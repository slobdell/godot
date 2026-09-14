extends SceneTree
## GA3 helper (`make garage-e2e`): builds an army through the garage's own Loadout API, the way a
## player would (mixed weapons, three squads, roles, paint), and saves it where the garage saves.
## Prints GARAGE_ARMY <path> <cost>. Not a test_* file, so `make test` doesn't run it.
##   -- --stem=NAME  (default garage_e2e)
##   -- --preset=ARCHETYPE --seed=N   write a CPU army (ArmyPresets) to user://doctrines/cpu/<archetype>_<seed>.json instead


func _initialize() -> void:
	var stem := "garage_e2e"
	var preset := ""
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stem="):
			stem = arg.trim_prefix("--stem=")
		elif arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
		elif arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
	var catalog := GarageCatalog.from_game()
	if preset != "":
		if not ArmyPresets.ARCHETYPES.has(preset):
			push_error("no archetype %s (have %s)" % [preset, ArmyPresets.ids()])
			quit(1)
			return
		var cpu := ArmyPresets.build(preset, catalog, seed_value)
		var written := ArmyStore.save(cpu.to_doctrine(), "%s_%d" % [preset, seed_value], GarageMode.CPU_DIR)
		print("GARAGE_ARMY %s %d" % [written.get("path", written.get("error")), cpu.total_cost()])
		quit(0 if written.has("path") and cpu.is_ready() else 1)
		return
	var loadout := Loadout.new(catalog)
	loadout.set_army_name("Garage E2E")
	loadout.add_squad()
	loadout.add_squad()
	var unit_id := catalog.unit_ids()[0]
	for squad_index in [0, 0, 1, 1, 2]:
		_check(loadout.add_unit(squad_index, unit_id))
	_check(loadout.set_weapon(1, 0, "main", "flamethrower"))
	_check(loadout.set_weapon(1, 1, "main", "flamethrower"))
	_check(loadout.set_squad_role(1, "flanker"))
	_check(loadout.set_formation(1, "echelon_right"))
	_check(loadout.set_squad_role(2, "scout"))
	_check(loadout.set_unit_role(0, 1, "anchor"))
	_check(loadout.set_paint(0, 0, "#c8a02a"))
	if not loadout.is_ready():
		push_error("garage e2e army is not ready: %s" % [loadout.problems()])
		quit(1)
		return
	var saved := ArmyStore.save(loadout.to_doctrine(), stem)
	if saved.has("error"):
		push_error(saved["error"])
		quit(1)
		return
	print("GARAGE_ARMY %s %d" % [saved["path"], loadout.total_cost()])
	quit(0)


func _check(error: String) -> void:
	if error != "":
		push_error("garage e2e build step failed: " + error)
