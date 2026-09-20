extends TestCase
## Round 9 (nav, round 8's last open stretch item): **a `face` order had no recovery.** `Movement.unstick` runs only
## for a `move_to` and the mover is `idle()` under a face, so a wheeled hull wedged against scenery creeps for ever
## on `WHEELS_MIN_THROTTLE` and nothing notices.
##
## It is the lead's complaint directly. Round 8 measured what it looks like from his camera: the War Rig's apparent
## pivot IS the creep's legs cancelling against props — **26 degrees within 1.5 m on yard against 7 degrees on bare
## ground at every hull length**. The hull is neither turning nor going anywhere, and N1's guarantee — *"it never
## stands still silently"* — had a `face` order as its one exemption.
##
## OPT-IN (`--nav-off=facegiveup` turns it ON), because it is behaviour on the default path.

const MATCH := preload("res://game/match/match.tscn")


static func _giveup(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["facegiveup"]) if on else PackedStringArray()
	Movement._off_parsed = true
	OrderController.face_giveups = 0
	OrderController.face_checked = 0
	return was


## THE GUARD, first: a hull that CAN come round must still come round. A recovery that fires on a healthy face would
## break the one thing the order is for, and it would do it behind a flag where nobody looks.
func test_a_car_with_room_still_turns_to_its_face() -> void:
	var was := _giveup(true)
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Turner", 0, Match.Team.GREEN, "ifv")
	tank.global_position = Vector3(-100, 0, 40)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "face", "x": -60.0, "z": 40.0}, {"type": "hold_fire"}), "", "told to face east")
	for frame in int(SimClock.TICK_RATE * 8):
		await tree.physics_frame
	var east := (-tank.global_basis.z).dot(Vector3.RIGHT)
	var stalled := ctl.face_stalled
	Movement._off = was
	assert_true(east > 0.7, "a car with open ground comes round (dot %.2f)" % east)
	assert_true(not stalled, "and is never reported as unable to (%s)" % stalled)


## The arithmetic of the window itself, so the bar is checkable without a wedged hull: under FACE_STALL_DEG of turn
## across FACE_STALL_SECONDS is a shuffle, not a rotation. Round 8's bare-ground figure was 7 degrees and its
## against-scenery figure 26, so a 3 degree bar sits well below both and does not fire on either.
func test_the_stall_bar_sits_below_the_numbers_round_8_measured() -> void:
	assert_true(OrderController.FACE_STALL_DEG < 7.0,
			"3 degrees is below round 8's 7-degree bare-ground turn, so an unobstructed hull never trips it")
	assert_true(OrderController.FACE_STALL_SECONDS >= 1.0,
			"and the window is long enough that a hull mid-swing is not called stalled")


## The arm, provable from outside (lesson 147): `face_checked` is the denominator, so a zero in `face_giveups` is
## distinguishable from a mechanism nothing reached — which is round 8's `gates aimed 0` in a new place.
func test_the_counter_distinguishes_never_checked_from_never_stalled() -> void:
	var was := _giveup(true)
	assert_eq(OrderController.face_checked, 0, "nothing checked yet")
	assert_eq(OrderController.face_giveups, 0, "and nothing given up")
	Movement._off = was
	assert_true(not OrderController.face_giveup_on(), "and the switch is OFF by default, like every round-9 row")
