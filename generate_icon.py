import math
import os
from PIL import Image, ImageDraw

def create_app_icon(output_path="assets/icon/app_icon.png"):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    bg_margin = 32
    bg_radius = 220
    gradient_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(gradient_img)
    for y in range(size):
        ratio = y / size
        r = int(7 + (22 - 7) * ratio)
        g = int(11 + (31 - 11) * ratio)
        b = int(20 + (50 - 20) * ratio)
        grad_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [bg_margin, bg_margin, size - bg_margin, size - bg_margin],
        radius=bg_radius,
        fill=255
    )
    img.paste(gradient_img, (0, 0), mask)

    draw.rounded_rectangle(
        [bg_margin, bg_margin, size - bg_margin, size - bg_margin],
        radius=bg_radius,
        outline=(245, 158, 11, 120),
        width=6
    )

    cx, cy = 512, 540
    # Compass rings
    for r, col, w in [(370, (36, 48, 70, 255), 5), (260, (36, 48, 70, 200), 3), (150, (36, 48, 70, 180), 3)]:
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w)

    # Crosshair lines
    draw.line([(cx - 380, cy), (cx + 380, cy)], fill=(56, 189, 248, 140), width=4)
    draw.line([(cx, cy - 380), (cx, cy + 380)], fill=(56, 189, 248, 140), width=4)

    # Golden Sun Trajectory Arc
    arc_bbox = [cx - 330, cy - 340, cx + 330, cy + 280]
    draw.arc(arc_bbox, start=195, end=345, fill=(245, 158, 11, 255), width=18)
    draw.arc([cx - 330, cy - 260, cx + 330, cy + 320], start=205, end=335, fill=(56, 189, 248, 190), width=10)

    # Glowing Sun Sphere at zenith-right
    sx, sy = cx + 115, cy - 285
    draw.ellipse([sx - 95, sy - 95, sx + 95, sy + 95], fill=(245, 158, 11, 70))
    draw.ellipse([sx - 68, sy - 68, sx + 68, sy + 68], fill=(251, 191, 36, 255), outline=(255, 255, 255, 220), width=5)

    # Solar Panel / Horizon Vector Emblem at center
    panel_pts = [(cx - 140, cy + 90), (cx + 90, cy - 10), (cx + 150, cy + 110), (cx - 80, cy + 210)]
    draw.polygon(panel_pts, fill=(15, 23, 42, 255), outline=(56, 189, 248, 255))

    img.save(output_path, "PNG")
    print(f"Generated SunPath AR Pro icon at {output_path}")

if __name__ == "__main__":
    create_app_icon()
