#!/usr/bin/env python3
"""The shipping containers' one shared texture set (assets X1), rebuilt deterministically.

    make assets-containers        (downloads the ambientCG sets into assets/incoming/ambientcg/ if missing)

Sources (ambientCG, "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License",
https://docs.ambientcg.com/license/, checked 2026-09-15):
    Rust009          rust albedo and roughness
    PaintedMetal006  chipped green paint over rust: its chip pattern becomes the erosion order
Font: Share Tech Mono (SIL Open Font License, assets/fonts/ShareTechMono-OFL.txt) for the stencils.

Outputs (game/theme/arena_kit/containers/), one set for every container of every kind, varied per instance in
container.gdshader. Texture space is meters: one tile = TILE_M (2.4 m) on every face, so 20 ft and 40 ft containers
share the same texel density.
    container_surface.png  512   RGB rust albedo, A = erosion order (low values lose their paint first; the shader
                                 thresholds it by the instance's rust amount)
    container_detail.png   512   RG = corrugation + dent normal (tangent space x, y), B = grime streak mask,
                                 A = paint mottling
    container_stencils.png 1024×512  RGBA atlas, 2 columns × 4 rows of 512×128 cells (4.8 × 1.2 m on the side):
                                 colored stencils with worn coverage in A (STENCILS below, in shader order)
"""

import io
import math
import random
import sys
import urllib.request
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "assets" / "incoming" / "ambientcg"
OUT = ROOT / "game" / "theme" / "arena_kit" / "containers"
FONT = ROOT / "assets" / "fonts" / "ShareTechMono-Regular.ttf"
SIZE = 512
TILE_M = 2.4
## ISO side corrugation: 8 trapezoid cycles per 2.4 m tile (0.3 m pitch), 36 mm deep.
CYCLES = 8
DEPTH_M = 0.036
## Atlas cells in shader order (container.gdshader STENCIL_*). Fictional owners only; the dystopia leaks through a
## slightly wrong detail, never a joke (game_design.md, humor direction).
STENCILS = [
    {"id": "code", "lines": [], "color": (230, 228, 220)},
    {"id": "prison", "lines": ["PRISON TRANSPORT", "INMATE CARGO  04-117"], "color": (232, 230, 222)},
    {"id": "evidence", "lines": ["EVIDENCE", "DO NOT OPEN  CASE 88-2041"], "color": (236, 236, 236)},
    {"id": "impound", "lines": ["IMPOUND LOT 7", "PROPERTY OF THE WARDEN"], "color": (240, 196, 40)},
    {"id": "aquacorp", "lines": ["AQUACORP", "POTABLE RESERVE  AUTHORIZED ONLY"], "color": (236, 232, 218), "logo": "drop"},
    {"id": "organ_futures", "lines": ["ORGAN FUTURES", "LOGISTICS  KEEP BELOW 4°C"], "color": (214, 190, 120), "logo": "ring"},
    {"id": "gang_tag", "lines": ["WRECKERS"], "color": (255, 88, 30), "tag": True},
    {"id": "hazard", "lines": ["DETENTION STORAGE"], "color": (236, 200, 40), "hazard": True},
]
CELL_W, CELL_H = 512, 128


def fetch(asset: str) -> Path:
    folder = INCOMING / asset
    if not any(folder.glob("*_Color.jpg")):
        url = f"https://ambientcg.com/get?file={asset}_1K-JPG.zip"
        print(f"downloading {url}")
        with urllib.request.urlopen(url, timeout=120) as response:
            zipfile.ZipFile(io.BytesIO(response.read())).extractall(folder)
    return folder


def load(folder: Path, kind: str, mode: str) -> np.ndarray:
    image = Image.open(next(folder.glob(f"*_{kind}.jpg"))).convert(mode).resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(image, dtype=np.float32) / 255.0


def tileable_noise(cells: int, rng: random.Random) -> np.ndarray:
    grid = Image.new("L", (cells, cells))
    grid.putdata([rng.randrange(256) for _ in range(cells * cells)])
    tiled = Image.new("L", (cells * 3, cells * 3))
    for x in range(3):
        for y in range(3):
            tiled.paste(grid, (x * cells, y * cells))
    big = tiled.resize((SIZE * 3, SIZE * 3), Image.BICUBIC).crop((SIZE, SIZE, SIZE * 2, SIZE * 2))
    return np.asarray(big, dtype=np.float32) / 255.0


