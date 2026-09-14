extends TestCase
## Formations (pure), squad commands, commander succession, and drills in real physics.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const NORTH := Vector3(0, 0, -1)
const EAST := Vector3(1, 0, 0)


# ---- Formation geometry -------------------------------------------------------------

func test_wedge_is_a_point_forward() -> void:
	var offsets := Formations.offsets("wedge", 5, 10.0)
	assert_eq(offsets[0], Vector2.ZERO, "the commander is the point")
	assert_eq(offsets[1], Vector2(-10, 10), "first wingman back-left")
	assert_eq(offsets[2], Vector2(10, 10), "second wingman back-right")
	assert_eq(offsets[4], Vector2(20, 20), "the arms extend further back")


func test_vee_opens_forward_and_line_is_abreast() -> void:
	assert_true(Formations.offsets("vee", 3, 10.0)[1].y < 0.0, "vee wingmen are AHEAD of the commander")
	for offset in Formations.offsets("line", 5, 10.0):
		assert_eq(offset.y, 0.0, "every tank in a line is abreast of the commander")
	assert_eq(Formations.offsets("column", 3, 10.0)[2], Vector2(0, 20), "a column is single file behind")
	assert_eq(Formations.offsets("echelon_right", 3, 10.0)[2], Vector2(20, 20), "echelon right steps back to the right")


func test_formation_rotates_with_heading() -> void:
	var wingman := Formations.offsets("wedge", 2, 10.0)[1]  # back-left
	var facing_north := Formations.to_world(Vector3.ZERO, NORTH, wingman)
	assert_true(facing_north.is_equal_approx(Vector3(-10, 0, 10)), "heading north: back-left is south-west (%s)" % facing_north)
	var facing_east := Formations.to_world(Vector3.ZERO, EAST, wingman)
	assert_true(facing_east.is_equal_approx(Vector3(-10, 0, -10)), "heading east: back-left is north-west (%s)" % facing_east)


func test_coil_rings_the_destination_facing_out() -> void:
	var offsets := Formations.offsets("coil", 4, 10.0)
	for offset in offsets:
		assert_near(offset.length(), 8.0, 0.01, "every coil slot is on the ring")
	var outward := Formations.facing("coil", NORTH, offsets[1])
	assert_true(outward.dot(Formations.to_world(Vector3.ZERO, NORTH, offsets[1]).normalized()) > 0.99,
			"coil tanks face outward")


# ---- Commands and succession -------------------------------------------------------

func test_command_validation() -> void:
	assert_eq(Squad.validate_command({"squad": "Alpha", "verb": "move", "to": [10, -20], "formation": "vee"}), "",
			"a full command is valid")
	assert_true(Squad.validate_command({"squad": "Alpha", "verb": "move"}) != "", "move needs a destination")
	assert_true(Squad.validate_command({"squad": "Alpha", "verb": "hold"}) == "", "hold may omit it (hold here)")
	assert_true(Squad.validate_command({"squad": "Alpha", "verb": "dance", "to": [0, 0]}) != "", "unknown verbs are rejected")
	assert_true(Squad.validate_command({"squad": "Alpha", "formation": "blob"}) != "", "unknown formations are rejected")
	assert_true(Squad.validate_command({"squad": "Alpha", "verb": "move", "to": [0, 500]}) != "", "destinations stay in the arena")
	assert_true(Squad.validate_command({"squad": "Alpha"}) != "", "a command must say something")


func _setup_squad(formation := "wedge", count := 3) -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tanks := []
	for i in count:
		tanks.append({"weapon": "cannon"})
	var doctrine := {"name": "Test", "squads": [{"name": "Alpha", "formation": formation, "verb": "hold", "tanks": tanks}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: doctrine loads")
	return [game_match, game_match.squads["0/Alpha"]]


func test_election_and_succession() -> void:
	var setup: Array = _setup_squad()
	var game_match: Match = setup[0]
	var squad: Squad = setup[1]
	assert_eq(squad.commander, "Green_Alpha_1", "the first tank in the roster leads by default")
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "commander": "Green_Alpha_2"}), "",
			"the player can elect another tank")
	assert_eq(squad.commander, "Green_Alpha_2", "command passes to the elected tank")
	assert_true(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "commander": "Rust_X_1"}) != "",
			"only squad members can command")
	(game_match.tanks.get_node("Green_Alpha_2") as Tank).apply_damage(1000)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(squad.commander, "Green_Alpha_3", "when the commander dies, the NEXT tank in the roster takes over")
	assert_true(squad.events[squad.events.size() - 1].contains("commander down"), "and the squad reports it")


