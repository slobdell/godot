#!/usr/bin/env python3
"""Contact sheet for `make class-look` (fleet, round 15, F1): one row per pair, one column per heading, each cell the
pair's lit crops side by side at the pixels HE sees them at (no scaling), each outlined from its own silhouette mask in
its own colour (first unit yellow, second cyan), the pair's centred silhouette IoU under it.

    tools/assets/class_look_sheet.py build/class-look          # every <size>/ under it -> <size>/sheet.png

PIL only (builder0 has no numpy). Reads the CLASS_LOOK lines from each <size>/log.txt.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUTLINES = [(255, 220, 0), (0, 240, 255), (255, 80, 200)]
PAD = 12
LABEL_H = 34


def read_rows(log: Path):
    rows, pairs = [], []
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("CLASS_LOOK "):
            rows.append(json.loads(line[len("CLASS_LOOK "):]))
        elif line.startswith("CLASS_LOOK_PAIR "):
            pairs.append(json.loads(line[len("CLASS_LOOK_PAIR "):]))
    return rows, pairs


def outlined(lit_path: Path, mask_path: Path, colour) -> Image.Image:
    lit = Image.open(lit_path).convert("RGB")
    mask = Image.open(mask_path).convert("L")
    w, h = mask.size
    m = mask.load()
    px = lit.load()
    inside = [[m[x, y] > 127 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if not inside[y][x]:
                continue
            edge = x == 0 or y == 0 or x == w - 1 or y == h - 1 or not (
                inside[y][x - 1] and inside[y][x + 1] and inside[y - 1][x] and inside[y + 1][x])
            if edge:
                px[x, y] = colour
    return lit


def font(size):
    for name in ("DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(size_dir: Path) -> Path | None:
    log = size_dir / "log.txt"
    if not log.exists():
        return None
    rows, pairs = read_rows(log)
    if not rows:
        return None
    headings = []
    for row in rows:
        if row["heading"] not in headings:
            headings.append(row["heading"])
    pair_keys = []
    for row in rows:
        key = tuple(row["pair"])
        if key not in pair_keys:
            pair_keys.append(key)
    cells = {}
    for row in rows:
        key = tuple(row["pair"])
        images = []
        for i, unit in enumerate(key):
            lit = size_dir / f"{unit}_{row['heading']}.png"
            mask = size_dir / f"{unit}_{row['heading']}_mask.png"
            if lit.exists() and mask.exists():
                images.append(outlined(lit, mask, OUTLINES[i % len(OUTLINES)]))
        iou = next((v for k, v in row.items() if k.startswith("iou_")), None)
        cells[(key, row["heading"])] = (images, iou)
    col_w = {h: max((sum(im.width for im in cells[(k, h)][0]) + PAD * (len(cells[(k, h)][0]) - 1)
                     for k in pair_keys if (k, h) in cells), default=50) + PAD for h in headings}
    row_h = {k: max((max((im.height for im in cells[(k, h)][0]), default=20)
                     for h in headings if (k, h) in cells), default=20) + 2 * LABEL_H for k in pair_keys}
    left = 330
    width = left + sum(col_w.values()) + PAD
    height = LABEL_H + sum(row_h.values()) + PAD
    out = Image.new("RGB", (width, height), (24, 24, 28))
    draw = ImageDraw.Draw(out)
    big, small = font(20), font(16)
    x = left
    for h in headings:
        draw.text((x, 6), h.replace("_", " "), fill=(230, 230, 230), font=big)
        x += col_w[h]
    by_pair = {tuple(p["pair"]): p for p in pairs}
    y = LABEL_H
    for k in pair_keys:
        p = by_pair.get(k, {})
        names = "  vs  ".join(k)
        draw.text((PAD, y + 4), names, fill=(255, 255, 255), font=big)
        draw.text((PAD, y + 30), "yellow = %s, cyan = %s" % (k[0], k[1] if len(k) > 1 else "-"),
                  fill=(200, 200, 200), font=small)
        lengths = p.get("drawn_length_m", {})
        draw.text((PAD, y + 52), "drawn length " + " / ".join("%.2f" % lengths.get(u, 0) for u in k) + " m",
                  fill=(200, 200, 200), font=small)
        draw.text((PAD, y + 74), "IoU mean %.2f  max %.2f" % (p.get("iou_mean", 0), p.get("iou_max", 0)),
                  fill=(255, 220, 120), font=small)
        x = left
        for h in headings:
            images, iou = cells.get((k, h), ([], None))
            cx = x
            for im in images:
                out.paste(im, (cx, y + LABEL_H))
                cx += im.width + PAD
            if iou is not None:
                draw.text((x, y + LABEL_H + row_h[k] - 2 * LABEL_H + 6), "IoU %.2f" % iou, fill=(255, 220, 120),
                          font=small)
            x += col_w[h]
        y += row_h[k]
    path = size_dir / "sheet.png"
    out.save(path)
    return path


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else "build/class-look")
    made = [sheet(d) for d in sorted(root.iterdir()) if d.is_dir()]
    for path in made:
        if path:
            print("CLASS_LOOK_SHEET", path)
    return 0 if any(made) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
