class_name CyberMeter
extends Control
## A kit element (G2, `_agents/ui_kit.md`): a filled chamfered meter with a tick every `step`, for an amount out of a
## total that the player spends (the garage's credits) or earns (a score). The fill is `color`; past the total it
## turns the error colour and says so. The words sit inside the bar, left and right: `label` and "<value> / <total>".
## Drawn with `_draw` (one polygon per layer, no nodes), so it costs nothing while it does not change.

@export var value := 0:
	set(v):
		value = v
		queue_redraw()
@export var total := 1000:
	set(v):
		total = maxi(1, v)
		queue_redraw()
## A tick every `step` (0 = none).
@export var step := 100:
	set(v):
		step = maxi(0, v)
		queue_redraw()
@export var color := CyberStyle.GREEN:
	set(v):
		color = v
		queue_redraw()
@export var label := "":
	set(v):
		label = v
		queue_redraw()
## What follows the numbers: "CR".
@export var unit := "":
	set(v):
		unit = v
		queue_redraw()
## True when the meter shows what is LEFT (it drains as the player spends); the right-hand text then reads "<value>
## LEFT" and an overdraft is a negative value.
@export var shows_left := false:
	set(v):
		shows_left = v
		queue_redraw()
@export var size_1080 := CyberKit.BODY:
	set(v):
		size_1080 = v
		queue_redraw()
## Below this fraction of the total (and above zero) the fill turns amber: "nearly spent" (0 = never; the default, so
## existing meters draw as before). The garage sets 0.1.
@export var low_fraction := 0.0:
	set(v):
		low_fraction = v
		queue_redraw()
## The screen's scale (the factor its layout uses); 0 = screen height / 1080 x the touch boost.
@export var ui_scale := 0.0:
	set(v):
		ui_scale = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## The filled fraction, 0..1 (what is left, or what is spent, of the total).
func fraction() -> float:
	return clampf(float(value) / float(total), 0.0, 1.0)


## Nearly spent: under `low_fraction` of the total, but not empty and not over.
func low() -> bool:
	return low_fraction > 0.0 and value > 0 and not over() and float(value) < float(total) * low_fraction


func over() -> bool:
	return value < 0 if shows_left else value > total


## "620 / 1000 CR", or "620 CR LEFT", or "OVER BY 40 CR".
func readout() -> String:
	var suffix := (" " + unit) if unit != "" else ""
	if over():
		return "OVER BY %d%s" % [absi(value) if shows_left else value - total, suffix]
	if shows_left:
		return "%d%s LEFT" % [value, suffix]
	return "%d / %d%s" % [value, total, suffix]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	var scale := ui_scale if ui_scale > 0.0 else CyberKit.s(self) * CyberStyle.touch_boost()
	var cut := CyberFrame.clamp_chamfer(CyberKit.CUT * scale, rect.size)
	var accent := CyberStyle.ERROR_BORDER if over() else (CyberKit.AMBER if low() else color)
	draw_colored_polygon(CyberFrame.chamfer_polygon(rect, cut), Color(CyberStyle.CARD, 0.92))
	var fill_rect := rect.grow(-3.0)
	if not over():  # an overdraft fills the whole bar in the error colour
		fill_rect.size.x *= fraction()
	if fill_rect.size.x > 1.0:
		draw_colored_polygon(_fill_polygon(fill_rect, CyberFrame.clamp_chamfer(cut - 2.0, rect.grow(-3.0).size)),
				Color(accent, 0.38 if not over() else 0.3))
	if step > 0 and total > step:
		var ticks := PackedVector2Array()
		var n := total / step
		for i in range(1, n + (0 if total % step == 0 else 1)):
			var x := rect.position.x + rect.size.x * float(i * step) / float(total)
			ticks.append_array([Vector2(x, rect.end.y - rect.size.y * 0.28), Vector2(x, rect.end.y - 3.0)])
		draw_multiline(ticks, Color(CyberStyle.TEXT, 0.35), 1.0)
	var outline := CyberFrame.chamfer_polygon(rect, cut)
	outline.append(outline[0])
	draw_polyline(outline, Color(accent, 0.9), 2.0, true)
	var font := CyberStyle.font()
	var font_size := roundi(size_1080 * scale)
	var baseline := rect.get_center().y + font.get_ascent(font_size) * 0.38
	var pad := CyberKit.GAP_M * scale
	if label != "":
		draw_string_outline(font, Vector2(rect.position.x + pad, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				3, Color.BLACK)
		draw_string(font, Vector2(rect.position.x + pad, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				CyberStyle.TEXT)
	var text := readout()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(rect.end.x - pad - width, baseline)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CyberStyle.WHITE if not over() else accent)


## The fill: chamfered on the left, cut square on the right unless it reaches the end.
func _fill_polygon(fill: Rect2, cut: float) -> PackedVector2Array:
	var full := rect_reaches_end(fill)
	if full:
		return CyberFrame.chamfer_polygon(fill, cut)
	var l := fill.position.x
	var t := fill.position.y
	var r := fill.end.x
	var b := fill.end.y
	var c := minf(cut, fill.size.x)
	return PackedVector2Array([Vector2(l + c, t), Vector2(r, t), Vector2(r, b), Vector2(l + c, b), Vector2(l, b - c),
			Vector2(l, t + c)])


func rect_reaches_end(fill: Rect2) -> bool:
	return fill.end.x >= size.x - 4.0
