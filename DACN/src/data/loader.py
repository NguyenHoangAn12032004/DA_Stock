

from __future__ import annotations

from dataclasses import dataclass
from io import StringIO
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import numpy as np
import pandas as pd
import requests
import yfinance as yf
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from joblib import load as joblib_load

from src.utils.technical import (
    calculate_adx,
    calculate_average_true_range,
    calculate_bollinger_bands,
    calculate_money_flow_index,
    calculate_obv,
    calculate_macd,
    calculate_rate_of_change,
    calculate_rsi,
    calculate_stochastic,
    calculate_williams_r,
    calculate_cci,
)


RAW_DATA_DIR = Path("data/raw")
YF_CHART_URL = "https://query2.finance.yahoo.com/v8/finance/chart/{ticker}"
STOOQ_URL = "https://stooq.com/q/d/l/?s={symbol}&i=d"
# Phase 7: Macro Tickers
# ^VIX: CBOE Volatility Index (Fear Gauge)
# ^TNX: 10-Year Treasury Yield (Interest Rates)
# DX-Y.NYB: US Dollar Index (Currency Strength)
# GC=F: Gold Futures (Safe Haven / Inflation)
MACRO_TICKERS = ["^VIX", "^TNX", "DX-Y.NYB", "GC=F"]


def _download_macro_features(start: str, end: str) -> pd.DataFrame:
    """Download macro indicators and return a DataFrame with aligned dates."""
    macro_data = {}
    print(f"Downloading Macro Data: {MACRO_TICKERS}...")
    for ticker in MACRO_TICKERS:
        try:
            df = yf.download(
                ticker, start=start, end=end, interval="1d",
                auto_adjust=True, progress=False, threads=False
            )
            if not df.empty:
                # Ensure simple index
                if hasattr(df.index, "tz_localize"):
                    df.index = df.index.tz_localize(None)
                
                # Keep Close and Maybe Volume? For macro, Close is usually enough.
                # VIX Close is the index level. 
                # TNX Close is the yield.
                if isinstance(df.columns, pd.MultiIndex):
                    # Handle yf multiindex output
                    try:
                        # try to get Close for the ticker, or just "Close"
                        s = df.xs("Close", axis=1, level=0)
                        if isinstance(s, pd.DataFrame):
                             s = s[ticker] # extract series
                    except KeyError:
                         # Fallback if structure is different (older yf version)
                         if "Close" in df.columns:
                             s = df["Close"]
                         elif "Adj Close" in df.columns:
                             s = df["Adj Close"]
                         else:
                             s = df.iloc[:, 0] # First column
                else:
                    s = df["Close"] if "Close" in df.columns else df.iloc[:, 0]
                
                # Clean name
                clean_name = ticker.replace("^", "").replace("=F", "").replace("-", "").replace(".", "")
                macro_data[f"macro_{clean_name}"] = s
        except Exception as e:
            print(f"Failed to download macro {ticker}: {e}")
    
    if not macro_data:
        return pd.DataFrame()
    
    df = pd.DataFrame(macro_data)
    df = df.ffill().fillna(0) # Forward fill missing days (holidays differ)
    return df


def _calculate_regime_features(panel: pd.DataFrame, tickers: List[str]) -> Tuple[pd.DataFrame, List[str]]:
    """
    Calculate Regime features (Trend, Cycle) and append to panel.
    Returns updated panel and list of new feature names.
    - regime_cycle: 0 (Recession/Panic), 1 (Normal/Expansion)
    - regime_trend: 0 (Bear), 1 (Sideways), 2 (Bull)
    """
    new_features = []
    
    # 1. Cycle (Global)
    vix_series = None
    first_ticker = tickers[0]
    if ("macro_VIX", first_ticker) in panel.columns:
        vix_series = panel[("macro_VIX", first_ticker)]
    
    if vix_series is not None:
        # 0=Risk Off (Panic), 1=Risk On (Normal)
        cycle_series = np.where(vix_series > 30, 0.0, 1.0)
        for ticker in tickers:
            panel[("regime_cycle", ticker)] = cycle_series
        new_features.append("regime_cycle")
        
    # 2. Trend (Per Asset)
    for ticker in tickers:
        close = panel[("close", ticker)]
        sma50 = close.rolling(50).mean()
        sma200 = close.rolling(200).mean()
        
        # Bull: Close > SMA50 > SMA200
        # Bear: Close < SMA50 < SMA200
        trend = np.full(len(close), 1.0) # Default Sideways
        bull_cond = (close > sma50) & (sma50 > sma200)
        bear_cond = (close < sma50) & (sma50 < sma200)
        
        trend[bull_cond] = 2.0
        trend[bear_cond] = 0.0
        
        panel[("regime_trend", ticker)] = trend
        
    new_features.append("regime_trend")
    return panel, list(set(new_features))


