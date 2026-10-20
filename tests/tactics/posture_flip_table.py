#!/usr/bin/env python3
"""Round 35 (brains E3): what a CPU commander's flip to HOLD (Posture.decide) does to elements already fighting.

Reads showmatch logs made with `--brains-census --element-trace=all` (BRAINS_POSTURE lines, ELEMENT_TRACE rows). For every
flip of a team to `hold`, each of that team's elements is classed by its task just before the flip and just after:

  engaged    its task before was attack or support_by_fire (it was in the fight)
  re-posted  its task point after is > REPOST_M from where the element stood (its centre), and differs from before

and its crews are counted at the flip and WINDOW_S later (the crews its trace rows list). Prints, per arena, the flips, the
engaged elements re-posted v kept, and the crews each group lost in the window (per element), plus one row per re-posted
engaged element. Report only: a census, not a judged series.

usage: posture_flip_table.py <dir of *.log> [--rows]
"""
import glob
import os
import re
import sys
from collections import defaultdict

REPOST_M = 40.0
WINDOW_S = 30.0
ENGAGED = ("attack", "support_by_fire")

POSTURE = re.compile(r"BRAINS_POSTURE team (\d) t=(\d+)s (\w+) (.*)")
ROW = re.compile(r"ELEMENT_TRACE t=([\d.]+) \[([^\]]*)\] id (\d+) task (\w+) to (\[[-\d.e]+, [-\d.e]+\]|<null>|null)"
                 r".*? centre \(([-\d.]+),([-\d.]+)\)")
CREW = re.compile(r"\| (Green|Rust)_\S+ at ")


def read(path):
    flips, rows = [], defaultdict(list)  # rows[element id] = [(t, verb, to, centre, crews, team)]
    with open(path, errors="replace") as handle:
        for line in handle:
            if line.startswith("BRAINS_POSTURE"):
                m = POSTURE.match(line)
                if m:
                    flips.append((int(m.group(1)), float(m.group(2)), m.group(3), m.group(4).strip()))
            elif line.startswith("ELEMENT_TRACE"):
                m = ROW.match(line)
                if not m:
                    continue
                crews = CREW.findall(line)
                if not crews:
                    continue
                to = None
                if m.group(5).startswith("["):
                    x, z = m.group(5)[1:-1].split(",")
                    to = (float(x), float(z))
                team = 0 if crews[0] == "Green" else 1
                rows[m.group(3)].append((float(m.group(1)), m.group(4), to, (float(m.group(6)), float(m.group(7))),
                                         len(crews), team, m.group(2)))
    return flips, rows


def at(series, t):
    before = [r for r in series if r[0] <= t]
    return before[-1] if before else None


def main():
    root = sys.argv[1]
    show_rows = "--rows" in sys.argv
    table = defaultdict(lambda: defaultdict(float))
    lines = []
    for path in sorted(glob.glob(os.path.join(root, "*.log"))):
        arena = os.path.basename(path).rsplit("-", 1)[0]
        flips, rows = read(path)
        table[arena]["fights"] += 1
        for team, t, posture, why in flips:
            if posture != "hold":
                continue
            table[arena]["flips"] += 1
            for element_id, series in rows.items():
                if not series or series[0][5] != team:
                    continue
                before, after = at(series, t - 0.01), at(series, t + 3.0)
                if before is None or after is None or before[4] == 0:
                    continue
                engaged = before[1] in ENGAGED
                moved = after[2] is not None and after[2] != before[2] \
                    and ((after[2][0] - before[3][0]) ** 2 + (after[2][1] - before[3][1]) ** 2) ** 0.5 > REPOST_M
                later = at(series, t + WINDOW_S)
                lost = before[4] - (later[4] if later is not None and later[0] > t + 3.0 else 0)
                if later is None or later[0] < t + WINDOW_S - 2.0:
                    lost = before[4]  # no row near the window's end: the element is gone
                group = ("engaged" if engaged else "idle") + ("_reposted" if moved else "_kept")
                table[arena][group] += 1
                table[arena][group + "_lost"] += lost
                table[arena][group + "_crews"] += before[4]
                if engaged and moved:
                    dist = ((after[2][0] - before[3][0]) ** 2 + (after[2][1] - before[3][1]) ** 2) ** 0.5
                    lines.append("  %s t %.0f team %d %s#%s %s -> %s %.0f m, crews %d lost %d (%s)" % (
                        os.path.basename(path), t, team, before[6], element_id, before[1], after[1], dist, before[4], lost, why))
    groups = ["engaged_reposted", "engaged_kept", "idle_reposted", "idle_kept"]
    print("posture flips to HOLD and the elements they re-post (> %.0f m); crews lost in the %.0f s after, per group" % (REPOST_M, WINDOW_S))
    print("%-10s %6s %6s  %s" % ("arena", "fights", "flips", "  ".join("%-26s" % g for g in groups)))
    for arena, c in sorted(table.items()):
        cells = []
        for g in groups:
            n, crews, lost = c[g], c[g + "_crews"], c[g + "_lost"]
            cells.append("%-26s" % ("%d el, %d/%d crews (%.0f %%)" % (n, lost, crews, 100.0 * lost / crews if crews else 0.0)))
        print("%-10s %6d %6d  %s" % (arena, c["fights"], c["flips"], "  ".join(cells)))
    if show_rows:
        print("\nengaged elements re-posted at a flip to hold:")
        print("\n".join(lines))


if __name__ == "__main__":
    main()
