extends Node3D
## Entry point (run/main_scene). Decides this process's ROLE and wires the scene.
## The rules of play live in Match (game/match/match.gd); this file is plumbing.
##
## Flags come from the command line after a bare `--` (desktop, server), or from
## the URL query string in the browser (index.html?connect&demo):
##   (no role flag)             OFFLINE: your tank vs --bots (default 1), no networking
##   --server[=port]            SERVER: no local tank; one tank per connecting client
##   --connect[=ws://host:port] CLIENT: join a server (default ws://<page host>:9080)
##   --bots=N                   server/offline: add N server-controlled BotController tanks
##   --demo                     scripted driver instead of keyboard/mouse
##   --agent-port=PORT          let an external agent (Claude) command your tank over
##                              http://127.0.0.1:PORT (_agents/agent_bridge.md); desktop only
##   --screenshot=<abs path>    save a PNG after a few seconds, then quit (desktop)
##   --screenshot-delay=SECONDS how long to wait before that screenshot (default 3)
## An exported server binary (feature tag "server") is a SERVER unless told otherwise.
##
## Console markers. Smoke tests wait for these exact prefixes; rename with care:
##   TANK_SQUAD_READY  TANK_SQUAD_LISTENING  TANK_SQUAD_CONNECTED  TANK_SQUAD_SPAWNED

enum Role { OFFLINE, SERVER, CLIENT }

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
	if DisplayServer.get_name() == "headless":
		# Nothing is drawn, so without a cap the main loop would spin a CPU core.
		Engine.max_fps = Engine.physics_ticks_per_second
	game_match.local_tank_spawned.connect(_attach_local_tank)

	if _flags.has("server") or (OS.has_feature("server") and not _flags.has("connect")):
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
	if _local_tank != null and is_instance_valid(_local_tank):
		var bars := int(round(_local_tank.reload_fraction() * 10.0))
		# ASCII on purpose: the default font has no block glyphs (they render as empty boxes).
		line += "      HP %d      Reload [%s]" % [_local_tank.sync_health,
				"#".repeat(bars) + "-".repeat(10 - bars)]
		banner.visible = not _local_tank.is_alive()
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
	var host := "127.0.0.1"
	if OS.has_feature("web"):
		host = str(JavaScriptBridge.eval("window.location.hostname", true))
	return "ws://%s:%d" % [host, DEFAULT_PORT]


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
