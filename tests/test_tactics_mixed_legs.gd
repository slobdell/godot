extends TestCase
## Round 18, brains D4: his attack-move (an element task `move` with drills: rts_controls sends `drills: false` only for a
## plain move) on a MIXED squad drove one leg, every crew settled into its slot, and the squad never moved on. Sized on
## his path (settle probe, 150 m, 60 s): two-scout mixes stalled in 14 of 24 runs off the Sumps, the Terminus 8 of 8;
## four tanks never. The cause: ElementPlan._cohesive judged "closed up" against a FRESH seating (no pinned leader, no
## previous seats), so the role-ranked tank was measured against the front slot while it sat in its real one at the back.

var seconds := 60.0
const METRES := 150.0


## A squad of `ids` at the Green spawn, abreast and facing the enemy, attack-moved METRES toward it. Returns
## {"arrived_s" (-1 = never), "to_go_m" (the centre's distance from the point at the end)}.
func _attack_move(ids: Array, arena: String, seed_value: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in ids.size():
		var at := home + right * ((i - (ids.size() - 1) * 0.5) * 8.0)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_M_%d" % (i + 1), at, yaw, String(ids[i])).name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var centre := _centre(game_match, names)
	var goal := centre + toward * METRES
	element.assign({"verb": "move", "to": [goal.x, goal.z]})
	var arrived := -1
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if element.arrived:
			arrived = tick
			break
	var result := {"arrived_s": arrived / float(SimClock.TICK_RATE) if arrived >= 0 else -1.0,
			"to_go_m": snappedf(_centre(game_match, names).distance_to(goal), 0.1), "reseats": element.reseats}
	lab.dispose()
	return result


func _centre(game_match: Match, names: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in names:
		var t := game_match.tanks.get_node(NodePath(unit_name)) as Node3D
		sum += Vector3(t.global_position.x, 0.0, t.global_position.z)
	return sum / float(names.size())


func test_a_two_scout_squad_attack_moved_across_the_terminus_arrives() -> void:
	var mixed: Dictionary = await _attack_move(["law_scout", "law_scout", "law_ifv", "law_tank"], "terminus", 1)
	var tanks: Dictionary = await _attack_move(["law_tank", "law_tank", "law_tank", "law_tank"], "terminus", 1)
	print("MEASURE mixed_legs terminus seed 1: two scouts %s | four tanks %s" % [mixed, tanks])
	assert_true(float(tanks["arrived_s"]) > 0.0, "control: four tanks arrive (%s)" % tanks)
	assert_true(float(mixed["arrived_s"]) > 0.0, "a two-scout mixed squad arrives too, not stalled after one leg (%s)" % mixed)


## The mechanism: closed-up is judged against the seats the element GAVE (pinned leader, previous seating), so a squad
## standing in those seats reads as closed up whatever the role ranking would choose fresh.
func test_cohesion_is_judged_against_the_seats_the_element_gave() -> void:
	var heading := Vector3.FORWARD
	var anchor := Vector3.ZERO
	var members: Array = [
		{"name": "A", "position": Vector3.ZERO, "role": "scout", "unit": "law_scout", "speed": 14.0},
		{"name": "B", "position": Vector3.ZERO, "role": "scout", "unit": "law_scout", "speed": 14.0},
		{"name": "C", "position": Vector3.ZERO, "role": "ifv", "unit": "law_ifv", "speed": 11.0},
		{"name": "D", "position": Vector3.ZERO, "role": "tank", "unit": "law_tank", "speed": 8.0}]
	# Seat them as the element would with A pinned as leader and A,B,C,D as the previous seating, then stand each crew
	# exactly in its slot.
	var opts := {"leader": "A", "previous": {"A": 0, "B": 1, "C": 2, "D": 3}, "policy": "exposure"}
	for entry in TacticsFormation.place(members, "wedge", anchor, heading, TacticsFormation.DEFAULT_SPACING, opts):
		for member: Dictionary in members:
			if String(member["name"]) == String(entry["unit"]):
				member["position"] = entry["to"]
	var table := DoctrineTable.for_faction("law")
	assert_true(ElementPlan._cohesive(members, anchor, "wedge", heading, TacticsFormation.DEFAULT_SPACING, table, INF,
			{"leader": "A", "previous": opts["previous"]}), "standing in the seats it was given is closed up")


## Round 18, brains D5: on the Sumps a squad attack-moved 150 m never arrived (0 of 8 even at 180 s, four tanks
## included). In the 14 m lane along the centre block the squad goes single file; the pinned leader was BEHIND a
## squadmate but held the front seat, and the squadmate parked in its own seat squarely in the leader's path. The seating
## is stable by design and never uncrossed the file. A crew that keeps driving without closing on its slot now gets the
## element to re-seat once, fresh (leader unpinned), so the file's order becomes the shape's.
func test_four_tanks_attack_moved_across_the_sumps_arrive() -> void:
	seconds = 90.0
	var result: Dictionary = await _attack_move(["law_tank", "law_tank", "law_tank", "law_tank"], "sumps", 1)
	print("MEASURE mixed_legs sumps seed 1: four tanks %s" % result)
	assert_true(float(result["arrived_s"]) > 0.0, "four tanks attack-moved 150 m across the Sumps arrive (%s)" % result)


## Round 18, after D5: the re-seat fired where it could not help. A Law two-scout squad on the Sumps arrived in 19.9 s with
## D4 alone and 37.0 s with D5 (7 re-seats over four seeds): a wheeled scout pinned on a wall with nobody in its way
## triggered re-seats of OTHER crews, and closing-up judged only against grounded slots waited for it. Now a re-seat
## needs a squadmate in the crew's way, and closing-up counts the nearer of the nominal and the grounded slot.
func test_a_two_scout_squad_across_the_sumps_arrives_without_needless_re_seats() -> void:
	seconds = 60.0
	var result: Dictionary = await _attack_move(["law_scout", "law_scout", "law_ifv", "law_tank"], "sumps", 1)
	print("MEASURE mixed_legs sumps seed 1: two scouts %s" % result)
	assert_true(float(result["arrived_s"]) > 0.0 and float(result["arrived_s"]) <= 25.0,
			"a Law two-scout squad attack-moved 150 m across the Sumps arrives in about 20 s (%s)" % result)
	assert_eq(int(result["reseats"]), 0, "with no re-seat: nobody stood in anybody's way")
