extends TestCase
## N5 (round 6, CP4): the engagement envelope. The lead, twice: "units see each other and then everyone just starts
## firing". These tests pin the three gates that now stand between seeing and shooting, and they are written against
## the RULE (game/combat/engagement.gd), not against today's numbers — the effective bands move when balance.md says
## so, and these must not move with them.

const TANK := preload("res://game/tank/tank.tscn")
const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## An open lane on the west side of the arena, clear of obstacles (test_tank_drive.gd uses the same one).
const LANE_X := -100.0

## A vehicle with no arena under it and no physics frame ever stepped: these are rule tests. It goes in the tree only
## because `global_position` is meaningless outside one. The stats a spawned Tank reads from its unit are set by hand.
func _tank(unit_id := "tank", team := 0) -> Tank:
	var tank: Tank = add_to_tree(TANK.instantiate())
	tank.unit_id = unit_id
	tank.team = team
	tank.set_weapon(String(Units.PROFILES[unit_id]["weapon"]))
	tank.sight_radius = float(Units.stat(unit_id, "sight_radius"))
	return tank


## Every test runs on a fresh case but the switches it moves are STATIC: put them back or the next file inherits them.
func teardown() -> void:
	Engagement.acquisition_enabled = true
	Units.tuning.clear()
	Weapons.tuning.clear()
	super.teardown()


# ---- Gate 3: fire discipline ----------------------------------------------------------

func test_every_direct_fire_weapon_has_a_band_shorter_than_its_reach() -> void:
	# This is the whole complaint in one assertion. Round 5 shipped `effective_range` and left it equal to `range` on
	# every weapon, so there was never a distance at which a shot was legal but bad.
	var checked := 0
	for id: String in Weapons.PROFILES:
		var weapon: Dictionary = Weapons.PROFILES[id]
		if not weapon.has("effective_range"):
			continue  # cones and arcs are disciplined by their own reach or by needing a spotter
		checked += 1
		assert_true(Engagement.effective_range(weapon) < float(weapon["range"]),
				"%s: effective %s must be shorter than its reach %s" % [id, weapon["effective_range"], weapon["range"]])
	assert_true(checked >= 8, "expected the direct-fire weapons to be checked, saw %d" % checked)


func test_a_crew_holds_its_fire_until_it_is_inside_the_band() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var band := Engagement.effective_range(tank.weapon)
	var lay := Engagement.Lay.new()
	# Long enough for any acquisition: the only thing under test here is range.
	assert_true(not lay.engage(tank, contact, band + 10.0, 10.0, false),
			"a shot from outside the band is held even with the contact long since acquired")
	assert_true(lay.engage(tank, contact, band - 1.0, 10.0, false), "inside the band the gun speaks")


func test_an_ordered_long_shot_overrides_the_crews_judgement_about_range() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var reach := float(tank.weapon["range"])
	var lay := Engagement.Lay.new()
	assert_true(not lay.engage(tank, contact, reach - 1.0, 10.0, false), "unordered, that range is held")
	assert_true(Engagement.Lay.new().engage(tank, contact, reach - 1.0, 10.0, true),
			"a commander who has decided a long shot is worth the round has taken the decision")


func test_a_crew_being_shot_at_may_answer_at_any_range_it_can_reach() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var reach := float(tank.weapon["range"])
	var lay := Engagement.Lay.new()
	assert_true(not lay.engage(tank, contact, reach - 1.0, 10.0, false), "calm, it holds")
	tank.suppression = Engagement.RETURN_FIRE_SUPPRESSION
	assert_true(Engagement.Lay.new().engage(tank, contact, reach - 1.0, 10.0, false),
			"under fire, a crew is not required to sit and take it")


func test_the_gun_does_not_stutter_at_the_edge_of_the_band() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var band := Engagement.effective_range(tank.weapon)
	var lay := Engagement.Lay.new()
	assert_true(lay.engage(tank, contact, band - 0.5, 10.0, false), "opens fire inside the band")
	assert_true(lay.engage(tank, contact, band + 1.0, 0.1, false),
			"a target drifting a metre out does not switch the gun off")
	assert_true(not lay.engage(tank, contact, band * Engagement.RELEASE_FACTOR + 1.0, 0.1, false),
			"far enough out, the engagement is broken off")


