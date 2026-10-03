class_name DrawBatch
extends RefCounted
## Control X4 (CP1: the HUD ≤ 130 draw calls): the renderer merges consecutive draws of the same kind into one draw
## call, so a widget that draws each cell's fill, outline, icon and label in turn pays four calls per cell. Queue the
## cells' pieces here instead and `flush` draws them kind by kind: every fill, then every outline, then every icon,
## then every label. Later pieces still land on top of earlier kinds, which is how the widgets were layered anyway.

var _fills: Array = []
var _outlines: Array = []
var _icons: Array = []
## Round 6 X2: pre-drawn textures (task graphics) in the icon pass.
var _textures: Array = []
var _texts: Array = []


func fill(rect: Rect2, color: Color) -> void:
	_fills.append([rect, color])


func outline(rect: Rect2, color: Color, width := 1.0) -> void:
	_outlines.append([rect, color, width])


func icon(role: String, at: Vector2, size: float, color: Color) -> void:
	_icons.append([role, at, size, color])


func texture(image: Texture2D, rect: Rect2, color: Color) -> void:
	_textures.append([image, rect, color])


func text(font: Font, at: Vector2, words: String, font_size: int, color: Color, width := -1.0) -> void:
	_texts.append([font, at, words, font_size, color, width])


func flush(canvas: CanvasItem) -> void:
	for piece: Array in _fills:
		canvas.draw_rect(piece[0], piece[1])
	for piece: Array in _outlines:
		canvas.draw_rect(piece[0], piece[1], false, piece[2])
	for piece: Array in _icons:
		CommandIcons.draw_unit_icon(canvas, piece[0], piece[1], piece[2], piece[3])
	for piece: Array in _grouped(_textures, _texture_key, _texture_rect):
		canvas.draw_texture_rect(piece[0], piece[1], false, piece[2])
	for piece: Array in _grouped(_texts, _text_key, _text_rect):
		canvas.draw_string(piece[0], piece[1], piece[2], HORIZONTAL_ALIGNMENT_LEFT, piece[5], piece[3], piece[4])
	_fills.clear()
	_outlines.clear()
	_icons.clear()
	_textures.clear()
	_texts.clear()


## Round 16 (hud H7): the renderer starts a new draw call whenever the texture changes, and a card that draws button by
## button alternates them (a task glyph, then the pointer corner; a 13 px hotkey, then a 14 px label: each size is its
## own glyph texture). So a pass is drawn grouped by texture, the groups in order of first use and each group in its
## own order - but ONLY when no two pieces of different groups overlap. Then every pixel is covered by the same pieces
## in the same order as before; if any two do overlap, the pass is drawn exactly as queued.
static func _grouped(pieces: Array, key_of: Callable, rect_of: Callable) -> Array:
	if pieces.size() < 3:
		return pieces
	var keys: Array = []
	var rects: Array[Rect2] = []
	var groups := {}
	var order: Array = []
	for piece: Array in pieces:
		var key: Variant = key_of.call(piece)
		keys.append(key)
		rects.append(rect_of.call(piece))
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		(groups[key] as Array).append(piece)
	if order.size() == pieces.size() or order.size() == 1:
		return pieces  # nothing to merge, or already one group
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			if keys[i] != keys[j] and rects[i].intersects(rects[j]):
				return pieces
	var result: Array = []
	for key: Variant in order:
		result.append_array(groups[key])
	return result


static func _texture_key(piece: Array) -> Variant:
	return piece[0]


static func _texture_rect(piece: Array) -> Rect2:
	return (piece[1] as Rect2).abs()


static func _text_key(piece: Array) -> Variant:
	return [piece[0], piece[3]]  # font, size: one glyph cache texture


## The line box (ascent to descent, the advance wide): glyph ink stays inside it, so two boxes that only share an
## edge share no pixel (`intersects` without borders).
static func _text_rect(piece: Array) -> Rect2:
	var font: Font = piece[0]
	var size: int = piece[3]
	var width: float = piece[5]
	var advance := font.get_string_size(piece[2], HORIZONTAL_ALIGNMENT_LEFT, width, size).x
	var at: Vector2 = piece[1]
	return Rect2(at.x, at.y - font.get_ascent(size), advance, font.get_height(size))
