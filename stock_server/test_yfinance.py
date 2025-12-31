import yfinance as yf
import pandas as pd

try:
    print("Testing AAPL history...")
    ticker = yf.Ticker("AAPL")
    history = ticker.history(period="1mo")
    print(f"History empty? {history.empty}")
    if not history.empty:
        print(history.head())

    print("\nTesting AAPL info...")
    info = ticker.info
    print(f"Info keys: {list(info.keys())[:5]}")
    print(f"Symbol in info: {'symbol' in info}")
    print(f"LongName in info: {'longName' in info}")

except Exception as e:
    print(f"Error: {e}")
