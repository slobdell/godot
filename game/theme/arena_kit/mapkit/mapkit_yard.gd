class_name MapkitYard
extends Node3D
## Draws the map kit's repeated pieces (mapkit P4, round 47; the lead's picks on the looks page) in a viewport, ONE
## MultiMesh per kind, each kind one mesh of at most two surfaces (lit steel/concrete + unshaded neon), so a field of 80
## hedgehogs or a 200 m monorail is two draws. No lights, no per-piece `_process`. Visual only; collision is Arena's.
##   hedgehog      three crossed steel I-beams, hazard-yellow tips (tank traps, his pick A)
##   monorail      a round concrete pillar (overpass, his pick C)
##   monorail_beam the beam it carries at 9 m with cyan rails under it, 1 m long: the instance is scaled to its span
##   monorail_car  a lit car parked on the beam
##   pipeline      10 m of fat pipe on concrete saddles, a cyan flow stripe on top (pipe runs, his pick B)
##   gantry_leg    a yellow crane leg (gantry crane, his pick A)
##   gantry_beam   the crane's beam, trolley and red warning lights, 1 m long: the instance is scaled to its span

const KINDS := ["hedgehog", "monorail", "monorail_beam", "monorail_car", "pipeline", "gantry_leg", "gantry_beam"]
## What a hedgehog is drawn inside: ArenaKit's 1.6 m footprint; 1.2 m tall where the collision box is 0.9 m (its open
## arms are what a round flies between).
const HOG := Vector3(1.6, 1.2, 1.6)
const HOG_BEAM := 0.2
const HOG_TIP := 0.24
## The monorail: pillar radius and height (ArenaKit `monorail` is the pillar's 1.4 x 9.0 x 1.4 box), the beam's section
## and the span a pillar carries by default (pillars 10 m apart make a continuous beam; look key `span` for others).
const PILLAR_R := 0.6
const BEAM_Y := 9.0
const BEAM := Vector2(2.4, 1.4)
const SPAN := 10.0
const STEEL := Color(0.16, 0.17, 0.19)
const CONCRETE := Color(0.22, 0.22, 0.23)
const CAR := Color(0.75, 0.76, 0.8)
## Pipeline: 10 m a prop, the pipe 0.8 m across (its top at 0.9 m: under the muzzles, ArenaKit `pipeline`).
const PIPE_LEN := 10.0
const PIPE_R := 0.4
const PIPE := Color(0.62, 0.64, 0.66)
## Gantry: legs 14 m tall (ArenaKit `gantry_leg` 1.2 x 14 x 1.2); the beam's section.
const LEG := Vector3(1.2, 14.0, 1.2)
const GANTRY_BEAM := Vector2(2.2, 2.0)
const CRANE_YELLOW := Color(0.62, 0.48, 0.1)

## P1b (R47.28, his Material Maker trial): "trim" (the shared trim sheet, assets/props/trim/, rendered by Material Maker:
## `make mapkit-trim`) or "plain" (flat colour + painted glow). HE PICKED THE TRIM SHEET for all four pieces (traps,
## monorail, pipes, crane; the trial page's db, R47.38), so it ships ON; `--kit-look=plain` is the escape. Read when a
## kind's mesh is first built.
static var look := "plain" if OS.get_cmdline_user_args().has("--kit-look=plain") else "trim"
## The trim sheet's bands (v ranges, top to bottom; assets/props/trim/trim_sheet.ptex): a box face or prism maps into one.
const PLATE := Vector2(0.0, 0.40)
const HAZARD := Vector2(0.40, 0.55)
const GRIME := Vector2(0.55, 0.85)
const JOINTS := Vector2(0.85, 1.0)
## Metres of surface per u = 1 (the sheet repeats along u): a plate panel is 1/4 of that, 0.75 m.
const TILE_M := 3.0
const TRIM_DIR := "res://assets/props/trim/"
static var _trim_materials := {}

var _entries := {}  # id -> [kind, Transform3D]
var _next_id := 1
var _dirty := false
var _draws := {}  # kind -> MultiMeshInstance3D
static var _meshes := {}


