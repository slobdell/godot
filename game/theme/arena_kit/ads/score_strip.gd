class_name ScoreStrip
extends Control
## Round 19 (board, S4): the score as the arena's giant screens show it during play, a strip along the bottom of the
## live feed (the shader composites it; AdBroadcast owns the little viewport it renders in, redrawn only when the
## score changes or the caller says something). Faction names, the points to the win as two meters, the zones held,
## and under them the line the booth just said with the team it is about, the way a venue screen captions the call.
## Visual only: reads `Match.score_snapshot()` and the booth's cues.

const DISPLAY_FONT := preload("res://assets/fonts/Oswald-Latin.ttf")
const MONO_FONT := preload("res://assets/fonts/ShareTechMono-Regular.ttf")
## The strip's layout sizes (portrait and the airship's landscape cut), drawn into a viewport of the same size.
const PORTRAIT := Vector2i(320, 104)
const LANDSCAPE := Vector2i(640, 84)

var snapshot: Dictionary = {}
## The caption under the score: {text, team} (team -1 = nobody's), or empty.
var caption: Dictionary = {}
var wide := false


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.92))
	if snapshot.is_empty():
		return
	var sides: Array = snapshot["sides"]
	var control := bool(snapshot["control"])
	var colours := [GameTheme.team_color(0), GameTheme.team_color(1)]  # the venue is neutral: team colours, not friend and foe
	var row := 34.0 if not wide else 30.0
	# Names at the edges, points in the middle: "CONDEMNED  42 · 37  LAW".
	for t in 2:
		var side: Dictionary = sides[t]
		var name := String(side["name"])
		var value := str(int(side["points"])) if control else str(int(side["kills"]))
		var name_px := 20 if not wide else 22
		var value_px := 30 if not wide else 28
		var nw := DISPLAY_FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
		var vw := DISPLAY_FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_px).x
		var nx := 10.0 if t == 0 else w - 10.0 - nw
		var vx := w / 2.0 - 14.0 - vw if t == 0 else w / 2.0 + 14.0
		draw_rect(Rect2(0.0 if t == 0 else w - 4.0, 0, 4.0, row), colours[t])
		draw_string(DISPLAY_FONT, Vector2(nx, row - 9.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, Color.WHITE)
		draw_string(DISPLAY_FONT, Vector2(vx, row - 4.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_px, Color.WHITE)
		if control:
			# The meter to the win under each half, filling toward the middle.
			var meter := Rect2(10.0 if t == 0 else w / 2.0 + 6.0, row + 2.0, w / 2.0 - 16.0, 6.0)
			draw_rect(meter, Color(colours[t], 0.2))
			var f := clampf(float(side["points"]) / float(snapshot["points_to_win"]), 0.0, 1.0)
			var filled := Rect2(meter.position, Vector2(meter.size.x * f, meter.size.y))
			if t == 1:
				filled.position.x = meter.end.x - filled.size.x
			draw_rect(filled, colours[t])
	var mid := "TO %d" % int(snapshot["points_to_win"]) if control else "KILLS"
	var mw := MONO_FONT.get_string_size(mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(MONO_FONT, Vector2(w / 2.0 - mw / 2.0, 12.0), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
	# Who holds what, one line: "W ■ CONDEMNED   E □ —".
	var zones_line := ""
	if control:
		var parts: Array = []
		for zone: Dictionary in snapshot["objectives"]:
			var owner := int(zone["owner"])
			parts.append("%s: %s" % [String(zone["label"]).trim_prefix("the ").to_upper(),
					String(sides[owner]["name"]) if owner >= 0 else ("CONTESTED" if bool(zone.get("contested", false)) else "OPEN")])
		zones_line = "   ".join(parts)
	draw_string(MONO_FONT, Vector2(10.0, row + 22.0), zones_line, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 11, Color(0.85, 0.85, 0.8))
	if not caption.is_empty():
		var team := int(caption.get("team", -1))
		var c: Color = colours[team] if team >= 0 and team < 2 else Color(1.0, 0.8, 0.3)
		draw_rect(Rect2(0, h - 26.0, 4.0, 26.0), c)
		draw_string(MONO_FONT, Vector2(10.0, h - 9.0), String(caption["text"]), HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, 12, c.lerp(Color.WHITE, 0.5))
