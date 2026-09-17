extends TestCase
## Round 5 combat X5: a matchup-free answer to "can my gun kill that, and how fast?", from the rules themselves
## (penetration against the armor face, shields, rate of fire, heat). ai's SUPPRESS gate asked for it: the matchup
## table the champion brain runs without is not a rule, this is.


func test_a_cannon_kills_a_tank_far_faster_than_a_machine_gun_does() -> void:
	var cannon := Lethality.seconds_to_kill("tank", "tank", "front")
	var machine_gun := Lethality.seconds_to_kill("scout", "tank", "front")
	assert_true(cannon > 0.0 and cannon < 40.0, "a tank kills a tank from the front in reasonable time (%.1f s)" % cannon)
	assert_true(machine_gun > cannon * 4.0, "a scout's machine gun barely scratches a tank's front (%.1f s vs %.1f s)"
			% [machine_gun, cannon])
	assert_true(Lethality.is_slow_kill("scout", "tank", "front"), "so for a scout, a tank is a slow kill")
	assert_true(not Lethality.is_slow_kill("tank", "tank", "rear"), "and a tank from behind is not slow for a cannon")


func test_faces_matter_the_way_armor_says() -> void:
	var front := Lethality.seconds_to_kill("ifv", "tank", "front")
	var side := Lethality.seconds_to_kill("ifv", "tank", "side")
	var rear := Lethality.seconds_to_kill("ifv", "tank", "rear")
	assert_true(front > side and side > rear, "front %.1f > side %.1f > rear %.1f" % [front, side, rear])


func test_what_is_left_of_a_target_counts() -> void:
	var fresh := Lethality.seconds_to_kill("ifv", "scout", "side")
	var hurt := Lethality.seconds_to_kill("ifv", "scout", "side", 30, 0.0)
	assert_true(hurt < fresh * 0.5, "a nearly dead, unshielded scout dies much sooner (%.1f s vs %.1f s)" % [hurt, fresh])


func test_heat_limits_a_laser_in_a_long_fight() -> void:
	var laser := String(Units.stat("lancer", "weapon"))
	var burst_rate := 1.0 / float(Weapons.profile(laser)["reload_s"])
	assert_true(Lethality.rounds_per_second("lancer") < burst_rate, "sustained fire is heat-limited (%.2f/s < %.2f/s)"
			% [Lethality.rounds_per_second("lancer"), burst_rate])


func test_every_unit_has_an_answer_against_every_unit() -> void:
	for shooter: String in Units.PROFILES:
		for target: String in Units.PROFILES:
			var seconds := Lethality.seconds_to_kill(shooter, target, "side")
			assert_true(seconds > 0.0 and is_finite(seconds), "%s vs %s is a finite number (%s)" % [shooter, target, seconds])
