# Stream: brains (the computer defends and lies in wait; a tasked squad never stops short; the element machinery cheaper on his laptop)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (*His pick*: smart
> on both sides) and *Round 19 direction* (item 2's second path is yours to guard), `_agents/doctrine.md`,
> `_agents/navigation.md`, `_agents/workstreams.md` *Round 19*, and your round-18 brief's final report
> (`streams/archive/round18/brains.md`: B4, B5(a), the price of CPU squad leaders). You own `game/ai/**`,
> `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`.
> **Lent to orders (C19.1):** one guard line in `Elements.form` (`game/tactics/elements.gd:80`): an element is never
> formed with more than `Formations.MAX_MEMBERS` members. You do not edit that line this round; you re-read it after
> orders' checkpoint.

## The lead's direction (standing, 2026-10-04; and 2026-10-05)

> *"Yes make the CPU smarter, this would apply to all units. We want to make the computer opponents hard, but kind of
> like in Gears of War, our friendly players are just as smart, so it just makes the game better."*

And on 2026-10-05, after two games on the twelve maps, his second item (the orchestrator read both paths; the
second is in your paths): *"I selected 2 squads and right clicked a point on the map - the resultant indicator dots
for all the units was all over the map, and a bunch of vehicles just basically ran off to the middle of the map."*
Orders owns the fix (one order per squad); the element machinery must make the bad case impossible (C19.1).

## Where things stand (read at `93ec68b4`)

- **Your round-18 ambush work is unmerged**, on branch `brains-r18-ambush` (renamed from `stream/brains` at the
  launch; `brains-wip-backup` also exists): `AmbushSite`, the commander choosing an ambush, the in-time rule
  (`4b060f00`), `ambush_probe.gd`, `ai-element-perfplay`, `element-digest` (`d6c7f3e1` is its tip). D1 on that
  branch (`6e0e116f`) is on `main` as `a122d6ff`: cherry-pick the rest onto this round's branch (which starts at
  `main`) and do not merge the old branch wholesale.
- **Measured (your own, round 18):** with elements on, the CPU takes 0 ambushes in his frame on parade over 8 seeds
  with the in-time rule; before it, 7 of 8 taken, 5 sprung, from a bay never: both sides race for the centre; the CPU
  needs about 100 m at 7–8 m/s to reach a bay, his line about 77 m at 9 m/s to reach the kill zone. **A bay ambush
  needs a CPU that DEFENDS.** The price of CPU squad leaders on his laptop (quiet window, equal vehicle counts, 23
  bins): mean +6.5 ms a tick (+20 %), median +4.6; of a sampled frame's +3.0 ms self: navmesh grounding of every
  slot +0.87, the tactics layer +0.92, the feeds +0.4, the brain's order paths +0.37, the ambush search +0.07.
- **In his skirmish today the CPU runs no squad leaders** (elements off on the CPU side); its commander never issued
  an ambush. Whether to turn CPU elements on for him is HIS decision; it was not put to him in round 18 because it
  would have cost him 20 % and shown him no ambush. This round makes the question answerable: a posture that
  produces ambushes he meets, at a price that is measured and cut.
- **One spot on the Cut** (roadmap round 19 candidate 4): seed 3, at (−4.1, 44.9), open ground 6 m from a city
  block's face; the re-seat fires its 3 allowed times and the squad stops 105 m short, one crew 18.5 m off its slot.
- Orders found in your paths (do not fix before O3 merges; judge and reply): `ElementPlan.clamp_to_arena`
  (`element_plan.gd:1298`) is the old square ±116 clamp, not the arena shape's; `Element.remove` (`element.gd:580`)
  emits no `element_changed`, so a brain can hold a stale station for one poll; `Elements.form` takes any number of
  members and `ElementPlan.build` never passes `TacticsFormation.auto`, so a 10-vehicle wedge is 126 × 70 m.
- The twelve-map rotation is dealt (`da0bdef3`): thirteen baseline lines (foundry + twelve), every one of your
  changes to fights is declared and merged alone (C19.3), as in round 18.
- The per-map 40 s baselines hold no bait on four of the six older maps (roadmap candidate 5): a decision change
  needs its own series. `make sim-variants` (ship, round 18) is the instrument.

## Decided by the orchestrator (broad strokes are ours; record a reason if you overturn one)

- **The posture comes before the price question.** A CPU side that is ahead on points, or whose zone is
  threatened, HOLDS: its line elements take positions covering its zone, and one lies in ambush on the flank of the
  open ground the enemy must cross (B5(a) as built, now with a reason to be there in time). A CPU behind on points
  attacks as today. The trigger is the match's own score (read `Match.control_score` / the objectives' owners; the
  board stream adds a `score_changed` signal, C19.4: read it when it lands, poll until then).
