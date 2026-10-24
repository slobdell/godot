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
			_feedback(at, tank, scale_factor)
			_rule_looks(tank, camera, scale_factor)


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


## His pick "pinned A": heads down, one to three chevrons pointing at the hull over the bar, by how pinned the crew is.
func chevrons_for(tank: Tank) -> int:
	var level := feedback.pinned_of(tank.name) if feedback != null and FeedbackLook.on("pinned") else 0.0
	var count := 0 if level <= 0.0 else 1 + int(level > 0.45) + int(level > 0.9)
	# Round 39 candidate "slowed: amber": a crew R3 is slowing shows at least one chevron, from the first slow.
	if count == 0 and FeedbackLook.rule("slowed") == "amber" and FeedbackLook.on("pinned") \
			and FeedbackReader.slowed(tank) * Tank.PIN_SLOW_MAX >= AMBER_FROM:
		count = 1
	return count


func _feedback(at: Vector2, tank: Tank, s: float) -> void:
	var count := chevrons_for(tank)
	if count == 0:
		return
	var height := (HULL_H + (SHIELD_H + GAP if tank.max_shield > 0.0 else 0.0)) * s
	var pulse := 0.65 + 0.35 * sin(_now * 6.0)
	var color := PIN_COLOR
	if FeedbackLook.rule("slowed") == "amber":
		# Yellow at the first slow, orange at R3's full ~40 %.
		color = PIN_COLOR.lerp(SLOW_COLOR, clampf(FeedbackReader.slowed(tank), 0.0, 1.0))
	for i in count:
		var y := at.y - height * 0.5 - (7.0 + i * 9.0) * s
		var half := 11.0 * s
		var chevron := PackedVector2Array([Vector2(at.x - half, y - 7.0 * s), Vector2(at.x, y), Vector2(at.x + half, y - 7.0 * s)])
		draw_polyline(chevron, Color(0.0, 0.0, 0.0, 0.6 * pulse), 6.5 * s, true)
		draw_polyline(chevron, Color(color, pulse), 4.0 * s, true)


# ---- Round 39 (feedback F1, C39.5): candidate looks for R1-R3, for his directions page (FeedbackLook.rule) -------------

## "slowed: amber": a chevron from this much of the crew's speed gone (5 %), turning SLOW_COLOR at R3's full slow.
const AMBER_FROM := 0.05
const SLOW_COLOR := Color(1.0, 0.45, 0.1)
## "slowed: brake": the lights show from this much slow on a hull still rolling (m/s).
const BRAKE_FROM := 0.05
const BRAKE_MIN_SPEED := 1.0
const BRAKE_COLOR := Color(1.0, 0.12, 0.08)
## "fire: wedge": drawn this long (m) and this many spreads wide (a spread is one sigma of the shot's scatter).
const WEDGE_M := 28.0
const WEDGE_SIGMAS := 2.0
const WEDGE_COLOR := Color(1.0, 0.62, 0.15)
## "sight: ring": the selected crews' sight circle, dashed.
const RING_SEGMENTS := 72
const RING_COLOR := Color(0.55, 0.9, 1.0)


func _rule_looks(tank: Tank, camera: Camera3D, s: float) -> void:
	var friendly: bool = tank.team == controls.team
	if FeedbackLook.rule("sight") == "ring" and friendly and _selected.has(tank.name):
		_sight_ring(tank, camera, s)
	if FeedbackLook.rule("fire") == "wedge":
		var shot := feedback.moving_shot_of(tank.name, _now)
		if not shot.is_empty():
			_wedge(shot, camera, s)
	if FeedbackLook.rule("slowed") == "brake":
		var slow := FeedbackReader.slowed(tank) * Tank.PIN_SLOW_MAX
		if slow >= BRAKE_FROM and absf(tank.speed()) >= BRAKE_MIN_SPEED:
			_brake_lights(tank, camera, s, clampf(slow / Tank.PIN_SLOW_MAX, 0.0, 1.0))


## The crew's sight as it is NOW (R1: shrinks driving, grows settled), dashed on the ground round it.
func _sight_ring(tank: Tank, camera: Camera3D, s: float) -> void:
	var centre := tank.global_position + Vector3.UP * 0.15
	var radius := tank.sight_radius
	for i in range(0, RING_SEGMENTS, 2):
		var a := centre + Vector3(cos(TAU * i / RING_SEGMENTS), 0.0, sin(TAU * i / RING_SEGMENTS)) * radius
		var b := centre + Vector3(cos(TAU * (i + 1) / RING_SEGMENTS), 0.0, sin(TAU * (i + 1) / RING_SEGMENTS)) * radius
		if camera.is_position_behind(a) or camera.is_position_behind(b):
			continue
		draw_line(camera.unproject_position(a), camera.unproject_position(b), Color(RING_COLOR, 0.55), 2.0 * s, true)


## This round's spread (fired on the move) as a fading wedge from the muzzle, the same gun's stopped spread inside it.
func _wedge(shot: Dictionary, camera: Camera3D, s: float) -> void:
	var muzzle: Vector3 = shot["muzzle"]
	var direction: Vector3 = (shot["direction"] as Vector3)
	direction.y = 0.0
	if direction.length() < 0.01 or camera.is_position_behind(muzzle):
		return
	direction = direction.normalized()
	var fade := 1.0 - float(shot["age"])
	for pair: Array in [[float(shot["spread"]), 0.22], [float(shot["still"]), 0.0]]:
		var half := minf(float(pair[0]) * WEDGE_SIGMAS, 0.6)
		var left := muzzle + direction.rotated(Vector3.UP, half) * WEDGE_M
		var right := muzzle + direction.rotated(Vector3.UP, -half) * WEDGE_M
		if camera.is_position_behind(left) or camera.is_position_behind(right):
			return
		var points := PackedVector2Array([camera.unproject_position(muzzle), camera.unproject_position(left),
				camera.unproject_position(right)])
		if float(pair[1]) > 0.0:
			draw_colored_polygon(points, Color(WEDGE_COLOR, float(pair[1]) * fade))
			draw_polyline(PackedVector2Array([points[1], points[0], points[2]]), Color(WEDGE_COLOR, 0.8 * fade), 1.5 * s, true)
		else:
			draw_polyline(PackedVector2Array([points[1], points[0], points[2]]), Color(1, 1, 1, 0.7 * fade), 1.0 * s, true)


## Two red lights at the hull's rear corners while R3 is slowing a rolling crew, brighter as it slows more.
func _brake_lights(tank: Tank, camera: Camera3D, s: float, strength: float) -> void:
	var size: Variant = Units.stat(String(tank.unit_id), "hull_size", [])
	var hull := Vector3(float(size[0]), float(size[1]), float(size[2])) if size is Array and (size as Array).size() == 3 \
			else Vector3(2.4, 2.0, 5.0)
	var basis := tank.global_basis
	for side: float in [-1.0, 1.0]:
		var light := tank.global_position + basis.z * hull.z * 0.5 + basis.x * side * hull.x * 0.36 + Vector3.UP * hull.y * 0.45
		if camera.is_position_behind(light):
			continue
		var at := camera.unproject_position(light)
		draw_circle(at, 5.5 * s, Color(BRAKE_COLOR, 0.25 * strength))
		draw_circle(at, 2.6 * s, Color(BRAKE_COLOR.lightened(0.3), 0.55 + 0.45 * strength))
