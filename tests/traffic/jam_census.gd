extends SceneTree
## Round 34 (traffic T5, measurement on MAIN): crews that die JAMMED by friendly traffic. Showmatch fights (both CPU sides run
## elements, as his opponent does); every crew lost prints a JAM_DEATH row read from its drive state the tick BEFORE it died:
##   cause   far_census's death_cause: jam:yielding / jam:friend (friendly traffic), stuck:* (no path, static, wedged, still
##           while under way), open:* (driving, enemy contact, parked)
##   blocker  for a jam: who held it (blocker_rel own_squad / other_squad / unseated), whether that crew is a set-up battery
##   jam_s    how long it had been continuously jammed (yielding, or blocked by a friendly hull) before it died
##   hit_in_jam  whether its last hit before the death blow landed during that jam; hits_10s hits on it in the last 10 s
##   terrain  ElementSituation.terrain_at (dense / lanes / open) at the death; base_m its distance from its team's start
##   JAM_CENSUS {...}  the fight's totals.
##   godot --headless --fixed-fps 30 --path . --script res://tests/traffic/jam_census.gd -- --skirmish --demo-match --clean --seed=N --arena=A --mute --seconds=180

var _teams := {}
var _seconds_run := 0.0
var _printed := false
var _deaths := 0
var _by_cause := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fight_row(team: int) -> Dictionary:
	return _teams.get_or_add(str(team), {"shots": 0, "hits": 0, "kills": 0, "deaths": 0})


func _finalize() -> void:
	_report()


func _report() -> void:
	if _printed:
		return
	_printed = true
	print("JAM_CENSUS " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"seconds": snappedf(_seconds_run, 0.1), "deaths": _deaths, "by_cause": _by_cause, "teams": _teams,
			"parkedroom_on": not Traffic.off("parkedroom")}))


## far_census.gd's death_cause, verbatim (traffic X1, round 34).
static func death_cause(under_way: bool, phase: String, blocked_kind: String, still_s: float, wedged: bool) -> String:
	if not under_way:
		return "open:parked"
	if phase == "yielding":
		return "jam:yielding"
	if phase == "blocked":
		if blocked_kind == "friend":
			return "jam:friend"
		if blocked_kind == "enemy":
			return "open:enemy"
		return "stuck:" + ("no_path" if blocked_kind == "no_path" else "static")
	if wedged:
		return "stuck:wedged"
	if still_s >= Movement.BLOCKED_SECONDS:
		return "stuck:still"
	return "open:driving"


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var shooter_of := {}
	var hits_at := {}  # victim -> [ticks of hits]
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null:
			return
		var row_shots := _fight_row(shooter.team)
		row_shots["shots"] = int(row_shots["shots"]) + 1
		shooter_of[event.get("projectile_id", -1)] = shooter.team)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var team: Variant = shooter_of.get(event.get("projectile_id", -1))
		if team == null or not event.has("target"):
			return
		var victim := game_match.tanks.get_node_or_null(String(event["target"])) as Tank
		if victim != null and victim.team != int(team):
			var row_hits := _fight_row(int(team))
			row_hits["hits"] = int(row_hits["hits"]) + 1
			hits_at.get_or_add(String(event["target"]), []).append(game_match.tick))
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var row_deaths := _fight_row(int(event.get("team", -1)))
		row_deaths["deaths"] = int(row_deaths["deaths"]) + 1
		var killer := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
		if killer != null and String(event.get("cause", "")) == "enemy":
			var row_kills := _fight_row(killer.team)
			row_kills["kills"] = int(row_kills["kills"]) + 1)
	var seconds := float(_flag("seconds", "180"))
	var started := -1
	var last_tick := -1
	var frames := 0
	var last_seen := {}
	var moving_at := {}
	var jam_since := {}
	var base := {}  # team -> [sum, n] of first-seen positions
	var first_seen := {}
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		_seconds_run = (tick - started) / float(SimClock.TICK_RATE)
		_observe(game_match, last_seen, moving_at, jam_since, hits_at, base, first_seen)
		if seconds > 0.0 and _seconds_run > seconds:
			break
	_report()
	quit(0)


