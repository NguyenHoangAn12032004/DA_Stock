import sys
sys.stdout.reconfigure(encoding='utf-8')

import redis
import json
import time
import random
from firebase_admin import credentials, firestore, initialize_app, _apps

# Config
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
CRED_PATH = "stock_server/serviceAccountKey.json"

def init_services():
    # Redis
    r = redis.from_url(REDIS_URL, decode_responses=True)
    
    # Firebase
    if not _apps:
        cred = credentials.Certificate(CRED_PATH)
        initialize_app(cred)
    db = firestore.client()
    
    return r, db

def seed_leaderboard(r, db):
    print("🏆 Seeding Leaderboard...")
    
    # Mock Users
    mock_users = [
        {"id": "user_pro_1", "name": "Nguyễn Văn A", "equity": 500_000_000},
        {"id": "user_pro_2", "name": "Trần Thị B", "equity": 250_000_000},
        {"id": "user_pro_3", "name": "Le Van C", "equity": 150_000_000},
        {"id": "user_whale", "name": "Shark Tank", "equity": 2_000_000_000},
        {"id": "user_newbie", "name": "F0 Chứng Khoán", "equity": 50_000_000},
    ]

    pipe = r.pipeline()
    batch = db.batch()
    
    for u in mock_users:
        # Update Redis Leaderboard
        pipe.zadd("leaderboard:equity", {u['id']: u['equity']})
        
        # Ensure User Exists in Firestore (for name lookup)
        ref = db.collection("users").document(u['id'])
        batch.set(ref, {"fullName": u['name'], "balance": u['equity'], "email": f"{u['id']}@example.com"}, merge=True)
    
    pipe.execute()
    batch.commit()
    print("✅ Leaderboard Seeded with 5 users.")

def seed_feed(r):
    print("📰 Seeding Social Feed...")
    
    symbols = ["HPG", "VCB", "FPT", "MWG", "TCB"]
    actions = ["mua", "bán"]
    names = ["Nguyễn Văn A", "Trần Thị B", "Shark Tank", "Le Van C"]
    
    trades = []
    current_time = time.time()
    
    for i in range(10):
        t = {
            "user_id": f"user_pro_{random.randint(1,3)}",
            "user_name": random.choice(names),
            "symbol": random.choice(symbols),
            "action": random.choice(actions),
            "price": random.randint(20, 100) * 1000,
            "quantity": random.randint(100, 5000),
            "timestamp": current_time - (i * 300), # 5 mins apart
            "type": "trade"
        }
        trades.append(t)
        
    # Push to Redis List
    # Clear old first?
    r.delete("recent_trades")
    
    pipe = r.pipeline()
    for t in trades:
        pipe.rpush("recent_trades", json.dumps(t)) # rpush to keep order if fetching lrange(0, -1)
    
    pipe.execute()
    print("✅ Social Feed Seeded with 10 trades.")

if __name__ == "__main__":
    try:
        r, db = init_services()
        seed_leaderboard(r, db)
        seed_feed(r)
        print("\n🎉 Social Data Seeding Complete!")
    except Exception as e:
        print(f"❌ Error: {e}")
