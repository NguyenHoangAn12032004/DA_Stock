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

def clean_bad_orders():
    print("🧹 Scanning for Anomalous Orders (Price Bug)...")
    
    # Threshold: Orders > 100 Billion VND are suspicious for this MVP
    # Or check AAPL quantity vs Price.
    # Actually, simpler: just wipe ALL orders for the affected user if needed, or filter.
    # Let's verify by just listing them first.
    
    # Users from previous step
    target_users = ["EiIwapmdUjVBg0lnUg6qGV5RUxa2", "hKgZPoD9HVaNYEtRs9LFCXC3IJp2"] # Admin & Another
    
    for uid in target_users:
        print(f"\nScanning User: {uid}")
        
        # Redis Orders
        u_orders_key = f"user_orders:{uid}"
        order_ids = r.lrange(u_orders_key, 0, -1)
        print(f"   found {len(order_ids)} orders in Redis.")
        
        bad_ids = []
        for oid in order_ids:
            # Check price/value in Redis
            data = r.hgetall(f"order:{oid}")
            if not data: continue
            
            try:
                symbol = data.get('symbol', 'UNKNOWN')
                price = float(data.get('price', 0))
                qty = float(data.get('quantity', 0))
                total = price * qty
                
                # Check for "Trillion" bug. 3667006115360 d
                if total > 100_000_000_000: # 100 Billion
                     print(f"   ⚠️ BAD ORDER DETECTED: {oid} | {symbol} | Total: {total:,.0f} VND")
                     bad_ids.append(oid)
            except: pass
            
        # Delete Bad Orders
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
         clean_bad_orders()
    except Exception as e:
        print(f"❌ Error: {e}")
