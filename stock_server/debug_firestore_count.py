import firebase_admin
from firebase_admin import credentials, firestore
import os

# Setup Credentials
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(BASE_DIR, "serviceAccountKey.json")

try:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

print("--- DEBUGGING FIRESTORE COUNT ---")

# 1. Try Aggregation Count
try:
    print("Attempting Aggregation Count...")
    agg_query = db.collection("users").count()
    results = agg_query.get()
    print(f"Aggregation Result Type: {type(results)}")
    print(f"Aggregation Result Raw: {results}")
    
    val = results[0][0].value
    print(f"Aggregation Value: {val}")
except Exception as e:
    print(f"[ERROR] Aggregation failed: {e}")

# 2. Try Manual Stream Count
try:
    print("\nAttempting Manual Stream Count...")
    docs = list(db.collection("users").stream())
    print(f"Stream Count: {len(docs)}")
    for d in docs:
        print(f" - {d.id} => {d.to_dict().get('email')}")
except Exception as e:
    print(f"[ERROR] Stream failed: {e}")
