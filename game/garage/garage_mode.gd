class_name GarageMode
extends GameMode
## --garage: build an army, tap FIGHT, and play the skirmish with it (GA2). The garage is a screen
## over the still-empty arena; FIGHT hands over to SkirmishMode in the same process (nothing has
## spawned yet, so no scene reload is needed).
##   --enemy=OPPONENT      preselect the opponent: cpu / cpu:<archetype> (rules' Army, default cpu = a random archetype)
##   --army=CODE           open with a shared army code (the garage's SHARE line; browser: ?garage&army=CODE)
##   --enemy-faction=NAME  the CPU's faction (condemned | gangs | law | syndicate; default random, never a mirror)
##   --faction=NAME        open on this faction (default: the saved army's, else the Condemned)
##   --seed=N              seed for a cpu army (default: random each fight; passed on to the skirmish)
##   --garage-settings=PATH  where first-run tip progress lives (default user://garage.cfg; "none" = fresh and
##                         unsaved, so automated runs never mark the player's tips as seen)
##   --garage-scratch      automated runs: settings in memory, armies AND the progression profile in an emptied SCRATCH_DIR,
##                         so smoke tests and screenshots never touch the player's tips, armies, or credits
##   --profile=PATH        the progression profile (default user://profile.json; "none" = in memory)
##   --credits=N           automated runs only (with --garage-scratch): start the scratch profile with N credits
##   --garage-autofight[=S]  tap FIGHT as soon as the garage opens, or after S seconds (smoke tests, screenshots of the
##                         handover; a delay lets music-smoke hear the garage's bed hand over to the match's opening)
##   --garage-army=PATH    open this saved army (the match loop's ARMY and REMATCH)
##   --garage-rematch      fight straight away with --garage-army, --enemy, --enemy-faction, --seed (REMATCH)
##   --challenge=ID        play challenge mission ID (Challenges) straight away
##   --garage-keep         with --garage-scratch: keep the scratch folder (a restart inside an automated run)
## After FIGHT an ArmyLoop shows results and offers REMATCH / ARMY (its flags: game/garage/army_loop.gd).
## Music (round 13): the garage holds the director on its own `garage` bed ([method music_state]); FIGHT releases it to
## the match mood, which before the first shot is the opening, `pre_match` (MusicDirector.release).
## Prints GARAGE_FIGHT player=<path> enemy=<opponent> enemy_path=<doctrine> seed=<n> budget=<points> green=<tanks>
## rust=<tanks> faction=<his> enemy_faction=<the CPU's> when the skirmish starts.

const SCRATCH_DIR := "user://garage_scratch/"
## Where a challenge's fixed armies are written for the skirmish to load (ArmyFormat.to_game_doctrine), outside the
## saved-armies folder so they never show up under LOAD.
const FIGHT_COPY := "user://army_fight/army.json"
## Budget the skirmish checks a challenge's fixed army against (challenge armies aren't bought).
const CHALLENGE_BUDGET := 100000

var screen: GarageScreen
var _layer: CanvasLayer


func role_name() -> String:
	return "GARAGE"


## Round 14 (G5; round 13's tour: a garage load showed the match loader's command-card tip, "STOP [S]", for ~5 s): what
## the loading screen shows instead when `flags` open the garage -- the army the garage will open with, the way
## `start` picks it (--garage-army, else the last army the player saved, else the first-visit starter).
## {} when the launch goes straight to a match (REMATCH, a challenge, an immediate autofight): the tip belongs there.
## {"title", "name", "line", "hint"}.
static func loader_card(flags: LaunchFlags) -> Dictionary:
	if not flags.has("garage") or flags.has("garage-rematch") or flags.has("challenge") \
			or (flags.has("garage-autofight") and flags.text("garage-autofight") in ["", "0"]):
		return {}
	var scratch := flags.has("garage-scratch")
	var path := flags.text("garage-army", "")
	if path == "" and not scratch:
		var settings_path := flags.text("garage-settings", GarageSettings.DEFAULT_PATH)
		path = GarageSettings.new("" if settings_path == "none" else settings_path).last_army
	var draft: ArmyDraft = null
	var catalog := ArmyCatalog.for_game(flags.text("faction") if Units.FACTIONS.has(flags.text("faction"))
			else Units.DEFAULT_FACTION)
	if path != "" and FileAccess.file_exists(path):
		draft = GarageMode.open_saved(path)
		if draft != null:
			catalog = draft.catalog
	if draft == null:
		draft = GarageScreen.starter_army(catalog)
	var parts: PackedStringArray = []
	var counts := draft.counts_by_unit()
	for unit_id: String in counts:
		var count := int(counts[unit_id])
		parts.append("%d %s" % [count, catalog.display_name(unit_id) if count == 1
				else GarageAdvice._pluralize(catalog.display_name(unit_id))])
	return {"title": "YOUR ARMY", "name": String(draft.army.get("name", "My Army")),
			"line": "%s   ·   %d / %s" % ["  ·  ".join(parts), draft.total_cost(), catalog.money(catalog.budget)],
			"hint": "Pick a faction, tap vehicles to buy them, put them in up to five squads. FIGHT when ready."}


