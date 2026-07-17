#!/usr/bin/env python3
"""Generate LocalFlow.icns from scratch using PIL."""

import math
import os
import struct
import subprocess
import tempfile
from PIL import Image, ImageDraw

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def rounded_rect_mask(size, radius_frac=0.224):
    img = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(img)
    r = int(size * radius_frac)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return img


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient_bg(draw, size):
    top = (28, 52, 180)
    bottom = (88, 28, 200)
    for y in range(size):
        t = y / (size - 1)
        c = lerp_color(top, bottom, t)
        draw.line([(0, y), (size - 1, y)], fill=c + (255,))


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw_gradient_bg(draw, size)

    mask = rounded_rect_mask(size)
    img.putalpha(mask)

    lw = max(2, int(size * 0.038))

    # --- mic body (centred, slightly left of canvas centre) ---
    mic_cx = size * 0.38
    mic_cy = size * 0.42
    mic_w = size * 0.20
    mic_h = size * 0.36
    mic_r = mic_w / 2
    mic_top = mic_cy - mic_h / 2
    mic_bottom = mic_cy + mic_h / 2

    draw.rounded_rectangle(
        [mic_cx - mic_w / 2, mic_top, mic_cx + mic_w / 2, mic_bottom],
        radius=mic_r,
        fill=(255, 255, 255, 255),
    )

    # --- stand: bracket arc below mic + vertical stem + base ---
    bracket_r = size * 0.155
    bracket_cy = mic_bottom
    bracket_box = [
        mic_cx - bracket_r,
        bracket_cy - bracket_r,
        mic_cx + bracket_r,
        bracket_cy + bracket_r,
    ]
    draw.arc(bracket_box, start=0, end=180, fill=(255, 255, 255, 230), width=lw)

    stem_top_y = bracket_cy + bracket_r
    stem_bottom_y = stem_top_y + size * 0.06
    draw.line([(mic_cx, stem_top_y), (mic_cx, stem_bottom_y)],
              fill=(255, 255, 255, 230), width=lw)

    base_half = size * 0.09
    draw.line([(mic_cx - base_half, stem_bottom_y),
               (mic_cx + base_half, stem_bottom_y)],
              fill=(255, 255, 255, 230), width=lw)

    # --- sound wave arcs (right of mic, centred on mic mid-height) ---
    wave_start_x = mic_cx + mic_w / 2 + size * 0.025
    wave_cy = mic_cy
    wave_color = (255, 255, 255, 210)
    wave_lw = max(1, int(size * 0.030))
    for gap in [0.10, 0.18, 0.27]:
        r = size * gap
        # arc centred at (wave_start_x, wave_cy)
        ab = [wave_start_x - r, wave_cy - r,
              wave_start_x + r, wave_cy + r]
        draw.arc(ab, start=-55, end=55, fill=wave_color, width=wave_lw)

    # --- text cursor (far right, clearly separated) ---
    cur_x = size * 0.80
    cur_h = size * 0.26
    cur_top = wave_cy - cur_h / 2
    cur_bottom = wave_cy + cur_h / 2
    cur_lw = max(2, int(size * 0.042))
    serif = size * 0.035

    draw.line([(cur_x, cur_top), (cur_x, cur_bottom)],
              fill=(255, 255, 255, 255), width=cur_lw)
    draw.line([(cur_x - serif, cur_top), (cur_x + serif, cur_top)],
              fill=(255, 255, 255, 255), width=cur_lw)
    draw.line([(cur_x - serif, cur_bottom), (cur_x + serif, cur_bottom)],
              fill=(255, 255, 255, 255), width=cur_lw)

    return img


def build_icns(images_by_size, out_path):
    """Assemble an .icns file manually."""
    type_map = {
        16:   (b"icp4", b"ic11"),
        32:   (b"icp5", b"ic12"),
        64:   (b"icp6", None),
        128:  (b"ic07", b"ic13"),
        256:  (b"ic08", b"ic14"),
        512:  (b"ic09", b"ic10"),
        1024: (b"ic10", None),
    }

    chunks = []
    for size, img in images_by_size.items():
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            img.save(f.name, "PNG")
            png_data = open(f.name, "rb").read()
            os.unlink(f.name)

        normal_type, retina_type = type_map.get(size, (None, None))
        if normal_type:
            chunks.append((normal_type, png_data))

    total = 8  # header size
    for type_code, data in chunks:
        total += 8 + len(data)

    with open(out_path, "wb") as f:
        f.write(b"icns")
        f.write(struct.pack(">I", total))
        for type_code, data in chunks:
            f.write(type_code)
            f.write(struct.pack(">I", 8 + len(data)))
            f.write(data)


def main():
    os.makedirs("Resources", exist_ok=True)

    images = {}
    for size in SIZES:
        hi = size * 2 if size <= 512 else size
        base = draw_icon(hi)
        if hi != size:
            base = base.resize((size, size), Image.LANCZOS)
        images[size] = base
        print(f"  {size}x{size} drawn")

    # Use iconutil if available (cleaner), else manual
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")
    size_name_map = {
        16: ["icon_16x16.png", "icon_16x16@2x.png"],
        32: ["icon_32x32.png", "icon_32x32@2x.png"],
        128: ["icon_128x128.png", "icon_128x128@2x.png"],
        256: ["icon_256x256.png", "icon_256x256@2x.png"],
        512: ["icon_512x512.png", "icon_512x512@2x.png"],
    }
    # write 1x images and 2x as double-resolution
    for size, names in size_name_map.items():
        images[size].save(os.path.join(iconset_dir, names[0]), "PNG")
        if size * 2 in SIZES:
            images[size * 2].save(os.path.join(iconset_dir, names[1]), "PNG")
        else:
            hi = draw_icon(size * 2)
            hi.save(os.path.join(iconset_dir, names[1]), "PNG")

    out = "Resources/AppIcon.icns"
    result = subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", out],
        capture_output=True
    )
    if result.returncode == 0:
        print(f"AppIcon.icns written via iconutil → {out}")
    else:
        print("iconutil failed, falling back to manual assembly")
        build_icns(images, out)
        print(f"AppIcon.icns written manually → {out}")

    # Also save a 1024 PNG preview
    images[1024].save("Resources/AppIcon-preview.png", "PNG")
    print("Preview PNG → Resources/AppIcon-preview.png")


if __name__ == "__main__":
    main()
