import asyncio
import redis
import json
import sys
# Fix Windows Unicode Output
sys.stdout.reconfigure(encoding='utf-8')

from firebase_admin import firestore, credentials, initialize_app

# 1. Init Redis
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
r = redis.from_url(REDIS_URL, decode_responses=True)

# 2. Init Firestore
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    initialize_app(cred)
except ValueError:
    pass # Already init
db = firestore.client()

def identify_users():
    print("--- 🏆 Leaderboard Diagnosis ---")
    
    # Get Top 5 from Redis
    top_users = r.zrevrange("leaderboard:equity", 0, 4, withscores=True)
    
    print(f"Found {len(top_users)} users in Redis Leaderboard:")
    
    for uid, equity in top_users:
        print(f"\nUID: {uid}")
        print(f"Equity: {equity:,.0f}")
        
        # Check Firestore
        doc = db.collection("users").document(uid).get()
        if doc.exists:
            data = doc.to_dict()
            name = data.get("fullName", data.get("name", "Unknown"))
            email = data.get("email", "No Email")
            print(f"Firestore Name: {name}")
            print(f"Firestore Email: {email}")
        else:
            print(f"❌ Firestore: Document Not Found! REMOVING Ghost User {uid}...")
            r.zrem("leaderboard:equity", uid)
            r.zrem("leaderboard:roi", uid) # Just in case
            print("✅ Removed from Leaderboard.")

if __name__ == "__main__":
    identify_users()
