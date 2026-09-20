class_name TankBrain
extends OrderController
## An autonomous tank: it senses through its team's shared intel, scores every
## option with its directives ("weights in a tree"), commits to the best, and
## turns that into standing orders that OrderController executes.
##
## DETERMINISM (see _agents/tank_brain.md "Determinism contract"):
##   - thinks on physics ticks (Match.tick), staggered by think_offset: never wall-clock
##   - build_situation() is the only impure step (physics queries); everything in it
##     is ordered by tank name
##   - decide(situation, current) is a pure static function: same input → same output
##   - ties go to the earlier option in OPTIONS order, then earlier target name

## K1: brains execute control's orders themselves, so control's stand-in OrderExecutor leaves them alone.
const EXECUTES_ORDERS := true
const THINK_HZ := 10.0
const THINK_EVERY_TICKS := SimClock.TICK_RATE / 10
## Think LOD (_agents/unit_ai.md §8, extended in round-4 X2), three rates by how close the fight is:
##   THINK_EVERY_TICKS       something can shoot me or I can shoot it — the micro that needs 10 Hz,
##   NEAR_THINK_EVERY_TICKS  an enemy is known within LOD_RADIUS but nothing is in reach: closing, repositioning,
##                           taking up a position. A decision 200 ms later changes nothing at that distance,
##   IDLE_THINK_EVERY_TICKS  nothing known within LOD_RADIUS.
## The rate is recomputed on every intel refresh and a brain that drops to a faster rate thinks that tick, so coming
## into range is never noticed late. Orders and element calls arrive on their own signals, so none of this delays
## them (G3, K1, L1).
const NEAR_THINK_EVERY_TICKS := SimClock.TICK_RATE / 5
const IDLE_THINK_EVERY_TICKS := SimClock.TICK_RATE * 3 / 10
const NEAR_THINK_HZ := 5.0
const IDLE_THINK_HZ := 10.0 / 3.0
const LOD_RADIUS := 130.0
## "In reach" for the fight rate: either gun's range plus this (meters).
const FIGHT_MARGIN := 15.0
## The current choice gets this multiplier, so near-equal options don't flip-flop. Round 8 (the lead: "they seem to just
## move back and forth indefinitely"): 1.35 halves the churn (`make squad-decisions`, laptop, yard, seeds 1/3/7:
## switches/reversals per unit-min 18.1/0.30 at 1.15, 12.7/0.17 at 1.35, 12.1/0.27 at 1.60) and a 48-match ladder said
## "does not lose" — but two BEHAVIOUR scenarios say it does: a squad stops concentrating its fire (focus share 69% vs
## brains-alone 69%, i.e. squad tactics buy nothing) and a scout stops working onto engine decks (41 hits/23 on the deck
## → 3/0), because a crew that sticks harder no longer switches onto its squad's focus or into an orbit. A ladder cannot
## see either. So the default stays 1.15 and the lever lives on as variant `x5c`; the churn fix has to come from
## somewhere that does not cost target choice.
const COMMIT_BONUS := 1.15
## A crew being suppressed stays worth suppressing down to this fraction of the pin threshold (hysteresis on `pinned`).
const PIN_HOLD_FRACTION := 0.75
## N5 (CP4): the longest a peek from cover is held waiting for the gunner's lay (Engagement.ACQUIRE_FAR_SECONDS is 1.6 s).
const PEEK_COMMIT_TICKS := SimClock.TICK_RATE * 2
## ...and it's kept at least this long unless something is EMERGENCY_MARGIN× better.
const MIN_COMMIT_TICKS := SimClock.TICK_RATE * 3 / 4
## Round 7 (make squad-decisions): the thrash shape is A -> B -> A — going straight back to what it just left (mostly a
## target flip inside ENGAGE, and ENGAGE <-> SUPPRESS / CLEAR_LANE). For REVISIT_S after leaving an option+target,
## returning to it scores REVISIT_FACTOR: it has to be clearly better, not a hair better. Seconds off the fixed tick.
const REVISIT_S := 3.0
const REVISIT_FACTOR := 0.85
const EMERGENCY_MARGIN := 1.6
## Contacts older than this are investigated rather than engaged.
const CONTACT_FRESH_TICKS := SimClock.TICK_RATE * 2
## Tactical queries (TacticalQuery) are re-run at most this often per tank unless the situation changed.
const QUERY_EVERY_TICKS := SimClock.TICK_RATE / 2
## ...or this far from where the last one was asked (meters).
const QUERY_MOVED := 6.0
## Hiding places are searched this far around a tank (meters)...
const COVER_SEARCH_RADIUS := 30.0
## ...and only by tanks that might use them: worn below this fraction of hull + shield, or shield down.
const COVER_QUERY_TOUGHNESS := 0.8
## A brain reasons about its nearest this-many contacts (plus its current target and any artillery): the
## situation's cost grows with contacts, and a far enemy never outranks a near one anyway.
const MAX_CONTACTS := 8
## A retreating tank that's in a gun's sight first breaks line of sight at cover this close (meters), then withdraws.
const RETREAT_COVER_DISTANCE := 25.0
## COVER_FIRE is worth nothing to a gun reloading this fast or faster (seconds): decide() scores it 0 there.
const COVER_FIRE_RELOAD_FLOOR := 0.4
## COVER_FIRE (A3): hide and peek spots count as reached within this distance (meters).
const SPOT_ARRIVE := 1.0
## ...peek when the gun will be loaded by the time the tank gets there, driving at about this speed (m/s),
const PEEK_SPEED := 5.0
## ...and only with at least this much shield left (fraction).
const PEEK_SHIELD := 0.35
## A COVER_FIRE query stays valid while the tank is this close to its hide spot and the target this close to
## where it was (meters), and the target still can't see the hide spot.
const COVER_FIRE_KEEP := 12.0
## A4: a gun held this many ticks for a friend in the line of fire makes the brain move to clear the lane.
const LANE_BLOCKED_TICKS := SimClock.TICK_RATE / 3
## How far CLEAR_LANE looks for a new firing spot (meters).
const LANE_SEARCH := 10.0
## A6 squad tactics: how much more a brain wants the squad's focus, an enemy shooting a retreating squad-mate
## it was asked to cover, and an enemy near the team's artillery or Lancers.
const FOCUS_BONUS := 1.25
const COVER_TEAMMATE_BONUS := 1.4
const FRAGILE_THREAT_BONUS := 1.15
## The flanker's FLANK floor (× confidence × firepower) on the squad's focus.
const FLANKER_APPETITE := 0.72
## A5 matchups: a fixed-gun unit circles a turret that turns slower than this orbit sweeps (radius in meters, its
## speed / radius = the angular speed it forces on the turret), bursting in when that turret points away.
const ORBIT_RADIUS := 11.0
## Combat's request (b), weak spots: a gun that gets at least this much more through a target's engine deck than its
## rear plate (Matchups.deck_gain: a scout's machine gun on a tank, ×1.8) circles to its stern before bursting in.
## (Two other ways of seeking the deck were measured and dropped: attack runs that circle to the stern first cost a scout
## on a Lancer 37 rounds -> 24 and 6 deck hits -> 2, since a straight run's break-away already passes astern; and FLANK
## coming in astern never fires — flankers pick ENGAGE with combat motion instead, so four ladders and an IFV-pair
## scenario ran byte-identical with and without it.)
const DECK_SEEK_GAIN := 1.4
## An orbiting fixed gun bursts in while the target's gun needs at least this long to reload (seconds), wherever it points.
const ORBIT_RELOAD_WINDOW := 1.0
## cos 45° astern (Armor.ARC_DEG): inside it I see the target's rear.
const COS_ASTERN := 0.70710678
## ...when the estimated duel advantage is at least ORBIT_START_ADVANTAGE, and keeps orbiting down to ORBIT_KEEP_ADVANTAGE.
const ORBIT_START_ADVANTAGE := 0.9
const ORBIT_KEEP_ADVANTAGE := 0.6
## A SUPPRESS nobody else is served by scores at most this fraction of the best winnable ENGAGE (round 7).
const SUPPRESS_UNDER_WINNABLE := 0.95
## ...bursts in when the target's gun is more than 60° off it (cos 0.5) and it's this close...
const ORBIT_BURST_RANGE := 30.0
const ORBIT_BURST_COS := 0.5
## ...and swings back out when the gun comes within ~37° (cos 0.8) or it's this close.
const ORBIT_BREAK_COS := 0.8
const ORBIT_BREAK_RANGE := 5.0
## cos and sin of 75°: the orbit steers at a point this far ahead on the circle (constants, no runtime trig); far
## enough ahead (~13 m) that steering doesn't slow down for arrival.
const ORBIT_LEAD_COS := 0.259
const ORBIT_LEAD_SIN := 0.966
const ARENA_LIMIT := Match.DRIVABLE_LIMIT
const OPTIONS := ["RETREAT", "RESUPPLY", "TAKE_COVER", "RECHARGE", "SPOT", "BOMBARD", "SHADOW", "CONTEST", "CLEAR_LANE", "ORBIT", "COVER_FIRE", "SUPPRESS", "ENGAGE", "FLANK", "INVESTIGATE", "REGROUP", "ADVANCE", "KEEP_SLOT", "HOLD"]
## Options only a K1 order produces (TankBrain._obey adds them): MOVE (drive to the order's slot), FOLLOW (keep station
## on a friend), PURSUE (close in on an ordered target that's out of sight).
const ORDER_ONLY_OPTIONS := ["MOVE", "FOLLOW", "PURSUE"]
## K1 orders (round-3 X1, _agents/unit_ai.md "Orders always win"): which options each verb leaves the brain. The
## player decides WHAT; these options only decide HOW. "idle" = no order now, but one earlier: the unit keeps
## the post its last order left it at.
const ORDER_OPTIONS := {
	"move": ["MOVE"],
	"stop": ["MOVE"],
	"hold": ["HOLD"],
	"follow": ["FOLLOW"],
	"attack": ["ENGAGE", "COVER_FIRE", "FLANK", "ORBIT", "CLEAR_LANE", "BOMBARD", "SUPPRESS", "PURSUE"],
	"attack_move": ["MOVE", "ENGAGE", "COVER_FIRE", "FLANK", "ORBIT", "CLEAR_LANE", "BOMBARD", "SUPPRESS", "TAKE_COVER", "RECHARGE", "RETREAT"],
	"idle": ["RETREAT", "RESUPPLY", "TAKE_COVER", "RECHARGE", "SPOT", "BOMBARD", "CLEAR_LANE", "ORBIT", "COVER_FIRE",
			"SUPPRESS", "ENGAGE", "FLANK", "INVESTIGATE", "ADVANCE", "HOLD"],
}
## Attack-move: driving on scores this, so any real fight on the way (ENGAGE ~0.6-0.9) comes first.
const ATTACK_MOVE_WEIGHT := 0.55
## ...because a fight with a visible enemy within weapon range + ATTACK_MOVE_REACH_MARGIN gets this added.
const ATTACK_MOVE_FIGHT := 0.5
const ATTACK_MOVE_REACH_MARGIN := 10.0
## A move or attack-move counts as done within this distance of the unit's slot (meters)...
const ORDER_ARRIVE := 3.5
## (Round 6, nav: there is no "close enough after a stall" any more. Round 5 completed a stalled move from up to 12 m away,
## which is what made a jammed horde look like it had decided to stop. An order completes when the unit arrives; a unit
## that cannot says so through Movement.state() — phase "blocked", and what blocks it — and keeps trying.)
## ...and for wheeled units within Movement.settle_radius (see _order_arrive).
## A stop order is done once the unit is slower than this (m/s).
const STOPPED_SPEED := 0.5
## ...no sooner than this many ticks after it was issued.
const STOP_SETTLE_TICKS := SimClock.TICK_RATE / 3
## A hold order keeps the unit this close to its spot (meters).
const HOLD_TOLERANCE := 3.0
## An idle unit fights near its post and returns when it drifts farther than this (regroup)...
const IDLE_LEASH := 30.0
## ...and a unit a PLAYER put somewhere never drives further than this from that post on its own (the lead, 2026-09-17:
## *"if they get sucked into combat I have no control whatsoever"*). It fights, circles, peeks and takes cover inside the
## circle; only the player moves it out of it. A move that IS an escape (running to cover, breaking contact) is exempt,
## and so is everything the player orders — a player's order has no leash at all.
const PLAYER_POST_LEASH := 18.0
## Lesson 47: options that move a held player unit back where it belongs, options that may move it only under fire, and
## how recently it must have been hit (or have a round inbound) to count as under fire.
const HELD_RETURNS := ["REGROUP", "HOLD", "KEEP_SLOT"]
const HELD_UNDER_FIRE_MOVES := ["TAKE_COVER", "COVER_FIRE", "RETREAT", "RECHARGE", "RESUPPLY"]
const HELD_UNDER_FIRE_TICKS := SimClock.TICK_RATE * 3
## ...with this much more rope for a move that IS the escape (running to cover, breaking contact).
const ESCAPE_LEASH_FACTOR := 2.0
## Follow: station this far behind the friend (meters).
const FOLLOW_DISTANCE := 10.0
## No stuck states: an autonomous option kept this long (ticks) goes on cooldown; for the fighting options the
## clock restarts with every shot, so only a fight that stopped producing shots times out.
const OPTION_TIMEOUT_TICKS := {"COVER_FIRE": SimClock.TICK_RATE * 10, "CLEAR_LANE": SimClock.TICK_RATE * 5,
	"TAKE_COVER": SimClock.TICK_RATE * 12, "RECHARGE": SimClock.TICK_RATE * 12, "ORBIT": SimClock.TICK_RATE * 15,
	"SUPPRESS": SUPPRESS_TIMEOUT_TICKS,
		"FLANK": SimClock.TICK_RATE * 15, "INVESTIGATE": SimClock.TICK_RATE * 20, "RETREAT": SimClock.TICK_RATE * 20,
		"RESUPPLY": SimClock.TICK_RATE * 40, "BOMBARD": SimClock.TICK_RATE * 15, "ENGAGE": SimClock.TICK_RATE * 15}
const FIGHT_OPTIONS := ["COVER_FIRE", "ORBIT", "FLANK", "BOMBARD", "ENGAGE", "CLEAR_LANE", "SUPPRESS"]
## ...and a move goal with no progress for this many ticks puts the option on cooldown too.
const STALL_TICKS := SimClock.TICK_RATE * 3
## X2 combat motion: fight on the move when the target is visible and within weapon range + this (meters)...
const MOTION_REACH_MARGIN := 15.0
## ...hulls with at least this much front armor angle it toward the target instead of circling side-on...
const ANGLE_FRONT_ARMOR := 6.0
## ...keeping the front toward at most this many visible guns (nearest, the ones aimed at it first).
const MOTION_THREATS := 4
## cos 45° (Armor.ARC_DEG) and cos 12° (a gun this close to pointing at me is aimed at me), as constants.
const COS_ARMOR_ARC := 0.70710678
const COS_AIMED_AT_ME := 0.9781476
## cos 20°: a gun last seen pointing this close to me is watching for me (reload windows).
const COS_WATCHING := 0.9396926
## X4: a flanker still in front of its target (within ~60° of its nose) aims this much wider (meters).
const FLANK_WIDE_COS := 0.5
const FLANK_WIDE_EXTRA := 20.0
## ...and re-plans the move at most this often (ticks) while nothing changed.
const MOTION_REPLAN_TICKS := SimClock.TICK_RATE / 4
## ...and a jink flips the circling side no sooner than JINK_MIN_TICKS after the last, and no later than
## JINK_MIN_TICKS + JINK_SPREAD_TICKS (per unit, so a group doesn't jink in step).
const JINK_MIN_TICKS := SimClock.TICK_RATE * 3 / 2
const JINK_SPREAD_TICKS := SimClock.TICK_RATE * 5 / 2
## Circling units jink only within this distance of their target (meters).
const JINK_RANGE := 50.0
## A unit this far outside its target's weapon range (and inside its own) holds still and shoots (meters).
const OUTRANGE_MARGIN := 4.0
## A fixed gun's run slows to this throttle inside its weapon's range.
const RUN_FIRING_SPEED := 0.65
## ...once its nose is within ~20° of the target (cos).
const RUN_AIMED_COS := 0.94
## ...and guns reloading at least SHORT_HALT_RELOAD seconds halt to fire: braking starts this long (s) before the gun is
## loaded, and a halt lasts at most SHORT_HALT_MAX_TICKS after it is (a gun that can't get a shot off moves on).
const SHORT_HALT_RELOAD := 1.5
const SHORT_HALT_LEAD := 0.15
const SHORT_HALT_MAX_TICKS := SimClock.TICK_RATE
## X3 reload windows: guns reloading at least this long (seconds) are worth timing; a peek or a halt shows the unit for
## about PEEK_EXPOSURE / SHORT_HALT_EXPOSURE seconds, so it waits (at most PEEK_PATIENCE_TICKS) for a reload that long.
const SLOW_GUN_RELOAD := 1.5
const PEEK_EXPOSURE := 1.5
const SHORT_HALT_EXPOSURE := 0.8
const PEEK_PATIENCE_TICKS := SimClock.TICK_RATE * 4
## A target fought from cover stays fresh this long out of sight (a slow reload plus a margin).
const COVER_FIRE_MEMORY_TICKS := SimClock.TICK_RATE * 8
## A bait shows the unit for at most BAIT_OUT_TICKS (or until the target can see it), then ducks back for BAIT_BACK_TICKS
## (a shell's flight plus a margin), at most MAX_BAITS times before a real peek.
const BAIT_OUT_TICKS := SimClock.TICK_RATE * 5 / 6
## N5 (CP4): once seen, a bait waits for the watching gunner's lay and the shot, ducking when the round is inbound, and
## never shows itself longer than this (Engagement.ACQUIRE_FAR_SECONDS is 1.6 s).
const BAIT_SEEN_MAX_TICKS := SimClock.TICK_RATE * 2
const BAIT_BACK_TICKS := SimClock.TICK_RATE
const MAX_BAITS := 2
## Cooldown length (ticks) and what an option on cooldown scores (× its score).
const COOLDOWN_TICKS := SimClock.TICK_RATE * 5
const COOLDOWN_FACTOR := 0.25
## Within this distance of its formation slot a tank counts as "in position".
const SLOT_TOLERANCE := 4.0
## Shield down, a gun on me, and the hull below this fraction: break contact to recharge (G6).
const SHIELD_DOWN_BREAK_HP := 0.75
## RECHARGE continues until the shield is back to this fraction.
const RECHARGED := 0.6
## How far RECHARGE backs off when there's no cover nearby.
const RECHARGE_BACKOFF := 25.0
## A tank at base stays until its hull is back to this fraction (G6 repair).
const REPAIR_TOP_UP := 0.9
## A tank at full heat fights with this fraction of its usual appetite (scaled in from 70% heat).
const HOT_FIREPOWER := 0.75
## A tank in its base's resupply zone stays until its ammo is back to this fraction.
const RESUPPLY_TOP_UP := 0.8
## Scouts keep known enemies about this far away: outside a cannon's 70 m, inside their own 110 m sight.
const SCOUT_STANDOFF := 85.0
## Artillery keeps visible enemies at least this far away (outside a cannon's 70 m reach).
const ARTILLERY_SAFE_DISTANCE := 80.0
## A lone unit advancing with no objective swings this far to the right of the base-to-base line (meters).
const LONE_LANE := 25.0
const LONE_LANE_REACHED := 8.0
## With nothing to shell, artillery trails this far behind the nearest friendly gun, toward home.
const ARTILLERY_TRAIL := 35.0
## A scout's appetite for attacking enemy artillery, relative to a tank's normal appetite.
const SCOUT_HUNT := 1.6
const SCOUT_HUNT_FLOOR := 0.8
## A scout's appetite for a straight fight, relative to a tank's.
const SCOUT_FIGHT := 0.6
## KEEP_SLOT's score under move/bound/hold orders (see decide()).
const ORDER_WEIGHT := 0.95
## Under orders (not assault), RETREAT only below this health fraction, scaled by caution.
const CRITICAL_HP_MIN := 0.08
const CRITICAL_HP_MAX := 0.25
## A remembered contact's position is extrapolated along its last velocity for at most this long.
const WATCH_PREDICT_SECONDS := 1.5
## L2 suppression (round-4 X3). A pinned crew cannot shoot straight (combat measured 5 hits of 13 against 13 of 13),
## so the answer is to get out of the fire, not to trade: TAKE_COVER scores at least this much while pinned...
const PINNED_COVER := 0.85
## ...and RETREAT's health threshold is raised by this much, so a hurt pinned unit leaves earlier than a calm one.
const PINNED_RETREAT_HP := 0.15
## An enemy whose crew is pinned is a worse shooter: worth this much more to flank, and counted as this much less of
## a threat when deciding whether to stay.
const PINNED_FLANK_BONUS := 1.5
const PINNED_THREAT_FACTOR := 0.5
## X2 (round 5, BrainVariants "suppress_proxy"): without matchups, a target counts as "killing this is slow going" when
## my weapon's penetration against the armour it shows me gets this share of the damage through or less
## (Matchups.penetration_multiplier, the Armor rule): a machine gun on a tank's front is x0.05, on its side x0.13, on a
## scout's plate x0.6; a cannon on a tank's front x0.5.
const SUPPRESS_PENETRATION := 0.25
## X2 ("pinned_exposed"): COVER_FIRE against a pinned target is worth this share of its usual score.
const PINNED_COVER_FIRE := 0.5
## SUPPRESS: how much of ENGAGE's appetite putting rounds on an enemy I can't kill quickly is worth...
const SUPPRESS_WEIGHT := 0.78
## ...and the kill rate (relative to my best target) below which killing isn't the point any more.
const SUPPRESS_KILL_RATIO := 0.45
## A suppressing unit holds its fire on a target no longer than this without the target's suppression rising.
const SUPPRESS_TIMEOUT_TICKS := SimClock.TICK_RATE * 7
## Where fire goes once the target ducks out of sight: its last position, led this many seconds along its last
## velocity — the ground it is behind, not where it was standing.
const SUPPRESS_LEAD_SECONDS := 0.6
## Suppressing fire holds ONE aim point rather than tracking. Combat measured why (balance.md): a round stamps the
## cells it flew through, so a gun streaming at a fixed point piles its stamps into one cell — a single machine gun at
## 39 m reads 1.17 density that way, against 0.78 from two guns chasing a moving unit at 36 m. Chasing a target
## spreads the fire out and suppresses nobody. The point is re-laid only when the target has left it by this much...
const SUPPRESS_REAIM := 7.0
## ...or after this long (ticks), so the fire follows a walking target without following a jinking one.
const SUPPRESS_REAIM_TICKS := SimClock.TICK_RATE * 3 / 2
## L1 elements (round-4 X1): a unit fighting from a formation slot manoeuvres inside this far of it (meters). About
## one formation spacing: room to circle, jink and take an angle without leaving the formation.
const SLOT_LEASH := 14.0
## ...and engages inside its sector of fire first (ElementFeed.SECTOR_COS).
const SECTOR_COS := ElementFeed.SECTOR_COS

