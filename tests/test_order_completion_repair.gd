extends TestCase
## Round 11, the orchestrator's integration fix between nav's R2 and the brain's order bookkeeping.
##
## nav built the goal repair the lead asked for — *"a unit's target position ends up inside of a building … some of
## them still just look dumb getting stuck behind a wall"* — and then found it could not be switched on:
## `Movement` re-grounds an unreachable goal once with the hull's envelope and drives to the REPAIRED point, while
## `TankBrain._update_order_progress` judges completion against `order["goal"]`, the ORIGINAL. So the hull arrives,
## `Movement.state` reads `arrived`, and the order never finishes. nav's measurement (builder0, `nav-orders`,
## `e62383ad`): a scout repaired 3.5 m sat "arrived" under an order that hung. They shipped the repair OPT-IN and
## asked for this one line rather than editing a file they did not own.
##
## **Why the fix is not "widen the arrival radius by `repaired_m`".** That is the tempting version and it is the
## round-6 fudge coming back in a new coat: until round 6 a stalled move completed from up to 12 m away, which is
## what made a jammed horde look like it had decided to stop (`tank_brain.gd` header). `REPAIR_MAX_M` is 12 m, so
## inflating the radius by the repair distance would let any move complete anywhere in a 12 m disc of its goal.
##
## The rule instead is narrow: **an order completes at a repaired goal only when the mover itself reports it is
## standing at the point IT was sent to.** `Movement` owns "did this hull arrive"; the brain owns "is this order
## done". With nothing repaired the distance test is untouched, and an unreachable goal still reports
## `blocked`/`no_path` and keeps trying.
##
## These tests drive the REAL mover (an `OrderController` on the Terminus, nav's own fixture geometry) and then ask
## the brain's rule about the state it produced. The brain's own processing is off, so `order` is exactly what the
## test set and nothing polls it away — the question here is the completion rule, not the order feed.

const MATCH := preload("res://game/match/match.tscn")


## A goal 3 m inside the (40, 0) Terminus block's north face is one `Movement` repairs rather than refuses
## (`REPAIR_MAX_M` 12 m) — nav's own fixture case. The mover arrives at the repaired point; the ORDER must finish.
func test_an_order_whose_goal_was_repaired_completes_when_the_hull_gets_there() -> void:
	var result := await _run(Vector3(40.0, 0.0, 17.0), "arrived")
	assert_true(result["repaired_m"] >= 3.0,
			"setup: the goal really was repaired, so this test exercises the repair (%s)" % result)
	assert_eq(result["phase"], "arrived", "setup: the mover arrived at the point it was sent to (%s)" % result)
	assert_true(result["finished"],
			"the ORDER completes when the mover arrives at the goal it repaired (%s)" % result)


## The other half, and the one that keeps the fix honest: 20 m inside the block is beyond `REPAIR_MAX_M`, so nothing
## is repaired and completion is the distance test it has always been — the order stays open and says why.
func test_an_unrepaired_unreachable_order_still_does_not_complete() -> void:
	var result := await _run(Vector3(40.0, 0.0, 0.0), "blocked")
	assert_eq(result["repaired_m"], 0.0, "setup: 20 m inside a block is beyond REPAIR_MAX_M (%s)" % result)
	assert_eq(result["phase"], "blocked", "the mover says blocked (%s)" % result)
	assert_true(not result["finished"],
			"and the order stays open: a unit that cannot arrive says so and keeps trying (%s)" % result)


## Drive a tank from the Terminus ring road at `goal` inside a block until the mover reaches `until` (or blocks),
## then ask the brain's completion rule about that state. Returns the mover's reading and whether the order finished.
func _run(goal: Vector3, until: String) -> Dictionary:
	Movement.reset_route_arms()
	var saved := Movement._off
	Movement._off = PackedStringArray(["repair"])  # the repair is opt-in on the tree; on for these tests
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN)
	tank.global_position = Vector3(goal.x, 0.0, 31.0)
	tank.rotation.y = 0.0
	tank.reset_physics_interpolation()
	var driver := OrderController.new()
	driver.tank = tank
	driver.tanks_root = game_match.tanks
	add_to_tree(driver)
	driver.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})

	# The brain under test: in the tree so it is freed, but not processing, so nothing polls `order` away.
	var brain := TankBrain.new()
	brain.name = "RuleBrain"
	brain.tank = tank
	brain.tanks_root = game_match.tanks
	add_to_tree(brain)
	brain.set_process(false)
	brain.set_physics_process(false)
	brain.order = {"verb": "move", "goal": Vector3(goal.x, 0.0, goal.z)}
	brain._order_key = "move:test"  # _finish_order refuses an order with no key

	var reading := {}
	for _frame in SimClock.TICK_RATE * 20:
		await tree.physics_frame
		reading = Movement.state(tank)
		brain._update_order_progress()
		if String(reading.get("phase", "")) == until:
			# Settle: let the rule see this state for a few more ticks, so "did not finish" is an answer, not a race.
			for _settle in 10:
				await tree.physics_frame
				brain._update_order_progress()
			break
	Movement._off = saved
	return {"phase": String(reading.get("phase", "")), "repaired_m": float(reading.get("repaired_m", 0.0)),
			"finished": brain._finished_key != ""}
