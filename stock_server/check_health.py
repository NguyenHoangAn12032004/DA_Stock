import requests
import time

try:
    # Check Health (or Main Page)
    res = requests.get("http://127.0.0.1:8000/docs", timeout=5)
    print(f"Health Check: {res.status_code}")
    
    # Check OrderBook endpoint (Safe check)
    res = requests.get("http://127.0.0.1:8000/api/orderbook/HPG", timeout=5)
    print(f"OrderBook Check: {res.status_code}")
    print(res.json())
except Exception as e:
    print(f"Error: {e}")
