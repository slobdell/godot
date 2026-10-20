extends TestCase
## Round 35 (brains E4, R35.47): A LAB STAGE PLAYS THE SAME AS THE FIRST MATCH IN ITS PROCESS. TacticsLab placed a hull by
## writing `global_position`, which left its physics body at its `Match.spawn_position` slot until the first step; four tanks
## abreast on the Sumps had two stale bodies overlapping their neighbours, and from the SECOND match in a process on the overlap
## was resolved as penetration (the outer tanks shoved 0.31 m inward before anything moved: four tanks arrived 50.0 s v 55.9 s,
## re-seats 1 v 0; test_tactics_mixed_legs passed alone and failed after another test, R35.39). `Tank.place` flushes the body.

const STEPS := 3 * SimClock.TICK_RATE


## The four-tank stage of test_tactics_mixed_legs (abreast at the Green spawn, 8 m apart), a move ordered, STEPS stepped:
## [Match.state_hash after each step, the farthest any hull stands from where it was placed once the lab has started (m)].
func _hashes() -> Array:
	var lab := TacticsLab.create(self, 1, "sumps")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_M_%d" % (i + 1), home + right * ((i - 1.5) * 8.0), yaw,
				"law_tank").name))
	await lab.start()
	# Nothing has been ordered yet: a hull that is not where the lab put it was shoved there by a stale body.
	var shoved := 0.0
	for i in names.size():
		var now := (game_match.tanks.get_node(NodePath(String(names[i]))) as Node3D).global_position
		var asked := home + right * ((i - 1.5) * 8.0)
		shoved = maxf(shoved, Vector2(now.x - asked.x, now.z - asked.z).length())
	var element := lab.elements.form(names, "Alpha")
	var goal := home + toward * 150.0
	element.assign({"verb": "move", "to": [goal.x, goal.z]})
	var hashes: Array = []
	for step in STEPS:
		await lab.step()
		hashes.append(game_match.state_hash())
	lab.dispose()
	return [hashes, shoved]


func test_a_second_match_in_the_process_plays_as_the_first() -> void:
	var first: Array = await _hashes()
	var second: Array = await _hashes()
	assert_near(float(first[1]), 0.0, 0.05, "no hull is shoved off its place before it is ordered (%.3f m)" % first[1])
	assert_near(float(second[1]), 0.0, 0.05, "nor in a second match in the process (%.3f m)" % second[1])
	var at := -1
	for i in STEPS:
		if first[0][i] != second[0][i]:
			at = i
			break
	assert_eq(at, -1, "the second match's state equals the first's at every step (first difference at step %d)" % at)
