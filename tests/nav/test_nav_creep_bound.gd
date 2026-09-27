extends TestCase
## Round 12 (nav N6, from squad's S6): a wheeled hull cannot pivot, so a `face` order becomes the plant's creep — half-
## second legs alternating forward and reverse while yawing. A forward arc and a reverse arc on the same yaw curve round
## opposite centres, so strict alternation WALKS the hull: squad measured an arrived scout drifting 1.5 m -> 8.6 m off
## its slot over 15 s of idle facing. N1's guarantee is that a hull that has arrived stays arrived.
##
## A scout in the open, told to face points round the compass one after another (an idle brain's facing, a minute of it).
## Control (`--nav-off=creepbound`): it walks off. Fix: it stays within a few metres of where it started, and still turns.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 60.0)
## Facing targets, each held for FACE_SECONDS: right, behind, left, ahead-right... far enough to be pure headings.
const FACES := [90.0, 200.0, 290.0, 30.0, 150.0, 250.0]
const FACE_SECONDS := 5.0


func _face_round(bound: bool) -> Dictionary:
	await ArenaFixture.build(self, "yard")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = PackedStringArray() if bound else PackedStringArray(["creepbound"])
	var tank := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	tank.global_position = START
	tank.rotation.y = 0.0
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	var farthest := 0.0
	var worst_error := 0.0
	for deg: float in FACES:
		var aim := Vector3(sin(deg_to_rad(deg)), 0.0, -cos(deg_to_rad(deg)))
		var look := tank.global_position + aim * 40.0
		orders.set_orders({"type": "face", "x": look.x, "z": look.z}, {"type": "hold_fire"})
		for frame in int(SimClock.TICK_RATE * FACE_SECONDS):
			await tree.physics_frame
			farthest = maxf(farthest, Vector2(tank.global_position.x - START.x, tank.global_position.z - START.z).length())
		var nose := -tank.global_basis.z
		worst_error = maxf(worst_error, rad_to_deg(absf(Vector3(nose.x, 0.0, nose.z).signed_angle_to(aim, Vector3.UP))))
	Movement._off = saved
	return {"farthest_m": farthest, "worst_error_deg": worst_error, "at": tank.global_position}


func test_control_strict_alternation_walks_the_scout_off_its_spot() -> void:
	var control := await _face_round(false)
	assert_true(control["farthest_m"] > 5.0, "control (creepbound off): a minute of facing walks it off (%s)" % control)


func test_a_wheeled_hull_turning_in_place_stays_near_its_spot_and_still_turns() -> void:
	var bound := await _face_round(true)
	assert_true(bound["farthest_m"] < 3.5, "it stays within a few metres of where it started (%s)" % bound)
	assert_true(bound["worst_error_deg"] < 25.0, "and still ends each facing on its heading (%s)" % bound)
