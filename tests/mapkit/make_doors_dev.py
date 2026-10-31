#!/usr/bin/env python3
"""Mapkit P2 (round 47): write arenas/doors_dev.json, the blast doors' DEV arena (a fixture: never dealt, no booth name).

A wall across the middle (z = 0) with two door gaps at x = +-40 (one mirrored pair, ONE schedule) and two flank gaps at
x = +-100 that never close, so the map is never sealed: a shut door changes the route, it never ends the match. Spawns and
zones are foundry's. Run: python3 tests/mapkit/make_doors_dev.py (C47.8: doors stay on this arena until route's planner
reads BlastDoors.is_open)."""
import json
import pathlib

HALF = 120.0
WALL_H = 3.0
WALL_T = 1.5
# Wall spans along x at z = 0 (x0, x1): the gaps are the doors (33..47 and mirror) and the flanks (90..110 and mirror).
SPANS = [(-120.0, -110.0), (-90.0, -47.5), (-32.5, 32.5), (47.5, 90.0), (110.0, 120.0)]

root = pathlib.Path(__file__).resolve().parents[2]
foundry = json.loads((root / "arenas" / "foundry.json").read_text())
obstacles = []
for x0, x1 in SPANS:
    obstacles.append({"type": "wall", "position": [(x0 + x1) / 2.0, 0.0], "rotation_deg": 0.0,
                      "size": [x1 - x0, WALL_H, WALL_T]})
layout = {
    "name": "doors_dev",
    "schema": 2,
    "title": "Doors (dev)",
    "note": "Mapkit P2's blast-door dev arena (tests/mapkit/make_doors_dev.py): a wall across the middle, two timed doors "
            "(one schedule), two flank gaps that never close. A fixture: never dealt.",
    "fixture": True,
    "half_size": HALF,
    "obstacles": obstacles,
    "props": [],
    "spawns": foundry["spawns"],
    "spawn_zones": {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
                    "rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}},
    "objectives": [{"name": "west yard", "position": [-70.0, 40.0], "radius": 14.0},
                   {"name": "east yard", "position": [70.0, -40.0], "radius": 14.0}],
    "doors": [
        {"name": "west_gate", "group": "gates", "position": [-40.0, 0.0], "rotation_deg": 0.0},
        {"name": "east_gate", "group": "gates", "position": [40.0, 0.0], "rotation_deg": 180.0},
    ],
}
(root / "arenas" / "doors_dev.json").write_text(json.dumps(layout, indent=1) + "\n")
print("wrote arenas/doors_dev.json")
