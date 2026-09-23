"""The terrain stream's arena layouts (round 10): maps built on water, pits and bridges.

Called from the end of `tools/make_arenas.py` (`make arenas`) with that module, so every helper -- `write_v2`,
`mirrored_props`, `objective_pair`, the kit props -- is the arena stream's own and nothing is re-implemented here.
arena owns make_arenas.py and reviews this file at merge; the only change there is the call and a `terrain`
argument to `write_v2`.

**The rule every map here is built to (the lead, 2026-09-18):** *"clearly crossing a bridge is risky, so you don't
want a simple map with 2 sides connecting two bridges. There generally has to be some compelling reason to cross
the bridge to take some advantageous ground."* Terrain makes the risk; a mirrored objective pair makes the reason;
the prize goes where the risk is. So every map here carries a pair, and each side's CONTESTED objective sits across
the water from its cheap one, at the far mouth of a crossing.

**Every map ships with a DRY TWIN** (`<name>_dry`, `fixture: true`): the same layout with `terrain: []`. It is the
null arm of the paired series (unit-time on the crossing vs the same seeds with no water, C6) and the before-frame
of every visual pair. A fixture never reaches a menu or the random rotation.
"""
import math
import sys

import arena_terrain


def water(name, x, z, width, depth):
    return {"kind": "water", "name": name, "rect": [float(x), float(z), float(width), float(depth)]}


def pit_area(name, x, z, width, depth):
    return {"kind": "pit", "name": name, "rect": [float(x), float(z), float(width), float(depth)]}


def bridge(name, x, z, width, depth):
    return {"kind": "bridge", "name": name, "rect": [float(x), float(z), float(width), float(depth)]}


def mirrored_terrain(half):
    """Each entry and its 180 degree twin; an entry centred on the origin is its own mirror and is listed once."""
    out = []
    for t in half:
        out.append(t)
        x, z, w, d = t["rect"]
        if x == 0 and z == 0:
            continue
        m = dict(t)
        m["name"] = t["name"] + " (far)"
        m["rect"] = [-x if x else 0.0, -z if z else 0.0, w, d]
        out.append(m)
    return out


def check_terrain(layout, clearance):
    """Authoring-time checks, so a bad layout is never written (the same discipline as check_spawn_clearance):
    R9's objective pair, R4's deck width, no spawn and no objective in the water, no prop standing in it."""
    terrain = layout.get("terrain", [])
    name = layout["name"]
    if not terrain:
        return
    if len(layout.get("objectives", [])) < 2:
        sys.exit("%s: R9 -- a map that carries terrain must carry a mirrored objective pair (a crossing needs a reason)" % name)
    for t in terrain:
        if arena_terrain.is_deck(t["kind"]) and min(t["rect"][2], t["rect"][3]) < arena_terrain.min_deck_m():
            sys.exit("%s: bridge %s is %.2f m across; R4 needs %.2f m (two widest hulls + bake radius + rails)"
                     % (name, t["name"], min(t["rect"][2], t["rect"][3]), arena_terrain.min_deck_m()))
    # Anything that must stand on dry ground, with the margin it needs: spawns keep the spawn clearance from the
    # water's edge AND its rim; an objective's whole disc must be dry, or part of what you hold is in the river.
    walls = arena_terrain.walls(terrain)
    for side in ("green", "rust"):
        for x, z in layout["spawns"][side]:
            wet = _nearest_wet(terrain, walls, x, z)
            if wet < clearance:
                sys.exit("%s: spawns.%s point [%s, %s] is %.1f m from water or its rim (need %.1f)" % (name, side, x, z, wet, clearance))
    for o in layout.get("objectives", []):
        x, z = o["position"]
        if _nearest_wet(terrain, walls, x, z) < o["radius"]:
            sys.exit("%s: objective %s at %s has part of its %.0f m disc in the water" % (name, o["name"], o["position"], o["radius"]))
    # R4: every declared lane two widest hulls wide after the bake, corners cleared for the rig -- measured WITH the
    # water, rims and rails (terrain_measure; arena's `test_arena_lanes.gd` is the game-side assertion).
    if not layout.get("fixture"):
        import terrain_measure
        for lane in terrain_measure.lanes_with_terrain(layout):
            bad = [c for c in lane["corners"] if not c["pass"]]
            if not lane["pass"] or bad:
                sys.exit("%s: lane %s fails R4: %.2f m drivable at %s; corners %s" % (
                    name, lane["name"], lane["drivable_m"], lane["at"], bad))
    import arena_report
    for box in arena_report.boxes_of(layout):
        for cx, cz in [box.corners()[i] for i in range(4)] + [(box.x, box.z)]:
            if arena_terrain.in_water(terrain, cx, cz):
                sys.exit("%s: %s at [%s, %s] stands in the water" % (name, box.kind, box.x, box.z))


