class_name FrameTarget
extends RefCounted
## The frame-rate target (render, round 5; the lead's sign-off): **a locked 30 fps at 1080p with 30 a side** by default,
## and a **60 fps performance option** that renders ~720 lines of 3D. The numbers behind it: `make perf-scene` on the
## lead's UHD 620 (render.md, "What 30 Hz can and can't fix"). Locked means capped: Engine.max_fps holds the frame to
## the target so its pacing is even, rather than running free and dipping.
##
## Which target: `--frame-target=30|60` (URL `?frame-target=60`) > the player's saved choice (`user://frame_target.cfg`,
## set with `apply(target, "player", true)`: control's menu) > the platform default (desktop: locked 30). Browsers pace
## frames to the display themselves, so the web gets no cap, only the 3D resolution ceiling.

enum Target { LOCKED_30, PERFORMANCE_60 }

const NAMES := {Target.LOCKED_30: "30", Target.PERFORMANCE_60: "60"}
const LABELS := {Target.LOCKED_30: "QUALITY 30", Target.PERFORMANCE_60: "PERFORMANCE 60"}
const SAVE_PATH := "user://frame_target.cfg"
## Per target: the frame cap, and the most lines of 3D it renders (the UI stays at full resolution), never below the
## minimum scale.
const SETTINGS := {
	Target.LOCKED_30: {"fps": 30, "max_3d_lines": 1080.0, "min_scale": 0.7},
	Target.PERFORMANCE_60: {"fps": 60, "max_3d_lines": 720.0, "min_scale": 0.5},
}

static var _target := -1
## "flag", "saved", "platform", "player", or "code".
static var source := ""


static func target() -> int:
	if _target < 0:
		_resolve()
	return _target


static func value(key: String) -> Variant:
	return SETTINGS[target()][key]


static func label() -> String:
	return LABELS[target()]


static func parse(text: String) -> int:
	match text.to_lower():
		"30", "locked", "quality", "locked_30":
			return Target.LOCKED_30
		"60", "performance", "performance_60":
			return Target.PERFORMANCE_60
	return -1


static func platform_default() -> int:
	return Target.LOCKED_30


## The 3D render scale for `which` target in a window `window_height` pixels tall, never above the quality tier's own
## scale. Pure.
static func render_scale_for(which: int, tier_scale: float, window_height: int) -> float:
	if window_height <= 0:
		return tier_scale
	var settings: Dictionary = SETTINGS[which]
	var fit := clampf(float(settings["max_3d_lines"]) / float(window_height), float(settings["min_scale"]), 1.0)
	return minf(tier_scale, fit)


static func set_target(new_target: int, from := "code") -> void:
	_target = clampi(new_target, Target.LOCKED_30, Target.PERFORMANCE_60)
	source = from


## Switch targets at runtime: cap the frame rate and push the 3D resolution into the live viewport. `persist` saves it as
## the player's choice for this device.
static func apply(new_target: int, from := "player", persist := false) -> void:
	set_target(new_target, from)
	if persist:
		var config := ConfigFile.new()
		config.set_value("frame", "target", NAMES[_target])
		config.save(SAVE_PATH)
	apply_frame_cap()
	var fx := FxWorld.existing()
	if fx != null:
		fx.apply_quality()
	print("FRAME_TARGET %s (%s)" % [NAMES[_target], from])


## Cap the frame rate to the target (desktop, rendering peers only; headless and the browser pace themselves).
static func apply_frame_cap() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	Engine.max_fps = int(value("fps"))


static func _resolve() -> void:
	var requested := parse(LaunchFlags.from_environment().text("frame-target"))
	if requested >= 0:
		set_target(requested, "flag")
		return
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var saved := parse(str(config.get_value("frame", "target", "")))
		if saved >= 0:
			set_target(saved, "saved")
			return
	set_target(platform_default(), "platform")
