#!/usr/bin/env python3
"""Round 48 (manoeuvre M1): YTRACE rows (tests/manoeuvre/yield_trace.gd) as a compact per-crew table, one line per state change
(or every --every ticks). Measurement only.
  python3 tests/manoeuvre/ytrace_table.py build/light/build/manoeuvre/yield-trace/crossing-13215.log [--every 30] [--crew a,b]"""
import json, sys, argparse

KEYS = ("phase", "blocked", "yield_to", "yspot", "verb", "choice", "move", "his_post", "under_way", "fire_post", "under_fire",
        "last_y", "pass_by", "hold", "ahead")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--every", type=int, default=0)
    ap.add_argument("--crew", default="")
    a = ap.parse_args()
    want = set(a.crew.split(",")) if a.crew else None
    last = {}
    for line in open(a.log, errors="replace"):
        if not line.startswith("YTRACE {"):
            continue
        r = json.loads(line[7:])
        n = r["n"]
        if want and n not in want:
            continue
        sig = tuple(str(r.get(k)) for k in KEYS)
        prev = last.get(n)
        if prev is not None and prev[0] == sig and not (a.every and r["tick"] - prev[1] >= a.every):
            continue
        last[n] = (sig, r["tick"])
        print("%5d %-20s L%d pos=%s yaw=%s v=%.1f hp=%s %s/%s mv=%s post=%s ph=%s blk=%s y=%s %s last=%s pass=%s fp=%s uf=%s uw=%s rem=%s stl=%s ahead=%s@%s hits=%s" % (
            r["tick"], n, r["lvl"], r["pos"], r["yaw"], r["v"], r["hp"], r.get("verb"), r.get("choice"), r["move"],
            r.get("post") if r.get("his_post") else "-", r["phase"], r["blocked"], r["yield_to"], r["yspot"], r["last_y"],
            r["pass_by"], int(r["fire_post"]), int(r["under_fire"]), int(r["under_way"]), r["rem"], r["stalled"], r["ahead"],
            r["ahead_m"], ",".join(r["hits"])))


if __name__ == "__main__":
    main()
