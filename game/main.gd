extends Node3D
## Entry point (run/main_scene). Decides this process's ROLE and wires the scene.
## The rules of play live in Match (game/match/match.gd); this file is plumbing.
##
## Flags come from the command line after a bare `--` (desktop, server), or from
## the URL query string in the browser (index.html?connect&demo):
##   (no role flag)             OFFLINE: your tank vs --bots (default 1), no networking
##   --server[=port]            SERVER: no local tank; one tank per connecting client
##   --connect[=ws://host:port] CLIENT: join a server. Default in the browser: /ws on the
##                              page's own address (tools/serve_web.py or the reverse proxy
##                              forwards it); on desktop: ws://127.0.0.1:9080
##   --bots=N                   server/offline: add N server-controlled BotController tanks
##   --demo                     scripted driver instead of keyboard/mouse
##   --agent-port=PORT          let an external agent (Claude) command your tank over
##                              http://127.0.0.1:PORT (_agents/agent_bridge.md); desktop only
##   --match                    MATCH RUNNER: bots only, no network; ends at a limit and prints
##                              MATCH_RESULT <json>. Run with Godot's --fixed-fps 60 to simulate
##                              faster than real time (`make match`). Options:
##                              --green=N --rust=N (BotControllers) or --green-doctrine=PATH
##                              --rust-doctrine=PATH (TankBrains from doctrines/*.json),
##                              --score-limit=K --time-limit=SECONDS --seed=S --elimination
##   --skirmish                 SKIRMISH: command your squads (doctrines/player_default.json) on the
##                              tactical map against a CPU doctrine (--enemy=NAME, default individuals).
##                              No server needed; works in the browser (?skirmish).
##   --screenshot=<abs path>    save a PNG after a few seconds, then quit (desktop)
##   --screenshot-delay=SECONDS how long to wait before that screenshot (default 3)
## An exported server binary (feature tag "server") is a SERVER unless told otherwise.
##
## Console markers. Smoke tests wait for these exact prefixes; rename with care:
##   TANK_SQUAD_READY  TANK_SQUAD_LISTENING  TANK_SQUAD_CONNECTED  TANK_SQUAD_SPAWNED

enum Role { OFFLINE, SERVER, CLIENT, MATCH, SKIRMISH }

const DEFAULT_PORT := 9080
const DEFAULT_OFFLINE_BOTS := 1
const SCREENSHOT_DELAY_SEC := 3.0

var role := Role.OFFLINE

var _flags := {}
var _status := ""
## PlayerController / ScriptedController / OrderController; null on a server.
var _controller: Node
var _local_tank: Tank

@onready var game_match: Match = $Match
@onready var camera: FollowCamera = $FollowCamera
@onready var status_label: Label = $HUD/Status
@onready var scoreboard: Label = $HUD/Scoreboard
@onready var banner: Label = $HUD/Banner


func _ready() -> void:
	_flags = _parse_flags(_raw_flags())
	if DisplayServer.get_name() == "headless" and not _flags.has("match"):
		# Nothing is drawn, so without a cap the main loop would spin a CPU core.
		# The match runner WANTS to spin: it simulates as fast as the CPU allows.
		Engine.max_fps = Engine.physics_ticks_per_second
	game_match.local_tank_spawned.connect(_attach_local_tank)

	if _flags.has("match"):
		_start_match()
	elif _flags.has("skirmish"):
		_start_skirmish()
	elif _flags.has("server") or (OS.has_feature("server") and not _flags.has("connect")):
		_start_server(_int_flag("server", DEFAULT_PORT))
	elif _flags.has("connect"):
		_start_client(_connect_url())
	else:
		_start_offline()

	if _flags.has("screenshot"):
		_capture_after(_flags["screenshot"], float(_flags.get("screenshot-delay", SCREENSHOT_DELAY_SEC)))
	print("TANK_SQUAD_READY role=%s flags=%s" % [Role.keys()[role], _flags])


