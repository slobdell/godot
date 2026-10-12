# Stream: brains (artillery shells from the side you drag; a drawn flank is carried out; squads not ordered into the enemy)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 27 direction* and **Round 28
> direction** (his calls 3 and 4), `_agents/doctrine.md`, `_agents/workstreams.md` *Round 28*, and round 27's brains
> report (`streams/archive/round27/brains.md`: B0, the live-flank write-up, the calibration, the lessons). **You own:**
> `game/ai/**` EXCEPT traffic's, manoeuvre's, scout's and native's carve-outs (C28 list), `game/tactics/**`,
> `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`,
> `tests/test_ai*.gd` (not combat_motion's), `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
> `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **The C++ (C28.2):** `decide`,
> `build_situation`'s core, the TacticalQuery functions run in C++: a change there goes to native as a diff first.

## The lead's direction

Round 27 gave every armed order a drawn facing and attack a drawn side (press on an enemy, drag, release).
**Round 28, his calls (2026-10-12):**
- **Artillery: SHELL FROM HIS SIDE** — "a drag means the same thing for every unit."
- **A drawn flank onto a stronger squad: SWING ROUND ANYWAY** — "you chose the flank; it carries out the order even if
  it costs crews."

What he will notice: drag an attack side and the squad goes round to it in a live fight, artillery included, instead of
turning it into a chase or a charge.

## Where things stand (main `ecc0d6e0`, green)

- B0 (round 27): an attack honours `task["approach"]` against a passive target (orders' probe 12/12). In a LIVE fight it
  reached the side 0/18 in every arm (round 27's write-up): (1) the target shuffling ≥ 2 m/s turned the attack into a
  PURSUIT, which has no side; (2) a near-ambush by the target's squadmates sprang assault-through and charged the middle;
  (3) circling at the crews' own reach (35 m for MG trucks) sat inside the enemy's guns. The parked fix
  (`lab/brains-flank-live`) fought WORSE than B0's rule. Yet the shipped drawn gesture beats a clicked attack on the even
  roster (kills 15 v 10, n = 18).
- Artillery backs off to its 68 m standoff and half-follows a drawn side (36–44° off at 66–71 m).
- Scout's census: 254 of 365 enemy contacts happened under an ordered MOVE (squads ordered into the enemy).
- His bridge 108 is 106/108 since round 26's tail (one law_tank 3.5–6.8 s at the rim; all cross).
- Instruments: `make flank-probe`, `flank-clip`, ApproachStage `--live/--moving`, the calibration rosters (5 gang gun
  trucks v one holding Law IFV is the even one), the every-crew arrive line.

## Backlog (in order)

**B1 — a drawn flank is carried out (his call 4).** A new design, not a threshold: while an element has a drawn approach,
the element's plan owns the approach until it is on the side (or the target is dead or truly fleeing, ≥ 6 m/s sustained):
the crews drive round at a stand-off outside the enemy's reach where the ground allows, fire on the move, and do not
switch to pursuit or assault-through on the target's own squad. Measure on (a) the even roster (calibrated), (b) a
stronger enemy squad (he chose: swing round anyway), (c) a target under the CPU commander (moving).
**Bar (to the orchestrator before the numbers; check the measuring point against each arm, lesson 297):** on side within
35° in ≥ 12/18 on (a) and ≥ 9/18 on (c); (b) on side reported with losses (his call accepts losses); side/rear hit share
up v clicked; clicked attacks unchanged. Fresh seeds for the judged run. Not declared if the default path (no approach) is
byte-identical.

**B2 — artillery shells from the drawn side (his call 3).** An artillery element with a drawn approach takes its firing
position on that side at its standoff. Bar: within 35° of the side in ≥ 15/18, time to first round ≤ +10 s v clicked.

**B3 — squads ordered into the enemy.** Trace scout's census (254/365 contacts under an ordered MOVE; seed 5, parade, law v
condemned, t 14–30 s: Rust_Eyes5/6 ordered MOVE into Green_Sirens/Hunters around (0,0)). Is the CPU commander ordering
moves through the enemy, or the player's attack-move? Fix in its own declared change if it's a rule.

**B4 — his bridge 106/108.** Bisect `eb987e87` (108/108) → `090b345d` (106) on the two cells (seed 2: green t5, rust t9;
`bridge-series` invocation in round 27's workstreams); fix the cause.

**B5 — stretch:** pictures for him of 8 m off a slot v 3.5 m (is 8 m too loose for a formation's look?), and support by
fire's wheeled-turret line if manoeuvre's trace hands it to you.

## How to verify

`make remote T=check` (builder0 only); `make flank-probe`, `flank-clip` (render one for him when B1 passes, the same seeds
before/after), the ApproachStage arms, `bridge-pooled` and the 108, the arrive series; pool over start ticks
{1,3,6,8,11,16}; fresh seeds after tuning.

## Don't touch

Traffic's, manoeuvre's and scout's carve-outs; `native/**`.

## Waiting on the lead

Nothing: his calls are made.

## Status

_Not started._
