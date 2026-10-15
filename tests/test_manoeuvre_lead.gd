extends TestCase
## Round 31, manoeuvre H3 (C31.4, `--gun-off=realspeed` = ON, opt-in until CP-H): **the two aim leads read the motion
## a target really makes.** A truck pinned on a parked squadmate moves 0 m/s while the plant reports ~12 m/s (design B,
## round 30); with the switch a gun leads it by its real motion, without it by the plant's reading (round 30's lines).


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func _pinned_lead(on: bool) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := Manoeuvre._gun_off
	var was_parsed := Manoeuvre._gun_off_parsed
	Manoeuvre._gun_off = PackedStringArray(["realspeed"]) if on else PackedStringArray()
	Manoeuvre._gun_off_parsed = true
	BrainSwitches.native = false
	var lab := TacticsLab.create(self, 31)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, "gang_tank")
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 32), 0.0, "gang_tank")
	await lab.start()
	_controller_of(lab, a).set_physics_process(false)
	_controller_of(lab, b).set_physics_process(false)
	for tick in SimClock.TICK_RATE * 3:
		b.command = TankCommand.new(1.0, 0.0, b.global_position + Vector3(0, 0, -20))
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		await lab.step()
	var out := {"lead": Manoeuvre.lead_velocity(b).length(), "real": b.real_velocity.length(),
			"estimated": b.estimated_velocity.length()}
	lab.dispose()
	BrainSwitches.native = was_native
	Manoeuvre._gun_off = was_off
	Manoeuvre._gun_off_parsed = was_parsed
	return out


func test_a_pinned_truck_is_led_by_its_real_motion_with_the_switch() -> void:
	var now := await _pinned_lead(true)
	var base := await _pinned_lead(false)
	print("MEASURE h3_lead pinned gang_tank: lead %.2f m/s with realspeed (real %.2f, plant %.2f) | %.2f without" % [
			now["lead"], now["real"], now["estimated"], base["lead"]])
	assert_true(now["estimated"] > 3.0, "setup: the plant reports the phantom speed (%.2f)" % now["estimated"])
	assert_true(now["lead"] < 1.0, "realspeed: the lead is the real motion (%.2f m/s)" % now["lead"])
	assert_true(absf(base["lead"] - base["estimated"]) < 0.01, "switched off: round 30's lead, the plant's reading (%.2f)" % base["lead"])
