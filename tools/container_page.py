#!/usr/bin/env python3
"""The lead's container page (yard, round 17, Y5): every dealt map at his pose, square (the launch tree) against turned
(the tree under review), with a tap per map -- looks right / too much / too little -- kept in the page's `db`.

Usage: python3 tools/container_page.py --before DIR --after DIR --out DIR [--commit SHA]
  DIR holds `make container-frames` output (<arena>_<spot>_<tag>.jpg). Writes OUT/index.html and OUT/frames/*.jpg
  (downscaled to 1440 px wide). Publish OUT/index.html with OUT/frames as supporting files."""
import argparse
import html
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import container_census  # noqa: E402
import gdscript_source  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TITLES = {"yard": "The Container Yard", "pit": "The Pit", "terminus": "The Terminus", "crossing": "The Crossing",
          "sumps": "The Sumps", "locks": "The Locks"}
LABELS = {"opening": "Where the match puts your camera", "west_stacks": "West stacks", "east_stacks": "East stacks",
          "close_stacks": "Close: a two-high run", "ring": "The ring", "gate": "A gate", "close_diagonal":
          "Close: a three-high wall", "avenue": "The avenue", "west": "West", "close_kerb": "Close: a stack against a building",
          "centre": "Centre", "east": "East", "middle": "Middle", "east_quay": "East quay", "south": "South"}
CLOSE = ("close_stacks", "close_diagonal", "close_kerb")


def frames(directory, tag):
    out = {}
    for name in sorted(os.listdir(directory)):
        if name.endswith("_%s.jpg" % tag):
            stem = name[: -len("_%s.jpg" % tag)]
            arena, spot = stem.split("_", 1) if stem.split("_", 1)[0] in TITLES else (None, None)
            if arena:
                out[(arena, spot)] = os.path.join(directory, name)
    return out


def shrink(src, dst, width=1440):
    from PIL import Image
    with Image.open(src) as im:
        h = round(im.height * width / im.width)
        im.convert("RGB").resize((width, h), Image.LANCZOS).save(dst, "JPEG", quality=82, optimize=True)


def counts(arena):
    """Per map: containers, how many the turn moved off their authored angle (against the frozen square layout), how
    many stay parallel to a building by rule, and the turn's mean and largest size."""
    with open(os.path.join(ROOT, "arenas", arena + ".json")) as f:
        layout = json.load(f)
    with open(os.path.join(ROOT, "tests", "arena", "before", "square", arena + ".json")) as f:
        square = json.load(f)
    turns, walls = [], 0
    for now, was in zip(layout.get("props", []), square.get("props", [])):
        if now.get("type") not in container_census.KINDS:
            continue
        turn = abs((float(now.get("rotation_deg", 0)) - float(was.get("rotation_deg", 0)) + 180.0) % 360.0 - 180.0)
        turns.append(turn)
        walls += 1 if "wall" in now else 0
    moved = [t for t in turns if t > 0.01]
    return {"total": len(turns), "turned": len(moved), "against_wall": walls,
            "mean_off": sum(moved) / len(moved) if moved else 0.0, "max_off": max(moved) if moved else 0.0}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--after", required=True)
    ap.add_argument("--strong", help="frames of direction B (<arena>_<spot>_strong.jpg)")
    ap.add_argument("--strong-ground", type=float, default=4.0)
    ap.add_argument("--strong-stack", type=float, default=0.45)
    ap.add_argument("--square-stacks", default="", help="comma list arena_spot whose BEFORE is the frozen square layout on today's code")
    ap.add_argument("--out", required=True)
    ap.add_argument("--commit", default="")
    ap.add_argument("--before-commit", default="3713fdaa")
    args = ap.parse_args()
    prop = gdscript_source.GAME / "theme" / "arena_kit" / "containers" / "container_prop.gd"
    amounts = {"ground_deg": gdscript_source.const_float(prop, "GROUND_SKEW_DEG"),
               "scale_20": gdscript_source.const_float(prop, "GROUND_SKEW_20_SCALE"),
               "stack_m": gdscript_source.const_float(prop, "STACK_OFFSET_M")}
    before, after = frames(args.before, "before"), frames(args.after, "after")
    strong = frames(args.strong, "strong") if args.strong else {}
    amounts["strong_ground_deg"], amounts["strong_stack_m"] = args.strong_ground, args.strong_stack
    square_stacks = set(x for x in args.square_stacks.split(",") if x)
    os.makedirs(os.path.join(args.out, "frames"), exist_ok=True)
    maps = []
    for arena in TITLES:
        shots = []
        for (a, spot), path in sorted(after.items(), key=lambda kv: (kv[0][1] in CLOSE, kv[0][1] != "opening")):
            if a != arena:
                continue
            item = {"spot": spot, "label": LABELS.get(spot, spot.replace("_", " ")), "close": spot in CLOSE,
                    "after": "frames/%s_%s_after.jpg" % (arena, spot)}
            shrink(path, os.path.join(args.out, item["after"]))
            if (arena, spot) in before:
                item["before"] = "frames/%s_%s_before.jpg" % (arena, spot)
                shrink(before[(arena, spot)], os.path.join(args.out, item["before"]))
                item["before_note"] = "rebuilt from the square layout" if "%s_%s" % (arena, spot) in square_stacks else ""
            if (arena, spot) in strong:
                item["strong"] = "frames/%s_%s_strong.jpg" % (arena, spot)
                shrink(strong[(arena, spot)], os.path.join(args.out, item["strong"]))
            shots.append(item)
        maps.append({"key": arena, "title": TITLES[arena], "counts": counts(arena), "shots": shots})
    data = {"amounts": amounts, "maps": maps, "commit": args.commit, "before_commit": args.before_commit}
    template = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "container_page.html")).read()
    page = template.replace("/*DATA*/null", json.dumps(data))
    with open(os.path.join(args.out, "index.html"), "w") as f:
        f.write(page)
    print("CONTAINER_PAGE %s: %d maps, %d frames" % (os.path.join(args.out, "index.html"), len(maps),
                                                     sum(len(m["shots"]) for m in maps)))


if __name__ == "__main__":
    main()
