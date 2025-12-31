from PIL import Image, ImageDraw

def create_splash_icon():
    # Source: The transparent foreground we made earlier
    src_path = r"d:\DA_Stock\stock_app\assets\icons_bull\android_foreground.png"
    out_path = r"d:\DA_Stock\stock_app\assets\splash_icon.png"
    
    try:
        # Load foreground (Green Bull on Transparent)
        img_fg = Image.open(src_path).convert("RGBA")
        
        # Determine size
        # We want the final icon to be a Black Circle containing the Bull.
        # Android 12 Splash Icon: The icon is viewed within a circle of diameter 2/3 * width.
        # But here we want the IMAGE itself to be the circle.
        
        size = img_fg.size
        width, height = size
        
        # Create a new canvas
        splash_img = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(splash_img)
        
        # Draw Black Circle
        # Diameter should be close to full size but leaving room?
        # Actually Android splash icons are usually square images that get masked.
        # IF we want it to LOOK distinctively round on a white background, we must draw the circle ourselves.
        # Assuming the input is roughly square 838x802.
        
        # Center coords
        cx, cy = width // 2, height // 2
        # Radius: min of width/height / 2
        radius = min(width, height) // 2
        
        # Margins to be safe?
        # Let's make the black circle fill the bounds (or slightly less to ensure anti-aliasing isn't cut)
        margin = 10
        draw.ellipse([cx - radius + margin, cy - radius + margin, cx + radius - margin, cy + radius - margin], fill=(0, 0, 0, 255))
        
        # Now Paste the Bull on top
        # We might need to scale the bull down a bit if it touches the edges, to fit inside the circle.
        # Check original processing, bull was full size.
        # Resize bull to 70% to fit nicely inside circle
        scale_factor = 0.75
        new_w, new_h = int(width * scale_factor), int(height * scale_factor)
        img_fg_resized = img_fg.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        offset_x = (width - new_w) // 2
        offset_y = (height - new_h) // 2
        
        splash_img.alpha_composite(img_fg_resized, (offset_x, offset_y))
        
        splash_img.save(out_path)
        print(f"Saved {out_path}")
        
    except Exception as e:
        print(f"Error creating splash icon: {e}")

if __name__ == "__main__":
    create_splash_icon()