def _load_local_csv(ticker: str) -> Optional[pd.DataFrame]:
    path = RAW_DATA_DIR / f"{ticker}.csv"
    if not path.exists():
        return None

    df = pd.read_csv(path, parse_dates=["Date"])  # Yahoo style headers expected
    if df.empty:
        return None

    df = df.rename(columns={col: col.title() for col in df.columns})
    if "Adj Close" in df.columns:
        df["Close"] = df["Adj Close"]
    required = {"Open", "High", "Low", "Close", "Volume"}
    if not required.issubset(df.columns):
        return None

    df = df.set_index("Date").sort_index()
    ordered_cols = ["Open", "High", "Low", "Close", "Volume"]
    df = df[ordered_cols]
    return df


def _date_to_epoch(date_str: str) -> int:
    timestamp = pd.Timestamp(date_str)
    if timestamp.tzinfo is None:
        timestamp = timestamp.tz_localize("UTC")
    else:
        timestamp = timestamp.tz_convert("UTC")
    return int(timestamp.timestamp())


def _download_via_chart_api(ticker: str, start: str, end: str, interval: str) -> Optional[pd.DataFrame]:
    params = {
        "period1": _date_to_epoch(start),
        "period2": _date_to_epoch(end),
        "interval": interval,
        "events": "div,splits",
        "includePrePost": "false",
    }

    try:
        response = requests.get(YF_CHART_URL.format(ticker=ticker), params=params, timeout=30)
    except requests.RequestException:
        return None

    if response.status_code != 200:
        return None

    try:
        payload = response.json()
    except ValueError:
        return None

    result = payload.get("chart", {}).get("result")
    if not result:
        return None

    result_entry = result[0]
    timestamps = result_entry.get("timestamp")
    indicators = result_entry.get("indicators", {})
    quote_list = indicators.get("quote", [{}])
    adjclose_list = indicators.get("adjclose", [{}])

    if not timestamps or not quote_list:
        return None

    quote = quote_list[0]
    frame = pd.DataFrame(quote)
    if frame.empty:
        return None

    frame.index = pd.to_datetime(timestamps, unit="s", utc=True)
    frame.index = frame.index.tz_convert(None)

    rename_map = {
        "open": "Open",
        "high": "High",
        "low": "Low",
        "close": "Close",
        "volume": "Volume",
    }
    frame = frame.rename(columns={col: rename_map.get(col.lower(), col) for col in frame.columns})

    if "Adj Close" not in frame.columns:
        adjclose = adjclose_list[0].get("adjclose") if adjclose_list else None
        if adjclose is not None:
            frame["Adj Close"] = adjclose
        elif "Close" in frame.columns:
            frame["Adj Close"] = frame["Close"]

    required_cols = ["Open", "High", "Low", "Close", "Adj Close", "Volume"]
    if not set(required_cols).issubset(frame.columns):
        return None

    return frame[required_cols].dropna(how="any")


