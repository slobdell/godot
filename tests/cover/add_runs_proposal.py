#!/usr/bin/env python3
"""K5 option (b) (cover, round 37): a DRAFT of short jersey-barrier runs ADDED in the hottest streets of the maps where the
fighting is most concentrated -- for the lead's before/after page; nothing applied, nothing committed to arenas/.

    python3 tests/cover/add_runs_proposal.py <heat.json> <out_dir> [--maps crossing,sumps,locks,gorge] [--runs 2]

A RUN is RUN_PIECES barricades end to end (12 m), its long side square to the base axis (a crew behind it faces the enemy's
half), and its 180-degree mirror (layouts are point-symmetric). Where: the centre of a hot 10 m cell (hits summed over the cell
and its mirror), nudged on a 2 m grid within the cell, kept only if the run grown by CLEAR_M touches nothing that collides,
no water or pit, stays MID_Z_MAX from the base lines (out of the spawn ends) and MIN_APART_M from another run, and every
lane keeps its R4 drivable width and the map keeps arena_room's reads (keeps_shape: the arena tests pin them). Up to `--runs`
mirrored pairs a map, hottest first. Default maps: the four whose top four cell pairs hold >= 20 % of the hull hits (heat at
5b4e79362): crossing 0.28, sumps 0.27, locks 0.20, gorge 0.20.
"""
import argparse, copy, html, json, math, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import cover_page  # noqa: E402
import arena_terrain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RUN_PIECES = 2
PIECE_M = 6.0
## Room a hull needs to pass the run's ends and sides (the widest hull is 4.07 m).
CLEAR_M = 5.0
MID_Z_MAX = 80.0
MIN_APART_M = 20.0
HEAT_RADIUS_M = 12.0
## A run must leave the map's shape as it was (keeps_shape); the room's line share may fall this much (the run is ground
## a line cannot stand on), no more. The SITES_TRIED hottest sites of a hot cell are tried, hottest first.
LINE_SHARE_SLACK = 0.02
SITES_TRIED = 8
## "all": the above. "lanes": lane widths and the base-to-base ambush read only (what the arena tests pin as the map's
## design: his parade's crossing line, the Terminus's no-line centre); room and chokepoint counts may move.
KEEP = "all"
DEFAULT_MAPS = ["crossing", "sumps", "locks", "gorge"]


def boxes(layout):
    """Every colliding footprint as (centre, size [x, h, z], rotation_deg)."""
    out = []
    for o in layout.get("obstacles", []):
        out.append((o["position"], o.get("size", cover_page.OBSTACLE_SIZES.get(o["type"], [1, 1, 1])),
                    float(o.get("rotation_deg", 0.0))))
    for p in layout.get("props", []):
        if p["type"] in cover_page.KIT:
            out.append((p["position"], cover_page.KIT[p["type"]], float(p.get("rotation_deg", 0.0))))
    return out


def _overlap(a, b):
    """Separating-axis test on two convex quads [(x, z)]."""
    for quad in (a, b):
        for i in range(4):
            x0, z0 = quad[i]
            x1, z1 = quad[(i + 1) % 4]
            nx, nz = z0 - z1, x1 - x0
            pa = [nx * x + nz * z for x, z in a]
            pb = [nx * x + nz * z for x, z in b]
            if max(pa) < min(pb) or max(pb) < min(pa):
                return False
    return True


def run_quad(centre, grow):
    hx, hz = RUN_PIECES * PIECE_M / 2 + grow, 0.4 + grow
    x, z = centre
    return [(x + hx, z + hz), (x - hx, z + hz), (x - hx, z - hz), (x + hx, z - hz)]


def fits(layout, centre, half):
    x, z = centre
    if abs(z) > MID_Z_MAX or abs(x) + RUN_PIECES * PIECE_M / 2 + CLEAR_M > half - 4.0:
        return False
    grown = run_quad(centre, CLEAR_M)
    for pos, size, rot in boxes(layout):
        if _overlap(grown, cover_page.corners(pos, size, rot)):
            return False
    for t in layout.get("terrain", []):
        x0, z0, x1, z1 = arena_terrain.bounds(t)
        if _overlap(grown, [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]):
            return False
    return True


