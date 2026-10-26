#!/usr/bin/env python3
"""Round 41 (manoeuvre, the orchestrator's reversing report, read-only): over probe_jam logs that carry reverse attribution
(JAM_EP.reverse_why / reverse_m / reverse_max_m / reverse_end_m / reverse_reentered), one table: what has a jammed crew moving
backward, by hull type; how far it backs; whether it comes back to the spot it left; and the blocker it was up against.

    python3 tests/manoeuvre/reverse_table.py DIR
"""
import collections
import glob
import json
import os
import statistics
import sys


def main(folder):
    eps = []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_EP "):
                    e = json.loads(line[7:])
                    e["file"] = os.path.basename(path)[:-4]
                    eps.append(e)
    rev = [e for e in eps if e["action"] == "reversed"]
    tot = sum(e["s"] for e in eps)
    rtot = sum(e["s"] for e in rev)
    runs = len({e["file"] for e in eps})
    print("%d runs, %d episodes (%.0f jam-s); reversing episodes %d (%.0f %% of episodes, %.0f jam-s = %.0f %%)" % (
        runs, len(eps), tot, len(rev), 100.0 * len(rev) / max(len(eps), 1), rtot, 100.0 * rtot / max(tot, 1)))
    ticks = collections.Counter()
    ticks_by_hull = {"wheeled": collections.Counter(), "tracked": collections.Counter()}
    for e in rev:
        hull = "wheeled" if e["wheeled"] else "tracked"
        for k, v in e.get("reverse_why", {}).items():
            ticks[k] += v
            ticks_by_hull[hull][k] += v
    t = sum(ticks.values()) or 1
    print("\nwhat has the hull moving backward (reversed crew-ticks, all): " + ", ".join(
        "%s %.0f %%" % (k, 100.0 * v / t) for k, v in ticks.most_common()))
    for hull, c in ticks_by_hull.items():
        th = sum(c.values()) or 1
        print("  %-7s (%5d ticks): %s" % (hull, th, ", ".join("%s %.0f %%" % (k, 100.0 * v / th) for k, v in c.most_common())))
    print("  shoved = moving backward with no reverse throttle while touching a hull; coasting = the same, touching nothing;"
          " kturn = a planned three-point-turn leg; unstick = the blind back-off; escape = H1's escape; yield = a give-way's own"
          " drive; order:<type> = a face / hold / stop order's gears; circle = Steering's circle test on a forward order; other = the"
          " drive's own reverse toward a steer point behind the hull; +touch = a hull in contact")
    # per-episode dominant why
    dom = collections.Counter()
    for e in rev:
        w = e.get("reverse_why", {})
        if w:
            dom[max(w.items(), key=lambda kv: kv[1])[0].split("+")[0]] += e["s"]
    print("\nreversing jam-seconds by the episode's dominant cause: " + ", ".join(
        "%s %.0f %%" % (k, 100.0 * v / max(rtot, 1)) for k, v in dom.most_common()))
    backs = [e["reverse_m"] for e in rev]
    maxs = [e["reverse_max_m"] for e in rev]
    print("\nhow far it backed (metres moving backward, an episode): median %.1f, p75 %.1f, p90 %.1f, max %.1f; farthest from where the"
          " reverse began: median %.1f, p90 %.1f" % (statistics.median(backs), sorted(backs)[int(0.75 * (len(backs) - 1))],
                                                      sorted(backs)[int(0.9 * (len(backs) - 1))], max(backs),
                                                      statistics.median(maxs), sorted(maxs)[int(0.9 * (len(maxs) - 1))]))
    far = [e for e in rev if e["reverse_max_m"] > 3.0]
    re = [e for e in far if e["reverse_reentered"]]
    print("episodes that got more than 3 m from where the reverse began: %d (%.0f jam-s); of those, back within 2 m of it by the"
          " episode's end (re-entered): %d (%.0f %%)" % (len(far), sum(e["s"] for e in far), len(re), 100.0 * len(re) / max(len(far), 1)))
    by_class = collections.Counter()
    for e in rev:
        by_class[e["class_mode"]] += e["s"]
    print("\nblocker during reversing episodes (jam-s): " + ", ".join(
        "%s %.0f %%" % (k, 100.0 * v / max(rtot, 1)) for k, v in by_class.most_common()))
    ph = collections.Counter()
    for e in rev:
        for k, v in e["phases"].items():
            ph[k] += v
    tp = sum(ph.values()) or 1
    print("asker's drive phase during them (ticks): " + ", ".join("%s %.0f %%" % (k, 100.0 * v / tp) for k, v in ph.most_common()))
    print("by hull (jam-s): wheeled %.0f %%, tracked %.0f %%; by unit: %s" % (
        100.0 * sum(e["s"] for e in rev if e["wheeled"]) / max(rtot, 1), 100.0 * sum(e["s"] for e in rev if not e["wheeled"]) / max(rtot, 1),
        ", ".join("%s %.0f %%" % (u, 100.0 * sum(e["s"] for e in rev if e["unit"] == u) / max(rtot, 1))
                  for u in sorted({e["unit"] for e in rev}))))
    print("\nlongest 8 reversing episodes: s, dominant cause, backed m, max m, re-entered, class, asker <- blocker, file")
    for e in sorted(rev, key=lambda e: -e["s"])[:8]:
        w = e.get("reverse_why", {})
        d = max(w.items(), key=lambda kv: kv[1])[0] if w else "-"
        print("  %5.1f s  %-14s back %4.1f m  max %4.1f m  re-entered %-5s  %-8s %-20s <- %-20s %s" % (
            e["s"], d, e["reverse_m"], e["reverse_max_m"], e["reverse_reentered"], e["class_mode"], e["asker"], e["blocker"], e["file"]))


if __name__ == "__main__":
    main(sys.argv[1])