## Measurement only (make ai-perf, while OrderController.profiling): microseconds per part of thinking. Never read by
## decisions.
static var profile_parts := {}

var game_match: Match
## Fully resolved directives (Directives.resolve).
var directives: Dictionary = Directives.DEFAULTS.duplicate(true)
var squad_name := ""
var think_offset := 0
## {"option": String, "target": String, "since": int}; empty before the first think.
var choice := {}
## Top scored options from the last think: [{"option", "target", "score"}], best first.
var ranked: Array = []
## The squad order_serial this brain last acted on.
var _order_serial := 0
## How often this brain thinks right now, in thinks per second (think LOD), the tick it is next due, and the fraction of
## a tick carried over — so a rate the tick rate can't divide (the champion's 6.67/s is 4.5 ticks at 30 Hz) is kept
## exactly instead of being rounded up into 12% more thinking, which is what integer division did when the simulation
## moved to 30 Hz.
var _think_hz := THINK_HZ
var _next_think_tick := -1
var _think_debt := 0.0
## A few words on why the current choice (phase, squad role), shown after the option on nameplates.
var why := ""
## The last cover query: {"tick", "position", "threats" (count), "result" [Vector3]}.
var _cover_cache := {}
## Bounding overwatch (A6): {"goal": the bound goal it was chosen for, "spot": Vector3}.
var _overwatch := {}
## ORBIT's phase: driving at the target (true) or circling it (false).
var _bursting := false
## CLEAR_LANE's chosen spot and when it was chosen (kept until reached or stale, so the tank settles to fire).
var _lane_goal: Variant = null
var _lane_goal_tick := 0
## The last COVER_FIRE query: {"tick", "target" (name), "target_position", "result" ({hide, peek, target} or {})}.
var _cover_fire_cache := {}
## N5: the tick the current real peek began (-1 = not peeking); a peek is held until the gun fires (PEEK_COMMIT_TICKS).
var _peek_tick := -1
## Lesson 47: the in-place alternative for a held player unit this think (face the nearest threat, or stop), whether it
## counts as under fire, and how many move orders the hold rule has refused (tests assert the MECHANISM with this).
var _held_face := {"type": "stop"}
## Round 8: face orders turned into a stop because the turret carries the aim (turret_carries_aim), for tests and probes.
var faces_declined := 0
var _held_under_fire := false
var held_moves_refused := 0
## Round 7: the option+target this brain last LEFT, and when ({} = none): decide() makes flipping straight back harder.
var _left := {}
## X3: the ground SUPPRESS is hosing (null = none), which target it was laid for, and when.
var _suppress_point: Variant = null
var _suppress_for := ""
var _suppress_tick := 0
## K1: the unit's current order (OrderFeed.normalize shape, {} = none), its identity, and the post the last
## finished order left it at (null = never ordered: doctrine and squad behavior as before).
var order := {}
var _order_key := ""
var _order_dirty := false
## The key of the order this brain reported complete (so it reports it once).
var _finished_key := ""
var _order_home: Variant = null
## Where a player left this unit (null = no player commands this side, or it has never been ordered): the centre of the
## circle it keeps to while it has no order of its own.
var _player_post: Variant = null
var _order_source: Object = null
## L1: this unit's element context (ElementFeed.context shape, {} = no element, so nothing below changes anything for
## a unit that isn't in one), and its source.
var element := {}
var _element_source: Object = null
var _element_dirty := false
## Whether the order and element sources publish their change signals (asked once per source, not every tick).
var _order_signals := false
var _element_signals := false
## Option name → tick its cooldown ends (stuck-state timeouts).
var cooldowns := {}
## X2 combat motion: which way around the target (+1/-1, 0 = not chosen yet), when the next jink may flip it, and a
## fixed gun's run phase ("run" in, "extend" out).
var _strafe_side := 0
## X3: how many rounds were on their way at the last look (a new one triggers a think).
var _incoming_count := 0
## The tick the gun became loaded (-1 while reloading), for the short halt.
var _loaded_tick := -1
## X3 reload windows: the tick COVER_FIRE started waiting in cover (-1 = not waiting).
var _hiding_since := -1
## ...and its bait: "" (none), "out" (showing itself), "back" (ducking the shot), since _bait_tick; baits since the last peek.
var _bait_phase := ""
var _bait_tick := 0
var _baits := 0
## The tick a bait first saw the target (it's in the open), -1 before.
var _bait_seen := -1
## The last CombatMotion plan: {"tick", "key", "why", "order"} (reused for MOTION_REPLAN_TICKS).
var _motion_cache := {}
var _jink_tick := 0
var _run_phase := "run"
## Round 7 (nav): the direction CombatMotion chose last plan, handed back so it can commit to it.
var _motion_prev_index := -1
var _motion_prev_reverse := false


func think(_delta: float) -> void:
	if game_match == null or tank == null:
		return
	if not spotter.is_valid():
		# Indirect fire aims at anything the TEAM can see (directive set 2: spotting).
		spotter = func(other: Tank) -> bool: return game_match.is_visible_to(tank.team, other)
		AiExplainOverlay.ensure(game_match)  # --ai-explain (playtests): lines showing what each brain is up to
	if not tank.is_alive():
		choice = {}
		tank.intent = ""
		return
	_stride = maxi(1, int(BrainVariants.for_team(tank.team).get("brain_stride", 1)))
	# X3: a side run by doctrine from the command line (--green-elements / --rust-elements, TacticsFlags).
	TacticsFlags.ensure(game_match)
	var pre := Time.get_ticks_usec() if OrderController.profile_detail else 0
	# The player's own units wait for orders (round 5). A brain that has never been given one normally falls back on its
	# doctrine directives, which send it at the enemy base — so the lead's army left before he could command it. Taking
	# its spawn as the post it was left at makes it behave exactly like a unit whose order finished here: it holds,
	# fights what comes to it, and returns to its place, until the player says otherwise. The CPU is unaffected.
	if _order_home == null and tank.team == OrderFeed.player_team(game_match):
		_order_home = _flat(tank.global_position)
	# A new squad order is thought about on the very next tick and breaks commitment (G3).
	var squad := game_match.squad_for(tank)
	var serial := squad.order_serial if squad != null else 0
	var fresh_order := serial != _order_serial
	_order_serial = serial
	# K1 response guarantee: a new player order is taken up on this very tick, whatever the brain was doing.
	# Under a controller stride a brain can only think on a tick that runs, so the next-due tick is at least a stride away.
	var think_tick := _due_to_think()
	if _poll_order(think_tick):
		fresh_order = true
		interrupt()
	# L1 (X1): the element leader's call — a halt, a new drill, a change of role — is acted on the same tick too.
	if _poll_element(think_tick):
		fresh_order = true
		interrupt()
	# ...and once it is standing where the player put it, that place is its post until the player says otherwise. Decided
	# AFTER this tick's order has been read: deciding it before would leash the player's own order to the post it is
	# meant to replace.
	if tank.team == OrderFeed.player_team(game_match) and order.is_empty():
		var station: Variant = OrderFeed.station(_order_source, String(tank.name))
		_player_post = station if station != null else _order_home
	else:
		_player_post = null
	pre = _lap("t.poll", pre)
	# X3: a new round on its way at a unit fighting on the move gets a look right away (a 70 m/s shell from 50 m
	# arrives in 43 ticks; waiting up to 6 for the next think wastes the dodge).
	if not think_tick and not fresh_order and _dodges() and FIGHT_OPTIONS.has(choice.get("option", "")):
		var count := IncomingFire.count_for(game_match, tank)
		think_tick = count > _incoming_count
		_incoming_count = count
	pre = _lap("t.incoming", pre)
	# Think LOD wake-up: every intel refresh, re-rate how close the fight is. Dropping to a faster rate (an enemy
	# came near, or came into reach) means thinking on this very tick, so nothing is noticed late.
	if game_match.tick % Match.INTEL_EVERY_TICKS < _stride:
		var rate := _think_rate()
		if rate > _think_hz:
			fresh_order = true
			think_tick = true
		_think_hz = rate
	# Finishing an order is not a decision and must not wait for one: a target dying, or arriving at a slot, is an
	# event, and with the champion thinking every 9 ticks a completion could sit unreported for 150 ms (round-4 X2
	# made that visible — control's "the attack order completes when the target dies" allows 3 ticks). Cheap: a
	# distance check and a name lookup.
	_update_order_progress()
	pre = _lap("t.rate_progress", pre)
	if not fresh_order and not think_tick:
		return
	# No stuck states: an option that stopped producing shots or progress goes on cooldown, and commitment to it ends.
	var timed_out := _timed_out()
	if timed_out != "":
		cooldowns[timed_out] = game_match.tick + COOLDOWN_TICKS
		fresh_order = true
	var clock := Time.get_ticks_usec() if OrderController.profiling else 0
	if think_tick:
		_schedule_think()
	var situation := build_situation()
	if fresh_order:
		_left = {}  # a new order is a new question: nothing to flip back to
	situation["left"] = _left
	if OrderController.profiling:
		profile_parts["situation"] = int(profile_parts.get("situation", 0)) + Time.get_ticks_usec() - clock
		clock = Time.get_ticks_usec()
	_think_hz = _think_rate()
	var decision := TankBrain.decide(situation, {} if fresh_order else choice)
	if OrderController.profiling:
		profile_parts["decide"] = int(profile_parts.get("decide", 0)) + Time.get_ticks_usec() - clock
		clock = Time.get_ticks_usec()
	ranked = decision["ranked"]
	var best: Dictionary = decision["choice"]
	var same: bool = best["option"] == choice.get("option") and best["target"] == choice.get("target")
	if not same and not choice.is_empty():
		_left = {"option": choice["option"], "target": choice["target"], "tick": game_match.tick}
	best["since"] = choice["since"] if same else game_match.tick
	choice = best
	_act(situation)
	if OrderController.profiling:
		profile_parts["act"] = int(profile_parts.get("act", 0)) + Time.get_ticks_usec() - clock
	watch_point = TankBrain.watch_for(situation, choice)
	tank.intent = TankBrain.label(choice) + ("" if why == "" else " - " + why)


# ---- K1 orders (round-3 X1) ---------------------------------------------------------

## Reads this unit's order from the match's Orders (OrderFeed). True when it changed since the last poll. Polled on
## every think tick and whenever order_changed named this unit (every tick if the source has no signal).
func _poll_order(think_tick: bool) -> bool:
	var feed := AiTickCache.order_source(game_match)
	if feed != _order_source:
		_order_source = feed
		_order_dirty = true
		_order_signals = feed != null and feed.has_signal("order_changed")
		if _order_signals and not feed.is_connected("order_changed", _on_order_changed):
			feed.connect("order_changed", _on_order_changed)
	if feed == null or not (_order_dirty or think_tick or not _order_signals):
		return false
	_order_dirty = false
	var now := OrderFeed.current(feed, String(tank.name))
	var now_key := OrderFeed.key(now)
	if now_key == _order_key:
		return false
	var finished := _order_key != "" and _order_key == _finished_key
	_order_key = now_key
	if now.is_empty() and not finished:
		_order_home = _flat(tank.global_position)  # cleared before it was done: stay where it stopped
	order = now
	if order.is_empty():
		return true
	if _order_home == null:
		_order_home = _flat(tank.global_position)
	if order["goal"] == null and ["hold", "move", "attack_move", "stop"].has(order["verb"]):
		order["goal"] = _flat(tank.global_position)  # hold or stop here (a move with nowhere to go holds too)
		if order["verb"] == "move" or order["verb"] == "attack_move":
			order["verb"] = "hold"
	return true


## Controller stride: whether something arrived that must be acted on this very tick rather than on this unit's next
## turn (a new K1 order or an element call; both arrive on signals).
func wants_to_run() -> bool:
	return _order_dirty or _element_dirty


func _on_order_changed(unit_name: String) -> void:
	if tank != null and unit_name == String(tank.name):
		_order_dirty = true


# ---- L1 elements (round-4 X1) -------------------------------------------------------------

## Reads this unit's element context from the match's Elements (ElementFeed). True when the leader's call changed
## since the last poll (`key`), which is what must reach the hull the same tick. Slot positions move with the leader
## and are simply refreshed.
func _poll_element(think_tick: bool) -> bool:
	var feed := AiTickCache.element_source(game_match)
	if feed != _element_source:
		_element_source = feed
		_element_dirty = true
		_element_signals = feed != null and feed.has_signal("element_changed")
		if _element_signals and not feed.is_connected("element_changed", _on_element_changed):
			feed.connect("element_changed", _on_element_changed)
	if feed == null or not (_element_dirty or think_tick or not _element_signals):
		return false
	_element_dirty = false
	# The verb of the order my leader gave me is part of reading the element: under bounding overwatch the half told
	# to move is the one bounding, and the half told to hold is covering it (ElementFeed._role).
	var now := ElementFeed.context(feed, String(tank.name), String(order.get("verb", "")))
	var call_changed := ElementFeed.changed(element, now)
	element = now
	return call_changed


## Elements publishes `element_changed(id: int)`; a stub may name it with a string. Either way it only matters
## whether it is mine.
func _on_element_changed(id: Variant) -> void:
	# str(), not String(): the id arrives as an int from Elements and String() has no Variant constructor.
	if element.is_empty() or str(id) == str(element.get("id", "")):
		_element_dirty = true


## The order is done: remember the post it leaves the unit at (idle units regroup there) and tell Orders.
func _finish_order(home: Vector3) -> void:
	if _order_key == "" or _finished_key == _order_key:
		return
	_finished_key = _order_key
	_order_home = _flat(home)
	OrderFeed.complete(_order_source, String(tank.name))


## Completes move and attack-move on arrival (or near a slot it can't reach), attack when the target is gone, follow
## when the friend is. Hold never completes.
func _update_order_progress() -> void:
	if order.is_empty():
		return
	var here := tank.global_position
	match String(order["verb"]):
		"move", "attack_move":
			var goal: Vector3 = order["goal"]
			var distance := _flat(here).distance_to(goal)
			# An attack-move is done when it's there and nothing is left to shoot (control's rule).
			var fighting: bool = order["verb"] == "attack_move" and engaged_target != ""
			var arrive := _order_arrive()
			if not fighting and distance <= arrive:
				_finish_order(goal)
		"stop":
			# Stopped, and stopped for a moment (a unit that had barely started moving would finish at once).
			if tank.estimated_velocity.length() < STOPPED_SPEED and game_match.tick - int(order["issued_tick"]) >= STOP_SETTLE_TICKS:
				_finish_order(here)
		"attack", "follow":
			var other := AiTickCache.tanks_by_name(game_match).get(String(order["target"])) as Tank
			if other == null or not other.is_alive():
				_finish_order(here)


## The option to put on cooldown now, or "": kept past its OPTION_TIMEOUT_TICKS (fights: since the last shot), or
## driving toward a goal without progress for STALL_TICKS. Options that carry out a player order never time out.
func _timed_out() -> String:
	if choice.is_empty() or not BrainVariants.for_team(tank.team).get("timeouts", true):
		return ""
	var option: String = choice["option"]
	if ["MOVE", "FOLLOW", "PURSUE", "HOLD", "KEEP_SLOT"].has(option):
		return ""
	var started := int(choice.get("since", game_match.tick))
	if FIGHT_OPTIONS.has(option):
		started = maxi(started, game_match.tick - ticks_since_fire)
	var limit := int(OPTION_TIMEOUT_TICKS.get(option, 0))
	if limit > 0 and game_match.tick - started > limit:
		return option
	if stalled_ticks >= STALL_TICKS and move_order.get("type") == "move_to":
		return option
	return ""


