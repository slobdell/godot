class_name ShaderWarmup
extends Node
## Round 18 (finale E3): every material in the arena drawn once, at load, the way the battle will first draw it, so its
## shaders compile behind the loading screen instead of in the middle of a fight. Measured by removal on his laptop
## (UHD 620, cold shader cache, sumps seed 1, `make end-trace`): two first uses held ~88 % of the mid-match draw stalls —
## the arena screens' LIVE FEED (its slots render the shared world under a copy of the environment WITHOUT glow, and in
## the Compatibility renderer that is another specialisation of every scene shader) and the POOLED LIGHTS (omni lights
## are another variant of every material they touch). The existing FxWorld._prewarm draws the effects; this draws the
## world.
##
## How, for TWO frames: every visible GeometryInstance3D gets a huge `extra_cull_margin` and no visibility range, so
## frustum AND light culling treat it as on screen, and one live-feed slot renders from the main camera's pose. Frame 1
## is UNLIT (the pool is switched off: with every margin widened even the prewarm's 0.5 m lights would touch everything),
## frame 2 is LIT (every pooled light requested at the camera with a range that reaches everything, energy near zero),
## because lit and unlit are two specialisations and the fight uses both (measured: a warm-up that lit everything left
## the feed's unlit variant to compile at its first recording, 1.9 s cold). The third frame puts every margin, range and
## the pool back. The picture after it is exactly the picture without it (no setting stays changed); the frames it costs
## are load time, measured and stated (E3). `--no-shader-warmup` turns it off (the E3 before/after arm); it marks
## `warmup` in a FrameTrace with what it touched.

const MARGIN := 16384.0
const LIGHT_RANGE := 4096.0
const LIGHT_PRIORITY := 1.0e6
## The scene assembles over the first frames after the match attaches (the live feed's slots enter after it): wait for a
## feed with slots, or this many frames where there is none (the low tier builds no slots).
const WAIT_FRAMES_MAX := 30

var enabled := not LaunchFlags.from_environment().has("no-shader-warmup")
## Stretch (b), pricing the warm-up by removal: `--shader-warmup-parts=unlit,lit,feed` (default all three). A part left
## out is skipped: no unlit frame (the pool stays as it was), no lit frame, or no live-feed render in either frame.
var parts: PackedStringArray = LaunchFlags.from_environment().text("shader-warmup-parts", "unlit,lit,feed").split(",", false)
var done := false
## What the last warm-up touched (the arm assertion): instances, lights, feed slots.
var touched := {"instances": 0, "lights": 0, "feed_slots": 0}

var _fx: FxWorld
var _saved: Array = []  # [GeometryInstance3D, extra_cull_margin, visibility_range_begin, visibility_range_end]
## -1 waiting, 0 the unlit frame was set up, 1 the lit frame was set up.
var _phase := -1
var _waited := 0
var _camera: Camera3D
var _pool_was_enabled := true
var _match: Node


func _init(fx: FxWorld = null) -> void:
	name = "ShaderWarmup"
	_fx = fx
	process_mode = Node.PROCESS_MODE_ALWAYS


## FxWorld calls this every frame before its systems update; the warm-up starts once a match and a camera exist, and
## again for every NEW match (a rematch or the next fight may be another arena, with other materials).
func step(camera: Camera3D, game_match: Node) -> void:
	if game_match != null and game_match != _match:
		_match = game_match
		if done or _phase >= 0:
			_restore()
		done = false
		_phase = -1
		_waited = 0
	if not enabled or done or camera == null or _match == null:
		return
	match _phase:
		-1:
			_waited += 1
			if not _feed_ready() and _waited < WAIT_FRAMES_MAX:
				return
			begin(camera)
		0:
			_phase = 1
			if _fx != null:
				_fx.lights.enabled = _pool_was_enabled
			if parts.has("lit"):
				_light_everything(camera)
				_render_feed(camera)
			else:
				finish()
		_:
			finish()


