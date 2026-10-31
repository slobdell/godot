extends SceneTree
## Arena X4: boots the REAL match runner (main.tscn with the flags after `--`, e.g. `--match --elimination --control
## --green-faction=condemned --rust-faction=condemned --arena=yard --seed=3`) and measures what the ARENA did to the
## fight, without touching the simulation (it only listens to K2 events and reads positions once a second):
##   engagement_ranges   muzzle-to-impact distance of every round that hit a vehicle (m)
##   flank_share         unit-seconds spent in the outer quarters (|x| > FLANK_X) while in the contested field
##   hidden_share        unit-seconds not visible to the enemy (Match.is_visible_to), contested field only
##   first_hit_seconds   when the first round hit a vehicle
##   crossed_share       (round 18, maps) of the vehicles seen, the share that ever got CROSS_M past the centre line
##                       toward the enemy's base: brains' "did a CPU element cross?" for the candidate maps
##   open_share          (round 18) unit-seconds on the layout's declared `open_ground` regions, contested field only
##   stall_share         (round 47 mapkit, Bar P guard 2) of every living crew's samples, the share whose move had made no
##                       progress for STALL_S or more (Movement.stalled_ticks): new things on the map to get stuck on
##   shots               (round 47, Bar P) rounds fired per side, {"green": n, "rust": n} (the Crossing's 6 v 358)
##   doors               (round 47, a map with blast doors) door events by kind, the booth's `door` calls by kind (its own
##                       MatchEventAdapter), every crossing of a doorway by side and the door's state at that moment (a
##                       crossing while SEALED would be a hull through a shut door: must be 0), the longest hold (s) and
##                       overstays (a crew parked in a closing doorway 6 s; manoeuvre's yield that would move it is OFF)
## Prints `ARENA_PROBE <json>` next to the runner's own MATCH_RESULT. Run by tools/arena_series.py.

const FLANK_X := 60.0
const FIELD_Z := 84.0
const CROSS_M := 20.0
const STALL_S := 2.0

var game_match: Match
var muzzles := {}  # projectile_id → muzzle Vector3
var ranges: Array = []
var first_hit_tick := -1
var unit_seconds := 0
var flank_seconds := 0
var hidden_seconds := 0
var open_seconds := 0
var home_sign := {}  # tank name -> +1 / -1: the side of the centre line it was first seen on
var crossed := {}
var reported := false
var alive_samples := 0
var stalled_samples := 0
var shots := {"green": 0, "rust": 0}
var door_events := {}
var booth_calls := {}
var door_crossings := {}  # "<side>/<state>" -> n
var _door_side := {}  # "<tank>/<door>" -> -1 / +1: which side of the slab line it was last seen on, near the doorway
var _hold_start := {}
var longest_hold_s := 0.0
var adapter: MatchEventAdapter


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
	if ArenaDoors.live != null:
		ArenaDoors.live.door_event.connect(_on_door)
		adapter = MatchEventAdapter.new(game_match, String(Arena.active.get("name", "")))


func _on_door(event: Dictionary) -> void:
	var kind := String(event["kind"])
	door_events[kind] = int(door_events.get(kind, 0)) + 1
	var id := String(event["door"])
	if kind == "held":
		_hold_start[id] = int(event["tick"])
	elif kind == "sealed" and _hold_start.has(id):
		longest_hold_s = maxf(longest_hold_s, (int(event["tick"]) - int(_hold_start[id])) / float(SimClock.TICK_RATE))
		_hold_start.erase(id)


func _on_fired(event: Dictionary) -> void:
	var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
	if shooter != null:
		shots["green" if shooter.team == 0 else "rust"] += 1
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
	if game_match == null:
		return
	if adapter != null:
		for event: Dictionary in adapter.poll():
			if String(event["type"]) == "door":
				var kind := String(event["kind"])
				booth_calls[kind] = int(booth_calls.get(kind, 0)) + 1
	if ArenaDoors.live != null and game_match.tick % 8 == 0:
		_watch_doors()
	if game_match.tick % 60 != 0:
		return
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		alive_samples += 1
		var controller := game_match.brains.get_node_or_null("Brain_" + String(tank.name)) as OrderController
		if controller == null:
			controller = game_match.brains.get_node_or_null("Orders_" + String(tank.name)) as OrderController
		if controller != null and controller.movement != null and controller.movement.stalled_ticks >= SimClock.ticks(STALL_S):
			stalled_samples += 1
		if absf(tank.global_position.z) > FIELD_Z:
			continue
		var z := tank.global_position.z
		if not home_sign.has(tank.name):
			home_sign[tank.name] = signf(z) if absf(z) > 1.0 else 1.0
		if z * float(home_sign[tank.name]) < -CROSS_M:
			crossed[tank.name] = true
		for region: Dictionary in Arena.regions_of(Arena.active, "open_ground"):
			var at: Vector3 = region["position"]
			if Vector2(tank.global_position.x - at.x, z - at.z).length() <= float(region["radius"]):
				open_seconds += 1
				break
		unit_seconds += 1
		if absf(tank.global_position.x) > FLANK_X:
			flank_seconds += 1
		if not game_match.is_visible_to(1 - tank.team, tank):
			hidden_seconds += 1


## Every 8 ticks: a living hull within its doorway's span (and 12 m of the slab line) that is on the other side of the
## line from last time crossed it, in the door's state now (open / closing / held / shut-sealed).
func _watch_doors() -> void:
	var doors := ArenaDoors.live
	for id in doors.doors.ids():
		var d := doors.doors.door(id)
		var centre: Vector2 = d["center"]
		var yaw := deg_to_rad(float(d["rotation_deg"]))
		var across := Vector2(sin(yaw), cos(yaw))  # the slab's local z in world (x, z): the crossing direction
		var along := Vector2(cos(yaw), -sin(yaw))
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			if tank == null or not tank.is_alive():
				continue
			var rel := Vector2(tank.global_position.x, tank.global_position.z) - centre
			var key := String(tank.name) + "/" + id
			if absf(rel.dot(along)) > float(d["width"]) / 2.0 + 2.0 or absf(rel.dot(across)) > 12.0:
				_door_side.erase(key)
				continue
			var side := signf(rel.dot(across))
			if side == 0.0:
				continue
			if _door_side.has(key) and float(_door_side[key]) != side:
				var state := "sealed" if doors.is_sealed(id) else ("held" if doors.is_held(id) else doors.doors.state(id, game_match.tick))
				var tag := ("green/" if tank.team == 0 else "rust/") + state
				door_crossings[tag] = int(door_crossings.get(tag, 0)) + 1
			_door_side[key] = side


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
		"first_hit_seconds": snappedf(first_hit_tick / float(SimClock.TICK_RATE), 0.1) if first_hit_tick >= 0 else -1.0,
		"unit_seconds": unit_seconds,
		"flank_share": snappedf(float(flank_seconds) / maxi(unit_seconds, 1), 0.001),
		"hidden_share": snappedf(float(hidden_seconds) / maxi(unit_seconds, 1), 0.001),
		"crossed_share": snappedf(float(crossed.size()) / maxi(home_sign.size(), 1), 0.001),
		"open_share": snappedf(float(open_seconds) / maxi(unit_seconds, 1), 0.001),
		"stall_share": snappedf(float(stalled_samples) / maxi(alive_samples, 1), 0.0001), "alive_samples": alive_samples,
		"shots": shots, "native": NativeBridge.available,
		"doors": {"events": door_events, "booth_calls": booth_calls, "crossings": door_crossings,
				"longest_hold_s": snappedf(longest_hold_s, 0.1), "open_holds": _hold_start.size()}}))
