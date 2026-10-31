class_name SightScreenProp
extends Node3D
## `prop.sight_screen` (mapkit P3, round 47): the `sight` cover class's look. PLACEHOLDER until the lead picks a direction
## on the looks page (https://claude.ai/artifact/WSBf2Wmmar3BSocBqqrRpm): the strip curtain (direction B, the cheapest
## and opaque), drawn inside ArenaKit's 14 x 6 x 0.6 m box so what blinds an eye is what you see. Two draws: the frame
## and its neon (one mesh each), the strips (one MultiMesh). Visual only; the body is Arena's (_build_screens).

const SIZE := Vector3(14.0, 6.0, 0.6)
const STRIPS := 22
const TARP := Color(0.11, 0.12, 0.13)
const AD_TARP := Color(0.32, 0.12, 0.22)

var _strips := MultiMeshInstance3D.new()


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func setup(_prop: Dictionary) -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	var frame := CyberMaterials.surface(Color(0.24, 0.25, 0.28), 0.5, 0.5)
	for side in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(0.5, SIZE.y, 0.5), Vector3(side * (SIZE.x / 2.0 - 0.25), SIZE.y / 2.0, 0.0), frame)
	CyberMaterials.box(self, Vector3(SIZE.x, 0.5, SIZE.z), Vector3(0, SIZE.y - 0.25, 0.0), frame)
	CyberMaterials.box(self, Vector3(SIZE.x, 0.12, 0.08), Vector3(0, SIZE.y - 0.25, SIZE.z / 2.0 - 0.04),
			CyberMaterials.neon(CyberMaterials.CYAN, 3.0, 0.0), false)
	var strip := BoxMesh.new()
	strip.size = Vector3(1.0, 1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	strip.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = strip
	FxMultiMesh.resize(multimesh, STRIPS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var inner := SIZE.x - 1.0
	for i in STRIPS:
		var x := -inner / 2.0 + inner * (i + 0.5) / STRIPS
		var length := SIZE.y - 0.5 if rng.randf() > 0.15 else rng.randf_range(3.0, 4.5)
		var basis := Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03)).scaled(Vector3(0.58, length, 0.05))
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, SIZE.y - 0.5 - length / 2.0, rng.randf_range(-0.08, 0.08))))
		multimesh.set_instance_color(i, AD_TARP if i % 5 == 2 else TARP)
	_strips.multimesh = multimesh
	_strips.name = "Strips"
	FxMultiMesh.never_interpolated(_strips)
	add_child(_strips)
