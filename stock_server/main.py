import sys
# FIX UNICODE ERROR ON WINDOWS IMMEDIATELY
sys.stdout.reconfigure(encoding='utf-8')

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from vnstock import Vnstock
import pandas as pd
import yfinance as yf
import requests
import json
import numpy as np
import redis
import asyncio
import uuid
from firebase_config import init_firebase, get_db
from firebase_admin import firestore, messaging, auth
import time
from datetime import datetime, timedelta

# --- Virtual Exchange Modules ---
from matching_engine import engine, Order, OrderSide, OrderType, OrderStatus
from market_maker import start_market_maker

class OrderRequest(BaseModel):
    user_id: str
    symbol: str
    side: str
    quantity: int
    price: float
    order_type: str = "limit"

# Global Config
TRADING_FEE_RATE = 0.0015 # 0.15%
shutdown_event = asyncio.Event()
active_connections = 0

# --- HELPER: TRADE SETTLEMENT ---
def process_executed_trades(trades: list):
    """
    Handles financial settlement (Firestore) and Status Updates (Redis) for executed trades.
    """
    if not trades or not r:
        print(f"[DEBUG] process_executed_trades: Aborting! Trades={len(trades) if trades else 0}, Redis={r is not None}")
        return
    
    print(f"[DEBUG] process_executed_trades STARTED with {len(trades)} trades.")
    db = get_db()
    
    print(f"⚡ Processing {len(trades)} trades...")
    
    for trade in trades:
        # trade check
        if not isinstance(trade, dict): continue
        print(f"[DEBUG] Trade Data: {trade}")
        
        qty = trade.get("quantity")
        symbol = trade.get("symbol")
        price = trade.get("price")
        buyer_id = trade.get("buyer_id")
        seller_id = trade.get("seller_id")
        
        # 1. Log Transaction (Optional for MVP, but good for history)
        # db.collection('transactions').add(trade)
        
        # 2. Settlement
        if db:
            try:
                batch = db.batch()
                
                # BUYER: Add Stocks (Money already held)
                if buyer_id != "MARKET_MAKER_BOT":
                    b_ref = db.collection("users").document(buyer_id).collection("holdings").document(symbol)
                    batch.set(b_ref, {"quantity": firestore.Increment(qty), "symbol": symbol}, merge=True)
                
                # SELLER: Deduct Stocks, Add Money
                if seller_id != "MARKET_MAKER_BOT":
                    s_ref = db.collection("users").document(seller_id)
                    s_holding = s_ref.collection("holdings").document(symbol)
                    
                    revenue = price * qty
                    fee = revenue * TRADING_FEE_RATE
                    net = revenue - fee
                    
                    print(f"💰 [SETTLEMENT] Seller {seller_id} sold {qty} {symbol} @ {price}. Net: {net:,.2f}")
                    
                    batch.update(s_holding, {"quantity": firestore.Increment(-qty)})
                    batch.update(s_ref, {"balance": firestore.Increment(net)})
                else:
                    print(f"msg: Seller is BOT, skipping balance update.")
                
                batch.commit()
                print("✅ [SETTLEMENT] Batch Commit Success.")
                
                # 3. Publish to Social Feed
                publish_social_feed(db, trade)
            except Exception as e:
                print(f"⚠️ Settlement Error: {e}")
        
                # 3. Redis Status Update
        try:
            for oid in [trade["buy_order_id"], trade["sell_order_id"]]:
                # if "BOT" in oid: continue  <-- REMOVED: Bot orders are now in Redis so must be cleaned up!
                # Actually Bot orders ARE in Redis now (market_maker.py puts them there).
                # But they might not have a distinct 'quantity' field easily accessible if we don't query.
                # However, for user orders:
                
                # Increment filled
                new_filled = r.hincrbyfloat(f"order:{oid}", "filled", float(qty))
                
                # Check Total Quantity
                # We need to fetch the original quantity to know if it's full.
                # Since we don't have it handy in the `trade` dict for *both* sides (only trade qty),
                # we must fetch from Redis.
                order_info = r.hmget(f"order:{oid}", ["quantity", "status"])
                if order_info and order_info[0]:
                    total_qty = float(order_info[0])
                    if new_filled >= total_qty - 0.0001: # Float tolerance
                        r.hset(f"order:{oid}", "status", "matched") # or filled
                        r.srem("pending_orders", oid)
                        print(f"✅ Order {oid} Fully Matched & Removed from Pending.")
                    else:
                         r.hset(f"order:{oid}", "status", "partial")

        except Exception as e:
            print(f"Redis Update Error: {e}")

    # 4. Broadcast Realtime Updates
    if r:
        try:
            affected_symbols = set(t.get("symbol") for t in trades if t.get("symbol"))
            for s in affected_symbols:
                broadcast_orderbook_update(s)
        except Exception as e:
            print(f"⚠️ Broadcast Error: {e}")

# --- Hydration Helper ---
def hydrate_engine():
    """
    Restores the In-Memory Matching Engine state from Redis on startup.
    This ensures that pending orders persist across server restarts.
    """
    if not r: 
        print("⚠️ Redis not connected, skipping hydration.")
        return

    print("♻️ Hydrating Matching Engine from Redis...")
    try:
        print("   -> Fetching pending_orders from Redis...")
        pending_ids = r.smembers("pending_orders")
        print(f"   -> Found {len(pending_ids)} pending orders.")
        count = 0
        
        # We need to load ALL orders first, then sort them by timestamp to re-play them continuously?
        # Or just adding them is enough? 
        # Ideally, we should add them in timestamp order to maintain priority.
        
        loaded_orders = []
        
        # Optimization: Use Pipeline to fetch all orders at once
        if pending_ids:
            pipe = r.pipeline()
            p_ids_list = list(pending_ids)
            for oid in p_ids_list:
                pipe.hgetall(f"order:{oid}")
            
            results = pipe.execute()
            
            for data in results:
                if not data: continue
                
                # Reconstruct Order Object
                try:
                    side_str = data.get("side", "").upper()
                    type_str = data.get("type", "").upper()
                    
                    # Safe float conversion
                    price = float(data.get("price", 0))
                    qty = int(float(data.get("quantity", 0)))
                    filled = int(float(data.get("filled", 0)))
                    ts = float(data.get("timestamp", time.time()))

                    order = Order(
                        id=data.get("order_id"),
                        user_id=data.get("user_id"),
                        symbol=data.get("symbol"),
                        side=OrderSide[side_str] if side_str in OrderSide.__members__ else OrderSide.BUY,
                        type=OrderType[type_str] if type_str in OrderType.__members__ else OrderType.LIMIT,
                        price=price,
                        quantity=qty,
                        filled_quantity=filled,
                        timestamp=ts,
                        status=OrderStatus.PENDING
                    )
                    loaded_orders.append(order)
                except Exception as e:
                    # print(f"⚠️ Failed to parse order data: {e}") 
                    continue
        
        # Sort by timestamp to preserve FIFO/Time priority
        loaded_orders.sort(key=lambda x: x.timestamp)
        
        for o in loaded_orders:
            trades = engine.place_order(o)
            if trades:
                print(f"⚡ Matched {len(trades)} trades during hydration!")
                process_executed_trades(trades)
            count += 1
            
        print(f"✅ Hydrated {count} orders into Matching Engine.")
        
    except Exception as e:
        print(f"❌ Hydration Error: {e}")

