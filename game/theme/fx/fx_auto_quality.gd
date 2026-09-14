class_name FxAutoQuality
extends Node
## Steps the FX tier down when the game can't hold its frame rate, only while nobody chose a tier
## (FxQuality.is_automatic) and, by default, only on web/mobile (desktop agents share a busy CPU and
## would flap). Browsers cap frames at the display rate, so there's no reliable headroom signal to
## step UP; players raise it with the HUD's FX button.
##   window: average frame time over 4 s; > 24 ms (under ~42 fps) → one tier down; 10 s cooldown.

const WINDOW_SECONDS := 4.0
const SLOW_FRAME_MS := 24.0
const COOLDOWN_SECONDS := 10.0
## Ignore the first seconds: loading and shader compiles aren't steady-state.
const SETTLE_SECONDS := 5.0

var enabled := OS.has_feature("web") or OS.has_feature("mobile") or LaunchFlags.from_environment().has("fx-auto")

var _elapsed := 0.0
var _frames := 0
var _since_start := 0.0
var _cooldown := 0.0


func _init() -> void:
	name = "FxAutoQuality"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_since_start += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if not enabled or _since_start < SETTLE_SECONDS or get_tree().paused:
		return
	_elapsed += delta
	_frames += 1
	if _elapsed < WINDOW_SECONDS:
		return
	var average_ms := 1000.0 * _elapsed / _frames
	_elapsed = 0.0
	_frames = 0
	if should_step_down(average_ms, FxQuality.tier(), FxQuality.is_automatic(), _cooldown):
		_cooldown = COOLDOWN_SECONDS
		FxQuality.apply(FxQuality.tier() - 1, "auto")


## The policy, pure for tests.
static func should_step_down(average_ms: float, tier: int, automatic: bool, cooldown: float) -> bool:
	return automatic and cooldown <= 0.0 and tier > FxQuality.Tier.LOW and average_ms > SLOW_FRAME_MS
