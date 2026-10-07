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
## The click is this far toward squad 2's flank, so heading for the two squads' middle is NOT heading for the click
## (his "ran off to the middle of the map" is only visible when the click is somewhere else).
const ASIDE_M := 35.0
const SAMPLE_S := 0.25
const FIRST_S := 5.0
const SETTLE_S := 25.0
## A vehicle's first 5 s may take it no farther from the click than this (its spacing: it is finding its seat).
const AWAY_M := 14.0

## Round 21 (orders, O2; C21.4): --five-squads plays his round-20 order instead: five gang squads of five
## (`tests/support/five_gangs_army.json`, vees as his garage army stood), all selected, one attack-move FIVE_AHEAD_M
## straight ahead (A, then a click). Per squad: the worst SIDEWAYS detour of its centre in the first FIVE_FIRST_S (its
## distance from the straight line between where its centre started and the click) and when it arrived (every crew
## within FIVE_THERE_M of the slot it will stand in); the body's frontage. FIVE_SQUADS lines and five_squads.json.
const FIVE_AHEAD_M := 150.0
const FIVE_FIRST_S := 10.0
const FIVE_LIMIT_S := 90.0
const FIVE_THERE_M := 12.0

var _cases := {}


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_can_capture = DisplayServer.get_name() != "headless"
	if not _can_capture:
		get_tree().root.size = Vector2i(1280, 720)  # headless roots are 64×64 (trip-up 31)
	var tree := get_tree()
	await tree.create_timer(1.0).timeout
	if OS.get_cmdline_user_args().has("--five-squads"):
		await _five_squads()
		return
	var one := _alive(controls.groups.members(1))
	var two := _alive(controls.groups.members(2))
	if one.is_empty() or two.is_empty() or controls.elements == null:
		print("TWO_SQUADS_DONE ok=false dir=%s (needs squads 1 and 2 and elements)" % out_dir)
		tree.quit(1)
		return
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	var base := _middle(one + two)
	var click := Orders.clamp_to_arena(base + forward * AHEAD_M + right * ASIDE_M)
	# O5 (`make two-squads-playtest TWO_ARENA=parade TWO_CLICK=x,z TWO_SHAPES=line,wedge`): his own click, and a
	# formation picked for each squad first (through G, as he would), so the squads go in two different shapes.
	var shapes: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--two-click="):
			var xz := arg.get_slice("=", 1).split(",")
			click = Orders.clamp_to_arena(Vector3(float(xz[0]), 0.0, float(xz[1])))
		elif arg.begins_with("--two-shapes="):
			shapes = arg.get_slice("=", 1).split(",")
	_step("two_squads_setup", {"one": one, "two": two, "base": _xz(base), "click": _xz(click),
			"arena": String(Arena.active.get("name", ""))})

	await _to_flanks(base, right)
	await _pick_shapes(shapes)
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

	# The reference: squad 1 ALONE ordered to the same click from its flank (how a crew finds its seat in one squad).
	await _to_flanks(base, right)
	controls.recall_group(1)
	await tree.process_frame
	_cases["single"] = await _order_both(click, base, right, one, [] as Array[String], "single")

	var file := FileAccess.open(out_dir.path_join("two_squads.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": _cases, "click": _xz(click), "base": _xz(base)}, "  "))
	file.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("TWO_SQUADS ", JSON.stringify({"checks": _checks}))
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


