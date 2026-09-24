extends SceneTree
## Find the DARK, FLAT, OUTWARD-FACING panels of a model -- the screen apertures a generated hull was asked for -- and
## print each one as the transform a QuadMesh needs to sit in it. The measurement behind `SyndicateAdAirship`'s
## screens, and the answer to "is the video overlaid on the intended area": the quad is placed from the mesh's own
## geometry, never from a number somebody eyeballed off a render.
##
##   godot --headless --path . --script res://game/theme/gallery/screen_apertures.gd -- <in.glb|res://…>
##       [--albedo=path.png] [--dark=0.16] [--min-area=2.0] [--flat=0.94]
##   `make assets-apertures IN=path.glb [ALBEDO= DARK= MIN_AREA=]`
##
## How it works: every triangle is scored by the albedo texture under its own UVs (a screen's glass is the darkest
## thing on a Syndicate hull, which is otherwise near-white), then dark triangles are grouped by the plane they lie
## in -- same normal within `--flat`, same plane offset within PLANE_TOL -- and each group is reported with its
## centre, its extent along two in-plane axes, and its outward normal. Groups smaller than `--min-area` are dropped
## so a sensor sphere or a louvre shadow is not mistaken for a display.

## A panel is one PLANE: faces further than this off the running plane start a new group. Loose values (0.35 m) merged
## the starboard recess with faces two metres inboard and reported panels wider than the hull's own beam.
const PLANE_TOL := 0.10
const NORMAL_TOL_DEFAULT := 0.985
## A face further than this from the group's running centre starts a new group even when it is coplanar: two dark
## panels in the SAME plane (the deck's pair, the recess floor behind a bezel) are different screens.
const SPREAD_TOL := 9.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: screen_apertures.gd -- <model> [--albedo=…] [--dark=0.16] [--min-area=2.0]")
		quit(2)
		return
	var path := args[0]
	var albedo_path := ""
	var dark := 0.16
	var min_area := 2.0
	var flat := NORMAL_TOL_DEFAULT
	for arg in args:
		if arg.begins_with("--albedo="):
			albedo_path = arg.trim_prefix("--albedo=")
		elif arg.begins_with("--dark="):
			dark = float(arg.trim_prefix("--dark="))
		elif arg.begins_with("--min-area="):
			min_area = float(arg.trim_prefix("--min-area="))
		elif arg.begins_with("--flat="):
			flat = float(arg.trim_prefix("--flat="))
	var model := AssetIO.load_glb(path) if not path.ends_with(".tscn") else (load(path) as PackedScene).instantiate()
	if model == null:
		push_error("could not load %s" % path)
		quit(1)
		return
	root.add_child(model)
	var image := _albedo(model, albedo_path)
	if image == null:
		push_error("no albedo image: pass --albedo=<png>")
		quit(1)
		return
	print("model: %s" % path)
	print("albedo: %d×%d" % [image.get_width(), image.get_height()])
	var faces := _dark_faces(model, image, dark, _bounds(model).get_center())
	print("dark faces: %d (luminance < %.2f)" % [faces.size(), dark])
	var groups := _group(faces, flat)
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["area"]) > float(b["area"]))
	var shown := 0
	for group: Dictionary in groups:
		if float(group["area"]) < min_area:
			continue
		shown += 1
		_report(group, shown)
	if shown == 0:
		print("no panel bigger than %.1f m^2 -- lower --min-area or raise --dark" % min_area)
	print("APERTURES_DONE")
	quit()


func _albedo(model: Node3D, override_path: String) -> Image:
	if override_path != "":
		var loaded := Image.load_from_file(ProjectSettings.globalize_path(override_path)) if not override_path.begins_with("res://") else (load(override_path) as Texture2D).get_image()
		return loaded
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s) as BaseMaterial3D
			if material == null:
				continue
			var texture := material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
			if texture != null:
				return texture.get_image()
	return null


