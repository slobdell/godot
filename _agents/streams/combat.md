# Stream: combat (seeing an enemy is not the same as opening fire)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *Units*, *Match rules*), [../workstreams.md](../workstreams.md) (you own **N5**, **K2**,
> **K3** data, **L2**, **L3**, **C1–C4**), [../balance.md](../balance.md), and your round-5 report in
> [archive/round5/combat.md](archive/round5/combat.md) with its saved results in
> [references/combat/](references/combat/).
>
> **You own** `game/units/`, `game/combat/`, `game/match/`, `game/ai/doctrine.gd` (the army-JSON loader, C2), `game/tank/` **except `tank_motion.gd`** (that moves to nav
> this round: it is the plant nav's controller regulates; its *data fields* stay yours),
> `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`.

## The lead's direction (2026-09-18, verbatim)

> *"The long range of the weapons is also I think making the game unplayable (units see each other and then everyone
> just starts firing)."*

He said a version of this in round 5 too (*"I can't tell if perhaps the vehicles have too much range, but when I play
the game now it's just these 2 masses shooting at each other"*). It did not land. **It is this round's CP4, it lands
once, and it lands early.**

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**The mechanism behind his sentence is real and it is one line.** `OrderController._shootable()`
(`order_controller.gd:734-747`) admits a target if it is *inside the weapon's range and has a clear physics line of
sight* — and the comment there records that the `seen` (spotted) test was found unused and **removed**. So a gun does
not require the contact to be acquired, tracked, or even spotted. There is no acquisition step between "exists on the
other side of the map with nothing in the way" and "shoot at it". The trigger is
`cmd.fire = _clear_to_fire(in_range and aimed and tank.ready_to_fire(), aim)` (`:710`).

The second half is that **`effective_range` equals `range` for every core weapon**, so there is no band where a shot
is legal but bad:

| weapon | range | effective | preferred band | damage | reload |
|---|---|---|---|---|---|
| `cannon` | 70 | 70 | 20–45 | 320 | 5.0 s |
| `autocannon` | 60 | 60 | 15–45 | 15×4 | 1.8 s |
| `laser` | 90 | 90 | 76–86 | 22 | 0.5 s |
| `machine_gun` | 45 | 45 | 12–35 | 3.5 @10/s | 0.1 s |
| `mortar` | 160 (min 42) | — | 60–140 | 140, splash 9 | 4.5 s |
| `flamethrower` | 20 (cone 30°) | — | 6–16 | 55 dps | — |

Faction weapons reach further still (`guided_missiles` 170, `gas_rockets` 150, `catapult` 120, `railgun` 110).

Sight radii (`units.gd`) run 55–135 m: tank **62**, scout 110, law_scout 125, syn_scout 135, syn_tank 105.
`Match.SENSOR_RANGE` is the tank's 62 m; contacts are remembered 12 s. Suppression cuts sight 40%.
Accuracy already degrades with range (`RANGE_SPREAD_FACTOR 3.0`, `MOVING_SPREAD_FACTOR 1.5`) — it is not enough to
stop anyone shooting.

**The measured consequence:** median hit range 39–43 m on *every* arena regardless of terrain, and flanking routes
using 4–5% of unit-time. The fight is decided at first contact, everywhere, always.

## Backlog (in order)

**X1 — the engagement envelope (N5, CP4). Do this first and land it once.** Make seeing and shooting two different
things:
- **Acquisition is a real step.** A weapon may only engage a target the unit has *acquired* — spotted (or handed a
  contact by a spotter), tracked for some time, still remembered. Put the `seen` test back, deliberately and with a
  design behind it, and give acquisition a duration so a contact at the edge of sight is not instantly a target.
- **An effective band that means something.** `effective_range` becomes genuinely shorter than `range`: beyond it a
  shot is legal but unrewarding (spread, penetration falloff), and the AI's own rule prefers to close. The
  recommendation is a real gap — effective around 55–65% of maximum for direct-fire weapons — but **measure rather
  than accept that number.**
- **Fire discipline.** A unit should not open up on the first thing it can technically reach. Hold fire until inside
  effective range unless ordered otherwise, or unless the target is worth a long shot.
Then measure the before/after on the configuration players actually get (faction armies, 30 a side, control point on,
default flags): median hit range, time to first shot, time to first kill, match duration, flanking-route unit-time,
and the faction win matrix. **Report the sample size** and name the commit and machine (lesson 26 exists because a
number went to the lead that was 18 shells).

**Tell the orchestrator the day X1 merges.** Every other stream re-runs its measurements after it, and nobody may
publish a number that straddles it.

**X2 — closing has to be survivable.** If you shorten engagement without changing anything else, the side that closes
dies on the way in and the game becomes "hold the longest stick". Check, and fix what you find: cover actually blocks
(arena's props), suppression actually buys movement (L2 — it was built for exactly this), smoke or speed or armour
gives an approach a chance, and the round-5 `break_contact` finding (doctrine went 91-29 without it) is not being
re-created by the new ranges.

**X3 — the arena is sized for the old ranges.** Half-size 121 m with 70 m cannons means two spawns are barely two
engagements apart. Once X1 lands, check with arena whether the map scale still fits, and say so with numbers rather
than leaving it implied.

**X4 — the gangs' 23%.** Still open from round 4, twice deferred. Road gangs win 23% against Condemned 70%, Law 63%,
Syndicate 47% (5 seeds, pre-Jolt, pre-30 Hz, pre-everything — **re-measure before tuning anything**). Two real defects
were fixed and neither moved it. With engagement ranges changing under it, re-run `make faction-matrix SEEDS=5
TIME=150` *after* X1 and treat the old number as history.

**X5 — the duplicated Lancer.** The Condemned `lancer` and the Syndicate `syn_lancer` share a role; the lead was asked
and hasn't ruled. Propose which faction loses it, with the roster reasoning, and put it in your Status for the
orchestrator to relay.

**X6 — the scout's counter.** `good_vs` claims must be real in the mechanics; `scout > lancer` still has no mechanic
behind it. Give it one or remove the claim (ai asked for this in round 4; it is still owed).

**X7 (stretch) — weak spots and armour facing, now that closing matters.** Flanking is only worth the risk if a rear
or side hit pays. Check that `Armor.penetration_multiplier` and the weak-spot rules are doing visible work at the new
ranges, and make the payoff legible (feel draws the cue; you provide the event).

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make faction-matrix`, `tools/match_series.py`, `make matches`, `combat_duel.py` — always in the players'
  configuration, always with the sample size stated.
- **Play it** (`make skirmish`) and ask the lead's question: does a fight start at a distance where anything but
  shooting is still possible?
- `make determinism` and the sim baseline: **yours to move, on purpose**, with the reason in the same commit
  (`make remote T=sim-baseline-record` on builder0, twice, to confirm it repeats).
- Balance numbers are spread across `weapons.gd` (damage, reload, range, spread), `tank.gd` (`max_health`) and
  `match.gd` (`SENSOR_RANGE`, arena size) — trip-up 33. Re-measure pace and re-run the fairness control after any of
  them.

## Don't touch

`game/ai/**` (nav's and squad's) **except `game/ai/gunnery.gd`, which becomes yours**: nav's X1 splits
`order_controller.gd` into movement (theirs) and gunnery (yours) so the firing decision lives with the stream that
owns the firing rule. Until that split lands, ask nav for the edit rather than making it — and agree the seam in
writing first. Also: `game/control/` `game/ui/` `game/camera/` (control's), `arenas/` `game/arena/` (arena's),
`game/theme/**` (feel's), `game/tank/tank_motion.gd` (nav's).

## Waiting on the lead

1. **The Lancer** (X5): which faction keeps it. Not blocking — propose and continue.

## Status

_The worker keeps this current._
