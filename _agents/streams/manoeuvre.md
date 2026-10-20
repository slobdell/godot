# Stream: manoeuvre (a crew wedged between friends gets out; fewer crews left sitting behind their squad)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1, CP36.1,
> C36.3) and in *Round 35*: R35.64, R35.66 (the joint), R35.67, R35.76 (X1(d) traced), R35.78 (X1b: W1b dropped). Then your round-35
> brief `streams/archive/round35/manoeuvre.md` (its Status is the close-out) and brains' `streams/archive/round35/brains.md` (X4a: the
> released crews that never rejoin are wedged; the net-motion mover rule). Evidence on `round35/manoeuvre`:
> `references/round35/manoeuvre/x1d-trace/README.md` (the trace, design (A)–(D), the stallnet bar draft), `joint3-series/`, `w1-trace/`.
> **You own:** the `drive()` body, `_nose_stop`, `unstick` (and its stall clock), `_pressing_escape`, the k-turn executor, H1/H1b,
> W1c's stall intent, the face-at-rest path in `order_controller.gd`, the `_order_move` decline for wheeled turret hulls,
> `game/ai/manoeuvre*.gd`, `tests/manoeuvre/**`, `tests/test_manoeuvre*.gd`, `mk/manoeuvre.mk`, additive fields in
> `game/control/screen_playtest.gd`. You may copy brains' read-only readers (`tests/tactics/mover_kind.py`) into `tests/manoeuvre/`.
> **Model:** **Fable** (this is the lingering problem: the wedged crew has been the biggest avoidable loss since round 34).
> **Machine:** builder0 (C36.1); light runs on either builder.

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. For round 36 he chose "use the agents' list" (2026-10-20).
From his playtests across rounds: a crew sitting idle and stuck while its squad has moved on is the thing he notices most.

What he will notice: a tank jammed between two friendly tanks at a choke backs out or finds a way within a few seconds instead of
rocking for a minute; fewer crews left behind, sitting still, when the squad has gone on.

## Where things stand

- **Round 35 shipped M5** (a War Rig told to face a way turns there and goes still) and the joint W1c + T9 lands at **CP36.1** (his
  yes): attack-move crews that never settle 48 -> 23, crews 25+ m off their goal 105 -> 59 (joint3 series, builder0).
- **W1b is dropped (R35.78):** X1b read SITTING DUCK (a held still wheeled hull takes ~2x the hits); T8 (traffic) is the answer.
- **X1(d) traced (R35.76):** the choke wedge's stall clock reads REAL velocity, but resets on any one tick >= 0.8 m/s; the contact pops
  ~once a second (one tick 8.5–9.9 m/s, net <= 0.1 m in 10 s), so the clock reaches 0.73–0.99 s and is zeroed just short of 1.0 for
  ~50 s. Rocking crews (`rocking_census.py`, joint3 hull-rest, 768 runs an arm): base 6, joint ON 3.
- **The left-behind crews (Bar E1, brains):** 9 of the 17 crews left > 25 m behind in E1's new arm were still wedged at the judge
  (law-605 Eyes_4, law-607 Guns_6, gangs-602 Hunters_3 traced; law-705 Eyes_3, law-711 Guns_7 never moved after release). X4b (did the
  joint free them?) was never run: it is your S2.
- **Measurement rule (brains, X4a):** count movers by NET motion (closing + wander in `mover_kind.py`), never `real_mps` alone: a
  wedged hull rocking reads >= 0.3 m/s.

## Backlog (in order)

1. **Carry over (C36.1):** after CP36.1, `git merge main`, then bring across from `round35/manoeuvre` what main lacks and you need
   (the STALL_TRACE probe `248e7495c` as measurement-only code, `rocking_census.py`, `fight_census.gd`'s exposure lines, the judges).
   Read `git diff main...round35/manoeuvre` first; W1c and the stall-intent tests arrive through the joint.
2. **S3 delete W1b (R35.78), first because it's small:** WHEEL_HALT and its tests out of GDScript; native deletes its inert mirror
   in the same pair (send native the commit). Switch-OFF inertness: sim-baseline unmoved (it was default OFF).
3. **S1 stallnet (C36.3), the bar draft in x1d-trace/README.md, filed in workstreams *Bars (round 36)* before any number:** the
   stall clock resets on NET motion from where it started (> STUCK_NET_M 0.5 m), routed move_to on the honest path only, behind
   `--nav-off=stallnet` (default OFF until judged); native mirrors `_stuck_from` (send native the spec). The DECIDING line is the
   deterministic lab stage `test_manoeuvre_stall_net` (a hull driven into a one-hull gap between two parked friends of another
   element; ON escapes within 3 s, base never in 20 s, both paths); the series lines are guards (no harm) on FRESH seeds; movers by
   net motion. A pass ships ON.
4. **S2 the left-behind crews after the joint (X4b, then the fix):** on a main with CP36.1 (and S1 if it shipped), re-run Bar E1's
   left-behind read (faced_attack_move + faced_move, fresh seeds, 4 factions, builder0 native) and REPORT: how many crews > 25 m behind
   at the judge, and how many of those are wedged (net motion). Trace the worst three. Then a design note to the orchestrator, and
   only then a bar. Expect the cause to be several mechanisms; name each with its count before choosing one.
5. **Stretch: R34.16's watch item** (one 9.1 m both-planned face) if a native clicked face_pairs pair runs.

## How to verify

Lab stage first (it is the deciding line); `make quick-remote`; one full check at a time a builder; series pinned, fresh seeds.
Every number: commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=locks`, send two squads through the lock
together, and look at the screenshots for a crew rocking between friends.

## Don't touch

Traffic's give-way block and `traffic.gd`, orders' paths, brains' paths (no owner, C36.6: ask the orchestrator for a grant),
`native/**` (send native specs), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-20 (orchestrator, at launch).** Not started. CP36.1 (the joint ship) was checking on builder0 at launch.
