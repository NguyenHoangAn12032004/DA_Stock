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

emails = ["hoangan1111112234@gmail.com", "thaochi14032004@gmail.com"]

print("Checking existence of new accounts...")
for email in emails:
    try:
        user = auth.get_user_by_email(email)
        print(f"[FOUND] {email} -> UID: {user.uid}")
    except auth.UserNotFoundError:
        print(f"[MISSING] {email} - User has not re-registered yet.")
