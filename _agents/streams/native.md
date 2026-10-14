# Stream: native (stage 1: the driving and shooting half of the brain in C++, equal answer)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7: what a port must look like to pay*,
> *P3*, *Stage 1*), `_agents/game_design.md` *Round 26: his C++ decision*, `_agents/workstreams.md` *Round 27* (C27.2,
> C27.4, C27.6, C27.7), and round 26's perf report (`streams/archive/round26/perf.md`, the FINAL REPORT and the *DRAFT —
> round 27's stage-1 brief*, lifted below). **You own:** `native/**`, `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main; **plus the stage-1 grants:** the seam
> at the top of `OrderController.compute_command`; `Movement`'s and `Gunnery`'s member STORAGE behind accessors
> (`movement.gd`, `gunnery.gd`); `traffic.gd` for its port; `wall_contact.gd`'s observer. **This stream outlives round
> 27** (C27.7): ~2.5–3 weeks; the worktree is kept at the round's close.

## The lead's direction (2026-10-11)

**"Driving+shooting half (Recommended)"** — the execute half next round, priced on his laptop (`game_design.md` *Round
26: his C++ decision*). What he was told: 20 a side reaches about full speed on his laptop (0.96–1.03 depending on the
day's baseline; 0.918 measured at `d84f7503`), 25 a side 0.88–0.92; ~2.5–3 weeks (re-costed from ~2: the C++ must own
the state); driving and shooting changes wait or are written twice meanwhile; stage 2 (the think half) only if he wants
bigger armies. His standing target: low-end hardware (he playtests on a UHD 620 laptop on purpose).

**Where things stand (verify at main):** the native drive (with GDScript callbacks), avoidance, the route tail,
situation's core, decide, the two TacticalQuery functions, dodge, cover, nav, native_el, M1's gate are C++. The
callbacks the drive makes into GDScript: `_next_waypoint`'s re-plan (~45 us a drive), `_planned_reverse` and the
k-turn planner, `_negotiate`/`_blocker`/the give-way, `_keep_station`, `_approach_gate`, `_repair`,
`_inflate_corners`, `_chord_slack`, `_manoeuvre`'s decision (CP1b's `Traffic` did not ship in round 26: its v4
failed traffic's pre-registered rule; if a later version lands, it is ported here, reading the record, never as a
callback, C26.10). Measured for this design (round 26, builder0): one native call per crew reading a shared record costs
~8 us of crossing; the C++ does the work at ~5 % of the GDScript; **reading the 97 fixed-type members of a crew's
Movement/Gunnery/Lay through the engine costs ~23 us a crew (464 us a gather for 20 crews,
`test_native_mover_record`, `631e678f`)** — so the execute state must LIVE in C++ (owned, written by the C++), with
GDScript reading it through accessors, never re-gathered every tick.

**Shape:** ONE native call per crew per tick at the top of `OrderController.compute_command`, equal answer (the
think/execute interleave stays; a batched execute was priced at +0.005 game speed for a declared change: not taken).
The per-tick record (pose, contacts) gathered once a tick and shared with avoidance.

