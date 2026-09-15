extends SceneTree
## Army e2e helper (`make garage-e2e`): builds an army through the army builder's own ArmyDraft API, the
## way a player would (three squads of mixed unit types, roles, a formation, paint), and saves it where the
## builder saves. Prints GARAGE_ARMY <path> <cost> <units> and GARAGE_CODE <army code>, and GARAGE_GAME <path>:
## the file the match loads (a v1 copy until checkpoint 1, see ArmyFormat.to_game_doctrine).
## Not a test_* file, so `make test` doesn't run it.
##   -- --stem=NAME  (default garage_e2e)
##   -- --preset=ID  write an ArmyPresets army instead (e.g. make garage-preset-army PRESET=scout_screen)


func _initialize() -> void:
	var stem := "garage_e2e"
	var preset := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stem="):
			stem = arg.trim_prefix("--stem=")
		elif arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
	var catalog := ArmyCatalog.from_game()
	var draft: ArmyDraft
	if preset != "":
		if not ArmyPresets.PRESETS.has(preset):
			push_error("no preset %s (have %s)" % [preset, ArmyPresets.ids()])
			quit(1)
			return
		draft = ArmyPresets.build(preset, catalog)
		stem = preset
	else:
		draft = ArmyDraft.new(catalog)
		draft.set_army_name("Garage E2E")
		draft.add_squad()
		draft.add_squad()
		for step in [[0, "tank"], [0, "tank"], [1, "ifv"], [1, "ifv"], [2, "scout"], [2, "scout"]]:
			_check(draft.add_unit(step[0], step[1]))
		_check(draft.set_squad_role(1, "flanker"))
		_check(draft.set_formation(1, "echelon_right"))
		_check(draft.set_squad_role(2, "scout"))
		_check(draft.set_paint(0, 0, "#c8a02a"))
	if not draft.is_ready():
		push_error("army e2e army is not ready: %s" % [draft.problems()])
		quit(1)
		return
	var saved := ArmyStore.save(draft.to_doctrine(), stem)
	var game := ArmyStore.save(ArmyFormat.to_game_doctrine(draft.to_doctrine()), stem, "user://army_fight/")
	if saved.has("error") or game.has("error"):
		push_error(saved.get("error", game.get("error")))
		quit(1)
		return
	print("GARAGE_ARMY %s %d %d" % [saved["path"], draft.total_cost(), draft.unit_count()])
	print("GARAGE_GAME %s" % game["path"])
	print("GARAGE_CODE %s" % ArmyCode.encode(draft))
	quit(0)


func _check(error: String) -> void:
	if error != "":
		push_error("army e2e build step failed: " + error)
