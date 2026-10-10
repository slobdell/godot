"""Round 25 (native, N5a): where the opening clash sits in a match's time, from its recordings (the black box), so a
TickProfile window (`--native-tick-profile=A,B`) is chosen to hold the fight on a map, not the drive to it.
Usage: fight_onset.py RECORDING [RECORDING...]  (.jsonl or .jsonl.gz). Per recording: the arena, the first hit, the
first kill, hits per 2 s bin, hulls alive at 8/12/16/20/25/30/36 s."""
import gzip, json, sys
from collections import Counter

TICK_RATE = 30.0

for path in sys.argv[1:]:
    opener = gzip.open if path.endswith(".gz") else open
    arena, units, hits, deaths = "?", 0, Counter(), []
    with opener(path, "rt") as handle:
        for line in handle:
            if not line.strip():
                continue
            r = json.loads(line)
            t = r.get("t")
            if t == "match":
                arena, units = r.get("arena", "?"), len(r.get("units", []))
            elif t == "hit":
                hits[int(r["tick"] / TICK_RATE // 2) * 2] += 1
            elif t == "dead":
                deaths.append(r["tick"] / TICK_RATE)
    first_hit = min(hits) if hits else None
    print(f"{path}: {arena}, {units} hulls; first hit in [{first_hit}, +2) s; first kill "
          f"{min(deaths):.1f} s" if deaths else f"{path}: {arena}, {units} hulls; no kill")
    print("   hits per 2 s: " + " ".join(f"{s}:{hits[s]}" for s in sorted(hits) if s < 40))
    print("   alive: " + " ".join(f"{s}s {units - sum(1 for d in deaths if d < s)}" for s in (8, 12, 16, 20, 25, 30, 36)))
