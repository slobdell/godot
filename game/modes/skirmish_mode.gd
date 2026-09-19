class_name SkirmishMode
extends GameMode
## Single player commands squads on the tactical map vs a CPU doctrine. Squad vs squad
## elimination; starts in a planning pause. See _agents/tactical_map.md.
##   --player=DOCTRINE (default player_default; must fit --budget, default Units.DEFAULT_BUDGET)
##   --enemy=DOCTRINE (default cpu: a seeded budgeted army; cpu:<archetype> picks one, see Army.ARCHETYPES)
##   --seed=N (the CPU army's seed; default: the clock)   --no-control (no control point at the center; on by default)
##   --player-faction=NAME / --enemy-faction=NAME (L3: condemned | gangs | law | syndicate). Either one turns that
##     side into a faction army whose SIZE falls out of the faction's costs, and raises the default budget to
##     Units.BASELINE_BUDGET (~30 a side). The match runner spells these --green-faction / --rust-faction; here
##     they follow --player / --enemy so one skirmish command reads consistently.
##   --pick-faction / --no-pick-faction  show (or skip) the faction menu before the match. It shows by default on
##     an interactive run that named no faction, and never in scripted, playtest or smoke runs.
##   --commander (a CpuCommander issues the CPU army's squad orders; experimental)
##   --ui-scale=1.25  bigger buttons, chips, and text (accessibility; 0.75..2)
##   --zoom=0..1  the starting camera height (default: frame the army, no lower than START_ZOOM)
##   --no-elements  the player's squads stay hand-driven (no L1 leaders picking formations and drills)
##   --element-cpu / --no-element-cpu  the CPU army is (or isn't) run by doctrine's ElementCommander; default ELEMENT_CPU_DEFAULT
##   --cinematic  the camera directs itself: it finds the fighting, holds a shot, and cuts (spectating, trailers)
##   --no-vision-camera  turn off L4 vision framing (a free camera with no zoom-out cap; galleries and comparisons)
##   --command-playtest=DIR  tap through every squad with off-screen radar orders; log the camera (CommandPlaytest)
##   --scripted   skip the planning pause and play a fixed order sequence (smoke tests, screenshots)
##   --camera-frame=close|default|wide  how much of the screen the commanded element fills (X3 dial)
##   --alert-lines=1..3  unseen alerts shown at once above the group chips (X3 dial; default 1)
##   --camera-readout=off  hide the live camera values (round 6: on, so the lead can find the camera; P copies the pose)
##   --hints=off|fresh  no control hints (X6; they retire themselves as each control is used), or all of them, remembering nothing
##   --squad-orders-test=DIR  the lead's sequence: order every squad in turn, then where each unit actually ends up
##   --response-test=DIR  click → order → ack → first visible movement, in ms, at this army size (ResponsePlaytest)
##   --hud-cost=PATH  X4: what each HUD widget costs in draw calls and _process at ~30 a side (HudCostProbe)
##   --shell-playtest=DIR  the first minutes through real input: faction menu, planning, the camera in battle (ShellPlaytest)
##   --control-playtest=DIR  a scripted session through real input events, screenshots and orders.jsonl (ControlPlaytest)
##   --camera-looks=DIR  round 6 X3: both sides CPU; freeze the first fight and photograph it from a grid of camera poses
##     (pitch x distance x FOV), then write DIR/index.html for the lead to pick from (CameraLooks)
##     --camera-looks-grid=arena  three frames only (round 5's start pose, the new default, the overview): the arena tour
##     --camera-looks-pitches=15,20,25 / -distances=35,50 / -fovs=60  a follow-up grid around a pick (no round-5 row)
##   --touch-map  round 2's tap grammar (squad bar, drill and formation pickers) instead of the desktop controls
## Round 3 (control stream): the default is StarCraft-style desktop control (RtsControls, _agents/tactical_map.md "v4").
## A DOCTRINE is a name in res://doctrines/ or a full path (e.g. user://doctrines/mine.json from the garage).


