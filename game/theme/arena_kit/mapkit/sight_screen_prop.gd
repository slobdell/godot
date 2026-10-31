class_name SightScreenProp
extends Node3D
## `prop.sight_screen` (mapkit, round 47): the `sight` cover class's look, inside ArenaKit's 14 x 6 x 0.6 m box so what
## blinds an eye is where you see it. The lead's pick on the looks page is C, VENT STEAM: five glowing floor grates
## breathing columns of steam. Steam is translucent, and overdraw is what costs the laptop's UHD 620, so it is a HARDWARE
## PRESET knob (C47.10): steam (grates 2 draws + the plumes 1 MultiMesh) on the high FX tier OUTSIDE the laptop render
## preset; everywhere else the opaque strip curtain (direction B: the frame and its neon, the strips 1 MultiMesh).
## `--fx-quality=` / `--render-preset=` pick it; `look` forces one (the gallery's GPU read).
## Visual only; the body is Arena's (_build_screens).

const STEAM_SHADER := preload("res://game/theme/arena_kit/mapkit/steam.gdshader")
const VENTS := 5
const VENT_STEP := 2.8
const GRATE := Vector3(2.2, 0.25, 0.6)
const PLUME := Vector2(2.6, 6.0)
const PLUMES_PER_VENT := 3
const SIZE := Vector3(14.0, 6.0, 0.6)
const STRIPS := 22
const TARP := Color(0.11, 0.12, 0.13)
const AD_TARP := Color(0.32, 0.12, 0.22)

var _strips := MultiMeshInstance3D.new()
## "" = by preset; "steam" or "strips" forces it (tests/mapkit/looks_gallery.gd's --screen-look).
static var look := ""


static func steam_here() -> bool:
	if look != "":
		return look == "steam"
	return FxQuality.tier() == FxQuality.Tier.HIGH and RenderLevers.preset() != "laptop"


func _ready() -> void:
	if get_child_count() == 0:
		_build()


func setup(_prop: Dictionary) -> void:
	if get_child_count() == 0:
		_build()


func _build() -> void:
	if steam_here():
		_build_steam()
	else:
		_build_strips()


func _build_steam() -> void:
	var grates := MapkitYard.surface()
	var slits := MapkitYard.surface()
	for i in VENTS:
		var x := (i - (VENTS - 1) / 2.0) * VENT_STEP
		MapkitYard.box(grates, Transform3D(Basis.IDENTITY, Vector3(x, GRATE.y / 2.0, 0)), GRATE)
		for k in 3:
			MapkitYard.box(slits, Transform3D(Basis.IDENTITY, Vector3(x, GRATE.y + 0.01, -0.18 + 0.18 * k)), Vector3(GRATE.x - 0.3, 0.03, 0.08))
	var mesh := MeshInstance3D.new()
	mesh.name = "Grates"
	mesh.mesh = MapkitYard.two_surfaces(grates, Color(0.16, 0.17, 0.19), 0.5, 0.7, slits, CyberMaterials.ORANGE)
	add_child(mesh)
	var quad := QuadMesh.new()
	quad.size = PLUME
	var material := ShaderMaterial.new()
	material.shader = STEAM_SHADER
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	FxMultiMesh.resize(multimesh, VENTS * PLUMES_PER_VENT)
	for i in VENTS:
		var x := (i - (VENTS - 1) / 2.0) * VENT_STEP
		for layer in PLUMES_PER_VENT:
			var index := i * PLUMES_PER_VENT + layer
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, GRATE.y + PLUME.y / 2.0, (layer - 1) * 0.25)))
			multimesh.set_instance_custom_data(index, Color(float(index) * 1.7, 0, 0, 0))
	var plumes := MultiMeshInstance3D.new()
	plumes.name = "Steam"
	plumes.multimesh = multimesh
	plumes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FxMultiMesh.never_interpolated(plumes)
	add_child(plumes)


func _build_strips() -> void:
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
