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

## ---- Round 14 (squad Q2): the budget REFUSES on a loaded machine (verification.md rule 3) -----------------------
## This scenario tripped whenever builder0 ran several checks at once (22 ms/tick against the 20 ms line in round 13's
## audio check; 17-18 ms with three running; 11.9 alone) and every isolated re-run was green: it judged a busy
## machine, not the brains. So it times a fixed reference workload (the control stream's yardstick,
## `ControlFixture.reference_work`) before the fight and every REF_EVERY_TICKS ticks during it, and compares the
## median with this machine's recorded nominal (`perf_nominal.json`, recorded idle with `make ai-perf-nominal`).
## Above LOADED_RATIO it prints `SCENARIO_NOT_JUDGED reason=loaded ref=<x>x` and sets `not_judged`: the runner
## counts it outside `passed` and the gate and `check`'s verdict say NOT JUDGED -- never a pass. The fight still
## runs and its other assertion is still judged, so a script error here is still caught. A machine with no
## nominal refuses the same way (reason=no_nominal): no yardstick, no verdict. `--perf-refuse=off` is the
## mutation arm: it judges regardless, which is how it failed under load before.
const ControlFixture := preload("res://tests/support/control_fixture.gd")
const NOMINAL_PATH := "res://tests/ai_scenarios/perf_nominal.json"
const LOADED_RATIO := 1.5
## One reference sample: this many `reference_work` calls (~1-2 ms on builder0), long enough to read above the
## microsecond clock's granularity and short enough not to disturb the fight it is interleaved with.
const REF_CALLS := 20
const REF_PRE_SAMPLES := 9
const REF_EVERY_TICKS := 30

## Read by tests/ai_scenarios/run_scenarios.gd: non-empty = the budget was refused, and why.
var not_judged := ""


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
	var pre: Array[float] = []
	for i in REF_PRE_SAMPLES:
		pre.append(reference_ms())
	var during: Array[float] = []
	for tick in ticks:
		await s.step()
		if s.game_match.stats["first_shot_seconds"] >= 0.0:
			fighting_ticks += 1
		if tick % REF_EVERY_TICKS == REF_EVERY_TICKS - 1:
			during.append(reference_ms())
	OrderController.profiling = false
	OrderController.profile_detail = false
	var per_tick := float(OrderController.profile_usec) / ticks
	var alive := s.game_match.alive_count(Match.Team.GREEN) + s.game_match.alive_count(Match.Team.RUST)
	print("MEASURE ai_usec_per_tick %.0f at %d brains (budget %.0f); %d ticks fighting, %d alive at the end; LOS %d queries, %d computed" % [
			per_tick, total, BUDGET_USEC, fighting_ticks, alive, CoverMap.los_queries - queries_before, CoverMap.los_computed - los_before])
	var parts: Array = TankBrain.profile_parts.keys().map(func(part: String) -> String:
		return "%s %.0f" % [part, float(TankBrain.profile_parts[part]) / ticks])
	parts.sort()
	# Per SECOND of match time as well as per tick: a tick-rate change moves the per-tick figure without changing what
	# the brains cost a player (round 5, the 30 Hz move).
	print("MEASURE ai_band_per_tick wall %.0f usec, thread cpu %.0f usec; per living unit per tick %.1f usec cpu (the -10 priority band: brains and orders; cpu time doesn't grow with other load, and per unit compares variants that fight different battles)" % [
			float(BandProbe.wall_usec) / maxi(BandProbe.ticks, 1), float(BandProbe.cpu_usec) / maxi(BandProbe.ticks, 1),
			float(BandProbe.cpu_usec) / maxi(BandProbe.unit_ticks, 1)])
	print("MEASURE ai_band_per_second %.1f ms cpu per second of match time, %.1f usec per living unit per second (at %d Hz)" % [
			float(BandProbe.cpu_usec) / maxi(BandProbe.ticks, 1) * SimClock.TICK_RATE / 1000.0,
			float(BandProbe.cpu_usec) / maxf(float(BandProbe.unit_ticks) / SimClock.TICK_RATE, 1.0), SimClock.TICK_RATE])
	print("MEASURE ai_execution full %d held %d" % [OrderController.executed_full, OrderController.executed_held])
	print("MEASURE ai_usec_per_tick_parts %s (the rest: executing orders, aiming, firing)" % ", ".join(parts))
	if not OS.get_cmdline_user_args().has("--profile-parts"):
		print("      (--profile-parts, i.e. make ai-perf DETAIL=1, adds the finer laps inside moving and shooting)")
	assert_true(fighting_ticks > SimClock.TICK_RATE * 5, "the armies actually fight during the measurement (%d ticks)" % fighting_ticks)
	var machine := machine_name()
	var nominal := nominal_ms(machine)
	var window := median(during)
	var ratio := window / nominal if nominal > 0.0 else 0.0
	print("MEASURE perf_reference %.3f ms median during the fight (%d samples), %.3f before it, nominal %s on %s: %.2fx (refuses above %.1fx)" % [
			window, during.size(), median(pre), ("%.3f" % nominal) if nominal > 0.0 else "NONE", machine, ratio, LOADED_RATIO])
	if OS.get_cmdline_user_args().has("--perf-record-nominal"):
		var all: Array[float] = pre.duplicate()
		all.append_array(during)
		print("PERF_NOMINAL %s" % JSON.stringify({"machine": machine, "ref_ms": snappedf(median(all), 0.001),
				"samples": all.size(), "ai_usec_per_tick": roundi(per_tick)}))
	var refuse := not OS.get_cmdline_user_args().has("--perf-refuse=off")
	if refuse and nominal <= 0.0:
		not_judged = "reason=no_nominal machine=%s" % machine
	elif refuse and ratio > LOADED_RATIO:
		not_judged = "reason=loaded ref=%.2fx" % ratio
	if not not_judged.is_empty():
		print("SCENARIO_NOT_JUDGED %s (the CPU budget was not judged: %.0f usec per tick %s the %.0f line; not a pass)" % [
				not_judged, per_tick, "under" if per_tick < FAIL_USEC else "OVER", FAIL_USEC])
		return
	assert_true(per_tick < FAIL_USEC, "AI cost stays near budget (%.0f usec per tick)" % per_tick)


## One sample of the yardstick, in milliseconds.
static func reference_ms() -> float:
	var started := Time.get_ticks_usec()
	for i in REF_CALLS:
		ControlFixture.reference_work()
	return (Time.get_ticks_usec() - started) / 1000.0


static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


## `--perf-machine=NAME` or the kernel's hostname: the key into perf_nominal.json.
static func machine_name() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-machine="):
			return arg.trim_prefix("--perf-machine=")
	# /etc/hostname, not /proc/sys/kernel/hostname: FileAccess reads a /proc file as empty (it reports size 0).
	var host := FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	if host == "":
		host = OS.get_environment("HOSTNAME")
	return host if host != "" else "unknown"


## This machine's recorded reference time, or 0 when it has none.
static func nominal_ms(machine: String) -> float:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOMINAL_PATH))
	if not data is Dictionary:
		return 0.0
	var entry: Variant = (data as Dictionary).get("machines", {}).get(machine, {})
	return float((entry as Dictionary).get("ref_ms", 0.0)) if entry is Dictionary else 0.0
