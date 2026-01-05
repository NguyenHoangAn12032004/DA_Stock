import redis
import sys
sys.stdout.reconfigure(encoding='utf-8')

REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

def list_aapl_orders():
    print("🔍 Listing AAPL/GOOG Pending Orders...")
    r = redis.from_url(REDIS_URL, decode_responses=True)
    
    pending_ids = list(r.smembers("pending_orders"))
    print(f"Total Pending IDs: {len(pending_ids)}")
    
    for oid in pending_ids:
        data = r.hgetall(f"order:{oid}")
        if not data:
            print(f"   [GHOST] {oid}")
            continue
            
        symbol = data.get('symbol', 'UNKNOWN')
        price = data.get('price', '0')
        qty = data.get('quantity', '0')
        side = data.get('side', '?')
        
        if symbol in ["AAPL", "GOOG", "TSLA"]:
            print(f"   👉 {symbol} | {side} | P: {price} | Q: {qty} | ID: {oid}")

if __name__ == "__main__":
    list_aapl_orders()
