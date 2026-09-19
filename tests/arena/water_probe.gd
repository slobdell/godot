extends SceneTree
## `make water-probe` (arena, round 7): **does a hole in the navmesh actually give us water?**
##
## The lead wants water and pits — *"elements that units could not cross but they could still fire over. Useful for
## setting up kill zones."* The claimed mechanism is that this is geometry rather than a new mechanic: navigation is
## baked from collision shapes in the `navigation_source` group, while line of sight is a physics ray at
## `Perception.EYE_HEIGHT` (1.3 m). So ground that is absent from the bake is unwalkable, and carries nothing to
## block a ray.
##
## That is a claim about two systems that were never designed together, and the whole water/bridge item rests on
## it, so it gets measured before anything is built on it. Three questions, and the third is the one that bites:
##
##   1. NAVMESH  is the carved footprint really off the mesh, and does a route around it get longer?
##   2. SIGHT    does an eye-level ray cross the gap unobstructed?
##   3. HULLS    a navmesh hole tells PATHING to go round. It does not stop a vehicle that is shoved, or one whose
##               local avoidance drifts it over the edge. Without something physical at the rim a unit ends up in
##               the water — or falls out of the world, since the carved ground is not there to stand on.
##
## The rim under test is a **low lip**: taller than a hull can climb, shorter than the 1.3 m eye line. The arena kit
## already has exactly these semantics in `barricade` ("stops a hull, not a shell or a sightline"), so if this
## works, water is two existing ideas rather than a new one.
##
##   .tools/.../godot --headless --path . --script res://tests/arena/water_probe.gd -- --json=build/water.json

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The test channel: a band of water running east-west across the middle of the southern half.
const CHANNEL_Z := 40.0
const CHANNEL_DEPTH := 26.0
const CHANNEL_HALF_WIDTH := 116.0
## The rim. 0.9 m matches ArenaKit's barricade, which is documented as stopping a hull but not an eye or a gun.
const RIM_HEIGHT := 0.9
const RIM_THICKNESS := 1.2
## The bridge deck's width. The rim must be CUT here, or the lip that keeps hulls out of the water also keeps them
## off the bridge -- which the first run of this probe did, reporting a crossing that was blocked by its own
## safety rail. A bridge is a hole in the water AND a hole in the rim.
const BRIDGE_WIDTH := 14.0
## How long a tank gets to try to cross.
const DRIVE_SECONDS := 14.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var bridge := OS.get_cmdline_user_args().has("--bridge")
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "foundry"
	# The stock Ground is one 320 x 320 slab, so carving means REPLACING it with the floor minus the footprint.
	var ground: StaticBody3D = arena.get_node("Ground")
	(ground.get_node("Collision") as CollisionShape3D).disabled = true
	arena.add_child(_carved_ground(bridge))
	arena.add_child(_rim(bridge))
	root.add_child(arena)
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(1, 0.0)
	game_match.elimination = true
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame

	# 1. NAVMESH: the middle of the channel should be off the mesh, and the crossing should have to go round.
	var map := arena.get_world_3d().navigation_map
	# Probe the water BESIDE the bridge, not on the centre line: with a bridge at x = 0 the centre is decking.
	var mid := Vector3(40.0, 0.0, CHANNEL_Z)
	var off_mesh := NavigationServer3D.map_get_closest_point(map, mid).distance_to(mid)
	var south := Vector3(0.0, 0.0, CHANNEL_Z + CHANNEL_DEPTH / 2.0 + 10.0)
	var north := Vector3(0.0, 0.0, CHANNEL_Z - CHANNEL_DEPTH / 2.0 - 10.0)
	var route := Pathing.find_path(arena, south, north)
	var route_m := _path_length(route)
	var straight := south.distance_to(north)
	# An unreachable goal yields a path to the CLOSEST REACHABLE POINT, which is a non-empty path that looks like
	# success: the first run of this probe reported `reachable: true` with an 8 m route for a 46 m trip across a
	# channel that spans the whole arena. Reachability is "the path ENDS at the goal", never "a path came back".
	var arrives := route.size() >= 2 and route[route.size() - 1].distance_to(north) < 4.0

	# 2. SIGHT: an eye-level ray straight across the channel.
	var space := arena.get_world_3d().direct_space_state
	var eye := func(from: Vector3, to: Vector3) -> bool:
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Perception.WORLD_MASK)).is_empty()
	var sees_across: bool = eye.call(south + Vector3.UP * Perception.EYE_HEIGHT, north + Vector3.UP * Perception.EYE_HEIGHT)

	# 3. HULLS: drive straight at it and see where the vehicle ends up.
	var tank := game_match.spawn_tank("Crosser", 0, Match.Team.GREEN, "tank")
	tank.global_position = south
	if tank.has_method("reset_physics_interpolation"):
		tank.reset_physics_interpolation()
	var controller := OrderController.new()
	controller.name = "Orders_Crosser"
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	game_match.brains.add_child(controller)
	# `direct` skips the navmesh: this is deliberately the worst case, a unit driving AT the water with no pathing
	# to save it. If the rim holds here it holds when avoidance nudges someone over the edge.
	controller.set_orders({"type": "move_to", "x": north.x, "z": north.z, "direct": true}, {"type": "hold_fire"})
	var lowest := tank.global_position.y
	for frame in int(SimClock.TICK_RATE * DRIVE_SECONDS):
		await physics_frame
		lowest = minf(lowest, tank.global_position.y)
	var ended := tank.global_position
	var crossed := ended.z < CHANNEL_Z - CHANNEL_DEPTH / 2.0

	var out := {
		"bridge": bridge,
		"channel_z": CHANNEL_Z, "channel_depth_m": CHANNEL_DEPTH,
		"navmesh_gap": {"centre_off_mesh_m": snappedf(off_mesh, 0.1), "carved": off_mesh > 2.0},
		"route": {"straight_m": snappedf(straight, 0.1), "navmesh_m": snappedf(route_m, 0.1),
				"detour": snappedf(route_m / maxf(1.0, straight), 0.01), "reachable": arrives,
				"path_ends_short_by_m": snappedf(route[route.size() - 1].distance_to(north) if route.size() > 0 else -1.0, 0.1)},
		"sight": {"eye_ray_crosses": sees_across},
		"hull": {"ended_at": [snappedf(ended.x, 0.1), snappedf(ended.y, 0.1), snappedf(ended.z, 0.1)],
				"lowest_y": snappedf(lowest, 0.1), "crossed": crossed, "fell_through_world": lowest < -5.0},
	}
	print("WATER %s" % JSON.stringify(out))
	var path := _flag("json", "")
	if path != "":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(out, "\t") + "\n")
			file.close()
	quit(0)