func _process(_delta: float) -> void:
	status_label.text = "%s   |   tanks: %d" % [_status, game_match.tanks.get_child_count()]
	var line := "Green %d : %d Rust" % [game_match.score_green, game_match.score_rust]
	if game_match.elimination:
		line = "Green %d tanks  vs  %d tanks Rust" % [game_match.alive_count(Match.Team.GREEN), game_match.alive_count(Match.Team.RUST)]
	if _local_tank != null and is_instance_valid(_local_tank):
		var bars := int(round(_local_tank.reload_fraction() * 10.0))
		# ASCII on purpose: the default font has no block glyphs (they render as empty boxes).
		line += "      HP %d      Reload [%s]" % [_local_tank.sync_health,
				"#".repeat(bars) + "-".repeat(10 - bars)]
		banner.visible = not _local_tank.is_alive()
		banner.text = "Destroyed — respawning…"
	scoreboard.text = line


# ---- Roles ----------------------------------------------------------------------

func _start_offline() -> void:
	role = Role.OFFLINE
	_controller = _make_controller()
	_set_status("Offline")
	# The offline MultiplayerPeer is its own server, so the same spawn path works.
	game_match.add_player(multiplayer.get_unique_id())
	for i in _int_flag("bots", DEFAULT_OFFLINE_BOTS):
		game_match.add_bot()


func _start_match() -> void:
	role = Role.MATCH
	game_match.has_local_player = false
	Pathing.enabled = not _flags.has("no-navigation")
	Match.swap_bases = _flags.has("swap-bases")
	var seed_value := _int_flag("seed", 0)
	game_match.seed_spawns(seed_value, 6.0 if _flags.has("seed") else 0.0)
	# --rust-first flips spawn (and therefore per-tick processing) order: a fairness probe.
	var order := [Match.Team.RUST, Match.Team.GREEN] if _flags.has("rust-first") else [Match.Team.GREEN, Match.Team.RUST]
	for team in order:
		var key := "green" if team == Match.Team.GREEN else "rust"
		if _flags.has(key + "-doctrine"):
			var loaded := Doctrine.load_file(_flags[key + "-doctrine"])
			if loaded.has("error"):
				push_error(loaded["error"])
				get_tree().quit(2)
				return
			game_match.load_doctrine(team, loaded["doctrine"])
		else:
			for i in _int_flag(key, 1):
				game_match.add_bot(team)
	game_match.elimination = _flags.has("elimination")
	game_match.start_limits(0 if game_match.elimination else _int_flag("score-limit", 5), float(_int_flag("time-limit", 300)))
	var started_msec := Time.get_ticks_msec()
	game_match.finished.connect(func(result: Dictionary) -> void:
		var real_seconds := (Time.get_ticks_msec() - started_msec) / 1000.0
		result["seed"] = seed_value
		result["real_seconds"] = snappedf(real_seconds, 0.01)
		result["speedup"] = snappedf(result["sim_seconds"] / maxf(real_seconds, 0.001), 0.1)
		print("MATCH_RESULT " + JSON.stringify(result))
		get_tree().quit())
	_set_status("Match runner")
	# With a window (make watch-match), look down on the whole arena.
	camera.offset = Vector3(0.0, 105.0, 62.0)
	camera.global_position = camera.offset
	camera.look_at(Vector3.ZERO)


func _start_skirmish() -> void:
	role = Role.SKIRMISH
	game_match.has_local_player = false
	var lineups := {Match.Team.GREEN: _flags.get("player", "player_default"), Match.Team.RUST: _flags.get("enemy", "individuals")}
	for team in lineups:
		var loaded := Doctrine.load_file("res://doctrines/%s.json" % lineups[team])
		var error: String = loaded.get("error", "")
		if error == "":
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error(error)
			_set_status("Can't start skirmish: " + error)
			return
	game_match.elimination = true
	game_match.finished.connect(func(result: Dictionary) -> void:
		var green_alive := game_match.alive_count(Match.Team.GREEN)
		banner.text = "VICTORY" if green_alive > 0 else "DEFEAT"
		banner.visible = true)
	var tactical := TacticalMap.new()
	tactical.name = "TacticalMap"
	tactical.game_match = game_match
	tactical.camera = camera
	$HUD.add_child(tactical)
	_set_status("Skirmish vs %s" % lineups[Match.Team.RUST])
	# Start in a planning pause: give your squads orders first, then press Space.
	tactical.set_paused(true, "PLANNING: give orders, then press Space to begin")


