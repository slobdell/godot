extends SceneTree
## Slice a model along an axis and print, per slice, how much geometry is there and how tall it stands — the
## measurement behind an authored cut box (FactionArt.GUN_CUTS, TRAILER_CUTS). A truck's profile shows the cab as a
## tall block at the front, a low notch over the drive axles (the fifth wheel), then the trailer.
##   godot --headless --path . --script res://game/theme/gallery/mesh_profile.gd -- <in.glb|res://…> [--axis=z] [--slices=36] [--box=x0,y0,z0,x1,y1,z1]
## `make assets-profile IN=path.glb [AXIS=z SLICES=36 BOX=...]`. Triangles are counted by centroid, in the model's
## own space (the space FactionArt's cut boxes are written in).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: mesh_profile.gd -- <model> [--axis=z] [--slices=36] [--box=x0,y0,z0,x1,y1,z1]")
		quit(2)
		return
	var path := args[0]
	var model: Node3D = null
	if path.begins_with("res://") and path.ends_with(".tscn"):
		var scene := load(path) as PackedScene
		model = scene.instantiate() as Node3D if scene != null else null
	else:
		model = AssetIO.load_glb(path)
	if model == null:
		push_error("could not load %s" % path)
		quit(1)
		return
	root.add_child(model)
	var axis := 2
	var slices := 36
	var box := AABB()
	var have_box := false
	var render_to := ""
	for arg in args:
		if arg.begins_with("--axis="):
			axis = ["x", "y", "z"].find(arg.trim_prefix("--axis="))
		elif arg.begins_with("--slices="):
			slices = maxi(2, int(arg.trim_prefix("--slices=")))
		elif arg.begins_with("--render="):
			render_to = arg.trim_prefix("--render=")
		elif arg.begins_with("--box="):
			var n := arg.trim_prefix("--box=").split(",")
			if n.size() == 6:
				var lo := Vector3(float(n[0]), float(n[1]), float(n[2]))
				var hi := Vector3(float(n[3]), float(n[4]), float(n[5]))
				box = AABB(lo, hi - lo)
				have_box = true
	var tris := _triangles(model, model)
	if have_box and "--clip" in args:
		var kept: Array[Vector3] = []
		for centroid in tris:
			if box.has_point(centroid):
				kept.append(centroid)
		tris = kept
		print("clipped to %s" % box)
	var bounds := _bounds(model)
	var slice_range := AABB()
	for i in tris.size():
		slice_range = AABB(tris[i], Vector3.ZERO) if i == 0 else slice_range.expand(tris[i])
	print("model: %s" % path)
	print("bounds: min %v  max %v  size %v" % [bounds.position, bounds.end, bounds.size])
	print("triangles: %d%s" % [tris.size(), "  (centroids span min %v max %v)" % [slice_range.position, slice_range.end] if have_box else ""])
	var lo_a: float = slice_range.position[axis]
	var span: float = maxf(slice_range.size[axis], 0.0001)
	var counts := PackedInt32Array()
	counts.resize(slices)
	var tops := PackedFloat32Array()
	tops.resize(slices)
	var bottoms := PackedFloat32Array()
	bottoms.resize(slices)
	var widths := PackedFloat32Array()
	widths.resize(slices)
	for i in slices:
		tops[i] = -1e9
		bottoms[i] = 1e9
		widths[i] = 0.0
	var inside := 0
	for centroid in tris:
		var point: Vector3 = centroid
		var index := clampi(int((point[axis] - lo_a) / span * slices), 0, slices - 1)
		counts[index] += 1
		tops[index] = maxf(tops[index], point.y)
		bottoms[index] = minf(bottoms[index], point.y)
		widths[index] = maxf(widths[index], absf(point.x))
		if have_box and box.has_point(point):
			inside += 1
	var peak := 1
	for count in counts:
		peak = maxi(peak, count)
	print("axis %s, %d slices of %.3f m (counts by triangle centroid, y/x extents of those centroids)" % [["x", "y", "z"][axis], slices, span / slices])
	print("  %-16s %6s %6s %6s %6s  %s" % ["slice (m)", "tris", "y_min", "y_max", "|x|max", "profile"])
	for i in slices:
		var a := lo_a + span * i / slices
		var b := lo_a + span * (i + 1) / slices
		var bar := "#".repeat(int(round(40.0 * counts[i] / peak)))
		if counts[i] == 0:
			print("  %6.2f .. %6.2f %6d %6s %6s %6s  %s" % [a, b, 0, "-", "-", "-", ""])
		else:
			print("  %6.2f .. %6.2f %6d %6.2f %6.2f %6.2f  %s" % [a, b, counts[i], bottoms[i], tops[i], widths[i], bar])
	if have_box:
		print("box %s contains %d of %d triangle centroids (%.1f%%)" % [box, inside, tris.size(), 100.0 * inside / maxi(tris.size(), 1)])
	if render_to != "":
		await _render_ruled(model, bounds, axis, render_to)
	print("MESH_PROFILE_DONE")
	quit()


