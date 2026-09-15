extends TestCase
## AI cost at scale (_agents/unit_ai.md §8): 50 brain tanks (5 squads of 5 per side) closing to fight in the
## real arena. Prints MEASURE ai_usec_per_tick (brains + orders, per physics tick) and fails far above the
## budget, so a big regression shows up in `make ai-scenarios` (`make ai-perf` runs just this). Timing on the
## shared dev machine swings ±30% with other worktrees' load: compare runs, don't trust one.

const PENDING := []
## The measured reality (2026-09-15) is ~9 ms at 50 units, down from 15 ms; the design target stays 1 ms
## (see unit_ai.md §8 for the plan to get there: think LOD, 30 Hz orders).
const BUDGET_USEC := 1000.0
## Fail only far above today's cost: timing on a shared machine is noisy.
const FAIL_USEC := 20000.0


func test_fifty_brains_stay_inside_the_cpu_budget() -> void:
	var s := AiScenario.create(self, 5)
	var squads: Array = []
	for i in 5:
		squads.append({"name": "S%d" % i, "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "tank"},
				{"unit": "tank"}, {"unit": "tank"}]})
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(s.game_match.load_doctrine(team, {"name": "Perf", "squads": squads}), "", "setup: 25 tanks load")
	# Spread each side along its base line so they don't start stacked on nine spawn slots.
	for tank: Tank in s.game_match.tanks_by_name().values():
		var index := int(String(tank.name).get_slice("_", 2)) - 1 + 5 * int(String(tank.name).get_slice("_", 1).trim_prefix("S"))
		var x := -96.0 + index * 8.0
		tank.global_position = Vector3(x if tank.team == Match.Team.GREEN else -x, 0, 70 if tank.team == Match.Team.GREEN else -70)
	await s.start()
	OrderController.profile_usec = 0
	OrderController.profiling = true
	var los_before := CoverMap.los_computed
	var queries_before := CoverMap.los_queries
	var ticks := 60 * 30
	var fighting_ticks := 0
	for tick in ticks:
		await s.step()
		if s.game_match.stats["first_shot_seconds"] >= 0.0:
			fighting_ticks += 1
	OrderController.profiling = false
	var per_tick := float(OrderController.profile_usec) / ticks
	var alive := s.game_match.alive_count(Match.Team.GREEN) + s.game_match.alive_count(Match.Team.RUST)
	print("MEASURE ai_usec_per_tick %.0f at 50 brains (budget %.0f); %d ticks fighting, %d alive at the end; LOS %d queries, %d computed" % [
			per_tick, BUDGET_USEC, fighting_ticks, alive, CoverMap.los_queries - queries_before, CoverMap.los_computed - los_before])
	assert_true(fighting_ticks > 60 * 5, "the armies actually fight during the measurement (%d ticks)" % fighting_ticks)
	assert_true(per_tick < FAIL_USEC, "AI cost stays near budget (%.0f usec per tick)" % per_tick)
