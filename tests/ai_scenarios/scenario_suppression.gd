extends TestCase
## Round-4 X3: suppression-aware behavior (contract L2, read through SuppressionFeed). The lead: *"vehicles make
## decisions to avoid walking into a wall of bullets that will kill them, and opposing forces could concentrate their
## fire power to create those suppressive fire effects or cut off an avenue."*
##
## Two things are measured, both against a control on the same seed:
##   1. a unit ordered across a swept lane does not drive through the wall of bullets,
##   2. suppressing an enemy lets a teammate work on it — combat measured a pinned tank hitting 5 of 13 shells where
##      a calm one hits 13 of 13, and taking twice as long to swing its turret,
##   3. and suppressive fire is fire held on a PLACE, not fire that chases a unit.
##
## Open ground west of the walls unless a scenario needs cover.

const PENDING := []


func _issue(orders: Object, units: Array, verb: String, extra := {}) -> void:
	var command := {"units": units.map(func(t: Tank) -> String: return String(t.name)), "verb": verb, "queue": false}
	command.merge(extra, true)
	assert_eq(orders.call("issue", command), "", "order accepted: %s" % [command])


# ---- 1. don't walk into a wall of bullets ------------------------------------------------------

func test_a_unit_ordered_across_a_swept_lane_keeps_out_of_the_fire() -> void:
	var swept := await _cross_the_lane(true)
	var ignored := await _cross_the_lane(false)
	print("MEASURE suppression_beaten_zone %d ticks in the beaten zone avoiding it vs %d ignoring it; arrived %s / %s, worst suppression %.2f / %.2f, rounds down the lane %d / %d, peak density %.2f / %.2f (beaten at %.1f)" % [
			swept["in_zone"], ignored["in_zone"], swept["arrived"], ignored["arrived"],
			swept["suppression"], ignored["suppression"], swept["rounds"], ignored["rounds"],
			swept["peak"], ignored["peak"], Match.BEATEN_ZONE_DENSITY])
	print("      steered off its route on %d / %d ticks, looked and found no way round on %d / %d" % [
			swept["detours"], ignored["detours"], swept["no_way"], ignored["no_way"]])
	print("      route ahead beaten on %d / %d ticks; swung %d m / %d m off the straight line to the goal" % [
			swept["ahead_beaten"], ignored["ahead_beaten"], swept["detoured"], ignored["detoured"]])
	# How far off the straight line it went is printed, not asserted: a lane is swept in TIME as well as space, and
	# what this unit mostly does is wait out a burst and cross in the gap rather than drive a wide arc. Both count as
	# not walking into the wall of bullets; only the time spent in it is the thing worth holding to.
	assert_true(int(ignored["rounds"]) >= 20, "setup: the machine guns are actually firing (%d rounds)" % ignored["rounds"])
	assert_true(bool(ignored["arrived"]), "setup: the control gets there at all")
	assert_true(int(ignored["in_zone"]) >= SimClock.TICK_RATE / 2, "setup: the lane really is a wall of bullets (%d ticks)" % ignored["in_zone"])
	assert_true(int(swept["in_zone"]) < int(ignored["in_zone"]) * 0.7,
			"a unit that reads the field spends far less of the crossing in it (%d vs %d ticks)" % [swept["in_zone"], ignored["in_zone"]])
	assert_true(float(swept["suppression"]) < float(ignored["suppression"]),
			"and takes less of the fire for it (%.2f vs %.2f)" % [swept["suppression"], ignored["suppression"]])
	assert_true(bool(swept["arrived"]), "and it still gets where it was sent")


## One green unit ordered across a lane two machine guns are sweeping. With `avoid` false the same run happens with
## the brain's view of the field taken away, which is the control: same seed, same fire, no reading of it.
## How far `point` is from the straight line from `from` to `to`, in meters.
static func _off_the_line(from: Vector3, to: Vector3, point: Vector3) -> float:
	var line := Vector2(to.x - from.x, to.z - from.z)
	var offset := Vector2(point.x - from.x, point.z - from.z)
	var length := line.length()
	if length < 0.01:
		return offset.length()
	return absf(offset.x * line.y - offset.y * line.x) / length


