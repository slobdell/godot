extends TestCase
## Round 34 (C34.11, O1; his "one of them was all the way across the bridge, thus causing one of my squads of scouts to
## go on a suicidal mission"): SelectionSquads.ground_cap. An anchor stands only where the CLICK reaches it directly
## by ground (drive <= 1.5 x straight + 8 m, no bridge deck on the way); otherwise it comes back toward the click.
## The pure cases use a hand-made river (z 2..26, a bridge at x = -92, the Crossing's west reach); the last case is the
## Crossing itself, its navmesh and its deck.


func teardown() -> void:
	SelectionSquads.GROUND_CAP = true
	super.teardown()


const BRIDGE_X := -92.0
const NORTH_BANK := 26.0
const SOUTH_BANK := 2.0


static func _north(p: Vector3) -> bool:
	return p.z >= (NORTH_BANK + SOUTH_BANK) * 0.5


## Drive by the bridge when the ends are on different banks.
static func _drive(a: Vector3, b: Vector3) -> float:
	if _north(a) == _north(b):
		return Vector2(b.x - a.x, b.z - a.z).length()
	var near := Vector3(BRIDGE_X, 0, NORTH_BANK if _north(a) else SOUTH_BANK)
	var far := Vector3(BRIDGE_X, 0, SOUTH_BANK if _north(a) else NORTH_BANK)
	return a.distance_to(near) + near.distance_to(far) + far.distance_to(b)


static func _crosses(a: Vector3, b: Vector3) -> bool:
	return _north(a) != _north(b)


## Out of the water onto the nearer bank.
static func _clamp(p: Vector3) -> Vector3:
	if p.z > SOUTH_BANK and p.z < NORTH_BANK:
		return Vector3(p.x, 0, NORTH_BANK if _north(p) else SOUTH_BANK)
	return p


func _three_beside_the_bridge() -> Array[Vector3]:
	# Three squads of five coming from the east, clicked on the north bank by the bridge: abreast along z.
	var blocks := []
	for i in 3:
		blocks.append({"center": Vector3(10.0, 0, 40.0 + i * 4.0), "width": SelectionSquads.width("auto", 5),
				"depth": SelectionSquads.depth("auto", 5)})
	return SelectionSquads.ranks(blocks, Vector3(BRIDGE_X, 0, 40.0))


func test_setup_today_one_anchor_is_across_the_river() -> void:
	var anchors := _three_beside_the_bridge()
	var across := anchors.filter(func(p: Vector3) -> bool: return not _north(p))
	assert_eq(across.size(), 1, "today one of the three stands across (%s)" % [anchors])


func test_no_anchor_stands_across_a_bridge_he_did_not_click_past() -> void:
	var click := Vector3(BRIDGE_X, 0, 40.0)
	var capped := SelectionSquads.ground_cap(_three_beside_the_bridge(), click, _drive, _crosses, _clamp)
	for p in capped:
		assert_true(_north(p) and not (p.z > SOUTH_BANK and p.z < NORTH_BANK), "every anchor on his bank, dry (%s)" % p)


func test_anchors_the_click_reaches_directly_are_untouched() -> void:
	var anchors: Array[Vector3] = [Vector3(-40, 0, 60), Vector3(-40, 0, 90), Vector3(-40, 0, 120)]
	var capped := SelectionSquads.ground_cap(anchors, Vector3(-40, 0, 90), _drive, _crosses, _clamp)
	assert_eq(capped, anchors, "open ground on one bank: the layout stands")


func test_a_long_detour_comes_back_even_with_no_bridge() -> void:
	# A wall: anything west of x = -60 is 200 m round by ground.
	var walled := func(a: Vector3, b: Vector3) -> float:
		var d := Vector2(b.x - a.x, b.z - a.z).length()
		return d + (200.0 if (a.x < -60.0) != (b.x < -60.0) else 0.0)
	var never := func(_a: Vector3, _b: Vector3) -> bool: return false
	var same := func(p: Vector3) -> Vector3: return p
	var capped := SelectionSquads.ground_cap([Vector3(-90, 0, 50)] as Array[Vector3], Vector3(-40, 0, 50), walled, never, same)
	assert_true(capped[0].x >= -60.0, "pulled back to the click's side of the wall (%s)" % capped[0])


func test_the_switch_off_is_round_33s_layout() -> void:
	SelectionSquads.GROUND_CAP = false
	var anchors := _three_beside_the_bridge()
	assert_eq(SelectionSquads.ground_cap(anchors, Vector3(BRIDGE_X, 0, 40.0), _drive, _crosses, _clamp), anchors,
			"--ground-cap=off: nothing moves")


## The Crossing: its navmesh and its west bridge's deck.
func test_on_the_crossing_three_squads_by_the_west_bridge_stay_on_his_bank() -> void:
	var lab := TacticsLab.create(self, 1, "crossing")
	var probe := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(-60, 0, 60), 0.0)
	await lab.start()
	var click := Vector3(BRIDGE_X, 0, 44.0)
	var blocks := []
	for i in 3:
		blocks.append({"center": Vector3(-20.0, 0, 44.0 + i * 4.0), "width": SelectionSquads.width("auto", 5),
				"depth": SelectionSquads.depth("auto", 5)})
	var laid := SelectionSquads.fit_inside(SelectionSquads.ranks(blocks, click),
			func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	var crosses := SelectionSquads.crosses_on(probe)
	var across_before := laid.filter(func(p: Vector3) -> bool: return bool(crosses.call(click, p)))
	assert_true(across_before.size() >= 1, "setup: today an anchor is reached over the bridge (%s)" % [laid])
	var capped := SelectionSquads.ground_cap(laid, click, SelectionSquads.drive_on(probe), crosses,
			func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	for p in capped:
		assert_true(not bool(crosses.call(click, p)), "no anchor is reached over the bridge (%s)" % p)
		assert_true(p.z > NORTH_BANK, "on the north bank (%s)" % p)
