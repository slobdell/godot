extends SceneTree
## `make slope-probe` (arena X4, round 6): **what slope can the navmesh bake over, and what slope can a vehicle
## actually climb?** Everything in the arena kit today is a box on a flat floor. Before adding sunken lanes, raised
## platforms and ramps, the brief says to find out what the engine survives -- so this measures it rather than
## guessing from the NavigationMesh defaults.
##
##   .tools/.../godot --headless --path . --script res://tests/arena/slope_probe.gd -- --json=build/slopes.json
##
## For each angle it builds a REAL arena (so the real bake settings, the real half-bake-plus-mirror, the real
## physics) with a ramp added as a navigation source before the arena enters the tree, and asks two questions that
## are easy to confuse:
##
##   navmesh_connects   is there a path from the foot of the ramp to the top of it? A ramp the baker rejects leaves
##                      a platform that pathing cannot reach, which reads to a player as "my units refuse to go there"
##   vehicle_climbs     does a tank ordered to the top actually gain the height? The navmesh can happily bake a
##                      slope that the vehicle physics cannot drive up, and then units grind against it forever
##
## It prints `SLOPE <json>` per angle and `SLOPE_SUMMARY <json>`. Nothing here ships: it is a measurement.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Angles to sweep, degrees. Godot's NavigationMesh defaults to a 45 deg max slope; the vehicles are the unknown.
const ANGLES := [5, 8, 10, 12, 15, 20, 25, 30]
## The ramp: this long up the slope, and spanning the WHOLE arena across.
##
## The width is 240 m for a reason the second version of this probe learned the hard way. At 24 m wide the tank
## drove round the embankment and arrived at the goal's x/z at ground level -- `climbed_m` 0.3, which reads exactly
## like "cannot climb". A vehicle that goes around is not a vehicle that cannot climb, and the two are
## indistinguishable in the output unless the geometry forbids one of them. Spanning the arena makes the ramp the
## only way from one side to the other, so `vehicle_climbs` means what it says.
const RAMP_RUN := 24.0
const RAMP_WIDTH := 240.0
## A flat shelf beyond the crest, so the ramp leads SOMEWHERE. Without it the crest is a cliff edge and the navmesh
## is eroded back from it by the agent radius, leaving no mesh at the top to path to.
const PLATFORM_RUN := 24.0
## Where the ramp sits, in the southern half so it is inside the bake's filter AABB.
const RAMP_CENTRE := Vector2(0.0, 40.0)
## How long a tank gets to climb before we call it stuck.
const CLIMB_SECONDS := 12.0

var results: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	for angle: int in ANGLES:
		results.append(await _measure(float(angle)))
		print("SLOPE %s" % JSON.stringify(results[-1]))
	var climbs: Array = results.filter(func(r: Dictionary) -> bool: return r["vehicle_climbs"])
	var bakes: Array = results.filter(func(r: Dictionary) -> bool: return r["navmesh_connects"])
	var summary := {
		"steepest_navmesh_connects": bakes.map(func(r: Dictionary) -> float: return r["angle_deg"]).max() if bakes else -1.0,
		"steepest_vehicle_climbs": climbs.map(func(r: Dictionary) -> float: return r["angle_deg"]).max() if climbs else -1.0,
		"angles": results,
	}
	print("SLOPE_SUMMARY %s" % JSON.stringify(summary))
	var path := _flag("json", "")
	if path != "":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(summary, "\t") + "\n")
			file.close()
			print("SLOPE_JSON %s" % path)
	quit(0)


