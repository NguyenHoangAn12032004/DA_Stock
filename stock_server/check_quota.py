import firebase_admin
from firebase_admin import credentials, firestore
import os
import time

# Force UTF-8 for Windows Console
import sys
sys.stdout.reconfigure(encoding='utf-8')

def test_firestore_quota():
    print("\n🕵️ TESTING FIRESTORE ADMIN SDK QUOTA...\n")
    
    try:
        # Load Creds
        cred_path = "serviceAccountKey.json"
        if not os.path.exists(cred_path):
             print("[ERROR] serviceAccountKey.json missing!")
             return

        # Init (if not already)
        if not firebase_admin._apps:
             cred = credentials.Certificate(cred_path)
             firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        # Try to read 1 document
        print("   -> Attempting to read 'system/config'...")
        start = time.time()
        doc = db.collection('system').document('config').get()
        latency = (time.time() - start) * 1000
        
        if doc.exists:
            print(f"   ✅ SUCCESS! Admin SDK is ALIVE.")
            print(f"   ⏱️ Latency: {latency:.2f}ms")
            print("   👉 Conclusion: Backend API SHOULD work even if Client App is blocked!")
        else:
            print(f"   ✅ SUCCESS! Read completed (Doc not found), but Quota seems OK.")
            
    except Exception as e:
        print(f"   ❌ FAILED! Quota Exceeded or Error.")
        print(f"   Error details: {e}")
        print("   👉 Conclusion: You MUST create a new Firebase Project instantly.")

if __name__ == "__main__":
    test_firestore_quota()
