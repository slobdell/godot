# Stream: manoeuvre (a wheeled turret vehicle told to face a direction ends facing it and sits still: a better ruler, the arrival flicker, then CP-F attempt 4)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md`, `_agents/workstreams.md` **Round 34** (C34.1, C34.4; R33.2, R33.21, R33.23,
> R33.34, R33.35 in *Round 33*), `_agents/roadmap.md` *Round 34 candidates* (the hull-rest entries, the k-turn flicker),
> your round-33 brief `streams/archive/round33/manoeuvre.md` (its close-out Status), and planner's diagnosis
> `references/round33/planner/face-flip-s69/`. Evidence: `references/round33/manoeuvre/` (cpf3b-series, cpf-arriveleg-dev,
> c339-judged). Raw runs (1.4 GB): `/home/slobdell/overnight-manoeuvre`, outside the repo.
> **You own:** round 33's manoeuvre paths (`game/ai/movement.gd`'s `drive()` body, `_nose_stop`, `unstick`,
> `_pressing_escape`, H1/H1b, the k-turn / planned-reverse / circle executor; `game/ai/manoeuvre*.gd`, `clothoid.gd`,
> `wall_contact.gd`; the face-at-rest path and C33.9's turn-in in `order_controller.gd`; `tests/test_manoeuvre*.gd`,
> `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`).
> **Granted (round 34):** `game/control/screen_playtest.gd`, ADDITIVE only: `real_mps` per hull-rest crew row (1B) and
> `--faced-shift-m` (2B); defaults unchanged, merge note. Still granted: gunnery's two aim-lead lines and the `_order_move`
> decline for wheeled turret hulls under turnhull (C31.8). **The C++ (C31.2):** send native each settled diff.
> **Model: FABLE** (CP-F has parked three times).

## The lead's direction

Round 28, call 2: **turn the whole vehicle to his drawn facing.** At round 33's close (2026-10-18) he chose to keep CP-F
parked and give it a fourth try now, on top of the herringbone fix. What he will notice: a War Rig, gang tank or IFV he
tells to face a direction ends with its hull pointing there and then sits still. With brains' B11b on top, one pushed off
its post goes back and faces his way again.

## Where things stand (main at the round-34 docs commit)

- **C33.9 (his scout report) did NOT ship (R33.38, R33.39).** He said ship attempt 1. Its whole suite with the switch
  ON then went red: the turn-in took every plain face and every `stop` swing, so a wheeled hull turning in place drove
  24.5 m (creep_bound), and a tracking scout rolled in a swept lane. Both narrowings tried at the close flipped judged
  lines on seeds 31–36 (`fc809b60a`: (c) worst in-reach cell −46 %, (d) max 13 reverse ticks). C31.1 had not been run
  before the judged series. Carry: `pair/c339-ship` `fc809b60a`, `lab/c339-turnin` `781801da0`, refs
  `references/round33/manoeuvre/c339-narrow/`. Native's stop hand-back (`pair/native-c339` `2f9ad0fb9`) covers any
  narrowing.
- **CP-F attempt 3 PARKED narrowly (R33.34):** turrets end 3–4° off the drawn facing (93–96 % within 15°) against
  60–100° today. It missed one line, gang crews still driving at 75 s on attack-move (+7 against 6.5). The trace (R33.35)
  showed those late movers came from the herringbone re-lay, which brains fixed on main (`7f27a479c`; seat jumps 107 v 2342).
- **The judge was part of every miss.** R33.21's series ran unpinned on a loaded box. hull-rest's "still" reads reported
  velocity, so a wedged hull counts as moving. Seeds 40 = 43 and 44 = 45 row for row. Your judge fixes (`cpf_judge.py`:
  jitter, `--wedged`, `--distinct`) and the CP-F code are on `round33/manoeuvre` `18e37ec76`, default OFF.
