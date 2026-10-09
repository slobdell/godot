class_name BrainsAB
extends Node
## Round 16 (brains): the in-fight A/B of make ai-perf AB=1 for ANY run: a headless match, the skirmish he plays.
## `--brains-ab-run` (all switches) or `--brains-ab-run=<BrainSwitches name>` flips the round's switches every AB_BLOCK
## physics ticks and charges each tick's controller band (process_physics_priority -10: every OrderController and
## TankBrain) to its arm, in this thread's CPU time (/proc/thread-self/schedstat) and in wall time. The switches are
## equalities, so the run is the same run with or without the A/B: its MATCH_RESULT state hash must equal a run
## without the flag (that is the proof), and both arms share whatever load the machine has.
## Prints BRAINS_AB at exit (scenario_perf's own `--brains-ab` is the same idea inside that test's loop).
## Measurement only: reads the clock, decides nothing.
##
## Round 17 (T1): `--brains-ab-run=levers` alternates BrainLevers.gate instead: arm ON = the variant's DECISION levers
## (the run's --green-brain / --rust-brain must be an `l17*` variant, or there is nothing to flip), arm OFF = the
## champion's behaviour. A lever changes the fight, so here the two arms are interleaved blocks of ONE (hybrid) fight:
## the cost is still by removal inside one run under one load, and the behaviour is priced elsewhere (the ladder, the
## drills, MATCH_RESULT over seeds). A slower think rate is booked up to a second ahead, so `--brains-ab-block=<ticks>`
## (default 30; levers want 300) and `--brains-ab-skip=<ticks>` (the first ticks of each block, charged to neither arm
## while the brains' bookings settle) exist. Each arm is also split by phase: "early" until the match's first shot,
## "fight" after it (Match.stats.first_shot_seconds), so a lever is priced while everyone travels and in the fight.

const AB_BLOCK := 30
static var _block := AB_BLOCK
static var _skip := 0
static var _match: Object = null
## [arm][phase] for phase 0 = early, 1 = fight.
static var _phase_cpu := [[0, 0], [0, 0]]
static var _phase_tick_cpu := [[0, 0], [0, 0]]
static var _phase_ticks := [[0, 0], [0, 0]]
static var _phase := 0
static var _charging := true
## The split A/B (`--brains-ab-run=levers-split`): per [half][phase], each controller's wall time charged to its unit's
## half (BrainLevers.open_for: ON = the lever open for it this block), and the unit-ticks charged.
static var split_on := false
static var _unit_usec := [[0, 0], [0, 0]]
static var _unit_ticks := [[0, 0], [0, 0]]
static var _split_ticks := [0, 0]
## ...and per unit: name -> [usec ON, unit-ticks ON, usec OFF, unit-ticks OFF], phase "fight" only (the paired
## estimate: each unit against itself, so which units fell in which half drops out).
static var _per_unit := {}

static var _installed_for := 0
static var _cpu := [0, 0]
static var _wall := [0, 0]
static var _ticks := [0, 0]
## The whole physics tick's scripts (every _physics_process: elements and commanders at -30..-15, the band, tanks,
## Match, shells), per arm: changes outside the band (the element leaders' slot grounding) show here.
static var _tick_cpu := [0, 0]
static var _which := ""
## `--brains-parts`: the brains' detailed laps and call counts (OrderController.add_part: think / execute / move /
## weapon, nav.*, nav.closest@<site>, los.*, avoid.*) printed at exit as BRAINS_PARTS, per controller-band tick. The
## same parts `make sim-profile` reports as brain/* sections, for runs SimProfile does not reach (his skirmish).
static var _parts := false
static var _census := false
static var _arm := 0
static var _band_start := 0
static var _band_wall := 0
static var _tick_start := 0

## 0 opens the tick (and flips the switches, before anything in the tick runs), 1 opens the band, 2 closes it,
## 3 closes the tick.
const ROLES := [[-100001, "BrainsABTickOpen"], [-11, "BrainsABOpen"], [-9, "BrainsABClose"], [100001, "BrainsABTickClose"]]
var role := 0


