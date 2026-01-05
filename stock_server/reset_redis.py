import redis
import sys
import re

# Read RediS URL from main.py to be sure
def get_redis_url():
    try:
        with open("main.py", "r", encoding="utf-8") as f:
            content = f.read()
        match = re.search(r'REDIS_URL\s*=\s*"(.*?)"', content)
        if match: return match.group(1)
    except: pass
    return None

url = get_redis_url()
if not url:
    print("❌ Could not find REDIS_URL in main.py")
    sys.exit(1)

print(f"Connecting to Redis: ...@{url.split('@')[-1]}")
r = redis.from_url(url, decode_responses=True)

try:
    print("WARNING: This will DELETE ALL DATA in the Redis database (Orders, Orderbooks).")
    confirm = input("Type 'yes' to confirm: ")
    if confirm.lower() != "yes":
        print("Cancelled.")
        sys.exit(0)

    r.flushdb()
    print("FLUSHDB Executed. Database is Empty.")
    
    # Verify
    keys = r.keys("*")
    print(f"Current Keys: {len(keys)}")
    
except Exception as e:
    print(f"Error: {e}")
