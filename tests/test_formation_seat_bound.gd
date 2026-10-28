extends TestCase
## Round 43 (manoeuvre S2, C43.5): a squad's seats are where his click is. His first order on Locks 56416 (2026-10-27) laid
## five crews (three War Rigs, a Gun Truck, a Tanker) as the Gangs' swarm, 112 m wide: War Rig 3 seated 72 m east of the
## click, the Tanker 63 m east. `--seat-bound=on` (TacticsFormation.SEAT_BOUND): the farthest seat within the bound
## (1.5 hull lengths + the hull floor along, never under 18 m), the shape scaled toward the click as a whole, never below the
## hull floor between two seats; halts and groups past a platoon as today. OFF by default. Pure math: no scene.

const CLICK := Vector3(-69.1, 0.0, 50.7)
const HEADING := Vector3(-0.5, 0.0, -0.87)
## The Gangs' "lanes" spacing, what the Guns were laid at on Locks.
const SPACING := 14.0

var _was := false


func before_each() -> void:
	_was = TacticsFormation.SEAT_BOUND


func after_each() -> void:
	TacticsFormation.SEAT_BOUND = _was


static func his_guns() -> Array:
	return [{"name": "Guns_1", "unit": "gang_tank"}, {"name": "Guns_2", "unit": "gang_tank"},
			{"name": "Guns_3", "unit": "gang_tank"}, {"name": "Guns_4", "unit": "gang_ifv"}, {"name": "Guns_5", "unit": "gang_support"}]


static func gun_trucks() -> Array:
	var members: Array = []
	for i in 5:
		members.append({"name": "Hunters_%d" % (i + 1), "unit": "gang_ifv"})
	return members


static func reach(placed: Array[Dictionary], anchor: Vector3) -> float:
	var farthest := 0.0
	for entry in placed:
		var to: Vector3 = entry["to"]
		farthest = maxf(farthest, Vector2(to.x - anchor.x, to.z - anchor.z).length())
	return farthest


## True when every pair of seats is separated on one axis by the floor (closest_boxes' rule, in the formation's frame).
static func clear_by_floor(placed: Array[Dictionary], floor_v: Vector2) -> bool:
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var apart: Vector2 = ((placed[i]["offset"] as Vector2) - (placed[j]["offset"] as Vector2)).abs()
			if apart.x < floor_v.x - 0.01 and apart.y < floor_v.y - 0.01:
				return false
	return true


