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
