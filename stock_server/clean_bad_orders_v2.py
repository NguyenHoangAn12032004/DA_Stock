import sys
sys.stdout.reconfigure(encoding='utf-8')
import firebase_admin
from firebase_admin import credentials, firestore, initialize_app, _apps
import os
import redis

# Config
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

# Init Firebase
if _apps:
    for app_name in list(_apps.keys()):
        firebase_admin.delete_app(_apps[app_name])

current_dir = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(current_dir, "serviceAccountKey.json")

if not os.path.exists(cred_path):
    cred_path = "serviceAccountKey.json"

cred = credentials.Certificate(cred_path)
initialize_app(cred)
db = firestore.client()
r = redis.from_url(REDIS_URL, decode_responses=True)

def clean_bad_orders_v2():
    print("🧹 Scanning for Low Price Bug Orders (e.g. 221 VND)...")
    
    # Target Users
    target_users = ["EiIwapmdUjVBg0lnUg6qGV5RUxa2", "hKgZPoD9HVaNYEtRs9LFCXC3IJp2", "N3bP2q37NxcMQ31i6sE5g9tjYHu2"]
    
    for uid in target_users:
        print(f"\nScanning User: {uid}")
        
        # Redis Orders
        u_orders_key = f"user_orders:{uid}"
        order_ids = r.lrange(u_orders_key, 0, -1)
        print(f"   found {len(order_ids)} orders in Redis.")
        
        bad_ids = []
        for oid in order_ids:
            data = r.hgetall(f"order:{oid}")
            if not data: continue
            
            try:
                symbol = data.get('symbol', 'UNKNOWN')
                price = float(data.get('price', 0))
                
                # Logic: If AAPL/GOOG/BTC and price < 1,000,000 => BAD (USD treated as VND)
                # If HPG/VCB and price < 5000 => SUSPICIOUS (but maybe possible?)
                
                is_foreign = len(symbol) > 3 or "-" in symbol # Simple heuristic matches CurrencyHelper
                
                is_bad = False
                if is_foreign and price < 100_000: # Clearly wrong. AAPL is ~4M VND.
                    is_bad = True
                    print(f"   ⚠️ FOREIGN LOW PRICE: {oid} | {symbol} | Price: {price:,.0f} VND")
                    
                if not is_foreign and price < 1000:
                    is_bad = True
                    print(f"   ⚠️ DOMESTIC LOW PRICE: {oid} | {symbol} | Price: {price:,.0f} VND")
                
                if is_bad:
                     bad_ids.append(oid)
            except: pass
            
        if bad_ids:
            print(f"   🗑️ Deleting {len(bad_ids)} bad orders from Redis...")
            pipe = r.pipeline()
            for oid in bad_ids:
                pipe.lrem(u_orders_key, 0, oid)
                pipe.delete(f"order:{oid}")
            pipe.execute()
            print("   ✅ Redis Cleaned.")
            
    print("\n✨ Done.")

if __name__ == "__main__":
    try:
         clean_bad_orders_v2()
    except Exception as e:
        print(f"❌ Error: {e}")
