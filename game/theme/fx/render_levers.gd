class_name RenderLevers
extends RefCounted
## The priced levers (render, round 16, R8) and the two presets the lead chose from them (R9). A lever buys GPU time by
## CHANGING THE PICTURE (contract C16.1): none is on unless a preset or the command line names it.
##
##   scale_085 / scale_075  the 3D picture rendered at 85 % / 75 % of the window's lines, scaled up (UI stays sharp)
##   lights_2               two pooled lights instead of four (explosions light fewer things at once)
##   no_haze                no heat haze over burning wrecks
##   no_env_fog             no depth/height fog in the arena
##   crowd_medium           the medium tier's crowd (3 600 figures, not all 7 700 seats)
##   unlit_stands           the stands drawn flat-lit (no moonlight shading on the kit)
##
## The presets (the lead's taps on the levers page, 2026-10-03, game_design.md "Round 16: the render levers, decided on
## the page"; his words: "We should still have the option to keep scale at 1.0 on better gaming setups"):
##   laptop   his five taps: scale_075, lights_2, no_env_fog, no_haze, crowd_medium   (~5.9 ms GPU at his window, UHD 620)
##   desktop  none: full resolution, fog, haze, four pooled lights, the full crowd
## `unlit_stands` (tapped OFF) and `scale_085` (untapped) are in no preset; both stay reachable by --render-levers.
##
## Which, resolved ONCE per launch: --render-levers=a,b (exactly those) > --render-preset=laptop|desktop > the player's
## saved choice (user://render_preset.cfg, the HUD's toggle) > the video adapter (`preset_for_adapter`). Logged as one
## RENDER_PRESET line. A headless run is always desktop, so baselines and parity shots never move with it.

const NAMES := ["scale_085", "scale_075", "lights_2", "no_haze", "no_env_fog", "crowd_medium", "unlit_stands"]
const PRESETS := {
	"laptop": ["scale_075", "lights_2", "no_env_fog", "no_haze", "crowd_medium"],
	"desktop": [],
}
const SAVE_PATH := "user://render_preset.cfg"

static var _on: Dictionary = {}
static var _read := false
## "laptop", "desktop", or "custom" (an explicit --render-levers list).
static var _preset := ""
## "levers", "flag", "saved", "adapter", "headless", "player", "test": where the active set came from.
static var source := ""


static func on(lever: String) -> bool:
	if not _read:
		_resolve()
	return _on.has(lever)


static func preset() -> String:
	if not _read:
		_resolve()
	return _preset


## The preset a machine gets by default. Godot's Compatibility renderer usually reports the adapter type as OTHER, so the
## NAME decides then: an Intel integrated GPU (UHD, Iris, HD Graphics -- his laptop is "Mesa Intel(R) UHD Graphics 620")
## is a laptop; NVIDIA, GeForce or a Radeon RX is a desktop; anything unrecognised (and a headless dummy) is a desktop,
## the full picture, so no strong machine is ever cut by a guess.
static func preset_for_adapter(adapter_type: int, adapter_name: String) -> String:
	var lowered := adapter_name.to_lower()
	if adapter_name == "" or lowered.contains("dummy"):
		return "desktop"
	if adapter_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return "laptop"
	if adapter_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU or adapter_type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		return "desktop"
	if lowered.contains("nvidia") or lowered.contains("geforce") or lowered.contains("radeon rx") or lowered.contains("radeon pro"):
		return "desktop"
	if lowered.contains("intel") and (lowered.contains("uhd") or lowered.contains("iris") or lowered.contains("hd graphics")):
		return "laptop"
	return "desktop"


## Switch presets at runtime (the HUD's toggle): the levers change and every system re-reads them through the quality
## path; `persist` saves it as the player's choice for this device.
static func apply_preset(name: String, from := "player", persist := false) -> void:
	if not PRESETS.has(name):
		push_warning("RenderLevers: no preset called '%s' (have %s)" % [name, ", ".join(PackedStringArray(PRESETS.keys()))])
		return
	_set(PRESETS[name], name, from)
	if persist:
		var config := ConfigFile.new()
		config.set_value("render", "preset", name)
		config.save(SAVE_PATH)
	var fx := FxWorld.existing()
	if fx != null:
		fx.apply_quality()
	print("RENDER_PRESET %s (%s) levers=%s" % [_preset, source, ",".join(PackedStringArray(_on.keys()))])


## The other preset (for a two-state toggle).
static func next_preset() -> String:
	return "desktop" if preset() == "laptop" else "laptop"


## What a button shows: the preset and what it means in a word.
static func label() -> String:
	return {"laptop": "LOOK LIGHT", "desktop": "LOOK FULL"}.get(preset(), "LOOK CUSTOM")


## For tests: set the levers directly ([] = all off).
static func set_for_test(levers: Array) -> void:
	_set(levers, "custom", "test")


static func _set(levers: Array, name: String, from: String) -> void:
	_read = true
	_on.clear()
	for lever: String in levers:
		_on[lever] = true
	_preset = name
	source = from


static func _resolve() -> void:
	var flags := LaunchFlags.from_environment()
	var listed := flags.text("render-levers", "")
	if listed != "":
		var levers: Array = []
		for piece in listed.split(",", false):
			if piece in NAMES:
				levers.append(piece)
			else:
				push_warning("--render-levers: no lever called '%s' (have %s)" % [piece, ", ".join(NAMES)])
		_set(levers, "custom", "levers")
	else:
		var wanted := flags.text("render-preset", "")
		if PRESETS.has(wanted):
			_set(PRESETS[wanted], wanted, "flag")
		else:
			var config := ConfigFile.new()
			var saved := str(config.get_value("render", "preset", "")) if config.load(SAVE_PATH) == OK else ""
			if PRESETS.has(saved):
				_set(PRESETS[saved], saved, "saved")
			elif DisplayServer.get_name() == "headless":
				_set(PRESETS["desktop"], "desktop", "headless")
			else:
				var name := RenderingServer.get_video_adapter_name()
				var picked := preset_for_adapter(RenderingServer.get_video_adapter_type(), name)
				_set(PRESETS[picked], picked, "adapter")
	print("RENDER_PRESET %s (%s) adapter='%s' type=%d levers=%s" % [_preset, source, RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_type(), ",".join(PackedStringArray(_on.keys()))])


## The tier's value for `key` with the levers applied (FxQuality.value routes through this).
static func adjust(key: String, value: Variant) -> Variant:
	match key:
		"render_scale":
			if on("scale_075"):
				return minf(float(value), 0.75)
			if on("scale_085"):
				return minf(float(value), 0.85)
		"lights":
			if on("lights_2"):
				return mini(int(value), 2)
		"haze":
			if on("no_haze"):
				return false
	return value
