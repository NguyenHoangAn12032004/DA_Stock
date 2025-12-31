"""FastAPI service exposing trading advice, control commands, and market stream."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path
import os
from typing import Iterable, List, Optional
import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import yaml
from dotenv import load_dotenv
import yfinance as yf

load_dotenv()

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from src.evaluation.advice import AdviceConfig
from src.services.advice_engine import AdviceEngine
from src.services.market_stream import MarketStreamService
from src.services.rl_inference import predict_latest
from src.services.hybrid_inference import HybridInferenceService
import pandas as pd



SERVER_ASSETS_CFG = Path("configs/server_assets.yaml")


class AssetModes(BaseModel):
    symbol: str
    mode: str
    config: Optional[str] = None
    model_path: Optional[str] = None


def _load_server_assets() -> dict:
    if SERVER_ASSETS_CFG.exists():
        with SERVER_ASSETS_CFG.open("r", encoding="utf-8") as fh:
            return yaml.safe_load(fh) or {}
    # Fallback defaults if config missing
    return {
        "assets": {
            "AAPL": {"mode": "prod", "config": "configs/aapl_prod.yaml", "model_path": "models/aapl/best_model.zip"},
            "NVDA": {"mode": "limited", "config": "configs/nvda.yaml", "model_path": "models/nvda/best_model.zip"},
            "GOOG": {"mode": "disabled", "config": "configs/goog.yaml", "model_path": "models/goog/best_model.zip"},
        },
        "market_stream": {"poll_interval": 3600, "lookback_days": 30},
        "advice": {"metrics_path": "reports/forward_paper/forward_metrics.csv", "thresholds": {}},
    }


_assets_cfg = _load_server_assets()
_assets = _assets_cfg.get("assets", {})
_active_assets = {k: v for k, v in _assets.items() if v and v.get("mode") in {"prod", "limited"}}
# Exclude known non-ticker asset keys (e.g. models)
_active_symbols = sorted([k for k in _active_assets.keys() if not k.startswith("PHASE")]) or ["AAPL"]

_advice_section = _assets_cfg.get("advice", {})
_metrics_path = Path(_advice_section.get("metrics_path", "reports/forward_paper/forward_metrics.csv"))
_thr = _advice_section.get("thresholds", {})
engine = AdviceEngine(
    metrics_path=_metrics_path,
    advice_config=AdviceConfig(
        buy_sharpe=float(_thr.get("buy_sharpe", 0.5)),
        hold_sharpe=float(_thr.get("hold_sharpe", 0.1)),
        min_total_return=float(_thr.get("min_total_return", 0.0)),
        min_trades=int(_thr.get("min_trades", 5)),
        max_cost_ratio=float(_thr.get("max_cost_ratio", 0.25)),
    ),
    tickers=_active_symbols,
)

_ms = _assets_cfg.get("market_stream", {})
_dir = (_ms.get("directional", {}) or {})
stream_service = MarketStreamService(
    symbols=_active_symbols,
    poll_interval=int(_ms.get("poll_interval", 3600)),
    lookback_days=int(_ms.get("lookback_days", 30)),
    buy_threshold=float(_dir.get("buy_threshold", 0.6)),
    sell_threshold=float(_dir.get("sell_threshold", 0.4)),
    min_samples=int(_dir.get("min_samples", 120)),
    retrain_interval=int(_dir.get("retrain_interval", 20)),
)

# Initialize Hybrid Services (Optional now, but kept for legacy/fallback)
hybrid_services = {}
for sym in _active_symbols:
    try:
        hybrid_services[sym] = HybridInferenceService(sym)
        print(f"Loaded Hybrid Model for {sym}")
    except Exception as e:
        print(f"Failed to load Hybrid Model for {sym}: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[Startup] Triggering Daily Data Update for Phase 4...")
    try:
        # Run scripts/prepare_data.py synchronously to ensure latest data is available before serving
        subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "prepare_data.py"), "--config", "configs/rl_enhanced.yaml"],
            check=True
        )
        print("[Startup] Data Updated Successfully.")
    except Exception as e:
        print(f"[Startup] Data Update Failed: {e}")
        
    await stream_service.start()
    yield
    await stream_service.stop()


app = FastAPI(title="RL Trading Advice API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _rows_to_payload(ticker: Optional[str] = None) -> List[dict]:
    df = engine.list_runs(ticker)
    payload: List[dict] = []
    for _, row in df.iterrows():
        symbol = str(row.get("ticker"))
        mode = _assets.get(symbol, {}).get("mode", "unknown")
        payload.append(
            {
                "ticker": symbol,
                "run_name": row.get("run_name"),
                "start_date": row.get("start_date").strftime("%Y-%m-%d")
                if hasattr(row.get("start_date"), "strftime")
                else row.get("start_date"),
                "end_date": row.get("end_date").strftime("%Y-%m-%d")
                if hasattr(row.get("end_date"), "strftime")
                else row.get("end_date"),
                "recommendation": row.get("recommendation"),
                "confidence": row.get("confidence"),
                "total_return": row.get("total_return"),
                "sharpe_ratio": row.get("sharpe_ratio"),
                "trade_count": row.get("trade_count"),
                "rationale": row.get("rationale"),
                "mode": mode,
            }
        )
    return payload


class TrainRequest(BaseModel):
    config: Path
    timesteps: Optional[int] = None
    chunk_size: Optional[int] = Field(default=None, ge=1)
    resume: bool = False
    reset_optimizer: bool = False


class EvaluateRequest(BaseModel):
    config: Path
    model: Path
    run_name: str
    start_date: str
    period_days: int = Field(default=252, ge=1)
    extra_slippage_bps: float = 2.0


class CommandResponse(BaseModel):
    command: List[str]
    returncode: int
    stdout: str
    stderr: str


def _run_command(args: Iterable[str]) -> CommandResponse:
    process = subprocess.run(
        list(args),
        capture_output=True,
        text=True,
        check=False,
    )
    return CommandResponse(
        command=list(args),
        returncode=process.returncode,
        stdout=process.stdout[-4000:],
        stderr=process.stderr[-4000:],
    )


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/assets", response_model=List[AssetModes])
def get_assets() -> List[AssetModes]:
    out: List[AssetModes] = []
    for sym, cfg in _assets.items():
        out.append(
            AssetModes(
                symbol=sym,
                mode=str(cfg.get("mode", "unknown")),
                config=str(cfg.get("config")) if cfg.get("config") else None,
                model_path=str(cfg.get("model_path")) if cfg.get("model_path") else None,
            )
        )
    return out


@app.get("/advice")
def get_advice(ticker: Optional[str] = None, include_limited: bool = Query(False)) -> List[dict]:
    rows = _rows_to_payload(ticker)
    if include_limited:
        return rows
    # Filter out limited-mode assets unless explicitly requested
    return [r for r in rows if _assets.get(str(r.get("ticker")), {}).get("mode") == "prod"]


@app.get("/advice/{run_name}")
def get_run(run_name: str) -> dict:
    df = engine.advice_table
    row = df[df["run_name"] == run_name]
    if row.empty:
        raise HTTPException(status_code=404, detail="Run not found")
    return _rows_to_payload()[df.index.get_loc(row.index[0])]


@app.post("/advice/refresh")
def refresh(include_limited: bool = Query(False)) -> List[dict]:
    engine.refresh()
    rows = _rows_to_payload()
    if include_limited:
        return rows
    return [r for r in rows if _assets.get(str(r.get("ticker")), {}).get("mode") == "prod"]


@app.get("/tickers")
def get_tickers(include_limited: bool = Query(False)) -> List[str]:
    syms = engine.list_tickers()
    if include_limited:
        return syms
    return [s for s in syms if _assets.get(s, {}).get("mode") == "prod"]


@app.post("/train", response_model=CommandResponse)
def train(request: TrainRequest) -> CommandResponse:
    args = [
        sys.executable,
        str(ROOT / "scripts" / "train_agent.py"),
        "--config",
        str(request.config),
    ]
    if request.timesteps is not None:
        args.extend(["--timesteps", str(request.timesteps)])
    if request.chunk_size is not None:
        args.extend(["--chunk-size", str(request.chunk_size)])
    if request.resume:
        args.append("--resume")
    if request.reset_optimizer:
        args.append("--reset-optimizer")
    return _run_command(args)


@app.post("/evaluate", response_model=CommandResponse)
def evaluate(request: EvaluateRequest) -> CommandResponse:
    args = [
        sys.executable,
        str(ROOT / "scripts" / "run_forward_paper.py"),
        "--config",
        str(request.config),
        "--model",
        str(request.model),
        "--run-name",
        request.run_name,
        "--start-date",
        request.start_date,
        "--period-days",
        str(request.period_days),
        "--extra-slippage-bps",
        str(request.extra_slippage_bps),
    ]
    return _run_command(args)


@app.websocket("/ws/market/{symbol}")
async def market_stream(websocket: WebSocket, symbol: str) -> None:
    await websocket.accept()
    try:
        symu = symbol.upper()
        mode = _assets.get(symu, {}).get("mode")
        if mode == "disabled":
            await websocket.send_json({"type": "error", "message": f"Symbol {symu} is disabled"})
            await websocket.close(code=1003)
            return
        if mode == "limited":
            cfg_token = (_assets_cfg.get("auth", {}) or {}).get("limited_token") or os.getenv("LIMITED_ROLLOUT_TOKEN")
            provided = websocket.query_params.get("token") if hasattr(websocket, "query_params") else None
            if cfg_token and (provided != cfg_token):
                await websocket.send_json({"type": "error", "message": "Access denied for limited asset"})
                await websocket.close(code=1008)
                return
        history, queue = await stream_service.register(symu)
    except ValueError as exc:
        await websocket.send_json({"type": "error", "message": str(exc)})
        await websocket.close(code=1003)
        return

    await websocket.send_json(
        {
            "type": "history",
            "symbol": symbol.upper(),
            "data": history,
        }
    )

    try:
        while True:
            payload = await queue.get()
            
            # Run Hybrid Inference (Can keep this for WebSocket realtime signals if desired, or switch to PPO)
            # Keeping Hybrid for WebSocket consistency with original design, but Chat uses PPO.
            if symbol in hybrid_services:
                try:
                    # Convert payload to DataFrame for inference
                    if isinstance(payload, dict) and 'close' in payload:
                        data_point = {
                            'Date': payload.get('timestamp'),
                            'Open': payload.get('open'),
                            'High': payload.get('high'),
                            'Low': payload.get('low'),
                            'Close': payload.get('close'),
                            'Volume': payload.get('volume', 0)
                        }
                        df_input = pd.DataFrame([data_point])
                        
                        # Fetch recent history to construct window
                        recent_history = stream_service.get_recent(symbol, limit=20)
                        if recent_history:
                            df_hist = pd.DataFrame(recent_history)
                            df_hist = df_hist.rename(columns={
                                'timestamp': 'Date',
                                'open': 'Open',
                                'high': 'High',
                                'low': 'Low',
                                'close': 'Close',
                                'volume': 'Volume'
                            })
                            
                            # Ensure we have the latest point
                            last_ts = pd.to_datetime(payload.get('timestamp'))
                            if not df_hist.empty:
                                last_hist_ts = pd.to_datetime(df_hist.iloc[-1]['Date'])
                                if last_ts > last_hist_ts:
                                     df_hist = pd.concat([df_hist, df_input], ignore_index=True)
                            
                            prediction = hybrid_services[symbol].predict(df_hist)
                            payload['prediction'] = prediction
                except Exception as e:
                    print(f"Inference error: {e}")

            await websocket.send_json(payload)
    except WebSocketDisconnect:
        pass
    finally:
        stream_service.unregister(symbol, queue)


@app.get("/market/history")
def market_history(
    symbol: str = Query(..., min_length=1), 
    days: int = Query(15, ge=1, le=60),
    interval: str = Query("1d")
) -> List[dict]:
    symbol = symbol.upper()
    try:
        if interval != "1d":
            return stream_service.get_intraday_history(symbol, interval)
        return stream_service.get_recent(symbol, limit=days)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@app.get("/market/summary")
def market_summary(symbols: str = Query("AAPL,GOOG,NVDA")) -> List[dict]:
    syms = [s.strip().upper() for s in symbols.split(",") if s.strip()]
    return stream_service.get_summary(syms)


@app.get("/market/last")
def market_last(symbol: str = Query(..., min_length=1)) -> dict:
    symbol = symbol.upper()
    payload = stream_service.get_last(symbol)
    if not payload:
        raise HTTPException(status_code=404, detail="No data")
    return payload


class ChatRequest(BaseModel):
    symbol: str
    message: str


from google import genai
import os

# Initialize Gemini Client
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or "AIzaSyBqKbsiqoG3rHeX_MKNs7sgetZPmYUbOgU"

MASCOT_INSTRUCTION = """
Bạn là "Gemini Investment Assistant", một trợ lý đầu tư thông minh.
Nhiệm vụ: Trả lời câu hỏi người dùng về cổ phiếu một cách NGẮN GỌN, TRỌNG TÂM và DỄ HIỂU.

