class_name TaskPreview
extends RefCounted
## Round 7 (C2), the lead: "I don't know what it means to tell a unit to screen. I don't know what way they'll point or
## if they'll hold position or what. So it would be really cool to have a sleek video game HUD ... that shows an
## animation of the movement [this] would do for the squad." The command-card tooltip plays a small top-down loop: the
## squad (bottom) moves to its posture around the clicked point (top), turns to face where it will face, and shows
## whether it fires and whether it keeps advancing. The military symbol made the button nameable; this makes the
## behaviour knowable.
##
## The geometry is `posture()`. Today it is a stand-in built from TacticsFormation's real shapes and the numbers squad
## reported for each task (support by fire: a line at a standoff, facing the point; screen: a wide line across it;
## ambush: a line short of the kill zone, holding fire until an enemy is in it). When squad publishes a pure preview
## of its task postures, `posture()` becomes a call to it and the drawing does not change.

const LOOP_S := 3.6
## Phases of the loop, as fractions of LOOP_S: moving, then facing, then the task's own business (firing, holding).
const MOVE_END := 0.45
const FACE_END := 0.6
const UNITS := 4


## The posture a task leaves a squad in, in a unit square (x right, y down; the point the player clicks is (0.5, 0.2),
## the squad starts along the bottom): {"slots": [Vector2], "facing": [Vector2 unit], "fires": "no" | "always" |
## "on_contact", "advances": bool, "marker": "point" | "zone" | "line" | "none", "words": String}.
static func posture(verb: String, count := UNITS) -> Dictionary:
	var point := Vector2(0.5, 0.2)
	var slots: Array[Vector2] = []
	var facing: Array[Vector2] = []
	var result := {"fires": "no", "advances": false, "marker": "point", "words": ""}
	match verb:
		"support_by_fire":
			# A firing line at a standoff from the point, every gun facing it; it does not advance.
			for i in count:
				slots.append(Vector2(lerpf(0.22, 0.78, float(i) / maxf(count - 1, 1)), 0.62))
				facing.append((point - slots[-1]).normalized())
			result.merge({"fires": "always", "words": "Line up at a distance, face it, fire. No advance."}, true)
		"screen":
			# A wide line across the point, facing out, observing; fights only what comes to it.
			for i in count:
				slots.append(Vector2(lerpf(0.08, 0.92, float(i) / maxf(count - 1, 1)), 0.2))
				facing.append(Vector2(0, -1))
			result.merge({"fires": "on_contact", "marker": "line", "words": "Spread in a wide line across it, watch outward."}, true)
		"ambush":
			# A line short of the kill zone, facing it, holding fire until an enemy walks in.
			for i in count:
				slots.append(Vector2(lerpf(0.25, 0.75, float(i) / maxf(count - 1, 1)), 0.55))
				facing.append((point - slots[-1]).normalized())
			result.merge({"fires": "on_contact", "marker": "zone", "words": "Hide in a line, hold fire until they enter the zone."}, true)
		"attack_move":
			# The formation drives to the point, firing at anything on the way.
			var offsets := TacticsFormation.centered(TacticsFormation.offsets("wedge", count, 1.0))
			for offset: Vector2 in offsets:
				slots.append(point + Vector2(offset.x, offset.y) * 0.11 + Vector2(0, 0.08))
				facing.append(Vector2(0, -1))
			result.merge({"fires": "always", "advances": true, "words": "Drive there in formation, shooting on the way."}, true)
		"hold":
			# Stop where they are and fight from there.
			for i in count:
				slots.append(Vector2(lerpf(0.3, 0.7, float(i) / maxf(count - 1, 1)), 0.85))
				facing.append(Vector2(0, -1))
			result.merge({"fires": "on_contact", "marker": "none", "words": "Stay put and fight from here."}, true)
		"stop":
			for i in count:
				slots.append(Vector2(lerpf(0.3, 0.7, float(i) / maxf(count - 1, 1)), 0.85))
				facing.append(Vector2(0, -1))
			result.merge({"fires": "no", "marker": "none", "words": "Drop every order; stand still."}, true)
		_:
			return {}
	result["slots"] = slots
	result["facing"] = facing
	return result