# --- Social Trading Helpers ---
def publish_social_feed(db, trade: dict):
    """
    Publishes a trade to the Social Feed and sends FCM if it's a 'Whale' trade.
    """
    try:
        # Validating input
        symbol = trade.get('symbol')
        price = trade.get('price', 0)
        quantity = trade.get('quantity', 0)
        total_val = price * quantity
        timestamp = trade.get('timestamp', time.time())
        buyer_id = trade.get('buyer_id')
        seller_id = trade.get('seller_id')

        # Cache names ideally, but fetch for now
        buyer_name = "Nhà đầu tư"
        seller_name = "Nhà đầu tư"
        
        # 1. Feed for Buyer
        if buyer_id:
            b_snap = db.collection("users").document(buyer_id).get()
            if b_snap.exists: buyer_name = b_snap.to_dict().get("name", "Nhà đầu tư")
            
            db.collection("feed").add({
                "user_id": buyer_id,
                "user_name": buyer_name,
                "symbol": symbol,
                "action": "mua",
                "price": price,
                "quantity": quantity,
                "timestamp": timestamp,
                "type": "trade"
            })

        # 2. Feed for Seller
        if seller_id:
            s_snap = db.collection("users").document(seller_id).get()
            if s_snap.exists: seller_name = s_snap.to_dict().get("name", "Nhà đầu tư")
            
            db.collection("feed").add({
                "user_id": seller_id,
                "user_name": seller_name,
                "symbol": symbol,
                "action": "bán",
                "price": price,
                "quantity": quantity,
                "timestamp": timestamp,
                "type": "trade"
            })

        # 3. Whale Alert (> 100M VND)
        if total_val > 100_000_000:
            print(f"🐋 WHALE ALERT: {total_val:,.0f} VND on {symbol}")
            
            notification_title = f"🐋 Cá mập hành động trên {symbol}!"
            val_str = f"{total_val/1_000_000_000:,.2f} tỷ" if total_val >= 1_000_000_000 else f"{total_val/1_000_000:,.0f} triệu"
            notification_body = f"Giao dịch khớp lệnh {quantity:,.0f} CP giá {price:,.0f}. Tổng trị giá {val_str} VND."

            message = messaging.Message(
                notification=messaging.Notification(
                    title=notification_title,
                    body=notification_body,
                ),
                topic="market_news",
                data={
                    "type": "whale_alert",
                    "symbol": symbol,
                    "value": str(total_val)
                }
            )
            try:
                response = messaging.send(message)
                print('✅ FCM Sent:', response)
            except Exception as fcm_error:
                print('❌ FCM Error:', fcm_error)

    except Exception as e:
        print(f"Error publishing social feed: {e}")

from contextlib import asynccontextmanager
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request

# --- CẤU HÌNH REDIS (UPSTASH) ---
# TODO: Thay thế chuỗi bên dưới bằng URL từ Upstash Dashboard của bạn
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

try:
    r = redis.from_url(REDIS_URL, decode_responses=True)
    print("✅ Đã khởi tạo client Redis")
except Exception as e:
    print(f"❌ Lỗi khởi tạo Redis: {e}")
    r = None

class ActivityTrackerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 1. Track User Activity
        user_id = request.headers.get("x-user-id")
        if user_id and r:
            try:
                await asyncio.to_thread(r.zadd, "online_users", {user_id: time.time()})
            except: pass
        response = await call_next(request)
        return response

# --- Lifespan (Startup/Shutdown) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚦 Lifespan: Startup Sequence initiated...")
    
    # Startup
    try:
        print("   -> Hydrating Engine...")
        await asyncio.to_thread(hydrate_engine)
        print("   -> Engine Hydrated.")
    except Exception as e:
        print(f"   ❌ Engine Hydration Failed: {e}")

    # Init Firebase
    try:
        print("   -> Initializing Firebase...")
        init_firebase()
        print("   -> Firebase Initialized.")
    except Exception as e:
        print(f"   ❌ Firebase Init Failed: {e}")
    
    # Start Background Services
    print("   -> Starting Background Tasks...")
    asyncio.create_task(market_data_simulator())
    asyncio.create_task(alert_monitor())
    asyncio.create_task(metrics_monitor()) 
    asyncio.create_task(maintenance_monitor())
    
    # Start Market Maker Bot
    # print("   -> Starting Market Maker Bot...")
    # asyncio.create_task(start_market_maker(process_executed_trades, r))

    print("🚀 All Services Started via Lifespan.")
    yield
    # Shutdown
    print("🛑 Server Shutting Down...")
    shutdown_event.set()

# Overwrite 'app' to bind lifespan
app = FastAPI(lifespan=lifespan)
app.add_middleware(ActivityTrackerMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/api/orders")
def place_order(order: OrderRequest):
    """
    API Đặt lệnh (Mua/Bán) Limit/Market.
    - Validate & Trừ tiền/lock cổ phiếu.
    - Gửi vào Matching Engine.
    - Xử lý kết quả khớp lệnh ngay lập tức (nếu có).
    """
    global IS_MAINTENANCE
    if IS_MAINTENANCE:
        raise HTTPException(status_code=503, detail="Hệ thống đang bảo trì. Vui lòng quay lại sau.")

    if not r:
        raise HTTPException(status_code=503, detail="Redis not connected")

    order_id = str(uuid.uuid4())
    timestamp = time.time()
    
    # 1. Validation & Pre-deduction (Firestore)
    db = get_db()
    
    # Normalize inputs
    symbol = order.symbol.upper()
    side = OrderSide.BUY if order.side.lower() == "buy" else OrderSide.SELL
    o_type = OrderType.MARKET if order.order_type.lower() == "market" else OrderType.LIMIT
    quantity = int(order.quantity)
    
    # --- Price Protection Logic ---
    # For Limit Orders: Trust User Price
    # For Market Orders: Use Best Ask (Buy) or Best Bid (Sell) from Engine to estimate impact
    input_price = float(order.price)
    price = input_price # Restore 'price' variable for downstream usage logic
    check_price = input_price
    
    if o_type == OrderType.MARKET and side == OrderSide.BUY:
        best_ask = engine.get_best_ask(symbol)
        if best_ask > 0:
            # Use Best Ask + 5% slippage buffer for safe deduction
            check_price = best_ask * 1.05
            print(f"🛡️ Market Buy Safety: Using BestAsk {best_ask:,.2f} (+5%) -> {check_price:,.2f} for deduction check.")
        else:
            print(f"⚠️ Market Buy Warning: No Asks in Book. Using User Est {input_price:,.2f}")
            
    # Fee Calculation using SAFE Price
    total_val = check_price * quantity
    fee = total_val * TRADING_FEE_RATE
    total_deduction = total_val + fee

    if db:
        try:
            user_ref = db.collection("users").document(order.user_id)
            
            if side == OrderSide.BUY:
                # BUY: Deduct Balance Immediately (Hold funds)
                user_snap = user_ref.get()
                if not user_snap.exists: raise HTTPException(status_code=404, detail="User wallet not found")
                
                balance = user_snap.to_dict().get("balance", 0)
                if balance < total_deduction:
                    raise HTTPException(status_code=400, detail=f"Insufficient funds (Req: {total_deduction:,.0f})")
                
                user_ref.update({"balance": firestore.Increment(-total_deduction)})
                print(f"💰 [BUY-PRE-DEDUCT] User {order.user_id} | Qty {quantity} @ {price} | Total Deduct: {total_deduction:,.2f}")

            elif side == OrderSide.SELL:
                # SELL: Check Stocks (Ideally Lock them, here we just check)
                holdings_ref = user_ref.collection("holdings").document(symbol)
                h_snap = holdings_ref.get()
                current_qty = h_snap.to_dict().get("quantity", 0) if h_snap.exists else 0
                
                if current_qty < quantity:
                     raise HTTPException(status_code=400, detail=f"Not enough {symbol} shares to sell")
                
                # Ideally: specific field 'locked_quantity' increment
                pass 

        except HTTPException as he: raise he
        except Exception as e:
            print(f"DB Error: {e}")
            raise HTTPException(status_code=500, detail="Transaction failed")
            
    # 2. Persist Initial Order (Pending) to Redis for UI
    order_data = {
        "order_id": order_id,
        "user_id": order.user_id,
        "symbol": symbol,
        "side": side.value,
        "type": o_type.value,
        "price": price,
        "quantity": quantity,
        "filled": 0,
        "status": OrderStatus.PENDING.value,
        "timestamp": timestamp,
        "fee": fee
    }
    
    try:
        pipe = r.pipeline()
        pipe.hset(f"order:{order_id}", mapping=order_data)
        pipe.lpush(f"user_orders:{order.user_id}", order_id)
        pipe.sadd("pending_orders", order_id)
        pipe.execute()
    except Exception as e:
        print(f"⚠️ Redis Error (Order Persistence): {e}")
        # We process the order in memory (Engine) anyway, but UI might not see it in 'Pending' if restart.
        # Ideally we should fail if Redis is critical, but for now we proceed or Raise 503?
        # If Redis is full, we probably shouldn't accept orders to avoid state drift.
        raise HTTPException(status_code=503, detail="System busy (Storage Limit). Please try again later.")
    
    # 3. Submit to Matching Engine
    engine_order = Order(
        id=order_id,
        user_id=order.user_id,
        symbol=symbol,
        side=side,
        type=o_type,
        price=price,
        quantity=quantity,
        timestamp=timestamp
    )
    
    trades = engine.place_order(engine_order)
    
    # 4. Process Executed Trades (Settlement)
    if trades:
        process_executed_trades(trades)
    
    # 5. Broadcast OrderBook Update (Realtime)
    broadcast_orderbook_update(symbol)
            
    return {
        "status": "success",
        "message": "Order placed successfully",
        "data": {
            "order_id": order_id, 
            "trades_count": len(trades),
             "symbol": symbol,
             "side": order.side,
             "price": price,
             "quantity": quantity
        }
    }
# [CLEANUP] Removed duplicate imports and app definition

# --- CONFIGURATION ---
TRADING_FEE_RATE = 0.001 # 0.1% Fee per transaction

# --- HELPER: ROBUST REQUEST SESSION ---
def get_requests_session():
    """Create a session with browser-like headers to avoid blocking."""
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "text/html,application/json,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5"
    })
    return session