func _cross_the_lane(avoid: bool) -> Dictionary:
	var s := AiScenario.create(self, 21)
	var mover := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-84, 0, 40), 0.0, {}, "ifv")
	AiScenario.make_durable(mover)
	# Two machine guns off to the east, sweeping the ground the mover has to cross.
	# Two machine guns off to the east, sweeping the lane the mover has to cross. A machine gun only reaches 45 m,
	# so they sit close enough for the rounds to actually land on it.
	var guns: Array[Tank] = []
	for i in 2:
		var lane_z := 8.0 + i * 8.0
		# Facing west, at the lane: forward is -Z, and +PI/2 yaw swings it to -X (orientation.md trip-up 2).
		var gun := s.shooter(Match.Team.RUST, "Rust_G_%d" % (i + 1), Vector3(-52, 0, lane_z), PI / 2.0,
				{"type": "stop"}, {"type": "suppress", "x": -86.0, "z": lane_z}, "scout")
		AiScenario.make_durable(gun)
		guns.append(gun)
	if not avoid:
		# The control is a brain variant, not a changed world: the same fire, the same seed, a brain that can't read
		# the field (`x4ns`). Reset in teardown by BrainVariants.reset() below.
		BrainVariants.use(Match.Team.GREEN, "x4ns")
	var goal := Vector3(-84, 0, -24)
	var start := mover.global_position
	_issue(s.orders(), [mover], "move", {"to": [goal.x, goal.z]})
	OrderController.fire_detours = 0
	OrderController.fire_no_way_round = 0
	await s.start()
	var in_zone := 0
	var worst := 0.0
	var peak_density := 0.0
	var ahead_beaten := 0
	var detoured := 0
	var arrived := false
	var controller := s.controller_of(mover)
	for tick in SimClock.TICK_RATE * 26:
		await s.step()
		# The predicate the brain itself uses: is the ground it is about to drive over a wall of bullets?
		var nose := -mover.global_basis.z
		if s.game_match.is_beaten_zone(Match.Team.GREEN, mover.global_position,
				mover.global_position + Vector3(nose.x, 0.0, nose.z).normalized() * OrderController.FIRE_LOOKAHEAD):
			ahead_beaten += 1
		# How far it is from the straight line between where it started and where it was sent: the spectator's
		# version of "it went round".
		detoured = maxi(detoured, roundi(_off_the_line(start, goal, mover.global_position)))
		var density := s.game_match.threat_field(Match.Team.GREEN).at(mover.global_position)
		peak_density = maxf(peak_density, density)
		if density >= Match.BEATEN_ZONE_DENSITY:
			in_zone += 1
		worst = maxf(worst, mover.suppression)
		if Vector2(mover.global_position.x - goal.x, mover.global_position.z - goal.z).length() < 6.0:
			arrived = true
			break
	var fired := 0
	for gun in guns:
		fired += s.shots_by(gun)
	var result := {"in_zone": in_zone, "arrived": arrived, "suppression": worst, "rounds": fired,
			"peak": peak_density, "ahead_beaten": ahead_beaten, "detoured": detoured,
			"detours": OrderController.fire_detours, "no_way": OrderController.fire_no_way_round}
	BrainVariants.reset()
	s.dispose()
	return result


# ---- 2. suppressing enables a flank ------------------------------------------------------------

func test_holding_a_crew_down_lets_a_teammate_work_on_it() -> void:
	var suppressed := await _pin_and_flank(true)
	var quiet := await _pin_and_flank(false)
	print("MEASURE suppression_enables_flank target suppression %.2f vs %.2f; it landed %d of %d shells vs %d of %d; the flanker dealt %d vs %d, spending its time on %s vs %s" % [
			suppressed["suppression"], quiet["suppression"], suppressed["hits_landed"], suppressed["shots"],
			quiet["hits_landed"], quiet["shots"], suppressed["damage"], quiet["damage"],
			suppressed["options"], quiet["options"]])
	assert_true(float(suppressed["suppression"]) >= Tank.PINNED_SUPPRESSION,
			"two machine guns pin the crew (%.2f)" % suppressed["suppression"])
	assert_true(float(quiet["suppression"]) < Tank.PINNED_SUPPRESSION,
			"setup: without the machine guns the crew is never pinned (%.2f — the flanker's own cannon suppresses a little)"
			% quiet["suppression"])
	assert_true(int(quiet["shots"]) >= 3 and int(suppressed["shots"]) >= 3, "setup: it shoots in both runs (%d / %d)" % [
			suppressed["shots"], quiet["shots"]])
	var pinned_rate := float(suppressed["hits_landed"]) / float(suppressed["shots"])
	var calm_rate := float(quiet["hits_landed"]) / float(quiet["shots"])
	assert_true(pinned_rate < calm_rate * 0.7,
			"a pinned crew shoots far worse (%.0f%% of shells landed vs %.0f%%)" % [pinned_rate * 100.0, calm_rate * 100.0])
	assert_true(int(suppressed["damage"]) > int(quiet["damage"]),
			"and the teammate working on it gets more done (%d vs %d damage)" % [suppressed["damage"], quiet["damage"]])


