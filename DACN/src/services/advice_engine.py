"""High-level interface for retrieving trading advice derived from evaluations."""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional

import pandas as pd

from src.evaluation.advice import AdviceConfig, generate_advice_table


@dataclass
class AdviceEngine:
    """Wrapper around ``generate_advice_table`` with convenience accessors.

    Parameters
    ----------
    metrics_path:
        Location of the aggregated forward metrics table (CSV/JSON) produced
        by ``scripts/compile_forward_reports.py``.
    advice_config:
        Optional ``AdviceConfig`` controlling thresholds.
    tickers:
        Optional ticker allowlist. Leave ``None`` to keep every asset found in
        ``metrics_path``.
    """

    metrics_path: Path = Path("reports/forward_paper/forward_metrics.csv")
    advice_config: AdviceConfig = field(default_factory=AdviceConfig)
    tickers: Optional[Iterable[str]] = None
    _advice_table: Optional[pd.DataFrame] = field(default=None, init=False, repr=False)

    def refresh(self) -> pd.DataFrame:
        """Reload metrics from disk and rebuild the advice table."""

        self._advice_table = generate_advice_table(
            source=self.metrics_path,
            config=self.advice_config,
            tickers=self.tickers,
        )
        return self._advice_table

    @property
    def advice_table(self) -> pd.DataFrame:
        """Return the cached advice table, refreshing it on demand."""

        if self._advice_table is None:
            return self.refresh()
        return self._advice_table

    def list_tickers(self) -> list[str]:
        """Return sorted list of tickers present in the advice table."""

        df = self.advice_table
        if "ticker" not in df.columns:
            return []
        return sorted(df["ticker"].dropna().astype(str).unique())

    def list_runs(self, ticker: Optional[str] = None) -> pd.DataFrame:
        """Return runs filtered by ticker (or all runs if ticker is None)."""

        df = self.advice_table
        if ticker:
            mask = df["ticker"].str.upper() == ticker.upper()
            return df[mask].copy()
        return df.copy()

    def get_top_runs(
        self,
        ticker: str,
        limit: int = 3,
        sort_by: str = "sharpe_ratio",
        ascending: bool = False,
    ) -> pd.DataFrame:
        """Return the top runs for a ticker sorted by the chosen metric."""

        runs = self.list_runs(ticker)
        if runs.empty or sort_by not in runs.columns:
            return runs.head(0)
        return runs.sort_values(sort_by, ascending=ascending).head(limit)

    def describe_run(self, run_name: str) -> Optional[str]:
        """Build a human-readable description of a specific run."""

        df = self.advice_table
        run = df[df["run_name"] == run_name]
        if run.empty:
            return None
        row = run.iloc[0]
        start = row.get("start_date")
        end = row.get("end_date")
        start_str = start.strftime("%Y-%m-%d") if isinstance(start, pd.Timestamp) else "?"
        end_str = end.strftime("%Y-%m-%d") if isinstance(end, pd.Timestamp) else "?"
        return (
            f"{row['ticker']} / {row['run_name']} ({start_str} → {end_str})"\
            f" | recommendation: {row['recommendation']} ({row['confidence']})"\
            f" | sharpe {row['sharpe_ratio']:.2f} | return {row['total_return']:.2%}"\
            f" | trades {int(row['trade_count'])} | {row['rationale']}"
        )

    def summarize_ticker(self, ticker: str, limit: int = 3) -> str:
        """Produce a multi-line summary of the best runs for a ticker."""

        runs = self.get_top_runs(ticker=ticker, limit=limit)
        if runs.empty:
            return f"No runs found for {ticker}."
        lines = [f"Top {len(runs)} runs for {ticker}:"]
        for _, row in runs.iterrows():
            lines.append(
                f"- {row['run_name']}: {row['recommendation']} ({row['confidence']}),"
                f" sharpe {row['sharpe_ratio']:.2f}, return {row['total_return']:.2%},"
                f" trades {int(row['trade_count'])}"
            )
        return "\n".join(lines)

    def to_dict(self) -> dict[str, pd.DataFrame]:
        """Expose raw advice table for serialization (e.g., API response)."""

        df = self.advice_table
        payload = df.copy()
        for col in ("start_date", "end_date"):
            if col in payload.columns:
                payload[col] = payload[col].astype(str)
        return {"advice": payload.to_dict(orient="records")}


__all__ = ["AdviceEngine"]
