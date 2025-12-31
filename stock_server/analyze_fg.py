from PIL import Image

def analyze_fg():
    path = r"d:\DA_Stock\android_foreground.png"
    try:
        img = Image.open(path).convert("RGBA")
        print(f"Mode: {img.mode}, Size: {img.size}")
        
        # Check corner pixel to see if it's black
        corner = img.getpixel((0, 0))
        print(f"Corner pixel: {corner}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    analyze_fg()
