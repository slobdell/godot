extends SceneTree
## `make class-look` (fleet, round 15, F1; garage's tour, in a player's words: *"My tanks and IFVs look the same in the
## fight."*). Each faction's tank and IFV, one at a time, at HIS pose (pitch 21 deg, FOV 35, 72 m; `--class-look-
## distance=49` for round 6's settled pose) under the arena's night environment, at five headings relative to the
## camera (away, quarter-away, side, quarter-toward, toward). Per shot it renders the unit twice: LIT (what he sees)
## and as a MASK (every drawn mesh unshaded white on black: the silhouette, lighting-proof). Then, per pair and heading,
## it prints `CLASS_LOOK {json}`: each unit's on-screen area, box and mean lit colour, the share of its pixels that
## are bright (lamps, neon), and the pair's silhouette IoU with the two masks laid on their centroids (1.0 = the same
## shape at the same size; a tank and an IFV that read apart want it low). `CLASS_LOOK_PAIR` sums a pair up, with the
## drawn length ratio (union of drawn meshes along the hull's forward, tank over IFV). It saves `<unit>_<heading>.png`
## (lit) and `<unit>_<heading>_mask.png` crops for the contact sheet (`tools/assets/class_look_sheet.py`).
## Visual only; nothing simulates. Flags: --class-look-dir=<abs dir> [--class-look-pairs=condemned,law]
## [--class-look-distance=72] [--class-look-headings=away,side] [--class-look-size=1920x1080]
## [--class-look-units=tank,ifv] (any two or more units instead of the faction pairs: F2's before/after).

const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const DISTANCE_M := 72.0
## The unit's yaw for each heading, with the camera south of it looking north (-Z). Forward is -Z and positive yaw
## turns LEFT (trip-up 2): 0 drives away from the camera, -90 drives to the right of the frame, 180 toward it.
const HEADINGS := {
	"away": 0.0, "quarter_away": -45.0, "side": -90.0, "quarter_toward": -135.0, "toward": 180.0,
}
const ROLES := ["tank", "ifv"]
## Crops keep this many pixels around the mask's box.
const CROP_MARGIN := 6
## A lit pixel this bright (max channel) counts as a lamp or neon, not paint.
const BRIGHT := 0.6

var _world: Node3D
var _camera: Camera3D
var _environment_slot: Node3D
var _floor: MeshInstance3D
var _mask_env: Environment
var _out := ""


func _init() -> void:
	_run.call_deferred()


## Each faction's [tank, ifv] by catalog role.
static func faction_pairs(factions: Array) -> Array:
	var pairs: Array = []
	for faction: String in factions:
		var pair: Array = []
		for role: String in ROLES:
			for unit_id: String in Units.roster(faction):
				if Units.role_of(unit_id) == role:
					pair.append(unit_id)
					break
		if pair.size() == ROLES.size():
			pairs.append(pair)
	return pairs


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_out = flags.text("class-look-dir", "/tmp/class-look")
	DirAccess.make_dir_recursive_absolute(_out)
	GameTheme.use("cyberpunk")
	var size_text := flags.text("class-look-size", "1920x1080").split("x")
	root.size = Vector2i(int(size_text[0]), int(size_text[1]))
	var distance := float(flags.text("class-look-distance", str(DISTANCE_M)))
	var headings: Array = HEADINGS.keys()
	if flags.text("class-look-headings") != "":
		headings = Array(flags.text("class-look-headings").split(",", false))
	var pairs: Array
	if flags.text("class-look-units") != "":
		pairs = [Array(flags.text("class-look-units").split(",", false))]
	else:
		var factions: Array = Units.FACTIONS
		if flags.text("class-look-pairs") != "":
			factions = Array(flags.text("class-look-pairs").split(",", false))
		pairs = faction_pairs(factions)
	_build_world(distance)
	if flags.has("class-look-lineup"):
		for heading: String in ["away", "quarter_away"]:
			await _lineup(heading)
		print("CLASS_LOOK_DONE")
		quit()
		return
	for pair: Array in pairs:
		var shots := {}  # unit -> heading -> shot
		var lengths := {}
		for unit_id: String in pair:
			shots[unit_id] = {}
			var tank := _spawn(unit_id)
			for i in 8:
				await process_frame
			lengths[unit_id] = drawn_length(tank)
			for heading: String in headings:
				shots[unit_id][heading] = await _shoot(tank, unit_id, heading)
			tank.queue_free()
			await process_frame
		_report(pair, shots, lengths, headings, distance)
	print("CLASS_LOOK_DONE")
	quit()


