class_name UnitBars
extends Control
## Hull and SHIELD over every unit you can see, without clicking it.
##
## The lead, 2026-09-25, after twenty seconds of two scout squads on one Condemned IFV: *"the enemy unit is not dying,
## and if I click on it, it appears in full health"* … *"let's at least add indicators of shield health"*.
##
## The card already showed both numbers — but only for the ONE unit he clicked, and only while he kept it selected.
## In a fight that is the wrong shape of readout: the question "is my fire doing anything to that thing" is asked
## about a unit he is shooting, continuously, while he is looking at the battle rather than at a panel. Every unit
## in the game carries a shield that recharges (40-60 a second after 2.5-4 s of quiet), so "the health bar is not
## moving" has two completely different causes — the shield is eating it, or the shots are not arriving — and
## nothing on screen told them apart.
##
## So: a thin two-part bar above each visible hull. The lower part is hull, the upper is shield, and the shield part
## is only drawn when the unit HAS one. Fog is respected (`Match.is_visible_to`): this shows what he can see, never
## more. Full-health units with a full shield are drawn faintly so the screen is not a wall of bars; anything hurt,
## or with its shield down, is drawn bright — which makes "that one is taking damage" the thing that stands out.

## Bar size in pixels at 1080p, scaled by the viewport like the rest of the HUD.
const WIDTH := 34.0
const HULL_H := 3.5
const SHIELD_H := 2.5
const GAP := 1.0
## How far above the hull's top the bar floats, in metres.
const LIFT_M := 1.2
## Bars fade out past this distance (m) so a big map does not turn into confetti.
const FAR_M := 220.0
## Untouched units (full hull, full shield) are drawn at this alpha; anything hurt is drawn solid.
const QUIET_ALPHA := 0.35

var controls: RtsControls
var game_match: Match
## Set false to hide the bars (a screenshot, a cinematic).
var shown := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = -1  # under the panels and markers, over the world
	if controls != null:
		controls.unit_bars = self  # round 16: the controls' older per-unit bar stands down where these run


func _process(_delta: float) -> void:
	var started := HudClock.begin()
	_process_timed(_delta)
	HudClock.end(&"unit_bars.process", started)


func _process_timed(_delta: float) -> void:
	if shown and visible:
		queue_redraw()


func _draw() -> void:
	var started := HudClock.begin()
	_draw_timed()
	HudClock.end(&"unit_bars.draw", started)


func _draw_timed() -> void:
	if not shown or controls == null or game_match == null or controls.camera == null:
		return
	if game_match.tanks == null:
		return
	var scale_factor := clampf(float(get_viewport_rect().size.y) / 1080.0, 0.6, 2.0)
	var team: int = controls.team
	var camera := controls.camera
	var fx := FxWorld.existing()
	feedback = fx.feedback if fx != null else null
	_now = fx.now if fx != null else 0.0
	feedback_drawn.clear()
	var eye := camera.global_position  # round 16: read once a draw, not once per tank
	if record:
		last_drawn = []
	# Round 18 (picker): the selection as a set keyed by the node names, built once a draw, so a bar's "selected?" is one
	# lookup instead of a String conversion and a search of the selection array (round 17 measured this line at 146 us,
	# round 18 at 185 after the selected-bar rule landed; same picture).
	_selected.clear()
	for unit_name: String in controls.selection.units:
		_selected[StringName(unit_name)] = true
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		if not game_match.is_visible_to(team, tank):
			continue  # never draw a bar over something the fog is hiding
		var head := tank.global_position + Vector3.UP * (_top_of(tank) + LIFT_M)
		if camera.is_position_behind(head):
			continue
		var distance := eye.distance_to(tank.global_position)
		if distance > FAR_M:
			continue
		var at := camera.unproject_position(head)
		_bar(at, tank, scale_factor)
		if feedback != null:
			_feedback(at, head, tank, scale_factor, camera)


