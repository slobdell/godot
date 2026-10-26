#!/usr/bin/env python3
"""Round 42 (manoeuvre Bar Q5, R41.10's frame): the no-pressing rule judged on WHAT HE SEES, over `make manoeuvre-probe-jam` logs of
his 5-squad across click (orders' O1 probe, crew headings, 4 maps) in two arms, paired by (arena, seed, headings). Written before
any number on the bar's seeds.

  Deciding (both must hold):
    D1 friendly contact ticks (ORDERS_PROBE.contact_ticks): ON pooled <= 0.8 x OFF pooled AND paired per-run mean < 0 by >= 2 se
    D2 shoved crew-ticks (JAM_EP.reverse_why "shoved": the hull moves backward with no reverse throttle, a hull in contact):
       ON pooled <= 0.8 x OFF pooled AND paired per-run mean < 0 by >= 2 se
  Strict guards (filed first):
    G5 every-squad-in mean: ON <= OFF + 1.645 se (paired; a never-in run reads as the window)
    G6 never-in runs: ON <= OFF (a count, no slack)
  Reported, never deciding (R41.10): jam-seconds; jam-seconds with the rule's own eased ticks taken out (JAM_EP.eased_ticks, the
  ticks the asker itself was easing under the rule); the rule's counters (nopush_ticks / episodes / capped) a run.
  The fight lines G1-G4 are follow_judge.py's (`--on-arm=nopush`), read beside this.

    python3 tests/manoeuvre/q5_judge.py DIR [--base=main] [--arm=nopush] [--window=90] [--ratio=0.8]
"""
import glob
import json
import math
import os
import statistics
import sys


def load(folder):
    runs = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        run, probe, squads, shoved, eased_s, jam_eps = None, None, [], 0, 0.0, 0
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_RUN "):
                    run = json.loads(line[8:])
                elif line.startswith("ORDERS_PROBE {"):
                    probe = json.loads(line[13:])
                elif line.startswith("ORDERS_PROBE_SQUAD "):
                    squads.append(json.loads(line[19:]))
                elif line.startswith("JAM_EP "):
                    ep = json.loads(line[7:])
                    jam_eps += 1
                    for why, ticks in ep.get("reverse_why", {}).items():
                        if why.split("+")[0] == "shoved":
                            shoved += int(ticks)
                    eased_s += float(ep.get("eased_s", 0.0))
        if run is None or probe is None:
            print("MISSING (no JAM_RUN / ORDERS_PROBE): %s" % os.path.basename(path))
            continue
        run["all_in_s"] = float(probe.get("all_in_s", -1.0))
        run["never_in_squads"] = sum(1 for s in squads if float(s.get("arrived_s", -1.0)) < 0)
        run["contact_ticks"] = int(probe.get("contact_ticks", 0))
        run["shoved_ticks"] = shoved
        run["eased_s"] = eased_s
        run["jam_eps"] = jam_eps
        runs[(run["arm"], run["arena"], run["seed"], run["headings"])] = run
    return runs


def paired(base, arm, keys, f):
    d = [f(arm[k]) - f(base[k]) for k in keys]
    mean_b = statistics.mean(f(base[k]) for k in keys) if keys else 0.0
    mean_a = statistics.mean(f(arm[k]) for k in keys) if keys else 0.0
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
    return mean_b, mean_a, statistics.mean(d) if d else 0.0, se


