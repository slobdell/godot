# Stream: brains (armed tasks honour a drawn facing; his bridge drill passes; the round-25 carry-overs)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (reading (5)) and
> *Round 25* sections, `_agents/doctrine.md`, `_agents/workstreams.md` *Round 26* (C26.1, C26.3, C26.6), and round 25's
> brains report (`streams/archive/round25/brains.md`, **Status → *Round 26 carry-overs***: your backlog's source). You own
> `game/ai/**` EXCEPT traffic's, manoeuvre's and perf's carve-outs (C26 ownership list), `game/tactics/**`,
> `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd` and one registration line each),
> `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`,
> `tests/test_form_up.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk` (minus manoeuvre's targets),
> `doctrines/doctrine_*.json`. **C26.2:** `decide`, `build_situation`, the route tail, `_around_fire` and the two
> TacticalQuery functions run in C++; perf ports any change (and holds seams on `act` and `build_situation`'s non-core
> part: tell perf before touching those).

## The lead's direction

His screen-facing note (`game_design.md` *Round 26 direction*): *"I was trying to get tanks oriented in a screen at a
particular angle … it short-circuit directly to screen and so the vehicles moved into a line abreast angle I didn't
want. This is probably the case for all our specialized cases (attack, ambush, screen, etc)."* Orders builds the
gesture; you make every task obey what it draws (C26.3).

His bridge (round 25): *"I click a point for my army to move to (across a bridge). Not[e] all of them make it to the other
side."* Much better after round 25, not fixed.

## Where things stand (VERIFY at main)

- `ElementTask.facing` exists (`element.gd` has a facing channel); a right-drag MOVE's facing reaches the task. Whether
  screen / support by fire / ambush / attack-move read `task["facing"]` is unknown per task: check each.
- His bridge drill (`make bridge-pooled`, start ticks {1,3,6,8,11,16} × both sides): 45/54 his side, 41–42/54 the CPU's at
  3 seeds; failures are crews standing short in a mouth or far exit and deck queues (F3′'s traces).
- `brains-f1b-full` (`2894ded7`): drill seats by nearest without the leader pin, measured WORSE (45 → 38/54).
- F5: the scout misses the engine deck at think phases 2 and 5 (sits 15–22 m in front of the tank's gun, likely
  reversing).

## Backlog (in order)

**B0 — every armed task honours a drawn facing (C26.3; CP0, merge early).** When `task["facing"]` is present: the screen's
line is laid across it (the facing is where the line looks), support by fire faces it from its position, an ambush
faces it, an attack-move arrives facing it. Absent: byte-identical to main (thirteen lines, determinism, the element
digest unmoved). A unit test per task (with and without the key). Name the green commit to the orchestrator: it merges
as CP0 and orders merges main.

**B1 — his bridge drill passes.** Re-tune the mouth feed for nearest-seat arrival (carry-over 1 and 4): why crews stand
short of the far exit; then the 108 (start ticks 1–18 × seeds 1–3). Pass: `make bridge-pooled` every run 4 across and
`rim_crews 0`, both sides; then put `bridge-pooled` in `check` (a request to the orchestrator: `mk/core.mk` is
nobody's). After traffic's CP1 merges (keep-right changes who meets whom at a mouth), `git merge main` when told and
re-run the 108 before claiming it. Declared change (C26.1), merged alone.

**B2 — drill seats by nearest (F1b part 2)** on top of B1: re-try `brains-f1b-full`'s unpin with the re-tuned feed;
ship only if the 108 is not worse (lesson 287).

**B3 — F5, the scout at phase 2** (carry-over 2): its Movement driver and reverse reason 10–15 s in (`BridgeStage._decided`
shows how). If the cause is the reverse or a k-turn, hand the trace to manoeuvre through the orchestrator (their block).

**B4 — stretch:** F6 only with a new reason; the street-funnel trade stays his call (held: "squads squeeze into a narrow
street instead of keeping their full width (a second quicker), but a line you send down a street no longer forms up on
the way").

## How to verify

`make remote T=check`; the bridge series and the element digest on builder0; screenshots of B0 for each task at his pose
(laptop through the orchestrator, C26.7), looked at.

## Don't touch

Traffic's and manoeuvre's `movement.gd` blocks, `avoidance.gd`, `steering.gd`, `clothoid.gd`, `wall_contact.gd`;
`native/**`, perf's seams and pace's former hunk in `tank_brain.gd`; `game/control/**` (orders').

## Waiting on the lead

The street-funnel trade (above). Nothing else.

## Status

_Round 26 brains worker, started 2026-10-10 evening at `b57838ed`._

### FINAL REPORT (round 26, 2026-10-11)

| item | state | where |
|---|---|---|
| B0: every armed task honours a drawn facing | DONE, merged (CP0) | `63adfedd` → main `7f792de9` |
| B1: his bridge drill passes | DONE, merged; `bridge-pooled` (18 runs) is in check | 108/108 on main `eb987e87`; `8600d892` → main `47b8527b`, `2aadc60c` |
| B2: drill seats by nearest | NOT SHIPPING: round-27 carry-over (the pursuit, the bay ambush and Sumps break) | the paired table below |
| B3: F5, the scout at phase 2 | traced, handed to manoeuvre (an orbit k-turn loop) | B3 section |
| nav-orders `--seed` (B4) | DONE, merged | `517b848f` + `efc571c0` → main `47b8527b` |
| "the squad never lets go of the chase" guard | branch, awaiting the fresh check | `059d6985` |
| the stale heading on an element's own re-issue | branch, DECLARED (latent: not his re-order path), awaiting the fresh check | `07bdde89` |
| the rig carrot (manoeuvre's relay) | traced; a rule; PARKED for round 27 (n = 3 is a trade, not a win) | lab `f082af36` |
| make-room's falsifier (traffic's two stages) | none on main: priced by removal in round 27 | below |
| the stuck clock's pause | round-27 carry-over (its arrival is hollow) | lab `26b94aa6` |
| the arrive line passes a hollow arrival | round-27 carry-over (a stricter definition proposed) | below |

**The branch for merge:** `dd7c7db2` = main `da78de4f` (perf's preset-leak fix, CP1a2, orders) + the let-go guard
`059d6985` + the heading fix `07bdde89` + `SETTLE_FLAGS` (tooling) + Status. Its fresh full check is running on builder0;
the green hash is named below when it reads (the merge is only if the thirteen lines read UNMOVED: the orchestrator).
Questions for the lead: none open. builder0 folders of this stream: `godot-brains`, `godot-brains-lab2`, `godot-brains-lab3`
(+ `-light`), to remove at close; local worktrees `godot-brains-lab2`, `godot-brains-lab3` (scratch, nothing unmerged needed
from them except the round-27 prototypes: `26b94aa6` on branch `lab/brains-mr2` (the clock pause), `f082af36` on `lab/brains-carrot` (the under-hull rule, on manoeuvre's `3c981eb0`); keep those two branches).

**B1 (preliminary, scratch `aa5defa1` = stream/brains + traffic's CP1a `5c31c58f`, builder0, the 108):** his side
53/54, the CPU's 53/54, deck jam 135 / 92 crew-s (round 25 at its own code: 45/54, 41-42/54, 1013 / 754). The one
failure each side is seed 1 tick 15: a crew KILLED by the lancers (alive 3, rim 0, deck jam ~0). **Paired control at the
same commit** (`--traffic-off=slide`): 45/54 and 42/54, arriving 37 / 40, deck jam 1013 / 754 (round 25's numbers
exactly). CP1a: +8 / +11 runs, every squad arrives, deck jam −87 %; no run worse. Ruled (C26.6, the orchestrator): the line counts every SURVIVING crew
across; an uncrossed dead crew is excused only if it was stuck under 3 s in the 10 s before it died (`fafc3eae`:
BridgeStage's `dead`, `tools/tactics/bridge_verdict.py`, its known answers in tactics-pytest). B1 is claimed only on
main + CP1a, re-run after the merge; then `bridge-pooled` goes into check (≤ ~3 min wall time on builder0, the
orchestrator adds the core.mk line).

**B1 DONE on main (`eb987e87` = stream/brains merged with main `6434f968`, which carries CP1a; builder0, the 108,
06:43–07:08): `bridge_verdict.py` reads `BRIDGE_POOLED 108 of 108 runs pass`.** The raw numbers match the scratch run
exactly: 53/54 a side, every squad arrives, deck jam 135 / 92 crew-s. The two raw failures are excused under the ruled
line: seed 1, tick 15, `Green_S_1` killed by `Rust_G_2` and `Rust_S_1` killed by `Green_G_2`, both at 14.5 s, both held
under 0.5 s in their last 10 s (in a fight, not stuck). **The check entry (approved by the orchestrator):** `bridge-pooled`
defaults to seeds 1–3 × start ticks {1, 8, 15} × both sides = 18 runs (`8600d892`), which holds both excusals so the
dead-crew branch runs every check. At `8600d892` on builder0: `BRIDGE_POOLED 18 of 18 runs pass`, about 3.4 min of run
time (1045 s of wall time, 14 min of it waiting for a slot). The full 108 stays the declared-change series. The line for
the orchestrator: `bridge-pooled` appended to `CHECK_TARGETS` (`mk/core.mk:329`). It writes only
`build/bridge-series.jsonl`, which no other check target touches.

**nav-orders seed (`517b848f` + `efc571c0`):** the nudge and the tick shift work. On builder0 at `517b848f`: two seeds
give two different starts, the same seed repeats, and no `--seed` is the historical start (digest `14857e4e91ad953c`
both times). The third test failed only on its own message (an array passed as the format arguments: the one failure of
the check on `eb987e87`, 2402 / 1, all 22 other targets green); fixed in `efc571c0`. Merges with the heading fix's check.

**The stale heading (the orchestrator's priority item, 2026-10-11; DECLARED; `07bdde89`).** Orders' trace (builder0,
ba541b96): `Element._should_issue` compared verb, place and target but not the heading, so an element re-given its task
without the heading drawn on the first (or with another) kept the old one on every crew already moving. Red on builder0
(`b93fdc14`): order ids 1 and 2 still carried facing [0, −1] after 360 frames. Now a heading given, taken away, or
turned past `HEADING_REISSUE_DEG` (20) is a changed intention, both on our order and once it has finished; drift under
20 deg re-issues nothing. `--reissue-heading=off`. With orders' `Orders._same_order` hunk (`518d7775`, in the lab only)
every crew takes it in 5 frames, all three ways (builder0, `7f1b73ac`, 20 passed / 0).
**It is NOT his own re-order.** `control_fixture` sets no player team, so orders' repro runs an element's own re-issue.
On his team a task's first update issues every crew with the new task id, and the OLD rule sheds the heading in 5
frames too (builder0, `8fd6209a`, both arms measured). What this fixes is an element re-issuing on its own: a CPU
squad re-tasked, or a plan whose heading changes under the same task. It passes WITHOUT orders' hunk too (builder0,
`b9503a94`, the same tree as `07bdde89`: 6 passed / 0, 5 frames each), so it does not wait on orders.
**HELD (the orchestrator, 2026-10-11) until perf's preset-leak fix (`845dc7af`) lands.** On `f07f366d` (stream + main
through `2aadc60c`, CP2) the full check read 2410 / 6, thirteen UNMOVED, determinism foundry `762a0576f944f5b7`. All six
failures were in SHARD 4/5: five `test_native_army_cap` (perf's file, 13 / 0 alone: a RenderLevers preset leak) and
the shed test. The shed test ALONE on the same tree passes (builder0, debug trace: the re-assign at tick 5, both crews
re-issued without the facing at tick 8), so the premise holds after CP2 and the failure is the shard's leak. Next: merge
main once `845dc7af` is in, run one fresh full check, and name the hash for `059d6985` + `07bdde89`.

**manoeuvre's relay: the rig carrot (Terminus drive, rigs, seed 2, Green_S0_3, 23 legs from tick 1438).** Cause:
`_corner_beyond` and `_guard_steer` skip only corners within round 11's 1.5 m of the hull centre (a tank's size). A
route corner 1.7 m ahead and 0.7 m aside sits UNDER a War Rig, and the circle rule reverses at it. The next corner is
also inside the rig's circle, while the carrot ahead is not, so it flips reverse / forward. It is identical with
native drive and path off. A rule (a corner inside the hull's footprint is "on" it; `--nav-off=underhull`), lab
`f082af36` on manoeuvre's `3c981eb0`, GDScript path, Terminus seeds 1–3, paired: the 23-leg press is gone, and the
worst static / friendly / open episodes go 23 / 19 / 27 → 5 / 9 / 19. But the ≤3-leg share drops (friendly 0.74 →
0.61, open 0.61 → 0.54), and S0_3's new trajectory has a 13-leg circle. n = 3 and chaotic, so there is no claim. The
rule is also in the C++ tail (`drive_native.cpp`, `route_native.cpp`), so nothing goes to perf. **PARKED: a round-27
carry-over (manoeuvre, 2026-10-11; CP3 ships without it).** The deciding run, both arms (lab `f082af36` has the
rule): `tools/remote.sh --light manoeuvre-census CENSUS_WORKLOADS=terminus 'CENSUS_SEEDS=1 2 3 4 5 6 7 8'
'NAV_FLAGS=--brains-off=native'` with and without `--nav-off=underhull`, then `tests/nav/drive_table.py` on the logs
renamed `<squad>-<seed>.log` (strip `terminus-`). A win must shrink the worst cases WITHOUT lowering the ≤3-leg share.
If it ships, perf ports `_on_hull` into both C++ copies (C26.2).

**make-room (traffic's two stages): NO FALSIFIER on main, priced by removal in round 27 (the orchestrator).**
(1) Terminus crossing, solo_a, seed 3, tick 8, on main after CP2 (`f07f366d`, builder0): no jam. All five crews arrive
(A_5 at 22.0 s), with nothing swapped or re-seated. Crew 3 parks at (7.5, −14.0), not traffic's (10.6, −7.7), and the
`--no-make-room` arm reads the same to the tenth (A_5 22.0 s, end 26.5 s): CP2's reverse rescued that geometry.
(2) Sumps, law_scout:law_ifv:law_tank:law_tank, seed 1, drills on (traffic's CP1a regression in the arrive series):
CP1a never arrives with make-room on or off (identical, 0 re-seats); `--traffic-off=slide` arrives at 22.57 s. Cause:
S_2 (a tracked law_ifv, so traffic's wheeled creep fix does not touch it) shuffles 1.6 m behind S_3, parked on its own
station 7.2 m away, for 110 s. `Element._watch_progress` RESETS the 4 s "driving without closing" clock on any tick
under STUCK_MPS (1 m/s), and the shuffle passes zero at every reversal, so the crew never reads stuck: no re-seat, and
make-room (which fires only after a re-seat came back unchanged) never gets its turn.

**Round-27 carry-over: the stuck clock's pause.** Prototype in lab3 `26b94aa6` (`--stuck-pause=off` is the old reset):
the clock pauses while a crew is slow and runs while it drives. On the Sumps stage (builder0), with or without
make-room (identical, 0 swaps), the squad reads arrived at 52.27 s after 3 re-seats; the old reset never arrives. **But
the arrival is hollow.** The first re-seat (~15 s, seats 0312 → 1302) frees S_2 by handing S_3, the parked crew, the
far-side seat. S_3 then trails 41–48 m off its slot through the lanes (`yielding`, then `blocked/terrain`) and ends
19–26 m past its slot when the element reads arrived. The pause is right in principle (a shuffle should not defeat
stuck detection), but it needs a re-seat that seats the blocked crew round the parked one rather than across the
lanes, or an arrival rule that does not count it. It must not make the arrive line lie (the orchestrator). The stage:
`make squad-settle ARENA=sumps DIR=forward METRES=150 SEED=1 UNITS=law_scout:law_ifv:law_tank:law_tank
SETTLE_SECONDS=120 TRACE=on SETTLE_FLAGS="--drills=on [--stuck-pause=off | --no-make-room]"` (SETTLE_FLAGS: this
branch).

**Round-27 carry-over: the arrive line can pass a hollow arrival (the orchestrator).** The element's "arrived" (and
squad-settle's / squad-arrive-series' `arrived_s`, which read it) was true on that Sumps run with S_3 19–26 m off its
slot. Proposal: the series' arrival is EVERY crew within its settle radius of its seat (Movement.settle_radius for its
hull, the order's arrive radius at the least), held for 1 s; the element's own "arrived" may stay as it is for the
leader's flow, but the measuring line reads the stricter one. Pre-register it on the round-26 arrive series first, so
the change of line and any behaviour change are never measured together.

**B2 does NOT ship this round: a round-27 carry-over (the orchestrator, 2026-10-11).** The bridge passes with CP1a alone
(B1). The unpin (drill seats by nearest, `2894ded7`) on main (`fe45a510` = `eb987e87` + `2894ded7`, lab
`lab/brains-b2m`), the fight tests in both arms under the SAME test lines (`pace-p0-tests`, builder0, phase 0):

| | nearest (the unpin) | pinned (main) |
|---|---|---|
| the 7 tests matched (pursuit 8 m/s, cpu_hold, mixed_legs) | 4 passed / 3 failed | 7 / 0 |
| pursuit 8 m/s, "the whole squad let go" | lets go at 7.5 s | holds |
| cpu_hold, the bay ambush springs | at 12.1 s from x 55.7 (line: beyond 56) | at 15.5 s from x 64.6 |
| mixed_legs, Sumps two scouts arrive | 26.1 s (line 25) | 20.4 s |

On his bridge it was a gain: his 108, 54/54 a side unpinned against 53/54 pinned (`24f7ca2c`, pre-merge). **What it
would need:** a drill's seating must keep the lead crew's role in pursuit and ambush, so the crew on point stays the
one the chase or the bay depends on. Nearest seating hands point to whichever crew is closest, which is how the squad lets go of the
chase and how the ambush springs before it is in the bay. Its cost was not readable (below); its arrive series was
never re-run outside the disk window (the 05:38 series is void).
**The let-go line comes in on its own as a guard** (the orchestrator; `059d6985`): round 25's line without the excuses
it carried on the two older pursuit lines. Main passes it (builder0, `7f1b73ac`).

**B2 cost (C26.10, 25 a side, `native-tp-headless`, builder0 during the busy window 05:46–07:30): NOT READABLE.** The
same arm read 26.2 then 61.7 ms of tick scripts (pinned) and 44.6 then 64.3 ms (nearest). The elements segment read
6.8 / 15.7 pinned against 11.8 / 16.5 nearest. Noise is wider than any effect, so there is no claim either way. It
needs perf-judge's pinned-core method, or a quiet box.

**Plan (the backlog in order):** B0 (facing on every armed task; CP0, merge early) → B1 (his bridge drill; after
traffic's CP1a/CP1 merges, re-run the 108 before claiming) → B2 (drill seats by nearest on B1's feed) → B3 (the scout at
phase 2) → B4 stretch.

**Noted from the orchestrator (2026-10-10):** C26.8 grants traffic `ElementFeed.changed` and the key built in
`ElementFeed.context` (the slot's float string re-fired `changed()` every ~0.3 s and reset every crew's stall clocks).
Not touched here. It lands as CP1a and very likely moves the bridge drill: B1 is judged only after merging it.

**Relayed by the orchestrator (2026-10-11, after CP0 merged as `7f792de9`):** (1) orders' probe: a PLAIN two-squad
right-drag move tells the crews the facing but the hulls are 69 / 140 deg off it 15 s after arrival; sent to manoeuvre
(face-at-rest, C26.9); brains to report any element-layer cause (station or slot heading overriding the order).
(2) CP1a makes `test_tactics_make_room`'s case resolve by give-way: make-room has NO falsifier; after B1, a stage that
still needs it with CP1a on, or price it by removal. (3) perf's free item: `_cover_spots` early-out before `threat_list`
(granted to perf, 2026-10-11: my early version, 7beac85c, reverted on this branch so the two never meet).
(4) `SquadConsolidation.for_player` (game/tactics/squad_consolidation.gd) granted to perf for this round (2026-10-11): a
desktop faction army's 6-14-crew squads were refused by Elements.form (C19.1), so their tasks and right-clicks dropped; the
player fold becomes squads of at most 5 with the overflow in groups 6-10. Not touched here.

### B3: the scout at think phase 2 (F5) — traced, handed to manoeuvre (2026-10-11)

builder0, `63adfedd`, `tools/remote.sh pace-p0 ORBIT_PROBE=1 PACE_P0_FILTER=engine_deck PACE_P0_ARMS=base
'PACE_P0_PHASES=1 2'`: phase 1 deck 41/43 PASS, phase 2 deck 4/22 FAIL (reproduced). The traces (every 0.5 s: option,
range, the move order's point as distance@bearing off the hull, position, driver, throttle, reverse reason, k-turn
plan kind) are in `streams/references/round26/brains/f5_engine_deck_phase{1,2}.txt`. **Cause: a k-turn loop.** The
orbit controller's steering point (13 m ahead, 50-130 deg off the hull, re-aimed every think) is answered by Movement
with a planned SINGLE k-turn (throttle -0.70 ~1.5 s, sometimes `why=circle`) nearly every time from ~11 s; the scout
sits 18-22 m from the tank around (-85, -34), every back-up takes it further out, it never gets inside the 11 m orbit,
never starts its attack run. Phase 1 runs the same loop twice and then comes out at 6.7 m and bursts. The scout's
turning radius is 5 m, so a point 13 m away is reachable forward: the k-turn is `_arc_hit` calling the forward arc
blocked, or the planner preferring the reverse: manoeuvre's block. Handed over through the orchestrator (with the
caution that a steering point refreshed every think is not a destination for CP2's "short move behind" rule). If the
arc is really blocked by terrain, the fix is mine (the orbit circles the other way when its forward arc is blocked).

### B0: every armed task honours a drawn facing (C26.3)

`game/tactics/element_plan.gd`, three places, every one behind `ElementTask.facing(task) is Vector3` (absent = the old
code path, untouched):
- **screen** (`_plan_screen`): the line's heading is the drawn facing (laid across it), whichever way the element came.
- **support by fire / ambush** (`_plan_support_by_fire`, shared): the line looks along the facing, and stands off its
  point AGAINST the facing, so the guns that look his way look at the point he gave. Reason (one line): his gesture is
  press at the spot, drag toward the facing; a line on our side facing elsewhere would point its guns away from the
  point it was told to cover, so the drag picks the side it fires FROM. With an ambush's `from`, it lies there looking
  along the facing.
- **attack-move** (a `move` with drills on) arrives facing it (`_arrive_facing`): its travel shape laid on the spot
  toward the facing, every crew holding that heading (the plain right-drag move's posture), not the halt's all-round
  sectors. On the way: orders identical to no facing. A `hold` with a facing (the CPU's) is not touched.

Tests: `tests/test_tactics_facing_tasks.gd` (11, plan-level, with and without the key; 5 failed before the change) and
`tests/test_tactics_facing_tasks_live.gd` (4, a real match: a squad driving north, told east). Local laptop run (not a
measurement of speed): mean hull heading 0.4 / 1.5 / 1.4 / 2.1 deg off east for screen / support by fire / ambush /
attack-move, worst crew 28.8 / 32.1 / 32.2 / 2.5 deg (a firing line's interlocking sectors, ±10/±30 deg, are kept);
with the old element_plan.gd: 68.5 / 51.7 / 31.5 / 49.3 deg mean off, 0 of 4 pass.

**CP0 GREEN, merge here: `63adfedd`** (builder0, `make check exited 0`, 2392 passed / 0 failed, thirteen UNMOVED,
determinism `762a0576f944f5b7` unchanged; 2 NOT JUDGED for environment reasons only: the perf lock held by another
check 300 s, and scenario_perf unpinned on the hybrid machine). Told the orchestrator 2026-10-11 ~00:40.
Screenshots at his pose: not taken by me (the laptop is the orchestrator's to schedule, C26.7, and the gesture is
orders'); orders' O2 screenshots cover it. Note for O2: a firing line's outer crews keep interlocking sectors (up to
~30 deg out), so a 15 deg line is the line's mean heading, not every crew's.

