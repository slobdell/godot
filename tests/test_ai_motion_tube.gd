extends TestCase
## Round 9, A1's BRAIN half: a state-error tube instead of a fixed re-plan cadence, and the latency guarantee that
## has to hold before the switch can ever be flipped.
##
## `TankBrain._hold_motion_plan` decides whether last tick's `CombatMotion` plan still stands. The shipped rule is a
## CADENCE — same key, younger than `MOTION_REPLAN_TICKS` — which is a true argument about *time* that says nothing
## about whether anything moved. The tube (`TUBE_ENABLED`, **off by default**) is the same argument about *state*: hold
## the plan while neither the unit nor its target has left the neighbourhood it was computed in.
##
## **The default is off on evidence, not caution.** nav measured its own half of A1 failing its falsifier in a fight
## (the route cadence skipped 2144 of 2222 firings and total re-plans moved +0.9%), and then attributed **968 of 2059**
## re-plans to `goal_slid` — a goal nav was already regulating. Until that fix is re-measured, the share of re-planning
## reachable from this side is unknown, and a mechanism whose falsifier cannot be evaluated does not ship on.
##
## So what these tests are for is the part that must be true *whatever* the measurement says: **the tube may only ever
## hold a plan LONGER than the cadence would, never shorter, and it may never delay the response to something new.**
## A tube that swallowed a new contact or a new order would be the dwell timer this project has already measured and
## rejected once (round 8's acquire floor: switches 19.5 vs 18.1 and reversals 0.67 vs 0.30, worse on every seed).

const TICK := 1


## A bare brain, added to the tree so TestCase frees it (TankBrain extends OrderController extends Node, and a Node
## made and dropped is "N ObjectDB instances leaked" — trip-up 75's shape).
func _brain(tube: bool) -> TankBrain:
	TankBrain.TUBE_ENABLED = tube
	var brain := TankBrain.new()
	brain.name = "TubeBrain_%d" % _made
	_made += 1
	add_to_tree(brain)
	return brain


var _made := 0


func _plan(brain: TankBrain, key: String, tick: int, at: Vector3, target_at: Vector3) -> void:
	brain._motion_cache = {"tick": tick, "key": key, "why": "test", "order": {"type": "stop"},
			"at": at, "target_at": target_at}


func _contact(at: Vector3) -> Dictionary:
	return {"name": "Rust_1", "position": at}


