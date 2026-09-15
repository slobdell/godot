extends SceneTree
## Asset pipeline CLI (headless). Driven by mk/assets.mk; see _agents/streams/archive/round1/assets.md.
##
##   godot --headless --path . --script res://assets/pipeline/pipeline.gd -- <command> [--flags]
##
##   inspect   --in=<glb> [--slot=<slot>]      measure a model; with a slot, check it against the contract
##   normalize --in=<glb> --slot=<slot> --theme=<theme>
##             [--forward=+z] [--up=+y] [--include=glob,..] [--exclude=glob,..] [--scale=<f>]
##             [--palette]  merge flat-colored materials into one vertex-color material (fewer draw calls);
##                          --tint/--team-emissive/--heat/--emissive materials are kept separate
##             [--split=tank]  a whole generated unit in one mesh: split into islands and label them
##                             hull_N / turret_N / cannon_N, then pick a slot's parts with --include/--exclude
##             [--split=regions --turret-box=x0,y0,z0,x1,y1,z1 --cannon-box=…]  label islands by position instead
##                             (fractions of the oriented bounds; z 0 = front): units the tank heuristic can't read
##             [--place-from=unit.<id>.hull [--center] [--shift-from=unit.<id>.turret]]  a unit's turret/weapon keeps
##                             its generated placement on that hull, in turret space (--center: onto the pivot; --turn=180: about it;
##                             --stretch: a barrel keeps its breech and reaches the gameplay muzzle point)
##             [--repeat=5x1x2]  tile the selection along x/y/z (after the axis remap) before fitting
##             [--deck-from=tank.hull]  raise turret/cannon onto that hull's roof when it is taller than the default deck
##             [--emission-energy=<f>]  emission energy for emissive materials (generated maps come in dim)
##             [--attach-to=tank.turret]  a barrel from the same model stays where it was attached to that turret
##             [--scale-from=<slot>]  reuse the uniform scale another slot got from the same source
##             [--texture-caps=normal_texture:512,roughness_texture:512,metallic_texture:512]  smaller maps per property
##             [--textures-from=<slot>]  export without textures and wear that slot's materials (one texture set per unit)
##             [--emissive=glob:energy,..] [--emission-map=<png>[:material glob]] (e.g. Meshy's emission map)
##             [--tint=glob,..] [--tint-strength=0..1] [--team-emissive=glob,..] [--heat=glob,..] [--shield=glob,..]
##             [--source=<url or path>] [--license=<text>] [--credit=<text>]
##             → game/theme/<theme>/generated/<slot file>.glb + .tscn wrapper + manifest.json entry
##   check     [--theme=<theme>]                enforce contracts on generated themes (exit 1 on errors)
##   textures  --theme=<theme> | --dir=res://…  apply the web/mobile texture import policy to extracted maps / a folder
##   slots                                      print the contract table


func _initialize() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var command: String = args.get("_command", "")
	var status := 0
	match command:
		"inspect":
			status = _inspect(args)
		"normalize":
			status = _normalize(args)
		"check":
			status = _check(args)
		"textures":
			var changed := AssetIO.apply_texture_policy_dir(args["dir"]) if args.has("dir") else AssetIO.apply_texture_policy(args.get("theme", ""))
			for file in changed:
				print("texture policy applied: %s" % file)
		"slots":
			for slot in AssetContracts.all_slots():
				print("%-22s %s" % [slot, AssetContracts.get_contract(slot)])
		_:
			printerr("usage: pipeline.gd -- inspect|normalize|check|slots [--flags] (see the file header)")
			status = 2
	quit(status)


func _inspect(args: Dictionary) -> int:
	var model := AssetIO.load_glb(args.get("in", ""))
	if model == null:
		return 1
	var report := AssetInspector.inspect(model)
	model.free()
	print(AssetInspector.summary(report))
	if args.has("slot"):
		return _print_result(AssetChecker.check_report(report, args["slot"]), args["slot"])
	return 0


