extends TestCase
## AI cost at scale (_agents/unit_ai.md §8): brain tanks (squads of 5 per side) closing to fight in the real arena.
## Prints MEASURE ai_usec_per_tick (brains + orders, per physics tick) and fails far above the budget, so a big
## regression shows up in `make ai-scenarios` (`make ai-perf` runs just this). Timing on the shared dev machine swings
## ±30% with other worktrees' load: compare runs, don't trust one. Always measure on builder0 (`make remote`).
##
## Round 4 (X2) raised the bar from 50 units to 60 — the lead wants ~30 a side — so `--units=N` picks the total,
## default 60. The round-2 and round-3 numbers in unit_ai.md were taken at 50: `make ai-perf UNITS=50` repeats them.

const PENDING := []
## Round-4 X2 target: 60 units, 4 ms per physics tick, measured on builder0.
const BUDGET_USEC := 4000.0
## Fail only far above today's cost: timing on a shared machine is noisy.
const FAIL_USEC := 20000.0
const DEFAULT_UNITS := 60
const PER_SQUAD := 5


static func _units() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--units="):
			return maxi(2, int(arg.trim_prefix("--units=")))
	return DEFAULT_UNITS


func test_the_brains_stay_inside_the_cpu_budget() -> void:
	var total := _units()
	var per_side := total / 2
	var s := AiScenario.create(self, 5)
	# Spread each side along its base line so they don't start stacked on nine spawn slots.
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		for index in per_side:
			var tank := s.game_match.add_brain_tank(team, "S%d" % (index / PER_SQUAD),
					"tank", [{}], "%s_S%d_%d" % ["Green" if team == Match.Team.GREEN else "Rust",
					index / PER_SQUAD, index % PER_SQUAD + 1])
			var x := -96.0 + index * (192.0 / maxf(per_side - 1, 1))
			tank.global_position = Vector3(x if team == Match.Team.GREEN else -x, 0,
					70 if team == Match.Team.GREEN else -70)
			tank.rotation.y = 0.0 if team == Match.Team.GREEN else PI
	await s.start()
	BandProbe.install(s.game_match)
	OrderController.profile_usec = 0
	TankBrain.profile_parts = {}
	OrderController.profiling = true
	OrderController.profile_detail = OS.get_cmdline_user_args().has("--profile-parts")
	var los_before := CoverMap.los_computed
	var queries_before := CoverMap.los_queries
	var ticks := SimClock.TICK_RATE * 30
	var fighting_ticks := 0
	for tick in ticks:
		await s.step()
		if s.game_match.stats["first_shot_seconds"] >= 0.0:
			fighting_ticks += 1
	OrderController.profiling = false
	OrderController.profile_detail = false
	var per_tick := float(OrderController.profile_usec) / ticks
	var alive := s.game_match.alive_count(Match.Team.GREEN) + s.game_match.alive_count(Match.Team.RUST)
	print("MEASURE ai_usec_per_tick %.0f at %d brains (budget %.0f); %d ticks fighting, %d alive at the end; LOS %d queries, %d computed" % [
			per_tick, total, BUDGET_USEC, fighting_ticks, alive, CoverMap.los_queries - queries_before, CoverMap.los_computed - los_before])
	var parts: Array = TankBrain.profile_parts.keys().map(func(part: String) -> String:
		return "%s %.0f" % [part, float(TankBrain.profile_parts[part]) / ticks])
	parts.sort()
	print("MEASURE ai_band_per_tick wall %.0f usec, thread cpu %.0f usec; per living unit per tick %.1f usec cpu (the -10 priority band: brains and orders; cpu time doesn't grow with other load, and per unit compares variants that fight different battles)" % [
			float(BandProbe.wall_usec) / maxi(BandProbe.ticks, 1), float(BandProbe.cpu_usec) / maxi(BandProbe.ticks, 1),
			float(BandProbe.cpu_usec) / maxi(BandProbe.unit_ticks, 1)])
	print("MEASURE ai_execution full %d held %d" % [OrderController.executed_full, OrderController.executed_held])
	print("MEASURE ai_usec_per_tick_parts %s (the rest: executing orders, aiming, firing)" % ", ".join(parts))
	if not OS.get_cmdline_user_args().has("--profile-parts"):
		print("      (--profile-parts, i.e. make ai-perf DETAIL=1, adds the finer laps inside moving and shooting)")
	assert_true(fighting_ticks > SimClock.TICK_RATE * 5, "the armies actually fight during the measurement (%d ticks)" % fighting_ticks)
	assert_true(per_tick < FAIL_USEC, "AI cost stays near budget (%.0f usec per tick)" % per_tick)
