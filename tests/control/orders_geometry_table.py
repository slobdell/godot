#!/usr/bin/env python3
"""Round 44 (orders O3 / Bar G1 v10): his geometry read from the orders probe's rows.

    python3 tests/control/orders_geometry_table.py <dir>    (dir holds runs.jsonl, rows.jsonl, geometry.jsonl)

Per run (one click of every squad), from each squad's `start` and `anchor` and the run's click and approach (ORDERS_GEOMETRY):
  spread_m     the farthest two squads' places apart (his recording: ~100 m north to south for a 44 m move)
  across_m     the places' spread ACROSS the approach (a column: at most two squads abreast, <= widest + gap)
  aside_max_m  the farthest any place stands off the click line (the line through the click along the approach): the
               map-edge push (fit_inside) and the ranks' own frontage both show here
  backward     squads whose place lies behind where they stood along the approach by more than BACK_M (sent back)
  front_ok     whether the squad nearest the click at the start got the place nearest the click (closest in front)
  all_in_s     the last squad's arrival (-1: a squad never arrived in the window)
Prints one line per cell (map x starts x reach x arm) with medians over seeds, and the per-run rows with --runs.
"""
import json
import statistics as st
import sys
from collections import defaultdict

HOLD_M = 2.0
BACK_M = 10.0
GAP_M = 14.0  # SelectionSquads.GAP_M
ABREAST_CAP = 2  # SelectionSquads.COLUMN_ABREAST  # SelectionSquads.COLUMN_AWAY_M: a squad whose place is behind its start along the approach by more than this was sent back