def wrap_blur(field: np.ndarray, radius: float) -> np.ndarray:
    """Gaussian blur that wraps around the tile edges (blur a 3×3 tiling, keep the middle)."""
    tiled = np.tile(field, (3, 3))
    image = Image.fromarray(np.clip(tiled * 255, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(radius))
    return (np.asarray(image, dtype=np.float32) / 255.0)[SIZE:SIZE * 2, SIZE:SIZE * 2]


def surface(rust: Path, painted: Path, rng: random.Random) -> Image.Image:
    rust_rgb = load(rust, "Color", "RGB")
    # PaintedMetal006 is green paint chipped down to rust: how far a texel is from the paint color says whether it
    # has already chipped. Blurred and mixed with noise, that becomes a smooth erosion order with chip-shaped edges.
    color = load(painted, "Color", "RGB")
    paint = np.median(color.reshape(-1, 3)[color.reshape(-1, 3)[:, 1] > color.reshape(-1, 3)[:, 0] + 0.1], axis=0)
    chipped = np.clip(np.linalg.norm(color - paint, axis=2) * 2.2, 0.0, 1.0)
    intact = 1.0 - chipped
    order = 0.45 * wrap_blur(intact, 10) + 0.25 * intact + 0.3 * tileable_noise(6, rng)
    order = (order - order.min()) / (order.max() - order.min())
    rgba = np.dstack([rust_rgb, order])
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


def detail(rng: random.Random) -> Image.Image:
    u = (np.arange(SIZE, dtype=np.float32) + 0.5) / SIZE * CYCLES % 1.0
    # One cycle: outer flat 0.37, falling web 0.13, inner flat 0.37, rising web 0.13 (fractions of 0.3 m).
    height = np.interp(u, [0.0, 0.37, 0.5, 0.87, 1.0], [1.0, 1.0, 0.0, 0.0, 1.0]) * DEPTH_M
    slope = np.gradient(np.tile(height, 3), TILE_M / SIZE)[SIZE:SIZE * 2]
    dents = wrap_blur(tileable_noise(20, rng), 6) - 0.5
    dy, dx = np.gradient(np.tile(dents, (3, 3)) * 0.03, TILE_M / SIZE)
    nx = -slope[None, :] - dx[SIZE:SIZE * 2, SIZE:SIZE * 2]
    ny = -dy[SIZE:SIZE * 2, SIZE:SIZE * 2]
    length = np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny = nx / length, ny / length
    # Grime runs down from the roof rail in thin vertical streaks, stronger in the corrugation valleys.
    columns = tileable_noise(64, rng)[0]
    streak = np.clip((np.tile(columns, (SIZE, 1)) - 0.45) * 2.0, 0.0, 1.0)
    streak *= 0.55 + 0.45 * tileable_noise(4, rng)
    streak *= 0.7 + 0.3 * (1.0 - height[None, :] / DEPTH_M)
    mottle = 0.5 + (tileable_noise(12, rng) - 0.5) * 0.6 + (tileable_noise(70, rng) - 0.5) * 0.25
    rgba = np.dstack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, streak, np.clip(mottle, 0, 1)])
    return Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA")


