extends DriveTwinCase
## Round 48 (native N1, the twin manoeuvre asked for): with `heldpost` ON (manoeuvre M2: Movement.ask's refusal by a crew on HOLD at
## its post, with the pass offer, and _begin_yield's refused in-place hold by a parked crew) the native drive and yield
## (BrainSwitches.native_yield: _negotiate, ask and _begin_yield in drive_native.cpp) are the live GDScript, on manoeuvre's stage
## (tests/test_manoeuvre_heldpost.gd): a gang tank on yard_open, a law tank 20 m south sent 40 m north through its post; the held
## arm (verb hold) and the unheld arm (its stop). Every frame every driving crew is driven both ways from one snapshot
## (DriveTwinCase._compare_tick: the command, every Movement member and static, `heldpost_refusals` / `heldpost_holds_refused` and
## `pass_offer` included); the fight itself runs on the C++ drive and yield.

const WATCH_FRAMES := 20 * 30

var _lab: TacticsLab
var _was := not Traffic.off("heldpost")


func teardown() -> void:
	Traffic.set_off("heldpost", not _was)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


func _arm(held_verb: String) -> Array:
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	_lab = TacticsLab.create(self, 7, "yard_open")
	var held := _lab.unit(Match.Team.GREEN, "Green_Held", Vector3.ZERO, 0.0, "gang_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 20.0), 0.0, "law_tank")
	await _lab.start()
	if held_verb != "":
		assert_eq(_lab.orders.call("issue", {"units": ["Green_Held"], "verb": held_verb}), "", "setup: the %s is accepted" % held_verb)
	for i in 2 * SimClock.TICK_RATE:
		await _lab.step()
	assert_eq(_lab.orders.call("issue", {"units": ["Green_Asker"], "verb": "move", "to": [0.0, -24.0]}), "", "setup: the move")
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for tank: Tank in [held, asker]:
		var mover := Movement.of(tank)
		movers.append(mover)
		controllers.append(mover.ctl as OrderController)
	var refusals := Movement.heldpost_refusals
	var drives := 0
	var mismatches := 0
	var first := ""
	for frame in WATCH_FRAMES:
		BrainSwitches.native_drive = true  # the fight's own drive and yield: the C++ ones
		await _lab.step()
		var result := _compare_tick(movers, controllers, frame)
		drives += int(result[0])
		mismatches += int(result[1])
		if first == "" and String(result[2]) != "":
			first = result[2]
	var out := [drives, mismatches, first, Movement.heldpost_refusals - refusals]
	_lab.dispose()
	_lab = null
	return out


func test_the_held_post_refusal_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_the_held_post_refusal_is_the_live_gdscript"):  # its own process
		return
	if NativeExpect.absent(self):
		print("native: absent, the heldpost equality is not exercised in this run")
		return
	Traffic.set_off("heldpost", false)
	assert_true(BrainSwitches.native_yield, "ON keeps the C++ yield (traffic.gd's gate lifted for heldpost)")
	for verb: String in ["hold", ""]:
		var got: Array = await _arm(verb)
		print("native drive heldpost (%s): %d drives, %d mismatches, %d held refusals (C++ yield)" % [verb if verb != "" else "stop",
				got[0], got[1], got[3]])
		assert_eq(int(got[1]), 0, "the C++ drive and yield are the live GDScript with heldpost ON (%s): %s" % [verb, got[2]])
		# Held: the offer lets the asker by in ~3 s (88 drive ticks on the laptop); its stop: it gives way and waits (~660).
		assert_true(int(got[0]) >= (60 if verb == "hold" else 200), "the asker drove (%d)" % got[0])
		if verb == "hold":
			assert_true(int(got[3]) >= 1, "the held crew refused in the C++ yield (%d)" % got[3])
