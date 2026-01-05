
import firebase_admin
from firebase_admin import credentials, firestore
import os

# Setup Firebase - Use Absolute Path or Relative to Current Directory
if not firebase_admin._apps:
    try:
        # Try relative path first
        cred_path = "serviceAccountKey.json"
        if not os.path.exists(cred_path):
             # Fallback to absolute path if running from elsewhere (though CWD should be set)
             cred_path = r"d:\DA_Stock\stock_server\serviceAccountKey.json"
        
        print(f"Using credential: {cred_path}")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error loading creds: {e}")
        exit(1)

db = firestore.client()

def check_user_data():
    users_ref = db.collection('users')
    docs = users_ref.stream()
    
    print(f"{'User ID':<30} | {'Name':<20} | {'Balance (VND)':<20}")
    print("-" * 80)
    
    target_user_id = None
    
    for doc in docs:
        data = doc.to_dict()
        uid = doc.id
        name = data.get('fullName', 'Unknown')
        balance = data.get('balance', 0)
        
        print(f"{uid:<30} | {name[:20]:<20} | {balance:,.0f}")
        
        # Heuristic to find the current user
        if balance > 1000000: 
             target_user_id = uid

    print(f"\nScanning Orders for ALL Users...")
    print(f"{'User':<10} | {'ID':<10} | {'Side':<10} | {'Symbol':<5} | {'Qty':<5} | {'Price':<15} | {'Status':<10}")
    
    all_orders = db.collection('orders').stream()
    for o in all_orders:
        d = o.to_dict()
        user_short = d.get('user_id', '')[:10]
        print(f"{user_short:<10} | {o.id[:10]:<10} | {str(d.get('side')):<10} | {d.get('symbol'):<5} | {d.get('quantity'):<5} | {d.get('price'):<15} | {d.get('status'):<10}")

if __name__ == "__main__":
    check_user_data()