def main(argv):
    folder = argv[1]
    base_arm, on_arm, window, ratio = "main", "nopush", 90.0, 0.8
    for a in argv[2:]:
        if a.startswith("--base="):
            base_arm = a.split("=", 1)[1]
        elif a.startswith("--arm="):
            on_arm = a.split("=", 1)[1]
        elif a.startswith("--window="):
            window = float(a.split("=", 1)[1])
        elif a.startswith("--ratio="):
            ratio = float(a.split("=", 1)[1])
    runs = load(folder)
    base = {k[1:]: r for k, r in runs.items() if k[0] == base_arm}
    arm = {k[1:]: r for k, r in runs.items() if k[0] == on_arm}
    keys = sorted(set(base) & set(arm))
    missing = sorted(set(base) ^ set(arm))
    lines, ok = [], True

    def line(name, passed, text):
        nonlocal ok
        ok = ok and passed
        lines.append("%s %s: %s" % ("PASS" if passed else "FAIL", name, text))

    def deciding(name, key):
        pb = sum(base[k][key] for k in keys)
        pa = sum(arm[k][key] for k in keys)
        _, _, dm, se = paired(base, arm, keys, lambda r: float(r[key]))
        ratio_ok = pa <= ratio * pb
        sig_ok = se > 0 and dm < 0 and -dm >= 2.0 * se
        line(name, ratio_ok and sig_ok, "%d -> %d (%+.1f %%; line <= %.0f = %.2f x OFF) %s; paired mean %+.0f a run, se %.0f = %+.1f se %s" % (
            pb, pa, 100.0 * (pa - pb) / pb if pb else 0.0, ratio * pb, ratio, "ratio PASS" if ratio_ok else "ratio FAIL",
            dm, se, dm / se if se else 0.0, "(< 0 by >= 2 se) PASS" if sig_ok else "significance FAIL"))

    lines.append("paired runs: %d (unpaired: %s); arms %s -> %s" % (len(keys), ", ".join("%s s%s %s" % k for k in missing) or "none", base_arm, on_arm))
    deciding("D1 friendly contact ticks", "contact_ticks")
    deciding("D2 shoved crew-ticks", "shoved_ticks")
    allin = lambda r: r["all_in_s"] if r["all_in_s"] >= 0 else window
    b, a, _, se = paired(base, arm, keys, allin)
    line("G5 every-squad-in mean", a <= b + 1.645 * se,
         "%.1f -> %.1f s (never-in reads as %.0f; line <= %.1f = OFF + 1.645 x se %.2f)" % (b, a, window, b + 1.645 * se, se))
    nb = sum(1 for k in keys if base[k]["all_in_s"] < 0)
    na = sum(1 for k in keys if arm[k]["all_in_s"] < 0)
    sb = sum(base[k]["never_in_squads"] for k in keys)
    sa = sum(arm[k]["never_in_squads"] for k in keys)
    line("G6 never-in runs", na <= nb, "%d -> %d (line <= %d); never-in squads %d -> %d" % (nb, na, nb, sb, sa))
    jb = sum(float(base[k]["jam_s"]) for k in keys)
    ja = sum(float(arm[k]["jam_s"]) for k in keys)
    lines.append("reported jam-seconds %.0f -> %.0f (%+.1f %%)" % (jb, ja, 100.0 * (ja - jb) / jb if jb else 0.0))
    eb = sum(base[k]["eased_s"] for k in keys)
    ea = sum(arm[k]["eased_s"] for k in keys)
    lines.append("reported jam-seconds with the rule's own eased ticks taken out: %.0f -> %.0f (%+.1f %%; eased jam-s OFF %.0f, ON %.0f)" % (
        jb - eb, ja - ea, 100.0 * ((ja - ea) - (jb - eb)) / (jb - eb) if jb - eb else 0.0, eb, ea))
    c = [arm[k] for k in keys if "nopush_ticks" in arm[k]]
    if c:
        lines.append("reported %s counters a run (mean): eased crew-ticks %.0f, episodes %.0f, capped %.0f" % (
            on_arm, statistics.mean(float(r["nopush_ticks"]) for r in c), statistics.mean(float(r["nopush_episodes"]) for r in c),
            statistics.mean(float(r.get("nopush_capped", 0)) for r in c)))
    lines.append("per cell: " + " | ".join("%s s%s: contacts %d -> %d, shoved %d -> %d, all-in %.1f -> %.1f, never-in squads %d -> %d" % (
        k[0], k[1], base[k]["contact_ticks"], arm[k]["contact_ticks"], base[k]["shoved_ticks"], arm[k]["shoved_ticks"],
        base[k]["all_in_s"], arm[k]["all_in_s"], base[k]["never_in_squads"], arm[k]["never_in_squads"]) for k in keys))
    lines.append("VERDICT %s" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
