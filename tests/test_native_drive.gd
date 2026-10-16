extends DriveTwinCase
## Round 24 (native, N3c): `Movement.drive` natively against the live GDScript drive, on the live members, plus the
## harness's own check. The harness, the fight and the other cases: tests/native/drive_twin_case.gd (round 32, C32.8).


func test_the_harness_reaches_the_statics() -> void:
	var mover := Movement.new(null)
	var before := Movement.a1_replans
	assert_eq(mover.get("a1_replans"), before, "a static is read through the instance (MoverState's capture)")
	mover.set("a1_replans", before + 7)
	assert_eq(Movement.a1_replans, before + 7, "and written through it (MoverState's restore)")
	Movement.a1_replans = before
	assert_true(MoverState.static_names().has("a1_replans") and MoverState.static_names().has("give_ways") == false,
			"the statics are movement.gd's own `static var` lines")


func test_drive_is_the_live_gdscript() -> void:
	await _drive_case(false)
