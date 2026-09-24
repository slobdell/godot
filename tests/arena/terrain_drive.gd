extends SceneTree
## `make terrain-drive` (arena, round 11, A1.4): **a squad ordered over a bridge, on the default path, as he would.**
## The lead: *"I haven't seen any bridges or pits that I've asked for."* Publishing the Crossing and the Sumps puts
## them in front of him; this is the check that what he meets there WORKS before he meets it — a bridge nobody has
## watched a tank cross is not a bridge that works (the brief's own words).
##
## One player squad, ordered through control's `Orders` exactly as a right-click would (`source: player`), leg by leg
## to points ACROSS the terrain from its spawn, so the planner has to find the bridge or the causeway itself. Nobody
## fights. Per leg: arrivals, seconds, wall contacts by cause (`WallContact`, nav's instrument: rims and rails are
## colliders, so a hull shoved at the water shows up here), and **whether any hull was ever inside a carved
## footprint** (it must never be: the rim and the pan exist so it cannot).
##
## `--shots=<abs dir>` (needs a display) also saves a frame at the LEAD'S POSE (21 deg, FOV 35, 49 m) on the squad's
## centroid every `--shot-every` seconds: the frames for his page. Prints `TERRAIN_DRIVE_LEG <json>` per leg and
## `TERRAIN_DRIVE <json>` with `"pass"` at the end; exits 1 only if it could not run.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const ROSTERS := {
	"mixed": ["tank", "ifv", "scout", "lancer", "artillery", "ifv"],
	"rigs": ["gang_tank", "gang_tank", "gang_tank", "gang_tank"],
}
## Each course starts from the green spawn (z ~ +100) and ends somewhere the planner can only reach over the terrain.
const COURSES := {
	# The west landing is across the west reach: the only dry ways are the two bridges. Then back to the east of the
	# neck on his own side, which is the same bridge again.
	"crossing": [{"name": "the west landing", "to": [-76.0, -22.0]}, {"name": "home, east of the neck", "to": [60.0, 40.0]}],
	# The far causeway objective is beyond the west pit; then up to the pit's lip to see hulls stop at the kerb.
	"sumps": [{"name": "the far causeway", "to": [-52.0, -22.0]}, {"name": "the west pit's lip", "to": [-40.0, 32.0]}],
	# The far quay is across the canal: over the lock (short, watched) or a swing bridge. Then back to his own east
	# quay, which is the canal again.
	"locks": [{"name": "the far quay", "to": [-72.0, -24.0]}, {"name": "home, the east quay", "to": [70.0, 20.0]}],
	"terminus_canal": [{"name": "over the avenue bridge", "to": [0.0, -40.0]}, {"name": "back over the west bridge", "to": [-70.0, 60.0]}],
}
const ARRIVED_M := 7.0
const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0

