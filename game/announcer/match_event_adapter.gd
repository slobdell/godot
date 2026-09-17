class_name MatchEventAdapter
extends RefCounted
## Turns a live Match into K5 announcer events (tests/announcer/fixtures/README.md): the same timeline the fixtures
## hold, so the director can't tell a real match from a fake one.
##
## It only listens: Match signals (tank_destroyed, friendly_fire, control_changed, finished), each Tank's `fired`, and
## reads of health, shield, team, and squad. It never writes to the simulation. Call poll() once per physics tick
## after the match has stepped; it returns the events that happened since the last call.
##
## Until combat's K2 weapon events merge (`projectile_impact` with the shooter), `damage` events are inferred from hull
## changes and credited to the victim's nearest living enemy; `first_contact`'s target is the shooter's nearest enemy.

const TEAM_KEYS := ["green", "rust"]
const MOMENTUM_EVERY_S := 5.0
const CLOSE_CALL_HULL := 0.15
const CLOSE_CALL_DELAY_S := 4.0
const DAMAGE_REPORT_GAP_S := 3.0

var game_match: Match
var arena := Arena.DEFAULT_LAYOUT
## Only a fallback now: each side's faction is read from the units the match actually fielded (team_faction).
var faction := Units.DEFAULT_FACTION

var _pending: Array = []
var _started := false
var _ended := false
var _contact := false
var _units := {}
var _last_momentum_t := 0.0


## Doctrine (L1) reports why an element is lining up the way it is, and the booth turns that into commentary
## instead of the HUD having to show it. Found by duck typing rather than by class: doctrine's `Elements` lives on
## its own branch until the checkpoint merges, and naming the class here would stop this file compiling before then.
## Still a pure listener — doctrine never hears back from us.
const ELEMENT_SIGNAL := "element_reported"


## True when something is publishing element decisions and we are listening to it (whether we connected just now
## or on an earlier call), so it is safe to call again after doctrine's nodes appear.
func listen_for_elements() -> bool:
	var candidates: Array = []
	if game_match.is_inside_tree():
		candidates.append_array(game_match.get_tree().get_nodes_in_group("elements"))
	candidates.append_array(game_match.get_children())
	for node in candidates:
		if not node.has_signal(ELEMENT_SIGNAL):
			continue
		if not node.is_connected(ELEMENT_SIGNAL, _on_element_reported):
			node.connect(ELEMENT_SIGNAL, _on_element_reported)
		return true
	return false


## Doctrine sends the decision with no clock on it; stamping it is ours, exactly as every other event here.
func _on_element_reported(event: Dictionary) -> void:
	var fields := event.duplicate()
	var type := String(fields.get("type", "element_formation"))
	fields.erase("type")
	_emit(type, fields)


func _init(watched: Match, arena_name: String = Arena.DEFAULT_LAYOUT) -> void:
	game_match = watched
	arena = arena_name
	game_match.tank_destroyed.connect(_on_destroyed)
	game_match.friendly_fire.connect(_on_friendly_fire)
	game_match.control_changed.connect(_on_control_changed)
	game_match.finished.connect(_on_finished)
	listen_for_elements()


## Match time: ticks at the rate the physics actually runs. A constant 60 here would put the booth, the match mood
## and the music at half speed the moment the tick becomes 30 Hz (round 5): stale windows twice as long, heat
## decaying half as fast.
func seconds() -> float:
	return SimClock.seconds(game_match.tick)


func _emit(type: String, fields: Dictionary) -> void:
	var event := {"tick": game_match.tick, "t": snappedf(seconds(), 0.01), "type": type}
	event.merge(fields)
	_pending.append(event)


