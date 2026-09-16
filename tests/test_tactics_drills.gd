extends TestCase
## Doctrine X3: battle drills fire on the right trigger, stop when their reason is gone, and time out.
## Pure decisions on hand-built situations (the brain-decide pattern in _agents/verification.md): every test
## is named for what a player would see happen.


func _table(faction := "standard") -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(faction)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [faction, loaded.get("error", "")])
	return loaded.get("table")


## A situation with `count` of our vehicles at the origin and the listed contacts.
func _situation(contacts: Array, extra: Dictionary = {}) -> Dictionary:
	var members: Array = []
	for i in int(extra.get("members", 4)):
		members.append({"name": "Green_%d" % (i + 1), "position": Vector3(i * 10.0 - 15.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "tank", "speed": 9.0, "range": 70.0,
				"sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed: Array = []
	for contact: Dictionary in contacts:
		var position: Vector3 = contact.get("position", Vector3(0.0, 0.0, -float(contact.get("distance", 50.0))))
		listed.append({"name": String(contact.get("name", "Rust_1")), "position": position,
				"role": String(contact.get("role", "tank")), "unit": "tank",
				"visible": bool(contact.get("visible", true)), "age": int(contact.get("age", 0)),
				"distance": float(contact.get("distance", position.length())),
				"bearing_deg": 0.0, "strength": float(contact.get("strength", 200.0)),
				"speed": float(contact.get("speed", 0.0))})
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	var enemy := 0.0
	for contact: Dictionary in listed:
		enemy += float(contact["strength"])
	var situation := {"tick": int(extra.get("tick", 1000)), "team": 0, "center": Vector3.ZERO,
			"heading": Vector3.FORWARD, "leader": "Green_1", "members": members, "contacts": listed,
			"terrain": String(extra.get("terrain", "open")),
			"threat": ElementSituation.threat_from(listed, bool(extra.get("taking_fire", false))),
			"composition": "heavy", "strength": float(extra.get("strength", 800.0)), "enemy_strength": enemy,
			"taking_fire": bool(extra.get("taking_fire", false)), "arrived": bool(extra.get("arrived", false))}
	return situation


func _state(extra: Dictionary = {}) -> Dictionary:
	var state := {"task": {"verb": "move", "to": [0, -80]}, "drill": "", "drill_tick": 0, "drill_point": null,
			"drill_target": "", "drill_why": "", "anchor": null, "bounding": 0, "arrived": false,
			"heading": Vector3.FORWARD}
	state.merge(extra, true)
	return state


func test_an_ambush_sprung_at_close_range_is_charged_not_avoided() -> void:
	# The lead: "if a unit gets ambushed, the standard operating procedure is to face the direction of the
	# ambush and charge forward."
	var table := _table()
	var situation := _situation([{"distance": 25.0, "age": 0}], {"taking_fire": true})
	var drill := Drills.select(situation, _state(), table)
	assert_eq(drill["drill"], "near_ambush", "an enemy that opens up 25 m away is a near ambush")
	assert_true(String(drill["why"]).contains("assault through"), "and the drill says what it is doing")
	var turned := Drills.select(situation, _state({"drill": "near_ambush", "drill_tick": situation["tick"] - 40}), table)
	assert_eq(turned["drill"], "assault_through", "once the hulls are round, the element assaults through it")


func test_an_enemy_seen_long_ago_at_that_range_is_not_an_ambush() -> void:
	var table := _table()
	var stale := _situation([{"distance": 25.0, "age": 600, "visible": true}])
	assert_true(Drills.select(stale, _state(), table)["drill"] != "near_ambush",
			"a contact we have watched for ten seconds is not a surprise")
	var far := _situation([{"distance": 90.0, "age": 0}], {"taking_fire": true})
	assert_true(Drills.select(far, _state(), table)["drill"] != "near_ambush",
			"and fire from 90 m away is a far ambush, not a near one")


func test_an_enemy_we_are_already_fighting_does_not_restart_the_drill_as_an_ambush() -> void:
	# Otherwise every maneuver collapses into a frontal charge the moment the flankers get close.
	var table := _table()
	var close := _situation([{"distance": 30.0, "age": 400}], {"taking_fire": true})
	var fighting := _state({"drill": "far_ambush", "drill_tick": close["tick"] - 200})
	assert_eq(Drills.select(close, fighting, table)["drill"], "far_ambush",
			"an element already fighting keeps maneuvering")
	assert_eq(Drills.select(close, _state(), table)["drill"], "near_ambush",
			"but the same enemy opening up on an element that was just driving is an ambush")


func test_first_contact_makes_the_element_return_fire_before_it_decides() -> void:
	var table := _table()
	var situation := _situation([{"distance": 60.0, "age": 200}], {"taking_fire": true})
	var drill := Drills.select(situation, _state(), table)
	assert_eq(drill["drill"], "react_to_contact", "being shot at from 60 m starts react to contact")
	var running := _state({"drill": "react_to_contact", "drill_tick": situation["tick"] - 10})
	assert_eq(Drills.select(situation, running, table)["drill"], "react_to_contact", "which runs for a moment...")
	var elapsed := _state({"drill": "react_to_contact", "drill_tick": situation["tick"] - table.drill_ticks("react_ticks")})
	assert_eq(Drills.select(situation, elapsed, table)["drill"], "far_ambush",
			"...and then becomes fire and maneuver against the enemy we found")


func test_an_element_that_is_losing_breaks_contact_but_not_nose_to_nose() -> void:
	var table := _table()
	var far := _situation([{"distance": 80.0, "strength": 900.0}], {"strength": 200.0, "taking_fire": true})
	assert_eq(Drills.select(far, _state(), table)["drill"], "break_contact",
			"outgunned four to one at 80 m: bound out")
	var close := _situation([{"distance": 20.0, "strength": 900.0}], {"strength": 200.0, "taking_fire": true})
	assert_true(Drills.select(close, _state(), table)["drill"] != "break_contact",
			"but turning your back at 20 m just gets you shot in it")
	var even := _situation([{"distance": 80.0, "strength": 300.0}], {"strength": 800.0, "taking_fire": true})
	assert_true(Drills.select(even, _state(), table)["drill"] != "break_contact",
			"and an element that is winning stays and fights")


func test_a_drill_stops_when_its_reason_is_gone() -> void:
	var table := _table()
	var clear := _situation([])
	var running := _state({"drill": "far_ambush", "drill_tick": clear["tick"] - 60})
	assert_eq(Drills.select(clear, running, table)["drill"], "",
			"with nothing left to see, fire and maneuver is over")
	var withdrawing := _state({"drill": "break_contact", "drill_tick": clear["tick"] - 60})
	assert_eq(Drills.select(clear, withdrawing, table)["drill"], "", "and so is breaking contact")


func test_no_drill_runs_forever() -> void:
	var table := _table()
	# An assault that never gets through its objective: the enemy is still there, 50 m off, shooting.
	var situation := _situation([{"distance": 50.0, "age": 500}], {"taking_fire": true})
	var state := _state({"drill": "assault_through", "drill_point": Vector3(0.0, 0.0, -400.0),
			"drill_tick": situation["tick"] - 60})
	assert_eq(Drills.select(situation, state, table)["drill"], "assault_through", "the assault runs...")
	var stuck := _state({"drill": "assault_through", "drill_point": Vector3(0.0, 0.0, -400.0),
			"drill_tick": situation["tick"] - table.drill_ticks("timeout_ticks") - 1})
	assert_true(Drills.select(situation, stuck, table)["drill"] != "assault_through",
			"...but after the timeout the leader stops charging and decides again")


func test_a_halted_element_watches_its_flanks() -> void:
	var table := _table()
	var halted := _situation([{"distance": 150.0, "visible": false, "age": 300}],
			{"arrived": true})
	var state := _state({"task": {"verb": "hold"}, "arrived": true})
	assert_eq(Drills.select(halted, state, table)["drill"], "herringbone",
			"stopped with something out there: herringbone, not a parked clump")
	var alone := _situation([])
	assert_eq(Drills.select(alone, state, table)["drill"], "",
			"with nothing known at all there is nothing to watch for")


func test_a_faction_without_a_drill_never_runs_it() -> void:
	var gangs := _table("gangs")
	var losing := _situation([{"distance": 80.0, "strength": 900.0}], {"strength": 150.0, "taking_fire": true})
	assert_true(not gangs.runs_drill("break_contact"), "the gangs' table switches break contact off")
	assert_true(Drills.select(losing, _state(), gangs)["drill"] != "break_contact",
			"so a losing gang element never bounds away: it keeps coming")
	var standard := _table()
	assert_eq(Drills.select(losing, _state(), standard)["drill"], "break_contact",
			"where a standard element would have withdrawn")


## A table that switches a drill on, for testing a mechanism no shipped doctrine currently selects.
func _table_running(drill: String) -> DoctrineTable:
	var parsed := DoctrineTable.parse({"name": "with_%s" % drill,
			"drills": {"enabled": DoctrineTable.DRILL_DEFAULTS["enabled"] + [drill]},
			"movement": [{"when": {}, "formation": "swarm", "technique": "traveling", "why": "lab"}]})
	assert_true(parsed.has("table"), "a table can switch on %s: %s" % [drill, parsed.get("error", "")])
	return parsed.get("table")


func test_the_ring_triggers_for_a_pack_that_can_make_one() -> void:
	# The encircle mechanism, which is switched OFF in every shipped table: it was measured strictly worse
	# than simply fighting (same survival, a third of the damage — _agents/doctrine.md "Why encircle is off").
	# It stays testable so the tactics-discovery harness can revisit it.
	var ringing := _table_running("encircle")
	var contact := _situation([{"distance": 70.0, "age": 500}], {"members": 4, "taking_fire": true})
	assert_eq(Drills.select(contact, _state(), ringing)["drill"], "encircle",
			"a pack that can see them and has the numbers gets around them")
	var pair := _situation([{"distance": 70.0, "age": 500}], {"members": 2, "taking_fire": true})
	assert_true(Drills.select(pair, _state(), ringing)["drill"] != "encircle",
			"two vehicles are not a ring, they are two targets")
	var knife := _situation([{"distance": 12.0, "age": 500}], {"members": 4, "taking_fire": true})
	assert_true(Drills.select(knife, _state(), ringing)["drill"] != "encircle",
			"and nobody circles an enemy already inside knife range")
	assert_true(not _table("gangs").runs_drill("encircle"),
			"and no shipped table chooses it: it lost the measurement")
	assert_true(not _table().runs_drill("encircle"), "least of all standard doctrine")


func test_a_gang_sends_its_fastest_to_pull_them_onto_the_pack() -> void:
	# The lead: "the street gang would also be more likely to create tactics of having a vehicle draw fire to
	# try and lead the opponents into an ambush."
	var gangs := _table("gangs")
	# A contact that is MOVING: a lure only means something against something that will follow.
	var situation := _situation([{"distance": 85.0, "age": 500, "speed": 7.0}], {"members": 4})
	# Make one member clearly the fastest, and the leader slow, so the choice is unambiguous.
	(situation["members"][2] as Dictionary)["speed"] = 18.0
	var drill := Drills.select(situation, _state(), gangs)
	assert_eq(drill["drill"], "bait", "at stand-off range the pack baits instead of charging")
	assert_eq(String(Drills.bait_of(situation)["name"]), "Green_3", "the fastest vehicle draws the fire")
	assert_true(String(Drills.bait_of(situation)["name"]) != String(situation["leader"]),
			"and never the leader: the pack still needs somebody deciding")
	assert_true(Drills.select(situation, _state(), _table())["drill"] != "bait",
			"standard doctrine does not use its own vehicles as lures")
	# The lesson that cost three of four vehicles the first time: you cannot lure a gun that never moves.
	var dug_in := _situation([{"distance": 85.0, "age": 500, "speed": 0.0}], {"members": 4})
	(dug_in["members"][2] as Dictionary)["speed"] = 18.0
	assert_true(Drills.select(dug_in, _state(), gangs)["drill"] != "bait",
			"a dug-in gun will never chase the bait, so nobody is sent to die drawing it")
