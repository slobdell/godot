"""Round 36 (orders O1): the herringbone lab stage's lines as a per-cell table.

Each line: "<arm> HERRINGBONE_LAB {...}" (tests/control/herringbone_lane_probe.gd). A cell is (lead_m, goal_dx, goal_dz).
Per cell and arm: the Sirens' all-in (sirens_s), the jam counter (held_s, held_worst_s), Hunters2's deploy and pass waits.
Then, for every arm other than `off`: (arm - off) Sirens all-in and held_s, summed and per cell, and the JAM cells: cells
where the off arm's Sirens are later than the `nostep` arm's (no herringbone) by JAM_S or more.
"""
import json
import statistics
import sys

JAM_S = 3.0
NEVER_S = 40.0  # a Sirens all-in of -1 (never in within the run) reads as the run's length


def _in(d: dict) -> float:
    return d["sirens_s"] if d["sirens_s"] >= 0 else NEVER_S


def main(path: str) -> None:
    rows: dict = {}
    for line in open(path):
        parts = line.strip().split(" ", 2)
        if len(parts) < 3 or parts[1] != "HERRINGBONE_LAB":
            continue
        d = json.loads(parts[2])
        cell = (d["lead_m"], d.get("goal_dx", 0.0), d.get("goal_dz", 0.0))
        rows.setdefault(cell, {})[parts[0]] = d
    arms = sorted({a for r in rows.values() for a in r})
    for cell, by_arm in sorted(rows.items()):
        cells = []
        for arm in arms:
            d = by_arm.get(arm)
            if d is None:
                cells.append(f"{arm}: missing")
                continue
            cells.append(f"{arm}: in {d['sirens_s']:5.1f} held {d['held_s']:4.1f}/{d['held_worst_s']:4.1f} "
                         f"dep {d['deployed_s']:5.1f} w {d['pass_waits']}")
        jam = ""
        if "off" in by_arm and "nostep" in by_arm and _in(by_arm["off"]) - _in(by_arm["nostep"]) >= JAM_S:
            jam = " JAM"
        print(f"lead {cell[0]:+5.0f} dx {cell[1]:+3.0f} dz {cell[2]:+3.0f} | " + " | ".join(cells) + jam)
    jams = [c for c, r in rows.items() if "off" in r and "nostep" in r and _in(r["off"]) - _in(r["nostep"]) >= JAM_S]
    print(f"jam cells (off - nostep >= {JAM_S} s): {len(jams)} of {len(rows)}")
    for arm in arms:
        if arm == "off":
            continue
        diffs = [_in(r[arm]) - _in(r["off"]) for r in rows.values() if arm in r and "off" in r]
        held = [r[arm]["held_s"] - r["off"]["held_s"] for r in rows.values() if arm in r and "off" in r]
        jd = [_in(rows[c][arm]) - _in(rows[c]["off"]) for c in jams if arm in rows[c]]
        rest = [_in(r[arm]) - _in(r["off"]) for c, r in rows.items() if arm in r and "off" in r and c not in jams]
        if rest:
            print(f"{arm} - off on non-jam cells: mean {statistics.mean(rest):+.2f} s worst {max(rest):+.1f} "
                  f"over +5 s: {sum(1 for d in rest if d > 5.0)} n {len(rest)}")
        if len(diffs) >= 2:
            print(f"{arm} - off Sirens all-in: mean {statistics.mean(diffs):+.2f} s sd {statistics.stdev(diffs):.2f} "
                  f"worst {max(diffs):+.1f} n {len(diffs)}; held_s mean {statistics.mean(held):+.2f}"
                  + (f"; on jam cells mean {statistics.mean(jd):+.2f} n {len(jd)}" if jd else ""))


if __name__ == "__main__":
    main(sys.argv[1])
