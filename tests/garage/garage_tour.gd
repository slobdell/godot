extends SceneTree
## Round 13 (G1): the garage as a player meets it, driven by taps, with a frame at every step. The lead had never played
## the garage; every garage check before this one was headless and started from `--garage`, not from the title.
##
##   make remote T=garage-tour        # both aspects on builder0's display -> build/screenshots/garage-tour/<aspect>/
##
## The path (round 19): the title -> GARAGE -> The Law -> CLEAR -> buy three -> + NEW SQUAD -> pick a vehicle up and move
## it -> sell one by a second tap -> drag a card onto a squad -> VS -> SUGGESTED -> FIGHT -> the match -> results ->
## REMATCH -> results -> ARMY -> back in the garage. Taps and drags are real input events at the control's centre (Input.parse_input_event), so
## a button that is covered, off screen or unwired shows up as a step that did nothing.
## Prints TOUR_STEP <n> <name> ok|FAIL <detail> per step and TOUR_DONE failed=<n>; the frames are the evidence.
## Flags (after --): --tour-out=<abs dir> (required), --tour-match=S (seconds each match runs, default 25),
## --tour-fresh (forget the player's tips, credits and armies first), plus whatever the title keeps for the session
## (--ui-touch for the phone run).

const TITLE := "res://game/ui/widgets/title/title_screen.tscn"

var out := ""
var match_seconds := 25.0
var step := 0
var failed := 0
var saw_centre_tip_again := false


func _initialize() -> void:
	var flags := LaunchFlags.from_environment()
	out = flags.text("tour-out")
	match_seconds = float(flags.text("tour-match", "25"))
	DirAccess.make_dir_recursive_absolute(out)
	if flags.has("tour-fresh"):
		_forget_the_player()
	_run.call_deferred()


## A first visit: no tips seen, no credits, no saved armies. Only with --tour-fresh, and only ever in a worktree's own
## Godot user dir (override.cfg) on the build machine: the title does not carry --garage-scratch into the garage.
func _forget_the_player() -> void:
	for path in [GarageSettings.DEFAULT_PATH, Progression.DEFAULT_PATH]:
		DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(ArmyStore.DIR):
		return
	for file_name in DirAccess.get_files_at(ArmyStore.DIR):
		DirAccess.remove_absolute(ArmyStore.DIR.path_join(file_name))


