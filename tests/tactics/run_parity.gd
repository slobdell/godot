extends SceneTree
## `make tactics-parity` (doctrine X5): a scripted match where BOTH sides are commanded the same way —
## an ElementCommander hands each side's elements TASKS, and every formation, movement technique and battle
## drill below that comes from the shared library. Nothing here is available to only one side.
##
## It prints what a spectator would see: each element's shape, technique, drill and the reason for it, every
## few seconds, plus the score. The lead (2026-09-16): *"if the opposing computer player can easily create
## sophisticated formations all the time while the player can't … it would be no good."*
##
##   --seconds=90   how long to run          --green=<army>  --rust=<army>   army JSON in res://doctrines/

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const REPORT_SECONDS := 10
## Where the element decisions are written, as JSON lines in the announcer's K5 shape: a timeline audio can
## write lines against, the same way tests/announcer/fixtures holds theirs.
const EVENTS_OUT := "res://build/tactics/element_events.jsonl"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds := 90
	var armies := {"green": "combined_arms", "rust": "anvil_hammer"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = int(arg.trim_prefix("--seconds="))
		for team in ["green", "rust"]:
			if arg.begins_with("--%s=" % team):
				armies[team] = arg.trim_prefix("--%s=" % team)
	var case := TestCase.new()
	case.tree = self
	var arena := case.add_to_tree(ARENA.instantiate())
	var game_match := case.add_to_tree(MATCH.instantiate()) as Match
	game_match.seed_spawns(5, 0.0)
	game_match.elimination = true
	var orders := Orders.new(game_match)
	Orders.attach(game_match, orders)
	var elements := Elements.install(game_match, orders)
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var key := "green" if team == Match.Team.GREEN else "rust"
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % armies[key])
		if loaded.has("error"):
			print("PARITY_FAIL ", loaded["error"])
			quit(1)
			return
		var error := game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			print("PARITY_FAIL ", error)
			quit(1)
			return
	for i in 12:
		await physics_frame
	var commanders: Array = []
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var commander := ElementCommander.install(game_match, team, elements)
		commander.form_elements()
		commanders.append(commander)
	print("PARITY armies green=%s rust=%s elements=%d" % [armies["green"], armies["rust"], elements.all().size()])
	# Every decision either side takes, stamped the way MatchEventAdapter stamps a K5 event.
	var timeline: Array = []
	elements.element_reported.connect(func(event: Dictionary) -> void:
		var stamped := {"tick": game_match.tick,
				"t": snappedf(SimClock.seconds(game_match.tick), 0.01)}
		stamped.merge(event)
		timeline.append(stamped)
		print("PARITY_EVENT ", JSON.stringify(stamped)))

	var reported := {}
	for tick in seconds * 60:
		await physics_frame
		if tick % (REPORT_SECONDS * 60) != 0:
			continue
		print("PARITY t=%02ds score %d:%d alive %d:%d" % [tick / 60, game_match.score_green,
				game_match.score_rust, game_match.alive_count(Match.Team.GREEN),
				game_match.alive_count(Match.Team.RUST)])
		for element: Element in elements.all():
			var side := "GREEN" if element.team == Match.Team.GREEN else "RUST "
			print("PARITY   %s %s | task %s" % [side, element.describe(),
					ElementTask.describe(element.task) if not element.task.is_empty() else "-"])
			reported[element.formation] = true
			if element.drill != "":
				reported[element.drill] = true
	print("PARITY shapes and drills seen: %s" % ", ".join(PackedStringArray(reported.keys())))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVENTS_OUT.get_base_dir()))
	var file := FileAccess.open(EVENTS_OUT, FileAccess.WRITE)
	if file != null:
		for event: Dictionary in timeline:
			file.store_line(JSON.stringify(event))
	print("PARITY events %d -> %s" % [timeline.size(), EVENTS_OUT])
	print("PARITY_DONE score %d:%d" % [game_match.score_green, game_match.score_rust])
	case.teardown()
	quit(0)
