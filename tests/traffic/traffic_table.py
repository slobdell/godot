#!/usr/bin/env python3
"""Round 26 (traffic T0): pool `make traffic-series` (build/traffic-series.jsonl) by map and case.

Per (arena, kind), over every seed and start tick:
  runs, all_in (runs where every crew arrived), crews arrived / crews,
  friend_stuck crew-seconds (mean per run, total), stuck crew-seconds (mean), contacts (mean), fast contacts (total),
  k-turns with a friend ahead (total), give-ways begun (mean),
  all-in s: per run, the last arrival of every crew of both squads (seconds from the order; a run where a crew never
         arrived counts as its end time, so a stuck crew can only raise it): median and mean over the runs,
  ratio: the crossing's last arrival of each squad over that squad's solo last arrival on the same seed and tick
         (median, worst; 'never' counts squads that did not all arrive in the crossing while they did alone).
  cross s (round 30, T3b): THE CROSSING'S OWN CLOCK, split from the far end's seating: per run, when both squads'
         last crew is past the meeting point (a run where one never is counts as its end time): median and mean, and
         the yielding squad's own (the squad with more crew-ticks slowed is not known per run; each squad's is printed).
Then the solo runs' own line (the clear-road reference) and the pass line pre-registered in the brief's Status.
"""
import json
import statistics
import sys
from collections import defaultdict


def load(path):
    rows = []
    for line in open(path):
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def all_in_s(r):
    """Every crew's last arrival in this run; a crew that never arrived counts as the run's end."""
    times = [t if t >= 0 else r["end_s"] for t in r["arrive_s"].values()]
    return max(times) if times else r["end_s"]


def cross_clear_s(r):
    """When both squads' last crew is past the meeting point (round 30, T3b); never = the run's end."""
    c = r.get("cross_clear_s")
    if c is None:
        return None
    return c if c >= 0 else r["end_s"]


