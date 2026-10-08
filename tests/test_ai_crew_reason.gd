extends TestCase
## Round 23 (brains B2, C23.2): `UnansweredFire.crew_reason(game_match, unit_name)`, the per-crew "fire I cannot
## answer" read for orders' readout of a crew he holds. His recording's geometry (DuckStage): a Syndicate gunship
## (pulse cannon, effective 55 m) under a Lancer's laser from 84 m, with NO element at all (his direct hold takes a crew
## out of its element), and then inside an element on his hold, where it must say what the element's readout says.

const GUNSHIP := "Rust_Hunters_2"
const LANCER := "Green_Charlie_1"


func teardown() -> void:
	UnansweredFire.ENABLED = true
	super.teardown()


func _stage(with_element: bool) -> Dictionary:
	var lab := TacticsLab.create(self, 1, "foundry")
	lab.game_match.set_meta("player_team", Match.Team.RUST)
	var toward := (DuckStage.LANCER_AT - DuckStage.GUNSHIP_AT).normalized()
	var duck := lab.unit(Match.Team.RUST, GUNSHIP, DuckStage.GUNSHIP_AT, atan2(-toward.x, -toward.z), "syn_ifv")
	lab.gun(Match.Team.GREEN, LANCER, DuckStage.LANCER_AT, atan2(toward.x, toward.z), "lancer")
	await lab.start()
	var element: Element = null
	if with_element:
		# The recorded ambush, as DuckStage's "his" stage: his posture task, so the element holds and says why.
		element = lab.elements.form([GUNSHIP], "Hunters", DoctrineTable.load_table("syndicate")["table"])
		element.assign({"verb": "ambush", "from": DuckStage.AMBUSH_FROM, "to": DuckStage.AMBUSH_TO})
	else:
		# His direct hold: the crew's own controller, no element (orders' direct path takes it out of one).
		lab.orders.call("issue", {"units": [GUNSHIP], "verb": "hold"}, Match.Team.RUST)
	return {"lab": lab, "duck": duck, "element": element}


## Out of any element: "" until it has been hit for the grace with nothing it can answer, then WHY_HELD, then "" again
## once the fire stops (the Lancer dead).
func test_a_crew_outside_any_element_says_why_after_the_grace() -> void:
	var stage := await _stage(false)
	var lab: TacticsLab = stage["lab"]
	var duck: Tank = stage["duck"]
	assert_eq(UnansweredFire.crew_reason(lab.game_match, GUNSHIP), "", "nothing yet")
	var first_hit := -1
	var said := -1
	for tick in 12 * SimClock.TICK_RATE:
		await lab.step()
		if first_hit < 0 and duck.ticks_since_hit < 2:
			first_hit = tick
		var reason := UnansweredFire.crew_reason(lab.game_match, GUNSHIP)
		if first_hit < 0 or tick - first_hit < UnansweredFire.GRACE_TICKS - 2:
			assert_eq(reason, "", "inside the grace (tick %d, hit at %d)" % [tick, first_hit])
		elif reason == UnansweredFire.WHY_HELD and said < 0:
			said = tick
		if said >= 0 and tick - said > SimClock.TICK_RATE:
			break
	assert_true(first_hit >= 0, "the Lancer hits it")
	assert_true(said >= 0 and said - first_hit <= UnansweredFire.GRACE_TICKS + SimClock.TICK_RATE / 2,
			"says WHY_HELD within half a second of the grace (first hit %d, said %d)" % [first_hit, said])
	# The fire stops: kill the Lancer, let the quiet pass.
	lab.tank_of(LANCER).apply_damage(100000)
	for tick in UnansweredFire.QUIET_TICKS + 5:
		await lab.step()
	assert_eq(UnansweredFire.crew_reason(lab.game_match, GUNSHIP), "", "the fire has stopped")
	lab.dispose()


## Inside an element on his hold: the same words as the element's readout, at the same time.
func test_a_crew_in_an_element_on_his_hold_says_what_its_element_says() -> void:
	var stage := await _stage(true)
	var lab: TacticsLab = stage["lab"]
	var element: Element = stage["element"]
	var agreed := 0
	var held := 0
	for tick in 12 * SimClock.TICK_RATE:
		await lab.step()
		var reason := UnansweredFire.crew_reason(lab.game_match, GUNSHIP)
		var readout := element.describe().contains(UnansweredFire.WHY_HELD)
		if readout:
			held += 1
			if reason == UnansweredFire.WHY_HELD:
				agreed += 1
		if held > 2 * SimClock.TICK_RATE:
			break
	assert_true(held > 0, "the element held it and said so")
	assert_true(agreed >= held - 3, "the crew read agrees with the readout (%d of %d ticks)" % [agreed, held])
	lab.dispose()


## A crew that CAN answer (the shooter inside its range) is never "held".
func test_a_crew_with_the_shooter_in_its_range_says_nothing() -> void:
	var lab := TacticsLab.create(self, 1, "foundry")
	lab.game_match.set_meta("player_team", Match.Team.RUST)
	# The recording's ground (the foundry's centre is a crate), the Lancer 40 m off: inside the gunship's 55 m.
	var toward := (DuckStage.LANCER_AT - DuckStage.GUNSHIP_AT).normalized()
	var duck := lab.unit(Match.Team.RUST, GUNSHIP, DuckStage.GUNSHIP_AT, atan2(-toward.x, -toward.z), "syn_ifv")
	lab.gun(Match.Team.GREEN, LANCER, DuckStage.GUNSHIP_AT + toward * 40.0, atan2(toward.x, toward.z), "lancer")
	await lab.start()
	var hits := 0
	for tick in 6 * SimClock.TICK_RATE:
		await lab.step()
		if duck.ticks_since_hit < 2:
			hits += 1
		assert_eq(UnansweredFire.crew_reason(lab.game_match, GUNSHIP), "", "it can shoot back (tick %d)" % tick)
	assert_true(hits > 0, "it was being hit")
	lab.dispose()