## The yard of `node`'s viewport, created on first use.
static func for_node(node: Node) -> MapkitYard:
	var viewport := node.get_viewport() if node.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	if viewport.has_meta("mapkit_yard"):
		var existing: Variant = viewport.get_meta("mapkit_yard")
		if is_instance_valid(existing):
			return existing
	var yard := MapkitYard.new()
	yard.name = "MapkitYard"
	viewport.set_meta("mapkit_yard", yard)
	viewport.add_child.call_deferred(yard)
	return yard


func add(kind: String, xform: Transform3D) -> int:
	assert(KINDS.has(kind), "unknown mapkit kind %s" % kind)
	var id := _next_id
	_next_id += 1
	_entries[id] = [kind, xform]
	_mark()
	return id


func remove(id: int) -> void:
	if _entries.erase(id):
		_mark()


func count(kind: String) -> int:
	return _entries.values().filter(func(e: Array) -> bool: return e[0] == kind).size()


## MultiMeshInstance3Ds drawing `kind` (0 or 1).
func draws_of(kind: String) -> int:
	return 1 if _draws.has(kind) and (_draws[kind] as MultiMeshInstance3D).multimesh.instance_count > 0 else 0


func _mark() -> void:
	if not _dirty:
		_dirty = true
		flush.call_deferred()


func flush() -> void:
	_dirty = false
	var by_kind := {}
	for entry: Array in _entries.values():
		if not by_kind.has(entry[0]):
			by_kind[entry[0]] = []
		by_kind[entry[0]].append(entry[1])
	for kind: String in KINDS:
		var xforms: Array = by_kind.get(kind, [])
		if xforms.is_empty() and not _draws.has(kind):
			continue
		if not _draws.has(kind):
			var draw := MultiMeshInstance3D.new()
			draw.name = kind.capitalize().replace(" ", "")
			draw.set_meta("kind", kind)  # how the parity test (and KitYard's readers) pair a draw with its entries
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh_of(kind)
			draw.multimesh = multimesh
			FxMultiMesh.never_interpolated(draw)
			add_child(draw)
			_draws[kind] = draw
		var multimesh := (_draws[kind] as MultiMeshInstance3D).multimesh
		FxMultiMesh.resize(multimesh, xforms.size())
		for i in xforms.size():
			multimesh.set_instance_transform(i, xforms[i])


static func mesh_of(kind: String) -> ArrayMesh:
	var key := kind + "/" + look
	if not _meshes.has(key):
		_meshes[key] = _build(kind)
	return _meshes[key]


static func _build(kind: String) -> ArrayMesh:
	var built: ArrayMesh = null
	match kind:
		"hedgehog":
			built = _hedgehog()
		"monorail":
			built = _monorail()
		"monorail_beam":
			built = _monorail_beam()
		"monorail_car":
			built = _car()
		"pipeline":
			built = _pipeline()
		"gantry_leg":
			built = _gantry_leg()
		"gantry_beam":
			built = _gantry_beam()
	return built


## Surface 0 lit (`albedo`), surface 1 neon (`glow`): the two SurfaceTools committed into one mesh.
## With `look` "trim" the body wears the trim sheet tinted `trim_tint` instead of the flat colour.
static func two_surfaces(body: SurfaceTool, albedo: Color, roughness: float, metallic: float, glow: SurfaceTool, glow_color: Color,
		trim_tint := Color.WHITE) -> ArrayMesh:
	body.generate_normals()
	glow.generate_normals()
	if look == "trim":
		body.generate_tangents()
		body.set_material(trim_material(trim_tint))
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = albedo
		material.roughness = roughness
		material.metallic = metallic
		body.set_material(material)
	glow.set_material(CyberMaterials.neon(glow_color, 3.0, 0.0))
	var mesh := body.commit()
	glow.commit(mesh)
	return mesh


