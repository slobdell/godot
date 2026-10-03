class_name SimProfile
extends Node
## Round 5 (CP1): where a simulation tick goes. The lead's laptop spends ~20 ms of scripts per physics tick at 60+
## vehicles, against a 5 ms budget shared with ai (_agents/streams/references/fx_tricks.md, M1). This is the combat
## stream's stopwatch: `--sim-profile` on the match runner adds two SimProfile nodes that bracket every
## `_physics_process` in a tick (the lowest and highest process_physics_priority), and the simulation's own hot paths
## add sections with `SimProfile.add(section, started_usec)` behind `if SimProfile.enabled`. The match runner prints
## SIM_PROFILE <json> at the end: ms per tick for the whole tick and per section, and whatever is left over
## ("unattributed": what runs at priority 0 outside a section, which is mostly ai's brains).
##
## Profiling only: it reads the wall clock, so nothing it measures may feed a decision (trip-up 28).

static var enabled := false


## S1 (round 16): `--sim-off=a,b` switches named pieces of the simulation's presentation-side work off for a whole run,
## so a cost is attributed by removal within one build (verification.md rule 3) -- play's `make perf-play` layer
## `no_visfield` passes `--sim-off=visfield`. Names: `visfield` (the skirmish's VisibilityField stops computing; the
## fog and radar keep the last picture), `visfield_thread` (its cell marks run on the main thread, as before S1). Only work that cannot change a decision may have a switch here.
static var _off: PackedStringArray = []
static var _off_read := false


static func switched_off(part: String) -> bool:
	if not _off_read:
		_off_read = true
		_off = LaunchFlags.from_environment().text("sim-off").split(",", false)
	return _off.has(part)
static var _usec := {}
static var _calls := {}
static var ticks := 0
static var _tick_started := 0
static var tick_usec := 0


static func reset() -> void:
	_usec.clear()
	_calls.clear()
	_counts.clear()
	ticks = 0
	tick_usec = 0


## A plain counter (queries, hits): reported per tick beside the sections.
static var _counts := {}


static func count(counter: String, amount := 1) -> void:
	_counts[counter] = int(_counts.get(counter, 0)) + amount


static func add(section: String, started_usec: int) -> void:
	_usec[section] = int(_usec.get(section, 0)) + Time.get_ticks_usec() - started_usec
	_calls[section] = int(_calls.get(section, 0)) + 1


## Marker nodes for `parent`'s tree, in process_physics_priority order. Everything between two markers is charged to
## the later marker's segment, so the tick splits by who runs when: elements and the CPU element commander (-30/-31),
## control's order executor and the CPU squad commander (-20), unit controllers (-10: OrderController turns orders and
## brains' choices into a TankCommand), and then priority 0 (tanks, brains, Match, shells), whose simulation parts
## have their own sections.
const MARKERS := [["open", -100000], ["segment:elements", -25], ["segment:order_executor+commanders", -15],
		["segment:controllers", -9], ["close", 100000]]

var _index := 0


static func install(parent: Node) -> void:
	enabled = true
	reset()
	for index in MARKERS.size():
		var node := SimProfile.new()
		node.name = "SimProfile_%d" % index
		node._index = index
		node.process_physics_priority = MARKERS[index][1]
		parent.add_child(node)


static var _segment_started := 0


## Stop profiling (tests): the marker nodes are the caller's to free.
static func uninstall() -> void:
	enabled = false
	_tick_started = 0


func _physics_process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _index == 0:
		_tick_started = now
		_segment_started = now
		return
	if _tick_started <= 0:
		return
	if _index == MARKERS.size() - 1:
		tick_usec += now - _tick_started
		ticks += 1
		return
	var section: String = MARKERS[_index][0]
	_usec[section] = int(_usec.get(section, 0)) + now - _segment_started
	_calls[section] = int(_calls.get(section, 0)) + 1
	_segment_started = now


## {ticks, tick_ms, sections: {name: {ms_per_tick, calls_per_tick}}, unattributed_ms}, sections biggest first.
static func report() -> Dictionary:
	var per_tick := float(maxi(ticks, 1))
	var names: Array = _usec.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return _usec[a] > _usec[b])
	var sections := {}
	var attributed := 0
	for section: String in names:
		# Nested sections ("match/intel" inside "match") are reported but not double-counted.
		if not section.contains("/"):
			attributed += int(_usec[section])
		sections[section] = {"ms_per_tick": snappedf(_usec[section] / per_tick / 1000.0, 0.001),
				"calls_per_tick": snappedf(_calls[section] / per_tick, 0.01)}
	var counters := {}
	for counter: String in _counts:
		counters[counter] = snappedf(_counts[counter] / per_tick, 0.01)
	return {"ticks": ticks, "tick_ms": snappedf(tick_usec / per_tick / 1000.0, 0.001), "sections": sections,
			"counters_per_tick": counters,
			"unattributed_ms": snappedf((tick_usec - attributed) / per_tick / 1000.0, 0.001)}
