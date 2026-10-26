#!/usr/bin/env python3
"""Round 40 (manoeuvre F1, R40.21): Bar F1's judge, line by line (the bar is in _agents/streams/manoeuvre.md Status, filed before
numbers).

    python3 tests/manoeuvre/follow_judge.py WEDGE_OFF WEDGE_ON PROBE_ROWS_JSONL [--on-arm=NAME]

As reroute_judge.py (Bar M3), with D on MOVING-STUCK seconds: long episodes (touching a hull, net motion < 0.5 m, >= 3 s) whose
`phase` ticks are under half `arrived` (M3's lesson: an arrived crew parked against a parked friend is not stuck to the player).
G8 (bridge-pooled 18/18 with F1 ON) is bridge_verdict.py's own line, read beside this one.
"""
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chain_judge import LAST_IN_LATE_S, LAST_IN_LATE_SLACK, LAST_IN_MEAN_S, runs  # noqa: E402
from reroute_judge import causes, fights, long_eps, paired  # noqa: E402

D_RATIO = 0.8


def moving(e):
    phase = e.get("phase", {})
    return phase.get("arrived", 0) * 2 < sum(phase.values())


def moving_eps(f):
    return [e for e in long_eps(f) if moving(e)]


def main(argv):
    on_arm = "follow"
    for a in argv[4:]:
        if a.startswith("--on-arm="):
            on_arm = a.split("=", 1)[1]
        else:
            raise SystemExit("unknown option %s" % a)
    off_all, on_all = fights(argv[1]), fights(argv[2])
    keys = sorted(set(off_all) & set(on_all))
    missing = sorted(set(off_all) ^ set(on_all))
    off = {k: off_all[k] for k in keys}
    on = {k: on_all[k] for k in keys}
    lines, ok = [], True

    def line(name, passed, text):
        nonlocal ok
        ok = ok and passed
        lines.append("%s %s: %s" % ("PASS" if passed else "FAIL", name, text))

    lines.append("A: %d paired fights (unpaired: %s)" % (len(keys), ", ".join(missing) or "none"))
    a, b, mean, se = paired(off, on, lambda f: sum(e["s"] for e in moving_eps(f)))
    line("D moving-stuck seconds", b <= D_RATIO * a and mean <= -2.0 * se,
         "%.1f -> %.1f s (%+.1f %%; line <= %.1f); paired mean %+.2f s a fight, se %.2f (%.1f se; line <= -2 se)" % (
             a, b, 100.0 * (b - a) / a if a else 0.0, D_RATIO * a, mean, se, mean / se if se else 0.0))
    a, b, mean, se = paired(off, on, lambda f: causes(f, ["jam:yielding", "jam:friend"]))
    line("G1 deaths in give-ways", b - a <= max(2.0 * se * len(keys), 3),
         "%d -> %d (line +%.1f = max(2 paired se x n, 3))" % (a, b, max(2.0 * se * len(keys), 3)))
    a, b, mean, se = paired(off, on, lambda f: causes(f, ["stuck:"]))
    line("G2 stuck deaths", b - a <= max(2.0 * se * len(keys), 3),
         "%d -> %d (line +%.1f)" % (a, b, max(2.0 * se * len(keys), 3)))
    a, b, mean, se = paired(off, on, lambda f: int(f["totals"].get("friendly_contact_ticks", 0)))
    line("G3 friendly contact ticks", b <= 1.10 * a, "%d -> %d (line <= %.0f)" % (a, b, 1.10 * a))
    ko, kn = {}, {}
    for src, dst in ((off, ko), (on, kn)):
        for f in src.values():
            for t, n in f["kills"].items():
                dst[t] = dst.get(t, 0) + n
    do = sum(int(f["totals"].get("deaths", 0)) for f in off.values())
    dn = sum(int(f["totals"].get("deaths", 0)) for f in on.values())
    share = lambda k, t: k.get(t, 0) / float(sum(k.values()) or 1)
    worst = max([abs(share(kn, t) - share(ko, t)) for t in set(ko) | set(kn)] or [0.0])
    line("G4 fights", worst <= 0.03 and abs(dn - do) <= 0.05 * do,
         "kill share %s -> %s (worst move %.3f, line 0.03); deaths %d -> %d (line +/- %.0f)" % (
             {t: round(share(ko, t), 3) for t in sorted(ko)}, {t: round(share(kn, t), 3) for t in sorted(kn)}, worst,
             do, dn, 0.05 * do))

    rows = [json.loads(x) for x in open(argv[3]) if x.strip()]
    ro, rn = runs(rows, "main"), runs(rows, on_arm)
    rk = sorted(set(ro) & set(rn))
    lines.append("B: %d paired runs (off %d, on %d)" % (len(rk), len(ro), len(rn)))
    no, nn = sum(1 for k in rk if ro[k] < 0), sum(1 for k in rk if rn[k] < 0)
    line("G5 never-in runs", nn <= no, "%d -> %d (no more)" % (no, nn))
    both = [k for k in rk if ro[k] >= 0 and rn[k] >= 0]
    diffs = [rn[k] - ro[k] for k in both]
    med = statistics.median(diffs) if diffs else 0.0
    line("G6 all-in time", med <= 2.0, "paired median %+.1f s over %d runs (line +2.0)" % (med, len(both)))
    mean_d = statistics.mean(diffs) if diffs else 0.0
    later = sum(1 for d in diffs if d > LAST_IN_LATE_S)
    earlier = sum(1 for d in diffs if d < -LAST_IN_LATE_S)
    line("G7 last squad in", mean_d <= LAST_IN_MEAN_S and later <= earlier + LAST_IN_LATE_SLACK,
         "paired mean %+.1f s over %d runs (line +%.1f); %d runs > %.0f s later v %d > %.0f s earlier (line: later <= earlier + %d)" % (
             mean_d, len(diffs), LAST_IN_MEAN_S, later, LAST_IN_LATE_S, earlier, LAST_IN_LATE_S, LAST_IN_LATE_SLACK))

    # Reported, not judged.
    for name, src in (("OFF", off), ("ON ", on)):
        eps = [e for f in src.values() for e in long_eps(f)]
        mov = [e for e in eps if moving(e)]
        lines.append("reported %s long episodes %d, %.0f s (moving %d, %.0f s); longest moving %s" % (
            name, len(eps), sum(e["s"] for e in eps), len(mov), sum(e["s"] for e in mov),
            ", ".join("%s s%d %s %s %.1f s" % (e["arena"], e["seed"], e["crew"], e["unit"], e["s"])
                      for e in sorted(mov, key=lambda e: -e["s"])[:3])))
    lines.append("VERDICT %s (G8 bridge-pooled: bridge_verdict.py's line)" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv)
