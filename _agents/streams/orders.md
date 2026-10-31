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

### NOW (2026-10-30 22:51 PDT, Opus, `godot-orders` / `stream/orders`; Bar O2 run on 4536ccb0f; main ba23e011e merged)

| Item | State |
|---|---|
| O1 the spread | **Bar O2 FAILED on two guards (G2 wedged, G6 contact_s), every deciding line passes; ruling asked** (below). O1 stays OFF (`--group-merged=on` / `=all` opt in) until he rules |
| O2 Bar O | Bar O failed (D1, below); **Bar O2** filed 4536ccb0f (R47.21 / R47.37) before any number, run on 4536ccb0f, verdict below |
| O3 the order lag | **closed: no lag** (below; relayed to route as R1 by the orchestrator) |
| O4 the `inp` row | **done** (7d41d5061, 3046343c1, 87eb68b1c); hashes sent to native via the orchestrator |
| O5 the recipient cue | **done** ON: rings pulse + chip flash; shots 778c7d397 (builder3 :1, desktop + phone) |
| O6 artillery screen | **done** ON: a battery's screen = support by fire, `--battery-screen=off` |
| O7 his acceptance read | waits on the O1 ruling (reads the shipped tree) |

Green hashes: 0b1caafa2 (3536/0), d9151bad5 (merged as 09780edb9), 1c2fc5838 (3555/0, 29 ALL JUDGED; merged as 79cea77e5).
4536ccb0f (the freeze): check 3554/1, the one red = test_match_shell_dropped_peer, re-run alone 1/0 on 4536ccb0f (R36.12,
the orchestrator's ruling: launch without a re-check).

**Bar O2 (builder3, tree 4536ccb0f, 10 jobs; merged / all 12749-12760, his clicks 12761-12772, identity 12773-12778; every part
complete first try: 240 / 24 / 24 / 144 / 240 / 24 runs; G7 test_manoeuvre_noprogress 2/0; ~/orders-r47/bar-o2-4536ccb0f/):
VERDICT FAIL, both arms.** Merged arm: D1 paired ON-OFF -14.2 m (median 35.1 v 52.4 m, n 120) PASS; D1c 0 wider PASS; D1b 51
of 51 laid within 20/40 m PASS (laid on 51 of 120); D2 +0.44 s PASS; D2b 0 v 0 PASS; G1 contacts 46.8 v 33.3 (cap 88.3) PASS;
G3 0 v 0, decks 1 v 1 PASS; G4 0 of 180 places differ PASS; G5 farthest spot 21.2 v 36.9 m PASS; G6 noprog_s +3.07 se 1.96 PASS;
**G2 wedged crew-s 57.2 v 39.0 (cap 53.8) FAIL; G6 contact_s +0.50 se 0.25 (cap +0.41) FAIL.** His Crossing click 14.0 v 39.4 m
apart, all in 13.8 v 16.1 s; his Locks click unchanged (39.4 v 39.4: the ground refuses the files). The `all` arm reads the same
and fails the same two. **Where the wedging is:** only the 51 clicks laid as files (12.5 -> 55.5 crew-s a run); the 69 not laid
are identical to OFF. By map, ON-OFF a click: sumps +61 / +82 (2 / 3 squads), yard_open +22 / +18, locks / crossing / terminus
~0. **In his terms (sent 22:50):** "two or three squads sent to one spot now park side by side in short lines ~15 m closer
(your Crossing click: 14 m apart instead of 39), just as fast; on Sumps and the open yard the back tanks in each line sit
stuck behind the one in front a few seconds each before they settle; Locks, Crossing and Terminus look the same." My
recommendation: ship ON with the =off escape (second failed bar on his repeated ask; deciding lines all pass; the cost is
two maps), else keep OFF and take the Sumps / yard stall as a follow-up.

**O1 v3 (files only at the end, R47.21: element_plan's MERGED_ARRIVE_FILE) dev reads** (builder3, dev 7001-7002, laid cells):
contacts all / near 60 m / after in / on the way ON 286 / 178 / 99 / 9 v OFF 152 / 123 / 21 / 8: the bumping is at the halt.
Wider gap (`--group-merged-gap`, fd0a69c05): 1x 31.8 v 16.9, 1.5x 29.3 v 6.1, 2x 34.5 v 18.4 contacts: no help, left at 1x.

**Bar O, first series (builder3, 0b1caafa2's code, seeds 12701-12712, ~/orders-r47/bar-o-0b1caafa2/; stopped after merged, his_x
and his_l):** VERDICT FAIL. D1 median spread ON 71.3 v OFF 71.3 m (n 60 three-squad pairs); D1b files laid on 12 of 60, all
yard_open (28 m); D2 -0.83 s PASS; D2b, G1 (35.5 v 34.2), G2 (42.0 v 36.4), G3 (0 v 0), G5 PASS. **Instrument fault (mine; lesson
350):** no 2-squad probe army existed (`tests/control/orders_probe_2.json`), so every 2-squad cell (his case) errored, and the part
check counted the error lines as runs. Fixed: the army is added; a Bar O2 runner must count only rows with `map`.
**O1 v2 dev read** (builder3, 0b1caafa2 + the step-back (the double file steps back 4 m at a time up to 40 m to dry, standable
seats) + the 2-squad army; dev seeds 7001-7002, 5 maps x 2 / 3 squads, n 1 a cell, ~/orders-r47/dev-v2/): laid on 7 of 20 cells;
there 2 squads 14 v 33-41 m, 3 squads 28 v 54-73 m, all-in mostly sooner (yard 6.8 v 9.5 s, locks 4.3 v 28.0 s), but **friendly
contacts 5-20x** (yard 42 v 6, sumps 60 v 22 / 58 v 5 / 122 v 6): two columns a pitch apart accordion and brush the whole way.
Crossing and terminus: still refused (rear seats in buildings or off the arena). **In his terms:** "your merged squads end up side
by side at your click, usually sooner, but rub hulls all the way in; at bridges and in streets nothing changes yet." Not worth a
series. Options sent to the orchestrator (recommended first): (a) today's abreast lay pulled in by halt clearance instead of GAP_M
(each squad's own halt; Crossing ~61 -> ~45 m, Locks ~36 -> ~30 m); (b) the files only for the last stretch (element_plan's
ARRIVE_FILE, D3b: not my code); (c) the bumping to him as a feel question.

**Laptop windowed runs (C47.1, the lead watches the screen):** only when a read needs one; each is named here while it runs.
None running at 19:50 PDT. Done today: four perf-play arms (his Crossing, ~3 min each, 19:16-19:21 and 19:41-19:47).

**R47.22 (the money cap, his pick R47.26: ON everywhere).** 99ffb918a + 2a1e36a22: a faction skirmish is fought with the garage's
2000 CR (3,500 pts) a side, every vehicle bought fielded on every preset (the roll's and fielded()'s count trims are
`--army-cap=count` only, which is round 46's army whole: 5,200 pts + the 20 trim); the recorder's rules stamp gains `army_money`
and tests/replay/rules.py replays an older recording with `--army-cap=count`. **His laptop (UHD 620, lock, his Crossing seed
101, laptop preset, AB + BA, n 2 an arm):** count cap (gangs 20 / 2,490 pts v syndicate 17 / 5,000) 52-57 ms a frame (~18 fps),
game speed 0.95-0.97; money cap (gangs 27 / 3,435 v 12 / 3,430) 86-123 ms (~8-12 fps), speed 0.79-0.93. **Where it goes** (R47.31):
headless HUD (HudClock, ABAB, n 2) 3.24-3.36 v 2.90-2.94 ms, my controls' widgets flat (+0.06-0.09 ms each); perf-play's layers
(windowed, n 1): the fog-of-war field (game/match/visibility_field.gd) costs 10.6 ms of frame / 3.0 ms of UI at the money cap
v 3.4 / 0.8 at the count cap, the controls nothing measurable. The field went to native (R47.31). Caveat: the arms fight different
battles (37 v 25-34 alive).

**O1 (R47.4) what and why.** Both of his far-apart clicks were a control group he had MERGED: Crossing group 4 = Spears + Wrenches,
Locks group 2 = Burners + Burners2, 10 vehicles each. A squad holds 5, so the selection is two squads, and `row` laid them ABREAST
across his approach, each its halt footprint wide plus GAP_M 14 apart (Crossing: two gang coils, 44 m wide; Locks: two
herringbones, 25 m). Two non-overlapping halts of five cannot stand much nearer than one halt's width, so a tighter gap or file
cannot reach "together" (R46.36 showed packing makes them later). **The change:** his merged group (the selection is exactly one
group of > 5 living, 2-3 squads, plain move / attack-move, no drawn facing, not a shifted leg) halts as FILES side by side across
his click, one pitch apart, heads on the click line, crews behind toward where they came from (a double file of ten); the task
carries `halt_at` / `halt_shape: column` / `lay` (round 35's D3 plumbing: no new element code). Any wet / deck / unstandable seat
or a head the veto refuses keeps today's places. And `split`: a group partly taken by a smaller one in the selection keeps its
remainder as a squad (Crossing's Wrenches were ordered LOOSE, `source: player`, no squad, because group 4 also held group 3).
**Dev read** (builder3, ff65a5481's tree, `tests/test_control_his_spread_clicks.gd`, his tick-0 starts, n 1 each; OFF reproduces
his recording to < 3 m): Crossing spread **61.2 -> 18.0 m**, Locks **35.9 -> 14.0 m**; the same two squads NOT merged lay
identically ON and OFF; his Gorge veto tests unchanged (19/19 in the filtered run).

**O3 closed (Locks recording, no Godot run):** his attack click on Lances_3 at tick 1461 reached Hunters' element at tick 1462 (its
task row). The census reads `attack_move` until ~1707 because an element of several crews runs every attack as attack_move crew
orders; at 1707 Hunters_4 was alone and took his order as a lone crew (`Element._his_lone_order`). The drive north and the 230 m
detour are the element's route to the target, already north under his earlier attack on Lances_4 (task tick 883): route's R1.

**O4 the inp row (C47.4):** `RtsControls.input_recorded` -> `MatchRecorder` writes `{"t":"inp","f","k","act","sel_before",
"sel_after"}` for every key press / mouse button that changed the selection or gave an order, after the sel / order rows it caused,
same frame. `act`: recall_group:N, chip:N, edge_marker:N, portrait:<unit>, command_card:<id>, group_save:N, next_group:N,
next_idle:N, jump_to_alert:<text>, select_army, select_idle, click_select:<unit>, box_select, escape, order:<verb>, or "?".
**Sumps 601-618 re-read (what COULD switch Bravo to Charlie with no key row):** the 3 key, the group bar's chip 3, Tab (next group
after 2), an edge marker for group 3, F2 (next idle element), Q (jump to an alert). The likeliest is his own hand: his screen key
**E sits directly under 3** on a QWERTY keyboard; "2, then reaching for E" lands on 3 first. No UI fault found in the chip,
marker or panel paths (each acts on its own click only). The next recording will say which; O5 makes it visible as it happens.

**O5 the recipient cue (C47.5):** the moment he gives an order, each vehicle that receives it wears a white ring that grows out of
its own ring and fades, twice (0.45 s each, real time, so it plays while paused); its group-bar chip flashes white with it. Only
the receivers; nothing else new on screen; the ring layer is empty between orders (no draw call).

**O6 (proposal = what is built):** a SCREEN order to a squad that is all artillery is taken as SUPPORT BY FIRE on the same point:
in his terms, "tell the mortars to screen a line and they stay back where they can shell it, instead of driving onto it". Tank,
IFV and mixed squads screen as before. ON, `--battery-screen=off`.

**Merge notes (shared files):** `tests/replay/rules.py` (native's): my 2a1e36a22 adds `RULES["army_money"] = ("army-cap",
"count")`. When native's 46c3b2f3b lands on main (RULES entries become (switch, off value, shipped stamp)), my merge of main
writes it as `("army-cap", "count", "<R47.22's merge stamp>")`; test_rules: ALL_OFF gains "--army-cap=count" and
test_his_round46_recordings_ran_every_rule_on expects ["--army-cap=count"]. `game/match/match_recorder.gd`: the inp row and
the army_money stamp (additive). `game/tactics/element_plan.gd`: one condition at the D3b hook (R47.21, manoeuvre agreed).

**The control playtest's stale check (fixed, R47 orchestrator's ask):** `queued_route_has_three_stops` read the crew-order queue
and `waypoints()`, but a squad's shift-clicks queue its ELEMENT's tasks (round 35's D6, REQUEUE), so it failed on main too:
`make control-playtest` (headless) on main 6ef3681f7, builder3 light folder: `CONTROL_PLAYTEST_DONE ok=false`,
queued_route_has_three_stops false (not in make check, so nothing went red). Now a squad's route is its element's task + queued
tasks (loose crews keep the old read); stream/orders: `ok=true`, exit 0. The windowed recording of the same step
(2026-10-30T20-19-30) shows the three clicks as three `queue: true` order rows taken as Bravo's element tasks.

**Questions for the lead:** none yet (O1 ships ON on Bar O's verdict; if it fails, the player-terms note goes to the orchestrator).
**Requests to other streams:** none. **Builders:** a fresh builder3 folder is seeded from `~/tank_squad/godot` server-side first
(rsync over the laptop uplink ran ~1-2 MB/min tonight); told the orchestrator.

**Plan (backlog order; smallest foundation first):**
1. O1 dev read: `tests/test_control_his_spread_clicks.gd` lays his Crossing (Spears + Wrenches, group 4) and Locks (Burners +
   Burners2, group 2) clicks on the real navmesh and prints every stage's places, block widths and the spread; then the change
   behind `--group-merged` (ON when Bar O passes), every other click byte-identical.
2. O2 Bar O filed in `workstreams.md` *Bars (round 47)* before any number on 12701-12748.
3. O3 the order lag (trace Hunters_4 ticks 1461-1710, Locks).
4. O4 the `inp` row (C47.4). **Relay from the orchestrator: the hour it lands, message native (`godot-native-6f`) with the hash;
   native's reader is on stream/native 1702fbd2c (playtest-report section (d)).** Then re-read Sumps frames 601-618.
5. O5 the recipient cue; O6 a screen order to artillery; O7 his acceptance read.

**First read of the recordings (no Godot run):** both of his far-apart clicks are a control group he had MERGED (Crossing group 4
= Spears + Wrenches, 10 vehicles; Locks group 2 = Burners + Burners2, 10). `SelectionSquads.split` cannot make one squad of 10
(MAX_MEMBERS 5), so the selection becomes two squads, which `row` lays ABREAST across his approach, each its halt footprint wide
plus GAP_M 14 apart: Crossing 61 m (the line between the two places is the across vector of his approach, (0.65, 0.76)), Locks 36 m.

