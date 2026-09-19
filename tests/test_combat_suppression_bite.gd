extends TestCase
## X2 (round 4 combat): suppression has to CHANGE things, not just exist. The lead: *"vehicles make decisions to
## avoid walking into a wall of bullets that will kill them, and opposing forces could concentrate their fire power
## to create those suppressive fire effects or cut off an avenue"*, and a machine gun's value must be volume rather
## than damage.
##
## Each test prints a MEASURE line, so the numbers behind balance.md are reproducible:
##   make remote T="test FILTER=combat_suppression_bite"

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The lane runs along x at z = 0 on the west side, clear of foundry's cover (a crate sits at the arena center).
## The CROSSING point is fixed, because it is the one spot on this map known to be clear of obstacles; the GUN LINE is
## placed relative to it, scaled to the machine gun's effective band.
##
## N5 (round 6): those distances used to be written down (guns at x -55, aim at the gun's full 45 m reach, crossing at
## -16), which was fine while every weapon's band equalled its reach. It no longer does: at full reach the spread is
## (1 + Match.RANGE_SPREAD_FACTOR) = 4x wider, which turns the curtain this file is about into thin scattered fire and
## would have this test measuring range falloff instead of "can crews cut off an avenue". The gun line now sits so the
## crossing is at the same FRACTION of the band that it used to be of the reach.
const LANE_Z := 0.0
const CROSSING_X := -16.0
## Where the crossing sits along the gun line, as a fraction of the band (39 m of the old 45 m reach).
const CROSSING_FRACTION := 0.87

static func _lane_band() -> float:
	return Engagement.effective_range(Weapons.profile("machine_gun"))


## The gun line: back far enough that the crossing point sits at CROSSING_FRACTION of the band.
static func _lane_from() -> Vector3:
	return Vector3(CROSSING_X - _lane_band() * CROSSING_FRACTION, 0.0, LANE_Z)


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.seed_spawns(4242, 0.0)  # trip-up 38: spread and scatter are a dice roll until the RNG is seeded
	return game_match


## One unit a side, brains removed: these tests script the commands themselves.
func _pair(game_match: Match, green_unit: String, rust_unit: String) -> Array:
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": green_unit}]}]}), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
			"units": [{"unit": rust_unit}]}]}), "", "rust loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	return [game_match.tanks.get_node("Green_A_1") as Tank, game_match.tanks.get_node("Rust_A_1") as Tank]


# ---- "Cut off an avenue": crossing a streamed lane ----------------------------------

## How long the guns interdict the lane before the crosser sets off. A stream reaches its steady density in about
## three half-lives, and "is the lane shut?" is a question you ask about fire that is already falling.
const ESTABLISH_TICKS := SimClock.TICK_RATE * 3


