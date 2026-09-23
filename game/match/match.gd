class_name Match
extends Node
## The rules of a match: teams, spawning, shells, damage, death, respawn, score.
##
## Rule decisions (damage, death, scoring) happen only on the simulating peer
## (server or offline). The spawn functions run on EVERY peer, so replicated
## tanks and shells are built identically everywhere (node paths must match).

signal local_tank_spawned(tank: Tank)
## Emitted once when a score or time limit is reached (see start_limits).
signal finished(result: Dictionary)
## Simulating peer: the control point changed hands (-1 = neutral).
## N7: an objective changed hands. `index` is its position in `objectives`; `owner` is -1, Team.GREEN or Team.RUST.
## `control_changed` still fires for the primary objective, so pre-N7 listeners need no change.
signal objective_changed(index: int, owner: int)
signal control_changed(owner: int)
## Simulating peer: a tank was destroyed (by `killer`, a tank name).
signal tank_destroyed(victim: Tank, killer: String)
## Simulating peer: `shooter` (a tank name) hurt its own teammate `victim` (R4: friendly fire is on).
signal friendly_fire(victim: Tank, shooter: String, hull: int, killed: bool)
## K2 (round 3), simulating peer: a weapon fired one round (or, for fire, a puff every CONE_EVENT_TICKS while held).
## {tick, shooter, weapon, fire_model, muzzle [x,y,z], direction [x,y,z], projectile_id, speed_mps, range}.
signal weapon_fired(event: Dictionary)
## K2, simulating peer: a round struck something. {tick, projectile_id, position [x,y,z], normal [x,y,z],
## target? (unit name), face? ("front"/"side"/"rear"), weak_spot, damage (shield + hull points), killed}. A shell or beam
## that hits a wall has no target and 0 damage; a round that flies out of range reports nothing. Arc bursts add
## victims: [{target, face, damage, killed}] and name the most-hurt victim as target.
signal projectile_impact(event: Dictionary)
## Round 3 stretch, simulating peer: a unit was destroyed, with where its wreck lies (effects, wreck art, the announcer).
## {tick, unit (name), unit_id, team, killer (a unit name, "hazard:<type>", or ""), cause ("enemy" | "friendly_fire" |
## "hazard"), position [x,y,z], forward [x,y,z] (flat unit vector), hull_size [w,h,l]}. Emitted right after tank_destroyed.
signal unit_destroyed(event: Dictionary)

enum Team { GREEN, RUST }

const TEAM_NAMES := ["Green", "Rust"]
const TANK_SCENE := preload("res://game/tank/tank.tscn")
const SHELL_SCENE := preload("res://game/combat/shell.tscn")
const BASE_DAMAGE := 34.0
## Bases sit this far north/south of center; slots spread along x.
## Arena geometry. Obstacles and spawns come from the arena layout (arenas/*.json, Arena); the size is fixed here.
## 2026-09-13: doubled from 60 → 120 after the lead's first skirmish; contact was
## immediate on the small map and formations had no room.
##
## X3 (round 7, 2026-09-19): 120 → 140, and it is now a **BOUND, not a size**. A layout declares its own
## `half_size` under it (Arena.validate), so Pit and Yard stay 120 x 120 and nothing about them changes; what moved
## is the ceiling, which is what a hexagon of circumradius 139.7 needs in order to exist at all. Depends on arena's
## `877dc34a`, merged into this branch: before it, validate demanded half_size == this constant, so raising it would
## have grown every shipped map 36% as a side effect of a shape change nobody asked to apply to them.
##
## The constant was doing two jobs -- "how big is the play area" and "how big is the world the HUD must cover" -- and
## a non-square arena is what makes them different numbers. **Anything that draws or declares the PLAY AREA must read
## `Arena.active.half_size`** (the pattern in `RtsCamera.perimeter_half()`), never this.
const ARENA_HALF_SIZE := 140.0
## How close to the perimeter tanks and slots may be sent (walls' inner face minus clearance).
##
## X3: this did NOT scale with the bound, and the reason is the whole point of M4. It is a **square** clamp, so on a
## hexagon of circumradius 139.7 -- inradius 121.0 -- a limit of 136 would admit points 192 m from centre on the
## diagonal, well outside the wall, and `Arena.validate` would approve every one of them. It is about three times too
## permissive, not slightly. The conservative inscribed bound is 121.0 - 4.0 = **117**.
##
## Left at **116**, one metre inside that, deliberately: 116 is already within 117, so it is safe for the hexagon as
## well as for today's squares, while moving it to 117 would take a metre of clearance off every shipped map -- a
## change to maps the lead has played, bought in exchange for nothing. It is a FALLBACK square bound that is
## conservative for every shape; the real answer to "is this point inside the arena" is `Arena.contains()`, and each
## remaining `clampf(..., DRIVABLE_LIMIT)` is a site still to migrate (M4 in _agents/workstreams.md).
const DRIVABLE_LIMIT := 116.0
const BASE_Z := 90.0
## Spawn grid. Slot 0 is the middle of the front row, then out to the flanks, then the rows behind it,
## SPAWN_ROW_SPACING apart toward the team's own wall.
##
## WHAT THIS GRID HAS TO HOLD, and it is less than it looks (combat, round 8; re-measured by scale in round 9 and
## now guarded by `tests/test_spawn_grid.gd` rather than believed): **only what is placed ON it and left there,
## which is `Units.DEFAULT`.** `Match.spawn_tank` defaults to it and its callers are network players and legacy
## bots. A doctrine army never stands here -- `load_doctrine` ends with `ArmyLayout.deploy()`, which re-lays every
## unit by its own hull size at tick 0, synchronously, before any physics step. So the grid is sized for the
## bare-spawn unit plus clearance, and the real ceiling on vehicle size is the spacing an army STANDS at
## (tests/test_army_footprint.gd), not this.
##
## ROUND 9 (scale, S1): `Units.DEFAULT` went from 3.6 m to 8.62 m, which is longer than the old 8 m rows. Rather
## than push the grid deeper -- there is nowhere to go, the back row was already at z = 114 against a DRIVABLE_LIMIT
## of 116 -- it became SHALLOWER AND WIDER: 3 rows 12 m apart (z = 90, 102, 114: the same extent as before, so
## spawn distance and pace are unchanged) and 19 columns 7.5 m apart reaching +-67.5 m. 57 slots, comfortably over
## Army.MAX_ARMY_UNITS (45).
##
## WHY +-67.5 AND NOT WIDER, since the spawn zone every layout authors is 150 m across: `make arenas` refused
## +-72 m. The Terminus has an ad screen at x = 76, z = 100, and a column at 72 stood 1.3 m from its footprint
## against a required 4.3. The authoring check found it, which is the second time this round that a guard has
## earned its place by saying no.
##
## THE ARENA LAYOUTS' SPAWN LISTS ARE BAKED AND THEY WIN: `Match.spawn_position` consults `Arena.spawn_spot` first
## and only falls back to these constants. `tools/make_arenas.py` used to carry its own copy of this table behind a
## comment saying "must mirror"; it now READS these three constants (Invariant 0), so `make arenas` cannot
## regenerate a grid that disagrees with them.
const SLOT_X := [0.0, -7.5, 7.5, -15.0, 15.0, -22.5, 22.5, -30.0, 30.0, -37.5, 37.5, -45.0, 45.0,
		-52.5, 52.5, -60.0, 60.0, -67.5, 67.5]
const SPAWN_ROWS := 3
const SPAWN_ROW_SPACING := 12.0
const SPAWN_SLOTS := 57
## Round 9: how far above the floor a spawn point sits. **It is 0.0, and the reason it exists at all is narrower than
## the reason it was introduced** -- that history is worth one paragraph, because the original rationale is written as
## fact in commit `0682a366` and is wrong.
##
## It was ruled at 0.05 m to cure what looked like a degenerate ground contact: three units in a full faction army
## were found 1.5 m BELOW the floor, and the story was that a body created at exactly y = 0.0 gives the solver a
## contact with zero penetration and no reliable normal. **That story is dead.** Measured frame by frame: the units
## are at -1.475 after one physics frame, **-0.190 after two, -0.042 after three**, and their collider boxes are
## exact. It is `move_and_slide`'s depenetration recovering normally over about three frames; the test was reading
## the worst instant of a settle and calling it a spawn position. Lifting changed the recovery's first frame by
## 0.032 m and nothing else -- the same three units were below the floor at 0.05 AND at 0.0, same workload.
##
## **WHAT SURVIVES, and it is the whole justification for the constant: a spawn point has TWO sources** -- this grid
## and a layout's own `spawns` list via `Arena.spawn_spot` -- **and they must not drift apart.** Both read this, in
## `spawn_position`, which is the only place either can be changed. That is worth a named constant even at zero.
##
## If it is ever set non-zero, check who writes y LAST before believing it reaches anything: `Match._jittered` adds
## 0.0 on y, but squad's `ArmyLayout.deploy` writes the full placement, so a doctrine army takes the layout's y and
## not this one. Two streams implemented the same ruling in two places in round 9 and only one could have an effect.
const SPAWN_LIFT_M := 0.0
## Spawn jitter never moves a unit more than this sideways or along z. THE RULE (re-derive it, do not type it, when a
## hull or the grid changes): `pitch - 2 x jitter - hull >= TacticsFormation.HULL_CLEAR_M (2.0)` for the bare-spawn
## unit `Units.DEFAULT` on each axis, so jitter = (pitch - hull - 2.0) / 2 -- tests/test_spawn_grid.gd asserts it.
## Round 10, CP3 (feel, with the orchestrator's approval; combat's constants, combat reviews at merge): the bus grew
## to 2.90 x 9.70 m (R6), so X = (7.5 - 2.90 - 2.0) / 2 = 1.30 and Z = (12.0 - 9.70 - 2.0) / 2 = 0.15 (they were 1.5 /
## 0.6 for the 2.40 x 8.62 bus). Arena.SPAWN_CLEARANCE reads X, so it shrinks by 0.2 m with it, which only loosens
## arena's authoring checks. A doctrine army's scatter is unaffected: ArmyLayout lays it out by hull size at tick 0.
const SPAWN_JITTER_MAX_X := 1.30
const SPAWN_JITTER_MAX_Z := 0.15

## Experiment switch (`--swap-bases`): Green starts north, Rust south. A fairness probe.
static var swap_bases := false

## X5: the "idle guns" readout (gun_ready_samples / gun_idle_samples) costs a line-of-sight raycast for every
## viewer-enemy pair in weapon range, which is the same order of work as team vision itself and buys nothing the
## simulation needs. Sampled this many INTEL passes apart instead of every one; the ratio it reports is unchanged.
const GUN_READY_EVERY_INTELS := 10
## Shared team vision: refreshed this often, remembered this long. How far each tank sees is its own
## Tank.sight_radius (G1); SENSOR_RANGE is the standard tank's, kept for callers that need a default.
const INTEL_EVERY_TICKS := SimClock.TICK_RATE / 10
const SENSOR_RANGE: float = Units.PROFILES["tank"]["sight_radius"]
const CONTACT_MEMORY_TICKS := SimClock.TICK_RATE * 12

