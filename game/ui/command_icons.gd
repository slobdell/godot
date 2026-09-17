class_name CommandIcons
extends RefCounted
## C2/C3/C5: the command UI's pictograms, drawn with CanvasItem calls so they scale to any tap target
## and need no image assets. Formation icons are drawn FROM Formations.offsets (the geometry the squads
## really use), so an icon can never drift from behavior. Colors come from the caller (GameTheme.ui).
##
## All glyphs face "up the screen" (the direction of travel) unless a heading is given.

## Plain-language names, taglines, and one-liners for players who aren't military experts (the lead,
## round 2): [name, tagline, description].
const FORMATION_INFO := {
	"column": ["Column", "fast in lanes", "Single file. Quick through narrow gaps; only the leader shoots forward."],
	"wedge": ["Wedge", "all-round", "An arrowhead. Strong in every direction: the best default."],
	"vee": ["Vee", "guns forward", "Leader at the back, flanks forward. Most guns face a known enemy."],
	"line": ["Line", "max firepower", "Side by side. Everyone shoots forward, but the flanks are weak."],
	"echelon_right": ["Echelon R", "guard right", "A diagonal back to the right. Protects the right flank."],
	"echelon_left": ["Echelon L", "guard left", "A diagonal back to the left. Protects the left flank."],
	"coil": ["Coil", "halt, all-round", "A ring facing outward. Stopped and watching every direction."],
}
## [name, description].
const DRILL_INFO := {
	"move": ["Move", "Travel together in formation, shooting back."],
	"bound": ["Bound", "Half the squad covers while the other half moves up, then they swap."],
	"hold": ["Hold", "Stop where you are and fight from position."],
	"assault": ["Assault", "Charge the spot. Every vehicle hunts."],
	"break_contact": ["Break contact", "Back away toward base, front armor to the enemy."],
}
## Short order states for the squad bar (≤ 8 letters, so they fit a phone chip beside the name).
const ORDER_STATE := {"move": "Moving", "bound": "Bounding", "hold": "Holding", "assault": "Charging",
		"break_contact": "Retreat", "": "Idle"}


## What a vehicle is doing, in player words, from its brain's option (TankBrain.OPTIONS; unknown options are
## shown capitalized, so the AI stream can add options freely).
const INTENT_WORDS := {"RETREAT": "Retreating", "RESUPPLY": "Resupplying", "TAKE_COVER": "Taking cover",
		"RECHARGE": "Recharging shields", "SPOT": "Spotting", "BOMBARD": "Bombarding", "SHADOW": "Shadowing",
		"CONTEST": "Taking the center", "CLEAR_LANE": "Moving for a clear shot", "COVER_FIRE": "Peeking from cover",
		"SUPPRESS": "Keeping their heads down",
		"ORBIT": "Circling", "ENGAGE": "Engaging", "FLANK": "Flanking", "INVESTIGATE": "Investigating",
		"REGROUP": "Regrouping", "ADVANCE": "Advancing", "KEEP_SLOT": "In formation", "HOLD": "Holding"}


static func intent_words(intent: String) -> String:
	if intent == "":
		return "Idle"
	var option := intent.get_slice(" ", 0)
	return String(INTENT_WORDS.get(option, option.replace("_", " ").capitalize()))


## The unit's role for icons: catalog v2's `role` (contract C1) when present; v1's `class`, with a laser
## tank shown as a lancer, until rules' catalog v2 lands.
static func role_of(tank: Tank) -> String:
	var profile: Dictionary = Units.PROFILES.get(tank.unit_id, {})
	if profile.has("role"):
		return String(profile["role"])
	var role := String(profile.get("class", tank.unit_id))
	if role == "tank" and tank.weapon_id == "laser":
		return "lancer"
	return role


## Unit pictograms drawn once into textures (X4): IconRaster paints draw_unit at UNIT_TEXTURE_PX, the glyph filling
## UNIT_TEXTURE_GLYPH of it, in white with dark ink, so a tint colours the body and leaves the ink dark.
const UNIT_TEXTURE_PX := 64
const UNIT_TEXTURE_GLYPH := 50.0
static var _unit_textures := {}


static func unit_texture(role: String) -> Texture2D:
	if not _unit_textures.has(role):
		var raster := IconRaster.new(UNIT_TEXTURE_PX)
		draw_unit(raster, role, Vector2.ONE * UNIT_TEXTURE_PX / 2.0, UNIT_TEXTURE_GLYPH, Color.WHITE)
		_unit_textures[role] = raster.texture()
	return _unit_textures[role]


## draw_unit for a HUD widget: the cached texture as one rect, which the renderer batches with every other icon.
## Pointing up the screen only (no heading), at `size` px tall like draw_unit.
static func draw_unit_icon(canvas: CanvasItem, role: String, at: Vector2, size: float, color: Color) -> void:
	if not (_drawable(at) and size >= 1.0):
		return
	var side := size * UNIT_TEXTURE_PX / UNIT_TEXTURE_GLYPH
	canvas.draw_texture_rect(unit_texture(role), Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false, color)


