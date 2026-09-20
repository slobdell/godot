class_name SelectionMarkers
extends Node3D
## C2/C5: flat rings on the ground under vehicles, drawn in 3D with depth testing so a vehicle always
## covers its own ring (the old 2D circles were painted over the models).
##   selected squad     a bright ring in the team color; the commander's ring is gold; the focused unit's white
##   our other units    a faint thin team-colored ring (so "whose is it" reads at a glance)
##   enemies in sight   a faint enemy-colored DASHED ring (never for enemies hidden by the fog); the dashes
##                      tell friend from foe without relying on color (accessibility)
##   inspected enemy    a bright enemy-colored ring (round 3: clicking an enemy inspects it)
## Round 3 (RtsControls): set `selection` and the rings follow it (per unit, no commander); `map` is the legacy
## squad-grammar TacticalMap.
## The command stream owns what is shown when; colors come from GameTheme.ui (art owns the palette).

## Round 9 (CP2): THE MARKER IS SHAPED LIKE THE VEHICLE, not a circle round its longest side.
##
## It used to be a circle of `max(hull.x, hull.z) * 0.75`. That was right for a 3.6 m hull. After the resize the
## Condemned tank is **8.62 m long and still 2.40 m wide**, so its ring became **12.9 m across** — a circle you could
## park two tanks abreast inside — and a squad in close formation drew a cloverleaf nobody could read a unit out of.
##
## Scaling the old annulus by the hull box does not fix it: at 3.6:1 the band comes out 3.6x thicker at the ends
## than at the sides, which reads as broken rather than shaped. So the ring is drawn in the FRAGMENT SHADER as a
## signed-distance rounded rectangle (`corner radius = half-width`, i.e. a capsule along the hull), from per-instance
## half-extents, and the band is a constant thickness IN METRES at any aspect ratio. One MultiMesh of unit quads per
## kind, exactly as before: **no new draw calls** (the HUD's budget is 130 and the whole HUD is ~90).
## Clearance between the hull box and the inside of the band.
const MARGIN_M := 0.55
## The band's own thickness, in metres, the same for every vehicle from the 2.93 m rat rod to the 14 m rig.
const BAND_M := 0.34
## Just above the fog-of-war plane (0.08 m) so fog never tints the ring.
const HEIGHT := 0.12
const SELECTED_ALPHA := 0.95
const IDLE_ALPHA := 0.4
const ENEMY_ALPHA := 0.7

var game_match: Match
var map: TacticalMap
## Round 3: the player's unit selection (takes precedence over `map`).
var selection: Selection
## Tests without fog of war: every enemy counts as seen.
var reveal_all := false
var team := Match.Team.GREEN

## Round 5 (X4, CP1): one MultiMesh per ring kind, not a mesh per vehicle (render counted 61 separate draws at 30 a side).
const KINDS := ["selected", "friendly", "enemy", "inspected", "commander", "focused"]

var _layers := {}  # kind → MultiMeshInstance3D
var _rings := {}  # tank name → {"kind", "visible", "position"}
var _materials := {}  # key → StandardMaterial3D
static var _quad: ArrayMesh
static var _shader: Shader


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Placed every rendered frame at where vehicles are drawn (Shown), so not interpolated again.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	refresh()


## What each ring shows, as data (tests read this): tank name → {"kind", "visible", "position"}. A ring that is hidden
## keeps the last kind it showed.
func state() -> Dictionary:
	return _rings.duplicate(true)


## The MultiMeshInstance3D that draws every ring of `kind` (created on first use).
func layer(kind: String) -> MultiMeshInstance3D:
	if _layers.has(kind):
		return _layers[kind]
	var instance := MultiMeshInstance3D.new()
	instance.name = "Rings_" + kind
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = _material(kind)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _quad_mesh()
	multimesh.use_custom_data = true  # per instance: the hull's half-extents and the band's thickness, in metres
	instance.multimesh = multimesh
	# The rings are placed every rendered frame at where the vehicles are drawn (Shown), so the renderer must not
	# interpolate them on top of that (render's FxMultiMesh: the node switch and the server flag, both of which matter).
	FxMultiMesh.never_interpolated(instance)
	add_child(instance)
	_layers[kind] = instance
	return instance


