from PIL import Image

def clean_mono_aggressive():
    # Use the file explicitly mentioned by user if possible, or the asset
    # The user mapped d:\DA_Stock\android_monochrome.png
    src_path = r"d:\DA_Stock\android_monochrome.png"
    out_path = r"d:\DA_Stock\stock_app\assets\icons_final\android_monochrome.png"
    
    try:
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        new_data = []
        for item in datas:
            r, g, b, a = item
            # Aggressive white check
            # Only keep pixels that are clearly white/bright
            if r > 150 and g > 150 and b > 150:
                new_data.append((255, 255, 255, 255))
            else:
                new_data.append((0, 0, 0, 0))
        
        cleaned_img = Image.new("RGBA", img.size)
        cleaned_img.putdata(new_data)
        cleaned_img.save(out_path)
        print(f"Aggressively cleaned mono icon saved to {out_path}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    clean_mono_aggressive()
