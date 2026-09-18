#!/usr/bin/env python3
"""The arena crowd's figure atlas (art X5), procedural and seeded: make assets-crowd

    game/theme/cyberpunk/crowd/crowd_atlas.png   512 × 128, 8 frames of 64 × 128, RGBA
        frames 0-3  spectators at rest (arms down, hands on the rail, one pointing, hands in pockets)
        frames 4-7  the same people cheering (both arms up, fist pump, waving, arms wide)
    R = B = shading (a lit top edge for the floodlight rim, darker clothes below), G = skin (1 on heads and hands,
    so the shader can give faces a skin tone: feel X2, round 6), A = coverage (alpha scissor).

Figures are head-and-torso silhouettes: the stands' rails hide the legs, and from the RTS camera a spectator is a
few pixels, so shape and motion carry it. The shader tints each instance and swaps rest → cheer frames (+4).
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "theme" / "cyberpunk" / "crowd"
W, H = 64, 128


def figure(pose: str, rng: random.Random) -> Image.Image:
    scale = 4  # draw big, then downsample for soft edges
    img = Image.new("LA", (W * scale, H * scale), (0, 0))
    d = ImageDraw.Draw(img)
    skin = Image.new("L", (W * scale, H * scale), 0)
    s = ImageDraw.Draw(skin)
    cx = W * scale // 2
    shoulder_y = int(H * scale * 0.42)
    width = int(W * scale * rng.uniform(0.34, 0.44))
    head_r = int(W * scale * 0.13)
    body = 150
    # torso, then head
    d.polygon([(cx - width // 2, shoulder_y), (cx + width // 2, shoulder_y),
               (cx + width // 2 - 10, H * scale), (cx - width // 2 + 10, H * scale)], fill=(body, 255))
    d.ellipse([cx - head_r, shoulder_y - head_r * 2 - 14, cx + head_r, shoulder_y - 14], fill=(205, 255))
    s.ellipse([cx - head_r, shoulder_y - head_r * 2 - 14, cx + head_r, shoulder_y - 14], fill=255)
    arm = 32

    def limb(x0, y0, x1, y1):
        d.line([(x0, y0), (x1, y1)], fill=(170, 255), width=arm)
        d.ellipse([x1 - arm // 2 - 2, y1 - arm // 2 - 2, x1 + arm // 2 + 2, y1 + arm // 2 + 2], fill=(200, 255))
        s.ellipse([x1 - arm // 2 - 2, y1 - arm // 2 - 2, x1 + arm // 2 + 2, y1 + arm // 2 + 2], fill=255)

    left, right = cx - width // 2 + 8, cx + width // 2 - 8
    top = shoulder_y + 10
    reach = int(H * scale * 0.3)
    if pose == "rest_down":
        limb(left, top, left - 12, top + reach)
        limb(right, top, right + 12, top + reach)
    elif pose == "rest_rail":
        limb(left, top, left + 10, top + int(reach * 0.8))
        limb(right, top, right - 10, top + int(reach * 0.8))
    elif pose == "rest_point":
        limb(left, top, left - 12, top + reach)
        limb(right, top, right + 60, top - 40)
    elif pose == "rest_pockets":
        limb(left, top, left + 6, top + int(reach * 0.9))
        limb(right, top, right - 6, top + int(reach * 0.9))
    elif pose == "cheer_both":
        limb(left, top, left - 40, top - reach)
        limb(right, top, right + 40, top - reach)
    elif pose == "cheer_fist":
        limb(left, top, left - 12, top + reach)
        limb(right, top, right + 16, top - int(reach * 1.1))
    elif pose == "cheer_wave":
        limb(left, top, left - 55, top - int(reach * 0.7))
        limb(right, top, right + 12, top + reach)
    elif pose == "cheer_wide":
        limb(left, top, left - 58, top - int(reach * 0.3))
        limb(right, top, right + 58, top - int(reach * 0.3))
    small = img.resize((W, H), Image.LANCZOS)
    skin_small = skin.resize((W, H), Image.LANCZOS)
    lum, alpha = small.split()
    # Rim light from above: brighten the top 20% of the silhouette's pixels in each column.
    shade = Image.new("L", (W, H))
    px_l, px_a, px_s = lum.load(), alpha.load(), shade.load()
    for x in range(W):
        seen = 0
        for y in range(H):
            if px_a[x, y] > 60:
                seen += 1
                px_s[x, y] = min(255, px_l[x, y] + (60 if seen < 5 else 0))
            else:
                px_s[x, y] = px_l[x, y]
    return Image.merge("RGBA", (shade, skin_small, shade, alpha))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(1409)
    atlas = Image.new("RGBA", (W * 8, H), (0, 0, 0, 0))
    poses = ["rest_down", "rest_rail", "rest_point", "rest_pockets", "cheer_both", "cheer_fist", "cheer_wave", "cheer_wide"]
    for i, pose in enumerate(poses):
        atlas.paste(figure(pose, rng), (i * W, 0))
    atlas.save(OUT / "crowd_atlas.png")
    print(f"{(OUT / 'crowd_atlas.png').relative_to(ROOT)}  {atlas.size}  {(OUT / 'crowd_atlas.png').stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
