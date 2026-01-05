import firebase_admin
from firebase_admin import credentials, auth, firestore
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

email_target = "thaochi14032004@gmail.com"
uid_target = "hKgZPoD9HVaNYEtRs9LFCXC3IJp2"

print(f"DTO Deletion Script for: {email_target} ({uid_target})")

# 1. Delete from Auth
try:
    auth.delete_user(uid_target)
    print(f"[SUCCESS] Deleted user from Firebase Auth: {uid_target}")
except auth.UserNotFoundError:
    print(f"[INFO] User not found in Auth (already deleted?)")
except Exception as e:
    print(f"[ERROR] Auth deletion failed: {e}")

# 2. Delete from Firestore
try:
    doc_ref = db.collection("users").document(uid_target)
    doc = doc_ref.get()
    if doc.exists:
        doc_ref.delete()
        print(f"[SUCCESS] Deleted user from Firestore: {uid_target}")
    else:
        print(f"[INFO] User document not found in Firestore")
except Exception as e:
    print(f"[ERROR] Firestore deletion failed: {e}")

print("Done.")