## A unit pictogram (top-down silhouette) centered at `at`, `size` px tall, pointing along `heading`
## (radians, 0 = up the screen, positive = clockwise).
static func draw_unit(canvas: Object, role: String, at: Vector2, size: float, color: Color, heading := 0.0,
		outline := Color(0, 0, 0, 0.75)) -> void:
	# A camera that isn't set up yet (headless runs, the first frame after a mode switch) unprojects to NaN, and a
	# degenerate polygon makes the renderer log a triangulation error: draw nothing instead.
	if not (_drawable(at) and is_finite(heading) and size >= 1.0):
		return
	var s := size / 2.0
	var xf := Transform2D(heading, at)
	var body: PackedVector2Array
	match role:
		"scout":
			# A dart: fast, fixed gun forward.
			body = _pts([Vector2(0, -1.0), Vector2(0.55, 0.85), Vector2(0, 0.5), Vector2(-0.55, 0.85)], s, xf)
		"ifv":
			body = _pts([Vector2(-0.5, -0.75), Vector2(0.5, -0.75), Vector2(0.5, 0.9), Vector2(-0.5, 0.9)], s, xf)
		"artillery":
			body = _pts([Vector2(-0.5, -0.35), Vector2(0.5, -0.35), Vector2(0.5, 0.95), Vector2(-0.5, 0.95)], s, xf)
		"lancer":
			body = _pts([Vector2(-0.42, -0.4), Vector2(0.42, -0.4), Vector2(0.5, 0.95), Vector2(-0.5, 0.95)], s, xf)
		_:
			body = _pts([Vector2(-0.55, -0.6), Vector2(0.55, -0.6), Vector2(0.55, 0.9), Vector2(-0.55, 0.9)], s, xf)
	var closed := body.duplicate()
	closed.append(body[0])
	if not _fill(canvas, body, color):
		return
	canvas.draw_polyline(closed, outline, maxf(1.0, size / 16.0))
	var ink := Color(0.02, 0.03, 0.05, 0.9)
	var w := maxf(1.5, size / 9.0)
	match role:
		"tank":
			# A big turret and a long gun.
			canvas.draw_line(xf * Vector2(0, 0.1 * s), xf * Vector2(0, -1.05 * s), color, w * 1.2)
			canvas.draw_circle(xf * Vector2(0, 0.15 * s), 0.34 * s, ink)
			canvas.draw_circle(xf * Vector2(0, 0.15 * s), 0.22 * s, color)
		"ifv":
			# A small turret and a short fast gun.
			canvas.draw_rect(Rect2(xf * Vector2(-0.22 * s, -0.1 * s), Vector2(0.44 * s, 0.44 * s)), ink)
			canvas.draw_line(xf * Vector2(0, -0.1 * s), xf * Vector2(0, -1.0 * s), ink, w * 0.8)
		"scout":
			canvas.draw_line(xf * Vector2(0, -0.2 * s), xf * Vector2(0, 0.45 * s), ink, w * 0.7)
		"artillery":
			# A lobbed arc over the hull.
			var arc := PackedVector2Array()
			for i in 9:
				var t := i / 8.0
				arc.append(xf * (Vector2(lerpf(-0.7, 0.7, t), -0.45 - 0.6 * sin(PI * t)) * s))
			canvas.draw_polyline(arc, color, w * 0.8)
			canvas.draw_circle(xf * Vector2(0, 0.35 * s), 0.18 * s, ink)
		"lancer":
			# A beam with a spark at the end.
			canvas.draw_line(xf * Vector2(0, 0.2 * s), xf * Vector2(0, -1.1 * s), color, w * 0.6)
			canvas.draw_circle(xf * Vector2(0, -1.05 * s), 0.16 * s, color)
			canvas.draw_circle(xf * Vector2(0, 0.35 * s), 0.18 * s, ink)
		_:
			canvas.draw_circle(xf * Vector2(0, 0.15 * s), 0.2 * s, ink)


## A hostile marker: a diamond (filled faintly, or hollow for a remembered contact). Friendly markers are round.
static func draw_hostile_frame(canvas: CanvasItem, at: Vector2, radius: float, color: Color, filled: bool) -> void:
	if not (_drawable(at) and radius >= 1.0):  # see draw_unit: degenerate polygons log engine errors
		return
	var diamond := PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius),
			at + Vector2(-radius, 0)])
	if filled:
		_fill(canvas, diamond, Color(0, 0, 0, 0.45))
	diamond.append(diamond[0])
	canvas.draw_polyline(diamond, color, 2.0)


## True for a screen position an icon can be drawn at.
static func _drawable(at: Vector2) -> bool:
	return at.is_finite()


## Draw a filled polygon only if the renderer can triangulate it. The engine logs "Invalid polygon data, triangulation
## failed" for shapes it can't triangulate, which fails tests and smoke runs. Measured on builder0 (2026-09-15): in about
## 1 of 3 headless army-loop runs a far-zoom icon for a unit near the camera plane lands 30k–100k px off screen, where a
## perfectly shaped 20 px quad fails triangulation on precision. The first skipped polygon is printed once.
static var _reported_degenerate := false
static func _fill(canvas: Object, polygon: PackedVector2Array, color: Color) -> bool:
	if _area(polygon) < 0.5 or Geometry2D.triangulate_polygon(polygon).is_empty():
		if not _reported_degenerate:
			_reported_degenerate = true
			print("COMMAND_ICONS_DEGENERATE_POLYGON %s" % [polygon])
		return false
	canvas.draw_colored_polygon(polygon, color)
	return true