## Called by every OrderController on _ready; installs the probes once per parent (the brains' container).
static func ensure(parent: Node, game_match: Object = null) -> void:
	if parent == null or _installed_for == parent.get_instance_id():
		return
	var which := requested()
	var parts := OS.get_cmdline_user_args().has("--brains-parts")
	# Round 17: `--brains-census` alone counts the think-LOD buckets (BRAINS_LOD) without the profiler's laps.
	var census := parts or OS.get_cmdline_user_args().has("--brains-census")
	if which == "" and not census:
		return
	_installed_for = parent.get_instance_id()
	_which = which
	_parts = parts
	_match = game_match
	if parts:
		OrderController.profiling = true
		OrderController.profile_detail = true
		TankBrain.profile_parts = {}
		TankBrain.profile_calls = {}
	_census = census
	if census:
		TankBrain.census = true
		TankBrain.lod_ticks = {}
		TankBrain.lod_thinks = {}
		TankBrain.first_fight_tick = -1
		TankBrain.stride_skips = [0, 0]
		TankBrain.peek_stats = [{}, {}]
		TankBrain.held_variants = [{}, {}]
	_block = AB_BLOCK
	_skip = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--brains-ab-block="):
			_block = maxi(1, int(arg.trim_prefix("--brains-ab-block=")))
		elif arg.begins_with("--brains-ab-skip="):
			_skip = maxi(0, int(arg.trim_prefix("--brains-ab-skip=")))
	_cpu = [0, 0]
	_wall = [0, 0]
	_ticks = [0, 0]
	_tick_cpu = [0, 0]
	_phase_cpu = [[0, 0], [0, 0]]
	_phase_tick_cpu = [[0, 0], [0, 0]]
	_phase_ticks = [[0, 0], [0, 0]]
	_unit_usec = [[0, 0], [0, 0]]
	_unit_ticks = [[0, 0], [0, 0]]
	_split_ticks = [0, 0]
	_per_unit = {}
	split_on = which == "levers-split"
	BrainLevers.split = split_on
	for index in ROLES.size():
		var probe := BrainsAB.new()
		probe.role = index
		probe.name = ROLES[index][1]
		probe.process_physics_priority = ROLES[index][0]
		parent.add_child.call_deferred(probe)


## The split A/B: one controller's wall time this tick, charged to its unit's half (called by OrderController).
static func charge_unit(unit: String, usec: int) -> void:
	if not _charging:
		return
	var half := 0 if BrainLevers.open_for(unit) else 1
	_unit_usec[half][_phase] += usec
	_unit_ticks[half][_phase] += 1
	if _phase == 1:
		var row: Array = _per_unit.get(unit, [0, 0, 0, 0])
		row[half * 2] += usec
		row[half * 2 + 1] += 1
		_per_unit[unit] = row


## "" (off), "all", "levers", "levers-split", or one BrainSwitches name.
static func requested() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg == "--brains-ab-run":
			return "all"
		if arg.begins_with("--brains-ab-run="):
			return arg.trim_prefix("--brains-ab-run=")
	return ""


static func _thread_cpu_usec() -> int:
	var file := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if file == null:
		return 0
	return int(file.get_line().get_slice(" ", 0)) / 1000


func _physics_process(_delta: float) -> void:
	match role:
		0:
			var frame := Engine.get_physics_frames()
			_arm = int(frame / _block) % 2  # 0 = the round's changes ON, 1 = OFF
			_charging = frame % _block >= _skip
			if _which == "all":
				BrainSwitches.set_all(_arm == 0)
			elif _which == "levers":
				BrainLevers.gate = _arm == 0
			elif _which == "levers-split":
				BrainLevers.split_flip = _arm
			elif _which != "":
				BrainSwitches.set_named(_which, _arm == 0)
			if _phase == 0 and _match != null and is_instance_valid(_match) \
					and float(_match.get("stats").get("first_shot_seconds", -1.0)) >= 0.0:
				_phase = 1
			_tick_start = _thread_cpu_usec()
		1:
			_band_start = _thread_cpu_usec()
			_band_wall = Time.get_ticks_usec()
		2:
			if split_on and _charging:
				_split_ticks[_phase] += 1
			if _charging:
				var used := _thread_cpu_usec() - _band_start
				_cpu[_arm] += used
				_wall[_arm] += Time.get_ticks_usec() - _band_wall
				_ticks[_arm] += 1
				_phase_cpu[_arm][_phase] += used
				_phase_ticks[_arm][_phase] += 1
		3:
			if _charging:
				var used := _thread_cpu_usec() - _tick_start
				_tick_cpu[_arm] += used
				_phase_tick_cpu[_arm][_phase] += used