# ---- Gate 2: acquisition ---------------------------------------------------------------

func test_a_contact_must_be_held_before_the_first_round() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var lay := Engagement.Lay.new()
	var close := 10.0
	var needed := Engagement.acquire_seconds(tank, null, close)
	assert_true(needed > 0.0, "acquisition costs time")
	assert_true(not lay.engage(tank, contact, close, needed * 0.5, false), "half the lay is not enough")
	assert_true(lay.engage(tank, contact, close, needed * 0.6, false), "the rest of it is")


func test_a_far_contact_takes_longer_to_resolve_than_a_near_one() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	assert_true(Engagement.acquire_seconds(tank, null, tank.sight_radius) > Engagement.acquire_seconds(tank, null, 5.0),
			"a contact at the limit of vision is not a target as fast as one at arm's length")


func test_a_suppressed_crew_is_slower_onto_a_target() -> void:
	var calm := _tank()
	var pinned := _tank()
	pinned.suppression = 1.0
	assert_true(Engagement.acquire_seconds(pinned, null, 30.0) > Engagement.acquire_seconds(calm, null, 30.0),
			"heads down, nobody is calling the range")


func test_a_scout_resolves_a_contact_faster_than_the_line_units() -> void:
	# X6: `good_vs` claims must have a mechanic. "Scouts are spotters first" is now one of them.
	var scout := _tank("scout")
	var tank := _tank("tank")
	assert_eq(Units.role_of("scout"), "scout", "this test rests on the scout's role")
	assert_true(Engagement.acquire_seconds(scout, null, 30.0) < Engagement.acquire_seconds(tank, null, 30.0),
			"finding things is the scout's job")


func test_swinging_onto_a_new_contact_costs_the_lay() -> void:
	var first := _tank("tank", 1)
	var second := _tank("tank", 1)
	var tank := _tank()
	var lay := Engagement.Lay.new()
	assert_true(lay.engage(tank, first, 10.0, 10.0, false), "acquired and engaging the first contact")
	assert_true(not lay.engage(tank, second, 10.0, 0.01, false), "a new contact is not a target yet")


func test_a_contact_that_ducks_behind_cover_is_not_found_from_scratch() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var lay := Engagement.Lay.new()
	var needed := Engagement.acquire_seconds(tank, null, 10.0)
	lay.engage(tank, contact, 10.0, needed, false)
	lay.lose(needed * 0.5)  # out of sight for half the time it took to find him
	assert_true(lay.progress > 0.0, "the lay bleeds off, it is not wiped")
	assert_true(lay.engage(tank, contact, 10.0, needed * 0.5, false), "he reappears and the gunner is back on him")


# ---- Gate 1: sight ---------------------------------------------------------------------

func test_a_gun_may_not_reach_past_the_eyes_that_aim_it() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	var tank := _tank()
	var enemy := _tank("tank", 1)
	tank.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, tank.sight_radius + 5.0)
	var nobody := Callable()
	assert_true(not Engagement.is_seen(tank, enemy, nobody), "beyond its own sight, a crew has nothing to shoot at")
	enemy.global_position = Vector3(0.0, 0.0, tank.sight_radius - 5.0)
	assert_true(Engagement.is_seen(tank, enemy, nobody), "inside it, the contact is there")


func test_a_spotter_hands_over_a_contact_the_crew_cannot_see_itself() -> void:
	var tank := _tank()
	var enemy := _tank("tank", 1)
	tank.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.0, 0.0, tank.sight_radius + 20.0)
	var team_sees := func(_other: Tank) -> bool: return true
	assert_true(Engagement.is_seen(tank, enemy, team_sees),
			"shared intel is what makes a scout's eyes worth a tank's gun")
	var team_blind := func(_other: Tank) -> bool: return false
	assert_true(not Engagement.is_seen(tank, enemy, team_blind), "and what a blind team cannot hand over")


