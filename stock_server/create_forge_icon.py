from PIL import Image, ImageDraw

def create_forge_stock_icons():
    # Dimensions
    size = 1024
    bg_color = (30, 30, 30, 255) # Dark Gray #1E1E1E
    fg_color = (255, 255, 255, 255) # White
    
    # 1. Create Base Image (Foreground Shape Only)
    # We will draw on a transparent 1024x1024 canvas
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # --- Draw Anvil ---
    # Centered at bottom half
    # Coordinates logic
    center_x = size // 2
    bottom_y = size - 200
    
    # Base
    base_w = 400
    base_h = 60
    draw.rectangle(
        [center_x - base_w//2, bottom_y - base_h, center_x + base_w//2, bottom_y], 
        fill=fg_color
    )
    
    # Neck (curved or trapezoid)
    neck_w = 150
    neck_h = 100
    neck_bottom_y = bottom_y - base_h
    neck_top_y = neck_bottom_y - neck_h
    # Simple trapezoid for neck
    draw.polygon([
        (center_x - base_w//4, neck_bottom_y),
        (center_x + base_w//4, neck_bottom_y),
        (center_x + neck_w//2, neck_top_y),
        (center_x - neck_w//2, neck_top_y)
    ], fill=fg_color)

    # Top (The Anvil Head)
    head_w = 600
    head_h = 150
    head_bottom_y = neck_top_y
    head_top_y = head_bottom_y - head_h
    
    # Horn (left side)
    # Block (right side)
    # Let's draw a complex polygon for the head
    points = [
        (center_x - head_w//2, head_top_y + 20), # Top left (horn tip start)
        (center_x - head_w//2 + 100, head_top_y + 100), # Curve clear
        (center_x - neck_w//2, head_bottom_y), # Join neck
        (center_x + head_w//2, head_bottom_y), # Bottom right
        (center_x + head_w//2, head_top_y),    # Top right
        (center_x - head_w//3, head_top_y),   # Top left-ish
    ]
    # Actually, simpler shape:
    # 1. Main block
    block_left = center_x - 100
    block_right = center_x + 300
    draw.rectangle([block_left, head_top_y, block_right, head_bottom_y], fill=fg_color)
    
    # 2. Horn (Triangle pointing left)
    horn_tip_x = center_x - 300
    horn_tip_y = head_top_y + 20
    draw.polygon([
        (block_left, head_top_y),
        (block_left, head_bottom_y),
        (horn_tip_x, head_top_y + 30)
    ], fill=fg_color)
    
    # --- Draw Arrow (Rising Stock) ---
    # Zig zag up from the anvil
    arrow_points = [
        (center_x - 200, head_top_y),        # Start on anvil
        (center_x - 50, head_top_y - 150),   # Peak 1
        (center_x + 50, head_top_y - 50),    # Dip
        (center_x + 250, head_top_y - 250)   # Peak 2 (Arrow head base)
    ]
    
    # Draw thick line
    draw.line(arrow_points, fill=fg_color, width=40)
    
    # Arrow Head
    tip = (center_x + 300, head_top_y - 300)
    # Base is the last point of line
    # Simple triangle
    draw.polygon([
        (center_x + 220, head_top_y - 300),
        (center_x + 300, head_top_y - 220),
        tip
    ], fill=fg_color)

    # Save Foreground (Transparent)
    img_foreground = img
    img_foreground.save(r"d:\DA_Stock\stock_app\assets\icons\android_foreground.png")
    print("Saved android_foreground.png")
    
    # Save Monochrome (Same as foreground but flattened alpha mask - here it's already white on transparent)
    img_foreground.save(r"d:\DA_Stock\stock_app\assets\icons\android_monochrome.png")
    print("Saved android_monochrome.png")
    
    # Save Base Icon (Compass on background)
    img_base = Image.new("RGBA", (size, size), bg_color)
    # Composite
    img_base.alpha_composite(img_foreground)
    img_base.save(r"d:\DA_Stock\stock_app\assets\icons\base_app_icon.png")
    print("Saved base_app_icon.png")

if __name__ == "__main__":
    create_forge_stock_icons()