def _nearest_wet(terrain, walls, x, z, step=1.0, reach=40.0):
    """Distance from (x, z) to the nearest wet point or rim/rail box, marched on a ring; `reach` if none."""
    best = reach
    for rect in walls:
        best = min(best, arena_terrain._rect_distance(rect, x, z))
    r = 0.0
    while r < best:
        for k in range(24):
            a = 2 * math.pi * k / 24
            if arena_terrain.in_water(terrain, x + math.cos(a) * r, z + math.sin(a) * r):
                return r
        r += step
    return best


def write_with_twin(m, name, title, fight, props, terrain, **kwargs):
    """The map, then its dry twin: identical but `terrain: []` and `fixture: true`."""
    m.write_v2(name, title, fight, props, terrain=terrain, **kwargs)
    kwargs = dict(kwargs)
    m.write_v2(name + "_dry", title + " (dry: no water)",
               "FIXTURE: %s with its terrain removed -- the null arm of its paired series and the before-frame of every "
               "picture of it. Not a map." % title, props, fixture=True, **kwargs)
    return m


# ---- The Crossing (round 10, backlog 2): a river, two bridges, two reasons ---------------------------------------
#
# A canal district. An S-shaped river crosses the middle: a WEST reach lying on green's side of the centre line
# (z 2..26), an EAST reach on rust's (its mirror, z -26..-2), joined by a narrow neck through the centre that
# nothing crosses. Each reach has one bridge, out toward the flank. So on each flank one army's bank bulges toward
# the other's base, and each bridge lands on the enemy's bulge.
#
# The objective pair sits on the bulges, at the far mouth of each bridge: green's cheap objective is on its own east
# bulge beside the east bridge, where RUST must cross to take it; green's contested one is on rust's west bulge,
# where GREEN must cross the west bridge. The prize is exactly where the risk is -- the mouth of a bridge its owner
# covers from its own bank.
#
# City blocks (the Terminus's, the lead's cityscape) stand on the banks either side of the neck: the river is one
# long sightline otherwise (the first draft, with containers only, let the centre see 75% of the field).
#
# Everything is authored on the south (green) half and mirrored.
RIVER_REACH = (-77.0, 14.0, 134.0, 24.0)   # x -144..-10, z 2..26: past the hexagon wall at every z it spans
RIVER_NECK = (0.0, 0.0, 20.0, 52.0)        # x -10..10, z -26..26: the S's middle stroke, its own mirror
CROSSING_BRIDGE = (-92.0, 14.0, 14.0, 34.0)  # x -99..-85, z -3..31: 14 m wide (R4 + rails need 13.14), 5 m onto each bank
CROSSING_OBJECTIVE = (-76.0, -22.0)          # rust's west bulge: green's contested objective (mirror: green's cheap)
CROSSING_BLOCKS = ((34.0, 33.0), (-38.0, 62.0))