## The trim sheet as a lit material (Material Maker's channels: ORM = occlusion, roughness G, metallic B), tinted.
static func trim_material(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if not _trim_materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.albedo_texture = load(TRIM_DIR + "trim_sheet_albedo.png")
		var orm: Texture2D = load(TRIM_DIR + "trim_sheet_orm.png")
		material.metallic = 1.0
		material.metallic_texture = orm
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		material.roughness = 1.0
		material.roughness_texture = orm
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.normal_enabled = true
		material.normal_texture = load(TRIM_DIR + "trim_sheet_normal.png")
		material.emission_enabled = true
		material.emission = Color.BLACK
		material.emission_texture = load(TRIM_DIR + "trim_sheet_emission.png")
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_trim_materials[key] = material
	return _trim_materials[key]


static func _hedgehog() -> ArrayMesh:
	var steel := surface()
	var tips := surface()
	# A cube resting on a corner has its body diagonals 54.7 deg from the vertical; three of them, 120 deg apart about
	# the vertical, give the tripod stance. Length set so the hog fits HOG.
	var length := 1.55
	var centre := Vector3(0, HOG.y / 2.0, 0)
	for k in 3:
		var basis := Basis.from_euler(Vector3(deg_to_rad(54.7), deg_to_rad(120.0 * k), 0.0), EULER_ORDER_YXZ)
		box(steel, Transform3D(basis, centre), Vector3(HOG_BEAM, length, HOG_BEAM), GRIME)
		for end in [-1.0, 1.0]:
			box(tips, Transform3D(basis, centre + basis.y * end * (length / 2.0 - HOG_TIP / 2.0)), Vector3(HOG_TIP, HOG_TIP, HOG_TIP))
	return two_surfaces(steel, STEEL, 0.4, 0.8, tips, CyberMaterials.YELLOW)


static func _monorail() -> ArrayMesh:
	var concrete := surface()
	var collar := surface()
	prism(concrete, Vector3.ZERO, PILLAR_R * 1.15, PILLAR_R, BEAM_Y, 10)
	prism(collar, Vector3(0, BEAM_Y - 0.6, 0), PILLAR_R + 0.04, PILLAR_R + 0.04, 0.15, 10)
	return two_surfaces(concrete, CONCRETE, 0.8, 0.05, collar, CyberMaterials.CYAN, Color(0.75, 0.75, 0.78))


## 1 m of beam along z, centred on the pillar; the instance's basis scales z to the span.
static func _monorail_beam() -> ArrayMesh:
	var concrete := surface()
	var rails := surface()
	box(concrete, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y / 2.0, 0)), Vector3(BEAM.x, BEAM.y, 1.0))
	for side in [-1.0, 1.0]:
		box(rails, Transform3D(Basis.IDENTITY, Vector3(side * (BEAM.x / 2.0 + 0.05), BEAM_Y + 0.1, 0)), Vector3(0.1, 0.1, 1.0))
	return two_surfaces(concrete, CONCRETE, 0.8, 0.05, rails, CyberMaterials.CYAN)


static func _car() -> ArrayMesh:
	var shell := surface()
	var windows := surface()
	box(shell, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y + 1.6, 0)), Vector3(3.4, 3.2, 24.0))
	box(windows, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y + 2.0, 0)), Vector3(3.5, 0.7, 22.0))
	return two_surfaces(shell, CAR, 0.3, 0.5, windows, CyberMaterials.CYAN, Color(1.4, 1.4, 1.45))


static func _pipeline() -> ArrayMesh:
	var body := surface()
	var stripe := surface()
	# The pipe as a 12-sided prism lying along z, on three saddles.
	var sides := 12
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * PIPE_R, 0.5 + sin(a0) * PIPE_R, 0)
		var p1 := Vector3(cos(a1) * PIPE_R, 0.5 + sin(a1) * PIPE_R, 0)
		var half := Vector3(0, 0, PIPE_LEN / 2.0)
		# u along the pipe (the brushed plate's grain), v around it across the plate band.
		var v0 := lerpf(PLATE.x, PLATE.y, float(i) / sides)
		var v1 := lerpf(PLATE.x, PLATE.y, float(i + 1) / sides)
		var u := PIPE_LEN / 2.0 / TILE_M
		var uvs := [Vector2(-u, v0), Vector2(-u, v1), Vector2(u, v1), Vector2(-u, v0), Vector2(u, v1), Vector2(u, v0)]
		var verts := [p0 - half, p1 - half, p1 + half, p0 - half, p1 + half, p0 + half]
		for k in 6:
			body.set_uv(uvs[k])
			body.add_vertex(verts[k])
	for z in [-3.5, 0.0, 3.5]:
		box(body, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, z)), Vector3(1.0, 0.4, 0.6), GRIME)
	box(stripe, Transform3D(Basis.IDENTITY, Vector3(0, 0.5 + PIPE_R + 0.02, 0)), Vector3(0.25, 0.04, PIPE_LEN))
	return two_surfaces(body, PIPE, 0.3, 0.9, stripe, CyberMaterials.CYAN)