def _compute_direction_probabilities(
    features: np.ndarray,
    returns: np.ndarray,
    split_index: int,
) -> np.ndarray:
    """Train per-asset logistic models to estimate upward-move probability."""

    time_steps, n_assets, _ = features.shape
    direction_probs = np.full((time_steps, n_assets), 0.5, dtype=np.float32)

    for asset_idx in range(n_assets):
        # Use feature vectors at time t to predict the sign of return at t+1.
        train_X = features[: max(split_index - 1, 0), asset_idx, :]
        train_y = (returns[1:split_index, asset_idx] > 0).astype(np.int32)

        if train_X.size == 0 or train_X.shape[0] != train_y.shape[0] or train_y.sum() in {0, train_y.size}:
            continue

        try:
            clf = LogisticRegression(
                max_iter=1000,
                class_weight="balanced",
                solver="lbfgs",
            )
            clf.fit(train_X, train_y)
            future_features = features[:-1, asset_idx, :]
            probs = clf.predict_proba(future_features)[:, 1]
            direction_probs[1:, asset_idx] = probs.astype(np.float32)
            direction_probs[0, asset_idx] = direction_probs[1, asset_idx]
        except Exception:
            # If the classifier fails (singular matrix, etc.), fall back to neutral probability.
            continue

    return direction_probs


def _download_via_stooq(ticker: str) -> Optional[pd.DataFrame]:
    symbol = f"{ticker.lower()}.us"
    response = requests.get(STOOQ_URL.format(symbol=symbol), timeout=30)
    if response.status_code != 200:
        return None

    try:
        data = pd.read_csv(StringIO(response.text))
    except (pd.errors.EmptyDataError, pd.errors.ParserError, UnicodeDecodeError):
        return None

    if data.empty or "Date" not in data.columns:
        return None

    data["Date"] = pd.to_datetime(data["Date"])
    data = data.set_index("Date").sort_index()

    rename_map = {
        "Open": "Open",
        "High": "High",
        "Low": "Low",
        "Close": "Close",
        "Volume": "Volume",
    }
    data = data.rename(columns=rename_map)
    if "Close" in data.columns:
        data["Adj Close"] = data["Close"]

    required_cols = ["Open", "High", "Low", "Close", "Adj Close", "Volume"]
    if not set(required_cols).issubset(data.columns):
        return None

    return data.dropna(how="any")


@dataclass
class MarketDataset:
    features: np.ndarray
    prices: np.ndarray
    returns: np.ndarray
    dates: np.ndarray
    tickers: List[str]
    feature_names: List[str]
    scaler_mean: np.ndarray
    scaler_scale: np.ndarray
    split_index: int

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(
            path,
            features=self.features,
            prices=self.prices,
            returns=self.returns,
            dates=self.dates,
            tickers=np.array(self.tickers, dtype="U10"),
            feature_names=np.array(self.feature_names, dtype="U32"),
            scaler_mean=self.scaler_mean,
            scaler_scale=self.scaler_scale,
            split_index=np.array([self.split_index], dtype=np.int32),
        )

    def with_feature_subset(self, feature_subset: List[str]) -> "MarketDataset":
        if not feature_subset:
            return self

        missing = [name for name in feature_subset if name not in self.feature_names]
        if missing:
            raise ValueError(f"Dataset is missing required features: {missing}")

        indices = [self.feature_names.index(name) for name in feature_subset]
        new_features = self.features[..., indices]
        new_feature_names = [self.feature_names[idx] for idx in indices]

        scaler_len = len(self.scaler_mean)
        mean_dtype = self.scaler_mean.dtype if hasattr(self.scaler_mean, "dtype") else np.float32
        scale_dtype = self.scaler_scale.dtype if hasattr(self.scaler_scale, "dtype") else np.float32
        new_scaler_mean = np.array(
            [self.scaler_mean[idx] if idx < scaler_len else 0.0 for idx in indices],
            dtype=mean_dtype,
        )
        new_scaler_scale = np.array(
            [self.scaler_scale[idx] if idx < scaler_len else 1.0 for idx in indices],
            dtype=scale_dtype,
        )

        return MarketDataset(
            features=new_features,
            prices=self.prices,
            returns=self.returns,
            dates=self.dates,
            tickers=self.tickers,
            feature_names=new_feature_names,
            scaler_mean=new_scaler_mean,
            scaler_scale=new_scaler_scale,
            split_index=self.split_index,
        )

    @classmethod
    def load(cls, path: Path, feature_subset: Optional[List[str]] = None) -> "MarketDataset":
        data = np.load(path, allow_pickle=True)
        dataset = cls(
            features=data["features"],
            prices=data["prices"],
            returns=data["returns"],
            dates=data["dates"],
            tickers=data["tickers"].tolist(),
            feature_names=data["feature_names"].tolist(),
            scaler_mean=data["scaler_mean"],
            scaler_scale=data["scaler_scale"],
            split_index=int(data["split_index"][0]),
        )
        if feature_subset is not None:
            dataset = dataset.with_feature_subset(feature_subset)
        return dataset


