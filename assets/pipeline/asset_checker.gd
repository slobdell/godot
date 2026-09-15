class_name AssetChecker
extends RefCounted
## Enforces the slot contracts (AssetContracts) on a measured model (AssetInspector report)
## and on whole generated themes (manifest + GLBs + wrapper scenes). `make assets-check`.
## Errors break the contract; warnings are worth a look but don't fail the check.


## Returns {errors: PackedStringArray, warnings: PackedStringArray}.
## raise: the manifest's options.raise for this slot (turret/barrel anchors lifted onto a tall hull's roof).
## attached: a barrel placed by its turret (options.attach): only the muzzle point and cross-section are enforced.
## placed: a unit turret/weapon kept where the generator put it (options.place): size and anchor aren't enforced;
## a weapon reports how far its visible tip is from the gameplay muzzle (a warning).
static func check_report(report: Dictionary, slot: String, raise := 0.0, attached := false, placed := {}) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var contract := AssetContracts.get_contract(slot)
	if contract.is_empty():
		errors.append("unknown slot '%s'" % slot)
		return {"errors": errors, "warnings": warnings}
	var aabb: AABB = report["aabb"]
	var size := aabb.size
	var guide: Vector3 = contract["guide"]
	var max_size: Vector3 = contract["max"]
	var tolerance := AssetContracts.SIZE_TOLERANCE
	var near := AssetContracts.ANCHOR_TOLERANCE

	if int(report["tris"]) > int(contract["tris"]):
		errors.append("%d triangles is over the %d budget" % [report["tris"], contract["tris"]])
	if int(report["tris"]) == 0:
		errors.append("no triangles")
		return {"errors": errors, "warnings": warnings}

	if not placed.is_empty():
		var aabb_placed: AABB = report["aabb"]
		if String(contract["anchor"]) == "barrel":
			var muzzle := float(contract["barrel_back"]) - (contract["guide"] as Vector3).z
			if absf(aabb_placed.position.z - muzzle) > 0.3:
				warnings.append("visible muzzle at z %.2f, gameplay fires from %.2f (turret space ×%.2f)" % [aabb_placed.position.z, muzzle, float(placed.get("turret_scale", 1.0))])
		if aabb_placed.size.length() > 12.0:
			errors.append("placed part is %s: far bigger than a vehicle part" % _v(aabb_placed.size))
		contract = contract.duplicate()
		contract["fit"] = "none"
		contract["anchor"] = "world"
		contract["elongated"] = ""
	match String(contract["fit"]):
		"contain":
			if size.x > max_size.x * (1 + tolerance) or size.y > max_size.y * (1 + tolerance) or size.z > max_size.z * (1 + tolerance):
				errors.append("size %s exceeds the slot's %s" % [_v(size), _v(max_size)])
			var fill := maxf(maxf(size.x / guide.x, size.y / guide.y), size.z / guide.z)
			if fill < AssetContracts.MIN_FILL:
				errors.append("size %s is too small for the slot (fills %d%% of %s on its best axis)" % [_v(size), int(fill * 100), _v(guide)])
		"stretch":
			for axis in 3:
				if absf(size[axis] - guide[axis]) > guide[axis] * tolerance:
					errors.append("size %s doesn't match the collision box %s" % [_v(size), _v(guide)])
					break
		"length":
			var muzzle := float(contract.get("barrel_back", 0.0)) - guide.z
			if attached:
				if absf(aabb.position.z - muzzle) > near * 2:
					errors.append("muzzle is at z = %.2f; gameplay fires from %.2f" % [aabb.position.z, muzzle])
				if aabb.end.z > 0.5 or aabb.end.z < muzzle * 0.5:
					errors.append("breech at z = %.2f isn't near the turret pivot" % aabb.end.z)
			elif absf(size.z - guide.z) > guide.z * tolerance:
				errors.append("length %.2f m should be %.2f m" % [size.z, guide.z])
			if size.x > max_size.x * (1 + tolerance) or size.y > max_size.y * (1 + tolerance):
				errors.append("cross-section %.2f × %.2f m exceeds %.2f × %.2f m" % [size.x, size.y, max_size.x, max_size.y])

	var center := aabb.get_center()
	match String(contract["anchor"]):
		"ground_center":
			if absf(aabb.position.y) > near:
				errors.append("bottom is at y = %.2f; it should sit on the ground (y = 0)" % aabb.position.y)
			if absf(center.x) > near * 4 or absf(center.z) > near * 4:
				errors.append("footprint center is at (%.2f, %.2f); it should be at the origin" % [center.x, center.z])
		"center":
			if center.length() > near * 2:
				errors.append("center is at %s; it should be at the origin" % _v(center))
		"turret":
			var bottom := float(contract["turret_bottom"]) + raise
			if absf(aabb.position.y - bottom) > near:
				errors.append("bottom is at y = %.2f; it should be at %.2f (hull deck)" % [aabb.position.y, bottom])
			if absf(center.x) > near * 4 or absf(center.z) > near * 6:
				errors.append("turret center is at (%.2f, %.2f); the pivot should be near its middle" % [center.x, center.z])
		"barrel" when attached:
			pass  # placement comes from the turret; the muzzle was checked above
		"barrel":
			if absf(aabb.end.z - float(contract["barrel_back"])) > near * 2:
				errors.append("back end is at z = %.2f; it should be at %.2f" % [aabb.end.z, contract["barrel_back"]])
			var axis := float(contract["barrel_y"]) + raise
			if absf(center.x) > near or absf(center.y - axis) > near * 2:
				errors.append("barrel axis is at (x %.2f, y %.2f); it should be at (0, %.2f)" % [center.x, center.y, axis])

	match String(contract["elongated"]):
		"z":
			if size.x > size.z * 1.02:
				errors.append("wider (x %.2f) than long (z %.2f): forward axis is probably wrong" % [size.x, size.z])
		"x":
			if size.z > size.x * 1.02:
				errors.append("deeper (z %.2f) than long (x %.2f): the long axis should be x" % [size.z, size.x])

	for material in report["materials"]:
		for texture in material["textures"]:
			if maxi(texture[1], texture[2]) > int(contract["textures"]):
				errors.append("material '%s' %s is %d×%d (max %d)" % [material["name"], texture[0], texture[1], texture[2], contract["textures"]])
	for extra in report["extras"]:
		if String(extra).begins_with("collision"):
			errors.append("visuals must not add collision (%s)" % extra)
		else:
			warnings.append("unexpected %s" % extra)
	if report["surfaces"] > 4:
		warnings.append("%d surfaces = %d draw calls per instance" % [report["surfaces"], report["surfaces"]])
	return {"errors": errors, "warnings": warnings}


