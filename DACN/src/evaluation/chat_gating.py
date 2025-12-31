from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

import math
import statistics


@dataclass
class Thresholds:
    forward_sharpe_min: float
    forward_drawdown_max: float
    evaluation_sharpe_min: float
    evaluation_hit_ratio_min: float
    evaluation_direction_accuracy_min: float
    walkforward_mean_sharpe_min: float
    walkforward_positive_fraction_min: float
    scenario_min_sharpe_min: float


def _load_json(path: Optional[Path]) -> Optional[Any]:
    if path is None:
        return None
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return None


def _status_from_checks(checks: Iterable[bool], missing: bool = False) -> str:
    if missing:
        return "missing"
    failed = [check for check in checks if not check]
    return "pass" if not failed else "fail"


def _clean_float(value: float) -> Optional[float]:
    if math.isnan(value):
        return None
    return value


def evaluate_evaluation_metrics(data: Optional[Dict[str, Any]], thresholds: Thresholds) -> Dict[str, Any]:
    if data is None:
        return {"status": "missing"}
    sharpe = float(data.get("sharpe_ratio", float("nan")))
    hit_ratio = float(data.get("hit_ratio", float("nan")))
    direction_accuracy = float(data.get("avg_direction_accuracy", float("nan")))
    checks = [
        sharpe >= thresholds.evaluation_sharpe_min,
        hit_ratio >= thresholds.evaluation_hit_ratio_min,
        direction_accuracy >= thresholds.evaluation_direction_accuracy_min,
    ]
    status = _status_from_checks(checks)
    return {
        "status": status,
        "sharpe_ratio": _clean_float(sharpe),
        "hit_ratio": _clean_float(hit_ratio),
        "avg_direction_accuracy": _clean_float(direction_accuracy),
    }


def evaluate_forward_metrics(data: Optional[Dict[str, Any]], thresholds: Thresholds) -> Dict[str, Any]:
    if data is None:
        return {"status": "missing"}
    metrics = data.get("metrics", {}) if isinstance(data, dict) else {}
    sharpe = float(metrics.get("sharpe_ratio", float("nan")))
    drawdown = float(metrics.get("max_drawdown", float("nan")))
    hit_ratio = float(metrics.get("hit_ratio", float("nan")))
    checks = [
        sharpe >= thresholds.forward_sharpe_min,
        drawdown >= thresholds.forward_drawdown_max,
    ]
    status = _status_from_checks(checks)
    return {
        "status": status,
        "sharpe_ratio": _clean_float(sharpe),
        "max_drawdown": _clean_float(drawdown),
        "hit_ratio": _clean_float(hit_ratio),
    }


def evaluate_walkforward_metrics(data: Optional[Dict[str, Any]], thresholds: Thresholds) -> Dict[str, Any]:
    if data is None:
        return {"status": "missing"}
    splits = data.get("splits", []) if isinstance(data, dict) else []
    if not splits:
        return {"status": "missing"}
    sharpe_values: List[float] = []
    positive = 0
    for split in splits:
        metrics = split.get("metrics", {})
        sharpe = float(metrics.get("sharpe_ratio", float("nan")))
        if math.isnan(sharpe):
            continue
        sharpe_values.append(sharpe)
        if sharpe > 0:
            positive += 1
    if not sharpe_values:
        return {"status": "missing"}
    mean_sharpe = statistics.fmean(sharpe_values)
    positive_fraction = positive / len(sharpe_values)
    min_sharpe = min(sharpe_values)
    checks = [
        mean_sharpe >= thresholds.walkforward_mean_sharpe_min,
        positive_fraction >= thresholds.walkforward_positive_fraction_min,
    ]
    status = _status_from_checks(checks)
    return {
        "status": status,
        "mean_sharpe": _clean_float(mean_sharpe),
        "positive_fraction": _clean_float(positive_fraction),
        "min_sharpe": _clean_float(min_sharpe),
        "split_count": len(sharpe_values),
    }


def evaluate_scenario_metrics(data: Optional[Dict[str, Any]], thresholds: Thresholds) -> Dict[str, Any]:
    if data is None:
        return {"status": "missing"}
    events = data.get("events", []) if isinstance(data, dict) else []
    if not events:
        return {"status": "missing"}
    sharpe_values: List[float] = []
    for event in events:
        metrics = event.get("metrics", {})
        sharpe = float(metrics.get("sharpe_ratio", float("nan")))
        if math.isnan(sharpe):
            continue
        sharpe_values.append(sharpe)
    if not sharpe_values:
        return {"status": "missing"}
    min_sharpe = min(sharpe_values)
    mean_sharpe = statistics.fmean(sharpe_values)
    checks = [min_sharpe >= thresholds.scenario_min_sharpe_min]
    status = _status_from_checks(checks)
    return {
        "status": status,
        "min_sharpe": _clean_float(min_sharpe),
        "mean_sharpe": _clean_float(mean_sharpe),
        "event_count": len(sharpe_values),
    }


def compile_gating_report(
    ticker: str,
    evaluation_path: Optional[Path],
    forward_path: Optional[Path],
    walkforward_path: Optional[Path],
    scenario_path: Optional[Path],
    thresholds: Thresholds,
) -> Dict[str, Any]:
    evaluation_data = _load_json(evaluation_path)
    forward_data = _load_json(forward_path)
    walkforward_data = _load_json(walkforward_path)
    scenario_data = _load_json(scenario_path)

    evaluation_summary = evaluate_evaluation_metrics(evaluation_data, thresholds)
    forward_summary = evaluate_forward_metrics(forward_data, thresholds)
    walkforward_summary = evaluate_walkforward_metrics(walkforward_data, thresholds)
    scenario_summary = evaluate_scenario_metrics(scenario_data, thresholds)

    statuses = [
        evaluation_summary.get("status"),
        forward_summary.get("status"),
        walkforward_summary.get("status"),
        scenario_summary.get("status"),
    ]
    if any(status == "fail" for status in statuses):
        overall = "fail"
    elif any(status == "missing" for status in statuses):
        overall = "pending"
    else:
        overall = "pass"

    return {
        "ticker": ticker,
        "overall_status": overall,
        "evaluation": evaluation_summary,
        "forward": forward_summary,
        "walkforward": walkforward_summary,
        "scenarios": scenario_summary,
    }


def write_gating_report(
    output_path: Path,
    tickers: Dict[str, Dict[str, Optional[Path]]],
    thresholds: Thresholds,
) -> Dict[str, Any]:
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "thresholds": thresholds.__dict__,
        "tickers": {},
    }
    for ticker, paths in tickers.items():
        report = compile_gating_report(
            ticker=ticker,
            evaluation_path=paths.get("evaluation"),
            forward_path=paths.get("forward"),
            walkforward_path=paths.get("walkforward"),
            scenario_path=paths.get("scenarios"),
            thresholds=thresholds,
        )
        payload["tickers"][ticker] = report
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    return payload
