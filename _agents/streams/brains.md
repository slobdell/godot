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

**Plan (the backlog in order):** B0 (facing on every armed task; CP0, merge early) → B1 (his bridge drill; after
traffic's CP1a/CP1 merges, re-run the 108 before claiming) → B2 (drill seats by nearest on B1's feed) → B3 (the scout at
phase 2) → B4 stretch.

**Noted from the orchestrator (2026-10-10):** C26.8 grants traffic `ElementFeed.changed` and the key built in
`ElementFeed.context` (the slot's float string re-fired `changed()` every ~0.3 s and reset every crew's stall clocks).
Not touched here. It lands as CP1a and very likely moves the bridge drill: B1 is judged only after merging it.

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