# ---- The control the measurements use --------------------------------------------------

func test_no_acquisition_restores_the_old_world_for_a_control_run() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	Engagement.acquisition_enabled = false
	var tank := _tank()
	var enemy := _tank("tank", 1)
	enemy.global_position = Vector3(0.0, 0.0, 1000.0)
	assert_true(Engagement.is_seen(tank, enemy, Callable()), "gate 1 is off")
	var band := Engagement.effective_range(tank.weapon)
	assert_true(Engagement.Lay.new().engage(tank, contact, band - 1.0, 0.0, false),
			"gate 2 is off: no lay needed at all")
	assert_true(not Engagement.Lay.new().engage(tank, contact, band + 10.0, 0.0, false),
			"gate 3 is NOT off — discipline has its own control (tuning effective_range up to range)")


func test_tuning_a_band_back_to_its_reach_is_the_discipline_control() -> void:
	var tank := _tank()
	var reach := float(Weapons.PROFILES[tank.weapon_id]["range"])
	assert_eq(Units.apply_tuning("%s.effective_range=%d" % [tank.weapon_id, int(reach)]), "",
			"the control the engagement series runs must be expressible as a --tune")
	assert_near(Engagement.effective_range(Weapons.profile(tank.weapon_id)), reach, 0.001,
			"the band is back at the weapon's reach")


# ---- The envelope reaching the trigger -------------------------------------------------
# Everything above tests the RULE. These two test the WIRE: a real arena, a real match, a real OrderController
# producing a real TankCommand. They are the tests that fail if the seam into the order controller is dropped — by a
# bad merge, by nav's split of that file into movement and gunnery, or by an edit that silently matched nothing
# (orchestration.md lesson 27). Without them, `game/combat/engagement.gd` could be perfect and never consulted.


func _match() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


## A shooter under standing orders and a silent enemy it can see. The enemy has no controller, so nothing ever fires
## back and nothing suppresses the shooter — which keeps the return-fire exception out of these measurements.
func _firing_line(weapon_order: Dictionary, enemy_z: float) -> Array:
	var game_match := _match()
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN)
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST)
	shooter.global_position = Vector3(LANE_X, 0.0, 30.0)
	enemy.global_position = Vector3(LANE_X, 0.0, enemy_z)
	var orders := OrderController.new()
	orders.tank = shooter
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	orders.set_orders({"type": "stop"}, weapon_order)
	return [game_match, enemy]


func test_fire_discipline_reaches_the_trigger() -> void:
	var weapon := Weapons.profile("cannon")
	var band := Engagement.effective_range(weapon)
	assert_true(float(weapon["range"]) > band + 15.0, "this test needs a real gap between the band and the reach")
	# 55 m: well inside a 70 m cannon's reach and inside the tank's 62 m sight, well outside its 45 m band.
	var line := await _held_then_closed(55.0, band)
	assert_eq(line[0], 0, "in range, in sight, and still holding: the fight does not start at first contact")
	assert_true(line[1] > 0, "and it does start once the shooter is inside its effective band")


## Hold the enemy at `far_z` for four seconds, then bring it inside `band` and give it three more.
## Returns [shots while far, shots after closing].
func _held_then_closed(far_distance: float, band: float) -> Array:
	var setup := _firing_line({"type": "fire_at_will"}, 30.0 - far_distance)
	var game_match: Match = setup[0]
	var enemy: Tank = setup[1]
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	var far_shots: int = game_match.stats["shots"][Match.Team.GREEN]
	enemy.global_position = Vector3(LANE_X, 0.0, 30.0 - (band - 10.0))
	enemy.reset_physics_interpolation()  # lesson 30(c): a teleport the drawn position must not smear
	await wait_physics_frames(SimClock.TICK_RATE * 3)
	return [far_shots, int(game_match.stats["shots"][Match.Team.GREEN]) - far_shots]