@export var respawn_seconds := 4.0
## Squad vs squad: destroyed tanks stay destroyed, and the match ends when one team has
## no tanks left. Skirmish and `--elimination` matches use it; the network server and
## `make run` keep respawns.
@export var elimination := false
## Stretch (anti-snowball): a control point at the arena center. Any number of one team's tanks
## alone in the zone capture it in CONTROL_CAPTURE_SECONDS (a flat rate: a bigger army doesn't capture
## faster, so a losing side can still steal it); the holder scores a point per second; the first to
## CONTROL_POINTS_TO_WIN wins (elimination still wins too). Off unless a mode turns it on (--control).
@export var control_point := false
const CONTROL_CENTER := Vector3.ZERO
const CONTROL_RADIUS := 16.0
## X5: how long a designator's paint lasts before it must be refreshed (one intel pass is 0.1 s, so this is a
## generous hold that still fades when the designator dies or looks away).
const DESIGNATE_SECONDS := 1.5
const CONTROL_CAPTURE_SECONDS := 8.0
const CONTROL_POINTS_TO_WIN := 90
## N7 (round 6): the objectives this match is fought over, read from the layout rather than hard-coded.
## Each entry is {name, position: Vector3, radius: float, owner: int (-1 neutral), progress: float (-1..1)}.
## `Arena.objectives_of` reports **exactly the single central zone this file used to hard-code** for any layout
## without an `objectives` list, so every shipped arena behaves identically. Off-centre objectives come in mirrored
## pairs (arena's validator enforces it), which is what keeps the fairness invariant.
##
## Why it matters, from the CP4 series: the gates (sight, acquisition) moved kill distance -11 m and off-axis kills
## +17 points where the bands moved them -3 m and +2 -- and a SINGLE CENTRAL objective is the terrain-level version
## of the same problem, because it collapses the space in which acquisition and flanking can matter at all. The 45%
## off-axis kills were measured *despite* one central control point on every map.
var objectives: Array = []
## -1 = neutral, else the team that holds it. **The PRIMARY objective's** (index 0), so every pre-N7 consumer --
## the radar, the tactical map, the announcer, the CPU commander, the agent bridge -- keeps reading what it always
## read. With one objective, which is every shipped layout today, it is the whole story.
## N7 makes the objective the single source of truth and these a view onto it, rather than a copy the tick has to
## remember to write back. A copy is what broke test_control_point when N7 landed: it poked `control_owner` between
## frames, the tick overwrote it from the objective, and the match silently never ended. Writing through means every
## pre-N7 reader AND every pre-N7 writer keeps working unchanged.
var control_owner: int:
	get:
		return int(objectives[0]["owner"]) if not objectives.is_empty() else -1
	set(value):
		if not objectives.is_empty():
			objectives[0]["owner"] = value
## -1 (Rust has it) .. 0 (neutral) .. 1 (Green has it). The primary objective's, as above.
var control_progress: float:
	get:
		return float(objectives[0]["progress"]) if not objectives.is_empty() else 0.0
	set(value):
		if not objectives.is_empty():
			objectives[0]["progress"] = value
## Whole points (seconds held) per team, summed over every objective.
var control_score := [0, 0]
## Fractional ticks: with N objectives a team banks INTEL_EVERY_TICKS x (held / N), so holding them all scores at
## exactly the old rate and holding half scores at half. **At N=1 this reduces to the old integer accumulation**,
## which is what makes N7 a read-through rather than a balance change wearing one's clothes.
var _control_ticks := [0.0, 0.0]

## Firing while moving at full speed multiplies shot spread by (1 + this).
const MOVING_SPREAD_FACTOR := 1.5
## X1 (round 5): at a weapon's full range its spread is (1 + this) times what it is inside effective_range.
const RANGE_SPREAD_FACTOR := 3.0
## L2 (round 4, contract L2): suppression and effective fire. Every round that resolves stamps the ground it swept
## into the enemy team's ThreatField; units standing in that fire get suppressed, which costs them accuracy and
## turret tracking, and above Tank.PINNED_SUPPRESSION counts as pinned. The field is what the brains and the
## battle drills read (threat_field / is_beaten_zone), so "don't walk into a wall of bullets" becomes a query
## instead of a guess. Deliberate simplification: only the ENEMY's rounds suppress, so a team is never scared off
## its own base of fire (friendly-fire DAMAGE is still real).
## Fire density that counts as fully suppressing. Sized so one machine gun holds a lane at about half suppression
## and a second crew on the same lane pins it (see Weapons "suppression").
const SUPPRESSION_FULL_DENSITY := 3.0
## Suppression is re-sampled (and the fields decay) every this many ticks: 20 Hz is far finer than a crew's
## reaction and keeps the grid work off most ticks.
const SUPPRESSION_SAMPLE_TICKS := maxi(1, (SimClock.TICK_RATE + 10) / 20)  # ~20 Hz, rounded to whole ticks
## Being fully suppressed multiplies shot spread by (1 + this). A pinned tank's 0.8 deg becomes 2.4 deg: it still
## shoots, it just stops hitting anything far away, which is what "effective fire" means.
const SUPPRESSION_SPREAD_FACTOR := 2.0
## Fire density at which a patch of ground counts as a beaten zone (is_beaten_zone). One machine gun streaming down
## a lane settles at about 1.4 (1.0 suppression per second against a 1 s half-life), so a single crew IS enough to
## make a lane a bad idea — which is the lead's "cut off an avenue". Getting PINNED there takes three times as much.
const BEATEN_ZONE_DENSITY := 1.0
## L2: suppression a single hit adds per fraction of the victim's hull it takes off (shield included). 1.0 means a
## round that costs you half your hull leaves you half-suppressed; a tank shell pins, a machine-gun round doesn't.
const SUPPRESSION_PER_HULL_FRACTION := 1.0
## G6 repair: hull points per second for tanks inside their base zone that haven't been hit for
## Tank.shield_recharge_delay. The hull is the lasting cost of a fight; mending it means going home.
const REPAIR_HP_PER_SECOND := 6.0
## L3: crews only get out and mend a hull once nothing has hit it for this long. It used to piggyback on the
## shield's recharge delay, which is 0 for a faction with no shields at all (the road gangs) — so a gang truck
## mended itself while it was being shot. The longer of the two applies.
const REPAIR_QUIET_SECONDS := 3.0
## G7 resupply: tanks within this distance of their own base center regain one shell every
## RESUPPLY_SECONDS_PER_SHELL. A full reload (45 shells) takes 45 s at base.
const RESUPPLY_RADIUS := 30.0
const RESUPPLY_SECONDS_PER_SHELL := 1.0
## World (layer 1) + tanks (layer 2): what beams and shells hit.
const HIT_MASK := 3

## Replicated by ScoreSync.
@export var score_green := 0
@export var score_rust := 0

## True on the server/offline (rules run here); false on networked clients.
var simulate := true
## True when this process has networked peers (adds NetworkInput to player tanks).
var networked := false
## False on a dedicated server (nobody sits at this machine).
var has_local_player := true
## Meters of random offset applied to spawn points (0 = exact slots). Used by the
## match runner so repeated seeded matches don't replay identically.
var spawn_jitter := 0.0

## Counters for match results and experiments, indexed by team where it's a pair.
var stats := {"shots": [0, 0], "hits": [0, 0], "damage": [0, 0], "flame_damage": [0, 0], "laser_damage": [0, 0], "mortar_damage": [0, 0], "shield_damage": [0.0, 0.0],
		"kills": [0, 0], "shells_resupplied": [0, 0],
		# R4 friendly fire, by the SHOOTER's team: hull + shield points dealt to teammates, hits, and teammates destroyed.
		"friendly_damage": [0.0, 0.0], "friendly_hits": [0, 0], "friendly_kills": [0, 0],
		# Stretch hazards, by the VICTIM's team: hull + shield points lost to the arena, and units it destroyed.
		"hazard_damage": [0.0, 0.0], "hazard_kills": [0, 0],
		"hits_by_face": {"front": 0, "side": 0, "rear": 0},
		# X3: enemy hits on the engine deck (Armor.is_weak_spot), by the shooter's team.
		"weak_spot_hits": [0, 0],
		# X5 POSITIVE CONTROL, per team: how many units with the `designates` capability were fielded, and how many
		# times one of them actually painted a contact. A treatment arm with no treatment is not a null result, it is
		# a failed run -- and this project has now produced two designator numbers that measured a different game
		# (the unit silently dropped from every army; then fielded but front-lined). Neither was caught by a check.
		# `designators_fielded > 0 and designations == 0` is the assertion a reader can make without knowing a roster.
		"designators_fielded": [0, 0], "designations": [0, 0],
		# L2 (round 4), by the SUPPRESSED team, sampled every SUPPRESSION_SAMPLE_TICKS over living units: how many
		# samples were taken, their suppression summed, and how many were pinned. Without these, nobody can tell
		# whether a match had any suppressive fire in it at all (X2: the answer was "almost none", because brains
		# don't suppress on purpose yet).
		"suppression_samples": [0, 0], "suppression_total": [0.0, 0.0], "pinned_samples": [0, 0],
		# Sampled every INTEL_EVERY_TICKS: a loaded weapon with an enemy in the tank's OWN sight and range...
		"gun_ready_samples": [0, 0],
		# Simulated seconds at the first shot fired and the first kill (pace of a fight).
		"first_shot_seconds": -1.0, "first_kill_seconds": -1.0,
		# ...and of those, how often it was NOT firing (turret still turning, or holding fire).
		"gun_idle_samples": [0, 0],
		# Sampled every INTEL_EVERY_TICKS: what living brain tanks are doing, {option: samples} per team.
		"options": [{}, {}]}
## C3: the match's budget (modes set it from --budget) and each team's army cost (load_doctrine adds it up).
var budget := Units.DEFAULT_BUDGET
var army_cost := [0, 0]
## C3: destroyed units by team, and by unit type: kills_by_unit[team] = {unit_id: enemies of that type destroyed},
## losses_by_unit[team] = {unit_id: own units of that type destroyed (friendly fire included)}.
var units_lost := [0, 0]
var kills_by_unit: Array[Dictionary] = [{}, {}]
var losses_by_unit: Array[Dictionary] = [{}, {}]
var sim_seconds := 0.0
## Physics ticks since the match began: THE clock for deterministic decisions.
var tick := 0
## Per team: what that team knows about enemy tanks (TEAM VISION: if one tank
## sees an enemy, every teammate knows). {enemy name: {position, velocity, forward,
## turret_forward, health, weapon, visible, seen_tick}}. Simulating peer only.
var intel: Array[Dictionary] = [{}, {}]
## L2: incoming-fire density per team (index = the team being shot AT). Built on first use, because the arena's
## half size comes from the layout and the Match can enter the tree before it.
var _threat: Array[ThreatField] = []
## Tank name → squad name, for brain tanks.
var _squad_by_tank := {}
## "team/squad name" → Squad (runtime squad state; tactical map commands land here).
var squads := {}
var _next_brain_index := 0
## Round 5 X1: the shape of the fight (EngagementStats), built on first use from the arena that is loaded. Read-only:
## it never touches the RNG or a unit. `_near_cover` caches each living unit's "by cover" flag from the last sample.
var _engagement: EngagementStats = null
var _near_cover := {}
var _shots_since_sample := 0
## N5 (round 6): the DIRECT-fire subset of them. The envelope governs direct fire only — artillery is deliberately
## outside it — so an all-shots engagement distance describes the battery as much as the fight (lesson 49).
var _direct_shots_since_sample := 0
## X5: the fielded-designator census is taken once, on the first paint pass after spawning.
var _counted_designators := false

var _rng := RandomNumberGenerator.new()
## Shot spread. Seeded with the match seed, so seeded matches stay deterministic.
var _fire_rng := RandomNumberGenerator.new()
var _score_limit := 0
var _time_limit := 0.0
var _finished := false

## Every round fired gets the next id (shells are named Shell_<id>); K2 events carry it.
var _next_shell_id := 0
## K1 (control's Orders, one per match): the player's and the CPU's unit orders. Modes attach it
## (Orders.attach(match, orders)); null in modes that don't use unit orders.
var orders: Orders = null
var _next_bot_id := 1

@onready var tanks: Node3D = $Tanks
@onready var shells: Node3D = $Shells
@onready var effects: Node3D = $Effects
@onready var brains: Node = $Brains
@onready var tank_spawner: MultiplayerSpawner = $TankSpawner
@onready var shell_spawner: MultiplayerSpawner = $ShellSpawner


func _ready() -> void:
	# Must be assigned on every peer before the server's first spawn message arrives.
	tank_spawner.spawn_function = _build_tank
	shell_spawner.spawn_function = _build_shell
	# N7: read the layout's objectives. Arena.active is set by the arena scene, which enters the tree first; a layout
	# with no `objectives` list yields exactly the single central zone this file used to hard-code.
	load_objectives()


