class_name SkirmishMode
extends GameMode
## Single player commands squads on the tactical map vs a CPU doctrine. Squad vs squad
## elimination; starts in a planning pause. See _agents/tactical_map.md.
##   --player=DOCTRINE (default player_default)   --enemy=DOCTRINE (default individuals)
##   --scripted   skip the planning pause and play a fixed order sequence (smoke tests, screenshots)
## A DOCTRINE is a name in res://doctrines/ or a full path (e.g. user://doctrines/mine.json from the garage).


const SCRIPT_BREAK_CONTACT_SECONDS := 30.0


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
	# G1 fog of war: what Green can see, drawn over the arena and (G2) on the radar.
	var field := VisibilityField.new()
	field.name = "VisibilityField"
	field.game_match = game_match
	field.team = Match.Team.GREEN
	game_match.add_child(field)
	var fog := VisualSlot.new()
	fog.name = "FogOfWar"
	fog.slot = "fx.fog_of_war"
	main.add_child(fog)
	fog.invoke("setup", [{"texture": field.texture, "origin": VisibilityField.ORIGIN,
			"size": field.cells * VisibilityField.CELL_SIZE}])
	field.refresh_all.call_deferred()
	var tactical := TacticalMap.new()
	tactical.name = "TacticalMap"
	tactical.game_match = game_match
	tactical.visibility = field
	tactical.camera = main.camera
	main.hud.add_child(tactical)
	var announcer := MatchAnnouncer.new()
	announcer.name = "Announcer"
	announcer.game_match = game_match
	announcer.team = Match.Team.GREEN
	announcer.announced.connect(main.hud.post_message)
	game_match.add_child(announcer)
	tactical.command_issued.connect(func(command: Dictionary, error: String) -> void:
		announcer.announce_command(tactical.describe_command(command), error))
	main.hud.set_status("Skirmish vs %s" % lineups[Match.Team.RUST])
	if flags.has("scripted"):
		_play_script(tactical)
	else:
		tactical.set_paused(true, "PLANNING: give orders, then press Space to begin")


## A short, fixed sequence of player orders, so unattended runs (make skirmish-shots) show squads
## doing things: Alpha advances in a wedge, Bravo bounds up the other flank, then Alpha breaks contact.
func _play_script(tactical: TacticalMap) -> void:
	var steps := [[0.0, {"squad": "Alpha", "verb": "move", "to": [-30.0, 10.0], "facing": [0.0, -1.0]}],
			[0.5, {"squad": "Bravo", "verb": "bound", "to": [40.0, 0.0]}],
			[SCRIPT_BREAK_CONTACT_SECONDS, {"squad": "Alpha", "verb": "break_contact"}]]
	var tree := main.get_tree()
	var elapsed := 0.0
	for step in steps:
		if float(step[0]) > elapsed:
			await tree.create_timer(float(step[0]) - elapsed).timeout
			elapsed = float(step[0])
		tactical.select_squad(step[1]["squad"])
		tactical.issue(step[1])


static func doctrine_path(name_or_path: String) -> String:
	return name_or_path if name_or_path.contains("://") else "res://doctrines/%s.json" % name_or_path