def crossing(m):
    terrain = mirrored_terrain([water("west reach", *RIVER_REACH), water("the neck", *RIVER_NECK),
                                bridge("west bridge", *CROSSING_BRIDGE)])
    bx, bz = CROSSING_BLOCKS[0]
    cx, cz = CROSSING_BLOCKS[1]
    props = [
        # The quay blocks: one on green's east bulge beside the neck, one set back behind the west reach.
        m.block(bx, bz, tiers=2, setback=1, neon="cyan", seed=53), m.block(cx, cz, tiers=3, neon="magenta", seed=61),
        # Screens at the neck: a stack on each bulge beside it (mirrored onto rust's) and a wall across each end, so
        # the middle cannot see down the reaches or up the neck. Without them the centre saw 40% of the field.
        #
        # Placement was SWEPT against the report, not guessed, and the sweep found the instrument's weak spot: the
        # decision spread flips between ~0.45 and ~0.03 on whether one alley on the bulge is open, because
        # `decision_report` routes the ENEMY with green's exposure field (its covered route to the same objective
        # is 193 m or 121 m, while the plain route is 112 m either way). So the spread is reported beside the plain
        # route lengths in _agents/arenas.md, and this is the variant where the centre is under 0.30 AND the spread
        # does not rest on that flip. Reported to arena as an instrument finding.
        m.c40(0, 40, 0, 2, faction="law"), m.c20(24, 11, 0, 2, faction="condemned"), m.c40(30, 4, 0, 2, faction="mixed"),
        # Green's south bank of the west reach: a container wall along the quay, broken at the bridge mouth. It hides
        # an army forming to cross, and it is where green's overwatch of the bridge stands.
        *m.run("container_40", -76, 36, -62, 36, 2, faction="law"),
        # 22 m apart: the bridge mouth is a LANE (R4 physical bar 12.14 m); 10 m apart they closed it.
        m.barricade(-106, 42, 0), m.barricade(-78, 42, 0),
        # Green's east bulge, around its cheap objective: cover the defender can hold without standing on it.
        m.c20(104, 22, 90, 2, faction="gangs"), m.wreck(66, 34, 70), m.c20(60, 6, 0, 1, faction="mixed"),
        # The approaches from the base: cover lines, offset so no lane is straight.
        m.c40(8, 64, 0, 1), m.c40(58, 60, 0, 2, faction="syndicate"), m.wreck(-86, 70, 20), m.c20(92, 50, 90, 1),
        # Form-up line in front of the base, as every arena has.
        m.c20(-42, 80, 0, 1), m.c20(0, 80, 0, 1), m.c20(42, 80, 0, 1),
        # Lamps: one at the bridge mouth on the bank side (the crossing is lit, the water is not), one by the block.
        m.floodlight(-108, 36), m.floodlight(8, 44),
        m.screen(-76, 100, 180, "arena"), m.sign(-81, 88, 180, "arena"),  # outside the spawn zone (x +-75), as arena moved the others in CP2
    ]
    write_with_twin(m, "crossing", "The Crossing",
                    "A river snakes through a canal district and two bridges cross it, each landing on the enemy's "
                    "bank beside the objective they hold cheaply. Take theirs and you fight at the far end of a bridge "
                    "they can see; hold yours and you are the kill zone. Tanks force a crossing; artillery owns the "
                    "water; scouts find the one that is unwatched.",
                    props, terrain,
                    shape={"kind": "hexagon"}, half_size=140.0,
                    objectives=m.objective_pair("the west landing", *CROSSING_OBJECTIVE, 14.0),
                    # R4 lanes, found by a clearance-grown A* (every point >= half the physical bar from any collider,
                    # rim, rail or water) and simplified; certified by `terrain_measure.lanes_with_terrain`, which
                    # check_terrain runs. The mirror is the east bridge from rust's side.
                    lanes=[m.lane("west bridge", [(-70, 88), (-87, 44), (-92, 28), (-92, -16), (-60, -86)], 14)],
                    regions=[m.region("west bridge", "chokepoint", -92, 14, 8),
                             m.region("the east bulge", "cover_cluster", 76, 22, 20),
                             m.region("the west quay", "overlook", -70, 40, 10),
                             m.region("the neck", "open_ground", 0, 36, 10)])


