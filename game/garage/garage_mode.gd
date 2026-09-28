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
##   --garage-scratch      automated runs: settings in memory, armies AND the progression profile in an emptied SCRATCH_DIR,
##                         so smoke tests and screenshots never touch the player's tips, armies, or credits
##   --profile=PATH        the progression profile (default user://profile.json; "none" = in memory)
##   --credits=N           automated runs only (with --garage-scratch): start the scratch profile with N credits
##   --garage-panel=NAME   open an overlay on start: compare | share | unlocks | challenges (screenshots)
##   --garage-autofight[=S]  tap FIGHT as soon as the garage opens, or after S seconds (smoke tests, screenshots of the
##                         handover; a delay lets music-smoke hear the garage's bed hand over to the match's opening)
##   --garage-army=PATH    open this saved army (the match loop's ARMY and REMATCH)
##   --tier=N              the budget tier to fight at (clamped to the tiers the player owns)
##   --garage-rematch      fight straight away with --garage-army, --enemy, --seed, --tier (REMATCH)
##   --challenge=ID        play challenge mission ID (Challenges) straight away
##   --garage-keep         with --garage-scratch: keep the scratch folder (a restart inside an automated run)
## After FIGHT an ArmyLoop shows results and offers REMATCH / ARMY (its flags: game/garage/army_loop.gd).
## Music (round 13): the garage holds the director on its own `garage` bed ([method music_state]); FIGHT releases it to
## the match mood, which before the first shot is the opening, `pre_match` (MusicDirector.release).
## Prints GARAGE_FIGHT player=<path> enemy=<opponent> enemy_path=<doctrine> seed=<n> budget=<n> green=<tanks> rust=<tanks>
## when the skirmish starts.

const SCRATCH_DIR := "user://garage_scratch/"
## Until checkpoint 1, FIGHT hands the skirmish a v1 copy of the army here (ArmyFormat.to_game_doctrine),
## outside the saved-armies folder so it never shows up under LOAD.
const FIGHT_COPY := "user://army_fight/army.json"
## Budget the skirmish checks a challenge's fixed army against (challenge armies aren't bought).
const CHALLENGE_BUDGET := 100000

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
	if flags.has("profile"):
		screen.progression = Progression.new("" if flags.text("profile") == "none" else flags.text("profile"))
	if flags.has("garage-scratch"):
		screen.settings = GarageSettings.new("")
		screen.store_dir = SCRATCH_DIR
		DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
		if not flags.has("garage-keep"):
			for file_name in DirAccess.get_files_at(SCRATCH_DIR):
				DirAccess.remove_absolute(SCRATCH_DIR.path_join(file_name))
		screen.progression = Progression.new(SCRATCH_DIR.path_join("profile.json"))
		if flags.has("credits") and not flags.has("garage-keep"):
			screen.progression.credits = flags.integer("credits", 0)
	if screen.progression == null:
		screen.progression = Progression.new()
	screen.tier = flags.integer("tier", 0)
	if flags.has("garage-army"):
		var loaded := ArmyStore.read(flags.text("garage-army"))
		if loaded.has("doctrine"):
			screen.draft = ArmyDraft.from_doctrine(ArmyCatalog.from_game(), loaded["doctrine"])
			screen.draft.make_player_army()
			screen.army_path = flags.text("garage-army")
	_layer.add_child(screen)
	main.add_child(_layer)
	screen.fight_requested.connect(fight)
	screen.challenge_requested.connect(start_challenge)
	if flags.has("army"):
		screen.import_code(flags.text("army"))
	match flags.text("garage-panel"):
		"compare":
			screen.toggle_compare(true)
		"share":
			screen.toggle_share(true)
		"unlocks":
			screen.toggle_unlocks(true)
		"challenges":
			screen.toggle_challenges(true)
	if flags.has("challenge"):
		start_challenge.call_deferred(flags.text("challenge"))
	elif flags.has("garage-rematch") or _autofight_delay() == 0.0:
		screen.fight.call_deferred()
	elif _autofight_delay() > 0.0:
		main.get_tree().create_timer(_autofight_delay()).timeout.connect(func() -> void: screen.fight())
	elif flags.text("army-loop-auto").split(",", false).slice(0, 1) == PackedStringArray(["quit"]):
		main.get_tree().quit.call_deferred()  # an automated loop that ended back in the builder