const SCRIPT_BREAK_CONTACT_SECONDS := 30.0
## The closest the RTS camera starts (0 = close behind a tank, 1 = high over the arena); it frames the army.
## Round 6: the lead's pose from play is 49 m out (zoom 0.365; round 5 was 0.36, 48 m).
const START_ZOOM := 0.365
## The camera starts looking this far ahead of the player's base (tanks sit in the lower third).
const START_AHEAD := 25.0
const SCRIPT_FOLLOW_ZOOM := 0.42


func role_name() -> String:
	return "SKIRMISH"


## X5: what each side fields. A faction flag turns that side into a faction army; the budget follows, unless
## --budget says otherwise. Pure, so the sizes are testable without starting a match.
static func lineup_plan(player: String, enemy: String, player_faction: String, enemy_faction: String,
		explicit_budget: int) -> Dictionary:
	var any_faction := player_faction != "" or enemy_faction != ""
	var budget := explicit_budget if explicit_budget > 0 else (Units.BASELINE_BUDGET if any_faction else Units.DEFAULT_BUDGET)
	return {"budget": budget,
			Match.Team.GREEN: {"lineup": "cpu" if player_faction != "" and player == "player_default" else player,
					"faction": player_faction},
			Match.Team.RUST: {"lineup": enemy, "faction": enemy_faction}}


## X3 (the lead's dials): how much of the screen the commanded element fills. `close` is the Twisted Metal end,
## `wide` shows more ground around it (still inside the force's horizon cap).
const CAMERA_FRAMES := {"close": 0.9, "default": RtsCamera.VISION_FRAME_INSET, "wide": 0.6}


static func camera_frame_inset(p_flags: LaunchFlags) -> float:
	return float(CAMERA_FRAMES.get(p_flags.text("camera-frame", "default"), RtsCamera.VISION_FRAME_INSET))


## X3: how many unseen alerts show above the group chips at once (1 by default, at most 3).
static func alert_lines(p_flags: LaunchFlags) -> int:
	return clampi(p_flags.integer("alert-lines", 1), 1, 3)


## Which team has a human commander, or -1 when nobody does (ai reads it as `OrderFeed.player_team`). A brain that has
## never been ordered otherwise follows its doctrine's objective and drives at the enemy base, which in a faction
## skirmish means the *player's* army leaves before he can command it (the lead, round 5: "they all also just rush
## forward right away at the start"). With this set, his vehicles hold their spawn until he orders them.
## `--cinematic` is spectator mode: nobody is commanding, so it returns -1 on purpose and both sides play themselves.
## Don't "tidy" that away, or SPECTATE becomes two armies sitting still.
static func commanded_team(p_flags: LaunchFlags) -> int:
	return -1 if SkirmishMode.spectated(p_flags) else Match.Team.GREEN


## Nobody commands either side: spectating (--cinematic), or photographing a fight for the camera page (--camera-looks).
static func spectated(p_flags: LaunchFlags) -> bool:
	return p_flags.has("cinematic") or p_flags.has("camera-looks")


## Whether the CPU army is commanded by doctrine's ElementCommander (elements, formations, drills) rather than by its
## brains alone. `--element-cpu` / `--no-element-cpu` decide; otherwise ELEMENT_CPU_DEFAULT. Brains-only stays
## reachable for A/B measurement. Off (ai, 2026-09-17): doctrine beat brains 52-28 in small mirrors without the control
## point, but lost 32-16 in the setup skirmish plays (faction armies at 5200, control point on). Flip when a variant wins.
const ELEMENT_CPU_DEFAULT := false


static func cpu_runs_elements(p_flags: LaunchFlags) -> bool:
	if p_flags.has("no-element-cpu") or p_flags.has("no-elements"):
		return false
	return p_flags.has("element-cpu") or ELEMENT_CPU_DEFAULT


## Whether the faction menu should open: an interactive run that named no faction. Never in a scripted, playtest,
## smoke or browser-driven run, which must keep starting the same match they always did.
static func wants_faction_menu(flags: LaunchFlags) -> bool:
	if flags.has("no-pick-faction") or flags.has("scripted") or flags.has("control-playtest") \
			or flags.has("command-playtest") or flags.has("touch-map") or flags.has("camera-looks"):
		return false
	if flags.has("pick-faction"):
		return true
	return flags.text("player-faction") == "" and flags.text("enemy-faction") == "" \
			and DisplayServer.get_name() != "headless"