## Run `crews` machine guns down the lane, then drive `crosser` across it. Returns what the crossing cost.
func _cross_the_lane(game_match: Match, gunners: Array[Tank], crosser: Tank, crews: int) -> Dictionary:
	for index in gunners.size():
		# Spread the crews along the lane's near side; a fixed-mount scout has to point down it (+x is yaw -90°).
		gunners[index].global_position = _lane_from() + Vector3(0.0, 0.0, (index - 1) * 4.0)
		gunners[index].rotation.y = -PI / 2.0
	crosser.global_position = Vector3(CROSSING_X, 0.0, LANE_Z - 26.0)
	crosser.rotation.y = PI  # facing +z, so full throttle drives it across the lane
	var aim := Vector3(_lane_from().x + _lane_band(), 0.0, LANE_Z)
	for tick in ESTABLISH_TICKS:
		for index in gunners.size():
			gunners[index].command = TankCommand.new(0.0, 0.0, aim + Vector3(0.0, 0.0, (index - 1) * 4.0), index < crews)
		crosser.command = TankCommand.new(0.0, 0.0, crosser.global_position + Vector3(0.0, 0.0, 10.0), false)
		await wait_physics_frames(1)
	var route_end := crosser.global_position + Vector3(0.0, 0.0, 52.0)
	var shut := game_match.is_beaten_zone(crosser.team, crosser.global_position, route_end)
	var field := game_match.threat_field(crosser.team)
	var density := snappedf(field.peak_along(crosser.global_position, route_end), 0.01)
	# How much fire the whole route is under, not just its worst cell: extra crews widen the curtain as much as they
	# deepen it, and what a crosser pays for is the time it spends inside.
	var exposure := snappedf(field.mean_along(crosser.global_position, route_end), 0.01)
	var start_health := crosser.health + crosser.shield
	var crossed_tick := -1
	var peak := 0.0
	for tick in SimClock.TICK_RATE * 12:
		for index in gunners.size():
			gunners[index].command = TankCommand.new(0.0, 0.0, aim + Vector3(0.0, 0.0, (index - 1) * 4.0), index < crews)
		crosser.command = TankCommand.new(1.0, 0.0, crosser.global_position + Vector3(0.0, 0.0, 10.0), false)
		await wait_physics_frames(1)
		peak = maxf(peak, crosser.suppression)
		if crossed_tick < 0 and crosser.global_position.z >= LANE_Z + 26.0:
			crossed_tick = tick
		if not crosser.is_alive() or crossed_tick >= 0:
			break
	return {"ticks": crossed_tick, "lost": snappedf(start_health - (crosser.health + crosser.shield), 0.1),
			"peak_suppression": snappedf(peak, 0.01), "alive": crosser.is_alive(), "shut": shut, "density": density,
			"exposure": exposure}


func test_machine_guns_shut_a_lane_and_more_of_them_shut_it_harder() -> void:
	var runs := {}
	for crews in [0, 1, 3]:
		var game_match := _setup()
		assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
				"units": [{"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}]}]}), "", "three scouts load")
		assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
				"units": [{"unit": "ifv"}]}]}), "", "the crosser loads")
		for brain in game_match.brains.get_children():
			brain.queue_free()
		await wait_physics_frames(1)
		var gunners: Array[Tank] = []
		for index in 3:
			gunners.append(game_match.tanks.get_node("Green_A_%d" % (index + 1)) as Tank)
		runs[crews] = await _cross_the_lane(game_match, gunners, game_match.tanks.get_node("Rust_A_1") as Tank, crews)
		(game_match.get_meta("arena") as Node).queue_free()
		game_match.queue_free()
		await wait_physics_frames(2)
	for crews in [0, 1, 3]:
		print("MEASURE lane_crossing crews=%d %s" % [crews, runs[crews]])

	var quiet: Dictionary = runs[0]
	var one: Dictionary = runs[1]
	var three: Dictionary = runs[3]
	assert_true(int(quiet["ticks"]) > 0, "the control crossing finishes (%d ticks)" % quiet["ticks"])
	assert_near(quiet["lost"], 0.0, 0.01, "and costs nothing when nobody is shooting")
	assert_true(not quiet["shut"], "an empty lane is not a beaten zone")
	assert_true(one["shut"], "one crew streaming down it IS, so a brain can refuse to cross (density %.2f)" % one["density"])
	# A hitscan stream aimed at a fixed point is a curtain a couple of sigma of spread thick (~3 m at this range), so
	# ONE crew costs a crossing vehicle a burst rather than its life; the price of the lane is mostly effectiveness.
	assert_true(float(one["lost"]) > 3.0, "crossing under one stream costs hit points (%.1f)" % one["lost"])
	assert_true(float(one["peak_suppression"]) >= Match.BEATEN_ZONE_DENSITY / Match.SUPPRESSION_FULL_DENSITY,
			"and the crew knows it (%.2f suppression)" % one["peak_suppression"])
	# "Opposing forces could concentrate their fire power to create those suppressive fire effects or cut off an
	# avenue": three crews on one lane must be much worse than one, in both damage and suppression.
	assert_true(float(three["exposure"]) > float(one["exposure"]) * 2.0,
			"three crews put far more of the route under fire (%.2f vs %.2f)" % [three["exposure"], one["exposure"]])
	assert_true(float(three["lost"]) > float(one["lost"]) * 1.8,
			"and hurt a crossing vehicle much more (%.1f vs %.1f)" % [three["lost"], one["lost"]])
	assert_true(float(three["peak_suppression"]) >= Tank.PINNED_SUPPRESSION,
			"and pin whatever tries it (%.2f)" % three["peak_suppression"])


