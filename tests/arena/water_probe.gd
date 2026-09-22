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
	# Round 10 (terrain): the channel is built by the SHIPPING path -- `ArenaTerrain.build()` from a layout's
	# `terrain` list, with its rims, rails and art -- not by a floor and rim this probe assembled for itself. The
	# round-7 probe measured the idea; this one measures what a map actually gets.
	var layout: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	layout["terrain"] = _terrain(bridge)
	arena.layout_override = layout
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
	var arrives := ArenaFixture.route_arrives(arena, south, north)

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

	# 4. RAILS (round 10): a hull ON the deck driven straight at the water beside it must stay on the deck.
	var shove := {}
	if bridge:
		var sider := game_match.spawn_tank("Sider", 0, Match.Team.GREEN, "tank")
		sider.global_position = Vector3(0.0, 0.0, CHANNEL_Z)
		if sider.has_method("reset_physics_interpolation"):
			sider.reset_physics_interpolation()
		var side_orders := OrderController.new()
		side_orders.name = "Orders_Sider"
		side_orders.tank = sider
		side_orders.tanks_root = game_match.tanks
		game_match.brains.add_child(side_orders)
		side_orders.set_orders({"type": "move_to", "x": 40.0, "z": CHANNEL_Z, "direct": true}, {"type": "hold_fire"})
		var low := sider.global_position.y
		for frame in int(SimClock.TICK_RATE * 8.0):
			await physics_frame
			low = minf(low, sider.global_position.y)
		var at := sider.global_position
		shove = {"ended_at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)], "lowest_y": snappedf(low, 0.1),
				"stayed_on_deck": absf(at.x) <= BRIDGE_WIDTH / 2.0 and low > -0.5,
				"rails": arena.get_node_or_null("TerrainRails") != null and arena.get_node("TerrainRails").get_child_count() > 0}

	var out := {
		"bridge": bridge,
		"shove": shove,
		"art": arena.get_node_or_null("TerrainVisual") != null,
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


## The channel and its mirror (a layout must be point-symmetric), and with `--bridge` a deck across each.
func _terrain(bridge: bool) -> Array:
	var width := CHANNEL_HALF_WIDTH * 2.0 + 88.0  # past the wall at both ends, so nothing drives round it
	var out: Array = [
		{"kind": "water", "name": "channel", "rect": [0.0, CHANNEL_Z, width, CHANNEL_DEPTH]},
		{"kind": "water", "name": "channel (far)", "rect": [0.0, -CHANNEL_Z, width, CHANNEL_DEPTH]},
	]
	if bridge:
		out.append({"kind": "bridge", "name": "deck", "rect": [0.0, CHANNEL_Z, BRIDGE_WIDTH, CHANNEL_DEPTH + 6.0]})
		out.append({"kind": "bridge", "name": "deck (far)", "rect": [0.0, -CHANNEL_Z, BRIDGE_WIDTH, CHANNEL_DEPTH + 6.0]})
	return out


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
