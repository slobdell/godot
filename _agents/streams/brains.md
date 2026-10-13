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
| B1 v2 (column round the ring; once round, HOLD a firing line on the side) | `cba5e063` | 16/18 | 27.3 | **1** | **1.44** | 1.00 |
| B1 v3 (once round: crews on the side within 40° (60 kept) and in reach attack freely; off it, back to its place) | `896f744c` | 13/18 | 33.9 | 11 | 2.11 | 0.93 |
| B1 v4 (pursuit only when the target FLEES ≥ 6 m/s away, 2 s, for the whole flank) | `c6cc7b6f` | 13/18 | 33.9 | 11 | 2.11 | 0.93 |
(c) moving, seeds 4–6: clicked 0/18 (90.2°), killed 18/18, alive 4.83; v3 0/18 (every run a pursuit: the CPU's lone IFV
drives AT the squad at 10.5 m/s); v4 8/18 (35.4°), killed **12**/18, alive **2.61** (fails the fight guard: three of five
crews chased line places sliding with the target for ~15 s). (b) Law squad of five, v3: on side by hit 3/18 (10 runs
hit at all), by reach 14/18; his squad wiped (0.39 alive v clicked 0.33), target killed 1 v 2 — his call accepts it.
v5 (`4d11c9f4`): once round, every crew on the side attacks whatever its distance.
v1's rows: a crew within 50 m at ~7 s 56° off (a five-wide line rides the 70 m ring with its inner crews ~28 m inside
it), "in" at 11–13 s, then the free `attack` fight circles the target. v2 (`cba5e063`): round in a column; once round, a
firing line on the drawn side (support-by-fire standoff, hold + fire at will); contact drills yield for the whole flank.

**Ruling on (c) (the orchestrator, C28.5, 2026-10-12 ~22:50):** the guard stays on (c); a target charging the squad
inside the crews' reach latches "in" and the attack fights where it is (`--approach-latch=off`); on-side on (c) is
reported. Implemented `f6190f57`, fixed `f3a0145d` (the latch decided before the pursuit rule reads the round).