## The arena floor with the channel cut out of it: two slabs, north and south of the water. With `--bridge`, a
## strip of floor is restored across the middle, which is all a bridge is.
func _carved_ground(bridge: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CarvedGround"
	body.add_to_group("navigation_source")
	var half := 160.0
	var near_edge := CHANNEL_Z - CHANNEL_DEPTH / 2.0
	var far_edge := CHANNEL_Z + CHANNEL_DEPTH / 2.0
	_slab(body, Vector3(0.0, -0.5, (near_edge - half) / 2.0), Vector3(half * 2.0, 1.0, near_edge + half))
	_slab(body, Vector3(0.0, -0.5, (far_edge + half) / 2.0), Vector3(half * 2.0, 1.0, half - far_edge))
	if bridge:
		_slab(body, Vector3(0.0, -0.5, CHANNEL_Z), Vector3(BRIDGE_WIDTH, 1.0, CHANNEL_DEPTH))
	return body


## The lip that stops a hull. NOT in `navigation_source`, so the bake never sees it: its whole job is physical.
func _rim(bridge: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "WaterRim"
	for side: float in [-1.0, 1.0]:
		var z: float = CHANNEL_Z + side * (CHANNEL_DEPTH / 2.0 + RIM_THICKNESS / 2.0)
		if not bridge:
			_slab(body, Vector3(0.0, RIM_HEIGHT / 2.0, z), Vector3(CHANNEL_HALF_WIDTH * 2.0, RIM_HEIGHT, RIM_THICKNESS))
			continue
		var run := (CHANNEL_HALF_WIDTH * 2.0 - BRIDGE_WIDTH) / 2.0
		for side_x: float in [-1.0, 1.0]:
			_slab(body, Vector3(side_x * (BRIDGE_WIDTH / 2.0 + run / 2.0), RIM_HEIGHT / 2.0, z),
					Vector3(run, RIM_HEIGHT, RIM_THICKNESS))
	return body


func _slab(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	if size.x <= 0.0 or size.z <= 0.0:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