func _physics_process(delta: float) -> void:
	if not simulate:
		return
	var started := _profile_start()
	sim_seconds += delta
	tick += 1
	if tick % SUPPRESSION_SAMPLE_TICKS == 0:
		var t := _profile_start()
		_update_suppression()
		_profile("match/suppression", t)
	if tick % INTEL_EVERY_TICKS == 0:
		var t := _profile_start()
		_update_intel()
		_profile("match/intel", t)
		t = _profile_start()
		_update_squads()
		_profile("match/squads", t)
		t = _profile_start()
		_resupply()
		_apply_hazards()
		_paint_designated()
		_sample_brain_options()
		if control_point and not _finished:
			_update_control()
		_profile("match/resupply_hazards_options_control", t)
	if tick % EngagementStats.SAMPLE_TICKS == 0:
		var t := _profile_start()
		_sample_engagement()
		_profile("match/engagement", t)
	var t_rounds := _profile_start()
	_land_rounds()
	_profile("match/land_rounds", t_rounds)
	_profile("match", started)
	_check_finished()


## SimProfile hooks: free when profiling is off (one static read).
static func _profile_start() -> int:
	return Time.get_ticks_usec() if SimProfile.enabled else 0


static func _profile(section: String, started: int) -> void:
	if started > 0:
		SimProfile.add(section, started)


func _check_finished() -> void:
	if _finished or (_score_limit <= 0 and _time_limit <= 0.0 and not elimination and not control_point):
		return
	var reason := ""
	if control_point and maxi(control_score[0], control_score[1]) >= CONTROL_POINTS_TO_WIN:
		reason = "control"
	elif elimination and (alive_count(Team.GREEN) == 0 or alive_count(Team.RUST) == 0) \
			and not team_tanks(Team.GREEN).is_empty() and not team_tanks(Team.RUST).is_empty():
		reason = "elimination"
	elif _score_limit > 0 and maxi(score_green, score_rust) >= _score_limit:
		reason = "score_limit"
	elif _time_limit > 0.0 and sim_seconds >= _time_limit:
		reason = "time_limit"
	if reason != "":
		_finished = true
		finished.emit(result(reason))


## End the match (emit `finished`) at `score_limit` kills or `time_limit` simulated seconds (0 = none).
func start_limits(score_limit: int, time_limit: float) -> void:
	_score_limit = score_limit
	_time_limit = time_limit


func seed_spawns(seed_value: int, jitter: float) -> void:
	_rng.seed = seed_value
	_fire_rng.seed = seed_value + 7919
	spawn_jitter = jitter


func result(reason: String) -> Dictionary:
	var winner := "draw"
	if reason == "control" or (control_point and reason == "time_limit" and control_score[0] != control_score[1]):
		winner = TEAM_NAMES[Team.GREEN] if control_score[0] > control_score[1] else TEAM_NAMES[Team.RUST]
	elif elimination:
		# Last team with tanks wins; on a time limit, more tanks alive, then more total health.
		var standing := [_team_standing(Team.GREEN), _team_standing(Team.RUST)]
		if standing[0] != standing[1]:
			winner = TEAM_NAMES[Team.GREEN] if standing[0] > standing[1] else TEAM_NAMES[Team.RUST]
	elif score_green != score_rust:
		winner = TEAM_NAMES[Team.GREEN] if score_green > score_rust else TEAM_NAMES[Team.RUST]
	var units_left := {"green": alive_count(Team.GREEN), "rust": alive_count(Team.RUST)}
	return {"winner": winner, "reason": reason, "state_hash": state_hash(), "tick": tick,
			# C3 (progression): what each side lost and kept, what it destroyed, how long, and at what budget.
			"units_lost": {"green": units_lost[Team.GREEN], "rust": units_lost[Team.RUST]}, "units_left": units_left,
			"kills_by_unit": {"green": kills_by_unit[Team.GREEN].duplicate(), "rust": kills_by_unit[Team.RUST].duplicate()},
			"losses_by_unit": {"green": losses_by_unit[Team.GREEN].duplicate(), "rust": losses_by_unit[Team.RUST].duplicate()},
			"duration_seconds": snappedf(sim_seconds, 0.1), "budget": budget,
			"army_cost": {"green": army_cost[Team.GREEN], "rust": army_cost[Team.RUST]},
			"score": {"green": score_green, "rust": score_rust},
			"control": {"green": control_score[0], "rust": control_score[1]} if control_point else null,
			"sim_seconds": snappedf(sim_seconds, 0.1), "tanks": {"green": team_tanks(Team.GREEN).size(),
			"rust": team_tanks(Team.RUST).size()}, "stats": _stats_with_engagement()}


func _stats_with_engagement() -> Dictionary:
	var copy := stats.duplicate(true)
	copy["engagement"] = engagement().summary()
	return copy


## Round 5 X1: the fight's shape so far (see EngagementStats).
func engagement() -> EngagementStats:
	if _engagement == null:
		_engagement = EngagementStats.new(EngagementStats.features_of(Arena.active))
	return _engagement


func _sample_engagement() -> void:
	var stats_now := engagement()
	var teams: Array = [[], []]
	_near_cover.clear()
	for tank in _sorted_tanks():
		if not tank.is_alive():
			continue
		var by_cover := stats_now.near_cover(tank.global_position)
		_near_cover[tank.name] = by_cover
		teams[tank.team].append({"position": tank.global_position, "speed": tank.speed(), "near_cover": by_cover})
	stats_now.sample(teams, _shots_since_sample, _direct_shots_since_sample)
	_shots_since_sample = 0
	_direct_shots_since_sample = 0


# ---- Joining and leaving (simulating peer only) ---------------------------------------

func add_player(peer_id: int) -> Tank:
	return spawn_tank("Tank_%d" % peer_id, peer_id)


func remove_player(peer_id: int) -> void:
	var tank := tanks.get_node_or_null("Tank_%d" % peer_id)
	if tank != null:
		tank.queue_free()  # the spawner removes it on every client too
		_sorted_cache_tick = -1  # a tank leaving mid-tick must not linger in this tick's cached list


## A server-controlled tank with a BotController brain (team -1 = the smaller team).
func add_bot(team: int = -1) -> Tank:
	var tank := spawn_tank("Bot_%d" % _next_bot_id, 0, team)
	_next_bot_id += 1
	var brain := BotController.new()
	brain.name = "Brain_" + tank.name
	brain.tank = tank
	brain.tanks_root = tanks
	brains.add_child(brain)
	return tank


## Spawn a unit of type `unit_id` (Units.PROFILES) on `team` (-1 = whichever team is smaller) at its
## team's next free slot. `paint` ("#rrggbb" or "") is cosmetic.
func spawn_tank(tank_name: String, owner_peer_id: int, team: int = -1, unit_id: String = Units.DEFAULT,
		paint: String = "") -> Tank:
	if team < 0:
		team = _smaller_team()
	var slot := _free_slot(team)
	return tank_spawner.spawn({"name": tank_name, "owner": owner_peer_id, "team": team, "slot": slot,
			"position": _jittered(spawn_position(team, slot)), "yaw": spawn_yaw(team), "unit": unit_id, "paint": paint})


func _jittered(point: Vector3) -> Vector3:
	if spawn_jitter <= 0.0:
		return point
	# Less jitter along z keeps tanks inside their base area, clear of the cover walls and of the row behind.
	var sideways := minf(spawn_jitter, SPAWN_JITTER_MAX_X)
	var lengthways := minf(spawn_jitter * 0.4, SPAWN_JITTER_MAX_Z)
	return point + Vector3(_rng.randf_range(-sideways, sideways), 0.0,
			_rng.randf_range(-lengthways, lengthways))


## World-space axes for team-relative coordinates: forward points at the enemy base.
static func team_frame(team: int) -> Dictionary:
	var south := (team == Team.GREEN) != swap_bases
	return {"right": Vector3.RIGHT if south else Vector3.LEFT, "forward": Vector3.FORWARD if south else Vector3.BACK}


static func spawn_position(team: int, slot: int) -> Vector3:
	var south := (team == Team.GREEN) != swap_bases
	var from_layout: Variant = Arena.spawn_spot(south, slot)
	if from_layout != null:
		# Lifted here rather than in `Arena.spawn_spot`, so BOTH sources of a spawn point get it from one place.
		return Vector3((from_layout as Vector3).x, SPAWN_LIFT_M, (from_layout as Vector3).z)
	var cell: Vector2i = _SPAWN_CELLS[slot % _SPAWN_CELLS.size()]  # arena's carve-out (round 10): turning-clear cells first
	var x: float = SLOT_X[cell.x]
	var z := BASE_Z + SPAWN_ROW_SPACING * cell.y
	return Vector3(x if south else -x, SPAWN_LIFT_M, z if south else -z)


## Round 10 (arena, item 4; the orchestrator's ruling A, 2026-09-22): THE ORDER THE GRID FILLS IN, so the first bare
## spawns have room to TURN. [column index into SLOT_X, row] per slot.
##
## THE TURNING ENVELOPE: a hull's first turn sweeps the disc of its half-diagonal, and squad measured that two hulls
## turning together sweep the full diagonal at once (tests/test_tactics_pitch.gd), so two neighbours are
## turning-clear when their centres are at least diagonal + 0.30 m apart at the WORST jitter:
##   the bus (`Units.DEFAULT`, 2.90 x 9.70 m): 10.12 + 0.30 = 10.42 m, i.e. an across pitch of 10.42 + 2 x 1.30
##     (SPAWN_JITTER_MAX_X) = 13.02 m, and a row pitch of 10.42 + 2 x 0.15 = 10.72 m (the rows' 12 m already clear);
##   the War Rig (3.32 x 14.00 m): 14.39 + 0.30 + 2.60 = 17.29 m across.
## WHY 57 TURNING-CLEAR SLOTS CANNOT FIT: the zone is 3 rows deep (z = 90..114: DRIVABLE_LIMIT and the hexagon) and
## +-67.5 m wide (the Terminus screens, see SLOT_X), which holds 11 bus columns a row at 13.02 m (33) or 28 on a
## stagger, and about 14 rigs. SPAWN_SLOTS is also every army's unit cap (Doctrine.MAX_UNITS), so it cannot shrink.
## SO THE SAME 57 LATTICE POINTS FILL IN A DIFFERENT ORDER: first the 28 checkerboard cells (column's lattice index +
## row even: row 0 at x = 0, +-15..+-60; row 1 at +-7.5..+-67.5; row 2 like row 0), whose worst-jitter centres are
## 15 - 2.6 = 12.4 m apart in a row and sqrt(4.9^2 + 11.7^2) = 12.7 m between rows, both clear of the bus's 10.42 m;
## then the other 29. tests/test_arena_spawn_envelope.gd asserts it.
## WHAT IT DOES NOT GIVE: a bare-spawned War Rig has no turning room beyond the first row's alternate cells (it needs
## 17.29 m). And a DOCTRINE army never stands here: `ArmyLayout.deploy()` re-lays it by hull size before any physics
## step (tests/test_spawn_grid.gd). (five_squads never touches this grid either: `test_ai_player_orders._setup` places
## its hulls BY HAND in a 6 m row -- combat's correction at review, round 10.)
static var _SPAWN_CELLS: Array = _spawn_cells()


static func _spawn_cells() -> Array:
	var clear: Array = []
	var rest: Array = []
	var pitch := absf(float(SLOT_X[1]) - float(SLOT_X[0]))
	for row in SPAWN_ROWS:
		for column in SLOT_X.size():
			var lattice := roundi(absf(float(SLOT_X[column])) / pitch)
			(clear if (lattice + row) % 2 == 0 else rest).append(Vector2i(column, row))
	return clear + rest


## How many slots, from slot 0, give every bare spawn room to turn (the checkerboard cells).
static func turning_clear_slots() -> int:
	var pitch := absf(float(SLOT_X[1]) - float(SLOT_X[0]))
	var count := 0
	for row in SPAWN_ROWS:
		for column in SLOT_X.size():
			if (roundi(absf(float(SLOT_X[column])) / pitch) + row) % 2 == 0:
				count += 1
	return count


## Green starts in the south facing north (−Z); Rust in the north facing south.
static func spawn_yaw(team: int) -> float:
	return 0.0 if (team == Team.GREEN) != swap_bases else PI


