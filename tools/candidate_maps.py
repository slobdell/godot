"""Round 18 (maps): CANDIDATE maps -- built to be played by the lead, never dealt until he says so (`Arena.CANDIDATES`,
contract C18.2). Imported by `tools/make_arenas.py`, which passes itself in, as `tools/terrain_maps.py` is.

His direction (2026-10-04, verbatim in `_agents/streams/maps.md`): room for vehicles to manoeuvre, a few chokepoints,
ground where screens and ambushes have a reason to exist, and *"a large open center that allows us to use these big
formations, but then create the necessary cover such that any team using a line abreast formation could easily be
ambushed from cover (i.e. a line abreast formation could get ambushed by another formation that was orthogonal)"*.

Every candidate is written with `fixture=True` (nothing offers a fixture: the booth, the picker, `random`) and listed
in `Arena.CANDIDATES` (what tells it from an instrument, and what holds its lanes to R4). The numbers that describe
each one before he plays it: `make arena-room` (tools/arena_room.py). Authoring rules are make_arenas.py's: author the
SOUTH (green, +z) half; the 180 degree mirror is the north; spawns sit at z 90..114 across x +-66, keep cover out of
z > 80 inside x +-74. The fairness invariant is ROTATIONAL symmetry, so a half need not be bilaterally symmetric.
"""
from __future__ import annotations


def parade(m):
    """Candidate 1: the Parade Ground -- the map he described.

    A clear floor 124 m wide across the middle (the ladders' inner ends at x = +-62), wide enough for three squads
    line abreast. Along each side of it a LADDER of container walls running across the line of advance (rungs E-W,
    24 m apart, staggered between the two sides by the mirror): a hull tucked behind a rung is hidden from a force
    starting across the floor, and sees out along the rung's length into the floor -- so a line crossing the middle
    shows the END of its line to whoever waits in the ladder, and that ambusher's own formation stands at right angles
    to the line's advance (his words). Behind each ladder, a slower covered way round between the ladder and the wall,
    entered past a neck at each end (a container wall from the hexagon wall in, and a short wall screening the ladder
    from the base: a 20 m gap between them). The objectives: a mirrored pair of depots at the mouth of each side's
    own ladder, so each side holds one cheaply and must cross the floor -- or go round -- for the one at the enemy's
    ladder.
    """
    half = []
    # The ladders. West rungs at z = 30 and 6 (authored); east rungs at z = 18 and 42 (authored). The mirror gives the
    # west ladder z = -18, -42 and the east ladder z = -6, -30: each ladder has four rungs, 24 m apart.
    for z in (30, 6):
        half += m.run("container_40", -98, z, -62, z, 2, faction="condemned")
    for z in (18, 42):
        half += m.run("container_40", 62, z, 98, z, 2, faction="syndicate")
    # The necks on the way round, at the base end of each ladder: a wall from the hexagon wall in (at z = 58 the wall
    # is at |x| = 106.5), a 20 m gap, and a short wall that also screens the ladder from the base apron.
    # The outer wall runs into the hexagon's (|x| = 106.5 at z = 58): a 6 m slot between a box and a wall is
    # where a hull wedges (the Locks, round 11).
    half += m.run("container_40", -110, 58, -94, 58, 2, faction="law")
    half += m.run("container_40", -76, 58, -62, 58, 2, faction="law")
    half += m.run("container_40", 94, 58, 110, 58, 2, faction="gangs")
    half += m.run("container_40", 62, 58, 76, 58, 2, faction="gangs")
    half += [
        # Cover on the base approach, beside the way round's neck.
        m.c20(-50, 54, 90, 2, faction="mixed"), m.c20(-34, 70, 0, 1, faction="mixed"), m.wreck(-50, 72, 25),
        # A cover line in front of the base: somewhere to form up out of the first volley.
        m.c20(-14, 78, 0, 1, faction="condemned"), m.c20(18, 78, 0, 1), m.barricade(40, 76, 0),
        # Lights on the hexagon's east/west vertices; a screen facing the base; the sign outside the spawn zone.
        m.floodlight(-128, 0), m.screen(30, 74, 180, "arena"), m.sign(-81, 88, 180, "arena"),
    ]
    m.write_v2("parade", "The Parade Ground",
               "A parade ground 120 m across between two ladders of container walls. Cross it in line and whoever "
               "waits in the ladders shoots down your line from its end; go round behind the ladders and the necks "
               "at each end are the fight. Each side's depot sits at the mouth of its own ladder: hold yours, or cross for theirs.",
               half, fixture=True, shape={"kind": "hexagon"}, half_size=140.0,
               # Swept, not guessed (arena_report's decision spread, laptop): (-45, 62) on the base approach scored 1.00 -- one
               # depot free, the other impossible; (-50, 20), at the mouth of each side's own ladder, scores 0.36, in
               # the family of the maps he kept (yard 0.43, pit 0.42). So the far depot is across the floor, at the
               # mouth of the enemy's ladder: the crossing and the ambush ground are the same place.
               objectives=m.objective_pair("the depot", -50.0, 20.0, 15.0),
               lanes=[m.lane("the floor", [(0, 90), (0, 0), (0, -90)], 30) | {"self_mirror": True},
                      m.lane("west way round", [(-80, 84), (-85, 58), (-110, 34), (-114, 0), (-110, -34), (-85, -58), (-80, -84)],
                             16) | {"mirror_name": "east way round"}],
               regions=[m.region("the parade ground", "open_ground", 0, 0, 50),
                        m.region("west neck", "chokepoint", -85, 58, 8), m.region("east neck", "chokepoint", 85, 58, 8),
                        m.region("west ladder", "cover_cluster", -75, 6, 26), m.region("east ladder", "cover_cluster", 75, 18, 26),
                        m.region("west way round", "flank", -104, 0, 14)])


