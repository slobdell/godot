extends TestCase
## Round 26, brains B0 (C26.3), end to end: a squad given an armed task WITH a drawn facing ends up with its hulls
## pointing the way he drew, in a real match (the arena, the brains, nav), not only in the plan. The unit-level half is
## test_tactics_facing_tasks.gd. Orders' O2 pass line is "heading on the ground within 15 deg of the drawn facing": a
## firing line's crews keep their interlocking sectors (the outer crews look up to 30 deg out to the flanks, doctrine),
## so the line's MEAN hull heading is held to 15 deg and every crew to its sector's width.
##
## He drew east; the squad drives up from the south, so its own geometry would have faced north.
## Round 31 (C31.9 / R31.9): the stage of test_tactics_facing_tasks_live*.gd (split by time); no tests of its own.

const EAST := Vector3(1, 0, 0)
const LANE_X := TacticsScenarios.LANE_X


func _forward(tank: Tank) -> Vector3:
	return TacticsFormation.flat(-tank.global_basis.z)
func _run(seed_value: int, task: Dictionary, seconds: int, what: String, guns_judged := false) -> void:
	var lab := TacticsLab.create(self, seed_value)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(LANE_X + i * 8.0 - 12.0, 0, 50), 0.0).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	assert_eq(alpha.assign(task), "", "setup: %s with a facing is a valid task" % what)
	for tick in SimClock.TICK_RATE * seconds:
		await lab.step()
	var mean := Vector3.ZERO
	var worst := 0.0
	for unit_name: String in names:
		var forward := _forward(lab.tank_of(unit_name))
		mean += forward
		worst = maxf(worst, rad_to_deg(forward.angle_to(EAST)))
	var off := rad_to_deg(TacticsFormation.flat(mean).angle_to(EAST))
	# Round 27 (B5): where the GUNS point, the squad's mean turret heading (orders' probe: an ambush read a flat 30 deg).
	var guns := Vector3.ZERO
	for unit_name: String in names:
		guns += TacticsFormation.flat(lab.tank_of(unit_name).turret_forward())
	var gun_off := rad_to_deg(TacticsFormation.flat(guns).angle_to(EAST))
	print("MEASURE b0_facing %s element heading %s, mean hull %.1f deg off, worst %.1f deg, mean gun %.1f deg off" % [what,
			alpha.heading, off, worst, gun_off])
	if guns_judged:
		assert_true(gun_off <= 15.0, "%s: the squad's guns look the way he drew (mean %.1f deg off)" % [what, gun_off])
	assert_true((alpha.heading as Vector3).dot(EAST) > 0.996, "%s: the formation is laid facing east (%s)"
			% [what, alpha.heading])
	assert_true(off <= 15.0, "%s: the squad's hulls face the way he drew (mean %.1f deg off)" % [what, off])
	assert_true(worst <= 45.0, "%s: no crew looks away from it (worst %.1f deg)" % [what, worst])
	lab.dispose()
