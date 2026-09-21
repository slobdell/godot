extends TestCase
## Round 9, control item 1: the desktop right-DRAG gives a move order its arrival heading, through Godot's real
## input pipeline (Viewport.push_input). Press = the destination, release = which way to be facing when you get
## there; a right click with no drag is today's plain move and carries no facing at all.
##
## Why this test exists at all: `Orders` has carried `"facing"` end to end since round 6 and nav grew an
## arrive-on-heading arc in round 8, but NOTHING IN THE GAME THE LEAD PLAYS EVER SENT ONE - the only caller was
## the touch map behind `--touch-map`, so nav's A/B read "gates aimed 0" in both arms. These assertions are what
## makes that arm live by construction: if the facing stops reaching `Orders`, (a) fails.

const Fixture := preload("res://tests/support/control_fixture.gd")

## Empty ground on the fixture's west side, well clear of the row of vehicles at z = 40.
const LANE_X := -30.0


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	return f


static func _facing(order: Dictionary) -> Vector2:
	var way: Array = order.get("facing", [])
	return Vector2(float(way[0]), float(way[1])) if way.size() == 2 else Vector2.ZERO


func test_a_right_drag_on_the_ground_says_which_way_to_arrive_facing() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	var destination := Vector3(LANE_X, 0.0, 10.0)
	var toward := Vector3(LANE_X, 0.0, -10.0)  # 20 m north of the destination: arrive facing -Z
	await f.right_drag(f.ground(destination), f.ground(toward))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "move", "a right drag is still a move order")
	var to: Array = order.get("to", [])
	assert_true(to.size() == 2 and Vector2(to[0], to[1]).distance_to(Vector2(destination.x, destination.z)) < 2.0,
			"the PRESS point is the destination, not the release point: %s" % [to])
	assert_true(order.has("facing"), "a right drag puts a facing on the order")
	var way := _facing(order)
	assert_true(way.distance_to(Vector2(0, -1)) < 0.08,
			"the facing points from the destination toward the release point, got %s" % [way])


func test_a_right_click_with_no_drag_carries_no_facing_at_all() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.right_click(f.ground(Vector3(LANE_X, 0.0, 10.0)))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "move", "a plain right click is still a move")
	assert_true(not order.has("facing"),
			"a click with no drag must leave the key ABSENT (nav then pivots as it always did), got %s" % [order])
	# A twitch of the hand is a click, not a gesture: below the threshold nothing changes.
	var at := f.ground(Vector3(LANE_X, 0.0, 20.0))
	await f.right_drag(at, at + Vector2(0.0, -4.0))
	assert_true(not f.orders.current("Green_Alpha_1").has("facing"),
			"a 4 px twitch is a click, not a facing drag")


func test_a_right_drag_never_selects_and_never_opens_a_box() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	var before := f.controls.selection.units.duplicate()
	# Drag right across the whole row of vehicles: a LEFT drag here would box every one of them.
	await f.right_drag(f.screen("Green_Alpha_1") + Vector2(-40.0, -40.0), f.screen("Green_Bravo_2") + Vector2(40.0, 40.0))
	assert_eq(f.controls.selection.units, before, "a right drag leaves the selection exactly as it was")
	assert_true(not f.controls._boxing, "a right drag never opens the selection box")
	assert_true(f.orders.current("Green_Alpha_1").has("facing"), "and it still orders the one selected unit")


func test_a_right_drag_over_an_enemy_still_attacks_it_on_the_press() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.right_drag(f.screen("Rust_Alpha_1"), f.screen("Rust_Alpha_1") + Vector2(60.0, 60.0))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "attack", "pressing on an enemy is an attack, drag or no drag")
	assert_eq(String(order.get("target", "")), "Rust_Alpha_1", "and it is that enemy")
	assert_true(not order.has("facing"), "an attack takes its heading from its target, not from the hand")


func test_shift_queues_a_facing_drag_like_any_other_order() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.right_click(f.ground(Vector3(LANE_X, 0.0, 10.0)))
	await f.right_drag(f.ground(Vector3(LANE_X, 0.0, -10.0)), f.ground(Vector3(LANE_X + 20.0, 0.0, -10.0)), true)
	assert_eq(f.orders.queue("Green_Alpha_1").size(), 1, "shift queues the dragged order behind the first")
	var queued: Dictionary = f.orders.queue("Green_Alpha_1")[0]
	assert_true(queued.has("facing"), "the queued order keeps its facing")
	assert_true(_facing(queued).distance_to(Vector2(1, 0)) < 0.08,
			"queued facing points east, got %s" % [_facing(queued)])


func test_an_armed_mode_eats_the_press_and_the_release_orders_nothing() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_A)  # attack-move armed: right cancels it, StarCraft-style
	assert_eq(f.controls.mode, "attack_move", "setup: the mode is armed")
	await f.right_drag(f.ground(Vector3(LANE_X, 0.0, 10.0)), f.ground(Vector3(LANE_X, 0.0, -10.0)))
	assert_eq(f.controls.mode, "", "the right press disarms")
	assert_true(f.orders.current("Green_Alpha_1").is_empty(),
			"and the release that cancelled a mode must not also issue a move")


