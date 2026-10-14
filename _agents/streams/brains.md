# Stream: brains (artillery drives to your side and shells from there; a drawn flank is carried out; your bridge 108/108 again)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–303), `_agents/game_design.md` *Round 28 direction*
> (his calls 3 and 4), *Round 28: decided for him*, **Round 29: his artillery call**, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 29** (C29.1–C29.8), and round 28's brains report
> (`streams/archive/round28/brains.md`: *FINAL REPORT*, B1, B2, B4). **You own:** `game/ai/**` EXCEPT traffic's,
> manoeuvre's and native's carve-outs (C29 list; `order_controller.gd` is manoeuvre's face path + native's seams),
> `game/tactics/**`, `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`,
> `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **Granted to others in your files:** traffic's one gate line each
> at `_track_progress`, `_update_phase` and the element's make-room / re-seat clock (C29.3: a crew holding for traffic is
> not stalled, not "blocked", not re-seated); manoeuvre's three lines in `TankBrain._order_move`; scout's SUPPRESS arm
> only if manoeuvre's stretch opens (C29.6). **The C++ (C29.2):** `decide`, `build_situation`'s core and the
> TacticalQuery functions run in C++: a change there goes to native as a diff first.

## The lead's direction

**Round 28, his calls (2026-10-12):** artillery with a drawn attack side: **SHELL FROM HIS SIDE** ("a drag means the same
thing for every unit"); a drawn flank onto a stronger squad: **SWING ROUND ANYWAY** (the squad carries out the order even
if it costs crews). Decided for him (reversible): a target that CHARGES the squad latches the flank "in" and the squad
fights where it is (`--approach-latch=off` restores the literal rule).
**Round 29, his artillery call (2026-10-13), his words:** *"I thought artillery generally had the disadvantage that it needs
to be positioned still in order to fire."* Re-asked in those terms, he chose **GO STRAIGHT TO MY SIDE**: it packs up, drives
round, sets up on his side and opens fire; the first round ~25 s after the order is accepted. It does NOT set up and fire
where it stands first.

What he will notice: drag a side for his artillery and it drives round without stopping to fire, sets up on that side and
shells from there. Drag a side for a squad attacking a dug-in enemy and it comes round and hits it from that side. His
bridge drill passes every cell again.

## Where things stand (main `bcef46a1`)

- **B2 artillery from the drawn side, parked** on `lab/brains-r28-battery` = `88b6a724`. Tuning seeds 4–6 (builder0,
  n = 18): fires from the side 18/18 (median shooter bearing 28.2°), alive 3.00 = clicked, first round 25.8 s v clicked
  2.3 s. It failed only on the first round's +23.5 s against a +15 s cut-off: **he has now accepted that wait**. Three
  traced fixes are on the branch: a mortar on a named move deploys and never leaves; a plain move fires at will on contact
  and deploys; a column re-laid from the moving centre swung round its post. Today on main a battery already carries its
  approach through `APPROACH_BATTERY`.
- **B1 a drawn flank, parked** on `lab/brains-r28-flank` = `f3a0145d`. Judged (fresh seeds 7–9 × 6 ticks): (a) even roster
  on side 10/18 against a bar of 12 (clicked 0/18; kills 10 v 4, alive 2.00 v 1.50); (c) a charging target 4/18 and the
  fight guard failed (kills 10 v 18, alive 2.39 v 4.89): the latch needs the target inside the CREWS' reach (35 m × 1.15),
  but the charging IFV stops at its own 45–60 m to shoot, so the trucks are shot while going round. (b) a Law five is a
  wipe either way (balance). On main `APPROACH_CARRY` is off (`--approach-carry=on` for B1's rule).
- **B4 his bridge 106/108, parked** on `lab/brains-r28-reissue` = `254fd98f`. Bisected to `7baffe24` (round 26: a heading
  change > 20° re-issues a crew's order); `--reissue-heading=off` gives 4/4 v 2/4 on his cells. The narrow fix (re-issue
  only when the TASK's drawn facing changed) traded his two cells for two new ones: rust t5 seed 1 (crossed 3/4) and
  rust t16 seed 2 (rim).
- Tools: `make approach-trace`, `flank-probe`, `flank-clip`, `recon-probe`, `contact-census`, `queued-screen-shots`,
  `bridge-series`, `bridge-pooled`.

## Backlog (in order)

**B1 — artillery from his side, his way (DECLARED).** From `88b6a724` with its three fixes: on a drawn side a battery packs
up, drives round to its post on the drawn side WITHOUT deploying on the way (no fire at will that deploys it, no named-move
deploy), sets up there and fires. Clicked artillery unchanged. **Bar (send before the numbers; one attempt):** fresh
seeds (not 4–9), n = 18: fires from the side (median shooter bearing within the side cone) ≥ 16/18; alive ≥ clicked − 0.5;
**no round fired before it is on side** (a counter, lesson 300); first round ≤ clicked + 30 s median (his accepted ~25 s;
the cut-off is the orchestrator's, set from round 28's 25.8 s); clicked byte-identical; ≤ 0.5 ms. A before/after
`flank-clip`-style clip of one run for him.

**B2 — a drawn flank, the target's reach (DECLARED; the last attempt).** From `f3a0145d`: the latch keys on the TARGET's
reach of a crew (a charging target that stops at its own 45–60 m to shoot latches "in" there), not the crews' own reach.
The rest of B1's design stays (column on a wide ring, the side-sector fight). **Bar (send before the numbers):** round 28's
bar (median hit bearing within 35°; (a) even roster ≥ 12/18; (c) charging ≥ 9/18 or the partial rule; fight guard kills ≥
clicked − 2, alive ≥ clicked − 0.5; (b) reported; clicked byte-identical) on NEW fresh seeds 10–12 × {1,3,6,8,11,16}
(lesson 298: (a) is NOT re-judged on new seeds for a latch-only change unless the bar says so up front; say which).
`flank-probe` on 3 fresh seeds and a before/after `flank-clip` on one seed where it comes round (what he judges).

**B3 — his bridge 108/108 (DECLARED).** Trace the two cells `254fd98f` loses (rust t5 seed 1: crossed 3/4; rust t16 seed 2:
the rim) BEFORE another fix (lesson 302); then one fix that keeps round 26's re-issue case (its tests) and passes all 108.
Bar: 108/108; reorder_heading + the fight tests pass; arrive series fresh seeds not below control − 1 on the 8 m line,
median within +2 %; thirteen declared.

**B4 — the gang trucks' screen slots (formation geometry, C29.8).** Four gang gun trucks (10 m hulls) screening get 6 m
slots side-on; one parallel-parks for ~1 min (TacticsLab seed 61, screen to `[LANE_X, 0]` facing east from 50 m south).
Slots laid at hull length for long hulls arriving side-on. Also any slot spread manoeuvre's M1 asks for (through the
orchestrator).

**B5 — stretch:** the element re-seating crews 3/4 for 36 s at a blocked slot (traffic's T3 lead: Sumps arrive cell
law_scout:law_ifv:law_tank:law_tank, seed 1, `make traffic-settle-trace`, n = 1, a lead); a queued attack-move / attack
after a waypoint takes its automatic facing from the last waypoint (B5's known gap); the support-by-fire line for wheeled
turret hulls (O3: 91° drawn v 56° clicked) if manoeuvre's M1 does not cover it.

## How to verify

`make remote T=check` (builder0 only, C29.7); `approach-trace`, `flank-probe`, `flank-clip`, `bridge-series`,
`bridge-pooled`, arrive series, `native-verify-scenarios`; clips and shots for him (look at them).

## Don't touch

Traffic's `traffic*.gd`, `avoidance.gd`, the give-way block, `_avoid`; manoeuvre's drive body, k-turn block,
`manoeuvre*.gd`, `wall_contact.gd`, `order_controller.gd`; native's `native/**`; `game/control/**` (ask: round 28's B5
grant is closed).

## Waiting on the lead

Nothing: his calls are made (artillery: go straight to his side, 2026-10-13).

## Status

### Round 29 FINAL REPORT (2026-10-14; green hash: see the last line of this block)
**Shipped to main:** B1 artillery from his side (main `c0ac69e0`); B2 drawn flank, the target's reach (`fa099d5b` →
`23d94eb3`); B5 queued attack (`5ab05468` → `1f5c84e4`).
**Parked, with branches (round 30):**
- **B5c** arrival-gate rule: `lab/brains-r29-gate` = `brains-b5c-flip` = `a8df3dc3` (judged attempt `053beffb`, every
  bar line passed; judged data kept). Native's mirror: `lab/native-b5c` (incl. `b01a8959`, the a8df3dc3 mirror). The flip
  failed round 8's 180° facing test; the narrow fix moved yard 23 (t1/t3/t6/t8 later, t11 earlier) and Sumps 6. Why,
  by the counters (not traced per crew): `reached_facing_away` fired in every moved cell (yard 129–220, Sumps 6: 33), so
  those cars no longer latched at a gate reached facing out and, with the stalled give-up held off while turning, went
  round it again: yard's 33 s gate-circling (what the v2 latch had fixed) partly returns. Sumps 4 and 7 fired it too
  (39, 21) and did not move.
- **B3** his bridge: `lab/brains-r29-bridge` = `474cf510` (fixes rust t5 s1; t16 s2 needs route-aware seating).
- **B4** gang trucks' screen slots: the cause is the gate (B5c); spacing pass on `lab/brains-r29-linespread` = `3fc0cb01`.
**Round-30 leads:** route-aware seating (B3 t16 s2: an attack-move seated by straight line across a crossing); the gate
refinement (keep yard's latch win AND come round for a 180° facing; no gate when the hull is inside the approach length
and the route via the gate is much longer; the 180° test in the bar from the start); the SBF per-crew trace (wheeled
turret hulls, drawn worse); splitting `test_tactics_scenarios` (orchestrator's lead).
**Stream v main:** game/ equals main except a 4-line comment in `game/ai/tank_brain.gd` (B5a's LATENT note at the move
dedup); the rest is probes, `mk/tactics.mk` and this brief.
GREEN HASH: pending (check running).

### Plan (2026-10-13; start = stream `3cd5596b`, covered by the launch check, main `bcef46a1` green)
1. **B1** artillery from his side: restore `88b6a724` on main, instrument it first (per-crew counters, lesson 300), trace the
   tuning seeds 4–6 before tuning, send the bar, judge on fresh seeds 13–15 (10–12 are B2's).
2. **B2** a drawn flank, the target's reach (from `f3a0145d`; its code is already on the stream, off by default).
3. **B3** his bridge: trace the two cells `254fd98f` loses before any fix (lesson 302).
4. **B4** gang trucks' screen slots (formation geometry).
5. **B5** stretch.
**Re-ordered 2026-10-13 (orchestrator godot-67):** B5's first item, the element's arrival re-seating onto `no_path` seats,
moves up to after B2 and before B3. Second sighting: traffic's Terminus head-on (stream/traffic `3a94f38d`, builder0,
tuning seeds 1–3): 6 of 9 crews left out are B_5, the rear tank, re-seated beside the block onto `no_path` seats (about
10 at base). The first sighting was round 28's T3 Sumps cell. The first cut to try: a seat that reads `no_path` is not handed
to a crew. Trace first (lesson 302). Order now: B1 → B2 → B5a (re-seat) → B3 → B4 → rest of B5.
Plan accepted (godot-67): B5a is judged on main's behaviour (traffic's CP-T absent) unless CP-T has merged by then. If it
has, the orchestrator says so, main is merged first, and both arms run with it. Traffic's C29.3 gate line stays untouched.
Why this order: the brief's own order. B1 first because its code also brings back B2's (the parked branch holds both).

### B1 — artillery from his side, his way (DECLARED; bar ACCEPTED 2026-10-13, filed at main `ad56bdea`)
**Candidate `c2ae6e68`.** Round 28's battery (`88b6a724`) applied on main (game/ diff `3e2f6e13..88b6a724`; B1-flank code
comes with it, off by default), plus four traced fixes (builder0, seed 4–6 traces, tick-level events in `approach-trace`):
1. Once round, the battery's line is **the post it drove to** (`battery_post`, 20° in from the side), not the side's
   centre line: re-laid there, a truck that had set up packed up and drove again (seed 5: set up 0.99 → 0.23 a second
   after "in").
2. **Standoff = ARTILLERY_SAFE_DISTANCE + 10 m** (90 m): at exactly 80 m a truck stopping a metre short read "too close"
   in BOMBARD, backed off and packed up mid set-up (seeds 4–6: 3–5 repacks a run → 1 in 3 runs).
3. A battery crew sets up and shells only **inside the 30° side cone** (B1-flank's 40° sector let a wing truck set up at
   37°: a round from off the side, seed 4).
4. **No notch past the post** (a 0° notch sent it beyond its post to the centre line).
Tried and reverted: shelling only within 8 m of its place (trucks circled 10–20 m off their slots for 45 s, first round
74 s, seed 4).
**Instrument (lesson 300):** ApproachStage now counts, per crew, rounds fired from > 35° off the side, set-ups started off
the side (after the crew has driven off), repacks (set up, then packed while the target lives), and rounds before the
element was round; `approach-trace` logs each as an EVENT with the crew's order, brain choice and movement phase.
**Tuning** (builder0, `c2ae6e68`'s tree, seeds 4–6 t1, n = 3): fired from the side 3/3 (median shooter 28.8°), rounds
off the side 0, first round 26.8 s median, alive 3.00, killed 3/3; repacks 1.
**The remaining repack is traffic's give-way** (traced seed 4 at 26 s): a set-up truck (deploy 1.00, order attack,
move_order stop) is `phase yielding, yield_to` the squadmate driving to its place, and giving way packs it up. Request
sent (via the orchestrator): a set-up hull does not yield. Reported, not bar.
**Bar (sent before the numbers, accepted):** fresh seeds 13–15 × {1,3,6,8,11,16}, n = 18 an arm, both arms at `c2ae6e68`:
side (median shooter ≤ 35°) ≥ 16/18; rounds from a crew > 35° off = 0; alive ≥ clicked − 0.5; first round median ≤
clicked + 30 s; clicked byte-identical to main `bcef46a1`'s; cost NOT READABLE (runs only for an all-artillery element
with a drawn approach). CPU line: the CPU never draws an approach (only `rts_controls` sets `task.approach`). C29.2: none
ported. The one attempt; else it parks.
**Judged: PASS, every bar line** (builder0; east and clicked arms at `c2ae6e68`, base run main `bcef46a1`; seeds 13–15 ×
{1,3,6,8,11,16}, n = 18 per arm, 90 s):
- From the side: 18/18 (clicked 0/18). Median of run medians 28.1°.
- Rounds from a crew > 35° off: 0.
- Alive: 3.00 (clicked 3.00).
- First round median: 27.1 s, worst 30.9 s (clicked 2.3 s), so +24.8 s.
- Killed: 18/18 in both arms (median 35.7 s v 9.3 s).
- Clicked: all 18 rows identical field for field with main's.
- Reported, not bar: set-ups off the side 6, repacks 8, runs clean 10/18, rounds before the element read "in" 2 (one run).
**Worst run** (seed 15, tick 16): 2 rounds before "in" (32.8 s), both from inside the cone; 3 repacks. Trace queued.
**Check:** the first `make check` (B2 work-in-progress files in the worktree) gave 24/25 targets. Unit tests 2556/0;
net-smoke FAILED (one of its two clients saw 1 of 2 tanks); combat-smoke NOT RUN (it depends on net-smoke). A clean check
on `c2ae6e68` is queued. No green hash yet.
**Clean check** (scratch worktree at exactly `c2ae6e68`, builder0): `>> remote: make check exited 0`; 24 passed,
2 NOT JUDGED; unit tests 2556/0; net-smoke and combat-smoke pass (the first failure was a flake); bridge-pooled 18/18.
The NOT JUDGED pair is perf-judge (refused 3×, the box was busy: 1.60–1.90×) and scenario_perf, which goes with it.
`perf-judge` is re-running alone on `c2ae6e68`.

### B2 — a drawn flank, the target's reach (DECLARED; the last attempt; bar ACCEPTED 2026-10-13 by godot-67)
**The change.** Built from `f3a0145d`'s design (a column on a wide ring, the side-sector fight once round).
- The charge latch keys on the TARGET's reach of a crew: its own weapon range, or the crew's reach × 1.15, whichever is
  longer. It also remembers a charge for 4 s after the target stops to shoot (`approach_round.closing_tick`).
- `--approach-latch=crews` is round 28's rule.
- `APPROACH_CARRY` goes ON by default; `--approach-carry=off` is B0's rule.
**Bar.** Both arms at one commit, built on B1 (`c2ae6e68`, which merges first). Fresh seeds 10–12 × {1,3,6,8,11,16},
n = 18 per arm per roster. Tuning on seeds 4–6. Measuring point: the median hit's bearing within 35° of the side.
- (a) Even roster: ≥ 12/18. Re-judged on the new seeds, declared up front: carry goes on for every element. Round 28's
  10/18 is reported beside it.
- (c) Moving target: ≥ 9/18, or the partial rule ((a) passes and (c) beats clicked by ≥ 5).
- Fight guard on (a) and (c): kills ≥ clicked − 2, alive ≥ clicked − 0.5.
- Side/rear hit share ≥ clicked.
- Clicked: byte-identical.
- (b) Law five: reported.
- Latch counter (`latched_s`), worst run read first.
- `flank-probe` on seeds 13–15, and a before/after clip.
**The orchestrator's additions:**
1. B1's drawn-artillery arm on 13 t1, 14 t1 and 15 t1 at B2's commit: identical to `c2ae6e68`'s rows, or meeting B1's
   bar lines.
2. A clicked attack, and a drawn one on a non-charging target, plan the same as under `--approach-latch=crews`
   (unit test `test_the_new_latch_moves_nothing_but_a_charge`).
3. `bridge-pooled` 18/18; the arrive series unchanged.
CPU line: the CPU never draws an approach. C29.2: nothing native-ported. A fail parks it on `lab/brains-r29-flank`.
**Ruling on (c)** (godot-67, after (c)'s tuning, disclosed; it follows C28.5, written before those numbers): (c) is judged
on the fight guard, side/rear share ≥ clicked, and the latch counter showing the latch fired. On-side for (c) is
reported. Added line: in (a) (a holding target) the latch fires in 0 of 18 runs. The artillery counter is left out of
B2's table.
**JUDGED at `fa099d5b`** (stream: main `c0ac69e0` + B2; builder0; scratch worktrees at exactly that commit and at main;
seeds 10–12 × {1,3,6,8,11,16}, n = 18 per arm per roster):
| roster | arm | on side (median hit ≤ 35°) | killed | alive | side/rear share | latch fired | verdict |
|---|---|---|---|---|---|---|---|
| (a) even | B2 | **14/18** (median 32.8°) | 8 | 1.78 | 0.88 | 0/18 | bar 12 PASS; guard PASS; latch 0 PASS |
| (a) even | clicked | 0/18 (79.7°) | 4 | 1.11 | 0.82 | 0/18 | |
| (c) moving | B2 | 0/18, reported | 18 | 5.00 | 0.78 | 18/18 (median 3.1 s) | guard PASS; share PASS; latch fired |
| (c) moving | clicked | 0/18 | 18 | 4.78 | 0.76 | 0/18 | |
| (b) Law five | B2 | 0/18 by hit (5 runs hit); by reach 9/18 | 0 | 0.00 | — | 0/18 | reported (a wipe either way) |
| (b) Law five | clicked | 0/18 | 0 | 0.00 | 0.84 | 0/18 | |
- Clicked: all 54 rows identical to main's.
- Addition 1: the battery's 13/14/15 t1 rows are identical to `c2ae6e68`'s.
- Addition 3: bridge-pooled 18/18. The arrive series equality is pending.
- Round 28's (a), for comparison: 10/18 on seeds 7–9.
**Worst run** ((a) seed 12, tick 16): all five trucks lost and the IFV survives, against clicked 5 alive and the IFV
killed. Trace queued.
**Tuning (c)** (builder0, `a97d5aab`, seeds 4–6, n = 18): the latch fired in 18/18 runs (median 3.1 s); on side 0/18 v
clicked 0/18; killed 18/18 v 18/18; alive 5.00 v 4.83; side/rear share 0.83 v 0.74.

### B5a — the arrival seating onto `no_path` seats (traced first, lesson 302)
**Terminus head-on** (traffic's case; seed 1, tick 11; main's behaviour; builder0 `790548fd`, `make reseat-trace`).
B_4 never arrives (traffic's own trace matches).
- The cause is a MAKE-ROOM swap, not a re-seat. At 48.4 s B_5 had been 20 m off its herringbone slot (-58.3, 81.2) for
  4 s. B_4 was parked on its own slot beside it, so the two traded slots.
- B_4's route to that slot is 21.6 m for a 12 m gap: it goes west round the south-west block's corner, then back east.
- B_4 stalls on the last leg ("terrain" for 2 s, then `no_path` at (-75.9, 87.8)) and is still there at the end.
- At the hand-over the slot did NOT read `no_path` from B_4's spot: the path reached it (0.0 m short). It read
  `no_path` only once B_4 was stuck west of it.
**Sumps cell** (law_scout:law_ifv:law_tank:law_tank, seed 1; `make traffic-settle-trace TRAFFIC_SETTLE_ARMS=none`; all
in at 83.0 s):
- Crew 4's slot (11.1, -73.4) read blocked/`no_path` from 48 s to 61 s.
- At 61.0 s make-room traded it to crew 3, which was parked beside it (seats 2310 → 2301, round 28's T3 pair).
- Crew 3 then read `no_path` too, from 64 s to 71 s, and reached the slot at 81 s by a long way round.
**Plan (accepted in principle by godot-67; bar before numbers, after B2):**
(i) Make-room never trades away a slot its stuck crew reads `no_path` for.
(ii) After arrival, a crew whose movement has read `no_path` at its slot for N s gets that slot moved to the nearest point
it can stand on and reach. The bar must name N and the reachable-point rule. Guard: a crew merely pausing (a give-way, or
traffic's hold) is not re-slotted.
**Deeper traces** (builder0; `make reach-probe` on an empty map; `reseat-trace`'s NOPATH lines with Movement's route
reading; native and GDScript paths identical):
- **Sumps — the seat is the fault.** Slot (11.1, -73.4) sits 3.6 m off the navmesh (NO_PATH_MARGIN 3.0), so every crew
  driving there reads `no_path`, from every start probed (102 points). `Element.ground` pushes a slot clear of
  obstacles, but not onto the mesh.
- **Terminus — the seat is fine.** It is on the mesh; from B_4's stuck spot the route is 18.8 m. Two other causes:
  1. A stale leash. B_4's move order keeps a leash centred on its OLD slot (14 m). At the swap the brain's element
     context still held the old slot, and `TankBrain._order_move`'s 2 m dedup drops every later order with the same
     x/z, leash or not, so the leash never refreshes.
  2. The arrival gate. B_4 is wheeled and its seat faces east, so Movement sends it to a gate about 17 m west of the slot,
     across the street by the arena edge. It grinds there, and `_blocker` labels it `no_path` because its route ends at
     the gate, not the slot.
**B5a WITHDRAWN (stream `25bc2ad2`, before any bar).** In the live match the Sumps seat sits ON the mesh: the on-mesh rule
fired 0 times, and the test's own Sumps read it on the mesh too. The reach probe's 3.6 m was read before the arena had
finished loading (no `lab.start`). Lesson: probe the navmesh only in a started match.
`SETTLE_NOPATH` (builder0) shows the real cause in both sightings, the arrival gate:
- Sumps crew 4 drives to path_goal (3.69, -54.82), a gate 20 m back from its slot along the seat's facing (APPROACH_MAX).
  It stalls about 7 m short.
- Movement's `_blocker` then labels it `no_path` because its route ends at the gate, not the slot (reachable, goal_gap 0).
- Terminus B_4 is the same, with a gate about 17 m west of its slot.
- The make-room guard fired once, on that mislabel.
B5a's code and test are removed; the probes stay.
**B5b dropped.** The order's leash is opt-in and off (`Movement.leash_on`; native "off here"). A LATENT note sits at
`TankBrain._order_move`'s dedup: it ignores the leash, so whoever turns the leash on must compare its centre.
**B5c — the arrival gate (`Movement._approach_gate`, brains-owned; native mirrors it at drive_native.cpp:779, so it is a
C29.2 pair with native).** The one fix for traffic's T3 lead. Inverted switch `--nav-off=gategiveup` (ON when given);
any `--nav-off` hands the drive to GDScript, so both arms run `--brains-off=native`.
- v1 (`b00b6f96`, give the gate up when BLOCKED aiming at it): fired 3–4 per run, fixed neither case (Sumps: within 8 m
  24 s sooner but S_3 overshot 7.5 m; Terminus unchanged).
- Third sighting confirmed (orchestrator's; yard_open crossing, main code, seed 22, builder0): ticks 1/3/6 all arrive by
  90 s, but B_1 circles 4–10 m round its gate 20 m back of a herringbone slot from 17 s to 50 s (in at 66.8 s v ~10–25 s).
  Cause: `reached` (GATE_REACHED 2.5 m) is judged afresh every tick, so a car at its gate pointing off the heading heads
  for the goal, leaves 2.5 m and is sent back.
- **v3 = the last attempt (`053beffb`; bar ACCEPTED by godot-67 with n = 12, bridge-pooled added, Terminus reported):**
  (i) give up when blocked; (ii) a REACHED gate stays done for its goal; (iii) a gate only where a ring of navmesh one
  turning radius round it exists, else the longest shorter run-in (75/50/25 %), else none ("cramped").
  Tuning n = 1 (builder0): yard t3 last crew in 26.2 s v 71.3 s; Sumps within 8 m 56.5 s v 82.6 s; Terminus unchanged.
- **Terminus B_4 is not the gate:** its gate has the room by the navmesh; it reaches it (latch fires) and jams on terrain
  4.8 m on, "blocked terrain" 8 s+ to the end (reseat-trace TRACK lines). An escape failure: to round 30 for manoeuvre.
- Judged running at `053beffb`: yard seeds 23–24 × {1,3,6,8,11,16}, Sumps seeds 2–13, Terminus 2–4, bridge-pooled on
  (**18/18**, exited 0; note its four law_tanks are tracked, so the gate never runs there), arrive series 25–28.
- Follow-up `9926f3bb` (native's review): the roomy gate memoised per hull on exactly (goal, heading, length, radius);
  latched refusals counted as "latched". No behaviour change; equality vs `053beffb` on the tuning cells queued.
- Native (godot-native-1b) reviewed the diff: mirrors cleanly. Shipping = the default flip + native's mirror back to back.
- Follow-up equality (builder0): `9926f3bb` v `053beffb` on the three tuning cells, every trace line and report field
  identical; only refusal labels move (most former "stalled" were latched arrivals).
- **Guards so far (053beffb, builder0, both arms `--brains-off=native`):** arrive series seeds 25–28 (5 maps × 5 squads):
  within 8 m off 89/100 (median 29.1 s) → on **100/100 (24.8 s)**, none lost, 11 gained; latched 151, given up 33,
  shortened 3126. bridge-pooled with the switch on 18/18 (law_tank is WHEELED, radius 8 m: the gate ran there; an
  earlier note here said tracked, wrong).
### B3 — his bridge 108/108: TRACED, time-boxed, PARKED (`lab/brains-r29-bridge` = `474cf510`)
Both cells `254fd98f` loses (builder0; candidate = stream + 254fd98f re-applied): the candidate equals
`--reissue-heading=off` in both, round 26's rule (`=plan`) passes both. Not the gate (identical with gategiveup on).
- **Rust t5 seed 1** (3/4, deck jam 112.9 s): S_2 stops "arrived" in the far mouth of the west swing bridge (far),
  4.8 m short of its seat; the mouth rule's once-per-seat guard holds it (it was mouth-sent from the deck at 18.5 s to a
  seat 2.3 m away); S_4 and S_1 jam behind it to the end. Round 26's heading re-issue was the accidental second send.
  **Fix (parked):** the guard gives way while the crew holds up a squadmate (one blocked by / yielding to it), at most
  every RE_ISSUE_TICKS (`--mouth-held=off`): 4/4, in 39.3 s, counter 1.
- **Rust t16 seed 2** (rim 4.2 s): seating. When the drill ends at 12.5 s an attack-move (drills on, so no transit and
  no route seating) seats by straight line and the seating is fixed (flow joined); both crews then route east round via
  the bridge and their seats cross; S_2 yields at the rim. Round 26's "stop" at 12 s delays the join and it re-seats
  right at 17 s. Needs route-aware seating for an attack-move across a crossing: round 30.
- The full 108 was not run: with cell 2 failing it cannot meet the bar (a new failing cell).
### B4 — the gang trucks' screen slots: the cause is the ARRIVAL GATE (B5c), not the pitch
`make screen-slots` (TacticsLab seed 61, four gang_tank, hull 14 m, screen east from 50 m south; builder0, stream):
grounding lays the line at a 6.0 m pitch (z 25.6 / 5.8 / −12.8 / −18.6) and A_2 is blocked no_path / terrain from
20 s to the end, 18.5 m off. A spacing pass (pitch → 15.8 m) does NOT free it; B5c's rule does, with or without the
spacing (A_2 in at 18.3 s / 22.2 s). Six metres between hulls parked side by side facing east is physical (2.9 m wide).
The spacing pass is parked on `lab/brains-r29-linespread` (`3fc0cb01`, tests 4/0); B4 rode on B5c's flip, so with B5c
parked B4 is unfixed this round (A_2 still stuck at seed 61); round 30, with B5c.
**B2 MERGED** alone: `fa099d5b` → main `23d94eb3` (check: exited 0, 2559/0, ALL JUDGED). flank-probe 13–15 (fa099d5b,
builder0): drawn 6/6 on task, 5/6 reached (median 25 s; the miss, right-13, parks on the ring 0.4° outside 35°), clicked
1/6. Clip: `~/projects/clips/round29/flank_drawn_vs_clicked_fa099d5b_seed10t3.mp4` (even roster, seed 10 t3: drawn 5
alive, IFV dead 29.1 s, hits 32° off; clicked 1 alive, IFV lives, 89° off).
Clip for him (B1): seed 13 t1, clicked v drawn east, copied by the orchestrator to main's
`build/round29/artillery_side_by_side.mp4`.

### B5c — PARKED for round 30 (`lab/brains-r29-gate` = `a8df3dc3`; reverted on the stream, `785dd103`)
The pair check went red on round 8's `test_wheeled_arrival` (180° facing). The narrow fix (`a8df3dc3`) passes it, but
its judged cells MOVED (GDScript path, builder0, rule on): yard 23 last crew in t1 21.7 → 32.8 s, t3 22.1 → 39.9 s,
t6 20.7 → 24.2, t8 24.8 → 25.6, t11 26.7 → 23.1; Sumps 6 moved (35.47 → 35.17 within 8 m), Sumps 2–5 and 7 identical;
`reached_facing_away` fires in every yard cell (129–220 refusals). B5c's last attempt was used, so by godot-67's rule it
parks; the run was stopped there (yard 24, Sumps 8–13, Terminus, bridge and arrive not rerun). Native's mirror is not
merged. **For round 30:** the yard crossing reaches its gates facing away often, so the latch is what wins yard; a
round-30 rule needs both a latch that keeps yard's win and a way round for the 180° case (e.g. latch facing away
only after one circuit, or lay a 180° gate to the side), judged with the 180° test in the bar from the start.
Record of the judged attempt (`053beffb`), every bar line passed:
Builder0, both arms `--brains-off=native`, fresh seeds:
| line | off | on |
|---|---|---|
| Yard crossing (23–24 × {1,3,6,8,11,16}, n = 12): last crew in, median | never (7/12 runs never all in) | **21.95 s** (10/10 every run) |
| Sumps (seeds 2–13, n = 12): all within 8 m, median | 38.8 s | **36.0 s** (no run > 5 s later) |
| Sumps guns_on_arc | 0.94 | 0.94 |
| Terminus (2–4, reported): crews arrived | 10 / 10 / 9 | 10 / 10 / 10 |
| Arrive series (25–28, n = 100): within 8 m | 89/100 (29.1 s) | **100/100 (24.8 s)** |
| bridge-pooled, switch on | — | 18/18 |
Counter > 0 in every on-arm run, 0 in every off-arm run.
**Worst run** (Terminus seed 3, squad B's last 62.1 → 74.2 s): B_4, 9 m from its east-facing slot, is sent 17.5 m back
to a gate by the west edge, reaches it (latched) and jams on terrain ~8 s (manoeuvre's escape, round 30). The gate's own
cost: it pulls a car already near its slot back. **Round-30 refinement recorded:** no gate when the hull is within the
approach length and the route via the gate is much longer.
**FLIP:** `brains-b5c-flip` = `ed843d63` (stream `3114a9f1` + `gate_giveup_on()` → `not switched_off("gategiveup")`;
nothing else in game code). Native's mirror: stream/native `1fabe6a8` (test `e0a80733`), combined with the flip at
`4a293e8a`; native's proof: 6000 drives + 189 forced stalls, 0 mismatches. The orchestrator's merge conditions: yard and
Sumps on the default native path equal to the judged on-arm run for run, then check + native-verify-suite on the pair.
**Pair check RED (native, tree `e0a80733`, builder0: 2581/1):** `test_wheeled_arrival::…face_the_way_it_came…` dot 0.50
(needs > 0.85), the same on the GDScript path, so the cause is the flip. Traced (builder0): the gate lies 17.5 m PAST the
goal; the car reaches it at 6.0 s still pointing out (dot −0.88 to the heading), the v2 latch marks it done, and it
loops straight to the goal and arrives 60° off. With the latch narrowed, the stalled give-up then dropped the gate
mid-turn: circling behind it at 8.3 m/s reads as no progress to the goal ("blocked no_path"). **Fix `a8df3dc3`**
(`brains-b5c-flip`): a gate reached with forward·heading < 0 is not latched (refusal `reached_facing_away`), and
`_gate_turning_for` holds off the stalled give-up for that goal until the latch fires or the goal moves. Trace: arrives
16.9 s, dot 0.98; wheeled_arrival + nav_gate_hold 15/0 (builder0). The orchestrator's rule: the judged cells must be
identical to the on-arm, else B5c parks. Native mirrors the new member (exec_fields.h + drive_native.cpp).
**Lesson:** round 8's own test caught a behaviour gap the judged bar missed. The bar's heading line (test_nav_gate_hold)
ordered a facing 90° off travel, where a car reaches its gate already near the heading. A 180° facing puts the gate
beyond the goal and the car reaches it facing out. Run a gate change against the existing facing tests on the default
path BEFORE it is judged, and give a heading bar the 180° case as well as the 90° one.
### B5 — queued attack (GRANTED: rts_controls.gd's order-queue hunk + `_order_squads`)
A shifted attack-move or attack on a squad still driving queues behind its waypoints (`Element.enqueue`); an
attack-move's automatic facing is from the last waypoint (an attack faces its target: none added). A chain of shift+A
runs leg by leg from each last point; a shifted plain move goes behind a task already queued; an element's attack is
done when its target is dead or gone; several squads each queue behind their own. Unshifted, and shift+A on an idle
squad, as before. `177a7419` + `11dde288`; builder0 31/0 and 24/0 (queued task, element, controls tests). The stream's check at
`11dde288` failed ONE test, by design of the pair: `test_native_exec_state` wanted B5c's four new Movement members in
`native/src/exec_fields.h`. Resolved by parking B5c (`785dd103`). B5
alone: `brains-b5-queued` = main `5b1307b8` + `55d1f566` + `5ab05468`: **GREEN at `5ab05468`** (builder0: exited 0, 2580/0,
26 targets ALL JUDGED, sim-baseline unmoved); **MERGED** `5ab05468` → main `1f5c84e4` (godot-67).
### B5 — support by fire, wheeled turret hulls: REPRODUCED, not fixed (round 30)
`make hull-rest-probe FACING_ONLY=faced_support_by_fire` (`053beffb`, builder0, 4 factions × 6 seeds, 24 runs an arm):
wheels/turret drawn median 80.5° v clicked 57.1° (n = 168, p 0.019; ≥ 100°: 42 % v 27 %); every other class is as good
or better drawn. Artillery dominates the tail (gang_artillery 128° v 109°, law_artillery 142° v 47°) and deploys for
indirect fire. Worse drawn: law_tank 106.8° v 30.6°, gang_ifv 47.6° v 24.8°, burner 71.2° v 46.4°; gang_tank better
drawn (48.0° v 77.9°). In every law run, BOTH arms, the squad is not arrived when the probe reads it ("settled" ≈ 19 s,
crews still): it measures hulls stopped on the way, not on the line. Needs a per-crew trace of a drawn SBF (the screen
test has none) before any fix.

### Requests to other streams
- **traffic:** a hull that is set up (`deploy_ratio > 0`) does not give way; the asker goes round (B1's last repack).

### Questions for the lead
None.
