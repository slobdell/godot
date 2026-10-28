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
BACK_M = 10.0  # SelectionSquads.COLUMN_AWAY_M: a squad whose place is behind its start along the approach by more than this was sent back


def load(path):
    try:
        with open(path) as f:
            return [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        return []


def flat(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def read_run(rows, geo):
    click, d = geo["click"], geo["approach"]
    across = (-d[1], d[0])
    anchors = [r["anchor"] for r in rows if r.get("anchor")]
    if len(anchors) < 2:
        return None
    spread = max(flat(a, b) for a in anchors for b in anchors)
    # Bar G1 v10b: across and aside are read over the squads the click MOVES (a place more than HOLD_M from where the squad
    # stands); a squad that holds its spot is not a destination he reads as scattered (the across row near the map's edge:
    # two squads go to the click, two hold 90 m apart). all_in still counts every squad.
    moved = [r["anchor"] for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M] or anchors
    asides = [((a[0] - click[0]) * across[0] + (a[1] - click[1]) * across[1]) for a in moved]
    along = lambda p: (p[0] - click[0]) * d[0] + (p[1] - click[1]) * d[1]
    backward = sum(1 for r in rows if r.get("anchor") and along(r["anchor"]) - along(r["start"]) < -BACK_M)
    nearest_start = max(rows, key=lambda r: along(r["start"]))  # farthest along the approach = nearest the click
    nearest_place = max((r for r in rows if r.get("anchor")), key=lambda r: along(r["anchor"]))
    front_ok = nearest_start["squad"] == nearest_place["squad"] or \
        abs(along(nearest_start.get("anchor") or nearest_start["start"]) - along(nearest_place["anchor"])) <= BACK_M
    times = [r["arrived_s"] for r in rows]
    all_in = -1.0 if any(t < 0 for t in times) else max(times)
    held = len(rows) - sum(1 for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M)
    # R44.6, line 6(c) (reach-20 cells): a squad may hold only if it already stands within the column's length behind the click,
    # the length read from the arm's own laid column (the farthest MOVED place behind the click); held <= those squads, no slack.
    moved_rows = [r for r in rows if r.get("anchor") and flat(r["anchor"], r["start"]) > HOLD_M]
    column_len = max((-along(r["anchor"]) for r in moved_rows), default=0.0)
    within = sum(1 for r in rows if 0.0 <= -along(r["start"]) <= column_len + HOLD_M)
    return {"spread_m": spread, "across_m": max(asides) - min(asides), "aside_max_m": max(abs(a) for a in asides),
            "backward": backward, "front_ok": front_ok, "all_in_s": all_in, "squads": len(rows), "moved": len(moved),
            "held": held, "within": within, "column_len_m": column_len}


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