func _run() -> void:
	change_scene_to_file(TITLE)
	await _seconds(5.0)
	await _shot("title", true, "")
	var garage_button := _find_button(current_scene, "GARAGE")
	if not await _check("title offers GARAGE", garage_button != null, "" if garage_button else "the title menu has no GARAGE entry"):
		return _finish()
	_tap(garage_button)
	var screen: GarageScreen = await _wait_for(func() -> Variant: return root.find_child("GarageScreen", true, false), 60.0)
	if not await _check("GARAGE opens the builder", screen != null, "" if screen else "no GarageScreen after 60 s"):
		return _finish()
	# The loading screen (GameLauncher's, on the root) is still up when the builder exists: frame it, then wait for it
	# to fade, which is when a player can use the builder.
	# Round 14 (G5): a garage load shows the army card, not a command-card tip.
	var loader := LoadingScreen.current
	await _shot("garage_loading", loader == null or not loader.garage_card.is_empty(), "the loading screen %s%s" % [
			"is up" if loader != null else "is gone",
			(", army card: %s" % loader.garage_card.get("line", "")) if loader != null and not loader.garage_card.is_empty() else ""])
	var loaded: Variant = await _wait_for(func() -> Variant: return true if LoadingScreen.current == null else null, 60.0)
	await _seconds(0.5)
	await _shot("garage_open", loaded != null, "" if loaded != null else "the loading screen never went away")

	# Round 19 (G3): the garage he asked for, by taps: the Law (faction), sell to make room, buy, pick up and move, sell
	# by a second tap, drag a card onto a squad, a new squad, the opponent. Every step is a real tap or drag.
	# Round 20 (R3), his rule played, doubled in round 22 (A2): ten squads of five Road Gangs scouts is exactly the 2000
	# credits, by 50 taps; a 51st is refused as full. Then the Syndicate's all-scout army: 16, and the money runs out
	# before the slots (the Law's 25 now spend 2000 exactly).
	_tap(_find_named(screen, "Faction_gangs"))
	await _seconds(0.6)
	_tap(_find_named(screen, "Clear"))
	await _seconds(0.4)
	for i in ArmyCatalog.MAX_UNITS + 1:
		_tap(_find_named(screen, "Card_gang_scout"))
		await _seconds(0.15)
	await _seconds(0.5)
	await _shot("gangs_50_scouts", screen.faction == "gangs" and _units(screen) == ArmyCatalog.MAX_UNITS
			and screen.draft.squads().size() == ArmyCatalog.MAX_SQUADS and screen.draft.remaining_budget() == 0
			and screen.toast_text().begins_with("Your army is full"),
			"51 taps on the Rat Rod: %d vehicles in %d squads, %d CR left (%s)" % [_units(screen), screen.draft.squads().size(),
			screen.draft.remaining_budget(), screen.toast_text()])
	_tap(_find_named(screen, "Faction_syndicate"))
	await _seconds(0.6)
	_tap(_find_named(screen, "Clear"))
	await _seconds(0.4)
	for i in 16:
		_tap(_find_named(screen, "Card_syn_scout"))
		await _seconds(0.15)
	await _seconds(0.5)
	await _shot("syndicate_16_scouts", _units(screen) == 16 and screen.draft.remaining_budget() == 80
			and screen.toast_text().begins_with("Your credits are spent"),
			"16 taps on the Syndicate scout: %d vehicles, %d CR left (%s)" % [_units(screen), screen.draft.remaining_budget(),
			screen.toast_text()])
	_tap(_find_named(screen, "Card_syn_scout"))
	await _seconds(0.5)
	await _shot("syndicate_17th_refused", _units(screen) == 16 and screen.toast_text().begins_with("Not enough credits"),
			"a 17th: %s" % screen.toast_text())
	_tap(_find_named(screen, "Faction_law"))
	await _seconds(0.6)
	_tap(_find_named(screen, "Suggested"))
	await _seconds(0.6)
	await _shot("faction_law", screen.faction == "law" and screen.draft.is_ready(),
			"tap The Law: %s, %d vehicles, %s" % [screen.faction, _units(screen), screen.toast_text()])
	_tap(_find_named(screen, "Clear"))
	await _seconds(0.4)
	_tap(_find_named(screen, "Card_law_tank"))
	await _seconds(0.3)
	_tap(_find_named(screen, "Card_law_scout"))
	await _seconds(0.3)
	_tap(_find_named(screen, "Card_law_ifv"))
	await _seconds(0.6)
	var three := Credits.of_unit("law_tank") + Credits.of_unit("law_scout") + Credits.of_unit("law_ifv")
	await _shot("bought_three", _units(screen) == 3 and screen.draft.remaining_budget() == Credits.GAME_CREDITS - three,
			"CLEAR, then three taps buy three: %d vehicles, %d CR left" % [_units(screen), screen.draft.remaining_budget()])
	_tap(_find_named(screen, "AddSquad"))
	await _seconds(0.4)
	var squad_0 := _find_named(screen, "Squad_0")
	_tap(squad_0.find_child("Unit_0", true, false) as Control if squad_0 != null else null)
	await _seconds(0.6)
	await _shot("picked_up", screen.picked == [0, 0], "tap a vehicle: picked up (%s)" % screen.toast_text())
	var squad_1 := _find_named(screen, "Squad_1")
	_tap(squad_1.find_child("Header", true, false) as Control if squad_1 != null else null)
	await _seconds(0.6)
	await _shot("moved", screen.draft.squads().size() == 2 and screen.draft.units_of(1).size() == 1,
			"tap BRAVO: it moves there (%s)" % screen.toast_text())
	var before := _units(screen)
	var chip := (_find_named(screen, "Squad_0").find_child("Unit_0", true, false) as Control) if _find_named(screen, "Squad_0") else null
	_tap(chip)
	await _seconds(0.3)
	_tap((_find_named(screen, "Squad_0").find_child("Unit_0", true, false) as Control) if _find_named(screen, "Squad_0") else null)
	await _seconds(0.6)
	await _shot("sold", _units(screen) == before - 1, "tap it twice: sold (%s)" % screen.toast_text())
	var card := _find_named(screen, "Card_law_suppressor")
	var target := _find_named(screen, "Squad_1")
	var count := _units(screen)
	if card != null and target != null:
		# Round 22 (A2): on the phone the card can sit below the list's fold (the vehicle column is narrower beside two
		# columns of squads); a player scrolls to it first.
		var list := card.get_parent()
		while list != null and not list is ScrollContainer:
			list = list.get_parent()
		if list != null:
			(list as ScrollContainer).ensure_control_visible(card)
			await _seconds(0.3)
		var dragged: bool = await _drag(card, target)
		await _seconds(0.6)
		await _shot("dragged_card", _units(screen) == count + 1, "drag a Suppressor card onto BRAVO: %d -> %d (a drag %s; %s)"
				% [count, _units(screen), "started" if dragged else "never started", screen.toast_text()])
	else:
		await _check("drag a card onto a squad", false, "no card (%s) or squad (%s)" % [card, target])
	_tap(_find_named(screen, "Opponent"))
	await _seconds(0.4)
	await _shot("opponent", screen.enemy_faction != GarageScreen.RANDOM, "VS: %s" % screen.enemy_faction)
	_tap(_find_named(screen, "Suggested"))
	await _seconds(0.6)
	await _shot("suggested", screen.draft.is_ready() and _units(screen) >= 5, "SUGGESTED: %d vehicles, %s" % [_units(screen),
			screen.toast_text()])

	# Round 22 (A2): the tour fights with ten squads: back to the Road Gangs, whose 50 Rat Rods it bought above (each
	# faction keeps its army).
	_tap(_find_named(screen, "Faction_gangs"))
	await _seconds(0.6)
	await _shot("ten_squads", screen.faction == "gangs" and screen.draft.squads().size() == ArmyCatalog.MAX_SQUADS
			and _units(screen) == ArmyCatalog.MAX_UNITS and screen.draft.is_ready(),
			"the Gangs' army: %d vehicles in %d squads" % [_units(screen), screen.draft.squads().size()])

	# The match loop's timing (ArmyLoop reads these when FIGHT starts it), so the tour does not wait out a real match.
	var game := current_scene as Main
	game.flags.values["army-loop-time"] = str(match_seconds)
	game.flags.values["army-loop-delay"] = "1"
	await _shot("before_fight", true, "")
	_tap(_find_named(screen, "Fight"))
	await _seconds(6.0)
	var picker := root.find_child("FactionPicker", true, false)
	var readout := root.find_child("CameraReadout", true, false)
	await _shot("fight_6s", picker == null and root.find_child("ArmyLoop", true, false) != null and readout == null,
			"FIGHT starts the garage's match (faction menu instead: %s; camera readout, the lead's tool, shown: %s)"
			% [picker != null, readout != null])
	if picker != null:
		return _finish()
	# Round 22 (A2): ten squads in, ten squads on the field (the skirmish's fold keeps them, C22.1), 50 vehicles.
	var fought := root.find_child("Match", true, false) as Match
	await _check("ten squads and 50 vehicles on the field", fought != null
			and fought.team_squads(Match.Team.GREEN).size() == ArmyCatalog.MAX_SQUADS
			and fought.sorted_team_tanks(Match.Team.GREEN).size() == ArmyCatalog.MAX_UNITS,
			"no match" if fought == null else "%d squads, %d vehicles" % [fought.team_squads(Match.Team.GREEN).size(),
			fought.sorted_team_tanks(Match.Team.GREEN).size()])
	# Round 15 (H1): the first fight from a fresh profile says the centre scores (CentreTip), once.
	var centre_tip := root.find_child("CentreTip", true, false)
	await _check("the first fight says the centre scores", centre_tip != null,
			"" if centre_tip != null else "no CentreTip on a fresh profile's first fight")
	await _seconds(maxf(1.0, match_seconds * 0.5 - 6.0))
	await _shot("match_mid", true, "")
	var results: Control = await _wait_for(func() -> Variant: return root.find_child("ResultsScreen", true, false),
			match_seconds + 30.0)
	if not await _check("results after the match", results != null, "" if results else "no ResultsScreen"):
		return _finish()
	await _seconds(1.5)
	# Round 14 (G3): a time-out with nothing lost on either side is a DRAW, not a DEFEAT.
	var loop := root.find_child("ArmyLoop", true, false)
	var report: Dictionary = loop.get("last_report") if loop != null and loop.get("last_report") is Dictionary else {}
	var headline := _find_named(results, "Headline") as Label
	var shown := headline.text if headline != null else ""
	var quiet := String(report.get("reason", "")) == "time_limit" \
			and int(report.get("teams", {}).get("green", {}).get("units_lost", -1)) == 0 \
			and int(report.get("teams", {}).get("rust", {}).get("units_lost", -1)) == 0
	# The skirmish plays the control point: a time-out is judged on it first (Match.result), so only an even point counts.
	var playing := current_scene as Main
	var control: Array = playing.game_match.control_score if playing != null and playing.game_match != null else [0, 0]
	quiet = quiet and control[0] == control[1]
	var why := _find_named(results, "Reason") as Label
	await _shot("results", shown != "" and (not quiet or shown == "DRAW") and (why == null or why.text.contains("—")
			or String(report.get("reason", "")) != "time_limit"),
			"headline %s (reason %s, nothing lost and the point even at %s: %s; says '%s')" % [shown, report.get("reason", "?"),
			control, quiet, why.text if why != null else "?"])

	# Round 15 (H6): a loss on the point teaches the first fight's tip, word for word.
	var lesson := _find_named(results, "Lesson") as Label
	if ResultsScreen.point_lesson(report, String(loop.get("last_paid").get("outcome", "")) if loop != null else "") != "":
		await _check("the loss on the point repeats the tip", lesson != null and lesson.text in [CentreTip.LINE, CentreTip.RINGS_LINE],
				"lesson: '%s'" % (lesson.text if lesson != null else "?"))
	_tap(_find_named(results, "Rematch"))
	var first_results := results.get_instance_id()
	var rematch_results: Control = await _wait_for(func() -> Variant:
		if root.find_child("CentreTip", true, false) != null:
			saw_centre_tip_again = true
		var found := root.find_child("ResultsScreen", true, false)
		return found if found != null and found.get_instance_id() != first_results else null, match_seconds + 60.0)
	if not await _check("REMATCH plays again", rematch_results != null, "" if rematch_results else "no second ResultsScreen"):
		return _finish()
	await _check("the centre tip is not shown twice", not saw_centre_tip_again, "" if not saw_centre_tip_again
			else "a CentreTip came up on the REMATCH")
	await _seconds(1.5)
	await _shot("rematch_results", true, "")

	_tap(_find_named(rematch_results, "Army"))
	var back: GarageScreen = await _wait_for(func() -> Variant: return root.find_child("GarageScreen", true, false), 60.0)
	if await _check("ARMY returns to the builder", back != null, "" if back else "no GarageScreen after ARMY"):
		await _seconds(2.0)
		await _shot("back_in_garage", true, "")
	_finish()


