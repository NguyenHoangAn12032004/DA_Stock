import redis
import sys

# Replace with the URL you just updated in main.py
REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

print(f"Testing connection to: {REDIS_URL.split('@')[1]}")

try:
    r = redis.from_url(REDIS_URL, decode_responses=True)
    response = r.ping()
    print(f"Connection Successful! Redis replied: {response}")
    
    # Check permissions
    r.set("test_key", "hello")
    val = r.get("test_key")
    print(f"Read/Write Check: wrote 'hello', got '{val}'")
    
except Exception as e:
    print(f"Connection Failed: {e}")
    sys.exit(1)
