class_name ContainerMesh
extends RefCounted
## One ISO shipping container as a single ~300-triangle mesh (assets X1), built in code so a 40 ft container is its own
## mesh with tiled UVs rather than a stretched 20 ft one. Long axis along X, doors at +X, origin at the ground center.
##
## Attributes the container shader reads (container.gdshader):
##   UV      meters / TILE_M on every face, so every kind shares the texture set at the same texel density
##   UV2     side panels: panel meters (x from the center as seen from outside, y up) for the stencil band;
##           other faces: a code in y: CODE_CORRUGATED (roof, front wall, doors), CODE_FRAME (flat steel), CODE_INTERIOR;
##           on door leaves x = ± the hinge x (+ = left leaf, hinged at +Z; - = right leaf), 0 elsewhere
## No vertex colors: the Compatibility renderer multiplies them by MultiMesh instance colors, which are zero when unused.

const WIDTH := 2.44
const HEIGHT := 2.59
const FRAME := 0.14
const RAIL := 0.16
const TILE_M := 2.4
## Hinges sit just outside the corner posts, so an open door folds flat against the outside of the side wall.
const HINGE_OUTSET := 0.02
const CODE_CORRUGATED := -1.0
const CODE_FRAME := -3.0
const CODE_INTERIOR := -5.0
const INTERIOR_DEPTH := 0.6

var _tool := SurfaceTool.new()


static func build(length: float) -> ArrayMesh:
	return ContainerMesh.new()._build(length)


