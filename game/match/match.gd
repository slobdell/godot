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
signal control_changed(owner: int)
## Simulating peer: a tank was destroyed (by `killer`, a tank name).
signal tank_destroyed(victim: Tank, killer: String)
## Simulating peer: `shooter` (a tank name) hurt its own teammate `victim` (R4: friendly fire is on).
signal friendly_fire(victim: Tank, shooter: String, hull: int, killed: bool)

enum Team { GREEN, RUST }

const TEAM_NAMES := ["Green", "Rust"]
const TANK_SCENE := preload("res://game/tank/tank.tscn")
const SHELL_SCENE := preload("res://game/combat/shell.tscn")
const BASE_DAMAGE := 34.0
## Bases sit this far north/south of center; slots spread along x.
## Arena geometry. Obstacles and spawns come from the arena layout (arenas/*.json, Arena); the size is fixed here.
## 2026-09-13: doubled from 60 → 120 after the lead's first skirmish; contact was
## immediate on the small map and formations had no room.
const ARENA_HALF_SIZE := 120.0
## How close to the perimeter tanks and slots may be sent (walls' inner face minus clearance).
const DRIVABLE_LIMIT := 116.0
const BASE_Z := 90.0
## R5 spawn grid: up to 5 squads x 5 units per side. Slot 0..8 fill the front row (center out), then the rows
## behind it, SPAWN_ROW_SPACING apart toward the team's own wall. 12 m columns and 10 m rows keep even a
## jittered 2.6 x 4 m hull clear of its neighbours (SPAWN_JITTER_MAX_X).
const SLOT_X := [0.0, -12.0, 12.0, -24.0, 24.0, -36.0, 36.0, -48.0, 48.0]
const SPAWN_ROWS := 3
const SPAWN_ROW_SPACING := 10.0
const SPAWN_SLOTS := 27
## Spawn jitter never moves a unit more than this sideways (half the column gap minus a hull width).
const SPAWN_JITTER_MAX_X := 4.0

## Experiment switch (`--swap-bases`): Green starts north, Rust south. A fairness probe.
static var swap_bases := false

## Shared team vision: refreshed this often, remembered this long. How far each tank sees is its own
## Tank.sight_radius (G1); SENSOR_RANGE is the standard tank's, kept for callers that need a default.
const INTEL_EVERY_TICKS := 6
const SENSOR_RANGE: float = Units.PROFILES["tank"]["sight_radius"]
const CONTACT_MEMORY_TICKS := 60 * 12

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
const CONTROL_CAPTURE_SECONDS := 8.0
const CONTROL_POINTS_TO_WIN := 90
## -1 = neutral, else the team that holds it.
var control_owner := -1
## -1 (Rust has it) .. 0 (neutral) .. 1 (Green has it).
var control_progress := 0.0
## Whole points (seconds held) per team.
var control_score := [0, 0]
var _control_ticks := [0, 0]

## Firing while moving at full speed multiplies shot spread by (1 + this).
const MOVING_SPREAD_FACTOR := 1.5
## G6 repair: hull points per second for tanks inside their base zone that haven't been hit for
## Tank.shield_recharge_delay. The hull is the lasting cost of a fight; mending it means going home.
const REPAIR_HP_PER_SECOND := 6.0
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
		"hits_by_face": {"front": 0, "side": 0, "rear": 0},
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
## Tank name → squad name, for brain tanks.
var _squad_by_tank := {}
## "team/squad name" → Squad (runtime squad state; tactical map commands land here).
var squads := {}
var _next_brain_index := 0

var _rng := RandomNumberGenerator.new()
## Shot spread. Seeded with the match seed, so seeded matches stay deterministic.
var _fire_rng := RandomNumberGenerator.new()
var _score_limit := 0
var _time_limit := 0.0
var _finished := false

var _next_shell_id := 0
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


func _physics_process(delta: float) -> void:
	if not simulate:
		return
	sim_seconds += delta
	tick += 1
	if tick % INTEL_EVERY_TICKS == 0:
		_update_intel()
		_update_squads()
		_resupply()
		_sample_brain_options()
		if control_point and not _finished:
			_update_control()
	_land_rounds()
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
			"rust": team_tanks(Team.RUST).size()}, "stats": stats.duplicate(true)}


# ---- Joining and leaving (simulating peer only) ---------------------------------------

func add_player(peer_id: int) -> Tank:
	return spawn_tank("Tank_%d" % peer_id, peer_id)