func _build_world(distance: float) -> void:
	_world = Node3D.new()
	root.add_child(_world)
	# The arena's own night: sky, skyline, moon, fog and glow (VisualSlot "arena.environment"), and a floor the colour
	# of the arena's, so the lit frames are judged against what he plays on rather than a studio grey.
	var slot := VisualSlot.new()
	slot.slot = "arena.environment"
	_world.add_child(slot)
	_environment_slot = slot
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	_floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.11, 0.11, 0.12)
	ground.roughness = 0.9
	_floor.material_override = ground
	_world.add_child(_floor)
	_camera = Camera3D.new()
	_camera.fov = FOV_DEG
	_camera.far = 1500.0
	_world.add_child(_camera)
	_camera.current = true
	_camera.global_transform = RtsCamera.pose_at(Vector3.ZERO, 0.0, distance, PITCH_DEG)
	_mask_env = Environment.new()
	_mask_env.background_mode = Environment.BG_COLOR
	_mask_env.background_color = Color.BLACK
	_mask_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_mask_env.ambient_light_color = Color.BLACK


func _spawn(unit_id: String) -> Node3D:
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	tank.set("team", 0)
	_world.add_child(tank)
	tank.call("set_team_accent", GameTheme.team_color(0))  # as Match dresses every tank it builds
	for label in tank.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	return tank


## The union of a unit's drawn meshes along its own forward axis (metres): what the eye can take as its length.
static func drawn_length(tank: Node3D) -> float:
	var box := drawn_bounds(tank)
	return box.size.z


## The union of a unit's visible meshes, in the tank's own frame.
static func drawn_bounds(tank: Node3D) -> AABB:
	var to_tank := tank.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in tank.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := to_tank * mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## One heading: the lit frame and the mask, analysed. Returns the mask (bounding box and bytes) and the numbers.
func _shoot(tank: Node3D, unit_id: String, heading: String) -> Dictionary:
	# A tank that does not simulate is a replica: every drawn frame it eases toward its synced pose (tank.gd), so the
	# yaw is set THERE too -- the first run set only `rotation` and shot five identical frames per unit.
	var yaw := deg_to_rad(float(HEADINGS.get(heading, 0.0)))
	tank.set("sync_yaw", yaw)
	tank.rotation.y = yaw
	tank.set("sync_turret_yaw", 0.0)
	(tank.get_node("Turret") as Node3D).rotation.y = 0.0
	# A model sitting off its origin drifts in the frame between headings; nothing measured depends on where it sits
	# (masks are compared on their centroids).
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var lit := root.get_texture().get_image()
	# The mask: every drawn mesh unshaded white over black, the night's sky and skyline hidden.
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	var overridden: Array = []
	var flares := tank.find_children("ClassFlare", "Node3D", true, false)
	for node in tank.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		overridden.append([geometry, geometry.material_override])
		geometry.material_override = white
	# A class lamp's flare is light, not shape (ClassMark): its dome is in the silhouette, its glow is not.
	for flare: Node3D in flares:
		flare.visible = false
	_environment_slot.visible = false
	_floor.visible = false
	_camera.environment = _mask_env
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var mask_image := root.get_texture().get_image()
	for pair: Array in overridden:
		(pair[0] as GeometryInstance3D).material_override = pair[1]
	for flare: Node3D in flares:
		flare.visible = true
	_environment_slot.visible = true
	_floor.visible = true
	_camera.environment = null
	var shot := analyse(lit, mask_image)
	var box: Rect2i = shot["rect"]
	if box.size.x > 0:
		var crop := box.grow(CROP_MARGIN).intersection(Rect2i(Vector2i.ZERO, lit.get_size()))
		lit.get_region(crop).save_png(_out.path_join("%s_%s.png" % [unit_id, heading]))
		mask_image.get_region(crop).save_png(_out.path_join("%s_%s_mask.png" % [unit_id, heading]))
	return shot