## What the player's order means for decide(), or null for a unit that has never had one:
## {"verb" (an ORDER_OPTIONS key), "goal": Vector3 | null, "target": String, "speed", "target_alive": bool,
##  "target_position", "target_forward", "target_velocity" (Vector3 | null)}.
func _order_context() -> Variant:
	if _order_home == null:
		return null
	if order.is_empty():
		var post: Variant = OrderFeed.station(_order_source, String(tank.name))
		return {"verb": "idle", "goal": post if post != null else _order_home, "target": "", "speed": 1.0,
				"target_alive": false, "target_position": null, "target_forward": null, "target_velocity": null}
	var context := {"verb": order["verb"], "goal": order["goal"], "target": order["target"], "speed": order["speed"],
			"target_alive": false, "target_position": null, "target_forward": null, "target_velocity": null}
	# Live values: a follow's station moves with the friend, and a group's pace changes as it closes up.
	if _order_source != null:
		if order["verb"] == "follow":
			context["goal"] = OrderFeed.point(_order_source.call("goal_position", String(tank.name))) \
					if _order_source.has_method("goal_position") else null
		if _order_source.has_method("pace_factor"):
			context["speed"] = clampf(float(_order_source.call("pace_factor", String(tank.name))), 0.2, 1.0)
	# L1 (X1): the leader's call outranks the movement order it issued earlier. Told to stop bounding — to become the
	# overwatch half or the base of fire — this unit halts where it stands and fights from there, the same tick,
	# without waiting for a fresh K1 order. Told to bound, it rushes: a bound is a sprint between covered positions.
	if ElementFeed.is_firing_base(element) and ["move", "attack_move"].has(String(context["verb"])):
		context["verb"] = "hold"
		context["goal"] = _flat(tank.global_position)
	elif String(element.get("role", "")) == "bound":
		context["speed"] = 1.0
	elif not element.is_empty() and ["move", "attack_move"].has(String(context["verb"])):
		# X3: my leader paces me so the element arrives together (FormUp: the lead's form-up formula). A unit the
		# player has taken off its element has no slot there, so it reads a pace of 1.
		context["speed"] = clampf(minf(float(context["speed"]), float(element.get("pace", 1.0))), 0.2, 1.0)
	var other := AiTickCache.tanks_by_name(game_match).get(String(order["target"])) as Tank
	if other != null and other.is_alive():
		context["target_alive"] = true
		context["target_position"] = other.global_position
		context["target_forward"] = -other.global_basis.z
		context["target_velocity"] = other.estimated_velocity
		# An enemy the team lost sight of is chased to where it was last seen, not through the fog.
		var known: Variant = (game_match.intel[tank.team] as Dictionary).get(String(order["target"]))
		if other.team != tank.team and known != null:
			context["target_position"] = known["position"]
			context["target_velocity"] = known["velocity"]
	return context


## Armor.facing as a name, with the arc's cosine as a constant (no trig per contact): which face a round travelling
## along `shell_direction` strikes on a hull facing `hull_forward`.
static func face_hit(hull_forward: Vector3, shell_direction: Vector3) -> String:
	var forward := Vector2(hull_forward.x, hull_forward.z)
	var toward_shooter := Vector2(-shell_direction.x, -shell_direction.z)
	var lengths := forward.length() * toward_shooter.length()
	var alignment := forward.dot(toward_shooter) / lengths if lengths > 1e-9 else 0.0
	if alignment >= COS_ARMOR_ARC:
		return "front"
	if alignment <= -COS_ARMOR_ARC:
		return "rear"
	return "side"


## Whether a flat `forward` points within the angle whose cosine is `min_cos` of `direction` (a zero vector counts as
## pointing, like Ballistics.aim_error).
static func points_at(forward: Vector3, direction: Vector3, min_cos: float) -> bool:
	var a := Vector2(forward.x, forward.z)
	var b := Vector2(direction.x, direction.z)
	var lengths := a.length() * b.length()
	return lengths < 1e-8 or a.dot(b) >= min_cos * lengths


## Whether a contact faces one of my team other than me (AiTickCache.faced_by, without a lambda per contact).
func _faces_someone_else(known: Dictionary, contact_name: String, my_name: String) -> bool:
	for faced: String in AiTickCache.faced_by(game_match, tank.team, contact_name, known):
		if faced != my_name:
			return true
	return false


## Measurement only: adds the time since `since` to profile_parts[part] while profiling; returns now.
static func _lap(part: String, since: int) -> int:
	if not OrderController.profile_detail:
		return 0
	var now := Time.get_ticks_usec()
	profile_parts[part] = int(profile_parts.get(part, 0)) + now - since
	return now


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


## How close counts as arrived for a move order: ORDER_ARRIVE, or for wheels Movement.settle_radius (a car can't settle on
## a point much closer than that without circling it).
func _order_arrive() -> float:
	# The wheeled number lives in one place (nav's Movement.settle_radius, round 7): 0 for tracks and hover.
	return maxf(ORDER_ARRIVE, Movement.settle_radius(tank.unit_id))


## How often this brain should think right now (think LOD): the fight rate when either gun can reach the nearest
## known enemy, the near rate when one is within LOD_RADIUS, the idle rate otherwise. Reads the team's shared contact
## table (AiTickCache), so a brain's own rate costs a handful of distance checks.
func _think_rate() -> float:
	var my_position := tank.global_position
	var my_reach := float(tank.weapon["range"]) + FIGHT_MARGIN
	var rate := IDLE_THINK_HZ
	for known: Dictionary in AiTickCache.contact_prototypes(game_match, tank.team).values():
		var distance := my_position.distance_to(known["position"])
		if distance > LOD_RADIUS:
			continue
		if distance <= maxf(my_reach, float(known["weapon_range"]) + FIGHT_MARGIN):
			return _contact_think_hz(BrainVariants.for_team(tank.team))
		rate = NEAR_THINK_HZ
	return rate


## Whether this brain thinks on this tick: its own turn has come round (staggered by think_offset), or it has never
## thought. Under a controller stride the turn is taken on the first tick of the window that actually runs.
func _due_to_think() -> bool:
	if _next_think_tick < 0:
		_next_think_tick = game_match.tick + think_offset % maxi(1, roundi(SimClock.TICK_RATE / _think_hz))
	return game_match.tick >= _next_think_tick


## Book the next think at the current rate, carrying the fraction of a tick that doesn't divide (6.67/s at 30 Hz is
## 4 ticks, then 5, then 4...). Deterministic: integers and one float per brain, never a clock.
func _schedule_think() -> void:
	_think_debt += SimClock.TICK_RATE / maxf(_think_hz, 0.01)
	var step := maxi(_stride, int(_think_debt))
	_think_debt -= step
	_next_think_tick = game_match.tick + step


static func label(option: Dictionary) -> String:
	if option.is_empty():
		return ""
	return option["option"] + ("" if option["target"] == "" else " " + option["target"])


# ---- The pure part ----------------------------------------------------------------

