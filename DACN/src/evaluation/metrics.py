from __future__ import annotations

from dataclasses import dataclass
from typing import Dict

import numpy as np


@dataclass
class BacktestReport:
    total_return: float
    annualized_return: float
    annualized_volatility: float
    sharpe_ratio: float
    max_drawdown: float
    hit_ratio: float
    cumulative_values: np.ndarray
    dates: np.ndarray


def compute_backtest_metrics(
    portfolio_values: np.ndarray,
    risk_free_rate: float = 0.0,
    trade_mask: np.ndarray | None = None,
    direction_accuracy: np.ndarray | None = None,
    direction_correct: np.ndarray | None = None,
) -> Dict[str, float]:
    values = np.asarray(portfolio_values, dtype=np.float64)
    returns = np.diff(values) / values[:-1]
    log_returns = np.log1p(returns)
    total_return = values[-1] / values[0] - 1.0
    annual_factor = 252
    annualized_return = np.expm1(log_returns.mean() * annual_factor) if len(log_returns) > 0 else 0.0
    annualized_volatility = log_returns.std(ddof=1) * np.sqrt(annual_factor) if len(log_returns) > 1 else 0.0
    sharpe_ratio = 0.0
    if annualized_volatility > 1e-9:
        sharpe_ratio = (annualized_return - risk_free_rate) / annualized_volatility
    running_max = np.maximum.accumulate(values)
    drawdowns = (values - running_max) / running_max
    max_drawdown = drawdowns.min() if len(drawdowns) else 0.0

    metrics: Dict[str, float] = {
        "total_return": float(total_return),
        "annualized_return": float(annualized_return),
        "annualized_volatility": float(annualized_volatility),
        "sharpe_ratio": float(sharpe_ratio),
        "max_drawdown": float(max_drawdown),
    }

    step_hit_ratio = float((returns > 0).sum()) / max(len(returns), 1)
    metrics["step_hit_ratio"] = step_hit_ratio

    if trade_mask is not None and direction_correct is not None:
        trades = np.asarray(trade_mask, dtype=bool)
        correct = np.asarray(direction_correct, dtype=np.float64)
        trade_count = int(trades.sum())
        metrics["trade_count"] = float(trade_count)
        metrics["trade_rate"] = float(trade_count) / max(len(trades), 1)
        if trade_count > 0:
            metrics["hit_ratio"] = float(correct[trades].mean())
        else:
            metrics["hit_ratio"] = 0.0
    else:
        metrics["trade_count"] = 0.0
        metrics["trade_rate"] = 0.0
        metrics["hit_ratio"] = step_hit_ratio

    if direction_accuracy is not None and trade_mask is not None:
        trades = np.asarray(trade_mask, dtype=bool)
        accuracies = np.asarray(direction_accuracy, dtype=np.float64)
        trade_count = trades.sum()
        metrics["avg_direction_accuracy"] = float(accuracies[trades].mean()) if trade_count > 0 else 0.0
    else:
        metrics["avg_direction_accuracy"] = 0.0

    return metrics
