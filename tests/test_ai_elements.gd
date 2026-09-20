extends TestCase
## Round-4 X1 (_agents/streams/archive/round4/ai.md): the L1 seam. ElementFeed normalizes whatever doctrine's `Elements` publishes
## into the few things a brain executes — my slot, my sector of fire, and whether I am the half that moves or the half
## that shoots. Behavior on the real arena: tests/ai_scenarios/scenario_elements.gd.
##
## The point of these tests is that the feed degrades: doctrine may ship a leaner state() than the stub does, and a
## brain that learns nothing from it must behave exactly as it did before elements existed.


class FakeElement extends RefCounted:
	var value := {}

	func _init(p_state: Dictionary) -> void:
		value = p_state

	func state() -> Dictionary:
		return value


static func _context(state: Dictionary, unit := "Green_A_2") -> Dictionary:
	return ElementFeed.normalize(FakeElement.new(state), unit)


func test_it_reads_a_slot_with_a_position_a_sector_and_a_role() -> void:
	var context := _context({"id": "Alpha", "leader": "Green_A_1", "members": ["Green_A_1", "Green_A_2"],
			"formation": "line", "technique": "bounding_overwatch", "drill": "react_to_contact", "task": "move",
			"slots": {"Green_A_2": {"position": [-104.0, 20.0], "facing": [-1.0, 0.0], "role": "overwatch"}}})
	assert_eq(context["id"], "Alpha", "the element id, as text")
	assert_eq(context["leader"], "Green_A_1", "who the leader is")
	assert_true(not bool(context["is_leader"]), "Green_A_2 is not the leader")
	assert_eq(context["formation"], "line", "the formation the leader chose")
	assert_eq(context["technique"], "bounding_overwatch", "the movement technique")
	assert_eq(context["drill"], "react_to_contact", "the drill in force")
	assert_eq(context["task"], "move", "the task the element was assigned")
	assert_eq(context["slot"], Vector3(-104.0, 0.0, 20.0), "a flat world position")
	assert_eq(context["facing"], Vector3(-1.0, 0.0, 0.0), "a unit direction")
	assert_eq(context["role"], "overwatch", "and what this unit is doing in it")


func test_a_leaner_state_leaves_the_brain_where_it_was() -> void:
	# No slots, no technique, no drill: nothing for a brain to execute, and nothing it does differently.
	var context := _context({"id": "Alpha", "leader": "Green_A_1", "members": ["Green_A_1", "Green_A_2"]})
	assert_eq(context["slot"], null, "no slot, so nothing to hold")
	assert_eq(context["facing"], null, "and no sector to cover")
	assert_eq(context["role"], "", "no role was given and none is invented")
	assert_true(not ElementFeed.is_firing_base(context), "so it is not held in place")
	assert_eq(TankBrain.element_slot({"element": context}), null, "and nothing leashes it")
	assert_true(ElementFeed.in_sector(context, Vector3.ZERO, Vector3(0, 0, -30)), "every bearing is in sector")


func test_a_bare_position_per_unit_is_a_slot_too() -> void:
	var context := _context({"slots": {"Green_A_2": [10.0, -4.0]}})
	assert_eq(context["slot"], Vector3(10.0, 0.0, -4.0), "a bare [x, z] is a world slot")
	assert_eq(context["facing"], null, "a bare position carries no sector")


func test_slots_may_be_a_list_parallel_to_the_members() -> void:
	var context := _context({"members": ["Green_A_2", "Green_A_1"],
			"slots": [{"position": [1.0, 2.0]}, {"position": [3.0, 4.0]}]})
	# members are read in sorted order, so Green_A_1 is first whatever order the source listed them in.
	assert_eq(context["members"], PackedStringArray(["Green_A_1", "Green_A_2"]), "members are sorted, whatever order the source listed them in")
	assert_eq(context["slot"], Vector3(3.0, 0.0, 4.0), "the entry at my place in the sorted members")


func test_a_technique_a_drill_or_a_task_we_dont_know_is_dropped() -> void:
	var context := _context({"technique": "teleporting", "drill": "vibes", "task": "conquer"})
	assert_eq(context["technique"], "", "an unknown technique is dropped")
	assert_eq(context["drill"], "", "so is an unknown drill")
	assert_eq(context["task"], "", "and an unknown task")


func test_the_half_that_moves_can_be_named_instead_of_a_role_per_unit() -> void:
	var bounding := {"technique": "bounding_overwatch", "moving": ["Green_A_1"],
			"slots": {"Green_A_1": [0.0, 0.0], "Green_A_2": [10.0, 0.0]}}
	assert_eq(_context(bounding, "Green_A_1")["role"], "bound", "the named moving half is bounding")
	assert_eq(_context(bounding, "Green_A_2")["role"], "overwatch", "the named moving half is bounding")
	var sbf := {"drill": "support_by_fire", "moving": ["Green_A_1"],
			"slots": {"Green_A_1": [0.0, 0.0], "Green_A_2": [10.0, 0.0]}}
	assert_eq(_context(sbf, "Green_A_1")["role"], "maneuver", "the moving half of a support-by-fire is the maneuver element")
	assert_eq(_context(sbf, "Green_A_2")["role"], "base_of_fire", "the moving half of a support-by-fire is the maneuver element")