def main(path):
    rows = load(path)
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    solo = {}
    for r in rows:
        if r["which"].startswith("solo_"):
            squad = r["which"][5:]
            solo[(r["arena"], r["kind"], squad, r["seed"], r["start_tick"])] = r.get("last_%s_s" % squad, -1.0)
    groups = defaultdict(list)
    for r in rows:
        groups[(r["arena"], r["kind"], "both" if r["which"] == "both" else "solo")].append(r)
    print("TRAFFIC_TABLE %s (%d runs, %d missing)" % (path, len(rows), len(missing)))
    header = "%-10s %-5s %-4s %4s %6s %9s %10s %8s %7s %8s %5s %6s %7s %6s %5s %8s %8s" % (
        "arena", "kind", "arm", "runs", "all_in", "crews", "fstuck/run", "fstuck", "stuck/r", "contact/r", "fast",
        "kt_fr", "yield/r", "ratio", "worst", "allin_md", "allin_mn")
    print(header)
    summary = {}
    for key in sorted(groups):
        arena, kind, arm = key
        g = groups[key]
        crews = sum(r["crews"] for r in g)
        arrived = sum(r["arrived"] for r in g)
        all_in = sum(1 for r in g if r["arrived"] == r["crews"])
        fstuck = [r["friend_stuck_s"] for r in g]
        allin = [all_in_s(r) for r in g]
        ratios = []
        never = 0
        if arm == "both":
            for r in g:
                for squad in ("a", "b"):
                    alone = solo.get((arena, kind, squad, r["seed"], r["start_tick"]))
                    together = r.get("last_%s_s" % squad, -1.0)
                    if alone is None or alone <= 0:
                        continue
                    if together < 0:
                        never += 1
                        continue
                    ratios.append(together / alone)
        line = {
            "runs": len(g), "all_in": all_in, "crews": "%d/%d" % (arrived, crews),
            "fstuck_mean": round(statistics.mean(fstuck), 1), "fstuck_total": round(sum(fstuck), 1),
            "stuck_mean": round(statistics.mean(r["stuck_s"] for r in g), 1),
            "contacts_mean": round(statistics.mean(r["contacts"] for r in g), 1),
            "fast_total": sum(r["contacts_fast"] for r in g),
            "xfast_total": sum(r.get("contacts_cross_fast", 0) for r in g),
            "verdicts": sum(r.get("tr_verdicts", 0) for r in g),
            "holds": sum(r.get("tr_holds", 0) for r in g),
            "hold_ticks": sum(r.get("tr_hold_ticks", 0) for r in g),
            "rel_passed": sum(r.get("tr_released_passed", 0) for r in g),
            "rel_cap": sum(r.get("tr_released_cap", 0) for r in g),
            "no_spot": sum(r.get("tr_no_spot", 0) for r in g),
            "cross_verdicts": sum(r.get("tr_cross_verdicts", 0) for r in g),
            "cross_slowed": sum(r.get("tr_cross_slowed", 0) for r in g),
            "wedged": sorted("s%s/t%s:%d" % (r["seed"], r.get("start_tick", "?"), r["crews"] - r["arrived"])
                             for r in g if r["crews"] - r["arrived"] > 1),
            "kturns_friend": sum(r["kturns_friend"] for r in g),
            "yields_mean": round(statistics.mean(r["yields"] for r in g), 1),
            "ratio_median": round(statistics.median(ratios), 2) if ratios else None,
            "ratio_worst": round(max(ratios), 2) if ratios else None, "never": never,
            "allin_median": round(statistics.median(allin), 1), "allin_mean": round(statistics.mean(allin), 1),
        }
        clears = [c for c in (cross_clear_s(r) for r in g) if c is not None]
        if clears:
            line["cross_median"] = round(statistics.median(clears), 1)
            line["cross_mean"] = round(statistics.mean(clears), 1)
            for squad in ("a", "b"):
                own = [r["cross_%s_s" % squad] if r["cross_%s_s" % squad] >= 0 else r["end_s"] for r in g
                       if "cross_%s_s" % squad in r]
                if own:
                    line["cross_%s_median" % squad] = round(statistics.median(own), 1)
        summary["%s/%s/%s" % key] = line
        print("%-10s %-5s %-4s %4d %6d %9s %10.1f %8.1f %7.1f %8.1f %5d %6d %7.1f %6s %5s %8.1f %8.1f%s" % (
            arena, kind, arm, line["runs"], all_in, line["crews"], line["fstuck_mean"], line["fstuck_total"],
            line["stuck_mean"], line["contacts_mean"], line["fast_total"], line["kturns_friend"], line["yields_mean"],
            line["ratio_median"], line["ratio_worst"], line["allin_median"], line["allin_mean"],
            ("  never %d" % never) if never else ""))
    print("between squads (fast contacts between the squads, same-squad fast; the hold's counters: squad-pair verdicts,"
          " crews sent to a spot, crew-ticks held, released passed / at the cap, no spot; the crossing's verdicts and crew-ticks"
          " slowed; runs with > 1 crew never in):")
    for key, line in sorted(summary.items()):
        if key.endswith("/both"):
            print("  %-22s xfast %4d  own %4d  verdicts %4d  holds %4d  held %6d  passed %4d  cap %3d  nospot %3d  xverd %4d  slowed %6d  wedged %s" % (
                key, line["xfast_total"], line["fast_total"] - line["xfast_total"], line["verdicts"], line["holds"],
                line["hold_ticks"], line["rel_passed"], line["rel_cap"], line["no_spot"], line["cross_verdicts"],
                line["cross_slowed"], " ".join(line["wedged"]) or "-"))
    print("the crossing's own clock (both squads past the meeting point; median / mean s; each squad's median):")
    for key, line in sorted(summary.items()):
        if "cross_median" in line:
            print("  %-22s cross %5.1f / %5.1f   A %5.1f  B %5.1f" % (key, line["cross_median"], line["cross_mean"],
                  line.get("cross_a_median", -1), line.get("cross_b_median", -1)))
    print("TRAFFIC_SUMMARY " + json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/traffic-series.jsonl")
