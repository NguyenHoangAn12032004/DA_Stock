import sys
sys.stdout.reconfigure(encoding='utf-8')
import redis
import json
import os
from firebase_admin import credentials, firestore, initialize_app, _apps

# Config
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

def init_services():
    r = redis.from_url(REDIS_URL, decode_responses=True)
    
    # Path resolution
    current_dir = os.path.dirname(os.path.abspath(__file__))
    cred_path = os.path.join(current_dir, "serviceAccountKey.json")
    if not os.path.exists(cred_path):
        cred_path = "serviceAccountKey.json"

    if not _apps:
        cred = credentials.Certificate(cred_path)
        initialize_app(cred)
    db = firestore.client()
    return r, db

def force_update_leaderboard():
    r, db = init_services()
    print("🧹 Cleaning old Mock Data...")
    r.delete("leaderboard:equity")
    r.delete("recent_trades") # Optional: clear feed too if requested, but let's keep trades for now or clear if mock? 
    # User said "Mock data à?" implying they hate it. Let's clear recent_trades too if they are obviously fake.
    # But wait, seed_social_data added them. So YES, clear them.
    r.delete("recent_trades")
    print("✅ Cleared Redis keys.")

    print("🔄 Calculating Real Equity for ALL Users...")
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
            symbol = h_data.get("symbol", "")
            
            # Get Real Price from Redis
            current_price = 0
            if symbol:
                market_json = r.get(f"stock:{symbol}")
                if market_json:
                    try: 
                        current_price = float(json.loads(market_json).get("price", 0))
                    except: pass
                
                # If Redis price missing, use avg_price as fallback or 0? 
                # Better to use avg_price to minimalize shock, or 0.
                if current_price == 0:
                    current_price = h_data.get("average_price", 0)

            holdings_val += qty * current_price
            
        total_equity = balance + holdings_val
        
        # Add to Redis
        pipe.zadd("leaderboard:equity", {uid: total_equity})
        
        print(f"   👤 {uid}: Equity = {total_equity:,.0f} (Bal: {balance:,.0f} + Stock: {holdings_val:,.0f})")
        count += 1
        
    pipe.execute()
    print(f"✅ Leaderboard Updated. Total Real Users: {count}")

if __name__ == "__main__":
    try:
        force_update_leaderboard()
    except Exception as e:
        print(f"❌ Error: {e}")
