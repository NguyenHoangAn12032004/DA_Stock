import sys
sys.stdout.reconfigure(encoding='utf-8')
import time
import uuid
import requests
import firebase_admin
from firebase_admin import firestore
from firebase_config import init_firebase, get_db

# Init Firebase
init_firebase()
db = get_db()

BASE_URL = "http://localhost:8000"
SYMBOL = "TEST_MATCH"

def setup_users():
    if not db:
        print("❌ Database not connected. Cannot seed.")
        sys.exit(1)

    buyer_id = f"test_buyer_{uuid.uuid4().hex[:4]}"
    seller_id = f"test_seller_{uuid.uuid4().hex[:4]}"
    
    print(f"🛠️ Seeding data for Buyer: {buyer_id} & Seller: {seller_id}")
    
    # 1. Setup Buyer (Needs Money)
    db.collection("users").document(buyer_id).set({
        "balance": 1000000.0, # 1 Million
        "email": "buyer@test.com"
    })
    
    # 2. Setup Seller (Needs Stocks)
    # Ensure they have enough money for fees too just in case? No, Seller pays fee from revenue.
    db.collection("users").document(seller_id).set({
        "balance": 0.0,
        "email": "seller@test.com"
    })
    db.collection("users").document(seller_id).collection("holdings").document(SYMBOL).set({
        "symbol": SYMBOL,
        "quantity": 1000
    })
    
    print("✅ Seed complete.")
    return buyer_id, seller_id

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
            print(f"✅ Placed {side} Order: {qty} @ {price}")
            return r.json()
        else:
            print(f"❌ Failed to place order: {r.text}")
            return None
    except Exception as e:
        print(f"❌ Exception placing order: {e}")
        return None

def wait_for_server():
    print("⏳ Waiting for Server 8000 to be ready...")
    for i in range(10):
        try:
            r = requests.get(f"{BASE_URL}/docs")
            if r.status_code == 200:
                print("✅ Server is Ready!")
                return True
        except:
            time.sleep(1)
            print(f"   ...retry {i+1}")
    return False

def main():
    if not wait_for_server():
        print("❌ Server failed to start.")
        return

    # RESET SERVER STATE (Redis + Engine)
    try:
        print("🧹 Resetting Server State...")
        requests.post(f"{BASE_URL}/api/debug/reset")
    except Exception as e:
        print(f"⚠️ Failed to reset server: {e}")

    print(f"🚀 Starting Seeded Matching Test...")
    
    buyer_id, seller_id = setup_users()
    
    # 2. Place SELL Order (Maker)
    print("\n[STEP] Placing SELL Order (Maker)")
    sell_price = 100.0
    qty = 10
    place_order(seller_id, "sell", sell_price, qty)
    
    time.sleep(1)
    
    # 3. Place BUY Order (Taker)
    print("\n[STEP] Placing BUY Order (Taker) - Should Match")
    place_order(buyer_id, "buy", sell_price, qty)
    
    # 4. Wait
    time.sleep(2)
    
    # 5. Verify Results
    print("\n[STEP] Verifying Results")
    data_final = dump_orders()
    
    orders = data_final.get("orders", {})
    matched_count = 0
    
    for oid, odata in orders.items():
        s = odata.get("symbol")
        user = odata.get("user_id")
        if s == SYMBOL and user in [buyer_id, seller_id]:
            status = odata.get("status")
            side = odata.get("side")
            print(f"   -> Order {oid[:8]} [{side}] ({user}): {status}")
            if status == "matched":
                matched_count += 1
                
    if matched_count >= 2:
        print("\n✅✅ SUCCESS: Both orders matched successfully!")
        
        # Optional: Verify Firestore balances updated?
        b_doc = db.collection("users").document(buyer_id).get()
        s_doc = db.collection("users").document(seller_id).get()
        
        print(f"   Buyer Balance: {b_doc.get('balance')} (Should be close to 1M - cost)")
        print(f"   Seller Balance: {s_doc.get('balance')} (Should be > 0)")
        
    else:
        print("\n❌❌ FAILURE: Orders did not match properly.")

if __name__ == "__main__":
    main()