static func decide(s: Dictionary, current: Dictionary) -> Dictionary:
	var me: Dictionary = s["self"]
	var d: Dictionary = s["directives"]
	var weapon: Dictionary = me["weapon"]
	var hp := float(me["health"]) / float(me["max_health"])
	# G6: confidence counts the shield (a fresh shield makes a fight winnable); retreat thresholds use
	# the hull alone, because the hull is what doesn't come back.
	var max_shield := float(me.get("max_shield", 0.0))
	var shield := float(me.get("shield", 0.0))
	var toughness := (float(me["health"]) + shield) / (float(me["max_health"]) + max_shield)
	var shield_down := max_shield > 0.0 and shield <= 0.0
	var confidence := lerpf(0.35, 1.0, toughness)
	var contacts: Array = s["contacts"]
	var objective: Variant = s["objective"]
	var leash := float(d["leash"])
	var my_position: Vector3 = me["position"]
	## Squad orders (tactical map): null when this tank's squad has no drill.
	var squad: Variant = s.get("squad")
	var commanded: bool = squad != null and squad["slot"] != null
	## L1: what my element's leader has me doing ({} when I'm not in one).
	var element_context: Dictionary = s.get("element") if s.get("element") != null else {}
	## Brain variant switches (BrainVariants): missing = on.
	var features: Dictionary = s.get("features", {})
	var tactics: Dictionary = s.get("tactics", {}) if features.get("squad_tactics", true) else {}
	var fragile_threats: Array = tactics.get("fragile_threats", [])

	var visible_threats := 0
	var threats_on_me := 0
	# G7: a gun with no shells can't fight; a laser at its heat cap has to wait.
	var max_ammo := int(me.get("max_ammo", -1))
	var ammo := int(me.get("ammo", -1))
	var out_of_ammo := max_ammo > 0 and ammo == 0
	var is_scout: bool = me.get("class", "tank") == "scout"
	var is_artillery: bool = me.get("class", "tank") == "artillery"
	var firepower := 0.1 if out_of_ammo else lerpf(1.0, HOT_FIREPOWER, clampf((float(me.get("heat", 0.0)) - 0.7) / 0.3, 0.0, 1.0))
	# Guns that can shoot me right now: in their reach with a clear line (A3). Hand-built situations may omit
	# it; then a gun aimed at me counts.
	var exposed_to := 0
	for c in contacts:
		if c["visible"]:
			visible_threats += 1
			# L2 (X3): a pinned gun is half a gun — it mostly misses and it tracks slowly — so it weighs less in
			# "am I outgunned here".
			var weight := PINNED_THREAT_FACTOR if bool(c.get("pinned", false)) else 1.0
			if c["aiming_at_me"]:
				threats_on_me += 1 if weight >= 1.0 else 0
			if c.get("threatens_me", c["aiming_at_me"]):
				exposed_to += 1 if weight >= 1.0 else 0

	# Round-5 X1: candidates are appended directly (a lambda call per option was measurable at 60 brains).
	var candidates: Array = []

	# L2 (X3): my crew's own suppression. Pinned, my fire is wasted, so getting out of the beaten zone beats trading.
	var pinned: bool = me.get("pinned", false)
	# RETREAT: hurt past the caution-derived threshold with enemies in sight, or badly outnumbered.
	var retreat_threshold := lerpf(0.15, 0.55, float(d["caution"])) + (PINNED_RETREAT_HP if pinned else 0.0)
	var retreat := 0.0
	if commanded and String(squad["verb"]) != "assault":
		# Player intent dominates (G3): a tank under orders only saves itself when it's about to die.
		if hp < lerpf(CRITICAL_HP_MIN, CRITICAL_HP_MAX, float(d["caution"])) and visible_threats > 0:
			retreat = 0.99
	elif hp < retreat_threshold and visible_threats > 0:
		retreat = 0.85 + 0.1 * float(d["caution"])
	elif visible_threats >= 3 and hp < 0.6:
		retreat = 0.45 * float(d["caution"])

	candidates.append({"option": "RETREAT", "target": "", "score": float(retreat)})
	# RESUPPLY (G7): empty guns go home; tanks already at base top up; low tanks refill in quiet moments.
	# Under a player order it stays below ORDER_WEIGHT: the player sees ammo and decides.
	var resupply := 0.0
	if max_ammo > 0:
		var ammo_ratio := float(ammo) / max_ammo
		if out_of_ammo:
			resupply = 0.9
		elif bool(me.get("in_resupply_zone", false)) and ammo_ratio < RESUPPLY_TOP_UP:
			resupply = 0.9 if visible_threats == 0 else 0.5
		elif ammo_ratio <= OrderController.LOW_AMMO_FRACTION and visible_threats == 0:
			resupply = 0.5
	# G6 repair: the base also mends hulls. A worn tank at base stays until mended; a badly hurt one
	# with nobody in sight heads home (this replaced standing still, and fixes camping hurt tanks:
	# they go home, mend, and come back).
	if bool(me.get("in_resupply_zone", false)) and hp < REPAIR_TOP_UP and visible_threats == 0:
		resupply = maxf(resupply, 0.85)
	elif hp < retreat_threshold and visible_threats == 0 and not commanded:
		resupply = maxf(resupply, 0.6)
	candidates.append({"option": "RESUPPLY", "target": "", "score": float(resupply)})
	# TAKE_COVER: guns on me, hurt, cautious, and somewhere hidden is close by.
	var cover := 0.0
	if not (s["cover"] as Array).is_empty() and maxi(threats_on_me, exposed_to) > 0:
		cover = float(d["caution"]) * minf(1.0, maxi(threats_on_me, exposed_to) / 2.0) * (1.0 - toughness) * 1.6
	# Pinned with somewhere to hide: go. Cover is what breaks a beaten zone, and shooting back from inside one is
	# throwing rounds away.
	if pinned and not (s["cover"] as Array).is_empty():
		cover = maxf(cover, PINNED_COVER)
	candidates.append({"option": "TAKE_COVER", "target": "", "score": float(cover)})
	# RECHARGE (G6): shield gone, a gun on me, hull already worn: break contact for a few seconds (the
	# nearest cover, or back off out of the line of fire) and come back when the shield is up. A short
	# hop, not a trip home: RETREAT to base (2026-09-14 first cut) cost the fight and lost T1 22 of 24.
	var recharge := 0.0
	if shield_down and threats_on_me > 0 and hp < SHIELD_DOWN_BREAK_HP:
		recharge = 0.4 + 0.3 * float(d["caution"])
	elif max_shield > 0.0 and current.get("option", "") == "RECHARGE" and shield < max_shield * RECHARGED and visible_threats > 0:
		recharge = 0.5  # keep ducking until the shield is mostly back
	candidates.append({"option": "RECHARGE", "target": "", "score": float(recharge)})
	# A5: how fast my weapon kills each fresh contact (mechanics + catalog prior), and how the duel goes.
	var matchups: Dictionary = TankBrain.matchups_for(s) if features.get("matchups", true) else {}
	var best_kill_rate := 0.0
	for entry: Dictionary in matchups.values():
		best_kill_rate = maxf(best_kill_rate, float(entry["kill_rate"]))
	var engages: Array = []
	var flanks: Array = []
	var orbits: Array = []
	var investigates: Array = []
	# L2 (X3): whether my gun is a suppressing one at all. Volume and noise hold a crew down, not damage — combat
	# measured a machine gun laying 1.0 suppression per second against a cannon's 0.24, while doing a twentieth of
	# the damage through a tank's front. That is the whole case for firing at something I cannot kill.
	var suppresses: bool = SuppressionFeed.suppresses(weapon) and not out_of_ammo and features.get("avoid_beaten", true)
	var suppressions: Array = []
	for c in contacts:
		var distance := my_position.distance_to(c["position"])
		var in_leash: bool = objective == null or leash <= 0.0 \
				or (objective as Vector3).distance_to(c["position"]) <= leash + float(weapon["range"])
		var leash_factor := 1.0 if in_leash else 0.15
		# A target I'm fighting from cover stays fresh while I hide through its reload (reload windows).
		var fresh_ticks := COVER_FIRE_MEMORY_TICKS if features.get("reload_windows", false) \
				and current.get("option", "") == "COVER_FIRE" and current.get("target", "") == c["name"] else CONTACT_FRESH_TICKS
		if int(c["age"]) <= fresh_ticks:
			var reach := 1.0
			if distance > float(weapon["range"]):
				reach = clampf(1.0 - (distance - float(weapon["range"])) / 80.0, 0.15, 1.0)
			var priority := TankBrain._priority(String(d["target_priority"]), c, distance)
			var engage := (0.3 + 0.7 * float(d["aggression"])) * reach * (0.55 + 0.45 * priority) \
					* confidence * leash_factor * (1.0 if c["visible"] else 0.75) * firepower
			var matchup_factor := 1.0
			if matchups.has(c["name"]) and best_kill_rate > 0.0:
				var m: Dictionary = matchups[c["name"]]
				# Shoot what my weapon kills fastest; lean into duels I win, away from ones I lose.
				matchup_factor = (0.5 + 0.5 * float(m["kill_rate"]) / best_kill_rate) * clampf(pow(float(m["advantage"]), 0.25), 0.8, 1.25)
				# Orbit a turret I can out-turn when the duel looks winnable; once circling, keep at it unless it's clearly lost.
				var keep_orbiting: bool = current.get("option", "") == "ORBIT" and current.get("target", "") == c["name"]
				# Round 7: a target I am already circling stays mine while its contact is fresh, seen or not. Circling IS
				# crossing its line of sight fast, which combat's X6 makes hard to hold continuously: at 25 m the scout lost
				# sight mid-orbit, dropped to SPOT, backed off to its standoff and never fired (scenario_cp2 engine deck).
				if m.get("orbit", false) and (c["visible"] or keep_orbiting) \
						and float(m["advantage"]) >= (ORBIT_KEEP_ADVANTAGE if keep_orbiting else ORBIT_START_ADVANTAGE):
					orbits.append([c["name"], maxf(engage * 1.2, 0.95 * confidence * firepower * leash_factor)])
			engage *= matchup_factor
			# A6: the squad's plan tilts who to shoot (never whether to follow the player's order).
			var squad_bonus := 1.0
			if c["name"] == tactics.get("focus", ""):
				squad_bonus *= FOCUS_BONUS
			if c["name"] == tactics.get("cover_target", ""):
				squad_bonus *= COVER_TEAMMATE_BONUS
			if fragile_threats.has(c["name"]):
				squad_bonus *= FRAGILE_THREAT_BONUS
			if squad_bonus > 1.0:
				var boosted := engage * squad_bonus
				engage = minf(boosted, maxf(engage, ORDER_WEIGHT - 0.1)) if commanded else boosted
			engages.append([c["name"], engage])
			# SUPPRESS: rounds on an enemy I can't kill quickly, to stop it shooting. Worth it when my gun suppresses,
			# the target is visible and in reach, and either killing it is slow going or it is already pinned and
			# worth keeping that way while someone else does the killing.
			if suppresses and c["visible"] and distance <= float(weapon["range"]):
				var poor_kill: bool = best_kill_rate > 0.0 and matchups.has(c["name"]) \
						and float((matchups[c["name"]] as Dictionary)["kill_rate"]) <= best_kill_rate * SUPPRESS_KILL_RATIO
				# X2 (round 5): without matchups, "killing this is slow going" is read off the armour it shows me.
				if not poor_kill and not matchups.has(c["name"]) and features.get("suppress_proxy", false):
					poor_kill = TankBrain.rounds_barely_mark(weapon, c)
				# X2 (round 5, "pinned_exposed"): `flank_target` is only ever set for the squad's FLANKER — the unit sent
				# round — so round 4 was telling the flanker itself to stay and hose its own target (x1.25), and it did.
				# Holding the target down is the rest of the squad's job; with the fix the flanker's pin reasons are the
				# same as anyone's.
				var own_flank: bool = c["name"] == tactics.get("flank_target", "")
				var flanker_fix: bool = features.get("pinned_exposed", false)
				# ...and a crew that is ALREADY pinned is exploited, not re-pinned, by a gun that can kill it: keeping its
				# head down is the base of fire's job (the guns whose rounds barely mark it), killing it is everyone else's.
				# Hysteresis (round 6): a crew I am already holding down stays worth holding while it is NEARLY pinned. On
				# the bare threshold both of its attackers flipped ENGAGE -> SUPPRESS -> ENGAGE in 0.8 s as its
				# suppression crossed and re-crossed the line (CP4's tighter fire pins more, so it crossed more often).
				var holding_down: bool = current.get("option", "") == "SUPPRESS" and current.get("target", "") == c["name"] \
						and float(c.get("suppression", 0.0)) >= Tank.PINNED_SUPPRESSION * PIN_HOLD_FRACTION
				var keep_pinned: bool = (bool(c.get("pinned", false)) or holding_down) \
						and (not flanker_fix or TankBrain.rounds_barely_mark(weapon, c) or poor_kill)
				var worth_pinning: bool = poor_kill or keep_pinned \
						or (own_flank and not flanker_fix) or c["name"] == tactics.get("focus", "")
				if worth_pinning:
					var suppress_score := SUPPRESS_WEIGHT * reach * confidence * leash_factor * firepower
					# Holding down the one a teammate is going round is the point of a base of fire.
					var firing_base := ElementFeed.is_firing_base(element_context)
					if (own_flank and not flanker_fix) or firing_base:
						suppress_score *= 1.25
					# Only "my rounds barely mark it": no teammate is served by pinning this one (see the cap below).
					var only_poor_kill: bool = not (keep_pinned or own_flank or firing_base or c["name"] == tactics.get("focus", ""))
					suppressions.append([c["name"], suppress_score, only_poor_kill])
			# FLANK pays when the target is busy facing a teammate; pointless if I already see its side.
			var flank := float(d["flanking"]) * (1.0 if c["facing_ally"] else 0.55) * confidence * reach * leash_factor * firepower \
					* minf(matchup_factor, 1.0)
			# A pinned crew can't track a mover: this is the moment to go round it, not to sit and trade.
			if bool(c.get("pinned", false)):
				flank *= PINNED_FLANK_BONUS
			if c["exposed_face"] != "front":
				flank *= 0.35
			elif tactics.get("flank_target", "") == c["name"] and (not commanded or String(squad["verb"]) == "assault"):
				# A6 suppress-and-flank: the squad sent me to its focus's side while the others keep it busy.
				flank = maxf(flank, FLANKER_APPETITE * confidence * firepower * leash_factor)
				# X2 ("pinned_exposed"): and once they have its head down, that is the moment to go.
				if features.get("pinned_exposed", false) and bool(c.get("pinned", false)):
					flank = maxf(flank, FLANKER_APPETITE * PINNED_FLANK_BONUS * confidence * firepower * leash_factor)
			flanks.append([c["name"], flank])
		else:
			var staleness := clampf(float(c["age"]) / float(s["memory_ticks"]), 0.0, 1.0)
			# A last-known position beats marching blindly at the enemy base (ADVANCE's 0.3).
			investigates.append([c["name"], (0.25 + 0.4 * float(d["aggression"])) * (1.0 - staleness) * leash_factor])
	# Artillery never brawls: it shells what the team spots (BOMBARD) and stays behind (SHADOW).
	var fight_scale := 0.0 if is_artillery else (SCOUT_FIGHT if is_scout else 1.0)
	var cover_fire: Dictionary = s.get("cover_fire", {}) if s.get("cover_fire") != null else {}
	var pinned_targets := {}
	for c in contacts:
		if bool(c.get("pinned", false)):
			pinned_targets[c["name"]] = true
	for pair in engages:
		var score: float = pair[1] * fight_scale
		if is_scout and TankBrain._is_prey_contact(contacts, pair[0], String(me.get("unit", ""))):
			# Scouts hunt artillery (directive set 2 counter triangle): artillery is blind up close, can't
			# fire inside 35 m, and is fragile; a scout closing fast on it is its nightmare. Even a
			# cautious scout goes for it.
			score = maxf(pair[1] * SCOUT_HUNT, SCOUT_HUNT_FLOOR * confidence)
		candidates.append({"option": "ENGAGE", "target": pair[0], "score": float(score)})
		# COVER_FIRE (A3): the same fight, from a hide/peek pair: hide while reloading, peek to shoot. Worth it
		# for slow-reloading direct-fire guns (a machine gun or laser gains little from ducking between
		# shots); cautious crews like it more. Considerations: fight appetite × reload × caution × spot quality.
		if features.get("cover_fire", true) and not cover_fire.is_empty() and cover_fire["target"] == pair[0] \
				and weapon["kind"] != Weapons.Kind.ARC:
			var slow_reload := UtilityCurves.linear(float(weapon["reload"]), COVER_FIRE_RELOAD_FLOOR, 2.0)
			var spot_quality := UtilityCurves.floor_at(float(cover_fire.get("score", 0.5)), 0.6)
			var cover_value := score * slow_reload * (1.08 + 0.3 * float(d["caution"])) * spot_quality
			# X2 (round 5): cover buys safety from a gun that can hit me, and a pinned crew mostly can't. Fighting it
			# from cover is worth less than going round it or pressing it while its head is down.
			if features.get("pinned_exposed", false) and pinned_targets.has(pair[0]):
				cover_value *= PINNED_COVER_FIRE
			candidates.append({"option": "COVER_FIRE", "target": pair[0], "score": float(cover_value)})
	for pair in flanks:
		candidates.append({"option": "FLANK", "target": pair[0], "score": float(pair[1] * fight_scale)})
	# SUPPRESS (X3): keep a crew's head down. It scores below a fight this unit can actually win, and above hanging
	# back doing nothing — which is what a machine-gun scout did with 84% of its time before this existed.
	# Round 7: the cap that sentence promises. An IFV between a tank it barely marks and a scout it counters suppressed
	# the tank (0.90) over killing the scout (0.51; scenario_matchups). Where nobody is served by the pin, SUPPRESS stays
	# just under the best ENGAGE on a target this unit is not reduced to pinning.
	var suppressed := {}
	for pair in suppressions:
		suppressed[pair[0]] = true
	var best_winnable := 0.0
	for pair in engages:
		if not suppressed.has(pair[0]):
			best_winnable = maxf(best_winnable, float(pair[1]) * fight_scale)
	for pair in suppressions:
		var suppress := float(pair[1] * fight_scale)
		if bool(pair[2]) and best_winnable > 0.0:
			suppress = minf(suppress, best_winnable * SUPPRESS_UNDER_WINNABLE)
		candidates.append({"option": "SUPPRESS", "target": pair[0], "score": suppress})
	# ORBIT (A5): a fixed gun can't out-shoot a turret head-on, but it can out-turn a slow one: circle it and burst in
	# when its gun points away. Scores above SPOT, so scouts fight what they counter instead of hanging back.
	for pair in orbits:
		candidates.append({"option": "ORBIT", "target": pair[0], "score": float(pair[1])})
	# CLEAR_LANE (A4): my gun is ready and aimed but a friend is in the way: step aside to a spot with a clear
	# line to the target instead of waiting (or shooting through it). Above the fight it serves, even when
	# that fight is committed (×COMMIT_BONUS).
	if features.get("hold_for_friends", true) and int(me.get("lane_blocked_ticks", 0)) >= LANE_BLOCKED_TICKS \
			and current.get("target", "") != "":
		for pair in engages:
			if pair[0] == current["target"]:
				candidates.append({"option": "CLEAR_LANE", "target": pair[0], "score": float(maxf(float(pair[1]) * fight_scale, 0.3) * COMMIT_BONUS * 1.15)})
	if is_artillery:
		for c in contacts:
			if not c["visible"]:
				continue
			var reach := my_position.distance_to(c["position"])
			if reach > float(weapon["range"]) + 40.0:
				continue
			var bombard := (0.6 + 0.3 * TankBrain._priority(String(d["target_priority"]), c, reach)) * confidence * firepower
			candidates.append({"option": "BOMBARD", "target": c["name"], "score": float(bombard)})
		var trail := 0.0
		if not (s["allies"] as Array).is_empty():
			trail = 0.55 if visible_threats == 0 else 0.3
		candidates.append({"option": "SHADOW", "target": "", "score": float(trail)})
	# SPOT (scouts, directive set 2): be the team's eyes. Keep the nearest visible enemy at SCOUT_STANDOFF
	# (outside its guns, inside our sight); with nothing in sight, scout ahead.
	var spot := 0.0
	if is_scout:
		var nearest := INF
		for c in contacts:
			# Artillery isn't a threat up close (hunt it), and neither is a slow turret I can orbit (A5).
			var orbitable: bool = matchups.has(c["name"]) and matchups[c["name"]].get("orbit", false) \
					and float(matchups[c["name"]]["advantage"]) >= ORBIT_KEEP_ADVANTAGE
			if c["visible"] and not TankBrain._is_prey(c, String(me.get("unit", ""))) and not orbitable:
				nearest = minf(nearest, my_position.distance_to(c["position"]))
		if nearest < SCOUT_STANDOFF - 10.0:
			spot = 0.88
		elif nearest < INF:
			spot = 0.7
		else:
			spot = 0.62
	candidates.append({"option": "SPOT", "target": "", "score": float(spot)})
	for pair in investigates:
		candidates.append({"option": "INVESTIGATE", "target": pair[0], "score": float(pair[1] * (0.0 if is_artillery else 1.0))})
	# REGROUP: drifted away from the squad, weighted by cohesion (formations do this job when commanded).
	var regroup := 0.0
	if s["squad_center"] != null and not commanded:
		var gap := my_position.distance_to(s["squad_center"])
		regroup = float(d["cohesion"]) * clampf((gap - 15.0) / 30.0, 0.0, 1.0) * 0.8
	candidates.append({"option": "REGROUP", "target": "", "score": float(regroup)})
	# ADVANCE toward the objective (or, with none, toward the enemy base so matches progress).
	var advance := 0.0
	var at_objective := false
	if objective != null:
		var to_objective := my_position.distance_to(objective)
		at_objective = to_objective <= float(s["objective_radius"])
		if leash > 0.0 and to_objective > leash:
			# Back to the post, unless the tank is breaking contact to recharge (G6): a hard leash kept
			# anchors from ever letting their shields come back.
			advance = 0.95 if recharge <= 0.0 else 0.3
		elif not at_objective:
			advance = 0.45 if visible_threats == 0 else 0.25
	elif visible_threats == 0 and hp >= retreat_threshold:
		# Hurt tanks don't go looking for a fight: without this, a damaged tank (no repairs in
		# squad-vs-squad) yo-yoed between its base and the enemy forever.
		advance = 0.3
	if commanded:
		advance = 0.0  # the squad's destination replaces free advancing
	candidates.append({"option": "ADVANCE", "target": "", "score": float(advance)})
	# CONTEST (stretch, control point): take and hold the center when it isn't ours. Holding tanks stay
	# inside and fight from there. Artillery doesn't contest (it can't hold ground).
	var contest := 0.0
	var control: Variant = s.get("control")
	if control != null and not commanded and not is_artillery and hp >= retreat_threshold:
		var inside := my_position.distance_to(control["center"]) <= float(control["radius"]) * 0.8
		if int(control["owner"]) != int(me["team"]):
			contest = 0.72 if visible_threats == 0 else 0.5
		elif inside:
			contest = 0.4
		else:
			contest = 0.45 if visible_threats == 0 else 0.2
		contest *= 0.8 if is_scout else 1.0
	candidates.append({"option": "CONTEST", "target": "", "score": float(contest)})
	# KEEP_SLOT: be where the squad's formation and drill want me. The player's order dominates
	# (G3): it beats even a committed ENGAGE (~0.8 x COMMIT_BONUS), and only a tank about to die
	# (RETREAT 0.99) overrides it. "Move" means return fire on the move (the turret tracks threats,
	# G5) rather than stopping for every fight. Assault deliberately lets brains hunt.
	var keep_slot := 0.0
	var in_position := false
	if commanded:
		var gap := my_position.distance_to(squad["slot"])
		in_position = gap <= SLOT_TOLERANCE and not squad["moving"]
		match String(squad["verb"]):
			"move":
				keep_slot = 0.0 if in_position else ORDER_WEIGHT
			"bound":
				# The overwatch element drives to its overwatch spot (A6), then holds there.
				var to_spot: bool = squad["moving"] or squad.get("overwatch", false)
				keep_slot = ORDER_WEIGHT if to_spot and gap > 3.0 else 0.0
				in_position = not squad["moving"] and (not squad.get("overwatch", false) or gap <= 3.0)
			"hold":
				keep_slot = 0.0 if gap <= SLOT_TOLERANCE else ORDER_WEIGHT
			"assault":
				keep_slot = 0.0 if in_position else (0.5 if visible_threats == 0 else 0.15)
			"break_contact":
				keep_slot = 0.0 if gap <= SLOT_TOLERANCE else 0.97
	candidates.append({"option": "KEEP_SLOT", "target": "", "score": float(keep_slot)})
	# HOLD: the fallback, and the anchor's job once at its objective.
	var hold := 0.1
	if at_objective:
		hold = 0.3 + 0.35 * (1.0 - float(d["aggression"]))
	if in_position:
		hold = maxf(hold, 0.72)  # in formation and halted: fight from here
	candidates.append({"option": "HOLD", "target": "", "score": float(hold)})
	# No stuck states (X1): an option on cooldown after timing out scores much less, so something else gets a turn.
	var cooldowns: Dictionary = s.get("cooldowns", {})
	if not cooldowns.is_empty():
		for candidate in candidates:
			if int(cooldowns.get(candidate["option"], -1)) > int(s["tick"]):
				candidate["score"] *= COOLDOWN_FACTOR
	# K1 (X1): the player's order decides what this unit does; the options above only decide how.
	var order_context: Variant = s.get("order")
	if order_context != null:
		var critical := hp < lerpf(CRITICAL_HP_MIN, CRITICAL_HP_MAX, float(d["caution"])) and visible_threats > 0
		candidates = TankBrain._obey(candidates, order_context, s, critical, out_of_ammo)
		keep_slot = 0.0

	# No flip-backs: what it left under REVISIT_S ago has to be clearly better to be chosen again.
	var left: Dictionary = s.get("left", {})
	if not left.is_empty() and int(s["tick"]) - int(left["tick"]) < roundi(REVISIT_S * SimClock.TICK_RATE):
		for candidate in candidates:
			# Only between fights of the brain's own choosing: going back to the ORDER (MOVE, PURSUE...), to an escape or
			# to its post is obeying or surviving, and must never be made harder.
			if FIGHT_OPTIONS.has(candidate["option"]) and candidate["option"] == left["option"] \
					and candidate["target"] == left["target"]:
				candidate["score"] *= REVISIT_FACTOR
	# Commitment: favor the current choice; keep it through MIN_COMMIT_TICKS unless beaten decisively.
	var committed: Dictionary = {}
	# An order the tank isn't carrying out yet outranks commitment to anything but itself or survival.
	var order_pending := keep_slot > 0.0 and not ["KEEP_SLOT", "RETREAT"].has(current.get("option", ""))
	var commit_bonus := float(features.get("commit_bonus", COMMIT_BONUS))  # hoisted: decide() runs per brain per think
	for candidate in candidates:
		if order_pending:
			break
		if not current.is_empty() and candidate["option"] == current["option"] and candidate["target"] == current["target"]:
			candidate["score"] *= commit_bonus
			committed = candidate
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if candidate["score"] > best["score"]:
			best = candidate
	if not committed.is_empty() and committed != best and int(s["tick"]) - int(current["since"]) < MIN_COMMIT_TICKS \
			and committed["score"] > 0.0 and best["score"] < committed["score"] * EMERGENCY_MARGIN:
		best = committed

	return {"choice": {"option": best["option"], "target": best["target"]},
			"ranked": TankBrain._top(candidates, 3)}


## K1: keep only the options the order's verb allows (ORDER_OPTIONS) and add the ones that carry it out. A move,
## hold, or follow is absolute; an attack fights only its target (any way the brain likes) and chases it when it's
## out of sight; an attack-move drives on unless a fight on the way outscores ATTACK_MOVE_WEIGHT (only its named target,
## when it has one); an idle unit fights
## around its post (the situation's objective) and never roams off to scout, contest, or resupply.
static func _obey(candidates: Array, o: Dictionary, s: Dictionary, critical: bool, out_of_ammo: bool) -> Array:
	var verb: String = o["verb"]
	var allowed: Array = ORDER_OPTIONS.get(verb, [])
	var target: String = o.get("target", "")
	var contacts: Array = s["contacts"]
	var target_fresh := contacts.any(func(c: Dictionary) -> bool:
		return c["name"] == target and int(c["age"]) <= CONTACT_FRESH_TICKS)
	var anything_visible := contacts.any(func(c: Dictionary) -> bool: return c["visible"])
	# Attack-move: visible enemies within the weapon's reach (plus a margin) are "met on the way".
	var in_reach: Array = []
	var my_position: Vector3 = s["self"]["position"]
	var reach := float(s["self"]["weapon"]["range"]) + ATTACK_MOVE_REACH_MARGIN
	for c: Dictionary in contacts:
		if c["visible"] and my_position.distance_to(c["position"]) <= reach:
			in_reach.append(c["name"])
	var result: Array = []
	for candidate: Dictionary in candidates:
		var option: String = candidate["option"]
		if not allowed.has(option):
			continue
		match verb:
			"hold":
				candidate["score"] = 1.0
			"attack":
				if candidate["target"] != target:
					continue
				candidate["score"] = 1.0 + float(candidate["score"])
			"attack_move":
				if option == "RETREAT":
					if not critical:
						continue
					candidate["score"] = 0.99
				elif target != "" and candidate["target"] != "" and candidate["target"] != target:
					# Round 8: an attack-move that names a target (an element maneuvering onto the one its task names)
					# fights that one and drives past the rest: the lead's "they shoot whatever they were already
					# shooting at" was the maneuver half of a drill picking fights on the way.
					continue
				elif candidate["target"] in in_reach:
					candidate["score"] = ATTACK_MOVE_FIGHT + float(candidate["score"])  # met on the way: fight it
			"idle":
				if (option == "SPOT" and not anything_visible) or (option == "RESUPPLY" and not out_of_ammo):
					continue
		result.append(candidate)
	var goal: Variant = o.get("goal")
	match verb:
		"move", "stop":
			if goal != null:
				result.append({"option": "MOVE", "target": "", "score": 1.0})
		"attack_move":
			if goal != null:
				result.append({"option": "MOVE", "target": "", "score": ATTACK_MOVE_WEIGHT})
		"follow":
			if bool(o.get("target_alive", false)):
				result.append({"option": "FOLLOW", "target": target, "score": 1.0})
		"attack":
			if bool(o.get("target_alive", false)) and not target_fresh:
				result.append({"option": "PURSUE", "target": target, "score": 1.0})
			elif target_fresh and not result.any(func(c: Dictionary) -> bool: return float(c["score"]) > 0.0):
				result.append({"option": "ENGAGE", "target": target, "score": 1.0})
	if result.is_empty():
		result.append({"option": "HOLD", "target": "", "score": 0.1})
	return result