var game_match: Match
var orders: Orders
var units: Array[Tank] = []
var legs: Array = []
var leg_index := -1
var leg_started_tick := 0
var leg_goal := {}
var leg_done := {}
var leg_contacts_before := {}
var leg_in_hole := {}      # unit -> ticks inside a carved footprint this leg
var leg_results: Array = []
var time_per_leg := 120.0
var squad_kind := "mixed"
var shots_dir := ""
var shot_every := 6.0
var next_shot_s := 0.0
var camera: Camera3D
var shooting := false
var shot_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var arena_name := _flag("arena", "crossing")
	time_per_leg = float(_flag("leg-time", "120"))
	squad_kind = _flag("squad", "mixed")
	shots_dir = _flag("shots", "")
	shot_every = float(_flag("shot-every", "6"))
	if not ROSTERS.has(squad_kind) or not COURSES.has(arena_name):
		push_error("terrain-drive: --squad in %s, --arena in %s" % [ROSTERS.keys(), COURSES.keys()])
		quit(1)
		return
	legs = COURSES[arena_name]
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = arena_name
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(int(_flag("seed", "1")), 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	if String(Arena.active.get("name", "")) != arena_name or (Arena.active.get("terrain", []) as Array).is_empty():
		push_error("terrain-drive control FAILED: asked for %s, built %s with %d terrain pieces" % [arena_name,
				Arena.active.get("name", "?"), (Arena.active.get("terrain", []) as Array).size()])
		quit(1)
		return
	var roster: Array = ROSTERS[squad_kind]
	var error := game_match.load_doctrine(Match.Team.GREEN, {"name": "TerrainDrive",
			"squads": [{"name": "S0", "units": roster.map(func(unit: String) -> Dictionary: return {"unit": unit})}]})
	if error != "":
		push_error("terrain-drive: " + error)
		quit(1)
		return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.game_match = game_match
	executor.orders = orders
	root.add_child(executor)
	for tank: Tank in game_match.tanks.get_children():
		units.append(tank)
		for label in tank.find_children("*", "Label3D", true, false):
			(label as Label3D).visible = false
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
		camera = Camera3D.new()
		root.add_child(camera)
		camera.current = true
		camera.fov = FOV_DEG
		camera.far = 900.0
	for frame in SimClock.TICK_RATE:
		await physics_frame
	WallContact.reset()
	print("TERRAIN_DRIVE_CONTROL arena %s squad %s units %d (%s) terrain %d" % [Arena.active.get("name", "?"), squad_kind,
			units.size(), ", ".join(units.map(func(t: Tank) -> String: return t.unit_id)), (Arena.active["terrain"] as Array).size()])
	_next_leg()
	physics_frame.connect(_sample)


func _next_leg() -> void:
	leg_index += 1
	leg_goal = {}
	leg_done = {}
	leg_in_hole = {}
	leg_contacts_before = WallContact.by_cause.duplicate()
	leg_started_tick = game_match.tick
	next_shot_s = 0.0
	if leg_index >= legs.size():
		return
	var names: Array = units.map(func(t: Tank) -> String: return String(t.name))
	var result := orders.issue(UnitCommand.make(names, "move", {"to": legs[leg_index]["to"], "source": "player"}))
	if result != "":
		push_error("terrain-drive: " + result)


## Is a hull's centre inside a water or pit footprint (and not on a deck)? `Arena.contains` already answers exactly
## this for orders, so the probe asks the same function the game does.
func _in_hole(tank: Tank) -> bool:
	return not Arena.contains(tank.global_position)


func _sample() -> void:
	var elapsed := float(game_match.tick - leg_started_tick) / float(SimClock.TICK_RATE)
	for tank in units:
		var key := String(tank.name)
		if _in_hole(tank):
			leg_in_hole[key] = int(leg_in_hole.get(key, 0)) + 1
		if leg_done.has(key):
			continue
		var g: Variant = orders.goal_position(key)
		if g != null:
			leg_goal[key] = g
		elif leg_goal.has(key) and orders.is_idle(key):
			leg_done[key] = elapsed
	var trace := _flag("trace", "")
	if trace != "" and game_match.tick % SimClock.TICK_RATE == 0:
		for tank in units:
			if trace == "all" or tank.unit_id == trace:
				var reading := Movement.state(tank)
				print("TERRAIN_DRIVE_TRACE %s leg %d t %.0f at (%.1f, %.1f) yaw %.0f speed %.1f phase %s blocked_by %s" % [tank.unit_id, leg_index, elapsed,
						tank.global_position.x, tank.global_position.z, rad_to_deg(tank.rotation.y), tank.speed(),
						reading.get("phase", "?"), reading.get("blocked_by", "")])
				if _flag("trace-full", "") == str(int(elapsed)):
					print("TERRAIN_DRIVE_STATE %s %s" % [tank.unit_id, JSON.stringify(reading)])
	if camera != null and not shooting and elapsed >= next_shot_s:
		next_shot_s += shot_every
		_shoot(elapsed)
	if leg_done.size() == units.size() or elapsed >= time_per_leg:
		_close_leg(elapsed)
		_next_leg()
		if leg_index >= legs.size():
			_report()


func _shoot(elapsed: float) -> void:
	shooting = true
	var centre := Vector3.ZERO
	for tank in units:
		centre += tank.global_position
	centre /= float(units.size())
	centre.y = 0.0
	# From the south-east of the squad's centroid looking north-west at his pitch: the green player's side of the map
	# looks toward -Z, so the camera sits on +Z like his.
	var back := Vector3(0.0, 0.0, 1.0) * DISTANCE_M * cos(deg_to_rad(PITCH_DEG))
	camera.global_position = centre + back + Vector3.UP * DISTANCE_M * sin(deg_to_rad(PITCH_DEG))
	camera.look_at(centre, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := shots_dir.path_join("%s-%s-leg%d-%03ds.png" % [Arena.active.get("name", "?"), squad_kind, leg_index, int(elapsed)])
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	shot_count += 1
	print("TERRAIN_DRIVE_SHOT %s %s" % [path, "ok" if err == OK else error_string(err)])
	shooting = false


func _close_leg(elapsed: float) -> void:
	var arrived := 0
	var misses: Array = []
	for tank in units:
		var key := String(tank.name)
		var gap := _flat(tank.global_position, leg_goal[key]) if leg_goal.has(key) else -1.0
		if leg_done.has(key) and gap >= 0.0 and gap <= ARRIVED_M:
			arrived += 1
		else:
			var reading := Movement.state(tank)
			misses.append({"unit": key, "id": tank.unit_id, "gap_m": snappedf(gap, 0.1), "completed": leg_done.has(key),
					"phase": String(reading.get("phase", "?")), "blocked_by": String(reading.get("blocked_by", "")),
					"reachable": bool(reading.get("reachable", true)), "goal_off_mesh_m": snappedf(float(reading.get("goal_gap_m", 0.0)), 0.1),
					"goal": [snappedf(leg_goal[key].x, 0.1), snappedf(leg_goal[key].z, 0.1)] if leg_goal.has(key) else null,
					"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)]})
	var contacts := {}
	for cause: String in WallContact.by_cause:
		var n := int(WallContact.by_cause[cause]) - int(leg_contacts_before.get(cause, 0))
		if n > 0:
			contacts[cause] = n
	var times: Array = leg_done.values()
	times.sort()
	var row := {"leg": legs[leg_index]["name"], "to": legs[leg_index]["to"], "seconds": snappedf(elapsed, 0.1),
			"arrived": arrived, "units": units.size(), "last_done_s": snappedf(times[-1], 0.1) if not times.is_empty() else -1.0,
			"contact_unit_ticks": contacts, "in_hole_unit_ticks": leg_in_hole, "misses": misses}
	leg_results.append(row)
	print("TERRAIN_DRIVE_LEG %s" % JSON.stringify(row))


func _report() -> void:
	physics_frame.disconnect(_sample)
	var arrived_all := leg_results.all(func(row: Dictionary) -> bool: return int(row["arrived"]) == int(row["units"]))
	var dry := leg_results.all(func(row: Dictionary) -> bool: return (row["in_hole_unit_ticks"] as Dictionary).is_empty())
	var out := {"arena": String(Arena.active.get("name", "?")), "squad": squad_kind, "units": units.size(),
			"legs": leg_results.size(), "arrived_every_leg": arrived_all, "never_in_a_hole": dry,
			"wall_contacts": WallContact.report(), "shots": shot_count, "pass": arrived_all and dry}
	print("TERRAIN_DRIVE %s" % JSON.stringify(out))
	quit(0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
