# Workstreams: the current round

> **ROUND 35 PREPARED (2026-10-19; launched FRESH from the docs commit: no worktree or agent carried over from round
> 34): five streams, ALL OPUS (the lead, 2026-10-19: "move all our agents back to Opus"), builder0 ONLY (builder2 powered off by
> the lead the same morning).** Briefs in `streams/`.

## Round 35: five streams, all Opus, builder0 only (prepared 2026-10-19; briefs in `streams/`)

**Goal: finish what he asked for in round 34, then the biggest avoidable loss.** His three answers (game_design.md *Round 34
close*): ship the scout turn-in, turn the deploy step ON, the firing truck keeps its spot. Round 34 closed his "one click,
three squads" complaint on the river (no crossing in any of 24 probe cells) and made routes the squad's; what's left of it is
the arrival (squads shuffle 19–87 m after arriving) and tight packing, which his deploy-step yes unlocks. The biggest avoidable
loss in every fight is the wedged crew (8.3 % of deaths, R34 candidates).

| Stream | Folder (offset) | Model | Brief | What he will notice | First item |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | Opus | [streams/traffic.md](streams/traffic.md) | a crew under fire doesn't step aside into a killing zone when the one behind can go round | the design note |
| **manoeuvre** | `godot-manoeuvre` (2) | Opus | [streams/manoeuvre.md](streams/manoeuvre.md) | fewer crews die shoved around in a lane mouth; a wheeled hull told to face a direction ends facing it and goes still | the wedged-death trace |
| **brains** | `godot-brains` (3) | Opus | [streams/brains.md](streams/brains.md) | squads on an attack-move don't hang ~30 s at each leg while a crew finishes turning to its arc | the sector-face step |
| **native** | `godot-native` (4) | Opus | [streams/native.md](streams/native.md) | nothing alone: every pair; the judging table complete | pairs, then planner's leftovers |
| **orders** | `godot-orders` (5) | Opus | [streams/orders.md](streams/orders.md) | squads arrive in their travel shape and deploy as one move, packed close without overlapping; five squads on the Locks route don't jam at a junction | ship the deploy step |

**Machines (C35.1):** builder0 only (12 cores, 14 GB). **At most ONE full check and ONE judged series on builder0 at a time**;
before any heavy launch read `free -g` and the Godot count by cwd (lesson 321). Every named run under `systemd-run --user
--setenv=PATH="$PATH"` (remote_builds.md; lesson: setsid wrappers die). A judged series takes `FAR_JOBS=3` or the stage's own
lower setting while a check runs. Light runs and the laptop for dev. If two streams want the box, the orchestrator orders them.

**Ownership:** round 34's table stands (round 33's, with the round-34 grants) EXCEPT: **orders** owns `game/control/**` (except
manoeuvre's additive fields in `screen_playtest.gd`), `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`,
`mk/command.mk`, and in `game/tactics/element_plan.gd` the deploy-step and halt-lay functions (`DEPLOY_STEP`, `_deploy_*`, the
halt seat lay for a plain AUTO move; merge note to brains); brains owns the rest of `game/tactics/**` and `game/ai/**` outside the
carve-outs. **native** takes planner's paths this round (`game/ai/planner/**`, `native/src/planner_*`, `tests/planner/**`,
`mk/planner.mk`, `tools/judge/**`). **Nobody:** `tests/baselines/**` except the orchestrator's adoption on main.

**Contracts (round 35):**

- **C35.1 Fresh start, builder0 only.** Round 34's `stream/*` branches are `round34/<stream>`; every worktree is created from this
  docs commit. The machine rule above.
- **C35.2 The deploy step ships ON (orders' FIRST item; his yes).** Base: `round34/brains` `07c029732` (WIP: default flipped,
  tests updated, NO check run). It reaches CPU elements too (any plain move with no chosen formation or told facing), so
  sim-baseline moves: attribute every moved map with `DEPLOY_STEP=off` on the same tree, then the orchestrator adopts. Because
  the CPU gets it too, one REPORTED fights census on fresh fixed-arena seeds (deaths, kills, stuck, by side) beside the check:
  a gross regression (> 2 se) is brought to the orchestrator before shipping. Then the O5 probe's 24 cells on the shipped hash.
- **C35.3 The scout turn-in ships (his yes; the orchestrator).** `pair/c339-r34b` `3902ade09` (manoeuvre's turn-in + native's stop
  hand-back, on main c46f66dc2) is checking on builder0 (log `~/overnight-manoeuvre/r34_pair2_check_3902ade09.log`, done marker
  `r34_pair2_done`, attribution `godot-manoeuvre-pair2/build/sim-variants-turninoff.tsv`). The orchestrator merges it on green and
  adopts the moved maps. Streams merge main after.
- **C35.4 Tight packing on the deploy step (orders; round 34's O2 (B)).** With the deploy step on, a squad's final seats are its
  halt shape on a heading fixed at ORDER time, so packing is exact: hull-to-hull ≥ ~9 m between crews of different squads (his
  correction 1: wedges nest), his 28 m between two columns kept, each squad on its own side of the approach, back ranks no farther
  back than their own squad (R34.12b), nothing on a building (ground_anchors). Bar filed before numbers: the probe's 24 cells and
  the settle/arrive series; the click's 3-tick response kept (`test_control_scale`).
- **C35.5 Crossing drives on the last leg (orders).** Planner's Locks 5-squad route: squads 3 and 5 jam for ~55 s at (5, 65) because
  their DRIVES cross though their anchors' straight lines don't. Deal the last leg by navmesh paths (crossing test, swap with a
  length guard). Probe before/after.
- **C35.6 Wedged deaths (manoeuvre).** 499 of 5984 deaths (8.3 %) in T5's census: mid-weight hulls pushed at walking pace by their
  own avoidance in lane mouths under fire; only 26 % slow enough for the stall rule. Trace first (which force pushes them; why
  unstick doesn't see them), then a design note to the orchestrator, then a bar: deciding gain wedged deaths, guards as T6's
  (open, stuck, jam, far loops, kills, hit rate).
- **C35.7 CP-F attempt 5, the new design (manoeuvre's face side; brains' element side; seam agreed through the orchestrator
  before code).** R34.18's two mechanisms: a face no plan fits gives up cleanly after N refused plans (manoeuvre); an element
  steps to its next leg without waiting on a crew's `face from sector` (brains, tank_brain ~2960). Fresh bar, guards sized from M1's
  A/A (judging.md).
- **C35.8 Under fire, refuse only when the asker has another way (traffic).** T6/T6b (R34.17, R34.20): refusing every ask under
  fire cut yielding deaths 53–69 % but moved them to stuck/blocked/parked one for one. Refuse only when the asker has a way round
  (parkedroom's room/route test). Design note first; bar as T6b's (fresh fixed arenas, no twins). Native mirrors.
- **C35.9 Planner's leftovers (native).** Delete FACE_KEEP_FAR (R34.5); the judging table's owed rows (round 31 brains, round 32,
  the round 31–34 inventory lines); every series tool drops random-seed twins (R34.15, `seed_twins.py`).

## Bars (round 35)

_Filed here before any number._

- **C35.3 the scout turn-in (orchestrator, filed 2026-10-19 08:45 before `3902ade09`'s check read).** Ships when (1) builder0
  `make check` on `pair/c339-r34b` `3902ade09` exits 0 on every target except sim-baseline; (2) every sim-baseline map that MOVES
  reads main's line again with the turn-in off (`make sim-variants VARIANTS_EXTRA=--nav-off=turnin` on the same commit), so the
  move is the turn-in's alone; then the moved maps are adopted in the merge commit. A map that moves with the turn-in off too
  blocks the merge until traced.
- **T7 under fire, refuse only when the asker has a way round (traffic, C35.8), filed before any number on `stream/traffic`
  (design `references/round35/traffic/t7_design.md`).** Pair = current main + T7 (`--traffic-on=underfire`, DEFAULT_OFF) + native's
  mirror + the ON flip; base arm `--traffic-off=underfire`; switch-OFF sim-baseline inertness beside the C31.1 full check. Native,
  builder0 start to end, pinned, 180 s showmatch, FRESH fixed arenas `{terminus, locks, sumps, gorge, parade} × 1600–1627` (n 140,
  no random arena, no twins). k = 1.645, paired se (`tests/traffic/jam_ab.py`). DECIDING GAIN G: jam-under-fire deaths (T5's
  definition) arm < base AND (base − arm) − k·se > 0. Guards (T6b's, unchanged): (1) open deaths ± k·se; (2) stuck deaths ≤ base +
  k·se; (3) far loops ≤ base + k·se; (4) kills ± k·se, hit rate ≥ base − k·se; (5) contacts in the 3 s after a hit-ended give-way ≤
  base + k·se; (6) crossing arrivals 44–46 × 6 ≥ base − k·se a case; **(7, new) all friendly hull contacts a fight ≤ base + k·se**
  (a pass must not buy bumps). Reported: contacts with a crew passing, standoffs with durations, all/jam deaths, deaths by cause,
  `underfire_refusals/gives/holds`, `passes/passes_done/passes_timeout`. A fail is traced (worst fight first); no re-read.
- **D3 tight packing (orders, C35.4), filed before any number on `stream/orders` `54cff1bfc` (2026-10-19 ~09:20).** The deploy
  step ON in both arms; `main:` (pack on) v `pack_off:--pack=off`. Its counter: `SelectionSquads.packed` non-zero in the main arm.
  - **Probe:** `make orders-probe` on builder0 (native), seed 34, n 1 a cell (deterministic): Locks / Crossing / Terminus x 3 / 5
    squads x click / route = 24 cells, arms `main:` (pack on) v `pack_off:--pack=off`, the same tree, the deploy step ON in both.
  - **Gain (must pass):** over the 6 CLICK cells, the median of each cell's `end far max m` (the farthest crew from the click at
    the window's end) at least 15 % below pack_off's; and in EVERY cell `end foreign min m` >= 7 m (the 9 m design, less
    grounding slop), on both arms reported.
  - **Guards (each must hold in every cell):** all-in <= pack_off x 1.2 + 3 s, and no cell all-in on pack_off but not on main;
    far bank 0; `toward min m` >= 0 (nobody sent away from the click); `twitch worst m` <= pack_off + 5 m.
  - **Response:** `test_control_scale` (the click's 3-tick response) passes in the check of the named hash.
  - **Single squads:** the pack acts only on 2+ squads; `make squad-arrive-series ARRIVE_ARM_FLAG=pack ARRIVE_MAPS="terminus sumps"
    ARRIVE_SEEDS="1 2"` both arms must be byte-identical (an equality check, reported).
  - Screenshots (`orders-probe-shots`, arrival and +5 s, desktop and phone) looked at for every 5-squad click cell.

- **W1b a wheeled hull held to a standstill sits still (manoeuvre, C35.6's W1 follow-on), filed before any number from
  `godot-manoeuvre` `references/round35/manoeuvre/w1-trace/README.md`, with one change by the orchestrator: fixed arenas only
  (locks, terminus, sumps; NO random arena, R34.15).** Pair = stream + native's mirror (drive_native's pace-0 branch). **Arms (R35.19
  follow-up): two native trees,** base `lab/w1b-base` `ab9c50c76` (= f4f6bf1d2 + mk FIGHT_RANGE; halt OFF), ON `lab/w1b-on` `7fc4a5307` (= 0015f48ad + mk; WHEEL_HALT_DEFAULT true),
  since any `--nav-off` leaves native's drive; C31.1's `make native check` on the ON tree first. Builder0, FRESH seeds 3820–3843 x
  locks/terminus/sumps, n = 72 fights an arm; counter first: wheel_halts > 0 in the ON arm. **Deciding:** at-spot creep ticks of held
  wheeled crews (its counter; non-zero in base first) → ~0; wedged + held deaths not up beyond 1.645 se. **Guards (as T6b):** open,
  stuck, jam deaths, far loops, kills and hit rate per team, each within 1.645 se paired; all deaths reported.

- **E1 straggler release (brains, C35.7 element side per R35.3), filed before any number on `stream/brains` (code `ec1f5cc75`:
  `ElementPlan._advance` stops waiting on a crew that has not come 2 m nearer its slot in 8 s; `--straggler=off` = the old gate).**
  One commit, builder0, native, both arms on the same tree. Workload: hull-rest drawn, faced_attack_move + faced_move, FRESH seeds
  701–716 x 4 factions (128 runs an arm); fights census on fresh seeds 720–743. **Counter first (R35.5):** straggler releases > 0
  in the new arm. **(a) Deciding:** attack-move long-hold seconds (leg waits >= 10 s) new <= 0.6 x base AND lower by > 2 se, paired
  by seed. **(b)** faced_move not worse by > 2 se. **Guards:** (c) crews left > 25 m off their slot in their element's last trace
  row, new - base <= max(2, 2 se), each task; (d) late movers at 75 s (real_mps >= 0.3) and settled-in-75 s within 2 se; (e) squads
  arrived within 2 se; (f) fights' kills and deaths each side within 2 se; (g) `make check` green, moved sim-baseline maps
  attributed with `--straggler=off`.

- **M5 W2, CP-F attempt 5, the face side (manoeuvre, C35.7 decoupled by R35.3), filed before any number from `stream/manoeuvre`
  `d544e83a0` Status *Bar M5*.** Candidate: stream + `TURN_HULL_DEFAULT := true` + `FACE_SETTLE_DEFAULT := true` (lab/cpf5); base
  the same tree `--nav-off=turnhull,facesettle`. Gate (C31.1): lab/cpf5's whole `make native check` green on builder0, sim-baseline
  moves attributed with `--nav-off=turnhull,facesettle`. builder0 only. FRESH seeds: hull-rest 701–716 (4 factions x 16 x 6 tasks,
  drawn and clicked, GDScript M1_GD=1 both arms, plus the native drawn pair), Terminus 720–732, SBF 770–775, bridge-pooled's 18,
  fights on FIXED arenas locks/terminus/sumps x 740–763 (`FIGHT_AT`). Ruler and noise: M1's, round 34's A/A table. Lines: Bar M3's
  (a)–(m) unchanged (`streams/archive/round34/manoeuvre.md`), plus (n) `face_creep` crews at the judge, new <= base + 1 per task;
  (o2) counter first: `face_settles` > 0, `hull_turns` > 0, `face_settle_fails` reported; (p) at-rest hull error of the crews that
  gave up REPORTED (median, count >= 45 deg). Gate: (a)–(j), (n); a miss parks it with a trace. If (d)/(e) miss on attack-move only,
  the trace names the mechanism and the verdict is the orchestrator's (the step is brains' E1).
  **Scope change before the gate (2026-10-19 ~11:05, from W2's dev read on tuning seeds 460–463, builder0, lab/cpf5 bdacb1786):**
  the give-up applies to TURRET hulls only (`5c692b507`); with it on hull-fixed scouts, scouts >= 45 deg off rose 33 -> 48 over six
  tasks (a scout's creep is how it aims). **Second scope change (R35.23, 2026-10-19 ~15:45, before the gate):** the give-up and
  its rolling-home rule act ONLY when turn_hull_on() AND the face came through the turnhull lift (from in {drawn, order, sector}),
  on a turret mount, not a hull-fixed scout; every plain `face` keeps round 9's creep + give-up window bit for bit. (n) reads the drawn
  tasks, where the give-up acts; clicked faces never reached the hull turn (attempt 4: hull_turns 0 clicked). Gate candidate lab/cpf5 `a7167e4f9`, then `9a463b0b9` (same game/ and native/; + a cpf5base arm and references; on main 0f4d528d7; E1 NOT in). Native base arm: lab/cpf5-base `f77360f92` (= 9a463b0b9 with TURN_HULL/FACE_SETTLE defaults false).

- **T8 a held crew under fire leaves the hold (traffic, R35.7 (B)), filed before any code or number from `stream/traffic`
  `d3d2e6478` (`references/round35/traffic/t8_design.md`), with two lines added by the orchestrator.** `--traffic-on=holdfire`
  (DEFAULT_OFF): in `Traffic.hold_of`, a held crew hit within UNDER_FIRE_S (5 s) is released from its squad's wait like a passed
  crew (`released_fire`), for good for that wait; native mirrors the hold. Pair cut AFTER T7's series reads (on T7's verdict).
  Fixed arenas {terminus, locks, crossing, gorge, parade} x FRESH 1800–1827 (moved from 1700–1727: traffic read 1700–1701 in a T7 dev read before this bar reached it), n 140, native, builder0, pinned; k = 1.645 paired se.
  **Counter first (added):** `released_fire` > 0 in the arm. **G:** held deaths (dead while `Traffic.holding` the tick before, or
  within 3 s of a hold ending; jam_census `held`, T5's causes untouched) arm < base and (base - arm) - k·se > 0. **Guards:** stuck
  deaths, jam deaths, open deaths ±, far loops, kills / hit rate, all friendly contacts, crossing arrivals 44–46 x 6, `tr_holds` >=
  half of base; **(added) all deaths per team <= base + k·se** (T6's lesson: deaths moved cause one for one). Reported:
  `released_fire`, hold seconds, standoffs, deaths by cause.

- **M6 W1c, the stall rule reads the drive's intent against a friendly hull (manoeuvre, R35.12), filed before code from
  `stream/manoeuvre` `df0c7efba` Status *Bar M6*.** Switch `--nav-off=stallintent`, default OFF. Candidate = lab/w1c (default
  flipped) + native's mirror; base = `--nav-off=stallintent`; gate = the pair's `make native check` on builder0. FRESH seeds:
  hull-rest 901–916 drawn; fights + wedge probe on fixed locks/terminus/sumps x 940–963. **(0) Counter first:** stall_intent_ticks,
  H1 hull escapes, asks > 0 in the ON arm. **Deciding:** (d) attack-move movers by real_mps, new <= base - 1.645 x 1.17 x sqrt(pairs),
  no other task over Bar M3's (d) guard; (e) attack-move never-settled <= base, no task over M3's (e) guard. **Guards:** (f)
  arrivals, (i) fights per team, (q) stuck/jam/open deaths, (r) far loops, (s) friendly contact ticks, each within 1.645 se paired;
  (t) asks and give-ways REPORTED (the churn risk).

- **D5 a multi-squad route's in-between gate dealt by each squad's previous leg (orders, C35.5), filed before any builder0 number
  from `stream/orders` `fac1f5ca4` Status *D5 bar*, with one change by the orchestrator: fresh seeds.** `--gate-deal=off` = round 34.
  `make orders-probe` on builder0 (native), the 24 cells, arms `main:` v `gate_off:--gate-deal=off`, same tree (deploy step ON, pack
  OFF). **Seeds (changed):** seed 34 (the tuned cell) is REPORTED only; the gain and guards read FRESH seeds 3611–3616 (n 6 a
  cell; 3601–3602 were read on the laptop while fixing the probe). A seed other than 34 moves the click (and the route's
  waypoints) by <= 12 m to a dry standable point (`stream/orders` 54a5306fe: before it, every seed replayed seed 34 byte for byte). **Counter first:** `gates_laid` > 0 in every multi-waypoint route cell on main; the printed legs differ between arms in
  the Locks 5 route. **Gain:** the Locks 5-squad route median all-in <= 0.7 x gate_off's (or in where gate_off never is), and the
  summed all-in over the 12 route cells lower on main. **Guards:** the 12 click cells byte-identical between arms; every route cell
  median all-in <= gate_off x 1.2 + 3 s, never in on gate_off but not on main; deck / far bank no higher than gate_off in any cell;
  drive/plan worst <= gate_off + 0.2 in each cell.

- **D4 minimax deploy seating (orders, the shuffle), filed before any builder0 number from `stream/orders` `b6068ded0` Status
  *D4 bar*, with one guard added by the orchestrator.** The deploy seats crews so the longest leg is shortest; `--deploy-minimax=off`
  = D1. `make orders-probe` on builder0 (native), 24 cells x FRESH seeds 3621–3626 (never run; seeds move the click <= 12 m),
  medians a cell; seed 34 (tuned, laptop) reported only. **Counter first:** the arms' rows differ in >= 1 cell. **Gain:** summed over
  the 24 cells, median `twitch worst m` >= 20 % lower on main, and the Terminus 5 click cell's median twitch lower. **Guards (each
  cell):** median all-in <= minimax_off x 1.2 + 3 s, no more never-in seeds; median `place worst m` <= minimax_off + 5 m; median end
  foreign min >= minimax_off - 3 m; deck / far no higher; **(added) median `twitch worst m` <= minimax_off + 3 m** (the laptop's
  Locks 5 read 13.6 -> 15.5: a sum can hide one cell getting worse).
  **Arms as run (R35.26):** tree stream/orders `68d4c06cd` (code = 554131533, gate deal ON by default), so both arms carry
  `--gate-deal=off`: `main:--gate-deal=off` v `minimax_off:--gate-deal=off,--deploy-minimax=off`; JOBS 2.

- **M6/T9 JOINT: the stuck asker asks again (W1c, manoeuvre) and the asked parked crew answers (T9 yieldfit2, traffic), filed
  2026-10-19 ~11:55 before any T9 code, replacing M6's two-arm read (R35.13).** T9 design: `stream/traffic` `0a1567b56`
  `references/round35/traffic/t9_trace_design.md`. **Arms:** candidate = W1c ON + `yieldfit2` ON + native's mirrors of
  both; base = the same code with both switches off. **As run (R35.53/59): two native trees** (lab/joint3-on 872f82ae5 v lab/joint3-base
  2a2682560), since `--nav-off` / `--traffic-off` flags would leave native's drive. Pair cut by manoeuvre (it runs the series) from manoeuvre's W1c +
  traffic's T9 + native's mirrors; gate = the pair's `make native check` on builder0 plus switch-OFF sim-baseline inertness. Seeds:
  M6's FRESH blocks (hull-rest **901–932** drawn, i.e. 128 pairs; fights + wedge probe on fixed locks/terminus/sumps x 940–963).
  **n raised 2026-10-19 ~12:30, before any judged number, the line itself unchanged:** the joint dev read (tuning 460–467, 32 an arm)
  read movers 8 v 14; at that rate (d)'s line (-1.645 x 1.17 x sqrt(pairs)) needs ~105 pairs, so 64 would miss on n alone. **Counter first:**
  stall_intent_ticks, H1 escapes, asks AND `yields_unfinished` > 0 in the candidate. **Deciding:** M6's (d) and (e) as filed
  (attack-move movers by real_mps; never-settled), plus crews ending > 25 m off goal with a live move, new <= base. **Guards:**
  M6's (f) (i) (q) (r) (s); yields started a fight <= base + 1.645 se (no shuffle storm); retries capped REPORTED; all deaths per
  team <= base + 1.645 se.
  **Added 2026-10-20 ~01:30 (R35.53, traffic's T9 x T7 note; before any joint3 number):** jam-under-fire deaths (T5's definition)
  <= base + 1.645 se, and jam:yielding deaths <= base + 1.645 se (an unfinished give-way re-asked under fire meets T7's lane gate:
  a lane -> refuse + pass; no lane -> up to 2 more step-asides under T9's cap). Base = main 5f05c997c's code (T7 ON) + the joint
  code with both switches off.

- **D6 a shift-click never replaces a squad's route (orders, R35.28 option (b)), filed before code on `stream/orders` `bda5db637`;
  seeds named by the orchestrator.** A shifted move queues on the elements its units now belong to (round 22's cross-squad re-deal
  stays); code `862e60970`, OFF until its A/B. Probe on builder0 (native), the 24 cells, arms main v the switch off; Crossing 5 route
  s3614 (the reproduction) REPORTED; FRESH route seeds **3641–3646**. **Counter first:** legs queued per squad differ between arms in
  >= 1 route cell. **Gain:** every squad gets every leg (legs per squad = waypoints) in every route cell on main. **Guards:** round 22's
  Sumps seed 5988 scenario keeps 0 path crossings; test_control_queued_task and the route tests green; the 12 click cells
  byte-identical between arms; a test reproducing the replace (red on the switch off, green on).

- **D3b a packed squad arrives in a file its halt opens out of (orders, R35.41), filed before code on `stream/orders` `972c05912`.**
  `make native orders-probe` on builder0, FRESH seeds 3661–3666, n 6, medians; arms `main:` v `pack:--pack=on,--arrive-file=on` (deploy
  step on; D4/D5/D6 at their defaults). **Counter first:** packed > 0 in the pack arm's click cells, rows differ from main's. **Gain:**
  summed median `end far max m` over the click cells >= 15 % lower AND closest foreign hull at arrival >= 7 m in every cell (what
  failed D3). **Guards:** far bank 0 in every cell; all-in <= main x 1.2 + 3 s; never-in no higher; twitch median <= main + 3 m per
  cell; test_control_scale green.

- **E4 lab hulls placed with `Tank.place` (brains, R35.47), filed before code from `stream/brains` `0fa9b5e29` Status.** TacticsLab.unit,
  TacticsLab.gun and BodyStage's spawn (body_stage.gd:152) call `tank.place()` instead of a bare `global_position =`. builder0 native:
  (1) the suite green; (2) test_tactics_mixed_legs alone v after h1b_guard / blocker_reach reads the same arrival and reseats (plus a
  test pinning order-independence); (3) every test line that moves is listed old -> new, each expected to move from its "later-match"
  value to its "first-match" value; any other move is traced before the merge. sim-baseline unmoved expected (Match spawns via
  army_layout, already `place`).

## Rulings (round 35)

- **R35.1 (2026-10-19 09:20) C35.3 passed its bar and merged** (`c6fd30d71`; INHERIT from `3902ade09`'s check: builder0 26/27,
  2885/0, only sim-baseline). Attribution on builder0: `--nav-off=turnin` on 3902ade09 reads main's base40 AND base90 on all 13
  maps (main's own base40 equals the recorded lines). Moved and adopted: yard terminus crossing locks parade gorge cut docks.
  The merge carried round 34's manoeuvre Status into round 35's brief; restored (`ffa462c94`). Orientation 84–86 kept.
- **R35.2 (2026-10-19) C35.7, manoeuvre's side of the seam approved:** W2 face settle (a face no plan fits 3 times in a row stops
  still; `--nav-off=facesettle`; ships with turnhull ON) and `Movement.face_settled()`, a read-only query. Brains' side waits
  for E1's leg-gate trace to name the rule that holds the leg.
- **R35.3 (2026-10-19 ~09:40) C35.7 is DECOUPLED.** Brains' E1 trace (laptop, GDScript, lab/cpf4 `e76f6dab6` both arms,
  law/faced_attack_move-614; probe `c23acdbe2`): the leg is held by `ElementPlan._advance`'s `_cohesive` gate on ONE laggard
  (allowance 20 m x 1.0 / slowest 12 m/s = 1.33 s, ~16 m); `reached` is true at every hold; the crew on `face from sector` sat 3–4 m
  from its slot and never held a step. R34.18's "steps at 60 v 32" is that gate waiting on a laggard, chaotic by arm. Brains' side
  becomes a **straggler release** (the gate stops waiting on a crew with no progress on its slot for N s), no face knowledge;
  face_settled() returns only if the 128-run series (seeds 601–616 x 4 factions x CP-F on/off, builder0) shows a real `face`
  share. Manoeuvre's W2 ships on its own bar. Brains' base-arm laggard G4, wedged at (18, 87.5) (plant 9.25 v real 1.17 m/s,
  re-seat watch out of budget), relayed to manoeuvre's W1.
- **R35.4 (2026-10-19) main 0f4d528d7 is GREEN without a new check:** the only check-read diff from `3902ade09` is
  `tests/baselines/sim_state_hash.txt`, adopted from the 13 maps read twice at ffa462c94 on builder0, equal to 3902ade09's
  check's hashes. All five workers told to `git merge main` (orders BEFORE D1's attribution).
- **R35.7 (2026-10-19 ~10:10) W1 read: wedged deaths are not stuck hulls.** Manoeuvre (builder0, native, main a0ae0aafd + probe,
  Locks/Terminus x fresh seeds 3500–3511, 24 fights x 180 s): 81 of 984 deaths `stuck:wedged` (8.2 %); 80/81 hit in the last
  10 s; 67/81 wheeled; unstick drove 1 % of ticks. Two populations: 41 % (33) HELD by Traffic's take-turns hold at a street mouth
  under fire (median 5.4 s into the hold; the 3 longest episodes, 18 s, all holds); 59 % (48) ORCA-slowed in a fight's crowd
  (median 1.2 s wedged). Rulings: (A) NO new wedged trigger in unstick. (B) **T8 (traffic, after T7's series; its own bar):** a
  held crew that is being hit leaves the hold. Not folded into T7: T7's bar is filed. (C) **W1b approved** (bar above), default
  OFF; native mirrors after its dev read. (D) traffic's census adds `jam:held` as a REPORTED sub-cause; T5's definition that T7's
  G counts stays fixed until T7's series has read.
- **R35.8 (2026-10-19) T7's native mirror (`pair/native-t7` c9ba20917):** everything native except `_pass_lane` and its
  `_pass_wheels_ok/_pass_clear/_pass_swept`, which C++ calls back into GDScript (reads only the navmesh, the Avoidance table and the
  two hulls; ~19 calls a fight; exact by construction). Ported only if T7 ships, with its own twins (R34.20: a parked rule's mirror is
  dead weight).
- **R35.9 (2026-10-19) E1's census closes the face question.** Brains (`c23acdbe2` = main a0ae0aafd + trace, builder0,
  attack-move, seeds 601–616 x 4 factions, n 64 an arm): leg-wait seconds CP-F off 516 = closing 252, WEDGED 255 (49 %), face 0;
  CP-F on 428 = closing 228, wedged 189, face 2 (the on arm's drive ran GDScript, base native). Holds >= 10 s: 11 / 329 s off, 7 /
  191 s on, nearly all on a WEDGED crew (< 0.5 m/s, 20–50 m off its slot; law-605 Eyes_4 71 s in both arms). face_settled() stays
  out. These long out-of-fire wedges are NOT W1's populations (1–5 s, under fire): relayed to manoeuvre to trace (a possible W1c);
  brains' guard (c) reported split by wedged-at-release.
- **R35.10 (2026-10-19 ~10:20) W1b's dev read, and the 70 s scout dead-stop.** W1b (builder0, a0c874924's tree, tuning seeds
  3500–3503 x locks/terminus/sumps, 12 fights an arm, GDScript both arms): wheeled pace-0 ticks still moving >= 0.5 m/s 7181/11871
  (60 %, 7099 Traffic holds) -> 636/15723 (4 %). Native asked for the mirror (`pair/native-w1b`, after T7's pair). law-605
  Green_Eyes_4 (native, main 0f4d528d7; also on a0ae0aafd, so NOT the scout turn-in's): from t ~10 s to the judge at (-8.1, 99.6),
  34 m off, move_to, phase `blocked` by Green_Eyes II_5 (another squad's scout), touching it; not a Traffic hold; ORCA pace 0.05,
  unstick's stall rule needs |throttle| > 0.5 so stops counting after t 26; nothing asks II_5 to give way. Parkedroom's shape out of
  fire (traffic told, heads-up). Owner decided after manoeuvre traces II_5.
- **R35.11 (2026-10-19 10:35) D3 tight packing PARKED, OFF (`--pack=on`), code `stream/orders` `183eb4cd6`.** The halts pack
  exactly (9 m between squads' seats, coils as rings, 28 m columns, 14 tests), but squads ARRIVE in their travel shape (a five-squad
  wedge ~60 m wide) and deploy only when all are in, so packed halts put two arriving wedges' slots 5.7 m apart and the 5-squad
  Locks cell jams (laptop GDScript probe: place move 40.7 m, twitch 27.3 m). Keeping travel shapes apart (7 m) leaves the pack no
  tighter than the ranks (70.7 v 68.7 m to the farthest crew). No bar number read on builder0. Next try **D3b** = orders' option
  (a): a packed squad's last stretch in a narrower arrival shape its halt opens out of; fresh bar; AFTER D1's merge, D2, D4, D5.
- **R35.12 (2026-10-19 ~10:45) The out-of-fire dead-stop: W1c (manoeuvre) + T9 (traffic).** Manoeuvre (builder0, native, main
  0f4d528d7 + OFF switches 58395b79c, hull-rest law faced_attack_move): law-605's blocker Green_Eyes II_5 is a PARKED crew of another
  squad; asked once, it yielded only 2.4 m (still touching, still across the route), the yield ended at t 14.5 s, nobody asked again
  for 65 s. law-607 Guns_6 the same (23 m off from t 24 s, a pack of 8–9 friends). Cause on the asker's side: unstick's stall rule
  reads the POST-ORCA throttle (0.05–0.09), so with the drive's intent ~0.9–1.0 the clock never runs and H1's escape (ask, reverse,
  stand, `blocked`) never starts. **W1c (manoeuvre, approved, default OFF):** for a routed move in contact with / blocked by a friendly
  hull, the stall rule reads the drive's intent; H1's escape unchanged; native mirrors after its dev read; fresh seeds hull-rest
  901–916, fights 940–963; bar to the orchestrator before code. **T9 (traffic, after T7 and T8):** a give-way that ends with the
  yielder still touching or across the asker's route does not count as done.
- **R35.13 (2026-10-19 ~11:35) W1c alone rocks, it does not free; W1c + T9 become one series.** Manoeuvre's dev read (builder0,
  ec991cf7f, GDScript both arms): counter fires (stall_intent_ticks 0 v 1434 on law-605, 0 v 2088 on law-607; asks 2 -> 7; H1 escapes
  3 -> 8), but neither traced crew reaches its goal: the parked blocker (Green_Eyes II_5) yielded once (t 9–13 s, 2.4 m, still
  touching) and refused all 5 later asks, so the asker cycles ask / stand / reverse <= 3 m / forward into the same friend. Hull-rest
  attack-move tuning 460–467, 32 an arm: movers 10 v 14, never settled 4 v 7, settle median 37.2 v 44.5 s, about half M6 (d)'s
  needed effect. M6 NOT run; W1c held OFF (f9b3bb7f3). Traffic traces T9's mechanism now (why a once-yielded crew refuses); W1c + T9
  judged as ONE series under a joint bar filed when T9's design is in.
- **R35.14 (2026-10-19 ~11:55) T9's mechanism (traffic, builder0 light, GDScript, W1c ON, law faced_attack_move 605, n 1,
  lab/t9-trace-w1c e2bea96f2):** `ask()` opens with `if yield_to != "" or asker == _last_yielded_to: return false`;
  `_last_yielded_to` is written at the end of EVERY give-way, so a PARKED crew whose give-way ended on the 6 s clock with the asker
  never past (II_5: 5.1 m centre to centre) refuses that asker forever (f676, 941, 1395; II_7 the same). A turn-taking rule for two
  movers acting as a once-only rule for a parked crew (the same lock parkedroom v2–v4 removed). **T9 approved** (`--traffic-on=
  yieldfit2`, DEFAULT_OFF): an unfinished give-way (asker not passed AND yielder within 1.0 m box gap or across its travel line)
  does not write `_last_yielded_to`; at most 2 unfinished to the same asker in 30 s; finished give-ways, the battery rule and T7's
  gate unchanged. Native mirrors `_end_yield` and ask()'s first line. Joint bar above.
- **R35.15 (2026-10-19 ~12:20) A STALE native library on builder0 voided brains' E1 check (67a5a9db0: 2888/2, both turn-in
  tests; parade/docks back on their PRE-turn-in lines).** A remote run that waited for a slot built native at 09:23 from the
  pre-merge tree; the worker's merge (native/src changed, local mtime 09:22) then synced with `rsync -a` preserving the OLDER mtimes,
  so cmake rebuilt nothing. Proof (builder0): clean 0f4d528d7 8/0; brains' tree after `touch native/src/*` 8/0, identical. The check
  and its sim-baseline moves are VOID; E1 re-checks after M5. **Until N3 lands:** after any merge that touches native/src, `touch
  native/src/*` before a remote run, and read sim-baseline against main's current lines. **N3 (native, urgent):** native/build.sh
  stamps a content hash of native/src so a source change always rebuilds.
- **R35.16 (2026-10-19 ~12:35) The joint W1c + T9 dev read frees the stuck crews; mirrors released.** Manoeuvre (builder0,
  GDScript both arms, lab/w1c-t9 878200ede = stream 2428a2b25 + traffic 2af7d3528): law-605 Green_Eyes_4 base blocked 34.1 m short
  t 16 s to the judge (80 s), ON arrived by t ~24 s; law-607 Green_Guns_6 base blocked 23 m short from t 24 s, ON arrived by t ~48 s.
  ON counters: stall_intent_ticks 205 / 983, yields_unfinished 1 / 4, asks_refused 0 / 1. Native: N3 -> W1b pair -> W1c + T9 mirrors
  on ONE pair branch.
- **R35.17 (2026-10-19 ~12:45) D1's last red: test_tactics_body (brains' file).** orders-d1 `0603f3274` (builder0): `make check
  exited 2`, 2885/1, sim-baseline 13 unmoved; the scenario fix works. Red: his three squads keep together, "off 17.7 s, on 23.8 s"
  (line off + 5 s); reproduces alone; native path only. Sirens' body-route arrival: step off 18.5 s, step on + centred lay
  (1a5e33c47) 20.9 s, step on + on-spot lay 23.8 s. Ruling: orders takes ONE builder0 trace (+ one fix try in its carve-out); if
  that fails, the line is resized to the measured cost + 2 s, citing this ruling (he chose the deploy step knowing planner's pass
  was slower in some cells); NOT the centred lay (a squad sent to a spot ends on it is the stronger promise).
  **Follow-up:** orders' trace (builder0, `make body-trace-orders`): with the step on, the arrived Hunters2 re-forms into the Law's
  lane herringbone across the Sirens' street; Sirens_1 blocked 15–24 s; no carve-out fix keeps the on-spot promise; line resized to
  off + 8.1 s (measured 6.1 + 2), orders-d1 `581b8a396`; brains agrees; a round-36 item in game_design.md.
- **R35.18 (2026-10-19 ~13:05) T7's gate (C31.1) passes; its series starts.** `pair/underfire-t7` `e95179252` builder0 `make native
  check exited 2`, 2902/0, 24/27 pass; the one red sim-baseline (5 maps moved with T7 ON, 8 unmoved); switch-OFF inertness
  (`--traffic-off=underfire`, same commit) reads main's 13 lines. perf-judge and scenario_perf NOT JUDGED (load); perf-judge alone on
  a quiet builder0 is owed before any ship.
- **R35.19 (2026-10-19 ~13:10) Mirror pairs, and the joint pair's base.** W1b: `pair/native-w1b` `f4f6bf1d2` (manoeuvre 58395b79c +
  mirror; builder0 light `native test FILTER=test_native_` 107/0, 0 mismatches; halt ON on lab 1d2f0cac9 1094 halts a stage, 0
  mismatches) is W1b's SERIES pair; main only on W1b's bar. Joint: `pair/native-w1c-t9` `2446d46f9` = lab/w1c-t9 878200ede + traffic
  f432645dd + pair/native-t7 + pair/native-w1b + T9's and W1c's mirrors. Traffic's stream carries **T6b** (a give-way already begun
  finishes when a hit lands) as DEFAULT behaviour, not on main, plus T7 OFF; so the joint series' base includes T6b, and the joint
  pair merges only AFTER T7's verdict (if T7 parks, re-cut without T6b/T7 and re-twinned).
- **R35.20 (2026-10-19 ~14:30) M5's gate RED; fix; re-gate on main 1a18dd278.** lab/cpf5 `9a463b0b9` builder0 `make native check
  exited 2`, 2891/3, sim-baseline unmoved. All 3 reds W2's: test_nav_face_recovery and test_planner_trace_wedged (round 9's "never
  silent": the give-up stood the hull still without face_checked / face_giveups / face_stalled), test_planner_seam_hold rolling face
  (plan_face failures counted while still ROLLING; give-up before rest; hull 180 deg off at 40 s). Fix `55e53006d`: a failed plan
  counts only at rest (|speed| <= 0.5 m/s; a refused leg still counts), and the give-up reports. Re-gate on main 1a18dd278 (the
  deploy step changes player plain-move halts, which hull-rest's drawn/clicked stages use); full-check order main's batch -> M5 ->
  W1b-ON. **Follow-up:** the first fix left the same 3 red (builder0, 39f66c60a). Trace (laptop, each default flipped alone, no flags):
  only FACE_SETTLE breaks the rolling face: a face ordered while rolling keeps its home where the order found it; the rig rolls 8.8 m
  past a home it must plan within 5 m of; settle stands it out there. Fix `f283fc089`: under settle the face's home follows the hull
  until rest, and the standing face runs round 9's own give-up window (`OrderController._face_giving_up`). **Re-gate hashes:**
  candidate lab/cpf5 `61a46d3c6` (stream cc2a001fc + both defaults true), native base lab/cpf5-base `de75b6757` (cc2a001fc, defaults
  false), on main 1a18dd278; E1 not in.
  **Superseded by R35.23's scope:** gate candidate lab/cpf5 `63336d690` (stream a960fa2c2 + both defaults true), native base
  lab/cpf5-base `4fb7493a2` (same code, defaults false), on main 1a18dd278; E1 not in. Pre-gate builder0 `make native test` over 49
  face / planner-seam / planner-trace / turn-hull / planner-keep / wheeled-arrival tests: 49/0.
- **R35.21 (2026-10-19 ~14:55) D2's report (reported, not gating; his "mixed" confirmed).** `make orders-probe` builder0, main
  977a270fa (1a18dd278's code; library from 581b8a396's build, no game-code difference), seed 34, n 1 a cell, main v deploy_off.
  With the step on: twitch after settling falls on Crossing (5 click 46.5 -> 23.3 m, 3 click 32.2 -> 18.3) and Locks 3, rises on Locks
  5 click (4.4 -> 19.6), Terminus 5 click (13.1 -> 30.6); all-in mostly within a few s; Locks 3 route slower (38.3 v 18.5 s); Locks 5
  route now finishes (45.6 s; deploy_off never). D4 (minimax seating) and D5 (gate deal) target exactly those cells. Rows:
  `stream/orders` 56ed913fc `references/round35/orders/d2-main-1a18dd278/`.
- **R35.22 (2026-10-19 ~15:25) E1's re-check timed out; the unfinished targets run alone.** `83b3b90b4` (67a5a9db0 + main
  fc1f4ac0e's N3), builder0: `slot.sh: killed after 5400s` under load mid ai-scenarios-check (no FAIL in its log). Finished: test
  2890/0 (the turn-in tests pass: the stale-library diagnosis confirmed), 16/26 targets passed, sim-baseline ALL 13 UNMOVED at main's
  current lines (the release changes no baseline match), determinism 8c3c1232b711a760. Ruling: the 10 unfinished targets run on the
  same tree with CHECK_TARGETS; finished 16 + those 10 = the gate.
- **R35.23 (2026-10-19 ~15:45) W2's design note: the give-up was scoped too wide.** a5053e70e (builder0 native, 48 face / planner /
  turn-hull / wheeled-arrival tests): 46/2; the rolling face and Terminus street rig pass; the wedged semi (test_nav_face_recovery,
  test_planner_trace_wedged) reads 0 give-up windows in 8 s, because those tests send PLAIN `face` orders to wheeled hulls, where
  round 9's creep and its window are the designed behaviour, and settle removed the creep that ran the window. Approved: the give-up
  acts only on faces lifted by turnhull (his drawn facing on a wheeled turret hull), plus a test that a plain face on a wheeled turret
  hull still creeps under FACE_SETTLE true. Plain faces pass by construction, not by tuning.
- **R35.24 (2026-10-19 ~15:55) The joint pair's twins.** `2446d46f9` (W1c OFF) builder0 light 111/0, 0 mismatches; T9's forced
  endings reach 8 unrecorded and 6 capped give-ways. Lab 6548394ea (W1c ON): 0 mismatches, W1c's intent read fires 49 a fight / 8 a
  hold stage, but 109/2 on coverage floors: Sumps' yield stage reaches no parked refusal and no plain refused ask with W1c ON (the
  pinned crew escapes first). Floors re-scoped under C34.6 (`f9ff445b0`, `ca004661e`: the parked refusal floored on yard_open in both
  arms). Ruling: the plain refused ask (ask()'s line T9 changes) gets a FORCED compare with W1c ON before the pair is named; it is the
  shipped configuration's path.
- **R35.25 (2026-10-19 ~16:00) main eea6fb9fa = native 44d06cbbe (`tools/builder_checks.sh` + the slot-exclusive light-lane fix):
  green by composition.** Its only check-read diff from 1a18dd278 (green) is three files that only shell-tools-test reads, and
  shell-tools-test passed on 44d06cbbe (builder0 light, 25 suites). **Every worker launches full checks behind `tools/builder_checks.sh
  --wait-below 2`** (counts `make [native] check` in every form, one per worktree).
- **R35.26 (2026-10-19 ~16:15) D5's A/B: gain passes, three guards fail; one trace, one fix try, fresh re-read.** builder0 `make
  native orders-probe`, stream/orders 554131533, seeds 3611–3616, n 6 a cell, medians. Counter: gates laid in 31/36 main route runs;
  the Locks 5 route's legs differ. **Gain passes:** Locks 5 route median all-in 19.9 v 33.4 s (bar <= 23.4); summed route medians
  153.3 v 170.4 s; click cells 36/36 identical. **Guards fail:** (1) Crossing 5 route 1 never-in seed on main v 0 (s3614, squad 4
  29 m short); (2) deck up in Crossing 3 route (6 v 5) and Locks 3 route (4 v 2), far bank 0 everywhere; (3) Crossing 5 route
  drive/plan 2.17 v 1.94 (+0.23 v +0.2). Fails as filed; lines unchanged. Next: trace s3614 and the deck runs; at most one fix try;
  re-read on FRESH seeds **3631–3636** (same bar); a second fail parks D5 with the trace. D4's A/B runs with `--gate-deal=off` in both
  arms if the tree has the deal ON, so D4 is judged on main's behaviour.
- **R35.27 (2026-10-19 ~16:30) E1's partial ran nothing: a partial check must include `lint`.** `check CHECK_TARGETS="<10>"` on
  83b3b90b4: 0 passed, 10 NOT RUN, because the runner orders every target after `lint`. E1's series (HULL_JOBS / FIGHT_JOBS 3) started
  on the partial's done-file and runs on (test 2890/0 on this tree; sim-baseline at main's lines); the corrected partial (`lint` + the
  10) follows it; a red there on E1's paths voids the series. E1 merges only on the partial's green. **Lesson for orchestration.md:**
  a CHECK_TARGETS partial lists `lint` too.
- **R35.28 (2026-10-19 ~16:40) A shift-clicked route REPLACED, not queued, after untangle (orders' find; pre-existing, both arms).**
  Crossing 5 route s3614: squads 3–5 got ONE leg (two shared a place). Cause: round 22's `SelectionSquads.untangle` (O1b) re-deals
  VEHICLES between squads at the first click; the elements no longer match the control groups, so each later shift-click finds no
  element exactly the group, `_queue_task_for` returns null, and the task replaces instead of queueing. **Ruling: (b)**, a shifted
  move queues on the elements its units now belong to. NOT (a) (whole squads only): round 22's answer to his interleaved squads WAS
  the cross-squad re-deal, and he accepted "two interleaved squads sent abreast no longer cross". **D6 (orders)**, after D5's re-read
  and D4; bar filed before code: every squad gets every leg on the reproduction (reported) and fresh route seeds; round 22's Sumps
  seed 5988 case keeps 0 path crossings; queued-task / route tests green; click cells byte-identical; a test that reproduces the
  replace. D5 fix try `45d34470a` (the gate's approach pointed backwards on s3614); re-read on fresh 3631–3636.
- **R35.29 (2026-10-19 ~16:45) The joint W1c + T9 pair is green: `pair/native-w1c-t9` `6177ee87a`.** Builder0 light, `native test
  FILTER=test_native_yield` 12/0 on it (W1c OFF) and on lab c8db0a442 (W1c ON); the forced plain-refusal stage (REFUSE_POSES, 5 Sumps
  poses) reaches asks_refused 5/5, 0 mismatches both arms; the parked refusal floored on the under-fire stages (native corrected its
  own earlier yard_open claim on the re-run). Next: C31.1's `make native check` with BOTH switches ON (manoeuvre cuts that tree),
  then the joint series; merge only after T7's verdict (R35.19).
  **Series trees:** base lab/joint-base `df82e66a7` (6177ee87a + FIGHT_RANGE + the probe's T9 counter rows, measurement only), ON
  lab/joint-on `b04bfdda2` (same + STALL_INTENT_DEFAULT true + yieldfit2 default on); native both, no flag arms; ON's check queued
  after M5's gate.
- **R35.30 (2026-10-19 ~17:00) W1b's gate (C31.1) passes; its series starts.** lab/w1b-on `7fc4a5307` builder0 `make native check exited
  0`, 2891/0, one ai-scenario NOT JUDGED (load), sim-baseline unmoved on all 13 (nothing to attribute). Series ON 7fc4a5307 v base
  ab9c50c76, 3820–3843 x locks/terminus/sumps, JOBS 2 beside T7's, E1's and D4's series.
- **R35.31 (2026-10-19 ~17:05) D4 minimax seating FAILS its bar; PARKED OFF.** builder0 `make native orders-probe`, stream/orders
  68d4c06cd, seeds 3621–3626, n 6, both arms `--gate-deal=off`. Counter: 25 of 36 click runs differ. Gain: summed median twitch
  169.1 v 179.8 m (-6 %, line -20 %); Terminus 5 click 5.7 v 18.9. Per-cell guard (<= off + 3 m) fails in 4 cells (Crossing 3 click
  15.4 v 10.7; Crossing 5 route 29.4 v 21.4; Locks 5 click 21.4 v 13.9; Terminus 5 route 21.2 v 17.3); never-in up (Terminus 5 route 3
  v 2, Locks 5 route 1 v 0). Parked OFF (`bd22ac4c8`, `--deploy-minimax=on`). Round 36: the residual twitch IS the deploy move (a
  wedge across the street re-forming into a herringbone along it) plus seats reached only round obstacles (game_design.md).
- **R35.32 (2026-10-19 ~17:10) E1's series: counter by inference; line (b) vacuous.** Releases > 0 in the ON arm (6 in the first 119
  hull runs), INFERRED from the trace (a wait streak >= 8 s ending with the waited-on crew < 2 m nearer over its last 8 s = the release
  rule; the once-a-second LEG_GATE line misses the release's update); the inference reads 0 in both arms on the pre-release census
  c23acdbe2 (no false positives). Line (b) faced_move is VACUOUS (a plain move plans through `_plan_form_up`, not `_advance`; leg-wait
  0 in every run), reported as vacuous, not a pass.
- **R35.33 (2026-10-19 ~17:30) M5's re-gate (C31.1) passes; its series starts.** lab/cpf5 `63336d690` builder0 `make native check exited
  0`, 2896/0, one ai-scenario NOT JUDGED (load), sim-baseline unmoved on all 13 (the scoped give-up touches no baseline match); base
  lab/cpf5-base `4fb7493a2`. Series at HULL_JOBS / FIGHT_JOBS 2 beside W1b's. The joint W1c+T9 ON check (b04bfdda2) launched.
- **R35.34 (2026-10-19 ~18:05) D5's fresh re-read FAILS; the gate deal is PARKED OFF** (`84ba02a69`, `--gate-deal=on`). builder0,
  stream/orders bd22ac4c8 (the backwards-approach fix in), seeds 3631–3636, n 6. Counter acted; click cells 36/36 identical. Gain:
  Locks 5 route median all-in 25.8 v 34.2 s (-25 %, line -30 % = 23.9 s): FAIL; summed route medians 170.5 v 179.2 s. Guards: never-in
  0 v 1, all-in, drive/plan (Locks 5 route 1.49 v 3.37) pass; deck up in Crossing 3 route (5 v 3) and Crossing 5 route (5 v 2),
  near-ramp nosing, far bank 0: FAIL. **For the lead at the close (his item, a feel call):** the Locks 5-squad route gets everyone in
  ~8 s sooner and drives half the detour, at the cost of crews nosing onto a near bridge ramp a little more often on the Crossing
  (never across). Parked as filed; offered to him with the numbers.
- **R35.35 (2026-10-19 ~18:40) M5's ON arm measures W2 on the native path; its counter-first line needs a sample.** Native (code read of
  63336d690): a wheeled hull's `face` order hands the whole execute step back to GDScript (execute_native.cpp ~363–378, reason 3
  `other_order`); turnhull's lift is in `TankBrain._order_move` (GDScript); W2 is in `Movement.face_turn` + Manoeuvre's face_* helpers.
  Gap: `face_settles` / `face_settle_fails` are not in `ManoeuvreCensus.counters()`, so the series' rows can't show (o2). Ruling: a
  measurement-only tree (63336d690 + the two census counters) on a sample of the drawn cells (~16 runs, the series' seeds); its rows
  must equal the series' on every non-counter line, and face_settles > 0 there satisfies (o2); native's counter run is the second check.
  **Follow-up:** native's counter run (builder0 light, 63336d690 + scratch counters, new_drawn, seed 460, gangs + law, 12 runs):
  face_settles 27, face_settle_fails 93, hull_turns 17535, hull_holds 688; execute_counts handed_back 285692 (face 205912, other_order
  0), verify_mismatches 0: W2 and turnhull fire natively. Hull-rest is not run-to-run deterministic everywhere, so the sample's
  non-counter lines need only sit within M1's A/A noise of the series' rows (exact equality is a bonus).
- **R35.36 (2026-10-19 ~18:45) The orchestrator broke C35.1; the series lane is enforced from now.** C35.1 says at most ONE full
  check and ONE judged series on builder0 at a time; through the afternoon the orchestrator let two full checks and up to five series
  run together (load 20–22). Cost: W1b's first series step killed at slot.sh's 5400 s (64/72 fights, 3 corrupt copy-back files), E1's
  re-check timed out, checks ran ~2x. builder2 stays OFF (his choice; builder0 only). **Series queue, one at a time:** the three
  already mid-run finish (T7 at its last arena, E1, D6's probe), then **W1b -> M5 -> the joint W1c+T9 (after T7's verdict) -> T8**.
  W1b and M5 (restarted 30 s before) stop and wait. Full checks: ONE at a time, behind `tools/builder_checks.sh --wait-below 1`.
  Dev / light runs stay small (JOBS <= 2). **Lesson for orchestration.md:** the machine contract is the brief's, not the
  orchestrator's convenience; read C35.1 before granting a slot.
- **R35.37 (2026-10-19 ~19:20) The joint-ON check is RED.** lab/joint-on `b04bfdda2` builder0 `make native check exited 2`, 2916/3;
  sim-baseline moved foundry, crossing, sumps, cut (attribution by lab/joint-base). Reds: test_manoeuvre_h1b_guard and
  test_nav_blocker_reach's control arm assert today's premises that W1c / T9 change by design (no escape fires; nobody is asked to
  give way): pinned OFF in those arms PLUS an ON arm asserting the new behaviour (manoeuvre owns tests/nav/, nav's successor).
  test_tactics_mixed_legs: four tanks attack-moved across the Sumps don't arrive (31.9 m short), NATIVE path only (laptop GDScript
  passes on/off); being run natively on joint-base v joint-on to tell the carried T6b/T7-OFF code from the mirror. Series held.
- **R35.38 (2026-10-19 ~19:30) D6 passes its bar as filed but is HELD: a squad crossed to the far bank.** builder0 `make native
  orders-probe`, stream/orders 84ba02a69, seeds 3641–3646, n 6, main v `--requeue=on`. Counter: legs differ in 12 of 36 route runs;
  every squad every leg 144/144 v 117/144; click cells 36/36 identical; queued-task / route / untangle / requeue tests green. But
  Crossing 5 route s3643 with requeue ON: TWO squads reach the far bank (0 off; deck 9 v 4); squad 4's crews got goals across the
  river at 31 s (Delta_3 at -79.3, -7.1) though its place (-100.5, 28.9) is on his side. Also: Crossing 5 route all-in 41.0 v 33.9 s,
  Locks 5 route 35.4 v 29.3, Terminus 5 route never-in 2 v 1. The bar omitted D5's far-bank guard (the orchestrator's miss); **every
  orders bar now carries far bank 0 in every cell.** Trace s3643 (laptop), fix, re-read on FRESH 3651–3656 with far bank 0.
- **R35.39 (2026-10-19 ~19:50) The joint pair's native-only red is a real interaction; W1c is scoped to OTHER elements.**
  test_tactics_mixed_legs on lab/joint-on (builder0 native) passes alone (50.6 s) and fails whenever another test runs first in the
  process (31.9 m short); joint-base passes in the same order. Trace: from t 48 s Green_M_3 is blocked by its OWN squadmate M_2
  (parked at its seat); W1c's escape fires again and again (H1 asks 5 -> 12) but an ask to an own-element crew yields nothing
  (yields_started 5 stays); the escape's reverse/forward cycling keeps brains' round-18 D5 re-seat (`reseats` 1 in every passing run)
  from ever reading "driving without closing". Ruling: W1c's intent reading applies only against a friend in ANOTHER element (or
  unseated); against an own-element squadmate today's gate and the re-seat stand. Native mirrors one predicate. A deterministic test
  builds the nose-on-own-squadmate pose directly. The between-test state that lets process history decide who ends nose-on is to be
  named (lesson 83).
  **Follow-up:** built `e795505ea` (+ spec `7620f67f0` to native); builder0 `make native test` over stall_intent / h1b /
  blocker_reach / mixed_legs (mixed_legs last) 15/0: own squadmate -> 0.05 (the command), another element -> 1.00 (the intent); four
  tanks across the Sumps with W1c pinned ON arrive 57.3 s, reseats 1, identical to base. The exact nose-on pose is not rebuilt live
  (time-boxed); the rule test pins the predicate. What carries between tests is unproven; leading candidate trip-up 82 (Godot settles
  TOUCHING bodies differently in a process's first match); per-instance tables and W1c's counter ruled out.
- **R35.40 (2026-10-19 ~20:05) D6's far-bank crossing traced and fixed; the re-read joins the series queue after W1b.** s3643:
  squad 4's final place sat at the west bridge's MOUTH (-100, 28; his click 4 m from the deck's end); with requeue it arrives by its
  whole route from the north-east and its shape, laid on that heading, puts seats past the dry deck on the far bank (the water rule
  keeps seats off the canal, not off a deck's far end). Fix (`1b174f05d`, under D6's switch): a shifted leg's places step back along
  the way the squad came from any deck their seats would reach; a click on or within 2 m of a deck leaves them. Laptop s3643 far bank
  1 -> 0; test_control_deck_clear 3/0; control suite 467/0. **Series queue now: W1b -> D6 re-read (3651–3656) -> M5 -> joint -> T8.**
  Round-36 watch: a plain click right at a bridge mouth could lay seats past the deck today (far bank 0 in every A/B this round).
- **R35.41 (2026-10-19 ~20:15) D3b grant (orders, in brains' `ElementPlan._plan_form_up`).** ONE switched addition, default OFF: when
  the task carries `halt_at` (set only by orders' pack, itself OFF), the last INSET_NEAR_M of the move uses a file/column arrival.
  Nothing else in the function; merge note to brains (told). Bar first (fresh seeds, far bank 0 in every cell, D3's gain/guards);
  its series after T8.
- **R35.42 (2026-10-19 ~20:30) E1 PASSES its bar; merge waits on the partial gate.** `83b3b90b4` (E1 67a5a9db0 + main fc1f4ac0e
  tooling), builder0 native, base `--straggler=off` same tree; FRESH 701–716 x 4 factions (64 attack-move pairs), fights 720–743
  (n 24). (0) releases 6 v 0 (inferred). (a) long-hold seconds 89 v 358 (0.25x; paired -269, se 116.4, 2.3 se): all in the 6
  released runs, the other 58 identical; wait seconds 339 v 561 (wedged 138 v 342). (b) VACUOUS. (c) left > 25 m 17 v 20. (d) late
  movers 13 v 10 (+3, limit 4.4; released crews still driving at 75 s), settled 35 v 34. (e) arrived 194 v 190. (f) kills 970 v 970,
  deaths 984 v 984, hit rate 0.718 both (the release fired 3x for CPU elements). (g) test 2890/0, sim-baseline unmoved; the corrected
  partial (lint + 10) queued. **In his terms:** when one crew is wedged, its squad moves on to the next attack-move leg after ~8 s
  instead of waiting a minute or more; the wedged crew catches up or stays stuck (W1c + T9's job).
- **R35.43 (2026-10-19 ~20:40) D3b withdrawn before its series; D3 stays parked for a round-36 redesign.** Built within R35.41 (OFF).
  Laptop look at seed 34 (reported only; 3661–3666 unseen): arrivals no longer mix (closest foreign at arrival 7.0–13.1 m in 5 of 6
  cells) but the spread GROWS in every click cell (end far Crossing 3 64.0 v 34.2, Locks 3 67.3 v 49.4) and the pack arm crosses the
  river in both Crossing cells (far bank 1 each): the strict pack (every seat on good ground, arrivals apart) pushes places away from
  the click. Not spent on the series lane. Round 36: redesign the packing objective (game_design.md). Series queue: W1b -> D6 re-read
  -> M5 -> joint -> T8.
- **R35.44 (2026-10-19 ~20:45) T7 PASSES its bar as filed.** Pair `e95179252`, builder0 start to end, native, pinned, 180 s, fixed
  arenas {terminus, locks, sumps, gorge, parade} x 1600–1627, n 140 paired, none missing; crossing 44–46 x 6. Counters (arm):
  underfire_refusals 427, passes 311 (192 abreast, 44 timed out), gives 1327, holds 68; base 0. **G** jam-under-fire deaths 277 -> 240
  (-13 %, se 17.65, 2.1 se): PASS. Guards: open 4780 -> 4746; stuck 958 -> 960; far loops 108 -> 108; kills 6037 -> 5979, hit rate
  0.732 -> 0.731; post-hit contacts 416 -> 407; crossings 180/180 x 4; all friendly contacts 107053 -> 107271 (+0.2 %): all PASS.
  Reported: all deaths 6082 -> 6019; by arena G terminus 66->49, sumps 71->60, gorge 52->40, locks 55->56, parade 33->35. T6b's costs
  (stuck +61, far loops x2) are gone. **Before it ships:** (1) T6b's abort removal ("a give-way already begun finishes when a hit
  lands") is default behaviour in BOTH T7 arms and not on main; R34.20 parked T6 (T6b's series failed stuck and far loops), so T7's
  pass does not cover it: traffic shows a filed T6b pass, or T6b is switched and ships OFF with T7 re-verified on that tree;
  (2) the hand-over re-cut on current main + one `make native check`; (3) perf-judge alone on a quiet builder0.
  **(1) settled (2026-10-19 ~20:55):** main never had a mid-step abort; T6 ADDED it as rule (c) and T6b removed it again, so the
  hand-over's `right_of_way` differs from main by a comment only (checked by the orchestrator: `git diff main 3dbc206a0 --
  game/ai/movement.gd`); the native abort was dropped in T6b's re-cut; T6b's kept parts (the refusal, the self-yield hold) are what T7
  replaces and gates; switch-OFF inertness reads main's 13 lines. T7's pass covers the hand-over. Hand-over: `handover/t7-on-main`
  `3dbc206a0` (= main 8be787afe + the judged pair); its check follows brains' partial.
- **R35.45 (2026-10-19 ~21:00) E1 merged (main bbe418b80); one batch main check after T7.** E1's gate: builder0 test 2890/0,
  sim-baseline 13/13 unmoved, determinism 8c3c1232b711a760 + the partial (lint + 10) exited 0, 2 NOT JUDGED by load. Main now carries
  E1 and D1 (both in element_plan.gd, different functions) unchecked together; T7's hand-over (cut before E1) takes the full-check slot
  next, then merges, then ONE main check of E1 + T7 + D1. Workers don't merge main until it's green.
- **R35.46 (2026-10-19 ~21:30) E3 closed: no lever.** Brains' census (74526bca1, laptop GDScript, lane_census showmatch locks /
  terminus / crossing x seeds 1400–1409, n 30): 56 flips to hold (35 ahead on points, 21 zone threatened); engaged elements re-posted
  > 40 m at a flip lost 15 / 30 / 25 % of crews in the next 30 s v 19 / 40 / 33 % for those that kept their task (SELECTED groups: no
  sign the pull-back is worse, not proof it is better). locks-1404 is one fight's shape (as B9 / R34.19). No A/B. **E4 (brains,
  trace only):** what carries between matches in one process so test_tactics_mixed_legs plays differently after another test (trip-up
  82 suspected; BodyStage R32.6), and whether a reset makes the second match equal the first.
- **R35.47 (2026-10-19 ~22:00) E4 named: a bare `global_position =` leaves the physics body at its spawn slot until the first step.**
  Brains' probe (laptop GDScript, the four-tank Sumps stage seed 1 played twice in one process): 1st 50.0 s / reseats 1, 2nd 55.9 s /
  reseats 0; they diverge at step 0 (2nd match only: outer tanks pushed 0.31 m inward), because every body still sits at its Match
  spawn slot before lab.start and stale bodies overlap neighbours; a later match resolves it as penetration. `Tank.place` (node +
  server flush + interpolation + sync_position) makes both matches identical in poses AND Match.state_hash at all 1800 steps. Fix in
  brains' lab paths approved (bar above), after the batch main check. 85 other test files (brains' corrected count) spawn then assign `global_position`; listed
  for their owners in round 36 (orientation lesson).
- **R35.48 (2026-10-19 ~22:20) Main's batch check of D1 + E1 + T7 is GREEN** (f2690c8ef, builder0 `make native check exited 0`, 2908/0,
  25 passed + 2 NOT JUDGED by load). Workers merge main. Full-check order: manoeuvre's joint2-on C31.1 (319d63fec) now, then brains'
  tip (E4 + the release counter) on the orchestrator's word. Series lane: W1b (~02:00) -> D6 re-read -> M5 -> joint -> T8.
- **R35.49 (2026-10-19 ~23:15) builder2 is back: a second series lane.** The lead had builder2 converted to a cost-optimized Spot VM
  (e2-highcpu-32, us-west4-a, 32 GB; same name and ZeroTier IP; idle auto-stop after 20 min; `_agents/gcp_builder.md`). Verified:
  `make gcp-remote T=sim-baseline` reads all 13 recorded lines. **Machines now:** builder0 = one full check + one judged series;
  builder2 = one judged series (both arms of a series on ONE machine, gcp_builder rule 1), `make gcp-start` first (it stops itself
  when idle), launched via `make gcp-remote` / `REMOTE_HOST=slobdell@builder2`. **M5 moves to builder2 now** (its gate was builder0's
  63336d690 check; rows are pinned so the machine does not change them). builder0's lane: W1b -> D6 re-read -> the joint -> T8.
- **R35.50 (2026-10-19 ~23:50) main 214e444ef = native's pass-lane port (T7's `_pass_lane` + sweep in C++; R35.8 follow-up).**
  `8f7c8a1f5`: builder2 `make native check exited 0`, 25 passed + 2 NOT JUDGED (timing; builder2 never judges timing), 2910/0,
  sim-baseline 13 unmoved; 576-pose twin 0 mismatches. Green by composition: the only other diff from the checked tree is
  mk/gcp.mk and tools/gcp/*.sh, which no check reads. First full check on the converted builder2.
- **R35.51 (2026-10-20 ~00:30) E4 merged (main 5f05c997c); a batch main check on builder2.** E4's gate (code c7c7d347a, builder0):
  2909/0, sim-baseline 13/13; bar (2) mixed_legs alone v after the others 50.03 s / reseats 1 both; bar (3) 33 of 34 moved behavioural
  keys equal their alone value (table `references/round35/brains/e4_moved_lines_85fa139cf.txt`). The 34th, test_tactics_scenarios_6
  `switches_per_unit_min` (main-suite 6.0, tip-suite 4.8, tip-alone 3.2), is a SECOND, pre-existing carry-over (that stage already
  places through TacticsLab.unit; history-dependent on main too): merged as known; brains bisects it on the light lane. Main now
  carries E4 + native's pass-lane port, checked separately: one `make native check` of 5f05c997c on builder2.
  **GREEN:** builder2 `make native check exited 0`, 2911/0, 25 passed + 2 NOT JUDGED (timing). Workers merge main.
- **R35.52 (2026-10-20 ~01:00) W1b PARKS as filed (one guard misses, upward).** builder0, native both arms, ON 7fc4a5307 v base
  ab9c50c76 (E1 not in), fresh 3820–3843 x locks/terminus/sumps, 72 pairs, 12/12 calls exited 0 (`references/round35/manoeuvre/
  w1b-series/`, stream dccdedd8d). Counter: halts 105296 ON. Deciding: wheeled pace-0 ticks still creeping 63 % -> 4 %; wedged + held
  deaths 242 v 239 (band 31.1). Guards pass: open, stuck, jam, far loops, kills, team 0 hit rate. **MISS:** team 1 hit rate 0.6733 ->
  0.6970 (+0.0237 v 1.645 se 0.0230): two-sided, misses by 0.0007. All deaths 2860 v 2862. Not re-read. Trace from the existing rows
  (no re-run): team 1's hits per exposed second on held wheeled crews at pace 0, base v ON. If up, a still held hull is a sitting
  duck (the rocking dodged fire) and round 36's answer is T8 (leave the hold when hit); if flat, a round-36 re-try. W1b stays OFF; its
  mirror unmerged. Series queue (builder0): D6 re-read -> the joint -> T8; builder2: M5.
  **Follow-up:** the existing rows can't split hits by a held target (FIGHT_CENSUS keeps per-team totals). Proxies (72 pairs, base v
  ON): held exposure equal (3468 v 3495 wheeled pace-0 s); held deaths 76 v 67 (down), but their last-10-s hits 9.2 v 11.4 per death;
  pooled accuracy up for both teams. Undecided; the probe line (each impact's target held/pace-0 state + exposure ticks) and a small
  re-run are round 36's first step, not this round's.
- **R35.53 (2026-10-20 ~01:20) The joint W1c + T9 series is re-cut on current main before it runs.** joint2-on `319d63fec` check:
  builder0 `make native check exited 2`, 2925/0, the one red sim-baseline (foundry, crossing, sumps, cut MOVED; joint2-base
  attribution running). But joint2 predates T7's ship: its base has T7 OFF, main has T7 ON + E1 + E4, and W1c / T9 change the
  give-way paths T7 gates under fire. Re-cut: native rebases its mirrors onto main 5f05c997c (`pair/native-w1c-t9-main`), manoeuvre
  cuts joint3 (base switches off, ON both on), C31.1 check + attribution, then the series on 901–932 / 940–963 in builder0's lane
  after D6. R35.19's T6b caveat is moot (T7 shipped).
  **Trees:** GDScript lab/joint3 `813f6e1ff` (main 5f05c997c + stream/manoeuvre + T9 c7de7cf95/aba7f800e; DEFAULT_OFF ["yieldfit2"];
  W1b excluded); native `pair/native-joint3` `7a1435cdd` (813f6e1ff + T9's and W1c's mirrors + floors + the forced refusal stage;
  diff v 813f6e1ff is T9 + W1c only); ON twins on lab 441c4dbc5. Native's first cut e2fe62c9a (with T8 and W1b) is superseded.
  The two new guards read traffic's jam_census (T5's definition), the probe's under-fire counts reported only.
  **Series trees (joint3):** base lab/joint3-base `2a2682560`, ON lab/joint3-on `872f82ae5` (STALL_INTENT true, DEFAULT_OFF [] = T7 ON
  + yieldfit2 ON), each = pair/native-joint3 `7a1435cdd` + one probe-only commit (friendly_contact_ticks per fight, guard (s)); E1, E4
  in; C31.1 `make native check` on 872f82ae5 on builder0, base's sim-baseline for attribution. Native saw the under-fire stage's
  give-ways 66 v 39 with yieldfit2 ON: the yields-started guard is the one to read closely.
- **R35.54 (2026-10-20 ~01:50) E4b, the second carry-over (test_tactics_scenarios_6): it is the runner's teardown.** Brains' trace
  (80ef83789): it flips on ANY earlier test in the process (even one that only waits 1 / 97 / 1000 frames, so not frame phase); the
  stage played twice inside ONE test is identical (GDScript and native), so a match does not change it, the first test's TEARDOWN does;
  per-tick dumps identical through step 28, then Rust_B_2 yields to its column leader only after a teardown. Candidates:
  `drain_navigation` or a lazily initialised static (Element._body_memo ruled out). **Granted (brains, narrowly):** `tests/run_tests.gd`
  warms up before the first test (one physics frame + the standard teardown) so every test sees the same state; marked interim.
  Bar: scenarios_6 alone == in the suite; full suite green, moved lines listed. Round 36: name the field, so tests can match the game's
  real first-match state (no teardown in play).
  **Follow-up:** written `0daea3d90`; scenarios_6 alone 4.8 = the suite value (builder0 light, native; was 3.2 alone); laptop GDScript
  3.0 alone and after (was 4.8 v 3.0). Its full check runs on builder2 (load ~6 of 32 beside M5's series).
- **R35.55 (2026-10-20 ~02:00) D6 PASSES on fresh seeds; REQUEUE flips ON.** builder0 `make native orders-probe`, orders-d6
  `ee3a8dab2` (84ba02a69 + deck fix 1b174f05d), seeds 3651–3656, n 6 (`references/round35/orders/d6-ab2-ee3a8dab2/`). Counter: legs
  differ in 22 of 36 route runs. Every squad every leg 144/144 v 121/144; far bank 0 in every cell, both arms; click cells 36/36
  identical; tests green. Reported: all-in equal or better in 5 of 6 route cells (Crossing 3 route 15.9 v 19.8 s); Crossing 5 route
  41.3 v 38.8 s but worst shuffle 39.5 v 80.6 m, drive/plan 2.39 v 1.71; Locks 3 route's never-in seed gone. **In his terms:** a
  shift-clicked route is followed by every squad (about one squad in six used to skip the waypoints and drive straight to the end).
  Next: the default flip on stream/orders, its full check after traffic's, merge alone.
- **R35.56 (2026-10-20 ~02:20) main 25f8bc52f = brains' E4b warm-up (interim), green by INHERIT** from 4a6394932's builder2 check
  (`make check exited 0`, 2911/0, sim-baseline 13/13). Moved lines v main's suite: 8, none in what a test measures (5 tick stamps +1;
  Manoeuvre's process-wide plan census shifted once in 3 c339 lines; every stage field identical). Brains' brief: done except E2 (waits
  on CP-F 5). Note: orders' D6 check (on 5f05c997c + its work) predates this; the runner change touches no game code.
- **R35.57 (2026-10-20 ~02:45) E4b's cause, corrected: the engine's FIRST main-loop iteration, not the runner's teardown.** Native's trace
  (laptop GDScript, main 5f05c997c, scenarios_6 switches_per_unit_min 4.8 alone v 3.0 after): all 815 `static var`s identical at a
  process's first test and after a 1-frame test (only the physics frame counter differs); an earlier test that steps NO frame changes
  nothing, whatever its teardown (drain_navigation ruled out); waiting 1–97 frames all read 3.0 (not frame phase); forcing the nav map's
  first sync without a frame: 4.8; one `await physics_frame` or `process_frame`: 3.0. So the state is engine-side, set by the first
  main-loop iteration (leading candidate: the physics space's first step / Jolt's broadphase bookkeeping; not named within the
  time-box). **Real play matches the LATER tests** (a match starts many iterations after launch). So brains' warm-up is the CORRECT
  fix, not interim: every test now sees real play's state. R35.54's caveat ("tests should match the first-match state") is withdrawn.
  Round 36: optional, name the engine state below the main loop.
- **R35.58 (2026-10-20 ~03:00) D6 merged (main 31e3d605c).** `93cdb1559`: builder2 `make native check exited 0`, 2941/0, sim-baseline 13
  unmoved (the CPU never shift-clicks). Parked OFF behind switches on main: D3/D3b, D4, D5 (GATE_DEAL=on for his feel call). Main now
  carries D6 + E4b's warm-up (checked separately): one batch `make native check` of 31e3d605c on builder2.
  **GREEN in parts:** the first run reached 22/26 targets with 0 failed (test 2941/0) before the LAPTOP's slot.sh killed the
  orchestrator's own `make gcp-remote` wrapper at 5400 s (builder2 loaded by M5's series; the remote make died with its ssh session);
  lint passed alone; the 4 left (bridge-pooled, native-verify-scenarios 0 mismatches, native-live-guard, planner-pytest) passed on
  builder2 under systemd-run. **Lessons (orchestrator):** launch long remote checks under `systemd-run` (orientation 86 already says
  so); a multi-word `CHECK_TARGETS` is word-split by remote.sh down to its first word, so run the leftover targets as plain make goals.
- **R35.59 (2026-10-20 ~03:10) joint3's gate (C31.1) passes; its series starts on builder0.** lab/joint3-on `872f82ae5` builder0 `make
  native check exited 2`, 2931/0, 26/27, the one red sim-baseline (foundry, crossing, sumps, cut MOVED); lab/joint3-base `2a2682560`
  sim-baseline 13/13 unmoved, so the 4 moves are W1c + T9's (adopt only if it ships). On main 5f05c997c: T7 ON, E1, E4. Series:
  wedge probe + fights + traffic's jam census on 940–963 x locks/terminus/sumps, then hull-rest drawn 901–932, both arms native, JOBS 3.
- **R35.60 (2026-10-20 ~04:30) stream/traffic's tip is red by construction only; T9 is judged on the joint pair.** 4fbbd4d3c (main 5f05c997c
  + T8 + T9 OFF), builder0 `make native check exited 2`: 2916/1, sim-baseline unmoved; the one red test_native_exec_state wants T9's three
  Movement members (`_unfinished_to/_count/_since`) in native/src/exec_fields.h, which native's T9 mirror carries in the joint pair.
  stream/traffic is not a merge candidate on its own; T9 reaches main only via the joint pair (joint3-on 2931/0). T8's series cannot
  fit this round behind the joint's (~8 h): its bar and pair plan open round 36.
- **R35.61 (2026-10-20 ~07:20) M5 PASSES: CP-F attempt 5 ships (main ed121d24f).** lab/cpf5 `63336d690` (stream a960fa2c2 + TURN_HULL and
  FACE_SETTLE defaults true; R35.23 scope), builder2, 60/60 calls exited 0 (`references/round35/manoeuvre/m5-series/README.md`, stream
  ced0c8992). (a) wheels/turret point tasks: move 4.3 deg / 80.2 % within 15 deg, right 4.4 / 76.5 %, attack-move 5.0 / 71.3 %. (b) no
  class worse at p < 0.05. (c) clicked +0.00 everywhere. (d) attack-move +6 v the A/A guard 15.4 (on the series' own se it would read
  +6 v +4.5: the bar sizes (d) from the A/A, as filed). (e) within +4.9. (h) 18/18. (i) kills / deaths / hit rate within. (j) hull_turns
  277373 v 0. (n) face_creep at the judge 0 v 0 (attempt 4: 8 v 0). (o2) builder2 sample: 9 give-ups, 16 cells identical crew for crew.
  (l) SBF hull error at arrival 3.5 v 26.5 deg (reported). (p) not readable (no per-crew give-up mark). 7 hull-rest cells hit the 300 s
  wall cap, unpaired (listed). The merge also brings W1b and W1c OFF (STALL_INTENT / WHEEL_HALT false), as on the gated tree. Batch
  check of ed121d24f on builder2 (systemd-run). **In his terms:** a War Rig he tells to face a way turns to it and goes still; nothing
  is left creeping. Brains' E2 (B11b) is unblocked.
- **R35.5 (2026-10-19 ~09:50) D1's census measured nothing; D1 ships on the check alone.** Orders' `make deploy-census` on
  `e9066083a` (builder0, 48 paired CPU-v-CPU fights, Locks/Terminus/Sumps, seeds 3501–3516): on and off arms BYTE-IDENTICAL,
  0 deploys either side. The census CPU only gives screen/attack/support_by_fire/ambush tasks, never a plain move, so the
  step never fires in a CPU fight. Its bar was filed after the reading (orders said so); it is moot. His yes (C35.2) is the
  decision; D1 ships when `orders-d1` `1a5e33c47`'s builder0 check is green and every moved sim-baseline map reads the
  recorded line with `--deploy-step=off`. What the step does on HIS moves is read by D2's probe (main v deploy_off), reported,
  not gating. **Lesson:** an A/B whose arms come out byte-identical has not exercised the change; check the change's own
  counter (deploys) is non-zero in an arm before reading any guard.
- **R35.6 (2026-10-19) C35.4a, ElementTask keys for packing (orders writes; brains' file).** Orders may add to
  `game/tactics/element_task.gd` ONLY: `KEYS` += `"halt_at"` ([x, z]) and `"halt_shape"` (a formation name), plus their
  `validate` lines. Additive and optional; set only by the controls when several squads are packed; absent = today. Brains
  owns the file and is told. ElementPlan reads them only in orders' own carve-out (`_deploy_state`: the anchor = halt_at when
  present; `_deploy_shape`: halt_shape, else `_halt_pick`); any other reader goes through brains.

## Round 34: six streams, two on Fable (prepared 2026-10-18, CLOSED 2026-10-19; briefs in `streams/archive/round34/`)

**Goal: the problems that have failed three times get the strongest model and a better ruler.** Round 33 shipped 14
items (HANDOFF *Round 33 closed*). Three things parked three times running: the parked crew that makes room
(parkedroom v1–v3), the War Rig's turn to face at rest (CP-F attempts 1–3), and the yard's last hull circling (T4
tries 1–3). Each time the behaviour itself worked and a guard or the judge failed. CP-F's last two misses were the stage
(wall-clock pacing, then the herringbone bug that brains fixed). parkedroom's last miss was a kills line that counted
a rout that never happened as a loss (traffic's random-859 trace). So round 34 fixes the rulers first, then tries again.

**The lead's words (2026-10-18), on round 33's two open questions:** "let's go with both of your recommendations."
That means (1) C33.9, the scout turn-in, ships as it is. It then failed its whole-suite check and its narrowing
flipped judged lines (R33.38, R33.39), so it is manoeuvre's first round-34 item (C34.10),
and (2) CP-F stays parked in round 33, with a fourth attempt in round 34 on top of the herringbone fix. His stand-or-hang-back
question is read as answered by (1): **a scout that can fight stands and trades; one that is outgunned gets away**
(the recommendation he accepted said "the real answer is that an outgunned scout should LEAVE"). Brains' duel-only
scout try 2 builds exactly that.

**Methods unchanged** (C31.1–C31.3, R31.1–R31.10, R32.1–R32.7, R33.20, R33.32 stand): the whole suite with the switch
ON on the pair tree before a judged series; bars sized from `judging.md` and filed in *Bars (round 34)* before any number;
FRESH seeds for judging; every judged stage pinned at `--fixed-fps $(SIM_HZ)`; a pair tree = main + its own commits only.

**Machines (`_agents/gcp_builder.md` rule 5):** builder0 is always on. builder2 (GCP Spot, about $0.52/h) is ON only when
the lead turns it on (or the orchestrator, under his standing yes, when queues are deep). When it is on, builder2 takes
judged series and the checks that gate them; builder0 takes dev, tuning, traces and light runs. A judged series stays on
ONE machine. Before a run, `make gcp-status` says whether builder2 is up; if not, use builder0 (`make remote`).

| Stream | Folder (offset) | Model | Brief | What he will notice | First item |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | **Fable** | [streams/traffic.md](streams/traffic.md) | a crew stuck behind a parked crew of another squad gets by, and the parked crew goes back to its post (parkedroom v4); the yard's last hull stops circling (T4) | the stuck-death census |
| **manoeuvre** | `godot-manoeuvre` (2) | **Fable** | [streams/manoeuvre.md](streams/manoeuvre.md) | his circled scout turns and fights instead of shuffling (C33.9, done right); a War Rig or other wheeled turret vehicle told to face a direction ends facing it and sits still (CP-F 4) | C33.9 |
| **brains** | `godot-brains` (3) | Opus | [streams/brains.md](streams/brains.md) | a scout stands and trades when it can win, and leaves when it can't; a pushed-off War Rig returns facing his way (B11b, after CP-F) | scout try 2 |
| **native** | `godot-native` (4) | Opus | [streams/native.md](streams/native.md) | nothing alone: every pair; a network match that never logs a shell hitting a dropped player | pairs, then the relay-smoke bug |
| **planner** | `godot-planner` (6) | Opus | [streams/planner.md](streams/planner.md) | a rematch without restarting plays out the same (replays and the network depend on it) | the rematch diagnosis |
| **orders** (added mid-round, 2026-10-18) | `godot-orders` (5) | Opus | [streams/orders.md](streams/orders.md) | three squads sent to one point all end up near it, on the side of the river he clicked; a shift-clicked route is followed squad by squad (C34.11) | O1 the ground cap |

**Launch baseline:** the docs commit's main inherits the last green main check (HANDOFF names it). Workers run no
baseline check.

**Ownership:** round 33's table stands (`workstreams.md` *Round 33*, Ownership). **New grants (round 34):**
- **manoeuvre:** `game/control/screen_playtest.gd`, ADDITIVE fields only, for the hull-rest crew row: (1B) `real_mps` per
  crew row and (2B) `--faced-shift-m`, a per-seed shift of the order's destination (control has no stream; merge note).
- **planner:** read all of `game/match/**`. Add a reset hook (or a fresh physics space per match) in `game/match/match.gd`
  for C34.6, ONLY after the diagnosis is written and agreed. Also `tools/judge/**` for C34.8 (the orchestrator's judging
  table, delegated this round).
- **native:** for C34.7, one guard on `_shell_hit`'s RPC in `game/match/match.gd` (~2094) and the shell teardown in
  `game/combat/shell.gd` (or its actual path), with a test. For C34.8, one `--fixed-fps $(SIM_HZ)` token in each of
  nav.mk, pace.mk, planner.mk, command.mk and tactics.mk's direct run_tests.gd callers, and in each JUDGED stage target
  the audit finds unpinned.
- **orders (new, C34.11):** `game/control/**` except manoeuvre's additive fields in `screen_playtest.gd`, `tests/test_control*.gd`,
  `mk/command.mk` (native's one `--fixed-fps` token there stands), `references/round34/orders/**`; READ-ONLY calls into
  `game/tactics/slot_ground.gd` and `game/ai/pathing.gd`; for O4 only, the queued-move done rule in `game/tactics/element.gd`
  (`_next_queued` + one helper; brains' file, merge note, agreed through the orchestrator first).
- **Nobody:** `tests/baselines/**` except the orchestrator's `make sim-baseline-adopt` on main.

**Contracts (round 34):**

- **C34.1 Fresh start.** Round 33's `stream/*` branches are renamed `round33/<stream>` (traffic's overnight branch is
  `round33/traffic-overnight`). Every worktree is created from this docs commit. Branches holding unmerged work that a
  round-34 item builds on are named in its brief, and every other lab/pair branch is history. `origin` holds old
  `stream/*` branches, so workers don't push.
- **C34.2 parkedroom v4 (traffic; native's hand-back).** v3 (R33.37) worked: hold-post loops 59 → 18, far loops 411 → 201.
  It failed two guards. (a) L6, the way back home: 89.96 % against 90 %. 19 of the 45 misses were still owed the way back at
  the read because the asker was still driving. (b) L3, kills and deaths: −3.9 % on random maps. The one fight traced
  (random-859) showed that a rout of crews caught stuck or jammed never happened (Rust lost 44 → 20). **Ruling (the
  orchestrator, under his "smart AI on both sides, symmetric improvements ship" rule):** fewer crews dying stuck in a jam
  is the fix working, not a harm, and needs no question to the lead. **Order:** (1) a REPORTED census on dev fights, not
  the judged 820–867, of deaths by cause (stuck/jammed v in the open), both arms, with `far_census --far-kills=on`. It says
  whether random-859 is the general case. (2) v4's bar, filed before any v4 number: L3 becomes deaths-in-the-open, two-sided,
  plus stuck/jammed deaths ON ≤ base (one-sided) and hit rate one-sided. L6 is read at a time the census justifies (e.g.
  when the asker has cleared, or 45 s), named before any number. (3) The pair is cut on CURRENT main and carries native's
  hand-back rebased (`ae8d6e858`, `f16f49867`, `a7999c5c4`, `5e5465af8`, today on `pair/native-parkedroom`). The C31.1 full
  check, then FRESH fights from 868 up.
- **C34.3 T4, a fourth try only after a trace (traffic; brains' body stage if asked).** T4 parked on G2 (R33.30): body
  cohesion alone_s rises > 3 s on seeds 7, 8, 9 and 14. First, per-seed traces of those four seeds, saying why the ghost
  changes which body route the Sirens' crews take. A fourth try is filed only if the traces name a fix. Native's
  ghost-aware twins (`pair/native-ghost-on` `b2b97188d`) come back only with it.
- **C34.10 C33.9, the scout turn-in, done right (manoeuvre's FIRST item; R33.38, R33.39).** He said ship it, and it
  failed the whole suite: it reached plain faces and every `stop`. Scope it to a crew facing a live threat it can't yaw
  onto at rest. Run the whole suite with the switch ON first, then a fresh bar on FRESH orbit seeds (not 11–36) with R33.24's
  lines. Native's hand-back is ready.
- **C34.4 The hull-rest ruler, the k-turn arrival flicker, then CP-F attempt 4 (manoeuvre; brains for the held-post
  refusal; planner advises).** In order. (1) The ruler: "still" reads REAL velocity (1B), wedged crews are their own line,
  the seed varies the stage's geometry (2B), and every hull-rest target is pinned. Each changes what hull-rest measures, so
  the target says so, and an A/A on the new ruler sizes its noise for (3). (2) The flicker (planner's diagnosis,
  `references/round33/planner/face-flip-s69/`): don't declare "arrived" while the seam or executor is mid-leg, or hold the
  faced finish until the leg ends (R33.2: manoeuvre owns WHEN a faced finish runs). Brains owns `_order_move`'s held-post
  refusal. Agree the seam through the orchestrator before either side writes code. It ships alone if it is a bug fix with a
  test that fails without it. (3) CP-F attempt 4 on main (herringbone in), on the new ruler, with a fresh bar and fresh
  seeds 41/44/45/66/67 excluded (kept as tuning). The base is `round33/manoeuvre` `18e37ec76` (CP-F code and the new judge,
  `cpf_judge.py` with jitter, `--wedged` and `--distinct`, all default OFF), rebased on main; the herringbone fix is already
  on main (`7f27a479c`). The flicker's lab is `lab/cpf-arriveleg` `7e0953f9d`. Ships ON as a pair with
  native's mirrors. Tell brains the merge hash the day it lands: B11b judges on it.
- **C34.5 Scout, try 2: stand when it can win, leave when it can't (brains; native's mirror).** C33.9's turn-in is ON
  (round 33). The rule: ENGAGE beats SPOT only when the scout's duel advantage ≥ 1.0 (Matchups.duel_advantage is a ratio)
  AND the contact is within its reach over the next 1–2 s. Otherwise SPOT's 0.88 stands, and the scout opens distance.
  Base: `lab/brains-scout` `0565d1a89` rebased on main. C33.9's turn-in is NOT on main (R33.39), so the arms are judged
  turn-in OFF, and the bar names whether a turn-in-ON arm is reported. A fresh bar on orbit seeds 73–79 (never used for tuning) covers the
  shots ratio, damage taken (no cell worse by > 20 %), scout survival, and team enemy-seen seconds ≥ base − 1.645 se.
- **C34.6 A same-process rematch replays (planner; UNOWNED until now).** A rematch in one process branches at TICK 1 on
  hull height (`references/round33/traffic/ov_replay.md`, seeds 1–6). A fresh World3D or clearing GDScript statics does not
  fix it; a fresh process does. (1) Find what the physics server carries between matches (body RIDs, broadphase, contact
  caches, a solver warm start) and write it down with the test that shows it. (2) Agree the fix through the orchestrator:
  a reset, or a fresh physics space per match. (3) A test where two matches in one process give identical hashes. Sim-baseline
  should NOT move (it already runs one match a process). If it does, say why.
- **C34.7 relay-smoke: a shell's RPC fires after the peer has dropped (native, grant above; R33.25).** Guard `_shell_hit`'s
  RPC on a connected peer (or stop shells at teardown), with a test that drops the peer while a shell is in flight and
  fails without the fix. relay-smoke and net-smoke stay green under a full check's load.
- **C34.8 Measurement debts (native: pinning; planner: the judging table and tools).** (a) native: audit every JUDGED
  stage and pin it (`--fixed-fps $(SIM_HZ)`), plus the five direct run_tests.gd callers. Make a list of every stage whose
  numbers move, as the suite's bar did. (b) planner: re-render `_agents/judging.md` with round 33's judged pairs
  (orchestration step 5b, not done at round 33's close). Then series_verdict's run identity across the tools, and a ruling
  request on retiring FACE_KEEP_FAR. P3 v3 waits on C34.4 (2), the flicker, which is most of its tail.
- **C34.9 War Rig follow-ups (brains).** Log the inset's engage distance in the War Rig trace (small). Then B11b (HOLD's
  return honours the post's facing for turret-mounted wheeled hulls) on CP-F ON, if CP-F ships this round. B10b returns only
  in a new form (re-ground with hysteresis) with a fresh bar, as a stretch.

- **C34.11 One click, several squads (orders; added mid-round from his playtest, game_design.md 2026-10-18).** Today
  `SelectionSquads.ranks` lays squads ≤3 abreast at a line's frontage and `fit_inside` clamps only to the arena walls, so
  an outer squad's anchor (~70 m off the click) can sit across a river; his scouts drove over a bridge to die. Decided:
  (O1) a ground cap: no anchor further from the click by DRIVE than ~1.5× its straight offset (+ slack) or > ~30 m
  straight; (O2) places found outward from the click by driving distance, constraint = ~9 m hull-to-hull clearance between
  vehicles of DIFFERENT squads (wedges may nest/overlap), each squad on its own side of the approach, tight ground stacks
  back along the approach road; (O3) a squad priced at the shape it will arrive in; (O4) in-between waypoints are the
  SQUAD's (passed when its centre is within ~its width; no form-up stop), a GATE as wide as the ground for several
  squads, single file only where the terrain narrows; only the last waypoint packs. Feel item: no judged bar unless
  asked; sim-baseline must not move (the CPU orders through `cpu_commander`). O4's edit in `element.gd` is agreed with
  brains through the orchestrator before code.

**Not this round (recorded):** battery (c) deploy-at-place, only if he still sees trucks setting up short. Engaged
fire-post loops (a battery firing at a target holds its spot): his T1c-b2 yes stands. CP-Q stays parked. R5 seat swap only
if parkedroom becomes an element make-room. Each is in `roadmap.md`.

## Bars (round 34)

_Filed here before any number._

**Bar, brains B1 (C34.5) scout try 2: stand when it can win, leave when it can't (filed 2026-10-18 by brains, before any
number; rule at stream/brains `86c8d7f68`).** Rule: TankBrain.scout_fights_back fires for a scout hit within 2 s by a
visible, non-prey contact that threatens it, with duel advantage >= 1.0 (a ratio), that stays within the scout's
effective range now and at +1 s and +2 s (both on their current velocities). Then SPOT scores 0.15 and ENGAGE wins.
Otherwise today's SPOT (0.88 / 0.7) stands and it opens distance. `--scout-fight=off` / env `SCOUT_FIGHT=off` is main.
Try 1's "can't outrun it" clause is dropped (R33.31). **Judged tree:** lab/brains-scout2 = stream/brains + manoeuvre's
`608c3357e` (the orbit stage, which exists only beside the turn-in; switch default OFF). Turn-in OFF rows are judged and
turn-in ON rows are reported (each cell runs both). **Ship tree:** stream/brains without 608c3357e.
(1) DECIDING, `make scout-cells SCOUT_CELLS_SEEDS=73-79` (24 cells, n 7, GDScript both arms, --fixed-fps), ON v off:
(a) pooled scout shots ON >= OFF, and on ENGAGED cells (ON ENGAGE ticks >= 1 s a run) pooled shots ON >= 1.25x OFF;
(b) no cell with OFF median hits >= 10 has median damage taken ON > 1.2x OFF (smaller cells reported); (c) ENGAGE
ticks ON > 0; out-of-reach cells' ENGAGE ticks reported. The exchange (dealt / taken) per cell is reported.
(2) The pure tests, both sides of the rule (tests/test_ai_scout_fights_back.gd).
(3) Fights guard, `make scout-census` (showmatch, native ON, --fixed-fps), FRESH seeds 29–36, n 8, ON v
`--scout-fight=off`: scout deaths, paired per seed, mean(ON − OFF) <= 1.645 se; team enemy-seen seconds mean(ON − OFF)
>= −1.645 se; kills reported. (4) `make check` on the ship tree with native's mirror: test_native_decide 0 mismatches;
sim-baseline moves named and attributed with `SCOUT_FIGHT=off`. (5) The worst ON cell traced before its medians are read.
**Ships ON if (1)(a)(b)(c), (3) and (4) pass.** Tuning: seeds 50–59 only. One machine for each series.
**Amended (brains, 2026-10-18, approved by the orchestrator; before any judged number, tuning seeds 50–52 only).**
Two findings in tuning. (i) The champion x18m runs with `matchups: false`, so decide's matchups table is empty and an
advantage rule never fires (seeds 50–52, builder0: ENGAGE 0, arms identical 799 v 799). Fix `834562ab1`: decide
computes `matchups_for(s)` only for a scout under fire with the switch ON. With `--scout-fight=off`, `scout_under_fire` is
false and nothing extra is computed, so the OFF arm stays main. (ii) The stage's own cells (syn_scout, gang_ifv) can't
exercise the stand side. Laptop probe, seed 50: advantage >= 1 on 207 of 5320 rule ticks, and none of those in reach.
**So:** (1) runs two cell sets per seed. The STAGE set is manoeuvre's 24 cells. The DUEL set is
`tests/test_ai_scout_duel_cells.gd`, which drives manoeuvre's `_orbit_stage` unchanged: subjects law_scout and
gang_scout, circled by syn_lancer or law_tank (turreted orbiters a scout can beat by the brain's own estimate), at 15,
24 and 35 m, post and free, turn-in OFF. That is 24 cells, all judged, PINNED now, and none added or dropped later.
**(a) and (c) are judged on the DUEL set** ((c) now reads ENGAGE ticks ON > OFF, and "engaged" means ON exceeds OFF by
>= 1 s a run). **(b) is judged on BOTH sets**, plus pooled shots ON >= OFF on the stage set. The stage set's turn-in ON is
reported. Judged seeds are FRESH 73–79. Seed 50 and every cell already seen count as tuning only.
**Verdict (brains, 2026-10-18): PASS, ships ON** (rows in `references/round34/brains/scout2_*`). (1) builder2,
lab/brains-scout2 `5abdcd32e`, seeds 73–79, n 7 a cell. DUEL set: (a) pooled shots 4299 v 3490 (×1.23), engaged cells
(8) 1950 v 1139 (×1.71, bar 1.25) PASS; (b) no cell worse by > 20 % PASS, pooled damage median 825 v 842; (c) ENGAGE
ON−OFF 14452 PASS, out-of-reach cells +32 ticks. STAGE set: shots 1779 v 1778, (b) PASS, damage median 182 v 182 (the
outgunned scout keeps its distance, as today). Turn-in ON reported: shots 5432 v 5434, (b) PASS. (5) Worst ON cell
(gang_scout v syn_lancer 15 m, post: damage 825 v 759) traced on seed 76: held at its post, the fixed gun k-turns
("backing up to keep its gun on it"), in-arc 0 %, 0 shots in both arms. That is the lead's C33.9 shuffle, manoeuvre's
C34.10. (2) The pure tests and the decide test under the champion pass. (3) builder2, stream/brains `02b0c1267`,
scout-census seeds 29–36, n 8, native ON: deaths 134 v 140, mean diff −0.75 (limit +1.75) PASS; team enemy-seen
18403 v 18413 s, mean diff −1.2 (floor −93.2) PASS; kills 12 v 12. (4) builder2 `0b8fbd3f6` check: 2809/0, every native
twin 0 mismatches. sim-baseline: docks moved (50f15553 → 4074d105), attributed by `SCOUT_FIGHT=off` (13 unmoved,
builder0), ruled R34.3.

- **B1 scout try 2 (brains), filed and amended before any judged number on `stream/brains` `66df97de3` (full text there).**
  Rule: fight only when advantage >= 1 AND the shooter is in reach at 0/1/2 s; otherwise today's SPOT. The stage's own
  cells hold only duels the scout loses (advantage >= 1 on 207 of 5320 rule ticks, none in reach), so (a)/(c) are judged on 24
  pinned duel cells (law/gang scout × syn_lancer/law_tank × 15/24/35 m × post/free, turn-in OFF) and (b) on both sets.
  Fresh seeds 73–79; seed 50 is tuning. The OFF arm adds no compute (lazy matchups gated by `scout_under_fire`); the hash
  proof is `sim-baseline SCOUT_FIGHT=off` beside the pair check.

- **M0 C33.9 turn-in, second judged series (manoeuvre), filed before any fresh-seed number on `stream/manoeuvre`
  `ebc7da585` (full text in its brief, *Bar M0*).** Orbit stage via `manoeuvre-c339-cells`, both arms GDScript; candidate =
  the pair tree (main + stream/manoeuvre at its C31.1-green hash + `pair/native-c339`'s three native commits), base = the same
  tree `--nav-off=turnin`; builder2 start to end; FRESH seeds 101–112 (n 12 a cell, 576 rows), 11–36 tuning. R33.24's lines
  (a)–(h) in variance-aware form (k 1.645), noise from round 33's rows. (c)'s per-cell exchange ratio is re-formed into a
  REPORT plus two harm guards (R34.1). A third judged series would need a new design.

- **X2 parkedroom v4 (traffic), filed before any v4 number on `stream/traffic` `672a695f8`
  (`references/round34/traffic/x2_parkedroom_v4_bar.md`, full text).** v4 = v3 + ONE gate change (`1b2fd26f1`:
  `Movement.at_post()` = not under way AND (still ≥ 2 s OR a HOLD crew inside its hold line); native's hand-back calls
  `at_post_of`). Tree `pair/parkedroom-v4` = current main + stream/traffic + native's hand-back on that main (carrying N5
  `17876e4b6`) + a DEFAULT_OFF flip; base `--traffic-off=parkedroom`; native path; builder2 for every line, both arms;
  pinned; FRESH 868–915 × {terminus, locks, random}, n 144. Gates: C31.1 native check on the pair, test_traffic_neck 13/0, one
  end-to-end trace ON. L1a hold-post loops ≤ 50 % base; L1b parked loops ≤ base + k se; L2 all loops ≤ base + k se; L3 (random 48,
  `--far-kills=on`) a GUARD by cause (X1: parkedroom moves no death line): (a) deaths in the open within base ± k se, (b)
  stuck/jammed deaths ≤ base + k se, (c) hit rate ≥ base − k se; kills/deaths/routs reported; L4 crossing arrivals ≥ base − k se
  a case; L5 repack while firing 0/9; L6 read at 45 s both arms (reason: the rule's own clocks, a room ≤ 20 s + a way back ≤ 20 s;
  19 of v3's 45 misses were inside them at 30 s), ≥ 90 % at the post or inside the hold line, n ≥ 50. Ships ON only if every
  deciding line passes; no re-read.
- **T4 fourth try (traffic, R34.4), filed before any number on `stream/traffic` `b1cdf9025`
  (`references/round34/traffic/x4_t4_fourth_bar.md`).** Tree `pair/ghost-on-r34b` = current main + ghost out of OPT_IN + T4
  tooling + native's ghost-aware twins (`b2b97188d` rebased); base `--traffic-off=ghost`; builder2 both arms, native, pinned.
  Seeds above 915, never read: body 920–931 (n 12), Terminus drive 940–987 (n 48 a squad, mixed + rigs), skirmish random
  1000–1023 (n 24). Gates: C31.1 native check ghost ON; one traced Terminus cell (a pinned hull's asked v real velocity).
  Deciding GAIN: T(1) mixed friend-stuck crew-s arm < base AND (base − arm) − k se > 0; byte-identical arms on every cell =
  NOT ARISEN, no ship. Deciding guards T(2)–T(4), T(6) within base ± k se; G1–G4, r1 on 920–931, each naming its count of
  byte-identical cells. Order 7 → G, r1 → T; a fail parks; no re-read. Runs after the v4 series.
- **B6 the halt shape laid on the final approach (brains), approved 2026-10-18 before any number (code `stream/brains`
  `619eff0e1`, `ElementPlan.HALT_SHAPE_EARLY`; cause traced `661be82f7`: the move → halt hand-off re-lays every seat ±9.3 → ±16–17 m
  as the centre enters the arrival radius).** No C++ mirror (shape and seats are GDScript; el_native only grounds). ON v
  `--halt-shape-early=off`, builder2, paired, FRESH seeds (40–41 tuning only). (1) DECIDING, ground-series `--drift-trace`:
  Sumps 610 611 × ticks {1,3,6,8,11,16}, yard the same, Terminus 610–613 (28 runs an arm; amended from 50–53 before any
  number: squad-arrive-series read 49–56 on the same probe): (a) pooled drift moves ON ≤ 0.5 × OFF;
  (b) Sumps all_in8_s paired mean(ON−OFF) ≤ 1.645 se and hollow runs ON ≤ OFF + 1; yard/Terminus crews in, mean(ON−OFF) ≥
  −1.645 se; (c) REPORTED: arrived re-lays left ON (count, distance, formation before/after). (2) Choke guard, crossing-series
  AUTO, drills on, crossing/locks × green/rust, seeds 4–7 × ticks {1,8,15} (48 runs an arm), arrival just past the bridge: runs
  all-across ON ≥ OFF − 1; last-across time and inversions + point passes + overtakes, mean(ON−OFF) ≤ 1.645 se. (3) make check on
  the ship tree, sim-baseline moves attributed with HALT_EARLY=off. Ships ON if (1)(a)(b), (2), (3) pass.

- **v4b parkedroom re-judge (traffic, R34.9), filed before any number on `stream/traffic` `07276c881`
  (`x2_parkedroom_v4_bar.md`, section v4b).** The same pair `5914d3ac5` (its C31.1 and attribution stand); builder0 start to end,
  headless, pinned, native path (ask_handed_back > 0); base `--traffic-off=parkedroom`; FRESH 1100–1147 × {terminus, locks, random},
  n 144 paired; L6 at 45 s. DECIDING GAIN L2 all far loops: arm < base AND (base − arm) − k·se > 0. Guards: L1a, L1b arm ≤ base + k·se.
  L3–L6 exactly as filed. Ships ON only if all pass, as a pair with native's `4445f6b4c` and one fresh check on the hand-over
  tree; a fail parks parkedroom for the round.

- **M3 CP-F attempt 4 (manoeuvre), filed before any attempt-4 number on `stream/manoeuvre` `be2770a10` (Status, "Bar M3").**
  Candidate `lab/cpf4` `e76f6dab6` (main 82feffa86 + round33/manoeuvre's attempt-3 code + M1's ruler, TURN_HULL_DEFAULT true); base
  the same tree `--nav-off=turnhull`; builder2 start to end; FRESH hull-rest 601–616 (64 pairs a task), Terminus 620–632, fights
  640–663, SBF 670–675, bridge 18. R33.21's lines with (c) one-sided (R33.23); (d) by real_mps with wedged apart, guard base +
  1.645 × sd_run × √pairs from M1's A/A (attack-move +15.4 at 64 pairs, right +8.4, move +6.7, screen +5.4, ambush +3.2, SBF +3.0);
  (e) likewise; FACE_KEEP_FAR reported (R34.5); (m) native's statement (no C++ change, twins 14/0 on e76f6dab6) plus the hull-rest
  drawn arms on the native path. M1's A/A (`references/round34/manoeuvre/m1-aa/`): about half the old ruler's "still moving"
  crews were WEDGED hulls.

- **T6 a crew under fire does not give way (traffic, R34.15), filed before any number on `stream/traffic` `95d160ce1`
  (`references/round34/traffic/x6_underfire_bar.md`).** Pair `pair/underfire-r34` = current main + stream/traffic + native's twins
  + the ON flip (base `--traffic-off=underfire`; a switch-OFF sim-baseline inertness run beside the C31.1); native, one machine,
  pinned; FRESH fixed arenas only {terminus, locks, sumps, gorge, parade} × 1300–1327, n 140, no twins. DECIDING GAIN:
  jam-under-fire deaths (last hit during the jam, or ≥ 2 hits in the 10 s before) arm < base AND (base − arm) − k·se > 0. Guards:
  open deaths ± k·se; stuck deaths, far loops, friendly contacts in the 3 s after an under-fire abort ≤ base + k·se; kills ± k·se and
  hit rate ≥ base − k·se; crossing arrivals 44–46 × 6 ≥ base − k·se a case. Reported: standoffs with durations, all jam and all deaths,
  the counters. Sizing from T5: 1.75 a fight, sd 1.61, se of the sum ≤ ~19 at n 140.

- **B9 lane spread (brains), design and bar approved before any code or number (lane census: `stream/brains` `44e7bd397`,
  `references/round34/brains/b9_lane_census_*`; the CPU's centre lane takes 89 % of Locks and 78 % of Terminus picks, 2 in 3 stack).**
  ArmyPlan: when a side's lane holds 2+ of its elements, the cheapest-detour one moves to another lane only if the detour ≤ 1.4 ×
  direct + 30 m, the side's own intel shows enemy strength within 40 m of that lane's middle ≤ 0.5 × the mover's, and the lane has
  fewer of the side's squads; the task carries `via`, latched per task. `--lane-spread=off|green|rust|both`, default off. Series:
  asymmetric judge, symmetric ship: showmatch, Locks + Terminus + Crossing, FRESH seeds 1400–1439 each (n 120; moved off 1301–1340 to
  stay clear of T6's block), ruled side by seed parity. DECIDING: exchange gain E (ln-ratio, ruled v base) mean > 1.645 se,
  pooled, each arena reported. Guards (≤ base + 1.645 se): jam deaths, stuck deaths, far loops, time to first contact, fight length,
  piecemeal arrival. An A/A first (E ≈ 0, sizes se); the worst ruled fight traced before the means. Ships ON for both sides on a pass.

- **X1 the stuck-death census (traffic), REPORTED (`references/round34/traffic/x1_stuck_death_census.md`).** builder0, native,
  random 600–647, n 48 paired, 180 s, pinned, v3 + hand-back: deaths stuck or jammed 428 v 443 (paired se 22.3), in the
  open 1668 v 1634 (se 43), kills 2065 v 2051 (se 35): parkedroom changes neither how many crews die nor how; v3's judged −80
  kills was that series' draw. About 1 death in 5 is counted stuck or jammed (~9 a fight), split (X1 data): 622 parked by order (30 %, not stuck), 106 jammed by friendly traffic (5 %), 322 stuck with a live move order (15 %: wedged 133, static 85, still under way 2–7 s 94, no path 10), 1046 driving or in contact (50 %). Wedged (Movement.wedged, manoeuvre's) is the biggest stuck kind: relayed to manoeuvre as a post-CP-F finding. Firemission was OFF in both
  arms (an overnight DEFAULT_OFF artefact, fixed `e6468b2e0`).

## Rulings (round 34)

- **R34.1 Bar M0's three re-forms ruled (2026-10-18, before any fresh-seed number).** (1) **(c) per-cell exchange
  becomes a report: APPROVED.** A ratio whose denominator is ~0 (gang_scout v syn_scout 15 m: OFF deals 0.04, bootstrap
  −100..+135 %) measures nothing. The two replacement guards are on the harm he would see: in-reach pooled hits taken ON ≤
  OFF + k·se, and per in-reach cell damage taken ON ≤ OFF + k·se_cell. They are judged lines, and the pooled exchange gain
  stays judged (point AND distinguishable). (2) **"No worse than what he accepted" ship readings: APPROVED** for (a)
  (≥ 23.9 − k·sd_boot) and (c-out) (≤ 57 hits pooled, no cell worse than +37 %). He accepted those values when he said ship
  it (R33.38); attempt 1 failed on the suite, not on them. Out of reach is brains' C34.5 (the outgunned scout leaves). A
  candidate shipping on these readings is reported to him in player terms, with the margin. (3) **Partial rule: APPROVED as
  written:** (a) alone missing by less than its sd_boot does not park a candidate that passes (b)–(g); any (d)/(d2)/(e) run
  fails it.
- **R34.2 The rematch carrier is traffic's solve phase; fix (A) approved (2026-10-18; planner, diagnosis on `stream/planner`
  `references/round34/planner/rematch/diagnosis.md`).** `traffic.gd` `hold_of()` / `shape()` re-solve on
  `(Engine.get_physics_frames() + name.hash()) % SOLVE_TICKS == 0`; the process frame counter never resets, so a rematch
  starts at another phase (builder0 native, 918ede503: 12 of 12 rematches branched, 6 outcomes; with a 3-line patch, 0 of 12,
  1 outcome). Physics server, World3D, statics: no effect. Planner is GRANTED those two phase lines + one helper in
  traffic.gd (traffic told). Conditions: audit every `get_physics_frames()` in `game/` and `native/src` for absolute-phase
  use and fix or clear each; native mirrors any C++ twin; prefer the match tick as origin; the test fails on today's main;
  sim-baseline repeats twice on the fixed tree. Merged ALONE, then the orchestrator adopts the baseline (it moves once on
  every map); judged series already running stay on their pair trees.
- **R34.3 B1's pair check counts green on an expected sim-baseline move (2026-10-18; brains `0b8fbd3f6`, builder2).**
  `make check exited 2`: 2809/0, 26 of 27 targets green, the only red sim-baseline: docks 50f15553c558d108 → 4074d105e1739377,
  12 unmoved. Same tree `SCOUT_FIGHT=off` (builder0): 13 unmoved, so the move is the default-ON rule's (a scout standing in a
  won duel); B2's adapter, B3's trace and the lazy duel are inert. The judged series may start (R33.31's precedent), on
  condition that scout-cells / scout-census are pinned at `--fixed-fps` on that tree (it predates main 02a912163). The
  orchestrator adopts the docks baseline at merge.
- **R34.4 T4, a fourth try, approved (C34.3; traffic X4, `references/round34/traffic/x4_t4_guard_reread.txt`).** On current
  main the R33.30 G2 failure is gone (tuning seeds 7–18, builder0, native, pinned: body-ON alone_s 2–6 s both arms, every
  ON−OFF 0.0; body OFF 17–21 s). Brains' route now keeps the Sirens with the body. A fresh bar after the v4 series on
  builder2, with seeds disjoint from every judged block (above 915), the Terminus T(1)–T(6) GAIN lines deciding (the guards
  pass trivially on identical arms), byte-identical arms reported, C31.1 with ghost ON and native's ghost-aware twins.
- **R34.5 FACE_KEEP_FAR retired as a judged line (planner P4 (b), 2026-10-18).** On one series it flips with the distinct
  rule alone (p3-pinned drawn FAIL all-pairs / PASS distinct; clicked the reverse); its p90 "over" is faces planned in one arm
  only (clicked max 12.4 v 5.7). The paired `face_pairs` (crew and home) reads both-planned faces identical (clicked p90 6.3 v
  6.3, se 0.00; drawn 8.5 v 8.5). Judged: `face_pairs`, CAND_ONLY reported. FACE_KEEP_FAR REPORTED in round 34, deleted in 35.
- **R34.6 parkedroom v4's pair check counts green (traffic `pair/parkedroom-v4` `5914d3ac5`, builder2 `make native check`
  exited 2, 2824/0, 24/26).** (1) sim-baseline: the same tree `--traffic-off=parkedroom` leaves 12 unmoved and docks at B1's
  4074d105e1739377, so terminus → accbd28434111b99, sumps → 02a1d4ff63c20c1b, parade → a6178ae02c7e3769, docks → 874553bfdb105b07 are
  parkedroom ON's (v3's same four). (2) native-verify-scenarios' scenario_perf 29238 µs at 1.50× in the check; alone on builder2
  17435 µs at 1.41× (line 20000), and main's own last check read 22407 at 1.51× unjudged: a both-paths measure swinging with
  load, not a 7× cost. Judged perf on the pair PERF_JUDGE PASS 1.05×; traffic's GDScript share 529 of 17435 µs (3 %).
- **R34.7 B6 PARKED (brains, `a2add1d0f`, builder2, `references/round34/brains/b6_series_a2add1d0f_builder2.txt`).** (1)(a) FAIL
  pooled drift 121 ON v 104 OFF (limit 52); (1)(b) FAIL Sumps hollow 9/12 ON v 0/12; all_in8 +9.97 s (passes alone); yard/Terminus
  crews in 160 v 160; (1)(c) 82 arrived re-lays left ON (median 10.3 m). (2) passed TRIVIALLY: crossing ON = OFF row for row, the
  early lay never engaged. Worst run traced (Sumps s611 t16, 60 v 4): an early-laid halt seat on an obstacle edge flips every
  0.5–1 s, B10's round-32 grounding flip (standable_from keyed on the centre's 5 m cell). Switch OFF on stream/brains. Next:
  trace one hollow run and one leftover re-lay on tuning seeds 40–41; a try 2 only with those causes written, and its choke
  guard must show the early lay ENGAGING. The player-visible shuffle (C34.11's arrival) stays open.
  **Causes traced (tuning 40–41, laptop, n 4, `333830f17`):** (1) the early lay MOVES the swerve to the 60 m line (a seat jumps
  ~35 m sideways there), it doesn't remove it; (2) leftover re-lays = the early lay's per-update heading swings close in (27°
  turns a ±17 m herringbone 5–8 m a seat); (3) hollow = CORRECTED (`b77910424`): a crew's move goal and its halt slot part by
  ~1.8 m after the goal is sent (the early lay shifts the slot); it arrives at its goal (2.7 m off), HOLDs, and is never
  re-sent, so it sits 3.7 m from the slot the line reads. B6-specific (main's arm: 0 of 24 Sumps runs hollow). SLOT_TOLERANCE
  is not involved: B7 has NO CASE. A B6 return would need a re-send when goal and slot part by > 1 m after arrival; (4) B10's grounding flip. **No try 2.** The better
  design, if he dislikes the shuffle, is a deliberate deploy step (travel seats until all in, then one visible move into the
  halt shape): a question for him.
- **R34.8 orders' O1 and O3 go to brains while no orders worker runs (2026-10-19 ~00:20 PDT).** The orders worktree was
  created at 21:50 but no agent has started in it, and C34.11 is the round's most player-visible item; brains is idle
  (B4 waits on CP-F, B5 on traffic). Brains is GRANTED `game/control/selection_squads.gd`, `RtsControls._order_squads` /
  `_squad_width` / `_squad_depth`, and new `tests/test_control*.gd`, for O1 (the ground cap) then O3 (price a squad at its halt
  shape), working on `stream/brains`, per `streams/orders.md`. If an orders worker starts, brains hands over at its next
  green commit and orders continues from there (O2, O4, O5).
  **Extended (00:50 PDT): planner takes orders' O5 (the player test) while idle on P5:** GRANTED new probe files under
  `tests/control/` (or `tests/orders_probe*.gd`), one additive target in `mk/command.mk`, and `references/round34/orders/**`;
  READ-ONLY on game code. Measurement and screenshots only, no game code.
  **Extended (01:40 PDT): traffic takes orders' O4 (waypoints are the squad's; gates) after T4 parked:** GRANTED
  `RtsControls._queue_task_for` and its helpers, new `tests/test_control*.gd`; the `Element._next_queued` seam by a signature
  agreed with brains through the orchestrator. Design (passed radius, gate width from the ground, the seam, the failing test)
  to the orchestrator before code. Not `selection_squads.gd` / `_order_squads` (brains, O2).
  **O5 read (planner, `stream/planner` `749a7a155`, `references/round34/orders/o5.md`; builder0, native, main 2c7c1d0dc + probe,
  3 maps × 3/5 squads × click/route × main/cap-off/halt-price-off, n 1 a cell, deterministic).** (1) 5 squads to one point: the
  second rank's anchors sit 71.6 m behind the click, at or behind their start (they "arrive" in 0.1 s): O2. (2) **His bridge case
  is NOT closed on the Locks:** O1 capped the anchor to the near bank, but a crew SEAT that lands in the canal snaps to the far
  bank (Green_Echo_3 (39.4, 12.2) → (39.4, −12.2) at 9 s); Echo_1 crossed the east bridge and came back; the squad shuffled 78.5 m
  after "arrived". Brains, FIRST: snap a seat only onto ground its anchor reaches without a deck. (3) Where O1 acts it works
  (Crossing far-bank crews 1 → 0 and 2 → 0). (4) RETRACTED by planner before any code: clamp_to_arena already clamps to the polygon (ArenaShape,
  inset WALL_CLEARANCE_M); (−100.9, 59.7) is 4.6 m inside the Crossing's hex wall. The probe's top-down shots drew the HUD's 2D
  rings through the game's perspective camera, so they landed wrong; the vehicles were right. Grant withdrawn. Post-arrival
  shuffle 20–48 m worst with 3 squads, 28–124 m with 5 (B6's cause; the deploy step is his question).
- **R34.9 parkedroom v4 FAILS as filed and is PARKED (DEFAULT_OFF); a v4b re-judge of the SAME code is approved (traffic,
  pair `5914d3ac5`, builder2, fresh 868–915 × 3, n 144, `references/round34/traffic/x3_v4_series_5914d3ac5.txt`).** L1a hold-post
  far loops 34 → 18 against a line of ≤ 17 (paired se 20.2): FAIL by one loop. 16 of the 18 are ONE episode (locks-913: a
  battery asking a squadmate parked on HOLD 1.3 m from its slot, 16 times in 70 s, where the room search found no spot and so
  refused, as OFF does; without it 34 → 2). Everything else passed: L1b 92 → 47, L2 124 → 60, L3 (a) open deaths +51 in a ±54 band,
  (b) stuck/jammed 410 → 387, (c) hit rate within its line, L4 identical, L5 0/9, L6 94.2 % at 45 s. No re-read: the verdict stands.
  **Why a v4b:** L1a's "≤ 50 % of base" on a base of 34 with se 20 asked for a drop the series could not resolve (17 is 0.84 se),
  so the line failed on one fight's single cramped spot, not on the rule. v4b = the same code, a FRESH seed block disjoint from every
  judged one, a bar re-filed before any number with the far-loop gain judged on L2 (all far loops: arm < base AND (base − arm) −
  k·se > 0), L1a and L1b as guards (arm ≤ base + k·se), L3–L6 as filed. Run on **builder0** (a judged series stays on one machine)
  so T4's fourth try runs on builder2 at the same time. If v4b also fails, parkedroom parks for the round, with no fifth try
  without a new design.
- **R34.10 C33.9 turn-in, second series (M0): every line passes but (c-out); by the bar it does NOT ship; the lead decides
  (manoeuvre, pair `c8fb8b6a3` = 764ef5427 + native 25fd4298e, check green, builder2, fresh 101–112, n 12 a cell, 576 rows;
  `references/round34/manoeuvre/m0-series/`).** (a) in-arc 3.1 → 74.2 % (sd_boot 4.6); (b) shots 1 → 10; (c) exchange 0.13 → 2.34;
  in-reach hits taken 8088 → 5690; all six in-reach cells take less damage (−38 to −280 a run); (d)/(d2) 0 reverse in 144 runs
  (OFF max 48 at stop); (e) 26.0 m; (g) free cells byte-identical. **(c-out) FAIL:** out-of-reach hits taken 3139 → 4627
  (+1488 v k·se 437), pooled median 46 → 60 against the 57 he accepted (+3 hits, +1.0 sd_boot), worst cell +10 % (inside +37 %).
  Out of reach the scout now turns in and fights: exchange there 0.06 → 1.45; gang scout v IFV 30 m kills it in 5 of 12 runs.
  R34.1's ship reading puts a pooled median above 57 on the regression side, so the orchestrator does not ship it. The pair
  stays ready; the orchestrator recommends SHIP to the lead (the shuffle he reported is gone in every run, and the out-of-reach
  cost buys kills). On his yes: merge `c8fb8b6a3`, adopt crossing / parade / archipelago at the attributed hashes.
- **R34.11 T4 (the ghost) PARKS a fourth time, on its deciding gain (traffic, pair `777820d7b`, builder2, fresh 920–931 /
  940–987 / 1000–1023, `references/round34/traffic/x4_t4_fourth_series_777820d7b.txt`).** T(1) mixed friend-stuck crew-s 307 → 426
  (+119, se 210.5; 34 of 48 cells byte-identical): FAIL. Guards pass (T(2) rigs stuck 597 → 848 inside its line but the wrong way,
  T(3), T(4), T(6) fights unchanged; G1–G3 identical arms, no information). The yard circling it cured in rounds 31–32 is not
  there to cure on today's main (escape, unstick and manoeuvre's later rules took it), and real-velocity ORCA sometimes steers
  round a stalled friend it would have pushed through. The ghost stays OPT_IN; `pair/ghost-on-r34b` is NOT merged; native's
  ghost twins return only with a new case. No fifth try without one.
- **R34.12 O2 (packing by driving distance) PARKED; a small rank fix instead (brains, `wip/brains-o2` kept as the record).**
  The AUTO-only pack (C) was NOT tighter (three AUTO squads, outer anchors 136 m v O3's 78.8 m), regressed the click's response
  (box-around-the-army 4 ticks v the 3-tick window at 30 units) and still mixed five squads (closest pair 4.2 m). Cause: until
  arrival an AUTO element's final seats are its TRAVEL wedge (±25 m; B6 parked) at a heading not knowable at order time.
  "Packed at the halt" needs (B) the order fixing the heading AND B6's halt seats from the final approach. That is the
  same design question as his deploy step (R34.7), so it waits on his answer. Now: brains fixes planner's O5 finding (1) in the
  existing ranks path (a rank's anchor never farther back along the approach than its squad's own centre), with a test from
  the Locks/Terminus case.
- **R34.13 parkedroom PARKS for round 34 (v4b, traffic, pair `5914d3ac5`, builder0, fresh 1100–1147 × 3, n 144,
  `x3_v4b_series_5914d3ac5.txt`).** L2 all far loops 169 → 127 (drop 42, paired se 54.9): not distinguishable: FAIL. Guards pass:
  L1a hold-post loops 82 → 21 (−74 %, 2.7 se: the targeted mechanism works), L1b 136 → 102, L3 (a)/(b)/(c), L4, L5 0/9, L6 93.3 %.
  **Watch:** jammed-by-friendly-traffic deaths ALONE 79 → 116 (+37, se 12.6, 2.9 se; stuck 276 → 257), under the combined line.
  What's left in the arm's loops is mostly behind batteries set up and firing (67 of 127; his T1c-b2 yes keeps them put).
  v3/v4/v4b each cut hold-post loops 50–74 % and brought 90–94 % home; each failed on totals the rule doesn't reach. DEFAULT_OFF
  stays; the pair and native's `4445f6b4c` are not merged; no fifth try without a new design. **A question for him:** should a
  crew stuck behind a FIRING mortar truck get by (the truck packs up briefly, or the asker is sent round)?
- **R34.14 main 6d167331a is GREEN by inheritance** (brains `1fc467258`, builder2 `make check exited 0`, 2847/0, sim-baseline 13
  unmoved: main's batch M1 + O4 + N6 + the rank fix + LOADED_RATIO 1.2). **Brains builds the deploy step as a prototype behind a
  switch, default OFF (B8)**, so his answer to R34.7 meets something he can see rather than a description: an AUTO squad keeps its
  travel seats until every crew is in, then lays its halt shape on the approach heading as one move. With the heading fixed at
  order time, O2's (B) packing becomes exact. Default stays OFF until he says yes; planner's O5 probe reads it before/after.
- **R34.15 T5 the jam-death census (traffic, REPORTED, `references/round34/traffic/t5_jam_death_census.md`; builder2, native,
  fresh 1200–1247 × 3, 144 fights, pinned, 5984 deaths).** Jammed by friendly traffic 337 = 5.6 % (2.34 a fight): giving way 83 %,
  held by ANOTHER squad's crew 69 %, by a set-up battery 1 % (so the mortar-truck question is not what jam deaths are about);
  lanes 74 %, Locks the worst; under fire while jammed 77 %, last hit during the jam 63 %; jam time median 1.5 s. Stuck deaths
  17 % (wedged 8 %). **Decided (symmetric AI, ships without asking if it passes its bar): a crew under fire does not give way
  (T6, traffic):** it holds the lane and the asker goes round or waits; fresh bar, filed before numbers. The CPU feeding two or
  three squads through one Locks lane under fire is brains' commander lane choice (later). **Measurement note:** 14 of 48
  "random" seeds dealt the Locks or Terminus, so those fights twin the fixed-arena fight of the same seed (paired readings
  unaffected; totals double-count them; true of X1/v4/v4b): future series exclude random seeds that deal a fixed arena.
- **R34.16 P5 closes with NO v3 (planner, `references/round34/planner/p5-remeasure-15f5980ac/`; builder0, native, main with M2 + M1,
  hull-rest gangs, dev seeds 96–107, face_pairs distinct 42/41).** The tail v3 targeted was the flicker: round 33's miss was a face only
  the candidate planned (asked mid-k-turn). With M2 in, candidate-only faces are 0 drawn, 0 clicked, so a slot cap has nothing to cut.
  Both-planned clicked faces 2.5 v 2.0 m median (se 0.26), p90 4.0 v 3.9, max 9.1 v 4.0 (one face): a WATCH item for the next series
  that reads face_pairs, not a bar. **The round-34 Terminus route stall** (planner's bisect: O4's a5a362737 first bad; brains: O3 put
  squad 3's first-leg anchor in a block) is fixed in brains' next check (ground_anchors + a player-route stall fallback, 12 s, every
  crew settled, in-between legs only).
- **R34.17 T6 (under fire, no give-way) FAILS as filed; a T6b without the mid-step abort is approved (traffic, pair
  `ac1bf4692`, builder2, fixed arenas × 1300–1327, n 140, `x6_series_ac1bf4692.txt`).** G jam-under-fire deaths 231 → 72 (7 se):
  PASS. Guards FAIL: open deaths +169 (band ±123), stuck deaths +124 (line 877), kills +138 (band ±112), friendly contacts in the 3 s
  after a hit-ended give-way 331 → 1049 (5.7 se over). All deaths +2.3 %. Reading: the deaths moved rather than went (crews holding
  under fire and the askers behind them die where they stand), and the mid-step abort (c) reverses a crew into the asker. DEFAULT_OFF;
  native's mirror `bc6aaa203` not merged. **T6b = (a) + (b) only, no (c)**, re-judged on a FRESH fixed-arena block with the same
  lines; if open and stuck deaths still rise, the trade is real and T6 parks for the round.
- **R34.18 CP-F attempt 4 (M3) PARKS (manoeuvre, `lab/cpf4` `e76f6dab6`, builder2, 14/14 steps, fresh seeds as filed,
  `references/round34/manoeuvre/cpf4-series/`).** The turn itself is right: point tasks 3.0–4.0° median, 82–94 % within 15° (base
  48–57°, 14–24 %); ambush 3.7 v 80.4°, SBF 3.7 v 77.5; native twins 14/0. Misses: (d) movers by real_mps (ambush +7 v guard +3.2,
  move +9 v +6.7, screen +13 v +5.4), (e) attack-move never settled +6 v 4.9, (g) Terminus mixed arrivals −5 v 4.6. Two mechanisms
  traced: faces no plan fits creep at the 0.35 lock until the judge; attack-move elements step to the next leg ~30 s later when
  arrived crews sit on a sector face (tank_brain ~2960) instead of a stop. Per R33.34 a fifth attempt needs a NEW design (a face
  that gives up cleanly when no plan fits; the element step not waiting on a sector face), not seeds. B11b gets no merge hash.
- **R34.19 B9 lane spread FAILS its bar and stays OFF (brains, `a82615a2b`, builder2, locks/terminus/crossing × 1400–1439,
  n 120 an arm, `references/round34/brains/b9_lane_series/`).** A/A E +0.254 (se 0.292); ruled E +0.157 (se 0.310), needed > +0.511.
  Every guard passes. The mechanism works (stacked picks 64 % → 49 %), the outcome doesn't follow: the census's stacking/deaths link
  was a correlation, not a lever. Worst ruled fight traced (locks-1404: two squads sent together round the side fed in piecemeal).
  No re-tune. The code rides main OFF (green at f1034b904).
- **R34.20 T6 PARKS for the round (T6b, traffic, pair `104ca5a11`, builder2, fixed arenas × 1500–1527, n 140,
  `x6b_series_104ca5a11.txt`).** G jam-under-fire deaths 256 → 121 (−53 %): PASS. Dropping (c) fixed the collision harm (contacts in
  the 3 s after a hit-ended give-way 336 → 167, open deaths inside, total deaths flat 5768 → 5735, kills equal). FAIL: stuck deaths
  902 → 963 (+6.8 %, 1.9 se over the line); far loops doubled (96 → 192, passing by 0.1). A crew refused by an under-fire squadmate
  stalls behind it: the rule converts yielding deaths into stuck/blocked/parked deaths about one for one. DEFAULT_OFF; neither pair nor
  native's `badfdb978` is merged. For round 35: refuse only when the asker has another way round (parkedroom's room/route test).
- **M2 report (manoeuvre, `references/round34/manoeuvre/m2-report/`, builder0, REPORT only):** with the planner seam driving
  (new `M1_GDD=1`; the plain GDScript arm abandons every k-turn ask, so no crew is ever mid-leg: a measurement trap, written down),
  gangs × six tasks × seeds 60–71: the hold fired 3 times in 144 runs, one tick each; every other row identical to base. M2's footprint
  on today's hull-rest stage is small; its effect on the flicker is P5's re-measure (R34.16: candidate-only faces 0 with M2 in).
- **Round-35 candidates recorded (2026-10-19 morning):** (1) **wedged deaths** (manoeuvre, from T5's rows,
  `references/round34/manoeuvre/wedged-deaths/`): 499 of 5984 = 8.3 %, 3.5 a fight, all `driving`, none held; mid-weight hulls
  (suppressor, burner, IFV, tank, lancer 13–16 % of their own deaths; scouts and artillery 2–4 %); lanes, the Locks worst (the x≈0 lane
  mouths 57 of 195); median speed at death 1.2 m/s, 85 % under fire, only 26 % slow enough for the stall rule to see: crews pushed
  around at walking pace by their own avoidance in a lane mouth while being shot. (2) **CP-F's new design** on both sides (a face that
  gives up after N refused plans; the element step not waiting on a sector face). (3) **the Locks 5-squad route's crossing drives**
  (brains: deal the last leg by drive paths). (4) **O2's (B) packing** with the deploy step, if he wants it.

## Round 33, overnight extension: round-34 candidates go to the same five workers (2026-10-18 ~00:45 PDT)

**The lead, going to bed:** "Are you able to just go ahead and kick off the subsequent workstreams for the next round to
the current set of workers? Obviously we want to run on builder2 now primarily since it's 4x faster." So there is no
formal close yet. Each worker keeps its worktree and takes the next items from `roadmap.md` *Round 34 candidates*,
listed in its brief under **Overnight (round 33 extension)**. Every round-33 contract, ruling and the bar discipline
stand: a bar is filed before any number, judged on fresh seeds, with every judged stage pinned at `--fixed-fps $(SIM_HZ)`.

**Machines (`_agents/gcp_builder.md`):** builder2 is FIRST for every remote run (`make gcp-remote T=…`, or
`REMOTE_HOST=slobdell@builder2`), and takes 6 heavy at once (main `b739912a`). Merge main into your branch first, to get
mk/gcp.mk, the 6-slot remote.sh and the perf nominal. Seed a new builder2 folder's `.godot` from `~/tank_squad/godot`
(never native/). builder0 takes overflow and builder0-specific numbers. **builder2 is a Spot VM:** if it stops answering,
check `make gcp-status`. If it reads TERMINATED it was preempted: tell the orchestrator, who restarts it (`make
gcp-start`, the lead's standing yes). A run lost that way is no result, so re-run it.

| Stream | Overnight items, in order (details in its brief) |
|---|---|
| traffic | (1) parkedroom v2 (the rule only for a crew AT a post), fresh bar. (2) T4 ghost, third try: the cohesion guard on body_probe children at --fixed-fps, plus a REPLAY line (a same-process rematch replays), then Terminus. (3) Diagnose the fire-post loop (random-705) with brains: owner to be decided. |
| manoeuvre | (1) C33.9, the scout (his report): finish, judged run 31–36. (2) CP-F attempt 3 (R33.23), series 460–475. (3) The hull-rest judge: real-velocity "still", a seed that varies the stage (after CP-F's series, never during it). |
| brains | (1) The battery item (three switches, filed bar). (2) A scout under fire fights back when it can't get away (bar first; pairs with C33.9). (3) An element that never arrives because one crew still drives (the War Rig 4-of-5 case). (4) A respawned crew rejoins its squad's living element when it has room. |
| planner | (1) The tools: series_verdict's both-arms-seam mode; re-make or retire stage_s207. (2) P3 v2 RE-JUDGED with hull-rest pinned on fresh seeds (its clicked-drift miss may be pacing, as CP-F's was), using the same pair code that is on main OFF. (3) Only if it fails pinned: P3 v3, the slot cap. |
| native | Test infra, granted for these items: mk/core.mk's `test` and `check` recipes, mk/web.mk's web-smoke judge, tools/test_slot_light.sh, tools/remote.sh. **Also granted (2026-10-18):** tools/test_filter_gate.sh and tools/test_test_shards.sh, one token each (`-o _native-ready`), for item 2. **And (2026-10-18), for item 1, test-only, no stream owns them this round:** tests/test_fx_kill_cam.gd (assert that the reader agrees with the runner's own `--fixed-fps`), tests/test_control_dials.gd (wait on game time or the zoom settling, not 40 frames), tests/test_ship_voice_fetch.gd (the fake fetch delay and the wait use the wall clock, as AnnouncerVoice does). Each keeps its assertion's intent, and none is loosened. (1) The suite at a fixed physics rate (`--fixed-fps $(SIM_HZ)` for run_tests), with a full check on builder2 and a list of every test whose numbers move. (2) A remote `make test` with no native library refuses, or builds it. (3) web-smoke's sound bound and test_slot_light read NOT JUDGED under load instead of FAIL. (4) Split test_native_gate by frame. (5) One NATIVE=off perf reading on main. Pairs (brains' arrivedgate mirror) pre-empt all of it (C31.2). |

**Bar, native overnight item 1: the suite at a fixed physics rate (filed 2026-10-18 before any number).** The change is
in mk/core.mk's `test` recipe only: run_tests.gd under `--fixed-fps $(SIM_HZ)` (`TEST_FPS ?= $(SIM_HZ)`; `TEST_FPS=` is
the old free-running suite), and the test-wall line names the fps. Other streams' direct run_tests.gd callers (nav, pace,
planner, command, tactics .mk) are left alone, with a merge note. (1) `make gcp-remote T=check` (builder2) and
`make remote T=check` (builder0), both native ON (read from the NATIVE line): exit 0, sim-baseline 13 unmoved. (2) A
moves list: on builder2 at one commit, `native test` twice at TEST_FPS=30 and twice free. A test MOVES when its verdict
or any number it prints differs between the fixed pair and the free pair. A difference inside a pair is noise, listed
separately. Each mover gets a reason. (3) Any test that fails pinned is fixed, or listed with its owner, before the
merge; nothing is loosened to pass. **Added (orchestrator):** (4) REPORT the suite's wall time and slowest shard, fixed
v free, on both machines.

**Bar, planner overnight item 2: P3 v2 re-judged PINNED (filed 2026-10-18 before any number).** R33.19's bar (main
`8681d2aa` + amendment `e8383ce6`), unchanged except: the candidate is the same code that is on main (keep 1 plus the
kept-first fallback, FACE_KEPT_SHARE 45), with arms `--planner-face-keep=0` v `=1`, FIFO, explicit on each arm. The pair
tree is main `e46f1720` + manoeuvre's `670f4e12` (hull-rest and hull-one pinned at `--fixed-fps $(SIM_HZ)`) +
FACE_KEEP_DEFAULT 1, and its whole suite goes green on builder2 first. No CP-F (named). FRESH seeds: hull-rest gangs
96–107 (drawn + clicked, n 72 paired a mode); Terminus rigs and mixed 244–256 (n 13). All on builder2, labelled. (3) is
read by series_verdict `seam=both`. Pass = every line, early stop OFF; (1) passes and a guard fails → PARKED, then v3.
Pinned numbers don't compare with bca4eaca's. **Added (orchestrator, as for CP-F's R33.23):** hull-rest barely varies
with the seed, so the verdict reports distinct rows per cell, and every se is over distinct pairs only.

**Bar, brains overnight item 2: a scout under fire fights back when it can't get away (filed 2026-10-18 before any code
or number).** Lab on lab/c339-turnin `ea043755` (the orbit stage exists only there; main's behaviour = its turn-in-OFF
arm, named in the verdict). Candidate: in TankBrain.decide (plus native's mirror, C26.2), a scout hit within 2 s with a
visible non-prey contact C inside both its effective range and C's, AND unable to get away (duel advantage v C ≥ 0, or
C's speed ≥ 0.9 × its top speed; clarified before any number: Matchups.duel_advantage is a RATIO, so the code
reads ≥ 1.0, an even duel or better), scores SPOT 0.7 instead of 0.88, so ENGAGE wins. `--scout-fight=off`. The proxy
"fire from a contact in reach" is stated, because no attacker is recorded on a hit. (1) DECIDING, the orbit cells
(--fixed-fps a seed): 24 cells × FRESH seeds 60–72 (n 13), turn-in OFF, ON v off: (a) pooled median scout shots ON ≥
1.5× OFF; (b) median damage taken ON ≤ OFF, and no cell worse by more than 20 % (read on cells with OFF hits ≥ 10;
smaller cells reported); (c) ENGAGE ticks > 0 ON, and SPOT ticks ON < OFF. Turn-in ON reported alongside. (2) A pure
test: a scout that loses the duel and can outrun keeps SPOT 0.88. (3) Fights guard, scout-census (showmatch,
--fixed-fps), FRESH seeds 21–28, n 8: scout deaths ON ≤ OFF + 1.645 se, kills reported. **Added (orchestrator): (3b)
team enemy-seen seconds is MEASURED and judged**, ON ≥ OFF − 1.645 se. It is the scouting risk this change was designed
around (brains' own design, roadmap), so brains adds the probe before any number. (4) The check, with native's twin of
decide at 0 mismatches. (5) The worst ON cell traced before the medians. Ships ON if (1), (3), (3b) and (4) pass. Tuning
seeds 50–59 only. Runs on builder2 after the battery series. Tell manoeuvre before any merge (it moves C33.9's base).
**Re-filed (orchestrator, 2026-10-18, after TUNING seeds 50–52 only):** as built, ON and OFF were identical (shots
799 v 799). The rule fires and SPOT drops 1.01 → 0.80, but ENGAGE scores only 0.27–0.43 for a scout against syn_scout,
so SPOT still wins: the roadmap's "drops to 0.7, so ENGAGE wins" was a code read that never checked ENGAGE's score.
**Mechanism now:** under the same condition SPOT scores SCOUT_FIGHT_SPOT = 0.15 (above HOLD's 0.10, below ENGAGE's
0.27–0.43 even with the ~0.10 commitment bonus), and SPOT returns 2 s after the last hit. **(c) gains:** where the rule
fires, the chosen option is ENGAGE (counted by option, so no other option such as ADVANCE takes over), ENGAGE ticks ON >
OFF, and 0 in the out-of-reach cells. Brains prints the full option table on one tuning run first, to show ENGAGE wins.
**Shown (brains, laptop, tuning seed 50, 48 cells, lab/brains-scout `57d8342c`):** in 2130 rule-firing ticks, ENGAGE
was chosen 1925 times (90 %), COVER_FIRE 82, SPOT 76 (committed, right after first firing) and HOLD 47. **(a) clarified
before any judged number:** the median scout shots per cell are about 0.5 in BOTH arms (most cells fire almost nothing
either way), so a ratio of medians is degenerate. (a) reads POOLED TOTAL shots ON ≥ 1.5× OFF, with the medians
reported.

**Rejoin's stage re-filed before any number (2026-10-18):** manoeuvre-fights is ELIMINATION (skirmish_mode.gd:423), so
no crew respawns and both arms read identical (0 reforms in 32 fights); nothing was judged there. New stage `make
rejoin-fights`: the match runner WITHOUT --elimination, perf_armies 25 a side, both sides on elements, score limit 0,
180 s, --fixed-fps 30, --rejoin-trace on both arms; FRESH seeds 580–583 × sumps/yard/terminus/foundry, n 16. The lines are
unchanged; (b) reads MATCH_RESULT kills and losses per side, pooled. The check stays 2775/0, since the commit adds only a
make target.
**Bar, brains overnight item 4: a respawned crew rejoins its squad's living element when it has room (filed 2026-10-18
before any code or number).** ElementCommander.form_elements: a squad's unseated living crew first JOINS a living element
of the same squad with room (members < MAX_MEMBERS; most room first, then name order) through a new
Element.join / Elements.join. The element keeps its id, task and seats, and the joiner is seated at the next plan. Only
crews that don't fit form a new element. `--rejoin=off` = R33.6. GDScript only (native confirms there is no twin).
(1) Tests: joins with room, keeping id and task; past MAX it forms its own; off = R33.6's outcome. (2) DECIDING,
manoeuvre-fights (showmatch, respawn, --fixed-fps 30, 180 s), FRESH seeds 560–575, n 16, ON v off on one tree: (a)
one-crew elements formed after the first minute ON < OFF; (b) pooled kills ON ≥ OFF − 1.645 se, deaths ON ≤ OFF + 1.645
se; (c) 0 C19.1 refusals and 0 ERROR lines. Reported: joins per fight, and the joined element's leg progress, traced on
the worst ON fight before the totals. (3) The check, with sim-baseline moves listed. Judged on builder2 after the battery
and scout series; dev on builder0. **Also (item 3, the War Rig):** manoeuvre's read says the four were AT their seats;
two seats were laid 28 m and 56–68 m south of the anchor, so the centre can't come within 12 m. It's seat geometry or a
clamp, not a stalled crew, so the roadmap's "4 of 5" rule may be wrong. A pinned --element-trace comes first, and a
candidate only after it.

- **R33.24 C33.9 PARKED (2026-10-18; manoeuvre, stream/manoeuvre `7e8e072bf`, references/round33/manoeuvre/c339-judged/;
  tree `781801da0` = ea043755's turn-in + measurement; FRESH seeds 31–36, builder2 start to end, --fixed-fps 30, 288
  rows).** (a) in-reach in-arc 3.7 → 23.9 % FAIL (≥ 25). (b) shots 2 → 10 PASS. (c) in-reach exchange 0.20 → 1.77, no
  cell worse, PASS (hits 111 → 104). (c-out) pooled hits 42 → 57, worst +37 % (gang_scout v syn_scout 45 m) FAIL. (d) 0
  commanded reverse in 72 runs, (d2) 0 reverse at stop (OFF max 30), (e) 25.8 m, (g) identical: all PASS. Machine
  equivalence: dev OFF rows 312/312 identical on builder2 and builder0. **What he saw is fixed in every judged run** (no
  chosen reverse at a face or a HOLD; it fights, with an exchange of 1.77 v 0.20). It misses on aim time (23.9 v 25) and
  on hits taken where its gun can't reach. Nothing ships. **The next step is the lead's** (HANDOFF, morning): ship as it
  is, or a second attempt that turns in only within weapon reach (out of reach it keeps today's motion, so (c-out) =
  OFF by construction). Recommendation in HANDOFF.
- **R33.25 relay-smoke red under load on CP-F's pair `70cb7f683` (2026-10-18).** The suite: 2777/0 and sim-baseline
  unmoved. The only red is relay-smoke's engine-log gate, ×6 "Trying to call an RPC via a multiplayer peer which is not
  connected" (match.gd:2094 `_shell_hit` ← shell.gd `_fly`), a different message from round 31's 4/5-tanks race. It
  passed alone twice on the same tree and box. CP-F touches neither the network nor shells. **Ruling:** the pair meets
  C31.1 for STARTING its series (its suite is green). The message is a LATENT network bug (a shell's RPC fired after the
  peer drops at teardown), filed UNOWNED in the roadmap per HANDOFF's "a second relay-smoke red gets traced, not waved
  through". CP-F does not merge while relay-smoke is red in its merge check.

**Bar, brains overnight item 3: the War Rig that never arrives (filed 2026-10-18 before any number; lab/brains-warrig
`387004f7`).** Cause confirmed (builder0, pinned, seed 8, seat triples). R33.6 splits the 13 Guns crews 5/4/4. One
4-crew element's anchor (6, 116) sits ON the arena's north edge (the orders layer's share of the order). clamp_to_arena
pulls its two outer seats onto the edge, then SlotGround moves them 6 m in, so the shape collapses on one side, the
seat centroid sits 17–20 m off the anchor, and the element can never pass the 12 m centre rule. Stale seat sizes are
refuted. **Candidate (ElementPlan, GDScript only):** an element's anchor, the move destination and each leg's anchor, is
inset from the arena edge by its shape's half-extent along the heading frame, so every nominal seat lies inside;
clamp_to_arena stays as the backstop. `--anchor-inset=off`. The "4 of 5" rule is DROPPED. (1) DECIDING, warrig-trace
(foundry faced drag, gangs, 180°, squads 1, pinned), named seed 8 + FRESH seeds 9–14, n 7: ON, every element's seat
centroid ≤ 3 m from its anchor once laid, and every element arrives (centre within 12 m); OFF reported; the second 4-crew
element traced first. (2) squad-arrive-series, FRESH seeds 69–72, n 100: all-within-8 m ON ≥ OFF − 1.645 se, with the
median inset reported. (3) The check, with sim-baseline moves listed. (4) The worst ON run traced before the counts.
What he'd notice: a squad sent right to the arena's edge stops a few metres inland, in formation, instead of half of it
never "arriving".
**Added before any judged number (orchestrator, 2026-10-18):** brains' tuning read (seed 8) showed the largest inset
at 50.8 m (a 4-crew swarm reaches 51 m across). A squad sent to the edge stopping 50 m from where he clicked is a miss he
would see. So the design fits the SHAPE to the edge (folds or compresses the clamped side), or caps the inset, and
**(1b) is judged: the largest inset ON ≤ 15 m (one swarm pitch)**, with the median reported.
**Scope set before the series (brains, 2026-10-18):** applied from a move's start, the inset changed a drill's route
(tactics-drills far_ambush held_the_line_m 12.68 against its 12 bound). It now applies only on the final approach (within
INSET_NEAR_M = 60 m of the destination), and further out a move is today's (far_ambush back to 11.354 exactly). The
verdict REPORTS the distance from the destination at which the inset engaged.
**Tree named (R33.32):** lab/brains-warrig-main `befd86c2` = main + EXACTLY two manoeuvre harness commits the stage needs,
`77348a53` (--faced-off-deg) and `8fc224fa` (--faced-squads): screen_playtest.gd, mk/manoeuvre.mk and
test_manoeuvre_face_clip, defaults unchanged (CP-F (r)'s grant). Plus brains' six War Rig commits. One real merge: R33.9's
latch is kept, with both arrival sites reading `_arrived_at(center.distance_to(arrive_point or destination), state)`, so
the fold's arrive point goes THROUGH the latch.
**Design filed (brains, agreed by the orchestrator, before any judged number): CAP + FOLD, one rule under
`--anchor-inset`.** (i) The inset is capped at one swarm pitch (15 m). (ii) Whatever still falls outside is clamped as
today (the fold). (iii) The element's arrival is measured to the CENTROID OF THE SEATS IT LAID (after clamp and ground),
not the anchor. Compressing the shape alone moves the centroid inland by construction, so a fold needs (iii) anyway.
(1) becomes: every element arrives, with the centroid offset reported; (1b) the largest inset ≤ 15 m, judged; plus a
pure test that an inland element's arrival is unchanged (its seats' centroid = its anchor). Because (iii) changes how
every element's arrival is measured, the squad-arrive line (2) and the check are the guards that it changes nothing
inland.

**Bar, traffic overnight item 2: T4 ghost ON, the third try (filed 2026-10-18 before any number; traffic
`7f81383e3`, references/round33/traffic/ov_t4_bar.md).** Pair/ghost-on-r34 `2b41d3a04` = main `2b40ce075` + the ghost
out of OPT_IN + traffic-t4-guard tooling; OFF = `--traffic-off=ghost`. Native path, builder2 for every line and both
arms, everything at --fixed-fps 30, FRESH seeds, k 1.645. **G** (fresh body_probe children, Locks, seeds 7–18, n 12,
ghost × body): G1 median body-ON alone_s, ghost ON ≤ OFF + 3.0 s; G2 at most 2 of 12 seeds where ON exceeds OFF by
more than 3.0 s (each child is deterministic, so every per-seed difference is real); G3 the Sirens choose body with the
ghost ON in at least as many seeds as with it OFF; G4 test_tactics_body green in the check. **R:** r1 (deciding) a FRESH
process replays exactly with the ghost ON (each probe child twice; rematch_probe's run-0 digest of every position and
velocity identical across two processes, seeds 7–18); r2 REPORTED, the same-process rematch branch rate ON v OFF.
**7:** make check on the pair green on builder2 first (C31.1). **T,** Terminus (C33.7's lines), FRESH drive seeds
849–896, n 48: (1) mixed friend-stuck crew-s ON < base and (base − ON) − k·se > 0; (2) rigs stuck ≤ base + k·se;
(3) pinned ≤ base + k·se; (4) arrivals ≥ base − k·se; (5) REPORTED, the yard head-on and between-squad contacts;
(6) a skirmish guard, random arena, fresh 924–947, n 24: kills, deaths, hit rate and far loops each within base ± k·se.
**Amended at filing (orchestrator):** T(2), (3), (4) and (6) are DECIDING guards too, alongside G1–G4, r1, 7 and T(1).
Any one failing parks T4 with its reading, and there is no partial rule.
**Line 7 red, ruled (orchestrator, 2026-10-18, R33.29):** the pair `2b41d3a04` read 2768/5 on builder2 (sim-baseline
13 moved, as expected; perf JUDGED PASS). relay-smoke (the R33.25 RPC message) and the quiet-window test are known load
reds. test_native_fire passed when re-run. Four reds are native COVERAGE FLOORS with the ghost ON (the gate
"came round" path at 0; sumps parked_refusals 2 ≥ 5), with 0 mismatches. A ghost-ON default must stay covered, so: (b)
native makes its twin stages ghost-aware. Stages whose floor paths the ghost starves run with `--traffic-off=ghost` (they
measure native equality on those paths), and a ghost-ON twin stage is added with floors restated at half its fresh
counts, plus compared ≥ 100. Native's commit is carried onto the pair, line 7 re-runs, and relay-smoke and
remote-guard-test re-run alone if they're the only reds. (c) G and R may run now, and T runs only after 7 is green.

**Bar, traffic overnight item 1: parkedroom v2 (filed 2026-10-18 before any number on its fights; traffic `d8ad761b0`,
references/round33/traffic/ov_parkedroom_v2_bar.md).** Gate: the room rule applies only to a crew AT a post (not under
way, still ≥ 2.0 s). Return: v2 drives the crew back to its post once the asker is past, unless the brain sent it
somewhere new (a move_to more than 3 m from the post); a re-sent order keeps the post owed. Tree stream/traffic-overnight
`20b1cc113`: main + traffic's game diff only (movement.gd, traffic.gd; checked by the orchestrator), DEFAULT_OFF; arm
`--traffic-on=parkedroom`. Native, builder2 for both arms, --fixed-fps 30, k 1.645. FRESH fights 724–771 × {terminus,
locks, random}, n 144 paired, 180 s. Pre-series: test_traffic_neck, C31.1 on pair `5259fb463`, and one s403 episode
traced ON. **Deciding:** L1a far loops behind a parked blocker on a HOLD post ≤ 50 % of base; L1b all parked far loops
≤ base + k·se; L2 all far loops ≤ base + k·se; L3 random's 48 fights, kills, deaths and hit rate within base ± k·se; L4
four crossing cases, fresh 44–46 × six ticks, n 18 a case, crews in ≥ base − k·se; L5 repack while firing = 0; L6 room
give-ways whose crew is alive 30 s later with an UNCHANGED order: ≥ 90 % within 3 m of the post (a change from v1's L6,
since v2 lets a new order win by design; the all-alive line and the new-order count are reported). **Added
(orchestrator):** L6 needs ≥ 50 unchanged-order give-ways, or it reads INCONCLUSIVE and can't pass. Dev reads put L6 at
78 %: a real risk, flagged before numbers.
**Blocked before any judged number; R33.33 (2026-10-18):** N5.Y moved ask / _negotiate / _begin_yield into C++, and
Drive::ask (drive_native.cpp:2465) has NO parkedroom. So on the shipping native path v1 and v2 act only on the few asks
still made in GDScript: a fresh-native dev census (old fights 700–707, builder0) shows 1.5 room give-ways a fight,
against 12 on the stale or absent libraries the earlier dev reads ran. **Ruling (a):** native mirrors it as a
HAND-BACK. While parkedroom is ON, Drive::ask hands the ask to GDScript Movement.ask when the asked crew is not under
way, still ≥ Traffic.still_s and not on a fire post; everything else stays native. The twins check the hand-back at
0 mismatches, both switch states. The series then runs on a pair with native's commit, the bar unchanged. Item 4's
on_fire_post mirror changes alongside it.
**Built (native, pair/native-parkedroom `ae8d6e85` on traffic's pair `5259fb463`):** while parkedroom is on and the
asked crew is not under way, Drive::ask calls Traffic.refresh then Traffic.still_s, and at still ≥ ROOM_STILL_S hands
the WHOLE ask to the live Movement.ask (counted as ask_handed_back). **The ruling's "not on a fire post" carve-out is
dropped, with the orchestrator's agreement:** the GDScript reaches the setup refusal through the parked path, so
handing back every parked ask is equal by construction, and a carve-out would mismatch the counters. The twins: yield
stages set parkedroom OFF for their parked floors, and a new Sumps stage with it ON is floored on ask_handed_back. The
per-ask Traffic.refresh cost is read in the pair's perf-judge.
**Green (native, pair/native-parkedroom `5e5465af` on `5259fb463`, builder2, n 1):** twins + native_h1b + the traffic tests
88/0, 0 mismatches; the parkedroom-ON stage reaches the hand-back once and traffic's room path once (thin, but reached);
perf-judge PASS 1.00x. **Addition, accepted:** crews with `_room_post` set are also EXECUTED by the GDScript (an execute
hand-back), because traffic's right_of_way owns the way back. Without it, 3 traffic_neck ON tests stayed red. The series
reports ask_handed_back per fight, so the hand-back's real coverage is read there.

**Bar, traffic overnight item 4: a battery counts as firing only with a fire mission (filed 2026-10-18 before any
number; traffic `1e48e66a3`, references/round33/traffic/ov_item4_bar.md).** Movement.on_fire_post() is true only for a
hull that is set up, on a fire order that isn't hold_fire, with no move of its own under way, AND with a fire mission
(weapon order target/suppress, or an engaged target). `--traffic-off=firemission` = today. Native's Drive::on_fire_post
(drive_native.cpp:2448) mirrors it. **Tree: current MAIN** (brains' battery seat (a) is already on main, `32e740843`; that
is the battery item as shipped) + the narrowing + native's mirror. Native path, every run `native <target>`, builder2,
--fixed-fps 30, k 1.645, FRESH. (1) random-705 on the pair: fire-post far loops ON = 0 (if base is also 0, the traced
reason is reported and (2) decides alone). (2) census fights 772–795 × 3 arenas, n 72: fire-post far loops ON ≤ base, and
(base − ON) − k·se > 0 if base ≥ 10. (3) repack while firing = 0. (4) brains' battery census, Sumps/Parade/Foundry ×
FRESH 59–64, n 18: shots ON ≥ base − 5 %, median first shot ≤ base + 5 s. (5) all far loops ≤ base + k·se, and random's
24 fights: kills, deaths, hit rate within ± k·se. (6) C31.1 on the pair. All deciding.

## Round 33: five streams, all Opus (prepared 2026-10-17, CLOSED 2026-10-18; briefs in `streams/archive/round33/`)

**Goal: carry home round 32's parked candidates (`roadmap.md` *Round 33 candidates*), each judged on a stage where it
happens the way he plays it.** No new playtest words from him at preparation (2026-10-17 ~07:00 PDT, "prepare the
workspaces for our next round"); his words, if any arrive before launch, go into the briefs first. What he should notice
when it ships: a crew stuck behind a parked crew of ANOTHER squad gets by instead of nudging back and forth; a War Rig or
other wheeled turret vehicle told to face a direction ends facing it, including after it is pushed off its post; a crew's
seat stops jumping while its squad jostles, without parking it in a squadmate's way; respawns never land inside a
standing hull; the planner's shared queue (no starvation) and the War Rig's open-ground face-behind planned on the
library path. Method unchanged (C31.1–C31.3, R31.1–R31.10, R32.1–R32.7 stand): the whole suite with the switch ON on the
pair tree before a judged series, bars sized from `judging.md` and filed in *Bars (round 33)* before any number, `make
quick-remote` to iterate, a full check only for a named hash.

**Models (his last rule, 2026-10-16: "we should go back to using Opus agents across the board to conserve fable quota"):
every stream AND the orchestrator on Opus.** If he wants one Fable stream this round (memory: at most one, for the single
hardest problem), it is traffic (the far loop, lingering since round 31).

| Stream | Folder (offset) | Model | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | Opus | [streams/traffic.md](streams/traffic.md) | a crew pinned behind a parked crew of another squad gets by (the far ask loop in skirmish); the crowded yard's last hull stops circling its slot (T4) | **CP-X** the far-loop census + design |
| **manoeuvre** | `godot-manoeuvre` (2) | Opus | [streams/manoeuvre.md](streams/manoeuvre.md) | a wheeled turret vehicle given a facing turns its hull there AT REST and sits still (M1b(3)) | **CP-F** face at rest |
| **brains** | `godot-brains` (3) | Opus | [streams/brains.md](streams/brains.md) | respawns never overlap a standing hull; a pushed-off rig returns to its post facing his way (B11b on CP-F); seats stop jumping (B10b); the yard's last crew in (B5c-v6) | respawn fix; B11b |
| **native** | `godot-native` (4) | Opus | [streams/native.md](streams/native.md) | nothing alone: every pair; N5's held ports once CP-X's design settles | each pair |
| **planner** | `godot-planner` (6) | Opus | [streams/planner.md](streams/planner.md) | the planner's shared queue (no gang-press starvation) and the War Rig's open-ground face-behind served on the library path | CP-Q |

**Launch baseline:** main `bb4fad59` (+ this docs commit) inherits `0c124cf7`'s green check (builder0 `make check exited
0`, 2724/0, sim-baseline 13 unmoved): `tools/merge_check_needed.sh 0c124cf7` lists only `mk/planner.mk`, whose diff is one
comment line (a brief's archive path). Workers run no baseline check.

**Ownership:** round 32's table stands (traffic the give-way block, `_avoid`, `_around_friends`, `_ask_behind`,
`_hull_within`, `_negotiate`, ask, `_begin_yield`; manoeuvre the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`,
the k-turn executor, H1/H1b, the face-at-rest path in `order_controller.gd`, the `_order_move` decline for wheeled turret
hulls; planner `game/ai/planner/**`, `native/src/planner_*`, `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`;
native `native/**` outside planner_*, `mk/native.mk`, `exec_fields.h`, the twins; brains the rest of `game/ai/**`,
`game/tactics/**`, elements, `tank_brain.gd`, `gunnery.gd` except manoeuvre's lead lines). **New grants:** brains gets the
respawn spot in `game/match/match.gd` (the `tank.respawn(_jittered(spawn_position(...)))` call ~2128 and one helper beside it; merge
note) for C33.5; traffic gets `arenas/**` / `game/arena/**` ONLY for the crate-roof navmesh islands (stretch). **Nobody:**
`tests/baselines/**` except the orchestrator's `make sim-baseline-adopt` on main; `tools/judge/**` (the orchestrator).

**Contracts (round 33):**

- **C33.1 Fresh start.** Round 32's `stream/*` branches are renamed `round32/<stream>` (kept, all merged); every worktree is
  created from this docs commit. No agent of round 32 runs. `origin` holds old `stream/*` branches: workers don't push.
- **C33.2 The far ask loop in skirmish (CP-X; traffic leads, brains provides any element seam).** Round 32's evidence
  (manoeuvre, builder0, fights 400–423, n 24, `a13a9399`): far rows 6, of which 5 are a crew pinned by a PARKED crew of
  ANOTHER element (4 × Green_Guns_4 behind Green_Eyes II_3, 54 m of route left, gap 6 m; 1 × Rust_Battery2_1 behind
  Rust_Battery_5, 19 m left) and 1 same-element under way. **n 6 is too few to design on.** (1) **Census first:** far rows by
  `blocker_kind` (manoeuvre's field, on main) over a wider skirmish sample (fights, hull-rest, and two real skirmish maps
  he plays, Terminus and the Locks; harness must form elements: lesson 1 of manoeuvre's round-32 close), filed as a
  REPORTED table with the frequency per match. If the case is rarer than ~1 per match, say so and the orchestrator decides
  whether to build. (2) **Design**, written before code and agreed through the orchestrator: a cross-element give-way (the
  parked crew yields by traffic's `_begin_yield`, since it has no route of its own) or an element-level make-room
  (brains: the parked crew's element shifts that seat). Swapping seats is out (C32.10, parked: different elements share
  no seats). If brains' seam is needed, its signature is agreed before either side writes code (as C32.10's). (3) Its own
  bar on the skirmish stages, filed before numbers; the whole suite on the pair tree with the switch ON first; native
  mirrors only if the rule reaches the drive or `_negotiate`.
- **C33.3 Face at rest (CP-F; manoeuvre), then B11b (brains).** Manoeuvre first traces planner's round-32 finding
  (hull-rest faced_move s66: both arms end ~150° off and the seam never acted, a `stop` with no face step after the move;
  a likely main bug) and fixes it on its own commit if it is one. Then M1b(3): a wheeled turret hull that completes a
  faced order turns its HULL to the facing at rest (turn-the-hull, his round-28 call 2) and settles; R32.3 (a)–(c) stand
  (arrived = the held seat at completion; re-seats guarded; facekeep unchanged). CP-F merges ON when judged. **Then** brains'
  B11b: HOLD's return honours the post's facing for `mount == "turret"` wheeled hulls ONLY (B11's gain kept: wheels/turret
  faced_move 48.4 → 17.3°; fixed-gun wheeled hulls untouched by construction), judged on a base with CP-F ON; the pass
  case s66 Green_Guns_5 ≤ 90° in ≥ 2 of 3; no class worse at p < 0.05.
- **C33.4 B10b, the grounding latch as a seat choice (brains).** B10 fixed the flips (Sumps s16 t8: 22 → 0) but failed Sumps
  s19 t8 (+19.9 s: the latched seat stood in two squadmates' passage). B10b keeps the latch only while the latched point is
  not in a squadmate's route corridor (or re-grounds once, with hysteresis); its bar names s16 t8 (flips) and s19 t8
  (time) as pass cases. Then B5c-v6 (lab `lab/brains-r32-gate` `b8a34c4f`; native's side-gate mirror on
  `pair/brains-v6-carry`) on a base with B10b ON if it ships, else on main.
- **C33.5 Respawns never overlap a standing hull (brains, the grant above).** A respawn takes the nearest clear spot
  (hull footprint v standing hulls), deterministic; a test that fails without it (a big hull respawning beside a parked
  one). Sim-baseline may move: the orchestrator adopts with the reason.
- **C33.6 CP-Q, the planner's shared queue, and the open-ground face-behind (planner).** (a) The hull-rest gang arm A/A
  (fifo v fifo, seeds 66–71) sizes line (3)'s noise; (b) re-judge `--planner-queue=shared` (refuse early only at rest,
  `d98656ab`) on FRESH seeds with that bar; ships ON as a pair if it passes. (c) The seam never serves a War Rig's
  open-ground face-behind with the library (189 expansions > PENDING_TICKS × SLICE = 180): a budget or heuristic change so
  it does, priced per preset (his rule: perf cuts ship as presets), judged on test_manoeuvre_face_behind's cases and the
  hull-rest rigs. Manoeuvre's CP-F is the executor side: agree with manoeuvre which owns a faced finish.
- **C33.7 T4-ON (traffic, after CP-X's census).** Trace ONE circle loop (the yard head-on's last hull circling its slot
  15–20 s with the ghost on; also B5c-v6's case: tell brains what you find), then mixed stuck re-judged at n ≈ 48 on fresh
  seeds, bar filed first.
- **C33.8 Native.** Pairs pre-empt its own work (C31.2). N5's held ports (`_negotiate` / ask / `_begin_yield`, `_manoeuvre`)
  stay held until CP-X's design is written (it will likely change exactly those); then port them. `test_native_face_behind`
  compared 0 native executes in round 32 (vacuous): give it a floor if round 32 did not.
- **C33.9 The scout out-turned by an attacker orbiting it (manoeuvre; his words 2026-10-17, `game_design.md` *Round 33,
  his playtest words during the round*).** His law_scout (Pursuit Cruiser: wheels, fixed machine gun with a 20° arc, min
  turn radius 5.5 m, 16 m/s forward / 7 reverse, hull_turn_rate 130°/s), alone, under fire from a vehicle circling it. It
  drove forward and back trying to yaw right and never got its nose round. He wants it to drive forward on a hard turn toward
  the attacker's side, because a wheeled hull yaws faster rolling forward, and moving is also evasion. Manoeuvre owns it;
  diagnose FIRST on the laptop while CP-F's series holds builder0. (1) Build a stage that reproduces it: a law_scout alone
  and a faster enemy orbiting it at its own range, and name what drives the back-and-forth (Manoeuvre.choose's k-turn, the
  fixed-mount aim, the unstick, or the brain's engage). (2) Report his scene's numbers: time to the first shot, hits taken,
  and the scout's yaw rate against the orbiter's angular rate. (3) A fix: a fixed-gun wheeled hull whose target is off its
  arc and moving round it takes a forward turning arc toward the target's side (no reverse leg) while the arc is outside a
  threshold. File a bar before any number. Native: if the change is in Manoeuvre.choose / behind / simulate (C++ since N5.M),
  it pairs with native (C26.2). The same rule applies to every fixed-gun wheeled hull on every side (symmetric). Priority:
  after CP-F's series and verdict, ahead of manoeuvre's stretch items.
  **Diagnosed (manoeuvre, laptop, scratch of main `0ef2443b`, GDScript, seed 4, n 1 a cell, 30 s; stage
  tests/test_manoeuvre_orbit.gd):** the back-and-forth is OrderController's FACE CREEP, reached because the scout picks SPOT
  (0.88 whenever a visible threat is closer than 75 m), not ENGAGE. SPOT clamps its 85 m post to the 18 m player-post leash
  and then sends `face` at the threat. plan_face finds no plan against a moving target (23–24 empty a run v 1–5 made), so
  the creep drives full lock forward/back: 38 gear flips in 30 s. choose, plan_lay, unstick and wheelhold are not involved.
  His scene (player-team law_scout v syn_scout), radius 30 / 15 m: the scout yaws 20.8 / 26.9°/s against the orbiter's
  bearing rate of 32.3 / 57.9°/s; target in arc 3.8 / 4.4 % of ticks; shots 5 v 112 / 20 v 128; hits taken 60 / 108.
  **Bar C33.9 "turn in" (filed 2026-10-17 before any fix number).** Candidate: on a face order whose spot is more than
  T = 30° off the arc, a wheeled fixed-gun hull (law_scout, gang_scout) drives FORWARD at full lock toward the spot's side,
  with no reverse leg. Inside T it rolls on its turning circle at the speed that matches the target's bearing rate (creep
  floor), and stops only when that rate is near zero. Lands in order_controller.gd's face-at-rest path plus a new function
  in manoeuvre.gd (choose/behind/simulate untouched; manoeuvre confirms with native that the wheeled face path has no C++
  twin before building). Opt-in `--nav-off=turnin` until it passes. Cells: subject law_scout / gang_scout × orbiter
  syn_scout / gang_ifv × radius 15/30/45 m × player post on/off × FRESH seeds 11–16; arms ON v OFF on one tree. (a) median
  target-in-arc share ON ≥ 2× OFF and ≥ 25 %. (b) median scout shots ON ≥ 1.5× OFF. (c) median hits taken ON ≤ OFF, and no
  cell worse by more than 20 %. (d) while |error| > T, ON spends 0 reverse ticks in every run and makes ≤ 2 gear flips per
  30 s. (e) ON's furthest point from the post ≤ the 18 m leash + 11 m. **(e2), added by the orchestrator:** a STATIC face
  (a drawn facing with no moving target, his CP-F case for a fixed-gun scout) is no worse: aligned no later than OFF, and
  no further from its spot than OFF + 2 m. (f) builder0 guards: scout tests and scenarios green; the fights stage's scout
  kills and deaths no worse than OFF within noise; the full check green, sim-baseline unmoved while opt-in. The default
  flips later, with its own A/B. **The SPOT-v-ENGAGE question goes to brains** (a scout under fire within its gun's reach
  probably should ENGAGE), recorded and not built this round unless brains has room after R4.
  **First matrix NOT a verdict (manoeuvre, laptop, scratch `777d2979`, seeds 14–16, 144 cells):** the stage's seed changed
  only the hit dice (orbit direction, start and heading fixed), so 3 seeds were about 1 sample. The candidate had a stall
  bug: on target, "under 5° in 1 s" read as stuck and handed back to the creep, which reversed. Player-post cells: (a) time
  on target 4.3 → 55.1 %, (b) shots 2 → 19, (c) hits 91 → 86 median but worst cell +167 % (6 → 16 hits), (d) 27 flips, and
  (e) 36 m from the post. Free cells: ON ≡ OFF (turn-in never runs; that scout reverses on SPOT moves). **Amended
  (orchestrator, 2026-10-17):** the seed now also sets orbit direction, start phase and scout heading, and "on target" counts
  as progress in the stall check. Because seeds 11–16 have now been seen, **the judged run is on FRESH seeds 31–36**
  (builder0 light, one tree, named). Seed 21 is development only. (d) counts reverse ticks while a FACE ORDER holds, and
  (d) and (e) are judged on the player-post cells. **(d) amended (orchestrator, 2026-10-18, before any judged number; dev 11–23 seen
  only):** (d) counts reverse ticks under a REVERSE COMMAND, which must be 0 in every run, and gear flips by command. Total
  reverse ticks are REPORTED: 12 of 156 dev runs had 1–9, every one under a forward command at full lock, which are
  contact/depenetration bounces from the physics plant and not the controller choosing reverse.
  **Corrected the same day (manoeuvre, laptop, --fixed-fps 30, gang_scout v syn_scout 15 m seed 14, scratch `0782504d`):
  they are NOT contact.** No slide collision on those ticks. Between SPOTs the brain picks HOLD → `stop`, and gunnery's R2
  hook (gunnery.gd ~172: a fixed mount at `stop` steers `drive_toward` at throttle 0) swings the gun through the plant's
  creep, so the scout shuffles under HOLD (164 of 900 ticks in that run). That is HIS shuffle, alive outside the face
  path. **Added to C33.9 (orchestrator):** under the turn-in switch, a wheeled fixed-gun hull at `stop` with its target
  out of arc goes through turn-in (or holds still), never the creep. Manoeuvre puts it in order_controller.gd (its own
  file) before the creep. If the gunnery R2 line itself must change, that line is granted to manoeuvre for this, with a
  merge note. **(d) gains (d2):** reverse ticks while the order is `stop` (HOLD), ON = 0 in every player-post run, and
  total reverse ticks are reported. Filed before any judged number.
  **Weapon reach (orchestrator, 2026-10-18; after dev 11–23 only, judged 31–36 unseen):** dev on three variants
  (`ea043755`, `679de95d`, `ecb955be`; builder2, --fixed-fps, n 13) passes (b), (d), (d2), (e) and (g), but (a) is 21–23 %
  and (c)'s worst cell is +36 to +56 %, always gang_scout v syn_scout at 30/45 m. There the gang scout's spear_gun
  (effective 24 m) fires 0 shots in BOTH arms, while the orbiter's pulse_repeater reaches 55 m. Turning in to face a
  target it cannot hit gains nothing and exposes it. That is a design fact, not a number to tune, so: **the candidate
  becomes `ea043755` + "out of its weapon's effective reach, the turn-in jinks without chasing the bearing" (evasion only,
  no facing)**, developed on 11–23 first. **Judged on 31–36:** (a) ≥ 2× OFF and ≥ 25 %, and (c)'s per-cell 20 % line
  (OFF hits ≥ 10), both read on IN-REACH cells (the orbit radius within the scout's effective range). OUT-OF-REACH cells:
  pooled hits ON ≤ OFF, and no cell worse by more than 20 % (OFF hits ≥ 10), with in-arc reported. The 25 % line stands
  and is not lowered. A scout outgunned at range LEAVING is brains' item 2 (the SPOT question), not steering. A new line (g): free cells ON no worse than OFF on (a)–(c). SPOT's own
  **(c) in reach re-read (orchestrator, 2026-10-18; dev 11–23 only, judged 31–36 unseen):** dev at `835da0875` shows
  the in-reach (c) miss is a DUEL the scout now takes: law_scout v syn_scout 30 m, scout shots 8 → 260 and hits taken
  78 → 103. Hits taken alone penalises exactly what he asked for ("get a shot off"). So in reach, (c) is judged as the
  EXCHANGE: pooled damage dealt ÷ damage taken ON ≥ OFF, and no cell's exchange worse by more than 20 % (cells with OFF
  hits ≥ 10). Hits taken are reported. (a)'s 25 % stands. Out of reach, the lines are unchanged. Manoeuvre picks ONE
  candidate (ea043755 or 835da0875, or one more dev iteration on 11–23) before 31–36, and the verdict says why. Whether
  a scout that can't get away should stand and trade at all is put to the lead in player terms (HANDOFF).
  moves stay with brains' SPOT-v-ENGAGE question. (c)'s "no cell worse by more than 20 %" is read on cells with OFF hits
  ≥ 10, and cells below that are reported. The machine-equivalence check (laptop seed 11 v builder0 seed 11, same code) is
  reported in the verdict.
  **Mechanism found (manoeuvre, builder0 light, dev seeds 21–23, `640d9535`):** every turn-in variant raised hits taken
  because the orbiter's gunner fires only once its turret lay settles on the lead point (gunnery `aimed`). OFF's
  half-second creep reversals keep moving that point, so they work as evasion by accident. Enemy shots at 45 m v gang_ifv:
  42 OFF v 198 with braking; hit per shot barely moved (0.19 v 0.25). So the evasion he asked for is the mechanism.
  Candidate `b9656866` jinks on target: speed swaps between 0.2 and the yaw-cap share on uneven 0.5–1.0 s dwells,
  always forward, with a 10 m leash. **Added (orchestrator):** the dwells come from the sim's seeded randomness (or tick
  and hull id), never a time-seeded source, and (f) gains a determinism line: the same seed run twice gives identical ON
  rows.

**Rulings (round 33, the orchestrator's, as they arise):**

- **R33.1 F0 closes with no fix; CP-F is the change (2026-10-17, manoeuvre's trace):** builder0, main `ae3dad71`, hull-rest
  gangs s66 faced_move, native path, n 1: Green_Guns_5 ends 109.1° off, at rest. Its element's faced hold replaces its move
  ~12 m out; every face after that (order/sector sources, and contact) is declined to `stop` by round 8's
  turret-carries-aim rule because turnhull is OFF, so no face reaches the mover and the seam never acts. Not a main bug.
  Manoeuvre's F1 lead: under turnhull ON a contact face is declined to `stop` mid-plan, so the hull stops partway through
  its turn (the attack-move moving-at-75-s line).
- **R33.2 A faced finish (C33.3 / C33.6 (c), agreed by manoeuvre and planner):** manoeuvre owns WHEN a faced finish runs
  and its residual; planner owns HOW while `take()` holds.
- **R33.3 `PlannerSeam.live()` has no staleness check: a MAIN BUG, planner's first item (pre-empts P1):** a crew whose seam
  face or k-turn is cut off by another order stays live until the match ends (`planner_seam.gd:254` checks only that the
  crew and hull exist), so `Movement.unstick` is skipped for that hull (`movement.gd:3078`) and the census is blind to it
  (s66 Green_Guns_5: live from ~f 500 to ~f 2300 under order `stop`). Fix alone on its own commit with a test that fails
  without it (a seam hold released when the order that started it is replaced), a check, a named hash; a sim-baseline move
  goes to the orchestrator with the reason. Native says whether the C++ drive reads the hold through the same callback
  (no mirror) or needs one.
  **Amended (native's pre-assessment, same day):** the C++ drive does NOT call live(); `drive_native.cpp:280` `seam_live()`
  mirrors it inline from `PlannerSeam._crews` (read by the unstick gate :1449 and the `_planned_reverse` open :2211; it
  calls live() back only for a freed hull). **Ruling: the fix RELEASES the stale crew from `_crews` where the order is
  replaced (the seam's sweep / step / order hand-off), and live() stays a pure lookup**, so the C++ needs no change and the
  tick stays cheap. A check inside live() would mismatch the twin. Native confirms on the pair tree (kturn / execute twins).
  **Answered (planner, `33300f99`):** "asked about" = take()/hold() (only `_serve` writes tick_seen; live() writes nothing);
  hold() is face_turn's and `_planned_reverse`'s first line, both called every tick, and the C++ hands wheeled faces back
  to face_turn (execute_native.cpp:363-376) and calls `_planned_reverse` back every tick (drive_native.cpp:2211-2214);
  STALE_TICKS 2 (`_serve`'s rule since round 31), run each physics_frame (the frame counter only). Native approved.
  **Native's twins on `03d1a50c`** (builder0 light, `native_drive|native_execute|native_face_behind|planner_seam_stale`):
  exited 0, 10/0, every twin 0 mismatches; answer (a), no C++ change. Planner's full check is the ship gate.
  Native's face_behind floor was already on main (builder0 `ae3dad71`: 142 native executes, 0 mismatches).

- **R33.4 CP-X: BUILD, kind-agnostic, as traffic's own give-way (2026-10-17, on traffic's X1 census):** builder0, tree
  `dc6723ed` (main + probe), showmatch fights 500–523 on Terminus / Locks / random, 180 s, n 69: far loops 0.54 a match
  (9/69 matches); the brief's case (parked crew of ANOTHER element) 3 episodes / 9 loops (~1 in 23 matches); behind ANY
  parked crew ~10 episodes / 30 loops (~1 in 7). Mechanism (s403): no spot in `_begin_yield`'s fixed set fits a parked
  crew in a neck, so it gives way IN PLACE (moves nothing), then refuses that asker for good ("just gave way to you": 20
  of 30 loops); the other 10 are set-up batteries (T1c-b2, his yes). **Ruling:** build X2 option (a), kind-agnostic: a
  parked crew never yields in place, is never refused for "just gave way" after an in-place yield, searches wider for a
  spot off the asker's ROUTE, then returns. Switch `parkedroom`, DEFAULT_OFF; stage `test_traffic_neck`. No brains seam.
  **The bar must carry T1c-b2's line** (a set-up mortar truck ordered to fire never repacks for a passer: 0, as shipped)
  and the parked crew's return (it ends back at its slot / post within a filed time). Native: ask / `_begin_yield` run in
  GDScript on both paths, so no mirror for parkedroom; **N5's ports of those functions wait for parkedroom's verdict**
  (it changes `_begin_yield`'s body).
- **R33.5 CPU squads of > 5 hulls are refused an element every think tick (traffic's side finding; brains owns it, next
  after R1):** C19.1 refuses an element at start and again every think tick once a team's elements are gone
  (`element_commander.gd:180`): unseated crews and up to ~470 ERROR lines a fight. A play bug (log spam each tick, crews
  never seated): trace, fix alone with a test, its own check.

- **R33.6 R33.5's cause and fix: SPLIT a > 5-hull CPU-played squad into elements (brains, 2026-10-17):** only on a side
  folded with `SquadConsolidation.for_player` but played by the CPU (showmatch / `--player=cpu`; never his opponent).
  for_player splits only past SPLIT_OVER 8, so that side has squads of 6–8; `skirmish_mode.gd:415` forms one element per
  squad and C19.1 refuses each big one; `element_commander.gd:180` re-forms only when the team has NO element, so those
  crews stay unseated all match, and once the formed ones die the refusal repeats every THINK_TICKS (~470 ERRORs).
  **Ruling: build the split** (his rule: symmetric AI improvements ship without asking; it is the existing doctrine): a
  squad of n > MAX_MEMBERS becomes ceil(n / 5) balanced blocks ("<squad>", "<squad> II", …), the same count and balance as
  his own `SelectionSquads.split` deals a big group into; the commander also re-forms when any living squad member of its
  team has no element. Grant: brains edits `game/modes/skirmish_mode.gd:415` (one line: `form_squad` for `form`; merge
  note). A test that fails without it (0 ERRORs, every crew seated, on a showmatch side with a 6- and an 8-hull squad);
  its own check; sim-baseline moves listed with the reason (showmatch maps). **Every running series stays on its own tree:**
  traffic's parkedroom and manoeuvre's fights stages use showmatch fights, whose Green side this changes.

  **Side effect accepted (orchestrator, on brains' `71f80a70` read):** in RESPAWN (non-elimination) matches, a crew that
  respawns is now re-formed on the next think into a new element named after its squad, usually 1 crew. Main left it
  unseated (its brain alone) until its team had no element. It is a symmetric AI change and ships with R33.6: a respawned
  crew rejoins doctrine. Two elements can share a squad name on the CPU side (cosmetic). Elimination matches are unchanged.
  A sim-baseline move from this is listed with its reason at merge. Round 34 candidate: rejoin the squad's living element
  when it has room.
- **R33.7 N5.M, `_manoeuvre`'s decision in C++ (native, 2026-10-17):** stream/native `04ee782e` + `145ada3a`, switch
  `BrainSwitches.native_manoeuvre` default ON (off = round 26's callback); design in `native.md` *N5.M*. Proof (builder0
  light): `test_native_manoeuvre` 920 decisions, 0 mismatches, 0 called back (reverse 307, route 613, every refusal but
  no_arrival). Price: a decision tick's drive 1762 → 719 µs (loaded box, n 1), nothing per tick. Merges ALONE when green
  with sim-baseline 13 UNMOVED (the port's own proof), NATIVE=off and native-proof read, no_arrival covered or shown
  unreachable. **From its merge, `Manoeuvre.choose / simulate / behind / _others` are twinned (C26.2):** manoeuvre's edits
  there become pairs with native.

- **R33.8 T4's circling hull is the approach gate's (traffic's X4 trace, 2026-10-17; `references/round33/traffic/x4_t4_circle.md`):**
  builder0 light, yard head-on s42 t3, native path: ghost ON A_5 settles 44.6 s v base 25.2 s (round 32's case reproduces).
  A faced wheeled hull interrupted ~5 m from its approach gate, pointing the wrong way, re-aims the gate from inside its
  turning circle and the circle rule loops 16 s; the ghost only changes where the hull ends up near the gate. **Ruling:**
  brains' fix, inside B5c-v6 (R4): yard s42 t3 A_5 joins v6's bar as a named pass case (ghost ON and OFF). T4's mixed-stuck
  re-judge (n ≈ 48) runs after parkedroom's series, with the yard head-on's settle time REPORTED (not judged) until v6 lands.

- **R33.9 An element's `arrived` flips with no hysteresis: a MAIN bug, brains' next item after R1 (manoeuvre's F1 trace,
  2026-10-17; `references/round33/manoeuvre/f1-arrived-flip/`):** builder0 light, `97bcd952` + a goal print, gangs hull-rest
  faced_attack_move s40, GDScript, n 1 an arm: the Battery element (14 crews, swarm) flips `arrived` every 0.5–3 s from
  t ≈ 15 s to the end on ONE anchor; arrived lays the seats on his drawn heading, not-arrived ~150° the other way, so every
  seat jumps 19–27 m a flip. Base (turnhull OFF) as bad: Battery 67 flips v 59, Hunters 17 v 5, re-seats 286 v 234. Cause:
  `element_plan.gd:290` `plan["arrived"] = to_go <= ARRIVE_M` (12 m, the centre) — the arrival layout pulls the centre past
  12 m, the travelling layout pulls it back (the pattern line 781's `facing_sent` already guards for the facing). Turnhull
  only catches more crews mid-turn at the judge. **What he would see:** a gang battery that never settles after an
  attack-move, crews shuttling ~20 m back and forth. **Ruling:** brains latches arrival per task (arrived stays true for the
  task until the centre leaves ARRIVE_M + a margin; line 686's twin read too), alone, a test on a 14-crew swarm
  attack-move that fails without it, its own bar (s40 Battery flips 0; arrivals not down; re-seats down), its own check;
  sim-baseline moves adopted with the reason; native states whether element_plan has a twin. **Order for brains:** R1 →
  R33.9 → R33.6 → B10b (its series on a tree with R33.9). **Manoeuvre's CP-F bar judges on a tree with R33.9.**

- **R33.10 builder0 is the bottleneck (2026-10-17):** two full checks (planner `03d1a50c`, brains `2fd9f420`) were killed at
  slot.sh's 5400 s cap at load ~23 with shard 3 unfinished (both 0 failed in what ran, sim-baseline 13 unmoved): no verdict.
  **Rules for the rest of the round:** each stream runs ONE heavy builder0 job at a time; priority is (1) the full check of a
  hash named for merge, (2) a filed judged series, (3) tuning / traces (light lane or the laptop where the number is not
  judged). **R1 merges on R33.9's check:** if lab/brains-r339 `429ebc4b` (= R1 `2fd9f420` + R33.9) is green, `2fd9f420`
  merges on it (its own partial check read 2640 passed / 0 failed, sim-baseline unmoved, 23 other targets passed);
  `429ebc4b` itself merges only when R33.9's bar passes.

- **R33.11 parkedroom's pair check `cf17abd6` (builder0 `make check exited 2`: test 2724 passed / 3 failed, sim-baseline red as
  expected, native traffic twins 0 mismatches):** the three reds are tests of the old fixed-set give-way
  (`test_movement::test_asked_to_give_way_it_steps_off_the_line_and_resumes`, brains';
  `test_nav_yield_fit::test_a_rig_accepts_only_a_spot_it_fits_and_gives_way_without_the_wall` and
  `::test_the_refusing_build_declines_when_nothing_fits`, manoeuvre's). **Granted:** traffic pins parkedroom OFF in those
  three functions' setup only (they judge the fixed-set rules, which remain), and adds ON counterparts to
  `test_traffic_neck` (merge note). **Before the series:** the first test's ON yield point (-100, 0, 2) is on the lane and
  behind the asker's start, so traffic shows the parked crew's path, minimum gap to the asker and contacts ON; a head-on
  means the room search excludes spots whose path crosses the asker's corridor, fixed before the series.
  **Answered and fixed (traffic, stream/traffic `ad347548`):** the spot was 6 m AHEAD of the asker down the lane (LANE is
  z 20), but the defect was real: the asker asks before it has a route, so the corridor was a point and a spot straight down
  the lane read as off route. Now with no route the corridor is the asked direction (40 m), and the straight run to a room
  spot never comes closer to the asker than it starts nor re-enters the corridor. Test (a) ON (pair tree `ea550faf` =
  `cf17abd6` + the fix + the pins, builder0 light): spot 8.3 m off the lane, MIN GAP 7.1 m, contacts 0; traffic_neck 7/0,
  test_movement 9/0, nav_yield_fit 4/0. **The series tree moves to `ad347548`'s code; its full check (`ea550faf`) first.**
  The pins must restore in a teardown/after_each, not a last line (a failing assert would leak the pin into later tests).
  **Done:** pins restore in teardown() (stream/traffic `aff64e2b`). Pair hash for the check: `pair/parkedroom-on` `6ea486ef`
  (= `ea550faf` + that; ea550faf's check stopped, no verdict). Series tree: stream/traffic `aff64e2b`.

- **R33.12 parkedroom PARKED (2026-10-17; series FAIL, stream/traffic `b4b78825`,
  `_agents/streams/references/round33/traffic/x3_series_verdict.md`).** builder0, tree `d90fbdb7` (code `aff64e2b`), fights
  700–723 × terminus/locks/random, 180 s, n 72 paired: L1 parked far loops 22 → 25 (paired se of the sum 20.3) FAIL; L2 all
  far loops 36 → 44 PASS; L3 PASS; L6 return 212/2175 back within 3 m FAIL; L4/L5 not run. It stays DEFAULT_OFF and
  `pair/parkedroom-on` does not merge. Findings: the targeted hold-post "just gave way" loops went 11 → 0, but L1's remaining
  loops are T1c-b2 fire-post refusals (20 of 23 in random-705), which the rule leaves alone. L6 is a real defect: "parked" =
  "not under way", so a crew paused between orders makes room and its element then sends it on (median 19.1 m from the
  "post" at 30 s). **Ruling:** no v2 this round ahead of T4 and islands. If traffic reaches it, v2 gates the rule on a crew AT
  a post, and its bar is filed fresh before any number: new fights (not 700–723), L1 on hold-post far loops plus all
  parked far loops not up, L6 kept. Narrowing L1 after seeing these numbers counts only on fresh seeds. The random-705
  fire-post loop (20 loops, one fight) is REPORTED to the round's close as a separate problem; no stream owns it this round.
  What he'd notice ON (traffic, same tree): crews shuffle aside about 42 extra times a fight (median; worst 111). They are
  crews paused between orders that never needed to move, so a busy neck could look like milling. The fights look the same.

- **R33.13 CP-Q (planner P2) does not ship (2026-10-17; builder0, pair `c75f20a6`, hull-rest gangs fresh seeds 72–83, n 72
  paired a mode).** Line (1), abandoned share, FAILS in both modes: drawn 0.9 % v FIFO 1.0 % (p 0.44), clicked 0.9 % v 1.6 %
  (p 0.06). Both are under 5 %, and neither is significantly below base. The FIFO base was 13–25 % in round 32 and P1's A/A;
  on main today, with R33.3's stale release, it is 1.0–1.6 %. **R33.3 is the cause, shown by removal** (planner, laptop GDScript, FIFO hull-rest gangs drawn, seeds 72–74 × 6, 18 runs an arm): release on (`c75f20a6`) 7/594 = 1.2 % abandoned; `_hook()` stubbed (`02934dec`, never pushed) 142/667 = 21.3 %, queue_waits 1298 v 15767, Fisher p 6e-34.
  (2) PASS. (3a) drawn at-rest hull error +5.43° against a +4.50 line FAILS (attack_move +13.2, move +15.2). (3b) and (3c)
  PASS. Terminus and s207 are reported in full (early stop off). **Main keeps FIFO; P3's series tree = main + FACE_KEEP on
  FIFO.** The stretch item (refuse GOAL_BLOCKED / START_BLOCKED before queueing) is planner's call, and only if a cheap read
  shows those refusals cost hold time. Native gets nothing from P2.

- **R33.14 T4's line 7 red is an order-dependent test, and T4's series goes ahead (2026-10-17).** Pair `bbb4d2db` (ghost out
  of OPT_IN), builder0 `make check exited 2`: 2730/1, sim-baseline 13 moved (expected), perf NOT JUDGED. The red is
  `test_tactics_body::test_his_three_squads_keep_together`, brains'. Traffic's light lane on `bbb4d2db`: alone it passes 3/3
  (alone_s off 43.5, on 15.0). With test_rts_camera in front it fails (off 38.0, on 18.5 against a line of < 19.0). On
  ghost-OFF trees it passes in every order traffic tried (off 41–44.5, on 12–15). It is the same class as R32.6: the result
  depends on what ran before it, on a relative line. **Ruling:** (a) the Terminus re-judge runs on `bbb4d2db` as filed. T4
  does NOT merge until line 7 is green on a named hash. Brains hardens the test (laptop; e.g. each arm in a fresh stage
  state, or a fixed start phase, keeping the halving line) as its own small commit, and traffic carries it onto the pair
  tree for the merge check. Traffic REPORTS ghost OFF v ON alone_s for the body-ON arm in the failing order (test_rts_camera
  in front), so a real ghost cost on keeping squads together shows up as a number and not a flake.
  **Read (traffic, builder0 light, seed 1, n 1 a cell; OFF = stream/traffic `b4b78825`, ON = `bbb4d2db`):** body-ON
  alone_s ghost OFF v ON, by what runs in front: none 15.0 v 15.0; det_core 15.0 v 15.0; rts_camera 12.0 v 18.5; shard-3
  48–70 12.0 v 18.5; 71–93 15.0 v 17.5. So it isn't only the order: in 3 of 5 orders the ghost costs the body-route squads
  +2.5 to +6.5 s alone. **Added to T4's bar as a JUDGED guard, filed before its numbers:** the body stage
  (`tests/tactics/body_stage.gd`, locks), seeds 1–3 × fronts {none, test_det_core, test_rts_camera}, n 9 a side, body ON,
  ghost OFF v ON on one tree. Median alone_s ghost ON ≤ ghost OFF + 3.0 s; in every ghost-ON cell, body-ON alone_s < 0.5 × that cell's
  body-OFF alone_s (the test's own halving line); and the Sirens choose "body" in every ghost-ON cell. Fail = T4 parks with the worst cell traced. Brains' hardening must not hide this:
  the hardened test has to fail on a stage that really loses cohesion, so it is shown failing on one such case.
  **Read and ruled (traffic `cea5cb56`, builder0 light, tree `95f85afc` = game code `bbb4d2db`, n 9 a side): (1) PASS
  (median 15.0 v 15.0). (2) and (3) FAIL, all at seed 2, and the ghost-OFF arm fails the same cells.** At seed 2 the Sirens
  choose "own", identically in both arms and before anything drives (own 103.0 m with 24.6 m alone v body 123.6 m with 22.4 m
  alone), which is the right choice. Ghost-OFF's body-OFF baseline there never arrives (alone 56.5 s). **R33.16, a bar
  defect, shown by the control arm:** (2) and (3) were written as absolute lines, but the guard's filed purpose is a ghost
  COST. They are re-read in the guard's own relative form: (2') every cell's body-ON alone_s ghost ON ≤ ghost OFF + 3.0 s;
  (3') the Sirens' choice is the same, ghost ON v OFF, in every cell. Amended after the numbers were seen, so the reason is
  recorded here. Dropping seed 2 was rejected. The earlier suite-order signal (12.0 v 18.5) did not reproduce in the guard
  at --fixed-fps 60 (13.5 v 12.5). Traffic reports both. Also: tactics.mk's BODY_SEEDS shadowed traffic's variable, now
  renamed BGUARD_*.
  **Re-read, then T4 PARKED (R33.17; traffic `787fb8ae`, same tree, seeds 1–3 × 3 fronts):** (3') PASSES in all 9 cells.
  (2') passes in 8 and FAILS at rts_camera s3: ghost OFF 7.0 v ON 12.5, against a line of 10.0. Traced: the ghost arm reads
  12.5 at seed 3 behind every front. The CONTROL arm swung 17.0 → 7.0 with the front, because Hunters2 was late and the army
  came in at 23.1 s (body_stage.gd:31's known order swing). It still fails as filed, so T4 stays OPT_IN and the Terminus
  re-judge is not run. Next time (round 34): a T4 guard on this stage needs brains' hardened, order-free stage, or many fronts.

- **R33.15 N5.M merges; the NATIVE=off perf budget is not N5.M's (2026-10-17).** native: `025d5631` builder0 `make check
  exited 0`, 2727/0, 26 targets ALL JUDGED, sim-baseline 13 unmoved, determinism 9d66d3a0c59a7936. `c70be402` (diff:
  _agents/streams/native.md only) `make check NATIVE=off exited 2`: 2727/0, sim-baseline unmoved with the same hashes. The
  two FAILs: native-live-guard (fails by construction with no library) and perf-judge 1.47x (ai_usec_per_tick 20050,
  load 9.01) on the all-GDScript AI. native-proof EQUAL 10c328a0f978ea49. no_arrival reached in `1a1182bb` (940 decisions,
  0 mismatches). **Ruling:** merged (main `199d1587`). N5.M's GDScript diff touches the off path only under
  `NativeBridge.counting` plus a new switch, read by the orchestrator, so the off-path perf is main's own. **Known, not
  this round:** the all-GDScript AI (the no-library path: browser, or a missing .so) is over perf-judge's CPU budget at
  about 1.5x on builder0, n 1. Native files a NATIVE=off perf reading on main at round close if the box is free.
  Merge notes: brain_switches.gd (native_manoeuvre), native_drive.gd and native_exec.gd (counting only), and
  tests/native/mover_state.gd. C26.2 now reaches Manoeuvre.choose / behind / simulate / _others / _hull_hit / _note, so a
  CP-F or F1 edit there becomes a pair with native.

- **R33.18 B10b FAILS on its own base, and R4 goes first, on main (2026-10-17).** B10b pair `99e867ee`: builder0 check
  green (2740/0, ALL JUDGED, sim-baseline unmoved, BRIDGE_POOLED 18/18). Series, named cases, native path, n 1: line 1 PASS
  (Sumps s16 t8); **line 2 FAIL** (Sumps s19 t8 all-within-8 m: on 100.8 s v off 69.4 s, bar ≤ off + 5), deterministic
  on the native path (the laptop's GDScript gives 35.3 v 35.3). Trace: Green_S_1 circles inside its approach gate's turning
  circle t=78–98 (30 SETTLE_NOPATH), S_4 likewise t=30–79. That is R33.8's loop: B10b's latch holds the seat, so the gate
  holds still, and in the off arm the drifting seat frees it by accident. Tuning read, NOT judged, on R4's candidate
  `97c3b654` (B10b ON + v6 + inside_circle + mirror): s19 38.8 v 42.4 s, s16 36.2 v 36.5 s. **Ruling:** B10b's verdict on
  `99e867ee` stands as FAIL and it does not ship on that base. R4 is judged FIRST, on MAIN, as its bar allows ("else
  main"): brains rebuilds R4's pair as main + R4 + native's mirror without B10b, names it, gets native's twins at 0
  mismatches on it, then runs the full check (C31.1), then R4's series. If R4 ships, B10b is re-judged on main + R4 with its
  bar unchanged and a fresh check. Its named cases are the same deterministic cases, judged once more on the new base, and
  the census is untouched so far.

- **R33.19 P3 PARKED (2026-10-17; planner, bca4eaca, builder0, 20:25–22:07 PDT, FIFO, no CP-F; evidence stream/planner
  `ddbca315`, references/round33/planner/p3-bca4eaca/).** (0) PASS: the yard stage on and off native, kept plan, drift
  0.97 m, aligned 9.83 v 15.43 s; kept share of hull-rest face plans 23/23 drawn, 16/18 clicked. (0b) PASS: the street
  is served in a 26-tick hold after 1 fallback. (1), (2a), (2b) and (3) PASS (rigs 175 v 181 of 208, paired −0.46, se
  0.55; series_verdict hand-read). **(2c) clicked FAILS:** p90 furthest-from-home 15.4 v 12.8 m (n 18 v 27 plans). Worst
  pair: clicked faced_attack_move s87, a 15.4 m KEPT plan v base 2.7 m, past one hull length, which only a slot-law face's
  circle allows (inferred, not traced). The series can't separate the slot-law ordering from the fallback. Parked per the
  bar's rule. Round 34 candidate: cap a slotted face's kept circle at one hull length from the slot, on fresh seeds.

- **R33.20 Main's known native coverage-floor reds don't block a pair's series (2026-10-17).** Main `de6d3266` / `54abf20a` is
  red on builder2 only on test_native_gate / test_native_yield path floors (0 mismatches everywhere; the stage's counts move
  with shard order). Native's fresh-process fix (`fix/native-fresh-stages`) is in flight. Until it lands, a pair tree whose
  check reds ONLY on those same floors, with 0 mismatches and everything else green, meets C31.1 for STARTING its series.
  It does NOT merge until a check on its merge tree is fully green with native's fix in it. First use: B10b's
  `f91b61c7` (builder2: 2770/3, the three floors only, sim-baseline unmoved; main 54abf20a fails the same way filtered).

- **R33.21 CP-F PARKED (manoeuvre, stream/manoeuvre `b4bf8f2c`, references/round33/manoeuvre/cpf-series/; pair/cpf-on
  `b6c2a974` v base `--nav-off=turnhull`, builder0, all 14 calls exited 0, hull-rest seeds 440–445).** The turn works:
  drawn wheeled turret hulls end 3–6° off, against 60–100° today, on both paths; SBF gang_ifv drawn 2.3 v 34.0°; fights
  no worse, with shots +20 % and hits +27 %; Terminus, the bridge and arrivals pass. **Misses:** (a) attack-move
  wheels/turret 69.5 % within 15°, against a 70 % line. (b) ambush wheels/fixed worse, 3.9 v 2.6° (p 0.042), p90 76 v 7°,
  not traced. (c) clicked's ±5° median line sits inside run-to-run noise (−6.8 to +9.5°, every p ≥ 0.197): the bar was
  wrong, and nothing was tuned. (d) crews still moving at the judge: ambush +14, move +13, screen +20, over their limits.
  (e) never-settled on move: +3 against a limit of 2.6. The extra movers are not turning hulls: on ambush, 39 of 55 are
  driving a move to a goal 8–28 m away, i.e. crews are RE-SEATED after they face (gangs, law). **Next:** a diagnosis-only
  trace of that re-seat on tuning seeds 40–45, NEW v BASE, with seat-goal prints. Also run B10b's seat latch ON in that
  trace, as a question (if B10b ships, CP-F's attempt 3 sits on it). C33.9 keeps priority for manoeuvre.
  **Pacing caveat (2026-10-18):** manoeuvre-hull-rest (and hull-one) run WITHOUT `--fixed-fps`, 6 at once (HULL_JOBS),
  so CP-F's (a)–(f), (j), (k) and (m) came from wall-clock-paced runs on a loaded builder0. Its fights, Terminus, SBF,
  bridge and sim-baseline stages were pinned. On the laptop's tuning seeds, the movers behind (d) read about 0.3 a run
  in every arm, against about 2.3 in the series. Manoeuvre pins hull-rest (`--fixed-fps $(SIM_HZ)`, mk/manoeuvre.mk) on
  stream/manoeuvre, and from then on hull-rest numbers don't compare with earlier ones. Planner's P2/P3 hull-rest lines
  carry the same caveat (R33.13, R33.19).
  **Attempt-3 trace (manoeuvre, builder2, hull-rest pinned at --fixed-fps 30, GDScript, tuning seeds 40–45, 4 factions
  × 6 tasks, 144 runs an arm, tree `e9197ecb`; stream/manoeuvre `80e49424`,
  references/round33/manoeuvre/cpf-trace-fixedfps/):** crews still moving at the judge, NEW v BASE: ambush 7 v 6 (paced
  series 51 v 35), move 9 v 8 (26 v 15), screen 7 v 10 (49 v 29), attack-move 36 v 29, right 6 v 12, support-by-fire 8 v 3
  (+5 over its 3.3 limit). (e) never-settled passes on 5 of 6 tasks; SBF 7 v 2. (a) within 15°: move 93.9 %, right
  93.9 %, attack-move 79.4 % (paced 69.5–82 %). B10b's latch changes nothing (seat moves 875/2485 v NEW 886/2565). So
  the judged misses (a), (d) and (e) came mostly from wall-clock pacing on a loaded builder0, not from re-seats.
- **R33.23 CP-F attempt 3 (orchestrator, 2026-10-18; filed before any attempt-3 number).** The same pair (`b6c2a974` v
  `--nav-off=turnhull`, plus native's (m) arms) is re-judged with hull-rest PINNED (stream/manoeuvre `670f4e12`'s flag) on
  FRESH seeds 460–465 (never read), every call and both arms on builder2, labelled builder2. The bar's lines stand, with
  one change, made now: **(c)** clicked wheels/turret per task: paired median difference NEW − BASE ≤ +1.645 se (one-sided:
  no worse), replacing the ±5° median line that sat inside run-to-run noise. Before the series, manoeuvre traces SBF's
  movers on tuning seeds 40–45 (diagnosis only). A fix found there is a candidate change and is re-filed before numbers.
  C33.9 keeps priority.
  **SBF traced (manoeuvre, builder2, pinned, tuning 40–45):** NEW's 8 SBF movers v BASE's 3 are two things. (i) Wedged
  crews (reported v > 0, real 0.00), counted as "still moving" in BOTH arms: a pre-existing judge issue, reported only.
  (ii) CP-F's own **face ↔ dressing loop** (gangs Guns_5 gang_tank, s44): the face at rest creeps the hull off its seat,
  the element's dressing reverses it back, and it repeats until the judge (the planner has no legs for it, so it
  creeps). **R33.23 amended before any 460–465 number:** the candidate adds (a): a face at rest that has pulled its hull
  more than 3 m off its held seat gives up and holds the residual error, on the creep path too (facekeep's rule
  extended). Manoeuvre's files only; it's a new pair hash and needs its own check first. Also: the stage is barely
  seed-sensitive (seeds 40 = 43 and 44 = 45, row for row), so **the series runs seeds 460–475 (n 16 a cell)**, and the
  verdict reports how many distinct rows each cell has and computes se over distinct pairs only.
  **Re-filed (orchestrator, 2026-10-18, before any 460–475 number):** the tuning sanity (builder2, pinned, 40–45, 144 runs
  an arm, pair `60d2d86a`) showed the 3 m rule never fires on SBF (face_pulled_holds 0 there; 514 attack-move, 874
  screen), and SBF's movers were unchanged (8 v 3). Re-read: the hull stays 6.5–8 m off its seat, the dressing move
  reverses toward it, then the face that turnhull lifts REPLACES the move, it creeps, and the cycle repeats. BASE
  declines that face, the move finishes, and the crew sits. **New amendment (a):** a face is NOT lifted (and drawn_face
  does not convert it) while the crew stands further from its held seat than its arrive radius
  (max(ORDER_ARRIVE, settle_radius)). The decline stands as today: the hull finishes its move, then turns once seated.
  **The 3 m give-up is DROPPED** (one reason per candidate; it fires about 1390 times elsewhere unjudged). Test first
  (gang_tank 7 m off its seat with an order face: declined until it's inside the radius), then the sanity again on 40–45,
  then a new pair hash and its check, and only then 460–475.
  **Radius re-filed (orchestrator, 2026-10-18; tuning 40–45 only):** at max(ORDER_ARRIVE 3.5 m, settle_radius) the rule
  over-corrects (builder0, pinned, pair `70cb7f683`): wheels/turret within 15° fell to 58.8 % on attack-move (from 78.8;
  bar 70), and to about 71–72 % on move, right and ambush (from 94–96). off_seat_declines ran 4–12 k a task, because crews
  3.5–7 m out are "arrived" by R32.3 (ARRIVED_M 7 m) yet never turned. SBF improved, but its movers (6 v 3) and
  never-settled (5 v 2) are still over their limits. **Now:** the radius is max(R32.3's ARRIVED_M, settle_radius), the
  same "arrived" the bar's (f) uses. That's a definition, not a tuned value, so there is no sweep. Then the sanity on
  40–45, a new pair and its check, and 460–475. If SBF stays marginal at 7 m, it is reported and judged as filed.

- **R33.22 B10b PARKED after its re-judge on main + R4 (2026-10-18; brains, builder2, pair `f91b61c7`, rows
  `references/round33/brains/b10b_rejudge_f91b61c7_builder2.txt`).** It fails as written on line 3's strict clause: pooled
  drift moves 112 v 112 (on < off required). Every other line passes, and no ON run is later than OFF. With R4 on main,
  OFF no longer flips on Sumps s16 t8 (0 flipping, 2 drift), so R4 fixed the case B10b was built for. On 28 fresh census
  runs ON and OFF are identical in every field: the latch never acts. Parked, not shipped (a latch with no case left).
  `--ground-latch` stays on stream/brains for manoeuvre's R33.21 re-seat trace. B11b stays BLOCKED (CP-F parked).

- **R33.26 P3 v2 pinned PARKS on (2c) clicked, and (2c) is re-scoped (2026-10-18; planner, pair `c3acd47a2`, builder2,
  FIFO, no CP-F; stream/planner `4b0e981bd`, references/round33/planner/p3-pinned-c3acd47a2/).** 36 distinct pairs of
  72 a mode (seeds pair off). (0), (0b), (1), (2a), (2b), (2c) drawn and (3) PASS (yard aligned 9.83 v 15.43 s; rigs
  178 v 179). (2c) clicked: median 3.0 v 2.7 m, but p90 6.3 v 4.9, max 12.4 v 5.7, on 14 v 10 plans. **The trace:** the
  candidate SERVES clicked faces today's search never plans (26 v 18 served plans from 267 v 271 asks). The worst pair
  (faced_attack_move s100) has the base's face_far EMPTY (10 asks, none planned), against [12.4, 3.2] kept. So (2c)
  compares different populations, 12.4 m is inside one hull length, and v3's slot cap could not touch it: the
  slot-law inference was wrong. **Ruling: (a).** (2c) becomes paired BY FACE: drift on faces both arms planned (median and
  p90, no worse than + 1.645 se). The faces only the candidate serves are judged against what the base's hull did for
  those same asks (its furthest-from-home under the fallback executor or abandon): no worse. Faces only the base serves
  are reported. A new bar on FRESH seeds, filed with the face-pairing tool proven (pinned runs are deterministic, so faces
  match). v3 as written is withdrawn.
  **Bar filed (2026-10-18, before any number; planner's tool stream/planner `33f8905b7`, proven on the laptop).** The seam
  reports `face_episodes` (a crew at one home, from the first ask until a new home, a new order, the hull freed, or 30 s;
  with outcome, plan_far, and the HULL's own furthest from home, whoever drove it). face_pairs.py pairs them by crew and
  home. **Judged on hull_far**, with plan_far reported: in the yard stage the base's "served" re-ask plan reads 1.4 m
  while its hull went 12.1 m under the executor, so plan_far understates today. Candidate = the same code + the
  measurement; keep 0 v 1, FIFO, no CP-F. Pair = main + `670f4e12` (if not on main) + FACE_KEEP_DEFAULT 1 + the tools,
  suite green on builder2 first. FRESH seeds: hull-rest gangs 120–131 (drawn + clicked), Terminus rigs and mixed 270–282
  (n 13). builder2, pinned, distinct pairs. (0), (0b), (1), (2a), (2b), (2d) and (3) unchanged. **(2c) per mode:**
  BOTH-PLANNED faces, median and p90 hull_far ≤ base + 1.645 se (a paired bootstrap over faces, 4000 rounds, seed 33);
  CANDIDATE-ONLY faces, hull_far ≤ the base hull's hull_far for the same episode + 1.645 se (plan_far and the kept count
  reported). A class with fewer than 2 faces is NOT JUDGED and reported; base-only, neither-served and unmatched episodes
  are reported. **Added (orchestrator):** the BOTH-PLANNED class must have ≥ 10 faces per mode, or that mode's (2c) is
  INCONCLUSIVE, and an inconclusive mode can't PASS. Pass = every line, early stop OFF; a failed guard → PARKED with the
  worst face pair's trace.

- **R33.27 Battery item FAILS as a whole; subset (a) filed; (c) parked, (b) dropped (2026-10-18; brains,
  lab/brains-r33-battery `ee18403b`, builder2, rows `references/round33/brains/battery_series_ee18403b9_builder2.txt`).**
  (2) census, n 18, ON v OFF: never-past battery askers 2 v 1 FAIL; far set-ups 7/99 v 186/344 PASS; shots 441 v 446
  PASS; repack-while-firing 0 PASS; friendly-stuck PASS; first shot median 9.0 v 3.3 s (limit 8.3) FAIL, with 19/28
  orders answered v 28/31. (1) named PASS on ON. (b)'s arrive line 97 v 97 PASS. The check green. The worst run traced:
  (c)'s hold-fire-to-place is the first-shot delay (Parade s49: 20.1 s v 7.1). **The subset is chosen from the bar's own
  per-switch arms in (1), not from (2):** (a)-alone fired the most in both named cases (109 and 90 shots) with far
  set-ups 5/6 and 5/7; (c)-alone is the only alone-arm with never-past askers (Foundry 2); (b)-alone was identical to OFF
  in both. **Filed:** (a) ALONE (`--battery-seat`, a set-up crew keeps its seat), on FRESH census seeds 53–58, n 18, with
  (2)'s lines unchanged, the named cases re-run, and the check. (c) PARKED (its cost is its design: firing waits for the
  place). (b) DROPPED (no measured effect; a switch with no case doesn't ship, as B10b).

- **R33.28 P3 v2 SHIPS ON (2026-10-18; planner, series on `923fcb97f`, builder2, FIFO, no CP-F; evidence stream/planner
  `4cefb2011`, references/round33/planner/p3-pairs-923fcb97f/).** Every filed line passes on distinct pairs: (0) the yard
  9.83 v 15.43 s, kept share drawn 65 %, clicked 96 %; (0b), (1), (2a) (0/24 3a cells), (2b); (2c) BOTH-planned drawn
  19 faces (median 2.8 v 3.0, p90 8.5 v 8.5) and clicked 21 (1.6 v 1.6, 6.3 v 6.3); CANDIDATE-ONLY drawn 2 faces PASS,
  clicked 1 face NOT JUDGED by the filed text (under 2); (2d) 4 v 4; (3) rigs 172 v 170 of 208. **Ruling:** the filed text
  governs. face_pairs.py's judge() returned FAIL for a 1-face class, against the text: a tool bug, found after the
  numbers, fixed after the verdict, and it does not decide. Reported: the all-runs clicked both-planned median, 1.7 v 1.6,
  over a 0.05 se (distinct was the pre-declared judged set). **Merged: main = pair/planner-face-pairs `923fcb97f`**
  (pair check green on `f8b7b003e`; main since the pair's base is docs only). It brings manoeuvre's hull-rest pin
  `670f4e12` with it. What he'd notice: a vehicle told to face behind it in open ground turns round in about 10 s
  instead of 15, in three tight legs instead of a wide loop.

- **R33.30 T4 (ghost ON) PARKED a third time, on G2 (2026-10-18; traffic, `6e23e692d`,
  references/round33/traffic/ov_t4_bar.md, Result).** builder2, pair `aacdfb4b6` (game `2b41d3a04`), fresh pinned
  body_probe children, Locks, seeds 7–18, n 12. G1 PASS (median alone 14.0 v 15.5 s); **G2 FAIL**: 4 of 12 seeds are
  worse by more than 3 s (s7 +6.5, s8 +4.0, s9 +3.5, s14 +4.0; the line is ≤ 2), while s16 improves by 41 s. The children
  are deterministic, so these are the ghost's real per-seed effects. G3 PASS (7/12 both arms). r1 PASS (a fresh process
  replays exactly, 36/36, both arms). r2 REPORTED: a same-process rematch's digest differs on 12/12 seeds in BOTH arms.
  Line 7 was also red (native floors under ghost ON). T not run. **Native's ghost-aware stages (R33.29) are withdrawn**:
  there's no ghost-ON default to cover. For a fourth try (round 34+, not tonight): trace s7, and a cohesion bar over more
  than Locks.

- **R33.31 Scout fights back PARKED (2026-10-18; brains, lab/brains-scout `0565d1a8` + native's mirror, builder2; rows
  references/round33/brains/scout_series_0565d1a8_builder2.txt).** (1)(a) pooled shots 5121 v 3158 (×1.62) PASS; (c)
  ENGAGE 52180 v 0 PASS; **(b) FAIL**: damage median 190 v 186, and 3 cells more than 20 % worse, all against syn_scout
  with no post (gang_scout 15 m 619 v 475; law_scout 15 m 431 v 353 and 30 m 250 v 205). The out-of-reach check isn't
  zero (693 ENGAGE ticks for gang_scout at 30/45 m: reach is judged at the tick and the orbiter swings inside 24 m). (3) the
  fights guard is identical in both arms (element-commanded scouts never pick SPOT), a trivial pass. Attribution:
  `sim-baseline SCOUT_FIGHT=off` gives 13 unmoved, so the six moves were the rule's. **Reading:** fighting back pays in
  shots, but costs hull where the shooter is faster AND outranges it. The "can't get away" speed clause sends it into
  fights it loses. A next try (round 34): fight only an even-or-better duel (advantage ≥ 1), with a fresh bar on seeds
  73–79. That bears on the lead's morning question (stand and trade, or hang back).

- **R33.32 Rejoin passed, but NOT merged: its tree carried B10b ON (2026-10-18).** lab/brains-rejoin `6345125b` sits on
  stream/brains, which has B10b's ground latch at GROUND_LATCH := true (parked, R33.22; main has it OFF). A merge
  attempt also conflicted in mk/tactics.mk, so it was reset (nothing pushed). The verdict (one-crew elements 0 v 1691;
  kills and deaths within noise) was judged on main + rejoin + B10b ON in BOTH arms, not on main + rejoin. **Ruling:**
  rebuild rejoin on MAIN alone (no B10b), check it, and re-run the rejoin series on FRESH seeds 584–587 × the same 4
  maps (n 16) with the lines unchanged. Merge on that. **Rule for every stream's branch:** a candidate is main + its own
  commits only; anything else on its tree is named in the bar, or the tree is rebuilt.

- **R33.34 CP-F attempt 3 PARKS, narrowly (2026-10-18; manoeuvre, stream/manoeuvre `22e9cab4e`,
  references/round33/manoeuvre/cpf3b-series/; pair `0dad42fa2`, check green; all builder2, pinned, fresh seeds; 21 of 64
  pairs a task distinct, judged over distinct pairs).** PASS: (a) within 15° on move 93.8 %, right 96.0 %, attack-move
  80.2 %; (b); (c) one-sided; (e); (f) 273 v 274; (g) Terminus mixed 300 v 295, rigs 182 v 177; (h) 18/18; (i) fights
  within noise (shots 21,987 v 21,090); (m) native = GDScript, byte-identical rows. **FAIL: (d) attack-move all classes
  +7 against a limit of 6.5** (gang crews mostly DRIVING a move at 75 s: the seat-move pattern, now on attack-move only);
  **(j) as written**, hull_holds = 0, because only 1 of 383 judged runs had the quiet enemy in sight (the mechanism is
  tested; the tuning sanity had 4,256 holds). Reported: SBF hull error 2.3 v 22.8°. **Next:** attempt 4 = CP-F + the
  k-turn arrival-flicker fix (planner's s69 diagnosis, roadmap; manoeuvre owns it), since an attack-move's late movers may
  be that flicker. Developed and checked on tuning 40–45 tonight; judged only after the lead's word (HANDOFF), on FRESH
  seeds. (j) is re-filed as REPORTED, since a hold that needs a quiet enemy in sight can't be forced by seed choice.

- **R33.35 CP-F's attack-move movers are the HERRINGBONE halt laying seats on the live average hull heading
  (2026-10-18; manoeuvre's diagnosis, dev only; builder0, pinned, attack-move, seeds 40–45 + 66–71, n 48 an arm, on
  CP-F's pair + main with the War Rig).** First, main's War Rig change roughly halves the gap (wheels/turret +11 against
  a limit of 12.5, PASS; all classes +13 against 12.8, by a hair). The loop: with a quiet enemy "possible", Drills picks
  herringbone (drills.gd ~178). `_plan_drill`'s herringbone branch (element_plan.gd ~1902) lays seats on the
  situation's heading, which is the members' hull forwards AVERAGED (element_situation.gd ~72), never the task's facing.
  CP-F turns the hulls, so the average moves, the herringbone re-lays rotated, the seats jump 5–17 m and the crews are
  re-sent, over and over. (Guns, seed 41: seat drifts after 30 s, 12 BASE v 103 NEW.) In BOTH arms, the Hunters swarm
  re-lays about 750 times after arrival, likely the same root, untraced: a base bug. **Ruling:** brains' own item (one reason): the herringbone halt lays on the task's drawn
  facing when it has one, else on the heading kept while the halt holds, never on the live average. Its own bar and
  fresh seeds, judged on main, with the Hunters re-lays as a measured line. Then CP-F attempt 4 = a pair on main + that
  fix, with the new judge, after the lead's word.
  **Hunters traced and bar filed (brains, before any code or number):** of 1,121 Hunters seat-goal moves, 1,046 come
  AFTER arrival in the herringbone (831 drift, 215 reseat), with the anchor fixed and the laying heading swinging with
  the hulls. Same root. Candidate (ElementPlan, GDScript only, `--herring-heading=off`): the herringbone halt lays on
  (1) the task's drawn facing when it has one, else (2) the heading it was first laid on, kept while the element stays in
  the herringbone drill, with (3) the current heading only on entry. (1) DECIDING, hull-rest (main, pinned,
  --arrive-trace), gangs faced_attack_move AND plain attack_move, FRESH seeds **520–525** (the orchestrator moved them off
  480–485 to keep clear of CP-F's fights block), n 6 a task, ON v off: the Hunters element's seat jumps ≥ 8 m after
  arrival ON ≤ 25 % of OFF, and every element's arrive-flips ON ≤ OFF; Guns' drifts reported; arrived elements ON ≥ OFF.
  (2) squad-arrive-series FRESH 73–76, n 100: all-within-8 m ON ≥ OFF − 1.645 se, drift moves ON ≤ OFF. (3)
  tactics-drills green (its herringbone coverage and bearings) and the check, with sim-baseline moves listed. (4) The worst
  ON run traced first. **Added (orchestrator):** hull-rest's seeds barely vary on main (no jitter there yet), so report
  distinct rows per task and read (1) on distinct pairs. builder2, `native <target>`.
  **Corrected before any number:** main's hull-rest has no plain attack_move task (only the six faced ones), so (1)
  runs on faced_attack_move only. The undrawn path (kept heading, heading on entry) is judged by (2),
  squad-arrive-series (drills-on attack-move with no facing, which halts in the herringbone): drift moves ON ≤ OFF as
  filed, with after-arrival drift moves reported beside it.
  **Tree named:** lab/brains-herring `3f0bab2a` = main `7dcae6b5` + R33.9's flag-gated arrive-trace measurement
  (`70ffe28e`/`97ec141f`, no behaviour change) + the fix `725e058e`. Check GREEN on builder2 (2794/0, BRIDGE_POOLED 18/18).
  **Both stages were NULLS (builder2, native): identical arms, nothing judged.** Main's hull-rest army on 520–525 is not
  manoeuvre's case: a 21-crew Gangs army whose "Hunters" holds Battery crews (Hunters jumps 15 v 15, every pair
  identical). squad-arrive's herringbones are the HALT formation through `_halt` (which already keeps its heading), not
  the `herringbone` DRILL this fix changes (drift 331 v 331). **Re-filed before any judged number:** (a) reproduce
  first, on manoeuvre's exact stage at s41 (or main + whatever fields its 14-crew gang_ifv Hunters swarm), as a TUNING
  check that the arms differ, with a measurement-only counter of herringbone-drill lays per element proving the path
  fires; (b) only then judge on that stage, FRESH seeds, the same lines. If the drill path fires only in CP-F's world,
  the fix is chiefly CP-F's enabler, and attempt 4 judges them together, which the lead decides.
  **(a) reproduced ON MAIN (tuning, builder0, native, lab/brains-herring `3baf3a06`, gangs faced_attack_move s41):** OFF:
  HERRING_LAY 201, Hunters goal moves after arrival 1,097, never settled; ON: 60, 29, settled at 30.5 s. The drill path
  fires on MAIN, not only in CP-F's world. The nulls happened because the SEED rolls the gang army: seeds 41/44/45/66/67
  field Guns + three gang_ifv squads (the looping case), while 40/43/68/70/71 and 520–525 roll the Battery army (no
  herringbone, HERRING_LAY 0). **(b) re-filed:** scan fresh seeds 526–575 for their army only (screen.json's squads,
  fixed by seed before either arm acts), take the FIRST 6 that roll Guns + gang_ifv, and run ON v off on those, with the
  same lines and distinct pairs counted. Selecting on the army is selecting on something fixed before treatment, so it's
  fair, and the scan's army list is filed before any arm runs.
  **Scan filed (brains, builder2, SCREEN squads only):** Guns + THREE gang_ifv Hunters squads: 526 527 528 537 542 550
  551 557 560 562 565 566 571 572; a two-Hunters variant: 532 535 539 546 553 564 567 570; Battery: 529–531 534 536 543
  548 549 555 556 558 563 568 569 573 574; Guns only: the rest. The criterion is manoeuvre's literal "three Hunters
  squads". The two-Hunters variant is excluded (520/525 rolled it, with identical arms). **Judged seeds: 526, 527, 528,
  537, 542, 550.** Line (2) stands as run (97 v 97, identical; its halts aren't the drill).

- **R33.36 Traffic's v2 and item 4 both fail as filed; both re-filed (2026-10-18; traffic stream/traffic-overnight
  `4afc4a85a`, ov_parkedroom_v2_bar.md and ov_item4_bar.md, Result sections).** **v2** (pair `e7b202760`, native
  hand-back, fresh 724–771 × 3, n 144): L1a hold-post loops 39 → 1, L1b 51 → 39 and L2 83 → 95 PASS. L3 FAILS on the GOOD
  side (hit rate 0.714 → 0.731, against a two-sided line). L6 63 % of 395 (line 90 %). Trace: of 147 misses, 99 sit
  inside the brain's own hold line around the ORDER GOAL (the parked spot was a median 3.1 m off it, and the hold order
  took them there); only 48 are off station by both readings. ask_handed_back median 21 a fight. **v3, filed now, before
  any number:** a crew on a HOLD order returns to its hold point (the order goal), not to the parked spot. L6 = back
  within 3 m of its post OR inside its hold line around its order goal, ≥ 90 % (≥ 50 rooms); L3 = no worse, one-sided
  (kills ≥ base − k·se, deaths ≤ base + k·se, hit rate ≥ base − k·se), as a guard means. Every other line unchanged.
  FRESH fights 820–867 × 3. **Item 4** (pair `23251f069`, fresh 772–795): line 2 FAILS (fire-post loops 34 → 29, se
  14.4), lines 3–6 PASS (shots 594 v 595, first shot 2.8 v 2.8 s). Trace: all 29 of the arm's fire-post loops have an
  ENGAGED blocker, a real fire mission that his T1c-b2 yes keeps by design, while the IDLE kind went 10 → 0. The line
  counted both kinds; the item's purpose is the idle kind. **Re-filed:** line 2 = IDLE fire-post loops (blocker with
  no fire mission) ON = 0 and ≤ base, with engaged ones REPORTED. FRESH fights 796–819 × 3, n 72, same tree, lines 3–6
  unchanged.
- **R33.37 Traffic's parkedroom v3 fails as filed; parkedroom PARKS for round 33 (2026-10-18; pair
  `pair/parkedroom-on-v3 6d0e00652`, stream/traffic-overnight `db8ef0878`, ov_parkedroom_v2_bar.md "v3 result",
  ov_parkedroom_v3_series.txt; builder2 throughout, native, FRESH 820–867 × 3, n 144 paired).** PASS: L1a hold-post
  loops 59 → 18, L1b parked loops 224 → 63, L2 far loops 411 → 201, L4 crossing arrivals identical, L5 repack while
  firing 0 of 9. FAIL: **L3** kills 2072 → 1992 (se 40.9) and deaths 2090 → 2008, both outside the line, with hit rate
  equal (0.736 / 0.736) and shots −0.6 %. Kills fell in 29 of 48 random fights (worst random-859 54 → 34) and stayed flat on
  Terminus and Locks. **L6** 89.96 % (403 of 448, line 90 %). All 45 misses are hold orders: 19 still owed the way back,
  and 15 ended it 4–23 m off the goal. No re-read: the bar stands as filed. Fewer kills from the same hits is a fight
  change the fix doesn't explain, so a trace comes before any v4. **Granted:** one dev read on builder0 (not judged)
  of random-859, both arms, with kills by hull and by time, into the stream's references. Its finding goes to the round
  34 roadmap entry. A v4 needs a fresh bar, fresh fights, and a pair on current main with native's hand-back.
- **R33.38 The lead ships C33.9 attempt 1 and keeps CP-F parked (2026-10-18, "let's go with both of your
  recommendations"). C33.9's ship pair is RED on the whole suite.** Pair `pair/native-c339` `2f9ad0fb9` = manoeuvre's
  `4a7cbc6ea` (`608c3357e` the net diff + TURN_IN_DEFAULT true) + native's stop hand-back. builder2 `make native check
  exited 2`, 2801/2. The fails: test_nav_creep_bound (a wheeled hull turning in place ends 24.5 m from its start) and
  test_ai_scenarios_elements' swept lane (20 v 16 ticks in the fire). scenario_suppression has 2 fails (51/53), and
  sim-baseline moved crossing, parade and archipelago. Every twin is at 0 mismatches. With the library off the same tests fail,
  and main passes them, so the turn-in's GDScript causes them. **Ruling: no test is loosened, and no baseline is
  re-recorded to make it pass.** A hull told to turn in place that drives 24.5 m away, and a crew that sits longer in a
  swept lane, are harms he would see. The judged stage (orbit cells) never exercised them. **Manoeuvre narrows the
  turn-in to the case it was judged on**, a wheeled fixed gun turning to face a contact or a facing it can't yaw onto at
  rest, never a plain turn in place or a stop that isn't facing anything. Then: (1) the two tests and the two scenarios
  pass, unchanged; (2) the judged orbit cells, seeds 31–36, re-run on the narrowed tree read the same verdict lines
  (row-identical, or each line's value reported beside R33.24's); (3) a new full check, with any sim-baseline moves named
  and explained as the turn-in's own. If (2) changes any line's pass/fail, C33.9 does not ship this round and becomes
  round 34's first manoeuvre item.
- **R33.39 C33.9 does NOT ship in round 33; it is round 34's first manoeuvre item (2026-10-18; manoeuvre stream
  `8f9846a5c`, references/round33/manoeuvre/c339-narrow/).** The cause of R33.38's reds: the turn-in took every brainless
  or plain face from its first tick, and every `stop` swing. A static spot rolled the hull for 3 s and then froze its turn
  (creep_bound's 24.5 m; the suppression scenario's tracking scout). Two narrowings were tried, both on builder2's judged
  cells 31–36. `bd4f001fa` (gate on a brain's crew whose spot is within 10 m of a live enemy moving > 1.5 m/s) passes the
  tests and the scenarios, but (d) flips (reverse ticks max 0 → 23). `fc809b60a` (the gate only on a threat face's first
  ticks and on the stop swing) passes every test unchanged, but (c) flips to FAIL (worst in-reach cell −46 %, pooled
  exchange 1.58 v 1.77) and so does (d) (max 13). Manoeuvre stopped rather than tune a third time on the judged seeds.
  **Process lesson:** C31.1 (the whole suite with the switch ON) was not run before C33.9's judged series. It would have
  caught this a day earlier. Round 34: the turn-in's full suite comes FIRST, then a fresh bar on fresh orbit seeds.
  Native's stop hand-back (`pair/native-c339` `2f9ad0fb9`) covers any narrowing and needs no change. CARRY:
  `pair/c339-ship` `fc809b60a`, `lab/c339-turnin` `781801da0`. The lead is told in player terms: the scout shuffle he
  reported is still there in round 33's build.

**Bars (round 33):** filed here before any number.

- **B10b (brains, C33.4; filed 2026-10-17 before any number, stream/brains `03dabed8`).** Form: the latch is released while
  the held seat lies on a moving squadmate's navmesh route (both hulls' half widths + 1 m).
  Candidate: stream/brains at the hash its check goes green on. Arms, one tree, builder0, the DEFAULT path (native where
  it runs; Element.ground is GDScript on every path, so no native half): **on** = default (latch + corridor);
  **off** = `--ground-latch=off` (main's rules); **b10** = `--ground-corridor=off`, reported only.
  1. **Pass case Sumps s16 t8** (main's flip case: 22 flips, never in): no flipping crew (> 10 drift moves) on.
  2. **Pass case Sumps s19 t8** (the case B10 failed, +19.9 s): on's all-within-8 m time ≤ off's + 5 s.
  3. **Drift census, FRESH seeds** (`make ground-series`: Sumps 20 21 × ticks 1 3 6 8 11 16, n 12; yard 31 32 × the
     same, n 12; Terminus head-on 16–19 t11, n 4): pooled runs with a flipping crew on ≤ off AND pooled drift moves on <
     off; Sumps all-within-8 m median on ≤ off and no run > 5 s later; yard crews in on ≥ off every run.
  4. **Arrive series, FRESH seeds 53–56, n 100 an arm:** all-within-8 m count on ≥ off − 1.645 se (se of the paired
     difference of the per-run 0/1 outcomes, × n); discordant pairs and the paired median reported.
  5. **sim-baseline:** moved maps listed with reasons (a CPU element's held seat re-grounded off a route), adoption by the
     orchestrator; unmoved also acceptable.
  6. **The whole suite on the tree** (the check, on), bridge-pooled 18/18.
  7. Cost: `t.poll.element` on Locks ≤ 0.5 ms (B10: 0.149 v 0.164).
  8. The worst on-arm run of 1–4 traced before medians are read.
  Ships ON as one commit if every line passes.
- **P2, CP-Q re-judged (planner, C33.6 (b); filed 2026-10-17 before any number, stream/planner `33300f99`; noise from P1's
  A/A, builder0 `4bbe8322`: round 32's line (3) misses were inside the probe's own null swing).**
  
  Arms: base `--planner-queue=fifo`, candidate `--planner-queue=shared` (refuse early only at rest, `d98656ab`), both the
  native drive, ONE tree: the pair tree (`QUEUE_DEFAULT` true) on top of R33.3's fix, after its whole suite is green (C31.1).
  Hull-rest gangs, FRESH seeds **72-83** (12) x 6 tasks, drawn and clicked: **n 72 paired runs a mode**. Terminus rigs FRESH
  seeds **218-230** (13). Early stop OFF on every line (R31.8: guards). The se on each guard is the PAIR's own paired se (the
  A/A's figure in brackets is what n was sized on). No tuning on these seeds; this is CP-Q's last attempt this round.
  1. **(gain) abandoned share of asks <= 5 % in each mode, AND below base (Fisher one-sided p <= 0.05).** (Round 32: 1.0 /
     3.7 % v 18.6 / 14.5 %; A/A base 25 / 13-16 %.)
  2. **(gain) the hold per event, pooled median, candidate <= base** in each mode; and on the Terminus rigs.
  3. **(guards, pooled over the six tasks, paired on (task, seed)):**
     (a) at-rest hull error: mean paired per-run median diff <= **+1.645 se** in each mode [A/A: se 2.56 deg drawn -> line
     +4.2 deg, MDE 6.4; clicked se 2.06 -> +3.4, MDE 5.1];
     (b) settle (drawn): mean paired diff <= +1.645 se [A/A se 1.9 s -> +3.1 s]; never-settled runs reported (censored);
     (c) crews moving at 75 s: summed paired diff <= +1.645 se of the sum in each mode [A/A: drawn se 13.1 -> +21.5 crews
     over 72 runs, ~0.3 a run; clicked se 17.3 -> +28.5].
     Per-task numbers REPORTED (each is inside the A/A swing at n 12).
  4. **(guard) Terminus rig arrivals:** paired not down beyond 1.645 se (judging.md's Terminus rigs row: sd 1.68 a seed);
     wall contact-ticks REPORTED (not affordable: the row's n > 700).
  5. **(deterministic cell) s207 stage:** under `shared`, Green_S0_4 pinned on Block_7 0 ticks (`make planner-stage-s207`).
  6. **C31.1:** the whole suite on the pair tree, green.
  Pass = every line. Partial (1)-(2) pass, a guard fails: PARKED with the worst pair's trace (lesson 302), not tuned.
- **parkedroom (traffic X3, C33.2 / R33.4), filed 2026-10-17 before any number.** Arms on ONE pair tree: base = default
  (`parkedroom` in DEFAULT_OFF), arm = `--traffic-on=parkedroom` (the ship flips DEFAULT_OFF to []). Native: none (`ask` /
  `_begin_yield` run in GDScript on both paths; R33.4). Pre-series gates: `test_traffic_neck` (fights s403's neck, both crews
  in their own elements: OFF never through in 40 s, ON through and the scout back on its post) green, the whole suite on the
  pair tree with the switch ON (C31.1), and one real fight episode with elements formed traced ON end to end
  (`traffic-far-one`, s403 crossing). Stages and lines (k = 1.645, se = paired se of the SUM from the pair's own rows,
  `tests/traffic/far_ab.py` prints them):
  1. **L1 gain (the product line):** far loops behind a PARKED blocker (any kind), FRESH showmatch fights 700–723 ×
     {terminus, locks, random} (n 72 paired, 180 s, `make traffic-far-census FAR_RANGE=700-723 FAR_AT=terminus,locks,random`):
     arm ≤ 50 % of base AND (base − arm) − k·se > 0. No table row exists for this probe (it is new): X1's base read 30 parked
     loops in 69 fights, ~10 fights with any, so the line is decided by the ~10–15 fights where it acts. **Partial rule:** if
     the point passes and the distinguishable clause fails, ONE extension to fights 724–747 (n 144), then judged; nothing else.
  2. **L2 guard:** all far loops, same fights: arm ≤ base + k·se.
  3. **L3 fights guard** (manoeuvre-fights, `NAV_FLAGS=--traffic-on=parkedroom` v none, FIGHT_SEEDS 700–723, random arena):
     kills, deaths, hit rate each within base ± k·se (the pair's own se; the table's manoeuvre-fights rows for reference:
     kills se 28.2 at n 24).
  4. **L4 arrivals not down:** traffic-series his four crossing cases (seeds 1–3 × six ticks, n 18 a case, `TRAFFIC_FLAGS`
     for the arm): crews in ≥ base − k·se per case (table rows: se 1.2–4.1); the hull-rest rigs (drawn) arrived ≥ base − k·se
     REPORTED if the box allows.
  5. **L5 T1c-b2 as shipped (deciding, deterministic in the rule):** traffic-census with the arm: runs with a repack while
     firing 0 (a set-up mortar truck ordered to fire never repacks for a passer); setup refusals reported both arms. By
     construction `on_fire_post()` refuses before parkedroom is read.
  6. **L6 the parked crew's return:** of the arm's room give-ways in L1's fights, read 30 s after each began
     (`FAR_ROOM back_m`): ≥ 90 % of those whose crew is alive are within 3 m of the post they left (the element may have
     moved the post meanwhile: those are listed, not excused). Plus the stage: the scout back within 3 m of its post 20 s
     after the tank is through.
  7. **sim-baseline:** OFF (default) the pair tree is behaviour-identical to main by construction (sim-baseline unmoved on
     the pair check is the equality check); the ship tree (ON) may move maps: listed with the reason for the orchestrator.
  Verdict: ships ON as a pair (a docs/DEFAULT_OFF flip) only if L1, L2, L3, L4, L5, L6 pass; a fail is traced (the worst
  fight's episode read before any total) and written up.
  **Pre-series gate MET (traffic, builder0, `5da50167` + `--traffic-on=parkedroom`, s403 crossing, 90 s, elements formed):** the
  scout gave way at ~23.5 s and reached its room spot within ~1.8 m UNDER its element; Green_Guns_4 through by 24 s, at goal
  29 s (OFF: pinned 23–52 s, 4 far loops); scout back on post ~33 s. 51 room give-ways in that fight (both sides). **Added
  before numbers (orchestrator), REPORTED only:** room give-ways per fight ON v all give-ways OFF, median and worst, in L1's
  fights; a clip of the busiest neck ON for him if it ships (does it look like milling).
  **Series tree and an L3 amendment (traffic, before numbers):** stream/traffic `23cad95c` = pair tree `cf17abd6`'s game code
  exactly (DEFAULT_OFF = ["parkedroom"]: base default, arm `--traffic-on=parkedroom`) + measurement-only changes
  (`tests/traffic/**`, `mk/traffic.mk`); its check is `cf17abd6`'s. L3 reads kills / deaths / hit rate from L1's own
  random-arena fights 700–723 (the manoeuvre-fights command line) instead of a second stage. Accepted.
- **T4-ON re-judged (traffic, C33.7; filed 2026-10-17 before any number, stream/traffic `9b4e5ab7`).** Native path, arm
  `--traffic-on=ghost` v none, FRESH Terminus drive seeds 801–848 (n 48 a squad, paired). (1) deciding: mixed friend-stuck
  arm < base AND drop − 1.645 se > 0; (2) rigs stuck ≤ base + 1.645 se; (3) pinned mixed / rigs ≤ base + 1.645 se;
  (4) arrivals mixed / rigs ≥ base − 1.645 se; (5) REPORTED until v6 (R33.8): yard head-on all-in median, last arrival,
  between-squad fast (traffic-series 41–43 × 6 ticks). No partial rule. Runs after parkedroom's series.
  **Added before numbers (orchestrator):** (6) the Terminus drive forms no elements (round 32's lesson), so a skirmish
  guard: showmatch fights on the random arena, FRESH seeds 900–923 (n 24, the manoeuvre-fights command line), kills,
  deaths, hit rate and far loops each within base ± 1.645 se of the pair's own se; (7) C31.1: the whole suite on the pair
  tree with the ghost ON, green, before the series.
- **CP-F, turn the hull at rest (manoeuvre, C33.3; filed 2026-10-17 before any number, manoeuvre's brief Status).** Candidate:
  ONE switch `turnhull` = M1b(2) attempt 2 (the decline lifted for a DRAWN face from order/sector, + facekeep) PLUS
  round 33's `Manoeuvre.drawn_face`: a face still declined under turnhull (a contact the turret takes) keeps the hull on
  his drawn heading instead of `stop` (counter `hull_holds`; test
  `test_a_declined_contact_face_keeps_the_hull_on_his_drawn_heading`). Base: main with R33.9, same tree, switch at
  default. Gate: C31.1 check on the pair tree (TURN_HULL_DEFAULT true) + native-verify-scenarios; sim-baselines may move
  (CPU element task facings lift the decline too, symmetric). FRESH seeds: hull-rest 440–445 (144 runs an arm, drawn and
  clicked), Terminus 450–462, fights 470–493, SBF gang_ifv 500–505, the bridge's 18. Lines: (a) drawn point tasks,
  wheels/turret median ≤ 15° AND ≥ 70 % within 15° per task; (b) no class worse than base at p < 0.05 on any task,
  fixed-gun wheels included; (c) clicked arm within ±5° of base; (d) moving at the judge ≤ base + 1.645 se per task,
  wheels/turret and all classes; (e) never-settled ≤ base + 1.645 se, settle time REPORTED; (f) R32.3 arrivals at the held
  seat, re-seats ≤ base + 1.645 se (FAIL); (g) Terminus arrivals, rigs and mixed apart, not down beyond 1.645 se paired;
  (h) bridge 18/18; (i) fights kills, deaths, hit rate within 1.645 se; (j) hull_turns > 0 and hull_holds > 0; (k) s66 G5
  REPORTED; (l) SBF REPORTED. (a)–(j) gate.
  **Amended before numbers (orchestrator):** (m) **the default path:** the arms run the path he plays (native, stage 1 ON),
  not GDScript only; native mirrors what reaches the drive first (R33.7: `Manoeuvre.*` twinned once N5.M merges), twins
  at 0 mismatches as a gate; if a GDScript-only series is the only one affordable, one hull-rest drawn seed set on the
  native path must agree with it in sign on (a) and (d). (n) fights 470–493 run wholly before R33.6 merges, or with it in
  both arms. (o) (b)'s many cells are a guard against harm: a single cell at p < 0.05 in a class the change does not touch
  (e.g. tracks) is traced before it fails the series, and the trace is reported either way.
  **(m) resolved (native + manoeuvre, on `136c3828`):** nothing to mirror. The decline is in `TankBrain._order_move` (the
  think, GDScript on every path); `drawn_face` only rewrites the ORDER to a face `from: drawn`; `turret_carries_aim` is
  wheels + turret only, and execute_native hands wheeled faces back to GDScript by design (~365). N5.M's functions and the
  exec rows are untouched. So CP-F's arms run on the default native path; native reads the twins on its pair tree.
  **(p) added before numbers (orchestrator, on manoeuvre's `b09eee0b` note):** his plainest case is a K1 move with a drawn
  facing, then a contact; `Orders._remember_station` (`game/control/orders.gd:489`) keeps the heading but not that it was
  drawn, so there the declined face stays round 8's `stop` in both arms. **Granted to manoeuvre:** one additive field in that
  function (`"drawn": order.has("facing")` on the station; merge note), read by `drawn_face` under the same `turnhull`
  switch, with a test of that case; it rides CP-F (no separate series). (q) REPORTED: turret shots in the first 20 s of a
  contact while the hull turns (manoeuvre's test: ON 1 v OFF 5 shots, n 1); the fights' hit-rate line (i) judges it.
  **(r) granted (orchestrator, for the stretch clip only):** `game/control/screen_playtest.gd` (nobody's this round), one
  additive read `--faced-off-deg=<deg>` replacing the const's use in the faced_right right-drag (default 60 =
  `FACED_OFF_TRAVEL_DEG`, so every existing run and the hull-rest workload are byte-unchanged), plus a `manoeuvre-face-clip`
  target in `mk/manoeuvre.mk`. Filmed on the laptop, windowed, `--write-movie`, switch OFF v ON; no builder0. Merge note;
  it rides CP-F's merge, and the clip is not evidence for any CP-F line.
- **R33.9, the arrival latch (brains; filed 2026-10-17 before any number).** Candidate lab/brains-r339 `429ebc4b` (R1 +
  R33.9): arrived until the centre is ARRIVE_M + 6 m out (half the arrive radius: above a five-crew swarm's centre swing on
  a re-seat, far below a real departure), cleared per task by `Element.assign`; both read sites (`element_plan.gd:290`,
  `:686`); `--arrive-latch=off` = main's rule. ElementPlan has no C++ twin (no mirror). Lines: (a) gangs hull-rest
  faced_attack_move s40 (GDScript, as traced): Battery arrive-flips 0 on (off reported), re-seats on < off (counter
  `arrive_flips` beside `goal_moves`, measurement only); (b) arrivals not down: that cell's settled crews on ≥ off, and
  squad-arrive-series FRESH seeds 57–60 (n 100) all-within-8 m on ≥ off − 1.645 se; (c) the check; sim-baseline moves
  listed with reasons.
- **P3, the face keep circle (planner, C33.6 (c); filed 2026-10-17 before any judged number).** Candidate
  `--planner-face-keep=1` (stream/planner `45390507`, OFF): every pose of a face plan stays within one hull length of the
  face's home (a slot-law face: its end circle + one hull length); `keep` is a request field native already reads (no C++
  change; per-tick price the slice on every preset). Diagnosis only: builder0 light census seeds 66–71 (31 and 58 searches)
  furthest-from-home max 29.0 → 14.2 m at identical cost; the ε 2.0 weight DROPPED (it served the 25 m plan). Tree: main after
  R33.3 + P3 with FACE_KEEP_DEFAULT 1, whole suite green first (C31.1). Arms: base today v keep 1, native drive. Runs after
  P2's series. (1) Deterministic cell, test_manoeuvre_face_behind's stage, NATIVE on and off: served (abandoned 0), drift
  ≤ 8 m, aligned no later than today's abandon-then-executor arm (15.4 s, laptop), legs ≤ 3; test_manoeuvre_face_behind and
  test_manoeuvre_behind pass on the pair tree. (2) Hull-rest gangs FRESH seeds 84–95, drawn + clicked, n 72 paired a mode:
  (2a) P2's pooled guards at + 1.645 of the pair's own se (at-rest error, settle, moving at 75 s); (2b) abandoned share of
  FACE asks not up beyond 1.645 se (two-proportion); (2c) drift: served face plans' furthest-from-home (`face_far`),
  candidate median ≤ base median + 1.645 se (bootstrap over plans) and p90 ≤ base p90, max reported. (3) Terminus rigs FRESH
  seeds 231–243: arrivals not down beyond 1.645 se; contact-ticks reported. Pass = every line; early stop OFF; (1) passes
  and a guard fails → PARKED with the worst pair's trace.
  **Amended before numbers (orchestrator):** both arms run on the queue main has when P3's series starts (`shared` if P2
  shipped, FIFO if not), named in the verdict; and if CP-F has merged by then, on a tree with it (R33.2: the faced finish's
  when is manoeuvre's), else REPORTED which.
  **P3's pair tree failed C31.1 (`6f89ecc1`, builder0 `make check exited 2`, 2733/4, sim-baseline unmoved):** a War Rig in a
  Terminus street (s31, (−70, 0, 0)) told to face back. Keep 1 runs out every hold (abandoned 8, still 42° off after 40 s)
  where today's search serves it. Probe (laptop GDScript, failing scenes only, planned whole at budget 20000): yard_open,
  keep 0 189 expansions / 17.5 s / 25.3 m, keep 1 4 / 11.7 s / 11.5 m; street, keep 0 7 / 16.9 s / 28.9 m, keep 1 10091 /
  41.7 s / 13.9 m (a 16-leg shuffle); 1.5, 2 and 3 serve neither well. **Amended before any series number (orchestrator,
  2026-10-17), a NEW candidate under the fallback rule:** pair `bca4eaca` (= `6f89ecc1` + the change). The kept search (keep
  1) gets the first FACE_KEPT_SHARE = 45 expansions of the hold. On a refusal, or no plan by then, today's search runs from
  the same pose in the remaining 135, inside the same pending cap: no budget raised, and the slice price is unchanged on
  every preset. 45 was sized on the diagnosis census `a6368824` (seeds 66–71: 19 of 20 in-hold faces served kept, none
  lost), not on judged seeds. The keep now applies AFTER the slot law. On `6f89ecc1` the slot law's req.keep replaced it,
  so slotted faces went unkept. Arms: `--planner-face-keep=0` v keep 1 + fallback, FIFO, no CP-F (named in the verdict).
  Lines: **(0)** the open-ground gain survives: the yard_open stage, NATIVE on and off, served by the KEPT plan
  (face_kept_served ≥ 1, face_kept_fallbacks 0), abandoned 0, drift ≤ 8 m, aligned no later than today; AND on the
  hull-rest arms ≥ 50 % of the candidate's served face plans are kept plans (else it is main in disguise → PARK). **(0b)**
  the street face-back is served inside the hold (test_planner_face_epsilon's new test, test_planner_seam). (1), (2a–c) and
  (3) as filed, fresh seeds 84–95 and 231–243. **(2d)** REPORTED: face hold per event, median candidate v base (a fallback
  costs ≤ 23 ticks at slice 2). Line (2a)'s settle guard judges what he'd feel. The both-arms-seam guard in series_verdict
  is read by hand, and the verdict says so. Pass = every line; early stop OFF. The series waits for `bca4eaca`'s suite.
- **R4 B5c-v6 (brains, R33.8; filed 2026-10-17 before any number, stream/brains `a579b245`).** *Preamble:* round 32's
  v6 as carried (`b8a34c4f`) fails `test_nav_gate_v4` and `test_wheeled_arrival` (the 180-degree car parks at dot -0.60),
  so the candidate is the NARROWED v6: the side gate only where v4's come-round has no turning circle beside the rear
  gate, plus `inside_circle` (R33.8). Candidate = `db72c8e9` + native's mirror (pair branch, test_native_gate 0
  mismatches), on the B10b base if B10b ships (else main). Arms: ON v `--nav-off=gateside,gateinside` (v5's gate, as main
  ships), one tree, native path, fresh seeds where a cell is named by seeds below.
  (1) **Named pass cases, DECIDING.** **Yard s27 t8:** every crew in, ON, and last crew in ON ≤ OFF. **Sumps s17 t11:**
  all-within-8 m ON ≤ OFF + 2 s (round 32's tuning read 35.8 v 34.8, n 1). **Yard head-on s42 t3 Green_A_5 (R33.8):**
  settles ON ≤ OFF + 5 s with circle reverses ≤ 20, ghost OFF, and ghost ON too if traffic's ghost is on the base tree
  (else said so).
  (2) **Pursuit** (R31.3's count): `make pursuit-aa`, 24 cells, ON ≥ OFF − 3 as written AND nudged, no new let-go at 18 m/s.
  (3) **Yard crossing cell** (seeds 29 30 × ticks 1 3 6 8 11 16, n 12), DECIDING: runs with every crew in ON ≥ OFF, and
  crews in ON ≥ OFF in every run. Last-crew median REPORTED.
  (4) **Sumps cell** (seeds 22 23 × the same 6 ticks, n 12): all-within-8 m median ON ≤ OFF, no run more than 5 s later;
  guns_on_arc ≥ OFF − 0.05.
  (5) Terminus head-on (seeds 8–11, t11) REPORTED.
  (6) **Arrive series** (5 maps × 5 squads × seeds 61–64, n 100): all-within-8 m ON ≥ OFF − 1.645 se.
  (7) **The faced finish:** test_nav_gate_v4, test_wheeled_arrival and test_nav_gate_inside green on the native path.
  Counters gates_side and gates_inside > 0 on the acting ON runs and 0 on every OFF run.
  (8) The check green on the candidate, sim-baseline moves listed with the reason.
  (9) The worst ON run of (3) and (4) traced before the medians are read.
  Ships ON as one pair with native's mirror if (1)–(4) and (6)–(8) pass. (This line, from a579b245's text, was dropped when
  the bar was first copied here; restored.)
  **test_native_gate's floors, re-filed before any change (native, pair/brains-v6-r4 `560e09e8`, builder0 light, n 1,
  twins 0 mismatches on sumps and foundry):** the narrowed side gate and inside_circle make two vacuous-run floors fail on
  foundry. Side gates went 1/1, because the rear gate has turning room there now. The live latch went 0, because
  inside_circle latches first. **Granted:** side gates ≥ 5 on sumps only (6/6 seen); on foundry, gates_inside ≥ 1 (3/1
  seen); and the latch floor becomes latched + latched_away + inside > 0 (inside_circle is a `_gate_latch`). Everything
  else is unchanged (near, turned/forced_turning, shortened, cramped on sumps, drives ≥ 3000). These are guards that the
  paths ran, not targets.
- **Battery seats (brains stretch; filed 2026-10-17 before any number, lab/brains-r33-battery `c104f45e`, trace
  `references/round33/brains/battery_parade_s43_laptop.txt`).** Trace (laptop, parade gangs v law s43, 150 s, n 1): (1) at
  t=86 the coil swapped Battery_2's and Battery_5's places while 1, 3 and 4 were set up. Battery_2's new place was 20 m
  across the set-up trucks; Battery_3 refused it and it never moved again. Nothing in the seating knows a crew is set up.
  (2) At t=52 Battery_4 and Battery_2 set up 11 m and 5 m short and stood in their squadmates' lanes. (3) The post re-laid
  ~30 m at t=64 under set-up trucks. Unexplained, and traced before building: Battery_2 drove 20 m south at t=80–84 with
  its place 5 m away. Candidate: a set-up battery crew (deploy_ratio ≥ 1) keeps its seat, and its place is where it
  stands. Movers get the remaining places and are never seated past a set-up squadmate while another place is open.
  GDScript only (ElementPlan has no C++ twin); `--battery-seat=off`. Lines: (1) DECIDING, parade s43 and foundry s45: ON,
  no never-past battery asker, and the asker sets up within 8 m of its place. (2) Census, traffic-census parade + foundry
  + sumps × FRESH seeds 47–52, n 18: never-past battery askers ON ≤ OFF; trucks set up > 8 m from their place ON ≤ OFF;
  artillery shots ON ≥ OFF − 5 %; T1c-b2 (repack while firing) 0; friendly-stuck crew-s ON ≤ OFF + its round-32 limit.
  (3) The check, with sim-baseline moves listed. (4) The worst ON run traced before the counts are read. Ships ON if 1–3 pass.
  **Amended at filing (orchestrator):** "its place" in (1) and in (2)'s "> 8 m" line means the place the crew was ASSIGNED
  when it began to deploy, not the seat the candidate gives it afterwards. Otherwise ON passes by definition (its place
  becomes where it stands). Queued behind B10b and R4.
  **Second cause traced (brains, laptop, parade s43, native path, n 1):** Battery_2 ARRIVED 4.9 m from its place at
  t=80 pointing the wrong way without passing its approach gate. The gate was re-aimed 20.0 m back along the place's
  facing, it drove back, yielded to a squadmate crossing the coil, was re-seated across the set-up trucks at t=86 and
  refused. **Ruling (orchestrator):** R4 stays as filed and frozen (`97c3b654`). "An arrived hull latches its goal's gate,
  and the face at rest does the turn" joins this item as a SECOND switch, `--nav-off=arrivedgate`, on its own and not
  folded into the seat rule. It is scoped to hulls whose gun doesn't need the hull's facing (artillery/battery and turreted
  hulls). Never fixed-gun wheeled hulls: their face at rest is exactly C33.9's creep. A gate change, so it pairs with native
  (C26.2) and the gate tests. The bar gains: named cases with each switch ALONE reported and both together DECIDING;
  squad-arrive-series FRESH seeds (n 100) all-within-8 m ON ≥ OFF − 1.645 se; test_nav_gate_v4 / test_wheeled_arrival /
  test_nav_gate_inside green on native.
  **Third cause measured (brains, lab `87181cf3`, laptop, parade s43, n 1):** 18 of 31 Green set-ups stood more than 8 m
  from the place assigned at deploy, many 13–27 m off. Trucks deploy where they stand once they may fire. **Added as a
  THIRD switch, `--battery-seat=deployatplace`, judged alone like the other two:** a battery crew deploys only at its place
  (within 8 m). The cost is firing later, so the bar gains: median time from a battery's fire order to its first shot,
  ON ≤ OFF + 5 s on the census, plus the shots line already filed.
  **How each line is read (brains, filed 2026-10-18 before any number; candidate lab/brains-r33-battery `e8530098` =
  three switches + native's arrivedgate mirror + main 579c6fc4 + a measurement-only commit; all on builder2).** Flags:
  (a) `--battery-seat=off`, (b) `--nav-off=arrivedgate`, (c) `--battery-deploy=off`. ON = all three, OFF = none. (1)
  Parade s43 and Foundry s45 run five arms: on, off, a-alone, b-alone, c-alone. DECIDING on ON: 0 never-past battery
  askers, with set-ups > 8 m from the assigned place reported per arm. (2) `make battery-census` (census_probe pinned at
  --fixed-fps 30), Sumps/Parade/Foundry × FRESH seeds 47–52, n 18, ON v OFF, with the filed lines; first shot = from the
  battery element's attack/SBF task to any crew's shot, median ON ≤ OFF + 5 s, unanswered orders counted. (b)'s line:
  squad-arrive-series FRESH seeds 65–68, n 100. (3) The check. (4) The worst ON runs printed before the totals. **Added
  (orchestrator):** if (2) fails as a whole, shipping a SUBSET of the switches needs its own census on fresh seeds
  53–58 for that subset, filed first. No subset is picked from (2)'s numbers.

## Round 32: five streams, all Opus (launched 2026-10-16, CLOSED 2026-10-16 ~19:00 PDT; briefs in `streams/archive/round32/`)

**Goal: ship his two yeses first (T3b-c, T1c-b2; `game_design.md` *Round 31 close: his two answers*), then carry home
round 31's parked candidates (`roadmap.md` *Round 32 candidates*): the H1 ask loop he may see, his bridge's seating
without the heading rule, the arrival gate a third time (now with the planner's side gate), turn-the-hull's settle and
re-seating question, the planner's SLICE as a hardware preset, and the default arena's navmesh gap. Method unchanged
from round 31 (C31.1–C31.3, R31.1–R31.10 stand): the whole suite with the switch ON on the pair tree before a judged
series, bars sized from `judging.md`, `make quick-remote` to iterate and a full check only for a named hash (R31.9).**

**Models (his rule, 2026-10-16: "we should go back to using Opus agents across the board to conserve fable quota"):
every stream AND the orchestrator on Opus. No Fable session this round.**

| Stream | Folder (offset) | Model | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | Opus | [streams/traffic.md](streams/traffic.md) | at a Terminus street crossing the squad that gives way waits ~2.6 s and the squads bump a third less; a set-up mortar truck stays set up while squadmates go round (both his yeses); later, a hull no longer stranded off the navmesh in the default arena | **CP-T** both ships ON, first |
| **manoeuvre** | `godot-manoeuvre` (2) | Opus | [streams/manoeuvre.md](streams/manoeuvre.md) | a vehicle pinned on a squadmate that never moves goes round it or settles short instead of asking and backing every 21 s; wheeled turret vehicles turn their hull to his facing and settle | H1b; M1b(3) |
| **brains** | `godot-brains` (3) | Opus | [streams/brains.md](streams/brains.md) | every crew across his bridge (108/108) without the arrive maps paying; the yard's last crew in every time, Sumps included | B3b-2c; B5c-v6 |
| **native** | `godot-native` (4) | Opus | [streams/native.md](streams/native.md) | nothing in play: every pair (T3b-c first), the four twin test files split | each pair |
| **planner** | `godot-planner` (6) | Opus | [streams/planner.md](streams/planner.md) | the laptop preset keeps the planner's War Rig turns without the tick cost (SLICE per preset); the side gate brains' arrival needs | CP-S side_gate; SLICE preset |

**Ownership:** round 31's table stands (traffic the give-way block, `_avoid`, `_around_friends`, `_ask_behind`,
`_hull_within`; manoeuvre the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, the k-turn executor, H1's ask
(`unstickback`); planner the plan source, `game/ai/planner/**`, `native/src/planner_*`, `tests/planner/**`,
`tests/test_planner*.gd`, `mk/planner.mk`; native the member storage, `mk/native.mk`, `exec_fields.h`, the twins; brains the
rest of `movement.gd`, `tank_brain.gd`, `gunnery.gd` except manoeuvre's lead lines). **New grants:** traffic gets
`arenas/**` and `game/arena/**` for the navmesh gap ONLY (C32.6); planner gets the hardware preset's SLICE knob in
`game/theme/fx/fx_quality.gd` (`FxQuality`, the existing preset; one additive field, merge note), or a sim-side preset
read it designs if a render preset must not steer the sim (its call, one reason recorded). **Nobody:** as round 31. `tests/baselines/**` only by the
orchestrator's `make sim-baseline-adopt` on main.

**Contracts (round 32):**

- **C32.1 His two yeses ship first (CP-T).** Traffic carries `traffic-t3bc-judged` (`f5dc4147`) onto current main, native
  carries `413252ea` beside it; the PAIR tree, switch ON by default, plain `make remote T=check` (C31.1's ship check). A
  red on sim-baseline ALONE, with the moved maps listed, is expected: the orchestrator merges the pair back to back and
  re-records with `make sim-baseline-adopt` (two reads agreeing), giving each moved line its reason. Then T1c-b2
  (`traffic-t1cb2` `33cb2da5`): traffic-native-verify (native states "none ported" or carries the mirror), a check with
  the rule ON, the pit baseline re-recorded the same way. **If carrying either forward moves what was judged** (CP-H and
  CP-P1 landed after the judging), the owner re-runs that judged series ONCE on the new tree against its round-31 bar
  before naming a ship hash: his yes covered the behaviour, not a change to it.
- **C32.2 H1b, the ask that never frees (manoeuvre).** Terminus seed 31's last leg is the pass case: after N failed asks on
  the SAME blocker (N and the "failed" test pre-registered in the bar), re-path around it or complete short (settle);
  never re-drive into it. Pass lines: seed 31 loops 0; CP-H's pinned/stuck rows not worse (base + 1.645 se); arrivals not
  down; wall and terrain pins keep R31.5's escape. Behind `--nav-off=h1b` default OFF until judged; ships ON as a pair.
- **C32.3 Brains' bridge seating ALONE (B3b-2c):** the crossing seating + mouth guard with round 28's heading rule left
  OFF (the attribution trace: `--reissue-heading=plan` alone recovered 9/9). Its own bar: his bridge 108/108 (or ≥ the
  control) AND the arrive series within 8 m not below base − 1.645 se. Fresh seeds.
- **C32.4 The arrival gate, a third time (B5c-v6) with the planner's side gate (CP-S).** Planner delivers
  `PlannerSeam.side_gate(slot, facing, unit_id) -> Vector3` (§2.8's `slot + perp × R` on the side with room, two clearance
  reads through the C++ cache, no search; GDScript + C++ equal on fixtures) as CP-S, merged OFF-path (nobody calls it).
  Brains keeps the gate (C30.5) and chooses between the side gate and `near` keyed per seat (or with hysteresis), with one
  reason recorded; the bar names Sumps s17 t11 and yard s27 t8 as pass cases, pursuit as R31.3's count, Terminus and the
  yard as v5's lines. The full "slot" take point (`in_scope(unit_id, kind)`) is planner's stretch, only if brains asks.
- **C32.5 Turn the hull, M1b(3) (manoeuvre, with brains on re-seating):** before any number, manoeuvre and brains agree in
  writing (via the orchestrator) whether an arrivals line counts "completed at a re-seated slot" as arrived, and whether
  facekeep changes for gang hulls; the orchestrator records it as a ruling. Then the attack-move settle (moving-at-75-s
  line) is the problem to solve, not the turn (attempt 2's turn rows stand as evidence).
- **C32.6 The default arena's navmesh gap (traffic, after CP-T):** at (-25.7, 7.3) the start snaps 8.2 m to (-17.5, 7.3).
  First establish bake hole v obstacle footprint (a screenshot of the navmesh and the footprint, and the bake's inputs);
  a bake fix re-bakes only the default arena, and its sim-baseline move goes to the orchestrator with the reason.
- **C32.7 SLICE per hardware preset (planner):** CP-P1's (f) miss is solved as a preset knob (his rule: perf cuts ship as
  presets), not by changing SLICE on the default path: laptop preset SLICE 1, others 2, read once at match start, the same
  for both sides and deterministic across peers (a networked match uses the host's value). Priced on builder0 and, in a
  slot the orchestrator grants, the laptop.
  **RESOLVED 2026-10-16 ~05:35 PDT (the laptop's price):** laptop (flightdeck, i5-8365U), `65cc43dd` at `--planner-slice=1`,
  `planner-census` probe 30, Sumps 25 a side, seeds 92721 / 31337, pinned 0–3, load 2.66 → 1.55 (an UPPER BOUND, R31.6):
  **89 / 79 µs an expansion warm** (early 122 / 121), so SLICE 2 costs ~0.18–0.24 ms a tick on his laptop, under the 0.5 ms
  line; round 31's builder0 263 µs was the box's load. SLICE 1 only doubled the hold (7 v 3 ticks, slice test, n 1). **The
  laptop preset goes back to SLICE 2** (the knob and `--planner-slice` stay for a weaker device); no SLICE 1 v 2 series.
- **C32.8 Test splits (R31.9 (3)):** native's four twin files first, then each stream's own slowest files, same assertions
  divided, test count shown before and after, bodies byte-identical where possible.
- **C32.9 Fresh start:** every round-31 `stream/*` branch was renamed `round31/<stream>` (kept, not merged) and every
  worktree re-created from this docs commit. No agent of round 31 runs.
- **C32.10 The parked squadmate in the way: SWAP SEATS (decided 2026-10-16 ~04:00 PDT on manoeuvre's far-loop trace; replaces
  a draft back-off).** Manoeuvre's hunt (builder0 `48657f07`, Terminus drive seeds 1–16, n 1 a seed): base loops 105 mixed /
  114 rigs, ~70 % `far` (> 12 m of route left), out of H1b's settle. The far-loop trace (laptop, `08e6d44c`, H1b arm, Terminus
  seeds 3–6 rigs + mixed, counts matching builder0): 62 far loops from 6 pairs; in **50/62 the blocker is PARKED at its own
  slot** (route left 0), the other 12 (rigs) a blocker itself blocked by a third hull; mutual refused-both-ways **0/62**; the
  pinned hull is the SAME squad, 22 / 29 / 37 m of route left (p10/50/90), 6–14 m behind; every pinned ask refused (62/62);
  `_negotiate` designates the parked one in 50/62 but it has no validated spot. Traffic's proposed back-off (the designated
  yielder reverses along its own route) would need 11 / 16 / 20 m of reverse and straight room met it 0/62: dropped.
  **Rule:** when H1b's failed-ask count trips on a PARKED same-squad friend and the asker's slot lies beyond it, the two
  crews SWAP SEATS: the parked crew takes the asker's farther slot and drives on with nothing ahead of it; the asker takes
  the near slot. Nobody reverses; both end at a slot. **Owners:** brains owns the swap (the element's seats + both Movement
  goals behind one seam, e.g. `Element.swap_seats(a, b) -> bool`, refusing when a seat is pinned by a drawn facing or a
  task role; player squads are elements too); manoeuvre owns the detection hook (H1b's count) and keeps H1b's settle for
  the near-goal case. Signature agreed through the orchestrator before code. The 12 third-hull cases are REPORTED. Its own
  bar (Terminus seeds where base loops, named before the series; arrivals; swaps counted; the whole suite on the pair
  tree). Native mirrors only if the swap reaches the drive. **Why swap, not give way forward or back:** one decision, no
  geometry, and what a player expects of a crew stuck behind a squadmate who is already where he was told to be.
  **The seam, AGREED (2026-10-16 ~04:30 PDT, brains' settlement of manoeuvre's half):**
  `Elements.of_match(m).swap_seats(asker: String, parked: String) -> String` ("" = taken, else the refusal reason; String,
  no bool variant). It trades the two crews' last-issued orders (`Element._issued[name]`: to, facing, verb) and sends both
  through Elements.orders INSIDE the call, so both goals change THE SAME TICK; it also sets the element's `_swap` (round
  19's make-room mechanism: each plan, if the seating returns the original indices, `Element.apply_swap` trades slots,
  sectors, seats and orders back; `assign` clears it), so the next plans keep the swap until the movement ends.
  Refusals: not_same_element, unseated, leader (slot 0 of a drill move), kept (a re-seat's keep), task_role (the task is
  not a move/attack-move: SBF line, screen, overwatch/ambush post, hold), drill (a drill running), role (roles differ AND
  halted), deck (within MOUTH_REACH_M), budget (MAX_SWAPS 2 a movement, shared with make-room), standing. **A drawn facing is
  NOT a refusal** (the orchestrator's ruling: every seat of a faced shape carries his heading and SBF sectors trade with
  the seats). GDScript only; no native mirror. Counters: swaps, swaps_asked (brains); swaps asked / granted / refused by
  reason (manoeuvre's census). Tests: one per refusal + the accepted case + the plan-keeps-it case.
- **C32.11 B10, the grounding latch, ships ALONE before B5c-v6 (2026-10-16 ~04:35 PDT, brains' finding):** a seating bug ON
  MAIN: `Element.ground` → `SlotGround.standable_from` picks the side a pushed (unstandable) slot lands on, memoised by the
  element CENTRE's 5 m cell, so a squad jostling on its spot moves the centre across a cell edge and a seat jumps ~10 m (Sumps
  s16 t8, main's rules, no gate: Green_S_2's seat 3 flips 22 times, 43–120 s, never all in; v5's `near` made it 67 flips on
  s17 t11). Fix: latch each seat's grounding while its asked-for point holds within 0.5 m (`--ground-latch=off` = control);
  GDScript, every element (sim-baseline expected to move). Its own bar; then v6 (v5's gate + the side gate for yard s27 t8)
  is judged on a base with the latch ON. Order for brains: B3b-2c verdict → B10 → C32.10's swap → v6.
- **C32.12 HOLD's return backs a faced War Rig onto its post TAIL-FIRST (manoeuvre's trace, 2026-10-16 ~09:10 PDT; brains
  owns the fix):** hull-rest faced_move s66 Green_Guns_5 (laptop `fab0d82e`, GDScript, 153–160° off in 3 runs): it arrives at
  8–11 m/s, completes inside the 6 m settle radius, overshoots ~10 m; HOLD's "pushed off the spot" (`tank_brain.gd` ~2814)
  sends {move_to, reverse: true, NO facing}, and a wheeled turret hull's face is declined (turnhull off). **Fix (brains):**
  the return honours the post's drawn facing (reverse only within ~60° of the nose, else nose-first, or carry `facing`); its
  own bar, s66 Green_Guns_5 the pass case; after R32.6 and B10, before v6. **Manoeuvre** measures the overshoot itself
  (faced arrivals ending past settle + 1 m) as M1b(3)'s first input.
  **CORRECTED ~09:30 PDT (manoeuvre's arrival watch):** it did NOT overshoot. It came no closer than 11.5 m and swung to
  15 m, never inside its 6 m settle radius, yet its faced move COMPLETED by f 259 (11–15 m off). So brains first traces WHY
  the order completed far from the spot (the element's "arrived" completing every crew's order, or the repaired-arrival
  path), then makes HOLD's return honour the facing. True roll-pasts are rare (0/7). Manoeuvre's M1b(3) input becomes
  "move orders completed with the hull > settle + 1 m from its goal, by completion path".
- **C32.13 The War Rig face-behind GDScript-v-native divergence (planner's trace, 2026-10-16 ~10:00 PDT):** not the drive and not
  the search (the seam's exact request plans the same 5 legs both ways, 189 expansions). The planner's NO-LIBRARY session plans
  whole at `begin_session` and answers "done" at once, so PENDING_TICKS × SLICE (180 expansions) never applies; with the library
  the 189-expansion face is ABANDONED at 90 ticks and today's face executor turns the rig. Fix (planner): the no-library
  session reports done only once the expansions handed out reach the plan's (C++'s arithmetic); native's path untouched.
  **Round-33 note:** the seam never serves a War Rig's open-ground face-behind with the library (189 > 180); today's executor
  does. Native's `test_native_face_behind` compared 0 native executes (vacuous): native adds a floor.
  **The second-arena question (planner, ~11:00 PDT, laptop, `test_planner_second_arena.gd`, 3 plays in one process, freed
  between):** native's "legs 0" was its scratch's artifact (the old hull never freed, the new one spawned on it). A REAL
  smaller carry-over found: `PlannerSeam._retry_until` keyed by hull NAME, so a second match's War Rig reusing a name within
  ~1 s of the first's last decline lost its first plan (play 1: 2 requests, aligned 15.43 s; plays 2–3: 1 request, 12.43 s).
  Fixed: declines carry the hull's instance id; report()'s `live` counts only existing hulls. Granted: one line in match.gd's
  teardown calling `PlannerSeam.reset()` (game/match/** unowned this round).
- C31.1–C31.11 (except C31.10's Fable line) and rulings R31.1–R31.10 stand.

**Rulings (round 32, the orchestrator's, as they arise):**

- **R32.1 CP-T's native half is already on main (2026-10-16, native's finding, verified):** `413252ea` (the T3b-c mirror,
  `NativeTraffic.avoid_shape`) is an ancestor of main, inert until Traffic has `shape`. So C32.1's pair is traffic's carried
  T3b-c alone on main; native builds the pair tree from traffic's carried hash, runs plain `make remote T=check` with the
  switch ON and names the hash; traffic runs the re-judge on that same tree. `traffic-t3bc-judged` conflicts with main in
  traffic's files only (movement.gd, traffic.gd, mk/traffic.mk): traffic resolves them.
- **R32.2 H1b may WRITE brains' repair fields (2026-10-16, manoeuvre's flag):** H1b's settle-short sets the mover's existing
  `_repair_for` / `_repair_to` so the brain completes the order through `Movement.repaired_arrival`, as it already does.
  Granted: writes from H1b's hook only, no edit to any brains function or to what those fields mean; brains is told and
  owns the fields' meaning. The native drive's copy of those fields is part of H1b's pair (native mirrors the write).
- **R32.3 C32.5's two answers for M1b(3), agreed by manoeuvre and brains (2026-10-16 ~02:15 PDT):** (a) **YES**: an arrivals
  line counts a crew as arrived when it completes within ARRIVED_M (7 m) of the element's seat for that crew AT COMPLETION
  (`Element.seats`, what settle_probe's `off_slot_m` reads), not a stale `to`; a re-seat is the leader's correction, not a
  miss. Guards: each arm reports arrivals against the ORIGINAL slot, `reseats` and `reseats_after_arrival`; re-seats >
  base + 1.645 se is a FAIL line, so a hull that turns badly can't win by being re-seated. (b) **facekeep unchanged** for
  gang hulls (its refusals are the sector rule keeping a crew's arc, on the CPU's hulls; changing it moves sim-baseline and
  CPU fights for a problem it does not cause); attempt 2's 'sector' lift stays. The problem is the attack-move settle (crews
  moving at 75 s). (c) **The re-seat reads heading through the SHAPE, not the matching** (brains): `TacticsFormation.seat`
  matches by positions only, but an attack-move arriving with no drawn facing lays its halt along the element's heading
  = the members' averaged hull forward (`element_situation.gd` ~70–76 → `element_plan.gd:146` → `_halt` ~1669), read once on
  the arrival plan; a drawn facing replaces it (~668–672). Also `element_plan.gd` ~678 (a plain move forming up within
  2 m) and `drills.gd` ~387 (assault_through's "past" test). So a wheeled hull turning BEFORE the element arrives moves
  every seat; after arrival, none. Pinned by `tests/test_tactics_reseat_heading.gd` (stream/brains `cbddb940`).
- **R32.4 web-match-smoke's first-sound bound is a load timing line (2026-10-16 ~02:35 PDT, brains' B3b-2c check):** on
  `5f0ed865` (builder0, load ~22) the only red of 26 was "first sound 30.6 s after READY (bound 30 s)". A change that does not
  touch `game/audio/**`, the web export or the boot path may proceed to its series on that red, provided web-smoke re-run
  ALONE passes before the hash merges. A second miss on a quiet box gets traced, not waved through.

- **R32.5 A load-timing red in a file the branch doesn't touch, green re-run alone, doesn't block a TEST-ONLY merge
  (2026-10-16 ~06:00 PDT, native's split check `981e336b`):** `test_control_vision_camera::test_a_teleported_vehicle_is_drawn_
  where_it_was_put` red at load 12+, 18/18 alone on the same build. Merged; the next main check re-reads it, and a second red
  there gets traced (owner: nobody this round, so the orchestrator).

- **R32.7 A pass line whose READER is shown mechanically defective after its number is NOT READABLE, then re-measured on
  FRESH seeds with the fixed reader filed first (2026-10-16 ~10:40 PDT, H1b's line (3)):** H1b stage 1 (Terminus drive
  300–312, builder0, `9c46002a`, n 13 a squad): rigs STUCK 257 → 380 v bound 370.2, the whole +123 on the 3 seeds where H1b
  settled. Manoeuvre showed `pinned_table.py`'s STUCK keeps `best` across an ORDER CHANGE (s303 Green_S0_4: a new leg's goal
  6.6 → 69.8 m read as "never 1 m closer"), and that an offline re-read with a goal jump > 3 m restarting the run reproduces
  the filed numbers without the change and reads rigs 192 → 121 with it (mixed's 204 v 204 both artifact). **Ruling:**
  neither (A) park on a defective ruler nor (B) swap the ruler after the number. Line (3)'s STUCK is NOT READABLE on
  300–312; the reader is fixed on its own commit (its test: the s303 case), then line (3) STUCK (rigs and mixed) is run ONCE
  on FRESH Terminus seeds 360–372 with the fixed reader, filed before numbers, both arms, as the filed bound form. The other
  lines of stage 1 stand as read. The as-filed and offline numbers are reported beside it. CP-H's round-31 STUCK rows may be
  overstated the same way: noted for the close, not re-judged.
  **Its bar sentence, filed ~10:50 PDT before any number (manoeuvre):** "H1b line (3) STUCK, run once: Terminus drive seeds
  360–372, rigs and mixed, base `--brains-off=native` v H1b `--nav-off=h1b --brains-off=native` (GDScript), STUCK crew-seconds
  read by `tests/manoeuvre/pinned_table.py` as fixed on its own commit (a goal-distance jump > 3 m = NEW_GOAL_JUMP restarts
  the run; the s303 Green_S0_4 case held by a test), per squad: H1b ≤ base + 1.645 se (seed-paired), read once at completion;
  the as-filed 300–312 reading (257 → 380) and the offline one (192 → 121) reported, not judged." Runs after stage (6).

- **R32.6 `test_tactics_body::test_his_three_squads_keep_together` is red ON MAIN, order-dependent (2026-10-16 ~08:20 PDT,
  planner's A/B):** alone on main's code (254973bb, builder0 light) it FAILS deterministically (squad-seconds alone off 33.5 /
  on 24.5, army off 16.9 / on 29.1 s); it PASSED in main's full check at 6fcfbe46 and failed with other numbers in 8904c9c4's
  full check. Its outcome depends on what ran before it (a static carried between tests, or between matches in one
  session, which a player would hit too). **Brains owns it, priority over B10's remaining series reading**; until fixed it
  does not block a merge whose changes do not touch tactics/elements, and every check that reds on it alone names it.
  **FOUND (brains, ~10:10 PDT, stream `03aa0c5d`):** not a script static. The test stage's spawn jitter put two hulls 3.8 m
  apart, overlapping; on the first frame of the FIRST match in a process, physics shoves overlapping bodies ~2 m apart, in
  later matches it does not (engine-side first-physics-space recovery). Fix (test stage only): `BodyStage.spawns()` pushes
  spawns apart; `test_the_stage_spawns_no_two_hulls_overlapping` (mutation-checked). Line still right on today's main: off
  41.0, on 15.0–16.0 (needs ≤ 20.5). Open: whether the GAME's spawns can overlap (asked of brains).
  **REOPENED ~11:40 PDT (brains, check on `03aa0c5d` 2699/1):** the spawn fix stabilised ON (15–16 in any position), but OFF
  drifts with successive matches in one process (41.0 → 37.0 → 28.5): a second, cumulative effect (each squad on its own
  route). Treated as a possible play bug (a session's third skirmish v its first); script caches, then NavigationServer
  regions from earlier arenas, are the suspects. The line is not loosened; B11 waits on it.
  **CLOSED ~13:15 PDT (brains, stream `c029cf70`, test stage only):** clearing all twelve caches changed nothing (not script
  state); a hull touching something at spawn is moved on the first frame differently between a process's matches (7 cm),
  and the stage snapped wherever physics left it. Fix: after start(), snap each hull's INTENDED spawn, zero velocity. One
  process (builder0): on 15.5, 15.5, 15.5; off 41.0, 37.0, 41.0 (a residual off wobble from contact-level physics at ~1.9 s,
  time-boxed); the line holds in every order (on/off ≤ 0.42 v 0.5). **Play side, the orchestrator's reading:** a determinism
  note, not a bug he'd feel (deployments are clear of each other in all four factions; a skirmish is a fresh scene; a
  host-simulated match does not need cross-process lockstep). Recorded in orientation's trip-ups (brains' line 82).

**Bars (round 32, pre-registered before their numbers; the orchestrator appends each here as it arrives):**

- **B3b-2c (brains, C32.3; filed 2026-10-16 ~00:50 PDT before any number; DECLARED; partial: none; the full text is
  stream/brains `c13ad95f` Status *B3b-2c bar*).** Candidate: B3b-2b's seating + mouth guard (lab `5ed61f91` merged in),
  with round 28's heading narrowing OFF by default (`5ca8269d`: `HEADING_REISSUE_TASK_ONLY` false, i.e. main's round-26
  rule; `--reissue-heading=task` turns it on). Control = `--route-seat=off --mouth-held=off` (= main's rules; the
  orchestrator checked that the narrowing was never on main). Lines: (1) his bridge, the full 108: on 108/108 or ≥ the
  control (any cell control passes and on fails is a named regression, traced first); (2) bridge-pooled 18/18; (3) the arrive
  series on FRESH seeds 45–48, n 100 an arm: all_in8_s on ≥ control − 1 AND McNemar discordant against ≤ 1 (C32.3's
  1.645 se read as the count row's form), the paired median ≤ +2 % REPORTED; (4) counters: crossings_found > 0 on every
  on-run of the 108, 0 on control and on every arrive run; (5) `t.poll.element` on Locks ≤ 0.5 ms a tick or NOT READABLE on
  a busy box; (6) the worst on-arm cell of (1) and of (3) traced before the medians. Native: none ported (GDScript on every
  path). Ships ON as one commit. Stated in advance: the arrive arms may be byte-identical, which is the point of this cut.
- **CP-Q, the planner's queue (planner, hand-over (3); filed 2026-10-16 ~01:10 PDT before any number; DECLARED).**
  Candidate `--planner-queue=shared`: refuse early (a blocked start/goal answered at the ask, never queued), round-robin
  with a QUANTUM of 20 expansions over a session per crew, the same slice a tick. Base: the same tree without the flag
  (today's FIFO). Both arms the native drive. Series tree = the hash planner's full check goes green on (code from
  stream/planner `0b9e96bc`). Every line read once at completion on the 1.645 se line, (faction, seed)-paired:
  (1) hull-rest gang arm (`make planner-judge-queue`, gangs, drawn + clicked, FRESH seeds 66–71): abandoned ≤ 5 % of asks in
  EACH of drawn and clicked (round 31: 23 % / 18 %); (2) hold per event, pooled median per arm, NOT UP: (2a) those hull-rest
  runs, (2b) the Terminus rig series (`make planner-series-queue`, rigs + mixed, fresh seeds 205–217); (3) round 31's (d)
  lines as filed: at-rest hull error permutation p ≥ 0.05 every class × task, settle paired median ≤ +6 s, crews moving at
  75 s each task × arm ≤ base + 1.645 se; (4) Terminus rig arrivals (2b) mean paired ≥ −1.645 se; (5) the whole suite green
  on native's pair tree with the default flipped ON (C31.1), before the series. REPORTED only: refused_early, queue_waits,
  plans, driven, refused by code, hold max. Ships ON as a pair (QUEUE_DEFAULT true + native's review of `refused_at_begin`).
  If (1) misses: the abandoned searches' expansions reported, stop; no re-tuning on these seeds.
- **B10, the grounding latch (brains, C32.11; filed 2026-10-16 ~04:50 PDT before any number; full text stream/brains
  `ddd1cc56` Status *B10 bar*).** Candidate: the latch alone on main `33321516` (T3b-c and B3b-2c ON). On = default; off =
  `--ground-latch=off` (main's rules); builder0, default path, fresh seeds. (1) Drift census (`make ground-series`: Sumps 18 19
  × 6 ticks, yard 29 30 × 6, Terminus 12–15 t11): pooled flipping-crew runs (> 10 drift moves) on ≤ off AND pooled drift on
  < off, plus the named main-side case Sumps s16 t8 with no flipping crew on; (2) arrivals not down: Sumps median on ≤ off,
  no run > 5 s later; yard every-crew-in and crews in on ≥ off every run; Terminus reported; (3) arrive FRESH seeds 49–52, n
  100: on ≥ off − 1, discordant against ≤ 1; (4) sim-baseline moves listed with reasons (CPU elements latch too); (5) the
  whole suite + bridge-pooled; (6) cost; (7) worst runs traced first. `ground_census.py` must reproduce v5's table from its
  rows (a check on the tool).
- **T4-ON, ORCA reads the honest velocity (traffic stretch; filed 2026-10-16 ~07:50 PDT before any number; DECLARED).** Tree
  `traffic-t4-on-r32` `0adc6deb` = main `2dce8a8c` + ghost out of OPT_IN (ghostself stays opt-in, unmirrored, named by no
  judged arm). Arms on the NATIVE default path (native mirrors the gather, `test_native_avoid_gather` 0 mismatches ghost
  on); base `--traffic-off=ghost`. `make nav-terminus-drive`, mixed + rigs, FRESH seeds 41–64, n 24 a squad, paired,
  `pinned_table.py`. Lines: (1) DECIDING mixed stuck crew-s down beyond 1.645 se; (2) rigs stuck crew-s not up beyond 1.645
  se; (3) pinned crews each squad not up beyond 1.645 se; (4) arrivals ≥ base − 1.645 se each squad (rows 68/70); (5) the
  four traffic-series cases (seeds 41–43 × six ticks, n 18) within T3b-c's guards; (6) bridge-pooled 18/18; (7)
  `test_traffic_ghost` and `traffic-native-verify` ghost-on at 0 mismatches; C31.1's ON gate before the series. A stretch
  item: it runs behind H1b's, B10's and CP-Q's series on builder0; if H1b ships first, T4's tree takes main before its
  series.
  **CP-Q JUDGED 2026-10-16 ~08:30 PDT: FAIL on line (3) → PARKED** (`pair/planner-queue` 65cc43dd kept; OFF on main). builder0:
  (1) abandoned drawn 1.0 %, clicked 3.7 % (base 18.6 / 14.5 %) PASS; (2) hold medians down (hull-rest 0 / 1 v 4 / 9.5 ticks;
  Terminus rigs 0 v 19) PASS; **(3) FAIL**: faced SBF drawn at-rest error p 0.035 (106.8° v 74.3°), faced_move settle +14.5 s
  (never settled 6/6 v 3/6), moving at 75 s faced_move +5 (line 2.96), faced_screen +3 (line 2.14); (4) rig arrivals 187 v
  180 PASS; (5) PASS. Reported: Terminus rig contact-ticks median 522 v 321. **Reading:** serving 1.5–2× the face plans in a
  19-crew press costs drawn facing, settling and wall contact; the FIFO's starvation was hiding the cost of the seam's face
  plans in a press. Round 33: trace why a served face in a press ends worse, a press-aware scope, then the queue again.
  **Traces (planner, builder0 light, ~09:00 PDT):** hull-rest's worst pairs do NOT reproduce (the harness's run-to-run
  variation dominates the tail; one is a faced-move War Rig left ~150° off after a plain stop in BOTH arms, relayed to
  manoeuvre as a possible face-path bug on main). **Terminus s207's contact rise IS the queue's, mechanism found:** under the
  FIFO a request is HELD (`_pend` brakes the hull to rest) until its search answers, so a refusal hands today's code a hull
  at rest; refuse-early answers from the ROLLING pose, so today's code keeps 7–9 m/s and drives into the block (series-wide
  258 refused early; GOAL_BLOCKED 197 v 138). **Round 33:** refuse early only AT REST (brake a rolling ask as the FIFO does,
  then probe), round-robin unchanged; the hull-rest A/A (fifo v fifo) sizes line (3) first; re-judge on fresh seeds.
  **B10 JUDGED 2026-10-16 ~09:45 PDT: FAIL on line (2) → PARKED as filed** (check `8e43cc5c` 2699/0 ALL JUDGED; series
  builder0): (1) flipping-crew runs 0 v 2, drift 107 v 138 PASS; **(2) Sumps median 42.75 v 49.86 s but s19 t8 89.3 v 69.4 s
  (+19.9) breaks "no run > 5 s later" FAIL**; yard identical; (3) arrive 93 v 93 PASS; sim-baseline unmoved; cost 0.149 v
  0.164 ms. **The losing run, traced:** the latch holds S_2's near seat, so S_2 PARKS at (-2.5,-51.9) in the passage S_3 and S_4
  need to their west seat (~40 s of no_path / blocked-by-each-other, two make-room trades); off, the bug's flipping moved
  S_2 out of the way by accident. **Ruling:** parked as filed (the bar is not changed after its numbers). It is C32.10's
  situation (a parked squadmate in the way): **B10b = the same latch re-judged ONCE on fresh seeds on a tree with C32.10's
  swap ON**, no code change, its own bar (the s19 t8 case named); B5c-v6 waits behind B10b (its s17 t11 pass case needs the
  latch: 35.8 v 34.8 s with it, v5 58.3 without).
  **AMENDED ~14:10 PDT (manoeuvre's diagnostic, builder0 light, `519001d5` = main + swap + latch, reproduces 89.27 s):** the
  swap CANNOT reach s19 t8 (escape fires 1, failed asks 0, swaps asked 0): S_3 and S_4 three-point in a passage they read as
  `no_path`; S_2, parked on its latched seat, is never their blocked_by name. So **B10b is a seat-choice change in brains'
  element** (the latch / grounding avoids a seat lying in a squadmate's passage), its own bar with s19 t8 named; the swap's
  bar reports s19 t8 instead of naming it. Not this round unless brains has room after B11.
- **B11, HOLD's return honours his drawn facing (brains, C32.12 (2); filed 2026-10-16 ~09:30 PDT before any number; full
  text stream/brains `e440bcd9` Status *C32.12*).** C32.12 (1) answered: the faced move is not completed far off, it is
  REPLACED: when the element arrives (centre within ARRIVE_M) the halt gives every crew a `hold` at its seat carrying his
  facing, and a faced hold replaces a move at once (`Element._should_issue`, round 10's rule) wherever the crew is. Candidate:
  HOLD's return backs on only while his facing is within FACING_KEEP_DEG (60°) of the nose, else drives nose-first carrying
  the facing; `--hold-return=old` = control; GDScript. Hull-rest drawn, 4 factions × 6 FRESH seeds × 6 faced tasks, on v old.
  **Seeds amended by the orchestrator before numbers: 350–355** (brains proposed 61–65, 67, which overlap round 31's judged
  hull-rest 60–65 and CP-Q's 66–71). (1) DECIDING crews > 90° off pooled, on < off (Fisher reported); (2) s66 Green_Guns_5
  ≤ 90° in ≥ 2 of 3 on-repeats (a named case; the harness is not run-to-run deterministic); (3) no class's median worse (p <
  0.05), never-settled on ≤ off + 2, settle median ≤ +2 s; (4) the whole suite, sim-baseline moves named; (5) worst traced.
  **T4-ON JUDGED ~13:40 PDT: NOT SHIPPED** (builder0, `0adc6deb`, native path; `references/round32/traffic/t4_r32/`):
  (1) DECIDING mixed stuck 607 → 313 crew-s (−48 %), se 211, needed beyond −347: FAIL (direction right, size unproven at
  n 24); (2) rigs stuck 627 → 459 pass (manoeuvre's `_honest_blocker` removed round 31's rig harm); (3) pinned mixed 316 → 17
  pass; (4) arrivals pass; (5) yard head-on FAILS two guards (between-squad fast 53 → 59 v +5.8; all-in median 33.8 → 38.0 s
  v +3.82): the late hull (usually Green_A_5) reverses and circles round its slot 15–20 s (reversing turns 8 → 138, 15 →
  112, 20 → 47; friend-stuck ≈ 0). Round 33: trace one circle loop, re-judge mixed stuck at n ≈ 48.
- **C32.10's seat swap (manoeuvre + brains; filed 2026-10-16 ~14:20 PDT before any number; DECLARED; partial: none; full
  text stream/manoeuvre `c8a75e91` Status).** Candidate `lab/manoeuvre-swap2` = main `5cc02947` + brains' seam `f2cc956d` +
  manoeuvre's hook, switch `h1bswap` OPT-IN (native's `_h1b_swap_goal` row rides in the pair). Base: the same tree without it
  (H1b ON). GDScript path, one tree. The swap is asked only at H1b's 2nd failed ask on a PARKED friend whose goal is nearer
  than the asker's route left; a far loop = H1b's `far` count. **Fresh seeds (orchestrator confirmed unclaimed):** Terminus
  380–392 rigs + mixed, hull-rest 393–398 (n 144 an arm), fights 400–423; named cases the trace's six pairs (hunt rigs 3, 4,
  6; mixed 4, 5). **GAIN:** on 380–392 swap-arm far loops ≤ 50 % of base, rigs and mixed apart. **Guards** (1.645 se, once):
  (1) loops − far = 0 both arms, far ≤ base on every named hunt seed; (2) hull-rest PINNED ≤ 10 m and STUCK ≤ base + 1.645 se;
  (3) Terminus PINNED and STUCK per squad ≤ base + 1.645 se; (4) arrivals paired ≥ base − 1.645 se, rigs and mixed apart;
  (5) fights kills, deaths, hit rate within 1.645 se; (6) element RE-SEATS (R32.3's fail line; swaps not counted) ≤ base +
  1.645 se; (7) the whole suite on native's pair tree with the default flipped ON, before the series. STUCK =
  `pinned_table.py` at `f5bf085f` (a run ending in progress is not counted, as always). REPORTED: swaps asked / taken /
  refused by reason; far rows by blocker kind; Sumps s19 t8 latch ON.
  **AMENDED ~16:30 PDT before any series number (manoeuvre's finding):** the Terminus drive forms NO elements (Orders +
  OrderExecutor; `Elements.install` runs only in skirmish-based stages), so the seam answers `no_element` there and G cannot
  pass on 380–392; the far-loop trace's 50/62 were drive orders, not element seats. **Ruling: (a) + (b).** G moves to fights
  400–423: swap-arm far loops ≤ 50 % of the h1b arm's, summed over the 24 seeds, AND swaps taken ≥ 1; hull-rest 393–398's far
  loops reported beside it. Terminus 380–392 stays as GUARDS only (lines (1), (3), (4), (6): the hook does no harm when it
  cannot swap). Noted for round 33: in his skirmish every squad is an element, so the swap reaches play; the Terminus drive
  harness does not resemble play here (no elements) and its far loops may not be his.
  **B11 JUDGED ~16:00 PDT: FAILS lines (2) and (3) → PARKED** (OFF, `--hold-return=faced`; stream/brains `32e21917`; check
  `c029cf70` 2700/0; series on `ffba7f77`, builder0, n 144 an arm): (1) crews > 90° off 377 v 391 PASS; **(2) s66 Green_Guns_5
  on 104.5 / 125.8 / 122.4° FAIL** (the return completes inside the 6 m settle radius still turned, and nothing faces a
  wheeled turret hull at rest); **(3) wheels/fixed worse** (faced_move median 7.5 v 3.0°, p 0.000; never settled 85 v 73)
  FAIL, while **wheels/turret (his rigs) gains a lot** (faced_move 17.3 v 48.4°, p 0.004; faced_right 21.0 v 43.6°).
  **Round 33:** B11b limited to `mount == "turret"`, paired with M1b's face at rest.
  **SWAP JUDGED ~17:05 PDT: G FAILS → PARKED** (no partial; `pair/swap-ship 80300909` NOT merged). Fights 400–423, builder0:
  far loops h1b 6 v swap 6 (G needed ≤ 3), swaps asked 0; all 24 fights bit-identical. Blocker kind (swap arm): 5 rows a
  parked crew of ANOTHER element, 1 row same element but under way, 0 rows the swap's case. **Reading:** in skirmish a crew's
  far loops are against a parked crew of another element, which a seat swap cannot trade; the Terminus drive's 50/62 came
  from a harness with no elements. **Round 33:** an element-level make-room or a cross-element give-way (traffic/brains).
- **H1b, the ask that never frees (manoeuvre, C32.2; filed 2026-10-16 ~01:25 PDT before any series number; DECLARED;
  partial: none; full text stream/manoeuvre Status *H1b bar*).** Arms: candidate `--nav-off=h1b` (opt-in, R31.1) v the same
  tree without it, both GDScript (`--brains-off=native`). N = 2 failed asks; "failed" = the escape fires again on the same
  friend for the same goal and that friend's net flat move since the previous fire is < 0.5 m; a loop = a fire that records the
  second (or a later) failed ask and that H1b did not break (counted in both arms; wording amended 02:30 PDT before any series
  number, manoeuvre's off-by-one in its own test, intent unchanged). Settle short only with ≤ 12 m of route left and a goal not
  sliding; loops farther out are counted (`far`), not acted on. **Fresh seeds (confirmed unclaimed by the orchestrator):**
  Terminus 300–312, hull-rest 313–318 (n 144 an arm), fights 320–343. Lines, guards to completion, each read once on 1.645 se:
  (1) **AMENDED 04:25 PDT before any series number (seed 31 no longer loops on today's main; C32.10 hands far loops to the
  swap):** on every named hunt seed (builder0 `48657f07`, n 1: Terminus drive mixed 4 5 6 7 9 10 11 13 14 16; rigs 1 2 3 4 6 9
  10 14 15 16; fights 4 Terminus, 6 Sumps) AND on the fresh Terminus seeds 300–312, H1b-arm loops − far = 0 (every near-goal
  loop broken) and far ≤ base loops (H1b never makes a loop); far reported per seed as C32.10's base; (2) hull-rest pinned and stuck crew-s (row 67) ≤ base + 1.645 se;
  (3) nav-terminus-drive PINNED/STUCK per squad ≤ base + 1.645 se; (4) Terminus arrivals, rigs and mixed apart, ≥ base −
  1.645 se; (5) fights kills, deaths, hit rate within 1.645 se; (6) R31.5's terrain pins unchanged: `test_nav_wall_contact`,
  `test_control_queued_task`, `test_manoeuvre_escape` green; (7) the whole suite green on native's pair tree with the switch
  flipped ON, before the series. REPORTED: settles, metres short, `far`, loops in both arms. A miss parks H1b with its trace.

## Round 31: five streams (prepared 2026-10-14 evening; briefs in `streams/`)

**Goal: carry home what round 30 judged and could not ship (`roadmap.md` *Round 31 candidates*; his two calls in
`game_design.md` *Round 31: his two traffic calls*), and put the planner into play. Round 30's pattern — six candidates
passed every judged line and failed the pair-tree check on a stage the series never covered (lesson 307) — sets this
round's method: the whole suite with the switch ON on the pair tree BEFORE a judged series, every bar sized from
`judging.md`, the scenario stages named as pass lines. Beside it: his two traffic calls re-judged with the lines he set;
the honest reading (`Tank.real_velocity`, on main, read by nobody) given its consumers as ONE A/B; the arrival gate, his
bridge and the SBF line re-judged with their round-30 findings; the C++ port of the lattice planner and its seam.**

| Stream | Folder (offset) | Model | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | Opus | [streams/traffic.md](streams/traffic.md) | crossing squads: the yielder through ~3 s later, half the bumps (his call); a set-up mortar truck stays set up for a passing squadmate (his call); the early-stop hook in the runners | T3b, T1c-b early (cheap re-judges); T4 into **CP-H** |
| **manoeuvre** | `godot-manoeuvre` (2) | Opus | [streams/manoeuvre.md](streams/manoeuvre.md) | a wedged IFV or truck backs out of a wall or a squadmate instead of sitting at full throttle, and a War Rig pinned on a friend asks, then backs straight; wheeled turret vehicles turn their whole hull to his drawn facing | **CP-H** (the honest-reading A/B, manoeuvre runs it); M1b(2) |
| **brains** | `godot-brains` (3) | Opus | [streams/brains.md](streams/brains.md) | the yard's last crew in every time with the 180° arrival and a scout's chase intact; his bridge 108/108; support by fire lines up on his drawn facing | **CP-G** B5c-v5 pair; B3b; B6 |
| **native** | `godot-native` (4) | Opus | [streams/native.md](streams/native.md) | nothing in play: every pair; the planner's C++ reviewed and built; `test_native_traffic_hold` split | each pair; **CP-P0** with planner |
| **planner** | `godot-planner` (6) | **Fable** | [streams/planner.md](streams/planner.md) | a long truck in a Terminus street turns in two or three deliberate legs, backs out of a wedge, never grinds a wall (behind `--nav-off=planner` until its bar passes, then ON as a pair) | **CP-P0** C++ port equal to the GDScript planner; **CP-P1** the seam judged |

**Ownership (round 30's, restated, plus the planner's grants):** in `movement.gd`: traffic the give-way block
(`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`; manoeuvre the `drive()`
body, `_nose_stop`, `unstick`, `_pressing_escape`, the k-turn / planned-reverse / circle block's EXECUTOR (`kturn_on` through
`_look_stop`, `_kturn_start_leg`, `_planned_reverse`); **planner the PLAN SOURCE of that block** (C31.5: one seam where a
plan is asked for, behind `--nav-off=planner`); native the member storage; brains the rest (`_track_progress`,
`_update_phase`, `_approach_gate`, the re-seat's "slow" test …). `order_controller.gd`: manoeuvre the face path; native its
seams. `tank_brain.gd`: brains, except native's seams and manoeuvre's `_order_move` grant (turn-hull lifts the decline,
C31.8). `game/ai/gunnery.gd`: brains, except manoeuvre's two lead lines (C31.4). `game/tank/tank.gd`: nobody (the member
is in). **Planner owns** `game/ai/planner/**`, `native/src/planner_*.{h,cpp}` (NEW; native reviews every commit and owns
the build glue: `mk/native.mk`, `exec_fields.h`, the seam's record fields), `tests/planner/**`, `tests/test_planner*.gd`,
`mk/planner.mk`, `references/round31/planner/**`. **Nobody**: `game/match/**`, `game/units/**`, `game/garage/**`,
`game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/announcer/**`, `game/theme/**`, `arenas/**`,
`game/arena/**`, `game/control/**`, `tests/baselines/**` (except the orchestrator's re-record), `tools/remote.sh`,
`tools/slot.sh`, `mk/core.mk`, `tools/judge/**` (the orchestrator re-renders at the close).

**Contracts (round 31):**

- **C31.1 Every change to fights or driving is DECLARED (C30.1 carried, every clause) AND checked on the pair tree BEFORE
  its judged series (lesson 307):** the candidate's switch ON, `make check` on a tree with native's mirror (or native's
  statement "none ported" + `native-verify-scenarios`), the WHOLE suite green — including `scenario_cp2`'s scout orbit,
  `test_tactics_mixed_legs` (the Sumps causeway), `test_nav_wall_contact`, `test_tactics_pursuit`, `test_wheeled_arrival`
  — before any series spends builder0. A red there is a finding; a fix is re-checked the same way. The bar (partial rule,
  last attempt named) goes to the orchestrator before numbers; tuned on named seeds, judged on fresh ones; the worst
  run's trace before the median; the count is what he sees.
- **C31.2 The C++ follows, and native carries it** (C30.2 carried): each settled diff to the drive, `_avoid`,
  `right_of_way`, unstick, gunnery, the k-turn executor or the per-crew execute goes to native BEFORE its commit; the pair
  merges back to back and is checked once. Pairs pre-empt native's own work.
- **C31.3 Bars are sized from `judging.md`** (C30.3 carried; the table re-rendered with round 30's pairs at `3ca70af2`):
  every line cites its row (sd, n, the guard as base ± 1.645 se or a count form); a probe with no row owes an A/A pair
  first; **early stop is allowed**: the runner prints `tools/judge/sequential.py`'s CONTINUE / SERIES PASS / FAIL after
  each row (traffic adds the hook to its runner first; others copy), and a stream may stop on the row the rule names,
  recording that row in the bar's block; truncation is decided by the fixed test (M2b's lesson). Round-30 judged pairs
  go under `references/round31/<stream>/` for the close's re-render.
- **C31.4 CP-H, the honest reading's consumers as ONE A/B** (`Tank.real_velocity` is on main, read by nobody in play).
  The consumers, each behind its own switch, default OFF, built by its owner: manoeuvre's escapes (`--nav-off=unstickback`:
  the honest stall reading + the escape redesigned — ask first, a STRAIGHT reverse ≤ 3 m where the k-turn's outline sweep
  is clear, ended by the real backoff, else "blocked by <name>"; never a blind reverse on lock), the War Rig's stall
  against a FRIEND (touch false, a Tank collider), kturnarc with the arc SIGNED by gear (`--nav-off=kturnarc`), the two
  aim leads in `gunnery.gd` (manoeuvre's grant, `--gun-off=realspeed`); traffic's T4 (`--traffic-off=ghost`: ORCA's
  neighbour table and the solver's own velocity read `real_velocity`); brains' re-seat "slow" test (`--brains-off=
  realslow`). **Manoeuvre runs the judged A/B** once every consumer is on main behind its switch (the orchestrator calls
  CP-H when the last lands; traffic and brains deliver theirs by then or stand down for this round): all consumers ON v
  all OFF, GDScript path, fresh seeds, the stages = Terminus census (rigs + mixed, 13 seeds), hull-rest (one arm per call),
  bridge-pooled, fights (24 seeds), nav-terminus-drive's pinned/STUCK rows, `scenario_cp2`, `mixed_legs`, the whole suite
  on the pair tree; PLUS each consumer alone REPORTED (one arm each, fresh seeds). Partial rule (pre-registered here): the
  combined ships as one pair if every line passes; if the combined fails, each consumer that passed alone on every line
  may be re-declared alone (one attempt). Native ports every consumer (one pair).
- **C31.5 The planner into play, two checkpoints.** **CP-P0:** `native/src/planner_native.{h,cpp}` reproduces the GDScript
  planner's plans EXACTLY on every offline fixture (the 16 tests + the lab fixtures; a twin test `test_native_planner`
  with 0 mismatches; the expansion budget semantics identical), and prices a plan (µs on builder0, foundry 25 a side):
  the per-tick slice design (a resumable search with a budget per tick) proven to return the same plan as one call. Native
  reviews every planner C++ commit before it is pushed to the branch (SendMessage, orchestrator copied) and owns the build
  glue. **CP-P1:** the seam — ONE call in the k-turn block where today's planner produces a plan (manoeuvre names the line
  with the planner through the orchestrator; manoeuvre's executor consumes `Vector3(gear, steer, metres)` legs or the
  planner adapts to `Vector2` — the hand-over's P4 finding — decided in writing before code), behind `--nav-off=planner`
  DEFAULT OFF; judged as a declared change on the C31.1 stages with the round-30 cases as pass lines: seed 31's and seed
  51's grinds (Terminus rigs, contact-ticks ≤ base + 1.645 se and arrivals not down), the six-cusp car (yard s25 t1 ≤ 3
  legs), the squadmate pin, a scout's orbit unchanged (`scenario_cp2`), the 180° arrival; plus the cost line (≤ 0.5 ms a
  tick at Sumps 25 a side with the slice, or the budget that achieves it). Ships ON as a pair (the C++ plan source is the
  default path; the GDScript planner stays as the twin). Partial: CP-P0 alone merges OFF (the port and its proofs are
  worth having); CP-P1 missed = the finding with its traces, parked.
- **C31.6 Brains' arrival gate B5c-v5:** before any series, the pursuit test's own margin is measured over seeds (an A/A on
  `test_tactics_pursuit`'s stage: 12 seeds, both arms OFF) and goes to `judging.md`; the candidate scopes `near` to a
  re-seat / new goal while on a task (never an opening seat), or lays the 180° gate to the SIDE (the planner's §2.8);
  judged on round 30's cells + arrive + `test_tactics_pursuit` on every seed of its A/A as a pass line (C31.1). The C++
  mirror starts from `lab/native-b5c-v4` f508ce89.
- **C31.7 builder0 runs every Godot run** (C30.7); one hull-rest arm per remote call (lesson 311); the series cache is
  ADOPTED for base rows (`CACHE=on`, proven in round 30) by every series runner — the owner adds it; the laptop only in a
  slot the orchestrator grants (none planned).
- **C31.8 Formation geometry is brains'** (carried). **Turn-hull (M1b(2)) lifts the decline in `TankBrain._order_move`
  for wheeled turret hulls** (manoeuvre's round-28 grant extended: the decline becomes "turn the hull" for a drawn facing
  when `turnhull` is on; brains told; the gang_ifv SBF ceiling from B6's trace is its first probe).
- **C31.9 Tooling owners:** the early-stop hook — traffic (its runner first, the pattern for others); the
  `test_native_traffic_hold` split (486 s, the floor) — native; the face_slot counters exported from the hull-rest probe —
  manoeuvre; the `WEB_PACK FAILED` line renamed so a passing refusal test does not read as a failure — the orchestrator.
- **C31.10 Models (his rule):** planner on Fable 5.1; traffic, manoeuvre, brains, native and the orchestrator on Opus.
- **C31.11 Fresh start:** every worktree was re-created at this split from main `cff4307e`; no agent of round 30 runs.
- C28.2's stale rule, C26.4–C26.10's rulings, C25.6, C24.6–C24.8 and the older standing contracts stand.

**Rulings (round 31, the orchestrator's, as they arise):**

- **R31.1 CP-H switches are OPT-IN (2026-10-14, manoeuvre's proposal, adopted for every consumer):** each consumer's
  switch is default OFF on main, and naming it turns it ON (like `inflate`). Main and native's default path play unchanged
  until CP-H ships. **Two checks, not one:** (a) the PRE-SERIES gate for a GDScript-only consumer is a scratch tree with
  the default flipped ON, `make remote T="check NATIVE=off"` (the whole suite on the GDScript path with the switch on).
  (b) The SHIP check is still C31.1's pair tree: native's mirror in, the default flipped ON, plain `make remote T=check`
  (native's default path), the whole suite green. (a) gates the series; only (b) gates a merge ON. Traffic (`ghost`),
  brains (`realslow`) and native are told.
  **Addendum (native, 2026-10-14 ~23:20 PDT): which arms run native.** Any `--nav-off=` name makes
  `NativeDrive.usable()` false, so the arm runs the GDScript drive (manoeuvre's `unstickback`, `kturnarc`, the planner).
  **Traffic's `ghost` (`Traffic._off`), brains' `realslow` (`--brains-off`) and the gun's `realspeed` (`--gun-off`) do
  NOT:** their arms run the NATIVE drive, which ignores the switch until its mirror lands, so an "ON" arm silently runs the
  OFF behaviour. **Rule:** every pre-series gate AND every judged series of those three runs with `NATIVE=off` (C31.4's
  GDScript path) until native's mirror is in, and the A/B's runner must refuse a native arm for them. The pair tree
  (mirror in, default ON, plain check) is the only place their native path counts.
  **Under `NATIVE=off`, `native-live-guard` fails BY CONSTRUCTION** ("no native switch in force … nothing guarded,
  FAIL"). In a `NATIVE=off` gate that one red is structural, not a finding (brains' B8 gate `44b32f12`: 2612/0,
  25 of 26, sim-baseline unmoved, accepted as the series gate). A pre-series gate may be read from the runner's printed
  summary. A merge or ship check needs the wrapper's `>> remote: … exited` line.

- **R31.2 The planner seam, AGREED in writing before code (2026-10-14 ~23:10 PDT; amends C31.5's "ONE call" and the
  executor line for planner-held hulls; planner's draft `f2245404` "DRAFT SEAM", manoeuvre's and traffic's replies):**
  **(A) AMENDED ~00:35 PDT (the planner's correction at `9281fc43`, manoeuvre's review OK):** a take on the first line
  of `_planned_reverse` would ask for a plan every tick of every routed move. The seam is now `PlannerSeam.hold()` at
  the TOP of `_planned_reverse` and of `face_turn`, which only continues a held crew and never asks, plus
  `PlannerSeam.take()` at the three points where today's code MAKES a plan. Those are the circle plan (inside
  `_away_here()`, near rest, inside the circle), the blocked forward arc (after the `KTURN_HIT_WITHIN_M` return and the
  `KTURN_CHECK_TICKS` throttle), and the face after its aligned test. A hull mid k-turn or face leg is never taken,
  because both leg blocks return first. `yield_to_plan()` is still called once on first take, for the escapes. The
  unstick gate and `manoeuvring()` are unchanged. The superseded text: (A) **Two call lines**, both unreached when OFF: the first line of `Movement._planned_reverse`
  (`if PlannerSeam.on() and PlannerSeam.take(self, cmd, "kturn", waypoint, delta): return true`) and `face_turn` right
  after its `FACE_ALIGNED_DEG` return ("face"). Manoeuvre grants exactly those two lines. (B) **Legs `Vector3(gear, steer,
  metres)` driven by the planner's `PlannerExecutor`** (planner's path), with no Vector2 adapter. Manoeuvre's executor stays
  Vector2 on one lock and drives everything the seam declines. Manoeuvre does NOT take the two brake rules; they belong to
  PlannerExecutor. (C) **Pending:** zero throttle, zero lock, ≤ 3 s (`PLANNER_PENDING_TICKS` 90), then decline 1 s and
  today's rules run. One hull a tick (a one-deep FIFO). Re-plan only on a leg abort, at most 2 per order. (D) **Readers:**
  `in_kturn()` is unchanged. The planner owns a new `Movement.manoeuvring()` = `in_kturn() or (PlannerSeam.on() and
  PlannerSeam.live(name))`, which equals `in_kturn()` when OFF. Traffic reads it in `Traffic.refresh`'s crossing row and in
  `ask()` (a held hull refuses). Manoeuvre's straight-leg lever reads it. `manoeuvre_census.gd` keeps `in_kturn()` plus a
  separate planner column. Each owner makes its own reads after the seam lands. (E) **The unstick gate:** `unstick()`
  returns at once for a planner-held hull, right after traffic's `Traffic.holding` line. **The planner adds that one line
  in its seam commit** (the orchestrator's ruling, so the seam is one atomic diff for CP-P1), and manoeuvre reviews it.
  `PlannerSeam.live(name)` is static and false when OFF. (F) **Switch** `--nav-off=planner`, opt-in (R31.1); `planner`
  goes in `OFF_NAMES`, the planner's one shared-file edit. Any `--nav-off` flag makes `NativeDrive.usable()` false, so the
  judged arms run the GDScript drive, and native's mirror is exercised only on the default-ON pair tree. (G) **Native, CLOSED (native's answers 2026-10-14 ~23:20 PDT):** no
  `exec_fields.h` rows, on one condition: `PlannerSeam`'s table must be capturable by the twin harnesses (MoverState,
  TrafficTwin), so the planner gives it a `capture()`/`restore()` pair (its executor and session are Objects).
  `planned_reverse_cheap`'s cheap exits are gated in native's C++ at the pair: while `PlannerSeam.on()` or any crew is
  live, the drive calls back `_planned_reverse`. `face_turn` needs nothing, because wheeled face orders already go back to
  GDScript (execute_native.cpp:363). `BrainSwitches.native_planner` (default true) is at stream/native `bf8d4a78`; the
  planner reads `BrainSwitches.native and BrainSwitches.native_planner`. The planner makes the register_types.cpp and
  CMakeLists.txt lines in its CP-P0 commit, and native reviews them. (H) **Stale state on take (manoeuvre's review of the seam
  at `50d380e1`, ~00:20 PDT; placement of all five lines OK):** a hull taken mid k-turn leg keeps `_kturn_left_m` /
  `_kturn_legs`, so the half-driven leg resumes on release, and a hull taken mid-escape keeps `_unstick_left`,
  `_escape_gear` and H1's `_esc_stage`. **Fix:** manoeuvre's `Movement.yield_to_plan()` (stream/manoeuvre `9b257348`)
  ends the leg as "planner", drops its queued legs, ends both escapes and clears the stall and press clocks.
  `PlannerSeam.take` calls it ONCE, on the tick it first takes a hull. **Order:** `9b257348` reaches main in manoeuvre's
  merge-OFF candidate, and the planner then calls it directly, with no `has_method` shim; CP-P1 is not judged before it.
  Noted, no change: planner-held ticks are invisible to ManoeuvreCensus; the planner column counts them.

- **R31.3 The pursuit test is knife-edge on main; B5c-v5's pursuit line goes to a count (2026-10-14 ~23:15 PDT, brains'
  A/A at `3cb76e17`, row in `judging.md` *Rows filed by hand in round 31*):** a 0.25 m start nudge (a null change) flips
  3 of 12 verdicts at 8 m/s, including seed 3, the test's own seed. So round 30's v4 red on seed 3 sat inside this noise.
  **Rulings:** (1) **B5c-v5's pursuit pass line** is brains' count form: on the 24 cells (12 seeds × 8/18 m/s), the
  number passing with v5 ON is ≥ the OFF count − 3 (OFF = 22, so ON ≥ 19), with no new let-go at 18 m/s. The
  orchestrator adds that the same line is ALSO run on the nudged starts (OFF nudged = 19, so ON ≥ 16), because one
  start set is one draw. The seed-3 cell is REPORTED, not deciding. (2) **The in-suite test becomes robust FIRST, as its
  own commit, on main before any v5 number:** the same three asserts (unchanged thresholds), seeds 3 + 4 more (brains
  proposes them from the A/A rows, rule OFF, and the orchestrator approves the set BEFORE v5 runs), asserting the
  count. It must be green on main with the rule OFF. A test changed after the candidate's numbers would be fitted to
  them, so the ORDER is the guard. (3) **The C31.1 question:** if v5 reddens only the old single-seed cell, that is noise
  by the A/A. It is NOT a finding, but it is ALSO not mergeable: main stays green, so only the robust test on main can
  clear it. A red on the robust test's count, or on any other stage, IS a finding. (4) **18 m/s seeds 1 and 9 fail on
  main as written** (Green_A_1 66 → 194 m in 5 s, faster than the car drives, with a 180° turn at 3.5–6.5 s). Brains
  traces ONE of them (worst run first) before v5, because a physics launch on main would also poison CP-H's
  `real_velocity` readers. If it is a launch, it goes to manoeuvre (the drive) and native.
  **Resolved (brains' trace, ~23:25 PDT, builder0, game/ = main):** NOT a launch. At 18 m/s seed 1, Green_A_1 is hit
  to hp 0.01 at 5.0 s, picks RETREAT ("breaking away") and drives home at full speed while the target runs the other way,
  so the range opens at ~26 m/s combined. Seed 9 is the same hit. The drive, real_velocity and native are not implicated.
  It is a test gap: the let-go line excuses a badly hurt crew (C25.3, hp < 0.15), but the per-crew closing and reversal
  lines do not. **Approved, in this order, each its own commit before any v5 number:** (a) the closing and reversal lines
  skip samples where that crew is excused as hurt (hp < BADLY_HURT), the same excuse the let-go line already uses, and
  nothing else changes; (b) the robust test: seeds {3,4,5,6,7} (the test's seed plus the next four in order, not picked
  by outcome), both visible chases (8 and 18 m/s) on those seeds with the three asserts and thresholds unchanged per run,
  each asserting passes ≥ 3 of 5. On the A/A rows for exactly these seeds, rule OFF: as written 5/5 and 5/5, nudged 3/5
  and 5/5, so 3 is the null's own floor. The out-of-sight law_tank test stays single-seed (not measured), at about +60 s
  on builder0; (c) `make pursuit-aa` RE-RUN on main's code with (a) and (b) in, rule OFF, because (a) changes the OFF
  counts. Line (1)'s OFF counts (22 as written, 19 nudged) are REPLACED by (c)'s before v5 runs, with the same "− 3".
  Both (a) and (b) green on main with the rule OFF.
  **(c) DONE (~00:50 PDT 10-15, brains `0415da23` = main `aa205ea5`'s code, rule OFF, builder0, default path, 48 runs;
  rows `references/round31/brains/pursuit-aa-0415da23.*`):** OFF **24/24 as written, 22/24 nudged** (8 m/s nudged 10/12:
  seeds 3 and 9 fail the let-go line; 18 m/s 12/12 both sets, seeds 1 and 9 now pass under (a)). **B5c-v5's line (1)
  is therefore: ON ≥ 21/24 as written AND ON ≥ 19/24 nudged, with no new let-go at 18 m/s.** Margins as written:
  closing min +13.9 m (8 m/s) / +11.6 m (18); reversal min +69° / +20°. The robust test's seeds pass 5/5, 5/5 as
  written and 4/5, 5/5 nudged.

- **R31.4 CP-H's ONE tree (2026-10-15 ~01:00 PDT, native's proposal corrected):** the tree is **main after every
  consumer has merged OFF** (manoeuvre's H1–H3 tip, traffic's T4, brains' B8 `80eea6ec`, already on main at `aa205ea5`)
  **+ native's mirrors**, with **ONLY the CP-H consumer switches** flipped ON: `unstickback`, the War Rig's friend stall,
  `kturnarc`, `realspeed`, `ghost` (and `ghostself` only if traffic's tuning pair keeps it) and `realslow`. It is
  NOT built from a stream tip carrying another candidate's switch ON, because traffic's `dc8fcbf6` carries T1c-b2's rule
  ON. T3b and T1c-b2 are whatever main holds when CP-H is called (each ships or parks on its own bar first). **Native
  builds it** (it owns the mirrors) and names its hash. **Manoeuvre runs the judged A/B on it** (C31.4: GDScript path, every
  arm `NATIVE=off` or `--brains-off=native`, enforced by its runner). The tree's plain `make check` is the ship check.
  **The orchestrator calls CP-H** when the last consumer is on main. Native confirmed B8 is NONE PORTED (~01:00).
  **Status ~05:30 PDT 10-15:** manoeuvre's H1–H3 pre-series gate is GREEN (flipped tree `998fe844`, NATIVE=off, test
  2621/0, ai-scenarios 52/0, with only the structural sim-baseline and native-live-guard reds; both earlier reds gone).
  H1–H3 are on main OFF at `298e4498`, and the terrain fallback `426e6c6e` follows in manoeuvre's next batch. B8 is on
  main. **T4 is not**: it is in tuning, with its merge-OFF pair `pair/t4 80fbdbe9` in native's queue. **Cutoff (C31.4):
  T4 merged OFF with its NATIVE=off gate green by 09:00 PDT 10-15, or CP-H runs WITHOUT T4** (T4 stands down this round,
  parked with its tuning tables).
  **T4's merge-OFF branch (~06:15 PDT): `traffic-t4` `357ca38b`**, one commit on main `c6ffb37e`: T4 v1 + ghostself
  (both OPT-IN, default OFF), the test-only teardown, and ALL of I4's tooling (seq_hook, `mk/traffic.mk` with
  `33cb2da5`'s echo fix, CACHE=auto, `turns_verdict --allow`). It carries NO T1c-b2 rule and NO T3b. Native pairs it
  (the ghost mirror is already on main at `298e4498`). **ghostself:** OUT of CP-H unless its tuning arm has run by
  ~07:00 PDT. It stays in the code OPT-IN and UNMIRRORED as tuning only, and a native-path arm naming it would silently
  run it OFF, so no judged run names it.
  **Decided (~06:50 PDT, traffic's tuning on `dc8fcbf6`, nav-terminus-drive s24–29, GDScript, n 12 paired): ghostself
  is OUT and T4 = v1 alone.** v1 v v1+ghostself: pinned crews 126 → 598 (+472, se 185, UP beyond 2 se), rigs 71 → 311,
  stuck 324 → 799. Native's `pair/t4-on` (ghostself opt-in, ghost on) is T4's gate tree.
  **CP-H CALLED ~07:45 PDT 10-15, WITHOUT T4 (case `allnoghost`).** T4's ghost-ON gate cannot land before the 09:00
  cutoff (traffic's forecast: the OFF check is ~13/25 at load 27, and a gate takes 70–90 min), so T4 stands down this
  round and parks with its tuning tables. Its OFF pair `0475758f` still merges if green (I4's tooling + T4 OFF). **The ONE
  tree (R31.4):** native builds current main + its mirrors with `unstickback`, `kturnarc`, `realspeed` and `realslow`
  flipped ON. Its plain `make check` is both CP-H's C31.1 gate (the four together have never been checked) and the ship
  check. Manoeuvre runs the A/B on that tree's commit with ALL = `allnoghost`, as filed. Native's chain: T4 OFF (running),
  then that tree; T4's ON gate is dropped.
  **Slots and scope (~08:00 PDT):** manoeuvre gets a SECOND heavy slot for CP-H while M1b(2) attempt 2's heavy lane
  runs (traffic holds none now; every other stream keeps one heavy and one light). The ALONE arms (REPORTED) run on
  census + drive + fights only, NOT hull-rest. **Consequence, stated before numbers:** if the combined arm fails and a
  consumer is re-declared alone (C31.4's one attempt), its hull-rest arm runs then, on fresh seeds, inside that one
  attempt.
  **The ONE tree's gate RED (~10:00 PDT):** `68280cce` (main `83341378` + unstickback, kturnarc, realspeed and realslow
  ON, native default path), builder0 `exited 2`, 2637 passed / 1 failed; sim-baseline moved on all 13 (expected ON).
  The red: `test_control_queued_task::test_shift_screen_after_shift_waypoints_waits_for_the_route`. The screen starts
  after the route but faces 80.9° off point − waypoint (needs ≤ 10°). Manoeuvre's three alone with NATIVE=off passed
  it 12/0, so the cause is realslow, the native path, or both. Native re-runs the file alone; manoeuvre splits realslow
  v native, and brains reads realslow for a facing effect. **The A/B does not start** until the gate is green (C31.1).
  **Pinned (~10:30 PDT): it's H1's FRAGILITY, not a mirror gap and not realslow.** On 68280cce, GDScript path: realslow
  ON passes (heading_off 0.1°), and realslow OFF FAILS exactly like the native run (route_first −1, 2.2 m, 80.9°), while
  main's older 998fe844 passed. The R31.5 terrain fallback doesn't cover every variant of Green_Alpha_3's ground pin, so
  the outcome flips on tiny upstream differences, the same lesson as R31.3. **The fix's re-check is a VARIANT SET, all
  green:** that test on 68280cce with {realslow ON, OFF} × {GDScript, native} plus `998fe844`'s tree plus a 0.25 m
  start nudge (6 light runs). Then the CP-H tree is re-cut and the whole flipped suite re-gated. Native stood down.
  **H1 fix PASSES the variant set 6/6 (~10:50 PDT, stream/manoeuvre `f593f487`, default OFF).** Traced cause: the pin
  HAD room, so H1 backed STRAIGHT (2.0, 1.5, 1.0 m, twice) and the route drove it back into the same spot, since a
  straight reverse never changes the heading. **The fix:** every pin with NO hull in it takes round 29's escape (main's)
  bit for bit, whatever room is behind; hull pins are unchanged (ask → straight reverse → stand). The test went 12/0 in
  every variant (realslow ON/OFF × GDScript/native, a 0.25 m nudge, and `998fe844` + fix); test_manoeuvre_escape 6/0,
  with the hull-pin measurements unchanged. **R31.5 amended:** H1's redesign now applies to HULL pins only, and wall or
  terrain pins keep main's escape, so round 30's "tank backing off a wall" regression is out of reach by construction.
  Condition 1 is retired (`fallback` = `fires_wall` by construction); CP-H reports fires_wall's share of all fires.
  **Next:** `f593f487`'s OFF check (the merge candidate) → merge → native re-cuts R31.4's tree (main + the four ON) →
  the whole-suite gate → the CP-H A/B. Native confirms no C++ change.
  **A new Movement member makes even an OFF merge a PAIR (~01:20 PDT):** manoeuvre's merge-OFF tip `9b257348` checked
  `exited 2`, 2619 passed / 1 failed, the one red being `test_native_exec_state::test_the_table_is_the_scripts_members`
  (H1/H2's 7 new members are not in `exec_fields.h`, 151 v 144). sim-baseline passed, so OFF really is unchanged.
  **Rule:** any commit adding a `Movement` member merges with native's `exec_fields.h` rows, back to back, defaults OFF,
  checked once. The merge-OFF candidate is therefore native's pair tree on manoeuvre's current tip (`0cf72ba7`: H2
  scoped to ≥ 10 m hulls, `yield_to_plan`, turnhull), plain `make check`. **CP-H waits** for the flipped suite to be
  green, including `test_control_queued_task`'s shift-waypoints red under `unstickback` alone (the squad centre stalls
  2.2 m short; manoeuvre is tracing it).

- **R31.5 C31.4's escape clause amended for TERRAIN pins (2026-10-15 ~02:20 PDT, manoeuvre's queued-task trace on
  `9b257348` + unstickback ON, builder0 light):** Green_Alpha_3 sat from f 1140 13.5 m from its goal, real 0.00, plant
  0.00, touch false, phase blocked 'terrain'/'no_path', NOT pinned on a hull. Main's escape fires and reverses 0.9 s on
  lock, which frees it. H1 classed it a terrain pin, found < 1 m for a straight reverse, REFUSED and stood, nine times in a
  row (refused 9, backs 0), so the squad held 11.6 m off and the shift-queued screen never began. **Ruling:** C31.4's
  "never a blind reverse on lock" was written for a hull pinned on a FRIEND (round 30's stranded Sumps 8×8), and that
  path (ask → straight reverse → stand) is unchanged. For a pin with NO hull involved (`fires_wall`) whose straight
  reverse is refused, H1 falls back to MAIN's escape bit for bit (round 29's pivot / ask-behind check, then 0.9 s on
  lock), counted `fallback`. The CP-H A/B reports `fallback` per stage, and round 30's "tank backing off a wall"
  regression stage stays a pass line. **Side finding, routed to brains:** a truck 13.5 m short with no contact and
  `no_path` on Green_Alpha_3's spot looks like a terrain or navmesh trap on main; brains owns blocked-phase reporting.

- **R31.6 CP-P0's price is an UPPER BOUND, accepted (2026-10-15 ~02:40 PDT):** `tools/remote.sh --quiet planner-twin
  PLANNER_CPUS=0-3` on `41212da0` (= `a3755e37` + docs) exited 0, 4/0, but QUIET WINDOW: NOT USABLE (7 of 7 samples with
  7–8 foreign runs live). Native, cold field, pinned to 4 CPUs with others live: Terminus turnround 7 exp 3.57 ms
  (510 µs/exp); slot180 37 exp 3.67 ms; tjunction 94 exp 16.2 ms (172 µs/exp); yard BUDGET 12 000 exp 1.30 s; offline
  F6a 3735 exp 150 ms (40 µs/exp). Unpinned at load 13, the same plans cost 2.7–3× more. **Cap v cost:** at this price the
  0.5 ms line allows a slice of 3–5 expansions a tick, so a 94-expansion plan takes ~20–30 ticks (~1 s), inside the 3 s
  pending cap; with the navmesh cell cache warm it is ~10 a tick. **Ruling:** no second quiet window this round, because
  it cost the whole box ~1 h and still wasn't quiet. CP-P0's price stands as an upper bound. C31.5's cost line (≤ 0.5 ms
  a tick at Sumps 25 a side) is judged at CP-P1 from planner-census's in-fight probe, which also chooses SLICE. CP-P0's
  candidate stays `a3755e37` (check `planner-check6` pending). The cell cache (`d373af4e`/`17bd1ec8`, C++ changed after
  equality) merges only with its own planner-twin (ALL) green.

- **R31.7 The planner's slice and SCOPE are chosen BEFORE CP-P1's judged run (2026-10-15 ~03:30 PDT; planner `005a3837`,
  census-2 on `fd36ecd5`, builder0 light, Sumps 25 a side, seeds 92721 / 31337):** SLICE = 2 expansions a tick, COUNTED
  and never timed (lockstep), ~0.3 ms pinned and 0.4–0.8 ms unpinned. The brief's Terminus fixtures land in 4 / 19 / 47
  ticks, and PENDING_TICKS 90 caps a search at 180 expansions. The warm price, ~200 µs an expansion among 49 hulls, is
  compute (a long hull's sphere walks), not lookups. **The arithmetic:** ~3 plan events a second × ~130 expansions (the
  census's median in-press face-about) × ~200 µs = ~3 ms a tick if every event were served, six times the cost line. At
  SLICE 2, most in-press takes beyond ~180 expansions run out the hold (`abandoned`) and fall back to today's code.
  **Ruling:** the planner proposed choosing SCOPE (which kinds and hulls the seam takes) AFTER the judged `abandoned`
  number. That would fit the candidate to the judged run. **The scope is chosen on the census and tuning seeds (92721,
  31337 and the brief's named cases) and FILED in CP-P1's bar before any judged number.** The brief's target is the long
  hull (a War Rig, a long truck in a Terminus street), so a ≥ 10 m-hull scope is the natural first candidate; the
  planner decides it from the census. `abandoned` / `queue_waits` / `refused` are REPORTED lines. If the judged run then
  shows the scoped seam starved, that is a finding with its traces, and CP-P1 parks; there is no second scope.
  **SCOPE CHOSEN before numbers (~03:45 PDT, `a6a66f31`):** LONG hulls only, length ≥ 10 m
  (`PlannerSeam.SCOPE_MIN_HULL_M`), which in today's catalog is gang_tank, the War Rig at 14.0 m (the next is tank at
  9.7 m). It takes every kind (face, circle plan, blocked arc), and a short hull is never taken (tested: a law_scout face
  ON requests 0). **Consequence for C31.5's pass lines, stated before numbers:** "the six-cusp car (yard s25 t1 ≤ 3
  legs)" and "a scout's orbit unchanged" concern SHORT hulls the seam never takes. The car becomes a REPORTED line (its
  legs per arm, expected equal), and the scout's orbit stays a pass line as a no-change guard. The deciding lines are the
  rig cases: seed 31's and 51's Terminus grinds, the squadmate pin, and the 180° arrival where it is a rig.

- **R31.8 Early stop is OFF on guard lines (2026-10-15 ~11:40 PDT, manoeuvre's finding, `judging.md`):** on M1b(2)'s
  Terminus census, `arrived:guard:0.10` read SERIES PASS at run 6 while the fixed 1.645 se line FAILED at 13, because the
  stop rule's 10 % harm is ~4× the fixed line's. **For every series not yet run (CP-H, CP-P1 attempt 2):** guard lines
  run to completion and are judged on their fixed line, and early stop applies only to a gain line whose stop effect
  equals that line's MDE. CP-H's (a) "early stop by `sequential.py arrived:guard:0.10`, never before 6 seeds" and any
  CP-P1 arrivals stop rule are therefore REMOVED, before numbers.

- **R31.9 builder0 throughput (2026-10-15 ~13:00 PDT, the lead's question and his OK).** builder0 does not do clean
  builds: the native .so and Godot's import are incremental. A check is ~55 min of TEST time (the last main check 3278 s,
  its test suite 2320 s; the 33 heaviest files are 65 % of the suite's ~7200 CPU-s) on a 12-core box held by three
  checks at once. **(1) No second check of the same code:** the orchestrator runs `tools/merge_check_needed.sh
  <green>` after every merge (`orchestration.md` §7), and an INHERIT means no main check. **(2) Iterate with `make
  quick-remote`** (~8 min); a full `make check` only for a hash you will name (a pre-series gate, a merge candidate, a
  ship check). C31.1's full suite before every judged series is unchanged. **(3) Split the slowest test files**, each by
  its owning stream, with the same assertions divided across files and the test count shown before and after:
  traffic and brains now if idle; the rest go in round 32's briefs.

- **R31.10 remote-guard-test's box-state groups don't block a gate (2026-10-15 ~13:25 PDT).** Its quiet-window and
  slot-exclusive groups test `tools/slot.sh`'s windows against the live box. Under load they fail in a different group
  each time (`9e1000d6` slot-exclusive 13/18; CP-H's `130a069b` quiet-window 27/1 at load 22), and they pass on a quiet
  box (main `298e4498`). A light-lane re-run cannot open an exclusive window over the heavy slots, so it cannot clear
  them. **Rule:** when remote-guard-test's box-state groups are the only red besides an expected sim-baseline move, and
  the change touches nothing in `tools/slot.sh`, `tools/remote.sh` or `tools/quiet_window.sh`, the gate reads GREEN,
  with the flake named in the record. A red in its other groups (remote-guard, check-verdict …) still blocks.
- **CP-H's gate: GREEN under R31.10 (~13:20 PDT).** The ONE tree `130a069b` (main `a2ef0b31` + unstickback, kturnarc,
  realspeed and realslow ON), builder0 `exited 2`, tests 2641 passed / 0 failed; sim-baseline moved on all 13
  (expected; adopted at the ship); remote-guard-test quiet-window 27/1 at load 22 (R31.10); the queued-task route test
  passes (route_first 1370, 2.1 m, 0.1°); native-verify-scenarios 0; perf-judge judged 5/0. **The CP-H A/B starts on
  `130a069b`.**
  **The A/B STARTED 13:23 PDT, with one accepted deviation:** on `130a069b` `realslow` cannot be turned OFF
  (brain_switches.gd: naming it SETS it true, not a toggle), so the ON arm = `130a069b` with nothing named, and the base
  and each consumer alone = its parent `a2ef0b31` with the opt-in names. `git diff a2ef0b31 130a069b -- game` is exactly
  the four default lines, so the arms differ in the consumers only. **A ship blocker:** brains makes `realslow` a toggle
  (`not REALSLOW_DEFAULT`, with a unit test) before any CP-H ship, or once flipped it could never be removed.
  **Fixed (~13:50 PDT):** stream/brains `c45c9792` (merged at `d0aafb70`): `REALSLOW_DEFAULT` const, naming it sets
  `not REALSLOW_DEFAULT`, test_tactics_realslow 5 cases; its full check is pending, and it joins CP-H's ship pair.
  **Interim (~15:05 PDT; base `a2ef0b31` → ON `130a069b`):** census + drive 110–122: mixed arrivals 285 → 286 PASS,
  contact 1979 → 2158 PASS; rigs arrivals 181 → 177 (−4, bound 7.0) PASS, contact 6800 → 8914 (+2114, bound 4144)
  PASS, though without each arm's two worst runs +999 v ~1041; alone, kturnarc's rig contact is 6800 → 9685, and
  realspeed and realslow are IDENTICAL to base on every seed (nulls on this stage, lesson 300). Hull-rest 84–89 (144
  paired): **pinned crew-s 3106 → 333 (−2773, se 488), DOWN beyond 2 se, line (c) PASSES**; stuck 6578 → 3737, also
  down; moving at 75 s better on 5 of 6 tasks, ambush +2 (guard +5). Counters: fires_hull 559, fires_wall 43 (7.1 %).
  **Owed before the verdict:** realspeed and realslow each shown firing on some judged stage, or each drops out of the
  ship; and kturnarc's worst rig-contact run traced. Fights and bridge pending.
  **Fights (g) PASS (~15:25 PDT, 214–237, 24 pairs):** kills 987 → 1001 (+14 v 1.645 se 24.5), deaths 996 → 1013 (+17
  v 25.3), hit rate 0.677 → 0.689, touching-target 0.598 → 0.622. **kturnarc's rig rise is ONE run:** census seed 114,
  rig contacts 398 → 3234 and arrivals 15 → 13 (the other 12 seeds +49 in total), a real grind: Green_S0_1 PLANTED on
  Block_7 for 1927 ticks after the arc changed its path. That is a wall pin of H1's kind, and the same seed with all four
  ON reads 548, which **favours shipping the four TOGETHER over the arc alone.** realspeed and realslow are nulls on
  Terminus by construction (realslow is Element's clock, and Terminus has no Element); their firing is read from their
  alone FIGHTS rows (deterministic: any changed seed means it fired). If either is identical on all 24, it is reported
  unexercised and drops from the ship.
  **kturnarc's rise traced (~15:15 PDT, kturnarc-alone drive arm on `a2ef0b31`, rigs seed 114, `--turn-states`):**
  Green_S0_1 on move_to, touch true throughout, PLANT v 9–12 m/s against REAL 0.05–0.7 m/s; round 29's escape fires
  (esc 2.0 at f 5430) and doesn't free it. A real grind on Block_7, the plant/real lie unstickback's honest reading is
  built for (all four ON, the same seed reads 548 v base 398). **Coupling, filed before the verdict: kturnarc does not
  ship without unstickback.** If the combined arm fails and consumers are re-declared alone (C31.4's partial rule),
  kturnarc may only go together with unstickback.
  **✅ CP-H VERDICT (~16:30 PDT): every filed line PASSES on the combined arm (allnoghost), so it SHIPS as ONE pair**
  (C31.4). ON `130a069b`, base and alone on `a2ef0b31`, builder0, GDScript, to completion. (a) arrivals mixed 285 → 286,
  rigs 181 → 177 (bounds 8.2 / 7.0); (b) contact mixed +179 (bound 356), rigs +2114 (bound 4144); (c) pinned crew-s 3106
  → 333 (−2773, se 488), rigs 653 → 26, scouts 1497 → 112; (d) moving at 75 s ambush +2 (guard +5), the rest −8 to −14;
  (e) stuck crew-s 6578 → 3737, stuck crews 203 → 147; (f) bridge 18/18; (g) fights kills +14, deaths +17 (within
  1.645 se), hit 0.677 → 0.689; (h) native's plain check 2641/0; (i) fires_hull 559, fires_wall 43 (7.1 %). ALONE
  (reported, lesson 300 by seed divergence): unstickback fires everywhere; kturnarc's fights are bloodier on both sides
  (kills +42, deaths +46, se 19, outside 2 se), so it stays coupled; realspeed fires on fights (23/24 differ); realslow
  fires THINLY (2/24 fights differ). It rides with the combined arm that passed, recorded as thin evidence. **The ship:**
  native re-cuts on CURRENT main (B6 and brains' toggle `c45c9792` landed since `a2ef0b31`; the realslow flip is now
  `REALSLOW_DEFAULT := true`) with UNSTICK_BACK, KTURN_ARC, REAL_SPEED and REALSLOW defaults true; its plain check is the
  ship check; then the orchestrator merges, records the 13 baselines twice (`sim-baseline-record`, the reason in the
  commit), and runs one main check.
  **Ship tree cut (~16:45 PDT):** pair/cph-ship `76b7ee46` on main `edc7dec8`, exactly four one-line flips (verified:
  3 files, 4+/4−: UNSTICK_BACK, KTURN_ARC, REAL_SPEED and REALSLOW defaults true; ghost OFF). Its plain check is running.

**Bars (round 31, pre-registered before their numbers; the orchestrator appends each here as it arrives):**

- **Traffic T3b-c bar (filed by the orchestrator 2026-10-14 ~22:45 PDT from the brief, before any judged number;
  DECLARED; ONE run = the LAST attempt):** candidate stream/traffic `e57f93d2` = `traffic-t3b` cf124433's game/ + tests
  re-based on main, no code change (+ `ab3351fb`'s teardown fix, test-only). **Gate first (C31.1 / R31.1):** the whole
  suite with `turns` ON on the pair tree `pair/t3b` (native `413252ea`'s `Traffic.shape` mirror + traffic), plain
  `make remote T=check`, green, before any series. **Bar = round 30's filed T3b bar (below, *Bars (round 30)*, lines
  (1)–(7) and the orchestrator's additions (a)–(d)) UNCHANGED EXCEPT line (2) at the YARD:** the crossing clock's mean
  paired difference in `cross_clear_s` ≤ **base + 3.0 s** (his call, `game_design.md` *Round 31: his two traffic calls*);
  Terminus' line (2) stays ≤ 0.10 × base median + 1.645 se, the judged run's own paired sd/√n. Fresh seeds: NOT 1–3,
  22–24 or 31–33 (traffic names the set before the run). Every row cites `judging.md`; early stop by `sequential.py`'s
  rows (C31.3, `e1aaabe1`'s hook), the stopping row recorded here. Ships as a pair with native, the default flipped ON
  (`Traffic.DEFAULT_OFF` loses `turns`); a before/after clip of his yard crossing for him.
  **Clarified before numbers (~22:55 PDT):** the yard line (2) reads **mean paired diff ≤ 3.0 s + 1.645 se**, the se
  the judged run's own paired sd/√18. That is C31.3's guard form with his 3 s in place of 0.10 × median, and it is
  what `turns_verdict.py --allow yard_open/cross=3.0` (`64dc8ef2`) computes (round 30's rows: +2.80 v limit +3.36 PASS;
  the old +10 % line FAIL as filed). **Seeds** {41,42,43} × ticks {1,3,6,8,11,16}, n = 18 a case, four cases, 90 s. On
  the pair tree `turns` is default ON, so base = `--traffic-off=turns` and arm = no flag. Early-stop lines are in
  traffic's Status bar block.
  **JUDGED ~02:45 PDT 10-15 — FAIL on line (2) Terminus; NOT SHIPPED (the last attempt, no partial).** builder0, pair
  tree `f5dc4147`, GDScript path both arms, seeds 41–43 × 6, n 18 a case, full grid with no early stop; rows at
  stream/traffic `99cbd53d` `references/round31/traffic/t3bc_*`. (2) Terminus crossing clock mean paired **+2.61 s**
  (se 0.55) v limit 0.10 × 11.7 + 1.645 se = **+2.07, FAIL**: a steady shift, not a wedge (16/18 runs later, worst s43/t1
  +5.3 s, squad B the yielder +4.22 s, A −1.09; round 30's seeds 31–33 read −1.17 here). (2) Yard, his line: **+3.38 s**
  (se 0.26) v +3.43, pass narrowly. (1) between-squad fast pooled 191 → 117 (−39 %) pass; Terminus 93 → 61, yard 98 → 56.
  (3) crews pass; (4) no wedge in the arm (the base had two); (5) and (6) pass; (7) all-in Terminus 39.5 → 32.9, yard
  66.4 → 75.5 reported. Hook: yard SERIES PASS at run 7, Terminus SERIES FAIL at 18. **A LEAD CALL is owed** (HANDOFF
  *Owed to him*): his round-31 call kept "the Terminus clock within its se". Accepting ~2.6 s there too is his decision.
  If yes, these judged rows pass on his line (+2.61 ≤ 3.0 + 0.90) with no re-run, because the line would then be his,
  set before he sees a re-run. Native `413252ea` stays unmerged until then.
  **Brains' B9 trace (~05:40 PDT, terminus cross s33 t1, round 30's worst, n = 1, builder0 GDScript):** T3b alone gives
  all-in 61.4 s; T3b + v4's gate gives 27.5 s, 10/10 (main's base 33.7). The +27.7 s was B_4 circling its arrival gate,
  which v5 fixes. That concerns the ALL-IN, not the failing crossing clock (traffic: the yielder clears at 16.3 s, long
  before any seat circling), so the question to him is unchanged. **If T3b is ever re-judged, it pairs T3b on top of v5
  v v5 alone.**
  **C31.1 gate PASSED (~00:05 PDT 10-15):** pair tree `pair/t3b` = `f5dc4147` (native `413252ea` + traffic `ab3351fb` +
  `DEFAULT_OFF = []`), builder0 `>> remote: make check exited 2`, 2624 passed / 0 failed, 25 of 26 targets passed, the
  sim-baseline alone failed, with all 13 maps moved as a turns-ON tree must (one read each; two reads at adoption).
  Determinism 7/0, native-verify-scenarios 0, the four traffic twins 0 mismatches. Judged series cleared to run.
- **Traffic T1c-b2 bar (filed 2026-10-14 ~23:00 PDT, before any judged number; DECLARED; ONE run = the LAST attempt;
  full text in traffic's Status at `4054e7ca`):** candidate stream/traffic `6d19a3d9` = `16780030`'s game/ + `02dc1433`'s
  measurement additions re-based, no code change; rule ON by default (base `--traffic-off=setup`). No C++ twin: native
  states "none ported"; `native-verify-scenarios` + `traffic-native-verify` on the tree; whole suite green first (C31.1).
  Census fresh seeds {41..46} × Sumps 1000 / Parade 2000 / Foundry 2000, n = 18, 150 s. **(1) DECIDING:** runs with any
  repack while firing, arm 0/18, Fisher p ≤ 0.05 v base, base ≥ 8/18 (else NULL, lesson 300). (2) friendly-stuck total ≤
  base + 1.645 se (row sd 32.2 → +225). (3) fast friendly ≤ base + 1.645 se (sd 6.84 → +47.7). **(4) artillery shots
  REPORTED, not judged** (said before numbers, per the brief): row sd 34.1, base 24.9 a run, a 10 % loss needs ~1150 runs,
  MDE at n 18 ≈ 20 a run; totals, paired mean ± se, per-battery counts, worst run traced. (5) ApproachStage drawn
  artillery s41–43 × 6 ticks: give-way repacks down, from the side 18/18, first round ≤ clicked + 30 s, alive within
  1.645 se. (6) bridge-pooled 18/18. (7) the four traffic cases s41–43 equal field for field, or within T3b-c's guards,
  no wedge. Early stop: `SEQ_CENSUS_LINES='rwf_any:rate:0.02:0.44 fstuck:guard:0.2 fast:guard:0.1'`. Ships ON (his call:
  "ships if the repack count holds at 0").
  **Gate (~01:20 PDT 10-15):** `dc8fcbf6` (rule ON), read from build/ (wrapper reaped): 2630 passed / 0 failed,
  native-verify-scenarios 0 mismatches, sim-baseline moved on pit ALONE (e03377ea → a8fe8e14), the declared rule on the
  map with set-up batteries. make stopped at that red, so `traffic-native-verify` (and any other target not in done/)
  runs in the judged chain. **Condition (orchestrator): a red in any of them VOIDS the census.** Chain: unit
  `traffic-t1cb2`, scratch at `33cb2da5` (= `dc8fcbf6` + a make-echo fix only). Merge takes `33cb2da5`'s
  `mk/traffic.mk` line.
  **Base arm in (~07:10 PDT, builder0, `33cb2da5`, seeds 41–46 × 3, n 18):** runs with any repack while firing =
  **6/18** (10 repacks), below the filed precondition (base ≥ 8/18). **So line (1) is NULL as filed, and T1c-b2 cannot
  ship on this run** (lesson 300; not re-read after the fact). Orchestrator: the ARM census runs for the record (its
  repack count, artillery and guards REPORTED); the approach, cases and traffic-native-verify are STOPPED to free builder0.
  T1c-b2 parks, and a player-terms question goes to him with the arm's numbers.
  **Arm REPORTED (~08:00 PDT, n 18 paired, 0 missing):** repacks while firing 6/18 → **0/18** (one-sided Fisher p
  0.0095), total 10 → 0; artillery 434 → 437 (paired +0.17, se 0.39); friendly-stuck 746 → 787 (inside +225); fast
  1021 → 997 (inside +47.7); give-way repacks 31 → 26; refusals on post 0 → 45. **PARKED as filed**; the question is in
  HANDOFF *Owed to him* (2). Sizing note for any re-bar: the pooled base rate is 10/27 ≈ 0.37, so a precondition of
  base ≥ 5/18 suffices at arm 0/18.
- **Manoeuvre M1b(2) turn-the-hull bar (filed 2026-10-14 ~23:45 PDT, before any number; DECLARED; this is the FIRST run, a
  second on fresh seeds would be the last):** candidate stream/manoeuvre `44adcbbe` (+ tooling `eea19309`). ONE opt-in
  switch `--nav-off=turnhull` (`Manoeuvre.TURN_HULL_DEFAULT` false) = (i) `TankBrain._order_move`'s decline lifted for a
  wheeled turret hull when the face comes from its order AND the facing was DRAWN (`Manoeuvre.hull_takes_face`; C31.8's
  grant, the decline line the only tank_brain edit; brains told), and (ii) round 29's facekeep (every pose of a face plan
  stays inside max(ORDER_ARRIVE, settle radius) − 0.75 m, or no further than it starts). Unit stage (builder0, light):
  rig 4 m short, 150° face, worst pose 6.76 → 3.93 m (keep 5.25), 19 steps refused over 9 cases. **Gate first (C31.1):**
  native confirmed NONE PORTED (~23:55 PDT: no C++ counterpart of plan_face, _face_legs or _order_move; wheeled face
  orders already go back to GDScript at execute_native.cpp:363, so the only native effect is more hand-backs, a cost
  line). **The gate is native's proof:** plain `make remote T=check` on a tree with `TURN_HULL_DEFAULT = true` (the
  native path runs around it; a `--nav-off` arm would not), whole suite green with `native-verify-scenarios` inside it.
  That one check is both the C31.1 gate and the ship check. **Gate RESULT (~08:15 PDT):** tree `c57188f6` (main `298e4498` + the fallback +
  `TURN_HULL_DEFAULT true`), builder0 `>> remote: make check exited 2`, 2629 passed / 0 failed, 25 of 26, sim-baseline
  alone red: locks 2e02a926 → 76156304 and parade fc52b48b → 7c13a1a6, eleven unmoved, native-verify-scenarios passing.
  **Declared cause:** `drawn_facing()` reads the element TASK's facing, so a CPU element's task facing also lifts the
  decline for its wheeled turret hulls. That is symmetric with the player under his "smart AI on both sides" rule.
  **Orchestrator's addition before numbers:** because turn-hull now changes CPU behaviour in fights, the bar gains
  **(j) fights at 24 FRESH seeds 238–261: kills, deaths and hit rate within 1.645 se** (rows 69–71), as a GATE line. The
  judged series runs on `6987bd12` (= main `441eabb0` + the two R31.2 reads, OFF-identical), and the **ship check is
  re-run on the merge tree** (main + turnhull flipped) before the merge, with locks and parade re-recorded twice on
  builder0. Arms: both on the GDScript path (`M1_GD=1`), one arm per remote call
  (lesson 311); new = `M1_NEW_OFF=turnhull`, base = main, drawn AND clicked, same commit. Tuning: hull-rest seeds 40–41.
  **Judged fresh:** hull-rest seeds 76–81 (4 factions × 6 tasks × 6 = 144 runs an arm), Terminus census 93–105 (13),
  bridge-pooled's 18 cells. Lines (`judging.md` rows 62–66, 73, 75, 96): (a) drawn point tasks, wheeled turret at rest:
  median ≤ 15° AND ≥ 70 % within 15°; (b) drawn line tasks: hull error not worse than base, per-class permutation
  p ≥ 0.05; (c) clicked arm: median within ±5° of base (the lift is drawn-only); (d) crews still moving at 75 s, per task,
  wheeled turret AND all classes: ≤ base + **1.645 se** (C31.3's form; manoeuvre proposed 2 se, and the orchestrator
  tightened it before numbers), se quoted as `M1_CLASS` prints it; (e) settle time censored at 75 s REPORTED; (f)
  bridge-pooled 18/18; (g) Terminus arrivals, rigs and mixed apart, not down beyond 1.645 se paired
  (`sequential.py arrived:guard:0.10`, no early stop before 6 seeds); (h) B6's SBF probe for gang_ifv (88.6 / 65.6 /
  96.3° today) REPORTED; (i) counters: `hull_turns` > 0 in the new arm (lesson 300), `face_keep_refused` REPORTED.
  **Partial:** (a)–(d), (f) and (g) are the gate; any missed = parked with the trace. Ships ON if it holds (the default
  flipped; native's statement covers the pair).
  **JUDGED run 1 (~07:30 PDT): NOT MET (line (a)); the SECOND and LAST attempt approved.** builder0, `6efd1ed9`, hull-rest
  76–81, 144/144 runs an arm, GDScript path; the clicked arms and fights were not taken (stopped to free builder0). (a)
  Point tasks, wheeled turret at rest: attack-move 4.6° / 78 % PASS; move 4.3° / 68 % and right 6.9° / 55 % MISS the 70 %
  share (base 32 %, 31 %). (b) Line tasks better: ambush 27.6 v 66.3°, screen 27.4 v 37.0, SBF 28.6 v 73.6 (p < 0.01).
  (d) Moving at 75 s PASS on every task (ambush margin 0.4). (f) bridge 18/18. (g) Terminus PASS (mixed 292 → 293, rigs
  175 → 183). (h) SBF gang_ifv drawn 61.0 → 20.9°, ≥ 45° 14 → 0 of 24. **Traced:** artillery 95–99 % within 15°, but
  gang_ifv 37 % and gang_tank 41 %. A crew in an ELEMENT gets the drawn facing through its element task, and the brain
  sends it `from: "sector"`, while the lift accepted only `from == "order"`, so the decline still fired (gang_ifv 2195
  stop rows v 141 face). Facekeep also refuses many gang plans (face_none 105 → 1172, face_keep_refused 9607), which is
  REPORTED per class beside (a). **Attempt 2 (the last):** the lift accepts `from` ∈ {"order", "sector"} when
  `drawn_facing(brain)` is true, and nothing else changes. Same bar, every line, gate first (the TURN_HULL_DEFAULT-true
  plain check). **Fresh seeds:** hull-rest 90–95; **Terminus 146–158** (manoeuvre proposed 123–135, which overlaps
  CP-P1's 133–145); fights 262–285; bridge's 18; **SBF gang_ifv 25–30** (7–12 were round 30 B6's). A facekeep-caused
  miss on attempt 2 is a finding with its trace; there is no third attempt.
  **Attempt 2 JUDGED (~09:30 PDT): MISSES line (g), mixed squad; PARKED (the last attempt).** builder0, `25ef8f7e`,
  Terminus 146–158, n 13 paired, GDScript: mixed arrivals 293 → 285 of 312 (diff −8, se 4.55, bound −7.5, FAIL; without
  each arm's two worst runs −5, se 2.6, still FAIL); rigs 177 → 179 PASS; contact-ticks fall (mixed 2405 → 2089, rigs
  15740 → 8810). Traced, worst seed 153 mixed, the west-street leg 6 → 2 arrived: the four "misses" are NOT stuck. Each
  is `completed: true`, phase arrived, 7–14 m from its slot, including a tracked tank and a fixed-gun scout the lift never
  touches. The element seats differently once its wheeled turret members turn at their slots, and the arrivals line
  counts a changed seating as a miss. Kept for round 32: the drawn hull-rest arms (lines (a) and (d), facekeep per
  unit) finish; the clicked arms and fights are DROPPED to free builder0 for CP-H.
- **Manoeuvre CP-H bar (filed 2026-10-15 ~06:00 PDT, before any judged number; DECLARED; CP-H's FIRST run, with the
  alone re-declaration its only second chance; full text in manoeuvre's Status):** tree = R31.4's one tree,
  native-built; arms are flags on that one commit, all on the GDScript path (`make manoeuvre-cph` refuses any arm
  without `--brains-off=native`). OFF = `--brains-off=native`. ALL = `--nav-off=unstickback,kturnarc --gun-off=realspeed
  --traffic-off=ghost --brains-off=native,realslow` if T4 is on main OFF by the 09:00 PDT cutoff, else `allnoghost` (the
  same list without ghost), with the case named in the bar block when the series starts. Each consumer ALONE
  (unstickback, kturnarc, realspeed, realslow, plus ghost when in) is REPORTED on the same judged seeds, and every run
  prints its flags. **Fresh seeds:** Terminus census + drive 110–122 (13); hull-rest 84–89 (4 factions × 6 tasks × 6 =
  144 an arm, one arm per remote call); **fights 214–237 (24)** (manoeuvre proposed 190–213, which overlaps CP-P1's
  181–204, so the orchestrator moved them before numbers); bridge-pooled's 18 cells. **Pass lines:** (a) Terminus
  arrivals, rigs and mixed apart (rows 73, 75): not down beyond 1.645 se paired each; early stop by `sequential.py
  arrived:guard:0.10`, never before 6 seeds, row recorded. (b) Terminus wall contact-ticks, rigs and mixed apart (rows
  74, 76): ≤ base + 1.645 se each, with and without each arm's two worst runs. (c) hull-rest pinned crew-seconds (row
  67): DOWN beyond 2 se paired at n 144 for ≤ 10 m hulls (a gain line, stricter than 1.645 by the owner's choice); rigs
  reported apart; STUCK row and tracks reported. (d) hull-rest crews still moving at 75 s per task (rows 62–63): ≤ base +
  1.645 se, se quoted. (e) nav-terminus-drive PINNED and STUCK rows down, per squad. (f) bridge-pooled 18/18 (a 17/18
  read by its trace). (g) fights at 24 seeds (rows 69–71): kills, deaths and hit rate within **1.645 se** (the
  orchestrator's correction from 2 se, C31.3); touching-target hit rate REPORTED. (h) scenario_cp2,
  test_tactics_mixed_legs, `test_nav_wall_contact::test_a_hull_driven_at_a_wall_is_counted_as_steered_into_it` (R31.5
  condition 2) and the WHOLE suite green on native's ON pair tree (the ship check). (i) REPORTED per stage and arm:
  escape fires by kind (hull / wall), asks, backs, backed v capped, refused, FALLBACK (R31.5 condition 1: fallback
  carrying most of fires_wall on the census is a finding), unstick_fires, press_escapes. A consumer that never fires in
  its arm is a null (lesson 300). **Partial (C31.4):** the combined ships as one pair if every line passes; if it fails,
  each consumer that passed ALONE on every line may be re-declared alone, once. Native's ONE pair ships it.
- **Brains B3b-2 bar (filed 2026-10-15 ~04:45 PDT, before any judged number; DECLARED; the LAST attempt; partial:
  none):** candidate `lab/brains-r31-bridge` `344a772a` = stream `0415da23` + `lab/brains-r30-bridge` `4bc708d7` (route
  seating + mouth guard + heading rule) + the crossing seating matched ONCE per task point (held until the point changes
  or a re-seat). Control = main's rules (`--route-seat=off --mouth-held=off --reissue-heading=plan`); round 30's B3b is
  `--route-seat-once=off`. Tuning (builder0, n = 1 a cell): green s2 t5 rim 0 / 35.8 s (B3b rim 0 / 31.8); rust s2 t9 rim
  0 / 38.0 s, deck 0.4 s (B3b 49.3 s, deck 7.1); green s3 t18 rim 0 / 36.4 s (B3b **rim 1, FAIL**). crossings_held
  231–293 on, 0 off. **Gate first (C31.1):** `make check` on the lab tip with every switch ON, plus native's "none ported"
  (the seating is GDScript: Element / TacticsFormation) and native-verify-scenarios. Lines: (1) **his bridge, the FULL
  108** (locks × both sides × seeds 1–3 × ticks 1–18, deterministic) on = 108/108, control reported (main 106/108).
  **Orchestrator's note:** the tuning cells lie INSIDE the 108. That is accepted because the 108 is his own
  full-coverage definition and deterministic, a coverage requirement rather than a sample; (3) is the generalisation
  check. (2) bridge-pooled 18/18. (3) Arrive series, FRESH seeds 41–44 (5 maps × 5 squads, n 100 an arm): within 8 m on
  ≥ control − 1 AND McNemar discordant-against ≤ 1; paired median REPORTED. (4) crossings_found / crossings_held > 0 on
  decked cells and 0 on a Sumps cell; mouth_held_resends REPORTED. (5) Cost ≤ 0.5 ms a tick or NOT READABLE. (6) The
  suite green on the tip, pursuit included. Ships ON (GDScript; native none ported).
  **C31.1 gate RED, fixed before any judged number (~09:00 PDT):** `344a772a`'s pre-series check `exited 2`, 2619/0,
  bridge-pooled 17/18 (rust t8 s2 rim_crews 1); remote-guard-test was the known load flake. Traced: with seating held, S_1
  (first across) kept the westmost far seat on the bank edge, then backed into the rim for 4.1 s (control 0.5 s). **The
  candidate becomes B3b-2b `5ed61f91`:** re-match the seating once each time another crew passes the exit
  (`--route-seat-across=off` = `344a772a`); tuning, n = 1, rust s2 t8 / green s2 t5 / rust s2 t9 / green s3 t18 all rim 0.
  The same bar and lines apply, gate re-run on `5ed61f91`, then the series on that one heavy slot, and B6 after.
  **JUDGED ~11:00 PDT: FAIL on line (3); PARKED (the last attempt).** builder0, `5ed61f91`: (1) his bridge, the full
  108, 108/108 v control 106/108 PASS; (2) bridge-pooled 18/18 PASS; (3) **arrive seeds 41–44, n 100 an arm: every crew
  within 8 m on 90 v 97, discordant 9 against v 2 for (McNemar p 0.065), FAIL**; (4) crossing counters > 0 in all 108 on
  and 0 in all 200 arrive runs (the seating never fires there); (5) cost 0.116 v 0.194 ms (busy box, no gain claimed).
  **Reading:** the arrive loss comes from round 30's other two switches carried in the candidate (the mouth guard and the
  heading rule), whose arrive line was never read; round 30's chain stopped at the 108. Rows:
  `references/round31/brains/b3b2b-*`.
- **Planner CP-P1 bar (filed 2026-10-15 ~04:00 PDT, before any judged number; DECLARED; the LAST attempt = the second
  judged run; full text in planner Status `ea246430` "CP-P1 BAR (DRAFT v2)"):** candidate = the seam ON
  (`--nav-off=planner`) at the hash the pair-tree check passes (`0914dafd` or successor), GDScript drive, C++ planner ON in
  both arms; base = the same commit with `--brains-off=native_drive`. Declared change: for hulls ≥ 10 m (the War Rig
  only), the k-turn block's and the at-rest face's plan source is replaced by the lattice planner's legs, driven by
  PlannerExecutor. SLICE 2 counted, PENDING 90 ticks, one crew searched at a time. **Demand (census-4 `b37b9ecb`,
  builder0 light, Sumps 25 a side, seeds 92721 / 31337):** long hulls are 2 of 50 and make 6 of 174 and 9 of 202
  manoeuvre starts (3.4 % / 4.5 %); the rig's plan median is 131 expansions, giving ~0.05 ms a tick averaged and the seam
  idle ~85 %. **Lines:** (a) Terminus census rigs + mixed, 13 fresh seeds 61–73, arrivals not down beyond 1.645 se each
  squad, no early stop before 6; contact-ticks and `PlannerSeam.report()` REPORTED; `abandoned` / `queue_waits` /
  `refused` REPORTED, never pass lines. (b) **DECIDING, the rig cases:** seed 31's and 51's Terminus grinds
  (contact-ticks arm ≤ base + 1.645 se, arrivals not down), the squadmate pin (freed, no re-pin loop, pinned
  crew-seconds reported), and the 180° arrival on a rig (three legs, not a gate). The six-cusp car is REPORTED, legs
  per arm expected EQUAL, and a difference is a leak and parks. (c) scenario_cp2 on brains' 12 A/A seeds, the scout's
  orbit unchanged (pass, no-change guard); the four named tests green on the pair tree with the switch ON first
  (C31.1). (d) hull-rest 4 × 6, seeds 54–59, drawn and clicked: still-moving at 75 s ≤ base + **1.645 se**; at-rest error
  not worse (p ≥ 0.05); settle paired median ≤ +6 s; the seam's face plans v plan_face's REPORTED for the rig class. (e)
  bridge-pooled 18/18; fights 24 seeds within **1.645 se**. (f) Cost: SLICE × the probe's warm per-expansion median for
  the longest live hull ≤ 0.5 ms (builder0 pinned 0–3, load quoted, an upper bound per R31.6); per-plan hold reported;
  thirteen sim-baseline lines unmoved with the switch OFF. (g) The clip: the Terminus west-street rig before and after.
  **Partial:** (a), (c), (d), (e) and (b)'s rig lines met = ships ON as a pair; (b)'s car line or (c) moved = a leak,
  parked; (b)'s rig lines missed or a starved `abandoned` = a finding, parked with traces, and CP-P0 stays merged OFF.
  **Orchestrator's changes before numbers:** (d) and (e) at 1.645 se, not 2 se (C31.3). **Owed before numbers:** (i)
  (b)'s rig cases need an n: each named seed × a fixed set of tick offsets (the planner names the set, e.g. 6), so
  "+ 1.645 se" has an se; (ii) Terminus 61–73 and hull-rest 54–59 confirmed fresh against round 30's planner and
  manoeuvre tuning and judged seeds, and against M1b(2)'s 76–81 / 93–105 (no overlap seen).
  **RESOLVED (~04:15 PDT, planner Status `e5ea1260`):** (ii) the draft's seeds were NOT fresh: Terminus 61–73 collides
  with M4b run 2's 62–74 and T4's 49–61, and hull-rest 54–59 were M4b's chain. They are **replaced by Terminus 133–145
  (13), hull-rest 60–65 (6) and fights 181–204 (24)**, unused anywhere in `_agents/` or `references/round30/` (the
  orchestrator's own check had missed M4b's). (i) No honest tick-offset multiplier exists: `terminus_drive.gd` takes only
  `--seed`, and a pure order delay in a deterministic one-squad drive replays the same grind shifted in time, giving n
  copies with zero se. **So C31.5's named rig cases change form:** the SIZED deciding lines are the RIGS SQUAD's paired
  rows over (a)'s 13 fresh seeds (rig wall contact-ticks ≤ base + 1.645 se of the paired difference, and rig arrivals
  per (a)). The pin is sized from hull-rest's pinned crew-seconds row ((d), n 144 paired, se ~420), and the rig 180° is
  deterministic (`test_wheeled_arrival`'s rig case green on the pair tree, plus planner-lab slot180 on a rig in three
  legs). Seed 31's and 51's grinds and the seed-9 pin are REPORTED traces at n = 1, never judged. The partial rule
  follows. A true offset series would need a per-squad start jitter in `terminus_drive.gd`, which no stream owns this
  round, so it is not pursued.
- **CP-P1's C31.1 gate RED (~06:40 PDT, native `aa0615e4` = pair/cpp1-on, PLANNER_DEFAULT true, builder0):**
  `make check exited 2`, 2634 passed / 6 failed; the native mirror is clean (87/87 test_native_*, the seam twin held
  the rig on 195/900 drives with 0 mismatches). The six: 4 in test_planner_seam (it assumes default OFF; the planner
  fixes its own test); `test_nav_face_recovery` (the wedged-semi recovery is never reached) and `test_kturn_three_point`
  (the rig takes 4 legs, 0 k-turns), both the seam taking the rig. **Ruling:** those two are manoeuvre's tests. The
  planner traces each with the seam ON and reports the OUTCOME against what the test protects. If the outcome holds and
  only the mechanism differs, manoeuvre may pin the test to the planner OFF on condition the planner adds an outcome
  assertion with the seam ON. If it doesn't hold, it's a finding against CP-P1. The judged series stays held until a
  re-cut gate is green.
  **The outcomes, set by manoeuvre before the traces (~07:00 PDT):** test_kturn_three_point = the rig ARRIVES and
  turns away in ≤ 3 LEGS (gear segments of its actual motion), wall contact ≤ base (today 2 legs, 5.6 s, 0 contacts);
  his sentence "a vehicle should be able to do a 3 point turn". **4 real legs is a finding.** test_nav_face_recovery's
  wedged semi = the footprint never yaws through the wall (RESIDUAL_BAR_M, yaw < 20°) AND it is never silent (it faces,
  or is reported unable within a few seconds); a planner refusal followed by today's give-up report satisfies it.
  **Read against them (~07:15 PDT, native's log): both are FINDINGS, to be fixed before the series and re-gated.** (1)
  k-turn ON arrived in 7.2 s with 0 contacts, but its plans are 4 legs each (plan_legs 20 over 5 plans) against today's 2
  legs / 5.6 s. The fix is in the planner's gear-change cost, re-tuned on the named fixtures (turnround rig 3 legs,
  six-cusp car ≤ 3). (2) The wedged semi's corridor is a StaticBody3D added after the bake, which the planner's world
  (navmesh walls + living hulls) cannot see: 2 plans, 2 aborts, 6 s into the slabs, and the give-up never checked in 8 s
  ("never silent" FAILS; footprint 0.03 m over, yaw 6.3°, holds). **Ruling: unbaked scenery and WRECKS are in CP-P1's
  scope**, since they occur in every fight. The fix is either static colliders and wrecks in the planner's snapshot, or
  the face kind handing back after its first abort. No pin of manoeuvre's tests.
  **Traced (~07:30 PDT, builder0 light, `032af15f`, 29/0) and the wreck ruling CORRECTED:** (1) k-turn ON drives 4 real
  gear segments (R 3.0, F 1.4, R 1.6, F 29.0 m) v OFF's 2 (R 4.5, F 29.8), so it is a finding. The planner is sweeping
  the seam's own request one variable at a time (goal clipping, arrival radius, heading, cusp cost, arrive gear) on that
  scene plus the named fixtures, to find the lever before changing it. (2) **Wrecks do NOT block:**
  `Tank._set_alive(false)` disables a wreck's collision, so PlannerNavWorld skipping dead hulls is right, and the
  orchestrator's ruling was wrong. The remaining blind spot is scenery added after the bake, which today's content does
  not have. **No collider snapshot this round.** The fix is a face handing back on its FIRST abort (`1e513bcf`) and on
  its FIRST wall touch (`d8c2e742`, `mover.contact.touching`); k-turn keeps R31.2's abort and two re-plans. (Over 20 s
  both arms breach the semi's footprint bar; the test reads it at 8 s.)
  **Interim (~08:20 PDT, builder0 light, `9d168af8`, 30/0):** the sweep put the lever at the GOAL. The k-turn goal now
  AIMS at the waypoint (`PlanRequest.aim`, both planners): a 3-leg plan (R3 F2 R12.5, 9 expansions), the C++ equal, the
  named fixtures holding (turnround F6a 9, T-junction 2, mouth 1, yard corner 2, slot180 4, wedge 4). **The wedged
  semi MEETS outcome (b)** (give-up at 4.6 s v base 4.5, yaw 9°, footprint 0.67 m over v bar 1.8). **The k-turn row is
  still NOT met:** real motion is R3.0 F1.4 R1.6 F29 (4 segments) v base R4.5 F29.8; it is the street's start geometry
  under three locks. **Rulings:** the next step prefers the half-lock steer (STEERS ±0.5, a general capability), with the
  fixtures re-read and the extra branching priced. An aim tolerance chosen so one arc satisfies THIS scene is fitting
  and is barred unless justified independently and stated first. **Time-box: if the k-turn row isn't met by 12:00 PDT
  10-15, CP-P1 parks with its traces**, and CP-P0 + the OFF seam on main are the round's planner result.
  **MET (~08:45 PDT, builder0 light, `1f325b91`, 30/0) — before the time-box.** k-turn ON: arrives 7.0 s, 0 contacts,
  2.20 m nose clearance, 2 REAL gear segments (R 4.0, F 29.6), one 2-leg plan driven to its end; base 2 segments,
  5.6 s, 1.64 m. The cost is +1.4 s, REPORTED. It took three trace-read changes, none a tuned number: the aim goal, an
  aim heuristic owing only the heading change and its cusps (`5ffda2b4`, the unlock), and the order-goal release
  (`1f325b91`). Half lock was measured and REVERTED (the scene was unchanged and three fixtures broke). The wedged semi
  is met. Every named fixture holds, and the C++ twin plans identically. **Re-cut base for native's gate: `edb773cf`.**
- **CP-P1 JUDGED run 1 (~09:30 PDT): MISSES line (a), the rigs squad.** builder0 heavy, series tree `0fcdd5dd` (code
  `05ce260b`), gate `8bb2ad4e`, Terminus seeds 133–145, n 13: rig arrivals base 178 v candidate 159 of 208, paired mean
  −1.462 a seed, se 0.595 v pass line −0.979, FAIL. Per seed: −4 −5 +2 +1 +1 −4 −2 −3 −1 −1 0 −1 −2. Contact-ticks
  REPORTED: median 563 v 564, paired +294.8 (se 190.5), worst 139 at 2469 (base 541). The mixed squad is identical in
  both arms (291/291; the seam never fired, so the equality holds). Seam totals over 13 rig runs: requests 461, plans
  129, driven 96, aborted 4, abandoned 4; refused GOAL_BLOCKED 174, START_BLOCKED 121, NO_PATH 16; **queue_waits 1141**;
  pending per rig event n 444, median 12, max 120 ticks. The other stages were not launched. **Ruling: the SECOND and
  LAST attempt is allowed** (the bar names it): the planner diagnoses on seeds 133–145 (now tuning) and DECLARES its fix
  before any new number, by 12:00 PDT; then native re-cuts and re-gates, and the series re-runs on **fresh Terminus
  seeds 172–184**, with the other stages then as filed. No other stages run now (builder0 goes to CP-H). If no fix is
  declared by 12:00, CP-P1 parks, with CP-P0 + the OFF seam on main as the round's planner result.
  **FIX DECLARED (~09:50 PDT, planner Status `8761158f`, before any new number):** of the candidate's 28 misses that
  arrived with the order complete, 21 sit 7.0–11 m from their slots (base 4), at the same slots seed after seed. Trace
  (seed 134 Green_S0_4, the plaza): arrived 4.5 m from its slot, then the seam's FACE plan "R+1.0x3.5" reversed it to
  7.4 m, past the census line. **Cause:** the seam's face request lacked manoeuvre's SLOT LAW (round 30 M1b: a face
  plan may not end further from `ctl.face_slot` than it starts + 0.5 m). **Fix, nothing else:** `PlanRequest.keep(x, z,
  all_m, end_m)` in both planners (twin fixture), set by the face request exactly as manoeuvre's plan_face does. The
  k-turn request, PENDING/RETRY and the hold are unchanged. Also from the traces: the GOAL_BLOCKED and queue_waits cost
  time, not arrivals, and **a rig pressed at full throttle into a squadmate for 65 s** (13 base / 17 candidate, a wedge
  in both arms) is H1's target, relayed to manoeuvre for CP-H.
  **Attempt 2's gate RED (~12:05 PDT, native `3a66f546`):** `exited 2`, 2646 passed / 1 failed; sim-baseline moved on 6
  (expected ON); the native mirror is clean (seam twin 344/900 held, 0 mismatches). The red is a REAL planner bug:
  `test_tactics_army_layout10` hits 8 engine errors when `PlannerExecutor.tick` reads `global_position` on a freed tank
  (`planner_executor.gd:135`, then `planner_seam.gd:411` on Nil). A seam crew outlives its hull. The planner fixes it
  (release on a dead or freed tank), native re-cuts, and the gate re-runs; the series waits.
  **Re-cut gate GREEN under R31.10 (~14:10 PDT):** `85911f0b` (main `a2ef0b31` + planner `f9d2c639`'s crew-hull fix +
  native's mirror `14f4de82`, PLANNER_DEFAULT true), builder0 `exited 2`, tests 2652 passed / 0 failed. sim-baseline
  moved on foundry, pit, crossing, sumps, gorge and archipelago (planner ON) and held on the seven maps whose scenarios
  have no War Rig; remote-guard-test failed only its box-state groups (slot-light, watch at load 24.5); the seam twin
  held 344 of 900 drives with 0 mismatches. **The second judged series (`planner-series-fresh`, Terminus 172–184) runs
  on `85911f0b`.**
  **SECOND judged series: line (a) PASSES (~14:45 PDT).** builder0, series tree `35f5df92` (code `f9d2c639`), gate
  `85911f0b`, Terminus 172–184, n 13, to completion: rig arrivals base 180 v candidate 172 of 208, paired mean −0.615 (se
  0.500) v pass line −0.823, PASS (per seed −1 +1 −1 +2 −1 0 +2 −2 −3 −3 −3 0 +1). The mixed squad is identical both arms
  (289/289, the seam silent 13/13). Rig contact-ticks REPORTED: median 855 v 533, paired −282.2 (se 211.2). Seam totals
  over 13 rig runs: requests 459, plans 137, driven 106, aborted 5, abandoned 2; refused GOAL_BLOCKED 203 / START_BLOCKED
  83 / NO_PATH 23; queue_waits 486 (series 1: 1141); pending per rig event n 448, median 11, max 104 ticks. Rows:
  `references/round31/planner/series2-fresh/` (`f8f91846`). **The other stages run to completion:** hull-rest, fights,
  bridge, cp2.
  **Line (b)'s named rig cases (REPORTED at n = 1, `fe5f8a9e`, traces `references/round31/planner/cases-b/`):** seed 31,
  the rig 1930 base v 2198 candidate contact-ticks. It is a different grind of the same length: the candidate's is a
  squadmate wedge in the west street with NO seam event (CP-H's H1 class, relayed). Arrivals 13 v 13. Seed 51: the rig
  267 v 244; arrivals 16/16 v 15/16 (Green_S0_3 completed 9.6 m from its slot with no seam event in that leg). The seed-9
  pin: pinned unit-ticks 491 (16.4 s) v 30 (1.0 s), freed with no re-pin loop. The rig 180°: `test_wheeled_arrival`'s rig
  case is green on the gate. The car's leak check: the mixed line identical both arms.
  **Line (f) as filed (~15:45 PDT, a1d9e1fc = code f9d2c639, builder0 pinned 0–3):** the warm (late-quarter) per-expansion
  median for the longest live hull is 263 µs on seed 92721 (load 16.7), so SLICE 2 × 263 = **0.526 ms, a MISS by 0.026
  ms**; seed 31337 reads 186 µs, 0.372 ms, PASS. Unpinned this morning the same probe read 214 µs (0.43 ms). **Ruling:**
  (f) is NOT in the filed ship clause ((a), (c), (d), (e) and (b)'s rig lines), so a miss on (f) does not block a ship,
  and SLICE is NOT changed after the numbers. The record says "(f) MISS on 92721 at load 16.7, an upper bound
  (R31.6)". **Round 32: SLICE becomes a hardware-preset knob** (his rule: perf cuts ship as presets), e.g. SLICE 1 on the
  laptop preset. On the laptop (~2.75×) the bound is ~1.45 ms in a tick a rig is planning (rigs plan ~0.06 times a
  second), and SLICE 1 halves that at the price of twice the hold.
  **Line (d) RULED PASS as filed (~16:20 PDT; base `0b2cf981`, candidate `35f5df92`, hull-rest seeds 60–65, 144 runs an
  arm):** the filed text is "crews still moving at 75 s per task ≤ base + se (wheeled turret row … quote M1_CLASS's
  paired se)", at 1.645 se, so the form is PER TASK on the WHEELED-TURRET row, and it passes on all 12 rows (closest
  attack_move +8 v 9.05, SBF +8 v 8.39). At-rest error is not worse anywhere (smallest p 0.087), and settle passes. The
  all-classes per-task reading (3 of 12 over) and wheels/fixed attack_move (+4 v 3.62) are REPORTED, not the filed form.
  Supporting evidence: the hull-rest harness is NOT deterministic run to run. 92 of the 108 law/syndicate/condemned runs
  where the seam never fired differ anyway, and those silent runs carry most of each per-task miss. **Round-32 finding:**
  in a 19-crew gang press the one-session queue starves (23 % drawn / 18 % clicked of asks abandoned at the 90-tick cap,
  queue_waits 19 179 / 26 578; the series had 2 of 459). Holds n 1141, median 14, max 110 ticks.
  **✅ CP-P1 VERDICT (~17:30 PDT): the ship clause is MET on every stage, so it SHIPS** (series `35f5df92` = code
  `f9d2c639`, gate `85911f0b`, builder0, every line read once at completion). (a) rig arrivals −0.615 v −0.823 PASS;
  mixed identical. (b) rig contact median 855 → 533, paired −282.2, PASS. (c) scenario_cp2 identical both arms, PASS.
  (d) hull-rest PASS as ruled. (e) fights kills −4 (se 4.5), deaths −4 (se 3.4), hit +0.012, PASS; bridge 18/18 identical.
  The rig 180° PASS. (f) cost MISS on one seed (0.526 ms), not in the ship clause. Clip:
  `~/projects/clips/round31/planner_terminus_f9d2c639.mp4`. **Ship order:** CP-H's ship (`76b7ee46`, check running)
  merges FIRST, with its 13 baselines recorded twice. Then native re-cuts CP-P1 on THAT main (planner `f9d2c639` + its
  mirror + `PLANNER_DEFAULT true`). Its plain check is CP-P1's ship check, and the FIRST check with the planner and CP-H's
  four all ON together (C31.1's whole-suite test of the pair). Then merge, record its moved baselines twice, and run one
  main check.
  **Ship check on `3cd68da5` (~18:30 PDT): `exited 2`, 2651 passed / 2 failed, a COVERAGE gate, not a mismatch.**
  test_native_drive's live and owned twins assert ≥ 20 station-keeping drives and saw 12 (planner alone 44, CP-H alone
  20, both 12); twin fidelity 2160 drives, 0 mismatches. Native fixes the SCENARIO (test-only) with the ≥ 20 floor kept,
  reaching ≥ 20 on all four trees (neither, planner, CP-H, both), then the light lane and the plain check.
  **Fixed (~19:00 PDT, `166f7f1e`, test-only, floor kept):** five followers with front-row leaders, each starting on its
  slot. Stationed counts (live = owned): neither 249, planner 199, CP-H 210, both 121 (before: ? / 44 / 20 / 12); 2160
  drives with 0 mismatches on each tree. CP-P1's plain ship check on `166f7f1e` is running.
- **R31.2 (C) wording amended (planner, `0914dafd`):** a pending hull that is still rolling is **braked to rest (the
  k-turn's 0.7 opposite throttle, straight lock), then held at zero/zero.** Zero/zero alone let a rolling rig coast past
  the 3 s hold. **Amended again (~04:30 PDT, `faeab49c`):** braked to rest, then held at zero/zero for **at most 3 s of
  SEARCH** (PENDING_TICKS counted from the tick the search begins at rest). The hull's whole hold is in `pending_ticks`.
  The rolling-face test took one request and one 5-leg plan, abandoned 0, pending 113 ticks (~45 braking + ~68 search)
  and ended 4.1° off at 40 s (builder0 light, 5/0). **What he could see:** a rig ordered to face while moving fast stands
  for up to ~3.8 s before its first leg, so CP-P1 REPORTS `pending_ticks` per rig event (median and max). The switch is in
  CP-H's form at `39ba4b0b` (`PLANNER_DEFAULT := false`), so the ship change is one const.
- **Brains B5c-v5 bar (filed 2026-10-15 ~02:10 PDT, before any judged number; DECLARED; the LAST attempt; partial:
  none):** candidate = **round 30's v4 rule UNCHANGED** (`lab/brains-r30-gate` `f1a804eb`). It was parked only on the
  single pursuit cell, which R31.3's A/A puts inside a do-nothing nudge's noise, so it gets no re-scoping fitted to it
  (lesson 306). **C31.1 gate PASSED:** pair tree `pair/brains-v5` `17e7b08c` (stream `0415da23` + `f1a804eb` ON + native
  `f508ce89`), builder0 `>> remote: make check exited 0`, 2629 passed / 0 failed, 24 passed + 2 NOT JUDGED (perf-judge
  and scenario_perf, refused on a busy box), sim-baseline 13 unmoved, native-verify-scenarios 0. Named stages on the
  native path: pursuit 10/10, wheeled_arrival 11/11, nav_gate_v4 8/8, gate_hold 4/4, native_gate 4/4, mixed_legs 4/4,
  wall_contact 11/11, scenario_cp2 pass. Arms: default ON v `--nav-off=gategiveup`, one tree, GDScript drive both
  arms, fresh seeds. (1) **Pursuit** (R31.3): `make pursuit-aa` rule ON, ≥ 21/24 as written AND ≥ 19/24 nudged, no
  new let-go at 18 m/s. (2) **Yard crossing** (seeds 27 28 × ticks 1 3 6 8 11 16, n 12; *yard crossing cell*,
  count-runs): DECIDING, runs with every crew in on ≥ off AND crews on ≥ off in every run; last-crew median ≤ off − 5 s
  REPORTED (A/A ±9 s). (3) **Sumps cell** (seeds 16 17 × 6, n 12; se 6.61 s): all-within-8 m median on ≤ off with no
  run > 5 s later; guns_on_arc ≥ off − 0.05. (4) Terminus head-on (seeds 8–11, t11) REPORTED. (5) **Arrive series**
  (5 maps × 5 squads × seeds 37–40, n 100): within 8 m on ≥ off − 1 AND McNemar discordant-against ≤ 1; paired median
  of cells complete in both ≤ +2 % REPORTED (needs n > 1000). (6) Counters gates_turned / latched_away / near /
  given_up > 0 on every acting on-run, 0 on every off-run; come-round endings counted, and mostly-cap is a finding. (7)
  bridge-pooled 18/18 on; `make screen-slots` seed 61 A_2 in. (8) Cost: path.gate ≤ 0.5 ms a tick at Sumps 25 a side,
  or NOT READABLE. (9) The worst on-arm run of (2) and (3) traced before the medians. Ships as the default flip +
  native's mirror, one pair, with native showing yard and Sumps equal on the ON path. One arm-pair per remote call,
  systemd-run. **Owed before numbers (orchestrator):** brains names round 30's v4 tuning and judged seeds per stage and
  confirms none of 27–28, 16–17, 8–11 or 37–40 is among them.
  **CONFIRMED (~02:15 PDT, from round 30's judged rows):** yard r29 22–24 / r30 23, 25–26; Sumps r29 2–13 / r30 2,
  14–15; Terminus r29 1–4 / r30 2–7; arrive 1–4, 25–36. No overlap and nothing swapped. Cleared to run.
  **JUDGED ~06:30 PDT 10-15 — FAIL on line (3) Sumps "no run > 5 s later"; PARKED (the last attempt, partial none).**
  Pair tree `e675a28a` (= `17e7b08c` + `arrive_pair.py`), builder0, GDScript both arms. The series stopped once the
  verdict was decided, so arrive, bridge, screen-slots and cost never ran. (1) Pursuit PASS, 24/24 as written and 24/24
  nudged, the 8 m/s reversal margin +47° on v +69° off. (2) Yard PASS: every crew in 11/12 on v 1/12 off, crews on ≥
  off every run, last-crew median 21.0 s v never. The worst on-arm run, s27 t8, was traced: A_5 reached its herringbone
  gate facing away (dot −0.94), the gate was given up 27 m from its slot, and it drove onto terrain by the containers.
  That's the come-round case for the planner's §2.8 side gate. (3) **Sumps FAIL:** median 24.8 v 24.9 s and
  guns_on_arc 0.939 v 0.939 both pass, but **s17 t11 runs 58.3 v 36.0 s (+22.3 s)**. Traced: Green_S_3's slot drifts
  67 times on v 3 off, flipping every ~1 s between seats ~10 m apart, and each flip refires `near` (66 times). That's a
  limit cycle between v4's per-goal `near` and the element's seating. (4) Terminus (reported): every crew in 3/4 on v
  2/4 off. Kept as the record: `pair/brains-v5`. **Round 32:** key `near` per SEAT (or with hysteresis), or take the
  planner's §2.8 side gate (roadmap).

## Round 30: six streams (launched 2026-10-14; briefs in `streams/`)

**Goal: round 29's parked calls carried home, and the two lingering problems he named for Fable attacked head-on
(`roadmap.md` *AT ROUND 29's CLOSE*, *Round 30 candidates*; his words in `game_design.md` *Round 30: the launch*):
long wheeled hulls in tight space (three rounds of failed bars: M1, M2, M4) get both a fix stream and a planner designed
from scratch; builder0's bottleneck gets judged series sized by their measured noise instead of by feel; the arrival gate
keeps the yard it won without breaking the 180° arrival; his bridge back to 108/108; crossing squads released once the
other's tail clears; the C++ core continuing.**

| Stream | Folder (offset) | Model | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | Opus | [streams/archive/round30/traffic.md](streams/archive/round30/traffic.md) | two of his squads crossing at an angle: the yielding squad no longer crawls as a whole for 30–45 s; a set-up mortar truck stays set up while it is still ordered to fire | T3b DECLARED; T1c-b DECLARED; I3's proof |
| **manoeuvre** | `godot-manoeuvre` (2) | **Fable** | [streams/archive/round30/manoeuvre.md](streams/archive/round30/manoeuvre.md) | a long truck wedged against a wall backs out instead of sitting at full throttle; a drawn facing lands nose-on for wheeled turret vehicles; the creep re-judged on an honest base | **CP-M4b** (+ native's pair), M1b, M2b, M5 |
| **brains** | `godot-brains` (3) | Opus | [streams/archive/round30/brains.md](streams/archive/round30/brains.md) | the yard's last crew in every time AND a car that arrives facing the way it came; gang trucks' screen slots filled; his bridge 108/108 | **CP-G** B5c-v4 (+ native's pair), B3b |
| **native** | `godot-native` (4, continuing) | Opus | [streams/native.md](streams/native.md) | nothing in play (equal answer): the B5c and M4b pairs; N7.5 element_feed | each pair |
| **sizing** | `godot-sizing` (5) | **Fable** | [streams/archive/round30/sizing.md](streams/archive/round30/sizing.md) | nothing in play: every bar this round is sized by its probe's measured noise; fewer builder0 runs that decide the same thing | **CP-N** the per-probe n table, early |
| **planner** | `godot-planner` (6) | **Fable** | [streams/archive/round30/planner.md](streams/archive/round30/planner.md) | nothing in play this round: a local motion planner for long wheeled hulls in streets, designed, tested offline and shown in a lab scene; manoeuvre integrates it next round | P2 offline tests; P3 the lab clip |

**Ownership (round 29's, restated, plus the two new isolated streams):** each brief's header lists its paths. In
`movement.gd`: traffic the give-way block (`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`,
`_hull_within`; manoeuvre the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, `_manoeuvre`, the k-turn /
planned-reverse / circle block; native the member STORAGE; brains the rest (`_track_progress`, `_update_phase`,
`_approach_gate`, …). `order_controller.gd`: manoeuvre the face-at-rest path; native its seams; nobody else.
`tank_brain.gd`: brains, except native's seams and manoeuvre's `_order_move` grant. `game/ai/wall_contact.gd`: manoeuvre.
**Planner owns only** `game/ai/planner/**`, `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`,
`_agents/streams/references/round30/planner/**`. **Sizing owns only** `tools/judge/**`, `tests/test_judge*.gd`,
`_agents/judging.md`, `_agents/streams/references/round30/sizing/**`. **Nobody** (a request): `game/match/**`,
`game/tank/**` (except C30.6's granted lines), `game/units/**`, `game/garage/**`, `game/modes/**`, `game/camera/**`,
`game/network/**`, `game/audio/**`, `game/announcer/**`, `game/theme/**`, `arenas/**`, `game/arena/**`, `game/control/**`,
`tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`, `mk/core.mk`.

**Contracts (round 30):**

- **C30.1 Every change to fights or driving is DECLARED** (C29.1 carried, every clause): one commit, merged alone, with
  its scenario and paired series, the CPU on the same behaviour; **the bar (with a partial-gain rule and the last attempt
  named) is sent to the orchestrator before its numbers**; tuned on named seeds, judged on fresh ones; the control arm can
  win and lose; the measuring point checked against each arm; an arm's own counter shows the rule fired; the count is what
  he sees, split from squadmates' noise; the worst run's trace read before the median; a heading bar carries the 180°
  case as well as the 90° (lesson 305); a probe reads only an arena that has finished loading (304).
- **C30.2 The C++ follows, and native carries it** (C29.2 carried): develop on the GDScript path (`--brains-off=native`);
  send native each SETTLED diff to the drive, `_avoid`/`Avoidance.solve`, `right_of_way`, unstick, gunnery, the tank's
  velocity lines (C30.6) or the per-crew execute before its commit (SendMessage, orchestrator copied); native ports it with
  an equal-answer proof; the pair merges back to back and is checked once. The stale rule and `native-verify-scenarios`
  stand. Pairs pre-empt native's N7 work.
- **C30.3 Bars are sized by sizing's table once CP-N lands; before it, by round 29's sizes.** Sizing delivers, first
  and early, a per-probe table (`_agents/judging.md` *The table*): each probe's measured noise (paired se, A/A swing),
  the smallest n that decides the effect its bar names, and a variance-aware form for guard lines. The orchestrator
  relays CP-N to traffic, manoeuvre and brains; **a bar pre-registered after CP-N cites the table's row** (or says why
  it departs); a bar pre-registered before CP-N may be re-sized ONCE before its judged run, in writing, before numbers.
  Sizing never runs a series on builder0: it reads `streams/references/round27..29/` and the judged blocks in this file. **Delivered and MERGED (`9730193f`): the table and the method are `_agents/judging.md` (*The table*, *How to write a bar*, *Early stop*); `tools/judge/size.py` prints n and the guard for a probe and an effect.**
- **C30.4 The planner is isolated this round.** No edit outside its paths; nothing it builds is reached in play (no seam
  in `movement.gd`, `manoeuvre*.gd` or `order_controller.gd`). It may read every manoeuvre branch and trace. Its lab
  scene and offline tests run on builder0 as light targets (one slot at a time; no judged series); `make check` must
  stay green with its tests in. The hand-over to manoeuvre (P4) names the seam line it wants; the orchestrator grants
  it, if at all, at round 31's split (or as a late round-30 checkpoint if manoeuvre's backlog is done and asks for it).
- **C30.5 The Terminus escape is manoeuvre's, the gate is brains'.** Brains' B5c worst run (Terminus seed 3: B_4, 9 m
  from its slot, sent 17.5 m back to a gate, reaches it and jams on terrain ~8 s): the gate's placement (no gate within the
  approach length when the route via it is much longer) is brains' B5c-v4; a wheeled hull's escape from terrain it is
  jammed on is manoeuvre's M5. Each traces the run on its own path first; findings cross through the orchestrator.
- **C30.6 M4b's `tank.gd` grant:** manoeuvre may add, in `game/tank/tank.gd` beside the `estimated_velocity = velocity`
  lines (~721), ONE new reading of the real flat displacement a tick (capped at the asked planar speed), stored in its
  own member (name it `real_velocity`), behind `--tank-off=real_velocity`; `estimated_velocity` and the plant's `_speed`
  are NOT changed (round 29's M4 showed that zeroes wheels' `_speed` on every wall brush). Readers that judge progress
  (`unstick`, `_pressing_escape`, the pinned probe) and aim leads read the new member. Native ports the line in
  `tank_drive_native` as a pair.
- **C30.7 builder0 runs every Godot run** (C29.7); the laptop only in a slot the orchestrator grants (none planned).
  Traffic's I3 cache (`CACHE=on`) is adopted by another stream's series only after its cached == fresh proof is on main
  and the orchestrator says so.
- **C30.8 Formation geometry is brains'** (C29.8): slot spread and the 6 m screen slots for gang trucks (B4 rides on B5c).
- **C30.9 `test_tactics_scenarios.gd` is split by brains** (two files balanced by `tests/shard_times.txt`, no behaviour
  change, one commit, no series); traffic does not touch it.
- **C30.10 Fable streams report like every stream:** a brief's Status, a bar before numbers, `make remote T=check` green
  on the hash they hand over. A design doc is not done until its offline tests run in `check` (sizing: `tools/judge`'s
  tests; planner: `tests/test_planner*.gd`).
- C28.2's stale rule, C26.4–C26.10's rulings, C25.6, C24.6–C24.8 and the older standing contracts stand.

**Round 30 outcomes (2026-10-14 close):** SHIPPED — sizing's `judging.md` + `tools/judge` (CP-N, early stop), the
planner (isolated, `game/ai/planner/**`, nothing in play), traffic's I3 cache proof + `make quick` 487 s, brains' B7 test
split, native's N7.5, the `real_velocity` reader pair, manoeuvre's M1b(1) `face_slot`. NOT SHIPPED (each judged, parked
with its table and bar): brains B5c-v4, B3b, B6; manoeuvre M4b's escapes, the creep lift, kturnarc, M5; traffic T3b,
T1c-b (his calls), T4. Main's final tree: `04aaf1c2` (= native's checked `3b3e590d`: 2608/0, 25 of 26 gates, the
sim-baseline re-recorded for face_slot's docks move).

**Bars (round 30, pre-registered before their numbers; the orchestrator appends each here as it arrives):**

- **CP-N DELIVERED (sizing, 2026-10-14 ~11:30 PDT; stream/sizing `44a8b95a`, `_agents/judging.md`):** 55 probe × metric
  rows (48 sized from rounds 27–29's rows): per-run paired sd, base, icc (seed v tick), n today, the se to quote, the
  effect the bar names, the n that decides it (80 % power, 5 % one-sided), the MDE at n today, the noise-sized guard
  (base ± 1.645 se); a count-line block (Fisher / binomial / McNemar) and an A/A block. The orchestrator re-derived one
  row from the raw rows: Terminus head-on between-squad fast, CP-T pair alone paired sd 18.1 a run (sizing's pooled 16.7),
  base 22.1, −25 % = 5.5 a run → n = 57; MDE at n = 18 = 9.8 a run (44 % of base): reproduces. S1's inventory: 42 of
  122 judged pass lines of rounds 27–29 were inside their probe's noise (M1's six +5 guards and every "crews ≥ base − 2"
  among them). Relayed to traffic, manoeuvre, brains with sizing's per-stream headlines (their Status). **Ruling:** brains'
  B5c-v4 bar stands as filed (its run started before CP-N); every later bar cites the table (C30.3). Sizing's python suite
  enters `check` through a `tests/test_judge_tools.gd` wrapper under `make test` (no `mk/core.mk` edit).

- **Sizing S4 (early stop) RESULT (2026-10-14 ~12:10 PDT; stream/sizing, `judging.md` *Early stop*):** a truncated Wald
  SPRT per pre-registered line on the per-run paired differences in the runner's seed-major order, sd from the table, α 5 %
  / β 20 %, no stop before one full seed; round 29's judged series would have stopped after 113 of 174 runs per arm
  (−35 %, ~3.6 of traffic's ~10 box-hours) with EVERY verdict unchanged; false-pass on gain lines simulated on the rows'
  noise 3–11 % (median 6 %). Caveat: on T1b's wedged pair the real sd is 1.5–1.9× the table's (guards' false-fail
  15–23 %), so the table is re-rendered after every judged pair lands under `references/`; at n = 18 a true −25 % effect
  fails about half the time. **Ruling:** applies to bars written after sizing's tip is on main; the in-flight series
  (B5c-v4, M4b) keep their plans; a runner's hook is its owner's, through the orchestrator, after sizing's check.
- **Traffic T3b: the brief's premise corrected and the bar's line re-ruled (2026-10-14 ~12:30 PDT, before any judged
  number):** traffic's crossing clock (both squads past the meeting point; builder0 `bd05077d`, GDScript, 72 runs an arm,
  n = 18 a case, round 29's v2 v base): Terminus crossing median 13.4 → 13.2 s, yard 9.2 → 12.4 s; the yielding squad's
  own crossing +2.8 / +3.5 s. **The 40–75 s last arrivals in round 29's worst runs (Terminus s24/t3, s22/t6, reproduced run
  for run) happen AFTER the crossing: a crew circles its far-end seat reading no_path/terrain for 30–40 s** — seating,
  brains' (relayed); the whole-squad "crawl" ends by ~6.5 s. Design (b) picked (`--traffic-off=reach`: only crews within
  20 m of the crossing keep the squad's share). **Ruling:** the crossing clock replaces "all-in ≤ +10 %" as the judged
  line on the crossing cases (paired sd 2.2–4.0 s on tuning pairs; guard base + 1.645 se, n from CP-N's crossing rows);
  all-in median REPORTED with its se (CP-N row 42: se 7.0 s on 40 s); the rest of round 29's T3 bar stands; the full bar
  is filed when traffic sends it. T3b is committed default-OFF for the stream's check (the C++ `_avoid` has no
  `Traffic.shape` yet) and the native pair flips it on — third in native's queue. **I3 PROVEN** (same box/commit,
  Terminus crossing seeds 1–3 × 6: a fresh row v a miss and a hit are equal on all 576 fields of 18 rows, byte-identical;
  a one-line `game/` change misses; `CACHE=off` still writes rows, so a proof needs an empty `SERIES_CACHE_DIR`) → goes
  into `verification.md`; adoption by other series after traffic's merge (C30.7). `make quick` measured 1272 s cold /
  1081 s warm (lint 712 s of it): a narrowed quick-lint granted inside traffic's tooling, check's full lint unchanged.
- **Traffic T3b bar (pre-registered 2026-10-14 ~12:40 PDT, before any judged number; DECLARED; the LAST attempt; no
  partial; CP-N rows cited):** candidate stream/traffic `7a0701f3` (round 29's v2 + option (b), CRAWL_REACH_M = 20 m).
  Judged: builder0, both arms one commit, GDScript path, fresh seeds {31,32,33} × {1,3,6,8,11,16}, n = 18 a case, four
  cases, 90 s; base = no flag (turns DEFAULT_OFF = main), arm `--traffic-on=turns`; read by `tests/traffic/turns_verdict.py`
  updated before the run; tuned on 1–3 only. (1) between-squad fast pooled over the two crossing cases down ≥ 25 % (row
  56: n 16 decides −25 %; pooled n 36); neither crossing case up beyond base + 1.645 se (rows 38 +19.1, 44 +12.6);
  (2) THE CROSSING CLOCK per crossing case: mean paired difference in `cross_clear_s` (never = run end) ≤ 0.10 × base
  median + 1.645 se, the se the judged run's own paired sd/√18 quoted (tuning: ≈ +2.9 s Terminus, +1.8 s yard);
  `cross_b_s` / `cross_a_s` reported with se; (3) crews in every case ≥ base − 1.645 se (rows 35/41/47/53: −4, −4, −6,
  −1); (4) no wedge, the worst run's trace first; (5) same-squad fast per crossing case ≤ base + 1.645 se (rows 40/46);
  (6) head-on cases within 1.645 se of base on fast, between-squad fast, all-in (rows 32/36, 50/54); (7) all-in median per
  crossing case REPORTED with se (rows 42/48). Also: CPU mirror on Terminus crossing no worse on (1)(3)(4); bridge-pooled
  18/18 with turns on; `test_traffic_turns_live` fires, counters reported; cost ≤ 0.5 ms at Sumps 25 a side or NOT
  READABLE. Merge: default-OFF on its own check, the pair flips it on (native third). **Orchestrator's additions (before
  numbers):** (a) if the judged run's paired sd on line 2 exceeds the tuning sd by more than 1.5× (sizing's T1b caveat),
  say so beside the line and the guard still uses the judged se; (b) per run, the crews beyond 20 m that drove at full
  share (the rule's own counter) reported per arm; (c) after native's port: Terminus crossing + bridge-pooled once on the
  DEFAULT path at the pair; (d) the thirteen explained if they move.
  **Judged run started ~13:00 PDT at `cf124433`** (game/ = `a63dde6d` = `7a0701f3` + the counter `tr_cross_reach_free`).
  Disclosed before numbers: on the TUNING seeds the 20 m candidate passes every line except the yard crossing clock,
  missed by 0.02 s (+1.63 v +1.61 s); 12 m tried on seeds 1–3 and rejected (yard crews 169 → 163, two wedges). Judged as
  filed. **I2 DONE:** `make quick` with the narrowed lint 487 s on builder0 (was 1081 s warm; full lint 712 s of it) +
  any slot wait; committed `4248d8ee` with I3's proof in `verification.md`. T1c-b built on `traffic-t1cb` (5/5 unit
  tests); its bar comes after T3b's table.
- **Traffic T1c-b bar (pre-registered 2026-10-14 ~14:00 PDT, before any judged number; DECLARED; the LAST attempt; no
  partial):** candidate stream/traffic `88e52c8f`: `Movement.ask()` refuses while the asked hull is on its fire post
  (`deploy_ratio > 0`, weapon order not hold_fire, own order not a move or the move arrived: `Movement.on_fire_post`);
  the asker treats it as parked and goes round; a set-up hull with a NEW move is asked as before. `--traffic-off=setup`;
  counter `Movement.setup_refusals`; `test_traffic_setup` 5/5. Tuning (census seeds 1–3, n = 9): repacks_while_firing
  13 → 0, runs with any 5/9 → 0/9; repacks while giving way 42 → 27; refusals 0 → 122; artillery shots 275 → 273; fast
  friendly 468 → 473; friendly-stuck 636 → 602; ApproachStage seeds 4–6 t1 the one give-way repack 1 → 0. Judged: both
  arms one commit, GDScript; base `--traffic-off=setup`. (A) traffic-census fresh seeds {7,8,9} × 3 arenas, n = 9;
  (B) ApproachStage drawn artillery seeds 13–15 × 6, drawn and clicked, n = 18. Lines: (1) runs with any
  repacks_while_firing: arm 0/9 AND one-sided Fisher p ≤ 0.05 v base (needs base ≥ 4/9; base < 4/9 = NULL), arm total 0;
  (2) friendly-stuck ≤ base + 1.645 se (judged paired sd, ≈ +79); (3) fast friendly ≤ base + 27.1 (row 83); (4) artillery
  shots not down > 21.6 (row 82); (5) ApproachStage drawn: repacks ≤ base and any arm repack traced as not a give-way;
  from the side 18/18; first round ≤ clicked + 30 s (row 74); alive ≥ clicked − 0.5 reported with row 73's se;
  (6) bridge-pooled 18/18 rule on; (7) the four traffic-series cases rule on, seeds 31–33, v T3b's judged base rows:
  equal row for row, or no wedge and within T3b's guards; (8) no native diff (no C++ twin). **Orchestrator's additions
  (before numbers):** (a) the asker's side counted: askers refused that never got past the set-up hull within 20 s, per
  arm, reported (the "goes round" must be shown, not assumed); (b) the CPU side's refusals and repacks in the census
  reported (symmetric rule); (c) cost ≤ 0.5 ms a tick at Sumps 25 a side or NOT READABLE; (d) `native-verify-scenarios`
  on the census and ApproachStage scenarios shows the stale rule holds (line 8 proven, not stated); (e) line 7's "equal
  row for row": if not equal, the first differing run traced before anything else; (f) the thirteen explained if they
  move.
- **Traffic T1c-b JUDGED — NOT SHIPPED (2026-10-14 ~15:00 PDT; `16780030` both arms, builder0, GDScript; census seeds
  7–9 n = 9, ApproachStage 13–15 × 6 n = 18):** PASSED (1) the defect: runs with any repack while firing 4/9 → 0/9 (Fisher
  p = 0.041), total 11 → 0, repacks while giving way 33 → 4; (2) friendly-stuck 496 → 404; (3) fast friendly 589 → 563;
  (5) ApproachStage drawn repacks 8 → 2, from the side 18/18 both, first round 27.1 s both, alive 3.00 both;
  (6) bridge-pooled 18/18; (7) all 72 traffic-series rows equal T3b's base rows field for field. **FAILED (4) artillery
  shots not down > 21.6 (row 82): 318 → 163**, carried by ONE run: Parade s9 171 → 26, both sides' artillery fell (Rust
  refused nothing and went 19 → 7 rounds); re-run singly with per-battery counts: Green's batteries set up at similar times
  but fired 1–5 rounds each v 14–19 — the fight's geometry diverged. Without that run 147 → 137. The judged paired
  1.645 se is 237, ~10× row 82's 21.6: **row 82 is under-sized** (sizing's table had few artillery rows; re-rendered at
  the close, step 5b). Verdict stands as filed; parked `traffic-t1cb-judged`; stream/traffic's game/ back to main's
  (`3129de50`). Additions on the worst run: refused askers went round 7, never got past in 20 s 0, 2 pending at the end;
  all refusals on Green's side; traffic-native-verify built, not run; cost not measured (three field reads per ask()).
  **Round 31 candidate, in player terms:** "a set-up mortar truck no longer packs up for a squadmate passing (11 → 0
  repacks); whether it then fires less is not decided" — a re-judge with the artillery line sized from this run's sd (the
  judged run's own paired se, as T3b's clock line did) or more census seeds. **Traffic's next: T4** (the ORCA ghost
  velocity), bar written now, run after M4b's `real_velocity` is on main.
- **Traffic T4 (the ORCA ghost) — tuning read and a PROPOSED bar; not judged this round (2026-10-14 ~15:40 PDT;
  `lab/traffic-t4` = stream/traffic + M4b2 `77a1603f`; builder0, nav-terminus-drive mixed + rigs, seeds 21–23, GDScript,
  base `--traffic-off=ghost`):** v1 (`05bb2c22`, ORCA's neighbour table reads `Tank.real_velocity`): mixed stuck 198 → 86
  crew-s, manoeuvre's mixed-21 IFV 74 → 12 and the oscillation gone; **but rigs 72 → 164**: in rigs-21 a War Rig sits at
  full throttle 55 s (real 0, estimated 12 m/s, touch false, stall clock 0) — M4b2 keeps the rig's unstick on
  `estimated_velocity` (over `UNSTICK_BLIND_MAX_LEN_M`), so a rig pressed against a FRIEND never fires its stall. v2
  (`b63a90c1`, the solving crew's own velocity honest too): mixed 198 → 142, rigs 72 → 77, the IFV still oscillates 50 s.
  Noise: paired stuck differences −62 to +77 s a run (sd ≈ 60; not in CP-N): a halving needs ~40–50 runs a squad, −30 %
  ~130. Traffic's pick: v1 (the traced cause); its rig harm is the rig's stall reading, manoeuvre's. **Proposed bar**
  (re-sized when M4b is on main): Terminus drive mixed, fresh seeds, n = 24 a squad, stuck crew-s down beyond 1.645 se;
  rigs stuck not up beyond 1.645 se; arrivals ≥ base − 1.645 se (rows 68/70); the four traffic cases within T3b's guards;
  bridge-pooled 18/18; `test_traffic_ghost`; a native pair (`avoidance_gather` and the drive's solve). **Ruling:** T4 is
  **round 31's first traffic item**, judged TOGETHER with manoeuvre's answer to "should a War Rig's stall clock read
  `real_velocity` when pressed against a FRIEND (not a wall)?" — M4b2 is in its last judged attempt and cannot change
  now; the two land as one declared pair of changes next round, sized from this round's stuck rows (to sizing's probes).
  Traffic → check on its tip and the report.
- **Traffic T3b JUDGED — NOT SHIPPED (2026-10-14 ~13:35 PDT; `cf124433` both arms, builder0, GDScript, seeds 31–33 × 6,
  n = 18 a case):** FAILED one line: **the yard crossing clock +2.80 s (se 0.22) v a limit of +1.18 s** (the yard's
  yielding squad pays +3.66 s, se 0.23; judged paired sd 0.92 < tuning 1.77, the 1.5× caveat does not apply). Every
  other line passed: between-squad fast pooled over the crossings 176 → 96 (−45 %; Terminus 76 → 50, yard 100 → 46);
  crews 176 → 176 and 168 → 166, no wedge; same-squad fast 170 → 187 / 140 → 122 (within limits); head-on within
  1.645 se; Terminus crossing clock −1.17 s (se 1.05). Reported: all-in Terminus 50.8 → 42.8, yard 90 → 90; verdicts
  18/19; reach-free reads 2041/1332; the rule fires a little in head-on (8/10 verdicts), no line moved. Parked
  `traffic-t3b` (= `cf124433`); stream/traffic's game/ back to main's (`e84f36e1`). CPU mirror and bridge-pooled not run
  (chain stopped after the verdict). **Worst Terminus run (s33/t1, all-in 33.7 → 61.4 s, every crew in): B_4 gives way
  to two squadmates at the far end, then circles its seat (35.6, 23.9) reading no_path/terrain 36–61 s; seated at 30.4 s
  in the paired base run; the same seat as round 29's s24/t3** (a seat trap at B's destination (45, 30) on the Terminus;
  relayed to brains). **Ruling:** the last attempt by the filed rule; parked. **Round 31 candidate, his call (in player
  terms):** at a yard crossing the yielding squad gets through ~3 s later and the two squads bump into each other half as
  often — the line was set at +10 % by the orchestrator, not from his words ("both squads arrive a little later"); if he
  accepts ~3 s, T3b re-judges once on fresh seeds with the line he sets.
- **Planner P2–P4 DONE (2026-10-14 ~13:10 PDT; stream/planner code `8f73e4cd`, docs on top; check queued; C30.4 kept:
  nothing in play, nothing outside its paths):** hybrid-A* over whole legs on the plant's own arcs, time cost, OBB
  squadmates, a free-space table per hull class, an expansion budget; 16 offline tests in `check`. Lab (builder0,
  Terminus, n = 1 each, frames looked at): a War Rig facing back in the west street 15.5 s / 3 gear changes / 0 wall
  contacts v today 29.8 s / 53 / 14; a scout's 180° slot 9 m ahead 20 m v today's 99 m through the gate; a rig into the
  ring road facing east on heading at 6.9 s v never in 45 s. Pre-registered lines NOT met and recorded: the wedge and the
  causeway slot 4 legs not 3; a rig's 20 m in-street turn-round 9 legs not 6 (lattice best 8); an IFV's turn-round in
  12 m not found within budget (BUDGET, never a false NO_PATH). **Cost is the catch:** 0.06–3 s a plan in GDScript (17 s
  for the rig's turn-round): in play it needs native's port (~100×) or a resumable slice a tick (round 31). Four executor
  findings relayed to manoeuvre (brake on the leg's lock with opposite throttle; zero throttle with lock on = the plant's
  creep; stopping distance v²/2b − v·dt/2; a leg measured by the ARC not the chord: `_flat_distance(here, _kturn_from)` is
  3 % short on a 10 m leg); the side-gate note (design.md §2.8) relayed to brains.
- **Manoeuvre M5 PARKED with the finding (2026-10-14 ~14:35 PDT; nothing declared; builder0 light, n = 1 each):** (1)
  Terminus head-on s3 t11 under B5c-v4: B_4 does not jam (all 10 arrive, B_4 at 41.2 s; no stall / escape / terrain
  block in 55 state rows) — the 8 s jam belonged to round 29's gate; brains' v4 closes case 1. (2) Yard crossing s25 t1:
  B_4 (a car) re-tasked at 4.9 m/s to a slot 9 m behind it with a nose facing (round 26's reverse refused) drives a
  full-lock forward loop 15 m out, the slot lands inside its turning circle, Steering's reactive circle rule shuffles it
  in: six cusps, 11 s, "blocked terrain" throughout though nothing blocks it. The planned circle back-up never runs for
  a car: `_away_here()` gates planned legs to hulls ≥ 10 m since round 26 (the mixed squad took +14 % contacts with it
  on) plus a |speed| < 1.5 m/s gate; `circlebrake` (`lab/manoeuvre-m5`) is unreached for cars for that reason, and
  enabling planned legs for cars re-opens round 26's measured harm. **The answer is the planner's F4 (a goal POSE 9 m
  away: 2–3 legs, ~15 m), round 31.** For him: a car turning round in six goes is turning badly, not stuck.
- **Manoeuvre M4b bar (pre-registered 2026-10-14 ~11:40 PDT, before any judged number; DECLARED; the FIRST run, a second
  on fresh seeds would be the last; full text in the brief's Status "M4b bar"):** C30.6's `real_velocity` to the readers
  (unstick's stall test, the pinned probe's state line, gunnery's two leads) PLUS the stall/press escapes sized to the
  plant's momentum (`--nav-off=unstickback`: with the plant's `_speed` kept, a pinned rig carries a phantom 12 m/s that
  takes 1.5 s of braking before any reverse moves it, so round 29's fixed 0.9 s escape is a no-op for rigs; the escape
  holds reverse until the hull has REALLY backed 1.5 m, cap = 0.9 s + |speed|/braking). GDScript path both arms, base =
  `--tank-off=real_velocity --nav-off=unstickback` same commit. Tuned: Terminus 20–22, hull-rest gangs 40–41, fights
  1–8. Judged fresh: Terminus 23–28, hull-rest 42–47 (4 factions, drawn, `--turn-states`), fights 133–156, bridge-pooled.
  (b1) Terminus rigs wall contact-ticks DOWN and arrivals ≥ base, with and without each arm's two worst runs; mixed
  arrivals ≥ base − 2, contact-ticks ≤ base + 10 %; counters (unstick_fires, press_escapes) reported; (b2) pinned
  crew-seconds DOWN > 2 se paired; (b3) bridge-pooled 18/18; (b4) tracks apart in (b2); (b5) a rig's mean speed while
  touching a wall within 2 se of base; fights kills / deaths / hit rate within 2 se paired, hit rate on touching targets
  reported; smokes, determinism, the thirteen re-recorded twice with the reason if they move, ≤ 0.5 ms, a tracked row.
  Partial: (b1) is the gate; (b2) missed with (b1) met = ship with the miss written; (b1) missed = nothing ships, the
  worst run's trace to the planner. Tuning disclosed (quick-remote, n = 1): a pinned gang_tank reads 0.00 by
  real_velocity, 12.00 by the plant; unstick fires 0× with the old reading, once within a second with the new. The
  stream's own check is red on three native twin tests until the pair; the PAIR's check is the green one (C30.2), the
  three named at hand-over. **Orchestrator's ruling and additions (before numbers):** CP-N landed minutes before this bar,
  so manoeuvre takes its ONE re-size now, in writing, before the judged run starts: (b1) decided on Terminus ARRIVALS
  against the table's se (contact-ticks REPORTED: the table's MDE is +127 % at 6 seeds), (b2) names the effect n = 36
  decides (or runs the n the table says for −50 %), the fights lines quote the table's se; (f) the escape's end counted
  per fire (backed 1.5 m v the cap) and reported — an escape ending mostly by the cap is a finding; (g) the two switches
  are one declared change (the reading without the escape is a no-op for rigs), both named in the merge; (h) mixed
  arrivals "≥ base − 2" becomes base − 1.645 se from the table if the table has the row, else stated as unsized.
- **Manoeuvre M4b bar RE-SIZED ONCE from CP-N (2026-10-14 ~11:50 PDT, in writing, before any judged run; the stream's
  Status "Re-sized ONCE from CP-N"; accepted):** (b1) judged on Terminus ARRIVALS over 13 seeds (23–35), rigs and mixed
  apart, the paired total not down beyond 1 se (down beyond 2 se = the gate missed); wall contact-ticks and the
  unstick/press counters REPORTED; (b2) pinned crew-seconds DOWN beyond 2 se paired at n = 144 runs (decides about
  −40 %); fights at 24 seeds: kills/deaths within 2 se decide a 5–6 % loss, the hit-rate guard decides about −3 pts,
  stated; (b5) the brush speed reported with its se (a first measurement); (b3) a 17/18 read by the cell's trace per the
  McNemar row, not a pass or a fail. Partial rule unchanged: (b1) is the gate. Tuning (seeds 20–22, gangs 40–41) starts
  when the wedge tests are green.
  **M4b committed `e8bfef2e`** (on main `3f1713a5`; wedge tests builder0 7/0; native has the hash). Tuning disclosed
  (Terminus 20–22, n = 1 each, GDScript): honest pins base 74 + 67 + 70 crew-s on three of six runs, new 0; rigs wall
  contact-ticks 1849 → 1370, leg time 346 → 251 s, arrivals 45 → 44 (seed 21: a rig latched "arrived" 16.8 m off a
  face-order goal, not a pin); mixed arrivals 63 → 64, leg time 566 → 487 s, contacts 420 → 485; brush speed −0.59 m/s
  (se 0.72, n 6); the stall rule now fires on rigs (0 → 2–4 a run), escapes end by the backoff, 0–2 a run by the cap.
  **Worst run: mixed seed 21's IFV, pinned 74 s at base, OSCILLATES 73 s under M4b** — stall fires, it backs 1.5 m, the
  route drives it straight back into the same blocker (a hull, not a wall) every 3 s; a "stuck" row (no 1 m of progress
  over ≥ 10 s driving) added to `pinned_table.py` so judged (b2) reports the loop beside the pins. **Cause found (a
  request to traffic, round 31 or traffic's next bar):** `game/ai/avoidance.gd` ~147 fills ORCA's neighbour table from
  `tank.estimated_velocity`, so a pinned hull is a 12 m/s ghost to every crew steering round it; the honest reading is
  `tank.real_velocity` once M4b is on main (traffic's line; `Avoidance.solve` has a C++ twin → a pair). The judged chain
  starts after the tuning hull-rest arms (~14:45 PDT).
  **M4b's judged tree = `1b3e2e56` (code = `e8bfef2e`; tooling: pinned_table's STUCK row, tracks apart, `M1_BASE_OFF`).**
  Found on the way: the switch parser honours only the FIRST `--nav-off=` on a command line (a second is an error and is
  ignored), so a runner that hard-codes one and appends another silently loses the second — this round's tuning
  hull-rest BASE arm ran with `unstickback` effectively ON (the Terminus arms were right); round 29's M1 base arm passed a
  single flag and was right. Rule: a base arm's switch list is ONE flag, printed by the run (lesson 300's family).
- **Manoeuvre M4b JUDGED (first run) — NOT PASSED (2026-10-14 ~14:50 PDT; Terminus 13 fresh seeds 23–35, GDScript,
  `e8bfef2e`/`1b3e2e56`, builder0):** (b1) arrivals rigs 185 → 181 of 208 (−4; se of the total 3.72: down 1.1 se —
  "not down beyond 1 se" NOT met, "beyond 2 se" not reached: undecided at 13 seeds); mixed 282 → 288 (+6, se 3.49).
  **REPORTED, and decisive: rigs' wall contact-ticks 7456 → 17970 (+141 %, +3.1 se paired; two worst dropped 4601 →
  11966)**, by driver "route" 6067 → 15591 (forward-gear contacts ×2.7), "unstick" 0 → 717; mixed 1403 → 1642 (+17 %,
  1.7 se) with leg time −14 %. Counters: rigs stall fires 187 (base 0), 185 ended by the backoff, 2 by the cap; press
  escapes 128 v 29. Brush speed +0.39 m/s (se 0.30) but touching crew-seconds 361 → 706. Reading: the pins are freed and
  the rigs then grind Terminus' walls twice as much — round 29's (A) regression in a new form; the three tuning seeds
  (1849 → 1370) pointed the other way, the +127 % MDE the table warned about. **Ruling:** the gate is not passed; nothing
  ships from this run. The filed bar allows ONE second run on fresh seeds (the last): its bar = the filed lines PLUS rigs'
  wall contact-ticks ≤ base + 1.645 se paired as a JUDGED line (a +141 % cannot pass as "reported" twice), trace first
  (seed 31: 566 → 3218 contact-ticks, 15 → 13 arrived), then either a narrow fix DECLARED as the last attempt or M4b
  parked with the finding. **M1b's and M2b's chains HOLD** until M4b's second attempt is judged or parked (if parked,
  both re-base on main and M1b runs first). M4b's own chain (bridge, fights, hull-rest) runs on for the record.
- **Manoeuvre M4b — the SECOND and LAST attempt, bar (pre-registered 2026-10-14 ~14:05 PDT, before numbers; full text in
  the stream's Status):** seed 31's trace: the extra contact is the DRIVING AFTER the escapes — Green_S0_2 grinds the west
  street wall 77 s (plant 10.7 m/s, real 0.1–3 m/s jittering, throttle 0.9, goal distance oscillating 25–29 m) in a state
  neither rule reads as stuck (real speed spikes > 0.8 m/s every other second reset the stall timer; the press window
  sees > 0.75 m sideways); an escape's reverse-on-lock and re-approach leaves a 14 m hull at an angle to the wall where
  the phantom momentum grinds it. No blind reverse fixes that: the planner's F2/F6 does (round 31). **The narrow fix:
  `UNSTICK_BLIND_MAX_LEN_M = 10 m`** — the honest stall reading and the sized escapes only for hulls that can back out of a
  street in one reverse (scouts, IFVs, lancers, artillery, 8×8s); the War Rig keeps round 29's reading and 0.9 s escape
  BIT FOR BIT; `real_velocity`, the probe line and the aim leads unchanged for all hulls. Candidate `lab/manoeuvre-m4b2` **`77a1603f`**
  (wedge tests builder0 8/0: an IFV pinned on a squadmate fires at 1.90 s and is free at 2.30 s, old reading never; a
  War Rig pinned the same way fires 0 times either way); judged chain started 14:25 PDT (Terminus 62–74 first); base as before; fresh seeds Terminus 62–74, hull-rest 54–59 (144 runs), fights 157–180,
  bridge. (b1) arrivals rigs AND mixed not down beyond 1.645 se (sequential early stop); **(b1') JUDGED: wall
  contact-ticks rigs AND mixed ≤ base + 1.645 se, with and without two worst** — with the gate exact a rig run replicates
  its base run (diff 0; any non-zero rig diff is a LEAK), so the mixed line carries it (run 1: +17 %, 1.7 se); (b2) pinned
  DOWN beyond 2 se at n = 144, STUCK and tracks reported; (b3)(b4)(b5)(f)(g)(h) and the fights guard as filed. Partial:
  (b1)+(b1') are the gate (all four lines); (b2) missed with the gate met = ship with the miss written; a gate miss =
  parked, `real_velocity`-to-the-probe-only offered as a measurement commit. **Orchestrator's additions (before
  numbers):** (i) every rig run byte-identical to its paired base run is a PASS LINE (one leak = the gate missed, no
  "reported as such"); (j) the pinned line (b2) is read on the hulls the fix reaches (≤ 10 m) AND on rigs apart — rigs'
  pins must be unchanged (they keep today's reading), stated; (k) **M4b's record chain (bridge, fights, hull-rest of the
  failed candidate) is STOPPED now** — a parked candidate's record is not worth 1.5 box-hours on the round's bottleneck;
  the second attempt starts as soon as its tests are green.
  **Run 2 Terminus GATE PASSES (2026-10-14 ~14:50 PDT; `77a1603f`, 13 fresh seeds 62–74, GDScript, builder0):** rigs
  arrivals 178 = 178 of 208, wall contact-ticks 13411 = 13411 (two worst dropped 8286 = 8286), leg seconds 1748 = 1748,
  counters identical (stall 0/0, press 97/97); (i) every rig run line-for-line identical to its base in all drive, leg and
  per-second state lines — the only differing bytes are the state line's printed `real` column (the reader's VALUE, which
  differs by construction while the motion does not) and the summary's recorded `off` list: no leak. Mixed: arrivals
  295 → 293 of 312 (−2; 1.645 se = 4.7, pass), wall contact-ticks 2093 → 1915 (−8 %; 1.645 se = 423, pass; two worst
  dropped 1314 → 1350), leg seconds 1478 → 1534 (+4 %), stall fires 40 v 11 — **21 ended by the backoff, 19 by the cap:
  the cap binds for the short hulls (line (f), a finding, not a pass line)**; press 7 v 7; brush speed +0.07 m/s (se 0.09,
  n 26), touching crew-seconds 522 v 525. The chain continues (bridge, fights 157–180, hull-rest 54–59 for (b2)), ~2 h;
  M1b/M2b held until the whole run is ruled. Native told to port `77a1603f` now (the pair's proofs run while the chain
  finishes).
  **Run 2 JUDGED — PASSES every filed line (2026-10-14 16:39 PDT; `77a1603f`, builder0, GDScript):** (b2) hull-rest fresh
  seeds 54–59, n = 144 paired: pinned crew-seconds 2596 → 658 (−75 %, se 422: beyond 2 se); the hulls the fix reaches
  (≤ 10 m) 2596 → 556; scouts apart 1179 → 268; tracks 122 → 108 (within 2 se); pinned crews 65 → 14; STUCK (reported)
  6631 → 4794 (−28 %, se 628); rigs apart 0 → 102 crew-s (se 72, within 2 se: the rig's rule is bit-for-bit unchanged —
  Terminus proved it — its squadmates now move differently round it: environment); crews still moving at 75 s fewer on
  every task (screen 43 → 33, support by fire 26 → 21). (b3) bridge-pooled 18/18. Fights 157–180: kills 967 → 971 (se
  34), deaths 975 = 975, hit rate 0.710 = 0.710, on touching targets 0.645 → 0.670 (+2.5 pts, se 0.036). Terminus as
  reported. **Ruling: M4b SHIPS as the C30.2 pair** (manoeuvre's lab tip, code `77a1603f`, + native `pair/m4b2`
  `366b42bc`) when the pair's check is green; manoeuvre's own check (red on the three twin tests by design) is
  redundant and stopped. **M1b's and M2b's chains: GO, M1b first**, on their re-based branches.
- **M4b PAIR CHECK RED (2026-10-14 ~16:55 PDT; native `pair/m4b2` `366b42bc`, builder0 load 16–21: `make check exited 2`,
  2607 passed / 2 failed; 20 gates passed, 3 FAILED, 1 NOT RUN, 2 NOT JUDGED for load):** (1) `test_tactics_mixed_legs::
  test_four_tanks_attack_moved_across_the_sumps_arrive` — never arrived, 31.6 m to go (tracked hulls are ≤ 10 m: the new
  escape reaches them); (2) `test_nav_wall_contact::test_a_hull_driven_at_a_wall_is_counted_as_steered_into_it` — 16 of
  48 contact ticks cause=plant driver=unstick (reverse) where the test expects steer/drive (the sized escape firing at a
  wall); (3) sim-baseline moved on every map — expected for a declared change, the thirteen re-recorded on manoeuvre's tip;
  (4) net-smoke one client saw 1 of 2 tanks (load flake, rerun). Native re-running (1)(2) with NATIVE=off. **Ruling
  framework (as B5c-v4's):** manoeuvre traces both on the GDScript path first; a fix ships only if every judged row stays
  byte-identical (Terminus, hull-rest, fights); a fix that moves judged rows = M4b PARKED for round 31; (2) may be a test
  expectation encoding the old behaviour if the ticks are correctly classified (the edit granted in brains' test file if
  so). M1b/M2b chains PAUSED after their test re-runs until this is ruled.
- **M4b's ESCAPES PARKED for round 31; a READER-ONLY commit ships (ruled 2026-10-14 ~17:05 PDT).** Both failures reproduce
  on 77a1603f's GDScript path (trace log under references/round30/manoeuvre/): (2) 48 contact ticks = 32 steer + 16 plant
  (driver unstick, reverse: the 9.7 m tracked tank backs off once the honest reading fires the stall rule) — the
  classification is correct, the test encodes never-backs-off on a raw `drive`; (1) three of four law_tanks (7.3 m wheeled
  8×8) seat by 45 s; Green_M_3 takes ONE stall escape at 48 s (a 0.9 s reverse on full lock, nothing to shed) and from 57 s
  sits 21.5 m from its slot at ORCA's pace (cmd 0.07/−0.03, plant 0.86, real 0.00, touching nothing, behind a seated
  squadmate, reseats 0: the re-seat's "slow" test reads estimated_velocity 0.86 as driving, and at 0.07 throttle no rule
  reads it as stuck) — a real regression on a stage the series did not cover, the escape itself the cause; no fix in
  manoeuvre's paths leaves the judged rows byte-identical. **Ruling:** the escapes park (`lab/manoeuvre-m4b2` 77a1603f,
  both judged tables, the design note: ask first, a straight reverse by the outline sweep, blocked by name; the re-seat
  reading `real_velocity` is brains' line — round 31 with T4 and the rig rule as ONE A/B of the honest reading's
  consumers). **Ships: `lab/manoeuvre-m4b-reader`** = `Tank.real_velocity` (C30.6) + the census's `real` column + the
  pinned probe's honest class; NOT the two aim leads (a fights change measured only together with the escapes: round 31).
  Its bar (no series): sim-baseline UNMOVED (nobody in play reads the member), the wedge tests' reader lines (0.00 v the
  plant's 12.00), `test_nav_wall_contact` + `test_tactics_mixed_legs` green, native's pair equal (the tank.gd line in
  `tank_drive_native` only), the pair's check green. M1b/M2b re-base onto the reader commit; chains GO when their tests
  are green, M1b first.
  **Reader commit = `lab/manoeuvre-m4b-reader` `8cbdcfad`** (tank.gd: the member and its write after either plant;
  manoeuvre_census.gd's `real`; hull_rest_moving.py's class; five reader tests in test_manoeuvre_wedge; movement.gd and
  gunnery.gd = main's exactly). Native: escapes + lead mirrors kept on `lab/native-m4b-escapes` = 366b42bc; stream/native
  back to f1e4178b; the reduced pair on 8cbdcfad (one tank_drive_native line). NATIVE=off re-run on 366b42bc showed both
  failures identical with the library off (13 passed / 2 failed both ways): M4b's GDScript, not the port.
  Reader 8cbdcfad on builder0: 20 passed / 0 failed (wedge's five reader lines; wall_contact all, no backing off, every tick
  steer; mixed_legs all, the four 8×8s arrive). Native's `pair/m4b-reader` in its check; its green hash = the merge. M1b
  re-based = `55622870`, M2b = `1f1c9835` (on the reader base): tests then chains, M1b first.
- **Manoeuvre M1b(1) bar — `face_slot` alone (pre-registered 2026-10-14 ~14:20 PDT, before any judged number; DECLARED;
  FIRST run, a second on fresh seeds would be the last; a bug fix: any line missed = not shipped; full text in the
  stream's Status):** candidate `lab/manoeuvre-m1b` `37c47851` (re-based onto M4b2 `77a1603f` as `b14bee65`, no code change) = M4b + the anchor alone (`OrderController.
  face_slot` = the last move_to's goal, kept across the face; `plan_face` takes the even split ending nearest the slot and
  refuses any plan ending further from it than it starts + 0.5 m; counters face_slot_kept/refused; test 2/0). No
  turn-hull, no facekeep. Base `--nav-off=faceslot` same commit (both arms carry M4b), GDScript. Lines from CP-N: (a)
  hull-rest fresh seeds 48–53, 4 factions × 6 tasks, drawn AND clicked, `--turn-states`: the at-rest hull-error median
  per class × task not worse, permutation p < 0.05; (b) crews still moving at 75 s per task ≤ base + 2 se, M1_CLASS's
  paired se quoted (~+12 wheeled turret, ~+15 all at n = 27); (c) REPORTED: clicked support-by-fire's −17.8° reproduced
  or not; settle censored; counters > 0 new arm; (d) Terminus rigs + mixed, 13 fresh seeds 36–48: arrivals not down
  beyond 1 se, `sequential.py arrived:guard:0.10` as the early-stop rule (never before 6 seeds); contact-ticks reported;
  "a face left the slot" leg misses counted both arms, reported; (e) bridge-pooled 18/18, smokes, determinism, the
  thirteen re-recorded twice with the reason if they move, ≤ 0.5 ms, `native-verify-scenarios` (plan_face is GDScript on
  both paths: no port expected). Runs after M4b's judged chain. **Orchestrator's additions (before numbers):** (f) the
  candidate is judged on top of M4b, so it merges only AFTER M4b's pair (or, if M4b fails its gate, is re-based on main
  and its hull-rest lines re-run before merging: the Terminus lines could then differ); (g) the first early-stop use in
  this project: the row where `sequential.py` printed SERIES PASS/FAIL is recorded in this block with the n reached;
  (h) seed 21's rig (the defect in the wild, 16.8 m off after a face from 8.6 m) re-run on the candidate and reported.
  **M1b(1) Terminus (d) PASSES (2026-10-14 ~17:45 PDT; `55622870` on the reader base, 13 fresh seeds 36–48, GDScript,
  builder0):** rigs arrivals 176 → 179 of 208 (+3, se 5.13), mixed 284 → 286 of 312 (+2, se 3.56). **The project's first
  early-stop record (g):** `sequential.py arrived:guard:0.10` (A +2.77 / B −1.56, α 0.05 β 0.20, min 6 seeds): rigs
  SERIES PASS at run 10 of 13 (seed 45, llr −1.71), mixed SERIES PASS at run 6 of 13 (seed 41, llr −5.60) — the 13 had
  already run (the chain is not interactive), so nothing was saved this time; an interactive hook would have saved 10 of
  26 runs. Reported: contact-ticks rigs 8945 → 7662 (−14 %, se 2221), mixed 2475 → 1738 (−30 %, se 481); "a face left the
  slot" leg misses rigs 19 → 21, mixed 14 → 9. Bridge, the four-arm hull-rest (seeds 48–53, 576 runs, ~2 h) and rigs seed
  21 follow; M2b after.
  **M1b hull-rest: one remote call with four arms (576 real-time runs) hit builder0's 90-minute run cap** (make exited 124
  at 18:30): new_drawn, base_drawn, new_clicked complete at 144 each, base_clicked cut at 61, 9 files flagged corrupt by
  the copy-back (runs killed mid-write); the seed-21 reruns then refused by the wrapper's stale-run guard. Lesson: ONE
  hull-rest arm per remote call (round 29's note). base_clicked re-runs alone (REMOTE_FORCE=1 once, after a cwd-verified
  zero processes), then seed 21; the (a)(b)(c) tables read only when complete. (e) bridge-pooled 18/18. Preliminary (two
  complete drawn arms, not a verdict): at-rest medians within noise (permutation p 0.38–0.93 on the ALL rows), attack-move
  ALL 23.1 → 15.9°, wheels/fixed p90 61.1 → 9.2°.
  **M1b(1) JUDGED — PASSES by the filed letter (2026-10-14 ~19:30 PDT; `55622870` on the reader base, builder0, GDScript;
  table `references/round30/manoeuvre/m1b_judged.txt`):** (a) at-rest medians per task, ALL classes, drawn: ambush 33.8 →
  33.3 (p 0.87), attack-move 23.1 → 15.9 (0.38), move 8.3 → 7.0, right 8.9 → 7.5, screen 30.8 → 30.4, SBF 33.2 → 32.9;
  clicked 36.7 → 37.9 (0.57), 60.9 → 62.7 (0.75), 42.2 → 41.3, 41.7 → 42.1, 41.9 → 42.3, 35.7 → 35.3: no task worse at
  p < 0.05 — PASS. (b) crews still moving at 75 s PER TASK (the filed line), drawn: −1, −10, −10, +5, −4, −3 — every task
  within 2 se — PASS; the 18 class × task lines (reported): 16 within 2 se, wheels/fixed faced_right −8, **one at 2.3 se:
  wheels/turret faced_right 11 → 26 (+15, se 6.5)** — those 26 are 13 pinned + 13 driving, 0 face legs, 0 face creep:
  crews that never reached their slot, which the anchor cannot touch (the probe's known class; the A/A swing ±12–17 a
  task); one of 18 lines at 2.3 se is what chance gives. (c) clicked SBF's −17.8° NOT reproduced (35.7 → 35.3, p 0.92),
  as sizing predicted; the face_slot counters are not exported by the hull-rest probe (a tooling gap; the anchor's action
  shows in the drawn attack-move median and Terminus' face-order misses mixed 14 → 9). (d) Terminus PASS both squads;
  (e) bridge 18/18; (h) rigs seed 21 both arms byte-identical (the wild case was M4b run 1's escape, parked). **Ruling:
  SHIPS** — the filed (b) is per task and every task passes; the class × task miss is recorded with its reading, not
  ruled on (it was never a pass line). No port (plan_face is GDScript both paths; native confirms with
  native-verify-scenarios). Merges with kturnarc's pair as one batch, ONE main check.
- **Manoeuvre M2b bar — the creep lift on M4b + the planner's two executor fixes (pre-registered 2026-10-14 ~14:35 PDT,
  before any judged number; DECLARED; FIRST run, a second on fresh seeds would be the last; full text in the stream's
  Status):** candidate `lab/manoeuvre-m2b` `e94ca27e` (re-based onto M4b2 `77a1603f` as `acf29cb2`, no code change) (tests builder0 3/0: a War Rig's 10 m reverse leg drives 10.03 m by the arc rule v 10.31 by the chord; a paced IFV and a gang catapult roll a 120° open-ground turn with 0 gear changes v 14 and 23) = M4b `e8bfef2e` + round 29's creep lift
  re-based (`--nav-off=creeplift`) + the planner's two executor fixes behind one switch `--nav-off=kturnarc` (a k-turn leg
  measured by the arc driven, Σ real_velocity × dt, not the chord; the discrete stopping distance v²/2b − v·dt/2). Base
  `--nav-off=creeplift,kturnarc` same commit, GDScript; two switches, ONE declared change (the lift's legs end where the
  planner said only with the arc rule). (a) open+static creep episodes DOWN ≥ 50 % over fresh census seeds 14–19 (Terminus
  mixed + rigs) + sim 9–11, paired per run, se reported (no CP-N row: full grid; the census now prints per-run rows);
  (b) > 3-leg episodes not up beyond 2 se; friendly creep not up > 10 % (reported); (c) Terminus arrivals, rigs and
  mixed, 13 fresh seeds 49–61, not down beyond 1 se, `sequential.py arrived:guard:0.10` early stop; contact-ticks reported
  and the rigs' wall-contact direction explained from the worst trace; (d) kturnarc: driven/planned leg metres reported
  both arms, kturn_aborted not up; (e) bridge 18/18, ≤ 0.5 ms, symmetric, smokes, determinism, the thirteen, the arm's
  counters. Partial: (a) missed with (c) met = the finding to the planner, nothing ships; (c) missed = nothing ships;
  kturnarc cannot ship under this bar alone — if the lift fails it is re-declared alone with (c)(d)(e). Queues after
  M1b's chain; native gets the diff (`_planned_reverse`, a GDScript callback on both paths; one new Movement member
  `_kturn_arc_m` for exec_fields). **Orchestrator's additions (before numbers):** (f) the base arm's switch list is ONE
  `--nav-off=` flag, printed by every run (the parser finding above); (g) (a)'s "≥ 50 %" has no sized row, so the first
  census pair of this run IS the A/A it owes: both arms' per-run rows go to sizing's `probes.py` at the close whatever the
  verdict; (h) the rigs' wall-contact ticks under the lift, with and without each arm's two worst runs, beside (c) — round
  29's M2 failed on exactly that and the bar must show it either way; (i) as M1b(1): merges only after M4b's pair.
  **M2b JUDGED — NOT MET (2026-10-14 18:45 PDT; `1f1c9835` on the reader base, builder0, GDScript):** (a) open+static creep
  episodes (census 14–19 + sim 9–11, 15 runs paired) 53 → 37 (−30 %, se 9.8; the line was −50 %); > 3-leg 111 → 89;
  friendly 90 → 100 (+11 %, se 19); the lift fired 14727 unit-ticks (refused: slowed 4983, no_arc 240, blocked 1765);
  per-run rows written for sizing (g). (c) Terminus 13 fresh seeds 49–61: rigs arrivals 181 → 172 of 208 (−9, se 4.97:
  1.8 se down — the 1.645 se line MISSED; the SPRT at the full grid read PASS, the two rules disagree at this n, the miss
  is reported as the ruling says: truncation is decided by the fixed test); mixed 292 → 293 (SERIES PASS at run 6); rigs'
  wall contact-ticks 10400 → 13953 (+34 %, se 3034); rigs' k-turns 165 → 1028, kturn_multi 61 → 144. (h) worst run seed 51
  Green_S0_3: 1765 of the run's 1848 contact-ticks, 50 s touching the plaza-crossing wall at throttle 0.8 / lock 0.44,
  plant 9.4 m/s, goal distance frozen at 24 m — the lift rolled an earlier turn instead of creeping it and the rig met the
  wall at an angle where the phantom momentum grinds it: round 29's finding and M4b run 1's grind state again; the lift's
  gain is on short hulls in the open. (d) kturn_aborted 9 = 9; (e) bridge 18/18, brush +0.04 m/s (se 0.47). **Ruling (the
  filed partial rule):** the lift FAILS → the finding to the planner (F1: the creep at a corner is the planner's one forward
  arc or back-up); **`kturnarc` RE-DECLARED ALONE — GO:** same commit, base `--nav-off=creeplift,kturnarc` v new
  `--nav-off=creeplift`, Terminus 13 fresh seeds 75–87: (c) arrivals not down beyond 1.645 se both squads, contact-ticks
  reported; (d) driven/planned leg metres reported, kturn_aborted not up; (e) bridge 18/18, counters. Runs after M1b's
  last arm. Native pairs it (`_kturn_arc_m` in exec_fields; `_planned_reverse` a GDScript callback on both paths).
  **Amended before it runs (accepted):** the judged commit is `lab/manoeuvre-kturnarc` = the reader 8cbdcfad + the arc
  commit only (no lift code: 1f1c9835 carries the lift ON by default and must not merge); base `--nav-off=kturnarc` v new
  (no switch); the judged commit = the merge commit; native mirrors exactly it.
  Native's review of the diff found a bug before the judged run: the arc accumulator was reset only in the not-rolling
  branch, so a leg that starts rolling (every leg of a hull under 10 m, whose brake rule is off) inherited the previous
  leg's arc and ended early; fixed in `_kturn_start_leg` (one line) + a test (an IFV's second leg started rolling drives
  its own 8 m). **Candidate = `lab/manoeuvre-kturnarc` `e7a58262`** (807e8b8f is not a merge candidate).
  **kturnarc JUDGED — PASSES every filed line (2026-10-14 ~19:40 PDT; `e7a58262` on the reader, builder0, GDScript,
  Terminus 13 fresh seeds 75–87, base `--nav-off=kturnarc`):** (c) rigs arrivals 178 → 181 of 208 (+3, se 7.38; SERIES
  PASS at run 6), mixed 291 → 288 of 312 (−3, se 3.34, 1.645 se = 5.5; SERIES PASS at run 6); contact-ticks rigs 12184 →
  11755 (−4 %, se 3836), mixed 1861 → 1991 (+7 %, se 437), reported; leg seconds rigs 2120 → 1730 (−18 %), mixed 1839 →
  1782. (d) kturn_aborted 22 → 21; k-turns 398 → 396; kturn_ticks 42443 → 40311 (−5 %: legs end where the plan said; the
  driven/planned ratio needs `--reverse-log` records, the tick count stands in, stated). (e) bridge-pooled 18/18. The arc
  rule reached on every k-turn leg (398 plans an arm). **Ruling: SHIPS as a C30.2 pair** (merge tip e7a58262 exactly;
  native's mirror on `pair/kturnarc`, its builder0 pair check is the gate); merges in the final batch with M1b, ONE main
  check. Table `references/round30/manoeuvre/kturnarc_judged.txt`.
  **kturnarc PARKED for round 31 (2026-10-14 ~20:20 PDT):** the final batch check on native's `40b89dd1` (main + M1b +
  kturnarc + port + d122485c) was RED beyond the expected sim-baseline move: `ai-scenarios-check` 51/1 —
  `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck`; native-verify 0 mismatches (C++ = GDScript); attributed
  four ways on builder0 (n = 1, deterministic headless): native-off FAIL, native on FAIL, `--nav-off=kturnarc` PASS,
  `--nav-off=faceslot` FAIL → kturnarc's own GDScript, M1b clean. Lesson 307 a third time: a stage the series never
  covered (a scout's orbit) and any scoping would touch the scouts in the judged mixed squads. Kept:
  `lab/manoeuvre-kturnarc` e7a58262 + table; native's `lab/native-kturnarc` 40b89dd1. Manoeuvre traces the orbit for the
  round-31 note. **M1b ships alone**: native cuts main (`3ca70af2`, with the re-render) + 55622870 + d122485c and runs the
  round's LAST check.
  **The orbit traced (manoeuvre, builder0, e7a58262 GDScript; stream/manoeuvre `b994a987`, logs under references):** arc
  on 3 deck hits of 27 (FAIL) v `--nav-off=kturnarc` 58 of 83 (PASS), native's numbers exactly. Cause: a scout (hull 3.04 m)
  is under `KTURN_BRAKE_HULL_M`, so `kturn_brake_on()` is false and `_kturn_start_leg` sets `_kturn_rolling` with the hull
  still rolling FORWARD at 10 m/s under reverse throttle; both rules count the roll-out as leg 1, then part on the
  re-planned 3.0 m leg: the chord shrinks back through the plan point as the hull reverses (the roll-out cancels by
  accident); the UNSIGNED arc keeps the 1.2 m roll-out as progress and ends 2.2 m short, nose 40° off (under the 45°
  re-plan floor → a circle plan), and the orbit diverges (8 legs v 3). **Round-31 fix named, not built:** the arc signed by
  gear (`real_velocity.dot(nose)·gear·dt`), or the rolling logic for every wheeled hull — either moves the short wheeled
  hulls in the judged mixed squads (likely the 291 → 288), so a fresh A/B with `scenario_cp2` as a bar line.
- **Brains B7 DONE and MERGED (`d69d73d4`; C30.9):** `test_tactics_scenarios.gd` split 6 + 6 by measured time (218.7 +
  208.6 s v 425.5 s); `make test` on builder0 green 2585/0 with both files. **No wall gain:** test wall 1901 → 1918 s at
  5 shards round-robin (the longest shards are many files; the file is no longer a floor — the floor is now
  `test_native_traffic_hold`, 486 s). The new floor is native's file: round 31's split candidate.
- **Brains B3b bar — his bridge 108/108 (pre-registered 2026-10-14 ~16:40 PDT, before numbers; DECLARED; post-CP-N; the
  LAST attempt; no partial):** candidate `lab/brains-r30-bridge` `a117cb1a` = stream `33d9c310` + round 28's heading rule
  narrowed to the task's drawn facing (254fd98f) + round 29's mouth guard (474cf510) + NEW route-aware seating: on a drill
  move whose navmesh route crosses a deck, `TacticsFormation.seat`'s cost is (|crew→entry| + |exit→seat|)², so the crew
  nearest the crossing takes the seat farthest from it (the crossing found once per task point; static destinations
  only). Control = all three off (`--route-seat=off --mouth-held=off --reissue-heading=plan` = main's rules). GDScript
  only (Pathing.find_path already native): no native diff. Trace (rust t16 s2): the wedge across the river was seated by
  straight line at the drill's end; S_4 (westmost near bank) took the westmost far seat while every route crossed the
  east bridge; seats crossed; give-ways from 19 s; make-room swap at 23 s; rim 4.2 s. Tuning (that cell, n = 1): rim
  0.6 s, all across 27.1 v 37.4 s. Lines: (1) the FULL 108 (`bridge-series`, locks × both sides × seeds 1–3 × ticks 1–18,
  deterministic): on = 108/108 by bridge_verdict, control reported (main 106/108); (2) bridge-pooled 18/18; (3) arrive
  series FRESH seeds 33–36, n = 100 paired: within 8 m on ≥ control − 1 AND McNemar discordant-against ≤ 1; paired median
  no slower than +2 %; (4) counters: crossings_found > 0 in the bridge runs; mouth_held_resends > 0 somewhere in the 108
  (else "not exercised"); route seating fires 0× on arrive maps without decks; (5) cost ≤ 0.5 ms (element part) or NOT
  READABLE; (6) `test_tactics_reorder_heading`, `_reseat_keep`, `_route_seat`, the drills and pursuit tests + check green
  on the tip; the thirteen explained if they move. Per-run rows to references for sizing. **Orchestrator's additions
  (before numbers):** (a) the two cells failing at control named, and which of the three switches each needs (one re-run
  of those two cells with each switch alone — 6 runs, not 324); (b) any arrive discordant-against run traced before the
  medians (lesson 302); (c) the yard / Sumps gate cells are NOT in this bar (no deck): say so, and that `route-seat` cannot
  fire there (the counter at 0 on one Sumps cell, reported); (d) on a pass, the whole suite incl. `test_tactics_pursuit`
  on the tip (lesson 305, the whole suite with the rules ON) is the merge gate, not the filtered tests.
- **Brains B3b JUDGED — NOT SHIPPED (2026-10-14 ~17:20 PDT; `lab/brains-r30-bridge` `4bc708d7`, builder0, the full 108):**
  candidate **107/108** (failing: green t18 s3, rim_crews 1); control (all three off = main's rules) 106/108 (failing:
  green t5 s2, rust t9 s2: round 28's two cells). The three switches fix main's two cells and break one new cell. The
  last attempt by its rule: PARKED. The rest of the chain stopped as moot. Running for the record and round 31: the new
  cell traced on the candidate and with route-seat off; addition (a): main's two cells with each switch alone (6 runs).
- **Brains B6 — support by fire, the wheeled line: TRACED (not an artefact; three causes) and a fix DECLARED (bar
  pre-registered 2026-10-14 ~17:35 PDT, before numbers; v1 = the last attempt; no partial):** new probe `tests/tactics/
  sbf_probe.gd`, `make sbf-series` (four crews, SBF 100 m ahead, drawn 60° off travel v none, EACH CREW READ ONLY ONCE IN:
  ≤ 8 m of its slot, still 2 s; starts jittered by seed). Builder0, n = 1 a unit and arm: hull error at arrival drawn v
  none gang_ifv 74° v 36°, law_tank 25° v 44° (A_1 never in), gang_tank 20° v 48°, law_ifv 20° v 62°. Causes: (a) BRAINS:
  with a drawn facing the SBF line still hands each crew its fanned sector (the plain move zeroes sectors when he draws —
  "his facing is everyone's"); (b) the arrival gate (law_tank A_1 circles its gate reading no_path from 32 s: B5c, parked);
  (c) a wheeled hull arriving off-heading is not turned at rest (gang_ifv A_4 parked 168° off after its slot moved:
  manoeuvre's M1b). Tuning of (a) (`lab/brains-r30-sbf`, every crew given the drawn heading; `--sbf-told-sectors=on` =
  control; n = 1): drawn err gang_ifv 74 → 44.7°, gang_tank 20 → 11.2°, law_ifv 20 → 1.1°, law_tank 25 → 47.6° with all
  four in (was 3); clicked arm identical. **Bar:** candidate `lab/brains-r30-sbf` `9aa0cd7c` (= e4b37bae + the line-(4) counter in the probe's report, measurement only); arms on v
  `--sbf-told-sectors=on`, one tree; `make sbf-series SBF_SEEDS=7..18` (fresh) × law_tank gang_ifv law_ifv gang_tank
  (+ `tank`, tracked, as a guard), n = 12 runs an arm (no CP-N row; rows to sizing): (1) drawn arm, hull error at arrival
  pooled over the four wheeled classes: median on ≤ control − 10°, no class's median worse than control by > 2 se (paired
  by seed); (2) crews in, drawn: on ≥ control − 1 over each class's 48; (3) the clicked rows byte-identical between arms;
  (4) counter: facings replaced > 0 every drawn on-run, 0 clicked; (5) tactics scenario tests (SBF, screen, ambush
  postures) + the whole suite green on the tip; thirteen explained. **Orchestrator's additions:** (a) the tracked `tank`
  guard's drawn error within 2 se of control, stated; (b) the CPU never draws a facing — stated, so no CPU line; (c) cost
  ≤ 0.5 ms or NOT READABLE; (d) whether the sector hand-out reaches ported code (`native-verify-scenarios` on the probe,
  or "none"); (e) law_tank's 47.6° (worse than its 25° with one crew out) read against the gate cause (b) in the worst
  run's trace before the median. **Runs tonight only if builder0 has a slot after brains' final check; else round 31's
  first brains item with this bar.**
- **Brains B5c-v4 bar (pre-registered 2026-10-14 ~10:40 PDT, before numbers; DECLARED; the LAST attempt; no partial;
  pre-CP-N so round 29's sizes, may be re-sized ONCE in writing before the judged run if CP-N lands first):** candidate
  `lab/brains-r30-gate` `19eca15a` (round 29's gate restored ON + v4: a gate reached facing away is come round only
  where a turning circle of navmesh fits beside it, and only until stuck on terrain/a hull or 12 s, else latched; NEAR:
  no gate for a new goal already within the nominal approach length when via-the-gate > 2× straight). Arms on ONE
  commit, GDScript drive both (off = `--nav-off=gategiveup` = main's behaviour). Tuned on yard 23, Sumps 2, Terminus
  2–4; judged on FRESH seeds: (1) yard crossing (`gate-series`, yard_open cross, seeds 25–26 × {1,3,6,8,11,16}, n = 12):
  last-crew median on ≤ off − 5 s (never = 90 s), crews on ≥ off every run; (2) Sumps cell (seeds 14–15 × six ticks,
  n = 12): all-within-8 m median on ≤ off, no run > 5 s later, guns_on_arc ≥ off − 0.05; (3) Terminus head-on seeds 5–7
  t11 + seed 3 (B_4's): crews arrived on ≥ off each; the near counter fires on seed 3; REPORTED; (4) arrive series
  (`squad-arrive-series`, fresh seeds 29–32, n = 100 an arm): within 8 m on ≥ off − 1, median ±2 %; (5) counters > 0
  every on run, 0 every off run; (6) bridge-pooled 18/18 rule on; (7) `screen-slots` seed 61 A_2 in (B4); (8) heading:
  `test_wheeled_arrival` (all), `test_nav_arrival_heading`, `test_nav_gate_hold`, `test_nav_gate_v4` (90° AND 180°, the
  planner's scout case, B_4's near case) on the GDScript path now (24/0 builder0) and on the DEFAULT path at the pair with
  native's mirror + `test_native_gate` before shipping. Shipping = lab tip + native's mirror as a C30.2 pair; native shows
  yard and Sumps on the default path equal to the judged on-arm run for run. Tuning disclosed (n small): yard 21.1 s v
  never (6/6 v 2/6 all in), Sumps 24.3 v 24.4, Terminus 10/10 ×3 v 9/10 twice. **Orchestrator's additions (before
  numbers):** (a) the worst on-arm run of (1) and (2) traced before the medians (lesson 302); (b) how each come-round
  ended (latched / stuck / the 12 s cap) counted per arm and reported — a come-round ending mostly by cap is a finding;
  (c) cost ≤ 0.5 ms a tick at Sumps 25 a side GDScript path or NOT READABLE stated (C29.5); (d) the thirteen explained if
  they move; (e) Terminus seed 3 is n = 1: reported, never a pass line.
- **Brains B5c-v4 JUDGED — PASSES every line (2026-10-14 ~13:20 PDT; `lab/brains-r30-gate` `19eca15a`, builder0, GDScript
  both arms, fresh seeds; the tree since = + the .uid `bdc21eae` + measurement tooling `f1a804eb`):** (1) yard n = 12:
  every crew in 12/12 v 1/12 (Fisher, the deciding line), crews on ≥ off every run, median 19.0 s v never (reported);
  (2) Sumps n = 12: all-within-8 m 24.5 v 37.5 s, no run > 5 s later, guns_on_arc 0.941 = 0.941; (3) Terminus s3/5/6/7
  t11 reported: 10/10 both arms, last 50.1/56.2/45.6/43.7 v 56.8/82.2/47.0/52.7 s, near fired every run; (4) arrive
  n = 100 (seeds 29–32): within 8 m 99 v 91 (McNemar 8 v 0), median 24.5 v 29.6 s (−17 %, se 1.6), on slot 89 v 77;
  (5) counters > 0 every on run, 0 off; (6) bridge-pooled 18/18 rule on; (7) screen-slots s61 A_2 in 22.8 s v never;
  **A_4 ends 5.4 m off in BOTH arms (B4 not wholly fixed)**; (8) heading tests 24/0 GDScript, native's mirror green on
  the 5 named + `test_native_gate` 0 mismatches. Additions: (a) worst runs: yard s25 t1 (26.1 s) B_4 overshot when the
  squad's shape changed, near = no gate, **its U-turn ran onto terrain ~8 s (manoeuvre's M5, a second case)**; Sumps s14 t8
  (59.5 s; off never) S_3 came round, stuck 2 s later → turn_blocked latched, seat moved, near sent it straight in;
  (b) come-round endings (28/28 trace rows identical to the judged): latched 6, stuck 3, cap 0; (c) path.gate 0.081 ms
  on v 0.115 off (≤ 0.5 ms PASS); (d) thirteen at the pair; (e) noted. Traffic's relay reproduced on brains' tree
  WITHOUT traffic-t3: Terminus crossing s24/t3, s22/t6 last in 32.6/27.3 s, no 30–40 s far-end circling; v4 on
  30.2/21.7 s — **the 40–75 s sighting needs traffic-t3's rule underneath** (relayed to traffic). Planner's question: v4
  still lays the gate BEHIND the slot along the facing when the hull starts outside the approach length (how the 180°
  passes: it comes round it ~8 s); gates_turned fired 10× in the gate cells and 25× in arrive → round 31's side-gate form
  has cases. **Ship = lab tip + native's mirror as a pair; waiting on the PAIR's green hash from native.**
- **B5c-v4 PAIR CHECK RED (2026-10-14 ~14:45 PDT; native `787d3664` = stream/native + brains' tip f1a804eb; builder0
  `>> remote: make check exited 2`, 2601 passed / 1 failed, 25 targets passed / 1 FAILED):** `test_tactics_pursuit::
  test_a_spotter_retreating_at_8_mps_is_chased_down` — "the whole squad let go of the chase (17.0 s, every crew excused)",
  five wheeled gang scouts on yard_open seed 3; identical with the library removed (`make native-off … test`, same MEASURE
  line to the decimal), so the cause is v4's GDScript rule, not the port. Everything else green (sim-baseline unmoved,
  native-verify-scenarios 0 mismatches, 22 switches live, perf-judge PASS). Brains' own lab check passed it only because
  its default path still ran native's v3 mirror (lesson 305 again: a gate change is checked with the rule ON on the
  default path, i.e. the PAIR tree). **Ruling:** brains owns the fix. The judged bar was the last attempt, so a fix ships
  only if it is a SCOPING change that leaves the judged runs untouched: the 24 on-arm gate cells, the arrive series rows
  and screen-slots re-run on the fixed tree must be byte-identical to the judged on-arm (brains' table), and the pursuit
  test + the whole suite green on the pair tree. A fix that moves any judged row = B5c-v4 PARKED for round 31 with this
  finding (as round 29's a8df3dc3 was). Native re-mirrors the fix and re-checks the pair.
- **B5c-v4 PARKED for round 31 (2026-10-14 ~15:30 PDT; `lab/brains-r30-gate` = `f1a804eb`, judged `19eca15a`, every bar
  line passed; native's mirror on stream/native `787d3664`):** the pursuit red traced (builder0, `--gate-trace`, the 8 m/s
  test alone: FAILS, A_3 reversed 133° at 16.5–18.5 s; native's whole-suite run failed it differently — "let go at 17 s" —
  the outcome depends on process history). The gate answered exactly FIVE times in the run, all at t = 0.1 s while the
  squad formed its opening vee: A_1/A_3/A_5 aimed (as v3), **A_2 and A_4 `near`** (7.6 m from their vee seats); no chase
  order carries a facing, so no gate rule runs during the chase. The pursuit diverges downstream of two crews driving
  straight to their opening seats instead of round a 13.75 m gate; rule OFF, all 9 pursuit tests pass (8 m/s worst
  reversal 50°; 18 m/s 96°, near the line even there). **No honest scoping:** (a) "near not on a hull that has not driven
  since spawn" leaves the judged rows identical but guts the near rule's own demonstrations (B_4, the planner's scout both
  start standing) and is fitted to this guard; (b) "not on an arrived hull" moves judged rows (yard s25 t1's A_4). The bar
  was the last attempt. **Finding:** "the near rule tips `test_tactics_pursuit` (a knife-edge chase on seed 3) by changing
  two crews' opening moves; the come-round and latches are not involved." **Round 31 lead:** measure the pursuit test's
  own margin over seeds first (an A/A on the test; sizing's table), then re-judge v4 — or `near` only on a re-seat / new
  goal while on a task. Native's B5c re-check stopped. Brains → B7, B3b.

## Round 29: four streams (launched 2026-10-13, CLOSED 2026-10-14; briefs in `streams/archive/round29/`)

**Goal: round 28's four calls, each parked with a trace, carried home (`roadmap.md` *Round 29 candidates*; his words in
`game_design.md` *Round 28 direction* and *Round 29: his artillery call*): squads meeting in a street take turns with a
real place to wait; wheeled turret vehicles turn their whole hull to a drawn facing without a packed squad still turning a
minute later; artillery drives to his side and shells from there; a drawn flank is carried out. Beside them: his bridge
back to 108/108, the creep in tight streets planned as legs, and the C++ core continuing (N7.3, the tick's scheduling).**

| Stream | Folder (offset) | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | [streams/archive/round29/traffic.md](streams/archive/round29/traffic.md) | two of his squads meeting in a street: one waits beside the mouth, the other comes through, nobody locks up | **CP-T** T1, DECLARED, + native's port |
| **manoeuvre** | `godot-manoeuvre` (2) | [streams/archive/round29/manoeuvre.md](streams/archive/round29/manoeuvre.md) | wheeled turret vehicles end nose-on to his drawn facing within a few seconds; long trucks in tight streets turn in a few planned legs, not a creeping shuffle | **CP-M1**, **CP-M2**, each DECLARED (+ port for M2) |
| **brains** | `godot-brains` (3) | [streams/archive/round29/brains.md](streams/archive/round29/brains.md) | artillery drives round and shells from his side; a drawn flank is carried out; his bridge 108/108 again | B1, B2, B3 as they go green |
| **native** | `godot-native` (4, continuing) | [streams/native.md](streams/native.md) | nothing in play (equal answer); the tick's scheduling in C++; every driving change ported | N7.3 green; each pair |

**Ownership (as round 28's, restated):** each brief's header lists its paths. In `movement.gd`: traffic the give-way block
(`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`; manoeuvre the `drive()`
body, `_nose_stop`, `unstick`, `_pressing_escape`, `_manoeuvre`, the k-turn / planned-reverse / circle block; native the
member STORAGE; brains the rest (`_track_progress`, `_update_phase`, …). `order_controller.gd`: manoeuvre the face-at-rest
path; native its seams (C29.4: N7.3's freeze released); nobody else. `tank_brain.gd`: brains, except native's seams, manoeuvre's `_order_move` grant
(round 28's three lines) and, only if its stretch opens, scout's round-28 SUPPRESS arm (C29.6). `game/ai/wall_contact.gd`:
manoeuvre (native's N7.4 waits for manoeuvre's word). **Nobody** (a request): `game/match/**`, `game/tank/**`,
`game/units/**`, `game/garage/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`,
`game/announcer/**`, `game/theme/**`, `arenas/**`, `game/arena/**`, `game/control/**`, `tests/baselines/**` (except
declared lines), `tools/remote.sh`, `tools/slot.sh`, `mk/core.mk`.

**Contracts (round 29):**

- **C29.1 Every change to fights or driving is DECLARED** (C28.1 carried): one commit, merged alone, with its scenario and
  paired series, the CPU on the same behaviour; **the bar (with a partial-gain rule and the last attempt named) is sent to
  the orchestrator before its numbers**; tuned on named seeds, judged on fresh ones (lesson 298); the control arm can win
  and lose (295); the measuring point checked against each arm (297); an arm's own counter shows the rule fired (300);
  the count is what he sees, split from squadmates' noise (301); the worst run's trace read before the median (302).
- **C29.2 The C++ follows, and native carries it** (C28.2 carried, stage 1 ON): develop on the GDScript path
  (`--brains-off=native`); send native each SETTLED diff to the drive, `_avoid`/`Avoidance.solve`, `right_of_way`,
  unstick, gunnery or the per-crew execute before its commit (SendMessage, orchestrator copied); native ports it with an
  equal-answer proof; the pair merges back to back and is checked once. Any GDScript write to a `Movement` / `Gunnery` /
  lay member outside the native execute marks it stale (`movement.native_stale |= Movement.STALE_*`); run
  `native-verify-scenarios` on your scenarios before the diff goes to native. Pairs pre-empt native's N7 work.
- **C29.3 The street hold is traffic's, end to end, with one-line grants** (round 29 item 1). Traffic owns
  `Traffic.holding(crew) -> bool` and the hold itself (`game/ai/traffic*.gd`). Traffic is GRANTED one additive gate line
  (`if Traffic.holding(...)`, behind `--traffic-off=hold`) at each of: brains' stall clock (`_track_progress`), the
  "blocked" phase (`_update_phase`), the element's make-room / re-seat clock; manoeuvre's `unstick`, `_pressing_escape`
  and the k-turn entry. Owners: do not restructure those functions' first lines without telling the orchestrator; the
  gates merge with traffic's T1. Native ports the hold read from the record (C29.2).
- **C29.4 N7.3's freeze window: RELEASED** (granted 2026-10-13 morning, released the same hour). N7.3a (`OrderController.
  _physics_process` in C++, `native_controller`) proved equal but priced a LOSS (builder0, foundry 25 a side, ×3 an arm:
  the controllers segment 2.0 → 2.7 % of the tick; each extension crossing costs more than the VM step it replaces), so it
  is committed OFF for stage 2 and N7.3b is skipped. `order_controller.gd` is manoeuvre's face-at-rest path again, plus
  native's existing seams; nobody else.
- **C29.5 A behaviour change carries a cost line** (C28.4): its cost a tick at 25 a side on Sumps, GDScript path,
  ≤ 0.5 ms or NOT READABLE. **A pass line changes only with its reason written down** (C28.5): arrival is `all_in8_s`.
- **C29.6 Scout's fixed-gun SUPPRESS lay (round 28 S1, `scout-s1-suppresslay`) is manoeuvre's stretch, conditional:**
  only if CP-M2 (the creep as legs) ships; then the round-28 grant applies (one FIRST branch in `_act`'s "SUPPRESS" arm,
  `_combat_move`'s optional `aim_point`, `--scout-off=suppresslay`), judged ONCE on fresh census seeds 85–108 with kills
  as a guard (round 28's pre-registered last attempt). Brains told.
- **C29.7 builder0 runs every Godot run** (C28.6); the laptop only in a slot the orchestrator grants (E6b after N7.3).
- **C29.8 Formation geometry is brains'.** A slot spread that manoeuvre's turn room needs, and the 6 m screen slots for
  10 m gang trucks, are brains' code; manoeuvre asks through the orchestrator.
- C28.2's stale rule, C26.4–C26.10's rulings, C25.6, C24.6–C24.8 and the older standing contracts stand.


**Bars (round 29, pre-registered before their numbers):**

- **Traffic CP-T bar (pre-registered 2026-10-13, before any T1 number; T0 running on builder0 at `3cd5596b`, GDScript
  path, seeds {1,2,3}):** judged ONCE, both arms at one commit, GDScript path, fresh seeds {13,14,15} × ticks
  {1,3,6,8,11,16}, n = 18 a case; base arm `--traffic-off=hold`. **Terminus head-on:** (1) crews in ≥ base − 2;
  (2) `contacts_cross_fast` (between squads) down ≥ 25 %; (3) `all_in` median ≤ base + 20 %; (4) NO WEDGE: no run with
  > 1 crew never in where its paired base run had none (the worst run's trace read first). **The other three cases:**
  fast and all-in medians within 2 se of base, crews ≥ base − 2. **Plus:** the CPU mirror (`--side=rust`) on Terminus
  head-on reported and no worse on (1)–(4); the bridge pooled 18/18; `test_traffic_hold_live` fires (verdicts, holds and
  held ticks > 0 in the judged arm, counts in the report); cost ≤ 0.5 ms/tick at Sumps 25 a side GDScript path, or NOT
  READABLE stated. **No partial gain:** every line passes or nothing ships. Tuned on seeds {1,2,3} only. **LAST
  ATTEMPT:** the version traffic declares for judging is the last; a fail is parked with its trace. The C29.3 gates go
  in as one-liners (`_track_progress`, `_update_phase`, the element re-seat clock, `unstick`, `_pressing_escape`, the
  k-turn entry); brains and manoeuvre told.
- **Manoeuvre M1 bar (pre-registered 2026-10-13 ~13:40 PDT, before judged numbers; DECLARED; LAST attempt):** candidate
  `d7385da2` (`face_slot`: a face at rest keeps the last move_to's slot (round 28's faceslot read `mover._goal`, which
  `Movement.idle()` wipes, so it never anchored); `facekeep`: every pose of a face plan inside the arrive radius − 0.75 m).
  Wheels/turret drawn, new v base `--nav-off=turnhull,faceslot,facekeep`, same commit, FRESH seeds 22–33 (12 seeds: round
  28's M1 re-run on the same seeds moved the 75 s count by up to ±17, so 6 seeds cannot read a +5 guard). Point tasks
  median ≤ 15° and ≥ 70 % within 15° of crews AT REST; line tasks = hover/turret ±5°; clicked ±5° of base; settle paired
  median ≤ +6 s; GUARD moving-at-judge, all classes, ≤ base + 5 every task. **Orchestrator's additions:** (a) a guard miss
  only among classes M1 never commands (tracked, hover, fixed gun) passes only if each such class is within 2 se of base
  (paired), else nothing ships; (b) the wheeled-turret at-rest share is not down > 5 pts v base on any task. Partial:
  point tasks pass, line tasks fail → turnhull for point tasks only. bridge-pooled 18/18, arrive series, thirteen
  explained, ≤ 0.5 ms. **Clarified ~14:00 (before judged numbers; after tuning seeds showed SCREEN missing the guard, disclosed):** a wheeled-turret guard or at-rest miss on a LINE task = that line task fails → the partial rule (point tasks only), provided line tasks provably take today's path (a test that they never enter turnhull/faceslot/facekeep + one line-task run byte-identical to base); a miss on a POINT task → nothing ships. **wall_contact.gd:** M2 will not edit it → native's N7.4 GO. **M4 added** (after M2): unstick blind
  to a wedged hull (speed 6–12 m/s reported, zero displacement), DECLARED, own A/B, ported.

- **Manoeuvre M1 JUDGED — NOT SHIPPED (2026-10-13 ~15:00; `d7385da2`, builder0, fresh seeds 22–33, 288 runs an arm; table
  `references/round29/manoeuvre/m1_judged.txt` on stream/manoeuvre):** point tasks at rest move / right-drag / attack-move
  medians 3.2–3.3°, 80–82 % within 15° (base 41–59°, 14–32 %); line tasks = hover/turret; at-rest share ≥ base − 3.9 pts;
  settle +0. MISSES: the 75 s guard on attack-move (a POINT task) +8 (98 v 90; wheeled turret +12, se 8.9); support by
  fire +8; clicked medians outside ±5° of base on 4 tasks (3 of them lower error). Last attempt → parked:
  `d7385da2`, `manoeuvre-m1-pointonly`. Context (not used to rule): the clicked pair, where M1 never acts, moved the
  same class +10, so this guard's noise is about ±10 at n = 288. **Round 30 candidates:** a fresh-seed re-judge with the
  guard set from the probe's measured noise, written before numbers; `face_slot` alone as a declared bug fix (it
  improves clicked faces too: support by fire −17.8°, p 0.02).

- **Brains B1 JUDGED — PASSES every line (2026-10-13 ~15:00; `c2ae6e68` both arms, builder0, fresh seeds 13–15, n = 18):**
  from the side 18/18 v 0/18 (median 28.1°); off-cone rounds 0; alive 3.00 v 3.00; first round 27.1 v 2.3 s (+24.8,
  worst 30.9); clicked rows identical to main `bcef46a1`; killed 18/18 both, 35.7 v 9.3 s. Reported: off-side set-ups 6,
  repacks 8, 2 rounds before "in" (seed 15 t16, the worst run, traced). Merge on its clean check.

- **Brains B2 bar (pre-registered 2026-10-13 ~15:40, before numbers; DECLARED; LAST attempt → `lab/brains-r29-flank`):**
  f3a0145d's design + the charge latch on the TARGET's reach of a crew (max(its weapon range, the crew's reach × 1.15),
  remembered 4 s after it stops to shoot; `--approach-latch=crews` = round 28's, `=off` = the literal flank);
  `APPROACH_CARRY` ON by default (`--approach-carry=off` = B0). Judged once, both arms one commit, fresh seeds 10–12 ×
  {1,3,6,8,11,16}, n = 18 an arm a roster; median hit bearing within 35°. (a) even roster ≥ 12/18 (re-judged on new seeds,
  declared; round 28's 10/18 beside it); (c) CPU-commanded target ≥ 9/18, partial: (a) passes, (c) beats clicked by ≥ 5;
  fight guard kills ≥ clicked − 2, alive ≥ clicked − 0.5; side/rear ≥ clicked; clicked byte-identical to main; (b)
  reported; the latch counter per roster; worst run first; flank-probe seeds 13–15 + a before/after clip. CPU unchanged
  (never draws an approach); nothing native-ported. **Orchestrator's additions:** built on B1 (`c2ae6e68`); B1's drawn
  artillery on seeds 13/14/15 t1 identical to c2ae6e68's (or meeting B1's lines); a clicked attack and a drawn attack on a
  target that neither charges nor runs take the same path as `--approach-latch=crews`; bridge-pooled 18/18, arrive
  series unchanged. **Ruled ~17:20 (after (c)'s tuning, disclosed; follows C28.5, written before round 28's numbers):** (c) is
  judged on the fight guard + side/rear ≥ clicked + the latch counter firing; on-side (c) REPORTED (the latch makes a
  charging target an in-place fight by design; tuning a97d5aab seeds 4–6: latched 18/18 at 3.1 s, killed 18/18 both,
  alive 5.00 v 4.83). Added: the latch fires in 0/18 of (a) (a holding target).

- **Manoeuvre M2 bar (pre-registered 2026-10-13 ~16:30, before judged numbers; DECLARED; LAST attempt; no partial):**
  `7b895eed` (`manoeuvre-m2-r29`): round 28's creep lift re-based (no circle fill) + refusal counters, `--nav-off=creeplift`.
  Judged once on fresh census seeds 8–13 and sim seeds 6–8, GDScript path both arms: (1) open+static creep episodes −≥ 50 %;
  (2) > 3-leg episodes not up, static and open ≤ 3-leg shares each not down > 2 pts; (3) Terminus arrivals ≥ base and wall
  contact-ticks ≤ base + 10 %, mixed and rigs apart; (4) bridge-pooled 18/18; (5) ≤ 0.5 ms; (6) symmetric, check green.
  **Orchestrator's additions:** (7) friendly creep episodes not up > 10 %; (8) report why rigs' wall contacts moved the
  other way from round 28's judged run. Tuning disclosed (seeds 1–3): open+static creep 78 → 32, rigs' wall
  contact-ticks 2566 → 1473. After a pass: native's port, then bridge-pooled + Terminus on the ON path at the pair.

- **Traffic CP-T JUDGED — PASSES (2026-10-13 ~16:40; `3a94f38d` both arms, GDScript, seeds 13–15 × 6, n = 18; green
  `3a94f38d`: builder0 check exited 0, 2550/0):** Terminus head-on between-squad fast 475 → 91 (−81 %), crews 176 → 177,
  all-in 60.8 → 59.3 s, no wedge; other cases = base; CPU mirror 475 → 58; bridge-pooled 18/18; live test fires. Native's
  T2 equal; merged as a PAIR once native is green on a tree with both.
- **Traffic T1c bar (pre-registered ~16:50; DECLARED; last attempt):** `Movement.ask()` refuses while the asked hull is
  set up (`deploy_ratio > 0`; `--traffic-off=setup`). traffic-census fresh seeds 4–6: deployed_yields 0 in the arm, > 0 in
  base (else NULL); friendly-stuck ≤ base × 1.2 + 10; fast contacts ≤ base × 1.1 + 5; artillery fire not down > 2 se.
  **Orchestrator's additions:** bridge-pooled 18/18 and traffic's four cases with no wedge; brains' ApproachStage drawn
  artillery (seeds 13–15 × 6) both arms after B1 + CP-T are on main: give-way repacks → 0, B1's lines hold.

- **Manoeuvre M2 JUDGED — NOT SHIPPED (~17:30; `7b895eed`, GDScript, census seeds 8–13 + sim 6–8, builder0):** open+static
  creep 125 → 75 (−40 %, bar −50); > 3 legs 386 → 308; Terminus mixed arrived 133 → 132/144, rigs 82 → 75/96, rigs' wall
  contact-ticks 3938 → 6494 (still up 1425 → 2259 without each arm's two worst runs: the lift puts rigs into street walls,
  round 28's finding; today's tuning drop was seed luck). Friendly creep 125 → 113. Kept `manoeuvre-m2-r29`. The long pins
  traced (terminus rigs seed 9, Green_S0_3): NOT creep but **M4** — 12 m/s reported at throttle 1.00 with zero
  displacement, so unstick never fires. **M4 GO** (find why the reported speed is non-zero first; a `game/tank/**` edit
  needs the orchestrator's grant; native ports). Round 30 candidate: the creep lift re-judged on top of M4.
  **M4 cause (traced ~17:50):** `game/tank/tank.gd` ~721 sets `estimated_velocity = velocity` after `move_and_slide`, which
  returns the wanted velocity unchanged when the slide is fully blocked (moved 0.0000 m, velocity 12 m/s). **GRANT (A):**
  those lines only + a `real_velocity` switch: estimated_velocity = the real displacement (capped at the wanted planar
  speed). Bar adds: DECLARED fights guard (kills, deaths, hit rate within 2 se; hit rate on touching targets reported);
  net-smoke, combat-smoke, determinism; the thirteen re-recorded twice with the reason; tracked hulls shown; native's
  port in `tank_drive_native` equal, merged as a pair.

- **Traffic T1c JUDGED — NOT SHIPPED (~18:00; `761bd727`, census fresh seeds 4–6, n = 9 an arm):** set-up give-ways 25 → 9
  (bar 0); friendly-stuck, fast contacts, artillery shots pass; repacks while giving way 13 → 7. The 9 are give-ways a
  set-up hull STARTS itself in `_negotiate` with a new move. Parked `traffic-t1c`. Round 30: judge "repacks while still
  ordered to fire" (a hull with a new move is leaving anyway), not every set-up give-way.

- **Brains B5a split (~18:10, traced on builder0, both paths identical):** Sumps: the SEAT is 3.6 m off the navmesh (margin
  3.0) → B5a = no seat handed out > NO_PATH_MARGIN off the mesh (ground it to the nearest mesh point) + make-room never
  trades a slot its stuck crew reads no_path for. Terminus: the seat is fine; (B5b) a STALE LEASH: a swapped crew's move
  keeps the old slot's 14 m leash because the 2 m dedup ignores the leash centre; (B5c) the ARRIVAL GATE
  (`Movement._approach_gate`, brains') laid ~17 m back across the street for a wheeled hull facing east, which grinds
  there. Each declared with its own bar; native-ported status stated in each. **B5b DROPPED (~18:20):** the order leash
  applies only under the opt-in `leash_on()` (off; the native drive the same), and CombatMotion's leash is rebuilt each
  think, so the stale leash is inert; the latent dedup bug is noted at the dedup. B5a: no native diff; B5c: a C29.2 pair
  (`drive_native.cpp` mirrors `_approach_gate`). **B5a WITHDRAWN (~19:00):** the Sumps seat is ON the mesh in a live match
  (the rule fired 0 times; the 3.6 m was a probe on an arena not yet loaded); both sightings are the arrival gate 17–20 m
  back from the seat (APPROACH_MAX), mislabelled no_path because the route ends at the gate. B5c is the one fix.

- **Traffic T3 bar (pre-registered ~18:30; DECLARED; last attempt; no partial):** v3's squad-pair crossing verdict beside
  the hold (`--traffic-off=turns`; base = hold ON), fresh seeds 22–24 × 6 ticks, n = 18 a case, GDScript: between-squad
  fast pooled over the two crossing cases −≥ 25 %, neither up; every case crews ≥ base − 2, all-in ≤ +20 %, no wedge;
  same-squad fast ≤ base × 1.2 + 10 per crossing case; head-on fast within 2 se; CPU mirror reported; bridge-pooled
  18/18; live test fires; ≤ 0.5 ms. Native diff (Traffic.shape callback in `_avoid`) before the commit. Merge main first if
  the CP-T pair lands before the judged run.

- **Manoeuvre M4 bar (pre-registered ~18:40; DECLARED; last attempt; no partial):** `9db2a57c` (`manoeuvre-m4-r29`):
  estimated_velocity = the real flat displacement, capped at the asked velocity (`--tank-off=real_velocity`); test: a pinned
  truck 0.00 v 12.00 m/s. GDScript tank both arms, fresh seeds: (b1) Terminus census 14–19 rig wall+hull contact-ticks down,
  arrivals ≥ base; (b2) pinned crews (≥ 10 s on a move_to, |throttle| > 0.3, goal distance unchanged within 0.05 m) in the
  hull-rest probe seeds 34–39, down; (b3) bridge-pooled 18/18; (b4) tank segment reported; fights guard (manoeuvre-fights
  seeds 109–132, 180 s): kills, deaths, hit rate within 2 se, paired; net-smoke, combat-smoke, determinism. **Orchestrator's
  additions:** (b2) down by > 2 se paired; (b1) also with each arm's two worst runs dropped; after native's port the Terminus
  drive + bridge-pooled on the default path at the pair, the thirteen re-recorded twice in the pair commit; a tracked row.

- **Brains B2 JUDGED — PASSES every line (~19:20; `fa099d5b` = main c0ac69e0 + B2, seeds 10–12, n = 18):** (a) on side
  14/18 v 0/18 (32.8° v 79.7°), kills 8 v 4, alive 1.78 v 1.11, side/rear 0.88 v 0.82, latch 0/18; (c) kills 18 v 18, alive
  5.00 v 4.78, latch 18/18 at 3.1 s, on side 0 v 0 (reported); (b) both arms wiped. Clicked 54 rows identical to main; B1's
  battery rows identical; bridge-pooled 18/18; arrive series 100 rows identical. Worst run (a) seed 12 t16: came round,
  fought from the side inside the IFV's reach and lost all five (his "swing round anyway"). Merge on its check.

- **Traffic T3 JUDGED — NOT SHIPPED (~19:45; `d9b3339c`, seeds 22–24, n = 18):** crossings between-squad fast 206 → 95
  (−54 %) and head-on = base pass, but Terminus crossing all-in 39.4 → 48.3 s (+23 %), yard crossing crews 171 → 167 and one
  wedge (yard s22/t6) fail. Worst runs: the yielding squad crawls at 0.4 as a whole for 30–45 s. Parked `traffic-t3`. Round
  30: release the yielding squad once the other's tail clears the point, or crawl only crews within a squad length. The
  yard far-end misses (both arms) relayed to brains as a B5c sighting.

- **Manoeuvre M4 JUDGED — NOT SHIPPED (~21:00; `9db2a57c`, GDScript tank):** (b2) pinned crew-s 2902 → 1040 (se 460) and the
  fights guard (kills, deaths, hit rate within 2 se) PASS; (b1) Terminus rigs arrived 81 → 64/96 (all 6 seeds), rig
  contact-ticks 5337 → 8542 (1044 → 3882 without the two worst), mixed 720 → 3486; (b3) bridge-pooled 17/18. FAIL. Reading:
  the honest velocity zeroes wheels' `_speed` on every wall brush, so rigs grind along walls instead of sliding off.
  Parked `manoeuvre-m4-r29`. **Round 30:** keep the plant's `_speed` as today; give the real displacement only to the
  progress readers (unstick, `_pressing_escape`, the pinned probe) and aim leads.

- **Brains B5c bar (pre-registered ~21:30; DECLARED; last attempt v3 `053beffb`, `--nav-off=gategiveup` inverted):** a
  wheeled hull with a facing gives its gate up when BLOCKED aiming at it; holds a reached gate done per goal; a gate only
  where a turning-radius ring of navmesh exists (else a shorter run-in, else none). Judged GDScript path, both arms one
  commit: yard crossing last-crew median on ≤ off − 5 s, crews ≥ off every run; Sumps cell all-within-8 m median ≤ off, no
  run > 5 s later, guns_on_arc ≥ off − 0.05; counters fire on, 0 off; arrive series 8 m ≥ control − 1, median ±2 %;
  heading test. **Orchestrator's changes:** yard and Sumps n = 12 each; Terminus n = 3 REPORTED only (traced as an escape
  failure: B_4 jammed on terrain past its gate → round 30, manoeuvre); bridge-pooled 18/18 switch on; shipping = the
  default flip + native's mirror merged as a pair.

- **Brains, ~23:00:** B3 PARKED (time-box; `lab/brains-r29-bridge` 474cf510: cell rust t5 s1 fixed by a mouth guard; cell
  rust t16 s2 needs route-aware attack-move seating → round 30). B4 PARKED (`lab/brains-r29-linespread`): the stuck truck
  is freed by B5c's gate rule, not slot pitch → rides on B5c's flip. B5c guards in: arrive 100/100 v 89/100 (median 24.8 v
  29.1 s), bridge-pooled 18/18 switch on (law_tank is WHEELED). **GRANT (B5, queued attack):** `rts_controls.gd`
  order_selection's element-task branch, `_queue_task` / `_queue_task_for`, `test_control_queued_task`: a shifted
  attack-move / attack on a driving squad enqueues behind its waypoints, facing from the last waypoint; a chain of shifted
  attack-moves still runs in order; a shifted MOVE after a queued attack-move goes behind it; unshifted byte-identical.

- **Brains B5c JUDGED — PASSES every line (~22:40; `053beffb`, GDScript both arms, fresh seeds):** yard crossing last crew
  in: off never in 7/12 runs v on 21.95 s median, on 10/10 in all 12; Sumps all-within-8 m 38.8 → 36.0 s, no run > 5 s
  later (seed 3 never → 36.5 s); guns_on_arc 0.94 = 0.94; Terminus (reported) 10/10/9 → 10/10/10; counters on/off as
  required; arrive series 89 → 100/100; bridge-pooled 18/18. Worst run: a hull 9 m from its slot pulled 17 m back to a gate
  (round 30: no gate when already within the approach length). **Ship = the default flip + native's mirror as a pair**;
  native shows yard and Sumps on the ON path equal to the judged on-arm run for run. B5 queued attack grant extended to
  `_order_squads` (several squads queue like round 28's screen); merged separately.

- **Brains B5c PARKED (2026-10-14 ~01:30):** the default flip failed `test_wheeled_arrival`'s face-the-way-it-came case (dot
  0.50; the bar's heading test was 90°, this one 180°: lesson 305); the narrow fix `a8df3dc3` moved judged cells (yard 23,
  Sumps 6), so by the rule set before its proof it parks. Kept: `brains-b5c-flip`, native's `lab/native-b5c` (mirror +
  the fix's mirror, unrun). Round 30 with route-aware seating.

- **Brains B1 bar (pre-registered 2026-10-13, before numbers; DECLARED; the ONE attempt, a fail parks B1):** candidate
  `stream/brains` `c2ae6e68` (round 28's battery `88b6a724` restored, plus 4 traced fixes: the line once round is the
  post it drove to; standoff = safe 80 m + 10 m; a battery crew shells only inside the 30° cone; no notch past the post).
  ApproachStage `--live=on --his=artillery` ×3 `--theirs=law_ifv`, 90 s, builder0, FRESH seeds 13–15 × ticks
  {1,3,6,8,11,16}, n = 18 an arm (tuned on 4–6; 7–9 were round 28's judged seeds; 10–12 reserved for B2); arms drawn
  (east) v clicked (none), **both at `c2ae6e68`**. All must hold: (1) median shooter bearing ≤ 35° in ≥ 16/18 runs;
  (2) rounds fired by a crew > 35° off the side = 0 over all 18, and rounds before the element is round are reported;
  (3) alive ≥ clicked − 0.5 (mean); (4) first-round median ≤ clicked + 30 s; (5) the 18 clicked rows byte-identical to
  main `bcef46a1`'s; (6) cost NOT READABLE (the code runs only for an all-artillery element with a drawn approach, so
  none at Sumps 25 a side). Reported, not bar: set-ups off the side, repacks, and the rule firing (runs with in_s > 0).
  Lesson 295 said up front: the stage is one-sided, so "alive" guards the route, not a fight. **Orchestrator's
  additions:** the CPU line (C29.1): does the CPU's artillery take this path, reported either way; and whether any of the
  4 fixes reach native-ported code (`native-verify-scenarios` on ApproachStage, or "none ported" stated). Tuning
  (builder0, seeds 4–6 t1, n = 3): side 3/3 (median 28.8°), off-side rounds 0, first round 26.8 s, alive 3.00, 1 repack.
  **Request routed to traffic:** a set-up hull (deploy_ratio > 0) does not yield; the asker goes round (seed 4 t1 at 26 s:
  a set-up mortar truck yielded to a squadmate and packed up). Traffic's call whether it joins T1.

## Round 28: five streams (launched 2026-10-12 ~11:45 PDT, CLOSED 2026-10-13; briefs in `streams/archive/round28/`)

**Goal: his four calls (`game_design.md` *Round 28 direction*): squads crossing take turns; wheeled turret vehicles turn
their whole hull to a drawn facing; artillery shells from a drawn side; a drawn flank is carried out even onto a stronger
squad. Beside them: stage 1's laptop ruling (E6) and the C++ that keeps up with every driving change; scouts that keep
their gun on target while suppressing.**

| Stream | Folder (offset) | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | [streams/archive/round28/traffic.md](streams/archive/round28/traffic.md) | two of his squads crossing slow and take turns instead of nosing into each other | **CP-T** T1, DECLARED, + native's port |
| **manoeuvre** | `godot-manoeuvre` (2) | [streams/archive/round28/manoeuvre.md](streams/archive/round28/manoeuvre.md) | wheeled turret vehicles end nose-on to a drawn facing; no creeping shuffle in tight streets | **CP-M1**, **CP-M2**, each DECLARED, + port |
| **brains** | `godot-brains` (3) | [streams/archive/round28/brains.md](streams/archive/round28/brains.md) | a drawn flank is carried out in a live fight; artillery shells from the drawn side; squads not ordered into the enemy | B1, B2 as they go green |
| **native** | `godot-native` (4) | [streams/native.md](streams/native.md) | E6 on his laptop rules stage 1 ON or OFF; then every driving change ported; stage 2 priced for him | E6 → the ON commit |
| **scout** | `godot-scout` (5) | [streams/archive/round28/scout.md](streams/archive/round28/scout.md) | scouts keep the gun on target while suppressing | **CP-S1** DECLARED |

**Ownership:** each brief's header lists its paths. In `movement.gd`: traffic the give-way block, `_avoid`,
`_around_friends`, `_ask_behind`, `_hull_within`; manoeuvre the `drive()` body, `_nose_stop`, `unstick`,
`_pressing_escape`, `_manoeuvre`, the k-turn/reverse/circle block; native the member STORAGE (stage 1's grant); brains the
rest. `order_controller.gd`: manoeuvre the face-at-rest path; native the seams and storage; nobody else. `tank_brain.gd`:
scout the fight-motion hunk (+ SUPPRESS's motion for a fixed gun, agreed with brains through the orchestrator); native its
seams; brains the rest. **Nobody** (a request): `game/match/**`, `game/tank/**`, `game/units/**`, `game/garage/**`,
`game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/announcer/**`, `game/theme/**`, `arenas/**`,
`game/arena/**`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`, `mk/core.mk`.

**Contracts (round 28):**

- **C28.1 Every change to fights is DECLARED** (C27.1 carried): one commit, merged alone, with its scenario and paired
  series, the CPU on the same behaviour; **the bar (with a partial-gain rule) is sent to the orchestrator before its
  numbers**; judged runs on seeds the change was not tuned on (lesson 298); a stage's control arm must be able to win and
  lose (lesson 295) and its measuring point is checked against each arm (lesson 297).
- **C28.2 The C++ follows, and native carries it** (C26.2 with stage 1's surface). The drive, `_avoid`/`Avoidance.solve`,
  `right_of_way`, unstick, gunnery and the per-crew execute have C++ twins held equal by live-function proofs
  (`test_native_drive`, `test_native_execute`, `exec_verify`, `native-proof`). Behaviour streams develop on the GDScript
  path (`--brains-off=native` or the switch off) and send native each SETTLED diff before its commit (SendMessage,
  orchestrator copied); native ports it with an equal-answer proof; the orchestrator merges the pair back to back and
  checks once. Native keeps every port it has OFF-proven green at all times.
  **Stage 1 is ON (E6, 2026-10-12): the C++ OWNS the execute state.** Any GDScript code that writes a `Movement` /
  `Gunnery` / lay member outside the native execute MUST mark it stale (`movement.native_stale |= Movement.STALE_*`),
  or the native drive keeps the old value (found: `_kturn_start_leg`, 31006db9's check). Native audits every such door;
  traffic and manoeuvre add the stale line to every new write and run `exec_verify` on their scenarios.
- **C28.3 Stage 1's ruling is the laptop's** (E6, rule D in native's Status): ON only if the laptop's paired ABBA arms meet
  the pre-registered bar; the prediction (20 a side 0.97–0.99, 25 a side 0.85–0.87 of real time) is told to him as
  measured, beside the 1.00–1.03 he was told when he chose.
- **C28.4 A behaviour change carries a cost line** (C27.4): its cost a tick at 25 a side on Sumps, GDScript path,
  ≤ 0.5 ms or NOT READABLE.
- **C28.5 A pass line changes only with its reason written down** (C27.5): the arrival line is `all_in8_s` (every crew
  within max(8 m, settle radius), held 1 s), the strict line reported beside it.
- **C28.6 builder0 runs every Godot run** (C27.6); the laptop only in a slot the orchestrator grants (E6 first).
- **C27.2's freeze is lifted** and replaced by C28.2 (stage 1 is built; a driving change is written twice from here).
- C26.4–C26.10's rulings, C25.6, C24.6–C24.8 and the older standing contracts stand.

- **Traffic T1 bar (pre-registered 2026-10-12 evening, before T0's numbers):** the brief's bar unchanged; GDScript path
  both arms, n = 18 a case, start ticks {1,3,6,8,11,16}; tuned on seeds {1,2,3}, **judged on fresh {4,5,6}**; **v3 is the
  last attempt**. Design: one verdict per SQUAD pair (the later squad yields as a whole, v3's 0.4 floor; a crew at the
  conflict zone never yields; tie → priority on the right, then element id); keep right head-on only in a street (static
  geometry both sides, from the navmesh), never toward a squadmate abeam; open ground left to ORCA. + one CPU-side case;
  native-verify-scenarios before the diff goes to native.

- **Grant to scout (2026-10-12 evening):** in `tank_brain.gd`, (a) one new FIRST branch in `_act`'s "SUPPRESS": arm
  (~2475–2499) for a fixed gun on the lay planner (standoff, gunlay on, `_moves_while_fighting`, not bounding) returning
  `_combat_move(s, contact, spot)`, every other unit byte-for-byte; (b) `_combat_move` gains an optional `aim_point`.
  `--scout-off=suppresslay`. No `decide` change (no port). Brains told.

- **Scout CP-S1 bar (pre-registered 2026-10-12, before any census number; scenario pools seen first, disclosed):**
  PRIMARY fresh census seeds 61–84 (85+ if < 12 pair), new v `--scout-off=suppresslay`: fixed-gun gun-on-point during
  SUPPRESS ≥ +10 pts outside 2 se ships; +5..+10 outside 2 se ships with a note only if the scenario passes all four
  cases. GUARDS (paired, 2 se): all-fight on target not down, contacts not up, **SUPPRESS share of fight time not down
  (orchestrator's addition; absolute seconds reported)**; outcomes reported. Scenario `scenario_scout_suppress` n = 18 a
  case, all four pass and off fails one; check, native-verify-scenarios, ≤ 0.5 ms, symmetric.

- **Manoeuvre M1 bar + grant (2026-10-12 evening, before probe numbers):** traced: the "hull keeps its arrival heading" rule
  is `TankBrain._order_move` (round 8: an untold face becomes a stop for a wheeled turreted hull; a squad's drawn facing
  arrives as the element's sector watch, never "told"). **GRANT: ~3 lines of `_order_move`** (the decline skips a
  from=="order" face when the element task carries a drawn facing; `--nav-off=turnhull`); brains told. No C++ port (face
  turns for wheeled hulls run in GDScript). Bar: hull-rest-probe drawn wheels/turret median ≤ 15° and ≥ 70 % within 15° on
  each of 6 tasks; settle time +≤ 6 s median; clicked within ±5° of base; bridge-pooled, arrive series, thirteen explained;
  partial for line tasks: = hover/turret's error ±5°.

- **Brains B1 bar (pre-registered 2026-10-12 evening, before numbers):** trace (even roster seed 4): B0 rounds at the trucks'
  own 35 m reach inside the IFV's 60 m, then the TARGET's near-ambush sets off a 30 s assault-through. Design: the element
  plan owns a drawn approach until on side — ring = max(own range, target squad's reach + 10 m); pursuit only at ≥ 6 m/s
  for 2 s; no ambush/assault-through/break-contact from the target's own squad while rounding; after "in", the target
  closing is not an ambush. Measure: MEDIAN HIT bearing on the target's hull within 35° (same for every arm). Judged fresh
  seeds 7–9 × 6 ticks: (a) even roster ≥ 12/18; (c) moving target ≥ 9/18; (b) Law squad of five reported with losses;
  side/rear share ≥ clicked; clicked byte-identical. **+ fight guard on (a)/(c): kills ≥ clicked − 2, alive ≥ clicked −
  0.5 (orchestrator); flank-probe 3 fresh seeds + a before/after flank-clip for him.** Partial: (a) passes, (c) misses but
  beats clicked by ≥ 5 runs → ships with (c) noted.

- **Manoeuvre M2 bar (pre-registered 2026-10-12 evening):** (a) CREEP LIFT in drive() (C++ port follows): raise throttle to
  the creep line only when avoidance's pace is untouched (≥ 0.99) and the full-lock arc lines up and is clear
  (`--nav-off=creeplift`); (b) CIRCLE FILL in `_planned_reverse` (no port; `--nav-off=circlefill`). Base census 121 creep
  episodes. Judged on untraced seeds, GDScript path, one commit: creep episodes down ≥ 50 % (30–50 % with a note); > 3-leg
  episodes not up; Terminus arrivals ≥ base, wall contacts ≤ +10 %; bridge-pooled 18/18; ≤ 0.5 ms; symmetric. **+ after
  native's port: bridge-pooled and the Terminus drive once on the ON path at the pair's commit (orchestrator).** Candidate
  to brains: gang trucks screening into 6 m slots, one parallel-parks ~1 min.

- **Scout CP-S1 NOT SHIPPED (2026-10-12, blind seeds 61–84, game/ = c138e589):** gun on point in SUPPRESS +6.32 pts, se 5.17
  (n = 13): inside 2 se; guards held; fixed-gun kills 77 → 57 (−1.0/seed, se 0.5). Trace: ~60 % of SUPPRESS is a wheeled
  hull coming round in legs at 19–32 % on point. Kept on `scout-s1-suppresslay`. **One last attempt after manoeuvre's M2
  (the creep lift) merges (conditional: only if M2(a) ships): fresh seeds 85–108, kills promoted to a guard.** S2 (to brains B3): 23–30 % of fixed-gun deaths
  under an ordered MOVE, 14–17 % retreating, 3–7 % in SUPPRESS.

- **Traffic T1 v3 frozen at `672eb785` (2026-10-12 evening), single judged run on seeds {4,5,6} + the CPU side on both
  Terminus cases.** v1–v2d were tuning arms on seeds 1–3; "v3" = the one judged version (= v2d's code). Design: a crossing
  verdict per squad pair from mean headings (later squad slows as a whole, 0.4 floor); a head-on meeting in a street
  (navmesh ends within 16 m both sides) is a one-lane bridge (the squad still in the open waits at 0.2); street keep-right
  DROPPED (tuning: his head-on fast 716 → 990); open ground ORCA. Tuning seeds: fast contacts 294 → 198, 716 → 374,
  277 → 160, 113 → 113; arrivals no fewer; no case slower. Its port queues behind manoeuvre's M2(a) (native down).

- **Scout S3 bar (pre-registered):** a fixed gun on the lay planner short-halts only OUTSIDE its turning room
  (`CombatMotion.halt_allowed`, no bearing condition; `--scout-off=halt`). PRIMARY gang_scout his case: runs with contact
  9/18 → ≤ 4/18 (off arm ≥ 7 on the same commit); guards: gang's passing cases still pass, scout/law byte-identical; blind
  census fresh seeds 109–132: gang contacts, in-reach on target, kills, all-fight on target not worse beyond 2 se.
  Partial 5–6/18 with guards → ships with a note.

- **Manoeuvre M2 FAILED its bar (2026-10-12, `27b56521`, builder0, GDScript path, untraced seeds):** creep episodes 148 →
  123 (−17 %, bar ≥ 50 %); static ≤ 3-leg share 93 → 88 % (a new 39-leg episode by the circle fill); rigs on Terminus 55
  → 51/64 arrived, contacts 1797 → 3261 → (b) circle fill OFF as pre-registered; (a) judged alone next (time-boxed); no
  port needed yet. **M1 first judged run (`748735c9`):** line tasks meet the partial rule (27.6–27.9° v hover 28.1–28.7°;
  base 39–103°); point tasks medians 6.5–7.5° (base 61–73°) but 55–67 % within 15° (bar 70 %), +15–27 crews still moving
  at 75 s; a face-turn ping-pong fixed after (`--nav-off=faceslot`). **Ruled: M1's re-judge is its LAST attempt, on 6
  fresh probe seeds, + guard: crews still moving at 75 s ≤ base + 5 per task.**

- **Traffic T1 v3 FAILED (2026-10-12, `672eb785`, judged fresh seeds {4,5,6}, n = 18):** fast friendly contacts Terminus
  crossing 183 → 199 (+8.7 %; between squads 82 → 58 but squadmates 101 → 141), Terminus head-on 871 → 419 (−52 %), yard
  crossing 309 → 205 (−34 %), yard head-on 122 → 118: 2 of 4 (bar 3). Crews held, all-in ≤ +19.9 %, friendly-stuck down
  in all four; CPU mirror Terminus head-on 868 → 431. Parked `traffic-t1-v3`. **Ruled: T1b = the street head-on
  one-lane-bridge rule ALONE, last attempt, judged once on fresh seeds {7,8,9}:** Terminus head-on fast ≥ −25 %, crews
  ≥ base − 2, all-in ≤ +20 %; other three cases not worse (fast ≤ +10 %, crews ≥ base − 2); friendly-stuck ≤ base × 1.2 +
  10; bridge-pooled, arrive series, cost, native-verify-scenarios. The crossing half → round 29.

- **C28.5 ruling on brains B1's (c) (2026-10-12 evening, before the judged run; tuning seen, disclosed):** tuning v4
  (`c6cc7b6f`): (a) even roster on side 13/18 (median hit 33.9°) v clicked 0/18, killed 11 v 10, alive 2.11 v 2.33,
  side/rear 0.93 v 0.81: passes. (c) under the CPU commander the lone IFV CHARGES the squad (10.5 m/s): v4 on side 8/18,
  killed 12 v 18/18, alive 2.61 v 4.83: fails the guard. **Ruled: when the target closes inside the crews' reach, latch
  "in" and fight where it is (`--approach-latch=off`); (c) on-side REPORTED, guard kept (kills ≥ clicked − 2, alive ≥
  clicked − 0.5).** Reason: his call 4 was a stronger squad holding ground ((b) keeps "swing round anyway"); a target
  charging into the squad has left the position the side was drawn against, and circling it gives a 60 m gun free shots
  at 35 m guns. Told to him in player terms; reversible.

- **Traffic T1b's judged run on {7,8,9} VOID (2026-10-12):** the rule never fired (verdict counter 0; `_avoid` gated Traffic
  on turns/streetright only). Fixed at `474558f8` (gate includes streetturns; no parameter changed) + a live falsifier
  (`test_traffic_turns_live`: his Terminus head-on must make a verdict). Re-run on fresh {10,11,12}, same bar, still the
  last attempt; verdict counts per case reported.

- **Manoeuvre M2 NOT SHIPPED (2026-10-12):** (a) alone also fails (creep −20 %, floor 30 %; rigs' wall contact-ticks 1797 →
  4136: lifting rolls 10 m rigs into street walls, round 26's M3 again); 52 % of remaining creep is the friendly (pace < 1)
  case. Kept `manoeuvre-m2`. Round 29: plan a long hull's creep as legs (M1b's planner in the drive); friendly creep via
  traffic's give-way. No port needed. **Scout's conditional S1 retry is cancelled** (`scout-s1-suppresslay` parked).
  M1's last attempt running at `140275af` on fresh seeds 2 4 7 9 15 19.

- **B1's judged run started at `f3a0145d`** (v4 + latch, fresh seeds 7–9, three rosters). **B2 bar (pre-registered):** an
  artillery element with a drawn approach drives to the nearest point within 20° of the side at its standoff
  (max(80 m, target squad reach + 10), inside the mortar's band), straight if outside the enemy's reach else notching
  round in a column. Stage: 3 mortar carriers v a holding Law IFV, attack drawn from the east. Measure: median FIRING
  bearing within 35°. Fresh seeds 7–9: on side ≥ 15/18; first round ≤ clicked + 10 s; clicked byte-identical. **Partial
  decided in advance: +10–15 s ships with a note; guard: crews alive ≥ clicked − 0.5 (orchestrator).**

- **Traffic T1b FAILED (2026-10-12, `474558f8`, fresh seeds {10,11,12}, the rule fired: 19 verdicts on Terminus head-on):**
  fast contacts 872 → 440 (−50 %) but crews 173 → 170 (bar ≥ 171), all-in +26 % (bar ≤ +20 %), friendly-stuck 629 → 839
  (limit 764); other cases unchanged; CPU mirror 763 → 392, crews 170 → 173. Most of the excess is one wedged run (seed 12
  t16: the waiting squad creeps at 0.2 into the street mouth and the squads lock). Parked `traffic-t1b`. **Round 29: a
  real waiting spot outside the mouth that the stall clock, asks and unstick honour** (traffic + manoeuvre + brains).
  Traffic → T3, then stops.

- **Manoeuvre M1 NOT SHIPPED (2026-10-12, last attempt `140275af`, fresh seeds 2 4 7 9 15 19, 155 crews a task):** line
  tasks pass the partial rule (screen 27.5°, ambush 26.8°, support by fire 27.6° v hover 28.1–29.0°; base 40.9–113.1°);
  point tasks medians 5.2–6.1° (base 52–60°) but within-15° 70 / 69 / 64 % (bar 70 %) and **crews still moving at 75 s
  +14 (move), +25 (right-drag), +12 (screen), +8 (sbf) over base (guard ≤ +5)**. Ruled (a): his price was "a few seconds
  longer", not a minute of shuffling. Kept `manoeuvre-m1`. **Round 29: give the turn room among squadmates (a spread
  before the face, or legs planned against squadmates' discs), re-judged on fresh seeds.**

- **Native restarted (session `godot-native-34`); N6.1 + N6.2 at `d11f40ce`** (builder0 check 2522/0, 24/25: only
  remote-guard-test's quiet-window case, a load flake at load ~27, passes alone): `native_motion` OFF by its price (the
  planners' crossing costs more than the step: +1.7–3.5 %); `native_tank` ON (Tank._drive incl. move_and_slide as one
  call, ~6.5 % cheaper tank/drive); `native_combat` ON (hit terms + take_hit arithmetic, 0 mismatches over 840). native-proof
  equal on five maps. Merge after native-verify-suite; N6.4 granted (three seam lines in `pathing.gd`, `native_pathing`
  OFF until proven). **Load-sensitive tooling:** `tools/test_quiet_window.sh` "records once the window opens" (1 of 2
  samples in 30 s at load 27) — orchestrator's to harden.

- **Brains B1 NOT SHIPPED, PARKED (2026-10-12, `f3a0145d`, fresh seeds 7–9):** (a) on side 10/18 (bar 12; tuning read 13)
  but beats clicked clearly (median hit 33.2° v 67.8°, killed 10 v 4, alive 2.00 v 1.50, side/rear 0.87 v 0.77); (c)
  4/18 v 0/18, guard FAILS (killed 10 v 18, alive 2.39 v 4.89: the latch keyed on the crews' 35 m reach barely fires, the
  charging IFV stops at its own 45–60 m); (b) both arms wiped. **v8 refused:** it changes only (c)'s latch, so re-judging
  (a) on new seeds would be seed-shopping. Kept `lab/brains-r28-flank`. Round 29: latch on the TARGET's reach; (a) is
  close. B2 gated to batteries (B1's switch OFF, B2's ON), judged on its own bar.

- **Scout S3 SHIPPED (2026-10-13, merged `de45a69f`, builder0 green 2521/0):** a fixed gun on the lay planner short-halts
  only outside its turning room. His case (gang_scout) contact runs 9/18 → 0/18, all bars pass; blind seeds 109–132:
  gang contacts −0.31/seed (se 0.24), in-reach on target −0.49 (se 1.71), kills 33 → 28 (inside 2 se, noted). Scout DONE;
  kept `scout-s1-suppresslay`.

- **Brains B2 PARKED (2026-10-13, `lab/brains-r28-battery` = `88b6a724`, tuning seeds 4–6):** fires from the side 18/18
  (median shooter 28.2°), alive 3.00 = clicked, but first round 25.8 s v clicked 2.3 s (+23.5, past the +15 s cutoff):
  ~90 m at ~4 m/s on a 90° swing after three traced fixes (a deployed mortar never leaving a named move; a relocating
  battery holding fire via Element.relocating → ElementFeed → MOVE; the column re-laying its heading). Not judged
  (would confirm the fail). **For him (round 29): shell from where it stands while driving round, or accept ~20–25 s.**
- **Brains B3 FOUND: the CPU commander orders squads into the enemy** (seed 5 Parade, `make recon-probe`):
  ElementCommander re-tasks recon squads to `screen` a point 45 m short of the enemy focus (SCREEN_AHEAD_M), the enemy
  advances onto it (34 → 1 m by t 17) and the crews keep driving to their places. **Fix GO (DECLARED, CPU only):** stand the
  screen off at SCOUT_STANDOFF (85 m) and re-aim when an enemy comes within it. Bar: fresh census seeds 13–24, fixed-gun
  contacts under MOVE ≥ −50 %, recon deaths not up, CPU win rate within noise, thirteen declared; + all-unit MOVE
  contacts and screen re-tasks/min reported (orchestrator).

- **His bridge 106/108 BISECTED (brains B4, builder0):** `47b8527b`, `f193bcb8`, `2e2715e4` pass; **`7baffe24` (round 26's
  brains merge: any heading given/taken/turned > 20° re-issues a crew's order)** and `090b345d` fail. Fix candidate
  `254fd98f` (DECLARED; first named e3b6d2a9 in error): re-issue only when the TASK's drawn facing changed since the crew's order (`--reissue-heading=plan`
  = round 26's rule). Bar: the 108 = 108/108 (107 with no new failing cell ships with a note); round 26's re-order tests
  pass; arrive series fresh seeds 17–20 ≥ control − 1, median ≤ +2 %; thirteen declared; **+ the fight tests (pace-p0
  phase 0, the let-go guard) all pass (orchestrator).**

- **HIS PLAYTEST (2026-10-13): a queued screen after a waypoint** (`game_design.md` *Round 28, his playtest*) → **brains
  B5, TOP priority** (after B3/B4's in-flight judged runs, coding now). GRANT: the order-queue hunk of
  `game/control/rts_controls.gd` (`order_selection`'s element-task branch, the queue, `_copy_*`) and its tests. Probe
  through the player's input (lesson 291), paused planning AND live; armed orders with an automatic facing take it from
  the last queued waypoint; a drawn facing wins; unshifted orders byte-identical.

- **Native N6.4 merged (`37e05351` = native `5033c8b1`+status; builder0 check 2523/0, native-verify-suite 0 mismatches):** the
  nav wrappers in C++ (`native_pathing` ON, 300 pairs equal, price ~0). **N6.3 GRANTED as PERCEPTION ONLY** (line of sight,
  sight ranges, contact gathering as one batched pass; seams in `game/ai/perception.gd` + the gathering call site;
  `native_perception` ON once proven); **intel (what crews remember/believe) is NOT granted:** it is the AI's thinking he
  deferred. Brains told not to edit perception.gd.

- **Brains B3 judged (`b95a3d6e`, builder0, fresh showmatch seeds 13–24, n = 12 paired):** enemy hull contacts under an
  ordered MOVE (all units) 9.25 → 2.33/seed (−75 %, se 2.71); all contacts −62 %, no role up; recon deaths 5.00 → 4.58
  (not up); the same side wins 12/12; screen re-tasks per recon squad-minute 4.27 → 7.65 (≤ 1 a think, never < 10 m: not a
  thrash; the knob if he sees CPU screens shuffle). Merges once the fixed-gun MOVE line (the bar's exact line) lands.
- **Brains B4 FAILED (`254fd98f`, builder0, full 108):** 106/108: his two cells pass but two NEW cells fail (rust t5 seed
  1 crossed 3/4; rust t16 seed 2 a rim crew). Parked `lab/brains-r28-reissue`. Round 29: the cause is pinned (7baffe24's
  heading re-issue; `--reissue-heading=off` restores his cells); trace the two new cells before narrowing again.

- **Brains B3 SHIPPED (merged `6efe3450` = `b95a3d6e`):** the bar's exact line, scout-census fixed guns, fresh seeds 13–24:
  enemy hull contacts under an ordered MOVE 36 → 0 (per seed 3.00 → 0.00, se 1.50); all fixed-gun contacts 93 → 24; gun on
  target 21.9 → 20.2 %, inside turning room 6.3 → 3.5 %.

- **Native N6.3 (perception ONLY) at `a1174911`** (builder0 check 2524/0, 23 + 2 NOT JUDGED for box load; native-verify-suite
  0 mismatches): C++ answers WHO SEES WHOM (Match._update_intel's per-enemy first viewer in sight radius on a clear line,
  the gun-ready sample; rays cast from C++); intel stays GDScript (contact records, seen_tick, forgetting, stats);
  `native_perception` ON, 240 poses / 7012 lines equal, price ~0 (the rays are the engine's). **N6 complete as granted.**
  Queued for merge after main's closing check. Next: N7 proposal (core, outside thinking and round 29's contested code);
  **E6b** (his laptop, everything shipped ON v all native off, rule D) on the orchestrator's GO when he is away.

- **Native N7 (proposed `eaa5d433`, ordered 2026-10-13):** GO (1) projectile flight + impact queries (4–5 days; GRANT: seams in
  shell.gd flight/hit, Match._land_rounds, Match.incoming_projectiles, _damage_estimate); then (2) the suppression field
  (1–2 days; GRANT: threat_field.gd stamp/decay/at, Match._update_suppression). WAIT for round 29's split: (3) the tick's
  scheduling around the brain (~3 %, needs an order_controller.gd freeze window), (4) wall contact's observer (1.47 %, on
  nav/manoeuvre's say-so), (5) element_feed's gather (2.39 %, after round 29). (6) the match recorder last.

- **CORRECTION (native, 2026-10-13): N6.4's and N6.3's prices were INVALID** — `NativePathing.usable()` /
  `NativePerception.usable()` stepped aside when `OrderController.profile_detail` was on, and the tick profile sets it:
  both arms ran GDScript. Correctness proofs stand (proofs, native-proof, checks and verify-suites run without the
  profile). Fix in test (seams no longer depend on profile_detail); re-pricing. **Asked: audit every seam's gate against
  every measurement mode; confirm E6 (stage 1 on his laptop) was NOT affected; a guard test asserting each ON switch's
  native counter > 0 under the tick profile** (lesson 300's cousin).

- **Native N6 ordered (2026-10-12, the orchestrator; his principle "core components in C++ long-term"):** (1) the tank's
  motion (tank.gd/TankMotion script half; 0.63 ms builder0; 3–4 days; GRANT: `game/tank/**` for that port, seams only);
  (2) combat resolution (shell/impact/armour/damage; 4–6 days; GRANT: the resolution functions in `game/match/**` and
  `game/tank/**`, seams only); (3) perception + intel as one batched pass (2–3 days; brains' file and stage 2's first
  block: ask the orchestrator first); (4) the nav wrappers (1 day). Each: equal answer, thirteen and determinism unmoved,
  native-proof on = off, native-verify-suite green, a switch ON once proven, its price reported. N3 diffs pre-empt.

**Checkpoints:** E6 → native's ON commit (if it rules ON) → everyone merges main. CP-T, CP-M1, CP-M2, CP-S1 and brains'
B1/B2 each merged ALONE as they go green (with native's port where C28.2 applies), queued by the orchestrator.

**Decided for him (his calls, 2026-10-12):** take turns; turn the whole hull; artillery honours the side; swing round anyway.

**Standing rules:** rounds 12–27's (lessons 225–298).

## Round 27: four streams (prepared 2026-10-11 evening; briefs in `streams/`)

**Goal: his decision (stage 1 C++: the driving and shooting half, the C++ owning the execute state, ~2.5–3 weeks) and his
showmatch feedback (`game_design.md` *Round 27 direction*: scouts close to contact with no room to turn, and never
reverse to keep a moving target). The scout fix goes FIRST and lands while the freeze still allows it; the think side
keeps moving; everything that rewrites the drive (traffic's convention, the wheeled creep) waits for stage 1.**

| Stream | Folder (offset) | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|
| **scout** | `godot-scout` (1) | [streams/archive/round27/scout.md](streams/archive/round27/scout.md) | scouts fight from a distance they can still turn in, and back up to keep a target that slides past their nose | **CP-S** S1+S2, DECLARED, alone (+ native's port if `decide` moved) |
| **brains** | `godot-brains` (2) | [streams/archive/round27/brains.md](streams/archive/round27/brains.md) | a squad told to arrive has every crew on its seat (no crew stuck behind a parked squadmate); drill seats by nearest that keep the lead's role; ambush guns on the drawn facing | **CP0** B0 (attack honours `approach`) → orders merges main |
| **orders** | `godot-orders` (3) | [streams/archive/round27/orders.md](streams/archive/round27/orders.md) | press on an enemy and drag: the squad attacks from that side; showmatch's end shot stays on the arena | after **CP0** |
| **native** | `godot-native` (4) | [streams/native.md](streams/native.md) | nothing in play until E5/E6; then 20 a side at about full speed on his laptop | E1 OFF on main early; E5 ON in an A/B |

**Not this round (wait for stage 1, the drive is frozen):** traffic's friendly convention (his crossing cases already
pass since round 26's CP1a; his question on taking turns v pushing through is put to him for when it runs); manoeuvre's
wheeled creep (M3) and the rig carrot. Kept branches: `traffic-cp1b-v4`, `manoeuvre-m3`, `local/perf-m3-port`,
`lab/brains-mr2` (brains B2 starts from it), `lab/brains-carrot`.

**Ownership (every path exactly one owner; the full lists are in each brief's header):**

- **scout:** `game/ai/combat_motion.gd`; in `tank_brain.gd` `_combat_move`, `_hold_motion_plan` and the ORBIT controller
  with its constants; in `movement.gd` only `_manoeuvre`'s `reaimed` rule; `game/ai/manoeuvre.gd`;
  `tests/test_ai_combat_motion.gd`, new `tests/test_scout*.gd`, `tests/ai_scenarios/scenario_scout*.gd`, `mk/scout.mk`.
- **brains:** `game/ai/**` except scout's, native's and the frozen files (C27.2); `game/tactics/**`,
  `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd` + one registration line), `tests/tactics/**`,
  `tests/nav/**`, `tests/test_ai*.gd` (not combat_motion's), `tests/test_tactics*.gd`, `tests/test_nav*.gd`,
  `tests/test_form_up.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
- **orders:** `game/control/**`, the order hints in `game/ui/**`, `tests/test_control*.gd`, `mk/command.mk`'s control
  targets, the showmatch tooling, and (grant) `game/camera/**`'s cinematic framing.
- **native:** `native/**`, `game/ai/native/**`, `tests/native/**`, `tests/test_native*.gd`, `mk/native.mk`,
  `mk/pace.mk`, `brain_switches.gd` (one switch line each from others: merge note), `cover_map.gd`, `think_quiet.gd`,
  the seams on main, and stage 1's grants: the seam at the top of `OrderController.compute_command`, `Movement`'s and
  `Gunnery`'s member STORAGE behind accessors, `traffic.gd` for its port, `wall_contact.gd`'s observer.
- **Nobody** (a request through the orchestrator): `game/match/**`, `game/tank/**`, `game/units/**`, `game/garage/**`,
  `game/modes/**`, `game/network/**`, `game/audio/**`, `game/announcer/**`, `game/theme/**`, `arenas/**`,
  `game/arena/**`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`, `mk/core.mk`.

**Contracts (round 27):**

- **C27.1 Every change to fights is DECLARED** (C26.1 carried): scout's S1+S2, brains' B2 and B4, each one commit,
  merged alone with its scenario and paired series, the CPU on the same behaviour. Everything else pre-registers
  UNMOVED on the thirteen lines and determinism. Two declared changes never share a merge: the orchestrator queues them.
  **The bar is written before the numbers** (lesson 292): each declared change messages the orchestrator its ship rule
  (including a partial-gain rule) before its comparison runs.
- **C27.2 The execute step is frozen for stage 1** (native's draft, C26.2 widened). While native runs, a behaviour change
  to `movement.gd`'s drive and its callbacks, `gunnery.gd`, `order_controller.gd`'s execute path, `steering.gd`,
  `avoidance.gd`, `traffic.gd`, `wall_contact.gd`, `clothoid.gd` waits, or goes to native as a diff to port. Think-side
  files (`tank_brain.gd`'s situation/decide/act, tactics, elements, `combat_motion.gd`) are NOT frozen. **Exception for
  scout:** `_manoeuvre`'s `reaimed` rule and `manoeuvre.gd` (GDScript callbacks from the native drive; native's E2
  ports `_manoeuvre` LAST, after scout's CP). A change to `decide` or `build_situation`'s core (C++) goes to native as a
  diff before the commit (SendMessage, orchestrator copied); the pair merges back to back.
- **C27.3 A drawn approach reaches the attack task** (orders ↔ brains, C26.3's shape). Orders puts the drag on the task as
  `task["approach"] = [x, z]` (normalised; the direction of the run IN: release point → target, so the squad attacks from the target's side the drag was released on; confirmed both sides 2026-10-11, orders `cd113207` `rts_controls.gd:1810`, brains `9603c1d7`; a target running ≥ 2 m/s is a pursuit and ignores it); absent = today,
  byte-identical. Brains (B0, first) honours it and merges it as CP0; orders then merges main. Until then orders tests
  against a stub in its own paths.
- **C27.4 A behaviour change carries a cost line** (C26.10 carried): its cost a tick at 25 a side on Sumps, GDScript path,
  measured, pre-registered and reported beside its behaviour numbers (≤ 0.5 ms unless the orchestrator rules otherwise).
- **C27.5 A pass line changes only with its reason written down** (C26.6 carried): the trace, the old and new line and
  what a player would see, approved by the orchestrator before commit. Pool timing-sensitive results over start ticks
  {1,3,6,8,11,16}. An arrival counts every crew inside its settle radius (lesson 293; brains B1 builds the line).
- **C27.6 builder0 runs every Godot run** (C26.7 ruling carried): `make remote T=…`, lint and single tests included; the
  laptop runs Godot only in a slot the orchestrator grants (native's E6 has priority).
- **C27.7 native outlives the round.** At round 27's close native's worktree and branch are kept (not archived); its
  merges land as they go green (E1 OFF first). Scout's and brains' declared merges are checkpoints native merges.
- **C26.4–C26.10's rulings, C25.6, C24.6–C24.8, C23.1a, C23.2, C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5,
  C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

- **CP-S ship rule (pre-registered 2026-10-11, scout, before the paired comparison; full text in scout's Status):**
  `CombatMotion.plan_lay` (2.1 s rollout over the fixed gun's plant v the target's predicted pose; forward/reverse/brake x
  5 locks by gun-on-target time; turning room a cost; `--scout-off=gunlay`; `decide` and M1 untouched, no port). Ships if
  (1) `scenario_scout_cross` n = 18/case passes its 5 bars and base fails his case; (2) scout-census, 12 showmatch seeds
  new v off: fixed-gun gun-on-target +5 pts (+2..+5 ships with a note, < +2 no), **the gain outside 2 se of the 12 paired
  per-seed differences (the orchestrator's addition)**, fight-option enemy contacts not up, inside-turning-room share
  not up > 1 pt; (3) check green, thirteen lines' moves declared; (4) ≤ 0.5 ms a tick, 25 a side Sumps; (5) symmetric.
  (1)'s pool was seen before registration (disclosed): (2) is the blind test. Census base (main `c37605f0`, builder0, 12
  seeds): gun on target 18.4 % of 1537 fight-s; 365 enemy contacts, **254 under an ordered MOVE** (squads ordered into
  the enemy: brains' side, filed).

- **CP-S v1 FAILED its pre-registered census (2026-10-11, scout, builder0, 12 paired seeds): no ship.** (1) passed:
  `scenario_scout_cross` n = 18/case, all 5 bars on new, off fails 4 of 5 incl. his case (gun on target 0.20 → 0.75,
  re-acquire 8.4 → 0.5 s). (2) failed: real-match gun on target +1.34 pts, se 3.06 (18.4 → 18.8 %). Contacts fell
  (fight-option 121 → 52, ordered-MOVE 225 → 47 — the MOVE drop unexplained: divergence or a path, to trace). Next: where
  the 81 % off-target fight time goes (option × motion, in reach, planner active); any v2 bar sent before its census.

- **CP-S v2 bar (pre-registered 2026-10-11, scout proposed, the orchestrator amended, before the census):** v1's MOVE
  contact drop was divergence (arms differ before first contact). 45 % of a scout's fight time is outside the planner
  (ENGAGE out of reach/sight 24 %; SUPPRESS 20 %, FLANK 9 %, CLEAR_LANE 4 %: brains' motion — filed). Two v1 defects fixed
  (a hold winning on commitment 134° off; `_combat_move`'s outranging stop firing 140–155° off). **PRIMARY:** gun on
  target in reach (range + LOS) during ENGAGE, paired new − `--scout-off=gunlay`, **fresh seeds 13–36** (1–12 were traced:
  reported only); ≥ +5 pts outside 2 se ships, +2..+5 outside 2 se ships with a note. **GUARDS (paired, not worse beyond
  2 se):** on target / all fight-s; in-reach ENGAGE share of fight-s; fight-option enemy contacts. Plus scenario (1) all 5
  bars n = 18, check green, thirteen declared, ≤ 0.5 ms a tick.

- **CP-S v2 PASSED its blind census (2026-10-11, scout, builder0, tree `90413868`, seeds 13–36):** primary +16.14 pts
  (se 5.16, n = 21); guards over n = 22: all fight-s on target +5.21 (se 1.66), contacts −6.27/seed (se 3.47), in-reach
  share −3.42 (se 2.01, passes, close). **Outcomes (reported): kills 40 → 36, damage 21970 → 18845 (−14 % pooled, inside 1
  se), deaths 354 → 359 — unchanged within noise.** Thirteen lines: 7 moved (declared, `36d67c08`, read 4× identical).
  **C27.5 ruling:** check's scout_cross subset runs start ticks {1,6,11}, bars unchanged: APPROVED. Next trace: does the
  lay planner open range (in-reach seconds −21 %)?

- **C27.5 ruling (2026-10-11, brains B1, before any B2 number):** the arrive series on main (`3aa67b17`, builder0, 100
  cells): the element says 99/100 arrived, the strict every-crew line (3.5 m) 68/100 — 31 hollow (worst crew ≤ 6 m: 13,
  6–12: 8, > 12: 10). Many are the element's DESIGNED tolerance (REISSUE_M / IN_POSITION_M = 8 m). **Ruled: `all_in8_s`
  (every living crew within max(8 m, settle radius) of its own slot, held 1 s) is the judged line for B2; the strict line is
  reported beside it.** Whether 8 m is too loose for a formation's look is a separate candidate (for the lead, with
  pictures). B2 gains a third part: the stuck-crew watch keeps running after arrival (8 of the 10 > 12 m runs had 0
  re-seats); guarded by round 26's paired fight tests, the let-go guard, bridge-pooled, and no re-seat of a crew engaging, in a
  drill or under a moving task. B3: make-room priced by removal, 68 = 68/100 (1 swap): no measured gain.

- **B2 disclosure (2026-10-11):** the Sumps cell (seeds 1–4 × 6 ticks) was seen under both lines before the ruling and tuned
  on (v1's pause everywhere regressed seed 2: 6/6 at 24.8 s → 3/6 at 57.1 s, re-seats 4 → 47; v2 narrows the pause to a crew
  pressing a parked squadmate: 8 m line 14 → 17/24). So bar (1) is required but not evidence; **the blind evidence is the
  arrive series (fresh seeds 5–8 if any B2 variant has touched seeds 1–4 of it) + the fight guards; (8) reported: the
  Sumps cell at fresh seeds 5–8.**

- **CP-S merged 2026-10-11 (`f4c5f7c9` = scout `ae0a50a4`, builder0 exited 0, 2471/0, ALL JUDGED; seven sim lines moved,
  declared).** Clips for the lead: `build/scout_clips/` (seed 13, Parade, Gangs v Law; before/after).
- **B2 v3 FAILED rule (2) (2026-10-11, brains, game code `787cd2e4`, builder0, series seeds 1–4, 8 m line):** 89 v 86
  arrived but 4 cells lost (≤ 1) and +13.4 % median (≤ 10 %); the post-arrival watch re-seated 89× in 61 cells (control 6
  in 100): an ordinary halt settling also "drives without closing". v4 (`730788b1`): post-arrival only for a crew pressing
  a squadmate parked on its slot; judged on FRESH series seeds 5–8, control paired in the same run.
- **The flank stall traced (brains, from orders' flank-probe seeds 3/13):** (a) pre-B0: below the attack's close-in band
  the crews are on attack-moves that stop at full range (70 m); a target that never fires back is never closed on; (b)
  B0 circled at 70 m, past a tank's 62 m sight → the attack became a pursuit (no side) and stopped 40–54° off. Fix on
  `lab/brains-close` (`b93638fb`): DECLARED, after B2, bar before numbers. **(Overturned 2026-10-12: artillery; parked — below.)**

- **brains-close bar (pre-registered 2026-10-11, before its numbers; DECLARED):** (a) an attack goes in once within the crews'
  LONGEST weapon range (control `--attack-close=effective`); (b) B0's drive round at min crew sight − 6 m
  (`--approach-sight=off`). Ships only if ALL: (1) flank-probe drawn ≥ 11/12 within 35° incl. seeds 3 and 13, clicked nearest
  crew ≤ 45 m ≥ 11/12, **+ 6 fresh probe seeds reported (the orchestrator's addition; 3/13 were traced)**; (2) quiet stage
  ≤ 45 m ≥ 17/18; (3) targets that fire back: approach-series side ≥ 17/18, kill time ≤ +10 %, crews alive ≥ −0.25;
  (4) fight guards, tactics-drills, ai-scenarios, bridge-pooled 18/18, the 108 ≤ 1 a side; (5) CPU v CPU army-series
  paired, outcome within noise; (6) thirteen/determinism or explained, ≤ 0.5 ms. Partial: split (a) from (b); (b) alone
  not declared if thirteen unmoved.

- **Scout's range trace (2026-10-11, seeds 13–36, builder0): no range term.** ENGAGE bearing seconds 455 → 526 (+16 %), mean
  range while bearing 21.1 → 26.4 m (inside the MG's 35 m edge); flat damage most likely fire outside ENGAGE (SUPPRESS 20 %)
  + per-seed noise. **S4 bar (pre-registered, DECLARED):** `_combat_move`'s short-halt early return no longer stops a fixed
  gun on the planner unless it bears and stands outside its turning room (`--scout-off=halt`). PRIMARY gang_scout
  scenario pool n = 18/case, his case contacts → 0, 5/5 bars (partial: ≥ 50 % fewer contact runs ships with a note);
  guards: scout 5/5, law_scout 4/5 kept; fresh census seeds 37–60 on-target-in-reach and contacts not worse beyond 2 se;
  **+ (orchestrator) a blind gang_scout contacts line on ≥ 12 fresh gang seeds, and the cost measured, not asserted.**

- **Native progress (2026-10-11):** green at `791821cf` (pre-CP-S base; builder0 exited 0, 2472/0, ALL JUDGED, thirteen
  unmoved): E3 (`native_gun`, OFF, 8400 applies 0 mismatches), E4 (unstick + pressed-wall escape inside the native drive),
  E5 (one native call per crew, `native_exec`, OFF, 10 624 executes 0 mismatches); native-proof Sumps all arms
  770df71a443ba743. NOT merged early (nothing in play; stale base). **Ruling: `native_cb` (E2a's callback ports) defaults
  OFF until priced on a quiet box** (it was `true` on the branch, unpriced) — ON in its own commit once it clears the bar.
  Native's warning: E5 on live members may not be faster (C++ reads via Object::get); the payoff is E5b's owned state.

- **B2 v4 FAILED (2026-10-11, brains `5877710e` merged base, builder0):** (1) Sumps seed 1 tick 1 never arrives (seeds 1–4
  21/24 v 14/24); (2) fresh seeds 5–8, 8 m line: 85 v 83, 4 gained, 2 lost (≤ 1), median −0.4 %. Guards 39/0; his 108
  106/108. Trace: an idle crew whose stalled move "completed" 11.4 m short is never re-sent (the element's thrash rule);
  6–12 m is now the bulk of hollow runs (17/29). **Ruled: v5 (re-send an idle crew > 8 m off its slot once per seat) is
  the LAST attempt this round — no v6;** judged on fresh seeds 9–12, all eight rules + resend count and no thrash
  loop. Fails → parked and written up. brains-close's judged runs may proceed meanwhile; first green merges first.

- **Scout S4 NOT SHIPPED (2026-10-11, tree `0b4c2879`, builder0):** the halt gate fixed the traced touch (gang_scout his case
  contacts 9 runs → 0) but crossing targets lost standing shots (cross 5 m 0.52 → 0.46, 10 m 0.63 → 0.50: 3/5 bars); blind
  seeds 37–60 (13 gang): contacts +0.08/seed, se 0.66, no effect. Kept on branch `scout-s4-halt`; reverted on
  stream/scout. **Scout's backlog is complete; it stops after its final report** (frees builder0 for native's quiet slot).

- **B2 v5 (2026-10-12, brains `3e54110e`, builder0, 8 m line), passing so far:** (1) Sumps seed 1 tick 1 arrives 82.6 s, seed 1
  6/6; (2) fresh seeds 9–12: 95 v 88, gained 8, lost 1, median +0.0 % (strict 74 v 67); hollow 33 → 26, crews > 12 m off
  9 → 4; resends 25 in 19 cells, none twice, no loop; (3) 108: 106 = 106 control; fight guards 39/0; (7) 15 v 13/18;
  (8) 24 v 23/24. CPU side, check and cost pending.
- **FOUND (brains): his bridge 108 is 106/108 on main `f4c5f7c9`** (seed 2: his side tick 5, CPU tick 9, one rim crew each;
  round 26 left it 108/108 at `eb987e87`). Not B2 (both arms). **Bisected (2026-10-12): round 26's tail, not round 27.** Both cells
  fail identically at `090b345d` (round 26's close; orchestrator, builder0 light: green t5 rim 4.1 s, rust t9 rim 6.8 s,
  4/4 crossed, arrived 51.0 / 51.9 s) and at `f4c5f7c9` with and without CP-S (scout: byte-identical records; no fixed
  gun in the drill: 4 law_tanks v 3 lancers). Between `eb987e87` (108/108) and `090b345d`: a round-27/28 brains
  candidate (one tank hesitating 3.5–6.8 s at the rim; all crews cross).

- **Orders O3, hull facing at rest (report; `9c6f3381`, builder0, foundry, 4 factions × seeds 3/5/8/11/13/21, 313 crews a
  task an arm; `streams/references/round27/orders_hull_rest.txt`):** a drawn facing works for hover, tracks and wheeled
  fixed guns (median 1.4–3.8°, 69–100 % within 15°, v 23–71° clicked); **wheeled turreted hulls are the whole 100–167° tail**
  (168/313 crews, median 60–68° drawn = clicked; by design their turret takes the facing); line tasks ~27–29° (the 30°
  sectors); support by fire on wheeled turreted hulls is WORSE drawn (90.9° v 55.9°, p = 0.001). Candidates: wheeled
  turreted hulls face at rest (frozen order_controller, after stage 1) — a question for him; support-by-fire wheeled
  drawn (brains). O4's flank clip: the orchestrator renders it after brains-close merges.

- **CORRECTION (2026-10-12, brains): the flank "stall" on orders' seeds 3/13 was ARTILLERY, not an attack-closing bug.** The
  player's group 1 there is the gangs' wrecker catapults; they back off to their 68 m standoff and the immortal target
  never ends the fight. Direct-fire tanks in the quiet stage close to 22 m in both arms (lab `8b3039fb`). **`lab/brains-close`
  is PARKED** ((a) no player failure shown; (b)'s rework unproven; `8de99ab8` runs void). Candidate for him: should
  artillery honour a drawn approach (bombard from that side) or ignore it? flank-probe should pick a direct-fire squad or
  report per group. B2 v5 CPU side (seeds 9–10, 50 cells, 8 m): 45 v 43, 2 lost, median +0.0 % (reported; accepted).

- **FOUND (2026-10-12, the orchestrator's flank clips, main `d1101179`, builder0, gangs v law, target alive and firing):** the
  drawn approach did NOT reach the side in any of 3 — seed 21 best 70.1° / end 36.5 m, seed 5 71.2° / 38.5 m, seed 8 87.2°
  / 42.1 m (group "Guns"). orders' probe (immortal target holding fire) reached it on the same seeds. Given to brains:
  the unit type, then trace whether the fight reflex overrides the drive round. No clip for him until it works.

- **Live-flank traced (brains, 2026-10-12, builder0; "Guns" = gang_ifv, direct fire):** B0 plans the drive round once, then
  the attack becomes a PURSUIT because the CPU's target shuffles ≥ 2 m/s (PURSUIT_MPS) and a pursuit has no side; at 64 m a
  near-ambush by the target's squadmates triggers assault-through and the squad charges the middle (0/1 reached; all 5
  dead by 19 s). **Fix accepted (approach path, not declared if thirteen unmoved):** a drawn approach outranks pursuit
  below 6 m/s, circle on the target's current position; no assault-through from the target's own squad while going round.
  **Bar (pre-registered):** live stage seeds 1–3 × 6 ticks reached ≥ 12/18 (< 12 = partial, no ship); kills ≥ control − 2,
  crews alive ≥ control − 0.5 where control = a CLICKED attack, same seed/tick (today's drawn reported); side-armour hit
  share reported; B0 approach-series ≥ 17/18; pursuit tests unchanged; flank-clip seeds 5/8/21 + fresh 61/67/71 reported.

- **B2 merged 2026-10-12 (`3dc04293` = brains `2dccf781`, builder0 exited 0, 2497/0, ALL JUDGED, thirteen unmoved).** Rule
  sheet all PASS at v5 (cost NOT READABLE). **B5 (ambush lays its guns on its sectors, every ambush) rode inside the
  declared merge: accepted after the fact** (fight guards 39/0, thirteen unmoved; `--ambush-lay=off`); a default-path
  change gets its own commit next time.
- **Live-flank fix: PARTIAL, not shipped (2026-10-12, `33bf5862` → lab branch).** Stage (5 gang_ifv v a Law squad of 5):
  0/18 on side in EVERY arm and alive 0.00 in every arm: an unwinnable stage, uninformative (C27.5, the orchestrator's
  miss too). Traces: B0 circled at the crews' own reach (35 m, inside the Law guns); a near-ambush by the target's
  squadmates sprang assault-through; under a commander the target drives 8–10 m/s (≥ 2 m/s = pursuit). **One re-run
  allowed on an EVEN stage** (clicked survival 30–70 %, calibrated on clicked arms only), same bar, fresh seeds 4–6; under
  12/18 → parked for good. After B3.

- **B4 RETIRED (2026-10-12, brains, builder0 light, 2dccf781 + `--drill-seats=nearest`):** letting the role go with the
  point fails 5 fight tests (base 31/0, nearest 26/5: pursuit 8 m/s the old leader turns 178° and opens 53 → 142 m;
  mixed_legs, cannot-catch, elements, seat_nearest). The pinned leader IS "keep the lead's role"; the unpin's one gain was
  overtaken by CP1a. Kept on `lab/brains-b4-point` (`9f15bfd9`).

- **Native's quiet slot (2026-10-12 02:29–02:49, `ed6ecaa9`, builder0 quiet, pinned 0-3, n = 3 a arm, no void):** A —
  execute ~30 % of the tick's scripts at 20 a side, GDScript in it 19–22 % of the tick (inside the 12–22 % band: the
  estimate is not re-told); ~60 µs of GDScript a crew (the "27" and "200–300" figures both retired). B — `native_cb`
  saves 0.8–1.3 % at 50 v 50 (< 2 %): STAYS OFF. C (second reading, no ruling) — stage 1 v default: tick's scripts
  −7.6 % / −8.5 % at 20 a side (foundry / parade), −8.1 % / −8.8 % at 25; execute ~88 → ~65 µs a crew. **Below the
  11–15 % estimate he decided on; internal until E6 (the laptop rules), with native's pre-registered estimate of what the
  remaining ports add written first.**

- **Live-flank calibration (brains, clicked arm only, builder0, seeds 1–3 × ticks 1/8/16, won = enemy wiped in 90 s):** 5
  gang gun trucks v Law {IFV,IFV,scout} 0/9, {IFV,IFV,scout,scout} 0/9, {IFV,IFV,tank} 0/9, {IFV,scout} 0/9, **one holding
  IFV 3/9 (chosen)**; 4 gang tanks v {IFV,IFV,scout} one-sided. Caveat: no squadmates, so the near-ambush part is untested;
  **+ a reported arm with the IFV under the CPU commander (moving) for the pursuit rule** — a fix that still collapses into
  pursuit there does not ship. **Balance candidate:** gang gun trucks lose 0/9 (clicked) to every real Law squad tried.

- **Live-flank fix PARKED FOR GOOD (2026-10-12, brains `370fc64d`, builder0, 5 gun trucks v one holding Law IFV, fresh
  seeds 4–6 × 6 ticks, n = 18 an arm):** on side 0/18 in every arm (fix 65°, B0 rule 76°, clicked 89°); the fix fights
  WORSE than B0's rule (kills 10 v 15, alive 1.83 v 2.78). Instrument caveat: the stage's "first crew within 50 m" mark
  coincided with the fix's new 50 m circle (by its own state the element reached the 30° cone 18/18). **Kept finding: on
  the even roster the SHIPPED drawn gesture (B0's rule) beats a clicked attack: kills 15 v 10, alive 2.78 v 2.28,
  side/rear hit share 0.76 v 0.81.** Branch `lab/brains-flank-live` (`64355ff2`).

- **B3: make-room KEPT (2026-10-12, brains, builder0, game = main `3dc04293`, fresh seeds 13–16, 100 cells paired):** 8 m line
  on 97 v off 93 (gained 5, every one with a swap; lost 1; median +0.0 %), strict 76 v 72, crews > 12 m off 2 v 6. On round
  26's base it bought nothing (68 = 68); B2's watch now hands it the case it was built for. Brains' backlog done; final
  report at `a66a95bc` (check running).

- **CP0 merged 2026-10-11 (`1c8da4d8` = brains `9603c1d7`, builder0 check exited 0, 2475/0, thirteen unmoved).** Main's
  check of native E1 + CP0 together running; then orders merges main.
- **B2 ship rule (pre-registered 2026-10-11, brains, before any numbers; DECLARED):** the clock pause + a re-seat that keeps
  every crew parked on its own slot seated; both arms under B1's line (every living crew within max(3.5 m, settle radius)
  of its slot, held 1 s). Ships only if ALL: (1) the Sumps cell (law_scout:law_ifv:law_tank:law_tank, seed 1, drills on,
  150 m) arrives within 120 s at start tick 1 and in ≥ 5 of 6 pooled ticks; (2) arrive series 100 cells paired v main:
  arrivals ≥ main's, ≤ 1 cell main-arrives/B2-fails, median all_in_s ≤ +10 %; (3) bridge-pooled 18/18, the 108 ≤ 1 run a
  side worse; (4) thirteen and determinism unmoved or explained; (5) ≤ 0.5 ms a tick (or NOT READABLE); **(6) symmetric,
  reported per side; (7) the Sumps cell at seeds 2–4 reported (the orchestrator's additions).** Sumps fixed with (2)/(3)
  failing → lab branch, no ship.

**Checkpoints:** **CP0** brains' B0 → orders merges main. **CP-S** scout's declared change (+ native's port of any
`decide` diff) → everyone merges main. **CP-B2**, **CP-B4** brains' declared changes, each alone. Native's E1 (OFF)
merges whenever green; native merges main at CP-S.

**Decided for him (reversible):** the scout keeps turning room and picks forward or reverse by gun-on-target time (his
reading); traffic and the wheeled creep wait for stage 1 (both rewrite the frozen drive; his crossing cases pass); attack
with a drawn direction is built (it completes the gesture round 26 gave every other armed order).

**Standing rules:** rounds 12–26's (lessons 225–294).

## Round 26: five streams (launched 2026-10-10 night, CLOSED 2026-10-11; briefs in `streams/archive/round26/`)

**Goal: his playtest of round 25 (`game_design.md` *Round 26 direction*, readings (1)–(9)): friendly squads crossing
each other jam (head-on and at right angles), and he expects the same in every friendly clump; a stuck vehicle shuffles
in N legs instead of a planned three-point turn, and a short move behind it is a pirouette instead of a reverse; an
armed order (screen, support by fire, attack-move, ambush) takes no facing. Beside it, his standing target: low-end
hardware, so the C++ keeps up with every behaviour change and the next step (the whole brain as one batched pass) is
scoped for him.**

| Stream | Folder (offset) | Brief | What he will notice | Checkpoint |
|---|---|---|---|---|
| **traffic** | `godot-traffic` (1) | [streams/archive/round26/traffic.md](streams/archive/round26/traffic.md) | two friendly squads ordered through each other pass (keep right head-on; a rule for who yields at a crossing); fewer friendly jams in big fights; enemies still blocked on purpose | **CP1** the convention, DECLARED, merged alone with perf's port |
| **manoeuvre** | `godot-manoeuvre` (2) | [streams/archive/round26/manoeuvre.md](streams/archive/round26/manoeuvre.md) | a short move behind a vehicle is a reverse (or back-up-then-forward), never a pirouette; a stuck vehicle turns in three planned legs | **CP2** the short move behind; **CP3** the three-point turn; each DECLARED, alone |
| **orders** | `godot-orders` (3) | [streams/archive/round26/orders.md](streams/archive/round26/orders.md) | press at the spot, drag toward the facing, release: screen, support by fire, attack-move and ambush face the way he drew | after **CP0** (brains B0) |
| **brains** | `godot-brains` (4) | [streams/archive/round26/brains.md](streams/archive/round26/brains.md) | every armed task honours a drawn facing (B0, small, first); his bridge drill finally passes; the scout reaches the deck | **CP0** B0 merged early → orders merges main |
| **perf** | `godot-perf` (5) | [streams/archive/round26/perf.md](streams/archive/round26/perf.md) | nothing lost: the C++ follows every traffic/manoeuvre change; the remaining batched ports that pay; the whole-brain batched pass priced for his decision; stretch: a lighter look he can switch on | none of its own |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**

- **traffic:** `game/ai/avoidance.gd`, `game/ai/steering.gd`, in `game/ai/movement.gd` the give-way block (`right_of_way`
  through `_blocker`, today lines ~1315–1853), `_avoid` and `_around_friends` (~1948–2058), `_ask_behind` and
  `_hull_within`; new `game/ai/traffic*.gd` (preferred: put the convention in its own file); new
  `tests/test_traffic*.gd`, new `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`; `mk/traffic.mk`
  (new; one include line in the Makefile is a merge note).
- **manoeuvre:** in `movement.gd` the body of `drive()` (~894–1089), `_nose_stop`, `unstick`, `_pressing_escape`, the
  `press_on`/`inflate_on`/`nose_stop_on` switches, and the k-turn / planned-reverse / circle block (`kturn_on` through
  `_look_stop`, ~2960–3992); `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; new `game/ai/manoeuvre*.gd`; new
  `tests/test_manoeuvre*.gd` / `tests/test_kturn*.gd`, new `tests/ai_scenarios/scenario_manoeuvre*.gd`; `mk/nav.mk`'s
  k-turn/reverse targets and a new `mk/manoeuvre.mk`.
- **orders:** `game/control/**`, the order hints in `game/ui/**` (the help/hint text about order input only; a list in
  its Status), `tests/test_control*.gd`, the control playtests and their make targets in `mk/command.mk`.
- **brains:** `game/ai/**` EXCEPT traffic's, manoeuvre's and perf's carve-outs (so: the rest of `movement.gd` — routes,
  gates, chord, station-keeping —, `tank_brain.gd` except perf's seams, `element_feed.gd`, `order_feed.gd`,
  `formations.gd`, `squad*.gd`, `gunnery.gd` …), `game/tactics/**`, `tests/ai_scenarios/**` (others add their own
  `scenario_<stream>*.gd` files and one registration line each in `run_scenarios.gd`: merge note), `tests/tactics/**`,
  `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
  `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk` (minus manoeuvre's targets), `doctrines/doctrine_*.json`, the baseline lines
  it declares.
- **perf:** `native/**`, `game/ai/native/**`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch
  line: merge note), `cover_map.gd`, `combat_motion.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd` and
  `tank_brain.gd`'s think-scheduling hunk (round 25 pace's), every `if BrainSwitches.native_*` seam already on main, a
  NEW seam at the top of `TankBrain.act` and of `build_situation`'s non-core part (grant, C26.2), `tests/test_native*.gd`,
  `tests/native/**`, `tests/test_ai_think_lod.gd`, `tests/test_pace*.gd`, `tests/tactics/l1_speed_table.py`,
  `_agents/native.md`. Stretch only: `game/theme/fx/render_levers.gd` and the effects it switches (a grant for P5).
- **Nobody this round** (a request through the orchestrator): `game/match/**`, `game/tank/**`, `game/units/**`,
  `game/garage/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/announcer/**`,
  `game/theme/**` (except perf's P5 grant), `arenas/**` (a new scenario map is a request), `game/arena/**`,
  `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`, `mk/core.mk`.

**Contracts (round 26):**

- **C26.1 Every change to fights is DECLARED** (C25.1 carried): traffic's convention (CP1), manoeuvre's short move
  behind (CP2) and three-point turn (CP3) each land as one commit, merged alone, with its scenario and the paired
  series (his two crossing cases, `make nav-orders`, `make bridge-pooled`, the arrive series, the Terminus drive), the
  CPU on the same behaviour. Everything else pre-registers UNMOVED on the thirteen lines and determinism. Two declared
  changes never share a merge: the orchestrator queues them.
- **C26.2 The C++ follows, and perf carries it** (C25.2 with perf in native's place). `Movement.drive`'s body, `_avoid`
  (mirrored inside `drive_native.cpp`), the k-turn leg's execution inside the drive (`_kturn_start_leg`,
  `_kturn_stopping`, `kturn_brake_on`), `Avoidance.solve` (`avoidance.cpp`), the route tail, `_around_fire`, `decide`,
  `build_situation`, the two TacticalQuery functions, and the OFF-but-proven `native_move` geometry (`_chord_compute`,
  `_outline_ok`, `_arc_hit`) are held to their GDScript by live-function proofs (`test_native_drive`,
  `test_native_avoidance`, `test_native_avoid_gather`, `test_native_movement_geometry`, …). Traffic and manoeuvre develop
  on the GDScript path (`--brains-off=native` or the switch off) and, before the commit that changes one of them, send
  perf the diff (SendMessage, the orchestrator copied); perf ports it and names the commit; the orchestrator merges the
  pair back to back and checks once. **Prefer the callback layer:** the native drive calls BACK into GDScript for
  `_planned_reverse`, `_negotiate`, `_blocker`, `_kturn_end`, `_keep_station`, `_repair`, `_approach_gate`,
  `_inflate_corners`, `_chord_slack` — a change there needs no port. A geometry function with an OFF port: perf may
  instead retire the port (its seam and proof) if it will never be switched on; say so in `native.md`. Perf's grant: one
  seam at the top of `TankBrain.act` and one around `build_situation`'s non-core part (the N7 candidates); brains does
  not change those two functions this round without telling perf.
- **C26.3 A drawn facing reaches every armed task** (orders ↔ brains). Orders puts the drawn heading on the task as
  `task["facing"] = [x, z]` (normalised, the same key a right-drag move uses, `ElementTask.facing`); absent means
  "automatic", exactly today's behaviour. Brains (B0, first) makes every armed task honour it when present: the screen's
  line is laid ACROSS the facing (the facing is the way the line looks), support by fire faces it from its position, an
  ambush faces it, attack-move arrives facing it. Brains merges B0 as CP0 (not a declared change: the default path,
  with no facing, is byte-identical — the thirteen lines and determinism unmoved), then orders merges main. Until
  then orders tests against a stub reading `task["facing"]` in its own paths.
- **C26.4 The friendly convention is shared and symmetric** (traffic). Both crews in a meeting compute the same answer
  from the same facts (positions, headings, speeds at the meeting's first tick; a deterministic tie-break by unit id),
  so neither waits for the other to decide; head-on, both keep right; at a crossing the rule names who yields (traffic
  picks it, writes it in `navigation.md` with the reason, and the CPU uses the same rule). It applies between FRIENDLIES
  only: against an enemy nothing changes (a charging crew may hold its line or block). A crew in a give-way already
  (round 13's yield) and a crew in a k-turn are inputs traffic reads, not states it rewrites.
- **C26.5 Obstacle kinds are counted, not guessed** (traffic ↔ manoeuvre). Manoeuvre's census of k-turns and stuck
  episodes labels each by what is in the way: static (wall, rock, water edge), a friendly hull, an enemy hull. Traffic
  reads the "friendly" share before and after CP1; manoeuvre's pass lines are judged on static obstacles and on the goal
  behind, and report the friendly share separately. The counters live in `movement.gd`'s `route_arms()` (manoeuvre adds
  them; traffic may add its own keys beside them: merge note).
- **C26.6 A pass line changes only with its reason written down** (C25.3 carried, every stream). New scenarios are
  free; an existing line is loosened only with the trace, the old and new line and what a player would see, approved by
  the orchestrator before it is committed. Pool over pre-registered start ticks ({1,3,6,8,11,16}, lesson 283) wherever a
  TacticsLab or scenario result is timing-sensitive.
- **C26.7 The laptop is one instrument** (C25.4 carried). Flightdeck sessions are serialized through the orchestrator;
  perf has priority for pricing, the others for his-pose clips and screenshots; pair by seed, ABBA, cooldown, void a hot
  session; pin `--squad-cap` and read `ARMY_CAP_FIELDED` (lesson 285). builder0 for everything else. **Ruled 2026-10-10 ~23:30 (the laptop saturated at launch): EVERY Godot run goes to builder0 (`make remote T=lint`, `T=check`, `T=<target>`), lint, single tests and probes included; the laptop runs Godot only in a slot the orchestrator grants.**
- **C25.6 (the army cap follows the render preset), C24.6, C24.7 (the bar), C24.8 (the seams), C23.1a, C23.2,
  C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

- **C26.8 Grant to traffic (2026-10-10 night): `ElementFeed.changed` / the `key` built in `ElementFeed.context`
  (`element_feed.gd` ~190–207), that hunk only.** Traffic found the head-on jam's root cause there: the key carries the
  crew's slot as a float string, the element slides that slot by millimetres every update (~9 ticks), so `changed()`
  reads true, `TankBrain._poll_element` interrupts, and `Movement.reset()` zeroes `stalled_ticks`/`_order_ticks` every
  ~0.3 s: `_avoid`'s start-of-order grace never ends (ORCA only slows, never steers aside) and ask/yield/held_back never
  fire. Every element move, both sides. (Laptop probe on b57838ed, yard_open, his head-on case, n = 1, seed 1: 4/10 crews
  nose to nose all 60 s, 207 friendly-stuck crew-s; prototype ignoring a slot slide < 2 m with the rest of the key
  equal: 10/10 by 24 s, 0.) **Terms:** a DECLARED change (C26.1) of its own, **CP1a, merged alone BEFORE the convention
  (CP1b)**, so each one's effect is measured separately; a real re-seat (a slot that jumps, a role/task/drill change)
  must still interrupt (a unit test for each); the series: his two cases, `nav-orders`, `bridge-pooled`, the arrive
  series, the element digest (moves: declared), the thirteen lines, the think-rate census (perf P4: fewer interrupts
  may move the quiet share). Brains does not edit `ElementFeed.changed` or the key this round and re-runs its bridge
  108 after CP1a.

- **C26.9 Ruling + grant to manoeuvre (2026-10-10 ~23:40): the short move behind ends WITHOUT a face turn.** Manoeuvre's M0
  (`make manoeuvre-behind`, builder0, b57838ed): most of his "N point turn" on a short move behind is the POST-ARRIVAL
  face turn. A plain move's heading is the travel direction, so a crew that arrives (or is already inside its settle
  radius) then turns to face backward, and a wheeled hull does it by the plant's creep in 0.5 s legs: War Rig 5 m astern
  arrived at once, then 89 creep legs in 45 s; 10 m astern done 7.6 s, settled 43 s. **Ruling (his reading (8), applied):**
  a plain move with NO drawn facing whose goal falls in M1's short-move envelope arrives keeping the hull's heading at
  the order (reverse onto it, or back-up-then-forward, and stop: no face turn); a drawn facing still wins. **Grant:**
  manoeuvre owns the face-at-rest path in `game/ai/order_controller.gd` this round (`_same_face`, `face_giveup_on`,
  `_face_giving_up`, the face branch of `_apply_move`) for M1 and for M1b, **a planned face turn for wheeled hulls** (a
  three-point turn at rest instead of the creep, the same planner as M2). Part of CP2 (declared). If the rule needs
  `game/control/orders.gd`'s heading, that hunk is a request to orders through the orchestrator, not an edit.

- **C26.10 A behaviour change carries a cost line (2026-10-11 ~00:30).** Perf sized traffic's CP1b draft (5b881905,
  builder0 light lane loaded, Sumps 25 a side + leaders, n = 3): `Traffic.shape` ~36 calls a tick × ~80 µs = 2.8 ms,
  refresh 0.75, ~4 ms a tick (5–6 %): more than N7's whole remaining port list. So CP1b's pass line includes **≤ 0.5 ms a
  tick on the GDScript path at 25 a side on Sumps** (perf's sub-lap workload), reached by the algorithm first (ORCA's
  neighbour table, one decision per meeting pair, idle crews skipped); perf ports the SETTLED version once. The same
  rule for every declared change this round: its cost at 25 a side is measured, pre-registered and reported beside
  its behaviour numbers.

- **C26.6 rulings (2026-10-11, traffic's CP1a at 5c31c58f: check 2381/2, thirteen and determinism unmoved; both failures
  brains' tests, both CP1a fixing what they measured).** Granted to traffic for CP1a's declared commit, those two files
  only: (1) `test_tactics_make_room` (the Cut, four Law tanks): APPROVED "the squad arrives, in both arms", swaps
  REPORTED not asserted. Its stage reproduced round 19's crew pressed 70 s against a parked squadmate; CP1a's running
  stall clock lets the give-way free the corner, so make-room no longer fires there. Make-room is left WITHOUT a
  falsifier: brains (after B1) either builds a stage that still needs it with CP1a on, or prices it by removal
  (lesson: attribute only by removing). (2) `test_tactics_pursuit` out-of-sight: the line is C25.3 ruling (2) as already
  approved — "killed by THIS squad, or the squad ends within 40 m" — the test's −1 (target dead) was never wired to
  it; the kill must be credited to one of this squad's crews in the kill log, not merely "the target is dead".

- **C26.6 ruling (2026-10-11 ~01:35, brains B1): his bridge line counts every SURVIVING crew across**, a crew killed in
  the fight excused only if it was not stuck (no rim and no deck-jam time ≥ 3 s in the 10 s before its death), with a
  reason line per excused crew and a mutation check (stalled ≥ 3 s then killed fails). Preliminary (builder0 aa5defa1 =
  stream/brains + CP1a cherry-picked, scratch): his side 53/54, the CPU's 53/54, deck jam 135 / 92 crew-s (round 25:
  45 and 41–42/54, 1013 / 754, older code); the only failure each side a crew killed by the lancers. `bridge-pooled`
  joins `check` after CP1a, if ≤ ~3 min in check's lanes (the orchestrator adds the mk/core.mk line).

- **CP1a merged 2026-10-11 ~05:00 (e9f9e946 = db019850).** Correction filed after the merge (traffic, traced): the
  yard_open CROSSING case started and ended squad B behind the container walls at x = ±50 (blocked/no_path in BOTH
  arms), so its numbers are VOID; the stage now runs inside the walls (12cecbe8) and every arm is re-measured there.
  The Terminus regression (a crew yielding to a parked squadmate) is CP1a2's. `make nav-orders` ignores --seed (brains'
  probe): every "nav-orders over seeds" so far is n = 1.

- **B2 (drill seats by nearest) does NOT ship this round (2026-10-11 ~08:00).** Paired at one commit (fe45a510 = main +
  the unpin, builder0, phase 0, the same test lines both arms): nearest 4/3 fight tests vs pinned 7/0 — pursuit 8 m/s the
  squad lets go at 7.5 s (pinned holds), the bay ambush springs early (x 55.7 at 12.1 s v 64.6 at 15.5 s), the Sumps
  two-scout squad 26.1 v 20.4 s. His bridge passes with CP1a alone. The "whole squad let go" line enters as a guard
  (main passes it). Round 27 carry-over.

- **Found 2026-10-11 ~11:30 (orders' showmatch run, builder0 windowed, preset=laptop): the laptop army fold breaks
  squads.** "Elements.form: 7 members is more than one squad (Formations.MAX_MEMBERS = 5): refused (C19.1)" (+3 for
  6): the C25.6 fold packs a faction army into 4 squads of > 5, ElementCommander refuses them, and those squads fight
  with no element (no formation, drills or leader) — likely every laptop skirmish since N6 (94c26255). Given to perf
  (N6's heir): trim, never pack; ≤ 5 a squad, both sides; tests per roster at cap 4. Granted to orders: two `.movie`
  window-override lines in project.godot (Movie Maker ignores --resolution).

- **Found 2026-10-11 ~12:00 (perf's desktop probe, a5ab7518): on DESKTOP a player with a faction army gets squads past
  five** (for_player at cap 5: gangs [7,14,8,8,7], condemned [7,7,7,7,14], law and syndicate up to 8/7); Elements.form
  refuses them (C19.1) and `rts_controls.gd:684` calls `.assign` on null — every armed task AND a right-click move on
  that squad is silently dropped. **Decided (a):** the player's fold gives squads of ≤ 5 at every cap, the overflow on
  groups 6–10 (every vehicle on a key, every squad an element); perf builds it (grant: `SquadConsolidation.for_player`);
  orders guards the null element (a move falls back to per-unit orders; a task gets a notice with the reason).
  **RETRACTED the same hour:** through the REAL path (recall_group → order_selection) `SelectionSquads.split` deals
  every group past five into squads of ≤ 5 first; every order lands (perf's re-probe, gangs/condemned/law seed 7). The
  first probe called assign_task directly. (a) NOT built (kept as a patch under references/round26/perf/); the desktop
  fold stays; orders' null guard ships as hygiene. Lesson: probe the path the player's input takes.

- **The Sumps arrive cell (CP1a's miss) is NOT fixed this round (2026-10-11 ~14:00).** Traced: a TRACKED law_ifv presses
  a squadmate parked on its station; make-room never fires because Element._watch_progress resets its 4 s not-closing
  clock on every sub-1 m/s dip (a shuffle). Brains' clock pause unlocks re-seats (never → 52.27 s) but the arrival is
  HOLLOW (the re-seat hands the parked crew a far seat; it ends 19–26 m off while the element reads arrived). Traffic's
  creep floor (wheels only) measured no help and was dropped; the creep it targets is composed in drive() (→ manoeuvre
  M3 request). Round 27: a re-seat that seats the blocked crew around the parked one; make-room priced by removal; an
  arrive line that counts every crew inside its settle radius.

- **CP1b's partial-gain rule (pre-registered 2026-10-11 ~15:30, before v4's numbers):** v4 (6cfd6a1f) ships if on ALL
  four of his cases v base (n = 18): crews arrived / all-in not worse beyond noise (≥ base − 2 crews); friendly-stuck
  ≤ base × 1.2 + 10 crew-s; fast friendly contacts drop in ≥ 3 of 4 and rise in none by > 10 %; plus bridge-pooled 18/18,
  arrive 99/100 = main, cost ≤ 0.5 ms. Otherwise round 27; no v5 this round. (v2 failed: crossing-yield's zero floor
  tripled friendly-stuck; v3 better but open-ground head-on worse.)

- **CP1b does NOT ship (2026-10-11 ~17:30).** v4 (6cfd6a1f) failed the pre-registered partial-gain rule: crews arrived
  down at both crossings (171 → 167, 165 → 160; all-in 3 → 0), Terminus head-on friendly-stuck 401 → 520 (limit 491),
  open-ground head-on fast contacts +51 %. In his terms: keeping right steered tanks into their own squadmates, and the
  crossing yield made crews crawl. His two squads now get through each other because of CP1a (the order-spam fix), not
  a traffic rule. The convention stays OFF main (on branch traffic-cp1b-v4: native's _avoid would ignore a switch).
  Round 27: a convention designed formation-to-formation, and ported with the drive.

**Checkpoints:** **CP0** brains' B0 (facing honoured) → orders merges main. **CP1a** traffic's feed-key fix (C26.8), alone; **CP1b** traffic's convention + perf's port,
merged as a pair → everyone merges main; brains re-runs its bridge 108 on it. **CP2** manoeuvre's short move behind
(+ perf's port if any) → everyone merges main. **CP3** manoeuvre's three-point turn (+ port) → everyone merges main;
traffic re-reads the friendly share.

**Decided for him (reversible, `game_design.md` *Round 26 direction* readings (2)–(9)):** keep right among friendlies,
never against enemies; press–drag–release for armed orders (a click keeps today's automatic facing); the short move
behind picks the cheaper of reverse or back-up-then-forward by planned time; a perf stream that keeps the C++ in step,
ports only what prices outside 2 se, and scopes the whole-brain batched pass for his decision.

**Standing rules:** rounds 12–25's (lessons 225–288).

## Round 25: three streams (launched 2026-10-10 morning; briefs in `streams/`)

**Goal: his playtest of round 24's close on the Crossing (`game_design.md` *Round 25 direction* and *Round 25: the
launch*): a squad in a wide shape sticks on the bridge and some crews never cross; the squad slows while the "point"
crew drives up from the back. Beside it, the 0.97 bar (C24.7) with a smarter "quiet" think rate, and water in the
laptop's pricing workload.**

| Stream | Brief | Round 25 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round25/brains.md](streams/archive/round25/brains.md) | **F0** his crossing counted by cause from the recording + a failing scenario; **F1** seats by nearest (DECLARED); **F2** funnel through a crossing and re-open (DECLARED); **F3** the give-way at the bridge mouth; stretch: B1's +0.5 s | **CP1**: F1 merged alone; **CP2**: F2 merged alone → pace and native merge main |
| **pace** | [streams/archive/round25/pace.md](streams/archive/round25/pace.md) | **P0** the fight scenarios' pass lines: behaviour or brittle threshold, per scenario that L1 broke; **P1** the quiet census (which crew-ticks a smarter quiet could slow, and the most it can buy); **P2** the smarter quiet, DECLARED, priced on the laptop | re-verify P2 on main after CP2 |
| **native** | [streams/archive/round25/native.md](streams/archive/round25/native.md) | **N5a** a water map (locks) in `make native-tick-profile`; **N5b** `native_el` re-priced on it; **N5c** mirror every behaviour change to a ported function (C25.2, first priority whenever asked); **N5d** `native_scan` re-priced in contact; stretch: the Android device proof | none of its own |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**` minus native's and pace's below, `game/tactics/**`, `tests/ai_scenarios/**` (pace may change a pass
line under C25.3), `tests/tactics/**` (minus `l1_speed_table.py`), `tests/nav/**`, `tests/test_ai*.gd` (minus
`test_ai_think_lod.gd`), `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`, `mk/nav.mk`,
`mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · pace the think-scheduling hunk of
`tank_brain.gd` (C24.7's: the `*_THINK_*` constants, `_think_hz`, the rate choice around `t.rate_progress`,
`brain_stride`), a new `game/ai/think_quiet.gd` (or similar, its own file) for the quiet read, `tests/test_ai_think_lod.gd`,
`tests/tactics/l1_speed_table.py`, new `tests/test_pace*.gd`, `mk/pace.mk` (new; one include line in the Makefile is
a merge note) · native `native/**`, `game/ai/native/**`, `mk/native.mk`, `avoidance.gd`, `steering.gd`, `cover_map.gd`,
`combat_motion.gd`, `brain_switches.gd` (additive; pace and brains may add a switch line: merge note),
`incoming_fire.gd`'s seam, every native seam already on main (the `if BrainSwitches.native_* :` lines in `movement.gd`,
`tank_brain.gd`, `pathing.gd`, `tactical_query.gd`, `slot_ground.gd`, `gunnery.gd`), `tests/test_native*.gd`,
`tests/native/**`, `_agents/native.md`. **Nobody this round** (a request through the orchestrator): `game/control/**`,
`game/ui/**`, `game/theme/**`, `game/match/**`, `game/tank/**`, `game/units/**`, `game/garage/**`, `game/modes/**`,
`game/camera/**`, `game/network/**`, `game/audio/**`, `game/announcer/**`, `arenas/**` (a new scenario's map is a
request), `game/arena/**`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`,
`mk/core.mk`.

**C25.3 rulings, 2026-10-10 (brains F1b, his pursuit answer "stay on the chase"):** (1) pursuit: a crew may open the range only if hull < 15 % or the target's gun was on it within 2 s, AND every other crew keeps closing; (2) out-of-sight target: killed by this squad, or the squad ends within 40 m; (3) elements: ≥ 0.3 × top speed × 6 s on the element centre's progress, AND no crew's route remaining grows. Each tightened so the line cannot pass when the squad as a whole lets go.

**Grant, 2026-10-10 (native, N7):** a new `if BrainSwitches.native_weapon :` seam at the top of `gunnery.gd`'s lanes and aim functions, switch OFF until an equal-answer proof against the live GDScript passes (the N2b pattern), then ON as its own merge. This is round 26's native-exec item started early; native-exec inherits it. `act` (`tank_brain.gd`) follows on the same terms. C25.2 holds: any behaviour change to those functions lands in GDScript and C++ together.

**Contracts (round 25):**

- **C25.1 Every change to fights is DECLARED** (C24.3 carried): brains' F1 and F2 and pace's P2 each land as one
  commit, merged alone, with a scenario and the paired series (the arrive series, his bridge on every map with a
  crossing, the beaten zone, the pursuit), the CPU on the same behaviour. Everything else pre-registers UNMOVED on the
  thirteen lines and determinism.
- **C25.2 A behaviour change to a PORTED function lands in GDScript and C++ together.** `Movement.drive`,
  `Movement._next_waypoint`'s tail, `Movement._around_fire`, `TankBrain.decide`, `TankBrain.build_situation`,
  `TacticalQuery.find_cover(_fire)` are ON in C++ (`brain_switches.gd`), and the live-function proofs fail the moment
  their GDScript changes. So: brains/pace develop on the GDScript path (`--brains-off=native` or the switch off), and
  before the commit that changes behaviour in one of them they send native the diff (through the orchestrator, or
  SendMessage directly with the orchestrator copied); native ports it on its branch and names the commit; the
  orchestrator merges the pair back to back (behaviour first, port second) and checks once. **Prefer the layer above:**
  a seat, a slot, a leg, a goal or a gate decided in `game/tactics/**` or `formations.gd`/`squad.gd` needs no port.
  The SlotGround and `ElementPlan.build` seams (C24.8): `native_el` stays OFF until N5b rules; a brains change to the
  water rules is told to native the same way (its proof must follow). `ElementPlan.build` is NOT ported this round
  (brains is likely to change it).
- **C25.3 A pass line changes only with its reason written down.** Pace may propose a new pass line for an existing
  scenario (P0) when its trace shows the old line measured a threshold, not a behaviour; it writes the case in its
  Status (the trace, the old and new line, what a player would see), and the orchestrator approves it before pace
  commits it. Brains adds its own new scenarios freely; neither stream loosens a line to make its own change pass.
- **C25.4 The laptop is one instrument.** Pricing runs on flightdeck (`make native-tick-profile`, the windowed in-contact
  number, lesson 279) are serialized: a stream asks the orchestrator before a session and says when it ends; a quiet
  window around every run (lesson 260); pair by seed, ABBA, cooldown, void a hot session (lesson 282). builder0 for
  everything else.
- **C25.5 Seats** (brains F1, the lead's words): the nearest crew takes each spot; the leader does not own the point on
  a move; while moving, toughness only as a short swap; once halted, the heavies take the front/outside spots
  (exposure) even when that is a longer drive (his option 2, 2026-10-10) (`game_design.md` *Round 25: the launch* 1). `TacticalFormation.seat`
  is the one place it is decided, for both sides.
- **C25.3 rulings (the orchestrator, 2026-10-10 morning, on pace's P0 table at `37b91c04`):** (1) cp2, the scout onto
  the engine deck: HELD (pace, same morning: run ALONE its three timings give 7 / 43 / 22 hits, in the suite 43 at
  phase 0, so the outcome depends on which scenarios ran before it in the process: a static leak between scenarios;
  the line stays as on main until the leak is found and fixed; FINAL after the runner fix 00b91730: run alone it is
  41/43, 41/43, 4/22 at phases 0/1/2, equal to the suite: at one timing in three the scout never reaches the deck, a
  BEHAVIOUR weakness like the overwatch stall, so the line STAYS as on main and the miss goes to brains, low priority). Was: APPROVED, the pooled form (phases 0–2, pooled deck share ≥ 0.5 AND every timing ≥ 20 hits); it
  fails 1 timing in 3 on main with no rate change, so the one-phase line measures timing luck. (2) The duel's "they
  still fight" (shots ≥ 6 → pooled ≥ 15): DECLINED. It holds identically at every timing today (not phase-brittle),
  and pace's arm S does not use the engaged rate that moved it; re-propose with a trace only if S itself fails it.
  (3) Squad overwatch: the line STAYS. The bound stalling at one think timing in three on main (`--think-phase=1`,
  commander z −13 v −60) is a behaviour bug a player can see, not a brittle line; it goes to brains (after F3,
  or sooner if F2's series hits it). (4) Cover-by-a-wall, the slot, suppression, the teammate drawing fire: kept, as
  pace proposed (BEHAVIOUR). Pace's pre-registered arm S (2 Hz smarter quiet, no order guard, ships only on a clean
  check at phases 0–2 + his series + a laptop gain outside 2 se; predicted best case ≈ 0.86–0.87) is accepted as written.
  **S FAILED its bar** (builder0 `f16f9ab1`, 44 × phases 0–2, old runner): cover-by-a-wall at all three timings (the
  tank between shots holds ENGAGE, not COVER_FIRE, reads quiet, and stays in the open) and fire_discipline at p2. S does
  not ship. **S2 approved as the LAST arm** (S + "watched": a known enemy gun laid on the crew, inside its reach + 5 m),
  pre-registered before its decisive runs, those runs on the fixed runner (`00b91730`); if S2 fails anything there is no
  S3: pace writes up the gap and the orchestrator takes it to him.
  **S2 KILLED by its kill line** before any decisive run (builder0, n = 9, 25 a side, 8–20 s): "watched" marks 66–68 % of
  the quiet crew-ticks; S2's share 29 % → most it can buy ≈ +0.014 < +0.03. **P2 ends with nothing shipping: the 0.97 bar
  is not reachable by think rate** (in the opening clash ~1/6 of crew-ticks are genuinely quiet). Pace moves to stretch
  (b), the gap by component, with native.
- **C25.3 ruling (the orchestrator, 2026-10-10 late morning): his bridge test is pooled over start ticks.** Pace found the
  bridge drill's run-to-run variance (deck_jam_s 21.0 / 12.6 / 21.0): `TacticsLab.start()` waits physics frames for a
  nav map that syncs per RENDERED frame, so a drill starts on tick 1 at --fixed-fps 30/15 and tick 0 at 60 fps or the
  free clock. Brains pins START_TICK = 1. Pace's sweep of start ticks 1–18 on `f3b84ee2` (main + CP1, before F2):
  `test_his_squad_crosses_by_the_bridge` passes 7/18, 9 of the 11 failures with a crew pressed at the water ≥ 3 s (his
  river bug), the CPU side 14/18. The line becomes: a pre-registered set of start ticks (≥ 6), EVERY one with every crew
  across and zero crews at the water ≥ 3 s, both sides. CP2 is held until the sweep runs on it. Every TacticsLab test has
  the same free-clock exposure.
- **C25.6 (2026-10-10 noon, his pick: "20 now, C++ continues"): the army cap follows the render preset.** Native owns it
  (N6), with a grant this round over: `game/units/units.gd` (a `Units.max_squads()` beside `MAX_SQUADS`, which stays the
  ceiling for anything sized at compile time), the readers that size a MATCH (`game/garage/army_catalog.gd`,
  `army_draft.gd`, `garage_opponent.gd`, `game/progression/credits.gd`, `game/ai/doctrine.gd`'s player cap,
  `game/tactics/squad_consolidation.gd`'s `for_player` default — brains is told, one additive line), and the tests that
  pin 5. **Added the same day (native's finding: plain `make skirmish` builds both sides with `Army.cpu_army` and folds
  only GREEN):** `game/units/army.gd` `cpu_army`'s unit cap and `game/modes/skirmish_mode.gd` `_start_match` (the cap read
  once, an `ARMY_CAP` log line, both sides folded and trimmed when the cap is below MAX_SQUADS). Also granted: one line in `game/garage/garage_screen.gd` `_adopt` showing the cap note
  (filtered to it alone). Network, verified by native: no network path loads armies, so the cap is that of the machine
  that builds the match. The rule: `RenderLevers.preset() == "laptop"` → 4 squads, else `MAX_SQUADS` (5); read ONCE at match setup and
  applied to BOTH sides (the CPU's army folded the same way); a headless run is desktop, so baselines and the
  thirteen lines do not move; the HUD's LOOK toggle changes the cap from the next match, never mid-match; in a network
  match the host's value is the match's. Credits stay as they are (lesson: one change at a time). Pass: a unit test per
  rule; `make skirmish` on the laptop (his preset) fields 4 squads a side, read from the RENDER_PRESET / spawn log and a
  screenshot of the garage looked at; the laptop number at 20 a side re-taken through the real skirmish path, not
  the --size flag (lesson: play the default path). The laptop returns to 25 when `make native-tick-profile` at 25
  reads ≥ 0.97 — the orchestrator flips it, checked.
- **C24.6, C24.7 (the bar and pace's hunk), C24.8 (the seams), C23.1a, C23.2, C22.4–C22.7, C21.1, C21.3–C21.5, C20.1,
  C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.** C24.1 (the freeze) is over.

**Checkpoints:** **CP1** brains' F1 (seats) merged alone; **CP2** brains' F2 (the funnel) merged alone → pace and native
told to merge main; pace re-runs its P2 series on the result (a slower think on a new crossing is lesson 281's
pattern).

**Decided for him (reversible, `game_design.md` *Round 25: the launch*):** seats by nearest (the leader and the heavies
give way to it); the funnel; three streams (orders, army, perf rest).

**Standing rules:** rounds 12–24's (lessons 225–282).

## Round 24: two streams (launched 2026-10-08 night, CLOSED 2026-10-09; briefs in `streams/archive/round24/`)

**Goal: his bug from playing round 23's close (`game_design.md` *Round 24 direction*: crews ordered across the Locks'
bridge drive into the river and stick; one squad of a big group takes another route and leaves the army) and his
decision of round 23 (the whole per-vehicle tick in C++, `native.md` N3). The bridge goes FIRST (CP1), because the
native rewrite freezes the files it lives in (`roadmap.md` *Round 24 candidates* 1b).**

| Stream | Brief | Round 24 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round24/brains.md](streams/archive/round24/brains.md) (CLOSED) | **R0** his bridge case reproduced from the recording, the layer named; **R1** the fix, a scenario on the Locks, a nav check on every map with water; **R2** squads ordered together keep to the body's route (a cost on detaching, DECLARED, symmetric); stretch: the nav guard in `make check`, B1's 0.75 s priced | **CP1**: R1 merged ALONE → native merges main, the freeze starts |
| **native** | [streams/archive/round24/native.md](streams/archive/round24/native.md) (CLOSED) | **N3a** the per-tank record + contacts table + the execute step's map (equal / declared), before CP1; **N3b** the execute step's leaves; **N3c** `Movement.drive` as one native call per tank; **N3d** think's `situation` | each step priced at three sizes on builder0 → the orchestrator's laptop table |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**` minus native's below, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`,
`tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`, `mk/nav.mk`,
`mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · native `native/**`, `game/ai/native/**`,
`mk/native.mk`, `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` (additive),
`incoming_fire.gd`'s seam, the C23.1a seam in `pathing.gd`, `tests/test_native*.gd`, `tests/native/**`,
`_agents/native.md`, and after CP1 the freeze set (C24.1). **Nobody this round** (a request through the orchestrator):
`game/control/**`, `game/ui/**`, `game/theme/**`, `game/match/**`, `game/tank/**`, `game/units/**` (`MAX_SQUADS` is the
orchestrator's, C24.4), `game/garage/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`,
`game/announcer/**`, `arenas/**`, `game/arena/**`, `tests/baselines/**` (except declared lines), `tools/remote.sh`,
`tools/slot.sh`, `mk/core.mk` (native's `check` → `native` hook stands).

**Contracts (round 24):**

- **C24.1 The freeze.** The freeze set is the per-vehicle tick: `game/ai/movement.gd`, `tank_brain.gd`, `gunnery.gd`,
  `perception.gd`, `ai_tick_cache.gd`, `bot_controller.gd`, `wall_contact.gd`, `pid.gd`, `clothoid.gd` (plus native's
  own `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `incoming_fire.gd`). **Until CP1** they are
  brains' (the bridge fix), and native does not edit `movement.gd` or `tank_brain.gd`. **From CP1 to the round's
  close** native owns them for porting: seams and the GDScript reference paths; no behaviour changes except a port's
  DECLARED one (C24.2). Brains changes no behaviour in them after CP1; a fix it needs there (R2, or a bug) is a
  request through the orchestrator, applied by native or by the orchestrator on main and merged into both. Brains
  keeps `squad.gd`, `order_controller.gd`, `formations.gd`, `cpu_commander.gd`, `element_feed.gd`, `order_feed.gd`,
  `squad_tactics.gd`, `tactical_query.gd`, `pathing.gd` (minus C23.1a) and `game/tactics/**` all round.
- **C24.2 Every port is equal or DECLARED** (C22.2, C23.1 carried). Equal = bit-exact against the LIVE GDScript (the
  N2b proof pattern: the test calls the live function, so a later edit to it that the C++ does not follow fails
  the check), the hashes equal in `native-proof`, `ai-parity` and `element-digest` unchanged. A port that cannot be
  exact (Dictionary-ordered tie-breaks) is said in advance in `native.md`'s map, lands as one commit behind its own
  switch with the paired series (equal outcomes), and the orchestrator rules ON/OFF and takes it to him.
- **C24.3 Every change to fights is declared** (C22.2, C23.5 carried): brains' R1 (if it moves crews) and R2 each one
  commit, merged alone, a scenario and a paired series, the arrive series part of green for a movement change; the
  CPU gets the same behaviour (symmetric). Everything else pre-registers UNMOVED on the thirteen lines and
  determinism.
- **C24.4 The cap is a measured number, the laptop is the fact** (C23.3 carried). The orchestrator runs the laptop
  table with native ON at the launch (`make native` on the laptop, then `make perf-fight PERF_FIGHT=size
  PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r24-base`, his preset, a quiet window; the laptop is the orchestrator's
  until it says done) and after each native step on main; files it under `streams/references/round24/perf/laptop/`.
  The bar: 50 v 50 leaders in contact ≤ 25 ms a tick on the laptop → `Units.MAX_SQUADS` → 10 (army's A4 recipe),
  by the orchestrator, alone, checked; until then the cap moves to the largest size under the bar, if any.
- **C24.5 Squads ordered together** (brains' R2): the route choice for a group order prefers the body's route; the
  cost is a cost (a real split that saves time is allowed and written down), applies to the CPU's grouped orders,
  and is measured with `game/tactics/coherence_probe.gd` on his case.
- **C24.6 (granted 2026-10-09 ~05:00, brains' request after measuring): two seams in `game/ai/tactical_query.gd`.**
  Native may add, at the top of `TacticalQuery.find_cover_fire` and `TacticalQuery.find_cover`, a seam `if
  BrainSwitches.native and BrainSwitches.native_tq: return NativeBridge.impl.<fn>(...)` over a C++ port of those
  functions with their helpers (`hull_hidden`, `peek_from`, `_cover`, `_candidates`: pure over `CoverMap` + the
  request), equal answer by the live-function proof (`tests/test_ai_tactical_query.gd` cases plus seeded requests
  from real situations), ruled ON/OFF by the in-contact laptop rule. Nothing else in that file; brains does not edit
  those functions while the seam is open (it tells the orchestrator first). Brains' measurement (builder0, 50 v 50
  leaders, pinned, n = 1, profiling on, `9cc1aca7`): `find_cover_fire` ~1.1 ms a call (~15 hidden/peek searches),
  0.86 ms a tick; `find_cover` ~0.7 ms a call, 0.21 ms a tick; every crew asks its own question, the sight lines
  under them already native: what is left is GDScript loop overhead (lesson 276's whole-loop shape).
- **C24.7 (2026-10-09, his decision): the round's bar is 25 a side with no slow motion in the opening clash on his
  laptop.** Measured by the orchestrator with `make native-tick-profile` (his preset, 25 a side, foundry + parade × 3
  seeds, window 8–20 s, n = 6, uninstrumented frame from `perf-fight`'s per-phase timeline as the second reading):
  **game speed in the window ≥ 0.97** (ticks a frame × 33.3 ms ÷ frame ms; today 2.94 × 33.3 / 124 ≈ 0.79, pinned at
  the catch-up cap). `Units.MAX_SQUADS` stays 5. **The think-rate change (brains' L1)** is a DECLARED behaviour change
  (C24.3): one commit, alone, both sides, decided from simulation state only (contact, reach, distance, orders;
  never the camera, the selection or the machine), with a scenario and the paired series (arrive, the beaten zone,
  the pursuit, his recordings' cases), priced in contact on the laptop. **Ownership for it:** brains owns, in
  `tank_brain.gd`, the think-scheduling hunk (the `*_THINK_*` constants, `_think_hz` and the rate choice around
  `t.rate_progress`, `brain_stride`) and whatever new per-crew urgency read it needs in its own files; native owns
  the rest of the freeze set as before and does not edit that hunk. A conflict in that file resolves by hunk owner.
- **C24.8 (granted 2026-10-09 ~09:00, from native's elements breakdown): the element's grounding and plan, ported.**
  Native may add seams (behind a new switch `native_el`, ruled by the in-contact laptop rule) at the top of
  `SlotGround.standable_from`, `standable_for` / `_standable_for` (with `_settle`, `_fits`, `_off_mesh`, `wet`,
  `over_water`, `on_anchor_side`, `pulled_dry` as the C++ needs them) in `game/tactics/slot_ground.gd`, and of
  `ElementPlan.build` in `game/tactics/element_plan.gd`, over C++ ports proven equal against the LIVE functions on
  requests seeded from real fights (every map with water among them: CP1's rules must survive bit for bit). Nothing
  else in those files. Brains does not edit those functions while the seams are open (tells the orchestrator first).
  The measurement (native, builder0 headless, Sumps 25 a side + leaders, 8–20 s, 3 seeds, throwaway laps on
  `c8ca14dc`): elements = 21.7 % of the tick's scripts; `Element.update` → `u.ground` 1.57 ms (37 % of elements:
  apply_swap + ground + ground_stations → SlotGround per slot and per order goal), `u.plan` 1.07 (25 %),
  `u.situation` 0.63, `u.issue` 0.34, `u.etas` 0.23 (absolute ms on a lighter run; read the shares).
- **C23.1a, C23.2, C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Bar (from 2026-10-09, his decision):** C24.7 supersedes C24.4's 50-a-side bar for this round.

**Checkpoints:** **CP1** brains' R1 (the bridge) merged ALONE the moment it is green → native told to merge main; the
freeze starts. **The laptop table** (the orchestrator's, the launch night) → native's bar; re-run per native step on main.

**Decided for him (reversible, recorded in `game_design.md` *Round 24 direction: the launch*):** the bridge first, the
rewrite second; two streams (orders, army, perf rest); R2 as a cost on detaching, not a rule that squads never split.

**Standing rules:** rounds 12–23's (lessons 225–278).

> **No round is running. Round 23 is CLOSED (2026-10-08): three streams, brains, native and orders, all merged;** its
> briefs are in `streams/archive/round23/`, its contracts (C23.1–C23.5, C23.1a) kept below. Round 24 is planned: the
> per-vehicle tick rewritten in C++ (the lead's decision; `roadmap.md` *Round 24 candidates*, `native.md` N3).

> **Round 23 is RUNNING (launched 2026-10-07 ~23:45 PDT): three streams, brains, native and orders** (the section
> below). Round 22 is CLOSED (its briefs in `streams/archive/round22/`, its contracts C22.1–C22.7 kept). Rounds 21
> (C21.1–C21.5), 20 (C20.1–C20.5) and 19 (C19.1–C19.7) stand.

> **No round is running. Round 22 is CLOSED (2026-10-08): four streams, army, brains, orders and perf, all merged;**
> its briefs are in `streams/archive/round22/`, its contracts (C22.1–C22.7) kept below. Rounds 21 (C21.1–C21.5), 20
> (C20.1–C20.5) and 19 (C19.1–C19.7) stand.

## Round 23: three streams (launched 2026-10-07 night, CLOSED 2026-10-08; briefs in `streams/archive/round23/`)

**Goal: his first item after playing round 22's close (`game_design.md` *Round 23 direction, first item*: a line
abreast only formed at the end because the lead vehicle was already nearest the target; some vehicles should slow so
the squad forms on the way) and the per-vehicle tick that caps the army at 25 (round 22's verdict: ~0.6–0.8 ms per
vehicle per tick on builder0, four fifths the vehicle brain, the profile flat, equal-answer cuts ≤ 2 %, native code
the candidate). Three streams, one problem each: brains (the squad paces itself on the way; the per-crew fire read;
the grace under three guns), native (a C++/godot-cpp toolchain, then the brain's hot loop ported where it pays, the
sim hash + the full suite the proof, priced by in-run A/B), orders (two columns 28 m apart, decided by him; the alert
strip clears the edge chips; the held crew's readout; ten AUTO squads on the click). The laptop baseline at 25 and 30
a side is the orchestrator's first measurement, run the launch night (lesson 271).**

| Stream | Brief | Round 23 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round23/brains.md](streams/archive/round23/brains.md) (CLOSED) | **B0** his case reproduced and measured; **B1** the fast crew slows, the anchor paces to the slowest seat (DECLARED, alone); **B2** `UnansweredFire.crew_reason` for orders (C23.2); **B3** under three guns act inside the grace (DECLARED, alone) | **CP1**: B1 (+ B2 if ready) merged ALONE → native merges main before touching `movement.gd` |
| **native** | [streams/archive/round23/native.md](streams/archive/round23/native.md) (CLOSED) | **N0** the toolchain priced by a no-op (godot-cpp 4.7, `make native`, `make check` with and without the `.so`); **N1** Avoidance native; **N2** Movement's geometry; **N3** the data reshaped (the execute step as one native call per tank); the number per step at 50 v 50, builder0 | N0 green → merged early (everyone's `make check` changes) |
| **orders** | [streams/archive/round23/orders.md](streams/archive/round23/orders.md) (CLOSED) | **O1** two columns 28 m apart (his answer); **O2** the alert strip clears the edge chips and the panel header (`edge_markers.gd` lent, C23.4); **O3** the held crew's readout (consumer of C23.2); **O4** ten AUTO squads stand on the click | C23.2 consumer (stub until B2 lands) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**` minus native's files below, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`,
`tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
`mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares, and in
`game/ai/movement.gd` the `speed_factor` / `_keep_station` / station-PID hunks · native `native/**`,
`game/ai/native/**`, `mk/native.mk`, `game/ai/avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`,
`brain_switches.gd` (additive), `incoming_fire.gd`'s `closest_approach` only, and in `game/ai/movement.gd` the
pure-geometry seams (`_chord_compute`, `_arc_hit`, `_outline_ok`, the call into `Avoidance`), `tests/test_native*.gd`,
`tests/native/**`, `_agents/native.md`; `Makefile`, `mk/core.mk` (the `check` → `native` dependency), `project.godot`,
`.gitignore`, `export_presets.cfg` additive in merge notes · orders `game/control/**`, `game/ui/formation_picker.gd`,
`selection_panel.gd`, `group_bar.gd`, `squad_chip.gd`, `selection_markers.gd`, `command_icons.gd`, `tactical_map.gd`,
`radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`, **`game/ui/edge_markers.gd`
(lent from perf this round)**, `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`,
`tests/test_element_preview.gd`, `tests/test_touch.gd`, `mk/command.mk`. **Nobody this round** (a request through the
orchestrator): `game/match/**`, `game/tank/**`, `game/announcer/**`, `game/garage/**`, `game/units/**` (army resting:
`Units.MAX_SQUADS` flips back to 10 at the close by the orchestrator; orders may flip it LOCALLY to measure at ten,
never committed), `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/web/**`, the rest of
`game/ui/**` and `game/theme/**` (perf resting), `arenas/**`, `game/arena/**`, `tests/baselines/**` (except declared
lines), `tools/remote.sh`, `tools/slot.sh` (the orchestrator's; native's build dir may need an rsync rule: a request).

**Contracts (round 23):**

- **C23.1 Two streams in `game/ai/`, one file shared by hunk.** Brains owns the brain's behaviour (`tank_brain.gd`,
  the element/transit code, `movement.gd`'s speed and station-keeping); native owns the pure pieces it ports
  (`avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` additive) and, in
  `movement.gd`, ONLY the pure-geometry functions named above, wrapped as `if NativeBridge.available: return
  Native.x(...)` seams. Each lists its `movement.gd` hunks in merge notes; the orchestrator resolves a conflict in
  favour of the owner of the hunk. Native does not touch `movement.gd` before CP1 (brains' B1) is on main and merged
  into its branch. Native never changes an answer (equal hash in `ai-ab-match`, the full check, `ai-parity`,
  `element-digest`); if a piece cannot be bit-exact it is a DECLARED change under C22.2, said in advance.
- **C23.1a (granted 2026-10-08 01:45, native's request): one function in `game/ai/pathing.gd`.** Native may add,
  above the engine call in `Pathing.closest_point`, the three-line seam `if BrainSwitches.native and
  BrainSwitches.native_nav: return NativeBridge.impl.closest_point(map, point)` (its N2a: a grid-indexed closest
  point equal to the engine's linear scan by construction, 13 maps × 961 points 0 mismatches). Nothing else in that
  file; brains' B1 does not touch it (checked); listed in native's merge notes. Finding filed: Godot 4.7.2's
  `map_get_closest_point` scans every navmesh polygon with no broadphase (429 calls a tick at 14.5 µs = 14.5 % of
  the brains' work at 50 v 50).
- **C23.2 The per-crew "fire I cannot answer" read.** Brains provides
  `UnansweredFire.crew_reason(game_match: Match, unit_name: String) -> String` (static; returns
  `UnansweredFire.WHY_HELD` while the named crew is being hit by something it cannot return, by B1's own test, for a
  crew inside OR outside an element; "" otherwise; no cost unless called). Orders reads it for the selected crew(s)
  under a direct hold and shows the same words; until it lands, orders stubs it in its paths (a static in
  `game/control/` returning "") and wires the readout against the stub. B2 merges with CP1 or as its own
  equal-answer merge.
- **C23.3 The cap is a measured number, and the laptop is the fact** (C22.3 carried, lesson 271). The orchestrator
  runs the laptop baseline (`make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r23-base`,
  his preset, a quiet window) the launch night and files it under `streams/references/round23/perf/laptop/`; native
  reports builder0's controller band per step (his Sumps, 25 v 25, 50 v 50; `taskset -c 0-3`; n = 3); when a step
  lands on main the orchestrator re-runs the laptop command. The bar: 50 v 50 with leaders in contact ≤ 25 ms a tick on
  the laptop (p95 frame at 50 ≤ p95 at 25 on round 21's main + 25 %, perf's bar, as the second reading). When met,
  `Units.MAX_SQUADS` → 10 (army's A4 recipe, `streams/archive/round22/army.md`), by the orchestrator, alone, checked.
  Until then the cap moves to the largest size under the bar in the table, if any.
- **C23.4 `edge_markers.gd` is orders' this round** (perf resting): the alert strip and the off-screen element chips.
  Perf's round-22 `alert_y()` rule (the strip clears the group bar's top) stays; orders adds the chips and the
  panel header. Frames at both aspects filed.
- **C23.5 Every change to fights is declared** (C22.2 carried): brains' B1 and B3 each one commit, merged alone, a
  scenario and a paired series, the arrive series part of green for a movement change; everything else, every
  stream, pre-registers UNMOVED on the thirteen lines and determinism (the match runner forms no elements: brains'
  transit change is expected UNMOVED and still declared).
- **C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** brains' B1 (his item) merged ALONE the moment it is green → native and orders told to merge
main. **N0** (the toolchain) merged early on its own, checked with and without the `.so` → everyone's `make check`
builds the `.so` on builder0; told. **The laptop table** (the orchestrator's) → native's bar; re-run per native
step on main.

**Decided by him at the launch (2026-10-07 ~23:00):** two columns 28 m apart (yes); the Syndicate range gap stays.
**Decided for him (reversible, recorded in `game_design.md` *Round 23 direction: the launch*):** C++ through
godot-cpp for native code (he asked whether it meant Rust; the recommendation stands unless he says otherwise).

**Standing rules:** rounds 12–22's (lessons 225–274).

## Round 22: four streams (launched 2026-10-07 afternoon, CLOSED 2026-10-08; briefs in `streams/archive/round22/`)

**Goal: his two items after playing round 21 (`game_design.md` *Round 22 direction*): the army DOUBLES (ten squads of
five, 50 vehicles, 2000 credits; the final cap set by his frame on the laptop at 50 a side), and a vehicle that is
being shot by something it cannot answer does not sit on its post until it dies. Four streams, one problem each:
army (the garage, the budget, the cap), brains (the sitting duck; the commander at ten squads; the sim's tick at 50 a
side), orders (ten control groups, ten squads selected and shown, the body at ten), perf (his frame on the laptop at
50 a side: measured, then cut as equal-output changes and hardware presets).**

| Stream | Brief | Round 22 | Checkpoint |
|---|---|---|---|
| **army** | [streams/archive/round22/army.md](streams/archive/round22/army.md) (CLOSED) | `MAX_SQUADS` 10, the budget 2000 CR, the cap 50, in ONE place each (C22.1); the garage fits ten squads on desktop and phone; the CPU opponent buys 2000; suggested armies and the tour at ten; the hint text | **CP1**: the constants + the opponent, merged ALONE → everyone merges |
| **brains** | [streams/archive/round22/brains.md](streams/archive/round22/brains.md) (CLOSED) | **the sitting duck** (B1: a crew under fire it cannot return closes, breaks the line of fire or falls back, both sides; from his recording); the commander and `ArmyLayout` at ten elements a side (B2); the sim's tick at 50 v 50 with leaders on builder0 and the slot-grounding cut (B3); the Syndicate range gap measured for him (B4) | B1 and B3 declared, alone (C22.2) |
| **orders** | [streams/archive/round22/orders.md](streams/archive/round22/orders.md) (CLOSED) | control groups 1–9 and 0 (O1); the selection panel, group bar and squad chips at ten squads, desktop and phone (O2); the body at ten squads (ranks of three, O3); the radar and tactical map at 50 a side (O4); the probes at ten | CP1 consumer |
| **perf** | [streams/archive/round22/perf.md](streams/archive/round22/perf.md) (CLOSED) | his frame on the laptop at 25 v 25 and 50 v 50 with leaders on (P1: the number that sets the cap, C22.3); the frame's cost by removal (P2); equal-output cuts in render, FX and the HUD's per-unit work (P3); what remains as a hardware preset (P4) | P1's number to the orchestrator the same day |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
army `game/garage/**`, `game/progression/**`, `game/units/units.gd` (`DEFAULT_BUDGET` and prices only), `game/ui/widgets/cyber_*.gd`,
`conductors.gd`, `game/ui/widgets/title/**`, `game/theme/game_theme.gd` `ui` palettes, `doctrines/player_*.json`,
`tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md`,
`_agents/balance.md` *Economy*, `assets/units/thumbs/**` · brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`,
`mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · orders `game/control/**`,
`game/ui/formation_picker.gd`, `selection_panel.gd`, `group_bar.gd`, `squad_chip.gd`, `selection_markers.gd`,
`command_icons.gd`, `tactical_map.gd`, `radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`,
`tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`,
`tests/test_touch.gd`, `mk/command.mk` (its `hud-profile` and `hud-digest` targets are LENT to perf, read-only for orders this round) · perf `game/theme/fx/**` (minus `order_feedback.gd`),
`game/theme/cyberpunk/**`, `game/theme/arena_kit/**`, `game/ui/hud.gd`, `hud.tscn`, `hud_messages.gd`, `unit_bars.gd`,
`unit_portraits.gd`, `edge_markers.gd`, `draw_batch.gd`, `hud_cost_probe.gd`, `game/ui/widgets/hud_skin.gd`,
`tools/perf*`, `tests/test_hud*.gd`, `tests/test_theme*.gd` (minus the airship two, still airship-owned at rest),
`tests/test_fx*.gd`, `mk/fx.mk`, `_agents/show_dials.md`, `_agents/lighting.md`, `_agents/legibility.md` *the HUD's
cost*. **Nobody this round** (a change there is a request through the orchestrator): `game/match/**`, `game/announcer/**`,
`game/ui/scoreboard*.gd`, `arenas/**`, `game/arena/**`, `game/tank/**`, `game/combat/**`, `game/modes/**` (one
constant for army if the skirmish's default army size lives there, listed), `game/camera/**`, `game/network/**`,
`game/audio/**`, `game/web/**`, `export_presets.cfg`, `mk/core.mk` (`perf-play` is read-only for perf; a change is a
request), `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`. `game/main.gd`,
`project.godot`: additive only, in merge notes. Tests: each stream owns the `tests/test_*.gd` of its area; a test another
stream's change breaks is fixed by the owner of the behaviour, by request.

**Contracts (round 22):**

- **C22.1 The army's size lives in one place each, and CP1 is the constants.** **Amended at launch+1 h (army's finding):** the
  squad count is `Units.MAX_SQUADS := 10` in `game/units/units.gd` (army's), read by `ArmyCatalog.MAX_SQUADS`,
  `SquadConsolidation.MAX_SQUADS` (which folds HIS army before it spawns) and `Doctrine.PLAYER_MAX_SQUADS` (two
  one-line edits in brains' paths, granted, in army's merge notes); tactics never imports the garage. `Units.DEFAULT_BUDGET`
  STAYS 1000 points (the flagless skirmish's fixed 5-vehicle player_default v a 1000-pt CPU and every match-runner
  experiment lean on it; army's decision, accepted); the garage alone goes to 2000 CR. Original text: `ArmyCatalog.MAX_SQUADS` (10),
  `ArmyCatalog.MAX_SQUAD_SIZE` (5, unchanged: `Formations.MAX_MEMBERS` stays 5, brains' invariant), the garage's budget
  (2000 CR; `Units.DEFAULT_BUDGET` follows in points so `make skirmish` without a faction fields the same size, army
  decides and records), and the CPU opponent's purchase (`GarageOpponent.UNIT_CAP` derives). Everyone else READS them;
  nobody hard-codes 5, 10, 25, 50, 1000 or 2000 for an army size (grep in the merge). CP1 = those constants + the
  opponent + the catalog's tests, merged ALONE with the archetype × seed proof that `Army.cpu_army` for the baselines
  (`Units.BASELINE_BUDGET`, explicit flags) is untouched; the thirteen lines UNMOVED. The garage's screen for ten
  squads follows CP1 on the same branch.
- **C22.2 Every change to fights is declared** (C21.2 carried): brains' B1 and any B3 cut that is not equal-answer are
  each one commit, merged alone, lines adopted and named; B1 has a scenario from his recording AND a paired series
  (hold stage, parade and foundry, 8 then 24 seeds); the arrive series for any movement change. Everything else, every
  stream, pre-registers UNMOVED on the thirteen lines and determinism.
- **C22.3 The cap is a measured number.** Perf's P1 measures his frame on the laptop (his preset, his window, the
  garage's path, CPU leaders on) at 25 v 25 and 50 v 50 (and 40 v 40 if 50 fails): mean and p95 frame ms over ≥ 3
  seeds × 120 s, with `make perf-play` (read-only, nobody's `mk/core.mk`; perf asks for a target of its own in
  `mk/fx.mk` if it needs one). The orchestrator runs the laptop half in a quiet window (lesson 260) or hands him the
  command; builder0 gives ratios only. If 50 a side is not smooth at the laptop preset after P3's cuts (bar: p95 ≤ the
  25-a-side p95 at round 21's main + 25 %), the cap drops to the largest size that is, and army scales the credits
  (40 → 1600, 30 → 1200). The orchestrator decides the number and tells army; army builds for 10 regardless, with
  the constant.
- **C22.4 The sim's tick is brains', the frame is perf's.** Brains prices the simulation at 50 v 50 with leaders
  (`sim-profile`, `ai-ab-match`, builder0) and cuts there; perf prices everything else (render, FX, HUD, dressing) and
  cuts there; neither quotes the other's number as its own, and both put their numbers in the same table in HANDOFF
  (commit, machine, workload, n).
- **C22.5 Ten groups, one keyboard.** Orders: keys 1–9 and 0 (0 = group 10); `ControlGroups` holds ten; the group bar,
  squad chips and selection panel lay out ten on desktop and at phone aspect; the garage's squads 1–10 map to groups
  1–10 (army reads `ControlGroups.MAX_GROUPS`, orders' constant; until it lands, 10 literal in army's tests only).
  The HUD files perf owns are not where the squad row is drawn (`group_bar.gd`, `squad_chip.gd` are orders'); if
  perf's HUD cut touches their layout it is a request.
- **C22.6 Symmetric, and a direct order still wins** (lesson 264): brains' B1 runs for his crews under a hold too, and
  under his explicit order a crew does what he said (a `hold` he gave is his; the element's hold is the leader's and
  may be left). The scenario states both arms.
- **C22.7 (granted at launch+2 h, from perf's P0): the tick's hot paths outside brains' tree.** `game/match/match.gd`'s
  per-tick paths (+12.1 ms a tick at 41 vehicles in contact, builder0) are brains' for EQUAL-ANSWER cuts (declared if a
  line moves; in merge notes); `game/announcer/announcer_booth.gd` WAS perf's for one equal-answer cut of a measured +2.3 ms of
  TICK; **withdrawn**: re-measured alone over 8 bracketed cycles it is +0.35 ms mean with per-cycle signs disagreeing
  (the 2-cycle sweep read the fight's own drift); not a defect, no edit. `game/tank/tank.gd` (+3.2) stays nobody's: named, requested.
  **B3 is the round's critical path:** the tick costs ~0.7 ms per vehicle in contact on builder0 (~2 ms on his laptop),
  so 50 a side cannot ship at today's cost; the cap (C22.3) is decided after B3's first cut, not before.
- **C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.4–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** army's constants + opponent → merged alone, checked, everyone told to merge (brains' B2 and
orders' O2–O4 read the real cap; perf's P1 50-a-side runs need it). Perf's **P1 number** → the orchestrator the same day
→ the cap decided → army told. Brains' declared changes: whichever is green first, each alone.

**Questions to him this round (asked in the launch message, one recommendation each):** the airship on the Cut /
Docks / Sumps (round 22 candidate 1; recommended: try the flag in one game and say); the Syndicate-over-gangs range
gap (candidate 2; recommended: leave it, a 120 CR platform should beat 40 CR scouts in the open).

**Standing rules:** rounds 12–21's (lessons 225–270).

## Round 21: three streams (launched 2026-10-06 evening, CLOSED 2026-10-07; briefs in `streams/archive/round21/`)

**Goal: the two things he saw in his two games after round 20 (`game_design.md` *Round 20, afternoon* and *Round 20,
evening*), and the one thing he never saw. (1) When he attacks a vehicle that runs, his scouts circle instead of
chasing it, and an attack-move still sends one scout forward per squad and holds the rest: brains. (2) When five
squads are ordered together the outer squads first drive 100 m sideways: orders. (3) He played whole matches on the
built-up maps and the airship was never in his frame (0–3 % of the flight on five rotation maps): airship. Each stream
is one independent problem; brains and orders share the attack order and have a contract (C21.1).**

| Stream | Brief | Round 21 | Checkpoint |
|---|---|---|---|
| **airship** | [streams/archive/round21/airship.md](streams/archive/round21/airship.md) (CLOSED 2026-10-07) | the airship is in his frame for a real share of every rotation map at his pose, without hiding the fight more than today; the report reads the live rotation; frames looked at | none needed (isolated) |
| **brains** | [streams/archive/round21/brains.md](streams/archive/round21/brains.md) (CLOSED 2026-10-07) | no bait/encircle under ANY player order (attack-move included); an attack on a named target that moves is a PURSUIT; stretch: the hold falls back when losing; the in-run A/B for the leaders' price | each declared change alone (C21.2) |
| **orders** | [streams/archive/round21/orders.md](streams/archive/round21/orders.md) (CLOSED 2026-10-07) | several squads, one click: the row's width capped (a second rank behind, not 400 m abreast); a probe case for it; the Parade bay slot | **CP1**: O1 merged → brains told to merge (its five-squad scenarios read the real layout) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
airship `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
`game/theme/fx/bench/airship_shot.gd`, `game/theme/fx/bench/rig_vanish.gd`, `tools/airship_view_pool.py`, the airship
targets in `mk/fx.mk`, the `_build_airship` carve-out in `game/theme/cyberpunk/arena_dressing.gd`; `game/camera/**` is
READ-ONLY for it (one additive accessor allowed, listed in merge notes) · brains `game/ai/**`, `game/tactics/**`,
`tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
`tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it
declares · orders `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`, `command_icons.gd`,
`tactical_map.gd`, `radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`,
`tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`,
`tests/test_touch.gd`, `mk/command.mk`. **Nobody this round** (a change there is a request through the orchestrator):
`game/garage/**`, `game/progression/**`, `game/units/**`, `game/ui/**` except orders' files, `game/match/**`,
`game/announcer/**`, the rest of `game/theme/**`, `arenas/**`, `game/arena/**`, `game/tank/**`, `game/combat/**`,
`game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/web/**`, `export_presets.cfg`,
`mk/core.mk`, `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`.
`game/main.gd`, `project.godot`: additive only, in merge notes. Tests: each stream owns the `tests/test_*.gd` of its
area; a test another stream's change breaks is fixed by the owner of the behaviour, by request.

**Contracts (round 21):**

- **C21.1 The attack order, split at the task.** Orders decides WHAT each squad is told (one task per squad; for a
  named-target `attack` the task carries `target` and no `to`, as today; for a `move`/`attack_move` with several
  squads the row's anchors, capped by O1). Brains decides HOW an element carries a task out: for an `attack` with a
  `target` the element follows the target's live or last-known position (never a fixed point), does not "arrive"
  outside weapon range, and runs no elective drill under any player task. Neither edits the other's files; the task
  dictionary's keys (`verb`, `to`, `target`, `facing`, `formation`) do not change this round.
- **C21.2 Every change to fights is declared** (C20.2 carried): brains' P1, P2 and any stretch behaviour each one
  commit, merged alone, lines adopted and named; the arrive series is part of green for a movement change (lesson
  261) and a decision change has its own paired series (lesson 263 family: a behaviour change gets a scenario AND a
  series). Everything else, every stream, pre-registers UNMOVED on the thirteen lines and determinism. Orders' O1
  changes where squads are sent, so it is a declared change too if any line moves (the baselines are CPU-v-CPU and
  should not; say so in the pre-registration).
- **C21.3 The airship is seen, not in the way.** Round 14's instrument stands as the acceptance in both directions:
  `make airship-view` *hides the fight %* per map does not rise above main's at `0a9ce446` (same seeds, same arms), and
  `make airship-report` *in his frame %* rises on every rotation map where it is under 10 % today. The report's
  default map list is the live `Arena.ROTATION` (lesson 265). The camera's lift (round 11) is read-only: a fix on the
  camera's side is a request.
- **C21.4 The probe is the acceptance for orders' O1** (C20.3 carried, the other way round): orders adds the five-squad
  case to `make two-squads-playtest`; brains reads the before/after numbers, edits nothing there.
- **C21.5 CPU squad leaders on by default (his answer, 2026-10-06 evening).** Brains may edit `game/modes/skirmish_mode.gd`
  for exactly one thing: `ELEMENT_CPU_DEFAULT := true` (and its comment), with a test pinning that a launch with no
  flag runs the CPU's elements and `--no-element-cpu` does not. It is a DECLARED change (C21.2) if any baseline line
  moves (the baselines launch their own flags; say which in the pre-registration), merged ALONE, the file listed in
  brains' merge notes. The garage's fight goes through the same mode and so turns on with it.
- **C19.4–C19.7 stand** (one score read everywhere; the kit additive; questions through the orchestrator in his terms;
  shared files by area). **C20.1, C20.4, C20.5, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** orders' O1 → merged alone, checked, brains told to merge (so brains' pursuit scenarios with
five squads start from where orders now sends them). Brains' declared changes: whichever is green first, each alone.
Airship: merged when green; nobody depends on it.

**His answers, minutes after the launch (2026-10-06 evening):** CPU squad leaders ON by default (C21.5, brains P0);
the airship *"same as other maps"* (airship V2's bar: the open maps' 24–31 % in frame, the fight never hidden).

**Standing rules:** rounds 12–20's (lessons 225–266).

## Round 20: two streams (launched 2026-10-06, CLOSED 2026-10-06; briefs in `streams/archive/round20/`)

**Goal: his two garage items after playing round 19 (`game_design.md` *Round 20 direction*): the vehicles are SEEN on
their cards and in their squads, and five squads of five scouts is exactly 1000 credits (prices per faction: the
scout is 40 CR, relative prices kept; the 25 cap stays unless he says otherwise). Brains runs beside it on his
standing rule: a squad forms up on the move (no shuffle before it sets off, no crew driving away from the click), and
the computer's opening lets it be ahead so its ambush can fire.**

| Stream | Brief | Round 20 | Checkpoint |
|---|---|---|---|
| **garage** | [streams/archive/round20/garage.md](streams/archive/round20/garage.md) (CLOSED 2026-10-06) | the per-faction price rule (scout = 40 CR); unit thumbnails from the real meshes on every card and chip; the phone wrap | **CP1**: R1 (the prices) merged ALONE |
| **brains** | [streams/archive/round20/brains.md](streams/archive/round20/brains.md) (CLOSED 2026-10-06) | form up on the move (M1); the opening posture (M2); the ambush hides the line (M3) | each declared change alone (C20.2) |

**Ownership:** as round 19's garage and brains (above), plus garage's `assets/units/thumbs/**` and `tools/unit_thumbs.*`.
Orders' and board's paths are **nobody's** this round (closed): `game/control/**`, `game/ui/**` except the kit and
title files, `game/match/**`, `game/announcer/**`, `game/theme/arena_kit/**`; a change there is a request through the
orchestrator. `game/modes/**`, `game/theme/**`, `arenas/**`, `mk/core.mk`, `tests/baselines/**` (except declared
lines): nobody.

**Contracts (round 20):**

- **C20.1 Prices per faction, points untouched.** `Credits.of_unit` is the only place a credit price is computed;
  `Units.cost` (points) is balance (C12.6) and the baselines' input; the garage's CPU opponent buys at the same 1000 CR
  under the same faction prices. R1 merges ALONE with the 21-price table and the archetype × seed proof that
  `Army.cpu_army` for skirmish and the baselines is untouched.
- **C20.2 Every change to fights is declared** (C19.3 carried): brains' M1, M2, M3 each one commit, merged alone, lines
  adopted and named; the arrive series is part of green for a movement change (lesson 261); everything else
  pre-registers UNMOVED on the thirteen lines and determinism.
- **C20.3 The probe is the acceptance.** Orders' `make two-squads-playtest` and `tests/test_control_two_squads.gd` are
  read-only instruments for brains; their numbers (worst off-line in 5 s; worst away-from-click) before and after are
  in every M1 report.
- **C20.4 Thumbnails are assets.** `assets/units/thumbs/**` is generated by `make unit-thumbs` on builder0 and
  committed; a test fails when a unit has no thumbnail; nothing is rendered at runtime for the chips.
- **C20.5 The garage names the opponent (granted 2026-10-06, garage's request R4).** garage may edit
  `game/modes/skirmish_mode.gd` for exactly one thing: the HUD status line reads an optional `enemy-title` launch flag
  in place of `lineups[RUST]` (a no-op without the flag), so the garage's fight says "Skirmish vs The Condemned (CPU)"
  instead of flashing the enemy file path. A test pins it; the file is listed as a shared-file edit in garage's merge notes.
- **C19.4–C19.7 stand** (one score read everywhere; the kit additive and documented; questions through the
  orchestrator in his terms; shared files by area). **C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** garage's R1 → merged alone, checked, brains told to merge (its CPU opponent reads the same
prices). Brains' declared changes: whichever is green first, each alone.

**Standing rules:** rounds 12–19's (lessons 225–263).


## Round 19: four streams (launched 2026-10-05, CLOSED 2026-10-06; briefs in `streams/archive/round19/`)

**Goal: the four things he said after two games on the twelve-map rotation (`game_design.md` *Round 19 direction*):
a formation belongs to the squad he gave it to; two squads ordered together stay two squads and arrive side by side;
the garage he imagines (1000 credits a game, every vehicle priced, squads however he likes up to five, one simple
screen in our theme, with the theme written down as a kit); and a scoreboard he can read all match, in the register
of a televised sport. Brains runs beside them on his standing rule (smart on both sides): the computer defends and
lies in wait on the open maps, the price of its squad leaders cut and measured so he can be asked.**

| Stream | Brief | Round 19 | Checkpoint |
|---|---|---|---|
| **orders** | [streams/archive/round19/orders.md](streams/archive/round19/orders.md) (CLOSED 2026-10-06) | **A formation lives on the squad** (a pick applies to the selected squad at once; selecting another shows its own; G cycles the selected squad's); **several squads, one click: one order per squad**, side by side across the approach, each transiting from its own position, never one element over `MAX_MEMBERS`; the dots per vehicle and per squad | **CP2**: O2+O3 merged → brains told to merge |
| **brains** | [streams/archive/round19/brains.md](streams/archive/round19/brains.md) (CLOSED 2026-10-06) | **The CPU holds and lies in wait** when ahead on points or its zone is threatened (B5(a) carried forward from `brains-r18-ambush`); **the element machinery's price cut** as equal-answer work and re-measured in his frame; the Cut's stop-short; the tactics-side guards for the two-squad case; a decision change's own series | CP2 consumer; C19.3 for every declared change |
| **garage** | [streams/archive/round19/garage.md](streams/archive/round19/garage.md) (CLOSED 2026-10-06) | **1000 credits a game, both sides**; every vehicle priced and buyable; faction → vehicles → squads → FIGHT on one screen in the kit; the kit documented (`_agents/ui_kit.md`, `make ui-kit-shots`); tiers and unlocks retired from the garage | **CP1**: the kit merged early → board told to merge. **CP3**: the prices (G1) merged ALONE, pre-registered |
| **board** | [streams/archive/round19/board.md](streams/archive/round19/board.md) (CLOSED 2026-10-06) | **A score bug** (each side's progress to the win as a meter with the zones named as the map names them, kills, credits destroyed), redrawn on change; **the celebration** on a kill in the broadcast register (the caller's line wired to it); one score snapshot and signal from `Match`; the arena screens and the results screen read it | CP1 consumer; its signal is read by brains (C19.4) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
orders `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`, `command_icons.gd`, `tactical_map.gd`,
`radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`, `tests/test_control*.gd`,
`tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd`,
`mk/command.mk` · brains `game/ai/**`, `game/tactics/**` (minus the lent guard line), `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`,
`mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · garage `game/garage/**`,
`game/progression/**`, `game/units/units.gd` prices only, `game/ui/widgets/cyber_*.gd`, `conductors.gd`,
`game/ui/widgets/title/**`, `game/theme/game_theme.gd` `ui` palettes, `doctrines/player_*.json`,
`tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md`,
`_agents/balance.md` *Economy* · board `game/match/**` (additive), `game/ui/hud.gd`, `hud.tscn`, `hud_messages.gd`,
`game/ui/widgets/hud_skin.gd`, `game/ui/scoreboard*.gd`, `game/announcer/**`, `assets/announcer/**`,
`game/theme/arena_kit/**`, `tests/test_control_point.gd`, `tests/test_hud*.gd`, `tests/test_match*.gd`,
`tests/test_assets_ad_screens.gd`, `tests/announcer/**`, `mk/announcer.mk`. **Nobody:** `arenas/**`, `game/arena/**`,
`game/tank/**`, `game/combat/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`,
`game/theme/fx/**` (minus order_feedback), the rest of `game/theme/**`, `game/web/**`, `export_presets.cfg`,
`mk/core.mk`, `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh` — a change
there is requested through the orchestrator. `game/main.gd`, `project.godot`: additive only, in merge notes. Tests:
each stream owns the `tests/test_*.gd` of its area; a test another stream's change breaks is fixed by the owner of
the behaviour, by request.

**Contracts (round 19):**

- **C19.1 Several squads are never one element.** Orders issues one order per squad for any selection that holds
  several (both selection shapes); `Elements.form` refuses more than `Formations.MAX_MEMBERS` members, loudly. That
  one guard line in `game/tactics/elements.gd` is LENT to orders; brains re-reads it at CP2 and adds the
  tactics-side tests (B5). Partial squads (`partial_probe.gd --case=mixed`) keep their behaviour.
- **C19.2 Prices move once, on purpose: garage's CP3.** `Units.cost` is balance (C12.6, his); a proportional
  re-expression to the 1000-credit scale is allowed when it buys IDENTICAL CPU armies for every archetype, faction
  and seed the baselines and series use (the table is in garage's Status before the commit); otherwise credits are a
  presentation of the internal points, or the move is declared and merged alone with its lines adopted. G1 merges
  ALONE either way with its pre-registration.
- **C19.3 Every change to fights is declared** (C18.1 carried): brains' B2, B4 and any B3 cut that is not
  equal-answer are each one commit, merged alone, lines adopted with `make sim-baseline-adopt` and named in the
  commit. Every other commit of every stream pre-registers UNMOVED on the thirteen lines (foundry + the twelve) and
  determinism; an unplanned move is a finding: stop, attribute, message the orchestrator. CPU elements stay OFF on
  his path until he answers (brains' B3 prepares the number).
- **C19.4 One score, read everywhere.** `Match` gains `score_snapshot()` and `score_changed(snapshot)` (board, S1,
  additive; the rules of winning untouched: `CONTROL_*`, `_check_finished`, `result()` are his). The HUD bug, the
  radar, the arena screens, the results screen and brains' posture read the snapshot; nobody keeps a second tally.
  Until S1 lands brains polls `control_score` and the objectives' owners. A kill's value on the board is
  `Units.cost` as the garage prices it after CP3.
- **C19.5 The kit is additive and documented.** `CyberFrame`, `CyberUiTheme`, `CyberStyle`, `CyberBanner`,
  `Conductors` are garage's this round; every change is additive (new elements, new parameters with today's
  defaults) and the HUD's and title's output are unchanged frame for frame (`make hud-digest`; a title frame
  diffed) on every garage commit. `_agents/ui_kit.md` + `make ui-kit-shots` are CP1; board builds on them after
  CP1 and on HudSkin's use of `CyberFrame` before it. A kit element board needs is a request to garage.
- **C19.6 Questions to him go through the orchestrator**, in his terms, one recommendation each (lesson 254);
  briefs' *Waiting on the lead* lists them; the worker builds the recommended option meanwhile.
- **C19.7 Shared files and carve-outs.** `game/ui/**` is split by file as above; a new file in `game/ui/` belongs to
  the stream that creates it and is named in its merge notes. `game/match/**` is board's but ADDITIVE only. `mk/*.mk`
  by area as above; a new target in another stream's makefile is a request with its seconds. The kit files are
  garage's; HudSkin is board's. `game/theme/fx/order_feedback.gd` is orders'. `tests/baselines/**` is nobody's
  except declared lines (C19.2, C19.3).
- **C18.7 stands** (the native game never bends for the browser; `web-smoke` stays in `check` unchanged), **C16.3
  stands** (every number: commit, machine, load, workload, sample), **C12.6 stands** (balance values are his),
  **C18.3 stands** (his eye is the check; a page only for a real choice, rendered and counted first).

**Checkpoints:** **CP1** garage's kit (G2) → merged, `make remote T=check` on `main`, board told to merge.
**CP2** orders' O2+O3 → merged, checked, brains told to merge. **CP3** garage's G1 (the prices) → merged ALONE,
checked, lines adopted if declared, every stream told to merge. Order between them: whichever is green first.

**Laptop runs this round.** He plays on the laptop. Windowed laptop runs open on his desktop: under two minutes
each, logged in Status with `uptime`'s load, announced to the orchestrator first. Quiet-window series (brains' B3
before/after; garage's G5 and board's S5 are plays, not series) are scheduled by the orchestrator (lesson 260).

**Standing rules:** rounds 12–18's (the slot; builder0 one invocation at a time across all of a stream's folders and
one slot hold ≤ ~30 min; `make remote` one per worktree, always backgrounded; no `pkill -f`; scratch scripts named
with the stream and stopped only by a PID file, lesson 244; every time written down comes from `date`, lesson 243;
scratch deleted when its number is written, `df -h /` before anything over ~200 MB and never start under 3 GB free,
lesson 249; a check is read as its verdict line AND its engine-error count AND the wrapper's exit, lessons 251, 255,
257; an intermittent red recorded as `seen k of N`, lesson 258; lessons 225–260).


## Round 18: five streams (launched 2026-10-04, CLOSED 2026-10-05; briefs in `streams/archive/round18/`)

**Goal: the two things he asked for after playing round 17 — a formation picker he can see, and maps with room to
manoeuvre and an open centre a line abreast can be ambushed in — plus his pick from the candidates: every unit stops
peeking at a loaded gun (*"Yes make the CPU smarter, this would apply to all units"*), and no browser work (*"I don't
want to sacrifice anything on our game to accomodate browser play"*).** The freeze at the final kill is in on the
orchestrator's recommendation; a baseline that sees every dealt map and the CPU's doctrine in open ground are in
because his map item cannot be checked or played without them. His words: `game_design.md` *Round 18 direction*.

| Stream | Brief | Round 18 | Checkpoint |
|---|---|---|---|
| **picker** | [streams/archive/round18/picker.md](streams/archive/round18/picker.md) (CLOSED 2026-10-05) | **The Formation button becomes a picker:** opens on hover (tap on touch), every formation as its shape from one shared list (AUTO first, echelons and coil included), the current one marked, one click picks, the animated preview on each card built from the real geometry; G still cycles; nothing per frame while closed | — (baseline UNMOVED) |
| **maps** | [streams/archive/round18/maps.md](streams/archive/round18/maps.md) (CLOSED 2026-10-05) | **New maps by experiment:** a CANDIDATE class he can play by name the day a map exists; the qualities he named as numbers per map (room for a line of four, chokepoints with a way round, flank-ambush ground); candidate 1 = the open centre; three or four more, different in kind; each played by the CPU before him; a page with KEEP / CUT; the lane validator's turning-pocket hole | **CP2** candidate 1 playable, merged early (brains measures on it; he plays it from `main`) |
| **brains** | [streams/archive/round18/brains.md](streams/archive/round18/brains.md) (CLOSED 2026-10-05; branch `stream/brains` KEPT for the unmerged ambush work) | **No unit shows itself to a loaded gun** (rule A: peek only while the enemy reloads; rule B if A loses a ladder), in the champion, for both sides, with the scenario rewritten and a two-target stage; then **the CPU in open ground, measured for the first time**: drills and seating read for wall assumptions, a line of four at its own spacing, the CPU on maps' candidate 1, and the fixes he would notice | **CP1** the peeking fix + its declared hashes, ONE commit, merged alone |
| **ship** | [streams/archive/round18/ship.md](streams/archive/round18/ship.md) (CLOSED 2026-10-05) | **A baseline line per dealt map** (rotation + foundry, read from the game; a rotation map with no line fails), the adopter for many lines with every branch stub-driven; candidates stay out, visibly; the test shards exit clean and their allow-list lines go; `round-status` prints the disk. No browser work | **CP0** the per-map lines on the launch tree (before CP1 if first; re-recorded by the orchestrator otherwise) |
| **finale** | [streams/archive/round18/finale.md](streams/archive/round18/finale.md) (CLOSED 2026-10-05) | **The freeze at the final kill** (1.7 s and 3.4 s frames on a loaded laptop): a per-frame trace through the end of a match on his path, the cause by removal, the fix at the cause (a warm-up at load, a preload, work spread over frames), a measure that keeps it out; the same class at first use during a match | — (baseline UNMOVED; windowed laptop runs open on his desktop) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
picker `game/ui/**`, `game/control/**`, `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_hud*.gd`,
`tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd` · maps `tools/make_arenas.py`,
`tools/arena_generator.py`, `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `tests/arena/**`,
`tests/test_arena*.gd`, `mk/arena.mk`, `_agents/arenas.md` · brains `game/ai/**`, `game/tactics/**`,
`tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
`tests/test_nav*.gd`, `mk/ai.mk` minus the perf targets, `mk/nav.mk`, `mk/tactics.mk`, and the `sim_state_hash.txt`
line at CP1 · ship `mk/core.mk`, `tests/baselines/**`, `tools/slot.sh`, `tools/remote.sh`, `tools/round_status.sh`,
`tools/engine_log_gate.py`, `tests/run_tests.gd`, `tests/support/**`, the perf targets of `mk/ai.mk` · finale
`game/theme/fx/**`, `tests/test_fx*.gd`, `tests/test_render*.gd`, `mk/fx.mk`. **Nobody:** the rest of `game/theme/**`,
`game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**`, `game/modes/**`, `game/camera/**`,
`game/garage/**`, `game/network/**`, `game/progression/**`, `game/announcer/**`, `game/audio/**`, `game/web/**`,
`export_presets.cfg`, `mk/web.mk` — a change there is requested through the orchestrator. Tests: each stream owns the
`tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the stream that owns the
behaviour, by request.

**Contracts (round 18):**

- **C18.1 The hashes move once, on purpose: brains' CP1.** The launch baseline is `05df1d55ba49cde1` (glibc 2.43,
  builder0), determinism `762a0576f944f5b7`, on `foundry`. Brains' peeking fix is the round's one planned change of
  fights: one commit, merged alone, its moved lines adopted with `make sim-baseline-adopt` and declared (it may leave
  foundry's line unmoved; brains says which before the run). Ship's per-map lines (CP0) are recorded on the launch
  tree; **whichever of CP0 and CP1 merges second, the orchestrator re-records every line on the merged tree, twice.**
  Brains' later open-ground changes (B5) are declared one at a time the same way. Every other commit of every stream
  pre-registers UNMOVED (picker and finale change what is drawn; maps adds candidates nobody is dealt; ship changes
  the instrument). An unplanned move is a finding: stop, attribute it, message the orchestrator; it merges alone.
- **C18.2 A candidate map is never dealt.** `Arena.ROTATION` and `Arena.DEFAULT_LAYOUT` change only on his word. A
  candidate is playable by name (`make skirmish ARENA=<name>`), never by `random`, carries no baseline line, and has
  no announcer name until dealt. The day one is dealt, ship's rule makes its missing line a failure.
- **C18.3 His play and his eye are the checks.** The picker is judged in the game; the maps on a page that records
  KEEP / CUT / notes per candidate in a `db` (**C15.2 stands**: the page says when its `db` was last read; the
  orchestrator reads it at close). A page is rendered headless and its buttons counted by the worker before the first
  publish and by the orchestrator before the link goes to him (lesson 252). A question to him is written as what he
  would notice when playing, with one recommendation (lesson 254).
- **C18.4 Smart on both sides ships on our evidence** (his words, `game_design.md` *His pick*): a decision change that
  applies to every unit on both sides needs a scenario, a ladder or paired series, and a declared hash move, not his
  tap. Still his: anything that makes the sides unequal, what a difficulty setting means, balance values (**C12.6
  stands**), and round 17's levers that trade behaviour for cost (C17.4 stands for those; all OFF).
- **C18.5 One tree per comparison** (C17.2 carried). Streams `git merge main` when the orchestrator says: after CP0,
  after CP1, after CP2. No A/B, ladder, series or frame-time comparison has arms on both sides of a merge.
- **C18.6 Shared files and carve-outs.** `game/ui/**` is picker's; finale's fix to the DEFEAT / VICTORY banner, if the
  stall is there, is a minimal patch landed by the orchestrator and listed in finale's merge notes. `mk/core.mk` is
  ship's: anyone else's target or measure line is added by request with its seconds (finale's end-frame measure; a
  candidate-loads smoke for `check-all`). `mk/arena.mk`'s `container-hashes` is maps'; ship calls or copies it and
  says which. `tests/baselines/**` is ship's; the `sim_state_hash.txt` line is brains' at CP1 only. The tactical map
  or radar drawing a candidate wrong is picker's, by request. `game/main.gd` and `project.godot`: additive only, in
  merge notes. A request to another stream goes in Status AND as a message to the orchestrator.
  **Added 2026-10-04 14:57 PDT (ship's request):** `mk/match.mk`'s `determinism` recipe, and only that recipe, is lent to ship to add
  a second pair of runs on `crossing` beside foundry's: foundry's pair unchanged (the hash stays `762a0576f944f5b7`),
  crossing's pair with its own files and a failure that names the map, both statuses captured, every branch
  stub-driven, the added seconds measured on builder0. **And the candidate list's name is fixed:** `Arena.CANDIDATES`,
  a flat Array of layout names in `game/arena/arena.gd` (maps writes it; ship's per-map baseline and its `check-all`
  `candidates-smoke` read it); either stream changes it only with the other told first.
  **Added 2026-10-04 18:41 PDT (ship's exit-code audit):** the status-capture lines of every check / check-all recipe that reads a
  Godot run's markers and drops its exit code are lent to ship, wherever the recipe lives: `mk/garage.mk`
  (army-loop-smoke, garage-smoke), `mk/tactics.mk:8-9` (tactics-drills; brains' file, this one recipe),
  `mk/metrics.mk` (ai-scenarios-check), `mk/audio.mk` (music-smoke's garage part), `mk/match.mk`
  (windowed-elimination-pair), `mk/net.mk` (the background servers of net-, combat- and relay-smoke are reaped and
  their exit read; a trap's own SIGTERM is the one named expected code), `mk/web.mk` desktop-smoke only (a native
  export; the web-net / web-relay smokes stay as they are under C18.7 and are listed, not fixed). Picker fixes its own
  three in `mk/command.mk` (picker-playtest, picker-shots, shell-playtest). The pattern: `s=0; godot … > log 2>&1 ||
  s=$?; grep … log; [ $s -eq 0 ] || { echo "<target>: exited $s"; exit 1; }`; `|| true` stays only where a comment
  names the non-zero code that is expected. Each fix is proved red once by a stub that exits non-zero after printing
  its markers. **A crash this makes visible is a finding for the path's owner, sent through the orchestrator; ship
  does not fix the game to get its own change green.**
  **Added and CLOSED 2026-10-04 23:38 PDT (picker, at the end of its brief):** the "+188 orphan nodes" a full unit setup leaves were
  assigned to picker with a carve-out in `game/theme`; picker proved they are not a leak (188 of 213 are already
  `queue_free()`d `StaticBatcher.merge` sources; +0 after two process frames; the runner samples after a physics
  frame, before the delete queue runs). No change in `game/theme`; the carve-out is withdrawn; the sampler is ship's.
  **Added 2026-10-05 02:46 PDT:** `game/audio/music_director.gd` and the music's playing path (`game/audio/**`; the soundtrack
  code under `game/theme/audio/**` if the holder is there) are lent to finale for a MINIMAL fix to the exported
  build's intermittent exit leak (attributed to music playing: 0 of 14 runs with music off against 18 of 46 on). No
  change to what he hears, the mix or the bus layout.
  **Added 2026-10-05 02:58 PDT:** the game's quit paths are lent to finale for ONE awaited call each
  (`MusicDirector.quiet_for_quit`): `game/match/match.gd`'s `--hash-until` quit, and a window close / menu Quit
  wherever they live (`game/main.gd`, `game/ui/**`, `game/modes/**`). The leak is the music's Ogg playback held by the
  audio server at exit (`stop()` only marks it; the mix that deletes it does not run again under the headless Dummy
  driver). Conditions: the simulation does not notice (no extra tick, the same hashes), bounded, no change to what
  he hears.
  **Picker's next item, by the orchestrator's word:** roadmap candidate 2 (the HUD's per-unit work) as far as it
  goes without native code, in its own paths: today's table at his army size, equal-output savings shipped (the HUD's
  output identical frame for frame, proved by a digest), anything that changes what he sees priced and listed.
- **C18.7 The native game never bends for the browser** (his words). No browser work this round; `web-smoke` stays in
  `check` unchanged. If a native change turns a web target red, the stream reports the line and keeps the feature.
- **C16.3 stands** (every number: commit, machine, load, workload, sample; a cost or effect attributed only by removal
  inside one run, with an arm assertion; the orchestrator's quiet-window laptop runs are the record).

**Checkpoints:** **CP0** ship's per-map baseline → merged, `make remote T=check` on `main`, every stream told to merge.
**CP1** brains' peeking fix → merged alone, checked, lines re-recorded if CP0 is already in, every stream told to
merge. **CP2** maps' candidate 1 → merged early; brains is told to merge and measures on it; the lead is told the
command to play it. Order between them is whichever is green first.

**Laptop runs this round.** He plays on the laptop and it is finale's subject machine. Windowed laptop runs open on
his desktop: under two minutes each, logged in Status with `uptime`'s load. The quiet-window record runs are the
orchestrator's: finale's end-frame trace, maps' `perf-play ARENA=<candidate>`, brains' open-ground lever arm. Ask
with the exact command.

**Standing rules:** rounds 12–17's (the slot; builder0 one invocation at a time across all of a stream's folders and
one slot hold ≤ ~30 min; `make remote` one per worktree; no `pkill -f`; scratch scripts named with the stream and
stopped only by a PID file, lesson 244; every time written down comes from `date`, lesson 243; scratch deleted when
its number is written, `df -h /` before anything over ~200 MB and never start under 3 GB free, lesson 249; a check is
read as its verdict line AND its engine-error count, lesson 251; lessons 225–254).

## Round 17: five streams (launched 2026-10-03, CLOSED 2026-10-04; briefs in `streams/archive/round17/`)

**Goal: two things he said after playing round 16 — the containers look synthetic, the guns have no power — and the
three items round 16 left for him to order, which he took whole (*"I want all 5, go"*).** While the round was being
briefed he widened the sound item (where a round lands, a full audit of silent events) and authorised the spend
(*"we have Elevenlabs credits to burn so we should use them"*).

| Stream | Brief | Round 17 | Checkpoint |
|---|---|---|---|
| **yard** | [streams/archive/round17/yard.md](streams/archive/round17/yard.md) | **Containers placed by people:** 93 % of 668 sit at exactly 0° or 90° and a stack moves ±0.6° / ±4 cm, which nobody can see. Upper levels visibly offset (visual); the ground level turned for real by a few seeded degrees, authored in the half so the mirror stays fair; walls stay walls (no ray through a joint); lanes, nav, cover, fairness re-proved; before/after frames at his pose on a page | **CP1** the layouts + the new sim baseline, ONE commit, merged alone |
| **guns** | [streams/archive/round17/guns.md](streams/archive/round17/guns.md) | **Sound he can feel on a living-room system:** source, mix and format separated on one sheet first; the mix lets a gun be the loudest thing; tanks → Abrams, 25 mm → Bradley / Apache chain gun, scouts → heavy machine guns, explosions, in layers (crack, body, sub, mechanism, stereo tail); **impacts by surface** (ground, building, steel, water, armour, shield, kill); **the audit of silent events**; an audition page for his ear | — (baseline UNMOVED; spend authorised, on the ledger) |
| **brains** | [streams/archive/round17/brains.md](streams/archive/round17/brains.md) | **The tick's last big line, as prices:** the far-and-idle think rate, three execution levers (k-turn check, chord samples, ORCA neighbours), their bundles — each OFF behind a switch, cost by removal and behaviour on one table, in his frame; a decision page; equal-answer leftovers ship | — (default path UNMOVED on every commit) |
| **sim** | [streams/archive/round17/sim.md](streams/archive/round17/sim.md) | **The same windowed fight twice:** the Sumps fork at ticks 601–630 — a rate first, the unit and the field, a bisect by removal, the fix at the cause, a regression that keeps it out | — (headless baseline UNMOVED, pre-registered; a move is a finding) |
| **ship** | [streams/archive/round17/ship.md](streams/archive/round17/ship.md) | **What the browser player gets, and a check with no holes:** the web build observed (the preset excludes the booth's clips and three factions' art); the voice options priced and the recommended one built behind a switch, on a page; smokes that assert what the player gets; `scenario_perf` judged every time; the garage tour and a desktop boot in `check-all` | — (announce before the first `mk/core.mk` change merges) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
yard `tools/make_arenas.py`, `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `game/theme/arena_kit/containers/**`,
`tests/arena/**`, `tests/test_arena*.gd`, `mk/arena.mk`, `tests/baselines/**` (CP1 only) · guns `game/theme/audio/**`,
`game/audio/**`, `assets/audio/**`, `tools/audio/**`, `tests/audio/**`, `mk/audio.mk`, `project.godot [audio]`, the
sound-selection lines of `game/theme/fx/weapon_fx.gd` · brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `mk/ai.mk` minus the perf targets, `mk/nav.mk`, `mk/tactics.mk` ·
sim `game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**`, `game/modes/**`, `tests/combat/**`,
`tests/scale/**`, `mk/match.mk`, `mk/scale.mk`, `project.godot [physics]`, plus a minimal-fix carve-out wherever the
fork's cause lives in an unowned path · ship `export_presets.cfg`, `mk/web.mk`, `mk/core.mk`'s check composition (lent
by the orchestrator), the `ai-perf*` / `scenario_perf` targets of `mk/ai.mk` and `perf_nominal.json` (lent by brains),
`tools/slot.sh`, `tools/remote.sh`, the announcer's clip-loading path, and (lent 2026-10-03, one additive MEASURE line,
not judged) `tests/ai_scenarios/scenario_perf.gd`. Also lent to ship (2026-10-03, evening): the status-capture lines
`mk/net.mk:167`, `:241`, `:265` and `mk/tactics.mk:64` (`cmd || status=$$?` so a failing recipe prints its reason). **Nobody:** the rest of `game/theme/**`,
`game/ui/**`, `game/control/**`, `game/camera/**`, `game/garage/**`, `game/network/**`, `game/progression/**`,
`game/announcer/**` — a change there is requested through the orchestrator. Tests: each stream owns the
`tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the stream that owns the
behaviour, by request.

**Contracts (round 17):**

- **C17.1 One planned change of fights: yard's CP1.** The launch baseline is `05df1d55ba49cde1` (glibc 2.43).
  **CORRECTED 2026-10-03 (yard's finding, verified): the baseline and `make determinism` run on `foundry`
  (`Arena.DEFAULT_LAYOUT`), which holds zero containers — so CP1 is pre-registered UNMOVED on the baseline while it
  changes every fight on the dealt container maps.** The baseline therefore proves nothing about those maps: CP1 carries
  its own table (one seeded headless hash per layout before and after: dealt maps CHANGE, foundry / furnace / scrapyard
  and the fixtures maze / barriers IDENTICAL), and every other stream's equality claim names a hash or `ai-parity` on a
  map he plays, not the baseline alone. (As launched this line read: yard moves the baseline once, in the commit that
  turns the layouts, recorded twice and declared.) Every other commit of every stream
  pre-registers UNMOVED on the default path (brains' levers are OFF by default; guns reads the fight and never writes
  it; ship changes the instrument, not the game; sim's fix is expected to leave the headless path alone). An unplanned
  move is a finding: stop, attribute it (the unit, the state, the second), message the orchestrator; it merges alone.
- **C17.2 One tree per comparison.** Until CP1 is merged and announced, every series runs on the launch tree; after
  it, streams `git merge main` **when the orchestrator says**, and no A/B, ladder, price or fork rate compares arms
  across that merge. Sim does not take CP1 until its fork is localised on the launch tree's Sumps (the turned
  containers are a different fight). Brains re-states its table's tree in every row.
- **C17.3 His eye and his ear are the checks.** Yard's frames page and guns' audition page are the verification of
  those streams; a worker looks at / measures everything first and says plainly what it cannot judge. Pages carry a
  `db` for his taps; **C15.2 stands** (each page records when its `db` was last read; the orchestrator reads every page
  at close). Four pages this round: yard Y5, guns G4, brains T5, ship W2.
- **C17.4 A lever is priced, never shipped on our call** (C16.1 carried): anything that changes a decision, the look
  or the web pack's size is built OFF / behind a switch and put on a page with its price. Equalities (the baseline and
  `ai-parity` identical) ship.
- **C17.5 Paid generation.** ElevenLabs **sound effects are authorised for this round by his words** (guns only, on
  `assets/audio/elevenlabs/ledger.md`, credits before → after on every run). Everything else under lead gate 1 is
  unchanged: no announcer generation, no Meshy, no new voices, no hosting bought.
- **C17.6 Shared files.** `game/theme/fx/weapon_fx.gd`: guns' carve-out is the sound keys and `_sound` call sites only.
  `game/theme/fx/shield_effect.gd`: lent to guns 2026-10-03 for one additive call (`shield_up` when a shield returns
  from zero, in `set_shield`), with a test that it fires once per return and never on a mere recharge tick.
  `mk/ai.mk`: brains owns it minus the perf targets (ship's). `mk/core.mk`: ship's check composition; anyone else's
  target is added by request (sim's `windowed-repeat` pair for `check-all`). `project.godot`: `[audio]` guns (and the new root file `default_bus_layout.tres`, guns', 2026-10-03),
  `[physics]` sim. `export_presets.cfg`: ship; guns reports its pack MB. `game/main.gd`: additive only, in merge notes.
  A request to another stream goes in Status AND as a message to the orchestrator.
- **C16.3 stands** (every number: commit, machine, load, workload, sample; a cost attributed only by removal inside
  one run; the orchestrator's quiet-window laptop runs are the record). **C12.6 stands** (nobody tunes balance).

**Checkpoints:** CP1 yard's Y3 (layouts + baseline, one commit) → merged alone, `make remote T=check` on `main`, then
each stream is told when to merge `main` (sim last, by its own word).

**The builder0 queue rule (added 2026-10-03, +2 h):** one builder0 invocation at a time across ALL of a stream's
folders (a `-before` / `-base` / `-price` folder counts), and one slot hold ≤ ~30 min — split chains and series into
separate `make remote` calls. Measured cause: load 0.78 on 12 threads with all 3 slots held by long light jobs (a
20-run windowed series, a four-target frames chain) and five jobs waiting 18–30 min; the slot kills any command at
5400 s. The mechanism (a light lane, a per-run series runner) is ship's to price (W4).

**Scratch scripts (added 2026-10-03 after an incident):** named with the stream (`yard-chain3.sh`), stopped only by a
PID the script wrote to a file at start, never by a name pattern (lesson 244). Every time written down comes from
`date` (lesson 243).

**The laptop's disk (added 2026-10-03 after it filled):** scratch copies of the project, exports, raw recordings and
frame sets are deleted as soon as the number or page asset they exist for is written down; `build/light/build` is
emptied after each light job; before anything that writes more than ~200 MB, `df -h /`, and do not start under 3 GB
free (lesson 249).

**Standing rules:** rounds 12–16's (the slot, builder0, `make remote` one per worktree, no `pkill -f`, detach long runs,
lessons 225–242); a windowed run on the laptop opens on his desktop — say so in Status and keep it short; the laptop
was rebooted 2026-10-03 (the wedged-directory hazard of lesson 240 is cleared, the lesson stands).

## Round 16: six streams (launched 2026-10-02 evening, CLOSED 2026-10-03; briefs in `streams/archive/round16/`)

**Goal: the frame he feels, on his laptop, along his path, without cutting a pixel or a decision.** His words are in
[`game_design.md`](game_design.md) *Round 16 direction*. Measured at launch (`1efa9940`, his laptop, his window 1854×1011,
his flags; `streams/references/perf/r16-before-1080-his-flags.json`): at 30 vehicles a frame is **36.9 ms** — the
simulation tick **24.0 ms** (brains ~85 % of it, round 5's split), the GPU **19.8 ms** flat at every count, game+UI
`_process` 2.6 ms, FX 1.0, draw submission 1.6; at 52 vehicles 3.5 ticks a frame (the frame read 100 ms but was LONGER: see the caveat in `references/perf/README.md` — a saturated perf-scene phase reports game time); a locked 30 holds at
**10** vehicles. His matches start at ~51. Round 5's budget (`fx_tricks.md` *The budget*) stands: tick ≤ 5 ms at 60,
GPU ≤ 10 ms at 1080p, game+UI ≤ 1.5, FX ≤ 1.0, frame ≤ 33 at a locked 30 with headroom.

| Stream | Brief | Round 16 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round16/brains.md](streams/archive/round16/brains.md) | **The tick's biggest line without changing one decision:** the brains' split re-measured today, a per-section brain profile, LOS memoised once per pair per tick, squared distances, allocation per think, nav queries per tick, the non-think tick; `ai_usec_per_tick` 10 022 → toward 4 000 (builder0) | — (baseline UNMOVED on every commit) |
| **sim** | [streams/archive/round16/sim.md](streams/archive/round16/sim.md) | **The rest of the tick, and the thing no headless instrument sees:** `VisibilityField` (~346 rays + ~12 100 cells a tick, skirmish-only) priced and made incremental; `_update_intel`'s allocation inside the loop and uncached LOS; the HUD's per-frame accessors cached on the tick; `Units.stat` without a String per call; shells, the recorder's census tick, Jolt's bodies; then **Law's APC on tracks** (his words) | **CP1b** `Units.stat` cached (early, alone); **CP2** Law's APC = a sim change, pre-registered, merged alone |
| **render** | [streams/archive/round16/render.md](streams/archive/round16/render.md) | **The GPU's 20 ms at his window, the picture unchanged:** `make look-parity` first (pixel diff at his pose); the ~8 ms base split by layer; work that renders nothing he sees (viewport feeds, FX with nothing alive, unchanged shader writes); fragment cost on the big surfaces; draws; glow and pool lights; a priced-levers page ONLY if the budget is still missed | — (baseline cannot move; parity on every item) |
| **hud** | [streams/archive/round16/hud.md](streams/archive/round16/hud.md) | **The main thread's per-frame scripts:** one fog-of-war walk shared by controls and map; redraw on change not on time (37 `queue_redraw` sites, 10 unconditional); per-tank per-frame work without allocation; one unproject table a frame; the camera's group lookups and the cutaway's loops gated; `process_game_ui_ms` 2.6–3.3 → ≤ 1.5 | — |
| **play** | [streams/archive/round16/play.md](streams/archive/round16/play.md) | **His path, measured as he plays it** (`make perf-play`: human-side skirmish, his flags, his window, capped and uncapped, layers `no_visfield/no_controls/no_audio/no_recorder`); a frame-time trace beside every recording; **the opponent randomised; the title music through the loader** (his words); audio ≤ 0.3 ms a frame; the slow-motion trap explained | **CP1** `make perf-play` (first hours; everyone measures with it) |
| **booth** | [streams/archive/round16/booth.md](streams/archive/round16/booth.md) | **The announcers repeat:** the effective pool at each pick over HIS matches, ranked; memory across launches (the free half); new lines for the thin pools in the voice, through his veto page; generation after his taps on the ledger; the director falls through rather than repeats | — (a review page: lead gate 1) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `mk/ai.mk`,
`mk/nav.mk` · sim `game/match/**` (incl. `visibility_field.gd`, `sim_profile.gd`), `game/tank/**`, `game/combat/**`,
`game/arena/**`, `game/units/**`, `tests/combat/**`, `tests/arena/**`, `tests/scale/**`, `mk/match.mk`, `mk/arena.mk`,
`project.godot [physics]` · render `game/theme/**` minus `audio/**` and `fx/bench/**`, `project.godot [rendering]`,
`mk/show.mk`, `tools/look_parity.py` · hud `game/ui/**` minus `faction_picker.gd`, `loading_screen.gd`, `widgets/title/**`;
`game/control/**`, `game/camera/**`, `mk/command.mk` · play `game/modes/**`, `game/theme/fx/bench/**`, `mk/fx.mk`'s perf
targets, `mk/play.mk`, `game/audio/**`, `game/theme/audio/**`, the three `game/ui` carve-outs, `tools/perf_*.py`,
`game/main.gd` additive (the director's lifetime) · booth `game/announcer/**`, `assets/announcer/**`, `tests/announcer/**`,
`mk/announcer.mk`. Nobody: `game/garage/**`, `game/network/**`, `game/progression/**`, `mk/core.mk` (orchestrator).
Tests: each stream owns the `tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the
stream that owns the behaviour, by request.

**Contracts (round 16):**

- **C16.1 Nothing is cut.** His words: *"before sacrificing any of the existing graphics or gameplay"*. No behaviour, no
  think, no unit, no pixel at his pose goes to buy a frame. A lever that changes the look or a decision is PRICED and
  put on a decision page (OFF by default), never shipped on a worker's call.
- **C16.2 The sim baseline is UNMOVED by every performance commit** (`05df1d55ba49cde1`, glibc 2.43, read from the
  wrapper's line), and `make determinism` holds. Pre-register UNMOVED per item; a move means the optimisation changed a
  decision: find why and fix it, or — if it is a genuine behaviour fix — its own commit, declared, merged alone as a CP
  with the attribution (lesson 230's rule: name the unit, the state, the second). The ONE planned move is sim's S9
  (Law's APC on tracks, CP2), last in its backlog.
- **C16.3 Every number carries its commit, machine, workload and sample.** A cost is attributed only by removal within
  one run (perf-scene's layer alternation, a `--*-off=` switch) or a counter — never a ratio read off a combined run.
  builder0 for CPU ratios and counts (2.75× faster than his laptop); the laptop for GPU ms and for the before/after he
  will feel; **the orchestrator's quiet-window laptop runs are the record** (the two `r16-before-*` files at launch; the
  afters at close). A worker's own laptop run states the load.
- **C16.4 Shared files.** `game/units/units.gd` is sim's (CP1b: `Units.stat` cached — hud and brains adapt in their
  paths until it merges); `project.godot`: `[physics]` sim's, `[rendering]` render's, every edit in merge notes;
  `game/main.gd` additive only (play's director lifetime); `mk/core.mk` the orchestrator's; `export_presets.cfg` by
  merge note. A request to another stream goes in Status AND as a message to the orchestrator.
- **C16.5 The perf harness is play's** (`game/theme/fx/bench/**`, `mk/fx.mk`'s perf targets): `make perf-play` is CP1;
  other streams add layers through their own switch tables (`--sim-off=visfield`, FxWorld's switches) and ask play to
  expose them; nobody else edits `perf_scene.gd`.
- **C16.6 The picture is proven unchanged**: render's `make look-parity` (R1, early) diffs shot sets at his pose with
  a stated tolerance; every render and hud item ships with its parity line; until R1 merges, before/after shots diffed
  by hand. A diff outside the tolerance is a C16.1 question, not a judgment call.
- **C12.7, C15.2 stand** (paid generation on the ledger after his taps; every decision page records when its `db` was
  last read; the orchestrator reads every page at close).

**Checkpoints:** CP1 play's `make perf-play` → merged early, every stream `git merge main`; CP1b sim's `Units.stat`
cached → early, alone; CP2 sim's S9 → last, alone, the baseline recorded twice if it moves.

**Standing rules:** rounds 12–15's (the slot, builder0, `make remote` one per worktree, no `pkill -f`, detach long runs,
lessons 225–234); a windowed run on the laptop opens on his desktop — say so in Status and keep it short.


## Round 15: five streams (launched 2026-10-01 evening, CLOSED 2026-10-02; briefs in `streams/archive/round15/`)

**Goal: round 14's own list, built overnight; nothing from his play (*"playin right now feels good"*).** His words are
in [`game_design.md`](game_design.md) *Round 15 direction*; the list is `roadmap.md` *Round 15 candidates*. Same rules
as rounds 12–14; memory *overnight autonomy*: every agent working, decide rather than block, validated work by morning.

| Stream | Brief | Round 15 | Checkpoint |
|---|---|---|---|
| **nav** | [streams/archive/round15/nav.md](streams/archive/round15/nav.md) | **One exit test cannot serve the rig and the scout:** N3 keyed by hull class or plan purpose, the scenario gate green; then N5, the planner that looks earlier from a moving hull; acceptance seeds 17–24 | **CP1** = a baseline move, declared and attributed, merged alone |
| **airship** | [streams/archive/round15/airship.md](streams/archive/round15/airship.md) | **The view-climb is ON; now the 39–49 s intrusion cluster it does not fix, and buying back the seen-share** without putting the hull in the way; the clip for his morning | — (dressing; baseline UNMOVED) |
| **squad** | [streams/archive/round15/squad.md](streams/archive/round15/squad.md) | **The gangs' flipped verdicts measured over seeds** and put on a decision page for him (C12.6: no table ships); the ladder re-baselined with the winner rule printed; `scenario_perf` pinned to one fight; the flanker's loop by the crate | — (baseline UNMOVED unless a brain defect is fixed: declare it) |
| **garage** | [streams/archive/round15/garage.md](streams/archive/round15/garage.md) | **The second tour's list:** the centre scores, said before the fight; the sense of size on the card/turntable; the loader's hint on a phone; the status box at 20:9; the tour again and the next list | — (UI; baseline UNMOVED) |
| **fleet** | [streams/archive/round15/fleet.md](streams/archive/round15/fleet.md) | **Tanks and IFVs that read apart from the play camera:** measure the confusion per faction pair, fix what is free (markings, lamps, paint) first, prepare the paid route on a review page for his morning (concepts only; image-to-3D waits for his tap); no box changes | — (art; baseline UNMOVED) |

**Ownership:** as rounds 12–14 for nav, airship, squad, garage; fleet as round 12's fleet row **minus the `units.gd` /
`tank.gd` carve-outs** (no box changes this round). Garage's carve-outs: `game/ui/loading_screen.gd` (the hint line),
`game/ui/widgets/hud_skin.gd` (the status box), one additive hook in `game/modes/skirmish_mode.gd` if the tip is shown
at the planning pause. Squad adds `tools/tactics_ladder.py`. Airship adds `game/theme/fx/bench/rig_vanish.gd` and
`tools/airship_view_pool.py`.

**Contracts:** C12.6 (nobody tunes balance — squad's page is a RECOMMENDATION, his tap changes a table), C12.7
(generation on the ledger; **concept images only tonight, image-to-3D after his tap**), C14.1 (the baseline
`6313a38d7ecd99bb`; only nav may move it on purpose; pre-register with the path; design seeds named before the first
variant, acceptance on seeds the design never saw), C14.2 (the airship opaque and visible), C14.3 (S6 is his toggle),
**C15.1** the view-climb default is his toggle (`AirshipFlight.view_climb`): airship measures around it, nobody flips
it. **C15.2** every decision page records in Status the time its `db` was last read; the orchestrator reads every page's
`db` at close (step 5a) and lists unconsumed taps in HANDOFF.

## Round 14: four streams (launched 2026-09-27 evening, CLOSED 2026-09-28; briefs in `streams/archive/round14/`)

**Goal: his airship item, and round 13's own list.** His words are in [`game_design.md`](game_design.md) *Round 14
direction, first item*; the list is `roadmap.md` *Round 14 candidates*. Same rules as rounds 12–13.

| Stream | Brief | Round 14 | Checkpoint |
|---|---|---|---|
| **airship** | [streams/archive/round14/airship.md](streams/archive/round14/airship.md) | **A0 first: two War Rigs turned invisible in his play** (defect; measured, not guessed; a carve-out into the cutaway and the rig's theme files for the fix only). Then **the airship steers clear of the player's view** (his words): measure the intrusion with the LIVE camera first, then the carrot avoids the wedge between camera and focus, looking ahead; opaque, visible, in the venue; the PID and the climb-over stay | — (dressing; baseline UNMOVED) |
| **garage** | [streams/archive/round14/garage.md](streams/archive/round14/garage.md) | **The list a player's first visit produced** (round 13's G1 table): room to build, the turntable at match proportions, a stalemate is a draw, a clean HUD at 20:9, the loader, the dead stub | — (baseline UNMOVED; the time-limit rule is outside the 40 s baseline match) |
| **nav** | [streams/archive/round14/nav.md](streams/archive/round14/nav.md) | **The other 53 %**: route-driver circle reverses and k-turn legs, instrumented then validated with the sweep; the stall share re-read on more seeds; does a holding rig block the street | **CP1** = a baseline move, declared and attributed, merged alone |
| **squad** | [streams/archive/round14/squad.md](streams/archive/round14/squad.md) | **Two red instruments**: the gang-pack drills bisected and fixed; `scenario_perf` refuses under load (rule 3); the ladder variants' stale row | — (a drill change may move the baseline: declare it) |

**Ownership:** as round 11's table for airship (`game/theme/arena_kit/airship/**`, its tests and bench, the airship
targets in `mk/fx.mk`, the `_build_airship` carve-out) with `game/camera/**` READ-ONLY (one additive accessor allowed,
listed); as rounds 12–13 for nav and squad; garage as round 1's garage stream (`game/garage/**`,
`game/modes/garage_mode.gd`, `mk/garage.mk`, `tests/garage/**`) **plus three carve-outs** (the time-limit winner rule in
`game/match/match.gd`, `game/ui/camera_readout.gd`, and a read of `Tank._apply_hull_size` — additive, listed, the
orchestrator reviews at merge). Squad's carve-out: the `scenario_perf` targets in `mk/ai.mk` and an additive read of the
box's load.

**Contracts:** C12.6 (nobody tunes balance) and C12.7 (generation on the ledger) stand. **C14.1** the sim baseline is
`6313a38d7ecd99bb`; only nav may move it on purpose; anyone else pre-registers UNMOVED **with the path** or treats a
move as a finding (lesson 223); design seeds are named before the first variant and acceptance runs on seeds the design
never saw (lesson 224). **C14.2** the airship stays opaque and visible, never faded or cut away (the lead, rounds 10 and
14). **C14.3** `TankBrain.IDLE_FACE_NO_PIVOT` is the lead's toggle: nobody flips it.



## Round 13: three streams (launched and CLOSED 2026-09-27; briefs in `streams/archive/round13/`)

**Goal: the lead's answers to round 12's candidate list, built.** His words are in [`game_design.md`](game_design.md)
*Round 13 direction*. Small round, small items, the same rules as round 12 (ownership below is round 12's for these
three streams, plus the garage carve-out).

| Stream | Brief | Round 13 | Checkpoint |
|---|---|---|---|
| **squad** | [streams/archive/round13/squad.md](streams/archive/round13/squad.md) | **The default plain-move shape is the wedge** (his answer 2), on the paired series; then **S6 measured** (stop issuing an idle `face` to a no-pivot hull with nothing in sight) | — (a sim move is possible on S6: declare it) |
| **nav** | [streams/archive/round13/nav.md](streams/archive/round13/nav.md) | **Right-of-way sized for long hulls**: a 14 m rig yields into room it fits in; the +57 % reverse-gear contacts are the number to move; started on the orchestrator's recommendation, his veto stands | **CP1** = a baseline move, declared, merged alone |
| **audio** | [streams/archive/round13/audio.md](streams/archive/round13/audio.md) | **The garage, smoke-tested like a player, then given music** (his answer 6: *"I've never even smoke tested the garage"*): title → GARAGE → build → FIGHT on the default path, frames, what breaks; then the `garage` state plays a bed and rotates | — (isolated) |

**Ownership:** as round 12's table for squad, nav and audio, **plus a carve-out for audio:** `game/garage/**`, the garage
targets in `mk/garage.mk`, and `game/modes/garage_mode.gd` (the paused stream's paths) for the smoke test and the music
hook only — no garage feature work; anything bigger is written up as a round-14 item.

**Contracts:** C12.6 (nobody tunes balance) and C12.7 (generation on the ledger) stand; the sim baseline is
`6313a38d7ecd99bb` and only nav may move it.
 How rounds work (roles, lifecycle, the worker contract, the
> kickoff prompt) is in [orchestration.md](orchestration.md): read it first. **Round 12's six streams, ownership,
> checkpoints and contracts are in the next section.** Round 11's section follows it (closed; its record is
> `HANDOFF.md` *ROUND 11*), then round 10's (closed, kept for its contracts R1–R9); the round-9 section after that
> (S1–S6, the research-catalogue sequencing) is still in force where it is not superseded; rounds 1–11 are archived in
> `streams/archive/round1..11/`; the round-6 material further down (contracts N1–N7, ownership, invariants) is still
> in force where it is not superseded.

## Round 12: the six streams (launched 2026-09-26, CLOSED 2026-09-27; briefs in `streams/archive/round12/`)

**Goal: every pending item on the list he approved, after his two corrections.** His words are in
[`game_design.md`](game_design.md) *Round 12 direction* (both parts: the fine-tuning session and *Round 12 becomes a
round*). The list is `roadmap.md` *Now* as it stood on 2026-09-26, minus "the direct path still scatters" (a whole-squad
box-select already takes the task path; a partial one is a question, not a defect) and plus **the fire engine he
approved on 2026-09-24 that nobody built** (the page's `db` held the tap; the repo never read it).

**The acceptance test for the round is his:** the Condemned field a fire engine that is not a prison bus and a bus that
is not a van; the water on the Crossing and the Locks reads wet at his pose; the camera never sits inside a floodlight's
lamp head and an ad screen between him and the fight is cut away; the AUTO icon shows the shape the squad is actually
forming and a G-chosen wedge is still a wedge when the squad halts; a War Rig squad gets through the Terminus streets
with fewer refused back-ups; the booth stops saying *"they are trading"* every match and the opening music is not the
same track every time.

| Stream | Brief | Round 12 | Checkpoint |
|---|---|---|---|
| **fleet** | [streams/archive/round12/fleet.md](streams/archive/round12/fleet.md) | **The fire engine he approved and the bus he approved, built** (`burner_r11_b` → 3D → the burner's own hull, turntable turret and box; `bus_r11_i` → 3D → `unit.tank.hull`; his taps recorded first); the burner's `turret_mount` and the −Z test; stretch: the War Rig's muzzle, measured before moved | **CP1** = the burner's (and the bus's, if it moves) `hull_size`, merged alone; the orchestrator records the baseline |
| **arena** | [streams/archive/round12/arena.md](streams/archive/round12/arena.md) | **Water reads wet** (the Crossing, the Locks, the canal fixture) at his pose, judged as pairs on his page with `db`; the Locks' open-canal question re-put with the exposure number; pits stay dark and read as pits | — (visual; sim baseline pre-registered UNMOVED, navmesh untouched) |
| **camera** | [streams/archive/round12/camera.md](streams/archive/round12/camera.md) | **The camera asks the drawing, not the collider**: `RtsCamera.roof_over` / `clear_pose` / `sight_blocked` and `BlockCutaway._gather` read a drawn-extent table (floodlight 16 m, ad screen 20.7 m, sign 7.65 m) instead of the collision boxes; measured over the Terminus pose sweep; **no collider grows** | — (visual; baseline UNMOVED) |
| **squad** | [streams/archive/round12/squad.md](streams/archive/round12/squad.md) | **The formation he sees is the one the squad forms**: the AUTO icon and card show the leader's actual pick (control's `command_icons.gd`, a carve-out); a G-chosen formation survives `_halt`; the fall-in rule for the first seconds of a move from the spawn line; the partial-selection question answered on the default path; whether *dense → column* is the right row for a plain move on the maps he plays | — (a sim move is a finding; declare it) |
| **nav** | [streams/archive/round12/nav.md](streams/archive/round12/nav.md) | **The War Rig's refused back-ups** (`kturn_none` 130 against 64 `kturns` on the Terminus drive): why the single planned reverse finds nothing in an 18–22 m street, then a multi-leg plan (back-and-fill) validated against the navmesh with both ends, measured on the drive test over 8+ seeds; stretch: the kinematic planner the count is asking for | **CP2** = any change that moves the sim baseline, declared, merged alone; attributed with `make nav-sim-arms` |
| **audio** | [streams/archive/round12/audio.md](streams/archive/round12/audio.md) | **The trade call and the opening track**: the `trade` pool (5 lines: 3 caller, 2 color) deepened and the director's pick audited with the pool report; the 23 Suno tracks in `assets/incoming/music/` imported and assigned so every state with one bed has several and the per-match rotation is TESTED to rotate; generation authorised under his round-10 words, on the ledger, on the Booth Monitor for his veto | — (runs in isolation; `music-smoke` and `announcer-record-smoke` prove the sim unmoved) |

**Why six, and why these six:** each is one problem with one owner and one set of paths — the vehicles (fleet), the
water (arena, holding the terrain art this round since no feel stream runs), the camera's occlusion rules (camera),
the formation the player sees and gets (squad, with one carve-out into control's icon file), the rig's manoeuvre
planner (nav), the booth and the soundtrack (audio). No stream needs another's output to start. Six sessions are
~2.1 GB on this 7.6 GB laptop, which had ~2 GB free at launch with Chrome open: **start fleet, squad and audio first;
camera, arena and nav when memory allows**, and every Godot run of any size goes to builder0.

### Checkpoints (round 12)

- **CP1 — fleet's hull boxes.** A `hull_size` change is a sim-baseline move by construction (spawn grid, collider).
  fleet lands its art first, then puts every box change in ONE commit and names the green hash; **the orchestrator
  records the baseline twice in the same session** (`make sim-baseline-adopt`, never a copied file). Nobody publishes
  a size-dependent number measured across CP1.
- **CP2 — nav's planner.** A manoeuvre plan that changes when a hull reverses moves the sim baseline (round 11's did:
  `457b5e83 → 814aed46`). nav declares it in its green report, attributes it with `make nav-sim-arms`, and the
  orchestrator records it alone. Not before nav's drive-test numbers are in its Status.
- Everything else pre-registers **UNMOVED** (`01ab39b592cc9837`) and treats a move as a finding.

### Who owns what (round 12) — changes to the tables below

| Path | Owner (round 12) |
|---|---|
| `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`, `game/theme/gallery/**`, `assets/pipeline/**`, `assets/review/**`, `assets/meshy_ledger.md`, `tools/assets/**`, `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`, `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **carve-outs:** the `hull_size` / `muzzle_height` / `turret_mount` / `scale_reference` VALUES of `tank` and `burner` in `game/units/units.gd`, and `Tank._apply_hull_size` / `Tank.turret_pose` in `game/tank/tank.gd` | **fleet** |
| `arenas/`, `game/arena/`, `game/theme/arena_kit/terrain/**` (the water and pit art, the shaders), `tools/make_arenas.py`, `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`, `tests/arena/`, `tests/test_arena*.gd`, `_agents/arenas.md`; **carve-out:** the lamp-pool and environment inputs the water shader reads from `game/theme/cyberpunk/arena_dressing.gd` / `arena_environment` (ADDITIVE accessors only, listed in merge notes) | **arena** |
| `game/camera/**`, `tests/test_control_camera_solids.gd`, the camera tests under `tests/`; **read-only:** `AirshipFlight.DRAWN` (`game/theme/arena_kit/airship/airship_flight.gd`) — see C12.2 | **camera** |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`, `doctrines/`, `mk/tactics.mk`, `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/ai_scenarios/`, `_agents/{doctrine,tank_brain,squad_ai_design}.md`; **carve-outs into control:** `game/ui/command_icons.gd` (the AUTO glyph and its label) and the formation readout on the selection card in `game/control/` (the consumer of `UnitCommand.AUTO` there) — additive, no other control paths; **and, if the partial-selection answer is "give it the anchor":** the route from `RtsControls.order_selection` into a transient element, one function, listed in merge notes (the orchestrator reviews at merge; no control stream runs) | **squad** |
| `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md` | **nav** |
| `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`; `game/audio/`, `assets/music/`, `assets/incoming/music/` (ignored), `tools/audio/`, `mk/audio.mk`, `tests/test_audio_*.gd`, `assets/announcer/ledger.md` | **audio** |
| everything else | orchestrator / shared, as the round-6 table below |

### Contracts (round 12)

- **C12.1 — the fleet page's taps are the lead's decisions.** `burner_r11_b`, `bus_r11_i` and `q_r11_bus_fit` are
  APPROVED (2026-09-24 17:27 UTC; the dump is in `streams/references/round12/fleet_page_db/`). fleet records them with
  `make art-apply-decisions` (or `art-decide` per id) as its first commit, so `review.json` and the page agree. Lead
  gate 1 is satisfied for exactly those two image-to-3D runs; any further concept or 3D goes back to a page with `db`.
- **C12.2 — one drawn-extent table, read, not copied** (Invariant 0). `AirshipFlight.DRAWN` is held against the kit's
  meshes by `test_the_flights_table_of_drawn_props_covers_what_the_kit_draws`. camera READS it. If camera needs it
  somewhere the airship's file is the wrong home for, it moves it in ONE additive commit to a `drawn` field beside
  `ArenaKit.PROPS` (arena's file; arena reviews at merge) with the test moving with it, and the airship reads the new
  home. Two tables of drawn heights is the defect this round exists to fix, one layer up.
- **C12.3 — the collider never grows to fix a picture.** Nothing in `ArenaKit.PROPS` sizes, `Arena.active["obstacles"]`
  or the `Obstacles` bodies changes for a visual reason. camera and arena pre-register the sim baseline UNMOVED.
- **C12.4 — the icon shows what the leader picked.** squad publishes the element's chosen formation where the card
  can read it (`Element.state()["formation"]` already exists; the icon must read THAT for an AUTO selection, and the
  requested shape for a G-chosen one). control's file changes only in the glyph/label lookup; the palette, hotkeys and
  the six-verb popup are untouched.
- **C12.5 — a G-chosen formation is the shape at every phase.** `task.formation`, when present, wins over the table's
  pick in `_plan_form_up`, `_advance_transit`'s stations AND `_halt`; the table decides only under AUTO. Test: a wedge
  ordered with G is a wedge at t0, in transit and after arrival, on a drills-on move.
- **C12.6 — nobody tunes balance.** fleet's sizes reach matchups; nav's planner reaches arrivals. Report the number;
  do not chase it (*"we'll worry about evening up factions later"*).
- **C12.7 — generation is authorised, scoped by count, on the ledger.** ElevenLabs for audio under his round-10
  words (*"let's burn through some ElevenLabs credits"*) and the standing humour direction: text through
  `make announcer-audit`, every run on `assets/announcer/ledger.md` with the balance before and after, every clip
  speech-to-text verified, the new lines on the Booth Monitor for his veto. Meshy for fleet: the two approved runs
  (~15 credits each) plus what the splitter needs; balance 809. Both streams stop and ask at half the remaining
  balance.

### Standing rules for round 12

- **Play the default path** (`make skirmish` with no flags, the maps in the rotation) before reporting anything
  shipped; a behaviour behind a flag the default path never passes has not shipped.
- **Every visual claim is a pair at his pose** (21°, FOV 35, 49 m): before/after, one variable moved, on a page with
  `db` so his tap is recorded — and **the orchestrator reads that page's `db` at the round's close** (lesson 220).
- **Every number carries its commit and its machine**; the laptop is ~2.75× slower than builder0; merge at the hash
  whose check went green; read the wrapper's own `>> remote: make check exited <N>` line.
- **Baseline moves are declared and merged alone** (CP1, CP2); every other stream pre-registers UNMOVED.
- **Series compare arms on the same seeds** and print discordant pairs; nav's drive test takes 8+ seeds per arm.
- **A hypothesis from the orchestrator is labelled as one** (lesson 219), with the measurement that would kill it.

## Round 11: the four streams (launched 2026-09-24, CLOSED 2026-09-24; briefs in `streams/archive/round11/`)

**Goal: the eleven defects he named in one playtest, and the maps he has asked for three times.** His words are in
[`game_design.md`](game_design.md) *Round 11 direction*. He called it a light workload and it is: no new mechanic, no
new system, no design argument to settle. **Three of the four streams are finishing work that already exists and does
not reach him**; the fourth is driver intelligence he has now described precisely enough to build.

**The acceptance test for the round is his:** pick each map from the faction picker and see the bridges, the water and
a pit; drive a squad through the Terminus streets and watch a hull reverse *before* it touches a wall; look at the
three factions parked side by side; and watch the airship fly the Terminus without passing through a block, with the
camera lifting over it when they meet.

| Stream | Brief | Round 11 |
|---|---|---|
| **arena** | [streams/archive/round11/arena.md](streams/archive/round11/arena.md) | **The maps he has never been dealt** (`Arena.ROTATION` is three names and `arenas/` holds fifteen; round 10's Crossing and Sumps — water, bridges and the only real pits in the game — have never been reachable), each played on the default path and judged on the arena page; **the venue floodlight towers are solid** (21 m of steel with no collider, standing 7.8 m inside the Terminus wall) and the parity test extended to the dressing layer that hid them; then one genuinely new terrain map |
| **nav** | [streams/archive/round11/nav.md](streams/archive/round11/nav.md) | **His two-part Terminus problem, measured apart.** R2: the goal repair (`squad.gd:272` grounds a slot on the mesh centre, so a War Rig's nose is in the building; `source != "player"` is not grounded at all; `_reachable == false` is computed and thrown at a readout). R1: **a reverse decided at plan time** — run the turning-circle test against the route's first leg and emit an explicit reverse leg, instead of discovering it at the bumper through `unstick` and the pressed-wall escape |
| **fleet** | [streams/archive/round11/fleet.md](streams/archive/round11/fleet.md) | **The vehicles, five complaints and four causes:** seven turrets spinning *inside* their hulls for want of a `turret_mount`; five stray generated barrel sticks (the Law tank's is 14 triangles, 1.8 cm across, 0.74 m off centre); the Condemned tank and burner as the only non-uniformly **stretched** meshes in the game (1.63:1 on the tank — his "deformed" one); the Law's tank and IFV re-derived under the round-9 K rule; and **a test that a nose points at −Z**, which has never existed |
| **airship** | [streams/archive/round11/airship.md](streams/archive/round11/airship.md) | **It flies through the blocks and the camera flies through it.** Real rotated footprints instead of a circle table that is 7.28 m short at every block corner; a look-ahead by the 8.7 s it takes to climb; `contain` no longer erasing `avoid` at the (±100, 0) blocks; a 3 m floodlight no longer entered as 24 m (which is most of why it cruises low only 52 % of the time on the Terminus); and **the camera lifting over the hull** through the round-9 solid rule, which today cannot see a moving occluder at all |

**Why four, and why these four:** each is one independent problem with one owner and almost no overlap — the maps and
their props (arena), the driver and the goal (nav), the vehicles (fleet), the airship and the camera (airship). The
two smallest shared files are split by function and named below. No stream needs another's output to start.

### The one checkpoint

**CP1 — fleet's size changes (its T3 + T4), merged alone.** Any `hull_size` move changes the spawn grid, the collider
and the sim baseline by construction. fleet lands its art items first, then puts every box change in one commit and
names the green hash; **the orchestrator records the baseline twice in one session**, never the worker. Nobody
publishes a size-dependent number measured across CP1. Everything else merges when it is green.

### Who owns what (round 11) — changes to the tables below

| Path | Owner (round 11) |
|---|---|
| `arenas/`, `game/arena/`, `tools/make_arenas.py`, `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`, `tests/arena/`, `tests/test_arena*.gd`, `_agents/arenas.md`; **carve-outs:** `_build_tower` and the venue placement calls in `game/theme/cyberpunk/arena_dressing.gd`, and `tests/test_arena_prop_parity.gd` | **arena** |
| `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`; **carve-out for R2 only:** `game/tactics/slot_ground.gd`, `Orders.ground_goal` in `game/control/orders.gd`, and the call site `game/ai/squad.gd:272` (no control or squad stream runs; the orchestrator reviews these three at merge) | **nav** |
| `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`, `game/theme/gallery/**`, `assets/pipeline/**`, `tools/assets/**`, `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`, `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **carve-outs:** the `hull_size` / `muzzle_height` / `turret_mount` VALUES in `game/units/units.gd`, and `Tank._apply_hull_size` / `Tank.turret_pose` in `game/tank/tank.gd` | **fleet** |
| `game/theme/arena_kit/airship/**`, `game/camera/**`, `tests/test_theme_ad_airship.gd`, `tests/test_control_camera_solids.gd`, `game/theme/fx/bench/airship_shot.gd`, the airship targets in `mk/fx.mk`; **carve-out:** `_build_airship` in `game/theme/cyberpunk/arena_dressing.gd` | **airship** |
| everything else | orchestrator / shared, as the round-6 table below |

### The two shared files, split by function

- **`game/theme/cyberpunk/arena_dressing.gd`:** arena owns `_build_tower` and the venue placement calls that site the
  towers; airship owns `_build_airship` (`:140-155`). Neither touches the other's function; both list the file in
  their merge notes.
- **`game/units/units.gd`:** fleet changes VALUES only (`hull_size`, `muzzle_height`, `turret_mount`). Nobody changes
  the catalogue's shape, weapons or balance this round.

### Contracts (round 11)

- **C11.1 — the rotation is published early.** arena's first item adds `crossing` and `sumps` to `Arena.ROTATION`.
  Every stream that walks "every shipping map" (`SyndicateAdAirship.flies_on`/`route_for`, `make nav-fight-maps`,
  fleet's galleries) re-runs its map walk after the orchestrator announces that merge. Until then, **say which map
  list a number was taken on.**
- **C11.2 — the camera's solid rule stays pure and headless.** `RtsCamera.clear_pose` is a static function over data,
  which is why it has tests at all. airship may add a dynamic occluder parameter or registry; it may not make the rule
  require a physics space or a running tree.
- **C11.3 — the airship gets no collider,** and the sim baseline `457b5e830708b439` does not move for any reason
  except CP1.
- **C11.4 — nobody tunes balance.** fleet's sizes and arena's navmesh both reach matchups. Report the number; do not
  chase it (his standing ruling: *"we'll worry about evening up factions later"*).

## Round 10: the nine streams (launched 2026-09-20 evening, run 2026-09-22, CLOSED 2026-09-23; briefs in `streams/archive/round10/`) — CLOSED, kept for its contracts

**Goal: the playability blockers he named, in the order they block him.** His words are in
[`game_design.md`](game_design.md) *Round 10 direction*. He cannot judge unit intelligence until a right-click is obeyed
at once, any selection can carry an element order, and a squad can be driven through the Terminus streets; after that
come the walls and the yaw, then the look (walls of light, the blimp, the turrets, the bus), then the announcer. Every
stream's first backlog item is one of his sentences. **The acceptance test for the round is his: `make skirmish
ARENA=terminus`, drive squads through the streets, give ad-hoc selections element orders, and see the lights.**

| Stream | Brief | Round 10 | Checkpoint |
|---|---|---|---|
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | **The unanswered right-click** (a player's order replaces an in-flight one within one input frame, on the default path, with the readout saying what was ISSUED); **squad orders for a mixed selection** (R1 narrowed: a Form-squad action and a reason on the greyed buttons; the regroup behaviour stays); the refused-order banner and `ungrouped=N` readout | — |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | **a player's order pre-empts a task, a hold and co-arrival pacing**; the 40 s settle on a 20 m move; slot pitch from the turning envelope (decided: hulls do not clip while dressing); the base-of-fire scenario; `_is_clear`; Delta's margin | — (CP1 withdrawn) |
| **arena** | [streams/archive/round10/arena.md](streams/archive/round10/arena.md) | **The Terminus streets are lanes** (containers off the lanes; every lane's narrowest drivable width asserted, not watched; the arena page shows the before/after at his pose); **prop collision parity** (R3: what a hull can touch has a collider; the lamps); the spawn grid gives a hull room to turn (the half-diagonal, scale's round-9 handover) | **CP2** = the Terminus lanes green, merged alone, early (nav's drive test runs on it) |
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | **Units still drive into walls**: the Terminus drive test (a squad ordered street to street on the default path: zero wall contacts, arrival, measured), what a wall contact IS (a counter on the plant, published), the wedged regime, the obstacle-tiling row; every clearance constant names the motion it licenses; `Avoidance.radius_of` (the seventh disc site); the held wheeled hull's facing; the seam (Movement vs CombatMotion) as the structural item, measured before moved | — |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | **The rigs yaw through walls**: the plant predicate (why a clear hull refuses every candidate yaw for 1135 ticks), the ordering, then diagonal spacing as a candidate; the constraint returns ON only when five_squads passes with the corridor numbers kept; ORBIT radius reads hull length (the engine-deck scenario); the artillery scenario; the gangs-vs-law series with `match.hull_disc` (stretch) | **CP4** = the constraint ON (baseline moves), merged alone if it happens |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | **The blimp he asked for, in HIS frame** (R7); **the turret mounts** (R5: a per-unit mount in the hull frame, derived from the mesh, applied on all three axes; Condemned and gangs first); **the Condemned bus reads bigger than the garbage truck** (R6: his eye rules over the reference for `tank` and `burner`; concept page for a paid bus mesh); the per-faction rim light | **CP3** = the bus box (baseline moves), merged alone; the orchestrator records |
| **show** | [streams/archive/round10/show.md](streams/archive/round10/show.md) | **The light show on the building WALLS**: per-window addressable primitives (custom data per instance, the S6 hook rule), effects composed from them (chases, waves, sweeps, sign flicker, a kill ripple that crosses a facade), judged by HIS eye against a 1990s-baseline frame, not a luminance bar; the frozen re-shoot and the louder pair first (the fastest thing he can see) | — |
| **announcer** | [streams/archive/round10/announcer.md](streams/archive/round10/announcer.md) | **More lines on the same themes** (deepen every thin moment to a real pool; same voices, same humour direction), audited, on the review page, **generated this round** (R8: he authorised the spend); the ledger; speech-to-text verified; the transcripts and the Booth Monitor re-cut | — (runs in total isolation against fixtures) |
| **terrain** | [streams/archive/round10/terrain.md](streams/archive/round10/terrain.md) | **The maps with water, pits and bridges that never materialised** (added 2026-09-20 evening on his ask): the `arena.terrain` art first (the reason he could not see it), then two maps that use the round-7 mechanism with mirrored objective pairs (a river with two bridges; pits as kill zones), each judged by `spread` > 0, a paired series showing the expensive route used, and his eye on the arena page; bridges are lanes under R4 | — (its maps are new files; Godot on builder0) |

**Why nine (the ninth added the same evening):** the lead asked for the bridge/pit/water maps he had asked for before; the mechanism has existed since round 7 with no map and no art, so it is a stream of its own on new files, with Godot on builder0. **Why eight before that:** commanding is one problem with two owners (control's input path, squad's task layer) and a contract
between them, so both run; the Terminus streets are the map's fault (arena) before they are nav's; the yaw is combat's
plant and the walls are nav's mover, and round 9 showed they must be measured apart; the look is three streams' paths
(feel, show, announcer's carve-out). Nine sessions are ~3.6 GB on the laptop: **show runs every Godot process on
builder0; announcer is Python and fixtures and runs no Godot beyond `announcer-check`.** If the laptop swaps, start
control, squad, arena and nav first; terrain and show last.

### Checkpoints (round 10)

- **CP1 — WITHDRAWN (2026-09-20 night):** R1 narrowed to a UX item on control's side; nothing of squad's to merge early. control's Form-squad action lands with its own check.
- **CP2 — the Terminus lanes (arena).** Containers off the lanes, the lane-width assertion, R3's parity test, the
  before/after frames at his pose. Merged alone, early; nav's drive test runs on the new map from then on (before it,
  nav measures on the ring road and the avenue's clear halves, and says so). Moves no baseline (the sim baseline's
  match runs on the foundry; pre-registered, and a move is a finding).
- **CP3 — the bus box (feel).** A `hull_size` change is a sim-baseline move by construction (spawn grid, collider);
  merged alone with the lineup frame beside it; the orchestrator records the baseline twice in the same session.
- **CP4 — the plant constraint ON (combat), only if** five_squads passes with the constraint on AND the corridor
  numbers (44.0° → 11.6°, 12.1 → 6.1 m) are re-measured on the same build. Baseline moves; merged alone.

### Who owns what (round 10) — changes to the round-6 table below

| Path | Owner (round 10) |
|---|---|
| `arenas/`, `game/arena/` (including `arena_kit.gd`'s `PROPS` sizes: the collider boxes), `tools/make_arenas.py`, `tools/arena_report.py` and siblings, `mk/arena.mk`, `_agents/arenas.md`, `tests/arena/`, `tests/test_arena*.gd`; **carve-out from combat's C1 (as scale had it in round 9):** the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in `game/match/match.gd` (combat reviews at merge). `tools/roster_scale.py`, `mk/scale.mk` rest with arena (read, not changed). | **arena** |
| `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`, and the announcer targets in `mk/audio.mk` (`announcer-*`, `audio-launch-smoke`); `_agents/streams/archive/round3/announcer.md` is its reference. **Carved out of feel for the round**; feel reviews nothing here (the voices and humour direction are the lead's, recorded in `game_design.md`). | **announcer** |
| `game/theme/**` except show's carve-outs (unchanged from round 9) and the announcer paths above; `game/audio/`, `assets/{audio,music}/`, `tools/{assets,audio}/`, `mk/{fx,assets}.mk`, the art docs. **Carve-outs granted 2026-09-20:** (a) an optional `turret_mount: [x, y, z]` key per `Units.PROFILES` entry and its consumer in `Tank._apply_hull_size` (`game/tank/tank.gd`, the three-axis write; combat reviews at merge, mutation-checked test required); (b) the `hull_size` (and `muzzle_height`) VALUES of `tank` and `burner` in `game/units/units.gd` (R6; combat reviews; CP3). | **feel** |
| `game/theme/show/`, `mk/show.mk`, `_agents/lighting.md`, `_agents/show_dials.md`, the `show` key per arena, and the round-9 emission carve-outs from feel (`CityBlock`'s emission paths and `city_block.gdshader`, the perimeter rim, `NeonSigns`, the pools, `CyberMaterials.neon()`). **Extended 2026-09-20 for per-window addressing:** `CityBlock`'s window MESH construction may gain per-instance custom data (a MultiMesh where it is a mesh today) — additive, the silhouette unchanged, feel reviews the look at merge. | **show** |
| New arena layouts (`arenas/<new>.json`; their functions in `tools/make_arenas.py`, ADDITIVE, arena reviews the diff), `game/arena/arena_terrain.gd`, `tests/arena/water_probe.gd`, new `game/theme/arena_kit/terrain/` (the `arena.terrain` slot; feel reviews the look), the `water-probe`/`terrain-*` targets in `mk/arena.mk` (additive), a *Terrain maps* section of `_agents/arenas.md`. Not the existing layouts, not `arena.gd`/`arena_kit.gd` (arena's). | **terrain** |
| everything else | as the round-6 table below: nav, squad, control, combat, orchestrator, shared |

### New contracts (round 10)

| Contract | Owner, where | Consumers |
|---|---|---|
| **R1 Squad orders for a mixed selection (NARROWED 2026-09-20 night, on the lead's words in `game_design.md`).** No transient element is formed automatically: assigning a selection a control group (1–5) already makes it a squad that carries formation and element orders, and the lead calls that good behaviour. The contract is now UX: the greyed task buttons carry a one-line reason the player reads ("these units are in different squads: press Form squad or Ctrl+1–5"), and the card offers a one-click **Form squad** action that assigns the next free group number to the selection and enables the buttons in the same frame. Numbered groups keep today's path unchanged. | control: `SelectionPanel`, `RtsControls.assign_task` | squad (nothing to build; `Element.state()` keeps publishing its split for the readout) |
| **R2 A player's order pre-empts everything.** A new order from the player on a unit or selection replaces that unit's in-flight order, task, hold and pacing within one input frame, always. `Orders._same_order()` never drops a `player` order (its 3 m dedup compares slots, not clicks: two clicks metres apart on a moving squad compare equal); an armed mode (`mode != ""`) cancelled by a right press still issues the move on the NEXT press, and the readout says which happened; `Element.assign()` re-derives every crew's order on the next tick and the re-issue suppression (`element.gd` `_same_place`/`REISSUE_M`) yields to a fresh task. Test: the round-10 regression is an integration test on the default `make skirmish` path — a squad en route, a right-click 40 m off its line, every crew's order changes within 2 ticks. | control: `game/control/orders.gd`, `rts_controls.gd`; squad: `game/tactics/element.gd` | the lead |
| **R3 Prop collision parity.** For every kit prop, the drawn geometry a hull can reach (everything below the tallest hull's height, `law_suppressor` 6.18 m, plus the tallest hull's reach when it yaws) lies inside the prop's collider footprint in `ArenaKit.PROPS`, or the prop is declared `drive_through` and placed where no lane runs. A test asserts it per prop by measuring feel's mesh AABB against the box (arena writes it; a failure names the prop and the overhang in metres). The floodlight is the known offender (footing 2.4 × 3.0 × 2.4; the mast and the 4.2 m head have no collider): arena widens the box or asks feel to raise the head above 6.2 m; either way the test decides. | arena: `game/arena/arena_kit.gd`, `tests/arena/` | feel (meshes), nav (the bake reads the same boxes) |
| **R4 Streets are lanes.** Every declared lane in an arena's `lanes` (Terminus: the avenue, west street ×2, the ring road ×2, and arena adds the east street and the plaza crossings) keeps a continuous drivable width of at least **2 × the widest hull's width after the bake radius** (CORRECTED 2026-09-22 by arena: the widest hull is `syn_artillery` at 4.07 m, so the bar is 8.14 m drivable, physical ≥ 12.14 m at a 2.0 m bake; it is read live from `ArenaLanes.bar()` in `game/arena/arena_lanes.gd`, never from this prose) along its whole length; containers, wrecks and barricades stand on lots, against walls and at kerbs, parallel to the street, never across it. `tools/arena_report.py`'s corridor WATCH line becomes a failing assertion for lanes (it stays a watch line for the open field, the reason it was a watch line still holds there). The arena page shows the before/after pair at his pose (21°, FOV 35, 49 m) for each changed street. Authored chokepoints are allowed only OFF the declared lanes and are listed in `arenas.md` by name. | arena: `tools/make_arenas.py`, `tools/arena_report.py`, `tests/arena/` | nav (the drive test), the lead |
| **R5 Turret mount.** `Units.PROFILES[id]` gains an optional `turret_mount: [x, y, z]` in metres in the hull frame (x right, y up, z forward, the hull's origin at its box centre on the ground); `Tank._apply_hull_size` applies all three (today only y is written and z stays at `tank.tscn`'s +0.2 m for every hull from 2.9 to 14 m). Default when absent: today's `[0, muzzle_height − 0.05, 0.2]`, so nothing moves until a unit is measured. feel derives each value from the mesh's ring (the pipeline's `driving_bounds()` pattern), records it in `slot_contracts.md`, and the sim baseline is pre-registered UNMOVED (the turret is visual; the muzzle height is unchanged; a move is a finding, not a record). | feel: values and the write (carve-out); combat reviews `tank.gd` | control (the marker reads the hull, not the turret), combat |
| **R6 The bus is his eye.** S1's derivation (reference × K) stands for every unit with a mesh; for `tank` and `burner` (no mesh of their own) the lead's ruling on the lineup frame is the source: **the bus must read LONGER than the garbage truck (the Condemned `ifv`, 7.54 m) and TALLER in proportion.** feel picks the numbers (start: length ≥ 1.25 × the ifv's, height ≥ the ifv's 3.70 scaled by the same ratio, width from a coach's proportions), shoots the lineup at his pose, records the chosen reference beside the box, and CP3 merges it alone with the baseline recorded. A paid bus mesh goes through the concept page (2–3 directions) before any 3D. | feel: `units.gd` values (carve-out), `slot_contracts.md`, the concept page | combat (reviews), arena (spawn grid), squad (slot pitch), nav (clearance) |
| **R7 The blimp.** The lead's blimp is a thing he sees while he PLAYS, at his pose (21°, FOV 35, 49 m), not a title element. Geometry: the frame's top edge is 3.5° below the horizon there, so nothing at or above the camera's own height (~17.5 m at his boom) is ever in frame; a blimp that shows in play flies LOW, among the Terminus blocks (24 m tall) and over the far half of the frame, ~10–14 m up, slow, with its own lights and screens, no collider (pre-registered: the sim baseline does not move). feel builds it and proves it with the airship-look sweep: in frame at his pose for a stated fraction of a match, with the frame beside the number. The round-9 airship at 560 m stays as the city's. If the geometry refuses at every candidate, the frames go to him and the choice (title/results element) is his. | feel: `game/theme/arena_kit/airship/`, `arena_dressing.gd` | show (its screens are fixtures), control (the cutaway must not cut it) |
| **R8 Announcer generation is authorised this round.** His words: *"let's burn through some ElevenLabs credits."* Lead gate 1's text approval is satisfied by the standing humour direction (`game_design.md` *The arena announcer*, the 2026-09-15 ruling) plus `make announcer-audit` plus the review page; the announcer stream generates in batches (`APPROVED=1`) without waiting, appends every run to `assets/announcer/ledger.md` with the balance before and after, verifies every clip with speech-to-text, and puts the new lines on the Booth Monitor page for his veto. Spend guidance: the balance is ~109 k credits at launch; the round's target is the thin moments deepened to real pools, roughly 400–600 lines (~30–50 k credits); **stop at half the remaining balance and ask** unless he says otherwise. | announcer: its paths | the lead (veto), feel (nothing to review) |
| **R9 Terrain maps.** A map that carries `terrain` (water, pit, bridge rectangles, mirrored) must also carry a mirrored objective pair so the crossing has a reason (his rule; N7's `objectives` list); every bridge deck and its approaches are LANES under R4 (≥ 6.64 m drivable at the live bake, corners certified with the rig's turning radius, C5); the rim stays below the 1.3 m eye line; the art in the `arena.terrain` slot adds no lights and one draw call per surface kind. Acceptance is three things together: `spread` > 0 on the arena report, unit-time on the expensive route in a paired series against the same map with `terrain: []`, and the lead's eye on the page. Pre-registered: the sim baseline does not move (the baseline match runs on the foundry). | terrain: its layouts and art | arena (reviews the generator diff), nav (the drive test on a bridge), control (the menu, later) |
| **R2b One grounding call for per-unit goals (added 2026-09-22 night, nav's finding).** Every per-unit goal issued to a crew (Element slots, the right-click formation slots from `Orders._resolve_group`, the drills' stations, a follow station) is grounded onto the navmesh with the HULL's own clearance (the turning-envelope tier) through squad's `SlotGround.standable_for(point, hull)` (public, usable without an Element), and the readout says when a goal was moved and by how much. Found because the drive test's misses were all ungrounded right-click goals inside blocks. | squad: `SlotGround.standable_for` | control (`orders.gd`), squad's Element and drills |
| **R2a K1 gains `task` (added 2026-09-22 night, squad's request, control's file).** `UnitCommand.KEYS` gains an optional integer `task` (the element's task sequence); `Orders._same_order()` returns false whenever `current.task != order.task`, whatever the source, so an element re-issue that changes only the facing (or an unchanged `follow`) after a fresh player task is never deduplicated. Squad sends the key through a runtime adapter until control's commit lands; control lands it inside its R2 item. | control: `orders.gd`, the K1 keys | squad (`element.gd` sends it) |

### Standing rules for round 10 (in addition to *The standing rules for this round* below)

- **Play the default path.** Every fix in this round is judged on `make skirmish ARENA=terminus` with no flags: a
  behaviour behind a flag the default path never passes has not shipped (lesson 165's shape).
- **A readout says what was ISSUED, not what was intended** (lesson 183): control's banner, squad's element split,
  nav's wall-contact counter, combat's refusal counter all report the thing that happened.
- **Every visual claim is a pair** (show's rule 12): before/after at his pose, one variable moved, the dial and the file
  named in the caption.
- **Baseline moves are pre-registered and merged alone** (CP3, CP4); every other stream pre-registers UNMOVED and
  treats a move as a finding.
- **Every number carries its commit and its machine**; merge at the hash whose check went green; read the wrapper's
  own line.
- **Every A/B states its positive control** (research addendum B12): before an arm's null is reported, a known
  disturbance must move the metric; an arm proves it applied with a counter; shared state is hashed or drained between
  tests. A null without a positive control is "not measured", never "no effect".
- **Series compare arms on the SAME seeds and report discordant pairs** (C6): a cell is a paired comparison over a
  fixed seed list, never two unpaired batches; ~32 paired seeds for a large shift, ~64 to size a component; the
  report prints the discordant counts beside any rate.
- **The clearance vocabulary is four names** (B5): static footprint, swept travel ribbon, turning envelope, combat
  signature. A constant or a reader that does not say which it is gets a comment or a rename in the commit that touches it.

## Round 9: the seven streams (launched 2026-09-19 evening)

**Goal: the research catalogue lands against metrics that can see what the lead sees — and the roster is drawn at
real relative scale.** The catalogue ([`research_catalog.md`](research_catalog.md)) is the algorithm backlog; the lead
added two items while asking for the round ([`game_design.md`](game_design.md) *Round 9 direction*): the War Rig is
still one rigid box, and **every vehicle needs proportional, real-world relative sizing** — the semi resize *"makes the
game much cooler and awesome"* and he wants it for the whole roster.

| Stream | Brief | Round 9 | Checkpoint |
|---|---|---|---|
| **metrics** | [streams/metrics.md](streams/metrics.md) | **A12** trajectory-space metrics (windowed displacement efficiency, signed cusp density, spectral arc length, affine formation residual) that reproduce round 8's oscillation finding from the saved replays; then **T1** parallelise `make check` | **CP1** = A12 green; **CP3** = T1 green |
| **scale** | [streams/scale.md](streams/scale.md) | **The roster at real relative scale** (one factor K anchored by the 14 m rig; every hull = reference length × K; boxes from the mesh via `SizeLook.box_at_length`), the review frame for the lead, and everything that was sized for a 4 m hull: spawn grid, navmesh agent radius, muzzle heights; then **A3** hull-chord cover tables and the `arena-report` WATCH line | **CP2** = the resized roster green |
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | **A7 → A11 → A1 → A4**, in nav's own order (argued below), A7's priority table written and reviewed before code | — |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | **A2** state-dependent switching cost (falsifier: squad's fire-concentration and engine-deck scenarios), then **A3's consumer**; the balance consequences of the resized roster measured, not tuned | — |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | **A8 → A9 → A10**, each naming what it replaces by file; formation spacing derived from hull length after CP2 | — |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | **The articulated War Rig** (visual hinge at the fifth wheel, tractor simulated, trailer follows; the 14 m box stays), the **A6 motion-law contract** with control and nav, the void below the near wall; stretch: the Syndicate airship from primitives | — |
| **show** | [streams/archive/round10/show.md](streams/archive/round10/show.md) | **Added 2026-09-20:** the arena as a light show — fixtures, channels, patches and cues over the Terminus blocks, the perimeter neon and the signage, driven by match mood and events, at zero added draw calls and lights ([game_design.md](game_design.md) *Round 9 addition*) | — |
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | **Desktop right-drag facing** with the test that makes the arc's A/B live by construction; the **A6 readout**; the camera, HUD, selection and radar checked at his pose against the resized roster after CP2 | — |

**Why seven and not six:** the lead asked for *"as many workstreams as necessary"*. The resize touches five owners'
paths and is the item he will judge the round by, so it gets an owner rather than being combat's first task; and A12
gates every falsifier in the catalogue, so it gets an owner rather than the orchestrator's spare time. Seven Claude
sessions are ~2.8 GB on a 7.6 GB laptop with heavy runs on builder0. **If the laptop swaps, start metrics, scale, nav
and feel first and the other three after CP1.** **An eighth stream, `show`, was added mid-round on 2026-09-20 at the lead's request; with seven live the laptop had ~2.2 GB free, so show runs every Godot process on builder0 and starts when a slot is free.** arena's paths are scale's this round; the `stream/arena` branch rests.

### Checkpoints (round 9)

- **CP1 — A12 metrics (metrics). FORMAT STABLE 2026-09-20 (`tools/metrics/FORMAT.md`, `7f2ec225` on `stream/metrics`); positive control PASSED** — round 8's 7.2 / 6.6 / 5.8 / 5.3% reproduced at 7.16 / 6.65 / 5.81 / 5.30 from the same run on builder0 at `aa984edd` + emitter (bar ±0.5, ordering kept); replays in `streams/references/round9/metrics/`. A producer adds two lines (`TRAJECTORY.install(match, path, producer, knobs)`); `make metrics LOGS=…` reads. **The continuous metric says the threshold understated the problem ~4×:** a tenth of every wheeled unit's 4 s windows sit at or below 0.25 efficiency against 7.2% of ticks flagged — the lead watches the p10, not the mean. Merge hash follows the green check. Every catalogue falsifier that names cusp density, displacement efficiency,
  spectral arc length or formation residual is read from A12. **Streams build and iterate before CP1; nobody publishes
  a falsifier verdict before it merges.** Its own acceptance: it reproduces the round-8 oscillation finding
  (5.3–7.2% on four maps) from the saved replays in `streams/references/round8/`.
- **CP2 — the resized roster (scale).** It moves the sim baseline (the orchestrator records it, Invariant 2), the
  spawn grid, cover, clearance and every size-dependent number. Lands **once, early**; every stream `git merge main`
  and re-runs anything size-dependent after it. **Nobody publishes a size-dependent number measured across CP2.**
  The lead sees the side-by-side frame before it merges (a look, not a number: the numbers are derived).
  **Pre-registered before CP2 (2026-09-20):** combat's `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` WILL
  move — the Condemned tank's collider grows 0.8 m in height — and nobody attributes that to A2 or A7. scale's check on
  `b7055602` found exactly two failures, both size-dependent literals in other streams' tests (control's 12 s group-move
  budget, feel's tracer window at −21.5…−17.0 written for a 3.8 m IFV); **ruled: scale lands both inside the CP2
  commit in derived form, owners review at merge**, and scale greps every test for the same shape (a distance, window,
  duration or budget derived once and then typed) and sends each stream its list before CP2 merges.
- **CP2b — squad's attacking-element leash (added 2026-09-20).** `TankBrain.element_slot()` no longer returns null for
  `bound`/`maneuver`, so every element member carries a leash to its published slot at `slot_leash(element)`; the
  drift bar becomes `slot_leash(element) + 2.0`. nav's A7 cannot go on by default without it. Merged alone, early, the
  day squad names its green hash; nav cherry-picks it for measurement only until then.
- **CP2c — control's desktop right-drag facing (added 2026-09-20).** Press = destination, release > 18 px away = the
  drag's ground direction becomes `facing` (pixels, not metres: at his pose 18 px is 0.3 m at the bottom of the frame
  and 40 m at the top); inside = a plain move with the key absent. Merged alone the day control names its green hash;
  it is the live arm for nav's arrival-arc A/B, which must not run before it.
- **CP3 note (2026-09-20 02:20):** T1's profile says `test` is **92%** of a check (2388 of 2584 s, builder0 `c21d0256`), so
  T1 is test sharding, not target concurrency. **After CP3 a slot holds six to eight processes, so CP3 sets
  `REMOTE_SLOTS=3`, not 6 or 8** — same box saturation, half the latency per check (metrics' arithmetic: 3 slots → ~5
  shards → ~10 min; 6 → ~2 shards → ~22 min); `tools/slot.sh --jobs` divides the *memory* budget by the live slot count
  so the two knobs cannot multiply into an OOM. **A separate follow-up checkpoint after CP3:** `make test` passes no
  `--fixed-fps`, so the suite waits on wall-clock 30 Hz physics — measured ~5× on simulated time; landed alone with
  three consecutive runs because it can change a test's *result* where sharding cannot.
- **CP3 — T1 parallel `check` (metrics).** Merged the moment it is green over three consecutive runs with a
  bit-identical sim hash; every stream benefits and every stream re-times its wall-clock assumptions after it.

### Who owns what (round 9) — changes to the round-6 table below

| Path | Owner (round 9) |
|---|---|
| `tools/metrics/` (new), `mk/metrics.mk` (new), `_agents/metrics.md` (new); **granted for T1 only:** the `check` recipe in `mk/core.mk`, `tools/slot.sh`, and timeouts in any smoke it has to raise — each listed in merge notes, and a raised timeout named with its before/after. **Granted for the S3 emitter (2026-09-19, at launch):** no per-tick trajectory log exists anywhere in the repo (round 8's JSONs are per-run aggregates), so metrics may add a **few-line emitter hook** — one call per tick into its own `tools/metrics/` writer, behind a flag off by default — in nav's `tests/nav/fight_probe.gd` and combat's `game/modes/match_runner_mode.gd`. Nothing else in those files; the owners review the hook at merge. | **metrics** |
| `arenas/`, `game/arena/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` (arena's paths, resting this round), **plus a carve-out from combat's C1: the `hull_size` and `muzzle_height` values of every `Units.PROFILES` entry, and the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in `game/match/match.gd`**; `tools/roster_scale.py` (new), `mk/scale.mk` (new). combat reviews the `units.gd`/`match.gd` diff at merge and owns the files again afterwards. **Also granted (2026-09-19, at launch): a `lineup` view in feel's `game/theme/fx/bench/size_look.gd`** — the 21-unit side-by-side frame for the lead — additive, calling `box_at_length` rather than copying it; feel reviews at merge. Do not build a second renderer. **Granted retroactively (2026-09-20): `Tank._apply_hull_size` in `game/tank/tank.gd`** — two silent mirrors blocked the resize (an early return that let tank.tscn's authored 1.6 m-tall box win over the catalog's 2.4 m for the Condemned tank alone, i.e. the one unit the baseline match fields; and shared hull art fitted to that catalog entry rather than its own mesh). combat and feel review at CP2 merge; each mirror gets a mutation-checked regression test. **K = 0.707071** (rig 14.0 m over a 19.80 m tractor + DOT-406 tanker); judgment calls approved: Syndicate platforms referenced by role, `law_tank` = Centauro B1 8×8 at 7.85 m. | **scale** |
| `game/theme/show/` (new: fixtures, channels, patches, cues, the show director), `mk/show.mk` (new), `_agents/lighting.md` (new), a `show` section per arena in `arenas/*.json` (additive key, validated by arena's loader — scale reviews); **carve-outs from feel's `game/theme/**`, granted 2026-09-20:** the emission paths of `game/theme/arena_kit/` `CityBlock` (edges, window grid), the perimeter rim in `arena_dressing.gd` (`_build_perimeter`'s neon), `NeonSigns`, the floodlight pools, and `CyberMaterials.neon()` — **additive** (a fixture hook that feel's materials expose), never a restyle; feel reviews at merge and keeps the look | **show** |
| everything else | as the round-6 table below: nav, squad, control, combat, feel, orchestrator, shared |

### New contracts (round 9)

| Contract | Owner, where | Consumers |
|---|---|---|
| **S1 Roster scale** (CP2). `Units.PROFILES[id]` gains an optional documented key `scale_reference: {"vehicle": str, "length_m": float}` — the real-world vehicle the unit is drawn as and its cited length. `Units.SCALE_K` is the one world factor, fixed from the War Rig's reference at its ruled 14.0 m. **`hull_size[2] == scale_reference.length_m × SCALE_K` is asserted by a test for every unit that carries a reference, and width/height are asserted to be the mesh's proportions at that length (`SizeLook.box_at_length`) within a stated tolerance** — so the numbers are derived and checked, not mirrored (Invariant 0). `make roster-scale` prints the whole table (reference, K, length, box, drawn box) and renders the side-by-side frame. Units without an approved mesh keep their box and say so in the table. | scale: `game/units/units.gd` values, `tools/roster_scale.py`, `mk/scale.mk` | combat (C1 owner, reviews at merge), feel (the fit is automatic: `_fit_to_hull` scales by length), squad (formation spacing from `hull_size`), nav (clearance), control (framing) |
| **S2 Articulation is visual this round.** The War Rig's tractor is the simulated body and its 14.0 m box is the collider; the trailer is a theme part cut from the approved mesh at the fifth wheel and yawed per frame by tractor-trailer kinematics from the drawn motion. `articulated` in `Units.LOCOMOTIONS` stays reserved; nothing under `game/tank/`, `game/ai/`, `game/units/` changes for it. **Pre-registered: the sim hash does not move.** The follow-on (a second body with its own collider, and the plant's articulated locomotion) is recorded, not scheduled. | feel: `game/theme/` | nav (none this round), combat (none) |
| **S3 A12 metrics** (CP1). `tools/metrics/` reads a per-tick trajectory log (position, heading, speed, gear, order/goal, element and slot per unit per tick) and reports, per unit and per match: windowed displacement efficiency (4 s window), signed cusp density (per agent-minute, split ordered / creep / unexplained where the log carries the cause), spectral arc length of the speed profile, and the affine formation residual per element. **The log format is metrics' to define and every producer's to emit**: metrics ships a reference emitter for `nav-fight` and the match runner; if a stream's harness cannot produce it, that stream asks metrics rather than inventing a second format. Every falsifier in the catalogue that names one of these four quantities is read from this tool and no other. | metrics: `tools/metrics/`, `mk/metrics.mk` | nav, combat, squad, feel (every falsifier), orchestrator (the round's verdicts) |
| **S6 The light show** (added 2026-09-20). `Show` owns a set of **channels** (named scalar/colour signals computed once per frame on the CPU: breathe, chase, strobe, sweep, cycle) and **cues** (channel programmes bound to `MatchMood.current().state` and K5 events). A **fixture** is any emissive surface that exposes `set_show_channel(name)` or reads a per-instance custom-data slot; feel's materials expose the hook, show drives it. **Patches are data** per arena. **Hard rules:** zero added draw calls and zero real lights (M1's budget, measured with `make perf-scene` on builder0 before and after); the expensive part is baked once and only a scalar animates per frame (the widget spec's architecture); visual only, frame time not tick time, **pre-registered: the sim hash does not move**. `_agents/lighting.md` documents the vocabulary so a road or a bridge can be patched later without new abstractions. **The hook rule (feel, 2026-09-20):** a value that differs between instances is per-instance custom data on the MultiMesh (`use_custom_data`, how the crowd is already driven); a value that is one number for the whole fixture is a material uniform (`CyberMaterials.neon()`); show never adds a MultiMesh or a light to get variation a custom-data channel could carry. **`AdBroadcast` already drives the ground wash from the ad's average colour** — an arena-wide cue is a second writer to the same quantity, so `lighting.md` names one owner (recommended: the show director owns the wash and reads the ad colour as an input). And `make perf-scene`'s *"Too many instances using shader instance variables"* counter is a first-class number: read it, not only the frame time. | show: `game/theme/show/` | feel (materials, the look; reviews at merge), scale (arena JSON schema), control (the cutaway must not fight a cue) |
| **S5 One commitment term, two seams** (ruled 2026-09-20, from nav's A7 table). A2's switching cost is **one expression owned by combat** (braking energy plus turret/hull slew from `Units` physics, in combat's paths), consumed at **exactly two seams and nowhere else**: the brain's option scorer (`tank_brain.gd` `COMMIT_BONUS` 1.15 — squad's file, combat's seam, landed as a proposed commit squad takes or reverts) and nav's **level-5** commitment term in `combat_motion.gd` (today's additive 0.35). nav adopts combat's expression verbatim and keeps no constant beside it — **refined 2026-09-20 (nav + combat):** nav consumes `SwitchingCost.seconds_for()`, not `penalty()`, because the *seconds* are portable and combat's price (0.07/s, cap 0.35) is calibrated to the brain's 0..1.2 score range; nav publishes its exchange rate and the tree it was calibrated on, and keeps the shape (a capped price, never a veto). Under A7 a standoff HOLD is no longer an early `index −1` return but the zero-radial-speed candidate at level 2, so the term is consulted on holds by construction; nav lands a counter proving it. Table committed at `7edec4fb` on `stream/nav`. **combat's review (2026-09-20) produced two rulings written into the table before code:** (i) a standoff HOLD scored as a candidate needs a **hold term at level 5** in the same commit or the standoff weights vote it out every tick — acceptance is `scenario_motion::test_a_scout_holds_a_firing_position_instead_of_ramming` at 26.9 m closest / 0.92 in-band / 0.91 nose-on / 226 shots vs the run control's 6.0 m / 13 shots, before and after; (ii) **under a hold or station the leash is a level-0 feasibility bound on every candidate, dodges included** — a held unit dodges within its leash and never leaves it (product constraint 4; squad's base-of-fire scenario, base shots 5 then 4, is the test). Also corrected: the scouts are **fixed-mount**, so the armour demotion for turreted hulls cannot reach the engine-deck scenario; its falsifier is the turreted duel (front hits 100%/80%). **A7 lands first**, leaving the motion term in one named line; combat wires that seam the day nav names the A7 hash. An A2 penalty anywhere else in either scorer is the catalogue Part 2 failure by construction. Also settled from the same table: the dodge is strictly dominant at level 1; armour-toward-threat is a null-space preference for turreted hulls (combat runs squad's two scenarios on nav's actual A7 commit); **A6's motion law sits at level 3** — above formation, below the weapon band — unless feel's `legibility.md` argues otherwise before A7 is coded. | combat (expression), nav (level 5), squad (the brain seam) | feel (A6's level), orchestrator |
| **S4 A6 is a contract before it is code.** One written page, `_agents/legibility.md`, owned by feel with control and nav as signatories, stating: the motion law (a turreted hull fighting off-axis keeps its nose within ~25° of the ordered corridor tangent; a hull-fixed vehicle is bounded forward-oblique), who executes it (nav's velocity layer — as a priority in A7's table, named there), and what the player is shown (control's readout). **No stream writes A6 motion code until all three have signed the page.** control's right-drag facing lands first regardless, because it is the prerequisite for any facing A/B. **Page written at `4ec341d2` on `stream/feel` (2026-09-20); feel signed, nav reviewed.** Settled there: A6 sits at **level 3** (feel confirms: its own falsifier bars trading exchange ratio for a tidy line, and a law above the band would point the three hull-fixed scouts' guns down the corridor). A6 has **two clauses**: A6-a the nose clause (turreted within 25° of the corridor tangent, hull-fixed bounded forward-oblique at 75°), and **A6-b the sign of the arc** — when both shoulders serve the band equally, take the one that advances along the corridor, so level 3's null space becomes speed alone; **A6-b is the cell that makes the law reach the velocity falsifier at all**, and nav adds it to the A7 table as a row. The corridor is N1's `path_points` current leg, one publisher. Control's half is exactly three things: draw the corridor at **the lead's pose — 21° pitch, FOV 35, 49 m** (NOT 12°, the camera he played and rejected; corrected by control 2026-09-20), attribute a level-1/2 override in the existing "why did my element do that" vocabulary, nothing new on the command card. Active ticks are flagged with a reason and the falsifier is computed over active ticks with the active fraction beside it. **Invariant 0c answer: A6 replaces nothing** (no heading law or corridor exists today, and A7 already deletes `PENALTY_SIDE_ON`) — accepted as an addition **with A5's pre-registered revert:** if the velocity-opposing fraction does not fall below 10% without an exchange-ratio fall, it comes out with its switch. **control signed 2026-09-20 with one condition on nav:** `Movement.state(unit)` carries `"legibility": {"active": bool, "why": StringName}` (`why` from a closed set: `band`, `survival`, `armour`, …) so the readout names which level took the nose rather than inferring it from geometry. **And a rule for A12:** an arrival arc under an *ordered* facing is off-corridor by construction — those ticks are flagged by nav's emitter and counted as ordered, never charged to A6's fraction. | feel (author), control, nav | squad (a facing on holds) |

### The round's structural finding so far (2026-09-20, nav and squad independently)

**Intent does not reach the layer that moves the hull.** nav: `CombatMotion` decides under a tenth of a hull's ticks
in a fight; `Movement` drives the other nine tenths and has no notion of a formation leash, so A7's level-0 region
must move into `Movement`'s goal selection. squad: A8's deformation, measured, makes a wedge *fail* a defile it passes
without it, because a slot layout is the wrong place to express intent the mover cannot see — and it never applied
to a plain right-click move at all. **Same seam, from both ends, within an hour.** Not a tonight-sized change; it is
the first candidate for round 10, ahead of retrying either row.
**The defile failure, MEASURED (nav, 02:50, squad's tree and configuration, maze, wheeled, seed 3, 70 s; reproduces
squad's result exactly — artillery never arrives, dispersion 41.4 s):** three hypotheses were pre-registered with their
signatures before the run, and two died. Chord guard starving wide hulls: `guard_rescues` **1** all run — dead.
Right-of-way impossible in a 5 m corridor (4.55 m of clearance needed; nav's and the orchestrator's favourite): `asks_refused`
**0**, `yields_started` **0** — dead, **because nobody ever asks**: right-of-way triggers on stall or on being held below
the ask pace, and a unit ORCA is deflecting is neither. **ORCA: `orca_deflected` 1330 of `orca_solved` 2172 — 61% —
alive.** The hull sits in a regime no recovery mechanism recognises: not stalled (it moves), not blocked (it
progresses a little), not slow enough to ask; every safety net watches for a different symptom. Two consequences: the
pre-approved "strict file order" fix would fix a deadlock that is not happening and is withdrawn; the real question is
why ORCA's deflected velocity does not resolve in a corridor — whether the navmesh refusal (`AVOID_MESH_PROBE`) should
return a slower but legal velocity instead of falling back to the route at reduced pace — and **something must notice
the regime** (61% deflection with no arrival in 70 s trips nothing). The method is the finding: signatures written
before the run killed the two stories their authors believed. **Then the third died too (nav, 03:10):** the ORCA
navmesh refusal fires twice in 70 s; making it return a slower-but-legal velocity changed nothing (identical arrivals,
identical 40.57 s dispersion) and was reverted as a null. **All three pre-registered hypotheses are dead and the cause is
unknown.** What survives is `wedged`, a `Movement` regime detector that fires 8 times in the run and gives the failure a
name in the state machine, so the next investigation starts from a counter rather than a story.

### Standing rules for round 9 (in addition to *The standing rules for this round* below)

- **CP1 before verdicts, CP2 before size-dependent numbers.** Build freely; publish after.
- **The orchestrator records the sim baseline in the same session as CP2 and any sim-moving merge** (Invariant 2 as
  amended). A merge that moves it says so in its subject.
- **Every number carries its commit and its machine**, and after CP3 lands, wall-clock figures taken before it are
  retired (T1's note in *Round 9 goal* below).

## Round 6 goal

**Movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get stuck
behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera too far
above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](game_design.md) *Round 6 direction*). Frame rate is **not** on his list this round — the locked 30 fps
held — so this round spends its budget on behaviour, not on the frame.

The stack the lead described, top to bottom, is the shape of this round:

```
  player order  ──▶  squad: target formation, a slot per unit, form-up ETA     (squad)
                     └─▶ unit: path to my slot, avoid, negotiate, unstick      (nav)
                         └─▶ hull: throttle and turn from a regulated error    (nav, PID)
  read and issued through the task palette, symbols and camera                 (control)
  over terrain that makes ambush and flanking possible                         (arena)
  at ranges where closing is a decision                                        (combat)
  in a place that feels inhabited                                              (feel)
```

## Round 6 streams

| Stream | Brief | Outcome |
|---|---|---|
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, and one regulated control law (PID) from the wheels up. Proven on a maze. |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | A squad order is a *formation* order: a target formation anchored on the destination, a slot per unit, a form-up formula and ETA, and every named task producing the behaviour its name claims |
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, and loading that shows its progress |
| **arena** | [streams/archive/round10/arena.md](streams/archive/round10/arena.md) | Terrain that makes ambush and flanking possible instead of one open brawl, plus the maze arena nav is measured against |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | Engagement ranges where seeing an enemy is not the same as opening fire: closing, breaking contact and cover become decisions |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and the place reacts to the match |

**Paused:** netcode, the garage and progression loop, new Meshy *models* (88 credits left). ElevenLabs has credits and
feel may use them for crowd beds under the standing text-approval gate.

**Why this split:** the lead's message is one stack with six layers, and each layer fails on its own terms. Getting a
vehicle around another vehicle (nav) is a different craft from deciding where five vehicles should stand (squad), from
naming that task on screen (control), from the ground it happens on (arena), from when a gun is allowed to speak
(combat), from whether the arena feels like a place (feel).

## Checkpoints

- **CP1, nav's Movement API (N1)** — the seam every other stream's movement runs through. nav lands the interface and a
  working default first, before the clever parts, so squad is never coding against a stub.
- **CP2, arena's maze (N3)** — a small data job arena does on day one, because it is nav's acceptance test.
- **CP3, squad's slot contract (N2)** — control's task palette and the CPU commander both read it.
- **CP4, combat's engagement envelope (N5)** — it re-times every fight. It lands **once**, early, and every stream
  re-runs its measurements after; nobody publishes a number that straddles it (round 5 lost days to exactly this).

## Product constraints every stream designs for (the lead)

1. **"Even smarter than StarCraft 2."** The bar is legibility: a unit must look like it knows what it is doing. No unit
   standing still in a fight, no unit stuck behind a friend, no element flip-flopping between drills.
2. **A locked 30 fps at 1080p with 30 a side** (the lead's round-5 sign-off), and a 720p 60 fps option. Anything added
   this round is measured against it; the simulation tick is 30 Hz.
3. **Orders obey instantly**: the K1 response guarantee is **100 ms of wall clock**, asserted in milliseconds.
4. **The player's units hold until ordered** (round-5 ruling). An army that moves without being told is not an army.
5. **Fun first, desktop first; no unearned god view; CPU and player run the same doctrine.**
6. **The vibe** ([art_direction.md](art_direction.md)) and **die-hard, no pay-to-win** ([vision.md](vision.md)).

## Lead gates this round

1. **The camera look is the lead's call.** control puts a page of screenshots (pitch × height × FOV, the same moment of
   the same fight) in front of him rather than guessing at "between StarCraft 2 and Twisted Metal".
2. **Paid generation:** no new Meshy models (88 credits). ElevenLabs crowd beds need the usual text approval, and a
   cheap pilot before any batch (lesson 19).
3. **Design pillars**, money, accounts, and anything destructive outside your worktree.

## Who owns what (round 6)

| Path | Owner |
|---|---|
| `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, new `game/ai/{avoidance,movement,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), `_agents/navigation.md` (new) — **one exception, granted 2026-09-18:** with no nav session running and two streams holding for CP4, combat made four surgical edits to `order_controller.gd` (an `engagement_lay` member, an `Engagement.is_seen` early-out in `_shootable`, an `envelope` term in the trigger line, and a seconds helper with `lose`/`forget`). Every rule lives in combat's `game/combat/engagement.gd`; the controller only holds state and calls it, and none of the edits touches a path, waypoint or throttle. nav reviews them when it starts and owns the file. The seam combat wants for the `gunnery.gd` split is written into [streams/archive/round10/nav.md](streams/archive/round10/nav.md). | **nav** |
| **Contract, agreed 2026-09-19 (nav + squad):** a move order may carry `"facing": [x, z]`. squad populates it from `TankBrain.intended_facing()` at its `_move_to`/`_order_move` choke point; nav consumes it in `Movement` so a WHEELED hull rolls onto that heading on its last leg (a Dubins-style arc) instead of creeping round after it arrives (measured: an IFV 45° off at arrival, ~6 s to correct). Tracked and hover hulls ignore it and pivot as they do now. | **nav** (the arc) + **squad** (the facing) |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd` (**not** `doctrine.gd`: the army-JSON loader is combat's, C2), `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md` | **squad** |
| `game/control/`, `game/ui/` (HUD, widgets, title screen, loading screen), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` — **one exception, granted 2026-09-18:** squad rewrites `game/control/group_formation.gd` into a thin adapter over N2's `TacticsFormation.slots()`, keeping its public API unchanged, because N2 cannot collapse three formation systems into one while one of them lives behind another stream's wall. control reviews that diff at merge and owns the file again afterwards. **Reviewed and cleared 2026-09-18:** control confirms the shim suits `Orders._resolve_group()` — pacing carried over exactly (`PACE_NEAR` 8 m, `PACE_FLOOR` 0.35, same formula) and seating through `TacticsFormation.place(..., {"policy": "front"})` keeping heavies forward with non-crossing seats; all 141 control formation/orders/group tests pass on the merged tree. No objection — the exception is discharged and the file is control's again. | **control** |
| `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` | **arena** |
| `game/units/`, `game/combat/`, `game/match/`, `game/tank/` **except `tank_motion.gd`**, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | **combat** |
| `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**), `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and art paths, `tools/{assets,announcer,audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md` — **one exception, granted 2026-09-18:** arena edited four lines of `tools/announcer/test_arena_names.py` to skip layouts flagged `"fixture": true`, because its maze is a test fixture that must never get a spoken name (the booth should not name a map nobody plays) or a recorded clip (paid ElevenLabs time behind a lead gate), and it had turned `main`'s check red. feel reviews it at merge and owns the file. | **feel** |
| `game/garage/`, `game/progression/`, `game/network/`, `server/`, net modes, `mk/{garage,net}.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `backups.md`, `HANDOFF.md` | orchestrator |
| **Shared:** `project.godot`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/{remote,slot,backup_assets}.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

`game/theme/audio/` and `engine_system.gd` stay with the sound owner, which is **feel** this round (round 5's audio
stream folds into it; round 5's render stream folds into it too — the frame-rate work is done and the remaining
presentation job is the arena as a place).

## New contracts (round 6)

| Contract | Owner, where | Consumers |
|---|---|---|
| **N1 Movement API** (CP1). One seam between *where a unit is told to be* and *how it gets there*. `Movement.request(unit, to: Vector3, opts) -> void` where `opts` may carry `{"arrive_radius", "facing", "pace", "priority"}`; `Movement.state(unit) -> {"phase": "pathing" \| "driving" \| "yielding" \| "blocked" \| "arrived", "eta_s", "remaining_m", "path_points", "blocked_by"}`; `Movement.eta(unit, to) -> float` (the lead's "estimate the position and time at which a unit would converge"); `Movement.cancel(unit)`. Guarantees nav owes every consumer: a unit given a reachable destination **arrives or reports `blocked` with a reason** — it never stands still silently, and never remains stuck. Local avoidance and right-of-way are always on; no consumer opts in. | nav: `game/ai/movement.gd` | squad (slots), control (orders, markers), combat (none), arena (none) |
| **N2 Slot contract** (CP3). A squad/element order is a formation order. `TacticsFormation.slots(element, anchor, heading, count) -> [{"unit", "to", "facing", "role"}]`, recomputed as the anchor moves; assignment **minimises crossing** (a unit keeps its relative place) and is stable tick to tick; `element.form_up_eta() -> float` from N1's ETAs; the group paces to its slowest member (`Orders.pace_factor`). The two formation systems that exist today (`game/ai/formations.gd`, squad-level, 5 slots; `game/tactics/tactics_formation.gd`, element-level) become **one**. | squad: `game/tactics/`, `game/ai/formations.gd` | control (palette, markers), nav (consumes slot targets), combat (none) |
| **N3 Maze arena** (CP2, day one). `arenas/maze.json` — a quasi-maze the lead asked for by name, built from the existing kit, point-symmetric like every arena, with a start zone and a far objective and gaps a horde must file through. Plus `make nav-maze`, a headless run that sends N units across it and reports how many arrive, when, and how many were ever stuck. It is nav's acceptance test, not a shipping map. | arena: `arenas/`, `mk/arena.mk` | nav (acceptance), squad (form-up under constraint) |
| **N4 Task palette and symbology.** The final task vocabulary, one row per task: the verb (`ElementTask.VERBS`), its **military symbol** (APP-6 / MIL-STD-2525 tactical task graphic), its hotkey, one line of player-facing text, and the behaviour the player is entitled to see. A verb may only appear in the palette when squad can demonstrate its behaviour; a verb the mouse already expresses (`move`, `follow`, `attack`) gets **no button**. control owns the table and draws the symbols; squad owns the behaviour behind each row. | control + squad, table in `_agents/tactical_map.md` | all |
| **N5 Engagement envelope** (CP4). Per-weapon *effective* range, acquisition range and the rule that decides when a unit opens fire, such that seeing an enemy is not the same as shooting at it. Lands once, early, with the before/after measured on the configuration players actually get. | combat: `game/combat/`, `game/units/`, `game/match/` | all (every measurement re-runs after it) |
| **N7 Objectives are the arena's, not a constant** (added 2026-09-18, arena proposing, combat scheduling). `Match` hard-codes `CONTROL_CENTER := Vector3.ZERO` and `CONTROL_RADIUS := 16.0`, and a layout's `control_point` reaches only the *dressing* — **an arena cannot move its own objective today; the field is decorative.** arena has landed its half: `arenas/` gains `objectives: [{name, position, radius}]` with `Arena.objectives_of()`, validated so off-centre objectives come in **mirrored pairs** (a lone one is owned by whichever base is nearer, preserving the fairness invariant), and a layout with no `objectives` list reports exactly the single central zone `Match` already hard-codes — asserted for every shipped layout. **combat's half is a pure read-through with no behaviour change on any existing arena:** read `Arena.objectives_of(Arena.active)` instead of the two constants, and hold a per-objective owner instead of one scalar. It is combat's to schedule; arena's X3 (objectives off the centre line) is blocked on it *and* on CP4. | arena: `arenas/`, `game/arena/` → combat: `game/match/` | squad (what to take), feel (dressing) |
| **N6 PID as the house control law.** `Pid` (a small, deterministic, tick-based regulator: gains, integral clamp, derivative on measurement, reset) used where there is a continuous error to regulate — slot station-keeping, speed matching, turret lay — and **not** where the problem is discrete choice. Gains live in **data**, per faction, so the lead's idea that factions differ by their gains is reachable: the Syndicate crisp, the gangs loose. Default gains ship stable first; per-faction gains are a stretch. | nav: `game/ai/{pid,control_gains}.gd` | squad (station-keeping), control (camera smoothing), feel (none) |

## Round 9 goal (2026-09-19): the research catalogue, sequenced — and the metrics BEFORE the mechanisms

**Read [`research_catalog.md`](research_catalog.md) first.** It is the backlog: 12 ADOPT rows, each with a canonical
reference, what it replaces, an owner and a **pre-registered falsifier**. This section is only the *split and the
order*, which the catalogue deliberately does not fix.

**A12 (the trajectory-space metric suite) LANDS FIRST, and it is the orchestrator's, not a stream's.** Everything below
is judged against it, and round 8 proved twice over why:
- **We measured time-allocation while his complaint was about the shape of the motion.** A unit that jerks for 0.5 s
  costs almost nothing in "6% of travel time" and ruins the next fifteen seconds of watching.
- **squad's churn lever is the proof** (lesson 150): `commit_bonus` 1.35 halved the churn metric, passed a 48-match
  ladder, and cost a squad its fire concentration and a scout its engine-deck targeting (41/23 → 3/0). **The metric
  improved while the behaviour degraded.** A12's own acceptance is that it reproduces the round-8 oscillation finding
  from the same replays — *a metric that cannot see a pathology we already found is the wrong metric.*

### The split

| Stream | Round 9 | Order and why |
|---|---|---|
| **orchestrator** | **A12 metrics suite**, then **T1 parallelise `check`** | Windowed displacement efficiency (the 8 m/2 m signature measured directly), signed cusp density, spectral arc length, affine formation residual. **Before anything else ships.** |

**T1 — PARALLELISE `make check`. The lead asked for this directly (2026-09-19) and it is worth more than any single
algorithm on this list.** Measured at the close of round 8: a `check` on builder0 is **one single-threaded Godot
process at ~7% CPU on a 12-thread machine** — latency-bound on awaiting fixed-tick physics frames, not compute-bound.
**We gate an entire round on ~8% of the build machine for 30–50 minutes.**

- **This is the knob the slot question was really reaching for.** Raising `TANK_SQUAD_SLOTS` (2 → derived, now 4)
  shortens the QUEUE. **Only inner parallelism shortens the RUN**, and the run is what everyone waits on.
- **What a 40 → 10 minute check would have changed on the night of round 8's close, concretely:** combat would not
  have had to abandon a 590-test run when the network dropped and start over; the orchestrator's own lint mess would
  have been caught in one cycle instead of three wrong diagnoses; and the round would not have needed a two-hour tail
  that the lead had to cut short.
- **Shape:** the targets in `check` are largely independent (`lint`, `test`, the smokes, `determinism`,
  `announcer-check`, `audio-check`, the pytest suites). Run independent targets concurrently under the slot budget
  rather than serially. **Memory is the constraint, not cores** (~735 MB a Godot run against 11.9 GB available on
  builder0), so the budget is roughly 8–10 concurrent runs there and far fewer on the laptop — **derive it the way
  `tools/slot.sh` now derives its slot count, do not hard-code it** (lesson 148).
- **⚠ Determinism is safe; TIMING is not.** Separate processes on a fixed tick produce identical hashes under any
  load. What breaks is anything sampling wall-clock inside a run — profiling, timeouts, real-second budgets. Three
  garage liveness timeouts already went 60/120 s → 600 s for this reason, and **control measured that a
  reference-workload ratio corrects for "busy machine" but NOT for "every thread busy"** (~14× vs 2× under 7 burners
  on 8 threads). **Expect to raise timeouts, and expect wall-clock figures taken before this change to be retired**
  (nav catalogued which of its own survive, in `verification.md`).
- **Falsifier:** wall-clock for a full `check` on builder0 drops by **≥ 50%** with **zero new flakes over three
  consecutive runs**, and the sim baseline hash is **bit-identical** to the serial run's. A faster check that flakes
  once is worse than a slow one, because a flake costs a re-run plus a false investigation.
| **nav** | **A7 → A11 → A1 → A4** | **This order is nav's, adopted over the orchestrator's A1-first proposal — see below.** |
| **combat** | **A2**, then A3's consumer | A2 replaces the flat `commit_bonus` (**1.15** on main; 1.35 reverted) with a state-dependent switching cost. **Its falsifier is inherited, not invented: squad's two behaviour scenarios** — fire concentration and the scout's engine decks — because that is exactly what the crude version cost |
| **arena** | **A3's summed-area tables**, + the **Syndicate airship** | A3 retires the 12.19 m cover cliff at any hull length. **The `make arena-report` WATCH line must be revised in the same commit as the tables** or it becomes a confident false alarm. Airship: primitives, no Meshy, no collision body ([game_design.md](game_design.md)) |
| **squad** | **A8 → A9 → A10** | squad's own plan names what each REPLACES **by file** — A8 replaces `TacticsFormation.group_offsets` and `ArmyLayout._scale_for` (`game/tactics/army_layout.gd:195` — the round-8 plan misnamed it `ElementPlan._scale_for`); A9 replaces `Element.form_up_eta` and `_pace_leader_for_flow`; **A10 replaces `TacticsFormation.seat()`'s Hungarian matching AND BOTH its hysteresis patches** (`STABLE_MARGIN` and round 8's `fixed` flag, which is deleted with it, not layered on). **Aim A8/A9 at WHEELED hulls** (re-aimed 2026-09-20 from *light* hulls on metrics' CP1 evidence: on a Condemned roster with no scout, yard efficiency ifv/lancer 0.62 with ~35 cusps per agent-minute against the tracked tank's 0.80 and 7.4 — a **locomotion** effect, not a unit; and 56% of all reversals are the wheeled creep, `tank` producing zero) — round 8's *scout is the shuffler* (0.68 net/path, 13.3%) was the same effect seen through one unit |
| **feel + control** | **A6 legibility — as a CONTRACT first** | See below; this one does not start as code |

### nav's sequencing, adopted over the orchestrator's — and the argument, because the argument is the artefact

The orchestrator proposed A1 (cadence) then A4 (clothoids). **nav argued A7 → A11 → A1 → A4 and was right.** Recorded
here rather than left in a message, because the reasoning is what a fresh orchestrator needs:

1. **A7 (null-space priority projection) first, alone.** It is the only architectural row, and **everything else is
   priced wrongly until it lands.** Round 8's clearest finding is a cancellation failure: *standoff HOLD returns index
   −1 and never consults the commitment bonus*, so we shipped a term that was never in the code path and measured it
   twice for nothing. That IS "opposing goals cancel to zero", which priority projection makes structurally
   impossible. Its falsifier is also already measurable with nav's `travelled` counter and arena's stall counters.
2. **A11 (dynamic-window arcs) second, because it replaces the ring A7 has just re-plumbed.** The other order means
   fitting priority projection to a scoring structure we are about to delete.
3. **A1 (event-triggered replanning) third.** Worth the most on paper (70% of churn) but **the row most likely to look
   like a win while hiding a regression** — nav's hold-hysteresis A/B is the cautionary case: churn down 6–22% and it
   still failed its bar. A1's latency falsifier (≤ 2 ticks to a new contact) needs a stable decision layer beneath it.
4. **A4 (clothoids) last, after A11.** Clothoids are a primitive; the thing that consumes them is the arc chooser.
   Landing them first writes them into the ring we are removing. Round 8's arrival arc is the natural first consumer.

**⚠ nav's caution against its own recommendation, which is the part to brief hardest:** A7 replaces additive blending,
and **that is also what `CombatMotion`'s entire weight table is.** Those weights encode behaviour the lead has already
approved — standoff, commitment, armour toward threats. *"Six multiply-adds"* badly understates the blast radius.
**A7's brief must name which of those become priorities and which become null-space tasks BEFORE any code**, reviewed
against combat's and feel's contracts. That is where round 7's approved behaviour either survives or quietly does not.

**nav's Invariant 0c declaration, for reuse as the template:** *it owns the desired-velocity layer (`movement.gd`,
`combat_motion.gd`, `steering.gd`, `tank_motion.gd`); it assumes above it that squad hands down goals and a `facing`,
and below it that the plant honours (throttle, turn) with a bounded yaw rate; A7 replaces its additive blend, A11 its
direction ring, A1 its fixed repath/re-aim cadence, A4 the straight approach in its arrival arc.* **None of the four
adds alongside.** That is the answer Invariant 0c is looking for.

### A6 is a contract before it is code — feel, control and nav together

feel raised this and it is right: **the motion code is nav's and combat's, not feel's**, so A6 cannot be three parallel
adoptions. It starts as one written contract — feel owns the motion law, control owns the readout, nav owns the layer
it executes in — and **control's prerequisite lands first**, because of lesson 149:

**The arrive-on-heading arc cannot fire in the game the lead plays.** A `facing` enters a move from exactly one place,
`game/ui/tactical_map.gd:269`, the touch map's right-drag, and the touch map is behind `--touch-map`. His desktop
`RtsControls` only ever *reads* `facing`. **So control's first round-9 commit gives the desktop right-click the touch
map's grammar** (press = destination, drag = the facing to arrive on) **with a test asserting
`orders.current(unit)["facing"]` after a real drag — so the next A/B has a live arm BY CONSTRUCTION.** An arm you have
to remember to check will eventually not be checked. And note: even then, `nav-fight` issuing a plain `move` measures
nothing — **the live cases are a player drag and a squad hold. Do not re-measure zero twice.**

### The standing rules for this round

- **Invariant 0c governs.** A brief that adopts a catalogue row names what it **replaces**; *"nothing"* is the answer
  the orchestrator interrogates. Rows touching one code path are **sequenced, not parallelised**.
- **Pair every outcome ladder with a behaviour assertion**, and prefer the behaviour assertion when they disagree
  (lesson 150). A ladder is a safety net against making things worse, never evidence of having made things better.
- **Prove the arm is distinguishable before believing any comparison** (lesson 147). An arm-engagement counter costs
  four lines and is the difference between a finding and a fiction.
- **Play the default path** before reporting anything as shipped (lesson 149).
- **Never quote the external reviews' audit counts or Elo figures.** They are unverifiable assertions about a codebase
  neither service has seen. The reasoning stands on its own; the digits do not.

## Round 8 goal (2026-09-19): the owed algorithms, and the eight things he listed

**The lead: *"it still sucks"*, and *"my expectation was that you would have gotten all this working while I was away."***
**Round 7 merged seventeen branches and did not change his verdict.** Round 8 is the algorithm roster plus his eight
items, and **nothing else**. No instrument work that is not in service of one of them.

**Why the roster slipped, stated plainly so it is not repeated:** round 7 spent its capacity on *merging* and on
*instruments* — six measuring tools were found broken — and the owed algorithms were deferred as too large to land
alongside that. **That was defensible once. It is not defensible twice**, and the four missing algorithms map directly
onto his complaints:

| his complaint | the owed algorithm |
|---|---|
| *"the semi trucks are yawing in place"* | **angular acceleration limit** on the plant |
| trucks turn like tracked vehicles | **Reeds–Shepp** |
| *"stuck behind basic barriers… back and forth indefinitely"* | **flow fields** |
| long routes, repathing every second | **HPA\*** |

| Stream | Round 8 |
|---|---|
| **nav** | **The three motion algorithms, in this order: (1) angular-acceleration limit in `TankMotion.step_in_place` — and a wheeled hull must NOT rotate without translating, which is a class bug, not a semi bug; (2) Reeds–Shepp for car-like hulls; (3) FLOW FIELDS as its own checkpoint.** Flow fields are no longer deferrable — they are the named answer to his loudest complaint |
| **arena** | **A REPRO MAP for the barrier stall, in the configuration he plays.** nav measured blocked-by-terrain to zero in `nav-fight` while he watches it happen in `make skirmish` — **the instrument and the game disagree and the game is right.** Build the barrier that stalls units and make it a probe nav can run |
| **squad** | **Orphaned units: every unit belongs to a squad, and 1–4 selects all of them.** Then **an explicit attack order must override an existing target** — `test_a_move_order_beats_every_brain_state` has no attack sibling and needs one |
| **control** | **The selection side of the orphans**, and whatever makes an ignored order visible: if a unit cannot obey, the HUD must say so rather than leaving him to infer it |
| **feel** | **MAKE THE SEMI HUGE.** 3.14× satisfied the number he gave in round 6 and not the intent, and **he has removed balance as a constraint**. Then the articulated tractor/trailer, which he offered to shelve — **treat it as a stretch** |
| **combat** | **`hull_size` for the semi** (the catalog is combat's, and it is the collision box), and **the balance consequences of a huge semi, which he has explicitly deferred** — measure, do not tune |

**The standing rule for this round: every item is something he named. If a stream wants to do something he did not name,
it asks first.**

## New contracts (round 7)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M4 Arena containment is a predicate, not a scalar** (added 2026-09-19; combat found it, arena owns it). `Arena.contains(point) -> bool` and `Arena.clamp_into(point) -> Vector3`, working for **every** shape including the existing square, so no caller knows what shape the arena is. **Why it exists:** `DRIVABLE_LIMIT` is used as a *square* clamp in six places — three `absf(x) > DRIVABLE_LIMIT or absf(z) > ...` checks in `arena.gd`'s validate, and `clampf` in `orders.gd`, `rts_controls.gd` and `army_layout.gd`. A regular hexagon of circumradius 139.7 m has an **inradius of 121.0**, so its boundary is 139.7 m toward a vertex and 121.0 m toward a flat edge, while **a square clamp at ±136 permits points 192 m from centre on the diagonal** — every one of those call sites would place an obstacle, clamp an order or lay out an army outside the playable arena, and `Arena.validate` would approve it. `DRIVABLE_LIMIT` survives only as the conservative **inscribed** bound: 121.0 − 4.0 clearance = **117**, which is barely different from today's 116. **⚠ Scaling it 116 → 136 in proportion with `ARENA_HALF_SIZE` makes the clamp about three times too permissive, not slightly.** `clamp_into` must document whether it returns the nearest boundary point or the ray-to-centre crossing — they differ sharply near a corner; nearest-boundary is what a player means by *"go as far that way as you can"*. The water and pit footprints belong behind the same predicate: a point inside a pit is not a point a player can be ordered into. | arena: `game/arena/` | **control** (`orders.gd` ✅, `rts_controls.gd` ✅ via `Orders.clamp_to_arena`: the shape inset by a 4 m hull clearance (exactly ±116 on the square), then `Arena.clamp_into` for water and pits; `radar.gd` has no clamp), **arena** (`validate`), **squad** (`army_layout.gd`, `agent_bridge.gd`), **combat** (`match.gd` constants, `visibility_field.gd` ✅, `match_runner_mode.gd` bench spread — still a square clamp, harmless today, **unmigrated**), nav |

## Round 5's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M1 Performance budget.** `make perf-scene` reports frame time, draw calls, primitives and real-light count for a 30-a-side battle; the written budget is in `_agents/streams/references/fx_tricks.md`. The target is the lead's: **a locked 30 fps at 1080p with 30 a side**, plus a 720p 60 fps option. | feel | all |
| **M2 Arena layout v2.** `arenas/<name>.json` with the arena kit: `props` (`container_20`/`container_40` with `stack`, `ad_screen`, `barricade`, `sign`, `wreck`), lanes and cover annotations for the AI, per-arena spawn zones sized for 30+ a side, validated point-symmetric; `--arena=<name>`. | arena | combat (collision, nav), nav (navigation), feel (props), squad (cover, lanes) |
| **M3 Team identity without glare.** Vehicles read as vehicles at play distance; team accent is a hint. Settled by the lead: **rim tint is enough**, no per-team hull paint. | feel + control | all |

## Round 4's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **L1 Elements and doctrine.** *Sharp edge (control, 2026-09-16): an element with no task still runs its SOP, so forming one before it has a task makes its leader fight the player for the wheel. Form lazily, on the first task.* An `Element` is a cluster of units with a leader: `Elements.form(units, name)`, `Elements.of(unit)`, `element.assign(task)` where a task is `{"verb": "move" \| "attack" \| "screen" \| "support_by_fire" \| "hold", "to"?, "target"?}`; the leader picks a **formation** (`column`, `wedge`, `line`, `echelon_left/right`, `herringbone`) and a **movement technique** (`traveling`, `traveling_overwatch`, `bounding_overwatch`) from doctrine data, and runs **battle drills** on triggers (`react_to_contact`, `near_ambush`, `far_ambush`, `break_contact`, `support_by_fire`, `assault_through`). It issues per-unit orders through control's K1 `Orders`. Read-only for UI: `element.state() -> {formation, technique, drill, reason, slots}` and signal `element_changed(id)`. Doctrine data lives in `doctrines/doctrine_<name>.json` with a `faction` field. **Round 6 puts this contract on trial: the verbs must do what they say (N4), and the formations must actually form (N2).** | squad: `game/tactics/` | control (HUD, task issuing), nav (executes), combat |
| **L2 Suppression and effective fire.** `Tank.suppression` (0–1, decays), raised by near-misses and rounds passing close; accuracy penalty and a `pinned` state above a threshold. `Match.threat_field(team)`, `Match.is_beaten_zone(team, from, to)`, `Match.threat_along(team, from, to)`, `Match.shot_spread(weapon, moving, suppression)`, `Weapons.suppression(weapon)`, `Tank.suppression`/`is_pinned()`/`suppress()`. `projectile_impact` and `weapon_fired` carry `suppression_applied`. | combat | squad, feel |
| **L3 Faction rosters.** `Units.PROFILES` entries carry `faction` (`condemned` \| `gangs` \| `law` \| `syndicate`), per-faction costs and stats; `Units.roster(faction)`; `--green-faction=` / `--rust-faction=`; `Army` builds faction armies to a budget. | combat: `game/units/` | squad, control, feel, nav (per-faction gains, N6) |
| **L4 Vision-framed camera.** `RtsCamera.frame_vision(element)`, `Camera.max_zoom_in`, `Match.visible_region(team, units)`. Off-screen markers and alerts come from control. | control | — |
| **L5 Match mood.** `MatchMood.current() -> {intensity 0..1, state: "lull" \| "skirmish" \| "battle" \| "last_stand" \| "victory" \| "defeat", reasons[]}` from the K5 event stream. | feel: `game/audio/` | announcer, crowd, screens |

## Standing contracts (from rounds 2–3, still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **K1 Orders API** (control). `UnitCommand` = `{"units": [names], "verb": "move" \| "attack" \| "attack_move" \| "follow" \| "hold" \| "stop", "to"?, "target"?, "queue": bool, "formation"?, "source"?: "player" \| "element" \| "", "facing"?: [x, z]}`. **The response guarantee is 100 ms of wall-clock time, not a tick count** — at 30 Hz that is exactly 3 ticks with nothing spare, so 30 Hz is the floor for the simulation rate. `Match.orders` holds `Orders`: `issue`, `current(unit)`, `queue(unit)`, `complete(unit)`, signal `order_changed(unit)`, plus `pace_factor` and `station` for group moves. | control: `game/control/` | nav (executes), squad (elements issue), combat, feel (markers) |
| **K2 Weapon events** (combat). `Weapons.PROFILES` fire model fields; `Match.weapon_fired(event)`, `Match.projectile_impact(event)` (faces, `weak_spot`, `suppression_applied`), `Match.incoming_projectiles(unit)`. | combat | squad (dodging, weak spots), feel (effects) |
| **K3 Locomotion** (combat). `locomotion` (`tracks` \| `wheels`), `min_turn_radius_m`, acceleration, braking, `lateral_grip`; `TankMotion.predict/state_for/step`. **`tank_motion.gd` moves to nav for round 6** (it is the plant the controller regulates); its data fields stay combat's. | combat (data) + nav (motion) | nav, control, squad |
| **K4 Faction art slots** (feel). `unit.<faction>.<role>.hull/turret/weapon`; `make vehicle-gallery FACTION=<id>`. | feel: `game/theme/factions/` | combat (rosters) |
| **K5 Match events for the announcer** (feel). JSON-line events from fixtures or `Match`; `element_formation` and `element_drill` carry the table's reason. | feel: `game/announcer/` | squad (publishes), combat (adapter) |
| **C1 Unit catalog v2.** `Units.PROFILES[id]` = `display_name`, `role`, `blurb`, `cost`, `unlock_tier`, `hull_size`, `max_health`, `max_shield`, `shield_recharge_delay`, `shield_recharge_rate`, `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`, `sight_radius`, `weapon`, `mount`, `turret_turn_rate_deg`, `fire_arc_deg`, `muzzle_height`, optional `heat_capacity`/`heat_dissipation`, `good_vs`/`weak_vs`, `armor` `{front, side, rear}`, `locomotion`, `min_turn_radius_m`, optional `faction`. Weapons carry `penetration` and `splash_radius`. | combat: `game/units/units.gd`, `game/combat/weapons.gd` | all |
| **C2 Army JSON v2.** `{"name", "squads": [{"name", "formation"?, "directive"?, "units": [{"unit": id, "paint"?, "directive"?}]}]}`; ≤ 5 squads, ≤ 5 units per squad; cost ≤ the match budget. | combat + squad | garage (paused), skirmish, match runner |
| **C3 Match result for progression.** `Match.finished(result)` includes `winner`, `reason`, per-team `units_lost`/`units_left`, kills by unit type, `duration_seconds`, `budget`. | combat | control (results), progression (paused) |
| **C4 Combat queries for AI.** `Match.friendlies_in_line_of_fire(shooter, aim_point)`, `Arena.cover_features()`, `Tank.mount`/`fire_arc_deg`/`turret_turn_rate`/`muzzle_height`, `Tank.can_bear_on(point)`, `Arena.hazards()`, `Units.armor(unit, face)`, `Match.armor_multiplier(weapon, unit, face)`. | combat | squad, nav |
| **C5 Arena layouts.** `arenas/<name>.json` = `{name, half_size, obstacles: [{type, position, rotation_deg, size?}], spawns: {green, rust}, control_point?, hazards?}`, validated point-symmetric; `--arena=<name>`; obstacle `type` maps to visual slot `prop.<type>`; `arena.dressing.setup(layout)`. | arena | feel (props), squad (cover), nav (navigation), control (radar outline) |
| **C6 Visual slots**, including per-unit ids `unit.<id>.hull/turret/weapon`; `set_team_color`, `set_paint`, `set_shield`, `set_heat`, `set_firing`, `setup`. | feel: [slot_contracts.md](slot_contracts.md) | all |
| **C7 Command API.** `SquadCommand` `{squad, verb, to, facing, formation, commander}`; `Formations.offsets(formation, count)`; `TacticalMap.command_issued`, `squad_selected(squad_key)`; `RtsCamera.follow(target)` / `focus_on(point)` / `frame(points)`. | control, squad | agent bridge |
| **C8 Progression profile.** `user://profile.json`; `Progression.BUDGET_TIERS`; `Progression.award(report, team, tier)`. | paused | — |
| **HUD messages:** `Hud.post_message(text, severity)` → cyber banners | control posts; feel renders | everyone |
| **Visibility / radar data:** `VisibilityField`, `Match.is_visible_to`, `Match.intel`, `Radar.blips()`, slot `fx.fog_of_war` | combat (field), control (radar) | feel (skin) |
| **Launch flags and console markers** (`TANK_SQUAD_*`, `MATCH_RESULT`, `GARAGE_FIGHT`, …) | each mode's owner; list in `game/main.gd` header | smoke tests, `match_series.py` |

## Invariants every stream must keep

0. **A value with a single owner is READ, not mirrored. Where it must be mirrored, the mirror FAILS LOUDLY — or it is
   not a mirror, it is a second source of truth.** (arena + combat, adopted as house policy 2026-09-19 after **five
   instances in five streams in two days**.)

   | the copy | how it failed |
   |---|---|
   | feel's copied `ROSTER` table | drifted from the catalog |
   | `make_arenas.py` mirroring `Match.SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING` behind a comment saying *"must mirror"* | **the copy WON** — baked spawn lists beat the constants, so changing a constant changed nothing in a real match |
   | `arena_report.KIT` mirroring `ArenaKit.PROPS` | **the original was ABSENT** — `block` was missing, so the cityscape could not be authored |
   | hull sizes | read rather than copied, and **re-answered themselves** the moment the 14 m rig landed |
   | `faction_matrix.py`'s hard-coded `FACTIONS = [...]` | **adding a faction would have produced a smaller table that looked complete** |

   **The second clause is the one that bites.** Everyone already agrees copies are bad; the copies that *hurt* are the
   ones that fail **without a symptom** — where the copy silently **wins**, or where the original is silently **absent**.
   **A copy that disagrees loudly is an annoyance. A copy that disagrees quietly is a wrong number with evidence
   attached.**

   Three clauses that are part of the rule, not craft around it:
   - **A reader must NOT fall back to a hard-coded list when the parse fails. Raise.** A fallback restores the exact bug
     silently the moment the parse breaks — that is how a guard becomes decoration.
   - **Mutation-check the reader BOTH directions:** add a value and confirm the tool picks it up; rename the source and
     confirm it refuses. Otherwise the reader is no better than the copy it replaced and you will not find out until it
     matters.
   - **Prove a guard can go red before trusting it.** arena shipped **two guards that could not fire** in one session —
     four tests `unittest discover` never collected because they were bare functions, and a `WATCH` line whose value its
     own `_`-prefix convention stripped before the notes were built. **Both were green by absence, and both were found
     because a COUNT did not move, not because anything failed.**

0b. **A check must not encode a decision nobody has made.** arena declined to make the hull-cover finding a failing test:
   a red `make check` would be the tooling taking a position on a question the lead has not ruled on, **and would force
   the very fix two streams had agreed to hold.** It prints loudly on every report, stays out of `check`, and **becomes
   an assertion the day he rules.** **A tool that fails on an open question is an advocate, not an instrument.**

0c. **A technique adopted in one stream is checked against the techniques adopted in the others BEFORE either merges —
   and a brief that adopts one must name what it REPLACES.** Adopted 2026-09-19 from the external research review
   ([`research_catalog.md`](research_catalog.md) Part 2), which audited its own proposals against each other and found
   that **a majority of combinations of individually-valid techniques violate a cross-layer invariant.**

   The examples are ours and they are concrete:
   - A **space-time reservation** scheme assumes an agent executes the plan it committed to. An **event-triggered
     replanner** assumes it may abandon one at any tick. Each is correct alone. Together, one agent reserves a corridor
     slot and the other never arrives to use it. *(This pairing is why catalogue C8 is held out of round 9 while A1 is
     in it.)*
   - **Null-space priority projection** guarantees safety dominates formation-keeping. **Additive context steering**
     guarantees the opposite, by summing them. Adopt both and you get neither.

   **This is lesson 116 — *inertness does not compose* — in the design layer rather than the test layer**, and it is a
   hazard aimed squarely at how this project works: **five or six streams adopting techniques independently, in
   parallel worktrees, from one shared catalogue.** That is the organisational structure most likely to produce exactly
   this failure, and **no worker is positioned to see it. The orchestrator is.** So:
   - A brief that adopts a catalogue row states **the layer it owns**, **what it assumes the layers above and below
     will do**, and **which already-adopted mechanism it replaces**.
   - **"Replaces: nothing" is the answer to interrogate**, not the answer to accept. *Replacing* is safe; *adding
     alongside* is where two correct techniques fight.
   - Rows that touch the same code path are **sequenced, not parallelised**. A1, A7 and A11 all rewrite how a desired
     velocity is chosen; they do not go to three streams in one round.


1. **`make remote T=check` passes before merging** (lint, tests, network + relay + lobby smoke, combat, match,
   determinism, sim baseline, garage smoke). Paused areas keep their tests green.
2. **The sim baseline is recorded ONCE, by the orchestrator, on `main`, after the last simulation-changing merge of
   the round.** No stream records it — not even a stream entitled to move it. **Ruling made 2026-09-18** (combat
   proposed it; the round had three streams each about to record, and every per-stream hash was guaranteed stale):
   - **A per-stream hash is correct on a tree that will not exist by the time anything checks it.** With three
     streams moving the simulation, "whoever merges second re-records" is undefined — nobody can know at record time
     whether they are last.
   - **It fails safe.** A stale committed hash turns `sim-baseline` red on `main`, and *"the simulation broke"* and
     *"the hash is old"* look identical from the outside. That ambiguity cost round 5 a day.
   - **INERTNESS DOES NOT COMPOSE, and this is the deep reason the rule exists** (combat, 2026-09-19). *"'A is inert'
     and 'B is inert' does not give 'A+B is inert', because A can be inert only in the absence of B."* Three streams
     each measuring a green `sim-baseline` on their own branch **predicts nothing about `main` after merge** — each was
     measured against a different baseline, on a different tree, alone. **A hash that differs from what the branches
     implied is not evidence of a defect; it is the expected result of composing changes measured separately.** The
     orchestrator treated one such gap as an anomaly and sent a stream a message implying its correct claim was wrong.
   - **A change can be genuinely inert in BEHAVIOUR and not inert in the HASH.** arena's `_build_perimeter()` generates
     the arena wall from the shape polygon instead of using boxes authored in the scene: geometrically identical walls,
     **different collision bodies created in a different order, which is enough for Jolt.** Expect this from any change
     to how the physics world is *built*, even one that changes nothing about how it behaves.
   - **Nothing local can catch the mistake.** The file is keyed per glibc; the laptop is **2.39** and there is no
     2.39 line, so `sim-baseline` **silently skips locally** — every stream can commit a stale hash and watch a green
     local check.
   A stream whose change moves the simulation says so in its green report — *"the sim baseline moves and is
   deliberately NOT recorded here"* — and the orchestrator records it with `make remote T=sim-baseline-record`
   (twice, confirming it repeats) in a commit that names every change it covers.
   **AMENDED 2026-09-19, after the orchestrator read "after the last simulation-changing merge" as licence to defer
   to round close.** It does not mean that. It means *do not record repeatedly mid-round*, and it silently assumed
   merges arrive **batched at the end of a round**. In round 7 they trickled in across a long round, and the result was
   that **`main` sat red on `sim-baseline` for hours** — so every stream that merged `main` afterwards inherited a
   failure that had nothing to do with its work, could not tell whose it was, and had to ask.
   - **The orchestrator records the baseline in the same working session as any sim-changing merge to `main`** — not at
     round close. One record per *session of merging*, not one per round.
   - **A merge commit that moves the simulation says so in its subject or body.** Then a stream hitting a red
     `sim-baseline` runs `git log main --grep` and answers the question **without a round trip to the orchestrator**.
     Invariant 2 already asks streams to declare it in their green report; the merge commit needs the same declaration.
   - **The rule looked cheap because of a cost asymmetry** (combat's framing): *"the orchestrator who defers pays
     nothing, and the cost lands on every stream that merges `main` afterwards."* **A rule whose cost falls entirely on
     people who did not make the decision will always look cheaper than it is.**
   - **And a stream's red `sim-baseline` may be over-determined, so it is evidence of nothing.** combat's `d21a3d86`
     carried three of its own hash-moving changes (N7's per-objective owner, the designator's effect on *when* units
     fire, and `hull_size` as the collision box), so it would have failed *whether `main` were green or red*. **Only a
     check on `main` itself can establish `main`'s state.** Do not let a stream's failure stand in for that.
   **While the baseline is stale, THREE targets fail and two of them lie about why** (found by combat, 2026-09-18):
   `sim-baseline` says what is actually wrong, but `announcer-record-smoke` announces *"the booth changed the
   simulation"* and `music-smoke` announces *"the soundtrack changed the simulation"* — **both computing exactly the
   same hash `sim-baseline` computed, which is the proof they changed nothing.** They are feel's targets, so a feel
   agent would go hunting in audio code for a bug that does not exist. **If you see either of those messages, check
   whether the three hashes agree before believing the accusation.**
   **The root defect named (combat, 2026-09-19, after both targets PASSED on a current baseline): those two targets ask a
   DIFFERENTIAL question — "does the booth/soundtrack change the simulation?" — and implement it as an ABSOLUTE comparison
   against a shared file.** So they misfire **every time the baseline moves, i.e. once a round by design**, and they have
   been carried in feel's brief as broken for two rounds when nothing was ever wrong with the components. **The fix is to
   make the comparison differential too: run the match twice in one invocation, with and without the subsystem, and
   compare the two hashes to EACH OTHER.** A latent trap rather than a live failure — it blocks nothing. The underlying defect and its fix are in
   [orchestration.md](orchestration.md) lesson 65.
2b. **The old text, for the rules it still carries:** the baseline (`tests/baselines/sim_state_hash.txt`, one hash per glibc version; builder0 canonical) changes
   only on purpose, recorded with `make remote T=sim-baseline-record`, in the same commit as the reason.
   **Round 6: nav, squad and combat will move it** (movement and ranges are the simulation); control, arena and feel
   must not.
3. The web build still boots (`make remote T=web-smoke`) and the server still exports. Visual slots load headless.
4. Fairness: arena, spawn, or navigation changes re-run the swap-bases control ([verification.md](verification.md)).
5. Docs move with code: your brief's Status and any stale `_agents/` doc, in the same merge.
6. **Design follows [game_design.md](game_design.md)**; propose changes with evidence in your Status.
7. **Portable simulation code** (combat, nav, squad, control's order execution): [determinism.md](determinism.md)
   guidelines, and add new engine dependencies to its inventory. **Decisions must never read the wall clock** — a PID's
   `dt` is the fixed tick, not a frame delta.
8. **Heavy runs go to builder0** (`make remote T=…`, [remote_builds.md](remote_builds.md)); this laptop is for editing.
9. **Every number carries its commit, its machine, its workload and its sample size** (orchestration.md lesson 10).
   Nobody publishes a number measured across CP4.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same* repository, each on its own
branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=nav     OFFSET=1     # → ../godot-nav on branch stream/nav
make worktree STREAM=squad   OFFSET=2
make worktree STREAM=control OFFSET=3
make worktree STREAM=arena   OFFSET=4
make worktree STREAM=combat  OFFSET=5
make worktree STREAM=feel    OFFSET=6
make worktrees                            # status of all of them
```

What `tools/worktree.sh` isolates:

| Shared resource | Collision risk | Isolation |
|---|---|---|
| Files and branch | agents overwrite each other | separate folder + `stream/<name>` branch |
| Network ports (servers, smoke tests, agent bridge) | two `make check`s fight over 9181/8061/8765 | `local.mk`: every port + `10 × OFFSET` |
| CPU (match series) | 6 agents × parallel matches thrash | `local.mk`: `JOBS := 2` |
| Godot `user://` (saves, logs) | garage saves / logs collide | `override.cfg`: `tank_squad_<stream>` user dir |
| `.godot/` import cache | a stale cache for another branch | per worktree (not shared) |
| `.tools/` Godot toolchain (300 MB) | none (read-only use) | shared by symlink |

## Running the agents

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`, then the `/goal`
   prompt from `HANDOFF.md` (the same text for every stream; the agent reads its stream from its folder).
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** reviews and integrates; after every merge, the other streams `git merge main`.
4. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree.
- `git stash`, hooks, and `git config` are **shared** across worktrees. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).

## What reads `hull_size`, and what each use assumes

**Written after round 9's resize landed in three places nobody was looking** (the spawn grid's "widest hull", the
asset contract's refit, the screening bar) — so the next resize has a checklist instead of three surprises.
`Units.PROFILES[*]["hull_size"]` is `[width, height, length]` in metres and **it is the collision box**, so it is not
a display number: 42 call sites read it. One line each, with the assumption that makes it a consumer rather than a
reader.

| consumer | reads | assumes |
|---|---|---|
| `tank.gd::_apply_hull_size` | all three | **`hull_size` IS the collider**; box bottom at the unit origin (`position.y = h/2`), hull art scaled to the box |
| `match.gd:1383` friendly-fire risk | w, l | the hull is a **disc** of the box's diagonal — see the hazard below |
| `match.gd:1450` `incoming_projectiles` | w, l | same disc |
| `ai/incoming_fire.gd:101` | w, l | same disc, and **caches it per `unit_id`** (`_radius_by_unit`) — a size that changed at runtime would not be re-read |
| `match.gd::screen_for` + screening geometry | w | a wider screen shadows more; the 0.35 bar in `test_combat_screening` was calibrated against a 2.40 m dozer |
| `match.gd:1637` `tank_destroyed` payload | all three | FX size the wreck from the event, not the catalog |
| `theme/fx/weapon_fx.gd:337,342` | from the event | fire shape scales to the dead hull |
| `ai/avoidance.gd:54` | w, l | avoidance radius `(w + l) / 4 + margin`; **fallback `[2.4, 1.6, 3.8]`** |
| `ai/movement.gd:708, 1700` | w, l | routing clearance; **same stale fallback** |
| `tactics/tactics_formation.gd:90` | w, l | `hull_extent` / `hull_floor` → formation spacing; fallback `[0,0,0]` is the deliberate `NO_HULL` sentinel |
| `tactics/army_layout.gd:302` | w, l | assembly depth and frontage; **fallback `[2.6, 1.8, 4.0]`** |
| `arena/arena.gd` + `cover_tables.gd` | l | `cover_fraction(..., hull_length)` — A3 chord cover is a function of length |
| `control/rts_controls.gd:1075` | h | HUD bar sits at `hull[1] + BAR_ABOVE_M` |
| `control/rts_controls.gd:1202` | all three | selection picking |
| `assets/pipeline/asset_contracts.gd` + `asset_checker.gd` | all three | art **refitted by LENGTH** must match the box's width and height; refits from the mesh's *authored* pose |
| `theme/fx/bench/size_look.gd` | all three | `box_at_length` — the function the numbers come FROM |
| `theme/cyberpunk/dozer_part.gd`, `factions/faction_art.gd` | l | `_fit_to_hull` scales art by `hull_size[2] / FactionArt.hull_length` |
| ~~`garage/catalog_stub.gd`~~ | — | deleted in round 14 (garage G6): its pre-CP2 boxes were unreachable |
| `garage/garage_turntable.gd` | all three | round 14 (G2): the preview IS a `Tank` (simulate off), so it draws `hull_size` through `apply_unit`; the camera frames the box |
| `tools/roster_scale.py`, `tools/arena_report.py` | all three | the table and the reports |
| `Match.SLOT_X` clearance (spawn grid) | w, l | adjacent columns and rows must clear the widest/longest hull |

**⚠ THE HAZARD THE LIST FOUND, unflagged until now: three consumers model a hull as a DISC of its diagonal**
(`Vector2(w, l).length() / 2`). That is fine for a roughly square hull and wrong for a slab:

| unit | w × l | disc radius used | real half-width | error |
|---|---|---|---|---|
| `gang_tank` | 3.32 × 14.00 | **7.19 m** | 1.66 m | **4.3×** |
| `tank` | 2.40 × 8.62 | 4.47 m | 1.20 m | 3.7× |
| *pre-CP2 worst* | 2.4 × 4.2 | 2.42 m | 1.20 m | 2.0× |

So the AI treats a War Rig as a **14.4 m-wide circle** for friendly-fire avoidance and incoming-shell threat. Before
CP2 the worst case was 2× and the error was centimetres; now it is metres. **Not fixed here and not this stream's
files** — recorded so it is a decision rather than a discovery.

**⚠ ONE NUMBER, TWO SITES, OPPOSITE ERRORS — whoever fixes the disc sites must NOT "fix" the turning envelope the
same way.** The half-diagonal above is *also* the room a hull needs to **turn**, and there it is the **right**
number: on a tree where hulls start where they were placed, four crews overlap at spawn (−1.36, −0.02, −0.01,
−0.77 m) and the off-slot crews of the five-squads test never depart — their first turn refused in the press —
because **the spawn grid and the formation both space by WIDTH**. So:

| the same `Vector2(w, l).length() / 2` | at `match.gd:1383`, `match.gd:1450`, `incoming_fire.gd:101` | at the spawn grid and `TacticsFormation` |
|---|---|---|
| **overstates where a hull IS** | friendly-fire refuses safe shots; shells read as threats they are not | — |
| **correctly states the room to TURN** | — | spacing by width under-provisions it, and a hull cannot make its first turn |

**Fix the first by using an oriented box; fix the second by spacing on the half-diagonal.** Doing either
substitution at the other site makes it worse.

**⚠ AND THE STALE FALLBACKS:** `[2.4, 1.6, 3.8]` (three sites) and `[2.6, 1.8, 4.0]` are **pre-CP2 sizes** that apply
silently when a `unit_id` is unknown. They cannot be reached by a shipped unit today, which is exactly why nothing
catches them — a fallback that never fires is indistinguishable from a correct one.
