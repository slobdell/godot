#!/usr/bin/env python3
"""Round 41 (manoeuvre Q1, the jam census): pool `make manoeuvre-probe-jam` logs (JAM_EP / JAM_RUN rows from
tests/manoeuvre/probe_jam.gd beside the probe's own ORDERS_PROBE rows) into the census the brief asks for, per arm x headings:
jam-seconds by what the blocker was doing, by what the asker did, and the share of jam-seconds whose blocker had cleared the
asker's frozen lane within N s (the "wait, don't detour" counterfactual); the longest episodes; each run's all-in time.

    python3 tests/manoeuvre/probe_jam_table.py DIR [--top N] [--jsonl OUT]
"""
import collections
import glob
import json
import os
import statistics
import sys

WAIT_N = ["2", "3", "5", "8"]
CLASSES = ["turning", "crossing", "same_way", "head_on", "stalled", "parked"]


def load(folder):
    runs, eps = [], []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        run, probe, these = None, None, []
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_EP "):
                    these.append(json.loads(line[7:]))
                elif line.startswith("JAM_RUN "):
                    run = json.loads(line[8:])
                elif line.startswith("ORDERS_PROBE {"):
                    probe = json.loads(line[13:])
        name = os.path.basename(path)[:-4]
        if run is None:
            print("MISSING (no JAM_RUN line): %s" % name)
            continue
        run["file"] = name
        run["all_in_s"] = probe.get("all_in_s", -1.0) if probe else -1.0
        run["contact_ticks"] = probe.get("contact_ticks", -1) if probe else -1
        runs.append(run)
        for e in these:
            e["file"] = name
        eps.extend(these)
    return runs, eps


def key(r):
    return "%s/headings=%s" % (r["arm"], r["headings"])


def pct(part, whole):
    return 100.0 * part / whole if whole else 0.0


