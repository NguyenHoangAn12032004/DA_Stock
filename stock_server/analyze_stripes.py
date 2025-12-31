from PIL import Image

def analyze_stripes():
    path = r"d:\DA_Stock\android_monochrome.png"
    try:
        img = Image.open(path).convert("RGBA")
        print(f"Mode: {img.mode}, Size: {img.size}")
        
        # Check a 20x20 grid of pixels at 0,0
        pixels = []
        for y in range(20):
            row = []
            for x in range(20):
                row.append(img.getpixel((x, y)))
            pixels.append(row)
        
        print("First 5x5 pixels:")
        for y in range(5):
            print(f"Row {y}: {pixels[y][:5]}")
            
        # Check distinct colors in the whole image
        # This might be slow for large images, so just check a sample
        # Or just check if there are grayish pixels
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    analyze_stripes()