## A doctrine-driven team (army JSON v2): every unit gets a TankBrain with resolved directives.
## Returns "" or an error.
func load_doctrine(team: int, doctrine: Dictionary) -> String:
	army_cost[team] += Units.army_cost(doctrine)
	for squad in doctrine["squads"]:
		var index := 1
		var roster: PackedStringArray = []
		for entry in squad["units"]:
			var tank_name := "%s_%s_%d" % [TEAM_NAMES[team], squad["name"], index]
			index += 1
			roster.append(tank_name)
			add_brain_tank(team, String(squad["name"]), String(entry["unit"]),
					[squad.get("directive", {}), entry.get("directive", {})], tank_name, String(entry.get("paint", "")))
		var runtime := Squad.new(String(squad["name"]), team, roster)
		runtime.spacing = float(squad.get("spacing", Formations.DEFAULT_SPACING))
		squads[_squad_key(team, runtime.squad_name)] = runtime
		# A doctrine may start a squad in a formation/drill (e.g. the player's squads wait in formation).
		if squad.has("formation") or squad.has("verb"):
			var command := {"squad": runtime.squad_name}
			for key in ["formation", "verb"]:
				if squad.has(key):
					command[key] = squad[key]
			var error := runtime.apply_command(command, tanks_by_name(), spawn_position(team, 0))
			if error != "":
				return "squad %s: %s" % [runtime.squad_name, error]
	# The army starts as an army (round 6, the lead; squad's ArmyLayout): squads side by side in formation, facing the enemy.
	ArmyLayout.deploy(self, team)
	return ""


## Apply a SquadCommand (see squad.gd) from the tactical map, a CPU commander, or a test.
func command_squad(team: int, command: Variant) -> String:
	var error := Squad.validate_command(command)
	if error != "":
		return error
	var squad := squads.get(_squad_key(team, command["squad"])) as Squad
	if squad == null:
		return "no squad %s on %s" % [command["squad"], TEAM_NAMES[team]]
	return squad.apply_command(command, tanks_by_name(), spawn_position(team, 0))


func team_squads(team: int) -> Array[Squad]:
	var result: Array[Squad] = []
	var keys := squads.keys()
	keys.sort()
	for key in keys:
		if (squads[key] as Squad).team == team:
			result.append(squads[key])
	return result


## The runtime Squad a brain tank belongs to, or null.
func squad_for(tank: Tank) -> Squad:
	return squads.get(_squad_key(tank.team, squad_of(tank))) as Squad


func squad_context(tank: Tank) -> Dictionary:
	var squad := squad_for(tank)
	if squad == null:
		return {}
	return squad.context_for(String(tank.name), tanks_by_name())


func tanks_by_name() -> Dictionary:
	var result := {}
	for tank in _sorted_tanks():
		result[String(tank.name)] = tank
	return result


static func _squad_key(team: int, squad_name: String) -> String:
	return "%d/%s" % [team, squad_name]


func _update_squads() -> void:
	var by_name := tanks_by_name()
	var keys := squads.keys()
	keys.sort()
	for key in keys:
		(squads[key] as Squad).update(by_name)


func add_brain_tank(team: int, squad_name: String, unit_id: String, directive_layers: Array,
		tank_name: String, paint: String = "") -> Tank:
	var tank := spawn_tank(tank_name, 0, team, unit_id, paint)
	_squad_by_tank[tank_name] = squad_name
	var brain := TankBrain.new()
	brain.name = "Brain_" + tank_name
	brain.tank = tank
	brain.tanks_root = tanks
	brain.game_match = self
	brain.squad_name = squad_name
	brain.directives = Directives.resolve(directive_layers)
	brain.think_offset = _next_brain_index
	_next_brain_index += 1
	brains.add_child(brain)
	return tank


func squad_of(tank: Tank) -> String:
	return _squad_by_tank.get(String(tank.name), "")


func sorted_team_tanks(team: int) -> Array[Tank]:
	var result: Array[Tank] = []
	for tank in _sorted_tanks():
		if tank.team == team:
			result.append(tank)
	return result


## Base service: shells trickle back (G7) and hulls mend (G6) inside a team's own base, or in the field beside a
## unit that carries a repair crew (L3, the gangs' resupply tanker). Deterministic: sorted units, counted in ticks.
func _resupply() -> void:
	var ticks_per_shell := roundi(RESUPPLY_SECONDS_PER_SHELL * SimClock.TICK_RATE)
	var menders := _field_menders()
	for tank in _sorted_tanks():
		var rate := repair_rate_for(tank, menders)
		if tank.is_alive() and tank.health < tank.max_health and rate > 0.0 \
				and tank.ticks_since_hit >= roundi(maxf(tank.shield_recharge_delay, REPAIR_QUIET_SECONDS) * SimClock.TICK_RATE):
			var ticks_per_hp := maxi(1, roundi(SimClock.TICK_RATE / rate))
			tank.repair_ticks += INTEL_EVERY_TICKS
			if tank.repair_ticks >= ticks_per_hp:
				var hp := tank.repair_ticks / ticks_per_hp
				tank.repair_ticks -= hp * ticks_per_hp
				tank.repair(hp)
		else:
			tank.repair_ticks = 0
		if not tank.is_alive() or tank.ammo < 0 or tank.ammo >= tank.max_ammo:
			tank.resupply_ticks = 0
			continue
		if not in_resupply_zone(tank.team, tank.global_position):
			tank.resupply_ticks = 0
			continue
		tank.resupply_ticks += INTEL_EVERY_TICKS
		if tank.resupply_ticks >= ticks_per_shell:
			tank.resupply_ticks -= ticks_per_shell
			stats["shells_resupplied"][tank.team] += tank.resupply(1)


## L3: living units that mend their neighbours (Units "repair_hp_per_second" / "repair_radius_m"), in sorted order.
func _field_menders() -> Array:
	var menders: Array = []
	for tank in _sorted_tanks():
		var rate := float(Units.stat(tank.unit_id, "repair_hp_per_second", 0.0))
		if tank.is_alive() and rate > 0.0:
			menders.append({"team": tank.team, "position": tank.global_position,
					"radius": float(Units.stat(tank.unit_id, "repair_radius_m", 0.0)), "rate": rate})
	return menders


## L3: hull points per second `tank` mends at right now — REPAIR_HP_PER_SECOND inside its own base, or the best
## rate offered by a friendly repair unit standing near it, whichever is higher. A faction with no shields
## (the road gangs) gets its hit points back this way instead, and the vehicle that does it is easy to kill.
func repair_rate_for(tank: Tank, menders: Array) -> float:
	var rate := REPAIR_HP_PER_SECOND if in_resupply_zone(tank.team, tank.global_position) else 0.0
	for mender: Dictionary in menders:
		if int(mender["team"]) != tank.team:
			continue
		var offset: Vector3 = mender["position"] - tank.global_position
		if Vector2(offset.x, offset.z).length() <= float(mender["radius"]):
			rate = maxf(rate, float(mender["rate"]))
	return rate


static func resupply_center(team: int) -> Vector3:
	return spawn_position(team, 0)


static func in_resupply_zone(team: int, point: Vector3) -> bool:
	var center := resupply_center(team)
	return Vector2(point.x - center.x, point.z - center.z).length() <= RESUPPLY_RADIUS


## Fire burns through shields like the flamethrower and wraps around armor (no strong face).
const HAZARD_SHIELD_MULTIPLIER := 1.5
const HAZARD_ARMOR_MULTIPLIER := 1.0


## Stretch: the arena's hazards (Arena layout "hazards") hurt every living unit inside them, either team, every
## INTEL_EVERY_TICKS. Deterministic: sorted units, tick-counted time.
func _apply_hazards() -> void:
	var hazards := Arena.hazards_of(Arena.active)
	if hazards.is_empty():
		return
	var seconds := float(INTEL_EVERY_TICKS) / SimClock.TICK_RATE
	for tank in _sorted_tanks():
		for hazard: Dictionary in hazards:
			if not tank.is_alive():
				break
			var center: Vector3 = hazard["position"]
			if Vector2(tank.global_position.x - center.x, tank.global_position.z - center.z).length() > float(hazard["radius"]):
				continue
			var hit := tank.take_hit(float(hazard["damage_per_second"]) * seconds, HAZARD_SHIELD_MULTIPLIER, HAZARD_ARMOR_MULTIPLIER)
			stats["hazard_damage"][tank.team] += float(hit["hull"]) + float(hit["shield"])
			if hit["killed"]:
				stats["hazard_kills"][tank.team] += 1
				print("%s burned in a %s" % [tank.name, hazard["type"]])
				_announce_destroyed(tank, "hazard:" + String(hazard["type"]))


## N7: read the layout's objectives. Called at setup; safe to call again (it keeps owners where names match).
func load_objectives() -> void:
	var previous := {}
	for objective: Dictionary in objectives:
		previous[objective["name"]] = objective
	objectives = []
	for spec: Dictionary in Arena.objectives_of(Arena.active):
		var was: Dictionary = previous.get(spec["name"], {})
		objectives.append({"name": spec["name"], "position": spec["position"], "radius": spec["radius"],
				"owner": int(was.get("owner", -1)), "progress": float(was.get("progress", 0.0))})
	if objectives.is_empty():
		# `control_point` is a MATCH flag (--control), not a layout property: before N7 it meant "a zone at the arena
		# centre, radius CONTROL_RADIUS" whatever the layout said. A layout that declares no control_point must still
		# get that zone, or --control would silently do nothing on it.
		objectives.append({"name": "control point", "position": CONTROL_CENTER, "radius": CONTROL_RADIUS,
				"owner": int(previous.get("control point", {}).get("owner", -1)),
				"progress": float(previous.get("control point", {}).get("progress", 0.0))})


## Tanks of each team alive inside `objective`'s zone (the primary one by default, which is what
## `control_presence()` meant before N7).
func objective_presence(objective: Dictionary) -> Array:
	var present := [0, 0]
	var centre: Vector3 = objective["position"]
	var radius := float(objective["radius"])
	for tank in _sorted_tanks():
		if not tank.is_alive():
			continue
		if Vector2(tank.global_position.x - centre.x, tank.global_position.z - centre.z).length() <= radius:
			present[tank.team] += 1
	return present


## Tanks of each team alive inside the primary objective's zone. Unchanged for every pre-N7 caller.
func control_presence() -> Array:
	return objective_presence(objectives[0]) if not objectives.is_empty() else [0, 0]


## True if `point` is inside ANY objective. Prefer this over the static `in_control_zone` once a layout ships
## off-centre objectives: the static one can only know about the default central zone.
func in_any_objective(point: Vector3) -> bool:
	for objective: Dictionary in objectives:
		var centre: Vector3 = objective["position"]
		if Vector2(point.x - centre.x, point.z - centre.z).length() <= float(objective["radius"]):
			return true
	return false


## The DEFAULT central zone, kept because it is static and five streams call it. It cannot see a layout's
## objectives, so it is correct only while every shipped layout uses the central point -- which is true today.
## N7 consumers should use `in_any_objective` / `objective_presence` instead.
static func in_control_zone(point: Vector3) -> bool:
	return Vector2(point.x - CONTROL_CENTER.x, point.z - CONTROL_CENTER.z).length() <= CONTROL_RADIUS


