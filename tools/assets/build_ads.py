#!/usr/bin/env python3
"""Placeholder ads for the arena's giant screens (assets X2), rebuilt deterministically.

    make assets-ads

The lead decides the real ad art and copy (the brief: "ad art and copy are the lead's call"). These placeholders prove
the screen: graphic backgrounds drawn here (no text baked in: text is overlaid in the engine, art_direction.md), and
the copy in ads.json written to the humor direction in game_design.md (believable, slightly off, never a punchline).

Outputs (game/theme/arena_kit/ads/):
    <id>.png       512 × 1024 portrait still, or a flipbook sheet (frames laid out left to right, top to bottom)
    ads.json       the playlist: id, image, frames [cols, rows], fps, seconds, brand, headline, fine_print, accent,
                   average_color (tints the screen's light spill on the ground), kind ("still" or "live")
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "theme" / "arena_kit" / "ads"
W, H = 512, 1024

ADS = [
    {"id": "syndicate_life", "brand": "SYNDICATE LIFE", "headline": "COVERAGE THAT\nOUTLIVES YOU",
     "fine_print": "Beneficiary payouts processed within 90 business days of confirmed loss.", "accent": "#d8b86a", "seconds": 9},
    {"id": "aquacorp", "brand": "AQUACORP", "headline": "CLEAN WATER.\nEVERY DAY\nYOU QUALIFY.",
     "fine_print": "Ration tier verified at point of sale.", "accent": "#7fe3ff", "seconds": 8, "frames": [4, 2], "fps": 6},
    {"id": "warden", "brand": "OFFICE OF THE WARDEN", "headline": "SAFER STREETS\nSTART WITH\nA REPORT",
     "fine_print": "Verified tips earn ration credit. Reports cannot be withdrawn.", "accent": "#e8ecf2", "seconds": 8},
    {"id": "organ_futures", "brand": "ORGAN FUTURES", "headline": "INVEST IN\nTONIGHT'S\nCHAMPIONS",
     "fine_print": "Contracts settle at the final bell.", "accent": "#e2c27a", "seconds": 8},
    {"id": "freedom_program", "brand": "THE FREEDOM PROGRAM", "headline": "WIN YOUR\nFREEDOM\nTONIGHT",
     "fine_print": "Release subject to review by the Board. Terms apply.", "accent": "#ffb13b", "seconds": 8},
    {"id": "arena_live", "kind": "live", "brand": "LIVE FROM THE PIT", "headline": "GREEN\nvs\nRUST",
     "fine_print": "Odds update after every confirmed kill.", "accent": "#ffffff", "seconds": 7},
]


def gradient(top, bottom) -> np.ndarray:
    t = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None, None]
    return np.broadcast_to(np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t, (H, W, 3)).copy()


def glow(layer: Image.Image, radius: float, strength: float) -> np.ndarray:
    base = np.asarray(layer, dtype=np.float32) / 255.0
    halo = np.asarray(layer.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0
    return base + halo * strength


def noise(seed: int, amount: float) -> np.ndarray:
    """Film grain, kept faint: grain defeats PNG compression, and the screen shader adds its own texture."""
    return (np.random.default_rng(seed).random((H // 4, W // 4, 1), dtype=np.float32) - 0.5).repeat(4, 0).repeat(4, 1) * amount * 0.3


def to_image(rgb: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(rgb, 0.0, 1.0) * 255).astype(np.uint8), "RGB")


def syndicate_life() -> Image.Image:
    rgb = gradient((0.02, 0.03, 0.06), (0.09, 0.08, 0.07))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.ellipse([56, 250, 456, 650], outline=(216, 184, 106), width=3)  # a halo rising over a horizon
    d.ellipse([136, 330, 376, 570], fill=(60, 52, 36))
    d.rectangle([0, 520, W, H], fill=(0, 0, 0))
    d.line([(24, 520), (488, 520)], fill=(216, 184, 106), width=2)
    for i in range(60):
        x, y = (i * 97) % W, 120 + (i * 53) % 380
        d.ellipse([x, y, x + 2, y + 2], fill=(200, 180, 130))
    rgb = rgb * 0.8 + glow(layer, 18, 1.2) * 0.9
    return to_image(rgb + noise(1, 0.03))


def aquacorp() -> Image.Image:
    # Flipbook frames at half resolution: motion hides it, and eight full frames would weigh as much as eight ads.
    sheet = Image.new("RGB", (W * 2, H))
    for frame in range(8):
        rgb = gradient((0.0, 0.08, 0.14), (0.0, 0.02, 0.05))
        layer = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(layer)
        phase = frame / 8.0
        for ring in range(3):  # ripples spreading from where the drop lands
            r = 40 + ((phase + ring / 3.0) % 1.0) * 220
            fade = int(200 * (1.0 - ((phase + ring / 3.0) % 1.0)))
            d.ellipse([W / 2 - r, 600 - r * 0.28, W / 2 + r, 600 + r * 0.28], outline=(40, fade, 255), width=3)
        y = 180 + (math.sin(phase * math.tau) * 0.5 + 0.5) * 60
        d.ellipse([196, y + 90, 316, y + 210], fill=(90, 210, 255))
        d.polygon([(200, y + 140), (256, y), (312, y + 140)], fill=(90, 210, 255))
        d.ellipse([222, y + 120, 250, y + 148], fill=(210, 245, 255))
        rgb = rgb + glow(layer, 16, 1.0) * 0.8
        frame_image = to_image(rgb + noise(10 + frame, 0.02)).resize((W // 2, H // 2), Image.LANCZOS)
        sheet.paste(frame_image, ((frame % 4) * W // 2, (frame // 4) * H // 2))
    return sheet


def warden() -> Image.Image:
    rgb = gradient((0.03, 0.04, 0.08), (0.01, 0.01, 0.02))
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    sweep = np.clip(1.0 - np.abs((x * 0.6 + y * 0.4) - 520) / 160, 0, 1)[..., None]
    rgb += sweep * np.array([0.35, 0.02, 0.05], np.float32) * 0.6
    sweep2 = np.clip(1.0 - np.abs((x * 0.6 - y * 0.4) + 80) / 160, 0, 1)[..., None]
    rgb += sweep2 * np.array([0.02, 0.1, 0.4], np.float32) * 0.6
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    cx, cy = W / 2, 330
    shield = [(cx - 120, cy - 130), (cx + 120, cy - 130), (cx + 120, cy + 20), (cx, cy + 150), (cx - 120, cy + 20)]
    d.polygon(shield, outline=(220, 226, 236), width=6)
    star = [(cx + math.cos(math.pi / 2 + i * math.pi / 5) * (70 if i % 2 == 0 else 28),
             cy - 10 - math.sin(math.pi / 2 + i * math.pi / 5) * (70 if i % 2 == 0 else 28)) for i in range(10)]
    d.polygon(star, fill=(200, 206, 216))
    rgb = rgb + glow(layer, 10, 0.6) * 0.8
    return to_image(rgb + noise(3, 0.04))


def organ_futures() -> Image.Image:
    rgb = gradient((0.02, 0.02, 0.02), (0.05, 0.03, 0.02))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for gx in range(0, W, 48):
        d.line([(gx, 120), (gx, 600)], fill=(40, 34, 24), width=1)
    for gy in range(120, 601, 48):
        d.line([(0, gy), (W, gy)], fill=(40, 34, 24), width=1)
    points, value = [], 520.0
    rng = np.random.default_rng(4)
    for i, px in enumerate(range(20, W - 19, 24)):
        value -= rng.normal(14, 22)  # a line that mostly goes up
        points.append((px, max(150.0, min(580.0, value))))
    d.line(points, fill=(226, 194, 122), width=4, joint="curve")
    d.ellipse([points[-1][0] - 8, points[-1][1] - 8, points[-1][0] + 8, points[-1][1] + 8], fill=(255, 230, 160))
    rgb = rgb + glow(layer, 12, 0.9) * 0.9
    return to_image(rgb + noise(5, 0.03))


def freedom_program() -> Image.Image:
    rgb = gradient((0.06, 0.03, 0.01), (0.01, 0.01, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.rectangle([176, 170, 336, 560], fill=(255, 196, 110))  # an open gate, light pouring through
    for bar in range(6):
        bx = 176 + bar * 32
        d.rectangle([bx - 3, 170, bx + 3, 560], fill=(30, 18, 8))
    d.polygon([(176, 560), (336, 560), (470, 700), (42, 700)], fill=(120, 80, 36))
    for stripe in range(-2, 16):
        sx = stripe * 40
        d.polygon([(sx, 1024), (sx + 20, 1024), (sx + 70, 950), (sx + 50, 950)], fill=(60, 40, 8))
    rgb = rgb + glow(layer, 26, 1.1) * 0.85
    return to_image(rgb + noise(6, 0.04))


def arena_live() -> Image.Image:
    rgb = gradient((0.02, 0.02, 0.05), (0.0, 0.0, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.polygon([(0, 140), (W, 60), (W, 330), (0, 410)], fill=(0, 120, 128))
    d.polygon([(0, 440), (W, 360), (W, 630), (0, 710)], fill=(128, 0, 76))
    rgb = rgb + glow(layer, 30, 0.6) * 0.5
    return to_image(rgb + noise(7, 0.03))


PAINTERS = {"syndicate_life": syndicate_life, "aquacorp": aquacorp, "warden": warden, "organ_futures": organ_futures,
            "freedom_program": freedom_program, "arena_live": arena_live}


def average_color(image: Image.Image, frames) -> str:
    if frames:
        image = image.crop((0, 0, image.width // frames[0], image.height // frames[1]))
    rgb = np.asarray(image, dtype=np.float32).reshape(-1, 3)
    # What a screen throws on the ground is its bright content, not its black background.
    weights = rgb.max(axis=1) + 1.0
    mean = (rgb * weights[:, None]).sum(axis=0) / weights.sum()
    return "#%02x%02x%02x" % tuple(int(v) for v in mean)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    playlist = []
    for ad in ADS:
        image = PAINTERS[ad["id"]]()
        image.save(OUT / f"{ad['id']}.png", optimize=True)
        entry = {"id": ad["id"], "kind": ad.get("kind", "still"), "image": f"res://game/theme/arena_kit/ads/{ad['id']}.png",
                 "frames": ad.get("frames", [1, 1]), "fps": ad.get("fps", 0), "seconds": ad["seconds"],
                 "brand": ad["brand"], "headline": ad["headline"], "fine_print": ad["fine_print"], "accent": ad["accent"],
                 "average_color": average_color(image, ad.get("frames"))}
        playlist.append(entry)
        print(f"ads: {ad['id']:<16} {(OUT / (ad['id'] + '.png')).stat().st_size / 1024:.0f} KB  light {entry['average_color']}")
    (OUT / "ads.json").write_text(json.dumps({"placeholder": True, "note": "Art and copy are the lead's call; see "
                                              "tools/assets/build_ads.py.", "ads": playlist}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
