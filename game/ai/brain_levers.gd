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
##                      1 probes the END only. (The first version probed the midpoint only: on the Sumps the midpoint
##                      refused 0 of ~49 000 chords and the end all 0.3 a tick that were refused, so "midpoint only"
##                      meant "never refuse"; `127e8f66`, builder0, ai-parts-match.)
##   orca_neighbours    6   → how many nearest neighbours ORCA avoidance solves against (Avoidance.solve).
##   far_exec_stride    1   → a CPU unit with no known enemy in reach (its think-LOD bucket is not "fight") runs its
##                      whole controller every this many ticks, staggered; the hull keeps its last command in between
##                      and still moves every tick; a new order or element call runs it at once (the round-5
##                      `brain_stride` machinery, per unit). Never the player's own units.
##   far_exec_straight  false → with far_exec_stride: stride only while Movement.straight_and_clear() (a plain straight
##                      leg, touching nothing, not deflected, not in a planned leg). The Sumps driving series showed
##                      route scrapes +40..+80 a minute with the plain stride.

const FAR_IDLE_HZ := "far_idle_hz"
const KTURN_CHECK_TICKS := "kturn_check_ticks"
const CHORD_SAMPLES := "chord_samples"
const ORCA_NEIGHBOURS := "orca_neighbours"
const FAR_EXEC_STRIDE := "far_exec_stride"
const FAR_EXEC_STRAIGHT := "far_exec_straight"
const DEFAULTS := {FAR_IDLE_HZ: 0.0, KTURN_CHECK_TICKS: 6, CHORD_SAMPLES: 2, ORCA_NEIGHBOURS: 6, FAR_EXEC_STRIDE: 1,
		FAR_EXEC_STRAIGHT: false}

## The A/B's gate (see above). True outside an A/B.
static var gate := true
## The SPLIT A/B (`--brains-ab-run=levers-split`, BrainsAB): the levers are open for HALF the units (by a hash of the
## unit's name) and closed for the other half, and the halves swap every block (`split_flip`). Both arms then run in
## the same ticks of the same fight, so the fight's own trend (units dying, the fight moving) is in both; BrainsAB
## times each controller and charges it to its unit's half. Measurement only.
static var split := false
static var split_flip := 0


## Is the lever open for this unit right now? `unit` is the unit's name ("" = asked without one: the gate alone).
static func open_for(unit: String) -> bool:
	if not gate:
		return false
	if split and unit != "":
		return ((unit.hash() & 1) ^ split_flip) == 0
	return true


static func far_idle_hz(team: int, unit := "") -> float:
	if team < 0 or not open_for(unit):
		return 0.0
	return float(BrainVariants.for_team(team).get(FAR_IDLE_HZ, 0.0))


static func kturn_check_ticks(team: int, unit := "") -> int:
	if team < 0 or not open_for(unit):
		return 6
	return int(BrainVariants.for_team(team).get(KTURN_CHECK_TICKS, 6))


static func chord_samples(team: int, unit := "") -> int:
	if team < 0 or not open_for(unit):
		return 2
	return int(BrainVariants.for_team(team).get(CHORD_SAMPLES, 2))


static func orca_neighbours(team: int, unit := "") -> int:
	if team < 0 or not open_for(unit):
		return 6
	return int(BrainVariants.for_team(team).get(ORCA_NEIGHBOURS, 6))


static func far_exec_stride(team: int, unit := "") -> int:
	if team < 0 or not open_for(unit):
		return 1
	return int(BrainVariants.for_team(team).get(FAR_EXEC_STRIDE, 1))


static func far_exec_straight(team: int, unit := "") -> bool:
	if team < 0 or not open_for(unit):
		return false
	return bool(BrainVariants.for_team(team).get(FAR_EXEC_STRAIGHT, false))


## The lever features a variant sets, {} for the champion (for logs: what a run actually priced).
static func of_variant(team: int) -> Dictionary:
	var out := {}
	var profile := BrainVariants.for_team(team)
	for key: String in DEFAULTS:
		if profile.has(key) and profile[key] != DEFAULTS[key]:
			out[key] = profile[key]
	return out