func _update_control() -> void:
	if objectives.is_empty():
		return
	var step := float(INTEL_EVERY_TICKS) / SimClock.TICK_RATE / CONTROL_CAPTURE_SECONDS
	var held := [0, 0]
	for index in objectives.size():
		var objective: Dictionary = objectives[index]
		var present := objective_presence(objective)
		var progress := float(objective["progress"])
		# A zone is taken by whichever side is alone in it: a flat rate, so a bigger army does not capture faster
		# and a losing side can still steal one back.
		if present[Team.GREEN] > 0 and present[Team.RUST] == 0:
			progress = minf(1.0, progress + step)
		elif present[Team.RUST] > 0 and present[Team.GREEN] == 0:
			progress = maxf(-1.0, progress - step)
		var previous := int(objective["owner"])
		var owner := previous
		if progress >= 1.0:
			owner = Team.GREEN
		elif progress <= -1.0:
			owner = Team.RUST
		elif (previous == Team.GREEN and progress <= 0.0) or (previous == Team.RUST and progress >= 0.0):
			owner = -1  # pushed back past neutral
		objective["progress"] = progress
		objective["owner"] = owner
		if owner >= 0:
			held[owner] += 1
		if owner != previous:
			objective_changed.emit(index, owner)
			# The primary objective is what `control_changed` has always meant, and five streams listen to it.
			if index == 0:
				control_changed.emit(owner)
	# Score by the SHARE of objectives held, so holding them all scores at exactly the pre-N7 rate and holding half
	# scores at half. At N = 1 this is the old accumulation exactly.
	var total := float(objectives.size())
	for team in 2:
		if held[team] > 0:
			_control_ticks[team] += float(INTEL_EVERY_TICKS) * float(held[team]) / total
			control_score[team] = int(_control_ticks[team] / SimClock.TICK_RATE)


## X5 (round 6): DESIGNATORS paint. Every intel pass, each living designator marks the nearest enemy its own team can
## see inside its sight radius; while the paint lasts, that contact is acquired in a quarter of the usual time by
## everyone on the designator's side (Engagement.DESIGNATED_ACQUIRE_SCALE).
##
## It paints what its team can see rather than what it personally has a line to, because the unit's job is to turn
## the Syndicate's eyes into everyone's tempo — and because making it require its own line of sight would just make it
## a second scout. It runs on the intel cadence, not per tick, and refreshes a countdown rather than setting a flag,
## so a designator that dies stops helping within DESIGNATE_SECONDS instead of instantly or forever.
func _paint_designated() -> void:
	# Count the fielded designators once, on the first pass after spawning.
	var counting := not _counted_designators
	for tank in _sorted_tanks():
		if not bool(Units.stat(tank.unit_id, "designates", false)):
			continue
		if counting:
			stats["designators_fielded"][tank.team] += 1
		if not tank.is_alive():
			continue
		var best: Tank = null
		var best_distance := tank.sight_radius
		for enemy in sorted_team_tanks(1 - tank.team):
			if not enemy.is_alive() or not is_visible_to(tank.team, enemy):
				continue
			var distance := tank.global_position.distance_to(enemy.global_position)
			if distance <= best_distance:
				best = enemy
				best_distance = distance
		if best != null:
			# Count a paint only when it lands on a contact that was not already painted, so the number is "how often
			# designation did something" rather than "how many ticks a designator was alive".
			if best.designated_seconds <= 0.0:
				stats["designations"][tank.team] += 1
			best.designated_seconds = DESIGNATE_SECONDS
	_counted_designators = true


func _sample_brain_options() -> void:
	for node in brains.get_children():
		var brain := node as TankBrain
		if brain == null or brain.tank == null or not brain.tank.is_alive() or brain.choice.is_empty():
			continue
		var counts: Dictionary = stats["options"][brain.tank.team]
		counts[brain.choice["option"]] = int(counts.get(brain.choice["option"], 0)) + 1


# ---- L2 suppression and effective fire (simulating peer) -----------------------------

## Contract L2: the incoming-fire density `team` is facing — a coarse grid of where the ENEMY's rounds have been
## falling, fading with a ~1 s half-life (ThreatField). Read it to avoid beaten zones, to see whether your own
## suppression is landing, or to drive a support-by-fire drill.
func threat_field(team: int) -> ThreatField:
	if _threat.is_empty():
		var half := float(Arena.active.get("half_size", ARENA_HALF_SIZE))
		_threat = [ThreatField.new(half), ThreatField.new(half)]
	return _threat[team]


## Contract L2: would moving from `from` to `to` take a unit of `team` through a wall of bullets? The straight
## path is sampled against that team's incoming fire; BEATEN_ZONE_DENSITY is about one machine gun's worth.
func is_beaten_zone(team: int, from: Vector3, to: Vector3) -> bool:
	return threat_field(team).peak_along(from, to) >= BEATEN_ZONE_DENSITY


## Contract L2: how exposed a path is for `team` on average (0 = clear), for scoring one route against another.
func threat_along(team: int, from: Vector3, to: Vector3) -> float:
	return threat_field(team).mean_along(from, to)


## L2: the spread (radians, standard deviation) a shot leaves the barrel with. `moving` is speed as a fraction of
## the hull's top speed and `suppression` is the crew's (0..1). Both cost accuracy, and they stack: a tank that
## charges while under fire hits almost nothing.
## X1 (round 5): `distance` (m, 0 = unknown) past the weapon's effective_range widens it too (see Weapons).
static func shot_spread(weapon: Dictionary, moving: float, suppression: float, distance := 0.0) -> float:
	var spread_deg := float(weapon.get("spread_deg", 0.0))
	return deg_to_rad(spread_deg) * (1.0 + MOVING_SPREAD_FACTOR * moving + SUPPRESSION_SPREAD_FACTOR * suppression) \
			* range_spread_multiplier(weapon, distance)


## X1: how much wider a shot at `distance` spreads than one inside the weapon's effective range (1 = no change).
static func range_spread_multiplier(weapon: Dictionary, distance: float) -> float:
	var reach := float(weapon.get("range", 0.0))
	var effective := float(weapon.get("effective_range", reach))
	if distance <= effective or reach <= effective:
		return 1.0
	return 1.0 + RANGE_SPREAD_FACTOR * clampf((distance - effective) / (reach - effective), 0.0, 1.0)


## L2: mark the ground a direct-fire round swept, and report the suppression it laid down (0 for a weapon that
## doesn't suppress). Rounds only suppress the side they were fired AT. When the round struck a unit, the lane runs
## to that unit's CENTRE rather than to the point on its hull: a round stops ~2 m short of centre, which with 6 m
## cells could leave the crew that was just hit in an unmarked cell (X2: one machine gun on a tank measured 0.08
## suppression instead of ~0.47 for exactly that reason).
func _suppress_lane(shooter_team: int, from: Vector3, to: Vector3, weapon: Dictionary, victim: Tank = null) -> float:
	var weight := Weapons.suppression(weapon)
	if weight > 0.0:
		threat_field(1 - shooter_team).stamp_segment(from, victim.global_position if victim != null else to, weight)
	return weight


## L2: mark the ground a burst covered (arcs, and the flame cone's reach).
func _suppress_area(shooter_team: int, center: Vector3, radius: float, weight: float) -> float:
	if weight > 0.0:
		threat_field(1 - shooter_team).stamp_burst(center, radius, weight)
	return weight


## L2: fade the fields, then settle every living crew's suppression to the fire falling on it. Deterministic:
## sorted units, time counted in ticks.
func _update_suppression() -> void:
	for team in 2:
		threat_field(team).decay(SUPPRESSION_SAMPLE_TICKS)
	var seconds := float(SUPPRESSION_SAMPLE_TICKS) / SimClock.TICK_RATE
	for tank in _sorted_tanks():
		if not tank.is_alive():
			continue
		var density := threat_field(tank.team).at(tank.global_position)
		tank.settle_suppression(clampf(density / SUPPRESSION_FULL_DENSITY, 0.0, 1.0), seconds)
		stats["suppression_samples"][tank.team] += 1
		stats["suppression_total"][tank.team] += tank.suppression
		if tank.is_pinned():
			stats["pinned_samples"][tank.team] += 1


func _update_intel() -> void:
	for team in 2:
		var known: Dictionary = intel[team]
		for contact in known.values():
			contact["visible"] = false
		var viewers := sorted_team_tanks(team)
		for viewer in (viewers if tick % (INTEL_EVERY_TICKS * GUN_READY_EVERY_INTELS) == 0 else [] as Array[Tank]):
			if not viewer.is_alive() or not viewer.ready_to_fire():
				continue
			for enemy in sorted_team_tanks(1 - team):
				if enemy.is_alive() and viewer.global_position.distance_to(enemy.global_position) <= float(viewer.weapon["range"]) \
						and Perception.has_line_of_sight(viewer, enemy):
					stats["gun_ready_samples"][team] += 1
					if not viewer.command.fire:
						stats["gun_idle_samples"][team] += 1
					break
		for enemy in sorted_team_tanks(1 - team):
			if not enemy.is_alive():
				known.erase(String(enemy.name))
				continue
			for viewer in viewers:
				if not viewer.is_alive():
					continue
				if viewer.global_position.distance_to(enemy.global_position) > viewer.sight_radius:
					continue
				if not Perception.has_line_of_sight(viewer, enemy):
					continue
				known[String(enemy.name)] = {"position": enemy.global_position, "velocity": enemy.estimated_velocity,
						"forward": -enemy.global_basis.z, "turret_forward": enemy.turret_forward(),
						"health": enemy.health, "shield": enemy.sync_shield, "weapon": enemy.weapon_id, "unit": enemy.unit_id,
						# L2: how suppressed a contact is, for brains that pick a target or a moment to flank (ai asked,
						# 2026-09-16). It is what you can see from outside: a crew with its head down.
						"suppression": enemy.suppression, "role": Units.role_of(enemy.unit_id), "visible": true,
						"seen_tick": tick}
				break
		for contact_name in known.keys():
			if tick - int(known[contact_name]["seen_tick"]) > CONTACT_MEMORY_TICKS:
				known.erase(contact_name)


## A fingerprint of the exact simulation state (full float bits of every tank's
## position, heading, turret, and health). Two runs, or two machines, agree only if
## they simulated identically. Basis for determinism checks and future lockstep desync detection.
## G1: whether `team` sees `tank` right now (its own tanks always; enemies only through intel).
## Presentation code (fog of war, radar, map) must ask this instead of reading positions.
func is_visible_to(team: int, tank: Tank) -> bool:
	if tank.team == team:
		return tank.is_alive()
	return tank.is_alive() and bool(intel[team].get(String(tank.name), {}).get("visible", false))


func state_hash() -> String:
	var bytes := PackedByteArray()
	bytes.append_array(var_to_bytes(tick))
	for tank in _sorted_tanks():
		bytes.append_array(var_to_bytes([String(tank.name), tank.global_position, tank.rotation.y,
				tank.turret.rotation.y, tank.health, tank.alive, tank.suppression]))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode().left(16)


## Comparable team strength: tanks alive dominate, total health breaks ties.
func _team_standing(team: int) -> int:
	var health := 0
	for tank in team_tanks(team):
		if tank.is_alive():
			health += tank.health
	return alive_count(team) * 100000 + health


func alive_count(team: int) -> int:
	var count := 0
	for tank in team_tanks(team):
		if tank.is_alive():
			count += 1
	return count


func team_tanks(team: int) -> Array[Tank]:
	var result: Array[Tank] = []
	for node in tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == team and not tank.is_queued_for_deletion():
			result.append(tank)
	return result


func _smaller_team() -> int:
	return Team.RUST if team_tanks(Team.RUST).size() < team_tanks(Team.GREEN).size() else Team.GREEN