**Ownership (grants):** perf's own (`native/**`, `game/ai/native/**`, `tests/native/**`, `tests/test_native*.gd`,
`mk/native.mk`, `brain_switches.gd`) plus: the seam at the top of `OrderController.compute_command`; `Movement`'s and
`Gunnery`'s member STORAGE behind accessors (movement.gd: brains', traffic's and manoeuvre's blocks; gunnery.gd);
`Traffic` (traffic's) for its port; `wall_contact.gd`'s observer.

**The freeze (C26.2 widened to the whole execute step):** while the stream runs, a behaviour change to
`movement.gd`'s drive and its callbacks, `gunnery.gd`, `order_controller.gd`'s execute path, `steering.gd`,
`avoidance.gd`, `traffic.gd`, `wall_contact.gd`, `clothoid.gd` waits, or comes to native-exec as a diff to port.
Think-side files (`tank_brain.gd`'s situation/decide/act, tactics, elements) are NOT frozen.

**Backlog (in order):**
1. **E1 the execute state owned in C++** (from round 26's `MoverRecord`, `native/src/mover_record.*`, OFF): Movement's,
   Gunnery's and the lay's members move into native structs with GDScript accessors (`Movement.state()`,
   `route_arms()`, the census counters, `in_kturn`, `is_under_way`, `straight_and_clear`, the HUD's and explain
   overlay's reads); the field-by-field test kept; OFF, then ON with the full check unmoved.
2. **E2 the drive's callbacks**, cheapest first, each proven by `test_native_drive` (live-function): `_chord_slack`,
   `_inflate_corners`, `_keep_station`, `_approach_gate`, `_repair`; then `_negotiate`/`_blocker`; then
   `_planned_reverse` + the k-turn planner; then the re-plan block; `_manoeuvre`'s decision last.
3. **E3 gunnery** (the scan loop around the engine's ray, aim, engage, lanes, cover, `_clear_to_fire`, suppress,
   indirect) — tag `n7-weapon-slices` has proven aim and engage to start from.
4. **E4 reflexes, unstick, the wall-contact observer.**
5. **E5 the per-crew `execute` seam** ON in an A/B (`--brains-off=native_exec`), `native-proof` equal with and without
   leaders, the thirteen lines and determinism unmoved, `make check` and `make check NATIVE=off`.
6. **E6 the laptop's ruling.**

**The bar and the arms (written before the run):** `make native-tick-profile`, bar workload (foundry + parade, 8-20 s,
seeds 92721 31337 5988), his preset, **arms `s20@20` and `s25@25`, each ON v `--brains-off=native_exec`, ABBA, n = 6
paired**, `--squad-cap` pinned, ARMY_CAP_FIELDED read in every log, a session voided if prio0 moves; **ON when the tick's
scripts fall >= 2 % outside 2 se** at 20 a side; reported: game speed at 20 and 25, the split (P1's table) re-taken.
The estimate it checks: 11-15 % of the tick's scripts.

**Ownership, re-costed (the orchestrator's check, 2026-10-11 05:20; counted at `3e0f5815`):** of the 94 typed
members, the sites OUTSIDE movement.gd/gunnery.gd are few: 27 in 4 game files through a mover/gunnery reference
(order_controller, native_route, match_recorder, think_quiet) + ~20 game reads through OrderController's 9 forwarding
properties (already getters: one line each to repoint) + 73 in 17 test files (mostly perf's own native tests); the 607
sites INSIDE the two scripts stay as the GDScript reference (web build, NATIVE=off, the live-function proofs), which
keeps its members; with native ON the C++ owns the state and the GDScript members are written back only for the
fields read outside (a per-tick publish of ~45 fields x the crews, or accessors over one packed snapshot a tick).
**Days: ~2.5-3 weeks, not 2** (+2-3 days for the accessor/publish layer and its proof). **Do the accessors eat the
saving?** Not if they read a snapshot: one native call a tick hands a packed array, each read is then a GDScript array
index (~0.05 us); a native call per read (~1-8 us) at the few hundred outside reads a tick would cost 0.1-0.6 ms
builder0 and must not be the design. The publish's own cost is pre-registered as part of E1's measurement.

**First item:** E1, starting from `MoverRecord` (configure / gather / row, `test_native_mover_record`) — turn the
read-only gather into ownership one owner at a time (the lay first: 3 fields, one writer).

## Round 29 backlog (the orchestrator, 2026-10-13; contracts C29.2, C29.4, C29.7 in `workstreams.md` *Round 29*)

Round 29 runs traffic (1), manoeuvre (2), brains (3) beside you. In order:
1. **The pairs (C29.2), pre-empting everything below:** traffic's street hold (T1: the hold as a record field the drive
   reads; `Traffic.holding`), manoeuvre's creep as legs (M2) and anything from its turn room (M1) that touches the drive or
   unstick. Equal-answer proof, the pair merged back to back. Also the held N5 ports once their owners' changes ship
   (`_negotiate`'s body / `ask` / `_begin_yield` after CP-T; the k-turn planner and `_manoeuvre` after CP-M2).
2. **N7.3: N7.3a built, equal, priced a LOSS (+0.7 % of the tick), committed OFF for stage 2; N7.3b skipped** (the
   orchestrator's ruling 2026-10-13: glue, not a core component; C29.4's freeze released).
3. **E6b on his laptop: GRANTED 2026-10-13 ~10:56 PDT** (rule D as written below). **DONE 12:10 PDT** (`b2712987`):
   20 a side no C++ 0.854 -> shipped 0.936, 25 a side no C++ 0.672 -> shipped 0.878; *E6b* below.
4. **N7.4 wall contact: DONE, equal, priced a LOSS (+0.22 % of the tick), committed OFF** (`native_wall`; the N7.3a
   precedent). Manoeuvre's word (M2 leaves `wall_contact.gd` alone) came through the orchestrator.
1b. **C29.2 pair, traffic T1: DONE and green** (`59c1cc09` = stream/native + traffic `3a94f38d`): the street hold in the
   native drive, equal; the NativeHold scaffold reverted (*Round 29: traffic's street hold in the native drive* below).
5. N7.5 (element_feed) waits until after round 29; stage 2 stays deferred (his call).

## Round 28 backlog (the orchestrator, 2026-10-12 ~11:45 PDT; contracts C28.2, C28.3 in `workstreams.md` *Round 28*)

1. **N1 E6 now** (GO'd; running from 11:21:56 PDT on `19543dae`'s code), rule D as pre-registered.
2. **N2 the ruling commit:** if E6 meets rule D, flip `native_exec`/`native_owned` ON in one commit (`native_cb` only if it
   ever clears its own bar), thirteen lines and determinism unmoved, check, hand the orchestrator the hash; if not, write
   up why and what would.
3. **N3 the port partner (C28.2):** traffic (the crossing rule, `right_of_way`/`_avoid`), manoeuvre (turret hulls turning
   to a drawn facing, a planned turn for the creep, the face path), scout/brains for any `decide` diff. They send settled
   diffs; native ports each with an equal-answer proof; the pairs merge back to back. Every OFF-proven port stays green.
4. **N4 stage 2 priced for him:** the think half (situation/decide/act/tactics polls) as one batched pass: days and the
   expected laptop speed at 25 a side, as a decision he can make in player terms.

Merge main (44b6be5c) after E6 is reported, not during.

**Round 28 additions (the orchestrator, 2026-10-12 afternoon; the lead's stage 2 call in `game_design.md` *Round 28: his
stage 2 call*):** stage 2 (the think half) is **DEFERRED**, an open item. A new principle supersedes "port only what
pays": *"even if there's not an obvious benefit to moving to C++ … long-term we are better positioned for a good game by
having the core components in C++."* So, after N3 (which stays first whenever a stream sends a diff):

5. **N5 the rest of the execute in C++**, equal-answer proofs, even where the gain is ~0: the k-turn planner's body, what is
   left of the re-plan block, the drive's remaining callbacks (`_manoeuvre`'s decision, `_negotiate`'s body with
   `ask`/`_begin_yield`, `_repair`, the first-use caches). Every port keeps `native-verify-suite` green and the doors rule.
6. **N6 propose (do not start)** the next core components outside the AI's thinking (perception / line of sight, combat
   resolution, nav queries), sized in days, for the orchestrator to order.

## Who changes your frozen files this round (C27.2)

- **Scout** may change `_manoeuvre`'s M1 `reaimed` rule in `movement.gd` and `game/ai/manoeuvre.gd` (still GDScript
  callbacks from the native drive: no port needed until your E2 reaches `_manoeuvre` — it is last), and may change
  `decide`'s ORBIT scoring (C++: you port that diff; the pair merges back to back).
- **Brains** works think-side; a `decide`/`build_situation` change comes to you as a diff.
- Anything else in the frozen list waits, or comes to you as a diff to port. Re-base E1/E2 on scout's declared merge
  when the orchestrator announces it (`git merge main` at that checkpoint only).

## How to verify

`make remote T=check` and `make remote T=check NATIVE=off` (both green before any ON); the live-function proofs
(`test_native_drive`, `test_native_mover_record`, …); `native-proof` equal with and without leaders; the thirteen lines
and determinism unmoved; the bar above with every number carrying its commit, machine, workload and n. The laptop is
one instrument: a laptop session only in a slot the orchestrator grants (C27.6) — E6 is that session.

## Don't touch

Scout's `combat_motion.gd` and fight-motion hunk of `tank_brain.gd`; brains' think side (`tank_brain.gd`'s
situation/decide/act outside your seams, `game/tactics/**`, elements); orders' `game/control/**`, `game/camera/**`.

## Waiting on the lead

E6 (the laptop's ruling) needs a laptop slot; he plays the result. **Asked for 2026-10-12 ~05:00 PDT** (`63f8cca4`).

## Status

_Started 2026-10-11 18:25 PDT from `c37605f0` (main's green check `090b345d` covers it: no baseline re-run). Heavy runs on
builder0; the laptop only in a granted slot (C27.6)._

### The report (read this first; kept current)

**Round 29 report (2026-10-14; the round is closing).** On main: stage 1, N6.1b-N6.4, N7.1, N7.2, **N7.6 (ON)**.
**N7.3a** (`native_controller`) is equal and **OFF by its price**. **N7.4** (`native_wall`, the wall-contact observer) is equal
(12000 observes, 0 mismatches) and **OFF by its price** (+0.22 % of the tick, builder0). **E6b DONE** on his laptop
(`b2712987`): 20 a side, no C++ 0.854 -> shipped 0.936; 25 a side, 0.672 -> shipped 0.878. **The CP-T pair is GREEN at
`59c1cc09`** and on main (`1267ffb1` + `1113062c`). That is stream/native + traffic `3a94f38d`. builder0: `make check
exited 0`, 2554 passed / 0 failed, 26 targets ALL JUDGED, thirteen unmoved, determinism `2875411ff4ec6be7`;
`native-verify-suite` scenarios 52/0 and `native-live-guard` 21 switches live, both exited 0. Traffic's T1 street hold
runs in the native drive, equal, and traffic's judged Terminus head-on on the native path matches their GDScript arm run for
run (section below). The hand-back scaffold (`bde8de0a`) is reverted. **B5c (brains' arrival gate) is PARKED for round
30.** The mirror was equal, but the flip failed `test_wheeled_arrival`, and brains' fix moved their judged cells. The work
is kept on `lab/native-b5c`; stream/native was reset to before it (section below). **No other pairs this round:** traffic
T3 and manoeuvre M1, M2 and M4 all failed their bars, so nothing to port. T1c needed no C++.
**Next (round 30):** N7.5 after the round's split; B5c from `lab/native-b5c` once brains' flip is judged; the held N5 ports
(`_negotiate`'s body / ask / `_begin_yield`, the k-turn planner, `_manoeuvre`) when manoeuvre's code settles; stage 2
deferred (his call).

| item | state |
|---|---|
| E1 the execute state owned in C++ | DONE (mirror design, priced ~2 us a crew; on main) |
| E2 the drive's callbacks | DONE for the common callbacks (`native_cb`, OFF by its price, B); left as callbacks: the k-turn planner's body, `_manoeuvre`'s decision, `_negotiate`'s body, `_repair` (rare paths; the planner ~0.5-1 % of a tick) |
| E3 gunnery | DONE (incl. ARC) |
| E4 reflexes, unstick, wall contact | unstick DONE; reflexes hand back (brains never set any); the wall-contact observer stays GDScript (it runs before think, outside the seam; ~0.47 ms a tick headless) |
| E5 the per-crew execute seam | DONE and ON: `native_exec` + `native_owned` + `native_cb`; native-proof equal on every arm; the doors audited (`native-verify-suite`, `native-verify-scenarios`) |
| E6 the laptop's ruling | DONE: rules ON (20 a side -8.59 %, 0.890 -> 0.930; 25 a side -7.21 %, 0.818 -> 0.865) |

**What to playtest:** `make native && make skirmish` on his laptop: the same fights as before, nothing should look or
play differently, and the opening clash at 20 a side should run at ~0.93 of real time (0.89 before). `--brains-off=
native_exec` puts the old execute back for a side-by-side.

**Known issues:** none open in native's code. Wheeled hulls under a `face` order and crews with reflexes still hand back
(~3.6 % of executes in his Sumps).

### Plan (in order; one-line reasons)

1. **E1a the field table and the owned struct** (`native/src/exec_fields.h`, `exec_state.{h,cpp}`): ONE X-macro list of
   every script member of Movement (128), Gunnery (12 stored; its 5 forwarding getters are not state) and the Lay (3),
   generating the typed C++ struct, the names, `pull` (GDScript -> C++), `push` (C++ -> GDScript: every field, or only
   those the C++ changed), and a field-by-field `row`. Tests (`test_native_exec_state`): the table IS the scripts'
   member list with their types (drift fails); pull == the GDScript's read in a Sumps fight; scramble every member ->
   push puts back exactly what was pulled (containers by identity); a changed-only push writes exactly the changed
   fields. OFF: nothing in the game calls it. *Why a table, not MoverRecord's runtime spec:* the execute code needs
   typed fields at compile time; the drift test keeps the table honest the way the runtime spec did.
2. **E1b the in-game proof** (`--native-exec-mirror`, measurement only): at the top of `compute_command` pull, scramble,
   push; `native-proof` must print the one hash (push is lossless over a whole match).
3. **E1c the View template:** `drive_native.cpp` rewritten over a typed view `V` (`ObjectView` = the live members
   through get/set, today's behaviour; `StructView` = the owned struct). ObjectView ON = today's numbers exactly
   (`test_native_drive`, `native-proof`); StructView proven by the same tests. *Why:* every E2-E4 port is then written
   once and pays at once in today's mode (it removes a crossing, N7 (b)), and at E5 the same code runs on the owned
   struct with no rewrite.
4. **E2** the drive's callbacks in the brief's order, each with `test_native_drive` (live-function) and `native-proof`.
5. **E3** gunnery; **E4** reflexes, unstick, wall contact; **E5** the per-crew `execute` seam on StructView (pull only
   when GDScript wrote the state: a dirty mark at every outside writer, with a verify mode that pulls and diffs every
   tick to find a missed one); **E6** the laptop (a granted slot).

**Decision (E1, recorded for the orchestrator): a MIRROR, not accessors.** With the C++ owning the state, after each
native execute the C++ pushes back only the fields it changed (dirty bits, a set costs ~0.1 us), so the GDScript
members are always current and every reader outside the execute step (OrderController's forwarders, think_quiet,
the census, match_recorder, the HUD, tank_brain's `straight_and_clear`, other crews' think) keeps working with NO
code change and no stale-read risk. The brief's accessor design needed ~47 game sites + 73 test sites repointed and a
packed snapshot a tick; the mirror's cost is changed-fields x ~0.1 us, pre-registered and measured at E5.

### Done

- **E1a the table and the owned struct** (`bfd90266`): `native/src/exec_fields.h` (143 fields: Movement 128, Gunnery
  12, Lay 3), `exec_state.{h,cpp}`, bindings `exec_*` on TankNative. builder0, `test_native_exec_state` 4/0: the table
  is the scripts' 143 members; 600 pulls in a Sumps fight, 85 800 values, 0 mismatches; 34 320 members scrambled then
  pushed back, 0 not restored (Arrays/Dictionaries by identity); a changed-only push writes exactly the 6 changed
  fields. OFF (nothing in the game calls it).
- **E1b the in-game proof** (`bfd90266`): `native-proof NATIVE_PROOF_ARMS="on off ab mirror"`, builder0: every crew
  pulled, scrambled and pushed back at the top of every `compute_command` (135 000 crews, 19.0 M members):
  on = off = ab = mirror = `770df71a443ba743`. (First run segfaulted at process exit: the static registry freed its
  Variants after the engine; now emptied at the library's unload and the mirror uses a local struct.)

- **E1c + E2a** (`9b641aca`, check pending): the drive on a typed view (`exec_view.h`): live members (ObjectView,
  as before) or the owned struct (StructView, `--native-exec-owned`). E2a under switch `native_cb` (ON; price pending):
  `_keep_station` + its PID's `step_with_rate` and `reset` in place, `_inflate_corners` (the identity in the native
  drive's configuration), `Pathing.query`, `_blocker`, `_negotiate`'s early returns, `_planned_reverse`'s look to its
  cheap exits. builder0: `test_native_drive` 5/0 both views (2160 + 1440 drives, 0 mismatches); `native-proof`
  on = off = ab = owned (Sumps `770df71a443ba743`, foundry `a401412b50925d19`).

- **Since the slot** (`a9357a96`, `63f8cca4` green: builder0 check 2520/0, ALL JUDGED, thirteen unmoved, det
  `2875411ff4ec6be7`; its first run failed test_combat's respawn flake, the orchestrator's, fixed on main): the gun's last
  GDScript calls ported; `--native-exec-profile`. Merged main at `8623c224` (green, merged to main by the orchestrator).
- **E3 / E4 / E5 written, in test** (since committed, see above): `gun_native.cpp` (Gunnery.apply line by line
  on the view: the scan loop, `_shootable`, Engagement's `is_seen`/`acquire_seconds`/`crossing_rate`/`Lay.engage`/`lose`,
  Ballistics, Difficulty's wander, OrderFeed.point, `_cover`, `_clear_to_fire`; still called: ARC's `_apply_indirect`,
  the native scan's seam, AiTickCache, the spotter, Difficulty.for_team (once a frame a team), FireLanes.for_shot (once a
  reload), Tank.ready_to_fire/ammo_fraction), switch `native_gun` OFF; `unstick` + the pressed-wall escape in the drive's
  template (the rare stuck event's `_hull_within`/`_ask_behind` called); `execute_native.cpp`: compute_command's common
  path (living hull, no reflexes, not giving way, a move_to) as ONE call composing drive + unstick + gun +
  `note_decision` + `held_aim_point` + `bind` on one view, anything else handed back untouched; switch `native_exec` OFF.
  Proofs: `test_native_gun` (three arms from one snapshot, synthetic orders for every branch), unstick inside
  `test_native_drive` (forced states for every branch), `test_native_execute` (compute_command three ways).

**The mirror's price (the orchestrator's condition on E1, 2026-10-11 ~20:30):** the push of CHANGED fields at a drive's
end, which is what E5 keeps. builder0 (load ~15-20), `native-tp-headless` 20 a side + leaders, `--native-exec-owned`,
seeds 92721 31337 5988, 25 000 drives each (whole match, not only the window), `9b641aca`: **foundry 8.1 fields,
1.51 / 1.59 / 1.64 us a drive; parade 8.0 fields, 1.87 / 3.18 / 3.29 us** (the slow seeds' pulls were slow too: load);
Sumps 8.5 fields, 2.3-2.5 us. Against the 9.7 us crossing and the execute GDScript it replaces (stage 1's estimate
~200-300 us a crew; the prototype slice ~27 us) the push is ~2-3 us, under the third the orchestrator set. Not yet in
it: Gunnery's and the Lay's fields (E3; ~3-5 changed a tick expected, ~+1 us). First version marked every set dirty
(22 fields, ~4 us); setters now mark only a change of bits.

**Reconciling "~200-300 us a crew" (the orchestrator, 2026-10-11 ~20:45):** that number is design text in `native.md`
*Stage 1* (round 26), never measured; the 11-15 % he decided on comes from SHARES (perf P3, `b57838ed`), and the 27 us
(perf `304d6b59`) is the prototype think-side slice. Neither feeds the estimate, so nothing is re-told to him until the
clean bar-workload measurement (plain native v `--brains-off=native`, foundry + parade, 20 a side, pinned, n = 3 seeds,
a quiet box the orchestrator holds) gives execute ms a tick, its GDScript part and us a crew a tick. A first, unclean
reading (parade 20 a side + leaders, builder0 load 15-20, owned arm with its transition pulls, every sub-lap timed,
`9b641aca`): brain/execute 11.8 of 37.2 ms tick scripts (32 %), ~37 hulls alive, ~300 us a crew a tick, of it the native
drive 5.0 ms and the weapon 4.2 -- NOT for relaying.

- **E3-E5** (`791821cf`, green: builder0 check 2472/0, ALL JUDGED, thirteen unmoved, det `2875411ff4ec6be7`):
  `test_native_gun` 8400 applies, `test_native_execute` 10 624 executes, unstick 7200, 0 mismatches each.
- **Merged main at CP-S** (`062425a5`).
- **E5b** (`47407dee`, green: builder0 check 2490/0, ALL JUDGED, thirteen unmoved, det `2875411ff4ec6be7`): the
  persistent owned state with stale bits; `exec_verify`: 91 399 executes, 169 full + 15 695 part pulls, all verified,
  0 mismatches. Found on the way: a namespace-scope `String` crashed `--import` (signal 11); dead hulls pulled the whole
  state every tick before handing back (72 775 needless full pulls). Then (`native_owned` switch, tracked-hull `face`
  native): native-proof on = exec_verify = stage1 = stage1_ab = `0398922d31f335f8`; first in-run A/B (one Sumps match,
  his armies, builder0 loaded, n = 1, NOT a ruling): `native_exec` on the owned state, band -3.6 %, tick scripts -3.2 %.

### The measurements and their rules (written 2026-10-12 before any of these numbers exist; lesson 292)

**A. Reconciliation (the orchestrator's quiet builder0 slot, pinned 0-3):** `native-tp-headless`, 20 a side + leaders,
foundry and parade x seeds 92721 31337 5988, arms plain native v `--brains-off=native`. Reported: tick scripts, the
controllers' execute ms a tick and its native part (`brain/m.native_drive`), us a crew a tick (executed crews), against
the 17 % GDScript-in-execute share the 11-15 % estimate used. **Rule:** the estimate is re-told to him only if the
measured GDScript-in-execute share is outside 12-22 % of the tick's scripts (the estimate's own range at r 0.08-0.3).

**B. `native_cb` (E2a's callback ports), same slot:** `native-price NATIVE_PRICE_SWITCH=native_cb`, n = 3, pinned.
**Rule (round 23's execute-port rule):** ON when the 50 v 50 controller band falls >= 2 % outside 2 se, hashes equal;
otherwise it stays OFF (equal answer is not enough: N7).

**C. Stage 1 headless (same slot, the second reading):** `native-tp-headless`, 20 and 25 a side, foundry + parade, 3 seeds,
arms default v `--brains-on=native_exec,native_cb,native_owned`. Reported only; no ruling from it.

**D. E6, the laptop (a slot the orchestrator grants; the ruling):** `make native-tick-profile` bar workload, his preset,
`NATIVE_TP_ARMS="b20@20= e20@20=--brains-on=native_exec,native_cb,native_owned b25@25= e25@25=--brains-on=native_exec,native_cb,native_owned"`
(ABBA built in, n = 6 paired each size, `--squad-cap` pinned by the target, ARMY_CAP_FIELDED read in every log).
**Rule:** stage 1 ships ON (`native_exec`, `native_cb`, `native_owned` true together) when the tick's scripts at 20 a side
fall >= 2 % outside 2 se, paired; a session where priority 0 (tanks, match) moves with the arm is void and re-run.
**Partial rule:** if 20 a side clears and 25 does not, it ships ON (20 a side is his preset's army); if neither clears,
OFF, and the split re-taken to find what the ON arm still pays. Reported either way: game speed at 20 and 25.

### The quiet slot (2026-10-12 02:29-02:49 PDT, builder0 quiet, pinned 0-3, `ed6ecaa9`, 3 seeds an arm; priority 0 unmoved in every pair: none void; `references/round27/native/slot-ed6ecaa9/`)

- **A, the reconciliation:** execute ~30 % of the tick's scripts at 20 a side (foundry 3.44 of 11.55 ms, parade 3.60 of
  11.80), the native drive section 1.26-1.41 ms of it, so GDScript in execute ~19-22 %: inside 12-22 %, the estimate is
  not re-told. ~86-90 us an execute a crew, ~55-65 us of it GDScript (40 executes a tick, dead hulls included). The
  "27 us" and "200-300 us" are both retired: ~60 us of GDScript a crew-tick, headless builder0.
- **B, `native_cb`:** 50 v 50 band 0.8 / 1.3 / 1.0 % saved (his Sumps -0.1/-0.3/-1.1, 25 a side -0.4/-0.4/-0.5), hashes
  equal: under 2 %: **stays OFF**.
- **C, stage 1 headless (no ruling):** tick's scripts 20 a side foundry 11.55 -> 10.67 (-7.6 %), parade 11.80 -> 10.80
  (-8.5 %); 25 a side foundry 15.81 -> 14.53 (-8.1 %), parade 15.63 -> 14.26 (-8.8 %); execute ~88 -> ~65 us a crew;
  think unchanged. Below the 11-15 % estimate so far: what the owned execute still pays is the next work, before E6.

### E6, the laptop's ruling (2026-10-12 11:21-11:54 PDT, flightdeck = his laptop, `19543dae`'s code at `6d9fa7a4`, his
preset, bar workload, ABBA, 3 cycles a run, n = 6 paired a size; `references/round27/native/e6-19543dae/`)

| | tick's scripts | outside 2 se | game speed in the window (base -> stage 1) |
|---|---|---|---|
| 20 a side | **-8.59 %** (se 3.90; foundry -12.0 se 8.0, parade -5.2 se 0.5) | yes | **0.890 -> 0.930** (+0.040, se 0.033) |
| 25 a side | **-7.21 %** (se 0.68; foundry -7.1, parade -7.3) | yes | **0.818 -> 0.865** (+0.047, se 0.006) |

- **Rule D: met at both sizes -> stage 1 rules ON.** Priority 0 not moved by the arm (20: -0.048 ms se 0.099; 25:
  +0.051 se 0.031); elements unmoved; ARMY_CAP_FIELDED right in all 24 logs (4 x 5, 5 x 5); the laptop's load steady
  1.7-2.5 through both sessions. One void cell: Godot crashed in `--import` (signal 11, inside the engine, no frame of
  ours) before parade 5988's last three runs; that cell was re-run alone, all four arms, its own cooldown and ABBA order.
- **Against the prediction:** 20 a side tick -8.59 % is inside -8 to -11 % (central -9.5); its game speed 0.930 is NOT
  0.97-0.99, because today's base is 0.890, not P1's 0.918: the prediction applied the saving to a base the laptop did
  not reproduce. 25 a side -7.21 % is just under -8 (above the -6 falsifier: no re-take of P1's split needed); its game
  speed 0.865 is inside 0.85-0.87. No falsifier fired (-6 floor not crossed; -13 ceiling not crossed).
- **For him (C28.3):** at 20 a side his laptop now runs the opening clash at ~0.93 of real time (0.89 without), not the
  1.00-1.03 he was told when he chose; at 25 a side ~0.87 (0.82 without).

### E6's prediction (pre-registered 2026-10-12 ~04:00 PDT, before the laptop session; the orchestrator's ask)

**What the ON arm is at E6:** `a9357a96`+ with `native_exec`, `native_cb`, `native_owned` (rule D). Since the slot's C
(`ed6ecaa9`) the gun's remaining GDScript calls were ported (`a9357a96`: ARC's `_apply_indirect`, Tank's reload/ammo
reads, the named-target lookup): the gun's GDScript calls ~21 -> ~4.8 us an execute (instrumented, foundry 20 a side).
An unclean re-take (builder0 not quiet: void as a reading) put the stage-1/default execute ratio at 0.73/0.67
(foundry/parade) against C's 0.74/0.73.

**What is still paid inside the owned execute** (`--native-exec-profile`, instrumented, builder0 foundry 20 a side,
~18 900 native executes a seed; shares of a native execute): the drive ~62 % (its own C++ plus the callbacks still left:
the k-turn planner past its cheap exits ~8 % of the drive, `_manoeuvre`'s decision and `_negotiate`'s body ~2 % each;
the engine's path query and the avoidance solve), the gun ~25 %, note_decision ~7 %, the command's creation ~4 %, the
state's bits ~4 %. No single remaining port is worth more than ~1 % of the tick this stage: the planner (the biggest, a
multi-day port of manoeuvre's planner) ~0.5-1 %.

**The prediction for E6** (his laptop, bar workload, paired ABBA n = 6; its reasoning: C's headless -7.6 to -8.8 % plus
~1 point from the gun's port, the laptop's shares being the builder0 shares within P1's accuracy):
- **20 a side: the tick's scripts -8 to -11 % (central -9.5 %)**; on P1's base (`d84f7503`: 0.918, wall 36.4 ms, scripts
  27.8) that is game speed **0.97-0.99** (central 0.98), not the 1.00-1.03 he was told.
- **25 a side: -8 to -11 %; game speed 0.85-0.87** (P1's base 0.803).
- **Falsifiers:** below -6 % at 20 a side means the laptop's execute share is smaller than builder0's (re-take P1's split);
  above -13 % means the instrumented profile overstated the drive (re-take without clocks).
- If the measured number is under the 11-15 % he decided on, the orchestrator tells him so with the measured game speed.
- **Addendum (2026-10-12 ~06:20 PDT, still before E6):** if E6 runs on a later commit than `63f8cca4`, it also has
  `right_of_way` native (E5c: crews giving way were ~5 % of executes and handed back to the GDScript; now 0, his Sumps
  native-proof). Expected to add ~0.2-0.5 point at 20 a side; the prediction's range stands.

### The doors audit (the orchestrator's condition on the ON commit, 2026-10-12 ~13:00 PDT)

Every GDScript write to an owned member (Movement's 128, Gunnery's 12, the Lay's 3) that can happen OUTSIDE the native
execute, by entry point (found by listing every Movement/Gunnery method called from outside its own script and every
member assignment outside it; `game/` only: tests set up state and are covered by the detector below):

| entry (who calls it, when) | writes owned members? | marks stale? |
|---|---|---|
| OrderController's 9 forwarding setters (brains' think: watch_point, spotter, hold_for_friends, engaged_target, ...) | yes | **yes** (STALE_GUN / STALE_STALL, on a change) |
| `set_orders` -> `Movement.new_order` (orders, the CPU, Movement.request) | yes | **yes** (STALE_ORDER) |
| `interrupt` -> `Movement.reset` (a new order or element call, Movement.request) | yes | **yes** (STALE_ALL) |
| `Movement.ask` (another crew's `_negotiate`/`_ask_behind`, called back from ITS native drive) | yes (`_begin_yield`) | **yes** (STALE_ALL) |
| `Movement.wheel_radius` (brains' `_wheel_radius()` on the think side) | yes, its cache, first use only | **yes, since this audit** (STALE_ALL) |
| `Movement._kturn_start_leg` (the planner, called back; tests) | yes | **yes, since `0465a11e`** |
| the GDScript compute_command (`bind`, `idle`, `drive`, `right_of_way`, `face_turn`, `keeps_heading`, `unstick`, `note_decision`, `Gunnery.apply/dead/held_aim_point`) | yes | **safe:** it runs only when the native seam is off (the seam's else marks STALE_ALL) or the native execute handed the tick back (it marks STALE_ALL) |
| a drive callback into GDScript (`_planned_reverse`, `_manoeuvre`, `_negotiate`, `_repair`, ...; manoeuvre.gd under them) | yes | **safe:** the callback is wrapped (push the struct before, pull it all after) |
| `observe_contact` -> `WallContact.observe` (every tick, before think) | no owned member (its own fields; `_yield_rec`/`_kturn_rec` Dictionaries mutated in place, shared with the struct) | n/a |
| manoeuvre_census, avoidance (`is_under_way`), tank_brain (`straight_and_clear`), rts_controls/movement_readout/two_squads_playtest (`corridor`, `legibility`, `state`), Gunnery `_nearest_shootable` | reads only | n/a |

**The detector:** `--native-exec-verify` / `TANK_NATIVE_EXEC_VERIFY=1` compares a fresh pull with the owned state before
every owned execute and raises an engine ERROR on a difference; `make native-verify-suite` runs the whole suite and the AI
scenarios that way, and native-proof's `exec_verify` arm a whole match. **C28.2's new rule** (the orchestrator): every
stream writing mover/gunnery members marks `native_stale`.

**Results (builder0, stage 1 ON):** the first `native-verify-suite` found no game door beyond the list; its 6 failures
were the proof harness itself writing members (`MoverState.restore`'s deep copies, a direct `_wheel_radius_unit` write),
now marked. It also exposed a **lifetime bug**: test processes aborted at exit ("corrupted size vs. prev_size") because
the owned states (first an extension object on each mover, then a registry emptied at the library's unload) were freed
after the GDScript language had finished, while holding script objects (the Lay, the station PID, the spotter lambda).
Fixed: a crew's state is released in `OrderController._exit_tree` (while scripts are alive; the scene tree frees its
nodes at quit), with a per-frame sweep of movers that are gone. `a3790744`: `native-verify-suite` 2520/0 tests, 50/0
scenarios, 0 verify mismatches, no exit crash; native-proof on = off = exec_verify = `0398922d31f335f8`.

### N4: stage 2 (the think half) priced for him (2026-10-12 ~12:40 PDT; an estimate, confidence low-medium)

**What it is:** situation, decide, act and the tactics polls (each crew's thinking: what to do next) as ONE batched C++
pass over all crews a tick, the GDScript kept as the reference with live-function proofs (the way stage 1 was built).
Stage 1 moved the execute half (how each crew drives and shoots).

**The estimate and its calibration:** P3 (round 26, builder0, `b57838ed`) put the whole pass at 46 % of the tick's
scripts, the execute half ~16 %, so the think half ~30 % (24-36). Stage 1's estimate landed at ~0.6 of itself on his
laptop (predicted ~13 % central; measured -8.6 % at 20 a side, -7.2 % at 25). Applying the same 0.6: **the think half
saves ~18 % of the tick's scripts (14-22 %).** On E6's laptop numbers with stage 1 ON (25 a side: 0.865 of real time,
tick scripts 30.4 ms, a game tick ~38.5 ms of wall time): 18 % is ~5.5 ms -> **25 a side ~1.0 (full speed; 0.975 at the
low end)**; 20 a side (0.93, 26.0 ms of scripts) -> **full speed with headroom.**

**The cost:** stage 1 was costed at 2.5-3 weeks and took ~1.5 days of this stream's time (Oct 11 18:25 -> Oct 12 12:30),
because the drive was already native and the proofs were reusable; the think half has no such head start (tank_brain.gd
~3 500 lines, the tactics feeds) and its inputs are Dictionary-shaped: **~1-2 weeks of one stream** (low confidence). The
real price is afterwards: the thinking is what brains changes every round, and every such change is then written twice
(GDScript + C++, proven equal), as driving changes are now (C28.2): **AI-thinking changes cost ~1.5-2x the work for as
long as the AI keeps changing.**

**The question for him, in player terms (one recommendation):** *"Your laptop now runs 20 a side at about 0.93 of real
time and 25 a side at about 0.87. Moving the AI's thinking to C++ too would make 25 a side run at full speed (20 a side
with room to spare), and take about one to two weeks; after that, every change to how the AI decides costs about twice
the work. Do it now, or once the AI's decisions have settled?"* **Recommendation: once the AI's decisions settle**
(brains reshapes the thinking every round today: doubling that cost now slows the smarter-AI work he keeps asking for;
20 a side is close to full speed already). The orchestrator puts it to him.

**N6 ORDERED (the orchestrator, 2026-10-12 evening):** (1) the tank's motion first (grant: `game/tank/**` for that port,
the seam lines only); (2) combat resolution (grant: the resolution functions in `game/match/**` and `game/tank/**`,
seams only); (3) perception + intel last of the big ones, and ASK before starting it (perception.gd is brains', and it is
stage 2's first block); (4) the nav wrappers any time. Rules: equal answer (thirteen and determinism unmoved),
native-proof on = off, native-verify-suite green, the doors rule for owned state, a switch per port defaulting ON once
its proof is green (no speed bar; the price reported). N3 diffs pre-empt all of it.

### N6: the next core components outside the AI's thinking -- PROPOSED (2026-10-12; ordered as above)

Sized from this stream's rate (stage 1: ~2 days of porting with proofs per ~1 500 lines of drive/gun) and priced from the
quiet slot's profile (builder0 headless, stage 1 ON, foundry 20 a side, tick's scripts 10.67 ms; `ed6ecaa9`). All are in
paths **nobody** owns (`game/match/**`, `game/tank/**`, `game/combat/**`): each needs the orchestrator's grant. Each is
equal-answer (hash-proven) unless declared; none is expected to move his laptop by more than ~1-4 % (the thinking is
4.8 of the 10.7 ms, the execute ~2.6, elements 1.8).

| # | component | what moves to C++ | today's cost (builder0) | days | why it's core |
|---|---|---|---|---|---|
| 1 | **The tank's motion** (`game/tank/tank.gd` drive/TankMotion, the per-tank physics step's script half) | the command -> velocity/yaw integration, the speed/turn limits, the slide bookkeeping (the engine's move_and_slide stays) | `tank` 0.63 ms (`tank/drive` 0.42) | 3-4 | every hull every tick; deterministic core of the sim; the server and the AI both depend on it |
| 2 | **Combat resolution** (`shell.gd`, `impact.gd`, `armor.gd`, damage in `match.gd`) | shell flight and hit tests, armor facing, damage/shield/kill bookkeeping (signals stay GDScript) | shells 0.014 + engagement 0.013 ms today (cheap: few rounds in flight); grows with bigger fights | 4-6 | the rules of the game; one implementation the server, the replay and the AI's lethality math can share |
| 3 | **Perception and intel** (`perception.gd`, `match.gd`'s intel refresh, `visibility_field.gd`) | who-sees-whom each intel refresh as one batched pass (the engine's rays stay), the team visibility table the AI reads | intel 0.13 + LOS bookkeeping ~0.08 ms | 2-3 | feeds both brains' thinking (stage 2's inputs) and the fog of war; batched it is stage 2's first block |
| 4 | **Nav queries' last GDScript** (`pathing.gd` wrappers, `nav.is_ready`/`nav.path` callers on the think side) | the wrappers and memo the think side still calls (the drive's are native since N5) | ~0.1 ms | 1 | small; finishes the nav layer |

**Recommended order:** 3 (it is the bridge to stage 2 when he wants it), then 1, then 2; 4 whenever convenient. None
starts before the orchestrator orders it.

### N6 progress (ordered 2026-10-12 evening; each port a switch, its proofs, its price)

| port | code | switch | proofs | price |
|---|---|---|---|---|
| **N6.1a** `TankMotion.step_in_place` | `native/src/motion_native.{h,cpp}`; seam in `game/tank/tank_motion.gd` | `native_motion` **OFF** (by its price) | `test_native_motion` 600 rolls x 40 ticks = 24 000 steps every locomotion, 0 mismatches; native-proof `motion` equal | builder0 50v50: +1.7 / +3.5 / +2.3 % (a crossing per call from GDScript's planners costs more than the step) |
| **N6.1b** `Tank._drive` as one call (incl. `move_and_slide` from C++) | `native/src/tank_drive_native.{h,cpp}`, `game/ai/native/native_tank.gd`; seam in `game/tank/tank.gd` `_drive` | `native_tank` **ON** | native-proof on = off = tank on sumps `0398922d31f335f8`, leaders `9aad48e924fc7bf4`, foundry `28b7ccfab3c5b916`, terminus `f90c67a55c7ad9e6`, yard `1f15cb10c038b2bd` | builder0 (noisy, normalised to the `match` section, 3 alternated runs an arm): tank/drive ~6.5 % cheaper, ~0.06 ms a tick at 25 a side |
| **N6.2** combat resolution's rules | `native/src/combat_native.{h,cpp}`, `game/ai/native/native_combat.gd`; seams in `game/match/match.gd` `_land_hit_result`, `game/tank/tank.gd` `take_hit` | `native_combat` **ON** (`d11f40ce`; on main `a9c492a7`) | `test_native_combat` 840 terms + 840 take_hits, 0 mismatches; native-proof on = off = tank = combat = `0398922d31f335f8` | ~0 (a few hits a second) |
| **N6.4** the nav wrappers (`Pathing.is_ready` / `query` / `find_path`) | `native/src/pathing_native.{h,cpp}`, `game/ai/native/native_pathing.gd`; seams in `game/ai/pathing.gd` | `native_pathing` **ON** (`5033c8b1`: check + verify-suite green) | `test_native_pathing` 300 pairs every switch combination (119 reachable, 121 not), 0 mismatches; native-proof on = off = pathing = `0398922d31f335f8` (builder0, `7d95ec03`) | ~~~0~~ INVALID (both arms ran the GDScript: see *the measurement-mode audit*); corrected at `5ed9b332`, builder0 quiet: tick -0.4 % (0.06 ms) |
| **N6.3** perception ONLY (granted 2026-10-13: who sees whom; **intel stays GDScript**, it is the deferred thinking half) | `native/src/perception_native.{h,cpp}`, `game/ai/native/native_perception.gd`; seam in `game/match/match.gd` `_update_intel` (the sight line and the gun-ready sample; the contact's record factored into `Match._contact`); `perception.gd` unchanged | `native_perception` **ON** (`a1174911`: check exited 0, 2524/0, thirteen unmoved; perf-judge NOT JUDGED (the box 1.5-2.5x busy); verify-suite 0 mismatches) | `test_native_perception`: `Match._update_intel` itself both ways from one snapshot, 240 poses, 7012 lines, 0 mismatches (intel, stats and the ray count bit for bit); native-proof on = off = perception = `0398922d31f335f8` (builder0, `e479c79b`) | ~~~0~~ INVALID (both arms ran the GDScript: see *the measurement-mode audit*); corrected at `5ed9b332`, builder0 quiet: intel 0.183 -> 0.088 ms (-52 %), tick -0.7 % |

Lessons: 76b0a881's check failed `test_native_motion` because creepbound (`Movement.switched_off`) had been read once at
configure; tests switch `_off` at run time, so it is asked live (fixed in dc466667). Anything the GDScript asks per call
stays asked per call.

### N7 progress (GO 2026-10-13: (1) then (2); (3)-(5) wait for round 29's split, (6) last)

| port | code | switch | proofs (builder0) | price |
|---|---|---|---|---|
| **N7.1a** `Match.incoming_projectiles` (K2) + `_damage_estimate` | `native/src/incoming_native.{h,cpp}`, combat_native's terms factored (`combat_terms`, `combat_damage_estimate`); seam at the top of `incoming_projectiles`; the threats sorted by Godot's sort with `Match._incoming_before` | `native_incoming` **ON** | `test_native_incoming` 1440 queries, 471 threats (shells and lobbed rounds), the hull as disc and box, 0 mismatches; native-proof on = off = incoming = `0398922d31f335f8` | see below |
| **N7.1b** `IncomingFire._count_in_flight` (the per-tick dodge trigger) | same files; seam in `game/ai/incoming_fire.gd` | `native_incoming` | `test_native_incoming` compares `count_for` both ways (254 counted), 0 mismatches; ai_perf_equivalence, ai_incoming_site pass | |
| **N7.1c** `Shell._fly` | `native/src/shell_native.{h,cpp}`; seam at the top of `Shell._fly` (each shell still flies from its own tick: the scene's order kept) | `native_shell` **ON** | `test_native_shell` 300 shots, 4810 ticks, 197 hits, 53 burnt out, 0 mismatches; native-proof on = off = shell = `0398922d31f335f8` | see below |
| **N7.2** the suppression field: `ThreatField` stamp_point / stamp_segment / stamp_burst / decay, `Match._update_suppression` (Tank.settle_suppression, its sight / hull-turn effects, is_pinned, the stats) | `native/src/threat_native.{h,cpp}`, worked in place on the field's own packed arrays (swapped out for the call so writing never copies); seams at the top of each stamp and of decay in `game/combat/threat_field.gd`, and after the decay in `_update_suppression`. `at` / `peak_along` / `mean_along` keep GDScript (a call costs what they do; the drive's reads are native since N4) | `native_threat` **ON** | `test_native_threat` 4000 field operations (626 points, 1780 lanes, 838 bursts, 756 decays; on, across and off the grid) and 200 suppression samples over 12 hulls (388 pinned), 0 mismatches; native-proof on = off = threat = `0398922d31f335f8` | match/suppression 0.36 -> 0.23 % (below) |
| **N7.6** the black box: `MatchRecorder._physics_process` (the squad-task scan, the once-a-second census with `census_row`, their rows written and flushed) | `native/src/recorder_native.{h,cpp}`; seam at the top of `_physics_process` in `game/match/match_recorder.gd`. The event rows (order, hit, dead, end) stay GDScript signal handlers (a few a second) | `native_recorder` **ON** | `test_native_recorder`: two recorders on one live match, one each way, 240 ticks, 62 task rows + 35 censuses (phases, orders and blocked-by filled), byte for byte, 0 mismatches. No native-proof arm: the profile/proof matches do not record (headless `--match`), so the state hash cannot see it; `native-live-guard` lists it under ELSEWHERE (held by its own test, printed) | -24 % on its own work (below) |
| **N7.3a** `OrderController._physics_process` (the per-crew tick: the contact observer's call, the stride hold, think then execute, every measurement branch) | `native/src/controller_native.{h,cpp}`; seam at the top of `_physics_process` | `native_controller` **OFF by its price** | `test_native_controller` 600 seeded scenarios on a probe brain (134 holds, 466 runs) 0 mismatches; native-proof on = off = controller = `0398922d31f335f8`, and with `--quiet-stride=3` `620e3564b48e22b2` (the hold on a live match) | **+0.7 % of the tick (a LOSS)**, below |
| **N7.4** `WallContact.observe`'s scan (alive / parked, the slide collisions, the deepest wall by script chain and `\|normal.y\| <= WALL_NORMAL_MAX_Y`, a hull touched); a wall tick is still classified by the GDScript (it re-fetches that collision) | `native/src/wall_native.{h,cpp}` (`wall_scan` -> -1 nothing to read, else bit0 = hull, `(code>>1)-1` = the wall's index), `game/ai/native/native_wall.gd`; seam in `game/ai/wall_contact.gd` observe | `native_wall` **OFF by its price** | `test_native_wall` a Sumps fight, 12000 observes (1803 with nothing to read, 543 wall ticks, 495 hull ticks), the observer's fields, statics and the mover's records, 0 mismatches; native-proof on = off = wall = `0398922d31f335f8` (`573ca520`) | **+0.22 % of the tick (a LOSS)**, below |
| `Match._land_rounds` | **kept GDScript**: its body is `_land_hit_result` per victim (signals, stats; the arithmetic native since N6.2), the suppression stamp (N7.2's field), the impact signal and an rpc; what is left is the radius/falloff filter, 0.02 % of the tick | | | |

**N7.1's price (builder0 BUSY, tick 20-36 ms; `382656de`, foundry 25 a side pinned 0-3, 3 alternated runs an arm; shares of
each run's own tick):** both OFF: K2 0.80 %, s.incoming 1.38 %, t.incoming 1.87 %, shell 0.12 %; native_incoming ON:
K2 0.74 % (-8 %), s.incoming 1.33 %, t.incoming 1.85 % (unchanged); native_shell ON: shell 0.14 % (+0.02 % of the
tick, inside the noise of a busy box). **~0 at today's fire**: ~1.2 shells in flight a tick, so the GDScript count
mostly returned at `xs.is_empty()` and its cost is the call's dispatch, which a native body does not remove. The port
pays only in heavier fire; it ships ON for the core-in-C++ principle (no speed bar), not for speed.

**N7.2's price (builder0 busy, tick 15-23 ms; `ad1dcf26`, foundry 25 a side pinned 0-3, 3 alternated runs an arm;
shares of each run's own tick):** OFF match/suppression 0.36 % (0.363 / 0.365 / 0.359); `native_threat` ON 0.23 %
(0.239 / 0.230 / 0.228): -36 % of the lap, ~0.13 % of the tick. The stamps sit inside the fire laps (a few a tick).

**N7.6's price (builder0, `45040fed`'s tree + the test's timer; in-test, both paths on the same ticks, 3 runs):** 240
ticks with the census forced 35 times: GDScript 80.3 / 81.7 / 80.0 ms, native 61.4 / 60.3 / 60.8 ms (-24 %). Most of
what is left is the flush per row (the black box's deliberate durability), the same both ways. In a real skirmish the
census lands once a second, so the share of a tick is ~0; ON for the C++-core principle.

**N7.3a's price, a loss (builder0, foundry 25 a side pinned 0-3, 3 alternated runs an arm; the controllers segment
minus think, execute and wall contact, as a share of each run's tick):** `61ef8c30` (line for line): OFF 2.09 / 1.99 /
1.96 %, ON 2.78 / 2.74 / 2.75 %; `2a3ebe19` (each static read once, `_lap` inlined, the command not read back): OFF
2.01 / 1.97 / 1.98 %, ON 2.71 / 2.69 / 2.70 %. **+0.7 % of the tick either way.** The body is glue: everything it
does is a call back into GDScript (think, compute_command's wrapper, the contact observer, wants_to_run) or a static
read, and each crossing of the extension boundary (the seam's usable(), the bridge call, ~10 gets/sets/calls a crew)
costs more than the same step inside the GDScript VM. Trimming the static reads moved it 0.05 %, so the cost is the
crossings themselves, not what is read. N7.3b (one native loop instead of the engine's per-crew dispatch) keeps those
crossings per crew, so on this evidence it lands at parity at best. **The controllers' tick pays only once think is
native (stage 2):** then the loop calls C++ from C++. Shipped OFF, the seam and its proofs kept for stage 2.

**N7.4's price, a loss (builder0, `573ca520`, foundry 25 a side pinned 0-3, seed 92721, 3 alternated runs an arm;
`brain/c.wall_contact` as a share of each run's tick; the ON arm's profile shows `native_taken.wall` 4500):** OFF 1.56 /
1.60 / 1.57 %, ON 1.83 / 1.80 / 1.78 %: **+0.22 % of the tick.** The scan was a short loop in GDScript; the native one
pays the crossings (the call, the tank's gets, a slide-collision object per contact) and the GDScript still re-fetches
the wall tick's collision to classify it. Shipped OFF, the seam and its proofs kept (it pays once the observer's caller,
the controller, is native: stage 2).

**Found on the way (not this stream's file, reported):** `test_combat_cover::test_fire_stopped_by_a_wall_still_suppresses_
the_crew_sheltering_behind_it` fails when run ALONE (suppression 0.00; builder0, `ad1dcf26`'s tree with `native_threat`
OFF, and again with `native_shell` OFF) and passes after its file's first test: an order dependence that a FILTER run
exposes; the full suite runs them in file order and passes.

### N7: core components outside the thinking AND outside round 29's contested code -- PROPOSED (2026-10-13; nothing started)

Excluded (round 29 rewrites them): the give-way / `_negotiate`, the k-turn planner and face turns, the element's arrival
watch. Shares of the tick from the N6.3 price runs' OFF arms (builder0 very loaded, foundry 25 a side, stage 1 + N6 ON,
`a1174911`'s tree, 3 runs; shares of `tick_ms`, so they are roughly load-independent; an estimate, confidence medium).
Ranked by how core, then size; all equal-answer (hash-proven) with a switch each, the N6 rules.

| # | component | what moves to C++ | today (share of tick) | days | why core / risk |
|---|---|---|---|---|---|
| 1 | **Projectile flight + impact queries** (`game/combat/shell.gd`, `Match._land_rounds`, `Match.incoming_projectiles` (K2) + `_damage_estimate`) | the shells' flight and hit tests as one pass over the shells, the lobbed rounds' landing, the incoming-fire geometry query every brain asks (pure geometry, no engine queries) | shell 0.11 + shell/hit 0.06 + land_rounds 0.02 + engagement 0.12 %; the incoming query inside `t.incoming` 1.78 + `s.incoming` 1.17 % (part of it; to be split by a lap before porting) | 4-5 | the rules of the fight; completes N6.2 (one implementation for the sim, the replay and the AI's lethality); grows with bigger fights. Risk: shells are Nodes (their physics step stays the engine's) |
| 2 | **The suppression field** (`game/combat/threat_field.gd`: stamp, decay, `at`; `Match._update_suppression`) | the grid's arithmetic and the per-crew settle | match/suppression 0.34 % + the stamps inside fire | 1-2 | a game rule (L2) on a plain grid: deterministic, easy to prove; small |
| 3 | **The tick's scheduling around the brain** (`OrderController._physics_process`'s dispatch: the per-crew entry, the parts bookkeeping, the controllers segment's loop) | one native loop over the crews calling think (GDScript) and execute (native) in today's order | controllers minus think minus execute: ~3 % (of which wall contact 1.47 %, below) | 3-4 | the seam stage 2 will need; touches `order_controller.gd` (brains-adjacent): needs a freeze window. Risk medium |
| 4 | **Wall contact's observer** (`game/ai/wall_contact.gd`, nav's) | the per-tick contact read and its bookkeeping (runs before think, outside the execute seam) | c.wall_contact 1.47 % | 2 | physics bookkeeping, not a decision; ASK nav/manoeuvre first that round 29 leaves it alone |
| 5 | element_feed's per-tick gather (`game/ai/element_feed.gd` normalize) | the context normalising | feed.normalize 2.39 % | 2 | a real cost, but it reads doctrine's shapes and sits beside the arrival watch round 29 rewrites: AFTER round 29 |
| 6 | the match recorder (`game/match/match_recorder.gd`) | the event rows and the census | ~0 (no section: event-driven, one census a second) | 1 | tooling, not the sim; only for the C++-core principle; last |

**Recommended order:** 1, 2, then 3 when a freeze window on `order_controller.gd` exists; 4 on nav's say-so; 5 after
round 29; 6 last. None starts before the orchestrator orders it.

### E6b, the laptop's "where it stands now" (DONE 2026-10-13 12:10 PDT, `b2712987`)

The rule-D design of E6: his laptop, his preset, ABBA paired, n = 6 a size at 20 and 25 a side; A = the shipped defaults
(everything native ON), B = `--brains-off=native` plus every `native_*` switch off. Reports game speed and tick scripts
for each size with the se of the paired difference, and the commit + machine. Run as E6 was (`make native-tick-profile` on
flightdeck, the bar workload foundry + parade, window 8-20 s, 180 s cooldown); B is `--brains-off=native` alone (every
`native_*` switch checks `BrainSwitches.native` first). Evidence to `references/round28/native/e6b-<commit>/`.

**GO and run (2026-10-13):** granted ~10:56 PDT; started 11:45 PDT on flightdeck at `b2712987` (main `3cd5596b` merged;
`native_controller` OFF, so the shipped game), arms `b20@20=--brains-off=native a20@20= b25@25=--brains-off=native a25@25=`.
Checked first: every `usable()` in `game/ai/native/*.gd` and every seam reads `BrainSwitches.native` before its own switch.

**The prediction (written 11:50 PDT, before any number; reasoning in one line):** round 24's laptop table had all native
off at +22 % of the shipped tick's scripts (42.7 v 34.9 ms, 25 a side, `26009842`); since then stage 1 (-7 to -9 %, E6)
and N6/N7 (~-1 to -2 %, builder0) compound, so **A saves 22-32 % of B's tick scripts (central ~27 %) at both sizes**;
A's game speed ~0.93-0.95 at 20 a side and ~0.86-0.88 at 25 (E6's 0.930 / 0.865 plus N6/N7); B's ~0.72-0.80 at 20 and
~0.62-0.70 at 25. **Falsifiers:** a saving under 18 % means the earlier ports' laptop share fell (re-take the split);
over 36 % means B pays something new (find it before telling him).

**The result (flightdeck = his laptop, `b2712987`, his preset, bar workload, 11:48-12:10 PDT, ABBA held in every cell,
n = 6 paired a size, 0 engine errors, load 1.1-2.6, no other Godot; hulls alive at the window's ends the same in both
arms; `references/round28/native/e6b-b2712987/`):**

| | tick's scripts (shipped A v no C++ B) | game speed in the window |
|---|---|---|
| 20 a side | **-20.6 %** (se 0.88): 25.3 v 31.9 ms; foundry -20.6, parade -20.7 | **no C++ 0.854 -> shipped 0.936** (+0.082, se 0.008) |
| 25 a side | **-29.2 %** (se 0.42): 29.7 v 42.0 ms; foundry -28.5, parade -30.0 | **no C++ 0.672 -> shipped 0.878** (+0.206, se 0.004) |

- **Against the prediction:** 25 a side inside everything (saving 22-32 %, A 0.86-0.88, B 0.62-0.70). 20 a side: A's
  0.936 inside 0.93-0.95; the saving -20.6 % just under the 22 % low end (above the 18 % falsifier) and B's 0.854 above
  0.72-0.80: without native the laptop at 20 a side is not yet at the 3-ticks-a-frame cap (2.77), so it loses less
  speed than the saturated model said. No falsifier fired.
- **Priority 0:** unmoved at 20 (-0.01 ms, se 0.04); at 25 -0.19 ms (se 0.03), which is the arm itself, not a void
  session: unlike E6's arm, B turns off ports that live in priority 0 (perception in `match/intel`, the suppression
  field, shells, combat, the tank's drive); `match` 1.13 -> 0.93 ms, `tank` unchanged.
- **Since E6 (same laptop, the shipped arm):** 20 a side E6 0.930 -> E6b 0.936, 25 a side E6 0.865 -> E6b 0.878 (N6/N7's ports; different
  sessions, so read as about +0.01, not a paired number).
- **For him, in player terms:** *"All the C++ together is worth about a fifth of the game's work at 20 a side and nearly
  a third at 25. On your laptop the opening clash runs at 0.94 of real time at 20 a side (0.85 without any of it) and
  0.88 at 25 a side (0.67 without)."*

### The measurement-mode audit (2026-10-13, the orchestrator's order after the N6.3/N6.4 price bug)

**The bug:** `NativePathing.usable()` and `NativePerception.usable()` stepped aside while `OrderController.profile_detail`
was on, to keep the GDScript's per-call laps; the tick profile (every price and the laptop's ruling use it) turns
SimProfile on, which turns `profile_detail` on in every controller. So both N6.4's and N6.3's "~0" prices compared
GDScript with GDScript. Their correctness proofs stand (the tests force the switch; native-proof, the checks and the
verify-suites run with no profile). Fixed: neither gate reads a measurement flag; natively those laps are not taken.

**Every native gate audited** (`usable()` in `game/ai/native/*.gd`, every seam's call site, every switch the C++ reads):
the only conditions besides the switches are behaviour-selecting arms (Armor.deck_probe, SwitchingCost's cost arm and
probe, Movement._off / reverse_log / kturn_log, --nav-off=carrot, the clearance arm, the drive-trace instrument): none of
them is set by the tick profile, --brains-parts, SimProfile, the census or the A/B. The C++'s own profile clocks
(`--native-exec-profile`, `--native-drive-profile`) time, they never route.

| switch (ON as shipped) | where it is taken | live under the tick profile |
|---|---|---|
| native_exec, native_owned | `OrderController.compute_command` (NativeExec) | yes (never gated) |
| native_drive, native_cb, native_fire, native_avoid, native_path | inside the native drive (`drive_native.cpp` reads cb / avoid live; fire and the route tail are its own ports) | yes (never gated) |
| native_tank | `Tank._drive` | yes (the drive-trace instrument only) |
| native_combat | `Match._land_hit_result`, `Tank.take_hit` | yes (deck_probe only) |
| native_dodge, native_cover, native_nav, native_tq, native_el, native_situation, native_decide | their seams | yes (never gated) |
| native_pathing, native_perception | `pathing.gd`, `Match._update_intel` | **no until `5ed9b332`, yes after** |

**(a) E6 is NOT affected:** at `6d9fa7a4` (E6's code) neither `NativeExec.usable` nor `NativeDrive.usable` had a
measurement condition (read from that commit), and the arms differed by -8.6 % / -7.2 % outside 2 se, which they could
not have if the execute had stepped aside. E6's ruling stands.

**The guard:** `make native-live-guard` (~1 min builder0): a fight at 20 a side on foundry under `--native-tick-profile`;
the native paths taken are counted (`NativeBridge.took`, a bool check a call otherwise) from 5 s of match time until the
window opens (not inside it), and `tests/native/live_guard.py` fails naming any switch in force that was never taken.
Switches carried inside another path are checked through it (cb, fire, avoid, path -> the drive). **Falsified:** with
the old `profile_detail` condition put back in `NativePathing.usable()` it FAILS naming native_pathing (a first version
counting from the install let that seam score its one call before profile_detail flipped: hence the 5 s).
Joins CHECK_TARGETS with the merge (the orchestrator, `mk/core.mk`).

**Tools that UNDER-COUNT since `5ed9b332`:** `tests/native/sizing_table.py` and `tests/native/p1_table.py` read the
per-call laps `los.ray`, `nav.path`, `nav.is_ready` as the engine's share of a tick. With native_pathing / native_perception
ON those laps are no longer taken (the native path does not lap per call), so their engine columns MISS the native
path's engine calls: a tick split read from them is not complete. Read the sections (`brain/think`, `match/intel`)
instead, or run them with `--brains-off=native_pathing,native_perception`.

**The corrected prices (builder0 QUIET: tick 14.04-14.18 ms over all nine runs; `5ed9b332`, foundry 25 a side, pinned
0-3, 3 alternated runs an arm, the native counts confirm each arm's path):** all ON 14.06 ms a tick; native_pathing off
14.12 (ON saves 0.06 ms, -0.4 %; think 6.72 both); native_perception off 14.17 (ON saves 0.10 ms, -0.7 %: `match/intel`
0.183 -> 0.088 ms, -52 %). N7.1's lap: the K2 query (`k2.incoming`) 0.098 ms (0.7 % of the tick), half of
`s.incoming` (0.187); `t.incoming` 0.255 ms (1.8 %) is IncomingFire's own per-tick count over the shell columns.

### Round 29: traffic's street hold in the native drive (C29.2 pair; GREEN `59c1cc09`)

**What it is.** Traffic's T1 (`3a94f38d`) puts the hold at the top of `Movement._avoid` and gates six places on
`Traffic.holding` (C29.3). The native drive (`drive_native.cpp`) does the same: at the top of `avoid` (not when `held`) one
call back to `NativeTraffic.avoid_hold(crew, tanks_root)` (= `Traffic.refresh` + `Traffic.hold_of`; the table work stays
traffic's GDScript): at the spot -> face, throttle 0; else the approach clamp((dist - HOLD_REACHED_M) / HOLD_SLOW_M,
0.15, 1) on the avoid it recurses into with `held`. `holding()` is read natively from Traffic's `_live` table (its
`_root`, `_frame`, LIVE_TICKS), cached per drive. The gates: negotiate's early return, unstick, pressing_escape,
track_progress, update_phase's stalled branch, the planned reverse. `NativeTraffic.drive_config()` is `{}` on a tree
without `Traffic.hold_of` (the drive is as before), so stream/native parses and runs with or without traffic's merge.
**Proofs (builder0):** `test_native_traffic_hold` on traffic's own stage (TrafficStage, Terminus head-on, seed 1), every
crew driven both ways each tick from one snapshot of every mover and of Traffic's statics: live members 7461 drives (1975
holding: 621 at the spot, 1354 approaching) + 1490 unsticks (396 holding); the owned state 7304 drives + 1458 unsticks;
**0 mismatches**; the stage held 5 crews. **Traffic's judged case on the native path** (`59c1cc09`, `traffic-series`
terminus/head, seeds 13-15 x ticks 1,3,6,8,11,16, n = 18): crews 177/180, between-squad fast 91, all fast 379, all-in
median 59.3, no wedge, 18 verdicts / 90 holds / 87 released passed / 3 at the cap / 0 no spot: `hold_verdict.py`
against traffic's judged base VERDICT PASS, and **every run equal field for field to traffic's judged GDScript hold arm**
(18/18; only the arm's `brains_off` label differs).
**The scaffold** (`bde8de0a`: NativeHold, `hold_native`, the execute's "holding" hand-back) is **reverted** (`e4cd396f`):
T1's hold lives in the drive, so nothing would ever write that record.
**Next pairs:** T3 (`Traffic.shape` after the hold block: one callback, ORCA on the shaped wish, the early-out on the
route's wish; refresh is keyed on the frame so the second call is a no-op), M4 did not pass its bar (no port).

### Round 29: brains' B5c arrival-gate rule -- PARKED for round 30 (2026-10-14); the work is on `lab/native-b5c`

**What happened.** Brains' flip `ed843d63` turned `Movement._approach_gate`'s rule on by default: give up the gate when
stalled aiming at it, latch a reached gate, offer a gate only where there is a turning circle of navmesh (`_roomy_gate`,
memoised per hull). Native merged it (`4a293e8a`) and mirrored it in C++ (`1fabe6a8`, `e0a80733`). On builder0 at
`e0a80733`: `test_native_gate` 20/0, 0 mismatches (Sumps 6000 drives + 189 forced stalls; default layout 6000 + 555; live
and owned). native-proof on = off = ab = owned = `0398922d31f335f8`. 24/24 yard + Sumps cells on the native path equal
brains' judged on-arm. **But `make check exited 2`** (2581 passed / 1 failed): `test_wheeled_arrival`'s face-the-way-it-came
car arrived at dot 0.50, and it failed the same way with native OFF, so the cause is the flip's GDScript. Brains' fix
`a8df3dc3` (a gate reached facing away is not latched, the give-up waits while turning, new member `_gate_turning_for`)
moved the judged cells on the GDScript path (yard 23 last crew in, e.g. t3 22.1 -> 39.9 s; Sumps 6), so by the
orchestrator's rule **B5c parks for round 30** and the pair comes off the stream.
**Where it is.** `stream/native` was reset (never pushed, never on main) to `028fb334`; its code is again the green
`59c1cc09`'s. `lab/native-b5c` keeps the merge, the mirror, the gate test, the status note, and `b01a8959`, the mirror of
`a8df3dc3`, which was built locally but never run. For round 30: merge brains' final flip and mirror it from the lab branch
(exec_fields `_gate_dropped_for/_why`, `_gate_turning_for`, `_roomy_key/_value`; DriveConfig `gate_giveup`,
`GATE_ROOM_POINTS`; `tests/test_native_gate.gd` + uid). Then run the gate test, native-proof, the 24 cells, and check.

### Questions for the lead

- **Stage 2 (N4):** do it now, or once the AI's decisions settle? (above; the orchestrator asks him)

### Requests to other streams

- None.

### Merge notes

- Round 29: `game/ai/wall_contact.gd` observe's seam (N7.4, `native_wall` OFF); `game/ai/brain_switches.gd` `native_wall`;
  `mk/native.mk` native-proof arm `wall`. New scripts: `game/ai/native/native_{wall,traffic}.gd`,
  `tests/test_native_{wall,traffic_hold}.gd`. `native_drive.gd` merges `NativeTraffic.drive_config()` into the drive's
  configuration. The pair merge carries traffic `3a94f38d` (traffic's files as they are on stream/traffic).
- N6 seam lines in files no stream owns (granted, seams only): `game/tank/tank.gd` (`_drive`, `take_hit`),
  `game/tank/tank_motion.gd` (`step_in_place`), `game/match/match.gd` (`_land_hit_result`); in nav's `game/ai/pathing.gd`
  three seam lines (`is_ready`, `query`, `find_path`, N6.4). Switches in `game/ai/brain_switches.gd`: `native_motion`,
  `native_tank`, `native_combat`, `native_pathing`. New scripts: `game/ai/native/native_{tank,combat,pathing}.gd`.