## The mask's box, area and centroid, and the lit colour inside it.
static func analyse(lit: Image, mask_image: Image) -> Dictionary:
	var size := mask_image.get_size()
	var lo := Vector2i(size.x, size.y)
	var hi := Vector2i(-1, -1)
	for y in size.y:
		for x in size.x:
			if mask_image.get_pixel(x, y).r > 0.5:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return {"rect": Rect2i(), "area": 0, "bits": PackedByteArray(), "centroid": Vector2.ZERO,
				"mean": Color.BLACK, "bright": 0.0}
	var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
	var bits := PackedByteArray()
	bits.resize(rect.size.x * rect.size.y)
	var area := 0
	var sum := Vector2.ZERO
	var colour := Vector3.ZERO
	var bright := 0
	for y in rect.size.y:
		for x in rect.size.x:
			var p := rect.position + Vector2i(x, y)
			if mask_image.get_pixel(p.x, p.y).r <= 0.5:
				continue
			bits[y * rect.size.x + x] = 1
			area += 1
			sum += Vector2(x, y)
			var c := lit.get_pixel(p.x, p.y)
			colour += Vector3(c.r, c.g, c.b)
			if maxf(c.r, maxf(c.g, c.b)) > BRIGHT:
				bright += 1
	colour /= area
	return {"rect": rect, "area": area, "bits": bits, "centroid": sum / area, "lit": lit.get_region(rect),
			"mean": Color(colour.x, colour.y, colour.z), "bright": float(bright) / area}


## Intersection over union of two masks laid on their centroids (each a dictionary from `analyse`).
static func centred_iou(a: Dictionary, b: Dictionary) -> float:
	if int(a["area"]) == 0 or int(b["area"]) == 0:
		return 0.0
	var ra: Rect2i = a["rect"]
	var rb: Rect2i = b["rect"]
	var bits_a: PackedByteArray = a["bits"]
	var bits_b: PackedByteArray = b["bits"]
	# B's pixel (x, y) lands on A's (x + shift.x, y + shift.y).
	var shift := Vector2i(((a["centroid"] as Vector2) - (b["centroid"] as Vector2)).round())
	var both := 0
	for y in rb.size.y:
		var ay := y + shift.y
		if ay < 0 or ay >= ra.size.y:
			continue
		for x in rb.size.x:
			if bits_b[y * rb.size.x + x] == 0:
				continue
			var ax := x + shift.x
			if ax >= 0 and ax < ra.size.x and bits_a[ay * ra.size.x + ax] == 1:
				both += 1
	return float(both) / float(int(a["area"]) + int(b["area"]) - both)


## F2's number (a marking cannot move a silhouette): how different the two LIT units look, pixel by pixel, laid on
## their centroids -- the mean RGB distance (0-255) over the union of the two masks, a pixel outside a mask counting
## as black. The same unit against itself is 0; a shape change and a lamp both raise it.
static func lit_difference(a: Dictionary, b: Dictionary) -> float:
	if int(a["area"]) == 0 or int(b["area"]) == 0:
		return 0.0
	var ra: Rect2i = a["rect"]
	var rb: Rect2i = b["rect"]
	var shift := Vector2i(((a["centroid"] as Vector2) - (b["centroid"] as Vector2)).round())
	# The union, in A's crop coordinates.
	var lo := Vector2i(mini(0, shift.x), mini(0, shift.y))
	var hi := Vector2i(maxi(ra.size.x, rb.size.x + shift.x), maxi(ra.size.y, rb.size.y + shift.y))
	var total := 0.0
	var count := 0
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var ca := _lit_at(a, Vector2i(x, y))
			var cb := _lit_at(b, Vector2i(x - shift.x, y - shift.y))
			if ca.a == 0.0 and cb.a == 0.0:
				continue
			total += Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
			count += 1
	return total / maxi(count, 1) * 255.0


## A unit's lit pixel in its own crop, alpha 1 inside its mask; black with alpha 0 outside it.
static func _lit_at(shot: Dictionary, p: Vector2i) -> Color:
	var rect: Rect2i = shot["rect"]
	if p.x < 0 or p.y < 0 or p.x >= rect.size.x or p.y >= rect.size.y:
		return Color(0, 0, 0, 0)
	if (shot["bits"] as PackedByteArray)[p.y * rect.size.x + p.x] == 0:
		return Color(0, 0, 0, 0)
	var c := (shot["lit"] as Image).get_pixel(p.x, p.y)
	return Color(c.r, c.g, c.b, 1.0)


## The distance between two lit colours, 0-255 RGB (Euclidean): under ~20 the eye calls them the same colour.
static func colour_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0