func _free_slot(team: int) -> int:
	var used := []
	for tank in team_tanks(team):
		used.append(tank.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


# ---- Spawn functions (EVERY peer, identical data) ----------------------------------

func _build_tank(data: Dictionary) -> Node:
	var tank: Tank = TANK_SCENE.instantiate()
	tank.name = data["name"]
	tank.team = data["team"]
	tank.slot = data["slot"]
	tank.owner_peer_id = data["owner"]
	tank.position = data["position"]
	tank.rotation.y = data["yaw"]
	tank.unit_id = data.get("unit", Units.DEFAULT)
	tank.simulate = simulate
	var is_local: bool = has_local_player and tank.owner_peer_id != 0 \
			and tank.owner_peer_id == multiplayer.get_unique_id()
	tank.display_name = "YOU" if is_local else tank.name
	# Needs its visuals ready. A loadout's paint colors the whole vehicle; the team shows as an accent
	# (the lead, 2026-09-14: friend or foe by accent lights, not hull color).
	tank.set_team_accent.call_deferred(GameTheme.team_color(tank.team))
	var paint: String = data.get("paint", "")
	if paint != "":
		tank.set_paint.call_deferred(Color.html(paint))
	Replication.attach_tank_sync(tank)
	if simulate:
		tank.fired.connect(_on_tank_fired.bind(tank))
		tank.sprayed.connect(_on_tank_sprayed.bind(tank))
		tank.died.connect(_on_tank_died.bind(tank))
	if networked and tank.owner_peer_id != 0:
		var input := NetworkInput.new()
		input.name = "NetworkInput"
		input.tank = tank
		input.owner_peer_id = tank.owner_peer_id
		tank.add_child(input)
	if is_local:
		local_tank_spawned.emit.call_deferred(tank)
	return tank


func _build_shell(data: Dictionary) -> Node:
	var shell: Shell = SHELL_SCENE.instantiate()
	shell.name = "Shell_%d" % data["id"]
	shell.position = data["muzzle"]
	shell.ray_start = data["ray_start"]
	shell.direction = data["direction"]
	shell.team = data["team"]
	shell.shooter_name = data["shooter"]
	shell.max_range = data.get("range", Shell.MAX_RANGE)
	shell.speed = data.get("speed", Shell.SPEED)
	shell.projectile_id = data["id"]
	shell.simulate = simulate
	if simulate:
		var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
		if shooter != null:
			shell.exclude = [shooter.get_rid()]
		shell.hit.connect(_on_shell_hit)
		shell.expired.connect(_on_shell_expired)
	return shell


# ---- Rules (simulating peer only) ----------------------------------------------------

func _on_tank_fired(muzzle: Vector3, direction: Vector3, tank: Tank) -> void:
	var started := _profile_start()
	_fire(muzzle, direction, tank)
	_profile("tank/fire", started)


func _fire(muzzle: Vector3, direction: Vector3, tank: Tank) -> void:
	stats["shots"][tank.team] += 1
	_shots_since_sample += 1
	var indirect: bool = tank.weapon["kind"] == Weapons.Kind.ARC
	if not indirect:
		_direct_shots_since_sample += 1
	engagement().record_shot(bool(_near_cover.get(tank.name, false)), indirect)
	if stats["first_shot_seconds"] < 0.0:
		stats["first_shot_seconds"] = snappedf(sim_seconds, 0.1)
	var moving := clampf(absf(tank.speed()) / tank.max_forward_speed, 0.0, 1.0)
	# L2: a suppressed gunner's rounds go wide (shot_spread), so volume of fire buys accuracy from the other side.
	var spread := shot_spread(tank.weapon, moving, tank.suppression,
			Vector2(tank.aim_point.x - muzzle.x, tank.aim_point.z - muzzle.z).length())
	var actual := direction.rotated(Vector3.UP, _fire_rng.randfn(0.0, spread)) if spread > 0.0 else direction
	var projectile_id := _next_shell_id
	_next_shell_id += 1
	if tank.weapon["kind"] == Weapons.Kind.BEAM:
		_emit_fired(tank, muzzle, actual, projectile_id)
		_fire_beam(tank, muzzle, actual, projectile_id)
		return
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		_lob(tank, muzzle, projectile_id)
		return
	_emit_fired(tank, muzzle, actual, projectile_id)
	shell_spawner.spawn({"id": projectile_id, "muzzle": muzzle, "ray_start": tank.turret.global_position,
			"direction": actual, "team": tank.team, "shooter": String(tank.name),
			"range": float(tank.weapon["range"]) + Shell.RANGE_MARGIN,
			"speed": float(tank.weapon.get("projectile_speed_mps", Shell.SPEED))})


## K2: announce one round leaving `tank`'s gun.
func _emit_fired(tank: Tank, muzzle: Vector3, direction: Vector3, projectile_id: int) -> void:
	var weapon := tank.weapon
	weapon_fired.emit({"tick": tick, "shooter": String(tank.name), "weapon": tank.weapon_id,
			"fire_model": String(weapon.get("fire_model", "shell")), "muzzle": _triple(muzzle), "direction": _triple(direction),
			"projectile_id": projectile_id, "speed_mps": float(weapon.get("projectile_speed_mps", 0.0)),
			"range": float(weapon["range"]),
			# L2: how suppressive this round is (per second for streams and cones), for cues and readouts.
			"suppression_applied": Weapons.suppression(weapon)})


static func _triple(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## K2: announce a round striking something. `hit` is _land_hit_result's dictionary, or empty for a wall.
func _emit_impact(projectile_id: int, position: Vector3, normal: Vector3, victim: Tank, hit: Dictionary,
		suppression_applied := 0.0) -> void:
	var event := {"tick": tick, "projectile_id": projectile_id, "position": _triple(position), "normal": _triple(normal),
			"weak_spot": false, "damage": 0.0, "killed": false, "suppression_applied": suppression_applied}
	if victim != null and not hit.is_empty():
		event["target"] = String(victim.name)
		event["face"] = hit["face"]
		event["weak_spot"] = hit["weak_spot"]
		event["damage"] = float(hit["hull"]) + float(hit["shield"])
		event["killed"] = hit["killed"]
	projectile_impact.emit(event)


## Indirect rounds in the air: [{"from", "to", "land_tick", "team", "shooter", "weapon"}], in firing order.
var _rounds: Array = []


## ARC weapons (artillery): lob a round at the tank's aim point, scattered, clamped to the weapon's
## range window. It lands after its flight time and bursts (see _land_rounds).
func _lob(tank: Tank, muzzle: Vector3, projectile_id: int) -> void:
	var weapon := tank.weapon
	var flat := Vector3(tank.aim_point.x - muzzle.x, 0.0, tank.aim_point.z - muzzle.z)
	var distance := clampf(flat.length(), float(weapon["min_range"]), float(weapon["range"]))
	var direction := flat.normalized() if flat.length() > 0.01 else tank.turret_forward()
	var target := Vector3(muzzle.x, 0.0, muzzle.z) + direction * distance
	var sigma := arc_scatter(weapon, distance, is_point_spotted(tank.team, target))
	target += Vector3(_fire_rng.randfn(0.0, sigma), 0.0, _fire_rng.randfn(0.0, sigma))
	var flight_ticks := maxi(1, roundi(distance / float(weapon["flight_speed"]) * SimClock.TICK_RATE))
	_emit_fired(tank, muzzle, (target - Vector3(muzzle.x, 0.0, muzzle.z)).normalized(), projectile_id)
	_rounds.append({"from": muzzle, "to": target, "fire_tick": tick, "land_tick": tick + flight_ticks, "team": tank.team,
			"shooter": String(tank.name), "weapon": weapon, "weapon_id": tank.weapon_id, "projectile_id": projectile_id})
	show_arc.rpc(muzzle, target, flight_ticks / float(SimClock.TICK_RATE))


## R2 "artillery needs team sight": rounds at a point no teammate sees land BLIND_SCATTER_FACTOR times wider.
const BLIND_SCATTER_FACTOR := 3.0


## Scatter (meters, standard deviation) of an indirect round fired `distance` meters.
static func arc_scatter(weapon: Dictionary, distance: float, spotted: bool) -> float:
	var sigma := float(weapon["scatter"]) + float(weapon["scatter_per_meter"]) * distance
	return sigma if spotted else sigma * BLIND_SCATTER_FACTOR


## Whether some living tank of `team` has `point` (a ground spot) inside its sight radius with a clear view.
func is_point_spotted(team: int, point: Vector3) -> bool:
	for viewer in sorted_team_tanks(team):
		if viewer.is_alive() and Vector2(viewer.global_position.x - point.x, viewer.global_position.z - point.z).length() <= viewer.sight_radius \
				and _clear_view(viewer, point):
			return true
	return false


## No static world geometry between a tank's eyes and a spot at the same height above `point`.
static func _clear_view(viewer: Tank, point: Vector3) -> bool:
	var eye := Vector3.UP * Perception.EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(viewer.global_position + eye, Vector3(point.x, 0.0, point.z) + eye,
			Perception.WORLD_MASK)
	return viewer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _land_rounds() -> void:
	var due: Array = []
	var flying: Array = []
	for flying_round in _rounds:
		(due if int(flying_round["land_tick"]) <= tick else flying).append(flying_round)
	_rounds = flying
	for landing: Dictionary in due:
		var weapon: Dictionary = landing["weapon"]
		var point: Vector3 = landing["to"]
		var radius := float(weapon["splash_radius"])
		var hit_any := false
		var killed_any := false
		var victims: Array = []
		var main_victim: Tank = null
		var main_hit := {}
		for victim in _sorted_tanks():
			if not victim.is_alive():
				continue  # R4: bursts hurt everyone inside, teammates included
			var offset := Vector3(victim.global_position.x - point.x, 0.0, victim.global_position.z - point.z)
			if offset.length() > radius:
				continue
			var falloff := lerpf(1.0, 0.3, offset.length() / radius)
			var from_burst := offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
			var hit := _land_hit_result(victim, float(weapon["damage"]) * falloff, weapon, from_burst, int(landing["team"]),
					String(landing["shooter"]), "mortar_damage", not hit_any)
			killed_any = bool(hit["killed"]) or killed_any
			hit_any = true
			var dealt := float(hit["hull"]) + float(hit["shield"])
			victims.append({"target": String(victim.name), "face": hit["face"], "damage": dealt, "killed": hit["killed"]})
			if main_victim == null or dealt > float(main_hit["hull"]) + float(main_hit["shield"]):
				main_victim = victim
				main_hit = hit
		# L2: a burst suppresses everything inside its splash, which is what makes a battery worth having.
		var suppression := _suppress_area(int(landing["team"]), point, radius, Weapons.suppression(weapon))
		var burst := {"tick": tick, "projectile_id": int(landing.get("projectile_id", -1)), "position": _triple(point),
				"normal": [0.0, 1.0, 0.0], "weak_spot": false, "damage": 0.0, "killed": killed_any, "victims": victims,
				"suppression_applied": suppression}
		if main_victim != null:
			burst["target"] = String(main_victim.name)
			burst["face"] = main_hit["face"]
			for entry: Dictionary in victims:
				burst["damage"] += float(entry["damage"])
		projectile_impact.emit(burst)
		show_impact.rpc(point + Vector3.UP * 0.3, true)


## Beam weapons (G7 laser): an instant ray from the turret center; the first thing it touches takes
## the pulse, teammates included (R4 friendly fire).
func _fire_beam(tank: Tank, muzzle: Vector3, direction: Vector3, projectile_id: int) -> void:
	var weapon := tank.weapon
	var from := tank.turret.global_position
	var to := from + direction * float(weapon["range"])
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, [tank.get_rid()])
	var hit := tank.get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	var victim: Tank = null
	var result := {}
	if not hit.is_empty():
		end = hit.position
		victim = hit.collider as Tank
		if victim != null and victim.is_alive():
			result = _land_hit_result(victim, float(weapon["damage"]), weapon, direction, tank.team, String(tank.name), "laser_damage", true)
		else:
			victim = null
	# L2: hitscan rounds suppress the corridor they crossed, whether or not they hit (the wall of bullets).
	var suppression := _suppress_lane(tank.team, from, end, weapon, victim)
	if not hit.is_empty():
		_emit_impact(projectile_id, hit.position, hit.normal, victim, result, suppression)
	show_beam.rpc(muzzle, end, String(weapon.get("fx", "fx.laser_beam")))


## Cone weapons: every tank inside the cone with line of sight burns this tick, teammates included (R4).
func _on_tank_sprayed(origin: Vector3, direction: Vector3, delta: float, tank: Tank) -> void:
	var started := _profile_start()
	_spray(origin, direction, delta, tank)
	_profile("tank/spray", started)


func _spray(origin: Vector3, direction: Vector3, delta: float, tank: Tank) -> void:
	var weapon := tank.weapon
	if tick % CONE_EVENT_TICKS == 0:
		_emit_fired(tank, origin, direction, _next_shell_id)
		_next_shell_id += 1
		# L2: fire suppresses the ground it washes over, a CONE_EVENT_TICKS slice of its per-second weight.
		var reach := float(weapon["range"])
		_suppress_area(tank.team, origin + direction * reach * 0.5, reach * 0.5,
				Weapons.suppression(weapon) * float(CONE_EVENT_TICKS) / SimClock.TICK_RATE)
	for victim in _sorted_tanks():
		if not victim.is_alive() or victim == tank:
			continue
		if not Weapons.in_cone(origin, direction, victim.global_position, weapon["range"], weapon["cone_deg"]):
			continue
		if not Perception.has_line_of_sight(tank, victim):
			continue
		var attack := Vector3(victim.global_position.x - tank.global_position.x, 0.0,
				victim.global_position.z - tank.global_position.z)
		_land_hit(victim, float(weapon["damage_per_second"]) * delta, weapon, attack, tank.team, String(tank.name),
				"flame_damage", false)


## K2: fire weapons (cones) announce a weapon_fired puff this often while the trigger is held, not every tick.
const CONE_EVENT_TICKS := SimClock.TICK_RATE / 10


## X5 (round 4): the sorted list is rebuilt at most once per tick. It was being sorted from scratch by a GDScript
## lambda on every call — a dozen call sites, several of them per tick — which is O(n log n) of interpreted
## comparisons per call and the single most expensive thing in the simulation at 60 units a side. The cache is
## keyed on the tick AND the child count, so a spawn inside a tick still rebuilds it. A tank freed mid-tick does not
## change the child count until the frame ends, so the one place that frees one (remove_player) invalidates the
## cache by hand.
var _sorted_cache: Array[Tank] = []
var _sorted_cache_tick := -1
var _sorted_cache_children := -1


## Tanks in a stable order (by name): anything that affects decisions or damage
## must iterate deterministically.
func _sorted_tanks() -> Array[Tank]:
	var children := tanks.get_child_count()
	if _sorted_cache_tick == tick and _sorted_cache_children == children:
		return _sorted_cache
	var result: Array[Tank] = []
	for node in tanks.get_children():
		if node is Tank and not node.is_queued_for_deletion():
			result.append(node)
	result.sort_custom(func(a: Tank, b: Tank) -> bool: return String(a.name) < String(b.name))
	_sorted_cache = result
	_sorted_cache_tick = tick
	_sorted_cache_children = children
	return result


## A missed direct-fire round carries on past its aim point: friendlies this far beyond it count as in the line.
const LINE_OF_FIRE_OVERSHOOT := 15.0
## Friendlies within this many standard deviations of a weapon's spread (or a round's scatter) count as at risk.
const LINE_OF_FIRE_SIGMAS := 2.0


## C4 (R4): living teammates of `shooter` that a shot at `aim_point` could hit, nearest first. Pure geometry
## (walls are ignored: a wall in between makes the shot pointless anyway). Direct fire (shells, beams): the
## corridor from the turret toward the aim point, out to LINE_OF_FIRE_OVERSHOOT past it (capped at the weapon's
## range), as wide as a hull plus the weapon's spread at that distance. Arcs: teammates inside the splash radius
## of the landing point, widened by its scatter. Cones: teammates inside the flame cone.
func friendlies_in_line_of_fire(shooter: Tank, aim_point: Vector3) -> Array[Tank]:
	var weapon := shooter.weapon
	var origin := shooter.turret.global_position
	var flat_origin := Vector2(origin.x, origin.z)
	var flat_aim := Vector2(aim_point.x, aim_point.z)
	var to_aim := flat_aim - flat_origin
	var direction := to_aim.normalized() if to_aim.length() > 0.01 else Vector2(shooter.turret_forward().x, shooter.turret_forward().z)
	var at_risk: Array[Tank] = []
	var distances := {}
	for friend in sorted_team_tanks(shooter.team):
		if friend == shooter or not friend.is_alive():
			continue
		var spot := Vector2(friend.global_position.x, friend.global_position.z)
		var size: Array = Units.stat(friend.unit_id, "hull_size")
		# ROUND 9: the hull is an ORIENTED BOX, not a disc. One `Vector2(w, l).length() / 2` used to serve all four
		# tests below, on four different axes. For a War Rig that disc is 7.19 m against a 1.66 m half-width, and the
		# error varies 4.3x abeam to 1.03x end-on -- so the gun declined shots ACROSS a friendly rig, which is the
		# shot a gang pack with a rig in the middle most wants. `Units.hull_reach_along` projects the real box on
		# whichever axis each test needs, and `--tune=match.hull_disc=1` restores the old disc inside it.
		var friend_forward := -friend.global_basis.z
		var risky := false
		match int(weapon["kind"]):
			Weapons.Kind.ARC:
				var distance := clampf(to_aim.length(), float(weapon["min_range"]), float(weapon["range"]))
				var landing := flat_origin + direction * distance
				var sigma := arc_scatter(weapon, distance, true)
				# Toward the landing POINT: the hull's reach along the line from that point to the hull.
				var toward_landing := Vector3(spot.x - landing.x, 0.0, spot.y - landing.y)
				risky = spot.distance_to(landing) <= float(weapon["splash_radius"]) \
						+ Units.hull_reach_along(size, friend_forward, toward_landing, "lof") + LINE_OF_FIRE_SIGMAS * sigma
			Weapons.Kind.CONE:
				var toward_muzzle := friend.global_position - origin
				risky = Weapons.in_cone(origin, Vector3(direction.x, 0.0, direction.y), friend.global_position,
						float(weapon["range"]) + Units.hull_reach_along(size, friend_forward, toward_muzzle, "lof"),
						float(weapon["cone_deg"]))
			_:
				var flat_direction := Vector3(direction.x, 0.0, direction.y)
				var reach := minf(to_aim.length() + LINE_OF_FIRE_OVERSHOOT, float(weapon["range"]) + Shell.RANGE_MARGIN)
				var along := (spot - flat_origin).dot(direction)
				# LONGITUDINAL: could a shot with `reach` left travel far enough to touch this hull at all.
				if along > 0.0 and along <= reach + Units.hull_reach_along(size, friend_forward, flat_direction, "lof"):
					var moving := clampf(absf(shooter.speed()) / maxf(shooter.max_forward_speed, 0.1), 0.0, 1.0)
					var spread := tan(shot_spread(weapon, moving, shooter.suppression) * LINE_OF_FIRE_SIGMAS) * along
					# LATERAL: hull_distance_to_line has already taken the hull's own extent off, so what remains to
					# compare against is the spread alone.
					risky = Units.hull_distance_to_line(size, friend_forward, friend.global_position,
							Vector3(flat_origin.x, 0.0, flat_origin.y), flat_direction, "lof") <= spread
		if risky:
			at_risk.append(friend)
			distances[friend] = spot.distance_to(flat_origin)
	at_risk.sort_custom(func(a: Tank, b: Tank) -> bool: return distances[a] < distances[b])
	return at_risk


## X3 (round 4): a hull counts as screening a unit when it blocks the line from the threat to the unit's turret,
## the height rounds actually fly at (Units "muzzle_height"). Shells and beams already stop at the first hull they
## meet, so this query just *reports* the geometry the physics is already using.
const SCREEN_HEIGHT := 1.27


## X3, contract C4: the friendly hull shielding `unit` from fire coming from `from_point`, or null. This is not a
## buff and grants nothing: heavies shield fragile units because a shell stops at the first hull it hits, and
## `armor_multiplier` then decides what it costs. A dozer eating a cannon shell on its 8 mm front takes x0.5 where
## the Lancer behind it would have taken x1.21 on 3 mm, on top of having half again the hull and shield. Brains and
## drills use this to know whether a unit is covered (or whether a heavy is doing its job) before moving.
## Wrecks never screen: `Tank._set_alive(false)` disables the collision shape.
func screen_for(unit: Tank, from_point: Vector3) -> Tank:
	if unit == null or not unit.is_alive():
		return null
	var eye := Vector3(0.0, SCREEN_HEIGHT, 0.0)
	var target := Vector3(unit.global_position.x, 0.0, unit.global_position.z) + eye
	var query := PhysicsRayQueryParameters3D.create(Vector3(from_point.x, 0.0, from_point.z) + eye, target,
			HIT_MASK, [unit.get_rid()])
	var hit := unit.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var blocker := hit.get("collider") as Tank
	return blocker if blocker != null and blocker.is_alive() and blocker.team == unit.team else null


## A shell passing within this many meters of a hull's edge counts as incoming (K2 dodging).
const INCOMING_MARGIN := 1.0


## K2, for dodging: rounds in flight that will reach `unit` if it holds still, soonest first. Each is {position,
## velocity (m/s), eta_ticks, damage_estimate (shield + hull points at its current shield), projectile_id, weapon}.
## Shells count when their straight path passes within INCOMING_MARGIN of the hull's OWN ORIENTED BOX before they burn
## out; lobbed rounds when they will land within their splash of it. Anyone's rounds but the unit's own (friendly
## fire is real). Walls are ignored: pure geometry (dot and cross products, no engine queries).
func incoming_projectiles(unit: Tank) -> Array:
	var threats: Array = []
	if unit == null or not unit.is_alive():
		return threats
	var here := Vector2(unit.global_position.x, unit.global_position.z)
	var half := Units.hull_half_extents(Units.stat(unit.unit_id, "hull_size"))
	var forward := -unit.global_basis.z
	for node in shells.get_children():
		var shell := node as Shell
		if shell == null or not shell.in_flight() or shell.shooter_name == String(unit.name) or shell.speed <= 0.0:
			continue
		var from := Vector2(shell.global_position.x, shell.global_position.z)
		var direction := Vector2(shell.direction.x, shell.direction.z).normalized()
		var offset := here - from
		var along := offset.dot(direction)
		var flat_direction := Vector3(direction.x, 0.0, direction.y)
		# ROUND 9: the box, not the half-diagonal (see the friendly-fire note above and Units.hull_reach_along).
		if along <= 0.0 or along > shell.remaining_range() + Units.hull_reach_of(half, forward, flat_direction, "incoming"):
			continue
		if Units.hull_distance_of(half, forward, unit.global_position,
				Vector3(from.x, 0.0, from.y), flat_direction, "incoming") > INCOMING_MARGIN:
			continue
		var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
		var weapon := shooter.weapon if shooter != null else Weapons.profile(Weapons.DEFAULT)
		threats.append({"position": shell.global_position, "velocity": shell.direction * shell.speed,
				"eta_ticks": ceili(maxf(0.0, along - Units.hull_reach_of(half, forward, flat_direction, "incoming"))
						/ shell.speed * SimClock.TICK_RATE), "projectile_id": shell.projectile_id,
				"weapon": shooter.weapon_id if shooter != null else Weapons.DEFAULT,
				"damage_estimate": _damage_estimate(unit, float(weapon["damage"]), weapon, shell.direction, false)})
	for flying: Dictionary in _rounds:
		if String(flying["shooter"]) == String(unit.name):
			continue
		var weapon: Dictionary = flying["weapon"]
		var landing: Vector3 = flying["to"]
		var distance := here.distance_to(Vector2(landing.x, landing.z))
		var splash := float(weapon["splash_radius"])
		# Toward the landing POINT: an arcing round comes down somewhere, so the hull's reach is measured along the
		# line from that point to the hull rather than along any travel direction.
		if distance > splash + Units.hull_reach_of(half, forward,
				Vector3(unit.global_position.x - landing.x, 0.0, unit.global_position.z - landing.z), "incoming"):
			continue
		var from: Vector3 = flying["from"]
		var flight := maxi(1, int(flying["land_tick"]) - int(flying["fire_tick"]))
		var fraction := clampf(float(tick - int(flying["fire_tick"])) / flight, 0.0, 1.0)
		var falloff := lerpf(1.0, 0.3, clampf(distance / maxf(splash, 0.01), 0.0, 1.0))
		threats.append({"position": ArcRoundVisual.point_at(from, landing, fraction),
				"velocity": Vector3(landing.x - from.x, 0.0, landing.z - from.z) / SimClock.seconds(flight),
				"eta_ticks": maxi(0, int(flying["land_tick"]) - tick), "projectile_id": int(flying.get("projectile_id", -1)),
				"weapon": String(flying.get("weapon_id", "")),
				"damage_estimate": _damage_estimate(unit, float(weapon["damage"]) * falloff, weapon, forward, true)})
	threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["eta_ticks"]) < int(b["eta_ticks"]) or (int(a["eta_ticks"]) == int(b["eta_ticks"]) and int(a["projectile_id"]) < int(b["projectile_id"])))
	return threats


