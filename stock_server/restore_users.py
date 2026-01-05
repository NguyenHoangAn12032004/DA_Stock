import asyncio
import redis
import json
import sys
import time
sys.stdout.reconfigure(encoding='utf-8')

from firebase_admin import firestore, credentials, initialize_app, auth

# 1. Init
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
r = redis.from_url(REDIS_URL, decode_responses=True)

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    initialize_app(cred)
except ValueError:
    pass 
db = firestore.client()

TARGETS = [
    {"email": "thaochi14032004@gmail.com", "name": "Thảo Chi", "uid": None},
    {"email": "hoangan1111112234@gmail.com", "name": "Hoàng An", "uid": None}
]

def restore_users():
    print("--- ♻️ Restoring Users ---")
    
    for t in TARGETS:
        email = t["email"]
        name = t["name"]
        print(f"\nProcessing {email}...")
        
        # 1. Find by Email in Auth
        uid = None
        try:
            user = auth.get_user_by_email(email)
            uid = user.uid
            print(f"   -> Found Existing Auth UID: {uid}")
        except auth.UserNotFoundError:
            print("   -> User not in Auth. Creating...")
            user = auth.create_user(email=email, password="123456", display_name=name)
            uid = user.uid
            print(f"   -> Created New Auth UID: {uid}")
            
        # 2. Check Firestore
        doc_ref = db.collection("users").document(uid)
        doc = doc_ref.get()
        
        balance = 100_000_000
        
        if not doc.exists:
            print("   -> Firestore Doc missing. Creating...")
            doc_ref.set({
                "id": uid,
                "email": email,
                "fullName": name,
                "balance": balance,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "fcm_token": "" 
            })
            # Seed Holdings?
            # Grant 100 HPG
            doc_ref.collection("holdings").document("HPG").set({
                "symbol": "HPG",
                "quantity": 100,
                "average_price": 26000
            })
            print("   -> Seeded 100M VND + 100 HPG")
        else:
            print("   -> Firestore Doc exists.")
            data = doc.to_dict()
            balance = data.get("balance", 0)
            
        # 3. Update Redis Leaderboard
        # Estimate Equity = Balance + (100 HPG * 26000) roughly
        # For precise, we'd need real prices, but let's approximate:
        equity = balance + (100 * 26000) 
        
        r.zadd("leaderboard:equity", {uid: equity})
        # Mock ROI
        r.zadd("leaderboard:roi", {uid: 15.5}) # Give them some green
        
        print(f"   ✅ Added to Leaderboard: {equity:,.0f} VND")

if __name__ == "__main__":
    restore_users()
