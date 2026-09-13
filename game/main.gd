extends Node3D
## Entry point (run/main_scene). Decides this process's ROLE and wires the scene.
##
## Flags come from the command line after a bare `--` (desktop, server), or from
## the URL query string in the browser (index.html?connect&demo):
##   (no role flag)             OFFLINE: one local tank, no networking
##   --server[=port]            SERVER: no local tank; one tank per connecting client
##   --connect[=ws://host:port] CLIENT: join a server (default ws://<page host>:9080)
##   --demo                     scripted driver instead of keyboard/mouse
##   --screenshot=<abs path>    save a PNG after a few seconds, then quit (desktop)
## An exported server binary (feature tag "server") is a SERVER unless told otherwise.
##
## Console markers. Smoke tests wait for these exact prefixes; rename with care:
##   TANK_SQUAD_READY  TANK_SQUAD_LISTENING  TANK_SQUAD_CONNECTED  TANK_SQUAD_SPAWNED

enum Role { OFFLINE, SERVER, CLIENT }

const DEFAULT_PORT := 9080
const SCREENSHOT_DELAY_SEC := 3.0
const TANK_SCENE := preload("res://game/tank/tank.tscn")
const SPAWN_RADIUS := 10.0
const SPAWN_SLOTS := 8
## Until M3 adds teams: your tank keeps the scene's green, everyone else is rust.
const OTHER_PLAYER_COLOR := Color(0.55, 0.27, 0.2)

var role := Role.OFFLINE

var _flags := {}
var _status := ""
var _next_spawn_slot := 0
## PlayerController or ScriptedController; null on a server.
var _controller: Node

@onready var tanks: Node3D = $Tanks
@onready var spawner: MultiplayerSpawner = $TankSpawner
@onready var camera: FollowCamera = $FollowCamera
@onready var status_label: Label = $HUD/Status


func _ready() -> void:
	_flags = _parse_flags(_raw_flags())
	if DisplayServer.get_name() == "headless":
		# Nothing is drawn, so without a cap the main loop would spin a CPU core.
		Engine.max_fps = Engine.physics_ticks_per_second
	# Every peer must know how to build a tank BEFORE the server's spawn messages arrive.
	spawner.spawn_function = _spawn_tank

	if _flags.has("server") or (OS.has_feature("server") and not _flags.has("connect")):
		_start_server(_flags.get("server", "").to_int() if _flags.get("server", "") != "" else DEFAULT_PORT)
	elif _flags.has("connect"):
		_start_client(_connect_url())
	else:
		_start_offline()

	if _flags.has("screenshot"):
		_capture_after(_flags["screenshot"], SCREENSHOT_DELAY_SEC)
	print("TANK_SQUAD_READY role=%s flags=%s" % [Role.keys()[role], _flags])


func _process(_delta: float) -> void:
	status_label.text = "%s   |   tanks: %d" % [_status, tanks.get_child_count()]


# ---- Roles ----------------------------------------------------------------------

func _start_offline() -> void:
	role = Role.OFFLINE
	_controller = _make_controller()
	_set_status("Offline")
	# The offline MultiplayerPeer is its own server, so the same spawn path works.
	spawner.spawn({"peer_id": multiplayer.get_unique_id(), "position": Vector3.ZERO, "yaw": 0.0})


func _start_server(port: int) -> void:
	role = Role.SERVER
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("server: cannot listen on port %d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	# Clients may only talk to the server, never relay messages to each other.
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_set_status("Server on port %d" % port)
	print("TANK_SQUAD_LISTENING port=%d" % port)


func _start_client(url: String) -> void:
	role = Role.CLIENT
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
		for tank in tanks.get_children():
			tank.queue_free())
	_set_status("Connecting to %s…" % url)


# ---- Server: players come and go -------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	var angle := TAU * float(_next_spawn_slot % SPAWN_SLOTS) / SPAWN_SLOTS
	_next_spawn_slot += 1
	var spawn_position := Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RADIUS
	# Face the arena center: yaw toward the vector from the spawn point back to the origin.
	var yaw := TankMotion.yaw_toward(-spawn_position)
	spawner.spawn({"peer_id": peer_id, "position": spawn_position, "yaw": yaw})
	print("peer %d joined -> Tank_%d" % [peer_id, peer_id])


func _on_peer_disconnected(peer_id: int) -> void:
	var tank := tanks.get_node_or_null("Tank_%d" % peer_id)
	if tank != null:
		tank.queue_free()  # the spawner removes it on every client too
	print("peer %d left" % peer_id)


# ---- Spawning (runs on EVERY peer with identical data) ----------------------------

func _spawn_tank(data: Dictionary) -> Node:
	var peer_id: int = data["peer_id"]
	var tank: Tank = TANK_SCENE.instantiate()
	tank.name = "Tank_%d" % peer_id
	tank.position = data["position"]
	tank.rotation.y = data["yaw"]
	tank.simulate = role != Role.CLIENT
	if role != Role.OFFLINE:
		var input := NetworkInput.new()
		input.name = "NetworkInput"
		input.tank = tank
		input.owner_peer_id = peer_id
		tank.add_child(input)
	if role != Role.SERVER:
		if peer_id == multiplayer.get_unique_id():
			_attach_local_tank.call_deferred(tank)
		else:
			tank.set_paint.call_deferred(OTHER_PLAYER_COLOR)  # needs its child meshes ready
	return tank


func _attach_local_tank(tank: Tank) -> void:
	_controller.set("tank", tank)
	camera.follow(tank)
	print("TANK_SQUAD_SPAWNED peer=%d" % multiplayer.get_unique_id())


func _make_controller() -> Node:
	var controller: Node = ScriptedController.new() if _flags.has("demo") else PlayerController.new()
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
