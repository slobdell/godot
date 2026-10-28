extends TestCase
## Round 43 (engage A7, R43.5 / R43.21): A CREW KEEPS ITS GUN ON A TARGET ACROSS WATER BUT NEVER MOVES FOR IT. His Locks seed
## (A1's trace, ticks 556-694): a War Rig under attack-move engaged a Syndicate crew across the canal 58-61 m away (team-seen,
## the cover map's "own line" clear: it knows walls and props, not water) and its combat move hopped along the bank, one
## reverse hop 36 m, swinging the 14 m hull round. The census (dev 7001-7012): 19 s a run of such hops, the crew 23 m off its
## own order. Under `--engage-water=on`: (1) a contact across water is not "met on the way" under an attack-move (_obey's
## in_reach), so MOVE keeps the route; (2) in ENGAGE on a contact across water the act step never takes a combat hop: a named
## attack drives to it by the route, anything else stands and fires across. The water question is answered by the test seam
## (`TankBrain.water_between`), the act step on a built situation (test_engage_suppress_line's pattern).


## The shipped default, as tank_brain.gd computes it: ON unless the escape. Each test sets the switch itself; the teardown puts
## the default back (a static var: the first check of the flip read `false` left by the test before, 1c20cc1c2 on builder0).
static func _default_on() -> bool:
	return not (OS.get_cmdline_user_args().has("--engage-water=off") or OS.get_environment("ENGAGE_WATER") == "off")


func teardown() -> void:
	TankBrain.ENGAGE_WATER = _default_on()
	TankBrain.water_between = Callable()
	super.teardown()


## _obey's candidates for an attack-move with one visible contact 30 m ahead, `across` water or not.
func _obey(on: bool, across: bool) -> Array:
	TankBrain.ENGAGE_WATER = on
	TankBrain.water_between = func(_from: Vector3, _to: Vector3) -> bool: return across
	var s := {"self": {"position": Vector3(0, 0, 0), "weapon": {"range": 50.0}},
			"contacts": [{"name": "Rust_1", "position": Vector3(0, 0, -30), "visible": true, "age": 0}]}
	var order := {"verb": "attack_move", "goal": Vector3(0, 0, -120), "target": ""}
	var candidates := [{"option": "ENGAGE", "target": "Rust_1", "score": 0.3}]
	return TankBrain._obey(candidates, order, s, false, false)


func _score(result: Array, option: String) -> float:
	for c: Dictionary in result:
		if String(c["option"]) == option:
			return float(c["score"])
	return -1.0


func test_control_a_contact_in_reach_is_met_on_the_way_dry_or_across_water() -> void:
	var dry := _obey(false, false)
	assert_true(_score(dry, "ENGAGE") > _score(dry, "MOVE"), "dry: a contact in reach is fought (ENGAGE %.2f v MOVE %.2f)" % [_score(dry, "ENGAGE"), _score(dry, "MOVE")])
	var wet := _obey(false, true)
	assert_true(_score(wet, "ENGAGE") > _score(wet, "MOVE"), "OFF, across water: fought all the same (today's rule)")


func test_under_the_rule_a_contact_across_water_is_not_met_on_the_way() -> void:
	var wet := _obey(true, true)
	assert_true(_score(wet, "MOVE") > _score(wet, "ENGAGE"), "ON, across water: the move keeps the route (ENGAGE %.2f v MOVE %.2f)" % [_score(wet, "ENGAGE"), _score(wet, "MOVE")])
	var dry := _obey(true, false)
	assert_true(_score(dry, "ENGAGE") > _score(dry, "MOVE"), "ON, dry: a contact in reach is still fought")


## The crew's move order when its brain is in ENGAGE on a target 20 m away that `across` reports as across water.
func _act(on: bool, across: bool) -> Dictionary:
	var s := AiScenario.create(self, 4)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, "gang_ifv")
	var target := s.dummy(Match.Team.RUST, "Rust_1", Vector3(0, 0, -20.0), PI, "ifv")
	var brain := s.brain_of(me)
	await s.start()
	for i in 10:
		await s.step()  # perception: the dummy becomes a contact
	TankBrain.ENGAGE_WATER = on
	TankBrain.water_between = func(_from: Vector3, _to: Vector3) -> bool: return across
	var situation := brain.build_situation()
	var named := false
	for c: Dictionary in situation["contacts"]:
		named = named or String(c["name"]) == String(target.name)
	assert_true(named, "the target is a contact before the act step")
	if not named:
		s.dispose()
		return {"type": "", "why": "", "direct": false, "weapon": ""}
	brain.choice = {"option": "ENGAGE", "target": String(target.name)}
	brain._act(situation)
	var out := {"type": String(brain.move_order.get("type", "")), "why": brain.why,
			"direct": bool(brain.move_order.get("direct", false)), "weapon": String(brain.weapon_order.get("type", "")),
			"weapon_name": String(brain.weapon_order.get("name", ""))}
	s.dispose()
	return out


func test_off_the_act_step_is_todays_across_water_or_not() -> void:
	var wet: Dictionary = await _act(false, true)
	assert_true(not String(wet["why"]).contains("water between"), "OFF: nothing new in its why (%s)" % wet["why"])
	assert_eq(wet["weapon"], "target", "the gun on it")


func test_on_a_target_across_water_is_fired_at_and_never_hopped_for() -> void:
	var wet: Dictionary = await _act(true, true)
	assert_true(wet["type"] in ["face", "stop"], "ON, across water, no named attack: the crew stands and fires across (a face, or a stop when its turret carries the aim) (%s)" % [wet])
	assert_true(not bool(wet["direct"]), "never a direct hop")
	assert_true(String(wet["why"]).contains("water between: firing across"), "and says so (%s)" % wet["why"])
	assert_eq(wet["weapon"], "target", "the gun stays on it")
	assert_eq(wet["weapon_name"], "Rust_1", "that target")
	var dry: Dictionary = await _act(true, false)
	assert_true(not String(dry["why"]).contains("water between"), "ON, dry: today's combat move (%s)" % dry["why"])


func test_the_rule_is_on_by_default_since_bar_a7() -> void:
	assert_eq(TankBrain.ENGAGE_WATER, _default_on(), "ON unless the escape (whatever order the tests ran in)")
