#!/usr/bin/env python3
"""Round 34 (traffic T6's bar, R34.15): the paired reading of two `make traffic-jam-census` folders (base = underfire OFF,
arm = ON), fight by fight (the same <arena>-<seed>.log in both).

    python3 tests/traffic/jam_ab.py BASE_DIR ARM_DIR [--k 1.645]

Lines (filed in workstreams.md *Bars (round 34)* before any number; se = the paired se of the SUM over fights):
  G  (deciding gain)  jam-under-fire deaths (a jam death whose last hit landed during the jam, or with >= 2 hits in the
                      10 s before): arm < base AND (base - arm) - k*se > 0
  1  (guard) deaths in the open: within base +- k*se        2 (guard) stuck deaths: arm <= base + k*se
  3  (guard) far loops (H1b's, from Movement.route_arms): arm <= base + k*se
  4  (guard) kills: within base +- k*se; hit rate: arm >= base - k*se
  5  (guard) friendly contacts of a crew in the 3 s after its give-way ended on a hit: arm <= base + k*se
  R  (reported) standoffs (two friendly crews nose to nose, both under fire, neither yielding, still >= 2 s), with durations;
     Movement's underfire counters; jam deaths of every kind; all deaths.
Crossing arrivals (line 6) are read by v2_lines.py on traffic-series, as parkedroom's L4 was.
"""
import collections
import json
import math
import os
import sys


def read(path):
    deaths, census, standoffs, aborts = [], None, [], []
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith("JAM_DEATH "):
                deaths.append(json.loads(line[10:]))
            elif line.startswith("JAM_CENSUS "):
                census = json.loads(line[11:])
            elif line.startswith("STANDOFF "):
                standoffs.append(json.loads(line[9:]))
            elif line.startswith("ABORT "):
                aborts.append(json.loads(line[6:]))
    return deaths, census, standoffs, aborts


def under_fire(r):
    return bool(r.get("hit_in_jam")) or int(r.get("hits_10s", 0)) >= 2


def far_loops(census):
    ra = (census or {}).get("route_arms") or {}
    h1b = ((ra.get("turns") or {}).get("counters") or {}).get("h1b") or ra.get("h1b") or {}
    return int(h1b.get("loops", 0))


def paired(base, arm):
    d = [b - a for b, a in zip(base, arm)]
    n = len(d)
    mean = sum(d) / n if n else 0.0
    sd = math.sqrt(sum((x - mean) ** 2 for x in d) / (n - 1)) if n > 1 else 0.0
    return {"base": sum(base), "arm": sum(arm), "drop": sum(d), "se": sd * math.sqrt(n), "n": n, "differing": sum(1 for x in d if x)}


def per_fight(deaths, census, standoffs, aborts):
    jam = [r for r in deaths if str(r.get("cause", "")).startswith("jam:")]
    teams = (census or {}).get("teams", {})
    shots = sum(int(t.get("shots", 0)) for t in teams.values())
    hits = sum(int(t.get("hits", 0)) for t in teams.values())
    return {
        "jam_uf": sum(1 for r in jam if under_fire(r)),
        "jam": len(jam),
        "open": sum(1 for r in deaths if str(r.get("cause", "")).startswith("open:")),
        "stuck": sum(1 for r in deaths if str(r.get("cause", "")).startswith("stuck:")),
        "all": len(deaths),
        "kills": sum(int(t.get("kills", 0)) for t in teams.values()),
        "hit_rate": hits / shots if shots else 0.0,
        "far": far_loops(census),
        "standoffs": len(standoffs),
        "standoff_s": sum(float(s.get("lasted_s", 0)) for s in standoffs),
        "aborts": len(aborts),
        "abort_contacts": sum(int(a.get("contacts_3s", 0)) for a in aborts),
        "counters": {k: int(((census or {}).get("route_arms") or {}).get(k, 0)) for k in ("underfire_refusals", "underfire_holds", "underfire_aborts")},
    }


