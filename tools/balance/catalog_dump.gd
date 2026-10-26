extends SceneTree
## B1 (round 40, balance): the unit and weapon catalogs as JSON, so the per-unit tally can price and describe what it
## counts without parsing GDScript. Read-only: prints CATALOG_JSON <json> and quits.
##   godot --headless --path . --script res://tools/balance/catalog_dump.gd [-- --tune=<spec>]
## With --tune (B4), it also prints TUNED_JSON: each unit's hp, shield, armour and weapon damage as the simulation reads
## them (Units.stat, Units.armor, Weapons.profile) under that tune, so a candidate is seen to land before fights use it.


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tune="):
			var problem := Units.apply_tuning(arg.trim_prefix("--tune="))
			if problem != "":
				printerr("TUNE_ERROR " + problem)
				quit(1)
				return
			var tuned := {}
			for unit_id: String in Units.PROFILES:
				tuned[unit_id] = {"max_health": Units.stat(unit_id, "max_health"),
						"max_shield": Units.stat(unit_id, "max_shield", 0.0),
						"armor": {"front": Units.armor(unit_id, "front"), "side": Units.armor(unit_id, "side"),
								"rear": Units.armor(unit_id, "rear")},
						"damage": Weapons.profile(String(Units.stat(unit_id, "weapon"))).get("damage"),
						# Round 41 (B5): his levers, as the tank reads them at spawn (Tank.apply_unit -> Units.stat).
						"turret_turn_rate_deg": Units.stat(unit_id, "turret_turn_rate_deg"),
						"max_forward_speed": Units.stat(unit_id, "max_forward_speed"),
						"max_reverse_speed": Units.stat(unit_id, "max_reverse_speed"),
						"hull_turn_rate_deg": Units.stat(unit_id, "hull_turn_rate_deg")}
			print("TUNED_JSON " + JSON.stringify(tuned))
	var units := {}
	for unit_id: String in Units.PROFILES:
		var p: Dictionary = Units.PROFILES[unit_id]
		var row := {}
		# Round 41 (B5, C41.5): his levers, a tank's turret traverse and hull speed / turn, so a candidate can scale them.
		for key: String in ["display_name", "role", "faction", "cost", "max_health", "max_shield", "max_forward_speed",
				"max_reverse_speed", "hull_turn_rate_deg", "turret_turn_rate_deg", "sight_radius", "weapon", "armor", "hull_size"]:
			row[key] = p.get(key, Units.DEFAULT_FACTION if key == "faction" else null)
		row["squad_key"] = Army.squad_key(unit_id)
		units[unit_id] = row
	var weapons := {}
	for weapon_id: String in Weapons.PROFILES:
		weapons[weapon_id] = Weapons.PROFILES[weapon_id]
	print("CATALOG_JSON " + JSON.stringify({"units": units, "weapons": weapons, "squads": Army.SQUADS,
			"archetypes": Army.ARCHETYPES}))
	quit(0)