func _observe(game_match: Match, last_seen: Dictionary, moving_at: Dictionary, jam_since: Dictionary, hits_at: Dictionary,
		base: Dictionary, first_seen: Dictionary) -> void:
	var tick := game_match.tick
	var alive := {}
	var elements := Elements.of_match(game_match)
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var name := String(tank.name)
		if not first_seen.has(name):
			first_seen[name] = true
			var b: Array = base.get_or_add(str(tank.team), [Vector3.ZERO, 0])
			b[0] += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			b[1] += 1
		if tank.speed() > Traffic.STILL_SPEED or not moving_at.has(name):
			moving_at[name] = tick
		var still_s := (tick - int(moving_at[name])) / float(SimClock.TICK_RATE)
		var mover := Movement.of(tank)
		var under_way := mover != null and mover.is_under_way()
		var blocked_kind := "none"
		var blocker_rel := ""
		var blocker_setup := false
		var blocker_name := mover.blocked_by if mover != null and (mover.phase == "blocked" or mover.phase == "yielding") else ""
		if mover != null and mover.phase == "yielding" and mover.yield_to != "":
			blocker_name = mover.yield_to
		if blocker_name != "":
			var other := game_match.tanks.get_node_or_null(NodePath(blocker_name)) as Tank
			if other != null:
				blocked_kind = "friend" if other.team == tank.team else "enemy"
				if other.team == tank.team:
					var mine := elements.of(name) if elements != null else null
					var theirs := elements.of(blocker_name) if elements != null else null
					blocker_rel = "unseated" if mine == null or theirs == null else ("own_squad" if mine == theirs else "other_squad")
					blocker_setup = other.deploy_ratio > 0.0
			elif blocker_name == "no_path":
				blocked_kind = "no_path"
			else:
				blocked_kind = "static"
		var phase := mover.phase if mover != null else ""
		var cause := death_cause(under_way, phase, blocked_kind, still_s, mover != null and mover.wedged)
		if cause.begins_with("jam:"):
			if not jam_since.has(name):
				jam_since[name] = tick
		else:
			jam_since.erase(name)
		var recent: Array = hits_at.get(name, [])
		var hits_10s := 0
		for t in recent:
			if tick - int(t) <= 10 * SimClock.TICK_RATE:
				hits_10s += 1
		var jam_ticks := tick - int(jam_since.get(name, tick))
		alive[name] = {"hull": tank.unit_id, "team": tank.team, "cause": cause, "phase": phase, "blocked_by": blocker_name,
				"blocker_rel": blocker_rel, "blocker_setup": blocker_setup, "jam_s": snappedf(jam_ticks / float(SimClock.TICK_RATE), 0.1),
				"hit_in_jam": cause.begins_with("jam:") and tank.ticks_since_hit <= jam_ticks, "hits_10s": hits_10s,
				"still_s": snappedf(still_s, 0.1), "v": snappedf(tank.speed(), 0.1),
				"terrain": ElementSituation.terrain_at(tank.global_position),
				"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)]}
	for name: String in last_seen:
		if not alive.has(name):
			var row: Dictionary = (last_seen[name] as Dictionary).duplicate()
			row["unit"] = name
			row["s"] = snappedf(_seconds_run, 0.1)
			var b: Array = base.get(str(row["team"]), [Vector3.ZERO, 0])
			if int(b[1]) > 0:
				var centre: Vector3 = (b[0] as Vector3) / int(b[1])
				row["base_m"] = snappedf(_flat(Vector3(row["at"][0], 0.0, row["at"][1]), centre), 0.1)
			_deaths += 1
			_by_cause[row["cause"]] = int(_by_cause.get(row["cause"], 0)) + 1
			print("JAM_DEATH " + JSON.stringify(row))
	last_seen.clear()
	last_seen.merge(alive)
