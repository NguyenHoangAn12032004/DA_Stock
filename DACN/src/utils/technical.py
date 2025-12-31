from __future__ import annotations

import numpy as np
import pandas as pd


def calculate_rsi(close: pd.Series, window: int = 14) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0.0)
    loss = -delta.clip(upper=0.0)
    avg_gain = gain.ewm(alpha=1.0 / window, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1.0 / window, adjust=False).mean()
    rs = avg_gain / (avg_loss + 1e-9)
    rsi = 100.0 - (100.0 / (1.0 + rs))
    return rsi


def calculate_macd(
    close: pd.Series,
    fast_period: int = 12,
    slow_period: int = 26,
    signal_period: int = 9,
) -> tuple[pd.Series, pd.Series, pd.Series]:
    ema_fast = close.ewm(span=fast_period, adjust=False).mean()
    ema_slow = close.ewm(span=slow_period, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal_period, adjust=False).mean()
    histogram = macd_line - signal_line
    return macd_line, signal_line, histogram


def calculate_stochastic(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    window: int = 14,
    smooth: int = 3,
) -> tuple[pd.Series, pd.Series]:
    lowest_low = low.rolling(window).min()
    highest_high = high.rolling(window).max()
    percent_k = 100.0 * (close - lowest_low) / (highest_high - lowest_low + 1e-9)
    percent_d = percent_k.rolling(smooth).mean()
    return percent_k, percent_d


def calculate_williams_r(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    window: int = 14,
) -> pd.Series:
    highest_high = high.rolling(window).max()
    lowest_low = low.rolling(window).min()
    williams_r = -100.0 * (highest_high - close) / (highest_high - lowest_low + 1e-9)
    return williams_r


def calculate_rate_of_change(close: pd.Series, period: int = 12) -> pd.Series:
    roc = close.pct_change(periods=period) * 100.0
    return roc


def calculate_bollinger_bands(
    close: pd.Series,
    window: int = 20,
    num_std: float = 2.0,
) -> tuple[pd.Series, pd.Series, pd.Series, pd.Series]:
    sma = close.rolling(window).mean()
    std = close.rolling(window).std(ddof=0)
    upper = sma + num_std * std
    lower = sma - num_std * std
    width = (upper - lower) / (sma.abs() + 1e-9)
    percent_b = (close - lower) / (upper - lower + 1e-9)
    return upper, lower, width, percent_b


def calculate_average_true_range(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    window: int = 14,
) -> pd.Series:
    prev_close = close.shift(1)
    tr_components = pd.concat(
        [
            high - low,
            (high - prev_close).abs(),
            (low - prev_close).abs(),
        ],
        axis=1,
    )
    true_range = tr_components.max(axis=1)
    atr = true_range.ewm(alpha=1.0 / window, adjust=False).mean()
    return atr


def calculate_adx(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    window: int = 14,
) -> tuple[pd.Series, pd.Series, pd.Series]:
    prev_high = high.shift(1)
    prev_low = low.shift(1)
    up_move = (high - prev_high).fillna(0.0)
    down_move = (prev_low - low).fillna(0.0)

    plus_dm = np.where((up_move > down_move) & (up_move > 0.0), up_move, 0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0.0), down_move, 0.0)

    prev_close = close.shift(1)
    tr_components = pd.concat(
        [
            (high - low).abs(),
            (high - prev_close).abs(),
            (low - prev_close).abs(),
        ],
        axis=1,
    )
    true_range = tr_components.max(axis=1)
    atr = true_range.ewm(alpha=1.0 / window, adjust=False).mean()

    plus_dm_series = pd.Series(plus_dm, index=close.index)
    minus_dm_series = pd.Series(minus_dm, index=close.index)

    plus_di = 100.0 * plus_dm_series.ewm(alpha=1.0 / window, adjust=False).mean() / (atr + 1e-9)
    minus_di = 100.0 * minus_dm_series.ewm(alpha=1.0 / window, adjust=False).mean() / (atr + 1e-9)
    dx = (plus_di - minus_di).abs() / (plus_di + minus_di + 1e-9) * 100.0
    adx = dx.ewm(alpha=1.0 / window, adjust=False).mean()
    return adx, plus_di, minus_di


def calculate_obv(close: pd.Series, volume: pd.Series) -> pd.Series:
    direction = np.sign(close.diff().fillna(0.0))
    obv = (direction * volume.fillna(0.0)).cumsum()
    return obv


def calculate_money_flow_index(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    volume: pd.Series,
    window: int = 14,
) -> pd.Series:
    typical_price = (high + low + close) / 3.0
    raw_money_flow = typical_price * volume.fillna(0.0)

    price_diff = typical_price.diff().fillna(0.0)
    positive_flow = raw_money_flow.where(price_diff > 0.0, 0.0)
    negative_flow = raw_money_flow.where(price_diff < 0.0, 0.0).abs()

    pos_mf = positive_flow.rolling(window).sum()
    neg_mf = negative_flow.rolling(window).sum()
    money_flow_ratio = pos_mf / (neg_mf + 1e-9)
    mfi = 100.0 - (100.0 / (1.0 + money_flow_ratio))
    return mfi


def calculate_cci(
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    window: int = 20,
) -> pd.Series:
    typical_price = (high + low + close) / 3.0
    sma = typical_price.rolling(window).mean()
    mean_deviation = (typical_price - sma).abs().rolling(window).mean()
    cci = (typical_price - sma) / (0.015 * (mean_deviation + 1e-9))
    return cci
