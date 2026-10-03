extends TestCase
## Round 16 (hud H7): DrawBatch draws its texture and text passes grouped by texture (one draw call per group) only when
## no two pieces of different groups overlap - then the same pieces cover every pixel in the same order. Any overlap
## between groups keeps the order as queued.


func test_disjoint_pieces_are_grouped_by_texture_in_first_use_order() -> void:
	var a := PlaceholderTexture2D.new()
	var b := PlaceholderTexture2D.new()
	var pieces: Array = []
	for i in 4:
		pieces.append([a, Rect2(i * 100, 0, 40, 40), Color.WHITE])
		pieces.append([b, Rect2(i * 100 + 50, 0, 40, 40), Color.WHITE])
	var drawn := DrawBatch._grouped(pieces, DrawBatch._texture_key, DrawBatch._texture_rect)
	assert_eq(drawn.slice(0, 4), [pieces[0], pieces[2], pieces[4], pieces[6]], "every A first, in their own order")
	assert_eq(drawn.slice(4), [pieces[1], pieces[3], pieces[5], pieces[7]], "then every B")


func test_any_overlap_between_groups_keeps_the_queued_order() -> void:
	var a := PlaceholderTexture2D.new()
	var b := PlaceholderTexture2D.new()
	var pieces: Array = [[a, Rect2(0, 0, 40, 40), Color.WHITE], [b, Rect2(30, 30, 40, 40), Color.WHITE],
			[a, Rect2(200, 0, 40, 40), Color.WHITE]]
	assert_eq(DrawBatch._grouped(pieces, DrawBatch._texture_key, DrawBatch._texture_rect), pieces, "B over A stays B over A")
	# Same-texture overlaps are fine: they stay in their own order inside the group.
	var same: Array = [[a, Rect2(0, 0, 40, 40), Color.WHITE], [a, Rect2(10, 10, 40, 40), Color.RED],
			[b, Rect2(200, 0, 40, 40), Color.WHITE], [a, Rect2(400, 0, 4, 4), Color.WHITE]]
	assert_eq(DrawBatch._grouped(same, DrawBatch._texture_key, DrawBatch._texture_rect), [same[0], same[1], same[3], same[2]],
			"overlaps within one texture keep their order")


func test_texts_group_by_font_and_size_and_respect_their_line_boxes() -> void:
	var font := ThemeDB.fallback_font
	var apart: Array = [[font, Vector2(0, 20), "S", 13, Color.WHITE, -1.0], [font, Vector2(0, 60), "Stop", 14, Color.WHITE, -1.0],
			[font, Vector2(200, 20), "H", 13, Color.WHITE, -1.0], [font, Vector2(200, 60), "Hold", 14, Color.WHITE, -1.0]]
	var drawn := DrawBatch._grouped(apart, DrawBatch._text_key, DrawBatch._text_rect)
	assert_eq(drawn, [apart[0], apart[2], apart[1], apart[3]], "hotkeys together, labels together")
	var touching: Array = [[font, Vector2(0, 20), "Support", 13, Color.WHITE, -1.0], [font, Vector2(10, 26), "by Fire", 14, Color.WHITE, -1.0],
			[font, Vector2(300, 20), "x", 13, Color.WHITE, -1.0]]
	assert_eq(DrawBatch._grouped(touching, DrawBatch._text_key, DrawBatch._text_rect), touching, "lines that touch keep their order")
