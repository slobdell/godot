extends TestCase
## Round 47 (orders O1, R47.4): HIS SPREAD GROUP CLICKS. Two squads he had merged into one control group of ten (his words:
## "I selected squads 3 and 4, grouped them into a single squad 4, then I picked a single target waypoint ... picked two points
## that were far apart") got two places laid ABREAST across his approach, each a squad's halt width plus GAP_M apart:
##   Crossing (references/round46/playtest/2026-10-30T15-41-59-crossing.jsonl, seed 101, tick 0 paused): Spears + Wrenches (group 4)
##     click (80.9, 49.5) -> Spears (55.7, 22.6), Wrenches (95.5, 69.0): 61 m apart.
##   Locks (references/round46/playtest/2026-10-30T15-49-20-locks.jsonl, seed 1 of the recording, tick 0 paused): Burners + Burners2
##     (group 2) click (-81.6, 45.7) -> Burners (-91.2, 58.9), Burners2 (-68.3, 31.2): 36 m apart.
## This lab stands his squads where they spawned on the real navmesh, saves his control groups, and clicks as he did.

const CASES := {
	"crossing": {
		"seed": 101,
		"squads": {
			"Green_Spears": ["Green_Spears_1", "Green_Spears_2", "Green_Spears_3", "Green_Spears_4", "Green_Spears_5"],
			"Green_Wrenches": ["Green_Wrenches_1", "Green_Wrenches_2", "Green_Wrenches_3", "Green_Wrenches_4", "Green_Wrenches_5"],
		},
		"others": {
			"Green_Guns": ["Green_Guns_1", "Green_Guns_2", "Green_Guns_3", "Green_Guns_4", "Green_Guns_5"],
			"Green_Hunters": ["Green_Hunters_1", "Green_Hunters_2", "Green_Hunters_3", "Green_Hunters_4", "Green_Hunters_5"],
		},
		# his control groups: 1 Guns, 2 Hunters, 3 Spears, 4 = Spears + Wrenches (his merge)
		"groups": [["Green_Guns"], ["Green_Hunters"], ["Green_Spears"], ["Green_Spears", "Green_Wrenches"]],
		"at": {
			"Green_Guns_1": ["gang_tank", Vector3(-48.643, 0, 90.0)], "Green_Guns_2": ["gang_tank", Vector3(-35.643, 0, 90.0)],
			"Green_Guns_3": ["gang_tank", Vector3(-47.125, 0, 105.0)], "Green_Guns_4": ["gang_tank", Vector3(-42.143, 0, 90.0)],
			"Green_Guns_5": ["gang_tank", Vector3(-40.625, 0, 105.0)],
			"Green_Hunters_1": ["gang_ifv", Vector3(-21.125, 0, 89.0)], "Green_Hunters_2": ["gang_ifv", Vector3(-14.625, 0, 89.0)],
			"Green_Hunters_3": ["gang_ifv", Vector3(-17.875, 0, 95.5)], "Green_Hunters_4": ["gang_ifv", Vector3(-8.125, 0, 89.0)],
			"Green_Hunters_5": ["gang_ifv", Vector3(-11.375, 0, 95.5)],
			"Green_Spears_1": ["gang_scout", Vector3(8.125, 0, 89.0)], "Green_Spears_2": ["gang_scout", Vector3(11.375, 0, 105.0)],
			"Green_Spears_3": ["gang_scout", Vector3(17.875, 0, 105.0)], "Green_Spears_4": ["gang_scout", Vector3(14.625, 0, 89.0)],
			"Green_Spears_5": ["gang_tank", Vector3(21.125, 0, 89.0)],
			"Green_Wrenches_1": ["gang_support", Vector3(37.375, 0, 89.0)], "Green_Wrenches_2": ["gang_support", Vector3(50.375, 0, 89.0)],
			"Green_Wrenches_3": ["gang_support", Vector3(43.875, 0, 89.0)], "Green_Wrenches_4": ["gang_ifv", Vector3(47.125, 0, 97.58)],
			"Green_Wrenches_5": ["gang_ifv", Vector3(40.625, 0, 97.58)],
		},
		"click": Vector3(80.9164, 0.0, 49.5366),
		"to": {"Green_Spears": Vector3(55.652, 0, 22.637), "Green_Wrenches": Vector3(95.516, 0, 69.048)},
	},
	"locks": {
		"seed": 0,
		"squads": {
			"Green_Burners": ["Green_Burners_1", "Green_Burners_2", "Green_Burners_3", "Green_Burners_4", "Green_Burners_5"],
			"Green_Burners2": ["Green_Burners2_1", "Green_Burners2_2", "Green_Burners2_3", "Green_Burners2_4", "Green_Burners2_5"],
		},
		"others": {
			"Green_Guns": ["Green_Guns_1", "Green_Guns_2", "Green_Guns_3", "Green_Guns_4", "Green_Guns_5"],
			"Green_Hunters": ["Green_Hunters_1", "Green_Hunters_2", "Green_Hunters_3", "Green_Hunters_4", "Green_Hunters_5"],
		},
		# the order rows say group 2: his two burner squads merged into one group
		"groups": [["Green_Burners"], ["Green_Burners", "Green_Burners2"], ["Green_Guns"], ["Green_Hunters"]],
		"at": {
			"Green_Guns_1": ["tank", Vector3(8.125, 0, 90.0)], "Green_Guns_2": ["tank", Vector3(14.625, 0, 90.0)],
			"Green_Guns_3": ["tank", Vector3(21.125, 0, 90.0)], "Green_Guns_4": ["lancer", Vector3(11.375, 0, 101.7)],
			"Green_Guns_5": ["lancer", Vector3(17.875, 0, 101.7)],
			"Green_Hunters_1": ["ifv", Vector3(37.375, 0, 90.0)], "Green_Hunters_2": ["ifv", Vector3(43.875, 0, 90.0)],
			"Green_Hunters_3": ["ifv", Vector3(47.125, 0, 99.54)], "Green_Hunters_4": ["ifv", Vector3(50.375, 0, 90.0)],
			"Green_Hunters_5": ["lancer", Vector3(40.625, 0, 99.54)],
			"Green_Burners_1": ["burner", Vector3(-50.375, 0, 90.0)], "Green_Burners_2": ["burner", Vector3(-40.625, 0, 99.54)],
			"Green_Burners_3": ["burner", Vector3(-43.875, 0, 90.0)], "Green_Burners_4": ["burner", Vector3(-47.125, 0, 99.54)],
			"Green_Burners_5": ["burner", Vector3(-37.375, 0, 90.0)],
			"Green_Burners2_1": ["burner", Vector3(-21.125, 0, 90.0)], "Green_Burners2_2": ["burner", Vector3(-14.625, 0, 90.0)],
			"Green_Burners2_3": ["burner", Vector3(-17.875, 0, 99.54)], "Green_Burners2_4": ["burner", Vector3(-8.125, 0, 90.0)],
			"Green_Burners2_5": ["burner", Vector3(-11.375, 0, 99.54)],
		},
		"click": Vector3(-81.637, 0.0, 45.7407),
		"to": {"Green_Burners": Vector3(-91.154, 0, 58.937), "Green_Burners2": Vector3(-68.317, 0, 31.226)},
	},
}

