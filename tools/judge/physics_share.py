#!/usr/bin/env python3
"""Round 39 stretch (native): the physics engine's share of a simulation tick, from `make physics-share`'s logs.

Per fight: wall ms a tick = MATCH_RESULT real_seconds x 1000 / SIM_PROFILE ticks; scripts = SIM_PROFILE tick_ms (every
_physics_process); engine = wall - scripts (headless: PhysicsServer3D sync, query flush and the Jolt step, plus the idle
frame); tank/drive = the motion model + move_and_slide inside the scripts (an upper bound on scripts' physics queries).
Usage: physics_share.py LOG..."""
import json
import sys


def read(path):
    profile = result = None
    for line in open(path, errors="replace"):
        if line.startswith("SIM_PROFILE "):
            profile = json.loads(line[len("SIM_PROFILE "):])
        elif line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
    return profile, result


def main(paths):
    rows = []
    for path in paths:
        profile, result = read(path)
        if profile is None or result is None or not profile.get("ticks"):
            print(f"PHYSICS_SHARE {path}: no SIM_PROFILE / MATCH_RESULT (not read)")
            return 1
        wall = result["real_seconds"] * 1000.0 / profile["ticks"]
        scripts = profile["tick_ms"]
        drive = profile["sections"].get("tank/drive", {}).get("ms_per_tick", 0.0)
        rows.append((path, profile["ticks"], wall, scripts, wall - scripts, drive))
        print(f"PHYSICS_SHARE {path}: {profile['ticks']} ticks, wall {wall:.3f} ms/tick, scripts {scripts:.3f}, "
              f"engine (frame - scripts) {wall - scripts:.3f} ({(wall - scripts) / wall:.1%}), "
              f"tank/drive {drive:.3f} ({drive / wall:.1%})")
    ticks = sum(r[1] for r in rows)
    wall = sum(r[2] * r[1] for r in rows) / ticks
    engine = sum(r[4] * r[1] for r in rows) / ticks
    drive = sum(r[5] * r[1] for r in rows) / ticks
    print(f"PHYSICS_SHARE all {len(rows)} fights, {ticks} ticks: wall {wall:.3f} ms/tick; engine {engine:.3f} "
          f"({engine / wall:.1%}); tank/drive {drive:.3f} ({drive / wall:.1%}); "
          f"physics at most {(engine + drive) / wall:.1%} of a tick")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
