extends SceneTree
## A5 web/mobile budget report: per visual-slot scene, triangles, draw calls, texture memory, and
## exported size, for the default theme and every generated theme. Prints markdown tables.
##   godot --headless --path . --script res://assets/pipeline/budget_report.gd
##   make assets-report   (also runs the .pck breakdown; see _agents/streams/references/asset_budget.md)
##
## Texture memory: "RGBA8" is what Lossless/Lossy imports upload (w × h × 4 × 4/3 for mipmaps);
## "VRAM" is what a VRAM-compressed or Basis Universal import uploads (≈ 1 byte/px × 4/3: BC3/ETC2-RGBA/ASTC 4×4).
## "Pack" sums the imported files (.scn/.ctex in .godot/imported) that an export would include.


func _initialize() -> void:
	var themes := {"default": GameTheme.DEFAULT_SLOTS}
	for theme in AssetIO.generated_themes():
		var scenes := {}
		var manifest := AssetIO.read_manifest(theme)
		for slot in manifest["slots"]:
			scenes[slot] = "%s/%s" % [AssetIO.generated_dir(theme), manifest["slots"][slot]["scene"]]
		themes[theme] = scenes
	for theme in themes:
		print("\n### `%s`\n" % theme)
		print("| slot | tris / budget | draw calls | textures | RGBA8 KB | VRAM KB | pack KB | emissive |")
		print("|---|---:|---:|---|---:|---:|---:|---|")
		var totals := {"tris": 0, "calls": 0, "rgba": 0, "vram": 0, "pack": 0}
		for slot in themes[theme]:
			var path: String = themes[theme][slot]
			var packed := load(path) as PackedScene
			if packed == null:
				print("| %s | (missing %s) |" % [slot, path])
				continue
			var instance := packed.instantiate()
			var report := AssetInspector.inspect(instance)
			instance.free()
			var textures := PackedStringArray()
			var vram := 0
			var seen := {}
			for material in report["materials"]:
				for texture in material["textures"]:
					var key := "%s %d×%d" % [material["name"], texture[1], texture[2]]
					if seen.has(key):
						continue
					seen[key] = true
					textures.append("%d²" % texture[1] if texture[1] == texture[2] else "%d×%d" % [texture[1], texture[2]])
					vram += int(texture[1] * texture[2] * 4.0 / 3.0)
			var pack := _pack_bytes(path)
			var budget := int(AssetContracts.get_contract(slot).get("tris", 0)) if AssetContracts.has(slot) else 0
			print("| `%s` | %d / %s | %d | %s | %.0f | %.0f | %.0f | %s |" % [slot, report["tris"], str(budget) if budget > 0 else "—",
					report["surfaces"], ", ".join(textures) if textures.size() > 0 else "—", report["texture_bytes"] / 1024.0,
					vram / 1024.0, pack / 1024.0, "yes" if report["emissive"] else ""])
			totals["tris"] += report["tris"]
			totals["calls"] += report["surfaces"]
			totals["rgba"] += report["texture_bytes"]
			totals["vram"] += vram
			totals["pack"] += pack
		print("| **total** | %d | %d | | %.0f | %.0f | %.0f | |" % [totals["tris"], totals["calls"], totals["rgba"] / 1024.0,
				totals["vram"] / 1024.0, totals["pack"] / 1024.0])
	quit()


## Imported bytes an export would pack for a scene: its own imported file, plus (for generated
## wrappers) the GLB's imported scene and its extracted textures.
func _pack_bytes(scene_path: String) -> int:
	var total := 0
	var dir := scene_path.get_base_dir()
	var stem := scene_path.get_file().get_basename()
	total += _file_size(scene_path)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".import") and (file.begins_with(stem + ".") or file.begins_with(stem + "_")):
			var config := ConfigFile.new()
			if config.load("%s/%s" % [dir, file]) == OK:
				for dest in config.get_value("deps", "dest_files", []):
					total += _file_size(dest)
	return total


func _file_size(path: String) -> int:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return 0
	var size := handle.get_length()
	handle.close()
	return size