# ---- "Concentrate their fire power": pinning --------------------------------------

func test_two_crews_on_one_target_pin_it_where_one_cannot() -> void:
	var game_match := _setup()
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "G", "squads": [{"name": "A",
			"units": [{"unit": "scout"}, {"unit": "scout"}]}]}), "", "two scouts load")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, {"name": "R", "squads": [{"name": "A",
			"units": [{"unit": "tank"}]}]}), "", "one tank loads")
	for brain in game_match.brains.get_children():
		brain.queue_free()
	await wait_physics_frames(1)
	var gunners: Array[Tank] = [game_match.tanks.get_node("Green_A_1") as Tank, game_match.tanks.get_node("Green_A_2") as Tank]
	var target := game_match.tanks.get_node("Rust_A_1") as Tank
	target.max_health = 1_000_000  # measuring suppression, not death
	target.health = 1_000_000
	target.global_position = Vector3(-60.0, 0.0, 0.0)
	var settled := {}
	for crews in [1, 2]:
		target.suppression = 0.0
		for index in gunners.size():
			gunners[index].global_position = Vector3(-60.0 + (index * 6.0 - 3.0), 0.0, -30.0)
			gunners[index].rotation.y = PI  # facing +z, at the target: a fixed mount only swings 8 degrees
		for tick in SimClock.TICK_RATE * 5:
			for index in gunners.size():
				gunners[index].command = TankCommand.new(0.0, 0.0, target.global_position, index < crews)
			target.command = TankCommand.new(0.0, 0.0, gunners[0].global_position, false)
			await wait_physics_frames(1)
		settled[crews] = snappedf(target.suppression, 0.01)
	print("MEASURE pinning one_crew %.2f two_crews %.2f (pin at %.2f)"
			% [settled[1], settled[2], Tank.PINNED_SUPPRESSION])
	assert_true(settled[1] > 0.2, "one machine gun rattles a tank (%.2f)" % settled[1])
	assert_true(settled[1] < Tank.PINNED_SUPPRESSION, "but cannot pin it on its own (%.2f)" % settled[1])
	assert_true(settled[2] >= Tank.PINNED_SUPPRESSION, "two crews on the same target do (%.2f)" % settled[2])


# ---- "Pinning should be worth doing" ----------------------------------------------

func test_a_pinned_gunner_misses_what_it_would_otherwise_hit() -> void:
	var results := {}
	for suppression in [0.0, 1.0]:
		var game_match := _setup()
		var pair: Array = await _pair(game_match, "tank", "tank")
		var gunner: Tank = pair[0]
		var target: Tank = pair[1]
		# N5 (round 6): inside the cannon's effective band, derived from the weapon. This test measures what
		# SUPPRESSION costs a gunner's aim; at the old fixed 60 m the shot is now beyond the band, so range falloff
		# (Match.range_spread_multiplier) dominated and the calm control only hit 46% — two effects in one number.
		# What a long shot costs is measured on its own, below.
		var band := Engagement.effective_range(Weapons.profile("cannon"))
		gunner.global_position = Vector3(-60.0, 0.0, band * 0.4)
		target.global_position = Vector3(-60.0, 0.0, -band * 0.4)
		target.max_health = 1_000_000
		target.health = 1_000_000
		target.max_shield = 0.0
		target.shield = 0.0
		for tick in SimClock.TICK_RATE * 62:  # 5 s reload: about a dozen shells
			gunner.suppression = suppression  # held there: this measures the accuracy cost alone
			gunner.command = TankCommand.new(0.0, 0.0, target.global_position, true)
			target.command = TankCommand.new(0.0, 0.0, gunner.global_position, false)
			await wait_physics_frames(1)
		results[suppression] = {"shots": game_match.stats["shots"][Match.Team.GREEN],
				"hits": game_match.stats["hits"][Match.Team.GREEN]}
		(game_match.get_meta("arena") as Node).queue_free()
		game_match.queue_free()
		await wait_physics_frames(2)
	var calm: Dictionary = results[0.0]
	var pinned: Dictionary = results[1.0]
	var calm_rate := float(calm["hits"]) / maxf(float(calm["shots"]), 1.0)
	var pinned_rate := float(pinned["hits"]) / maxf(float(pinned["shots"]), 1.0)
	var band := Engagement.effective_range(Weapons.profile("cannon"))
	print("MEASURE pinned_accuracy inside the band (%.0f m of %.0f): calm %d/%d (%.0f%%), pinned %d/%d (%.0f%%)"
			% [band * 0.8, band, calm["hits"], calm["shots"], calm_rate * 100.0, pinned["hits"], pinned["shots"],
			pinned_rate * 100.0])
	assert_true(int(calm["shots"]) >= 8, "the control fired enough shells to measure (%d)" % calm["shots"])
	assert_eq(pinned["shots"], calm["shots"], "a pinned crew still shoots as often: only its aim suffers")
	assert_true(calm_rate > 0.7, "a calm tank hits a standing target inside its band (%.0f%%)" % (calm_rate * 100.0))
	assert_true(pinned_rate < calm_rate - 0.2, "a pinned one misses a lot more (%.0f%% vs %.0f%%)"
			% [pinned_rate * 100.0, calm_rate * 100.0])


