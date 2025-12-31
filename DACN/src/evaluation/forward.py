from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Sequence

import json
import csv

import numpy as np
from stable_baselines3.common.base_class import BaseAlgorithm

from src.env.trading_env import EnvConfig, TradingEnv
from src.evaluation.metrics import compute_backtest_metrics


@dataclass
class ForwardRunConfig:
    output_dir: Path
    run_name: str | None = None
    extra_slippage_bps: float = 0.0
    risk_free_rate: float = 0.0
    save_csv: bool = True
    save_summary: bool = True


@dataclass
class ForwardRunArtifacts:
    log_path: Path | None
    summary_path: Path | None
    metrics: Dict[str, float]
    run_name: str


def _prepare_output_dir(config: ForwardRunConfig) -> Path:
    run_name = config.run_name or datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    run_dir = config.output_dir / run_name
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def _build_fieldnames(tickers: Sequence[str]) -> List[str]:
    base = [
        "step",
        "date",
        "portfolio_value",
        "net_return",
        "turnover",
        "transaction_cost",
        "slippage_cost",
    ]
    per_ticker = []
    for ticker in tickers:
        per_ticker.extend(
            [
                f"price_{ticker}",
                f"action_{ticker}",
                f"weight_{ticker}",
                f"direction_prob_{ticker}",
            ]
        )
    return base + per_ticker


def _build_record(
    step: int,
    date_value: np.datetime64,
    portfolio_value: float,
    net_return: float,
    turnover: float,
    transaction_cost: float,
    slippage_cost: float,
    tickers: Sequence[str],
    prices: np.ndarray,
    action: np.ndarray,
    weights: np.ndarray,
    direction_prob: np.ndarray | None,
) -> Dict[str, float]:
    record: Dict[str, float] = {
        "step": float(step),
        "date": np.datetime_as_string(date_value, unit="D"),
        "portfolio_value": float(portfolio_value),
        "net_return": float(net_return),
        "turnover": float(turnover),
        "transaction_cost": float(transaction_cost),
        "slippage_cost": float(slippage_cost),
    }

    for idx, ticker in enumerate(tickers):
        record[f"price_{ticker}"] = float(prices[idx])
        record[f"action_{ticker}"] = float(action[idx])
        record[f"weight_{ticker}"] = float(weights[idx])
        prob_value = float(direction_prob[idx]) if direction_prob is not None else np.nan
        record[f"direction_prob_{ticker}"] = prob_value

    return record


def run_forward_paper(
    model: BaseAlgorithm,
    dataset: Dict[str, np.ndarray],
    env_config: EnvConfig,
    run_config: ForwardRunConfig,
) -> ForwardRunArtifacts:
    env = TradingEnv(dataset, env_config)
    obs, _ = env.reset()

    output_root = _prepare_output_dir(run_config)
    tickers = dataset.get("tickers")
    if tickers is None:
        raise ValueError("Dataset dictionary must include 'tickers'.")

    log_records: List[Dict[str, float]] = []
    slippage_costs: List[float] = []
    transaction_costs: List[float] = []

    extra_slippage = max(run_config.extra_slippage_bps, 0.0) / 10000.0
    step = 0
    done = False
    while not done:
        prev_value = float(env.portfolio_value)
        action, _ = model.predict(obs, deterministic=True)
        obs, _reward, terminated, truncated, info = env.step(action)

        transaction_cost = float(info.get("cost", 0.0))
        slippage_cost = 0.0
        if extra_slippage > 0.0:
            turnover = float(info.get("turnover", 0.0))
            if turnover > 0.0:
                slippage_cost = extra_slippage * turnover * float(env.portfolio_value)
                if slippage_cost > 0.0:
                    env.portfolio_value = max(float(env.portfolio_value) - slippage_cost, 1e-6)
                    env.history["values"][-1] = env.portfolio_value
        else:
            turnover = float(info.get("turnover", 0.0))

        current_value = float(env.portfolio_value)
        net_return = (current_value / max(prev_value, 1e-6)) - 1.0

        price_idx = env.current_step - 1
        date_value = env.dates[price_idx]
        prices = dataset["prices"][price_idx]
        direction_probs = None
        if env.history["direction_prob"]:
            direction_probs = env.history["direction_prob"][-1]

        record = _build_record(
            step=step,
            date_value=date_value,
            portfolio_value=current_value,
            net_return=net_return,
            turnover=turnover,
            transaction_cost=transaction_cost,
            slippage_cost=slippage_cost,
            tickers=tickers,
            prices=prices,
            action=np.asarray(action).reshape(-1),
            weights=env.portfolio_weights,
            direction_prob=direction_probs,
        )
        log_records.append(record)
        slippage_costs.append(slippage_cost)
        transaction_costs.append(transaction_cost)

        step += 1
        done = terminated or truncated

    values = np.array([env.initial_cash] + env.history["values"], dtype=np.float64)
    trade_mask = np.array(env.history["trade_mask"], dtype=np.float32)
    direction_accuracy = np.array(env.history["direction_accuracy"], dtype=np.float32)
    direction_correct = np.array(env.history["direction_correct"], dtype=np.float32)

    metrics = compute_backtest_metrics(
        values,
        risk_free_rate=run_config.risk_free_rate,
        trade_mask=trade_mask,
        direction_accuracy=direction_accuracy,
        direction_correct=direction_correct,
    )
    metrics["transaction_cost_total"] = float(np.sum(transaction_costs))
    metrics["slippage_cost_total"] = float(np.sum(slippage_costs))
    metrics["final_portfolio_value"] = float(values[-1])

    csv_path: Path | None = None
    summary_path: Path | None = None

    if run_config.save_csv:
        csv_path = output_root / "forward_log.csv"
        fieldnames = _build_fieldnames(tickers)
        with csv_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            for row in log_records:
                writer.writerow(row)

    if run_config.save_summary:
        summary_path = output_root / "summary.json"
        summary_payload = {
            "run_name": output_root.name,
            "start_date": log_records[0]["date"] if log_records else None,
            "end_date": log_records[-1]["date"] if log_records else None,
            "extra_slippage_bps": run_config.extra_slippage_bps,
            "risk_free_rate": run_config.risk_free_rate,
            "metrics": metrics,
        }
        with summary_path.open("w", encoding="utf-8") as handle:
            json.dump(summary_payload, handle, indent=2)

    return ForwardRunArtifacts(
        log_path=csv_path,
        summary_path=summary_path,
        metrics=metrics,
        run_name=output_root.name,
    )