## X1: the formation slot this unit should fight from, or null when it has no element, no slot, or is the half that
## is meant to be covering ground (a bounding or assaulting unit moves; the rest hold their place in the formation).
static func element_slot(s: Dictionary) -> Variant:
	var context: Variant = s.get("element")
	if context == null or ["bound", "maneuver"].has(String((context as Dictionary).get("role", ""))):
		return null
	return (context as Dictionary).get("slot")


## Where the turret covers when nothing is in this tank's own sights (G5): the chosen target,
## else the most pressing known contact: visible before remembered, guns on me first, then nearest.
## Null with no contacts (the turret holds its heading).
static func watch_for(s: Dictionary, current: Dictionary) -> Variant:
	var my_position: Vector3 = s["self"]["position"]
	var best: Variant = null
	var best_score := INF
	for c in s["contacts"]:
		# Where it probably is now: last known position plus a short dead-reckoning.
		var seconds := minf(float(c["age"]) / SimClock.TICK_RATE, WATCH_PREDICT_SECONDS)
		var predicted: Vector3 = c["position"] + (c["velocity"] as Vector3) * seconds
		if c["name"] == current.get("target", ""):
			return predicted
		var score := my_position.distance_to(c["position"]) * (0.6 if c["aiming_at_me"] else 1.0)
		if not c["visible"]:
			score += 1000.0 + float(c["age"])
		if score < best_score:
			best_score = score
			best = predicted
	return best


## X2: whether `weapon`'s rounds barely mark `contact` through the armour face it shows me (SUPPRESS_PENETRATION). False
## when either side carries no armour data (hand-built situations, old profiles).
static func rounds_barely_mark(weapon: Dictionary, contact: Dictionary) -> bool:
	if not weapon.has("penetration"):
		return false
	var armor: Variant = Units.profile(String(contact.get("unit", ""))).get("armor")
	if not armor is Dictionary:
		return false
	var thickness := float((armor as Dictionary).get(String(contact.get("exposed_face", "front")), 0.0))
	return thickness > 0.0 and Matchups.penetration_multiplier(float(weapon["penetration"]), thickness) <= SUPPRESS_PENETRATION


## A scout's prey: artillery (it can't fire up close) and the roles its catalog entry is good against (the Lancer's
## turret can't track it; since CP2 a scout that only spotted a Lancer never fired, balance.md matrix #6).
static func _is_prey(contact: Dictionary, my_unit: String) -> bool:
	if contact.get("weapon", "") == "mortar":
		return true
	var role := Units.role_of(String(contact.get("unit", ""))) if Units.exists(String(contact.get("unit", ""))) else ""
	return role != "" and (Units.profile(my_unit).get("good_vs", []) as Array).has(role)


static func _is_prey_contact(contacts: Array, contact_name: String, my_unit: String) -> bool:
	for c in contacts:
		if c["name"] == contact_name:
			return TankBrain._is_prey(c, my_unit)
	return false


static func _is_artillery_contact(contacts: Array, contact_name: String) -> bool:
	for c in contacts:
		if c["name"] == contact_name:
			return c.get("weapon", "") == "mortar"
	return false


static func _priority(rule: String, contact: Dictionary, distance: float) -> float:
	match rule:
		"weakest":
			# Hull plus shield against a standard tank's full load (was health / 100, which rated every
			# tank above 100 HP as equally healthy).
			var full := float(Units.stat("tank", "max_health")) + float(Units.stat("tank", "max_shield"))
			return 1.0 - clampf((float(contact["health"]) + float(contact.get("shield", 0.0))) / full, 0.0, 1.0)
		"most_exposed":
			return {"rear": 1.0, "side": 0.7, "front": 0.3}[contact["exposed_face"]]
		"threatening_allies":
			return 1.0 if contact["facing_ally"] else 0.3
	return 1.0 - clampf(distance / 150.0, 0.0, 1.0)  # nearest


## Highest scores first; ties keep candidate order (stable, unlike sort_custom).
static func _top(candidates: Array, count: int) -> Array:
	var remaining := candidates.duplicate()
	var result: Array = []
	while result.size() < count and not remaining.is_empty():
		var best_index := 0
		for i in remaining.size():
			if remaining[i]["score"] > remaining[best_index]["score"]:
				best_index = i
		var picked: Dictionary = remaining.pop_at(best_index)
		result.append({"option": picked["option"], "target": picked["target"], "score": snappedf(picked["score"], 0.001)})
	return result


# ---- Sensing (the only impure part) -----------------------------------------------

## The situation's "control": the objective this tank would contest from where it stands (the nearest its team does not
## hold, else the nearest it does; Objectives.goal), or null when the match has none.
static func _control_of(game_match: Match, my_team: int, at: Vector3) -> Variant:
	var objective := Objectives.goal(game_match, my_team, at)
	if objective.is_empty():
		return null
	return {"center": objective["position"], "radius": float(objective["radius"]), "owner": int(objective["owner"])}


func build_situation() -> Dictionary:
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	var team := tank.team
	var my_position := tank.global_position
	var allies: Array = []
	var squad_positions: Array = []
	var my_name := String(tank.name)
	for ally: Dictionary in AiTickCache.allies(game_match, team):
		if ally["name"] == my_name:
			continue
		allies.append(ally)
		if ally["squad"] == squad_name:
			squad_positions.append(ally["position"])

	lap = _lap("s.allies", lap)
	var features := BrainVariants.for_team(team)
	hold_for_friends = features.get("hold_for_friends", true)
	var contacts: Array = []
	var cover_map := CoverMap.of(tank)
	var flank_reach := float(tank.weapon["range"]) + 30.0
	var intel: Dictionary = game_match.intel[team]
	# Intel changes only on its refresh, so the sorted names are shared (intel can gain a name between refreshes only
	# through a refresh, and a name that died is skipped below).
	var names: Array = AiTickCache.intel_names(game_match, team)
	var keep := {}
	if names.size() > MAX_CONTACTS:
		var by_distance: Array = []
		for contact_name in names:
			by_distance.append([my_position.distance_to(intel[contact_name]["position"]), contact_name])
		by_distance.sort()
		for i in by_distance.size():
			var contact_name: String = by_distance[i][1]
			if i < MAX_CONTACTS or contact_name == choice.get("target", "") or contact_name == order.get("target", "") \
					or intel[contact_name]["weapon"] == "mortar":
				keep[contact_name] = true
	lap = _lap("s.select", lap)
	# X2: everything that doesn't depend on where I am was built once for the whole team this intel refresh.
	var prototypes := AiTickCache.contact_prototypes(game_match, team)
	for contact_name in names:
		if (not keep.is_empty() and not keep.has(contact_name)) or not prototypes.has(contact_name):
			continue
		var known: Dictionary = intel[contact_name]
		var contact: Dictionary = (prototypes[contact_name] as Dictionary).duplicate()
		var position: Vector3 = contact["position"]
		var offset := position - my_position
		var visible: bool = contact["visible"]
		contact["age"] = game_match.tick - int(contact["seen_tick"])
		contact["exposed_face"] = TankBrain.face_hit(contact["forward"], offset)
		# Only near enough to flank or prioritize matters (reach + 30 m); the check is contacts × allies.
		contact["facing_ally"] = offset.length() <= flank_reach and _faces_someone_else(known, contact_name, my_name)
		contact["aiming_at_me"] = visible and TankBrain.points_at(contact["turret_forward"], -offset, COS_AIMED_AT_ME)
		# Its gun pointed my way when last seen (within ~20°), visible or not: is it watching the corner?
		contact["watching_me"] = TankBrain.points_at(contact["turret_forward"], -offset, COS_WATCHING)
		# In its weapon's reach with a clear line to me (CoverMap): it can shoot me right now.
		contact["threatens_me"] = visible and my_position.distance_to(position) <= float(contact["weapon_range"]) + 5.0 \
				and cover_map.clear_line_coarse(position, my_position)
		# L2 (X3): a pinned crew is a worse SHOOTER, which makes it the one to go round, not the one to avoid
		# (combat measured a pinned tank hitting 5 of 13 shells where a calm one hits 13 of 13, and taking twice as
		# long to swing its turret).
		contact["pinned"] = float(contact.get("suppression", 0.0)) >= Tank.PINNED_SUPPRESSION
		contacts.append(contact)

	lap = _lap("s.contacts", lap)
	var objective: Variant = null
	var objective_radius := 0.0
	var order_context: Variant = _order_context()
	if order_context != null:
		# K1 replaces doctrine objectives: an idle unit's post is where its last order left it.
		objective = order_context["goal"] if order_context["verb"] == "idle" else null
		objective_radius = 5.0
	elif typeof(directives["objective"]) == TYPE_DICTIONARY:
		var o: Dictionary = directives["objective"]
		objective = Directives.to_world(team, float(o["right"]), float(o["forward"]))
		objective_radius = float(o["radius"])

	var squad_center: Variant = null
	if not squad_positions.is_empty():
		var sum := Vector3.ZERO
		for p in squad_positions:
			sum += p
		squad_center = sum / squad_positions.size()

	# A unit under K1 orders ignores its doctrine squad's drill (the player's order replaced it).
	var squad_context: Dictionary = {} if order_context != null else AiTickCache.squad_context(game_match, tank)
	if features.get("squad_tactics", true) and order_context == null:
		squad_context = _with_overwatch(squad_context, contacts, allies)
	var effective_directives := directives
	if squad_context.get("slot") != null:
		effective_directives = Squad.drill_directives(directives, squad_context)
	if order_context != null:
		effective_directives = directives.duplicate()
		effective_directives["leash"] = IDLE_LEASH
		effective_directives["objective"] = null
	lap = _lap("s.squad", lap)
	var tactics := _tactics(features)
	lap = _lap("s.tactics", lap)
	var cover := _cover_spots(contacts, allies, squad_context)
	lap = _lap("s.cover_spots", lap)
	var cover_fire: Variant = _cover_fire_spot(contacts, allies, squad_context, cover_map)
	lap = _lap("s.cover_fire", lap)
	var incoming: Array = IncomingFire.for_unit(game_match, tank) if _dodges() else []
	lap = _lap("s.incoming", lap)

	return {
		"tick": game_match.tick,
		"self": {"name": String(tank.name), "team": team, "position": my_position, "forward": -tank.global_basis.z,
				"health": tank.health, "max_health": tank.max_health, "weapon": tank.weapon,
				"ammo": tank.ammo, "max_ammo": tank.max_ammo, "heat": tank.sync_heat,
				"shield": tank.shield, "max_shield": tank.max_shield, "reload": tank.sync_reload,
				"lane_blocked_ticks": lane_blocked_ticks, "unit": tank.unit_id, "velocity": tank.estimated_velocity,
				"class": Units.PROFILES.get(tank.unit_id, {}).get("role", "tank"), "sight_radius": tank.sight_radius,
				"in_resupply_zone": Match.in_resupply_zone(team, my_position),
				# L2 (X3): my own crew's suppression, and whether it is bad enough that my fire is wasted.
				"suppression": SuppressionFeed.of(tank), "pinned": SuppressionFeed.is_pinned(tank)},
		"directives": effective_directives,
		"squad": squad_context if squad_context.get("slot") != null else null,
		"contacts": contacts,
		"allies": allies,
		"objective": objective,
		"objective_radius": objective_radius,
		"squad_center": squad_center,
		"features": features,
		"tactics": tactics,
		"cover": cover,
		"cover_fire": cover_fire,
		"rally": Match.spawn_position(team, tank.slot),
		"resupply": Match.resupply_center(team),
		"enemy_base": Match.spawn_position(1 - team, 0),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"control": _control_of(game_match, team, my_position),
		"order": order_context,
		"element": element if not element.is_empty() else null,
		"cooldowns": cooldowns,
		"incoming": incoming,
	}