## Squad n takes shapes[n - 1] with G (pressed until the button reads it), then is deselected.
func _pick_shapes(shapes: PackedStringArray) -> void:
	for i in mini(shapes.size(), 2):
		controls.recall_group(i + 1)
		await get_tree().process_frame
		var presses := 0
		while String(controls.formation) != shapes[i] and presses < FormationCatalog.ORDER.size() + 1:
			await _key(KEY_G)
			presses += 1
		if String(controls.formation) != shapes[i]:
			controls.set_formation(shapes[i])  # a panel-only shape (coil, echelons): the picker's one click
		_step("two_squads_shape", {"squad": i + 1, "formation": String(controls.formation), "g_presses": presses})
	controls.selection.clear()
	await get_tree().process_frame


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
	var squad_centre := {1: _middle(_alive(one)), 2: _middle(_alive(two)) if not two.is_empty() else Vector3.ZERO}
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
	var worst_off := 0.0
	var farthest_goal := 0.0
	var moved := 0
	for unit_name in units:
		var path: Array = samples[unit_name]
		var s0: Vector3 = path[0]
		var away := 0.0
		var off_line := 0.0
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
		# How far its first 5 s strayed from the straight line between where it stood and where it is meant to stand.
		for p: Vector3 in path:
			off_line = maxf(off_line, Geometry3D.get_closest_point_to_segment(p, s0, meant).distance_to(p))
		# How far it ran toward the middle (between the flanks) beyond where it started, where it is meant to stand AND
		# its own squad's centre: a crew driving out to its slot, or closing on its own squad to form up for the
		# move, is not running to the middle; one crossing past its squad toward the other is.
		var own: Vector3 = squad_centre[1 if one.has(unit_name) else 2]
		# (its own squad's wedge or line reaches half a frontage either side of that centre while it travels)
		var own_inner := absf((own - base).dot(right)) - SelectionSquads.width("line", Formations.MAX_MEMBERS) * 0.5
		var inner := minf(minf(absf((s0 - base).dot(right)), absf((meant - base).dot(right))), own_inner)
		var middle := maxf(inner - lateral_min, 0.0)
		if signf((s0 - base).dot(right)) != signf((meant - base).dot(right)):
			middle = 0.0  # its place is across the middle (his click was on the other side): crossing is the order
		var row := {"unit": unit_name, "squad": 1 if one.has(unit_name) else 2, "start": _xz(s0),
				"goal": _xz(goal) if goal is Vector3 else null,
				"goal_to_click": snappedf((goal as Vector3).distance_to(click), 0.1) if goal is Vector3 else -1.0,
				"slot": _xz(slot) if slot is Vector3 else null,
				"slot_to_click": snappedf((slot as Vector3).distance_to(click), 0.1) if slot is Vector3 else -1.0,
				"at_5s": _xz(path[path.size() - 1]), "end": _xz(end), "end_to_click": snappedf(end.distance_to(click), 0.1),
				"away_5s": snappedf(away, 0.1), "off_line_5s": snappedf(off_line, 0.1), "to_middle_5s": snappedf(middle, 0.1)}
		rows.append(row)
		worst_away = maxf(worst_away, away)
		worst_off = maxf(worst_off, off_line)
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
	var expected := 2 if not two.is_empty() else 1
	var squads_kept := elements.size() == expected and elements.all(func(e: Element) -> bool: return e.members().size() <= Formations.MAX_MEMBERS)
	var summary := {"case": label, "group_selected": group_before, "units": units.size(), "elements": elements.size(),
			"element_sizes": elements.map(func(e: Element) -> int: return e.members().size()),
			"formations": elements.map(func(e: Element) -> String: return e.formation),
			"moved": moved, "farthest_goal_m": snappedf(farthest_goal, 0.1), "worst_away_5s_m": snappedf(worst_away, 0.1), "worst_off_line_5s_m": snappedf(worst_off, 0.1),
			"worst_to_middle_5s_m": snappedf(worst_middle, 0.1)}
	print("TWO_SQUADS %s summary %s" % [label, JSON.stringify(summary)])
	_checks["%s_the_order_moved_them" % label] = moved * 2 >= units.size()
	_checks["%s_two_squads_kept" % label] = squads_kept
	_checks["%s_nobody_heads_away" % label] = worst_away <= AWAY_M
	if not two.is_empty():  # one squad has no "middle" between two squads to run to: its case is a reference only
		_checks["%s_nobody_runs_to_the_middle" % label] = worst_middle <= AWAY_M
	# off_line is REPORTED, not judged: a crew taking its seat inside its own squad's travelling formation strays off
	# the straight line by the element's own seating (brains' transit), the same for one squad alone; the "single"
	# case measures that reference.
	return {"summary": summary, "rows": rows}


