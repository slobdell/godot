class_name CrowdSystem
extends Node3D
## The arena crowd (art X5): every spectator in one MultiMesh (one draw call), animated in crowd.gdshader. The arena
## dressing gives it seat rows; the crowd reacts to FxWorld.spectacle (kills roar, hits ripple near the action) and
## settles back to a murmur. The tier sets how many people are drawn (visible_instance_count), never the seating.
## Visual only: nothing here reads or changes the simulation.

const SHADER := preload("res://game/theme/fx/shaders/crowd.gdshader")
const ATLAS := preload("res://game/theme/cyberpunk/crowd/crowd_atlas.png")
## People drawn per quality tier (FxQuality): phones show a thinner crowd.
const PER_TIER := {FxQuality.Tier.LOW: 900, FxQuality.Tier.MEDIUM: 1800, FxQuality.Tier.HIGH: 4000}
## The crowd's resting mood and how fast a roar dies down (per second).
const CALM := 0.12
const SETTLE := 0.35
const EVENT_RADIUS := 90.0
## Clothes: grimy darks and worn denim/leather (never saturated: art_direction.md), with a few fans in team neon.
const PALETTE := [Color(0.26, 0.25, 0.25), Color(0.19, 0.21, 0.26), Color(0.33, 0.28, 0.23), Color(0.23, 0.23, 0.21),
		Color(0.4, 0.38, 0.35), Color(0.3, 0.2, 0.17), Color("#0898A4"), Color("#A80E62")]
const NEON_FANS := 0.06

var excitement := CALM
var multimesh_instance := MultiMeshInstance3D.new()
var material := ShaderMaterial.new()
var seats := PackedVector3Array()
var _event := Vector4(0.0, 0.0, EVENT_RADIUS, 0.0)
var _rng := RandomNumberGenerator.new()
## Sound: the crowd's murmur and roar are the audio stream's CrowdVoice (game/theme/audio/crowd_voice.gd, round 5),
## made only when there is an FxWorld to play it: built unconditionally, it leaked on headless peers (relay-smoke).
var voice: CrowdVoice


func _init() -> void:
	name = "Crowd"
	material.shader = SHADER
	material.set_shader_parameter("atlas", ATLAS)
	multimesh_instance.name = "CrowdMesh"
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(multimesh_instance)


func _ready() -> void:
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.spectacle.connect(react)
		fx.quality_changed.connect(apply_quality)
		voice = CrowdVoice.new()
		add_child(voice)


## Seats along rows: each row is [from: Vector3, to: Vector3] (world space, feet height). `spacing` meters between
## people, `occupancy` 0..1 of seats filled. Seeded, so the same arena always has the same crowd.
func seat_rows(rows: Array, spacing := 0.85, occupancy := 0.85, seed := 1409) -> void:
	_rng.seed = seed
	seats.clear()
	for row in rows:
		var from: Vector3 = row[0]
		var to: Vector3 = row[1]
		var count := int(from.distance_to(to) / spacing)
		for i in count:
			if _rng.randf() > occupancy:
				continue
			var t := (i + 0.5 + _rng.randf_range(-0.2, 0.2)) / count
			seats.append(from.lerp(to, t) + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.15, 0.15)))
	_build()


func _build() -> void:
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	quad.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	FxMultiMesh.resize(multimesh, seats.size())
	# Shuffle draw order so a thinner tier drops people evenly instead of whole stands.
	var order := range(seats.size())
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var bounds := AABB()
	for n in order.size():
		var seat := seats[order[n]]
		var height := _rng.randf_range(1.6, 1.95)  # the quad is 1 m tall and 2 m wide before scaling: a 64 × 128 figure
		multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * height), seat))
		var tint: Color = PALETTE[6 + _rng.randi() % 2] if _rng.randf() < NEON_FANS else PALETTE[_rng.randi() % 6]
		multimesh.set_instance_color(n, tint * _rng.randf_range(0.8, 1.15))
		multimesh.set_instance_custom_data(n, Color(_rng.randf(), _rng.randf(), (seat.x + 500.0) / 1000.0, (seat.z + 500.0) / 1000.0))
		bounds = AABB(seat, Vector3.ONE) if n == 0 else bounds.expand(seat)
	multimesh_instance.multimesh = multimesh
	FxMultiMesh.never_interpolated(multimesh_instance)
	multimesh_instance.custom_aabb = bounds.grow(3.0)
	apply_quality()


func apply_quality() -> void:
	if multimesh_instance.multimesh != null:
		multimesh_instance.multimesh.visible_instance_count = mini(seats.size(), PER_TIER[FxQuality.tier()])


## A hit or kill at `position`: the whole crowd lifts a little, the stands nearby erupt.
func react(position: Vector3, weight: float) -> void:
	excitement = clampf(maxf(excitement, CALM + weight * 0.75), 0.0, 1.0)
	if weight >= _event.w * 0.6:
		_event = Vector4(position.x, position.z, EVENT_RADIUS, clampf(weight, 0.0, 1.0))


func _process(delta: float) -> void:
	excitement = move_toward(excitement, CALM, SETTLE * delta)
	_event.w = move_toward(_event.w, 0.0, SETTLE * 0.8 * delta)
	material.set_shader_parameter("excitement", excitement)
	material.set_shader_parameter("event_position", _event)


func drawn_count() -> int:
	return multimesh_instance.multimesh.visible_instance_count if multimesh_instance.multimesh != null else 0