## The music this launch holds while the builder is up (MusicDirector.attach asks): the garage's own bed, or "" when
## the garage hands straight over to a match (REMATCH, a challenge, an immediate autofight), so the match opens on its
## own opening instead of a bar of blues.
func music_state() -> String:
	if flags.has("garage-rematch") or flags.has("challenge") or _autofight_delay() == 0.0:
		return ""
	return "garage"


## --garage-autofight: 0 for straight away, the seconds to wait when it names some, -1 when it is not set.
func _autofight_delay() -> float:
	if not flags.has("garage-autofight"):
		return -1.0
	var text := flags.text("garage-autofight")
	return maxf(0.0, float(text)) if text.is_valid_float() else 0.0


## Leave the garage and start the skirmish with the saved army at `player_path`.
func fight(player_path: String, enemy: String) -> void:
	var seed_value := flags.integer("seed", randi() % 100000)
	# CPU armies are built by the skirmish itself (Army.load_army) from this seed, at the same budget.
	var budget := screen.draft.catalog.budget
	var game_path := player_path
	if not ArmyFormat.game_reads_v2():
		game_path = _write_game_copy(screen.draft.to_doctrine(), FIGHT_COPY.get_file().get_basename())
	var loop := _start_skirmish(game_path, enemy, budget, seed_value, screen.draft.to_doctrine())
	loop.army_path = player_path
	loop.enemy = enemy
	print("GARAGE_FIGHT player=%s enemy=%s enemy_path=%s seed=%d budget=%d green=%d rust=%d" % [player_path, enemy, enemy, seed_value, budget,
			main.game_match.team_tanks(Match.Team.GREEN).size(), main.game_match.team_tanks(Match.Team.RUST).size()])


## Start challenge mission `challenge_id` (Challenges): its fixed army against its scripted opponent.
func start_challenge(challenge_id: String) -> void:
	if not Challenges.LIST.has(challenge_id) or not Challenges.playable(challenge_id, screen.base_catalog):
		screen.report("No playable challenge '%s'." % challenge_id)
		return
	var player := Challenges.army(challenge_id, "player", screen.base_catalog)
	var enemy_path := _write_game_copy(Challenges.army(challenge_id, "enemy", screen.base_catalog), "challenge_enemy")
	var player_path := _write_game_copy(player, "challenge_player")
	# Challenge armies are fixed, not bought: the budget only has to let the loader accept them.
	var loop := _start_skirmish(player_path, enemy_path, CHALLENGE_BUDGET, flags.integer("seed", 1), player)
	loop.challenge = challenge_id
	print("ARMY_CHALLENGE id=%s green=%d rust=%d" % [challenge_id, main.game_match.team_tanks(Match.Team.GREEN).size(),
			main.game_match.team_tanks(Match.Team.RUST).size()])


## Writes what the game's loader reads (ArmyFormat.to_game_doctrine) under user://army_fight/; returns the path.
func _write_game_copy(army: Dictionary, stem: String) -> String:
	var saved := ArmyStore.save(ArmyFormat.to_game_doctrine(army), stem, FIGHT_COPY.get_base_dir())
	if saved.has("error"):
		push_error(saved["error"])
	return String(saved.get("path", ""))


## Hand over to SkirmishMode in this process and attach the match loop (results, rematch).
func _start_skirmish(player_path: String, enemy_path: String, budget: int, seed_value: int, army: Dictionary) -> ArmyLoop:
	_layer.queue_free()
	var music := MusicDirector.find(main)
	if music != null:
		music.release()
	main.hud.visible = true
	main.flags.values.erase("garage")
	main.flags.values["skirmish"] = ""
	# Round 13 (G1): the army IS the faction choice. Without this, a windowed FIGHT opened the skirmish's faction menu
	# with nothing spawned (green=0 rust=0), and picking there restarted a plain skirmish without the player's army;
	# every garage check before was headless, where that menu never opens.
	main.flags.values["no-pick-faction"] = ""
	main.flags.values["player"] = player_path
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
	var loop := ArmyLoop.new()
	loop.name = "ArmyLoop"
	loop.main = main
	loop.progression = screen.progression
	loop.catalog = screen.draft.catalog
	loop.army = army
	loop.seed_value = seed_value
	loop.tier = screen.tier
	loop.budget = budget
	main.add_child(loop)
	loop.begin()
	return loop
