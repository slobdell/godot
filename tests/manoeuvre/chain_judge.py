#!/usr/bin/env python3
"""Round 39 (manoeuvre M1): Bar M1's judge, line by line (the bar is in _agents/streams/manoeuvre.md Status, filed before numbers).

    python3 tests/manoeuvre/chain_judge.py CENSUS_OFF CENSUS_ON PROBE_ROWS_JSONL [--on-arm=NAME] [--d-ratio=R] [--last-in]

CENSUS_OFF / CENSUS_ON: `traffic-jam-census` folders (JAM_CENSUS lines, one log per fight, named <arena>-<seed>.log), paired by
file name. PROBE_ROWS_JSONL: one `orders-probe` rows.jsonl holding both arms (`main` = OFF, `chain` = ON).
Round 40 (Bar M1 v2): `--on-arm` names the probe's ON arm (default chain), `--d-ratio` the deciding line's ratio (default 0.5,
Bar M1's), `--last-in` adds G7, the last squad in judged on its tail (the orchestrator: what he'd see). With no options the output
is round 39's judge, line for line.
"""
import glob
import json
import math
import os
import statistics
import sys


def census(folder):
    out = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_CENSUS "):
                    out[os.path.basename(path)] = json.loads(line[11:])
    return out


def chained(c):
    return float(c.get("giveway_chain", {}).get("parked:chained", {}).get("out_m", 0.0))


def causes(c, prefix):
    return sum(int(v) for k, v in c.get("by_cause", {}).items() if any(k.startswith(p) for p in prefix))


def paired(off, on, key):
    diffs = [key(on[k]) - key(off[k]) for k in off]
    mean = statistics.mean(diffs)
    se = statistics.stdev(diffs) / math.sqrt(len(diffs)) if len(diffs) > 1 else float("inf")
    return sum(key(off[k]) for k in off), sum(key(on[k]) for k in on), mean, se


def team_totals(cs):
    kills, deaths = {}, 0
    for c in cs.values():
        for team, row in c.get("teams", {}).items():
            kills[team] = kills.get(team, 0) + int(row.get("kills", 0))
            deaths += int(row.get("deaths", 0))
    return kills, deaths


def runs(rows, arm):
    out = {}
    for r in rows:
        if (r.get("arm") or "") != arm:
            continue
        key = (r["map"], r["squads"], r["route"], r.get("seed"))
        out.setdefault(key, []).append(r["arrived_s"])
    return {k: (-1.0 if min(v) < 0 else max(v)) for k, v in out.items()}


def options(argv):
    opts = {"on_arm": "chain", "d_ratio": 0.5, "last_in": False}
    for a in argv[4:]:
        if a.startswith("--on-arm="):
            opts["on_arm"] = a.split("=", 1)[1]
        elif a.startswith("--d-ratio="):
            opts["d_ratio"] = float(a.split("=", 1)[1])
        elif a == "--last-in":
            opts["last_in"] = True
        else:
            raise SystemExit("unknown option %s" % a)
    return opts


# G7 (round 40, --last-in): over runs both arms got all in, the paired MEAN of the last arrival ON - OFF <= LAST_IN_MEAN_S, and runs
# whose last squad is in more than LAST_IN_LATE_S later ON <= the runs more than LAST_IN_LATE_S earlier + LAST_IN_LATE_SLACK.
LAST_IN_MEAN_S = 2.0
LAST_IN_LATE_S = 10.0
LAST_IN_LATE_SLACK = 3


