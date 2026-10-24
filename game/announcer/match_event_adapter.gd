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
## The same unit records as `_units`, in an Array: the per-tick walk (round 16, B6).
var _watched: Array[Dictionary] = []
## The per-tick walk's fast path, parallel to `_watched`: each tank, the health last seen, and whether the record
## needs its full check even with an unchanged hull (1 = a close call is being timed; 2 = dead, never again).
var _watch_tanks: Array[Tank] = []
var _watch_seen := PackedInt32Array()
var _watch_state := PackedByteArray()
var _last_momentum_t := 0.0
## Round 37 (feedback F3): which face of a vehicle the round that hurt it struck, so the caller can say a flank or a rear
## hit (and a weak spot) in a live match, not only in the recorded fixtures: target name -> {tick, face, weak_spot} of
## its latest K2 impact; rounds from above (artillery) report no face (their "side" is not a flank).
var _struck := {}
var _arcing := {}
const STRUCK_FRESH_S := 0.5
## Round 39 (feedback stretch, his six approved caller lines): the booth hears two of round 37's rules in a real match,
## ON by default since round 39's close (his call: "If we have new announcer scripts we should just turn them on");
## `--announcer-rules=off` mutes them. Carried on momentum as an optional `rules` field, so K5 is
## unchanged (as round 37's `face`): {"moving": {team: [misses, hits]}, "slowed": {team: unit or ""}}
##   moving  shells a team fired on the move (R2's spread) since the last momentum: how many hit no vehicle, how
##           many hit an enemy
##   slowed  a crew R3 has held at RULE_SLOW_FROM or more of its speed for RULE_SLOW_S while it drives ("" none)
var rules_calls: bool = LaunchFlags.from_environment().text("announcer-rules") != "off"
## A round is fired on the move from this fraction of the hull's top speed (FeedbackReader's, Match.shot_spread's).
const RULE_MOVING_FROM := 0.15
## A round no impact reported after this long missed (it flew on past its range).
const RULE_MISS_WAIT_S := 3.0
## R3's slow that counts (of the crew's speed: suppression 0.5 at PIN_SLOW_MAX 0.4), on a hull still rolling this fast.
const RULE_SLOW_FROM := 0.2
const RULE_SLOW_SPEED := 1.0
const RULE_SLOW_S := 2.0
## projectile id -> [team, seconds fired] of a gun round fired on the move, until its impact.
var _moving_rounds := {}
var _moving_count := [[0, 0], [0, 0]]
## unit id -> seconds since its slow began.
var _slow_since := {}


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
	# Round 19 (board, S3): every zone's capture, not only zone 0's (`control_changed` is the primary zone's): the
	# twelve dealt maps score two rings, and the booth heard half of what happened on them.
	game_match.objective_changed.connect(_on_objective_changed)
	game_match.finished.connect(_on_finished)
	game_match.weapon_fired.connect(_on_weapon_fired)
	game_match.projectile_impact.connect(_on_impact)
	listen_for_elements()


## Match time: ticks at the rate the physics actually runs. A constant 60 here would put the booth, the match mood
## and the music at half speed the moment the tick becomes 30 Hz (round 5): stale windows twice as long, heat
## decaying half as fast.
func seconds() -> float:
	# Engine.physics_ticks_per_second, not SimClock.TICK_RATE: the booth's clock must follow the rate the physics is
	# ACTUALLY running at (tests change it at runtime, and the two agree in every shipped configuration —
	# tests/test_sim_clock.gd checks that). Restored on main once already: a "Merge main" on stream/combat resolved
	# this hunk back to the old constant while keeping the test that asserts the new behaviour, so main arrived red.
	return game_match.tick / float(Engine.physics_ticks_per_second)


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
		if rules_calls:
			_watch_slowed()
		if seconds() - _last_momentum_t >= MOMENTUM_EVERY_S:
			_last_momentum_t = seconds()
			var momentum := {"army_health": {"green": _army_health(0), "rust": _army_health(1)},
					"units_left": {"green": game_match.alive_count(0), "rust": game_match.alive_count(1)}}
			if rules_calls:
				momentum["rules"] = _rules_since()
			_emit("momentum", momentum)
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
			units.append({"id": id, "unit": booth_unit(tank.unit_id), "squad": game_match.squad_of(tank)})
			_units[id] = {"tank": tank, "team": team, "unit": booth_unit(tank.unit_id), "alive": tank.is_alive(), "hull": _hull(tank),
					"id": id, "health": tank.health, "low_since": -1.0, "close_call": false, "reported": -100.0}
			_watched.append(_units[id])
			_watch_tanks.append(tank)
			_watch_seen.append(tank.health)
			_watch_state.append(0)
			tank.fired.connect(_on_fired.bind(id))
		teams.append({"team": TEAM_KEYS[team], "faction": team_faction(team), "units": units})
	# match_start carries the whole roster; events before it in this poll would break the contract's order.
	var earlier := _pending
	_pending = []
	_emit("match_start", {"arena": arena, "budget": game_match.budget, "teams": teams, "control_point": game_match.control_point,
			"zones": game_match.objectives.size() if game_match.control_point else 0})
	_pending.append_array(earlier)


