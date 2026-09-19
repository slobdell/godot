class_name TracerSystem
extends Node3D
## Every projectile in flight drawn as one tracer MultiMesh plus one ground-splat MultiMesh
## (two draw calls total). Projectile visuals (the `fx.shell` slot) register themselves; each
## frame this copies their transforms into the buffers and asks the LightPool for a light
## for each (only the best few get one).

const TRACER_SHADER := preload("res://game/theme/fx/shaders/tracer.gdshader")
const SPLAT_SHADER := preload("res://game/theme/fx/shaders/splat.gdshader")

## Buffers grow in steps of this many instances (rarely: a big firefight has ~40 shells in flight).
const GROW := 32
## Everything a tracer can reach, so the MultiMesh is never frustum-culled by accident.
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

## How each kind of round draws (feel X2/X3), by K2 fire model: tracer tail and width (m), brightness, the ground
## splat under it (m, brightness at ground level), and the light it asks the pool for. "default" is round 2's look.
## Render (round 5): every style roughly halved in width, splat and brightness so rounds read as fire, not as the subject.
const STYLES := {
	"default": {"tail": 5.0, "width": 0.3, "intensity": 1.0, "splat_width": 2.2, "splat_length": 6.0, "splat_intensity": 0.3,
			"light_energy": 2.5, "light_range": 9.0, "priority": LightPool.PRIORITY_TRACER},
	# The tank shell: a white-hot slug you can follow, dragging a pool of light along the floor.
	"shell": {"tail": 7.0, "width": 0.55, "intensity": 1.5, "splat_width": 3.5, "splat_length": 9.0, "splat_intensity": 0.5,
			"light_energy": 6.0, "light_range": 15.0, "priority": LightPool.PRIORITY_SHELL},
	# Round 6: up with the stream below (a 25 mm round stays the fatter, heavier tracer of the two).
	"burst": {"tail": 5.5, "width": 0.42, "intensity": 2.0, "splat_width": 2.0, "splat_length": 5.5, "splat_intensity": 0.32,
			"light_energy": 1.8, "light_range": 6.0, "priority": LightPool.PRIORITY_TRACER},
	# Round 6 (the lead: "I'm not seeing any cool machine gun fire from the scouts"): at round 5's halved style and
	# HITSCAN_SPEED a scout's 10 rounds/s at 26 m left about one thin 4 m dash on screen at a time, a speck from the RTS
	# camera. A stream now flies slower (its own `speed`) so 3-4 rounds are in the air at once, with a longer, hotter
	# tail: a hose of fire you can follow from gun to target.
	"stream": {"tail": 8.0, "width": 0.32, "intensity": 2.4, "splat_width": 1.6, "splat_length": 6.0, "splat_intensity": 0.3,
			"light_energy": 1.2, "light_range": 4.5, "priority": LightPool.PRIORITY_TRACER - 0.3, "speed": 90.0},
	"arc": {"tail": 5.0, "width": 0.45, "intensity": 1.2, "splat_width": 2.8, "splat_length": 6.0, "splat_intensity": 0.4,
			"light_energy": 3.0, "light_range": 10.0, "priority": LightPool.PRIORITY_TRACER + 0.5},
	# A round glancing off armor: a short hot streak, no light of its own.
	"ricochet": {"tail": 2.2, "width": 0.12, "intensity": 1.6, "splat_width": 0.0, "splat_length": 0.0, "splat_intensity": 0.0,
			"light_energy": 0.0, "light_range": 0.0, "priority": 0.0},
}
## Rounds without a node (hitscan streams, ricochets): drawn from data in a ring buffer, oldest replaced when full.
const MAX_ROUNDS := 256
## How fast a hitscan round visibly travels (m/s): fast, but slow enough to see each tracer for a few frames.
const HITSCAN_SPEED := 180.0

## A splat fades out as its projectile climbs above this height (m).
var splat_fade_height := 6.0
var splats_enabled := true
var lights_enabled := true

## Registered projectile visuals → [tint color, style Dictionary].
var _sources: Dictionary = {}
## Virtual rounds (parallel arrays, ring buffer): from, direction, length (m), speed (m/s), start (s), color, style.
var _round_from := PackedVector3Array()
var _round_direction := PackedVector3Array()
var _round_length := PackedFloat32Array()
var _round_speed := PackedFloat32Array()
var _round_start := PackedFloat32Array()
var _round_color := PackedColorArray()
var _round_style: Array[Dictionary] = []
var _next_round := 0
var _rounds_used := 0
var _tracers := MultiMeshInstance3D.new()
var _splats := MultiMeshInstance3D.new()


func _init() -> void:
	name = "Tracers"
	_tracers.name = "TracerMesh"
	_tracers.multimesh = _make_multimesh(_quad(), TRACER_SHADER)
	FxMultiMesh.never_interpolated(_tracers)
	_splats.name = "SplatMesh"
	_splats.multimesh = _make_multimesh(_plane(), SPLAT_SHADER)
	FxMultiMesh.never_interpolated(_splats)
	for instance in [_tracers, _splats]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.custom_aabb = WORLD_AABB
		add_child(instance)
	for array in [_round_from, _round_direction]:
		array.resize(MAX_ROUNDS)
	for array in [_round_length, _round_speed, _round_start]:
		array.resize(MAX_ROUNDS)
	_round_color.resize(MAX_ROUNDS)
	_round_style.resize(MAX_ROUNDS)


