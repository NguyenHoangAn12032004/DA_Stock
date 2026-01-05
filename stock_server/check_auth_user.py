import firebase_admin
from firebase_admin import credentials, auth
import os

# Setup Credentials
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(BASE_DIR, "serviceAccountKey.json")

try:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

print(f"Listing users for Project: {cred.project_id}")

try:
    page = auth.list_users()
    print(f"Total Users Found: {len(page.users)}")
    for user in page.users:
        print(f" - {user.email} (UID: {user.uid})")
        if "hoangan" in user.email:
             print(f"   ^^^ MATCH FOUND! Exact email: '{user.email}'")

except Exception as e:
    print(f"[ERROR] {e}")