static func _hull(tank: Tank) -> float:
	return clampf(float(tank.health) / maxf(1.0, float(tank.max_health)), 0.0, 1.0)


func _army_health(team: int) -> float:
	var total := 0.0
	var count := 0
	for unit in _watched:
		if unit["team"] == team:
			count += 1
			total += unit["hull"] if unit["alive"] else 0.0
	return snappedf(total / maxf(1.0, count), 0.001)


## Hull drops become damage events (rate-limited like the fixtures); low hull that survives becomes a close call.
func _watch_health() -> void:
	var now := seconds()
	# Round 16 (B6): most hulls don't change in a given tick, and an unchanged hull emits nothing unless a close call
	# is being timed. Walking 52 records of Dictionaries every tick was the whole booth's cost at his army size; the
	# packed arrays skip the quiet ones, and the events are exactly what the full walk emitted (max_health is fixed
	# once a tank is set up).
	for index in _watch_tanks.size():
		var state := _watch_state[index]
		if state == 2:
			continue
		var tank := _watch_tanks[index]
		if not is_instance_valid(tank):
			continue
		var health := tank.health
		if health == _watch_seen[index] and state == 0:
			continue
		_watch_seen[index] = health
		var unit: Dictionary = _watched[index]
		if not unit["alive"]:
			_watch_state[index] = 2
			continue
		var id: String = unit["id"]
		var hull := _hull(tank)
		var lost: float = unit["hull"] - hull
		unit["hull"] = hull
		if lost > 0.0 and tank.is_alive():
			var critical := lost >= 0.3 or hull <= 0.25
			if critical or (lost >= 0.1 and now - float(unit["reported"]) >= DAMAGE_REPORT_GAP_S):
				var shooter := _nearest_enemy(tank)
				if shooter != "":
					unit["reported"] = now
					var damage := {"shooter": shooter, "shooter_unit": _units[shooter]["unit"], "victim": id,
							"victim_unit": unit["unit"], "hull": snappedf(hull, 0.001),
							"shield": snappedf(clampf(tank.shield / maxf(1.0, float(tank.max_shield)), 0.0, 1.0), 0.001),
							"critical": critical, "amount": snappedf(lost, 0.001)}
					damage.merge(_struck_face(id))
					_emit("damage", damage)
		if hull < CLOSE_CALL_HULL and float(unit["low_since"]) < 0.0:
			unit["low_since"] = now
			_watch_state[index] = 1
		if not unit["close_call"] and float(unit["low_since"]) >= 0.0 and now - float(unit["low_since"]) >= CLOSE_CALL_DELAY_S:
			unit["close_call"] = true
			_watch_state[index] = 0
			_emit("close_call", {"unit_id": id, "unit": unit["unit"], "team": TEAM_KEYS[unit["team"]], "hull_left": snappedf(hull, 0.001)})


## The face and weak spot of the round that just struck `id` ({} when no fresh impact says: a burst, a flame).
func _struck_face(id: String) -> Dictionary:
	var hit: Dictionary = _struck.get(id, {})
	if hit.is_empty() or game_match.tick - int(hit["tick"]) > roundi(STRUCK_FRESH_S * Engine.physics_ticks_per_second):
		return {}
	var known := {"weak_spot": bool(hit["weak_spot"])}
	if String(hit["face"]) != "":
		known["face"] = hit["face"]
	return known


func _on_weapon_fired(event: Dictionary) -> void:
	if rules_calls and String(event.get("fire_model", "")) == "shell":  # a beam lands before it is announced
		var unit: Dictionary = _units.get(String(event.get("shooter", "")), {})
		var tank: Tank = unit.get("tank")
		if tank != null and is_instance_valid(tank) and absf(tank.speed()) >= RULE_MOVING_FROM * maxf(tank.max_forward_speed, 0.1):
			_moving_rounds[int(event.get("projectile_id", -1))] = [int(unit["team"]), seconds()]
	if String(event.get("fire_model", "")) == "arc":
		_arcing[int(event.get("projectile_id", -1))] = true
		if _arcing.size() > 512:
			_arcing.clear()