def lanes_ok(layout):
    """Names of the lanes that pass R4 on `layout` (terrain_measure, the generator's own measure)."""
    import terrain_measure
    return {lane["name"] for lane in terrain_measure.lanes_with_terrain(layout)
            if lane["pass"] and all(c["pass"] for c in lane["corners"])}


def with_run(layout, centre):
    after = copy.deepcopy(layout)
    x, z = centre
    for k in range(RUN_PIECES):
        offset = -RUN_PIECES * PIECE_M / 2 + PIECE_M * (k + 0.5)
        after["props"].append({"type": "barricade", "position": [x + offset, z], "rotation_deg": 0.0})
        after["props"].append({"type": "barricade", "position": [-x - offset, -z], "rotation_deg": 180.0})
    return after


def heat_near(cells, pos):
    return sum(count for key, count in cells.items()
               if math.hypot(int(key.split(",")[0]) * 10 + 5 - pos[0], int(key.split(",")[1]) * 10 + 5 - pos[1])
               <= HEAT_RADIUS_M)


def shape(layout):
    """What a run must not change: each lane's R4 drivable width and pass, and arena_room's room and ambush reads
    (tools/test_arena_room.py and test_arena_lanes.py pin these per map)."""
    import arena_room
    import terrain_measure
    lanes = {lane["name"]: (round(lane["drivable_m"], 2), lane["pass"] and all(c["pass"] for c in lane["corners"]))
             for lane in terrain_measure.lanes_with_terrain(layout)}
    m = arena_room.measure(layout, with_report=False)
    b = m["ambush"]["base_to_base"]
    return {"lanes": lanes, "stations": b["stations"], "hulls": b["hulls"], "chokepoints": len(m["chokepoints"]),
            "line_share": m["room"]["line_share"], "frontage": m["room"]["widest_frontage_m"]}


def keeps_shape(before, after):
    """'' or what the run changed. Lane widths and the ambush/chokepoint reads exactly; the room's line share within
    LINE_SHARE_SLACK and its widest frontage within 1 m."""
    for name, (width, ok) in before["lanes"].items():
        w, o = after["lanes"].get(name, (0.0, False))
        if w < width - 0.05 or (ok and not o):
            return f"lane {name} {width} -> {w} m"
    for key in ("stations", "hulls") + (() if KEEP == "lanes" else ("chokepoints",)):
        if after[key] != before[key]:
            return f"{key} {before[key]} -> {after[key]}"
    if KEEP == "lanes":
        return ""
    if after["line_share"] < before["line_share"] - LINE_SHARE_SLACK:
        return f"line share {before['line_share']} -> {after['line_share']}"
    if after["frontage"] < before["frontage"] - 1.0:
        return f"frontage {before['frontage']} -> {after['frontage']}"
    return ""