def download_price_data(
    tickers: Iterable[str],
    start: str,
    end: str,
    interval: str = "1d",
) -> pd.DataFrame:
    combined_frames: List[pd.DataFrame] = []
    missing: List[str] = []

    for ticker in tickers:
        try:
            df = yf.download(
                tickers=ticker,
                start=start,
                end=end,
                interval=interval,
                auto_adjust=True,
                progress=False,
                group_by="ticker",
                threads=False,
            )
        except Exception:
            df = pd.DataFrame()

        if df.empty:
            df = _download_via_chart_api(ticker, start, end, interval)
            if df is None:
                df = _download_via_stooq(ticker)
            if df is None:
                df = _load_local_csv(ticker)
            if df is None:
                missing.append(ticker)
                continue
        else:
            df = df.sort_index()
            if hasattr(df.index, "tz_localize"):
                try:
                    df.index = df.index.tz_localize(None)  # type: ignore[assignment]
                except (TypeError, AttributeError, ValueError):
                    pass
            if isinstance(df.columns, pd.MultiIndex):
                df = df.droplevel(0, axis=1)

        if isinstance(df.columns, pd.Index):
            rename_map = {
                "open": "Open",
                "high": "High",
                "low": "Low",
                "close": "Close",
                "adj close": "Adj Close",
                "adjclose": "Adj Close",
                "volume": "Volume",
            }
            df = df.rename(columns={col: rename_map.get(col.lower(), col) for col in df.columns})

        if not isinstance(df.columns, pd.MultiIndex):
            df.columns = pd.MultiIndex.from_product([df.columns, [ticker]])

        combined_frames.append(df.dropna(how="any"))

    if missing or not combined_frames:
        raise ValueError(f"Failed to download data for tickers: {missing or list(tickers)}")

    data = pd.concat(combined_frames, axis=1)
    data = data.sort_index()
    data = data.dropna(how="any")
    return data


