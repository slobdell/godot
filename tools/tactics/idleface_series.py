#!/usr/bin/env python3
"""Round 13 (squad Q2, S6): summarise `make squad-idleface-series` (build/squad-idleface.jsonl).

Pairs the two arms of IDLE_FACE (TankBrain.IDLE_FACE_NO_PIVOT: on = a wheeled fixed-gun hull with no enemy in sight is
not told to face unless its order names a facing) on the SAME seed, arena, direction and squad. Per cell: medians of
arrival and stop (a run that never stopped inside the cap counts as the cap), the worst crew's distance from its slot
when the squad stopped, the scouts' own worst, the faces issued with nothing in sight by source, and the discordant
pairs on the stop time.
"""
import json
import statistics
import sys
from collections import defaultdict

CAP_S = 90.0


def val(row, key):
    v = row.get(key)
    return CAP_S if v is None else float(v)


def worst(row, only=None):
    off = row.get("off_slot_m", {})
    units = row["units"].split(":")
    names = sorted(off)
    picked = [float(off[n]) for i, n in enumerate(names) if only is None or (i < len(units) and units[i] == only)]
    return max(picked) if picked else -1.0


def main(path):
    runs = defaultdict(dict)
    for line in open(path):
        line = line.strip()
        if line:
            row = json.loads(line)
            runs[(row["arena"], row["dir"], row["units"])].setdefault(row["seed"], {})[
                "on" if row.get("idle_face") else "off"] = row
    print("arms: IDLE_FACE off / on (medians; stop, worst off-slot at stop, scouts' worst; faces with nothing in sight)")
    total = [0, 0, 0]
    for cell in sorted(runs):
        pairs = [p for p in runs[cell].values() if "on" in p and "off" in p]
        if not pairs:
            continue
        med = lambda a, f: statistics.median(f(p[a]) for p in pairs)
        faster = sum(1 for p in pairs if val(p["on"], "stopped_s") < val(p["off"], "stopped_s") - 0.5)
        slower = sum(1 for p in pairs if val(p["on"], "stopped_s") > val(p["off"], "stopped_s") + 0.5)
        ties = len(pairs) - faster - slower
        for i, n in enumerate((faster, slower, ties)):
            total[i] += n
        faces = lambda a: {k: sum(int(p[a].get("idle_faces", {}).get(k, 0)) for p in pairs)
                           for k in sorted({k for p in pairs for k in p[a].get("idle_faces", {})})}
        print("%-9s %-7s %-22s n=%d | arrived %5.1f / %-5.1f | stopped %5.1f / %-5.1f | worst %5.1f / %-5.1f | scouts %5.1f / %-5.1f"
              " | on faster %d, slower %d, tie %d" % (
                  cell[0], cell[1], cell[2], len(pairs), med("off", lambda r: val(r, "arrived_s")),
                  med("on", lambda r: val(r, "arrived_s")), med("off", lambda r: val(r, "stopped_s")),
                  med("on", lambda r: val(r, "stopped_s")), med("off", worst), med("on", worst),
                  med("off", lambda r: worst(r, "scout")), med("on", lambda r: worst(r, "scout")), faster, slower, ties))
        print("    faces with nothing in sight: off %s | on %s; declined on: %d" % (
            faces("off"), faces("on"), sum(int(p["on"].get("idle_faces_declined", 0)) for p in pairs)))
        for seed in sorted(runs[cell]):
            p = runs[cell][seed]
            if "on" in p and "off" in p and abs(val(p["off"], "stopped_s") - val(p["on"], "stopped_s")) > 0.5:
                print("    seed %s: stopped off %.1f / on %.1f, worst off-slot off %.1f / on %.1f" % (
                    seed, val(p["off"], "stopped_s"), val(p["on"], "stopped_s"), worst(p["off"]), worst(p["on"])))
    print("TOTAL stop: on faster %d, on slower %d, tie %d" % tuple(total))


if __name__ == "__main__":
    main(sys.argv[1])