func _build(length: float) -> ArrayMesh:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := length / 2.0
	var hw := WIDTH / 2.0
	var inner := Vector2(hl - FRAME, hw - FRAME)
	var panel_y := Vector2(RAIL, HEIGHT - RAIL)
	# Corrugated side walls, recessed 2 cm inside the frame. Stencil coordinates read left to right from outside.
	for side in [1.0, -1.0]:
		var z: float = side * (hw - 0.02)
		_quad([Vector3(-inner.x, panel_y.x, z), Vector3(inner.x, panel_y.x, z), Vector3(inner.x, panel_y.y, z), Vector3(-inner.x, panel_y.y, z)],
				Vector3(0, 0, side), func(p: Vector3) -> Vector2: return Vector2(p.x * side, p.y), func(p: Vector3) -> Vector2: return Vector2(p.x * side, p.y))
	# Roof (ribs run across the width, so the profile varies along the length) and the blind front wall.
	var roof := HEIGHT - 0.03
	_quad([Vector3(-inner.x, roof, -hw + 0.02), Vector3(inner.x, roof, -hw + 0.02), Vector3(inner.x, roof, hw - 0.02), Vector3(-inner.x, roof, hw - 0.02)],
			Vector3.UP, func(p: Vector3) -> Vector2: return Vector2(p.x, p.z), _code(CODE_CORRUGATED))
	var front := -hl + 0.02
	_quad([Vector3(front, panel_y.x, -inner.y), Vector3(front, panel_y.x, inner.y), Vector3(front, panel_y.y, inner.y), Vector3(front, panel_y.y, -inner.y)],
			Vector3.LEFT, func(p: Vector3) -> Vector2: return Vector2(p.z, p.y), _code(CODE_CORRUGATED))
	# The dark interior, seen only when the doors are open.
	var back := hl - INTERIOR_DEPTH
	var dark := _code(CODE_INTERIOR)
	var flat := func(p: Vector3) -> Vector2: return Vector2(p.z, p.y)
	_quad([Vector3(back, panel_y.x, -inner.y), Vector3(back, panel_y.x, inner.y), Vector3(back, panel_y.y, inner.y), Vector3(back, panel_y.y, -inner.y)], Vector3.RIGHT, flat, dark)
	for side in [1.0, -1.0]:
		var z: float = side * (inner.y - 0.01)
		_quad([Vector3(back, panel_y.x, z), Vector3(hl - 0.06, panel_y.x, z), Vector3(hl - 0.06, panel_y.y, z), Vector3(back, panel_y.y, z)], Vector3(0, 0, -side), flat, dark)
	for level in [panel_y.x + 0.01, panel_y.y - 0.01]:
		var normal := Vector3.UP if level < HEIGHT / 2.0 else Vector3.DOWN
		_quad([Vector3(back, level, -inner.y), Vector3(hl - 0.06, level, -inner.y), Vector3(hl - 0.06, level, inner.y), Vector3(back, level, inner.y)], normal, flat, dark)
	# Door leaves: corrugated outside, flat steel inside, two locking bars each. Tagged so the shader can swing them.
	var door_x := hl - 0.06
	var hinge_x := hl + HINGE_OUTSET
	for side in [1.0, -1.0]:
		var tag: float = side * hinge_x
		var z0 := 0.0
		var z1: float = side * inner.y
		_quad([Vector3(door_x, panel_y.x, z0), Vector3(door_x, panel_y.x, z1), Vector3(door_x, panel_y.y, z1), Vector3(door_x, panel_y.y, z0)],
				Vector3.RIGHT, func(p: Vector3) -> Vector2: return Vector2(p.z, p.y), _code(CODE_CORRUGATED, tag))
		_quad([Vector3(door_x - 0.03, panel_y.x, z0), Vector3(door_x - 0.03, panel_y.x, z1), Vector3(door_x - 0.03, panel_y.y, z1), Vector3(door_x - 0.03, panel_y.y, z0)],
				Vector3.LEFT, func(p: Vector3) -> Vector2: return Vector2(p.z, p.y), _code(CODE_FRAME, tag))
		for bar in [0.28, 0.78]:
			_box(Vector3(hl - 0.03, HEIGHT / 2.0, side * bar * inner.y), Vector3(0.05, HEIGHT - 0.45, 0.06), tag)
	# The steel frame: corner posts, side rails, end headers and sills, corner castings.
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			_box(Vector3(sx * (hl - FRAME / 2.0), HEIGHT / 2.0, sz * (hw - FRAME / 2.0)), Vector3(FRAME, HEIGHT - 0.24, FRAME))
			for y in [0.06, HEIGHT - 0.06]:
				_box(Vector3(sx * (hl - 0.09), y, sz * (hw - 0.085)), Vector3(0.18, 0.12, 0.17))
	for sz in [1.0, -1.0]:
		for y in [RAIL / 2.0, HEIGHT - RAIL / 2.0]:
			_box(Vector3(0, y, sz * (hw - 0.06)), Vector3(length - 2.0 * 0.18, RAIL, 0.12))
	for sx in [1.0, -1.0]:
		for y in [0.1, HEIGHT - 0.1]:
			_box(Vector3(sx * (hl - 0.06), y, 0), Vector3(0.12, 0.2, WIDTH - 2.0 * 0.17))
	_tool.index()
	_tool.generate_tangents()
	return _tool.commit()


func _code(code: float, x := 0.0) -> Callable:
	return func(_p: Vector3) -> Vector2: return Vector2(x, code)


## A quad from four corners (any winding) facing `normal`. `uv` maps a point to meters; `uv2` to the second channel.
func _quad(corners: Array, normal: Vector3, uv: Callable, uv2: Callable) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var d: Vector3 = corners[3]
	# Godot's front faces wind clockwise as seen from the side the normal points to.
	var order := [a, b, c, a, c, d] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b, a, d, c]
	for p: Vector3 in order:
		_tool.set_normal(normal)
		_tool.set_uv(uv.call(p) / TILE_M)
		_tool.set_uv2(uv2.call(p))
		_tool.add_vertex(p)


func _box(center: Vector3, size: Vector3, door := 0.0) -> void:
	var h := size / 2.0
	var frame := _code(CODE_FRAME, door)
	for axis in 3:
		for dir in [1.0, -1.0]:
			var normal := Vector3.ZERO
			normal[axis] = dir
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var face := center + normal * h
			var du := u * h
			var dv := v * h
			_quad([face - du - dv, face + du - dv, face + du + dv, face - du + dv], normal,
					func(p: Vector3) -> Vector2: return Vector2(p.dot(u), p.dot(v)), frame)