## The drawn top of the hull, so the bar floats over the vehicle rather than through it.
func _top_of(tank: Tank) -> float:
	var known: Variant = _tops.get(tank.unit_id)
	if known == null:
		# The catalogue's hull_size is [w, h, l]. Until round 16 this read it as a Vector3, never matched, and floated
		# every bar at 2.0 m: inside the 14 m rig (5.24 m tall), high over a 1.24 m scout (a defect fix, the
		# orchestrator's call).
		var size: Variant = Units.stat(String(tank.unit_id), "hull_size", [])
		known = float(size[1]) if size is Array and (size as Array).size() == 3 else 2.0
		_tops[tank.unit_id] = known
	return known


## unit id → _top_of (round 16, hud H4: Units.stat formats a key per call, and this ran per bar per frame).
var _tops := {}
## Round 18 (picker): when true, each draw records what it drew in `last_drawn` ([name, screen point, hull, shield,
## alpha] per bar) for `make hud-digest`. Off in play.
static var record := false
var last_drawn: Array = []
var _selected := {}  # StringName -> true: this draw's selection
## Round 37 (feedback): the world half of the rules made visible; this draws their screen half over the bar.
var feedback: FeedbackFx
var _now := 0.0
## What the feedback looks drew this draw: [name, what] per mark (tests).
var feedback_drawn: Array = []


func _bar(at: Vector2, tank: Tank, s: float) -> void:
	var width := WIDTH * s
	var hull_h := HULL_H * s
	var shield_h := SHIELD_H * s
	var hull := clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
	var has_shield: bool = tank.max_shield > 0.0
	var shield := clampf(tank.shield / maxf(tank.max_shield, 1.0), 0.0, 1.0) if has_shield else 0.0
	# Quiet until something is wrong: a full unit is a hint, a hurt one is a readout. This is what keeps thirty
	# vehicles from becoming thirty flashing bars while still making the one being shot obvious.
	var hurt: bool = hull < 0.999 or (has_shield and shield < 0.999)
	var alpha := 1.0 if hurt or _selected.has(tank.name) else QUIET_ALPHA  # _alpha_of's rule, from values in hand
	if record:
		last_drawn.append([String(tank.name), at, hull, shield, alpha])
	var friendly: bool = tank.team == controls.team
	var top_left := at - Vector2(width * 0.5, (hull_h + (shield_h + GAP * s if has_shield else 0.0)) * 0.5)
	if has_shield:
		var shield_rect := Rect2(top_left, Vector2(width, shield_h))
		draw_rect(shield_rect, Color(0.0, 0.0, 0.0, 0.5 * alpha))
		# Cyan for the shield, which is the whole point of the addition: when this empties and the hull below it
		# starts dropping, the fire is getting through; when it keeps refilling, it is not.
		draw_rect(Rect2(shield_rect.position, Vector2(width * shield, shield_h)),
				Color(0.55, 0.85, 1.0, alpha))
		top_left.y += shield_h + GAP * s
	var hull_rect := Rect2(top_left, Vector2(width, hull_h))
	draw_rect(hull_rect, Color(0.0, 0.0, 0.0, 0.5 * alpha))
	var full := Color(0.45, 0.85, 0.5) if friendly else Color(0.9, 0.45, 0.4)
	var low := Color(0.9, 0.3, 0.25)
	draw_rect(Rect2(hull_rect.position, Vector2(width * hull, hull_h)),
			Color(full.lerp(low, 1.0 - hull), alpha))


## Quiet until something is wrong: hurt (hull, or a shield that is down) draws solid. Round 16 (the orchestrator's
## call): a SELECTED unit's bar is drawn solid too, so the selection reads its own health at a glance (round 3's design,
## carried by the controls' own bar until it stood down where these run).
func _alpha_of(tank: Tank) -> float:
	var hull := clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
	var has_shield: bool = tank.max_shield > 0.0
	var shield := clampf(tank.shield / maxf(tank.max_shield, 1.0), 0.0, 1.0) if has_shield else 0.0
	var hurt: bool = hull < 0.999 or (has_shield and shield < 0.999)
	var selected: bool = controls != null and controls.selection.units.has(String(tank.name))
	return 1.0 if hurt or selected else QUIET_ALPHA


# ---- Round 37 (feedback, C37.6): the rules made visible over the bar -----------------------------------------------

const PIN_COLOR := Color(1.0, 0.86, 0.25)
const MEND_COLOR := Color(0.35, 1.0, 0.55)
const HIT_LABELS := {"side": "FLANK", "rear": "REAR", "deck": "ENGINE"}


