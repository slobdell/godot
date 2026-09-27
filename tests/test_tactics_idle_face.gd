extends TestCase
## Round 13, squad Q2 (S6, the lead's answer 3 measured rather than asked again): after a squad arrives, wheeled scouts
## with FIXED guns were told to face their sector with nothing in sight, and a wheeled hull turns in place only by a
## multi-point turn that walked it off its slot. With `TankBrain.IDLE_FACE_NO_PIVOT` on, such a face is a stop -- unless
## the unit's own order names a facing (a hold's `facing`, an ambush's), which is never touched. Asserted as a MECHANISM,
## with controls: the same squad with the switch off, and the tracked tank beside the scouts.


func _squad(switch_on: bool, task: Dictionary, seconds: float) -> Dictionary:
	var was := TankBrain.IDLE_FACE_NO_PIVOT
	TankBrain.IDLE_FACE_NO_PIVOT = switch_on
	var lab := TacticsLab.create(self, 5)
	var names: Array = []
	var ids := ["scout", "scout", "tank"]
	for i in ids.size():
		var tank := lab.unit(Match.Team.GREEN, "Green_F_%d" % (i + 1), Vector3(-60 + i * 9.0, 0, 60), PI, ids[i])
		names.append(String(tank.name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	element.assign(task)
	for tick in int(SimClock.TICK_RATE * seconds):
		await lab.step()
	var result := {"scout_declined": 0, "scout_faces": {}, "tank_faces": {}}
	for unit_name: String in names:
		var brain := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
		var key := "tank_faces" if unit_name.ends_with("3") else "scout_faces"
		if unit_name != "Green_F_3":
			result["scout_declined"] += brain.idle_faces_declined
		for source: String in brain.idle_faces:
			result[key][source] = int(result[key].get(source, 0)) + int(brain.idle_faces[source])
	lab.dispose()
	TankBrain.IDLE_FACE_NO_PIVOT = was
	return result


func test_the_hull_it_is_about() -> void:
	assert_true(TankBrain.no_pivot_fixed_gun("scout"), "the Condemned scout: wheels and a fixed gun")
	assert_true(TankBrain.no_pivot_fixed_gun("gang_scout") and TankBrain.no_pivot_fixed_gun("law_scout"), "every scout")
	assert_true(not TankBrain.no_pivot_fixed_gun("ifv"), "a wheeled turret is the round-8 rule's, not this one's")
	assert_true(not TankBrain.no_pivot_fixed_gun("tank"), "a tracked hull pivots")
	assert_true(not TankBrain.no_pivot_fixed_gun("syn_scout"), "a hover hull pivots")


func test_an_arrived_scout_with_nothing_in_sight_is_not_told_to_face() -> void:
	var move := {"verb": "move", "to": [-51.0, 30.0], "drills": false}
	var off: Dictionary = await _squad(false, move, 20.0)
	var on: Dictionary = await _squad(true, move, 20.0)
	print("MEASURE idle_face plain move: off %s | on %s" % [off, on])
	var faced_off := 0
	for source: String in off["scout_faces"]:
		if source != "order":
			faced_off += int(off["scout_faces"][source])
	assert_true(faced_off > 0, "control: with the switch off the scouts ARE told to face with nothing in sight (%s)"
			% off["scout_faces"])
	assert_true(int(on["scout_declined"]) > 0, "switch on: those faces become stops (%d)" % on["scout_declined"])


func test_a_hold_with_an_ordered_facing_still_turns_the_scouts() -> void:
	var hold := {"verb": "hold", "to": [-51.0, 60.0], "facing": [1.0, 0.0]}
	var on: Dictionary = await _squad(true, hold, 12.0)
	print("MEASURE idle_face hold with facing: on %s" % on)
	assert_true(int(on["scout_faces"].get("order", 0)) > 0,
			"a hold's facing reaches the scouts as an ORDERED facing (%s)" % on["scout_faces"])
	assert_eq(int(on["scout_declined"]), 0, "and none of it is declined: the hold's facing is untouched")