func start() -> void:
	if flags.has("shell-playtest"):
		ShellPlaytest.ensure(main.get_tree(), flags.text("shell-playtest"))
	if SkirmishMode.wants_faction_menu(flags):
		_pick_faction()
		return
	_start_match()


## X5: the faction menu. Picking restarts the skirmish with the flags, so the armies come out of exactly the same
## code path as --player-faction on the command line.
func _pick_faction() -> void:
	var picker := FactionPicker.new()
	picker.name = "FactionPicker"
	picker.budget = flags.integer("budget", Units.BASELINE_BUDGET)
	picker.player_faction = flags.text("player-faction", Units.DEFAULT_FACTION)
	picker.enemy_faction = flags.text("enemy-faction", Units.DEFAULT_FACTION)
	main.hud.add_child(picker)
	main.hud.set_status("Pick a faction, then FIGHT")
	picker.arena = flags.text("arena", GameLauncher.RANDOM)
	picker.chosen.connect(func(player_faction: String, enemy_faction: String) -> void:
		GameLauncher.start(main.get_tree(), SkirmishMode.faction_flags(flags, player_faction, enemy_faction, picker.arena)))


## X5: the flags the skirmish restarts with after the menu - everything it was launched with, plus the two
## factions, minus the menu itself (or it would open again). Pure, so the restart is testable.
static func faction_flags(current: LaunchFlags, player_faction: String, enemy_faction: String, arena := "") -> LaunchFlags:
	var next := LaunchFlags.new()
	next.values = current.values.duplicate()
	next.values.erase("pick-faction")
	next.values["no-pick-faction"] = ""
	next.values["player-faction"] = player_faction
	next.values["enemy-faction"] = enemy_faction
	if arena != "":
		next.values["arena"] = arena
	return next