func _report(pair: Array, shots: Dictionary, lengths: Dictionary, headings: Array, distance: float) -> void:
	var first: String = pair[0]
	var ious: Array = []
	var diffs: Array = []
	for heading: String in headings:
		var row := {"pair": pair, "heading": heading, "distance_m": distance, "size": [root.size.x, root.size.y],
				"units": {}}
		for unit_id: String in pair:
			var shot: Dictionary = shots[unit_id][heading]
			var rect: Rect2i = shot["rect"]
			var mean: Color = shot["mean"]
			row["units"][unit_id] = {"area_px": shot["area"], "box_px": [rect.size.x, rect.size.y],
					"mean_rgb": [roundi(mean.r8), roundi(mean.g8), roundi(mean.b8)],
					"bright_share": snappedf(float(shot["bright"]), 0.001)}
		for unit_id: String in pair.slice(1):
			var a: Dictionary = shots[first][heading]
			var b: Dictionary = shots[unit_id][heading]
			var iou := centred_iou(a, b)
			ious.append(iou)
			row["iou_%s_%s" % [first, unit_id]] = snappedf(iou, 0.001)
			row["colour_distance_%s_%s" % [first, unit_id]] = snappedf(colour_distance(a["mean"], b["mean"]), 0.1)
			var diff := lit_difference(a, b)
			diffs.append(diff)
			row["lit_difference_%s_%s" % [first, unit_id]] = snappedf(diff, 0.1)
		print("CLASS_LOOK " + JSON.stringify(row))
	# The arm check (round 9's lesson: an instruction accepted is not an instruction obeyed): a unit turned from away
	# to side-on must change its on-screen box. The first run's tanks never turned, and every heading measured alike.
	if headings.has("away") and headings.has("side"):
		for unit_id: String in pair:
			var away: Rect2i = shots[unit_id]["away"]["rect"]
			var side: Rect2i = shots[unit_id]["side"]["rect"]
			if away.size == side.size:
				print("CLASS_LOOK_STUCK %s: the same %s box away and side-on -- the unit did not turn" % [unit_id,
						away.size])
	var summary := {"pair": pair, "distance_m": distance, "size": [root.size.x, root.size.y],
			"drawn_length_m": {}, "iou_mean": 0.0, "iou_max": 0.0}
	for unit_id: String in pair:
		summary["drawn_length_m"][unit_id] = snappedf(float(lengths[unit_id]), 0.01)
	if pair.size() >= 2 and float(lengths[pair[1]]) > 0.0:
		summary["drawn_length_ratio"] = snappedf(float(lengths[first]) / float(lengths[pair[1]]), 0.001)
	if not ious.is_empty():
		var total := 0.0
		for iou: float in ious:
			total += iou
		summary["iou_mean"] = snappedf(total / ious.size(), 0.001)
		summary["iou_max"] = snappedf(ious.max(), 0.001)
	if not diffs.is_empty():
		var sum := 0.0
		for diff: float in diffs:
			sum += diff
		summary["lit_difference_mean"] = snappedf(sum / diffs.size(), 0.1)
		summary["lit_difference_min"] = snappedf(diffs.min(), 0.1)
	print("CLASS_LOOK_PAIR " + JSON.stringify(summary))


# ------------------------------------------------------------------------------------------------------------------
# F4 (round 15, stretch): the same silhouette WITHOUT a renderer, so a headless test can hold the roster to it. Every
# drawn triangle of a unit is projected through his camera (pitch 21, FOV 35, 72 m, the phone's 810 rows) and filled
# into a bitmap; the result has the shape `analyse` returns, so `centred_iou` compares it. The rendered masks of `make
# class-look` are the check on this: the two agree to a few hundredths on every pair (Status, F4).
# ------------------------------------------------------------------------------------------------------------------

