#!/usr/bin/env python3
"""Round 42 (engage E4): Bar E1's lines from `make engage-probe` logs (tests/engage/attack_shot_probe.gd, one ENGAGE_PROBE
json line per seed).

    attack_shot_table.py DIR                 one arm: a row per seed and the totals
    attack_shot_table.py --pair OFF_DIR ON_DIR   the bar: paired by seed, each line with its paired mean difference and se
    ... --deciding=suppress                       Bar E2's lines (v2: the SUPPRESS stand): a dominance line with an exercised floor

Lines (the bar names them before any number; this prints what they read):
  stuck      crew-seconds under the order, in distance-range, no line, not moving (sum a run)    deciding: ON <= 0.25 x OFF
             and paired mean < 0 by >= 2 se
  first_hit  seconds from the order to each crew's first hit, never = the window (mean a run)    deciding: ON < OFF by >= 2 se
  deaths_moving  crews that died moving for a shot (sum a run)                                   guard: ON <= OFF + 1.645 se
  never_reached  spots sent and never reached (sum)                                              reported
  dither     spot changes per crew per order (mean a run)                                        reported, cap 2.0
  deaths, hits, target_dead_s                                                                    reported
Report only; the verdict is read against the bar by hand.
"""
import glob
import json
import math
import os
import sys


def read(folder):
    rows = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path) as f:
            for line in f:
                if line.startswith("ENGAGE_PROBE "):
                    d = json.loads(line[len("ENGAGE_PROBE "):])
                    if "error" in d:
                        continue
                    rows[int(d["seed"])] = d
    return rows


def metrics(d):
    crews = list(d["stuck_s"].keys())
    window = float(d["window_s"])
    first = [float(d["first_hit_s"][c]) if float(d["first_hit_s"][c]) >= 0 else window for c in crews]
    return {
        "stuck": sum(float(v) for v in d["stuck_s"].values()),
        "stuck_suppress": sum(float(v) for v in d.get("stuck_suppress_s", {}).values()),
        "no_shot": sum(float(v) for v in d["no_shot_s"].values()),
        "first_hit": sum(first) / len(first),
        "never_hit": sum(1 for c in crews if float(d["first_hit_s"][c]) < 0),
        "deaths_moving": int(d["deaths_moving"]),
        "deaths": int(d["deaths"]),
        "never_reached": int(d["never_reached"]),
        "dither": sum(int(v) for v in d["spot_changes"].values()) / len(crews),
        "hits": sum(int(v) for v in d.get("hits", {}).values()),
        "target_dead": float(d["target_dead_s"]) if float(d["target_dead_s"]) >= 0 else window,
        "lines_per_plan_tick": (float(d["lines"]) / float(d["plan_ticks"])) if int(d.get("plan_ticks", 0)) > 0 else 0.0,
        "line_flips": sum(int(v) for v in d.get("line_flips", {}).values()) / len(crews),
    }


KEYS = ["stuck", "stuck_suppress", "no_shot", "first_hit", "never_hit", "deaths_moving", "deaths", "never_reached", "dither", "line_flips", "hits",
        "target_dead", "lines_per_plan_tick"]


def one(folder):
    rows = read(folder)
    print("%-6s %-9s %-10s %5s %5s | %7s %7s %8s %5s %6s %6s %5s %6s %5s %7s" % (
        "seed", "arena", "hull", "crews", "start", "stuck", "noshot", "firsthit", "never", "dmov", "deaths", "nreach", "dither", "hits", "tdead"))
    totals = {k: 0.0 for k in KEYS}
    for seed in sorted(rows):
        d = rows[seed]
        m = metrics(d)
        clear = sum(1 for v in d["start_line"].values() if v)
        print("%-6d %-9s %-10s %5d %5s | %7.1f %7.1f %8.1f %5d %6d %6d %5d %6.2f %5d %7.1f  %s%s" % (
            seed, d["arena"], d["hull"], int(d["crews"]), "%d/%d" % (clear, int(d["crews"])), m["stuck"], m["no_shot"],
            m["first_hit"], m["never_hit"], m["deaths_moving"], m["deaths"], m["never_reached"], m["dither"], m["hits"], m["target_dead"],
            "" if d.get("stage_ok", True) else "STAGE-OFF ", d.get("start_m", "")))
        for k in KEYS:
            totals[k] += m[k]
    n = len(rows)
    if n:
        print("SUPPRESS share of stuck: %.1f of %.1f s (%.0f %%)" % (totals["stuck_suppress"], totals["stuck"],
            100.0 * totals["stuck_suppress"] / totals["stuck"] if totals["stuck"] > 0 else 0.0))
        print("n %d | stuck %.1f | first_hit mean %.1f | never_hit %d | deaths_moving %d | deaths %d | never_reached %d | dither mean %.2f | hits %d | lines/plan tick %.1f" % (
            n, totals["stuck"], totals["first_hit"] / n, totals["never_hit"], totals["deaths_moving"], totals["deaths"],
            totals["never_reached"], totals["dither"] / n, totals["hits"], totals["lines_per_plan_tick"] / n))


## Bar E2 (round 42, v2): the dominance line on the SUPPRESS stand. ON <= 0.25 x OFF over the series AND no seed worse (ON <= OFF
## + WORSE_S on every seed), decided only when the series is EXERCISED (>= EXERCISED_SEEDS seeds with OFF >= EXERCISED_S).
WORSE_S = 0.5
EXERCISED_SEEDS = 3
EXERCISED_S = 2.0


