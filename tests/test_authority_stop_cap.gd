extends TestCase
## Round 45 (engage E6, R45.22): a scout HE stops stays stopped. A hull-fixed wheeled crew cannot pivot, so under a stop
## its gun's turn-in (Manoeuvre.turn_in, C33.9) drove it round onto a live enemy: 4 m on the authority probe (11330). Under
## his stop or hold it rolls at most TankBrain.TURN_IN_CAP_M from where it came to rest; with the rule off it swings freely.


func _stage(authority: bool) -> Dictionary:
	var was := Drills.PLAYER_AUTHORITY
	Drills.PLAYER_AUTHORITY = authority
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	# The scout faces -Z; the enemy stands off its right side, out of a fixed gun's arc: it must turn to shoot.
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0, {}, "scout")
	AiScenario.make_durable(me)
	var enemy := s.dummy(Match.Team.RUST, "Rust_A_1", Vector3(-70, 0, 40), 0.0)
	AiScenario.make_durable(enemy)
	await s.start()
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "stop", "source": "player"}), "", "setup: his stop is accepted")
	var rest: Variant = null
	var farthest := 0.0
	var stopping := true
	for tick in SimClock.TICK_RATE * 6:
		await s.step()
		var here := Vector3(me.global_position.x, 0.0, me.global_position.z)
		if rest == null and me.estimated_velocity.length() < TankBrain.STOPPED_SPEED:
			rest = here
		# Where his STOP ends (R45.22: E6): from where the crew came to rest until the stop completes. What it does after
		# (the post's hold: a wheeled hull's face creep, as shipped) is E1's hold slack, not this.
		if rest is Vector3 and stopping:
			farthest = maxf(farthest, here.distance_to(rest))
		stopping = stopping and not s.orders().current("Green_A_1").is_empty()
	var result := {"farthest": farthest, "shots": s.shots_by(me), "rested": rest != null}
	s.dispose()
	Drills.PLAYER_AUTHORITY = was
	return result


func test_a_scout_he_stops_does_not_roll_off_to_swing_its_gun_round() -> void:
	var on := await _stage(true)
	var off := await _stage(false)
	print("MEASURE authority_stop_cap on %s | off %s" % [on, off])
	assert_true(bool(on["rested"]) and bool(off["rested"]), "setup: the scout comes to rest in both arms")
	assert_true(float(off["farthest"]) > TankBrain.TURN_IN_CAP_M + 0.5,
			"setup: with the rule off it rolls round to aim (%.1f m), the case this guards" % off["farthest"])
	assert_true(float(on["farthest"]) <= TankBrain.TURN_IN_CAP_M + 0.5,
			"his stop ends at most the cap from where it came to rest (%.1f m)" % on["farthest"])
	# The trade ruled (b) (R45.22): an enemy outside a fixed gun's arc that a swing inside the cap cannot reach is not shot
	# until it comes into the arc. MEASURE says how many fewer; Bar E2b's G2 counts it over a workload.