## Shield + hull points a hit of `raw` travelling along `direction` would take from `unit` now (no state change).
func _damage_estimate(unit: Tank, raw: float, weapon: Dictionary, direction: Vector3, arcing: bool) -> float:
	var face: String = "side" if arcing else Armor.FACING_NAMES[Armor.facing(-unit.global_basis.z, direction)]
	var through_armor := weak_spot_multiplier(weapon, unit.unit_id) if not arcing and is_weak_spot_hit(weapon, -unit.global_basis.z, direction) \
			else armor_multiplier(weapon, unit.unit_id, face)
	var split := Armor.split_shield(raw, unit.shield, float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face]),
			through_armor)
	return split.x + split.y


## The engine-deck diagnostic's row (see `Armor.deck_probe`). Three columns and no verdict:
##   travel_deg   the angle between the victim's hull forward and the shell's travel -- what Armor.is_weak_spot tests
##                (it fires under WEAK_SPOT_ARC_DEG, 25 deg)
##   bearing_deg  where the SHOOTER stands relative to the victim's nose: 180 is dead astern. A shell can arrive
##                inside the cone from a shooter that is not behind (a crossing shot), so the two are not the same
##                question and conflating them is how this lands on the wrong owner.
##   range_m      shooter to victim
func _print_deck_row(victim: Tank, forward: Vector3, direction: Vector3, weak: bool, face: String,
		shooter: String, weapon: Dictionary) -> void:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var travel := Vector3(direction.x, 0.0, direction.z).normalized()
	var shooter_tank := tanks_by_name().get(shooter) as Tank
	var bearing_deg := -1.0
	var range_m := -1.0
	if shooter_tank != null:
		var to_shooter := shooter_tank.global_position - victim.global_position
		range_m = Vector3(to_shooter.x, 0.0, to_shooter.z).length()
		bearing_deg = rad_to_deg(flat_forward.angle_to(Vector3(to_shooter.x, 0.0, to_shooter.z).normalized()))
	print("DECK_HIT " + JSON.stringify({"victim": victim.unit_id, "shooter_unit":
			"" if shooter_tank == null else shooter_tank.unit_id, "weapon": String(weapon.get("id", "")),
			"travel_deg": snappedf(rad_to_deg(flat_forward.angle_to(travel)), 0.1),
			"bearing_deg": snappedf(bearing_deg, 0.1), "range_m": snappedf(range_m, 0.1),
			"face": face, "weak_spot": weak, "arc_deg": Armor.WEAK_SPOT_ARC_DEG}))


