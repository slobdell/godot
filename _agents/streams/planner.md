# Stream: planner (the lattice planner into play: its C++ port equal to the GDScript, a per-tick slice, the one seam into the drive; a long truck in a Terminus street turns in deliberate legs and never grinds a wall)

> Read `_agents/orchestration.md` (the worker contract; lessons 306–311), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 31** (C31.1–C31.11, especially **C31.5** — your two checkpoints — and **C31.2**), round 30's planner report and
> hand-over (`streams/archive/round30/planner.md`; `references/round30/planner/{problem,design,handover}.md`), and round
> 30's manoeuvre report for the cases you now own (`streams/archive/round30/manoeuvre.md`: seed 31's and seed 51's grinds,
> the squadmate pin loop, the six-cusp car, Green_M_3; logs under `references/round30/manoeuvre/`). **You own:**
> `game/ai/planner/**`, **`native/src/planner_native.{h,cpp}` (NEW — native reviews every commit before it is pushed and
> owns the build glue: `mk/native.mk`, `exec_fields.h`, the seam's record fields)**, `tests/planner/**`,
> `tests/test_planner*.gd`, `tests/test_native_planner*.gd`, `mk/planner.mk`, `references/round31/planner/**`. **Granted
> (C31.5, CP-P1):** ONE seam in `movement.gd`'s k-turn block where a plan is asked for, behind `--nav-off=planner` DEFAULT
> OFF — the exact line and the leg shape agreed with manoeuvre in writing through the orchestrator BEFORE code. **Model:
> Fable 5.1** — the round's one Fable stream (his rule): the port and the seam are where capability, not process, is the
> bottleneck.

## The lead's direction

Round 26: *a stuck vehicle should make a planned three-point turn, not shuffle back and forth.* Round 28: **TURN THE
WHOLE VEHICLE** to a drawn facing. His Fable ask (round 30): the hard lingering problems. Round 31 (his quota rule): Fable
for the single most challenging problem — this one.

What he will notice when CP-P1 ships ON: a War Rig told to face back in a Terminus street turns in two or three legs
(the lab: 15.5 s, 3 gear changes, 0 wall contacts v today's 29.8 s, 53, 14); a truck wedged nose-first backs out and goes
round; a car ordered to a slot 9 m behind it with a facing takes 2–3 legs, not six cusps; nothing grinds along a wall.

## Where things stand (main `cff4307e`)

- **On main (round 30, isolated, reached by nothing):** `game/ai/planner/**` — a hybrid-A* lattice over whole legs on the
  plant's own arcs, time cost with cusps and a clearance band, squadmates as oriented boxes, a free-space table per hull
  class, an EXPANSION budget (never the wall clock), legs `Vector3(gear, steer, metres)`; 16 offline tests in `check`
  (`test_planner_model`, `test_planner_fixtures`: every plan audited exactly, drawn as ASCII, planned twice); `make
  planner-lab`. Pre-registered lines NOT met and recorded: the wedge and the causeway slot 4 legs not 3; a rig's 20 m
  in-street turn-round 9 legs not 6 (the lattice's best is 8); an IFV's turn-round in 12 m not found within budget.
- **The cost is the catch:** 0.06–3 s a plan in GDScript on builder0, 17 s for the rig's turn-round. In play it needs the
  C++ port (~100×) or a resumable slice a tick — `handover.md`'s cost line.
- **The executor:** manoeuvre took two of your four rules (arc-not-chord; the discrete stopping distance) as `kturnarc` —
  judged, then parked: the UNSIGNED arc counts a short hull's forward roll-out as progress (a scout's orbit, `scenario_cp2`);
  manoeuvre fixes it gear-signed this round (CP-H). The other two (brake on the leg's own lock with the opposite throttle;
  never zero throttle with the lock on) are manoeuvre's to take or refuse. Today's executor consumes `Vector2` legs on one
  lock; yours are `Vector3(gear, steer, metres)` — the P4 finding, to be decided before code.
- **Your cases, with traces:** F1 the creep at a corner (seed 51, Green_S0_3: the lift rolled a rig's turn into the
  plaza-crossing wall, 50 s at throttle 0.8/lock 0.44); F2/F6 the grind after an escape (seed 31: 77 s, plant 10.7, real
  0.1–3 m/s, goal distance 25–29 m); F4 a goal POSE (yard s25 t1: a car's slot 9 m behind with a facing → six cusps; the
  planned circle back-up never runs for a car since round 26's +14 % contacts); the squadmate pin (a rig pinned 61.4 s
  between two squadmates at 6.9 m/s reported, 0.0000 m moved; Green_M_3's backoff-and-re-pin loop).
- **The honest reading** `Tank.real_velocity` is on main (read by nobody); your plan can take it as the start state's
  true speed.
- `judging.md` has rows for the Terminus census (arrivals, contact-ticks, 13 seeds), hull-rest, the fights guard; a scout
  orbit stage has none yet (brains measures its A/A this round, C31.6).

## Backlog (in order)

**P5 — CP-P0: the C++ port, equal to the GDScript planner.** `native/src/planner_native.{h,cpp}`: the lattice search,
the kinematic model, the free-space table, the OBB squadmate check, the budget — the SAME algorithm (same expansion order,
same tie-breaks, same budget semantics) so plans are identical. `tests/test_native_planner.gd`: every offline fixture and
the lab fixtures planned both ways, 0 mismatches (legs, cost, expansions, the failure code), the twin test in `check`; a
`native-proof`-style arm if the planner is reached by a proof match (it is not until CP-P1: say so). **Price it** on
builder0 (µs a plan per fixture; the 17 s rig turn-round in C++) and write the number with commit and machine. Native
REVIEWS every commit before you push it (SendMessage with the diff hash; orchestrator copied) and owns `mk/native.mk`,
`exec_fields.h`, the seam's record fields — ask, don't edit. CP-P0 merges OFF on its own (worth having alone).

**P6 — the per-tick slice.** A resumable search: a plan request that runs N expansions a tick and returns the SAME plan as
one call would (prove it: the twin test runs each fixture sliced at 50/200/1000 expansions a tick and compares to the
whole plan); the budget per tick chosen from the cost line (≤ 0.5 ms a tick at Sumps 25 a side with every hull that
wants a plan — measure how many want one a tick in a Sumps fight, GDScript census, before choosing). What the hull does
while a plan is pending (hold? today's k-turn's first leg?) is part of the seam design (P7), written before code.

**P7 — CP-P1: the seam, designed in writing, then judged.** With manoeuvre, through the orchestrator, BEFORE code: the one
line in the k-turn block where a plan is asked for (today's planner call), the leg shape (`Vector3(gear, steer, metres)`
consumed by manoeuvre's executor, or your adapter to `Vector2` on one lock — the executor's two untaken rules decide
which is honest), the re-plan events (a leg done, a block, a stale obstacle; never per tick), the pending-plan behaviour,
and what the planner REPLACES when ON (the circle fill? the planned reverse? the creep lift is already gone). Then the
code behind `--nav-off=planner` DEFAULT OFF, native's mirror of the seam (C31.2), and **the pair-tree check (C31.1)
with the switch ON — the whole suite — before any series.** Bar (to the orchestrator before numbers, every line a
`judging.md` row): Terminus census rigs + mixed 13 fresh seeds (arrivals not down beyond 1.645 se EACH squad; rigs'
wall contact-ticks ≤ base + 1.645 se — the thing three rounds of rules broke), seed 31's and seed 51's stages re-run (the
grinds gone: contact-ticks on those runs reported), yard s25 t1 (the car's legs ≤ 3), the squadmate-pin fixture (freed, no
loop), `scenario_cp2` on brains' A/A seeds (a scout's orbit unchanged), `test_wheeled_arrival` + the 180° arrival, hull-rest
(one arm per call; crews still moving at 75 s per task ≤ base + 2 se), bridge-pooled 18/18, fights 24 seeds within 2 se,
cost ≤ 0.5 ms a tick at Sumps 25 a side or the budget that achieves it (stated), the thirteen explained if they move.
Last attempt named; partial: CP-P0 stays merged OFF; a CP-P1 miss parks with its traces. Ships ON as a pair (the C++
plan source on the default path; the GDScript planner kept as the twin). A clip of the Terminus west-street rig and the
yard car before/after for him.

**Stretch:** the squad-level schedule (four trucks facing east without boxing each other) — a design note only.

## How to verify

`make remote T=check` (the twin test in it); the pair-tree check with `planner` ON before any series (C31.1); `make
planner-lab`; the stages above (`nav-terminus-drive`, `manoeuvre-census`, hull-rest, `bridge-pooled`, `manoeuvre-fights`,
`scenario_cp2`, the arrival tests); `native-verify-scenarios`. Every number: commit, machine, workload, n, its row. builder0
only; one slot at a time for anything heavy; no laptop.

## Don't touch

Manoeuvre's executor (`kturn_on` … `_look_stop`, `_kturn_start_leg`, `_planned_reverse`, unstick, `_pressing_escape`) —
you ask for the seam line and consume its leg shape; traffic's, brains' paths; native's build files and `exec_fields.h`
(ask); `game/tank/**`; `tools/judge/**`.

## Waiting on the lead

Nothing (his calls: a planned turn, not a shuffle; the whole hull turns to his facing — both made).

## Status

_(the worker keeps this current; the seam design announced when written so manoeuvre and native can read it; bars to the
orchestrator before numbers; the report at the top)_