func _start_match() -> void:
	LoadingScreen.mark("mode_start")  # X4: where a FIGHT load's time goes (printed with LOAD_TIMING)
	var game_match := main.game_match
	game_match.has_local_player = false
	# Directive set 2: armies are bought with a budget. The CPU army is seeded (--seed, else the clock,
	# printed so a surprising match can be replayed). X5: a faction flag decides the side's roster and, with it,
	# how many vehicles the budget buys.
	var plan := SkirmishMode.lineup_plan(flags.text("player", "player_default"), flags.text("enemy", "cpu"),
			flags.text("player-faction"), flags.text("enemy-faction"), flags.integer("budget", 0))
	var lineups := {Match.Team.GREEN: String(plan[Match.Team.GREEN]["lineup"]),
			Match.Team.RUST: String(plan[Match.Team.RUST]["lineup"])}
	var budget := int(plan["budget"])
	var seed_value := flags.integer("seed", int(Time.get_unix_time_from_system()) % 100000)
	for team in lineups:
		var faction := String(plan[team]["faction"])
		var loaded := Army.load_army(lineups[team], seed_value, budget, faction)
		LoadingScreen.mark("army_%d_rolled" % team)
		var error: String = loaded.get("error", "")
		if error == "" and team == Match.Team.GREEN and faction == "":
			error = Army.check_budget(loaded["doctrine"], budget)
		if error == "":
			print("SKIRMISH_ARMY %s %s%s: %s" % [Match.TEAM_NAMES[team], lineups[team],
					" (%s)" % faction if faction != "" else "", Army.describe(loaded["doctrine"])])
			# Round 8 (squad, control approved): the player's army in at most five squads, so every vehicle is on a number key.
			var doctrine: Dictionary = SquadConsolidation.for_player(loaded["doctrine"]) if team == Match.Team.GREEN \
					else loaded["doctrine"]
			error = game_match.load_doctrine(team, doctrine)
			LoadingScreen.mark("army_%d_spawned" % team)
		if error != "":
			push_error(error)
			main.hud.set_status("Can't start skirmish: " + error)
			return
	LoadingScreen.mark("armies_built")
	# K1: the match's Orders (Match.orders once combat adds the field) and, until brains execute orders themselves
	# (ai X1), the adapter that makes ordered units obey.
	var orders := Orders.of(game_match)
	if orders == null:
		orders = Orders.new()
		Orders.attach(game_match, orders)
	# X3 (L1, CP1): every player squad becomes an element with a leader that picks the formation, the movement
	# technique and the battle drills from doctrine; the player gives it tasks and keeps direct control of any
	# unit it orders by hand. Doctrine's own note: "elements are not wired into the real game yet".
	var elements: Elements = null
	if not flags.has("no-elements"):
		elements = Elements.install(game_match, orders)
		# The player's elements are formed on demand, by the first task given to a control group: an element with
		# no task still runs its SOP, and an untasked leader would fight the player for the wheel.
		# Round 5: the switch for the CPU running doctrine (elements, formations, drills); off until a doctrine variant beats
		# brains at skirmish scale. A spectated match runs both sides that way. ai owns the commander; this is the flag.
		if SkirmishMode.cpu_runs_elements(flags):
			var cpu_teams := [Match.Team.RUST, Match.Team.GREEN] if SkirmishMode.spectated(flags) else [Match.Team.RUST]
			for cpu_team: int in cpu_teams:
				for squad in game_match.team_squads(cpu_team):
					elements.form(Array(squad.roster), String(squad.squad_name))
				ElementCommander.install(game_match, cpu_team, elements)
	LoadingScreen.mark("elements")
	var executor := OrderExecutor.new()
	executor.name = "OrderExecutor"
	executor.game_match = game_match
	executor.orders = orders
	main.add_child(executor)
	game_match.elimination = true
	# ai (round 5, reopened): a brain that has never been ordered falls back on its doctrine's objective and drives at the
	# enemy base — which in a faction skirmish is the *player's* army leaving before he can command it (the lead: "they
	# all also just rush forward right away at the start"). This tells the brains which side has a commander; they hold
	# their spawn until he orders them. A spectated match has no commander, so both sides play themselves.
	if SkirmishMode.commanded_team(flags) >= 0:
		game_match.set_meta("player_team", SkirmishMode.commanded_team(flags))
	# The center control point is on by default (the lead: "control point on by default"; combat X7 measured CPU vs CPU
	# at this budget: median match 92 s with it, most fights end under a minute without). --no-control turns it off;
	# --control is still accepted.
	game_match.control_point = not flags.has("no-control")
	# Stretch: --commander gives the CPU army a CpuCommander that issues squad orders. Opt-in: v1 made
	# the CPU weaker (see _agents/balance.md), so it stays off until a series shows it helps.
	if flags.has("commander"):
		var commander := CpuCommander.new()
		commander.name = "CpuCommander"
		commander.game_match = game_match
		commander.team = Match.Team.RUST
		game_match.add_child(commander)
	game_match.finished.connect(func(_result: Dictionary) -> void:
		main.hud.show_banner("VICTORY" if _result["winner"] == Match.TEAM_NAMES[Match.Team.GREEN] else "DEFEAT"))
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
	fog.invoke("setup", [{"texture": field.texture, "origin": field.origin,
			"size": field.cells * VisibilityField.CELL_SIZE}])
	field.refresh_all.call_deferred()
	LoadingScreen.mark("fog")
	# G4: an RTS camera over the player's base, looking toward the enemy.
	var rig := RtsCamera.new()
	rig.name = "RtsCamera"
	rig.camera = main.camera
	rig.edge_pan = not (flags.has("scripted") or flags.has("command-playtest") or flags.has("control-playtest"))
	var frame := Match.team_frame(Match.Team.GREEN)
	rig.yaw = 0.0 if frame["forward"] == Vector3.FORWARD else PI
	# C5: start where the vehicles read as vehicles: frame the whole army and the ground just ahead of it,
	# never higher than needed (--zoom=0..1 overrides, for screenshots and tuning).
	# Round 6: the first frame is the one the lead plays - squad 1 (the group the planning pause selects), not the whole
	# army. At his 35° telephoto, fitting thirty vehicles climbed to ~110 m and the vision camera then swooped in.
	var army: Array = []
	var middle := Vector3.ZERO
	var first: Array = Array(game_match.team_squads(Match.Team.GREEN)[0].roster) if not game_match.team_squads(Match.Team.GREEN).is_empty() else []
	for tank in game_match.sorted_team_tanks(Match.Team.GREEN):
		if not first.is_empty() and not first.has(String(tank.name)):
			continue
		army.append(tank.global_position)
		middle += tank.global_position
	army.append(middle / maxf(army.size(), 1.0) + (frame["forward"] as Vector3) * START_AHEAD)
	rig.frame(army, false, START_ZOOM)
	if flags.has("zoom"):
		rig.zoom = clampf(float(flags.text("zoom")), 0.0, 1.0)
	main.add_child(rig)
	print("SKIRMISH_CAMERA focus=(%.0f, %.0f) zoom=%.2f vehicles=%d" % [rig.focus.x, rig.focus.z, rig.zoom, army.size() - 1])
	var announcer := MatchAnnouncer.new()
	announcer.name = "Announcer"
	announcer.game_match = game_match
	announcer.team = Match.Team.GREEN
	game_match.add_child(announcer)
	# C6: one filtered feed to the HUD (merges losses, rate-limits order acks, adds squad-destroyed and
	# friendly-fire messages); the announcer's other messages pass through it.
	var messages := HudMessages.new()
	messages.name = "HudMessages"
	messages.game_match = game_match
	messages.team = Match.Team.GREEN
	main.add_child(messages)
	announcer.announced.connect(messages.relay)
	messages.posted.connect(main.hud.post_message)
	# Which arena this is (the lead picks it, or Arena rolls it from the seed): the name Arena built, not the flag.
	var arena_title := String(Arena.active.get("title", String(Arena.active.get("name", "")).capitalize()))
	main.hud.set_status("Skirmish vs %s%s%s" % [lineups[Match.Team.RUST],
			" (seed %d)" % seed_value if Army.is_cpu(lineups[Match.Team.RUST]) else "",
			"\n%s" % arena_title if arena_title != "" else ""])
	# Round 3: StarCraft-style desktop controls by default; round 2's tap grammar (squad bar, drill and formation
	# pickers) stays behind --touch-map until the lead playtests the new controls (control X6).
	LoadingScreen.mark("camera_hud")
	if flags.has("touch-map") or flags.has("command-playtest"):
		_start_touch_map(field, rig, messages)
	else:
		_start_desktop_controls(field, rig, messages, orders)
	LoadingScreen.mark("controls")


