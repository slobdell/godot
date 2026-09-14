#!/usr/bin/env python3
"""Compare deterministic-spike runs from different builds: `make det-spike`.

Usage: det_spike_compare.py <label>=<log> [<label>=<log> ...]

Each log holds DET_SPIKE_CHECKPOINT tick=N hash=H lines and one DET_SPIKE_RESULT {json} line
(printed by game/modes/det_spike_mode.gd; browser logs have a "[browser:log] " prefix).
Exits 0 when every run reached the same checkpoints with identical hashes, 1 otherwise, naming the
first tick where they diverge.
"""
import json
import re
import sys


def parse(path):
    checkpoints, result = {}, None
    with open(path, encoding="utf-8", errors="replace") as log:
        for line in log:
            if m := re.search(r"DET_SPIKE_CHECKPOINT tick=(\d+) hash=(\w+)", line):
                checkpoints[int(m.group(1))] = m.group(2)
            elif "DET_SPIKE_RESULT " in line:
                result = json.loads(line.split("DET_SPIKE_RESULT ", 1)[1])
    return checkpoints, result


def main():
    runs = {}
    for arg in sys.argv[1:]:
        label, path = arg.split("=", 1)
        runs[label] = parse(path)
    ok = True
    for label, (checkpoints, result) in runs.items():
        if result is None:
            print(f"DET_SPIKE {label}: no DET_SPIKE_RESULT (did the run finish?)")
            ok = False
            continue
        print(f"DET_SPIKE {label}: hash={result['hash']} ticks={result['ticks']} tanks={result['tanks']} "
              f"shots={result['shots']} hits={result['hits']} kills={result['kills']} "
              f"usec_per_tick={result['usec_per_tick']} (worst batch {result['worst_batch_usec_per_tick']}) "
              f"budget_at_30hz={result['budget_used_at_30hz']:.1%}")
    if not ok:
        return 1
    labels = list(runs)
    reference = runs[labels[0]][0]
    for label in labels[1:]:
        other = runs[label][0]
        for tick in sorted(set(reference) | set(other)):
            if reference.get(tick) != other.get(tick):
                print(f"DET_SPIKE DIVERGED: {labels[0]} vs {label} first differ at tick {tick} "
                      f"({reference.get(tick)} vs {other.get(tick)})")
                return 1
        if runs[labels[0]][1]["hash"] != runs[label][1]["hash"]:
            print(f"DET_SPIKE DIVERGED: final hashes differ ({labels[0]} vs {label})")
            return 1
    print(f"DET_SPIKE IDENTICAL across {', '.join(labels)}: {len(reference)} checkpoints, final {runs[labels[0]][1]['hash']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
