#!/usr/bin/env python3
"""Placeholder ads for the arena's giant screens (assets X2), rebuilt deterministically.

    make assets-ads

The copy is the lead's approved set (round 5): the twelve screen ads in assets/announcer/drafts/ad_copy.md, as written
(headline, small line). Art is procedural backgrounds drawn here, one motif per brand (no text baked in: text is
overlaid in the engine, art_direction.md). Between matches the screens rotate these; during a match they show LiveFeed.

Outputs (game/theme/arena_kit/ads/):
    <id>.png       256 × 512 portrait still (drawn at 512 × 1024), or a flipbook sheet (frames laid out left to right, top to bottom)
    neon_signs.png 512 × 256 atlas of neon tube signs for the stands (4 rows of 512 × 64): R = tube core, G = glow
                   (text drawn here from our own brand names in Oswald; neon_signs.gd lays them out)
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

LINE_CHARS = 13


def headline(text: str) -> str:
    """Break an approved headline (at most four words) into the screen's lines: sentences first, then at LINE_CHARS (what fits the 46 px Oswald headline across the 320 px layout)."""
    lines, current = [], ""
    for word in text.split():
        if current and (len(current) + 1 + len(word) > LINE_CHARS or current.endswith(".")):
            lines.append(current)
            current = word
        else:
            current = f"{current} {word}".strip()
    lines.append(current)
    # Never strand a short word on its own line ("TAKEN CARE / OF"): pull it up.
    if len(lines) > 1 and len(lines[-1]) <= 3 and len(lines[-2]) + 1 + len(lines[-1]) <= LINE_CHARS:
        last = lines.pop()
        lines[-1] = f"{lines[-1]} {last}"
    return "\n".join(lines)


# The lead's approved screen copy (ad_copy.md, round 5): [id, brand, headline, small line, accent, art]. `art` names the
# painter (brands share one motif); AquaCorp's water drop is a flipbook.
APPROVED = [
    ["aquacorp_week", "AQUACORP", "CLEAN WATER. EVERY WEEK.", "For approved households. Schedules posted Mondays.", "#7fe3ff", "aquacorp"],
    ["aquacorp_health", "AQUACORP", "HYDRATION IS HEALTH", "Your allocation has been reviewed.", "#7fe3ff", "aquacorp"],
    ["syndicate_life_protect", "SYNDICATE LIFE", "PROTECT WHAT MATTERS", "Plans from one month of labor.", "#d8b86a", "syndicate_life"],
    ["syndicate_life_care", "SYNDICATE LIFE", "THEY'LL BE TAKEN CARE OF", "Beneficiaries notified automatically.", "#d8b86a", "syndicate_life"],
    ["meridian", "MERIDIAN TRANSPORT", "GET THERE TOGETHER", "District passes checked at every stop.", "#9fd4a8", "meridian"],
    ["harbor_general", "HARBOR GENERAL", "WE'RE HERE FOR YOU", "Official hospital of the arena. Winners first.", "#ff8a8a", "harbor_general"],
    ["vireo", "VIREO", "REAL FOOD. REAL ENERGY.", "Now 92% food.", "#b8e05a", "vireo"],
    ["northgrid", "NORTHGRID POWER", "KEEPING THE LIGHTS ON", "In selected residential areas.", "#ffd34a", "northgrid"],
    ["syndicate_vision", "SYNDICATE VISION", "EVERY ANGLE. FOREVER.", "All broadcasts archived permanently.", "#c7a6ff", "syndicate_vision"],
    ["syndicate_housing", "SYNDICATE HOUSING", "A HOME IN THE EAST", "Applications reviewed by lottery.", "#e8c9a0", "syndicate_housing"],
    ["syndicate_security", "SYNDICATE SECURITY", "SEE SOMETHING. REPORT IT.", "Reports during tonight's match earn double credit.", "#e8ecf2", "warden"],
    ["the_law", "THE LAW", "ORDER IS A PUBLIC GOOD", "Tip lines open around the clock.", "#8fb4ff", "warden"],
]