func remove_player(peer_id: int) -> void:
	var tank := tanks.get_node_or_null("Tank_%d" % peer_id)
	if tank != null:
		tank.queue_free()  # the spawner removes it on every client too


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
	# Less jitter along z keeps tanks inside their base area, clear of the cover walls.
	var sideways := minf(spawn_jitter, SPAWN_JITTER_MAX_X)
	return point + Vector3(_rng.randf_range(-sideways, sideways), 0.0,
			_rng.randf_range(-spawn_jitter, spawn_jitter) * 0.4)


## World-space axes for team-relative coordinates: forward points at the enemy base.
static func team_frame(team: int) -> Dictionary:
	var south := (team == Team.GREEN) != swap_bases
	return {"right": Vector3.RIGHT if south else Vector3.LEFT, "forward": Vector3.FORWARD if south else Vector3.BACK}


static func spawn_position(team: int, slot: int) -> Vector3:
	var south := (team == Team.GREEN) != swap_bases
	var from_layout: Variant = Arena.spawn_spot(south, slot)
	if from_layout != null:
		return from_layout
	var x: float = SLOT_X[slot % SLOT_X.size()]
	var z := BASE_Z + SPAWN_ROW_SPACING * ((slot / SLOT_X.size()) % SPAWN_ROWS)
	return Vector3(x if south else -x, 0.0, z if south else -z)


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


## Base service: shells trickle back (G7) and hulls mend (G6) inside a team's own base.
## Deterministic: counted in ticks.
func _resupply() -> void:
	var ticks_per_shell := roundi(RESUPPLY_SECONDS_PER_SHELL * 60.0)
	var ticks_per_hp := roundi(60.0 / REPAIR_HP_PER_SECOND)
	for tank in _sorted_tanks():
		if tank.is_alive() and tank.health < tank.max_health and in_resupply_zone(tank.team, tank.global_position) \
				and tank.ticks_since_hit >= roundi(tank.shield_recharge_delay * 60.0):
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


static func resupply_center(team: int) -> Vector3:
	return spawn_position(team, 0)


static func in_resupply_zone(team: int, point: Vector3) -> bool:
	var center := resupply_center(team)
	return Vector2(point.x - center.x, point.z - center.z).length() <= RESUPPLY_RADIUS


## Tanks of each team alive inside the control zone.
func control_presence() -> Array:
	var present := [0, 0]
	for tank in _sorted_tanks():
		if tank.is_alive() and in_control_zone(tank.global_position):
			present[tank.team] += 1
	return present


static func in_control_zone(point: Vector3) -> bool:
	return Vector2(point.x - CONTROL_CENTER.x, point.z - CONTROL_CENTER.z).length() <= CONTROL_RADIUS


func _update_control() -> void:
	var present := control_presence()
	var step := float(INTEL_EVERY_TICKS) / 60.0 / CONTROL_CAPTURE_SECONDS
	if present[Team.GREEN] > 0 and present[Team.RUST] == 0:
		control_progress = minf(1.0, control_progress + step)
	elif present[Team.RUST] > 0 and present[Team.GREEN] == 0:
		control_progress = maxf(-1.0, control_progress - step)
	var previous := control_owner
	if control_progress >= 1.0:
		control_owner = Team.GREEN
	elif control_progress <= -1.0:
		control_owner = Team.RUST
	elif (control_owner == Team.GREEN and control_progress <= 0.0) or (control_owner == Team.RUST and control_progress >= 0.0):
		control_owner = -1  # pushed back past neutral
	if control_owner != previous:
		control_changed.emit(control_owner)
	if control_owner >= 0:
		_control_ticks[control_owner] += INTEL_EVERY_TICKS
		control_score[control_owner] = _control_ticks[control_owner] / 60


func _sample_brain_options() -> void:
	for node in brains.get_children():
		var brain := node as TankBrain
		if brain == null or brain.tank == null or not brain.tank.is_alive() or brain.choice.is_empty():
			continue
		var counts: Dictionary = stats["options"][brain.tank.team]
		counts[brain.choice["option"]] = int(counts.get(brain.choice["option"], 0)) + 1


func _update_intel() -> void:
	for team in 2:
		var known: Dictionary = intel[team]
		for contact in known.values():
			contact["visible"] = false
		var viewers := sorted_team_tanks(team)
		for viewer in viewers:
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
						"role": Units.role_of(enemy.unit_id), "visible": true, "seen_tick": tick}
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
				tank.turret.rotation.y, tank.health, tank.alive]))
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
	shell.simulate = simulate
	if simulate:
		var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
		if shooter != null:
			shell.exclude = [shooter.get_rid()]
		shell.hit.connect(_on_shell_hit)
		shell.expired.connect(func(expired_shell: Shell) -> void: expired_shell.queue_free())
	return shell


