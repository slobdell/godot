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

var _was := TacticsFormation.SEAT_BOUND  # the default as the command line set it
var _last_was := TacticsFormation.SEAT_LAST_OPEN


func teardown() -> void:
	TacticsFormation.SEAT_BOUND = _was  # the harness runs teardown() only (no after_each)
	TacticsFormation.SEAT_LAST_OPEN = _last_was
	super.teardown()


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


func test_the_travelling_stations_keep_the_bound() -> void:
	# The transit lays its stations itself (ElementPlan.route_seats / stations_along): without the bound War Rig 3's first
	# station on Locks was 70 m east; with it the stations are the bounded shape along the route. OFF: today's exactly.
	var members := his_guns()
	for i in members.size():
		members[i]["position"] = Vector3(-43.0 + i * 6.5, 0.0, 95.0)
	var route: Array = [Vector3(-43.0, 0.0, 95.0), Vector3(-69.1, 0.0, 50.7)]
	var pose := ElementPlan.route_pose(route, 30.0)
	var transit := {"route": route, "s": 30.0, "anchor": pose["point"], "heading": pose["tangent"]}
	var seats := {}
	for i in members.size():
		seats[String(members[i]["name"])] = ["swarm", 5, i]
	var plan := {"seats": seats, "formation": "swarm", "pitch": TacticsFormation.pitch(members, SPACING)}
	TacticsFormation.SEAT_BOUND = false
	var open_seats: Array = ElementPlan.route_seats(members, "swarm", SPACING, transit)
	var open_stations: Dictionary = ElementPlan.stations_along(plan, transit, members)
	var bare_stations: Dictionary = ElementPlan.stations_along(plan, transit)
	TacticsFormation.SEAT_BOUND = true
	var tight_seats: Array = ElementPlan.route_seats(members, "swarm", SPACING, transit)
	var tight_stations: Dictionary = ElementPlan.stations_along(plan, transit, members)
	var anchor: Vector3 = pose["point"]
	var far_open := 0.0
	var far_tight := 0.0
	for i in open_seats.size():
		far_open = maxf(far_open, Vector2((open_seats[i] as Vector3).x - anchor.x, (open_seats[i] as Vector3).z - anchor.z).length())
		far_tight = maxf(far_tight, Vector2((tight_seats[i] as Vector3).x - anchor.x, (tight_seats[i] as Vector3).z - anchor.z).length())
	assert_true(far_open > 50.0, "OFF: a route seat of the swarm sits over 50 m from the travelling anchor (%.1f)" % far_open)
	assert_true(far_tight <= 37.0 + 0.5, "ON: every route seat within the bound of the travelling anchor (%.1f)" % far_tight)
	for unit_name: String in tight_stations:
		var station: Vector3 = tight_stations[unit_name]
		assert_true(Vector2(station.x - anchor.x, station.z - anchor.z).length() <= 37.0 + 0.5, "ON: %s's station within the bound" % unit_name)
		assert_true((bare_stations[unit_name] as Vector3).distance_to(open_stations[unit_name]) < 0.01,
				"OFF: stations with members are today's stations without them, exactly")
	for unit_name: String in open_stations:
		assert_true((tight_stations[unit_name] as Vector3).distance_to(open_stations[unit_name]) > 0.1
				or Vector2((open_stations[unit_name] as Vector3).x - anchor.x, (open_stations[unit_name] as Vector3).z - anchor.z).length() <= 37.5,
				"ON changes the stations that were past the bound")


## Round 45 (S v5 candidate, R45.17): with `--seat-last=open` the bound's DEEPEST seat keeps its nominal depth (the rear crew parks behind
## the settled squad instead of pressing into the filled bound: Bar S v4's Locks wedged miss sat on the squad's last two crews), every
## other seat stays within the bound, the floor holds, nobody is re-seated.
func test_seat_last_open_keeps_the_deepest_seat_at_its_nominal_depth() -> void:
	TacticsFormation.SEAT_BOUND = true
	TacticsFormation.SEAT_LAST_OPEN = false
	var bounded_all := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	TacticsFormation.SEAT_LAST_OPEN = true
	var placed := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	TacticsFormation.SEAT_BOUND = false
	TacticsFormation.SEAT_LAST_OPEN = false
	var open := TacticsFormation.place(his_guns(), "swarm", CLICK, HEADING, SPACING)
	var deepest := 0
	for i in open.size():
		if (open[i]["offset"] as Vector2).y > (open[deepest]["offset"] as Vector2).y:
			deepest = i
	assert_true((open[deepest]["offset"] as Vector2).y > (bounded_all[deepest]["offset"] as Vector2).y + 1.0,
			"the swarm's deepest seat is pulled in by the bound (%.1f -> %.1f m behind)" % [(open[deepest]["offset"] as Vector2).y, (bounded_all[deepest]["offset"] as Vector2).y])
	assert_near((placed[deepest]["offset"] as Vector2).y, (open[deepest]["offset"] as Vector2).y, 0.05,
			"last open: the deepest seat keeps its nominal depth behind the anchor")
	for i in placed.size():
		if i == deepest:
			continue
		assert_true((placed[i]["offset"] as Vector2).length() <= 37.0 + 0.05, "every other seat stays within the 37 m bound (seat %d)" % i)
		assert_near((placed[i]["offset"] as Vector2).x, (bounded_all[i]["offset"] as Vector2).x, 0.05, "...and where the bound put it (seat %d)" % i)
	assert_true(clear_by_floor(placed, TacticsFormation.hull_floor(his_guns())), "no two seats closer than the hull floor")
	for i in placed.size():
		assert_eq(String(placed[i]["unit"]), String(open[i]["unit"]), "nobody is re-seated by the open last seat")


