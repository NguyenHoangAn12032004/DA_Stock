"""Directional signal model for daily trading recommendations."""
from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Dict, Optional

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

LOGGER = logging.getLogger(__name__)


@dataclass
class DirectionalSignal:
    """Container holding the latest probabilistic signal."""

    probability: float
    signal: str
    thresholds: Dict[str, float]
    context: Dict[str, float]


def _compute_rsi(series: pd.Series, window: int = 14) -> pd.Series:
    """Compute a simple RSI for quick inference."""

    delta = series.diff()
    gain = np.clip(delta, a_min=0.0, a_max=None)
    loss = -np.clip(delta, a_min=None, a_max=0.0)
    avg_gain = gain.rolling(window=window, min_periods=window).mean()
    avg_loss = loss.rolling(window=window, min_periods=window).mean()
    rs = avg_gain / (avg_loss + 1e-12)
    rsi = 100.0 - (100.0 / (1.0 + rs))
    return rsi


def _compute_features(df: pd.DataFrame) -> pd.DataFrame:
    """Build the feature frame used by the logistic regression model."""

    features = pd.DataFrame(index=df.index)
    close = df["close"].astype(float)
    volume = df["volume"].astype(float)

    features["return_1d"] = close.pct_change()
    features["return_5d"] = close.pct_change(5)
    features["return_21d"] = close.pct_change(21)

    sma_5 = close.rolling(window=5, min_periods=5).mean()
    sma_20 = close.rolling(window=20, min_periods=20).mean()
    sma_50 = close.rolling(window=50, min_periods=50).mean()

    features["sma_5_ratio"] = close / sma_5 - 1.0
    features["sma_20_ratio"] = close / sma_20 - 1.0
    features["sma_50_ratio"] = close / sma_50 - 1.0

    features["rsi_14"] = _compute_rsi(close, window=14) / 100.0

    volume_mean = volume.rolling(window=30, min_periods=5).mean()
    volume_std = volume.rolling(window=30, min_periods=5).std(ddof=0)
    features["volume_z"] = (volume - volume_mean) / (volume_std + 1e-12)

    future_close = close.shift(-1)
    features["target"] = (future_close > close).astype(float)

    return features.dropna()


class DirectionalSignalModel:
    """Train logistic regression on daily bars to derive buy/hold/sell signals."""

    FEATURE_COLUMNS = [
        "return_1d",
        "return_5d",
        "return_21d",
        "sma_5_ratio",
        "sma_20_ratio",
        "sma_50_ratio",
        "rsi_14",
        "volume_z",
    ]

    def __init__(
        self,
        symbol: str,
        buy_threshold: float = 0.6,
        sell_threshold: float = 0.4,
        min_samples: int = 120,
        retrain_interval: int = 20,
    ) -> None:
        self.symbol = symbol
        self.buy_threshold = buy_threshold
        self.sell_threshold = sell_threshold
        self.min_samples = min_samples
        self.retrain_interval = retrain_interval

        self._model: Optional[LogisticRegression] = None
        self._scaler = StandardScaler()
        self._feature_frame = pd.DataFrame()
        self._trained_rows = 0

    @property
    def feature_frame(self) -> pd.DataFrame:
        """Return a copy of the feature frame used for inference."""

        return self._feature_frame.copy()

    def update_data(self, df: pd.DataFrame) -> None:
        """Update the feature store and (re)train the model when necessary."""

        if df.empty:
            return
        computed = _compute_features(df)
        if computed.empty:
            return

        self._feature_frame = computed
        if len(computed) < self.min_samples:
            LOGGER.debug("Not enough samples to train directional model for %s", self.symbol)
            return

        needs_training = self._model is None or len(computed) - self._trained_rows >= self.retrain_interval
        if needs_training:
            self._fit_model(computed)

    def _fit_model(self, computed: pd.DataFrame) -> None:
        train_df = computed.iloc[:-1]
        X = train_df[self.FEATURE_COLUMNS]
        y = train_df["target"]
        if (y.sum() == 0) or (y.sum() == len(y)):
            LOGGER.warning("Skipping logistic training for %s due to single-class target", self.symbol)
            return

        scaled = self._scaler.fit_transform(X)
        model = LogisticRegression(max_iter=1000, class_weight="balanced")
        model.fit(scaled, y)
        self._model = model
        self._trained_rows = len(computed)
        LOGGER.info("Directional model trained for %s with %d samples", self.symbol, len(train_df))

    def get_signal(self, timestamp: pd.Timestamp) -> Optional[DirectionalSignal]:
        """Return the latest signal for the provided timestamp if available."""

        if self._model is None or self._feature_frame.empty:
            return None
        if timestamp not in self._feature_frame.index:
            return None

        row = self._feature_frame.loc[timestamp]
        feature_df = row[self.FEATURE_COLUMNS].to_frame().T
        scaled = self._scaler.transform(feature_df)
        probability = float(self._model.predict_proba(scaled)[0, 1])

        if probability >= self.buy_threshold:
            signal = "BUY"
        elif probability <= self.sell_threshold:
            signal = "SELL"
        else:
            signal = "HOLD"

        context = {
            "return_1d": float(row["return_1d"]),
            "return_5d": float(row["return_5d"]),
            "sma_5_ratio": float(row["sma_5_ratio"]),
            "sma_20_ratio": float(row["sma_20_ratio"]),
            "rsi_14": float(row["rsi_14"]),
            "volume_z": float(row["volume_z"]),
        }

        return DirectionalSignal(
            probability=probability,
            signal=signal,
            thresholds={"buy": self.buy_threshold, "sell": self.sell_threshold},
            context=context,
        )
