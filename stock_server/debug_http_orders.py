
import requests
import json
import sys

try:
    print("Requesting /api/debug/dump_orders...")
    r = requests.get("http://localhost:8000/api/debug/dump_orders", timeout=10)
    print(f"Status: {r.status_code}")
    if r.status_code == 200:
        data = r.json()
        orders = data.get("orders", {})
        print(f"Total Orders: {len(orders)}")
        print(f"{'ID':<38} | {'Sym':<5} | {'Stat':<10} | {'Prc':<8} | {'Qty':<5} | {'Side':<5}")
        for oid, info in orders.items():
            if info.get("symbol") == "HPG":
                print(f"{oid.replace('order:', ''):<38} | {info.get('symbol'):<5} | {info.get('status'):<10} | {info.get('price'):<8} | {info.get('quantity'):<5} | {info.get('side'):<5}")

    else:
        print(r.text)
except Exception as e:
    print(f"Error: {e}")