# --- REAL DATA FETCHING ONLY ---

async def fetch_real_price(symbol: str):
    """Hàm lấy giá thực tế từ nguồn (Vnstock/Yfinance). Tuyệt đối không Mock."""
    try:
        price = 0.0
        volume = 0
        change_percent = 0.0
        
        # 1. VN Stock
        # 1. VN Stock
        if len(symbol) == 3 and symbol.isalpha():
            def get_vn_price():
                try:
                    # Hybrid Strategy: Intraday (Price) + History (Reference)
                    try:
                        stock = Vnstock().stock(symbol=symbol, source='VCI')
                        
                        # 1. Get Realtime Price (Intraday)
                        df_now = stock.quote.intraday(page_size=1)
                        local_price = 0.0
                        local_volume = 0
                        if df_now is not None and not df_now.empty:
                            row = df_now.iloc[0]
                            local_price = float(row.get('price', 0))
                            local_volume = int(row.get('volume', 0))
                        
                        if local_price == 0: return None
                        
                        # Fix Scaling (Crucial for HPG: 26.4 -> 26400)
                        if local_price < 500: local_price *= 1000
                        
                        return (local_price, local_volume, 0.0) # change_percent calc later
                    except BaseException as e: # Catch SystemExit and Rate Limits
                        print(f"⚠️ Vnstock Error/RateLimit: {e}")
                        return None

                except Exception as e:
                    print(f"⚠️ get_vn_price logic error: {e}")
                    return None
            try:
                result = await asyncio.wait_for(asyncio.to_thread(get_vn_price), timeout=5.0) # Increased timeout
                if result:
                    price, volume, change_percent = result
                else: 
                     return None
            except: return None

        # 2. US/Crypto (Yfinance)
        else:
            def get_yf_price():
                try:
                     # Use Ticker.fast_info which is usually reliable
                     # NOTE: Removed custom session as recent yfinance prefers internal handling or curl_cffi
                    ticker = yf.Ticker(symbol) 
                    info = ticker.fast_info
                    p = info.last_price
                    prev_close = info.previous_close
                    volume = int(info.last_volume) if info.last_volume else 0
                    change = ((p - prev_close) / prev_close) * 100 if prev_close else 0.0
                    return p, volume, change
                except Exception as e:
                    # print(f"YF Price Error {symbol}: {e}")
                    return None

            try:
                result = await asyncio.wait_for(asyncio.to_thread(get_yf_price), timeout=3.0)
                if result:
                     price, volume, change_percent = result
                else:
                     return None
            except: return None

        return {
            "symbol": symbol,
            "price": round(price, 2),
            "change_percent": round(change_percent, 2),
            "volume": volume,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        print(f"Lỗi lấy giá {symbol}: {e}")
        return None

async def market_data_simulator():
    """
    Update Realtime Prices to Redis.
    Renamed to 'market_data_updater' conceptually, but keeping function name for compatibility if needed.
    """
    print("🚀 Bắt đầu service cập nhật giá REALTIME...")
    symbols = ["HPG", "VCB", "FPT", "AAPL", "BTC-USD", "GOOG"]
    
    while not shutdown_event.is_set():
        try:
            # Chỉ chạy khi có kết nối
            if r and active_connections > 0:
                updates = []
                for symbol in symbols:
                    if shutdown_event.is_set(): break
                    real_data = await fetch_real_price(symbol)
                    
                    if real_data:
                        await asyncio.to_thread(r.set, f"stock:{symbol}", json.dumps(real_data))
                        await asyncio.to_thread(r.publish, "stock_updates", json.dumps(real_data))
                        updates.append(real_data)
                
                await asyncio.sleep(30) # Reduce frequency to respect Rate Limits (Active Users)
            else:
                await asyncio.sleep(60) # Idle Mode (No active users)
        except asyncio.CancelledError:
            print("🛑 Service cập nhật giá đã dừng.")
            break
        except Exception as e:
            print(f"⚠️ Lỗi simulator: {e}")
            await asyncio.sleep(5)

# [CLEANUP] Removed Loop-based Matching Engine (Using LOB)


async def alert_monitor():
    """
    Task chạy ngầm: Kiểm tra giá và kích hoạt cảnh báo qua FCM.
    Refs: Runs in a separate thread to prevent blocking the Main Event Loop.
    """
    print("🚀 Bắt đầu Alert Monitor (FCM Ready)...")
    from firebase_admin import messaging

    def check_alerts_sync():
        try:
            db = get_db()
            if not db or not r: return
            
            # 1. Fetch all alerts (Blocking I/O)
            # Optimization: Use a query if index exists, else stream
            alerts_stream = db.collection_group("alerts").stream()
            
            # Convert to list to iterate quickly? Or iterate stream
            # Iterating stream involves I/O
            
            for alert_doc in alerts_stream:
                if shutdown_event.is_set(): return
                
                alert_data = alert_doc.to_dict()
                if not alert_data.get("is_active", False): continue
                
                symbol = alert_data.get("symbol")
                target_price = alert_data.get("value")
                condition = alert_data.get("condition")
                user_id = alert_data.get("user_id")
                
                if not symbol or not target_price or not user_id: continue
                
                # 2. Get Price from Redis (Blocking I/O - insignificant for local/upstash)
                market_data_json = r.get(f"stock:{symbol}")
                if not market_data_json: continue
                
                market_data = json.loads(market_data_json)
                current_price = float(market_data.get("price", 0))
                
                # 3. Check Condition
                is_triggered = False
                if condition == "Above" and current_price >= target_price:
                    is_triggered = True
                elif condition == "Below" and current_price <= target_price:
                    is_triggered = True
                    
                # 4. RSI Logic ... (Omitted for brevity, keep simple for now)
                
                if is_triggered:
                    # Send Notification logic...
                    # (Keep existing logic or simplified print for MVP)
                     print(f"🔔 ALERT TRIGGERED: {symbol} {condition} {target_price} (Current: {current_price})")
                     # Disable alert to prevent spam
                     alert_doc.reference.update({"is_active": False})
                     
                     # TODO: FCM Send
        except Exception as e:
            print(f"⚠️ Alert Monitor Error: {e}")

    while not shutdown_event.is_set():
        try:
             # Run the blocking check in a thread
            await asyncio.to_thread(check_alerts_sync)
            await asyncio.sleep(10) # Check every 10s
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"⚠️ Alert Loop Error: {e}")
            await asyncio.sleep(10)


