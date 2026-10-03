class_name RenderLevers
extends RefCounted
## The priced levers (render, round 16, R8): ways to buy GPU time that CHANGE THE PICTURE, so every one is OFF unless
## named on the command line -- `--render-levers=scale_085,lights_2` (`make skirmish SKIRMISH_FLAGS=...`, or any mode).
## Contract C16.1: nothing here ships on a worker's call; the lead taps them on his page, and a tapped lever becomes a
## default only by a later, declared commit. Prices (GPU ms saved at his window, laptop, frozen staged frame) are in
## the render brief's Status and on the page.
##
##   scale_085 / scale_075  the 3D picture rendered at 85 % / 75 % of the window's lines, scaled up (UI stays sharp)
##   lights_2               two pooled lights instead of four (explosions light fewer things at once)
##   no_haze                no heat haze over burning wrecks
##   no_env_fog             no depth/height fog in the arena
##   crowd_medium           the medium tier's crowd (3 600 figures, not all 7 700 seats)
##   unlit_stands           the stands drawn flat-lit (no moonlight shading on the kit)

const NAMES := ["scale_085", "scale_075", "lights_2", "no_haze", "no_env_fog", "crowd_medium", "unlit_stands"]

static var _on: Dictionary = {}
static var _read := false


static func on(lever: String) -> bool:
	if not _read:
		_read = true
		_on.clear()
		for piece in LaunchFlags.from_environment().text("render-levers", "").split(",", false):
			if piece in NAMES:
				_on[piece] = true
			else:
				push_warning("--render-levers: no lever called '%s' (have %s)" % [piece, ", ".join(NAMES)])
		if not _on.is_empty():
			print("RENDER_LEVERS %s" % ",".join(PackedStringArray(_on.keys())))
	return _on.has(lever)


## For tests: set the levers directly ([] = all off).
static func set_for_test(levers: Array) -> void:
	_read = true
	_on.clear()
	for lever: String in levers:
		_on[lever] = true


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
