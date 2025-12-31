from PIL import Image
import math

def fix_user_mono():
    path = r"d:\DA_Stock\stock_app\assets\icons_final\android_monochrome.png"
    
    try:
        img = Image.open(path).convert("RGBA")
        datas = img.getdata()
        
        new_data = []
        for item in datas:
            r, g, b, a = item
            # Distance from Black (0,0,0)
            dist_black = math.sqrt(r**2 + g**2 + b**2)
            
            # If it's close to black, make it transparent
            # If it's NOT black (e.g. the bull), make it SOLID WHITE
            
            if dist_black < 50: 
                # Background -> Transparent
                new_data.append((0, 0, 0, 0))
            else:
                # Foreground -> Solid White
                new_data.append((255, 255, 255, 255))
        
        img.putdata(new_data)
        img.save(path)
        print(f"Fixed monochrome icon at {path}")
        
    except Exception as e:
        print(f"Error fixing mono: {e}")

if __name__ == "__main__":
    fix_user_mono()