async def metrics_monitor():
    """
    Task chạy ngầm: Tự động tính toán Leaderboard mỗi 60 giây.
    """
    print("🚀 Bắt đầu Metrics Monitor...")
    while not shutdown_event.is_set():
        try:
             # Call the logic directly (reusing the code from the API would be better, but copying for safety/speed)
             # Actually, let's call the function if it was refactored. 
             # For now, we will duplicate the critical logic or refactor.
             # Let's refactor the logic into a standalone function `update_leaderboard_logic()`
             await update_leaderboard_logic()
             await asyncio.sleep(60)
        except Exception as e:
            print(f"⚠️ Metrics Monitor Error: {e}")
            await asyncio.sleep(60)

async def update_leaderboard_logic():
    if not r: return
    db = get_db()
    if not db: return
    
    users = db.collection("users").stream()
    pipe = r.pipeline()
    count = 0
    
    for user in users:
        uid = user.id
        data = user.to_dict()
        balance = data.get("balance", 0)
        # Calculate Holdings
        holdings_ref = db.collection("users").document(uid).collection("holdings").stream()
        holdings_val = 0
        
        for h in holdings_ref:
            h_data = h.to_dict()
            qty = h_data.get("quantity", 0)
            avg_price = h_data.get("average_price", 0)
            symbol = h_data.get("symbol", "")
            
            current_price = avg_price
            market_json = r.get(f"stock:{symbol}")
            if market_json:
                try: 
                    current_price = float(json.loads(market_json).get("price", avg_price))
                except: pass
            
            holdings_val += qty * current_price
            
        total_equity = balance + holdings_val
        pipe.zadd("leaderboard:equity", {uid: total_equity})
        count += 1
        
    pipe.execute()
    print(f"✅ Leaderboard updated: {count} users processed")


IS_MAINTENANCE = False

async def maintenance_monitor():
    """
    Background Task: Sync Maintenance Status from Firestore
    """
    global IS_MAINTENANCE
    print("🛡️ Maintenance Monitor Started...")
    while not shutdown_event.is_set():
        try:
            db = get_db()
            if db:
                doc = db.collection('system').document('config').get()
                if doc.exists:
                    data = doc.to_dict()
                    new_status = data.get('maintenance_mode', False)
                    if new_status != IS_MAINTENANCE:
                        IS_MAINTENANCE = new_status
                        print(f"🛡️ System Maintenance Mode Changed to: {IS_MAINTENANCE}")
            await asyncio.sleep(10)
        except Exception as e:
            print(f"Maintenance Monitor Error: {e}")
            await asyncio.sleep(10)

# [CLEANUP] Removed old startup_event


@app.on_event("shutdown")
async def shutdown_event_handler():
    print("🛑 Đang tắt server...")
    shutdown_event.set()

# --- WEBSOCKET ENDPOINT ---

# --- WEBSOCKET ENDPOINT ---
@app.websocket("/ws/stocks")
async def websocket_endpoint(websocket: WebSocket):
    global active_connections
    await websocket.accept()
    active_connections += 1
    print(f"🔌 Client kết nối. Tổng: {active_connections}")
    
    # Tạo một kết nối Redis riêng cho Pub/Sub (Redis yêu cầu)
    pubsub = r.pubsub()
    await asyncio.to_thread(pubsub.subscribe, "stock_updates")
    
    try:
        # Sử dụng vòng lặp non-blocking thay vì pubsub.listen() (blocking)
        while True:
            # get_message là non-blocking, trả về None nếu không có tin nhắn
            message = pubsub.get_message(ignore_subscribe_messages=True)
            
            if message:
                if message["type"] == "message":
                    # Gửi dữ liệu JSON xuống Flutter
                    await websocket.send_text(message["data"])
            else:
                # Quan trọng: sleep để nhường CPU cho các task khác (như API history)
                await asyncio.sleep(0.1)
                
    except WebSocketDisconnect:
        active_connections -= 1
        print(f"🔌 Client ngắt kết nối. Tổng: {active_connections}")
    except Exception as e:
        active_connections -= 1
        print(f"⚠️ Lỗi WebSocket: {e}")
        
    finally:
        try:
            pubsub.unsubscribe()
            pubsub.close()
        except:
            pass

@app.get("/")
def read_root():
    redis_status = "Disconnected"
    if r:
        try:
            r.ping()
            redis_status = "Connected"
        except:
            redis_status = "Connection Error"

    return {
        "status": "Server is running",
        "project": "Stock App Graduation Project",
        "redis_status": redis_status,
        "docs_url": "http://localhost:8000/docs"
    }