func _finish() -> void:
	print("TOUR_DONE failed=%d out=%s" % [failed, out])
	quit(1 if failed > 0 else 0)


func _check(name: String, ok: bool, detail: String) -> bool:
	step += 1
	if not ok:
		failed += 1
	print("TOUR_STEP %02d %s %s%s" % [step, name, "ok" if ok else "FAIL", "  " + detail if detail != "" else ""])
	return ok


## A frame of the step, named by its order, and the step's verdict.
func _shot(name: String, ok: bool, detail: String) -> void:
	await _check(name, ok, detail)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%02d_%s.png" % [step, name]))


func _seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _wait_for(probe: Callable, timeout_s: float) -> Variant:
	var waited := 0.0
	while waited < timeout_s:
		var found: Variant = probe.call()
		if found != null:
			return found
		await _seconds(0.25)
		waited += 0.25
	return null


func _units(screen: GarageScreen) -> int:
	return screen.draft.unit_count()


func _find_named(parent: Node, node_name: String) -> Control:
	if parent == null:
		return null
	return parent.find_child(node_name, true, false) as Control


func _find_button(parent: Node, text: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node
	return null


## A tap where the player would put a finger: the control's centre, as a mouse press and release.
func _tap(control: Control) -> void:
	if control == null:
		print("TOUR_TAP nothing to tap")
		return
	var at := control.get_global_rect().get_center()
	_mouse_button(at, true)
	_mouse_button(at, false)


func _drag(from: Control, to: Control) -> bool:
	var start := from.get_global_rect().get_center()
	var end := to.get_global_rect().get_center()
	_mouse_button(start, true)
	await process_frame
	var dragging := false
	for i in 16:
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(end, (i + 1) / 16.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = (end - start) / 16.0
		Input.parse_input_event(motion)
		await process_frame
		dragging = dragging or root.gui_is_dragging()
	_mouse_button(end, false)
	await process_frame
	return dragging


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