## An orthogonal side view whose pixels map exactly to model-space metres, ruled along `axis`: a red line at 0, long
## green ticks every 0.5 m, short ones every 0.1 m. Authoring a cut box means reading a number off the model, and a
## perspective turnaround cannot be read that way.
func _render_ruled(model: Node3D, bounds: AABB, axis: int, out_path: String) -> void:
	var span: float = bounds.size[axis] * 1.25
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# KEEP_WIDTH, so `size` is the HORIZONTAL extent and one pixel is span/width metres: the whole point of this view
	# is that a pixel can be read as a number (Godot's default KEEP_HEIGHT makes `size` vertical and the ruler lies).
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = span
	camera.near = 0.01
	camera.far = 100.0
	root.add_child(camera)
	camera.current = true
	var center := bounds.get_center()
	# Looking down +X so the model's -Z (its forward) is to the RIGHT of the frame, +Z to the left.
	camera.position = center + Vector3(6.0, 0.0, 0.0)
	camera.look_at(center, Vector3.UP)
	camera.position.y += bounds.size.y * 0.15  # the ruler owns the bottom strip; lift the model out of it
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 1.1
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 110, 0)
	root.add_child(sun)
	for frame in 6:
		await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var width := image.get_width()
	var height := image.get_height()
	# Screen x maps to world -Z: x = width/2 - (z - center.z) / span * width ... derived from the camera basis above.
	var start := int(floor(bounds.position[axis] * 10.0))
	var stop := int(ceil(bounds.end[axis] * 10.0))
	for step in range(start, stop + 1):
		var value := step * 0.1
		var offset := (value - center.z) / span
		var x := int(round(width * 0.5 - offset * width))
		if x < 0 or x >= width:
			continue
		var major := absf(value) < 0.001
		var half := absi(step) % 5 == 0
		var color := Color(1, 0.25, 0.2) if major else (Color(0.3, 1.0, 0.4) if half else Color(0.55, 0.6, 0.7))
		var length := height if major else (int(height * 0.14) if half else int(height * 0.06))
		for y in range(height - length, height):
			image.set_pixel(x, y, color)
		if major:
			for y in range(0, height):
				image.set_pixel(x, y, color)
	image.save_png(out_path)
	print("ruled side view: %s (red = %s 0, green ticks 0.5 m, grey 0.1 m; forward -Z to the RIGHT)" % [out_path, ["x", "y", "z"][axis]])


## The union of the model's mesh AABBs in its own space. Deliberately computed here rather than through
## FactionArt.natural_bounds: touching FactionArt from a --script tool drags in GameTheme's static initialiser,
## which calls back into FactionArt before Units is resolved and prints a one-off "Nonexistent function 'roster'"
## before recovering. The slots come out correct (probed: 80 slots, the faction hulls present), but a measurement
## tool should not print an engine error it does not mean.
func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var xform := Transform3D.IDENTITY
		var node: Node = instance
		while node != null and node != model:
			if node is Node3D:
				xform = (node as Node3D).transform * xform
			node = node.get_parent()
		var box := xform * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Every triangle centroid of `node`'s meshes, in `space`'s coordinates.
func _triangles(node: Node3D, space: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var xform := Transform3D.IDENTITY
		var current: Node = instance
		while current != null and current != space:
			if current is Node3D:
				xform = (current as Node3D).transform * xform
			current = current.get_parent()
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(verts.size())
				for i in verts.size():
					indices[i] = i
			for t in range(0, indices.size() - 2, 3):
				result.append(xform * ((verts[indices[t]] + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0))
	return result
