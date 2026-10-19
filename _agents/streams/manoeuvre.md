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

### W1 TRACED, design note sent (2026-10-19 ~09:30 PDT): `references/round35/manoeuvre/w1-trace/README.md`

builder0, native path, behaviour of main a0ae0aafd + the probe, Locks/Terminus × fresh 3500–3511, 24 fights × 180 s, 984 deaths:
**81 stuck:wedged (8.2 %, T5's rate)**, 80/81 hit in the last 10 s, 67/81 wheeled. Two populations, neither one stuck: **41 % held by
Traffic's take-turns hold** at a street mouth under fire (median 5.4 s into the hold; the 3 longest episodes, 18 s, all holds; on
wheels the at-spot hold is throttle 0 at full lock = the plant's creep shuffle, 67/106 at-spot ticks moving); **59 % ORCA slowing a
crew in a fight's crowd, wedged a median 1.2 s** before death. Unstick drove 1 % of ticks. Proposals: (A) no new wedged trigger;
(B) traffic: a held crew that is hit leaves the hold (request); (C) mine W1b: a wheeled hull held to a standstill doesn't creep
(native mirrors); (D) traffic's death_cause gets `jam:held`. Waiting on the orchestrator for (C); built OFF meanwhile.

### Requests to other streams

- **traffic:** (B) release a Traffic hold for a crew being hit; (D) `jam:held` in `death_cause` before `stuck:wedged`.
- **native:** mirror W1b in drive_native (pace-0 wheeled hold: turn 0) once the switch's GDScript lands.

### Plan (2026-10-19, Opus)

1. **W1 trace** — `tests/manoeuvre/wedge_trace.gd` + `wedge_table.py`, `make native manoeuvre-wedge-trace` (WEDGE_AT, WEDGE_RANGE;
   fresh seeds 3500+ on Locks/Terminus; native path). Per wedged episode: what shaped the motion each tick (unstick / k-turn /
   yield / Traffic hold / ORCA turn / ORCA slow / sideways shove / the drive itself), what unstick's stall rule saw, the order and
   brain option, hits, friends near. Per `stuck:wedged` death (T5's `death_cause`, verbatim): a 10 s timeline. → design note to
   the orchestrator → bar → only then a change.
2. **W2 face settle** — seam proposed to the orchestrator 2026-10-19 (a face no plan fits 3 times in a row stops still, `--nav-off=facesettle`,
   ships with turnhull ON; `Movement.face_settled()` offered to brains). Code waits for the agreement.
3. **Stretch** — the R34.16 watch item, if a face_pairs series runs.

### W1 first read (laptop, stream a0ae0aafd + probe, locks s3500, 90 s, one fight, mechanism only)

The `wedged` flag counts every tick whose pace is under 0.999 — so a crew **holding at a street mouth on purpose** (Traffic's
take-turns hold, pace 0) and a crew **giving way** are "wedged" too. In that fight: 251 episodes; by tick, Traffic hold 37 %,
ORCA slow 36 %, yield 10 %, drive 8 %, ORCA turn 6 %, k-turn 3 %, shove 1 %. Of 5 wedged-at-death crews, one was holding (pace 0,
held True), which T5's `death_cause` files as `stuck:wedged`. The builder0 batch (24 fights) decides how big that share is.