## The unit's silhouette at his pose for `heading`, as `analyse` returns it (rect, area, bits, centroid), rasterised.
## `tank` must be in the tree (its parts are fitted when they enter it); its own transform is ignored.
static func raster_silhouette(tank: Node3D, heading: String, size := Vector2i(1800, 810),
		distance := DISTANCE_M) -> Dictionary:
	var yaw := deg_to_rad(float(HEADINGS.get(heading, 0.0)))
	var place := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	var view := RtsCamera.pose_at(Vector3.ZERO, 0.0, distance, PITCH_DEG).affine_inverse()
	var focal := (size.y / 2.0) / tan(deg_to_rad(FOV_DEG) / 2.0)
	var centre := Vector2(size) / 2.0
	var to_tank := tank.global_transform.affine_inverse()
	var filled := {}  # Vector2i -> true
	for node in tank.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree() or mesh_instance is ShieldEffect \
				or String(mesh_instance.name) == "ClassFlare":
			continue
		var to_screen := view * place * to_tank * mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
					else PackedInt32Array()
			var points := PackedVector2Array()
			points.resize(vertices.size())
			for i in vertices.size():
				var p := to_screen * vertices[i]
				points[i] = centre + Vector2(p.x, -p.y) * (focal / maxf(-p.z, 0.01))
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0, count - 2, 3):
				var a := points[indices[t] if not indices.is_empty() else t]
				var b := points[indices[t + 1] if not indices.is_empty() else t + 1]
				var c := points[indices[t + 2] if not indices.is_empty() else t + 2]
				_fill_triangle(filled, a, b, c)
	if filled.is_empty():
		return {"rect": Rect2i(), "area": 0, "bits": PackedByteArray(), "centroid": Vector2.ZERO}
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for p: Vector2i in filled:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
	var bits := PackedByteArray()
	bits.resize(rect.size.x * rect.size.y)
	var sum := Vector2.ZERO
	for p: Vector2i in filled:
		bits[(p.y - lo.y) * rect.size.x + (p.x - lo.x)] = 1
		sum += Vector2(p - lo)
	return {"rect": rect, "area": filled.size(), "bits": bits, "centroid": sum / filled.size()}


## Mark every pixel whose centre is inside triangle abc (either winding).
static func _fill_triangle(filled: Dictionary, a: Vector2, b: Vector2, c: Vector2) -> void:
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-6:
		return
	var x0 := floori(minf(a.x, minf(b.x, c.x)))
	var x1 := ceili(maxf(a.x, maxf(b.x, c.x)))
	var y0 := floori(minf(a.y, minf(b.y, c.y)))
	var y1 := ceili(maxf(a.y, maxf(b.y, c.y)))
	var sign := 1.0 if area > 0.0 else -1.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if (b - a).cross(p - a) * sign >= 0.0 and (c - b).cross(p - b) * sign >= 0.0 \
					and (a - c).cross(p - c) * sign >= 0.0:
				filled[Vector2i(x, y)] = true


# F4: the lineup for his eye -- every faction's scout, IFV and tank side by side in ONE frame at his pose (72 m), as he
# would see them driving away from him; `lineup_<heading>.png`. The standing number is tests/test_units_class_lineup.gd.
const LINEUP_GAP_M := 3.2

func _lineup(heading: String) -> void:
	var ids: Array = []
	for faction: String in Units.FACTIONS:
		for role: String in ["scout", "ifv", "tank"]:
			for unit_id: String in Units.roster(faction):
				if Units.role_of(unit_id) == role:
					ids.append(unit_id)
					break
	var widths := ids.map(func(id: String) -> float: return float(Units.stat(id, "hull_size")[0]))
	var span := 0.0
	for w: float in widths:
		span += w + LINEUP_GAP_M
	span -= LINEUP_GAP_M
	var at := -span / 2.0
	var parked: Array = []
	for i in ids.size():
		var tank := _spawn(ids[i])
		var x := at + float(widths[i]) / 2.0
		var yaw := deg_to_rad(float(HEADINGS[heading]))
		tank.set("sync_yaw", yaw)
		tank.set("sync_position", Vector3(x, 0, 0))
		tank.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, 0))
		var label := Label3D.new()
		label.text = "%s\n%s" % [Units.stat(ids[i], "display_name"), Units.role_of(ids[i]).to_upper()]
		label.font_size = 48
		label.outline_size = 14
		label.pixel_size = 0.016
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		_world.add_child(label)
		# At the row's own depth, above it (two tiers): a label nearer the camera than its vehicle drifts sideways
		# away from it toward the frame's edges (the first frame put every label one vehicle off).
		label.global_position = Vector3(x, 7.0 + 2.6 * (i % 2), 0.0)
		parked.append(tank)
		parked.append(label)
		at += float(widths[i]) + LINEUP_GAP_M
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("lineup_%s.png" % heading))
	print("CLASS_LOOK_LINEUP %s %d units, %.1f m" % [heading, ids.size(), span])
	for node: Node in parked:
		node.queue_free()
	await process_frame

