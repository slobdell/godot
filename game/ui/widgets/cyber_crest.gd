class_name CyberCrest
extends Control
## A kit element (G2, `_agents/ui_kit.md`): a faction's crest slot. A chamfered badge in the faction's colour holding
## its letters (CyberKit.FACTION_MARKS); `texture` (optional) replaces the letters when a faction gets drawn art.
## Square; it draws into the largest square that fits its rect.

@export var faction := "":
	set(v):
		faction = v
		queue_redraw()
@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
## A dimmed crest (a faction not picked).
@export var dim := false:
	set(v):
		dim = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 4.0:
		return
	var rect := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	var color := CyberKit.faction_color(faction)
	var alpha := 0.45 if dim else 1.0
	var cut := side * 0.24
	draw_colored_polygon(CyberFrame.chamfer_polygon(rect, cut), Color(CyberStyle.CARD, 0.95))
	var inner := rect.grow(-side * 0.08)
	var inner_outline := CyberFrame.chamfer_polygon(inner, cut * 0.8)
	draw_colored_polygon(inner_outline, Color(color, 0.16 * alpha))
	var outline := CyberFrame.chamfer_polygon(rect, cut)
	outline.append(outline[0])
	draw_polyline(outline, Color(color, alpha), maxf(2.0, side * 0.04), true)
	inner_outline.append(inner_outline[0])
	draw_polyline(inner_outline, Color(color, 0.5 * alpha), 1.0, true)
	if texture != null:
		draw_texture_rect(texture, inner.grow(-side * 0.06), false, Color(1, 1, 1, alpha))
		return
	var mark := String(CyberKit.FACTION_MARKS.get(faction, faction.substr(0, 2).to_upper()))
	var font := CyberStyle.font()
	var font_size := roundi(side * 0.42)
	var width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(rect.get_center().x - width / 2.0, rect.get_center().y + font.get_ascent(font_size) * 0.36)
	draw_string(font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
