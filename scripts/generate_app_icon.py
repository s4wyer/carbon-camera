"""Render Carbon's geometric offset-copy mark. Requires Pillow; CI uses committed PNGs."""

import json
from pathlib import Path

from PIL import Image, ImageDraw


def generate():
    output = Path(__file__).resolve().parents[1] / "Carbon/Resources/Assets.xcassets/AppIcon.appiconset"
    output.mkdir(parents=True, exist_ok=True)
    # Draw at 2x the largest size, then downsample for smooth edges.
    image = Image.new("RGB", (2048, 2048), "#0E0E10")
    draw = ImageDraw.Draw(image)
    draw.arc((464, 464, 1648, 1648), 42, 318, fill="#B79B62", width=144)
    draw.arc((336, 336, 1520, 1520), 42, 318, fill="#F3EBDD", width=144)
    draw.rectangle((1552, 880, 1696, 1024), fill="#B79B62")
    images = []
    for size, scales, idiom in ((20, (2, 3), "iphone"), (29, (2, 3), "iphone"),
                                 (40, (2, 3), "iphone"), (60, (2, 3), "iphone"),
                                 (1024, (1,), "ios-marketing")):
        for scale in scales:
            pixels = size * scale
            filename = f"AppIcon-{pixels}.png"
            image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(output / filename)
            images.append({"filename": filename, "idiom": idiom,
                           "size": f"{size}x{size}", "scale": f"{scale}x"})
    (output / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8")


if __name__ == "__main__":
    generate()