func _on_impact(event: Dictionary) -> void:
	var target := String(event.get("target", ""))
	var moving: Array = _moving_rounds.get(int(event.get("projectile_id", -1)), [])
	if not moving.is_empty():
		_moving_rounds.erase(int(event.get("projectile_id", -1)))
		var team := int(moving[0])
		var enemy: bool = _units.has(target) and int(_units[target]["team"]) != team
		_moving_count[team][1 if enemy else 0] += 1
	if target == "":
		return
	var from_above := _arcing.erase(int(event.get("projectile_id", -1)))
	_struck[target] = {"tick": game_match.tick, "face": "" if from_above else String(event.get("face", "")),
			"weak_spot": bool(event.get("weak_spot", false))}


## Round 39: when each crew's R3 slow began (rolling, at RULE_SLOW_FROM or more); a crew that stops or shakes it off
## starts again.
func _watch_slowed() -> void:
	var now := seconds()
	for index in _watch_tanks.size():
		var tank := _watch_tanks[index]
		var id: String = _watched[index]["id"]
		if is_instance_valid(tank) and tank.pin_slow() * Tank.PIN_SLOW_MAX >= RULE_SLOW_FROM \
				and absf(tank.speed()) >= RULE_SLOW_SPEED:
			if not _slow_since.has(id):
				_slow_since[id] = now
		else:
			_slow_since.erase(id)


## Round 39: the rules heard since the last momentum (the `rules` field), then a fresh count.
func _rules_since() -> Dictionary:
	var now := seconds()
	for id: Variant in _moving_rounds.keys():
		var round_of: Array = _moving_rounds[id]
		if now - float(round_of[1]) >= RULE_MISS_WAIT_S:
			_moving_count[int(round_of[0])][0] += 1
			_moving_rounds.erase(id)
	var rules := {"moving": {}, "slowed": {}}
	for team in [0, 1]:
		rules["moving"][TEAM_KEYS[team]] = (_moving_count[team] as Array).duplicate()
		var slowed := ""
		for id: String in _slow_since:
			var unit: Dictionary = _units[id]
			if int(unit["team"]) == team and unit["alive"] and now - float(_slow_since[id]) >= RULE_SLOW_S:
				slowed = unit["unit"]
				break
		rules["slowed"][TEAM_KEYS[team]] = slowed
	_moving_count = [[0, 0], [0, 0]]
	return rules


func _nearest_enemy(tank: Tank) -> String:
	var best := ""
	var best_distance := INF
	for other in _watched:
		if other["team"] == tank.team or not other["alive"] or not is_instance_valid(other["tank"]):
			continue
		var distance := tank.global_position.distance_squared_to((other["tank"] as Tank).global_position)
		if distance < best_distance:
			best_distance = distance
			best = other["id"]
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


## `control_changed` for any zone. `zone` (the board's name for it) and `previous` (that zone's last owner) ride along
## as optional fields; a recording without them reads as the single-zone match it was.
func _on_objective_changed(index: int, owner: int) -> void:
	if not _started or _ended:
		return
	var names: Array = game_match.objectives.map(func(o: Dictionary) -> String: return String(o["name"]))
	var zone := MatchScore.zone_label(String(names[index]), names) if index >= 0 and index < names.size() else ""
	var previous := int(_zone_owners.get(index, -1))
	_zone_owners[index] = owner
	_emit("control_changed", {"owner": TEAM_KEYS[owner] if owner >= 0 else "neutral", "zone": zone,
			"previous": TEAM_KEYS[previous] if previous >= 0 else "neutral"})


## Each zone's owner as last reported (index -> team or -1).
var _zone_owners := {}


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
			var role := booth_unit(String(unit))
			kills[key][role] = int(kills[key].get(role, 0)) + int(result["kills_by_unit"][key][unit])
	_emit("match_end", {"winner": String(result["winner"]).to_lower(), "reason": reasons.get(result["reason"], "time"),
			"duration_seconds": float(result["duration_seconds"]),
			"units_left": {"green": int(result["units_left"]["green"]), "rust": int(result["units_left"]["rust"])},
			"kills_by_unit": kills})


## The unit type the booth speaks of: a faction's own vehicle ("gang_ifv", the Gun Truck) by its role ("ifv"). K5's
## unit fields are the six types the booth has words for; the faction is already on the team (round 12: sending the
## faction id made every unit-naming line ineligible in every faction match, and every recording invalid).
static func booth_unit(unit_id: String) -> String:
	var role := Units.role_of(unit_id)
	return role if role in AnnouncerEvents.UNIT_TYPES else unit_id

