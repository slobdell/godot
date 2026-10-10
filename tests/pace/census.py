#!/usr/bin/env python3
"""Round 25 pace P1: the quiet census from BRAINS_LOD lines (perf-fight logs named <prefix>-25-<arena>-main-<seed>.txt).

Per arena and in total: crew-ticks in the window, the fight rate's engaged and quiet shares (round 24's blunt quiet),
and the blunt quiet split by ThinkQuiet's first reason it is NOT quiet ("smart" = quiet by the smarter rule), plus
the options quiet crews held. Player and CPU crews are summed (the "p:" prefix is the player's side).
"""
import collections
import glob
import json
import re
import sys

LOD = re.compile(r"^BRAINS_LOD unit-ticks (\{.*?\}); thinks (\{.*?\}); first fight-rate tick (-?\d+)")


def merge(ticks):
    out = collections.Counter()
    for key, count in ticks.items():
        out[key[2:] if key.startswith("p:") else key] += count
    return out


def main(build, prefix):
    by_arena = collections.defaultdict(collections.Counter)
    thinks_by_arena = collections.defaultdict(collections.Counter)
    runs = collections.Counter()
    for path in sorted(glob.glob(f"{build}/{prefix}-25-*-main-*.txt")):
        arena = path.split(f"{prefix}-25-")[1].split("-main-")[0]
        for line in open(path, errors="replace"):
            m = LOD.match(line)
            if m:
                by_arena[arena] += merge(json.loads(m.group(1)))
                thinks_by_arena[arena] += merge(json.loads(m.group(2)))
                runs[arena] += 1
    if not runs:
        print(f"census: no BRAINS_LOD lines in {build}/{prefix}-*.txt")
        return 1
    total = collections.Counter()
    for c in by_arena.values():
        total += c
    by_arena["ALL"] = total
    runs["ALL"] = sum(runs.values())
    for arena, c in by_arena.items():
        plain = {k: v for k, v in c.items() if ":q." not in k}
        all_ticks = sum(plain.values())
        quiet = c.get("fight:quiet", 0)
        engaged = c.get("fight:engaged", 0)
        print(f"\n## {arena} ({runs[arena]} runs): {all_ticks} crew-ticks in the window")
        print(f"  fight engaged {engaged} ({engaged / max(all_ticks, 1):.1%}), fight quiet (round 24) {quiet} "
              f"({quiet / max(all_ticks, 1):.1%}), fight-rate quiet share {quiet / max(quiet + engaged, 1):.1%}")
        reasons = {k.split(":q.")[1]: v for k, v in c.items() if k.startswith("fight:quiet:q.") and ".opt." not in k}
        for reason, count in sorted(reasons.items(), key=lambda kv: -kv[1]):
            print(f"    {reason:8s} {count:7d}  {count / max(quiet, 1):6.1%} of round 24's quiet")
        options = {k.split(":q.opt.")[1]: v for k, v in c.items() if k.startswith("fight:quiet:q.opt.")}
        print("    options held while quiet: " + ", ".join(f"{o} {v / max(quiet, 1):.0%}" for o, v in
                                                          sorted(options.items(), key=lambda kv: -kv[1])))
        others = {k: v for k, v in plain.items() if not k.startswith("fight")}
        print("  other buckets: " + ", ".join(f"{k} {v / max(all_ticks, 1):.0%}" for k, v in sorted(others.items(), key=lambda kv: -kv[1])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build", sys.argv[2] if len(sys.argv) > 2 else "pace-census"))
