# Stream: orders (his all-squads click: every squad the same way, a column of wedges at his click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 44** (C44.1-C44.5,
> CP44.0). Your last brief: `streams/archive/round41/orders.md` (G1 v9's bar and Status); R41.15 and *Bars (round 41)* Bar G1 v9 in
> `workstreams.md`; *Round 37: his playtest note on a group click* in `game_design.md`. **You own:** `game/control/**` (incl.
> `selection_squads.gd`, `group_formation.gd`, `rts_controls.gd`), `tests/test_control*.gd`, `tests/control/**`,
> `tests/orders_probe*.gd`, `mk/command.mk`; GRANT (C44.2) a `click` / `group` key on the `order` row of
> `game/match/match_recorder.gd`; GRANT (CP44.0) the `"group"` entry in `ElementTask.KEYS`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only. **Model:** Fable. **Machine:** builder0 light lane (J<=4); builder2 for a bar series.
> **Seeds:** 10801-10848 (bar), 10849-10896 (reserve).

## The lead's direction (2026-10-28, verbatim; the full note in `game_design.md` *His playtest after round 43*)

"I selected all of my squad and told all of them to move to the west side of the map. I had reported this issue long ago: the
waypoints selected for the respective squads were all over the place, leading to all squads moving in all different directions. We had
already talked about this at lenth in the path where I was trying to ask for the squads to pack it in or something (i.e. one squad behind
another or something so that they can all share roughly the same destination)"

Round 37, what he asked for: "stacks of wedges, one squad immediately behind the other", "the squad furthest away to land in the back
and the closest squad to land in the front". **This is the round's lead item and it has come back after a bar passed (G1 v9, R41.15):
the bar measured something other than his case. Find out what, on his recording, before anything else.** The bar for this stream is
"units must look smart" (memory): he must see one army going one way.

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- **His case** (`references/round43/playtest/2026-10-28T08-21-31-locks.jsonl`, Locks, seed 56416, Gangs v Condemned, laptop, native ON,
  cap 4): at tick 1512 (50 s) all four squads stood along the north edge side by side: Hunters (-15, 92), Spears (14, 91), Wrenches
  (44, 93), Guns_4 alone (-8, 78). One click west became Guns_4 (-50, 15), Hunters (-46, 70), Spears (8, 58), Wrenches (-25, 117): four
  destinations ~100 m apart north to south, the Wrenches sent back to the north edge, the Spears barely west of where they stood. Again
  at tick 1808: (-60, 20) / (-66, 58) / (-1, 66) / (-72, 110). **The recording has each squad's `to` but not his click point.**
- G1 v9 ON (`--group-g1`, `--group-column-toward=stay`: the column stands; a squad it would send > 10 m away keeps the spot it stands
  on). Code: `selection_squads.gd`, `group_formation.gd`, `rts_controls.gd` `_order_squads`; tests `test_control_column_toward.gd`;
  probe `tests/orders_probe_group.gd` (locks / crossing / terminus x 5 squads x click). The G1 v9 probe's squads start clumped;
  his started side by side in a line 60 m wide, perpendicular to the click. That geometry may never have been in the corpus.
- Unchecked suspicions (yours to confirm or kill, by removal): the column's axis taken from the army's spread rather than the click
  direction; `fit_to_corridor` / the corridor re-lay spreading the column across Locks' streets; `column-toward=stay` keeping squads
  on their own spots because the column's seats are > 10 m from them (four squads, all "far"); a per-squad anchor picked per
  street (planner route spread).
- `make replay-match` / `tests/replay_orders.gd` re-issue his recorded orders (native's; faithful on his round-42 match, R43.9). Run
  it on the 08-21 recording to reproduce tick 1512 headless.

## Backlog (in order)

1. **O0 CP44.0 the `group` marker (first commit, output-identical).** Land e883fc4eb's two lines in `rts_controls.gd` and the KEYS
   entry (`git diff $(git merge-base wip/manoeuvre-scope-g1 main) wip/manoeuvre-scope-g1 -- game/control game/tactics/element_task.gd`)
   with a test that the key reaches the element's task and survives a re-lay; G1 v9 probe byte-identical v main. Message the
   orchestrator the green hash; it merges alone.
2. **O1 record the click (C44.2), merged alone.** `order` row: `click:[x,z]` (the ground point under his cursor before any layout) and
   `group:<n>`. Recorder test; old recordings still read. Green hash to the orchestrator the minute it passes, so his next playtest
   carries it.
3. **O2 his case reproduced and explained.** Replay 08-21 to tick 1512 (and 1808); infer his click point from the four `to`s and the
   layout code, or bracket it. Then a table: per squad, its start, the seat G1 v9 computed, the `to` it got, which step moved it there.
   Remove candidates one at a time until the scatter goes (C43.3's rule: cause before rule). Write the cause up in your Status before
   building anything; message the orchestrator.
4. **O3 the corpus grows his geometry.** Add starts the probe never had: squads side by side in a line perpendicular to the click,
   squads strung along the click direction, one squad detached (his Guns_4), on Locks / Crossing / Terminus and his own seed. Read
   main's G1 v9 on them: how often is a squad sent backwards, how far apart are the destinations, does the closest land in front.
5. **O4 the fix, behind a switch, then Bar G1 v10.** Every squad's destination within one column at his click, ordered by distance
   (closest in front), no squad's goal behind its start along the click direction, the column through the corridor his click is in.
   File the bar in `workstreams.md` *Bars (round 44)* BEFORE any number on 10801-10848: deciding lines on his geometry (spread of
   destinations, squads sent backward, time to the last squad in), guards: G1 v9's own probe lines, manoeuvre's one-squad arrival
   (C44.3), fights (deaths, friendly contacts), the corridor. Symmetric: the CPU's group orders take it (C44.5). Ships ON when it passes.
6. **O5 his case, the acceptance read:** the fixed build on his 08-21 replay at ticks 1512 and 1808; screenshots from above
   (`make control-playtest-shots` style, or a replay frame) of the four squads' seats before/after. Look at them.
7. **Stretch:** the feel question G1 v9 left open (a click right beside his army: squads already in that street hold, only the near ones
   move); the departure order (closest leaves first) if O2 shows crews crossing at the start.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make control-playtest`,
`make two-squads-playtest`; the G1 probe (`tests/orders_probe_group.gd`) via `mk/command.mk`; `make replay-match RECORDING=...`;
screenshots of the column from above, at his click, looked at. Every number with its commit and machine.

## Don't touch

Movement / traffic / the formation's spacing, seat bound, latch, converge (manoeuvre); the planner beyond the grant; `native/**`;
`game/camera/**`; `game/match/**` beyond C44.2; `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If O2 shows two reasonable readings of "pack it in", write both in player terms (what he would see) with one
recommendation in your Status; keep building the recommended one.

## Status

_(worker keeps this current)_
