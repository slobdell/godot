extends TestCase
## Round 30 (traffic T1c-b, brains' request): a hull SET UP and still ON ITS FIRE ORDER, with no move of its own, does not
## give way. Brains' trace (ApproachStage seed 15, tick 16; round 29 seed 4 at 26 s): a mortar truck with its legs down,
## order attack, move_order stop, was asked by squadmates driving to their places, gave way and packed up, so it never
## fired from its spot. It refuses the ask; the asker treats it as parked and goes round (Movement._negotiate's CP1a2 rule;
## ORCA). Round 29's T1c refused EVERY set-up hull and was judged on give-ways a hull with a new move started itself; here
## a set-up hull that is leaving anyway (a new move under way), or that is ordered to hold fire, is asked as before.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("setup", false)
	Traffic.set_off("firemission", Traffic.DEFAULT_OFF.has("firemission"))  # the default back, whichever it is
	if _lab != null:
		_lab.dispose()  # each case's lab (undisposed, the shard leaked 20 ObjectDB instances at exit: engine-log-gate)
		_lab = null
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


## The battery set up on its post: legs down, ordered to fire, its own order a stop.
func _on_post(battery: Tank, weapon := "fire_at_will") -> Movement:
	battery.deploy_ratio = 1.0
	var mover := Movement.of(battery)
	mover.ctl.move_order = {"type": "stop"}
	mover.ctl.weapon_order = {"type": weapon}
	mover.idle()
	return mover


func test_a_set_up_battery_on_its_fire_order_does_not_give_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	var mover := _on_post(battery)
	assert_true(mover.on_fire_post(), "set up, ordered to fire, no move of its own: on its fire post")
	var refused_before := Movement.setup_refusals
	var gave_way := mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0))
	assert_true(not gave_way, "it refuses the ask")
	assert_eq(mover.yield_to, "", "and is not giving way")
	assert_eq(Movement.setup_refusals, refused_before + 1, "counted as a refusal on the post")


func test_a_set_up_battery_told_to_hold_fire_still_gives_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	var mover := _on_post(battery, "hold_fire")
	assert_true(not mover.on_fire_post(), "holding fire: not on a fire post")
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "it gives way as before")


func test_a_set_up_battery_with_a_new_move_is_leaving_anyway() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var mover := _on_post(battery)
	mover.ctl.move_order = {"type": "move_to", "x": 0.0, "z": -60.0}
	mover.phase = "driving"
	assert_true(not mover.on_fire_post(), "a move of its own under way: leaving anyway, not on its post")


func test_a_packed_battery_still_gives_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	var mover := _on_post(battery)
	battery.deploy_ratio = 0.0
	assert_true(not mover.on_fire_post(), "packed: not on a fire post")
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "packed, it gives way as before")
	assert_eq(mover.yield_to, String(tank.name), "to the asker")


func test_off_switch_restores_the_old_give_way() -> void:
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	var mover := _on_post(battery)
	Traffic.set_off("setup", true)
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "--traffic-off=setup: it gives way")


## Round 33 overnight (item 4, `firemission`): set up on fire_at_will with NOTHING to fire at (random-705's truck, dug in
## 5 m short of its place) is not a firing battery: it is asked like any parked crew, and packs up to give way.
func test_on_a_dug_in_battery_with_nothing_to_shoot_gives_way() -> void:
	Traffic.set_off("firemission", false)
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	var mover := _on_post(battery)
	assert_eq(mover.ctl.engaged_target, "", "nothing engaged")
	assert_true(not mover.on_fire_post(), "fire_at_will, no target: not on a fire post")
	assert_true(mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "it gives way")
	assert_eq(mover.yield_to, String(tank.name), "to the asker")


## ...and the lead's T1c-b2 yes holds: a battery ORDERED to fire at someone keeps its post.
func test_on_a_battery_ordered_to_fire_keeps_its_post() -> void:
	Traffic.set_off("firemission", false)
	var units: Array = await _stage()
	var battery: Tank = units[0]
	var tank: Tank = units[1]
	for kind in ["target", "suppress"]:
		var mover := _on_post(battery, kind)
		assert_true(mover.on_fire_post(), "%s: on its fire post" % kind)
		assert_true(not mover.ask(String(tank.name), tank.global_position, Vector2(0.0, -1.0)), "%s: it refuses the ask" % kind)


## OFF (today's reading): the dug-in battery with nothing to shoot refuses, as T1c-b2 shipped.
func test_off_a_dug_in_battery_with_nothing_to_shoot_refuses() -> void:
	Traffic.set_off("firemission", true)
	var units: Array = await _stage()
	var mover := _on_post(units[0] as Tank)
	assert_true(mover.on_fire_post(), "today's reading: set up on fire_at_will is a fire post")
