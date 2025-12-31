
import firebase_admin
from firebase_admin import credentials, firestore
import os

db = None

def init_firebase():
    global db
    try:
        # Check for service account key
        cred_path = "serviceAccountKey.json"
        
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            db = firestore.client()
            print("✅ Firebase Admin SDK initialized successfully!")
        else:
            print("⚠️ WARNING: serviceAccountKey.json not found!")
            print("   -> Database features (Balance Deduction) will NOT work.")
            print("   -> Please place 'serviceAccountKey.json' in the 'stock_server' folder.")
            db = None
            
    except Exception as e:
        print(f"❌ Error initializing Firebase: {e}")
        db = None

def get_db():
    return db
