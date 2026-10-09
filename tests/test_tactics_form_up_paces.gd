extends TestCase
## Round 24: FormUp.paces with an ETA whose crew no longer has a seat (a crew died and another took its place in the
## same second: the element's ETAs are refreshed once a second). It was a script error that aborted the element's
## update (CPU v CPU at 25 a side, parade seed 3); the unseated crew is now skipped.

func test_an_eta_without_a_seat_is_skipped() -> void:
	var lab := TacticsLab.create(self, 1, "yard")
	var a := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(0, 0, 40), PI, "law_tank")
	var b := lab.unit(Match.Team.GREEN, "Green_P_2", Vector3(8, 0, 40), PI, "law_tank")
	await lab.start()
	var tanks := {"Green_P_1": a, "Green_P_2": b}
	var slots := {"Green_P_1": Vector3(0, 0, 0)}
	var result := FormUp.paces(tanks, slots, {"Green_P_1": 4.0, "Green_P_2": 6.0, "Green_P_3": 9.0})
	assert_true(result.has("Green_P_1"), "the seated crew is paced: %s" % result)
	assert_true(not result.has("Green_P_2") and not result.has("Green_P_3"), "unseated or gone crews are skipped: %s" % result)
	lab.dispose()