NGUYÊN TẮC QUAN TRỌNG NHẤT:
1. **TRẢ LỜI TRỰC DIỆN**: Nếu người dùng hỏi "có nên mua/bán X không?", hãy đưa ra nhận định ngay (VD: "Thị trường đang tốt để Mua", "Nên Giữ", "Rủi ro cao, nên Bán").
2. **KHÔNG DÀI DÒNG**: Tuyệt đối KHÔNG liệt kê các chỉ số (RSI = 53, SMA = ...) trừ khi người dùng hỏi cụ thể về thông số kỹ thuật.
3. **NGÔN NGỮ ĐỜI THƯỜNG**: Tránh dùng jargon tài chính phức tạp nếu không cần thiết.

DỮ LIỆU BẠN CÓ (Chỉ dùng để phân tích trong đầu, KHÔNG in ra hết):
- System Signal & PPO AI Model (Quan trọng nhất).
- RSI, Trend.

CẤU TRÚC CÂU TRẢ LỜI:
- **Câu đầu tiên**: Nhận định xu hướng chính (Bullish/Bearish/Neutral) và Lời khuyên (Buy/Sell/Hold).
- **Câu thứ hai**: Lý do ngắn gọn (VD: "Do AI Model dự báo tăng và xu hướng đang lên").
- **Cảnh báo rủi ro**: Ngắn gọn (VD: "Lưu ý quản lý vốn").

