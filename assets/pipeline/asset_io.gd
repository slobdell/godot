class_name AssetIO
extends RefCounted
## Files in and out of the asset pipeline: GLB load/save (GLTFDocument, no editor import needed),
## the wrapper scene that implements the slot's optional methods, and each generated theme's
## manifest.json (slot → glb, wrapper scene, source, license, pipeline options).

const WRAPPER_SCRIPT := "res://assets/runtime/generated_visual.gd"
const THEMES_ROOT := "res://game/theme"


static func load_glb(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if error != OK:
		push_error("could not read %s (error %d)" % [path, error])
		return null
	var scene := document.generate_scene(state) as Node3D
	AssetInspector.bake_skins(scene)
	return scene


static func save_glb(root: Node, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	return error


static func generated_dir(theme: String) -> String:
	return "%s/%s/generated" % [THEMES_ROOT, theme]


## Writes <dir>/<file>.tscn instancing <file>.glb under the GeneratedVisual script.
## `materials`: {tint: [...], team_emissive: [...], heat: [...]} material-name globs.
static func write_wrapper(theme: String, slot: String, materials: Dictionary = {}) -> String:
	var contract := AssetContracts.get_contract(slot)
	var file: String = contract["file"]
	var dir := generated_dir(theme)
	var path := "%s/%s.tscn" % [dir, file]
	var lines := PackedStringArray([
		"[gd_scene format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"%s\" id=\"1_visual\"]" % WRAPPER_SCRIPT,
		"[ext_resource type=\"PackedScene\" path=\"%s/%s.glb\" id=\"2_model\"]" % [dir, file],
		"",
		"[node name=\"%s\" type=\"Node3D\"]" % file.to_pascal_case(),
		"script = ExtResource(\"1_visual\")",
		"slot = \"%s\"" % slot,
	])
	for key in [["tint", "tint_materials"], ["team_emissive", "team_emissive_materials"], ["heat", "heat_materials"]]:
		var globs: Array = materials.get(key[0], [])
		if not globs.is_empty():
			var quoted := PackedStringArray()
			for glob in globs:
				quoted.append("\"%s\"" % glob)
			lines.append("%s = PackedStringArray(%s)" % [key[1], ", ".join(quoted)])
	lines.append_array(["", "[node name=\"Model\" parent=\".\" instance=ExtResource(\"2_model\")]", ""])
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string("\n".join(lines))
	handle.close()
	return path


static func read_manifest(theme: String) -> Dictionary:
	var path := "%s/manifest.json" % generated_dir(theme)
	if not FileAccess.file_exists(path):
		return {"theme": theme, "slots": {}}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {"theme": theme, "slots": {}}


static func write_manifest(theme: String, manifest: Dictionary) -> void:
	var path := "%s/manifest.json" % generated_dir(theme)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(JSON.stringify(manifest, "  ", true) + "\n")
	handle.close()


## Themes that have a generated/manifest.json.
static func generated_themes() -> PackedStringArray:
	var themes := PackedStringArray()
	for theme in DirAccess.get_directories_at(THEMES_ROOT):
		if FileAccess.file_exists("%s/manifest.json" % generated_dir(theme)):
			themes.append(theme)
	return themes


## slot → wrapper scene path for a generated theme; merge it over GameTheme.slots to preview.
static func theme_slots(theme: String) -> Dictionary:
	var slots := {}
	var manifest := read_manifest(theme)
	for slot in manifest["slots"]:
		if AssetContracts.SLOTS.has(slot):
			slots[slot] = "%s/%s" % [generated_dir(theme), manifest["slots"][slot]["scene"]]
	return slots