func _normalize(args: Dictionary) -> int:
	for required in ["in", "slot", "theme"]:
		if not args.has(required):
			printerr("normalize needs --%s" % required)
			return 2
	var slot: String = args["slot"]
	var theme: String = args["theme"]
	var source := AssetIO.load_glb(args["in"])
	if source == null:
		return 1
	if args.get("split", "") == "tank":
		var islands := AssetSplitter.split_islands(source)
		var counts := AssetSplitter.label_tank(source, args.get("forward", "+z"), args.get("up", "+y"))
		print("split into %d islands: %d hull, %d turret, %d cannon" % [islands, counts["hull"], counts["turret"], counts["cannon"]])
	elif args.get("split", "") == "regions":
		var islands := AssetSplitter.split_islands(source)
		var regions := {}
		for label in ["cannon", "turret"]:  # cannon first: a gun inside the turret's box stays the gun
			if args.has(label + "-box"):
				regions[label] = AssetSplitter.parse_box(args[label + "-box"])
		var counts := AssetSplitter.label_regions(source, args.get("forward", "+z"), args.get("up", "+y"), regions)
		print("split into %d islands by region: %s" % [islands, counts])
	var manifest := AssetIO.read_manifest(theme)
	var options := {
		"forward": args.get("forward", "+z"), "up": args.get("up", "+y"),
		"include": _list(args.get("include", "")), "exclude": _list(args.get("exclude", "")),
		"scale": float(args.get("scale", "0")), "emissive": {},
	}
	if args.has("palette"):
		options["palette"] = true
		options["keep"] = _list(args.get("tint", "")) + _list(args.get("team-emissive", "")) + _list(args.get("heat", "")) \
				+ _list(args.get("shield", ""))
	if args.has("repeat"):
		var counts := String(args["repeat"]).split("x")
		options["repeat"] = Vector3i(int(counts[0]), int(counts[1]) if counts.size() > 1 else 1, int(counts[2]) if counts.size() > 2 else 1)
	if args.has("texture-caps"):  # normal_texture:512,roughness_texture:512
		options["texture_caps"] = {}
		for pair in _list(args["texture-caps"]):
			options["texture_caps"][String(pair).get_slice(":", 0)] = int(String(pair).get_slice(":", 1))
	if args.has("emission-energy"):
		options["emission_energy"] = float(args["emission-energy"])
	if args.has("deck-from"):
		var hull: Dictionary = manifest["slots"].get(args["deck-from"], {})
		if not hull.has("roof"):
			printerr("--deck-from=%s: normalize that slot first" % args["deck-from"])
			return 1
		options["raise"] = maxf(0.0, float(hull["roof"]) - AssetContracts.DEFAULT_DECK_Y)
		print("raising onto the %s roof at %.2f m: +%.2f m" % [args["deck-from"], hull["roof"], options["raise"]])
	if args.has("attach-to"):
		var turret: Dictionary = manifest["slots"].get(args["attach-to"], {})
		var placed: Array = turret.get("options", {}).get("fitted_offset", [])
		if placed.size() != 3:
			printerr("--attach-to=%s: normalize that slot first" % args["attach-to"])
			return 1
		options["attach"] = {"scale": float(turret["options"]["fitted_scale"]), "offset": Vector3(placed[0], placed[1], placed[2])}
	if args.has("place-from"):
		var hull: Dictionary = manifest["slots"].get(args["place-from"], {})
		var placed: Array = hull.get("options", {}).get("fitted_offset", [])
		var unit := AssetContracts.unit_of(args["place-from"])
		if placed.size() != 3 or unit == "":
			printerr("--place-from=%s: normalize that unit hull first" % args["place-from"])
			return 1
		var pivot := AssetContracts.unit_pivot(unit)
		options["place"] = {"hull_scale": float(hull["options"]["fitted_scale"]), "hull_offset": Vector3(placed[0], placed[1], placed[2]),
				"pivot": pivot["pivot"], "turret_scale": pivot["turret_scale"], "center_xz": args.has("center"),
				"turn_deg": float(args.get("turn", "0")), "stretch": args.has("stretch")}
		var contract_now := AssetContracts.get_contract(slot)
		if String(contract_now.get("anchor", "")) == "barrel":
			options["place"]["muzzle_z"] = float(contract_now["barrel_back"]) - (contract_now["guide"] as Vector3).z
		if args.has("shift-from"):
			var shift: Array = manifest["slots"].get(args["shift-from"], {}).get("options", {}).get("shift", [0, 0, 0])
			options["place"]["shift"] = Vector3(shift[0], shift[1], shift[2])
	if args.has("scale-from"):
		var other: Dictionary = manifest["slots"].get(args["scale-from"], {})
		options["scale"] = float(other.get("options", {}).get("fitted_scale", 0.0))
		if options["scale"] <= 0.0:
			printerr("--scale-from=%s: normalize that slot first" % args["scale-from"])
			return 1
	if args.has("textures-from"):
		var lender: Dictionary = manifest["slots"].get(args["textures-from"], {})
		if not lender.has("glb"):
			printerr("--textures-from=%s: normalize that slot first" % args["textures-from"])
			return 1
		options["strip_textures"] = true
		options["textures_from"] = args["textures-from"]
	for pair in _list(args.get("emissive", "")):
		var parts := String(pair).split(":")
		options["emissive"][parts[0]] = float(parts[1]) if parts.size() > 1 else 2.0
	if args.has("emission-map"):
		# <file.png> or <file.png>:<material glob>
		var spec := String(args["emission-map"])
		var png := spec.get_slice(".png:", 0) + ".png" if spec.contains(".png:") else spec
		var glob := spec.get_slice(".png:", 1) if spec.contains(".png:") else "*"
		var image := Image.load_from_file(png)
		if image == null:
			printerr("could not read emission map %s" % png)
			return 1
		options["emission_maps"] = {glob: ImageTexture.create_from_image(image)}
	var before := AssetInspector.inspect(source)
	print("source %s:\n%s" % [args["in"], AssetInspector.summary(before)])
	var result := AssetNormalizer.normalize(source, slot, options)
	source.free()
	for note in result["notes"]:
		print("  note: %s" % note)
	if result["scene"] == null:
		return 1
	var contract := AssetContracts.get_contract(slot)
	var file: String = contract["file"]
	var dir := AssetIO.generated_dir(theme)
	var glb_path := "%s/%s.glb" % [dir, file]
	var error := AssetIO.save_glb(result["scene"], glb_path)
	var after := AssetInspector.inspect(result["scene"])
	result["scene"].free()
	if error != OK:
		printerr("could not write %s (error %d)" % [glb_path, error])
		return 1
	var materials := {"tint": _list(args.get("tint", "")), "team_emissive": _list(args.get("team-emissive", "")),
			"heat": _list(args.get("heat", "")), "shield": _list(args.get("shield", ""))}
	var lender_glb := ""
	if options.has("textures_from"):
		lender_glb = "%s/%s" % [dir, manifest["slots"][options["textures_from"]]["glb"]]
	var scene_path := AssetIO.write_wrapper(theme, slot, materials, float(args.get("tint-strength", "1.0")), lender_glb)
	options.erase("emission_maps")
	if options.has("repeat"):
		options["repeat"] = args["repeat"]
	if args.has("emission-map"):
		options["emission_map"] = args["emission-map"]
	options["fitted_scale"] = (result["scale"] as Vector3).x
	var shift_applied: Vector3 = result["shift"]
	options["shift"] = [snappedf(shift_applied.x, 0.0001), 0.0, snappedf(shift_applied.z, 0.0001)]
	if options.has("place"):
		var place: Dictionary = options["place"]
		options["place"] = {"from": args["place-from"], "center_xz": place["center_xz"], "turret_scale": place["turret_scale"],
				"turn_deg": place["turn_deg"], "stretch": place["stretch"]}
	var offset: Vector3 = result["offset"]
	options["fitted_offset"] = [snappedf(offset.x, 0.0001), snappedf(offset.y, 0.0001), snappedf(offset.z, 0.0001)]
	if options.has("attach"):
		var attach_offset: Vector3 = options["attach"]["offset"]
		options["attach"] = {"scale": options["attach"]["scale"], "offset": [attach_offset.x, attach_offset.y, attach_offset.z]}
	options["materials"] = materials
	manifest["theme"] = theme
	manifest["slots"][slot] = {
		"glb": glb_path.get_file(), "scene": scene_path.get_file(),
		"source": args.get("source", args["in"]), "license": args.get("license", ""), "credit": args.get("credit", ""),
		"options": options, "tris": after["tris"], "notes": Array(result["notes"]),
		"roof": snappedf((after["aabb"] as AABB).end.y, 0.001),  # read by --deck-from
	}
	AssetIO.write_manifest(theme, manifest)
	print("wrote %s and %s:\n%s" % [glb_path, scene_path, AssetInspector.summary(after)])
	return _print_result(AssetChecker.check_report(after, slot, float(options.get("raise", 0.0)), options.has("attach"),
			options.get("place", {})), slot)


