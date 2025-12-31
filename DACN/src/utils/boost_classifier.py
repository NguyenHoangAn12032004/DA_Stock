"""Utility to train boosted direction models with basic evaluation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, Tuple

import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, brier_score_loss


@dataclass
class BoostDataset:
    features: np.ndarray
    labels: np.ndarray
    feature_names: Tuple[str, ...]


def train_gradient_boost(
    dataset: BoostDataset,
    val_fraction: float,
    random_state: int,
    min_train_fraction: float = 0.7,
) -> Dict[str, float]:
    """Train a gradient boosting classifier with chronological validation split."""

    if not 0.0 < val_fraction < 0.5:
        raise ValueError("val_fraction must lie in (0, 0.5)")

    n_samples = dataset.features.shape[0]
    train_end = max(int(n_samples * min_train_fraction), 1)
    val_start = max(int(train_end * (1 - val_fraction)), 1)

    X_train = dataset.features[:val_start]
    y_train = dataset.labels[:val_start]
    X_val = dataset.features[val_start:train_end]
    y_val = dataset.labels[val_start:train_end]

    if X_val.shape[0] == 0:
        raise ValueError("Validation split is empty; consider increasing val_fraction.")

    model = GradientBoostingClassifier(
        n_estimators=300,
        learning_rate=0.05,
        max_depth=3,
        subsample=0.8,
        random_state=random_state,
    )
    model.fit(X_train, y_train)

    val_probs = model.predict_proba(X_val)[:, 1]
    val_preds = (val_probs >= 0.5).astype(np.int8)

    metrics: Dict[str, float] = {
        "val_brier_score": float(brier_score_loss(y_val, val_probs)),
        "val_accuracy": float(accuracy_score(y_val, val_preds)),
        "train_samples": float(X_train.shape[0]),
        "val_samples": float(X_val.shape[0]),
    }

    importances = getattr(model, "feature_importances_", None)
    if importances is not None:
        pairs = sorted(zip(dataset.feature_names, importances), key=lambda kv: kv[1], reverse=True)
        metrics["feature_importance_top10"] = {name: float(score) for name, score in pairs[:10] if score > 0}

    metrics["model"] = model
    return metrics