def main(argv):
    opts = options(argv)
    off_all, on_all = census(argv[1]), census(argv[2])
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
    a, b, mean, se = paired(off, on, chained)
    r = opts["d_ratio"]
    line("D chained seat drift", b <= r * a and mean <= -2.0 * se,
         "%.1f -> %.1f m (%+.1f %%; line <= %.1f); paired mean %+.2f m a fight, se %.2f (%.1f se)" % (
             a, b, 100.0 * (b - a) / a if a else 0.0, r * a, mean, se, mean / se if se else 0.0))
    a, b, mean, se = paired(off, on, lambda c: causes(c, ["jam:yielding", "jam:friend"]))
    line("G1 deaths in give-ways", b - a <= max(2.0 * se * len(keys), 3),
         "%d -> %d (line +%.1f = max(2 paired se x n, 3))" % (a, b, max(2.0 * se * len(keys), 3)))
    a, b, mean, se = paired(off, on, lambda c: causes(c, ["stuck:"]))
    line("G2 stuck deaths", b - a <= max(2.0 * se * len(keys), 3),
         "%d -> %d (line +%.1f)" % (a, b, max(2.0 * se * len(keys), 3)))
    a, b, mean, se = paired(off, on, lambda c: int(c.get("friendly_contacts", 0)))
    line("G3 friendly contacts", b <= 1.10 * a, "%d -> %d (line <= %.0f)" % (a, b, 1.10 * a))
    ko, do = team_totals(off)
    kn, dn = team_totals(on)
    share = lambda k, t: k.get(t, 0) / float(sum(k.values()) or 1)
    worst = max(abs(share(kn, t) - share(ko, t)) for t in set(ko) | set(kn))
    line("G4 fights", worst <= 0.03 and abs(dn - do) <= 0.05 * do,
         "kill share %s -> %s (worst move %.3f, line 0.03); deaths %d -> %d (line +/- %.0f)" % (
             {t: round(share(ko, t), 3) for t in sorted(ko)}, {t: round(share(kn, t), 3) for t in sorted(kn)}, worst,
             do, dn, 0.05 * do))

    rows = [json.loads(x) for x in open(argv[3]) if x.strip()]
    ro, rn = runs(rows, "main"), runs(rows, opts["on_arm"])
    rk = sorted(set(ro) & set(rn))
    lines.append("B: %d paired runs (off %d, on %d)" % (len(rk), len(ro), len(rn)))
    no, nn = sum(1 for k in rk if ro[k] < 0), sum(1 for k in rk if rn[k] < 0)
    line("G5 never-in runs", nn <= no, "%d -> %d (no more)" % (no, nn))
    both = [k for k in rk if ro[k] >= 0 and rn[k] >= 0]
    diffs = [rn[k] - ro[k] for k in both]
    med = statistics.median(diffs) if diffs else 0.0
    cells = {}
    for k in both:
        cells.setdefault(k[:3], []).append(rn[k] - ro[k])
    worst_cell = max(cells.items(), key=lambda kv: statistics.median(kv[1])) if cells else (None, [0.0])
    wc = statistics.median(worst_cell[1])
    line("G6 all-in time", med <= 2.0 and wc <= 10.0,
         "paired median %+.1f s over %d runs (line +2.0); worst cell %s median %+.1f s (line +10)" % (
             med, len(both), " ".join(str(x) for x in worst_cell[0]) if worst_cell[0] else "-", wc))
    if opts["last_in"]:
        mean_d = statistics.mean(diffs) if diffs else 0.0
        later = sum(1 for d in diffs if d > LAST_IN_LATE_S)
        earlier = sum(1 for d in diffs if d < -LAST_IN_LATE_S)
        line("G7 last squad in", mean_d <= LAST_IN_MEAN_S and later <= earlier + LAST_IN_LATE_SLACK,
             "paired mean %+.1f s over %d runs (line +%.1f); %d runs > %.0f s later v %d > %.0f s earlier (line: later <= earlier + %d)" % (
                 mean_d, len(diffs), LAST_IN_MEAN_S, later, LAST_IN_LATE_S, earlier, LAST_IN_LATE_S, LAST_IN_LATE_SLACK))

    def arms(cs):
        t = {"chained_n": 0, "parked_out_m": 0.0}
        for c in cs.values():
            g = c.get("giveway_chain", {})
            t["chained_n"] += int(g.get("parked:chained", {}).get("n", 0))
            t["parked_out_m"] += float(g.get("parked", {}).get("out_m", 0.0))
            for k in ("chain_in_play", "chain_spots_skipped", "chain_refusals", "chain_releases", "chain_holds_refused",
                      "parked_refusals"):
                t[k] = t.get(k, 0) + int(c.get("route_arms", {}).get(k, 0))
        t["parked_out_m"] = round(t["parked_out_m"], 1)
        return t
    lines.append("reported OFF %s" % json.dumps(arms(off), sort_keys=True))
    lines.append("reported ON  %s" % json.dumps(arms(on), sort_keys=True))
    lines.append("VERDICT %s" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv)
