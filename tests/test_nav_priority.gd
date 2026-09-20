extends TestCase
## Round 9 (nav, A7 — catalogue row A7, Antonelli/Arrichiello/Chiaverini 2008): null-space priority projection replaces
## the additive score in `CombatMotion.choose`. The pre-registered falsifier is *zero ticks where a unit with an
## unreached goal holds |v| < 0.2 m/s with no blocking geometry*, and round 8 found the clearest instance of exactly
## that: a standoff HOLD returns `index -1` BEFORE the ring is scored, so the leash, the commitment bonus and every
## other term are never consulted. A unit shooting from 40 m outside the slot it was given stands there.
##
## The priority table these tests encode is in `_agents/navigation.md` ("A7's priority table"), reviewed by combat and
## feel before the code was written. The two that matter here: SURVIVAL (level 1) is strictly dominant, and FORMATION
## (level 4) still gets to choose among everything the WEAPON band (level 2) leaves free — which is the whole
## tangential component, and, inside the band, the radial slack too.

const TARGET_AT := Vector3(0, 0, -35)


## A7 is opt-in (`--nav-off=a7` turns it ON — see `CombatMotion.a7_on()`), so every test here pins the arm it means
## rather than inheriting whatever the default happens to be. Round 7 lost an A/B to exactly that (two byte-identical
## arms, because a static was read before the switch list was populated).
static func _with_a7(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["a7"]) if on else PackedStringArray()
	Movement._off_parsed = true
	return was


static func _request(extra: Dictionary = {}) -> Dictionary:
	var base := {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 10.0, "reverse_speed": 5.0,
			"style": "standoff", "target": {"position": TARGET_AT, "forward": Vector3.BACK, "velocity": Vector3.ZERO},
			"band": [15.0, 40.0], "side": 1.0, "wheels": false, "turn_rate_deg": 90.0, "acceleration": 8.0,
			"velocity": Vector3.ZERO, "limit": 200.0}
	base.merge(extra, true)
	return base


## The control for the two below: with nothing else asking for anything, a gun inside its band SHOULD stop and shoot.
## Round 7's shoot-and-scoot is lead-approved behaviour (closest approach 3.0 -> 27.7 m, shots 29 -> 211) and A7 must
## not quietly cost it. If this test ever goes red, A7 has broken the standoff, not fixed the stall.
func test_a_gun_inside_its_band_with_nothing_else_to_do_still_holds_and_shoots() -> void:
	var was := _with_a7(true)
	var result := CombatMotion.choose(_request())
	Movement._off = was
	assert_true(result.get("hold", false), "inside the band, unleashed, nothing incoming: hold and shoot (%s)" % result)


## THE FALSIFIER, as a unit test. Same gun, same band, but its element slot is 40 m away and its leash radius is 4 m:
## it is holding a firing position it was never told to hold, 36 m outside its slot. Today `standoff_holds` returns
## before the leash is ever read, so the unit stands still with an unreached goal and no blocking geometry.
func test_a_gun_held_outside_its_slot_slides_back_into_it_instead_of_standing_still() -> void:
	var was := _with_a7(true)
	var slot := Vector3(40, 0, 0)
	var result := CombatMotion.choose(_request({"leash": {"center": slot, "radius": 4.0}}))
	Movement._off = was
	assert_true(not result.get("hold", false), "a slot 36 m away is a goal, and standing still is not an answer to it (%s)" % result)
	assert_true(not result.is_empty(), "and it is not 'every direction blocked' either (%s)" % result)
	var point: Vector3 = result["point"]
	assert_true(point.x > 0.0, "it moves toward its slot (steer point x %.1f, slot at x %.1f)" % [point.x, slot.x])


## The same cancellation from the other side: the band pulls OUT (the gun is 10 m from a target it wants to fight at
## 30-40 m) while the slot pulls IN (the slot is past the target). Exactly opposing tasks. Under an additive blend
## opposing terms can sum to nothing; under priority projection the band owns the RADIAL component and the slot is
## answered in what that leaves, so the unit always has somewhere to be.
func test_opposing_band_and_slot_pulls_still_produce_a_velocity() -> void:
	var was := _with_a7(true)
	var near := {"target": {"position": Vector3(0, 0, -10), "forward": Vector3.BACK, "velocity": Vector3.ZERO},
			"band": [30.0, 40.0], "leash": {"center": Vector3(0, 0, -40), "radius": 2.0}}
	var result := CombatMotion.choose(_request(near))
	Movement._off = was
	assert_true(not result.is_empty(), "opposing goals do not cancel to nothing (%s)" % result)
	assert_true(not result.get("hold", false), "and they do not cancel to a hold either (%s)" % result)
	assert_true(Vector2(result["point"].x, result["point"].z).length() > 0.2,
			"the steer point is somewhere else than here (%s)" % result)


