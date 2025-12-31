"""Utilities to translate evaluation metrics into human-readable trading advice."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import pandas as pd


@dataclass
class AdviceConfig:
    """Configuration used when mapping metrics to advice."""

    buy_sharpe: float = 0.5
    hold_sharpe: float = 0.1
    min_total_return: float = 0.0
    min_trades: int = 5
    max_cost_ratio: float = 0.25  # relative transaction+slippage cost vs. gross profit


@dataclass
class AdviceRow:
    """Structured representation of a single recommendation."""

    ticker: str
    run_name: str
    start_date: Optional[pd.Timestamp]
    end_date: Optional[pd.Timestamp]
    recommendation: str
    confidence: str
    rationale: str
    total_return: float
    sharpe_ratio: float
    trade_count: float

    def to_dict(self) -> dict[str, object]:
        return {
            "ticker": self.ticker,
            "run_name": self.run_name,
            "start_date": self.start_date,
            "end_date": self.end_date,
            "recommendation": self.recommendation,
            "confidence": self.confidence,
            "rationale": self.rationale,
            "total_return": self.total_return,
            "sharpe_ratio": self.sharpe_ratio,
            "trade_count": self.trade_count,
        }


def _load_metrics(source: pd.DataFrame | Path | str) -> pd.DataFrame:
    if isinstance(source, pd.DataFrame):
        return source.copy()
    path = Path(source)
    if path.suffix.lower() == ".json":
        df = pd.read_json(path)
    else:
        df = pd.read_csv(path)
    return df


def _normalise_dates(df: pd.DataFrame) -> pd.DataFrame:
    for col in ("start_date", "end_date"):
        if col in df.columns and df[col].dtype != "datetime64[ns]":
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df


def _cost_ratio(row: pd.Series) -> float:
    gross = float(row.get("total_return", 0.0))
    transaction = float(row.get("transaction_cost_total", 0.0))
    slippage = float(row.get("slippage_cost_total", 0.0))
    denom = abs(gross) if abs(gross) > 1e-6 else 1.0
    return (transaction + slippage) / denom


def _pick_confidence(sharpe: float, trades: float) -> str:
    trade_tiers = [(25, "high"), (15, "medium"), (0, "low")]
    for threshold, label in trade_tiers:
        if trades >= threshold:
            base = label
            break
    else:
        base = "low"
    if abs(sharpe) >= 1.0:
        return f"{base}-confidence"
    if abs(sharpe) >= 0.5:
        return f"{base}-moderate"
    return f"{base}-cautious"


def _build_rationale(row: pd.Series, recommendation: str, config: AdviceConfig) -> str:
    parts: list[str] = []
    total_return = float(row.get("total_return", 0.0))
    sharpe = float(row.get("sharpe_ratio", 0.0))
    trades = float(row.get("trade_count", 0.0))
    parts.append(f"Sharpe {sharpe:.2f}")
    parts.append(f"return {total_return:.2%}")
    parts.append(f"{int(trades)} trades")
    cost_ratio = _cost_ratio(row)
    parts.append(f"cost ratio {cost_ratio:.1f}x")
    if recommendation == "hold" and sharpe < config.buy_sharpe:
        parts.append("needs stronger risk-adjusted return")
    if recommendation == "sell" and total_return > config.min_total_return:
        parts.append("profit offset by costs")
    return ", ".join(parts)


def generate_advice_table(
    source: pd.DataFrame | Path | str,
    config: AdviceConfig | None = None,
    tickers: Optional[Iterable[str]] = None,
) -> pd.DataFrame:
    """Convert forward metrics into human-readable trading guidance.

    Parameters
    ----------
    source:
        Either a DataFrame or a path to the CSV/JSON produced by
        ``compile_forward_reports.py``.
    config:
        Optional ``AdviceConfig`` to tweak thresholds.
    tickers:
        Optional allowlist of tickers to include; leave ``None`` to keep all.

    Returns
    -------
    pandas.DataFrame
        Table with recommendation, confidence, and supporting metrics per run.
    """

    cfg = config or AdviceConfig()
    df = _normalise_dates(_load_metrics(source))
    if tickers is not None and "ticker" in df.columns:
        upper = {t.upper() for t in tickers}
        df = df[df["ticker"].str.upper().isin(upper)].copy()
    required_cols = {"ticker", "run_name", "total_return", "sharpe_ratio", "trade_count"}
    missing = required_cols - set(df.columns)
    if missing:
        raise ValueError(f"Metrics table missing required columns: {sorted(missing)}")

    advice_rows: list[AdviceRow] = []
    for _, row in df.iterrows():
        total_return = float(row.get("total_return", 0.0))
        sharpe = float(row.get("sharpe_ratio", 0.0))
        trades = float(row.get("trade_count", 0.0))
        cost_ratio = _cost_ratio(row)

        if trades < cfg.min_trades:
            recommendation = "hold"
        elif sharpe >= cfg.buy_sharpe and total_return > cfg.min_total_return and cost_ratio < cfg.max_cost_ratio:
            recommendation = "buy"
        elif sharpe >= cfg.hold_sharpe and total_return >= cfg.min_total_return:
            recommendation = "hold"
        else:
            recommendation = "sell"

        confidence = _pick_confidence(sharpe, trades)
        rationale = _build_rationale(row, recommendation, cfg)

        advice_rows.append(
            AdviceRow(
                ticker=str(row.get("ticker", "NA")),
                run_name=str(row.get("run_name", "")),
                start_date=row.get("start_date"),
                end_date=row.get("end_date"),
                recommendation=recommendation,
                confidence=confidence,
                rationale=rationale,
                total_return=total_return,
                sharpe_ratio=sharpe,
                trade_count=trades,
            )
        )

    advice_df = pd.DataFrame([row.to_dict() for row in advice_rows])
    if not advice_df.empty:
        advice_df.sort_values(["ticker", "start_date", "run_name"], inplace=True)
    return advice_df.reset_index(drop=True)


__all__ = ["AdviceConfig", "generate_advice_table"]