func test_the_default_is_the_cadence_and_nothing_else() -> void:
	# With the switch off, the rule must be exactly what shipped: same key, younger than MOTION_REPLAN_TICKS.
	var brain := _brain(false)
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	assert_true(brain._hold_motion_plan("k", TankBrain.MOTION_REPLAN_TICKS - 1, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"inside the cadence the plan stands")
	assert_true(not brain._hold_motion_plan("k", TankBrain.MOTION_REPLAN_TICKS, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"at the cadence it is re-taken")
	# And state does not enter into it: a target that has not moved does not buy the default rule any extra time.
	assert_true(not brain._hold_motion_plan("k", TankBrain.MOTION_REPLAN_TICKS + 30, Vector3.ZERO,
			_contact(Vector3(40, 0, 0))), "the cadence is about time, and only time")


func test_the_tube_only_ever_holds_a_plan_longer_never_shorter() -> void:
	# The property that makes the switch safe to flip: inside the cadence the tube cannot cause an extra re-decide,
	# whatever the state has done. If it could, turning it on would make the brain think MORE, which is the opposite
	# of the row's purpose and the kind of regression a flag hides.
	var brain := _brain(true)
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	var moved_a_lot := Vector3(40 + TankBrain.TUBE_TARGET_M * 3.0, 0, 0)
	assert_true(brain._hold_motion_plan("k", TankBrain.MOTION_REPLAN_TICKS - 1, Vector3.ZERO, _contact(moved_a_lot)),
			"inside the cadence the plan stands even when the target has left the tube")


func test_over_a_whole_drive_the_tube_never_re_decides_more_and_does_hold_something() -> void:
	# The range version of the property above, plus nav's non-vacuity guard. Driving the same unchanged world past the
	# cadence many times over, the tube must take NO MORE decisions than the cadence would -- and it must take FEWER
	# at least once, or "never more" is satisfied by a tube that never holds anything at all.
	#
	# nav wrote exactly this assertion for A1's nav half on my suggestion and it failed immediately: its drift
	# condition was independent of the cadence being due, so the tube could re-plan MORE in the regime where a unit
	# had no route yet -- invisible, because the switch is off by default. That is the regression a flag hides, and
	# a single-point assertion like the one above would not have caught it in my layer either.
	var ticks := TankBrain.TUBE_MAX_TICKS + TankBrain.MOTION_REPLAN_TICKS * 3
	var counts := {}
	for tube: bool in [false, true]:
		var brain := _brain(tube)
		var decisions := 0
		var skips := 0
		var last_plan := -1
		for tick in ticks:
			if last_plan >= 0 and brain._hold_motion_plan("k", tick, Vector3.ZERO, _contact(Vector3(40, 0, 0))):
				skips += 1
				continue
			decisions += 1
			last_plan = tick
			_plan(brain, "k", tick, Vector3.ZERO, Vector3(40, 0, 0))
		counts[tube] = {"decisions": decisions, "skips": skips}
	print("MEASURE brain_tube over %d ticks, world unchanged: cadence %s, tube %s" % [ticks, counts[false], counts[true]])
	assert_true(int(counts[true]["decisions"]) <= int(counts[false]["decisions"]),
			"the tube never takes more decisions than the cadence it replaces (%s vs %s)" \
			% [counts[true]["decisions"], counts[false]["decisions"]])
	assert_true(int(counts[true]["decisions"]) < int(counts[false]["decisions"]),
			"and it takes fewer at least once, so `never more` is not satisfied vacuously (%s vs %s)" \
			% [counts[true]["decisions"], counts[false]["decisions"]])
	assert_true(int(counts[true]["skips"]) > int(counts[false]["skips"]),
			"which shows up as it holding plans the cadence would have dropped (%s vs %s skips)" \
			% [counts[true]["skips"], counts[false]["skips"]])


func test_the_tube_holds_a_plan_while_nothing_has_moved_and_drops_it_when_something_has() -> void:
	var brain := _brain(true)
	var past_cadence := TankBrain.MOTION_REPLAN_TICKS + 2
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	assert_true(brain._hold_motion_plan("k", past_cadence, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"past the cadence, a plan whose world has not moved is still the right plan")
	# The target leaves the tube.
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	var target_out := Vector3(40 + TankBrain.TUBE_TARGET_M + 1.0, 0, 0)
	assert_true(not brain._hold_motion_plan("k", past_cadence, Vector3.ZERO, _contact(target_out)),
			"a target that has left the tube re-takes the decision")
	# The unit itself leaves the tube.
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	var self_out := Vector3(TankBrain.TUBE_SELF_M + 1.0, 0, 0)
	assert_true(not brain._hold_motion_plan("k", past_cadence, self_out, _contact(Vector3(40, 0, 0))),
			"and so does a unit that has driven out of it")


func test_a_new_contact_or_a_jink_re_decides_at_once_whatever_the_tube_says() -> void:
	# THE LATENCY GUARANTEE, and it is the one that must hold before the switch is flipped. Everything a brain must
	# react to instantly is in the cache KEY -- the target's name, the strafe side, the run phase, and the count of
	# rounds on their way -- and a key change refuses the plan before the tube is consulted at all. So the tube can
	# lengthen the life of a plan for an unchanged world and can never delay a reaction to a changed one.
	var brain := _brain(true)
	_plan(brain, "Rust_1|1|hunt|0", 0, Vector3.ZERO, Vector3(40, 0, 0))
	var here := Vector3.ZERO
	var target := _contact(Vector3(40, 0, 0))
	assert_true(not brain._hold_motion_plan("Rust_2|1|hunt|0", 1, here, target), "a new target re-decides at once")
	assert_true(not brain._hold_motion_plan("Rust_1|-1|hunt|0", 1, here, target), "a jink re-decides at once")
	assert_true(not brain._hold_motion_plan("Rust_1|1|run|0", 1, here, target), "a run phase flip re-decides at once")
	assert_true(not brain._hold_motion_plan("Rust_1|1|hunt|1", 1, here, target),
			"and a round on its way re-decides at once, which is the reflex the tube must never blunt")


func test_the_tube_has_a_ceiling_so_a_held_plan_cannot_become_a_stuck_state() -> void:
	# A tube with no ceiling is a stuck state (lesson 17's shape: a rule above a behaviour that can cancel it
	# forever). Past TUBE_MAX_TICKS the decision is re-taken however still the world looks.
	var brain := _brain(true)
	_plan(brain, "k", 0, Vector3.ZERO, Vector3(40, 0, 0))
	assert_true(brain._hold_motion_plan("k", TankBrain.TUBE_MAX_TICKS - 1, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"just inside the ceiling an unchanged world still holds its plan")
	assert_true(not brain._hold_motion_plan("k", TankBrain.TUBE_MAX_TICKS, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"at the ceiling it is re-taken whatever the state says")


func test_the_counters_count_what_they_claim() -> void:
	# `redecide_counts()` is how the tube's value becomes a measured before/after rather than an argument, so it has
	# to start honest: no plan means no skip.
	var brain := _brain(false)
	assert_eq(brain.redecide_counts(), {"redecides": 0, "skips": 0}, "a fresh brain has decided nothing")
	assert_true(not brain._hold_motion_plan("k", 0, Vector3.ZERO, _contact(Vector3(40, 0, 0))),
			"with no cached plan there is nothing to hold")
	TankBrain.TUBE_ENABLED = false