## The one that decides the threshold's units. At the lead's pose (21°, FOV 35, 49 m out) the ground under the
## screen is wildly foreshortened: an 18 px drag near the top of the frame spans tens of metres and the same 18 px
## near the bottom spans well under one. A threshold in METRES (the touch map's 4.0) would therefore make the same
## hand gesture mean different things in different halves of the screen - a facing up top, a silent plain move down
## below. The threshold is in PIXELS, because the gesture is made with a hand on a screen; the metres only have to
## be non-degenerate, and the direction is exact either way.
func test_the_same_hand_gesture_means_the_same_thing_anywhere_on_his_screen() -> void:
	var f := await _setup()
	var lens: float = RtsCamera.fov
	RtsCamera.fov = RtsCamera.FOV_DEG  # 35°, the lead's telephoto
	f.rig.pitch = RtsCamera.DEFAULT_PITCH_DEG  # 21°
	f.rig.zoom = RtsCamera.level_for(49.0)  # his distance
	f.rig.focus = Vector3.ZERO
	f.rig.snap()
	f.place("Rust_Alpha_1", Vector3(0.0, 0.0, -100.0))  # out of the way: a press on an enemy is an attack
	await wait_physics_frames(2)
	f.controls.selection.set_units(["Green_Alpha_1"])
	var screen := Vector2(tree.root.size)
	var pull := Vector2(0.0, -24.0)  # the same upward flick in both places
	var aim := -f.camera.global_basis.z
	var forward := Vector2(aim.x, aim.z).normalized()  # away from the camera, on the ground
	var results := {}
	for where: Array in [["near the horizon", Vector2(screen.x * 0.5, screen.y * 0.06)],
			["near the bottom", Vector2(screen.x * 0.5, screen.y * 0.96)]]:
		await f.right_drag(where[1], where[1] + pull)
		var order := f.orders.current("Green_Alpha_1")
		results[where[0]] = order
		assert_true(order.has("facing"), "%s: a 24 px flick reads as a facing, got %s" % [where[0], order])
		assert_true(_facing(order).dot(forward) > 0.9,
				"%s: dragging up-screen means 'face away from me', got %s" % [where[0], _facing(order)])
	print("MEASURE facing_drag_at_the_leads_pose ", JSON.stringify({
			"pitch_deg": RtsCamera.DEFAULT_PITCH_DEG, "fov_deg": RtsCamera.FOV_DEG, "distance_m": 49.0,
			"flick_px": 24.0,
			"near_horizon_to": results["near the horizon"].get("to", []),
			"near_bottom_to": results["near the bottom"].get("to", [])}))
	RtsCamera.fov = lens


## The pin's heading chevron must read AS AN ARROW on the screen, at the pose the lead actually plays, including
## the worst case: a heading pointing straight away from the camera, where the ground foreshortens hardest and the
## chevron shares screen-vertical with the pin's own stalk. The first two attempts both failed here - a line, then
## a chevron sized in metres - and both passed every test that only asked "is a facing on the pin".
func test_the_pin_chevron_reads_as_an_arrow_and_not_a_tick() -> void:
	var f := await _setup()
	f.rig.zoom = RtsCamera.level_for(49.0)
	f.rig.focus = Vector3.ZERO
	f.rig.snap()
	await wait_physics_frames(2)
	var aim := -f.camera.global_basis.z
	var away := Vector3(aim.x, 0.0, aim.z).normalized()  # the hard one: pointing away, down the screen's vertical
	var toward := -away
	var across := Vector3(-away.z, 0.0, away.x)
	var measured := {}
	for case: Array in [["away", away], ["toward", toward], ["across", across]]:
		var shape := f.controls.ordered_facing_shape(Vector3.ZERO, case[1] as Vector3)
		assert_true(not shape.is_empty(), "%s: no chevron shape was found at the lead's pose" % case[0])
		var span := float(shape["span_px"])
		var stand := float(shape["stand_px"])
		assert_true(stand >= span * RtsControls.ORDER_FACING_NOSE,
				"%s: the nose stands off %.1f px against a %.1f px span - that reads as a tick" % [case[0], stand, span])
		assert_true(span >= RtsControls.ORDER_FACING_MIN_SPAN_PX,
				"%s: a %.1f px span is a smudge" % [case[0], span])
		measured[case[0]] = {"arm_m": snappedf(float(shape["arm_m"]), 0.01),
				"span_px": roundi(span), "stand_px": roundi(stand)}
	# Metres, not pixels, are what changes with the pose: the shape is the constant and the ground pays for it.
	assert_true(float(measured["away"]["arm_m"]) > float(measured["across"]["arm_m"]),
			"pointing away costs more ground than pointing across, got %s" % [measured])
	print("MEASURE pin_chevron_shape ", JSON.stringify({
			"pitch_deg": RtsCamera.DEFAULT_PITCH_DEG, "distance_m": 49.0,
			"nose_ratio": RtsControls.ORDER_FACING_NOSE, "cases": measured}))