func _check(args: Dictionary) -> int:
	var themes := PackedStringArray([args["theme"]]) if args.has("theme") else AssetIO.generated_themes()
	if themes.is_empty():
		print("assets-check: no generated themes yet")
		return 0
	var failed := false
	for theme in themes:
		var result := AssetChecker.check_theme(theme)
		for line in result["lines"]:
			print(line)
		for warning in result["warnings"]:
			print("  warning: %s" % warning)
		for error in result["errors"]:
			printerr("  CONTRACT: %s" % error)
		failed = failed or result["errors"].size() > 0
	print("assets-check %s (%s)" % ["FAILED" if failed else "passed", ", ".join(themes)])
	return 1 if failed else 0


func _print_result(result: Dictionary, slot: String) -> int:
	for warning in result["warnings"]:
		print("  warning: %s" % warning)
	for error in result["errors"]:
		printerr("  CONTRACT: %s" % error)
	print("%s contract %s" % [slot, "FAILED" if result["errors"].size() > 0 else "passed"])
	return 1 if result["errors"].size() > 0 else 0


static func _parse(raw: PackedStringArray) -> Dictionary:
	var args := {}
	for arg in raw:
		if not arg.begins_with("--"):
			args["_command"] = arg
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	return args


static func _list(text: String) -> Array:
	var items := []
	for item in text.split(",", false):
		items.append(item.strip_edges())
	return items
