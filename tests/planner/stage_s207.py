#!/usr/bin/env python3
"""Round 32 (CP-Q's park, the round-33 candidate): the Terminus seed 207 stage. The drive is deterministic, so one run an
arm is the case: under `--planner-queue=shared-rolling` (the first cut: refuse early from the ROLLING pose) Green_S0_4
pins on Block_7 for ~2043 plant-contact ticks (traced at bc56ef9c); under `--planner-queue=shared` (refuse early only
at rest) it must not. Reads each log's NAV_DRIVE episodes.
Usage: stage_s207.py rolling=<log> shared=<log>   (exit 0 = the stage reproduces AND the fix holds; 1 otherwise)
"""
import json
import sys

UNIT = "Green_S0_4"
COLLIDER = "Block_7"
REPRODUCES_AT_LEAST = 1000   # the first cut's pin (2043 traced): the stage must show it, or it proves nothing
FIXED_AT_MOST = 300          # the FIFO's own run of this seed had 0 on Block_7; its worst rig pin elsewhere was 187


def pinned(path):
    drive = None
    with open(path, errors="replace") as handle:
        for line in handle:
            if line.startswith("NAV_DRIVE {"):
                drive = json.loads(line[len("NAV_DRIVE "):], strict=False)
    if drive is None:
        return None, None
    ticks = sum(int(e.get("ticks", 0)) for e in drive.get("episodes", [])
                if e.get("unit") == UNIT and e.get("collider") == COLLIDER and e.get("cause") == "plant")
    total = sum(int(e.get("ticks", 0)) for e in drive.get("episodes", []) if e.get("cause") == "plant")
    return ticks, total


def main(argv):
    arms = dict(arg.split("=", 1) for arg in argv[1:])
    rolling, rolling_total = pinned(arms["rolling"])
    shared, shared_total = pinned(arms["shared"])
    if rolling is None or shared is None:
        print("STAGE_S207 REFUSED: a run has no NAV_DRIVE line")
        return 1
    reproduces = rolling >= REPRODUCES_AT_LEAST
    fixed = shared <= FIXED_AT_MOST
    print("STAGE_S207 %s on %s plant ticks: shared-rolling %d (all rigs %d) -> %s | shared %d (all rigs %d) -> %s" % (
        UNIT, COLLIDER, rolling, rolling_total, "reproduces" if reproduces else "DOES NOT REPRODUCE",
        shared, shared_total, "FIXED" if fixed else "STILL PINNED"))
    return 0 if reproduces and fixed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
