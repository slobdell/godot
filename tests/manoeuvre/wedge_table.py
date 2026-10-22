#!/usr/bin/env python3
"""Round 35 (manoeuvre W1): pool tests/manoeuvre/wedge_trace.gd logs.

usage: wedge_table.py <dir-of-logs> [--top N]

Prints: deaths by T5's cause; for the stuck:wedged deaths, what shaped the death tick and the last 3 s (force shares),
speed, what unstick saw, hits, order/option, Traffic holds; the N longest wedged-death episodes; all episodes' totals.
"""
import json
import statistics
import sys
from collections import Counter
from pathlib import Path


def rows(directory):
    eps, deaths, totals = [], [], []
    for log in sorted(Path(directory).glob("*.log")):
        for line in log.read_text(errors="replace").splitlines():
            for tag, sink in (("WEDGE_EP ", eps), ("WEDGE_DEATH ", deaths), ("WEDGE_TRACE ", totals)):
                if line.startswith(tag):
                    sink.append(json.loads(line[len(tag):]))
    return eps, deaths, totals


def share(counter):
    n = sum(counter.values()) or 1
    return ", ".join(f"{k} {100 * v / n:.0f}%" for k, v in counter.most_common())


def main():
    directory = sys.argv[1]
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 3
    eps, deaths, totals = rows(directory)
    causes = Counter()
    for t in totals:
        causes.update(t["totals"].get("by_cause", {}))
    n_deaths = sum(causes.values())
    print(f"fights {len(totals)}  deaths {n_deaths}  wedged deaths {causes['stuck:wedged']}"
          f" ({100 * causes['stuck:wedged'] / max(n_deaths, 1):.1f} %)")
    print("deaths by cause: " + share(causes))
    fires = [t["unstick_fires"] for t in totals if "unstick_fires" in t]
    print(f"unstick fires (WEDGE_TRACE totals): {sum(fires)} in {len(fires)} of {len(totals)} fights" if fires
          else "unstick fires: not printed (a WEDGE_TRACE from before round 37's M2)")
    uf = Counter()
    for t in totals:
        uf.update(t["totals"].get("by_cause_under_fire", {}))
    print(f"under fire (hit within 5 s): {sum(uf.values())}; jam under fire {sum(v for k, v in uf.items() if k.startswith('jam:'))}"
          f" (jam:yielding {uf['jam:yielding']}, jam:friend {uf['jam:friend']})")
    ht = sum(t["totals"].get("halt_ticks", 0) for t in totals)
    hc = sum(t["totals"].get("halt_creep_ticks", 0) for t in totals)
    hh = sum(t["totals"].get("halt_creep_held_ticks", 0) for t in totals)
    print(f"wheeled pace-0 drive ticks {ht}, moving >= 0.5 m/s (creep) {hc} ({100 * hc / max(ht, 1):.0f} %), of those held {hh}")
    if not deaths:
        return
    at_death, last3, units, options, orders = Counter(), Counter(), Counter(), Counter(), Counter()
    speeds, hit10, stall3, held, touch = [], [], 0, 0, 0
    for d in deaths:
        tl = d["timeline"]
        last = tl[-1]
        at_death[last["force"]] += 1
        for s in tl[-6:]:
            last3[s["force"]] += 1
        speeds.append(last["mps"])
        hit10.append(1 if last.get("since_hit_s", 999) <= 10.0 else 0)
        stall3 += any(s["stall"] for s in tl[-6:])
        held += bool(last["held"])
        touch += bool(last["touch_hull"])
        options[last["option"]] += 1
        orders[last["order"] or "(none)"] += 1
    for e in eps:
        if e["died"]:
            units[e["unit"]] += 1
    n = len(deaths)
    print(f"\nstuck:wedged deaths traced: {n}")
    print("  force on the death tick: " + share(at_death))
    print("  force over the last 3 s: " + share(last3))
    print(f"  speed at death median {statistics.median(speeds):.2f} m/s; >= 0.5 m/s {sum(s >= 0.5 for s in speeds)}/{n}")
    print(f"  hit in the last 10 s {sum(h > 0 for h in hit10)}/{n}; stall rule counting in the last 3 s {stall3}/{n};"
          f" Traffic hold at death {held}/{n}; touching a hull {touch}/{n}")
    print("  option at death: " + share(options))
    print("  order at death: " + share(orders))
    print("  units: " + share(units))
    died = sorted((e for e in eps if e["died"]), key=lambda e: -e["s"])
    print(f"\nthe {top} longest wedged-death episodes:")
    for e in died[:top]:
        print(f"  {e['arena']} s{e['seed']} {e['crew']} ({e['unit']}) {e['s']} s wedged at ({e['x']}, {e['z']}),"
              f" net {e['net_m']} m, median {e['mps_med']} m/s; force {e['by_force']}; phase {e['phase']};"
              f" stall ticks {e['stall_ticks']}, unstick fires {e['unstick_fires']}; option {e['options']};"
              f" order {e['orders']}; friends<=14m max {e['friends_max']}, enemies<=56m max {e['enemies_max']}")
    allf = Counter()
    for e in eps:
        allf.update(e["by_force"])
    print(f"\nall wedged episodes: {len(eps)}, {sum(e['s'] for e in eps):.0f} s; force share: " + share(allf))


if __name__ == "__main__":
    main()
