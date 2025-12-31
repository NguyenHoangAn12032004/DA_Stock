from PIL import Image, ImageDraw

def create_forge_v2_icons():
    # Dimensions
    size = 1024
    
    # Colors
    bg_color = (0, 0, 0, 255)       # Solid Black
    neon_green = (0, 230, 118, 255) # #00E676 Vibrant Green
    white_color = (255, 255, 255, 255)
    
    # Create directory if not exists (handled by cmd previously)
    base_path = r"d:\DA_Stock\stock_app\assets\icons_v2"
    
    # Helper to draw the icon shape
    def draw_forge_stock(draw_obj, color, size, draw_border=True):
        center_x = size // 2
        center_y = size // 2
        
        # 1. Circular Border
        # Adaptive icons safe zone is roughly 66% of the image (diameter ~720px for 1080px)
        # We need to stay safely inside. Let's use 700px diameter circle.
        radius = 380 
        if draw_border:
            border_bbox = [center_x - radius, center_y - radius, center_x + radius, center_y + radius]
            draw_obj.ellipse(border_bbox, outline=color, width=40)
        
        # 2. Anvil
        # Centered roughly
        anvil_y_base = center_y + 150
        
        # Base
        base_w = 250
        base_h = 40
        draw_obj.rectangle(
            [center_x - base_w//2, anvil_y_base - base_h, center_x + base_w//2, anvil_y_base], 
            fill=color
        )
        
        # Neck
        neck_w = 400
        neck_h = 150 # Height of the main block
        head_bottom_y = anvil_y_base - base_h - 20 # Gap for neck visual (or just connect)
        # Actually let's just draw a sold block for "simple" anvil
        
        # Main Block (Anvil Head)
        block_w = 400
        block_h = 100
        block_y_start = head_bottom_y - block_h
        
        # Neck trapezoid connecting base and block
        draw_obj.polygon([
            (center_x - base_w//4, anvil_y_base - base_h),
            (center_x + base_w//4, anvil_y_base - base_h),
            (center_x + block_w//4, block_y_start + block_h),
            (center_x - block_w//4, block_y_start + block_h)
        ], fill=color)

        # Head Block
        draw_obj.rectangle(
            [center_x - block_w//2 + 50, block_y_start, center_x + block_w//2 + 50, block_y_start + block_h],
            fill=color
        )
        
        # Horn (Left side triangle)
        draw_obj.polygon([
            (center_x - block_w//2 + 50, block_y_start),
            (center_x - block_w//2 + 50, block_y_start + block_h),
            (center_x - block_w//2 - 100, block_y_start + 10) # Pointy
        ], fill=color)

        # 3. Stock Arrow (Rising from Anvil Center)
        # Zig Zag
        start_pt = (center_x - 100, block_y_start) 
        pt2 = (center_x, block_y_start - 100)
        pt3 = (center_x + 50, block_y_start - 30)
        pt4 = (center_x + 200, block_y_start - 200)
        
        draw_obj.line([start_pt, pt2, pt3, pt4], fill=color, width=35)
        
        # Arrow Head
        # Simple triangle at pt4
        arrow_size = 40
        draw_obj.polygon([
            (pt4[0] - arrow_size, pt4[1] + arrow_size), # Left
            (pt4[0] + arrow_size, pt4[1] - arrow_size), # Right (approx)
            (pt4[0] + arrow_size//2, pt4[1] - arrow_size*2) # Tip
        ], fill=color)
        
        # Correct arrow head to be more "arrow-y"
        # Let's just draw a polygon pointing UR
        draw_obj.polygon([
            (pt4[0] - 20, pt4[1]),
            (pt4[0], pt4[1] + 20),
            (pt4[0] + 50, pt4[1] - 50)
        ], fill=color)

    # --- 1. Base App Icon (Full Color) ---
    img_base = Image.new("RGBA", (size, size), bg_color)
    draw_base = ImageDraw.Draw(img_base)
    draw_forge_stock(draw_base, neon_green, size, draw_border=True)
    img_base.save(f"{base_path}\\base_app_icon.png")
    print("Saved base_app_icon.png")

    # --- 2. Foreground (Transparent BG) ---
    img_fg = Image.new("RGBA", (size, size), (0,0,0,0))
    draw_fg = ImageDraw.Draw(img_fg)
    draw_forge_stock(draw_fg, neon_green, size, draw_border=True)
    img_fg.save(f"{base_path}\\android_foreground.png")
    print("Saved android_foreground.png")

    # --- 3. Monochrome (Stencil - White on Transparent, No Border usually? User asked for 2 themed variants)
    # "01 ảnh: Màn hình Home (Themed icons ON) hiển thị icon đơn sắc đúng."
    # Monochrome icons usually do NOT have the container border, just the logo.
    # But if the user wants the border to be part of the logo, we can include it.
    # Let's include the border for consistency, but maybe thinner? Or same.
    # Let's keep it same shape, just WHITE.
    
    img_mono = Image.new("RGBA", (size, size), (0,0,0,0))
    draw_mono = ImageDraw.Draw(img_mono)
    draw_forge_stock(draw_mono, white_color, size, draw_border=True) # Keeping border
    img_mono.save(f"{base_path}\\android_monochrome.png")
    print("Saved android_monochrome.png")

if __name__ == "__main__":
    create_forge_v2_icons()
