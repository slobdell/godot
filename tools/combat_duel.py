#!/usr/bin/env python3
"""Combat X2-X4: watch a small fight tick by tick, as text (`make duel GREEN_UNITS=tank RUST_UNITS=tank`).

Builds one squad per side from unit ids (repeats allowed: "scout,scout"), runs one seeded headless elimination match
with --combat-log, and prints a timeline: shots, hits (face, damage, weak spots, kills), and every POSE_EVERY seconds
each unit's position, heading, speed, health, and brain intent, plus the distance between the first unit of each
side. The raw COMBAT_EVENT lines are saved to build/duel/events.jsonl.

Usage: combat_duel.py --godot PATH [--green tank] [--rust tank] [--seed 1] [--time-limit 90] [--arena foundry]
                      [--tune unit.stat=v,...] [--role assault] [--pose-every 1.0] [--meet 30,0]
"""
import argparse
import json
import math
import os
import subprocess
import sys

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build", "duel")


def army(side, units, role, meet):
    """Both sides advance on the same world point `meet` (x, z). Objectives are team-relative (Green's right is +x
    and forward -z; Rust's are mirrored), and without one the brains drive straight at each other's base, which on a
    point-symmetric arena keeps the center crate between two lone units the whole way (they pass unseen)."""
    x, z = meet
    objective = {"right": x, "forward": -z, "radius": 12.0} if side == "green" else {"right": -x, "forward": z, "radius": 12.0}
    return {"name": f"{side} duel", "squads": [{"name": "Duel", "directive": {"role": role, "objective": objective},
                                               "units": [{"unit": unit} for unit in units]}]}


def heading(fx, fz):
    """Compass-style degrees: 0 = north (-z), 90 = east (+x)."""
    return round(math.degrees(math.atan2(fx, -fz))) % 360


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--green", default="tank")
    parser.add_argument("--rust", default="tank")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--time-limit", type=int, default=90)
    parser.add_argument("--arena", default="")
    parser.add_argument("--tune", default="")
    parser.add_argument("--role", default="assault")
    parser.add_argument("--pose-every", type=float, default=1.0)
    parser.add_argument("--meet", default="30,0", help="world x,z both sides advance on")
    args = parser.parse_args()

    os.makedirs(BUILD, exist_ok=True)
    for side, units in (("green", args.green), ("rust", args.rust)):
        with open(os.path.join(BUILD, f"{side}.json"), "w") as handle:
            json.dump(army(side, [u for u in units.split(",") if u], args.role,
                           [float(v) for v in args.meet.split(",")]), handle)
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ROOT, "--", "--match", "--elimination", "--combat-log",
               "--green-doctrine=res://build/duel/green.json", "--rust-doctrine=res://build/duel/rust.json",
               f"--time-limit={args.time_limit}", f"--seed={args.seed}", "--budget=100000"]
    if args.arena:
        command.append(f"--arena={args.arena}")
    if args.tune:
        command.append(f"--tune={args.tune}")
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit + 240)
    events, result = [], None
    for line in completed.stdout.splitlines():
        # Round 9: pass the engine-deck diagnostic through untouched (--tune=probe.deck=1). It is one line per enemy
        # hit and `make deck-angles` aggregates it; without this the rows are swallowed with the rest of stdout.
        if line.startswith("DECK_HIT "):
            print(line)
        if line.startswith("COMBAT_EVENT "):
            events.append(json.loads(line[len("COMBAT_EVENT "):]))
        elif line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
    with open(os.path.join(BUILD, "events.jsonl"), "w") as handle:
        for event in events:
            handle.write(json.dumps(event) + "\n")
    if result is None:
        errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
        print(f"no MATCH_RESULT (exit {completed.returncode}) {errors}", file=sys.stderr)
        return 1

    print(f"DUEL {args.green} (Green) vs {args.rust} (Rust), seed {args.seed}")
    next_pose = 0.0
    shots, hits = {}, {}
    for event in events:
        seconds = event["tick"] / float(SIM_HZ)
        stamp = f"{seconds:6.2f}s"
        kind = event["event"]
        if kind == "poses":
            if seconds + 1e-6 < next_pose:
                continue
            next_pose = seconds + args.pose_every
            units = event["units"]
            parts = [f"{u['name']} ({u['x']:.0f},{u['z']:.0f}) hdg {heading(u['fx'], u['fz']):3d} {u['speed']:+.1f} m/s "
                     f"hp {u['health']}+{u['shield']} [{u['intent']}]" for u in units]
            greens = [u for u in units if u["name"].startswith("Green")]
            rusts = [u for u in units if u["name"].startswith("Rust")]
            gap = ""
            if greens and rusts:
                gap = f" | gap {math.hypot(greens[0]['x'] - rusts[0]['x'], greens[0]['z'] - rusts[0]['z']):.0f} m"
            print(f"{stamp} POSE{gap}")
            for part in parts:
                print(f"         {part}")
        elif kind == "fired":
            shots[event["shooter"]] = shots.get(event["shooter"], 0) + 1
            if event["fire_model"] in ("shell", "arc", "beam") or shots[event["shooter"]] % 10 == 1:
                print(f"{stamp} FIRE {event['shooter']} {event['weapon']} ({event['fire_model']}) #{event['projectile_id']}")
        elif kind == "impact":
            if "target" in event:
                hits[event["target"]] = hits.get(event["target"], 0) + 1
                flag = " WEAK SPOT" if event["weak_spot"] else ""
                dead = " KILL" if event["killed"] else ""
                print(f"{stamp} HIT  #{event['projectile_id']} -> {event['target']} {event.get('face', '')} "
                      f"{event['damage']:.0f} dmg{flag}{dead}")
        elif kind == "destroyed":
            print(f"{stamp} DEAD {event['victim']} (by {event['killer']})")
    print(f"RESULT winner {result['winner']} ({result['reason']}) after {result['duration_seconds']} s; "
          f"shots {json.dumps(shots)}; hits taken {json.dumps(hits)}; first shot {result['stats']['first_shot_seconds']} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
