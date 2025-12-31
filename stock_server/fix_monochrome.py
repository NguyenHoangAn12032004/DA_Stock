from PIL import Image
import math

def fix_monochrome():
    # Source: Use the foreground we (supposedly) made correctly.
    # actually let's re-process the original to be safe.
    src_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
    out_path = r"d:\DA_Stock\stock_app\assets\icons_bull\android_monochrome.png"
    
    try:
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        # Create a strictly binary mask
        # If pixel is NOT white (background), make it SOLID WHITE (Foreground).
        # If pixel IS white (background), make it TRANSPARENT.
        
        new_data = []
        for item in datas:
            r, g, b, a = item
            # Distance from white
            dist = math.sqrt((255-r)**2 + (255-g)**2 + (255-b)**2)
            
            # Threshold: Increased to 100 to catch any light shadows/edges of the white background
            if dist < 100: 
                # Background -> Transparent
                new_data.append((255, 255, 255, 0))
            else:
                # Foreground -> Solid White
                new_data.append((255, 255, 255, 255))
        
        # Create new image
        mono_img = Image.new("RGBA", img.size)
        mono_img.putdata(new_data)
        
        # Optional: Add a small border or just save as is. 
        # The bull itself is the icon.
        mono_img.save(out_path)
        print(f"Saved {out_path}")
        
    except Exception as e:
        print(f"Error fixing monochrome: {e}")

if __name__ == "__main__":
    fix_monochrome()