## S v5 dev read 4 (Terminus 7001-7012): the two rear crews of every start layout stand abreast (0.0-0.2 m apart in depth), so "the
## rear-most crew" was a float tie; when it fell to the crew on the far side, the deep seat (18 m to one side) sent it across its
## squadmate's path (wedged 17 -> 44 s on three seeds). Rear crews within a tie (SEAT_LAST_REAR_TIE_M) are all rear: the deep seat goes
## to the one laterally nearest it, whichever order the members come in; a crew clearly behind (a column) still takes it from the far
## side. Through the plain move's own path (policy "travel", the route seats as `at`, the bound and the order on): place()'s default
## policy seats by armour tiers, where no rear term can speak.
func test_seat_last_open_breaks_the_rear_tie_toward_the_deep_seat() -> void:
	TacticsFormation.SEAT_BOUND = true
	var anchor := Vector3(-52.0, 0.0, 59.0)
	var route: Array = [Vector3(-52.0, 0.0, 100.0), anchor]  # straight south onto the click
	var pose := ElementPlan.route_pose(route, 41.0)
	var transit := {"route": route, "s": 41.0, "anchor": pose["point"], "heading": pose["tangent"]}
	var heading: Vector3 = pose["tangent"]
	var right := Vector3(-heading.z, 0.0, heading.x)
	var open := TacticsFormation.place(his_guns(), "swarm", anchor, heading, SPACING)
	var deepest := 0
	for i in open.size():
		if (open[i]["offset"] as Vector2).y > (open[deepest]["offset"] as Vector2).y:
			deepest = i
	var side := signf((open[deepest]["offset"] as Vector2).x)  # which side of the line of advance the deep seat sits
	assert_true(absf((open[deepest]["offset"] as Vector2).x) > 10.0, "the swarm's deep seat sits well to one side (%.1f m)" % (open[deepest]["offset"] as Vector2).x)
	var deep_index: int = open[deepest]["index"]
	var seats := func(members: Array) -> Dictionary:
		TacticsFormation.SEAT_LAST_OPEN = true
		var at: Array = ElementPlan.route_seats(members, "swarm", SPACING, transit)
		var placed := TacticsFormation.place(members, "swarm", anchor, heading, SPACING, {"policy": "travel", "seat_bound": true, "seat_order": true, "at": at})
		TacticsFormation.SEAT_LAST_OPEN = false
		return TacticsFormation.seating_of(placed)
	var holder := func(seating: Dictionary) -> String:
		for unit_name: String in seating:
			if int(seating[unit_name]) == deep_index:
				return unit_name
		return ""
	for near_first in [true, false]:
		var members := his_guns()
		# Three crews ahead near the line of advance, two rear crews abreast 35 m behind the click, 10 m either side of the line.
		members[0]["position"] = anchor - heading * 20.0 - right * 6.0
		members[1]["position"] = anchor - heading * 20.0 + right * 6.0
		members[2]["position"] = anchor - heading * 26.0
		var near := anchor - heading * 35.0 + right * (side * 10.0)
		var far := anchor - heading * 35.1 - right * (side * 10.0)  # 0.1 m MORE rear: the old rule's "rear-most"
		members[3]["position"] = near if near_first else far
		members[4]["position"] = far if near_first else near
		var near_name := "Guns_4" if near_first else "Guns_5"
		assert_eq(holder.call(seats.call(members)), near_name,
				"abreast rear crews: the one on the deep seat's side takes it (near listed %s)" % ("first" if near_first else "last"))
	# A column: the far-side crew is a hull length and more behind -> it is the rear crew and takes the deep seat.
	var column := his_guns()
	column[0]["position"] = anchor - heading * 20.0 - right * 6.0
	column[1]["position"] = anchor - heading * 20.0 + right * 6.0
	column[2]["position"] = anchor - heading * 26.0
	column[3]["position"] = anchor - heading * 35.0 + right * (side * 10.0)
	column[4]["position"] = anchor - heading * 45.0 - right * (side * 10.0)
	assert_eq(holder.call(seats.call(column)), "Guns_5", "a crew 10 m behind the others is the rear crew and takes the deep seat from the far side")
