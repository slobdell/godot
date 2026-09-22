class_name UnitSkin
extends RefCounted
## Dresses a generated vehicle model (Meshy PBR materials) in the cyberpunk unit shader (unit_body.gdshader): team-colored
## neon, paint, heat, and a rim light.
##
## Render X2 (round 5): there are NO instance uniforms. An instance uniform reserves 16 of the renderer's 4,096 global
## buffer slots per instance, so ~256 vehicle parts filled it and 30 a side logged hundreds of errors. Instead every
## (texture set, team color, paint, heat level) combination is one shared ShaderMaterial: a battle has a handful of
## teams and paints, and heat is quantized to HEAT_LEVELS steps, so the cache stays small. The Compatibility renderer
## draws each instance separately anyway, so sharing fewer materials costs no draw calls.

const SHADER := preload("res://game/theme/fx/shaders/unit_body.gdshader")
## Heat is shown in this many steps above cold (the shader's curve is cubic, so steps don't read as jumps).
const HEAT_LEVELS := 8
const DEFAULT_TEAM := Color(0.75, 0.75, 0.8)
const SOURCES_META := &"unit_skin_sources"

## Feel (round 10, backlog 4; round 9's recommendation): A FAINT RIM PER FACTION. Dark hulls between the lamp pools were
## carried only by their selection rings; the shader's rim was one cool blue for every vehicle. Each faction's rim is
## now its own colour, the team hint on top of it unchanged (`rim_team`: friend/foe still reads on the silhouette),
## and a little stronger. Colours from art_direction.md's faction looks: the Condemned's hazard amber, the gangs'
## magenta, Law's police blue, the Syndicate's ivory. `--no-faction-rim` restores the old rim for the A/B pair.
const FACTION_RIM := {
	"condemned": Color(1.0, 0.62, 0.22),
	"gangs": Color(1.0, 0.38, 0.78),
	"law": Color(0.42, 0.62, 1.0),
	"syndicate": Color(0.92, 0.94, 1.0),
}
const FACTION_RIM_STRENGTH := 0.5
static var faction_rim_enabled := not LaunchFlags.from_environment().has("no-faction-rim")

## key → WeakRef(ShaderMaterial): a material is freed with the last vehicle wearing it (a strong static cache leaks at exit).
static var _materials: Dictionary = {}


## Replaces every textured surface's material under `model` with the shared unit material (default team, no paint, cold).
## Returns the MeshInstance3Ds it dressed; pass them to `dress()` whenever team, paint or heat change.
static func apply(model: Node) -> Array[MeshInstance3D]:
	var dressed: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var sources := []
		var any := false
		for surface in instance.mesh.get_surface_count():
			var source := instance.get_active_material(surface) as BaseMaterial3D
			if source == null or source.albedo_texture == null:
				sources.append(null)
				continue
			sources.append(source)
			any = true
		if any:
			instance.set_meta(SOURCES_META, sources)
			dressed.append(instance)
	dress(dressed, DEFAULT_TEAM, Color(1, 1, 1, 0), 0.0)
	return dressed


## Put every dressed surface in the shared material for this team, paint (`paint.a` = strength, 0 = none) and heat (0..1).
static func dress(instances: Array[MeshInstance3D], team: Color, paint: Color, heat: float, faction := "") -> void:
	var level := heat_level(heat)
	for instance in instances:
		var sources: Array = instance.get_meta(SOURCES_META, [])
		for surface in sources.size():
			if sources[surface] == null:
				continue
			var material := material_for(sources[surface] as BaseMaterial3D, team, paint, level, faction)
			if instance.get_surface_override_material(surface) != material:
				instance.set_surface_override_material(surface, material)


static func heat_level(heat: float) -> int:
	return clampi(roundi(heat * HEAT_LEVELS), 0, HEAT_LEVELS)


static func material_for(source: BaseMaterial3D, team := DEFAULT_TEAM, paint := Color(1, 1, 1, 0), level := 0,
		faction := "") -> ShaderMaterial:
	var rim_faction := faction if faction_rim_enabled and FACTION_RIM.has(faction) else ""
	var key := "%d|%s|%s|%d|%s" % [source.albedo_texture.get_instance_id(), team.to_html(), paint.to_html(), level,
			rim_faction]
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
	material.set_shader_parameter("team_color", team)
	material.set_shader_parameter("paint", paint)
	material.set_shader_parameter("heat", float(level) / HEAT_LEVELS)
	if rim_faction != "":
		var rim: Color = FACTION_RIM[rim_faction]
		material.set_shader_parameter("rim_color", Vector3(rim.r, rim.g, rim.b))
		material.set_shader_parameter("rim_strength", FACTION_RIM_STRENGTH)
	_materials[key] = weakref(material)
	return material