def gorge(m):
    """Candidate 2: the Gorge -- a wide valley, two necks into it, and a road round them.

    A band of sheer pits right across each half (z 38..50 on green's), broken by two 16 m causeways at x = +-40: the
    necks. Past the band's ends, between the last pit and the hexagon wall, a road round (about 17 m): longer, and it
    comes out on the valley's flank. Between the two bands the valley: 76 m deep and the arena's full width, open
    ground with a scatter of cover, where formations have room. The objective pair sits in the valley, on the far
    side of the centre line, so both sides must come down through a neck -- or round -- to fight for it.
    """
    from terrain_maps import mirrored_terrain, pit_area
    terrain = mirrored_terrain([pit_area("the west drop", -72.0, 44.0, 48.0, 12.0),
                                pit_area("the middle drop", 0.0, 44.0, 64.0, 12.0),
                                pit_area("the east drop", 72.0, 44.0, 48.0, 12.0)])
    half = [
        # Overwatch over each neck from the base side, set off its mouth.
        m.c40(-62, 60, 0, 2, faction="law"), m.c20(-18, 62, 0, 2, faction="law"),
        m.c40(62, 60, 0, 2, faction="gangs"), m.c20(18, 62, 0, 2, faction="gangs"),
        # The valley's scatter: walls end-on to the advance on the flanks, wrecks in the middle.
        m.c40(-84, 14, 90, 2, faction="condemned"), m.c20(-58, -6, 30, 2), m.wreck(-24, 18, 40),
        m.c40(28, 22, 0, 1, faction="syndicate"), m.wreck(60, 8, 110), m.c20(96, -10, 90, 2, faction="mixed"),
        # The form-up line, and the dressing.
        m.c20(-32, 78, 0, 1), m.c20(32, 78, 0, 1, faction="condemned"),
        m.floodlight(-128, 0), m.screen(0, 74, 180, "arena"), m.sign(-81, 88, 180, "arena"),
    ]
    m.write_v2("gorge", "The Gorge",
               "A valley between two bands of sheer drops. Two causeways lead down into it from each side -- the "
               "necks -- and a longer road runs round the ends of the drops onto the valley's flank. The prize is in "
               "the valley, past the middle: come through a neck and be seen, or go round and be late.",
               half, fixture=True, shape={"kind": "hexagon"}, half_size=140.0, terrain=terrain,
               objectives=m.objective_pair("the valley", -70.0, -20.0, 14.0),
               lanes=[m.lane("west neck", [(-40, 86), (-40, 20)], 14),
                      m.lane("east neck", [(40, 86), (40, 20)], 14),
                      m.lane("west road round", [(-82, 84), (-106, 44), (-104, 4)], 14)],
               regions=[m.region("the valley", "open_ground", 0, 0, 40),
                        m.region("west neck", "chokepoint", -40, 44, 8), m.region("east neck", "chokepoint", 40, 44, 8),
                        m.region("west road round", "flank", -106, 44, 8)])


