#!/usr/bin/env python3
"""Round 37 (rules): read one arm against the base by Bar R (_agents/streams/rules.md, re-filed PAIRED 104d231f5).

    python3 tests/rules/bar_r.py BASE ARM

BASE / ARM as tools/scoreboard/guard.py --pair takes them (the base .fights.jsonl, the arm's raw folder). guard.py pairs the
fights and gives the deciding line; this adds what the bar asks beyond it: the verdict per line, the turtle's McNemar in ITS
favour (guard 1), the blob's paired win difference per faction (reported), and guard 2 (kills per match and median length per
faction, both lines, within base +- 2 x paired se). se is always the per-seed se of the paired differences.
"""
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "scoreboard"))
import guard  # noqa: E402


def key(f):
    return (f["kind"], f["arena"], f["seed"], f["side"])


def se(values):
    if len(values) < 2:
        return None
    mean = sum(values) / len(values)
    return math.sqrt(sum((v - mean) ** 2 for v in values) / (len(values) - 1)) / math.sqrt(len(values))


def paired(pairs, stat):
    """(diff of `stat` over all pairs, per-seed se of the differences, seeds) for [(base fight, arm fight)]."""
    by_seed = {}
    for b, a in pairs:
        by_seed.setdefault(b["seed"], []).append((b, a))
    diffs = [stat([a for _, a in ps]) - stat([b for b, _ in ps]) for ps in by_seed.values()]
    return stat([a for _, a in pairs]) - stat([b for b, _ in pairs]), se(diffs), len(by_seed)


def win(rows):
    return sum(1 for f in rows if f["r"]["role"] == "guard") / len(rows)


def kills_per_match(rows):
    return sum(f["r"]["kills"]["green"] + f["r"]["kills"]["rust"] for f in rows) / len(rows)


def median_s(rows):
    return statistics.median(float(f["r"]["seconds"]) for f in rows)


def main(argv):
    base_root, arm_root = argv
    base = {key(f): f for f in guard.read([base_root]) if f["r"] is not None}
    arm = {key(f): f for f in guard.read([arm_root]) if f["r"] is not None}
    rep = guard.pair([base_root], [arm_root])
    print(guard.render_pair(rep))
    args = sorted({f["r"].get("args", "") for f in arm.values()})
    print("arm args %s | base %d fights, arm %d, paired %d" % (args, len(base), len(arm), sum(1 for k in arm if k in base)))
    verdict = {}
    b = rep.get("blob")
    if b and b["n"]:
        down = b["win_diff"] < 0 and b["win_diff_se"] is not None and -b["win_diff"] > 2 * b["win_diff_se"]
        decide = down and b["mcnemar_p_worse"] < 0.05
        kr_up = b["kr_diff"] is not None and b["kr_diff_se"] is not None and b["kr_diff"] > 2 * b["kr_diff_se"]
        verdict["deciding"] = "PASS" if decide else "NOT MET"
        verdict["second line (blob kr not up)"] = "FAIL (contradiction)" if kr_up else "held"
        print("DECIDING blob win %+.3f vs 2se %.3f, McNemar p %.4f -> %s" % (b["win_diff"], 2 * (b["win_diff_se"] or 0),
              b["mcnemar_p_worse"], verdict["deciding"]))
        print("SECOND   blob kr %+.3f vs 2se %.3f -> %s" % (b["kr_diff"] or 0, 2 * (b["kr_diff_se"] or 0),
              verdict["second line (blob kr not up)"]))
    t = rep.get("turtle")
    if t and t["n"]:
        p_turtle = guard.mcnemar_p(t["better"], t["worse"])
        up = t["win_diff"] > 0 and t["win_diff_se"] is not None and t["win_diff"] > 2 * t["win_diff_se"]
        verdict["guard 1"] = "FAIL" if (up or p_turtle < 0.05) else "held"
        print("GUARD 1  turtle win %+.3f vs 2se %.3f, McNemar p %.4f in its favour -> %s" % (
              t["win_diff"], 2 * (t["win_diff_se"] or 0), p_turtle, verdict["guard 1"]))
    print("FACTION (reported): the blob's paired win difference by the blob's faction")
    for fac in sorted({guard.guard_faction(base[k]) for k in base if k[0] == "blob"}):
        pairs = [(base[k], arm[k]) for k in sorted(arm) if k in base and k[0] == "blob" and guard.guard_faction(base[k]) == fac]
        if pairs:
            d, s, n = paired(pairs, win)
            print("  %-10s %3d fights %d seeds: %+.3f (se %s)" % (fac, len(pairs), n, d, "n/a" if s is None else "%.3f" % s))
    g2_fail = []
    print("GUARD 2  kills per match and median length per faction, both lines, within +- 2 x paired se")
    for kind in ("blob", "turtle"):
        for fac in sorted({guard.guard_faction(base[k]) for k in base if k[0] == kind}):
            pairs = [(base[k], arm[k]) for k in sorted(arm) if k in base and k[0] == kind
                     and guard.guard_faction(base[k]) == fac]
            if not pairs:
                continue
            row = []
            for name, stat in (("kills/match", kills_per_match), ("median s", median_s)):
                d, s, _ = paired(pairs, stat)
                out = s is not None and abs(d) > 2 * s
                if out:
                    g2_fail.append("%s %s %s" % (kind, fac, name))
                row.append("%s %+.2f (2se %s)%s" % (name, d, "n/a" if s is None else "%.2f" % (2 * s), " OUT" if out else ""))
            print("  %-6s %-10s %s" % (kind, fac, "; ".join(row)))
    verdict["guard 2"] = "held" if not g2_fail else "OUT: " + ", ".join(g2_fail)
    print("BAR R " + " | ".join("%s: %s" % kv for kv in verdict.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
