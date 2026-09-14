class_name PerfOverlay
extends CanvasLayer
## A corner readout for phone tests without a console: fps, frame ms (avg and worst over the
## last half second), draw calls, objects, pooled lights lit, tracers, and the FX quality tier.
## Show it with `--perf` (any mode) or in the FX lab.

const REFRESH_SECONDS := 0.5

var extra := ""

var _label := Label.new()
var _elapsed := 0.0
var _frames := 0
var _worst := 0.0


func _init() -> void:
	name = "PerfOverlay"
	layer = 100
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _elapsed < REFRESH_SECONDS:
		return
	var fx := FxWorld.existing()
	_label.text = "%d fps  %.1f ms avg  %.1f ms worst\ndraws %d  objects %d  prims %dk\nlights %s  tracers %s  fx %s%s" % [
		roundi(_frames / _elapsed), 1000.0 * _elapsed / _frames, 1000.0 * _worst,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
		str(fx.lights.lit_count) + "/" + str(fx.lights.lights.size()) if fx != null else "-",
		str(fx.tracers.active_count()) if fx != null else "-",
		FxQuality.tier_name(), ("\n" + extra) if extra != "" else ""]
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0