## Two machine guns and a third vehicle against one tank. (The third one mostly chooses COVER_FIRE rather than FLANK —
## the printed option counts say so — so what this measures is "a pinned crew lets a teammate work on it", not a flank
## specifically. The pinned-target flank bonus exists; whether it should out-score peeking from cover is a tuning
## question for the ladder, noted in the stream's Status.)
## Two machine guns and a flanker against one tank. With `firing` false the guns hold their fire: the control for
## "does holding a crew down change anything", same seed, same three vehicles in the same places. What's measured is
## the TARGET's shooting — shells landed out of shells fired — because that is what suppression is supposed to ruin,
## and it doesn't depend on which of our units it chose to shoot at.
func _pin_and_flank(firing: bool) -> Dictionary:
	var s := AiScenario.create(self, 22)
	var target := s.shooter(Match.Team.RUST, "Rust_A_1", Vector3(-80, 0, -20), 0.0)
	AiScenario.make_durable(target)
	var gunners: Array[Tank] = []
	for i in 2:
		var gun := s.shooter(Match.Team.GREEN, "Green_B_%d" % (i + 1), Vector3(-92.0 + i * 24.0, 0, 16), PI,
				{"type": "stop"},
				{"type": "target", "name": "Rust_A_1", "fallback": false} if firing else {"type": "hold_fire"}, "scout")
		AiScenario.make_durable(gun)
		gunners.append(gun)
	var flanker := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-108, 0, 4), PI)
	AiScenario.make_durable(flanker)
	_issue(s.orders(), [flanker], "attack", {"target": "Rust_A_1"})
	await s.start()
	var green := gunners + [flanker]
	var green_health := 0.0
	for tank in green:
		green_health += tank.health + tank.shield
	var target_health := target.health + target.shield
	var hits_landed := 0
	var worst := 0.0
	var options := {}
	var brain := s.brain_of(flanker)
	# Long enough for a slow gun to fire a dozen times: with five shells a single lucky one moves the hit rate 20
	# points, which is not a measurement (round 5, after guns started firing at their designed rate).
	for tick in SimClock.TICK_RATE * 60:
		await s.step()
		worst = maxf(worst, target.suppression)
		var option := String(brain.choice.get("option", ""))
		options[option] = int(options.get(option, 0)) + 1
		var now := 0.0
		for tank in green:
			now += tank.health + tank.shield
		if now < green_health - 0.5:
			hits_landed += 1
			green_health = now
	var result := {"hits_landed": hits_landed, "shots": s.shots_by(target), "suppression": worst,
			"damage": int(target_health - (target.health + target.shield)), "options": options}
	s.dispose()
	return result


# ---- 3. suppressive fire hoses a place, it doesn't chase a unit ---------------------------------

func test_holding_the_aim_point_suppresses_far_better_than_tracking() -> void:
	# Combat's measurement of the mechanic (balance.md): a round stamps the cells it FLEW THROUGH, so a gun streaming
	# at a fixed point piles its fire into one place while a gun tracking a moving unit spreads it thin. That makes
	# "aim at ground" not a fallback for when the target is hidden but the whole point of suppressive fire — so the
	# SUPPRESS option holds its aim point instead of following the target, and this is what says it still matters.
	var held := await _hose(true)
	var chased := await _hose(false)
	print("MEASURE suppression_held_aim held point: peak suppression %.2f, peak density %.2f, %d rounds; tracking: %.2f, %.2f, %d rounds" % [
			held["suppression"], held["density"], held["rounds"], chased["suppression"], chased["density"], chased["rounds"]])
	assert_true(int(held["rounds"]) > int(chased["rounds"]) * 3,
			"a gun told to hose a place keeps firing; one told to track a unit stops every time the unit is out of reach or out of sight (%d rounds vs %d)"
			% [held["rounds"], chased["rounds"]])
	assert_true(float(held["density"]) >= Match.BEATEN_ZONE_DENSITY * 0.5 and float(chased["density"]) < 0.2,
			"and it is the held fire that marks the ground: %.2f density against %.2f" % [held["density"], chased["density"]])
	assert_true(float(held["suppression"]) > float(chased["suppression"]),
			"so the unit crossing it is the more suppressed (%.2f vs %.2f)" % [held["suppression"], chased["suppression"]])


## One machine gun against a unit driving across its front, either hosing the ground the unit is crossing (`held`) or
## tracking the unit itself. Returns what the fire achieved.
func _hose(held: bool) -> Dictionary:
	var s := AiScenario.create(self, 23)
	var crossing := Vector3(-92, 0, 0)
	var mover := s.shooter(Match.Team.GREEN, "Green_A_1", Vector3(-92, 0, 24), 0.0,
			{"type": "move_to", "x": crossing.x, "z": -24.0}, {"type": "hold_fire"})
	AiScenario.make_durable(mover)
	var gun := s.shooter(Match.Team.RUST, "Rust_G_1", Vector3(-56, 0, 0), PI / 2.0, {"type": "stop"},
			{"type": "suppress", "x": crossing.x, "z": crossing.z} if held
			else {"type": "target", "name": "Green_A_1", "fallback": false}, "scout")
	AiScenario.make_durable(gun)
	await s.start()
	var worst := 0.0
	var density := 0.0
	for tick in SimClock.TICK_RATE * 16:
		await s.step()
		worst = maxf(worst, mover.suppression)
		density = maxf(density, s.game_match.threat_field(Match.Team.GREEN).at(crossing))
	var result := {"suppression": worst, "density": density, "rounds": s.shots_by(gun)}
	s.dispose()
	return result
