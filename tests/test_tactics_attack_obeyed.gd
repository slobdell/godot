extends TestCase
## Round 20 (brains M1b): HIS ATTACK ORDER IS OBEYED. He played 25 Rat Rods, selected all, V formation, and ordered
## them to attack one Law vehicle; four of his five squads ran the gangs' BAIT drill on sight (one scout forward, four
## holding 45 m back, then backing toward their start line because the Law never chased), and he saw "they all spread
## out and drove away" (foundry, seed 40047, build/recordings/2026-10-06T14-59-04.jsonl). Decided: under a PLAYER's
## attack with a named target the gangs' elective drills (bait, encircle) do not fire; the computer keeps them, and so
## does his movement without a named target.
##
## The stage: five squads of five gang scouts abreast at the Green spawn on the yard, one Law tank parked 70 m ahead
## (in bait range, not chasing), every squad given {"verb": "attack", "target": <it>}.

const SECONDS := 15.0
const SQUADS := 5
const ELECTIVE := ["bait", "encircle"]


## {"drills": {element: [drill names seen]}, "closed_m": {element: start - end distance to the target}, "dead": bool}
func _attack(player: bool) -> Dictionary:
	var lab := TacticsLab.create(self, 3, "yard")
	var game_match := lab.game_match
	if player:
		game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var squads: Array = []
	for k in SQUADS:
		var names: Array = []
		for i in 5:
			var at := home + right * ((k - (SQUADS - 1) * 0.5) * 22.0 + (i - 2) * 4.0) - toward * (i % 2) * 4.0
			names.append(String(lab.unit(Match.Team.GREEN, "Green_%s_%d" % ["ABCDE"[k], i + 1], at, yaw, "gang_scout").name))
		squads.append(names)
	var target_at := home + toward * 70.0
	var target := lab.unit(Match.Team.RUST, "Rust_T_1", target_at, yaw + PI, "law_tank")
	await lab.start()
	var elements: Array = []
	for k in SQUADS:
		var element := lab.elements.form(squads[k], "Squad_%d" % (k + 1))
		element.assign({"verb": "attack", "target": String(target.name), "formation": "vee"})
		elements.append(element)
	var seen := {}
	var start := {}
	for element: Element in elements:
		seen[element.element_name] = []
		start[element.element_name] = lab.center_of(Array(element.members())).distance_to(target_at)
	for tick in int(SECONDS * SimClock.TICK_RATE):
		await lab.step()
		for element: Element in elements:
			if element.drill != "" and not (seen[element.element_name] as Array).has(element.drill):
				(seen[element.element_name] as Array).append(element.drill)
	var closed := {}
	for element: Element in elements:
		var alive := Array(element.members()).filter(func(n: String) -> bool:
			return lab.tank_of(n) != null and lab.tank_of(n).is_alive())
		closed[element.element_name] = snappedf(float(start[element.element_name]) - lab.center_of(alive).distance_to(target_at), 0.1) \
				if not alive.is_empty() else 999.0
	var result := {"drills": seen, "closed_m": closed, "dead": not target.is_alive()}
	lab.dispose()
	return result


func test_his_squads_attack_the_vehicle_he_named() -> void:
	var his: Dictionary = await _attack(true)
	print("MEASURE attack_obeyed yard seed 3 five gang squads, his attack: %s" % his)
	for squad: String in his["drills"]:
		for drill: String in his["drills"][squad]:
			assert_true(not ELECTIVE.has(drill), "%s ran %s under his attack order (%s)" % [squad, drill, his["drills"][squad]])
		assert_true(float(his["closed_m"][squad]) >= 25.0 or bool(his["dead"]),
				"%s closed on the target (%.1f m in %.0f s)" % [squad, float(his["closed_m"][squad]), SECONDS])


func test_the_computers_packs_still_run_their_drills() -> void:
	var cpu: Dictionary = await _attack(false)
	print("MEASURE attack_obeyed yard seed 3 five gang squads, no player (the computer's attack): %s" % cpu)
	var elective := 0
	for squad: String in cpu["drills"]:
		for drill: String in cpu["drills"][squad]:
			if ELECTIVE.has(drill):
				elective += 1
	assert_true(elective >= 1, "the gang's bait/encircle still fire for the computer (%s)" % cpu["drills"])
