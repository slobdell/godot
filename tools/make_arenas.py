#!/usr/bin/env python3
"""Write arenas/*.json (rules R6, contract C5; arena X3, layout v2 = contract M2): each layout is authored as HALF its
obstacles, props, hazards, lanes and regions; the other half is the 180° mirror, so every layout is point-symmetric by
construction (Arena.validate checks it). The design vocabulary and each arena's measurements: _agents/arenas.md.

Usage: python3 tools/make_arenas.py arenas   (or `make arenas`; then `make arena-report` and `make test FILTER=arena`)"""
import json, math, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdscript_source

OUT = sys.argv[1]

# ROUND 9 (scale): these used to be a COPY of Match.SLOT_X / SPAWN_ROWS / SPAWN_ROW_SPACING, kept in step by a
# comment saying "must mirror". It is the worst row in Invariant 0's table because THE COPY WON: `Arena.spawn_spot`
# is consulted before the constants, so the baked lists here beat them and changing a constant changed nothing in a
# real match. They are read now, and `make arenas` is the only thing that writes a spawn list.
MATCH_GD = gdscript_source.GAME / "match" / "match.gd"
ARENA_GD = gdscript_source.GAME / "arena" / "arena.gd"


def spawns():
    """Every spawn point for both sides, laid out exactly as `Match.spawn_position` lays out its fallback."""
    columns = gdscript_source.const(MATCH_GD, "SLOT_X")
    rows = int(gdscript_source.const(MATCH_GD, "SPAWN_ROWS"))
    row_spacing = gdscript_source.const_float(MATCH_GD, "SPAWN_ROW_SPACING")
    base_z = gdscript_source.const_float(MATCH_GD, "BASE_Z")
    slots = int(gdscript_source.const(MATCH_GD, "SPAWN_SLOTS"))
    green = []
    for row in range(rows):
        for x in columns:
            green.append([float(x), base_z + row * row_spacing])
    if len(green) < slots:
        sys.exit("make_arenas: %d columns x %d rows is %d spawn points, fewer than Match.SPAWN_SLOTS (%d)"
                 % (len(columns), rows, len(green), slots))
    rust = [[-x if x else 0.0, -z] for x, z in green]
    return {"green": green, "rust": rust}


def spawn_clearance():
    """`Arena.SPAWN_CLEARANCE`, both halves of it read from where they are defined."""
    return (gdscript_source.const_float(MATCH_GD, "SPAWN_JITTER_MAX_X")
            + gdscript_source.const_float(ARENA_GD, "SPAWN_CLEARANCE_MARGIN"))


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


## Top-level keys that are AUTHORED BESIDE the generated layout and must survive regeneration.
##
## `arenas/*.json` are generated, not hand-authored: both writers build a fresh dict and dump the whole file, so
## any key this generator does not know about is DELETED on the next `make arenas`. `show` (the arena light show's
## channel/patch data, round 9) is tuning the lead will change several times after he sees the first frames --
## putting it in this file would make every tweak a cross-stream request, and putting it in a sibling file would
## need a loader to go looking for it. So the generator does not learn what a channel is; it only refuses to throw
## one away, and it says which keys it carried.
##
## What this gives up: a MISSPELLED key survives regeneration forever as dead data. `Arena.validate()` closes that
## by rejecting unknown top-level keys, with these in its allowed set.
PRESERVED_KEYS = ("show",)


def _keep(name, layout):
    """Carry `PRESERVED_KEYS` over from the layout already on disk, and report what was carried."""
    path = os.path.join(OUT, name + ".json")
    if not os.path.exists(path):
        return
    with open(path) as f:
        old = json.load(f)
    for key in PRESERVED_KEYS:
        if key in old:
            layout[key] = old[key]
            print("ARENA_KEPT %s: %s (authored beside the generator, not by it)" % (name, key))


def write(name, note, half, control_radius=16.0, hazards=()):
    layout = {"name": name, "note": note, "half_size": 120.0, "obstacles": mirrored(half),
              "spawns": spawns(), "control_point": {"radius": control_radius}}
    if hazards:
        layout["hazards"] = mirrored(list(hazards))
    _keep(name, layout)
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