# ---- Drills in real physics ----------------------------------------------------------

func _slot_errors(game_match: Match, squad: Squad) -> Array:
	var by_name := game_match.tanks_by_name()
	var errors := []
	for member in squad.formation_order(by_name):
		var context := squad.context_for(member, by_name)
		errors.append((by_name[member] as Tank).global_position.distance_to(context["slot"]))
	return errors


func test_move_in_wedge_arrives_in_formation() -> void:
	var setup: Array = _setup_squad("wedge", 3)
	var game_match: Match = setup[0]
	var squad: Squad = setup[1]
	# Green spawns around (0..±12, 42). Move 40 m north up the open middle-west lane.
	for tank in game_match.tanks.get_children():
		tank.global_position = Vector3(-100 + (tank.slot - 1) * 5.0, 0, 40)
	await wait_physics_frames(3)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "move", "to": [-100, 5]}), "", "order accepted")
	for frame in 60 * 14:
		await tree.physics_frame
		if squad.arrived:
			break
	await wait_physics_frames(60 * 3)  # let the wings settle
	var lead := game_match.tanks.get_node(NodePath(squad.commander)) as Tank
	assert_true(squad.arrived, "the commander reaches the destination (at %s)" % lead.global_position)
	var errors := _slot_errors(game_match, squad)
	for i in errors.size():
		assert_true(errors[i] < 6.0, "tank %d of the wedge is within 6 m of its slot (%.1f m)" % [i, errors[i]])


func test_hold_faces_the_ordered_direction() -> void:
	var setup: Array = _setup_squad("line", 2)
	var game_match: Match = setup[0]
	for tank in game_match.tanks.get_children():
		tank.global_position = Vector3(-100 + (tank.slot) * 8.0, 0, 30)
	await wait_physics_frames(3)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "hold", "to": [-96, 30], "facing": [1, 0]}), "",
			"hold facing east")
	await wait_physics_frames(60 * 8)
	for tank: Tank in game_match.tanks.get_children():
		var forward := -tank.global_basis.z
		assert_true(forward.dot(EAST) > 0.9, "%s faces east when holding (forward %s)" % [tank.name, forward])


func test_break_contact_withdraws_front_first() -> void:
	var setup: Array = _setup_squad("wedge", 2)
	var game_match: Match = setup[0]
	for tank in game_match.tanks.get_children():
		tank.global_position = Vector3(-100 + (tank.slot) * 6.0, 0, 0)
		tank.rotation.y = 0.0  # facing north, toward the (imagined) enemy
	await wait_physics_frames(3)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "break_contact", "to": [-97, 30]}), "",
			"break contact toward the south")
	await wait_physics_frames(60 * 3)
	var brain: TankBrain = game_match.brains.get_child(0)
	assert_eq(brain.move_order.get("reverse"), true, "withdrawing in reverse (front armor still toward the enemy)")
	var lead := game_match.tanks.get_child(0) as Tank
	assert_true(lead.global_position.z > 3.0, "and actually moving back south (z %.1f)" % lead.global_position.z)
	assert_true((-lead.global_basis.z).dot(NORTH) > 0.7, "while still facing north")


func test_bounding_overwatch_leapfrogs_to_the_destination() -> void:
	var setup: Array = _setup_squad("wedge", 4)
	var game_match: Match = setup[0]
	var squad: Squad = setup[1]
	for tank in game_match.tanks.get_children():
		tank.global_position = Vector3(-98 + (tank.slot % 2) * 6.0, 0, 44 - tank.slot * 3.0)
	await wait_physics_frames(3)
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "bound", "to": [-96, -10]}), "", "bound north")
	var halted_while_other_moved := false
	for frame in 60 * 60:
		await tree.physics_frame
		if frame % 30 == 0:
			var by_name := game_match.tanks_by_name()
			var moving := 0
			var holding := 0
			for member in squad.formation_order(by_name):
				if squad.context_for(member, by_name)["moving"]:
					moving += 1
				else:
					holding += 1
			if moving > 0 and holding > 0:
				halted_while_other_moved = true
		if squad.arrived:
			break
	var swaps := 0
	for event in squad.events:
		if event.contains("bound: element"):
			swaps += 1
	assert_true(halted_while_other_moved, "one element holds (overwatch) while the other moves")
	assert_true(swaps >= 1, "the elements swap roles (%d swaps: %s)" % [swaps, squad.events])
	var lead := game_match.tanks.get_node(NodePath(squad.commander)) as Tank
	assert_true(squad.arrived, "bound by bound, the squad reaches the destination 54 m away (commander at %s)" % lead.global_position)