## R2: the fraction of a hit's hull damage that gets through `unit_id`'s armor on `face`.
static func armor_multiplier(weapon: Dictionary, unit_id: String, face: String) -> float:
	return Armor.penetration_multiplier(float(weapon.get("penetration", 0.0)), Units.armor(unit_id, face))


## Every weapon's damage lands here (G6): shield first, then hull through the armor facing.
## `direction` is the attack's travel direction. Returns true if it destroyed the victim.
func _land_hit(victim: Tank, raw: float, weapon: Dictionary, direction: Vector3, team: int, shooter: String,
		weapon_stat: String, counts_as_hit: bool) -> bool:
	return _land_hit_result(victim, raw, weapon, direction, team, shooter, weapon_stat, counts_as_hit)["killed"]


## _land_hit, returning {"shield", "hull", "killed", "face", "weak_spot"} for K2 events.
func _land_hit_result(victim: Tank, raw: float, weapon: Dictionary, direction: Vector3, team: int, shooter: String,
		weapon_stat: String, counts_as_hit: bool) -> Dictionary:
	var forward := -victim.global_basis.z
	var face: String = Armor.FACING_NAMES[Armor.facing(forward, direction)]
	if weapon["kind"] == Weapons.Kind.ARC:
		face = "side"  # indirect rounds come down on top: no face is the strong one
	var weak := is_weak_spot_hit(weapon, forward, direction)
	if Armor.deck_probe and victim.team != team:
		_print_deck_row(victim, forward, direction, weak, face, shooter, weapon)
	var through_armor := weak_spot_multiplier(weapon, victim.unit_id) if weak else armor_multiplier(weapon, victim.unit_id, face)
	var result := victim.take_hit(raw, float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face]), through_armor)
	result["face"] = face
	result["weak_spot"] = weak
	# L2: getting HIT HARD rattles a crew beyond the fire density where they sit. Scaled by the fraction of the hull
	# this one round took off, not by the weapon's suppression weight: a machine-gun round that pings the armor is
	# nothing (0.01), while a tank shell that strips half your hull pins you on its own. Weighting it by the weapon
	# instead would double-count volume, which the threat field already measures (X2: one machine gun pinned a tank
	# on hits alone, which made "concentrate your fire" meaningless).
	victim.suppress((float(result["hull"]) + float(result["shield"])) / maxf(float(victim.max_health), 1.0)
			* SUPPRESSION_PER_HULL_FRACTION)
	if weak and victim.team != team and counts_as_hit:
		stats["weak_spot_hits"][team] += 1
	if victim.team == team:
		stats["friendly_damage"][team] += float(result["hull"]) + float(result["shield"])
		stats["friendly_hits"][team] += 1 if counts_as_hit else 0
		if result["killed"]:
			stats["friendly_kills"][team] += 1
			print("%s destroyed teammate %s (friendly fire)" % [shooter, victim.name])
			_announce_destroyed(victim, shooter)
		friendly_fire.emit(victim, shooter, int(result["hull"]), bool(result["killed"]))
		return result
	if counts_as_hit:
		stats["hits"][team] += 1
		stats["hits_by_face"][face] += 1
	stats["damage"][team] += int(result["hull"])
	stats["shield_damage"][team] += float(result["shield"])
	if weapon_stat != "":
		stats[weapon_stat][team] += int(result["hull"])
	if result["killed"]:
		_record_engagement_kill(victim, shooter, face, weapon)
		_score_kill(team, shooter, victim)
	return result


func _record_engagement_kill(victim: Tank, shooter: String, face: String, weapon: Dictionary) -> void:
	var killer := tanks.get_node_or_null(NodePath(shooter)) as Tank
	var stats_now := engagement()
	var distance := killer.global_position.distance_to(victim.global_position) if killer != null else -1.0
	stats_now.record_kill(victim.team, face, weapon["kind"] == Weapons.Kind.ARC, distance,
			killer != null and stats_now.near_cover(killer.global_position), stats_now.near_cover(victim.global_position))
	if killer != null:
		stats_now.record_kill_bearing(victim.team, victim.global_position, killer.global_position)


## X3 weak spots: a direct round (shell or beam; not a lobbed burst or a flame) into the engine deck.
static func is_weak_spot_hit(weapon: Dictionary, hull_forward: Vector3, direction: Vector3) -> bool:
	var kind := int(weapon.get("kind", -1))
	return kind != Weapons.Kind.ARC and kind != Weapons.Kind.CONE and Armor.is_weak_spot(hull_forward, direction)


## X3: the fraction of a hit's hull damage that gets through `unit_id`'s engine deck (thinner than its rear armor).
static func weak_spot_multiplier(weapon: Dictionary, unit_id: String) -> float:
	return Armor.penetration_multiplier(float(weapon.get("penetration", 0.0)),
			Units.armor(unit_id, "rear") * Armor.WEAK_SPOT_ARMOR_FRACTION)


func _score_kill(team: int, killer: String, victim: Tank) -> void:
	stats["kills"][team] += 1
	kills_by_unit[team][victim.unit_id] = int(kills_by_unit[team].get(victim.unit_id, 0)) + 1
	if stats["first_kill_seconds"] < 0.0:
		stats["first_kill_seconds"] = snappedf(sim_seconds, 0.1)
	if team == Team.GREEN:
		score_green += 1
	else:
		score_rust += 1
	print("%s destroyed %s (score Green %d : %d Rust)" % [killer, victim.name, score_green, score_rust])
	_announce_destroyed(victim, killer)


func _on_shell_hit(shell: Shell, collider: Object, point: Vector3) -> void:
	var started := _profile_start()
	_shell_hit(shell, collider, point)
	_profile("shell/hit", started)


func _shell_hit(shell: Shell, collider: Object, point: Vector3) -> void:
	var killed := false
	var victim := collider as Tank
	var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
	var weapon := shooter.weapon if shooter != null else Weapons.profile(Weapons.DEFAULT)
	# L2: the round suppressed everything along the corridor it flew down before it stopped here.
	var suppression := _suppress_lane(shell.team, shell.ray_start, point, weapon,
			victim if victim != null and victim.is_alive() else null)
	if victim != null and victim.is_alive():
		var hit := _land_hit_result(victim, float(weapon["damage"]), weapon, shell.direction, shell.team, shell.shooter_name, "", true)
		killed = hit["killed"]
		_emit_impact(shell.projectile_id, point, shell.hit_normal, victim, hit, suppression)
	else:
		_emit_impact(shell.projectile_id, point, shell.hit_normal, null, {}, suppression)
	show_impact.rpc(point, killed)
	shell.queue_free()


## L2: a round that burned out without hitting anything still swept a lane; mark it, then free the shell.
func _on_shell_expired(shell: Shell) -> void:
	var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
	_suppress_lane(shell.team, shell.ray_start, shell.global_position,
			shooter.weapon if shooter != null else Weapons.profile(Weapons.DEFAULT))
	shell.queue_free()


## Every destruction goes through here: the round-2 signal, then the round-3 event with the wreck's transform.
func _announce_destroyed(victim: Tank, killer: String) -> void:
	tank_destroyed.emit(victim, killer)
	var shooter: Tank = null
	if killer != "" and not killer.begins_with("hazard:"):
		shooter = tanks.get_node_or_null(NodePath(killer)) as Tank
	var cause := "hazard" if killer.begins_with("hazard:") else ("friendly_fire" if shooter != null and shooter.team == victim.team else "enemy")
	var forward := -victim.global_basis.z
	unit_destroyed.emit({"tick": tick, "unit": String(victim.name), "unit_id": victim.unit_id, "team": victim.team,
			"killer": killer, "cause": cause, "position": _triple(victim.global_position),
			"forward": _triple(Vector3(forward.x, 0.0, forward.z).normalized()),
			"hull_size": (Units.stat(victim.unit_id, "hull_size") as Array).duplicate()})


func _on_tank_died(tank: Tank) -> void:
	units_lost[tank.team] += 1
	losses_by_unit[tank.team][tank.unit_id] = int(losses_by_unit[tank.team].get(tank.unit_id, 0)) + 1
	if elimination:
		return  # squad vs squad: destroyed means destroyed
	await get_tree().create_timer(respawn_seconds).timeout
	if is_instance_valid(tank) and not tank.is_queued_for_deletion():
		tank.respawn(_jittered(spawn_position(tank.team, tank.slot)), spawn_yaw(tank.team))


# ---- Effects (every peer with a screen) ----------------------------------------------

## How long a laser pulse's visual lives before it's freed (the visual fades itself).
const BEAM_VISUAL_SECONDS := 0.2


@rpc("authority", "call_local", "unreliable")
func show_arc(from: Vector3, to: Vector3, seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var round_visual := ArcRoundVisual.new()
	round_visual.from = from
	round_visual.to = to
	round_visual.seconds = seconds
	effects.add_child(round_visual)


@rpc("authority", "call_local", "unreliable")
func show_beam(from: Vector3, to: Vector3, fx_slot: String) -> void:
	if DisplayServer.get_name() == "headless" or not GameTheme.slots.has(fx_slot):
		return
	var beam := VisualSlot.new()
	beam.slot = fx_slot
	effects.add_child(beam)
	beam.invoke("setup", [from, to])
	get_tree().create_timer(BEAM_VISUAL_SECONDS).timeout.connect(beam.queue_free)


@rpc("authority", "call_local", "unreliable")
func show_impact(point: Vector3, big: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var impact := Impact.new()
	impact.big = big
	effects.add_child(impact)
	impact.global_position = point