def objective(name, x, z, radius=14.0):
    """One objective. Off-centre ones come in MIRRORED PAIRS — a lone one is owned by whichever base is nearer,
    which is the fairness invariant this whole file exists to protect (Arena.validate enforces it)."""
    return {"name": name, "position": [float(x), float(z)], "radius": float(radius)}


def objective_pair(name, x, z, radius=14.0):
    """An objective and its 180 degree twin. Each side gets one it holds cheaply and one it must contest, which is
    the dilemma combat's share-of-objectives scoring creates: hold your own at half rate, or take theirs at full.

    **Decision spread is not a quantity to maximise**, which a sweep of pit's placements made obvious: pushing the
    pair from z = -30 to -70 ran the spread 0.13 -> 0.42 -> 0.63 -> 0.96, and 0.96 is not a better map. It means
    one objective is nearly free and the other nearly impossible, which is a formality rather than a choice -- and
    at z = -70 it sits in the base's approach funnel, the boulevard failure this stream wrote a placement rule
    against. Too little spread is no decision; too much is no contest. Both shipping pairs sit near 0.4."""
    return [objective(name, x, z, radius), objective(name + " (far)", -x, -z, radius)]


def write_v2(name, title, fight, props, lanes=(), regions=(), obstacles=(), control_radius=16.0, hazards=(),
             fixture=False, objectives=(), shape=None, half_size=120.0):
    layout = {"name": name, "schema": 2, "title": title, "note": fight, "half_size": half_size, "fixture": fixture,
              "obstacles": mirrored(list(obstacles)), "props": mirrored_props(list(props)),
              "spawns": spawns(), "spawn_zones": {"green": SPAWN_ZONE, "rust": {"center": [0.0, -102.0], "size": SPAWN_ZONE["size"]}},
              "lanes": mirrored_lanes([dict(l) for l in lanes]), "regions": mirrored_regions(list(regions)),
              "control_point": {"radius": control_radius}}
    if hazards:
        layout["hazards"] = mirrored(list(hazards))
    if objectives:
        layout["objectives"] = list(objectives)
    if shape:
        layout["shape"] = shape
    _keep(name, layout)
    check_spawn_clearance(layout)
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        f.write(json.dumps(layout, indent=1) + "\n")


