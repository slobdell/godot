extends TestCase
## Round 35, manoeuvre W1b (C35.6, R35.7): **a wheeled hull held to a standstill does not creep.** W1's trace: crews Traffic
## held at a street mouth under fire were 41 % of wedged deaths, and at the spot (pace 0, facing the squad's way) a wheeled
## hull's throttle 0 at full lock is the plant's creep, shuffling it in the lane mouth. `Manoeuvre.wheel_halt` turns such a
## drive's turn to 0 (ON arm); `--nav-off=wheelhalt` flips the default. The live effect is the series' (the probe counts
## pace-0 wheeled ticks that still MOVED); this pins the rule.


func _arm(on: bool) -> PackedStringArray:
	return PackedStringArray([]) if on == Manoeuvre.WHEEL_HALT_DEFAULT else PackedStringArray(["wheelhalt"])


func _halt(on: bool, radius: float, pace: float, kturn_m: float, throttle: float, turn: float) -> TankCommand:
	var was := Movement._off
	Movement._off = _arm(on)
	var cmd := TankCommand.new(throttle, turn)
	Manoeuvre.wheel_halt(cmd, radius, pace, kturn_m, 1)
	Movement._off = was
	return cmd


func test_a_pace_zero_wheeled_drive_stands_instead_of_creeping() -> void:
	var asks := Manoeuvre.wheel_halt_asks
	var halts := Manoeuvre.wheel_halts
	var cmd := _halt(true, 6.0, 0.0, 0.0, 0.0, 1.0)
	assert_eq(cmd.turn, 0.0, "the turn is dropped: nothing for the plant to creep on")
	assert_eq(cmd.throttle, 0.0, "and it stands")
	assert_eq(Manoeuvre.wheel_halt_asks - asks, 1, "counted as an ask")
	assert_eq(Manoeuvre.wheel_halts - halts, 1, "and a halt")


func test_switched_off_the_creep_stands_as_before() -> void:
	var asks := Manoeuvre.wheel_halt_asks
	var halts := Manoeuvre.wheel_halts
	var cmd := _halt(false, 6.0, 0.0, 0.0, 0.0, -1.0)
	assert_eq(cmd.turn, -1.0, "the base arm keeps the turn (the plant creeps)")
	assert_eq(Manoeuvre.wheel_halt_asks - asks, 1, "the ask is counted in the base arm too (the counter is non-zero there)")
	assert_eq(Manoeuvre.wheel_halts - halts, 0, "no halt")


func test_everything_else_is_untouched() -> void:
	assert_eq(_halt(true, 6.0, 0.4, 0.0, 0.0, 1.0).turn, 1.0, "a drive with pace keeps its turn")
	assert_eq(_halt(true, 6.0, 0.0, 2.0, -1.0, 1.0).turn, 1.0, "a planned k-turn leg is driven as planned")
	assert_eq(_halt(true, 0.0, 0.0, 0.0, 0.0, 1.0).turn, 1.0, "tracks pivot in place: no creep to stop")
	assert_eq(_halt(true, 6.0, 0.0, 0.0, 0.8, 1.0).turn, 1.0, "a throttle above the creep threshold is driving, not creeping")
