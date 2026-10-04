extends TestCase
## AI cost at scale (_agents/unit_ai.md §8): brain tanks (squads of 5 per side) closing to fight in the real arena.
## Prints MEASURE ai_usec_per_tick (brains + orders, per physics tick) and fails far above the budget, so a big
## regression shows up in `make ai-scenarios` (`make ai-perf` runs just this). Timing on the shared dev machine swings
## ±30% with other worktrees' load: compare runs, don't trust one. Always measure on builder0 (`make remote`).
##
## Round 4 (X2) raised the bar from 50 units to 60 — the lead wants ~30 a side — so `--units=N` picks the total,
## default 60. The round-2 and round-3 numbers in unit_ai.md were taken at 50: `make ai-perf UNITS=50` repeats them.

const PENDING := []
## Round 15 (squad P3): the runner runs this file FIRST in its process, so the suite measures the battle `make ai-perf`
## measures. Its fight depends on the world's history in the process, below anything a scenario can reset (builder0,
## 85703220: alone LOS 148 100 queries / 26 alive; after any one of the ten scenarios before it 156 382 / 24; with a
## warm-up arena built and freed first, 156 382 alone but 167 094 / 27 in the suite). Not the navmesh resource and not
## stale regions (both probed). The perf_start line names it: alone the fight begins at match tick 0, after any earlier
## scenario at tick 1 -- one tick of phase, and every brain's think stagger is keyed on Match.tick. First in a fresh
## process is the one history alone and suite share by construction: builder0 at cf574701, `make ai-perf-leak`, all 12
## runs LOS 148 100 / 26 alive; `SCENARIO_ORDER=alpha` (the old order) 2 fights.
const RUN_FIRST := true
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
	print("MEASURE perf_start scenario_index=%d match_tick=%d" % [int(Engine.get_meta("scenario_index", -1)), s.game_match.tick])
	BandProbe.install(s.game_match)
	OrderController.profile_usec = 0
	TankBrain.profile_parts = {}
	TankBrain.profile_calls = {}
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
	# Round 16 (brains): --brains-ab[=<switch>] flips BrainSwitches (all, or the one named) every AB_BLOCK ticks inside
	# this one fight and charges each tick's band CPU to the arm it ran under. The switches are equalities, so the fight
	# is the same fight either way (the LOS fingerprint below proves it) and both arms see the same machine load.
	var ab := _ab_switch()
	var ab_cpu := [0, 0]
	var ab_ticks := [0, 0]
	for tick in ticks:
		var arm := 0
		if ab != "":
			arm = (tick / AB_BLOCK) % 2  # 0 = switches ON (the round's changes), 1 = OFF (the code before them)
			if ab == "all":
				BrainSwitches.set_all(arm == 0)
			else:
				BrainSwitches.set_named(ab, arm == 0)
		var cpu_before := BandProbe.cpu_usec
		await s.step()
		ab_cpu[arm] += BandProbe.cpu_usec - cpu_before
		ab_ticks[arm] += 1
		if s.game_match.stats["first_shot_seconds"] >= 0.0:
			fighting_ticks += 1
		if tick % REF_EVERY_TICKS == REF_EVERY_TICKS - 1:
			during.append(reference_ms())
	OrderController.profiling = false
	OrderController.profile_detail = false
	if ab != "":
		BrainSwitches.set_all(true)
		var on_us := float(ab_cpu[0]) / maxi(ab_ticks[0], 1)
		var off_us := float(ab_cpu[1]) / maxi(ab_ticks[1], 1)
		print("MEASURE ai_ab %s: band cpu ON %.0f usec/tick (%d ticks), OFF %.0f usec/tick (%d ticks): %.1f%% of the band saved, %d-tick blocks interleaved in one fight" % [
				ab, on_us, ab_ticks[0], off_us, ab_ticks[1], 100.0 * (off_us - on_us) / maxf(off_us, 1.0), AB_BLOCK])
	var per_tick := float(OrderController.profile_usec) / ticks
	var alive := s.game_match.alive_count(Match.Team.GREEN) + s.game_match.alive_count(Match.Team.RUST)
	print("MEASURE ai_usec_per_tick %.0f at %d brains (budget %.0f); %d ticks fighting, %d alive at the end; LOS %d queries, %d computed" % [
			per_tick, total, BUDGET_USEC, fighting_ticks, alive, CoverMap.los_queries - queries_before, CoverMap.los_computed - los_before])
	var parts: Array = TankBrain.profile_parts.keys().map(func(part: String) -> String:
		return "%s %.0f" % [part, float(TankBrain.profile_parts[part]) / ticks])
	# Round 16 (A2): calls per tick, for the parts that count queries (los.*, nav.*, avoid.*).
	var calls: Array = TankBrain.profile_calls.keys().filter(func(part: String) -> bool:
		return part.begins_with("los.") or part.begins_with("nav.") or part.begins_with("avoid.")).map(
		func(part: String) -> String: return "%s %.1f" % [part, float(TankBrain.profile_calls[part]) / ticks])
	calls.sort()
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
	if not calls.is_empty():
		print("MEASURE ai_calls_per_tick %s (los.ray counts the match's intel rays too)" % ", ".join(calls))
	if not OS.get_cmdline_user_args().has("--profile-parts"):
		print("      (--profile-parts, i.e. make ai-perf DETAIL=1, adds the finer laps inside moving and shooting)")
	assert_true(fighting_ticks > SimClock.TICK_RATE * 5, "the armies actually fight during the measurement (%d ticks)" % fighting_ticks)
	var machine := machine_name()
	var nominal := nominal_ms(machine)
	var window := median(during)
	var ratio := window / nominal if nominal > 0.0 else 0.0
	print("MEASURE perf_reference %.3f ms median during the fight (%d samples), %.3f before it, nominal %s on %s: %.2fx (refuses above %.1fx)" % [
			window, during.size(), median(pre), ("%.3f" % nominal) if nominal > 0.0 else "NONE", machine, ratio, LOADED_RATIO])
	# Round 17 (ship W4, lent for this one additive line; NOT judged): the brains' cost in units of the reference workload
	# measured in the same run. On builder0's hybrid CPU six pinned runs read 11.0-21.7k usec raw and 12.4-14.6k usec per
	# ref-ms normalised; this round's checks collect it to show whether it is steady enough to judge (the orchestrator).
	print("MEASURE ai_usec_per_ref_ms %.0f (ai_usec_per_tick %.0f / perf_reference %.3f ms during the fight; machine %s, cpu %s)" % [
			per_tick / window if window > 0.0 else 0.0, per_tick, window, machine, _cpu_kind()])
	if OS.get_cmdline_user_args().has("--perf-record-nominal"):
		var all: Array[float] = pre.duplicate()
		all.append_array(during)
		print("PERF_NOMINAL %s" % JSON.stringify({"machine": machine, "ref_ms": snappedf(median(all), 0.001),
				"samples": all.size(), "ai_usec_per_tick": roundi(per_tick)}))
	var refuse := not OS.get_cmdline_user_args().has("--perf-refuse=off")
	# Round 17 (ship, lent by the orchestrator): on a HYBRID machine (builder0: P-cores 0-3, E-cores 4-11) only a run
	# pinned to the P-cores judges -- check's perf-judge (tools/perf_judge.sh). Unpinned, the scheduler mixes core
	# types, and the reference and the brains do NOT slow alike: 9b404030 under load read the reference at 1.46x (under
	# the refusal line) and the brains at 21444 usec/tick (over the fail line) -- a false FAIL -- while perf-judge in the
	# same check passed at 1.35x. A machine with no hybrid topology (the laptop) judges as before.
	var cpu_kind := _cpu_kind()
	if refuse and nominal <= 0.0:
		not_judged = "reason=no_nominal machine=%s" % machine
	elif refuse and cpu_kind != "-" and cpu_kind != "P":
		not_judged = "reason=unpinned cpu=%s (a hybrid machine: perf-judge judges, pinned to the P-cores)" % cpu_kind
	elif refuse and ratio > LOADED_RATIO:
		not_judged = "reason=loaded ref=%.2fx" % ratio
	if not not_judged.is_empty():
		print("SCENARIO_NOT_JUDGED %s (the CPU budget was not judged: %.0f usec per tick %s the %.0f line; not a pass)" % [
				not_judged, per_tick, "under" if per_tick < FAIL_USEC else "OVER", FAIL_USEC])
		return
	assert_true(per_tick < FAIL_USEC, "AI cost stays near budget (%.0f usec per tick)" % per_tick)


