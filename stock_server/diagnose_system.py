import requests
import redis
import re
import os

SERVER_URL = "http://localhost:8000"
MAIN_PY_PATH = "main.py"

def check_server_api():
    print(f"--- 1. Checking Running Server API ({SERVER_URL}) ---")
    try:
        url = f"{SERVER_URL}/api/orderbook/HPG"
        print(f"   -> GET {url}")
        resp = requests.get(url, timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            bids = len(data.get("bids", []))
            asks = len(data.get("asks", []))
            print(f"   Server Responded: {bids} Bids, {asks} Asks")
            if bids > 0:
                print(f"   WARNING: Server returned data! (Expected Empty if New Redis)")
                print(f"   Sample Bid: {data['bids'][0]}")
            else:
                print(f"   Server returned EMPTY Orderbook (Correct for New Redis)")
        else:
            print(f"   Server Error: {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"   Could not connect to Server: {e}")
        print("      (Is it running? Port 8000?)")

def check_file_config():
    print(f"\n--- 2. Checking main.py Configuration ---")
    try:
        with open(MAIN_PY_PATH, "r", encoding="utf-8") as f:
            content = f.read()
            
        match = re.search(r'REDIS_URL\s*=\s*"(.*?)"', content)
        if match:
            url = match.group(1)
            masked_url = url.split('@')[-1] if '@' in url else "Invalid Format"
            print(f"   Found REDIS_URL in file: ...@{masked_url}")
            return url
        else:
            print(f"   Could not find REDIS_URL in main.py")
            return None
    except Exception as e:
        print(f"   Error reading file: {e}")
        return None

def check_redis_directly(url):
    print(f"\n--- 3. Checking Redis Directly ---")
    if not url: return
    try:
        r = redis.from_url(url, decode_responses=True)
        info = r.ping()
        print(f"   Connected to Redis: {info}")
        
        keys = r.keys("order:*")
        print(f"   Found {len(keys)} Orders in Redis.")
        pending = r.smembers("pending_orders")
        print(f"   Found {len(pending)} Pending Orders.")
        
    except Exception as e:
        print(f"   Redis Connection Failed: {e}")

if __name__ == "__main__":
    check_server_api()
    url = check_file_config()
    check_redis_directly(url)
