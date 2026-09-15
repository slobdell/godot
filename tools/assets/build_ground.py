#!/usr/bin/env python3
"""The cyberpunk arena floor's texture set (art X3), rebuilt deterministically from CC0 sources.

    make assets-ground          (downloads the ambientCG sets into assets/incoming/ambientcg/ if missing)

Sources (ambientCG, "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License",
https://docs.ambientcg.com/license/, checked 2026-09-14):
    Asphalt027C  cracked asphalt: the base surface
    Concrete047B concrete with a rusty drain grate: the grate is cut out and scattered by the shader

Outputs (game/theme/cyberpunk/ground/), sized for the web budget (Basis above 256 px, streams/references/asset_budget.md):
    asphalt_albedo_rough.png  1024  RGB albedo, A roughness
    ground_detail.png          512  R tire-mark mask, G oil-stain mask, B coarse noise, A fine noise (all tileable,
                                    procedural, seeded): the shader reads noise here instead of computing it per pixel
    drain.png                  256  RGB grate, A coverage
    arena_macro.png            512  the whole 320 m floor once (0.6 m/px): RGB = albedo multiplier ÷ 1.5 (weathering,
                                    concrete slab tint, oil), A = gloss (oil). Baked here so the shader fetches one
                                    texture instead of several noise and mask samples per pixel (art X2 fx-bench)
"""

import io
import math
import random
import sys
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets" / "incoming" / "ambientcg"
OUT = ROOT / "game" / "theme" / "cyberpunk" / "ground"
SOURCES = ["Asphalt027C", "Concrete047B"]


def fetch(asset: str) -> Path:
    folder = INCOMING / asset
    if not any(folder.glob("*_Color.jpg")):
        url = f"https://ambientcg.com/get?file={asset}_1K-JPG.zip"
        print(f"downloading {url}")
        with urllib.request.urlopen(url, timeout=120) as response:
            zipfile.ZipFile(io.BytesIO(response.read())).extractall(folder)
    return folder


def map_of(folder: Path, kind: str) -> Image.Image:
    return Image.open(next(folder.glob(f"*_{kind}.jpg")))


def albedo_rough(folder: Path, size: int) -> Image.Image:
    color = map_of(folder, "Color").convert("RGB").resize((size, size), Image.LANCZOS)
    rough = map_of(folder, "Roughness").convert("L").resize((size, size), Image.LANCZOS)
    packed = color.copy()
    packed.putalpha(rough)
    return packed


def tileable_noise(size: int, cells: int, rng: random.Random) -> Image.Image:
    """Smooth value noise that wraps (a random grid upscaled with wrap-around bicubic interpolation)."""
    grid = Image.new("L", (cells, cells))
    grid.putdata([rng.randrange(256) for _ in range(cells * cells)])
    tiled = Image.new("L", (cells * 3, cells * 3))
    for x in range(3):
        for y in range(3):
            tiled.paste(grid, (x * cells, y * cells))
    big = tiled.resize((size * 3, size * 3), Image.BICUBIC)
    return big.crop((size, size, size * 2, size * 2))


def tire_marks(size: int, rng: random.Random) -> Image.Image:
    """Skid arcs and straight runs drawn 3× over a wrapped canvas so the tile has no seams."""
    canvas = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(canvas)
    for _ in range(9):
        cx, cy = rng.uniform(0, size), rng.uniform(0, size)
        radius = rng.uniform(size * 0.2, size * 0.9)
        start = rng.uniform(0, 360)
        sweep = rng.uniform(25, 80)
        width = rng.randint(7, 12)
        strength = rng.randint(90, 200)
        gap = width * 1.9  # a vehicle leaves two parallel tracks
        for track in (0.0, gap):
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    r = radius + track
                    box = [cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r]
                    draw.arc(box, start, start + sweep, fill=strength, width=width)
    # Tread texture: break the marks up with fine noise, then soften the edges.
    grain = tileable_noise(size, 96, rng)
    marks = Image.composite(canvas, Image.new("L", (size, size), 0), grain.point(lambda v: 255 if v > 70 else 120))
    return marks.filter(ImageFilter.GaussianBlur(1.2))


def oil_stains(size: int, rng: random.Random) -> Image.Image:
    blobs = tileable_noise(size, 6, rng)
    detail = tileable_noise(size, 24, rng)
    mixed = Image.blend(blobs, detail, 0.35)
    return mixed.point(lambda v: max(0, min(255, (v - 150) * 5)))


def arena_macro(size: int, rng: random.Random) -> Image.Image:
    import numpy as np
    def noise(cells: int) -> "np.ndarray":
        return np.asarray(tileable_noise(size, cells, rng), dtype=np.float32) / 255.0
    def smooth(edge0: float, edge1: float, x):
        t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    macro = noise(9) * 0.7 + noise(29) * 0.3
    # Concrete comes in rectangular slabs: snap the patch mask to an 8×12 px (≈5 × 7.5 m) slab grid.
    cells = macro[4::8, 6::12]
    slab = np.repeat(np.repeat(smooth(0.67, 0.7, cells), 8, axis=0), 12, axis=1)[:size, :size]
    slab = np.pad(slab, ((0, size - slab.shape[0]), (0, size - slab.shape[1])), mode="edge")
    weathering = 0.78 + 0.3 * noise(17)
    oil = smooth(0.62, 0.9, noise(40)) * smooth(0.45, 0.7, noise(7)) * 0.4
    concrete = np.array([1.2, 1.16, 1.09], dtype=np.float32)  # lighter, warmer slabs over the dark asphalt
    rgb = weathering[..., None] * (1.0 + slab[..., None] * (concrete - 1.0)) * (1.0 - oil[..., None] * 0.7)
    out = np.dstack([np.clip(rgb / 1.5, 0, 1), np.clip(oil * 2.0, 0, 1)])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def drain(folder: Path) -> Image.Image:
    color = map_of(folder, "Color").convert("RGB")
    grate = color.crop((374, 367, 656, 655)).resize((256, 256), Image.LANCZOS)
    rgba = grate.copy()
    mask = Image.new("L", (256, 256), 0)
    ImageDraw.Draw(mask).rectangle([6, 6, 249, 249], fill=255)
    rgba.putalpha(mask.filter(ImageFilter.GaussianBlur(2)))
    return rgba


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    folders = {asset: fetch(asset) for asset in SOURCES}
    rng = random.Random(20260914)
    albedo_rough(folders["Asphalt027C"], 1024).save(OUT / "asphalt_albedo_rough.png")
    detail = Image.merge("RGBA", (tire_marks(512, rng), oil_stains(512, rng), tileable_noise(512, 8, rng), tileable_noise(512, 48, rng)))
    detail.save(OUT / "ground_detail.png")
    drain(folders["Concrete047B"]).save(OUT / "drain.png")
    arena_macro(512, random.Random(1409)).save(OUT / "arena_macro.png")
    for file in sorted(OUT.glob("*.png")):
        print(f"{file.relative_to(ROOT)}  {Image.open(file).size[0]} px  {file.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
