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
	var eye := camera.global_position  # round 16: read once a draw, not once per tank
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
		_bar(camera.unproject_position(head), tank, scale_factor)


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
	var alpha := 1.0 if hurt else QUIET_ALPHA
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