def read_dirs(base_dir, arm_dir):
    names = sorted(n for n in set(os.listdir(base_dir)) & set(os.listdir(arm_dir)) if n.endswith(".log"))
    rows = {"base": collections.defaultdict(list), "arm": collections.defaultdict(list)}
    skipped, warnings, durations = [], [], {"base": [], "arm": []}
    counters = {"base": collections.Counter(), "arm": collections.Counter()}
    for name in names:
        b = read(os.path.join(base_dir, name))
        a = read(os.path.join(arm_dir, name))
        if b[1] is None or a[1] is None:
            skipped.append(name)
            continue
        if b[1].get("underfire_on") or not a[1].get("underfire_on"):
            warnings.append("%s: arms not as named (base on %s, arm on %s)" % (name, b[1].get("underfire_on"), a[1].get("underfire_on")))
        for side, data in (("base", b), ("arm", a)):
            f = per_fight(*data)
            for k, v in f.items():
                if k != "counters":
                    rows[side][k].append(v)
            counters[side].update(f["counters"])
            durations[side] += [float(s.get("lasted_s", 0)) for s in data[2]]
    return {"n": len(rows["base"]["all"]), "rows": rows, "skipped": skipped, "warnings": warnings, "counters": counters, "durations": durations}


def line(label, stat, k, rule):
    extra = ""
    if rule == "gain":
        ok = stat["arm"] < stat["base"] and stat["drop"] - k * stat["se"] > 0
        extra = "drop - k*se %.2f" % (stat["drop"] - k * stat["se"])
    elif rule == "two":
        ok = abs(stat["drop"]) <= k * stat["se"]
        extra = "band +- %.2f" % (k * stat["se"])
    elif rule == "notup":
        ok = stat["arm"] <= stat["base"] + k * stat["se"]
        extra = "line <= %.2f" % (stat["base"] + k * stat["se"])
    else:
        ok = stat["arm"] >= stat["base"] - k * stat["se"]
        extra = "line >= %.2f" % (stat["base"] - k * stat["se"])
    return "%-46s base %7.2f  arm %7.2f  drop %7.2f  se %6.2f  %s  (n %d, fights differing %d): %s" % (
        label, stat["base"], stat["arm"], stat["drop"], stat["se"], extra, stat["n"], stat["differing"], "PASS" if ok else "FAIL"), ok


def main(argv):
    k = 1.645
    if "--k" in argv:
        i = argv.index("--k"); k = float(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
    r = read_dirs(argv[0], argv[1])
    for w in r["warnings"]:
        print("jam_ab: WARNING " + w)
    print("jam_ab: %d paired fights; left out (no JAM_CENSUS) %s" % (r["n"], r["skipped"] or "none"))
    b, a = r["rows"]["base"], r["rows"]["arm"]
    verdict = True
    for label, key, rule, deciding in (
            ("G jam-under-fire deaths (deciding gain)", "jam_uf", "gain", True),
            ("1 deaths in the open (guard, two-sided)", "open", "two", True),
            ("2 stuck deaths (guard)", "stuck", "notup", True),
            ("3 far loops, H1b (guard)", "far", "notup", True),
            ("4a kills (guard, two-sided)", "kills", "two", True),
            ("5 contacts in 3 s after a hit-ended give-way (guard)", "abort_contacts", "notup", True),
            ("R jam deaths, all kinds", "jam", "two", False),
            ("R all deaths", "all", "two", False),
            ("R standoffs (count)", "standoffs", "notup", False),
            ("R standoff seconds", "standoff_s", "notup", False),
            ("R give-ways ended by a hit (probe-read)", "aborts", "notup", False)):
        text, ok = line(label, paired(b[key], a[key]), k, rule)
        print(text if deciding else text.rsplit(":", 1)[0] + ": reported")
        if deciding:
            verdict = verdict and ok
    # hit rate: mean of fights, paired se of the mean
    d = [x - y for x, y in zip(a["hit_rate"], b["hit_rate"])]
    n = len(d)
    mean_b = sum(b["hit_rate"]) / n if n else 0.0
    mean_a = sum(a["hit_rate"]) / n if n else 0.0
    sd = math.sqrt(sum((x - sum(d) / n) ** 2 for x in d) / (n - 1)) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n else 0.0
    ok = mean_a >= mean_b - k * se
    print("4b hit rate (guard, one-sided): base %.3f arm %.3f, paired se of the mean %.4f, line >= %.3f: %s" % (mean_b, mean_a, se, mean_b - k * se, "PASS" if ok else "FAIL"))
    verdict = verdict and ok
    for side in ("base", "arm"):
        durs = sorted(r["durations"][side])
        print("R standoffs %s: %d%s; Movement counters %s" % (side, len(durs),
              (" (lasted s median %.1f, p90 %.1f, max %.1f)" % (durs[len(durs) // 2], durs[min(len(durs) - 1, 9 * len(durs) // 10)], durs[-1])) if durs else "",
              dict(r["counters"][side])))
    print("T6 %s (G and every guard; line 6 crossing arrivals read apart)" % ("PASS" if verdict else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1:])