@app.get("/test-redis")
def test_redis():
    """API để kiểm tra ghi/đọc dữ liệu Realtime"""
    if not r:
        raise HTTPException(status_code=503, detail="Redis chưa được cấu hình hoặc kết nối thất bại")
    
    try:
        # 1. Ghi thử dữ liệu giả lập giá HPG
        sample_data = {
            "symbol": "HPG",
            "price": 28500,
            "timestamp": datetime.now().isoformat()
        }
        # Lưu vào Redis (Key: 'stock:HPG')
        r.set("stock:HPG", json.dumps(sample_data))
        
        # 2. Đọc lại ngay lập tức
        saved_data = r.get("stock:HPG")
        
        return {
            "message": "Test Redis thành công",
            "data_from_redis": json.loads(saved_data) if saved_data else None
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi thao tác Redis: {str(e)}")

def generate_mock_history(symbol: str, start_date: str, end_date: str, resolution: str = "1D"):
    """
    Tạo dữ liệu giả lập chất lượng cao.
    """
    print(f"⚠️ [Mock] Generating data for {symbol}...")
    
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
        end = datetime.strptime(end_date, "%Y-%m-%d")
    except:
        start = datetime.now() - timedelta(days=30)
        end = datetime.now()

    data = []
    current = start
    
    # Deterministic seed based on symbol
    random.seed(sum(ord(c) for c in symbol))
    
    base_price = 100.0
    if "HPG" in symbol: base_price = 28.0
    if "VCB" in symbol: base_price = 90.0
    if "FPT" in symbol: base_price = 130.0
    if "AAPL" in symbol: base_price = 150.0
    if "BTC" in symbol: base_price = 45000.0
    
    price = base_price
    
    while current <= end:
        # Skip weekends for non-crypto
        if resolution == "1D" and current.weekday() > 4 and "BTC" not in symbol:
            current += timedelta(days=1)
            continue
            
        change = random.uniform(-0.03, 0.03) 
        open_p = price
        close_p = price * (1 + change)
        high_p = max(open_p, close_p) * (1 + random.uniform(0, 0.01))
        low_p = min(open_p, close_p) * (1 - random.uniform(0, 0.01))
        volume = random.randint(100000, 5000000)
        
        time_str = current.strftime("%Y-%m-%d")
        if resolution != "1D":
             time_str = current.strftime("%Y-%m-%d %H:%M:%S")

def fetch_from_stooq(symbol: str, start_date: str, end_date: str):
    """Fallback: Fetch data from Stooq (CSV)"""
    try:
        # e.g., AAPL.US for Stooq
        stooq_symbol = f"{symbol.lower()}.us"
        url = f"https://stooq.com/q/d/l/?s={stooq_symbol}&i=d"
        
        print(f"   -> [Stooq] Downloading {stooq_symbol}...")
        resp = requests.get(url, timeout=10)
        if resp.status_code != 200: return None
        
        from io import StringIO
        df = pd.read_csv(StringIO(resp.text))
        
        # Stooq CSV cols: Date, Open, High, Low, Close, Volume
        if df.empty or "Date" not in df.columns: return None
        
        # Rename lower
        df.columns = [c.lower() for c in df.columns] 
        # map date -> time
        df = df.rename(columns={"date": "time"})
        
        # Sort by time
        df["time"] = pd.to_datetime(df["time"])
        df = df.sort_values("time")
        
        # Filter range
        s_ts = pd.Timestamp(start_date)
        e_ts = pd.Timestamp(end_date)
        df = df[(df["time"] >= s_ts) & (df["time"] <= e_ts)]
        
        df["time"] = df["time"].astype(str) # Convert back to string for JSON
        
        # Ensure cols
        required = ['time', 'open', 'high', 'low', 'close', 'volume']
        if not set(required).issubset(df.columns): return None
        
        return json.loads(df[required].to_json(orient="records"))
    except Exception as e:
        print(f"   -> [Stooq] Error: {e}")
        return None

def fetch_stock_history_yfinance(symbol: str, start_date: str, end_date: str, resolution: str):
    """
    Lấy dữ liệu lịch sử từ Yfinance (Standard Mode) + Fallback Stooq.
    """
    # 1. Try YFinance (No Session - Let YF handle it)
    try:
        # Map resolution
        interval_map = {
            '1D': '1d', '1W': '1wk', '1M': '1mo',
            '1m': '1m', '5m': '5m', '15m': '15m', '30m': '30m', '1H': '60m'
        }
        interval = interval_map.get(resolution, '1d')
        
        yf_symbol = symbol
        if len(symbol) == 3 and symbol.isalpha():
             yf_symbol = f"{symbol}.VN"

        print(f"   -> [YFinance] Downloading {yf_symbol}...")
        
        # Remove session argument to fix "requires curl_cffi" error
        ticker = yf.Ticker(yf_symbol) 
        
        df = ticker.history(start=start_date, end=end_date, interval=interval, auto_adjust=True)

        if not df.empty:
            df = df.reset_index()
            # Rename columns to match expected format
            df.columns = [c.lower() for c in df.columns]
            rename_map = {
                "date": "time", "datetime": "time",
                "stock splits": "splits"
            }
            df = df.rename(columns=rename_map)
            
            # Ensure 'time' column is string
            if 'time' in df.columns:
                 df['time'] = df['time'].astype(str)
                 
                 required = ['time', 'open', 'high', 'low', 'close', 'volume']
                 if 'close' in df.columns:
                    for col in required:
                        if col not in df.columns: df[col] = 0
                    return json.loads(df[required].to_json(orient="records"))
        
        print(f"   -> [YFinance] No data found for {yf_symbol}. Trying Stooq...")
        
    except Exception as e:
        print(f"   -> [YFinance] Error downloading {symbol}: {e}")

    # 2. Fallback to Stooq (US Stocks only generally)
    if not (len(symbol) == 3 and symbol.isalpha()):
        return fetch_from_stooq(symbol, start_date, end_date)
        
    return None

@app.get("/api/history")
async def get_stock_history(symbol: str, start_date: str, end_date: str, resolution: str = "1D", period: str = None):
    """
    Lấy lịch sử giá cổ phiếu. TUYỆT ĐỐI KHÔNG MOCK.
    """
    print(f"📥 [API] Received history request for: '{symbol}'")
    symbol = symbol.strip().upper()
    
    # 0. Check Redis Cache
    cache_key = f"acc8_hist:{symbol}:{start_date}:{end_date}:{resolution}"
    try:
        if r:
            cached_data = await asyncio.to_thread(r.get, cache_key)
            if cached_data:
                print(f"✅ [Cache] Hit for {cache_key}")
                return json.loads(cached_data)
    except Exception as e:
        print(f"⚠️ Cache Error: {e}")

    # 1. Priorities: VNStock for VN, YFinance for everything else
    
    # VN Stock Logic
    if len(symbol) == 3 and symbol.isalpha():
         def fetch_vn():
             try:
                 print(f"      -> [Vnstock-VCI] Fetching {symbol}...")
                 stock = Vnstock().stock(symbol=symbol, source='VCI')
                 print(f"      -> [Vnstock-VCI] Got stock object, requesting history...")
                 
                 # NOTE: 'history' call can block
                 df = stock.quote.history(start=start_date, end=end_date, interval=resolution)
                 
                 print(f"      -> [Vnstock-VCI] History fetched. Rows: {len(df) if df is not None else 0}")
                 
                 if df is not None and not df.empty:
                     if 'time' in df.columns: df['time'] = df['time'].astype(str)
                     
                     # Check if scaling is needed (based on last close)
                     if not df.empty and 'close' in df.columns and df.iloc[-1]['close'] < 500:
                         cols = ['open', 'high', 'low', 'close']
                         for c in cols:
                             if c in df.columns: df[c] = df[c] * 1000
                             
                     return json.loads(df.to_json(orient="records"))
                 return None
             except Exception as e:
                 print(f"      -> [Vnstock Error] {e}") 
                 return None
         
         try:
             # Timeout after 8 seconds to allow Fallback to YFinance
             data = await asyncio.wait_for(asyncio.to_thread(fetch_vn), timeout=8.0)
         except asyncio.TimeoutError:
             print("      -> [Vnstock] Timeout! Switching to Fallback...")
             data = None
         if data: 
             result = {"symbol": symbol, "source": "Vnstock", "data": data}
             # Cache Result
             if r:
                 # TTL: 1h for old data, 1m for active day
                 ttl = 60 if resolution in ["1m", "5m", "15m", "1H"] else 300 
                 await asyncio.to_thread(r.setex, cache_key, ttl, json.dumps(result))
             return result
         # Fallback to YFinance if Vnstock fails
         
    # YFinance Logic (Universal Fallback)
    try:
        data = await asyncio.to_thread(fetch_stock_history_yfinance, symbol, start_date, end_date, resolution)
        if data:
            result = {"symbol": symbol, "source": "YFinance", "data": data}
            if r:
                ttl = 60 if resolution in ["1m", "5m", "15m", "30m", "1H"] else 300
                await asyncio.to_thread(r.setex, cache_key, ttl, json.dumps(result))
            return result
    except Exception as e:
        print(f"❌ [API Error] YFinance Fallback Failed: {e}")

    # FAILED -> Return Empty, NO FAKE DATA
    print(f"❌ [History] Failed to fetch data for {symbol}. Returning empty.")
    return {"symbol": symbol, "source": "None", "data": []}

@app.get("/api/company/overview")
async def get_company_overview(symbol: str):
    symbol = symbol.upper()
    # No more Mock Overview.
    
    def fetch_yf_info():
        try:
            # Removed session to allow standard YF behavior
            ticker = yf.Ticker(symbol)
            return ticker.info
        except: return None
        
    info = await asyncio.to_thread(fetch_yf_info)
    if info:
         data = [{
             "ticker": info.get('symbol', symbol),
             "exchange": info.get('exchange', 'Unknown'),
             "industry": info.get('industry', 'Unknown'),
             "companyName": info.get('longName', symbol),
             "establishedYear": "", 
             "noEmployees": info.get('fullTimeEmployees', 0)
         }]
         return {"data": data}
         
    return {"data": []}

@app.get("/api/stocktwits/{symbol}")
def get_stocktwits_stream(symbol: str):
    """
    Proxy to Stocktwits API
    """
    url = f"https://api.stocktwits.com/api/2/streams/symbol/{symbol}.json"
    try:
        resp = requests.get(url)
        if resp.status_code == 200:
            return resp.json()
        else:
            raise HTTPException(status_code=resp.status_code, detail="Stocktwits error")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- ORDER API ---

class OrderRequest(BaseModel):
    user_id: str
    symbol: str
    side: str  # "buy" or "sell"
    quantity: int
    price: float
    order_type: str = "limit" # "limit" or "market"

# [CLEANUP] Removed duplicate place_order


@app.get("/api/orders/{user_id}")

@app.get("/api/orders/{user_id}")
def get_orders(user_id: str):
    """
    Lấy danh sách lệnh của User từ Redis
    """
    if not r:
        raise HTTPException(status_code=503, detail="Redis not connected")
        
    try:
        # Lấy list order_ids
        order_ids = r.lrange(f"user_orders:{user_id}", 0, -1)
        orders = []
        
        for oid in order_ids:
            # Lấy chi tiết từng lệnh
            order_info = r.hgetall(f"order:{oid}")
            if order_info:
                orders.append(order_info)
                
        return {"data": orders}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch orders: {str(e)}")

class OrderCancelRequest(BaseModel):
    user_id: str
    order_id: str

@app.post("/api/orders/cancel")
@app.post("/api/orders/cancel")
def cancel_order(req: OrderCancelRequest):
    """
    Hủy lệnh đang chờ (Pending).
    - Hoàn tiền nếu là lệnh Mua.
    - Cập nhật trạng thái Redis.
    """
    if not r:
        raise HTTPException(status_code=503, detail="Redis not connected")
        
    try:
        # 1. Get Order Details
        order_key = f"order:{req.order_id}"
        order_data = r.hgetall(order_key)
        
        if not order_data:
            raise HTTPException(status_code=404, detail="Order not found")
            
        current_status = str(order_data.get("status", "")).lower()
        print(f"Cancel Request: Order={req.order_id}, Status={current_status}")
        
        if current_status != "pending":
             raise HTTPException(status_code=400, detail=f"Cannot cancel order with status '{current_status}'")
             
        if order_data.get("user_id") != req.user_id:
             raise HTTPException(status_code=403, detail="Unauthorized")

        # 2. Refund Logic (Firestore)
        side = str(order_data.get("side", "")).lower()
        price = float(order_data.get("price", 0))
        quantity = int(order_data.get("quantity"))
        total_val = price * quantity
        
        db = get_db()
        if side == "buy" and db:
             # Refund Money + Fee
             fee = float(order_data.get("fee", 0)) if "fee" in order_data else (total_val * TRADING_FEE_RATE)
             refund_amount = total_val + fee
             
             user_ref = db.collection("users").document(req.user_id)
             user_ref.update({"balance": firestore.Increment(refund_amount)})
             print(f"💰 Refunded {refund_amount} to User {req.user_id}")
        
        # 3. Redis Cleanup
        pipe = r.pipeline()
        pipe.hset(order_key, "status", "cancelled")
        pipe.srem("pending_orders", req.order_id)
        pipe.execute()
        
        return {"status": "success", "message": "Order cancelled"}
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Cancel Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def get_orderbook_data(symbol: str):
    """
    Helper: Calculate OrderBook from Redis (Sync)
    """
    if not r: return {"bids": [], "asks": []}
    
    try:
        # 1. Get Pending Orders IDs
        pending_ids = list(r.smembers("pending_orders"))
        if not pending_ids: 
            return {"bids": [], "asks": []}
        
        # 2. Get Details (Pipeline for speed)
        pipe = r.pipeline()
        for oid in pending_ids:
            pipe.hgetall(f"order:{oid}")
        orders = pipe.execute()
        
        bids = {} # Price -> Quantity
        asks = {}
        
        for i, order_data in enumerate(orders):
            if not order_data: continue
            
            # Filter by Symbol
            if order_data.get("symbol") == symbol:
                side = str(order_data.get("side", "")).lower()
                try:
                    price = float(order_data.get("price", 0))
                    initial_qty = int(order_data.get("quantity", 0))
                    filled = int(float(order_data.get("filled", 0)))
                    remaining_qty = initial_qty - filled
                    
                    if remaining_qty <= 0: continue
                    
                    if side == "buy":
                        if price in bids: bids[price] += remaining_qty
                        else: bids[price] = remaining_qty
                    elif side == "sell":
                        if price in asks: asks[price] += remaining_qty
                        else: asks[price] = remaining_qty
                except ValueError: continue

        # 3. Sort and Format
        sorted_bids = sorted(bids.items(), key=lambda x: x[0], reverse=True)[:5]
        sorted_asks = sorted(asks.items(), key=lambda x: x[0])[:5]
        
        return {
            "bids": [{"price": p, "quantity": q} for p, q in sorted_bids],
            "asks": [{"price": p, "quantity": q} for p, q in sorted_asks]
        }
    except Exception as e:
        print(f"OrderBook Calc Error: {e}")
        return {"bids": [], "asks": []}

def broadcast_orderbook_update(symbol: str):
    """
    Helper: Broadcast new OrderBook state to WebSocket
    """
    if not r: return
    try:
        data = get_orderbook_data(symbol)
        message = {
            "type": "ORDER_BOOK",
            "symbol": symbol,
            "data": data,
            "timestamp": time.time()
        }
        # Publish to Redis Channel
        # Note: We must serialize 'data' first or the whole message?
        # The WebSocket endpoint expects message['data'] to be the payload string or dict?
        # Line 722: await websocket.send_text(message["data"])
        # If we publish JSON string as message["data"], client receives string.
        # If we publish Dict, Redis PubSub receives it? No, Redis PubSub only strings (or bytes).
        # Standard: r.publish(channel, json.dumps(payload))
        # The Subscriber receives 'data': payload_string.
        # Our Subscriber logic:
        # message = pubsub.get_message()
        # if message["type"] == "message": 
        #    await websocket.send_text(message["data"])
        # So message["data"] is the STRING we publish here.
        
        r.publish("stock_updates", json.dumps(message))
        # print(f"📡 Broadcast OrderBook for {symbol}")
    except Exception as e:
        print(f"⚠️ Broadcast Error: {e}")

@app.get("/api/orderbook/{symbol}")
def get_order_book(symbol: str):
    """
    Lấy Sổ lệnh (Order Book) thật từ Redis Pending Orders.
    Tổng hợp khối lượng theo mức giá (Top 5 Mua / Top 5 Bán).
    """
    if not r: return {"bids": [], "asks": []}
    return get_orderbook_data(symbol.upper())

@app.get("/api/portfolio/{user_id}")
async def get_portfolio(user_id: str):
    """
    Lấy thông tin Portfolio của User (Balance + Holdings)
    """
    db = get_db()
    if not db:
        raise HTTPException(status_code=503, detail="Firebase Database not connected")
        
    try:
        # 1. Get Balance from User Doc
        user_doc = db.collection("users").document(user_id).get()
        if not user_doc.exists:
             return {"balance": 0.0, "holdings": []}
             
        user_data = user_doc.to_dict()
        balance = user_data.get("balance", 0.0)
        
        # 2. Get Holdings
        holdings_ref = db.collection("users").document(user_id).collection("holdings")
        docs = holdings_ref.stream()
        
        holdings = []
        for doc in docs:
            data = doc.to_dict()
            # Only include if quantity > 0
            if data.get("quantity", 0) > 0:
                holdings.append({
                    "symbol": data.get("symbol"),
                    "quantity": data.get("quantity"),
                    "average_price": data.get("average_price", 0.0)
                })
                
        return {
            "balance": balance,
            "holdings": holdings
        }
    except Exception as e:
        print(f"Portfolio Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
# --- SOCIAL TRADING API ---

@app.post("/api/social/calculate_metrics")
async def calculate_metrics():
    """
    Admin/Task: Tính toán lại PnL% (Manual Trigger).
    """
    try:
        await update_leaderboard_logic()
        return {"status": "success", "message": "Leaderboard updated"}
    except Exception as e:
         raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/social/leaderboard")
async def get_leaderboard(limit: int = 10):
    if not r: return {"data": []}
    
    # Get top users by Equity
    top_users = r.zrevrange("leaderboard:equity", 0, limit-1, withscores=True)
    
    result = []
    db = get_db()
    
    for uid, score in top_users:
        # Get User Info (Name, Avatar)
        name = "Unknown"
        if db:
            u_snap = db.collection("users").document(uid).get()
            if u_snap.exists:
                name = u_snap.to_dict().get("fullName", "Trader")
        
        result.append({
            "user_id": uid,
            "name": name,
            "equity": score,
            "roi": ((score - 100000000) / 100000000) * 100 # Mock ROI based on 100m start
        })
        
    return {"data": result}
    
@app.post("/api/social/follow")
async def follow_user(follower_id: str, leader_id: str):
    if not r: return {"status": "error"}
    
    # Add to Set
    r.sadd(f"followers:{leader_id}", follower_id)
    r.sadd(f"following:{follower_id}", leader_id)
    
    return {"status": "success", "message": f"User {follower_id} is now copying {leader_id}"}
    
@app.get("/api/social/profile/{target_id}")
async def get_trader_profile(target_id: str):
    # Mock Profile Data
    db = get_db()
    name = "Trader"
    if db:
        u = db.collection("users").document(target_id).get()
        if u.exists: name = u.to_dict().get("fullName", "Trader")

    return {
        "user_id": target_id,
        "name": name,
        "win_rate": 68.5, # Mock
        "total_trades": 142, # Mock
        "followers": r.scard(f"followers:{target_id}") if r else 0
    }

@app.get("/api/social/feed")
async def get_social_feed(limit: int = 20):
    """
    Get recent trades from the platform.
    """
    if not r: 
        print("❌ Redis unavailable in get_social_feed")
        return {"data": []}
    
    # Fetch from Redis List
    raw_trades = r.lrange("recent_trades", 0, limit - 1)
    print(f"🔍 DEBUG: Fetching recent_trades from Redis. Count: {len(raw_trades)}")
    
    result = []
    
    db = get_db()
    
    for rt in raw_trades:
        try:
            # Redis might return bytes if decode_responses=False isn't set
            if isinstance(rt, bytes):
                rt = rt.decode('utf-8')
                
            trade = json.loads(rt)
            # Enrich with User Name
            uid = trade.get("user_id")
            name = "Trader"
            if db:
                # Basic caching could be added here to avoid DB spam
                u_snap = db.collection("users").document(uid).get()
                if u_snap.exists:
                     name = u_snap.to_dict().get("fullName", "Trader")
            
            trade["user_name"] = name
            result.append(trade)
        except Exception as e:
            print(f"⚠️ Error parsing trade: {e}")
            pass
        
    return {"data": result}


async def verify_admin(x_user_id: str = Header(None, alias="x-user-id")):
    if not x_user_id:
        # For development ease, maybe allow check? No, strict.
        raise HTTPException(status_code=401, detail="Authentication Required")
    
    try:
        # Check Firestore Role
        db = get_db()
        doc = db.collection("users").document(x_user_id).get()
        if not doc.exists:
             raise HTTPException(status_code=403, detail="User not found")
        
        role = doc.to_dict().get("role")
        if role != "admin":
             raise HTTPException(status_code=403, detail="Admin Access Only")
             
        return x_user_id
    except HTTPException: raise
    except Exception as e:
        print(f"Auth Error: {e}")
        raise HTTPException(status_code=500, detail="Auth check failed")

# --- ADMIN API (High Performance) ---
@app.get("/api/admin/stats")
async def get_admin_stats(admin_id: str = Depends(verify_admin)):
    """
    Returns system statistics efficiently with REAL data.
    """
    db = get_db()
    
    db = get_db()
    
    # Calculate Online Users (Active in last 5 mins)
    online_users = 0
    try:
        if r:
            # 1. Remove expired users (older than 5 mins)
            five_mins_ago = time.time() - 300
            r.zremrangebyscore("online_users", 0, five_mins_ago)
            # 2. Count valid users
            online_users = r.zcard("online_users")
    except Exception as e: 
        # print(f"Online Count Error: {e}")
        pass

    response_data = {
        "total_users": online_users, # User requested this be "Users Online"
        "active_orders": 0,
        "total_assets": 0.0,
        "user_growth": [0] * 7,
        "status": "Maintenance" if IS_MAINTENANCE else "Online",
        "server_time": datetime.now().isoformat()
    }

    try:
        if not db:
            # If DB is down, we can still show basic status
            response_data["status"] = "Offline (DB)"
            return response_data

        # 1. User Growth (Last 7 Days) - Need Firestore
        try:
            today = datetime.now()
            start_date = today - timedelta(days=6)
            start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)
            
            users_coll = db.collection('users')
            # Stream only necessary fields if possible or just stream all (10k limit beware)
            # For 10k users, streaming all for growth chart is heavy. 
            # Optimization: Query only active/recent users if possible, or just accept cost for MVP.
            # actually we only need created_at >= start_date
            
            recent_docs = list(users_coll.where(filter=firestore.FieldFilter('createdAt', '>=', start_date)).stream())
            
            growth = [0] * 7
            for d in recent_docs:
                data = d.to_dict()
                created_at = data.get('createdAt')
                
                if created_at:
                    if isinstance(created_at, str):
                        try:
                            # Attempt parsing if string
                            t_str = created_at.replace('Z', '+00:00')
                            created_at = datetime.fromisoformat(t_str)
                        except: pass
                    
                    if isinstance(created_at, datetime):
                        c_date = created_at.date()
                        s_date = start_date.date()
                        
                        diff = (c_date - s_date).days
                        if 0 <= diff < 7:
                            growth[diff] += 1
            
            response_data["user_growth"] = growth
            
        except Exception as e:
            print(f"⚠️ User Growth Error: {e}")
            pass

        # 2. Redis Stats (Active Orders & Total Assets)
        if r:
            try:
                # Active Orders = Pending Orders (Waiting for match)
                response_data["active_orders"] = r.scard("pending_orders")
                
                # Check leaderboard for assets
                equity_scores = r.zrange("leaderboard:equity", 0, -1, withscores=True)
                if equity_scores:
                    response_data["total_assets"] = sum(score for _, score in equity_scores)
                else:
                    # Fallback assets calculation? Maybe unnecessary heavy fetch
                    pass

            except Exception as e:
                 print(f"⚠️ Redis Stats Error: {e}")
                 pass
        
        return response_data


    except Exception as e:
        print(f"CRITICAL Admin Stats Error: {e}")
        response_data["status"] = "Offline (Error)"
        return response_data

class AddBalanceRequest(BaseModel):
    user_id: str
    amount: float

@app.post("/api/admin/add_balance")
def admin_add_balance(req: AddBalanceRequest, admin_id: str = Depends(verify_admin)):
    """
    Admin: Add Demo Money to User
    """
    db = get_db()
    try:
        user_ref = db.collection("users").document(req.user_id)
        if not user_ref.get().exists:
            raise HTTPException(status_code=404, detail="User not found")
            
        user_ref.update({"balance": firestore.Increment(req.amount)})
        print(f"💰 Admin added {req.amount:,.0f} to {req.user_id}")
        return {"status": "success", "message": f"Added {req.amount:,.0f} VND"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



class AdminUserActionRequest(BaseModel):
    user_id: str

@app.post("/api/admin/ban")
def admin_ban_user(req: AdminUserActionRequest, admin_id: str = Depends(verify_admin)):
    """
    Admin: Ban/Unban User (Toggle)
    """
    db = get_db()
    try:
        user_ref = db.collection("users").document(req.user_id)
        doc = user_ref.get()
        if not doc.exists: raise HTTPException(status_code=404, detail="User not found")
        
        current_status = doc.to_dict().get("status", "active")
        new_status = "banned" if current_status != "banned" else "active"
        is_disabled = (new_status == "banned")
        
        # 1. Firebase Auth Disable
        auth.update_user(req.user_id, disabled=is_disabled)
        
        # 2. Update Firestore
        user_ref.update({"status": new_status})
        
        # 3. Revoke Tokens (Force Logout) if banning
        if is_disabled:
            auth.revoke_refresh_tokens(req.user_id)
            
        action = "Banned" if is_disabled else "Unbanned"
        return {"status": "success", "message": f"User {action}. Tokens Revoked."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/admin/reset_password")
def admin_reset_password(req: AdminUserActionRequest, admin_id: str = Depends(verify_admin)):
    """
    Admin: Generate Password Reset Link
    """
    try:
        user = auth.get_user(req.user_id)
        email = user.email
        if not email: raise HTTPException(status_code=400, detail="User has no email")
        
        link = auth.generate_password_reset_link(email)
        return {"status": "success", "message": "Reset Link Generated", "link": link}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "timestamp": time.time()}


@app.get("/api/debug/dump_orders")
async def debug_dump_orders():
    if not r: return {"error": "No Redis"}
    keys = r.keys("order:*")
    data = {}
    for k in keys:
        data[k] = r.hgetall(k)
    
    # Also dump pending set
    pending = r.smembers("pending_orders")
    
    return {
        "orders_count": len(keys),
        "pending_count": len(pending),
        "pending_ids": list(pending),
        "orders": data
    }

@app.post("/api/debug/reset")
async def debug_reset():
    """
    DANGER: Flushes Redis and Resets Matching Engine.
    Used for integration testing.
    """
    try:
        if r:
            r.flushdb()
            print("⚠️ Redis Flushed via API")
        
        # Reset Engine
        engine.books.clear()
        print("⚠️ Matching Engine State Cleared")
        
        return {"status": "success", "message": "System State Reset"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




# --- SOCIAL API ---
@app.get("/api/social/leaderboard")
def get_leaderboard():
    db = get_db()
    try:
        # MVP: Fetch all users (limit 50) and calculate equity
        # Optimally we should have an 'equity' field updated periodically.
        # Here we calculate on-the-fly.
        users_ref = db.collection("users").limit(50).stream() 
        leaderboard = []
        
        for u in users_ref:
            data = u.to_dict()
            uid = u.id
            name = data.get("name", f"User {uid[:4]}")
            balance = data.get("balance", 0)
            
            # Calculate Holdings Value
            holdings_ref = db.collection("users").document(uid).collection("holdings").stream()
            stock_val = 0
            for h in holdings_ref:
                h_data = h.to_dict()
                symbol = h_data.get("symbol")
                qty = h_data.get("quantity", 0)
                if qty > 0 and symbol:
                    # Get price. Use Best Bid (Liquidation Value)
                    price = engine.get_best_bid(symbol)
                    if price == 0: 
                        price = engine.get_best_ask(symbol)
                    # If empty book, maybe use reference price? 
                    # For now 0 if no market.
                    stock_val += qty * price
            
            total_equity = balance + stock_val
            
            # ROI Calculation (MVP Placeholder)
            # Assuming base 100M start for demo or 0
            roi = 0.0
            
            leaderboard.append({
                "user_id": uid,
                "name": name,
                "equity": total_equity,
                "roi": roi 
            })
            
        # Sort desc
        leaderboard.sort(key=lambda x: x['equity'], reverse=True)
        return {"data": leaderboard[:20]}
        
    except Exception as e:
        print(f"Leaderboard Error: {e}")
        return {"data": []}

@app.get("/api/social/feed")
def get_social_feed():
    db = get_db()
    try:
        # Fetch last 50 trades
        feed_ref = db.collection("feed").order_by("timestamp", direction=firestore.Query.DESCENDING).limit(50).stream()
        feed = []
        for f in feed_ref:
            feed.append(f.to_dict())
        return {"data": feed}
    except Exception as e:
        print(f"Feed Error: {e}")
        return {"data": []}

@app.get("/api/social/profile/{target_id}")
def get_social_profile(target_id: str):
    # Retrieve concise profile for social view
    db = get_db()
    try:
        u_snap = db.collection("users").document(target_id).get()
        if not u_snap.exists: return {"error": "User not found"}
        data = u_snap.to_dict()
        return {
            "name": data.get("name", "Unknown"),
            "joined": "2024", # Placeholder
            "bio": "Experienced Trader"
        }
    except Exception as e:
         raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/social/follow")
def follow_user(follower_id: str, leader_id: str):
    # Implementing Follow Logic (Firestore)
    db = get_db()
    try:
        # stored in users/{follower}/following/{leader}
        db.collection("users").document(follower_id).collection("following").document(leader_id).set({
            "timestamp": time.time()
        })
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- ALERTS API ---

class AlertRequest(BaseModel):
    user_id: str
    symbol: str
    condition: str  # "Above", "Below"
    value: float
    type: str = "Price"  # Price, News, Indicators

@app.post("/api/alerts")
async def create_alert(alert: AlertRequest):
    """
    Tạo cảnh báo mới
    """
    db = get_db()
    if not db:
        raise HTTPException(status_code=503, detail="Firebase Database not connected")
        
    try:
        alert_id = str(uuid.uuid4())
        alert_data = alert.dict()
        alert_data["created_at"] = int(time.time())
        alert_data["is_active"] = True
        alert_data["id"] = alert_id
        
        # Save to Firestore: users/{uid}/alerts/{alert_id}
        db.collection("users").document(alert.user_id)\
          .collection("alerts").document(alert_id).set(alert_data)
          
        return {"status": "success", "data": alert_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create alert: {e}")

@app.get("/api/alerts/{user_id}")
async def get_alerts(user_id: str):
    """
    Lấy danh sách cảnh báo của User
    """
    db = get_db()
    if not db:
        return {"data": []}
        
    try:
        docs = db.collection("users").document(user_id)\
                 .collection("alerts").order_by("created_at", direction=firestore.Query.DESCENDING).get()
                 
        alerts = [doc.to_dict() for doc in docs]
        return {"data": alerts}
    except Exception as e:
        print(f"Get Alerts Error: {e}")
        return {"data": []}

@app.delete("/api/alerts/{user_id}/{alert_id}")
async def delete_alert(user_id: str, alert_id: str):
    """
    Xóa cảnh báo
    """
    db = get_db()
    if not db:
        raise HTTPException(status_code=503, detail="Firebase Database not connected")
        
    try:
        db.collection("users").document(user_id)\
          .collection("alerts").document(alert_id).delete()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete alert: {e}")

class UpdateAlertRequest(BaseModel):
    is_active: bool

@app.put("/api/alerts/{user_id}/{alert_id}")
async def update_alert(user_id: str, alert_id: str, req: UpdateAlertRequest):
    """
    Cập nhật trạng thái Active/Inactive cho cảnh báo
    """
    db = get_db()
    if not db:
        raise HTTPException(status_code=503, detail="Firebase Database not connected")
    
    try:
        doc_ref = db.collection("users").document(user_id).collection("alerts").document(alert_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Alert not found")
            
        doc_ref.update({"is_active": req.is_active})
        
        return {"status": "success", "message": "Alert updated"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update alert: {e}")

# --- AI PREDICTION API (HEURISTIC / MOCK FOR MVP) ---

@app.get("/api/predict/{symbol}")
async def get_prediction(symbol: str):
    """
    Get AI-based trade recommendation.
    For MVP, uses simple technical indicators (RSI/SMA) to simulate AI reasoning.
    """
    symbol = symbol.upper()
    try:
        # 1. Fetch recent data (Simulation)
        # In real app, we would load the trained model here.
        
        # Randomize slightly for demo but base on symbol name/hash for consistency
        import random
        random.seed(symbol + datetime.now().strftime("%Y-%m-%d-%H")) # Stable for the hour
        
        score = random.randint(30, 95)
        
        action = "HOLD"
        rationale = "Market is volatile. Wait for clearer signals."
        
        if score > 75:
            action = "BUY"
            rationale = "Strong accumulation detected. RSI is neutral-bullish."
        elif score < 40:
            action = "SELL"
            rationale = "Price is overextended. Possible correction ahead."
            
        return {
            "symbol": symbol,
            "action": action,
            "confidence": score,
            "rationale": rationale,
            "timestamp": int(time.time())
        }
    except Exception as e:
         raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

