class_name ArmyStore
extends RefCounted
## Saved armies: doctrine JSON files under user://doctrines/, which skirmish loads with
## --player=user://doctrines/<file>.json. Local only until netcode decides where squads live online.

const DIR := "user://doctrines/"


## "Night Raiders!" → "night_raiders"
static func slug(army_name: String) -> String:
	var result := ""
	for character in army_name.strip_edges().to_lower():
		result += character if character.is_valid_ascii_identifier() or character.is_valid_int() else "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.trim_prefix("_").trim_suffix("_")
	return result if result != "" else "army"


static func path_for(stem: String, dir := DIR) -> String:
	return dir.path_join(stem + ".json")


## Writes the doctrine. Returns {"path": String} or {"error": String}.
static func save(doctrine: Dictionary, stem: String, dir := DIR) -> Dictionary:
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK:
		return {"error": "can't create %s: %s" % [dir, error_string(made)]}
	var path := path_for(stem, dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "can't write %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	file.store_string(JSON.stringify(doctrine, "  ", false))
	file.close()
	return {"path": path}


## Reads a saved army WITHOUT validating it, so an unfinished draft can still be edited.
## Returns {"doctrine": Dictionary} or {"error": String}. (Doctrine.load_file validates.)
static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "can't open %s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("name")) != TYPE_STRING:
		return {"error": "%s is not an army (JSON object with a name)" % path}
	return {"doctrine": data}


## Saved armies, sorted by file name: [{stem, path, name}]. Files that aren't armies are skipped.
static func list(dir := DIR) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var loaded := read(dir.path_join(file_name))
		if loaded.has("doctrine"):
			found.append({"stem": file_name.get_basename(), "path": dir.path_join(file_name),
					"name": String(loaded["doctrine"]["name"])})
	return found


static func remove(stem: String, dir := DIR) -> Error:
	return DirAccess.remove_absolute(path_for(stem, dir))