# ---- The Sumps (round 10, backlog 3: "the Pits"): kill zones without a river ------------------------------------
#
# NAMED `sumps`, not `pits`: the lead KEPT a map called `pit` ("The Pit", the container ring), and `ARENA=pit` next
# to `ARENA=pits` -- and an announcer calling both -- is a mix-up waiting to happen. The brief's working title was
# "the Pits"; the map's name is the Sumps (a drained works: a pump house and its sumps).
#
# His sentence: *"elements that units could not cross but they could still fire over. Useful for setting up kill
# zones."* No river and no line to hold: a pump house (a city block) stands in the centre, and a chain of sheer pits
# runs out from it to both walls. The gaps between them are the CAUSEWAYS -- the short ways forward, each a lane
# between two drops, watched from behind cover across the pits. A catwalk over the west pit is the shortest, most
# exposed crossing of all.
#
# The objective pair sits beyond the chain, so the short route to the contested objective runs along a pit's edge
# in the open, and the safe route is the long way round. Each side's cheap one is on its own side of the chain.
#
# The first draft put the great pit and its catwalk in the CENTRE, and the middle then saw 71% of the field -- a
# pit hides nothing, so a pit at the centre is the open brawl he cut four maps for. The pump house is the fix.
PITS_WEST = (-55.0, 14.0, 42.0, 24.0)     # x -76..-34, z 2..26: a 14 m causeway to the pump house (x -20)
PITS_FAR = (-119.0, 14.0, 50.0, 24.0)     # x -144..-94: to the wall, an 18 m causeway to the west pit
PITS_CATWALK = (-55.0, 14.0, 14.0, 34.0)  # over the west pit, bank to bank
PITS_OBJECTIVE = (-52.0, -22.0)           # beyond the west pit on rust's side: green's contested objective


def pits(m):
    terrain = mirrored_terrain([pit_area("the west pit", *PITS_WEST), pit_area("the far pit", *PITS_FAR),
                                bridge("the catwalk", *PITS_CATWALK)])
    props = [
        # The pump house (its own mirror): the centre is cover, not a view.
        m.block(0, 0, tiers=2, setback=1, neon="magenta", seed=71),
        # Overwatch across the chain: container stacks set back from the south lips, with gaps to shoot through. A
        # defender here sees the causeways on the far side; an attacker crossing is in the open.
        m.c40(-68, 38, 0, 2, faction="syndicate"), m.c20(-38, 36, 0, 2, faction="law"), m.c40(-112, 36, 0, 2),
        # Screens on the east side's south lip (their mirrors stand on the west's north lip): they break the view
        # along the chain, so the pump house's corners do not see down the whole band.
        # BETWEEN the crossings, never in a mouth: the first version stood these at the east crossings' mouths,
        # whose mirrors are the west ones, and closed three R4 lanes.
        m.c20(41, 8, 0, 2, faction="gangs"), m.c20(69, 8, 0, 2, faction="mixed"), m.c20(112, 10, 0, 2),
        # The pump house's own sightlines up the middle and along the causeways, broken (swept: ring-eye centre
        # 0.39 -> 0.34; a kill-zone map is open ACROSS its pits by design, so this is flagged for his eye rather
        # than pushed under 0.30 by burying the pits in cover).
        m.c40(0, 46, 0, 2, faction="law"), m.c20(-14, 34, 0, 2), m.c20(14, 34, 0, 2, faction="condemned"),
        # Re-swept on arena's FIXED eye (round 10: the old one stood inside the pump house and read 0.00; placed on
        # the pump house's corner it read 0.48). Three-high stacks off the corner: 0.48 -> 0.34, every lane intact.
        m.c40(46, 30, 0, 3, faction="syndicate"), m.c40(8, 30, 0, 3, faction="gangs"), m.c20(38, 16, 90, 3),
        # Green's cheap objective (the mirror, at (44, 30)) and cover a holder uses without standing on it.
        m.c20(70, 44, 90, 2, faction="condemned"), m.wreck(22, 52, 60),
        # Approaches and the form-up line.
        m.block(62, 66, tiers=1, neon="cyan", seed=73), m.wreck(-8, 62, 20),
        m.c20(-42, 80, 0, 1), m.c20(0, 80, 0, 1), m.c20(42, 80, 0, 1),
        m.floodlight(-40, 42), m.floodlight(-128, 0),
        m.screen(-76, 100, 180, "arena"), m.sign(-81, 88, 180, "arena"),  # outside the spawn zone (x +-75), as arena moved the others in CP2
    ]
    write_with_twin(m, "sumps", "The Sumps",
                    "A pump house in the middle and a chain of sheer sumps out to both walls, a catwalk over one. The "
                    "short ways forward are the causeways between the drops, watched from cover across the pits; the "
                    "safe way is the long one round. Hold the far objective and you hold a kill zone; take it and you "
                    "cross one.",
                    props, terrain,
                    shape={"kind": "hexagon"}, half_size=140.0,
                    objectives=m.objective_pair("the far causeway", *PITS_OBJECTIVE, 14.0),
                    # R4 lanes (as the Crossing's): each crossing from green's approach to just past the far lip,
                    # ending before any two meet -- a junction is certified for a right-angle turn, 11 m of clearance.
                    lanes=[m.lane("the catwalk", [(-55, 86), (-55, -1), (-45, -24)], 14),
                           m.lane("west causeway", [(-27, 86), (-27, -30)], 14),
                           m.lane("far causeway", [(-85, 80), (-87, -20)], 16)],
                    regions=[m.region("the catwalk", "chokepoint", -55, 14, 7),
                             m.region("west causeway", "chokepoint", -27, 14, 7),
                             m.region("the south lip", "overlook", -40, 34, 10),
                             m.region("the pump house", "centre", 0, 0, 24)])


