# Stream: squad, round 13 (the default plain-move shape is the wedge; S6 measured)

> **ARCHIVED — round 13 closed 2026-09-27.** This brief is kept as written, including its pre-registrations and the
> ones the stream proved wrong. What shipped is in `HANDOFF.md` *ROUND 13*; the lead's words are in `game_design.md`
> *Round 13 direction*; the evidence is in `streams/references/round13/`; the next round's candidates are in
> `roadmap.md` *Round 14 candidates*.


> Read [`game_design.md`](../../game_design.md) *Round 13 direction* (his answers; verbatim) and *Round 12: the lead's
> verdicts as they land*; [`doctrine.md`](../../doctrine.md) (round 12's S5 section and *A plain move travels AS a
> formation*); the archived round-12 brief `../round12/squad.md` (its Status is the round's record: what S5
> measured, the terrain correction, the S6 candidate's pre-registered signature). **You own** what round 12's squad
> stream owned: `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`,
> `doctrines/`, `mk/tactics.mk`, `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/tactics/`, `tests/ai_scenarios/`,
> `_agents/{doctrine,tank_brain,squad_ai_design}.md`; the round-12 carve-outs (`game/ui/command_icons.gd`,
> `game/ui/selection_panel.gd`) only if the icon's label needs the new default.

## The lead's direction (2026-09-27)

Answer 2: *"Default wedge."* Answer 3, on S6: *"I don't understand the question"* — so it is measured, not asked again.
Answer 4: the partial selection stays (*"leave"*). Standing: *"a 4s slower march for a tidier traversal is better, yes."*

## Where things stand (round 12's Status, verify)

- S5 (`161465ef`, builder0, 4 seeds × 8 cells, same seeds): the wedge settles faster in 23 of 32 paired runs and its
  first-10-s station error is lower in 7 of 8 cells (yard forward mixed 16.0 → 9.1 m); the column wins only the yard's
  forward move through the chokepoint and looks tidier in a Terminus street. The row was kept as column pending him.
- No squad he fields uses `doctrine_standard.json`; the Condemned and Law tables' plain-move catch-alls pick a
  **column in any terrain**. `make tactics-terrain` classifies the yard's spawns as dense, the Terminus as lanes.
- S6 candidate (pre-registered in the round-12 Status with its signature): after arrival, wheeled fixed-gun scouts get an
  idle `face` with nothing in sight; nav's N6 (`c8e80f5b`, on main) bounds the multi-point turn's drift (mixed stop time
  18.9 → 12.1 s on the laptop). Squad's half: do not issue the face at all when nothing is in sight.
- Tools: `make squad-shape-series` (column vs wedge, paired), `squad-transit-series`, `squad-settle
  UNITS=scout:scout:ifv:ifv:tank`, `make remote T=formation-shots`, `tactics-test`.

## Backlog (in order)

**Q1. The wedge is the default plain-move shape.** Change the faction tables' plain-move rows (`doctrines/doctrine_*.json`,
and `doctrine_standard.json` for parity) so a plain move on `open` and `lanes` forms a **wedge**; for `dense`, run the
paired series once more on the same seeds with the round-12 tooling and keep `column` there ONLY if it still wins
(the yard's chokepoint was the one cell) — otherwise wedge everywhere, and say which. The reason goes in the table's
`why` so the card reads "wedge (default)". Tests: the doctrine-table coverage test, and a test that a Condemned plain
move on the Terminus at t = 10 s is a wedge. Frames at his pose: yard and Terminus, before/after. The CPU's tasks run
drills and never take the plain-move path — pre-register the sim baseline UNMOVED and check it.

**Q2. S6, measured.** Behind a switch: `TankBrain` does not issue an idle `face` to a no-pivot (wheeled, fixed-gun) hull
when no enemy is in sight after arrival. Measure with `make squad-settle UNITS=scout:scout:ifv:ifv:tank` both arms, same
seeds, 8 seeds, on the tree WITH nav's N6 (main): stop time, worst off-slot, and whether any drill or hold that needs the
facing (an ambush's facing, a hold's `facing`) is unchanged — those carry an explicit facing and must not be touched.
CPU scouts face too, so **pre-register the sim baseline MOVED** and attribute it (both arms); the orchestrator records
it if it lands. Ship ON only if the numbers say so; otherwise OFF with the write-up.

## How to verify

`make remote T=check` green on every named commit; the series on builder0 with commit and machine; `make remote
T=formation-shots`; look at the frames. Declare any baseline move.

## Don't touch

`game/ai/movement.gd` and nav's other files; `game/control/**` beyond the two carve-outs; `game/audio/**`, `game/garage/**`.

## Waiting on the lead

Nothing; his answers are in.

## Status

_Worker report, 2026-09-27. Every number carries its commit and machine (all builder0; laptop numbers were never taken)._

**FINAL. Both items merged:** Q1 at `57ab6597` (main `cee83fd2`), the branch at `07b276c4` (main `73060fa2`, S6 ON).
The brief has no stretch items. Open: only the lead's S6 call (*Questions for the lead*). The merge-main baseline re-read was
dropped by the orchestrator: nav merged (`51a0dcd9`) with its baseline unmoved too.
**Q1 merged** by the orchestrator at `57ab6597` (main `cee83fd2`). **Q2: code green at `21864680`** (builder0, `>> remote:
make check exited 0`, 1777 passed, 0 failed, sim baseline `6313a38d7ecd99bb` unmoved); the merge hash for the whole
branch is named in *Merge here* at the bottom once the tip's check is in.

### Plan (ordered; smallest foundation first)

1. Green start: `make remote T=check` on `8f96a43c` (builder0).
2. **Q1 tests first:** the plain-move rows (open/lanes → wedge, the `why` reads "wedge (default)") in
   `test_tactics_doctrine.gd`; the Condemned plain move on the Terminus at t = 10 s is a wedge
   (`test_tactics_formation_readout.gd`, which pinned "column" in round 12).
3. **Q1 dense, pre-registered BEFORE the run:** `make remote T=squad-shape-series` (seeds 1–4, the round-12 tooling, the
   same 8 cells) on the current tree. The yard is the dense map. **The column is kept for `dense` only if, over the 16
   paired yard runs, it stops first in MORE than half (≥ 9) AND its median first-10-s station error is lower in at least
   2 of the 4 yard cells**; otherwise wedge in every terrain. (Round 12 at `161465ef`: column first in 6 of 16 yard
   runs, gap10 lower in 0 of 4 — so wedge-everywhere is expected.)
4. Q1 build: the Condemned, Law and standard plain-move catch-alls → wedge (Gangs swarm and Syndicate wedge are
   already not a column; untouched). The plain move's card line carries the table's reason so it reads "wedge
   (default)" (`ElementPlan._plan_form_up` overwrote the table's `why` with "moving as ordered: travelling in X").
   **Sim baseline pre-registered UNMOVED** (the brief's claim). Caveat written down before the run: CPU elements are
   given `move` tasks (`ElementCommander`, `ArmyPlan`), which also reach the catch-all with nothing in sight, so if the
   hash moves the cause is a CPU Condemned/Law move changing shape; I will attribute it, not adopt it silently.
5. Q1 frames: `make remote T=formation-shots` before (column, AUTO) / after (wedge) at his pose, yard and Terminus.
6. **Q2:** `TankBrain.IDLE_FACE_NO_PIVOT` switch; `--idle-face=on|off` in the settle probe; a
   `squad-idleface-series` (8 seeds, both arms, the mixed squad). **Sim baseline pre-registered MOVED** (scout and
   gang_scout are in the baseline match: wheeled, fixed gun). Ship ON only on the numbers. *(Done: see Done.)*

### Done

- **Green start:** `8f96a43c`, builder0, `>> remote: make check exited 0`, 1773 passed, 0 failed.
- **Q1 — the wedge is the default plain move, in every terrain** (`fda69463` tables + `57ab6597` card wording).
  - **Dense, on the pre-registered rule:** `make squad-shape-series`, builder0, seeds 1–4, 8 cells (the working tree of
    `736ea624` plus Q1's table edits, which a G-ordered shape does not read). Yard: the column stopped first in **5 of
    16** paired runs (bar: ≥ 9) and had the lower first-10-s station error in **0 of 4** cells (bar: ≥ 2) → **wedge in
    dense too**; the standard table's `nothing in sight, dense → column` row is removed. The column still wins the
    yard's forward move for the mixed squad (the chokepoint), as in round 12, and nowhere else. Overall 9 / 16 / 7
    (column first / wedge first / tie). Table in doctrine.md *Round 13: the wedge is the default plain move*.
  - **Tables:** Condemned, Law and standard catch-alls → `wedge`, `why` = "wedge (default), …". Contact rows untouched
    (Law `possible + dense → column`, standard `likely + dense → column`). Syndicate (wedge) and Gangs (swarm) unchanged.
  - **The card:** under AUTO a plain move's line carries the table's reason: "Alpha: wedge, traveling — moving as
    ordered, travelling: wedge (default), nothing in sight: quickest to settle, and it keeps its shape on the way";
    Formation button "Auto: Wedge".
  - **Tests:** `test_tactics_doctrine::test_a_plain_move_with_nothing_in_sight_is_a_wedge_by_default` (Condemned, Law,
    standard × every terrain × composition); `test_tactics_formation_readout::test_a_condemned_plain_move_on_the_terminus_is_a_wedge_at_ten_seconds`
    and `..._on_the_yard_reads_its_default` (both were pinned to column in round 12).
  - **Sim baseline: pre-registered UNMOVED, measured UNMOVED** (`fda69463`, builder0: `6313a38d7ecd99bb (baseline
    unmoved)`). That check exited 2 on one test, `test_tactics_tasks::..._publishes_a_station_per_crew...`: my first
    card line dropped the word "travelling"; fixed in `57ab6597`.
  - **Frames** at his pose (`make formation-shots SHAPES=auto`, builder0, seed 3; before = `8f96a43c`, after =
    `fda69463`): `references/round13/squad/q1_{yard,terminus}_auto_before_after.jpg` (top row before, bottom after; 10 s
    and arrival). Looked at: before is a column reading "Auto: Column"; after is a wedge reading "Auto: Wedge". In the
    Terminus's 20 m street the wedge spans the street and a wing rides close to a block (round 12 saw the same); on the
    yard it spreads between the container rows cleanly.

- **Q2 — S6 measured, shipped ON** (`21864680`; switch `TankBrain.IDLE_FACE_NO_PIVOT`, default true).
  - **Rule:** a face for a wheeled FIXED-gun hull (`scout`, `gang_scout`, `law_scout`: `TankBrain.no_pivot_fixed_gun`)
    while no enemy is visible becomes a stop, unless the facing is ORDERED: the unit's current K1 order carries a
    `facing`, or its element's task is a posture (hold, ambush, screen, support by fire). What is declined is a move's
    arrival sector and a post's travel heading.
  - **Series** (`make squad-idleface-series`, builder0, `fda69463`, both arms on seeds 1–8, yard + Terminus × forward +
    side × mixed + tracked, 80 m, AUTO; medians): mixed squad stop Terminus fwd 20.0 → **13.6** s, Terminus side 19.7 →
    **12.9**, yard fwd 22.8 → **15.1**, yard side 18.8 → **11.3**; **ON faster in 32 of 32 pairs**; the tracked control
    **32 ties**; arrival unmoved in every cell; the worst crew's off-slot unmoved (3.0 m fwd, ~12 m side in both arms
    and in the control: not this change). **Cost:** the scouts' own off-slot at the stop 0.9 → **2.7 m** (in-slot bar 3
    m). Faces with nothing in sight, mixed squads summed: ~690–870 per cell OFF → ~160–280 ON.
  - **Drills and holds unchanged:** `make tactics-drills IDLE_FACE=off` and `=on` (builder0, `eca402e3`) print
    identical `TACTICS` lines; `test_tactics_idle_face` asserts a hold with a `facing` reaches the scouts as an ordered
    facing with 0 declined (its first version FAILED on exactly that — a hold's sector read as a plain sector — and
    the rule was fixed in `1923eddb` before anything was measured).
  - **Sim baseline: pre-registered MOVED, measured UNMOVED.** OFF arm `57ab6597` → `6313a38d7ecd99bb`; ON arm `21864680`
    → `6313a38d7ecd99bb` (builder0, both from `make check`). Not verified why (likely: in the 40 s elimination the
    baseline's scouts are never idle with nothing in sight without an ordered facing). Nothing to record.
  - **Frames** (orchestrator's ask; `make formation-shots SHAPES=auto UNITS=scout:scout:ifv:ifv:tank IDLE_FACE=off|on
    SETTLE=on`, builder0, `aefa9a1c`, seed 3, slots drawn as yellow crosses): `references/round13/squad/q2_yard_s6_off_on.jpg`,
    `q2_terminus_s6_off_on.jpg`, and `q2_scouts_crop_s6_off_on.jpg` (full-resolution crops of the scouts at 25 s).
    **What I see:** OFF, the scouts stand angled ~45° outward along their wing's sector; ON, they point the way the squad
    travelled. On the yard the ON scout F_2 stands on its cross (OFF: a little right of it). **On the Terminus the ON
    scout F_1 stands visibly ~2–3 m short of its cross by the block corner** — flagged, per the orchestrator, for the
    lead's call. Settled at: yard ON 16.3 s (OFF not settled by 25 s in this seed), Terminus ON 13.4 s / OFF 18.6 s.

### Questions for the lead

1. **S6 (his answer 3, measured):** after a squad arrives with nothing in sight, should the scouts (a) turn to cover
   their wing's arc — the squad keeps shuffling ~7 s longer and each scout ends ~1 m from its place, angled outward
   (OFF) — or (b) stop where they arrived, pointing the way they drove, turning only when something shows up — settled
   ~7 s sooner, ~2.7 m from their places, one visibly short of its spot on the Terminus (ON, shipped)? Pictures:
   `references/round13/squad/q2_scouts_crop_s6_off_on.jpg`.

### Requests to other streams

- None.

### Known issues

- `make tactics-drills` (NOT in `make check`) fails two gang-pack assertions ("the pack rings them or baits them",
  "from more sides than a standard element would: 4") already on `8f96a43c` (builder0), with output identical to this
  branch's; not caused by Q1 or Q2. Orchestrator notified; filed as a known issue.
- The Terminus's 20 m street: the wedge spans it and a wing rides close to a block (Q1 frames; round 12 saw the same).
- `tests/tactics/variants/doctrine_standard_*.json` (ladder experiment copies) keep the old `dense → column` row; they
  are frozen arms of past experiments, not the shipped table.
- The settle probe's worst off-slot on SIDE moves reads ~12 m in both arms and in the tracked control (a slot the probe
  reads at the stop); not investigated this round.

### What to playtest

1. `make skirmish` (the Condemned or Law army the garage deals): press a squad's number key, right-click ~80 m away.
   It travels as a **wedge**; the Formation button reads "Auto: Wedge" and the doctrine line "moving as ordered,
   travelling: wedge (default), …". Once on the yard (dense) and once in a Terminus street (`make skirmish` again until
   the Terminus is dealt): on the yard it spreads between the container rows; in a 20 m street it spans the street.
2. Same order with a squad that has **scouts**: watch the arrival. They stop pointing the way they drove (no
   back-and-forth turn), and the squad is still within ~13 s instead of ~20 s. Put an enemy in sight and they turn to it.
3. To see the other arm of S6: set `IDLE_FACE_NO_PIVOT := false` in `game/ai/tank_brain.gd` and repeat 2; the scouts
   then shuffle round to face outward along their arcs.
4. Frames without playing: `make remote T="formation-shots SHAPES=auto UNITS=scout:scout:ifv:ifv:tank IDLE_FACE=on SETTLE=on"`
   (and `IDLE_FACE=off`) → `build/formation-shots/`.

### New tools

`make squad-idleface-series [IDLEFACE_SEEDS=…]` (`tools/tactics/idleface_series.py`), settle probe `--idle-face=on|off`,
`make tactics-drills IDLE_FACE=on|off`, `make formation-shots UNITS= IDLE_FACE= SETTLE=on`.

### Merge notes (shared files)

- No shared files touched (all in squad's paths). `_agents/doctrine.md`: *Round 13: the wedge is the default plain
  move* and *S6*.
- For the orchestrator's baseline re-read after nav's CP1: nothing of mine moves the hash on this tree; re-read it once
  on the merged tree as asked.

### Decisions

- The plain-move rows changed are the tables' catch-alls (the row a plain move with nothing in sight reaches); the
  `possible`/`likely` rows (Law's `possible + dense → column`, standard's `likely + dense → column`) are contact
  doctrine, not the plain-move default, and stay.
- The plain move's card line keeps "travelling" / "forming up" and then quotes the table's row, so "(default)" is
  what the player reads (the row's `why` alone never reached the card: `_plan_form_up` overwrote it).
- S6 shipped ON on the numbers; the frame cost (one scout visibly short of its slot on the Terminus, scouts not
  angled to their arcs) is put to the lead above. OFF is one line (`IDLE_FACE_NO_PIVOT := false`).

### Merge here

**`07b276c4` is green, merge here** — builder0, `>> remote: make check exited 0`, 1777 passed, 0 failed, 18 of 18
targets, sim baseline `6313a38d7ecd99bb` unmoved, determinism `550d53790035ddb4`. Anything after it on this branch is
this Status line only. Q1 alone was merged earlier at `57ab6597` (main `cee83fd2`).