## Events since the last poll, in order. The first one is match_start, once both armies are on the floor.
func poll() -> Array:
	if not _started:
		_try_start()
	elif not _ended:
		_watch_health()
		if seconds() - _last_momentum_t >= MOMENTUM_EVERY_S:
			_last_momentum_t = seconds()
			_emit("momentum", {"army_health": {"green": _army_health(0), "rust": _army_health(1)},
					"units_left": {"green": game_match.alive_count(0), "rust": game_match.alive_count(1)}})
	var out := _pending
	_pending = []
	return out


## The faction a side fields: the most common faction among its vehicles (control, round 5: a skirmish started from
## the faction menu had the booth calling the gangs "the Condemned", because every side was given this adapter's
## single default). Read from what the match built, not from any launch flag. Ties go to the first found.
func team_faction(team: int) -> String:
	var counts := {}
	var best := faction
	var best_count := 0
	for tank in game_match.sorted_team_tanks(team):
		var id := Units.faction_of(String(tank.unit_id))
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > best_count:
			best = id
			best_count = int(counts[id])
	return best


func _try_start() -> void:
	if game_match.team_tanks(0).is_empty() or game_match.team_tanks(1).is_empty():
		return
	_started = true
	_last_momentum_t = seconds()
	var teams: Array = []
	for team in [0, 1]:
		var units: Array = []
		for tank in game_match.sorted_team_tanks(team):
			var id := String(tank.name)
			units.append({"id": id, "unit": tank.unit_id, "squad": game_match.squad_of(tank)})
			_units[id] = {"tank": tank, "team": team, "unit": tank.unit_id, "alive": tank.is_alive(), "hull": _hull(tank),
					"low_since": -1.0, "close_call": false, "reported": -100.0}
			tank.fired.connect(_on_fired.bind(id))
		teams.append({"team": TEAM_KEYS[team], "faction": team_faction(team), "units": units})
	# match_start carries the whole roster; events before it in this poll would break the contract's order.
	var earlier := _pending
	_pending = []
	_emit("match_start", {"arena": arena, "budget": game_match.budget, "teams": teams, "control_point": game_match.control_point})
	_pending.append_array(earlier)


static func _hull(tank: Tank) -> float:
	return clampf(float(tank.health) / maxf(1.0, float(tank.max_health)), 0.0, 1.0)


func _army_health(team: int) -> float:
	var total := 0.0
	var count := 0
	for id in _units:
		if _units[id]["team"] == team:
			count += 1
			total += _units[id]["hull"] if _units[id]["alive"] else 0.0
	return snappedf(total / maxf(1.0, count), 0.001)


## Hull drops become damage events (rate-limited like the fixtures); low hull that survives becomes a close call.
func _watch_health() -> void:
	var now := seconds()
	for id in _units:
		var unit: Dictionary = _units[id]
		var tank: Tank = unit["tank"]
		if not unit["alive"] or not is_instance_valid(tank):
			continue
		var hull := _hull(tank)
		var lost: float = unit["hull"] - hull
		unit["hull"] = hull
		if lost > 0.0 and tank.is_alive():
			var critical := lost >= 0.3 or hull <= 0.25
			if critical or (lost >= 0.1 and now - float(unit["reported"]) >= DAMAGE_REPORT_GAP_S):
				var shooter := _nearest_enemy(tank)
				if shooter != "":
					unit["reported"] = now
					_emit("damage", {"shooter": shooter, "shooter_unit": _units[shooter]["unit"], "victim": id,
							"victim_unit": unit["unit"], "hull": snappedf(hull, 0.001),
							"shield": snappedf(clampf(tank.shield / maxf(1.0, float(tank.max_shield)), 0.0, 1.0), 0.001),
							"critical": critical, "amount": snappedf(lost, 0.001)})
		if hull < CLOSE_CALL_HULL and float(unit["low_since"]) < 0.0:
			unit["low_since"] = now
		if not unit["close_call"] and float(unit["low_since"]) >= 0.0 and now - float(unit["low_since"]) >= CLOSE_CALL_DELAY_S:
			unit["close_call"] = true
			_emit("close_call", {"unit_id": id, "unit": unit["unit"], "team": TEAM_KEYS[unit["team"]], "hull_left": snappedf(hull, 0.001)})


