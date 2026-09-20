#!/usr/bin/env python3
"""Write the synthetic trajectory fixtures, and a README naming each one's HAND-COMPUTED answer.

`make metrics-fixtures` writes these and runs `make metrics` over them: the end-to-end smoke test that the tool
runs at all, beside the unit tests that check what it computes. The answers in the README are derived in
`test_metrics.py` (on paper, not from a first run), so a fixture whose printed number stops matching its README
row is a real regression and not a re-baselining exercise.
"""

from __future__ import annotations

import math
import os
import subprocess
import sys

import metrics
import trajlog
from trajlog import Header, Sample

TICK_RATE = 30
## heading_rad for a hull facing +x, in fight_probe.gd's convention: heading = atan2(-fwd.x, -fwd.z).
FACING_X = -math.pi / 2.0


def commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
    except Exception:
        return "unknown"


def sample(tick, x, z=0.0, speed=0.0, unit="U1", unit_id="scout", heading=FACING_X, **kwargs):
    row = dict(
        tick=tick, unit=unit, unit_id=unit_id, team=0, x=float(x), z=float(z), heading_rad=float(heading),
        speed_mps=float(speed), gear=0, goal_x=None, goal_z=None, order_verb=None, element=None,
        slot_x=None, slot_z=None,
    )
    row.update(kwargs)
    return Sample(**row)


def header(name: str, knobs: dict) -> Header:
    return Header(commit=commit(), machine=os.uname().nodename, tick_rate=TICK_RATE, producer="synthetic",
                  arena=None, seed=None, command="tools/metrics/make_fixtures.py (%s)" % name, knobs=knobs)


def straight(ticks=600):
    """Drives in a straight line at a dead constant 6 m/s: efficiency 1.000, no cusps, the smoothest SPARC there is."""
    step = 6.0 / TICK_RATE
    return [
        sample(t, t * step, speed=6.0, unit="Straight_1", unit_id="rig",
               goal_x=10_000.0, goal_z=0.0, order_verb="move")
        for t in range(ticks)
    ]


def _legs(ticks, unit, unit_id, speed, forward_ticks, back_ticks):
    """A back-and-forth drive whose legs are whole numbers of TICKS, so the 4 s window holds a whole number of
    cycles and the answer is exact rather than nearly right. (The first version of this fixture turned on a
    distance test at 6 m/s, which put 2.4 cycles in a window and gave 0.571 where the arithmetic says 0.600.)"""
    period = forward_ticks + back_ticks
    step = speed / TICK_RATE
    out, x = [], 0.0
    for t in range(ticks):
        direction = 1.0 if (t % period) < forward_ticks else -1.0
        out.append(sample(t, x, speed=speed * direction, unit=unit, unit_id=unit_id,
                          goal_x=10_000.0, goal_z=0.0, order_verb="attack_move"))
        x += step * direction
    return out


def shuffle(ticks=600):
    """The 8 m-out / 2 m-back signature at 5 m/s: 48 ticks out, 12 ticks back, so a 120-tick window holds exactly
    two 10 m cycles -- path 20 m, net 12 m, efficiency 0.600 in EVERY window, and 0.600 is above the 0.25
    threshold, which is the whole argument for a continuous metric."""
    return _legs(ticks, "Shuffle_1", "scout", 5.0, 48, 12)


def pinned(ticks=600):
    """6 m forward, 4 m back, forever: a unit stuck at a barrier. 36 ticks out, 24 back at 5 m/s, so a 120-tick
    window holds exactly two 10 m cycles -- path 20 m, net 4 m, efficiency 0.200 < 0.25, oscillating on every
    full window. This is the pathology the lead described."""
    return _legs(ticks, "Pinned_1", "scout", 5.0, 36, 24)


def wedge_element(ticks=600):
    """Four units driving as an element, one of them 3 m out of its slot the whole time: the affine residual is
    exactly 3/4 = 0.750 m (test_metrics.AffineFormationResidualTest), and every other metric is clean."""
    square = [(1.0, 1.0), (1.0, -1.0), (-1.0, 1.0), (-1.0, -1.0)]
    step = 6.0 / TICK_RATE
    out = []
    for t in range(ticks):
        for i, (nx, nz) in enumerate(square):
            slot_x, slot_z = nx + t * step, nz
            x = slot_x + (3.0 if i == 0 else 0.0)
            out.append(sample(t, x, slot_z, speed=6.0, unit="Wedge_%d" % i, unit_id="tank",
                              goal_x=10_000.0, goal_z=0.0, order_verb="move",
                              element=1, slot_x=slot_x, slot_z=slot_z))
    return out


