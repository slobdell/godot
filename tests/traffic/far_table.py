#!/usr/bin/env python3
"""Round 33 (traffic X1, C33.2 (1)): the far ask loop's census table from `make traffic-far-census` logs.

    python3 tests/traffic/far_table.py build/traffic-far [more dirs or logs ...]

Each log holds FAR_ROW lines (one per far loop: manoeuvre's H1B_FAR fields + the blocker's state that tick, written by
tests/traffic/far_census.gd) and one FAR_CENSUS line (seed, arena, elements formed per team, h1b counters). The table:
far loops per match by arena; by blocker_kind x parked/moving; episodes (one asker on one blocker in one match); route
left and gap; where a parked blocker stood and why it refused the ask. Measurement only.
"""
import collections
import glob
import json
import os
import sys


def q(values):
    v = sorted(values)
    if not v:
        return "-"
    pick = lambda f: v[min(len(v) - 1, int(f * len(v)))]
    return "%s/%s/%s" % (pick(0.1), pick(0.5), pick(0.9))


def where(r):
    """Where a parked blocker stood (first match wins)."""
    if r.get("b_fire_post"):
        return "set up on a fire post"
    if r.get("b_yield_to"):
        return "giving way to someone"
    if r.get("b_order_verb") == "hold" or r.get("b_elem_task") in ("hold", "defend"):
        return "hold post (%s)" % (r.get("b_elem_task") or r.get("b_order_verb"))
    if 0.0 <= r.get("b_slot_m", -1.0) <= 3.0:
        return "its own slot (task %s)" % (r.get("b_elem_task") or "-")
    if 0.0 <= r.get("b_goal_m", -1.0) <= 3.0:
        return "its own goal (task %s)" % (r.get("b_elem_task") or "-")
    if r.get("b_engaged"):
        return "a firing spot (engaged, %s)" % r.get("b_option", "")
    return "elsewhere (%s, slot %.0f m)" % (r.get("b_option", ""), r.get("b_slot_m", -1.0))


def why(r):
    """Why the last ask was not answered with a give-way that held."""
    if r.get("last_ask_answer"):
        return "said yes (gave way, then back in the lane)"
    if r.get("b_fire_post"):
        return "refused: set up and firing (T1c-b2)"
    if r.get("b_yield_to"):
        return "refused: already giving way"
    if r.get("b_last_yielded_to_me"):
        return "refused: just gave way to this asker"
    return "refused: no validated spot"


def load(paths):
    matches, rows = [], []
    files = []
    for p in paths:
        files += sorted(glob.glob(os.path.join(p, "*.log"))) if os.path.isdir(p) else [p]
    for f in files:
        census = None
        mine = []
        refused = 0
        for line in open(f, errors="replace"):
            if "Elements.form:" in line and "refused" in line:
                refused += 1
            if line.startswith("FAR_ROW "):
                r = json.loads(line[len("FAR_ROW "):])
                r["file"] = f
                mine.append(r)
            elif line.startswith("FAR_CENSUS "):
                census = json.loads(line[len("FAR_CENSUS "):])
        if census is None:
            print("far_table: %s has no FAR_CENSUS (skipped; %d rows)" % (f, len(mine)))
            continue
        census["file"] = f
        census["form_refused"] = refused
        matches.append(census)
        for r in mine:
            r["arena"] = census["arena"]
        rows += mine
    return matches, rows


def main(argv):
    matches, rows = load(argv or ["build/traffic-far"])
    if not matches:
        print("far_table: no matches")
        return 1
    by_arena = collections.defaultdict(list)
    for m in matches:
        by_arena[m["arena"]].append(m)
    rows_by_file = collections.defaultdict(list)
    for r in rows:
        rows_by_file[r["file"]].append(r)
    print("FAR TABLE: %d matches, %d far loops (%.2f a match), %d matches with any" % (
        len(matches), len(rows), len(rows) / len(matches), sum(1 for m in matches if rows_by_file[m["file"]])))
    print("| arena | matches | elements formed (min green/rust) | squads refused an element (oversize) | seconds (min) | far loops | a match | matches with any | episodes | other_element parked loops | a match |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for arena in sorted(by_arena):
        ms = by_arena[arena]
        rs = [r for m in ms for r in rows_by_file[m["file"]]]
        eps = {(r["file"], r["unit"], r["blocker"]) for r in rs}
        op = [r for r in rs if r.get("blocker_kind") == "other_element" and not r.get("blocker_under_way")]
        print("| %s | %d | %d/%d | %d | %.0f | %d | %.2f | %d | %d | %d | %.2f |" % (
            arena, len(ms), min(int(m["elements"].get("0", 0)) for m in ms), min(int(m["elements"].get("1", 0)) for m in ms),
            sum(m["form_refused"] for m in ms),
            min(m["seconds"] for m in ms), len(rs), len(rs) / len(ms), sum(1 for m in ms if rows_by_file[m["file"]]),
            len(eps), len(op), len(op) / len(ms)))
    print()
    kinds = collections.Counter((r.get("blocker_kind", "?"), "moving" if r.get("blocker_under_way") else "parked") for r in rows)
    print("| blocker kind | blocker | loops | a match | episodes | route left p10/50/90 m | gap p10/50/90 m |")
    print("|---|---|---|---|---|---|---|")
    for (kind, state), n in kinds.most_common():
        rs = [r for r in rows if r.get("blocker_kind", "?") == kind and ("moving" if r.get("blocker_under_way") else "parked") == state]
        eps = {(r["file"], r["unit"], r["blocker"]) for r in rs}
        print("| %s | %s | %d | %.2f | %d | %s | %s |" % (kind, state, n, n / len(matches), len(eps),
                                                     q([r["remaining_m"] for r in rs]), q([r["gap_m"] for r in rs])))
    parked = [r for r in rows if not r.get("blocker_under_way")]
    if parked:
        print()
        print("Parked blockers (all kinds), where they stood | loops | episodes")
        for label, n in collections.Counter(where(r) for r in parked).most_common():
            eps = {(r["file"], r["unit"], r["blocker"]) for r in parked if where(r) == label}
            print("  %-60s %4d %4d" % (label, n, len(eps)))
        print("Parked blockers, the ask's answer | loops")
        for label, n in collections.Counter(why(r) for r in parked).most_common():
            print("  %-60s %4d" % (label, n))
        spotted = [r for r in parked if "b_spots" in r]
        if spotted:
            print("Parked blockers, the spot search re-run (dry) at the row: any spot ok %d of %d; first rejections: %s" % (
                sum(1 for r in spotted if any(x.endswith(":ok") for x in r["b_spots"])), len(spotted),
                dict(collections.Counter(x.split(":")[1] for r in spotted for x in r["b_spots"]).most_common())))
    eps = collections.Counter((os.path.basename(r["file"]), r["unit"], r["blocker"], r.get("blocker_kind", "?")) for r in rows)
    if eps:
        print()
        print("Episodes (match, asker, blocker, kind: loops, where, route left at first):")
        for (f, unit, blocker, kind), n in eps.most_common(30):
            first = next(r for r in rows if os.path.basename(r["file"]) == f and r["unit"] == unit and r["blocker"] == blocker)
            print("  %s %s on %s (%s): %d, %s, %s m, gap %s m, %s" % (
                f, unit, blocker, kind, n, "moving" if first.get("blocker_under_way") else where(first),
                first["remaining_m"], first["gap_m"], why(first)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