## One arena with one ramp at `angle`, measured. The ramp is a rotated box: a long thin slab pitched about X, with
## its top edge `rise` above the floor. It is added BEFORE the arena enters the tree, so it is present for the bake
## rather than needing a second one.
func _measure(angle: float) -> Dictionary:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "foundry"
	var rise := RAMP_RUN * tan(deg_to_rad(angle))
	arena.add_child(_ramp(angle))
	arena.add_child(_platform(angle))
	# `--max-climb=` rebakes with a different NavigationMesh.agent_max_climb, to test WHY the slope limit is where it
	# is. The baker rasterises a slope into steps of `cell_size * tan(angle)` and rejects one taller than
	# agent_max_climb, which predicts a ceiling at atan(agent_max_climb / cell_size). Set before the arena enters the
	# tree, because Arena bakes in _ready().
	var climb := float(_flag("max-climb", "0"))
	if climb > 0.0:
		var region: NavigationRegion3D = arena.get_node("Navigation")
		region.navigation_mesh.agent_max_climb = climb
	root.add_child(arena)
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(1, 0.0)
	game_match.elimination = true
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	# Foot of the ramp and the top of it, a little in from each edge.
	var foot := Vector3(RAMP_CENTRE.x, 0.0, RAMP_CENTRE.y + RAMP_RUN / 2.0 + 4.0)
	# Sample the top well BACK from the crest, on the platform. At 1 m from the crest the point sits inside the 2 m
	# agent-radius erosion along the drop edge, so the mesh legitimately does not reach it -- and since the old
	# tolerance scaled with `rise`, that read as "the baker rejects steep slopes" and got steadily worse with angle.
	# It was the sample point, not the slope. (Confirmed by doubling agent_max_climb and seeing the "limit" not move.)
	var top := Vector3(RAMP_CENTRE.x, rise, RAMP_CENTRE.y - RAMP_RUN / 2.0 - PLATFORM_RUN / 2.0)
	# COVERAGE, not a path to one point. Pathing to a single spot near the crest measured the agent-radius erosion
	# around the test ramp's edges rather than the slope: three different ramp geometries gave three different
	# "limits" (25 deg, 25 deg, 5 deg), each of them an artifact of where the goal sat relative to an edge. Walking
	# the ramp's own centreline and asking how much of it is ON the mesh has no edges in it.
	var map := arena.get_world_3d().navigation_map
	var on_mesh := 0
	var samples := 20
	for i in range(1, samples + 1):
		var t := float(i) / float(samples + 1)
		var z := RAMP_CENTRE.y + RAMP_RUN / 2.0 - RAMP_RUN * t
		var surface := Vector3(RAMP_CENTRE.x, rise * t, z)
		if NavigationServer3D.map_get_closest_point(map, surface).distance_to(surface) < 1.0:
			on_mesh += 1
	var coverage := float(on_mesh) / float(samples)
	var path := Pathing.find_path(arena, foot, top)
	var reached := path[path.size() - 1] if path.size() > 0 else foot
	# "Connects" means the path actually gets up there, not merely that a path came back: an unreachable goal
	# yields a path to the closest reachable point, which for a rejected ramp is the floor at its foot.
	# A fixed tolerance, not one that scales with the rise: "did the path get onto the platform" is the same
	# question at every angle, and a proportional tolerance silently asks an easier one of gentle slopes.
	var connects := coverage >= 0.8

	var tank := game_match.spawn_tank("Climber", 0, Match.Team.GREEN, "tank")
	tank.global_position = foot
	if tank.has_method("reset_physics_interpolation"):
		tank.reset_physics_interpolation()
	var controller := OrderController.new()
	controller.name = "Orders_Climber"
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	game_match.brains.add_child(controller)
	controller.set_orders({"type": "move_to", "x": top.x, "z": top.z}, {"type": "hold_fire"})
	var highest := tank.global_position.y
	var nearest := 1e9
	for frame in int(SimClock.TICK_RATE * CLIMB_SECONDS):
		await physics_frame
		highest = maxf(highest, tank.global_position.y)
		nearest = minf(nearest, Vector2(tank.global_position.x - top.x, tank.global_position.z - top.z).length())
	var climbed := highest - foot.y
	var ended := tank.global_position
	arena.queue_free()
	game_match.queue_free()
	await process_frame
	return {"angle_deg": angle, "rise_m": snappedf(rise, 0.01), "navmesh_connects": connects,
			"agent_max_climb": climb if climb > 0.0 else 0.25,
			"ramp_surface_on_navmesh": snappedf(coverage, 0.05),
			"path_top_y": snappedf(reached.y, 0.01),
			"climbed_m": snappedf(climbed, 0.01), "vehicle_climbs": climbed > rise * 0.8,
			# Diagnostics: a tank that never got near the ramp foot is a probe bug, not a slope limit.
			"ended_at": [snappedf(ended.x, 0.1), snappedf(ended.y, 0.1), snappedf(ended.z, 0.1)],
			"closest_to_top_m": snappedf(nearest, 0.1), "ramp_foot_z": RAMP_CENTRE.y + RAMP_RUN / 2.0}


## The flat top the ramp delivers onto, at the ramp's full height.
func _platform(angle: float) -> StaticBody3D:
	var rise := RAMP_RUN * tan(deg_to_rad(angle))
	var body := StaticBody3D.new()
	body.name = "Platform"
	body.add_to_group("navigation_source")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var thickness := 2.0 * rise + 4.0
	box.size = Vector3(RAMP_WIDTH, thickness, PLATFORM_RUN)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(RAMP_CENTRE.x, rise - thickness / 2.0, RAMP_CENTRE.y - RAMP_RUN / 2.0 - PLATFORM_RUN / 2.0)
	return body


func _ramp(angle: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.add_to_group("navigation_source")  # the bake parses collision shapes in this group on layer 1
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var rise := RAMP_RUN * tan(deg_to_rad(angle))
	# THICK, not a slab. The first version of this probe used a 1 m slab, which at anything past ~5 deg is a BRIDGE:
	# its far end floats `rise` metres up with open ground underneath, and a tank sent to the top simply drove under
	# it and arrived at the right x/z at y = 0.3. Every angle above 5 deg read "the vehicle cannot climb it", which
	# would have been published as an engine limit. It was a probe that had built the wrong shape. Make the underside
	# stay below the floor along the whole run, so this is an embankment a vehicle has to go over.
	var thickness := 2.0 * rise + 4.0
	box.size = Vector3(RAMP_WIDTH, thickness, RAMP_RUN / cos(deg_to_rad(angle)))
	slab.shape = box
	body.add_child(slab)
	body.position = Vector3(RAMP_CENTRE.x, rise / 2.0, RAMP_CENTRE.y)
	# Pitch about X so it climbs toward -Z, then drop it by half its thickness (measured up the slope) so the TOP
	# SURFACE passes through y = 0 at the foot and y = rise at the crest.
	body.rotation.x = deg_to_rad(angle)
	body.position.y -= (thickness / 2.0) / cos(deg_to_rad(angle))
	return body
