class_name TwoSquadsPlaytest
extends ControlPlaytest
## Round 19 (orders, O1): the lead's two-squad move, played like him in a real skirmish. *"I selected 2 squads and right
## clicked a point on the map - the resultant indicator dots for all the units was all over the map, and a bunch of
## vehicles just basically ran off to the middle of the map."* Launched by ControlPlaytest when the command line carries
## --two-squads (`make two-squads-playtest`, frames with `make two-squads-shots`).
##
## Squads 1 and 2 are sent to opposite flanks of their base and left to settle; then both are ordered to one point
## TWO_SQUADS_AHEAD_M in front of them, in each of the two ways he can have selected them:
##   selected  both squads selected together (a box, or shift-clicks): the selection is no control group
##   grouped   one control group holding exactly both squads (Ctrl+N over both, then N; or Shift+N, which ADDS the
##             selection to group N)
## For every vehicle it logs the goal its order holds, the slot it will stand in, where it is after 5 s and after
## SETTLE_S, and how its first 5 s went: how much farther from the click it got (heading away) and how far it ran
## toward the middle between the two flanks beyond where it is meant to stand. TWO_SQUADS lines, two_squads.json, and
## TWO_SQUADS_DONE ok=<bool> (exit 1 when a check failed).

const FLANK_M := 55.0
const AHEAD_M := 60.0
const SAMPLE_S := 0.25
const FIRST_S := 5.0
const SETTLE_S := 25.0
## A vehicle's first 5 s may take it no farther from the click than this (its spacing: it is finding its seat).
const AWAY_M := 14.0

var _cases := {}


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_can_capture = DisplayServer.get_name() != "headless"
	if not _can_capture:
		get_tree().root.size = Vector2i(1280, 720)  # headless roots are 64×64 (trip-up 31)
	var tree := get_tree()
	await tree.create_timer(1.0).timeout
	var one := _alive(controls.groups.members(1))
	var two := _alive(controls.groups.members(2))
	if one.is_empty() or two.is_empty() or controls.elements == null:
		print("TWO_SQUADS_DONE ok=false dir=%s (needs squads 1 and 2 and elements)" % out_dir)
		tree.quit(1)
		return
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	var base := _middle(one + two)
	var click := Orders.clamp_to_arena(base + forward * AHEAD_M)
	_step("two_squads_setup", {"one": one, "two": two, "base": _xz(base), "click": _xz(click),
			"arena": String(Arena.active.get("name", ""))})

	await _to_flanks(base, right)
	await _capture("1_flanks_selected")
	controls.selection.set_units(one + two)  # what a box round both, or shift-clicks, leaves selected
	await tree.process_frame
	_cases["selected"] = await _order_both(click, base, right, one, two, "selected")

	await _to_flanks(base, right)
	var number := 0
	for candidate in range(ControlGroups.COUNT, 0, -1):
		if controls.groups.is_empty(candidate):
			number = candidate
	controls.selection.set_units(one + two)
	await _key((KEY_0 + number) as Key, false, true)  # Ctrl+N over both squads
	await _key((KEY_0 + number) as Key)               # N: the group holding both
	_cases["grouped"] = await _order_both(click, base, right, one, two, "grouped")

	var file := FileAccess.open(out_dir.path_join("two_squads.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": _cases, "click": _xz(click), "base": _xz(base)}, "  "))
	file.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("TWO_SQUADS ", JSON.stringify({"checks": _checks}))
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


## Squad 1 to the left flank of the base and squad 2 to the right, each as its own task, then wait for them to stand.
func _to_flanks(base: Vector3, right: Vector3) -> void:
	for entry: Array in [[1, -1.0], [2, 1.0]]:
		controls.recall_group(int(entry[0]))
		var spot := Orders.clamp_to_arena(base + right * FLANK_M * float(entry[1]))
		controls.order_selection("move", {"to": [spot.x, spot.z]})
	var waited := 0.0
	while waited < SETTLE_S:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		var moving := false
		for unit_name in _alive(controls.groups.members(1) + controls.groups.members(2)):
			if _tank(unit_name).estimated_velocity.length() > 0.8:
				moving = true
		if not moving and waited >= 4.0:
			break
	controls.selection.clear()
	await get_tree().process_frame


