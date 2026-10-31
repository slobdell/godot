#!/usr/bin/env python3
"""Round 47 (manoeuvre M3): Bar M's W2 judge (route's CPU v CPU census, both sides, C47.9).

  barm_w2_judge.py <base dir> <buried dir>

Pairs <map>-<seed>.log across the two arms; per log the LAST `NOPROGRESS {...}` line. Per team (0, 1): crew-seconds with no progress
and wall-contact seconds, the paired mean difference (buried - base) a fight, se, z, n, sooner-or-identical share; and the fights the
rule touched. Measurement only: the verdict is the filing's.
"""
import json, math, os, sys


def last(path):
    row = None
    for line in open(path, errors="replace"):
        if line.startswith("NOPROGRESS {"):
            row = json.loads(line[len("NOPROGRESS "):])
    return row


def paired(d):
    n = len(d)
    if n < 2:
        return "n %d" % n
    m = sum(d) / n
    se = math.sqrt(sum((x - m) ** 2 for x in d) / (n - 1) / n)
    return "diff %+.3f a fight, se %.3f, z %+.2f, n %d, sooner-or-identical %.0f %%" % (
        m, se, m / se if se > 0 else 0.0, n, 100.0 * sum(1 for x in d if x <= 1e-9) / n)


def main(argv):
    a, b = argv[1], argv[2]
    pairs = []
    for f in sorted(os.listdir(a)):
        if f.endswith(".log") and os.path.exists(os.path.join(b, f)):
            x, y = last(os.path.join(a, f)), last(os.path.join(b, f))
            if x is not None and y is not None:
                pairs.append((f, x, y))
    print("W2 fights paired %d; touched (buried swaps > 0) %d" % (len(pairs), sum(1 for p in pairs if p[2].get("swaps", 0) > 0)))
    for team in ("0", "1"):
        for key in ("s", "contact_s"):
            base = [p[1].get(team, {}).get(key, 0.0) for p in pairs]
            arm = [p[2].get(team, {}).get(key, 0.0) for p in pairs]
            print("  team %s %-9s base %.1f -> buried %.1f | %s" % (team, key, sum(base), sum(arm), paired([y - x for x, y in zip(base, arm)])))


if __name__ == "__main__":
    main(sys.argv)
