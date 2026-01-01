import firebase_admin
from firebase_admin import credentials, firestore, auth
import sys
import os

# FIX UNICODE ERROR ON WINDOWS
sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase (Ensure serviceAccountKey.json is in the same folder)
base_path = os.path.dirname(os.path.abspath(__file__))
key_path = os.path.join(base_path, "serviceAccountKey.json")

cred = credentials.Certificate(key_path)
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

def set_admin_role(email):
    try:
        # 1. Find User by Email
        user = auth.get_user_by_email(email)
        uid = user.uid
        print(f"🔍 Found User: {email} (UID: {uid})")
        
        # 2. Update Firestore
        user_ref = db.collection("users").document(uid)
        
        if not user_ref.get().exists:
            print("❌ User document does not exist in Firestore. Please register/login in App first.")
            return

        user_ref.update({"role": "admin"})
        print(f"✅ Successfully promoted {email} to ADMIN role.")
        print("📲 Please LOGOUT and LOGIN again in the App to see the Admin Dashboard.")
        
    except firebase_admin.auth.UserNotFoundError:
        print(f"❌ User with email {email} not found in Firebase Auth.")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_email = sys.argv[1]
        set_admin_role(target_email)
    else:
        print("Usage: python set_admin.py <email>")
        # Default for quick test
        email_input = input("Enter email to promote to Admin: ")
        set_admin_role(email_input)
