#!/usr/bin/env python3
"""Write arenas/*.json (rules R6, contract C5; arena X3, layout v2 = contract M2): each layout is authored as HALF its
obstacles, props, hazards, lanes and regions; the other half is the 180° mirror, so every layout is point-symmetric by
construction (Arena.validate checks it). The design vocabulary and each arena's measurements: _agents/arenas.md.

Usage: python3 tools/make_arenas.py arenas   (or `make arenas`; then `make arena-report` and `make test FILTER=arena`)"""
import json, math, sys, os

OUT = sys.argv[1]
# Must mirror Match.SLOT_X / SPAWN_ROWS / SPAWN_ROW_SPACING (X5, round 4: 65 slots a side for faction-sized armies).
COLUMNS = [0.0, -11.0, 11.0, -22.0, 22.0, -33.0, 33.0, -44.0, 44.0, -55.0, 55.0, -66.0, 66.0]


def spawns(base_z=90.0, rows=4, row_spacing=8.0):
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


# ---- Layout v2 (arena X1/X3): the arena kit, spawn zones, lanes and regions ----------------------------------------

SPAWN_ZONE = {"center": [0.0, 102.0], "size": [150.0, 32.0]}


def prop(kind, x, z, rot=0, stack=None, **look):
    p = {"type": kind, "position": [float(x), float(z)], "rotation_deg": float(rot)}
    if stack and stack > 1:
        p["stack"] = int(stack)
    p.update(look)
    return p


def c20(x, z, rot=0, stack=1, **look):
    return prop("container_20", x, z, rot, stack, **look)


def c40(x, z, rot=0, stack=1, **look):
    return prop("container_40", x, z, rot, stack, **look)


def screen(x, z, rot=0, channel="arena"):
    """A screen faces -Z at rot 0. Point symmetry turns a south screen's mirror to face the other way, so face each
    screen toward its own half's base (south: 180, north: 0): each player's nearer screens face their camera."""
    return prop("ad_screen", x, z, rot, channel=channel)


def barricade(x, z, rot=0):
    return prop("barricade", x, z, rot)


def wreck(x, z, rot=0):
    return prop("wreck", x, z, rot)


def floodlight(x, z):
    return prop("floodlight", x, z)


def sign(x, z, rot=0, which="arena"):
    return prop("sign", x, z, rot, sign=which)


def run(kind, x0, z0, x1, z1, stack=1, **look):
    """A straight wall of containers end to end from (x0, z0) to (x1, z1), long axes along the run."""
    length = {"container_20": 6.06, "container_40": 12.19}[kind]
    dist = math.hypot(x1 - x0, z1 - z0)
    count = max(1, round(dist / length))
    rot = round(math.degrees(math.atan2(-(z1 - z0), x1 - x0)), 3)  # Basis(UP, a): local x -> (cos a, -sin a)
    out = []
    for i in range(count):
        t = (i + 0.5) / count
        out.append(prop(kind, round(x0 + (x1 - x0) * t, 3), round(z0 + (z1 - z0) * t, 3), rot, stack, **look))
    return out


def lane(name, points, width):
    return {"name": name, "points": [[float(x), float(z)] for x, z in points], "width": float(width)}


def region(name, kind, x, z, radius):
    return {"name": name, "kind": kind, "position": [float(x), float(z)], "radius": float(radius)}


def mirrored_props(half):
    out = []
    for p in half:
        out.append(p)
        x, z = p["position"]
        if x == 0 and z == 0:
            continue
        m = dict(p)
        m["position"] = [-x if x else 0.0, -z if z else 0.0]
        m["rotation_deg"] = float((p.get("rotation_deg", 0.0) + 180.0) % 360.0)
        out.append(m)
    return out


def mirrored_lanes(half):
    """A lane runs green end first; its mirror is the same route seen from the other base. A lane that is its own
    mirror (through the centre) is authored once and listed with `self_mirror`."""
    out = []
    for l in half:
        own = l.pop("self_mirror", False)
        out.append(l)
        if not own:
            out.append({"name": l["name"] + " (far)", "points": [[-x if x else 0.0, -z if z else 0.0] for x, z in reversed(l["points"])],
                        "width": l["width"]})
    return out


def mirrored_regions(half):
    out = []
    for r in half:
        out.append(r)
        x, z = r["position"]
        if x == 0 and z == 0:
            continue
        m = dict(r)
        m["name"] = r["name"] + " (far)"
        m["position"] = [-x if x else 0.0, -z if z else 0.0]
        out.append(m)
    return out