static func same_seats(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if String(a[i]["unit"]) != String(b[i]["unit"]) or (a[i]["to"] as Vector3).distance_to(b[i]["to"]) > 0.01:
			return false
	return true


func test_off_by_default_his_swarm_reaches_58_m() -> void:
	TacticsFormation.SEAT_BOUND = false
	var placed := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	assert_near(reach(placed, CLICK), 58.0, 1.0, "OFF: the Gangs' swarm of War Rigs reaches 58 m from the click (S1's read)")
	assert_true(not TacticsFormation.SEAT_BOUND or OS.get_cmdline_user_args().has("--seat-bound=on"),
			"the bound is off unless --seat-bound=on is on the command line")


func test_the_bound_is_the_hulls() -> void:
	# War Rig 14.0 m long: 1.5 x 14 + (14 + 2) = 37 m. Gun Truck 3.44 m: 1.5 x 3.44 + 5.44 = 10.6 -> the 18 m floor.
	assert_near(TacticsFormation.seat_bound(his_guns()), 37.0, 0.05, "three War Rigs: 1.5 hull lengths + the hull floor along")
	assert_near(TacticsFormation.seat_bound(gun_trucks()), 18.0, 0.05, "Gun Trucks: never under the 18 m floor")
	assert_true(not is_finite(TacticsFormation.seat_bound([{"name": "a"}, {"name": "b"}])), "members with no hull: no bound")


func test_on_his_swarm_sits_within_37_m_and_clear() -> void:
	TacticsFormation.SEAT_BOUND = true
	var placed := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	assert_true(reach(placed, CLICK) <= 37.0 + 0.05, "ON: every Guns seat within 37 m of his click (was 58 m)")
	assert_true(reach(placed, CLICK) >= 30.0, "...and the swarm keeps its spread rather than collapsing on the click")
	assert_true(clear_by_floor(placed, TacticsFormation.hull_floor(his_guns())), "no two seats closer than the hull floor")
	# The shape is the swarm scaled as a whole: the same seating, the same sides, the same depth order.
	TacticsFormation.SEAT_BOUND = false
	var open := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	for i in placed.size():
		assert_eq(String(placed[i]["unit"]), String(open[i]["unit"]), "nobody is re-seated by the bound")
		var a: Vector2 = placed[i]["offset"]
		var b: Vector2 = open[i]["offset"]
		assert_true(signf(a.x) == signf(b.x) and signf(a.y) == signf(b.y), "each seat keeps its side and its depth")


func test_the_wedge_and_vee_of_war_rigs_are_the_hull_floor_and_unchanged() -> void:
	for shape in ["wedge", "vee", "column", "line"]:
		TacticsFormation.SEAT_BOUND = false
		var open := TacticsFormation.place(his_guns(), shape, CLICK, HEADING, SPACING)
		TacticsFormation.SEAT_BOUND = true
		var placed := TacticsFormation.place(his_guns(), shape, CLICK, HEADING, SPACING)
		assert_true(same_seats(open, placed), "a %s of War Rigs already sits within the bound: laid as today" % shape)
	TacticsFormation.SEAT_BOUND = true
	assert_near(reach(TacticsFormation.place(his_guns(), "wedge", CLICK, HEADING, SPACING), CLICK), 29.3, 0.5,
			"the wedge's rear corner is 29 m out: the War Rig's hull floor, not the bound")


func test_gun_trucks_sit_within_18_m() -> void:
	TacticsFormation.SEAT_BOUND = true
	for shape in ["swarm", "wedge", "vee"]:
		var placed := TacticsFormation.place(gun_trucks(), shape, CLICK, HEADING, SPACING)
		assert_true(reach(placed, CLICK) <= 18.0 + 0.05, "a %s of Gun Trucks within 18 m of the click" % shape)
		assert_true(clear_by_floor(placed, TacticsFormation.hull_floor(gun_trucks())), "%s: the hull floor kept" % shape)
	TacticsFormation.SEAT_BOUND = false
	assert_true(reach(TacticsFormation.place(gun_trucks(), "wedge", CLICK, HEADING, SPACING), CLICK) > 25.0,
			"OFF: the same wedge at the doctrine's 14 m spacing reaches past 25 m")


func test_halts_groups_past_a_platoon_and_opt_outs_are_untouched() -> void:
	TacticsFormation.SEAT_BOUND = false
	var halt_off := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING, {"halt": true, "corridor_m": INF})
	var rows_off := TacticsFormation.place(his_guns() + gun_trucks(), "rows", CLICK, HEADING, SPACING)
	var opt_off := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING, {"seat_bound": false})
	TacticsFormation.SEAT_BOUND = true
	assert_true(same_seats(halt_off, TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING, {"halt": true, "corridor_m": INF})),
			"a halt (the G1 v9 group column's squads, every stand) is laid as today")
	assert_true(same_seats(rows_off, TacticsFormation.place(his_guns() + gun_trucks(), "rows", CLICK, HEADING, SPACING)),
			"ten vehicles in rows are a group, not a squad: as today")
	assert_true(same_seats(opt_off, TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING, {"seat_bound": false})),
			"a caller that says seat_bound false gets today's shape")
	assert_true(not same_seats(opt_off, TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)),
			"...and the default placement of the same swarm is bounded")


func test_bounded_is_pure_geometry() -> void:
	var shape: Array[Vector2] = [Vector2(0, -20), Vector2(-40, 0), Vector2(40, 0), Vector2(-80, 10), Vector2(80, -10)]
	var tight := TacticsFormation.bounded(shape, 40.0, Vector2(10.0, 12.0))
	assert_near(TacticsFormation.reach_of(tight), 40.0, 0.01, "scaled so the farthest slot is on the bound")
	var scale := 40.0 / TacticsFormation.reach_of(shape)
	for i in shape.size():
		assert_near(tight[i].x, shape[i].x * scale, 0.001, "one scale for the whole shape (x)")
		assert_near(tight[i].y, shape[i].y * scale, 0.001, "one scale for the whole shape (y)")
	var floored := TacticsFormation.bounded(shape, 10.0, Vector2(10.0, 12.0))
	assert_true(TacticsFormation.reach_of(floored) > 10.0, "a bound under the floor stops at the floor")
	assert_eq(TacticsFormation.bounded(shape, 100.0, Vector2(10.0, 12.0)), shape, "a shape within the bound comes back as is")
	assert_eq(TacticsFormation.bounded(shape, INF, Vector2(10.0, 12.0)), shape, "no bound: as is")