## --brains-ab: alternate the round-16 switches in blocks of this many ticks (one second at 30 Hz).
const AB_BLOCK := 30


## "" (no A/B), "all", or one BrainSwitches name.
static func _ab_switch() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg == "--brains-ab":
			return "all"
		if arg.begins_with("--brains-ab="):
			var name := arg.trim_prefix("--brains-ab=")
			if name != "all" and not BrainSwitches.NAMES.has(name):
				push_error("--brains-ab=%s: no such switch (have %s, or all)" % [name, ", ".join(BrainSwitches.NAMES)])
			return name
	return ""


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


## Which core type this process may run on (hybrid CPUs): "P" / "E" / "mixed" from its affinity, "-" elsewhere.
static func _cpu_kind() -> String:
	# /proc and /sys files report sizes that are not their contents (0, or a page of NULs), so get_file_as_string reads
	# them wrong: read every one by line. Until 2026-10-03 this returned "-" on builder0 (the status file read empty),
	# then "mixed:0-3" for a P-pinned run (the sysfs list did not compare equal).
	var p_cpus := _first_line("/sys/devices/cpu_core/cpus")
	var e_cpus := _first_line("/sys/devices/cpu_atom/cpus")
	if p_cpus == "" or e_cpus == "":
		return "-"
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("Cpus_allowed_list:"):
			var allowed := line.get_slice(":", 1).strip_edges()
			return "P" if allowed == p_cpus else ("E" if allowed == e_cpus else "mixed:" + allowed)
	return "-"


## The first line of a /proc or /sys file, stripped (and of NULs), or "" when it cannot be read.
static func _first_line(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_line().replace(char(0), "").strip_edges()


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
