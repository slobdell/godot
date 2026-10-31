class_name MapkitYard
extends Node3D
## Draws the map kit's repeated pieces (mapkit P4, round 47; the lead's picks on the looks page) in a viewport, ONE
## MultiMesh per kind, each kind one mesh of at most two surfaces (lit steel/concrete + unshaded neon), so a field of 80
## hedgehogs or a 200 m monorail is two draws. No lights, no per-piece `_process`. Visual only; collision is Arena's.
##   hedgehog      three crossed steel I-beams, hazard-yellow tips (tank traps, his pick A)
##   monorail      a round concrete pillar and the 10 m of beam it carries at 9 m, cyan rails under it (overpass, his pick C)
##   monorail_car  a lit car parked on the beam

const KINDS := ["hedgehog", "monorail", "monorail_car"]
## What a hedgehog is drawn inside: ArenaKit's 1.6 m footprint; 1.2 m tall where the collision box is 0.9 m (its open
## arms are what a round flies between).
const HOG := Vector3(1.6, 1.2, 1.6)
const HOG_BEAM := 0.2
const HOG_TIP := 0.24
## The monorail: pillar radius and height (ArenaKit `monorail` is the pillar's 1.4 x 9.0 x 1.4 box), the beam's section
## and the span each pillar carries (pillars 10 m apart make a continuous beam).
const PILLAR_R := 0.6
const BEAM_Y := 9.0
const BEAM := Vector2(2.4, 1.4)
const SPAN := 10.0
const STEEL := Color(0.16, 0.17, 0.19)
const CONCRETE := Color(0.22, 0.22, 0.23)
const CAR := Color(0.75, 0.76, 0.8)

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
	if not _meshes.has(kind):
		match kind:
			"hedgehog":
				_meshes[kind] = _hedgehog()
			"monorail":
				_meshes[kind] = _monorail()
			"monorail_car":
				_meshes[kind] = _car()
	return _meshes[kind]


## Surface 0 lit (`albedo`), surface 1 neon (`glow`): the two SurfaceTools committed into one mesh.
static func _commit(body: SurfaceTool, albedo: Color, roughness: float, metallic: float, glow: SurfaceTool, glow_color: Color) -> ArrayMesh:
	body.generate_normals()
	glow.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	body.set_material(material)
	glow.set_material(CyberMaterials.neon(glow_color, 3.0, 0.0))
	var mesh := body.commit()
	glow.commit(mesh)
	return mesh


static func _hedgehog() -> ArrayMesh:
	var steel := _begin()
	var tips := _begin()
	# A cube resting on a corner has its body diagonals 54.7 deg from the vertical; three of them, 120 deg apart about
	# the vertical, give the tripod stance. Length set so the hog fits HOG.
	var length := 1.55
	var centre := Vector3(0, HOG.y / 2.0, 0)
	for k in 3:
		var basis := Basis.from_euler(Vector3(deg_to_rad(54.7), deg_to_rad(120.0 * k), 0.0), EULER_ORDER_YXZ)
		box(steel, Transform3D(basis, centre), Vector3(HOG_BEAM, length, HOG_BEAM))
		for end in [-1.0, 1.0]:
			box(tips, Transform3D(basis, centre + basis.y * end * (length / 2.0 - HOG_TIP / 2.0)), Vector3(HOG_TIP, HOG_TIP, HOG_TIP))
	return _commit(steel, STEEL, 0.4, 0.8, tips, CyberMaterials.YELLOW)


static func _monorail() -> ArrayMesh:
	var concrete := _begin()
	var rails := _begin()
	prism(concrete, Vector3.ZERO, PILLAR_R * 1.15, PILLAR_R, BEAM_Y, 10)
	box(concrete, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y / 2.0, 0)), Vector3(BEAM.x, BEAM.y, SPAN))
	for side in [-1.0, 1.0]:
		box(rails, Transform3D(Basis.IDENTITY, Vector3(side * (BEAM.x / 2.0 + 0.05), BEAM_Y + 0.1, 0)), Vector3(0.1, 0.1, SPAN))
	return _commit(concrete, CONCRETE, 0.8, 0.05, rails, CyberMaterials.CYAN)


static func _car() -> ArrayMesh:
	var shell := _begin()
	var windows := _begin()
	box(shell, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y + 1.6, 0)), Vector3(3.4, 3.2, 24.0))
	box(windows, Transform3D(Basis.IDENTITY, Vector3(0, BEAM_Y + BEAM.y + 2.0, 0)), Vector3(3.5, 0.7, 22.0))
	return _commit(shell, CAR, 0.3, 0.5, windows, CyberMaterials.CYAN)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A box of `size` (local) placed by `xform`: 12 triangles, wound outward.
static func box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var h := size / 2.0
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(xform * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for quad: Array in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			for index: int in tri:
				st.add_vertex(corners[index])


## A vertical `sides`-sided prism from `base` up `height`, radius r0 at the foot and r1 at the top (no caps: never seen).
static func prism(st: SurfaceTool, base: Vector3, r0: float, r1: float, height: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p10 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p01 := base + Vector3(cos(a0) * r1, height, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, height, sin(a1) * r1)
		for v in [p00, p01, p11, p00, p11, p10]:
			st.add_vertex(v)
