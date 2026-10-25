extends SceneTree
## B1 (round 40, balance): the unit and weapon catalogs as JSON, so the per-unit tally can price and describe what it
## counts without parsing GDScript. Read-only: prints CATALOG_JSON <json> and quits.
##   godot --headless --path . --script res://tools/balance/catalog_dump.gd


func _initialize() -> void:
	var units := {}
	for unit_id: String in Units.PROFILES:
		var p: Dictionary = Units.PROFILES[unit_id]
		var row := {}
		for key: String in ["display_name", "role", "faction", "cost", "max_health", "max_shield", "max_forward_speed",
				"sight_radius", "weapon", "armor", "hull_size"]:
			row[key] = p.get(key, Units.DEFAULT_FACTION if key == "faction" else null)
		row["squad_key"] = Army.squad_key(unit_id)
		units[unit_id] = row
	var weapons := {}
	for weapon_id: String in Weapons.PROFILES:
		weapons[weapon_id] = Weapons.PROFILES[weapon_id]
	print("CATALOG_JSON " + JSON.stringify({"units": units, "weapons": weapons, "squads": Army.SQUADS,
			"archetypes": Army.ARCHETYPES}))
	quit(0)
