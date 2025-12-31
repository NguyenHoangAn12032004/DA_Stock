from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional

import matplotlib.pyplot as plt
import numpy as np
from stable_baselines3.common.base_class import BaseAlgorithm

from src.env.trading_env import EnvConfig, TradingEnv
from src.evaluation.metrics import compute_backtest_metrics


@dataclass
class BacktestConfig:
    figure_dir: Path
    save_plots: bool = True
    benchmark: Optional[str] = None


def run_backtest(
    model: BaseAlgorithm,
    dataset: Dict[str, np.ndarray],
    env_config: EnvConfig,
    backtest_config: BacktestConfig,
    risk_free_rate: float = 0.0,
) -> Dict[str, float]:
    env = TradingEnv(dataset, env_config)
    obs, _ = env.reset()
    done = False
    max_steps = env.end_index - env.start_index
    steps = 0
    while not done and steps < max_steps:
        action, _ = model.predict(obs, deterministic=True)
        obs, _, terminated, truncated, _ = env.step(action)
        done = terminated or truncated
        steps += 1

    values = np.array([env.initial_cash] + env.history["values"])
    metrics = compute_backtest_metrics(
        values,
        trade_mask=np.array(env.history["trade_mask"], dtype=np.float32),
        direction_accuracy=np.array(env.history["direction_accuracy"], dtype=np.float32),
        direction_correct=np.array(env.history["direction_correct"], dtype=np.float32),
    )

    # Optional: attach debug-driven counters if available
    # FP filter activation count (requires debug_flags_enabled in EnvConfig)
    if isinstance(env.history, dict) and "fp_filter_block" in env.history:
        try:
            arr = np.array(env.history["fp_filter_block"], dtype=np.int32)
            count = int(arr.sum())
            total = int(arr.size)
            metrics["fp_filter_block_count"] = count
            metrics["fp_filter_block_rate"] = float(count / total) if total > 0 else 0.0
        except Exception:
            pass

    benchmark_values = None
    if backtest_config.save_plots:
        backtest_config.figure_dir.mkdir(parents=True, exist_ok=True)
        fig_path = backtest_config.figure_dir / "ppo_backtest.png"
        
        benchmark_values = None
        if backtest_config.benchmark == "buy_and_hold":
             benchmark_metrics_raw = _compute_buy_and_hold_metrics(env, risk_free_rate, return_values=True)
             benchmark_values = benchmark_metrics_raw.get("values")

        _plot_performance(env, metrics, fig_path, benchmark_values)

    if backtest_config.benchmark == "buy_and_hold":
        if benchmark_values is None: # If not computed above
             benchmark_metrics = _compute_buy_and_hold_metrics(env, risk_free_rate)
        else:
             # Re-use computed metrics if possible, but _compute_buy_and_hold_metrics returns dict.
             # Let's adjust _compute_buy_and_hold_metrics to optionally return values.
             # For now, just re-compute or refactor.
             benchmark_metrics = _compute_buy_and_hold_metrics(env, risk_free_rate)
             
        metrics.update({f"benchmark_{key}": value for key, value in benchmark_metrics.items()})

    return metrics


def _plot_performance(env: TradingEnv, metrics: Dict[str, float], fig_path: Path, benchmark_values: np.ndarray = None) -> None:
    dates = env.history["dates"]
    values = env.history["values"]
    
    plt.figure(figsize=(12, 6))
    plt.plot(dates, values, label="PPO Portfolio", linewidth=2)
    
    if benchmark_values is not None:
        # Ensure benchmark_values matches length of dates
        if len(benchmark_values) == len(dates):
            plt.plot(dates, benchmark_values, label="Buy & Hold (Benchmark)", linestyle="--", alpha=0.7)
    
    plt.title("RL Portfolio vs Benchmark")
    plt.xlabel("Date")
    plt.ylabel("Portfolio Value (USD)")
    
    stats = (
        f"Total Return: {metrics['total_return']*100:.2f}%\n"
        f"Sharpe: {metrics['sharpe_ratio']:.2f}\n"
        f"Max Drawdown: {metrics['max_drawdown']*100:.2f}%"
    )
    plt.annotate(stats, xy=(0.02, 0.65), xycoords="axes fraction", bbox=dict(boxstyle="round", facecolor="white", alpha=0.8))
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(fig_path, dpi=200)
    plt.close()


def _compute_buy_and_hold_metrics(env: TradingEnv, risk_free_rate: float, return_values: bool = False) -> Dict[str, float | np.ndarray]:
    start_idx = env.start_index
    end_idx = env.end_index if env.end_index is not None else (env.n_steps - 1)
    if end_idx < start_idx:
        end_idx = start_idx

    returns_slice = env.returns[start_idx : end_idx + 1]
    if returns_slice.ndim == 2 and returns_slice.shape[1] > 0:
        simple_returns = np.expm1(returns_slice).mean(axis=1)
    else:
        simple_returns = np.expm1(returns_slice)

    cumulative = np.concatenate([[1.0], np.cumprod(1.0 + simple_returns)])
    # Adjust length to match env history if needed (env history has initial value + steps)
    # env.history['values'] has length (steps + 1)
    
    # If returns_slice has length N, cumulative has length N+1.
    # This should match.
    
    values = env.initial_cash * cumulative

    metrics = compute_backtest_metrics(values, risk_free_rate=risk_free_rate)
    if return_values:
        metrics["values"] = values
    return metrics
