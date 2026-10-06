extends TestCase
## Round 19 (brains B4): the Cut, seed 3. Four Law tanks attack-moved 150 m stopped 105 m short for good: a crew turning
## the south-west corner of a city block pressed for 70 s against the squadmate parked 3.7 m short of its own slot at
## that corner (its order counted as arrived), and each of the three fresh seatings came back the same (0312). Now the
## stuck crew trades slots with the stationary squadmate beside it (Element.MAKE_ROOM), which drives off and frees the
## corner. Both sides: an element is an element.

const METRES := 150.0
const SECONDS := 90.0


## The settle probe's stage (tests/tactics/settle_probe.gd): the squad abreast at the Green spawn, attack-moved forward.
func _attack_move(make_room: bool) -> Dictionary:
	var was := Element.MAKE_ROOM_ENABLED
	Element.MAKE_ROOM_ENABLED = make_room
	var lab := TacticsLab.create(self, 3, "cut")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 4:
		var at := home + right * ((i - 1.5) * 8.0)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_S_%d" % (i + 1), at, yaw, "law_tank").name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var centre := lab.center_of(names)
	var goal := centre + toward * METRES
	element.assign({"verb": "move", "to": [goal.x, goal.z]})
	var arrived := -1
	for tick in int(SECONDS * SimClock.TICK_RATE):
		await lab.step()
		if element.arrived:
			arrived = tick
			break
	var result := {"arrived_s": arrived / float(SimClock.TICK_RATE) if arrived >= 0 else -1.0,
			"to_go_m": snappedf(lab.center_of(names).distance_to(goal), 0.1), "reseats": element.reseats, "swaps": element.swaps}
	lab.dispose()
	Element.MAKE_ROOM_ENABLED = was
	return result


func test_four_tanks_round_the_block_on_the_cut_and_arrive() -> void:
	var off: Dictionary = await _attack_move(false)
	var on: Dictionary = await _attack_move(true)
	print("MEASURE make_room cut seed 3 four Law tanks: re-seat only %s | make room %s" % [off, on])
	assert_true(float(on["arrived_s"]) > 0.0, "the squad arrives (%s)" % on)
	assert_true(int(on["swaps"]) >= 1, "by making room (%s)" % on)
	assert_true(float(off["arrived_s"]) < 0.0, "control: without it the squad stops short (%s)" % off)
