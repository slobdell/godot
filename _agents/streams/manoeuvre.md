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

**Plan (in order; smallest foundation first):**
1. **M1 (M5 v2):** Bar M5 v2 filed below BEFORE any number. Lab trees on today's main: `lab/manoeuvre-r38-m5` (stream + M5a's
   rule from `lab/manoeuvre-r37-m5` + native's `pair/native-m5` 156d563d9, seatstep OFF) and `lab/manoeuvre-r38-m5on` (seatstep
   ON). Judge v2 (`tests/manoeuvre/m5_judge.py --v2`) written and unit-tested on round 37's rows first. Then the noise-floor arm
   (base on GDScript), the ON check, the series (builder0), the verdict.
2. **M2 (M5b reverse-back):** trace the return drive on the base tree (how often a seated crew that gave way along its own
   heading turns round to go back, how far, against what), from the jam census's seat episodes; spec + native twin request; bar.
3. **M7 (O5 v2):** read orders' O5 code and R37.32; the aside step also reads support_by_fire routes; bar from R37.32's base.
4. **Stretch M3 (S1 v2):** base rate of stalls on main with M2's `unstick_fires` total first.

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
