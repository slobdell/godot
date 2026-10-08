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
## Round 23 (O1): the closest two vehicles of different squads come is read from this many seconds in (as the
## interleaved probe reads it: once they have left where they stood, which the order did not choose).
const CLOSEST_FROM_S := 2.0

## Round 21 (orders, O2; C21.4): --five-squads plays his round-20 order instead: five gang squads of five
## (`tests/support/five_gangs_army.json`, vees as his garage army stood), all selected, one attack-move FIVE_AHEAD_M
## straight ahead (A, then a click). Per squad, in the first FIVE_FIRST_S: its centre's worst detour from the straight
## line start → click (C21.4's measure; it includes the squad's own place in the body), and its worst SIDEWAYS move,
## across the army's forward from where it stood (what he saw: the outer squads driving 100 m toward a wall); when it
## arrived (its centre within FIVE_THERE_M of its task's anchor); the body's frontage. FIVE_SQUADS lines and five_squads.json.
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
	# Round 23 (O1): --column-gap=14 lays two columns as before O1 (the probes' before-arm, on the same build).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--column-gap="):
			SelectionSquads.column_gap_m = float(arg.get_slice("=", 1))
			print("TWO_SQUADS column_gap_m=%.1f" % SelectionSquads.column_gap_m)
	if OS.get_cmdline_user_args().has("--five-squads"):
		await _five_squads()
		return
	if OS.get_cmdline_user_args().has("--interleaved-replay"):
		await _interleaved_replay()
		return
	if OS.get_cmdline_user_args().has("--interleaved"):
		await _interleaved()
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
	await _key(ControlGroups.key_for_number(number), false, true)  # Ctrl+N over both squads
	await _key(ControlGroups.key_for_number(number))               # N: the group holding both
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
	# Round 23 (O1): the nearest two vehicles of DIFFERENT squads come while driving (from CLOSEST_FROM_S, when they
	# have left their start positions, to SETTLE_S), and when: the number for two columns side by side.
	var closest_between := INF
	var closest_at := 0.0
	var t := 0.0
	while t < FIRST_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		for unit_name in units:
			(samples[unit_name] as Array).append(_flat(_tank(unit_name).global_position))
		if goals_first.is_empty():
			for unit_name in units:
				goals_first[unit_name] = _goal(unit_name)
		if t >= CLOSEST_FROM_S:
			var gap := _closest_between(one, two)
			if gap < closest_between:
				closest_between = gap
				closest_at = t
	await _capture("3_%s_5s" % label)
	var waited := FIRST_S
	while waited < SETTLE_S:
		await tree.create_timer(SAMPLE_S).timeout
		waited += SAMPLE_S
		var gap := _closest_between(one, two)
		if gap < closest_between:
			closest_between = gap
			closest_at = waited
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
		_ground_facts(unit_name, row)
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
			"worst_to_middle_5s_m": snappedf(worst_middle, 0.1),
			"closest_between_squads_m": snappedf(closest_between, 0.1) if closest_between < INF else null, "closest_at_s": closest_at}
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


## The nearest two living vehicles of different squads stand right now (INF when either squad is empty).
func _closest_between(one: Array[String], two: Array[String]) -> float:
	var closest := INF
	for a in _alive(one):
		var p := _flat(_tank(a).global_position)
		for b in _alive(two):
			closest = minf(closest, p.distance_to(_flat(_tank(b).global_position)))
	return closest