**B1 JUDGED — DOES NOT SHIP** (`f3a0145d`, builder0, fresh seeds 7–9 × {1,3,6,8,11,16}, n = 18 an arm; run from a scratch
worktree checked out at exactly that commit; rows in `references/round28/brains_b1_judged_*.jsonl`):
| roster | arm | on side (median hit ≤ 35°) | median hit | killed | alive | side/rear | verdict |
|---|---|---|---|---|---|---|---|
| (a) even | B1 | **10/18** | 33.2 | 10 | 2.00 | 0.87 | bar 12/18 FAILS; guard passes |
| (a) even | clicked | 0/18 | 67.8 | 4 | 1.50 | 0.77 | |
| (c) moving | B1 | 4/18 | 43.0 | **10** | **2.39** | 0.64 | guard FAILS (kills ≥ 16, alive ≥ 4.39) |
| (c) moving | clicked | 0/18 | 93.3 | 18 | 4.89 | 0.76 | |
| (b) Law five | B1 | 0/18 (7 runs hit at all); by reach 14/18 | 45.3 | 0 | 0.00 | — | reported |
| (b) Law five | clicked | 0/18; by reach 0/18 | 131.2 | 0 | 0.00 | 0.85 | |
**PARKED (the orchestrator's ruling, no v8: changing only the latch leaves (a) as judged, and re-judging it on new seeds
would be seed-shopping).** Branch `lab/brains-r28-flank` = `f3a0145d`. On the stream `8008df0a`: `APPROACH_CARRY` off by
default (`--approach-carry=on` brings B1's rule back for any element); every element is B0's rule again EXCEPT a battery,
which carries its approach through `APPROACH_BATTERY` (B2).
**Round-29 item (what the data says):** (a) beats clicked clearly (on side 10 v 0, kills 10 v 4, alive 2.00 v 1.50) —
the design is close, short of the bar; (c)'s latch should key on the TARGET's reach of a crew (it stops at 45–60 m to
shoot), not the crews' own; (b) is a wipe either way (a balance matter more than a flank one: five gun trucks v a Law
squad of five). Tuning history (v1–v6) is in the table above; what helped: a column on the ring, a wide ring, the side
sector fight; what didn't: a held line (1 kill in 18), free attacks at any distance, a close ring for a charging target.
Why (c) fails: the latch needs the target inside the CREWS' reach (35 m × 1.15) but the charging IFV stops at its own
45–60 m to shoot, so the trucks are shot while going round. Proposed to the orchestrator: one last attempt (latch on the
target's own reach of a crew), judged on new fresh seeds 10–12; else park on `lab/brains-r28-flank`.

### B2 — PARKED (no judged run, the orchestrator's ruling; `lab/brains-r28-battery` = `88b6a724`)
Tuning, seeds 4–6, builder0, n = 18 (`--live=on --his=artillery,artillery,artillery --theirs=law_ifv`), v5 `88b6a724`:
fires from the side 18/18 (median shooter bearing 28.2°), alive 3.00 = clicked 3.00, but the FIRST ROUND at 25.8 s v
clicked 2.3 s (+23.5; the cut-off was +15). Three traced fixes on the way, all round-29 material: (1) on a named move a
mortar that may fire deploys and never leaves; (2) a plain move fires at will on contact, which deploys it too (a
battery relocating now holds fire: `Element.relocating` → ElementFeed → TankBrain MOVE); (3) a column whose heading
was re-laid from the moving centre swung round its post and re-sent every crew, and forming a column from abreast
cost ~9 s. What is left is distance: ~90 m at ~4 m/s on a 90° swing. His question (on the calls page, the
orchestrator's): shell from where it stands while it drives round, or accept a ~20–25 s wait.
**B1 and B2 game code is OFF the stream** (`3e2f6e13`: game/ == main's); the tooling stays.

### B3 — squads ordered into the enemy: FOUND and FIXED (DECLARED)
**Who:** the CPU COMMANDER, not the player (`make recon-probe`, seed 5 Parade, stream `7840452b`): at t 7 s
`ElementCommander.think` re-tasks both Rust recon squads to `screen` a point 45 m short of the enemy focus
(`_toward(centre, focus, SCREEN_AHEAD_M)`), 34–36 m from the nearest enemy; the point then holds while the enemy
advances onto it (point-to-enemy 34 → 1 m by t 17) and the crews keep driving to their places on that line (MOVE
"ordered") into the enemy — the census's contacts at (0, −11).
**Fix (`ac237a0e` + `b95a3d6e`):** with an enemy known, the recon screen stands `SCREEN_STANDOFF_M` =
TankBrain.SCOUT_STANDOFF (85 m) off the enemy NEAREST it, on its own side; re-aimed at once when an enemy comes within
0.6 × that of the line (never to a point within 10 m of the one it holds). `--screen-standoff=off` is the old rule.
Tools: `make recon-probe`, `make contact-census` (every unit's enemy hull contacts by option and role, recon deaths,
screen re-tasks, survivors, both arms).
**Judged** (`b95a3d6e`, builder0, fresh showmatch seeds 13–24, 180 s, n = 12 paired; bar accepted before the numbers):
| | standoff (new) | old rule |
|---|---|---|
| enemy hull contacts, every unit | **129** | 339 (−62 %) |
| … under an ordered MOVE | **28** | 111 (**−75 %**; bar ≥ 50 %) |
| by role: scout / ifv / tank / support / suppressor / artillery | 47 / 30 / 31 / 14 / 4 / 3 | 122 / 70 / 69 / 38 / 32 / 8 |
| recon deaths (of 89 recon crews) | 55 | 60 (not up) |
| winning side | the same in all 12 seeds | |
| survivors green / rust (sum) | 92 / 89 | 97 / 84 |
| screen tasks per recon squad-minute | 6.42 | 4.03 (+59 %: one about every 9 s, not every think) |
Seed 5 (the traced one, tuning): contacts 241 → 7, under MOVE 119 → 1.
**B3 GREEN, merge here: `b95a3d6e`** (builder0, `make check exited 0`, 2522 passed / 0 failed, 25 targets ALL JUDGED,
sim-baseline UNMOVED: the baseline armies run no CPU recon screen). Cost line (C28.4): one nearest-contact scan per
recon element per commander think (1 Hz), not readable at 25 a side.

### B4 — his bridge 106/108: BISECTED, fix candidate (DECLARED)
builder0, his two cells (seed 2: green t5, rust t9; `bridge-series BRIDGE_ARMS=on BRIDGE_SEEDS=2 BRIDGE_TICKS="5 9"`):
47b8527b, f193bcb8, 2e2715e4 PASS 4/4; **7baffe24** (round 26's brains merge: a heading given, taken away or turned
> 20° re-issues a crew's order) and 090b345d FAIL (rim 4.1 / 6.8 s, all cross). Confirm on today's code (`b95a3d6e`):
4/4 with `--reissue-heading=off`, 2/4 without. **Fix `254fd98f`:** a heading change re-issues only when the TASK's
drawn facing changed since that crew's order (round 26's case, all its tests kept); the plan's own per-crew heading
toggling within one task no longer re-issues a move. `--reissue-heading=plan` is round 26's rule. Bar (accepted, + the
fight tests): 108/108; reorder_heading + fight tests pass; arrive series fresh 17–20 not below control − 1 on the 8 m
line, median within +2 %; thirteen declared. Running.

### B5 — his queued screen (TOP PRIORITY from his playtest, 2026-10-13; not declared: no fight change)
His words (`game_design.md` *Round 28, his playtest*): shift + screen after a waypoint should drive the waypoint(s) first,
then lay the screen as seen from the last one. **Built on its own branch `brains-b5`** (B5 alone on `3e2f6e13`, game/ ==
main) and cherry-picked onto the stream. Mechanism: a shifted screen / support by fire / ambush on a squad still
driving — its element's move task, or his crews' own shift-queued route — goes to `Element.queued_tasks`
(`enqueue`), started when the move has arrived or the route has run out; its automatic facing is point − last
waypoint (`facing_from: "waypoint"`, read "facing on from your waypoint"); a drawn facing wins; several squads each queue
behind their own (`_order_squads`); the queued task is drawn while he plans ("SCREEN · next", linked from the
waypoint). Unshifted orders, and shifted orders on an idle squad, take today's path; shifted moves / attack-moves /
attacks keep today's direct queue.
Measured (builder0, `brains-b5`): `test_control_queued_task` 6/0 through his input path — waypoint driven (centre within
11.3 m) then the line 0.0° off point − waypoint; his shift route then shift+E 0.1°; a drawn facing kept; several
squads each queue; the queued mark at his point linked from the waypoint; unshifted applies now. `make
queued-screen-shots` (Foundry, planned in the pause, 1854×1011 and 1200×540): screen starts 6.5 s after unpause at the
waypoint, every crew within 8 m of its place 29.8 / 29.2 s later (squad 1 here is the slow artillery battery), heading
0.0°; frames looked at (planned: "SCREEN · next" + dashed link + chevrons; settled: "SCREEN · ARRIVED · dressing 4/5",
the line across the way in). Check on `brains-b5`: running.

### Notes from the orchestrator (2026-10-12 evening), for after B1/B2
- **Screen slots for long wheeled hulls** (manoeuvre's census): four gang trucks told to screen get 6 m slots (TacticsLab
  seed 61) and one parallel-parks for ~1 min, on base and on manoeuvre's change alike. Formation geometry is mine; take
  it after B1/B2 if cheap.
- **B3 start:** scout's per-death table (stream/scout Status, S2): 23–30 % of fixed-gun scout deaths under an ordered
  MOVE, 14–17 % retreating, 3–7 % in SUPPRESS. Ask who ordered the MOVE and where to. My first read of the code: the CPU
  commander re-tasks recon every think with `screen` to a point 45 m from its OWN centre toward the enemy focus
  (`ElementCommander.think`, SCREEN_AHEAD_M) — a carrot that walks scouts into the enemy. To verify on seed 5.
- **Round-29 candidate (traffic's T3 lead, n = 1, not a result; `streams/traffic.md` on main, *Requests to other
  streams*):** an element re-seats crews 3 and 4 back and forth for 36 s while the slot at (11.1, −73.4) reads
  blocked/no_path — round 27's B2 re-seat logic. A quick trace after B2 if time allows.