def archipelago(m):
    """Candidate 3: the Archipelago -- islands of dense cover in open ground.

    Seven islands: a walled one at the centre, and three pairs: two forward (+-70, +-25), two on the approaches
    (+-40, +-46), two against the east and west walls (+-100, -+8). Each island hides a squad and has a side open
    toward the next; between them, 40-60 m of open ground. A fight jumps island to island, and the open ground
    between is where a screen earns its keep. The objectives are the forward islands.
    """
    half = [
        # The centre island: a broken square of stacked boxes (their mirrors close it), open on the diagonals.
        m.c40(0, 9, 0, 2, faction="syndicate"), m.c20(-10, 0, 90, 2, faction="syndicate"),
        # The west forward island, open to the north (its mirror is the east one, open to the south).
        m.c40(-70, 34, 0, 2, faction="condemned"), m.c20(-79, 26, 90, 2), m.c20(-61, 24, 90, 1, faction="condemned"),
        m.wreck(-70, 16, 30),
        # The east approach island, an L.
        m.c40(40, 52, 0, 2, faction="law"), m.c20(31, 44, 90, 2, faction="law"), m.wreck(48, 40, 75),
        # The west wall island (its mirror stands on the east wall).
        m.c40(-104, -8, 90, 2, faction="gangs"), m.c20(-96, 2, 0, 1, faction="gangs"),
        # The form-up line, and the dressing.
        m.c20(-30, 78, 0, 1), m.c20(28, 78, 0, 1, faction="mixed"), m.barricade(0, 76, 0),
        m.floodlight(-128, 0), m.screen(70, 74, 180, "arena"), m.sign(-81, 88, 180, "arena"),
    ]
    m.write_v2("archipelago", "The Archipelago",
               "Islands of stacked containers in open ground: one walled in the middle, three pairs out across the "
               "field. Every island hides a squad and every gap between them is open. Fights jump from island to "
               "island; whoever screens the open ground crosses it. The forward islands are the prize.",
               half, fixture=True, shape={"kind": "hexagon"}, half_size=140.0,
               objectives=m.objective_pair("the forward island", -70.0, 26.0, 14.0),
               lanes=[m.lane("west gap", [(-27, 86), (-27, -30)], 20)],
               regions=[m.region("the centre island", "cover_cluster", 0, 0, 14),
                        m.region("west forward island", "cover_cluster", -70, 26, 14),
                        m.region("the open", "open_ground", -35, 0, 20)])


def cut(m):
    """Candidate 4: the Cut -- one long open diagonal, crossed by a covered trench.

    City blocks fill the arena's south-east and north-west; between them a broad open band runs corner to corner from
    green's left to rust's left, the longest open axis in any of our maps. Across its middle, at right angles, the
    trench: two walls of stacked containers 20 m apart, each with a gap, a covered way from one block mass to the
    other through the open band. Hold the trench and you cross the band under cover; stay in the band and you have
    room, and nowhere to hide from it.
    """
    half = [
        # The south-east block mass (its mirror is the north-west).
        m.block(78, 30, tiers=2, neon="cyan", seed=181), m.block(22, 58, tiers=1, neon="magenta", seed=182),
        # Cover in the open band, sparse: wrecks a squad can stop behind, not hide in.
        m.wreck(-56, 30, 20), m.wreck(-90, 10, 70), m.c20(-78, 52, 45, 1, faction="mixed"),
        # The form-up line, and the dressing.
        m.c20(-40, 80, 0, 1), m.barricade(-10, 78, 0),
        m.floodlight(-128, 0), m.screen(-70, 74, 180, "arena"), m.sign(-81, 88, 180, "arena"),
    ]
    m.write_v2("cut", "The Cut",
               "A broad open band from corner to corner between two masses of city blocks, and a trench across its "
               "middle: two container walls, a covered way from one block mass to the other. Stay in the band for "
               "room; take the trench to cross it unseen. The objectives sit out in the band.",
               half, fixture=True, shape={"kind": "hexagon"}, half_size=140.0,
               # The trench: concrete walls (the legacy `wall`, never turned) on z - x = 14 with a gap; the mirror is
               # the wall on z - x = -14. Not containers: the seeded turn puts a corner past its neighbour's face at
               # every joint, and along a lane that is a tooth (M6) -- a trench a rig scrapes down its length.
               obstacles=[m.ob("wall", -22, -8, -45, (22.6, 3.0, 1.5)), m.ob("wall", 8, 22, -45, (22.6, 3.0, 1.5))],
               # Swept (decision spread, laptop): (-60, 34) 0.61, (-60, 10) 0.25, (-40, 20) 0.47, (-80, 30) 0.45 -- out on
               # the band's far side by the wall, where holding it means standing in the open.
               objectives=m.objective_pair("the band", -80.0, 30.0, 14.0),
               lanes=[m.lane("the band", [(-60, 84), (0, 0), (60, -84)], 30) | {"self_mirror": True},
                      m.lane("the trench", [(-30, -30), (30, 30)], 16) | {"self_mirror": True}],
               regions=[m.region("the band", "open_ground", -40, 40, 30), m.region("the trench", "cover_cluster", 0, 0, 14),
                        m.region("south-east blocks", "cover_cluster", 50, 45, 30)])


def author(m):
    parade(m)
    gorge(m)
    archipelago(m)
    cut(m)
