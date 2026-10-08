#!/usr/bin/env python3
"""Round 23 (brains B0/B1): his case (a line whose own axis points at the click) as a table, per case x arm.

Rows are tests/tactics/pace_probe.gd's PACE_PROBE lines (`make pace-series`). Per case (arena, units, metres, layout,
shape) and arm (--pace=on|off): n, formed k of n and the median metre of the anchor's route at which every crew was
within 3 m of its shape station (and that as a share of the route), the RMS shape error over the transit and over the
first 10 s, the lead crew's mean speed share and element pace over the first 10 s, the lowest anchor pace, crews that
stopped dead (runs with any; episodes), and the medians of arrived, in-slot and stopped. Then, where both arms ran the
same seeds, the paired per-seed differences (on - off) of formed_m, arrived_s, in_slot_s and stopped_s. A run that
printed nothing is MISSING and fails (exit 1).

Usage: pace_table.py build/pace-series.jsonl
"""
import json
import math
import statistics
import sys


def _med(values):
    values = [v for v in values if v is not None and v >= 0]
    return f"{statistics.median(values):.1f}" if values else "-"


def _mean(values, digits=2):
    values = [v for v in values if v is not None]
    return f"{statistics.mean(values):.{digits}f}" if values else "-"


def _paired(name, pairs):
    if not pairs:
        return f"{name}: no pairs"
    diffs = [a - b for a, b in pairs]
    sd = statistics.stdev(diffs) if len(diffs) > 1 else 0.0
    return f"{name} on-off {statistics.mean(diffs):+.2f} +- {sd:.2f} (se {sd / math.sqrt(len(diffs)):.2f}, n {len(diffs)})"


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    cases = []
    for r in rows:
        key = (r["arena"], r["units"], r["metres"], r["layout"], r.get("shape", ""))
        if key not in cases:
            cases.append(key)
    print("| case | pace | n | formed k/n | formed_m med (frac) | rms / rms10 m | lead speed / pace 10 s | pace_min | "
          "stops runs (episodes) | arrived med | in_slot med | stopped med | worst slot m |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for key in cases:
        for arm in ("on", "off"):
            group = [r for r in rows if (r["arena"], r["units"], r["metres"], r["layout"], r.get("shape", "")) == key
                     and r.get("pace") == arm]
            if not group:
                continue
            formed = [r for r in group if r["formed_m"] >= 0]
            stops_runs = sum(1 for r in group if r["stops"] > 0)
            label = f"{key[0]} {key[1]} {key[2]:.0f} m {key[3]} {key[4]}"
            print(f"| {label} | {arm} | {len(group)} | {len(formed)}/{len(group)} | "
                  f"{_med([r['formed_m'] for r in group])} ({_med([r['formed_frac'] for r in group])}) | "
                  f"{_mean([r['rms_m'] for r in group], 1)} / {_mean([r['rms10_m'] for r in group], 1)} | "
                  f"{_mean([r['lead_speed'] for r in group])} / {_mean([r['lead_pace'] for r in group])} | "
                  f"{_mean([r['pace_min'] for r in group])} | {stops_runs} ({sum(r['stops'] for r in group)}) | "
                  f"{_med([r['arrived_s'] for r in group])} | {_med([r['in_slot_s'] for r in group])} | "
                  f"{_med([r['stopped_s'] for r in group])} | {_mean([r['worst_slot_m'] for r in group], 1)} |")
        on = {r["seed"]: r for r in rows if (r["arena"], r["units"], r["metres"], r["layout"], r.get("shape", "")) == key and r.get("pace") == "on"}
        off = {r["seed"]: r for r in rows if (r["arena"], r["units"], r["metres"], r["layout"], r.get("shape", "")) == key and r.get("pace") == "off"}
        seeds = sorted(set(on) & set(off))
        if seeds:
            for field in ("formed_m", "arrived_s", "in_slot_s", "stopped_s", "rms_m"):
                pairs = [(on[s][field], off[s][field]) for s in seeds if on[s][field] >= 0 and off[s][field] >= 0]
                print(f"  {key[0]} {key[1]} {key[3]} {key[4]}: {_paired(field, pairs)}")
    if missing:
        print(f"MISSING {len(missing)} runs: {missing}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
