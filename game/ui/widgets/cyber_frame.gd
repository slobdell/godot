@tool
class_name CyberFrame
extends Control
## A chamfered translucent panel with four glowing corner brackets (banner spec §3): the frame for
## any HUD panel. Geometry scales with screen height / 1080; stroke (4 px) and glow (10 px) don't.
## The box can be animated about its center with anim_width / anim_height / anim_alpha (the banner's
## beam → open choreography). Draw commands are retained by the canvas, so a frame that isn't
## animating costs nothing per frame; glow is a few wide low-alpha strokes under the crisp one.

@export var fill_color := CyberStyle.THEME_INFO["fill"]:
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color := CyberStyle.BORDER_CYAN:
	set(value):
		border_color = value
		queue_redraw()
## Corner cut and bracket arm length at 1080p.
@export var chamfer_1080 := 20.0:
	set(value):
		chamfer_1080 = value
		queue_redraw()
@export var arm_1080 := 30.0:
	set(value):
		arm_1080 = value
		queue_redraw()
@export var stroke_px := 4.0:
	set(value):
		stroke_px = value
		queue_redraw()
@export var glow_px := 10.0:
	set(value):
		glow_px = value
		queue_redraw()
@export_range(0.0, 1.2) var anim_width := 1.0:
	set(value):
		anim_width = value
		queue_redraw()
@export_range(0.0, 1.2) var anim_height := 1.0:
	set(value):
		anim_height = value
		queue_redraw()
@export_range(0.0, 1.0) var anim_alpha := 1.0:
	set(value):
		anim_alpha = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func apply_theme(theme: Dictionary) -> void:
	fill_color = theme["fill"]
	border_color = theme["border"]


func _draw() -> void:
	var scale_1080 := CyberStyle.ui_scale(get_viewport_rect().size) if is_inside_tree() else 1.0
	var rect := animated_rect(Rect2(Vector2.ZERO, size), anim_width, anim_height)
	if rect.size.x <= 0.5 or anim_alpha <= 0.0:
		return
	var chamfer := clamp_chamfer(chamfer_1080 * scale_1080, rect.size)
	# Recompose per draw from the theme alpha × anim alpha (never accumulate).
	var fill := Color(fill_color, fill_color.a * anim_alpha)
	var border := Color(border_color, anim_alpha)
	var outline := chamfer_polygon(rect, chamfer)
	if outline.size() >= 3 and fill.a > 0.0:
		draw_colored_polygon(outline, fill)
	var arm := clamp_arm(arm_1080 * scale_1080, chamfer, rect.size)
	# Every bracket's segments in one list, so each layer is a single draw call (X4, CP1: the HUD ≤ 130 draw calls; four
	# polylines per layer made a frame 17 draws).
	var segments := PackedVector2Array()
	for path in bracket_paths(rect, chamfer, arm):
		for i in path.size() - 1:
			segments.append_array([path[i], path[i + 1]])
	if segments.is_empty():
		return
	# Glow: wide, faint strokes that fall off toward glow_px, then the crisp stroke.
	for layer in [[stroke_px + glow_px * 2.0, 0.12], [stroke_px + glow_px, 0.22], [stroke_px + glow_px * 0.4, 0.35]]:
		draw_multiline(segments, Color(border, border.a * float(layer[1])), float(layer[0]), true)
	draw_multiline(segments, border, stroke_px, true)


## The box scaled about its fixed center (spec §2: never the top-left).
static func animated_rect(base: Rect2, width_fraction: float, height_fraction: float) -> Rect2:
	var center := base.get_center()
	var box := Vector2(base.size.x * width_fraction, base.size.y * height_fraction)
	return Rect2(center - box / 2.0, box)


## chamfer = min(chamfer, min(w, h) / 2.5): collapsed boxes stay a lens, not a broken shape.
static func clamp_chamfer(chamfer: float, box: Vector2) -> float:
	return maxf(0.0, minf(chamfer, minf(box.x, box.y) / 2.5))


## Arms stop short of mid-edge so opposing brackets never touch.
static func clamp_arm(arm: float, chamfer: float, box: Vector2) -> float:
	return maxf(0.0, minf(arm, minf(box.y / 2.0 - chamfer, box.x / 2.0 - chamfer)))


## The octagon (spec §3.1), clockwise from the top edge.
static func chamfer_polygon(rect: Rect2, chamfer: float) -> PackedVector2Array:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	return PackedVector2Array([
		Vector2(l + chamfer, t), Vector2(r - chamfer, t), Vector2(r, t + chamfer), Vector2(r, b - chamfer),
		Vector2(r - chamfer, b), Vector2(l + chamfer, b), Vector2(l, b - chamfer), Vector2(l, t + chamfer),
	])


## Four open corner brackets (spec §3.2): arm → 45° chamfer → arm. Middles of edges stay open.
static func bracket_paths(rect: Rect2, chamfer: float, arm: float) -> Array[PackedVector2Array]:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	return [
		PackedVector2Array([Vector2(l + chamfer + arm, t), Vector2(l + chamfer, t), Vector2(l, t + chamfer), Vector2(l, t + chamfer + arm)]),
		PackedVector2Array([Vector2(l, b - chamfer - arm), Vector2(l, b - chamfer), Vector2(l + chamfer, b), Vector2(l + chamfer + arm, b)]),
		PackedVector2Array([Vector2(r - chamfer - arm, b), Vector2(r - chamfer, b), Vector2(r, b - chamfer), Vector2(r, b - chamfer - arm)]),
		PackedVector2Array([Vector2(r, t + chamfer + arm), Vector2(r, t + chamfer), Vector2(r - chamfer, t), Vector2(r - chamfer - arm, t)]),
	]