def build_feature_panel(
    price_data: pd.DataFrame,
    tickers: Iterable[str],
    feature_window: int = 50,
    indicators: Iterable[str] | None = None,
    include_extended_features: bool = False,
) -> Tuple[pd.DataFrame, List[str]]:
    indicators = list(indicators or [])
    ticker_frames: Dict[str, pd.DataFrame] = {}
    feature_names: List[str] = []

    for ticker in tickers:
        slice_df = price_data.xs(ticker, level=1, axis=1)
        frame = pd.DataFrame(index=slice_df.index)
        frame["open"] = slice_df["Open"].copy()
        frame["close"] = slice_df["Close"].copy()
        frame["high"] = slice_df["High"]
        frame["low"] = slice_df["Low"]
        frame["volume"] = slice_df["Volume"]
        frame["log_return"] = np.log(frame["close"].pct_change().add(1.0))
        frame["log_return"] = frame["log_return"].replace([-np.inf, np.inf], np.nan)
        frame["rolling_volatility"] = frame["log_return"].rolling(feature_window).std()
        frame["sma_ratio"] = frame["close"] / frame["close"].rolling(feature_window).mean()
        frame["ema_ratio"] = frame["close"] / frame["close"].ewm(span=feature_window, adjust=False).mean()

        # EMA Cross Signal (Macd-like but normalized by price)
        ema_fast = frame["close"].ewm(span=12, adjust=False).mean()
        ema_slow = frame["close"].ewm(span=26, adjust=False).mean()
        frame["ema_cross_signal"] = (ema_fast - ema_slow) / (frame["close"] + 1e-9)

        # Market Regime (Distance to SMA 200)
        # If history < 200, this will be NaN initially, handle carefully or allow dropna
        sma_200 = frame["close"].rolling(window=200, min_periods=50).mean()
        frame["market_regime"] = (frame["close"] - sma_200) / (sma_200 + 1e-9)

        if "rsi" in indicators:
            frame["rsi"] = calculate_rsi(frame["close"], window=feature_window // 2)
            # Phase 3: RSI Trend (Slope of last 5 days)
            frame["rsi_trend"] = frame["rsi"].diff(5) / 5.0
        if "macd" in indicators:
            macd, signal, hist = calculate_macd(frame["close"])
            frame["macd"] = macd
            frame["macd_signal"] = signal
            frame["macd_hist"] = hist
        if "stochastic" in indicators:
            k_value, d_value = calculate_stochastic(frame["high"], frame["low"], frame["close"])
            frame["stoch_k"] = k_value
            frame["stoch_d"] = d_value
        if "williams_r" in indicators:
            frame["williams_r"] = calculate_williams_r(frame["high"], frame["low"], frame["close"])
        if "roc" in indicators:
            frame["roc"] = calculate_rate_of_change(frame["close"], period=feature_window // 2)
            # Phase 4: Fast ROC (3-day) for V-shape detection
            frame["roc_fast"] = frame["close"].pct_change(3)
        if "bollinger" in indicators:
            upper, lower, bb_width, percent_b = calculate_bollinger_bands(frame["close"], window=feature_window)
            frame["bb_percent"] = percent_b
            frame["bb_width"] = bb_width
            frame["bb_zscore"] = (frame["close"] - (upper + lower) / 2.0) / (upper - lower + 1e-9)
        if "atr" in indicators:
            atr = calculate_average_true_range(frame["high"], frame["low"], frame["close"], window=feature_window // 2)
            frame["atr_ratio"] = atr / (frame["close"].abs() + 1e-9)
            # Phase 3: ATR Regime (Normalized by longer window to see if current vol is high)
            frame["atr_regime"] = frame["atr_ratio"] / (frame["atr_ratio"].rolling(window=feature_window).mean() + 1e-9)
        if "adx" in indicators:
            adx, plus_di, minus_di = calculate_adx(frame["high"], frame["low"], frame["close"], window=feature_window // 2)
            frame["adx"] = adx
            frame["plus_di"] = plus_di
            frame["minus_di"] = minus_di
            # ADX Trend: Strength * Direction
            # range roughly [-100, 100]
            di_sum = frame["plus_di"] + frame["minus_di"] + 1e-9
            di_diff = frame["plus_di"] - frame["minus_di"]
            frame["adx_trend"] = frame["adx"] * (di_diff / di_sum)
        if "obv" in indicators:
            frame["obv"] = calculate_obv(frame["close"], frame["volume"])
            frame["obv_pct"] = frame["obv"].pct_change().fillna(0.0)
        if "mfi" in indicators:
            frame["mfi"] = calculate_money_flow_index(frame["high"], frame["low"], frame["close"], frame["volume"], window=feature_window // 2)
        if "cci" in indicators:
            frame["cci"] = calculate_cci(frame["high"], frame["low"], frame["close"], window=feature_window // 2)

        if include_extended_features:
            vol_ma = frame["volume"].rolling(feature_window).mean()
            vol_std = frame["volume"].rolling(feature_window).std()
            frame["volume_ma_ratio"] = frame["volume"] / (vol_ma + 1e-9)
            frame["volume_zscore"] = (frame["volume"] - vol_ma) / (vol_std + 1e-9)
            frame["volume_trend"] = frame["volume"].pct_change().fillna(0.0)
            frame["price_range_pct"] = (frame["high"] - frame["low"]) / (frame["close"].abs() + 1e-9)
            prior_close = frame["close"].shift(1)
            frame["gap_pct"] = (frame["open"] - prior_close) / (prior_close.abs() + 1e-9)
            frame["return_5"] = frame["close"].pct_change(5)
            frame["return_21"] = frame["close"].pct_change(21)
            rolling_vol_mean = frame["rolling_volatility"].rolling(feature_window).mean()
            frame["volatility_ratio"] = frame["rolling_volatility"] / (rolling_vol_mean + 1e-9)
            # Momentum features (percentage change over lookbacks)
            frame["momentum_20"] = frame["close"].pct_change(20)
            frame["momentum_50"] = frame["close"].pct_change(50)
        
        # Phase 3: Volatility Cluster (Rolling variance of log returns)
        frame["volatility_cluster"] = frame["log_return"].rolling(window=10).var() * 1000

        # Clean infinities from percentage changes/divisions before dropping NaNs
        frame = frame.replace([np.inf, -np.inf], np.nan)
        frame = frame.dropna()
        ticker_frames[ticker] = frame

    aligned = pd.concat(ticker_frames, axis=1)
    # Swap levels to have (Feature, Ticker) structure
    aligned.columns = aligned.columns.swaplevel(0, 1)
    aligned = aligned.sort_index(axis=1)
    aligned = aligned.dropna(how="any")

    base_features = [
        "log_return",
        "rolling_volatility",
        "sma_ratio",
        "ema_ratio",
        "ema_cross_signal",
        "market_regime",
        "volatility_cluster",
    ]
    if "rsi" in indicators:
        base_features.extend(["rsi", "rsi_trend"])
    if "macd" in indicators:
        base_features.extend(["macd", "macd_signal", "macd_hist"])
    if "stochastic" in indicators:
        base_features.extend(["stoch_k", "stoch_d"])
    if "williams_r" in indicators:
        base_features.append("williams_r")
    if "roc" in indicators:
        base_features.extend(["roc", "roc_fast"])
    if "bollinger" in indicators:
        base_features.extend(["bb_percent", "bb_width", "bb_zscore"])
    if "atr" in indicators:
        base_features.extend(["atr_ratio", "atr_regime"])
    if "adx" in indicators:
        base_features.extend(["adx", "plus_di", "minus_di", "adx_trend"])
    if "obv" in indicators:
        base_features.extend(["obv", "obv_pct"])
    if "mfi" in indicators:
        base_features.append("mfi")
    if "cci" in indicators:
        base_features.append("cci")
    base_features.append("volume")

    if include_extended_features:
        base_features.extend(
            [
                "volume_ma_ratio",
                "volume_zscore",
                "volume_trend",
                "price_range_pct",
                "gap_pct",
                "return_5",
                "return_21",
                "volatility_ratio",
                "momentum_20",
                "momentum_50",
            ]
        )

    feature_names = base_features
    return aligned, feature_names


def _load_sentiment_data(tickers: Iterable[str], start: str, end: str) -> pd.DataFrame:
    path = Path("data/processed/sentiment.csv")
    if not path.exists():
        return pd.DataFrame()
    
    try:
        df = pd.read_csv(path)
        df["date"] = pd.to_datetime(df["date"])
        df = df.rename(columns={"date": "Date", "ticker": "Ticker"})
        
        # Filter by date range
        start_date = pd.Timestamp(start).tz_localize("UTC") if pd.Timestamp(start).tzinfo is None else pd.Timestamp(start)
        end_date = pd.Timestamp(end).tz_localize("UTC") if pd.Timestamp(end).tzinfo is None else pd.Timestamp(end)
        
        # Ensure df dates are UTC for comparison
        if df["Date"].dt.tz is None:
             df["Date"] = df["Date"].dt.tz_localize("UTC")
        else:
             df["Date"] = df["Date"].dt.tz_convert("UTC")

        df = df[(df["Date"] >= start_date) & (df["Date"] <= end_date)]
        
        # Convert to naive UTC to match price data
        df["Date"] = df["Date"].dt.tz_localize(None)
        
        # Filter by tickers
        df = df[df["Ticker"].isin(tickers)]
        
        if df.empty:
            return pd.DataFrame()

        # Pivot to match price_data structure: Index=Date, Columns=(Feature, Ticker)
        # We want to pivot all available sentiment columns
        value_vars = [c for c in df.columns if c not in ["Date", "Ticker"]]
        
        pivot_df = df.pivot(index="Date", columns="Ticker", values=value_vars)
        
        # pivot_df columns are already MultiIndex (Feature, Ticker) if values is a list
        # But if values has length 1, it might not be.
        # Let's ensure it's consistent.
        
        return pivot_df
    except Exception as e:
        print(f"Error loading sentiment data: {e}")
        return pd.DataFrame()


def prepare_market_dataset(
    tickers: Iterable[str],
    start: str,
    end: str,
    interval: str,
    dataset_path: Path,
    feature_window: int,
    indicators: Iterable[str],
    train_ratio: float = 0.8,
    include_extended_features: bool = False,
    calibration_enabled: bool = False,
    calibration_path: Optional[Path] = None,
    calibrate_only_after_split: bool = True,
) -> MarketDataset:
    price_data = download_price_data(tickers, start, end, interval)
    
    # Load and merge sentiment data
    sentiment_data = _load_sentiment_data(tickers, start, end)

    # Load and merge macro data (Phase 7)
    macro_data = _download_macro_features(start, end)
    
    panel, feature_names = build_feature_panel(
        price_data,
        tickers,
        feature_window,
        indicators,
        include_extended_features=include_extended_features,
    )

    # Merge macro data into panel
    if not macro_data.empty:
        # Reindex macro data to match panel dates
        macro_data = macro_data.reindex(panel.index).ffill().fillna(0)
        
        # Add macro features to every ticker
        for col in macro_data.columns:
            # col is like "macro_VIX"
            for ticker in tickers:
                 panel[(col, ticker)] = macro_data[col]
            
            if col not in feature_names:
                feature_names.append(col)

    # Calculate Regime Features (Trend/Cycle)
    panel, regime_features = _calculate_regime_features(panel, list(tickers))
    # feature_names.extend(regime_features) -> Moved to post-scaling
    # Ensure unique
    feature_names = list( dict.fromkeys(feature_names) )

    # Merge sentiment into panel
    if not sentiment_data.empty:
        # sentiment_data has columns (Feature, Ticker)
        # panel has columns (Feature, Ticker)
        
        # We need to align sentiment_data to panel index
        sentiment_data = sentiment_data.reindex(panel.index).fillna(0)
        
        # Add all sentiment columns to panel
        # sentiment_data.columns is MultiIndex (Feature, Ticker)
        for col in sentiment_data.columns:
            panel[col] = sentiment_data[col]
            feature_name = col[0]
            if feature_name not in feature_names:
                feature_names.append(feature_name)
        
        # Compute derived sentiment features
        # 1. Sentiment Volatility (average of stds if available, or just use what we have)
        # We expect 'news_sentiment_std' and 'tweet_sentiment_std'
        
        for ticker in tickers:
            # Volatility
            vol_cols = []
            if ("news_sentiment_std", ticker) in panel.columns:
                vol_cols.append(panel[("news_sentiment_std", ticker)])
            if ("tweet_sentiment_std", ticker) in panel.columns:
                vol_cols.append(panel[("tweet_sentiment_std", ticker)])
            
            if vol_cols:
                # Average the standard deviations to get a composite volatility metric
                # Using mean of stds is a reasonable proxy for overall sentiment uncertainty
                panel[("sentiment_volatility", ticker)] = pd.concat(vol_cols, axis=1).mean(axis=1)
            else:
                panel[("sentiment_volatility", ticker)] = 0.0
                
            # Trend (MA 7 of composite sentiment)
            if ("sentiment", ticker) in panel.columns:
                sent_series = panel[("sentiment", ticker)]
                panel[("sentiment_ma_7", ticker)] = sent_series.rolling(window=7).mean().fillna(0)
                
                # Momentum (diff)
                panel[("sentiment_momentum", ticker)] = sent_series.diff().fillna(0)
            else:
                panel[("sentiment_ma_7", ticker)] = 0.0
                panel[("sentiment_momentum", ticker)] = 0.0

        feature_names.extend(["sentiment_volatility", "sentiment_ma_7", "sentiment_momentum"])
        # Ensure unique feature names
        feature_names = list(dict.fromkeys(feature_names))

    dates = panel.index.to_numpy(dtype="datetime64[ns]")
    tickers_list = list(tickers)

    prices = np.stack([
        panel.xs(ticker, level=1, axis=1)["close"].to_numpy(dtype=np.float32)
        for ticker in tickers_list
    ], axis=1)

    returns = np.stack([
        panel.xs(ticker, level=1, axis=1)["log_return"].to_numpy(dtype=np.float32)
        for ticker in tickers_list
    ], axis=1)

    feature_stack: List[np.ndarray] = []
    for feature in feature_names:
        feature_slice = np.stack([
            panel.xs(ticker, level=1, axis=1)[feature].to_numpy(dtype=np.float32)
            for ticker in tickers_list
        ], axis=1)
        feature_stack.append(feature_slice)
    features = np.stack(feature_stack, axis=-1)

    split_index = int(len(dates) * train_ratio)

    scaler = StandardScaler()
    flattened = features.reshape(-1, features.shape[-1])
    if split_index > 0:
        train_flat = features[:split_index].reshape(-1, features.shape[-1])
        scaler.fit(train_flat)
    else:
        scaler.fit(flattened)
    scaled = scaler.transform(flattened)
    features = scaled.reshape(features.shape)

    direction_probs = _compute_direction_probabilities(features, returns, split_index)

    # Optional probability calibration (post-hoc) for direction_prob
    if calibration_enabled and calibration_path is not None and Path(calibration_path).exists():
        try:
            calib_obj = joblib_load(calibration_path)
            method = calib_obj.get("method")
            per_asset = calib_obj.get("per_asset", [])
            # Expect length to match number of assets; else fall back gracefully
            time_steps, n_assets = direction_probs.shape
            start_idx = max(split_index, 0) if calibrate_only_after_split else 0
            for a in range(min(n_assets, len(per_asset))):
                p = direction_probs[:, a].copy()
                if method == "platt":
                    lr = per_asset[a]
                    if lr is None:
                        continue
                    # Map p -> sigmoid(a * logit(p) + b)
                    eps = 1e-6
                    p_clip = np.clip(p[start_idx:], eps, 1 - eps)
                    x = np.log(p_clip / (1 - p_clip)).reshape(-1, 1)
                    try:
                        p_cal = lr.predict_proba(x)[:, 1].astype(np.float32)
                    except Exception:
                        # If LR is incompatible, skip calibration for this asset
                        continue
                    p[start_idx:] = p_cal
                    direction_probs[:, a] = p
                elif method == "isotonic":
                    iso = per_asset[a]
                    if iso is None:
                        continue
                    try:
                        p_cal = iso.predict(p[start_idx:]).astype(np.float32)
                    except Exception:
                        continue
                    p[start_idx:] = np.clip(p_cal, 0.0, 1.0)
                    direction_probs[:, a] = p
                else:
                    # Unknown method; no-op
                    pass
        except Exception:
            # Calibration artifact load failed; proceed without calibration
            pass
    # Append Regime Features (Unscaled)
    # Ensure deterministic order
    sorted_regime_features = sorted(regime_features)
    regime_stack = []
    for feat in sorted_regime_features:
        feat_slice = np.stack([
            panel.xs(ticker, level=1, axis=1)[feat].to_numpy(dtype=np.float32)
            for ticker in tickers_list
        ], axis=1)
        regime_stack.append(feat_slice)
    
    if regime_stack:
        regime_arr = np.stack(regime_stack, axis=-1)
        features = np.concatenate([features, regime_arr], axis=-1)

    features = np.concatenate([features, direction_probs[..., np.newaxis]], axis=-1)
    augmented_feature_names = feature_names + sorted_regime_features + ["direction_prob"]

    dataset = MarketDataset(
        features=features.astype(np.float32),
        prices=prices.astype(np.float32),
        returns=returns.astype(np.float32),
        dates=dates.astype("datetime64[D]"),
        tickers=tickers_list,
        feature_names=augmented_feature_names,
        scaler_mean=scaler.mean_.astype(np.float32),
        scaler_scale=scaler.scale_.astype(np.float32),
        split_index=split_index,
    )
    dataset.save(dataset_path)
    return dataset
