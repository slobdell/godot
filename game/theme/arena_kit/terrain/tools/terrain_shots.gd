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
##
## Round 12 (arena, A1): `--looks=r10,a_body,...` (WaterLook steps) shoots the WET map once per look at every spot,
## frozen at `--freeze=<s>` of the swell so the frames of a pair show one instant, as `<arena>-<spot>-<look>.png`;
## the dry twin is shot once. Each look's water pixels are then measured through a mask frame (the water painted
## flat magenta) and printed as `WATER_STATS {json}`: how many pixels are water, their mean sRGB luma, the share
## darker than 0.03 (what "reads black" means as a number), and how many pixels differ from the first look, in the
## whole frame (`changed_px`: the crowd and the show move, so never 0) and inside the mask (`changed_inside_px`: on
## a map with no water, its pits, which must show 0 -- they cannot take the wet look).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The lead's pose. Not negotiable in a frame we show him (show.mk, control's camera ruling).
const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0


var looks := PackedStringArray()
var freeze := 7.0


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
	looks = _flag("looks", "").split(",", false)
	freeze = float(_flag("freeze", "7.0"))
	var ok := true
	# The "before" frame: the map's dry twin by default; `--dry=<layout>` for a proposal whose before is a real map
	# (the Terminus canal's is the Terminus).
	arena_name_shot = arena_name
	for variant: String in [arena_name, _flag("dry", arena_name + "_dry")]:
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
	var visual: Node = null
	for node in arena.find_children("*", "", true, false):
		if node is TerrainVisual:
			visual = node
	var paired := not looks.is_empty() and variant == arena_name_shot
	for spot: Array in spots:
		var target := Vector3(spot[1], 0.0, spot[2])
		var back := Vector3(sin(yaw), 0.0, cos(yaw)) * DISTANCE_M * cos(deg_to_rad(PITCH_DEG))
		camera.global_position = target + back + Vector3.UP * DISTANCE_M * sin(deg_to_rad(PITCH_DEG))
		camera.look_at(target, Vector3.UP)
		if not paired:
			ok = await _save(out.path_join("%s-%s.png" % [variant, spot[0]])) and ok
			continue
		var images := {}
		for look: String in looks:
			if visual != null:
				visual.call("set_water_look", WaterLook.at(look), freeze)
			var path := out.path_join("%s-%s-%s.png" % [variant, spot[0], look])
			ok = await _save(path) and ok
			images[look] = Image.load_from_file(path)
		var mask: Image = null
		if visual != null:
			visual.call("set_water_mask", true)
			for frame in 8:
				await RenderingServer.frame_post_draw
			mask = root.get_viewport().get_texture().get_image()
			visual.call("set_water_mask", false)
			visual.call("set_water_look", {}, -1.0)
		for look: String in looks:
			print("WATER_STATS " + JSON.stringify(_stats(variant, String(spot[0]), look, images[look], images[looks[0]], mask)))
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


var arena_name_shot := ""


## One look's water, measured inside the mask (pure magenta in the mask frame). Luma is Rec. 709 on the sRGB values
## the lead sees; `black_share` is the fraction of water pixels under 0.03. `changed_px` counts pixels anywhere in
## the frame that differ from the first look's frame by more than 2/255 in any channel.
func _stats(variant: String, spot: String, look: String, image: Image, first: Image, mask: Image) -> Dictionary:
	var water := 0
	var luma := 0.0
	var black := 0
	var mean := Vector3.ZERO
	var changed := 0
	var changed_inside := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(0, height, 2):
		for x in range(0, width, 2):
			var c := image.get_pixel(x, y)
			if first != null and first != image:
				var f := first.get_pixel(x, y)
				if absf(c.r - f.r) > 2.0 / 255.0 or absf(c.g - f.g) > 2.0 / 255.0 or absf(c.b - f.b) > 2.0 / 255.0:
					changed += 1
			if mask == null:
				continue
			# The mask frame goes through the tonemapper and glow like any frame, so pure magenta does not come back
			# as (1, 0, 1): a water pixel is one the mask turned strongly magenta relative to the first look.
			var m := mask.get_pixel(x, y)
			var f0 := first.get_pixel(x, y) if first != null else c
			if m.r - m.g > 0.35 and m.b - m.g > 0.35 and (absf(m.r - f0.r) + absf(m.g - f0.g) + absf(m.b - f0.b)) > 0.3:
				if absf(c.r - f0.r) > 2.0 / 255.0 or absf(c.g - f0.g) > 2.0 / 255.0 or absf(c.b - f0.b) > 2.0 / 255.0:
					changed_inside += 1
				water += 1
				var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				luma += l
				mean += Vector3(c.r, c.g, c.b)
				if l < 0.03:
					black += 1
	var n := maxf(1.0, float(water))
	return {"arena": variant, "spot": spot, "look": look, "water_px": water * 4, "mean_luma": snappedf(luma / n, 0.0001),
			"black_share": snappedf(float(black) / n, 0.001),
			"mean_rgb": [snappedf(mean.x / n, 0.001), snappedf(mean.y / n, 0.001), snappedf(mean.z / n, 0.001)],
			"changed_px": changed * 4, "changed_inside_px": changed_inside * 4}


func _save(path: String) -> bool:
	for frame in 8:
		await RenderingServer.frame_post_draw
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	print("TERRAIN_SHOT %s %s" % [path, "ok" if err == OK else error_string(err)])
	return err == OK