## Round 3's desktop controls: RtsControls (named "TacticalMap" so the HUD skin lays out around it), selection rings,
## the radar, the selection panel with its command card, and the group bar. Doctrine squads become control groups 1–5.
func _start_desktop_controls(field: VisibilityField, rig: RtsCamera, messages: HudMessages, orders: Orders) -> void:
	var game_match := main.game_match
	var controls := RtsControls.new()
	controls.name = "TacticalMap"
	controls.game_match = game_match
	controls.orders = orders
	controls.visibility = field
	controls.camera = main.camera
	controls.rig = rig
	controls.groups = ControlGroups.from_squads(game_match, Match.Team.GREEN)
	controls.elements = Elements.of_match(game_match)
	controls.movement.provider = MovementReadout.from_movement(game_match)  # X5: silent until nav's N1 is on main
	controls.element_log.attach(controls.elements, game_match)  # X7: "why did my element do that"
	rig.facing = controls.selection_facing  # round 7 (A): the camera's yaw follows the selection's facing
	main.hud.add_child(controls)
	var markers := SelectionMarkers.new()
	markers.name = "SelectionMarkers"
	markers.game_match = game_match
	markers.selection = controls.selection
	main.add_child(markers)
	var radar := Radar.new()
	radar.name = "Radar"
	radar.game_match = game_match
	radar.controls = controls
	radar.visibility = field
	controls.add_child(radar)
	radar.read_arena(main.arena)
	var panel := SelectionPanel.new()
	panel.name = "SelectionPanel"
	panel.controls = controls
	controls.add_child(panel)
	var bar := GroupBar.new()
	bar.name = "GroupBar"
	bar.controls = controls
	bar.panel = panel
	controls.add_child(bar)
	# X2: the elements you aren't watching, pinned to the screen edge, plus the alert strip (Q jumps).
	var edge := EdgeMarkers.new()
	edge.name = "EdgeMarkers"
	edge.controls = controls
	controls.add_child(edge)
	controls.markers = edge
	edge.alert_lines = SkirmishMode.alert_lines(flags)
	# X6: the controls a new player can discover, retired one by one as they're used (--hints=off hides them).
	if flags.text("hints", "on") != "off" and not (flags.has("scripted") or flags.has("control-playtest") or SkirmishMode.spectated(flags)):
		var hints := ControlHints.new()
		if flags.text("hints") == "fresh":
			hints.store_path = ""
		controls.add_child(hints)
	if flags.has("cinematic"):
		# Stretch: a camera that watches the fight on its own. It replaces the vision framing rather than fighting
		# it, because nobody is earning this view - it is the spectator's. Everything else (orders, the HUD, the
		# planning pause) still works, so you can take the wheel back at any point by moving the camera.
		var director := CinematicCamera.new()
		director.name = "CinematicCamera"
		director.rig = rig
		director.game_match = game_match
		main.add_child(director)
		director.start()
		# A spectator sees both sides. Without this the camera cuts to the best scene on the field and films an
		# empty floor, because the fog of war has hidden every vehicle in it.
		controls.reveal_all = true
		var fog := main.get_node_or_null("FogOfWar")
		if fog != null:
			(fog as Node3D).visible = false
	elif not flags.has("no-vision-camera") and not flags.has("camera-looks"):
		# L4 (control X1): the camera frames the element you are commanding and never zooms out past what the force
		# can collectively see (the lead: "a bird's eye view is just an unearned god view").
		rig.vision = controls.vision_state
		rig.vision_inset = SkirmishMode.camera_frame_inset(flags)
	controls.command_issued.connect(func(command: Dictionary, error: String) -> void:
		messages.order(controls.describe(command), error))
	# Round 6: the camera's live values and keys, so the lead can find the camera in play (P copies the pose).
	if flags.text("camera-readout", "on") != "off" and not (flags.has("scripted") or SkirmishMode.spectated(flags)):
		var readout := CameraReadout.new()
		readout.name = "CameraReadout"
		readout.rig = rig
		readout.controls = controls
		controls.add_child(readout)
		controls.pose_copied.connect(readout.copied)
	if flags.has("squad-orders-test"):
		var squads := SquadOrdersPlaytest.new()
		squads.name = "SquadOrdersPlaytest"
		squads.controls = controls
		squads.out_dir = flags.text("squad-orders-test")
		main.add_child(squads)
		squads.run()
	if flags.has("response-test"):
		var response := ResponsePlaytest.new()
		response.name = "ResponsePlaytest"
		response.controls = controls
		response.out_dir = flags.text("response-test")
		main.add_child(response)
		response.run()
	if flags.has("hud-cost"):
		var probe := HudCostProbe.new()
		probe.name = "HudCostProbe"
		probe.main = main
		probe.out_path = flags.text("hud-cost")
		main.add_child(probe)
	if flags.has("camera-looks"):
		var looks := CameraLooks.new()
		looks.name = "CameraLooks"
		looks.game_match = game_match
		looks.rig = rig
		looks.camera = main.camera
		looks.out_dir = flags.text("camera-looks")
		looks.seed_value = flags.integer("seed", -1)
		looks.grid = flags.text("camera-looks-grid", "full")
		for axis in ["pitches", "distances", "fovs"]:
			if flags.has("camera-looks-" + axis):
				looks.set(axis, Array(flags.text("camera-looks-" + axis).split(",")).map(func(v: String) -> float: return float(v)))
				looks.show_today = false
		main.add_child(looks)
		looks.run()
	elif flags.has("control-playtest"):
		var playtest := ControlPlaytest.new()
		playtest.name = "ControlPlaytest"
		playtest.controls = controls
		playtest.radar = radar
		playtest.out_dir = flags.text("control-playtest")
		main.add_child(playtest)
		playtest.run()
	elif flags.has("scripted"):
		_play_desktop_script(controls)
	elif flags.has("cinematic"):
		# No planning pause for a spectator: the match has to be running for there to be anything to film.
		controls.recall_group(1)
	else:
		controls.recall_group(1)
		controls.set_paused(true, "PLANNING: select (click, drag, 1-5) and right-click to order; Space starts")