func test_a_designated_target_beyond_the_crews_sight_is_still_not_shot_at() -> void:
	# A `target` order overrides fire DISCIPLINE (gate 3) — it must not override SIGHT (gate 1). A commander may tell a
	# crew to take a long shot; they cannot tell it to shoot at something nobody can see.
	var sight := float(Units.stat("tank", "sight_radius"))
	var reach := float(Weapons.profile("cannon")["range"])
	assert_true(reach > sight + 4.0, "this test needs the cannon to out-reach the tank's own eyes")
	var setup := _firing_line({"type": "target", "name": "Enemy"}, 30.0 - (sight + 4.0))
	var game_match: Match = setup[0]
	var enemy: Tank = setup[1]
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 0,
			"a gun may not reach past the eyes that aim it, even when a commander names the target")
	enemy.global_position = Vector3(LANE_X, 0.0, 30.0 - 40.0)
	enemy.reset_physics_interpolation()
	await wait_physics_frames(SimClock.TICK_RATE * 3)
	assert_true(game_match.stats["shots"][Match.Team.GREEN] > 0, "inside its own sight, the designated target is engaged")


func test_a_brains_own_target_order_does_not_buy_it_a_long_shot() -> void:
	var contact := _tank("tank", 1)  # stationary: no crossing penalty, so this tests range and time alone
	# The trap this contract nearly fell into. TankBrain's ENGAGE state issues {"type": "target", "fallback": true}
	# EVERY TICK, so reading "target" as "a commander ordered this" would have exempted every CPU unit in the game and
	# left N5 doing nothing at all — while all fifteen rule tests above went on passing. The override has to be asked
	# for by name. This is the same shape of mistake as orchestration.md lesson 23 (a feature behind a flag the default
	# path never passes), inverted: an exception the default path always passes.
	var brains_order := {"type": "target", "name": "Enemy", "fallback": true}
	var setup := _firing_line(brains_order, 30.0 - 55.0)  # 55 m: seen, in reach, outside the 45 m band
	var game_match: Match = setup[0]
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 0,
			"the brain designating a contact is not an order to take a long shot")

	var ordered := _firing_line({"type": "target", "name": "Enemy", "long_shot": true}, 30.0 - 55.0)
	var ordered_match: Match = ordered[0]
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_true(ordered_match.stats["shots"][Match.Team.GREEN] > 0,
			"and asking for the long shot by name is what buys it")


# ---- The number other streams build on ------------------------------------------------

func test_the_covering_range_is_derived_from_the_rosters_not_a_constant() -> void:
	# arena's exposure() hard-coded a 110 m watcher range — a weapon-range assumption wearing a sightline's clothes.
	# This is the replacement, and the point of it is that it MOVES when the bands move, so it cannot go stale.
	var covering := Engagement.covering_range()
	assert_true(covering > 0.0, "every roster has direct-fire units, so there is an answer")
	var reaches: Array[float] = []
	for unit_id: String in Units.PROFILES:
		var weapon := Weapons.profile(String(Units.PROFILES[unit_id].get("weapon", "")))
		if weapon.has("effective_range"):
			reaches.append(minf(Engagement.effective_range(weapon), float(Units.stat(unit_id, "sight_radius", 0.0))))
	reaches.sort()
	assert_true(covering >= reaches[0] and covering <= reaches[-1],
			"it sits inside the spread it summarises (%.0f in %.0f..%.0f)" % [covering, reaches[0], reaches[-1]])
	assert_true(covering < 110.0,
			"and it is well under the 110 m arena was assuming (%.0f)" % covering)


func test_the_covering_range_follows_the_bands_when_they_move() -> void:
	var before := Engagement.covering_range()
	# Halve every band the line units carry; the answer must come down with them.
	assert_eq(Units.apply_tuning("cannon.effective_range=22,autocannon.effective_range=22,pulse_repeater.effective_range=22"),
			"", "tuning the line units' bands")
	assert_true(Engagement.covering_range() < before,
			"a metric derived from the data tracks the data (%.0f then %.0f)" % [before, Engagement.covering_range()])


