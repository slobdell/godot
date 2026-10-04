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
##
## Bounded in real time where the ticks do NOT keep up (the browser at 15 fps measured ~8-10 s of slow motion, his
## loaded laptop ~5 s): the schedule's progress is the LARGER of the ticks elapsed and the unscaled wall time divided by
## WALL_STRETCH, so at >= 1/WALL_STRETCH of real speed the ticks lead and the schedule is exactly the tick one
## (deterministic), and below it the wall clock eases it out by HOLD+RAMP x WALL_STRETCH real seconds (3 s). Under
## `--fixed-fps` the wall term is off (`wall_cap`): game time is decoupled from wall time there by definition, so every
## witness / determinism run is the pure tick schedule. A capped real-time run is presentation after a decided match.

const SLOW := 0.2
const SOUND_SLOW := 0.55
## Seconds at full slow motion, then easing back, counted in simulation ticks (HOLD_TICKS, RAMP_TICKS).
const HOLD_SECONDS := 1.4
const RAMP_SECONDS := 0.6
const HOLD_TICKS := 42  # SimClock.ticks(HOLD_SECONDS) at 30 Hz (a test keeps them in step)
const RAMP_TICKS := 18
## The real-time bound: the slow motion never outlasts (HOLD + RAMP) x this in unscaled wall seconds.
const WALL_STRETCH := 1.5
## The final kill must have happened this recently (s of FxWorld's clock) to count.
const RECENT_SECONDS := 1.5

var active := false
var enabled := true
var focus := Vector3.ZERO

var _fx: FxWorld
var _ticks := 0
## False under --fixed-fps (and settable by tests): the pure tick schedule.
var wall_cap := not OS.get_cmdline_args().has("--fixed-fps")
var _wall_s := 0.0
var _wall_usec := 0
var _match: Node
var _started_tick := -1
var _started_msec := 0


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
	_wall_s = 0.0
	_wall_usec = Time.get_ticks_usec()
	_match = game_match
	_started_tick = _match_tick()
	_started_msec = Time.get_ticks_msec()
	print("KILL_CAM start tick=%d ms=%d wall_cap=%s" % [_started_tick, _started_msec, wall_cap])
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


## The real-time bound (off under --fixed-fps): unscaled wall time, read every rendered frame.
func _process(_delta: float) -> void:
	if not active or not wall_cap:
		return
	var now := Time.get_ticks_usec()
	advance_wall(float(now - _wall_usec) / 1_000_000.0)
	_wall_usec = now


## Move the kill-cam on by `count` simulation ticks.
func advance_ticks(count: int) -> void:
	if not active:
		return
	_ticks += count
	_apply("ticks")


## Move the real-time bound on by `seconds` of unscaled wall time (nothing unless `wall_cap`).
func advance_wall(seconds: float) -> void:
	if not active or not wall_cap:
		return
	_wall_s += seconds
	_apply("wall")


func _apply(by: String) -> void:
	var progress := float(_ticks)
	if wall_cap:
		progress = maxf(progress, _wall_s / WALL_STRETCH * SimClock.TICK_RATE)
	var back := clampf((progress - HOLD_TICKS) / RAMP_TICKS, 0.0, 1.0)
	var eased := back * back * (3.0 - 2.0 * back)
	Engine.time_scale = lerpf(SLOW, 1.0, eased)
	AudioServer.playback_speed_scale = lerpf(SOUND_SLOW, 1.0, eased)
	if back >= 1.0:
		print("KILL_CAM end tick=%d ticks=%d ms=%d by=%s" % [_match_tick(), _ticks, Time.get_ticks_msec() - _started_msec, by])
		_restore()


func _match_tick() -> int:
	return int(_match.get("tick")) if _match != null and is_instance_valid(_match) else -1


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
