
import redis
import sys

# Connect to Redis
try:
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    r.ping()
    print("Connected to Redis")
except Exception as e:
    print(f"Redis Connection Error: {e}")
    sys.exit(1)

def scan_user_orders():
    # Helper to print order details
    def print_order(oid):
        data = r.hgetall(f"order:{oid}")
        if data:
            print(f" -> Order {oid}: Status='{data.get('status')}', Side='{data.get('side')}', Sym='{data.get('symbol')}', Qty={data.get('quantity')}")
        else:
            print(f" -> Order {oid}: NOT FOUND in Redis (orphaned in user list?)")

    # Get all keys matching user_orders:*
    keys = r.keys("user_orders:*")
    print(f"Found {len(keys)} user lists.")
    
    for k in keys:
        uid = k.split(":")[1]
        orders = r.lrange(k, 0, -1)
        print(f"User {uid} has {len(orders)} orders:")
        for oid in orders:
            print_order(oid)

    print("\n--- Pending Orders Set ---")
    pending = r.smembers("pending_orders")
    print(f"Total Pending: {len(pending)}")
    for oid in pending:
        print_order(oid)

if __name__ == "__main__":
    scan_user_orders()
