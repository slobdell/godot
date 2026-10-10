#!/usr/bin/env python3
"""Round 25 (brains F0): build/crossing-series.jsonl as a table, one line per run and a summary per case."""
import json
import sys
from collections import defaultdict

rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
cases = defaultdict(list)
for r in rows:
    key = (r.get("arena"), r.get("formation") + ("+drills" if r.get("drills") else ""), r.get("side"), r.get("arm", ""))
    if r.get("missing"):
        print("CROSSING %-9s %-7s %-5s seed=%s MISSING" % (key[0], key[1], key[2], r.get("seed")))
        continue
    cases[key].append(r)
    worst = max(r["stall_s"], key=lambda n: r["stall_s"][n]) if r["stall_s"] else ""
    print("CROSSING %-9s %-13s %-5s %s seed=%s crossed=%d/%d last=%5.1f arrived=%5.1f point_passes=%d seat_passes=%d "
          "overtakes=%d stall=%4.1fs(%s %s %s) wet_station=%.1fs reseats=%d route=%.0fm" % (
              key[0], key[1], key[2], key[3], r["seed"], r["crossed"], r["crews"], r["crossed_s"], r["arrived_s"],
              r["point_passes"], r["seat_passes"], r["overtakes"], r["stall_s"].get(worst, 0.0), worst[-3:],
              r["stall_at"].get(worst), r["stall_why"].get(worst), sum(r["wet_station_s"].values()), r["reseats"], r["route_m"]))
for key, rs in cases.items():
    n = len(rs)
    allx = sum(1 for r in rs if r["crossed"] == r["crews"])
    lasts = [r["crossed_s"] for r in rs if r["crossed_s"] >= 0]
    print("CASE %-9s %-13s %-5s %s n=%d all_across=%d/%d last_mean=%s point_passes=%s overtakes=%s max_stall=%.1fs" % (
        key[0], key[1], key[2], key[3], n, allx, n, ("%.1f" % (sum(lasts) / len(lasts))) if lasts else "-",
        [r["point_passes"] for r in rs], [r["overtakes"] for r in rs],
        max(max(r["stall_s"].values() or [0]) for r in rs)))
sys.exit(1 if any(r.get("missing") for r in rows) else 0)
