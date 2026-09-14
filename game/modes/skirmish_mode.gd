class_name SkirmishMode
extends GameMode
## Single player commands squads on the tactical map vs a CPU doctrine. Squad vs squad
## elimination; starts in a planning pause. See _agents/tactical_map.md.
##   --player=DOCTRINE (default player_default)   --enemy=DOCTRINE (default individuals)
## A DOCTRINE is a name in res://doctrines/ or a full path (e.g. user://doctrines/mine.json from the garage).


func role_name() -> String:
	return "SKIRMISH"


func start() -> void:
	var game_match := main.game_match
	game_match.has_local_player = false
	var lineups := {Match.Team.GREEN: flags.text("player", "player_default"), Match.Team.RUST: flags.text("enemy", "individuals")}
	for team in lineups:
		var loaded := Doctrine.load_file(doctrine_path(lineups[team]))
		var error: String = loaded.get("error", "")
		if error == "":
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error(error)
			main.hud.set_status("Can't start skirmish: " + error)
			return
	game_match.elimination = true
	game_match.finished.connect(func(_result: Dictionary) -> void:
		main.hud.show_banner("VICTORY" if game_match.alive_count(Match.Team.GREEN) > 0 else "DEFEAT"))
	var tactical := TacticalMap.new()
	tactical.name = "TacticalMap"
	tactical.game_match = game_match
	tactical.camera = main.camera
	main.hud.add_child(tactical)
	main.hud.set_status("Skirmish vs %s" % lineups[Match.Team.RUST])
	tactical.set_paused(true, "PLANNING: give orders, then press Space to begin")


static func doctrine_path(name_or_path: String) -> String:
	return name_or_path if name_or_path.contains("://") else "res://doctrines/%s.json" % name_or_path
