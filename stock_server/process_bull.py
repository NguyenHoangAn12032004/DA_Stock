from PIL import Image, ImageDraw
import math

def process_bull_icons():
    # Paths
    # Original Green Bull
    src_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
    out_dir = r"d:\DA_Stock\stock_app\assets\icons_bull"
    
    try:
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        # 1. Remove White Background (Simple Color Keying)
        # Anything close to white becomes transparent
        new_data = []
        for item in datas:
            # item is (R, G, B, A)
            # Distance from white
            r, g, b, a = item
            # Euclid distance from (255,255,255)
            dist = math.sqrt((255-r)**2 + (255-g)**2 + (255-b)**2)
            
            # Threshold
            if dist < 50: # Close to white
                new_data.append((255, 255, 255, 0)) # Transparent
            else:
                new_data.append(item)
        
        img.putdata(new_data)
        
        # Trim transparent space (optional, but good)
        # img = img.crop(img.getbbox())
        # Actually better to keep original canvas size to avoid scaling issues, just extracted.
        
        # Save Foreground (Bull on Transparent)
        fg_path = f"{out_dir}\\android_foreground.png"
        img.save(fg_path)
        print(f"Saved {fg_path}")
        
        # 2. Base Icon (Black Background)
        # Create Black BG
        bg_img = Image.new("RGBA", img.size, (0, 0, 0, 255))
        # Paste Bull (Masked by alpha)
        bg_img.alpha_composite(img)
        
        base_path = f"{out_dir}\\base_app_icon.png"
        bg_img.save(base_path)
        print(f"Saved {base_path}")
        
        # 3. Monochrome (White Silhouette)
        # Take the alpha channel of the foreground
        r, g, b, a = img.split()
        # Create a new white image with that alpha
        mono_img = Image.merge("RGBA", (Image.new("L", img.size, 255), Image.new("L", img.size, 255), Image.new("L", img.size, 255), a))
        
        mono_path = f"{out_dir}\\android_monochrome.png"
        mono_img.save(mono_path)
        print(f"Saved {mono_path}")
        
    except Exception as e:
        print(f"Error processing icons: {e}")

if __name__ == "__main__":
    process_bull_icons()
