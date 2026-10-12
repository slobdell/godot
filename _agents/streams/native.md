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

E6 (the laptop's ruling) needs a laptop slot; he plays the result.

## Status

_Started 2026-10-11 18:25 PDT from `c37605f0` (main's green check `090b345d` covers it: no baseline re-run). Heavy runs on
builder0; the laptop only in a granted slot (C27.6)._

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

- **E3 / E4 / E5 written, in test** (uncommitted until their proofs run): `gun_native.cpp` (Gunnery.apply line by line
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

### Questions for the lead

- None.

### Requests to other streams

- None.

### Merge notes

- None yet.