- **Both sides.** The same posture is available to his squads as an order he can give ("hold here, ambush the
  crossing" = the existing Ambush order with a `from`), so nothing is CPU-only (his rule). No new order button this
  round: orders owns the UI; file a request if the existing Ambush order needs a parameter.
- **The price is cut before it is offered.** Equal-answer work on the element machinery (the navmesh grounding of
  every slot, the situation build, the feeds), proved by `make element-digest` (your round-18 instrument: identical
  decisions, lower cost), each saving stated as ms on his laptop in a quiet window asked for through the orchestrator.
- **His question is prepared, not asked by you:** "the computer sets ambushes on the open maps; it costs about X ms
  a frame on your laptop (after the cuts); recommended on / off". The orchestrator asks it with your numbers.

## Backlog (in order)

- **B1. Carry the ambush work forward.** Cherry-pick the unmerged commits from `brains-r18-ambush` (skip D1), green
  on `main`'s tree, every scenario passing, `--no-cpu-ambush` still the control arm, CPU elements still OFF on his
  path. Pre-register UNMOVED on all thirteen lines (nothing runs on his path or in the baselines' CPU armies unless
  elements are on: say which it is before the check).
- **B2. The posture: hold and lie in wait.** `ElementCommander` chooses HOLD for a side that is ahead on points or
  whose zone is contested, posts its elements over its zone and one ambush on the flank of the enemy's approach
  (site search from the zone, not from the element); ATTACK otherwise. Scenario first (`tests/tactics/`): on parade,
  CPU ahead on points, his line crosses the floor → the ambush is taken in time and sprung from a bay (today: never).
  Then `ambush_probe.gd` in his frame, 8 seeds, parade and the Open Yard: ambushes taken, sprung, and the outcome
  paired per seed against the control arm (lesson 256: paired differences with their spread; an event count under
  about 30 is a count, not a rate).
- **B3. The price, cut.** The element machinery's per-tick cost with elements on: the three largest terms by
  removal inside one run (your profiler split), each cut as equal-answer work proved by `element-digest`; the
  interleaved on/off series again (`ai-element-perfplay`) in a quiet window the orchestrator schedules, equal
  vehicle counts, before and after. Report the new +ms with its spread.
- **B4. The Cut, seed 3.** The squad that stops 105 m short beside a wall: reproduce with the probe, name the cause
  (the re-seat cap? the slot ground beside a face? the corridor?), fix it for both sides, prove it on the Cut and on
  the Sumps and Terminus (D4/D5's 80 of 80 must still hold). Declared if any line moves.
- **B5. Two squads, one element: never.** After orders' checkpoint (CP2) merge `main`, re-read the lent guard, and
  add the tactics-side tests: `Elements.form` refuses more than `MAX_MEMBERS`; an element's transit anchor is its
  own centroid only when its members are within one formation width of each other (otherwise the lead vehicle's
  position); `ElementPlan.clamp_to_arena` uses the arena's shape; `Element.remove` emits `element_changed`. Each
  pre-registered; any line that moves is attributed before the merge.
- **B6. A decision change has its own series** (roadmap candidate 5). Write the rule for this round: the set of
  maps and seeds on which B2's and B4's decision changes are visible (where the 40 s baseline sees nothing,
  `sim-variants` with a longer match or a bait), and run it for each declared change. The orchestrator relays the
  recipe to the handoff.
- **Stretch.** (a) The CPU holds with its artillery registered on the kill zone (the ambush sprung by a barrage).
  (b) The Ambush order for his squads takes a `from` he picks (request to orders for the gesture). (c) The idle
  fallback that sends an ordered CPU unit to the objective (`tank_brain.gd:2487, 2529`): confirm his units can never
  reach it (orders' first suspicion for "ran to the middle"); a test that pins it.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` and `N
passed, M failed`; never a pipe). **Every change to fights is DECLARED, merged alone, and its moved lines adopted
with `make sim-baseline-adopt`; everything else pre-registers UNMOVED on the thirteen lines and determinism**
(C19.3). Scenario or probe first; a ladder or a paired series for anything that changes who wins; `make
ai-scenarios-check`, `make tactics-drills`, `make element-digest`; the laptop series only in a quiet window asked for
through the orchestrator (lesson 260: the count of other Godot processes read before AND after each run; a run with a
neighbour discarded, kept with that written on it). Every number: commit, machine, workload, N, spread.

## Don't touch

`game/control/**`, `game/ui/**` (orders and board) · `game/garage/**`, `game/progression/**`, `game/units/**`
(garage; `Units` read freely) · `game/match/**` (board; read `Match` freely; a signal you need is a request) ·
`arenas/**`, `game/arena/**` (nobody; a layout defect is a request) · `mk/core.mk`, `tests/baselines/**` except the
lines you declare and adopt (C19.3) · balance values (C12.6; his) · the elements flag's default on his path (his
decision; B3 prepares it).

## Waiting on the lead

- **CPU squad leaders on in his skirmish** (the posture needs them). Asked by the orchestrator with B3's number.

## Status

_Updated 2026-10-06 05:56 PDT (round 19, brains worker). The FINAL REPORT is first; the detail per item follows._

### FINAL REPORT (round 19, brains)

**Every backlog item is done, or waiting on his gate; my last code commit is green.** Last green: `37bdab41` (B5,
on merged main `b47c19a7`; builder0, `>> remote: make check exited 0`, 2131 passed 0 failed, thirteen lines unmoved,
determinism `762a0576f944f5b7`). Above it: docs and evidence only.

| item | where | what he gets / what was found |
|---|---|---|
| **B1** the ambush carried forward | `b7976c9d` (on main via `d7f2bd93`) | round 18's CPU ambush (AmbushSite, the in-time rule, `--no-cpu-ambush`) on this round's tree |
| **B2** hold and lie in wait (DECLARED) | `d7f2bd93` (main `eef498db`) | a CPU that is ahead on points, or whose zone is threatened, holds the zone and lays a flank ambush. Parade, 8 paired seeds: **sprung from the bay 8 of 8** (attacking: 0), depot held, more points; it **trades about 1.4 ± 1.2 more of its own vehicles** in that 8-v-4 stage. The Open Yard: holds, no ambush site |
| **B3** the price | cut 1 `2a87bfd7` (main `5619363f`) | the ambush search 2–5× faster, equal answers (900 cases): a 2.8–6.8 ms lump on his laptop is now 1.3–2.6 ms. **The price in his frame** (quiet window, main `5619363f`, laptop): **+5.1 ms a tick mean, +3.4 median, sd 4.5, 23 bins, +17 %** (round 18: +6.5 / +4.6). Cut 2 (slot grounding) built, equal, **0.0 %** saved: reverted. In his frame the CPU took **0 ambushes**: it holds only once threatened, and by then it is in contact (census) |
| **B4** the Cut, seed 3 (DECLARED) | v1 `47463712` (main, 99/100); **v2 `5f77e318`** (main `1fe73f9f`) | a crew corked at a block's corner by a squadmate parked short of its slot now trades slots with it. **100 of 100 arrive** (off 99 of 100), round 18's 80 unchanged |
| **B5** two squads, one element: never | **`37bdab41`** (to merge) | the lent guard tested; a travelled move starts at the lead vehicle when the element is spread; the element clamp follows the arena's shape; removing a crew always tells the brains; the posture reads `Match.score_changed` |
| **B6** a decision change's own series | rule + run (above, B6) | the rule written; whole-match series: the posture is exercised on 9 of 13 maps, the swap on 1 |
| stretch (a) guns on the kill zone | `e48856f2` | built, scenario-tested; no measured effect on one seed |
| stretch (b) Ambush `from` for his squads | request to orders | the element side takes `from` already |
| stretch (c) the idle fallback | `bb6a0747` (main) | pinned: his units cannot reach the roam-to-the-objective fallback |

**Decisions taken (with the reason):** a side that holds no zone attacks even when ahead (nothing to defend); holding
posts run no contact drill (a post that assaults out of its zone is not holding); a hold lasts at least 10 s; the
parade scenario starts the CPU on its depot (that is how it got ahead) and his line 10 s later (set off at once, the
ambusher is seen crossing open ground); B4's swap only after a re-seat came back unchanged, its own budget of 2 (v1
spent a re-seat a Sumps squad needed); cut 2 reverted at 0.0 % (round 18's rule).

**Questions for the lead (asked through the orchestrator, his gate):** CPU squad leaders in his skirmish: *"the
computer holds its depot when it's ahead or you're coming for it, and if it got there first it sets an ambush on the
open ground you cross; about 3–5 ms a tick on your laptop (up to ~13 ms in the heaviest fights)"* — recommended OFF
until he has played it (`make skirmish ARENA=parade CPU_LEADERS=1`, main `a748a264`).

**Requests to other streams:** orders (stretch (b), not urgent): a gesture for the Ambush order's `from`.

**Known issues:** (1) the ambush spot is hidden as one point, the line lying there is ~40 m wide: on parade his line can
see the outer crews from parts of the floor and the ambush springs before the kill zone (two fixes tried, reverted;
needs a per-seat concealment test). (2) In a match where the CPU does not score first it never lays an ambush (by
design of the in-time rule). (3) Orders' 12–20 m "off the straight line" in the first 5 s is the form-up into the
wedge (round 12's transit), not a crossing; option (b) changed nothing and was reverted. (4) In B2's stage the hold
trades worse in vehicles than attacking (−1.4 ± 1.2 a pair).

**What to playtest (exact commands):** `make skirmish ARENA=parade CPU_LEADERS=1` — take your near depot slowly, let the
computer get its own first, then cross the floor toward it in a line: watch the east bay. `make skirmish ARENA=cut` —
attack-move four tanks 150 m up the middle (they used to stop beside the block). Two squads (box-select both) right-
clicked anywhere: two wedges side by side, nobody to the middle.

**Next steps:** a per-seat concealment test for AmbushSite (with the real sight model); form up on the move (orders'
finding); a series to decide whether stretch (a) earns its place; the price's next cut needs an in-run A/B, not the
profiler (the profiler overstated grounding 0.86 ms → 0.0 %).

**Merge notes (shared files):** `game/tactics/elements.gd` (mine) holds orders' lent guard unchanged; `tools/tactics/
squad_arrive_table.py` is new (tactics tooling, mine); `mk/tactics.mk` gains `squad-arrive-series` and `DIGEST_FLAGS`;
`ElementPlan.clamp_to_arena` now calls `Orders.clamp_to_arena` (orders' file, read only).

### Merge notes (for the orchestrator)

- **Green and ready: `47463712`** (builder0, 2026-10-06 00:47–01:24 PDT: `>> remote: make check exited 0`, 2075 passed 0
  failed, 22 targets, all thirteen lines unmoved as pre-registered, determinism `762a0576f944f5b7`, 26 engine lines as
  main). Carries B3 cut 1 (equal answer), B4 (DECLARED; moves no line: no baseline runs squad leaders), `--no-make-room`,
  the B6 rule, cut 2 built and reverted. `make element-digest` at `9c65c9d3` (B4 in): `28fec80c6c83cfb33cdbbe615f67d552`
  (64 runs, builder0): the reference for later equal-answer work. **Quiet-window series requested** (message to the
  orchestrator, 01:30 PDT): `make ai-element-perfplay ELEMENT_PLAY_DIR=/tmp/claude-1000/element-play-r19`, ~11–12 min,
  arm assertion `BRAINS_AMBUSH team 1 … hold_s` on every "on" log, none on "off".
- **B5 green: `37bdab41`** (= `c1ba812a` + docs, on merged main `b47c19a7`; builder0 04:40 PDT on, `>> remote: make
  check exited 0`, 2131 passed 0 failed, 22 targets, thirteen lines unmoved as pre-registered, determinism
  `762a0576f944f5b7`; 28 engine lines = main's 26 + the two deliberate `Elements.form … refused (C19.1)` lines, one from
  orders' test and one from mine, both `expect_error`). Above it: docs only (`8e923038`).
- **B4 v2 green: `5f77e318`** (= `455d68b3` + docs; builder0 03:44–04:40 PDT, `>> remote: make check exited 0`, 2076/0,
  thirteen lines unmoved, determinism `762a0576f944f5b7`, 26 engine lines). Series 100/100 (off 99/100). B4 v1 is on
  main via `47463712` (99/100): v2 goes on top.
- **Merged:** `47463712` → main `5619363f` (B3 cut 1, B4 v1).
- **Merged:** `d7f2bd93` → main `eef498db` (the orchestrator, 2026-10-05 late). Do NOT merge main before CP2 (orders'
  O2+O3); the quiet-window series is sent to the orchestrator as command + duration + arm assertion when B3's cuts exist.

- **B1 + stretch (c) + B2 are green at `d7f2bd93`** (builder0, 22:53–23:33 PDT: `>> remote: make check exited 0`,
  2071 passed 0 failed, 22 targets passed, all thirteen sim-baseline lines unmoved as pre-registered, determinism
  `762a0576f944f5b7`, 26 lines match `ERROR|WARNING|parsing error`, the same count as main's check). Above it:
  `dcc66a7b`, `7cd36a9f` (the probe only, test-side; no check of their own yet). **B2 is the round's first DECLARED
  decision change (C19.3); it moves no line** because CPU elements are off in the baselines and on his path: merge it
  alone or with B1, say which; nothing to adopt.
- The check on the launch tree (`567e1997`, 22:14 PDT) exited 0 too, but its rsync picked up B1's cherry-picks
  mid-way (2060 tests against main's 2057): it is a check of no commit, recorded as such.

### Plan (order taken; the brief's order)

1. **B1** carry the ambush forward: cherry-picked onto `567e1997` as `b7976c9d` (one commit; the make targets and
   settle_probe's digest were already on main; D1 skipped; the old brief's Status edits stay in the archive).
2. **B2** the posture: `Posture.decide` (pure, `game/tactics/posture.gd`) + `ElementCommander._hold` behind
   `POSTURE_ENABLED` (`--no-cpu-hold` = control arm); scenario `test_tactics_cpu_hold.gd`, unit tests
   `test_tactics_posture.gd`; then `ambush_probe.gd` with a hold arm, 8 seeds, parade + the Open Yard, paired.
3. **B3** the price: the profiler split with elements on, the three largest terms cut as equal-answer work proved by
   `element-digest`; the quiet-window series asked of the orchestrator.
4. **B4** the Cut, seed 3.
5. **B5** after CP2: the tactics-side guards.
6. **B6** the decision-change series rule.
7. Stretch (c) first (cheapest, and it answers orders' first suspicion), then (a), (b).

### B3 — the price, cut (in progress)

**The split** (Godot's script profiler, builder0, headless parade seed 1801, 90 s, Law v Condemned at 4600, squad
leaders on BOTH sides (`--green-elements --rust-elements`, `7cd36a9f`) against none (`b2a3f65b`, docs only above it);
30 and 38 sampled frames, so shares, not ms you will feel; files `references/round19/brains/prof-*-builder0.json`).
Self time a sampled frame, on − off: **navmesh grounding** `Pathing.closest_point` +0.86 ms (237 calls a frame
against 52); **the ambush search** `CoverMap.points_near` +0.48 + `AmbushSite.find` +0.11; `ElementSituation.build`
+0.24; the order feeds `ElementFeed.normalize` +0.24, `OrderFeed.*` +0.18; `TacticsFormation.seat` +0.11. Script time a
sampled frame 14.2 ms on, 13.4 off.

- **Cut 1 — the ambush search** (`2a87bfd7`, equal answer): unsorted candidates (the best spot is chosen by a full
  key, so order never matters), the open-ground test before the two sight lines with an early exit, one search per
  think (holding, every element searches from the same zone). **Proof:** `test_tactics_ambush_site` runs the new
  search against round 18's sorted one over 300 random cases on parade, the Open Yard and the Sumps: identical in all
  900 (188 / 178 / 41 with a site). **Cost** (laptop, `2a87bfd7`, cold sight-line memo, load 0.2, 300 searches): parade
  2.80 → 1.45 ms a search, the Open Yard 6.66 → 2.62, the Sumps 6.79 → 1.32.
- **Cut 2 — open ground answered without probing: built, proved equal, measured, NOT shipped** (`1091d507`, reverted
  in the next commit). A slot in a cell whose square grown by the largest clearance (5.5 m) + 1 m is on the navmesh at
  every 1 m sample is its own grounded point. Proof: every rotation map, 400 random points × 3 clearances, identical in
  all 14,400 cases (laptop); `make ai-ab-match AB_SWITCH=ground_clear` (builder0, `1091d507`, parade 1801, 120 s, squad
  leaders on both sides): state hash equal to a plain run (`587eaf369fc045c2`), **whole tick's scripts 12,499 vs
  12,505 µs: 0.0 % saved** (controller band −0.4 %). **The profiler's +0.86 ms "grounding" was mostly the profiler's own
  cost on 237 instrumented calls a frame**, not time the tick spends: round 18's slot-grounding cut (0.4 %) said the
  same. Round 18's rule: a saving inside the noise is not shipped (it adds a per-cell first-touch cost for nothing).
- **THE PRICE, re-measured in his frame (the orchestrator's quiet window, laptop, main `5619363f` = `47463712`,
  2026-10-06 01:30:42–01:40:47 PDT; 61 load samples 0.82–2.76, all the series' own, no foreign Godot; files
  `references/round19/brains/element-play-5619363f-laptop/`):** `make ai-element-perfplay`, parade + the Sumps × seeds
  92721, 1801 × CPU squad leaders on/off, interleaved. Arm assertion holds (every "on" log prints `BRAINS_AMBUSH team
  1`, no "off" log does). **Whole tick's scripts at equal vehicle counts (phases binned 5 wide, on − off), 23 bins:
  mean +5.1 ms a tick, median +3.4, sd 4.5, range −0.0 .. +13.4; +17 %** (round 18, `4b060f00`: +6.5 mean, +4.6
  median, +20 % — lower, within the spread: not a proven cut). Strongly seed-dependent as before: parade 92721
  −0.0..+2.0, parade 1801 +3.8..+11.7, Sumps 92721 +0.2..+6.5, Sumps 1801 +9.5..+13.4. Frame average on/off: 68/53,
  92/78, 108/84, 128/98 ms (different fights: not a price). **Ambushes taken in his frame: 0 of 4 runs**; the posture
  DID trigger (held 0, 38, 33, 26 s). **Why no ambush (answered, builder0 `340d2b3d`, the same perfplay with the census
  counting refusals, parade + the Sumps seed 1801):** the CPU starts on ATTACK (0–0 on points, no zone held) and turns
  to HOLD only at 27–30 s, when "zone threatened" (an enemy 33–35 m from its depot), never for being ahead; by then
  its line is in contact: ambush refusals parade in-contact 148 / no-site 11 / late 18, the Sumps 103 / 33 / 0. Before
  contact, while attacking, the sites it finds are late or absent. **So in a match like this the CPU defends but does
  not lie in wait: the bay ambush needs it to be AHEAD before he arrives** (it took the near depot first and he comes
  later), the stage the parade scenario and series measure. Not changed: making it lay an ambush while attacking is
  round 18's in-time failure again.
- **Not cut, and why:** the order feeds (`Element.state()` built per crew per read: a per-tick cache is not provably
  equal, the state changes in many places, and it is ~0.03 ms a call); `ElementSituation.build` (a contact sort and a
  loop: small).

### B4 — the Cut, seed 3: fixed (`72e0f7c9`, DECLARED)

**Cause (the settle probe's trace, with the mover's own readout added: `--trace-mover=on`):** four Law tanks
attack-moved 150 m. One crew drives down a city block's west face (the block at (22, 58) is 40 m square) and must turn
its south-west corner to reach its slot under the south face; the squadmate whose order counted as ARRIVED 3.7 m short
of its own slot stands at that corner; the crew presses against it for 70 s (wheels at 11 m/s, the hull still). D5's
fresh seating came back identical three times (`0312`): nothing about the positions changes, so neither does the
seating. Not the slot's ground (both slots fit, 0.3 m), not the corridor. **Fix, both sides:** when the stuck-crew
watch fires and a stationary squadmate stands within 9 m, the two trade slots (`Element.MAKE_ROOM`, re-applied while
the seating keeps choosing the old seats, until the movement ends); otherwise the re-seat as before; counts toward
MAX_RESEATS. **Scenario** `test_tactics_make_room`: without, 3 re-seats, 105.5 m short; with, 1 swap, arrived at 31.8 s
(laptop, `72e0f7c9`). Settle probe: arrived 27.7 s, stopped at (2.3, −57.3) — the whole 150 m. `--no-make-room` is
the control arm in a whole match.

**The first version failed its series, and was revised (`455d68b3`).** `make squad-arrive-series` (builder0,
`47463712`, 01:41–02:04 PDT; round 18's five squads × yard, Terminus, pit, the Sumps + the Cut × seeds 1–4, both arms
on the same tree; `references/round19/brains/squad-arrive-47463712-builder0.jsonl`): make-room on 99 of 100 arrive, off
99 of 100 — **the Cut 20 of 20 against 19, but the mixed Law Sumps squad (scout, IFV, tank, tank) seed 3 lost its
arrival** (the swap fired on the first stuck watch, spent one of the three re-seats, and the crew that stuck 40 s later
had none left). Revised: (1) the swap fires only once a fresh seating this movement has come back UNCHANGED (the case
where re-seating cannot help; until then the element behaves exactly as round 18's); (2) a swap has its own budget
(MAX_SWAPS = 2 a movement) and spends no re-seat; (3) a new swap replaces the last (the Cut corks twice with the same
crew). Laptop, settle probe, 120 s: the Cut seed 3 arrives 47.5 s (1 re-seat, 2 swaps); the Sumps mixed seed 3 36.2 s,
seed 2 36.8 s (off: 105.3 s). The 100-run series again on `455d68b3`: queued on builder0, then the check.

### B5 — done after CP2 (`c1ba812a`, on merged main `b47c19a7`)

The lent guard in `Elements.form` re-read and accepted (orders' 14-line block: more than `Formations.MAX_MEMBERS`
living members refused with a push_error, before anyone leaves an element). `tests/test_tactics_c19_guards.gd` (5
tests, laptop green): form refuses six crews and moves nobody; **`Element.transit_origin`** — a travelled move starts
at the centroid only when the crews stand within one formation width (the line's frontage at the open spacing),
otherwise at the LEAD vehicle (two pairs 150 m apart started at the empty middle); **`ElementPlan.clamp_to_arena`**
delegates to `Orders.clamp_to_arena` (M4: the shape inset 4 m, out of water and pits; the square ±116 admitted
(116, 116), outside parade's hexagon); **`Element.remove`** emits `member_removed`, which `Elements` turns into
`element_changed` (or disbands an empty element) whoever called (`rts_controls` removes crews directly). The posture
now reads `Match.score_changed`'s snapshot (C19.4; the match's own fields before the first emission). Orders'
`test_control_two_squads` passes on the merged tree.

**Orders' finding (crews off their straight lines while seating in their own travelling wedge), read:** reproduced
with `make two-squads-playtest` on `c1ba812a` (laptop): one order per squad, two elements of five, worst crew 20.0 m off
its straight line in the first 5 s (grouped case, Alpha_3; "selected" 12.1 m), none toward the middle (≤ 0.6 m).
**Cause, first named wrongly and corrected:** I said the transit seats crews by role so back crews cross the shape.
The orchestrator approved option (b) (squared driving within a role tier, as "travel" already does); built and
measured with the same probe: **no change** (selected 12.1 → 12.1 m, grouped 20.0 → 20.0, single 13.6 → 13.3), so
reverted, never committed. Read from the per-crew lines instead: Alpha_3 (grouped) starts at (−32.7, 91.1), its slot
is (15.2, 6.9) to the south-east, and at 5 s it is at (−41.1, 65.3), 8 m WEST: it is driving to its STATION in the
wedge laid around the transit anchor (the squad standing abreast at the spawn forms the wedge first, then travels).
So the 12–20 m is the form-up from abreast into a wedge, by design of round 12's travelling anchor, not a crossing
inside a role; no crew runs toward the middle (worst 0.6 m selected). **Next if he notices it:** form up on the move
(stations that start where the crews stand and converge on the shape over the first leg) — a transit design change,
not tonight's.

### B6 — a decision change has its own series (the rule for round 19)

The thirteen baseline lines run no squad leaders, so every change of this round that lives inside an element (B2's
posture, B4's swap, B3's cuts) is invisible to them by construction. The rule:
1. **Its own probe series**, paired per seed, both arms on ONE tree, on the maps where the decision is taken: B2 →
   `tests/tactics/hold_probe.gd` on parade and the Open Yard, seeds 1–8, `--hold=on|off`; B4 → `make
   squad-arrive-series` (five squads × yard, Terminus, pit, the Sumps, the Cut × seeds 1–4, `--make-room=on|off`).
2. **A whole-match series** where squad leaders run on both sides, so the change can fire in a real fight: `make
   sim-variants VARIANTS_ONLY=his4600c90 "VARIANTS_EXTRA=--green-elements --rust-elements"` against the same plus the
   control arm (`--no-cpu-hold`, `--no-make-room`); a map whose hash does not move did not exercise the decision.
3. **Equal-answer cuts** carry an equality proof instead (a reference test, `make element-digest` with and without
   `--brains-off=<switch>`, `make ai-ab-match AB_SWITCH=<switch>` whose state hash must equal a plain run's).

**Run (builder0, `8e923038` / `4c637526` (docs only between), 2026-10-06 05:20–05:55 PDT, `make sim-variants
VARIANTS_ONLY=his4600c90` — his army size, 90 s — with squad leaders on both sides; files
`references/round19/brains/sim-variants-b6-*-builder0.tsv`):** against the plain arm, `--no-cpu-hold` moves the hash on
**9 of 13** maps (yard, pit, crossing, Sumps, locks, parade, gorge, docks, Open Yard; unmoved foundry, Terminus,
archipelago, the Cut) and `--no-make-room` on **1 of 13** (the pit). So the posture is exercised in a whole fight on most
maps, and B4's swap almost never (its own series, `squad-arrive-series`, is where it is seen: 3 of 100 runs). A future
change to either decision is judged on those maps.

### Stretch (a) — built (`e48856f2`, DECLARED, tiny)

Holding with an ambush laid, the support element (artillery, Lancers) is REGISTERED on the ambush's kill zone: once
there is contact its support-by-fire task aims where the ambush springs, not at the nearest contact. Scenario
`test_the_holding_cpus_guns_are_registered_on_the_kill_zone` (parade hold stage + two artillery behind the depot): the
guns' task is the kill zone after the spring; unregistered it is not. **Effect on the fight: not measured as anything**
(one seed: his line lost 1479 registered vs 1461 unregistered). Kept because it is what the posture means; a series
would decide whether it earns its place.

### Stretch (b) — a request to orders (filed below; nothing to build in my paths)

The element side already takes it: `ElementTask` accepts `{"verb": "ambush", "to": kill zone, "from": [x, z]}` and the
plan lays the line at `from` facing the kill zone (B1). What is missing is HIS gesture to pick `from`.

### Requests to other streams

- **orders (stretch (b), not urgent):** the Ambush order for his squads could carry a `from` he picks: e.g. the second
  right-drag of the Ambush order, or Ambush clicked on the kill zone then a click on where to lie, sent as the task's
  `"from": [x, z]` (ElementTask validates it: ambush only, finite [x, z]). Without it his ambush lies at 0.6 of its
  guns' range from the kill zone, as today.

### Stretch (c) — done (`bb6a0747`)

`tests/test_ai_idle_fallback.gd`: no order verb but "idle" leaves the brain SPOT or ADVANCE (the two options that drive
to the objective or the enemy base), and his idle scout and tank stay at their posts with a zone open on the map
(laptop: 0.0 m in 12 s each). **For orders: the brain's roam-to-the-objective fallback is not "ran to the middle"**; his
units always hold a post (their spawn until his first order), so the element transit from the two squads' centroid
(the brief's second path) is the remaining suspect.

### B1 — done (`b7976c9d`)

Cherry-picked from `brains-r18-ambush`: `6eff815c`, `0e003b28`, `b1108cc0`, `4b060f00`, `456870ea` (ambush_site only),
`d6c7f3e1` (ambush_probe's uid only). Already on main and skipped: D1 (`a122d6ff`), `ai-element-perfplay` (both
commits), `element-digest`, `AB_FLAGS`, settle_probe's digest. Tests: `test_tactics_ambush_site`,
`test_tactics_cpu_ambush` pass (laptop, 3/0). `--no-cpu-ambush` stays the control arm; CPU elements OFF on his path.

### B2 — built and measured (`d7f2bd93`; probe `7cd36a9f`)

**The rule** (`Posture.decide`, pure; `ElementCommander._hold`): a side that holds a zone HOLDS it when it is ahead on
points or an enemy it knows of is within 60 m of a zone it holds; otherwise it attacks as before. Holding: the line
posts across the zone facing the enemy's approach, with NO contact drill (in the first stage react_to_contact took a post
30 m off the depot and assault_through 50 m); the first post attacks an intruder in the zone; one line element lies in
ambush with the site searched from the ZONE (AmbushSite; taken only when in place in time); recon screens 45 m out;
support stands 45 m behind. A hold is kept at least 10 s. `--no-cpu-hold` is the control arm. The score is POLLED each
think (1 s) from `Match.control_score` and the objectives' owners (C19.4: board's `score_changed` is not on main yet).

**Scenario** `test_tactics_cpu_hold` (parade; the CPU's two elements on and beside its depot (36, −24), ahead 20–0;
his line of four Law tanks sets off 10 s later toward the depot): HOLD takes the ambush at 1.0 s, springs it from the
bay (x = 60), four on the depot at 20 s; ATTACK never springs one from a bay. Red before B2 (the commander attacked).
**Why the stage starts the CPU on its depot:** "ahead on points" means it has been standing there to score; started
at its base with the lead already on the board, it was still driving up when his line arrived. **Why his line waits 10
s:** set off at once, the ambusher is still crossing open ground when his guns see it, and springs at x = 41
(`hold_probe.gd --his-delay=0`).

**The series** (`tests/tactics/hold_probe.gd`, laptop `flightdeck`, `d7f2bd93`, 2026-10-05 22:55–23:30 PDT, load
6.3 → 1.6; the stage above, 60 s, seeds 1–8, hold vs `--no-cpu-hold` on the SAME seed; CPU 8 vehicles (2 tanks + 2 IFVs
×2) v his 4 Law tanks; file `references/round19/brains/hold-series-d7f2bd93-laptop.jsonl`):

| | parade, hold | parade, attack | Open Yard, hold | Open Yard, attack |
|---|---|---|---|---|
| ambush taken / sprung from a bay | **8 / 8** (x 59.6–60.3, 8–19 s) | 0 / 0 | 0 / 0 (no site found) | 0 / 0 |
| CPU on its depot at 20 s | 4 in 8 of 8 | 0 in 8 of 8 | 4 in 8 of 8 | 0 in 8 of 8 |
| CPU points at 60 s | 40–50 | 31–38 | 44–50 | 36–50 |
| CPU alive (of 8), paired hold − attack | **−1.4 ± 1.2** | | **−1.6 ± 2.6** | |
| his alive (of 4), paired hold − attack | **+1.1 ± 1.0** | | **+1.8 ± 1.2** | |

**Read it plainly:** the CPU now defends and springs a flank ambush from the bay every time on parade (before: never),
holds its zone and banks more points — and in this stage (8 against his 4, his line static for 10 s) it trades WORSE in
vehicles than charging him does: a defender lets a weaker attacker come to it, so fewer of his die and a few more of its
own. On the score that wins a match it is ahead in every pair; in kills it is behind by about 1.4 vehicles. N = 8 per
map: a count, not a rate (lesson 256). The Open Yard has no flank spot AmbushSite accepts (a hold without an ambush).
**Known limit (found, not fixed):** the ambusher's spot is hidden as ONE point, its line of four is about 40 m wide, so
on parade his line sees the outer crews from parts of the floor (seed 6: from his spawn, 99 m) and the ambush springs
before he reaches the kill zone. Tried: (1) the site must hide the whole line's width → the bay passed at x ≈ 67 but the
round-18 west-bay scenario found no site; (2) plus the ambush line laid tight (dense spacing, 24 m) → no bay passed at
all, the hold scenario red. CoverMap's line test is too coarse to place a line rather than a point. Both reverted;
time-boxed. Next if wanted: an AmbushSite that tests concealment per seat against the real sight model.

**Decisions (one line each):**
- B2: a side that holds NO objective attacks even when ahead on points (nothing to defend; it is losing ground). The
  brief says "ahead on points OR zone threatened"; I read both as "and it holds a zone".
- B2: a hold is kept at least 10 s once chosen (one second's score must not flip the army), and ends at once if the
  zone is lost.
- B2: holding posts run without contact drills (a post that charges out of its zone is not holding); the commander
  sends the first post at an intruder in the zone. His own Hold order is unchanged.
- B2: the posture runs for the commander's default ("direct") plan only; the ladder's `+army` and `+pin_and_flank`
  variants keep their own plans unchanged (they are discovery arms, not his path).
