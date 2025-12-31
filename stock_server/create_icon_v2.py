from PIL import Image, ImageDraw

def create_icon():
    input_path = r"C:\Users\Phuc\.gemini\antigravity\brain\f37925ae-2595-4f38-850a-0f02f32c0cc1\uploaded_image_0_1766459281308.png"
    output_path = r"d:\DA_Stock\stock_app\assets\icon_v2.png"
    
    try:
        img = Image.open(input_path).convert("RGBA")
        width, height = img.size
        
        # 1. Flood fill background (White -> Black)
        # Use a threshold to catch off-white pixels
        ImageDraw.floodfill(img, (0, 0), (0, 0, 0, 255), thresh=50)
        ImageDraw.floodfill(img, (width-1, 0), (0, 0, 0, 255), thresh=50)
        ImageDraw.floodfill(img, (0, height-1), (0, 0, 0, 255), thresh=50)
        ImageDraw.floodfill(img, (width-1, height-1), (0, 0, 0, 255), thresh=50)
        
        # 2. Draw Green Border
        # "viền xanh lá(green)"
        # Let's verify the Bull's green and try to coordinate, or just use a vibrant green
        # A nice material design green is #4CAF50, but user might want standard Green #00FF00
        # Let's use a vibrant green #00E676 (Green A400) or similar.
        border_color = (0, 230, 118, 255) # Green accent
        
        draw = ImageDraw.Draw(img)
        
        # Circle should be centered.
        # Diameter: fit within the square but leave some padding? Or full width?
        # Usually icons are full bleed. A circle border implies it touches the edges?
        # User screenshot shows a circle INSIDE the icon area? No, the screenshot shows the launcher icon IS a circle (adaptive).
        # But they asked for a "green border".
        # If I draw a circle border IN the image, and then Android masks it to a circle, the border might be cut off or look weird.
        # The user said "viền xanh lá".
        # If I make the WHOLE background black, and draw a circle around the bull.
        # I'll calculate a circle that frames the bull.
        
        # Assuming bull is roughly centered.
        # I'll draw a circle with some margin.
        margin = 20
        bbox = (margin, margin, width - margin, height - margin)
        
        # Thickness
        thickness = 40
        draw.ellipse(bbox, outline=border_color, width=thickness)
        
        # Save
        img.save(output_path)
        print(f"Icon created at {output_path}")
        
    except Exception as e:
        print(f"Error creating icon: {e}")

if __name__ == "__main__":
    create_icon()