func _nearest_enemy(tank: Tank) -> String:
	var best := ""
	var best_distance := INF
	for id in _units:
		var other: Dictionary = _units[id]
		if other["team"] == tank.team or not other["alive"] or not is_instance_valid(other["tank"]):
			continue
		var distance := tank.global_position.distance_squared_to((other["tank"] as Tank).global_position)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


func _on_fired(_muzzle: Vector3, _direction: Vector3, id: String) -> void:
	if _contact or not _started or _ended:
		return
	var tank: Tank = _units[id]["tank"]
	var target := _nearest_enemy(tank)
	if target == "":
		return
	_contact = true
	_emit("first_contact", {"team": TEAM_KEYS[tank.team], "unit_id": id, "unit": _units[id]["unit"], "target_id": target,
			"target_unit": _units[target]["unit"]})


func _on_destroyed(victim: Tank, killer: String) -> void:
	var id := String(victim.name)
	if not _started or _ended or not _units.has(id) or not _units[id]["alive"]:
		return
	_units[id]["alive"] = false
	_units[id]["hull"] = 0.0
	var fields := {"victim": id, "victim_unit": _units[id]["unit"], "victim_team": TEAM_KEYS[_units[id]["team"]],
			"killer": "", "killer_unit": "", "killer_team": "", "friendly": false, "cause": "hazard"}
	if _units.has(killer):
		fields.merge({"killer": killer, "killer_unit": _units[killer]["unit"], "killer_team": TEAM_KEYS[_units[killer]["team"]],
				"friendly": _units[killer]["team"] == _units[id]["team"], "cause": "weapon"}, true)
	_emit("unit_destroyed", fields)
	var squad := game_match.squad_of(victim)
	if squad == "":
		return
	var lost := 0
	for other in game_match.team_tanks(victim.team):
		if game_match.squad_of(other) == squad:
			if _units.get(String(other.name), {}).get("alive", false):
				return
			lost += 1
	_emit("squad_wiped", {"team": TEAM_KEYS[victim.team], "squad": squad, "units_lost": lost})


func _on_friendly_fire(victim: Tank, shooter: String, _hull_damage: int, killed: bool) -> void:
	var id := String(victim.name)
	if not _started or _ended or not _units.has(id) or not _units.has(shooter):
		return
	# A fatal hit is the unit_destroyed event tank_destroyed already produced (Match emits it first); the contract
	# never names a destroyed unit again.
	if killed or not _units[id]["alive"]:
		return
	_emit("friendly_fire", {"shooter": shooter, "shooter_unit": _units[shooter]["unit"], "victim": id,
			"victim_unit": _units[id]["unit"], "team": TEAM_KEYS[victim.team], "hull": snappedf(_hull(victim), 0.001), "killed": false})


func _on_control_changed(owner: int) -> void:
	if not _started or _ended:
		return
	_emit("control_changed", {"owner": TEAM_KEYS[owner] if owner >= 0 else "neutral"})


func _on_finished(result: Dictionary) -> void:
	if not _started or _ended:
		return
	_watch_health()
	_ended = true
	var reasons := {"elimination": "elimination", "control": "control", "time_limit": "time", "score_limit": "elimination"}
	var kills := {}
	for key in TEAM_KEYS:
		kills[key] = {}
		for unit in result["kills_by_unit"][key]:
			kills[key][unit] = int(result["kills_by_unit"][key][unit])
	_emit("match_end", {"winner": String(result["winner"]).to_lower(), "reason": reasons.get(result["reason"], "time"),
			"duration_seconds": float(result["duration_seconds"]),
			"units_left": {"green": int(result["units_left"]["green"]), "rust": int(result["units_left"]["rust"])},
			"kills_by_unit": kills})
