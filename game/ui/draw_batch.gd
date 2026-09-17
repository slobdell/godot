class_name DrawBatch
extends RefCounted
## Control X4 (CP1: the HUD ≤ 130 draw calls): the renderer merges consecutive draws of the same kind into one draw
## call, so a widget that draws each cell's fill, outline, icon and label in turn pays four calls per cell. Queue the
## cells' pieces here instead and `flush` draws them kind by kind: every fill, then every outline, then every icon,
## then every label. Later pieces still land on top of earlier kinds, which is how the widgets were layered anyway.

var _fills: Array = []
var _outlines: Array = []
var _icons: Array = []
var _texts: Array = []


func fill(rect: Rect2, color: Color) -> void:
	_fills.append([rect, color])


func outline(rect: Rect2, color: Color, width := 1.0) -> void:
	_outlines.append([rect, color, width])


func icon(role: String, at: Vector2, size: float, color: Color) -> void:
	_icons.append([role, at, size, color])


func text(font: Font, at: Vector2, words: String, font_size: int, color: Color, width := -1.0) -> void:
	_texts.append([font, at, words, font_size, color, width])


func flush(canvas: CanvasItem) -> void:
	for piece: Array in _fills:
		canvas.draw_rect(piece[0], piece[1])
	for piece: Array in _outlines:
		canvas.draw_rect(piece[0], piece[1], false, piece[2])
	for piece: Array in _icons:
		CommandIcons.draw_unit_icon(canvas, piece[0], piece[1], piece[2], piece[3])
	for piece: Array in _texts:
		canvas.draw_string(piece[0], piece[1], piece[2], HORIZONTAL_ALIGNMENT_LEFT, piece[5], piece[3], piece[4])
	_fills.clear()
	_outlines.clear()
	_icons.clear()
	_texts.clear()