func _five_squads() -> void:
	var tree := get_tree()
	var squads: Array = []
	for number in range(1, 6):
		var members := _alive(controls.groups.members(number))
		if not members.is_empty():
			squads.append(members)
	var all: Array[String] = []
	for members: Array[String] in squads:
		all.append_array(members)
	if squads.size() != 5 or controls.elements == null:
		print("TWO_SQUADS_DONE ok=false dir=%s (needs five squads and elements; found %d)" % [out_dir, squads.size()])
		tree.quit(1)
		return
	# Let the spawn settle (they are ordered from where they stand, as he did).
	await tree.create_timer(3.0).timeout
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	var base := _middle(all)
	var click := Orders.clamp_to_arena(base + forward * FIVE_AHEAD_M)
	var shape := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--two-click="):
			var xz := arg.get_slice("=", 1).split(",")
			click = Orders.clamp_to_arena(Vector3(float(xz[0]), 0.0, float(xz[1])))
		elif arg.begins_with("--five-shape="):
			shape = arg.get_slice("=", 1)
	if shape != "" and shape != UnitCommand.AUTO:
		# His round-20 squads went in vees: all five selected, one pick in the Formation panel (each squad takes it).
		controls.selection.set_units(all)
		await tree.process_frame
		controls.set_formation(shape)
		await tree.create_timer(4.0).timeout
	var starts: Array[Vector3] = []
	for members: Array[String] in squads:
		starts.append(_middle(members))
	_step("five_squads_setup", {"base": _xz(base), "click": _xz(click), "arena": String(Arena.active.get("name", "")),
			"starts": starts.map(func(p: Vector3) -> Array: return _xz(p))})
	controls.selection.set_units(all)
	if controls.rig != null:
		controls.rig.focus_on(click)
		await tree.create_timer(1.2).timeout
	await _capture("5_five_selected")
	var at := _screen(click)
	var under: Variant = controls.screen_to_world(at)
	var by := "click"
	await _key(KEY_A)
	if under is Vector3 and _flat(under).distance_to(click) < 3.0 and get_viewport().get_visible_rect().has_point(at):
		await _click(at)
	else:
		by = "radar"
		await _click(radar.get_global_rect().position + radar.world_to_radar(click))
	await tree.physics_frame
	await tree.physics_frame
	await _capture("6_five_ordered")
	var anchors: Array = []
	for members: Array[String] in squads:
		var element := controls.elements.of(members[0])
		var to: Array = element.task.get("to", []) if element != null else []
		anchors.append(_xz(Vector3(float(to[0]), 0.0, float(to[1]))) if to.size() == 2 else null)
	var detour := []
	var arrived := []
	for i in squads.size():
		detour.append(0.0)
		arrived.append(-1.0)
	var t := 0.0
	var shot_5 := false
	while t < FIVE_LIMIT_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		if t >= 5.0 and not shot_5:
			shot_5 = true
			await _capture("7_five_5s")
		for i in squads.size():
			var members := _alive(squads[i])
			if members.is_empty():
				continue
			if t <= FIVE_FIRST_S:
				var c := _middle(members)
				var nearest := Geometry3D.get_closest_point_to_segment(c, starts[i], click)
				detour[i] = maxf(float(detour[i]), c.distance_to(nearest))
			if float(arrived[i]) < 0.0 and members.all(func(n: String) -> bool:
					var slot: Variant = _slot(n)
					return slot is Vector3 and _flat(_tank(n).global_position).distance_to(slot) <= FIVE_THERE_M):
				arrived[i] = t
		if t >= FIVE_FIRST_S and arrived.all(func(a: float) -> bool: return a >= 0.0):
			break
	await _capture("8_five_settled")
	var west := INF
	var east := -INF
	for a: Variant in anchors:
		if a is Array:
			var p := Vector3(float(a[0]), 0.0, float(a[1]))
			west = minf(west, (p - click).dot(right))
			east = maxf(east, (p - click).dot(right))
	var elements := []
	for unit_name in all:
		var element := controls.elements.of(unit_name)
		if element != null and not elements.has(element):
			elements.append(element)
	var all_arrived: bool = arrived.all(func(a: float) -> bool: return a >= 0.0)
	var last: float = arrived.max() if all_arrived else -1.0
	var summary := {"case": "five", "by": by, "shape": shape if shape != "" else UnitCommand.AUTO, "arena": String(Arena.active.get("name", "")), "click": _xz(click),
			"anchors": anchors, "anchor_span_m": snappedf(east - west, 0.1),
			"elements": elements.size(), "element_sizes": elements.map(func(e: Element) -> int: return e.members().size()),
			"formations": elements.map(func(e: Element) -> String: return e.formation),
			"detour_10s_m": detour.map(func(d: float) -> float: return snappedf(d, 0.1)),
			"worst_detour_10s_m": snappedf(detour.max(), 0.1),
			"arrived_s": arrived, "last_arrived_s": last}
	print("FIVE_SQUADS summary %s" % JSON.stringify(summary))
	_checks["five_the_order_was_taken"] = anchors.all(func(a: Variant) -> bool: return a is Array)
	_checks["five_squads_kept"] = elements.size() == 5 and elements.all(func(e: Element) -> bool: return e.members().size() <= Formations.MAX_MEMBERS)
	var file := FileAccess.open(out_dir.path_join("five_squads.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary}, "  "))
	file.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("TWO_SQUADS ", JSON.stringify({"checks": _checks}))
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


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
