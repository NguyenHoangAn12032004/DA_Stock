import firebase_admin
from firebase_admin import credentials, firestore
import time
import sys

# FIX UNICODE ERROR ON WINDOWS
sys.stdout.reconfigure(encoding='utf-8')

# Initialize Firebase (Ensure serviceAccountKey.json is in the same folder)
cred = credentials.Certificate("serviceAccountKey.json")
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

def seed_courses():
    print("🚀 Seeding Learning Center Data...")
    
    courses_ref = db.collection("courses")
    
    # 1. Beginner Module
    beginner_data = {
        "title": "Nhập Môn Chứng Khoán",
        "level": "Beginner",
        "order": 1,
        "description": "Làm quen với các khái niệm cơ bản nhất của thị trường.",
        "lessons": [
            {
                "id": "l1_1",
                "title": "Chứng khoán là gì?",
                "duration": "10:15",
                "video_url": "https://www.youtube.com/watch?v=IPWv_fGkCf0", 
                "thumbnail": "",
                "order": 1
            },
            {
                "id": "l1_2",
                "title": "Cách đọc bảng giá điện tử",
                "duration": "12:30",
                "video_url": "https://www.youtube.com/watch?v=a1rStFvQWJk",
                "thumbnail": "",
                "order": 2
            },
            {
                "id": "l1_3",
                "title": "Cổ phiếu vs Trái phiếu",
                "duration": "8:45",
                "video_url": "https://www.youtube.com/watch?v=F3Q32CqXqaQ",
                "thumbnail": "",
                "order": 3
            }
        ]
    }
    
    # 2. Intermediate Module
    inter_data = {
        "title": "Phân Tích Cơ Bản & Kỹ Thuật",
        "level": "Intermediate",
        "order": 2,
        "description": "Trang bị công cụ để đánh giá và chọn lọc cổ phiếu.",
        "lessons": [
            {
                "id": "l2_1",
                "title": "Chỉ số P/E là gì?",
                "duration": "9:20",
                "video_url": "https://www.youtube.com/watch?v=6P3uT1lK2lM",
                "thumbnail": "",
                "order": 1
            },
            {
                "id": "l2_2",
                "title": "Mô hình Nến Nhật cơ bản",
                "duration": "14:10",
                "video_url": "https://www.youtube.com/watch?v=C35s4Q9d9T0",
                "thumbnail": "",
                "order": 2
            },
            {
                "id": "l2_3",
                "title": "Hỗ trợ & Kháng cự",
                "duration": "11:50",
                "video_url": "https://www.youtube.com/watch?v=JyJd6s7s5vI",
                "thumbnail": "",
                "order": 3
            }
        ]
    }
    
    # 3. Advanced Module
    adv_data = {
        "title": "Chiến Lược Giao Dịch Nâng Cao",
        "level": "Advanced",
        "order": 3,
        "description": "Quản trị rủi ro và các chiến thuật chuyên sâu.",
        "lessons": [
            {
                "id": "l3_1",
                "title": "Quản lý vốn & Rủi ro",
                "duration": "18:00",
                "video_url": "https://www.youtube.com/watch?v=1uWJ6y8Yy5k",
                "thumbnail": "",
                "order": 1
            },
            {
                "id": "l3_2",
                "title": "Tâm lý giao dịch (FOMO)",
                "duration": "15:45",
                "video_url": "https://www.youtube.com/watch?v=0k1vX-1j1jM",
                "thumbnail": "",
                "order": 2
            }
        ]
    }
    
    # Upload to Firestore
    # We use 'level' as ID for simplicity in fetching specific modules
    courses_ref.document("beginner").set(beginner_data)
    courses_ref.document("intermediate").set(inter_data)
    courses_ref.document("advanced").set(adv_data)
    
    print("✅ Successfully seeded 3 Modules with Lessons.")

if __name__ == "__main__":
    seed_courses()
