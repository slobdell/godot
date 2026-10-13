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

**Plan (2026-10-12, in order; start = stream `c6e32d03`, covered by main's green `94b5fc0d`, docs-only since):**
1. **Instrument first (B1/B2):** an `approach-trace` target, and a measuring point checked against every arm (lesson 297:
   round 27's "first crew within 50 m" fell inside the parked fix's own circle). Add a second, arm-independent reading:
   the element's bearing off the drawn side over the time its crews actually hit the target (hit-weighted), beside
   `reach_off_deg`. Trace one live run per arm before designing.
2. **B1** a drawn flank is carried out (DECLARED; bar to the orchestrator before the numbers; tuning seeds 4–6, judged on
   fresh seeds).
3. **B2** artillery shells from the drawn side (its standoff ring on the drawn side; same machinery as B1).
4. **B3** trace scout's census (who orders the MOVE into the enemy).
5. **B4** bisect his bridge 108 → 106.
6. **B5** stretch pictures.
Decisions: B1 before B2 because B2 reuses B1's "the plan owns the approach" state; instrument before either because the
last round's verdict on the live flank was a measuring-point error as much as a behaviour one.

### B1 — in progress (DECLARED; bar accepted by the orchestrator 2026-10-12 ~19:35)
**Bar (sent before numbers; accepted with a fight guard):** measuring point = per run, the MEDIAN HIT's bearing on the
target's hull (impact point v the target's centre that tick) within 35° of the drawn side (the same reading for every
arm; `reach_off_deg` reported beside it, now from the target's real position). Fresh seeds 7–9 × ticks
{1,3,6,8,11,16}, n = 18 an arm (tuning 4–6): (a) even roster (5 gang_ifv v 1 holding law_ifv) ≥ 12/18; (c) the same
target under the CPU commander (`--moving=on`) ≥ 9/18; (b) the Law squad of five: reported with losses. Side/rear share
≥ clicked; clicked byte-identical. Fight guard on (a), (c): kills ≥ clicked − 2, alive ≥ clicked − 0.5 mean. Partial:
(a) passes and (c) misses but beats clicked by ≥ 5 → ship, (c) partial. Plus `flank-probe` on 3 fresh seeds and a
`flank-clip` before/after on one seed where B1 comes round (what he judges).
**Trace (stream `ac3fe5e4`, builder0, even roster seed 4 t1):** B0 rounds at its OWN reach (gun trucks 35 m, inside the
IFV's 60 m); "in" at 12 s 29° off; then a near ambush by the target itself → 30 s of assault-through past it: killed
46.7 s, 2 alive v clicked 19.9 s, 4 alive.
**Tuning, even roster, seeds 4–6 (builder0, n = 18 an arm):**
| arm | commit | on side (median hit ≤ 35°) | median hit | kills | alive | side/rear share |
|---|---|---|---|---|---|---|
| clicked | `ca34bf25` | 0/18 | 68.2 | 10 | 2.33 | 0.81 |
| B0 (`--approach-carry=off`) | `44accd87` | 1/18 | 89.1 | 14 | 2.78 | 0.76 |
| B1 v1 (ring wide of the squad's guns, no pursuit < 6 m/s, no near ambush by the target's squad) | `ca34bf25` | 0/18 | 52.1 | 12 | 2.28 | 0.78 |
v1's rows: a crew within 50 m at ~7 s 56° off (a five-wide line rides the 70 m ring with its inner crews ~28 m inside
it), "in" at 11–13 s, then the free `attack` fight circles the target. v2 (`cba5e063`): round in a column; once round, a
firing line on the drawn side (support-by-fire standoff, hold + fire at will); contact drills yield for the whole flank.

