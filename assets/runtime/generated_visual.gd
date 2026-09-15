extends Node3D
## Wrapper for a generated or imported model filling a visual slot (written by assets/pipeline).
## Implements every optional slot method; each works by material NAME, so a model only needs
## its materials named to join in:
##   set_team_color(color)  tints materials matching `tint_materials` (albedo) and
##                          `team_emissive_materials` (emission: team-colored neon)
##   set_heat(ratio)        drives emission energy on `heat_materials` (barrels glow when hot)
##   set_shield(ratio)      fades `shield_materials` (a shell mesh around the model) with shield strength;
##                          hidden at 0 (planned contract, gameplay G6; look & feel may replace the effect)
##   set_firing(firing)     shows/hides a child named "Firing" if the wrapper has one
##   setup(weapon)          stores the weapon profile (for effects sized from it)
##   material_source        a part exported without textures (--textures-from) takes the same-named materials of
##                          that scene (the unit's hull), so one texture set serves every part of a unit
## Materials are shared by every instance of a scene, so each change works on a per-instance copy.

@export var slot := ""
@export var tint_materials: PackedStringArray = []
@export var team_emissive_materials: PackedStringArray = []
@export var heat_materials: PackedStringArray = []
@export var shield_materials: PackedStringArray = []
## Blend between the model's own albedo (0) and the team color (1).
@export_range(0.0, 1.0) var tint_strength := 1.0
@export var heat_energy := 4.0
## The scene whose materials (by name) this model's untextured surfaces wear; see --textures-from.
@export var material_source: PackedScene

## Materials merged by the pipeline's --palette carry their colors in vertex colors; glTF can't store
## the flags that say so, so they are restored here (on the shared material, once).
const PALETTE_MATERIAL := "vertex_palette"

var weapon := {}
var _copies := {}  # [MeshInstance3D, surface] key → per-instance material copy


func _ready() -> void:
	if material_source != null:
		_borrow_materials()
	for target in _surfaces(PackedStringArray([PALETTE_MATERIAL])):
		var material := (target[0] as MeshInstance3D).mesh.surface_get_material(target[1]) as BaseMaterial3D
		if material != null:
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = true


func set_team_color(color: Color) -> void:
	for target in _surfaces(tint_materials):
		var material := _own_material(target[0], target[1])
		if material != null:
			var original := ((target[0] as MeshInstance3D).get_active_material(target[1]) as BaseMaterial3D).albedo_color
			material.albedo_color = original.lerp(color, tint_strength)
	for target in _surfaces(team_emissive_materials):
		var material := _own_material(target[0], target[1])
		if material != null:
			material.emission_enabled = true
			material.emission = color


func set_heat(ratio: float) -> void:
	for target in _surfaces(heat_materials):
		var material := _own_material(target[0], target[1])
		if material != null:
			material.emission_enabled = true
			material.emission_energy_multiplier = clampf(ratio, 0.0, 1.0) * heat_energy


func set_shield(ratio: float) -> void:
	var strength := clampf(ratio, 0.0, 1.0)
	for target in _surfaces(shield_materials):
		var material := _own_material(target[0], target[1])
		if material != null:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.35 * strength
			material.emission_enabled = true
			material.emission_energy_multiplier = 2.0 * strength
		(target[0] as MeshInstance3D).visible = strength > 0.0


func set_firing(firing: bool) -> void:
	var effect := get_node_or_null("Firing") as Node3D
	if effect != null:
		effect.visible = firing


func setup(weapon_profile: Dictionary) -> void:
	weapon = weapon_profile


## Surface overrides from material_source: read from its packed state (the meshes are resources), no instancing.
func _borrow_materials() -> void:
	var by_name := {}
	var state := material_source.get_state()
	for node in state.get_node_count():
		for property in state.get_node_property_count(node):
			var value = state.get_node_property_value(node, property)
			if value is Mesh:
				for surface in (value as Mesh).get_surface_count():
					var material := (value as Mesh).surface_get_material(surface)
					if material != null:
						by_name[material.resource_name] = material
	for instance in find_children("*", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var own := mesh.surface_get_material(surface)
			if own != null and by_name.has(own.resource_name):
				(instance as MeshInstance3D).set_surface_override_material(surface, by_name[own.resource_name])


## [[MeshInstance3D, surface index], ...] whose material name matches any glob.
func _surfaces(globs: PackedStringArray) -> Array:
	var found := []
	if globs.is_empty():
		return found
	for instance in find_children("*", "MeshInstance3D", true, false):
		var mesh := (instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material := (instance as MeshInstance3D).get_active_material(surface)
			var material_name := material.resource_name if material != null else ""
			for glob in globs:
				if material_name.matchn(glob):
					found.append([instance, surface])
					break
	return found


func _own_material(instance: MeshInstance3D, surface: int) -> BaseMaterial3D:
	var key := "%d:%d" % [instance.get_instance_id(), surface]
	if not _copies.has(key):
		var source := instance.get_active_material(surface) as BaseMaterial3D
		if source == null:
			return null
		_copies[key] = source.duplicate()
		instance.set_surface_override_material(surface, _copies[key])
	return _copies[key]
