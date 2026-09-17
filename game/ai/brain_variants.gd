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
##   timeouts          stuck-state timeouts: options that stop producing shots or progress go on cooldown (X1; default on)
##   combat_motion     fight on the move: circle-strafe, angle the front armor, attack runs (round-3 X2, CombatMotion)
##   dodge             steer clear of incoming rounds while fighting on the move (round-3 X3, IncomingFire)
##   reload_windows    peek from cover and short-halt while a slow enemy gun reloads (round-3 X3)
##   short_halt_reload (float) guns reloading at least this long (s) halt to fire while fighting on the move (default 1.5)
##   weak_spots        seek engine decks (combat's request b): flank astern, and orbit to the stern and burst in while a
##                     slow gun reloads, when the deck lets my rounds through (TankBrain.DECK_SEEK_GAIN)
##   short_halt_lead   (float) how long (s) before the gun is loaded the halt starts, after braking (default 0.15)
##   avoid_beaten      steer manoeuvres away from walls of bullets, and suppress on purpose (round-4 X3, L2; default on)
##   suppress_proxy    SUPPRESS without matchups: "my rounds barely mark it" from penetration vs the armour it shows (round-5 X2)
##   pinned_exposed    fighting a pinned enemy from cover is worth less than going round it (round-5 X2)
##   brain_stride      (int) controller stride (round-5 X1): the whole controller, thinking and executing, runs every this
##                     many physics ticks, staggered per unit, and the tank keeps its last command in between; a new
##                     order or element call runs at once (default 1). Measured before it: holding only the steering at
##                     30 Hz ("exec_stride") saved 6% per unit and was removed.
const PROFILES := {
	# Round 1's behaviors on today's sensing (tactical cover spots, contact cap): the reference point.
	"r1": {"cover_fire": false, "retreat_to_cover": false, "hold_for_friends": false, "squad_tactics": false, "matchups": false},
	"a4": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": false, "matchups": false},
	"a6": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false},
	"a5": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": true},
	# Probe: thinking 50% less often in contact (CPU) — must not lose to a6 to be adopted.
	# Round 3 X2: a6 that keeps moving while it fights.
	"x2": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true},
	# Round 3 X3: x2 that dodges incoming rounds.
	"x3": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true},
	# Round 3 X3: x3 that times its peeks and halts to the enemy's reload.
	"x4": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true},
	# Probe for combat's round-3 weapons (preview of CP2): x3 with matchup-aware targets. Shoot-and-scoot (short_halt_lead
	# 1.2 / 2.0 s) and halting only 3 s+ reloads (short_halt_reload 3.0) were measured no better and removed.
	"x3m": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": true, "combat_motion": true, "dodge": true},
	# After CP2 (combat's request b): x4 with matchup-aware targets, seeking engine decks (the seeking needs them: a plain
	# x4 with weak_spots ran byte-identical on four ladders).
	"x4mw": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": true, "combat_motion": true, "dodge": true, "reload_windows": true, "weak_spots": true},
	# Probe (X1): a6 without stuck-state timeouts, to check they cost nothing.
	"a6nt": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "timeouts": false},
	"a6t9": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "think_ticks": SimClock.TICK_RATE * 3 / 20},
	# Round-4 X2: x4 thinking every 9 ticks in a fight instead of 6. THE CHAMPION since 2026-09-16 (see CHAMPION).
	"x4t9": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20},
	# Round-4 X3 control: the champion with L2 taken away — it neither avoids beaten zones nor fires to suppress.
	# The control for every suppression measurement, and the "before" the ladder compares against.
	# Round-5 X1: the champion running its controller at 30 Hz (every other physics tick, staggered). Half the cost by
	# construction; it has to prove it costs no behaviour (scenarios, and a ladder against x4t9) before adoption.
	"x5b2": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "brain_stride": 2},
	# Round-5 X2: the champion with both suppression gates opened (see the features above).
	"x5s": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "suppress_proxy": true, "pinned_exposed": true},
	# Round-5 X2, split after x5s went 27-37 (the proxy made the swarm army's machine-gun scouts suppress instead of
	# kill: 36k damage against 42k): x5p is only the flanker fix, x5q only the proxy.
	"x5p": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "pinned_exposed": true},
	# Round-5 X1 on the new champion: x5p with the half-rate controller.
	"x5pb2": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "pinned_exposed": true, "brain_stride": 2},
	# Round-5 reopening (the 30 Hz tick is not enough: ~85% of a 31 ms tick is the controllers). The champion thinks
	# every TICK_RATE * 3 / 20 ticks — 7.5 times a second. These think 5 and 3.75 times a second: the cost is measured
	# per second of match time, and what they cost in REACTION is measured in scenario_think_rate.gd.
	"x6t5": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "pinned_exposed": true, "think_ticks": SimClock.TICK_RATE / 5},
	"x6t4": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "pinned_exposed": true, "think_ticks": SimClock.TICK_RATE * 4 / 15},
	"x5q": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "suppress_proxy": true},
	"x4ns": {"cover_fire": true, "retreat_to_cover": true, "hold_for_friends": true, "squad_tactics": true, "matchups": false, "combat_motion": true, "dodge": true, "reload_windows": true, "think_ticks": SimClock.TICK_RATE * 3 / 20, "avoid_beaten": false},
}
## The variant brains use unless a flag picks another. Changed only when a ladder run says so.
## 2026-09-15: a6 (beat a4 9-7 in ladder run 1 and r1 7-5 in run 2; see unit_ai.md "AI ladder").
## 2026-09-15 (round 3): x3, fighting on the move (beat a6 14-10 on individuals and 17-7 on combined_arms).
## 2026-09-15 (round 3, after CP1+CP2): x4, which times its peeks and halts to the enemy's reload: it beat x3 92-68
## over two four-army ladder runs (160 matches). x4mw (matchup targets and engine decks) beat x4 93-67 over the same
## runs but is only even with x3 (48-48), is the weakest of the four on the all-armor army (29-43), and sends scouts
## onto a tank's engine deck at 3 m, which rules' catalog test says a scout must not do
## (test_units_roster::test_a_scout_keeps_an_enemy_tank_in_sight_but_out_of_its_range). It stays opt-in until rules and
## combat settle what a scout's counter is (streams/archive/round3/ai.md "Requests").
## 2026-09-16 (round 4, X2): x4t9 — the same brain thinking every 9 ticks in a fight instead of 6. It won all four
## armies of a post-CP2 ladder (individuals 13-11, armor 13-11, balanced 13-11, swarm 14-10; pooled 53-43, 96 matches)
## and costs about a fifth less CPU at 60 units (4293 usec per tick against 5327). Worth knowing that the same
## comparison BEFORE suppression landed was 48-48 with a clear loss on the all-armor army (9-15): with L2 in the
## world, and with fewer decisions each spent on better information, the slower cadence stopped hurting.
## 2026-09-17 (round 5, X2): x5p — x4t9 whose flanker goes round a pinned enemy instead of hosing it, and which keeps a
## crew it just saw pinned counted as pinned while it ducks out of sight (so a pin pulls units out of cover). It beat
## x4t9 53-43 over 96 matches on the same armies and seeds (individuals 15-9, armor 14-10, balanced 12-12, swarm 12-12):
## it wins or ties every army. The suppression proxy (x5q) was split off after x5s lost 27-37 and waits for combat's
## Lethality query.
const CHAMPION := "x5p"

static var _from_flags: Array = []


## The feature profile for `team`'s brains.
## "<id>_twin" is the same brain under another name, so the ladder can play a variant against itself (a mirror's hit
## statistics describe that one brain).
static func for_team(team: int) -> Dictionary:
	if _from_flags.is_empty():
		_from_flags = [CHAMPION, CHAMPION]
		for arg in OS.get_cmdline_user_args():
			for side in 2:
				var prefix := "--%s-brain=" % ["green", "rust"][side]
				if arg.begins_with(prefix) and PROFILES.has(arg.trim_prefix(prefix).trim_suffix("_twin")):
					_from_flags[side] = arg.trim_prefix(prefix).trim_suffix("_twin")
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