- **The k-turn arrival flicker (planner's s69):** a k-turn leg that crosses the 6 m arrival circle turns the order into a
  face nobody wanted. Your lab is `lab/cpf-arriveleg` `7e0953f9d`: one condition in `TankBrain._act`'s arrived branch, which
  is brains' code.

## Backlog (in order)

0. **M0 C33.9, the scout turn-in, done right (his report; he already said ship it).** Scope it to the case he reported:
   a scout's crew facing a live threat it can't yaw onto at rest. Never a plain face, a static spot or a `stop` with
   nothing to face. The order: (1) the WHOLE suite with the switch ON first (C31.1), and every test and scenario passes
   unchanged; (2) a fresh bar, filed before any number, on FRESH orbit seeds (not 11–36), keeping R33.24's lines; (3) the
   judged series on one machine; (4) the pair with native's hand-back. It ships ON when it passes. Out of reach, brains' scout
   try 2 decides whether the scout leaves (C34.5), so agree with brains which arm each judges on.
1. **M1 The ruler (C34.4 (1)).** Rebase `round33/manoeuvre`'s judge onto main (`git merge main` on a branch from it). Add 1B
   (`real_mps`) and 2B (`--faced-shift-m`) in screen_playtest. "Still" reads real velocity, wedged crews get their own line,
   the seed varies the geometry, and every hull-rest target is pinned. Then an A/A (OFF v OFF) on the new ruler on builder2,
   sized like planner's P1 (n ≥ 36 paired). The sd rows go to planner for `judging.md`. Ship the ruler alone (tests plus a
   check; it changes no game behaviour).
2. **M2 The flicker (C34.4 (2)).** Restate planner's s69 on current main. Agree the seam with brains through the orchestrator
   BEFORE code (brains owns `_act`'s arrived branch and `_order_move`'s held-post refusal; you own WHEN a faced finish runs,
   R33.2). A test that fails without the fix. If it's a bug fix, it ships alone with its check, before M3.
3. **M3 CP-F attempt 4 (C34.4 (3)).** On main (herringbone and M1/M2 in), a fresh bar filed before any number, on the new
   ruler. Fresh seeds, not 41/44/45/66/67. One machine. The pair = main + CP-F ON + native's mirrors only. Ships ON. **Tell
   brains the merge hash the day it lands** (B11b).
4. **M4 Help B11b:** answer brains' questions on the face step.
5. **Stretch:** a short clip of a War Rig told to face behind, before and after, for him (builder0 renders; builder2 has no
   display).

## How to verify

`make quick-remote` to iterate; `make native check` on the pair tree (switch ON) before any series, only for named hashes.
`make manoeuvre-hull-rest`, `manoeuvre-fights`, `manoeuvre-census`, `cpf_judge.py`, `test_manoeuvre_face_behind`,
`native-verify-scenarios`. Build squad-facing fixes on stages that form elements. Long remote runs under `systemd-run
--user`. Every number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; planner's `game/ai/planner/**`; brains' `tank_brain.gd` (beyond the
granted decline and an AGREED flicker seam), elements, `game/tactics/**`; native's `native/**`; `game/match/**`;
`game/control/**` beyond the 1B/2B grant; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (2026-10-19 early, round 34 in progress; Fable)

**Latest (2026-10-19 ~00:30 PDT):** M0's candidate is now stream/manoeuvre **fa5226f14**; its dev cells 11–23 run on
builder2, then the REPORTED syn_lancer cell. The superseded pair d38f688f2's C31.1 check on builder2 (`make native check
exited 2`): every test passed (2818/0), native twins 0 mismatches (test_native_execute_turn_in PASS, 276 turn_in_stop
hand-backs), lint clean; the one FAIL is sim-baseline with four maps MOVED (crossing, parade, archipelago, docks: brains'
scouts in contact now turn in), the NOT JUDGED is perf-judge's load refusal. The orchestrator asks the moves attributed on
the pair tree with `--nav-off=turnin` before the series (`make gcp-remote T="sim-variants VARIANTS_EXTRA=--nav-off=turnin
VARIANTS_TAG=turninoff"` against main's lines), and main ≥ 82feffa86 (docks adopted at B1's hash) merged at the re-cut.

