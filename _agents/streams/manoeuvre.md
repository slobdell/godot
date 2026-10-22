# Stream: manoeuvre (parked crews make way and come straight back; CPU screens out of the way)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1) and in
> *Round 37*: R37.6, R37.10, R37.30, R37.32 and Bar M5. Your round-37 close notes: `streams/archive/round37/manoeuvre.md`; orders'
> O5 notes in `streams/archive/round37/orders.md`. **You own:** `movement.gd`'s drive / unstick / side-step and traffic's give-way
> block, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`; GRANT:
> `element_commander.gd`'s screen / support_by_fire seat choice for M7 (merge note to doctrine). **Model:** Opus. **Machine:** builder0.

## The lead's direction

"the general priority is to mitigate vehicle contention with one another"; parked squads "Stay put and shoot"; units must look smart.

What he will notice: a parked crew that makes way for a friend steps aside and reverses straight back instead of leading the friend out
or turning round; CPU squads screening a street don't block their own traffic.

## Where things stand (switches on main, OFF)

- **M5a seatstep (R37.30):** seat metres -8.5 %, lead-outs 747 -> 436, but failed guards: team 1 kills -89 (fights got smaller, not
  one-sided) and faced_ambush never-settled 5 -> 10 (your later read: a redraw on path differences, no mechanism).
- **O5 seat-aside (R37.32):** CPU screen give-ways -23 % (bar asked -50 %): screen->screen 742 -> 438, but screen->support_by_fire
  251 -> 255 (the aside step doesn't see support_by_fire routes).

## Backlog (in order)

1. **M1 M5 v2:** file the bar first with your close notes' changes: (a) kill SHARE per team + both teams' total deaths, not "each team's
   kills not down"; (b) size never-settled (e)'s noise floor first (base v base, two paths). Then the series. Symmetric: a pass ships ON.
2. **M2 M5b the reverse-back:** trace first; native twin request; bar.
3. **M7 O5 v2:** the aside step also reads support_by_fire routes; bar from R37.32's base.
4. **Stretch:** M3's S1 v2 (count the stall base rate with M2's total before building).

## How to verify

Lab both paths; `make quick-remote`; series on fresh seeds; every number with commit, machine, workload, n.

## Don't touch

settle's deploy/halt/seat functions, orders' control paths, doctrine's brains paths beyond your grant, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**MERGED: main 8bfb74e55 merges 84c79d76f (orchestrator).** **2026-10-22 ~14:10 (worker): THE STREAM IS GREEN at 84c79d76f (builder2, R38.2):** `make native check exited 0`, 3,055 passed / 0
failed, 25 passed + 2 NOT JUDGED (perf-judge: builder2 is not a judging machine; scenario_perf loaded), sim-baseline passed (unmoved:
everything new is OFF or tooling). Log `~/overnight-manoeuvre/r38/check_stream_84c79d76f.log`. Later commits are Status only.
**Merge notes:** `element_commander.gd` (my grant, doctrine's file): `--seat-aside=v2` adds `SEAT_ASIDE_WAYS`, `ASIDE_SEATED_M`,
`_member_ways()` and one branch in `_aside()`; default behaviour unchanged (v1 `on` unchanged). `mk/manoeuvre.mk`: +
`manoeuvre-aside-trace`. Perf for this OFF change is judged with main's on builder0.

**Start (worker, 2026-10-22):** stream/manoeuvre = main 5b20bfd62 (round 38's launch; HANDOFF: GREEN, all judged, builder0), so no
baseline check (contract 1).

**Now (2026-10-22 ~08:50):**
- M1: lab trees built on today's main (clean merge): BASE `lab/manoeuvre-r38-m5` 226e4c190 (worktree `godot-manoeuvre-m5`), ON
  `lab/manoeuvre-r38-m5on` 269d593c5 (`godot-manoeuvre-m5on`). Judge `m5_judge.py --v2` (b1c-) tried on round 37's rows: it runs.
  Series driver `~/overnight-manoeuvre/r38/m5/m5v2_series.sh` under `systemd-run --user --unit=manoeuvre-m5v2` (builder0, J=6):
  ON full check first, then jam 3 maps x 40 seeds x 2 arms, hull-rest 768 runs x 3 arms (ON, base, base GDScript = the floor).
  Log `~/overnight-manoeuvre/r38/m5/series-summary.txt`. Expect ~10-12 h at J=6.
- M2: return trace written (`lab/manoeuvre-r38-m5btrace`, worktree `godot-manoeuvre-trace`: a SEAT_RETURN row per seated
  give-way: spot ahead/side/behind of the nose, turned > 90 deg or reversed, Manoeuvre's plan and refusal for the seat).
- M7: trace written (`tests/manoeuvre/aside_trace.gd`, `make manoeuvre-aside-trace`): orders' seat-yield census + the asker's
  ways. Reading the O5 code: `_aside` already reads EVERY other element's way, support_by_fire included, but a support_by_fire
  task's `to` is its TARGET (the enemy), not its seat, so the "way" it tests is centre -> enemy. The trace checks that.

**builder0 use (C38.1, the orchestrator's machine note 2026-10-22):** ONE judged series at a time. Judged: the M5 v2 series
(`manoeuvre-m5v2`) STARTED 08:41 (its ON check queued first); end will be logged here. Light/short runs beside it: the M2 trace
tree's `make lint` (godot-manoeuvre-trace) and the M7 aside trace (18 fights, J=3, `manoeuvre-aside1`). The M2 trace census
waits until those two end. **10:12: the M5 v2 ON check (269d593c5) was KILLED by slot.sh after 5400 s** on a loaded builder0 (load
~35; test / ai-scenarios-check / remote-guard-test Terminated with empty logs; sim-baseline MOVED on yard/pit/archipelago/cut, as
expected with seatstep ON). Not a verdict. Driver patched (a slot kill = a lost try) and relaunched as `manoeuvre-m5v2b` ~11:10.
M2 trace census (`manoeuvre-m2trace`, jam 3 maps x 7001-7008, J=3, both arms) started 11:01; M7 v2 dev read (`manoeuvre-aside2`,
18 fights) ~11:05. **M5 v2 ON check accepted (builder2, 269d593c5, R38.2):** `make native check exited 2` = 3,063 passed / 0
failed, 0 native twin mismatches (seatstep yield cases incl.), sim-baseline MOVED yard/pit/archipelago/cut (expected, as round 37's
ON tree), web-smoke missed first-sound 34.3 s > 30 s at 2 fps (load 27); web-smoke alone on builder2 at 269d593c5 PASSED.
**The judged series STARTED 13:18 on builder0 (J=6, `manoeuvre-m5v2d`).** R38.8: orders' G1 series shares builder0 (J <= 4); no light runs of mine there while both run. M2 trace and M7 dev read ENDED (~12:50 / ~11:50).

**Native note for M5b (native, 2026-10-22):** `Manoeuvre.choose` / `behind` / `simulate` are MIRRORED in C++ since round 33
(drive_native.cpp `manoeuvre_decide`, `man_choose`, ~3170-3270; twin test_native_manoeuvre.gd). A change there needs native's
mirror before any series; only a change above Movement (the order issued, the seat) needs no twin. Native writes Manoeuvre.refused
and `_behind_plan` / `_behind_since` back, so the M2 trace's reads hold on the native path.

**Case from settle for after M5 v2 (orchestrator relay, 2026-10-22; information only):** crossing, 5-squad click, s3866,
`--halt-terrain=latch` (settle b013518a6, `references/round38/settle/s2-neverin-trace-builder0/README.md`, builder0 light native
e42ff30eb). On main a squad-3 tank yields 7 m and squad 4 is in at 34 s; with one squad-3 seat 1.5 m different, a squad-1 tank is the
yielder, steps 20 m INTO the lane, and squad 4 never arrives in 90 s. To read after the verdict: is that 20 m pick one of YIELD_SPOTS'
ahead lead-outs (10/16/24) that M5a's seatstep already refuses for a seated crew? If so, seatstep ON is the lever (re-run the case
with `--traffic-on=seatstep`); if not, the lever is a cap on a give-way's spot distance / an off-lane preference. No light run on
builder0 while R38.8 holds.

**Plan (in order; smallest foundation first):**
1. **M1 (M5 v2):** Bar M5 v2 filed below BEFORE any number. Lab trees on today's main: `lab/manoeuvre-r38-m5` (stream + M5a's
   rule from `lab/manoeuvre-r37-m5` + native's `pair/native-m5` 156d563d9, seatstep OFF) and `lab/manoeuvre-r38-m5on` (seatstep
   ON). Judge v2 (`tests/manoeuvre/m5_judge.py --v2`) written and unit-tested on round 37's rows first. Then the noise-floor arm
   (base on GDScript), the ON check, the series (builder0), the verdict.
2. **M2 (M5b reverse-back):** trace the return drive on the base tree (how often a seated crew that gave way along its own
   heading turns round to go back, how far, against what), from the jam census's seat episodes; spec + native twin request; bar.
3. **M7 (O5 v2):** read orders' O5 code and R37.32; the aside step also reads support_by_fire routes; bar from R37.32's base.
4. **Stretch M3 (S1 v2):** base rate of stalls on main with M2's `unstick_fires` total first.

### Stretch M3 (S1 v2 stall net): BASE RATE COUNTED, NOT BUILT (2026-10-22 ~13:30)

No new runs: round 37's M1 series already printed M2's totals (builder0 native, wedge trace locks/terminus/sumps x 6640-6663, 72
fights; the ON arm 339d3f2e2 = sidestand ON, today's main movement; rows in `~/overnight-manoeuvre/r37/m1/wedge-on/`).
- `stall_net_holds` (ticks a pop would be held, game-wide, both arms count it): 48,875 in 72 fights; unstick fires 2,738.
- v2's target (note step 4: wedged against a hull, net motion < 0.5 m, >= 3 s): **82 episodes in 72 fights (~1.1 a fight), 0
  deaths**; median 6.8 s (max 178 s; 2,885 s in all); locks 35, sumps 26, terminus 21; tanks and artillery mostly.
- In 69 of the 82 ORCA's slow-down acted and 71 ran at under half pace: the hull was NOT at full throttle, so the stall clock
  (which runs only while pressing) mostly isn't the thing holding it (median stall ticks 15.5, 15 with none).
- **Decision: S1 v2 not built** (the note's own rule: no deaths in its target, and the clock it changes is not what holds most of
  these crews). For round 39, if he sees a tank grinding against a friend: trace the 82 long episodes' ORCA slow-down (who it
  yields to, why neither moves), not the stall clock.

### M2 (M5b the reverse-back) TRACED, NOT BUILT (2026-10-22 ~13:00)

Trace: `lab/manoeuvre-r38-m5btrace` 6d43ce7eb (SEAT_RETURN rows in the jam census, measurement only) + c16c4a0b6
(`tests/manoeuvre/seat_return_table.py`); builder0 native, jam census locks/terminus/sumps x 7001-7008 (24 fights an arm), base
(seatstep OFF) and ON (`--traffic-on=seatstep`); rows and tables in `~/overnight-manoeuvre/r38/m2trace/`.
- **Base: 1,166 seated give-ways; the drive back turned the hull > 90 deg in 107 (9 %), reversed in 435 (37 %)**; median 6.3 m
  off the seat when the give-way ended, median path back 2-3 m. By where the spot lay from the nose: ahead 422 (26 turned, 198
  reversed), side 245 (70 turned), behind 344 (10), none 155 (1). ON (seatstep): 1,057, turned 105, reversed 336.
- **72 of the 107 turn-rounds are the scout class** (syn_lancer 22, syn_scout 20, gang_scout 18, scout 10, law_scout 2): their
  turn-in on the facing, which the lead chose to keep (M6 closed, game_design.md). **The rest: 35 in 24 fights** (~1.5 a fight,
  3 % of returns, 267 m of path in all; side 17, ahead 13).
- **The reverse-or-route decision (Manoeuvre.choose) ran for the seat in only 16 of 1,166 returns** (plan captured; 9 route,
  7 reverse among those > 5 m off). A parked crew's order is a `face` (OrderController._apply_move: turns, never drives back), so
  the trip back is the turn-in / the brain's next order, not a move_to drive. R37.10's premise (a crew that led out turns round on
  its wheels) does not hold on today's main: of 422 ahead-spot give-ways, 26 turned round and 198 reversed back.
- **Decision: M5b not built.** A drive-body rule plus native's C++ mirror plus a series for ~1.5 non-scout turn-rounds a fight is
  not worth builder0 time this round; the scout share is his kept turn-in. Native told "no twin needed".
  If he still sees crews turning round after stepping aside, the lever is the `face` order's return (a move back to the seat in
  reverse when off it by > settle radius), not Manoeuvre.choose.

### M7 trace (O5 v1's leftover), builder0 native, stream 53159326e, `--seat-aside=on`, locks/gorge/terminus x 3801-3806 (18 fights)

`make manoeuvre-aside-trace` (rows kept in `~/overnight-manoeuvre/r38/aside1/`). CPU seat give-ways to another element's crew: screen
to screen 200, to hold 105, to support_by_fire 90, to attack 42, to ambush 24, to move 19; hold to hold 72. Of the 90 screen-to-
support_by_fire: every asker's element was still driving to its seat (89/89 not arrived); 59 happened with the screen crew >= 10 m
off its own seat (median 19 m: moving the seat cannot help those); of the 30 at the seat, **29 lay within 10 m of the asking crew's
own straight line to its goal, but only 10 within 10 m of the line O5 tests** (the element centre to the task's `to`, which for
support_by_fire is the ENEMY it fires at, 92 m from the seat at the median) and 12 of the centre-to-slot line. So v2 reads each
travelling member's own line.

### M7 DEV READ: v2 does not move the total; NOT sent to a judged series (2026-10-22 ~12:00)

builder0 native, stream b5775051e (v2) v 53159326e (v1), `make manoeuvre-aside-trace`, locks/gorge/terminus x 3801-3806 (the same 18
fights; rows in `~/overnight-manoeuvre/r38/aside{1,2}/`): CPU screen give-ways **v1 480, v2 483**; screen-to-support_by_fire 90 -> 72
(the part v1 missed does drop); seats moved aside 2,805 -> 2,486, seats left on a way with no clear point within 4 x 5 m 1,074 ->
3,022 (more ways leave fewer clear spots); deaths in seat give-ways 12 -> 17, all deaths 758 -> 801 (n 18, noise). **Why the total
can't move:** 230 of v1's 480 screen give-ways (48 %; v2 50 %) happen with the screen crew >= 10 m OFF its seat (driving to or from
it), which no seat choice reaches. Bar M7's deciding line (screen give-ways <= 50 % of base) needs nearly every SEATED give-way
gone; v2 changed the total by +3. **Decision:** no judged series (builder0 is scarce; a fail by construction is not worth one).
M7 is written up as blocked on the bar's reach, not as judged. **For the orchestrator / round 39:** (1) if the seated half is what
he'd notice, re-file the deciding line as SEATED screen give-ways (seat_m < 10; v1 250 -> v2 241 here, so even that needs a
bigger change); (2) the en-route half is ordinary traffic between elements (screens crossing other elements' routes on their
way), which is traffic's give-way rules, not seat choice. v2 stays OFF (`--seat-aside=v2`) on the stream.

### Bar M7 (O5 v2, `--seat-aside=v2`: CPU screens keep off where other elements' crews actually drive), filed 2026-10-22 before any number

- **Change (my grant, `element_commander.gd`'s screen seat choice):** O5's aside step (unchanged: a CPU screen point within
  ASIDE_CLEAR_M 10 m of a way steps across its approach, 5 m alternating, up to 4) with its WAYS replaced: each other element's
  living member not within 3 m of its slot contributes its line from where it is to its slot (else to the task's destination,
  never to a support_by_fire task's `to`, which is a target). `--seat-aside=v2` (`on` keeps v1). GDScript only (CPU commander;
  native has no twin of it: grep of native/ for seat_aside is empty).
- **Workload (R37.32's, fresh seeds):** `make native seat-yield-census`, arms none v `SY_FLAGS=--seat-aside=v2`, locks / gorge /
  terminus x 3811-3822 (36 fights an arm), builder0, on a green-checked hash, queued behind the M5 v2 series (one judged series).
- **(0) counter:** `seats_aside` > 0 in the arm.
- **DECIDING (R37.32's):** CPU screen give-way episodes summed, arm <= 50 % of base. Screen-to-support_by_fire REPORTED (the part v1
  missed; expect it down).
- **Reported line:** deaths in seat give-ways, arm <= base + 1.645 sqrt(base).
- **Guards (per-fight totals, both sides CPU):** deaths a fight per team each within base +- 1.645 se (se from the base arm's
  per-fight sd, n 36).
- **Pass = (0) + deciding + guards. A pass ships ON** (symmetric: every CPU commander); a fail is written up, no retry for a pass.
- Before the judged read: a dev read (builder0 light, a few fights) that the counter moves and screen-to-support_by_fire drops.

### Bar M5 v2 (`seatstep`: a seated crew steps aside and comes back), filed 2026-10-22 before any number

- **Change: M5a's, unchanged** (Bar M5 as filed in round 37, archive/round37/manoeuvre.md): a SEATED yielder (move_to arrived,
  within SEAT_NEAR_M 10 m of its seat) takes, of the spots legal today, the whole spot nearest its seat that does not lead the asker
  out; a lead-out only when nothing else is legal. Switch `seatstep` in Traffic.DEFAULT_OFF; native mirror = native's
  `pair/native-m5` 156d563d9 (merged into the lab trees, not hand-edited).
- **Why v2 (R37.30):** M5a passed deciding (-8.5 %) and failed two guards that a symmetric redraw can fail without harm: kills
  per team down (every fight count fell: smaller fights, not one-sided) and hull-rest (e) on a hand-set +4.9 line that a laptop
  GDScript re-run reversed (5 flips one way on native, the other way on GDScript).
- **Fresh seeds:** jam census locks/terminus/sumps x **6940-6979** (120 pairs; round 37's 72 gave the deciding line about 60 %
  power at its own -8.5 %, 120 gives about 85 %); hull-rest **6901-6932** x 4 factions x 6 tasks (128 pairs a task), native
  (`native <target>`), builder0.
- **(0) counter first:** `route_arms.yields_seated` > 0 in ON.
- **DECIDING (unchanged):** seat metres summed over seated give-ways, paired by (arena, seed): ON < base by more than 1.645 se of
  the paired sum. Lead-out / back / episode counts REPORTED.
- **Guards, unchanged:** the asker's wait (ticks) and give-way timeouts, friendly contacts, jam deaths, deaths per team: each not
  above base + 1.645 se. Hull-rest (f) squads arrived per task: not below base - 1.645 se.
- **Guard (a), NEW: fight volume is not a harm; who wins it is.** Replaces "kills per team within 1.645 se". (a1) team 0's KILL
  SHARE, K0 / (K0 + K1) summed over the series, within +-1.645 se of base, se from the paired linearisation (per pair
  z = (k0 - R k)/K for each arm, se of the paired sum of z_on - z_base). (a2) TOTAL deaths, both teams, not above base + 1.645 se.
  Total kills REPORTED (a smaller fight is allowed).
- **Guard (e), NEW: never-settled sized by its own noise floor, measured first.** Before the ON arm is read, run the BASE tree's
  hull-rest on the GDScript path (`M1_GD=1` = `--brains-off=native`, the same seeds, the same native-built folder) beside the base native arm. Per
  task, D_floor = runs whose settled/never-settled differs between the two base paths (a no-rule redraw). The ON line per task:
  never-settled ON - base <= 1.645 x sqrt(max(b + c, D_floor, 1)), where b + c = the runs discordant between ON and base (native).
  sqrt(discordant) is the sd of a net shift when each discordant run is a coin flip; D_floor stops a one-sided handful from failing
  a rule whose task redraws that many runs anyway, and b + c keeps the line honest if the floor is small. D_floor per task and the
  net shift base GDScript - base native are REPORTED with the verdict.
- **Pass = (0) + deciding + every guard. A pass ships ON** (symmetric; C37.7). No re-run to look for a pass; a fail is written up.
