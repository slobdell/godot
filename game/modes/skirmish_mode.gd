class_name SkirmishMode
extends GameMode
## Single player commands squads on the tactical map vs a CPU doctrine. Squad vs squad
## elimination; starts in a planning pause. See _agents/tactical_map.md.
##   --player=DOCTRINE (default player_default; must fit --budget, default Units.DEFAULT_BUDGET)
##   --enemy=DOCTRINE (default cpu: a seeded budgeted army; cpu:<archetype> picks one, see Army.ARCHETYPES)
##   --seed=N (the CPU army's seed; default: the clock)   --no-control (no control point at the center; on by default)
##   --commander (a CpuCommander issues the CPU army's squad orders; experimental)
##   --ui-scale=1.25  bigger buttons, chips, and text (accessibility; 0.75..2)
##   --zoom=0..1  the starting camera height (default: frame the army, no lower than START_ZOOM)
##   --no-vision-camera  turn off L4 vision framing (a free camera with no zoom-out cap; galleries and comparisons)
##   --command-playtest=DIR  tap through every squad with off-screen radar orders; log the camera (CommandPlaytest)
##   --scripted   skip the planning pause and play a fixed order sequence (smoke tests, screenshots)
##   --control-playtest=DIR  a scripted session through real input events, screenshots and orders.jsonl (ControlPlaytest)
##   --touch-map  round 2's tap grammar (squad bar, drill and formation pickers) instead of the desktop controls
## Round 3 (control stream): the default is StarCraft-style desktop control (RtsControls, _agents/tactical_map.md "v4").
## A DOCTRINE is a name in res://doctrines/ or a full path (e.g. user://doctrines/mine.json from the garage).


const SCRIPT_BREAK_CONTACT_SECONDS := 30.0
## The closest the RTS camera starts (0 = close behind a tank, 1 = high over the arena); it frames the army.
const START_ZOOM := 0.36
## The camera starts looking this far ahead of the player's base (tanks sit in the lower third).
const START_AHEAD := 25.0
const SCRIPT_FOLLOW_ZOOM := 0.42


func role_name() -> String:
	return "SKIRMISH"


func start() -> void:
	var game_match := main.game_match
	game_match.has_local_player = false
	var lineups := {Match.Team.GREEN: flags.text("player", "player_default"), Match.Team.RUST: flags.text("enemy", "cpu")}
	# Directive set 2: armies are bought with a budget. The CPU army is seeded (--seed, else the clock,
	# printed so a surprising match can be replayed).
	var budget := flags.integer("budget", Units.DEFAULT_BUDGET)
	var seed_value := flags.integer("seed", int(Time.get_unix_time_from_system()) % 100000)
	for team in lineups:
		var loaded := Army.load_army(lineups[team], seed_value, budget)
		var error: String = loaded.get("error", "")
		if error == "" and team == Match.Team.GREEN:
			error = Army.check_budget(loaded["doctrine"], budget)
		if error == "":
			print("SKIRMISH_ARMY %s %s: %s" % [Match.TEAM_NAMES[team], lineups[team], Army.describe(loaded["doctrine"])])
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error(error)
			main.hud.set_status("Can't start skirmish: " + error)
			return
	# K1: the match's Orders (Match.orders once combat adds the field) and, until brains execute orders themselves
	# (ai X1), the adapter that makes ordered units obey.
	var orders := Orders.of(game_match)
	if orders == null:
		orders = Orders.new()
		Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.name = "OrderExecutor"
	executor.game_match = game_match
	executor.orders = orders
	main.add_child(executor)
	game_match.elimination = true
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
	fog.invoke("setup", [{"texture": field.texture, "origin": VisibilityField.ORIGIN,
			"size": field.cells * VisibilityField.CELL_SIZE}])
	field.refresh_all.call_deferred()
	# G4: an RTS camera over the player's base, looking toward the enemy.
	var rig := RtsCamera.new()
	rig.name = "RtsCamera"
	rig.camera = main.camera
	rig.edge_pan = not (flags.has("scripted") or flags.has("command-playtest") or flags.has("control-playtest"))
	var frame := Match.team_frame(Match.Team.GREEN)
	rig.yaw = 0.0 if frame["forward"] == Vector3.FORWARD else PI
	# C5: start where the vehicles read as vehicles: frame the whole army and the ground just ahead of it,
	# never higher than needed (--zoom=0..1 overrides, for screenshots and tuning).
	var army: Array = []
	var middle := Vector3.ZERO
	for tank in game_match.sorted_team_tanks(Match.Team.GREEN):
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
	main.hud.set_status("Skirmish vs %s%s" % [lineups[Match.Team.RUST],
			" (seed %d)" % seed_value if Army.is_cpu(lineups[Match.Team.RUST]) else ""])
	# Round 3: StarCraft-style desktop controls by default; round 2's tap grammar (squad bar, drill and formation
	# pickers) stays behind --touch-map until the lead playtests the new controls (control X6).
	if flags.has("touch-map") or flags.has("command-playtest"):
		_start_touch_map(field, rig, messages)
	else:
		_start_desktop_controls(field, rig, messages, orders)


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
	# L4 (control X1): the camera frames the element you are commanding and never zooms out past what the force
	# can collectively see (the lead: "a bird's eye view is just an unearned god view"). --no-vision-camera opts out.
	if not flags.has("no-vision-camera"):
		rig.vision = controls.vision_state
	controls.command_issued.connect(func(command: Dictionary, error: String) -> void:
		messages.order(controls.describe(command), error))
	if flags.has("control-playtest"):
		var playtest := ControlPlaytest.new()
		playtest.name = "ControlPlaytest"
		playtest.controls = controls
		playtest.radar = radar
		playtest.out_dir = flags.text("control-playtest")
		main.add_child(playtest)
		playtest.run()
	elif flags.has("scripted"):
		_play_desktop_script(controls)
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
