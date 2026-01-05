import redis
import sys
sys.stdout.reconfigure(encoding='utf-8')

REDIS_URL = "rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379"

def clean_pending_orders():
    print("🧹 Cleaning Global Pending Orders...")
    r = redis.from_url(REDIS_URL, decode_responses=True)
    
    # 1. Get All Pending IDs
    pending_ids = list(r.smembers("pending_orders"))
    print(f"   Found {len(pending_ids)} total pending orders.")
    
    if not pending_ids:
        print("   Nothing to clean.")
        return

    # 2. Scan and Identify Bad Orders
    bad_count = 0
    pipe = r.pipeline()
    
    for oid in pending_ids:
        data = r.hgetall(f"order:{oid}")
        if not data:
            # Ghost ID in set but no data? Remove it.
            pipe.srem("pending_orders", oid)
            # print(f"   👻 Found Ghost ID: {oid}")
            continue
            
        try:
            symbol = data.get('symbol', 'UNKNOWN')
            price = float(data.get('price', 0))
            
            is_foreign = len(symbol) > 3 or "-" in symbol
            is_bad = False
            
            # Criteria: Foreign Stock < 100,000 VND is definitely wrong (e.g. 271 VND)
            if is_foreign and price < 100_000:
                is_bad = True
                print(f"   ⚠️ BAD ORDER: {symbol} @ {price} (ID: {oid})")
            
            if is_bad:
                bad_count += 1
                pipe.srem("pending_orders", oid)
                pipe.delete(f"order:{oid}")
                # Also try to remove from user_orders if we knew the user_id, 
                # but main priority is fixing the OrderBook display.
                
        except Exception as e:
            print(f"Error checking {oid}: {e}")
            
    if bad_count > 0:
        print(f"   🗑️ Deleting {bad_count} bad orders...")
        pipe.execute()
        print("   ✅ Cleanup Complete.")
    else:
        print("   ✅ No bad orders found in Pending Set.")

if __name__ == "__main__":
    clean_pending_orders()