func add(source: Node3D, color: Color, style := "default") -> void:
	_sources[source] = [color, STYLES.get(style, STYLES["default"])]


func remove(source: Node3D) -> void:
	_sources.erase(source)


func active_count() -> int:
	return _tracers.multimesh.visible_instance_count


## A round with no node, flying from `from` to `to` (a hitscan stream's tracer, a ricochet) at `speed` m/s (-1 = the
## hitscan speed), started at `now` on FxWorld's clock. Returns its index.
func shoot(from: Vector3, to: Vector3, color: Color, style: String, now: float, speed := -1.0) -> int:
	var offset := to - from
	if offset.length() < 0.05:
		return -1
	var index := _next_round
	_round_from[index] = from
	_round_direction[index] = offset.normalized()
	_round_length[index] = offset.length()
	var drawn: Dictionary = STYLES.get(style, STYLES["default"])
	_round_speed[index] = speed if speed > 0.0 else float(drawn.get("speed", HITSCAN_SPEED))
	_round_start[index] = now
	_round_color[index] = color
	_round_style[index] = drawn
	_next_round = (_next_round + 1) % MAX_ROUNDS
	_rounds_used = mini(_rounds_used + 1, MAX_ROUNDS)
	return index


func newest_round() -> int:
	return (_next_round - 1 + MAX_ROUNDS) % MAX_ROUNDS


func round_end(index: int) -> Vector3:
	return _round_from[index] + _round_direction[index] * _round_length[index]


## Where round `index`'s head is at `now` (it stops at its end).
func round_head(index: int, now: float) -> Vector3:
	var travelled := clampf((now - _round_start[index]) * _round_speed[index], 0.0, _round_length[index])
	return _round_from[index] + _round_direction[index] * travelled


## Whether round `index` is drawn at `now`: from its start until its tail has caught up with its end.
func round_alive(index: int, now: float) -> bool:
	if _round_style[index].is_empty():
		return false
	var travelled := (now - _round_start[index]) * _round_speed[index]
	return travelled >= 0.0 and travelled < _round_length[index] + float(_round_style[index]["tail"])


func active_count_at(now: float) -> int:
	var count := 0
	for i in _rounds_used:
		count += 1 if round_alive(i, now) else 0
	return count


## Copy this frame's projectiles into the buffers. Called by FxWorld once per frame with its clock.
func update(pool: LightPool, now := 0.0) -> void:
	var tracers := _tracers.multimesh
	var splats := _splats.multimesh
	var wanted := _sources.size() + _rounds_used
	if wanted > tracers.instance_count:
		var size := (wanted / GROW + 1) * GROW
		FxMultiMesh.resize(tracers, size)
		FxMultiMesh.resize(splats, size)
	var n := 0
	for key in _sources:
		if not is_instance_valid(key) or not (key as Node3D).is_visible_in_tree():
			continue
		var source := key as Node3D
		var entry: Array = _sources[key]
		var xform := FxWorld.visual_transform(source).orthonormalized()
		var style: Dictionary = entry[1]
		_write(n, xform, entry[0], style, float(style["tail"]), pool)
		n += 1
	for i in _rounds_used:
		if not round_alive(i, now):
			continue
		var travelled := (now - _round_start[i]) * _round_speed[i]
		var head := round_head(i, now)
		var style: Dictionary = _round_style[i]
		# The tail never reaches back past the muzzle, and shrinks into the end once the round has arrived.
		var tail := minf(float(style["tail"]), travelled) - maxf(0.0, travelled - _round_length[i])
		var up := Vector3.UP if absf(_round_direction[i].y) < 0.99 else Vector3.RIGHT
		var xform := Transform3D(Basis.looking_at(_round_direction[i], up), head)
		_write(n, xform, _round_color[i], style, maxf(tail, 0.01), pool)
		n += 1
	tracers.visible_instance_count = n
	splats.visible_instance_count = n if splats_enabled else 0


func _write(n: int, xform: Transform3D, color: Color, style: Dictionary, tail: float, pool: LightPool) -> void:
	var tracers := _tracers.multimesh
	var splats := _splats.multimesh
	tracers.set_instance_transform(n, xform)
	tracers.set_instance_color(n, color)
	tracers.set_instance_custom_data(n, Color(tail, style["width"], style["intensity"], 0.0))
	var head := xform.origin
	var height_fade := clampf(1.0 - head.y / splat_fade_height, 0.0, 1.0)
	var forward := -xform.basis.z
	var yaw := atan2(-forward.x, -forward.z)
	var splat_basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(maxf(style["splat_width"], 0.001), 1.0, maxf(style["splat_length"], 0.001)))
	splats.set_instance_transform(n, Transform3D(splat_basis, Vector3(head.x, 0.05, head.z)))
	splats.set_instance_color(n, color)
	splats.set_instance_custom_data(n, Color(height_fade * float(style["splat_intensity"]) if splats_enabled else 0.0, 0, 0, 0))
	if lights_enabled and float(style["light_energy"]) > 0.0:
		pool.request(head, color, style["light_energy"], style["light_range"], style["priority"])


static func _make_multimesh(mesh: Mesh, shader: Shader) -> MultiMesh:
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	FxMultiMesh.resize(multimesh, GROW)
	multimesh.visible_instance_count = 0
	return multimesh


static func _quad() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return _baked(quad)


static func _plane() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	return _baked(plane)


## Primitive meshes can't hold a surface material via surface_set_material; bake to an ArrayMesh.
static func _baked(primitive: PrimitiveMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
	return mesh
