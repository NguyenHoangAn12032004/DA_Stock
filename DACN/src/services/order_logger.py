"""Lightweight CSV logger for realtime trade recommendations/orders.

This module provides a tiny utility to append BUY/SELL signals to a per-symbol
CSV file under a designated reports directory. It's intentionally simple and
robust: it creates directories as needed, writes a header on first use, and
never raises on I/O errors (it logs them instead).
"""
from __future__ import annotations

import csv
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional


LOGGER = logging.getLogger(__name__)


@dataclass
class OrderRecord:
    symbol: str
    timestamp_iso: str
    action: str
    probability: Optional[float]
    close: Optional[float]
    open: Optional[float] = None
    high: Optional[float] = None
    low: Optional[float] = None
    volume: Optional[float] = None
    source: Optional[str] = None
    thresholds: Optional[Dict[str, float]] = None
    context: Optional[Dict[str, Any]] = None


class OrderLogger:
    """Append-only CSV logger for realtime orders per symbol."""

    def __init__(self, base_dir: Path | str = "reports/orders") -> None:
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _file_for(self, symbol: str) -> Path:
        return self.base_dir / f"{symbol.upper()}.csv"

    def log(self, record: OrderRecord) -> None:
        """Append the provided record to the symbol CSV. Never raises on I/O.

        Fields written:
        - timestamp, symbol, action, probability, price(close/open/high/low), volume, source
        - thresholds (JSON), context (JSON)
        """
        try:
            file_path = self._file_for(record.symbol)
            is_new = not file_path.exists()
            fieldnames = [
                "timestamp",
                "symbol",
                "action",
                "probability",
                "close",
                "open",
                "high",
                "low",
                "volume",
                "source",
                "thresholds_json",
                "context_json",
            ]
            row = {
                "timestamp": record.timestamp_iso,
                "symbol": record.symbol.upper(),
                "action": record.action,
                "probability": (f"{record.probability:.6f}" if record.probability is not None else ""),
                "close": (f"{record.close:.6f}" if record.close is not None else ""),
                "open": (f"{record.open:.6f}" if record.open is not None else ""),
                "high": (f"{record.high:.6f}" if record.high is not None else ""),
                "low": (f"{record.low:.6f}" if record.low is not None else ""),
                "volume": (f"{record.volume:.0f}" if record.volume is not None else ""),
                "source": record.source or "",
                "thresholds_json": json.dumps(record.thresholds or {}),
                "context_json": json.dumps(record.context or {}),
            }
            with file_path.open("a", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=fieldnames)
                if is_new:
                    writer.writeheader()
                writer.writerow(row)
        except Exception:  # pragma: no cover - logging should not crash the service
            LOGGER.exception("Failed to write order record for %s", record.symbol)
