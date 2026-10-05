#!/usr/bin/env python3
"""Candidate sim-baseline lines, priced and compared across two trees (ship, round 18, stretch a).

    sim_variants.py run <godot> <sim_hz> <out.tsv>        every (variant, dealt map) once -> out.tsv, all at once
    sim_variants.py compare <before.tsv> <after.tsv>       which variants a change moved, on which maps

The question (the orchestrator, from brains' CP1 finding): brains' x18m -- a decision change in every unit's brain --
moved the baseline's line on foundry, yard and pit and NOT on terminus, crossing, sumps or locks, because the 40 s
baseline match on those maps takes no decision x18m changes. Which line would have seen it on every dealt map, and
what would it cost in check seconds? A variant is worth adding if the change moves it on all six dealt maps.

Each row: variant, map, state hash, the run's real seconds (MATCH_RESULT's own), its exit code.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

BASE = ["--match", "--elimination"]
BASELINE_DOCTRINES = ["--green-doctrine=res://doctrines/sim_baseline_green.json",
                      "--rust-doctrine=res://doctrines/sim_baseline_rust.json"]
# His setup (HANDOFF round 17: "Law on the champion v the CPU's Condemned"): both sides the CPU's budgeted armies.
HIS = ["--green-doctrine=cpu", "--rust-doctrine=cpu", "--green-faction=law", "--rust-faction=condemned"]
VARIANTS = {
    "base40": BASELINE_DOCTRINES + ["--time-limit=40", "--seed=3"],
    "base90": BASELINE_DOCTRINES + ["--time-limit=90", "--seed=3"],
    "base40s11": BASELINE_DOCTRINES + ["--time-limit=40", "--seed=11"],
    "his40": HIS + ["--time-limit=40", "--seed=3"],
    "his90": HIS + ["--time-limit=90", "--seed=3"],
    # His armies at HIS size (brains' his-frame series: --budget=4600 --control), where a peek at a laid gun happens.
    "his4600c60": HIS + ["--budget=4600", "--control", "--time-limit=60", "--seed=3"],
    "his4600c90": HIS + ["--budget=4600", "--control", "--time-limit=90", "--seed=3"],
}
# One tree, two arms (C18.5): SIM_VARIANTS_EXTRA is appended to every run (e.g. "--green-brain=x5p --rust-brain=x5p"),
# and SIM_VARIANTS_ONLY limits the variants (space-separated names).


def dealt(godot: str) -> list[str]:
    out = subprocess.run([godot, "--headless", "--path", ".", "--script", "res://tests/support/dealt_layouts.gd"],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith("DEALT_LAYOUTS "):
            data = json.loads(line[len("DEALT_LAYOUTS "):])
            return [data["default"]] + [m for m in data["rotation"] if m != data["default"]]
    raise SystemExit(f"no DEALT_LAYOUTS line:\n{out[-500:]}")


def one(godot: str, hz: str, variant: str, layout: str) -> str:
    extra = os.environ.get("SIM_VARIANTS_EXTRA", "").split()
    cmd = [godot, "--headless", "--fixed-fps", hz, "--path", ".", "--"] + BASE + VARIANTS[variant] + [f"--arena={layout}"] + extra
    run = subprocess.run(cmd, capture_output=True, text=True)
    value, secs = "-", "-"
    for line in run.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
            value, secs = str(result.get("state_hash", "-")), str(result.get("real_seconds", "-"))
    return f"{variant}\t{layout}\t{value}\t{secs}\t{run.returncode}"


def cmd_run(godot: str, hz: str, out: str) -> int:
    maps = dealt(godot)
    only = os.environ.get("SIM_VARIANTS_ONLY", "").split() or list(VARIANTS)
    jobs = [(v, m) for v in VARIANTS if v in only for m in maps]
    workers = int(os.environ.get("SIM_VARIANTS_JOBS") or 7)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        rows = list(pool.map(lambda j: one(godot, hz, j[0], j[1]), jobs))
    with open(out, "w") as f:
        f.write("\n".join(rows) + "\n")
    print("\n".join(rows))
    return 0 if all(r.split("\t")[2] != "-" and r.endswith("\t0") for r in rows) else 1


def read(path: str) -> dict[tuple[str, str], tuple[str, str]]:
    rows = {}
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 4:
            rows[(parts[0], parts[1])] = (parts[2], parts[3])
    return rows


def cmd_compare(before: str, after: str) -> int:
    a, b = read(before), read(after)
    variants = sorted({v for v, _ in a} & {v for v, _ in b}, key=list(VARIANTS).index)
    maps = []
    for _v, m in a:
        if m not in maps:
            maps.append(m)
    print("variant     " + " ".join(f"{m:>9}" for m in maps) + "   moved   s/run (max)")
    for v in variants:
        cells, moved, secs = [], 0, []
        for m in maps:
            x, y = a.get((v, m), ("-", "-")), b.get((v, m), ("-", "-"))
            changed = x[0] != y[0]
            moved += 1 if changed and m != "foundry" else 0
            cells.append("MOVED" if changed else "same")
            for s in (x[1], y[1]):
                try:
                    secs.append(float(s))
                except ValueError:
                    pass
        dealt_count = len([m for m in maps if m != "foundry"])
        print(f"{v:<11} " + " ".join(f"{c:>9}" for c in cells)
              + f"   {moved}/{dealt_count} dealt   {max(secs) if secs else '-'}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) == 5 and argv[1] == "run":
        return cmd_run(argv[2], argv[3], argv[4])
    if len(argv) == 4 and argv[1] == "compare":
        return cmd_compare(argv[2], argv[3])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