## Checks every slot in one generated theme. Returns {errors, warnings, lines} (lines = the report).
static func check_theme(theme: String) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var lines := PackedStringArray()
	var manifest := AssetIO.read_manifest(theme)
	var dir := AssetIO.generated_dir(theme)
	if manifest["slots"].is_empty():
		errors.append("%s: manifest has no slots" % theme)
	for file in DirAccess.get_files_at(dir):
		var config := ConfigFile.new()
		if file.ends_with(".png") and config.load("%s/%s.import" % [dir, file]) == OK:
			var image := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, file]))
			if image != null and int(config.get_value("params", "compress/mode", 0)) != AssetIO.texture_policy(image.get_width(), image.get_height()):
				errors.append("%s: %s isn't imported with the web texture policy (make assets-textures THEME=%s)" % [theme, file, theme])
	for orphan in AssetIO.orphan_files(theme):
		errors.append("%s: %s isn't owned by any manifest entry (stale? delete it)" % [theme, orphan])
	for slot in manifest["slots"]:
		var entry: Dictionary = manifest["slots"][slot]
		var prefix := "%s/%s" % [theme, slot]
		for field in ["glb", "scene", "source", "license"]:
			if not entry.has(field) or String(entry[field]) == "":
				errors.append("%s: manifest entry lacks '%s'" % [prefix, field])
		var glb_path := "%s/%s" % [dir, entry.get("glb", "")]
		if not FileAccess.file_exists(glb_path):
			errors.append("%s: missing %s" % [prefix, glb_path])
			continue
		var model := AssetIO.load_glb(glb_path)
		if model == null:
			errors.append("%s: unreadable %s" % [prefix, glb_path])
			continue
		var report := AssetInspector.inspect(model)
		model.free()
		var options: Dictionary = entry.get("options", {})
		var result := check_report(report, slot, float(options.get("raise", 0.0)), options.has("attach"), options.get("place", {}))
		var aabb: AABB = report["aabb"]
		lines.append("%s: %d tris, %.2f × %.2f × %.2f m, %d materials, %.0f KB textures%s" % [prefix, report["tris"],
				aabb.size.x, aabb.size.y, aabb.size.z, report["materials"].size(), report["texture_bytes"] / 1024.0,
				", emissive" if report["emissive"] else ""])
		for error in result["errors"]:
			errors.append("%s: %s" % [prefix, error])
		for warning in result["warnings"]:
			warnings.append("%s: %s" % [prefix, warning])
		_check_wrapper(prefix, "%s/%s" % [dir, entry.get("scene", "")], slot, errors)
	return {"errors": errors, "warnings": warnings, "lines": lines}


## The wrapper scene loads (needs `make import`), adds no collision, and has the slot's methods.
static func _check_wrapper(prefix: String, path: String, slot: String, errors: PackedStringArray) -> void:
	if not ResourceLoader.exists(path):
		errors.append("%s: missing wrapper scene %s (run make import after adding GLBs)" % [prefix, path])
		return
	var packed := load(path) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	if instance == null:
		errors.append("%s: wrapper scene %s doesn't instantiate" % [prefix, path])
		return
	for method in AssetContracts.get_contract(slot)["methods"]:
		if not instance.has_method(method):
			errors.append("%s: wrapper lacks %s()" % [prefix, method])
	if instance.find_children("*", "CollisionObject3D", true, false).size() > 0:
		errors.append("%s: wrapper adds collision" % prefix)
	if AssetInspector.inspect(instance)["tris"] == 0:
		errors.append("%s: wrapper renders no triangles (is the GLB imported?)" % prefix)
	instance.free()


static func _v(value: Vector3) -> String:
	return "%.2f × %.2f × %.2f" % [value.x, value.y, value.z]
