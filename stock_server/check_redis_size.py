import redis
import os

try:
    # Hardcoded URL from main.py for debugging
    REDIS_URL = "rediss://default:AaQJAAIncDFlODg1ZGVlMTRiYWY0YTZkYjhkY2E0Mjc1YzRmZGExYXAxNDE5OTM@peaceful-parrot-41993.upstash.io:6379"
    r = redis.from_url(REDIS_URL, decode_responses=True)
    
    count = r.scard("pending_orders")
    print(f"Pending Orders Count: {count}")
    
    # Check if there are keys that shouldn't be there
    # print(f"Random Key: {r.randomkey()}")
    
except Exception as e:
    print(f"Error: {e}")