def main(argv):
    folder = argv[1]
    top = 8
    out = None
    for a in argv[2:]:
        if a.startswith("--top="):
            top = int(a.split("=", 1)[1])
        elif a.startswith("--jsonl="):
            out = a.split("=", 1)[1]
    runs, eps = load(folder)
    if out:
        with open(out, "w") as f:
            for e in eps:
                f.write(json.dumps(e) + "\n")
    groups = collections.defaultdict(list)
    for r in runs:
        groups[key(r)].append(r)
    ep_groups = collections.defaultdict(list)
    for e in eps:
        ep_groups[key(e)].append(e)
    print("== runs by arm x headings: n, never-in runs, all-in median s, jam-seconds a run (mean), episodes a run, held s, slowed-by-nobody s")
    for k in sorted(groups):
        rs = groups[k]
        never = [r for r in rs if r["all_in_s"] < 0]
        ins = [r["all_in_s"] for r in rs if r["all_in_s"] >= 0]
        print("  %-24s runs %2d never-in %2d all-in med %6.1f s | jam %6.1f s/run  eps %5.1f/run | held %5.1f s  no-blocker %5.1f s | native_drive %s" % (
            k, len(rs), len(never), statistics.median(ins) if ins else -1.0,
            statistics.mean(r["jam_s"] for r in rs), statistics.mean(r["episodes"] for r in rs),
            statistics.mean(r["held_s"] for r in rs), statistics.mean(r["no_blocker_s"] for r in rs),
            sorted({str(r.get("native_drive")) for r in rs})))
    for k in sorted(ep_groups):
        es = ep_groups[k]
        total = sum(e["s"] for e in es)
        print("\n== %s: %d episodes, %.1f jam-seconds over %d runs" % (k, len(es), total, len(groups[k])))
        print("  by what the BLOCKER was doing (episode mode): jam-s, share, episodes, median s, share of those jam-s whose blocker cleared the frozen lane within N s")
        for c in CLASSES + sorted(set(e["class_mode"] for e in es) - set(CLASSES)):
            ce = [e for e in es if e["class_mode"] == c]
            if not ce:
                continue
            cs = sum(e["s"] for e in ce)
            waits = []
            for n in WAIT_N:
                w = sum(e["s"] for e in ce if 0 <= e["t_clear"] <= float(n))
                waits.append("<=%ss %3.0f%%" % (n, pct(w, cs)))
            never = sum(e["s"] for e in ce if e["t_clear"] < 0)
            print("    %-9s %7.1f s %5.1f %%  eps %4d  med %4.1f s | %s | never-cleared %3.0f%%" % (
                c, cs, pct(cs, total), len(ce), statistics.median(e["s"] for e in ce), "  ".join(waits), pct(never, cs)))
        print("  by what the ASKER did: jam-s, share, episodes")
        for a, s in sorted(collections.Counter({a: sum(e["s"] for e in es if e["action"] == a)
                                                for a in set(e["action"] for e in es)}).items(), key=lambda kv: -kv[1]):
            n = sum(1 for e in es if e["action"] == a)
            print("    %-9s %7.1f s %5.1f %%  eps %4d" % (a, s, pct(s, total), n))
        print("  the counterfactual over ALL jam-seconds: blocker cleared the frozen lane within  " + "  ".join(
            "<=%ss %3.0f%%" % (n, pct(sum(e["s"] for e in es if 0 <= e["t_clear"] <= float(n)), total)) for n in WAIT_N))
        lane = [e for e in es if e.get("lane_start", True)]
        lane_s = sum(e["s"] for e in lane)
        print("  ...over the %d episodes (%.1f s = %.0f %%) whose blocker WAS in the asker's lane at the start:  " % (len(lane), lane_s, pct(lane_s, total))
              + "  ".join("<=%ss %3.0f%%" % (n, pct(sum(e["s"] for e in lane if 0 <= e["t_clear"] <= float(n)), lane_s)) for n in WAIT_N)
              + "  never %3.0f%%" % pct(sum(e["s"] for e in lane if e["t_clear"] < 0), lane_s))
        faster = sum(e["s"] for e in es if 0 <= e["t_clear"] < e["s"])
        print("  jam-seconds in episodes the blocker cleared BEFORE the episode ended (waiting would have been shorter than what happened): %.1f s = %.0f %%" % (
            faster, pct(faster, total)))
        same = sum(e["s"] for e in es if e["same_squad"])
        wheeled = sum(e["s"] for e in es if e["wheeled"])
        bw = sum(e["s"] for e in es if e.get("blocker_wheeled", False))
        print("  same-squad blocker %.0f %% of jam-s; wheeled asker %.0f %%; wheeled blocker %.0f %%; episodes >= 3 s: %d (%.1f s); >= 8 s: %d" % (
            pct(same, total), pct(wheeled, total), pct(bw, total), sum(1 for e in es if e["s"] >= 3), sum(e["s"] for e in es if e["s"] >= 3),
            sum(1 for e in es if e["s"] >= 8)))
        print("  blocker heading off the asker's at the start (deg), jam-s weighted: <45 %.0f %%, 45-135 %.0f %%, >135 %.0f %%" % (
            pct(sum(e["s"] for e in es if e["blocker_heading_off_deg"] < 45), total),
            pct(sum(e["s"] for e in es if 45 <= e["blocker_heading_off_deg"] <= 135), total),
            pct(sum(e["s"] for e in es if e["blocker_heading_off_deg"] > 135), total)))
        print("  longest %d episodes: s, t_clear, class (start -> mode), action, asker (sq) <- blocker (sq), at, start, file" % top)
        for e in sorted(es, key=lambda e: -e["s"])[:top]:
            print("    %5.1f s  clear %5s  %-8s -> %-8s %-8s %-22s (sq%d) <- %-22s (sq%d) at %s t+%.0fs lat %.1f m  %s" % (
                e["s"], ("%.1f" % e["t_clear"]) if e["t_clear"] >= 0 else "never", e["class_start"], e["class_mode"], e["action"],
                e["asker"], e["asker_squad"], e["blocker"], e["blocker_squad"], e["at"], e["start_s"], e["lateral_m"], e["file"]))


if __name__ == "__main__":
    main(sys.argv)
