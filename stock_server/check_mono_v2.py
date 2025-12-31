from PIL import Image

def check_mono():
    path = r"d:\DA_Stock\stock_app\assets\icons_final\android_monochrome.png"
    try:
        img = Image.open(path)
        print(f"Format: {img.format}")
        print(f"Mode: {img.mode}")
        print(f"Size: {img.size}")
        
        # Check center pixel and corner pixel
        w, h = img.size
        center = img.getpixel((w//2, h//2))
        corner = img.getpixel((0, 0))
        
        print(f"Center pixel: {center}")
        print(f"Corner pixel: {corner}")
        
        # Check standard deviation of alpha to see if it's a solid block
        if img.mode == 'RGBA':
            alphas = [p[3] for p in img.getdata()]
            unique_alphas = set(alphas)
            print(f"Unique Alpha values (first 10): {list(unique_alphas)[:10]}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_mono()
