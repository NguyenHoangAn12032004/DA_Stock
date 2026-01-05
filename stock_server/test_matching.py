import sys
sys.stdout.reconfigure(encoding='utf-8')
import requests
import time
import uuid
import json

BASE_URL = "http://localhost:8000"
SYMBOL = "TEST_MATCH"

def print_step(msg):
    print(f"\n[STEP] {msg}")

def dump_orders():
    try:
        r = requests.get(f"{BASE_URL}/api/debug/dump_orders")
        return r.json()
    except Exception as e:
        print(f"Error dumping orders: {e}")
        return {}

def place_order(user_id, side, price, qty, order_type="limit"):
    payload = {
        "user_id": user_id,
        "symbol": SYMBOL,
        "side": side,
        "price": price,
        "quantity": qty,
        "order_type": order_type
    }
    try:
        r = requests.post(f"{BASE_URL}/api/orders", json=payload)
        if r.status_code == 200:
            print(f"✅ Placed {side} Order: {qty} @ {price} (User: {user_id})")
            return r.json()
        else:
            print(f"❌ Failed to place order: {r.text}")
            return None
    except Exception as e:
        print(f"❌ Exception placing order: {e}")
        return None

def main():
    print(f"🚀 Starting Matching Test on {BASE_URL}...")
    
    # 1. Check Server Health
    try:
        requests.get(f"{BASE_URL}/docs")
        print("✅ Server is reachable.")
    except:
        print("❌ Server is NOT running on port 8001. Please restart 'python main.py'.")
        return

    buyer_id = f"user_buyer_{uuid.uuid4().hex[:4]}"
    seller_id = f"user_seller_{uuid.uuid4().hex[:4]}"
    
    # 2. Place SELL Order (Maker)
    print_step("Placing SELL Order (Maker)")
    sell_price = 100.0
    qty = 10
    place_order(seller_id, "sell", sell_price, qty)
    
    # 3. Verify Order Book / Pending
    time.sleep(1)
    data = dump_orders()
    pending = data.get("pending_ids", [])
    print(f"ℹ️ Pending Orders Count: {len(pending)}")
    
    # 4. Place BUY Order (Taker) - Matches the Sell
    print_step("Placing BUY Order (Taker) - Should Match")
    place_order(buyer_id, "buy", sell_price, qty)
    
    # 5. Wait for Matching
    time.sleep(2)
    
    # 6. Verify Results
    print_step("Verifying Results")
    data_final = dump_orders()
    
    # Check if orders are removed from pending or marked matched
    # We need to find our orders in the dump
    
    orders = data_final.get("orders", {})
    matched_count = 0
    
    for oid, odata in orders.items():
        # Clean up redis hash return format (bytes/strings)
        s = odata.get("symbol")
        if s == SYMBOL:
            status = odata.get("status")
            side = odata.get("side")
            print(f"   -> Order {oid[:8]} [{side}]: {status}")
            if status == "matched":
                matched_count += 1
                
    if matched_count >= 2:
        print("\n✅✅ SUCCESS: Both orders matched successfully!")
    else:
        print("\n❌❌ FAILURE: Orders did not match properly.")

if __name__ == "__main__":
    main()