func refresh() -> void:
	if game_match == null:
		return
	var seen := {}
	var placed := {}  # kind → Array[Transform3D]
	var selected: Squad = map.selected() if map != null else null
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		var tank_name := String(tank.name)
		seen[tank_name] = true
		var kind := ""
		if tank.is_alive():
			if selection != null:
				if tank.team == team:
					kind = "selected" if selection.units.has(tank_name) else "friendly"
				elif selection.inspected == tank_name and (reveal_all or game_match.is_visible_to(team, tank)):
					kind = "inspected"
				elif reveal_all or game_match.is_visible_to(team, tank):
					kind = "enemy"
			elif tank.team == team:
				if selected != null and selected.roster.has(tank_name):
					kind = "commander" if selected.commander == tank_name else "selected"
					if map.focused_unit == tank_name:
						kind = "focused"
				else:
					kind = "friendly"
			elif game_match.is_visible_to(team, tank):
				kind = "enemy"
		var ring: Dictionary = _rings.get_or_add(tank_name, {"kind": "", "visible": false, "position": Vector3.ZERO})
		ring["visible"] = kind != ""
		if kind == "":
			continue
		ring["kind"] = kind
		# The hull's own box, READ not mirrored (Invariant 0): x is the width, z is the length.
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var half := Vector2(float(hull[0]) * 0.5 + MARGIN_M, float(hull[2]) * 0.5 + MARGIN_M)
		var at := Shown.ground(tank) + Vector3.UP * HEIGHT
		ring["position"] = at
		ring["half"] = half
		# The quad covers the shape plus its band; the shader draws the band inside it. Turned with the hull, so a
		# long vehicle's marker lies along the vehicle instead of swallowing its neighbours.
		# `Shown.forward` is where the hull is DRAWN to point, not where physics has it this tick: the marker must sit
		# under the vehicle the player can see (the same reason Shown.ground is used for the position).
		var ahead := Shown.forward(tank)
		var basis := Basis(Vector3.UP, atan2(-ahead.x, -ahead.z)).scaled(Vector3(half.x + BAND_M, 1.0, half.y + BAND_M))
		(placed.get_or_add(kind, []) as Array).append([Transform3D(basis, at), half])
	for tank_name in _rings.keys():
		if not seen.has(tank_name):
			_rings.erase(tank_name)
	for kind: String in KINDS:
		var transforms: Array = placed.get(kind, [])
		if transforms.is_empty() and not _layers.has(kind):
			continue
		var multimesh := layer(kind).multimesh
		if multimesh.instance_count < transforms.size():
			# Grow in steps: resizing reallocates the buffer (and clears the server's no-interpolation flag, which
			# FxMultiMesh.resize re-asserts).
			FxMultiMesh.resize(multimesh, transforms.size() + 8)
		multimesh.visible_instance_count = transforms.size()
		for i in transforms.size():
			var half: Vector2 = transforms[i][1]
			multimesh.set_instance_custom_data(i, Color(half.x, half.y, BAND_M, 0.0))
			multimesh.set_instance_transform(i, transforms[i][0])


func _material(kind: String) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var color: Color
	match kind:
		"commander":
			color = Color(GameTheme.ui["commander"], SELECTED_ALPHA)
		"focused":
			color = Color(1, 1, 1, SELECTED_ALPHA)
		"selected":
			color = Color(GameTheme.ui["friendly"], SELECTED_ALPHA)
		"friendly":
			color = Color(GameTheme.ui["friendly"], IDLE_ALPHA)
		"inspected":
			color = Color(GameTheme.ui["enemy"], SELECTED_ALPHA)
		_:
			color = Color(GameTheme.ui["enemy"], ENEMY_ALPHA)
	var material := ShaderMaterial.new()
	material.shader = _ring_shader()
	material.set_shader_parameter("ring_color", color)
	# The enemy marker keeps its dashes: they tell friend from foe without relying on colour (accessibility), and
	# that was the point of the dashed annulus this replaces.
	material.set_shader_parameter("dashes", 12.0 if kind == "enemy" else 0.0)
	# A faint marker for units you have not selected is also a THINNER one, as the thin annulus used to be.
	material.set_shader_parameter("band_scale", 0.55 if kind == "friendly" else 1.0)
	_materials[kind] = material
	return material


## One unit quad in the XZ plane. Every marker is this mesh; its shape comes from the shader and its size from the
## instance transform, so all six kinds still cost one draw call each however many vehicles are on screen.
static func _quad_mesh() -> ArrayMesh:
	if _quad == null:
		var v := PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1),
				Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad


## The marker, as a signed-distance rounded rectangle with a band of CONSTANT WORLD THICKNESS.
##
## `INSTANCE_CUSTOM` carries (half-width, half-length, band metres) for this vehicle, so one material serves a 2.93 m
## rat rod and a 14 m rig without the band getting fatter at the ends - which is exactly what scaling a ring mesh
## non-uniformly does, and why that was not the fix. The corner radius is the half-width, so the shape is a capsule
## lying along the hull: square-ish across a wide vehicle, round-ended on a long one.
static func _ring_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 ring_color : source_color = vec4(1.0);
uniform float dashes = 0.0;
uniform float band_scale = 1.0;

varying vec2 local_m;
varying vec3 shape;

void vertex() {
	shape = INSTANCE_CUSTOM.xyz;                       // half-width, half-length, band (metres)
	local_m = VERTEX.xz * (shape.xy + vec2(shape.z));  // the quad is the shape plus its band
}

void fragment() {
	vec2 h = shape.xy;
	float band = max(shape.z * band_scale, 0.001);
	float r = min(h.x, h.y);                           // capsule: the corner radius is the half-width
	vec2 q = abs(local_m) - h + vec2(r);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float edge = fwidth(d) + 0.0001;
	float on = 1.0 - smoothstep(band * 0.5 - edge, band * 0.5 + edge, abs(d));
	if (dashes > 0.0) {
		float a = atan(local_m.y, local_m.x) / 6.2831853 + 0.5;
		on *= step(fract(a * dashes), 0.5);
	}
	if (on < 0.01) {
		discard;
	}
	ALBEDO = ring_color.rgb;
	ALPHA = ring_color.a * on;
}
"""
	return _shader




## A flat ring in the XZ plane (unit outer radius); with `dashes` > 0, that many gaps break it up.
static func annulus(inner: float, outer: float, segments := 40, dashes := 0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in segments:
		if dashes > 0 and (i * dashes / segments) % 2 == 1:
			continue  # a gap
		var a := TAU * i / segments
		var b := TAU * (i + 1) / segments
		var da := Vector3(cos(a), 0.0, sin(a))
		var db := Vector3(cos(b), 0.0, sin(b))
		vertices.append_array([da * outer, db * outer, da * inner, db * outer, db * inner, da * inner])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