**Third round of fixes (fa5226f14), from the 5055a6ed8 dev cells (builder2, 11–23, n 13):** the 5055a6ed8 table read
(a) 3.8 → **75.7 %** in-arc on in-reach cells, exchange 0.18 → 2.02, in-reach hits taken 104 → 85, (d)/(d2)/(e)/(g)
pass, but law_scout v syn_scout 15 m dealt **0 in every seed** and took 496 against 440 damage: my creep-line floor
`sqrt(yaw_share × 0.55 × 1.1)` read 1.15 for a 310 deg/s want, so the hull ran at 16 m/s, past the speed at which full
lock reaches its yaw cap, and sat 60° off the orbiter for 25 s (the failure the original code's comment names). Now the
floor is capped at TURN_IN_ROLL and the throttle at the yaw-cap speed; and when the bearing's own swing (rate + own)
outruns what full lock at the cap can yaw (a 17 m/s scout at 10 m), the catch-up JINKS instead of chasing smoothly (a
smooth circle is the easiest motion for the orbiter's lead). Laptop: that cell s11 0 → 31 dealt, 19 → 23 % in arc; s36
91 %; the other four cells unchanged. R34.1's lines read on the 5055a6ed8 dev rows (dev seeds; steering only, the bar
stays as filed): (a) PASS (75.7, sd_boot 3.0), (b) PASS, (c) exchange PASS (gain 1.84, k·sd 0.13), in-reach hits guard
PASS (−1317 v k·se 528), per-cell damage guard **FAIL on law v scout 15 m** (+56 a run v k·se 47; the other five pass by
12–257), (c-out) FAIL as written (+996 v k·se 592) but within what he accepted (medians 45 → 50, worst +23 %), (d) (d2)
(e) (g) PASS. The one line at risk is that cell's damage guard, at the hull's physical limit; fa5226f14's jink is aimed at
it, and the series' verdict falls where it falls (the orchestrator, 2026-10-19).

**M2 is built:** `lab/m2-arriveleg` bbf1f6b77 (main 9c0f4dfce merged, brains' adapter in): `Manoeuvre.leg_holds_arrival`
holds a move_to's arrival while a planned leg drives, bounded at 3 s of leg time per order (`Movement.arrive_hold_until`,
reset by new_order), `arrivals_held` once per order + `arrivals_held_ticks`, `--nav-off=arriveleg` (default ON), census
counters; tests/test_manoeuvre_arrive_leg.gd (the hold, its bound, the counters; the seam end to end through brains'
`_leg_holds_arrival`, the hold counted, held_moves_refused 0) + brains' tests/test_ai_arrive_leg.gd: 3/3 laptop. Its
quick-remote runs on builder0; its check waits behind M0 on builder2.

**M0 (C34.10): candidate stream/manoeuvre 5055a6ed8 (main 9c0f4dfce merged); pair tree `pair/c339-r34` d38f688f2 (= 5055a6ed8 +
`pair/native-c339`'s three native commits, clean). Its C31.1 `native check` runs on builder2 (folder godot-manoeuvre-pair);
dev cells 11–23 both arms run on builder2 (godot-manoeuvre), then the REPORTED gang_scout v syn_lancer cell. The bar is
filed (R34.1). Nothing judged yet.** builder0 went down ~22:55 PDT; nothing was read from it after that.

**M0, the second round of fixes (5055a6ed8; from the first dev set at dd0b2127c, builder0, 11–23 n 13: (a) 18.8 against
the judged tree's 21.3; the loss was all in the 30 m fast-orbit cells, law_scout v syn_scout 30 m 71 → 14 % in-arc,
while law v IFV 15 m went 23 → 71 % and hits taken 130 → 11):**
1. The catch-up (live) branch floored its speed at TURN_IN_ROLL 0.55 with a FULL lock whatever the wanted yaw. Once the
   want was small it chattered left-right every tick (yaw 92 deg/s read per tick, the heading net still), and a hull
   with an 11° error drove nearly straight at 6.9 m/s, out past its leash every time. Now: the lock is proportional
   (yaw_share / throttle) and the speed floor is the creep line (sqrt(yaw_share × WHEEL_CREEP × 1.1)), as the on-target
   branch already had.
2. The leash's first tier (14–18 m from the post, heading away) SLOWS THE DANCE: no fast dwell, the tightest circle that
   still tracks the target (creep-line share, the lock it needs). Round 33's override (full lock the shortest way home)
   was the target's far side half the time and lost a 48 deg/s orbiter for a lap; on the target's own side alone a
   gang_scout spiralled 65 m from its post (seed 17). Past 18 m, round 33's override as it was.

| laptop cell (n 1, --fixed-fps 30; mechanism only) | judged tree 781801da0 | dd0b2127c | 5055a6ed8 |
|---|---|---|---|
| law_scout v syn_scout 30 m s11: in-arc / hits / far | 71 % / 108 / 15 m | 11 % / 111 / 17 m | **91 % / 82 / 17 m** |
| law_scout v syn_scout 15 m s36 | 50 % / 150 | 22 % / 129 | **91 % / 147 / 20 m** |
| gang_scout v syn_scout 15 m s17 | 76 % / 149 | 7 % / 159 | **86 % / 108 / 17 m** |
| law_scout v gang_ifv 15 m s19 | 19 % / 140 | 94 % / 0 | **94 % / 1 / 12 m** |
| gang_scout v gang_ifv 30 m s12 | — | — | 32 % / 36 / 24 m |
Every run: 0 reverse ticks under a reverse command. The 7 orbit tests pass (laptop).

**Plan (ordered):** M0 C33.9 (the fix → quick-remote → dev cells 11–23 on builder0 → the bar to the orchestrator →
C31.1 full suite ON on the pair tree, builder2 → the judged series, fresh seeds, builder2) → M1 the ruler (1B/2B, A/A) →
M2 the flicker (seam agreed with brains, see below) → M3 CP-F attempt 4 → M4 → stretch clip.

**M0, what round 33's narrowing really failed on (laptop traces, commit dd0b2127c's tests; `C339_ONE=law_scout,syn_scout,15,36 C339_DENSE=1.4-5.4 make test FILTER=c339_cells`):**
1. Seed 36's 13 reverse ticks (R33.39): the scout turned in, closed from 15 to 3 m and sat on the orbiter's nose; the
   orbiter STOPPED for 3.0 s (its velocity read 0.0 from t1.6 to t4.6); the turn-in's "spot stood still 3 s → the face
   planner" rule handed a live threat face to the planner, whose first leg was a reverse (NEGCMD t4.63–5.17). Neither
   narrowing (speed gate on the first ticks, R33.38) touched this path; the speed gate itself made it worse because the
   stage's orbiter starts from rest.
2. The brain's face spot is STALE by 1–2 m: `TankBrain._order_move` drops a face within 2 m of the one executing (its
   near-duplicate rule, brains' code, correct for a fixed point), so after the enemy stops the spot sits where it was
   last re-issued (seed 14 halt trace: spot (13.7,−13.2), enemy (15.3,−12.4): 7° at 14 m, half a scout's arc). A hull
   holding on the spot had the real enemy at the edge of its arc and fired once in 10 s.
3. The judged ruler: (c)'s per-cell exchange on gang_scout/syn_scout/15 is 0.04 → 0.02 ("−46 %") in a cell where the
   gang scout deals nothing in 5 of 6 runs; its seed bootstrap at n = 6 spans −100..+135 %. That line cannot carry a
   verdict at any n this round can run; the bar below re-forms it.

**M0, the fix (dd0b2127c, `game/ai/manoeuvre.gd` turn_in, `order_controller.gd` _stop_turn_in, `movement.gd` face_drop):**
the turn-in resolves its spot to the LIVE ENEMY HULL it stands for (`Manoeuvre.live_enemy_near`: the nearest within
10 m; a brain's crew only; a threat face only, `from` empty, or a stop's swing) and reads the bearing, its rate (from the
enemy's velocity: d(theta)/dt = (p × v).y / |p|², smoothed a tick) and whether it STANDS (< 0.5 m/s) from that hull every
tick. A standing enemy in the arc: hold still and shoot. Out of the arc: come round forward (full lock at ≥ 0.55 share).
The face planner takes a face only when NO live enemy is at its spot (a memory, a drawn, post, sector or squad facing, a
scripted order): so creep_bound's plain faces, the suppression scenario's scripted scout and every drawn facing are
untouched, and a live threat face never reaches the planner's reverse legs. The planner's leftover legs are dropped the
tick a turn-in has the hull. The spot-step rate machinery (`_turn_in_bearing/_tick/_seen`, TURN_IN_MOVING_S, the speed
gate `facing_mover`) is gone. Native's stop hand-back (`pair/native-c339` 2f9ad0fb9) is untouched by this: the C++ hands
every stop on a fixed gun on wheels back under the switch, and the GDScript decides.

| test (laptop, --fixed-fps 30, n 1) | old code (fc809b60a's gate) | dd0b2127c |
|---|---|---|
| halted orbiter (gang_scout v syn_scout 15 m, seed 14, enemy stops at 2 s) | rev cmd 12, gear changes 1, in-arc 60 % | rev cmd 0, 0, in-arc 69 %, held still 181 ticks, dealt 137 |
| parked enemy (law_scout, syn_scout standing at 20 m 133° off, seed 36, 10 s) | turn-in never ran; the creep reversed 81 ticks; in-arc 44 % | rev cmd 0; in-arc 83 %; 84 shots; 9.4 m from post |
| (d2) stop (gang_scout v syn_scout 15 m, seed 14) | OFF 27 reverse ticks at stop | ON 0 |
| static drawn face (6 cells), determinism (2 fresh children) | pass | pass |

Laptop rows are for mechanism only: a pinned laptop run of seed 36 did NOT reproduce builder2's row (in-arc 22.4 v 12.4,
reverse 0 v 13 under the same code), so the laptop is not row-equivalent to the builders even at --fixed-fps (builder0 v
builder2 were 312/312 in round 33). Every judged or dev number below is a builder's.

**M2 seam (agreed through the orchestrator, 2026-10-18):** brains takes `lab/cpf-arriveleg` 7e0953f9d's one condition into
`TankBrain._act` as-is and keeps `_order_move`'s held-post refusal; manoeuvre owns `Manoeuvre.leg_holds_arrival` and the
`arriveleg` switch, bounds the hold at 3 s of leg time, and ships it with a test that fails without it. The counter's unit
(think ticks v arrivals) waits on brains' answer via the orchestrator.

**Native (C34.8):** native pinned command.mk's hull-rest/facing/flank probes (d8ce74b91, one $(PIN_FPS) token each): M1 adds
no second pin. `tests/test_manoeuvre_wedge.gd`'s "native: absent" return goes to `NativeExpect.absent(self)` once native's
12ac7b172 is on main (they will say).

### Bar M0 (C34.10): the scout turn-in, round 34 (filed 2026-10-18 before any fresh-seed number)

**Probe:** the orbit stage, `tests/test_manoeuvre_orbit.gd` `_orbit_stage` via `make manoeuvre-c339-cells` (one
`--fixed-fps 30` Godot a seed, both arms GDScript): 2 subjects (law_scout, gang_scout) × 2 orbiters (syn_scout, gang_ifv)
× 3 radii (15, 30, 45 m) × post (player / free) × arm (ON / OFF), 30 s a cell. In reach = radius ≤ the scout's
`reach_m` (35 m): the six in-reach player cells are gang 15 m, law 15 and 30 m against each orbiter.
**Candidate:** stream/manoeuvre at the hash whose C31.1 check is green (the pair tree = main + this branch +
`pair/native-c339`'s three native commits rebased; TURN_IN_DEFAULT true). **Base:** the same tree, `--nav-off=turnin`.
**Machine:** builder2, start to end; builder0 for dev only. **Seeds:** FRESH 101–112 (n = 12 a cell, 576 rows); 11–36 are
tuning. **Last attempt:** this is C33.9's second judged series (R33.24 was the first); a third would need a new design.
**Counters:** `turn_in` ticks/stalls, `holds`, `hold_ticks`, `stop_turn_ins` in every row.
**Noise, read from round 33's rows** (c339-judged/cells-31-36.jsonl n 6; dev-11-23 n 13; the bootstrap resamples seeds):
(a) pooled in-arc median sd_boot 3.5 at n 6 (≈ 2.5 at n 12); in-reach pooled exchange sd_boot 0.13 at n 6 (≈ 0.09);
per-cell damage-taken sd a run 12–90 (law/syn/15 11.7; gang/syn/15 89.6); per-cell hits-taken sd 6–38.

Lines, player-post cells (R33.24's lines kept, each in its variance-aware form; k = 1.645):
- **(a)** in-arc % median on in-reach cells: ON ≥ 2 × OFF and ≥ 25 (the point as R33.24 wrote it). Beside the verdict:
  sd_boot and the margin to R33.24's 23.9, the value he accepted (R33.38). *Ship reading:* ≥ 25 passes; ≥ 23.9 − k·sd_boot
  is "no worse than what he accepted" and is reported as such for the orchestrator's ruling; below that is a regression.
- **(b)** shots median, every player cell: ON ≥ 1.5 × OFF.
- **(c)** exchange (damage dealt / taken) pooled on in-reach cells: ON ≥ OFF (point) AND the gain distinguishable from
  nothing (ON − OFF − k·sd_boot > 0). **Re-formed:** the per-cell −20 % exchange ratio is a REPORT, not a line (a cell
  whose OFF deals 0.04 cannot carry a ratio: bootstrap −100..+135 %). In its place, two guards on harm he would see:
  in-reach pooled hits taken ON ≤ OFF + k·se (se = paired se of the sum over the 72 run pairs), and per in-reach cell
  damage taken ON ≤ OFF + k·se_cell (se_cell from that cell's 12 paired differences).
- **(c-out)** out-of-reach player cells: pooled hits taken ON ≤ OFF + k·se, and no cell with OFF ≥ 10 worse than +20 %
  (as R33.24 wrote). Beside the verdict: R33.24's accepted 42 → 57 / +37 %. *Ship reading* as (a): ≤ 57 and ≤ +37 % is
  "no worse than what he accepted"; out of reach is brains' C34.5 (the outgunned scout leaves), so the orchestrator rules.
- **(d)** while a face holds: 0 ticks under a reverse command in every ON run; commanded gear changes ≤ 2 a run. A
  deterministic count: a failing run is named and its trace read before the medians (lesson 302).
- **(d2)** while the order is `stop`: 0 reverse ticks in every ON run (OFF reported: the shuffle he saw).
- **(e)** furthest from the post ≤ 29 m in every ON run (14 m leash + a turning circle + a hull).
- **(g)** free cells: ON no worse than OFF on (a)–(c) medians; if the arms are byte-identical, say so.
- **(h) reported:** holds / hold_ticks, mean distance, damage, stalls, the per-cell exchange table.
**Before the series:** C31.1, the whole suite with the switch ON on the pair tree, green on builder2, with any sim-baseline
move named and explained as the turn-in's own (the brains' scouts that now turn in). **Partial rule:** (a) alone missing
by less than its sd_boot does not park a candidate that passes (b)–(g); any (d)/(d2)/(e) run fails it.

