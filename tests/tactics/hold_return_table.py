#!/usr/bin/env python3
"""Round 32 (brains B11): B11's bar lines from `make manoeuvre-hull-rest` arms new_drawn (on) and base_drawn
(--hold-return=old), read from <dir>/<arm>/<faction>/<task>-<seed>/screen.json (per-crew `each`):
  crews ending > 90 deg from his drawn heading, pooled, on v off, with a one-sided Fisher p (on fewer);
  the same per hull class; runs never settled (settled_after_s < 0) and the paired settled_after_s median difference.
Usage: hold_return_table.py <dir>"""
import json
import math
import pathlib
import statistics
import sys


def runs(root, arm):
    out = {}
    for path in sorted((pathlib.Path(root) / arm).glob("*/*/screen.json")):
        faction, run = path.parts[-3], path.parts[-2]
        try:
            rows = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        if rows:
            out[(faction, run)] = rows[0]
    return out


def crews(row):
    for squad in row.get("squads", []):
        for each in squad.get("each", []):
            yield each


def fisher_less(a, n_a, b, n_b):
    """One-sided p that arm a has as few or fewer hits than observed, given the margins (hypergeometric)."""
    total, hits = n_a + n_b, a + b
    def pmf(k):
        return math.comb(hits, k) * math.comb(total - hits, n_a - k) / math.comb(total, n_a)
    return sum(pmf(k) for k in range(max(0, hits - n_b), a + 1))


def main(root):
    on, off = runs(root, "new_drawn"), runs(root, "base_drawn")
    keys = sorted(set(on) & set(off))
    print("B11 paired runs: %d (on %d, off %d)" % (len(keys), len(on), len(off)))
    by_class = {}
    tot = {"on": [0, 0], "off": [0, 0]}
    for arm, table in (("on", on), ("off", off)):
        for k in keys:
            for each in crews(table[k]):
                wide = float(each.get("hull_error_deg", 0.0)) > 90.0
                tot[arm][0] += wide
                tot[arm][1] += 1
                c = by_class.setdefault(each.get("class", "?"), {"on": [0, 0], "off": [0, 0]})
                c[arm][0] += wide
                c[arm][1] += 1
    a, na = tot["on"]
    b, nb = tot["off"]
    print("crews > 90 deg off: on %d/%d v off %d/%d; one-sided Fisher p (on fewer) %.4f" % (a, na, b, nb,
          fisher_less(a, na, b, nb) if na and nb else float("nan")))
    for name, c in sorted(by_class.items()):
        print("  %-16s on %d/%d v off %d/%d" % (name, c["on"][0], c["on"][1], c["off"][0], c["off"][1]))
    never_on = sum(1 for k in keys if float(on[k].get("settled_after_s", -1)) < 0)
    never_off = sum(1 for k in keys if float(off[k].get("settled_after_s", -1)) < 0)
    diffs = [float(on[k]["settled_after_s"]) - float(off[k]["settled_after_s"]) for k in keys
             if float(on[k].get("settled_after_s", -1)) >= 0 and float(off[k].get("settled_after_s", -1)) >= 0]
    print("runs never settled: on %d v off %d; paired settled_after_s median diff %s s over %d" % (
          never_on, never_off, "%+.1f" % statistics.median(diffs) if diffs else "-", len(diffs)))
    worst = max(((float(e.get("hull_error_deg", 0)), k, e.get("unit")) for k in keys for e in crews(on[k])), default=None)
    print("worst on-arm crew: %s" % (worst,))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
