extends SceneTree
## Round 37 (rules R2's first MEASURE, C37.2): how much of a fight's damage comes from crews firing ON THE MOVE, and at what
## range. If movers deal little of it, a harsher moving-spread rule changes little (say so before building it).
## Every round fired is tagged with its shooter's `moving` (|speed| / max_forward_speed, what Match._fire feeds shot_spread)
## and its range to the aim point; every enemy hit adds its damage (shield + hull) to that round's bucket. ARC rounds are
## counted apart: shot_spread doesn't touch them. Read-only: listens to K2 events, changes nothing in the sim.
##   godot --headless --fixed-fps 30 --path . --script res://tests/rules/moving_fire_probe.gd -- --skirmish --demo-match
##       --clean --seed=N --arena=A --mute --seconds=180
## Prints MOVING_FIRE {...}: per team and pooled, damage and hits by motion (still < 0.15 <= slow < 0.5 <= fast) x range
## (near < 50 m <= mid < 100 m <= far), the arc damage, and the shots by motion.

const SLOW := 0.15
const FAST := 0.5
const MID_M := 50.0
const FAR_M := 100.0

var _rows := {}
var _seconds_run := 0.0
var _printed := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _row(team: String) -> Dictionary:
	return _rows.get_or_add(team, {"damage": {}, "hits": {}, "shots": {}, "arc_damage": 0.0, "arc_hits": 0})


static func _motion(moving: float) -> String:
	return "still" if moving < SLOW else ("slow" if moving < FAST else "fast")


static func _range(metres: float) -> String:
	return "near" if metres < MID_M else ("mid" if metres < FAR_M else "far")


func _add(bucket: Dictionary, key: String, amount: float) -> void:
	bucket[key] = snappedf(float(bucket.get(key, 0.0)) + amount, 0.01)


func _finalize() -> void:
	_report()


func _report() -> void:
	if _printed:
		return
	_printed = true
	print("MOVING_FIRE " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"seconds": snappedf(_seconds_run, 0.1), "rules": RuleSwitches.describe(), "teams": _rows}))


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var tag_of := {}  # projectile_id -> [team, motion|range key, arc]
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null:
			return
		var arc: bool = shooter.weapon["kind"] == Weapons.Kind.ARC
		var moving := clampf(absf(shooter.speed()) / shooter.max_forward_speed, 0.0, 1.0)
		var muzzle := shooter.global_position
		var metres := Vector2(shooter.aim_point.x - muzzle.x, shooter.aim_point.z - muzzle.z).length()
		var key := "%s|%s" % [_motion(moving), _range(metres)]
		tag_of[event.get("projectile_id", -1)] = [shooter.team, key, arc]
		if not arc:
			_add(_row(str(shooter.team))["shots"], _motion(moving), 1.0))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var tag: Variant = tag_of.get(event.get("projectile_id", -1))
		if tag == null:
			return
		var team := int(tag[0])
		var victims: Array = event.get("victims", [])
		if victims.is_empty() and event.has("target"):
			victims = [{"target": event["target"], "damage": event.get("damage", 0.0)}]
		for victim_event: Dictionary in victims:
			var victim := game_match.tanks.get_node_or_null(String(victim_event.get("target", ""))) as Tank
			var damage := float(victim_event.get("damage", 0.0))
			if victim == null or victim.team == team or damage <= 0.0:
				continue
			var row := _row(str(team))
			if bool(tag[2]):
				row["arc_damage"] = snappedf(float(row["arc_damage"]) + damage, 0.01)
				row["arc_hits"] = int(row["arc_hits"]) + 1
			else:
				_add(row["damage"], String(tag[1]), damage)
				_add(row["hits"], String(tag[1]), 1.0))
	var seconds := float(_flag("seconds", "180"))
	var started := -1
	var last_tick := -1
	var frames := 0
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
		if seconds > 0.0 and _seconds_run > seconds:
			break
	_report()
	quit(0)