def write_v2(name, title, fight, props, lanes=(), regions=(), obstacles=(), control_radius=16.0, hazards=()):
    layout = {"name": name, "schema": 2, "title": title, "note": fight, "half_size": 120.0,
              "obstacles": mirrored(list(obstacles)), "props": mirrored_props(list(props)),
              "spawns": spawns(), "spawn_zones": {"green": SPAWN_ZONE, "rust": {"center": [0.0, -102.0], "size": SPAWN_ZONE["size"]}},
              "lanes": mirrored_lanes([dict(l) for l in lanes]), "regions": mirrored_regions(list(regions)),
              "control_point": {"radius": control_radius}}
    if hazards:
        layout["hazards"] = mirrored(list(hazards))
    check_spawn_clearance(layout)
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        f.write(json.dumps(layout, indent=1) + "\n")


def check_spawn_clearance(layout, clearance=6.0):
    """Arena.SPAWN_CLEARANCE, checked at authoring time so a bad layout never gets written."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import arena_report
    for box in arena_report.boxes_of(layout):
        for side in ("green", "rust"):
            for x, z in layout["spawns"][side]:
                if box.distance(x, z) < clearance:
                    sys.exit("%s: spawns.%s point [%s, %s] is %.1f m from %s at [%s, %s] (need %.1f)" % (
                        layout["name"], side, x, z, box.distance(x, z), box.kind, box.x, box.z, clearance))


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


# ---- Round 5 arenas (arena X3): four characters built from the kit. Author the SOUTH (green) half; z > 0 is green's
# side, north (-z) is rust's. Spawn points are at z 90-114 across x +-66: keep cover out of z > 80 inside x +-74.

# The Container Yard: dense lanes, short sightlines, ambushes at every corner.
# Six container walls run base to base. Type A walls leave alleys at z ~ +-38; type B walls cross the centre line and
# leave alleys at z ~ +-13 and +-51. Every x has an A on one half and a B on the other (the mirror), so the alleys
# stagger and no line threads the whole yard.
YARD_A = [(7, 31), (45, 69)]
YARD_B = [(-6, 6), (20, 44), (58, 70)]
YARD_COLUMNS = [(-84, YARD_A, 2, "condemned"), (-50, YARD_B, 1, "mixed"), (-17, YARD_A, 2, "law"),
                (17, YARD_B, 1, "gangs"), (50, YARD_A, 2, "syndicate"), (84, YARD_B, 1, "mixed")]
yard = []
for x, segments, stack, faction in YARD_COLUMNS:
    for z0, z1 in segments:
        yard += run("container_40" if z1 - z0 > 18 else "container_20", x, z0, x, z1, stack, faction=faction)
yard += [
    # Sightline breaks inside each lane, staggered so no lane is straight end to end.
    c20(5, 30, 0, 2), c40(-6, 52, 0, 1, faction="law"), wreck(9, 68, 15),
    c20(-34, 16, 0, 2, faction="gangs"), c40(34, 56, 0, 1),
    c20(-67, 52, 0, 2, faction="condemned"), c20(67, 22, 90, 2), wreck(-70, 20, 70),
    c20(100, 50, 0, 1), c40(-100, 36, 0, 2, faction="mixed"), wreck(104, 12, 30),
    # A cover line in front of the base: somewhere to form up out of the first volley.
    c20(-40, 78, 0, 1), c20(0, 80, 0, 1, faction="condemned", doors="open"), c20(40, 78, 0, 1),
    barricade(-20, 78, 0), barricade(20, 78, 0),
    screen(-34, 74, 180, "arena"), floodlight(-100, 80), sign(106, 74, 0, "yard"),
]
write_v2("yard", "The Container Yard",
         "Dense lanes and short sightlines: fights happen at corners and alley mouths, a flank is one wall away, and "
         "whoever scouts the next lane first gets the ambush. Scouts, IFVs and burners shine; long guns can't see.",
         yard,
         lanes=[lane("centre", [(0, 90), (0, 0), (0, -90)], 30) | {"self_mirror": True},
                lane("inner west", [(-34, 90), (-34, 0), (-34, -90)], 28),
                lane("outer west", [(-67, 90), (-67, 0), (-67, -90)], 28),
                lane("far west", [(-100, 90), (-100, 0), (-100, -90)], 26)],
         regions=[region("the plaza", "centre", 0, 0, 16),
                  region("yard gate", "chokepoint", -34, 38, 8), region("east alley", "chokepoint", 67, 38, 8),
                  region("west stacks", "cover_cluster", -67, 40, 22), region("base apron", "cover_cluster", 0, 78, 30)])

# The Boulevard: three long avenues. Low barricade medians leave the fire lanes open; kiosks, screens and wrecks break
# them every ~60 m; container walls hide the outer service roads. Range and artillery matter; crossing an avenue is a
# decision.
boulevard = []
for x in (-40, 40):
    # Medians: barricade runs (low: sight and fire pass over), open at the crossings.
    for z0 in (8, 50):
        boulevard += [barricade(x, z0 + 3 + 6 * i, 90) for i in range(3)]
boulevard += run("container_40", -80, 4, -80, 40, 1, faction="law")
boulevard += run("container_40", -80, 56, -80, 80, 2, faction="law")
boulevard += run("container_40", 80, 10, 80, 46, 2, faction="syndicate")
boulevard += run("container_40", 80, 62, 80, 74, 1, faction="syndicate")
boulevard += [
    # The roundabout: four screens facing out around the control point, low barricades ringing it.
    screen(0, 30, 180, "arena"), screen(30, 0, 90, "sponsor"),
    barricade(-19, 12, 57), barricade(19, 12, 123),
    # Kiosks and wrecks: sightline breaks down the avenues, staggered.
    c20(-60, 20, 90, 2, faction="gangs", doors="open"), c20(60, 58, 90, 2), c20(-20, 58, 90, 2, faction="law"),
    wreck(-58, 64, 10), wreck(98, 30, 80),
    c40(-98, 60, 90, 1, faction="condemned"), wreck(-100, 14, 20),
    screen(-60, 80, 180, "sponsor"), screen(60, -2, 0, "arena"),
    floodlight(-40, 82), floodlight(40, 82), sign(-110, 70, 90, "boulevard"), sign(110, 20, 270, "boulevard"),
]
write_v2("boulevard", "The Boulevard",
         "Long fire lanes broken by screens, kiosks and wrecks: the side that spots first and crosses the avenues "
         "under cover wins. Artillery and long guns earn their cost; the walled service roads are the slow, hidden flank.",
         boulevard,
         lanes=[lane("centre avenue", [(0, 90), (0, 45), (-12, 0), (0, -45), (0, -90)], 34),
                lane("west avenue", [(-60, 90), (-60, 0), (-60, -90)], 34),
                lane("west service road", [(-98, 90), (-98, 0), (-98, -90)], 30)],
         regions=[region("the roundabout", "centre", 0, 0, 16),
                  region("west avenue", "open_ground", -60, 40, 18), region("centre avenue", "open_ground", 0, 60, 14),
                  region("west crossing", "chokepoint", -40, 44, 7), region("west service road", "flank", -98, 40, 16),
                  region("screen plinth", "overlook", 30, 0, 8)])

# The Pit: a walled ring around the control point with four gates. Inside, a close brawl among pillars; outside, open
# ground that anyone crossing to a gate has to survive. The world is flat, so "overlooked" means the gates and the
# gaps at the ring's corners, which see across the approaches from cover.
pit = []
RING = 42.0
for i, angle in enumerate((0, 45, 90, 135)):
    rad = math.radians(angle)
    cx, cz = RING * math.cos(rad), RING * math.sin(rad)
    tx, tz = -math.sin(rad), math.cos(rad)  # along the side
    rot = round(math.degrees(math.atan2(-tz, tx)) % 360, 3)  # Basis(UP, a): local x -> (cos a, -sin a)
    if angle % 90 == 0:
        # A gate: two stacks of two 20 ft containers either side of a 12 m opening.
        for side in (-1, 1):
            off = side * (6.0 + 3.03 + 6.06)
            pit.append(c20(round(cx + tx * (off - side * 3.03), 3), round(cz + tz * (off - side * 3.03), 3), rot, 2, faction="condemned"))
            pit.append(c20(round(cx + tx * off, 3), round(cz + tz * off, 3), rot, 2, faction="condemned"))
    else:
        # A solid wall: two 40 ft containers, three high on the diagonals, with a firing gap at each corner.
        for side in (-1, 1):
            off = side * 6.0  # overlap 0.2 m at the seam: no gap to see through
            pit.append(c40(round(cx + tx * off, 3), round(cz + tz * off, 3), rot, 3, faction="syndicate"))
pit += [
    # Pillars inside the ring.
    c20(0, 22, 0, 1, faction="gangs"), c20(20, 8, 70, 1, doors="ajar"), wreck(-16, 16, 40),
    # The approaches: sparse cover on the open ground outside, and a base cover line.
    wreck(-30, 66, 80), wreck(64, 56, 30), c20(-76, 44, 90, 1), c20(92, 10, 90, 2, faction="law"),
    barricade(-50, 34, 45), barricade(28, 70, 0), c20(0, 80, 0, 1), c20(-50, 80, 0, 1), c20(50, 80, 0, 1),
    # Screens on the ring's outside, over the gates.
    screen(0, 52, 180, "arena"), floodlight(-104, 96), floodlight(104, 96), sign(-60, 100, 180, "pit"),
]
write_v2("pit", "The Pit",
         "A control-point brawl behind walls: four gates into a ring of stacked containers, open killing ground "
         "outside. Hold a gate and you own the approach; go inside and it's knife range. Tanks and burners take the "
         "ring; artillery punishes whoever crowds it.",
         pit,
         lanes=[lane("south gate", [(0, 90), (0, 42), (0, 0), (0, -42), (0, -90)], 12) | {"self_mirror": True},
                lane("west gate", [(-40, 90), (-70, 40), (-42, 0), (0, 0), (42, 0), (70, -40), (40, -90)], 12) | {"self_mirror": True},
                lane("west flank", [(-66, 90), (-100, 0), (-66, -90)], 30)],
         regions=[region("the ring", "centre", 0, 0, 16), region("south gate", "chokepoint", 0, 42, 7),
                  region("west gate", "chokepoint", -42, 0, 7), region("south approach", "open_ground", 0, 62, 16),
                  region("west approach", "open_ground", -66, 30, 18), region("south-west corner gap", "overlook", -30, 30, 6)])

# The Boneyard: irregular cover (wrecks, tipped containers, broken walls at odd angles) with no pattern of shape, but
# point-symmetric in value. Every position has an answer on the other side; none of them line up.
boneyard = [
    # The west pile: a knot of tipped containers and husks, a position to hold.
    c40(-62, 28, 104, 2, faction="gangs", rust=0.9), c20(-50, 40, 12, 1, faction="mixed"), wreck(-44, 24, 70),
    wreck(-68, 48, 150), c20(-56, 54, 40, 2, faction="condemned"),
    # The east scrap: looser, with a way through the middle.
    c40(54, 34, 37, 1, faction="gangs"), wreck(68, 50, 110), c20(72, 26, 80, 2), wreck(44, 56, 20),
    # The heap around the centre, and breaks down the middle and the diagonals.
    c40(-10, 18, 23, 1, faction="gangs"), c20(16, 28, 71, 2, faction="gangs", doors="open"), wreck(3, 42, 12),
    wreck(-26, 40, 130), wreck(-4, 60, 95), c20(10, 68, 170, 1), wreck(34, 34, 45), c20(-28, 12, 60, 1),
    # The flanks: odd pieces, far apart.
    wreck(-98, 12, 5), c40(-92, 62, 66, 1, faction="condemned"), c20(100, 64, 20, 1), wreck(96, 88, 80),
    c20(-104, 36, 135, 2), wreck(88, 14, 160),
    # In front of the base.
    c40(-20, 78, 176, 1, faction="gangs"), c20(24, 80, 8, 1), wreck(-48, 78, 100), wreck(52, 76, 60),
    barricade(-34, 6, 150), barricade(40, 4, 30), barricade(6, 50, 95),
    screen(66, 70, 180, "sponsor"),
    floodlight(-84, 96), floodlight(-110, 40), sign(-80, 104, 180, "boneyard"), sign(108, 104, 200, "boneyard"),
]
boneyard_walls = [ob("wall", 30, 12, 58), ob("wall", -78, 72, 145, [12.0, 3.0, 1.5])]
write_v2("boneyard", "The Boneyard",
         "Irregular cover at odd angles: no two positions look alike, so fights are local and read differently every "
         "match. Small elements, patience and spotting win; a big formation breaks apart on the first wreck.",
         boneyard, obstacles=boneyard_walls,
         lanes=[lane("centre", [(0, 90), (8, 0), (0, -90)], 24),
                lane("west", [(-66, 90), (-70, 0), (-66, -90)], 24)],
         regions=[region("the heap", "centre", 0, 0, 16), region("west pile", "cover_cluster", -56, 38, 20),
                  region("east scrap", "cover_cluster", 58, 40, 20), region("the flats", "open_ground", -100, -30, 14)])
