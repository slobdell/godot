# Stream: manoeuvre (fewer crews die shoved around in a lane mouth; a wheeled hull told to face a way faces it and goes still)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md` (M1's A/A rows), `_agents/workstreams.md` **Round 35**
> (C35.1, C35.3, C35.6, C35.7; R34.10, R34.18 in *Round 34*), and your round-34 brief `streams/archive/round34/manoeuvre.md`
> (its Status is the close-out: M0, M1, M2, CP-F 4, the wedged-death table). Evidence: `references/round34/manoeuvre/`
> (cpf4-series, wedged-deaths, m2-report), traffic's T5 census `references/round34/traffic/t5_jam_death_census.md`.
> **You own:** round 34's carve-outs: the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, the k-turn executor, H1/H1b,
> the face-at-rest path in `order_controller.gd`, the `_order_move` decline for wheeled turret hulls, `game/ai/manoeuvre*.gd`,
> `tests/manoeuvre/**`, `tests/test_manoeuvre*.gd`, `mk/manoeuvre.mk`, additive fields in `game/control/screen_playtest.gd`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His answer at round 34's close: **"Ship it"**: the scout
turn-in (M0) ships (the orchestrator merges `pair/c339-r34b` `3902ade09` on its green check, C35.3). His standing CP-F ask: a War
Rig or other wheeled turret vehicle told to face a direction ends facing it and sits still.

What he will notice: fewer crews dying while being shoved around in a lane mouth; a wheeled hull told to face a way turns to it
and goes still, without the squad hanging at each leg.

## Where things stand

- **Shipped in round 34:** M1 the ruler (real_mps, wedged apart, A/A), M2 the arrival hold (ARRIVE_LEG_DEFAULT on), the M0 turn-in
  (merging under C35.3).
- **Wedged deaths (C35.6):** 499 of 5984 (8.3 %, 3.5 a fight) in T5's census, all `driving`, none held; mid-weight hulls (suppressor,
  burner, IFV, tank, lancer 13–16 % of their own deaths); lanes, the Locks lane mouths worst; median speed at death 1.2 m/s, 85 %
  under fire, only 26 % below STUCK_SPEED, so the stall rule never sees most of them.
- **CP-F (R34.18):** the turn is right (3–4° v ~50°); it failed on settling: faces no plan fits creep at the 0.35 lock until the
  judge, and attack-move elements step ~30 s later when arrived crews sit on a sector face (brains' side).

## Backlog (in order)

1. **W1 Wedged deaths: trace first.** On main, fresh seeds on the Locks/Terminus lanes: for the three largest episodes, which force
   moves the hull (ORCA, avoid, around_friends, the drive's own steer), what `Movement.wedged` and unstick saw, and what the crew was
   ordered to do. Then a design note to the orchestrator (a wedged trigger that acts on walking-pace shoving; what a crew under
   fire should do instead: back off, hold, or push through). Then a bar before any number: deciding gain wedged deaths; guards open,
   stuck, jam deaths, far loops, kills, hit rate (as T6b's). Native mirrors anything in the drive.
2. **W2 CP-F attempt 5, the face side (C35.7).** A face that gives up cleanly after N refused plans (no creep at the 0.35 lock).
   The seam with brains' element step is agreed through the orchestrator before code. A fresh bar with guards from M1's A/A.
3. **Stretch:** the watch item from R34.16 (one 9.1 m both-planned face) if a face_pairs series runs.

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins
(`tools/judge/seed_twins.py`). Every number: commit, machine, workload, n.

## Don't touch

Traffic's give-way block, brains' tactics/ai outside your carve-outs, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
