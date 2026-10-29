# Stream: engage (his order to a crew wins: a lone scout he holds, stops or moves does exactly that until he gives another)

> Read `_agents/orchestration.md` (the worker contract; lesson 339), `_agents/judging.md`, `_agents/workstreams.md` **Round 45**
> (C45.1-C45.5). Your last brief: `streams/archive/round43/engage.md` (Status: the replay probe, trace rows, A7). `game_design.md` *His
> playtest after round 44*; the 2026-09-17 authority note quoted in `game/tactics/element.gd` (~line 1903). **You own:**
> `game/tactics/drills.gd`, `game/tactics/element.gd`'s player-authority code (`_detached`, the take-back, the `source == "player"` skip,
> `preempting`), `game/tactics/element_plan.gd`'s engagement functions (`_engage`, `_hold`'s in-range tests, the contact drill's moves;
> NOT settle, `grouped()` or converge), `game/tactics/element_situation.gd` (additive), `game/tactics/firing_position.gd`, GRANT
> `game/control/order_executor.gd`'s `stop` / `hold` / `move` / `attack_move` branches for a crew's own order, `game/ai/order_controller.gd`
> (trace lines; behaviour on the orchestrator's ruling), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `tests/test_authority*.gd`,
> `mk/engage.mk`. **Model:** Opus. **Machine:** builder0 light lane (J<=4); builder2 for a series over 24 fights.
> **Seeds:** 11301-11348 (bar), 11349-11396 (reserve).

## The lead's direction (2026-10-29, verbatim)

"Then during gameplay, especially toward the end, I had a single scout I was trying to control (to not get it killed), and it routinely
kept going off and doing its own thing. I was trying to keep it out of combat, but it drew itself into an engagement I was explicitly
trying to avoid."

Standing (2026-09-17): *"if they get sucked into combat I have no control whatsoever"*. Memory: his direct order to a unit wins.

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **His case** (`references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`; `make replay-match RECORDING=<that file>` is faithful
  20/20 for 30 s: extend `REPLAY_SECONDS` to 107 and say whether the scout's late game still reproduces). Green_Hunters_5 (gang_scout)
  is the last of its squad from 69 s; killed 105.3 s by Rust_Guns_2. From 83.7 s he gave it 9 moves, 3 stops and a hold in 20 s:
  - **HOLD at 99.2 s overridden within 1 s:** the element's task became `hold` "contact: return fire, take cover, report" (tick 2978,
    `drills.gd:168`), and the census shows `move` (src element) at 100 s then `attack_move` (src element) at 101 s, driving from
    (-45, 47) to (-47, 33) INTO the gap toward the enemy.
  - **After his STOP at 95.8 s** it was still driving at 97 s (z 55.5 -> 47, toward the enemy).
  - **His last move (102.6 s) to (-47.1, 31.1):** at 103 s it is at (-59, 8), 25 m past his click; blocked; dead 2 s later.
  - Short moves 1-11 m "never arrived" (83.7, 85.2, 87.0, 91.8 s).
  - The one-crew squad's formation read `swarm` / `coil`; whether its slot sits off his click is NOT measured.
- `element.gd` detaches a crew the player orders "until that order is finished, then quietly takes it back" (header ~line 20,
  `_detached` ~1440-1520). Unchecked suspicion: a hold or stop "finishes" at once, the element takes the crew back, and the contact
  drill re-orders it. Prove or kill by removal.

## Backlog (in order)

1. **E1 which layer moved the scout, by removal.** On his replay (and a scripted dev scene: one crew left in a squad, enemy 60 m off,
   he holds / stops / moves it), remove one layer at a time (the element's take-back, the contact drill, the one-crew formation slot,
   the drive's arrival) until his hold holds, his stop stops and his move lands within 3 m. A table in Status: per order of his, what
   issued the next row and why. Cause before rule (C43.3); message the orchestrator.
2. **E2 the authority rule, ON by default, `--player-authority=off` the escape (C45.2: the smallest change that removes what he saw).**
   A crew carrying his direct order (stop, hold, move, attack-move to a point) stays detached from its element until HE gives it or
   its squad another order; its element never re-tasks it, its squad's drill never moves it; it still turns and fires from where it
   stands under hold / stop (a held crew is not a dead crew). A squad task he gives later takes it back (R2, newest word wins). His
   move ends at his click (within the arrival radius), not past it. Tests first, from E1's cause.
3. **E3 Bar E1**, filed in `workstreams.md` *Bars (round 45)* BEFORE any number on 11301-11348, NARROW: deciding lines on an
   authority probe (crews of every kind, alone and in a squad, ordered hold / stop / move near contact: metres moved under hold /
   stop <= 2, element-sourced rows while his order stands = 0, move ends within the arrival radius); guards: fights (his kills /
   losses, the CPU's, within base +/- 1.645 se; does a held crew still shoot back), a squad order after a crew order takes the crew
   back (100 %), orders' G1 probe and manoeuvre's one-squad arrival unchanged (C45.3). The CPU has no player orders: say so (C45.5).
   Ships ON the minute it passes; message the orchestrator the green hash.
4. **E4 his acceptance read:** the shipped tree on his Gorge replay from 83.7 s; per order of his, what the scout did; shots looked at.
5. **Stretch:** the short moves 1-11 m that never arrived (whose arrival radius swallowed them); a one-crew squad's formation slot
   (does `swarm` / `coil` place a lone crew off the click).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make replay-match RECORDING=... REPLAY_SECONDS=107`; `mk/engage.mk`
targets; a scripted scene with screenshots of the held scout under fire, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` beyond the grant (orders), movement / traffic / formation / `grouped()` / converge (manoeuvre), `native/**` (ask
native for twins), the planner (trace lines only), `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If E1 shows two reasonable readings of "keep it out of combat" (e.g. a held crew retreats from fire v stands),
write both in player terms with one recommendation in Status and build the recommended one (stands and fires: what he ordered).

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (2026-10-29, in progress)

**Plan (order):** E1 cause by removal-trace (DONE) -> E2 rule behind `--player-authority` ON, tests first -> E3 Bar E1 filed before
numbers -> E4 his replay read -> stretch (short moves, the one-crew slot).

**E1 DONE: which layer moved the scout.** Workload: his Gorge replay, `make replay-match ... REPLAY_SECONDS=107 CREWS=all` =
**faithful, builder0 8d59b2bdf, 20/20 crews within 3 m every second for all 107 s** (`DIVERGENCE ... verdict=PASS`; ignore its
`REPLAY_NATIVE_MISMATCH replay=false` line, the 0.0 m table is his match). Probe: `make engage-authority-trace` (new,
`tests/engage/authority_trace.gd`: per tick, the crew's K1 order + source, its element's task / drill / detached, the brain's option,
the mover's goal). Rows from builder0 8d59b2bdf, n = 1 replay (deterministic):

| His order (tick, s) | How it reached the crew | What issued the next rows, and why | What he saw |
|---|---|---|---|
| moves 2510-2838 (83.7-94.6 s) | squad TASK (a one-crew squad selected = whole squad, `rts_controls._is_task`), `drills: false` | element move; goal = the swarm / coil slot, **~5 m off his click** (2700: (-55.8, 78.1) v click (-55.9, 73.1); 2754: (-47.1, 68.9) v (-50.4, 72.7)); after arrival the order completes and the idle brain's ENGAGE drifts it ~5 m | short moves "never arrived": a 15 m/s scout reversing + the slot offset (stretch) |
| STOP 2873 (95.8 s) | DIRECT, source player (element disbanded) | TankBrain latches the stop's goal where the crew was when the order was READ (-42.6, 58.0); at 15 m/s it coasts ~7 m past, then the MOVE option drives loops trying to get back to that point: (-43.3, 47.0) at 2910, 11 m off, still `driving` | "after his STOP it was still driving" |
| STOP 2923 (97.4 s) | DIRECT | stop completes at 2926 -> order empty -> **idle brain picks ENGAGE** (post (-45.2, 47.0) is only a leash): 6 m toward the enemy by 2977 with NO order | the crew creeping on its own |
| HOLD 2977 (99.2 s) | squad TASK (element re-formed, task `hold`, drills on) | `Drills.select` -> **react_to_contact** ("return fire, take cover, report") -> `ElementPlan._engage`: `attack_move` 15 m toward the contact (out of reach) alternating with `move` to a firing spot, re-issued every update: **z 41.2 -> 12.0 by 3078, 30 m into the gap** | "drew itself into an engagement I was explicitly trying to avoid" |
| move 3078 (102.6 s) | squad task, drills false | element move to EXACTLY his click (-47.1, 31.1); the crew was already at (-59.8, 12.0), **22 m past it, carried there by the hold drill**; then blocked on terrain coming back | "ended 25 m past his click" |

Ruled out: the element take-back (`_adopt`) never acted (a direct order removes the crew from its element / disbands a one-crew
element); the drive's arrival (the last move's goal was his click); ElementCommander's rejoin (CPU only). The suspicion in the brief
("a hold finishes at once and the element takes it back") is killed: hold never completes; it was the task path's drill.

**Decision (two readings of "keep it out of combat"):** a held crew under fire either stands and fires or backs out of reach. Built:
**stands and fires** (what he ordered; the brief's recommendation). A crew he wants out of combat he moves out; it then stays there.

**Requests / messages:** orchestrator messaged 2026-10-29 with the cause and a GRANT REQUEST: E2's stop and post rules live in
`game/ai/tank_brain.gd` (+ an additive `player` key in `game/ai/order_feed.gd` normalize), because `order_executor.gd` (my grant) is
inert since TankBrain declares EXECUTES_ORDERS. Proceeding on the most reversible reading (switched, minimal, reuses the `hold` verb so
the C++ decide twin needs no new verb). Relay asked: orders (a squad of one goes down the task path), manoeuvre (the drive's arrival
is NOT the cause; the one-crew slot ~5 m off the click is a formation question).

**GRANTED (R45.2, orchestrator, main 6064df074):** `game/ai/tank_brain.gd` for the `--player-authority` switch only + the
additive keys in `game/ai/order_feed.gd` normalize. C45.4: native-on v native-off EQUAL on the authority probe before freezing.

**E2 (built, `--player-authority=on|off`, ON by default; `Drills.PLAYER_AUTHORITY`):**
- (a) `drills.gd`: his hold task runs no drill; `element_plan.gd` `_hold_in_place`: under his hold every crew holds its own spot
  facing the nearest contact (the halt re-seated a lone crew 5 m forward and a squad's crews up to 30 m).
- (b) `element.gd` `_his_lone_order` (C45.3): his move / hold task to a squad of ONE goes to the crew as his order (`source: player`,
  his exact click), and the crew stays detached (`HIS`) until his next task (`_retake`). Shift-queued tasks keep the element path.
- (c) `tank_brain.gd`: his stop brakes where the crew comes to rest (no drive back to where it was read); a hold he gave no point
  holds where the crew comes to REST (Orders fills the goal with the spot at issue, behind a 15 m/s scout); when his stop / move
  is done the crew holds where it finished (verb `hold`, the existing option: native decide needs no new verb) until its next order.
- `order_feed.gd` normalize: `player` (source == player) and `here` (a hold / stop with no point).
- The CPU: every rule reads `player` / the player's team; the CPU gives no player orders (C45.5). Proof: sim-baseline (CPU v CPU) in
  `make check` unmoved.

### Bar E1 (FILED 2026-10-29 ~11:40 PDT, before any number on 11301-11348)

**Workload:** `make engage-authority-bar AUTH_SEEDS="11301 ... 11348"` (`tests/engage/authority_probe.gd`, table
`tests/engage/authority_table.py --pair`): per seed a drawn arena (gorge / locks / terminus / crossing by seed), crew hull (8 kinds),
enemy gun (4 kinds), a lone crew (squad of one) or a squad of three, driving at a gun that shoots back from just outside the crew's
range; 2.5 s in, ONE order of his (hold / stop / move, by the RtsControls path: task for a squad of one's hold and move, direct
otherwise), standing 15 s; then his squad task (take-back). Arms OFF = `--player-authority=off`, ON = default, paired by seed, one
frozen tree (named when frozen), builder0 light lane, native ON. **His case** = runs where the crew is ordered alone (a squad of one,
or one crew of a squad given a direct order).

**Deciding (ON arm, his case):**
- D1 hold / stop: every rested run's farthest distance from where the crew first came to rest <= **3.0 m** (HOLD_TOLERANCE, the
  hold's own slack before it drives back; the brief's 2 m is under that existing slack, which this rule does not change).
- D2 element rows that send his crew somewhere else (attack, attack_move, or a move whose goal is over 3 m from the crew / from his
  click for his move) while his order stands: **0** in total.
- D3 his move: every run not dead and not ending `blocked` ends within the crew's own arrival radius
  (max(ORDER_ARRIVE 3.5, settle radius)) of his click; blocked ends are listed (the drive: manoeuvre's).

**Guards:**
- G1 fights: crew deaths ON <= OFF + max(1, 1.645 sqrt(OFF)); enemy hp left mean ON within OFF +/- 1.645 se of the paired
  difference (does his crew still hurt the gun).
- G2 a held crew shoots back: over held runs in range at the order, shots mean ON >= OFF - 1.645 se (if none is in range, UNREAD and
  said).
- G3 take-back: his squad task after his crew order reaches the crew within 1 s: **100 %** of living runs ON.
- G4 a squad's hold sends no crew at the enemy: squad pushed rows ON = 0.
- G5 C45.4: the ON arm native-on v `--brains-off=native` EQUAL on every seed (every probe field but the native flag).
- G6 C45.3: orders' multi-squad probe (`make orders-probe`, main v `pa_off:--player-authority=off`, ORDERS_PROBE_SEEDS 11301) rows
  identical (squad orders are element-sourced: the rule should not touch them); manoeuvre's player plain move (`make
  manoeuvre-behind`, both arms): arrival rows identical (post-arrival hold is after its measure).
- G7 `make check` GREEN on the frozen tree (sim-baseline unmoved = the CPU untouched, C45.5).

**What it could BREAK (named before the numbers):** a crew he left holding no longer drifts into a fight to help (G1, G2); a
squad of one's move now ignores the squad's formation (one crew, no formation to keep); a crew he stopped then forgot stands until
told (that is the rule, said to him in player terms).
