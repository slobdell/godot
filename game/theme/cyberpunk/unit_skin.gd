class_name UnitSkin
extends RefCounted
## Dresses a generated vehicle model (Meshy PBR materials) in the cyberpunk unit shader (unit_body.gdshader):
## team-colored neon, paint, heat, and a rim light, all as instance uniforms on one material that every
## instance of the unit shares. Parts that share a texture set (hull, turret, weapon of one unit) share the
## material too, so the unit's textures are uploaded once.

const SHADER := preload("res://game/theme/fx/shaders/unit_body.gdshader")

## albedo texture instance id → WeakRef(ShaderMaterial): every part using that texture shares one material, and
## the material is freed with the last vehicle wearing it (a strong static cache leaks at exit).
static var _materials: Dictionary = {}


## Replaces every textured surface's material under `model` with the shared unit material.
## Returns the MeshInstance3Ds that now carry the instance uniforms.
static func apply(model: Node) -> Array[MeshInstance3D]:
	var dressed: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var changed := false
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as BaseMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			instance.set_surface_override_material(surface, material_for(source))
			changed = true
		if changed:
			dressed.append(instance)
	return dressed


static func material_for(source: BaseMaterial3D) -> ShaderMaterial:
	var key := source.albedo_texture.get_instance_id()
	if _materials.has(key):
		var cached := (_materials[key] as WeakRef).get_ref() as ShaderMaterial
		if cached != null:
			return cached
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.resource_name = "unit_body:" + source.resource_name
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	if source.normal_enabled and source.normal_texture != null:
		material.set_shader_parameter("normal_texture", source.normal_texture)
	# The glTF importer points roughness and metallic at the same ORM image (G and B channels).
	var orm := source.roughness_texture if source.roughness_texture != null else source.metallic_texture
	if orm != null:
		material.set_shader_parameter("orm_texture", orm)
	if source.emission_enabled and source.emission_texture != null:
		material.set_shader_parameter("emission_texture", source.emission_texture)
		material.set_shader_parameter("emission_energy", source.emission_energy_multiplier)
	else:
		material.set_shader_parameter("emission_energy", 0.0)
	_materials[key] = weakref(material)
	return material


static func set_team(instances: Array[MeshInstance3D], color: Color) -> void:
	for instance in instances:
		instance.set_instance_shader_parameter("team_color", color)


## `strength` 0 leaves the generated body as it is.
static func set_paint(instances: Array[MeshInstance3D], color: Color, strength: float) -> void:
	for instance in instances:
		instance.set_instance_shader_parameter("paint", Color(color, strength))


static func set_heat(instances: Array[MeshInstance3D], ratio: float) -> void:
	for instance in instances:
		instance.set_instance_shader_parameter("heat", ratio)