func test_pinning_buys_a_flanker_time_to_get_round() -> void:
	# Why "pin, then flank" is a real plan: heads down, the gunner is slow to swing onto the new threat.
	var swing := {}
	for suppression in [0.0, 1.0]:
		var game_match := _setup()
		var pair: Array = await _pair(game_match, "tank", "scout")
		var gunner: Tank = pair[0]
		var flanker: Tank = pair[1]
		gunner.global_position = Vector3(-60.0, 0.0, 0.0)
		gunner.rotation.y = 0.0
		gunner.turret.rotation.y = 0.0
		flanker.global_position = Vector3(-20.0, 0.0, 0.0)  # dead on the gunner's flank
		var ticks := -1
		for tick in SimClock.TICK_RATE * 8:
			gunner.suppression = suppression
			gunner.command = TankCommand.new(0.0, 0.0, flanker.global_position, false)
			flanker.command = TankCommand.new()
			await wait_physics_frames(1)
			var aim := gunner.turret_forward().signed_angle_to(
					(flanker.global_position - gunner.global_position).normalized(), Vector3.UP)
			if absf(aim) <= deg_to_rad(float(gunner.weapon["aim_tolerance_deg"])):
				ticks = tick
				break
		swing[suppression] = ticks
		(game_match.get_meta("arena") as Node).queue_free()
		game_match.queue_free()
		await wait_physics_frames(2)
	print("MEASURE turret_swing_90deg calm %d ticks, pinned %d ticks" % [swing[0.0], swing[1.0]])
	assert_true(swing[0.0] > 0, "a calm turret comes round (%d ticks)" % swing[0.0])
	assert_true(swing[1.0] > 0, "a pinned one gets there eventually too (%d ticks)" % swing[1.0])
	assert_true(swing[1.0] >= swing[0.0] * 1.6, "but takes far longer, which is the flanker's window (%d vs %d)"
			% [swing[1.0], swing[0.0]])


