import asyncio
from unittest.mock import MagicMock, AsyncMock

# Mock Config
TRADING_FEE_RATE = 0.0015

async def test_financials():
    print("--- 1. Testing Buy Order Deduction ---")
    # Inputs
    qty = 600
    price = 27950.0
    expected_val = price * qty
    expected_fee = expected_val * TRADING_FEE_RATE
    total_deduction = expected_val + expected_fee
    
    print(f"Input: Buy {qty} @ {price}")
    print(f"Expected Deduction: {total_deduction:,.2f}")
    
    # Simulate place_order logic
    # total_val = 16,770,000
    # fee = 25,155
    # total = 16,795,155
    
    # If user saw 3,586,770 deducted...
    # Reverse engineer: 
    # 3,586,770 = P * 600 * 1.0015
    # P = 3,586,770 / (600 * 1.0015) = 5,968 VND?
    
    print("--- 2. Testing Sell Order Settlement ---")
    # Inputs: Sell 992 AAPL @ 185.50
    qty_sell = 992
    price_sell = 185.50
    revenue = qty_sell * price_sell
    fee_sell = revenue * TRADING_FEE_RATE
    net_proceeds = revenue - fee_sell
    
    print(f"Input: Sell {qty_sell} @ {price_sell}")
    print(f"Revenue: {revenue:,.2f}")
    print(f"Net Proceeds: {net_proceeds:,.2f}")
    # User saw 184,016.00 which matches nicely (184,016 / 185.50 = 992)
    # 992 * 185.50 = 184,016. 
    # Wait, 184016 * 0.0015 = 276.
    # 184016 - 276 = 183,740.
    
    # Logic check:
    # revenue = price * qty
    # fee = revenue * RATE
    # net = revenue - fee
    
    # Simulation
    mock_db = MagicMock()
    mock_batch = MagicMock()
    mock_db.batch.return_value = mock_batch
    
    # Seller Logic
    seller_id = "TEST_USER"
    symbol = "AAPL"
    
    # Replicates main.py logic
    s_ref = mock_db.collection("users").document(seller_id)
    s_holding = s_ref.collection("holdings").document(symbol)
    
    mock_batch.update(s_holding, {"quantity": -qty_sell}) # Simplified increment
    mock_batch.update(s_ref, {"balance": net_proceeds}) # Simplified increment
    
    mock_batch.commit()
    
    print("Mock Batch Commit called.")
    print("Logic seems 'correct' in code, implying runtime failure.")

if __name__ == "__main__":
    asyncio.run(test_financials())
