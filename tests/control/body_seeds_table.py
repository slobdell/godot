"""Round 35 extension (orders X3b): `make body-seeds-orders`'s lines as a per-seed table, then on - off over the seeds.

Each line: "<arm> s<seed> BODY_PROBE {...}". The stage's all-in (`arrived_s`) and each squad's arrival, per seed and arm;
then, for every arm other than `off`, (arm - off) all-in: mean, sd, worst, n.
"""
import json
import statistics
import sys


def main(path: str) -> None:
    rows: dict = {}
    for line in open(path):
        arm, seed, rest = line.split(" ", 2)
        rows.setdefault(seed, {})[arm] = json.loads(rest[len("BODY_PROBE "):])
    arms = sorted({a for r in rows.values() for a in r})
    squads = ("Sirens", "Hunters", "Hunters2")
    for seed, by_arm in rows.items():
        cells = []
        for arm in arms:
            d = by_arm.get(arm)
            if d is None:
                cells.append(f"{arm}: missing")
                continue
            cells.append(f"{arm}: all {d['arrived_s']:5.1f} " + " ".join(f"{s} {d[s]['arrived_s']:5.1f}" for s in squads))
        print(f"{seed:4} | " + " | ".join(cells))
    for arm in arms:
        if arm == "off":
            continue
        diffs = [r[arm]["arrived_s"] - r["off"]["arrived_s"] for r in rows.values() if arm in r and "off" in r]
        if len(diffs) >= 2:
            print(f"{arm} - off all-in: mean {statistics.mean(diffs):+.2f} s sd {statistics.stdev(diffs):.2f} "
                  f"worst {max(diffs):+.1f} n {len(diffs)}")


if __name__ == "__main__":
    main(sys.argv[1])