func _exit_tree() -> void:
	if role != 2 or _ticks[0] + _ticks[1] == 0:
		return
	if _parts:
		var ticks := float(_ticks[0] + _ticks[1])
		var table := {}
		for part: String in TankBrain.profile_parts:
			table[part] = [snappedf(float(TankBrain.profile_parts[part]) / ticks / 1000.0, 0.001),
					snappedf(float(TankBrain.profile_calls.get(part, 0)) / ticks, 0.01)]
		print("BRAINS_PARTS %d ticks, [ms, calls] per tick: %s" % [int(ticks), JSON.stringify(table)])
	if _census:
		print("BRAINS_LOD unit-ticks %s; thinks %s; first fight-rate tick %d" % [JSON.stringify(TankBrain.lod_ticks),
				JSON.stringify(TankBrain.lod_thinks), TankBrain.first_fight_tick])
		print("BRAINS_KEPT kept %s; changed %s" % [JSON.stringify(TankBrain.lod_kept), JSON.stringify(TankBrain.lod_changed)])
		# Round 18 (B1): the peeking arm assertion, per side (green, rust).
		print("BRAINS_PEEK green %s; rust %s" % [JSON.stringify(TankBrain.peek_stats[0]), JSON.stringify(TankBrain.peek_stats[1])])
		# ...and the variant every spawned brain actually HELD (read from the brains, not the command line).
		print("BRAINS_VARIANTS green %s; rust %s" % [JSON.stringify(TankBrain.held_variants[0]), JSON.stringify(TankBrain.held_variants[1])])
		# Round 17: the ARM assertion for a run with a lever ON for a whole side (perf-play on his laptop): did the
		# far-unit stride act, how much of the CPU's time had nothing in reach and no order, and where this machine's
		# tick time goes (the controller band's thread CPU beside the whole tick's scripts). Counted ticks are the
		# charged ones (all of them outside an A/B).
		var ticks: int = _ticks[0] + _ticks[1]
		var seconds := float(ticks) / SimClock.TICK_RATE
		var cpu_total := 0
		var cpu_free := 0
		var cpu_ordered := 0
		for key: String in TankBrain.lod_ticks:
			if key.begins_with("p:"):
				continue
			var n := int(TankBrain.lod_ticks[key])
			cpu_total += n
			if key == "idle_ordered":
				cpu_ordered += n
			elif key != "fight":
				cpu_free += n
		print(("BRAINS_ARM %d ticks (%.0f s): stride skipped green %d, rust %d controller ticks (%.1f / %.1f a second); "
				+ "CPU unit-ticks %d: nothing in reach and no order %.1f %%, carrying an order %.1f %%, in reach %.1f %%; "
				+ "controller band %.2f ms a tick, whole tick's scripts %.2f ms a tick (thread CPU)") % [ticks, seconds,
				TankBrain.stride_skips[0], TankBrain.stride_skips[1], TankBrain.stride_skips[0] / maxf(seconds, 0.001),
				TankBrain.stride_skips[1] / maxf(seconds, 0.001), cpu_total,
				100.0 * cpu_free / maxf(cpu_total, 1.0), 100.0 * cpu_ordered / maxf(cpu_total, 1.0),
				100.0 * (cpu_total - cpu_free - cpu_ordered) / maxf(cpu_total, 1.0),
				float(_cpu[0] + _cpu[1]) / maxf(ticks, 1) / 1000.0, float(_tick_cpu[0] + _tick_cpu[1]) / maxf(ticks, 1) / 1000.0])
	if _which == "":
		return
	BrainSwitches.set_all(true)
	BrainLevers.gate = true
	var phases := []
	for phase in 2:
		var on_band := float(_phase_cpu[0][phase]) / maxi(_phase_ticks[0][phase], 1)
		var off_band := float(_phase_cpu[1][phase]) / maxi(_phase_ticks[1][phase], 1)
		var on_whole := float(_phase_tick_cpu[0][phase]) / maxi(_phase_ticks[0][phase], 1)
		var off_whole := float(_phase_tick_cpu[1][phase]) / maxi(_phase_ticks[1][phase], 1)
		phases.append("%s: band ON %.0f OFF %.0f (%.1f%%), whole tick ON %.0f OFF %.0f (%.1f%%), ticks %d/%d" % [
				["early", "fight"][phase], on_band, off_band, 100.0 * (off_band - on_band) / maxf(off_band, 1.0),
				on_whole, off_whole, 100.0 * (off_whole - on_whole) / maxf(off_whole, 1.0),
				_phase_ticks[0][phase], _phase_ticks[1][phase]])
	if split_on:
		BrainLevers.split = false
		var rows := []
		for phase in 3:
			var on_usec: int = _unit_usec[0][0] + _unit_usec[0][1] if phase == 2 else _unit_usec[0][phase]
			var off_usec: int = _unit_usec[1][0] + _unit_usec[1][1] if phase == 2 else _unit_usec[1][phase]
			var on_n: int = _unit_ticks[0][0] + _unit_ticks[0][1] if phase == 2 else _unit_ticks[0][phase]
			var off_n: int = _unit_ticks[1][0] + _unit_ticks[1][1] if phase == 2 else _unit_ticks[1][phase]
			var ticks: int = _split_ticks[0] + _split_ticks[1] if phase == 2 else _split_ticks[phase]
			var on_per := float(on_usec) / maxi(on_n, 1)
			var off_per := float(off_usec) / maxi(off_n, 1)
			var units := float(on_n + off_n) / maxi(ticks, 1)
			rows.append("%s: ON %.1f OFF %.1f usec per unit-tick (%.1f%% saved; %.0f usec/tick at its %.1f units), unit-ticks %d/%d over %d ticks" % [
					["early", "fight", "all"][phase], on_per, off_per, 100.0 * (off_per - on_per) / maxf(off_per, 0.001),
					(off_per - on_per) * units, units, on_n, off_n, ticks])
		# The paired estimate (fight phase): per unit, its own OFF minus ON cost per unit-tick, weighted by the fewer of
		# its two counts; the standard error from the spread of those differences across units.
		var diffs := []
		var weights := []
		var off_sum := 0.0
		for unit: String in _per_unit:
			var row: Array = _per_unit[unit]
			if int(row[1]) >= 30 and int(row[3]) >= 30:
				diffs.append(float(row[2]) / row[3] - float(row[0]) / row[1])
				weights.append(float(mini(row[1], row[3])))
				off_sum += float(row[2]) / row[3] * mini(row[1], row[3])
		var wsum := 0.0
		var mean := 0.0
		for i in diffs.size():
			wsum += weights[i]
			mean += diffs[i] * weights[i]
		mean /= maxf(wsum, 1.0)
		var var_sum := 0.0
		for i in diffs.size():
			var_sum += weights[i] * (diffs[i] - mean) * (diffs[i] - mean)
		var se := sqrt(var_sum / maxf(wsum, 1.0) / maxf(diffs.size() - 1, 1))
		var off_mean := off_sum / maxf(wsum, 1.0)
		print("BRAINS_AB_PAIRED %s fight: %.2f usec per unit-tick saved (+- %.2f s.e.), %.2f%% (+- %.2f) of %.1f; %d units paired" % [
				_which, mean, se, 100.0 * mean / maxf(off_mean, 0.001), 100.0 * se / maxf(off_mean, 0.001), off_mean, diffs.size()])
		print("BRAINS_AB_SPLIT %s (%d-tick blocks, halves swapped each block, first %d of each uncharged; controller wall time): %s" % [
				_which, _block, _skip, "; ".join(rows)])
	print("BRAINS_AB_PHASES %s (%d-tick blocks, first %d of each uncharged): %s" % [_which, _block, _skip, "; ".join(phases)])
	var on_cpu := float(_cpu[0]) / maxi(_ticks[0], 1)
	var off_cpu := float(_cpu[1]) / maxi(_ticks[1], 1)
	var on_tick := float(_tick_cpu[0]) / maxi(_ticks[0], 1)
	var off_tick := float(_tick_cpu[1]) / maxi(_ticks[1], 1)
	print(("BRAINS_AB %s: controller band cpu ON %.0f usec/tick (%d ticks), OFF %.0f usec/tick (%d ticks): %.1f%% saved; "
			+ "whole tick's scripts cpu ON %.0f OFF %.0f: %.1f%% saved; band wall ON %.0f OFF %.0f; %d-tick blocks in one run") % [
			_which, on_cpu, _ticks[0], off_cpu, _ticks[1], 100.0 * (off_cpu - on_cpu) / maxf(off_cpu, 1.0),
			on_tick, off_tick, 100.0 * (off_tick - on_tick) / maxf(off_tick, 1.0),
			float(_wall[0]) / maxi(_ticks[0], 1), float(_wall[1]) / maxi(_ticks[1], 1), _block])
