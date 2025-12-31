"""Market data streaming service producing daily snapshots with signals."""
from __future__ import annotations

import asyncio
import logging
import os
import time
from collections import defaultdict, deque
from dataclasses import dataclass
from io import StringIO
from typing import Deque, Dict, Iterable, List, Optional, Tuple

import pandas as pd
import requests
import yfinance as yf

from src.services.directional_signal import DirectionalSignal, DirectionalSignalModel
from src.services.order_logger import OrderLogger, OrderRecord
from src.services.kalman import apply_kalman_filter, SimpleKalmanFilter

LOGGER = logging.getLogger(__name__)


@dataclass
class MarketSnapshot:
    """Single daily OHLCV bar accompanied by signal metadata."""

    symbol: str
    timestamp: pd.Timestamp
    open: float
    high: float
    low: float
    close: float
    volume: float
    source: str
    signal: Optional[DirectionalSignal] = None
    kalman_price: Optional[float] = None

    def as_payload(self) -> Dict[str, object]:
        payload: Dict[str, object] = {
            "type": "snapshot",
            "symbol": self.symbol,
            "timestamp": self.timestamp.isoformat(),
            "open": self.open,
            "high": self.high,
            "low": self.low,
            "close": self.close,
            "volume": self.volume,
            "source": self.source,
            "kalman_price": self.kalman_price,
        }
        if self.signal is not None:
            payload["recommendation"] = {
                "action": self.signal.signal,
                "probability": round(self.signal.probability, 4),
                "thresholds": self.signal.thresholds,
                "context": self.signal.context,
            }
        return payload