func test_only_the_halves_that_shoot_are_held_in_place() -> void:
	for role: String in ["overwatch", "base_of_fire"]:
		assert_true(ElementFeed.is_firing_base({"role": role}), "%s holds where it stands and shoots" % role)
	for role: String in ["bound", "maneuver", ""]:
		assert_true(not ElementFeed.is_firing_base({"role": role}), "%s is meant to be moving" % role)


func test_every_element_member_fights_from_the_slot_it_was_given() -> void:
	# Round 4 read this the other way round: `bound` and `maneuver` got NO slot, so "a unit told to cover ground is
	# free to move" was delivered by the absence of a leash. Round 9 (X3) overturns that, on nav's A7 finding, and
	# the round-4 intent is preserved by WHERE the slot is rather than by there being none: an element publishes a
	# bounding team's slot at its next bound's anchor and a manoeuvre element's at the flank it was sent to, so the
	# slot is the ground it was told to cover. nav's A7 bounds a candidate against that region with "inside it, and
	# if you are outside do not get further outside", which makes a leash on a slot 40 m ahead a convergence
	# guarantee rather than a cage.
	#
	# Why it had to change: under the blended steering the weapon band and the slot compromised to ~15 m of drift
	# with no leash involved at all; under A7's strict priority the weapon level wins and the same element drifts
	# 42 m -- every vehicle holding its own band, which is the lead's "just these 2 masses shooting at each other".
	# The accident was doing load-bearing work (nav, 2026-09-20, `stream/nav` at b6d72f52).
	var slot := Vector3(10, 0, 10)
	for role: String in ["overwatch", "base_of_fire", "bound", "maneuver", ""]:
		assert_eq(TankBrain.element_slot({"element": {"role": role, "slot": slot}}), slot,
				"%s fights from the slot its element gave it" % role)
	assert_eq(TankBrain.element_slot({}), null, "no element, no leash")
	assert_eq(TankBrain.element_slot({"element": {"role": "bound"}}), null,
			"an element that publishes no slot leashes nobody")


func test_the_leash_radius_is_the_elements_own_spacing() -> void:
	# X1: "one formation spacing" is a real per-element number now, so the leash grows with the hulls instead of
	# staying at a constant written for a 4 m tank. It is never tighter than it was.
	assert_near(TankBrain.slot_leash(null), TankBrain.SLOT_LEASH, 0.001, "nothing to read, nothing changes")
	assert_near(TankBrain.slot_leash({"role": "bound"}), TankBrain.SLOT_LEASH, 0.001, "no pitch, no change")
	assert_near(TankBrain.slot_leash({"pitch": Vector2(8.0, 9.0)}), TankBrain.SLOT_LEASH, 0.001,
			"a tight formation does not tighten the leash below what it has always been")
	assert_near(TankBrain.slot_leash({"pitch": Vector2(14.0, 22.0)}), 22.0, 0.001,
			"a formation spaced by its hulls is leashed to that spacing, on its larger axis")


func test_a_sector_of_fire_is_a_cone_around_my_facing() -> void:
	var context := {"facing": Vector3(0, 0, -1)}
	var me := Vector3(0, 0, 0)
	assert_true(ElementFeed.in_sector(context, me, Vector3(0, 0, -40)), "dead ahead")
	assert_true(ElementFeed.in_sector(context, me, Vector3(30, 0, -40)), "37 degrees off is inside 60")
	assert_true(ElementFeed.in_sector(context, me, Vector3(40, 0, -30)), "53 degrees is still inside")
	assert_true(not ElementFeed.in_sector(context, me, Vector3(40, 0, -20)), "63 degrees is outside")
	assert_true(not ElementFeed.in_sector(context, me, Vector3(40, 0, 0)), "abeam is outside")
	assert_true(not ElementFeed.in_sector(context, me, Vector3(0, 0, 40)), "and behind me certainly is")
	assert_true(ElementFeed.in_sector(context, me, me), "something on top of me is always in sector")


func test_a_brain_re_decides_only_when_the_leaders_call_changes() -> void:
	var moving := _context({"technique": "bounding_overwatch", "moving": ["Green_A_2"],
			"slots": {"Green_A_2": [0.0, 0.0]}})
	var moved := _context({"technique": "bounding_overwatch", "moving": ["Green_A_2"],
			"slots": {"Green_A_2": [0.0, 0.0]}})
	assert_true(not ElementFeed.changed(moving, moved), "nothing changed")
	var halted := _context({"technique": "bounding_overwatch", "moving": [],
			"slots": {"Green_A_2": [0.0, 0.0]}})
	assert_true(ElementFeed.changed(moving, halted), "the leader called the halt")
	assert_true(ElementFeed.changed({}, moving), "and joining an element counts too")