## Regression, NOT equivalence (the brief's word): with only SURVIVAL active — one round on its way, no leash, no
## threats, no friends, a band every candidate satisfies — A7 and the old additive blend should pick the same way out.
## A7 is meant to change what happens when levels DISAGREE; when only one level has anything to say there is nothing
## to re-order, and a different answer here would mean A7 moved something it was not supposed to touch.
func test_with_only_survival_active_a7_answers_where_the_old_blend_did() -> void:
	var incoming := [{"position": Vector3(14, 0, -14), "velocity": Vector3(-20, 0, 20), "eta_ticks": SimClock.TICK_RATE / 2}]
	var request := _request({"style": "strafe", "band": [0.0, 400.0], "incoming": incoming})
	var was := _with_a7(false)
	var old_blend := CombatMotion.choose(request)
	_with_a7(true)
	var projected := CombatMotion.choose(request)
	Movement._off = was
	assert_true(not (old_blend.is_empty() or projected.is_empty()), "both arms chose something (%s / %s)" % [old_blend, projected])
	var a := Vector2(old_blend["point"].x, old_blend["point"].z)
	var b := Vector2(projected["point"].x, projected["point"].z)
	assert_true(a.normalized().distance_to(b.normalized()) * float(request["speed"]) <= 0.1,
			"the same way out, within 0.1 m/s (old %s, a7 %s)" % [a, b])


## The arm counter, without which the A/B is not a comparison (lesson 147, and round 8's `gates aimed 0` in both arms).
func test_the_a7_arm_counter_moves_only_when_a7_is_on() -> void:
	var was := _with_a7(true)
	CombatMotion.reset_arms()
	CombatMotion.choose(_request({"leash": {"center": Vector3(40, 0, 0), "radius": 4.0}}))
	var on := CombatMotion.a7_projected
	_with_a7(false)
	CombatMotion.reset_arms()
	CombatMotion.choose(_request({"leash": {"center": Vector3(40, 0, 0), "radius": 4.0}}))
	var off := CombatMotion.a7_projected
	Movement._off = was
	assert_true(on > 0, "a plan under A7 records the levels it projected (%d)" % on)
	assert_eq(off, 0, "and the old blend records none, so the two arms are distinguishable")


## The same saturation trap as the leash, on the level that owns the radial component. `_band()` floors at zero 12 m
## below the band and 20 m above, so a unit far from its target would have EVERY candidate tied at the maximum band
## cost — the weapon level would rank nothing and the unit would have no pressure to close. A cost inside a level only
## ever competes with itself, so it has to stay monotone over the whole range it can see.
func test_a_gun_far_outside_its_band_still_closes_on_the_target() -> void:
	var was := _with_a7(true)
	var far := {"style": "strafe", "target": {"position": Vector3(0, 0, -90), "forward": Vector3.BACK, "velocity": Vector3.ZERO},
			"band": [15.0, 40.0]}
	var result := CombatMotion.choose(_request(far))
	Movement._off = was
	assert_true(not result.is_empty(), "it chooses something at 90 m (%s)" % result)
	assert_true(result["point"].z < -0.5, "and it is toward the target, not tied on a saturated band cost (%s)" % result)


## X6 (squad's request, the lead's named ask): gains are picked by faction, so "the same army with different gains"
## could not be set up — changing the faction changes the hulls, the weapons and the doctrine with it. A forced set
## makes the control law the only difference.
func test_gains_can_be_forced_so_an_identical_army_can_be_driven_two_ways() -> void:
	var was := ControlGains.forced
	ControlGains.forced = ""
	var condemned := ControlGains.for_loop("station", "")
	var law_by_faction := ControlGains.for_loop("station", "law")
	ControlGains.forced = "law"
	var condemned_forced := ControlGains.for_loop("station", "")
	ControlGains.forced = was
	assert_true(condemned["kp"] != law_by_faction["kp"], "the factions really do differ (%s vs %s)" % [condemned, law_by_faction])
	assert_eq(condemned_forced["kp"], law_by_faction["kp"], "a Condemned crew driven on the Law's gains")
	assert_eq(condemned_forced["kd"], law_by_faction["kd"], "including the damping that is the point of them")
