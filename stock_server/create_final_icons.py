from PIL import Image, ImageDraw, ImageOps
import math

def create_final_icons():
    # Source
    src_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
    out_dir = r"d:\DA_Stock\stock_app\assets\icons_final"
    
    # Colors
    green_color = (0, 230, 118, 255) # Vibrant Green
    
    try:
        # Load and Clean Background
        img = Image.open(src_path).convert("RGBA")
        datas = img.getdata()
        
        cleaned_data = []
        for item in datas:
            r, g, b, a = item
            dist = math.sqrt((255-r)**2 + (255-g)**2 + (255-b)**2)
            if dist < 80: # Remove white/near-white background
                cleaned_data.append((0, 0, 0, 0))
            else:
                cleaned_data.append(item)
        
        bull_img = Image.new("RGBA", img.size)
        bull_img.putdata(cleaned_data)
        
        # Resize bull slightly to fit inside ring
        # Original size ~800. Let's scale to 70%
        w, h = bull_img.size
        scale = 0.65
        new_w, new_h = int(w*scale), int(h*scale)
        bull_small = bull_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create Canvas for Ring/Border
        # Final canvas size same as original
        canvas_size = (w, h)
        cx, cy = w//2, h//2
        
        # --- 1. Foreground (Bull + Green Ring) ---
        fg_img = Image.new("RGBA", canvas_size, (0,0,0,0))
        draw_fg = ImageDraw.Draw(fg_img)
        
        # Draw Ring
        ring_radius = min(w, h)//2 - 20 # 20px padding
        draw_fg.ellipse(
            [cx - ring_radius, cy - ring_radius, cx + ring_radius, cy + ring_radius],
            outline=green_color,
            width=50 # Thick "Support" Ring
        )
        
        # Paste Bull (Centered)
        offset_x = (w - new_w) // 2
        offset_y = (h - new_h) // 2
        fg_img.alpha_composite(bull_small, (offset_x, offset_y))
        
        fg_path = f"{out_dir}\\android_foreground.png"
        fg_img.save(fg_path)
        print(f"Saved {fg_path}")

        # --- 2. Base Icon (Black BG + Foreground) ---
        base_img = Image.new("RGBA", canvas_size, (0, 0, 0, 255))
        base_img.alpha_composite(fg_img)
        
        base_path = f"{out_dir}\\base_app_icon.png"
        base_img.save(base_path)
        print(f"Saved {base_path}")
        
        # --- 3. Monochrome (Solid White Stencil of BULL + RING) ---
        # We want the Ring AND the Bull to be white.
        # Take fg_img alpha channel.
        # Any pixel with alpha > 0 becomes SOLID WHITE (255, 255, 255, 255)
        
        mono_data = []
        fg_datas = fg_img.getdata()
        for item in fg_datas:
            if item[3] > 0: # If not transparent
                mono_data.append((255, 255, 255, 255))
            else:
                mono_data.append((0, 0, 0, 0))
        
        mono_img = Image.new("RGBA", canvas_size)
        mono_img.putdata(mono_data)
        
        mono_path = f"{out_dir}\\android_monochrome.png"
        mono_img.save(mono_path)
        print(f"Saved {mono_path}")
        
    except Exception as e:
        print(f"Error creating final icons: {e}")

if __name__ == "__main__":
    create_final_icons()