func test_volume_beats_damage_at_suppressing() -> void:
	# The lead's rule for machine guns: their value is volume. Compare suppression laid down per second of fire.
	var per_second := {}
	for weapon_id in ["machine_gun", "autocannon", "cannon", "laser", "mortar"]:
		var weapon := Weapons.profile(weapon_id)
		var reload: float = maxf(float(weapon.get("reload_s", weapon["reload"])), SimClock.TICK_SECONDS)
		var rounds := maxi(1, int(weapon.get("burst_count", 1)))
		per_second[weapon_id] = snappedf(Weapons.suppression(weapon) * rounds / reload, 0.01)
	print("MEASURE suppression_per_second %s" % [per_second])
	assert_true(per_second["machine_gun"] > per_second["cannon"] * 2.0,
			"a machine gun suppresses far more than a tank cannon (%.2f vs %.2f/s)"
			% [per_second["machine_gun"], per_second["cannon"]])
	assert_true(per_second["machine_gun"] > per_second["autocannon"],
			"and more than the 25 mm (%.2f vs %.2f/s)" % [per_second["machine_gun"], per_second["autocannon"]])
	assert_true(per_second["machine_gun"] > per_second["laser"] * 3.0,
			"a silent beam suppresses least (%.2f vs %.2f/s)" % [per_second["laser"], per_second["machine_gun"]])
	# ...while its damage stays the worst in the game against anything armored.
	assert_true(Match.armor_multiplier(Weapons.profile("machine_gun"), "tank", "front") <= 0.1,
			"the machine gun still cannot scratch a tank's front: volume, not damage")


# ---- N5 (round 6): is reaching past the band a real trade, or free reach? ----------------
# squad's question when it wired `long_shot: true` into support-by-fire tasks: a posted SBF element fights at the
# weapon's full range as a matter of course, which for a cannon is 56% further out than an unposted crew. If the
# falloff past the band is not a real cost, "always task support-by-fire" becomes the dominant strategy and fire
# discipline only ever binds the side that forgot to use it. This measures the price of that reach.
# The gunner is commanded directly, so the engagement envelope's gates are not in play — only accuracy is.

func test_a_shot_beyond_the_effective_band_is_a_real_gamble() -> void:
	var band := Engagement.effective_range(Weapons.profile("cannon"))
	var reach := float(Weapons.profile("cannon")["range"])
	var rates := {}
	for distance in [band * 0.8, reach]:
		var game_match := _setup()
		var pair: Array = await _pair(game_match, "tank", "tank")
		var gunner: Tank = pair[0]
		var target: Tank = pair[1]
		gunner.global_position = Vector3(-60.0, 0.0, distance / 2.0)
		target.global_position = Vector3(-60.0, 0.0, -distance / 2.0)
		target.max_health = 1_000_000
		target.health = 1_000_000
		target.max_shield = 0.0
		target.shield = 0.0
		for tick in SimClock.TICK_RATE * 62:  # a 5 s reload: about a dozen shells
			gunner.command = TankCommand.new(0.0, 0.0, target.global_position, true)
			target.command = TankCommand.new(0.0, 0.0, gunner.global_position, false)
			await wait_physics_frames(1)
		rates[distance] = {"shots": game_match.stats["shots"][Match.Team.GREEN],
				"hits": game_match.stats["hits"][Match.Team.GREEN]}
		(game_match.get_meta("arena") as Node).queue_free()
		game_match.queue_free()
		await wait_physics_frames(2)
	var inside: Dictionary = rates[band * 0.8]
	var outside: Dictionary = rates[reach]
	var inside_rate := float(inside["hits"]) / maxf(float(inside["shots"]), 1.0)
	var outside_rate := float(outside["hits"]) / maxf(float(outside["shots"]), 1.0)
	print("MEASURE long_shot_cost: inside the band (%.0f m) %d/%d (%.0f%%), at full reach (%.0f m) %d/%d (%.0f%%)"
			% [band * 0.8, inside["hits"], inside["shots"], inside_rate * 100.0,
			reach, outside["hits"], outside["shots"], outside_rate * 100.0])
	assert_true(int(inside["shots"]) >= 8 and int(outside["shots"]) >= 8,
			"both runs fired enough shells to measure (%d, %d)" % [inside["shots"], outside["shots"]])
	assert_true(inside_rate > 0.7, "inside its band a stationary gun is reliable (%.0f%%)" % (inside_rate * 100.0))
	# The bar the design needs: reach past the band must COST something a commander can feel. Half the hit rate is a
	# trade; a tenth off is free reach and would make support-by-fire strictly dominant.
	assert_true(outside_rate < inside_rate * 0.65,
			"and at full reach it is a gamble, not free reach (%.0f%% against %.0f%%)"
			% [outside_rate * 100.0, inside_rate * 100.0])
