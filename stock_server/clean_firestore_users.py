import sys
sys.stdout.reconfigure(encoding='utf-8')
import firebase_admin
from firebase_admin import credentials, firestore, initialize_app, _apps
import os

# Ensure clean start
if _apps:
    for app_name in list(_apps.keys()):
        firebase_admin.delete_app(_apps[app_name])

def clean_database():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    cred_path = os.path.join(current_dir, "serviceAccountKey.json")
    
    # Fallback to CWD
    if not os.path.exists(cred_path):
        cred_path = "serviceAccountKey.json"
        
    print(f"🔑 Using credential: {os.path.basename(cred_path)}")
    
    cred = credentials.Certificate(cred_path)
    initialize_app(cred)
    db = firestore.client()
    
    # 1. Print Project ID
    # Indirectly via cred or just assume from success
    try:
        project_id = cred.project_id
        print(f"🆔 Connected to Project ID: {project_id}")
    except:
        print("🆔 Connected (Project ID unknown via SDK)")

    print("\n🔍 Scanning Users...")
    users = db.collection("users").stream()
    
    real_users = []
    trash_users = []
    
    for u in users:
        uid = u.id
        data = u.to_dict()
        name = data.get("fullName", "No Name")
        
        # Identification Logic:
        # Real users likely have 20-char IDs or don't start with "test_" / "user_"
        if uid.startswith("test_") or uid.startswith("user_") or name == "Unknown":
            trash_users.append(uid)
        else:
            real_users.append(f"{uid} ({name})")
            
    print(f"📊 Found {len(real_users) + len(trash_users)} total users.")
    print(f"   ✅ Real Users ({len(real_users)}): {real_users}")
    print(f"   🗑️ Trash Users ({len(trash_users)}): {len(trash_users)} detected.")
    
    # 2. Delete Trash
    if trash_users:
        print("\n🧹 Deleting Trash Users from Firestore...")
        batch = db.batch()
        count = 0
        deleted = 0
        
        for uid in trash_users:
            ref = db.collection("users").document(uid)
            batch.delete(ref)
            count += 1
            if count == 400: # Batch limit safe
                batch.commit()
                deleted += count
                print(f"   ...deleted {deleted} users")
                batch = db.batch()
                count = 0
        
        if count > 0:
            batch.commit()
            print(f"   ...deleted remaining {count} users")
            
        print("✨ Cleanup Complete.")
        
    else:
        print("✨ No trash users found.")

if __name__ == "__main__":
    try:
        clean_database()
    except Exception as e:
        print(f"❌ Error: {e}")
