import pandas_datareader.data as web
from datetime import datetime

start = datetime(2023, 1, 1)
end = datetime(2023, 1, 10)

symbols_to_test = ['BTC-USD', 'BTC.V', 'BTCUSD', 'XBTUSD', 'AAPL.US', 'AAPL']

print("Testing Stooq symbols...")
for sym in symbols_to_test:
    try:
        df = web.DataReader(sym, 'stooq', start=start, end=end)
        if df is not None and not df.empty:
            print(f"[SUCCESS] {sym}: Got {len(df)} rows.")
            print(df.head(1))
        else:
            print(f"[FAILED] {sym}: Empty.")
    except Exception as e:
        print(f"[ERROR] {sym}: {e}")
