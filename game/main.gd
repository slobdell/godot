extends Node3D
## Entry point (run/main_scene). Wires the scene for the requested mode.
##
## Flags come from the command line after a bare `--` (desktop), or from the URL
## query string in the browser (index.html?demo):
##   --demo                     scripted driver instead of keyboard/mouse
##   --screenshot=<abs path>    save a PNG after a few seconds, then quit (desktop)
##
## Milestone 2 adds --server / --connect=<url> here.

## Printed once the scene is wired. tools/web_smoke waits for this exact string.
const READY_MARKER := "TANK_SQUAD_READY"
const SCREENSHOT_DELAY_SEC := 3.0

@onready var tank: Tank = $Tank
@onready var player_controller: PlayerController = $PlayerController


func _ready() -> void:
	var args := _parse_flags(_raw_flags())
	if args.has("demo"):
		_use_scripted_controller()
	if args.has("screenshot"):
		_capture_after(args["screenshot"], SCREENSHOT_DELAY_SEC)
	print("%s flags=%s" % [READY_MARKER, args])


func _raw_flags() -> PackedStringArray:
	var flags := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&", false):
			flags.append("--" + part.uri_decode())
	return flags


## ["--demo", "--screenshot=/tmp/x.png"] -> {"demo": "", "screenshot": "/tmp/x.png"}
func _parse_flags(flags: PackedStringArray) -> Dictionary:
	var parsed := {}
	for flag in flags:
		var parts := flag.trim_prefix("--").split("=", true, 1)
		parsed[parts[0]] = parts[1] if parts.size() > 1 else ""
	return parsed


func _use_scripted_controller() -> void:
	player_controller.queue_free()
	var scripted := ScriptedController.new()
	scripted.name = "ScriptedController"
	scripted.tank = tank
	add_child(scripted)


func _capture_after(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	if err == OK:
		print("screenshot saved: ", path)
	else:
		push_error("screenshot failed (%s): %s" % [error_string(err), path])
	get_tree().quit(err)