func _order_both(click: Vector3, base: Vector3, right: Vector3, one: Array[String], two: Array[String], label: String) -> Dictionary:
	var tree := get_tree()
	var units := _alive(one + two)
	var start := {}
	for unit_name in units:
		start[unit_name] = _flat(_tank(unit_name).global_position)
	var group_before := controls.selected_group()
	# Frame the click the way he would (the camera on it), then right-click it on the ground. If the point is still not
	# under the pointer (the HUD over it, or off screen) the radar's right-click gives the same order.
	if controls.rig != null:
		controls.rig.focus_on(click)
		await tree.create_timer(1.2).timeout
	var at := _screen(click)
	var under: Variant = controls.screen_to_world(at)
	var by := "right_click"
	if under is Vector3 and _flat(under).distance_to(click) < 3.0 and get_viewport().get_visible_rect().has_point(at):
		await _right_click(at)
	else:
		by = "radar"
		controls.world_order(click)
	_step("two_squads_order", {"case": label, "by": by, "selected": controls.selection.units.size()})
	await tree.physics_frame
	await tree.physics_frame
	await _capture("2_%s_ordered" % label)
	var samples := {}
	for unit_name in units:
		samples[unit_name] = [start[unit_name]]
	var goals_first := {}
	var t := 0.0
	while t < FIRST_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		for unit_name in units:
			(samples[unit_name] as Array).append(_flat(_tank(unit_name).global_position))
		if goals_first.is_empty():
			for unit_name in units:
				goals_first[unit_name] = _goal(unit_name)
	await _capture("3_%s_5s" % label)
	var waited := FIRST_S
	while waited < SETTLE_S:
		await tree.create_timer(1.0).timeout
		waited += 1.0
	await _capture("4_%s_settled" % label)
	var rows: Array = []
	var worst_away := 0.0
	var worst_middle := 0.0
	var farthest_goal := 0.0
	var moved := 0
	for unit_name in units:
		var path: Array = samples[unit_name]
		var s0: Vector3 = path[0]
		var away := 0.0
		var lateral_min := absf((s0 - base).dot(right))
		for p: Vector3 in path:
			away = maxf(away, p.distance_to(click) - s0.distance_to(click))
			lateral_min = minf(lateral_min, absf((p - base).dot(right)))
		var end := _flat(_tank(unit_name).global_position)
		if end.distance_to(s0) > 10.0:
			moved += 1
		var slot: Variant = _slot(unit_name)
		var goal: Variant = goals_first.get(unit_name)
		var meant: Vector3 = slot if slot is Vector3 else end
		# How far it ran toward the middle (between the flanks) past the line it is meant to stand on.
		var middle := maxf(absf((meant - base).dot(right)) - lateral_min, 0.0)
		var row := {"unit": unit_name, "squad": 1 if one.has(unit_name) else 2, "start": _xz(s0),
				"goal": _xz(goal) if goal is Vector3 else null,
				"goal_to_click": snappedf((goal as Vector3).distance_to(click), 0.1) if goal is Vector3 else -1.0,
				"slot": _xz(slot) if slot is Vector3 else null,
				"slot_to_click": snappedf((slot as Vector3).distance_to(click), 0.1) if slot is Vector3 else -1.0,
				"at_5s": _xz(path[path.size() - 1]), "end": _xz(end), "end_to_click": snappedf(end.distance_to(click), 0.1),
				"away_5s": snappedf(away, 0.1), "to_middle_5s": snappedf(middle, 0.1)}
		rows.append(row)
		worst_away = maxf(worst_away, away)
		worst_middle = maxf(worst_middle, middle)
		var reach: Variant = slot if slot is Vector3 else goal
		if reach is Vector3:
			farthest_goal = maxf(farthest_goal, (reach as Vector3).distance_to(click))
		print("TWO_SQUADS %s %s" % [label, JSON.stringify(row)])
	var elements := []
	for unit_name in units:
		var element := controls.elements.of(unit_name)
		if element != null and not elements.has(element):
			elements.append(element)
	var squads_kept := elements.size() == 2 and elements.all(func(e: Element) -> bool: return e.members().size() <= Formations.MAX_MEMBERS)
	var summary := {"case": label, "group_selected": group_before, "units": units.size(), "elements": elements.size(),
			"element_sizes": elements.map(func(e: Element) -> int: return e.members().size()),
			"formations": elements.map(func(e: Element) -> String: return e.formation),
			"moved": moved, "farthest_goal_m": snappedf(farthest_goal, 0.1), "worst_away_5s_m": snappedf(worst_away, 0.1),
			"worst_to_middle_5s_m": snappedf(worst_middle, 0.1)}
	print("TWO_SQUADS %s summary %s" % [label, JSON.stringify(summary)])
	_checks["%s_the_order_moved_them" % label] = moved * 2 >= units.size()
	_checks["%s_two_squads_kept" % label] = squads_kept
	_checks["%s_nobody_heads_away" % label] = worst_away <= AWAY_M
	_checks["%s_nobody_runs_to_the_middle" % label] = worst_middle <= AWAY_M
	return {"summary": summary, "rows": rows}


## The goal this unit's current order holds (where its dot is drawn), or null.
func _goal(unit_name: String) -> Variant:
	var goal: Variant = controls.orders.goal_position(unit_name)
	return _flat(goal) if goal is Vector3 else null


## The slot it will stand in: its element's arrival slot when it is in one, else its order's goal.
func _slot(unit_name: String) -> Variant:
	if controls.has_method("arrival_slot"):
		var slot: Variant = controls.call("arrival_slot", unit_name)
		if slot is Vector3:
			return _flat(slot)
	var element := controls.elements.of(unit_name)
	if element != null and element.slots.get(unit_name) is Vector3 and not element.in_transit():
		return _flat(element.slots[unit_name])
	return _goal(unit_name)


static func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]
