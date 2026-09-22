extends SceneTree
## `make terrain-shots` (terrain, round 10): a terrain map at the LEAD'S POSE (21 deg pitch, FOV 35, 49 m), aimed at
## each named spot, beside the SAME frame of its dry twin (`<arena>_dry`, `terrain: []`) -- every visual claim is a
## pair with one variable moved (round 10's standing rule). Plus a straight-down overview of the whole arena.
##
## A few hulls stand on the bank and on the bridge for scale (brains off; they are furniture here), and their
## positions are the SAME in both frames of a pair.
##
##   godot --path . --resolution 1920x1080 --script res://game/theme/arena_kit/terrain/tools/terrain_shots.gd -- \
##     --arena=crossing --out=<abs dir> --spots=bridge:-92:14,neck:0:20 [--hulls=x:z:yaw,...] [--yaw=0]
## Prints TERRAIN_SHOT <path> per frame and TERRAIN_SHOTS_DONE ok=<bool>.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The lead's pose. Not negotiable in a frame we show him (show.mk, control's camera ruling).
const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var arena_name := _flag("arena", "crossing")
	var out := _flag("out", "")
	if out == "":
		push_error("terrain_shots: --out=<abs dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var spots := _parse(_flag("spots", "centre:0:0"))
	# Hulls have no name field: "x:z:yaw". Parsed as "name:x:z" they came out one field shifted (the first frames).
	var hull_text := _flag("hulls", "")
	var hulls := _parse("hull:" + hull_text.replace(",", ",hull:")) if hull_text != "" else []
	var yaw := deg_to_rad(float(_flag("yaw", "0")))
	var ok := true
	for variant: String in [arena_name, arena_name + "_dry"]:
		if not ResourceLoader.exists("res://arenas/%s.json" % variant) and not FileAccess.file_exists("res://arenas/%s.json" % variant):
			print("TERRAIN_SHOT missing layout %s" % variant)
			ok = false
			continue
		ok = await _shoot(variant, out, spots, hulls, yaw) and ok
	print("TERRAIN_SHOTS_DONE ok=%s" % ok)
	quit(0 if ok else 1)


## "name:x:z[:extra],..." -> [[name, x, z, extra], ...]
func _parse(text: String) -> Array:
	var outv: Array = []
	for part in text.split(",", false):
		var bits := part.split(":")
		if bits.size() >= 3:
			outv.append([bits[0], float(bits[1]), float(bits[2]), float(bits[3]) if bits.size() > 3 else 0.0])
	return outv


func _shoot(variant: String, out: String, spots: Array, hulls: Array, yaw: float) -> bool:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = variant
	root.add_child(arena)
	if Arena.active.get("name", "") != variant:
		# The loader falls back to the default layout on any problem and says so only in an error line: a frame of
		# the wrong map is worse than no frame.
		print("TERRAIN_SHOT %s did not load (got %s)" % [variant, Arena.active.get("name", "?")])
		arena.queue_free()
		return false
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(1, 0.0)
	var index := 0
	for hull: Array in hulls:
		var tank := game_match.spawn_tank("Scale%d" % index, 0, Match.Team.GREEN if index % 2 == 0 else Match.Team.RUST,
				["tank", "ifv", "scout"][index % 3])
		# Through `Tank.place()` (combat's settle path), not a bare position write: the first frames of this tool
		# showed hulls somewhere other than where they were put.
		tank.place(Vector3(hull[1], 0.0, hull[2]), deg_to_rad(float(hull[3])))
		# The debug nameplates ("Scale0 300 +150") are for a developer; these frames are for the lead.
		for label in tank.find_children("*", "Label3D", true, false):
			(label as Label3D).visible = false
		index += 1
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = FOV_DEG
	camera.far = 900.0
	# Let the arena build, the theme fill its slots and the shaders compile before the first frame.
	for frame in 90:
		await process_frame
	var ok := true
	for spot: Array in spots:
		var target := Vector3(spot[1], 0.0, spot[2])
		var back := Vector3(sin(yaw), 0.0, cos(yaw)) * DISTANCE_M * cos(deg_to_rad(PITCH_DEG))
		camera.global_position = target + back + Vector3.UP * DISTANCE_M * sin(deg_to_rad(PITCH_DEG))
		camera.look_at(target, Vector3.UP)
		ok = await _save(out.path_join("%s-%s.png" % [variant, spot[0]])) and ok
	# The whole arena from straight above, orthographic: the map as a plan.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 300.0
	camera.global_position = Vector3(0.0, 250.0, 0.001)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	ok = await _save(out.path_join("%s-overview.png" % variant)) and ok
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.queue_free()
	game_match.queue_free()
	arena.queue_free()
	for frame in 10:
		await process_frame
	return ok


func _save(path: String) -> bool:
	for frame in 8:
		await RenderingServer.frame_post_draw
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	print("TERRAIN_SHOT %s %s" % [path, "ok" if err == OK else error_string(err)])
	return err == OK
