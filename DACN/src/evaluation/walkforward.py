from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Dict, Iterable, List, Sequence

import numpy as np
from stable_baselines3.common.base_class import BaseAlgorithm

from src.env.trading_env import EnvConfig
from src.evaluation.backtest import BacktestConfig, run_backtest


@dataclass
class WalkForwardWindow:
    index: int
    start_index: int
    end_index: int


@dataclass
class WalkForwardResult:
    window: WalkForwardWindow
    metrics: Dict[str, float]
    figure_path: Path | None


def generate_walkforward_windows(
    available_range: Sequence[int],
    window_size: int,
    step_size: int,
) -> List[WalkForwardWindow]:
    start_indices = np.arange(available_range[0], available_range[1] - window_size + 1, step_size, dtype=int)
    windows: List[WalkForwardWindow] = []
    for idx, start in enumerate(start_indices):
        windows.append(
            WalkForwardWindow(
                index=idx,
                start_index=int(start),
                end_index=int(start + window_size - 1),
            )
        )
    return windows


def run_walkforward_evaluation(
    model: BaseAlgorithm,
    dataset: Dict[str, np.ndarray],
    base_env_config: EnvConfig,
    windows: Iterable[WalkForwardWindow],
    output_dir: Path,
    save_plots: bool = True,
    risk_free_rate: float = 0.0,
) -> List[WalkForwardResult]:
    output_dir.mkdir(parents=True, exist_ok=True)
    results: List[WalkForwardResult] = []

    for window in windows:
        env_config = replace(base_env_config, start_index=window.start_index, end_index=window.end_index)
        figure_dir = output_dir / f"split_{window.index:02d}"
        backtest_cfg = BacktestConfig(figure_dir=figure_dir, save_plots=save_plots)
        metrics = run_backtest(model, dataset, env_config, backtest_cfg, risk_free_rate=risk_free_rate)
        figure_path = (figure_dir / "ppo_backtest.png") if save_plots else None
        results.append(
            WalkForwardResult(
                window=window,
                metrics=metrics,
                figure_path=figure_path,
            )
        )

    return results