func _five_squads() -> void:
	var tree := get_tree()
	# Round 22 (orders O3): --squads=N plays the same order with N squads (ten: `ten_gangs_army.json`); --nest=off lays
	# the ranks a depth and a gap apart (the before-arm of the nesting ruling).
	var count := 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--squads="):
			count = int(arg.get_slice("=", 1))
	SelectionSquads.nest_ranks = not OS.get_cmdline_user_args().has("--nest=off")
	# Round 23 (O4): --auto-shape=off lays AUTO squads shapeless (the before-arm of the nominal shape).
	RtsControls.auto_nominal_shape = not OS.get_cmdline_user_args().has("--auto-shape=off")
	var squads: Array = []
	for number in range(1, ControlGroups.MAX_GROUPS + 1):
		var members := _alive(controls.groups.members(number))
		if not members.is_empty():
			squads.append(members)
	var all: Array[String] = []
	for members: Array[String] in squads:
		all.append_array(members)
	if squads.size() != count or controls.elements == null:
		print("TWO_SQUADS_DONE ok=false dir=%s (needs %d squads and elements; found %d)" % [out_dir, count, squads.size()])
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
	var at_order := {}
	for unit_name in all:
		var tank := _tank(unit_name)
		at_order[unit_name] = Vector3(tank.global_position.x, 0.0, tank.global_position.z) if tank != null else Vector3.ZERO
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
	# Round 22 (O1b): an order may deal interleaved squads by position (SelectionSquads.untangle), so the squads that
	# drive are the ELEMENTS the order formed, not the groups: follow those, from their own centres at the click.
	var groups_before := squads.map(func(m: Array) -> String: return ",".join(PackedStringArray(m)))
	var pieces: Array = []
	var seen := {}
	for unit_name in all:
		var element := controls.elements.of(unit_name)
		if element == null or seen.has(element):
			continue
		seen[element] = true
		var members: Array[String] = []
		for member: Variant in element.members():
			members.append(String(member))
		members.sort()
		pieces.append(members)
	var dealt := 0
	for members: Array[String] in pieces:
		if not groups_before.has(",".join(PackedStringArray(members))):
			dealt += 1
	if pieces.size() == squads.size():
		var old_starts := {}
		for i in squads.size():
			for unit_name: String in squads[i]:
				old_starts[unit_name] = at_order[unit_name]
		squads = pieces
		starts.clear()
		for members: Array[String] in squads:
			var c := Vector3.ZERO
			for unit_name in members:
				c += old_starts[unit_name]
			starts.append(c / members.size())
	var anchors: Array = []
	for members: Array[String] in squads:
		var element := controls.elements.of(members[0])
		var to: Array = element.task.get("to", []) if element != null else []
		anchors.append(_xz(Vector3(float(to[0]), 0.0, float(to[1]))) if to.size() == 2 else null)
	var detour := []
	var sideways := []
	var arrived := []
	for i in squads.size():
		detour.append(0.0)
		sideways.append(0.0)
		arrived.append(-1.0)
	var t := 0.0
	var shot_5 := false
	while t < FIVE_LIMIT_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		if is_equal_approx(fmod(t, 1.0), 0.0) and t <= FIVE_FIRST_S:
			_trace_squads(squads, t)
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
				# What he sees: how far the squad has gone ACROSS his army's forward from where it stood.
				sideways[i] = maxf(float(sideways[i]), absf((c - starts[i]).dot(right)))
			# Arrived = the squad's centre within FIVE_THERE_M of the anchor its task was given (brains, R2: crews at their
			# CURRENT slots read a restarted leg as "arrived" after 1-4 s, which is no arrival for an attack-move).
			var anchor: Variant = anchors[i]
			if float(arrived[i]) < 0.0 and anchor is Array \
					and _middle(members).distance_to(Vector3(float(anchor[0]), 0.0, float(anchor[1]))) <= FIVE_THERE_M:
				arrived[i] = t
		if t >= FIVE_FIRST_S and arrived.all(func(a: float) -> bool: return a >= 0.0):
			break
	await _capture("8_five_settled")
	var blocked: Array = []
	for unit_name in _alive(all):
		var row := {"unit": unit_name}
		_ground_facts(unit_name, row)
		if row.get("phase", "") == "blocked" or float(row.get("slot_pushed_m", 0.0)) > 3.0:
			blocked.append(row)
		print("FIVE_SQUADS unit %s" % JSON.stringify(row))
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
	# Round 22 (O3): the body against the click: how far the furthest anchor stands PAST it (none should), how deep the
	# body is behind it, and whether each squad's anchor is nearer the click than where it started.
	var past := -INF
	var deep := 0.0
	var closer: Array = []
	for i in anchors.size():
		var a: Variant = anchors[i]
		if not a is Array:
			closer.append(false)
			continue
		var p := Vector3(float(a[0]), 0.0, float(a[1]))
		var along := (p - click).dot(forward)
		past = maxf(past, along)
		deep = maxf(deep, -along)
		closer.append(p.distance_to(click) < starts[i].distance_to(click))
	var all_arrived: bool = arrived.all(func(a: float) -> bool: return a >= 0.0)
	var last: float = arrived.max() if all_arrived else -1.0
	var summary := {"case": "five", "squads": count, "dealt": dealt, "by": by, "shape": shape if shape != "" else UnitCommand.AUTO, "arena": String(Arena.active.get("name", "")), "click": _xz(click),
			"anchors": anchors, "anchor_span_m": snappedf(east - west, 0.1),
			"elements": elements.size(), "element_sizes": elements.map(func(e: Element) -> int: return e.members().size()),
			"formations": elements.map(func(e: Element) -> String: return e.formation),
			"detour_10s_m": detour.map(func(d: float) -> float: return snappedf(d, 0.1)),
			"worst_detour_10s_m": snappedf(detour.max(), 0.1),
			"sideways_10s_m": sideways.map(func(d: float) -> float: return snappedf(d, 0.1)),
			"worst_sideways_10s_m": snappedf(sideways.max(), 0.1),
			"arrived_s": arrived, "last_arrived_s": last, "blocked_or_pushed": blocked,
			"past_click_m": snappedf(past, 0.1), "body_depth_m": snappedf(deep, 0.1), "anchor_closer": closer}
	print("FIVE_SQUADS summary %s" % JSON.stringify(summary))
	_checks["five_the_order_was_taken"] = anchors.all(func(a: Variant) -> bool: return a is Array)
	_checks["five_squads_kept"] = elements.size() == count and elements.all(func(e: Element) -> bool: return e.members().size() <= Formations.MAX_MEMBERS)
	var file := FileAccess.open(out_dir.path_join("five_squads.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary}, "  "))
	file.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("TWO_SQUADS ", JSON.stringify({"checks": _checks}))
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


## One line per squad each second of the first FIVE_FIRST_S: what its element is doing with the order (the task's
## destination, transit or not, the plan's `arrived`, its drill and formation) and where its centre is. A squad that
## reads IDLE on the group bar after a click says why here.
func _trace_squads(squads: Array, t: float) -> void:
	for i in squads.size():
		var members := _alive(squads[i])
		if members.is_empty():
			continue
		var element := controls.elements.of(members[0])
		var to: Variant = ElementTask.destination(element.task) if element != null else null
		print("FIVE_SQUADS trace %s" % JSON.stringify({"t": t, "squad": i + 1, "centre": _xz(_middle(members)),
				"to": _xz(to) if to is Vector3 else null, "verb": String(element.task.get("verb", "")) if element != null else "",
				"in_transit": element.in_transit() if element != null else false,
				"arrived": element.arrived if element != null else false,
				"drill": element.drill if element != null else "", "formation": element.formation if element != null else "",
				"phase": String(controls.movement.state(members[0]).get("phase", "")),
				"order": String(controls.orders.current(members[0]).get("verb", ""))}))


## Round 21 (orders, O3): where its formation ASKED it to stand against where the ground let it (Element.slots_asked,
## SlotGround), how far it still is from that slot, and what nav says of it (BLOCKED, "terrain"): a slot laid inside a
## container and pushed to its face reads as a large `slot_pushed_m` with the crew blocked short of it.
func _ground_facts(unit_name: String, row: Dictionary) -> void:
	var element := controls.elements.of(unit_name)
	var asked: Variant = element.slots_asked.get(unit_name) if element != null else null
	var slot: Variant = element.slots.get(unit_name) if element != null else null
	if asked is Vector3:
		row["slot_asked"] = _xz(asked)
		if slot is Vector3:
			row["slot_pushed_m"] = snappedf(_flat(asked).distance_to(_flat(slot)), 0.1)
	if slot is Vector3:
		row["from_slot_m"] = snappedf(_flat(_tank(unit_name).global_position).distance_to(_flat(slot)), 0.1)
	var reading := controls.movement.state(unit_name)
	row["phase"] = String(reading.get("phase", ""))
	if String(reading.get("blocked_by", "")) != "":
		row["blocked_by"] = String(reading["blocked_by"])


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


## Round 22 (orders O1b): his six on the Sumps (2026-10-07T13-46-42-sumps, seed 5988): two squads of three Retired APCs
## standing interleaved, both selected, a line picked, one right-click between his two points. Alpha stands where his
## Green_Hunters 1, 5, 7 stood at tick 4410 and Bravo where 4, 6, 8 did. Measured: how many pairs of the six vehicles'
## straight paths (start -> the slot they are given) cross, and in the first INTERLEAVED_S how many samples had two
## hulls touching (centres closer than a hull's length) and how many crews read blocked; when all six stood within 6 m
## of their slots (INTERLEAVED_SETTLE_S at most) and how far each was then. `--untangle=off` is the
## before-arm (round 21's row, squads kept as they were). INTERLEAVED lines and interleaved.json.
const HIS_SIX := {"Green_Alpha_1": Vector2(66.1, -72.3), "Green_Alpha_2": Vector2(55.9, -80.1),
		"Green_Alpha_3": Vector2(43.2, -87.9), "Green_Bravo_1": Vector2(63.1, -64.2), "Green_Bravo_2": Vector2(47.9, -82.6),
		"Green_Bravo_3": Vector2(57.0, -71.7)}
const HIS_CLICK := Vector2(96.0, 23.6)
const INTERLEAVED_S := 10.0
const INTERLEAVED_SETTLE_S := 40.0


func _interleaved() -> void:
	var tree := get_tree()
	var untangle := not OS.get_cmdline_user_args().has("--untangle=off")
	controls.untangle_rows = untangle
	var six: Array[String] = []
	for unit_name: String in HIS_SIX:
		if _tank(unit_name) == null:
			print("TWO_SQUADS_DONE ok=false dir=%s (no %s)" % [out_dir, unit_name])
			tree.quit(1)
			return
		six.append(unit_name)
	# The line is picked first (his squads already stood in their shape), then they are put back where his stood, so
	# the order finds them interleaved as his did, not re-formed in place.
	controls.selection.set_units(six)
	await tree.process_frame
	controls.set_formation("line")
	await tree.create_timer(1.0).timeout
	for unit_name in six:
		var tank := _tank(unit_name)
		var at: Vector2 = HIS_SIX[unit_name]
		tank.global_position = Vector3(at.x, tank.global_position.y, at.y)
		tank.velocity = Vector3.ZERO
		tank.rotation.y = atan2(-(HIS_CLICK.x - at.x), -(HIS_CLICK.y - at.y))  # facing the click (forward is -Z)
		tank.reset_physics_interpolation()
	await tree.physics_frame
	await tree.physics_frame
	var starts := {}
	for unit_name in six:
		starts[unit_name] = _flat(_tank(unit_name).global_position)
	var click := Vector3(HIS_CLICK.x, 0.0, HIS_CLICK.y)
	controls.selection.set_units(six)
	if controls.rig != null:
		controls.rig.focus_on(click)
		await tree.create_timer(1.2).timeout
	var at := _screen(click)
	var under: Variant = controls.screen_to_world(at)
	var by := "click"
	if under is Vector3 and _flat(under).distance_to(click) < 3.0 and get_viewport().get_visible_rect().has_point(at):
		await _right_click(at)
	else:
		by = "radar"
		_mouse(radar.get_global_rect().position + radar.world_to_radar(click), true, MOUSE_BUTTON_RIGHT)
		_mouse(radar.get_global_rect().position + radar.world_to_radar(click), false, MOUSE_BUTTON_RIGHT)
		await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame
	await _capture("9_interleaved_ordered")
	# One pin per line (a dealt piece matches no control group: the pins must still be two, not one per crew).
	var pins := controls.order_marks().size()
	await tree.create_timer(0.5).timeout  # the leaders lay their slots on their next plan
	var slots := {}
	var lines := {}
	for unit_name in six:
		var element := controls.elements.of(unit_name)
		var slot: Variant = controls.arrival_slot(unit_name)
		if slot is Vector3:
			slots[unit_name] = _flat(slot)
		lines[unit_name] = element.id if element != null else -1
	# Between lines: a crew driving through the OTHER line (what O1b fixes). Within a line: the line's own seating
	# (brains' "travel" seats: least squared driving, which can swap two vehicles standing one behind the other).
	var crossings: Array = []
	var within: Array = []
	for i in six.size():
		for j in range(i + 1, six.size()):
			var a := six[i]
			var b := six[j]
			if not slots.has(a) or not slots.has(b):
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(_v2(starts[a]), _v2(slots[a]), _v2(starts[b]), _v2(slots[b]))
			if hit != null:
				(within if lines[a] == lines[b] else crossings).append([a, b])
	# Two hulls touching: centres closer than half a hull's width plus half its length (5.3 m for the APC); a column
	# standing 7 m apart is not touching, two hulls nose to flank are.
	var hull: Array = Units.stat("law_ifv", "hull_size")
	var touch_m := (float(hull[0]) + float(hull[2])) * 0.5
	var contact_samples := 0
	var touching := {}
	var contact_times: Array = []
	var closest_between := INF  # the nearest two vehicles of DIFFERENT lines came, from 2 s to INTERLEAVED_S
	var closest_any := INF
	var blocked := {}
	# How long the two lines drove MIXED (his "criss-crossed ... contending"): the samples in which the two lines' spans
	# across the heading overlap, over the whole drive (to INTERLEAVED_SETTLE_S or until all six stand in their slots).
	var middle := Vector3.ZERO
	for unit_name in six:
		middle += starts[unit_name]
	middle /= six.size()
	var heading := (click - middle).normalized()
	var across := Vector3(-heading.z, 0.0, heading.x)
	var mixed_samples := 0
	var mixed := func() -> bool:
		var spans := {}
		for unit_name in _alive(six):
			var x := _flat(_tank(unit_name).global_position).dot(across)
			var line: int = lines.get(unit_name, -1)
			var span: Array = spans.get(line, [INF, -INF])
			spans[line] = [minf(span[0], x), maxf(span[1], x)]
		var keys := spans.keys()
		return keys.size() == 2 and spans[keys[0]][1] > spans[keys[1]][0] and spans[keys[1]][1] > spans[keys[0]][0]
	var t := 0.0
	while t < INTERLEAVED_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		if mixed.call():
			mixed_samples += 1
		var living := _alive(six)
		for i in living.size():
			var reading := controls.movement.state(living[i])
			if String(reading.get("phase", "")) == "blocked":
				blocked[living[i]] = String(reading.get("blocked_by", ""))
			for j in range(i + 1, living.size()):
				var gap := _flat(_tank(living[i]).global_position).distance_to(_flat(_tank(living[j]).global_position))
				# From 2 s on: before that the six still stand where his stood, 7 m apart, whichever line each is in.
				if t >= 2.0:
					closest_any = minf(closest_any, gap)
				if t >= 2.0 and lines.get(living[i], -1) != lines.get(living[j], -2):
					closest_between = minf(closest_between, gap)
				if gap < touch_m:
					contact_samples += 1
					touching["%s/%s" % [living[i], living[j]]] = true
					contact_times.append(t)
	await _capture("10_interleaved_10s")
	var settled := -1.0
	var from_slots := {}
	while t < INTERLEAVED_SETTLE_S:
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		if mixed.call():
			mixed_samples += 1
		var all_there := true
		for unit_name in _alive(six):
			var slot: Variant = controls.arrival_slot(unit_name)
			var off := _flat(_tank(unit_name).global_position).distance_to(_flat(slot)) if slot is Vector3 else INF
			from_slots[unit_name] = snappedf(off, 0.1)
			if off > 6.0:
				all_there = false
		if all_there:
			settled = t
			break
	await _capture("11_interleaved_settled")
	var summary := {"case": "interleaved", "untangle": untangle, "by": by, "arena": String(Arena.active.get("name", "")),
			"click": _xz(click), "lines": lines, "slots": slots.keys().map(func(k: String) -> Array: return [k, _xz(slots[k])]),
			"path_crossings": crossings.size(), "crossing_pairs": crossings, "within_line_crossings": within, "contact_samples_10s": contact_samples,
			"pairs_touching_10s": touching.keys(), "contact_times_s": contact_times,
			"lines_mixed_s": mixed_samples * SAMPLE_S, "closest_between_lines_m": snappedf(closest_between, 0.1), "closest_any_m": snappedf(closest_any, 0.1), "blocked_10s": blocked, "touch_m": touch_m, "all_in_slots_s": settled, "from_slot_m": from_slots, "pins": pins}
	print("INTERLEAVED summary %s" % JSON.stringify(summary))
	_checks["interleaved_ordered"] = slots.size() == six.size()
	_checks["interleaved_two_pins"] = pins == 2
	if untangle:
		_checks["interleaved_no_crossing"] = crossings.is_empty()
	var file := FileAccess.open(out_dir.path_join("interleaved.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary}, "  "))
	file.close()
	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("TWO_SQUADS ", JSON.stringify({"checks": _checks}))
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


static func _v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## His six from tick 3600 of the same recording, given his five clicks at his times (the midpoint of each click's two
## points; AUTO for the first two, then the column he picked at tick 3782, before the third). Per order: crew paths
## crossing the other line. Over the whole 45 s: how long the two lines drove mixed (spans across their heading
## overlapping), the closest two vehicles of different lines came, hull contacts. INTERLEAVED_REPLAY lines.
const HIS_3600 := {"Green_Alpha_1": Vector2(48.6, -95.2), "Green_Alpha_2": Vector2(41.7, -105.2),
		"Green_Alpha_3": Vector2(31.5, -97.7), "Green_Bravo_1": Vector2(3.8, -69.9), "Green_Bravo_2": Vector2(-17.9, -81.1),
		"Green_Bravo_3": Vector2(-6.3, -81.4)}
## [seconds after the first, click x, click z, formation picked just before it ("" = leave)].
const HIS_CLICKS := [[0.0, 2.8, -94.4, ""], [2.1, -20.4, -94.3, ""], [6.53, -45.7, -105.4, "column"],
		[13.77, 76.9, -58.4, ""], [27.17, 96.0, 23.6, ""]]
const REPLAY_S := 45.0


func _interleaved_replay() -> void:
	var tree := get_tree()
	var untangle := not OS.get_cmdline_user_args().has("--untangle=off")
	controls.untangle_rows = untangle
	var six: Array[String] = []
	for unit_name: String in HIS_3600:
		var tank := _tank(unit_name)
		if tank == null:
			print("TWO_SQUADS_DONE ok=false dir=%s (no %s)" % [out_dir, unit_name])
			tree.quit(1)
			return
		var at: Vector2 = HIS_3600[unit_name]
		tank.global_position = Vector3(at.x, tank.global_position.y, at.y)
		tank.velocity = Vector3.ZERO
		tank.reset_physics_interpolation()
		six.append(unit_name)
	controls.selection.set_units(six)
	controls.set_formation(UnitCommand.AUTO)
	await tree.create_timer(0.5).timeout
	var hull: Array = Units.stat("law_ifv", "hull_size")
	var touch_m := (float(hull[0]) + float(hull[2])) * 0.5
	var t := 0.0
	var next := 0
	var per_order: Array = []
	var lines := {}
	var heading := Vector3.FORWARD
	var mixed_samples := 0
	var contact_samples := 0
	var closest_between := INF
	var since_order := 0.0
	while t < REPLAY_S:
		if next < HIS_CLICKS.size() and t >= float(HIS_CLICKS[next][0]):
			var step: Array = HIS_CLICKS[next]
			controls.selection.set_units(_alive(six))
			if String(step[3]) != "":
				controls.set_formation(String(step[3]))
			var click := Vector3(float(step[1]), 0.0, float(step[2]))
			var starts := {}
			var middle := Vector3.ZERO
			for unit_name in _alive(six):
				starts[unit_name] = _flat(_tank(unit_name).global_position)
				middle += starts[unit_name]
			middle /= maxf(starts.size(), 1.0)
			heading = (click - middle).normalized()
			controls.order_selection("move", {"to": [click.x, click.z]})
			await tree.create_timer(0.5).timeout
			t += 0.5
			lines.clear()
			var slots := {}
			for unit_name in _alive(six):
				var element := controls.elements.of(unit_name)
				lines[unit_name] = element.id if element != null else -1
				var slot: Variant = controls.arrival_slot(unit_name)
				if slot is Vector3:
					slots[unit_name] = _flat(slot)
			var crossing := 0
			var names := slots.keys()
			for i in names.size():
				for j in range(i + 1, names.size()):
					var a: String = names[i]
					var b: String = names[j]
					if lines[a] != lines[b] and Geometry2D.segment_intersects_segment(_v2(starts[a]), _v2(slots[a]),
							_v2(starts[b]), _v2(slots[b])) != null:
						crossing += 1
			per_order.append({"at_s": step[0], "click": [step[1], step[2]], "crossing_other_line": crossing,
					"lines": lines.duplicate(), "pins": controls.order_marks().size(),
					"formation": String(step[3]), "closest_between_lines_m": -1.0, "lines_mixed_s": 0.0})  # -1: no reading yet
			next += 1
			since_order = 0.0
			continue
		await tree.create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		since_order += SAMPLE_S
		var living := _alive(six)
		var across := Vector3(-heading.z, 0.0, heading.x)
		var spans := {}
		for unit_name in living:
			var x := _flat(_tank(unit_name).global_position).dot(across)
			var line: int = lines.get(unit_name, -1)
			var span: Array = spans.get(line, [INF, -INF])
			spans[line] = [minf(span[0], x), maxf(span[1], x)]
		var keys := spans.keys()
		if keys.size() == 2 and spans[keys[0]][1] > spans[keys[1]][0] and spans[keys[1]][1] > spans[keys[0]][0]:
			mixed_samples += 1
			if not per_order.is_empty():
				per_order[-1]["lines_mixed_s"] = float(per_order[-1]["lines_mixed_s"]) + SAMPLE_S
		for i in living.size():
			for j in range(i + 1, living.size()):
				var gap := _flat(_tank(living[i]).global_position).distance_to(_flat(_tank(living[j]).global_position))
				if gap < touch_m:
					contact_samples += 1
				if since_order >= 2.0 and lines.get(living[i], -1) != lines.get(living[j], -2):
					closest_between = minf(closest_between, gap)
					# Round 23 (O1): per order too, so the column clicks (his third on) read on their own.
					if not per_order.is_empty():
						var so_far := float(per_order[-1]["closest_between_lines_m"])
						per_order[-1]["closest_between_lines_m"] = snappedf(gap if so_far < 0.0 else minf(so_far, gap), 0.1)
	var summary := {"case": "interleaved_replay", "untangle": untangle, "orders": per_order,
			"crossing_other_line": per_order.reduce(func(sum: int, o: Dictionary) -> int: return sum + int(o["crossing_other_line"]), 0),
			"lines_mixed_s": mixed_samples * SAMPLE_S, "contact_samples": contact_samples, "touch_m": touch_m,
			"closest_between_lines_m": snappedf(closest_between, 0.1)}
	print("INTERLEAVED_REPLAY summary %s" % JSON.stringify(summary))
	var file := FileAccess.open(out_dir.path_join("interleaved_replay.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary}, "  "))
	file.close()
	# Measured, not judged, beyond the order being taken with one pin per line: the crossings here are to each crew's
	# SEAT, which in a column lies along the heading from the squad's place (brains' seating), where untangle deals by
	# the places themselves.
	var ok := per_order.size() == HIS_CLICKS.size() and per_order.all(func(o: Dictionary) -> bool: return int(o["pins"]) == 2)
	print("TWO_SQUADS_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)
