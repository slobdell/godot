extends SceneTree
## Arena X4: boots the REAL match runner (main.tscn with the flags after `--`, e.g. `--match --elimination --control
## --green-faction=condemned --rust-faction=condemned --arena=yard --seed=3`) and measures what the ARENA did to the
## fight, without touching the simulation (it only listens to K2 events and reads positions once a second):
##   engagement_ranges   muzzle-to-impact distance of every round that hit a vehicle (m)
##   flank_share         unit-seconds spent in the outer quarters (|x| > FLANK_X) while in the contested field
##   hidden_share        unit-seconds not visible to the enemy (Match.is_visible_to), contested field only
##   first_hit_seconds   when the first round hit a vehicle
## Prints `ARENA_PROBE <json>` next to the runner's own MATCH_RESULT. Run by tools/arena_series.py.

const FLANK_X := 60.0
const FIELD_Z := 84.0

var game_match: Match
var muzzles := {}  # projectile_id → muzzle Vector3
var ranges: Array = []
var first_hit_tick := -1
var unit_seconds := 0
var flank_seconds := 0
var hidden_seconds := 0
var reported := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	game_match = main.get("game_match")
	game_match.weapon_fired.connect(_on_fired)
	game_match.projectile_impact.connect(_on_impact)
	game_match.finished.connect(_on_finished)
	physics_frame.connect(_sample)


func _on_fired(event: Dictionary) -> void:
	var muzzle: Array = event["muzzle"]
	muzzles[int(event["projectile_id"])] = Vector3(muzzle[0], muzzle[1], muzzle[2])


func _on_impact(event: Dictionary) -> void:
	var id := int(event.get("projectile_id", -1))
	var from: Variant = muzzles.get(id)
	muzzles.erase(id)
	if not event.has("target") or from == null:
		return
	var at: Array = event["position"]
	ranges.append(snappedf((from as Vector3).distance_to(Vector3(at[0], at[1], at[2])), 0.1))
	if first_hit_tick < 0:
		first_hit_tick = int(event["tick"])


func _sample() -> void:
	if game_match == null or game_match.tick % 60 != 0:
		return
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive() or absf(tank.global_position.z) > FIELD_Z:
			continue
		unit_seconds += 1
		if absf(tank.global_position.x) > FLANK_X:
			flank_seconds += 1
		if not game_match.is_visible_to(1 - tank.team, tank):
			hidden_seconds += 1


func _on_finished(result: Dictionary) -> void:
	if reported:
		return
	reported = true
	ranges.sort()
	var median: float = ranges[ranges.size() / 2] if not ranges.is_empty() else 0.0
	var mean := 0.0
	for r: float in ranges:
		mean += r / ranges.size()
	print("ARENA_PROBE " + JSON.stringify({
		"arena": String(Arena.active.get("name", "")), "winner": result["winner"], "reason": result["reason"],
		"swap_bases": Match.swap_bases, "sim_seconds": result.get("sim_seconds", 0.0),
		"hits": ranges.size(), "range_median_m": median, "range_mean_m": snappedf(mean, 0.1),
		"range_p90_m": ranges[int(ranges.size() * 0.9)] if not ranges.is_empty() else 0.0,
		"first_hit_seconds": snappedf(first_hit_tick / 60.0, 0.1) if first_hit_tick >= 0 else -1.0,
		"unit_seconds": unit_seconds,
		"flank_share": snappedf(float(flank_seconds) / maxi(unit_seconds, 1), 0.001),
		"hidden_share": snappedf(float(hidden_seconds) / maxi(unit_seconds, 1), 0.001)}))