var _lab: TacticsLab
var _controls: RtsControls
var _case: Dictionary
var _last_tasks := {}


func teardown() -> void:
	RtsControls.order_trace_keep = false
	SelectionSquads.GROUP_GUARD = SelectionSquads.guard_default()
	SelectionSquads.GROUP_VETO = SelectionSquads.veto_default()
	SelectionSquads.GROUP_PACK = SelectionSquads.pack_default()
	SelectionSquads.GROUP_MERGED = SelectionSquads.merged_default()
	SelectionSquads.reset_g1()
	if _controls != null and is_instance_valid(_controls):
		_controls.queue_free()
	_controls = null
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _members(squads: Array) -> Array:
	var out: Array = []
	for squad: String in squads:
		out.append_array((_case["squads"] as Dictionary).get(squad, (_case["others"] as Dictionary).get(squad, [])))
	return out


## `with_elements`: each spawned squad under its own element first, as a skirmish forms them (the lab's default forms none).
func _build(map: String, with_elements := true) -> void:
	_case = CASES[map]
	_lab = TacticsLab.create(self, int(_case["seed"]), map)
	var at: Dictionary = _case["at"]
	for unit_name: String in at:
		_lab.unit(Match.Team.GREEN, unit_name, at[unit_name][1], 0.0, String(at[unit_name][0]))
	await _lab.start()
	if with_elements:
		for group: Dictionary in [_case["squads"], _case["others"]]:
			for squad: String in group:
				var first: String = (group[squad] as Array)[0]
				var faction := String(Units.PROFILES.get(String((_case["at"] as Dictionary)[first][0]), {}).get("faction", ""))
				_lab.element((group[squad] as Array).duplicate(), squad.trim_prefix("Green_"), DoctrineTable.for_faction(faction))
	_controls = RtsControls.new()
	_controls.game_match = _lab.game_match
	_controls.orders = _lab.orders
	_controls.elements = _lab.elements
	_controls.reveal_all = true
	add_to_tree(_controls)
	var number := 1
	for group: Array in _case["groups"]:
		_controls.groups.save(number, _members(group))
		number += 1
	await wait_physics_frames(1)