## Round 2's mobile tap grammar (--touch-map; also the camera playtest, which drives it).
func _start_touch_map(field: VisibilityField, rig: RtsCamera, messages: HudMessages) -> void:
	var game_match := main.game_match
	var tactical := TacticalMap.new()
	tactical.name = "TacticalMap"
	tactical.game_match = game_match
	tactical.visibility = field
	tactical.camera = main.camera
	tactical.ui_scale = clampf(float(flags.text("ui-scale", "1")), 0.75, 2.0)
	tactical.rig = rig
	main.hud.add_child(tactical)
	# C2: ground rings under the selected squad (and faint team marks), depth-tested under the models.
	var markers := SelectionMarkers.new()
	markers.name = "SelectionMarkers"
	markers.game_match = game_match
	markers.map = tactical
	main.add_child(markers)
	# G2: the radar, bottom right; it reads the same intel and visibility field as the map.
	var radar := Radar.new()
	radar.name = "Radar"
	radar.game_match = game_match
	radar.map = tactical
	radar.visibility = field
	tactical.add_child(radar)
	radar.read_arena(main.arena)
	tactical.command_issued.connect(func(command: Dictionary, error: String) -> void:
		messages.order(tactical.describe_command(command), error))
	if flags.has("command-playtest"):
		var playtest := CommandPlaytest.new()
		playtest.name = "CommandPlaytest"
		playtest.map = tactical
		playtest.radar = radar
		playtest.out_dir = flags.text("command-playtest")
		main.add_child(playtest)
		playtest.run()
	elif flags.has("scripted"):
		_play_script(tactical)
	else:
		tactical.set_paused(true, "PLANNING: give orders, then Resume (Space)")


