class_name BrainVariants
extends RefCounted
## Brain versions and parameter sets for the AI ladder (_agents/unit_ai.md "AI ladder", `make ai-ladder`).
## A variant is feature switches (and later tuning values) that TankBrain.decide() and OrderController read
## from the situation, so older behavior stays runnable next to newer behavior and a new brain has to beat the
## champion before it becomes the default.
##
## Selected per team with the game flags --green-brain=<id> / --rust-brain=<id> (read here, not in the match
## runner, so any mode that spawns brains honors them); the default is CHAMPION.

## Features (all bool unless noted):
##   cover_fire        COVER_FIRE: fight from hide/peek pairs (A3)
##   retreat_to_cover  RETREAT breaks line of sight at nearby cover first; withdrawals back away from threats (A3)
##   hold_for_friends  never fire through a friend; CLEAR_LANE to fix the lane (A4)
##   squad_tactics     focus fire, suppress-and-flank, covering retreats, fragile escorts (A6)
##   think_ticks       (int) how often a brain in contact thinks (default TankBrain.THINK_EVERY_TICKS = 6)
##   matchups          target choice and duel appetite from Matchups; fixed guns ORBIT slow turrets (A5)
const PROFILES := {
	# Round 1's behaviors on today's sensing (tactical cover spots, contact cap): the reference point.
	"r1": {"cover_fire": false, "retreat_to_cover": false, "hold_for_friends": false, "squad_tactics": false, "matchups": false},
	"a4": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": false, "matchups": false},
	"a6": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false},
	"a5": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": true},
	# Probe: thinking 50% less often in contact (CPU) — must not lose to a6 to be adopted.
	"a6t9": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "think_ticks": 9},
}
## The variant brains use unless a flag picks another. Changed only when a ladder run says so.
## 2026-09-15: a6 (beat a4 9-7 in ladder run 1 and r1 7-5 in run 2; see unit_ai.md "AI ladder").
const CHAMPION := "a6"

static var _from_flags: Array = []


## The feature profile for `team`'s brains.
static func for_team(team: int) -> Dictionary:
	if _from_flags.is_empty():
		_from_flags = [CHAMPION, CHAMPION]
		for arg in OS.get_cmdline_user_args():
			for side in 2:
				var prefix := "--%s-brain=" % ["green", "rust"][side]
				if arg.begins_with(prefix) and PROFILES.has(arg.trim_prefix(prefix)):
					_from_flags[side] = arg.trim_prefix(prefix)
				elif arg.begins_with(prefix):
					push_error("unknown brain variant '%s' (have %s)" % [arg.trim_prefix(prefix), PROFILES.keys()])
	return PROFILES[_from_flags[team]]


## Tests and scenarios: pick a variant for a team without command-line flags (reset() restores the flags).
static func use(team: int, variant: String) -> void:
	for_team(team)
	assert(PROFILES.has(variant), "unknown brain variant %s" % variant)
	_from_flags[team] = variant


static func reset() -> void:
	_from_flags = []


static func name_for_team(team: int) -> String:
	for_team(team)
	return _from_flags[team]