func _start_of(squad: String) -> Vector3:
	var start := Vector3.ZERO
	var names: Array = (_case["squads"] as Dictionary)[squad]
	for unit_name: String in names:
		start += (_case["at"] as Dictionary)[unit_name][1] / names.size()
	return start


## His click: his merged group selected, one plain move; {squad: the `to` its first vehicle's element got}.
func _click(tag: String) -> Dictionary:
	var click: Vector3 = _case["click"]
	_controls.selection.set_units(_members((_case["squads"] as Dictionary).keys()))
	var found: Dictionary = _controls.selection_squads()
	var blocks := ""
	for squad: Dictionary in found["squads"]:
		var block := _controls._squad_block(squad)
		blocks += " [%s n%d elem %s width %.1f depth %.1f shape %s halt %s]" % [(squad["units"] as Array)[0], (squad["units"] as Array).size(),
				squad.get("element") != null, float(block["width"]), float(block.get("depth", 0.0)), block.get("shape", "-"), block.get("halt", "-")]
	print("HIS_SPREAD %s blocks:%s loose %s" % [tag, blocks, found["loose"]])
	RtsControls.order_trace_keep = true
	var sent := {}  # first unit -> the command's `to` (a loose group's order is a command, not a task)
	var listen := func(command: Dictionary, error: String) -> void:
		if error == "" and command.has("to") and not (command.get("units", []) as Array).is_empty():
			sent[String(command["units"][0])] = Vector3(float(command["to"][0]), 0.0, float(command["to"][1]))
	_controls.command_issued.connect(listen)
	var said := _controls.order_selection("move", {"to": [click.x, click.z]})
	_controls.command_issued.disconnect(listen)
	_last_tasks = {}
	var out := {}
	for squad: String in _case["squads"]:
		var first: String = (_case["squads"][squad] as Array)[0]
		var element: Element = _controls.elements.of(first)
		if element != null and element.task.has("to"):
			out[squad] = Vector3(float(element.task["to"][0]), 0.0, float(element.task["to"][1]))
			_last_tasks[squad] = element.task.duplicate()
		else:
			out[squad] = null
			for unit_name: String in _case["squads"][squad]:
				if sent.has(unit_name):
					out[squad] = sent[unit_name]
	if said != "":
		print("HIS_SPREAD %s refused: %s" % [tag, said])
	for row: Dictionary in RtsControls.order_trace:
		var text := ""
		for place: Dictionary in row["places"]:
			text += " %s:(%.1f, %.1f)" % [String(place["squad"]).trim_prefix("Green_"), (place["at"] as Vector3).x, (place["at"] as Vector3).z]
		print("HIS_SPREAD %s stage %-14s%s" % [tag, row["stage"], text])
	var text := ""
	for squad: String in out:
		text += " %s:%s" % [squad.trim_prefix("Green_"), out[squad]]
	print("HIS_SPREAD %s places%s spread %.1f m" % [tag, text, _spread(out)])
	return out


static func _spread(places: Dictionary) -> float:
	var far := 0.0
	var list := places.values()
	for i in list.size():
		for j in range(i + 1, list.size()):
			if list[i] != null and list[j] != null:
				far = maxf(far, Vector2((list[i] as Vector3).x - (list[j] as Vector3).x, (list[i] as Vector3).z - (list[j] as Vector3).z).length())
	return far


func _today(map: String, with_elements: bool) -> Dictionary:
	await _build(map, with_elements)
	SelectionSquads.GROUP_MERGED = false
	return _click("%s today elements %s" % [map, with_elements])


func _merged(map: String, with_elements: bool) -> Dictionary:
	await _build(map, with_elements)
	SelectionSquads.GROUP_MERGED = true
	return _click("%s merged elements %s" % [map, with_elements])