def jerky(ticks=600):
    """Drives straight but with a heavily modulated speed: efficiency 1.000 and zero cusps -- and a SPARC well
    below `straight`. The fixture that shows the four metrics are not the same metric."""
    out = []
    x = 0.0
    for t in range(ticks):
        speed = 6.0 + 2.5 * math.sin(2.0 * math.pi * 8.0 * t / 256.0) + 1.5 * math.sin(2.0 * math.pi * 17.0 * t / 256.0)
        out.append(sample(t, x, speed=speed, unit="Jerky_1", unit_id="rig",
                          goal_x=10_000.0, goal_z=0.0, order_verb="move"))
        x += speed / TICK_RATE
    return out


FIXTURES = {
    "straight": (straight, "a dead constant 6 m/s in a straight line", [
        "efficiency 1.000 in every window (the definition: net == path)",
        "oscillating_share 0.000",
        "0 cusps",
        "SPARC -1.923: the smoothest profile there is (the Hann kernel alone)",
    ]),
    "shuffle": (shuffle, "the 8 m-out / 2 m-back signature at 5 m/s (48 ticks out, 12 back)", [
        "efficiency 0.600: a 120-SAMPLE window spans 119 intervals, just short of two whole 10 m cycles, so",
        "  individual windows sit within 0.005 of the exact two-cycle value and the mean is 0.600",
        "oscillating_share 0.000 -- 0.600 is well above the 0.25 threshold. THE THRESHOLD CANNOT SEE THIS UNIT,",
        "  and the continuous metric can: that is the argument for A12 in one fixture",
        "19 cusps = 57/agent-minute: 10 cycles in 600 ticks, two turns each, less the first (no prior direction)",
    ]),
    "pinned": (pinned, "6 m forward, 4 m back, forever: a unit stuck at a barrier (36 ticks out, 24 back)", [
        "efficiency 0.200: net 4 m / path 20 m (again within 0.005 per window, see `shuffle`)",
        "oscillating on every FULL window (0.200 < 0.25 with path 20 m >= 8 m)",
        "oscillating_share 0.802 = 481/600, NOT 1.000: round 8's denominator counts every under-way tick,",
        "  including the 119 before the first window closes. That clause is why the share reproduces",
        "19 cusps = 57/agent-minute",
    ]),
    "wedge": (wedge_element, "four units in formation, one 3 m out of its slot", [
        "affine formation residual exactly 0.750 m (= 3 m / 4 on the unit square)",
        "efficiency 1.000 and 0 cusps: being out of your slot is not being jerky",
    ]),
    "jerky": (jerky, "a straight line driven with a heavily modulated speed", [
        "efficiency 1.000 and 0 cusps -- position-space metrics see nothing",
        "SPARC well below straight's -1.923: the speed profile is what is wrong",
    ]),
}


def main(argv=None):
    out_dir = (argv or sys.argv[1:])[0] if (argv or sys.argv[1:]) else "build/metrics/fixtures"
    os.makedirs(out_dir, exist_ok=True)
    readme = ["# Synthetic trajectory fixtures (`make metrics-fixtures`)",
              "",
              "Written by `tools/metrics/make_fixtures.py`. Every expected value below is HAND-COMPUTED and",
              "asserted in `tools/metrics/test_metrics.py`; none of them was read off a first run.",
              "Reproduce: `make metrics-fixtures`.",
              ""]
    for name, (builder, description, answers) in FIXTURES.items():
        samples = builder()
        path = os.path.join(out_dir, "%s.jsonl" % name)
        trajlog.write_log(path, header(name, {"ticks": len(samples), "tick_rate": TICK_RATE}), samples)
        readme += ["## `%s.jsonl` — %s" % (name, description), ""]
        readme += ["- %s" % line for line in answers]
        readme += [""]
        print("metrics fixtures: wrote %s (%d samples)" % (path, len(samples)))
    with open(os.path.join(out_dir, "README.md"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(readme))
    return 0


if __name__ == "__main__":
    sys.exit(main())