def stencils(rng: random.Random) -> Image.Image:
    atlas = Image.new("RGBA", (CELL_W * 2, CELL_H * 4), (0, 0, 0, 0))
    small = ImageFont.truetype(str(FONT), 22)
    for index, stencil in enumerate(STENCILS):
        cell = Image.new("L", (CELL_W, CELL_H), 0)
        draw = ImageDraw.Draw(cell)
        code = f"TSQU {rng.randrange(100000, 999999)} {rng.randrange(10)}  22G1"
        draw.text((CELL_W - 12, 116), code, font=ImageFont.truetype(str(FONT), 17), fill=235, anchor="rs")
        lines = stencil["lines"]
        if stencil.get("hazard"):
            stripes = Image.new("L", (CELL_W * 2, 26), 0)
            sd = ImageDraw.Draw(stripes)
            for x in range(-40, CELL_W * 2, 34):
                sd.polygon([(x, 26), (x + 17, 26), (x + 43, 0), (x + 26, 0)], fill=255)
            cell.paste(stripes.crop((0, 0, CELL_W - 24, 22)), (12, 72))
        if stencil.get("tag"):
            tag = Image.new("L", (CELL_W, CELL_H), 0)
            td = ImageDraw.Draw(tag)
            x = 70
            for ch in lines[0]:
                glyph = Image.new("L", (80, 100), 0)
                ImageDraw.Draw(glyph).text((40, 50), ch, font=ImageFont.truetype(str(FONT), 64), fill=255, anchor="mm",
                                           stroke_width=4, stroke_fill=255)
                glyph = glyph.rotate(rng.uniform(-14, 14), resample=Image.BICUBIC)
                tag.paste(glyph, (x - 40, 4 + rng.randint(-5, 5)), glyph)
                x += 44
            for _ in range(9):  # drips
                dx = rng.randint(80, x - 40)
                td.line([(dx, 66), (dx, 66 + rng.randint(10, 30))], fill=220, width=3)
            td.arc([30, 6, 460, 96], 195, 335, fill=255, width=5)
            cell = Image.fromarray(np.maximum(np.asarray(cell), np.asarray(tag.filter(ImageFilter.GaussianBlur(1.1)))))
        elif lines:
            logo = stencil.get("logo")
            left = 16
            if logo:
                d = ImageDraw.Draw(cell)
                if logo == "drop":
                    d.ellipse([18, 36, 66, 84], fill=255)
                    d.polygon([(21, 54), (42, 12), (63, 54)], fill=255)
                    d.ellipse([32, 50, 52, 70], fill=0)
                else:
                    d.ellipse([16, 18, 72, 74], outline=255, width=8)
                    d.ellipse([36, 38, 52, 54], fill=255)
                left = 86
            room = CELL_W - left - 16
            size = 56
            while ImageFont.truetype(str(FONT), size).getlength(lines[0]) > room:
                size -= 2
            draw.text((left, 32), lines[0], font=ImageFont.truetype(str(FONT), size), fill=255, anchor="lm",
                      stroke_width=1, stroke_fill=255)
            if len(lines) > 1:
                draw.text((left + 2, 76), lines[1], font=small, fill=255, anchor="lm", stroke_width=1, stroke_fill=255)
        # Worn: sprayed through a stencil years ago, then scraped by forklifts.
        coverage = np.asarray(cell, dtype=np.float32) / 255.0
        wear = np.asarray(Image.fromarray((np.random.default_rng(index).random((CELL_H // 16, CELL_W // 16)) * 255).astype(np.uint8))
                          .resize((CELL_W, CELL_H), Image.BICUBIC), dtype=np.float32) / 255.0
        fine = np.asarray(Image.fromarray((np.random.default_rng(index + 50).random((CELL_H // 3, CELL_W // 3)) * 255).astype(np.uint8)).resize((CELL_W, CELL_H), Image.BICUBIC), dtype=np.float32) / 255.0
        coverage *= np.clip((wear * 0.7 + fine * 0.3 - 0.22) * 4.0, 0.0, 1.0) * 0.92
        rgba = np.zeros((CELL_H, CELL_W, 4), dtype=np.float32)
        rgba[..., :3] = np.array(stencil["color"], dtype=np.float32) / 255.0
        rgba[..., 3] = coverage
        cell_image = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
        atlas.paste(cell_image, ((index % 2) * CELL_W, (index // 2) * CELL_H))
    return atlas


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rust, painted = fetch("Rust009"), fetch("PaintedMetal006")
    surface(rust, painted, random.Random(9)).save(OUT / "container_surface.png")
    detail(random.Random(20)).save(OUT / "container_detail.png")
    stencils(random.Random(40)).save(OUT / "container_stencils.png")
    for name in ("container_surface.png", "container_detail.png", "container_stencils.png"):
        print(f"containers: {OUT / name} ({(OUT / name).stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
