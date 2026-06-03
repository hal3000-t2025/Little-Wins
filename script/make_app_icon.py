#!/usr/bin/env python3
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
BASE = RESOURCES / "AppIconBase.png"
PNG = RESOURCES / "AppIcon.png"
ICNS = RESOURCES / "AppIcon.icns"
ICONSET = ROOT / "tmp" / "icon" / "AppIcon.iconset"
TEXT = "功劳簿"
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"


def text_size(draw, text, font):
    box = draw.textbbox((0, 0), text, font=font, stroke_width=0)
    return box[2] - box[0], box[3] - box[1]


def draw_title(image):
    image = image.convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    text_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(text_layer)

    font_size = 190
    font = ImageFont.truetype(FONT, font_size, index=0)
    width, height = text_size(draw, TEXT, font)
    while width > 700:
        font_size -= 8
        font = ImageFont.truetype(FONT, font_size, index=0)
        width, height = text_size(draw, TEXT, font)

    x = (1024 - width) // 2
    y = 610

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.text(
        (x + 9, y + 13),
        TEXT,
        font=font,
        fill=(93, 24, 10, 190),
        stroke_width=7,
        stroke_fill=(93, 24, 10, 180),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(2.2))

    # Stacked offsets give the title a raised, pressed-metal feel.
    for offset, fill in [
        (8, (138, 70, 7, 255)),
        (6, (171, 94, 11, 255)),
        (4, (196, 121, 18, 255)),
    ]:
        draw.text(
            (x, y + offset),
            TEXT,
            font=font,
            fill=fill,
            stroke_width=7,
            stroke_fill=(100, 42, 7, 255),
        )

    draw.text(
        (x, y),
        TEXT,
        font=font,
        fill=(255, 214, 78, 255),
        stroke_width=7,
        stroke_fill=(111, 45, 6, 255),
    )
    draw.text(
        (x + 3, y - 4),
        TEXT,
        font=font,
        fill=(255, 246, 158, 185),
        stroke_width=0,
    )

    return Image.alpha_composite(Image.alpha_composite(image, shadow), text_layer)


def write_iconset(source):
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True, exist_ok=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for size, filename in sizes:
        source.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET / filename)

    if ICNS.exists():
        ICNS.unlink()
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)


def main():
    if not BASE.exists():
        raise SystemExit(f"Missing base icon: {BASE}")

    final = draw_title(Image.open(BASE))
    final.save(PNG)
    write_iconset(final)
    print(PNG)
    print(ICNS)


if __name__ == "__main__":
    main()
