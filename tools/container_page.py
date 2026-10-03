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
    """Turned / parallel to a building / total containers, from the layout the frames were taken on."""
    with open(os.path.join(ROOT, "arenas", arena + ".json")) as f:
        layout = json.load(f)
    row = container_census.census(layout)
    walls = sum(1 for p in layout.get("props", []) if p.get("type") in container_census.KINDS and "wall" in p)
    return {"total": row["containers"], "turned": row["containers"] - row["square"], "square": row["square"],
            "against_wall": walls, "mean_off": row["mean_off_deg"], "max_off": row["max_off_deg"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--after", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--commit", default="")
    ap.add_argument("--before-commit", default="3713fdaa")
    args = ap.parse_args()
    prop = gdscript_source.GAME / "theme" / "arena_kit" / "containers" / "container_prop.gd"
    amounts = {"ground_deg": gdscript_source.const_float(prop, "GROUND_SKEW_DEG"),
               "scale_20": gdscript_source.const_float(prop, "GROUND_SKEW_20_SCALE"),
               "stack_m": gdscript_source.const_float(prop, "STACK_OFFSET_M")}
    before, after = frames(args.before, "before"), frames(args.after, "after")
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
