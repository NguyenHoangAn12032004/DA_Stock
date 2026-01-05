import asyncio
import time
import random
import uuid
from matching_engine import engine, Order, OrderSide, OrderType, OrderStatus
from vnstock import Vnstock

# Simple caching for bot start price to avoid frequent API calls
# In simulation, we want the bot to create orders around a "Reference Price"
# The Reference Price can be updated from real API every minute.
PRICE_CACHE = {}

async def fetch_reference_price(symbol: str) -> float:
    # MVP: Mock fetching or simple logic
    # Try to get from cache
    if symbol in PRICE_CACHE and time.time() - PRICE_CACHE[symbol]['time'] < 60:
        return PRICE_CACHE[symbol]['price']
    
    # Simulate fetch from DB or Real API (Using simple requests for speed or mock)
    # Here we mock for stability in this standalone script example, 
    # but ideally this calls your `fetch_real_price` logic.
    # We'll default to a static map or random if fails.
    
    base_prices = {
        'HPG': 28000, 'VCB': 88000, 'FPT': 96000, 
        'VNM': 67000, 'TCB': 34000, 'SSI': 32000,
        'AAPL': 185.0, 'TSLA': 235.0, 'BTC-USD': 45000.0
    }
    
    price = base_prices.get(symbol, 20000.0) # Fallback
    
    # Add some noise to reference
    noise = random.uniform(-0.01, 0.01) # +/- 1%
    price = price * (1 + noise)
    
    PRICE_CACHE[symbol] = {'price': price, 'time': time.time()}
    return price

async def run_bot_cycle(symbol: str, callback=None, redis_client=None):
    ref_price = await fetch_reference_price(symbol)
    if not ref_price: return

    # Bot Parameters
    spread_percent = 0.002 # 0.2% Spread
    num_orders = 3
    
    # Helper to sync to Redis
    def sync_to_redis(order: Order):
        if not redis_client: return
        data = {
            "order_id": order.id,
            "user_id": order.user_id,
            "symbol": order.symbol,
            "side": order.side.value.lower(), # Standardize lowercase
            "type": order.type.value.lower(),
            "price": order.price,
            "quantity": order.quantity,
            "filled": order.filled_quantity,
            "status": "pending",
            "timestamp": order.timestamp
        }
        redis_client.hset(f"order:{order.id}", mapping=data)
        redis_client.sadd("pending_orders", order.id)

    # 1. Place ASKS (Sell Orders) above ref_price
    for i in range(num_orders):
        # Price increases as we go up the book
        level_price = ref_price * (1 + spread_percent * (i + 1))
        # Round logic (important for VND vs USD)
        if ref_price > 1000: # VND
            level_price = round(level_price / 50) * 50 # Round to nearest 50 dong
        else: # USD
            level_price = round(level_price, 2)
            
        ask_order = Order(
            id=f"BOT_ASK_{uuid.uuid4().hex[:8]}",
            user_id="MARKET_MAKER_BOT",
            symbol=symbol,
            side=OrderSide.SELL,
            type=OrderType.LIMIT,
            price=level_price,
            quantity=random.randint(10, 100) * 10
        )
        sync_to_redis(ask_order) # Persist first
        trades = engine.place_order(ask_order)
        if trades and callback: await callback(trades)

    # 2. Place BIDS (Result Orders) below ref_price
    for i in range(num_orders):
        # Price decreases as we go down
        level_price = ref_price * (1 - spread_percent * (i + 1))
        if ref_price > 1000:
            level_price = round(level_price / 50) * 50
        else:
            level_price = round(level_price, 2)

        bid_order = Order(
            id=f"BOT_BID_{uuid.uuid4().hex[:8]}",
            user_id="MARKET_MAKER_BOT",
            symbol=symbol,
            side=OrderSide.BUY,
            type=OrderType.LIMIT,
            price=level_price,
            quantity=random.randint(10, 100) * 10
        )
        sync_to_redis(bid_order) # Persist first
        trades = engine.place_order(bid_order)
        if trades and callback: await callback(trades)
        
    # print(f"🤖 Bot refreshed liquidity for {symbol} around {ref_price}")

async def start_market_maker(on_trade_callback=None, redis_client=None):
    print("🤖 Market Maker Bot Started...")
    symbols = ['HPG', 'VCB', 'FPT', 'AAPL', 'BTC-USD']
    
    while True:
        try:
            for s in symbols:
                await run_bot_cycle(s, on_trade_callback, redis_client)
            
            # Sleep 10 seconds (slower to reduce spam for now)
            await asyncio.sleep(10)
            
        except Exception as e:
            print(f"Bot Error: {e}")
            await asyncio.sleep(5)


if __name__ == "__main__":
    # Test run
    asyncio.run(start_market_maker())
