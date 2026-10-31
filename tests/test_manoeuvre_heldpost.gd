extends TestCase
## Round 48 (manoeuvre M2, `heldpost`, ON; `--traffic-off=heldpost` the escape): A CREW ON HOLD NEVER LEAVES ITS POST TO GIVE WAY.
## Spotter's class B (main df9aacc1a, `make manoeuvre-yield-trace`): on crossing 13215 a parked HOLD crew gave way IN PLACE to a
## squadmate whose route ran through it (frees nobody; renewed every 6 s for 10 s+), and held crews gave way 5-10 m off their posts,
## drove back on HOLD's return and pushed the next held crew off its post (Wrenches / Hunters, 80-100 s). With the rule a crew on
## HOLD standing at its post (verb hold, no move of its own) refuses any ask but an unsticking crew's room-behind, offering the pass
## lane when it has one; the asker passes or goes round it (CP1a2). Open ground (yard_open); forward is -Z.

var _lab: TacticsLab
var _was := not Traffic.off("heldpost")


func teardown() -> void:
	Traffic.set_off("heldpost", not _was)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A gang tank held at the origin; a law tank 20 m south of it sent 40 m north through its post.
func _stage(held_verb: String) -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var held := _lab.unit(Match.Team.GREEN, "Green_Held", Vector3.ZERO, 0.0, "gang_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 20.0), 0.0, "law_tank")
	await _lab.start()
	if held_verb != "":
		assert_eq(_lab.orders.call("issue", {"units": ["Green_Held"], "verb": held_verb}), "", "setup: the %s is accepted" % held_verb)
	for i in 2 * SimClock.TICK_RATE:
		await _lab.step()
	assert_eq(_lab.orders.call("issue", {"units": ["Green_Asker"], "verb": "move", "to": [0.0, -24.0]}), "", "setup: the move is accepted")
	return [held, asker]


func _run(arm: String, held_verb: String) -> Dictionary:
	Traffic.set_off("heldpost", arm == "off")
	var staged := await _stage(held_verb)
	var held := staged[0] as Tank
	var asker := staged[1] as Tank
	var post := held.global_position
	var refusals := Movement.heldpost_refusals
	var yields := Movement.yields_started
	var drift := 0.0
	var arrived_at := -1
	for i in 30 * SimClock.TICK_RATE:
		await _lab.step()
		drift = maxf(drift, Vector2(held.global_position.x - post.x, held.global_position.z - post.z).length())
		if asker.global_position.z < -20.0:
			arrived_at = i + 1
			break
	var out := {"drift": snappedf(drift, 0.1), "arrived_at": arrived_at, "refusals": Movement.heldpost_refusals - refusals,
			"yields": Movement.yields_started - yields, "asker": asker.global_position}
	print("HELDPOST_STAGE %s %s %s" % [arm, held_verb, str(out)])
	_lab.dispose()
	_lab = null
	return out


func test_on_by_default() -> void:
	assert_true(not Traffic.DEFAULT_OFF.has("heldpost"), "the rule ships ON (round 48, his class B)")


func test_a_held_crew_stays_on_its_post_and_the_asker_still_gets_by() -> void:
	var off := await _run("off", "hold")
	var on := await _run("on", "hold")
	assert_eq(int(off["refusals"]), 0, "OFF: no held refusal (today's give-way)")
	assert_true(int(on["refusals"]) >= 1, "ON: the held crew refused the ask (%d)" % on["refusals"])
	assert_true(float(on["drift"]) < 1.5, "ON: the held crew stays on its post (%.1f m; OFF %.1f m)" % [on["drift"], off["drift"]])
	assert_true(int(on["arrived_at"]) > 0, "ON: the asker still gets past within 30 s (at %s)" % str(on["asker"]))


func test_a_crew_not_on_hold_gives_way_as_today() -> void:
	# A parked crew with no hold order (its stop) is asked as before in both arms: the rule reads HOLD only.
	var off := await _run("off", "")
	var on := await _run("on", "")
	assert_eq(int(on["refusals"]), 0, "ON: no held refusal for a crew that is not on HOLD")
	assert_eq(float(on["drift"]), float(off["drift"]), "ON: the unheld crew moves exactly as OFF (%.1f v %.1f m)" % [on["drift"], off["drift"]])