static func _gantry_leg() -> ArrayMesh:
	var body := surface()
	var light := surface()
	box(body, Transform3D(Basis.IDENTITY, Vector3(0, LEG.y / 2.0, 0)), LEG)
	box(light, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, LEG.z / 2.0 + 0.02)), Vector3(0.6, 0.15, 0.04))
	return two_surfaces(body, CRANE_YELLOW, 0.5, 0.6, light, CyberMaterials.ORANGE, Color(1.6, 1.25, 0.35))


## 1 m along x from the origin leg: the instance's basis scales x to the span.
static func _gantry_beam() -> ArrayMesh:
	var body := surface()
	var lights := surface()
	box(body, Transform3D(Basis.IDENTITY, Vector3(0.5, LEG.y + GANTRY_BEAM.y / 2.0, 0)), Vector3(1.0, GANTRY_BEAM.y, GANTRY_BEAM.x))
	box(body, Transform3D(Basis.IDENTITY, Vector3(0.35, LEG.y + GANTRY_BEAM.y + 1.2, 0)), Vector3(0.15, 2.4, 3.2))
	box(lights, Transform3D(Basis.IDENTITY, Vector3(0.5, LEG.y - 0.1, GANTRY_BEAM.x / 2.0 + 0.02)), Vector3(1.0, 0.12, 0.04))
	return two_surfaces(body, CRANE_YELLOW, 0.5, 0.6, lights, CyberMaterials.RED, Color(1.6, 1.25, 0.35))


static func surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A box of `size` (local) placed by `xform`: 12 triangles, wound outward. Each face is UV-mapped into the trim sheet's
## `band` (a v range): u runs along the face's horizontal edge in metres / TILE_M, v across the band over its height.
static func box(st: SurfaceTool, xform: Transform3D, size: Vector3, band := PLATE) -> void:
	var h := size / 2.0
	var local: Array[Vector3] = []
	for i in 8:
		local.append(Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	# Per face: the corner quad and its (u axis, v axis) in box space.
	var faces := [[[0, 2, 3, 1], Vector3.RIGHT, Vector3.UP], [[4, 5, 7, 6], Vector3.RIGHT, Vector3.UP],
			[[0, 1, 5, 4], Vector3.RIGHT, Vector3.BACK], [[2, 6, 7, 3], Vector3.RIGHT, Vector3.BACK],
			[[0, 4, 6, 2], Vector3.BACK, Vector3.UP], [[1, 3, 7, 5], Vector3.BACK, Vector3.UP]]
	for face: Array in faces:
		var quad: Array = face[0]
		var u_axis: Vector3 = face[1]
		var v_axis: Vector3 = face[2]
		var v_extent := maxf(absf(size.dot(v_axis)), 0.001)
		for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			for index: int in tri:
				var p: Vector3 = local[index]
				var v01 := (p.dot(v_axis) / v_extent) + 0.5
				st.set_uv(Vector2(p.dot(u_axis) / TILE_M, lerpf(band.y, band.x, v01)))
				st.add_vertex(xform * p)


## A vertical `sides`-sided prism from `base` up `height`, radius r0 at the foot and r1 at the top (no caps: never seen);
## UVs: u around the circumference in metres / TILE_M, v up the height across `band`.
static func prism(st: SurfaceTool, base: Vector3, r0: float, r1: float, height: float, sides: int, band := GRIME) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p10 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p01 := base + Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, height, sin(a1) * r1)
		var u0 := TAU * r0 * i / sides / TILE_M
		var u1 := TAU * r0 * (i + 1) / sides / TILE_M
		var uvs := [Vector2(u0, band.y), Vector2(u0, band.x), Vector2(u1, band.x), Vector2(u0, band.y), Vector2(u1, band.x), Vector2(u1, band.y)]
		var verts := [p00, p01, p11, p00, p11, p10]
		for k in 6:
			st.set_uv(uvs[k])
			st.add_vertex(verts[k])
