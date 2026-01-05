import firebase_admin
from firebase_admin import credentials, firestore
import sys

# FIX UNICODE ERROR ON WINDOWS
sys.stdout.reconfigure(encoding='utf-8')

# --- CONFIG ---
SERVICE_ACCOUNT_KEY = "serviceAccountKey.json"

# --- DATA ---
COURSES = [
    {
        "id": "beginner",
        "title": "Stock Market Basics",
        "level": "Beginner",
        "description": "Learn the fundamental concepts of the stock market, how it works, and how to start investing.",
        "order": 1,
        "lessons": [
            {
                "id": "intro_stock",
                "title": "What is a Stock?",
                "duration": "5:30",
                "video_url": "https://www.youtube.com/watch?v=p7HKvqRI_Bo",
                "thumbnail": "https://img.youtube.com/vi/p7HKvqRI_Bo/0.jpg",
                "order": 1
            },
            {
                "id": "how_market_works",
                "title": "How the Stock Market Works",
                "duration": "8:15",
                "video_url": "https://www.youtube.com/watch?v=ZCFkWDdmXG8",
                "thumbnail": "https://img.youtube.com/vi/ZCFkWDdmXG8/0.jpg",
                "order": 2
            },
            {
                "id": "bull_bear",
                "title": "Bull vs Bear Markets",
                "duration": "4:20",
                "video_url": "https://www.youtube.com/watch?v=1z6aUSX-bPw",
                "thumbnail": "https://img.youtube.com/vi/1z6aUSX-bPw/0.jpg",
                "order": 3
            }
        ]
    },
    {
        "id": "intermediate",
        "title": "Technical Analysis 101",
        "level": "Intermediate",
        "description": "Master reading charts, understanding trends, and using indicators like RSI and MACD.",
        "order": 2,
        "lessons": [
            {
                "id": "candlestick",
                "title": "Reading Candlestick Charts",
                "duration": "12:00",
                "video_url": "https://www.youtube.com/watch?v=C327l6yq_wM",
                "thumbnail": "https://img.youtube.com/vi/C327l6yq_wM/0.jpg",
                "order": 1
            },
            {
                "id": "support_resistance",
                "title": "Support and Resistance",
                "duration": "10:45",
                "video_url": "https://www.youtube.com/watch?v=4pP9c8R6v8g",
                "thumbnail": "https://img.youtube.com/vi/4pP9c8R6v8g/0.jpg",
                "order": 2
            }
        ]
    },
    {
        "id": "advanced",
        "title": "Advanced Trading Strategies",
        "level": "Advanced",
        "description": "Learn about options, futures, and algorithmic trading strategies for experienced investors.",
        "order": 3,
        "lessons": [
            {
                "id": "options_intro",
                "title": "Introduction to Options",
                "duration": "15:20",
                "video_url": "https://www.youtube.com/watch?v=7PM4rNDr4oI",
                "thumbnail": "https://img.youtube.com/vi/7PM4rNDr4oI/0.jpg",
                "order": 1
            }
        ]
    }
]

# --- INIT FIREBASE ---
try:
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Initialized")
except Exception as e:
    print(f"❌ Firebase Init Error: {e}")
    exit(1)

def seed_courses():
    print("🚀 Seeding Courses...")
    batch = db.batch()
    
    for course in COURSES:
        doc_ref = db.collection("courses").document(course["id"])
        batch.set(doc_ref, course)
        print(f"   -> Prepared: {course['title']}")
        
    try:
        batch.commit()
        print("✅ All courses seeded successfully!")
    except Exception as e:
        print(f"❌ Error committing batch: {e}")

if __name__ == "__main__":
    seed_courses()