## Nearby hiding places from the visible threats, best first (TacticalQuery.find_cover), for worn tanks.
## Cached for QUERY_EVERY_TICKS unless the tank moved QUERY_MOVED.
func _cover_spots(contacts: Array, allies: Array, squad_context: Dictionary) -> Array:
	var threats := TankBrain.threat_list(contacts, tank.global_position)
	var toughness := (tank.health + tank.shield) / maxf(tank.max_health + tank.max_shield, 1.0)
	var shield_down := tank.max_shield > 0.0 and tank.shield <= 0.0
	if threats.is_empty() or (toughness >= COVER_QUERY_TOUGHNESS and not shield_down):
		_cover_cache = {}
		return []
	if not _cover_cache.is_empty() and game_match.tick - int(_cover_cache["tick"]) < QUERY_EVERY_TICKS \
			and tank.global_position.distance_to(_cover_cache["position"]) < QUERY_MOVED:
		return _cover_cache["result"]
	var request := {"position": tank.global_position, "threats": threats, "search_radius": COVER_SEARCH_RADIUS,
			"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
	if squad_context.get("slot") != null:
		request["anchor"] = squad_context["slot"]
	elif element.get("slot") != null and not ["bound", "maneuver"].has(String(element.get("role", ""))):
		request["anchor"] = element["slot"]  # X1: hide and peek inside my formation slot, not across the map
		request["anchor_radius"] = COVER_SEARCH_RADIUS * 0.6
	elif _order_home != null:
		if order.is_empty():
			request["anchor"] = _order_home
			request["anchor_radius"] = IDLE_LEASH
	elif typeof(directives["objective"]) == TYPE_DICTIONARY and float(directives["leash"]) > 0.0:
		var o: Dictionary = directives["objective"]
		request["anchor"] = Directives.to_world(tank.team, float(o["right"]), float(o["forward"]))
		request["anchor_radius"] = float(directives["leash"])
	var result: Array = TacticalQuery.find_cover(CoverMap.of(tank), request).map(
			func(spot: Dictionary) -> Vector3: return spot["point"])
	_cover_cache = {"tick": game_match.tick, "position": tank.global_position, "threats": threats.size(), "result": result}
	return result


## A hide/peek pair for fighting the most pressing target from cover (TacticalQuery.find_cover_fire), or
## null. The target is the one this tank is already fighting, else the nearest visible enemy in reach. Cached
## while the tank stays near the hide spot, the target stays put, and the hide spot stays hidden from it.
func _cover_fire_spot(contacts: Array, allies: Array, squad_context: Dictionary, cover_map: CoverMap) -> Variant:
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		return null
	# Round-5 X1: decide() scores COVER_FIRE × UtilityCurves.linear(reload, COVER_FIRE_RELOAD_FLOOR, 2.0), which is 0 for a
	# gun this quick (a machine gun gains nothing ducking between rounds), and a zero never wins: don't search for spots
	# nobody will use. Same for variants without cover fire.
	if float(tank.weapon["reload"]) <= COVER_FIRE_RELOAD_FLOOR or not BrainVariants.for_team(tank.team).get("cover_fire", true):
		_cover_fire_cache = {}
		return null
	var reach := float(tank.weapon["range"])
	var target: Dictionary = {}
	for c: Dictionary in contacts:
		# A target that ducked out of sight a moment ago is still the fight (hiding breaks our own line of sight too).
		var fresh_ticks := COVER_FIRE_MEMORY_TICKS if BrainVariants.for_team(tank.team).get("reload_windows", false) \
				and choice.get("option", "") == "COVER_FIRE" and c["name"] == choice.get("target", "") else CONTACT_FRESH_TICKS
		if int(c["age"]) > fresh_ticks or tank.global_position.distance_to(c["position"]) > reach + 15.0:
			continue
		if c["name"] == choice.get("target", ""):
			target = c
			break
		if not c["visible"]:
			continue
		if target.is_empty() or tank.global_position.distance_to(c["position"]) < tank.global_position.distance_to(target["position"]):
			target = c
	if target.is_empty():
		_cover_fire_cache = {}
		return null
	var cached: Dictionary = _cover_fire_cache.get("result", {})
	if not _cover_fire_cache.is_empty() and _cover_fire_cache["target"] == target["name"] \
			and game_match.tick - int(_cover_fire_cache["tick"]) < QUERY_EVERY_TICKS * 4 \
			and (target["position"] as Vector3).distance_to(_cover_fire_cache["target_position"]) < 6.0 \
			and (cached.is_empty() or (tank.global_position.distance_to(cached["hide"]) < COVER_FIRE_KEEP
				and TacticalQuery.hull_hidden(cover_map, target["position"], cached["hide"]))):
		return null if cached.is_empty() else cached
	if not _cover_fire_cache.is_empty() and _cover_fire_cache["target"] == target["name"] \
			and game_match.tick - int(_cover_fire_cache["tick"]) < QUERY_EVERY_TICKS:
		return null if cached.is_empty() else cached  # asked recently: don't re-run every think
	var request := {"position": tank.global_position, "target": target["position"],
			"threats": TankBrain.threat_list(contacts, tank.global_position), "search_radius": COVER_SEARCH_RADIUS,
			"range": [float(tank.weapon["preferred_min"]), float(tank.weapon["preferred_max"]), reach],
			"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
	if squad_context.get("slot") != null:
		request["anchor"] = squad_context["slot"]
	elif element.get("slot") != null and not ["bound", "maneuver"].has(String(element.get("role", ""))):
		request["anchor"] = element["slot"]  # X1: hide and peek inside my formation slot, not across the map
		request["anchor_radius"] = COVER_SEARCH_RADIUS * 0.6
	var found := TacticalQuery.find_cover_fire(cover_map, request)
	if not found.is_empty():
		found["target"] = target["name"]
	_cover_fire_cache = {"tick": game_match.tick, "target": target["name"], "target_position": target["position"], "result": found}
	return null if found.is_empty() else found


## This tank's slice of its squad's plan (SquadTactics): {"focus", "flank_target" (if I'm the flanker),
## "cover_target" (if I'm covering a squad-mate), "fragile_threats"}.
func _tactics(features: Dictionary) -> Dictionary:
	if not features.get("squad_tactics", true):
		return {}
	var plan := SquadTactics.for_squad(game_match, game_match.squad_for(tank))
	if plan.is_empty():
		return {}
	var my_name := String(tank.name)
	return {"focus": plan["focus"], "flank_target": plan["focus"] if plan["flanker"] == my_name else "",
			"cover_target": (plan["cover_for"] as Dictionary).get(my_name, ""), "fragile_threats": plan["fragile_threats"]}


## The squad-plan part of a choice's explanation: "focus", "flanking", "covering a squad-mate", "guarding artillery".
static func tactics_tag(s: Dictionary, current: Dictionary) -> String:
	var tags: Array = []
	# X1: what the element's leader has this unit doing, so a nameplate reads "HOLD - base of fire".
	var element: Variant = s.get("element")
	if element != null:
		var role := String((element as Dictionary).get("role", ""))
		if role != "":
			tags.append({"bound": "bounding", "overwatch": "overwatch", "base_of_fire": "base of fire",
					"maneuver": "assaulting"}.get(role, role))
		var drill := String((element as Dictionary).get("drill", ""))
		if drill != "":
			tags.append(drill.replace("_", " "))
	var tactics: Dictionary = s.get("tactics", {})
	var target: String = current.get("target", "")
	if tactics.is_empty() or target == "":
		return ", ".join(tags)
	if target == tactics.get("cover_target", ""):
		tags.append("covering a squad-mate")
	if target == tactics.get("flank_target", "") and current.get("option", "") == "FLANK":
		tags.append("flanking for the squad")
	elif target == tactics.get("focus", ""):
		tags.append("squad focus")
	if (tactics.get("fragile_threats", []) as Array).has(target):
		tags.append("guarding artillery")
	return ", ".join(tags)


static func _join(a: String, b: String) -> String:
	return b if a == "" else a + ", " + b


## Bounding overwatch (A6): while this tank's element covers the bound, its slot becomes a tactical overwatch spot
## near where it halted (sees the bound's destination, hidden from known threats) instead of "stay put". Chosen
## once per bound leg.
func _with_overwatch(context: Dictionary, contacts: Array, allies: Array) -> Dictionary:
	var squad := game_match.squad_for(tank)
	if context.get("verb", "") != "bound" or context.get("moving", true) or context.get("waiting", false) \
			or squad == null or squad.bound_goal == null:
		_overwatch = {}
		return context
	if _overwatch.is_empty() or not (_overwatch["goal"] as Vector3).is_equal_approx(squad.bound_goal):
		var request := {"position": tank.global_position, "watch": squad.bound_goal,
				"threats": TankBrain.threat_list(contacts, tank.global_position),
				"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
		_overwatch = {"goal": squad.bound_goal, "spot": TacticalQuery.find_overwatch(CoverMap.of(tank), request)}
	var result := context.duplicate()
	result["slot"] = _overwatch["spot"]
	result["overwatch"] = true
	return result


## A5: {contact name: {"kill_rate": 1/seconds to kill it, "advantage": duel advantage, "orbit": bool}} for fresh
## contacts whose unit type is known, from Matchups over the catalog. Empty for hand-built situations without
## unit ids. Angular speed and fire arcs use cross and dot products (no trig).
static func matchups_for(s: Dictionary) -> Dictionary:
	var me: Dictionary = s["self"]
	var my_profile := Units.profile(String(me.get("unit", "")))
	var result := {}
	if my_profile.is_empty():
		return result
	var weapon: Dictionary = me["weapon"]
	var my_position: Vector3 = me["position"]
	var my_forward: Vector3 = me["forward"]
	var my_velocity: Vector3 = me.get("velocity", Vector3.ZERO)
	var my_health := float(me["health"])
	var my_shield := float(me.get("shield", 0.0))
	var fixed := String(my_profile.get("mount", "turret")) == "fixed"
	var half_arc_cos := 1.0 - 0.5 * pow(deg_to_rad(float(my_profile.get("fire_arc_deg", 360.0)) / 2.0), 2.0)  # cos, small-angle
	var orbit_rate_deg := rad_to_deg(float(my_profile.get("max_forward_speed", 0.0)) / ORBIT_RADIUS)
	for c: Dictionary in s["contacts"]:
		var their_profile := Units.profile(String(c.get("unit", "")))
		if their_profile.is_empty() or int(c["age"]) > CONTACT_FRESH_TICKS:
			continue
		var offset := Vector3(c["position"].x - my_position.x, 0.0, c["position"].z - my_position.z)
		var distance := maxf(offset.length(), 0.1)
		var bearing := offset / distance
		var relative: Vector3 = (c["velocity"] as Vector3) - my_velocity
		var omega_deg := rad_to_deg(absf(relative.x * bearing.z - relative.z * bearing.x) / distance)
		var their_forward: Vector3 = c["forward"]
		var my_face: String = Armor.FACING_NAMES[Armor.facing(my_forward, bearing)]
		var mine := {"distance": distance, "face": c["exposed_face"], "angular_speed_deg": omega_deg,
				"weak_spot": Matchups.is_weak_spot(their_forward, bearing),
				"in_arc": not fixed or Vector2(my_forward.x, my_forward.z).normalized().dot(Vector2(bearing.x, bearing.z)) >= half_arc_cos}
		var their_arc_cos := 1.0 - 0.5 * pow(deg_to_rad(float(their_profile.get("fire_arc_deg", 360.0)) / 2.0), 2.0)
		var theirs := {"distance": distance, "face": my_face, "angular_speed_deg": omega_deg,
				"in_arc": String(their_profile.get("mount", "turret")) != "fixed"
					or Vector2(their_forward.x, their_forward.z).normalized().dot(Vector2(-bearing.x, -bearing.z)) >= their_arc_cos}
		var their_weapon := Weapons.profile(String(c.get("weapon", their_profile.get("weapon", ""))))
		var my_ttk := Matchups.time_to_kill(my_profile, weapon, their_profile, mine, float(c["health"]), float(c.get("shield", 0.0)))
		# A fixed gun that orbits fights at its best: in its arc on the burst, and forcing the orbit's sweep on the turret.
		var orbit: bool = fixed and String(their_profile.get("mount", "turret")) == "turret" \
				and float(their_profile.get("turret_turn_rate_deg", 360.0)) < orbit_rate_deg * 0.8 \
				and their_weapon.get("kind", -1) != Weapons.Kind.ARC and distance <= float(weapon["range"]) + 25.0
		if orbit:
			# Orbiting and bursting in: up close, on its side (or its rear if that's what it shows), in my arc, and
			# sweeping around its turret at the orbit's rate.
			var close := minf(distance, ORBIT_RADIUS + 5.0)
			var deck: bool = s.get("features", {}).get("weak_spots", false) and Matchups.deck_gain(weapon, their_profile) >= DECK_SEEK_GAIN
			mine = {"distance": close, "face": "rear" if c["exposed_face"] == "rear" or deck else "side",
					"angular_speed_deg": orbit_rate_deg, "in_arc": true, "weak_spot": deck}
			theirs["distance"] = close
			theirs["face"] = "side"
			theirs["angular_speed_deg"] = orbit_rate_deg
			my_ttk = Matchups.time_to_kill(my_profile, weapon, their_profile, mine, float(c["health"]), float(c.get("shield", 0.0)))
		var their_ttk := Matchups.time_to_kill(their_profile, their_weapon, my_profile, theirs, my_health, my_shield)
		var advantage := Matchups.duel_advantage(my_ttk, their_ttk)
		result[c["name"]] = {"kill_rate": 0.0 if my_ttk >= Matchups.NEVER else 1.0 / my_ttk, "advantage": advantage,
				"orbit": orbit}
	return result


## A unit's role: catalog v2 "role", round 1 "class", else "tank".
static func role_of(unit: Tank) -> String:
	var profile: Dictionary = Units.PROFILES.get(unit.unit_id, {})
	return String(profile.get("role", profile.get("class", "tank")))


## Visible contacts as TacticalQuery threats: guns aimed at me first (weight 1), then the rest (0.6),
## nearest first within each group.
static func threat_list(contacts: Array, my_position: Vector3) -> Array:
	var ranked: Array = []
	for c: Dictionary in contacts:
		if c["visible"]:
			var aimed: bool = c["aiming_at_me"]
			ranked.append([0 if aimed else 1, my_position.distance_to(c["position"]), c["name"], c["position"], 1.0 if aimed else 0.6])
	ranked.sort()
	return ranked.map(func(entry: Array) -> Dictionary: return {"position": entry[3], "weight": entry[4]})


# ---- Acting: choice → standing orders ----------------------------------------------

func _act(s: Dictionary) -> void:
	why = TankBrain.tactics_tag(s, choice)
	# Round 6 (lesson 47): what a held player unit may do instead of moving, and whether it is under fire.
	# With nothing to face, the facing it was told (nav's round-7 probe: two idle player units chose ADVANCE after their
	# move finished, the refused move became a bare stop, and nothing turned them to the ordered facing).
	_held_face = TankBrain._face_threat_or(s, _face_intended_or({"type": "stop"}))
	_held_under_fire = tank.ticks_since_hit < HELD_UNDER_FIRE_TICKS or not (s.get("incoming", []) as Array).is_empty()
	if choice["option"] != "CLEAR_LANE":
		_lane_goal = null
	var me: Dictionary = s["self"]
	var my_position: Vector3 = me["position"]
	var weapon: Dictionary = me["weapon"]
	var contact := _contact(s, choice["target"])
	match choice["option"]:
		"MOVE":
			var o: Dictionary = s["order"]
			var goal: Vector3 = o["goal"]
			why = TankBrain._join(why, "attack-move" if o["verb"] == "attack_move" else "ordered")
			if _flat(my_position).distance_to(goal) <= _order_arrive():
				_order_move(_face_intended_or({"type": "stop"}))
			else:
				_order_move(_arrive_facing(_move_to(goal, false, float(o["speed"]), _order_arrive())))
			# Round 8: a move that names a target (a crew its leader swings round onto the ordered target) lays its gun on
			# that one while it drives, not on whatever is nearest; fire at will when it can't bear.
			if String(o.get("target", "")) != "":
				_order_weapon({"type": "target", "name": String(o["target"]), "fallback": true})
			else:
				_order_weapon({"type": "fire_at_will"})
		"PURSUE":
			var o: Dictionary = s["order"]
			why = TankBrain._join(why, "ordered, closing in")
			_order_move(_move_to(o["target_position"], false, 1.0, 2.0))
			_order_weapon({"type": "target", "name": o["target"], "fallback": true})
		"FOLLOW":
			var o: Dictionary = s["order"]
			var friend: Vector3 = o["target_position"]
			var heading: Vector3 = o["target_forward"]
			var velocity: Vector3 = o["target_velocity"]
			# Control's live station for this unit around the friend (its formation slot) when it gives one, else behind the
			# friend; either way led by half a second so a moving escort doesn't trail off.
			var station := _flat(friend - heading * FOLLOW_DISTANCE) if o["goal"] == null else _flat(o["goal"])
			station += _flat(velocity * 0.5)
			why = TankBrain._join(why, "following " + String(o["target"]))
			if _flat(my_position).distance_to(station) > 4.0:
				_order_move(_move_to(station, false, 1.0, 3.0))
			else:
				_order_move(_face_threat_or(s, {"type": "stop"}))
			_order_weapon({"type": "fire_at_will"})
		"ENGAGE":
			var distance := my_position.distance_to(contact["position"])
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
			if contact["visible"] and distance <= float(weapon["range"]) + MOTION_REACH_MARGIN and _moves_while_fighting(s):
				_order_move(_combat_move(s, contact))
			elif not contact["visible"] or distance > float(weapon["preferred_max"]):
				_order_move(_move_to(contact["position"]))
			elif distance < float(weapon["preferred_min"]):
				var away: Vector3 = my_position + (my_position - contact["position"]).normalized() * 8.0
				_order_move(_move_to(away, true))
			else:
				_order_move({"type": "face", "x": contact["position"].x, "z": contact["position"].z})
		"SUPPRESS":
			# X3: keep this crew's head down. Rounds go at the enemy while it is in the open, and at the ground it
			# went behind the moment it isn't — a beaten zone doesn't stop being one because the target ducked, and
			# that is what stops it leaning back out. Hold the range that suits the gun; don't chase.
			var distance := my_position.distance_to(contact["position"])
			var spot: Vector3 = _suppression_point(contact)
			_order_weapon({"type": "suppress", "x": spot.x, "z": spot.z})
			why = TankBrain._join(why, "suppressing " + String(contact["name"]) if contact["visible"]
					else "fire on where it went")
			if distance > float(weapon["preferred_max"]):
				_order_move(_move_to(contact["position"]))
			elif distance < float(weapon["preferred_min"]):
				var back: Vector3 = my_position + (my_position - contact["position"]).normalized() * 8.0
				_order_move(_move_to(back, true))
			else:
				# Standing still is what makes fire effective (Match.shot_spread charges movement), and a base of
				# fire is meant to stay put anyway.
				_order_move({"type": "face", "x": contact["position"].x, "z": contact["position"].z})
		"FLANK":
			var side := Vector3(-contact["forward"].z, 0.0, contact["forward"].x)
			if side.dot(my_position - contact["position"]) < 0.0:
				side = -side
			var standoff := clampf((float(weapon["preferred_min"]) + float(weapon["preferred_max"])) / 2.0, 8.0, 45.0)
			var point: Vector3 = contact["position"] + side * standoff - contact["forward"] * (0.3 * standoff)
			var from_target: Vector3 = my_position - contact["position"]
			if s.get("features", {}).get("combat_motion", false) \
					and (contact["forward"] as Vector3).dot(from_target) > FLANK_WIDE_COS * from_target.length():
				# X4: still in front of it: swing wide first, so the flank reads as a flank (and stays out of its sights).
				point += side * FLANK_WIDE_EXTRA
				why = TankBrain._join(why, "swinging wide")
			_order_move(_move_to(point))
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"TAKE_COVER":
			var spot: Vector3 = s["cover"][0]
			_order_move(_move_to(spot, (spot - my_position).dot(me["forward"]) < 0.0, 1.0,
					OrderController.ARRIVE_RADIUS, false, true))
			_order_weapon({"type": "fire_at_will"})
		"RETREAT":
			# Break line of sight first (A3): backing 100 m across open ground under fire is how hurt tanks died.
			var exposed := (s["contacts"] as Array).any(func(c: Dictionary) -> bool:
				return c["visible"] and c.get("threatens_me", c["aiming_at_me"]))
			var cover_spots: Array = s["cover"]
			if not s.get("features", {}).get("retreat_to_cover", true):
				_order_move(_move_to(s["rally"], true, 1.0, OrderController.ARRIVE_RADIUS, false, true))
			elif exposed and not cover_spots.is_empty() and my_position.distance_to(cover_spots[0]) <= RETREAT_COVER_DISTANCE:
				why = TankBrain._join(why, "breaking line of sight")
				var hide: Vector3 = cover_spots[0]
				_order_move(_move_to(hide, (hide - my_position).dot(me["forward"]) < 0.0, 1.0, SPOT_ARRIVE, false, true))
			else:
				# X4: light hulls break away at full speed; only a thick front is worth backing off behind.
				var back_off: bool = not s.get("features", {}).get("combat_motion", false) \
						or TankBrain.motion_style(String(me.get("unit", ""))) == "angle"
				if not back_off:
					why = TankBrain._join(why, "breaking away")
				_order_move(_move_to(TankBrain.withdraw_point(s), back_off, 1.0, OrderController.ARRIVE_RADIUS, false, true))
			_order_weapon({"type": "fire_at_will"})
		"ORBIT":
			var target_position: Vector3 = contact["position"]
			var out := Vector3(my_position.x - target_position.x, 0.0, my_position.z - target_position.z)
			var distance := out.length()
			out = out / distance if distance > 0.1 else -(me["forward"] as Vector3)
			# Where its gun points relative to me: cos of the angle (dot product).
			var gun: Vector3 = contact["turret_forward"]
			var gun_on_me := Vector2(gun.x, gun.z).normalized().dot(Vector2(out.x, out.z))
			# Weak spots: where its hull points relative to me (-1 = I'm dead astern).
			var hull: Vector3 = contact["forward"]
			var hull_on_me := Vector2(hull.x, hull.z).normalized().dot(Vector2(out.x, out.z))
			var weak_spots: bool = s.get("features", {}).get("weak_spots", false)
			var deck := weak_spots and Matchups.deck_gain(weapon, Units.profile(String(contact.get("unit", "")))) >= DECK_SEEK_GAIN
			# Its slow gun still reloading (a 5 s cannon): the run is on even with the turret on me.
			var reloading := weak_spots and _gun_ready_in(String(contact["name"])) >= ORBIT_RELOAD_WINDOW
			if _bursting and ((gun_on_me > ORBIT_BREAK_COS and not reloading) or distance < ORBIT_BREAK_RANGE):
				_bursting = false
			elif not _bursting and (gun_on_me < ORBIT_BURST_COS or reloading) and distance <= ORBIT_BURST_RANGE \
					and (not deck or hull_on_me <= -COS_ASTERN):
				_bursting = true
			if _bursting:
				# Swing the hull (and the fixed gun) onto it and fire until its turret catches up.
				why = TankBrain._join(why, "attack run")
				_order_move({"type": "face", "x": target_position.x, "z": target_position.z})
			else:
				why = TankBrain._join(why, "circling its slow turret")
				var side := 1.0 if think_offset % 2 == 0 else -1.0
				var tangent := Vector3(-out.z, 0.0, out.x) * side
				if deck and hull_on_me > -COS_ASTERN:
					# Circle the short way round to its stern.
					why = TankBrain._join(why, "for its engine deck")
					if tangent.dot(hull) > 0.0:
						tangent = -tangent
				var point: Vector3 = target_position + (out * ORBIT_LEAD_COS + tangent * ORBIT_LEAD_SIN) * ORBIT_RADIUS
				_order_move(_move_to(point, false, 1.0, 2.0))
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"CLEAR_LANE":
			if _lane_goal == null or game_match.tick - _lane_goal_tick > SimClock.TICK_RATE * 2:
				_lane_goal = _lane_spot(s, contact)
				_lane_goal_tick = game_match.tick
			var spot: Vector3 = _lane_goal
			why = TankBrain._join(why, "%s in the line of fire" % lane_blocker if lane_blocker != "" else "friend in the line of fire")
			if my_position.distance_to(spot) > SPOT_ARRIVE + 0.5:
				_order_move(_move_to(spot, false, 1.0, SPOT_ARRIVE))
			else:
				_order_move({"type": "face", "x": contact["position"].x, "z": contact["position"].z})
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"COVER_FIRE":
			var pair: Dictionary = s["cover_fire"]
			var hide: Vector3 = pair["hide"]
			var peek: Vector3 = pair["peek"]
			var travel := my_position.distance_to(peek) / PEEK_SPEED
			var loaded_by_then := float(me.get("reload", 1.0)) >= 1.0 - travel / maxf(float(weapon["reload"]), 0.01)
			var max_shield := float(me.get("max_shield", 0.0))
			var shield_ok := max_shield <= 0.0 or float(me.get("shield", 0.0)) >= max_shield * PEEK_SHIELD
			var waited := game_match.tick - _hiding_since if _hiding_since >= 0 else 0
			var window := _window_open(s, contact, travel + PEEK_EXPOSURE, waited)
			# Its gun is still reloading for the whole peek: a low shield doesn't matter, it can't shoot.
			if s.get("features", {}).get("reload_windows", false) and float(contact.get("gun_ready_in", 0.0)) >= travel + PEEK_EXPOSURE:
				shield_ok = true
			# Bait (reload windows): loaded, but its slow gun is loaded and watching the corner: flick out until it can see
			# me, duck straight back before its shell lands, and peek for real while it reloads.
			var baiting := loaded_by_then and shield_ok and not window and _baits < MAX_BAITS
			if bool(contact.get("visible", false)) and _bait_phase == "out" and _bait_seen < 0:
				_bait_seen = game_match.tick
			# N5 (CP4): a watching gun no longer fires the instant it sees the bait — its gunner lays first (up to ~1.6 s).
			# Ducking a sixth of a second after being seen (round 5's rule) now ducks before the shot, so the gun never fires, never reloads,
			# and the window the bait exists to open never opens (the tank "baited" for 10 s, then fought in the open).
			# So a seen bait stays out until the round is actually on its way (then ducks), at most BAIT_SEEN_MAX_TICKS.
			var shot_at := not (s.get("incoming", []) as Array).is_empty()
			if _bait_phase == "out" and ((_bait_seen < 0 and game_match.tick - _bait_tick >= BAIT_OUT_TICKS)
					or (_bait_seen >= 0 and (shot_at or game_match.tick - _bait_seen >= BAIT_SEEN_MAX_TICKS))):
				_bait_phase = "back"
				_bait_tick = game_match.tick
				_baits += 1
			elif _bait_phase == "back" and game_match.tick - _bait_tick >= BAIT_BACK_TICKS:
				_bait_phase = ""
			if _bait_phase == "" and baiting:
				_bait_phase = "out"
				_bait_tick = game_match.tick
				_bait_seen = -1
			# N5 (CP4): a gunner must hold the lay before the first round leaves (up to ~1.6 s at the edge of sight), and
			# the reload window closes sooner than that. A peek that ducks back when the window shuts never fires — the
			# tank sat in cover through 10 s of "peeks" with one shot. So once out on a real peek, stay until this gun has
			# fired, or PEEK_COMMIT_TICKS have passed.
			var committed := _peek_tick >= 0 and game_match.tick - _peek_tick < PEEK_COMMIT_TICKS \
					and ticks_since_fire > game_match.tick - _peek_tick and _bait_phase == ""
			if committed:
				why = TankBrain._join(why, "peek, laying the gun")
				_order_move(_move_to(peek, false, 1.0, SPOT_ARRIVE))
			elif _bait_phase == "out":
				why = TankBrain._join(why, "baiting its shot")
				_order_move(_move_to(peek, false, 1.0, SPOT_ARRIVE))
			elif _bait_phase == "back":
				why = TankBrain._join(why, "ducking its shot")
				_order_move(_move_to(hide, true, 1.0, SPOT_ARRIVE))
			elif loaded_by_then and shield_ok and window:
				_hiding_since = -1
				_baits = 0
				if _peek_tick < 0 or game_match.tick - _peek_tick >= PEEK_COMMIT_TICKS:
					_peek_tick = game_match.tick
				_order_move(_move_to(peek, false, 1.0, SPOT_ARRIVE))
				why = TankBrain._join(why, "peek")
			else:
				_peek_tick = -1
				if _hiding_since < 0:
					_hiding_since = game_match.tick
				why = TankBrain._join(why, "reloading in cover" if not loaded_by_then else ("shield low, in cover" if not shield_ok
						else "waiting for its reload"))
				# Back into cover with the front still toward the target.
				_order_move(_move_to(hide, true, 1.0, SPOT_ARRIVE))
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"BOMBARD":
			var target_position: Vector3 = contact["position"]
			var distance := my_position.distance_to(target_position)
			var nearest_threat := INF
			var threat_at := Vector3.ZERO
			for c in s["contacts"]:
				if c["visible"] and my_position.distance_to(c["position"]) < nearest_threat:
					nearest_threat = my_position.distance_to(c["position"])
					threat_at = c["position"]
			if nearest_threat < ARTILLERY_SAFE_DISTANCE:
				# Too close to someone's guns: back away from them, facing them.
				var away := (my_position - threat_at).normalized()
				_order_move(_move_to(my_position + away * (ARTILLERY_SAFE_DISTANCE - nearest_threat + 10.0), true))
			elif distance > float(weapon["preferred_max"]):
				_order_move(_move_to(target_position + (my_position - target_position).normalized() * float(weapon["preferred_max"])))
			elif tank.deploy_seconds > 0.0 and tank.deploy_ratio > 0.0 \
					and String(Units.profile(tank.unit_id).get("mount", "turret")) == "turret":
				# Dug in (or digging in): the turret follows the target. Turning the hull to face it is a drive command,
				# and held long enough it packs the battery up (combat's request (d); scenario_cp2: 3 pack-ups in 25 s).
				_order_move({"type": "stop"})
			else:
				_order_move({"type": "face", "x": target_position.x, "z": target_position.z})
			_order_weapon({"type": "target", "name": contact["name"], "fallback": true})
		"CONTEST":
			var control: Dictionary = s["control"]
			var center: Vector3 = control["center"]
			# Spread out inside the zone: each tank takes its own spot on a ring (stable per tank).
			var angle := TAU * float(think_offset % 8) / 8.0
			var spot: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * float(control["radius"]) * 0.45
			var nearest_visible: Variant = null
			for c in s["contacts"]:
				if c["visible"] and (nearest_visible == null or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible)):
					nearest_visible = c["position"]
			if my_position.distance_to(spot) > 4.0:
				_order_move(_move_to(spot))
			elif nearest_visible != null:
				_order_move({"type": "face", "x": nearest_visible.x, "z": nearest_visible.z})
			else:
				_order_move({"type": "stop"})
			_order_weapon({"type": "fire_at_will"})
		"SHADOW":
			var nearest_ally: Variant = null
			for ally in s["allies"]:
				if nearest_ally == null or my_position.distance_to(ally["position"]) < my_position.distance_to(nearest_ally):
					nearest_ally = ally["position"]
			var home: Vector3 = s["rally"]
			var behind: Vector3 = nearest_ally + ((home - nearest_ally) as Vector3).normalized() * ARTILLERY_TRAIL
			_order_move(_move_to(behind))
			_order_weapon({"type": "fire_at_will"})
		"SPOT":
			var nearest_visible: Dictionary = {}
			for c in s["contacts"]:
				if c["visible"] and (nearest_visible.is_empty()
						or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible["position"])):
					nearest_visible = c
			if not nearest_visible.is_empty():
				var threat: Vector3 = nearest_visible["position"]
				var away := my_position - threat
				away.y = 0.0
				var post: Vector3 = threat + (away.normalized() if away.length() > 0.1 else -(me["forward"] as Vector3)) * SCOUT_STANDOFF
				if my_position.distance_to(post) > 6.0:
					# Back off facing the enemy, so it stays in sight.
					_order_move(_move_to(post, (post - my_position).dot(threat - my_position) < 0.0))
				else:
					_order_move({"type": "face", "x": threat.x, "z": threat.z})
			else:
				var goal: Vector3 = s["objective"] if s["objective"] != null else s["enemy_base"]
				var freshest: Dictionary = {}
				for c in s["contacts"]:
					if freshest.is_empty() or int(c["age"]) < int(freshest["age"]):
						freshest = c
				if not freshest.is_empty():
					var toward: Vector3 = (freshest["position"] as Vector3) - my_position
					goal = (freshest["position"] as Vector3) - toward.normalized() * SCOUT_STANDOFF * 0.8
				_order_move(_move_to(goal))
			_order_weapon({"type": "fire_at_will"})
		"RECHARGE":
			if not (s["cover"] as Array).is_empty():
				var hide: Vector3 = s["cover"][0]
				_order_move(_move_to(hide, (hide - my_position).dot(me["forward"]) < 0.0))
			else:
				var threat_center := Vector3.ZERO
				var seen := 0
				for c in s["contacts"]:
					if c["visible"]:
						threat_center += c["position"]
						seen += 1
				var away := (my_position - threat_center / maxf(seen, 1)).normalized() if seen > 0 else -(me["forward"] as Vector3)
				_order_move(_move_to(my_position + away * RECHARGE_BACKOFF, true))
			_order_weapon({"type": "fire_at_will"})
		"RESUPPLY":
			var depot: Vector3 = s.get("resupply", s["rally"])
			if bool(me.get("in_resupply_zone", false)) and my_position.distance_to(depot) < Match.RESUPPLY_RADIUS * 0.6:
				_order_move({"type": "stop"})
			elif s.get("features", {}).get("retreat_to_cover", true) and TankBrain.withdraw_point(s) != s["rally"]:
				# Enemies seen close by a moment ago: back straight away from them first (stays in cover's shadow).
				_order_move(_move_to(TankBrain.withdraw_point(s), true))
			else:
				# Back in with the front armor toward any threat, drive in when it's quiet.
				_order_move(_move_to(depot, not s["contacts"].filter(func(c: Dictionary) -> bool: return c["visible"]).is_empty()))
			_order_weapon({"type": "fire_at_will"})
		"INVESTIGATE":
			_order_move(_move_to(contact["position"]))
			_order_weapon({"type": "fire_at_will"})
		"REGROUP":
			_order_move(_move_to(s["squad_center"]))
			_order_weapon({"type": "fire_at_will"})
		"ADVANCE":
			var goal: Vector3 = s["objective"] if s["objective"] != null else s["enemy_base"]
			if s["objective"] == null and (s["allies"] as Array).is_empty():
				# Combat's request (f): a lone unit with nowhere to be takes a side lane to the midfield before turning in on
				# the enemy base. On a point-symmetric arena a mirror opponent drove the mirror path, and the line between
				# two mirror positions always runs through the center crate: they passed 9 m apart unseen. So the lane is
				# on the same side of the map for both teams (to Green's right, Rust's left): they meet in it head-on.
				var home: Vector3 = s["rally"]
				var across := Vector3(goal.x - home.x, 0.0, goal.z - home.z)
				var length := across.length()
				if length > 1.0:
					var ahead := across / length
					var side := 1.0 if tank.team == Match.Team.GREEN else -1.0
					var lane: Vector3 = (home + goal) * 0.5 + Vector3(-ahead.z, 0.0, ahead.x) * LONE_LANE * side
					if (my_position - home).dot(ahead) < length * 0.5 and _flat(my_position).distance_to(_flat(lane)) > LONE_LANE_REACHED:
						goal = lane
						why = TankBrain._join(why, "side lane")
			_order_move(_move_to(goal))
			_order_weapon({"type": "fire_at_will"})
		"KEEP_SLOT":
			var squad: Dictionary = s["squad"]
			_order_move(_arrive_facing(_move_to(squad["slot"], squad["reverse"], squad["pace"])))
			_order_weapon({"type": "fire_at_will"})
		"HOLD" when s.get("order") != null and s["order"]["verb"] == "hold" \
				and _flat(my_position).distance_to(s["order"]["goal"]) > maxf(HOLD_TOLERANCE, Movement.settle_radius(tank.unit_id) + 1.0):
			# Pushed off the spot (or ordered to hold somewhere else): back onto it, front toward trouble.
			var spot: Vector3 = s["order"]["goal"]
			why = TankBrain._join(why, "holding")
			_order_move(_move_to(spot, (spot - my_position).dot(me["forward"]) < 0.0, 1.0, maxf(1.5, Movement.settle_radius(tank.unit_id))))
			_order_weapon({"type": "fire_at_will"})
		"HOLD":
			var nearest_visible: Variant = null
			# X1: what is in my sector of fire comes first, so a halted element covers all round instead of every
			# hull swinging onto the same contact. Something outside it still gets watched when the sector is empty.
			var nearest_in_sector: Variant = null
			var sector: Dictionary = s.get("element") if s.get("element") != null else {}
			for c in s["contacts"]:
				if not c["visible"]:
					continue
				if nearest_visible == null or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_visible):
					nearest_visible = c["position"]
				if not ElementFeed.in_sector(sector, my_position, c["position"]):
					continue
				if nearest_in_sector == null or my_position.distance_to(c["position"]) < my_position.distance_to(nearest_in_sector):
					nearest_in_sector = c["position"]
			var watch: Variant = nearest_in_sector if nearest_in_sector != null else nearest_visible
			if watch == null and sector.get("facing") != null:
				watch = my_position + (sector["facing"] as Vector3) * 20.0  # nothing in sight: keep watching my arc
				why = TankBrain._join(why, "covering its sector")
			# Nothing to watch: the facing the unit was TOLD (its K1 order's, else its post's) beats a doctrine squad's
			# default, which beats standing still. (An element's sector already came first above; a unit the player
			# ordered directly is detached from its element and has no sector.)
			var told: Variant = intended_facing()
			if watch != null:
				_order_move({"type": "face", "x": watch.x, "z": watch.z})
			elif told != null:
				_order_move(_face_intended_or({"type": "stop"}))
			elif s.get("squad") != null:
				var look: Vector3 = my_position + (s["squad"]["facing"] as Vector3) * 20.0
				_order_move({"type": "face", "x": look.x, "z": look.z})
			else:
				_order_move({"type": "stop"})
			_order_weapon({"type": "fire_at_will"})