# ---- The Terminus with a canal (round 10, backlog 4): a PROPOSAL, a fixture, frames only -------------------------
#
# arena owns the Terminus; this is not it. It is the Terminus's own props with the ring road turned into a canal and
# 20 m bridges carrying the avenue and both side streets over it, written as a FIXTURE so it can be shot and
# measured beside the real map and never reaches a menu.
#
# What it costs, which is the point of drawing it: the ring road is a declared R4 lane and the plaza crossings run
# along it, so both go; the objective pair sat ON the ring road and has to move (here to the street corners beyond
# it). A canal on the Terminus is a redesign of the lead's acceptance map, not a dressing -- his call, with arena.
TERMINUS_CANAL = (0.0, 30.0, 290.0, 14.0)          # z 23..37 along the ring road, past the walls both ends
TERMINUS_BRIDGES = ((0.0, 30.0), (-70.0, 30.0), (70.0, 30.0))  # the avenue and both streets, 20 m wide


def terminus_canal(m):
    half = [water("the canal", *TERMINUS_CANAL)] + [bridge("the %s bridge" % n, x, z, 20.0, 22.0)
                                                   for n, (x, z) in zip(("avenue", "west street", "east street"), TERMINUS_BRIDGES)]
    terrain = mirrored_terrain(half)
    # Keep the Terminus's props, minus anything standing in the canal or on its rim (one container, at a kerb).
    def dry(p):
        x, z = p["position"]
        return not (abs(z) - 0.0 > 23.0 - 3.0 and abs(z) < 37.0 + 3.0 and abs(x) < 145.0)
    props = [p for p in m.terminus if dry(p)]
    m.write_v2("terminus_canal", "The Terminus (canal proposal)",
               "FIXTURE, a proposal to arena and the lead: the Terminus with its ring road a canal and 20 m bridges on "
               "the avenue and both streets. Costs the ring-road lanes and moves the objective pair off the water.",
               props, fixture=True, terrain=terrain, shape={"kind": "hexagon"}, half_size=140.0,
               objectives=m.objective_pair("the west ring", -75.0, -58.0, 15.0),
               lanes=[m.lane("the avenue", [(0, 90), (0, 42), (0, 0), (0, -42), (0, -90)], 18) | {"self_mirror": True},
                      m.lane("west street", [(-70, 90), (-70, 20), (-70, -20), (-70, -90)], 18),
                      m.lane("east street", [(70, 90), (70, 20), (70, -20), (70, -90)], 18)])


def author(m):
    crossing(m)
    pits(m)
    terminus_canal(m)