func _start_server(port: int) -> void:
	role = Role.SERVER
	game_match.networked = true
	game_match.has_local_player = false
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("server: cannot listen on port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	# Clients may only talk to the server, never relay messages to each other.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(peer_id: int) -> void:
		var tank := game_match.add_player(peer_id)
		print("peer %d joined -> %s (team %s)" % [peer_id, tank.name, Match.TEAM_NAMES[tank.team]]))
	multiplayer.peer_disconnected.connect(func(peer_id: int) -> void:
		game_match.remove_player(peer_id)
		print("peer %d left" % peer_id))
	for i in _int_flag("bots", 0):
		game_match.add_bot()
	_set_status("Server on port %d" % port)
	print("TANK_SQUAD_LISTENING port=%d" % port)
	print("  (WebSocket only. Browsers: `make play`, or `make serve-web` and open http://localhost:8060/?connect)")


func _start_client(url: String) -> void:
	role = Role.CLIENT
	game_match.simulate = false
	game_match.networked = true
	_controller = _make_controller()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		_set_status("Cannot connect to %s: %s" % [url, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		_set_status("Connected to %s as peer %d" % [url, multiplayer.get_unique_id()])
		print("TANK_SQUAD_CONNECTED peer=%d" % multiplayer.get_unique_id()))
	multiplayer.connection_failed.connect(func() -> void:
		_set_status("Connection to %s failed" % url))
	multiplayer.server_disconnected.connect(func() -> void:
		_set_status("Disconnected from server")
		for tank in game_match.tanks.get_children():
			tank.queue_free())
	_set_status("Connecting to %s…" % url)


# ---- Local player --------------------------------------------------------------------

func _attach_local_tank(tank: Tank) -> void:
	_local_tank = tank
	_controller.set("tank", tank)
	# Green's base is south, Rust's is north: both teams see the enemy "up" the screen.
	camera.follow(tank, tank.team == Match.Team.RUST)
	print("TANK_SQUAD_SPAWNED peer=%d name=%s team=%s" % [multiplayer.get_unique_id(), tank.name,
			Match.TEAM_NAMES[tank.team]])


func _make_controller() -> Node:
	var controller: Node
	if _flags.has("agent-port") and not OS.has_feature("web"):
		var orders := OrderController.new()
		orders.tanks_root = game_match.tanks
		var bridge := AgentBridge.new()
		bridge.name = "AgentBridge"
		bridge.port = _int_flag("agent-port", AgentBridge.DEFAULT_PORT)
		bridge.orders = orders
		bridge.game_match = game_match
		bridge.arena = $Arena
		add_child(bridge)
		controller = orders
	elif _flags.has("demo"):
		controller = ScriptedController.new()
	else:
		controller = PlayerController.new()
	controller.name = "LocalController"
	add_child(controller)
	return controller


# ---- Flags & utilities -----------------------------------------------------------

func _raw_flags() -> PackedStringArray:
	var flags := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&", false):
			flags.append("--" + part.uri_decode())
	return flags


## ["--demo", "--server=9090"] -> {"demo": "", "server": "9090"}
func _parse_flags(flags: PackedStringArray) -> Dictionary:
	var parsed := {}
	for flag in flags:
		var parts := flag.trim_prefix("--").split("=", true, 1)
		parsed[parts[0]] = parts[1] if parts.size() > 1 else ""
	return parsed


func _int_flag(flag_name: String, default_value: int) -> int:
	var value: String = _flags.get(flag_name, "")
	return value.to_int() if value.is_valid_int() else default_value


func _connect_url() -> String:
	var url: String = _flags.get("connect", "")
	if not url.is_empty():
		return url
	if OS.has_feature("web"):
		# Same origin as the page: works on any host/port, and becomes wss:// under https.
		var secure := str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"
		return "%s://%s/ws" % ["wss" if secure else "ws", str(JavaScriptBridge.eval("window.location.host", true))]
	return "ws://127.0.0.1:%d" % DEFAULT_PORT


func _set_status(text: String) -> void:
	_status = text


func _capture_after(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err == OK:
		print("screenshot saved: ", path)
	else:
		push_error("screenshot failed (%s): %s" % [error_string(err), path])
	get_tree().quit(err)
