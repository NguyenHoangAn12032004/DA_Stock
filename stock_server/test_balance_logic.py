import asyncio
from firebase_admin import firestore, initialize_app, credentials

# Mock Firestore Data
mock_user_balance = 74000000 # 74M
order_price = 80000000 # 80M
quantity = 1 # or 20 shares @ 4M each

def check_logic():
    print(f"--- DEBUGGING BALANCE CHECK ---")
    print(f"User Balance: {mock_user_balance:,.0f}")
    
    # 1. Simulate LIMIT Order
    qty = 1
    price = order_price
    print(f"\n[CASE 1] Limit Order: 1 share @ {price:,.0f}")
    
    total_val = price * qty
    fee = total_val * 0.0015
    deduction = total_val + fee
    print(f"   Required: {deduction:,.2f}")
    
    if mock_user_balance < deduction:
        print("   [PASS] Check PASSED: Insufficient funds detected.")
    else:
        print("   [FAIL] Check FAILED: System would allow this trade!")

    # 2. Simulate LOGIC ERROR with Types
    print(f"\n[CASE 2] Type Sensitivity Test")
    bal_float = float(mock_user_balance)
    print(f"   Balance (float): {bal_float}")
    if bal_float < deduction:
        print("   [PASS] Float Comparison OK.")
    else:
        print("   [FAIL] Float Comparison ERROR.")

    # 3. Simulate MARKET Order with Low Estimate
    print(f"\n[CASE 3] Market Order Vulnerability")
    estimated_price = 1000 # User places order when price is momentarily low? or Bug
    est_deduction = (estimated_price * qty) * 1.0015
    print(f"   Estimated Cost: {est_deduction:,.2f}")
    
    if mock_user_balance < est_deduction:
        print("   [PASS] Blocked.")
    else:
        print("   !!! [WARN] ALLOWED! Deduction will be small, but execution might be high.")

if __name__ == "__main__":
    check_logic()
