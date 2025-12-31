import sys
import os

# Set encoding to UTF-8 for Windows console
sys.stdout.reconfigure(encoding='utf-8')

from vnstock import Vnstock
from datetime import datetime, timedelta

def test_fetch(symbol):
    print(f"\n--- TESTING {symbol} ---")
    try:
        # Test Hybrid Strategy
        print("Testing Hybrid Strategy: Intraday (Price) + History (Ref)")
        stock = Vnstock().stock(symbol=symbol, source='VCI')
        
        # 1. Get Realtime Price
        df_now = stock.quote.intraday(page_size=1)
        current_price = 0.0
        if df_now is not None and not df_now.empty:
            current_price = float(df_now.iloc[0]['price'])
            print(f"Current Price (Intraday): {current_price}")
        
        # 2. Get Previous Close
        today = datetime.now().strftime("%Y-%m-%d")
        start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        df_hist = stock.quote.history(start=start_date, end=today, interval='1D')
        
        prev_close = 0.0
        if df_hist is not None and not df_hist.empty:
            records = df_hist.to_dict('records')
            # If the last record has today's date, we want the one BEFORE it.
            # Convert 'time' column to string to compare if needed, or just look at -2
            # timestamp is usually '2025-12-31 00:00:00'
            
            last_rec = records[-1]
            last_date = str(last_rec['time'])[:10] # '2025-12-31'
            
            if last_date == today:
                if len(records) >= 2:
                    prev_close = float(records[-2]['close'])
                    print(f"Using 2nd to last record for prev close: {records[-2]['time']} - {prev_close}")
                else:
                    print("Not enough history for prev close")
            else:
                # Last record is NOT today (maybe yesterday), so it IS the prev close
                prev_close = float(last_rec['close'])
                print(f"Using last record for prev close: {last_rec['time']} - {prev_close}")
                
        # 3. Calc
        if current_price > 0 and prev_close > 0:
            change = ((current_price - prev_close) / prev_close) * 100
            print(f"Calculated Change %: {change:.2f}%")
        else:
            print("Cannot calc change")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    for s in ["HPG", "VCB", "FPT"]:
        test_fetch(s)
