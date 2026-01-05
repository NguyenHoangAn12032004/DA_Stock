import sys
import redis
import yfinance as yf
import json
from datetime import datetime
sys.stdout.reconfigure(encoding='utf-8')

# Config
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
USD_VND_RATE = 25450.0
SYMBOLS = ["AAPL", "GOOG", "TSLA", "MSFT", "NVDA", "BTC-USD"]

def force_update():
    print("🚀 Force Updating Redis Prices to VND...")
    try:
        r = redis.from_url(REDIS_URL, decode_responses=True)
        
        for symbol in SYMBOLS:
            print(f"   Fetching {symbol}...")
            try:
                ticker = yf.Ticker(symbol)
                info = ticker.fast_info
                p_usd = info.last_price
                
                if p_usd:
                    p_vnd = round(p_usd * USD_VND_RATE)
                    
                    # Update Price Key
                    r.set(f"price:{symbol}", p_vnd)
                    
                    # Update Market Data Channel (for Socket)
                    payload = {
                        "type": "PRICE_UPDATE",
                        "symbol": symbol,
                        "price": p_vnd,
                        "change_percent": 0.0, # Placeholder
                        "volume": int(info.last_volume) if info.last_volume else 0,
                        "timestamp": datetime.now().isoformat()
                    }
                    r.publish("market_data", json.dumps(payload))
                    
                    print(f"      ✅ Set {symbol} = {p_vnd:,} VND")
            except Exception as e:
                print(f"      ❌ Error {symbol}: {e}")
                
        print("\n✨ Force Update Complete.")
        
    except Exception as e:
        print(f"Global Error: {e}")

if __name__ == "__main__":
    force_update()
