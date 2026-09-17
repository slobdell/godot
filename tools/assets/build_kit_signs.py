#!/usr/bin/env python3
"""Render (round 5, arena's prop.sign): neon tube signs naming the arena, for signs on posts that layouts place.
Same tube look and packing as the grandstand signs (build_ads.py neon_atlas: R = tube core, G = glow), one row per name,
written to game/theme/arena_kit/kit/kit_signs.png. KitYard.SIGN_CELLS must list the names in this order."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/theme/arena_kit/kit/kit_signs.png"
NAMES = ["BONEYARD", "BOULEVARD", "THE PIT", "THE YARD", "FOUNDRY", "FURNACE", "SCRAPYARD", "DEATH RACE"]
CELL_W, CELL_H = 1024, 256


def font(size: int) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(str(ROOT / "assets/fonts/Oswald-Latin.ttf"), size)
    try:
        face.set_variation_by_axes([300])
    except Exception:
        pass
    return face


def main() -> None:
    core = Image.new("L", (CELL_W, CELL_H * len(NAMES)))
    for row, text in enumerate(NAMES):
        cell = Image.new("L", (CELL_W, CELL_H))
        size = 190
        face = font(size)
        while face.getlength(text) > 900:
            size -= 6
            face = font(size)
        ImageDraw.Draw(cell).text((CELL_W // 2, CELL_H // 2), text, font=face, fill=255, anchor="mm")
        edges = np.clip(np.asarray(cell.filter(ImageFilter.MaxFilter(7)), np.int16) - np.asarray(cell.filter(ImageFilter.MinFilter(7)), np.int16), 0, 255)
        outline = Image.fromarray(edges.astype(np.uint8))
        ImageDraw.Draw(outline).rectangle([10, 10, CELL_W - 11, CELL_H - 11], outline=170, width=5)
        core.paste(outline, (0, row * CELL_H))
    glow = core.filter(ImageFilter.GaussianBlur(14))
    glow = Image.fromarray(np.clip(np.asarray(glow, np.float32) * 2.2, 0, 255).astype(np.uint8))
    image = Image.merge("RGB", (core, glow, Image.new("L", core.size))).resize((CELL_W // 2, CELL_H * len(NAMES) // 2), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT, optimize=True)
    print(f"kit signs: {len(NAMES)} names, {OUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
