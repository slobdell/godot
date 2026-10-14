extends TestCase
## Round 29 (traffic T1c, brains' request): a hull SET UP to fire does not give way. Brains' trace (ApproachStage seed 15,
## tick 16): a mortar truck with its legs down was asked three times in 7 s by squadmates driving to their places, gave
## way each time and packed up, so it never fired from its spot. A set-up hull refuses the ask; the asker treats it as
## parked and goes round (Movement._negotiate's CP1a2 rule; ORCA). The same hull packed still gives way.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("setup", false)
	super.teardown()


## A Law battery and a Law tank on open ground (yard_open's band), the tank 12 m south of the battery heading north.
func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var battery := _lab.unit(Match.Team.GREEN, "Green_Battery", Vector3(0.0, 0.0, 0.0), 0.0, "law_artillery")
	var tank := _lab.unit(Match.Team.GREEN, "Green_Tank", Vector3(0.0, 0.0, 12.0), 0.0, "law_tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	return [battery, tank]


func test_a_set_up_battery_does_not_give_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	battery.deploy_ratio = 1.0
	var refused_before := Movement.setup_refusals
	var mover := Movement.of(battery)
	assert_true(mover != null, "the battery has a mover")
	var gave_way := mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0))
	assert_true(not gave_way, "set up, it refuses the ask")
	assert_eq(mover.yield_to, "", "and is not giving way")
	assert_eq(Movement.setup_refusals, refused_before + 1, "counted as a set-up refusal")
	var at := battery.global_position
	for i in 30:
		await _lab.step()
	# (An idle battery with no fire order packs up by itself over time; that is the hull's own rule, not this one.)
	assert_eq(mover.yield_to, "", "a second later it is still not giving way")
	assert_true(battery.global_position.distance_to(at) < 0.5, "and has not driven off its spot")


func test_a_packed_battery_still_gives_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	battery.deploy_ratio = 0.0
	var mover := Movement.of(battery)
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "packed, it gives way as before")
	assert_eq(mover.yield_to, String(tank.name), "to the asker")


func test_off_switch_restores_the_old_give_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	Traffic.set_off("setup", true)
	battery.deploy_ratio = 1.0
	var mover := Movement.of(battery)
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "--traffic-off=setup: it gives way")