## Where each unit starts (the bottom row).
static func starts(count := UNITS) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in count:
		result.append(Vector2(lerpf(0.3, 0.7, float(i) / maxf(count - 1, 1)), 0.88))
	return result


## Draw the loop for `verb` into `rect` at `seconds` (any clock; it wraps).
static func draw(canvas: CanvasItem, rect: Rect2, verb: String, seconds: float, ink: Color, enemy: Color) -> void:
	var shape := posture(verb)
	if shape.is_empty():
		return
	var t := fposmod(seconds, LOOP_S) / LOOP_S
	var to_px := func(p: Vector2) -> Vector2: return rect.position + p * rect.size
	canvas.draw_rect(rect, Color(0, 0, 0, 0.35))
	var point: Vector2 = to_px.call(Vector2(0.5, 0.2))
	match String(shape["marker"]):
		"point":
			canvas.draw_line(point + Vector2(-6, -6), point + Vector2(6, 6), Color(ink, 0.8), 2.0)
			canvas.draw_line(point + Vector2(-6, 6), point + Vector2(6, -6), Color(ink, 0.8), 2.0)
		"zone":
			canvas.draw_arc(point, rect.size.y * 0.12, 0.0, TAU, 24, Color(enemy, 0.6), 1.5)
		"line":
			canvas.draw_dashed_line(to_px.call(Vector2(0.03, 0.2)), to_px.call(Vector2(0.97, 0.2)), Color(ink, 0.5), 1.0, 4.0)
	var slots: Array = shape["slots"]
	var facing: Array = shape["facing"]
	var start := starts(slots.size())
	var move := CyberStyle.ease_in_out(clampf(t / MOVE_END, 0.0, 1.0))
	var turn := clampf((t - MOVE_END) / (FACE_END - MOVE_END), 0.0, 1.0)
	# An enemy walks into the zone in the last part of the loop: the trigger for "on contact".
	var enemy_in := t > 0.75
	if String(shape["fires"]) == "on_contact" and t > 0.62:
		var walk := clampf((t - 0.62) / 0.13, 0.0, 1.0)
		canvas.draw_circle((to_px.call(Vector2(1.05, 0.05)) as Vector2).lerp(point, walk), 4.0, enemy)
	var glyph := rect.size.y * 0.13
	for i in slots.size():
		var from: Vector2 = to_px.call(start[i])
		var to: Vector2 = to_px.call(slots[i])
		var at: Vector2 = from.lerp(to, move)
		var travel := (to - from).normalized() if from.distance_to(to) > 1.0 else Vector2(0, -1)
		var face: Vector2 = (facing[i] as Vector2)
		var heading_vec: Vector2 = travel.lerp(face, turn).normalized() if turn > 0.0 else travel
		var heading := atan2(heading_vec.x, -heading_vec.y)
		CommandIcons.draw_unit(canvas, "scout", at, glyph, ink, heading)
		var fires := String(shape["fires"]) == "always" and t > FACE_END or String(shape["fires"]) == "on_contact" and enemy_in
		if fires and fmod(seconds * 6.0 + i * 0.37, 1.0) < 0.5:
			canvas.draw_dashed_line(at, at + heading_vec * rect.size.y * 0.35, Color(CyberStyle.YELLOW, 0.8), 1.5, 3.0)
	if shape["advances"] and t > FACE_END:
		canvas.draw_string(CyberStyle.font(), rect.position + Vector2(4, rect.size.y - 4), "ADVANCES", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, Color(ink, 0.7))
	elif not shape["advances"] and t > FACE_END:
		canvas.draw_string(CyberStyle.font(), rect.position + Vector2(4, rect.size.y - 4), "HOLDS HERE", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, Color(ink, 0.7))
