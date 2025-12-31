from PIL import Image

def clean_splash_stripes():
    # Use the splash icon we created/copied
    src_path = r"d:\DA_Stock\stock_app\assets\splash_icon.png"
    
    try:
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        new_data = []
        for item in datas:
            r, g, b, a = item
            
            # Logic: We only want the GREEN BULL.
            # Grid is usually grayish or white.
            # Green Bull has G > R and G > B significantly.
            
            # Simple Green Filter
            is_greenish = (g > r + 10) and (g > b + 10)
            
            # Also keep very dark pixels if they are part of the bull's shadow/details?
            # Actually the bull is bright green/gradient.
            # The grid is usually R=G=B (gray/white).
            
            # Check for gray (Grid)
            # If R, G, B are similar (low variance), it's likely grayscale (grid/white/black).
            variance = max(r, g, b) - min(r, g, b)
            
            if variance < 20: 
                # It's grayscale (white, gray, black) -> Transparent
                new_data.append((0, 0, 0, 0))
            else:
                # It has color -> Keep it
                new_data.append(item)
        
        cleaned_img = Image.new("RGBA", img.size)
        cleaned_img.putdata(new_data)
        cleaned_img.save(src_path)
        print(f"Removed stripes from {src_path}")
        
    except Exception as e:
        print(f"Error cleaning splash stripes: {e}")

if __name__ == "__main__":
    clean_splash_stripes()
