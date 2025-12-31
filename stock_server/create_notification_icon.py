
from PIL import Image, ImageDraw
import os

def create_notification_icon():
    # Size: Notification icons are usually small square. 
    # XXHDPI is often around 72x72 or 96x96. Let's go with 96x96 for safety in 'drawable'.
    size = (96, 96)
    
    # Transparent Background
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw White Bull - Abstract Shape
    # Same geometry as before but WHITE fill
    bull_color = (255, 255, 255, 255) # White
    
    center_x, center_y = size[0] // 2, size[1] // 2
    
    # Head
    head_w, head_h = 40, 36
    head_rect = [
        center_x - head_w//2, center_y - head_h//2,
        center_x + head_w//2, center_y + head_h//2
    ]
    draw.rounded_rectangle(head_rect, radius=8, fill=bull_color)
    
    # Horns (sharp triangles) -> White
    horn_w, horn_h = 10, 20
    # Left Horn
    draw.polygon([
        (center_x - head_w//2 + 4, center_y - head_h//2 + 5),
        (center_x - head_w//2 - 8, center_y - head_h//2 - 15),
        (center_x - head_w//2 + 14, center_y - head_h//2 + 5)
    ], fill=bull_color)
    # Right Horn
    draw.polygon([
        (center_x + head_w//2 - 4, center_y - head_h//2 + 5),
        (center_x + head_w//2 + 8, center_y - head_h//2 - 15),
        (center_x + head_w//2 - 14, center_y - head_h//2 + 5)
    ], fill=bull_color)
    
    # Snout (cutout or different shade? Notification icons must be white/alpha mostly.
    # To detail, we can cut out transparency.
    snout_y = center_y + 6
    snout_w = 24
    snout_h = 10
    snout_rect = [
         center_x - snout_w//2, snout_y,
         center_x + snout_w//2, snout_y + snout_h
    ]
    # Draw snout as TRANSPARENT (erasing from white head) prevents "flat blob" look
    draw.rounded_rectangle(snout_rect, radius=4, fill=(0,0,0,0)) 

    # Eyes (Transparent)
    eye_y = center_y - 6
    eye_size = 4
    # Left Eye
    draw.ellipse([center_x - 10 - eye_size, eye_y - eye_size, center_x - 10, eye_y], fill=(0,0,0,0))
    # Right Eye
    draw.ellipse([center_x + 10, eye_y - eye_size, center_x + 10 + eye_size, eye_y], fill=(0,0,0,0))

    # Save
    out_dir = r"d:\DA_Stock\stock_app\android\app\src\main\res\drawable"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "ic_notification.png")
    
    img.save(out_path)
    print(f"Created notification icon at: {out_path}")

if __name__ == "__main__":
    create_notification_icon()
