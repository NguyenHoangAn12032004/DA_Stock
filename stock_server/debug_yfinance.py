
import sys
import yfinance as yf
import requests

# FIX UNICODE ERROR ON WINDOWS
sys.stdout.reconfigure(encoding='utf-8')

def get_requests_session():
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "text/html,application/json,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5"
    })
    return session

def test_fetch(symbol):
    print(f"\n--- TESTING {symbol} ---")
    try:
        ticker = yf.Ticker(symbol, session=get_requests_session())
        info = ticker.fast_info
        print(f"Last Price: {info.last_price}")
        print(f"Prev Close: {info.previous_close}")
        
        p = info.last_price
        prev_close = info.previous_close
        
        if prev_close and prev_close > 0:
            change = ((p - prev_close) / prev_close) * 100
            print(f"Calculated Change %: {change:.2f}%")
        else:
            print("Prev Close is 0/None")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_fetch("AAPL")
    test_fetch("BTC-USD")
