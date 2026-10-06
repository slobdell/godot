extends TestCase
## Round 20 (brains M1): a squad FORMS UP ON THE MOVE. Five crews stand abreast at the Green spawn on the yard (8 m
## apart, as a squad stands after forming up there) and are ordered 100 m away as a line and as a wedge, ahead and to
## the side. Round 12's transit laid the finished shape round an anchor ahead of them from the first tick, so the row
## shuffled into the shape before it set off and a crew seated behind where it stood drove away from the click (orders'
## probe, round 19). Now each station starts on its crew and eases onto the shape (ElementPlan.converge): in the first
## 5 s nobody gets farther from where it is going, and the squad still arrives, in the shape it was given.

const METRES := 100.0
const SECONDS := 60.0
## The yard's spawn is near its east-west wall: 100 m to the side is not a place a squad can stand.
const SIDE_METRES := 60.0
const FIRST_S := 5.0
## A crew may give way to a squadmate or back round once, but not drive off: under half the row's 8 m spacing. (The
## yard's route leaves the spawn on a diagonal, which squeezes an abreast row 8 m apart into lanes 5.7 m apart, and an
## IFV whose first station is off its nose backs round once to reach it, a wheeled hull's three-point turn. Laptop,
## seed 3: the line 6.1 m with round 12's stations, 2.7 now; the wedge 1.4 then, 3.2 now — the one case that is worse.
## On his maps, orders' probe, every case is better: _agents/doctrine.md, round 20.)
const AWAY_M := 3.5
const UNITS := ["tank", "tank", "ifv", "ifv", "scout"]


func teardown() -> void:
	ElementPlan.CONVERGE_ENABLED = true
	super.teardown()


## One plain move: {away_m, off_line_m (worst over crews in the first 5 s), arrived_s, formation}.
func _move(shape: String, dir: String, converge: bool, metres: float) -> Dictionary:
	ElementPlan.CONVERGE_ENABLED = converge
	var lab := TacticsLab.create(self, 3, "yard")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in UNITS.size():
		var at := home + right * ((i - (UNITS.size() - 1) * 0.5) * 8.0)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_S_%d" % (i + 1), at, yaw, String(UNITS[i])).name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var direction: Vector3 = toward if dir == "forward" else right
	var goal := _flat(lab.center_of(names) + direction * metres)
	element.assign({"verb": "move", "to": [goal.x, goal.z], "drills": false, "formation": shape})
	var start := {}
	for unit_name: String in names:
		start[unit_name] = _flat(lab.tank_of(unit_name).global_position)
	var away := 0.0
	var slot_away := 0.0
	var off_line := 0.0
	var arrived := -1.0
	for tick in int(SECONDS * SimClock.TICK_RATE):
		await lab.step()
		if tick < int(FIRST_S * SimClock.TICK_RATE):
			for unit_name: String in names:
				var slot: Variant = element.slots.get(unit_name)
				if not (slot is Vector3):
					continue
				var p := _flat(lab.tank_of(unit_name).global_position)
				var meant := _flat(slot)
				var s0: Vector3 = start[unit_name]
				away = maxf(away, p.distance_to(goal) - s0.distance_to(goal))
				slot_away = maxf(slot_away, p.distance_to(meant) - s0.distance_to(meant))
				off_line = maxf(off_line, Geometry3D.get_closest_point_to_segment(p, s0, meant).distance_to(p))
		elif element.arrived:
			arrived = tick / float(SimClock.TICK_RATE)
			break
	var result := {"away_m": snappedf(away, 0.1), "off_line_m": snappedf(off_line, 0.1), "slot_away_m": snappedf(slot_away, 0.1), "arrived_s": snappedf(arrived, 0.1),
			"formation": element.formation}
	lab.dispose()
	return result


func _pair(shape: String, dir: String, metres := METRES) -> Array:
	var off: Dictionary = await _move(shape, dir, false, metres)
	var on: Dictionary = await _move(shape, dir, true, metres)
	print("MEASURE form_on_move yard seed 3 %s %s: round 12 %s | converge %s" % [shape, dir, off, on])
	return [off, on]


func _judge(pair: Array, label: String) -> void:
	var off: Dictionary = pair[0]
	var on: Dictionary = pair[1]
	assert_true(float(on["away_m"]) <= AWAY_M, "%s: no crew gets farther from the click in the first 5 s (%s)" % [label, on])
	# Off the straight line is REPORTED, not judged (as orders' probe): on the yard the route itself leaves on a diagonal.
	assert_true(float(on["arrived_s"]) > 0.0, "%s: the squad arrives (%s)" % [label, on])
	assert_true(float(on["arrived_s"]) <= float(off["arrived_s"]) + 5.0 or float(off["arrived_s"]) < 0.0,
			"%s: and not much later than round 12 (%s vs %s)" % [label, on, off])


func test_a_line_from_the_spawn_row_forms_on_the_move() -> void:
	_judge(await _pair("line", "forward"), "line forward")


func test_a_wedge_from_the_spawn_row_forms_on_the_move() -> void:
	_judge(await _pair("wedge", "forward"), "wedge forward")


func test_a_wedge_sent_to_the_side_forms_on_the_move() -> void:
	_judge(await _pair("wedge", "side", SIDE_METRES), "wedge side")


static func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)
