class_name GarageMode
extends GameMode
## --garage: build an army, tap FIGHT, and play the skirmish with it (GA2). The garage is a screen
## over the still-empty arena; FIGHT hands over to SkirmishMode in the same process (nothing has
## spawned yet, so no scene reload is needed).
##   --enemy=OPPONENT      preselect the opponent: cpu / cpu:<archetype> (rules' Army, default cpu = a random archetype)
##   --seed=N              seed for a cpu army (default: random each fight; passed on to the skirmish)
##   --army=CODE           open with a shared army code (ArmyCode; browser: ?garage&army=CODE)
##   --garage-settings=PATH  where first-run tip progress lives (default user://garage.cfg; "none" = fresh and
##                         unsaved, so automated runs never mark the player's tips as seen)
##   --garage-scratch      automated runs: settings in memory AND armies saved to an emptied SCRATCH_DIR, so smoke
##                         tests and screenshots never touch the player's tips, last army, or saved armies
##   --garage-panel=NAME   open an overlay on start: compare | share (screenshots)
##   --garage-autofight    tap FIGHT as soon as the garage opens (smoke tests, screenshots of the handover)
## Prints GARAGE_FIGHT player=<path> enemy=<opponent> enemy_path=<doctrine> seed=<n> budget=<n> green=<tanks> rust=<tanks>
## when the skirmish starts.

const SCRATCH_DIR := "user://garage_scratch/"
## Until checkpoint 1, FIGHT hands the skirmish a v1 copy of the army here (ArmyFormat.to_game_doctrine),
## outside the saved-armies folder so it never shows up under LOAD.
const FIGHT_COPY := "user://army_fight/army.json"

var screen: GarageScreen
var _layer: CanvasLayer


func role_name() -> String:
	return "GARAGE"


func start() -> void:
	main.hud.visible = false
	_layer = CanvasLayer.new()
	_layer.name = "Garage"
	_layer.layer = 10
	screen = GarageScreen.new()
	screen.name = "GarageScreen"
	screen.enemy = flags.text("enemy", screen.enemy)
	if flags.has("garage-settings"):
		var settings := flags.text("garage-settings")
		screen.settings = GarageSettings.new("" if settings == "none" else settings)
	if flags.has("garage-scratch"):
		screen.settings = GarageSettings.new("")
		screen.store_dir = SCRATCH_DIR
		DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
		for file_name in DirAccess.get_files_at(SCRATCH_DIR):
			DirAccess.remove_absolute(SCRATCH_DIR.path_join(file_name))
	_layer.add_child(screen)
	main.add_child(_layer)
	screen.fight_requested.connect(fight)
	if flags.has("army"):
		screen.import_code(flags.text("army"))
	match flags.text("garage-panel"):
		"compare":
			screen.toggle_compare(true)
		"share":
			screen.toggle_share(true)
	if flags.has("garage-autofight"):
		screen.fight.call_deferred()


## Leave the garage and start the skirmish with the saved army at `player_path`.
func fight(player_path: String, enemy: String) -> void:
	var seed_value := flags.integer("seed", randi() % 100000)
	# CPU armies are built by the skirmish itself (Army.load_army) from this seed.
	var enemy_path := enemy
	var budget := screen.draft.catalog.budget
	var game_path := player_path
	if not ArmyFormat.game_reads_v2():
		var saved := ArmyStore.save(ArmyFormat.to_game_doctrine(screen.draft.to_doctrine()), FIGHT_COPY.get_file().get_basename(),
				FIGHT_COPY.get_base_dir())
		game_path = String(saved.get("path", player_path))
	_layer.queue_free()
	main.hud.visible = true
	main.flags.values.erase("garage")
	main.flags.values["skirmish"] = ""
	main.flags.values["player"] = game_path
	main.flags.values["budget"] = str(budget)
	main.flags.values["enemy"] = enemy_path
	main.flags.values["seed"] = str(seed_value)
	var skirmish := SkirmishMode.new()
	skirmish.main = main
	skirmish.flags = main.flags
	main.mode = skirmish
	skirmish.start()
	for tip: String in screen.settings.take_match_tips():
		main.hud.post_message(tip, Hud.INFO)
	print("GARAGE_FIGHT player=%s enemy=%s enemy_path=%s seed=%d budget=%d green=%d rust=%d" % [player_path, enemy, enemy_path, seed_value, budget,
			main.game_match.team_tanks(Match.Team.GREEN).size(), main.game_match.team_tanks(Match.Team.RUST).size()])