## A saved army as a player army, priced by ITS faction's catalog (null if it can't be read). Round 19: a Law army read
## through the default (Condemned) catalog lost every vehicle, and REMATCH then refused to fight (the laptop tour).
static func open_saved(path: String) -> ArmyDraft:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var loaded := ArmyStore.read(path)
	if not loaded.has("doctrine"):
		return null
	var draft := ArmyDraft.from_doctrine(ArmyCatalog.for_game(ArmyCatalog.faction_of_army(loaded["doctrine"])),
			loaded["doctrine"])
	draft.make_player_army()
	return draft


## An army code (ArmyCode, the garage's SHARE line) as a player army, read with the faction whose roster keeps the
## most of its vehicles (a code carries unit ids, not a faction). {"draft": ArmyDraft} or {"error": String}.
static func open_code(code: String) -> Dictionary:
	var best: Dictionary = {}
	for faction: String in Units.FACTIONS:
		var decoded := ArmyCode.decode(code, ArmyCatalog.for_game(faction))
		if decoded.has("error"):
			return decoded
		var draft: ArmyDraft = decoded["draft"]
		if best.is_empty() or draft.unit_count() > (best["draft"] as ArmyDraft).unit_count():
			best = decoded
	(best["draft"] as ArmyDraft).make_player_army()
	return best


func start() -> void:
	main.hud.visible = false
	_layer = CanvasLayer.new()
	_layer.name = "Garage"
	_layer.layer = 10
	screen = GarageScreen.new()
	screen.name = "GarageScreen"
	screen.enemy = flags.text("enemy", screen.enemy)
	screen.enemy_faction = flags.text("enemy-faction", screen.enemy_faction)
	if Units.FACTIONS.has(flags.text("faction")):
		screen.faction = flags.text("faction")
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
	if flags.has("garage-army"):
		var opened := GarageMode.open_saved(flags.text("garage-army"))
		if opened != null:
			screen.draft = opened
			screen.army_path = flags.text("garage-army")
	if flags.has("army"):
		var opened := GarageMode.open_code(flags.text("army"))
		if opened.has("draft"):
			screen.draft = opened["draft"]
			screen.army_path = ""
		else:
			screen.report.call_deferred(String(opened["error"]))
	_layer.add_child(screen)
	main.add_child(_layer)
	screen.fight_requested.connect(fight)
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
## Round 19 (G1): both sides fight at the catalog's money (1000 credits = 1,750 points since R20) under the same rules: the CPU's
## army is bought here by GarageOpponent (a faction, at most five squads of five) and handed to the skirmish as a file,
## so the skirmish's own faction buyer (45 vehicles a side) never sizes the garage's opponent.
func fight(player_path: String, enemy: String) -> void:
	var seed_value := flags.integer("seed", randi() % 100000)
	var catalog := screen.draft.catalog
	var budget := catalog.budget_points()
	var player_faction := catalog.faction if catalog.faction != "" else Units.DEFAULT_FACTION
	var enemy_faction := GarageMode.resolve_enemy_faction(screen.enemy_faction, seed_value, player_faction)
	var built := GarageOpponent.build(enemy, enemy_faction, seed_value, catalog.budget if catalog.in_credits
			else Credits.of_points(budget))
	if built.has("error"):
		screen.report(String(built["error"]))
		return
	var enemy_path := _write_game_copy(built["doctrine"], "garage_enemy")
	# R4 (round 20): what the skirmish's status line names the opponent, once game/modes reads --enemy-title (a request
	# through the orchestrator); until then the line below overwrites the file path a moment after the handover.
	main.flags.values["enemy-title"] = "%s (CPU)" % Units.FACTION_NAMES.get(enemy_faction, enemy_faction)
	var loop := _start_skirmish(player_path, enemy_path, budget, seed_value, screen.draft.to_doctrine())
	loop.army_path = player_path
	loop.enemy = enemy
	loop.enemy_faction = enemy_faction
	# The skirmish names its opponent by the --enemy it was given, here the garage's file ("Skirmish vs
	# user://army_fight/garage_enemy.json"): name the faction he fights instead, and the arena.
	var arena_title := String(Arena.active.get("title", String(Arena.active.get("name", "")).capitalize()))
	main.hud.set_status("vs %s (CPU)%s" % [Units.FACTION_NAMES.get(enemy_faction, enemy_faction),
			"\n%s" % arena_title if arena_title != "" else ""])
	print("GARAGE_FIGHT player=%s enemy=%s enemy_path=%s seed=%d budget=%d green=%d rust=%d faction=%s enemy_faction=%s" % [
			player_path, enemy, enemy_path, seed_value, budget, main.game_match.team_tanks(Match.Team.GREEN).size(),
			main.game_match.team_tanks(Match.Team.RUST).size(), player_faction, enemy_faction])


## The faction the CPU fights as: `choice` when it names one, else RANDOM rolled from the seed the way the skirmish's
## faction menu rolls it (never a mirror: FactionPicker.roll_enemy), so a REMATCH of the seed is the same opponent.
static func resolve_enemy_faction(choice: String, seed_value: int, player_faction: String) -> String:
	if Units.FACTIONS.has(choice):
		return choice
	return FactionPicker.roll_enemy(seed_value, player_faction)


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
	if screen.settings.take_centre_tip():
		CentreTip.show_over(main)
	var loop := ArmyLoop.new()
	loop.name = "ArmyLoop"
	loop.main = main
	loop.progression = screen.progression
	loop.catalog = screen.draft.catalog
	loop.army = army
	loop.seed_value = seed_value
	loop.budget = budget
	main.add_child(loop)
	loop.begin()
	return loop
