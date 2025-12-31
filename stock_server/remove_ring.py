from PIL import Image
import math

def remove_ring():
    # Source: Original Green Bull
    src_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
    out_dir = r"d:\DA_Stock\stock_app\assets\icons_final"
    
    try:
        # Load and clean background (keep Bull only)
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        cleaned_data = []
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((255-r)**2 + (255-g)**2 + (255-b)**2)
            if dist < 80: # Remove white background
                cleaned_data.append((0, 0, 0, 0))
            else:
                cleaned_data.append(item)
                
        bull_img = Image.new("RGBA", img.size)
        bull_img.putdata(cleaned_data)
        
        # --- 1. Foreground (Bull ONLY) ---
        # No Ring. No Resize (use full size available, let Android scale it)
        # Actually, let's ensure it's centered and has slight padding but maximizing size.
        # The original image was good fit.
        fg_path = f"{out_dir}\\android_foreground.png"
        bull_img.save(fg_path)
        print(f"Saved {fg_path} (Bull Only)")
        
        # --- 2. Base Icon (Black BG + Bull) ---
        base_img = Image.new("RGBA", img.size, (0, 0, 0, 255))
        base_img.alpha_composite(bull_img)
        
        base_path = f"{out_dir}\\base_app_icon.png"
        base_img.save(base_path)
        print(f"Saved {base_path} (Black BG + Bull)")
        
        # Do NOT touch monochrome.
        
    except Exception as e:
        print(f"Error removing ring: {e}")

if __name__ == "__main__":
    remove_ring()