## The mechanism, today (the merge OFF): his two squads abreast across the approach, as far apart as he saw. Crossing: the
## lab forms no elements, as at his tick 0 the Wrenches had none (their order row is a loose group's, `source: player`).
func test_crossing_today_reproduces_his_places() -> void:
	var laid := await _today("crossing", false)
	for squad: String in _case["to"]:
		assert_true(laid[squad] != null and (laid[squad] as Vector3).distance_to(_case["to"][squad]) < 3.0,
				"%s: laid %s v his recording %s" % [squad, laid[squad], _case["to"][squad]])


func test_locks_today_reproduces_his_places() -> void:
	var laid := await _today("locks", true)
	for squad: String in _case["to"]:
		assert_true(laid[squad] != null and (laid[squad] as Vector3).distance_to(_case["to"][squad]) < 3.0,
				"%s: laid %s v his recording %s" % [squad, laid[squad], _case["to"][squad]])


## R47.4 ON: his merged group stands as one double file at his click: every squad a squad of its own (no loose crews), the
## squads' spots one pitch apart (<= 20 m v 61 / 36 m), both heads on the click line, each squad told to halt as a file there.
func _assert_merged(map: String, with_elements: bool) -> void:
	var laid := await _merged(map, with_elements)
	var click: Vector3 = _case["click"]
	var spread := _spread(laid)
	print("HIS_SPREAD %s merged spread %.1f m (laid %d refused %d)" % [map, spread, SelectionSquads.merged_laid, SelectionSquads.merged_refused])
	for squad: String in _case["squads"]:
		assert_true(laid[squad] != null, "%s got a place" % squad)
		assert_true(_last_tasks.has(squad), "%s is ordered as a squad (its own element's task)" % squad)
		if not _last_tasks.has(squad):
			continue
		var task: Dictionary = _last_tasks[squad]
		assert_eq(String(task.get("halt_shape", "")), "column", "%s halts as a file" % squad)
		assert_true(String(task.get("formation", "")) != "column", "%s travels in its own shape (files only at the end, R47.21)" % squad)
		assert_true(task.has("halt_at") and task.has("lay"), "%s: its halt's spot and heading ride the task" % squad)
		assert_true((laid[squad] as Vector3).distance_to(click) <= 12.0, "%s's spot within a pitch of his click (%.1f m)" % [
				squad, (laid[squad] as Vector3).distance_to(click)])
	assert_true(spread <= 20.0, "the squads' spots together (%.1f m)" % spread)


func test_crossing_merged_stands_one_double_file() -> void:
	await _assert_merged("crossing", false)


func test_locks_merged_stands_one_double_file() -> void:
	await _assert_merged("locks", true)


## Byte-identity: the same two squads selected WITHOUT the merge (each recalled, not one group of ten) lay as today with the
## switch ON (Locks: group 1 = Burners alone, Burners2 picked up by its element).
func test_two_squads_not_merged_lay_as_today() -> void:
	await _build("locks", true)
	_case = (CASES["locks"] as Dictionary).duplicate(true)
	_case["groups"] = [["Green_Burners"], ["Green_Burners2"], ["Green_Guns"], ["Green_Hunters"]]
	_controls.groups.save(2, _members(["Green_Burners2"]))
	SelectionSquads.GROUP_MERGED = false
	var off := _click("locks unmerged off")
	SelectionSquads.GROUP_MERGED = true
	var on := _click("locks unmerged on")
	for squad: String in off:
		assert_eq(on[squad], off[squad], "%s: the same place with the switch ON" % squad)


## Pure: the heads stand across the heading, a gap apart, left to right as the blocks stand; a file's seats run back.
func test_merged_heads_and_seats() -> void:
	var blocks := [{"center": Vector3(10.0, 0.0, 50.0)}, {"center": Vector3(-10.0, 0.0, 50.0)}]
	var heads := SelectionSquads.merged_heads(blocks, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 16.0)
	assert_eq(heads.size(), 2, "two heads")
	assert_true(heads[0].distance_to(Vector3(8.0, 0.0, 0.0)) < 0.01 and heads[1].distance_to(Vector3(-8.0, 0.0, 0.0)) < 0.01,
			"the east squad's head east, 16 m apart: %s" % [heads])
	var seats := SelectionSquads.merged_file_seats(heads[0], Vector3(0.0, 0.0, -1.0), 5, 14.0)
	assert_eq(seats.size(), 5, "five seats")
	assert_true(seats[4].distance_to(Vector3(8.0, 0.0, 56.0)) < 0.01, "the last seat 56 m back toward where they came from: %s" % [seats[4]])
