class_name SquadChip
extends Button
## C2: one squad in the squad bar. A Button (so the theme's cyber style and tap handling apply) that
## draws live squad data over itself:
##   row 1   NAME                                  order state ("Moving", "Holding", "Destroyed")
##   row 2   one unit-type pictogram per vehicle (lost vehicles fade out with a cross)
##   row 3   hull bar with the shield as a thin bar above it; a red contact pip when under fire or an enemy is in sight
## Tap handling lives in TacticalMap (tap selects; tapping the selected chip frames and follows it).

## A squad counts as in contact for this long after a hit (3 s).
const CONTACT_TICKS := 180

var squad: Squad
var game_match: Match
## Shown in the top-left corner as a desktop hint ("1"), or "" on touch screens.
var hotkey := ""


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	clip_text = true


func _process(_delta: float) -> void:
	queue_redraw()


## A summary of the squad for drawing and tests:
## {roles: [String], alive: [bool], health: 0..1, shield: 0..1, state: String, contact: bool, lost: bool}
func summary() -> Dictionary:
	var result := {"roles": [], "alive": [], "health": 0.0, "shield": 0.0, "state": "", "contact": false, "lost": false}
	if squad == null or game_match == null:
		return result
	var by_name := game_match.tanks_by_name()
	var health := 0.0
	var max_health := 0.0
	var shield := 0.0
	var max_shield := 0.0
	var any_alive := false
	var sighted: Array = []
	var intel: Dictionary = game_match.intel[squad.team]
	for contact_name in intel:
		if intel[contact_name]["visible"]:
			sighted.append(intel[contact_name]["position"])
	for member in squad.roster:
		var tank := by_name.get(member) as Tank
		if tank == null:
			continue
		var alive := tank.is_alive()
		(result["roles"] as Array).append(CommandIcons.role_of(tank))
		(result["alive"] as Array).append(alive)
		max_health += tank.max_health
		max_shield += tank.max_shield
		if alive:
			any_alive = true
			health += tank.sync_health
			shield += tank.sync_shield
			# In contact: hit in the last CONTACT_TICKS, or an enemy in sight within this vehicle's sight radius.
			if tank.ticks_since_hit < CONTACT_TICKS:
				result["contact"] = true
			for at in sighted:
				if (at as Vector3).distance_to(tank.global_position) <= tank.sight_radius:
					result["contact"] = true
	result["health"] = health / max_health if max_health > 0.0 else 0.0
	result["shield"] = shield / max_shield if max_shield > 0.0 else 0.0
	result["lost"] = not any_alive
	if not any_alive:
		result["state"] = "Destroyed"
	elif squad.verb in ["move", "bound", "assault", "break_contact"] and squad.arrived:
		result["state"] = "Arrived"
	else:
		result["state"] = CommandIcons.ORDER_STATE.get(squad.verb, squad.verb.capitalize())
	return result


func _draw() -> void:
	if squad == null:
		return
	var info := summary()
	var ui := GameTheme.ui
	var friendly: Color = ui["friendly"]
	var enemy: Color = ui["enemy"]
	var font := get_theme_font("font")
	var h := size.y
	var pad := h * 0.1
	var ink := Color(1, 1, 1, 0.35) if info["lost"] else Color.WHITE
	var name_size := roundi(clampf(h * 0.26, 11.0, 20.0))
	var small_size := roundi(clampf(h * 0.19, 9.0, 15.0))
	var baseline := pad + name_size * 0.9
	var name_x := pad
	if hotkey != "":
		draw_string(font, Vector2(pad, baseline), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, Color(1, 1, 1, 0.45))
		name_x += small_size * 0.9
	var name_text := squad.squad_name.to_upper()
	var name_width := minf(font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x, size.x * 0.6)
	draw_string(font, Vector2(name_x, baseline), name_text, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, name_size, ink)
	# The state takes what's left of the row, shrinking its font rather than overlapping the name.
	var state := String(info["state"])
	var room := size.x - pad - (name_x + name_width + pad * 0.6)
	var state_size := small_size
	while state_size > 8 and font.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, state_size).x > room:
		state_size -= 1
	var state_color := Color(1, 1, 1, 0.7) if not info["lost"] else Color(enemy, 0.8)
	draw_string(font, Vector2(size.x - pad - room, baseline), state, HORIZONTAL_ALIGNMENT_RIGHT, room, state_size, state_color)
	# Units: one pictogram each.
	var roles: Array = info["roles"]
	var glyph := clampf(h * 0.3, 8.0, 22.0)
	var step := minf(glyph * 1.15, (size.x * 0.8 - 2.0 * pad) / maxf(roles.size(), 1))
	var row_y := h * 0.55
	for i in roles.size():
		var at := Vector2(pad + glyph * 0.5 + i * step, row_y)
		if info["alive"][i]:
			CommandIcons.draw_unit(self, roles[i], at, glyph, friendly)
		else:
			CommandIcons.draw_unit(self, roles[i], at, glyph, Color(friendly, 0.18), 0.0, Color(0, 0, 0, 0.2))
			draw_line(at + Vector2(-glyph, -glyph) * 0.35, at + Vector2(glyph, glyph) * 0.35, Color(enemy, 0.8), 1.5)
			draw_line(at + Vector2(-glyph, glyph) * 0.35, at + Vector2(glyph, -glyph) * 0.35, Color(enemy, 0.8), 1.5)
	if info["contact"]:
		var pip := Vector2(size.x - pad - glyph * 0.3, row_y)
		draw_circle(pip, glyph * 0.28, enemy)
	# Hull and shield bars.
	var bar := Rect2(pad, h - pad - h * 0.09, size.x - 2.0 * pad, h * 0.09)
	draw_rect(bar, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(info["health"]), bar.size.y)), friendly.lerp(enemy, 1.0 - float(info["health"])) if float(info["health"]) < 0.5 else friendly)
	var shield_bar := Rect2(bar.position - Vector2(0, bar.size.y * 0.7), Vector2(bar.size.x * float(info["shield"]), bar.size.y * 0.45))
	draw_rect(shield_bar, Color(0.75, 0.9, 1.0, 0.85))