## Whether FxWorld's effect prewarm should stay on: from the start until this warm-up's lit frame has been drawn (the
## effects must be in both of its frames, and in the feed's).
func holding() -> bool:
	return enabled and not done and _match != null


func _feed_ready() -> bool:
	for feed in get_tree().root.find_children("*", "LiveFeed", true, false):
		if not (feed.get("slots") as Array).is_empty():
			return true
	return false


## Widen every visible instance and render one feed slot, unlit (this frame).
func begin(camera: Camera3D) -> void:
	var started := Time.get_ticks_usec()
	_phase = 0
	var root := get_tree().root
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree():
			continue
		_saved.append([geometry, geometry.extra_cull_margin, geometry.visibility_range_begin, geometry.visibility_range_end])
		geometry.extra_cull_margin = MARGIN
		geometry.visibility_range_begin = 0.0
		geometry.visibility_range_end = 0.0
	touched["instances"] = _saved.size()
	if _fx != null:
		_pool_was_enabled = _fx.lights.enabled
		_fx.lights.enabled = not parts.has("unlit")  # the unlit frame needs the pool off; without it, frame 1 is lit too
	touched["feed_slots"] = _render_feed(camera)
	print("SHADER_WARMUP begin frames_waited=%d instances=%d lights=%d feed_slots=%d setup_ms=%.1f" % [_waited,
			touched["instances"], touched["lights"], touched["feed_slots"], (Time.get_ticks_usec() - started) / 1000.0])
	FrameTrace.mark_now("warmup", JSON.stringify(touched))


## One slot of every live feed renders this frame from the main camera's pose. Slot 0 is not shown until the feed
## records into it (`ring.recorded == 0` until then), so a warm-up frame never reaches a screen. Returns the slots.
func _render_feed(camera: Camera3D) -> int:
	var count := 0
	if not parts.has("feed"):
		return 0
	for feed in get_tree().root.find_children("*", "LiveFeed", true, false):
		var slots: Array = feed.get("slots")
		var cameras: Array = feed.get("cameras")
		if slots.is_empty() or cameras.is_empty() or not bool(feed.get("enabled")):
			continue
		(cameras[0] as Camera3D).global_transform = camera.global_transform
		(slots[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		count += 1
	return count


func _light_everything(camera: Camera3D) -> int:
	if _fx == null:
		return 0
	var spot := camera.global_transform * Vector3(0, 0, -10)
	for i in _fx.lights.lights.size():
		# Above every other request (the prewarm asks at 100 for lights 0.5 m wide, nearer the camera, and won the tie).
		_fx.lights.request(spot, Color(0, 0, 0), 0.001, LIGHT_RANGE, LIGHT_PRIORITY)
	return _fx.lights.lights.size() if _fx.lights.enabled else 0


## Put every margin, range and the pool back; the warm-up for this match is done.
func finish() -> void:
	# The arm assertion, read from what the pool CONSULTED last frame: lights lit at the warm-up's range.
	if _fx != null:
		var wide := 0
		for light in _fx.lights.lights:
			if light.visible and light.omni_range >= LIGHT_RANGE:
				wide += 1
		touched["lights"] = wide
	_restore()
	done = true
	_phase = -1
	print("SHADER_WARMUP done lights_lit_wide=%d" % touched["lights"])


func _restore() -> void:
	for entry: Array in _saved:
		# Untyped until checked: a shell's visual freed during the warm-up is a freed instance, and assigning one to a typed
		# variable is a script error before is_instance_valid can say so.
		var node: Variant = entry[0]
		if is_instance_valid(node):
			var geometry := node as GeometryInstance3D
			geometry.extra_cull_margin = float(entry[1])
			geometry.visibility_range_begin = float(entry[2])
			geometry.visibility_range_end = float(entry[3])
	if not _saved.is_empty() and _fx != null:
		_fx.lights.enabled = _pool_was_enabled
	_saved.clear()


func _exit_tree() -> void:
	_restore()
