import firebase_admin
from firebase_admin import credentials, firestore, auth
import requests
import random
import time
import sys

# FIX UNICODE ERROR ON WINDOWS
sys.stdout.reconfigure(encoding='utf-8')

# --- CONFIG ---
SERVICE_ACCOUNT_KEY = "serviceAccountKey.json"
API_URL = "http://localhost:8000"

TARGET_USERS = [
    {"email": "hoangan1111112234@gmail.com", "role": "admin"},
    {"email": "thaochi14032004@gmail.com", "role": "user"}
]

INIT_HOLDINGS = [
    {"symbol": "HPG", "quantity": 1000},
    {"symbol": "AAPL", "quantity": 1000},
    {"symbol": "NVDA", "quantity": 1000}
]

# Market Prices (Approx)
PRICES = {
    "HPG": 28000,
    "AAPL": 220,
    "NVDA": 120
}

# --- INIT FIREBASE ---
try:
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Initialized")
except Exception as e:
    print(f"❌ Firebase Init Error: {e}")
    exit(1)

def get_or_create_user(email):
    try:
        user = auth.get_user_by_email(email)
        print(f"🔹 Found user: {email} ({user.uid})")
        return user.uid
    except auth.UserNotFoundError:
        print(f"🔸 User not found, creating: {email}")
        user = auth.create_user(email=email)
        return user.uid
    except Exception as e:
        print(f"❌ Error getting user {email}: {e}")
        return None

def seed_holdings(uid):
    print(f"   -> Seeding Holdings for {uid}...")
    try:
        # Give Money
        db.collection("users").document(uid).set({
            "balance": 100_000_000_000, # 100 Billion VND Rich!
            "email": "user_email_placeholder" # simplistic
        }, merge=True)

        batch = db.batch()
        for h in INIT_HOLDINGS:
            ref = db.collection("users").document(uid).collection("holdings").document(h["symbol"])
            batch.set(ref, {
                "symbol": h["symbol"],
                "quantity": h["quantity"],
                "average_price": PRICES[h["symbol"]] * 0.9 # Bought cheaper
            })
        batch.commit()
        print("   ✅ Holdings updated.")
    except Exception as e:
        print(f"   ❌ Error seeding holdings: {e}")

def set_admin_role(uid):
    print(f"   -> Setting Admin Role for {uid}...")
    try:
        auth.set_custom_user_claims(uid, {'admin': True})
        db.collection("users").document(uid).update({"role": "admin"})
        print("   ✅ Admin role set.")
    except Exception as e:
        print(f"   ❌ Error setting admin: {e}")

def place_random_orders(uid):
    print(f"   -> Placing 10 Random Orders for {uid}...")
    for i in range(10):
        symbol = random.choice(["HPG", "AAPL", "NVDA"])
        base_price = PRICES[symbol]
        
        # Randomize Price +/- 5%
        price = base_price * (1 + random.uniform(-0.05, 0.05))
        if symbol == "HPG": price = round(price, -2) # Round to 100 VND
        else: price = round(price, 2)
        
        side = "buy" if i % 2 == 0 else "sell"
        qty = random.randint(10, 100)
        
        payload = {
            "user_id": uid,
            "symbol": symbol,
            "side": side,
            "quantity": qty,
            "price": price,
            "order_type": "limit"
        }
        
        try:
            res = requests.post(f"{API_URL}/api/orders", json=payload)
            if res.status_code == 200:
                print(f"      ✅ Placed {side.upper()} {qty} {symbol} @ {price}")
            else:
                print(f"      ❌ Failed: {res.text}")
        except Exception as e:
            print(f"      ❌ API Error: {e}")
        
        time.sleep(0.1)

def main():
    print("🚀 Starting Data Seed V2...")
    
    for u_data in TARGET_USERS:
        email = u_data["email"]
        role = u_data["role"]
        
        uid = get_or_create_user(email)
        if not uid: continue
        
        seed_holdings(uid)
        
        if role == "admin":
            set_admin_role(uid)
            
        place_random_orders(uid)
        print("------------------------------------------------")

    print("🏁 Seeding Completed.")

if __name__ == "__main__":
    main()
