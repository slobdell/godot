class_name BurstSystem
extends Node3D
## Short-lived effects (flipbook fireballs, muzzle-flash stars, ground glows) in one pooled
## MultiMesh with one shared material: one draw call however many are alive. Starting an effect
## writes one instance into a ring buffer; the shader animates and hides it by its start time.
## Replaces the old per-hit SphereMesh + StandardMaterial3D allocation in Impact.

const SHADER := preload("res://game/theme/fx/shaders/burst.gdshader")
const ATLAS := preload("res://game/theme/fx/textures/explosion_flipbook.png")
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

enum Kind { FIREBALL, STAR, GROUND_GLOW, SHOCKWAVE, SMOKE, SCORCH, SPARKS, DEBRIS, FLARE }

## Kinds that are atmosphere rather than information: when the overdraw budget is spent they shrink, then drop.
const DECORATIVE := [Kind.GROUND_GLOW, Kind.SMOKE, Kind.SHOCKWAVE]
## Below this fraction of its size a decorative effect isn't worth drawing.
const MIN_DECORATIVE_SCALE := 0.45

var material := ShaderMaterial.new()
## Effects started since load (for the bench and tests).
var started := 0
## Render X5 (round 5): how much additive area (m², size² per effect) may be alive at once before decorative effects
## thin out. Bursts were 1.3 ms GPU of a 30-a-side fight on the UHD 620, almost all overdraw. 0 = no limit.
var overdraw_budget := 0.0
## Decorative effects shrunk or skipped by the budget (for the bench and tests).
var thinned := 0
## Area alive at the last update() (m²).
var alive_area := 0.0

var _mesh := MultiMeshInstance3D.new()
var _next := 0
# Per slot: when it stops drawing (s) and its area (m²), for the overdraw budget.
var _ends := PackedFloat32Array()
var _areas := PackedFloat32Array()


func _init(capacity := 64) -> void:
	name = "Bursts"
	material.shader = SHADER
	material.set_shader_parameter("atlas", ATLAS)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	_mesh.name = "BurstMesh"
	_mesh.multimesh = multimesh
	FxMultiMesh.never_interpolated(_mesh)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.custom_aabb = WORLD_AABB
	add_child(_mesh)
	resize(capacity)


func capacity() -> int:
	return _mesh.multimesh.instance_count


func resize(new_capacity: int) -> void:
	var multimesh := _mesh.multimesh
	FxMultiMesh.resize(multimesh, maxi(new_capacity, 1))
	_ends.resize(multimesh.instance_count)
	_ends.fill(-1000.0)
	_areas.resize(multimesh.instance_count)
	_areas.fill(0.0)
	# Every slot starts expired (start far in the past) so nothing draws until used.
	for i in multimesh.instance_count:
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
		multimesh.set_instance_color(i, Color.WHITE)
		multimesh.set_instance_custom_data(i, Color(-1000.0, 0.001, 0.0, 0.0))
	_next = 0


## Advance the shader clock. `now` must be the same clock passed to spawn().
func update(now: float) -> void:
	material.set_shader_parameter("now", now)
	var total := 0.0
	for i in _ends.size():
		if _ends[i] > now:
			total += _areas[i]
	alive_area = total


## How much of its size a new effect of `kind` may draw at, given what's alive (1 = full; 0 = skip). Pure, for tests.
static func budget_scale(kind: int, size: float, alive: float, budget: float) -> float:
	if budget <= 0.0 or not DECORATIVE.has(kind):
		return 1.0
	var room := budget - alive
	if room >= size * size:
		return 1.0
	var scale := sqrt(maxf(room, 0.0)) / maxf(size, 0.001)
	return scale if scale >= MIN_DECORATIVE_SCALE else 0.0


## Sparks and debris chunks drawn per spray (a quality-tier budget: each is a loop step per pixel of the spray).
func set_spray_count(count: int) -> void:
	material.set_shader_parameter("spray_count", count)


## Start an effect. `color.a` is the kind's variant (smoke darkness, debris chunkiness). Moving effects (smoke rings,
## thrown dust) drift from `position` at `velocity`, slowed by `drag` (1/s), pulled down by `gravity` (m/s²), and
## lifted at `rise` (m/s); the shader integrates it, so a moving effect still costs one write.
func spawn(kind: int, position: Vector3, size: float, duration: float, color: Color, now: float,
		velocity := Vector3.ZERO, drag := 0.0, gravity := 0.0, rise := 0.0) -> void:
	var scale := BurstSystem.budget_scale(kind, size, alive_area, overdraw_budget)
	if scale < 1.0:
		thinned += 1
		if scale <= 0.0:
			return
		size *= scale
	alive_area += size * size
	_ends[_next] = now + duration
	_areas[_next] = size * size
	var multimesh := _mesh.multimesh
	# The basis carries motion, not rotation (see burst.gdshader).
	multimesh.set_instance_transform(_next, Transform3D(Basis(velocity, Vector3(drag, gravity, rise), Vector3.ZERO), position))
	multimesh.set_instance_color(_next, color)
	multimesh.set_instance_custom_data(_next, Color(now, duration, size, float(kind)))
	_next = (_next + 1) % multimesh.instance_count
	started += 1
