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

### W1b and W2 built, default OFF; quick green (2026-10-19 ~10:30 PDT)

`9d2486dab` builder0 `make quick-remote` (QUICK_BASE 0f4d528d7) **exited 0, 75 passed 0 failed**, lint clean. W2's boxed War Rig
(four parked squadmates, face 90° right): ON gives up after 3 failed plans and stands (throttle 0, moved 0.0 m over the last 3 s,
`face_settled()` true); OFF creeps (throttle 0.7, 3.2 m). Open ground: turns to 3.4°, no give-up. W1b's rule test: 3/3. Orchestrator: W1b
approved (R35.7, arenas locks/terminus/sumps); Bar M5 filed on main 8640ec500. Dev reads running (tuning seeds: wedge 3500–3503 ×
locks/terminus/sumps, both arms GDScript; hull-rest 460–463 drawn on lab/cpf5 bdacb1786).

### W1 TRACED, design note sent (2026-10-19 ~09:30 PDT): `references/round35/manoeuvre/w1-trace/README.md`

builder0, native path, behaviour of main a0ae0aafd + the probe, Locks/Terminus × fresh 3500–3511, 24 fights × 180 s, 984 deaths:
**81 stuck:wedged (8.2 %, T5's rate)**, 80/81 hit in the last 10 s, 67/81 wheeled. Two populations, neither one stuck: **41 % held by
Traffic's take-turns hold** at a street mouth under fire (median 5.4 s into the hold; the 3 longest episodes, 18 s, all holds; on
wheels the at-spot hold is throttle 0 at full lock = the plant's creep shuffle, 67/106 at-spot ticks moving); **59 % ORCA slowing a
crew in a fight's crowd, wedged a median 1.2 s** before death. Unstick drove 1 % of ticks. Proposals: (A) no new wedged trigger;
(B) traffic: a held crew that is hit leaves the hold (request); (C) mine W1b: a wheeled hull held to a standstill doesn't creep
(native mirrors); (D) traffic's death_cause gets `jam:held`. Waiting on the orchestrator for (C); built OFF meanwhile.

### Bar M5 (W2, CP-F attempt 5, the face side; C35.7, decoupled from brains by R35.3) — DRAFT, to the orchestrator before any number

**Candidate:** stream/manoeuvre + `TURN_HULL_DEFAULT := true` + `FACE_SETTLE_DEFAULT := true` (lab/cpf5). **Base:** the same tree,
`--nav-off=turnhull,facesettle`. **Gate (C31.1):** lab/cpf5's whole `make native check` green on builder0 (sim-baseline moves
attributed with `--nav-off=turnhull,facesettle`). **Machine:** builder0 only, one series at a time (C35.1), FAR_JOBS/HULL_JOBS 3 while a
check runs. **Seeds (fresh):** hull-rest 701–716 (4 factions × 16 × 6 tasks, drawn and clicked, GDScript M1_GD=1 both arms, plus
the native drawn pair), Terminus 720–732, SBF 770–775, bridge-pooled's 18, fights on FIXED arenas locks/terminus/sumps × 740–763
(`FIGHT_AT`, R34.15). **Ruler and noise:** M1's (real_mps, wedged apart, HULL_SHIFT_M 6, HULL_JITTER_DEG 20), the A/A table in
round 34's Status. **Lines:** Bar M3's (a)–(m) unchanged (same rules, same A/A guards), plus:
| line | reads | rule |
|---|---|---|
| (n) | `face_creep` crews at the judge (hull_rest_moving), wheels/turret, per task | new ≤ base + 1 (attempt 4 read 8 v 0 on screen; the mechanism this attempt removes) |
| (o2) | counters in the new arm | `face_settles` > 0 and `face_settle_fails` REPORTED; `hull_turns` > 0 |
| (p) | wheels/turret at rest error, the crews that gave up | REPORTED (median, and how many ≥ 45°): the price of standing still |
**Partial:** (a)–(j), (n) are the gate; a miss parks it with a trace. Attack-move's step (attempt 4's mechanism 2) is brains' (R35.3,
the straggler release); if (d)/(e) miss on attack-move only, the trace says which mechanism, and the verdict goes to the orchestrator.

### Bar M6 (W1c, the stall gate reads the drive's intent against a friendly hull; R35.12) — DRAFT, to the orchestrator before code

**Change:** in `Movement._unstick`, for a ROUTED move (`move_to`, not `direct`) whose hull is in contact with a friendly hull (slide
collision) or whose phase is `blocked` by a friend, the stall rule's throttle test reads the drive's intent, |throttle| / pace when
pace < 1; every other case keeps `|throttle| > 0.5`. H1's escape unchanged (ask, straight reverse by the sweep, stand). Switch
`--nav-off=stallintent` (default OFF until this bar passes); native mirrors after the dev read. **Candidate** = stream + the
default flipped (lab/w1c), as a pair with native's mirror; **base** = the same tree `--nav-off=stallintent`. **Gate:** the pair's
whole `make native check` on builder0. **Seeds (fresh, outside E1's and M5's 701–716):** hull-rest 901–916 (4 factions × 16 × 6
tasks, drawn, both arms on the pair's native path), fights on FIXED locks/terminus/sumps × 940–963 (`FIGHT_AT`; also the wedge probe's
WEDGE_RANGE 940–963 for far loops / contacts / asks). Tuning seeds stay 460–475 and wedge 3500–3511.
| line | reads | rule |
|---|---|---|
| (0) counter first | in the ON arm: stall clocks run under the intent reading (`stall_intent_ticks`), H1 escapes started (`esc_fires_hull`), asks (`esc_asks`) | each > 0, or nothing is read |
| (d) deciding | hull-rest attack-move crews moving at the judge by `real_mps` (wedged apart) | new ≤ base − 1.645 × sd_run(A/A 1.17) × √pairs; also no other task worse than Bar M3's (d) guard (+1.645 sd√n: right 0.64, move 0.51, screen 0.41, ambush 0.24, SBF 0.23) |
| (e) deciding | attack-move never settled (75 s) | new ≤ base, and no task over base + Bar M3's (e) guard (se 3.0 a task at 64 pairs) |
| (f) | arrivals within ARRIVED_M | not down beyond 1.645 se paired |
| (i) fights | kills, deaths, hit rate per team (fight_table) | within 1.645 se paired |
| (q) jams | stuck, jam (yielding/friend) and open deaths (wedge probe's causes) | each within 1.645 se paired |
| (r) far loops | ManoeuvreCensus far rows | ≤ base + 1.645 se |
| (s) friendly contacts | ticks touching a friendly hull (wedge probe) | ≤ base + 1.645 se |
| (t) asks | H1 asks and give-ways started, per fight | REPORTED (the churn risk) beside base |
**Partial:** (0), (d), (e), (f), (i), (q)–(s) are the gate. A miss parks it with a trace.

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