## X3: the ground to hose to hold `contact` down. Laid on it (led a little, so a unit that is moving is walked into
## the fire rather than followed from behind) and then KEPT, so the rounds land in the same cells — that is what makes
## fire suppressive rather than merely aimed. Re-laid when the target has left it by SUPPRESS_REAIM or after
## SUPPRESS_REAIM_TICKS.
func _suppression_point(contact: Dictionary) -> Vector3:
	var predicted: Vector3 = contact["position"] + (contact["velocity"] as Vector3) * SUPPRESS_LEAD_SECONDS
	if _suppress_point == null or _suppress_for != String(contact["name"]) \
			or game_match.tick - _suppress_tick > SUPPRESS_REAIM_TICKS \
			or _flat(_suppress_point).distance_to(_flat(contact["position"])) > SUPPRESS_REAIM:
		_suppress_point = predicted
		_suppress_for = String(contact["name"])
		_suppress_tick = game_match.tick
	return _suppress_point


## X2: whether this unit keeps moving while it fights (CombatMotion). Not artillery (it deploys), not a squad holding a
## position, and only for brain variants with `combat_motion`.
func _moves_while_fighting(s: Dictionary) -> bool:
	if not s.get("features", {}).get("combat_motion", false) or tank.weapon["kind"] == Weapons.Kind.ARC:
		return false
	var squad: Variant = s.get("squad")
	return squad == null or String(squad["verb"]) != "hold"


## Seconds until a contact's gun is loaded again, when it's a slow gun (reload ≥ SLOW_GUN_RELOAD); 0 otherwise.
func _gun_ready_in(contact_name: String) -> float:
	var enemy := AiTickCache.tanks_by_name(game_match).get(contact_name) as Tank
	if enemy == null or float(enemy.weapon.get("reload", 0.0)) < SLOW_GUN_RELOAD:
		return 0.0
	return AiTickCache.gun_ready_in(game_match, enemy)


## X3 reload windows: whether now is a sensible moment to show myself to `contact` for `exposure` seconds: its gun is slow
## and still reloading for that long, or it isn't aimed at me, or I've waited PEEK_PATIENCE_TICKS already.
func _window_open(s: Dictionary, contact: Dictionary, exposure: float, waited_ticks: int) -> bool:
	if not s.get("features", {}).get("reload_windows", false):
		return true
	return float(contact.get("gun_ready_in", 0.0)) >= exposure or not bool(contact.get("watching_me", contact.get("aiming_at_me", false))) \
			or float(Weapons.profile(String(contact.get("weapon", ""))).get("reload", 0.0)) < SLOW_GUN_RELOAD \
			or waited_ticks >= PEEK_PATIENCE_TICKS


## How often this brain thinks with an enemy near: the team's difficulty when it sets one, else the variant's.
func _contact_think_hz(features: Dictionary) -> float:
	var level := int(Difficulty.for_team(tank.team)["think_ticks"])
	if level > 0:
		return SimClock.TICK_RATE / float(level)
	if features.has("think_hz"):
		return float(features["think_hz"])
	return SimClock.TICK_RATE / float(features.get("think_ticks", THINK_EVERY_TICKS))


## X3: whether this brain variant dodges incoming rounds.
func _dodges() -> bool:
	return bool(BrainVariants.for_team(tank.team).get("dodge", false))


## N5 (CP4): the distance inside which a crew may fire on its own judgement — the weapon's EFFECTIVE band, not its
## reach (Engagement.effective_range; the same expression, so this reads the same with or without combat's gate).
## Every "can my gun reach that far?" a DECISION asks must ask this: a heuristic reasoning about full reach against a
## rule reasoning about the band parks a unit where it may not shoot (combat measured a tank sitting 61 m from a scout
## for 45 s, 0 shots). Threat assessment — what can reach ME — keeps using the enemy's full `range`: they may be
## answering fire or spending a commander's long shot.
static func fire_band(weapon: Dictionary) -> float:
	return float(weapon.get("effective_range", weapon.get("range", 0.0)))


## X2 styles by chassis: a fixed gun aims with the hull, so it makes runs; a thick front wants to face the target, so
## heavy hulls angle; the rest circle-strafe.
static func motion_style(unit_id: String) -> String:
	var profile := Units.profile(unit_id)
	if String(profile.get("mount", "turret")) == "fixed":
		return CombatMotion.fixed_style  # round 7 (nav): "standoff" (shoot-and-scoot); "run" = round 3's attack runs
	if float((profile.get("armor", {}) as Dictionary).get("front", 0.0)) >= ANGLE_FRONT_ARMOR:
		return "angle"
	return "strafe"


