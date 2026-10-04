extends SceneTree
## Round 17 (brains T1): what a decision lever does to DRIVING, for the lead's page (the orchestrator's ask: half-rate
## steering is exactly a unit crossing the map). Boots the real match (main.tscn with the flags after `--`, headless,
## fixed fps), reads every hull's `Movement.state()` every physics tick -- the reading yard's tests/arena/contact_probe.gd
## and tests/nav/test_nav_back_and_fill.gd count -- and at the end prints one line per match:
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/nav/lever_drive_probe.gd -- --match --elimination \
##       --arena=sumps --green-faction=gangs --rust-faction=condemned --budget=5200 --time-limit=180 --seed=1 \
##       --green-brain=l17s --rust-brain=l17s --probe-tag=l17s
##
## LEVER_DRIVE {"arena", "tag", "seed", "ticks", "minutes", "contacts" (wall-contact ticks by long|short x cause x
## driver), "long_plant_kturn", "long_steer", "all", "wedged_units", "unstick_fires", "kturns", "kturn_aborted",
## "units_lost"}. Measurement only.

const LONG_M := 9.0

var _match: Node = null
var _counts := {}
var _ticks := 0
var _tag := ""
var _seed := ""
var _arena := ""
var _limit_ticks := 0
var _reported := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_tag = flags.text("probe-tag", "")
	_seed = flags.text("seed", "1")
	_limit_ticks = int(float(flags.text("time-limit", "180")) * SimClock.TICK_RATE) - 10
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _find_match(node: Node) -> Node:
	if node is Match:
		return node
	for child in node.get_children():
		var found := _find_match(child)
		if found != null:
			return found
	return null


func _tick() -> void:
	if _match == null:
		_match = _find_match(root)
		if _match == null:
			return
		_arena = String(Arena.active.get("name", ""))
	_ticks += 1
	var tanks: Node = _match.get("tanks")
	if tanks != null:
		for tank: Node in tanks.get_children():
			if not tank is Tank or not is_instance_valid(tank):
				continue
			var reading := Movement.state(tank)
			if not bool(reading.get("wall_contact", false)):
				continue
			var long := float(Movement.hull_box((tank as Tank).unit_id)[2]) >= LONG_M
			var key := "%s|%s|%s" % ["long" if long else "short", String(reading.get("wall_contact_cause", "?")),
					String(reading.get("wall_contact_driver", "?"))]
			_counts[key] = int(_counts.get(key, 0)) + 1
	if _ticks >= _limit_ticks:
		_report()


func _finalize() -> void:
	if not _reported:
		_report()


func _sum(prefix: String) -> int:
	var total := 0
	for key: String in _counts:
		if prefix == "" or key.begins_with(prefix):
			total += int(_counts[key])
	return total


func _report() -> void:
	_reported = true
	if physics_frame.is_connected(_tick):
		physics_frame.disconnect(_tick)
	var lost: Variant = _match.get("units_lost") if _match != null else null
	var out := {"arena": _arena, "tag": _tag, "seed": _seed, "ticks": _ticks,
		"minutes": snappedf(float(_ticks) / SimClock.TICK_RATE / 60.0, 0.001), "contacts": _counts,
		"long_plant_kturn": int(_counts.get("long|plant|kturn", 0)), "long_steer": _sum("long|steer"), "all": _sum(""),
		"wedged_units": Movement.wedged_units, "unstick_fires": Movement.unstick_fires, "kturns": Movement.kturns,
		"kturn_aborted": Movement.kturn_aborted, "units_lost": lost}
	print("LEVER_DRIVE " + JSON.stringify(out))
