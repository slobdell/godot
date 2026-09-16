class_name Main
extends Node3D
## Entry point (run/main_scene). Parses launch flags, picks a GameMode (game/modes/),
## and provides the shared pieces modes use. The rules of play live in Match; each way
## of running the game lives in its own mode file.
##
## Flags (command line after `--`, or the browser URL query ?a&b=c):
##   (none)                     OfflineMode: your tank vs --bots (default 1)
##   --skirmish                 SkirmishMode: command squads on the tactical map (--player, --enemy)
##   --garage                   GarageMode: build an army on a budget, then FIGHT a skirmish with it (--enemy)
##   --match                    MatchRunnerMode: headless bots vs bots → MATCH_RESULT json
##   --server[=port]            ServerMode: authoritative WebSocket server (--bots=N)
##   --connect[=ws://host:port] ClientMode: join a server (browser default: /ws on the page's host)
##   --lobby                    LobbyMode: touch-first HOST / JOIN-by-code screen (browser ?lobby)
##   --host [--relay=ws://...]  HostMode: YOU host through the broker's relay (browser default: /relay)
##   --join=CODE [--relay=...]  ClientMode: join a player-hosted room by its code
##   --demo                     scripted driver instead of keyboard/mouse (offline/client)
##   --agent-port=PORT          Claude commands your tank over localhost HTTP (_agents/agent_bridge.md)
##   --screenshot=<abs path>    save a PNG after --screenshot-delay seconds (default 3), then quit
##   --announcer=text|voice     the arena announcer calls the match (subtitles; voice once clips exist); --announcer-record=PATH
##   --music=on                 the dynamic soundtrack follows the match mood; --music-volume=DB, --music-dir=PATH
## An exported server binary (feature tag "server") is a server unless told otherwise.
##
## Console markers. Smoke tests wait for these exact prefixes; rename with care:
##   TANK_SQUAD_READY  TANK_SQUAD_LISTENING  TANK_SQUAD_CONNECTED  TANK_SQUAD_SPAWNED  TANK_SQUAD_ROOM

const SCREENSHOT_DELAY_SEC := 3.0

var flags: LaunchFlags
var mode: GameMode
## Set before reloading the scene to restart with these flags instead of the command line / URL (the army
## stream's rematch loop, game/garage/army_loop.gd). Used once, then cleared.
static var next_flags: LaunchFlags
## PlayerController / ScriptedController / OrderController; null when nobody drives locally.
var local_controller: Node

@onready var game_match: Match = $Match
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: Hud = $HUD
@onready var arena: Node3D = $Arena


func _ready() -> void:
	flags = next_flags if next_flags != null else LaunchFlags.from_environment()
	next_flags = null
	mode = GameMode.choose(flags)
	mode.main = self
	mode.flags = flags
	if DisplayServer.get_name() == "headless" and mode.caps_headless_fps():
		# Nothing is drawn, so without a cap the main loop would spin a CPU core.
		Engine.max_fps = Engine.physics_ticks_per_second
	hud.game_match = game_match
	game_match.local_tank_spawned.connect(_attach_local_tank)
	mode.start()
	# The arena announcer only listens to the match (--announcer=text|voice, --announcer-record=PATH; announcer_booth.gd).
	# The music follows the mood the booth keeps (--music=on, --music-volume=DB; game/audio/music_director.gd).
	MusicDirector.attach(self, AnnouncerBooth.attach(self))
	if flags.has("screenshot"):
		_capture_after(flags.text("screenshot"), float(flags.text("screenshot-delay", str(SCREENSHOT_DELAY_SEC))))
	print("TANK_SQUAD_READY role=%s flags=%s" % [mode.role_name(), flags.values])


## For modes where someone drives a tank from this process.
func create_local_controller() -> Node:
	if flags.has("agent-port") and not OS.has_feature("web"):
		var orders := OrderController.new()
		orders.tanks_root = game_match.tanks
		var bridge := AgentBridge.new()
		bridge.name = "AgentBridge"
		bridge.port = flags.integer("agent-port", AgentBridge.DEFAULT_PORT)
		bridge.orders = orders
		bridge.game_match = game_match
		bridge.arena = arena
		add_child(bridge)
		local_controller = orders
	elif flags.has("demo"):
		local_controller = ScriptedController.new()
	else:
		local_controller = PlayerController.new()
	local_controller.name = "LocalController"
	add_child(local_controller)
	return local_controller


func _attach_local_tank(tank: Tank) -> void:
	hud.local_tank = tank
	if local_controller != null:
		local_controller.set("tank", tank)
	# Green's base is south, Rust's is north: both teams see the enemy "up" the screen.
	camera.follow(tank, tank.team == Match.Team.RUST)
	print("TANK_SQUAD_SPAWNED peer=%d name=%s team=%s" % [multiplayer.get_unique_id(), tank.name,
			Match.TEAM_NAMES[tank.team]])


func _capture_after(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err == OK:
		print("screenshot saved: ", path)
	else:
		push_error("screenshot failed (%s): %s" % [error_string(err), path])
	get_tree().quit(err)
