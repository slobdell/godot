class_name BrainLevers
extends RefCounted
## Round 17 (brains): the tick's DECISION levers — each changes what a brain does, so each is OFF by default, priced
## (cost by removal inside one run, behaviour on the ladder, drills, scenarios, arrivals, K1, first contact and first
## shot) and put on the lead's page. Nothing here is ON for anyone until his tap ships it (C17.4).
##
## A lever is a FEATURE of a brain variant (BrainVariants.PROFILES, the `l17*` rows), so the ladder can play a lever
## against the champion and any run picks it with `--green-brain=<id> --rust-brain=<id>`. The champion has none of
## these features, so the default path reads every lever's default value and runs exactly the code it ran before
## (the sim baseline and `make ai-parity` prove it on every commit).
##
## `gate` is the in-run A/B's hand on all of them at once (`--brains-ab-run=levers`, BrainsAB): closed, every lever
## reads its default whatever the variant says, so one run alternates "the variant's levers" and "the champion's
## behaviour" in blocks and both arms share the machine's load (C16.3). Measurement only; never closed by the game.
##
## The levers (feature key: default → what the lever does):
##   far_idle_hz        0.0 → a CPU brain with no known enemy within TankBrain.LOD_RADIUS, no element station, and no
##                      order or element call waiting thinks this many times a second instead of the idle 3.3. Never the
##                      player's own units. Wakes on the existing triggers (a new order, an element call, an intel
##                      refresh that raises its rate). Expressed in simulation state only: never the camera.
##   kturn_check_ticks  6   → how often (ticks) a wheeled hull not in a planned reverse leg asks whether its forward arc
##                      will meet a wall (Movement._planned_reverse).
##   chord_samples      2   → how many points along a carrot chord are probed on the navmesh (Movement._chord_compute):
##                      1 probes the midpoint only.
##   orca_neighbours    6   → how many nearest neighbours ORCA avoidance solves against (Avoidance.solve).

const FAR_IDLE_HZ := "far_idle_hz"
const KTURN_CHECK_TICKS := "kturn_check_ticks"
const CHORD_SAMPLES := "chord_samples"
const ORCA_NEIGHBOURS := "orca_neighbours"
const DEFAULTS := {FAR_IDLE_HZ: 0.0, KTURN_CHECK_TICKS: 6, CHORD_SAMPLES: 2, ORCA_NEIGHBOURS: 6}

## The A/B's gate (see above). True outside an A/B.
static var gate := true


static func far_idle_hz(team: int) -> float:
	if not gate or team < 0:
		return 0.0
	return float(BrainVariants.for_team(team).get(FAR_IDLE_HZ, 0.0))


static func kturn_check_ticks(team: int) -> int:
	if not gate or team < 0:
		return 6
	return int(BrainVariants.for_team(team).get(KTURN_CHECK_TICKS, 6))


static func chord_samples(team: int) -> int:
	if not gate or team < 0:
		return 2
	return int(BrainVariants.for_team(team).get(CHORD_SAMPLES, 2))


static func orca_neighbours(team: int) -> int:
	if not gate or team < 0:
		return 6
	return int(BrainVariants.for_team(team).get(ORCA_NEIGHBOURS, 6))


## The lever features a variant sets, {} for the champion (for logs: what a run actually priced).
static func of_variant(team: int) -> Dictionary:
	var out := {}
	var profile := BrainVariants.for_team(team)
	for key: String in DEFAULTS:
		if profile.has(key) and profile[key] != DEFAULTS[key]:
			out[key] = profile[key]
	return out
