"""Lightweight paper-trading utilities for daily decision logging and P/L.

This module supports a minimal workflow:
- Record daily decisions (BUY/HOLD/SELL) per ticker from RL signals.
- Compute next-day mark-to-market P/L using latest prices (intraday or close).
- Persist to CSV for later weekly aggregation or Excel export.

Assumptions (can be tuned by caller):
- Default position sizing: 1000 shares per ticker.
- Long-only by default (SELL => flat). Set allow_short=True to treat SELL as a short.
- Entry price: last available price at record time (prefer daily close if run EOD).
- P/L: mark-to-market vs the latest available price (intraday 5m or daily close).
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable, Optional

import pandas as pd
import pytz
import yfinance as yf

NY_TZ = pytz.timezone("America/New_York")


@dataclass
class Decision:
    date: pd.Timestamp
    ticker: str
    action: str  # BUY | SELL | HOLD
    shares: int = 1000
    entry_price: Optional[float] = None
    entry_time: Optional[pd.Timestamp] = None
    config_path: Optional[str] = None
    model_path: Optional[str] = None
    # Indicator snapshot at decision time (raw, unscaled)
    rsi: Optional[float] = None
    bb_percent: Optional[float] = None
    macd_hist: Optional[float] = None
    direction_prob: Optional[float] = None
    # Optional reason (e.g., breakout_failed) for SELL decisions (or any action)
    reason: Optional[str] = None
    # Arbitrary snapshot map for dynamic features
    snapshot_json: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "date": self.date.normalize(),
            "ticker": self.ticker.upper(),
            "action": self.action.upper(),
            "shares": int(self.shares),
            "entry_price": float(self.entry_price) if self.entry_price is not None else None,
            "entry_time": self.entry_time.isoformat() if self.entry_time is not None else None,
            "config_path": self.config_path,
            "model_path": self.model_path,
            "rsi": self.rsi,
            "bb_percent": self.bb_percent,
            "macd_hist": self.macd_hist,
            "direction_prob": self.direction_prob,
            "reason": self.reason,
            "snapshot_json": self.snapshot_json,
        }


def _ensure_dir(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def _now_ny() -> pd.Timestamp:
    return pd.Timestamp(datetime.now(tz=NY_TZ))


def _last_business_day(ts: Optional[pd.Timestamp] = None) -> pd.Timestamp:
    ts = ts or _now_ny()
    # Move back day by day until weekday (Mon-Fri); ignore market holidays here for simplicity
    prev = ts.normalize() - pd.Timedelta(days=1)
    while prev.weekday() >= 5:  # 5=Sat, 6=Sun
        prev -= pd.Timedelta(days=1)
    return prev


def _next_business_day(ts: pd.Timestamp) -> pd.Timestamp:
    """Return the next weekday after the given timestamp (Mon-Fri)."""
    nxt = ts.normalize() + pd.Timedelta(days=1)
    while nxt.weekday() >= 5:
        nxt += pd.Timedelta(days=1)
    return nxt


def fetch_latest_price(
    ticker: str,
    use_intraday: bool = True,
    intraday_window_days: int = 3,
    daily_window_days: int = 7,
) -> tuple[float, pd.Timestamp]:
    """Return the latest price and its timestamp.

    Parameters
    ----------
    ticker: Symbol (e.g. "AAPL").
    use_intraday: If True, attempt 5m bars first.
    intraday_window_days: How many days of 5m history to request (default 3).
    daily_window_days: How many days of daily history to request (default 7).

    Notes
    -----
    - Shorter windows reduce bandwidth and chance of timezone mismatch.
    - We normalize the returned timestamp to NY timezone regardless of source.
    """
    sym = ticker.upper()
    if use_intraday:
        try:
            df = yf.Ticker(sym).history(period=f"{intraday_window_days}d", interval="5m", auto_adjust=False)
            if not df.empty:
                last = df.iloc[-1]
                ts_last = pd.Timestamp(last.name)
                # Robust tz handling: convert if tz-aware, localize->convert if naive
                if ts_last.tzinfo is None:
                    # yfinance intraday sometimes already tz-aware; if not assume UTC then convert
                    ts_last = ts_last.tz_localize(pytz.UTC).tz_convert(NY_TZ)
                else:
                    ts_last = ts_last.tz_convert(NY_TZ)
                return float(last["Close"]), ts_last
        except Exception:
            pass
    # Daily fallback with reduced window
    df = yf.Ticker(sym).history(period=f"{daily_window_days}d", interval="1d", auto_adjust=False)
    if df.empty:
        raise ValueError(f"No price data for {sym}")
    last = df.iloc[-1]
    ts = pd.Timestamp(last.name)
    if ts.tzinfo is None:
        # Assume UTC if naive, then convert to NY for consistency
        ts = ts.tz_localize(pytz.UTC).tz_convert(NY_TZ)
    else:
        ts = ts.tz_convert(NY_TZ)
    return float(last["Close"]), ts


def fetch_close_price(
    ticker: str,
    date: pd.Timestamp,
    search_window_days: int = 2,
) -> Optional[float]:
    """Get the daily close for a given ``date`` (NY time).

    Priority order:
    1) Local CSV fallback at ``data/raw/<TICKER>.csv`` (Yahoo-style columns).
    2) yfinance daily history bounded by ``date ± search_window_days``.

    Parameters
    ----------
    ticker: Equity symbol.
    date: Target trading date (tz-naive or tz-aware).
    search_window_days: Days before/after to query from yfinance (default 2).

    Returns
    -------
    float | None
        Close price if available, else None (holiday / missing).
    """
    sym = ticker.upper()
    # Ensure target date is NY tz-aware for consistent comparisons
    if date.tzinfo is None:
        date = date.tz_localize(NY_TZ)

    # 1) Local CSV fallback (offline mode)
    try:
        csv_path = Path("data/raw") / f"{sym}.csv"
        if csv_path.exists():
            df_local = pd.read_csv(csv_path, parse_dates=["Date"])
            # Normalize to NY date for comparison
            df_local["Date"] = pd.to_datetime(df_local["Date"]).dt.tz_localize(NY_TZ, nonexistent="shift_forward", ambiguous="NaT").dt.normalize()
            row_local = df_local[df_local["Date"] == date.normalize()]
            if not row_local.empty:
                # Prefer Adj Close if available
                if "Adj Close" in row_local.columns and pd.notna(row_local.iloc[-1]["Adj Close"]):
                    return float(row_local.iloc[-1]["Adj Close"])
                if "Close" in row_local.columns and pd.notna(row_local.iloc[-1]["Close"]):
                    return float(row_local.iloc[-1]["Close"])
    except Exception:
        # Ignore local CSV errors and fall back to network
        pass

    # 2) Network fallback via yfinance
    start = (date - pd.Timedelta(days=search_window_days)).strftime("%Y-%m-%d")
    end = (date + pd.Timedelta(days=search_window_days)).strftime("%Y-%m-%d")
    try:
        df = yf.Ticker(sym).history(start=start, end=end, interval="1d", auto_adjust=False)
    except Exception:
        df = pd.DataFrame()
    if df.empty:
        return None
    # Align on normalized date
    df_index_norm = pd.to_datetime(df.index).tz_localize(NY_TZ, nonexistent="shift_forward", ambiguous="NaT").normalize()
    mask = df_index_norm == date.normalize()
    if not mask.any():
        return None
    row = df.loc[mask].iloc[-1]
    return float(row.get("Close")) if "Close" in row else None


def upsert_decisions(path: Path, decisions: Iterable[Decision]) -> pd.DataFrame:
    """Append decisions to CSV, de-duplicating by (date, ticker)."""
    _ensure_dir(path)
    df_new = pd.DataFrame([d.to_dict() for d in decisions])
    if path.exists():
        df_old = pd.read_csv(path, parse_dates=["date"], dtype={"ticker": str, "action": str})
    else:
        df_old = pd.DataFrame(columns=df_new.columns)

    # Keep last per (date,ticker)
    df = pd.concat([df_old, df_new], ignore_index=True)
    df.sort_values(["date", "ticker", "entry_time"], inplace=True)
    df = df.drop_duplicates(subset=["date", "ticker"], keep="last").reset_index(drop=True)
    df.to_csv(path, index=False)
    return df


def compute_pnl(
    decisions_csv: Path,
    output_csv: Path,
    asof: Optional[pd.Timestamp] = None,
    allow_short: bool = False,
    use_intraday: bool = True,
    transaction_cost_bps: float = 0.0,
    slippage_bps: float = 0.0,
    roundtrip: bool = False,
    offline_price_bps: Optional[float] = None,
    missed_move_threshold_pct: float = 0.01,
    historical_next_close: bool = False,
    intraday_window_days: int = 3,
    daily_window_days: int = 7,
    close_search_window_days: int = 2,
) -> pd.DataFrame:
    """Compute mark-to-market P/L for decisions from the previous business day.

    Parameters
    ----------
    decisions_csv: Path to decisions log written by ``upsert_decisions``.
    output_csv: Path where to write/append daily P/L rows.
    asof: Evaluation timestamp (default: now in NY timezone).
    allow_short: If True, SELL is treated as -shares; otherwise SELL yields 0 position.
    use_intraday: If True, fetches 5m bar last price; else uses latest daily close.
    """
    if not Path(decisions_csv).exists():
        raise FileNotFoundError(f"Decisions file not found: {decisions_csv}")
    asof = asof or _now_ny()
    prev_day = _last_business_day(asof)

    dec = pd.read_csv(decisions_csv, parse_dates=["date"]) if Path(decisions_csv).exists() else pd.DataFrame()
    if dec.empty:
        raise ValueError("No decisions to evaluate.")
    prev_dec = dec[dec["date"].dt.normalize() == prev_day.normalize()].copy()
    if prev_dec.empty:
        # nothing to compute (holiday or not recorded yet); still return empty frame
        return pd.DataFrame(columns=[
            "valuation_date","valuation_time","price_ts","ticker","action","shares","entry_price","current_price","pnl_gross","pnl_net","pnl_pct","transaction_cost_bps","slippage_bps","mode"
        ])

    rows = []
    for _, row in prev_dec.iterrows():
        ticker = str(row["ticker"]).upper()
        action = str(row["action"]).upper()
        shares = int(row.get("shares", 1000) or 1000)
        # Prefer recorded entry_price when valid (>0); otherwise fallback to previous day's close
        raw_entry = row.get("entry_price")
        if pd.isna(raw_entry):
            entry_price = None
        else:
            try:
                entry_price = float(raw_entry)
            except Exception:
                entry_price = None
        if entry_price is None or entry_price <= 0:
            entry_price = fetch_close_price(ticker, prev_day, search_window_days=close_search_window_days) or 0.0
        current_price: Optional[float] = None
        current_ts: Optional[pd.Timestamp] = None
        try:
            if historical_next_close:
                # Use next business day's daily close as the valuation price
                nxt = _next_business_day(prev_day)
                p = fetch_close_price(ticker, nxt, search_window_days=close_search_window_days)
                if p is not None:
                    current_price = p
                    # Synthesize timestamp at 16:00 NY of next business day
                    current_ts = pd.Timestamp(nxt.tz_localize(NY_TZ) + pd.Timedelta(hours=16))
                else:
                    current_price = None
                    current_ts = None
            else:
                current_price, current_ts = fetch_latest_price(
                    ticker,
                    use_intraday=use_intraday,
                    intraday_window_days=intraday_window_days,
                    daily_window_days=daily_window_days,
                )
        except Exception:
            # Fallback: offline price if configured and entry_price available
            if offline_price_bps is not None and entry_price and entry_price > 0:
                current_price = entry_price * (1.0 + offline_price_bps / 1e4)
                current_ts = asof or _now_ny()
            else:
                current_price = None
                current_ts = None
        position = 0
        if action == "BUY":
            position = shares
        elif action == "SELL":
            position = -shares if allow_short else 0
        else:  # HOLD
            position = 0


        status = "ok"
        pnl_gross = float("nan")
        notional = (entry_price * abs(position)) if entry_price and entry_price > 0 else 0.0
        if current_price is None or current_ts is None:
            status = "holiday_or_no_price"
            price_change_pct = float("nan")
            pnl_net = float("nan")
            pnl_pct = float("nan")
            direction_correct = None
            decision_effective = None
            hold_correct = None
            missed_move = None
        else:
            pnl_gross = (current_price - entry_price) * position
            # Costs: transaction cost + slippage; if roundtrip=True, charge x2 (entry+exit)
            cost_rate = (transaction_cost_bps + slippage_bps) / 1e4
            if roundtrip:
                cost_rate *= 2.0
            costs = notional * cost_rate
            pnl_net = pnl_gross - costs
            price_change_pct = ((current_price - entry_price) / entry_price) if entry_price and entry_price > 0 else 0.0
            pnl_pct = (pnl_net / notional) if notional > 1e-9 else 0.0
            direction_correct = int(((position > 0 and current_price > entry_price) or (position < 0 and current_price < entry_price))) if position != 0 else 0
            decision_effective = int(position != 0 and pnl_net > 0.0)
            # Hold evaluation
            hold_correct = int(position == 0 and abs(price_change_pct) < missed_move_threshold_pct)
            missed_move = int(position == 0 and abs(price_change_pct) >= missed_move_threshold_pct)

        rows.append({
            "valuation_date": asof.normalize(),
            "valuation_time": asof.isoformat(),
            "price_ts": current_ts.isoformat() if current_ts is not None else None,
            "ticker": ticker,
            "action": action,
            "shares": position,
            "entry_price": entry_price,
            "current_price": current_price,
            "pnl_gross": pnl_gross,
            "pnl_net": pnl_net,
            "pnl_pct": pnl_pct,
            "transaction_cost_bps": transaction_cost_bps,
            "slippage_bps": slippage_bps,
            "price_change_pct": price_change_pct,
            "direction_correct": direction_correct,
            "decision_effective": decision_effective,
            "hold_correct": hold_correct,
            "missed_move": missed_move,
            "status": status,
            "mode": "short_allowed" if allow_short else "long_only",
        })

    df_out = pd.DataFrame(rows)
    _ensure_dir(output_csv)
    if output_csv.exists():
        prev = pd.read_csv(output_csv, parse_dates=["valuation_date"])
        df_out = pd.concat([prev, df_out], ignore_index=True)
        # Drop dups by (valuation_date, ticker, mode)
        df_out.sort_values(["valuation_date", "ticker", "valuation_time"], inplace=True)
        df_out = df_out.drop_duplicates(subset=["valuation_date", "ticker", "mode"], keep="last")
    df_out.to_csv(output_csv, index=False)
    return df_out


def make_shortview(pnl_csv: Path, output_csv: Optional[Path] = None) -> pd.DataFrame:
    """Create a de-duplicated PnL view that prefers short_allowed over long_only per day/ticker.

    If ``mode`` column is absent or there are no duplicates per (valuation_date, ticker),
    this function returns the input as-is. When duplicates exist, rows with ``mode == 'short_allowed'``
    are preferred; otherwise the first available row is kept.

    Parameters
    ----------
    pnl_csv: Path to the raw PnL CSV (potentially containing both long_only and short_allowed rows).
    output_csv: Optional path to write the shortview CSV. If None, only returns the DataFrame.
    """
    if not Path(pnl_csv).exists():
        raise FileNotFoundError(f"P/L file not found: {pnl_csv}")
    df = pd.read_csv(pnl_csv, parse_dates=["valuation_date"]).copy()
    if df.empty or "mode" not in df.columns:
        # Nothing to prefer; just return original
        out_df = df
    else:
        # Prefer short_allowed when duplicates exist per (date, ticker)
        df["_pref"] = df["mode"].apply(lambda m: 0 if m == "short_allowed" else 1)
        df.sort_values(["valuation_date", "ticker", "_pref", "valuation_time"], inplace=True)
        out_df = df.drop_duplicates(subset=["valuation_date", "ticker"], keep="first").drop(columns=["_pref"])
    if output_csv is not None:
        _ensure_dir(output_csv)
        out_df.to_csv(output_csv, index=False)
    return out_df


def aggregate_weekly(pnl_csv: Path, output_path: Path, week_start: Optional[pd.Timestamp] = None, prefer_shortview: bool = False) -> pd.DataFrame:
    """Aggregate a week of P/L into a summary and write CSV/XLSX depending on suffix.

    Week is Monday→Friday in NY time by default (or provided ``week_start``).
    """
    if not Path(pnl_csv).exists():
        raise FileNotFoundError(f"P/L file not found: {pnl_csv}")
    # Optionally de-duplicate with preference for short_allowed rows
    if prefer_shortview:
        df = make_shortview(pnl_csv, output_csv=None)
    else:
        df = pd.read_csv(pnl_csv, parse_dates=["valuation_date"]).copy()
    if df.empty:
        return df.head(0)
    week_start = week_start or _now_ny()
    # Align to Monday of that week
    monday = week_start - pd.Timedelta(days=week_start.weekday())
    monday = monday.normalize()
    friday = monday + pd.Timedelta(days=4)
    # Ensure tz-naive comparison to match CSV-loaded dates
    if isinstance(monday, pd.Timestamp) and monday.tzinfo is not None:
        monday = monday.tz_localize(None)
    if isinstance(friday, pd.Timestamp) and friday.tzinfo is not None:
        friday = friday.tz_localize(None)
    mask = (df["valuation_date"].dt.normalize() >= monday) & (df["valuation_date"].dt.normalize() <= friday)
    week_df = df[mask].copy()
    if week_df.empty:
        return week_df

    # Choose net if available
    net_col = "pnl_net" if "pnl_net" in week_df.columns else ("pnl_abs" if "pnl_abs" in week_df.columns else None)
    if net_col is None:
        return week_df
    daily = week_df.groupby([week_df["valuation_date"].dt.strftime("%Y-%m-%d"), "ticker"], as_index=False)[[net_col]].sum().rename(columns={net_col: "pnl_day"})
    totals = week_df.groupby("ticker", as_index=False)[[net_col]].sum().rename(columns={net_col: "pnl_week"})
    total_all = pd.DataFrame({
        "ticker": ["TOTAL"],
        "pnl_week": [totals["pnl_week"].sum()],
    })

    _ensure_dir(output_path)
    if output_path.suffix.lower() == ".xlsx":
        with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
            week_df.to_excel(writer, sheet_name="pnl_raw", index=False)
            daily.to_excel(writer, sheet_name="pnl_daily", index=False)
            totals.to_excel(writer, sheet_name="pnl_by_ticker", index=False)
            total_all.to_excel(writer, sheet_name="summary", index=False)
            # Accuracy sheet (only rows with metrics)
            acc_df = week_df.copy()
            if "direction_correct" in acc_df.columns:
                acc_df["pos_decision"] = (acc_df["shares"].abs() > 0).astype(int) if "shares" in acc_df.columns else 0
                grp = acc_df.groupby("ticker", as_index=False).agg({
                    "direction_correct": "sum",
                    "pos_decision": "sum",
                    "hold_correct": "sum" if "hold_correct" in acc_df.columns else "sum",
                    "missed_move": "sum" if "missed_move" in acc_df.columns else "sum",
                })
                # Avoid KeyError if columns missing
                for c in ("hold_correct", "missed_move"):
                    if c not in grp.columns:
                        grp[c] = 0
                grp["direction_accuracy"] = (grp["direction_correct"] / grp["pos_decision"]).fillna(0.0)
                grp.to_excel(writer, sheet_name="accuracy", index=False)
    else:
        # Default CSV writes the raw week_df; also emit _summary.csv nearby
        week_df.to_csv(output_path, index=False)
        summary_path = output_path.with_name(output_path.stem + "_summary.csv")
        totals.to_csv(summary_path, index=False)
    return week_df


__all__ = [
    "Decision",
    "upsert_decisions",
    "fetch_latest_price",
    "fetch_close_price",
    "compute_pnl",
    "make_shortview",
    "aggregate_weekly",
]
