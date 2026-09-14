class_name ColorMeshBuilder
extends RefCounted
## Builds procedural art (vehicles, small props) as vertex-colored boxes merged into ONE mesh with
## two surfaces: `lit` (StandardMaterial3D reading vertex color) and `glow` (unshaded neon reading
## vertex color × energy). Every tank part then costs two draw calls whatever its detail, and all
## tanks share the same two materials: team colors live in the vertex colors, not in materials.
## Vertex alpha on glow boxes is a heat mask: `instance uniform float heat` on the MeshInstance3D
## (see vehicle_glow.gdshader) makes those parts glow hotter.

const GLOW_SHADER := preload("res://game/theme/fx/shaders/vehicle_glow.gdshader")

static var _lit_material: StandardMaterial3D
static var _glow_material: ShaderMaterial

var _lit := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _lit_count := 0
var _glow_count := 0


func _init() -> void:
	_lit.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow.begin(Mesh.PRIMITIVE_TRIANGLES)


## A lit box. `rotation` in radians (XYZ Euler), applied about the box center.
func box(size: Vector3, center: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	_add_box(_lit, size, Transform3D(Basis.from_euler(rotation), center), Color(color, 1.0))
	_lit_count += 1


## An emissive box. heat_mask 1 = this part glows with `heat` (barrels, vents).
func glow_box(size: Vector3, center: Vector3, color: Color, heat_mask := 0.0, rotation := Vector3.ZERO) -> void:
	_add_box(_glow, size, Transform3D(Basis.from_euler(rotation), center), Color(color, heat_mask))
	_glow_count += 1


## A lit cylinder along the local axis given by `basis` (+Y of the basis), approximated by `sides`.
func cylinder(radius_bottom: float, radius_top: float, height: float, xform: Transform3D, color: Color, sides := 8, glow := false, heat_mask := 0.0) -> void:
	var tool := _glow if glow else _lit
	var tint := Color(color, heat_mask if glow else 1.0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0) * radius_bottom, -height / 2.0, sin(a0) * radius_bottom)
		var b1 := Vector3(cos(a1) * radius_bottom, -height / 2.0, sin(a1) * radius_bottom)
		var t0 := Vector3(cos(a0) * radius_top, height / 2.0, sin(a0) * radius_top)
		var t1 := Vector3(cos(a1) * radius_top, height / 2.0, sin(a1) * radius_top)
		var normal := Vector3(cos((a0 + a1) / 2.0), 0.0, sin((a0 + a1) / 2.0))
		_quad(tool, xform, [b1, t1, t0, b0], xform.basis * normal, tint)
		_triangle(tool, xform, [Vector3(0, height / 2.0, 0), t0, t1], xform.basis * Vector3.UP, tint)
		_triangle(tool, xform, [Vector3(0, -height / 2.0, 0), b1, b0], xform.basis * Vector3.DOWN, tint)
	if glow:
		_glow_count += 1
	else:
		_lit_count += 1


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _lit_count > 0:
		_lit.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, lit_material())
	if _glow_count > 0:
		_glow.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, glow_material())
	return mesh


static func lit_material() -> StandardMaterial3D:
	if _lit_material == null:
		_lit_material = StandardMaterial3D.new()
		_lit_material.vertex_color_use_as_albedo = true
		_lit_material.roughness = 0.45
		_lit_material.metallic = 0.45
	return _lit_material


static func glow_material() -> ShaderMaterial:
	if _glow_material == null:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = GLOW_SHADER
	return _glow_material


static func _add_box(tool: SurfaceTool, size: Vector3, xform: Transform3D, color: Color) -> void:
	var h := size / 2.0
	var faces := [
		[Vector3.RIGHT, [Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3.UP, [Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3.DOWN, [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z)]],
		[Vector3.BACK, [Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]],
	]
	for face in faces:
		_quad(tool, xform, face[1], (xform.basis * face[0]).normalized(), color)


## Quad corners in order (clockwise seen from outside, Godot's front-face winding).
static func _quad(tool: SurfaceTool, xform: Transform3D, corners: Array, normal: Vector3, color: Color) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(xform * (corners[index] as Vector3))


static func _triangle(tool: SurfaceTool, xform: Transform3D, corners: Array, normal: Vector3, color: Color) -> void:
	for corner in corners:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(xform * (corner as Vector3))
