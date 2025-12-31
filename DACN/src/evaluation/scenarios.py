from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Dict, Iterable, List

import json
import numpy as np
from stable_baselines3.common.base_class import BaseAlgorithm

from src.env.trading_env import EnvConfig
from src.evaluation.backtest import BacktestConfig, run_backtest


@dataclass
class ScenarioEvent:
    name: str
    date: np.datetime64
    lookback_days: int = 5
    lookahead_days: int = 5


@dataclass
class ScenarioResult:
    event: ScenarioEvent
    metrics: Dict[str, float]
    figure_path: Path | None


def load_events(path: Path) -> List[ScenarioEvent]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    events: List[ScenarioEvent] = []
    for entry in payload:
        events.append(
            ScenarioEvent(
                name=entry["name"],
                date=np.datetime64(entry["date"]),
                lookback_days=int(entry.get("lookback_days", 5)),
                lookahead_days=int(entry.get("lookahead_days", 5)),
            )
        )
    return events


def run_scenario_analysis(
    model: BaseAlgorithm,
    dataset: Dict[str, np.ndarray],
    base_env_config: EnvConfig,
    events: Iterable[ScenarioEvent],
    output_dir: Path,
    save_plots: bool = True,
    risk_free_rate: float = 0.0,
) -> List[ScenarioResult]:
    output_dir.mkdir(parents=True, exist_ok=True)
    date_array = dataset["dates"]
    date_array_str = date_array.astype(str)
    results: List[ScenarioResult] = []

    for idx, event in enumerate(events):
        target_str = str(event.date)
        # Try to match by string first
        if target_str not in date_array_str:
            # Fallback to original logic if needed, or just continue
            continue
            
        event_index = int(np.where(date_array_str == target_str)[0][0])
        start_index = max(event_index - event.lookback_days, base_env_config.window_size)
        end_index = min(event_index + event.lookahead_days, len(date_array) - 1)

        env_config = replace(base_env_config, start_index=start_index, end_index=end_index)
        figure_dir = output_dir / f"scenario_{idx:02d}"
        backtest_cfg = BacktestConfig(figure_dir=figure_dir, save_plots=save_plots)
        metrics = run_backtest(model, dataset, env_config, backtest_cfg, risk_free_rate=risk_free_rate)
        figure_path = (figure_dir / "ppo_backtest.png") if save_plots else None
        results.append(
            ScenarioResult(
                event=event,
                metrics=metrics,
                figure_path=figure_path,
            )
        )

    return results
