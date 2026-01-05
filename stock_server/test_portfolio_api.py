import requests
import time

BASE_URL = "http://localhost:8000"
USER_ID = "test_user_id" # Replace with a valid ID if needed, or use a mock one

def test_batch_quotes():
    print(f"\n--- Testing Batch Quotes API ---")
    url = f"{BASE_URL}/api/stock/batch_quotes"
    payload = {"symbols": ["HPG", "VCB", "FPT", "BTC-USD"]}
    
    start_time = time.time()
    try:
        response = requests.post(url, json=payload, timeout=5)
        latency = (time.time() - start_time) * 1000
        
        if response.status_code == 200:
            data = response.json().get("data", [])
            print(f"[SUCCESS] Latency: {latency:.2f}ms")
            print(f"Received {len(data)} items:")
            for item in data:
                print(f"   - {item.get('symbol')}: {item.get('price')}")
                
            if latency < 50:
                print("Performance: EXCELLENT (Likely Cached)")
            elif latency < 200:
                print("Performance: GOOD")
            else:
                print("Performance: SLOW (Check Redis?)")
        else:
            print(f"[FAILED] {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[ERROR] Connection Error: {e}")

def test_portfolio_endpoint():
    print(f"\n--- Testing Portfolio API ---")
    url = f"{BASE_URL}/api/portfolio/{USER_ID}"
    
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"[SUCCESS] Portfolio Data:")
            print(f"   Balance: {data.get('balance'):,.0f}")
            print(f"   Holdings: {len(data.get('holdings', []))} items")
        else:
            print(f"[FAILED] {response.status_code} - {response.text}")
    except Exception as e:
         print(f"[ERROR] Connection Error: {e}")

def check_server_health():
    print(f"\n--- Checking Server Health (Root '/') ---")
    try:
        start = time.time()
        response = requests.get(BASE_URL + "/", timeout=2) # Short timeout
        latency = (time.time() - start) * 1000
        
        if response.status_code == 200:
            print(f"[SUCCESS] Server is UP! Latency: {latency:.2f}ms")
            print(f"Response: {response.json()}")
            return True
        else:
            print(f"[FAILED] Status: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"[CRITICAL] Server Unreachable: {e}")
        return False

if __name__ == "__main__":
    print("[TEST] Starting Diagnosing Tests...")
    if check_server_health():
        test_batch_quotes()
        test_portfolio_endpoint()
    else:
        print("\n[ABORT] Server is dead or hanging at root. Please Restart.")
