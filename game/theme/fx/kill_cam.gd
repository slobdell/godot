class_name KillCam
extends Node
## The slow-motion kill-cam (feel stretch): when an elimination match ends on a kill, time slows to a crawl for a moment,
## the sound drops with it, the camera centers on the final kill, and then everything eases back to full speed.
## Presentation only: it starts after Match.finished (the result is already decided), never on a networked match (every
## peer shares the host's clock), and it counts its own time in real seconds so it can always give time back.
## `--no-kill-cam` turns it off.

const SLOW := 0.2
const SOUND_SLOW := 0.55
## Real seconds at full slow motion, then easing back.
const HOLD_SECONDS := 1.4
const RAMP_SECONDS := 0.6
## The final kill must have happened this recently (s of FxWorld's clock) to count.
const RECENT_SECONDS := 1.5

var active := false
var enabled := true
var focus := Vector3.ZERO

var _fx: FxWorld
var _elapsed := 0.0
var _last_ticks := 0


func _init(fx: FxWorld = null) -> void:
	name = "KillCam"
	_fx = fx
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not LaunchFlags.from_environment().has("no-kill-cam")


## Match.finished (connected by MatchFxLink).
func on_finished(result: Dictionary, game_match: Node) -> void:
	if not enabled or active or _fx == null or String(result.get("reason", "")) != "elimination":
		return
	if game_match != null and bool(game_match.get("networked")):
		return
	var kill := _fx.weapons.last_kill()
	if kill.is_empty() or _fx.now - float(kill["time"]) > RECENT_SECONDS:
		return
	active = true
	focus = kill["position"]
	_elapsed = 0.0
	_last_ticks = Time.get_ticks_usec()
	Engine.time_scale = SLOW
	AudioServer.playback_speed_scale = SOUND_SLOW
	_fx.shake.add(0.35, focus, 40.0)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var node: Node = camera
	while node != null:
		if node.has_method("focus_on"):
			node.call("focus_on", focus)
			break
		node = node.get_parent()


func _process(_delta: float) -> void:
	if not active:
		return
	var ticks := Time.get_ticks_usec()
	advance(float(ticks - _last_ticks) / 1_000_000.0)
	_last_ticks = ticks


## Move the kill-cam on by `real_seconds` of wall time (not scaled by the slow motion it causes).
func advance(real_seconds: float) -> void:
	if not active:
		return
	_elapsed += real_seconds
	var back := clampf((_elapsed - HOLD_SECONDS) / RAMP_SECONDS, 0.0, 1.0)
	var eased := back * back * (3.0 - 2.0 * back)
	Engine.time_scale = lerpf(SLOW, 1.0, eased)
	AudioServer.playback_speed_scale = lerpf(SOUND_SLOW, 1.0, eased)
	if back >= 1.0:
		_restore()


func _restore() -> void:
	active = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


func _exit_tree() -> void:
	if active:
		_restore()
