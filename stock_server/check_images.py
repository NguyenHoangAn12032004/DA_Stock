import sys
try:
    from PIL import Image, ImageOps, ImageDraw
    print("Pillow is installed")
except ImportError:
    print("Pillow is NOT installed")
    sys.exit(1)

import os

img0_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
img1_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_1_1766459281308.png"

def check_image(path):
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return
    try:
        img = Image.open(path)
        print(f"Image: {os.path.basename(path)}")
        print(f"  Format: {img.format}")
        print(f"  Mode: {img.mode}")
        print(f"  Size: {img.size}")
        # Check if it has transparency
        if img.mode == 'RGBA':
            extrema = img.getextrema()
            if extrema[3][0] < 255:
                print("  Has transparency")
            else:
                print("  No transparent pixels found")
        else:
             print("  No alpha channel")
    except Exception as e:
        print(f"  Error reading image: {e}")

check_image(img0_path)
check_image(img1_path)
