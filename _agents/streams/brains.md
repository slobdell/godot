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

**B1 (preliminary, scratch `aa5defa1` = stream/brains + traffic's CP1a `5c31c58f`, builder0, the 108):** his side
53/54, the CPU's 53/54, deck jam 135 / 92 crew-s (round 25 at its own code: 45/54, 41-42/54, 1013 / 754). The one
failure each side is seed 1 tick 15: a crew KILLED by the lancers (alive 3, rim 0, deck jam ~0). **Paired control at the
same commit** (`--traffic-off=slide`): 45/54 and 42/54, arriving 37 / 40, deck jam 1013 / 754 (round 25's numbers
exactly). CP1a: +8 / +11 runs, every squad arrives, deck jam −87 %; no run worse. Ruled (C26.6, the orchestrator): the line counts every SURVIVING crew
across; an uncrossed dead crew is excused only if it was stuck under 3 s in the 10 s before it died (`fafc3eae`:
BridgeStage's `dead`, `tools/tactics/bridge_verdict.py`, its known answers in tactics-pytest). B1 is claimed only on
main + CP1a, re-run after the merge; then `bridge-pooled` goes into check (≤ ~3 min wall time on builder0, the
orchestrator adds the core.mk line).

**Branch tip GREEN: `a38cf118`** (builder0, `make check exited 0`, 2392 passed / 0 failed, 23 targets ALL JUDGED,
thirteen UNMOVED, determinism `762a0576f944f5b7`): B0, the B1 verdict tooling (`fafc3eae`), the B3 probe, Status.
Not a behaviour change (bridge-pooled is off by default; the probe is env-gated).

**B2 trial (scratch `24f7ca2c` = aa5defa1 + round 25's unpin `2894ded7`, builder0, his 108, paired by
`--seat-leader=pinned`):** unpinned 54/54 his side and 54/54 the CPU's, deck jam 125 / 123 crew-s; pinned 53/54 and
53/54, 135 / 92 — the pinned arm byte-identical to the CP1a run without the trial (the switch arms the old code exactly).
The seed-1 tick-15 crew that died pinned lives unpinned. The CPU's deck jam +31 crew-s over 54 runs (~0.6 s a run), no run
failing. Queued: its check, the drill arrive series by the same switch, the cost at 25 a side (C26.10, pre-registered ~0).
**Its check (builder0, `24f7ca2c`, exited 2): 2393 passed / 5 failed.** Two are CP1a's own at that pre-merge commit
(`test_tactics_make_room`, `test_traffic_feed`: traffic edited both inside the merged CP1a). Three are the unpin's, in
fights: `test_tactics_cpu_hold` (the bay ambush: green wiped 0 alive, guns not on the kill zone),
`test_tactics_pursuit` 8 m/s (the whole squad let go: every crew excused, all four killed by the spotter),
`test_tactics_mixed_legs` (Sumps two-scout squad 26.1 s for ~20). So B2's bridge gain comes with fight changes: to be
re-trialled on main + CP1a (+ CP1a2) and each failure traced before anything is claimed (lesson 287).
Drill arrive series on the same trial (builder0, `24f7ca2c`, 5 maps × 5 squads × 4 seeds, paired by `--seat-leader`):
unpinned 100/100 arrive, pinned 99/100; unpinned − pinned **−0.03 s (se 0.46, median +0.20)**, 45 faster / 54 slower:
neutral — PROVISIONAL: it finished at 05:38, inside the window when builder0 was out of disk (the orchestrator: re-run, do not read); re-run on main + CP1a with the B2 re-trial. The cost run died on the full disk: re-running.

**Queued from the orchestrator (2026-10-11, after the B2 traces): make-room's new stage.** Traffic's trace (builder0,
traffic-cp1a2, Terminus crossing, squad A alone, seed 3, start tick 8): with CP1a, never ×3 of 6 ticks; nearest seating
put crew 3 at (10.6, −7.7), across the route of crew 5 (wheeled law_tank, slot 25 m behind); crew 5 shuffles at full lock,
crew 3 refuses every ask. Make it make-room's stage (CP1a on: arrives; make-room off: does not) and find why make-room
does not fire. Ask traffic for the exact command.

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