def check_spawn_clearance(layout, clearance=None):
    """Arena.SPAWN_CLEARANCE, checked at authoring time so a bad layout never gets written."""
    import arena_report
    if clearance is None:
        clearance = spawn_clearance()
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
## Two more columns further out than the old square allowed, because the hexagon is 280 m across at midfield where
## the square was 240. Without them the extra ground is empty and the longest clear shot goes from 184 m to 216 m
## -- the arena gets roomier and the sightlines get LONGER, which trades one of the lead's complaints for another.
## Their segments are shorter because the hexagon narrows toward the bases and a container out there would be
## through the wall.
## x = +-98, not 115: a hexagon narrows toward the bases, so a column out at 115 only fits within about 30 m of
## midfield. 98 with a 10..60 m segment hugs the new wall for its whole length -- checked against the inset
## boundary rather than guessed, after 115 put a container through the wall at z = 47.
YARD_OUTER = [(10, 60)]
YARD_COLUMNS = [(-98, YARD_OUTER, 2, "mixed"), (-84, YARD_A, 2, "condemned"), (-50, YARD_B, 1, "mixed"),
                (-17, YARD_A, 2, "law"), (17, YARD_B, 1, "gangs"), (50, YARD_A, 2, "syndicate"),
                (84, YARD_B, 1, "mixed"), (98, YARD_OUTER, 2, "law")]
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
    # Floodlights on the hexagon's east/west VERTICES and signs on its base-side corners: the square's corners do
    # not exist any more, and these four were the only props of yard's that fell outside the new wall.
    screen(-34, 74, 180, "arena"), floodlight(-128, 0), sign(-64, 108, 180, "yard"),
]
write_v2("yard", "The Container Yard",
         "Dense lanes and short sightlines: fights happen at corners and alley mouths, a flank is one wall away, and "
         "whoever scouts the next lane first gets the ambush. Scouts, IFVs and burners shine; long guns can't see.",
         yard,
         lanes=[lane("centre", [(0, 90), (0, 0), (0, -90)], 30) | {"self_mirror": True},
                lane("inner west", [(-34, 90), (-34, 0), (-34, -90)], 28),
                lane("outer west", [(-67, 90), (-67, 0), (-67, -90)], 28),
                lane("far west", [(-100, 90), (-100, 0), (-100, -90)], 26)],
         shape={"kind": "hexagon"}, half_size=140.0,
         # A mirrored pair: each side has one objective it holds cheaply and one it must contest. Combat's
         # share-of-objectives scoring makes that a real dilemma -- hold your own at half rate, or take theirs at
         # full. Held back until squad's Objectives migration landed (2341201f); its guard refused a non-central
         # layout until then, and rightly.
         objectives=objective_pair("the west depot", -62.0, -34.0),
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
    # Four of the hexagon's six vertices, which is a better ring than the square's corners were.
    # The east vertex and a point on the north-east edge; their mirrors give four. NOT the base-side vertices:
    # those sit inside the spawn block, and check_spawn_clearance refused them at 3.8 m from a spawn point.
    screen(0, 52, 180, "arena"), floodlight(-128, 0), floodlight(-94, 60), sign(-60, 100, 180, "pit"),
]
write_v2("pit", "The Pit",
         "A control-point brawl behind walls: four gates into a ring of stacked containers, open killing ground "
         "outside. Hold a gate and you own the approach; go inside and it's knife range. Tanks and burners take the "
         "ring; artillery punishes whoever crowds it.",
         pit,
         shape={"kind": "hexagon"}, half_size=140.0,
         # As yard: the ring is still the centre, but holding it is no longer the whole game -- you must leave it
         # to score at full rate.
         objectives=objective_pair("the west yard", -74.0, -50.0, 15.0),
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


# ---- The Maze (arena X1, round 6, contract N3 / checkpoint CP2) ------------------------------------------------
# A TEST FIXTURE, NOT A SHIPPING MAP: nav's acceptance test (_agents/arenas.md "The Maze"). It is deliberately
# un-fun -- no cover-vs-sightline design, no balance, no art pass -- and it exists to answer one question: can a
# horde of 30+ vehicles get from its spawn zone to the far base through gaps it has to file through?
#
# Geometry: four container walls run across the field (bands at z = 74, 52, 30, 10) with gaps at different x, and
# their 180 deg mirrors give four more at z = -10, -30, -52, -74. A gap at +x has its mirror at -x, so crossing the
# arena is a serpentine: every band forces a lateral run to reach the next gap. The navmesh agent radius is 2 m
# (game/arena/arena.tscn), so a gap of physical width W leaves W - 4 m of drivable corridor -- MAZE_TIGHT_GAP = 7 m
# is a 3 m corridor, narrower than two hulls (the widest is 3.0 m) and about one and a half of the common 2.6 m
# ones. Below ~6 m the bake starts losing the corridor to rasterisation, which reads as a nav bug; do not narrow it
# without re-running `make nav-maze`.

MAZE_BAND_Z = [74.0, 52.0, 30.0, 10.0]
MAZE_TIGHT_GAP = 7.0
MAZE_EDGE = 116.0  # Match.DRIVABLE_LIMIT: the walls run out to the edge of drivable space, so no band can be rounded.


def maze_wall(x0, z0, x1, z1, stack=2, kind="container_40"):
    """Like run(), but sized with ceil so neighbouring containers always OVERLAP. run()'s round() can leave a
    metre-wide slot between containers, which is not drivable but is a sightline and reads as sloppy in a fixture
    whose whole job is 'this gap and no other'."""
    # Lengths from ArenaKit.PROPS (the long axis, before rotation). Kept as a table rather than a lookup into the
    # GDScript so this tool stays standalone -- and a piece missing here fails loudly rather than silently.
    length = {"container_20": 6.06, "container_40": 12.19, "barricade": 6.0, "wreck": 3.2}[kind]
    dist = math.hypot(x1 - x0, z1 - z0)
    count = max(1, math.ceil(dist / length - 1e-9))
    rot = round(math.degrees(math.atan2(-(z1 - z0), x1 - x0)), 3)
    out = []
    for i in range(count):
        t = (i + 0.5) / count
        out.append(prop(kind, round(x0 + (x1 - x0) * t, 3), round(z0 + (z1 - z0) * t, 3), rot, stack))
    return out


def maze_band(z, spans):
    out = []
    for x0, x1 in spans:
        out += maze_wall(x0, z, x1, z)
    return out


maze = []
# Band 1 (z = 74), the way out of the spawn zone: one wide gate west, one TIGHT gate east.
maze += maze_band(74.0, [(-MAZE_EDGE, -62.0), (-50.0, 8.0), (8.0 + MAZE_TIGHT_GAP, MAZE_EDGE)])
# Band 2 (z = 52): three gaps, and the westmost one is a trap (see the pocket wall below).
maze += maze_band(52.0, [(-MAZE_EDGE, -104.0), (-92.0, -20.0), (-10.0, 60.0), (70.0, MAZE_EDGE)])
# Band 3 (z = 30).
maze += maze_band(30.0, [(-MAZE_EDGE, -72.0), (-62.0, 24.0), (34.0, MAZE_EDGE)])
# Band 4 (z = 10): the last band before the open centre corridor (z in [-9, 9]).
maze += maze_band(10.0, [(-MAZE_EDGE, -38.0), (-28.0, 86.0), (96.0, MAZE_EDGE)])
# The dead end: the z = 52 gap at x ~ -98 opens into a pocket closed by band 3 to the south, the arena edge to the
# west and this wall to the east. A unit that takes it has to come back out the way it went in.
maze += maze_wall(-86.0, 30.0, -86.0, 52.0)

write_v2("maze", "The Maze (nav test fixture)",
         "NOT A SHIPPING MAP. Eight container bands with staggered gaps: the only route from one base to the other "
         "is a serpentine through gaps 7-12 m wide, past one dead end. It exists so nav can prove a horde gets "
         "through (`make nav-maze`); it has no cover design, no balance and no art pass.",
         maze,
         lanes=[lane("west serpentine", [(-56, 90), (-56, 62), (-15, 62), (-15, 40), (-67, 40), (-67, 20),
                                         (-33, 20), (-33, 0), (33, 0), (33, -20), (67, -20), (67, -40),
                                         (15, -40), (15, -62), (56, -62), (56, -90)], 8),
                lane("east serpentine", [(11, 90), (11, 62), (65, 62), (65, 40), (29, 40), (29, 20),
                                         (91, 20), (91, 0), (-91, 0), (-91, -20), (-29, -20), (-29, -40),
                                         (-65, -40), (-65, -62), (-11, -62), (-11, -90)], 8)],
         regions=[region("the corridor", "centre", 0, 0, 9),
                  region("tight gate", "chokepoint", 11.5, 74, 4),
                  region("west gate", "chokepoint", -56, 74, 6),
                  region("dead end", "cover_cluster", -99, 41, 12)],
         control_radius=8.0, fixture=True)


# ---- The Barrier Line (arena, round 8): a fixture for the lead's stall -------------------------------------------
#
# He played round 7 and said: *"units are still just getting stuck behind basic barriers where they seem to just
# move back and forth indefinitely trying to get unstuck."* nav's nav-fight reports blocked-by-terrain at ~0 on
# yard, so the instrument and the game disagree; this is the ground the game's version can be measured on.
#
# **Built around ENDS, not walls.** nav's round-7 finding is that the units it pinned were all at the END of a
# barricade or a container, so a fixture made of one long wall would test the wrong thing. This is three rows of
# short, separate barriers, each row a different kit piece, with gaps of three widths -- so a horde ordered across
# must file past many ends, and we learn which piece and which width it happens at rather than only that it does.
#
# Gap widths are chosen against the 2 m navmesh agent radius, which eats 2 m from each side:
#   4 m  -> no drivable corridor at all: units must route around, and this is where they should bunch
#   7 m  -> 3 m of corridor, single file (the maze's tight gate, which a horde does choose)
#   11 m -> 7 m, two abreast
#
# A FIXTURE, not a shipping map: no art pass, no balance, and `--arena=random` never picks it.

BARRIER_ROWS = [
    # (z, kit piece, stack, the x centres of each gap)
    (62.0, "barricade", 1, [-70.0, -18.0, 40.0]),
    (38.0, "container_20", 2, [-44.0, 14.0, 72.0]),
    (14.0, "container_40", 2, [-72.0, -14.0, 44.0]),
]
BARRIER_GAPS = [4.0, 7.0, 11.0]
BARRIER_EDGE = 116.0

barriers = []
for row_z, piece, row_stack, gaps in BARRIER_ROWS:
    edges = [-BARRIER_EDGE]
    for centre, width in zip(gaps, BARRIER_GAPS):
        edges += [centre - width / 2.0, centre + width / 2.0]
    edges.append(BARRIER_EDGE)
    for i in range(0, len(edges), 2):
        x0, x1 = edges[i], edges[i + 1]
        if x1 - x0 < 1.0:
            continue
        barriers += maze_wall(x0, row_z, x1, row_z, row_stack, piece)

write_v2("barriers", "The Barrier Line (stall test fixture)",
         "NOT A SHIPPING MAP. Three rows of short barriers -- barricades, 20 ft containers, 40 ft containers -- each "
         "row with a 4 m, a 7 m and an 11 m gap, staggered so no line threads them. It exists so the stall the lead "
         "describes can be measured at a known piece and a known width, and it is built around barrier ENDS because "
         "that is where nav's round-7 pins happened.",
         barriers, fixture=True, control_radius=10.0,
         regions=[region("the gauntlet", "chokepoint", 0.0, 38.0, 12.0)])


# The Terminus: the cityscape (round 8). The lead asked twice -- *"could we formulate some cool-looking sci-fi
# 'buildings' or blocks... completely rendered using primitive types... with the cyberpunk neon borders"*, then
# *"a cityscape type map would be good, but I would just need to get it to match the theme and consistency of our
# gladiator environment."* feel built `block` (40 x 24 x 40, theme prop.block) and its visual slot in round 7, and
# for a full round NOT ONE LAYOUT PLACED ONE. The capability existed and the player never met it; this file is
# where that gap closes.
#
# **It is an arena with streets, not a city.** The constraint he added is the binding one: it has to read as the
# same venue. So it keeps everything that makes the others his -- the hexagon at the 140 m bound, the container
# kit, barricades, wrecks, floodlights on the vertices, the screens facing each base -- and adds blocks as the
# thing that shapes the ground.
#
# WHY THE BLOCKS SIT WHERE THEY DO, since the hexagon does most of the deciding. The wall runs |x| <= 140 -
# 0.577|z|, so the field narrows hard toward the bases: at midfield a block corner may reach x = 128, but at
# z = 82 only 92.7. Every position below was checked corner-by-corner against that line with a 2 m margin, not
# eyeballed -- yard's round-7 lesson, where a container column at x = 115 went through the wall at z = 47.
#
# The arithmetic that fixes the grid: a 40 m block, a street, and another 40 m block need 80 m plus the street,
# and there is only 84 m from the centre line to where spawn clearance begins (the front spawn row is z = 90 and
# SPAWN_CLEARANCE is 6 m). **So two rows of blocks per half do not fit, at any street width.** The map is
# therefore a band ON the centre line and one band per half, which is why the plan below is a cross rather than a
# grid -- the shape is the hexagon's, not a preference.
#
# Streets are 20 m. That is 16 m of drivable navmesh once the 2 m agent radius has eaten both kerbs: two or three
# vehicles abreast, wide enough to be a route and narrow enough to be a queue. **No alley is under 20 m on
# purpose.** The maze proves 7 m physical gives 3 m drivable and single-file, and this is a map the lead plays,
# not a fixture -- with nav's flow fields unstarted, shipping him a deliberately near-impassable alley would be
# choosing to reproduce his loudest complaint.
def block(x, z, rot=0, **look):
    """One city block: ArenaKit 'block', 40 x 24 x 40, cover hard. `tiers`, `setback`, `neon` and `seed` are
    LOOK_KEYS -- they change the silhouette above the shopfronts and never the footprint or the symmetry."""
    return prop("block", x, z, rot, **look)


# Authored on the south/centre half; mirrored_props() supplies the north. Corners checked against the wall.
#   z = 0 band:   x = +-40  (spans 20..60)   and  x = +-100 (spans 80..120)
#   z = +-62 band: x = +-30 (spans 10..50)
# which leaves: a 40 m central plaza at the origin, a 20 m avenue straight up the middle between the mid-band
# blocks, 20 m streets between the z = 0 blocks, and a 22 m ring road across each half at z ~ 20..42.
terminus = [
    block(40, 0, tiers=3, neon="cyan", seed=11),
    block(100, 0, tiers=2, setback=1, neon="magenta", seed=23),
    block(30, 62, tiers=4, neon="magenta", seed=37),
    block(-30, 62, tiers=2, setback=1, neon="cyan", seed=41),
]
terminus += [
    # Street furniture, so a 20 m street is a fight and not a corridor: containers set back against the kerbs,
    # barricades at the mouths, wrecks where a lane opens out. Every one is the same kit as the other arenas --
    # that is the consistency he asked for, and it is why this reads as the venue rather than as a city level.
    c40(-70, 8, 0, 1, faction="law"), c40(70, -8, 0, 1, faction="gangs"),
    c20(-70, 30, 90, 2, faction="condemned"), c20(70, 30, 90, 1),
    c20(0, 30, 0, 1, faction="syndicate"), c40(0, -34, 0, 2, faction="mixed"),
    wreck(-16, 24, 20), wreck(18, -26, 200), wreck(62, 36, 75),
    barricade(-10, 42, 0), barricade(10, 42, 0), barricade(-64, 62, 90),
    c20(-88, 62, 0, 2, faction="law"), c20(88, 74, 0, 1, faction="condemned"),
    # The form-up line in front of each base, as every other arena has.
    # z = 80, not 84: the authoring clearance check refused 84 at 4.8 m from the spawn point at
    # [-44, 90] (SPAWN_CLEARANCE is 6.0). Caught before the file was written, which is the point of it.
    c20(-42, 80, 0, 1), c20(0, 80, 0, 1, faction="condemned", doors="open"), c20(42, 80, 0, 1),
    # Floodlights on the hexagon's east/west vertices; screens facing each base; a sign on the base-side corner.
    floodlight(-128, 0), # x = -76, hemmed in from both sides: the hexagon wall is at |x| = 82.2 at this z, and the spawn
    # lattice reaches x = -66, so a screen fits only in the 6 m of clearance between them.
    screen(-76, 100, 180, "arena"), screen(76, 96, 180, "faction"),
    sign(-64, 108, 180, "arena"),
]

write_v2("terminus", "The Terminus",
         "A block city dropped into the arena: 20 m streets between sheer neon-edged towers, a plaza at the "
         "crossroads and a ring road across each half. Sightlines end at the next corner, so a flank is a street "
         "away and an ambush is a doorway. Scouts and IFVs own the grid; artillery has to be walked into it.",
         terminus,
         shape={"kind": "hexagon"}, half_size=140.0,
         # The mirrored pair sits where the ring road crosses the west street, behind the enemy's near blocks:
         # reachable, but you must leave the plaza and cross a street to hold it.
         #
         # **Placement swept, not guessed, and the target is 0.4 rather than "as high as possible."** My first
         # instinct, (-72, -34), scored 0.52 -- which is not a better map, it is one objective nearly free and the
         # other nearly impossible. Ten placements were measured; (-75, -26) gives **0.406**, which puts this map
         # in the same family as the two he kept (yard 0.43, pit 0.42) rather than in boulevard's.
         objectives=objective_pair("the west ring", -75.0, -26.0, 15.0),
         lanes=[lane("the avenue", [(0, 90), (0, 42), (0, 0), (0, -42), (0, -90)], 18) | {"self_mirror": True},
                lane("west street", [(-70, 90), (-70, 20), (-70, -20), (-70, -90)], 18),
                lane("the ring road", [(-110, 30), (0, 30), (110, 30)], 20)],
         regions=[region("the plaza", "centre", 0, 0, 18),
                  region("avenue mouth", "chokepoint", 0, 42, 8),
                  region("west crossing", "chokepoint", -70, 0, 9),
                  region("ring road west", "flank", -80, 30, 16),
                  region("south approach", "open_ground", 0, 92, 20),
                  region("tower corner", "overlook", -52, 40, 7)])
