# Stream: orders (one click puts his squads together; his click takes at once; the order goes to the squad he meant)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 348, 350, 352), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 47** (C47.1-C47.11; R47.4 is your deciding line; C47.4 and C47.5 are yours), your last brief `streams/archive/round46/orders.md`
> (FINAL REPORT: V1 shipped ON, V4 / Bar V2 and why packing made the group LATER, R46.36), `game_design.md` *His playtest after round
> 46's ships*, *His second match*, *His fourth note*. **You own:** `game/control/**` (incl. `selection_squads.gd`, `group_formation.gd`,
> `rts_controls.gd`) EXCEPT engage's crew branches in `order_executor.gd` and native's C++ seams; GRANT `game/ui/selection_markers.gd`,
> `game/ui/selection_panel.gd`, `game/ui/squad_chip.gd`, `game/ui/group_bar.gd` for the recipient cue (C47.5); the `inp` recording row
> (C47.4); `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`. No planner grant this round
> (route owns it). **Model:** Opus. **Machine:** builder3. **Seeds:** 12701-12748 (Bar O), 12749-12796 (reserve). Dev 7001-7006.

## The lead's direction (2026-10-30, verbatim)

Crossing: "I selected squads 3 and 4, grouped them into a single squad 4, then I picked a single target waypoint. The waypoint planner
or whatever once again counterintuitively picked to points that were far apart."

Locks (third note): "I told everyone to attack a target directly in front of it" (the attack order did not take for ~7 s; the route is
route's item).

Sumps: "I had clearly directed squad 2 of tanks to set up a screen north of the artillery, but they are simply not moving from their
original default formation. CHeck me if I did something wrong here"

He asked for the group click in rounds 37, 41, 43, 44, 45 and 46 (picked "Tighter", R46.2), and **has still not played a fix that
brings the squads together**. Memory: *ship his fix ON*: the closer group reaches his default game THIS round.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **Spread:** Crossing (`references/round46/playtest/2026-10-30T15-41-59-crossing.jsonl`): Spears + Wrenches (selection `["Spears",""]`: the merge is still two
  elements) to one click: (80.9, 49.5) -> (55.7, 22.6) and (95.5, 69.0), **61 m apart**; (96.4, -17.5) -> (65.6, -29.5) and
  (114.6, 1.5), **58 m apart**. Locks (`references/round46/playtest/2026-10-30T15-49-20-locks.jsonl`): (-81.6, 45.7) -> 36 m apart; queued (-94.4, -46.8) -> 44 m.
- **R46.36:** packing the file (`--group-pack=on`, factor 0.5 / 0.75) made the group arrive LATER (all-in 20.8 v 19.3 s; contacts 59.6
  v 41.9). **R47.4:** the deciding line is the spread for ONE click AND all-in sooner-or-same. Ideas to read, not prescriptions: lay
  squads side by side across the click rather than in a file; a merged selection lays as ONE squad; cap the distance from the click.
- **Order lag (Locks):** attack order on Rust_Lances_3 at tick 1461 (Hunters_1/4/5); Hunters_4's census stays on the earlier
  `attack_move` until tick 1680 (~7 s). Find where it was dropped or queued (the executor, the element, a busy flag). His direct order
  wins at once (memory). The crew branch is engage's code: trace it, ask engage through the orchestrator if the fix is there.
- **Wrong squad (Sumps, `references/round46/playtest/2026-10-30T15-53-39-sumps.jsonl`):** Bravo selected at frame 601, **Charlie (artillery) at 618 (~0.3 s later)**,
  the screen click at 763 went to Charlie; Bravo has no order or task row all match. No key rows, so the cause is unknown.

## Backlog (in order)

1. **O1 the group click's spread, ON, smallest change (R47.4, C47.2):** Status first with a dev read of the candidates on his three
   clicks; then the change, `=off` escape; every other click byte-identical where possible. Symmetric (C47.9). Tests first: his
   Crossing and Locks clicks (unit), the Gorge veto cases unchanged, a Terminus street click.
2. **O2 Bar O**, filed BEFORE any number on 12701-12748: deciding = spread between squads' spots for one click, all-in sooner or same;
   guards = the V1 veto's lines, contacts, wedged crew-s, never-arrived, the street lines. Native twin if a seam moves (C47.6). Ships ON.
3. **O3 the order lag:** trace Hunters_4 1461-1710 (Status first); fix so his attack/move order replaces the running one the tick he
   gives it. Test first.
4. **O4 the `inp` row (C47.4):** every input that changes the selection or issues an order; native's `playtest_report` reads it (tell
   the orchestrator the hour it lands). Then re-read Sumps 601-618 for what COULD have changed the selection without a key (a hotkey
   repeat, a click on a chip, a double-tap select-all, the panel) and fix any UI fault found.
5. **O5 the recipient cue (C47.5):** at the moment of an order, the receiving squad's marker / chip pulses; screenshots at desktop and
   phone aspect, looked at.
6. **O6 a screen order to artillery:** artillery told to "screen" should not march its mortars to the front line (a screen for
   artillery = hold behind the line it covers, or the order fits the unit). Proposal in Status with what he'd see; build ON if small.
7. **O7 his acceptance read:** his three clicks replayed on the shipped tree (spread, all-in), Hunters_4's order take time.

## Don't touch

`game/ai/planner/**` and `pathing.gd` (route), movement / traffic (manoeuvre), engage's crew branches (ask), `native/**`,
`game/camera/**`, the rest of `game/ui/**`, `arenas/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
