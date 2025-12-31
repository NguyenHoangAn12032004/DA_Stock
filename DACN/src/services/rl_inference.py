"""RL inference helper utilities for serving latest PPO-based signals.

This module loads a trained PPO model and the corresponding dataset/config,
rolls the TradingEnv to the most recent step, and returns a concise signal
summary suitable for API responses or chat surfaces.
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, Optional

import yaml
import numpy as np
from stable_baselines3 import PPO

from src.data.loader import MarketDataset
from src.env.trading_env import EnvConfig, TradingEnv


def _build_env_config(config_yaml: dict, start_index: int, end_index: int) -> EnvConfig:
    env_kwargs = dict(
        window_size=config_yaml["environment"]["window_size"],
        initial_cash=config_yaml["environment"]["initial_cash"],
        transaction_cost=config_yaml["environment"]["transaction_cost"],
        max_position=config_yaml["environment"]["max_position"],
        reward_metric=config_yaml["environment"].get("reward_metric", "differential_log_return"),
        reward_positive=config_yaml["environment"].get("reward_positive", 1.0),
        reward_negative=config_yaml["environment"].get("reward_negative", -1.0),
        reward_scale=config_yaml["environment"].get("reward_scale", 1.0),
        action_threshold=config_yaml["environment"].get("action_threshold", 0.0),
        direction_reward_weight=config_yaml["environment"].get("direction_reward_weight", 0.0),
        trade_penalty=config_yaml["environment"].get("trade_penalty", 0.0),
        direction_prob_threshold=config_yaml["environment"].get("direction_prob_threshold", 0.0),
        direction_prob_tolerance=config_yaml["environment"].get("direction_prob_tolerance", 0.0),
        cooldown_steps=config_yaml["environment"].get("cooldown_steps", 0),
        hold_bonus=config_yaml["environment"].get("hold_bonus", 0.0),
        low_vol_bonus=config_yaml["environment"].get("low_vol_bonus", 0.0),
        low_vol_threshold=config_yaml["environment"].get("low_vol_threshold", 0.0),
        volatility_lookback=config_yaml["environment"].get("volatility_lookback", 21),
        low_vol_direction_threshold=config_yaml["environment"].get("low_vol_direction_threshold", 0.0),
        subthreshold_trade_penalty=config_yaml["environment"].get("subthreshold_trade_penalty", 0.0),
        # Regime gating
        regime_gating_enabled=config_yaml["environment"].get("regime_gating_enabled", False),
        regime_momentum_lookback=config_yaml["environment"].get("regime_momentum_lookback", 20),
        regime_momentum_threshold=config_yaml["environment"].get("regime_momentum_threshold", 0.0),
        regime_adx_feature_idx=config_yaml["environment"].get("regime_adx_feature_idx"),
        regime_momentum_feature_idx=config_yaml["environment"].get("regime_momentum_feature_idx"),
        regime_adx_threshold=config_yaml["environment"].get("regime_adx_threshold", 20.0),
        regime_threshold_delta=config_yaml["environment"].get("regime_threshold_delta", 0.0),
        # V3 override
        override_gating_enabled=config_yaml["environment"].get("override_gating_enabled", False),
        override_momentum_threshold=config_yaml["environment"].get("override_momentum_threshold", 0.0),
        override_adx_threshold=config_yaml["environment"].get("override_adx_threshold", 20.0),
        override_min_duration=config_yaml["environment"].get("override_min_duration", 0),
        override_cooldown=config_yaml["environment"].get("override_cooldown", 0),
        override_action_threshold_mult=config_yaml["environment"].get("override_action_threshold_mult", 1.0),
        override_dpt_shift=config_yaml["environment"].get("override_dpt_shift", 0.0),
        override_regime_delta_override=config_yaml["environment"].get("override_regime_delta_override"),
        override_ignore_dpt=config_yaml["environment"].get("override_ignore_dpt", False),
        override_force_active=config_yaml["environment"].get("override_force_active", False),
        override_min_abs_weight=config_yaml["environment"].get("override_min_abs_weight", 0.0),
    )
    return EnvConfig(start_index=start_index, end_index=end_index, **env_kwargs)


def predict_latest(
    config_path: Path,
    model_path: Optional[Path] = None,
    include_feature_snapshot: bool = True,
    snapshot_features: Optional[list[str]] = None,
    evaluation_index: Optional[int] = None,
) -> Dict[str, object]:
    """Run PPO policy over the test segment up to the latest bar (or specific index) and return last-step signal.

    Returns a dict with fields: symbol, date, action (BUY/SELL/HOLD),
    weight, direction_prob, portfolio_value, and some context.
    """
    with Path(config_path).open("r", encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)

    dataset = MarketDataset.load(Path(cfg["data"]["dataset_path"]), feature_subset=cfg["data"].get("feature_subset"))
    dataset_dict = {
        "features": dataset.features,
        "prices": dataset.prices,
        "returns": dataset.returns,
        "dates": dataset.dates,
        "tickers": dataset.tickers,
        "feature_names": dataset.feature_names,
        "scaler_mean": dataset.scaler_mean,
        "scaler_scale": dataset.scaler_scale,
    }

    window_size = cfg["environment"]["window_size"]
    start_index = max(dataset.split_index, window_size)
    end_index = evaluation_index if evaluation_index is not None else (len(dataset.dates) - 1)
    env_cfg = _build_env_config(cfg, start_index, end_index)

    # Resolve model path (prefer explicit, else best_model.zip under model_dir)
    resolved_model = Path(model_path) if model_path else Path(cfg["project"]["model_dir"]) / "best_model.zip"
    model = PPO.load(resolved_model)

    env = TradingEnv(dataset_dict, env_cfg)
    obs, _ = env.reset()
    done = False
    last_info: Dict[str, object] = {}
    last_action = None
    while not done:
        action, _ = model.predict(obs, deterministic=True)
        obs, _r, terminated, truncated, info = env.step(action)
        done = terminated or truncated
        last_info = info
        last_action = action

    # Extract per-symbol outputs (single-asset expected, but support N)
    tickers = list(dataset.tickers)
    weights = env.history["weights"][-1] if env.history["weights"] else env.portfolio_weights
    dir_prob = env.history["direction_prob"][-1] if env.history["direction_prob"] else None
    date_value = env.history["dates"][-1] if env.history["dates"] else dataset.dates[end_index]

    signals: Dict[str, dict] = {}
    snapshots: Dict[str, dict] = {}
    # Build feature index map for snapshot (raw unscaled)
    feature_names = list(dataset.feature_names)
    name_to_idx = {n: i for i, n in enumerate(feature_names)}
    snapshot_features = snapshot_features or [
        "rsi", "rsi_trend", "atr_regime", "volatility_cluster", "adx_trend", "direction_prob"
    ]
    for i, sym in enumerate(tickers):
        w = float(weights[i]) if i < len(weights) else 0.0
        p = float(dir_prob[i]) if (dir_prob is not None and i < len(dir_prob)) else None
        if w > 1e-6:
            sig = "BUY"
        elif w < -1e-6:
            sig = "SELL"
        else:
            sig = "HOLD"
        signals[sym] = {"action": sig, "weight": w, "direction_prob": p}
        if include_feature_snapshot:
            raw_snapshot: Dict[str, float] = {}
            for fname in snapshot_features:
                idx = name_to_idx.get(fname)
                if idx is None:
                    continue
                val_scaled = float(dataset.features[end_index, i, idx])
                # Unscale if scaler arrays cover this index; else treat as already raw (e.g. direction_prob appended)
                if dataset.scaler_mean is not None and dataset.scaler_scale is not None and idx < len(dataset.scaler_mean):
                    mean = float(dataset.scaler_mean[idx])
                    scale = float(dataset.scaler_scale[idx])
                    raw_val = val_scaled * scale + mean
                else:
                    raw_val = val_scaled
                raw_snapshot[fname] = raw_val
            if p is not None:
                raw_snapshot["direction_prob"] = p
            snapshots[sym] = raw_snapshot

    payload: Dict[str, object] = {
        "date": np.datetime_as_string(date_value, unit="D"),
        "portfolio_value": float(env.portfolio_value),
        "tickers": tickers,
        "signals": signals,
    }
    if last_action is not None:
        payload["raw_action"] = np.asarray(last_action).reshape(-1).tolist()
    if include_feature_snapshot:
        payload["feature_snapshots"] = snapshots
    return payload