func _feedback(at: Vector2, head: Vector3, tank: Tank, s: float, camera: Camera3D) -> void:
	var width := WIDTH * s
	var height := (HULL_H + (SHIELD_H + GAP if tank.max_shield > 0.0 else 0.0)) * s
	var level := feedback.pinned_of(tank.name)
	if level > 0.0:
		var pulse := 0.65 + 0.35 * sin(_now * 6.0)
		if FeedbackLook.has("pinned", "a"):
			# Heads down: one to three chevrons pointing at the hull, over the bar.
			var count := 1 + int(level > 0.45) + int(level > 0.9)
			for i in count:
				var y := at.y - height * 0.5 - (7.0 + i * 9.0) * s
				var half := 11.0 * s
				var chevron := PackedVector2Array([Vector2(at.x - half, y - 7.0 * s), Vector2(at.x, y), Vector2(at.x + half, y - 7.0 * s)])
				draw_polyline(chevron, Color(0.0, 0.0, 0.0, 0.6 * pulse), 6.5 * s, true)
				draw_polyline(chevron, Color(PIN_COLOR, pulse), 4.0 * s, true)
			feedback_drawn.append([String(tank.name), "pinned:a"])
		if FeedbackLook.has("pinned", "c"):
			var rect := Rect2(at - Vector2(width * 0.5 + 2.0 * s, height * 0.5 + 2.0 * s), Vector2(width + 4.0 * s, height + 4.0 * s))
			draw_rect(rect, Color(PIN_COLOR, pulse), false, 1.5 * s)
			_text("PINNED", at + Vector2(0.0, height * 0.5 + 20.0 * s), PIN_COLOR, 19.0 * s)
			feedback_drawn.append([String(tank.name), "pinned:c"])
	var link := feedback.mending_of(tank.name)
	if not link.is_empty() and FeedbackLook.has("repair", "c"):
		var hull := clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
		var bottom := at.y + height * 0.5
		var edge := at.x - width * 0.5 + width * hull
		var sheen := fmod(_now * 1.5, 1.0)
		draw_rect(Rect2(Vector2(edge - 4.0 * s, bottom - HULL_H * s), Vector2(4.0 * s, HULL_H * s)), Color(MEND_COLOR, 0.6 + 0.4 * sheen))
		_text("+%d/s" % roundi(float(link["rate"])), Vector2(at.x + width * 0.5 + 20.0 * s, bottom + 2.0 * s), MEND_COLOR, 21.0 * s)
		feedback_drawn.append([String(tank.name), "repair:c"])
	if FeedbackLook.has("hit", "b"):
		var hit := feedback.recent_hit(String(tank.name), _now)
		if not hit.is_empty() and String(hit["kind"]) != "front":
			var age := (_now - float(hit["time"])) / FeedbackFx.HIT_MEMORY_S
			var color: Color = FeedbackFx.FACE_COLORS[String(hit["kind"])]
			color.a = 1.0 - age * age
			# A wedge beside the bar on the side the shot came from, pointing in at the hull.
			var toward: Vector3 = hit["toward"]
			var side := camera.unproject_position(head + toward * 4.0) - at
			side = side.normalized() if side.length() > 0.5 else Vector2.LEFT
			var tip := at + side * (width * 0.5 + 6.0 * s)
			var back := tip + side * 16.0 * s
			var across := Vector2(-side.y, side.x) * 9.0 * s
			draw_colored_polygon(PackedVector2Array([tip, back + across, back - across]), color)
			_text(String(HIT_LABELS[String(hit["kind"])]), at + Vector2(0.0, -height * 0.5 - (10.0 + age * 12.0) * s), color, 19.0 * s)
			feedback_drawn.append([String(tank.name), "hit:b:" + String(hit["kind"])])


func _text(text: String, centre: Vector2, color: Color, size: float) -> void:
	var font := CyberStyle.font()
	var pixels := maxi(8, roundi(size))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string_outline(font, centre - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, 3,
			Color(0.0, 0.0, 0.0, color.a * 0.8))
	draw_string(font, centre - Vector2(width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)
