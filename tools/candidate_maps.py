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


def author(m):
    parade(m)
