class_name Difficulty
extends RefCounted
## A difficulty knob for a team's brains (round-3 stretch, _agents/streams/archive/round3/ai.md): how quickly they react and how well
## they aim. Normal is the brains as they are; the others only slow thinking down or sharpen it and add a deterministic
## aim wander (no random numbers: a pattern from the tick and the unit's slot, so seeded matches stay reproducible).
##
## Selected per team with --green-difficulty=<level> / --rust-difficulty=<level> (read here, like BrainVariants), or
## Difficulty.use(team, level) in tests and modes.

const LEVELS := {
	# Reacts in about a third of a second, and its aim wanders up to ~2 m around the lead point: most long shots miss.
	"easy": {"think_ticks": SimClock.TICK_RATE * 3 / 10, "aim_wander_m": 2.0},
	"normal": {"think_ticks": 0, "aim_wander_m": 0.0},
	# Reacts every 4 ticks (the default is 6) and aims true.
	"hard": {"think_ticks": SimClock.TICK_RATE / 15, "aim_wander_m": 0.0},
}
const DEFAULT := "normal"
## The wander pattern changes every this many ticks (a crew re-laying the gun).
const WANDER_PERIOD_TICKS := SimClock.TICK_RATE / 3

static var _levels: Array = []


static func for_team(team: int) -> Dictionary:
	if _levels.is_empty():
		_levels = [DEFAULT, DEFAULT]
		for arg in OS.get_cmdline_user_args():
			for side in 2:
				var prefix := "--%s-difficulty=" % ["green", "rust"][side]
				if arg.begins_with(prefix) and LEVELS.has(arg.trim_prefix(prefix)):
					_levels[side] = arg.trim_prefix(prefix)
				elif arg.begins_with(prefix):
					push_error("unknown difficulty '%s' (have %s)" % [arg.trim_prefix(prefix), LEVELS.keys()])
	return LEVELS[_levels[team]]


static func use(team: int, level: String) -> void:
	for_team(team)
	assert(LEVELS.has(level), "unknown difficulty %s" % level)
	_levels[team] = level


static func reset() -> void:
	_levels = []


static func name_for_team(team: int) -> String:
	for_team(team)
	return _levels[team]


## The aim offset (meters, flat) for a unit at `slot` on `tick`: a fixed cycle of lateral and depth steps within
## `wander` meters, changing every WANDER_PERIOD_TICKS. Zero wander → Vector3.ZERO.
static func aim_offset(wander: float, tick: int, slot: int) -> Vector3:
	if wander <= 0.0:
		return Vector3.ZERO
	var step := (tick / WANDER_PERIOD_TICKS + slot * 3) % 8
	# Eight points around a square of half-size `wander` (no trig), in a scrambled order.
	var pattern: Array[Vector2] = [Vector2(1, 0), Vector2(-1, -1), Vector2(0, 1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 1),
			Vector2(0, -1), Vector2(-1, 1)]
	var point := pattern[step] * wander
	return Vector3(point.x, 0.0, point.y)
