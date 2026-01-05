import redis
import yfinance as yf
import json
from datetime import datetime
import sys

sys.stdout.reconfigure(encoding='utf-8')

# Config
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
USD_VND_RATE = 25450.0
SYMBOLS = ["AAPL", "GOOG", "TSLA", "MSFT", "NVDA", "BTC-USD"]

def force_update_stock_keys():
    print("🚀 Force Updating STOCK KEYS and Publishing to VND...")
    try:
        r = redis.from_url(REDIS_URL, decode_responses=True)
        
        for symbol in SYMBOLS:
            print(f"   Fetching {symbol}...")
            try:
                # 1. Fetch
                ticker = yf.Ticker(symbol)
                info = ticker.fast_info
                p_usd = info.last_price
                
                if p_usd:
                    # 2. Convert
                    p_vnd = round(p_usd * USD_VND_RATE)
                    vol = int(info.last_volume) if info.last_volume else 0
                    
                    # 3. Construct Payload (Matches main.py structure)
                    payload = {
                        "symbol": symbol,
                        "price": p_vnd,
                        "change_percent": 0.0, # Placeholder
                        "volume": vol,
                        "timestamp": datetime.now().isoformat()
                    }
                    json_str = json.dumps(payload)
                    
                    # 4. Update Key & Publish
                    r.set(f"stock:{symbol}", json_str)
                    r.publish("stock_updates", json_str) # For WS
                    
                    # Also update simple price key for redundancy
                    r.set(f"price:{symbol}", p_vnd)

                    print(f"      ✅ Set stock:{symbol} = {p_vnd:,} VND")
            except Exception as e:
                print(f"      ❌ Error {symbol}: {e}")
                
        print("\n✨ Force Stock Update Complete.")
        
    except Exception as e:
        print(f"Global Error: {e}")

if __name__ == "__main__":
    force_update_stock_keys()