def load(path):
    try:
        with open(path) as f:
            return [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        return []


def flat(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def signed_off_road(p, road, click, d):
    """The signed distance of p from the column's line: the road back from the click (left negative, right positive, as the
    approach sees it); the straight click line when no road was recorded. A column follows the street it is laid along, so a
    place 30 m from the straight line but 2 m from the road has not slid (R44.9's "no edge or wall slide")."""
    pts = [tuple(q) for q in (road or [])]
    if len(pts) < 2:
        across = (-d[1], d[0])
        return (p[0] - click[0]) * across[0] + (p[1] - click[1]) * across[1]
    best = None
    segs = list(zip(pts, pts[1:]))
    for i, (a, b) in enumerate(segs):
        vx, vz = b[0] - a[0], b[1] - a[1]
        ln = (vx * vx + vz * vz) ** 0.5
        if ln < 0.01:
            continue
        t = ((p[0] - a[0]) * vx + (p[1] - a[1]) * vz) / (ln * ln)
        # the first and last segments extend beyond the road's ends, as the layout's own walk does (a rank behind the squads'
        # centroid stands on the road's line carried on, not 60 m from its end point)
        lo = -1e9 if i == 0 else 0.0
        hi = 1e9 if i == len(segs) - 1 else 1.0
        t = max(lo, min(hi, t))
        qx, qz = a[0] + vx * t, a[1] + vz * t
        dist = flat(p, (qx, qz))
        # the road runs from the click BACK to the army, so "right of the approach" is left of the road's direction
        side = -((p[0] - qx) * (-vz / ln) + (p[1] - qz) * (vx / ln))
        if best is None or dist < abs(best):
            best = dist if side >= 0 else -dist
    return best


def read_run(rows, geo):
    click, d = geo["click"], geo["approach"]
    across = (-d[1], d[0])
    road = geo.get("road", [])
    anchors = [r["anchor"] for r in rows if r.get("anchor")]
    if len(anchors) < 2:
        return None
    spread = max(flat(a, b) for a in anchors for b in anchors)
    # Bar G1 v10b: across and aside are read over the squads the click MOVES (a place more than HOLD_M from where the squad
    # stands); a squad that holds its spot is not a destination he reads as scattered (the across row near the map's edge:
    # two squads go to the click, two hold 90 m apart). all_in still counts every squad.
    moved = [r["anchor"] for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M] or anchors
    asides = [signed_off_road(a, road, click, d) for a in moved]
    # R44.13 (b): the straight-line read beside it, for the record.
    line_asides = [((a[0] - click[0]) * across[0] + (a[1] - click[1]) * across[1]) for a in moved]
    along = lambda p: (p[0] - click[0]) * d[0] + (p[1] - click[1]) * d[1]
    backward = sum(1 for r in rows if r.get("anchor") and along(r["anchor"]) - along(r["start"]) < -BACK_M)
    nearest_start = max(rows, key=lambda r: along(r["start"]))  # farthest along the approach = nearest the click
    nearest_place = max((r for r in rows if r.get("anchor")), key=lambda r: along(r["anchor"]))
    front_ok = nearest_start["squad"] == nearest_place["squad"] or \
        abs(along(nearest_start.get("anchor") or nearest_start["start"]) - along(nearest_place["anchor"])) <= BACK_M
    times = [r["arrived_s"] for r in rows]
    all_in = -1.0 if any(t < 0 for t in times) else max(times)
    held = len(rows) - sum(1 for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M)
    # R44.9 (fit first): the front the clear ground at the click fits CENTRED with no slide: k squads of the widest, at most
    # ABREAST_CAP, whose frontage k x widest + (k - 1) x GAP fits twice the narrower clear side; the places' spread across is then
    # (k - 1) x (widest + GAP) and the farthest place off the line (k - 1) x (widest + GAP) / 2 (SelectionSquads.fit_abreast).
    widest = float(geo.get("widest", 44.0))
    clear = geo.get("clear", [0.0, 0.0])
    k = 1
    while k < ABREAST_CAP and (k + 1) * widest + k * GAP_M <= 2.0 * min(float(clear[0]), float(clear[1])):
        k += 1
    fit_across = (k - 1) * (widest + GAP_M)
    # R44.6, line 6(c) (reach-20 cells): a squad may hold only if it already stands within the column's length behind the click,
    # the length read from the arm's own laid column (the farthest MOVED place behind the click); held <= those squads, no slack.
    moved_rows = [r for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M]
    column_len = max((-along(r["anchor"]) for r in moved_rows), default=0.0)
    within = sum(1 for r in rows if 0.0 <= -along(r["start"]) <= column_len + HOLD_M)
    return {"spread_m": spread, "across_m": max(asides) - min(asides), "aside_max_m": max(abs(a) for a in asides),
            "backward": backward, "front_ok": front_ok, "all_in_s": all_in, "squads": len(rows), "moved": len(moved),
            "held": held, "within": within, "column_len_m": column_len, "fit_abreast": k, "fit_across_m": fit_across,
            "fit_aside_m": fit_across * 0.5, "reach": geo.get("reach", -1.0),
            "across_line_m": max(line_asides) - min(line_asides), "aside_line_max_m": max(abs(a) for a in line_asides)}


def med(xs):
    return st.median(xs) if xs else float("nan")


def main(argv):
    folder = argv[1]
    show_runs = "--runs" in argv
    rows, geos = load(folder + "/rows.jsonl"), load(folder + "/geometry.jsonl")
    by_key = defaultdict(list)
    for r in rows:
        by_key[(r["map"], r["seed"], r["arm"])].append(r)
    cells = defaultdict(list)
    for g in geos:
        key = (g["map"], g["seed"], g["arm"])
        if key not in by_key:
            continue
        read = read_run(by_key[key], g)
        if read is None:
            continue
        cells[(g["map"], g["starts"], g["reach"], g["arm"])].append((g["seed"], read))
        if show_runs:
            print("RUN %s %s reach %.0f %s s%d: spread %.0f across %.0f aside %.0f backward %d front %s all_in %.1f" % (
                g["map"], g["starts"], g["reach"], g["arm"], g["seed"], read["spread_m"], read["across_m"], read["aside_max_m"],
                read["backward"], read["front_ok"], read["all_in_s"]))
    print("%-10s %-7s %5s %-10s %2s %8s %8s %8s %8s %6s %8s %8s" % ("map", "starts", "reach", "arm", "n", "spread", "across", "aside", "backward", "front", "all_in", "never"))
    for key in sorted(cells):
        reads = [r for _, r in cells[key]]
        arrived = [r["all_in_s"] for r in reads if r["all_in_s"] >= 0]
        print("%-10s %-7s %5.0f %-10s %2d %8.0f %8.0f %8.0f %8.1f %5.0f%% %8s %8d" % (
            key[0], key[1], key[2], key[3], len(reads), med([r["spread_m"] for r in reads]), med([r["across_m"] for r in reads]),
            med([r["aside_max_m"] for r in reads]), sum(r["backward"] for r in reads) / len(reads),
            100.0 * sum(1 for r in reads if r["front_ok"]) / len(reads), ("%.1f" % med(arrived)) if arrived else "-",
            sum(1 for r in reads if r["all_in_s"] < 0)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
