from PIL import Image

def analyze_pixels(path, label):
    try:
        img = Image.open(path).convert('RGBA')
        width, height = img.size
        # Sample corners
        corners = [
            img.getpixel((0, 0)),
            img.getpixel((width-1, 0)),
            img.getpixel((0, height-1)),
            img.getpixel((width-1, height-1))
        ]
        print(f"--- {label} ---")
        print(f"Size: {width}x{height}")
        print(f"Corners: {corners}")
        
        # Sample center
        center = img.getpixel((width//2, height//2))
        print(f"Center: {center}")
        
    except Exception as e:
        print(f"Error analyzing {label}: {e}")

img0_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
img1_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_1_1766459281308.png"

analyze_pixels(img0_path, "Green Bull (Img 0)")
analyze_pixels(img1_path, "White Bull (Img 1)")