def propose(name, row, runs, base_dir=None):
    layout = json.load(open(Path(base_dir or ROOT / "arenas") / f"{name}.json"))
    half = float(layout.get("half_size", 120.0))
    cells = (row.get("heat") or {}).get("cells", {})
    pairs = {}
    for key, count in cells.items():
        x, z = (int(v) for v in key.split(","))
        k = min((x, z), (-x - 1, -z - 1))
        pairs[k] = pairs.get(k, 0) + count
    chosen = []
    before = shape(layout)
    placed = layout
    for (cx, cz), _ in sorted(pairs.items(), key=lambda kv: (-kv[1], kv[0])):
        if len(chosen) >= runs:
            break
        sites = []
        for dx in range(0, 11, 2):
            for dz in range(0, 11, 2):
                centre = (cx * 10 + dx, cz * 10 + dz)
                if any(math.dist(centre, c) < MIN_APART_M or math.dist(centre, (-c[0], -c[1])) < MIN_APART_M
                       for c, _ in chosen) or math.hypot(*centre) < MIN_APART_M / 2:
                    continue
                if not fits(layout, centre, half) or not fits(layout, (-centre[0], -centre[1]), half):
                    continue
                sites.append((heat_near(cells, centre) + heat_near(cells, (-centre[0], -centre[1])), centre))
        for heat, centre in sorted(sites, key=lambda s: (-s[0], s[1]))[:SITES_TRIED]:
            if not keeps_shape(before, shape(with_run(placed, centre))):
                chosen.append((centre, heat))
                placed = with_run(placed, centre)
                break
    return placed, chosen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("heat")
    ap.add_argument("out")
    ap.add_argument("--maps", default=",".join(DEFAULT_MAPS))
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--keep", default="all", choices=["all", "lanes"])
    ap.add_argument("--base", default=None, help="the maps without K5 (default arenas/; once K5 is applied, a "
                    "COVER_K5=none generation, e.g. make cover-k5 PLAN=none -> build/cover-k5-none/none)")
    args = ap.parse_args()
    global KEEP
    KEEP = args.keep
    report = json.load(open(args.heat))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    cards = []
    for name in args.maps.split(","):
        row = report[name]
        after, chosen = propose(name, row, args.runs, args.base)
        (out / f"{name}.json").write_text(json.dumps(after, indent=1))
        total = (row.get("heat") or {}).get("hull_hits", 0)
        what = "; ".join(f"a 12 m run at ({x:.0f}, {z:.0f}) and its mirror: {h} of {total} sampled hull hits within 12 m"
                         for (x, z), h in chosen) or "no street with room for a run near the fighting"
        cards.append(f"<section><h2>{html.escape(name)}</h2><div class='pair'><figure><img src='data:image/png;base64,"
                     f"{cover_page.plot(name, row, layout=json.load(open(Path(args.base or ROOT / 'arenas') / f'{name}.json')))}'><figcaption>today</figcaption></figure><figure><img "
                     f"src='data:image/png;base64,{cover_page.plot(name, row, layout=after)}'><figcaption>proposed: "
                     f"{len(chosen) * 2 * RUN_PIECES} barriers added</figcaption></figure></div><p>{html.escape(what)}</p>"
                     f"</section>")
    page = f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Barricades added</title><style>
:root{{--bg:#0f1014;--fg:#e8e8ea;--muted:#9aa0aa;--accent:#00ffd0}}
body{{background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif;margin:0 auto;max-width:1100px;padding:16px}}
h1{{font-size:22px}} h2{{font-size:18px;margin:4px 0}} .key{{color:var(--muted)}}
section{{background:#181a20;border-radius:8px;padding:10px;margin-bottom:16px}}
.pair{{display:grid;grid-template-columns:1fr 1fr;gap:8px}} figure{{margin:0}} img{{width:100%;height:auto;border-radius:4px}}
figcaption{{color:var(--muted);text-align:center}} @media (max-width:640px){{.pair{{grid-template-columns:1fr}}}}
</style></head><body><h1>Option (b), draft: a few barricades added across the hottest streets</h1>
<p class="key">The four maps where the fighting is most concentrated. Each change is a short run of two waist-high jersey
barriers (12 m) across a street where hulls were hit most, plus its mirror on the other side; every run leaves at least 5 m
clear at both ends and sides so traffic still passes, and none is in a base's spawn end. Nothing is removed. Bright outline =
low cover; red = where hulls were hit (4 fights a map). Not applied.</p>
{''.join(cards)}</body></html>"""
    (out / "index.html").write_text(page)
    print(f"add-runs proposal: {out / 'index.html'} ({len(page) // 1024} KB)")
    for card in cards:
        print(card[card.index("<p>") + 3:card.index("</p>")])


if __name__ == "__main__":
    main()