## Every triangle whose albedo is darker than `dark`, as {centre, normal, area, points}, in the model's own space.
func _dark_faces(model: Node3D, image: Image, dark: float, hub: Vector3) -> Array:
	var out: Array = []
	var width := image.get_width()
	var height := image.get_height()
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
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if uvs.is_empty():
				continue
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(verts.size())
				for i in verts.size():
					indices[i] = i
			for t in range(0, indices.size() - 2, 3):
				var ia := indices[t]
				var ib := indices[t + 1]
				var ic := indices[t + 2]
				var a := xform * verts[ia]
				var b := xform * verts[ib]
				var c := xform * verts[ic]
				var uv := (uvs[ia] + uvs[ib] + uvs[ic]) / 3.0
				var px := clampi(int(fposmod(uv.x, 1.0) * width), 0, width - 1)
				var py := clampi(int(fposmod(uv.y, 1.0) * height), 0, height - 1)
				var colour := image.get_pixel(px, py)
				var luma := 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b
				if luma >= dark:
					continue
				var cross := (b - a).cross(c - a)
				var area := cross.length() * 0.5
				if area <= 0.0:
					continue
				var centre := (a + b + c) / 3.0
				# The AUTHORED vertex normals, not the winding's cross product: a recess has faces on both sides of
				# one plane and the winding flips between them, which split a single screen into two panels facing
				# opposite ways. Falling back to the cross product (oriented away from the hull's centre) only where
				# a mesh ships no normals -- and that fallback cannot tell an upward cant from a downward one.
				var normal := cross.normalized()
				if norms.size() > maxi(ia, maxi(ib, ic)):
					var authored := (xform.basis * (norms[ia] + norms[ib] + norms[ic])).normalized()
					if authored.length_squared() > 0.5:
						normal = authored
				elif normal.dot(centre - hub) < 0.0:
					normal = -normal
				out.append({"centre": centre, "normal": normal, "area": area, "verts": [a, b, c]})
	return out


## Dark faces sharing a normal (within `flat`) and a plane offset (within PLANE_TOL), merged into panels.
func _group(faces: Array, flat: float) -> Array:
	var groups: Array = []
	for face: Dictionary in faces:
		var normal: Vector3 = face["normal"]
		var offset: float = normal.dot(face["centre"])
		var placed := false
		for group: Dictionary in groups:
			var gn: Vector3 = group["normal"]
			if gn.dot(normal) < flat:
				continue
			if absf(gn.dot(face["centre"]) - float(group["offset"])) > PLANE_TOL:
				continue
			if (face["centre"] as Vector3).distance_to(group["centre"]) > SPREAD_TOL:
				continue
			# area-weighted running normal and offset, so a slightly curved bezel does not split into slivers
			var total: float = float(group["area"]) + float(face["area"])
			group["normal"] = (gn * float(group["area"]) + normal * float(face["area"])).normalized()
			group["offset"] = (float(group["offset"]) * float(group["area"]) + offset * float(face["area"])) / total
			group["centre"] = ((group["centre"] as Vector3) * float(group["area"]) + (face["centre"] as Vector3) * float(face["area"])) / total
			group["area"] = total
			(group["points"] as Array).append_array(face["verts"])
			placed = true
			break
		if not placed:
			groups.append({"normal": normal, "offset": offset, "area": float(face["area"]),
					"centre": face["centre"], "points": (face["verts"] as Array).duplicate()})
	return groups


func _report(group: Dictionary, index: int) -> void:
	var normal: Vector3 = group["normal"]
	var points: Array = group["points"]
	# Two in-plane axes: "right" is horizontal where it can be (a deck panel's right is +X), "up" completes the frame.
	var helper := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var right := helper.cross(normal).normalized()
	var up := normal.cross(right).normalized()
	var centre := Vector3.ZERO
	for point: Vector3 in points:
		centre += point
	centre /= points.size()
	var min_r := INF
	var max_r := -INF
	var min_u := INF
	var max_u := -INF
	for point: Vector3 in points:
		var d: Vector3 = point - centre
		min_r = minf(min_r, d.dot(right))
		max_r = maxf(max_r, d.dot(right))
		min_u = minf(min_u, d.dot(up))
		max_u = maxf(max_u, d.dot(up))
	# Recentre on the extent's middle: the triangle centroids are denser at one end of a panel than the other.
	var middle := centre + right * (min_r + max_r) * 0.5 + up * (min_u + max_u) * 0.5
	print("")
	print("panel %d: %.2f m^2 of dark faces, %d triangles" % [index, float(group["area"]), points.size()])
	print("  centre  (%.3f, %.3f, %.3f)" % [middle.x, middle.y, middle.z])
	print("  normal  (%.3f, %.3f, %.3f)" % [normal.x, normal.y, normal.z])
	print("  size    %.2f m across × %.2f m up (right axis (%.2f, %.2f, %.2f))" % [max_r - min_r, max_u - min_u, right.x, right.y, right.z])
	print("  extent  right %.2f..%.2f  up %.2f..%.2f" % [min_r, max_r, min_u, max_u])


## The union of the model's mesh AABBs, in its own space (the hub every panel normal is oriented away from).
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