def pair(off_dir, on_dir, deciding="stuck"):
    off = read(off_dir)
    on = read(on_dir)
    seeds = sorted(set(off) & set(on))
    print("paired seeds: %d (off %d, on %d)%s" % (len(seeds), len(off), len(on), " | Bar E2 lines (--deciding=suppress)" if deciding == "suppress" else ""))
    print("%-16s %10s %10s %10s %8s %8s | %s" % ("line", "OFF", "ON", "mean diff", "se", "z", "reading"))
    for k in KEYS:
        a = [metrics(off[s])[k] for s in seeds]
        b = [metrics(on[s])[k] for s in seeds]
        diffs = [y - x for x, y in zip(a, b)]
        n = len(diffs)
        mean = sum(diffs) / n if n else 0.0
        sd = math.sqrt(sum((d - mean) ** 2 for d in diffs) / (n - 1)) if n > 1 else 0.0
        se = sd / math.sqrt(n) if n else 0.0
        z = mean / se if se > 0 else 0.0
        total_off = sum(a)
        total_on = sum(b)
        reading = ""
        if deciding == "suppress" and k == "stuck_suppress":
            exercised = sum(1 for x in a if x >= EXERCISED_S)
            worse = [seeds[i] for i in range(n) if b[i] > a[i] + WORSE_S]
            quarter = total_on <= 0.25 * total_off
            if exercised < EXERCISED_SEEDS:
                verdict = "NOT EXERCISED (%d of %d seeds with OFF >= %.0f s; needs %d): extend" % (exercised, n, EXERCISED_S, EXERCISED_SEEDS)
            else:
                verdict = "PASS" if (quarter and not worse) else "FAIL"
            reading = "DECIDING (E2): ON <= 0.25 x OFF (%s), no seed worse by > %.1f s (%s) | exercised %d seeds -> %s" % (
                quarter, WORSE_S, "none" if not worse else worse, exercised, verdict)
        elif deciding == "suppress" and k == "stuck":
            ok = total_on <= total_off + 1.645 * se * n
            reading = "GUARD (E2): ON <= OFF + 1.645 se (totals; se of the total %.2f) -> %s" % (se * n, "PASS" if ok else "FAIL")
        elif deciding == "suppress" and k == "first_hit":
            ok = mean <= 1.645 * se
            reading = "GUARD (E2): ON <= OFF + 1.645 se (not worse) -> %s" % ("PASS" if ok else "FAIL")
        elif deciding == "suppress" and k == "deaths":
            ok = total_on <= total_off + 1.645 * se * n
            reading = "GUARD (E2): ON <= OFF + 1.645 se (totals; se of the total %.2f) -> %s" % (se * n, "PASS" if ok else "FAIL")
        elif deciding == "suppress" and k == "lines_per_plan_tick":
            ok = mean <= 0.5
            reading = "GUARD (E2): ON <= OFF + 0.5 a plan tick -> %s" % ("PASS" if ok else "FAIL")
        elif k == "stuck":
            ok = total_on <= 0.25 * total_off and (se > 0 and mean < 0 and -z >= 2.0)
            reading = "DECIDING: ON <= 0.25 x OFF (%s) and mean < 0 by >= 2 se (%s) -> %s" % (
                total_on <= 0.25 * total_off, se > 0 and mean < 0 and -z >= 2.0, "PASS" if ok else "FAIL")
        elif k == "first_hit":
            ok = se > 0 and mean < 0 and -z >= 2.0
            reading = "DECIDING: ON < OFF by >= 2 se -> %s" % ("PASS" if ok else "FAIL")
        elif k == "deaths_moving":
            ok = total_on <= total_off + max(1.645 * se * n, 2.0 if deciding == "suppress" else 0.0)
            reading = "GUARD: ON <= OFF + %s (totals; se of the total %.2f) -> %s" % (
                "max(1.645 se, 2)" if deciding == "suppress" else "1.645 se", se * n, "PASS" if ok else "FAIL")
        elif k == "stuck_suppress":
            reading = "REPORTED (R42.6): SUPPRESS share of ON's stuck = %.0f %%" % (100.0 * total_on / sum(metrics(on[s])["stuck"] for s in seeds) if sum(metrics(on[s])["stuck"] for s in seeds) > 0 else 0.0)
        elif k == "dither":
            ok = (total_on / n if n else 0.0) <= 2.0
            reading = "REPORTED, cap 2.0 a crew an order -> %s" % ("within" if ok else "OVER")
        else:
            reading = "reported"
        if k in ("stuck", "stuck_suppress", "no_shot", "never_hit", "deaths_moving", "deaths", "never_reached", "hits"):
            print("%-16s %10.1f %10.1f %10.2f %8.2f %8.2f | %s" % (k, total_off, total_on, mean, se, z, reading))
        else:
            print("%-16s %10.2f %10.2f %10.2f %8.2f %8.2f | %s" % (k, total_off / n if n else 0, total_on / n if n else 0, mean, se, z, reading))


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--pair":
        deciding = "stuck"
        for arg in sys.argv[4:]:
            if arg.startswith("--deciding="):
                deciding = arg.split("=", 1)[1]
        pair(sys.argv[2], sys.argv[3], deciding)
    elif len(sys.argv) == 2:
        one(sys.argv[1])
    else:
        print(__doc__)
        sys.exit(2)