# ---- Rules (simulating peer only) ----------------------------------------------------

func _on_tank_fired(muzzle: Vector3, direction: Vector3, tank: Tank) -> void:
	stats["shots"][tank.team] += 1
	if stats["first_shot_seconds"] < 0.0:
		stats["first_shot_seconds"] = snappedf(sim_seconds, 0.1)
	var moving := clampf(absf(tank.speed()) / tank.max_forward_speed, 0.0, 1.0)
	var spread := deg_to_rad(float(tank.weapon.get("spread_deg", 0.0))) * (1.0 + MOVING_SPREAD_FACTOR * moving)
	var actual := direction.rotated(Vector3.UP, _fire_rng.randfn(0.0, spread)) if spread > 0.0 else direction
	if tank.weapon["kind"] == Weapons.Kind.BEAM:
		_fire_beam(tank, muzzle, actual)
		return
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		_lob(tank, muzzle)
		return
	shell_spawner.spawn({"id": _next_shell_id, "muzzle": muzzle, "ray_start": tank.turret.global_position,
			"direction": actual, "team": tank.team, "shooter": String(tank.name),
			"range": float(tank.weapon["range"]) + Shell.RANGE_MARGIN})
	_next_shell_id += 1


## Indirect rounds in the air: [{"from", "to", "land_tick", "team", "shooter", "weapon"}], in firing order.
var _rounds: Array = []


## ARC weapons (artillery): lob a round at the tank's aim point, scattered, clamped to the weapon's
## range window. It lands after its flight time and bursts (see _land_rounds).
func _lob(tank: Tank, muzzle: Vector3) -> void:
	var weapon := tank.weapon
	var flat := Vector3(tank.aim_point.x - muzzle.x, 0.0, tank.aim_point.z - muzzle.z)
	var distance := clampf(flat.length(), float(weapon["min_range"]), float(weapon["range"]))
	var direction := flat.normalized() if flat.length() > 0.01 else tank.turret_forward()
	var target := Vector3(muzzle.x, 0.0, muzzle.z) + direction * distance
	var sigma := arc_scatter(weapon, distance, is_point_spotted(tank.team, target))
	target += Vector3(_fire_rng.randfn(0.0, sigma), 0.0, _fire_rng.randfn(0.0, sigma))
	var flight_ticks := maxi(1, roundi(distance / float(weapon["flight_speed"]) * 60.0))
	_rounds.append({"from": muzzle, "to": target, "land_tick": tick + flight_ticks, "team": tank.team,
			"shooter": String(tank.name), "weapon": weapon})
	show_arc.rpc(muzzle, target, flight_ticks / 60.0)


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
		for victim in _sorted_tanks():
			if not victim.is_alive():
				continue  # R4: bursts hurt everyone inside, teammates included
			var offset := Vector3(victim.global_position.x - point.x, 0.0, victim.global_position.z - point.z)
			if offset.length() > radius:
				continue
			var falloff := lerpf(1.0, 0.3, offset.length() / radius)
			var from_burst := offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
			killed_any = _land_hit(victim, float(weapon["damage"]) * falloff, weapon, from_burst, int(landing["team"]),
					String(landing["shooter"]), "mortar_damage", not hit_any) or killed_any
			hit_any = true
		show_impact.rpc(point + Vector3.UP * 0.3, true)


## Beam weapons (G7 laser): an instant ray from the turret center; the first thing it touches takes
## the pulse, teammates included (R4 friendly fire).
func _fire_beam(tank: Tank, muzzle: Vector3, direction: Vector3) -> void:
	var weapon := tank.weapon
	var from := tank.turret.global_position
	var to := from + direction * float(weapon["range"])
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, [tank.get_rid()])
	var hit := tank.get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var victim := hit.collider as Tank
		if victim != null and victim.is_alive():
			_land_hit(victim, float(weapon["damage"]), weapon, direction, tank.team, String(tank.name), "laser_damage", true)
	show_beam.rpc(muzzle, end, String(weapon.get("fx", "fx.laser_beam")))


## Cone weapons: every tank inside the cone with line of sight burns this tick, teammates included (R4).
func _on_tank_sprayed(origin: Vector3, direction: Vector3, delta: float, tank: Tank) -> void:
	var weapon := tank.weapon
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


