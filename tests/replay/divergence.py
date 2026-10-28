#!/usr/bin/env python3
"""CP43.0: how far a replay's crews are from the recorded match's, per crew per census tick.
    python3 tests/replay/divergence.py HIS.jsonl[.gz] REPLAY.jsonl [--seconds=20] [--bar=3] [--crews=first2|all|Name,Name]
Prints one row per crew (its distance in m at each census second, then its max) and a verdict line:
    DIVERGENCE crews=N within=K bar=3.0m seconds=20 first_over=<crew>@<s> verdict=PASS|FAIL
`first2` (the default, the bar CP43.0 filed) = every unit named in the first two `order` rows that carry units.
A crew missing from either side counts as over the bar (its row says `missing`).
"""
import gzip, json, math, sys


def load(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def census(rows):
    out = {}
    for r in rows:
        if r.get("t") == "census":
            out[int(r["tick"])] = {u["n"]: u["pos"] for u in r["units"]}
    return out


def crews_of(rows, which):
    if which == "all":
        names = []
        for r in rows:
            if r.get("t") == "match":
                names = [u["name"] for u in r.get("units", []) if u.get("team") == 0]
        return names
    if which != "first2":
        return which.split(",")
    names, seen = [], 0
    for r in rows:
        if r.get("t") == "order" and r.get("units"):
            for n in r["units"]:
                if n not in names:
                    names.append(n)
            seen += 1
            if seen == 2:
                break
    return names


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    seconds = float(opts.get("seconds", 20))
    bar = float(opts.get("bar", 3))
    his_rows, rep_rows = load(args[0]), load(args[1])
    his, rep = census(his_rows), census(rep_rows)
    rate = 30
    for r in his_rows:
        if r.get("t") == "match":
            rate = int(r.get("tick_rate", 30))
    ticks = sorted(t for t in his if t <= seconds * rate and t in rep)
    crews = crews_of(his_rows, opts.get("crews", "first2"))
    print("crew                 " + " ".join("%4d" % (t // rate) for t in ticks) + "   max")
    within, first_over = 0, None
    for n in crews:
        cells, worst = [], 0.0
        for t in ticks:
            a, b = his[t].get(n), rep[t].get(n)
            if a is None and b is None:
                cells.append("   -")  # dead on both sides
                continue
            if a is None or b is None:
                cells.append("miss")
                worst = math.inf
                first_over = first_over or "%s@%d" % (n, t // rate)
                continue
            d = math.hypot(a[0] - b[0], a[1] - b[1])
            worst = max(worst, d)
            if d > bar and first_over is None:
                first_over = "%s@%d" % (n, t // rate)
            cells.append("%4.0f" % d if d >= 10 else "%4.1f" % d)
        within += worst <= bar
        print("%-20s " % n.replace("Green_", "")[:20] + " ".join(cells) + "  %5s" % ("miss" if worst == math.inf else "%.1f" % worst))
    verdict = "PASS" if within == len(crews) and crews and ticks else "FAIL"
    print("DIVERGENCE crews=%d within=%d bar=%.1fm seconds=%g ticks=%d first_over=%s verdict=%s"
            % (len(crews), within, bar, seconds, len(ticks), first_over or "-", verdict))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
