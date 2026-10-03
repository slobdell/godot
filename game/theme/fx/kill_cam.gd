class_name KillCam
extends Node
## The slow-motion kill-cam (feel stretch): when an elimination match ends on a kill, time slows to a crawl for a moment,
## the sound drops with it, the camera centers on the final kill, and then everything eases back to full speed.
## Presentation only: it starts after Match.finished (the result is already decided), never on a networked match (every
## peer shares the host's clock), and it counts its own time in real seconds so it can always give time back.
## `--no-kill-cam` turns it off.
##
## Round 17 (sim F4): it counts SIMULATION TICKS, not wall-clock seconds. `Engine.time_scale` is not presentation:
## Godot hands every `_physics_process` `physics_step * time_scale`, and the simulation keeps ticking after `finished`
## (the survivors drive on), so the slow-motion schedule IS simulation input. Counted in wall time, how many ticks ran
## slowed (and at which ramp values) depended on how fast the frames came: the same windowed seed was two fights from the
## end of the match on (the Sumps "fork at 601-630", rounds 16-17; headless has no kill-cam, so it never forked). Ticks
## arrive at TICK_RATE a second whatever the time scale (Godot scales the step, not the rate), so a tick is still a
## real 1/30 s whenever the game keeps up, and time is always given back.

const SLOW := 0.2
const SOUND_SLOW := 0.55
## Seconds at full slow motion, then easing back, counted in simulation ticks (HOLD_TICKS, RAMP_TICKS).
const HOLD_SECONDS := 1.4
const RAMP_SECONDS := 0.6
const HOLD_TICKS := 42  # SimClock.ticks(HOLD_SECONDS) at 30 Hz (a test keeps them in step)
const RAMP_TICKS := 18
## The final kill must have happened this recently (s of FxWorld's clock) to count.
const RECENT_SECONDS := 1.5

var active := false
var enabled := true
var focus := Vector3.ZERO

var _fx: FxWorld
var _ticks := 0


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
	_ticks = 0
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


## One simulation tick (PROCESS_MODE_ALWAYS, so a paused tree cannot strand the slow motion).
func _physics_process(_delta: float) -> void:
	if active:
		advance_ticks(1)


## Move the kill-cam on by `count` simulation ticks.
func advance_ticks(count: int) -> void:
	if not active:
		return
	_ticks += count
	var back := clampf(float(_ticks - HOLD_TICKS) / RAMP_TICKS, 0.0, 1.0)
	var eased := back * back * (3.0 - 2.0 * back)
	Engine.time_scale = lerpf(SLOW, 1.0, eased)
	AudioServer.playback_speed_scale = lerpf(SOUND_SLOW, 1.0, eased)
	if back >= 1.0:
		_restore()


## Move the kill-cam on by `seconds` (whole ticks of them).
func advance(seconds: float) -> void:
	advance_ticks(ceili(seconds * SimClock.TICK_RATE))


func _restore() -> void:
	active = false
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0


func _exit_tree() -> void:
	if active:
		_restore()