CHỈ KHI NGƯỜI DÙNG HỎI CHI TIẾT ("Tại sao?", "Chỉ số thế nào?", "Phân tích sâu"), BẠN MỚI ĐƯỢC ĐƯA RA CÁC THÔNG SỐ KỸ THUẬT CỤ THỂ.
"""

# Helper to fetch news
def get_stock_news(symbol: str) -> str:
    try:
        ticker = yf.Ticker(symbol)
        news_list = ticker.news
        if not news_list:
            return ""
        
        summary = []
        for item in news_list[:2]: # Top 2 news
            title = item.get('title', '')
            link = item.get('link', '')
            summary.append(f"- {title} ({link})")
        return "\n".join(summary)
    except Exception:
        return ""

def calculate_technicals(symbol: str) -> dict:
    """Calculate basic RSI and SMA from recent history."""
    try:
        # Get enough history for SMA50
        history = stream_service.get_recent(symbol, limit=60) 
        if not history or len(history) < 15:
            return {"rsi": "N/A", "sma": "N/A", "trend": "Unknown"}
            
        df = pd.DataFrame(history)
        close = df['close']
        
        # RSI 14
        delta = close.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        current_rsi = rsi.iloc[-1]
        
        # SMA 50 via Pandas
        sma50 = close.rolling(window=50).mean().iloc[-1] if len(close) >= 50 else None
        
        trend = "Neutral"
        if sma50:
            trend = "Bullish" if close.iloc[-1] > sma50 else "Bearish"
            
        return {
            "rsi": f"{current_rsi:.1f}" if pd.notnull(current_rsi) else "N/A",
            "sma": f"{sma50:.2f}" if pd.notnull(sma50) else "N/A",
            "trend": trend
        }
    except Exception as e:
        print(f"Tech calc error for {symbol}: {e}")
        return {"rsi": "Error", "sma": "N/A", "trend": "Error"}

@app.post("/chat")
async def chat(req: ChatRequest) -> dict:
    if not GEMINI_API_KEY:
        return {
            "symbol": req.symbol.upper(),
            "timestamp": None,
            "action": "HOLD",
            "probability": 0,
            "context": "Missing API Key",
            "reply": "Bạn chưa cấu hình GEMINI_API_KEY trong file .env rồi! Hãy thêm key vào để mình có thể trả lời nhé. 🤖",
        }

    # Gather context for ALL active symbols
    global_context = []

    # Pre-fetch PPO signals for all tickers to avoid re-loading model N times
    ppo_signals = {}
    try:
        # PATHS defined here for clarity
        RL_CONFIG = Path("configs/rl_enhanced.yaml")
        RL_MODEL = Path("models/ppo_trading.zip")
        
        if RL_MODEL.exists():
            print("[Chat] Loading PPO Model for inference...")
            # Run in thread to avoid blocking loop with heavy load
            rl_payload = await asyncio.to_thread(predict_latest, 
                config_path=RL_CONFIG,
                model_path=RL_MODEL,
                include_feature_snapshot=False
            )
            ppo_signals = rl_payload.get("signals", {})
            print(f"[Chat] PPO Signals loaded: {list(ppo_signals.keys())}")
        else:
            print(f"[Chat] PPO Model not found at {RL_MODEL}")
            
    except Exception as e:
        print(f"[Chat] PPO Inference failed: {e}")
    
    for sym in _active_symbols:
        payload = stream_service.get_last(sym)
        if not payload:
            continue
            
        latest_ts = payload.get("timestamp")
        rec = payload.get("recommendation") or {}
        action = rec.get("action", "HOLD")
        prob = rec.get("probability", 0)
        price = payload.get("close", 0)
        
        # 1. Technical Indicators
        techs = calculate_technicals(sym)
        
        # 2. PPO Model Inference (Replaces Hybrid)
        ppo_action = "N/A"
        ppo_conf = "N/A"
        ppo_weight = "N/A"
        
        if sym in ppo_signals:
            sig = ppo_signals[sym]
            ppo_action = sig.get("action", "HOLD")
            d_prob = sig.get("direction_prob")
            if d_prob is not None:
                ppo_conf = f"{d_prob:.2f}"
            w = sig.get("weight")
            if w is not None:
                ppo_weight = f"{w:.2f}"
        
        # 3. News
        news_text = get_stock_news(sym)
        
        symbol_info = f'''
        === STOCK: {sym} ===
        Price: {price}
        * SYSTEM SIGNAL: {action} (Prob: {prob:.2f})
        * PPO AI MODEL: {ppo_action} (Conf: {ppo_conf}, Weight: {ppo_weight})
        * TECHNICALS: RSI={techs['rsi']}, Trend={techs['trend']} (via SMA50)
        * NEWS:
        {news_text}
        '''
        global_context.append(symbol_info)
    
    context_str = "\\n".join(global_context)
    
    user_msg = req.message
    
    # Updated Prompt
    full_prompt = f"""
    MARKET DATA (Real-time Analysis & PPO Model):
    {context_str}
    
    USER QUESTION: {user_msg}
    
    INSTRUCTION:
    You are "Gemini Bot".
    1. Identify the stock(s) in question.
    2. ANALYZE internally using PPO Model (High Weight) and System Signal.
    3. ANSWER THE USER:
       - Give a DIRECT VERDICT (Buy/Sell/Hold) immediately.
       - Keep it under 3 sentences for simple questions.
       - DO NOT spit out the raw data/numbers unless explicitly asked for "details", "parameters", or "analysis".
       - Example Good Answer: "Với HPG, AI nhận thấy xu hướng tích cực. Đây là vùng giá tốt để Mua (Buy) nắm giữ trung hạn."
       - Example Bad Answer: "HPG có RSI là 50, System bảo Buy, AI bảo Buy, Trend là Bullish..." (Too verbose).
    4. If the user asks for "Portfolio Analysis", give a summary assessment of their Risk/Exposure first, then specific action items.
    """
    
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        response = await asyncio.to_thread(
            client.models.generate_content,
            model="gemini-2.5-flash-lite", 
            contents=full_prompt,
            config=genai.types.GenerateContentConfig(
                system_instruction=MASCOT_INSTRUCTION
            )
        )
        reply_text = response.text
    except Exception as e:
        err_str = str(e)
        print(f"Gemini Error: {err_str}")
        if "429" in err_str or "quota" in err_str.lower():
            reply_text = "Hic, mình đang bị quá tải do nhiều người hỏi quá! Bạn đợi khoảng 1 phút rồi hỏi lại nhé! 🤖⏳"
        else:
            reply_text = "Hic, server mình đang gặp chút trục trặc! Bạn thử lại sau nha! 🤖"

    # Try to find the symbol the user *might* be referring to, for metadata purposes (fallback to requested symbol)
    target_symbol = req.symbol.upper()
    target_payload = stream_service.get_last(target_symbol) or {}
    target_rec = target_payload.get("recommendation") or {}

    # Extract PPO action for the response metadata if available
    final_action = target_rec.get("action", "HOLD")
    if target_symbol in ppo_signals:
         final_action = ppo_signals[target_symbol].get("action", "HOLD")

    return {
        "symbol": target_symbol,
        "timestamp": target_payload.get("timestamp"),
        "action": final_action,
        "probability": target_rec.get("probability", 0),
        "context": "PPO Model + Realtime Data",
        "reply": reply_text,
    }


@app.get("/rl/predict")
def rl_predict(
    ticker: Optional[str] = Query(None),
    config: Optional[str] = Query(None),
    model: Optional[str] = Query(None),
) -> dict:
    """Return latest PPO-based signal for the requested symbol.

    If no config is provided, defaults to the AAPL no-force/base config.
    """
    # Default to AAPL no-force config if not provided
    default_cfg = Path("configs/aapl_prod.yaml")
    cfg_path = Path(config) if config else default_cfg
    model_path = Path(model) if model else None

    if not cfg_path.exists():
        raise HTTPException(status_code=400, detail=f"Config not found: {cfg_path}")

    try:
        payload = predict_latest(cfg_path, model_path)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail=str(exc))

    # Optional: narrow to a specific ticker if requested
    if ticker:
        sym = ticker.upper()
        sigs = payload.get("signals", {})
        if sym in sigs:
            return {
                "date": payload.get("date"),
                "portfolio_value": payload.get("portfolio_value"),
                "ticker": sym,
                "signal": sigs[sym],
            }
        raise HTTPException(status_code=404, detail=f"Ticker {sym} not in config dataset")
    return payload





# --- Phase 7: Regime Endpoint ---
from src.services.regime import RegimeClassifier, RegimeState, MarketTrend, EconomicCycle
from src.data.loader import MarketDataset

# Global dataset cache (simple)
_dataset_cache = {}

def _get_cached_dataset() -> MarketDataset:
    # Use valid path to dataset
    path = Path("data/processed/aapl_nvda_goog_daily.npz")
    if not path.exists():
        # Fallback if specific file missing
        path = Path("data/processed/dataset.npz")
    
    # Reload if modified? For now, simple load.
    # In prod, check mtime.
    return MarketDataset.load(path)

@app.get("/regime/current")
def get_current_regime() -> dict:
    """Analyze current market regime based on latest data."""
    try:
        ds = _get_cached_dataset()
        # Create a dataframe from the dataset for the latest step
        # RegimeClassifier expects a DataFrame with columns: close, macro_VIX, etc.
        # But dataset format is (Time, Asset, Feat).
        # We need to reconstruction a DataFrame for the LAST step (across all assets or just generally?)
        # Regime is Global (Cycle) + Asset Specific (Trend).
        # Let's return Global Cycle + Representative Trend (e.g. SPY or first ticker).
        
        # Taking "AAPL" or the first ticker as reference for Trend?
        # Or return Map?
        
        # Let's use Index 0 (latest available step - wait, dataset is historical).
        # Dataset assumes we have "today".
        # We take the very last row.
        
        last_idx = -1
        ticker = "AAPL" # Default reference
        if ds.tickers:
            ticker = ds.tickers[0]
            
        t_idx = ds.tickers.index(ticker)
        
        # Reconstruct row
        # features are scaled! We need unscaled for logic?
        # RegimeClassifier uses 'close', 'ema', 'vix'.
        # 'close' is available in ds.prices (unscaled).
        # 'vix' might be in features (scaled) or we need raw macro.
        # Wait, ds.features is SCALED. 
        # But 'regime_cycle' is UNSCALED (via my change).
        # And 'regime_trend' is UNSCALED.
        
        # So we can just read `regime_cycle` feature directly!
        # No need to re-run classifier logic if it's already in the dataset.
        
        # Find feature indices
        f_names = ds.feature_names.tolist() if hasattr(ds.feature_names, "tolist") else ds.feature_names
        
        has_cycle = "regime_cycle" in f_names
        has_trend = "regime_trend" in f_names
        
        res = {
            "date": str(ds.dates[last_idx]),
            "cycle": "Unknown",
            "trend": "Unknown",
            "risk_on": False,
            "description": "Insufficient Data"
        }
        
        if has_cycle:
            c_idx = f_names.index("regime_cycle")
            # 0=Recession, 1=Expansion
            val = ds.features[last_idx, t_idx, c_idx]
            res["cycle"] = "Expansion" if val > 0.5 else "Recession"
            
            # Simple VIX proxy if we can find it? 
            # Actually, let's just use the pre-calculated regime.
            
        if has_trend:
            tr_idx = f_names.index("regime_trend")
            # 0=Bear, 1=Sideways, 2=Bull
            val = ds.features[last_idx, t_idx, tr_idx]
            if val > 1.5: res["trend"] = "Bull"
            elif val < 0.5: res["trend"] = "Bear"
            else: res["trend"] = "Sideways"

        # Determine RiskOn
        is_bull = res["trend"] == "Bull"
        is_expansion = res["cycle"] == "Expansion"
        
        res["risk_on"] = is_bull or is_expansion # Aggressive if either is true?
        # Refined Logic matches RegimeClassifier:
        if res["cycle"] == "Recession":
            res["risk_on"] = False
        elif is_bull:
            res["risk_on"] = True
        else: # Sideways + Expansion
            res["risk_on"] = True # Accumulation
            
        res["description"] = f"Cycle: {res['cycle'].upper()} | Trend: {res['trend'].upper()}"
        return res
    
    except Exception as e:
        print(f"Regime Error: {e}")
        return {
            "date": "N/A",
            "cycle": "Error",
            "trend": "Error", 
            "risk_on": False,
            "description": str(e)
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("src.api.advice_server:app", host="0.0.0.0", port=8001, reload=True)
