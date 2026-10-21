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
## Round 34 (T6's bar): also STANDOFF rows (two friendly crews nose to nose, box gap <= STANDOFF_GAP_M, both under way, both
## hit within UNDER_FIRE_S, neither giving way, both slower than STANDOFF_MPS, for STANDOFF_MIN_S or more: the pair, where, how
## long) and ABORT rows (a give-way that ended the tick a hit landed: the crew, and the friendly hull contacts it had in the
## ABORT_WINDOW_S after). Both read from state only, so the probe runs on main and on the under-fire pair alike.
##   godot --headless --fixed-fps 30 --path . --script res://tests/traffic/jam_census.gd -- --skirmish --demo-match --clean --seed=N --arena=A --mute --seconds=180

## Still means slower than this (m/s): Traffic's table clock on the parkedroom branch; a local constant here so the probe runs on main.
const STILL_MPS := 0.3

const UNDER_FIRE_S := 5.0
const STANDOFF_GAP_M := 1.0
const STANDOFF_MPS := 0.5
const STANDOFF_MIN_S := 2.0
const ABORT_WINDOW_S := 3.0
const CONTACT_GAP_M := 0.15
var _standoffs := 0
var _aborts := 0
var _abort_contacts := 0
## Round 35 (T7's bar): every new friendly hull contact (guard 7), and those with a crew passing a refuser (reported).
var _friendly_contacts := 0
var _pass_contacts := 0
## Round 35 ((D), REPORTED; T5's causes unchanged): the last tick each crew was held by the take-turns hold (Traffic.holding),
## for JAM_DEATH's `held` (held the tick before) and `held_3s` (held, or released from a hold, within HELD_RECENT_S): T8's G.
const HELD_RECENT_S := 3.0
var _held_at := {}
var _held_deaths := 0
## (D), R35.7: the REPORTED sub-cause `jam:held` (a death while held by the take-turns hold the tick before), counted beside T5's
## causes, never instead of them (manoeuvre's W1: held crews read as stuck:wedged).
var _by_sub_cause := {}
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
			"standoffs": _standoffs, "aborts": _aborts, "abort_contacts": _abort_contacts,
			"friendly_contacts": _friendly_contacts, "pass_contacts": _pass_contacts, "held_deaths": _held_deaths, "by_sub_cause": _by_sub_cause,
			"underfire_on": not Traffic.off("underfire"), "route_arms": Movement.route_arms(),
			"holdfire_on": not Traffic.off("holdfire"), "traffic": Traffic.report()}))  # T8 (R35.7): the hold's own report


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
	var standing := {}  # "a|b" -> the tick the standoff began
	var open_aborts: Array = []  # [unit, tick, contacts] for ABORT_WINDOW_S
	var in_contact := {}  # "a|b" -> touching last tick
	var prev_yield := {}  # unit -> yield_to last tick (an abort = a give-way ending the tick a hit lands)
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
		_standoffs_and_aborts(game_match, prev_yield, standing, open_aborts, in_contact)
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
		if tank.speed() > STILL_MPS or not moving_at.has(name):
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
		var held := Traffic.holding(name)
		if held:
			_held_at[name] = tick
		alive[name] = {"sub_cause": "jam:held" if held else "", "held": held, "held_3s": _held_at.has(name) and tick - int(_held_at[name]) <= int(HELD_RECENT_S * SimClock.TICK_RATE),
				"hull": tank.unit_id, "team": tank.team, "cause": cause, "phase": phase, "blocked_by": blocker_name,
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
			if bool(row.get("held_3s", false)):
				_held_deaths += 1
			if String(row.get("sub_cause", "")) != "":
				var key := "%s<%s" % [row["sub_cause"], row["cause"]]
				_by_sub_cause[key] = int(_by_sub_cause.get(key, 0)) + 1
			print("JAM_DEATH " + JSON.stringify(row))
	last_seen.clear()
	last_seen.merge(alive)


## T6's bar lines, read from state. `last_seen` holds this tick's rows (after _observe), with each crew's yield_to.
func _standoffs_and_aborts(game_match: Match, prev_yield: Dictionary, standing: Dictionary, open_aborts: Array, in_contact: Dictionary) -> void:
	var tick := game_match.tick
	var hulls: Array = []
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive():
			hulls.append(tank)
	var fire_ticks := int(UNDER_FIRE_S * SimClock.TICK_RATE)
	var seen_pairs := {}
	for i in hulls.size():
		for j in range(i + 1, hulls.size()):
			var a: Tank = hulls[i]
			var b: Tank = hulls[j]
			if a.team != b.team:
				continue
			var gap := TrafficStage.box_gap(a, b)
			var key := "%s|%s" % [a.name, b.name]
			var touching := gap <= CONTACT_GAP_M
			if touching and not bool(in_contact.get(key, false)):
				_friendly_contacts += 1
				var pa := Movement.of(a)
				var pb := Movement.of(b)
				if (pa != null and pa._pass_by != "") or (pb != null and pb._pass_by != ""):
					_pass_contacts += 1
				for ab: Array in open_aborts:  # a new friendly contact inside an abort's window, involving the aborted crew
					if (String(ab[0]) == String(a.name) or String(ab[0]) == String(b.name)) and tick - int(ab[1]) <= int(ABORT_WINDOW_S * SimClock.TICK_RATE):
						ab[2] = int(ab[2]) + 1
			in_contact[key] = touching
			var ma := Movement.of(a)
			var mb := Movement.of(b)
			var standoff := gap <= STANDOFF_GAP_M and ma != null and mb != null and ma.is_under_way() and mb.is_under_way() \
					and ma.yield_to == "" and mb.yield_to == "" and a.ticks_since_hit <= fire_ticks and b.ticks_since_hit <= fire_ticks \
					and absf(a.speed()) < STANDOFF_MPS and absf(b.speed()) < STANDOFF_MPS
			if standoff:
				seen_pairs[key] = true
				if not standing.has(key):
					standing[key] = tick
	for key: String in standing.keys():
		if not seen_pairs.has(key):
			var lasted := (tick - int(standing[key])) / float(SimClock.TICK_RATE)
			standing.erase(key)
			if lasted >= STANDOFF_MIN_S:
				_standoffs += 1
				var names := key.split("|")
				var a := game_match.tanks.get_node_or_null(NodePath(names[0])) as Tank
				var at: Array = [snappedf(a.global_position.x, 0.1), snappedf(a.global_position.z, 0.1)] if a != null else [0.0, 0.0]
				print("STANDOFF " + JSON.stringify({"pair": [names[0], names[1]], "s": snappedf(_seconds_run - lasted, 0.1),
						"lasted_s": snappedf(lasted, 0.1), "at": at, "terrain": ElementSituation.terrain_at(a.global_position) if a != null else "?"}))
	# Aborts: a crew whose give-way ended this tick (yield_to non-empty last tick, empty now) the tick a hit landed.
	for node in hulls:
		var tank := node as Tank
		var mover := Movement.of(tank)
		if mover != null and mover.yield_to == "" and String(prev_yield.get(String(tank.name), "")) != "" and tank.ticks_since_hit <= 3:  # the brain's stride is up to 3 ticks
			_aborts += 1
			open_aborts.append([String(tank.name), tick, 0])
	for node in hulls:
		var tank := node as Tank
		var mover := Movement.of(tank)
		prev_yield[String(tank.name)] = mover.yield_to if mover != null else ""
	var closed: Array = []
	for ab: Array in open_aborts:
		if tick - int(ab[1]) > int(ABORT_WINDOW_S * SimClock.TICK_RATE):
			_abort_contacts += int(ab[2])
			print("ABORT " + JSON.stringify({"unit": ab[0], "s": snappedf(int(ab[1]) / float(SimClock.TICK_RATE), 0.1), "contacts_3s": ab[2]}))
			closed.append(ab)
	for ab: Array in closed:
		open_aborts.erase(ab)