## make skirmish-shots with the desktop controls: group 1 attack-moves up the left, group 2 moves up the right
## with a queued second leg, the camera rides along with group 1.
func _play_desktop_script(controls: RtsControls) -> void:
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var ahead := forward.dot(Vector3.FORWARD)  # +1 when "up the arena" is -z
	var steps := [[0.0, 1, "attack_move", [-30.0, 10.0 * ahead], false],
			[0.5, 2, "move", [40.0, 30.0 * ahead], false],
			[0.6, 2, "attack_move", [30.0, -10.0 * ahead], true]]
	var tree := main.get_tree()
	var elapsed := 0.0
	for step in steps:
		if float(step[0]) > elapsed:
			await tree.create_timer(float(step[0]) - elapsed).timeout
			elapsed = float(step[0])
		controls.recall_group(int(step[1]))
		controls.order_selection(String(step[2]), {"to": step[3], "queue": step[4]})
	controls.recall_group(1)
	if not flags.has("zoom"):
		controls.rig.zoom = SCRIPT_FOLLOW_ZOOM
	var group_one := func() -> Array:
		var points: Array = []
		for unit_name in controls.groups.members(1):
			var tank := main.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				points.append(tank.global_position)
		return points
	controls.rig.track(group_one, RtsCamera.Track.FOLLOW)


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
		if step[1]["squad"] == "Bravo" and tactical.rig != null:
			# Ride along with Alpha, a little above, so screenshots show the fight in 3D.
			tactical.select_squad("Alpha")
			if not flags.has("zoom"):
				tactical.rig.zoom = SCRIPT_FOLLOW_ZOOM
			tactical.follow_selected()


static func doctrine_path(name_or_path: String) -> String:
	return name_or_path if name_or_path.contains("://") else "res://doctrines/%s.json" % name_or_path