## Tanks in a stable order (by name): anything that affects decisions or damage
## must iterate deterministically.
func _sorted_tanks() -> Array[Tank]:
	var result: Array[Tank] = []
	for node in tanks.get_children():
		if node is Tank and not node.is_queued_for_deletion():
			result.append(node)
	result.sort_custom(func(a: Tank, b: Tank) -> bool: return String(a.name) < String(b.name))
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
		var radius := Vector2(float(size[0]), float(size[2])).length() / 2.0
		var risky := false
		match int(weapon["kind"]):
			Weapons.Kind.ARC:
				var distance := clampf(to_aim.length(), float(weapon["min_range"]), float(weapon["range"]))
				var landing := flat_origin + direction * distance
				var sigma := arc_scatter(weapon, distance, true)
				risky = spot.distance_to(landing) <= float(weapon["splash_radius"]) + radius + LINE_OF_FIRE_SIGMAS * sigma
			Weapons.Kind.CONE:
				risky = Weapons.in_cone(origin, Vector3(direction.x, 0.0, direction.y), friend.global_position,
						float(weapon["range"]) + radius, float(weapon["cone_deg"]))
			_:
				var reach := minf(to_aim.length() + LINE_OF_FIRE_OVERSHOOT, float(weapon["range"]) + Shell.RANGE_MARGIN)
				var along := (spot - flat_origin).dot(direction)
				if along > 0.0 and along <= reach + radius:
					var across := absf((spot - flat_origin).cross(direction))
					var moving := clampf(absf(shooter.speed()) / maxf(shooter.max_forward_speed, 0.1), 0.0, 1.0)
					var spread_deg := float(weapon.get("spread_deg", 0.0)) * (1.0 + MOVING_SPREAD_FACTOR * moving)
					var spread := tan(deg_to_rad(spread_deg) * LINE_OF_FIRE_SIGMAS) * along
					risky = across <= radius + spread
		if risky:
			at_risk.append(friend)
			distances[friend] = spot.distance_to(flat_origin)
	at_risk.sort_custom(func(a: Tank, b: Tank) -> bool: return distances[a] < distances[b])
	return at_risk


## R2: the fraction of a hit's hull damage that gets through `unit_id`'s armor on `face`.
static func armor_multiplier(weapon: Dictionary, unit_id: String, face: String) -> float:
	return Armor.penetration_multiplier(float(weapon.get("penetration", 0.0)), Units.armor(unit_id, face))


## Every weapon's damage lands here (G6): shield first, then hull through the armor facing.
## `direction` is the attack's travel direction. Returns true if it destroyed the victim.
func _land_hit(victim: Tank, raw: float, weapon: Dictionary, direction: Vector3, team: int, shooter: String,
		weapon_stat: String, counts_as_hit: bool) -> bool:
	var forward := -victim.global_basis.z
	var face: String = Armor.FACING_NAMES[Armor.facing(forward, direction)]
	if weapon["kind"] == Weapons.Kind.ARC:
		face = "side"  # indirect rounds come down on top: no face is the strong one
	var result := victim.take_hit(raw, float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face]),
			armor_multiplier(weapon, victim.unit_id, face))
	if victim.team == team:
		stats["friendly_damage"][team] += float(result["hull"]) + float(result["shield"])
		stats["friendly_hits"][team] += 1 if counts_as_hit else 0
		if result["killed"]:
			stats["friendly_kills"][team] += 1
			print("%s destroyed teammate %s (friendly fire)" % [shooter, victim.name])
			tank_destroyed.emit(victim, shooter)
		friendly_fire.emit(victim, shooter, int(result["hull"]), bool(result["killed"]))
		return result["killed"]
	if counts_as_hit:
		stats["hits"][team] += 1
		stats["hits_by_face"][face] += 1
	stats["damage"][team] += int(result["hull"])
	stats["shield_damage"][team] += float(result["shield"])
	if weapon_stat != "":
		stats[weapon_stat][team] += int(result["hull"])
	if result["killed"]:
		_score_kill(team, shooter, victim)
	return result["killed"]


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
	tank_destroyed.emit(victim, killer)


func _on_shell_hit(shell: Shell, collider: Object, point: Vector3) -> void:
	var killed := false
	var victim := collider as Tank
	if victim != null and victim.is_alive():
		var shooter := tanks.get_node_or_null(NodePath(shell.shooter_name)) as Tank
		var weapon := shooter.weapon if shooter != null else Weapons.profile(Weapons.DEFAULT)
		killed = _land_hit(victim, float(weapon["damage"]), weapon, shell.direction, shell.team, shell.shooter_name, "", true)
	show_impact.rpc(point, killed)
	shell.queue_free()


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