class MarketStreamService:
    """Polls daily market data and broadcasts snapshots to subscribers."""

    HISTORY_LIMIT = 512

    def __init__(
        self,
        symbols: Iterable[str],
        poll_interval: int = 900,
        lookback_days: int = 30,
        buy_threshold: float = 0.6,
        sell_threshold: float = 0.4,
        min_samples: int = 120,
        retrain_interval: int = 20,
    ) -> None:
        self.symbols = sorted({symbol.upper() for symbol in symbols})
        self.poll_interval = poll_interval
        self.lookback_days = lookback_days

        self._queues: Dict[str, List[asyncio.Queue[Dict[str, object]]]] = defaultdict(list)
        self._history_frames: Dict[str, pd.DataFrame] = {}
        self._history_payloads: Dict[str, Deque[Dict[str, object]]] = defaultdict(
            lambda: deque(maxlen=self.HISTORY_LIMIT)
        )
        self._models: Dict[str, DirectionalSignalModel] = {
            symbol: DirectionalSignalModel(
                symbol,
                buy_threshold=buy_threshold,
                sell_threshold=sell_threshold,
                min_samples=min_samples,
                retrain_interval=retrain_interval,
            )
            for symbol in self.symbols
        }
        self._tasks: List[asyncio.Task] = []
        self._lock = asyncio.Lock()
        self._finnhub_token = os.getenv("FINNHUB_API_KEY")
        self._active_source: Dict[str, str] = {symbol: "yfinance" for symbol in self.symbols}
        # Realtime order logger (per-symbol CSV under reports/orders)
        self._order_logger = OrderLogger()
        self._kalman_filters: Dict[str, SimpleKalmanFilter] = {}

    async def start(self) -> None:
        for symbol in self.symbols:
            await self._initialize_symbol(symbol)
            task = asyncio.create_task(self._run_symbol_loop(symbol))
            self._tasks.append(task)

    async def stop(self) -> None:
        tasks = list(self._tasks)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self._tasks.clear()

    async def register(self, symbol: str) -> Tuple[List[Dict[str, object]], asyncio.Queue[Dict[str, object]]]:
        symbol = symbol.upper()
        if symbol not in self.symbols:
            raise ValueError(f"Symbol {symbol} is not configured for streaming")

        queue: asyncio.Queue[Dict[str, object]] = asyncio.Queue(maxsize=32)
        self._queues[symbol].append(queue)
        history_payloads = list(self._history_payloads[symbol])
        return history_payloads, queue

    def unregister(self, symbol: str, queue: asyncio.Queue[Dict[str, object]]) -> None:
        symbol = symbol.upper()
        queues = self._queues.get(symbol)
        if queues and queue in queues:
            queues.remove(queue)

    async def _initialize_symbol(self, symbol: str) -> None:
        loop = asyncio.get_running_loop()
        frame, source = await loop.run_in_executor(None, self._fetch_daily_sync, symbol)
        if frame is None or frame.empty:
            LOGGER.warning("No historical data available for %s", symbol)
            return

        frame = frame.sort_index()
        async with self._lock:
            self._history_frames[symbol] = frame
            self._active_source[symbol] = source

        model = self._models[symbol]
        model.update_data(frame[["close", "volume"]])

        # Initialize Kalman Filter
        if not frame.empty:
            kalman_series, kf = apply_kalman_filter(frame["close"])
            self._kalman_filters[symbol] = kf
            # Store historical Kalman values in frame for snapshot building?
            # Or just assume we only need it for the recent snapshots we build below.
            # Let's attach it to the frame temporarily or use the series.
            frame["kalman_price"] = kalman_series

        recent = []
        for timestamp, row in frame.tail(15).iterrows():
            snapshot = self._build_snapshot(symbol, timestamp, row)
            if snapshot is not None:
                recent.append(snapshot.as_payload())

        if recent:
            async with self._lock:
                for payload in recent:
                    self._history_payloads[symbol].append(payload)

    async def _run_symbol_loop(self, symbol: str) -> None:
        while True:
            try:
                await self._poll_symbol(symbol)
            except asyncio.CancelledError:
                raise
            except Exception:  # pragma: no cover - defensive logging
                LOGGER.exception("Error while polling symbol %s", symbol)
            await asyncio.sleep(self.poll_interval)

    def get_recent(self, symbol: str, limit: int = 15) -> List[Dict[str, object]]:
        symbol = symbol.upper()
        payloads = list(self._history_payloads.get(symbol, deque(maxlen=self.HISTORY_LIMIT)))
        if not payloads:
            return []
        return payloads[-max(1, min(limit, self.HISTORY_LIMIT)) :]

    def get_last(self, symbol: str) -> Optional[Dict[str, object]]:
        recent = self.get_recent(symbol, limit=1)
        return recent[-1] if recent else None

    def get_summary(self, symbols: Iterable[str]) -> List[Dict[str, object]]:
        results: List[Dict[str, object]] = []
        for sym in symbols:
            symu = sym.upper()
            frame = self._history_frames.get(symu)
            if frame is None or frame.empty:
                results.append({"symbol": symu, "close": None, "change_pct": None, "source": self._active_source.get(symu)})
                continue
            last = frame.iloc[-1]
            close = float(last["close"]) if "close" in last else None
            change_pct = None
            if len(frame) >= 2 and close is not None:
                prev_close = float(frame.iloc[-2]["close"]) if "close" in frame.columns else None
                if prev_close and prev_close != 0:
                    change_pct = (close / prev_close - 1.0) * 100.0
            results.append({
                "symbol": symu,
                "close": close,
                "change_pct": change_pct,
                "source": self._active_source.get(symu),
            })
        return results
    async def _poll_symbol(self, symbol: str) -> None:
        loop = asyncio.get_running_loop()
        frame, source = await loop.run_in_executor(None, self._fetch_daily_sync, symbol)
        if frame is None or frame.empty:
            return

        async with self._lock:
            existing = self._history_frames.get(symbol, pd.DataFrame())
            combined = pd.concat([existing, frame], axis=0)
            combined = combined[~combined.index.duplicated(keep="last")].sort_index()
            new_index = combined.index.difference(existing.index)
            self._history_frames[symbol] = combined
            self._active_source[symbol] = source

        if new_index.empty:
            return

        model = self._models[symbol]
        model.update_data(combined[["close", "volume"]])
        
        # Update Kalman Filter for new data
        if symbol in self._kalman_filters:
            kf = self._kalman_filters[symbol]
            # We need to update for each new point sequentially
            new_kalman_values = []
            for timestamp in new_index:
                close_price = float(combined.loc[timestamp, "close"])
                k_val = kf.update(close_price)
                new_kalman_values.append(k_val)
            
            # Assign back to combined frame so _build_snapshot can pick it up
            # Note: This modifies the frame in place which is stored in _history_frames
            combined.loc[new_index, "kalman_price"] = new_kalman_values
        else:
            # Should have been initialized, but if not:
            kalman_series, kf = apply_kalman_filter(combined["close"])
            self._kalman_filters[symbol] = kf
            combined["kalman_price"] = kalman_series

        for timestamp in new_index:
            row = combined.loc[timestamp]
            snapshot = self._build_snapshot(symbol, timestamp, row)
            if snapshot is None:
                continue
            payload = snapshot.as_payload()
            async with self._lock:
                self._history_payloads[symbol].append(payload)
            # Log BUY/SELL recommendations as orders to CSV (skip HOLD)
            if snapshot.signal is not None and snapshot.signal.signal in {"BUY", "SELL"}:
                try:
                    self._order_logger.log(
                        OrderRecord(
                            symbol=symbol,
                            timestamp_iso=snapshot.timestamp.isoformat(),
                            action=snapshot.signal.signal,
                            probability=float(snapshot.signal.probability),
                            close=float(snapshot.close),
                            open=float(snapshot.open),
                            high=float(snapshot.high),
                            low=float(snapshot.low),
                            volume=float(snapshot.volume),
                            source=snapshot.source,
                            thresholds=snapshot.signal.thresholds,
                            context=snapshot.signal.context,
                        )
                    )
                except Exception:
                    LOGGER.exception("Failed to log order for %s at %s", symbol, timestamp)
            await self._broadcast(symbol, payload)

    async def _broadcast(self, symbol: str, payload: Dict[str, object]) -> None:
        queues = list(self._queues.get(symbol, []))
        for queue in queues:
            try:
                queue.put_nowait(payload)
            except asyncio.QueueFull:
                try:
                    _ = queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
                queue.put_nowait(payload)

    def _build_snapshot(self, symbol: str, timestamp: pd.Timestamp, row: pd.Series) -> Optional[MarketSnapshot]:
        try:
            open_price = float(row["open"])
            high_price = float(row["high"])
            low_price = float(row["low"])
            close_price = float(row["close"])
            volume = float(row["volume"])
        except (KeyError, TypeError, ValueError):
            LOGGER.debug("Row missing data for %s at %s", symbol, timestamp)
            return None

        ts = pd.Timestamp(timestamp)
        if ts.tzinfo is not None:
            ts = ts.tz_convert(None)

        signal = self._models[symbol].get_signal(ts)
        return MarketSnapshot(
            symbol=symbol,
            timestamp=ts,
            open=open_price,
            high=high_price,
            low=low_price,
            close=close_price,
            volume=volume,
            source=self._active_source.get(symbol, "unknown"),
            signal=signal,
            kalman_price=float(row.get("kalman_price")) if pd.notnull(row.get("kalman_price")) else None,
        )

    def get_recent(self, symbol: str, limit: int = 15) -> List[Dict[str, object]]:
        symbol = symbol.upper()
        payloads = list(self._history_payloads.get(symbol, deque(maxlen=self.HISTORY_LIMIT)))
        if not payloads:
            # Fallback: Try to fetch on-demand 1d data if cache is empty
            # This handles cases where background poller failed or hasn't run yet.
            LOGGER.info(f"Cache empty for {symbol}, attempting on-demand 1d fetch")
            fallback_data = self.get_intraday_history(symbol, interval="1d")
            if fallback_data:
                # We return it directly. We don't populate _history_payloads here to avoid complexity with the poller loop.
                # Just slice it.
                return fallback_data[-max(1, min(limit, self.HISTORY_LIMIT)) :]
            return []
            
        return payloads[-max(1, min(limit, self.HISTORY_LIMIT)) :]

    def get_last(self, symbol: str) -> Optional[Dict[str, object]]:
        recent = self.get_recent(symbol, limit=1)
        return recent[-1] if recent else None

    def get_summary(self, symbols: Iterable[str]) -> List[Dict[str, object]]:
        results: List[Dict[str, object]] = []
        for sym in symbols:
            symu = sym.upper()
            frame = self._history_frames.get(symu)
            if frame is None or frame.empty:
                results.append({"symbol": symu, "close": None, "change_pct": None, "source": self._active_source.get(symu)})
                continue
            last = frame.iloc[-1]
            close = float(last["close"]) if "close" in last else None
            change_pct = None
            if len(frame) >= 2 and close is not None:
                prev_close = float(frame.iloc[-2]["close"]) if "close" in frame.columns else None
                if prev_close and prev_close != 0:
                    change_pct = (close / prev_close - 1.0) * 100.0
            results.append({
                "symbol": symu,
                "close": close,
                "change_pct": change_pct,
                "source": self._active_source.get(symu),
            })
        return results

    def _fetch_daily_sync(self, symbol: str) -> Tuple[Optional[pd.DataFrame], str]:
        # CENTRALIZED DATA FETCHING: Call Stock Server (Port 8000)
        frame = self._fetch_from_stock_server(symbol)
        if frame is not None and not frame.empty:
             return frame, "central_server"
             
        LOGGER.warning("Central Stock Server returned no data for %s", symbol)
        return None, "unknown"

    def _fetch_from_stock_server(self, symbol: str) -> Optional[pd.DataFrame]:
        """Fetch standardized history from the Central Stock Server."""
        try:
             # Standardize symbol for endpoint
             # The stock server handles .VN or mapping internally
             end_date = pd.Timestamp.now()
             start_date = end_date - pd.Timedelta(days=self.lookback_days + 5) # Buffer
             
             params = {
                 "symbol": symbol,
                 "start_date": start_date.strftime("%Y-%m-%d"),
                 "end_date": end_date.strftime("%Y-%m-%d"),
                 "resolution": "1D"
             }
             
             # Assuming stock server is localhost:8000
             # Use a short timeout to fail fast if server is down
             resp = requests.get("http://localhost:8000/api/history", params=params, timeout=10)
             resp.raise_for_status()
             
             data = resp.json()
             if not data or "data" not in data or not data["data"]:
                 return None
                 
             records = data["data"]
             df = pd.DataFrame(records)
             
             # Required columns: time, open, high, low, close, volume
             if "time" not in df.columns: return None
             
             df["timestamp"] = pd.to_datetime(df["time"])
             df = df.set_index("timestamp").sort_index()
             
             # Ensure numeric
             cols = ["open", "high", "low", "close", "volume"]
             for c in cols:
                 df[c] = pd.to_numeric(df[c], errors='coerce')
                 
             df = df.dropna(subset=cols)
             
             # Localize/Convert if needed
             # Stock server returns date strings, we just parsed them.
             # Ensure tz-naive
             if df.index.tz is not None:
                  df.index = df.index.tz_convert(None)
                  
             if df.index.tz is not None:
                  df.index = df.index.tz_convert(None)
                  
             return df[cols]
             
        except Exception as e:
             LOGGER.error(f"Failed to fetch from Stock Server for {symbol}: {e}")
             return None

    def get_intraday_history(self, symbol: str, interval: str = "1h") -> List[Dict[str, object]]:
        """Fetch intraday history from Central Stock Server."""
        symbol = symbol.upper()
        # TODO: Implement centralization for intraday as well if needed.
        # For now, return empty if no centralized endpoint for intraday is ready, or use yfinance as fallback?
        # User said "ONLY 1 API". So we should call stock server.
        # But stock server /api/history supports resolution.
        
        try:
             # Delegate to central stock server
             end_date = pd.Timestamp.now()
             start_date = end_date - pd.Timedelta(days=5)
             
             params = {
                 "symbol": symbol,
                 "start_date": start_date.strftime("%Y-%m-%d"),
                 "end_date": end_date.strftime("%Y-%m-%d"),
                 "resolution": interval # 1H, 15m... matches server
             }
             
             resp = requests.get("http://localhost:8000/api/history", params=params, timeout=10)
             if resp.status_code != 200: return []
             
             data = resp.json()
             if not data or "data" not in data: return []
             
             # Format for frontend: t (iso), o, h, l, c, v
             records = []
             for item in data["data"]:
                 records.append({
                     "t": item["time"],
                     "o": item["open"],
                     "h": item["high"],
                     "l": item["low"],
                     "c": item["close"],
                     "v": item["volume"]
                 })
                 
             return records
        except Exception:
             return []
        period = "5d" # Default
        
        # NOTE: On weekends, "1d" might return empty for "1m". 
        # "5d" is safer to get the last trading session.
        if interval == "1m":
            period = "5d" 
        elif interval == "1h":
            period = "1mo" 
        elif interval == "1d":
            period = "3mo" # Sufficient for recent history fallback
            
        try:
            LOGGER.info(f"Fetching intraday {interval} (period={period}) for {symbol}")
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period, interval=yf_interval, auto_adjust=False)
            
            if data is None or data.empty:
                LOGGER.warning(f"No data found for {symbol} interval {interval}")
                return []

            if data.index.tz is not None:
                data.index = data.index.tz_convert(None)

            # Format strictly for frontend: t (ms), o, h, l, c, v
            records = []
            for ts, row in data.iterrows():
                records.append({
                    "t": ts.isoformat(), # Frontend converts this
                    "o": float(row["Open"]),
                    "h": float(row["High"]),
                    "l": float(row["Low"]),
                    "c": float(row["Close"]),
                    "v": float(row["Volume"]),
                })
            
            # Save to cache
            self._intraday_cache[cache_key] = {"ts": now, "data": records}
            return records

        except Exception as e:
            LOGGER.error(f"Failed to fetch intraday {interval} for {symbol}: {e}")
            return []