## Absolute shoelace area in px² (0 for non-finite points): collinear or zero-area shapes draw nothing anyway, and
## Geometry2D.triangulate_polygon still returns indices for them.
static func _area(polygon: PackedVector2Array) -> float:
	var twice := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if not (a.is_finite() and b.is_finite()):
			return 0.0
		twice += a.x * b.y - b.x * a.y
	return absf(twice) * 0.5


static func _pts(points: Array, scale: float, xf: Transform2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(xf * ((p as Vector2) * scale))
	return result


## Where each vehicle stands in a formation icon, fitted into `rect` (leader first). Pure, for tests.
static func formation_points(formation: String, rect: Rect2, count := 4) -> PackedVector2Array:
	var offsets := Formations.offsets(formation, count, 1.0)
	var bounds := Rect2(offsets[0], Vector2.ZERO)
	for offset in offsets:
		bounds = bounds.expand(offset)
	var room := rect.size * 0.72
	var scale := minf(room.x / maxf(bounds.size.x, 0.001), room.y / maxf(bounds.size.y, 0.001))
	scale = minf(scale, rect.size.y * 0.3)  # a single file or a line must not blow up to one huge gap
	var result := PackedVector2Array()
	for offset in offsets:
		# Offsets are (right, back): back is down the screen when the squad travels up it.
		result.append(rect.get_center() + (offset - bounds.get_center()) * scale)
	return result


## A formation icon: the vehicles as small arrowheads where the real formation puts them.
static func draw_formation(canvas: CanvasItem, formation: String, rect: Rect2, color: Color,
		leader_color: Color, count := 4) -> void:
	var points := formation_points(formation, rect, count)
	var glyph := clampf(rect.size.y * 0.3, 8.0, 24.0)
	if formation == "coil":
		canvas.draw_arc(rect.get_center(), (points[0] - rect.get_center()).length(), 0.0, TAU, 24, Color(color, 0.35), 1.0)
	for i in points.size():
		var heading := 0.0
		if formation == "coil":
			heading = (points[i] - rect.get_center()).angle() + PI / 2.0  # everyone faces outward
		draw_unit(canvas, "scout", points[i], glyph, leader_color if i == 0 and formation != "coil" else color, heading)


## A drill icon.
static func draw_drill(canvas: CanvasItem, verb: String, rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y) * 0.46
	var w := maxf(2.5, s / 5.0)
	match verb:
		"move":
			for i in 3:
				canvas.draw_circle(c + Vector2(0, (0.75 - i * 0.45) * s), w * 0.7, color)
			_arrow(canvas, c + Vector2(0, -0.2 * s), c + Vector2(0, -1.0 * s), color, w, s * 0.35)
		"bound":
			# Two elements leapfrogging: one arrow ahead of the other.
			_arrow(canvas, c + Vector2(-0.45 * s, 0.9 * s), c + Vector2(-0.45 * s, -0.1 * s), color, w, s * 0.3)
			_arrow(canvas, c + Vector2(0.45 * s, 0.4 * s), c + Vector2(0.45 * s, -0.95 * s), color, w, s * 0.3)
		"hold":
			# Stopped at a line, facing forward.
			canvas.draw_line(c + Vector2(-0.9 * s, -0.55 * s), c + Vector2(0.9 * s, -0.55 * s), color, w * 1.3)
			draw_unit(canvas, "scout", c + Vector2(0, 0.25 * s), s * 0.95, color)
		"assault":
			# Arrows converging on a target.
			for side in [-1.0, 0.0, 1.0]:
				_arrow(canvas, c + Vector2(side * 0.9 * s, 0.9 * s), c + Vector2(side * 0.3 * s, -0.25 * s), color, w, s * 0.28)
			canvas.draw_arc(c + Vector2(0, -0.75 * s), 0.25 * s, 0.0, TAU, 16, color, w * 0.7)
		"break_contact":
			# Facing the enemy (up) while the arrow goes back.
			draw_unit(canvas, "scout", c + Vector2(0, -0.5 * s), s * 0.8, color)
			_arrow(canvas, c + Vector2(0, 0.0), c + Vector2(0, 1.0 * s), color, w, s * 0.3)
		_:
			canvas.draw_circle(c, s * 0.3, color)


static func _arrow(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float, head: float) -> void:
	if not (from.is_finite() and to.is_finite()) or from.distance_to(to) < 0.01 or head < 0.5:
		return  # a zero-length arrow has no direction: its head would be a degenerate triangle
	var direction := (to - from).normalized()
	canvas.draw_line(from, to - direction * head * 0.5, color, width)
	var side := Vector2(-direction.y, direction.x)
	_fill(canvas, PackedVector2Array([to, to - direction * head + side * head * 0.6,
			to - direction * head - side * head * 0.6]), color)
