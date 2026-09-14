class_name CyberMaterials
extends RefCounted
## Shared materials for the cyberpunk theme. Every prop asks here instead of creating its own, so
## all neon strips of one color share ONE material (fewer state changes, and the neon shader
## gives each object its own flicker phase from its world position).

const NEON_SHADER := preload("res://game/theme/fx/shaders/neon.gdshader")
const BEAM_SHADER := preload("res://game/theme/fx/shaders/beam_cone.gdshader")
const HOLOGRAM_SHADER := preload("res://game/theme/fx/shaders/hologram.gdshader")
const GROUND_SHADER := preload("res://game/theme/fx/shaders/wet_ground.gdshader")
const PANEL_SHADER := preload("res://game/theme/fx/shaders/neon_panel.gdshader")

## The palette (mavlink-hud colors.xml + the specs).
const CYAN := Color("#00F3FF")
const MAGENTA := Color("#FF0099")
const PURPLE := Color("#D900FF")
const GREEN := Color("#39FF14")
const YELLOW := Color("#FFD500")
const RED := Color("#FF1744")
const ORANGE := Color("#FF6A00")

static var _cache := {}


static func neon(color: Color, energy := 3.0, flicker := 0.1) -> ShaderMaterial:
	var key := "neon/%s/%s/%s" % [color.to_html(), energy, flicker]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = NEON_SHADER
		material.set_shader_parameter("color", color)
		material.set_shader_parameter("energy", energy)
		material.set_shader_parameter("flicker", flicker)
		_cache[key] = material
	return _cache[key]


## Weathered metal/concrete, lit by the scene. Low roughness reads wet under neon.
static func surface(color: Color, roughness := 0.6, metallic := 0.3) -> StandardMaterial3D:
	var key := "surface/%s/%s/%s" % [color.to_html(), roughness, metallic]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_cache[key] = material
	return _cache[key]


static func beam(color: Color, energy := 0.25) -> ShaderMaterial:
	var key := "beam/%s/%s" % [color.to_html(), energy]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = BEAM_SHADER
		material.set_shader_parameter("color", color)
		material.set_shader_parameter("energy", energy)
		_cache[key] = material
	return _cache[key]


static func hologram(color: Color, accent: Color, seed := 1.0) -> ShaderMaterial:
	var key := "holo/%s/%s/%s" % [color.to_html(), accent.to_html(), seed]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = HOLOGRAM_SHADER
		material.set_shader_parameter("color", color)
		material.set_shader_parameter("accent", accent)
		material.set_shader_parameter("seed", seed)
		_cache[key] = material
	return _cache[key]


## A glowing top panel (border + hazard stripes), sized for the tactical camera.
static func panel(color: Color, aspect := 1.0, energy := 2.5, stripes := true) -> ShaderMaterial:
	var key := "panel/%s/%s/%s/%s" % [color.to_html(), aspect, energy, stripes]
	if not _cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = PANEL_SHADER
		material.set_shader_parameter("color", color)
		material.set_shader_parameter("aspect", aspect)
		material.set_shader_parameter("energy", energy)
		material.set_shader_parameter("stripes", 1.0 if stripes else 0.0)
		material.set_shader_parameter("border", 0.09 if aspect <= 2.0 else 0.18)
		_cache[key] = material
	return _cache[key]


## A horizontal quad facing up (+Y) of `size` (x, z) at `center`.
static func top_quad(parent: Node3D, size: Vector2, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func ground() -> ShaderMaterial:
	if not _cache.has("ground"):
		var material := ShaderMaterial.new()
		material.shader = GROUND_SHADER
		_cache["ground"] = material
	return _cache["ground"]


## A MeshInstance3D box with a material, positioned at `center` (helper for procedural props).
static func box(parent: Node3D, size: Vector3, center: Vector3, material: Material, shadows := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
