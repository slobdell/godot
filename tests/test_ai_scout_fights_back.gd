extends TestCase
## Overnight item 2 (brains, from C33.9, his scout report): A SCOUT UNDER FIRE FIGHTS BACK WHEN IT CAN'T GET AWAY.
## SPOT's 0.88 (keep the nearest enemy at SCOUT_STANDOFF) is meant to buy distance, but a scout circled by something it
## cannot outrun, or held by its post's leash, buys none and barely fires (manoeuvre's orbit stage: the scout's own shots
## 5-20 against the orbiter's 112-128 at it, SPOT held). Rule (TankBrain.scout_fights_back): hit within
## SCOUT_FIGHT_HIT_TICKS, by a visible non-prey contact that can shoot it now (threatens_me) and is inside its own
## effective range, and either matches it (duel advantage >= 1, an even duel) or is not slower than it (top speed >= 0.9 x its own):
## SPOT drops to its in-sight 0.7, so ENGAGE wins. Against a shooter it loses to and can outrun, SPOT opens distance as
## today. `--scout-fight=off` (or env SCOUT_FIGHT=off) is main's rule.


func teardown() -> void:
	TankBrain.SCOUT_FIGHT_BACK = true
	super.teardown()


## A law_scout at the origin, hit `since_hit` ticks ago, and one contact `metres` north of it.
func _case(since_hit: int, unit := "syn_scout", metres := 25.0, threatens := true, visible := true) -> Array:
	var me := {"unit": "law_scout", "position": Vector3.ZERO, "since_hit": since_hit,
			"weapon": Weapons.profile(String(Units.stat("law_scout", "weapon", "")))}
	var contacts := [{"name": "Rust_1", "unit": unit, "position": Vector3(0, 0, -metres), "visible": visible,
			"threatens_me": threatens, "role": Units.role_of(unit)}]
	return [me, contacts]


func test_hit_by_something_it_cannot_outrun_it_fights() -> void:
	var c := _case(10)
	assert_true(float(Units.stat("syn_scout", "max_forward_speed")) >= 0.9 * float(Units.stat("law_scout", "max_forward_speed")),
			"setup: the syn scout is not slower than the law scout")
	assert_true(TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 0.5}}), "can't get away: fight")


func test_it_fights_one_it_matches_even_when_it_could_run() -> void:
	var c := _case(10, "law_tank")
	assert_true(TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 1.2}}), "matches it: fight")


func test_against_one_it_loses_to_and_can_outrun_it_runs() -> void:
	var c := _case(10, "law_tank")
	assert_true(float(Units.stat("law_tank", "max_forward_speed")) < 0.9 * float(Units.stat("law_scout", "max_forward_speed")),
			"setup: the law tank is slower")
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 0.4}}), "loses and can run: SPOT")


func test_not_hit_lately_it_keeps_its_distance() -> void:
	var c := _case(TankBrain.SCOUT_FIGHT_HIT_TICKS + 1)
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 0.5}}), "not under fire: SPOT")


func test_a_shooter_out_of_its_own_reach_or_out_of_sight_does_not_count() -> void:
	var far := _case(10, "syn_scout", 500.0)
	assert_true(not TankBrain.scout_fights_back(far[0], far[1], {"Rust_1": {"advantage": 0.5}}), "beyond its own range")
	var unseen := _case(10, "syn_scout", 25.0, true, false)
	assert_true(not TankBrain.scout_fights_back(unseen[0], unseen[1], {"Rust_1": {"advantage": 0.5}}), "not visible")
	var safe := _case(10, "syn_scout", 25.0, false)
	assert_true(not TankBrain.scout_fights_back(safe[0], safe[1], {"Rust_1": {"advantage": 0.5}}), "it can't shoot me")


func test_the_switch_off_is_mains_rule() -> void:
	TankBrain.SCOUT_FIGHT_BACK = false
	var c := _case(10)
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 0.5}}), "--scout-fight=off: SPOT")
