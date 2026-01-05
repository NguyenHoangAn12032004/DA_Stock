import sys
# Set encoding for Windows console
sys.stdout.reconfigure(encoding='utf-8')

import time
import redis
import firebase_admin
from firebase_admin import credentials, firestore
import yfinance as yf
from vnstock import Vnstock
import os

print("\n🔍 STARTING SYSTEM HEALTH CHECK...\n")

# 1. CHECK REDIS
print("--- [1] REDIS CONNECTION ---")
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"
try:
    r = redis.from_url(REDIS_URL, decode_responses=True, socket_timeout=5)
    r.ping()
    print("[PASS] ✅ Redis Connected successfully!")
    print(f"       Ping Response: {r.ping()}")
except Exception as e:
    print(f"[FAIL] ❌ Redis Connection Failed: {e}")

# 2. CHECK FIREBASE
print("\n--- [2] FIREBASE CONNECTION ---")
try:
    cred_path = "serviceAccountKey.json"
    if not os.path.exists(cred_path):
        print("[FAIL] ❌ serviceAccountKey.json not found!")
    else:
        # Check if app already initialized
        if not firebase_admin._apps:
             cred = credentials.Certificate(cred_path)
             firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        # Simple read
        docs = db.collection('users').limit(1).get()
        print(f"[PASS] ✅ Firebase Connected successfully!")
        print(f"       Read {len(docs)} user docs (Test Read).")
except Exception as e:
    print(f"[FAIL] ❌ Firebase Connection Failed: {e}")

# 3. CHECK VNSTOCK (Vietnam Stocks)
print("\n--- [3] VNSTOCK API (Vietnam) ---")
try:
    stock = Vnstock().stock(symbol="HPG", source='VCI')
    data = stock.quote.intraday(page_size=1)
    if data is not None and not data.empty:
        price = data.iloc[0].get('price', 0)
        print(f"[PASS] ✅ Vnstock Connected! HPG Price: {price}")
    else:
        print("[WARN] ⚠️ Vnstock connected but returned empty data.")
except Exception as e:
    print(f"[FAIL] ❌ Vnstock Failed: {e}")

# 4. CHECK YFINANCE (US/Crypto)
print("\n--- [4] YFINANCE API (US/Crypto) ---")
try:
    ticker = yf.Ticker("AAPL") 
    info = ticker.fast_info
    price = info.last_price
    print(f"[PASS] ✅ YFinance Connected! AAPL Price: ${price:.2f}")
except Exception as e:
    print(f"[FAIL] ❌ YFinance Failed: {e}")

print("\n🏁 HEALTH CHECK COMPLETE.\n")