ADS = [
    {"id": ad_id, "brand": brand, "headline": headline(text), "fine_print": line, "accent": accent, "art": art, "seconds": 8,
     **({"frames": [4, 2], "fps": 6} if art == "aquacorp" else {})}
    for ad_id, brand, text, line, accent, art in APPROVED
] + [
    {"id": "arena_live", "kind": "live", "brand": "LIVE FROM THE PIT", "headline": "TONIGHT'S\nMATCH",
     "fine_print": "Odds update after every confirmed kill.", "accent": "#ffffff", "art": "arena_live", "seconds": 7},
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
    # Flipbook frames at quarter resolution (128 × 256): motion hides it, and eight full frames would weigh as much as
    # eight ads.
    sheet = Image.new("RGB", (W, H // 2))
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
        frame_image = to_image(rgb + noise(10 + frame, 0.02)).resize((W // 4, H // 4), Image.LANCZOS)
        sheet.paste(frame_image, ((frame % 4) * W // 4, (frame // 4) * H // 4))
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


def meridian() -> Image.Image:
    rgb = gradient((0.02, 0.05, 0.04), (0.0, 0.01, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for side in (-1, 1):  # rails running to a vanishing point, sleepers across them
        d.line([(W / 2 + side * 20, 300), (W / 2 + side * 230, H)], fill=(159, 212, 168), width=6)
    for k in range(12):
        t = (k / 12.0) ** 1.8
        y = 300 + t * (H - 300)
        half = 20 + t * 230
        d.line([(W / 2 - half, y), (W / 2 + half, y)], fill=(60, 90, 70), width=max(2, int(2 + t * 8)))
    d.ellipse([W / 2 - 18, 270, W / 2 + 18, 306], fill=(230, 255, 220))
    rgb = rgb + glow(layer, 14, 0.9) * 0.85
    return to_image(rgb + noise(11, 0.03))


def harbor_general() -> Image.Image:
    rgb = gradient((0.06, 0.02, 0.03), (0.01, 0.0, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.rectangle([W / 2 - 40, 150, W / 2 + 40, 390], fill=(255, 138, 138))  # a cross
    d.rectangle([W / 2 - 120, 230, W / 2 + 120, 310], fill=(255, 138, 138))
    points = [(0, 520)]
    for x in range(0, W + 1, 16):  # a pulse line that settles flat
        beat = 0 if x < 180 or x > 300 else (-120 if 220 < x < 240 else (60 if 240 <= x < 260 else 0))
        points.append((x, 520 + beat))
    d.line(points, fill=(255, 190, 190), width=4)
    rgb = rgb + glow(layer, 16, 1.0) * 0.8
    return to_image(rgb + noise(12, 0.03))


def vireo() -> Image.Image:
    rgb = gradient((0.04, 0.06, 0.02), (0.01, 0.02, 0.0))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([120, 260, 392, 380], radius=24, fill=(150, 120, 70))  # a ration bar
    for k in range(5):
        d.line([(150 + k * 50, 270), (150 + k * 50, 370)], fill=(110, 86, 48), width=5)
    d.ellipse([300, 150, 420, 250], fill=(184, 224, 90))  # a leaf beside it
    d.line([(310, 240), (410, 160)], fill=(90, 130, 40), width=4)
    rgb = rgb + glow(layer, 12, 0.8) * 0.85
    return to_image(rgb + noise(13, 0.03))


def northgrid() -> Image.Image:
    rgb = gradient((0.02, 0.02, 0.05), (0.05, 0.04, 0.0))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for px, scale in ((150, 1.0), (380, 0.7)):  # pylons and their sagging lines
        top, base = 200 + (1 - scale) * 150, 620
        d.polygon([(px, top), (px - 70 * scale, base), (px + 70 * scale, base)], outline=(255, 211, 74), width=4)
        d.line([(px - 60 * scale, top + 60), (px + 60 * scale, top + 60)], fill=(255, 211, 74), width=4)
    d.line([(90, 260), (330, 320)], fill=(200, 170, 60), width=2)
    for k in range(40):  # lit windows in one district only
        x, y = 20 + (k * 53) % 240, 700 + (k * 37) % 120
        d.rectangle([x, y, x + 8, y + 12], fill=(255, 220, 120))
    rgb = rgb + glow(layer, 12, 0.9) * 0.85
    return to_image(rgb + noise(14, 0.03))


def syndicate_vision() -> Image.Image:
    rgb = gradient((0.03, 0.02, 0.06), (0.0, 0.0, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for r, width in ((210, 4), (150, 6), (90, 10)):  # a camera lens
        d.ellipse([W / 2 - r, 330 - r, W / 2 + r, 330 + r], outline=(199, 166, 255), width=width)
    d.ellipse([W / 2 - 40, 290, W / 2 + 40, 370], fill=(240, 230, 255))
    d.ellipse([W / 2 - 70, 250, W / 2 - 40, 280], fill=(255, 255, 255))
    rgb = rgb + glow(layer, 18, 1.0) * 0.85
    return to_image(rgb + noise(15, 0.03))


def syndicate_housing() -> Image.Image:
    rgb = gradient((0.06, 0.04, 0.03), (0.01, 0.01, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for bx, top in ((40, 260), (190, 160), (340, 300)):  # identical towers, one window lit each
        d.rectangle([bx, top, bx + 130, 700], outline=(232, 201, 160), width=3)
        for wy in range(top + 20, 690, 40):
            for wx in range(bx + 15, bx + 120, 35):
                d.rectangle([wx, wy, wx + 14, wy + 18], fill=(60, 46, 34))
        d.rectangle([bx + 50, top + 140, bx + 64, top + 158], fill=(255, 220, 160))
    rgb = rgb + glow(layer, 10, 0.8) * 0.85
    return to_image(rgb + noise(16, 0.03))


def arena_live() -> Image.Image:
    rgb = gradient((0.02, 0.02, 0.05), (0.0, 0.0, 0.01))
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    d.polygon([(0, 140), (W, 60), (W, 330), (0, 410)], fill=(0, 120, 128))
    d.polygon([(0, 440), (W, 360), (W, 630), (0, 710)], fill=(128, 0, 76))
    rgb = rgb + glow(layer, 30, 0.6) * 0.5
    return to_image(rgb + noise(7, 0.03))


PAINTERS = {"syndicate_life": syndicate_life, "aquacorp": aquacorp, "warden": warden, "meridian": meridian,
            "harbor_general": harbor_general, "vireo": vireo, "northgrid": northgrid, "syndicate_vision": syndicate_vision,
            "syndicate_housing": syndicate_housing, "arena_live": arena_live}


def average_color(image: Image.Image, frames) -> str:
    if frames:
        image = image.crop((0, 0, image.width // frames[0], image.height // frames[1]))
    rgb = np.asarray(image, dtype=np.float32).reshape(-1, 3)
    # What a screen throws on the ground is its bright content, not its black background.
    weights = rgb.max(axis=1) + 1.0
    mean = (rgb * weights[:, None]).sum(axis=0) / weights.sum()
    return "#%02x%02x%02x" % tuple(int(v) for v in mean)


NEON_SIGNS = ["AQUACORP", "ORGAN FUTURES", "SYNDICATE LIFE", "LIVE FROM THE PIT"]


def neon_atlas() -> Image.Image:
    from PIL import ImageFont
    font_path = ROOT / "assets" / "fonts" / "Oswald-Latin.ttf"
    core = Image.new("L", (1024, 512))
    for row, text in enumerate(NEON_SIGNS):
        cell = Image.new("L", (1024, 128))
        size = 96
        font = ImageFont.truetype(str(font_path), size)
        try:
            font.set_variation_by_axes([300])  # a thin weight reads as bent glass tube
        except Exception:
            pass
        while font.getlength(text) > 940:
            size -= 4
            font = ImageFont.truetype(str(font_path), size)
            try:
                font.set_variation_by_axes([300])
            except Exception:
                pass
        ImageDraw.Draw(cell).text((512, 64), text, font=font, fill=255, anchor="mm")
        # Tubes: keep only the outline of each glyph, like glass bent along the letter's edge.
        outline = Image.fromarray(np.clip(np.asarray(cell.filter(ImageFilter.MaxFilter(5)), np.int16) - np.asarray(cell.filter(ImageFilter.MinFilter(5)), np.int16), 0, 255).astype(np.uint8))
        ImageDraw.Draw(outline).rectangle([6, 6, 1017, 121], outline=160, width=3)  # the sign's frame tube
        core.paste(outline, (0, row * 128))
    glow = core.filter(ImageFilter.GaussianBlur(9))
    glow = Image.fromarray(np.clip(np.asarray(glow, np.float32) * 2.2, 0, 255).astype(np.uint8))
    # Drawn at 1024 × 512 for clean tubes, shipped at half: a sign is 16 m wide, so that's still ~3 cm per texel (X6).
    return Image.merge("RGB", (core, glow, Image.new("L", core.size))).resize((512, 256), Image.LANCZOS)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    playlist = []
    painted = {}
    for ad in ADS:
        art = ad["art"]
        if art not in painted:
            painted[art] = PAINTERS[art]()
            # Stills ship at half size (256 × 512): the feed is 320 × 640 at most and the screen blurs them anyway (X6).
            shipped = painted[art] if ad.get("frames") else painted[art].resize((W // 2, H // 2), Image.LANCZOS)
            shipped.save(OUT / f"{art}.png", optimize=True)
        image = painted[art]
        entry = {"id": ad["id"], "kind": ad.get("kind", "still"), "image": f"res://game/theme/arena_kit/ads/{art}.png",
                 "frames": ad.get("frames", [1, 1]), "fps": ad.get("fps", 0), "seconds": ad["seconds"],
                 "brand": ad["brand"], "headline": ad["headline"], "fine_print": ad["fine_print"], "accent": ad["accent"],
                 "average_color": average_color(image, ad.get("frames"))}
        playlist.append(entry)
        print(f"ads: {ad['id']:<24} {(OUT / (art + '.png')).stat().st_size / 1024:.0f} KB  light {entry['average_color']}")
    neon_atlas().save(OUT / "neon_signs.png", optimize=True)
    print(f"ads: neon_signs       {(OUT / 'neon_signs.png').stat().st_size / 1024:.0f} KB")
    (OUT / "ads.json").write_text(json.dumps({"placeholder": False, "note": "Copy: the lead's approved screen ads "
                                              "(assets/announcer/drafts/ad_copy.md). Art: tools/assets/build_ads.py.", "ads": playlist}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
