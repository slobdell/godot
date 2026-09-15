#!/usr/bin/env python3
"""Write arenas/*.json (rules R6, contract C5): each layout is authored as HALF its obstacles and hazards; the
other half is the 180° mirror, so every layout is point-symmetric by construction (Arena.validate checks it).

Usage: python3 tools/make_arenas.py arenas   (then run `make test FILTER=arena_layouts` and the fairness control)"""
import json, sys, os

OUT = sys.argv[1]
COLUMNS = [0.0, -12.0, 12.0, -24.0, 24.0, -36.0, 36.0, -48.0, 48.0]


def spawns(base_z=90.0, rows=3, row_spacing=10.0):
    green = []
    for row in range(rows):
        for x in COLUMNS:
            green.append([x, base_z + row * row_spacing])
    rust = [[-x if x else 0.0, -z] for x, z in green]
    return {"green": green, "rust": rust}


def mirrored(half):
    out = []
    for o in half:
        out.append(o)
        x, z = o["position"]
        if x == 0 and z == 0:
            continue
        m = dict(o)
        m["position"] = [-x if x else 0.0, -z if z else 0.0]
        out.append(m)
    return out


def ob(kind, x, z, rot=0, size=None):
    o = {"type": kind, "position": [float(x), float(z)], "rotation_deg": float(rot)}
    if size:
        o["size"] = [float(v) for v in size]
    return o


def pit(x, z, radius=7.0, dps=30.0):
    return {"type": "fire_pit", "position": [float(x), float(z)], "radius": radius, "damage_per_second": dps}


def write(name, note, half, control_radius=16.0, hazards=()):
    layout = {"name": name, "note": note, "half_size": 120.0, "obstacles": mirrored(half),
              "spawns": spawns(), "control_point": {"radius": control_radius}}
    if hazards:
        layout["hazards"] = mirrored(list(hazards))
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        f.write(json.dumps(layout, indent=1) + "\n")


write("foundry",
      "Round 1's arena, extracted to data (rules R6): a center crate, staggered walls, open flanks. Mid-range fights with some cover.",
      [ob("crate", 0, 0),
       ob("wall", -36, -20), ob("wall", -72, 24, 90), ob("wall", -28, 60),
       ob("crate", -24, 12), ob("crate", 60, 52, 45), ob("crate", -12, 56), ob("crate", -80, 64),
       ob("wall", -88, -20, 90), ob("crate", 40, 30)])

write("scrapyard",
      "Rules R6's second layout: dense cover. Long walls cut the field into three lanes, crate clusters break sight lines, and cover walls shield each base. Short fights at corners: scouts and IFVs shine, long guns and artillery need spotters.",
      [ob("crate", 10, 10), ob("crate", -10, 10),
       ob("wall", 30, 22, 90, [36.0, 3.0, 1.5]), ob("wall", -30, 22, 90, [36.0, 3.0, 1.5]),
       ob("crate", 0, 34), ob("crate", -52, 30), ob("crate", 52, 30), ob("crate", 18, 48), ob("crate", -18, 48),
       ob("wall", 0, 70), ob("wall", -64, 70), ob("wall", 64, 70),
       ob("wall", -96, 8, 90), ob("crate", -76, 46), ob("crate", 76, 46), ob("crate", -44, 0),
       ob("crate", -96, 40, 45), ob("crate", 96, 40, 45)])

write("furnace",
      "Stretch hazards: foundry's cover plus burning fire pits (30 damage per second, shields first) in the center "
      "lanes and on the flanks. Charging straight down the middle costs hull; the pits punish clumps that don't route around them.",
      [ob("crate", 0, 0),
       ob("wall", -36, -20), ob("wall", -72, 24, 90), ob("wall", -28, 60),
       ob("crate", -24, 12), ob("crate", 60, 52, 45), ob("crate", -12, 56), ob("crate", -80, 64),
       ob("wall", -88, -20, 90), ob("crate", 40, 30)],
      hazards=[pit(0, 30), pit(-60, 0, 9.0), pit(24, -36, 6.0)])
