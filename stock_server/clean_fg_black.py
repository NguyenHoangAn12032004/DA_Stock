from PIL import Image
import math

def clean_fg_black():
    src_path = r"d:\DA_Stock\android_foreground.png"
    out_path = r"d:\DA_Stock\stock_app\assets\splash_icon.png"
    
    try:
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        new_data = []
        for item in datas:
            r, g, b, a = item
            # Check distance from Black
            dist = math.sqrt(r**2 + g**2 + b**2)
            
            # Threshold for black removal
            if dist < 50: 
                new_data.append((0, 0, 0, 0)) # Make Transparent
            else:
                new_data.append(item) # Keep original color
        
        cleaned_img = Image.new("RGBA", img.size)
        cleaned_img.putdata(new_data)
        cleaned_img.save(out_path)
        print(f"Saved cleaned splash icon to {out_path}")
        
    except Exception as e:
        print(f"Error cleaning fg: {e}")

if __name__ == "__main__":
    clean_fg_black()