## X2: the move order for fighting `contact` on the move: circle it in the weapon's band (CombatMotion), jinking to the
## other side now and then (heavy hulls right after firing, while they reload), and for fixed guns runs at its side and
## rear that break away when close. Falls back to facing the target when every direction is blocked.
func _combat_move(s: Dictionary, contact: Dictionary) -> Dictionary:
	var me: Dictionary = s["self"]
	var my_position: Vector3 = me["position"]
	var weapon: Dictionary = me["weapon"]
	var style := TankBrain.motion_style(String(me.get("unit", "")))
	var tick := game_match.tick
	var distance := _flat(my_position).distance_to(_flat(contact["position"]))
	if _strafe_side == 0:
		_strafe_side = 1 if think_offset % 2 == 0 else -1
		_jink_tick = tick + JINK_MIN_TICKS
	var jink_due := false
	match style:
		"angle":
			jink_due = tick >= _jink_tick + JINK_SPREAD_TICKS or (tick >= _jink_tick and ticks_since_fire <= THINK_EVERY_TICKS)
		"strafe":
			# Close in, jinks spoil a gunner's lead; at a long standoff they just look like rocking (a Lancer at 80 m).
			jink_due = distance <= JINK_RANGE and tick >= _jink_tick + (think_offset * 37) % JINK_SPREAD_TICKS
	# Round 7 (nav): a jink only buys anything against a gun with a flight time to lead (CombatMotion.jink_worth).
	jink_due = jink_due and CombatMotion.jink_worth(String(contact.get("weapon", "")))
	if jink_due:
		_strafe_side = -_strafe_side
		_jink_tick = tick + JINK_MIN_TICKS
	if style == "run":
		if _run_phase == "run" and distance <= CombatMotion.RUN_BREAK:
			_run_phase = "extend"
		elif _run_phase == "extend" and distance >= CombatMotion.RUN_RETURN:
			_run_phase = "run"
			_strafe_side = -_strafe_side  # come back in on the other flank
	# Outranging (a Lancer on a tank): standing where its gun can't reach and mine can, there's nothing to dodge. Hold still
	# and shoot, moving only if something is on its way or it closes in.
	var their_reach := float(Weapons.profile(String(contact.get("weapon", ""))).get("range", 0.0))
	if style != "run" and distance > their_reach + OUTRANGE_MARGIN and distance <= TankBrain.fire_band(weapon) \
			and (s.get("incoming", []) as Array).is_empty():
		why = TankBrain._join(why, "outranging it")
		return {"type": "stop"}
	# Short halt (slow guns): brake so the gun is loaded as the hull stops, fire from a standstill (moving spread, and
	# a turning hull drags the turret off), then move again while reloading. Never waits more than SHORT_HALT_MAX_TICKS.
	var reload_seconds := float(weapon["reload"])
	if float(me.get("reload", 1.0)) >= 1.0:
		_loaded_tick = tick if _loaded_tick < 0 else _loaded_tick
	else:
		_loaded_tick = -1
	var halt_reload := float(s.get("features", {}).get("short_halt_reload", SHORT_HALT_RELOAD))
	if style != "run" and reload_seconds >= halt_reload and distance <= TankBrain.fire_band(weapon):
		var ready_in := (1.0 - float(me.get("reload", 1.0))) * reload_seconds
		var braking := absf(tank.speed()) / maxf(tank.acceleration, 0.1)
		var incoming: Array = s.get("incoming", [])
		var about_to_be_hit := not incoming.is_empty() and CombatMotion.would_be_hit(my_position, tank.estimated_velocity,
				tank.estimated_velocity, incoming)
		var loaded_for := 0 if _loaded_tick < 0 else tick - _loaded_tick
		var halt_lead := float(s.get("features", {}).get("short_halt_lead", SHORT_HALT_LEAD))
		if ready_in <= braking + halt_lead and loaded_for <= SHORT_HALT_MAX_TICKS and not about_to_be_hit \
				and _window_open(s, contact, braking + SHORT_HALT_EXPOSURE, loaded_for):
			why = TankBrain._join(why, "short halt")
			return {"type": "stop"}
	# Re-plan every MOTION_REPLAN_TICKS unless something that changes the plan happened (a new round on its way, a
	# jink, a run phase flip, another target): the steer point is 12 m out, so a 0.2 s old plan still drives true.
	var motion_key := "%s|%d|%s|%d" % [contact["name"], _strafe_side, _run_phase, (s.get("incoming", []) as Array).size()]
	if not _motion_cache.is_empty() and _motion_cache["key"] == motion_key and tick - int(_motion_cache["tick"]) < MOTION_REPLAN_TICKS:
		why = _motion_cache["why"]
		return _motion_cache["order"]
	var cover_map := CoverMap.of(tank)
	var request := {"position": my_position, "forward": me["forward"], "speed": tank.max_forward_speed,
			"reverse_speed": tank.max_reverse_speed, "style": style,
			"target": {"position": contact["position"], "forward": contact["forward"], "velocity": contact["velocity"]},
			"band": [float(weapon["preferred_min"]), float(weapon["preferred_max"])], "side": _strafe_side,
			"phase": _run_phase, "map": cover_map,
			"friends": (s["allies"] as Array).map(func(ally: Dictionary) -> Vector3: return ally["position"]),
			"wheels": String(Units.stat(tank.unit_id, "locomotion", "tracks")) == "wheels",
			"min_turn_radius": float(Units.stat(tank.unit_id, "min_turn_radius_m", 0.0)),
			"velocity": tank.estimated_velocity, "incoming": s.get("incoming", []), "acceleration": tank.acceleration,
			"turn_rate_deg": rad_to_deg(tank.hull_turn_rate),
			"threats": TankBrain.threat_list(s["contacts"], my_position).slice(0, MOTION_THREATS),
			"target_busy": not bool(contact.get("aiming_at_me", false))}
	# X1: fight from your place in the formation. Circling 40 m out of the slot wins the duel and loses the element.
	var slot: Variant = TankBrain.element_slot(s)
	if slot != null:
		request["leash"] = {"center": slot, "radius": SLOT_LEASH}
		why = TankBrain._join(why, "in its slot")
	# X3 (L2): and don't manoeuvre through a beaten zone.
	var fields := _suppression_fields(game_match) if s.get("features", {}).get("avoid_beaten", true) else null
	if fields != null:
		var team := tank.team
		request["beaten"] = func(from: Vector3, to: Vector3) -> bool:
			return SuppressionFeed.beaten(fields, team, from, to)
	_incoming_count = (s.get("incoming", []) as Array).size()
	var clock := Time.get_ticks_usec() if OrderController.profiling else 0
	request["previous_index"] = _motion_prev_index  # round 7 (nav): commitment to last plan's direction
	request["previous_reverse"] = _motion_prev_reverse
	var result := CombatMotion.choose(request)
	_motion_prev_index = int(result.get("index", -1))
	_motion_prev_reverse = bool(result.get("reverse", false))
	if OrderController.profiling:
		profile_parts["motion"] = int(profile_parts.get("motion", 0)) + Time.get_ticks_usec() - clock
	if result.is_empty():
		return {"type": "face", "x": contact["position"].x, "z": contact["position"].z}
	if result.get("hold", false):
		# Round 7 (nav): a fixed gun inside its band stops and lays its hull on the target (Gunnery swings a stopped fixed
		# mount onto what it engages) instead of driving at it — the lead's "scouts are just running directly into their
		# targets and then they have to turn around to get a fix again".
		why = TankBrain._join(why, "holding at standoff")
		_motion_cache = {"tick": tick, "key": motion_key, "why": why, "order": {"type": "stop"}}
		return _motion_cache["order"]
	if result.get("dodging", false):
		why = TankBrain._join(why, "dodging")
	if result.get("beaten", false):
		why = TankBrain._join(why, "boxed in by fire")
	if bool(request["target_busy"]) and style != "run":
		why = TankBrain._join(why, "going for its side")
	match style:
		"run":
			why = TankBrain._join(why, "attack run" if _run_phase == "run" else "breaking away")
		"standoff":
			why = TankBrain._join(why, "moving to a firing position")
		"angle":
			why = TankBrain._join(why, "weaving, front armor on it")
		_:
			why = TankBrain._join(why, "circling")
	# A fixed gun on a run eases off inside its range: longer on target per pass (a scout's stream fired ~2.5 s a pass).
	var nose_on := (me["forward"] as Vector3).dot((Vector3(contact["position"].x, 0.0, contact["position"].z) - _flat(my_position)).normalized()) >= RUN_AIMED_COS
	var speed := RUN_FIRING_SPEED if style == "run" and _run_phase == "run" and distance <= TankBrain.fire_band(weapon) \
			and nose_on else 1.0
	_motion_cache = {"tick": tick, "key": motion_key, "why": why,
			"order": _move_to(result["point"], result["reverse"], speed, 1.0, true)}
	return _motion_cache["order"]


## Turn the hull toward the nearest visible enemy (front armor, and a fixed gun's aim), else `fallback`.
## Round 6 (the lead: "I couldn't tell what direction they were facing"): the facing this unit was TOLD to hold — the
## `facing` of its current K1 order, else the heading of the post its last order left it at (Orders.station: that
## order's facing, or the way it travelled). null when nothing says. K1 has carried `facing` since round 5; until round 6
## the brain never read it (OrderFeed passes verb, goal, target and speed only), so a unit told to face east faced north.
func intended_facing() -> Variant:
	if _order_source == null or tank == null:
		return null
	var unit_name := String(tank.name)
	if _order_source.has_method("current"):
		var raw: Variant = _order_source.call("current", unit_name)
		if raw is Dictionary and not (raw as Dictionary).is_empty():
			return TankBrain._direction_of((raw as Dictionary).get("facing"))
	if _order_source.has_method("station"):
		var post: Variant = _order_source.call("station", unit_name)
		if post is Dictionary:
			return TankBrain._direction_of((post as Dictionary).get("heading"))
	return null


## Turn to the intended facing if there is one, else `fallback`.
func _face_intended_or(fallback: Dictionary) -> Dictionary:
	var facing: Variant = intended_facing()
	if facing == null:
		return fallback
	var look: Vector3 = _flat(tank.global_position) + (facing as Vector3) * 20.0
	return {"type": "face", "x": look.x, "z": look.z, "told": true}


## [x, z] (or a Vector3) as a flat unit direction, or null.
static func _direction_of(value: Variant) -> Variant:
	var direction := Vector3.ZERO
	if value is Vector3:
		direction = Vector3((value as Vector3).x, 0.0, (value as Vector3).z)
	elif value is Array and (value as Array).size() == 2:
		direction = Vector3(float(value[0]), 0.0, float(value[1]))
	return direction.normalized() if direction.length_squared() > 1e-6 else null


static func _face_threat_or(s: Dictionary, fallback: Dictionary) -> Dictionary:
	var my_position: Vector3 = s["self"]["position"]
	var nearest: Variant = null
	for c: Dictionary in s["contacts"]:
		if c["visible"] and (nearest == null or my_position.distance_to(c["position"]) < my_position.distance_to(nearest)):
			nearest = c["position"]
	if nearest == null:
		return fallback
	return {"type": "face", "x": (nearest as Vector3).x, "z": (nearest as Vector3).z}


func _contact(s: Dictionary, contact_name: String) -> Dictionary:
	for c in s["contacts"]:
		if c["name"] == contact_name:
			return c
	return {}


## CLEAR_LANE's destination: the nearest of 16 nearby spots (two rings) that stands clear of obstacles, sees the
## target, and has no friend in the new line of fire; otherwise a sidestep away from the blocking friend.
func _lane_spot(s: Dictionary, contact: Dictionary) -> Vector3:
	var me: Vector3 = s["self"]["position"]
	var target: Vector3 = contact["position"]
	var map := CoverMap.of(tank)
	var friends: Array = (s["allies"] as Array).map(func(ally: Dictionary) -> Dictionary:
			return {"name": ally["name"], "position": ally["position"]})
	var best: Variant = null
	for ring: float in [LANE_SEARCH * 0.6, LANE_SEARCH]:
		for i in 8:
			var angle := TAU * i / 8.0
			var spot := me + Vector3(cos(angle), 0.0, sin(angle)) * ring
			if absf(spot.x) > ARENA_LIMIT or absf(spot.z) > ARENA_LIMIT or map.inside_any(Vector2(spot.x, spot.z), 2.4):
				continue
			if not map.clear_line(spot, target) or not FireLanes.in_line(spot, target, friends).is_empty():
				continue
			# Keep the range: the spot whose distance to the target changes least.
			var range_change := absf(spot.distance_to(target) - me.distance_to(target))
			if best == null or range_change < absf((best as Vector3).distance_to(target) - me.distance_to(target)) - 0.01:
				best = spot
		if best != null:
			return best
	var blocker: Vector3 = me
	for ally: Dictionary in s["allies"]:
		if ally["name"] == lane_blocker:
			blocker = ally["position"]
	var lane := Vector3(target.x - me.x, 0.0, target.z - me.z).normalized()
	var side := Vector3(-lane.z, 0.0, lane.x)
	if side.dot(blocker - me) > 0.0:
		side = -side
	return me + side * 6.0


## Where a tank breaking contact heads next: straight away from the nearest recently seen enemy that could
## still reach it (moving directly away from a threat keeps an obstacle between us: shadows widen with
## distance), bent toward home when home is roughly that way; the rally point once clear.
static func withdraw_point(s: Dictionary) -> Vector3:
	var me: Vector3 = s["self"]["position"]
	var rally: Vector3 = s["rally"]
	var nearest: Dictionary = {}
	for c: Dictionary in s["contacts"]:
		if int(c["age"]) > CONTACT_FRESH_TICKS * 2:
			continue
		var distance := me.distance_to(c["position"])
		if distance > float(Weapons.profile(String(c.get("weapon", "cannon")))["range"]) + 25.0:
			continue
		if nearest.is_empty() or distance < me.distance_to(nearest["position"]):
			nearest = c
	if nearest.is_empty():
		return rally
	var away := Vector3(me.x - nearest["position"].x, 0.0, me.z - nearest["position"].z)
	away = away.normalized() if away.length() > 0.1 else -(s["self"]["forward"] as Vector3)
	var home := Vector3(rally.x - me.x, 0.0, rally.z - me.z)
	if home.length() > 0.1 and home.normalized().dot(away) > 0.3:
		away = (away * 0.6 + home.normalized() * 0.4).normalized()
	var point := me + away * 20.0
	return Vector3(clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT), 0.0, clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT))


static func _move_to(point: Vector3, reverse := false, speed := 1.0, arrive := OrderController.ARRIVE_RADIUS,
		direct := false, to_safety := false) -> Dictionary:
	var order := {"type": "move_to", "x": clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT),
			"z": clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT), "reverse": reverse, "speed": snappedf(speed, 0.05),
			"arrive": arrive}
	if direct:
		order["direct"] = true
	if to_safety:
		# X3: this move IS the escape from the fire — don't let route avoidance second-guess it. A tank running for
		# cover is running through the beaten zone on purpose, and steering it sideways leaves it in the open
		# (measured: it stopped hiding at all, `ai_hurt_to_cover` first hidden -1 where it used to be 195 ticks).
		order["to_safety"] = true
	return order


## Round 8 (nav's contract, workstreams.md ba2c9adf): a move that ENDS somewhere the unit should be pointing a
## particular way carries it, so a wheeled hull rolls onto that heading on its last leg instead of arriving 45 degrees
## off and creeping round its spot (nav measured 6 s of shuffle on an IFV). Tracked and hover hulls ignore it and pivot
## as they always have, so this only ever adds the arc for hulls that cannot pivot.
func _arrive_facing(order: Dictionary) -> Dictionary:
	var facing: Variant = intended_facing()
	if facing == null or String(order.get("type", "")) != "move_to":
		return order
	order = order.duplicate()
	order["facing"] = [(facing as Vector3).x, (facing as Vector3).z]
	return order


## Whether a unit holding a player's post may start moving for `option`: back to its post (REGROUP/HOLD), with its
## element (KEEP_SLOT), or — under fire — into cover or away (TAKE_COVER, COVER_FIRE, RETREAT, RECHARGE, RESUPPLY, and any
## escape the brain marks `to_safety`). Never for a fight of its own choosing.
static func held_may_move(option: String, under_fire: bool, to_safety: bool) -> bool:
	if HELD_RETURNS.has(option):
		return true
	return under_fire and (to_safety or HELD_UNDER_FIRE_MOVES.has(option))


## A point this unit may drive to on its own: inside PLAYER_POST_LEASH of where the player left it. Anything further is
## pulled back onto the edge of that circle, so a unit fights from the ground it was given instead of being drawn across
## the map by whatever it can see.
func _within_post(point: Vector3, lead := PLAYER_POST_LEASH) -> Vector3:
	if _player_post == null:
		return point
	var post: Vector3 = _player_post
	var offset := Vector3(point.x - post.x, 0.0, point.z - post.z)
	var distance := offset.length()
	if distance <= lead or distance < 0.01:
		return point
	return post + offset / distance * lead


## Re-issuing an identical order would reset path following every think; skip near-duplicates.
## Round 8: a wheeled hull with a turret — its gun aims without the hull, and the hull cannot pivot (TankBrain._order_move).
static func turret_carries_aim(unit_id: String) -> bool:
	if not _turret_wheels.has(unit_id):
		_turret_wheels[unit_id] = Units.exists(unit_id) \
				and String(Units.stat(unit_id, "locomotion", "tracks")) == "wheels" \
				and String(Units.profile(unit_id).get("mount", "turret")) == "turret"
	return bool(_turret_wheels[unit_id])


static var _turret_wheels := {}


func _order_move(order: Dictionary) -> void:
	# The player's units hold until ordered (round-5 ruling; product constraint #4). A unit holding the post the player
	# left it at may shoot, turn and — under fire — take cover or escape, and it goes back to its post; it may NOT start
	# moving on its own judgement (a flank, an advance, a circle). Until round 6 nothing enforced this: a held unit sat
	# still only because a range heuristic in _combat_move happened to return "stop", and when CP4 changed the ranges it
	# held 21 s and then flanked (lesson 47). This is the rule, stated where every move order passes.
	if _player_post != null and String(order.get("type", "")) == "move_to" and not held_may_move(
			String(choice.get("option", "")), _held_under_fire, bool(order.get("to_safety", false))):
		held_moves_refused += 1
		order = _held_face

	# Round 8 (the lead: "the semi trucks are yawing in place (should be impossible, they're not a tracker vehicle)"): a
	# wheeled hull can only turn on the spot by creeping forward and back (TankMotion's multi-point turn), and the brain
	# asked it to constantly: a held unit's refused advance became a turn toward the threat, 85% of the ticks of the
	# player's rigs and tankers with an enemy in sight (squad's probe, round 8). A hull whose gun turns on its own has no
	# reason to: it stops and the turret carries the aim, as a real truck does. A facing the PLAYER gave ("told") is one
	# turn that settles, and is still honoured; a fixed gun's hull IS its aim, so it still faces.
	if String(order.get("type", "")) == "face" and not bool(order.get("told", false)) and turret_carries_aim(tank.unit_id):
		faces_declined += 1
		order = {"type": "stop"}

	# The player's post leashes everything this unit decides for itself. An escape (cover, breaking contact) gets a
	# longer lead but not a free one: a unit that runs all the way home has left the ground the player gave it, which is
	# what "I have no control" looks like from the outside.
	if _player_post != null and order["type"] == "move_to":
		var lead := PLAYER_POST_LEASH * (ESCAPE_LEASH_FACTOR if bool(order.get("to_safety", false)) else 1.0)
		var inside := _within_post(Vector3(order["x"], 0.0, order["z"]), lead)
		order = order.duplicate()
		order["x"] = inside.x
		order["z"] = inside.z
	if order["type"] == move_order.get("type") and order.get("reverse", false) == move_order.get("reverse", false) \
			and order.get("direct", false) == move_order.get("direct", false) \
			and absf(float(order.get("speed", 1.0)) - float(move_order.get("speed", 1.0))) < 0.1 \
			and is_equal_approx(float(order.get("arrive", 0.0)), float(move_order.get("arrive", 0.0))):
		if not order.has("x"):
			return
		if Vector2(float(order["x"]) - float(move_order["x"]), float(order["z"]) - float(move_order["z"])).length() < 2.0:
			return
	set_orders(order, null)


func _order_weapon(order: Dictionary) -> void:
	# X1 sectors of fire: a unit holding a formation slot engages inside its own arc first, so the element covers all
	# round instead of every gun swinging onto whatever is nearest (OrderController._nearest_shootable).
	if element.get("facing") != null and ["fire_at_will", "target"].has(String(order.get("type", ""))):
		order = order.duplicate()
		order["sector"] = element["facing"]
		order["sector_cos"] = SECTOR_COS
	# Round 6 (X5, N5): a base of fire is authorised to reach past its effective band. That is the point of one — an
	# element told to support by fire that holds its fire until the enemy is inside 45 m is supporting nothing. Combat's
	# fire discipline (CP4) holds fire outside the band unless the order says `long_shot`; only the commander's task
	# spends it, never a crew's own judgement.
	if String(element.get("task", "")) == "support_by_fire" and ["fire_at_will", "target", "suppress"].has(String(order.get("type", ""))):
		order = order.duplicate()
		order["long_shot"] = true
	# X7: an ambush that has not been sprung holds its fire, whatever its crews can see: one early shot and the kill zone
	# is empty. The element springs it (Drills: an enemy in the kill zone, or the ambush found), and then every gun fires.
	if ElementFeed.holds_fire(element) and ["fire_at_will", "target", "suppress"].has(String(order.get("type", ""))):
		order = {"type": "hold_fire"}
	if not order.recursive_equal(weapon_order, 2):
		set_orders(null, order)