# ---- X6: the mechanic behind `scout > lancer` ------------------------------------------
# The roster has claimed `lancer.weak_vs = ["scout"]` since round 2 with nothing behind it. A contact CROSSING the
# gunner's field is harder to lay on than one driving straight at him, which is pure geometry and pays for exactly the
# behaviour the scout is supposed to show.

func _moving(unit_id: String, at: Vector3, velocity: Vector3) -> Tank:
	var tank := _tank(unit_id, 1)
	tank.global_position = at
	tank.estimated_velocity = velocity
	return tank


func test_a_contact_crossing_the_sight_line_is_harder_to_lay_on_than_one_closing() -> void:
	var gunner := _tank("lancer")
	gunner.global_position = Vector3.ZERO
	var at := Vector3(0.0, 0.0, 60.0)
	var speed := float(Units.stat("scout", "max_forward_speed"))
	var closing := _moving("scout", at, Vector3(0.0, 0.0, -speed))  # straight down the sight line
	var crossing := _moving("scout", at, Vector3(speed, 0.0, 0.0))  # square across it
	assert_near(Engagement.crossing_rate(gunner, closing, 60.0), 0.0, 0.0001,
			"driving straight at the gun crosses nothing")
	assert_near(Engagement.crossing_rate(gunner, crossing, 60.0), speed / 60.0, 0.0001,
			"driving across it crosses at speed over range")
	assert_true(Engagement.acquire_seconds(gunner, crossing, 60.0) > Engagement.acquire_seconds(gunner, closing, 60.0) * 1.2,
			"so the crossing contact costs the gunner meaningfully more time")


func test_the_same_speed_crosses_faster_up_close_than_far_away() -> void:
	var gunner := _tank("lancer")
	gunner.global_position = Vector3.ZERO
	var speed := 10.0
	var near := _moving("scout", Vector3(0.0, 0.0, 20.0), Vector3(speed, 0.0, 0.0))
	var far := _moving("scout", Vector3(0.0, 0.0, 80.0), Vector3(speed, 0.0, 0.0))
	assert_true(Engagement.crossing_rate(gunner, near, 20.0) > Engagement.crossing_rate(gunner, far, 80.0),
			"angular rate is speed over range, so the same scout is a harder track up close")


func test_charging_straight_down_the_sight_line_buys_a_scout_nothing() -> void:
	# The rule has to pay for the RIGHT behaviour, or it is just a buff. A scout that drives at the gun gets no
	# protection at all; only the attack run does.
	var lancer := _tank("lancer")
	lancer.global_position = Vector3.ZERO
	var speed := float(Units.stat("scout", "max_forward_speed"))
	var charging := _moving("scout", Vector3(0.0, 0.0, 70.0), Vector3(0.0, 0.0, -speed))
	var still := _moving("scout", Vector3(0.0, 0.0, 70.0), Vector3.ZERO)
	assert_near(Engagement.acquire_seconds(lancer, charging, 70.0), Engagement.acquire_seconds(lancer, still, 70.0),
			0.0001, "a head-on charge is no harder to lay on than a parked hull")


func test_the_crossing_penalty_is_capped_so_a_contact_is_never_unlayable() -> void:
	var gunner := _tank("tank")
	gunner.global_position = Vector3.ZERO
	var blurring := _moving("scout", Vector3(0.0, 0.0, 6.0), Vector3(400.0, 0.0, 0.0))  # absurd angular rate
	var still := _moving("scout", Vector3(0.0, 0.0, 6.0), Vector3.ZERO)
	var worst := 1.0 + Engagement.CROSSING_ACQUIRE_PENALTY * Engagement.CROSSING_ACQUIRE_MAX
	assert_near(Engagement.acquire_seconds(gunner, blurring, 6.0),
			Engagement.acquire_seconds(gunner, still, 6.0) * worst, 0.0001,
			"the penalty saturates rather than running away")
