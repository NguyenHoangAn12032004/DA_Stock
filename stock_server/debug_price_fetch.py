import yfinance as yf
import sys
sys.stdout.reconfigure(encoding='utf-8')

USD_VND_RATE = 25450.0

def test_fetch(symbol):
    print(f"Testing fetch for {symbol}...")
    try:
        ticker = yf.Ticker(symbol)
        # Force fast info
        info = ticker.fast_info
        
        last_price = info.last_price
        currency = info.currency
        
        print(f"   Raw Price: {last_price}")
        print(f"   Currency: {currency}")
        
        final_price = last_price
        if currency == 'USD':
            print("   USD Detected. Converting...")
            final_price = last_price * USD_VND_RATE
            print(f"   Converted: {final_price}")
        else:
            print("   No Conversion.")
            
        print(f"   Final Result: {round(final_price)}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_fetch("AAPL")
    test_fetch("HPG")
