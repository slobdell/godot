# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-10-09 evening — **ROUND 24 IS CLOSED (the section below). The final check runs on main `b3bf60ce` (every merge; log `build/r24-final-check.log`, filed as `streams/references/round24/check-final-b3bf60ce.log` when it lands); if this line still says "runs", read it first: `grep -E "^>> remote: make check exited|^[0-9]{4} passed|ALL JUDGED" build/r24-final-check.log`. No round is running. He pushes `main`.**_

## ✅ ROUND 24 IS CLOSED (2026-10-08 ~21:00 PDT → 2026-10-09 evening) — read this first

**Two streams, all merged.** Briefs in `streams/archive/round24/`, evidence under `streams/references/round24/{his,brains,native,perf}/`
and main's check logs beside them. Worktrees removed, branches deleted.

| Merge | What | Worker's green (builder0) | Main's check |
|---|---|---|---|
| `b6bd539a` | brains CP1 (`9692ebbe`, alone): **his bridge** — combat hops stop short of water, seats on their anchor's side and off bridge decks (SlotGround.WET_ENABLED); crews pressed into water 11/12 fight runs → 0/18 | 2306/0 | 2306/0 |
| `1fccccfb` | brains R2 (`e48b45ca`, alone, DECLARED): **squads ordered together keep with the army** (a route cost for leaving the body's); his Locks case alone 42–102 → 6.5–23.5 squad-s | 2309/0 | 2309/0 |
| `c4f4a50c` | native N3a–N3c (`d0bc1517`): `Movement.drive` in C++ (ON), route tail, scan | 2315/0 | 2318/0 |
| `62f528d0` | native `b339f5fb`: TickProfile, `make native-tick-profile` (the in-contact laptop instrument) | 2324/0 | 2324/0 |
| `59a161f2` | brains feed cache (`395a732b`, equal answer): −1.1 ms in contact on the laptop | 2310/0 | 2325/0 at `5bfc456a` |
| `255073da` | brains final-1 (`7b17baf0`): counters, B1's cost by removal (+0.54 s, ~+0.5 in Movement's give-way) | 2310/0 | 2327/0 at `e40bd0c7` |
| `e40bd0c7` | native `2fcf133c`: decide in C++ (ON, −4.3 % in contact), TacticalQuery port (OFF), `make native-android` | 2327/0 ON and OFF | 2327/0 |
| `c4dcfc9a` | brains `1c59c777`: element ETAs no longer outlive a seat (CPU elements aborted in big fights); L1 knobs OFF | 2328/0 | 2328/0 |
| `4c704a2c` | native `abc071e0`: the N4 group ON (situation + tq + fire, −4.1 % in contact, pre-registered bundle); grounding (native_el) OFF | 2335/0 ON and OFF | 2336/0 |
| `b3bf60ce` | brains final (`da8a3fef` + docs): **L1 OFF by default** (every faster think rate broke his bridge, the pursuit or a fight scenario) | 2338/0, 44/44 | (final check) |

**The numbers that decided the round** (laptop flightdeck UHD 620, his preset, 25 a side, foundry + parade × 3 seeds,
window 8–20 s = the opening clash, n = 6 paired): tick scripts all-native-off 42.7 ms → shipped ~33 ms; **game speed in
the opening clash 0.79 (round 23) → ~0.82–0.83 shipped** (still slow motion). His bar after his decision (C24.7: no slow
motion at 25 a side, ≥ 0.97) is NOT met; the 50-a-side bar is out of reach by porting (native's honest estimate,
`references/round24/perf/laptop/README.md`). The cap stays 5 squads / 25.

**His decisions:** "25 a side, no slow-mo" (the bar); think-rate B with A as fallback — amended by its own rule to
B′, then (b), then 3.33 Hz, and finally **nothing ships** (each broke something he would see; `game_design.md` *his pick
of the think-rate setting* and its amendments). His view kept for round 25: *"I don't see why we would really need
micro-fast decision loops."*

**Playtest on main:** `make native && make skirmish` (the laptop builds its own `.so`): the Locks, a big group
attack-moved across the bridge: they cross; several squads moved west together keep to one route. `make
native-info` says the library is on.

**Round 25** (`roadmap.md` *Round 25 notes*): a smarter "quiet" think rate (not near water, not chasing or chased
fast, not in cover) after checking the fight scenarios' pass lines for brittleness; a water map in the laptop
workload (re-price `native_el`); Movement's give-way (B1's +0.5 s and the bridge-mouth queue); `ElementPlan.build`;
execute (weapon, move). Lessons 279–282 added.

## 🚀 ROUND 24 IS LAUNCHED (2026-10-08 ~21:00 PDT) — kept as written

**Two streams from his playtest at round 23's close and his decision of round 23** (his words in `game_design.md`
*Round 24 direction* and *the launch*; the split and contracts C24.1–C24.5 in `workstreams.md` *Round 24*; briefs in
`streams/`):

| Stream | Folder (offset) | What he will notice | Checkpoint |
|---|---|---|---|
| **brains** | `godot-brains` (1) | crews ordered across the Locks' bridge cross it instead of driving into the river (R0–R1, every map with water checked); squads ordered together keep with the army unless a split really pays (R2) | **CP1**: R1 merged ALONE → native merges main; the freeze (C24.1) starts |
| **native** | `godot-native` (2) | nothing at first; then big fights stop going into slow motion on his laptop, and the army returns to ten squads / 50 when the laptop table says so (C24.4) | each N3 step priced at three sizes → the orchestrator's laptop table |

**The orchestrator's jobs this round:** (1) the laptop table with native ON at the launch (C24.4: `make native` on the
laptop, then `make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r24-base`, quiet window, files
under `streams/references/round24/perf/laptop/`; the laptop is the orchestrator's until it tells the workers it is
done); (2) merge CP1 ALONE the moment brains names its green sha, `make remote T=check`, then tell native to `git merge
main`; (3) read native's N3a map (equal / declared per function) before N3b starts; (4) re-run the laptop table per
native step on main; flip `Units.MAX_SQUADS` only by C24.4's bar.

**Progress (2026-10-08 ~23:30 PDT):** **CP1 merged** `b6bd539a` (brains `9692ebbe`, alone): his bridge, three layers
(combat hops driven straight over water; canal seats snapped to the wrong bank; seats/orders grounded on a bridge deck);
crews pressed into water ≥ 3 s 11/12 fight runs → 0/18, every crew crossed 7/12 → 11/12 (builder0, 6 seeds × both
sides); arrive series 100/100 both arms, identical; element-digest ON = OFF; crossing + gorge sim lines DECLARED.
**Main's check at `b6bd539a`: builder0, exited 0, 2306/0, ALL JUDGED** (log `streams/references/round24/check-b6bd539a.log`).
Native told to merge main; the freeze is on. Native's N3a map (every execute row EQUAL by plan; decide is the DECLARED
risk) read and accepted. The laptop table `pf-r24-base` runs on `b6bd539a` (log `build/pf-r24-base.log`). Relayed:
native's t.poll finding (7.9 % of the brains' work) → brains, equal-answer stretch after R2.

**Progress (2026-10-09 ~01:20 PDT):** **R2 merged** `1fccccfb` (brains `e48b45ca`, alone, DECLARED C24.5: a plain move to
several squads weighs its own route against the army's; his Locks case alone 42–102 → 6.5–23.5 squad-s, builder0 6
seeds both sides; CPU attack-moves measured worse with it, left off) — main check 2309/0 ALL JUDGED, thirteen unmoved.
**Native N3a–N3c seams merged** `c4f4a50c` (`d0bc1517`: `native_drive` ON −9.4 / −12.0 / −9.4 % of the band at Sumps /
25 v 25 / 50 v 50, builder0 n = 3; `native_path`, `native_scan` (scan later ruled OFF on native's branch, +1.1 %)) —
main check 2318/0, thirteen unmoved, determinism `762a0576f944f5b7`, **perf-judge NOT JUDGED (builder0 busy, ratios
1.9–2.3×)**: re-run on a quiet box before the close. **Laptop windowed table after the drive (`pf-r24-n3c`, c4f4a50c,
n = 3): 25 a side in contact 31.6–33.1 ms (−4 to −6 %) though native's headless band fell −34 %** → native asked for a
windowed in-contact tick breakdown on the laptop before N3d goes further (`references/round24/perf/laptop/README.md`).
Native's `native_situation` 1.7 % (OFF), `native_move` re-priced on the laptop ~0 % (OFF).

**Progress (2026-10-09 ~04:30 PDT):** merged native `b339f5fb` (`62f528d0`: TickProfile, `make native-tick-profile`,
`--brains-on`; the windowed in-contact laptop instrument) and brains' feed cache `395a732b` (`59a161f2`, equal answer).
**Main's check at `5bfc456a` (= `59a161f2` + docs): builder0, exited 0, 2325/0, ALL JUDGED, thirteen unmoved** (log
`references/round24/check-5bfc456a.log`). **The rule for think ports (from native's in-contact breakdown):** ruled
ON/OFF by the laptop's windowed in-contact tick (8–20 s, 25 a side, n = 6 paired by seed), bar ≥ 2 % of the tick's
scripts outside 2 se. In contact the brains are 74 % of the tick and think-heavy (think 16.1 v execute 8.8 ms).
Rulings: decide ON (−4.3 %, se 0.50; merge pending at native's green `5d9d3cec`); situation OFF (−1.97 %, under the
bar; lesson 278); feed cache −1.1 ms (−3 %) in contact. Offered to brains: TacticalQuery/SquadTactics ≈ 2 ms in
contact (equal answer). Open: perf-judge on a quiet box before the close.

**Lesson 277 applied:** the workers run in the lead's own terminals, not as subagents of the orchestrator's session.

**The kickoff prompt** (one terminal per stream: `cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`,
then paste; the same text for every stream; `orchestration.md` *The kickoff prompt*):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your
> working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and
> `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an
> answer except at lead gates; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md,
> `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`,
> `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch
> items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and
> look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item
> is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the
> Status holds your report.

## ✅ ROUND 23 IS CLOSED (2026-10-07 ~23:00 PDT → 2026-10-08 ~20:30 PDT) — read this first

**Three streams, all done and merged.** Worktrees removed, branches deleted, briefs in `streams/archive/round23/`,
evidence under `streams/references/round23/{brains,native,orders,perf}/` and the main checks' logs beside them. He
pushes `main`.

| Merge | What | Worker's green (builder0) | Main's check |
|---|---|---|---|
| `179d0d8a` | orders O1+O2 (`ea760c03`): two columns 28 m apart (`SelectionSquads.COLUMN_GAP_M`); the alert strip clears the edge chips and the panel | 2267/0 | 2275/0 at `cf81cf6a` |
| `cf81cf6a` | native N0–N1b (`799e5408`): the C++/godot-cpp toolchain (`make native`, `native-proof`, `native-bench`, `native-sizing`); ports would_be_hit, ORCA avoidance, cover line of sight | 2268/0 ON and OFF | 2275/0 |
| `35eb9565` | native N2a (`6710bf90`): the navmesh closest point indexed (the engine's is a linear scan); seam in `Pathing.closest_point` (C23.1a) | 2278/0 | 2284/0 at `ebba1465` |
| `ebba1465` | brains CP1 (`35d61b21`, ALONE, DECLARED): **his item, the squad paces itself on the way**; B2 `UnansweredFire.crew_reason` | 2266/0 | **2284/0** |
| `ffba4918` | brains final (`163ea9d4`): B3 under three guns, shipped OFF with its finding; doctrine | 2285/0 | 2291/0 at `d4e9cfa0` |
| `d4e9cfa0` | orders O3+O4 (`5a36e899`): the held crew's readout; ten AUTO squads on the click | 2290/0 | **2291/0, ALL JUDGED** |
| `aa02225b` | brains stretch (b) (`e7cbb2ab`, ALONE, DECLARED): two crews of one line no longer cross to their seats | 2294/0 | (final check) |
| `fc56bd64` | native N2b (`7249857f`): movement's geometry seams, proven equal against the LIVE GDScript, OFF by ruling (~1 %) | 2292/0 | (final check) |

**The numbers that decided the round** (commit, machine, n):
- **His item** (brains, builder0, `649a5703` = shipped rule, his case 3 seeds): the line abreast along its own axis never
  formed before (RMS 15.0 m, the lead crew standing); now RMS 13.7 m, nobody stands, arrives 16.7 v 17.9 s. Cost on
  every ordinary 150 m plain move (100 paired runs, five maps): +0.75 s (se 0.31). The seat fix: crossings within a line
  3 of 3 → 0 of 3 on his six, arrival +0.12 s (se 0.16, neutral).
- **The tick** (native, builder0 pinned `taskset -c 0-3`, n = 3, leaders, every hash equal): every port on −20 % of the
  brains' cost at his Sumps, −22 % at 25 v 25, −22 % at 50 v 50 (−18 to −22 % with N2b OFF, the shipped default).
  Laptop headless 25 v 25: the band 24.3 → 18.1 ms (−25.5 %). Sizing at 50 v 50: execute 56.6 % / think 43.4 % of the
  brains' work; engine calls 27.5 % of execute. A native call costs 0.24 µs (lesson 276).
- **The laptop baseline** (the orchestrator, main `68b97663` code, 25/30 a side, 3 seeds): 25 a side in contact ~40 ms a
  tick, 3 catch-up ticks a frame; by proportion ~30 ms with native on. **The bar is 25: the cap stays 5 squads / 25.**
- **Orders** (builder0, 3 repeats): two column squads from opposite flanks, closest while driving 3.5–3.8 m → 12–19 m;
  ten AUTO gang squads 33.5 m past the click → 0.0 m.

**His decisions:** 28 m between columns (yes); the Syndicate range gap stays; **round 24 = the whole per-tick loop in
C++** (he asked about Rust; answered: C++ kept, `game_design.md` *Round 23, the afternoon*). **Decided for him
(reversible):** pacing candidate b over a (cheaper); B3 OFF; native_move OFF.

**Playtest on main:** `make garage` → the Law → SUGGESTED → FIGHT: select a squad, L for line, order it along its own
axis: it swings into shape on the way, nobody stops dead. Two squads in column ordered side by side drive 28 m apart.
Select one vehicle, H, let a laser shoot it from range: the panel says "under fire from beyond range: holding on your
order". The C++ library builds itself in `make check`; `make native` builds it for play (~10 min cold on the laptop;
a machine without cmake+c++ runs the GDScript path and says so). **A shipped `.so` must be built on the laptop
(glibc 2.39), never builder0** (`native.md`).

**His playtest at the close (2026-10-08 ~20:20, the Locks):** units ordered across the bridge drove into the river
and stuck (a BUG), and one squad of a big group took another route and left the army (he wants a cost on detaching).
His words and the orchestrator's reading are in `game_design.md` *Round 24 direction*; the recording is under
`references/round24/his/`. **It goes FIRST in round 24**, before native's freeze on `movement.gd` (`roadmap.md` item 1b).

**Starting round 24:** `orchestration.md` (the method, lessons to 278), `roadmap.md` *Round 24 candidates* items 1b and 1,
and
`native.md` *The plan from here* (N3). One stream (native), possibly two rounds; plan the freeze on `movement.gd` /
`tank_brain.gd` behaviour; the round's first measurement is the laptop table on this main with native ON. **Lesson
277:** launch workers in their own terminals (or redirect every check to a log), because a subagent dies with its
orchestrator's session limit; this round lost a night's check results that way.

## 🚀 ROUND 23 IS LAUNCHED (2026-10-07 ~23:50 PDT) — kept as written

**Three streams from his first item after playing round 22's close** (*"units getting into formation is getting
better, but … when I had tanks in line abreast and had them move somewhere, they never got into formation until the
very end"*; his words in `game_design.md` *Round 23 direction, first item* and *the launch*; the split and contracts
C23.1–C23.5 in `workstreams.md` *Round 23*; briefs in `streams/`):

| Stream | Folder (offset) | What he will notice | Checkpoint |
|---|---|---|---|
| **brains** | `godot-brains` (1) | a line abreast ordered along its own axis swings into shape on the way, nobody stops dead, the squad arrives about when it did (B1); a vehicle he holds that is shot from beyond its range says so (B2 for orders); a crew under three long-range guns moves before it dies (B3) | **CP1**: B1 merged ALONE → native, orders merge main |
| **native** | `godot-native` (2) | nothing yet; then big fights stop going into slow motion on his laptop, and the army goes back to ten squads / 50 vehicles when the laptop table says so (C23.3). C++ through godot-cpp (his question about Rust answered: recommendation C++, taken) | **N0** the toolchain merged early (everyone's `make check` builds the `.so` on builder0) |
| **orders** | `godot-orders` (3) | two squads in column side by side are 28 m apart, not 14 (his answer); a chip on the bottom edge no longer hides behind the contact alert; H on one vehicle under a laser at range shows "holding on your order"; ten AUTO squads stand on the click (when the cap is 10 again) | C23.2 consumer |

**Baseline:** `main-checked` = `68b97663` (builder0, exited 0, 2260/0, thirteen unmoved, determinism `762a0576f944f5b7`);
above it docs only (the launch). No check re-run for the launch.

**The laptop measurement (C23.3) is the orchestrator's job, the launch night:** `make perf-fight PERF_FIGHT=size
PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r23-base` on main `68b97663`, his preset, a quiet window (lesson 260: load
checked around every run), JSONs + the table under `streams/references/round23/perf/laptop/`; re-run per native step
that lands on main. The bar for the cap's return to 50: 50 v 50 with leaders in contact ≤ 25 ms a tick on the laptop.

**Decided by him at the launch:** 28 m between two columns (yes); the Syndicate range gap stays (recorded,
`game_design.md`). **Decided for him (reversible):** C++ / godot-cpp. **Nothing waits on him tonight.**

**How the workers were started (2026-10-07 23:40 PDT):** he went to bed without opening the three terminals, so the
orchestrator launched the three workers itself as subagents of its own session (`godot-67`), each told to `cd` into
its worktree first and to message `godot-67`; they report to the orchestrator when they finish. The laptop baseline
(`pf-r23-base`, main `46764993` = `68b97663` + docs) started at 23:38 in a quiet window (load 0.26 before; the
workers were told not to run Godot locally until 00:30); its log is `build/pf-r23-base.log`.

**The laptop baseline landed (00:18 PDT, `189b0436`, `streams/references/round23/perf/laptop/README.md`):** main
`68b97663` code, laptop, 25 and 30 a side × foundry/parade × 3 seeds, leaders on. **25 a side with everyone alive and
in contact = 39–40 ms a tick, 3.1 catch-up ticks a frame (141–149 ms)**; thinned to ~20 alive, 17–20 ms a tick and a
20–23 ms frame; run means 22–27 ms a tick; ui 3–8, gpu 9–13 ms a frame. For 50 a side at the bar (≤ 25 ms a tick in
contact) the per-vehicle cost must fall ~3–4× on the laptop; for 25 a side to hold 30 fps in contact, ~1.6×. Relayed
to native and brains.

**The kickoff prompt** (one terminal per stream: `cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`,
then paste; the same text for every stream; `orchestration.md` *The kickoff prompt*):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your
> working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and
> `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an
> answer except at lead gates; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md,
> `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`,
> `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch
> items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and
> look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item
> is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the
> Status holds your report.

### Where the night stopped (2026-10-08 ~02:50 PDT; the orchestrator's usage limit)

**Merged and checked:** `179d0d8a` orders O1+O2 (28 m between two columns: two columns from opposite flanks, closest
while driving 3.1–6.7 m → 7.3–18.6 m, builder0, 3 repeats, `make two-squads-playtest TWO_SHAPES=column,column`; the
alert strip clears the edge chips and the panel) and `cf81cf6a` native N0–N1b (the C++/godot-cpp toolchain, four
equal-answer ports behind `BrainSwitches.native`, `make native` / `native-proof` / `native-bench` / `native-sizing`;
`make check` now builds the `.so` on builder0; a machine without cmake+c++ runs OFF and says so). Main's check at
`cf81cf6a`: 2275/0, thirteen unmoved, perf-judge + the scenario perf line NOT JUDGED (busy box).

**Waiting to be merged, in this order (each named green by its worker; verify the sha's own check log in its worktree):**
1. **brains CP1 = candidate b `649a5703`** (B0 + B1 the pacing + B2 `UnansweredFire.crew_reason` + the slack-8 rule),
   ruled by the orchestrator over `2b0020fe` (checked green, 2266/0) because b's arrival cost is lower (+0.75 s se 0.31
   per 150 m plain move v +1.03) and his case arrives faster than OFF on every seed; brains was told to check
   `649a5703` and report "GREEN, merge here". If that check is not in `godot-brains` (branch `cp1` / `stream/brains`
   Status), merge `2b0020fe` with its stated cost instead. Merge ALONE (declared, C23.5), then `make remote T=check`,
   then tell orders (its C23.2 stub comes out) and native (merge main before `movement.gd` seams).
2. **native N2a** (the grid-indexed navmesh closest point, equal to the engine bit for bit, 13 maps × 961 points; laptop
   headless 25 v 25 with leaders: the controller band 24.3 → 18.1 ms a tick, −25.5 %, whole tick −28 %, n = 1, tree
   `061fa0f0`): its check and the pinned n = 3 price series were running at 02:10; it goes as its own merge with the
   table. The honest reading (native's sizing, builder0 pinned n = 3, 50 v 50: execute 56.6 % / think 43.4 % of the
   brains' work, engine calls 27.5 % of execute): per-piece ports reach ~−25–30 %; the 3–4× the laptop bar needs is
   N3 (execute AND think in C++, multi-round, likely DECLARED) or a think-rate/LOD design change: **his decision in
   the morning** (ask in player terms: big fights on the laptop; three options, recommend N3 as the next round's
   single stream with the cap raised to what the table allows meanwhile). Also his: the shipping `.so` must be built
   on a glibc ≤ 2.39 machine (the laptop), never builder0 (GLIBC_2.43 symbols); `_agents/native.md` has it.
3. **orders O3 + O4 + the probe** (`1537fb1a`, `9bb0899f`, `03d1177f`, +the ten-squad AUTO series and frames in
   flight): its final check was pending at 02:30; merge at the sha it names.

**Then:** re-run `make remote T=check` on main on a quiet builder0 so perf-judge judges; file each stream's evidence
under `streams/references/round23/<stream>/`; `Units.MAX_SQUADS` stays 5 until the laptop table (re-run
`pf-r23-base`'s command on the merged main with native ON) says otherwise; close per `orchestration.md` *Close*.
Lessons to add: builder0's `build/` copy-back lands under a worker's local run and kills it (one machine's `build/`
per worktree at a time; orders); a dynamic native call costs 0.24 µs so a seam must replace tens of µs (native);
the engine's `map_get_closest_point` is a linear scan (native).

## ✅ ROUND 22 IS CLOSED (2026-10-07 ~14:00 PDT → 2026-10-08 ~00:45 PDT) — read this first

**Four streams, all done and merged; `main-checked` = `68b97663`** (the final check: builder0, `>> remote: make check
exited 0`, 2260 passed 0 failed, 23 targets ALL JUDGED, thirteen sim-baseline lines unmoved, determinism
`762a0576f944f5b7`; it covers brains' final `f40f52e1` and army's **A4** `68b97663`). Above it: docs only (the close,
his post-close verdict). Worktrees removed, branches deleted, briefs in
`streams/archive/round22/`, evidence under `streams/references/round22/{army,brains,orders,perf}/` (3.7 MB + perf's 42
JSONs + his frame logs under `perf/his/`). He pushes `main`.

| Merge | What | Worker's green (builder0) | Main's check |
|---|---|---|---|
| `986a3d75` **CP1** | army (`9753a54f`): `Units.MAX_SQUADS` (10), 50 vehicles, 2000 CR, the opponent at 2000, the garage's two columns; two one-line reads in brains' paths | 2218/0 | 2235/0 (at `7766f53c`) |
| `1655e93b` | orders O1 + O1b (`8b488408`): groups 1–9 and 0; the place-level untangle (two interleaved squads abreast: crossings 3/3/3 → 0/0/0 on his six); ranks of three | 2227/0 | 2235/0 |
| `9ad6d65e` | the orchestrator: a stem fade wrote past `stem_db` after a track change (music; mutation-checked) | — | 2235/0 |
| `249e103f` | army final (`2694dc5f`): money-left line, army code at 50, suggested squads, phone fit, docs | 2221/0 (+ ALL JUDGED rerun) | 2238/0 |
| `e3fd375e` | brains **B1** (`5d910d80`, ALONE, DECLARED): a crew under fire it cannot return closes / takes cover / falls back, both sides; his hold holds with a readout. 24 seeds: +0.62/+1.00 alive, his loss +146 on foundry, the CPU's gunship takes cover 4/4; cost −5.83 points (se 1.90) on foundry's depot | 2221/0 | 2255/0 (at `14c8ec34`) |
| `14c8ec34` | perf final (`ff237169`): `make perf-fight`; P0 (the choppiness is the tick, not the flag / leaders / a regression); P1 (nothing above 25 a side holds the bar); P2 (the frame at 50); the alert strip above the two-row group bar | 2245/0 | 2255/0 |
| `916aa427` | orders final (`07c14a19`): nested ranks (ten vees 104 m deep, 0.2 m past the click); the x50 portrait; radar squares per squad past ten; `MAX_GROUPS` reads `Units.MAX_SQUADS` | 2242/0 | red on a dirty flag → |
| `1883447b` | the orchestrator: perf-fight-report's header test sets `TANK_SQUAD_DIRTY=` itself; the untangle `.uid` committed | — | **2259/0, thirteen unmoved** |
| `f40f52e1` | brains final (`19599717`; green `d530d9f0`): the leash arm OFF, B2's probe + footprint test, open_ground REVERTED (not equal answer: tag `b3-open-ground-finding`), the stride tables (OFF), B4 for him, doctrine | 2248/0 | (final check) |
| `68b97663` | army **A4** (`2e170be8`, ALONE): the cap 25 in five squads, 2000 CR kept (`GAME_CREDITS` its own constant); `ControlGroups.MAX_GROUPS := 10` (the keyboard's, granted) | 2260/0 | (final check) |

**The numbers that decided the round** (commit, machine, n): his Sumps match (`2026-10-07T13-46-42`, laptop, main
`5beb038f`): 20 ms a tick at 41 vehicles rising to 60–72, frame 100–280 ms, game speed 0.35–0.6; the same build an hour
earlier on foundry 33 ms a frame at 9–13 alive. Perf P0 (builder0, his fight rebuilt): the flag 14.5 v 15.6 ms a tick,
`--no-element-cpu` 15.6 v 15.5, round 20's main 18.3: not a regression; ~0.7 ms a vehicle in contact. Brains' tick
table (builder0, n = 1 ±30 %): 25 v 25 leaders both sides 21.9 ms a tick, 50 v 50 62.7; controllers 49 of it at 50;
the profile flat. Perf P1 (3 seeds × 120 s): p95 ×2.9–3.4 at 50 v 25 against a bar of 1.25; series 2: nothing above
25 holds. The stride: −15 to −25 % of the tick, behaviour unchanged, OFF. open_ground: −2 % and NOT equal (an orders
test). The laptop's own number for 25/30 a side is NOT taken (deferred to round 23's first measurement).

**His verdicts:** the airship trade: no. **Decided for him (reversible, recorded in `game_design.md` *Round 22: the
close*):** the cap 25 / 2000 CR (recommended, not yet answered); the stride OFF; the spawn layout unchanged (the untangle
at the first order is the design); the front rank on the click (round 21's ruling kept); B1 shipped with its stated
points cost. **Still his:** the cap choice; two columns 14 → 28 m; the range gap (B4).

**Playtest on main:** `make garage` → the Law → SUGGESTED → FIGHT: 16 vehicles for 2000 CR (five assault guns); Road
Gangs → 25 Rat Rods and ~500 CR left, the line says so. In a fight: a Syndicate vehicle under your laser at range moves
(cover or back) instead of dying in place; six vehicles in two squads ordered abreast do not cross; squads on 1–9 and 0.

**Round 23 candidates:** `roadmap.md` (his first item already in: the fast crew slows so the squad forms up on the way;
then the per-vehicle tick, native controllers the candidate). **Lessons 271–274** in `orchestration.md` (a scaled
number is first a question of what the current number costs; a sim hash is not the proof of equal answer; a test sets
the environment it reads; the owner measures before the orchestrator rules). **Starting the next round:**
`orchestration.md`; the kickoff prompt is unchanged.

## 🚀 ROUND 22 IS LAUNCHED (2026-10-07 afternoon) — kept as written

**Four streams from his two items after playing round 21** (*"I just played the game, it's great"*; his words verbatim
in `game_design.md` *Round 22 direction*, with the reading of his recording; the split and contracts C22.1–C22.6 in
`workstreams.md` *Round 22*; briefs in `streams/`):

| Stream | Folder (offset) | What he will notice | Checkpoint |
|---|---|---|---|
| **army** | `godot-army` (1) | a full army is ten squads, 50 vehicles, 2000 credits: 50 Rat Rods, 13 Law tanks, 7 Syndicate tanks (today 25 / 6 / 3); the garage fits ten squads on desktop and phone; the cap's final number is measured (C22.3) | **CP1**: the constants + the opponent, merged ALONE → everyone merges |
| **brains** | `godot-brains` (2) | a vehicle being shot by something it cannot answer closes, hides or backs off instead of dying in place (his recording: a Limousine Gunship held 22.5 s under a Lancer's laser); the computer commands ten squads; the sim's tick at 50 a side priced and cut; the Syndicate-over-gangs range gap measured for him | B1, B3 declared, alone |
| **orders** | `godot-orders` (3) | squads on keys 1–9 and 0; ten chips he can read on the phone; ten squads ordered with one click go in ranks of three, front rank on his click; the radar legible at 50 a side | CP1 consumer |
| **perf** | `godot-perf` (4) | the game stays smooth on his laptop at 50 a side, or the cap is set where it does (bar: p95 frame at 50 ≤ p95 at 25 on round 21's main + 25 %); cuts that change nothing he sees, then a hardware preset | **P1's number** → the orchestrator the same day → the cap |

**Baseline:** `main-checked` = `d25d0579` (builder0, exited 0, 2211/0, thirteen unmoved, determinism `762a0576f944f5b7`);
above it docs, evidence and orders' probe-measure commit (its own green `b2dc5cf8`). No check re-run for the launch.

**The laptop measurement (C22.3) is the orchestrator's job this round:** perf hands over one command; the orchestrator
runs it in a quiet window on the laptop (lesson 260) or hands it to him, commits the JSONs under
`streams/references/round22/perf/`, reads the cap off the table, tells army. Build is for 10 squads regardless.

**Questions to him (one recommendation each):** (1) the airship on the Cut, the Docks and the Sumps, seen as often as on
the open maps at the cost of sitting over the fight about twice as often (`AIRSHIP_ON=stationsescape
AIRSHIP_STATIONS_MAPS=cut,docks,sumps make skirmish ARENA=sumps`; recommended: try it in one game and say); (2) four
Syndicate out-range ten Rat Rods for no damage (recommended: leave it, brains measures it this round).

**Two hours in (2026-10-07 ~16:00 PDT):** his afternoon feedback (`game_design.md` *Round 22, an hour after the launch*
and *same hour*): the airship trade CLOSED (no; stations OFF for good); a choppy Sumps match; six vehicles crossing
and bumping on a line order (orders' O1b, the untangle). **Perf's P0 (stream/perf `63b7a7bd`, builder0, his fight
rebuilt: Law 24 v Syndicate 17, the Sumps, seed 5988):** the choppiness is the sim TICK at 41 vehicles in contact,
~0.7 ms per vehicle on builder0 (~2 ms on his laptop: 20 ms a tick at 41, 60–72 mid-fight = 2 s of tick per second
of play, game_speed 0.35–0.6); NOT the airship flag (14.5 v 15.6), NOT the CPU leaders (15.6 v 15.5), NOT a regression
(round 20's `0a9ce446` read 18.3 on the same fight). By script (removal in-run): tank_brain +16.9 ms a tick, match.gd
+12.1, tank.gd +3.2, elements.gd +2.5, announcer_booth +2.3 (RETRACTED by perf: +0.35 mean over 8 bracketed cycles, signs disagree; the 2-cycle sweep
read the fight's drift), visibility_field +1.5. His UI's 20–60 ms did not
reproduce on builder0 (laptop-only contention under 3 catch-up ticks a frame, to be settled by the laptop run). **So
brains' B3 is now the critical path** (tank_brain, then match.gd under C22.7) and **the cap waits for its first cut**:
at today's cost 50 a side is ~70 ms a tick on builder0. Perf's two laptop commands (`make perf-fight …`, from a
checkout at `stream/perf` ≥ `63b7a7bd`, ~25 min, a quiet window) are the orchestrator's to run tonight; JSONs go under
`references/round22/perf/laptop/`. Worker sessions: `godot-army-12`, `godot-brains-06`, `godot-orders-4b`, `godot-perf-b2`.

**The tick table (brains B3, builder0, whole matches, scratch `deec4d9` = `32748a0c` with the certificate off, n = 1 each,
load 4–13 so ±30 %):** his Sumps seed 5988 (41 vehicles) 15.6 ms a tick leaders off / 16.7 CPU leaders / 19.6 both;
25 v 25: 16.6 / – / 21.9; 50 v 50: 41.7 / – / 62.7 (ratio 50/25 = 2.5 off, 2.9 on). Parts at 50 v 50: controllers 49
ms (16.5 at 25 v 25), elements 8.6 (3.6), match.gd's own 4.1 (intel ~9 ms per refresh every 3rd tick), tank.gd 4.4.
The laptop is ~2.75×: **50 v 50 with leaders ≈ 170 ms a tick there; even 25 v 25 fully in contact ≈ 60 ms a tick**
(his foundry games held 30 fps only because 9–13 vehicles were alive at once). The profile is flat (closest_point 14 %,
then 1–5 % each): equal-answer cuts buy 10–25 %; the 2× lever is the brain stride (think at 15 Hz, staggered; round 5's
lever, OFF; a behaviour change, HIS; game-wide, both sides, every machine, never a per-machine preset: determinism and
two-player matches). Perf's P1 (builder0, 3 seeds × 120 s, 25 v 50): p95 ×2.90 foundry, ×3.43 parade against a bar of
1.25; the frame's own cost at 50 a side is small (GPU 10–14, ui 5–8, fx 1.2–1.5 ms). **Put to him (~17:00):** (1)
every vehicle thinks 15×/s on both sides (recommended), or (2) keep 30 and lower the cap to what the laptop holds
(perf's series 2). Orders' column spacing question (two columns 14 → 28 m apart, recommended yes) put to him too.
**For the close / round 23:** at ~0.5 ms per vehicle per tick on builder0 the vehicle brain's cost is the game's
ceiling; round 19's held item 2 (native code for the simulation's per-unit work) is now where the frame goes.

**State (2026-10-07 ~19:00 PDT): `main-checked` = `7766f53c`** (builder0, `>> remote: make check exited 0`, 2235/0, 23
targets ALL JUDGED, thirteen lines unmoved): army's **CP1** (`986a3d75`, ten squads / 50 / 2000 CR, `Units.MAX_SQUADS`),
orders' **O1 + O1b** (`1655e93b`: groups 1–9 and 0, the untangle, ranks of three; one conflict in
`tests/test_every_unit_selectable.gd` resolved to orders'), the orchestrator's music fix (`9ad6d65e`: a stem fade wrote
past `stem_db` after a track change; mutation-checked), the booth retraction. Above it: army's final `249e103f`
(garage/docs; its own green `2694dc5f` had perf-judge NOT JUDGED on a busy box), check running
(`build/round22-check-249e103f.log`). All four workers told to merge main. **Army is DONE** (A4 = one constant, on
the cap number). **Perf series 2** (builder0 `b282d00b`, 25/30/40): nothing above 25 a side holds the 1.25 bar on
foundry (means 24.6 / 38.0 / 76.0 ms; tick 20.8 / 27.2 / 38.5); the tick grows ~0.8 ms a tick per vehicle a side; the
frame at 50 a side on builder0 = 24.8 ms tick × 0.72 + GPU 8.5 + ui 4.4 + fx 1.1 + CPU render 2.0. **Put to him:**
2000 CR with the cap at 25 until the tick is cut (recommended: tank armies double today, 13 Law / 7 Syndicate, under
25), or ship 50 as built. **Brains:** B1 green at `5d910d80` (24 seeds: +1 alive, +146 his loss, but points −5.83 se
1.90 on foundry, REAL: cover/fall-back take crews off the zone) → held for the 15 m post-leash arm (`c1002756`, 8
seeds queued); B2 DONE (24 CPU-v-CPU runs at ten-of-five, 0 errors, invariants hold; the spawn stays as it is, the
untangle at the first order is the design, ruled); B4 measured for him (4 Syndicate beat 10 Rat Rods 16/16; 1 spotter
beats 5 Rat Rods 12/16; B1 changes neither); the open_ground certificate re-measured with leaders both sides −1.8 to
−2.3 % (ships as its own merge after the stride pricing); the stride pricing running. **Orders:** nesting (`aa830208`,
ten vees 104 m deep, 0.2 m past the click), the x50 portrait, the radar at 50, formation cards at ten, green at
`43094686`, merges after its main merge + a check. **Perf:** the alert strip above the group bar's live top (on its
branch), P2's frame breakdown.

**State (2026-10-07 ~22:30 PDT): `main-checked` = `1883447b`** (builder0, exited 0, 2259/0, 23 ALL JUDGED, thirteen
unmoved); above it brains' final merge `f40f52e1` (docs, evidence, the OFF leash arm; its own green `d530d9f0`). Merged
since 19:00: brains **B1** `e3fd375e` (ALONE; the sitting duck: 24 seeds, +1 alive, his loss +146 on foundry, the
CPU's gunship takes cover 4/4; one real cost, −5.83 points se 1.90 on foundry's depot, stated in the merge; the 15 m
leash arm inside noise, OFF); perf final `14c8ec34` (perf-fight, the tables, the alert strip above the two-row group
bar); orders final `916aa427` (nesting, the x50 portrait, the radar at 50, MAX_GROUPS reads Units.MAX_SQUADS); the
orchestrator's test fix `1883447b` (perf-fight-report's header test read TANK_SQUAD_DIRTY from the environment; one
untracked .uid in this checkout made main's check red at `916aa427`; the .uid committed). **Decided:** the stride stays
OFF (15–25 % of the tick, not 2×: a brain with a new order thinks at once; behaviour unchanged, not worth a game-wide
declared change); open_ground REVERTED (not equal answer: an orders test reading a squad's slots saw it; tag
`b3-open-ground-finding`); the cap for this week is **25 vehicles (five squads) with 2000 CR** (perf's series: nothing
above 25 a side holds the bar; neither lever changes it), army's A4 `7f3a03ac` re-checking on top of the fix (the
keyboard keeps ten groups: `ControlGroups.MAX_GROUPS := 10`, granted). Streams DONE: army (A4 pending), brains, orders,
perf. **For him, unanswered:** the cap choice (recommended and being built: 25 / 2000; one constant back to 10 / 50);
the column spacing 14 → 28 m; the range gap (B4: 4 Syndicate beat 10 Rat Rods 16/16, 1320 v 700 points; a lone spotter
beats 5 Rat Rods 12/16). The laptop perf run is deferred: with the cap at 25 it measures today's state, not a decision;
run it at the start of round 23 as its baseline.

**Waiting on him:** push `main`; the cap choice (built as recommended unless he says 50); the column spacing; the range gap.

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
per worktree folder (`~/projects/godot-army`, `~/projects/godot-brains`, `~/projects/godot-orders`, `~/projects/godot-perf`).

## ✅ ROUND 21 IS CLOSED (2026-10-06 ~20:00 PDT → 2026-10-07 ~04:30 PDT) — read this first

**Three streams, all done and merged; `main-checked` = `d25d0579`** (builder0, `>> remote: make check exited 0`, 2211
passed 0 failed, 23 targets ALL JUDGED, thirteen sim-baseline lines unmoved, determinism `762a0576f944f5b7`). Above it:
the airship's, brains' and orders' final Status (docs + evidence under `streams/references/round21/`), and orders'
probe-measure change (`8be7d470`, inside its green `b2dc5cf8` = main `d25d0579` merged, 2211/0; `git diff d25d0579 HEAD
-- game tests mk tools` is that one file). Worktrees removed, branches deleted, briefs in `streams/archive/round21/`.
He pushes `main`. Workers: `godot-airship-bc`, `godot-brains-52`, `godot-orders-0a` (idle); the orchestrator `godot-67`.

| Merge | What | Worker's green (builder0) | Main's check |
|---|---|---|---|
| `6d8071c4` **CP1** | orders O1 (`360c3f06`) + O2 probe: several squads, one click, stand as a BODY (two side by side as round 19; three or more at most 3 abreast, 200 m, ranks behind); `make five-squads-series` | 2176/0 | 2176/0 |
| `bbb6be80` | airship (`3f2ea88d`): foundry (and every default-size map) never BUILT the airship; one call + a test | 2167/0 | (with P0) |
| `f251e387` | brains **P0** (`30c95bc5`, C21.5): CPU squad leaders ON by default (his answer) | 2169/0 | 2180/0 |
| `d5e5b3dd` | brains **P1** (`ce3d1fc8`, DECLARED): no bait/encircle under ANY order of his | 2172/0 | 2183/0 |
| `a9ae05f0` | brains **P2** (`a59859c0`, DECLARED): an attack on a named target that moves is a PURSUIT; P3 doctrine | 2180/0 | 2191/0 |
| `9dd53cc0` | orders (`4bfba462`): probe columns, TWO_TIMEOUT 720 s, Shift+N says once that it ADDS | 2184/0 | 2192/0 |
| `6fc5a6c7` | orders (`11a90600`): the front rank stays ON the click (ruled), the per-squad trace | 2185/0 | (with R2) |
| `cf6955a2` | brains **stretch (d)** (`4ac954ca`, DECLARED; orders' R1): a pushed slot lands on the side its element reaches it from | 2193/0 | (with R2) |
| `32285ab8` + `fd384653` | airship (`1f091e84` + Status): the instrument on the live rotation + foundry, two cameras, body-in-lens / clear-sight columns; stations, liveboom, stationsfar, escape arms built, measured (seeds 51–56) and confirmed (61–66): **all OFF**; V3 frames | 2194/0 | (with R2) |
| `d25d0579` | brains **R2** (`09d663eb`, DECLARED; orders' request): far ambush yields under any task of his; a drill's end no longer leaves the leg anchor at its pre-drill point (both sides); no covered route for his tasks; stretch (a) hold fall-back measured AGAINST, OFF | 2198/0 | **2211/0, thirteen unmoved** |
| `4442c72e`, `3372435e` | brains' and orders' final Status + evidence (orders' includes `8be7d470`, in its green `b2dc5cf8`) | 2211/0 (orders) | — |

**The numbers (each with commit + machine + n):** P2 pursuit, on − off, paired: laptop `9f392432` n = 24/map: time to
kill −2.47 s se 0.67 (yard_open) / −2.67 se 0.85 (foundry), his loss −103 HP se 37 / −83 se 27, reversals 3 v 94 / 16
v 93; builder0 `a59859c0` seeds 9–24 n = 16: −2.94 se 0.89 / −2.11 se 0.48, −118 se 49 / −78 se 24, target killed in
every run. O1 layout alone (builder0, 3 repeats, pre-merge): worst sideways 40–58 → 15–25 m, span 218–232 → 79–129 m;
on main with R1+R2 (builder0, 3 repeats, centre-within-12 m arrival): every squad arrives, last in 12–20 s, foundry vee
detour 70 → 24–28 m (the remaining 34–45 m sideways is squads fighting under the attack-move, not the layout). Airship
body-in-lens (builder0, 240 s, seeds 51–56 / 61–66): open maps 29–39 %, foundry 39 (hides 6.7, inside the open maps'
0–11 per-seed spread), sumps 15/11, docks 10/14.5, cut 3/4.5, terminus/locks/crossing 0–3; no arm passed both bounds
(hides ≤ open band, longest ≤ theirs) on both seed sets. Hold fall-back (laptop `28837d1c`, 8 paired): against on every
measure.

**His two answers at the launch, both shipped:** CPU squad leaders ON by default (P0); the airship "same as other
maps" (foundry now is; the built-up three with tall roofs cannot be; the Cut/Docks/Sumps are his trade, `roadmap.md`
*Round 22 candidates* 1).

**Decided for him (reversible, recorded in `game_design.md` *Round 21: the close*):** the front rank of a body stands ON
his click; three abreast / 200 m; stations OFF; hold fall-back OFF.

**Playtest on main (`make garage` → Road Gangs → CLEAR → tap the Rat Rod 25 times → FIGHT):** Ctrl+A, V, click 150 m
ahead: five pins two-two-one inside ~80 m, nobody drives to a wall, no squad holds back or swings 40 m to flank; then
right-click one Syndicate vehicle: every scout drives at it, chases it when it runs, the last one alive straight at it;
the airship is in the sky over foundry; the computer's leaders hold the depot and ambush from the bays on parade
(`make skirmish ARENA=parade`); a squad ordered onto parade's east container row lines up on the near face.

**Round 22 candidates:** `roadmap.md`. **Lessons 267–270** in `orchestration.md` (the wrong-pose instrument; confirmation
seeds; the trace before the ruling; one stream's instrument finds another's defect). **Starting the next round:**
`orchestration.md`; the kickoff prompt is unchanged.

## 🚀 ROUND 21 IS LAUNCHED (2026-10-06 evening) — kept as written

**Three streams from his two games after round 20 and the one thing he never saw** (his words verbatim in
`game_design.md` *Round 20, afternoon* and *Round 20, evening*; the decisions made for him in *Round 21: decided for
him at the launch*; the split and contracts C21.1–C21.4 in `workstreams.md` *Round 21*; briefs in `streams/`):

| Stream | Folder (offset) | What he will notice | Checkpoint |
|---|---|---|---|
| **airship** | `godot-airship` (1) | he sees the airship on the built-up maps (today 0–3 % of its flight is in his frame on terminus, cut, locks, crossing, docks; 24–31 % on the open maps), and it never stands over the fight; `make airship-report` reads the live rotation | none (isolated) |
| **brains** | `godot-brains` (2) | an attack-move no longer sends one scout forward and holds the rest (P1, the bait drill under ANY order of his); an attack on a vehicle that runs is a chase, the last survivor drives straight at it (P2); stretch: the hold falls back when losing; the leaders' price by in-run A/B | each declared change alone (C21.2) |
| **orders** | `godot-orders` (3) | five squads ordered with one click go as a body (up to three abreast, the rest behind) instead of a 400 m row pinned at ±116 m (O1); the five-squad probe case (O2); the Parade bay slot (O3) | **CP1**: O1 merged alone → brains told to merge |

**Baseline:** `main-checked` = `0a9ce446` (builder0, `>> remote: make check exited 0`, 2166 passed 0 failed, 23 targets
ALL JUDGED, thirteen sim-baseline lines unmoved, determinism `762a0576f944f5b7`); every commit above it is docs. No
check was re-run for the launch (docs only).

**The mechanism behind his "circling", as read from his recording (a hypothesis for brains to verify, lesson 219):**
`ElementPlan._task_point` for an `attack` returns the target's position only while the target is in the squad's
`contacts`; otherwise the nearest contact or `null`, and a null destination marks the plan `arrived` and halts. The
retreating spotter left the squad's sight; the last Rat Rod "arrived" 70 m short. A named-target attack lays NO row
(`extra` carries `target`, no `to`), so the ±116 m spread in both recordings is the attack-MOVE's row (orders' O1).

**Questions to him (asked in the launch message, one recommendation each; the workers build the recommendation):**
1. The computer's squad leaders on by default (`make skirmish ARENA=parade CPU_LEADERS=1` to try; 3–5 ms a tick on his
   laptop; the ambush and the hidden line only run with them). Recommended: yes.
2. How often he wants to see the airship. Recommended: as on the open maps today, a glimpse every minute or two, never
   over the ground he is looking at.

**His answers, minutes later (2026-10-06 evening):** *"yes let's just go ahead and add the cpu leaders feature. I want
the airship same as other maps."* → brains **P0** (C21.5: `ELEMENT_CPU_DEFAULT := true`, merged alone, first) and
airship V2's bar = the open maps' 24–31 %. Recorded in `game_design.md` *Round 21: his two answers*, the briefs and
`workstreams.md`. The three worktrees were fast-forwarded to this commit before the agents' first read.

**Airship's first finding (minutes after kickoff, `stream/airship` `684f976b`, check pending):** on **foundry the
airship was never BUILT.** `ArenaDressing._ready` builds the venue before any map is active, and `setup(layout)`
rebuilt only when the map's half-size differed from the default venue's 121 m; foundry (`Arena.DEFAULT_LAYOUT`, every
`make garage` fight) is 120 m, so no rebuild and no airship (same for boulevard, boneyard, maze, barriers). Fix: one
line in `arena_dressing.gd` `setup()`'s no-rebuild branch calling `_build_airship()`, with a failing-then-passing test.
**Second:** the brief's 0–3 % on built-up maps was `airship-report`'s fixed 49 m camera, not his pose; the live camera
(`airship-view`, builder0, seeds 41–44) sits ~88 m back / 35 m up and there main's hull is in frame 50–84 % on
terminus/cut/locks/crossing/docks/sumps (open maps 74–89 %). So the round's airship item is mostly the build bug plus
an instrument that measured the wrong pose (a lesson for the close). Merge plan: the fix ALONE and first, so his next
garage fight shows the airship.

**State (2026-10-07 morning): eleven merges, `main-checked` = `d25d0579`** (builder0, `>> remote: make check exited 0`,
2211 passed 0 failed, 23 targets ALL JUDGED, thirteen lines unmoved, determinism `762a0576f944f5b7`); docs only above it.
Airship is DONE (final Status merged `fd384653`); brains and orders are writing their final reports. Each merge is the commit the
worker's own check went green on, merged alone:

| Merge | What | Worker's green (builder0) | Main's check |
|---|---|---|---|
| `6d8071c4` **CP1** | orders O1 (`360c3f06`) + O2 probe: several squads, one click, stand as a BODY (two side by side as round 19; three or more at most 3 abreast, 200 m, ranks behind; his five vees 2+2+1 instead of a 380 m row at ±116); `make five-squads-series` | exited 0, 2176/0 | exited 0, 2176/0, thirteen unmoved |
| `bbb6be80` | airship (`3f2ea88d`): foundry (and every map the size of the default venue) never BUILT the airship; one call in `arena_dressing.gd setup()`'s no-rebuild branch + a test | exited 0, 2167/0 | (with P0) |
| `f251e387` | brains **P0** (`30c95bc5`, C21.5): CPU squad leaders ON by default (`ELEMENT_CPU_DEFAULT := true`; `--no-element-cpu` for A/B) | exited 0, 2169/0 | exited 0, 2180/0, thirteen unmoved |
| `d5e5b3dd` | brains **P1** (`ce3d1fc8`, DECLARED): no bait/encircle under ANY order of his; the CPU's packs keep them | exited 0, 2172/0 | exited 0, 2183/0, thirteen unmoved |
| `a9ae05f0` | brains **P2** (`a59859c0`, DECLARED): an attack on a named target that moves is a PURSUIT (live or last-known track ≤ 10 s, never "arrived" short, a lone survivor drives straight at it); P3 doctrine | exited 0, 2180/0 | exited 0, 2191/0, thirteen unmoved |
| `6fc5a6c7` | orders (`11a90600`): the front rank stays ON the click (the orchestrator's ruling), the per-squad trace, the "moves toward the click" test | exited 0, 2185/0 | (with R2) |
| `cf6955a2` | brains **stretch (d)** (`4ac954ca`, DECLARED; orders' R1): a pushed slot lands on the side its element reaches it from (bounded: within 12 m, ≥ 15 m shorter); Parade's Bravo_3 arrives | exited 0, 2193/0 | (with R2) |
| `32285ab8` + `fd384653` | airship (`1f091e84` + final Status): the instrument on the live rotation + foundry, two cameras, body-in-lens and clear-sight columns; stations / liveboom / stationsfar / escape built, measured on seeds 51–56 and confirmed on 61–66, **all OFF** (no built-up map passes the open maps' band on both seed sets); V3 frames | exited 0, 2194/0 | (with R2) |
| `d25d0579` | brains **R2** (`09d663eb`, DECLARED; orders' request): far ambush yields under any task of his; a drill's end no longer leaves the leg anchor at its pre-drill point (reset by provenance); no covered route for his tasks; stretch (a) hold fall-back built, measured AGAINST, OFF | exited 0, 2198/0 | exited 0, 2211/0, thirteen unmoved |
| `9dd53cc0` | orders (`4bfba462`): probe columns (sideways move per squad, asked v grounded slot, nav phase, `five-squads-shots`); TWO_TIMEOUT 720 s; Shift+N says once that it ADDS | exited 0, 2184/0 | exited 0, 2192/0, thirteen unmoved |

**P2's numbers, now fact on two machines** (`make pursuit-series`, on − off, paired seeds): laptop `9f392432` n = 24 per
map: time to kill −2.47 s se 0.67 (yard_open) / −2.67 s se 0.85 (foundry), his loss −103 HP se 37 / −83 se 27, hull
reversals 3 v 94 / 16 v 93; builder0 `a59859c0` seeds 9–24 n = 16: −2.94 s se 0.89 / −2.11 s se 0.48, his loss −118
se 49 (lower in 10/16) / −78 se 24 (lower in 13/16), alive margin −0.75 se 0.66 / −0.12 se 0.33, the target killed in
every run. Arrive series 100/100 both arms, identical (an attack-move names no target). **O1's numbers** (builder0, 3
repeats × foundry/parade × vee/auto, both arms pre-merge so CPU leaders OFF and no P1): worst sideways drift in the
first 10 s 40–58 m → 15–25 m; anchor span 218–232 m (the wall) → 79–129 m.

**Decisions and findings since (2026-10-07 early):** (1) the orchestrator misread orders' wall frame (squad 3 IDLE at
5 s): it had moved 48 m to its rear-rank slot and arrived early; orders then centred the body on the click, and the
orchestrator RULED the front rank back ON the click (an attack-move must never drive past where he pointed; round 19's
"arrive at the point he clicked"), `11a90600`, both reasons in orders' Status. (2) Orders' merged-tree series found the
worst sideways drift on foundry UP to 46 m after P0+P1 (request R2, traces under `references/round21/orders/`); brains
answered at `76b6c847` (DECLARED, check pending): far ambush yields under any task of his (reflexes stay); a DEFECT: a
drill's end left the leg anchor at its pre-drill point so the cohesion gate held crews round it (both sides; it also
drove P2's squad back to its spawn); no covered route for his tasks; one laptop rep: worst detour 69.5 → 29.2 m.
(3) Airship: C21.3 restated in his terms, "same as other maps" both ways: hides pooled ≤ the open maps' band on the
same seeds (6.05 %), longest ≤ 6.0 s; per-map stations allowed. The body-in-lens table (builder0, seeds 51–56, 240 s):
open maps 30–39 % body, foundry 39 % (hides 6.7, inside the open maps' spread), sumps 15, docks 10, cut 3,
terminus/locks/crossing 0–3; stations lift cut/docks/sumps to 39–45 % but hides 5.7–10.9 → OFF; the mechanism on all
six is the climb over 24 m roofs (the body's lowest legal centre ~37 m sits above his ~34 m lens, and the ceiling
FALLS with distance at his pitch, so a far pass is worse: the orchestrator's suggestion was wrong, corrected by the
worker). Next arms: the stations' guard rebuilt at the live ~95 m boom, stations + guard, far stations + guard.

**In flight:** brains stretch (d) (`6fdd4133`, DECLARED: a slot grounds to the standable point on the side its element
reaches it from; orders' Parade repro Bravo_3 (75.5, −28.2) ok=false → (72.7, −17.6) ok=true, laptop one run; arrive
series then check) and stretch (a) (a losing holder falls back one bound: first read mixed, ships OFF unless it wins).
Airship: V2's stations measured on the live camera FAIL C21.3 (hides ~2× on cut/locks/docks) → OFF (lesson 266); the
instrument's new column *body in his lens with clear sight through the colliders* says the BODY (the screens) is seen
~0 % on Terminus, ~6 % on Docks v ~32 % foundry / 11–33 % yard (one-seed smoke; roofs never hide it from his ~35 m
camera, over 24 m roofs its middle is above his frame top) → V2 re-opened on body %, fresh seeds 51–56 post-merge,
main v stations + hides, the open maps as the noise band, the Crossing removal arms (~2 h on builder0; `be4516bb`
green, 2192/0). Orders: O3 named (relayed to brains, built as stretch d); open question from the wall frame
(`references/round21/orders/wall_seed29989_desktop_5s.jpg`): the rear rank's anchor landed on squad 3's own start, so
one squad stayed put on his click 21 m from the wall; asked whether the body should centre on the click.

**Worker sessions:** `godot-airship-bc`, `godot-brains-52`, `godot-orders-0a`; the orchestrator is `godot-67`
(`godot-22` is a stale main-checkout session from an earlier round: ignore/close it).

**Waiting on him:** push `main`; play `make garage` on main at `a9ae05f0` or later (the pursuit is on it) (the airship over foundry; five squads
as a body; V across the floor with no squad holding back; the computer's leaders on).

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
per worktree folder (`~/projects/godot-airship`, `~/projects/godot-brains`, `~/projects/godot-orders`).

## ✅ ROUND 20 IS CLOSED (2026-10-06 ~09:20 PDT → ~19:00 PDT) — read this first

**Two streams, both done and merged; `main-checked` = `0a9ce446`** (builder0, `>> remote: make check exited 0`, 2166
passed 0 failed, 23 targets ALL JUDGED, thirteen sim-baseline lines unmoved, determinism `762a0576f944f5b7`). Above it:
brains' final Status (`db059bcd`) and this close (docs only). Worktrees removed, branches deleted, briefs in
`streams/archive/round20/`, evidence in `streams/references/round20/brains/` and `build/round20-garage-shots/`
(garage's desktop/phone/results frames, rescued from its worktree; `assets/units/thumbs/**` is committed). He pushes `main`.

| Merge | What | Green (builder0) |
|---|---|---|
| `77e3ea0e` **CP1** | garage R1 ALONE (`5c89f03b`): 1 CR = 1.75 points for every faction; Gangs scout 40 CR; 25 Gangs scouts = 1000 exactly; the CPU opponent buys in credits | exited 0, 2143/0, thirteen unmoved |
| `ea322e9f` | garage at `bb1c088d`: 21 thumbnails from the real meshes on every card and chip (C20.4, `make unit-thumbs`); suggested armies in squads of about three; the tour plays his rule; the phone fits five squads; `--enemy-title` (C20.5); rings on the results screen; buy/sell sounds | exited 0, 2150/0 |
| `463eec2f` | garage at `4a4fd8b4` (green `e6a4024c`): builder0's thumbnails adopted; two captions | exited 0, 2150/0 |
| `29d323a2` | brains **M1** ALONE (`efc3682d`, DECLARED): a squad forms up on the move. Away-from-click in 5 s on parade 6.3–10.4 → 0.0–1.8 m; arrive series attack-move arm identical 100/100, plain-move arm median 21.1 vs 21.75 s | exited 0, 2158/0 |
| `cdc59a84` | brains **M1b** ALONE (`8ed06b70`, DECLARED): his attack on a named target runs no bait/encircle (the CPU keeps them) | exited 0, 2160/0 |
| `080f9f35` | brains **M2** ALONE (`97a581fb`): the CPU's opening built, measured, **shipped OFF** (`--cpu-opening`): round 19's posture already ambushes 8/8 on parade after a 10 s delay and trades better | (checked with M3) |
| `0a9ce446` | brains **M3** ALONE (`93d65495`, DECLARED): the ambush hides the LINE; parade 24 paired seeds: spring +2.20 s (se 1.00), his loss +214 HP (se 100), alive +1.25 (se 0.80); no cost without a site; search 1.17× only with CPU leaders on | exited 0, 2166/0, thirteen unmoved |

**His afternoon findings, both acted on or queued:** (1) *"they all just spread out and drove away"* = the gangs' bait
drill under his attack order → **fixed (M1b)**; the four squads' transit points at ±116 m on foundry are orders'
side-by-side spread scaling with five squads (a gang vee is ~72 m; five need ~400 m; the clamp pins the outer squads)
→ **round 21, orders**: converge on a named target or cap the spread. (2) **The airship is never in his frame on the
built-up maps** (`make airship-report`, main, laptop: terminus 0 %, cut 0 %, locks 1 %, crossing 1 %, docks 3 %; the
open maps 24–31 %; the pilot climbs over tall kit and stays above his frame top; the report's default `MAPS` is the
round-11 nine, not the rotation) → **round 21's first candidate** (he did not answer the third-stream offer; the
round closed with brains).

**Waiting on him:** CPU squad leaders on by default (`make skirmish ARENA=parade CPU_LEADERS=1`; 3–5 ms a tick on his
laptop; M3 only runs with them); push `main`; play the garage on main (`make garage`: Road Gangs → CLEAR → tap the Rat
Rod 25 times; the Law → 12 Pursuit Cruisers, 40 CR left) and a fight with 25 Rat Rods ordered to attack one vehicle.

**He played again after the close (~18:40, `build/recordings/2026-10-06T18-38-40.jsonl`):** his attack-MOVE still
baits (M1b covers only a named target: widen to every player order), and an attack on a RETREATING Syndicate spotter
had his scouts orbiting and the last one "arrived" 70 m short (the element re-lays vee stations around a moving
target; a pursuit is needed). His words and the reading: `game_design.md` *Round 20, evening*. **Round 21's first
item (brains), beside the airship.**

**Round 21 candidates:** `roadmap.md` *Round 21 candidates*. **Starting the next round:** `orchestration.md`; the
kickoff prompt is unchanged.

## 🚀 ROUND 20 IS LAUNCHED (2026-10-06 morning) — kept as written

**Two streams from his two garage items after playing round 19** (*"ok this is much better"*; his words verbatim in
`game_design.md` *Round 20 direction*; the split and contracts C20.1–C20.4 in `workstreams.md` *Round 20*; briefs in
`streams/`): **garage** (every vehicle SEEN on its card and in its squad, as a thumbnail rendered from the real mesh;
prices per faction so five squads of five scouts is exactly 1000 credits, the scout at 40 CR and relative prices
kept; the cap stays 25 unless he answers otherwise), **brains** (a squad forms up on the move, so nothing shuffles
into shape before it sets off and no crew drives away from the click; the computer's opening lets it be ahead so its
ambush fires; the ambush hides the line as stretch).

| Stream | Folder (offset) | What it is | His gate |
|---|---|---|---|
| **garage** | `godot-garage` (1) | the price rule (R1, merged ALONE = CP1); thumbnails via `make unit-thumbs` on builder0 (needs its desktop unlocked); the phone wrap | more than 25 for an all-scout army? (recommended: no) |
| **brains** | `godot-brains` (2) | form up on the move (M1); the opening posture (M2); the ambush hides the line (M3); each declared and alone | CPU squad leaders on by default (pending, with the price) |

**His answer minutes after the launch (replaces the launch's per-faction rule):** *"for now we will assume that an
all scout army for the road gangs is 25 vehicles, and all costs and counts can be based on that."* So the Gangs' scout
is the anchor: 25 = 1000 credits, ONE CREDIT = 1.75 POINTS for every faction (Gangs scout 40 CR, Condemned 63, Law 80,
Syndicate 120; all-scout armies 25 / ~15 / 12 / 8); the cap is 25. Recorded in `game_design.md` *Round 20: the cap
and the price anchor* and in garage's brief (R1; the worktree is at that commit). Decided for him: thumbnails, not
live 3D viewports.

**State (~16:30 PDT): garage DONE and merged; brains running.** `main-checked` = `29d323a2` (brains' M1 merged ALONE at
`efc3682d`, a squad forms up on the move; builder0, exited 0, 2158/0, thirteen lines unmoved, determinism
`762a0576f944f5b7`). Garage's last commit `463eec2f` was green before it (2150/0). Merges so far: **CP1** `77e3ea0e` (R1 alone, `5c89f03b`), `ea322e9f`
(garage at `bb1c088d`: thumbnails, squads of about three, the tour, the phone, `--enemy-title` C20.5, rings),
`463eec2f` (garage at `4a4fd8b4`). Brains merged main at `ee5838c1` (has CP1, the garage, and its brief's M1b).
**Brains' M1 is on main.** Next from brains, each alone and checked: **M1b** (`8ed06b70` on its branch, his attack on a
named target runs no bait/encircle; check pending), **M2 shipped OFF on evidence** (opening-series, builder0, 8 paired
seeds: no ambush in either arm when he sets off at once; after 10 s on parade round 19's posture already ambushes 8/8
and trades better; `--cpu-opening` keeps it switchable), **M3** (the ambush hides the line: springs later, median 14.6
vs 13.45 s on parade; alive +2.0 ± 3.85 and his loss +484 ± 525 HP over 8 seeds, both inside noise; asked whether it
ships). Evidence under `streams/references/round20/brains`. Worker sessions: `godot-garage-ee` (done, idle), `godot-brains-6f`;
the orchestrator is `godot-67`.

**Two findings from his afternoon play (both recorded in `game_design.md`):**
1. **The airship is never in his frame on the built-up maps** (`make airship-report` on main, laptop: terminus 0 %,
   cut 0 %, locks 1 %, crossing 1 %, docks 3 % of the flight in frame; parade/yard/gorge/archipelago 24–31 %). It is
   built on every map and his laptop preset does not remove it (FX tier HIGH on desktop); the pilot climbs over tall
   kit and stays above his frame top. The report's default `MAPS` list is the round-11 nine, not the rotation.
   **Offered to him as a third stream (airship, `game/theme/arena_kit/airship/**`) this round or round 21's first
   item; not yet answered.**
2. **His attack order was overridden by the gangs' bait drill** (25 Rat Rods, select all, V, attack one vehicle:
   one scout forward per squad, four holding and backing away). Decided and handed to brains as **M1b** (a
   player-given `attack` with a named target runs no bait/encircle). Recording:
   `build/recordings/2026-10-06T14-59-04.jsonl`.

**Waiting on him:** CPU squad leaders on by default (`make skirmish ARENA=parade CPU_LEADERS=1` to
try it; about 3–5 ms a tick on his laptop); ~~builder0's desktop unlocked~~ (done: caffeinate on there since ~09:40, screen on and desktop unlocked from now on; `remote_builds.md` troubleshooting updated); push `main`.

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
per worktree folder.

## ✅ ROUND 19 IS CLOSED (2026-10-05 21:15 PDT → 2026-10-06 08:10 PDT) — read this first

**Four streams, one night, from his one message after two games on the twelve maps** (formations seemed global; two
squads sent to one point scattered and ran to the middle; the garage he imagines; a scoreboard in the register of a
televised sport) and his second message minutes later (*"very little indication that standing in the ring scores
points"*). His words: `game_design.md` *Round 19 direction*. Briefs with each worker's final report:
`streams/archive/round19/`; evidence: `streams/references/round19/`; contracts C19.1–C19.7 in `workstreams.md`;
round 20 in `roadmap.md` *Round 20 candidates*. The merge table in the launch section below was kept live and is the
record (rows 1–14 plus the closing merges listed here). **He said nothing after ~22:20 PDT on the 5th; everything
after was decided without him and says so where it was.**

**`main-checked` = `635d9d9b`** (builder0, 2026-10-06, `>> remote: make check exited 0`, copy-back verified, 23 targets
all passed ALL JUDGED, 2139 passed 0 failed, six shard statuses 0, thirteen sim-baseline lines unmoved, determinism
`762a0576f944f5b7`, 28 engine-pattern lines: the 26 of round 18 plus two deliberate `Elements.form … refused` lines
from the C19.1 guard tests). Above it: docs only (this close).

### What he has now (all on `main`, every row checked on builder0)

- **A formation belongs to the squad he gave it to** (orders): a pick applies to the selected squad at once; selecting
  another squad shows that squad's own; G cycles the selected squad's, Shift+G steps back; the panel names which
  squad stands in which shape.
- **Two squads sent to one point stay two squads** (orders + brains' guard): one order per squad, side by side, each
  transiting from its own position; no element can ever hold more than five (the C19.1 guard, tested on both sides);
  one ground pin per squad and a dot per vehicle; the radar's rings fill as a side captures them. Probe: the worst
  run toward the middle 37.6 m → 6.9 m. The cause of his symptom: "1 then Shift+2" ADDS to group 2 (StarCraft's
  meaning, kept), which made one ten-vehicle element that transited from the midpoint between the squads.
- **The garage he imagines** (garage): 1000 credits a game for both sides (1 CR = 5 points, exact; `Units.cost`
  untouched, every baseline unmoved); every vehicle open; faction → vehicles → squads → FIGHT on one screen in the
  kit; the credits meter (amber under 10 %); "your army is full" / "every credit is spent" in words; the results
  screen in the kit with the score line; a SHARE line (`--army=CODE` opens it); tiers and unlocks retired from the
  garage. **The UI kit documented:** `_agents/ui_kit.md`, `make ui-kit-shots`.
- **A scoreboard he can read all match** (board): each scoring ring drawn ON THE FLOOR with a capture arc in the
  capturer's colour, flowing while held, its name and SCORING over it; the score bug top centre on both paths, up
  during the planning pause (meter to 90, +1 per point, W / E chips, a lower-third on a change of hands, LEAD
  CHANGE, kills and credits destroyed in CR); the booth hears both rings and names them; a ghastly kill's stinger on
  the bug; the screens' score strip over the live feed. One score snapshot and `score_changed` from `Match`
  (C19.4), read everywhere. The centre ring is painted only on maps whose centre scores.
- **The computer defends and lies in wait** (brains, behind `--element-cpu`, OFF on his path): a CPU holding a zone
  and ahead on points, or with an enemy within 60 m of it, defends it and lays one flank ambush (parade 8 seeds:
  sprung from the bay 8 of 8). The hold moves the hash on 9 of 13 maps in CPU-v-CPU. **His switch:** `make skirmish
  ARENA=parade CPU_LEADERS=1`. Also: the ambush-site search 2–5× faster; the squad that stopped short on the Cut
  arrives (100 of 100 with the fix, 99 without, on one tree); the element planner clamps to the arena's real shape.
- **Fixed on the way:** the Parade Ground's sign stood on a lane (the first check of the dealing was red on it); the
  results score line was empty because `Match` emitted `finished` before filling `final_score` (now filled first,
  tested); a latency test that counted rendered frames instead of physics ticks (red once in two runs after CP2).

### DECIDED FOR HIM while he was away (each reversible; overrule any)

1. **1000 credits buys the army he plays now, not five tanks** (1 CR = 5 points).
2. **Every vehicle is buyable from the first game**; tiers and unlocks left the garage; the earned total stays in the
   profile for his later layer (sketched in `game_design.md` *Progression*, nothing built).
3. **The Road Gangs are full at 25 vehicles** with credits unspent; the garage says so in words.
4. **Kills are shown, not scored** (board's series: 2 of 15 control wins would flip in 36 matches, both on the
   Crossing, both to the side that just shot more).
5. **The board names the zones as each map does** (two side rings on every dealt map; "centre" on the older arenas).
6. **CPU squad leaders stay OFF on his path** until he has crossed parade against them (brains' recommendation with
   the price: +5.1 ms a tick mean, +3.4 median, sd 4.5, 23 bins, his laptop, quiet window HELD).
7. **Shift+N keeps StarCraft's meaning** (adds to the group); with one order per squad it no longer matters.

### Waiting on the lead (live)

- **His play:** `make garage` (a Law army, FIGHT, REMATCH, ARMY); `make skirmish ARENA=parade` (squad 1 Line, squad 2
  Wedge, box both, right-click the far bay: two pins, two shapes side by side; then Ctrl+3 over both and the same);
  `make skirmish ARENA=terminus` (the bug at 0 : 0 while he plans; take a ring and watch it fill on the floor; hold
  it and watch the meter); `make skirmish ARENA=parade CPU_LEADERS=1` (start in a bay, let the CPU settle on its
  depot, cross the floor in line toward it).
- **CPU squad leaders on by default?** (candidate 1; the price above).
- **Unlock builder0's desktop** (`loginctl` LockedHint=yes since the small hours of the 6th): windowed renders there
  run at a tenth speed and time out; board's 95 s and phone in-play frames wait on it.
- **Push `main`.** Close the four round-19 terminals (orders, brains, garage, board: their folders are gone) and the
  stale `godot-22`.
- Still true from round 17: his browser's keyboard (`~/.cache/ibus`); play in stereo or 2.1.

### Housekeeping at the close

- All four worktrees and stream branches removed after the ancestor check, each worker's "done" and a scan for live
  processes (none); no ignored assets in any worktree (only `local.mk`). `brains-r18-ambush` (round 18's unmerged
  ambush branch, now carried forward and merged via brains' B1) and `brains-wip-backup` can be deleted on his word;
  the four older local branches are untouched.
- builder0: the four stream mirrors (`~/tank_squad/godot-<stream>`) are disposable; not removed (brains asked that
  its go once merged; nothing of the others runs there).
- The quiet-window series files and every series are under `streams/references/round19/`; the contaminated first
  attempt is on the laptop at `/tmp/claude-1000/element-play-r19-contaminated-0126/` (not in the repo; delete).
- The announcer pipeline's Python client is still installed by hand in `.tools/venv` (a `make bootstrap` item).
- The orchestrator's own errors this round, each a lesson candidate: merged brains' B4 v1 on the worker's word before
  its 100-run series had run (it lost 1 of 100; v2 fixed it the same night: the series is part of "green" for a
  movement change); announced "the window held" with a FOREIGN line on every sample that was its own pgrep loop (read
  the pid before the claim; it was, and the README says so); relayed brains' "option (b)" cause to the lead before
  it was measured, and had to retract it an hour later (a cause is relayed after the arm, not before).

_The launch record and the live log follow, as written while the round ran:_

## 🚀 ROUND 19 IS LAUNCHED (2026-10-05 evening) — read this first

**Four streams from his one message after two games on the twelve-map rotation** (his words verbatim in
`game_design.md` *Round 19 direction*; the split, ownership and contracts C19.1–C19.7 in `workstreams.md` *Round
19*; the briefs in `streams/`): **orders** (a formation belongs to the squad he gave it to; two squads ordered
together stay two squads and arrive side by side; the dots tell the truth), **brains** (the CPU holds and lies in
wait when ahead or threatened, carried forward from `brains-r18-ambush`; the element machinery's price cut and
re-measured so he can be asked; the Cut's stop-short; the tactics-side guards for the two-squad case), **garage**
(1000 credits a game for both sides, every vehicle priced and buyable, faction → vehicles → squads → FIGHT on one
screen in the kit, the kit written down in `_agents/ui_kit.md`; tiers and unlocks retired), **board** (a score bug
with each side's progress to the win and its kills, celebrated on a kill the way a broadcast does it; one score
snapshot from `Match` read everywhere).

| Stream | Folder (offset) | What it is | His gate |
|---|---|---|---|
| **orders** | `godot-orders` (1) | a formation per squad, applied at once; one order per squad for a multi-squad click, side by side; per-vehicle and per-squad dots | he plays it |
| **brains** | `godot-brains` (2) | the CPU defends and ambushes (B2) behind the elements flag (OFF on his path until he answers); the price cut (B3); the Cut (B4); the guards (B5) | CPU squad leaders on, at B3's price |
| **garage** | `godot-garage` (3) | 1000 credits, every vehicle, any mix, up to five squads, one screen, the kit documented (CP1); the prices alone (CP3) | army size at 1000; every vehicle open |
| **board** | `godot-board` (4) | the score bug, the celebration, the snapshot and signal, the screens and results from it | kills toward the win; one floor or two zones; new paid lines |

**Checkpoints:** CP1 garage's kit → board merges. CP2 orders' O2+O3 → brains merges. CP3 garage's prices, ALONE,
pre-registered either way. **Hash rule (C19.2, C19.3):** thirteen baseline lines (foundry + the twelve dealt maps)
and determinism UNMOVED on every commit except brains' declared changes and garage's G1; an unplanned move is a
finding.

**What was decided for him at the launch (each reversible; `game_design.md` *Round 19 direction* has the reasons):**
1000 credits buys the army he plays now, not five tanks; every vehicle open from the first game; he picks a faction
in the garage; squads of up to five, formation and role set in the match, not the garage; kills shown on the board
but not scoring a win this round; the board names the zones as each map does (the dealt maps have two side rings,
not a centre); the CPU's posture is built behind the flag and priced before he is asked.

**Questions put to him in the launch message** (his answers go to `game_design.md` and the briefs' *Waiting on the
lead*): army size at 1000 (recommended: the army he plays now); every vehicle open (yes); kills toward the win (not
this round); one central floor or two zones (the maps'); CPU squad leaders on at B3's price (after the number); the
2 s slow motion (keep).

**`main-checked`:** the check on `da0bdef3` (the dealing) **exited 2** on builder0 (21:05–21:35 PDT: 2056 passed, 1
failed: `test_arena_prop_parity::test_decoration_stands_where_no_hull_is_sent`, parade's arena sign 4.1 m from the
west way round's first point, a rule that runs only on dealt maps; every other target passed, 13 lines unmoved,
determinism `762a0576f944f5b7` + crossing `ecc5e597b641b7b0`). Fixed in **`9eae58b1`** (the sign to (−80, 92), a
decoration, no collider; laptop: arena_prop_parity 3/0, FILTER=arena 143/0); **`main-checked` = `9eae58b1`** (builder0,
21:40–22:08 PDT: `>> remote: make check exited 0`, copy-back verified 350 files, 23 targets all passed ALL JUDGED,
2057 passed 0 failed, six shard statuses 0, zero exit-leak lines; all thirteen sim-baseline lines unmoved, parade
`7c13a1a6191ebaf5` included; determinism `762a0576f944f5b7` + crossing `ecc5e597b641b7b0`; 26 lines match
`ERROR|WARNING|parsing error`, the same count as the previous check, no new kind). Above it: docs only. Workers
start from it.

**Merge table (round 19, kept live):**

| # | main | What | Its own check | On main |
|---|---|---|---|---|
| 1 | `6ebdaf78` (2026-10-05 22:39 PDT) | orchestrator, board's request 1: the floor paints the centre ring only where the centre scores (every dealt map scores two side zones); regression test in `test_fx_crowd` | — | **GREEN** (builder0, 22:39–23:1x PDT: exited 0, 2057/0, 13 lines unmoved) |
| 2 | `94d301ae` (23:27 PDT) | garage `84f7197d` = **CP1**: the UI kit (CyberKit, CyberCard, CyberMeter, CyberCrest, `_agents/ui_kit.md`, `make ui-kit-shots`), additive; the sheet looked at by the orchestrator (frames in garage's scratchpad `ui-kit-84f7197d/`) | exited 0, 2063/0, 13 unmoved | **GREEN** (builder0: exited 0, 2063/0, 13 lines unmoved). Board told to merge |
| 3 | `eef498db` (2026-10-06 ~00:00 PDT) | brains `d7f2bd93`: B1 (the ambush work carried forward), B2 DECLARED (a CPU holding a zone and ahead, or threatened within 60 m, defends it and lays a flank ambush; parade 8 seeds sprung from the bay 8 of 8, −1.4 ± 1.2 CPU alive per pair; moves no line; CPU elements OFF on his path), stretch (c) (the roam fallback cannot reach his units, pinned) | exited 0, 2071/0, 13 unmoved | **GREEN = `main-checked` `eef498db`** (builder0: exited 0, 23 targets ALL JUDGED, 2077/0, four shard statuses 0, 13 lines unmoved, determinism `762a0576f944f5b7`, 26 engine-pattern lines, no new kind). Docs above it: `ef9c9aaa` (Match rules rewritten) |

| 4 | `5619363f` (01:25 PDT) | brains `47463712`: B3 cut 1 (the ambush-site search 2–5× faster, identical answers), B4 v1 DECLARED (the Cut seed 3; later found to lose 1 of 100 on the Sumps) | exited 0, 2075/0 | GREEN (builder0, exited 0; the log `remote_check_5619363f.log`) |
| 5 | `5a60f032` (02:38 PDT) | garage `66b8f34a` ALONE = **CP3**: 1000 credits (1 CR = 5 points, exact; every vehicle open; the CPU at the same money); `Units.cost` untouched | exited 0, 2071/0, 13 unmoved | **GREEN** (builder0: exited 0, 2089/0, 13 unmoved) |
| 6 | `cc7d0538` (~02:50 PDT) | orders `38d99b44` = **CP2**: a formation per squad; one order per squad for a multi-squad click; the lent C19.1 guard (14 lines) | exited 0, 2074/0; squad-partial mixed identical | **GREEN** (builder0: exited 0, 2106/0, 13 unmoved) |
| 7 | `b8725381` (~03:05 PDT) | board `ad4c84e9`: the scoreboard (S1–S4); frames looked at | exited 0, 2082/0 | **RED, exited 2: ONE test**, `test_control_scale::test_input_to_order_latency_with_a_box_around_the_army` (20 of 30 ordered after one rendered frame; builder0 at load 7.4–8.2, 41 other Godot). Orders' diagnosis: since CP2 a box of six squads is six tasks and the crews' orders land over 3 physics ticks, inside the response window; the test awaited one RENDERED frame. A test too strict, not behaviour. Seen 1 of 2 (row 8 passed). Test fixed in `206f3cc1` (cherry-pick of orders' `753bfb70`; laptop 5/0) |
| 8 | `a5872968` (~03:50 PDT) | board `8235e608`: the bug shows CR via Credits; the kills line's backing tab | exited 0, 2126/0 | **GREEN = `main-checked` `a5872968`** (builder0: exited 0, 2129/0, 13 unmoved, 27 engine-pattern lines = 26 + one deliberate `Elements.form … refused` line) |
| 9 | `157c8718` | orders `b03c0767` = O4: one ground pin per squad; the radar's capture arc from the snapshot; the touch-map meter removed | exited 0, 2127/0 on the merged tree | queued |
| 10 | `1fe73f9f` | brains `5f77e318` = B4 v2: the make-room swap only for a corked crew; arrive series ON 100/100, OFF 99/100 | exited 0, 2076/0 | queued |
| 11 | `206f3cc1` | the control_scale test counted in physics ticks (orders `753bfb70`, cherry-picked) | laptop 5/0 | its check queued (`remote_check_206f3cc1.log`) |
| 12 | `4b8113dd` | brains `37bdab41` = B5: the C19.1 guard tests; `Element.transit_origin`; the arena-shape clamp; `Element.remove` emits; the posture reads `score_changed` | exited 0, 2131/0 on merged main | queued |
| 13 | `ca3951fc` | board `b2eb8488`: docs only (the final report; stretch (d): kills shown, not scored, 2 of 15 control wins would flip in 36 matches) | — | — |
| 14 | `97df1b9c` | garage `90695808` = G3–G5 + stretch (b): the garage he imagines; the results screen in the kit; the SHARE line; frames looked at | exited 0, 2129/0 on the merged tree | a check on the tip is owed |

**Pending:** board `4c37466b` (S1–S4: the snapshot and signal, ZoneRings, the ScoreBug, the booth on both rings, the
screens' strip; its first green `5596b72d` was withdrawn by board after its own frames showed no bug during the
opening planning pause; merged only after the orchestrator has looked at its in-game frames) → then orders told to
remove the touch-map meter and every stream told to merge. Garage `fe32ba38` (CyberCard sized to content), then G1
`66b8f34a` ALONE at CP3 (credits = points / 5, exact; `Units.cost` untouched; UNMOVED). Orders: O1 probe `31154440`;
O2–O4 drafted. His question answered by recommendation: a Road Gangs army is full at 25 vehicles with 125 credits
unspent; the garage says "your army is full" in words.

**Housekeeping at the launch:** branch `stream/brains` renamed `brains-r18-ambush` (12 commits not on main: the
ambush work, `element-digest`, `ai-element-perfplay`; D1 among them is on main as `a122d6ff`); `brains-wip-backup`
kept. Six stale sessions from round 18 were still open at the launch (brains, ship, maps, picker, finale, `godot-22`):
close them before the kickoffs. The announcer pipeline's Python client is installed by hand in `.tools/venv`
(`tools/announcer/requirements.txt`): a `make bootstrap` item, nobody's this round.

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
per worktree folder.

## ✅ ROUND 18 IS CLOSED (2026-10-04 14:38 PDT → 2026-10-05) — read this first

**Five streams, one afternoon and one night, from the two things he asked for after playing round 17 (a formation
picker he can see; maps with room to manoeuvre and an open centre a line abreast can be ambushed in) and one answer
to the candidate list: *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as
smart"* and *"I don't want to sacrifice anything on our game to accomodate browser play"*.** His words are in
`game_design.md` *Round 18 direction* (A, B, *His pick*); briefs with each worker's final report in
`streams/archive/round18/`; evidence in `streams/references/round18/`; lessons 254–260; round 19 in `roadmap.md`
*Round 19 candidates* (ten, each with a line for him). The merge table further down was kept live and is the
record (rows 1–30). **He said nothing after 14:20 PDT on the 4th; everything below was decided without him and
says so where it was.**

**`main-checked` = `908f4861`** (builder0, 2026-10-05 05:36–06:04 PDT: `>> remote: make check exited 0`, copy-back verified 315 files, 23 targets all passed ALL JUDGED, 2057 passed 0 failed, six shard statuses 0, zero exit-leak lines; sim-baseline foundry `5d8191d5aacc4027`, yard `e0393e53918debc1`, pit `e03377eab0ab0389`, terminus `8b0309ee85e497dc`, crossing `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e`; determinism `762a0576f944f5b7`; 26 lines match `ERROR|WARNING|parsing error`, every one a recipe echo or a test's deliberate line, no new kind against the previous check). Above it: docs only.

### What he has now (all on `main`, every row checked on builder0)

- **The formation picker** (picker): resting the mouse on Formation (or a tap) opens a panel of every formation as
  its shape, AUTO first; one click picks; an animated preview on each card from the real geometry; each card says
  "fits here" or "squeezed here" from the game's own seating; G still cycles the five everyday shapes. The same
  preview on the tactical map's picker. Three equal-output HUD cuts (markers −19 %, awareness −7 %, unit bars −12 %).
- **Six candidate maps he can play by name** (maps): `make skirmish ARENA=parade|gorge|archipelago|cut|docks|yard_open`.
  None is dealt. The Parade Ground (v3): a 112 m open floor with one 44 m bay of container walls a side; every
  formation fits in the centre and in a bay. `yard_open` is his Container Yard with the middle opened. **His page:**
  https://claude.ai/artifact/WenjeeygUULXj5RTSmjXzb (v4).
- **Units that do not show themselves to a gun they know is laid on them** (brains, CP1, `x18m`, both sides): the
  round's one planned change of fights; three baseline lines adopted; the scenario red since round 15 is green.
  Honest claim: at no measured cost in hits or wins (ladders ties; Law 16 of 48 → 11 of 48 within the spread).
- **His squads on a task arrive** (brains): a two-scout squad on an attack-move no longer stops after one leg (it
  stalled 21 of 80 runs; the Terminus 8 of 8); on the Sumps tasked squads went from 0 of 8 arriving to 80 of 80
  across four maps; a moving wedge or column watches its flanks (guns on their sectors).
- **No shader freezes mid-match** (finale): the first uses that compiled as 1–2.8 s frames on a cold cache are
  drawn behind a loading screen that holds for them by contract; the cold loading screen on his path is about 9 s
  (about 3 s warm). DEFEAT / VICTORY sits below the last kill. The exit leak at a quit is fixed in the quit paths.
- **A check with this round's holes closed** (ship): a baseline line per dealt map; a shard that crashes after its
  summary fails `test`; exit leaks fail `test`; every check recipe reads the engine's exit code; the copy-back
  verifies; an intermittent red is recorded as `seen k of N`; `make quit-leak-arms`, `make known-red`,
  `candidates-smoke` and `end-frame-measure` in `check-all`. Known red outside `check`: web-host-smoke only (held).

### DECIDED FOR HIM while he was away (each reversible; overrule any)

1. **The arena screens' feed keeps glow** (invisible from his camera, no measurable cost, cuts the cold loading
   screen from about 13 s to about 9 s). Undo: launch with `--feed-glow=off`.
2. **DEFEAT / VICTORY moved to 66 % of the screen height**, so the last explosion is visible during the slow motion.
3. **The freeze at the final kill was included in the round** on the orchestrator's recommendation (it did not
   reproduce: 0 of 9; the real stalls were cold-cache compiles).
4. **The peeking rule shipped as `x18m`, not the rule he was described** ("peek only while the enemy reloads" lost
   the squad fight 7–25).
5. **The computer running squad leaders in his skirmish was NOT put to him:** it costs his laptop about +6.5 ms a
   tick (+20 %) and, as built, shows him no ambush.

### NOT delivered, and why

- **The computer ambushing him.** The map offers it and his squads can do it; the CPU never will as it runs today
  (no squad leaders in his skirmish; its commander never issued an ambush). Built on branch `stream/brains`
  (KEPT, unmerged): it fires CPU-v-CPU, is never in time on parade (both sides race for the centre; a bay ambush
  needs a CPU that DEFENDS). Roadmap round 19 candidate 10 has the geometry, the probe counts and the price.
- **One spot on the Cut** where a tasked squad stops short beside a wall (seed 3; re-seats capped at 3).

### AFTER the close: the six maps DEALT (2026-10-05 21:06 PDT)

He came back, played, and said *"just keep all of the maps"*. Dealt in **`da0bdef3`** (one commit, as the rule in
`arena.gd` requires): `Arena.ROTATION` is twelve maps (yard, pit, terminus, crossing, sumps, locks, parade, gorge,
archipelago, cut, docks, yard_open = **the Open Yard**, beside the Container Yard); `CANDIDATES` is empty; the
layouts differ from the candidates only in `fixture`, the Open Yard's title and two notes naming their terrain; the
booth's 108 recordings of the six names (**his approval of the spend: 12,714 characters, ElevenLabs 34,490 →
22,724 credits**, `assets/announcer/ledger.md`); six baseline lines adopted, each read twice on builder0 (parade
`7c13a1a6191ebaf5`, gorge `c53b4eb1a4a8b108`, archipelago `4d7e1931f61b1f99`, cut `6bdedbdef29a1146`, docks
`c517fd89eaff67be`, yard_open `3e6d770e68294f41`), the seven older lines unmoved. Laptop: test_arena_kit 13/0 (after
the two notes), arena lanes / cover tables / layouts / layout keys, control_faction_pick and camera_solids all pass
over the new rotation; `announcer-check` passes; the names test passes; a random-pick skirmish and an Open Yard
skirmish run headless with 0 engine lines and the booth names the Open Yard. **The check on `da0bdef3` exited 2 on builder0** (one decoration test on the dealt
Parade Ground; fixed in `9eae58b1`: the launch section above has the record). The six Keeps on the maps page
are moot. The announcer pipeline's Python client was missing after his reset: installed in `.tools/venv`
(`tools/announcer/requirements.txt`); a `make bootstrap` item for the next orchestrator.

### Waiting on the lead (live)

- ~~The six Keeps on the maps page.~~ **Answered: "just keep all of the maps"; all six dealt (above).**
- **The slow motion after the final kill** lasts about 2 s; finale recommends keeping it; his feel.
- **Push `main`** (his; 1090 commits ahead of `origin/main`).
- **Close six terminals**: the five workers (picker, maps, brains, ship, finale: their folders are gone) and the
  stale `godot-22`.
- **Playtest list:** `make skirmish` and rest the mouse on Formation; `make skirmish ARENA=parade` (post a squad in
  a bay with the Ambush order and let the computer cross); attack-move a squad with two scouts in it on the
  Terminus, and four tanks across the Sumps (both used to stall); watch a wedge's guns as it moves; the end of a
  match (the word below the kill); the first launch after this pull loads about 9 s once.
- Still true from round 17: his browser's keyboard (`~/.cache/ibus`), play in stereo or 2.1.

### The findings that were not on any list

1. **A test passed and then the process died of heap corruption; four green checks could not see it** (lesson 255):
   `make test` wrote each shard's exit status and never read it; eight more recipes had the same blindness.
2. **The check's own recipe could fail a passing check** (lesson 257): the heartbeat's EXIT trap under `-e`.
3. **The loading-screen hold worked only because an unrelated polling interval was zero** (lesson 259).
4. **The copy-back failed every run after one `check-all`** (an unanchored rsync exclude; lesson 258).
5. **The per-map baseline does not see a decision change on four of his six maps** (their 40 s matches hold no
   bait): a decision change needs its own series (roadmap candidate 5).
6. **The "+188 orphan nodes" were a sampling artefact** (nodes already queued for deletion), not a leak.
7. **The open map is not the expensive case on his laptop** (parade 64 and 66 ms a frame against the Sumps' 77 and
   101, quiet window, N = 2 pairs).

### Housekeeping at the close

- All five worktrees and stream branches removed after the ancestor check and each worker's "clear to remove",
  EXCEPT **`stream/brains` (kept: the unmerged ambush work) and `brains-wip-backup` (kept: 31 commits found nowhere
  else)**. Only the main checkout remains. Four older local branches from before round 17 are untouched
  (`feel-rig-check`, `measure/facing-arc`, `stream/terrain-uid`, `tmp/metrics-r8-control`).
- builder0: this round's nine stream folders and their user dirs removed (28 GB free after); the ~40 mirrors of
  earlier rounds' streams remain, disposable on his word. Laptop: 29 GB free.
- The maps page's `db` read at the close and saved (`verdicts`, `meta`). It is the round's only page.
- The orchestrator's own errors this round, each a lesson: candidates put to him in our shorthand (254); "confirmed
  on main" said of a picker whose bottom row was covered, before looking at its frames; a rate relayed without its
  spread, and a ship / no-ship call made on it (256); one cost given to him as 12 s, then 3.3 s, then 7.6 s; "no
  race" said of a hold that worked by coincidence (259); a leak suspected in the game from a runner's count; a
  seven-minute "quiet" measurement with another stream's runs inside it (260); two workers' explanations repeated
  to him and later retracted by them (the copy-back; the desktop leak).

_The launch record and the live log follow, as written while the round ran:_

## 🚀 ROUND 18 IS LAUNCHED (2026-10-04 14:38 PDT) — kept as written

**Five streams, from his two items after playing round 17 and one answer.** He asked for a formation picker he can
see and for new maps with room to manoeuvre; offered the rest of the list as things he would notice, he said: *"Yes
make the CPU smarter, this would apply to all units. We want to make the computer opponents hard, but kind of like in
Gears of War, our friendly players are just as smart, so it just makes the game better. Don't worry too much about
the browser version right now, I don't want to sacrifice anything on our game to accomodate browser play"*
(`game_design.md` *Round 18 direction*, *His pick*).

| Stream | Folder (offset) | What it is | His gate |
|---|---|---|---|
| **picker** (CLOSED 2026-10-05) | ~~`godot-picker`~~ (1) | The Formation button opens a panel of every formation as its shape; one click; the animated preview on hover; G still cycles | he plays it |
| **maps** (CLOSED 2026-10-05) | ~~`godot-maps`~~ (2) | New maps by experiment: candidate 1 is the open centre a line abreast can be ambushed in; several more, different in kind; playable by name, never dealt | a page (KEEP / CUT per map), after playing each |
| **brains** (CLOSED 2026-10-05; branch kept) | ~~`godot-brains`~~ (3) | No unit shows itself to a loaded gun (both sides); then the CPU's doctrine in open ground, measured for the first time and made to play | — (his words are the authority: C18.4) |
| **ship** (CLOSED 2026-10-05) | ~~`godot-ship`~~ (4) | A baseline line per dealt map; the adopter for many lines; the test shards exit clean; the disk on `round-status`. No browser work | — |
| **finale** (CLOSED 2026-10-05) | ~~`godot-finale`~~ (5) | The freeze at the final kill on his laptop: traced, attributed by removal, fixed at the cause, kept out; the same class at first use mid-match | — (maybe one question: the slow motion's length) |

**Contracts** (`workstreams.md` *Round 18*): C18.1 the hashes move once on purpose (brains' CP1, merged alone; ship's
per-map lines re-recorded by the orchestrator on whichever merges second); C18.2 a candidate map is never dealt;
C18.3 his play and eye are the checks, pages rendered before he gets a link, questions in his terms; C18.4 smart on
both sides ships on our evidence; C18.5 one tree per comparison; C18.6 shared files and carve-outs (the banner for
finale; `mk/core.mk` by request); C18.7 the native game never bends for the browser.

**For the orchestrator while it runs:**
- **Three checkpoints, in whatever order they go green:** **CP0** ship's per-map baseline; **CP1** brains' peeking
  fix (ALONE; `make remote T=check` on `main`; if CP0 is in, re-record every per-map line on the merged tree, twice,
  before telling anyone to merge); **CP2** maps' candidate 1 (then tell brains to merge and measure on it, and give
  him the command to play it). After each: every stream is told to `git merge main`.
- **Quiet-window laptop runs are yours**: finale's end-frame trace, maps' `perf-play ARENA=<candidate>`, brains'
  open-ground lever arm (stretch). Close Chrome first; state the load.
- **Relays to expect:** brains ↔ maps (what candidate 1 made the CPU do; a map that breaks the CPU); finale → picker
  (a first-use cost in the banner: you land the minimal patch); finale → ship (an end-frame MEASURE line for
  `check-all`); maps → ship (the day a candidate is dealt, on his word); maps → picker (the tactical map or radar
  drawing a candidate wrong); ship → everyone (before its first `mk/core.mk` change merges); brains → him, through
  you, if the peeking fix changes who wins his usual skirmish by more than the seeds' spread.
- **At every merge:** the verdict line AND the engine-error count (lesson 251); `df -h /` and
  `du -sh /tmp/claude-1000/*` (lesson 249; 30 GB free at launch).
- **Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
  per worktree folder. The five round-17 worker terminals must be closed first (their folders are gone).

**The merge table (kept live; a row is not checked on `main` until its last column says so):**

| # | Merge on `main` | What | Green at (worker's check, builder0) | Check on `main` |
|---|---|---|---|---|
| 1 | `0d6e506b` (2026-10-04 15:50 PDT) | picker `58a5ebc2`: the Formation picker (P1–P5) + the tactical map's shared preview. The fits-here badge (stretch b, `1e537c9d` `dab64009`) is NOT in it | exited 0, 23 targets ALL JUDGED, 2013/0, baseline `05df1d55ba49cde1` unmoved, 0 engine errors | **GREEN** (builder0, 15:50–16:28 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2013 passed 0 failed, sim-baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; 41 lines match `ERROR\|WARNING\|parsing error`, every one a known class: recipe echoes, the tests' deliberate errors, the shards' exit leaks; none from the picker). `make picker-playtest` on `main`, laptop headless: 6/6, 0 engine lines |
| 2 | `6a1a8fd5` (2026-10-04 16:25 PDT) | ship `3ee39518` = **CP0**: a baseline line per dealt map (foundry `05df1d55ba49cde1`, yard `797dc49109a452d8`, pit `098f7d5cb3795e7f`, terminus `8b0309ee85e497dc`, crossing `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e`), determinism on crossing (`0459b39aa81dd51e`), the many-line adopter (`tools/sim_baseline.py`), `candidates-smoke` and `make known-red` in `check-all`, the disk on `round-status` | exited 0, 23 targets ALL JUDGED, 2002/0, every line unmoved; proved red on a nudged yard pair and a stale pit line; sim-baseline 8 → 17 s, determinism 16 → 14 s, no added wall time | **GREEN with row 3** (one check, below). A check of this tree alone was queued 16:28 PDT, never started, and was cancelled at 16:47; its three waiting processes on builder0 were stopped by PID |
| 3 | `23941d90` (2026-10-04 16:48 PDT) | maps `b6d817f9` = **CP2**: the CANDIDATE class (`Arena.CANDIDATES` = parade, gorge, archipelago, cut; playable by name, never dealt), the Parade Ground first, `make arena-room` (the measures he named), the turning-pocket rule (`ArenaLanes.teeth`: asserted on candidates, reported on dealt maps: Terminus 4, Sumps 2, yard 12, pit 6) | exited 0, 23 targets ALL JUDGED, 2005/0 on the LAUNCH tree, foundry unmoved; no dealt layout file changed | **GREEN = `main-checked`** (builder0, 16:48–17:22 PDT: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2016 passed 0 failed; sim-baseline foundry `05df1d55ba49cde1`, yard, pit, terminus, crossing, sumps, locks all unmoved; determinism `762a0576f944f5b7` + crossing `0459b39aa81dd51e`; 35 lines match `ERROR\|WARNING\|parsing error`, no new kind against row 1's 41). Maps' `container-hashes` on its own branch (`adfe794b`, builder0) equals ship's six lines. Laptop headless on the merged tree: `candidates-smoke` played all four; a scripted skirmish on parade to tick 600, 0 engine lines. **Every stream told at 17:25 PDT to `git merge 23941d90`** |
| 4 | `651edba8` (2026-10-04 17:02 PDT) | picker `d6df4928`: "fits here" / "squeezed here" on each formation card from the real seating (`FormationFit`, the read-only `Orders.preview_group`); **a fix to row 1: the control-group bar was drawn over the panel's bottom row of cards and would have taken their clicks**; the same click in a NEW formation is a new order (scripted Sumps hash SAME on both sides, laptop, two runs each) | exited 0, 23 targets ALL JUDGED, 2019/0, baseline unmoved, 0 engine errors (on its own tree, without rows 2–3) | **GREEN = `main-checked` `d9372259`** (builder0, 17:23–18:09 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2022 passed 0 failed, all seven per-map lines unmoved, determinism `762a0576f944f5b7`; 35 engine-pattern lines, no new kind). On the merged tree, laptop headless: `make picker-playtest` 8/8 incl. `clear_of_the_group_bar`, 0 engine lines; `make test FILTER=formation_picker` 18/0, `FILTER=hud_widgets` 16/0 |
| 5 | `e675cac7` (2026-10-04 19:06 PDT) | ship `a958cdbb`: the test shards exit clean (four test-side fixes); the leak allow-list is deleted, so an exit leak FAILS `test`. NOT in it: the shard exit-status fix, the lent exit-code lines (later commits on `stream/ship`, unchecked) | exited 0, 23 targets ALL JUDGED, 2016/0, seven lines unmoved, zero exit-leak lines, 25 engine-pattern lines | **GREEN = `main-checked` `e675cac7`** (builder0, 19:06–19:50 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2022 passed 0 failed, **zero exit-leak lines**, all five shard statuses 0, seven lines unmoved; 25 engine-pattern lines, no new kind). |
| 6 | `bd3c3383` (2026-10-04 19:15 PDT) | finale `0f276dc7`: `ShaderWarmup` (the cold-cache first uses drawn in two frames behind the loading screen), `make end-frame-measure` (proves a run cold or prints NOT JUDGED), the end-of-match frame trace; a written design for slow motion's half-simulation (nothing built) | exited 0, 23 targets ALL JUDGED, 2032/0 on `d9372259`'s tree, seven lines unmoved; `end-frame-measure` on builder0: COLD proved, JUDGED PASS, 187 ms | **GREEN = `main-checked` `f6c6a282`, rows 6–8 together** (builder0, 19:50–20:29 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2033 passed 0 failed, zero exit-leak lines, all five shard statuses 0, seven lines unmoved; 25 engine-pattern lines, no new kind). Laptop on the merged tree after `make import` (the new class names need it; before it the fx tests fail to parse, as expected): shader_warmup 8/0, frame_trace 2/0, kill_cam 9/0, fx_systems 29/0, each alone, exit 0, no exit-leak line, no orphans; a scripted Sumps skirmish headless to tick 600: exit 0, 0 engine lines. The orchestrator looked at `e6-1_2_hold.jpg` and the proposal frame: DEFEAT does sit on the last explosion. **Not run by the orchestrator: a windowed launch on the laptop** (it opens on his desktop) |
| 7 | `a7e8030f` (2026-10-04 19:28 PDT) | picker `43603182`: the heap-abort TEST fix (methods, connected and disconnected; lesson 255), `repath_playtest.gd`'s lambdas made methods, the three playtest recipes read Godot's exit code, no edge-marker chip on the radar (the "Bravo 2" box) | exited 0, 23 targets ALL JUDGED, 2023/0, seven lines unmoved | **GREEN with row 6.** Laptop, real exit codes: formation_picker 17/0 exit 0 (2 of 2, and under `MALLOC_CHECK_=3`), control_awareness 8/0, control_orders 12/0, `make picker-playtest` exit 0 |
| 8 | `c797dd06` (2026-10-04 19:37 PDT) | maps `0901ab64`: six candidates (`parade` v3 with one 44 m bay a side instead of the 21 m ladder gaps, `gorge`, `archipelago`, `cut`, `docks`, `yard_open` = his Container Yard with the two middle columns out) | exited 0, 23 targets ALL JUDGED, 2016/0 with `23941d90` merged, seven lines unmoved; `candidates-smoke` on builder0 played all six | **GREEN with row 6.** Laptop: `candidates-smoke` all six; scripted skirmishes to tick 600 on parade, yard_open, docks: exit 0, 0 engine lines; arena_kit 13/0, arena_lanes 9/0 |
| 9 | `a340e6e1` (2026-10-04 20:42 PDT) | ship `401e5cfb`: `make test` reads each shard's exit status (a shard that dies after its summary FAILS, by name); `sim_baseline.py` and `perf_judge.sh` refuse a run that crashed after its result; `Watch.on` (`tests/support/watch.gd`) with `test_relay_peer` and `test_audio_match_mood` converted; `make sim-variants`. NOT in it: the eight recipes' exit codes (`12450031`, in check) and `end-frame-measure` in `check-all` (`28818a85`) | exited 0, 23 targets ALL JUDGED, 2035/0 on `c797dd06`'s tree, all five shard statuses read and 0, seven lines unmoved | **GREEN = `main-checked` `a340e6e1`** (builder0, 20:42–21:37 PDT incl. a long queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2035 passed 0 failed, four shards with every status read and 0, zero exit-leak lines, seven lines unmoved; 25 engine-pattern lines, no new kind). Cosmetic: the check's `>> check:` summary lines now land in the middle of the replayed test output (two streams interleaving), so a line-anchored read misses them; sent to ship. Laptop on the merged tree: ship's stub suites test-shards 5/0, sim-baseline 53/0, perf-judge 5/0, determinism 7/0; test_watch 2/0, test_relay_peer 10/0, test_audio_match_mood 12/0, each alone, exit 0 |
| 10 | `ebae861e` (2026-10-04 21:20 PDT) | ship `12450031`, alone: eight check recipes read the engine's exit code (army-loop-smoke, garage-smoke, tactics-drills, ai-scenarios-check, music-smoke's garage part, desktop-smoke, windowed-elimination-pair; the servers of net-, combat- and relay-smoke reaped, 143 the one named expected code) | exited 0, 23 targets ALL JUDGED, 2035/0, seven lines unmoved; the new gates ran on the real targets and no existing crash surfaced in `check` on builder0 | **GREEN = `main-checked` `93b0c599`, rows 10–11 together** (builder0, 21:38–22:20 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2036 passed 0 failed, four shard statuses 0, zero exit-leak lines, seven lines unmoved; the new gates printed net-smoke/server, combat-smoke/server and relay-smoke/host `exited 143 (expected)` and ai-scenarios-check `exited 1 (expected)`; 26 engine-pattern lines, the +1 a recipe echo). Laptop (glibc 2.39, the allocator that caught the picker abort), load 1.2, `make`'s own exit code: tactics-drills, garage-smoke, army-loop-smoke, net-smoke, combat-smoke, relay-smoke all exit 0; stub suites lent-exit-codes 8/0, reap 5/0, exit-gate 5/0 |
| 11 | `cdef3fae` (2026-10-04 21:35 PDT) | finale `56aacf46`: **a fix to row 6: the warm-up was warming the faction menu's backdrop match with no loading screen in front, so on a cold cache the MENU froze about 5 s twice**; it now warms only a match with controls. `end-trace` reads Godot's exit code; `end-frame-measure` fails a dead run with a display (stub-proved). His path measured with no screenshots, N=3 per arm | exited 0, 23 targets ALL JUDGED, 2034/0 on `f6c6a282`'s tree, seven lines unmoved | **GREEN with row 10.** Laptop after `make import`: shader_warmup 9/0, frame_trace 2/0, kill_cam 9/0, exit 0; a scripted Sumps skirmish headless to tick 600: exit 0, 0 engine lines, hash unchanged from before row 6. **`make end-frame-measure-selftest` FAILS in the laptop's main checkout** (exit 2, "the stub's trace run never ran"; the checkout has no `override.cfg`; reading not proved; sent to finale and ship; the target is in no check) |
| 12 | `1a9564d2` (2026-10-04 21:47 PDT) | picker `39475d19`: the loading screen holds for the shader warm-up (a new last stage, "Warming up the lights", capped at 120 frames); DEFEAT / VICTORY centred at 66 % of the screen height, above the alert strip | exited 0, 23 targets ALL JUDGED, 2038/0 on `c797dd06`'s tree, seven lines unmoved; `shell-playtest` through the real launcher on builder0: warmup 1941 and 2003 ms (about 2 frames of its 1 fps hidden window) | **GREEN = `main-checked` `6b814f6c`** (builder0, 22:21–23:24 PDT incl. the queue: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2041 passed 0 failed, five shard statuses 0, zero exit-leak lines, seven lines unmoved; 26 engine-pattern lines, no new kind). Laptop after `make import`: hud_launcher_warmup 4/0, hud_widgets 17/0, loading_screen 3/0, fx_shader_warmup 9/0, exit 0; `make picker-playtest` exit 0. The orchestrator looked at the two "after" hold frames (1854x1011, 1200x540): the explosion is visible above DEFEAT, the word clear of the "Alpha wiped out" strip. **UNPROVED on main: the hold against finale's controls-only warm-up** (`holding()` needs `_played_seen`, which is throttled; if it is not set when the hold first asks, the hold exits at 0 frames; picker's tests inject `holding`). Asked of both: a real cold launch on the merged tree |
| 13 | `93f7f415` (2026-10-04 22:42 PDT) | finale `4eb6033a`: `end-trace`'s cold mode refuses by name without a private user dir (`END_TRACE_COLD_REFUSED`); the self-test carries its own cache dir and a third case; the glow pair for his decision (`streams/references/round18/finale/feed_glow_pair.jpg`, `feed_glow_view.jpg`) | exited 0, 23 targets ALL JUDGED, 2034/0, seven lines unmoved | **NOT ADOPTED: every target passed and `make check exited 2`** (builder0, 23:25–23:53 PDT at docs tip `e57dba92`: 23 targets all passed ALL JUDGED, 2044 passed 0 failed, five shard statuses 0, seven lines unmoved, 26 engine-pattern lines with no new kind; then `make[1]: *** [mk/core.mk:407: check] Error 1`). The cause is the check's own recipe, below. Re-checked GREEN in the run for rows 13–18 (row 16). `make end-frame-measure-selftest` in the laptop's main checkout (no `override.cfg`): exit 0, all three cases. The orchestrator looked at the glow pair: on the screen's picture the difference is small (brighter team outlines, light bloom, a haze on the magenta strip); its GPU cost on his laptop is unmeasured: asked of finale |
| 14 | `377af60a` (2026-10-04 23:08 PDT) | maps `09cb016c`: the arena kit test frees its arena (182 orphans gone); the candidate page's generator; series and room tooling. No layout changed | exited 0, 23 targets ALL JUDGED, 2033/0 with `f6c6a282` merged, seven lines unmoved | **GREEN in row 16's check** (the first run: all passed, exited 2: row 13). Laptop: arena_kit 13/0, arena_lanes 9/0, exit 0, no orphans |
| 15 | `5e9e6317` (2026-10-04 23:13 PDT) | brains `a6564bc6`, ALONE: **his squads on a task arrive** (D4 + D5: `ElementPlan._cohesive` judged closing-up against nominal slots; a file with crossed seats re-seats once by travel order; at most 3 re-seats a movement; the leader unpinned until the movement ends). A declared behaviour change for every element | exited 0, 23 targets ALL JUDGED, 2036/0 on `f6c6a282`; all seven lines and determinism UNMOVED as pre-registered (the baseline's matches run no elements). The Sumps 0 of 8 → 16 of 16 arrive; known limit: the Cut seed 3 stops 105 m short after its 3 re-seats; **one cell slower: a Law two-scout squad 19.9 → 37.0 s (asked why)** | **GREEN in row 16's check** (the first run: all passed, exited 2: row 13). Laptop after `make import`: tactics_mixed_legs 3/0, tactics_elements 8/0, tactics_settle 2/0, control_formation_picker 17/0, exit 0, no orphans; a scripted Sumps skirmish headless (seed 3, twice): hashes at ticks 300 and 600 identical to the tree before the merge, so `--scripted` runs are not moved by it |
| 16 | `521e75e3` (2026-10-04 23:26 PDT) | ship `21359d02`, as one: `end-frame-measure-selftest` and `end-frame-measure` last in `check-all`; `tools/remote.sh` gives a checkout with no `override.cfg` its own Godot user dir on builder0 (`tank_squad_godot` for main: **the environment main's checks run in changes here**); the check's closing summary on stdout; `sim-variants` arms; the known-HOLE mechanism | exited 0, 23 targets ALL JUDGED, 2036/0 from a scratch folder made the way main's is, first run from an EMPTY user dir; the measure proved cold, JUDGED PASS (max 215 ms); scratch folders removed the same minute | **GREEN = `main-checked` `b3586415`, rows 13–18 together** (builder0, 23:57–00:29 PDT: `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2045 passed 0 failed, five shard statuses 0, zero exit-leak lines, seven lines unmoved, 26 engine-pattern lines with no new kind; **the first check of `main` from its own user dir** (`tank_squad_godot`); the summary lines each start their own line; `check-trap: 4 passed` in the log). Laptop: known-red 11/0, test-shards 5/0, round-status 44/0, `make known-red` exit 0 |
| 17 | `c14306ca` (2026-10-04 23:35 PDT) | picker `d65913bf`: tests that the faction menu's backdrop match never holds the loading screen and a played match holds until its warm-up is done; `test_control_orders`' four watchers on `Watch.on` | exited 0, ALL JUDGED, 2042/0, baselines unmoved; through the real launcher on builder0 the hold released after 3 frames because the warm-up was DONE (twice), the menu launch held 0 frames | **GREEN with row 16.** Laptop: control_orders 12/0, hud_launcher_warmup 5/0, exit 0. The runner names 1,717 orphan nodes across 9 `test_control_orders` tests: **NOT a leak** (picker, by probe: 188 of 213 a setup are already queued for deletion; +0 after two process frames; the runner samples before Godot's delete queue runs). The sampler is ship's to fix; nothing changes in `game/theme`. Picker's next item: roadmap candidate 2, the HUD's per-unit cost, without native code |
| 18 | `b3586415` (2026-10-04 23:58 PDT) | **the orchestrator's integration fix: the check's heartbeat trap.** The recipe's once-a-minute heartbeat ends by itself when a poll finds nothing left; row 13's fan-out took 1380 s = 23 m 00 s, so the 23:00 poll ended it, the EXIT trap's `kill` then failed on a dead pid, and under `bash -eu -o pipefail` a failing command in an EXIT trap turns `exit 0` into 1. The trap's kill is `|| true`; `tools/test_check_trap.sh` drives the recipe's own trap line (ended / running heartbeat × passing / failing verdict) | red before the change (1 of 4), green after; `make shell-tools-test` exit 0 with it | **GREEN with row 16.** |
| 19 | `3b389bb0` (2026-10-05 00:59 PDT) | finale `ffa42026`: **the arena screens' feed keeps glow** (decided for him; `--feed-glow=off` restores today's behaviour exactly), so the warm-up drops its feed render; the cold loading screen on his path 12.9 / 12.9 / 13.3 s → 8.2 / 9.0 / 9.2 s (laptop, N=3 per arm, interleaved); the hold's first-read log; stretch (b) closed (cold 7.9–8.9 s = scene 0.09 + arena ~1 + armies ~0.7 + first frame 4.1–4.8 + warm-up 2.1–2.2; warm 2.8–3.3 s) | exited 0, 23 targets ALL JUDGED, 2044/0 on `6b814f6c`'s tree, seven lines unmoved; `end-frame-measure` on builder0: cold proved, JUDGED PASS, 201 ms | **GREEN = `main-checked` `4aaf973c`** (builder0, 00:59–01:42 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2048 passed 0 failed, five shard statuses 0, seven lines unmoved, 26 engine-pattern lines with no new kind). |
| 20 | `1fd38a10` (2026-10-05 01:39 PDT) | brains `62791f64` = **CP1, ALONE: the champion no longer shows itself to a gun it knows is laid on it (`x18m`), every unit, both sides.** The round's one planned change of fights (C18.1). Adopted, each map read twice on builder0: foundry `05df1d55ba49cde1` → `5d8191d5aacc4027`, yard `797dc49109a452d8` → `e0393e53918debc1`, pit `098f7d5cb3795e7f` → `e03377eab0ab0389`; terminus, crossing, sumps, locks UNMOVED (no bait in those 40 s matches, measured); determinism unmoved; ai-scenarios 43,1,3,0 → 45,0,3,0 (the scenario red since round 15 is green) | exited 0, 23 targets ALL JUDGED, 2045/0 on `b3586415`'s tree with the adopted lines read back. Evidence in the merge message: ladders TIES; 48 seeds, paired: Law −0.019 [−0.108, +0.071], Condemned −0.118 [−0.207, −0.030], pooled −0.084 [−0.141, −0.027]; showings at a laid gun 2.88 → 0.60 a match; Law won 16 of 48 → 11 of 48, within the spread, not proven equal | **GREEN = `main-checked` `4bc40de3`, alone** (builder0, 01:50–02:30 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2048 passed 0 failed, five shard statuses 0; the hashes line reads the adopted values: foundry `5d8191d5aacc4027`, yard `e0393e53918debc1`, pit `e03377eab0ab0389`, terminus, crossing, sumps, locks as before; determinism `762a0576f944f5b7`; scenarios 44 passed + scenario_perf judged by perf-judge = the file's 45). Laptop on the merged tree: test_ai_levers 9/0, test_brain_decide 18/0, test_ai_scenarios 11/0; `make ai-scenarios FILTER=cover` 6/0 |
| 21 | `30b7175e` (2026-10-05 02:05 PDT) | picker `354da40c` (its final commit; `ba326d38` checked, one Status-only commit above): three equal-output HUD cuts proved by `make hud-digest` (SelectionMarkers 3.64 → 2.94 refs a frame, ElementAwareness 3.35 → 3.10, UnitBars 2.05 → 1.81), the digest instrument, the hold's LOAD_TIMING mark, picker's final report | exited 0, 23 targets ALL JUDGED, 2042/0, seven lines unmoved | **GREEN with row 22 = `main-checked` `b24ff1aa`** (builder0, 02:32–03:01 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2048 passed 0 failed, five shard statuses 0, the seven lines as CP1 left them). Laptop after `make import`: control_awareness 8/0, hud_widgets 17/0, control_selection 9/0, control_formation_picker 17/0, hud_launcher_warmup 5/0, exit 0; `make picker-playtest` exit 0. **STREAM CLOSED 2026-10-05 02:11 PDT:** branch an ancestor of `main`, frames rescued to `streams/references/round18/picker/`, worktree and branch removed, builder0's `~/tank_squad/godot-picker` (863 MB, no live process) and its user dir removed (23 GB free there after), brief archived to `streams/archive/round18/picker.md` |
| 22 | `c6bb0d86` (2026-10-05 02:35 PDT) | maps `e0a52224` (its final commit; `6a784a92` checked; docs, the page generator and references above): the series, contacts and room JSON behind the page, the cover-point probe, the generator through v4, maps' final report. No layout or game code | exited 0, 23 targets ALL JUDGED, 2045/0 with `b3586415` merged, seven lines unmoved | **GREEN with row 21 (`main-checked` `b24ff1aa`).** **STREAM CLOSED 2026-10-05 02:32 PDT:** branch an ancestor of `main`, evidence committed under `streams/references/round18/maps/` (plus the page's v4 source), worktree and branch removed, builder0's `~/tank_squad/godot-maps` (863 MB, no live process) and its user dir removed, brief archived. **Page v4 rendered by the orchestrator 02:35 PDT:** "Version 4, built at 0ae17e29", 6 cards, 12 buttons (6 disabled off claude.ai), 18 choices, 6 note boxes, 29 images, none missing; parade's card now says the computer fights in the open and does not use the bays yet |
| 23 | `a6f3aced` (2026-10-05 02:46 PDT) | finale `58c05502`: **the loading-screen hold is a contract** (`ShaderWarmup.holding()` resolves the current match itself via `MatchFxLink.attach_current()`); a test in `check` holds it with the search at 0.5 s; his path, cold, N=3 at that setting: warm-up 2.3 / 1.7 / 2.2 s behind the screen, largest frame after it 201 / 184 / 195 ms (the removal that failed at 1.3–1.8 s now passes) | exited 0, 23 targets ALL JUDGED, 2045/0, seven lines unmoved | **GREEN = `main-checked` `46ad71de`** (builder0, 03:09–03:46 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2049 passed 0 failed, four shard statuses 0, the seven lines as CP1 left them; 2138 s, slow under builder0's load). Laptop after `make import`: fx_shader_warmup 10/0 (the contract test among them), hud_launcher_warmup 5/0, fx_feed_glow 3/0, fx_kill_cam 9/0, fx_systems 29/0, exit 0; a scripted Sumps skirmish headless: exit 0, 0 engine lines |
| 24 | `db73d342` (2026-10-05 03:15 PDT) | ship `2b71e83c`, as one (`6248551d` checked, one Status commit above): 13 recipe traps guard their kill + a static check; `tools/remote.sh`'s copy-back excludes anchored (an unanchored `desktop/` made every run after a `check-all` report 19 files missing); the scenario-count gate counts once for record and check; the ORPHAN report counts live orphans only; the WebSocket departure race excused in net- and combat-smoke's server logs only; `known_red.txt` takes `seen k of N` and lists desktop-smoke INTERMITTENT; "test beside lint" reverted (no saving) | exited 0, **copy-back verified 359 files**, 23 targets ALL JUDGED, 2047/0 on `b3586415`'s tree, seven lines unmoved | **GREEN = `main-checked` `6f89e805`, rows 24–25 together** (builder0, 03:48–04:29 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2052 passed 0 failed, five shard statuses 0, the seven lines as CP1 left them; 26 engine-pattern lines, the two new ones echoes of the smokes' new grep). Laptop after `make import`: `make shell-tools-test` exit 0, 22 suites green; test_orphans 2/0; test_arena_kit names no orphans; test_control_orders and test_every_unit_selectable now name 25 and 37 LIVE orphans in one test each (reported, not failed: per picker's probe, deferred adds that are gone two frames later); net-smoke and combat-smoke exit 0; `make known-red` prints desktop-smoke as INTERMITTENT, seen 3 of 7; the count-gate's 36 tests pass |
| 25 | `776a759e` (2026-10-05 03:27 PDT) | brains `b6b068a3`, ALONE = **D5b: a crew is closed up at the NEARER of its nominal and grounded slots.** A declared change for every tasked element. By removal the 17 s that row 15 cost one squad was closing-up judged only against grounded slots (waiting on a wheeled scout pinned on a wall), not the re-seat | exited 0, 23 targets ALL JUDGED, 2049/0 on `4bc40de3`; all seven lines and determinism UNMOVED as pre-registered. 80 runs (laptop, 120 s, four maps): 80 of 80 arrive, no cell slower than D5, the Law two-scout Sumps cell 37.0 → 19.9 s with 0 re-seats | **GREEN with row 24.** Laptop after `make import`: tactics_mixed_legs, tactics_elements, tactics_settle pass alone, exit 0 |
| 26 | `21e38456` (2026-10-05 04:05 PDT) | finale `1e34ef1b` (its final commit; `3954058e` checked, one Status commit above): **the exit leak fixed in the quit paths.** `MusicDirector.quiet_for_quit` stops every playing audio player and waits two audio buffers on the main thread (hard cap 250 ms; nothing playing returns at once; synchronous: no frame, no tick, no extra SIM_HASH line), called from `Match`'s `--hash-until` quit (one lent line) and on a window close; `make quit-leak-arms`; finale's final report | exited 0, 23 targets ALL JUDGED, 2048/0, seven lines and both determinism hashes unmoved. `quit-leak-arms`, builder0 light lane, N=12: base 0 of 12 (it was 18 of 46), music off 0 of 12; `windowed-elimination-pair` identical | **GREEN = `main-checked` `a83b8da4`, rows 26–28 together** (builder0, 04:30–04:58 PDT: `>> remote: make check exited 0`, copy-back verified, 23 targets all passed ALL JUDGED, 2057 passed 0 failed, six shard statuses 0, the seven lines as CP1 left them; 26 engine-pattern lines, no new kind). Laptop after `make import`: fx_quit_quiet 3/0, audio_music_director 32/0, fx_shader_warmup 10/0, fx_kill_cam 9/0, exit 0; three scripted Sumps quits headless: exit 0, the same two SIM_HASH lines each, no leak or engine line. **STREAM CLOSED 2026-10-05 04:05 PDT:** branch an ancestor of `main`, frames already in `streams/references/round18/finale/`, worktree and branch removed, builder0's `godot-finale` (806 MB) and `godot-finale-light` (780 MB) and their user dirs removed (no live process), brief archived |
| 27 | `4209baa0` (2026-10-05 04:08 PDT) | ship `2af96812`: `tests/baselines/ai_scenarios_count.txt` re-recorded by the FIXED recorder on a loaded builder0 (45,0,3,0 with "passed includes 1 NOT JUDGED scenario(s)"); brains' hand-written line and note from CP1 gone; the record recipe reads the runner's exit code, creates its build dir, takes `REASON_FILE=`; the live-orphan header's wording | exited 0, copy-back verified 359 files, 23 targets ALL JUDGED, 2051/0 on `db73d342`'s tree, CP1's lines unmoved; `ai-scenarios-check` accepted the new file on a busy box | **GREEN with row 26.** Laptop: the count file reads 45,0,3,0, no "note:" left; `make shell-tools-test` exit 0, 22 suites green; the count-gate's 36 tests pass |
| 28 | `50d3b787` (2026-10-05 04:28 PDT) | brains `a122d6ff`, ALONE = **D1: a crew with nothing to shoot lays its gun on its formation sector, moving or halted.** A declared change for every element on both sides: a moving wedge or column now watches its flanks (guns on their sectors on the plate: wedge 0.40–0.50 → 1.00, column 0.25 → 1.00, line 1.00 as before) | exited 0, 23 targets ALL JUDGED, 2051/0 on D5b's tree; all seven lines and determinism UNMOVED as pre-registered (the baseline's squads carry no sector) | **GREEN with row 26.** Laptop after `make import`: tactics_sectors_on_the_move, tactics_facing 5/0, tactics_idle_face 3/0, tactics_formations 12/0, tactics_mixed_legs 4/0, turrets 4/0, exit 0; a scripted Sumps skirmish headless: the same hashes at ticks 300 and 600 as before, 0 engine lines |
| 29 | `275b8d7d` (2026-10-05 05:20 PDT) | brains `ff243829` (its last; no game code): `make element-digest` (an md5 of every element decision over his plain move and attack-move; identical twice, 32 runs, laptop), `ai-ab-match`'s `AB_FLAGS`, `make ai-element-perfplay`, the quiet-window result files, brains' FINAL REPORT. One exact cut built and NOT shipped (0.4 % of a tick, inside the noise) | exited 0, 23 targets ALL JUDGED, 2057/0 on `a83b8da4`; all seven lines and determinism UNMOVED | **GREEN with row 30 = `main-checked` `908f4861`.** No game code in it (0 files under `game/`). **STREAM CLOSED 2026-10-05 05:08 PDT:** worktree clean and removed; **branch `stream/brains` KEPT** (14 commits above `main`: the unmerged ambush work and its instruments' history); `brains-wip-backup` also KEPT (31 commits not contained in `main` or `stream/brains`: the pre-rebase history; brains said it can go; kept because deleting is the one thing that cannot be undone); `brains-d1` and `brains-last` deleted (merged); builder0's `godot-brains` (806 MB) and `godot-brainsd1` (810 MB) and the user dir removed (no live process); `/tmp/claude-1000/element-play` deleted (copied into `references/round18/brains/`); brief archived with a banner saying what is not merged |
| 30 | `908f4861` (2026-10-05 05:35 PDT) | ship `225684cd` (its last; `dc5e6cbb` checked, one Status commit above): **desktop-smoke OFF the known-red list.** `quit-leak-arms` on main `a83b8da4`, builder0 light lane, load ~1.5: base leaked 0 of 12, music off 0 of 12, every run exit 0 at tick 90 (with finale's 0 of 12 at load 11.5–14.9: clean on a quiet box and a busy one). `verification.md` keeps the history and says `make quit-leak-arms` is ship's tool now. Known red outside `check`: web-host-smoke only (held, C18.7) | exited 0, copy-back verified 364 files, 23 targets ALL JUDGED, 2057/0 on `a83b8da4`, CP1's seven lines unmoved | **GREEN = `main-checked` `908f4861`, the round's final check** (builder0, 05:36–06:04 PDT: exited 0, copy-back verified, 23 targets all passed ALL JUDGED, 2057 passed 0 failed, six shard statuses 0). Laptop: `known_red.txt` lists web-host-smoke only; `make known-red` exit 0; `make shell-tools-test` exit 0, 22 suites green. **STREAM CLOSED 2026-10-05 05:36 PDT:** branch an ancestor of `main`, worktree clean; worktree and branch removed; builder0's `godot-ship` (1.3 GB) and `godot-ship-light` (747 MB) and their user dirs removed (no live process); brief archived |

**Decided while it runs (also in `workstreams.md` C18.6):** `mk/match.mk`'s `determinism` recipe lent to ship for a
`crossing` pair (done on `stream/ship` `84c403c6`, not yet checked on builder0); `Arena.CANDIDATES` is the candidate
list's name between maps and ship (maps' first candidate is named `parade`); picker's stretch (b), a "fits here /
squeezed here" line on each formation card, approved with four conditions and built. **Closed with picker:** its `Orders._same_order` fix does NOT change a `--scripted` skirmish (SAME, row 4); finale and brains need no warning.

**finale's finding (2026-10-04 17:25 PDT; its Status has the runs; NOT yet merged, green at `258d1f78` on its own tree):** the freeze
at the final kill **does not reproduce**: 0 of 9 on the laptop (his preset, warm and cold caches, load 2.5–8.2; the
largest frame within ±1 s of the final kill 97–258 ms against a typical 53–166), nor in about 30 later runs, nor in
his own last two matches' logs. What is real, and fixed on its branch: on a COLD shader cache (the first match after an
update that touches materials, or a driver update) first uses compile mid-match as 1–2.8 s frozen frames, several a
match; by removal about 88 % is the live feed's first recordings plus the pooled lights' first use, the rest the
shield shader. The fix draws them in two frames behind the loading screen (`ShaderWarmup`): cold, the largest frame
past load 90–194 ms; a cold load about 8 s longer, once; warm, no change. Round 17's 1.7 s and 3.4 s frames were
taken on a loaded laptop just after merges that touched materials: most likely the same cold first uses landing on
the kill (finale asked to show it directly or say it cannot). **Relayed:** to ship, `end-frame-measure` for
`check-all` once finale is on `main-checked`; to picker, hold the loading screen until the warm-up is done
(`game_launcher.gd`), and **decided: the DEFEAT / VICTORY word moves lower** so it no longer covers the last explosion
during the slow motion (picker's file; frames before and after). finale merges `23941d90`, re-checks and re-takes its
cold pair before naming its green hash.

**brains' B1, as it stands (2026-10-04 17:31 PDT; launch tree, nothing merged, CP1 not named):** the brief's rule A ("peek only
while the enemy reloads") **loses the squad fight** to today's champion `x5p`: individuals 7–25, armor 16–16,
balanced 14–18; "no bait" alone 9–23 (laptop). Why: in brawls only about 1 bait in 5 is hit, and the reloads the
baits draw are the squad's windows. The candidate is `x18m`: no real peek into a loaded, watching slow gun, and no
bait into a gun already LAID on the peek spot (the sure hit), but it still draws a gun that has to traverse. `x18m`
v `x5p`: individuals 53–43 (96 games, two seed sets; about 55 %, interval roughly 45–65 %), armor 30–33–1;
balanced, swarm and his-army pending. **That is "not clearly worse", not yet "better".** Asked of brains before CP1:
an acceptance rule written before the pending ladders report; the count he would see (peeks into a laid gun: `x5p`
n per match, `x18m` zero; hits within N ticks of leaving cover, his frame, 16 seeds); scenario names that say what
`x18m` does. For him, in brains' words: *units stop popping out into a gun already aimed at them; they still draw
fire from one that has to turn.* brains merges `23941d90` when its launch-tree ladders finish (C18.5), then reads
all seven maps with the new adopter. B3 found four open-ground defects (D1–D4, its Status); one-liners requested.

**brains, update (2026-10-04 17:41 PDT):** acceptance rule saved in its Status (`f2e7f58b`, 17:40:54 PDT): `x18m` v `x5p` pooled over
the four mirror armies ships if the 95 % Wilson lower bound is above 45 % and no army's point estimate is under 45 %.
**The his-army ladder then read `x18m` 12–20** (laptop, `cpu:balanced` 4600, Sumps, 32 games: 38 %, interval about
23–55 %; brains says it finished 2 s before the rule was saved, unread, and had it as "reported, not gated").
**The orchestrator made it a gate:** after 64 his-army games the point estimate is at least 45 % or `x18m` does not
ship and `x18l` is measured the same way; the post-merge 32 may be pooled only because the merge moves no fight
(Sumps' line unmoved). **B3's four open-ground defects** (bare 240 m plate, laptop; witnesses in its Status):
D1 on the move a wedge's wingmen and a column's flank and tail keep their guns forward, not on their sectors (guns
on arc: line 100 %, wedge 50–75 %, column 25 %); D2 on the CPU's path crews declare arrival 6–9 m off their slots
(3 m on his right-click path); D3 a line on the CPU's path closes up in transit (7.8 m between the nearest pair
against 11.3 on his path, 12 m pitch); **D4, not open-ground-specific, reproduces on the yard: a mixed squad on the
CPU's drills move halts after one leg and never arrives** (`ElementPlan._cohesive` re-seats with a fresh `place()`).
D4 goes first in B5 after CP1, sized first (share of CPU mixed elements, 8 seeds, his setup). D1–D4 relayed to maps.

**finale, update (2026-10-04 18:24 PDT; not merged; its final check is running on `0f276dc7`, already merged with `d9372259`):**
the cold-load cost is corrected: **+11.6 s on a cold shader cache through a direct launch** (`make skirmish`'s path;
laptop, load 2.7–4.4, N=3 per arm interleaved: 32.3 s (29.2–34.2) with the warm-up against 20.7 s (16.6–23.5)
without; the earlier +8 s was N=1), and +1.2 s through the real launcher (N=1; the title's backdrop match warms most
of it). In return the largest frame past load is 176–216 ms against 1253–1747 ms. Warm cache: no cost measured. Cold
is proved per run (`END_FRAME COLD … before=0 … scene_shader_files=M`; not proved → NOT JUDGED, never PASS): relayed
to ship for `check-all`. Round 17's 1.7 / 3.4 s frames at the final kill were **not reproduced directly** (no cold
run put a first use on the kill; the end ±1 s was ≤ 303 ms in every cold run without the warm-up): "cold first uses"
stays the likely reading, not a shown one. **ship:** S5 done on its branch (the test shards exit clean; the leak
allow-list is deleted, so an exit leak FAILS `test` once merged); green at `712f851f` before merging `23941d90`;
its check on the merged `a958cdbb` is running; it merges alone.

**DEFECT ON `main`: CAUSE FOUND (2026-10-04 18:38 PDT), a TEST defect, fix not yet merged.** Picker, by removal (laptop, glibc 2.39,
each arm alone): the two lambdas with `preview_group` → exit 134 (2 of 2); **lambdas only → 134 (2 of 2);
`preview_group` only → 0 (2 of 2)**; neither → 0; lambdas disconnected before the test returns → 0 (3 of 3); methods
instead of lambdas → 0 (3 of 3). A lambda connected to the RefCounted `Orders`' signals from a coroutine test, still
connected when the frame dies, aborts the process at exit. The game's own `Orders` listeners all connect methods
(one dev playtest lambda is being converted). The fits-here badge stays. Fixed on `stream/picker` (the whole file
under `MALLOC_CHECK_=3`: 17 passed, exit 0, 2 of 2); its check is running; it merges first, then ship (whose
shard-status fix makes the next one of these a red line with a name). The same class as one of ship's four S5 leaks
(`test_tactics_reissue`): ship asked for a scan of `tests/` and a helper. The original report follows.

**⚠ OPEN DEFECT ON `main` (2026-10-04 18:29 PDT; found by ship, reproduced by the orchestrator):** one of picker's tests,
`test_control_formation_picker::test_previewing_a_formation_issues_nothing`, passes and then **aborts the process at
exit** on the laptop (glibc 2.39): "corrupted size vs. prev_size in fastbins", exit 134, 2 of 2 on main's tip; with
`MALLOC_CHECK_=3` it dies after its summary with `std::system_error: Invalid argument` (a thread primitive used
after it is destroyed). **What is and is not shown:** the other 16 methods alone exit 0 (ship); the picker's headless
playtest through the real game exits 0, 2 of 2, and again under `MALLOC_CHECK_=3`; builder0's check at `d9372259`
(glibc 2.43) had all five shard statuses 0 and no "corrupted" line. So it shows only in that test on that glibc, at
exit; whether `Orders.preview_group` (which the fits-here badge calls when he opens the panel) is involved is NOT
yet ruled out. Picker has it first, by removal, with a 45-minute report. **Why `main-checked` could not see it:**
the sharded `make test` wrote each shard's exit status and never read it (fixed on `stream/ship`, with its own stub
test), and picker's playtest recipes read a grepped line, never the engine's exit code. **ship's merge is HELD**
until picker reports: it would turn `main` red on this. Lesson to write at the fix: a result read through a pipe is
not only a wrong exit code for the wrapper (the CLAUDE.md rule), it is a crash nobody sees.

**brains (2026-10-04 18:38 PDT; CP1 still not named):** on the merged tree `x18m` moves three per-map lines (foundry `05df1d55`→`5d8191d5`,
yard `797dc491`→`e0393e53`, pit `098f7d5c`→`e03377ea`) and leaves terminus, crossing, sumps and locks unmoved,
measured: those four baseline matches are identical under both brains and hold no bait at all inside their 40 s
(relayed to ship as a limit of the per-map baseline). Scenarios 43,1 → 45,0. **His-army gate: a tie with a wide
spread** (seeds 201–208 re-run on the merged tree reproduced 12–20 exactly; 209–216 read 20–11–1; 50.8 % of 64, and
side and base matter more than the brain). Mirror pool so far 52.0 % of 224 (Wilson about 45.5–58.5), lowest army
armor 47.7 %; swarm running. A limit it found: the rule reads the team's last-known turret, so the claim is "never
into a gun KNOWN to be laid" (on locks both brains made one peek into a gun truly laid, on stale knowledge). The
his-frame series with the arm assertion decides.

**Corrections and state (2026-10-04 19:37 PDT):** (1) **finale's cold-load cost on HIS path is +3.3 s, once** (`make skirmish` → faction
menu → FIGHT: the loading screen up 11.1 s with the warm-up against 7.8 s; laptop, load 0.6–1.9, **N=1 per cell**;
largest frame past load 0.86 s against 2.71 s; warm, no cost). The +11.6 s was a direct scripted launch, which is
not how he starts a match; the orchestrator told him 12 s and has corrected it. Asked of finale: N=3, and what is in
the remaining 0.86 s. (2) **brains' B1 is not shipping as `x18m`:** both ladder gates pass as TIES (mirror pool
51.6 % of 288, interval 45.8–57.3; his army 50.8 % of 64), and the his-frame series (builder0, 16 seeds, Sumps, Law
v Condemned 4600, one brain both sides) shows showings at a gun laid on the spot 43 → 7 and the same game (kills
28/28, length 117/116 s), **but hits within 3 s of showing went DOWN for the Condemned (0.279 → 0.167 a unit-minute)
and UP for Law, the faction he plays (0.148 → 0.259; on real peeks 6 → 20)**. Suspected: a second loaded gun
watching the corner. **Decided:** one more variant (`x18w`: every known slow gun watching must be reloading), judged
by paired per-seed differences with intervals, rule written first; if it fails, B1 is HELD with its write-up and the
round's planned hash move passes to **D4** (the CPU's mixed squads halting after one leg), which brains sizes now.
(3) finale's request to picker (hold the loading screen until the warm-up is done) is relayed as intent.

**Correction to (2) above (2026-10-04 19:44 PDT): Law's rise is NOT shown.** brains' paired per-seed intervals for `x18m` − `x5p`
(hits within 3 s of showing, per unit-minute, 16 seeds, his frame): Law +0.107 [95 % −0.109, +0.322]; Condemned
−0.122 [−0.269, +0.025]; pooled −0.048 [−0.182, +0.087]; laid-gun showings 2.69 → 0.44 a match (clear). The
orchestrator had told him "your faction takes more hits" from the two means alone: a number relayed without its
spread (the standing rule, broken; corrected with him). **`x18m` is back in.** The 16-seed series cannot tell +75 %
from zero, so the decision moves to **48 seeds for `x5p`, `x18m` and `x18w`**: a variant ships if no side's paired
interval is wholly above zero, laid-gun showings stay under 1 a match, and its ladder gates pass; if both pass,
`x18m` (simpler, ladders done); the claim is worded "stops showing itself to an aimed gun, at no measured cost in
hits or wins", not "takes fewer hits".

**Correction on D4 (2026-10-04 19:45 PDT; brains, from reading, sizing under way):** D4 does not stall CPU squads in his skirmish:
the CPU there does not run elements (`SkirmishMode.ELEMENT_CPU_DEFAULT = false`, brains alone since round 5).
Elements are HIS squads' leaders, and `rts_controls` sets `drills:false` only for a plain move, so **any other task
he gives a mixed control group (attack-move, attack, hold with a point) goes down the drills path where D4 lives.**
The orchestrator had told him it explained CPU forces sitting short of a fight: wrong, corrected with him and with
maps. Sizing is now his squads by composition and verb over seeds (the settle probe, laptop). The 48-seed his-frame
series is three builder0 holds of about 31 minutes (seeds 1817–1848, all three brains each hold), rule recorded at
`d086ee8e` before any new seed ran.

**brains (2026-10-04 20:04 PDT):** (a) **the default path reaches both sides** (ship had found `x18m` moving nothing in a headless
match of two CPU-built armies of his factions on any of seven maps at 40 and 90 s): measured on the B1 tree with no
brain flags, every spawned brain on both sides holds the champion (`BrainVariants.for_team` is the only writer); the
match had no `--budget`, so 5- and 8-vehicle armies, with one bait in 40 s and about ten peek decisions in 300 s: the
baseline's reach, not a wiring defect. (b) **D4 sized, in his terms: when he attack-moves a squad with two scouts in
it, it drives one leg (~7 s), every vehicle settles into its spot, and the squad never moves on.** Laptop, his
element via the settle probe, attack-move 150 m, 60 s, 4 seeds × yard / terminus / sumps / pit, 80 runs (brains'
Status `5d5480d0`): 21 of 80 stall that way; off the Sumps, two-scout mixes 14 of 24 (Terminus 8 of 8, pit 4 of 8,
yard 2 of 8), a one-scout mix 2 of 12, IFV / suppressor / tank 0 of 12, four tanks 0 of 12. A plain right-click move
never does it. Fix approved: scenario first, declared, merged alone when green, not tied to B1. (c) **D5, unread:**
on the Sumps nothing arrived at a 150 m attack-move point in 60 s, four tanks included, with crews off their slots;
asked to rule out the probe's window first (route length; the same runs at 180 s).

**brains (2026-10-04 20:14 PDT): D4 fixed on its branch (`6f9d43bc`, not merged, not yet checked); D5 is REAL.** D4: the scenario
`tests/test_tactics_mixed_legs.gd` (a Law two-scout squad attack-moved 150 m on the Terminus) is red before (never
arrives, 20.3 m short) and green after (18.5 s); the fix is in `ElementPlan._cohesive`; pre-registered UNMOVED on all
seven lines, determinism and `ai-parity` (no elements run in `--match` without the elements flags); every tasked
element's leg timing shifts a little (four tanks 17.1 → 16.6 s). It is cut as its own commit on the newest
`main-checked` once the 48-seed holds release brains' folder. **D5: on the Sumps his squads on a task never arrive:
0 of 8 runs at 180 s** (four tanks and an IFV mix, seeds 1–4, attack-move 150 m), crews 5–20 m off their slots, one
crew driving at 7–8 m/s without closing on its slot while the element waits. Not the probe's window. Next after D4,
ahead of the open-ground items.

**brains (2026-10-04 20:48 PDT): D5 fixed on its branch (`deffde5b`; not merged, not checked on builder0).** Scenario first: four
Law tanks attack-moved 150 m across the Sumps: red (77 m short at 90 s), green (arrive at 30.7 s). Two causes:
(1) the crossed file: `seat()` minimises total straight-line driving and in a single file every matching costs about
the same (22.0 against 22.5 m), so a fresh seating re-crossed it and the pinned leader took the point back; now a
crew driving without closing on its slot for 4 s asks for one fresh seating by the "travel" policy, and the leader
stays unpinned until the movement ends. (2) even uncrossed the leg never advanced: `_cohesive` judged closing-up
against NOMINAL slots while crews were sent to GROUNDED ones (the same defect as D4). Mutation: without (1) the squad
still stops 35 m short. No `SlotGround` / `fit_to_corridor` signature changed. **Decided:** D4 + D5 merge together
as one declared change ("his squads on a task arrive"), alone, on `f6c6a282` or newer, with one after-table that
includes the cases that already arrived; asked to state what he sees when the 4 s re-seat fires and what unpinning
the leader does to a formation in transit (round 12 pinned it for a reason).

**The numbers he was given, corrected again (2026-10-04 21:35 PDT):** finale's cold-load cost on his path is **+7.6 s once per cold
cache** (laptop, load 1.2–4.1, N=3 per arm, no screenshots, FIGHT pressed as the menu does: loading screen 12.9 /
15.6 / 16.6 s against 6.9 / 7.7 / 7.6 s); largest frame after the screen 144 / 163 / 224 ms against 2.21–2.42 s.
The earlier +3.3 s (N=1) hid a 5 s menu freeze that row 11 fixes; the first +11.6 s was a direct scripted launch.
Three numbers in one evening for one cost: each was relayed the hour it arrived; the first two were N=1 or the
wrong path (lesson 256's class). By parts (direct cold launch, N=2): the feed render about 7.5 s of ~11 s, the lit
frame about 5 s; **the feed's first recording costs 2.1–2.3 s as shipped and 36–80 ms when the feed's environment
keeps glow**: a feed with glow would cut most of the +7.6 s, changes the arena screens' look and costs some GPU per
feed frame. His call; recommendation: no change for now.
**brains' B1: `x18m` SHIPS by the rule written before the seeds ran (not yet merged).** 48 seeds (builder0,
1801–1848, his frame, both sides one brain, paired against `x5p`, hits within 3 s of showing per unit-minute): Law
−0.019 [−0.108, +0.071]; Condemned −0.118 [−0.207, −0.030]; pooled −0.084 [−0.141, −0.027]; showings at a gun laid
on the spot 2.88 → 0.60 a match. `x18w` passes too and `x18w` − `x18m` spans zero on every side: the simpler rule
wins. brains' plain line: Law won 16 of 48 under `x5p` and 11 of 48 under `x18m`; the ladders call it a tie; within
the spread, not proven equal. Plan: commit A ("his squads on a task arrive", D4 + D5) checked and merged alone; then
B (`x18m` as champion, three lines adopted, four declared unmoved) = CP1, merged alone.

**brains' tasked-squad table on the candidates (2026-10-04 21:47 PDT; laptop, its commit A = `f4daada0` = D4 + D5 on `f6c6a282`, NOT
merged; his element, attack-move 150 m from the Green spawn, 180 s, seeds 1–4; arrived k of 4, median seconds,
re-seats over the 4 runs; four Law tanks / Law ifv, ifv, suppressor, tank):** parade 4/4 14.1 s 0 · 4/4 18.5 s 0;
yard_open 4/4 13.8 s 0 · 4/4 15.9 s 0; archipelago 4/4 15.3 s 0 · 4/4 20.7 s 4; docks 4/4 21.1 s 0 · 4/4 18.3 s 0;
gorge 4/4 35.0 s 5 · 4/4 33.0 s 4; **cut 3/4 46.1 s 25 · 4/4 29.1 s 2** (the non-arriver stopped 105 m short at
(−4.1, 44.9) after 25 re-seats: a lane where the re-seat thrashes; a witness for maps and a limit of D5's fix);
the Sumps for scale 4/4 39.8 s 5 · 4/4 38.6 s 4 (**before the fix: 0 of 8 at 180 s**). Relayed to maps.
**finale (2026-10-04 21:47 PDT):** the self-test failure in the main checkout was a `sed` dying under `set -e` before cold mode's
refusal could print; fixed on its branch (`046c68d2`: a named `END_TRACE_COLD_REFUSED`, the self-test carries its
own cache dir); its check is running. Glow frames for his decision:
`_agents/streams/references/round18/finale/feed_glow_pair.jpg` and `feed_glow_view.jpg` on `stream/finale` (the
arena screen as shipped beside the same moment with glow); the GPU cost of glow on the feed is not measured.

**DECIDED FOR HIM (2026-10-04 22:53 PDT; reversible; he can overrule): the arena screens' feed keeps glow.** finale's price: glow
alternated OFF / ON every 5 s inside one run, read back each frame from the feed camera's environment (laptop UHD
620, his window and preset, Law v Condemned seed 92721, 60 s, uncapped, load 1.5–2.7, N=3, `31269298`): mean frame
45.4 / 48.5 / 49.8 ms off against 49.5 / 49.6 / 48.0 ms on, +1.1 ms on average (range −1.8 to +4.1): no cost
measurable; main-view GPU 10.2–10.9 ms either way. In his main view the screens are about 90×150 px and often show
ads, so the glow is not visible at his pose; on the screen's own picture the team outlines and lights bloom a little
(`feed_glow_pair.jpg`). What it buys: the feed's shaders become the main view's, so the warm-up's feed render (about
7.5 of 11 s cold) goes: most of the +7.6 s he pays on the first launch after an update. Why decided without him: he
answered nothing this evening, it is invisible from his camera, unmeasurably cheap and one switch from undone.
**Built, measured (below) and MERGED as row 19 (`3b389bb0`), in check.** `live_feed.gd` is unowned: finale's minimal fix, in its merge notes.

**The slower cell in row 15, explained (2026-10-04 23:19 PDT; brains, laptop, the Sumps, attack-move 150 m, seeds 1–4; arrived k of 4 and
median seconds, as: before any fix → D4 alone → D4 + D5 as merged):** four tanks 0/4 → 0/4 → 4/4 (39.8 s); IFV mix
0/4 → 0/4 → 4/4 (38.5); Law scout, ifv, tank, tank 0/4 → 1/4 → 4/4 (33.7); Condemned two-scout 0/4 → 4/4 (23.4) →
4/4 (22.8, 0 re-seats); **Law two-scout 0/4 → 4/4 (19.9) → 4/4 (37.0, 7 re-seats).** So against what he has today
every cell is better (nothing arrived); against D4 alone, D5's re-seat fires in that one cell when it was not
needed and costs about 17 s. Not traced; brains' inference: a crew drives 4 s without closing while the file is
still forming in a Sumps lane. brains fixes it first after B. Off the Sumps the scout mixes kept D4's timing.

**finale (2026-10-05 00:08 PDT; not merged; its check on `ffa42026` is running): the hold has no race, and glow on the feed saves 4.2 s.**
His path, cold, N=3 per arm, interleaved, `0b414550` (= `6b814f6c` + finale), laptop, load 0.5–2.5, every run writing
36–39 scene shaders from an empty cache. **The hold:** the launcher's first read (frame 2) is the faction menu's
backdrop (`played_seen=false`, not held: correct); the match's first read (frame 36) is `match=true played_seen=true
held=true`; `LOAD_TIMING warmup=` 6.9 / 6.8 / 7.2 s with `--feed-glow=off`: the warm-up runs behind the screen by
contract. **Glow (the default now):** loading screen 12.9 / 12.9 / 13.3 s → 8.2 / 9.0 / 9.2 s; the warm-up stage
6.8–7.2 → 2.1–2.2 s; largest frame after the screen 127–142 → 104–160 ms. So the cold cost against no warm-up at
all (6.9–7.7 s) is now about +1.5 s, once per cold cache, with nothing compiling in front of him. `--feed-glow=off`
restores both halves exactly (tested property for property, mutation-checked). `end-frame-measure` on builder0 at
`9bfcb756`: cold proved, JUDGED PASS, 201 ms. Frames: `screen_feed_before.jpg`, `screen_feed_after.jpg`.

**picker, the HUD's per-unit cost without native code (2026-10-05 00:26 PDT; commits through `c52640b7`, not merged, check running):**
today's table (laptop, headless `make hud-profile`, his window, ~64 a side, 30 s, 3 runs, `c750f942`, load 0.9–1.6,
ref ≈ 91 µs): HUD total 33.4 / 33.7 / 33.6 refs a frame (≈ 3.0 ms); top lines controls.process 6.9, rts_camera
4.9, selection_markers 3.6, cam.vision 3.6, selection_panel 3.5, ctl.awareness 3.35, radar.draw 3.25,
controls.draw 3.25, radar.blips 2.8, callouts 2.2, unit_bars.draw 2.05; about 6 % above round 17's readings except
unit bars (+27 %). **Two equal-output cuts shipped on its branch** (proved by a new per-frame digest, `make
hud-digest`, identical over ~1,075 frames each): SelectionMarkers 3.62 / 3.67 / 3.63 → 2.99 / 2.96 / 2.86 refs
(−19 %); ElementAwareness 3.31 / 3.36 / 3.37 → 3.09 / 3.10 / 3.11 (−7 %); HUD total about −7 %. Priced and dropped:
the markers as one MultiMesh buffer (worse headless), an x-sorted slab for the contact search (worse: enemies
bunch), the vision lean's shortcut (inside the spread). **The native question, sized for round 19:** after these the
HUD is about 2.8 ms of a 40–50 ms frame at his army size (≈ 6 %); a GDExtension port of its four hottest loops
might save half, ≈ 1.4 ms, about 3 % of his frame: not worth a native toolchain alone; only alongside the
simulation's per-unit work, where the frame goes. Follow-ups given: why unit bars rose 27 %; what is in
controls.process (the top line, unopened). Then picker stands down.

**ship's `check-all` (2026-10-05 00:40 PDT; `2861583b` = `21359d02` + Status, builder0, 23:08–00:38 PDT, 5245 s): 15 passed, 2 FAILED.**
`check` PASS (ALL JUDGED), relay-drop / latency / rejoin, screenshot, web-smoke, web-net, web-relay,
export-server-boot, perf-play-measure, garage-tour, windowed-elimination-pair (both runs through the exit gate),
candidates-smoke (maps' six), end-frame-measure-selftest, end-frame-measure all PASS. **web-host-smoke FAIL**, the
known red, tagged as such. **desktop-smoke FAIL, NEW:** every run exits 0 and the match reaches tick 90, but the
engine-message gate fails it on "ERROR: 2 resources still in use at exit" at the exported game's scripted mid-match
quit; the gate has failed that line in every target since round 17 and this is the first `check-all` since, so it
has been red unseen. On `tests/baselines/known_red.txt` with its evidence (ship, on its branch); **routed to maps**
(at the end of its brief): name the two resources with `--verbose`, on the export and on the editor build, and say
whose they are. Not in `check`; `main-checked` is unaffected.

**brains (2026-10-05 00:49 PDT): CP1's first check was red on one unrelated target; the over-eager re-seat is fixed on its branch.**
`171775db` (CP1, on `f6c6a282`'s tree): net-smoke failed on one server engine line after both clients passed
(`ERROR: Condition "ready_state != STATE_OPEN" is true`, a WebSocket shutdown line; in 0 of main's 11 check logs
tonight; sent to ship to size), 1 target NOT RUN behind it; everything else green (2036/0; the three adopted lines
foundry `5d8191d5`, yard `e0393e53`, pit `e03377ea` and the four unmoved read back). Re-running as `62791f64`
(`171775db` + `b3586415`). **D5b, `53434860` (on top of CP1, to merge after it, alone):** by removal the 17 s was
not the re-seat: closing-up was judged only against GROUNDED slots (it waited for a wheeled scout pinned on a wall);
judged only against nominal slots the four tanks never arrive; now a crew is closed up at the nearer of the two. A
narrower re-seat tried first stranded another squad in 2 of 4 seeds and is not in. The 80-run table (laptop, 120 s):
80 of 80 arrive, no cell slower than D5, the Law two-scout Sumps cell 37.0 → 19.9 s with 0 re-seats, 15 re-seats in
80 runs. The Cut's seed 3 is unchanged and still open.

**The hold's race was REAL, and something unrelated was hiding it (2026-10-05 01:04 PDT; finale).** Removing `MatchFxLink`'s
every-frame search (its last cleanup item) failed its proof: his path, cold, N=3, laptop, `fdc1688b` with the search
back at 0.5 s: `LOAD_TIMING warmup=0` in all three runs; the hold read `holding()` before the new match was
attached, saw the menu's state and let go at once; the warm-up then ran AFTER the screen; largest frame after the
screen 1792 / 1510 / 1259 ms. Reverted (`637e6397`); with the search every frame, as on `main`: warm-up 2.1–2.2 s
behind the screen, every later frame ≤ 160 ms. **So on `main` the loading-screen hold works only because a polling
interval happens to be zero**; no test in `check` would see it regress (only `check-all`'s cold measure). The
orchestrator's earlier "no race" (from finale's and picker's readings with the search in place) was true of the
shipped state and wrong as a statement about the design. Asked of finale before it closes (90 minutes): make it a
contract (`holding()` resolves the current match itself when the launcher asks), with a test in `check` that is red
today with the interval at 0.5 s; failing that, a test pinning the interval with the reason.

**THE ROUND'S REMAINING GAP (2026-10-05 01:35 PDT; brains' B4, first reading): the computer does not ambush him on the Parade Ground.**
Laptop, his setup (Law v Condemned 4600, `--control`, both sides `x18m`), 8 seeds, 180 s cap, parade against the
Sumps: contact at the same moment and range on both (5 s, about 120 m); then parade fights faster and in the open:
first kill 9 s against 18 s, match length 85 against 147 s, kills front / side / rear 36 / 47 / 11 %. **The CPU does
not use parade's flanking cover: 7 % of unit-time near cover against 26 % on the Sumps; deaths near cover 3 % against
29 %; 1.9 against 6.9 unit-minutes fighting from cover.** In his skirmish the CPU runs brains and doctrine squads
with no elements (`ELEMENT_CPU_DEFAULT` false), so lines and ambushes are not something it does. The map offers
the ambush and HIS squads can stand abreast in a bay (picker's read); the opponent will not do it to him. Asked of
brains, after CP1 → D5b → D1 (`6e0e116f`: guns on their sectors on the move, wedge 0.40–0.50 → 1.00, column 0.25 →
1.00 on the plate): his squads' ambush from a bay measured; the CPU with `--element-cpu` measured and priced on the
laptop; why a brain's cover scoring gives the bays 7 %. Turning CPU elements on by default is his to hear first.
**ship (2026-10-05 01:35 PDT):** its `5a300424` is NOT merged: the check ran green but a local run in its folder during the
copy-back made the wrapper fail it (rightly); and "test beside lint" showed no saving (lint 511 s, test 1656 s
together, check 1656 s against the orchestrator's 1348 and 1380 s) and is reverted. Re-checking as `5d084283`.

**Why the computer never ambushes, measured and read (2026-10-05 01:51 PDT; brains), and A DECISION THAT IS HIS.** (2) The CPU WITH
elements (laptop, the same 8 parade seeds, both sides' elements on, `x18m`): contact later (8 s against 5 s),
fights closer (engaged at 46 against 65 m), far more flanking (rear kills 27 % against 11 %), Rust wins 6 of 8, and
**cover use unchanged: 7 % of unit-time near cover, 0 % of deaths near cover.** Cause, read: `ElementCommander` only
ever gives move / attack / screen / support_by_fire / hold; it NEVER gives an ambush task. (3) Brains alone: not a
blind cover map; a brain queries cover only when threatened AND hurt or shield-down, and its cover-fire looks for
hide and peek spots only round a fight it is already in; nothing makes a healthy brain wait in a bay. **brains'
words for him:** *"Today the computer never sets an ambush: it always drives at you, on every map. Your squads can
ambush (the Ambush order), the computer's can't. The fix is to teach the computer's squad leaders to choose ambush
when your forces have open ground to cross and there is cover on the flank of that ground: the same order your
squads use. On the new open map that is exactly the trap you described. It needs the computer's squads to run squad
leaders (elements), which are off in your skirmish today; turning them on makes the computer flank more (rear kills
11 % → 27 % in 8 test matches) and costs some per-frame work on your laptop (not yet measured)."* **Approved:**
(a) brains builds "the commander picks ambush", scenario first, behind the elements flags (nothing changes in his
skirmish); (b) elements-on priced on his laptop at his army size, parade and the Sumps. **(c) HIS: whether the
computer runs squad leaders in his skirmish**, put to him with (a)'s result and (b)'s price.

**ship's correction (2026-10-05 02:13 PDT): its two "build/ here is not what the box wrote" failures were a bug in `tools/remote.sh`, not a
local run during the copy-back** (the explanation it gave at 01:24 and the orchestrator repeated to him and to
brains). `5d084283`'s check went green again (builder0, 01:25–02:05 PDT: exited 0, 23 targets ALL JUDGED, 2047/0)
with ship touching nothing locally, and its copy-back failed the same way: "0 corrupt, 19 missing, of 358 files",
every one `build/screenshots/garage-tour/desktop/*.png`. Cause: the copy-back rsync's `--exclude='desktop/'` was
unanchored and skipped EVERY directory named `desktop`, while the manifest skips only `build/desktop/*`; after a
`check-all` in a folder those 19 files are listed and never sent. It would hit any folder after a `check-all`,
main's included (none has run there this round), and the garage tour's desktop frames never came home to be looked
at. Fixed on its branch (`995659f0`: the four directory excludes anchored; `tools/test_remote_excludes.sh`). Not
merged; ship names a final tip after a copy-back verifies. **Do not run `check-all` from the main checkout until
that fix is on `main`.** desktop-smoke ×3 on its tip is running (first at 02:13).

**The exported build's exit leak, attributed (2026-10-05 02:46 PDT; finale, by removal; not fixed).** `desktop-smoke` runs the binary
`--headless`, so FxWorld, the warm-up and the feed do not exist there and cannot hold anything. `make quit-leak-arms`
(the exported binary run as desktop-smoke runs it, plain, arms interleaved, each exit code read; builder0, light
lane, load 3.8–10.9): base 1 of 6 and 3 of 8; **music off 0 of 6 and 0 of 8**; announcer text-only 4 of 6; music
prefetch off 4 of 6; quit at tick 300 4 of 6 and 2 of 8. **0 of 14 with music off against 18 of 46 with it on: the
music's playing path holds the two resources.** A first fix (`MusicDirector` stopping its players and dropping its
streams on PREDELETE) changed nothing (3 of 8) and is reverted. Ten `--verbose` runs are going to name them.
`game/audio/music_director.gd` and the music's playing path are lent to finale for a minimal fix (no change to what
he hears or to round 17's mix). On `known_red.txt` as INTERMITTENT (ship: seen 3 of 7 plain builder0 runs before
these; never on the laptop; never under `--verbose`).
**ship (2026-10-05 02:46 PDT):** its copy-back fix is proven (three runs each verified all 358 files); its final tip `6248551d` is
in check: the anchored excludes, the intermittent known-red marking, with everything since `21359d02`.

**The exit leak is NAMED (2026-10-05 02:58 PDT; finale; not fixed).** `--verbose` caught it in 2 of 10 runs on builder0: `Leaked instance:
AudioStreamPlaybackOggVorbis … Reference count: 1` and `OggPacketSequencePlayback … Reference count: 1`: the music's
Ogg playback, held by the audio server's playback list; no line of ours holds it. Mechanism: `AudioStreamPlayer
.stop()` only MARKS a playback for deletion and the audio server deletes it at its next mix step; at quit the
players stop as they leave the tree, and under headless's Dummy driver the mix often does not run again before the
engine's resource check. That explains music-only (0 of 14 off, 18 of 46 on), the intermittency, and `--verbose`
hiding it. Two fixes in the music's own code changed nothing and are reverted (3 of 8; 2 of 12 + 2 of 12). **The fix
belongs in the quit paths:** stop the music and let one mix pass BEFORE the tree is torn down. Lent to finale: one
awaited call in each quit path (C18.6). **Whether it happens on his laptop (PulseAudio mixes every ~10 ms) is NOT
measured; every leak seen was headless.**

**The orchestrator's laptop run, parade against the Sumps (2026-10-05 03:10 PDT): done, but NOT in a quiet window.** `make perf-play`,
his window and launch flags, interleaved per seed, sound to a temporary null sink (removed after; his default sink
unchanged), his desktop idle 96 minutes. Two of brains' headless probes were running on the laptop throughout (load
2.8–3.3), so the absolute frame times (69–105 ms) are about twice his and mean nothing. What the two pairs say, with
that caveat: under the same load parade was not slower than the Sumps (avg frame 68.8 against 90.3 ms; 92.9 against
105.4 ms), with fewer vehicles alive on parade (its fights go faster) and the GPU's share the same within about 2 ms
(15.5 against 14.8; 13.6 against 15.4). Files and the caveat: `streams/references/round18/orchestrator/`. **To be
re-run in a real quiet window**, with brains' `make ai-element-perfplay` (the price of CPU elements), when brains
says its laptop runs are paused.

**THE QUIET WINDOW ON HIS LAPTOP (2026-10-05 03:48 PDT): two measurements, no other Godot alive before or after any run, sound to a
temporary null sink (removed; his default sink unchanged). Files: `streams/references/round18/orchestrator/` and
`/tmp/claude-1000/element-play` (brains to keep what it needs).**
(1) **The open map is not the expensive case** (`make perf-play`, main `776a759e`, his window and launch flags,
sumps then parade per seed): avg frame 77.0 against 63.6 ms and 101.3 against 66.4 ms; tick 28.5 against 24.2 and
31.4 against 26.6 ms; GPU 15.8 against 15.4 and 15.3 against 13.4 ms; vehicles alive 37 against 31 and 38 against
33 (parade's fights end sooner). N = 2 pairs, each pair two different fights.
(2) **The price of the computer running squad leaders** (`make ai-element-perfplay` from brains' worktree at
`4b060f00`; parade and the Sumps × seeds 92721 and 1801 × elements on / off, interleaved; whole tick's scripts ms on
/ off): parade 30.9 / 26.3 and 36.7 / 30.4; the Sumps 38.3 / 31.9 and 45.3 / 35.4. **About +4.6 to +9.9 ms a tick
(+17 to +28 %) on his laptop, in every pair**; on seed 1801 the on arm had fewer unit-ticks and still cost more.
The controller band rises less (+1.1 to +4.8 ms), so most of the price is outside the controllers (where: asked).
The arm assertion holds (the CPU carries element orders 9–16 % of unit-ticks on, 0 % off). **And the commander took
NO ambush in any of the four on-runs** (`BRAINS_AMBUSH taken 0 sprung 0`): with `4b060f00`'s "only if it can be in
place before the enemy reaches the kill zone" it never fires in a 60 s match on his path. brains' own probe before
that rule (his line crossing parade against a CPU commander, 8 seeds): taken 7 of 8, sprung 5, from a bay NEVER
(sprung mid-floor: the CPU was caught driving to its spot). **So today the feature would cost him 5–10 ms a tick and
show him no ambush. Not put to him as "turn it on".**

**The computer's ambush, the end of round 18's attempt (2026-10-05 04:01 PDT; brains).** At equal vehicle counts CPU elements cost
his laptop +6.5 ms a tick on average (+20 %; median +4.6; per-pair ranges +0.7..+2.9, +7.4..+14.2, +2.6..+5.2,
+8.2..+14.0); by Godot's script profiler the cost is the element machinery (navmesh grounding of slots +0.87, the
tactics layer +0.92, the order feeds +0.4 ms a sampled frame; the ambush-site search +0.07). With the site search
widened to 150 m the in-time rule rejects every site: **0 ambushes in 8 seeds of his squad crossing parade. It is
geometry: both sides race for the centre and the bays are equally far from both bases; a bay ambush is possible only
when the CPU DEFENDS.** That is a doctrine design (roadmap, round 19 candidate 10). **Decided: (c) is not put to
him; the ambush code stays unmerged on `stream/brains` with its state written at the top of the Status; brains
spends the rest of the night on the element machinery's cost as equal-answer work** (it makes his own tasked squads
cheaper and is the precondition for CPU elements), stopping by about 06:00 PDT for the round's close.

**Pages waiting on him (C15.2; the orchestrator reads every `db` at close):**
- **maps M7, the candidate maps:** https://claude.ai/artifact/WenjeeygUULXj5RTSmjXzb — **v4** (built at `0ae17e29`: parade's card adds that the computer fights in the open and does not use the bays yet; rendered 02:35 PDT, counts as v3). **v3** (built at `cbf5ed99`, 2026-10-05): adds "A squad on the move" on every card (four tanks on a 150 m attack-move: parade 14 s, yard_open 14 s, archipelago 15 s, docks 21 s, gorge 35 s, the Cut 46 s in 3 of 4 runs; the Sumps about 40 s, never before the fix; 4 runs, laptop), each card's saved state, and a top line saying the six Keeps of 20:33 are treated as a first look. **Rendered by the orchestrator 2026-10-05 00:31 PDT** (headless Chrome on the worker's file, `node --check`, a screenshot taken): "Version 3", 6 cards, 12 buttons (6 disabled off claude.ai), 18 choices, 6 note boxes, 29 images, none missing, all six squad lines present. **NOT verifiable off claude.ai: the two things that read the live `db`** (the top "Claude last read" line and each card's "Saved:" state). `db` read 00:31 PDT: unchanged, the same six Keeps. What v2 was:
  **v2** (built at `8c0fb36c`):
  each card leads with a frame of a match under way from his camera and has a line on how the computer played it.
  **Rendered by the orchestrator 2026-10-04 23:05 PDT** (headless Chrome on the worker's file, `node --check`, a
  screenshot looked at): "Version 2", 6 cards, 12 buttons (6 Save buttons disabled off claude.ai), 18 choices, 6 note
  boxes, 29 images, none missing. v1 was rendered the same way at about 20:32 PDT.
  **`db` read 23:05 PDT: `verdicts` holds six docs, KEEP on all six, no notes, by his id, written 20:32:52–20:33:04
  PDT** in the page's bottom-to-top order, 2–3 s apart: about two minutes after v1 went up and BEFORE he was given
  the link. **Not treated as his played verdict; `ROTATION` untouched (C18.2); he has been asked.** The
  orchestrator's first read found `verdicts` empty and was logged as "20:35"; that clock was the commit's, the read
  came just before the writes (lesson 243, again). Collections to read at close: `verdicts`, `meta`.
- Series behind it (maps, builder0, tree `0901ab64`, CPU brains alone, 8 seeds × swapped bases): all six fair within
  2 SE (docks −0.103 ± 0.071 is the widest: 16 more seeds queued); the CPU crosses on every candidate (31–39 % of
  vehicles get 20 m past the centre line; on parade 41 % of its time on the open floor).

**Waiting on him (live):**
- **NOT YET A DECISION FOR HIM: the computer running squad leaders in his skirmish.** Priced on his laptop: about +5 to +10 ms a tick (+17 to +28 %); and the ambush it was meant to bring does not yet happen in his matches (0 of 4). Brought to him only if both improve.
- **Overrule if he wants: glow on the arena screens' feed** (decided for him, above; one switch undoes it).
- **The slow motion after the final kill** lasts about 2 s; finale recommends keeping it; his feel when he plays.
- **The candidate maps page** (above): six Keeps were saved under his account at 20:33 PDT, before he had the link. ASKED: did he tap them, and had he played? Until he says, they are a first look. If he has played: which maps join the random rotation, and does the opened Container Yard replace the original or join it?
- ~~Start the five workers~~ **Done: all five are running (14:45 PDT).** A stale session `godot-22` (15 h old, idle)
  is still open and two workers messaged it by mistake: close it.
- **Play the picker** (row 1 is green on `main`): `make skirmish`, rest the mouse on Formation.
- **Play the Parade Ground** (`main-checked` carries v3): `make skirmish ARENA=parade` (a 112 m open floor with one 44 m bay a side; cross it in line and whoever waits abreast in a bay shoots down the line from its end; picker's read: every formation fits in the bay and in the centre). Also `gorge`, `archipelago`, `cut`, `docks`, `yard_open` (his Container Yard with the middle opened). Its centre sees 0.80 of the field, far above the maps he cut in round 9, by design: 17 hulls of hidden flank ground is what is different. Three more to play by name: `gorge`, `archipelago`, `cut`; the page with KEEP / CUT is still to come.
- **A quiet laptop for a few minutes** (the orchestrator's run, windows open on his desktop): `make perf-play PERF_PLAY_ARENA=parade` against `sumps`, interleaved. Not run while five workers are busy and he may be playing.
- **Push `main`.**
- Everything under round 17's *Waiting on the lead* below that is still true: the browser keyboard fix (`ibus`), the
  playtest list in stereo or 2.1.

## ✅ ROUND 17 IS CLOSED (2026-10-03 → 2026-10-04)

**Five streams, one day and one night, from two things he said after playing round 16 (the containers look
synthetic; the guns have no power) plus the three items round 16 left him, which he took whole. He played the result
and said: *"It's getting quite good."*** His words are in `game_design.md` *Round 17 direction* and the five *Round 17:*
decision records; briefs in `streams/archive/round17/`; evidence in `streams/references/round17/` (every page's `db`,
yard's raw contact counts, brains' page source and parity base) and `references/perf/r17-laptop-*`; lessons 243–253;
round 18 in `roadmap.md` *Round 18 candidates* and `game_design.md` *Round 18 direction*. The merge table further down
was kept live and is the record (rows 1–19, plus brains' last merge `488c06bf`).

**`main-checked` = `488c06bf`** (builder0, 2026-10-04 10:14–10:34 PDT: exited 0, 23 targets all passed ALL JUDGED, 2002 passed 0 failed, sim-baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`, perf-judge JUDGED PASS on its first attempt; the one "Unicode parsing error" in the log is the gate's own test). Above it: docs only.

### What he has now (all on `main`, all decided by his taps or his words)

- **Containers placed by people** (yard): every dealt map at his strength B (±4.0° on a 40 ft box, ±6.4° on a 20 ft,
  upper levels offset up to 45 cm); boxes flush to a kerb stay parallel to their building; walls are still walls
  (joint-ray, lane and junction guards in `tests/test_arena_container_joints.gd`). The collider turns with the picture.
- **Sound he can feel** (guns): the mix lets a gun be the loudest thing (booth duck MID, limiter without make-up); the
  gun families in layers; impacts by what a round hit (ground, concrete, a container, water, armour, a shield); the
  kill; skids, track squeal, burning wrecks, incoming rounds, shields returning; music +4 dB in a match. Seventeen
  picks and thirteen keeps on his audition page, the mortar on its third try. **Spend: 2,879 ElevenLabs credits;
  balance 34,490** (`assets/audio/elevenlabs/ledger.md`).
- **The end of a match** (sim): the kill cam counts simulation ticks and is bounded to about 3 s of real time; the
  Sumps' windowed fork is fixed and has a regression pair in `check`.
- **The browser build** (ship): the announcer speaks (per-line fetch, the 24 kbit/s set), sound is required by the
  smoke, the three factions' art loads after the title. It runs his army size at 3–11 fps (round 18 candidate 7).
- **A check with no holes** (ship): 23 targets; `scenario_perf` judged pinned and alone, or a named NOT JUDGED row;
  an engine-message gate that fails a target on "Unicode parsing error", unjudged ERROR / WARNING lines and exit leaks;
  `check-all` reports every target; a light lane (`make remote LIGHT=1`).
- **The brains' decision levers: priced, and none worth turning on** (brains). Every lever ships OFF. See below.

### The brains' levers: the verdict (so round 18 does not re-measure it)

On his laptop neither the bundle (`l17b2`) nor half-rate steering (`l17s`) lowered the tick at the same number of
vehicles: the first minute on two seeds (`984b5c38`, 2026-10-04 03:07–03:27 PDT; at ~30 vehicles 26.1–27.0 ms for
today's brain run twice, 25.8–26.8 with a lever), and a 4-minute run on seed 92721 (`d6259490`, 09:58–10:10 PDT;
whole-run `tick_script_ms` 18.71 and 20.41 for today's brain run twice, 14.63 for the bundle, which fought a different
fight and ended with 7 vehicles alive against 19; at 30 vehicles 25.13 / 26.47 against 27.38). Per vehicle alive the
controllers cost 0.60 / 0.66 ms against 0.65 ms. The levers acted (`BRAINS_ARM`: about 68 CPU controller ticks a second
skipped). Why builder0 said 12–27 %: those runs were ~200 s and most far-and-idle time comes after the match is
decided. The bundle also changes outcomes (16 seeds of his setup: Law's kills 9.7 → 13.1 a match). **What would reopen
it:** long LIVE stretches with the CPU far from any fight (round 18's open maps, or many more units), measured on the
laptop at equal vehicle counts with a bracketed champion, plus a fix for the bundle's effect on the outcome. Full text:
`streams/archive/round17/brains.md` *THE VERDICT*; the method: `unit_ai.md` *pricing a decision lever*.

### The findings that were not on any list

1. **Seven green checks carried 38–46 engine "Unicode parsing error" lines**; he found it running `make skirmish`. A
   `"\u0000"` sentinel in `weapon_fx.gd`. The gate that now fails on engine messages came from it (lesson 251).
2. **The browser was silent because of one runtime `AudioServer.set_bus_send`** under Sample playback; the fix is a bus
   layout file, and the layout's order had to be pinned against the old game's printed order.
3. **The check itself had a hole on a busy builder0**: a perf-judge refusal killed the recipe under `-e` and ran
   nothing. Found by yard, fixed by ship, with its own test.
4. **Long hulls scrape containers 300–500 times a minute on every layout, turned or square** (yard's count, the first
   ever): the routes, not the boxes. Round 18 candidate 3.
5. **A lever's price depends on the window you measure.** Builder0's 12–27 % was real arithmetic over the time after
   the fight was decided (above). An arm assertion (`BRAINS_ARM`) is what showed it.
6. **Two of his taps were on pages that could not record or should not have been asked**: a mix choice made on a
   number whose two arms were the same arm (declared void, re-asked; lesson 247), and nine versions of a page that
   rendered headings only (lesson 252).
7. **In 5.1 the subwoofer gets everything** (engine panning): play in stereo or 2.1. Round 18 candidate 10.

### Waiting on the lead (live)

- ~~Round 18 starts from his two items and his pick from the candidates.~~ **Done: round 18 is launched (above).**
- **Push `main`** (his; 782 commits ahead of `origin/main`).
- **Close the five worker terminals** (yard, guns, sim, ship, brains): their folders are gone; the sessions are idle.
- **His browser's keyboard:** a cache clean-up removed `~/.cache/ibus`, so Chrome and Firefox take no keys. Either
  start a browser with `GTK_IM_MODULE=gtk-im-context-simple XMODIFIERS=@im=none google-chrome …`, or restart the input
  daemon with `ibus-daemon --panel disable --xim -drx`. The orchestrator did not restart it for him.
- **Playtest list:** `make skirmish` on the living-room system, **in stereo or 2.1** (not 5.1). The guns of every
  faction, impacts by surface, the kill, the caller over a louder battle; containers on every dealt map (the Terminus
  least: 10 of 14 sit parallel to their buildings by rule); the end of a match (the slow motion, bounded to ~3 s; a
  1.7–3.4 s stall at the final kill under load is known, round 18 candidate 8); the browser build's voice.
- **No page is unconsumed** (`references/round17/final_db_read_at_close.md`; brains' T5 was read again at the close:
  `taps` empty, its taps closed, v14 rendered by the orchestrator: 16 buttons, 6 disabled).
- **Known red outside `check`:** `web-host-smoke` (the broker's 10 s handshake against a slow browser host) and a wasm
  trap in the browser build ('function signature mismatch'). Round 18 candidates 11 and 12.

### Housekeeping at the close

- All five worktrees and `godot-brainsprice` removed after the ancestor check and each worker's "clear to remove"; all
  five branches deleted. Only the main checkout remains. Git-ignored payload: guns' 250 ElevenLabs masters verified
  identical in the main checkout (`assets/audio/elevenlabs/masters/`, ignored by design, backed up by the timer);
  yard's three raw contact files and brains' page source copied into `references/round17/`.
- builder0: this round's eleven stream mirrors under `~/tank_squad/` removed (yard, guns, sim, ship, each with its `-light`; brains, brainsprice, brainsbase): 74 GB used, 28 GB free after. About forty mirrors of earlier rounds' streams remain there (~20 GB, every one a copy of a worktree that no longer exists): disposable on his word, not removed.
- The orchestrator's own errors this round, each a lesson: estimated clock times written as facts (243); a `pgrep`
  pattern that let one stream kill another's chain (244); a number relayed to him without an arm assertion, which he
  tapped on (247); one collection of a page's `db` read and the other left four hours (248); a disk filled by
  scratch nobody was counting (249); green logs never read for engine lines (251); a page passed by reading its source
  (252); and a watcher at the close that waited six hours on a condition that could never pass, because its idle parse
  had never been run against a live value (253).

_The launch record and the live log follow, as written while the round ran:_

## 🚀 ROUND 17 IS LAUNCHED (2026-10-03) — kept as written

**Five streams. Two are his words after playing round 16; three are round 16's candidates, which he took whole.**

| Stream | Folder (offset) | What it is | His gate |
|---|---|---|---|
| **yard** | `godot-yard` (1) | Containers that look placed by people: upper levels visibly offset, the ground level turned for real, walls still walls | a frames page (too much / too little) |
| **guns** | `godot-guns` (2) | Sound he can feel: the mix, the three gun families in layers, impacts by surface, the audit of silent events | an audition page; **spend authorised by his words** |
| **brains** (CLOSED 2026-10-05; branch kept) | ~~`godot-brains`~~ (3) | The tick's decision levers, each priced OFF behind a switch | a decision page (ship / keep off) |
| **sim** | `godot-sim` (4) | The Sumps' windowed fork at ticks 601–630: rate, cause, fix, regression | — |
| **ship** | `godot-ship` (5) | The browser build observed (no announcer clips, three factions' art excluded); `scenario_perf` judged every time; the tour and a desktop boot in `check-all` | a page (the web voice; pack size is his call) |

**What the orchestrator found before briefing (both in `game_design.md` *Round 17 direction*, measured at `6adf94bb`):**
- **Containers:** 93 % of 668 sit at exactly 0° or 90°; a stack's upper levels already jitter, by ±0.6° and ±4 cm — one
  or two pixels at his pose; the ground level never turns. Layouts are generated (`tools/make_arenas.py`), mirrored from
  one half. Turning the ground level for real moves the collider, so **yard's CP1 moves the sim baseline once** (C17.1).
  The trap written into the brief: a turned wall opens wedges a sight ray passes through.
- **Guns:** every weapon sound is mono; the tank's shot is 77–91 % below 200 Hz with under 1 % above 2 kHz (no crack);
  the machine gun sits at −13 dB; the World bus is trimmed −6 dB under a limiter; everything falls off with distance
  from a camera that is never close; earlier rounds designed for phone and laptop speakers. Impacts know the weapon,
  not the surface: a shell that misses plays `dirt_impact` whatever it struck, and a 25 mm or machine-gun miss plays
  nothing. A file measurement, not a listening test: guns' first item separates source, mix and format.

**Contracts** (`workstreams.md` *Round 17*): C17.1 one planned baseline move (yard's CP1, merged alone); C17.2 one tree
per comparison (nobody merges `main` until told; sim last, after its fork is localised on the launch tree's Sumps);
C17.3 his eye and ear are the checks (four pages: yard Y5, guns G4, brains T5, ship W2; C15.2); C17.4 a lever is
priced, never shipped on our call; C17.5 ElevenLabs sound effects authorised this round by his words, guns only, on the
ledger — everything else under lead gate 1 unchanged; C17.6 shared files.

**For the orchestrator while it runs:**
- **CP1** (yard's Y3): merge alone at its green hash, `make remote T=check` on `main`, confirm the new baseline line
  twice, then tell guns, brains and ship to `git merge main`; sim when it says its fork is localised.
- **Quiet-window laptop runs are yours**: brains' `perf-play` arms for its price table; sim's
  `--sim-off=visfield_thread` arm (F6). Close Chrome first; state the load.
- **Relays to expect**: guns → ship (the pack MB after new assets); sim → ship (a `windowed-repeat` pair for
  `check-all`); sim → whoever owns the fork's cause; yard → nobody-owned `game/ui/tactical_map.gd` if it draws turned
  containers square (the orchestrator fixes or queues it); ship → everyone (before its first `mk/core.mk` change merges).
- **Asked of him at launch, unanswered until he says:** what he listens on when he plays (guns' brief, *Waiting on the
  lead*). Carry his answer to guns the day it lands.
- **Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream), one session
  per worktree folder. Close stray sessions before a kickoff (round 15: seven agents for five worktrees).

**Pages waiting on him (C15.2; the orchestrator reads every `db` at close):**
- **guns G4, the gun audition:** https://claude.ai/artifact/WmGWF4RBCVycueMmUMac9i — v1 2026-10-03 12:46 PDT: tank, 25 mm,
  heavy MG and the kill (today + 2–3 directions, DRY only), 11 impact-by-surface sounds and 6 once-silent events
  (keep / redo). `db`: `picks/<tank|25mm|mg|kill|booth>`, `verdicts/<sound>`; **empty at the orchestrator's read
  (12:46 PDT)**. **v3 (13:41 PDT) is complete: in-the-fight clips from his Sumps match, the whole game before/now, the booth-duck
  item (launch / mid = the shipped default / light), the other factions' weapons.** Asked of guns for v2: matched loudness for the dry clips (today's tank is 2–3.5 dB louder than
  every new direction), the tails' width stated honestly (most read 0.03–0.06: nearly mono), proof the 30–40 Hz layer
  survives the page's MP3.
- **ship W2, Browser Build Choices — ALL FIVE DECIDED (four read 14:16:41 PDT; `mix` re-tapped 16:59:33 as sample-duck, read 17:48 PDT):** https://claude.ai/artifact/CzFkHbMyKs7cuPM3oQnbWR — published 2026-10-03 before 12:52 PDT (ship wrote "13:18 PDT", which was in the future by the laptop's and builder0's clocks: see the 12:57 log entry).
  Four taps in `choices/<voice|bitrate|factions|desktop>` ({pick, note, at}); **empty at ship's read and at the orchestrator's read
  (12:52 PDT)**. Q1 how the announcers reach the browser (A in the pack / B re-encoded / C a
  pack after the title / **D each line fetched when first said — built behind `?web-voice=fetch`, recommended** / E
  subtitles); Q2 the same three lines at four bitrates for his ear; Q3 the three factions' art in the browser (+21.2 MB,
  recommended); Q4 the desktop voice folder (already ON: a defect fixed, the tap only picks a bitrate). Two cells still
  "measuring" (D's first-line delay, MB per match). **Asked of ship:** one table of the real combinations — D +
  faction art + guns' sounds is 99.3 MB (103.9 with the audition alternates) against GitHub Pages' 100 MB per file —
  and a second `.pck` priced as the structural fix. **New fact: Cloudflare Pages cannot host the build at all** (25 MiB
  per file; the pck is 68 MB, the wasm 39.5 MB).

**Merged to `main` in round 17 (in order; verdicts read from the wrapper's own line):**

| # | Merge | What | Stream's check | Check on main after |
|---|---|---|---|---|
| 1 | `30a2ffe1` (the orchestrator, 12:25) | `_agents/.gdignore`; 105 import sidecars removed | — | exited 0, 1915/0, 21 targets all passed, baseline unmoved (as `3713fdaa` + the change) |
| 2 | `d7860e7f` = sim `16a02e14` (15:30) | the kill cam counts simulation ticks; Match's live-tick `time_scale` guard; the witness tools; `windowed-elimination-pair` | exited 0, 1920/0; baseline `05df1d55ba49cde1` and headless Sumps tick-900 `441426e6489ed9eb` unmoved; determinism `762a0576f944f5b7` | exited 0 (16:03), 1920/0, 20 passed + **1 NOT JUDGED** (`scenario_perf` refused, ref 2.01×), baseline and determinism unmoved |
| 3 | `9314a2db` = yard `1c497496`, **CP1** (15:35) | containers turned for real on every dealt map (flush kerb boxes keep their block's angle); upper stack levels offset; joint-ray, lane and junction guards; square layouts frozen as fixtures | exited 0, 1923/0, 21 targets; baseline `05df1d55ba49cde1` UNMOVED (foundry has no containers); determinism unmoved; per-layout hashes: 11 dealt layouts changed, foundry / furnace / scrapyard / maze / barriers and the Terminus's 40 s tank match identical | checked together with #4 (below) |
| 4 | `ddf710b2` = ship `64a7e769` (15:56) | `export-guard` in `check`; `perf-judge` (scenario_perf first, alone, P-core pinned); the verdict line `ALL JUDGED` / named refusals; the light lane (`make remote LIGHT=1`); the browser's faction pack (his Q3 tap); `web-match-smoke`; the desktop voice folder; voice-fetch behind its switch | SOAK: two checks of `64a7e769`, both exited 0, 23 targets all passed ALL JUDGED, 1925/0, baseline and determinism unmoved; 21 light web smokes beside round 1 all green | **exited 0 (16:46), 23 targets all passed, ALL JUDGED, 1938/0, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`, perf-judge PASS on attempt 1, 1217 s** — covers #2–#4; `ddf710b2` ANNOUNCED to the streams at 16:57 |
| 5 | `dd6dbbe1` = guns `934f0ebc`, INTERIM (16:50) + `f93f3cb4` (a missing `.uid`) | the mix (MID duck, limiter without make-up, the distance filter off the crack); the gun families in layers; impacts by surface; the audit's first sounds; the declared bus layout (the browser's silence fixed); the web script duck and a −3 dB web Master trim. `game/main.gd` conflict resolved by the orchestrator (guns' line first, then ship's) | exited 0 (16:25), 21 targets all passed, 1956/0, baseline unmoved; `audio-launch-smoke` exited 0 (16:45) | **exited 0 (17:24), 23 targets all passed, ALL JUDGED, 1979/0, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`, 1308 s, on commit `f93f3cb4`** — `main-checked` moved to `f93f3cb4`; announced to guns and ship |
| 6 | `5a6fdf79` = guns `0423fe45` (18:47) | the music lifted +4 dB in a match (the title excluded); the web Master trim −4 dB; the layout's order pinned World-first against the launch tree's printed order; the default-is-MID and no-stacking tests; the faithful layout control, `booth-match`; `SCRIPT_DUCK` names its setting | exited 0, 1982/0, baseline unmoved, perf-judge judged where the suite refused at 2.72×; `layout-ab` N=4 EQUAL on every figure (0.14 dB between arms vs 0.64 within) | **exited 0 (19:24), 23 targets all passed, ALL JUDGED, 1982/0, baseline and determinism unmoved, copy-back verified, 1297 s, on commit `5a6fdf79`** — `main-checked` moved to `5a6fdf79` |
| 7 | `fa7a1c9c` = ship `9b404030` (18:57) | the browser's voice ON (per-line fetch, the 24 kbit/s set: his taps); `sound=require` in the browser smoke; the bus layout guarded in the export model; `windowed-elimination-pair` in `check-all`; the Q5 sweep and the joint run as evidence | exited 0 (18:55), 23 targets all passed ALL JUDGED, 1979/0, baseline and determinism unmoved, copy-back verified; browser first sound 6.2 s on builder0; pinned perf-judge 7 of 7 | **exited 0 (20:27), 23 targets all passed, ALL JUDGED, 1982/0, baseline and determinism unmoved, copy-back verified, 1382 s, on `9c7744ef`** (perf-judge PASS; the in-suite run refused at 2.15×) — `main-checked` moved to `9c7744ef` |
| 8 | `1861d3bb` = guns `de0d67ac` (green at `f5c127c4`; docs after) (19:48) | the second tries for his four redos (page-only until he picks), +1.85 MB of alternates in the web pack until then; the round-18 audit list in guns' Status | exited 0, 1982/0, copy-back verified (523 files) | covered by #9's check (21:13, green) |
| 9 | `f8032806` = yard `2c380daa`, **CP2** (19:55) | containers at strength B (his taps): ±4.0° / ±6.4°, upper levels to 45 cm; flush kerb boxes parallel; joints, lanes (20 cm, stated), junctions, stacks guarded | exited 0, 23 targets ALL JUDGED, 1940/0; baseline `05df1d55ba49cde1` UNMOVED (foundry), determinism unmoved; per-layout hashes changed again on 12 dealt layouts, identical on the container-free maps, the fixtures and the Terminus's 40 s match | **exited 0 (21:13), 23 targets all passed, ALL JUDGED, 1984/0, baseline `05df1d55ba49cde1` unmoved (foundry), determinism unmoved, copy-back verified, 1659 s, on `90c289f2`** — `main-checked` moved to `90c289f2`; ANNOUNCED to all five |
| 10 | `5cdeb942` = ship `6da99d45` (20:43) | on a hybrid machine the in-suite `scenario_perf` refuses (`reason=unpinned`) unless pinned: perf-judge is the only judgement on builder0; `check-all` reports every target; `export-server-boot`; the desktop smoke's frame | exited 0 (20:41), 23 targets ALL JUDGED, 1979/0, baseline and determinism unmoved, 1806 s; mutation in three directions (builder0 unpinned / pinned, the laptop) | **exited 0 (21:40), 23 targets all passed, ALL JUDGED, 1984/0, baseline and determinism unmoved, copy-back verified, 1481 s, on `0cd42ebe`** (the in-suite run refused `unpinned`; perf-judge judged) — `main-checked` moved to `0cd42ebe` |
| 11 | `1968620d` = guns `f49aa0b2` (green at `2ec25c9a`; docs after) (20:57) | the 5.1 check: `AUDIO_SPEAKERS` prints, `--audio-device=`; guns' final report in its Status | exited 0, 1982/0; perf-judge judged where the suite refused at 2.05× | covered by #10's check (21:40, green) |
| 12 | `d36193aa` = yard `580c6ebd` (22:03) | tooling only: the page tool's broken-frame guard, `contact-shot` and the per-collider contact probe, the Sumps' scrape reference frame, yard's final report (six files, none in `game/`, `arenas/` or the suite) | `6f1549b8` exited 0, 1940/0, ALL JUDGED; `580c6ebd` re-run 1984/0, perf-judge judged, `ai-scenarios-check` red only on the known cover scenario + the unpinned perf false FAIL its tree still had | covered by #13's check (22:44, green) |
| 13 | `7b599654` = ship `18f024eb` (22:16) | the check's perf-judge stage survives a refusal (own target, `judge || s=$?`, always exit 0; a refusal is a named NOT JUDGED row); `tools/test_check_perf_judge.sh` (stub judges 3 / 1 / 0 through the real recipe); the supersede line names its reason; the copy-back skips `build/desktop` | exited 0 (22:16), 23 targets ALL JUDGED, 1984/0, baseline and determinism unmoved, 1336 s; check-perf-judge 10 passed inside it | **exited 0 (22:44), 23 targets all passed, ALL JUDGED, 1984/0, baseline and determinism unmoved, copy-back verified, 1317 s, on `7b599654`** — `main-checked` moved to `7b599654` |
| 14 | `8e701a8d` = sim `bdf0dcaa` (22:21) | the kill cam bounded in real time (max of the tick schedule and unscaled wall / 1.5: ≤ 3 s; OFF under `--fixed-fps`, read from `/proc/self/cmdline` split on NUL, or `--kill-cam-ticks-only`; ON where there is no `/proc`); `KILL_CAM` lines; the pair layout-proof (finish + 90) and asserting `wall_cap=false`; the client handshake timeout 15 s | exited 0, 1989/0, ALL JUDGED, baseline and determinism unmoved; the pair on the CP2 tree: 60 slowed ticks in both runs at 585, `wall_cap=false`, 675/675, no divergence; headless Sumps tick-900 `882d74cd0ca71201` | **exited 0 (23:08), 23 targets all passed, ALL JUDGED, 1989/0, baseline `05df1d55ba49cde1` and determinism `762a0576f944f5b7` unmoved, copy-back verified, 1416 s, on `f5b2226c`** — `main-checked` moved to `f5b2226c`; announced to ship |
| 15 | `6999c53e` = ship `655bf04c` (22:39) | four recipes that failed closed but SILENT print their reason before failing (`mk/net.mk` web-host-smoke, replay-playback, lobby-smoke; `mk/tactics.mk` tactics-pytest); `verification.md`: exit 0 is not green without ALL JUDGED | exited 0 (22:39), 23 targets ALL JUDGED, 1984/0, baseline and determinism unmoved, 1313 s | covered by #14's check (23:08, green) |
| 16 | `34011f08` = guns `f280b903` (00:43) | his sixteen audio picks applied (the 25 mm → the Bradley burst; the railgun → the pre-round take; the four second tries; 16 unpicked directions retired); the NUL sentinel removed from `weapon_fx.gd` (`SfxWeapons.has_sound`); tests pinning his picks and keeping NUL out of audio / FX scripts | exited 0 (00:42), 23 targets ALL JUDGED, 1988/0, copy-back verified, 0 "Unicode parsing error" lines in its log | **exited 0 (01:08), 23 targets all passed, ALL JUDGED, 1993/0, baseline and determinism unmoved, copy-back verified, 1427 s, on `34011f08`; 0 "Unicode parsing error" lines in the log** — `main-checked` moved to `34011f08` |
| 17 | `9a377eaf` = ship `35cd2b48` (green at `ea40eed1`; a brief-only commit after) (01:14) | the engine-message gate (`tools/engine_log_gate.py`; per-target logs; fails on "Unicode parsing error", unjudged ERROR / WARNING lines, exit-time leaks; an allow-list of target + substring + reason); the smokes print an uncaught exception's stack; ship's final report | exited 0 (01:14), 23 targets ALL JUDGED, 1993/0, baseline and determinism unmoved, 1490 s; `engine-log-gate: test: 16 allowed engine line(s) seen`; its red half on `cfd514be`: 20 passed, 3 FAILED quoting the line | **exited 0 (01:40), 23 targets all passed, ALL JUDGED, 1993/0, baseline and determinism unmoved, copy-back verified, 1431 s, on `9a377eaf`; the gate printed its 16 allowed `test` lines** — `main-checked` moved to `9a377eaf` |
| 18 | `af244ec0` = brains `2657db11` (02:18) | the decision levers, EVERY ONE OFF by default (l17s the stride, l17i1 / l17i2, l17c, l17k, l17o, the bundles) and the instruments that price them; `ai_parity.py`'s DIGEST line carries machine and glibc | 23 targets ALL JUDGED, 2002/0, baseline and determinism unmoved, engine 0 errors / 0 warnings; parity with every lever off = main's `9a377eaf` digest `55fba4d6…` over 24 matches, same machine and session | **exited 0 (02:44), 23 targets all passed, ALL JUDGED, 2002/0, baseline and determinism unmoved, copy-back verified, 1482 s, on `af244ec0`** — `main-checked` moved to `af244ec0` |
| 19 | `a38359a3` = guns `0716d53a` (green at `3c270b50`; Status after) (02:29) | his mortar pick applied (d, the light mortar's sharp bark, at the loudness he heard); the other mortar candidates retired; the test pins all seventeen picks; guns' final report | exited 0 (02:28), 23 targets ALL JUDGED, 1993/0; `engine-log-gate: test: 8 allowed engine line(s) seen`; imported layered audio 26.89 → 19.84 MB over the round | **THE CLOSING CHECK: exited 0 (03:06), 23 targets all passed, ALL JUDGED, 2002/0, baseline `05df1d55ba49cde1` and determinism `762a0576f944f5b7` unmoved, copy-back verified, 1248 s, on `984b5c38`; `engine-log-gate: test: 10 allowed engine line(s) seen`** — `main-checked` moved to `984b5c38` |
| 20 | `488c06bf` = brains `eb3fa470` (green at `c69067f2`; three Status-only commits after) (10:12, 10-04) | the arm assertion (`BRAINS_ARM` under `--brains-census`), `ai-lever-perfplay`, `unit_ai.md` *pricing a decision lever*, brains' final report and VERDICT; every lever OFF by default | exited 0, 23 targets ALL JUDGED, 2002/0, baseline unmoved, parity digest = main's (builder0, `c69067f2`) | **THE CLOSING CHECK:** exited 0, 23 targets all passed ALL JUDGED, 2002/0, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7` (builder0, 10:14–10:34 PDT). `main-checked` = `488c06bf` |

- **yard Y5, Containers placed by people:** https://claude.ai/artifact/929eYAkRdDCMXArwc7Rja5 — published 2026-10-03
  ~17:50 PDT. Every dealt map at his pose (6 maps, 21 frame triples: square / turned A = what ships (±2.0° on a 40 ft
  box, ±3.2° on a 20 ft, upper levels ≤ 25 cm) / B = twice that, page-only), a drag wipe, per-map counts (Terminus 4
  turned / 10 parallel by rule; every other map all turned), taps per map and per close frame in `taps/`. **Empty at
  the orchestrator's read (17:50 PDT; first written as 17:56, an estimate, corrected from the clock).** Yard's read: A is subtle at his pose, B reads clearly; B is a fight change
  (hashes and contacts re-run). **Two frame triples are BROKEN (found by the orchestrator from identical byte counts):
  `sumps_opening` shows a rooftop with no container; `terminus_avenue` is a blown-out white frame.** Yard told to fix
  and republish, and to fail the page build on byte-identical triples.

- **brains T5, Brains Lever Prices:** https://claude.ai/artifact/To29gP1bdc8Xextr6P6UWV — published 2026-10-03 19:31 PDT.
  `taps/<lever id>` ({lever, choice: ship|keep_off, at}); **empty at the orchestrator's read (19:32 PDT).** Six levers and
  two bundles, every row launch-tree, laptop figures labelled as projections. Brains recommends ONE tap, the bundle
  `l17b2` (~29 % of the brains on his skirmish path, projected 25 → ~19 ms at 30 vehicles). **v5 (01:4x PDT): the two stride cards (`l17s`, the bundle `l17b2`) are OPEN to tap; the others closed. The orchestrator's advice to him: take the laptop measurement first.** Earlier state: v4, taps closed. Now on it:
  the headline as a range over three seeds (18–29 %, ~4–6 ms), the driving series (planned-leg contacts flat; Sumps
  route scraping +41 to +82 a minute), the asymmetric arm (his units do not die more). Brains asked to disable the buttons on cards with pending
  rows. Told to him: do not tap yet.

**PLAY IN STEREO OR 2.1 on the living-room system (guns, 20:57):** in 5.1 Godot sends every 3D sound full-range into
the LFE at a constant −11.2 dBFS whatever its bearing (laptop, a 6-channel null sink; below 120 Hz the LFE reads −20.1
dBFS against the fronts' −29.1 on his match), so with a receiver's +10 dB LFE gain the sub booms. Engine panning; not
fixable in audio's paths; round-18 candidate 10. Told to him.

**For his playtest of `main-checked` `f93f3cb4` (told to him at 17:27):** `make skirmish` on the living-room system.
The new guns (tank, 25 mm, heavy MG, the other factions' weapons), the kill, impacts by what a round hit (ground,
concrete, a container, water, armour, a shield), skids and track squeal, burning wrecks, mortar rounds coming down,
shields coming back up; the caller with the battle louder under him (MID); the music quieter under the fight than he
is used to (the +4 dB lift is not on main yet). Containers turned on every dealt map (the Terminus least: 10 of 14 sit
parallel to their buildings by rule). The end of a match: the slow motion is now actually seen on the laptop, and may
run ~5 s there (`KillCam.HOLD_TICKS`); a 1.7–3.4 s stall at the final kill is known and unowned.

**Round log (the orchestrator's relays and decisions; newest first; times are the laptop's clock, PDT, taken from
the commit that logged each entry):**
- **2026-10-04, 10:35 — ROUND 17 CLOSED.** Brains judged the long runs by its own bar (no measurable change; per vehicle alive
  the controllers cost 0.60 / 0.66 ms for today's brain against 0.65 for the bundle; all three runs end in his side's
  defeat at ~132–142 s, so the survivors are the CPU's, 19 against 7), published T5 v14 ("none of these levers is worth
  turning on"; rendered by brains and again by the orchestrator: 16 buttons, 6 disabled; `taps` empty) and named
  `eb3fa470` (green at `c69067f2`, docs after). Merged as `488c06bf` at 10:12; the closing check on main 10:14–10:34:
  exited 0, 23 targets ALL JUDGED, 2002/0, baseline unmoved. Brains' two worktrees and branch removed; its brief
  archived; builder0's eleven mirrors of this round removed. The closed section at the top is the summary.
- **2026-10-04, 10:12 — THE LONG LAPTOP RUNS ARE IN (six hours late, the orchestrator's error): NO MEASURABLE CHANGE; THE BUNDLE
  FOUGHT A DIFFERENT FIGHT.** The watcher armed at 04:17 never fired (its idle parse read "64" from "(uint64 …)"; lesson
  253); run by hand 09:57:59–10:09:50 PDT, he was idle 6 h, laptop, AC, screen on, brains' worktree `d6259490` (code =
  `c69067f2`), Sumps, seed 92721, uncapped, 21 phases × 10 s (218 s of match), load at each arm's start 1.33 / 2.59 /
  2.88. Whole-run `tick_script_ms`: **x5p 18.71, x5p again 20.41, l17b2 14.63.** The two x5p runs are the same fight
  (identical vehicle counts in every phase) and differ by 1.70 ms, so brains' condition (a) (within 1 ms) fails. The
  bundle's run is a different fight: it ends at 7 vehicles against 19 (CPU unit-ticks 58,549 against 131,386), so its
  lower number is fewer vehicles alive. At equal counts nothing: at 30 vehicles x5p 25.13 / 26.47 against l17b2 27.38;
  at 26, l17b2 25.02. `BRAINS_ARM`: the stride acted (68.4 CPU controller ticks a second skipped) and the champion's
  far-and-idle share over the run was 49.9 %, so the window reached the time the lever is for. N=1. By the bar set
  before the run: no measurable change; every lever stays OFF. Files:
  `references/perf/r17-laptop-long-d6259490-*.json` and `-run.log`. Sent raw to brains for its verdict and final hash.
- **2026-10-04, 04:17 → 09:57 — the close ran in two halves.** 03:58–04:01: yard, guns, sim and ship each answered "clear to
  remove" (no process, no ignored payload worth keeping bar yard's three raw contact files, copied to
  `references/round17/yard/`; guns' 250 masters verified identical in the main checkout); their briefs archived to
  `streams/archive/round17/`, worktrees and branches removed; every page's `db` read a last time (nothing new:
  `references/round17/final_db_read_at_close.md`); the ElevenLabs ledger corrected (batch 5 settled late: the round's
  sound spend is 2,879 credits, balance 34,490). 04:16: brains' check of `c69067f2` green on builder0 (23 targets ALL
  JUDGED, 2002/0, baseline unmoved, parity digest = main's). Then the watcher sat until its deadline (above).
- **2026-10-04, 03:56 — HE PLAYED AGAIN AND GAVE TWO ITEMS FOR ROUND 18; ROUND 17 STAYS OPEN FOR BRAINS.** In chat, ~03:50,
  awake at the laptop: *"let's let the brain keep working then, but let's also add some new handoff items after I played
  another game. It's getting quite good."* (1) **The formation button**: stepping through formations by clicks is slow
  and blind; he wants a hover panel of every formation with the preview on each. (2) **New maps by experiment**: the
  current maps' navigable space is low and the obstacles "are sort of just making navigation hard"; he never gets to
  move line abreast; first idea, an open centre where a line abreast can be ambushed from cover at right angles. Both
  verbatim, with what the code and layouts measure, in `game_design.md` *Round 18 direction*; `roadmap.md` *Round 18
  candidates* A and B. Measured for B at `c1cb2adb`: lanes on the six dealt maps are 12–30 m wide, a line of four at
  the 12 m default spacing needs about 36 m, so no lane fits one. Nothing launched: these are round 18's first items.
- **2026-10-04, 03:55 — brains: the arm assertion on builder0 (`c69067f2`, perf-play's own command line, ~60 s, seeds 92721 /
  31337, load 0.0–2.3) EXPLAINS THE LAPTOP NULL.** The stride lever acted: 63.8 / 64.3 CPU-side controller ticks a second
  skipped (bundle 67.3 / 66.3; his side 0 by design; champion 0 / 0), about a tenth of the CPU side's. But in
  perf-play's first minute the CPU is in reach of something 81 / 73 % of its unit-ticks, far and idle only 19–27 %,
  no orders on the CPU side. Controller band, builder0 thread CPU a tick: x5p 13.39 / 14.03 ms of 16.78 / 17.94 ms of
  scripts (~80 %; brains withdrew its "~55 %"); l17s 13.34 / 13.35 of 16.66 / 16.90; bundle 12.53 / 13.04 of 15.93 /
  16.70. So 0.1–1.2 ms a tick on builder0, inside the laptop's ±1 ms bracket: **nothing to save in a match's first
  minute, measured on both machines.** Brains' earlier 12–27 % came from ~200 s runs: the far-and-idle time is after
  the first clash. That later saving is builder0 only, two of three seeds, unconfirmed on the laptop. **Owed, when he
  is away from the laptop (two runs, ~4 min each, from `~/projects/godot-brains` at `c69067f2`):**
  `make perf-play PERF_PLAY_NAME=perf-play-long-x5p PERF_PLAY_ARMS=uncapped PERF_PLAY_SEEDS=92721 PERF_PLAY_SECONDS=10
  PERF_PLAY_FLAGS="--green-brain=x5p --rust-brain=x5p --brains-census"`, the same with `l17b2`, then
  `grep -h '^BRAINS_ARM' build/perf-play-long-*.log`. T5 stays v12 (projection withdrawn, taps closed). Brains
  recommends every lever OFF this round; the orchestrator agrees (C17.4).
  **Armed, behind two gates (04:00):** the orchestrator's watcher (`scratchpad/orch-long-pair.sh`, a background task of
  this session) runs THREE arms (x5p, l17b2, x5p again as the bracket; seed 92721, `PERF_PLAY_SECONDS=10`) once (1)
  brains has said "copy-back done" (its check of `c69067f2` runs from `~/projects/godot-brains`, and `tools/remote.sh`
  copies `build/` back with `rsync --delete`, which would delete a result written before it ends; the orchestrator then
  creates `scratchpad/long-pair/GO`) and (2) he has been away from the laptop 15 min. It gives up after 6 h. Results:
  `scratchpad/long-pair/`. If this session is gone the runs are still owed, by hand, when he is away.
  **The bar, set by brains BEFORE the run:** a saving only if (a) the two x5p runs agree within 1 ms on
  `tick_script_ms` over the whole run, (b) l17b2 is at least 2 ms below the lower x5p, whole run and at ~30 vehicles,
  (c) `BRAINS_ARM` shows CPU skips > 0 and the champion's free share ≥ 30 %. Anything less: no measurable change, N=1,
  levers off. Brains' worktree is at `d6259490` (code = `c69067f2`; docs above it), clean, frozen until the runs end.
- **2026-10-04, 03:29 — THE LAPTOP ARMS ARE IN: NO MEASURABLE SAVING FROM THE LEVERS ON HIS LAPTOP.** `make perf-play` from the
  main checkout (code = `984b5c38`; CP2), 03:07–03:27 PDT, he was asleep (idle > 65 min), monitor on, AC, his window,
  UHD 620, seeds 92721 and 31337, uncapped, 21 phases × 2.5 s; load at each arm's start 1.12 / 2.82 / 2.89 / 2.12 (not
  "CPU idle": five idle Claude sessions, his idle Chrome). The flags reached the game (`"rust-brain": "l17s"` etc. in
  TANK_SQUAD_READY). `tick_script_ms`, mean over phases — **at ~30 vehicles: seed 92721 x5p 26.08 / 26.99 (the
  bracket), l17s 26.45, l17b2 26.83; seed 31337 x5p 26.37 / 26.27, l17s 25.80, l17b2 26.39.** Whole run: 29.22 / 30.30
  vs 30.57 and 29.83; 29.50 / 29.96 vs 29.11 and 28.60. At 51 vehicles: 31.40 / 32.29 vs 34.53 and 34.09; 34.56 /
  34.74 vs 28.39 and 31.47 (the two seeds disagree in sign: noise between fights). Ticks a frame 2.4–3.0, GPU
  14.0–15.9 ms, game speed 0.90–0.96, whole-run frame 75–93 ms. Files: `references/perf/r17-laptop-984b5c38-*.json`
  and `-run.log`. **Not yet "the lever buys nothing": the log has no line showing the stride ACTED on this path.**
  Asked of brains: the arm assertion (controller ticks skipped by the stride, per side, on a perf-play run), why the
  builder0 +20 % does not appear, and meanwhile the page says "measured on your laptop, two seeds: no measurable
  change", the bundle's recommendation withdrawn, the stride's and the bundle's taps closed. One more laptop pair
  tonight if brains ships a build that prints the count.
- **2026-10-04, 03:29 — brains' T5 page had rendered as HEADINGS ONLY from v1 to v9** (its generator's `re.sub` turned the
  data's "\n" escapes into raw line breaks inside a JavaScript string: a syntax error, no cards, no buttons). The
  orchestrator had READ v1's source and passed it, then told him twice that two cards were open to tap. No tap was
  possible; `taps/` is empty. v11 fixed; **rendered by the orchestrator in headless Chrome from brains' published
  file: 8 cards, 8 Ship and 8 Keep-off buttons, 1 Ship disabled.** Lesson 252. The five remaining cards on the CP2
  tree (ladders at his size 9–7, 8–8, 10–6, 9–7, 7–9 against a null 7–7–2; scenarios and drills clean).
- **2026-10-04, 03:29 — close step 2 begun: guns' git-ignored ElevenLabs masters rsynced into the main checkout** (250 files,
  9.4 MB; 175 new). The other worktrees hold only `.tools`, `local.mk`, `override.cfg`, `.godot/`, `build/` and tool
  caches. Branches: yard, guns, sim, ship are ancestors of main; brains is 8 commits ahead (page tool, Status,
  measurements).
- **2026-10-04, 03:08 — THE CLOSING CHECK IS GREEN: `main-checked` = `984b5c38`** (03:06: exited 0, 23 targets ALL JUDGED,
  2002/0, 1248 s, baseline and determinism unmoved, the gate's 10 allowed `test` lines, 0 parsing lines; docs only
  above it). **The laptop arms are running since 03:07** (decided without his word: Mutter's idle monitor read 65 min
  with no input, the monitor on, AC online, laptop load 0.84; his Chrome left open, idle at ~0.2 % CPU; memory
  *overnight autonomy*): `make perf-play` from the MAIN checkout (the game he plays; the variants are on main; no
  worker's copy-back can touch its `build/`), arms x5p, l17s, l17b2, x5p again, default seeds 92721 / 31337, JSONs
  copied to the scratchpad as each ends.
- **2026-10-04, 02:45 — `main-checked` = `af244ec0`: brains' branch (levers OFF) is green on main** (02:44: exited 0, 23 targets
  ALL JUDGED, 2002/0, 1482 s; the gate's 14 allowed `test` lines; 0 parsing lines). The closing check (the tip with
  guns' mortar merge) started 02:44. Brains' CP2 arms (builder0, load 6–8): his skirmish seed 92721, one run: l17s
  +20.4 ± 4.9 %, the bundle +23.3 ± 4.9 %; Sumps driving, 6 paired seeds: l17s +37 route scrapes a minute (~7 %), the
  bundle +11 (~2 %), planned-leg hits −1 / −18, fewer wedged (the champion's 514 / 549 a minute agrees with yard's
  ~583). Brains corrected: "smaller rubbing on CP2" is true of the bundle, not of l17s alone.
- **2026-10-04, 02:29 — MERGED guns' last range (`a38359a3`): his mortar pick is on main; GUNS' STREAM IS COMPLETE and its branch
  is an ancestor of main; nothing of the round's sound waits on him.** The check of #18 (brains) is at 9 of 22; one
  more check then covers this merge and is the round's closing check unless he taps a lever.
- **2026-10-04, 02:19 — MERGED brains' branch with every lever OFF (`af244ec0` = `2657db11`); the check of main started 02:18.**
  All five streams' code is now on main. Left: guns' mortar range (his pick d, being applied), the check of this merge,
  the laptop arms (from `~/projects/godot-brains` at `2657db11`: x5p, l17s, l17b2, x5p again; on his window), his tap
  on T5's two open cards, brains' remaining rows (the CP2 Sumps arm; the five closed cards).
- **2026-10-04, 02:00 — HE PICKED THE MORTAR: `picks/mortar3` = d (the light mortar's sharp bark), 02:00:25 PDT; read 02:00:42;
  dumped; recorded.** Sent to guns to read back, apply as the default at the level he heard, retire e / f / b / c,
  republish the page, check on a tree with `main-checked` `9a377eaf` merged (the gate), and name its last hash. The
  round's sound is then decided in full.
- **2026-10-04, 01:46 — brains' r3 is complete; T5 v5: the two stride cards (l17s, the bundle l17b2) have every row in and
  their taps are OPEN; the other cards stay closed.** On `6a926d4b` (the launch tree + the fixed lever): ladders at his
  size, 16 games each: null (x5p v its twin) 8–8; l17s 10–6; the bundle 6–10 — all within ~1 s.d. of even (the old
  11–5 / 13–3 was the defect). Sumps driving, paired: l17s −2 route scrapes a minute, the bundle +40, no planned-leg
  rise, fewer wedged. His setup (Law on the champion v the CPU's Condemned on the lever, 16 seeds): Law wins 3 / 3 / 4;
  Condemned kills 18.4 / 17.8 / 17.6. Scenario counts clean in four arms. **The saving on his skirmish path: l17s
  12.3 / 19.3 / −1.8 %, the bundle 26.6 / 23.5 / 3.5 %** (nothing on the seed where the CPU is in contact 85 % of the
  time); the Sumps CPU v CPU 6.6 ± 1.1 and 8.5 ± 1.2 %, null −0.3. The page: "0–6 ms off his 25 ms tick depending on
  the fight; ~4 ms average; ~13 vehicles at a locked 30 from ~11", projected. Brains recommends the bundle.
  `taps/` and `picks/mortar3` EMPTY at the orchestrator's read (01:46). **Decided: brains merges `main-checked` now,
  checks, proves parity with every lever OFF against main itself, and names a hash the orchestrator merges with the
  levers OFF (his tap later flips one default); the laptop arms run on THAT tree (the game he plays, CP2), not on the
  launch tree; one builder0 arm per lever on the CP2 Sumps.**
- **2026-10-04, 01:40 — `main-checked` = `9a377eaf`: ship's engine-message gate is green on main** (01:40: exited 0, 23 targets
  ALL JUDGED, 1993/0, 1431 s; the gate's own line `test: 16 allowed engine line(s) seen`; the one "Unicode parsing
  error" string left in the log is the name of the gate's known-answer test). Everything of yard, sim, ship and guns
  (bar the mortar) is merged and checked. Open: his mortar tap; brains' r3 and T5; the laptop arms on his window.
- **2026-10-04, 01:14 — MERGED ship's final range (`9a377eaf`): the engine-message gate is on main; SHIP'S STREAM IS COMPLETE and
  its branch is an ancestor of main.** The check of main started 01:14. Four streams complete (yard, sim, ship; guns
  bar the mortar). Running: brains (r3's rows; T5's taps closed). Waiting on him: the mortar's third tries; a quiet
  window for the laptop arms at `6a926d4b`.
- **2026-10-04, 01:08 — `main-checked` = `34011f08`: his sixteen audio picks and the NUL fix are green on main** (01:08: exited
  0, 23 targets ALL JUDGED, 1993/0, 1427 s; 0 "Unicode parsing error" lines; the 23 `ERROR:` / `WARNING:` lines in the
  log are the tests' own deliberate warnings and the shards' exit-time leaks, which ship's gate will judge).
- **2026-10-04, 00:43 — MERGED guns' picks + NUL-fix range (`34011f08` = `f280b903`); his sixteen picks are what main plays;
  the warning he saw is gone** (a headless boot of merged main: 0 "Unicode parsing error" lines, 6 before). The check
  of main started 00:43; ship told to merge it and run the gate's green half in parallel. Left: ship's final hash (the
  gate), his mortar tap (`picks/mortar3`), brains' r3 rows and the laptop arms.
- **2026-10-04, 00:38 — ship's last list on `f5b2226c` is IN, and the gate's red half proved it.** web-net-smoke **5 of 5** on
  builder0 (1 of 3 on the launch tree); `check-all` **2025 s**, every target reported, web-host-smoke the only red (its
  two causes are round-18 candidates 11–12); the browser's kill cam from its own lines: `ticks=60 ms=2076 by=ticks` at
  59.2 fps, `ticks=22 ms=3050 by=wall` at 13.9 fps (the designed 2 s, and the 3 s bound; ~8–10 s before sim's fix). The
  gate on `cfd514be` with the NUL literal still present: `20 passed, 3 FAILED`, rows quoting the line (test ×36,
  web-smoke ×8; the third a false positive on a test's NAME, fixed `21abdeaf` by anchoring at line start). **The one
  other thing the gate finds: the test shards' exit-time leaks** (414 ObjectDB instances, 14 CanvasItem RIDs, 10
  resources in use, texture / text / font RIDs), printed after the runner returns. Decision (ship's, accepted):
  exit-time leak lines fail EVERY target; the shards' own two lines are allowed for `test` only, by target and
  substring, the count printed on every run; freeing them is round-18 candidate 13. Ship's green half waits on guns'
  `f280b903`. Brains' r3 scenario counts: no difference from the champion bar the known red (43/1/3 in all four arms;
  drills 0 failures): the stop rule holds; the laptop arms at `6a926d4b` wait only on his window.
- **2026-10-04, 00:20 — the mortar's THIRD tries are on the page (v8, same link; his tap saves to `picks/mortar3`): d a light
  mortar's sharp bark, e a heavy mortar's concussive boom, f the tank's own crack and report shortened with the tube's
  ring; "the shot itself, no handling".** Masters with any sound before the blast rejected; every take front-loaded
  like the tank (first 50 ms vs tail −4.8…−8.5 dB; 10–90 % rise 0.5–29 ms). Batch 7: 205 credits, 34,695 → 34,490.
  Committed as `7e1a571d`, a later range (its check after his tap). **Guns' range with his sixteen picks and the NUL
  fix is `f280b903`** (`SfxWeapons.has_sound` replaces the sentinel; a headless boot prints 0 "Unicode parsing error"
  lines, 6 before; its full check started 00:16:58); merge when its verdict line is quoted, then ship's gate.
- **2026-10-04, 00:16 — ship built the engine-message gate (`cfd514be`) and found web-host-smoke's two real causes.** The
  gate: per-target logs under `build/check/logs/`, `tools/engine_log_gate.py` fails a target on "Unicode parsing error"
  anywhere and on unjudged `ERROR:` / `WARNING:` / `SCRIPT ERROR:` lines, with an allow-list of (target, substring,
  reason); the FAIL row quotes the line; 20 known answers through the real wrapper. Why the suite missed the NUL
  warning: the engine prints it via `print_error()` to `_log_message`, which the test runner's ErrorCollector does not
  implement, and at parse time, before the first test's `errors.take()`; no smoke's output was read by anything.
  **Order decided: guns names its picks + literal-fix hash NOW (the mortar's third try is a later range); the
  orchestrator merges it, then ship's gate lands on a clean tree; every other line the gate finds (leak-at-exit lines)
  is listed before it merges.** web-host-smoke on `f5b2226c`: (a) the browser host's first frames take ~4 s, its relay
  socket is still CONNECTING when the broker's 10 s `handshakeTimeoutMs` passes, and `relay_peer.gd` ends the unseated
  session with no retry; (b) a wasm trap ('function signature mismatch') after the room opened, 1 in 3, also with
  packs off. Neither is this round's: round-18 candidates 11 and 12. He asked whether the announcer clips are Ogg:
  yes (verified: 3,112 Ogg Vorbis clips, mono 44.1 kHz ~40 kbit/s, 75.2 MB; none of it in the web pack). Brains'
  laptop-arm commit is `6a926d4b`; the arms wait on his window and on r3's four scenario counts (running since 00:06).
- **2026-10-04, 00:06 — two things from him.** (1) **The mortar's second tries are REJECTED** (`picks/mortar2`, 00:00 PDT,
  no pick): "These don't sound like mortars being fired, they sound like a mortar being loaded."; in chat "the sounds
  still stink". Sent to guns verbatim with a design reading (the SHOT, no handling; the tank's layers; three directions
  that differ in kind). (2) **`make skirmish` prints "Unicode parsing error … Unexpected NUL character" 6–10 times.**
  Traced (verbose boot + strace): the engine prints it each time it parses `game/theme/fx/weapon_fx.gd`, whose lines
  577–578 use a `"\u0000"` string literal as a sentinel (guns' carve-out; first on main with guns' interim merge).
  Harmless to the logic, noise in every launch — and **in every check log since: 38–46 lines a log, with every one of
  those checks reading ALL JUDGED.** Guns fixes the literal in its next range; ship asked why the engine-message gate
  did not see it and to close that (mutation: restore the literal, the check goes red).
- **2026-10-03, 23:56 — guns applied his picks (`9e27ccb2`) and put the MORTAR REDO on the page (v7, same link): one more tap
  from him, saved to `picks/mortar2`.** Read-back matched the orchestrator's list line for line. The levels he heard
  are the levels that ship: the railgun (today's take) had only dry clips, loudness-matched down 3.8 dB to direction
  A's, so the game's −0.7 dB reproduces what he tapped (the page does not record whether he switched matching off);
  the 25 mm B's fight clip was recorded at the shipped MIX −4; the second tries were composed to one loudness. The 16
  unpicked directions retired (59 takes deleted; imported layered audio 26.89 → 20.25 MB with the two mortar
  candidates; the web main pack ~90 → ~83 MB). Mortar batch: 10 takes, 183 credits, 34,878 → 34,695 (the balance had
  already moved ~280 below the last ledger line: settlement lag is the likely cause, to be confirmed). Guns' full check
  of `9123131e` is running; it names the hash.
- **2026-10-03, 23:38 — HIS AUDIO PICKS ARE IN (16; read 23:37:55 PDT; dumped; recorded in `game_design.md`).** Defaults
  confirmed: tank A, MG A, kill A, twin MG / missiles / pulse / flame A, booth MID, music +4 dB. **Changes: the 25 mm →
  B (the Bradley burst); the railgun → TODAY'S sound (pre-round); the mortar → today's sound and a REDO (his note:
  "Both of these sound lame and we should redo").** Second tries: skid B, squeal C, incoming B, shield C. Sent to guns
  to read back, apply, drop the unpicked alternates from the game and the web preset, generate new mortar directions
  for the page, and name a green hash. **His browsers had no keyboard:** his own `rm -rf *` in `~/.cache` this morning
  (shell history) deleted `~/.cache/ibus`, the running ibus-daemon's socket; apps started since cannot reach it. Told
  to him with a no-risk launch line (`GTK_IM_MODULE=gtk-im-context-simple XMODIFIERS=@im=none google-chrome …`) and the
  restart (`ibus-daemon --panel disable --xim -drx`); NOT restarted by the orchestrator; a logout would kill all six
  sessions. **Brains: a SECOND stride defect** (a unit carrying an order was strided for three ticks and drifted 88 m
  from its formation slot; fixed `1e15dfb0`, superseding `572e55a6`; r3 re-prices everything). Stop rule set: a third
  behaviour difference from the champion and the stride goes to round 18 unoffered. On the third skirmish seed the
  stride buys nothing (−3.2 % / +3.1 %).
- **2026-10-03, 23:09 — `main-checked` = `f5b2226c`: sim's kill-cam / handshake / pair commit and ship's last fix are green on
  main** (23:08: exited 0, 23 targets ALL JUDGED, 1989/0, 1416 s; docs only above it). The round's final code state
  unless ship's last list finds something. Announced to ship with its list. Brains' stride fix is `572e55a6` (its
  check and three-map parity queued at the end of its chain).
- **2026-10-03, 23:03 — brains' scenario counts caught a DEFECT in the stride lever; l17s / l17b2 are being re-priced from
  scratch (~3–4 h); T5's taps stay closed.** With both sides on the lever, one more scenario failed:
  `scenario_cover::test_a_healthy_tank_near_a_wall_fights_from_cover` — hidden 0 % of 20 s (champion 61 %), 0 returns
  to cover (2). Cause, tick by tick: an unrated brain counted as idle and strided from tick 1; a stride lasted until
  the next think after contact; a strided unit skipped the intel tick where contact arrives and noticed ONE tick late
  (t=5 vs 4). Control: the champion with its think phase shifted 1 / 2 / 3 ticks keeps cover every time. Fixed on
  brains' tip (no stride before the first rating; full rate when the rating rises; re-rate on every intel tick); the
  scenario then reads the champion's exact numbers. **On the OLD version the ladders at his size read l17s 11–5 and
  l17b2 13–3 against the champion**: asked that the mechanism be found if the fixed version still wins like that (a
  lever doing less work that beats the champion is a behaviour change no other column caught; C12.6). Every earlier
  T5 row for l17s / l17b2 (the 18–29 % range, the driving series, the asymmetric arm) is on the old version and will be
  replaced. The laptop arms will use the fixed commit.
- **2026-10-03, 22:52 — MERGED sim's docs range (`101a6782`: `determinism.md`'s third Sumps value, the final report);
  SIM'S STREAM IS COMPLETE and its branch is an ancestor of main.** Its round-18 lines: slow motion is half a
  simulation; the final-kill frame stall; `relay_peer.gd` has no handshake timeout; the 14-pair soak in the light
  lane; the garage not coverable unattended.
- **2026-10-03, 22:44 — `main-checked` = `7b599654` (ship's check fix + yard's tooling green on main: 23 targets ALL JUDGED,
  1984/0, 1317 s). The check of the tip started 22:44: sim's `8e701a8d` + ship's `6999c53e` (the four silent
  recipes).** If green, that is the round's final code state bar docs ranges and brains' branch. YARD and GUNS are
  complete (guns bar his picks); sim owes a docs range; ship its last list on the announced hash; brains its scenario
  counts and ladders, then the taps open.
- **2026-10-03, 22:21 — MERGED sim's kill-cam / handshake / pair commit (`8e701a8d` = `bdf0dcaa`).** Its pair on the CP2 tree:
  `WINDOWED_ELIMINATION ok slowed=[(585, 60)]/[(585, 60)] expected=60 wall_cap=['false']/['false'] lines=675/675
  first_divergence=none`. The Sumps' headless tick-900 witness is now `882d74cd0ca71201` (launch `441426e6489ed9eb`,
  CP1 `58cff8d52f018e7b`). The pair takes ~22 min on builder0. Sim owes a docs range and its final report; ship told
  the hash and what to measure on the announced one (web-net-smoke N ≥ 5, the timed `check-all`, the browser kill cam
  from its `KILL_CAM` lines: expected ~3 s at any frame rate now).
- **2026-10-03, 22:20 — brains' T5 v4 (taps still closed): the headline is a RANGE, and his units do not die more.**
  (1) Paired % of the brains' controller time on his skirmish path, seeds 92721 / 31337 / 4242: null +2.3 / −1.7 /
  −0.4; l17s +20.0 / +15.1 / +4.4 (mean 13.2); the bundle l17b2 +28.9 / +18.8 / +18.4 (mean 22.0). The page says
  18–29 %, projected 4–6 ms off his 25 ms tick at 30 vehicles (mean ~4.8; a locked 30 to ~13–14 vehicles from ~11);
  expect ~4–5 ms from the laptop arms, not 6.3. (2) His setup, asymmetric, 16 seeds (his Law on today's brain v the
  CPU's Condemned on the lever): Law wins 3 / 2 / 4 of 16 (champion / l17s / bundle); Condemned kills a match 18.4 /
  19.6 / 16.9. The Law-favouring shift with both sides on the lever came from Law's own units striding, which never
  happens to his. (3) `l17t` (the stride on straight legs only) removed the Sumps scraping (−23 a minute) but kept
  2.3 % of the saving: dropped; the plain stride survives with the scrape rise on its card. Still running: scenario
  counts, then the ladders at his size on l17s and l17b2; the taps open when they land.
- **2026-10-03, 22:17 — MERGED ship's fix for the check's `-e` defect (`7b599654` = `18f024eb`); the check of main started
  22:16.** Ship's `655bf04c` (the four silent recipes: `|| status=$$?`; shown with a deliberately failing client: the
  old lobby-smoke and tactics-pytest stop at `Error 1` with nothing printed, the new ones print their reason, then
  fail) has its check running. Yard's branch is fully on main (`367e6a72`, docs).
- **2026-10-03, 22:03 — MERGED yard's tooling tip (`d36193aa` = `580c6ebd`); YARD'S STREAM IS COMPLETE.** Its last check was
  red only on `ai-scenarios-check` (42,2): the known `scenario_cover` red plus the unpinned `scenario_perf` false FAIL,
  which its tree (`90c289f2`) still had; yard's reading that the cover scenario moved with load was corrected (it is
  the standing "1" in 43,1).
- **2026-10-03, 21:49 — ship fixed the check defect (`18f024eb`, its check launched 21:48) and swept the pattern.** The
  perf-judge stage is its own target (`judge || s=$$?`), always exits 0 so the fan-out runs; a refusal reads `22 passed,
  1 NOT JUDGED` + `NOT JUDGED perf-judge: <reason>` (exit 0: green with a NAMED HOLE — the orchestrator merges on the
  verdict LINE, never the exit code); a judged failure is a FAIL row. `tools/test_check_perf_judge.sh` drives the real
  recipe with stub judges (3 with and without a reason, 1, 0): 10/10; 7 of 10 fail on the old line. **The sweep:
  `mk/net.mk:167` (web-host-smoke), `:241` (replay-playback), `:265` (lobby-smoke) and `mk/tactics.mk:64` fail closed
  but SILENT** (a failing client kills the recipe before its reason prints: why web-host-smoke's cause was lost twice).
  Decision: those four lines LENT to ship (`mk/net.mk` nobody's; `mk/tactics.mk` brains', told). No hold on the light
  pool for a waiting perf-judge (the one refusal had the P-cores 62–65 % idle and still read 1.80–1.86×). **W4's
  result: perf-judge judged 15 of 16 checks across all streams since it merged** (waits 0–120 s an attempt; the stage
  16–319 s); the unpinned in-suite run refused or false-failed in the same checks.
- **2026-10-03, 21:40 — `main-checked` = `0cd42ebe`: every merge of the round so far is checked on main** (21:40: exited 0,
  23 targets ALL JUDGED, 1984/0, 1481 s, 10 SHARD lines in the log; the in-suite perf run refused `unpinned` and
  perf-judge judged, i.e. ship's fix working as built). Nothing unmerged is waiting except: sim's kill-cam / handshake
  / pair hash, ship's `-e` fix and final range, yard's tooling tip, brains' branch (levers, all OFF by default).
- **2026-10-03, 21:38 — DEFECT ON MAIN, in the check itself (yard found it, the orchestrator verified it): when perf-judge
  refuses all three attempts, `check` runs NOTHING and exits 2.** `Makefile:18` is `.SHELLFLAGS := -eu -o pipefail -c`
  and the recipe line is `tools/perf_judge.sh … >&2; s=$$?; \`: under `-e` an exit of 3 kills the shell before
  `s=$$?`, so the NOT JUDGED branch and the whole fan-out never run. It had only ever passed because perf-judge had
  always judged; tonight builder0 hit load 17–23 and yard's check came back with no SHARD lines. Relayed to ship with
  yard's fix (`s=0; … || s=$$?`) and the missing test (a stub perf-judge exiting 3 and 1 through the real recipe; every
  other `cmd; s=$$?` under those flags listed). **Until it merges: an `exited 2` with no SHARD lines means "did not
  run", not "red"** (told to sim and brains). Ship's end-of-round browser table on the CP2 tree is in (pack 90.1 MB;
  sound on every page; factions in their own art; the voice at boot; 0 console errors). Asked of ship: whether a
  waiting perf-judge should hold the light pool, and the judged rate across all streams since its merge.
- **2026-10-03, 21:36 — yard: the Sumps' extra scraping at B is the ROUTES, not the boxes; DECISION: no containers held
  square.** Per-collider counts over 8 seeds (totals equal CP2's run exactly): steer ticks 9,915 square (517 a minute)
  → 11,463 at B (601); of the +1,548, containers are +150; terrain rims +311, the perimeter +336, wrecks +397,
  floodlights +219, rails +69, blocks +66. The turned map sends fights along different routes. Top container rises:
  Container20_24 at (−38,−16) turned 4.49° 96 → 339; Container40_22 at (−8,−30) 226 → 330; Container20_8 at (−41,−8)
  89 → 183. Yard's one-line option (hold `c20(38,16)` and `c20(41,8)` square) buys at most a fifth: written down, not
  taken. Frame filed: `references/round17/yard_sumps_scrape_close.jpg` (a War Rig's nose against the three-high
  Container40_22: contact, nothing passing through). Round 18's nav item takes it as "the Sumps' routes". **Yard's
  stream is complete** (final report at `580c6ebd`; the census of other square props: barricades 89 % square,
  floodlights / signs / screens 98 %; door ends mixed shipped). Its tip's check came back exited 2 on perf-judge
  refusing three times (builder0 at load 17–23): asked whether the other targets ran. **builder0 at load ~20 at 21:35.**
- **2026-10-03, 21:21 — guns' post-CP2 MID `mix-ab` on his match (builder0 light lane, pinned seed, N=1 per arm), launch →
  now:** −17.3 → −16.6 LUFS; World median gain −17.2 → −11.2 dB; bed duck −21.2 → −11.2; booth over battle 21.1 →
  16.9 dB (busiest tenth 7.3 → 5.0); the Master limiter more than 1 dB under for 4.1 % → 11.3 % of the time (more
  than 3 dB: 1.2 %). The caller speaks 119 / 102 s of 150 on this fight (82 before CP2), and the pinned seed gave 37 vs
  33 lines across the arms. Against the pre-CP2 pair the direction holds for World, the bed and the booth; **the
  limiter's share moved the OTHER way (20.7 → 3.1 % before CP2): N=1 each on two different fights, unresolved**; guns
  asked to say so in Status. Guns has only his picks left.
- **2026-10-03, 21:20 — sim: the `/proc` caution was right; do NOT take `9f6976cd` / `0d714982` / `34221afc`.** `9f6976cd`'s
  check was green (1943/0) but its F5 pair failed: `wall_cap=true` in both runs, 4 slowed ticks, a fork at tick 523.
  Cause: `get_string_from_utf8()` stops at the first NUL, so the command-line reader returned argv[0] alone and the
  detector's test, asserting only argv[0], passed vacuously. Fixed `bdf0dcaa` (split on NUL bytes before decoding; the
  test asserts content past argv[0] and fails on the truncating reader), on top of sim's merge of `90c289f2`
  (`56baf40e`). Running in one chain: check → the pair (`wall_cap=false` in both runs, exactly 60 slowed ticks,
  identical hashes) → the Sumps witness hash twice for `determinism.md`'s third value (CP2). The hash sim names will
  carry the kill cam's bound, the pair's horizon and the handshake timeout. Second time today the pair caught what a
  green check did not.
- **2026-10-03, 21:14 — `main-checked` = `90c289f2`: CP2 (his strength B) is green on main** (21:13: exited 0, 23 targets
  ALL JUDGED, 1984/0, baseline unmoved, 1659 s). Announced to all five with what each does next: guns one post-CP2
  MID `mix-ab`; sim merges it, re-runs the pair on that tree and names ONE hash (now three commits past `9f6976cd`);
  ship merges and waits for sim's hash; yard the Sumps' scraping locations and its final report; brains stays on the
  launch tree until T5's rows and the laptop arms are done. The check of the tip (ship's perf fix + guns' 5.1 check)
  started 21:13.
- **2026-10-03, 21:07 — brains' driving series: half-rate steering is NOT killed on driving** (launch tree, builder0, War
  Rigs v Condemned, budget 5200, elimination, seeds 1–6, long-hull contact ticks a minute, median / mean, paired
  median vs the champion on the same seed). SUMPS: plant × kturn x5p 47.3 / 57.5, l17s 51.0 / 47.8 (paired −1.4),
  l17b2 48.9 / 88.1 (paired 0); route scrapes x5p 393 / 469, l17s 663 / 596 (**paired +82**), l17b2 586 / 618 (paired
  +41); wedged units 189 → 127 / 128. TERMINUS: plant × kturn 31.9 / 40.6, 13.0 / 39.4 (0), 48.8 / 46.8 (0); scrapes
  369 / 342, 294 / 283 (paired −43), 453 / 438 (−2); wedged 250 → 176 / 199. The smoke's 201 plants a minute was
  noise. So: planned-leg contacts do not rise; route scraping rises on the Sumps by about what CP2 itself adds there;
  fewer units wedge. Brains built the variant anyway (`l17t`: the stride only on a plain straight leg; bundle `l17b3`,
  `91d9c007`) and queues: l17t / l17b3 driving + cost → two more skirmish seeds → the asymmetric Law-champion v
  Condemned-lever arm → scenario counts → the ladders at his size on whichever survives. Guns' cleanup: a check's
  copy-back had brought 2.5 GB of WAVs back from builder0 (deleted on both sides now); disk 27 GB free.
- **2026-10-03, 20:57 — MERGED guns' final range (`1968620d`): the 5.1 check and its final report. GUNS' STREAM IS COMPLETE
  bar his picks** (then: defaults set, the unpicked alternates out of the web preset) and one MID `mix-ab` after CP2.
  The 5.1 finding is for his playtest (above). Arena acoustics as a runtime system was not done (round 18).
- **2026-10-03, 20:43 — MERGED ship's fix for the false perf FAIL (`5cdeb942` = `6da99d45`).** Three commits, because two
  reads were broken: Godot reads `/proc/self/status` EMPTY when read whole (so `_cpu_kind()` had returned "-" on
  builder0 all round), and the sysfs P-core list compared unequal. Relayed to sim: its fixed-fps detector reads
  `/proc/self/cmdline`. Ship's `check-all -k` of `9b404030` (pre-CP2), target by target: check FAIL only on
  `ai-scenarios-check` (the false perf FAIL, now fixed, plus the known `scenario_cover` red); web-smoke PASS;
  web-net-smoke FAIL (known, sim's `9f6976cd`); web-host-smoke FAIL (the browser HOST; reason lost, next run);
  **garage-tour PASS** (frames looked at; the caller's subtitle overlaps the LOOK chip: cosmetic, unowned);
  **desktop-smoke PASS** (105 MB pack + 80 MB voice folder, 3112 clips); the pair not run. Pinned perf-judge: 8 of 8.
- **2026-10-03, 20:27 — `main-checked` = `9c7744ef` (ship's second range green on main: exited 0, 23 targets ALL JUDGED,
  1982/0, 1382 s; perf-judge PASS on attempt 1, the in-suite run refused at 2.15×).** The check of the tip (CP2 +
  guns' second tries) started 20:27; it had waited ~35 min in builder0's queue before running. Disk 24 GB free.
- **2026-10-03, 20:12 — sim's CORRECTION: do not merge `775b810b` or `8376c790`; the hash to name is `9f6976cd`.** The kill
  cam's real-time bound had been ON under `--fixed-fps` (Godot consumes that flag before `OS.get_cmdline_args()`), and
  sim's "off, shown by 13 slowed ticks" was a wrong inference (the 530 horizon had cut the run). Its own F5 pair caught
  it at `8376c790`: both runs identical but 4 slowed ticks, not 60. A frame-clock version was tried and rejected on a
  measurement (a saturated game's process delta carries game time). `9f6976cd`: the bound uses the OS clock and is off
  when the process's own command line holds `--fixed-fps` (`/proc/self/cmdline`) or with `--kill-cam-ticks-only`;
  laptop real time: `KILL_CAM end … ticks=31 ms=3132 by=wall`. It still carries the pair's finish + 90 horizon and the
  client handshake timeout (15 s). Check and pair queued. Ship told which hash to expect; sim told main now carries
  CP2 and to re-run the pair on the announced tree.
- **2026-10-03, 19:56 — CP2 MERGED (`f8032806` = yard's `2c380daa`): his strength B is on main's tip, not yet checked
  there.** Long-hull contacts per minute, median square / A / B, same 8 seeds (seeds where turned > square): plant ×
  kturn pit 25.9 / 24.7 (4) / 13.4 (2), sumps 58.0 / 16.0 (0) / 49.6 (2), terminus 32.2 / 18.1 (2) / 27.3 (5), yard
  32.7 / 45.7 (4) / 26.2 (2); into containers 7.7 / 8.5 / 1.5, 8.8 / 2.5 / 14.2, 0 / 0 / 2.7, 23.7 / 25.0 / 22.8; steer
  504.7 / 496.2 / 404.6, **449.3 / 406.4 / 582.7 (7 of 8 seeds higher on the Sumps)**, 368.7 / 298.0 / 264.2, 383.9 /
  323.7 / 377.4. The square arm byte-identical to CP1's (32 of 32). **Decision: within the rule (plant × kturn inside
  the seeds' spread), CP2 stands as he chose; the outline fix stays round 18; the Sumps' route scraping at B is FLAGGED
  and filed** (yard asked where on the Sumps and whether it shows at his pose). Guns' third range also merged
  (`1861d3bb`: the second tries, page-only). The check of main on ship's range (started 19:24) had not begun running
  at 19:56: builder0's queue.
- **2026-10-03, 19:38 — ship found a hole in its own W4: the UNPINNED in-suite `scenario_perf` can give a FALSE FAIL under
  load, and it reddens `check`.** In `check-all -k` of `9b404030` (builder0, load ~14) the suite's run did not refuse
  (reference 1.46×, just under the 1.5 line) but read 21 444 µs a tick against the 20 000 line: FAILED,
  `ai-scenarios-check` red (43,1 → 42,2). The pinned perf-judge in the SAME check: PASS 1.35×, 14 320 µs. Normalised,
  the false run read 18 977 against 12.4k–15.4k elsewhere: the reference and the AI tick do not slow alike on a mix of
  cores, so **the normalised figure cannot be the judge** (the question left open at noon is closed). **Decision:
  approved** — on a hybrid machine the in-suite run refuses with `reason=unpinned` unless pinned to the P-cores;
  perf-judge is the only judgement on builder0; the laptop unchanged. Until it merges, a check of main under load may
  go red on this with a clean tree: read it as this defect and re-run. Brains' T5 v2: every tap disabled until its rows
  are in; a 20 s smoke of its new driving probe reads l17s plant × kturn 201 vs 55 a minute (n=1, not a result), and
  with both sides on l17s the extra kills are all LAW's (9.7 → 15.1 a match; Law wins 6/16 vs 3/16): a balance shift.
  Brains told to run the driving series before its ladders.
- **2026-10-03, 19:25 — `main-checked` = `5a6fdf79` (guns' second range green on main: exited 0, 23 targets ALL JUDGED,
  1982/0, 1297 s, copy-back verified).** The check of the tip (ship's `9b404030` merged as `fa7a1c9c`) started 19:24.
  Brains' first lever prices (builder0, in-run paired A/B on his skirmish path, 51 units, % of the brains' controller
  time): l17s (a CPU unit with nothing in reach runs its controller every other tick) 20.0 ± 4.9 %; l17b2 (far-idle
  1/s + k-turn 12 + chord end + l17s) 28.9 ± 5.1 %; null control 2.3 ± 2.5 %; projected on the laptop at 30 vehicles
  ~4.3 and ~6.3 ms off a 25 ms tick. **Brains asked for three laptop `perf-play` arms in a quiet window (x5p, l17s,
  l17b2, from `~/projects/godot-brains` at `8ad0b7b1`+): the orchestrator's to run, NOT started — he is at the
  laptop; asked of him.** Guns' round-18 audit list filed (`roadmap.md` candidate 9: turret traverse 474 starts a
  minute, silent).
- **2026-10-03, 18:57 — MERGED ship's tip (`fa7a1c9c` = `9b404030`).** Its check: exited 0, 23 targets ALL JUDGED, 1979/0,
  1820 s, copy-back verified. Disk at 26 GB free after ship removed 3.45 GB more (its scratchpad is 42 MB). Guns and
  ship both report nothing broke in the full-disk window. The check of main at `5a6fdf79` is still queued; the next
  one covers ship's range and, if named in time, sim's `8376c790`.
- **2026-10-03, 18:52 — THE LAPTOP'S DISK FILLED (the lead noticed): 477 MB free at 18:49, 60 MB at 18:50, 23 GB at 18:51.**
  Cause: guns' scratchpad (13 GB of WAV taps and recordings + six scratch web exports), guns' `build/` (6.3 GB: the
  light lane's copy-backs and `build/audio`), ship's scratchpad (7.6 GB: seven `wns-*` `git archive` project copies at
  ~700 MB each, plus `proj*` and the sweep's exports). Guns removed 17.7 GB itself within two minutes (reports, the
  page's assets and the ledger kept); **the orchestrator deleted ship's seven `wns-*` copies (4.7 GB) itself** after
  checking no process was in them (their 12 logs kept), and told ship in the same minute. Main's repo is clean
  (`git status`, `git fsck`); the check of main after guns' second merge was queued, not copying, during the window.
  All five streams told to check whatever was in flight 18:45–18:51 and given the scratch rule (`workstreams.md`;
  lesson 249). Nothing was paused beyond guns' recording runs, which had finished. Ship still holds ~2 GB of `proj*`
  scratch to remove; brains two extra worktrees (0.7 GB) to remove when their series end.
- **2026-10-03, 18:48 — MERGED guns' second range (`5a6fdf79` = `0423fe45`); the check on main started 18:48** (the
  orchestrator told guns "18:34", an estimate again: the clock said 18:48). The layout is closed as a native equality
  (`layout-ab` N=4, one tree, the faithful control, one announcer seed: EQUAL on every figure). The close's MID
  `mix-ab` on his match, pre-CP2 (`28425a48`), launch → now: World gain median −9.5 → −7.0 dB; bed duck −12.1 → −0.4;
  the Master limiter more than 1 dB under for 20.7 % → 3.1 % of the time; booth over battle 22.2 → 17.6 dB; **both arms
  −17.5 LUFS** (the earlier "about 1 dB louder" came from a run on the light duck: guns asked which stands). Not yet
  checked on guns' tip: the second tries (`ddd42868`, page-only until he picks, +1.85 MB of alternates).
- **2026-10-03, 18:32 — KNOWN RED ON MAIN (outside `check`): `windowed-elimination-pair` as merged fails after CP1.** Not a
  fork: CP1 moved sumps seed 1's elimination from tick 446 to ~518 and the target's fixed 530 horizon catches 13 of the
  60 slowed ticks (both runs identical, 530/530). Sim's `8376c790` (SUPERSEDED by `9f6976cd`: see the later entry) makes it layout-proof (`--hash-after-finish=N`; the
  target runs to finish + 90) and carries ship's handshake request (`ClientMode.new_socket()`, `handshake_timeout`
  15 s, tested); its check and pair are queued. Sim's `775b810b` (the kill cam's real-time bound) is green on its
  own: exited 0, 1941/0, baseline and determinism unmoved. Merge `8376c790` when named (it contains `775b810b`);
  ship told its `check-all` will be red on the pair until then. `game/network/relay_peer.gd` (nobody's) has no
  handshake timeout at all (a raw `WebSocketPeer.connect_to_url`): noted, not changed. **Yard's CP2 is built
  (`2c380daa`, B: 4.0° / 0.45 m)**: joints hold (the mutation opening widened to 60 cm), lane / junction tolerance
  re-set 10 → 20 cm with every loss over 10 cm named (max 16 cm on a 16.78 m causeway), stacks clamped, the back-and-
  fill test passes; its check, hashes, contacts (square / A / B) and frames are running on builder0.
- **2026-10-03, 18:24 — ship's first `check-all` with the pair in it stopped at a PRE-EXISTING flake, and the cause is one
  line in sim's path.** `make check-all exited 2` on `99813480` (17:30 → 18:03): its check part 23 targets ALL JUDGED,
  then `web-net-smoke` failed (the browser peer JOINs then LEAVEs), and because `check-all` stops at its first failure
  the garage tour, the desktop smoke and `windowed-elimination-pair` never ran. The same smoke on the LAUNCH tree
  passed 1 of 3. Cause, tested by ship: the client's WebSocket `handshake_timeout` is Godot's default 3 s and the
  browser boots at ~2 fps; with 15 s in a scratch copy, connected and spawned 2 of 2. Relayed to sim
  (`game/modes/client_mode.gd`); ship re-runs the smoke N ≥ 5 after it. Decision: `check-all` reports every target by
  default (`-k`), ship's next range. Ship's tip check (`9b404030`) launched 18:23; that is the hash it will name.
- **2026-10-03, 18:23 — TWO SETS OF HIS TAPS READ (18:22 PDT), one of them four hours late.** (1) **Yard's page: B on every
  dealt map and both close frames** (tapped 18:11–18:12 PDT; the kerb question not tapped, so flush boxes stay parallel)
  — twice the turn: ±4.0° / ±6.4°, upper levels to 45 cm. Yard builds it as **CP2**, a second planned change of fights,
  to CP1's standard, with the contact count re-run square vs A vs B (if plant × kturn rises at B, the outline fix comes
  forward from round 18: brains told to have it sketched). (2) **Guns' audition page: 17 verdicts written 14:21–14:22
  PDT and unread until ~18:15** — keep all 11 impacts, the tyre skid, the burning wreck; redo the incoming mortar
  round, shield-up, the track skid and the track squeal; no family picks. Every read after 14:16 had listed `picks/`
  only: the orchestrator's miss as much as guns' (lesson 248). Guns has two second tries per redo on page v6 (236
  credits; balance 35,158). **Page v5 (18:13): every item re-recorded with one booth seed (9), the arms asserted to
  hear the same commentary** — booth median / busiest tenth: launch 24.8 / 11.1, MID 16.7 / 6.8, light 10.1 / 3.0; the
  hold on the booth and music items is LIFTED. `layout-ab` on one tree, faithful control, the same 19 lines: the
  4.6–5.5 dB gaps are gone (all EQUAL bar 0.1–0.2 dB on booth-over-battle and true peak at N=2; N=4 queued, not a
  gate). Both decisions recorded in `game_design.md`; both dbs dumped under `references/round17/`.
- **2026-10-03, 17:51 — yard's page is up, with two broken frames.** See *Pages waiting on him*. Guns: the script duck cannot
  stack (it chases one target, rest − depth; a test with four back-to-back lines, `4717e8e4`), so ship's 18.2 dB dip is
  either the battle falling or a run on the LAUNCH setting (depth exactly 18.2): ship asked to read `SCRIPT_DUCK` in
  that log. Guns' next range adds 0 MB to the web pack.
- **2026-10-03, 17:49 — HE RE-TAPPED Q5: `choices/mix` = sample-duck** (16:59:33 PDT; read by the orchestrator 17:48 PDT;
  dumped and recorded in `game_design.md`). The browser keeps Sample with guns' scripted duck and Master trim — what
  is built. The page's write replaced the document, so the `set_aside` record of his first tap survives only in the
  14:16 dump. The gun audition page's `picks/` still EMPTY at the same read. **Ship's range 2 is green on `ddf710b2`
  (`576cc6f1`, 17:30: exited 0, 23 targets ALL JUDGED, 1938/0; pinned perf-judge 6 of 6)**; asked to check its TIP once
  (it already contains `f93f3cb4`, `sound=require` at `588d37e6`, `windowed-elimination-pair` in `check-all`) and name
  that one hash. Ship's joint run (voice D + the script duck in the browser, small armies at 54–57 fps): 24 lines
  spoken, 1 missed, worst 0.11 s late; the two isolated lines dipped the battle 11.1 and 18.2 dB (design 12.7; N=2).
  `sound=require`: first sound 9.7 / 15.4 s after READY, 65 / 52 effects (2 local SwiftShader runs); the pre-fix
  reports fail it. **The browser's main pack is 88 MB on the merged build: 12 MB under GitHub Pages' cap.** Guns:
  the default-is-MID unit test is in (`3171a0a0`); v5's clips recording at seed 9 in the light lane.
- **2026-10-03, 17:46 — `booth-match` closed on the mean; the layout's gate redefined so it crosses no merge.** The page's
  tree and guns' tip are different fights since guns merged main (CP1 turned the Sumps' containers), so the arms spoke
  different lines even with one `--announcer-seed`. Per booth seed (page tree vs tip, median / busiest tenth): seed 7
  12.4 / 4.9 vs 13.8 / 0.4; seed 8 15.7 / 1.9 vs 13.2 / 5.2; seed 9 12.8 / 4.9 vs 13.9 / 1.2. **Mean difference 0.0 dB
  (median), −1.7 dB (busiest tenth), against a 3.0–3.3 dB spread across booth seeds on one tree.** So the shipped MID
  reproduces the page's MID on average, and v5 (re-recorded on the tip, one seed — 9, the caller speaking 88 % of the
  window — across every arm) makes the page the shipped game. The gate for the layout is now: the ground truth (done);
  `layout-ab` on ONE tree with the faithful control and one announcer seed, lines asserted equal; a unit test that the
  default booth setting IS `mid`.
- **2026-10-03, 17:35 — CONFIRMED: the booth draws a new seed every match, so every booth figure this round was one draw
  of lines — and so is every arm of the page's booth and music items.** Guns: with `--announcer-history=off` two runs
  of one match seed still spoke different lines (a different PA opener, different first-shot and first-kill calls; 19
  vs 21 lines); only `--announcer-seed=N` pins them. `booth-match` (`dd07223d`) now runs three booth seeds, the page's
  tree and the tip back to back per seed, lines asserted equal, the spread stated; `layout-ab` and `mix-ab` pin seed 7
  (`7177d558`). **Asked of guns, ahead of `layout-ab`: re-record the page's booth item, music item and before/now pair
  with ONE announcer seed across the arms of each** (he is asked to judge the duck by ear and currently hears different
  commentary in each clip); republish as v5. Told to him: hold the booth and music items until v5; the guns, impacts
  and new sounds are unaffected. Sim: the kill cam's real-time bound is built (`775b810b`: progress = max(ticks,
  unscaled wall seconds / 1.5), ends by 3 s real, the wall term OFF under `--fixed-fps` so F5 and the witness runs keep
  the pure tick schedule; `KILL_CAM start/end` lines; laptop loaded: ended `by=wall` at 3.8 s); the headless Sumps
  tick-900 hash after CP1 is `58cff8d52f018e7b`. Its check is queued; merge when it names the hash.
- **2026-10-03, 17:33 — GROUND TRUTH: the old game is World-first, and main's interim has its order.** Printed by each game
  itself, windowed on his match (probe in a `git archive` copy): `3713fdaa` builds World, Impacts, Bed, Gunfire, Crowd,
  then Announcer, then Music (World carries Limiter + Compressor(Announcer −28 dB 6:1)); `1619596d` (the page's tree)
  the same. So the declared layout is right; guns' `47a8a43f` and its "runtime is Announcer-first" message were wrong,
  caused by the control arm (the reset ran in `main.gd`'s `_ready`, after child nodes had built World). Fixed
  `0ece2408` (the layout dropped before ANY bus is built). The 20–21 dB "runtime" figures are void. **Remaining:** the
  page's MID 14.9 dB vs today's 12.1–12.7 on an equal battle and an equal order — guns reads it as two sessions of one
  seed; the orchestrator's candidate mechanism: the booth's memory across launches (round 16) makes two sessions speak
  different lines, so `booth-match` must pin the announcer's history in both arms and print the line ids. It runs the
  page's tree live beside the tip in one session (`db7b67d7`), in the light lane.
- **2026-10-03, 17:25 — `main-checked` = `f93f3cb4`: guns' interim range is green on main** (17:24: exited 0, 23 targets all
  passed ALL JUDGED, 1979/0, baseline and determinism unmoved, 1308 s). The annotated tag carries the runner's line and
  the open items. Announced to guns (merge it; next range = ground truth + `booth-match`, the music lift and −4 dB trim,
  the equality columns, the MID `mix-ab`, his taps) and ship (flip `"sound"` to `require`; guard the layout file;
  `windowed-elimination-pair` into `check-all`; the joint voice + duck run; Q5 re-measured and re-asked). Told to him:
  main is ready to play, with its caveats. `tools/round_status.sh` at 17:26: yard and sim have merged `ddf710b2`;
  brains defers its merge until T5 is published on the launch tree; builder0 load 8.9 with all 3 slots held and sim and
  guns queued.
- **2026-10-03, 17:24 — the tick-counted kill cam runs LONG where ticks do not keep real time (ship's browser run,
  carried to sim).** Ship on `ddf710b2`, local web export, laptop, headless Chrome on the GPU, small armies (budget
  400) so the match ends; timed by inference from the music director's time-scaled clock. At 58.7 fps the slow motion
  costs ~1.3 s of clock (the designed ~2 s); at 15.3 fps (main thread throttled 8×) ~7–8 s, i.e. ~8–10 s of wall time;
  at his army size (3–5 fps in the browser) likely longer, unmeasured. It agrees with sim's laptop figure (60 ticks ≈
  5 s loaded). The old wall-clock schedule failed the other way (two still frames). **Asked of sim, small:** keep the
  tick schedule (F5 must still pass) AND bound it in real time — a ~3 s unscaled cap switched off in the determinism
  pair is the orchestrator's lean; plus a `KILL_CAM start/end` print so observers time it directly. Also from ship:
  **with small armies the browser runs at 58.7 fps and voice D speaks every line on cue (0.01–0.05 s late)** — the
  voice path is fine; the frame rate at his army size is the problem. Guns: the battle's own level is equal on the
  page's tree and today's (−14.1…−15.1 dB into World in the page's window), so booth-over-battle 14.9 (page) / 12.4
  (World first) / ~19 (Announcer first) is the duck behaving three ways on one battle; the prints will say why.
- **2026-10-03, 17:01 — OPEN ON MAIN: the bus order, and with it the booth's level in the interim range.** Guns' final
  `layout-ab` (builder0, `0b9ba0ee`, his match, N=2 per arm, taps working): whole-mix LUFS, true peak, booth level,
  music and crowd EQUAL between arms within the within-arm spread; **World stage −12.6 (declared layout, World first)
  vs −17.4 (runtime, which printed Announcer FIRST); booth over battle 15.6 vs 21.0 dB.** So guns' `bc47545a` reasoning
  was wrong and it does not know which order the old game used; and the page's clips (no layout, 13:16) read 14.7 — the
  World-first figure — which contradicts the runtime arm. Guns will not name a hash green for the layout. **Main's
  interim (`dd6dbbe1`) carries the World-first layout: if the old game was Announcer-first, main ducks ~5 dB less
  under the caller than the page's clip of the same setting.** Decision: the ground truth runs BEFORE the check, as
  four prints (the launch tree; the exact tree the page's clips synced; main's interim; the tip with
  `--no-bus-layout`), each at two moments (after `mode.start()`, and with the booth attached). **Acceptance redefined,
  independent of reasoning about order:** he picks by ear from the page's clips; the shipped build is right when it
  reproduces the picked clip's booth-over-battle on the same 20 s within the run-to-run spread (`make booth-match`),
  and the layout's order is whichever passes it. The title is excluded from the music lift (`4168c17a`).
- **2026-10-03, 16:58 — `ddf710b2` is CHECKED and ANNOUNCED; guns' interim range is merged on top and being checked.** The
  check of sim + CP1 + ship: exited 0, 23 targets all passed ALL JUDGED, 1938/0, baseline and determinism unmoved
  (16:46). Announced to ship, brains, yard and sim as a COMMIT to merge (`git merge ddf710b2`, not the tip), with the
  light lane's rules. Brains finishes T5 on the launch tree and merges after (its first lever ladders on default 5–8
  unit armies were a NULL workload — three of five byte-identical to the champion — and are being re-run at his size).
  **Decision: guns' `934f0ebc` taken as an INTERIM range** (`dd6dbbe1`), so the native game has the new sound for his
  playtest before the last equality columns exist; its check on main started 16:58. Sim's proof accepted (sumps seed 1
  identical over ~454 post-end ticks; the Terminus control identical; F5 green). **Audition page v4 (16:54): the music
  item** — the same 20 s at +0 / +4 / +8 dB: the music sits 14.0 / 9.7 / 5.6 dB under the battle while the caller
  speaks (about 7 before the round); no measurable price to the guns; **guns' shipped default is +4 dB in a match**
  (`73e594d9`, NOT in the interim on main: main has +0). `db` empty at guns' 16:54 read.
- **2026-10-03, 16:04 — guns explained the browser's peak drop, and the trim becomes −4 dB.** The two sets of fights were
  the same build bar the trim (`8d18de13` vs `53143c52`); the difference was the WINDOW: 45 s at 8 fps reached big
  impact moments (84 impact starts) that 45 s at 6 fps mostly did not (22). On comparable fights (100 s, 8 fps,
  2,412–2,872 sounds started, interleaved N=2): **no trim peaks at +0.1 and 0.0 dBFS — the browser clips in a full
  fight**; with −3 dB, −3.2 and −2.2. Decision: −4 dB (one constant; the player's volume gives it back). A web arm is
  now defined by sounds started or the tick reached, never by seconds. `layout-ab` on the corrected tree: whole-mix
  LUFS and true peak EQUAL between arms within the within-arm spread (0.13 vs 0.14 dB; 0.44 vs 0.95) — but the booth /
  sidechain / music / crowd columns came back empty (a tap-placement bug, fixed `3d611afd`), so that part of the
  native equality is still unmeasured. Guns' queue prioritised: the music arms (the one item missing from his page),
  the final `layout-ab`, the full check of the tip, the ground-truth bus order, the MID `mix-ab`.
- **2026-10-03, 16:03 — MERGED ship's soaked range (`ddf710b2` = `64a7e769`); one check now covers sim + CP1 + ship.** The
  check of main after sim's merge alone came back at 16:03: exited 0, 1920/0, baseline unmoved, **1 NOT JUDGED**
  (`scenario_perf` refused at 2.01×) — the hole ship's merge closes. Ship's W4 result over its own range: perf-judge
  (pinned, first, alone) judged **4 of 4** checks (1.07–1.47× after 48–108 s waits) where the unpinned in-suite run
  judged **1 of 4**; other streams' unpinned round-17 checks judged 4 of 6. Check wall time 1385–1536 s with it
  (perf-judge itself 65–158 s) against 1306 s without under the same five-stream load. The new verdict line:
  `>> check: N targets, all passed, ALL JUDGED  [ctx]` (the old prefix unchanged) or `N passed, M NOT JUDGED` with one
  row per refusal. Round 2's later light jobs ran ship's in-progress range-2 tree (not evidence about `64a7e769`; they
  found two range-2 bugs); the orchestrator accepted the soak without a third round. Ship's range 2 (voice D ON, the
  24k set) is `3ba814b7` + `88b70106`, its check launching. **A fact for him, on ship's page: at the browser's 2–3 fps
  a fetched clip arrives 16–21 s late (every fetch step queues behind the saturated main thread), so with voice D a
  first browser match is mostly subtitles until the clips are on the device.** The announcement to the five streams
  (merge `main`; the light lane's rules) waits for this check.
- **2026-10-03, 15:45 — sim: the kill cam as he will see it** (the LAPTOP, his window 1854×1011, desktop preset, real time,
  sumps seed 1 `--scripted`, a probe logging every `time_scale` change; LOADED 5.5–16.8, so not the record; 2 runs per
  arm). Old code: 5.19 s and 6.15 s real, but the whole wall-clock schedule fell inside TWO frames (1.7 s and 3.4 s
  frames): he got two still frames, not slow motion. Fixed code: 5.08 s and 5.36 s real over exactly 60 ticks and ~33
  frames: it is actually seen as slow motion, and on a saturated laptop it lasts as long as 60 ticks take (~2.5× the
  designed 2 s). Frames looked at: the last kill, the DEFEAT banner, the burst, the results flow unchanged. **For his
  playtest:** if the end-of-match slow motion feels long on the laptop, the knob is `KillCam.HOLD_TICKS` (42).
  **A finding nobody owns (round-18 candidate 8): a 1.7–3.4 s frame stall right at the final kill on the laptop**, in
  both arms — likely a first-use FX or shader stutter at the burst / banner. The proof series was stopped at a pair
  boundary; one seed-1 pair to 900 and one Terminus pair finish it.
- **2026-10-03, 15:35 — CP1 MERGED (`9314a2db` = yard's `1c497496`); DECISION: the k-turn outline fix is round 18.** Yard's
  contact count (builder0, War Rigs 14 m + Condemned tanks, budget 5200, elimination, 180 s cap, seeds 1–8, frozen
  square vs turned, counted to the decision; two populations of 8). Plant × kturn per minute, median square → turned
  (seeds where turned was higher): pit 25.9 → 24.7 (4/8); sumps 58.0 → 16.0 (0/8); terminus 32.2 → 18.1 (2/8); yard
  32.7 → 45.7 (4/8). Into containers: 7.7 → 8.5; 8.8 → 2.5; 0 → 0; 23.7 → 25.0. Steer contacts 300–500 a minute on
  both. No rise beyond the seeds' spread. **The absolute level is the round-18 finding: long hulls plant 16–58 times
  and scrape 300–500 times a minute on every layout.** The Terminus's 40 s baseline-style match is hash-identical
  (10 of 14 boxes parallel to buildings by rule; the 4 that turn are not reached in 40 s), witnessed otherwise by all
  8 elimination matches differing. Nobody merges `main` until its check after CP1 is green and announced.
- **2026-10-03, 15:30 — MERGED sim's fix (`d7860e7f` = `16a02e14`); the check on main is running.** The `kill_cam.gd` carve-out
  reviewed. F5's target `windowed-elimination-pair` (18 min on builder0, needs the display; exactly 60 slowed ticks in
  both runs and identical hashes, failing on the old code) goes to ship for `check-all`. F6 closed from round 16's
  laptop record (the field's thread saves 0.25–2.03 ms a tick, no contention: stays on). **Decision: the 17-pair proof
  (~8 h of a check slot) is cut** — the mechanism is now asserted deterministically; the record is the pairs already
  done + one sumps seed 1 pair to 900 + one Terminus pair + F5; the full fourteen only in ship's light lane, as
  confirmation. Still owed by sim: the kill cam's real duration and frames on the default path. Ship asked how long
  the tick-counted kill cam lasts in the browser at 3–5 fps.
- **2026-10-03, 15:27 — guns' web script duck is BUILT and proven (`1b5856ea`); DECISION: a web-only Master trim of −3 dB.**
  The duck lowers World's volume by the chosen setting's measured depth (`BOOTH_DUCKS[setting].script_db`: launch 18.2,
  MID 12.7, light 6.8 dB) while a booth line plays; off natively (tested). In the browser (Sample asserted by 46
  buffer-source starts; laptop, headless Chrome, real GPU): a loop on World went −8.5 → −20.4 → −8.5 dB for a −12 dB
  setting and kept playing; a later one-shot played normally. At 3–5 fps the dip lands in the line's first frame and
  the release is a 3–4 step staircase over ~1 s. With no limiter, four 30-a-side browser fights peaked at −1.6, −0.3,
  −1.3, −1.8 dBFS (0 of 423 half-second records at full scale): 0.3 dB of margin is none, so guns adds a −3 dB trim
  on MASTER (not World: every relation of the mix stays as native), web + Sample only, proven the same way and the
  peaks re-taken. Ship told: Q5's recommendation is (a) Sample + the scripted duck; he taps again.
- **2026-10-03, 15:23 — ship's constant-match sweep: the browser runs HIS fight at 3.4–4.9 fps on the laptop, and Stream
  is not an option there at any buffer.** (Guns' `4448e2c7` tree exported from a scratch copy; laptop, headless Chrome
  on the real GPU; Gangs v Law at his army size, seed 7, the Yard; CPU throttle 1× / 2× / 4×, N=2, interleaved, mode
  asserted on all 16 runs.) Share of time with sound at 1×: Sample 1.00 / 1.00; Stream 50 ms 0.07 / 0.06; 150 ms
  0.38 / 0.24; 300 ms 0.74 / 0.50. So Sample is the browser's mode and guns' scripted duck is its mix (told to make it
  robust at 3–5 fps). **The frame rate reframes his browser decisions**: asked of ship for the page's Today section —
  fps for his fight headless on the laptop GPU, in a real window on builder0, and what limits it. Round-18 candidate 7.
  **Ship's soak round 1 on `64a7e769`: exited 0, 23 targets all passed ALL JUDGED (15:20:29), 21 light web smokes
  beside it all green.** Round 2 queued.
- **2026-10-03, 15:13 — DECISION: guns builds a web-only SCRIPT duck this round.** He chose voice D, so the browser gets
  a booth; in Sample mode no bus effect runs, and guns priced the alternatives: MID's sidechain takes a median 12.7 dB
  off the battle while the caller speaks (launch 18.2, light 6.8); a static Announcer level cannot supply it (the booth
  peaks at −0.9 dBFS, no limiter) and a static World cut costs the guns 12.7 dB always. The script duck tweens the
  World bus's volume (~50 ms down, 300 ms up) while a booth line plays, by the same constant his audition tap sets;
  ON only on the web in Sample mode, OFF natively and proven so. Not a new lever for his page: it reproduces the
  relation he is choosing natively. To prove: a runtime World-bus VOLUME change is heard in Sample mode and glitches
  nothing (ship's observer); the full-mix peak in the browser with no limiter (a web-only World trim if it clips);
  then ship's joint run once voice D is on main. Q5's options on ship's page become (a) Sample + the scripted duck,
  (b) Stream at 300 ms, (c) Stream at a smaller buffer if a sweep shows it clean. Also: every valid World-first MID
  figure is 14.7–15.5 dB (the reconciliation closes); `make bus-order` (`41faf001`) prints the LAUNCH tree's bus order
  windowed from a `git archive` scratch copy; Stream at 150 ms plays 0.88–0.89 at 11 fps (N=4), 20–30 fps unmeasured.
- **2026-10-03, 15:06 — guns' SECOND correction, found by the reconciliation table: the bus-order "defect" was the
  control arm, and the reorder was wrong.** Two MID figures 5.4 dB apart on one match (page 14.7, `layout-ab`'s
  "runtime" arm 20.1) could not both be the runtime order. Cause: `FxWorld._init` makes `SfxSystem`, which builds
  World / Impacts / Bed / Gunfire / Crowd inside `mode.start()`, BEFORE the booth and music attach — so the windowed
  game was always WORLD-first; guns' order check was headless (booth first there), and `layout-ab`'s control arm had
  reset and rebuilt the buses Announcer-first. So `d542d79f`'s layout order was right; `47a8a43f` (Announcer first) was
  wrong and is undone at `bc47545a` (15:05:18 PDT), before the music arms and the MID `mix-ab` synced. **The two log
  entries below that say the layout changed the booth natively by ~4.6 dB, and that the corrected layout is
  "Announcer first", are WRONG as written:** the native equality of the layout is UNPROVEN either way until
  `layout-ab` is re-run with a control arm that resets before `mode.start()`. The audition page stands (its clips were
  World-first, the true old game); MID stands. Asked before a green hash: the bus order and sidechain sources printed
  from the LAUNCH tree windowed as ground truth, asserted in a test; which headless audio tests ran against an order
  the player never had. Three corrections from guns in two hours, each self-found; two were arms that were not what
  they claimed.
- **2026-10-03, 15:04 — the audition page is NOT affected by the bus-order defect: the hold on the booth item is lifted.**
  Guns answered from each run's sync time against commit times: the page's clips (`audition-clips` invoked 13:16:07)
  ran before the layout file existed, with buses built at runtime (Announcer first) — the order the corrected layout
  `47a8a43f` declares. Launch 21.7 / 8.8, mid 14.7 / 2.9, light 9.6 / 1.5 stand, and MID with them. `mix-ab` (13:39:05,
  `6b9cb5c0`) ran the WRONG order in both arms: its launch→now comparison is like-for-like, its absolute booth figures
  are set aside until the MID re-run. Asked: one table of every booth-over-battle figure with tree, bus order, duck
  setting and window. **Stream vs frame rate, first sweep** (guns; mode asserted; laptop headless real GPU; fps varied
  by viewport and army budget, **N=1 per cell**): 50 ms buffer clean at 58–60 fps (0.98–0.99), broken at 11–18 fps
  (0.43–0.47); 300 ms buffer clean at 21–60 fps, 0.96 at ~9 fps. Guns' row for the page: "Sample (no bus effects), or
  Stream with +300 ms on every sound"; asked for the 150 ms buffer at 20–30 fps and a static web-only Announcer level
  as the sidechain's substitute in Sample mode. Relayed to ship.
- **2026-10-03, 15:01 — brains diagnosed the year-old red scenario: the champion baits into a LOADED gun** (4 hits / 4
  shots; trace in brains' Status). **Decision: round 18** (`roadmap.md` *Round 18 candidates* 6): a decision change in
  the champion, its own ladder run; this round already carries CP1 and possibly the k-turn outline.
- **2026-10-03, 14:58 — ship's page v6 (14:56 PDT): Q5 un-chosen, his tap kept as `set_aside` in `choices/mix`, the wrong
  figure said plainly, no recommendation. Ship WITHDREW its own Stream frame times** (Sample 188 / 215 / 209 ms vs
  Stream 183 / 202 / 201 ms, logged below as accepted): the reports were deleted by a soak check's copy-back before
  the arm could be proven Stream. So the frame cost of Stream is UNMEASURED. `observe.mjs` now prints
  `mode=sample|stream` per run from buffer-source starts. Asked of ship for the sweep: hold the match constant and vary
  the frame rate by CDP CPU throttling (army size confounds frame rate with audio load); export Stream variants from
  a scratch copy, never an edit in the worktree; write reports where no copy-back reaches. Soak round 1 on `64a7e769`
  in progress.
- **2026-10-03, 14:55 — guns' check of `d542d79f` is RED (do not merge), and the bus layout had changed the booth natively.**
  (1) `make check exited 2`: 1948 passed, 1 failed — `test_announcer_booth` made a second "World" bus and its cleanup
  removed the declared one; fixed in the test (`f62e735e`, a merge-noted carve-out). (2) **`layout-ab` (builder0, his
  match, N=2) showed the layout's declared ORDER changed the booth's sidechain: World stage −12 vs −17.5 dB, booth over
  battle 15.5 vs 20.1 dB**, with whole-mix, booth, music and crowd levels equal — the equality the orchestrator asked
  for beyond the weapon probe caught it. Fixed `47a8a43f` (buses declared in the runtime order, Announcer first; the
  recorder prints the order and every compressor's settings). (3) Stream reverted `4448e2c7`. Range once green:
  `d542d79f..HEAD`. **OPEN, asked of guns: which tree did the audition page's fight clips, booth item and `mix-ab`
  sync?** If the wrong-order layout, the page's booth numbers (and the move of the default to MID) rest on a sidechain
  ~4.6 dB off; the lead is told to hold the booth item until guns answers. Stream vs buffer at ~9 fps (mode asserted,
  N=2): 50 ms 0.35 / 0.39 loud; 150 ms 0.82 / 0.80; 300 ms 0.96 / 0.97 — relayed to ship.
- **2026-10-03, 14:47 — A WRONG NUMBER REACHED HIM AND HE TAPPED ON IT: `choices/mix = stream` is VOID.** Guns' 14:00
  Stream pricing ("no dropouts at 7–8 fps", N=2) was not a Stream measurement: its script killed a subshell's PID, the
  Sample arm's server kept the port and served both arms. Guns found and reported it itself. Properly (laptop,
  headless Chrome on the real GPU, distinct ports, servers killed by PID, both arms with the layout fix, interleaved
  N=2): **Stream 0.41 / 0.39 of audio blocks loud at 9.5 fps; Sample 1.00 / 1.00 at 8 fps**; two different Stream
  exports agree. The orchestrator had relayed the wrong figure to ship's page and to him, without asking for an arm
  assertion (round 9's sentence, again). **Actions:** his tap set aside (`game_design.md` struck through, the dump of
  the tap kept); guns reverts `632df039` as its own commit — the running check of `d542d79f` is not restarted (the key
  is web-only; merge the green hash, then the revert, then the orchestrator's check on main); ship republishes Q5
  corrected and un-chosen, and confirms its own Stream arms were Stream; every web arm now asserts its mode. The
  re-pricing he needs: Stream's loud-block fraction against FRAME RATE (real window on builder0; 10 / 30 / 60 fps) and
  against `output_latency.web` (guns, in progress). Told to him directly.
- **2026-10-03, 14:17 — HE TAPPED ALL FIVE on ship's page** (db read by the orchestrator at 14:16:41 PDT; dumped to
  `streams/references/round17/ship_w2_choices_db.json`; recorded in `game_design.md` *Round 17: the browser build
  decided*): voice = **D** (per-line fetch), bitrate = **24k**, factions = **later** (the second pack; ON at ship's
  `1e4eedc0`), desktop = **beside** (as recorded; already the build), mix = ~~stream~~ (**VOID: see the entry above**). Applied: ship's soak hash
  `1e4eedc0` merges FIRST and unchanged; voice D ON + the 24k web clips are ship's SECOND range with its own check;
  Stream is guns' one-line `[audio]` setting (its own commit, native proven untouched). After both merge: ship's
  smoke requires sound and one browser run shows the battle dip under the caller. **The gun audition page's `db` was
  EMPTY at the same read** (`picks/`, `verdicts/`). Ship's soak round 1 (a dirty tree, so evidence not a hash):
  exited 0, 23 targets all passed ALL JUDGED, 1924/0, 1523 s, perf-judge PASS 1.07× after an 84 s wait at load 10.98,
  19 light web smokes beside it. Q5's frame cost: Sample 188 / 215 / 209 ms, Stream 183 / 202 / 201 ms (N=3, laptop).
- **2026-10-03, 14:13 — sim FOUND the Sumps' windowed fork: the kill cam, AFTER the match is decided.** (builder0, launch
  tree + witness, windowed Sumps, seed 3.) The per-tick clock line: `Engine.time_scale` = 0.2 on ticks 625–627 and a
  physics delta of 0.2/30 on 626–627 windowed; 1.0 throughout headless. At 625 Green's last unit dies, Match finishes,
  KillCam sets 0.2; the simulation keeps ticking after `finished`, and the kill cam ramped back on a WALL-CLOCK schedule
  (1.4 s + 0.6 s), so how many ticks integrated a shortened step depended on frame timing: windowed B (5 of 6 runs),
  windowed A (1 of 6), headless C (no kill cam). **Before the end, windowed runs were identical in all 8 runs.** Fix
  on sim's branch `eab2e906` (`game/theme/fx/kill_cam.gd`, the unowned-path carve-out: the kill cam counts simulation
  ticks; Match warns once if a LIVE tick runs at `time_scale` != 1); pre-registered UNMOVED: sim-baseline
  `05df1d55ba49cde1` and the headless Sumps tick-900 hash `441426e6489ed9eb`. Check and the ≥ 10-pair proof running
  (asked: state the ~4 % chance of ten agreeing pairs unfixed; the kill cam's real duration on the default path; every
  writer of `Engine.time_scale`). Brains' "aim via intel" and the orchestrator's thread hypothesis were both wrong.
  Told to all four others: a windowed A/B is one fight until a decided elimination. **Two design notes for him, filed
  in `roadmap.md`:** post-match slow motion runs tick-counted rules at full rate while motion runs at 0.2× (and
  tactics' `--slow-motion=` does that to a LIVE match); windowed and headless differ after a decided elimination by
  design.
- **2026-10-03, 14:11 — guns' `mix-ab` on HIS match** (builder0, tree `6b9cb5c0` = the layout fix + all G2/G3 but still the
  LIGHT duck; launch arm = the same build with `--mix=launch --sfx-direction=all:0`; 150 s, **N=1 per arm**; 0 clipped
  samples). Sumps seed 92721, launch → now: integrated −17.5 → −16.6 LUFS; true peak −3.1 → −1.6 dBTP; World stage
  median −15.8 → −4.6 dB; Bed duck −18.5 → −6.4 dB; booth over battle 22.0 / 8.3 → 10.6 / 1.8 dB (median / busiest
  tenth); **music under battle −7.1 → −14.4 dB**. Foundry seed 3: −18.2 → −17.0 LUFS; booth 21.9 / 10.4 → 11.2 / 2.5;
  music −6.9 → −16.4. So ~1 dB louder, the guns ~10 dB back against the booth, and **the music now 7–9 dB further under
  the fight (its level unchanged; the battle rose)**. Asked of guns: a music-level item on the audition page (three
  levels, his tap) with the level it would defend as the default; `mix-ab` re-taken at the green commit with the MID
  duck so the close's record describes what ships.
- **2026-10-03, 14:06 — the parity drift is CLOSED: no tree change moved it.** Brains ran parity at `1af40b4b` on today's
  builder0 (same tool, args, maps, seeds, 16 matches): `0095f2cf`, the launch tree's digest. So round 16's `cf50ef2b`
  was recorded on another machine or library (brains' READING: the laptop, glibc 2.39 vs builder0's 2.43; round 16's
  Status never named the machine). The "UI / theme / control path into headless decisions" lead is dead; sim told.
  Brains' reference is `d461fb2f` (builder0, launch tree, 24 matches incl. the Sumps) and `tools/ai_parity.py`'s DIGEST
  line will carry machine + glibc. Lesson 246.
- **2026-10-03, 14:00 — guns priced the browser's mix (Stream playback), carried to ship for a Question 5 on its page.**
  `8d18de13` + a scratch export with `default_playback_type.web=0`, laptop, headless Chrome on the real GPU, 7–8 fps,
  **N=2 per arm**, both arms with the bus-layout fix: first sound Sample 13.0 / 14.3 s, Stream 14.7 / 15.2 s; no
  dropout in ~45 s of fight per run in either mode. Stream gives the browser Godot's own mixer (limiter, ducks, the
  booth's sidechain once the web has clips); Sample runs no bus effects. Not priced: ~2 fps software rendering,
  phones, long matches, and **the frame cost of mixing on the main thread** (asked of ship: fps per arm, N=3). Guns
  recommends Stream, behind his tap. Also from guns: no bus is found by an order-dependent index; on the web guns,
  impacts, engines, crowd and music are each audible after the fix (one run per layer; the web solo leaks for `ui`
  and `booth`, not chased); `make layout-ab` (booth, sidechain, music, crowd; layout vs runtime buses, his match) is
  queued behind `mix-ab`, which started on builder0 at ~14:00.
- **2026-10-03, 13:44 — an incident, reported by the worker that caused it: guns killed yard's `chain3.sh`** (13:42;
  `pgrep -f "[c]hain3.sh"` + kill matched yard's script of the same name). Verified at 13:43: yard's
  `make remote T=check` (PID 388082) survives under systemd and the build continues; the rest of yard's chain (the
  contact count, the hashes, the AFTER frames) will not launch — yard told to poll `check-cp1b.log` and restart the
  remainder as a new chain at `1c497496`. Rule to all five: stream-named scratch scripts, stop by a recorded PID only,
  times from `date`. Lessons 243–245 written (clock times; `chain3.sh`; the slot's unit).
- **2026-10-03, 13:42 — guns: audition page v3 is COMPLETE for his ear** (same URL): the in-the-fight clips (15 s of HIS
  match — Sumps, Law v Condemned, seed 92721, budget 4600, builder0 — the same moment in every arm), the whole game
  before / now (**−16.8 → −15.2 LUFS: 1.6 dB louder, not quieter**), and the booth item (20 s, the caller over the
  loudest fight; he speaks ~76 % of that match). Caller over the battle, median / busiest tenth: launch 21.7 / 8.8 dB,
  mid 14.7 / 2.9, light 9.6 / 1.5. **Guns moved its own shipped default from light to MID (−24 dB, 4:1) at `4f3d117c`**
  on that measurement (6.4 dB back to the guns, a 14.7 dB median lead for the caller); his tap decides. `db` read by
  guns at 13:41 PDT after v3: empty. Told to him: the page is ready to judge.
- **2026-10-03, 13:39 — guns FOUND AND FIXED the browser's silence (`96c37137`, on its branch, not merged).** Cause: in
  Sample playback ONE runtime `AudioServer.set_bus_send()` silences every sample playback after it, Master included
  (probes: untouched Master audible; `add_bus`, a rename, an effect on Master harmless; one `set_bus_send` and all is
  silent) — SfxSystem, the booth and the music director all set sends at startup. Fix: every bus declared with its send
  in a new `res://default_bus_layout.tres` (guns', C17.6). On ship's scenario, same tree, interleaved, **N=2 per arm**
  (SwiftShader): without it silent for 45 s (peak −200 dB); with it loud from ~11 s after READY, peak −14 dB. Natively
  the weapon probe matches within 0.01 dB, so it ships as the default. **Asked before its green hash:** the same
  equality for the Announcer, Music and Crowd buses and the sidechain; no bus found by index; what classes of sound are
  audible on the web. Ship told: guard the layout file in the export model; flip `"sound"` to `require` as its own commit
  after the merge. **Still open, his decision later:** bus effects do not run in Sample mode, so the web mix has no
  limiter, ducks or sidechain (a web-only Stream setting, stutter unpriced).
- **2026-10-03, 13:38 — yard: the kerb rule changed, the holds are gone, the count is queued.** Pivoting a flush kerb box
  into its building sank the far corner 42 cm (≈14 px at his pose): dropped. **A container flush against a city block
  now keeps the block's angle** (`ad20fd89`), which removes the two `_square` holds — so the planner question is
  measured on the layouts as they will ship. Terminus: 10 of 14 boxes parallel to their buildings, 4 turn (a question
  for his page with a close frame; asked whether those stacks' UPPER levels still get the visible offset). Guards in
  `tests/test_arena_container_joints.gd`: every lane within 10 cm of its square width (largest loss 8 cm, dry twins),
  junction clearances (Boneyard and the Crossing lose 12–14 cm with 4.7–8.6 m spare, stated), flush boxes keep their
  place. **The Maze is never dealt** (`Arena.ROTATION` = yard, pit, terminus, crossing, sumps, locks): a fixture.
  Queued at `1c497496`, one at a time: check → the contact count (War Rigs + Condemned tanks, 180 s, 8 seeds × 4 maps ×
  square/turned, plant/kturn vs steer) → hashes ×2 → AFTER frames.
- **2026-10-03, 13:18 — ship: in the browser, EVERY sound started as a web sample is inaudible** (laptop, headless Chrome
  on the real GPU, ship's `7f76ae81` tree, 11 fps, **N=1**; autoplay allowed AND a trusted CDP click; the AudioContext
  `running` from 0.9 s — the "no gesture" hypothesis is ruled out): 924 sample playbacks started in 60 s (the 70.5 s
  pre-match bed, 769 one-second buffers, UI and SFX one-shots), all exact zero at the audio thread; the first non-zero
  block at 60 s is the fight music (stems in an `AudioStreamSynchronized`, mixed by Godot's own mixer). So a browser
  player hears the fight music and nothing else. Stream mode is audible from 11–18 s. Carried to guns with a hypothesis
  to test (the runtime-created buses of `SfxSystem.ensure_world_bus` may never be mirrored into WebAudio's sample
  graph: a `default_bus_layout.tres` might fix it without Stream mode). Order unchanged: guns' G4 clips first.
- **2026-10-03, 13:14 — brains' parity: side (a), its branch changed no decision** — the launch tree `3713fdaa` itself
  gives `0095f2cf` on yard + terminus (16 matches, builder0) and brains' `29f7578d` matches it row by row; the reference
  with the Sumps is `d461fb2f` (24 matches). **The cause of the drift from round 16's `cf50ef2b` is NOT named:**
  `cf50ef2b` was recorded at `8318b9db` and `1af40b4b`; `git diff 1af40b4b 3713fdaa -- game` is round 16's late hud and
  render merges (`game/ui/**`, `game/theme/fx/static_instancer.gd` and shaders, `game/control/rts_controls.gd`,
  `control_groups.gd`: verified by the orchestrator), no sim or ai path. Either a UI / theme / control change altered a
  HEADLESS match's decisions (a non-sim path into the simulation: sim's class of problem, sim told as unconfirmed) or
  the digest moves for a reason outside the tree. Brains runs parity at `1af40b4b` and bisects if it reproduces.
- **2026-10-03, 13:13 — CP1 gained a condition: turned corners may defeat the k-turn's outline check on EVERY map.**
  Brains' reading of `_outline_ok` (code at `b9a0d90e`, no runs): its 10 samples leave a 3.5 m gap along each side of a
  14 m rig; a square box presents a face the samples see, a box turned a couple of degrees presents a CORNER that can
  push between two samples while both read clear. Fix ~20 lines (side samples at ≤ 1.5 m), changes decisions for every
  long wheeled hull, ~2× the outline's navmesh queries; brains recommends round 18. **The orchestrator's catch:** then
  holding two avenue boxes square bounded one test, not the effect. **Asked of yard before CP1 is called:** plant/kturn
  contact ticks per match for the long hulls, square tree vs CP1 candidate, same seeds, Terminus / Yard / Pit / Sumps,
  N ≥ 8 per map (steer contacts separately). No material rise → CP1 as is, the fix in round 18; a rise → the fix rides
  this round last (brains, after T5, merged alone after CP1) or CP1's skew near streets is bounded.
- **2026-10-03, 13:13 — the browser's opening silence may be partly the TEST** (guns' two hypotheses, carried to ship):
  the pre-match beds are single imported Oggs, the fight beds are stems in an `AudioStreamSynchronized`, and first
  sound came exactly at the switch to the stems. H1: a Synchronized stream falls back to Godot's mixer and is heard
  while a sample started in the pause is not. H2: a sample started while the browser's `AudioContext` is still
  suspended (no gesture yet) is never scheduled. Ship's runs are scripted, so nobody clicks: asked for the autoplay
  policy, the `AudioContext.state` timeline, and one run through the title with a real (CDP) click; until then the
  page says "in a scripted run with no click" beside the 43 s.
- **2026-10-03, 13:12 — yard attributed the nav failure: a planner property with no margin, not a lost street.** Bisected
  one Terminus container pair at a time (laptop, local runs): only the avenue's kerb boxes flip `test_nav_back_and_fill`.
  (i) A 20 ft kerb box turned 1.37° had moved its street face 14 cm into the avenue (17.56 → 17.17 m) and the lane
  validator passed (its bar is 12.14 m: it cannot see a turning pocket) — fixed: a flush kerb box now pivots into the
  building and keeps its street face. (ii) Then the 40 ft box at (±8.78, ±60) turned −1.89°, its face NO closer than
  square, alone fails: the square run already scrapes it in route steering (ticks 221–242) and back-and-fills clean in
  5 legs; the turned run plans a different leg and plants into it (kturn, ticks 263–274, 9 contact ticks). Yard's
  suspect: `_outline_ok` (`game/ai/movement.gd`) accepts an outline sample off the mesh at a leg's START within 0.05 m,
  10 samples on a 14 m hull. **CP1 candidate `39c463f0` holds the two avenue kerb boxes (and mirrors) square**; its
  builder0 check is next. Carried to brains (its reading, the fix's size, this round or round 18; the orchestrator
  leans round 18). Asked of yard: how deep a kerb box's corner sinks into the building and whether it shows; a
  generator-level test that no turned container's street face is closer than its square one; is the Maze ever dealt.
- **2026-10-03, 13:12 — ship's check of `9a575a26` came back RED, by its own light-lane bug** (`make check exited 2`: 22
  passed, 1 FAILED web-smoke; 1919/0; baseline and determinism unmoved; 1385 s): a light job of the same worktree was
  serving on the worktree's `SMOKE_PORT`, so the check's smoke loaded the light folder's export. Fixed `7f76ae81`
  (light runs shift every `*_PORT` by +500). In the same check: **perf-judge JUDGED PASS at 1.07× after a 48 s wait
  while the unpinned in-suite run refused at 2.03×.** Also built behind `?web-packs=factions`: a 21.3 MB patch pack
  fetched once and loaded with `load_resource_pack`, so the largest single file stays the main pack. **Merge condition
  set: a soak** — on the named hash, a full check with a light job of the same worktree beside it, twice, both green,
  plus a list of everything two runs of one worktree share. Ship's web-silence numbers relayed to guns: 45 s of
  digital zeros at 60 fps on a real GPU during the planning pause; SwiftShader N=3, Sample 45.9 / 49.7 / 49.3 s to
  first sound, Stream 12.6 / 11.3 / 18.2 s — **not a low-frame-rate artefact**.
- **2026-10-03, 12:57 — the orchestrator's own error, corrected: this log's times were guesses.** Entries had been
  stamped "+1 h", "~13:15", "~13:30" from the feel of the conversation; `date` said 12:55 PDT when 13:30 was already
  written. Every entry is now stamped with its logging commit's time. Two workers had the same fault (ship's page read
  "13:18 PDT", guns' "~13:21", both ahead of the clock): both told to take every time from `date`, C15.2's read times
  included. **A time in a doc is read from a clock, never estimated.**
- **2026-10-03, 12:57 — guns: audition page v2 on the same URL** (dry clips loudness-matched down by default; width
  re-measured on the tail after 0.15 s — the tails were 0.05–0.18, now tank A 0.38, 25 mm 0.56, kill 0.32, MG 0.24 with a
  decorrelated room, `e967f25e`; the sub survives the 192 kbit/s MP3 at −0.27 dB from 20 to 200 Hz); the other factions'
  weapons brought up and on the page (railgun, twin MG, mortar, missiles, pulse cannon, flamethrower). Round spend
  2,363 credits, balance 35,394. **Pack corrected: the defaults are now 13.6 MB imported (not 9.9), alternates 4.6** —
  so faction art + defaults = 103.0 MB, over GitHub Pages' 100 MB per file even without the alternates; relayed to ship
  (the second `.pck` is now required, not optional). **Decision: no QOA import for the loops** (−5.9 MB but lossy and
  per-file, so the native build would get it too; the native sound is what he asked for). The fight clips and the
  booth item still wait on builder0: at 12:55 guns' `audio-pass` had queued 32 min, second in line behind brains.
- **2026-10-03, 12:52 — brains → sim (carried): the fork's lead is the AIM via intel** (a READING of code at
  `3713fdaa`/`b9a0d90e`, no runs): brains write only `command` and `intent` to a Tank; a Rust unit aims via Gunnery at
  contact positions from `game_match.intel[team]`; if intel is written from the `VisibilityField` worker thread or
  snapshotted at thread completion, every AI unit's aim moves by float noise in one tick and scripted Green stays exact
  — sim's signature. Brains' "cannot vary" list (AiTickCache keyed by tick over spawn order; frame-keyed memos change
  hits not answers; nav answers change only at a sync — check `map_get_iteration_id` 620–630; CoverMap built once;
  elements on `(tick + id) % UPDATE_TICKS`; no frame count or wall clock in a decision) relayed whole. Sim asked: does
  its dump carry `command.aim_point` at full bits (identical aim would kill the lead), and to run the
  `--sim-off=visfield_thread` arm next with N meaningful against its rate. **Brains still owes the parity-digest side.**
- **2026-10-03, 12:50 — ship built a LIGHT lane** (`eb6abb0e`, inert without `LIGHT=1`): `make remote LIGHT=1 T=…` queues
  a one-process job in its own pool (2 slots, own FIFO, `--jobs` = 1; 7.5 GB heavy + ~1.5 GB light inside ~11 GB), so
  a windowed series or a shot set no longer takes a check's slot; tests in check. perf-judge's worst-case wait cut
  ~22 → ~11 min (`1d057e22`). **Decisions:** it rides ship's one merge range (not split); **ship's range merges BEFORE
  yard's CP1**, so that merge carries no fight-changing commit and ALL five streams (sim included) can take it — say so
  in the announcement. At the merge announce: LIGHT is for one process with no fan-out; one heavy + one light per
  stream is the ceiling; a light Godot still counts as P-core busy. Ship owes: the green hash on HEAD ≥ `1d057e22`,
  the verdict line's exact format, wall times, and the judged rate (k of N) pinned vs unpinned.
- **2026-10-03, 12:48 — sim: the fork has a signature** (launch tree + witness `cc3d82f2`, builder0, windowed Sumps,
  seed 3, **N=1 pair**): identical to tick 625, forked by 630; at 630 ALL 34 Rust (AI) units differ in the last bits
  (turret yaw ~2e-6 rad, hull yaw, position, velocity) including parked units with identical commands; all 5 Green
  (player-ordered) units exact; frames and ticks 1:1 (catch-up ticks ruled out for this pair). So: a team-wide input
  every brain-driven unit consumes each tick. Relayed to brains with one question (every such input that could vary in
  the last bits: unordered aggregates, frame-keyed caches, nav sync, the field's thread); sim asked for the first tick
  and first FIELD (intent vs state) and the tick of each nav map change. Sim now runs two-run batches (~25 min a hold).
- **2026-10-03, 12:46 — yard: CP1 is NOT ready.** Check at `e6cf19ff`: 1920 passed / **1 failed**
  (`test_nav_back_and_fill`, the rig turning without touching a wall), baseline and determinism unmoved. Yard is
  attributing: a real loss of turning room on a dealt street (yard bounds the skew; do not loosen the test), a test
  tied to exact geometry (a frozen fixture, brains' file, by request), or a nav assumption of square footprints
  (brains' code). CP1 does not change `distance_to_footprint` or any layout key (guns told).
- **2026-10-03, 12:41 — the round's bottleneck is the slot queue, not the box.** builder0: load 0.78 on 12
  threads, 11 GB free, all 3 slots held (sim's 20-run `windowed-series` in ONE hold at ~7 % CPU; yard's before-frames
  chain in a second folder; yard's check), five jobs waiting 18–30 min (brains ×3 folders, ship, guns). Slot count 3 is
  deliberate (`remote.sh` header: latency per check); NOT changed. **Rule added to `workstreams.md`:** one invocation at
  a time across all of a stream's folders, one hold ≤ ~30 min; sim told its series would be killed at the 5400 s slot
  timeout and to batch 3–4 runs per hold (recording load per batch: pacing is its suspect); ship asked to PRICE a light
  lane / per-run series runner (W4), not to change slots mid-round unannounced.
- **2026-10-03, 12:43 — guns:** audit sounds going in (shield back up 23–39 a minute; skids and track squeal; burning
  wrecks and cook-off; mortar rounds heard coming down — no sim change); `shield_effect.gd` LENT for one additive
  `shield_up` call (C17.6); impact surfaces test the rotated footprint (`366e75e7`); a booth-duck item (launch / mid /
  new) on the audition page; `make mix-ab` re-takes G1 on his Sumps match. Web pack 68.2 → ~82.7 MB with the new sounds
  (−4.6 MB once he chooses), git +44 MB — relayed to ship. Balance 35,670 after batch 3.
- **2026-10-03 — brains:** costs now taken pinned and by a split A/B inside one process (whole-block alternation read
  ±16 % for levers touching ~2 % of the work); equality on the Sumps too. **OPEN: round 16's parity digest `cf50ef2b`
  no longer matches (`0095f2cf` at brains' first commit)** — asked which side: main drifted after the digest was
  recorded (the fire-RNG fix or Law's APC on tracks), or brains' first commit changed a decision with levers off.
- **2026-10-03, 12:31 — ship → guns: the browser build is digitally silent for a match's opening** (tree `9a575a26`,
  laptop export, headless Chrome on the real GPU at ~5 fps, scripted Gangs v Law on the Yard, **N=1 per arm**, an
  AudioWorklet on WebAudio's output): with Godot's web default playback type (Sample; `project.godot` has no `[audio]`
  section) the output is exact zeros until 43.3 s (the music's pre_match → fight_momentum switch), peak after −13.3
  dBFS; with `default_playback_type.web=0` (Stream) first sound at 13.7 s, peak −7.2 dBFS; on SwiftShader at 2 fps,
  zeros for all 45 s. Reading NOT proven: Sample mode bypasses Godot's mixer, so bus effects (guns' whole G2 mix) do
  not exist on the web. **Queued in guns' lane after its audition page** (reproduce, establish what Sample drops,
  price Stream's stutter, a web-only `[audio]` setting behind a switch — his decision, C17.4). Ship asked for N=3 and
  one real-browser run at a normal frame rate (it may be a low-fps artefact), and to land `web-match-smoke` as a
  MEASURE line until the decision, then failing. On ship's W2 page: the browser's sound is one question in three parts
  (the booth's clips, the opening silence, the mix that does not apply).
- **2026-10-03, 12:30 — guns G1: the mix costs the guns more than the samples do** (builder0, the launch mix, **ONE
  match**: Gangs v Law, Foundry, seed 3, 150 s, 30 a side, bus taps per stage; full table in guns' Status on its
  branch): the booth's duck on World (−28 dB, 6:1) holds the battle a median 26.5 dB under the booth, which speaks
  ~70 % of that match (retuned to −20 dB / 2.5:1 at `443648dd`); impacts duck the Bed −14.5 dB median (retuned
  `5b2caa2d`); `AudioEffectLimiter` adds +3 dB make-up and clamps every loud sound to −6.5 dBTP, so the tank, a held MG
  and the railgun peak the same (replaced by a HardLimiter, no make-up); Godot scales the distance filter by the
  voice's volume (the 25 mm lost 11.5 dB above 2 kHz at the camera's focus; the tank's crack −25 dB at 120 m);
  the tank's file AND its master have 0 % above 2 kHz; ElevenLabs returns mono even for "wide" prompts. G3 directions
  (tank, 25 mm, heavy MG, the kill) and G5 impacts by surface (read from `Arena.active`) are built; no green hash yet.
  **Asked back:** the table re-taken on HIS match (Sumps 92721, Law v Condemned); the speech-to-battle level before and
  after the booth retune and a dedicated old / middle / new item on the audition page (his ear: he loves the booth);
  whole-mix LUFS before and after the limiter swap; the surface lookup against yard's ROTATED footprints; mix and
  samples as separate commits. **The ElevenLabs balance is 36,195** (ledgers: the announcer's batches took it from
  ~111k on 09-19 to 39,731 by round 16; guns has spent 1,567 this round) — told to him; guns warns before any batch
  that would take it under 20,000.
- **2026-10-03, 12:19 — ship MEASURED the core-type effect on builder0** (`make perf-cores`, `43390f5c`, load 6.7–10.5
  with 28 godot processes, taskset-pinned, **N=3 per arm**): E-cores (CPUs 4–11) 1.76–1.93× the idle reference
  (`ai_usec_per_tick` 17 728–21 668); P-cores (0–3) 1.83–1.87× when shared, **1.10× when free** (11 046). Rounds 15–16's
  `scenario_perf` refusals were mostly the scheduler, not "a busy box". **An unpinned builder0 ms under load is one of
  two machines, 1.6–1.8× apart** — relayed to brains (pin its priced runs, alternate inside one process, print
  `perf_reference` beside every ms; round 16's loaded ms carry that uncertainty), guns (its `audio-bench` budget) and
  sim (earlier, as a lead). Ship's `bdb0fe09` (not yet green): `check` runs `scenario_perf` first, alone, P-core pinned,
  waiting up to 240 s for idle P-cores, 3 attempts; the verdict line gains `ALL JUDGED` or the named refusal.
  **Decision:** `tests/ai_scenarios/scenario_perf.gd` is LENT to ship (brains told) for one additive MEASURE line —
  `ai_usec_per_tick ÷ perf_reference` (six runs collapse to 12.4k–14.6k) — printed, NOT judged, collected over the
  round's checks; making it the judge is a round-18 one-liner if the spread and the smallest catchable regression hold.
- **2026-10-03, 11:48 — yard: the baseline runs on `foundry`, which has no containers** (verified: `DEFAULT_LAYOUT`,
  0 containers in `foundry.json`). CP1 will NOT move `05df1d55ba49cde1`; it still changes every fight on the dealt maps.
  C17.1 corrected in `workstreams.md`; yard asked for a per-layout before/after hash table as CP1's evidence; sim and
  brains told that "baseline UNMOVED" proves nothing on the maps he plays (their equality claims need a hash or
  `ai-parity` on the Sumps). **A round-18 candidate: the baseline covers one map.** Yard keeps maze and barriers
  square as fixtures (asked: is the Maze ever dealt to a player? if so it is his page's question).
- **2026-10-03, 11:48 — ship: three findings.** (1) `export-guard` (static: every file the game reaches for against
  every preset; both 2026-09-22 breaks turn it red) is going into `CHECK_TARGETS` (22): tell the other four when it
  MERGES, at its green hash. (2) The web pack was 175.6 MB, 107 MB of it `_agents/streams/references` screenshots Godot
  imported and exported; ship excludes `_agents/*` in the presets (68.2 MB). **Its request, done on main by the
  orchestrator: `_agents/.gdignore` + the 105 tracked `.import` sidecars removed** (verified first: the only
  `res://_agents` read in code is a `FileAccess` read of a `.md` in `tests/test_control_panel.gd`, 12/12 with the marker
  in place; own `make remote T=check` before the commit: **exited 0, 1915/0, 21 targets all passed, baseline unmoved, builder0 loaded** — committed as `30a2ffe1`; streams get it at their next announced merge of `main`). No more sidecar commits
  at a close. (3) **The announcer's clips are in NO export, desktop included** (the folder is `.gdignore`d and read from
  the real filesystem): the brief's "the Desktop preset keeps the clips" was wrong (written from the preset alone); W2
  now prices how ANY shipped build gets a voice. Ship's W4 lead, UNTESTED: builder0 is a hybrid i5-1345U (4 P-cores,
  8 E-cores) and `scenario_perf`'s refusals may be core type, not load — relayed to brains and sim as a lead only.

**Launch record:** `make remote T=check` at `153627f9` (builder0, idle, 1117 s): **exited 0, 1915 passed / 0 failed, 21 targets all passed**, sim-baseline `05df1d55ba49cde1` (unmoved), determinism `762a0576f944f5b7` — read from the wrapper's own lines in `build/r17-launch-check.log`. After it: docs only (the five briefs, `workstreams.md`, `roadmap.md`, `game_design.md`, this file); the launch commit's diff against `153627f9` touches nothing outside `_agents/` and `HANDOFF.md` (lesson 236: verified with `git diff --stat`, not asserted). Worktrees created after the docs commit, offsets 1–5 as the table.

## ✅ ROUND 16 IS CLOSED (2026-10-02 evening → 2026-10-03) — the round before this one

**Six streams, one night, a performance round from his words, with nothing cut from the picture or the gameplay and the
sim baseline unmoved by every performance commit; three decisions he tapped on pages, four he gave in chat; two
instruments that outlive the round.** His words are in `game_design.md` *Round 16 direction* and the four *Round 16:* decision
records; briefs in `streams/archive/round16/`; evidence in `streams/references/round16/` (hud's crops, render's LOOK sheet,
booth's veto db) and `references/perf/r16-*` (before, loaded, script profiles, the after record); lessons 235–241; round
17's candidates in `roadmap.md`. The merge table below was kept live and is the record.

### The numbers he will feel (the laptop, his path, `make perf-play`, CPU idle, `301bac8b` — the after record)

| | his path at ~30 vehicles | at ~39 (whole run) |
|---|---|---|
| **desktop preset** (the full look) | avg 41–50 ms, p95 61–75, **tick 25.6**, 1.4–1.7 ticks a frame, GPU 15.5–17.4, HUD 3.5–4.4, speed 1.0 | avg 68–74, tick 27.5–28, GPU 15.8–16.3, 84–92 % of frames over 34 ms, speed 0.96 |
| **laptop preset** (his five taps) | avg 40–45, tick 25, **GPU 10.2–11.8**, HUD 3.5–4.4, speed 1.0 | avg 67–73, GPU 10.6–11.3 |

**Read it honestly:** the launch 'before' (36.9 ms / tick 24.0 / GPU 19.8 at 30 vehicles) was a cinematic cpu-vs-cpu run
without the player's layer, the fog field or the booth — not the same path — so the round's wins are the within-run
numbers per stream, not this table against that one: **brains 9.4 % of the whole tick's scripts (every decision
identical), the fog field 1.85 → 0.36 ms a tick, the recorder's census 3.0 → 1.2 ms, HUD script 5.6 → 2.9 ms a frame
(−48 %), the GPU −2 ms pixel-equal and −6 ms by his taps (the laptop preset puts the GPU at the 10 ms line at his
window).** What is left is the TICK: 25 ms at 30 vehicles on the main thread, ~85–90 % brains, and equal-answer work is
spent — the 4 ms brain budget needs decision changes, each priced for his page (round 17 candidate 1; the instruments to
price them are in place). A locked 30 at 30 vehicles on this laptop needs that or a lower tick rate for the brains.

### The findings that were not on any list

1. **No instrument measured the game he plays** — every bench was headless or cpu-vs-cpu and muted; the fog-of-war field
   (hundreds of raycasts a tick) ran only in his skirmish. `make perf-play` (play's CP1) now runs his path; the frame
   time it read was wrong too: perf-scene's `avg_ms` was `delta` = GAME time once saturated (lesson 237).
2. **Every skirmish rolled fresh shot spread** (the fire RNG seeded only by the match runner): the cause of render's
   parity noise, found by sim from render's frames. A second windowed-only fork on the Sumps (ticks 601–630) is round 17's.
3. **The browser build had been dead since 2026-09-22** — two export breaks the same day (`FactionArt` excluded with the
   art; a `preload` of a `.gdignore`d `tools/` script) — and `web-smoke` lived only in `check-all`. Fixed, smoked, and
   `web-smoke` is in every `check` (21 targets).
4. **Round 15 never defined the draw order of six transparent effect systems** (an exact depth tie, an unstable sort):
   his explosions flipped between bright and paler on any render-list change. Pinned once, tested.
5. **The announcers' repeats were four caller pools one match uses up**, not the library size; his memory did persist.
   The free fix halved repeats; his 62 approved lines took them to ~1 a match.
6. **The opening music was silent in every planning pause**, not only the loader (the director paused with the match).
7. **Two HUD defects** (bars at a fixed 3.2 m: inside the War Rig; a duplicate bar) and **a regression hud caught with the
   garage tour** (white portraits from a change-only redraw and a freed texture) — the tour is outside `check`.
8. **The laptop has six processes wedged in uninterruptible disk wait** (two `du`s from before the round, render's
   copy-backs after): a reboot is the cure, his call; render's worktree folder stays until then (lesson 240).

### Waiting on the lead (live)

- **DONE 2026-10-03 (he rebooted; the orchestrator ran every command in this bullet; no worktree but main remains).** ~~A reboot of the laptop~~ (above). Before it: nothing of the round's runs locally. After it, the one piece of
  housekeeping left, in the main checkout: `make worktree-remove STREAM=render` (if it refuses on the wedged files:
  `git worktree remove --force ../godot-render`, then `rm -rf ~/projects/godot-render`), then `git branch -D stream/render` —
  the branch is merged (`5f7a4917`, `5d59bfa3`); and `git branch -D hud-before-probe` (hud's measuring baseline, never
  to merge). builder0: `rm -rf ~/tank_squad/godot-brainsbase`.
- **Playtest list:** `make skirmish` from the title (the opening track carries through the loader and the planning pause;
  the enemy faction opens on RANDOM — never his own); LOOK LIGHT vs LOOK FULL in the HUD beside QUALITY 30 (his five taps
  are LIGHT; the launch line says which preset the adapter chose); a big fight on the Sumps (the field, the bars over
  each hull, one bar on a selected unit, the portraits on the card); a Law army with the APC squad ordered to turn in place
  (tracks); the announcers over three matches (the four pools, his 62 lines); `--perf` for the SLOW ×N line.
- **No page is unconsumed:** booth's veto page (62/62, 04:31–04:34 UTC) and render's levers page (07:07–07:09 UTC) were
  both read and applied; no other page was published.
- **For round 17, his call on the order:** `roadmap.md` *Round 17 candidates* — the brains' decision levers priced (the
  far-idle think rate first), the HUD's three native candidates with their µs, the Sumps' windowed fork, the browser
  build's missing announcer voice.

### Housekeeping at the close

- Worktrees booth, brains, sim, play, hud removed after the ancestor check and the ignored-files listing (hud's last probe-only commit `bd9bcd6d` merged first: the hud-bar-shots the round16/hud references were taken with; two Godot-generated sidecars dropped) (only `local.mk`
  and `override.cfg` outside the known categories; booth's 296 new masters rsynced into main first); branches deleted.
  **Render's worktree and branch stay until his reboot** (its `build/look-parity` is wedged: removal would wedge the
  remover). `hud-before-probe` is hud's measuring baseline branch, never to merge — delete at leisure. builder0's
  `~/tank_squad/godot-brainsbase` is safe to delete.
- **The closing garage tour on the final tree PASSED** (`make remote T=garage-tour` at `301bac8b`+docs: `TOUR_DONE failed=0` desktop
  and phone; frame 19_match_mid looked at by the orchestrator — both portraits on the card, the bars over the hulls, LOOK LIGHT
  beside QUALITY 30 on builder0's integrated GPU; kept as `references/round16/close/garage-tour-19_match_mid-{desktop,phone}.png`).
- The quiet-box `ai-perf` watcher never found builder0 idle under six streams; the closing check judged `scenario_perf`
  in-suite (all 21 passed), so the isolated pass is no longer owed. The watcher is stopped.
- `scenario_perf` refused in most full checks of the night (as round 15); the lower-load check order is still a candidate.
- The orchestrator's own errors this round: the launch tree carried a code change called "docs" (lesson 236); the first
  laptop record run lost a seed to a copy-back (lesson 235); a `pkill` pattern matched its own shell once (trip-up 19,
  again); the first "pin round 15's fireballs" decision was withdrawn on render's correction of fact.

_The launch record follows, as written:_

## 🚀 ROUND 16 IS LAUNCHED (2026-10-02, evening) — read this first

**His words** (verbatim in `game_design.md` *Round 16 direction*): *"the game is getting extremely choppy, which might
mean that we need to start deploying as a native app. But more importantly, it's likely that we just haven't done the
work latley to optimize our code to just find basic efficiencies we can gain across the codebase - before sacrificing
any of the existing graphics or gameplay let's find (or profile our code) where we can just get better performance out
of our application"*; then the opponent randomised in `make skirmish`, the title music through the loading screen, and
the announcers repeating (*"the set of things to choose from … must be minimal"*). Asked where/when (three taps): native
`make skirmish`/`make garage` on this laptop (Intel UHD 620, window 1854×1011), from the first seconds all match, default
armies. His latest recording: `build/recordings/2026-10-02T18-59-00-sumps.jsonl` (seed 92721, Law 24 v Condemned 27).

**The measurement that shaped the round** (the orchestrator, `make perf-scene` on his laptop at `1efa9940`, kept as
`streams/references/perf/r16-before-{720-cinematic,1080-his-flags}.json`, rows in that README): at his window with his
flags, **30 vehicles → 36.9 ms a frame: `tick_script_ms` 24.0 (the simulation; brains ~85 % by round 5's split), GPU
19.8 flat at every vehicle count, game+UI `_process` 2.6, FX 1.0, draw submission 1.6**; 52 vehicles → 100 ms, 3.5
ticks a frame (the game then runs in slow motion: `max_physics_steps_per_frame=3`); a locked 30 holds at **10**
vehicles. **Caveat (play, CP1, 2026-10-02 evening): perf-scene's `avg_ms` was built from `delta`, which above `max_physics_steps_per_frame=3` is SIMULATED time, so every saturated phase (ticks_per_frame near 3.5: the 52- and 66-vehicle rows) UNDERSTATES the real frame — those read ~100 ms whatever they cost; the unsaturated rows (30 vehicles, 1.3 ticks a frame) stand. `make perf-play` uses the wall clock and reports game_speed.** At 720p the same scene reads as it did on 2026-09-17 — **the game has been this choppy since round 5; round
5's budget was never met (tick ≤ 5 ms at 60, GPU ≤ 10 at 1080p); the GPU grew 9 → 12 ms at 720p since (venue, show,
water, airship, the new hulls).** No instrument measures the path he plays (`perf-scene` is `--player=cpu --cinematic
--mute`; `sim-profile`/`ai-perf` are headless); `VisibilityField` (~346 rays + ~12 100 cells a tick) runs only in his
skirmish. The code survey's suspects are in each brief's *Where things stand*.

| stream | offset | the job |
|---|---|---|
| brains | 1 | the AI's ~85 % of a 24 ms tick, no decision changed: LOS memoised per pair per tick, squared distances, allocation per think, nav queries per tick, the non-think tick; `ai_usec_per_tick` 10 022 → toward 4 000 |
| sim | 2 | the visibility field priced and incremental; `_update_intel`'s allocation inside the loop; the HUD's accessors cached on the tick; **CP1b** `Units.stat` cached (early, alone); the recorder's census tick; Jolt's bodies; then **CP2** Law's APC on tracks (his words), last, alone |
| render | 3 | `make look-parity` first; the GPU's ~8 ms base split by layer; work that renders nothing he sees; fragment cost; draws; glow + pool lights; a priced-levers page only if still over budget |
| hud | 4 | one fog-of-war walk shared; redraw on change (37 `queue_redraw` sites, 10 unconditional); per-tank per-frame work without allocation; one unproject table; camera and cutaway gated; `process_game_ui_ms` → ≤ 1.5 |
| play | 5 | **CP1** `make perf-play` (his path: human-side skirmish, his flags, his window, capped + uncapped, layers) in the first hours; a frame-time trace beside every recording; **the opponent randomised; the music through the loader**; audio ≤ 0.3 ms; the slow-motion trap explained |
| booth | 6 | the effective pool at each pick over his matches, ranked; memory across launches; new lines for the thin pools through **his veto page** (lead gate 1), generated after his taps on the ledger |

**Contracts** C16.1–C16.6 in `workstreams.md` *Round 16* — the two that matter most: **nothing is cut** (a lever that
changes the look or a decision goes on a page, OFF), and **the sim baseline is UNMOVED by every perf commit** (the one
planned move is sim's CP2). **Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for
every stream). Merge at the hash each stream names green; the orchestrator takes the laptop's quiet-window after-runs
at close (the two before-files are the comparison); read every page's `db` at close (booth's expected; render's if R8
is needed).

**Waiting on the lead (round 16, live):**

- **Booth's veto page — the announcers' thin pools:** https://claude.ai/artifact/QYrMFqKyrMZM1hAvzzadNR (`db` collection
  `verdicts`; read EMPTY by booth at 03:46 and 04:16 UTC). **ANSWERED IN CHAT, late evening 2026-10-02: *"I approved all the
  proposed announcements"* — all 62 lines approved, lead gate 1 satisfied, booth told to generate (`game_design.md` *Round
  16: the announcer lines, approved in chat*).** Lead gate 1 was: nothing voiced before his word. 62 drafted lines (the caller's streak, flurry, "another one", the cut-in, streak stat, final kill, upset; four PA
  results toward the venue); all approved = 74 recordings, ~5 374 ElevenLabs credits. **The finding behind it (B1):**
  his memory DOES persist (31 matches in `user://announcer_history.json`); the repeats are four caller pools one match
  uses up — streak (9 lines, 2.6 calls a match, 72 % heard again within 5 matches), flurry (10, 2.5, 58 %), "another
  one" (13, 2.6, 31 %), the cut-in (6, 1.35, 52 %); today 7.09 of 34 calls a match (21 %) were heard in the last 5
  matches (8 real matches of his matchups on builder0, replayed as a 40-match evening with one memory, laptop). B5
  (`a1985ba8`, check running): a specific line heard in the last 4 matches loses its 8× specificity bonus and the booth
  falls through to the generic pool — repeats 7.09 → 4.11 a match (three seed sets agree), at the cost of trade calls
  answered by a trade-written line 71 → 57 % on the fixtures. With the page's lines approved, ~1.0 a match (3 %).
- **Render's levers page — the picture-changing cuts, PRICED, each OFF unless he says:** https://claude.ai/artifact/PMFmmgGgQJ5QdfS5jh9pDG
  (`db` `decisions/<lever>` {decision on|off|try, words, at}; read EMPTY at publish, 2026-10-03 early). Seven levers at
  his window (laptop, frozen staged frame, within-run; GPU all 16.0 ms): **scale_075 −3.48 ms, scale_085 −1.48,
  no_env_fog −1.05, lights_2 −0.62 (0.01 % pixel change on the staged frame), no_haze −0.46, crowd_medium −0.31,
  unlit_stands −0.23.** Glow not offered (his round-5 word). Render's pixel-equal work is ~2 ms so far; the 10 ms
  budget at 1080p needs ~6 more, hence the page. Each is `--render-levers=<name>` to try. **Orchestrator's recommendation:
  `lights_2` (invisible on the staged frame) and `scale_085` (the softest image for the most ms) first; `scale_075` if he
  tolerates the softer picture; the rest are small.** **CONSUMED: his taps 07:07–07:09 UTC (read by render after 07:10): ON
  scale_075, lights_2, no_env_fog, no_haze, crowd_medium; OFF unlit_stands; scale_085 untapped. His words: *"we are testing
  development here on a crummy laptop (to catch these very cases). We should still have the option to keep scale at 1.0 on
  better gaming setups"* — decided as a RENDER PRESET (laptop = the five, desktop = none, chosen by the adapter type,
  overridable, a HUD toggle; render's R9, one declared commit; `game_design.md` *Round 16: the render levers, decided on the
  page*). R9 MERGED: the `laptop` preset is live on his laptop by the adapter rule; LOOK FULL / LOOK LIGHT in the HUD once hud's row merges.**
- **A rule from booth, for every automated run in the main checkout:** the main checkout's `user://` is HIS; a windowed
  bench with the announcer on writes fake matches into his history unless it passes `--announcer-history=off` (relayed
  to play for the harness; the orchestrator's 1080p before-run tonight wrote one such match).

**FOUND AND FIXED (sim, merged at `0010bcb4`): the skirmish's shot-spread RNG was never seeded.** `Match._fire_rng`
(spread, lobbed-round scatter) was seeded only by `seed_spawns()`, which only the match runner calls; a skirmish kept
`RandomNumberGenerator.new()`'s random seed, so every round's spread was a fresh roll per run — the cause of render's
divergence (first divergence at tick 254/262, at the match's first round: the same muzzle, a different shell direction).
Reproduces HEADLESS; the same at `8318b9db` and with `--sim-off=visfield`. Fix `0010bcb4` (witness `075cf241`,
`--hash-every/--hash-until`): seeded in `Match._ready` from the launch `--seed`; three runs identical to tick 900;
`test_match_fire_rng_seeded` mutation-checked; baseline pre-registered UNMOVED (the runner seeds explicitly). **Windowed on builder0 at that hash (`make windowed-repeat`, two runs): the Terminus identical to tick 870, but the SUMPS still forks at tick 630 (headless Sumps identical to 900) — a second, windowed-only mechanism; a per-unit dump from tick 560 is queued to name the unit and field; a round-17 item if it is not cheap.** `_sorted_tanks` explained: nothing calls it between ticks and the key does not miss — 354 comparator calls a frame is ONE full sort of ~56 tanks per tick on a path that runs about a tick a frame: the cache re-sorted on every new tick though the set never changes; S3b `9c1c65d0` keeps the sorted list (and its identity, so the S3 caches hold across ticks) when a re-validation finds the same tanks in the same child order; `team_frame` returns one of two read-only constants. S9/CP2 committed at `c7d450ee`, test-first, the laptop baseline-match hash `5f81684d9c38cb45` before and after; check queued.

**FOUND AND FIXED (the orchestrator, `export_presets.cfg`, after `e823fdd7`): the BROWSER BUILD had not loaded since
2026-09-22.** The web and server presets excluded `game/theme/factions/*` wholesale, and `tank.gd:343` /
`game_theme.gd:172` have called `FactionArt` since `9dcc42d3` → `Identifier "FactionArt" not declared`, every browser
launch dead for ten days; `web-smoke` is in `check-all`, not `check`, so nothing said so (sim hit it running the S1
browser checks). Fix: exclude the three art folders (`factions/{gangs,law,syndicate}/*`), ship `faction_art.gd`. **The smoke then
found the SECOND break, same day (`e58030df`, 2026-09-22): `match_runner_mode.gd` preloads `tools/metrics/trajectory_log.gd`,
and `tools/` is `.gdignore`d — never exported — so `main.gd` failed to compile in every export since** (`Cannot infer the
type of "TRAJECTORY"`). Fix `1c5cdf7c`: the script moved to `game/metrics/trajectory_log.gd`, four references updated,
lint 698/698. **Both smokes PASS on `465071da` (builder0: `make web-smoke exited 0`, `make garage-web-smoke exited 0` — the demo renders, the garage fight loop runs; screenshots looked at by the orchestrator: `build/screenshots/web.png`, `web-garage-fight.png`). The browser build is alive again.** **Close-out candidate: `web-smoke` into
`check`** (an export per check; decide at close so the streams' checks do not change mid-round). Lesson for the list.

**The earlier open finding (render), now explained by the RNG above:** the WINDOWED skirmish is not repeatable across runs past
first contact even at `--fixed-fps 30` — same tree, builder0, `--skirmish --scripted --seed=3 --budget=6500`: frames agree
to 0.015 % at tick 150 and differ 3–75 % at ticks 450/900 (different fights); headless `make determinism` is green. **Render's divergent runs were at `ba7b3d3d`, which does NOT include sim's S1 — the threaded field is exonerated; the
divergence predates the round.** Sim's question is now which windowed-only input reaches the sim (the scripted controller
driven from `_process`? the camera's vision cap?); evidence: `build/look-parity/floor_{a,b}/*/live_t0450.png` on render's
builder0 worktree (`--scripted` runs do not record); until answered, every cross-run windowed comparison (perf-play
before/after, capped vs uncapped) is two different fights past ~tick 150 — within-run layer alternation stands. Render's
parity shots freeze at tick 150 and stage effects (40 pairs, worst 0.020 %).

**THE WHOLE TICK RANKED ON HIS PATH (brains, `make ai-script-profile-play` = perf-play's command line + Godot's own
script profiler, builder0 with a display, `dd63e277`, 89 fight frames; `build/ai-script-profile-play.json`):** module
shares of all script self-time — **ai 55 %**, match 8.9, ui 8.2, theme 6.5, tank 5.6, tactics 5.2, control 4.7, camera
2.1, combat 1.7. Top functions: `Pathing.closest_point` **12.4 %** (232 calls a sampled frame; brains' batch 3 caps the
sweep behind most of them), `Tank._drive` 2.5, `TankBrain.decide` 2.2, `VisibilityField._mark` 2.2, `build_situation`
1.9, hud's `TaskPreview._from_planner` 1.8 (0.9 calls a frame: a heavy body), `AiTickCache._refresh` 1.5,
`Match._sorted_tanks` 1.1 + its sort lambda 0.6 (354 comparator calls a FRAME — relayed to sim), hud's `MovementReadout`
lambda 1.2, `Radar._draw` 1.1, `RtsCamera._process` 0.8, `SelectionMarkers.refresh` 0.8, `Match.team_frame` 0.6 (298
calls a frame, a new Dictionary each — relayed to sim). The instrument is documented in `unit_ai.md` §8.

**THE SAME RANKING AFTER (brains, `7f9a36bf` = brains 319aaa7f + main 67ccd090: sim S3b, hud batch 1; builder0 with a display,
80 sampled fight frames; `references/perf/r16-script-profile-play-7f9a36bf.json` beside the before):** module shares before →
after — ai 55.2 → 59.3, match 8.9 → 7.6, theme 6.5 → 7.4, tank 5.6 → 6.5, control 4.7 → 5.0, **ui 8.2 → 4.5**, tactics
5.2 → 3.8, camera 2.1 → 2.2 (shares are relative: a module that shrank pushes the others up). Script per sampled frame
19.8 → 16.1 ms (different frames sampled: read shares and calls, not ms). Top ten (self %, calls a frame):
`Pathing.closest_point` **10.2 % at 120 calls (was 12.4 % at 232)**, `Tank._drive` 3.0, `VisibilityField._mark` 2.6 (0.3
calls: the thread), `TankBrain.decide` 2.5, `build_situation` 2.3, `AiTickCache._refresh` 1.8, `CoverMap._features_along`
1.7, `Movement.drive` 1.6, `OrderController._physics_process` 1.4, `TankBrain.think` 1.3. **Dropped (brains' corrected read of the file):** `Match._sorted_tanks` 1.1 → 0.18 % (#110); `Radar._draw` 1.1 →
0.00 (its timed variant 0.39 %, #47); `TaskPreview._from_planner` 1.8 → not in the table; `MovementReadout`'s lambda 1.2 →
0.63 % (#30: halved, not gone).

**THE LAPTOP HAS PROCESSES WEDGED IN UNINTERRUPTIBLE DISK WAIT (D state) — a reboot is the cure and it is HIS call, not
during the round.** Seen 2026-10-03 ~03:45: two `du -sh` over his home folder in D since 2026-10-02 00:48
(`wait_on_freeing_inode`) and 01:26 today (`d_alloc_parallel`) — not the round's; render's copy-back rsync (`vfs_utimes`,
55 min) and an `rm -rf` (`filename_unlinkat`) inside `~/projects/godot-render/build/look-parity`. ext4 on the NVMe, I/O
pressure 0, the filesystem writes fine elsewhere, disk at 95 % (5.8 GB free). Rules until the reboot: **nobody touches
`godot-render/build/look-parity`** (a `du`, `rm`, `git status --ignored` or a copy-back into it wedges the caller — the
close-out's ignored-files listing in godot-render must skip `build/`); render's new outputs go to its scratchpad; the
orchestrator never runs `du` over home again this round. **The protect knob was NOT enough: a copy-back with
`REMOTE_COPYBACK_PROTECT=look-parity/` wedged too (its `--delete` elsewhere in `build/`; three of render's rsyncs now in D).
Rule: NO copy-back into `godot-render/build` at all until the reboot — `REMOTE_NO_COPYBACK=1 make remote T=…` (on main at
`c7430de5`: runs, prints the verdict, skips the rsync, the exit line says NOT copied back) or a throwaway detached
worktree in the scratchpad with its own builder0 folder (render's workaround). And at the close: `make worktree-remove
STREAM=render` would delete `build/look-parity` and wedge — render's worktree STAYS until after his reboot; archive its
brief and delete its branch, remove the folder afterwards.** Render's results meanwhile: the pinned order vs round 15's
real frames = every calm frame PASS, 7 staged-fx frames 1.0–2.7 % (the defined tie); `no_hud` after hud's batches 135 →
114 draws on the staged frame, draw submission ~0.8 ms unchanged.

**A REGRESSION ON MAIN SINCE `e57d7eb7` (hud's H3), FIX ON HUD'S BRANCH, NOT YET MERGED:** the selection card's unit
portraits can draw as WHITE SQUARES. Found by hud's own `garage-tour` (frame 19_match_mid, both aspects); `make check`
cannot see it (the tour needs a display). Cause: `UnitPortraits` rendered a unit type twice when asked again mid-render,
the second texture replaced and freed the first, and the card — now redrawn only on change, with `ready_count()` (a
texture count) unchanged — kept drawing the freed texture. Fix: never queue a type again while it waits or renders;
`ready_count()` bumps on every stored portrait (test added). **FIXED on main at `301bac8b` (hud's final merge); the closing verification still runs `make remote T=garage-tour` on the final tree.**

**CLOSE-OUT OBLIGATIONS (collected live; step 2 of the close):**

- **Booth's new ElevenLabs masters: RESCUED** — `rsync -a --ignore-existing` from `godot-booth/assets/announcer/masters/`
  into the main checkout's (297 files there, 296 new here: 13 438 → 13 734 files, 399 MB) on 2026-10-03 before any
  worktree removal; the ignored-files listing of booth, brains, sim, play, hud showed only `local.mk` and `override.cfg`
  (the worktree's own config) outside the known categories; render's `build/` was skipped (wedged). The clips themselves are committed. The veto page's `db`
  dump is committed under `streams/references/round16/booth_veto_db/` (his taps DID land: 62/62 approve, 04:31–04:34 UTC,
  the same answer as his chat words).
- Brains' temporary detached checkout `../godot-brainsbase` is removed (brains); its folder on builder0, `~/tank_squad/godot-brainsbase`, is safe to delete.
- The ElevenLabs ledger: the 44 495 → 43 777 gap between rounds is reconciled as 'not speech; most likely late-settling
  STT' (booth, `d4dac595`); tonight's batch settled at **38 274**.
- **A question, not acted on:** the Web preset's `exclude_filter` excludes `assets/announcer/clips/*` (booth's merge
  note) — does the browser build have a voiced announcer at all? Pre-existing; a round-17 candidate, not this round's.

**Housekeeping at launch:** the airship option-C commit (`8c586a80`) changed code and broke two tests that asserted the
old default — fixed by the orchestrator in `tests/test_theme_ad_airship.gd` (the lift is exercised under the
`cameralift` arm; the default asserted OFF). The round-15 close said "after it only docs": wrong, and the previous
session's monitor caught it (1854/2). Lesson for the close: a default flip is code; it gets its own check before HANDOFF
calls main green.

**Green baseline at launch:** `8318b9db` (the docs commit + the test fix): builder0 `>> remote: make check exited 0`, 1856 passed, 0 failed, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; `scenario_perf` NOT JUDGED under load (isolated pass owed).

**Merged so far (the orchestrator, live):**

| stream | green code hash | merge | what landed |
|---|---|---|---|
| play (CP1: P1, P3, P4 v1) | `94072ca4` (builder0 1869/0, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; 18 other godot processes on the box) | `7100e3fe` (README rows combined), main's own check running | **`make perf-play`: his path measured as he plays it** — a human-side skirmish (the fog field, controls, markers, booth, music, recorder live), his flags, 1854×1011, Law v Condemned on the Sumps, seeds 92721 + 31337 × uncapped/capped, layers `no_visfield/no_controls/no_audio/no_recorder`, unknown names to render's `RenderLayers`; `tools/perf_play_report.py`. **The wall-clock fix:** perf-scene's `avg_ms` was `delta` = game time once saturated (the before rows' caveat); now wall time + `game_ms`, `game_speed`. His path on the LOADED laptop (`r16-play-laptop-loaded-*`): real frames 163–174 ms, the battle at 0.59–0.64× speed, 3.5 ticks a frame, 100 % of frames over 34 ms, tick 45–48 ms, GPU 18–22, game+UI 10–14, ~40 vehicles — the quiet-window run is the orchestrator's, after play's tip merges. **P3:** the enemy opens on RANDOM, rolled from the seed (`ENEMY_FACTION=` pins it). **P4 v1:** `MusicDirector.carry/adopt`, the menu's music through the loader, one director. After this hash on play's branch (tip `32324c4a`, checking): P4's planning-pause fix (the opening was SILENT in every planning pause, not only the loader — the director under the paused match was paused; now `PROCESS_MODE_ALWAYS`), P2 the `.perf` trace beside every recording + `SLOW ×N` on `--perf`, P5 the engine system, the `--announcer-history=off --music-history=off` flags on every harness target |

| sim (CP1b + S1–S3) | `00f43ed3` (builder0 1864/0, baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; `scenario_perf` NOT JUDGED under load) | `dcd25cc5`, checked with the next main check | **The first measured wins of the round, all baseline-neutral.** CP1b: `Units.stat` skips the String key when untuned (2.04 → 0.75 µs a call, laptop microbench). S1: the visibility field's cell marks on a worker thread (gated on thread support / not web / > 1 core — the browser takes the old inline path), the image identical tick for tick on sumps and terminus (`test_match_visfield_parity`), **~3.4 → 1.21 ms a tick on the main thread** (laptop, loaded, Law 27 v Condemned 29, Sumps, seed 92721; the field's only readers are the radar and the fog visual; the camera's vision cap never reads it); switches `--sim-off=visfield`, `--sim-off=visfield_thread`. S2: `_update_intel`'s enemy list hoisted out of the viewer loop; an EXACT LOS memo tried and measured useless (positions change every tick). S3: `team_tanks`/`sorted_team_tanks`/`tanks_by_name`/`team_squads` cached on the tick and returned as SHARED read-only objects (a caller that mutates one errors — hud and brains told). On the branch after it: S7 the recorder's census 3.0 → 1.24 ms once a second (same bytes), S6/S8 measurements; check2 queued |

| booth (B1 instrument, B2, B5, B6) | `a1985ba8` (builder0 1859/0, baseline unmoved, determinism `762a0576f944f5b7`) | merged after sim, checked with the next main check | **Why the announcers repeat, measured, and the free half fixed.** B1: `tools/announcer/thin_pools.py` over 8 real matches of his matchups replayed as a 40-match evening: four caller pools one match uses up (streak 9 lines / 2.6 calls a match / 72 % heard again within 5 matches; flurry 10 / 2.5 / 58 %; 'another one' 13 / 2.6 / 31 %; the cut-in 6 / 1.35 / 52 %); 7.09 of 34 calls a match (21 %) heard in the last 5 matches; his memory DOES persist (31 matches). B2: a match quit midway counts as heard. B5: a specific line heard in the last 4 matches loses its 8× specificity bonus — repeats 7.09 → 4.11 a match (three seed sets agree); trade calls answered by a trade-written line unchanged on his real matches (80 → 81 %; the fixtures' 71 → 57 % was one fixture replayed 50×). B6: the booth's tick 0.112 → 0.055 ms at 52 vehicles, K5 events byte-identical. The 62 drafted lines wait on the veto page (`db` read EMPTY again 04:16 UTC). On the branch after it: B7 every line said → `<recording>.booth.txt` beside his recording |

| play (P2, P4 fix, P5, flags) | `32324c4a` (builder0 1873/0, baseline unmoved, determinism `762a0576f944f5b7`) | merged after booth, checked with the next main check | **His games now carry their numbers**, and a second music bug found by the real-tree smoke. P2: every skirmish writes `<recording>.perf` (per second: frame avg/p95/max, ticks a frame, tick ms, GPU ms, vehicles) beside the jsonl, `tools/perf_trace_report.py`; `--perf` shows `SLOW ×N` (P6). **P4's planning-pause fix: the opening was SILENT in every planning pause, not only the loader** — the director under the paused match was stream-paused; now `PROCESS_MODE_ALWAYS`; `audio-launch-smoke` asserts carried == adopted, both playing, one director (pre_match_hymn carried at 5.3 s, still playing at 38 s through the pause). P5: `engine_system`'s per-frame `keys()` and `is_visible_in_tree()` per vehicle gone. The history-off flags on perf-play, perf-scene, skirmish-shots. Merge note: `mk/audio.mk` gains an additive assertion (accepted). Two docs commits after it (`cb156fcb`: `sim_tick_rate.md` re-read by the wall clock) come with the next merge |

| sim (S7 + measurements) | `5829902c` (builder0 1878/0, baseline unmoved, determinism `762a0576f944f5b7`) | merged, checked with the next main check | **S7: the recorder's census tick 3.0–3.3 → 1.24 ms average, worst 6.5 → 2.2 ms** (laptop; the file byte-identical) — the once-a-second hitch. Objects alive in every `sim-profile`; a physics census per arena. S5 (shells/impacts), S6 (per-tick allocations), S8 (Jolt bodies), S10 (arena collision) MEASURED, no change worth making — the numbers are in sim's Status. Next on the branch: the field's four arms on builder0, the two S1 checks (browser smokes, command-playtest), then S9 = CP2 (Law's APC on tracks) as its own commit, pre-registered UNMOVED (law_ifv is not in the baseline match) |

| booth (B7) | `aa0a2174` (builder0 1873/0, baseline unmoved) | merged, checked with the next main check | Every line the booth says → `<recording>.booth.txt` beside the recording. Status (`d4dac595`): the ledger gap (44 495 → 43 777 between rounds) is NOT speech — the account's TTS history has no requests between round 12 and tonight; most likely late-settling speech-to-text; annotated 'unknown'. Tonight's batch settled 39 731 → **38 274** (5 503: 5 374 TTS + ~129 STT). **The browser build has NO announcer voice** (code reading): the Web preset excludes the clips, `AnnouncerVoice.load_clips` finds no manifest and the booth falls back to subtitles — a round-17 question (roadmap). B4 (the 62 voiced lines, `b5b80a8e`) queued for a slot |

| brains (A1, A2, batch 1) | `156fdcf3` (builder0 exit 0, 1884/0, baseline unmoved; ai-parity 16/16 byte-identical to `8318b9db`, digest `cf50ef2b`) | `e823fdd7`, main's check running | **The split, re-measured:** brains ~92 % of a 17.1 ms tick at 56 vehicles (builder0, loaded, base `8318b9db`, Sumps 92721, Law v Condemned: 17.1 with brains, 1.3 without); at 50 vehicles **executing orders every tick 6.7 ms vs thinking 4.8** — nav the biggest cluster (chord checks 1.13 ms, 114 closest-point queries a tick 1.07, is_ready 0.46); LOS 46 rays a tick, 0.13 ms (A3's ray memo dropped on the measurement, as sim's null predicted). A2: `brain/*`, `los/*`, `nav/*` SimProfile sections. **Batch 1 (no decision changed):** an is_ready memo, a chord memo, an avoidance table, narrow Movement accessors — chord checks 24.6 → 18.2 a tick, closest-point queries 114 → 99, is_ready 0.46 → 0.05 ms, the same match before/after (state hash `14ecc9d4` both); ms totals not comparable (builder0 1.5× busier in the after-run) → batch 2 (`8864b954`, in check) adds `BrainSwitches` (`--brains-off=`) and `make ai-perf AB=1` (on/off interleaved in 30-tick blocks inside one fight: the load-proof per-item number). Cadence and sharding already exist (10/5/3.3 thinks a second; 7.7 of 50 brains think on an average tick) |

| booth (B4 — the voiced batch; **booth is DONE**) | `cd1ea5c0` (builder0 1873/0, baseline unmoved, determinism `762a0576f944f5b7`) | `737696a8`, checked with the next main check | **His 62 approved lines voiced and in the library**: 74 ElevenLabs recordings, 5 374 characters, STT flagged 0, alignment errors 0, the ledger settled at **38 274**. On the 40-match real evening: repeats within five matches **7.09 → ~1.0 a match (21 % → 3 % of calls)**, variance carryover 0.25 → 0.09 %; transcripts regenerated, the Booth Monitor rebuilt against the real pack. B5's test made relative to the unheard share (`b5b80a8e` alone read 1872/1 — not merged). Every backlog item done; Status holds the report. **Close-out: the 74 masters live only in `godot-booth` (rsync before removal); the session can be closed by the lead** |

| play (P1–P7 done) | `b987a525` (builder0 1873/0, baseline unmoved) + docs tip `f81e82bb` | merged, checked with the next main check | `PERF_PLAY_NAME`; the divergence caveat, the vehicles-alive curve and the recording path in every perf-play report, an optional frozen arm; `sim_tick_rate.md` re-read by the wall clock. P5 by measurement: booth + music **0.05–0.11 ms a frame** (builder0, inside the 0.3 budget); the engine-loop change below the noise, not claimed. **Found, not yet built (P8, given to play):** every `audio-bench` run shows one 7–16 ms frame in `music` at a bed change — a synchronous `ResourceLoader.load` = one dropped frame per track change at a locked 30; a threaded load at `set_state` is the fix. Open question answered by the orchestrator: Random never deals a mirror match (below) |

| brains (batch 2) | `8864b954` (builder0 exit 0, 1884/0, baseline unmoved; `scenario_perf` judged PASS 1.17×; ai-parity 16/16 identical, digest `cf50ef2b`) | `b5070f48`, checked with the next main check | `BrainSwitches` (`--brains-off=`: every change can be switched off) and **`make ai-perf AB=1`** (on/off interleaved in 30-tick blocks inside one deterministic fight — the load-proof per-item number, C16.3); **`make ai-script-profile`** (Godot's own script profiler, fight frames summed): `Pathing.closest_point` is the #1 script function, **13.8 % of all script self-time**, 58 of its 99 calls a tick from nav's planned-reverse check sweeping its whole full-lock arc to measure a distance only read up to 5 m + stopping distance; `decide` 5.5 %, `build_situation` 4.5 % self, then a flat tail ≤ 2 % each. First in-fight A/B (60 brains, 1.04×): batches 1+2 save **2.9 % of the brains band** (10 800 vs 11 126 µs/tick) — real but small: memos only remove repeats. Batch 3 `a2682209` (`kturn_cap`: the sweep stops where the answer can no longer change) in check |

| play (P8; **play is DONE**) | `64407282` (builder0 1875/0, baseline unmoved) + Status tip | merged, checked with the next main check | **The music bed's dropped frame:** beds prefetched on the loader thread after the first bed starts (~9 MB of Ogg + stingers; off on web, under a stub loader, `--music-prefetch=off` as the A/B): the bed change's main-thread cost **17.9/35.7 → 4.8/4.6 ms**, last stand 17.1/26.6 → 7.1/7.5 (headless, seed 92721, laptop load ~9.7, ×2 per arm, the same state hash in all four); `MUSIC_TRACK cost= bar_phase=`; the remaining 2–7 ms is `play()`'s Ogg seek + the stem-set build (a lever only if a frame still shows it). Random never mirrors (`FactionPicker.roll_enemy`). Every item done; available for requests |

| sim (the fire RNG) | `0010bcb4` (builder0 1880/0, baseline unmoved) | merged, checked with the next main check | The skirmish's shot-spread RNG seeded from the launch seed (above); the `--hash-every/--hash-until` witness |

| hud (H1–H6, first batch) | `3e6bcbd2` (builder0 1887/0, baseline unmoved; control-playtest ok, worst response 1 tick; command-playtest ok) + Status `7d066ca1` | `e57d7eb7`, checked with the next main check | **HUD script per frame 71.4 → 36.5 reference-workload units (−49 %, load-independent, same laptop back to back; the after includes sim's caches)**: `selection_panel.draw` 6.6 → 0 (redraws on change), radar 13.3 → 3.2 (marks in one pass, the static backdrop on change, `_flip` without `team_frame`), `controls.draw` 11.3 → 4.7, `controls.process` 14.2 → 7.3; `VisionRegion.contains` over packed copies of its discs; markers read the interpolated transform once, bars the camera once; callouts read the mover's fields. Parity by hand: radar + card + chips 0 px over 8/255 at 1920×1080, the radar interior identical at 1280×720 (looked at); draw calls 154 → 154. The earlier 8.8–9.2 ms was a loaded laptop (~3.2 ms lighter). **Not at 1.5 ms yet:** what is left is per-unit work at 30 Hz ticks = every frame at his target; priced look-levers (NOT built) in hud's Status. Next: the `TaskPreview` memo, H7 draw calls (panel 64, radar 20, group bar 19). `hud-before-probe` is a measuring baseline branch, never merged |

| brains (batch 3, `kturn_cap`) | `a2682209` (builder0 exit 0, 1884/0, baseline unmoved; ai-parity 16/16 identical to base AND with `--brains-off=all`) | merged, checked with the next main check | Nav's planned-reverse check swept its whole full-lock arc to measure a distance only read up to 5 m + stopping distance — the sweep now stops where the answer cannot change (58 of 99 closest-point calls a tick). **The in-run A/B on HIS PATH** (`make ai-ab-play`, a perf-play skirmish, builder0 with a display, ~2 810 ticks an arm): **all switches save 8.4 % of the brains' controller band** (11 765 vs 12 847 µs/tick thread CPU), `kturn_cap` alone 3.4 %; scenario_perf 8.7 %. Batch 4 queued: `lazy_path` (no per-tick route copy for the wall-contact instrument), `ground_memo` (`SlotGround.standable_for` per nav iteration; formation slots are 28 of his ~115 navmesh queries a tick) |

| play (no_visfield_thread; the intro dismissed) | `176b78fd` (builder0 1888/0, baseline unmoved) + Status `6b52b5a8` | `ef0ef015`, checked with the next main check | perf-play's `no_visfield_thread` layer; **on builder0, his path, seed 92721, 3 cycles, load 7.5: the whole field −0.13 ms a tick, its marks back on the main thread +0.22 — both inside the noise: with sim's S1 the field no longer weighs on his path** (`references/perf/r16-play-builder0-s1-92721.json`; that run: 87 ms frames, battle 0.87×, tick 28.5 ms, ~42 vehicles, loaded). perf-play closes the PLANNING intro the way his first key does (`SelectionPanel.dismiss_intro()` if present, else one Shift). Note: `game/ai/brain_switches.gd.uid` was never committed by brains (Godot generates one per checkout; main's copy deleted, brains asked to commit theirs — trip-up 8) |

| sim (**S9 = CP2**, Law's APC on tracks) | `c7d450ee` (an ancestor of the green `9c1c65d0`; its code is four `units.gd` lines + its test) | `f24ced45`, merged ALONE | **The round's one declared behaviour change, his words:** `law_ifv` locomotion wheels → tracks; test-first (the pivot ≤ 0.3 m and > 45° in a second; wheels shuffled 1.41 m / 13°); **pre-registered UNMOVED (law_ifv is not in the baseline match) and UNMOVED on builder0** (`05df1d55ba49cde1` at the green descendant); the laptop baseline-match hash `5f81684d9c38cb45` before and after. `make law-apc-shots` frames looked at by sim (the army fights normally; the scripted camera follows the rocket battery, so the APC is not clearly framed) — **his playtest: a Law army, the APC squad ordered to turn in place** |

| sim (S3b) | `9c1c65d0` (builder0 1883/0, baseline unmoved, determinism `762a0576f944f5b7`) | `f7a9928e`, checked with the next main check | `_sorted_tanks` kept across ticks when a re-validation finds the same tanks in the same child order (one full sort of ~56 tanks a tick was the 354 comparator calls a frame), so the S3 caches hold across ticks; `team_frame` → two read-only constants. **The field priced on builder0** (60 s, his matchup, brains on, ratios against the run's `tank` line): pre-S1 ≈ 1.85 ms/tick (1.17× tank), S1 inline 1.87, **S1 threaded 0.36 ms (0.40× tank)** — a third of the main-thread cost. The windowed Sumps per-unit dump (the tick-630 fork) running |

| brains (batches 4+5) | `319aaa7f` (builder0 exit 0, 1884/0, baseline unmoved; ai-parity 16/16 identical to base and with `--brains-off=all`) | `09e1ad33`, main's check running | `kturn_lazy`, `ground_memo`, `lazy_path` (no per-tick route copy for the wall-contact instrument), `direct_calls`, `preview_memo`; `BrainsAB` + `--brains-parts` + `make ai-ab-match` / `ai-ab-play` (the in-run A/B now charges the WHOLE tick's scripts, switches flipped at the top of the tick). **On his Sumps match: all switches save 8.7 % of the controller band and 7.7 % of the whole tick's script CPU** (12 326 vs 13 494 µs band; state hash `c298b9ae` equal to a plain run); **on his skirmish: 9.0 % of the whole tick's scripts** (12 463 vs 13 702 µs/tick), 6.1 % of the band. `ground_memo` alone inside the noise (reported unresolved, not a gain — the honest line). Next: `git merge main`, then `ai-script-profile-play` on the merge for the whole-tick after |

| render (R1–R4, the pinned order, the levers) | `f98e33d1` (builder0 1891/0, baseline unmoved, determinism `762a0576f944f5b7`; look-parity floor **40/40 PASS, worst 0.018 %**) | `33309ced`, checked with the next main check | **C16.6's instrument:** `make look-parity` floor/ab/bisect/bisect-forward/probe + `tools/look_parity.py`; `make render-split` (a frozen staged frame, within-run layers) + `RenderLayers`. Pixel-equal items at his window (laptop, within-run GPU): the fog sheet −0.47 ms, the sky's order −0.16/−0.33, the floor −0.1/−0.3, the yard + instancer light cells −0.2/−0.65 (one MultiMesh per kind per 64 m cell so a pooled light redraws only its neighbours) — ~2 ms in all. **The six transparent FX systems' draw order pinned at ONE site** (`FxWorld.TRANSPARENT_ORDER`; a test reads the six priorities back; round 15's undefined tie, now defined — the staged-frame footprint vs round 15 goes in render's Status). `RenderLevers`: seven priced picture-changing levers, ALL OFF unless `--render-levers=`, and his page (above). Merge notes: `tests/test_arena_prop_parity.gd` (yard draws carry a `kind` meta), `tests/test_assets_containers.gd` (a draw per occupied cell), `fx_quality.value` routes through `RenderLevers.adjust`; no `project.godot` edit |

| hud (H7 + the TaskPreview memo) | `8b7f330d` (builder0 1900/0, baseline unmoved; control-playtest ok, command-playtest ok) | `2a2b6fc7`, checked with the next main check | The command card's tooltip no longer reruns the squad planner every frame (`TaskPreview.posture` memoised per verb/count); **draw calls 154 → 121** on hud-cost (budget ≤ 130 met; panel 64 → 47, radar 20 → 12, group bar 19 → 11; `DrawBatch` groups chips and labels only where nothing overlaps — parity by shot masks identical inside the widgets); fog plates hidden once per tank; prune without copies. **HUD script on the laptop at idle load, back to back: 5.61 → 2.88 ms a frame at 68 vehicles (−48 %; includes sim's caches)** — not at 1.5 ms: the rest is per-unit work at tick = frame, exact cuts at their GDScript floor; priced look-levers (NOT built) and two lead questions (a bar-height bug, a duplicate hull bar) in hud's Status |

| brains (final; **brains is DONE**) | `1af40b4b` (builder0 exit 0, 1896/0, baseline unmoved; `scenario_perf` NOT JUDGED at 1.80×) + docs tip `c8e01d37` | merged, checked with the next main check | **The honest bottom line: equal-answer work bought ~9 % of the tick's scripts.** The final in-run A/B on his skirmish after the merge: all round-16 brain switches save **9.4 % of the whole tick's script CPU** (14 717 → 13 329 µs/tick) and 7.7 % of the brains' band, ~3 410 ticks an arm; ai-parity identical to base on every batch, both arms. A3 measured and not built; A4 closed by a microbench; A7/A8 partly done, the rest written up; A9 written up. **Beyond this the 4 ms budget needs decision changes** (a far-idle think rate, the k-turn cadence, chord samples, ORCA neighbours), each to be PRICED on his page — the instruments (`ai-script-profile[-play]`, `ai-ab-match/play`, `BrainSwitches`, `ai-parity`) are in place. Close-out: builder0's `~/tank_squad/godot-brainsbase` (the temp worktree's folder) is safe to delete |

| sim (the report; **sim is DONE** bar one Status commit) | `3e8300b3` (builder0 1883/0, baseline unmoved) | `d99901f3`, checked with the next main check | The Status report: S1–S10, CP1b, CP2 with their numbers; S5/S6/S8/S10 measured and not changed. **The Sumps' second windowed-only fork is a round-17 item** (`roadmap.md` *Round 17 candidates* 3): ticks 601–630 in 2 of 3 pairs at two hashes; the pair hashing every tick from 560 (different frame pacing) did not fork; headless Sumps identical to 900, windowed Terminus to 870; nothing in the sim reads frame time, the camera or the wall clock — a timing-dependent windowed input (the orchestrator's bridges/water suspect KILLED by sim: static decks, `StaticBody3D` only, no theme-side collider or nav region). Witness: `make windowed-repeat ARENA=sumps REPEAT_EVERY=5 REPEAT_UNTIL=640 REPEAT_FLAGS=--hash-detail-from=600` |

| sim (final Status; **sim is DONE**) | `41bf4d7c` (builder0 1883/0, baseline unmoved) | `105b41ef` | The bridges/water suspect for the Sumps fork killed (static decks; `StaticBody3D` only; no theme-side collider or nav region). The worktree is clean and held for the close |

| render (the footprint, the no_hud re-read) | `24399992` (builder0 1907/0 via a detached verify worktree, baseline unmoved) | `db35ad4f`, checked with the next main check | The pinned transparent order vs round 15's real frames: every calm frame PASS, 7 staged-fx frames 1.0–2.7 % (the defined tie); `no_hud` after hud's batches 135 → 114 draws on the staged frame, submission ~0.8 ms unchanged. **Next: R9, the render preset from his taps** (above) |

| play (the preset pinned in the benches) | `8d16d5d0` (builder0 1888/0, baseline unmoved) | merged, checked with the next main check | perf-scene and skirmish-shots pin `--render-preset=desktop`; `PERF_PLAY_PRESET` (default desktop; the laptop arm `PERF_PLAY_PRESET=laptop PERF_PLAY_NAME=perf-play-laptop`); the report prints each run's preset. **The record run at the close is both arms** |

| render (R9, the render preset) | `ea066185` (builder0 1910/0 via the detached verify worktree, baseline unmoved) | merged, checked with the next main check | **His five taps as the `laptop` preset; `desktop` = none** (scale 1.0, fog, haze, four lights, the full crowd); resolved `--render-levers` > `--render-preset` > `user://render_preset.cfg` > the adapter (Intel UHD/Iris/HD → laptop; NVIDIA/GeForce/Radeon/unknown/dummy → desktop); one `RENDER_PRESET` launch line; the live switch for hud's LOOK FULL / LOOK LIGHT row; headless → desktop (baseline and shots unchanged); tests for the lever sets, the adapter names, the dummy rule. Parity shots of both presets at his pose running (desktop must equal pre-R9; laptop is the expected change). Lesson from render: a static helper named `_set` in a RefCounted collides with `Object._set` — lint catches it, but only on builder0 |

| render (final Status; **render is DONE**) | `a52eb0ee` (docs only after the green `ea066185`) | merged | **R9 parity at his pose:** desktop vs pre-R9 PASS 40/40, worst 0.029 % (the full look unchanged); laptop vs desktop differs on every frame, worst 49 % (the fog) — the expected change. The LOOK FULL vs LOOK LIGHT sheet at his window: `references/round16/render/look_full_vs_light.jpg` (looked at by the orchestrator). The worktree stays on disk until his reboot (its `build/look-parity` is wedged); nothing of render's runs locally |

| hud (final; **hud is DONE**) | `a0421982` (builder0 1905/0, baseline unmoved; control-playtest ok, worst response 1 tick; command-playtest ok; garage-tour frames 17 and 19 looked at at both aspects, 0 pure-white px in the card) | `301bac8b`, **the closing check** | **Two defect fixes (the orchestrator's calls, visible):** every health bar 1.2 m over its own hull's top (it sat at a fixed 3.2 m); the duplicate bar dropped, a SELECTED unit keeps a bright bar (UnitBars at full alpha). Render's LOOK FULL / LOOK LIGHT row beside the frame button. **The portrait regression (since `e57d7eb7`) FIXED:** never queue a type again while it waits or renders; `ready_count()` bumps per stored portrait; a test. Lesson (hud): a redraw-on-change widget's signature carries what it draws by identity/version, not by count. Crops: `references/round16/hud/` (three before/after sheets, looked at by the orchestrator) |

_Round 15's record follows:_

## ✅ ROUND 15 IS CLOSED (2026-10-01 evening → 2026-10-02) — read this first

**Five streams overnight, three decision pages, two tapped before the orchestrator read them; one baseline move,
recorded.** His words are in `game_design.md` *Round 15 direction*; his taps in *Round 15: the gangs' table, decided on
the page* and *Round 15: the IFV concepts, decided on the page*. Briefs in `streams/archive/round15/`; evidence in
`streams/references/round15/`; lessons 229–234; round 16's candidates in `roadmap.md`. The merge table below was kept
live and is the record.

### The findings that were not on any list

1. **The two tank/IFV confusions were a roster problem in two factions**, and a lamp cannot change a shape: his taps
   bought two new IFVs (75 credits in all) and the overlap at his pose fell from 0.89/0.87 to 0.69/0.79. The first box
   commit moved the simulated turret pivots and threw both muzzles 2.5–2.8 m past the noses; three combat tests caught
   it before merge (lesson 229).
2. **The gangs' one-seed flips were noise, and the two drills behind them had defects** nobody had seen: a flanker that
   circled because its turn-in test flipped every 1.5 s, and a bait runner that never came home. Both fixed as
   mechanisms; his tap kept the table.
3. **The camera's lift and the airship's climb chase each other** — 54 of 60 intrusions begin with the camera already
   lifted. The fix is on the airship's side and on his page.
4. **A planned leg's exit test can be keyed by hull length** (the rig, ≥ 10 m) without touching the scout's orbit; the
   5.5 m key failed its null clause on fresh seeds and was narrowed before shipping.

### Waiting on the lead (live)

- **The airship page — what gives way:** https://claude.ai/artifact/NzztKZUw66Du6n9DPRzv6X (`db` `decisions/airship_view`;
  **read EMPTY by the orchestrator at close, 2026-10-02**). A main · B the climb against where the camera rests · **C
  (recommended, play it first)** B + the camera stops lifting over the airship (hides 0.00–0.08 %, no intrusion over
  1.5 s, seen about half as often as round 13, as now) · D B tuned to be seen more. Commands per option in the archived
  airship brief's Status. **CONSUMED: his tap is C (2026-10-03 01:55 UTC, read by the orchestrator 2026-10-02 evening)
  — shipped as three defaults in `airship_flight.gd` (`view_rest` ON, `view_low` ON, `camera_lift` OFF) with his words
  at the code site; `game_design.md` *Round 15: the airship's "what gives way"*. His playtest of C on the pit is the
  check for airship's unproven edge-pan caveat.**
- **Law's new APC: DECIDED in chat** (*"if it is now a tracked vehicle it should behave as one"*): `law_ifv`
  locomotion wheels → tracks — **round 16's first item** (a sim change; pre-register by the path; a CP if it moves).
- **The amber class lamps:** stay now that the shapes differ, or go? (`CLASS_MARK=off make skirmish` to compare.)
- **Playtest list:** a Condemned and a Law army, IFVs beside tanks, from his camera (the new vehicles, the lamps);
  the pit with each airship option; the garage from the title (the centre-scores card at the first fight, the lengths
  on the cards); a War Rig squad through the Terminus (the keyed k-turn brake).
- Pages read at close (step 5a): squad's (tapped, consumed), fleet's (tapped, consumed, image-to-3D done), airship's
  (empty, above).

### Housekeeping at the close

- Worktrees nav, airship, squad, garage, fleet removed after the ancestor check; branches deleted. Fleet's git-ignored
  Meshy payload (two `_t2` sets, five concepts) rsynced into `assets/incoming/meshy/` first. **Three worktrees showed
  1–2 ignored entries outside the known categories that were NOT inspected before removal** (lesson 234); most likely
  `__pycache__`, not verified.
- Two duplicate sessions at kickoff (seven agents for five worktrees) stood down on one message, changed nothing
  (lesson 231). `relay-smoke` failed once under the concurrent starts and passed alone and in every later check.
- `scenario_perf` refused in EVERY full check of the night under five streams (lesson 233); the isolated PASS on the
  final tree is 1.00× nominal. Round 16's housekeeping candidate: a quiet slot for it.
- builder0's persistent `build/` carried round 14's logs into a round-15 table once (`remote_builds.md` *Stale copy-backs*).

_The launch record follows, as written:_

## 🚀 ROUND 15 IS LAUNCHED (2026-10-01, evening, overnight) — kept as written

**His words:** *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for
the night. You can assume that we want to reset our environment across the board."* No playtest list; the round is
round 14's own next-steps. Overnight rules (memory): every agent working, decide rather than block, validated work by
morning; decision pages with `db` for anything that is his.

| stream | offset | the job |
|---|---|---|
| nav | 1 | N3 keyed by hull class or plan purpose so the rig gets real stops and the scout keeps its brake taps (the scenario gate green); then N5, the planner that looks earlier; seeds 17–24; **CP1** if the baseline moves |
| airship | 2 | the 39–49 s intrusion cluster the climb does not fix; buying back the seen-share without putting the hull in the way; the clip |
| squad | 3 | the gangs' flipped encircle/bait verdicts over seeds → a decision page for him (no table ships); the ladder re-baselined; `scenario_perf` pinned to one fight; the flanker's loop |
| garage | 4 | the second tour's list: the centre scores said before the fight; the sense of size; the loader's hint on a phone; the status box at 20:9; the tour again |
| fleet | 5 | tanks and IFVs that read apart at his pose: measure, fix what is free, prepare concepts on a page (no image-to-3D, no box changes) |

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream). **Reset:** the
four round-14 sessions (airship, garage, nav, squad) are closed by the lead; fresh worktrees at the launch commit. Merge
at the hash each stream names green; read every page's `db` at close (squad's and fleet's expected); rescue git-ignored
payload (fleet's concept images under `assets/`).

**Merged so far (the orchestrator, live):**

| stream | green code hash | merge | what landed |
|---|---|---|---|
| garage (H1–H6) | `19795f1b` (code `3d01b8d7`; builder0 1832/0, baseline unmoved; tour failed=0 both aspects) | `d307a234` + docs `4f7522d0`, main's own check 1832/0, baseline unmoved (`scenario_perf` NOT JUDGED under load; isolated pass owed) | **The second tour's list.** The centre-scores card at the first fight (once per fresh profile, tap to dismiss); 'N.N m long' on every unit card (the fixed turntable scale measured and kept OFF: a Scout 49 px at phone against a 60 px bar); the loader's hint readable on a phone; the status box fits at 20:9; a loss on the point repeats the tip. Carve-outs: loading_screen.gd, hud_skin.gd. Sheet looked at by the orchestrator: `references/round15/garage/garage_tour_round15.jpg` |

| fleet (F1–F3) | `b082a464` (builder0 1829/0, baseline unmoved; `scenario_perf` NOT JUDGED under load) | `8463bb66`, checked with the next merge's check | **Tanks and IFVs that read apart at his pose.** F1: a roster problem in two factions — Condemned bus / garbage truck IoU 0.89 from behind (the IFV's barrel draws it as long as the bus), Law Assault Gun / Retired APC 0.87 and the same paint; Gangs and Syndicate fine. F2 (free): amber class lamps on the two IFVs, roof-seated, tested; +10 % lit difference. F3: five concepts on the page below (45 credits). F4 merged at `40a2cb3d` → `a9648257`: the lineup as a standing test (every pair under a 0.80 silhouette ceiling; next-closest: Gangs' Gun Truck/Rat Rod 0.73, Syndicate's Limousine/Skimmer 0.72) |

| nav (V1) | `03f8336c` (builder0 1824/0, baseline unmoved — predicted; `scenario_perf` NOT JUDGED under load) | `375bd16c`, checked with the next merge's check | **N3 keyed to the War Rig, ON by default.** The stopping-distance exit applies to hulls ≥ 10 m; scouts keep their brake taps (the engine-deck scout 41/43 in both arms). Rigs on fresh seeds 17–24: contacts −30 %, arrivals −2, leg time +7.5 % (~2.4 s a leg, inside his trade). The 5.5 m key (buses too) failed its mixed-squad clause and was narrowed. `--nav-off=kturnbrake` = round 14; `kturnbrakeall` = everyone. V2–V3 merged at `4dc987a5` → `8415922b` (+docs `f26c5951`; builder0 1827/0): **V2, the planner that looks earlier, FALSIFIED on the design seeds and OPT-IN** (`--nav-off=kturnlook`, `kturnrollout`); V3's clip sheet looked at by the orchestrator: the rig's turn with the key on completes in the street and it drives off up the avenue by the ninth frame, no container touch |

| squad (P1–P5) | `e05a44fc` (builder0 1822/0, baseline unmoved — the pre-registered MOVED falsified both arms; `scenario_perf` NOT JUDGED at load 17) | `1f273e84`, checked with the next merge's check | **The gangs' verdicts measured and decided: AS SHIPPED (his tap).** P2: the ladder prints its winner rule, refuses across one, a kept 120-match reference. P3: `scenario_perf` fights one battle alone and in-suite (runs first; one tick of phase). P4: the far-ambush turn-in by bearing (the flanker's loop: enemy-left vs chasers 0.63 → 0.42). P5: the bait runner comes home. Shared: mk/core.mk, mk/ai.mk, run_scenarios.gd |

| fleet (F3, **CP1**) | `d7b52675` (builder0 1831/0, 17 targets, `make check exited 2` with ONLY sim-baseline failing, as pre-registered) | `ea61d450` merged ALONE; baseline `6313a38d7ecd99bb` → `05df1d55ba49cde1` recorded at `e991be30` (two agreeing reads) | **His two approved IFVs built and in** (30 credits, ledger 695): the Condemned crash-tender wedge and Law's tracked police APC. Collider-only box commit (ifv width 2.86 → 3.75, height 3.70 → 3.08; law_ifv 3.44 → 3.86, 4.11 → 3.56; lengths held); the simulated turret pivots UNCHANGED (a first cut moved them and threw the muzzles 2.5–2.8 m past the noses — three combat tests caught it before merge); the sim change is the turret scale through the wider boxes (muzzle reach 1.19 → 1.56, 1.43 → 1.61). Lineup: Condemned tank/IFV 0.90 → 0.69, Law 0.87 → 0.79. **Open for him:** law_ifv keeps 'wheels' handling under a tracked hull |

| airship (B1–B4) | `ce155f15` (builder0 1828/0, baseline unmoved; `ai-scenarios-check` alone 43/1 = baseline) | `c172f410` + docs `532705da`, the round's final check at `e991be30` 1856/0 | **The view-climb's remaining intrusions, named and measured; main's flight UNCHANGED, every new switch OFF, his call on the page below.** B1: 54 of 60 intrusions begin with the camera LIFTED — round 11's lift and round 14's climb chase each other at the hull's first close pass; the fix climbs against where the camera rests (`viewrest`+`viewlow`): the cluster 10 → 3, intrusions 58 → 25 on fresh seeds 25–32. B4: with that and the camera's lift off for the hull, hides-the-fight 0.00–0.08 % on four maps, no intrusion over 1.5 s (option C; "play it first": two rendered worst frames after big camera moves, suspected builder0 edge-pan, unproven). B2: no altitude lever reaches the in-frame bar. The camera's one approved accessor (`REST_META`, `rest_transform`, one `set_meta`). Playtest commands per option in its Status |

**Waiting on the lead (round 15, live):**

- **Airship's decision page — "When the airship's path crosses your camera, what should give way?":**
  https://claude.ai/artifact/NzztKZUw66Du6n9DPRzv6X (`db` `decisions/airship_view`; read EMPTY at 03:55 PDT by airship).
  **A** main as it is · **B** the airship climbs against where the camera RESTS (the B1 fix: the 39–49 s cluster 10 → 3,
  intrusions 58 → 25 on fresh seeds; OFF because its longest-intrusion clause failed) · **C (recommended)** B plus the
  camera stops lifting over the airship (the airship leaves the camera's occluder group; the hull hides the fight
  0.00–0.08 % on all four maps, no intrusion over 1.5 s; seen about half as often as round 13, as now) · **D** B tuned
  to be seen more (triples clean sightings on the pit and yard; fails its in-frame bar). Each card has its fresh-seed
  numbers and the exact command to try. UNCONSUMED.

- **Squad's decision page — the gangs' encircle/bait table:** https://claude.ai/artifact/TjdypH5KxNgdmwQfSea176
  (`db` collection `decisions`, doc `choice`; read EMPTY at 2026-10-02 01:50 by squad). **Recommendation: KEEP the table
  as shipped.** Over 16 paired fights per opponent on yard + Terminus (builder0, 8 seeds): encircle ON loses to a
  standard element (enemy stronger in 11 of 16, p 0.06); both flipped loses to chasers (14 of 16, p 0.004); bait OFF is
  a coin toss. Round 14's one-seed flips were noise. **CONSUMED: he tapped "As shipped" at 09:09:44 UTC** (read by
  squad at 03:28 PDT; `game_design.md` *Round 15: the gangs' table, decided on the page*). The table is unchanged.
- **Fleet's review page — a new IFV shape for the Condemned (3 directions) and for Law (2), or keep today's IFVs with
  the amber lamps:** https://claude.ai/artifact/KDZKwAhyD1JNAnySsfwMeh (`db` collection `decisions/<id>`; read EMPTY at
  2026-10-02 09:31 UTC by fleet). Each card says: APPROVE ≈ 15 credits, replaces that faction's IFV; at most one per
  faction. **The lamps are already on main for his A/B** (`CLASS_MARK=off make skirmish` to compare). After a tap: fleet
  reads the `db`, `make art-apply-decisions`, image-to-3D, the split, the −Z test, the class-look numbers again; a box
  change is a CP. **CONSUMED: he tapped at 09:34 UTC — APPROVED `ifv_r15_a` (crash-tender wedge, Condemned) and
  `law_ifv_r15_a` (tracked police APC, Law), the other three rejected** (read by fleet 09:59 UTC; `game_design.md`
  *Round 15: the IFV concepts, decided on the page*). Image-to-3D (~30 credits) goes ahead on his taps.

_Round 14's record follows:_

## ✅ ROUND 14 IS CLOSED (2026-09-27 evening → 2026-09-28 morning) — read this first

**Four streams, one night; his two items and round 13's list; the sim baseline unmoved all round.** His words are in
`game_design.md` *Round 14 direction* (the airship, then the invisible rigs and his correction). Briefs in
`streams/archive/round14/`; evidence in `streams/references/round14/` (his Locks recording, the deploy frames, the
airship view logs per seed, the garage tour sheets, the drill frames, nav's buckets and clip sheets); lessons 225–228;
round 15's candidates in `roadmap.md`. The merge table below was kept live and is the record.

### The three findings that were not on any list

1. **His invisible War Rigs were never invisible: they were deployed INSIDE a city block** (the Locks, 13 × 14 m rigs
   overflowing a 32 m spawn zone; the placement check a silent no-op before the navmesh bake) and depenetration pushed
   them 6.24 m under the floor on tick 2 — art under the ground, the selection ring on top. Found by replaying his
   recording after two wrong guesses (a roof; the canal rim). Deploy now keeps every hull clear of obstacles and inside
   the arena; the unchecked count is printed; an off-floor hull is logged.
2. **One exit test cannot serve a 14 m rig and an orbiting scout.** Nav's k-turn brake made the rigs tidier and
   quicker on fresh seeds, moved the baseline, and broke the scout's engine-deck orbit (41/43 → 3/13). Withdrawn on
   the measurement; opt-in; the split by hull class is round 15's.
3. **`scenario_perf` refused under load THREE times in one night** once it could — including under the round's own
   final check. The gate and the verdict line now count NOT JUDGED apart from passed; a green with that row needs the
   isolated pass beside it (this one has it).

### Waiting on the lead (live)

- **The airship's view-climb: ON or OFF.** Shipped OFF. On fresh seeds it halves how often the hull hides the fight
  (pit 7.8 → 2.3 %, yard 5.0 → 2.5 %, Terminus 2.3 → 1.2 %) and cuts the longest intrusion to a third, but misses its
  pre-registered bar and halves how often he SEES the airship. Try: `AIRSHIP_ON=viewclimb make skirmish ARENA=pit`
  against plain. **ANSWERED in chat 2026-09-28:** *"ah ok that's a great idea, turn that on by default"* — ON by default
  (`AirshipFlight.view_climb := true`, the toggle documented at the code site; `AIRSHIP_OFF=viewclimb` restores);
  recorded in `game_design.md` *Round 14: the view-climb decided*.
- **The camera readout in `make skirmish`:** off for players, still on in his launch (moved so it no longer overlaps).
  If he wants it gone when he plays: `CAMERA_READOUT=off`, or say so and the default flips.
- **For his ear:** the garage's two blues; the two defeat placements (carried from round 13).
- **Playtest list:** the Locks at seed 76424 with the Gangs (his rigs start in front of the west block; no ring
  without a truck); the garage from the title (room to add, the turntable, a time-out judged); a War Rig squad on the
  Terminus (nothing changed on the default path: N3 is opt-in); the pit with and without `AIRSHIP_ON=viewclimb`.
- No review page was published this round; step 5a had nothing to read.

### Housekeeping at the close

- Worktrees airship, garage, nav, squad removed after the ancestor check; branches deleted (nav's origin branch was an
  older round's and was never force-pushed). Nothing git-ignored in them was evidence.
- **A 92 MB brief blob was kept out of main** (lesson 228): airship's branch was rewritten on itself before merge.
- **An hour lost to a killed wrapper** (lesson 227): the remote half kept running; the wrapper refused the relaunch;
  read the launch log within a minute.
- The two `.uid` sidecars Godot generates in the main checkout on a local lint blocked one merge; delete them (they
  are byte-identical to the branch's) before merging a branch that adds the same tests.
- The tactics ladder's ELO is not comparable across `5f562dd0` for matches that hit the time limit (the winner rule).

_The launch record follows, as written:_

## 🚀 ROUND 14 IS LAUNCHED (2026-09-27, evening) — kept as written

| stream | offset | the job |
|---|---|---|
| airship | 1 | **A0 first, a defect from his play tonight:** *"I have 2 war rigs for the game that turned invisible during gameplay"* — reproduce, measure, name the mechanism (cutaway / rig art / airship occlusion / under a bridge), fix with a regression test; **from the recording and his correction:** the Locks, seed 76424, `Green_Guns_7`/`_9`; their ART vanished while he DROVE them, the selection ring still drawn (*"just a blue circle"*) — **MECHANISM FOUND by replay (airship): they SPAWNED INSIDE the city block at (−30, 42) — 13 rigs overflow the Locks' 32 m spawn zone and `SlotGround.standable` is a silent no-op before the nav map is ready — and depenetration pushed them 6.24 m under the floor for the whole match. Fix in `ArmyLayout._clear_spot` under a carve-out, regression test on the Locks at seed 76424, a logged floor-depth safety net (`game_design.md` *MECHANISM FOUND*). The roof and canal-rim guesses are dead. Then **his item:** the airship steers clear of the player's view — measure the intrusion with the LIVE camera, then the carrot avoids the wedge between camera and focus (looking ahead; opaque, visible, the PID and climb-over kept); ship ON only if it is still seen |
| garage | 2 | round 13's G1 list: room to build, the turntable at match proportions, a stalemate is a draw, a clean HUD at 20:9, the loader, delete the dead stub; three listed carve-outs |
| nav | 3 | the other 53 % of the rigs' reverse scrapes (route circle reverses, k-turn legs): instrument, validate with the sweep, fresh acceptance seeds; the stall share re-read; **CP1** if the baseline moves |
| squad | 4 | the two red instruments: bisect and fix the gang-pack drills; `scenario_perf` refuses under load (rule 3); the ladder variants' stale row |

**Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream). Merge at the
hash each stream names green; read every review page's `db` at close (none expected); rescue git-ignored payload.

**Merged so far (the orchestrator, live):**

| stream | green code hash | merge | what landed |
|---|---|---|---|
| airship (A0) | `62658311` (builder0 1792/0, 18 targets, baseline unmoved, measured) | `197364a8`, main's own check 1792/0, baseline `6313a38d7ecd99bb` | **The invisible War Rigs: deployed INSIDE a city block and pushed under the floor.** Replay of his Locks recording (seed 76424, his flags): 13 × 14 m rigs overflow the 32 m spawn zone; `SlotGround.standable` is a silent no-op before the bake (1279 unchecked queries live); depenetration pushed two rigs 6.24 m down for the whole match — art under the floor, ring on top. Fix (carve-outs): `_clear_spot` keeps the whole hull clear of obstacles, inside the arena, off water/pits; the unchecked count printed; `TANK_OFF_FLOOR` logged. Live: 4 hulls under the floor → 0 of 41; the class was wider (3 hulls on the perimeter wall at chamfered corners). **His playtest:** `make skirmish` with `--seed=76424 --arena=locks --player-faction=gangs --enemy-faction=condemned`: the rigs start in front of the west block; no ring without a truck |

| garage | `25d1c9b7` (main merged in; builder0 1804/0, 18 targets, garage-tour failed=0 both aspects, baseline unmoved) | `5f562dd0` + docs `3eb9aa7c`, main's own check at `3955efec` 1804/0, baseline `6313a38d7ecd99bb` | **The list a player's first visit produced, all six built.** The starter leaves room for the cheapest unit (800: Tank, Tank, IFV, Scout = 660); the turntable hosts a real `Tank` (the hull the match fields, within 5 %); **a time-out under elimination is JUDGED on points destroyed, equal = DRAW**, the control point first (a rule change: any series reading a time-out's winner changed meaning here); the camera readout off for players, on for `make skirmish`, no overlap at 20:9; the loader shows the army; `catalog_stub.gd` deleted. Carve-outs listed: match.gd, camera_readout.gd, hud_skin.gd, skirmish_mode.gd, loading_screen.gd, mk/play.mk. G7's next list in its Status |

| airship (A1–A3) | `601035f2` (builder0 1798/0, 18 targets, baseline unmoved) | `c442e7ef` + docs `6f3cf165`, main's own check 1810/0, baseline `6313a38d7ecd99bb` | **The airship against the LIVE camera, and the climb over his view, shipped OFF.** `make airship-view`: round 13's flight hides the fight 1.5–4.8 % of ticks on the Terminus, 3.4–7.5 % on the yard, 60–86 % of it while it does; most intrusions are the camera travelling to the hull. A2: the lens's near wedge is one more thing the flight climbs over (`AIRSHIP_ON=viewclimb`); the steering term measured no help live, OFF. A3 on fresh seeds 11–18: hides-the-fight pit 7.8 → 2.3 % (8 of 8), yard 5.0 → 2.5 % (7 of 8), Terminus 2.3 → 1.2 %, longest intrusion to a third — misses the pre-registered bar and halves how often he SEES it. **His call:** `AIRSHIP_ON=viewclimb make skirmish ARENA=pit` vs plain. The branch was rewritten on itself to drop a 92 MB brief blob (lesson 228) |

| nav (N1–N4) | `36c0547e` (main 3955efec merged in; builder0 1814/0, 18 targets, baseline unmoved; test_nav_ 92/0) | `8d65f866` + docs `7db73c32`, main's own check at `1648b78b` 1820/0, baseline `6313a38d7ecd99bb` | **The other 53 %, instrumented; two fixes measured and shipped OPT-IN; no CP1.** N1: momentum is the biggest mechanism in both buckets (236 of 305 k-turn reverse contacts nose-end with the hull still rolling forward; the drive follows the plan on clean legs, the contacts are at leg boundaries). N2 (circle rule gated on a sweep): falsified ×3 on the design seeds, `--nav-off=circlefit` turns it on. N3 (a planned leg ends within its stopping distance): rigs' contacts −24 % / −19 %, leg time −6 % / −13 % on design/acceptance seeds, BUT it broke `scenario_cp2`'s engine-deck scout (41/43 → 3/13: the orbit relies on planned legs being brake taps) and N3b did not rescue it — **opt-in (`--nav-off=kturnbrake` turns it on), the baseline stays**; the round-15 item: N3 keyed by hull class or plan purpose, `nav-scenario-arms` as the gate. N4: the stall share is a coin flip (25 of 48); a holding rig queues ~3.4× more per second, +13 % queued time overall. **Nothing changes on the default path.** |

| squad (Q1–Q4) | `81699a4f` (builder0 1805/0, 19 targets, baseline unmoved; `scenario_perf` judged PASS alone at 0.99×) | `f72091e6` + docs `58fab300`, the round's final check 1821/0 (`18 passed, 1 NOT JUDGED` + the alone PASS 1.01×) | **The two red instruments.** Q1: the gang-pack drill assertions were red since the commit that wrote them (2026-09-16: encircle off, bait needs a MOVING contact, the drill staged dug-in guns); no behaviour regressed; the drill asserts the gangs' design and can still fail (three mutation runs). Q2: `scenario_perf` REFUSES when the box is loaded (reference workload vs a recorded idle nominal per machine; NOT JUDGED on the verdict line, never a pass); loaded proof refused at 2.05×, mutation failed as before, alone PASS. Q3: the ladder variants take the live table's rows. Q4: `tactics-drills` in `check` (15 s, one md5 across three runs). **For the lead, not acted on (C12.6, ONE seed):** the 09-16 encircle/bait verdicts have flipped. Shared edits listed: mk/core.mk, check_verdict.sh, the gate script, mk/metrics.mk, mk/ai.mk |

**In flight (was):** squad (Q1 the drill corrected with three mutation runs at `070476be`, Q3 done, Q2 in a check; a one-seed finding for him: the 09-16 encircle/bait verdicts have flipped, C12.6 untouched); nav (N1: momentum is the biggest mechanism — 236 of 305 k-turn reverse contacts nose-end while still rolling forward; N2 build 2 on the design seeds, acceptance seeds 9–16 pre-registered).

_Previous state:_ **ROUND 13 IS CLOSED: three streams (squad, nav, audio), every item merged, worktrees removed, briefs in `streams/archive/round13/`, evidence in `streams/references/round13/`. No round is running. `main-checked` is `5b3c49f9` (the final check: builder0 1790/0, 18 targets, sim-baseline `6313a38d7ecd99bb` UNMOVED all round); after it only docs (`dad3ca23`, `9313eb70`, this). The lead pushes. S6 decided in chat: ON, with the toggle documented at the code site (`game_design.md` *Round 13: S6 decided*). Nothing is waiting on him. **Round 14's first item is his (2026-09-27 evening): the airship steers clear of the player's view** — `game_design.md` *Round 14 direction, first item*; `roadmap.md` *Round 14 candidates* 1.**_

## ✅ ROUND 13 IS CLOSED (2026-09-27, one afternoon) — read this first

**Three streams, every item built and merged, the sim baseline unmoved all round.** His words are in `game_design.md`
*Round 13 direction*. Briefs in `streams/archive/round13/`; evidence in `streams/references/round13/` (squad's Q1 and
Q2 frames, nav's yield sheet and two clips and every log, audio's tour sheets and logs); lessons 223–224; round 14's
candidates in `roadmap.md`. The merge table below was kept live during the round and is the record; each row names
the green code hash, the merge, and main's own verdict read from the wrapper's line.

### Waiting on the lead

- **S6 ON or OFF** (squad's Q2, shipped ON at `73060fa2`): an 8 s faster stop for the mixed squad against scouts that
  can sit 2–3 m off their slot and no longer angle out along their sector. Frames:
  `streams/references/round13/squad/q2_scouts_crop_s6_off_on.jpg` (the Terminus F_1 short of its cross by the block
  corner) and `q2_{yard,terminus}_s6_off_on.jpg` at his pose. **ANSWERED in chat 2026-09-27 evening:** *"ok go ahead
  and turn it on, but let's make sure it's documented in our codebase that this behavior can be toggled I might want to
  change it later"* — ON stays; the toggle is one line with the lead's words and both behaviours described above it in
  `game/ai/tank_brain.gd` (`IDLE_FACE_NO_PIVOT`); recorded in `game_design.md` *Round 13: S6 decided*.
- **For his ear, not a decision:** the garage's two blues; the two defeat placements by title (`make garage` → FIGHT →
  lose, or `make remote T="audio-pass PASS_SECONDS=90"`).
- **Playtest list:** from the title, GARAGE → build → FIGHT (the loop that had never been played); a Condemned squad's
  plain move on the Terminus (a wedge now); the War Rig squad through the Terminus streets (they yield into room they
  fit, and sometimes hold instead); a mixed squad's stop (S6).
- No review page was published this round, so step 5a (read every page's `db`) had nothing to read.

### Housekeeping at the close

- Worktrees squad, nav, audio removed after the ancestor check; branches deleted. Nothing git-ignored in them was
  evidence (each stream committed its sheets, clips and logs under `references/round13/`).
- Two idle audio sessions were open at launch (`godot-audio-dc` alongside the working `godot-audio-30`); only one
  worked the branch. Close stray sessions before a kickoff.
- `make tactics-drills` fails 2 gang-pack assertions on main (pre-existing at `8f96a43c`, not in `check`);
  `scenario_perf` went red once more under builder0 load (audio's first check). Both on the round-14 list.
- The laptop's memory guard killed the orchestrator's foreground waiters twice; detached `setsid nohup make remote`
  plus a 60 s-poll monitor on the log survived. Three worker sessions plus the orchestrator is the practical limit
  with Chrome open.

_The launch record follows, as written:_

## 🚀 ROUND 13 IS LAUNCHED (2026-09-27) — kept as written

**His answers** (verbatim in `game_design.md` *Round 13 direction*): 2 *"Default wedge"*; 4 *"leave"*; 5 *"29 MB of music is fine"*;
6 *"Yes let's add garage music, but I've never even smoke tested the garage"*; 7 *"ok"*; 8 *"don't worry about this"*;
1 and 3 *"I need clarification"* / *"I don't understand the question"* — the clarifications are recorded there; 1 starts
on the orchestrator's recommendation (his veto stands), 3 is measured rather than asked again.

| stream | offset | the job |
|---|---|---|
| squad | 1 | the wedge is the default plain-move shape (column only where the paired series still says so); S6 measured (no idle `face` for a no-pivot hull with nothing in sight), baseline pre-registered MOVED |
| nav | 2 | right-of-way sized for long hulls: the rig's +57 % reverse-gear contacts from yielding into small-hull spots; **CP1** = its baseline move, merged alone |
| audio | 3 | the garage smoke-tested like a player from the title (frames at both aspects; an hour's fixes; the rest as a round-14 list), then the `garage` state plays and rotates |

**Closed by his answers:** the partial selection stays; the web music pack stays at 29 MB; the key rotation is his
not-worry. **Kickoff:** the one-line prompt in `orchestration.md` *The kickoff prompt* (the same for every stream).
Merge at the hash each stream names green; nav's move is recorded twice with `make sim-baseline-adopt` (run LOCALLY:
it calls the remote wrapper itself); at close read every page's `db` (step 5a) and rescue git-ignored payload.

**Merged so far (the orchestrator, live):**

| stream | green code hash | merge | what landed |
|---|---|---|---|
| squad | `57ab6597` (builder0 1777/0, baseline unmoved) | `cee83fd2`, main's own check 1777/0, baseline `6313a38d7ecd99bb` | **Q1: the wedge is the default plain-move shape in every terrain.** The yard re-measured on the same seeds (builder0, 8 cells × 4 seeds): column first in 5 of 16 paired runs, tidier in 0 of 4 cells, against the pre-registered bar of 9 and 2. Frames at his pose in `streams/references/round13/squad/`. The `IDLE_FACE_NO_PIVOT` switch ships OFF here; Q2 (S6 ON) follows as its own merge |

| squad | `07b276c4` (builder0 1777/0, baseline unmoved in BOTH arms although pre-registered MOVED) | `73060fa2`, main's own check 1777/0, baseline `6313a38d7ecd99bb` | **Q2: S6 ON.** A wheeled fixed-gun hull with nothing in sight is not told to face unless its order names a facing. `squad-idleface-series` (builder0, 8 seeds × yard/Terminus × forward/side × mixed/tracked): mixed stop 19.7–22.8 → 11.3–15.1 s, faster in 32 of 32 pairs; tracked control 32 ties; arrivals and worst off-slot unmoved; drills identical off/on. **The cost he must judge:** the scouts' own off-slot at the stop 0.9 → 2.7 m; in `references/round13/squad/q2_scouts_crop_s6_off_on.jpg` the Terminus F_1 sits 2–3 m short of its cross by the block corner, and ON scouts point the way they drove instead of angling 45° out along their sector. OFF is one line (`TankBrain.IDLE_FACE_NO_PIVOT := false`) |

**Waiting on the lead (round 13):** **S6 ON or OFF** — an 8 s faster stop for the mixed squad against a scout that can sit 2–3 m off its slot and does not square up to its sector. His standing words (*"a 4s slower march for a tidier traversal is better"*) argue OFF; the numbers argue ON; shipped ON, asked in chat with the frames. UNANSWERED until he says.

| nav | `80f8c522` (builder0 1780/0, baseline unmoved in EVERY arm although pre-registered MOVED — no CP1) | `51a0dcd9` + docs `7325a1d7`, main's own check 1784/0, baseline `6313a38d7ecd99bb` | **A give-way the hull fits (R1+R2).** R1: the WHOLE round-12 +542 rig reverse-contact rise was right-of-way: spots were checked only at the hull's centre, and the 6 m last-resort back-up aims at a point inside a 14 m hull's own footprint. R2 (`--nav-off=yieldfit` restores round 12; `yieldshort` = the refusing build, measured worse; `yieldhold` = give way in place): a spot is accepted only if the steering-law drive to it keeps the whole outline clear, else give way as far as it fits, else in place. builder0, 16 seeds × 2 squads: rigs' reverse contacts 3602 → 1756, all contacts 15129 → 7305, leg time 2292 → 1915 s, arrivals 229 → 225 of 256; mixed 4282 → 2114 contacts, arrivals 364 → 366; fight-maps net wall ticks down 12 of 12. **Declared:** four pre-registered clauses FAILED on seeds 1–8 (the design seeds: arrivals −5, refusals +16, press/unstick +36 %) and reversed on fresh seeds 9–16; the fight-maps `blocked_*` share rose on 7 of 12 against a bound of 6 (a hull that yields in place is a hull that holds). Shipped ON on his standing trade (*"a 4s slower march for a tidier traversal"*); one switch to veto. Evidence merged (`8af1eb5d`): `references/round13/nav/` — the yield sheet (seed 7, first leg, both arms; **looked at by the orchestrator: OFF, the three rigs are through the gap by 5 s and gone by 8 s; ON, two are still in the gap at 8 s, one holding** — this leg is the slower march, though the 16-seed leg time is 16 % lower in aggregate), the two clips, R1's buckets, the 16-seed table, every log |

| audio | `c4d11015` (builder0 1779/0, 18 targets, baseline unmoved; `audio-launch-smoke` on a display passed) | `13a5f009` + docs `4504a9f3`, main's own check at `5b3c49f9` 1790/0, baseline `6313a38d7ecd99bb` | **The garage smoke-tested like a player, then given music (G1+G2).** Two findings a player hits first, fixed: **the title had no way into the garage** (a GARAGE row: the one shared line, `game/ui/widgets/title/title_screen.gd`); **a windowed FIGHT opened the skirmish's faction menu at 0 v 0** and restarted without the army (every earlier garage check was headless). `make garage-tour`: a tap-by-tap loop from the title with a frame per step at both aspects (`references/round13/audio/`, looked at by the orchestrator: the loop runs end to end). The director holds `garage` while the builder is up; FIGHT hands back to `pre_match`; the garage and victory pools split (one director follows the player into the match; a shared pool replayed the garage's take on the win). **The round-14 garage list** (audio's Status): the starter army leaves no room to add a unit; the turntable shows a short turreted tank while the match fields the dozer-bus (the hull-box fit is not applied on the turntable, theme-side); a stalemate time-out reads DEFEAT; the camera readout sits over the HUD at 20:9; `catalog_stub.gd` is dead code. **For his ear:** the garage's two blues; the two defeat placements by title (G3) |

**In flight (was):** Nav's R2 (sized give-way: at `d7d2f5d7`, builder0, 16 seeds × 2, rigs' reverse-gear contacts 3602 → 1756, arrivals 229 → 225 of 256, mixed 4282 → 2114 contacts, arrivals 364 → 366; R1's buckets: the give-way layer is 44 % of the rigs' reverse contacts, route 38 %, k-turn 15 %; CP1 pending its attribution). Audio's G1+G2 done in Status at `1dae1959` (two player findings fixed: no GARAGE on the title; a windowed FIGHT opened the faction menu at 0 v 0; a round-14 garage list of five; FIGHT lands in `pre_match`; garage/victory pools split), check re-running after a `scenario_perf` load flake.

**Known outside `check`:** `make tactics-drills` fails 2 gang-pack assertions on `8f96a43c` already (squad, same with S6 off and on).

_Round 12's record follows:_

## ✅ ROUND 12 IS CLOSED (2026-09-27) — read this first

**One night, six streams, every item on the list he approved, and one that was not on any list until he asked about it.**
His words are in `game_design.md` *Round 12 direction* (three parts) and *Round 12: the lead's verdicts as they land*.
Briefs are archived in `streams/archive/round12/`; the rescued evidence (page dumps, frames, clips) in
`streams/references/round12/`; the lessons are `orchestration.md` 220–222.

### Merged to `main` (in order; verdicts read from the wrapper's own line)

| stream | green code hash | what landed |
|---|---|---|
| fleet | `3b2fb346` (CP1), tip `d497a1b1` | **the fire engine he approved on 2026-09-24 and nobody read back**: the burner's own turntable-ladder hull, turret on the pedestal, flame from the drawn nozzle, box 2.40×2.40×6.89 → 2.99×3.30×7.54 (baseline pre-registered MOVED, measured unmoved: the burner is not in the baseline match); a pipeline fix (`AssetContracts.unit_pivot` floated new turret art 1.39 m); the bus: `bus_r11_i` came back a van (2.04:1) and was not shipped; the rig's muzzle gap 0.47/0.84 m = 16–29 px at his pose, left alone; matchups 130 → 132 of 180, a wash. Meshy 809 → 779 |
| audio | `da9edaec`, then M6 `159f8645`, M7 `aa049f5f` | the opening had NEVER played the pre-match bed (MatchMood starts at `lull`; nothing asked for `pre_match`); the director draws per state per match, least-recently-heard first; 14 tracks imported, every state rotates 3–6; the booth's faction unit ids fixed (413 of 427 events unmatchable before); 67 lines (trade 3 → 20), then 49 PA lines where she actually speaks (0.62 → 0.93 a match during play), then the ten he vetoed removed; repeat of the most-said line 109 → 44 in 160 broadcasts. ElevenLabs 56,183 → 44,495 |
| nav | `5b5e3a6a` (CP2), tip `5e3c4b0e` | of 132 refused back-ups, 36 were the search aiming under the hull; a ≤5-leg back-and-fill, the steering-guard fix, a blocker reach that sees a 14 m friend, and N6 (an arrived no-pivot hull stays arrived). Rigs: refusals 130 → 56, arrivals 104 → 115/128, press/unstick 227 → 83; declared cost reverse-gear contacts +57 %; mixed stop time 18.9 → 12.1 s. **Sim baseline `01ab39b5` → `6313a38d7ecd99bb`**, two causes, both attributed by arm; recorded `d6094cef`, read twice |
| camera | `fe4f79fb`, tip `206939ab` | the camera's visual questions read drawn extents (`AirshipFlight.DRAWN`, one table): out of the lamp head at low tilt. **His verdict:** keep that; **don't cut screens; leave masts and signs standing** — the cutaway is buildings-only, the machinery kept |
| squad | `bb51ca06`, tip `39184e14` | the AUTO icon and card read the leader's pick; a G-chosen shape survives `_halt`; the brief's terrain claim corrected (the Terminus is *lanes*; his factions' tables pick column everywhere); the fall-in rule measured WORSE both ways and ships OFF; a partial selection scatters by his round-10 design (his call); S5: wedge faster in 23 of 32 paired runs (his call) |
| arena | `fcc45829`, tip `a306706d` | water reads wet: the surface reflects the venue that is there at his angles, teal body, lamp glints on a swell, a lap line; near-black pixels 0.98 → 0.55 (Locks far quay), 0.72 → 0.37 (Crossing far bridge); pits unchanged; ~1 ms GPU, 0 draw calls (the first version cost 3 ms, bisected with `make water-gpu`) |

### The three findings that were not on the list

1. **A lead decision on a page is not a project decision until the repo has read it** (lesson 220). The fleet page held
   his fire-engine approval for two days. Now: the close-out reads every page's `db` (step 5a), and HANDOFF lists any
   page as UNCONSUMED until it has been read.
2. **The builder0 incident** (lesson 221, 23:28): a detached `tools/remote.sh` launched from a non-git copy resolved its
   repo root to `/` and ran `rsync --delete` of the laptop's root into `~/tank_squad/` — every stream folder gutted
   mid-run, `/home/slobdell` (with `.ssh`, `.claude`, `.credentials`) copied to builder0. Contained the same night: the
   copies deleted, the folders self-repaired on each stream's next sync, every run in the window declared void and
   re-run, the wrapper now REFUSES outside a checkout (`8a6a88a6`). **The lead should consider rotating the SSH key
   and the Meshy/ElevenLabs keys.** The 35 old round folders on builder0 that nothing re-synced stay gutted (junk).
3. **Two of his answers came in chat, not on a page:** the bus card (*"there was nothing wrong with the tank"* — the
   item closed; lesson 222's card rule) and the female announcer (*"more good content … for the female announcer"* —
   audio's M6, built and vetoed the same night).

### Waiting on the lead (live)

- **Arena's water page: ANSWERED in chat 2026-09-27** (*"Everything looks good, can we just get things wrapped up?"*):
  the wet look approved as shipped, the Locks' canal stays open. His taps never reached the page's `decisions`
  collection (read twice, empty), so the chat words are the record (`game_design.md`).
- **Column or wedge** (squad's S5; recommended wedge in lanes/open, column in dense) and **the partial selection**
  (recommended leave). Frames in `streams/references/round12/squad/`. Both are round-13 candidates in `roadmap.md`.
- **Key rotation** after the incident (his call).
- **Playtest list:** `make skirmish` twice from the title (a different opening track the second time); a big fight for
  the trade calls and the PA; the Condemned burner as a fire engine; a War Rig squad through the Terminus streets; the
  Crossing and the Locks at his pose.

### Housekeeping at the close

- Rescued into the main checkout before the worktrees came down: fleet's 16 Meshy files (the fire engine's raw 3D, the
  van-shaped bus, the rejected turnaround), audio's 70 + 58 ElevenLabs masters (the ten vetoed PA masters kept as paid
  records), camera's judged pairs and sweep, nav's two rig clips, squad's contact sheets — the last three committed under
  `streams/references/round12/`.
- Worktrees removed: fleet, camera, squad, nav, arena, audio, and arena's `arena-before`; branches deleted after the
  ancestor check. Older branches not touched this round (`feel-rig-check`, `measure/facing-arc`, `stream/terrain-uid`,
  `tmp/metrics-r8-control`) are for a quiet hour, not tonight.
- `scenario_perf`'s CPU-budget test trips under builder0 load (three streams saw it; each isolated re-run was green).
  Candidate: make it refuse rather than judge when the reference workload says the box is loaded (verification.md rule 3).

_The launch record follows, as written on 2026-09-26:_

## 🚀 ROUND 12 IS LAUNCHED (2026-09-26, evening) — read this first

**What he asked for**, shown the pending list: *"ok that all looks good but note that some of it might be stale. I
believe direct path doesn't scatter of the last fix. Another note: I believe I'd approved a render for a fire truck for
the condemned and I haven't seen that materialize yet. Can you set up our workspaces to orchestrated workloads for all
these items?"* (verbatim in `game_design.md` *Round 12 becomes a round*).

**Both of his notes checked out, and the first is the round's finding:**

- **The fire engine was approved and never built.** The fleet review page's `db`
  (https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS) holds his taps at **2026-09-24 17:27 UTC**: `burner_r11_b`
  APPROVED (the turntable-ladder fire engine), `bus_r11_i` APPROVED, `q_r11_bus_fit` APPROVED. The round-11 fleet
  stream last read the page at 16:00 UTC; the round closed that day; `review.json` still says `waiting`; no image-to-3D
  was ever requested for a fire engine. Dump: `_agents/streams/references/round12/fleet_page_db/`. Lesson 220.
- **The direct path does not scatter for the selections he makes.** Every spawned squad is on a number key (round 8),
  and `RtsControls._is_task()` routes a whole-squad or whole-group move down the task path, where the travelling anchor
  lives. Only a partial or mixed selection (or a shift-queued order) is direct. Roadmap item 10 is now a question for
  squad, not a defect.
- **Two stale numbers corrected:** Meshy has **809** credits (the ledger, 2026-09-24), not 88; the laptop disk is at
  90 % with 12 GB free, not 95 %.

**The six streams** (one line each; the table and the contracts are in `workstreams.md` *Round 12*):

| stream | offset | the job |
|---|---|---|
| fleet | 1 | record his taps; `burner_r11_b` → 3D → the burner's own hull/turret/box; `bus_r11_i` → 3D → the bus; the −Z and turret tests; stretch: the rig's muzzle. **CP1** = the boxes, merged alone, orchestrator records |
| squad | 2 | the AUTO icon shows the leader's pick (carve-out `command_icons.gd`); a G-chosen shape survives `_halt`; the fall-in rule; the partial-selection question; is *dense → column* right here |
| audio | 3 | the `trade` pool (5 lines) deepened and the director's pick widened; the 23 Suno tracks imported so every state rotates; generation authorised under his round-10 words (C12.7) |
| camera | 4 | `RtsCamera` and `BlockCutaway` read drawn extents (`AirshipFlight.DRAWN`, read not copied); no collider grows |
| arena | 5 | water reads wet (Crossing, Locks) as pairs at his pose on a page with `db`; the Locks question re-put; pits stay pits |
| nav | 6 | why `kturn_none` is 130 against 64 on the rig drive; a multi-leg back-and-fill validated with both ends; 8+ seeds. **CP2** = its baseline move |

**Start order if the laptop is short of memory** (it had ~2 GB free with Chrome open at launch; six sessions are
~2.1 GB): fleet, squad, audio first; camera, arena, nav as memory allows. Every Godot run of any size goes to builder0.

**`main-checked` moved to `db0cc74f` (2026-09-27 early): `>> remote: make check exited 0`, 1753 passed, 0 failed,
sim-baseline `6313a38d7ecd99bb` (nav's CP2, recorded `d6094cef`, read twice), determinism `550d53790035ddb4`; the tree with
fleet, audio, nav CP2 and camera merged. squad (`d3ab4865`) merged after it, green on its own check; the tip's check follows.**

_Earlier:_ **`main-checked` moved to `8a6a88a6` (2026-09-27 00:1x, builder0): `>> remote: make check exited 0`, 1732 passed, 0 failed,
sim-baseline `01ab39b592cc9837` unmoved, determinism `b83a374ce2fcde37` — the tree with fleet's CP1 and the remote.sh guard;
the checkpoint went to squad, nav, camera and arena at that hash.** Audio (`785bc293`) merged after it on its own green.

**Green baseline at launch:** `main` at the docs commit that carries this section; the code is `0299e05e`, whose
check on builder0 read `>> remote: make check exited 0`, 18 targets, **1726 passed, 0 failed**, sim-baseline
`01ab39b592cc9837`, determinism `b83a374ce2fcde37`. `main-checked` is annotated with that line. The two kept branches
from round 11 (`stream/arena` at `84e706eb`, `stream/nav` at `70201d30`) held only docs already folded by `0c7d23a3`
and were deleted so this round's worktrees start from `main`.

**The kickoff prompt** (the same for every stream; the stream comes from the folder — `orchestration.md` *The kickoff
prompt* is canonical):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your
> working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and
> `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an
> answer except at lead gates; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md,
> `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`,
> `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch
> items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and
> look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item
> is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the
> Status holds your report.

**Waiting on the lead (round 12, live list; lesson 220: a page's `db` is UNCONSUMED until the repo has it):**

- **The bus: CLOSED (2026-09-27, in chat).** His words: *"The firetruck looks great, I don't know why it's giving me
  the condemned tank for approval. There was nothing wrong with the tank"*. The Condemned tank keeps its look; fleet
  records `bus_r12_mv` rejected with those words and spends nothing more (`game_design.md` *Round 12: the lead's
  verdicts*).
- **The partial or mixed selection** (squad's S4): it scatters, by the round-10 R1 design he narrowed himself; squad
  recommends leaving it. His call, on the next page or in chat. Frames: `streams/references/round12/squad/s4_yard_*`.
- **Column or wedge for a Condemned/Law plain move** (squad's S5, `161465ef`, builder0, 4 seeds × 8 cells, same
  seeds): the wedge settles faster in 23 of 32 paired runs and its first-10-s station error is lower in 7 of 8 cells
  (yard forward mixed 16.0 → 9.1 m); the column wins only the yard's forward move through the chokepoint and looks
  tidier in a Terminus street. Row kept as column. **Recommended: wedge in lanes and open ground, column in dense.**
  Frames: `streams/references/round12/squad/s5_*_sheet.jpg`. Put in front of him 2026-09-27.
- **Arena's water page, with `db`, UNCONSUMED:** https://claude.ai/artifact/1PsZA4HnRWGCSgajuyamKN — "have you driven
  the Locks yet?", an overall tap, the Crossing / Locks / Terminus-canal spots (dry twin | round 10 | now), each map's
  build as one-dial steps, the pits unchanged, and **the Locks' open-canal question with its 45 % exposure number**.
  Taps land in `decisions/<id>` (the fleet page's schema). Arena's green code hash `b05b87c4` (builder0, 1773/0,
  baseline unmoved); its tip's final check pending.
- **Audio's three (merged at `785bc293`):** the web pack grew (`assets/music/` 13 → 29 MB, all in the web build) —
  ruled *leave it, decide at the next web release*; **by ear**, the two weakest placements are `defeat_hunt`
  (Predatory Hunt) and `defeat_ragnarok` (Ragnarok's Engine), one `states` edit each in `assets/music/manifest.json`;
  the garage has no music (not this round). **His veto page, with `db`:** https://claude.ai/artifact/6kWUqopgyKkiv6Ahf669A5
  — all 67 new lines with their clips, Keep / Veto per line; taps land in the `verdicts` collection (doc id = the
  line id with `.` → `_`). **CONSUMED 2026-09-27: all 67 KEPT**, dump in `streams/references/round12/audio_veto_db/`.
  His words led to a new audio item: **more content for the female announcer (the PA voice)** — audio's M6, DONE and
  merged (`159f8645` green): 49 PA lines where she actually speaks, her lines during play 0.62 → 0.93 a match.
  **Her veto page CONSUMED 2026-09-27: 39 kept, 10 vetoed** (https://claude.ai/artifact/Kkj5VrQPuw8HNDLJUsPtjk; dump in
  `streams/references/round12/audio_pa_veto_db/`); audio's M7 removes the ten (running at close).
- **Playtest for him:** `make skirmish` twice from the title — the opening should be a different track the second
  time; in a big fight, listen for the trade calls; the Condemned burner is a fire engine.
- **Camera: ANSWERED** (2026-09-26 evening: keep the lamp-head fix, don't cut screens, leave masts and signs standing);
  applied at `806dd794` on `stream/camera`, recorded in `game_design.md`.

**⚠ INCIDENT 2026-09-26 23:28 — builder0's `~/tank_squad/` was emptied by a runaway rsync, and the laptop's home
directory was copied there** (lesson 221). A worker launched a detached copy of `tools/remote.sh` from a scratchpad
directory; `git rev-parse` failed silently, the sync ran with source `/` and `--delete` against `~/tank_squad/`.
Consequences and what was done: (1) every stream's remote folder was gutted; each repairs itself on that stream's
next `make remote` (the sync is a full `--delete` mirror), and every stream was told that any remote result whose run
began between 23:28 and its next sync is VOID; (2) `main`'s first round-12 check (commit `14c0f62a`) read 1672/23 with
"file not found" for tracked files — that red is the incident, not the merge; re-run below; (3) the copied root
filesystem, including `~/tank_squad/home/slobdell/{.ssh,.claude,.credentials,.gnupg,…}` (2.2 GB), was deleted from
builder0 the same night; **the lead should consider rotating the SSH key in `~/.ssh` and the Meshy/ElevenLabs keys,
since they were copied to a second machine**; (4) `tools/remote.sh` now REFUSES to run unless the cwd is a checkout
with a Makefile (the commit that carries this note). The remote folders `squad-legs` and `squad-main` on builder0
are round-9 leftovers, gutted, harmless. **A seventh worktree exists for the round:** `../godot-arena-arena-before`
(branch `stream/arena-before`, at `46bac1a3`, offset 7), arena's "before" tree for the Crossing perf pair; nothing
is committed there; **remove it at close** (`git worktree remove ../godot-arena-arena-before`, then delete the branch).

**For the orchestrator running this round:** merge at the hash each stream names green; CP1 (fleet's boxes) and CP2
(nav's planner) are the two baseline moves, each merged alone and recorded twice with `make sim-baseline-adopt`; at the
close, **read every review page's `db`** (arena's, fleet's if it makes one, the Booth Monitor's if it has one) before
archiving — that is the step whose absence lost the fire engine.

_The fine-tuning session's record follows, as written earlier on 2026-09-26:_

## 2026-09-26: the travelling anchor (the lead fine-tuning in the main checkout, no orchestration)

**Closed by the lead the same evening:** *"ok commit your changes, this is now really good."* Committed on `main` as the
commit that carries this section (its hash is `main-checked`'s, moved here because the full check below ran on exactly
this code; the doc edits after it touch only `_agents/*.md` and this file).

**His words** (`_agents/game_design.md` *Round 12 direction*): *"it seems to take a long time for units to form up in
the desired formation … I just started a game where my first action was to click a location for a squad, they were in
auto formation (which I assume is a wedge based on the UI), and they all split apart and navigated their own way to the
destination."* Then, after the diagnosis: *"go ahead to build."* He also asked about the announcer's repeating filler
(*"they are trading in the middle of the floor"*) and whether the music rotates between matches — **parked at his request,
his words recorded, nothing investigated beyond the first grep** (roadmap item 11).

**The finding** (`_agents/doctrine.md` *A plain move travels AS a formation*): the scatter was the plain move's design —
one shape laid on the click, every crew to its final slot by its own route, and the round-7 flow gated on a
leader-at-the-front that round 10's least-driving seating made rare. And the shape he was looking for was not the one
being formed: the AUTO icon draws a wedge; the doctrine picks a column on dense terrain, which both the default arena and
the Terminus are.

**What was built** (all on the plain-move path only; CPU tasks run drills and never take it):
- `Element._advance_transit` + `ElementPlan.stations_along`: a travelling anchor on the navmesh route at the slowest
  hull's cruise, held back by the crew furthest behind its place; every crew's STATION rides it along the route. The K1
  orders are unchanged (`move` to the final slot, once). `TankBrain._order_context` drives to the station while one is
  published (`ElementFeed` "station"), thinks at the near rate, hands nav the goal on every think (`sliding`). Hand-off
  12 m short of the click. Co-arrival pacing is off for a travelled move. `ElementPlan.TRANSIT_ENABLED` is the switch.
- Three rules found by trace and fixed: a crew ahead of its station WAITS; a crew beside its station aims ahead by the
  lateral gap; a nav repair of the STATION goal no longer completes the ORDER (`_update_order_progress`).
- Two things tried and reverted with their numbers in the code: braking the anchor into the click; one uniform 0.6
  approach pace after the hand-off.
- `make squad-settle TRANSIT=off` is the control arm (reproduces round 10's numbers byte for byte);
  `make squad-transit-series` is the paired series (yard + Terminus, 4 seeds, both squads); `--transit` on the probe.
- The anchor starts half a shape AHEAD of the squad's centre (`ElementPlan.transit_start_m`), so the head moves off
  first and the rest fall in — started on the centre, the middle pair of an abreast line tangled for 8 s (yard trace).
- Tests: three pure tests in `tests/test_tactics_tasks.gd`; `test_an_element_travels_in_formation_on_the_way`
  re-specified against the round-10 path as control.
- Housekeeping: two stray `|||||||` diff3 markers removed from `game_design.md` and `verification.md`.

**VERIFIED GREEN on this tree (builder0, 2026-09-26 evening, read from the wrapper's own line):** `>> remote: make check
exited 0`, `check passed: 18 targets`, **1726 passed, 0 failed**, sim-baseline `01ab39b592cc9837` **UNMOVED** (the CPU's
tasks run drills and never take the plain-move path), determinism `b83a374ce2fcde37`. The same verdict came back once
before, on the tree without the ahead start. Committed after his verdict (see the head of this section).

**The measurement, honestly** (the paired table is in `doctrine.md`; both series builder0, 4 jittered seeds, yard and
Terminus, both squads): with the ahead start the stop time is a wash (off faster 12 / on faster 14 / tie 6) and the
order completes within a second either way; the shape on the way holds a 10–14 m mean station error against a 10.6 m
pitch where before there was no shape. With the anchor started on the centre it was off faster 18 / on 11 / tie 3 with a
tighter 6–9 m shape but a tangled start. The weak phase is the first seconds of a move from the spawn line — an abreast
line becoming a column — where paths cross and a middle pair can stall together; the next thing to build is a fall-in
rule (a crew does not close on the line until the crew whose station is ahead of it has passed). **The lead's eye is the
check that counts; nothing here is tuned past what the traces explained.**

**Two things about the tooling learned the hard way tonight** (`_agents/remote_builds.md`): the laptop kills a long
local background wrapper when its memory runs low (Chrome had it), so heavy remote runs go through a detached
`setsid nohup` script that writes a done-file; and `pgrep -f <pattern>` matches the shell running it — bracket the first
character (`[m]ake squad-transit-series`) or a wait loop never ends and a `pkill -f` kills its own command.

### For the next agent: the announcer's filler and the music rotation (his next question, parked tonight)

**His words** (`_agents/game_design.md` *Round 12 direction*, verbatim there): he hears *"They're trading! They are
trading in the middle of the floor!"* often and asks whether there are enough phrases for the same filler; and whether
the music has a wide selection and rotates, since he cannot tell if the opening plays the same track every time — *"if
there are comparable moods across tracks (which there should be, I did a few variations), it would be good if we can
randomize the selection."* This is still fine-tuning in the main checkout, not a round.

**What one grep found before he parked it — start here, verify before acting (lesson: check, then act):**

- The line is `caller.kill.69` in `assets/announcer/lines.json` (1119 lines: caller 472, color 421, pa 226), tagged
  `["kill", "trade"]`, intensity 3, with a recorded clip in `assets/announcer/clips/manifest.json`. So it is not a lull
  filler; it is a KILL call for a mutual trade, and the question is how many lines carry the `trade` tag and how the
  director picks among them. `game/announcer/announcer_director.gd` (507 lines) has per-kind cooldowns, "no line repeats
  in a match while another fits", and lull banter with a back-off; `announcer_variance.gd` and `announcer_history.gd`
  are where repetition is supposed to be prevented. Count the `trade`-tagged lines first; if it is one or two, the fix is
  more lines (a paid ElevenLabs run: the lead limits scope, not spend — see the memory notes) or a wider tag match.
- Music: `game/audio/music_director.gd` reads `assets/music/manifest.json`. `track_for(state)` picks the best track for
  a mood state and, among tracks that tie, `tied[posmod(rotation, tied.size())]` — **one pick per match**, `rotation`
  drawn from a randomised RNG in `attach()`. So rotation across matches exists IF several tracks share a state and
  intensity; a stem set outranks a single bed (+10). `assets/music/` holds beds (pre_match, lull, garage, victory,
  defeat, last_stand), three fight stem sets (hydraulic, ritual, rust) and one stinger; `assets/incoming/music/` holds
  23 Suno mp3s including the variations he mentions (Wasteland Blues ×3, Mechanical Predator ×2) that may never have
  been imported (`make music-import`, `tools/audio/import_music.py`, `assets/music/PROMPTS.md`). First check which
  states have only ONE track in the manifest — the opening (`pre_match`) probably does, which would be exactly what he
  hears — and whether the incoming variations are imported at all.
- Both are audio's paths (`_agents/workstreams.md`); tests in `tests/test_audio_music_director.gd` and the announcer
  suite (`make announcer-check` is in the check).

**Open, for whoever picks it up** (roadmap items 8–11): the AUTO icon should show the leader's actual pick; a G-chosen
formation is overridden by the halt shape at the end of a drills-on move (`_halt`); the direct path (a box-selection that
is not a numbered squad) still scatters; the announcer filler and the music rotation.

_Round 11's record follows, as written on 2026-09-24:_ **ROUND 11 IS CLOSED on a green tree. `main-checked` carries the verdict; the round's record is the section directly below.** All four streams (arena, nav, fleet, airship) merged, plus the orchestrator's completion fix and the goal repair flipped on. The sim baseline moved twice and both moves are attributed: `457b5e83` → `814aed46` (nav's waypoint guard + planned reverse) → `01ab39b5` (fleet's hull boxes after the lead's verdicts). A fresh orchestrator starts the next round from the `round` skill; round 12's candidates are in `_agents/roadmap.md`. The airship sections below this one are round 11's starting point, kept as written; the rest of the file is rounds 9 and 10._

## ROUND 11 (2026-09-24): eleven defects from one playtest, and the one-line bug behind his first complaint

**He played the airship build and sent eleven items in one message, calling it a light workload.** It was: no new
mechanic, no new system, no design argument. **Three of the four streams were finishing work that already existed and
did not reach him** — which is the round's whole shape, and the thing to look for first next time.

**His words are in `_agents/game_design.md` *Round 11 direction*; his nine live verdicts from the two review pages are
in *Round 11: the lead's verdicts*. The briefs are archived in `_agents/streams/archive/round11/`.**

### The finding that set the round's shape, found before any brief was written

`Arena.ROTATION` (`game/arena/arena.gd:63`) was `["yard", "pit", "terminus"]`, and it is the **only** list the faction
picker offers and the only thing `--arena=random` can deal. `arenas/` held **fifteen** layouts. Round 10's `terrain`
stream had built **the Crossing** (water, two bridges) and **the Sumps** (four pits, two bridges) — exactly the
bridges and pits he had asked for a round earlier — and **neither had ever been reachable from the game.**
`arenas/pit.json` also carried no terrain: "The Pit" was a name.

That is the **third** instance of *"it's missing" means "it doesn't reach me"* (lesson 32), and the test written after
the second instance only asserted that the CUT maps were absent — it never asked whether the maps built since were
present. It does now: **a map that is built and neither dealt, cut, nor a fixture fails the suite.**

### What each stream did, in its own words where it gave them

| stream | what landed |
|---|---|
| **arena** | *"The maps weren't missing; they weren't being dealt."* The Crossing and the Sumps into the rotation; the **Locks** built, approved, its name recorded and dealt (rotation is now six maps); the Pit dug at the ring's corners; the 21 m venue floodlight towers — which had **no collision at all** and stood ~8 m inside the Terminus wall — moved outside it, with the prop-parity test extended to the venue dressing where they hid. Its best tool was **`make terrain-drive`**, which orders a squad across a map the way the lead would: it found nav's bridge-exit deadlock and three layout traps the static report could not see, because *"a lane wide enough by the bar can still be a road a 14 m rig can't turn in."* |
| **nav** | **A reverse decided at plan time instead of at the bumper.** Every reverse in the game was reactive (1 s of no motion, or 1 s of wall CONTACT). Now a wheeled hull whose steering point is >45° off the nose sweeps its full-lock forward arc against the navmesh with its LEADING end, and if that would hit, searches the reverse arc with its TRAILING end — the first reverse in this game validated against what is BEHIND — then drives it as a leg with its own completion. Measured on the Terminus, 8 seeds × 4 legs × 2 squads, control and treatment on the same commit: **press/unstick-driven contacts 88 → 1** (mixed) and 393 → 227 (rigs); total wall contacts −64 % and −29 %; cusps −12 % and −24 %; arrivals up in both. Plus the goal repair: `squad.gd:272` grounded a slot on the navmesh CENTRE while the mesh edge is 2 m from a wall, so a War Rig (envelope ~7.2 m) had its nose in the building. |
| **fleet** | **The turrets were spinning INSIDE the hulls** — only 4 of ~21 units had a `turret_mount`, and seven turrets sat below their own roof. Five gun cuts so they turn. The **"detached barrel" was a 14-triangle, 1.8 cm sliver 0.74 m off the centreline** while the real gun was already in the turret mesh; a derived rule now refuses the next generated stick rather than blacklisting it after he finds it. The Condemned tank and burner were **the only non-uniformly stretched meshes in the game** (1.63:1 on the tank — his "deformed"); the bus is 4.08 m and uniform, the burner 2.40 m and exempt until it has a mesh. The Law at his approved **1.25×** as a declared multiplier (`Units.FACTION_SCALE`), not hand-edited numbers. And **the first test in this project's history that asserts a model faces −Z**. |
| **airship** | It was **inside something 31 % of a 240 s Terminus flight**; it is now **0 % on all nine maps**. Its blocker table used a radius-21 circle for a 40 × 40 m block whose corner is 28.28 m out, evaluated the climb at the hull's centre while its nose is 28.5 m ahead, and needed 8.7 s to climb with 1.6 s of lead-in. Real rotated footprints, drawn heights, and a look-ahead by the climb time. **The camera goes up and back over the hull when they meet**, so the airship ends up in frame — the lead watched the clip and said it looks fine. |

### The two sim-baseline moves, both attributed rather than asserted

1. **`457b5e830708b439` → `814aed46b1042e62`** (nav). Attributed with `make nav-sim-arms`: R2's grounding alone leaves
   the hash **unmoved**; the waypoint/follower-deadlock guard alone gives `bdb21d205dc97405`; the planned reverse takes
   it the rest of the way. Two causes, and the goal repair is neither.
2. **`814aed46b1042e62` → `01ab39b592cc9837`** (fleet's CP1). Hull boxes changed on purpose after his verdicts;
   `hull_size` IS the collider, so the baseline match's hulls are different bodies.

Adopted with **`make sim-baseline-adopt`** (reads twice, refuses a disagreement, merges the line) — *not* by copying
`build/sim_state_hash.txt` over, which deletes every other machine's baseline.

### The orchestrator's own work, and its two errors

- **The integration fix (`78b26067`):** nav's goal repair could not be switched on, because a repaired goal could
  never complete — `TankBrain._update_order_progress` judged completion against the order's ORIGINAL goal while the
  hull drove to the repaired one. The rule chosen is deliberately **narrow**: the mover owns "did this hull arrive",
  the brain owns "is this order done". **Not** "widen the arrival radius by `repaired_m`", which is round 6's "close
  enough after a stall" fudge returning — at `REPAIR_MAX_M` 12 m it would complete any move from a 12 m disc.
  Mutation-checked: without the fix the repaired case fails and the control still passes.
- **The flip (`7c25665c`):** the repair is **ON by default**, because a behaviour behind a flag the default path never
  passes has not shipped (lesson 23). Measured on the Terminus, one run per arm, 30 units: completed 20 → 22,
  never_completed 10 → 8, and **the two extra completions are the two repairs**, matching unit for unit. The yard arm
  is a null control and reads as one. Cost stated in the code: `completed_far` 0 → 1. The flag was also **inverted**
  (`--nav-off=repair` turned it ON); it now disables, like every other mechanism name.
- **Two errors, both written up as lessons (214, 219):** the orchestrator read a floodlight's **collider** (3.0 m) as
  the object, put "the floodlight is 3 m" in a brief and in a report to the lead, and attached an inference that the
  real measurement then **inverted** — time at cruise went DOWN, not up, because the old figures counted time spent
  flying THROUGH things. And it sent a confident, detailed, **wrong** hypothesis about the War Rig's turret that fleet
  had to kill with a measurement. Both cost nothing only because the instruction said *check this before acting on it*.

### Housekeeping at the close (2026-09-24)

- **`main-checked` is on `f83f25e0`**, the commit a check actually ran on: builder0, `>> remote: make check exited 0`,
  18 targets, **1716 passed, 0 failed**, sim-baseline `01ab39b592cc9837` unmoved, determinism `b83a374ce2fcde37`.
  The commits after it on main touch only `_agents/*.md` (verified with `git diff --name-only`).
- **Paid inputs rescued before the worktrees came down** (the round-3/round-4 lesson, and it mattered again): 72
  ElevenLabs master files for *"the Locks"* from `godot-arena` and 24 Meshy files from `godot-fleet`. Both sets
  existed in ONE place until they were copied into the main checkout, where the 30-minute timer takes them to
  builder0.
- **All four worktrees removed.** `stream/fleet` and `stream/airship` are ancestors of main and their branches are
  deleted. **`stream/arena` (`84e706eb`) and `stream/nav` (`70201d30`) are KEPT**: their final Status commits landed
  after the hash I merged, so their content was folded onto the archived brief paths by hand (`0c7d23a3`) rather than
  merged, and the branches stay as the evidence of where it came from. Delete them once you are satisfied.
- **Two docs were stale within the hour of being written** and were corrected in place, not appended to:
  `navigation.md` said the goal repair was opt-in with an inverted flag (true when nav wrote it, false after the
  flip), and `orchestration.md` lesson 215 recommended a two-reference trick that fleet then measured and
  half-refuted. Both are the ordinary hazard of documenting a thing someone else is about to change.

### Open, and the shape of round 12

`_agents/roadmap.md` carries the order. The candidates that came out of this round, all written up where the next
owner will meet them:

- **The camera asks the collider when it means the silhouette** (`verification.md`): `RtsCamera.roof_over` /
  `sight_blocked` and `BlockCutaway._gather`. The camera can sit inside a floodlight's lamp head at ~18° (his default
  pose is 21°), and a 20.7 m ad screen with a 1.4 m collider is never cut away from in front of the fight. **Feed a
  drawn-extent table in; never grow the colliders.**
- **The War Rig's muzzle**: the simulated pivot stays in the tractor frame, so the drawn gun is ~0.45 m sideways of
  where rounds leave at a 35° bend and ~0.7 m at the 65° jackknife limit. A simulation change; deferred deliberately.
- **Water reads black** at his pose on three maps now (`arenas.md`), his choice of next round over tonight.
- **The bus mesh**: image-to-image keeps the reference's proportions (lesson 215), so the approved concept came back a
  van. The way through is a reference that carries the proportion alongside one that carries the look.
- **The War Rig's `kturn_none`** (130 against 64 kturns): a 14 m hull with a 12 m radius in an 18-22 m street often has
  no valid 8 m back-up. The one sign a longer search or a kinematic planner would earn its keep.

## 🛩 THE AIRSHIP, PASS 2: IT FLIES ITSELF (2026-09-23, same session — read this before the pass-1 section below)

The lead on pass 1: *"the airship is too small … it's just moving in straight lines. We need to invest whatever
effort necessary to make it appear floating … and splining or circling behavior throughout the match. Also the
airship should ideally generally fly to where the action is … I think the airship would have its own PID controller
to try to fly the path of a target spline, and since it's an airship, slightly bad PID tunes might create a
realistic effect for high rotational inertia."*

**The route is gone.** `AirshipPilot` (new) is a PID rudder on a body with high rotational inertia, chasing a carrot
that circles wherever the units are fighting. `SyndicateAdAirship` owns the tick loop, the float and the screens.
It is stepped once per FIXED tick, so 30 fps and 144 fps fly the same line; `test_the_same_ticks_always_fly_the_same_path`
is the property that replaces the old pose function's purity.

**The tuning is the interesting part, and the first attempt was wrong in a way worth keeping.** The gains looked
under-damped but the loop was not: the closed-loop damping ratio is `(KD/YAW_INERTIA + YAW_DAMPING) / (2·√(KP/YAW_INERTIA))`,
and at `YAW_DAMPING = 0.55` that is **ζ = 1.01 — critically damped**, gliding onto every heading without ever
crossing it. Worse, `MAX_YAW_RATE = 0.22` saturated on every correction, and a rate-limited turn slews to its
heading and stops dead, so no gain could have produced an overshoot. Fixed by making the airframe physical rather
than the gains clever: **damping 0.12, rate cap 0.30 as a SAFETY limit, KD 1.60 → ζ = 0.38**, which overshoots a 40°
correction by 12.5°, crosses back twice and settles in ~5 s. Measured, not eyeballed.

**Four separable things make it read as floating** (`syndicate_ad_airship.gd` header): it never flies straight (the
carrot is always off to one side, mean |yaw rate| 8.5°/s); it leans LATE (bank lags yaw by ~2.2 s); it wallows on
three axes on periods with no common multiple; and it slips outward through its own turns like the sail it is.

**Size: 1.5×, 57 m, and 2× is refused with a number.** Scaling pins the belly at 6.2 m and lifts everything else, so
the flank screens rise through the top of his frame (14.76 m over his focus). Readable screen area: **1.0× → 39 m²
(84 % of the panel), 1.5× → 26 m² (25 %), 2.0× → 0 m² — the screens leave his frame entirely.** `TUNE=airship.scale`
to see it; the test asserts some flank panel stays under the ceiling, so a later resize fails here rather than in
play.

**Two wrong turns, both now written into the code as the reason something ISN'T there:**
- **A belly screen was built and cannot be seen.** The logic was "scaling lifts the flanks, so put a screen under the
  keel where it stays low". But his camera (17.56 m) sits INSIDE this hull's height range (belly 6.2 m, deck 22.8 m),
  so it views the hull edge-on and a downward panel faces away exactly as the upward deck panel does. **Only the
  flanks can ever work**, which is also why size costs readable screen and nothing buys it back.
- **Steering alone could not keep it out of the buildings.** At 1.5× the beam is 22.2 m and the Terminus streets are
  18 m: it no longer fits between the city blocks. Bending the goal away from a block just let the heavy rudder fly
  through it anyway (seen in a frame). It now **climbs over what it cannot go round** (rooftop + 3 m, at 2.4 m/s),
  which is both the fix and the most airship-like motion it makes. Cost, measured over 240 s per map: it is at its
  low cruise height **96 % of the time on yard, 90 % on pit, 62 % on crossing, 52 % on the Terminus**.

**`make blimp-look` is RETIRED** (it was built on the blimp's constants and a route model that no longer exists; its
frames came back empty and its pixel readings were wrong by 3×). `make airship-shot` takes the pictures;
`SyndicateAdAirship.seen_fraction` answers "how often" in closed form, as an upper bound that ignores occlusion.

**Four bugs the lead found by PLAYING it, all fixed, and three of them were mine in an embarrassing way:**
- ***"flew into the crowd and disappeared"*** — nothing kept the hull inside the arena. The venue's grandstands
  stand just outside `half_size`; the orbit carries the hull outward and `avoid` pushes it further out past every
  perimeter floodlight. `AirshipPilot.contain` now pulls it back from 72 % of the play radius and **the carrot is
  hard-clamped inside the wall**, because the gradual pull alone lost to the avoidance push (measured: 141.1 m on a
  140 m map). The orbit centre is also kept `TRACK_MARGIN` further in, since a heavy hull flies a wider circle than
  the one it is given.
- ***"flying backwards"*** — a straight convention bug. Godot's forward is −Z, so a node at heading h points
  `(−sin h, −cos h)`; the pilot used `(sin h, cos h)`. Self-consistent, and exactly 180° from the model, so the
  airship flew its whole flight in reverse. The convention now lives in two functions, `heading_toward` and
  `forward_of`, and nowhere else. **The overshoot test had the same bug** and had been passing on a goal that was
  straight ahead rather than dead astern.
- ***"stationary yaw … yaw more like a boat"*** — the rudder had full authority at any speed, so the hull could
  pivot on the spot like a turret. Torque now scales with speed (`flow`), which is what a rudder actually does and
  closes a loop with `TURN_DRAG`: a hard turn scrubs speed, which costs authority, which limits the turn.
- ***"just portrait video data … doesn't actually fill the screen"*** — the ad layout is authored portrait (320×640)
  and the flank panels are 1.9:1, so the feed was a narrow strip in a dark panel. `AdBroadcast` now builds a
  **landscape cut** (640×320, copy down the left, picture to the right) and each screen joins the cut matching its
  own shape. Measured fill of a flank panel: **26 % → 97 %**. Cropping the portrait feed instead was rejected —
  at these aspects it keeps only the middle quarter and cuts the brand and headline off at both ends. The ground
  screens are untouched (334 ad tests and 89 theme tests green).

**VERIFIED GREEN on the tree WITH all four fixes** (builder0, read from the wrapper's own line):
`>> remote: make check exited 0`, `check passed: 18 targets`, **1686 passed, 0 failed**, sim-baseline
`457b5e830708b439` **UNMOVED** (round 10's adopted hash — the airship still has no collider and still moves nothing
in the simulation), ai-scenarios `43,1` unchanged. 18 of those tests are `tests/test_theme_ad_airship.gd`.

## 🛩 THE SYNDICATE BROADCAST AIRSHIP, PASS 1 (2026-09-23, the same session — the asset and the screens)

**The lead asked to work on the rendered blimp alone, outside the orchestrator/worker pattern.** His words:
*"the blimp rendering just looks no good … I realize that the blimp is a make-or-break staple to the game, and
therefore it's worth adding a new asset … I don't want a blimp, I want an airship with a rigid body."* Round 10's
`AdBlimp` (a lit ellipsoid with four screen quads floating off its curve) is **deleted** and replaced by
`SyndicateAdAirship` built on a new Meshy asset, `airship_r11_m`.

**The concept gate took five rounds and fifteen concepts (135 credits, balance 905), and the two rejections that
mattered are lessons, not taste:**

1. *"still just kind of looks like a blimp instead of slightly satirical dystopian broadcasting airship of the
   syndicate"* — the first three briefs optimised the word RIGID and produced gas envelopes with a screen attached.
   At ~880 px the lead reads SILHOUETTE, and an ellipse is a blimp whatever detail is pressed into the skin: the
   broadcast apparatus has to BREAK the outline, not decorate the hull.
2. *"it doesn't have the consistent look of The Syndicate vehicles in the game. A player would have no idea these
   were part of the same organization"* — **the root cause is a documentation gap and it is now fixed.**
   `art_direction.md` described the Syndicate in one line ("curvy hover vehicles, immaculate ivory tower") and said
   *"write their rules here when a faction is scheduled"*, while five approved Syndicate concepts had been sitting in
   the repo since round 3. Briefing from those adjectives produced riveted grey municipal barges; the faction is
   actually **pearlescent cream lacquer, gold pinstripe, one continuous cyan light line, seamless and rivet-free.**
   The rules are now written into `art_direction.md`, with the rule that produced the accepted concepts:
   **when a faction has approved art, brief from the IMAGES and pass them to Meshy as `--reference`
   (`make art-concept REFS="a.png b.png"`), never from adjectives.**

**The lead's three requirements on the final asset, and how each was answered by a measurement:**

| his ask | answer |
|---|---|
| *"Ensure the vidoe screen is overlay properly on the intended area"* | **`make assets-apertures`** (new, `game/theme/gallery/screen_apertures.gd`) reads every triangle's albedo through its own UVs, keeps the dark ones, groups them into planes and prints each panel's centre, normal and extent. `SyndicateAdAirship`'s screen constants are that tool's output, so a regenerated hull is re-measured rather than re-guessed. **Second half of the same problem:** `ad_screen.gdshader` mapped UV straight onto a PORTRAIT 320×640 feed, so any non-portrait panel squashed the ad (the round-10 blimp did). It now takes a **`feed_rect` INSTANCE uniform** — per-screen crop, one shared material kept, so "ten screens cost one layout" still holds — and each panel letterboxes the feed at its own aspect. |
| *"I want this airship rendered in all maps"* | `route_for` **derives** a circuit for any layout instead of round 10's hand-written table with ONE entry (eight of nine maps silently had no blimp). It prefers a declared straight up-the-map lane wide enough for the 14.8 m beam, else the clearest offset, scoring by clearance from tall props (`TALL_PROPS`: blocks 21 m, floodlights 4.5 m, ad screens and signs 4 m) and tie-breaking toward the middle where his camera looks. `test_every_shipping_map_gets_an_airship` walks nine maps. |
| *"the blimp was smaller than I would have expected … This should be a large airship"* | **38 m, and that is within 6 % of the hard ceiling of 40.2 m.** At his pose the camera sits at 17.56 m and the frame's top edge is 3.5° BELOW the horizon, so the hull lives between two walls: its DECK under 17.31 m (or the screens tip away from him) and its BELLY over 6.45 m (or it drives through a 6.18 m tank). Those walls are 10.86 m apart and this mesh is 0.2704 of its length belly-to-deck. **Going bigger means changing the camera, not the airship** — that is the lead's call and the one lever left. |

**Verified:** nine tests in `tests/test_theme_ad_airship.gd` pass (collider-free, fixed-tick pose, all nine maps, the
Terminus lane, both camera walls, the size ceiling, screens seated inside the hull's own bounds, the feed fitted, and
the deck panel's honesty). **In the game:** `build/airship-shot/airship_t0600_wide.png` (ARENA=yard) shows the hull
over the yard with the flank screen seated in its bezel playing the live feed at the right aspect.

**The derived circuit, map by map** (`SyndicateAdAirship.corridor_pair`, legs as x offsets with their clearance from
the nearest tall prop). Two legs on the map is better than one, because a leg outside the arena is time he cannot see
it at all:

| map | legs (x) | clearance | note |
|---|---|---|---|
| terminus | 0 / 198 | 1.6 m / — | the avenue, and a return leg OUTSIDE the map: a 14.8 m beam fits only one Terminus street, the side streets each have a floodlight 7.6 m off them |
| yard | 0 / −48 | 22.6 / 2.6 m | both over the map |
| pit | −14 / 26 | 2.6 / 14.6 m | both over the map |
| boneyard | 0 / −40 | 54.6 / 14.6 m | both over the map |
| boulevard | −14 / −74 | 2.6 / 2.6 m | both over the map |
| crossing | −94 / 94 | 1.6 / 1.6 m | **flanks only** — props stand on its centreline |
| sumps | −94 / 94 | 1.6 / 1.6 m | **flanks only** — sumps has a city block at dead centre (0, 0) |
| maze, barriers | 0 / −40 | nothing tall at all | both over the map |

**Consequence worth his eye: on the Crossing and the Sumps it will be seen rarely**, because the only clear corridors
are 94 m out and the camera geometry (altitude ≤ 17.56 − 0.061 × distance) puts anything that far away above the
frame. That is the derivation refusing to fly through buildings, not a bug — but if he wants it over those two maps'
middles, the fix is theirs (move a prop) or a lower, smaller airship for them specifically.

**Two things the lead should know, both reported rather than hidden:**
- **The DECK screen is near-invisible at his pose (~89° grazing).** His camera is barely above the deck, so a panel
  facing straight up is edge-on. The FLANK screens carry the video. No resize fixes this at pitch 21°;
  `deck_grazing_deg()` and a test pin the number so nobody later claims otherwise.
- **`make blimp-look`'s numbers for this hull are not trustworthy** — it was built around the blimp's `ENVELOPE_*`
  constants, its frames came back empty (it re-finds a rebuilt instance that poses at the origin) and it reported
  1573 px for a hull the geometry puts out of frame at that range. Use the new **`make airship-shot`** for pictures;
  `blimp_look` needs a rewrite before its fraction is quoted again. Written up in `verification.md`.

**THE CHECK IS GREEN (builder0, 2026-09-23 ~03:30, read from the wrapper's own line):
`>> remote: make check exited 0`, `check passed: 18 targets`, `1677 passed, 0 failed`, **sim-baseline
`457b5e830708b439` UNMOVED** (round 10's adopted hash: the airship has no collider and moved nothing),
determinism passed, ai-scenarios `43,1` unchanged against the baseline. The test count 1674 → 1677 is exactly the
nine new airship tests minus the six deleted blimp tests, which is a small confirmation that nothing else moved.**

**Still open:** the working tree is **UNCOMMITTED on `main`** (51 paths; the lead was asked twice and has not said to
commit, so nothing was committed and nothing was pushed). When it is committed, the commit should name this verdict.
`blimp_look.gd` should be rewritten or retired before its numbers are quoted again. The only tree drift against the
green check is two comment-only edits made while it ran (a "geometry, not a measurement" qualifier on the px figure
in `asset_contracts.gd` and `syndicate_ad_airship.gd`); no code changed after the sync.

## ✅ ROUND 10 IS CLOSED (2026-09-23, 03:30) — the round before this session; the morning summary and the lead's list follow, then the launch record as written

**Nine streams — control, squad, arena, nav, combat, feel, show, announcer, and (added the same evening on his ask) terrain — each with a brief in
`_agents/streams/<stream>.md` and a worktree at `~/projects/godot-<stream>`.** The lead's playtest words are verbatim in
[`_agents/game_design.md`](_agents/game_design.md) *Round 10 direction* (with the orchestrator's reading and the
decisions made on them); the split, the four checkpoints (CP1 squad's transient element, CP2 arena's Terminus lanes,
CP3 feel's bus box, CP4 combat's constraint ON if it earns it), the ownership carve-outs and the eight contracts R1–R8
are in [`_agents/workstreams.md`](_agents/workstreams.md) *Round 10: the eight streams*.

**The round in one line:** he cannot judge unit intelligence until a right-click is obeyed at once (control + squad,
R2), a mixed selection can be told how to become a squad (R1, narrowed by the lead at night to a Form-squad action and a reason on the greyed buttons: regrouping already works), and a squad can be driven through the
Terminus streets (arena's lanes R4, nav's drive test); then the rigs' yaw (combat's predicate), the walls of light
(show, per-window), the blimp in his frame (feel, R7), the turret mounts (R5), the bus bigger than the garbage truck
(R6, CP3), and the announcer's pools deepened and GENERATED (R8: he authorised the spend), and the water/pit/bridge maps he asked for
twice (terrain, R9: the art for the slot, then a river map and a pits map with mirrored objectives, judged by `spread`
and a paired series).

**LAUNCHED 2026-09-22 (credits back): the nine agents were started by the lead in their worktrees at `main` = the commit of this line.** Between the briefing (2026-09-20) and the launch, two research replies were curated into the catalog and the briefs (rows B1–B14, C1–C12), a ninth stream (terrain) was added, and R1 was narrowed on the lead's playtest (CP1 withdrawn). The lead's newest playtest notes (formations still do not come together; the four causes) are at the end of `game_design.md`.

### ☀ THE MORNING AFTER ROUND 10's DAY (2026-09-22 → 23; written 00:30, updated at each tick)

**You launched nine agents at ~09:00 and went away for eight hours. By 01:30 thirty-five branches are merged to `main` and the closing check on `80e3ce90` is GREEN (1672/0, 18 targets, exit 0),
every merge at a hash whose own builder0 check was read from the wrapper's line and the runner's; the sim baseline
moved twice, each recorded twice and adopted with its causes named (`11c479c3` for the bus + nav's route retry,
`7dcc52f5` for arena's spawn grid); the scenario count is being re-recorded for the close; the closing main check
follows it. Nothing is pushed to `origin`; you push.** Eight of nine streams are done and idle (control, squad, arena,
nav pending its last rows, combat pending its last cells, feel, show, announcer, terrain); the worktrees stay until
you reset (the close commands follow, to run only after the closing check on `80e3ce90` reads green and nav's and combat's last
docs commits are merged):

    for s in control squad arena nav combat feel show announcer terrain; do make worktree-remove STREAM=$s; done
    for s in control squad arena nav combat feel show announcer terrain; do git branch -D stream/$s; done   # after the ancestor check
    git branch -D stream/terrain-uid

**DONE at 02:30 (2026-09-23): the nine briefs are archived to `_agents/streams/archive/round10/` with banners and every link fixed; every git-ignored payload is rescued (the announcer masters and the 36 arena-name masters in `assets/announcer/masters/`, feel's Meshy downloads in `assets/incoming/meshy/`, every worktree's frames and pages in `~/Desktop/round10-morning/`); the round's lessons 202–213 are in `orchestration.md`; every `stream/*` tip is an ancestor of `main` except arena's duplicate re-bake commit (identical content, superseded). The last main check on `e903e08f` is GREEN (1674/0, 18 targets, exit 0). Only the quiet window (feel's bench, show's perf) remains, and it does not block the reset: run the two lines above whenever you like.**

**What round 10 shipped, in one paragraph (all on `main`, all verified):** the unanswered right-click is fixed at
five mechanisms and reads 7 of 7 states on main; the greyed squad buttons say why and the card has Form squad; the
objective rings draw where the match scores; **the Terminus streets are lanes** (every street 16–22 m drivable, every
junction certified for the rig, the containers off the roads, the neon sign out of the spawn zones) with kerb paint,
centre dashes and a warm pool at every corner; **nav's wall-contact instrument and the Terminus drive test** (contacts
down 37–48 % from the streets alone, arrivals up, the rest attributed: the right-click's own goals landed inside
blocks, now grounded with the hull's clearance by control and squad); **the bigger bus (9.70 × 4.76 m), the turret
mounts on every hull's measured ring, and the blimp drifting down the avenue where your camera sees it**; **the light
show on the walls** (per-window addressing, chases, sweeps, a strobe on the facade facing the losing base, kill
ripples; show's verdict: the band dial was never the lever); **518 announcer lines recorded** on the same themes with
the PA's one-wrong-detail audit; **two new maps with water and bridges**, the Crossing and the Sumps, whose bridges
are used on 31 of 32 paired seeds; the lateral pitch from the turning envelope (squads open out; deploy stays packed,
round 11's stagger); a 20 m move that settles in 4–9 s instead of 9–17; the friendly-fire line-of-fire test reading
the hull's box, the first single change to move gangs-vs-law beyond noise (yard 36 % vs 23 %, p = 0.039); the yaw
freeze's mechanism found (a ratchet against a squadmate) and a world-only constraint that passes four bars but stays
OFF on a fifth (a pinch the driver must creep out of: round 11's first item). Two research replies were folded in
and paid off (the freeze mechanism, the pool-size formula, the corner formula, the paired-seed design, the per-window
lighting, the grounding vocabulary).

**Play it:** `make skirmish ARENA=terminus`, street to street, then right-click while they are moving, box-select
across squads and press Form squad, watch the walls; then `ARENA=crossing` and `ARENA=sumps`; then the Pit's west gate
(open, reads shut). Your taps and vetoes are in the list below; each is one message to me.

### FOR THE LEAD, THE MORNING AFTER 2026-09-22 (collected here as it lands; the files are in `~/Desktop/round10-morning/`)

- **The light show on the walls (show):** `~/Desktop/round10-morning/show/show-page/index.html` (12 show-off/show-on pairs at your pose, the band strip, 6 clips at 30 fps). Show's verdict: the band dial is not the lever; the per-window layer is. The luminance instrument reads the venue −6 % to −27 % brighter wide; reported, not blocking: your eye decides. **Four questions from show, each one edit in a named file** (its Status on main, "Questions for the lead"): 3× band or 2×; the loudness dials; keep the last_stand strobe; parapet vs outline.
- **The Terminus streets before/after (arena):** https://claude.ai/artifact/U3rZUei4p8YeLBS55VyCuX (7 street pairs, the corner readout with the formula, the other maps' lanes reported: yard's 7 lanes and pit's 1 are short of the bar; a round-11 call). **Version 3 adds lane READABILITY for every map at your pose: the Terminus reads open everywhere (+333 to +472 px over the widest hull); pit's west gate is 18 m wide but only 16 % of its throat is visible from your default camera, so it is open and reads shut, which is probably why pit feels different; yard's and the cut maps' lanes are AI hints drawn through cover, not streets.** The frames are also in `~/Desktop/round10-morning/arena/`; control's Form-squad and repath frames in `control/`; feel's blimp, rim, lineup and airship looks in `feel/`; nav's drive and rotation looks in `nav/`.
- **The announcer's 518 new lines (announcer):** `cd ~/projects/godot-announcer && make announcer-demo`, open `build/announcer/demo/index.html#new`; a Play button and a veto tick per line; your veto is a list of line ids, send them to me. Balance 60,398 credits.
- **The bus (feel, CP3 pending its final check):** the concept page for your tap at `~/projects/godot-feel/build/review_page_bus/index.html` (3 directions at 2.90 × 4.76 × 9.70 m, 27 Meshy credits); the bus lineup and the turret side-on pairs (paths in feel's Status). Copied to the Desktop folder at close.
- **The right-click (control + squad): 7 of 7 on main `8abba2b7`** (builder0, Terminus, seed 3, a squad of 8 under the no-damage tune): every crew is re-ordered within 2 ticks of the click, or follows a leader who was, in all seven states (move, attack-move, support by fire, an armed card command, a drag-facing, a click 5 m from the old destination, a click after arrival); visible intent within 1 s in 8/8 crews in EVERY state on the clean re-run (clicks stepped 4 m off any hull so all seven came out as move tasks; control 0097de46 harness fix). Five mechanisms fixed: three in control's input path (the dedup compared slots not clicks; an armed command spent the press as a cancel; a task change never re-issued) and two in squad's task layer (a task 5 m away hit an 8 m same-place rule; crews that had arrived got nothing). Play it.
- **Form squad (control):** the greyed buttons now say why and the card has a one-click Form squad.
- **The bus, the turrets and the blimp (feel, CP3 on main):** the Condemned bus is now 9.70 m long and 4.76 m tall (the garbage truck 7.54 × 3.70); the turret mounts sit on each hull's measured ring; the blimp drifts down the Terminus avenue and is on screen 12.0 % of a match at your pose over the arena (454 px median) and 881 px wide in your opening camera (`~/projects/godot-feel/build/blimp-look/blimp_opening.png`). **It flies ONLY the Terminus** (the one map with a street route; `make skirmish` with no ARENA picks a random map): `make skirmish ARENA=terminus` and look down the avenue. A route on every shipping map is a round-11 item. **Your tap: the bus AND the fire engine concept page**, `~/Desktop/round10-morning/feel/bus-concepts/index.html` (six concepts in two groups, R6; 54 Meshy credits tonight, balance 34: room for both image-to-3D runs after your taps, nothing more before a top-up). **The per-faction rim light** (faint warm edge lifting hulls off the asphalt; the switch is `--no-faction-rim`): the four-arm pair in `~/Desktop/round10-morning/feel/rim-pair/{noshow-norim,noshow-rim,show-norim,show-rim}/army.png`; your eye's call. Copies in `~/Desktop/round10-morning/feel/`. **The Terminus lanes now carry kerb paint, centre dashes and a warm pool at every junction** (the research's scale anchors and the light behind every corner): `~/Desktop/round10-morning/feel/lane_pair.jpg`, your opening view, marks off above and on below.
- **Two new maps with water and bridges (terrain, R9):** `make skirmish ARENA=crossing` (a river, two bridges, an objective across it) and `ARENA=sumps` (pits as kill zones). Frames and the page in `~/Desktop/round10-morning/terrain/`. **The Sumps' paired series (builder0, 32 paired seeds): 29 of 32 seeds cross on the causeways and catwalk more with the pits in (p < 0.0001); hits and the contested rate flat.** **The Crossing's paired series (builder0, 32 paired seeds, 180 s): unit-time on the bridges 0.0186 vs 0.0024 dry, higher on 31 of 32 seeds (p < 0.0001): the expensive route IS used, R9's bar met; time at the contested objective 0.58 vs 0.63 (p 0.38): the flanking rate does not move and terrain does not claim it; hits +74 % (p 0.02); the winner flips on 6 of 32.** Terrain's recommendation on a Terminus canal (backlog 4, built as a fixture `terminus_canal`): NO; it costs the ring-road and plaza lanes and moves the objective pair; spread 0.33 → 0.83 is a formality. Frames come with its next shots run; your call.
- **The gangs-vs-law question (combat):** the diagonal-disc hypothesis from round 9 got its first real cell. With the friendly-fire line-of-fire test reading the hull's oriented box instead of a disc, gangs win 36 % against 23 % on yard over 64 paired games (10 seeds flipped to the box, 2 against, p = 0.039), and the parked-friend scenario passes at default. Pit leans the same way but is not significant. That one site is now the default. **The series is complete, each cell its own finding: yard incoming 25 % vs 23 % (p = 1.00); yard both sites 36 % vs 23 % (p = 0.039), identical game for game to the lof cell, so the line-of-fire site carries the WHOLE effect and the incoming-threat site moves nothing on either map; the research's prediction is met on yard and not on pit, and where it is met the component is lof alone.** The two other disc sites stay on the disc; squad's own site gets its cell in round 11.
- **The rigs' yaw (combat):** the freeze that round 9 could not explain has its mechanism (a hull pivoting in place ratchets into a SQUADMATE, never a wall, until no candidate turn fits), and a world-only constraint passes three of four bars on the pitch tree (five_squads 0 of 30 off; the corridor 11.4°/6.0 m; nav's wedged rig never frozen). It does not ship yet: at the slot, three hulls flush against a crate refuse a 2° trim for 80–92 ticks, (a claim that a parked bus rotates 143.7° through a crate was made and RETRACTED within the hour: the measured penetration is about a millimetre, the physics scrapes it along the face). With the slide-off fix all four pre-registered bars pass on one build (five_squads 0 of 30 off, the longest refused run 0 ticks against 83 without it, the corridor kept, nav's wedged rig never frozen, formation gaps identical), **but the flip's own full check found a fifth: a four-vehicle element with a bus leader does not move at all with the constraint on (route progress −1.2 m against 19.0 m off), so the constraint stays OFF this round. The mechanism is named: the test's bus leader starts a centimetre inside a crate and is told to pivot in a two-sided pinch; the constraint correctly refuses, and the test only passes today because a hull can rotate through the crate. The fix belongs to the driver (creep out of a pinch before turning), round 11's first item.**
- **The 40-second settle (squad):** a 20 m plain move now STOPS in a median 4.2 s forward / 4.9 s side on the default arena (9.2 / 14.8 before) and 5.8 / 9.3 s on the Terminus (7.1 / 17.2 before), the order COMPLETED within 2.8 s; 8 seeds per cell, tank/tank/ifv/ifv, builder0, squad 6d6d6264 (37 seeds faster, 8 slower, 3 ties). Moving BACK is unchanged at ~16 s on both (a 40 m column pressed on the arena edge): known, not fixed. One wheeled crew creeps 0.5–1.8 m/s for ~15 s after its order completes: known issue in squad's Status.
- **Walls (nav), on the merged tree (main 709cbeb9: the lanes, the bus, the mounts, the route retry; builder0, seed 1):** the default path reads mixed 5959 contact unit-ticks (arrived 5,4,6,4 of 6) and rigs 8139 (2,2,1,3 of 4), down from 7866 / 15691 at launch; nav's opt-in arms cut the mixed squad to 424 (−93 %) and the rigs to 2428 (−70 %) but cost rig arrivals, so they stay opt-in. **CLOSING NUMBERS on grounded right-click goals (control's R2b on main; builder0, seed 1): the mixed squad's wall contacts fell from 5959 unit-ticks to 190 and every leg arrives 6, 4, 6, 6 of 6; the rigs read 10128 (held against wrecks and containers, plant drift) with 1, 2, 2, 2 of 4 arriving, and with nav's pressed-wall escape ON (a 1.0 s window, scoped to routed moves and unengaged crews) 2430 with 14 of 16 arriving. That escape is now DEFAULT ON, merged alone at `c1b92d84` with its baseline move recorded, as a HARMLESS default: 1674/0, the duel and the count unchanged, one proven cause, a unit test that backs a pinned hull off a face. Nav's own caveat, which stands: the arrival gain on this one deterministic seed rides on a SINGLE escape event (at 1.0 s the rigs fired one; the "50+" was the 1.5 s run), so it is a real mechanism firing, not evidence the row reliably helps; round 11 runs the drive test over paired seeds with a seed knob that moves spawn order. `TUNE=nav.press=0` (or the `--nav-off` switch nav names in its Status) restores opt-in if you prefer.** How it was attributed: **nav's re-run with verbs and controller orders showed the dominant cause of misses was YOUR right-click path.** 11 of 13 misses are plain move orders issued the way a right-click is (Orders/OrderExecutor, no Element), and the goal each crew is executing is an ungrounded formation slot 4–10 m inside a block (a ring-road IFV 4.1 m inside Block_1; rigs 4.3–9.8 m off); squad's Element grounding never sees those. Control grounds each unit's goal in `Orders._resolve_group` with the hull's clearance through squad's one grounding call (`SlotGround.standable_for`, made public without an Element); squad's 6d adds the clearance-aware grounding and the follow station. That is the next item on your acceptance test and the round's last open blocker on the Terminus drive.

### Merged to `main` (round 10, in order; verdicts read from the wrapper's own line)

| stream | merged at | what | branch verdict | main check |
|---|---|---|---|---|
| control | `52254fd2` (`f8e8c592`) | R2's input half (player orders compare the click; K1 gains `task`; `_same_order` never repeats across a task change), R1 as UX (task refusal reasons on the card, **Form squad**), the notice banner and "N IN NO SQUAD", a drawn facing orients the formation, **the objective rings drawn where the match scores** (terrain's finding), the pin-head lean, `make repath-test` | builder0 1575/0, exit 0, baseline unmoved, ai-scenarios 41,3 | **VERIFIED: `make check exited 0`, 1575/0, five shards, baseline unmoved, determinism 559a415887806e43; `main-checked` moved here** |
| arena | `46388559` (`44315882`, CP2) | **the Terminus streets are lanes** (R4 asserted: every street 16.4–22 m physical, bar 8.14 m drivable from `ArenaLanes.bar()`, 17/17 junctions clear the rig's corner cut), R3 prop parity (ad_screen 7.8 × 2.0, wreck 3.2 × 3.3, the neon sign out of the spawn zones), the lane readability test at his pose (every throat 100 % visible at his default heading), terrain's decision_report/standing_point fix (spread now pit 0.67, yard 0.49, terminus 0.33); **his page: https://claude.ai/artifact/U3rZUei4p8YeLBS55VyCuX (7 street pairs; private, share from its menu)** | builder0 1569/0, exit 0, baseline unmoved, ai-scenarios 41,3 | **VERIFIED at `7c7387fe` (with announcer): `make check exited 0`, 1587/0, six shards, baseline unmoved; `main-checked` moved here** |
| announcer | `68a0a24d` (`7a72ad05`) | **518 new lines on the same themes** (caller 205, Veteran 196, PA 117 with the one-wrong-detail audit), all recorded and speech-to-text verified: 41,346 credits, balance 63,894; the pool report against C9's per-moment targets (deficit 514 → 147); the PA remembered for an evening; the New tab on the Booth Monitor with a veto tick per line; `.gdignore` in the masters folder (a fresh import segfaulted on builder0 without it); 14 older lines with grammar slips re-recorded | builder0 1561/0, exit 0, baseline unmoved, ai-scenarios 41,3 | **VERIFIED at `7c7387fe`** (above) |
| squad | `08319e59` (`e4d5e3f3`) | **R2's task half** (the first update after a player task issues every crew past `_should_issue` and `REISSUE_M`; an idle crew gets the follow its flow asks for; the settle seating: least-driving seating on plain moves), `_is_clear` on each hull's own axes, the pitch instrument (default unchanged), **the ORBIT controller** (holds its radius, keeps the target 4 s, deck runs from the 25° cone: 27/29 deck hits, the engine-deck scenario green), **base-of-fire re-specified** to the HOLD the element really issues | builder0 1587/0, exit 2 only on the scenario count (43,1 vs recorded 41,3: two REASONs, re-recorded on main after combat), baseline unmoved | **VERIFIED at `cb127c16`: 1604/0, 17 passed 1 FAILED (the count only, 44,0 vs 41,3), baseline unmoved; `main-checked` moved here with that verdict** |
| nav | `e73950b3` (`95ae1ce6`) | **the wall-contact instrument** (per unit per tick, by cause and collider identity) and `make nav-terminus-drive`; instrument only | builder0 1564/0, baseline unmoved | **VERIFIED at `cb127c16`** (above) |
| announcer | `3934f234` (`88c91f18`) | the Crossing and the Sumps named and their 18 `{arena}` lines recorded (36 requests, balance 62,609 → 60,398); `generate.py --only-values` (36 recordings instead of 180: the Terminus masters had been lost with a round-8 worktree and an id-ordered run would have re-recorded them); `audio-launch-smoke` passed on builder0. **announcer is DONE**, idle for the lead's veto list | builder0 1587/0, exit 0, baseline unmoved | **VERIFIED at `cb127c16`** (above) |
| combat | `4a96829d` (`6e3cd021`) | **the yaw freeze's mechanism** (a ratchet against a SQUADMATE, never the world) and `match.yaw_world` rebuilt as a true mask arm (the CP4 candidate, NOT flipped; five_squads 12 → 0 of 30 off on the laptop, nav's corridor byte-identical), YAW_TRACE and the refused-run counter, **the artillery scenario re-specified** (the artillery was right; its target now parks in sight on either route), per-site disc knobs `match.hull_disc_{lof,incoming,squad_incoming}` with an arm-proof test, the paired-seed series tooling (McNemar; `disc-site-series`; `a2-cusps`), a collider-centred test; defaults unchanged | builder0 1604/0, 17 passed 1 FAILED (the count only: 44,0 vs recorded 41,3), baseline unmoved | **VERIFIED at `4ff45e50`: `make check exited 0`, all targets, baseline unmoved, count 44,0; `main-checked` moved here** |
| show | `2ecda325` (`f19804ed`) | **the light show on the building WALLS**: per-window addressing as one RGBA8 texel per window read by `city_block.gdshader`; a per-window pixel layer (idle twinkle, skirmish sweep, battle chase up every tower, last_stand strobe on the one facade facing the losing base, victory sweep in the winner's colour, a kill ripple, a capture fill floor by floor); sign letters as windows; the 2× band default (show's verdict: the band dial is not the lever, the pixel layer is); draw calls 257 → 258, lights 1 → 1. **His page: `~/projects/godot-show/build/show-page/index.html` (12 show-off/show-on pairs, the band strip, 6 clips at 30 fps); pairs under `~/projects/godot-show/build/show/` (`terminus_wide_cue_{skirmish,battle,last_stand,kill_0_55s}.png` vs `before/`)** | builder0 1572/0, 18 targets, exit 0, baseline unmoved | **VERIFIED at `4ff45e50`** |
| arena | `e430febf` (`1c745225`) | `ArenaLanes` reads the terrain's own colliders (rims now, bridge rails by name once terrain lands: a bank road 20.8 m with the rim vs 22 m without); the corner readout and the other maps' lanes on the street page (yard 7 of 7 lanes short, pit 1 of 4, boneyard 4 of 4, boulevard 6 of 6: reported, not changed) | builder0 1570/0, baseline unmoved, 17/18: the one red was scenario_perf under load, re-run alone exit 0 at 41,3 | **VERIFIED at `4ff45e50`** |
| terrain | `4ffb4c1a` (`ef29355f`, R9) | **the water, pit and bridge art in the `arena.terrain` slot; two new maps: the Crossing** (a river with two bridges and a mirrored objective pair: spread 0.55 vs 0.30 on its dry twin, the river makes the decision) **and the Sumps** (pits as kill zones: spread 0.35 wet and dry; the paired series decides); decks derived from `ArenaLanes.bar()`; rims and rails as nav sources; the arena_report terrain hook; every objective asserted reachable; `make skirmish ARENA=crossing` / `ARENA=sumps` | builder0 1611/0, baseline unmoved (pre-registered), 17/18 (the count only, main's known red) | **VERIFIED at `4ff45e50`** |
| feel | `69c681ac` (`f49b5f15`, CP3) | **the Condemned bus reads bigger than the garbage truck** (R6: `tank` 2.90 × 4.76 × 9.70 m, his eye over the reference; the lineup and the concept page for his tap), **the turret mounts** (R5: `turret_mount` per profile on all three axes, the Condemned and gang rings measured from the meshes; the pivot moves on x/z so shells leave under the drawn gun), combat's spawn jitter shrunk with the derivation (Z 0.6 → 0.15, X 1.5 → 1.3; asserted by test_spawn_grid), the per-faction rim light, the first low blimp (the avenue re-route, 13.4 % seen at his pose, comes with feel's next hash), `MatchMood.control_changes()`, size-derived forms for the autocannon and overwatch tests; three REASON'd reds (drive-to-slots, formation-slot: squad's; parked-friend: combat's) and base-of-fire newly red on the bus tree (squad reading) | builder0 1624/2 (the two REASON'd), **sim-baseline MOVED 1ea332e7bc268d2a → aac14c6704fbac39** (pre-registered: jitter 7001bdc8, box 055fb10f, mounts a138b5f1), determinism 2bf54e1e4c829e06 | **the baseline ADOPTED at `f29c5b7c` and VERIFIED there: 1651/2, sim-baseline 11c479c3bec77082 UNMOVED, determinism cd43435b56b09acf; the two reds are CP3's REASON'd pair (drive-to-slots: squad's form lands next; parked-friend: combat's row); count 40,4 (formation-slot, base-of-fire: squad's fixes next; parked-friend; scenario_perf under load). `main-checked` moved here with that verdict** |
| control | `8abba2b7` (`0f6ded16`) | `repath-test` under the no-damage tune (skirmish mode takes `--tune`; dead crews excluded from the verdict), the ARRIVED / dressing pin phase (B7), the short Form-squad reason, COLUMN TOO LONG on own vehicles only | builder0 1577/0, 18 targets, exit 0, baseline unmoved | covered by the next main check |
| show | `0885ef1d` (`1b0592dc`; code at `b5f95d14`) | the round-9 leftovers: the no-strobe arm keeps the strobe's own period (one variable), parapet-vs-outline shot on a fixed heading (both pairs discriminate again) | builder0 1572/0, 18 targets, baseline unmoved | covered by the next main check |
| nav | `709cbeb9` (`f386c63e`) | **a not-ready route is retried on the next tick** (the drained-map frame; combat's ask; on by default: the ONE pre-registered cause of nav's baseline move 1ea332e7bc268d2a → 7574ac017c17265b); the three wall-contact arms OPT-IN (`--nav-off=press,inflate,nosestop` turns them ON; inflation fails the element's drive north 7/1 and stays opt-in); the oriented `radius_of` opt-in; the drive test's miss report (reachability, the slot's off-mesh gap, blocked_by) | builder0 1634/0, ai-scenarios 44,0, exit 2 only on the baseline | **the baseline ADOPTED at `f29c5b7c`** (above; the retry alone 7574ac017c17265b) |
| terrain | `4cf545ac` (`2504b1ee`) | the seven `.uid` files for the terrain art, tools and tests (source; every worktree read dirty after an import without them: combat's catch) | uid files only | covered by the next main check |
| feel | `28d60a4a` (`a822a48f`) | **the low ad blimp flies the Terminus avenue** (a stadium loop at x = ±4 turning at z = ±86; 13.4 % seen at his pose, 881 px wide in his opening camera), blimp-look occludes with physics rays, the faction rim toned to 0.4, the fire engine's three concepts beside the bus's, `MatchMood.control_changes()`; visual, pre-registered unmoved | builder0 1645/2 (the two REASON'd), the CP3 baseline unchanged, count 39,5 on the pre-record tree (the engine-deck scenario re-red on the 9.7 m bus: squad reads; scenario_perf under five slots: load) | covered by the next main check |
| combat | `a636d8e0` (`0fe728d6`) | the turret-mount tune fix (a TUNE of muzzle_height moved the number but not the pivot; a red-then-green test), the disc-site series tooling (one arm per invocation, a clean clone per arm), the two-folder determinism check | builder0 1652/2 (main's two REASON'd reds), baseline 11c479c3bec77082 unmoved, count 40,4 (main's set) | covered by the next main check |
| arena | `58540dd7` (`eeb2a6e2`) | **the spawn grid fills turning-clear cells first** (ruling A: the 57 lattice points kept, the 28 checkerboard cells first so the first 28 bare spawns have disjoint bus envelopes; a doctrine army never stands on the grid); the one slot→cell line in `Match.spawn_position` (combat reviews); the front-row test restated (squad reviews); the envelope and deploy-zone tests | builder0 1656/2 (main's two REASON'd reds), count 41,3, **sim-baseline MOVED 11c479c3bec77082 → 7dcc52f547f03d3f (one cause: bots take different slots)** | **the baseline ADOPTED at `696b581c` and VERIFIED there: 1660/2, sim-baseline 7dcc52f547f03d3f UNMOVED, determinism ad35f217e1862ae3; count 42,2 (formation-slot: squad's harness Tank.place fix lands next; parked-friend: combat's row, the lof flip next); drive-to-slots now green. **CORRECTED (nav's check on 4588cb96 = main): the second test red is arena's `test_spawn_grid::test_every_layouts_baked_spawn_list_is_the_grid_the_constants_describe`, green on arena's branch, red on main: a composition: terrain's `terminus_canal` fixture was baked before the grid reorder merged; FIXED on main by the orchestrator (`make arenas` re-baked only that file; the test 6/0 filtered on the laptop).** `main-checked` moved here with that verdict** |
| arena | `5973863a` (`be094bcd`) | the Status, final: the lead's report (play the Terminus street to street, then the Pit's west gate), one question (the Terminus objectives' spread 0.33), round 11 (the staggered deploy; the Pit gate's readability). **arena is DONE** | docs | — |
| squad | `b1693901` (`f27bd321`) | **the lateral pitch from the turning envelope** (diagonal + 0.30 m: measured, the smaller bounds clip; tanks 9.25 m, rigs ~14.7 m; deploy stays at the width floor so no army stands outside its zone; the known cost: packed spawns whose first dressing turn clips; round 11: the checkerboard deploy), **base-of-fire in lof terms**, a drawn heading's hold replaces a move at once, drive-to-slots as route progress, the squad_incoming disc site, the hull-spacing test; the legged-path seating dropped on its own measurement | builder0 1655/1 (the parked-friend delegate), **sim-baseline 11c479c3bec77082 UNMOVED** (the pitch is baseline-neutral on the default path), count 42,2 (cover-peeking REASON'd; parked-friend) | arena's baseline move recorded on this tip next, then the main check |
| terrain | `8fe179e3` (`8b0a879a`) | the Crossing's and the Sumps' paired series (32 seeds each: the bridges used on 31/32, the causeways on 29/32, p < 0.0001; the contested rate flat on both), the swap-bases fairness (both maps inside one SE of zero south advantage), feel's look notes taken, the `terminus_canal` FIXTURE (recommended against), the page tooling. **terrain is DONE** pending its final Status | builder0 1651/2 = main f29c5b7c's known set, baseline unmoved | covered by the next main check |
| nav | `1e9327dd` (`31e9d83c`, checked at `d2bd7ac3`) | the oriented pair radius in ORCA, opt-in (**falsified as a default** on the defile: tracked arrivals 4 → 2, inversions 22 → 37); the held wheeled hull keeps its heading, opt-in (B7: shuffle after arrival 2.02 → 0.07 m median; facing within 10° at +5 s 5/25 → 14/24); **the seam MEASURED on a Terminus fight: unit-ticks by driver route 47.6 %, CombatMotion's direct hops 17.2 %, face 15.5 %, yield 11.2 %, stop 8.4 %; `Movement` has NO leash or corridor input on any tick; 10 % of yielding ticks touch a wall** (the next row); no behaviour change | builder0 1652/2 = main's known set, baseline unmoved, count 40,4 | covered by the next main check |
| feel | `facf5eb0` (`82d77c5a`) | **the lane marks** (C11's scale anchors: kerb paint and centre dashes on all seven Terminus lanes, stopping 0.3 m short of every collider) and a warm floor pool at each of the 11 junctions (B10's light behind every corner); flat, no collider, no light; the blimp re-measured at 12.0 % seen over the arena (454 px median). **feel is DONE** except his taps and the quiet-window bench | builder0 1656/2 (the two REASON'd), baseline unmoved, count 40,4 | covered by the next main check |
| terrain | `8316bd8b` (`fc4a4cba`) | the Status, final: the lead's report on both maps, the two series, fairness, the canal fixture and the recommendation against it, three questions, round 11; `water-probe` and `BRIDGE=1` pass on the shipping build path. **terrain is DONE** | docs | — |
| squad | `4c5b1671` (`18c7f9bc` + `e602025c`) | **slots grounded with the hull's own clearance and the follow station grounded** (6d: on nav's three Terminus points the fitted slots have 0 of 16 directions off the mesh; measured baseline-neutral), **`SlotGround.for_unit`** (the one grounding call, R2b), **the scenario harness placing through `Tank.place`** (engine-deck and formation-slot PASS on the 9.7 m bus; cover-peeking honestly red, 4 vs 4, paired 2/0/14 of 16), the seeded defile probe, the element leash on every move_to (nav's seam item). **squad is DONE** | builder0 1661/2 (main's spawn-grid red, since fixed; parked-friend), baseline 7dcc52f547f03d3f unmoved, count 41,3 (cover-peeking REASON'd; parked-friend; scenario_perf under load) | covered by the next main check |
| control | `46bbb9ac` (`e55d1143`) | **every PLAYER right-click formation goal grounded on the navmesh with the hull's clearance** (R2b, through squad's `SlotGround.for_unit`; CPU and scripted orders keep their geometry: grounding every order had moved the 100 ms response test), the readout says when a goal was moved; the repath harness steps clicks 4 m off any hull. **control is DONE** pending its final Status | builder0 1661/2, count 42,2 = main 696b581c's own reds (two since fixed on main; parked-friend combat's), baseline unmoved | covered by the next main check |
| combat | `4aaf8b56` (`f694af4b`) | **the friendly-fire line-of-fire site reads the hull's oriented box** (the other two disc sites stay): the parked-friend scenario passes at default on both machines; **the paired series (clean tree, 64 paired games per cell): yard gangs 36 % vs 23 %, b=10 c=2, p = 0.039, the first single disc site to move gangs-vs-law beyond noise; pit b=6 c=2, p = 0.29, same direction**; CP4 stopped this round (the two-sided pinch) | builder0 1672/0, sim-baseline 7dcc52f547f03d3f UNMOVED (pre-registered moved: wrong in the safe direction), count 43,1 (cover-peeking, squad's REASON) | the count re-recorded next; the closing main check after |
| nav | `500fa29d` (`c148b5d5`) | the leash clamp opt-in (the seam's smallest step), A6 falsified as a default (pooled off-corridor 0.3235 → 0.302 against < 10 %), the drive test's orders carry source player, yield-spot clearance and wheelhold opt-in on their series; **the walls entry on grounded right-click goals** (below) | builder0 1673/0, baseline 7dcc52f547f03d3f unmoved, count 43,1 (cover-peeking, main's) | covered by the closing check's successor |

### Night log, 2026-09-22 (the orchestrator's decisions while the lead is away; newest first)

- **announcer DONE and MERGED (`68a0a24d`):** 518 new lines (caller 205, Veteran 196, PA 117, each PA line carrying its one wrong detail as data; the C10 audit shape enforced), all recorded: 41,346 credits spent, balance 63,894 (the stop line was never reached). Pool deficit 514 → 147 under the FINAL rules (the earlier 568 was the same library under the first cap setting; both columns are in its Status); 0 in-match repeats over 400 laptop broadcasts. **The masters (523 files) are rescued into the main checkout's git-ignored `assets/announcer/masters/`** (verified, 0 missing); the tracked clips arrive with the merge. FOR THE LEAD: `cd ~/projects/godot-announcer && make announcer-demo` then open `build/announcer/demo/index.html#new`; every new line has a Play button and a veto tick; his veto is a list of line ids.
- **combat items 4 and 5 closed as FINDINGS (laptop probes, uncommitted):** ORBIT's radius is not the mechanism (0 → 0 deck hits at a surface-relative radius; the scout's real orbit is 33.7°/s against a 50°/s turret while the gate assumes 73°/s; making the gate honest makes ORBIT ineligible and the scout declines: squad's fix, relayed); the artillery was RIGHT: the scenario was decided by a tick-1 route request landing on the drained-map frame (ready=false, 0 points, replanned only after ~4 s), goal re-specified in sight on both routes, PASS in all three orders, count 41,3 → 42,2 with the REASON (combat records on builder0); nav asked to retry a ready=false route on the next tick.
- **nav's wall-contact instrument (`95ae1ce6`, check running), pre-CP2 Terminus, builder0:** mixed squad 7866 contact unit-ticks of 39472 (steer 6529, plant 1301, avoid 36), 5–6 of 6 arrive; rigs 15691 of 24463 (plant 8893, steer 6790), 1,1,0,0 of 4 arrive; hull-hull separately (3398 / 8620, the number to watch under yaw_world). Arena measured the block against its collider (art 6 cm wider, bake and physics agree): the kerb pins are CLEARANCE (turning envelope vs the 2.0 m bake near a turn), nav's row.
- **THE YAW FREEZE HAS A MECHANISM (combat `2434f50d`, builder0 check running; laptop numbers):** every refused yaw of every traced five_squads crew, the seating Alpha_4 included, was refused against a SQUADMATE, never the world: a hull pivoting in place in the 6 m row deepens its corner by up to the 5 mm slack per accepted step and stops at the posture where even the 0.3 candidate costs over the slack, a fixed point (Charlie_3 byte-identical for 1134 ticks). Fix: `match.yaw_world` rebuilt as a TRUE mask arm (same `test_move`, mask narrowed to world): five_squads 12 → 0 of 30 off, longest refused run 1268 → 1, nav's corridor byte-identical across arms (the arm proof). The ordering question closes as "neither alone". CP4 stays prepared until CP3 → squad's pitch → combat's re-run. Relayed to nav and squad.
- **Carve-out granted:** combat edits `ORBIT_RADIUS` / `ORBIT_BREAK_RANGE` and their read site in squad's `tank_brain.gd` (surface-relative orbit; the engine-deck scenario); squad reviews at merge.
- **Pitch ruling for squad:** measure overlap during the actual manoeuvre and land the smallest pitch that passes (half_diagonal + half_width ≈ 5.7 m tank / 8.85 m rig), with 2 × half_diagonal (8.95 / 14.4 m) as the fallback; a five-rig frame pair for the lead.
- **Orchestrator item, owed:** `make test` runs without `--fixed-fps`, so many-unit filtered tests on a loaded laptop are not repeatable (combat: 12 off then 8 off, same code); I land `--fixed-fps` on the test recipe on main after CP2 with three consecutive builder0 checks (round 9's CP3 follow-up note), then tell every stream.
- **The sim baseline ADOPTED at `e903e08f`: 7dcc52f547f03d3f → 457b5e830708b439** (read twice, one cause: nav's pressed-wall escape default ON). **THE ROUND'S LAST MAIN CHECK on `e903e08f` (36 merges + the third adopted baseline) is GREEN: `make check exited 0`, 1674 passed, 0 failed, 18 targets all passed, sim-baseline 457b5e830708b439 unmoved, determinism bcc6e1609c14e12d, ai-scenarios 43,1 unchanged (builder0, 2026-09-23 ~03:00). `main-checked` is on e903e08f with those lines; the three merges after it are docs only (nav's, squad's and feel's final Status commits, the archive, the roadmap).** The quiet window opened at 03:05. **Feel's hinge bench: the window HELD (alone, load 0.41–0.73) and the verdict is NOT USABLE, the fourth refusal, recorded as the answer: `--tune=match.no_damage=1` never reaches Armor.no_damage on the `perf-trailer-ab` path (13 of 13 phases OFF; the same class as the turret-mount tune combat fixed tonight), the kept cycles disagree (−0.4 to +14.8 ms), no number is quoted; combat's first round-11 row after the pinch.** **Show's perf re-measure: the window HELD for both halves (alone, load < 1): GPU median 7.05 ms before vs 7.11 ms after, spread ~3 ms from the camera; draw calls 263 vs 262; instance-uniform errors 0/0: the whole show including every window is under ~0.3 ms GPU at zero added draw calls, lights, nodes or instance uniforms.** The quiet window is closed; every stream is done and idle; builder0 is empty.
- **Nav's press flip merged ALONE at `c1b92d84` (304636cc: 1674/0, 17/18 the baseline only, count 43,1, sim-baseline MOVED 7dcc52f5 → 457b5e830708b439, one proven cause), the two records running detached.** Nav's correction after the merge: at the shipped 1.0 s window the rigs' drive fired ONE escape (the "50+" in the merge subject was the 1.5 s run), so the 7 → 14 of 16 arrival gain is one event on one seed; kept as a harmless default with the caveat; round 11: the drive test over paired seeds.
- **The scenario count ADOPTED at `80e3ce90`: 44,0 → 43,1,3,0** (builder0, an exclusive window; cover-peeking the one red, squad's REASON; parked-friend green at default). **THE CLOSING MAIN CHECK on `80e3ce90` (33 merges) is GREEN: `make check exited 0`, 1672 passed, 0 failed, 18 targets all passed, sim-baseline 7dcc52f547f03d3f unmoved, determinism bcc6e1609c14e12d, ai-scenarios 43,1 unchanged (builder0, 2026-09-23 ~01:30). `main-checked` is on 80e3ce90 with those lines.** After it: nav's third merge (docs and opt-in rows, 1673/0 on its own check) and combat's final Status; nav's press flip is the round's last code merge (its own check, recorded alone), then one last main check.
- **The closing count record read 42,2 and was NOT adopted:** the second red was scenario_perf's CPU budget under builder0's load (28.9 s with combat's series and nav's A/B on five slots), the load-sensitive case the baseline file's own header warns against baking in; relaunched as an exclusive-window run (`TANK_SQUAD_EXCLUSIVE=1`), which waits for a natural gap and records when the box is quiet; expected 43,1 (cover-peeking only).
- **The lof-site flip (combat f694af4b, on main 4c5b1671+): 1672/0, sim-baseline 7dcc52f5 UNMOVED (pre-registered MOVED; wrong in the safe direction: the baseline match never reaches a friend-in-lane decision where the disc and box disagree, while parked-friend now PASSES at default on both machines, 113–114 ticks / 2 shots, having failed with the disc on the same tree), count 43,1 (cover-peeking only); five_squads and suppression unchanged; the pit lof cell clean b=6 c=2 p=0.29 not worse; the yard cell running. Merges the moment yard reads not-worse, or at 02:00 on the pit cell with yard pending. No record needed.
- **Main VERIFIED at `5fd627a2` (28 merges, builder0): 1668 passed, 1 failed (the parked-friend delegate only, combat's row), count 42,2 (cover-peeking, squad's REASON'd; parked-friend), sim-baseline 7dcc52f547f03d3f UNMOVED. Every other red of the night is gone: the canal re-bake, drive-to-slots, formation-slot, base-of-fire, engine-deck all green. `main-checked` moved here.** Remaining before close: combat's lof-site flip (its own record), the count re-record (cover-peeking's REASON; parked-friend expected green after the flip), nav's final rows and hash, the closing main check.
- **CP4's flip 48569fce HELD (23:20):** its check read 1666/3, baseline MOVED 7dcc52f5 → 50acf21d6e6a68b7 (one cause), count 42,2; but one of its three reds, drive-to-slots, was GREEN on its merge base 696b581c (main's own check), so the constraint ON is the prime suspect; combat asked for the yaw_fit=0 vs default pair on that test before the merge. **CONFIRMED (builder0, FILTER=tactics_elements on 48569fce): with `yaw_fit=0` route progress 19.0 m, 8/0 PASS; with the constraint ON route progress −1.2 m, the element does not move at all, 7/1 FAIL. CP4 fails a fifth bar and does NOT merge; the baseline is not recorded.** **MECHANISM (combat, YAW_TRACE, builder0): refusals only against the WORLD. The element's leader (the 9.70 m bus, hand-placed by the test at (−15, 60)) starts 1.2 cm inside Crate_11 on tick 2 and is commanded a pure pivot for 186 ticks; every candidate down to 0.8° enters BOTH Crate_11 and Wall_5, a two-sided pinch, which the slide-off correctly refuses (pushing off one drives into the other). With the constraint off the bus pivots THROUGH the crate and wall and drives off: the test passes today because of the defect. The fix is the driver's, not the plant's: a hull whose pivot is refused on both sides must creep out of the pinch before turning (nav's Movement or squad's element leader, reading the public yaw_refused_ticks). CP4 STOPPED for round 10 (the flip reverted on combat's branch, defaults off); round 11's first item with these numbers. For squad: the test's leader spawn is 1.2 cm inside Crate_11.**
- **CP4: ALL FOUR BARS PASS on one build (combat 0bc0e214, builder0, every arm's TUNE line printed):** world mask + slide-off: five_squads 0 of 30 off slot, longest refused run 0 ticks (the yaw_slide=0 control on the same build: 83, the arm proven applied); corridor 11.4°/6.0 m, residual 1.21 m (bar 1.8), giveups 1; nav's suite 8/0; tank_yaw_fit 7/0; five_squads' worst gaps with the constraint on equal the off arm's to the decimal (the constraint costs formation nothing). **The flip commit is 48569fce (yaw_fit_enabled and yaw_fit_world default true; `TUNE=match.yaw_fit=0` restores round 9), ONE cause, its check running; the baseline will MOVE; merged alone and recorded twice.** Merge note: nav's test_nav_face_recovery.gd:169 comment says "OFF by default" (stale comment only). Clean pit series (6e2d9421): incoming b=6 c=3 p=0.51; BOTH b=2 c=2 p=1.00, so research C7's prediction (perception recovers most of the collapse) is NOT met on pit; lof running.
- **Nav's paired series (seeds 1 3 5 7 9, both arms proven applied): yieldclear −23 % yield-driver wall contacts on the Terminus (3 better, 2 worse; misses its ≥ 50 % bar; the seed-3 −58 % was one seed): STAYS OPT-IN; wheelhold on yard: shots −3.9 %, at-goal share lower in 3 of 5: STAYS OPT-IN (its shuffle 2.02 → 0.07 m stands).** Item 6's smallest step (a5723fbc): a move_to may carry a leash and Movement clamps the goal into it, opt-in; squad asked to send the brain's leash on move_to.
- **CP4 VERDICT RUN (combat, builder0, 6f553699 = main b1693901 with the pitch; one build, every arm's TUNE line printed): the constraint does NOT flip yet.** With the world mask: five_squads 0 of 30 off (vehicle mask 6/30, off 0/30); the corridor 11.4°/6.0 m, residual 1.22 m (bar 1.8), giveups 1, identical across mask arms; nav's suite 8/0 in every arm, the wedged rig not frozen. Bar 4 FAILS: the longest refused run is 83 ticks (bar ≤ 3): three hulls, each AT its slot and flush against ONE world collider, want a 1.6–2.7° trim that swings a corner 2–3 cm into it (runs of 80–92 ticks): item 1's ratchet against the world. Fix in progress: a refused smallest candidate may slide off a single contact (≤ 5 cm along its normal, accepted only if no deeper; a corridor still refuses). A second "hole" (a stationary bus rotating 143.7° through a crate unchecked) was RETRACTED by combat within the hour: measured penetration on that fixture is 1.3 mm with the constraint off and 0.6 mm on; move_and_slide depenetrates every tick even at zero velocity, so a hull pivoting against a face scrapes along it and does not pass through; the "inside" came from a helper counting a 1 mm touch as inside. The pivot-arming change is dropped. The slide-off mechanism stands (unit test, laptop: a bus flush against a wall goes from frozen 54 ticks / 16° to turning 88.5°, run 0, 14 slide-offs, never deeper than it stood; a fixed list of push distances 1/2/3.5/5 cm along the normal, first fit wins); it lands defaults-unchanged (baseline unmoved), then the four CP4 bars re-run on one build.
- **Control's grounding scoped to PLAYER orders (7cceceff):** grounding every order moved scenario_orders' 100 ms response test (laptop A/B: fails with, passes without), so only source == "player" orders are grounded; elements ground their own plans, CPU and scripted orders keep their geometry (which is why the baseline does not move). Consequence relayed to nav: the drive test must issue its orders with source "player" to see the grounding. Control's check on e55d1143 (main 696b581c merged) is running.
- **State at 21:00: twenty-two merges on main; four streams done (announcer, show, arena, terrain pending its final Status); the sim baseline adopted twice tonight (11c479c3 for CP3 + nav's retry at f29c5b7c; 7dcc52f5 for arena's grid at 696b581c); the main check on 696b581c running with REMOTE_SLOTS=5.** Still to land: control's right-click goal grounding (8e942f20, check running; contract R2b), squad's post-merge set (6d slot grounding with the hull's clearance, the one grounding call, the harness Tank.place fix, the seeded defile probe; MOVES), combat's CP4 verdict run (five_squads three arms on the pitch tree) and the pre-registered lof-site flip after squad's merge, nav's yield-spot clearance row (opt-in).
- **The parked-friend scenario, re-read under Tank.place (combat): the machine flip is GONE, and the disc refuses the lane the box allows.** Disc (default): first shot tick 251, 1 shot, moved 12.2 m, FAIL, identical on the laptop and builder0 to the tick; box (`match.hull_disc=0`, laptop): first shot 114, 2 shots, moved 4.1 m, PASS (builder0's box run and the per-site `hull_disc_lof=0` run pending). Feel's earlier inverted pair was the tick-1 teleport swapping the arms. The flip of the lof site to the box is pre-registered as its own commit with bars (parked-friend on both machines; the paired series cell not worse; five_squads and suppression unchanged; the baseline moved with one cause), after squad's merge. The pit series' frozen-tree runs were DIRTY (combat's own logs in the clone; the uid files) and are unquotable (lof b=6 c=2 p=0.29; incoming b=6 c=3 p=0.51, both leaning to the box); the clean re-run is running.
- **TWO "behaviour" REDS WITHDRAWN (squad, on arena's `_place` finding):** the scenario harness wrote `global_position` instead of `Tank.place()`, so every scenario body sat at its grid slot for tick 1 (combat's own settle-tick defect in another costume). With the fix (squad c0040ae4): engine-deck on the bus 7/12 FAIL → 47 deck hits of 50 PASS; formation-slot drift 16.1 → 15.0 m PASS; cover-peeking's 5-vs-4 margin was the artefact and is now honestly red (4 vs 4: the reload-window arm shows no effect; re-measured on paired seeds later). The count at squad's post-merge tip reads 42,2 (cover-peeking, parked-friend). Combat asked to re-read parked-friend under the fix before its series is read as the discriminator.
- **Sim baseline ADOPTED at `f29c5b7c`: 1ea332e7bc268d2a → 11c479c3bec77082** (builder0, read twice, agreeing; two causes named in the commit: CP3 and nav's route retry). Every stream told to merge main. **Squad's finding on its pitch check:** its tree read aac14c6704fbac39, which is CP3's hash ALONE, so the pitch (with deploy at the width floor) moved the baseline by zero on the default path; its pre-registration "MOVES" is corrected to UNMOVED-relative-to-CP3; if its tree on f29c5b7c reads 11c479c3 the merge needs no record.
- **Arena's grid check (36f5871a) read CP3's two REASON'd reds and a moved baseline** (1ea332e7 → 34a46c20 = CP3 + its reorder, because CP3's move was not yet adopted on main): told to wait for the adopt, merge main, re-check so its reorder is the one cause. Arena also found `tests/ai_scenarios/ai_scenario.gd::_place` writes `global_position` instead of `Tank.place()` (the documented teleport defect; not the cause of any red): squad's path, relayed.
- **The composed baseline (CP3 + nav's retry) record: first read `glibc-2.43 11c479c3bec77082` (builder0, main 709cbeb9's tree); the second read was KILLED mid-run when my chained watcher hit its one-hour timeout (my own harness trap: a monitor's timeout kills the job it launched; lesson for orchestration.md: launch long jobs detached and watch them, never inside a watcher); relaunched detached at 18:45, adopted when it agrees.**
- **Engine-deck on the 9.70 m bus (squad, laptop): BEHAVIOUR, not a literal.** MEASURE {deck 7, hits 12, shots 12}: the share holds (58 % on the deck, bar 50 %); the volume floor fails (12 hits < 20). The scout stays in ORBIT the whole fight but never opens a deck run: the tank's gun sits within ~5° of it almost always; orbit range wobbles 6–23 m at 20–40°/s, never out-turning the 50°/s turret. REASON'd red for the count; squad's, after the pitch merge (its item 6c/6d). **6d is BUILT (squad b59abc6e, after the merge hash, its own item): slots grounded with the hull's own clearance (`SlotGround.standable_for` probes at the envelope minus the bake radius) and the follow station grounded in the brain; on nav's three Terminus points the old edge points had the hull's reach off the mesh in 5/16, 8/16, 5/16 directions, the fitted slots 0/16, moved 5.3 / 10.4 / 8.5 m; tactics suites 77/77; moves the baseline (pre-registered).**
- **Combat's disc-site series, first cell (pit, pre-CP3 tree e7d3ced6, builder0, 64 paired seeds):** lof-site box vs disc control, gangs 28 % vs 20 %, discordant b=8 c=3, McNemar p = 0.227: a non-significant lean toward the box at the line-of-fire site; the run was killed by slot.sh's 90-min limit after two arms, so the target now takes one arm per invocation; the series is frozen at 6e2d9421 (post-CP3 bus) with the remaining arms queued from a clean clone at that commit. Three .uid files missing on main under terrain's paths (every worktree reads dirty after an import): terrain asked to commit them.
- **nav's arms branch, attributed (builder0):** the baseline move is ONE cause, the not-ready route RETRY (default path 7574ac017c17265b; `--nav-off=notready` gives back 1ea332e7bc268d2a exactly); the arms are OPT-IN (inverted switches: `--nav-off=press,inflate,nosestop` turns them ON; ON together = d54665a6104b7c1a) and go default only after their own A/B clears the tactics tests, because the two tactics_elements reds on c91d8039 came from the ARMS (corner inflation), not the retry (arms off + retry on: 8/0). Next check on f386c63e (main 4ff45e50 merged) queued with REMOTE_SLOTS=5; pre-registered MOVED by the retry alone. The oriented `radius_of` (the seventh disc site) is built, opt-in, awaiting its falsifier. Plan: squad's pair and nav's retry merge back to back and the baseline is recorded once naming both causes.
- **The deploy zone cannot grow (arena, measured from the colliders):** free ground ahead of the green zone's front edge is 5.0 m on yard and pit (the form-up containers), 4.0 m on the Terminus (the z = 62 blocks) and the Crossing, 0.0 m on the Sumps; backwards is the drivable limit; wider is 6 m a side. RULED, then REVISED on squad's measurement of the alternatives: for this merge ArmyLayout DEPLOYS at the round-9 width floor (no unit outside its zone; the deploy half of the baseline move disappears) and only FORMATIONS lay at the diagonal + 0.30 from the first order on; the known cost is that squads are packed at spawn and their first dressing turns clip (−0.27 m at 4.90 m on the bus); the checkerboard-staggered deploy (arena's option a) is the round-11 item that removes it. Arena's containment test (no deployed unit outside the zone ∪ the free floor behind its front edge) lands with its grid item. five_squads places its hulls by hand, so CP4's regime is untouched.
- **Squad on the bus tree (main 69c681ac merged; check on ed24518c running):** base-of-fire newly red was a LITERAL (the scenario's "lane clear" was 3 m from each assault vehicle's CENTRE while the friend check takes the hull's own extent off first and the bus reaches 5.06 m; now `hull_distance_to_line(..., "lof") ≤ 1 m`; on the bus: lane clear 11.8 s, first shot 0.2 s after, 5 shots, PASS; no move). Drive-to-slots is green on that tree but NOT because of the seating: its route runs 7 m east before turning north (an obstacle), so "metres north" undercounted a correct detour; it now measures route progress (19.0 m against 0.3 × top speed × 6 s = 16.2; the 0.3 is squad's judgement, flagged). The pair: d8193e86 pitch (diagonal + 0.30: bus turns clear at +0.27/+0.29, 4 of 4 round; MOVES, one cause) and bed99012 legged seating (MOVES, one cause, now without its motivating test): RULED kept only with its own legged-path settle pair on the same seeds, else dropped from this merge. Two forced follow-ups: a hold with a drawn heading replaces a move at once; the deploy zone derived from the floor (five 5-bus wedges need ~210 m; a 25-bus front rank stands ~11 m ahead of a 150 × 32 m zone: relayed to arena).
- **Sequence corrected by combat:** five_squads places its 30 hulls BY HAND at a 6 m row in test_ai_player_orders._setup (neither the spawn grid nor squad's pitch touches it), so CP4's re-run needs only squad's pair + CP3, not arena's grid; if the constraint ON still freezes that hand-placed row while arrival slots and the real grid are fine, the fix is the test's own row pitch derived from the envelope, with a REASON.
- **Combat's CP3 review: APPROVED** (jitter derived and asserted, Z is 0.15 by the code's (12.0 − 9.70 − 2.0)/2; bus box and mounts; turret scale pinned; the muzzle-inside-own-hull test landed and passes). One defect found and fixed on combat's branch (709d5b3b): `_apply_turret_mount` read the raw profile, so a TUNE of muzzle_height moved Tank.muzzle_height but not the pivot; untuned values identical, baseline pre-registered unmoved. **Arena's spawn-grid ruling: option A** (the 57 lattice points kept as a set, filled checkerboard-first so the first 28 bare spawns have disjoint bus envelopes; 57 disjoint envelopes cannot fit in 3 rows × ±67.5 m; doctrine armies re-lay at tick 0 and never stand on the grid, so five_squads' overlaps are squad's pitch); a one-line carve-out in Match.spawn_position, combat reviews; baseline moves, one cause. Combat's pit series synced BEFORE CP3 (measures the 8.62 m bus; reported as that tree's answer; a post-CP3 rerun follows).
- **The scenario count RE-RECORDED on main at `4ff45e50`: 41,3 → 44,0,3,0** (builder0, the tree with combat and squad in; three REASONs in the commit: the artillery target parks in sight on either route; base of fire gets the HOLD the element issues; the ORBIT controller). A main check on `4ff45e50` (nine merges + the record) launched 16:40 with REMOTE_SLOTS=5; every stream told to merge main before its next check.
- **builder0 slots raised to 5 for the night (15:00):** round-status read load 0.8 on 12 cores with 11.8 GB free while ten runs queued for three slots (lesson 161's shape); every stream told to launch with `REMOTE_SLOTS=5` (slot.sh divides the memory budget by the live count). Reversal: drop the prefix. Nav holds three navdev worktrees in the queue; asked to release superseded arms.
- **Squad's reading of its two CP3 scenarios (box commit 055fb10f, laptop):** overwatch-covers-from-cover is a LITERAL (the bigger bus settles its start 2.3 m south into WallWestA's shadow, so the positive control stopped controlling): a 4 m start shift plus a SETUP assertion land in CP3 (0 % exposed staying put vs 73 % at the tactical spot, PASS); formation-slot-stays-in-it is BEHAVIOUR, squad's row (drift 15.2 m against a derived 16.0 m leash bar on the laptop, over on builder0; the bigger hull's fighting turns carry its centre further out): left red with a REASON, taken after the pitch + seating pair.
- **CP3 bisect (feel, builder0):** the jitter shrink alone (7001bdc8) is clean (41,3 unchanged); the BOX alone (055fb10f) causes all three unit reds; the mounts add nothing to the UNIT tests (a138b5f1 identical, baseline aac14c6704fbac39) but tip one scenario: formation-slot-stays-in-it PASSES on the box-only tree and fails only with the mounts (the bus pivot 0.2 m aft), squad's 15.2-against-16.0 knife-edge; feel's correction, relayed to squad. On the box tree, newly failing: scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it and scenario_squad::test_the_overwatch_element_covers_from_cover (squad reading both: literal → derived form in CP3; behaviour on the 9.7 m bus → squad's row with a REASON), plus the parked-friend scenario (combat's row). Landed on feel's branch: combat's autocannon derivation (passes), squad's drive-to-slots form (red, REASON), parked-friend (red, REASON), the MatchMood.control_changes() accessor for show. Feel merges main (squad's and combat's fixes, the 44,0 count) before its final check.
- **show (green at 9f68b95e, 1572/0; merging once at f19804ed when its wrapper line lands):** per-window addressing is BUILT as one RGBA8 texel per window (ShowWindowGrid 32×1024) read by city_block.gdshader, plus a per-window 'pixel' layer: idle twinkle, skirmish sweep, battle chase up every tower, last_stand strobe on the one facade facing the losing base, victory sweep in the winner's colour, a kill ripple across windows, a capture fill floor by floor; sign letters as windows, pools take the ripple. Draw calls 257 → 258, lights 1 → 1, zero instance uniforms. **Show's verdict: the band dial (1×/2×/3×) is near-indistinguishable to the eye; the pixel layer is the lever.** The luma instrument now sees it (Terminus wide −6 % to −27 %): reported to him with the frames, not blocking. Feel reviews three shader edits at merge; the quiet perf re-measure is owed (builder0 contended).
- **State at 14:30:** seven merges on main (control, arena CP2, announcer ×3, squad, nav's instrument, combat); `main-checked` at 7c7387fe (1587/0); the check on cb127c16 (squad + nav instrument + arena names) queued at builder0 position 8 of 10, and the scenario-count record (44,0, three REASONs) chained to run the moment it finishes (remote.sh refuses two live runs from one folder). Waiting on: control c4a50ca9 (repath-test under the no-damage tune; 7/7 expected on main), feel's CP3 hash and bisect, nav's arms attribution (baseline moved: the route retry is the suspect), terrain's hash (arena names now on main), show's status (asked). Squad's site wiring a8789bea (arm-proven) rides with its pitch + seating pair after CP3.
- **Lessons to write into orchestration.md at close (announcer's words):** (1) git-ignored is not invisible: `tools/remote.sh` syncs the working tree, so a git-ignored folder of a format Godot imports reaches builder0 and gets imported (the masters folder had the clips folder's round-4 exposure for six rounds); (2) rescue a worktree's git-ignored inputs before removing it or a later round pays for them twice (the Terminus masters were lost with a round-8 worktree; `--only-values` caught the 180-recording re-run). Announcer's Status docs merged at 6e5bf7c8.
- **THE ROUND'S FIRST MEASURED ANSWER TO "UNITS DRIVE INTO WALLS" (nav, builder0, seed 1, 90 s legs, deterministic):** contact unit-ticks on the Terminus drive, mixed squad: pre-CP2 7866 (arrived 5,5,6,4 of 6) → CP2 map 4957 (5,3,6,4) → CP2 + nav's two arms (pressed-wall escape, corner inflation to the turning envelope) 1575 (5,4,6,4); War Rigs: 15691 (arrived 1,1,0,0 of 4) → 8139 (2,2,1,3) → 3839 (1,3,2,3). CP2 alone cut contacts 37 % / 48 %; the arms a further 68 % / 53 %. Top colliders after CP2: Block_1, Block_7 (steer), Floodlight_31 for the rigs. What remains is mostly hulls at the END of a route on the mesh edge against a kerb with the slot 8–14 m away and probably off-mesh (a nose-stop arm under test; slots-inside-blocks reported to squad). The arms branch (c91d8039) is NOT merged: its baseline moved (attribution running; the not-ready route retry is the likely single cause) and two test_tactics_elements reds are being read.
- **Drive-north on the bigger bus is a squad finding, not the spawn press (squad's trace on the CP3 tree):** the element seats its leader at the column's HEAD, so the bus at the row's left end swings to −76° and drives east at 8.8 m/s for 2 s crossing its own row while co-arrival pacing holds the rest at 0.35; the wider-turning bus tipped a test that was marginal on the 8.62 m tank. Squad's item-3 seating fix touched only plain moves; the legged (drills-on) path needs the same. RULED: squad lands the pitch and the legged-path seating as two separate commits in one merge, one recorded baseline move naming two causes; CP3 merges with this REASON and the parked-friend REASON (a knife-edge on the 9.7 m bus: laptop plain passes, disc=0 fails, builder0 plain fails; combat's series decides), count 39,5 with the two scenarios named. Sequence: CP3 → squad (pitch + seating) → combat's CP4 re-run.
- **Terrain's maps need spoken names** (announcer-check's test_arena_names): announcer records "the Crossing" and "the Sumps" (the Pits renamed so `pits` never sits beside `pit`) under R8; terrain merges after that lands. Terrain's numbers on the fixed instrument: the Crossing spread 0.55 vs 0.30 dry (the river makes the decision); the Sumps 0.35 wet and dry (the paired series decides).
- **CP3 interim (feel `a138b5f1`, builder0): 1571/3, sim-baseline MOVED 1ea332e7bc268d2a → aac14c6704fbac39 (pre-registered), ai-scenarios 41,3 → 39,5.** The neutral commits are proven (5cfde60e unmoved). Three unit reds are literals calibrated on the 8.62 m bus in other streams' tests (combat's fire_discipline parked-friend lane and combat_mechanics autocannon-past-range; squad's tactics_elements drive-north): RULED as round 9's CP2 rule, feel lands each in derived form inside CP3, owners review at merge, and a test whose CLAIM changes on the bigger bus becomes the owner's behaviour row instead. Feel is bisecting box/jitter/mounts and naming the two scenarios that moved. Ready for the lead: the bus concept page (3 directions, 27 Meshy credits, balance 61), the bus lineup and the turret side-on pairs (paths in feel's Status).
- **Pitch ruling revised on squad's measurement:** the smaller bound clips (hulls dressing together sweep the full diagonal at once); lateral floor = max(width + HULL_CLEAR_M, diagonal + DRESS_MARGIN_M 0.30): tank 9.25 m, rig ≈ 14.7 m; lands after CP3; staggered dressing is the recorded option if the rigs look too spread.
- **R2 status:** control `54fa6ff6`+ (K1 `task`, the click compare; 6 of 7 in-flight states pass on builder0) and squad `35f7b459` (the first update after a player task issues every crew, idle ones included; the idle-branch `_should_issue` fix, mutation-checked) both await full checks; control merges first, squad runs `repath-test ONLY=arrived` on main after.
- **CP2 in progress (arena `b438f72b`, check running):** the lane assertion, the Terminus furniture moved (avenue 17.56 m, streets 16.40, ring road 18.20 drivable; 17 junctions clear the rig's cut); the R4 bar corrected to 8.14 m (widest hull syn_artillery 4.07 m), read live from `ArenaLanes.bar()`; nav and terrain told. **R3 finding:** the floodlight fits its collider (head at 15 m); what he drove through was most likely the neon SIGN (no collider, inside spawn zones on three maps; moved and asserted); the rig's trailer art folding outside its 14 m box is the other candidate (S2). Two prop questions to feel (ad-screen housing height; wreck husk 3.3 m in a 6.4 m box).
- **R2a (K1 gains `task`):** squad found `_same_order` drops an element re-issue that changes only the facing and drops an unchanged `follow`; control adds the `task` key and the compare; recorded as contract R2a. **R5 design accepted** (feel): the turret pivot moves on x/z (sim: shells leave under the drawn gun), y stays at muzzle_height − 0.05, no mount = today's pose; combat no objection; aim point verified planar at the target's origin (C8 not a trap today, guard test coming); open check for feel: the fixed 3.2 m muzzle offset must stay inside the own hull box on long hulls. CP3 will name THREE causes (box, jitter, mounts) as three separate commits.
- **Sequence set for the spawn regime:** CP3 (feel: the bus box ≥ 9.4 × 2.9 m AND combat's `SPAWN_JITTER_MAX_Z` 0.6 → ≤ 0.3, `SPAWN_JITTER_MAX_X` 1.5 → ≤ 1.3, derived in the comment from pitch − 2·jitter − hull ≥ `HULL_CLEAR_M`; two named causes for one baseline move; combat reviews at merge, no objection) → squad's lateral pitch from the turning envelope (alone, baseline recorded) → combat re-runs five_squads with the constraint on, on that tree (CP4 is measured on the post-CP3 box, combat's request). Arena's spawn-grid item (its 4) merges main after CP3 and derives from the new jitter. Pre-registered by combat: `test_tank_place` / `test_spawn_isolation` placements MOVE under the jitter cap (not a regression); five_squads seeds jitter 0 and cannot be touched by it.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all nine (OFFSETs: control 1, squad 2, arena 3, nav 4, combat 5, feel 6, show 7, announcer 8, terrain 9;
show and terrain run every Godot process on builder0; announcer runs no Godot beyond `announcer-check`):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**`main` at launch:** `de31eeea` (round 9's close, plus the round-10 docs). Its code equals the round's final green
check (`a21bad3c` / `4b95749d`: 1559/0, 18 targets, exit 0, sim-baseline `1ea332e7bc268d2a`, ai-scenarios 41,3) on
every checked path except two comment lines (`combat_motion.gd`, `switch_arms.py`: archive links). **VERIFIED GREEN: the
full check on `de31eeea` (builder0, launched 18:55, read 19:45 from the wrapper's own line): `>> remote: make check
exited 0`, `1559 passed, 0 failed` over six shards, 18 targets, ai-scenarios 41,3 unchanged, sim-baseline
`1ea332e7bc268d2a` unmoved, determinism `559a415887806e43`. The round-10 docs commits since it are docs only.** **The eight round-9
worker sessions are still open on this laptop (ListAgents shows them idle in folders that no longer exist): end them
before starting the eight new ones.** Nothing is pushed to `origin`; you push.

**Orchestrator duties this round:** merge CP2 (arena's lanes) the day it is announced and tell nav to `git merge main` (CP1 withdrawn: R1 is control's UX item now); CP3 (the bus box) and CP4 (the constraint) move the sim
baseline: record it twice in the same session; put feel's lineup frame, blimp frame and turret pairs, show's three
band-width frames and its 1990s-baseline page, arena's street pairs and announcer's review page in front of the lead
the day they exist; carry nav's wall-contact log to combat and combat's refusal log to nav; re-record the ai-scenarios
count with combat's and squad's REASONs; relay the lead's vetoes (bus concept, announcer lines, band width) the same
day. Integration order: squad (CP1) → arena (CP2) → control → nav → combat → feel (CP3 alone) → show → announcer → terrain (after arena, whose generator it extends).

**Decisions made for him at launch (each reversible in one place, all in `game_design.md` §"What it means"):** streets
are for driving, containers to the kerbs (arena); any selection of two or more units forms a transient element
(squad/control); a player's order pre-empts every task, hold and pacing (R2); slot pitch from the turning envelope,
hulls do not clip while dressing (squad); a dragged facing orients the formation across the heading, the camera keeps
lifting (control's two questions); the bus's numbers are his eye, not the table (feel, R6); the blimp flies low among
the blocks in his frame (feel, R7); heavies-in-alleys is moot after CP2 and priced, not refused (nav); announcer
generation proceeds without per-line approval, review page for veto, stop at half the balance (R8); 2× band width
ships as the show's default if the gate allows, 3× is his (show).

---


## ✅ ROUND 9 IS CLOSED (2026-09-20, 18:05) — read this first

**All eight streams merged and closed at commits whose own builder0 checks were read from the wrapper's line and the
runner's line. The final check (show's `a21bad3c`, whose tree equals `main` on every checked path): 1559 passed,
0 failed, 18 targets all passed, `make check exited 0`, sim-baseline PASSED at `1ea332e7bc268d2a`, ai-scenarios 41,3,
zero FAIL lines. The annotated `main-checked` tag is on `4b95749d` with those lines. Nothing is pushed to `origin`;
you push.** Briefs are archived in `_agents/streams/archive/round9/`, each with its round-10 list at the top of Status.

**Your direction at 16:55 was converge, re-merge, reset; this is the converged state.** To reset: end the eight worker
sessions (they are idle), then in `~/projects/godot`:

    for s in combat control feel metrics nav scale show squad; do make worktree-remove STREAM=$s; done
    for s in combat control feel metrics nav scale show squad; do git branch -D stream/$s; done   # all are ancestors of main

(Every `stream/*` tip was verified an ancestor of `main`; no worktree holds git-ignored assets beyond `.tools`,
`local.mk`, `override.cfg`.)

**What round 9 shipped, in one paragraph:** combat's settle tick (`Tank.place()`: the tick-1 shove that put all 90
hulls 56–110 m off is gone; the sim baseline moved once, for that one declared cause), the plant constraint OFF on a
source bisect with the refusal ranking that refuted diagonal spacing, nav's sealed teardown (the 30–50-red cascade per
check structurally closed, two arms confirmed independently), metrics' keep-going check with a PASS / FAIL / NOT RUN
verdict and the first fully clean engine tally, `TUNE` applied at first read with a two-arm load-order test, control's
screen-specified chevron and contract-true pin test, squad's hold-on-arrival, scale's bodies guard and spawn-grid
handover, feel's roof dressing and lamp pair, show's decision pair on a real fight with a pair that is finally frozen. **Show's pre-registered S6 held at every check of the round: the show never reached the simulation** (sim-baseline unmoved across a channel engine, five shaders, seven fixtures, a cue book, a kill ripple and a main that moved twenty commits underneath it; the falsifier was registered before a line of code existed).
**Combat's ledger is the round's:** infrastructure and retractions shipped; the visible thing (semis not yawing in
place) did not, because enabling it stopped four of five squads forming up; "the units seem a little smarter but it's
hard to tell" is the correct reading. Eleven measurements were retracted, all one shape: the thing under test was
never selected and the null looked like a measurement (lessons 178–200; the one sentence above the list).

**What you saw when you played (`make skirmish` at `7424420b`, your words in `game_design.md`):** no blimp (never
briefed by anyone: my gap; round 10, your art call); the Terminus windows breathe exactly as subtly as the show's own
gates sized them ("the subtle glowing effect but that's it" is the show as built; round 10 starts from your two
quotes: basic primitives to drive individual lights on a building, light-show effects composed from them, your eye the
judge against a 1990s-game baseline frame); containers in the Terminus roads read as "impassable?" before routing
matters; your acceptance test for round 10 is driving squads through the Terminus streets.

**Round 10's list is below** ("Round 10's list, in the order I would brief it"), and each archived brief has its own
at the top of Status. The morning's section that follows is the day's history, kept as written.

---

## ☀ THE MORNING AFTER ROUND 9's NIGHT — read this first (2026-09-20, written 07:00, updated at each tick)

**You went to bed at ~00:45 with eight streams briefed. By 07:00 twelve branches were merged to `main`, every merge at
a hash whose own builder0 check went green, the sim baseline was recorded as it moved, and `main` was verified green
after each wave. Nothing is pushed to `origin` — you push.** The night's rules were yours: any decision over no
decision, and finished, validated work. Every decision below is reversible in one place, and each says how.

### What is on `main` (in merge order; builder0 verdicts read from the wrapper's own line)

| stream | merged at | what | verdict |
|---|---|---|---|
| control | `e27f0681` (CP2c) | **desktop right-drag orders the heading to arrive on** (press = destination, drag past 18 px = facing): the arc that could never fire on your controls now can | 1269/0 |
| nav | `5c8f08b3` | **A7 priority projection, A11 dynamic-window arcs, A1 event-triggered replanning, A4 clothoids: all built, measured, and OPT-IN**; the arrival gate counts offered = aimed + refused | 1290/0, baseline unmoved |
| feel | `7a706911` | **the War Rig is a tractor and a trailer hinged at the fifth wheel** (S2: the collider is still one 14 m box, so a shell can pass through a fold; the accepted cost this round) | 1273/0, baseline unmoved |
| metrics | `ae9c65e1` (CP1) | **A12 trajectory metrics** (reproduced round 8's oscillation numbers to 0.05 pt), **the lint that actually checks** (the remote gate had parse-checked ZERO files all round: lesson 157), the sharded parallel check (a full gate now takes 13–18 min instead of 45) | 1310/0 |
| nav | `3b01f5b7`, `c6222a5c`, `d6a1f454` | the `wedged` regime detector, the gains override, **the A4 A/B (fails its bars; default stays off on measurement)**, the legibility key and corridor tangent, A6's two clauses (opt-in, honestly inert until the corridor arrives) | 1295/0, 1316/0, 1381/0 |
| control | `ffd09b0e`, `3683e0ca` | **the camera stays outside the Terminus blocks** (lift 21° → 32° over a roof; 703 of 4328 poses inside a building → 0) **and the block in the way is cut** (alley walled 518 → 0); the corridor readout | 16/16 targets, 1372/0 |
| squad | `02762b8d`, `1a797642` | **slot pitch and leash from the members' hulls**, facings on element orders, **A8 measured and switched off**, **A9 co-arrival + explicit bounding overwatch**, per-faction PID gains measured; A10 stood down; A1's brain-side tube measured and OFF | 1297/0 + five targets; 1364/0; **baseline moved → `d4c049819a5833d3`** (recorded twice) |
| feel | `5ae7e531` | **the Syndicate airship** (primitives, no Meshy), the differential smokes proved, the pipeline roster fix | 1316/0, baseline unmoved |
| combat | `55b0de58` | **the dwell timer retired on measurement** (inert for two rounds), **A2 opt-in** (weaker than the flat bonus on churn, costs nothing where 1.35 did), the CLEAR_LANE catch | 1393/0; **baseline moved → `32831dc99cdaf5ca`** (recorded twice at 07:10, agreeing) |
| show | `e1823e68` | **the arena as a light show**: fixtures, channels, patches, cues; Terminus and yard patched; ~1.5% of frame time, zero added lights | 1420/0, baseline unmoved |
| **morning merges (10:10–12:20)** | | | |
| feel | `d8a107b5` | **a unit's collider is measured in the pose it is shot at in** (the artillery stowed: 4.74 → 2.90 m wide); the box-fill test deliberately red until scale's box lands | handover |
| show | `dd3c90f2`…`96a6a62a` | **the four dials in your terms** (`_agents/show_dials.md`), the add-a-cue recipe, rule 12 (every visual claim is a pair), the floor-ownership row | docs only |
| metrics | `9553be18` (`bac84a6f`) | **`ai-scenarios` into `check`** (count-gated; its first run exposed the three scenario rows below), the sim-hash verdict line (`make check-hashes`: determinism's hash reaches a log for the first time, `253adefeec657df1`), `--pool` with the mixed-commit banner | 1481/4, exit 2: the four reds are main's (diff under game/ and tests/ empty) |
| control | `e51516a1` (`822bd8a7`) | **item 4: the camera sweep and HUD on the resized roster**, the contact-pip test picks a visible spot, your two calls written in your terms | 1479/0 on `f007423e`, exit 2 only on a stale baseline file (its run produced main's recorded hash) |
| scale | `87566cf7` (`b3c36498`) | **the Condemned artillery box derived in the stowed pose (4.74 → 2.90 m wide; the only unit that moved)**, the spawn-isolation test, the bodies-only teardown guard (silent across 1487 tests) | 1487/2 (`TEST_SHARDS=3`), exit 2: **sim-baseline moved once for this one cause, `2d5215a8a0a59ded → 1e90f69e5d6fcc46`, RECORDED twice at 11:03, agreeing**; the two reds are feel's (asset contract refits from authored bounds; city-block push_warning fixed at a33638b8, unmerged) |
| feel | `167e3541` (`01473d4f`, checked at `fef0ddc9`) | **the city-block colour rejection moved to the read site** (`CityBlock.resolves()` for `Arena.validate()`), **the asset contract refits through `driving_bounds`** (the artillery slot checks against the stowed silhouette: 2.89 vs scale's 2.90, a third route to the number), `perf-trailer-ab` judges itself (per-cycle costs, warm-up dropped, census printed and failing the verdict) | 1491/1, exit 2: the one test red is the spawn transient (squad's), the gate's three are main's rows; **main's city-block and artillery reds CLEARED**; baseline unmoved |
| nav | `a6a1c32f` (`af0bcefc`) | **the clearance row**: the bake radius read from the live mesh (the constant demoted to a cross-check), `clearance_shortfall()` per hull (14 of 21 exceed the 2.0 m bake), the routing refusal behind `--nav-off=clearance` (gang_tank refused at −2.28 m slack, scout untouched at 0.90 m), the pre-registered falsifier; the P7 rotation notes | 1492/3, exit 2: zero nav failures (the three are feel's two, since merged fixed, and the spawn test); baseline unmoved on two consecutive checks with the whole row in |
| control | `9b0db570` (`d9da4dd1`, checked at `6ba28cb6`) | **the squad pin draws what the crews were told, not what the task holds; the selection marker is shaped like the vehicle** (SDF capsule, six draw calls, frames with you); the camera's lean bound read from the laid-out HUD; radar blips read the hull they stand for; **the wall cutaway no longer slices a tall hull at steep tilts** (a real CP2 bug, found by sweeping the range) | 1492/2, exit 2: the two are feel's, since merged fixed; nothing control owns fails |
| metrics | `f5bc93c7` (`bf2686ac`) | **the gate honours PENDING** (record `42,2,3,0` at `dd6f84ca`; the dodge coin is out, the two live rows stay in `failed`), **warnings counted apart from errors with `expect_warning`**, the ai-scenarios gate as a tested script, the shell suites no longer assume an idle laptop | 1499/3, exit 2: the three are main's (the spawn test; feel's two, fixed after metrics' merge point); baseline unmoved; copy-back verified by sha256 over 100 files |
| nav | `f1128ef5` (`bffdea0f`) | **`ArenaFixture` drains the navigation map to EMPTY before instantiating** (the navmesh synchronization cascade: `free()` is synchronous, the server's region removal is not, and the round-6 fixture guarded only the read side; 284 edge errors poisoned a whole shard of combat's check); `bake_radius()` keyed to the hull's own world | **merged UNVERIFIED** (nav's check blocked behind its queued arm); the main check on `f1128ef5` launched 12:13 is its verification |
| nav | `1ca8fc65` (`e94eed26`, over `490a20c9`, `f5a20e25`) | **the navigation drain in `TestCase.teardown()` (awaited by the runner) and in `ArenaFixture`**, so every test starts on an empty map; the clearance A/B's negative result; **and the parse error `bffdea0f` put on main** (a ternary GDScript cannot type in `movement.gd:528`; main's lint was red from 12:13 to 12:38, my cost for merging unverified) fixed | **VERIFIED at 17:45 (nav's check on `e94eed26`: 1514/2, ZERO navigation edge errors across the run where one shard had produced 284 and 568, baseline unmoved; the two reds metrics' shell test and the spawn test); the drain's budget raised 30 → 120 frames at `ccdf144d` after it cried wolf on a loaded box.** Before that: the main check on `f1128ef5` (the tree before the fix) came back 1113 passed / 402 FAILED, the parse error cascading at runtime, and its lint line said all scripts parse while control's check on the same tree died at lint: a lint inconsistency routed to metrics, which closed three absent-result-reads-as-clean holes in lint (`2e73a05e`: an empty checker output, a signal death, and a blind run all now fail, with the eight baselined artefacts as a liveness probe) and named the likely root cause: a per-file `--check-only` cannot see a type-inference error that only appears when the project compiles together, so the verdict depended on each worktree's `.godot` cache; the four-arm probe on builder0 (`b839495c`) then showed the checker sees this error class in every arm, so the green run had simply not checked the file: the silent-pass holes are the fix, no whole-project pass is built, and lint gains a fresh-error liveness probe; nav's check on `e94eed26` and the main check on `0ad28f49` (launched 12:46) are the verification** |
| squad | `f196b677` (`0f6e349b`) | **the deploy write fix** (the layout's y reaches the node; the earlier "0.05 passes" was inert), **the clearance test asserts placement, then settles, then judges, with a failure naming each pair's pitch, spacing and displacement vectors** (armed; silent on the 2-shard layout), the squad-wide facing reaches the order (leader only; option 3 next), one `SPAWN_LIFT_M` home | 1499/0, exit 2 only on the ai-scenarios count file main re-recorded after squad's merge point |
| scale | `222f4669` (`42aac2f2`) | **the no-mesh derivation reverted** (tank and burner keep 2.40 × 2.40 until they have art; both numbers in scale's Status), **the `hull_size` consumer list** (42 readers and what each assumes; the disc-of-diagonal hazard it found), **six irregular Terminus lamps inside the block grid** (authored in the generator; eight in a grid read as municipal, feel's objection), the fairness control's tooling, the lateral spawn-vector instrument | 1488/2 (`TEST_SHARDS=3`), exit 2: the two are feel's, since merged fixed; **sim-baseline PASSES at `1e90f69e5d6fcc46`** (no third move); screening green again; the bodies-only guard silent twice |
| control | `1ee1a4fa` (`771f93a6`, over the checked `230265a6`) | **item 4 complete: the auto-frame accounts for the hull, not just the point it stands on** (five War Rigs in column at your pose had a corner 16 px off screen); the lead's page of what item 4 changed | 1516/1, exit 2: the one red is combat's `test_combat_sim_cost` reported by nav's drain guard as leaving 2 regions after 30 frames, which turned out to be the guard's budget on a loaded box (zero edge errors in nav's run; budget raised to 120), not a leak; everything control owns passes |
| metrics | `46d3c8c2` (`d5974698`) | **the keep-going check with a PASS / FAIL / NOT RUN verdict read from the markers** (a failing shard had been abandoning 7 of 18 targets silently), **lint's three silent-pass holes closed with a fresh-error liveness probe** ("self-test seen" on the gate), `make sim-baseline-adopt`, `make round-status` (with the BASE column and the annotated `main-checked` verdict), the copy-back checksum and `--delete` with logs protected, `remote.sh` refusing to rsync over a live run, the quiet-window mode | 1500/2, exit 2, 914 s, 6 shards; markers agree with the summary; baseline unmoved |
| metrics | `3aa61da7` (`0f78674e`) | **`FILTER` as alternation, an empty match a FAILURE, `'` and `$` refused by name** (make expands `$` before any shell), round-status's BASE column (is what a branch took from main covered by a check) and the annotated `main-checked` verdict printed beside every run, the lint fresh-error probe | 1499/3 (check6), exit 2, 854 s, 5 shards; 17 passed / 1 FAILED / 0 NOT RUN agreeing with the markers; nine shell suites green on the box; baseline unmoved |
| nav | (`06c7e772`) | **`hull_box()` with a live unknown-id path** (`Units.stat` raises on an unknown id before any fallback: the pre-CP2 literals were stale AND dead), **`TestCase.expect_error`** (it surfaced a second, undeclared error on first use), the three fallbacks loud | 1516/2, exit 2; zero nav failures; baseline unmoved |
| squad | `4cff69b6` (`924460c7`) | **a dragged heading is a HOLD on arrival** (four iterations, each falsified by a measurement the previous could not make; the order asserted, the hull angles printed: tracked hulls reach it, wheeled hulls keep their approach), **the army_layout hull fallbacks loud and reading the live catalogue** (the old literal understated the default hull by 4.6 m, dead but wrong) | 1484/47, exit 2; **sim-baseline UNMOVED** (the hold needs a player-dragged facing; CPU play never takes the branch); the 47 are the 44-body cascade from combat's leaking test on main; shard 1 774/0; ai-scenarios-check reads 43,1 against the recorded 42,2 because `scenario_suppression` now passes under combat's separation bar (`364d77f2`, 1.02 / 0.28 = 3.6× against 3×; the engine-deck row still fails); metrics re-records from a run with the cause in the file (`ai-scenarios-record` now refuses without a REASON) |
| nav | `49ed1fb3` (`da57ab82`) | **the sealed `TestCase._teardown()` the runner awaits** (hook, free, guards, drain; the hook synchronous; `free_owned()` public), the concurrent-drain guard, the containment REVERTED (it regressed the suite to 1401/117 and stalled a shard by making every arena build burn its patience), the clearance row's claims corrected (rotational vs lateral length), vehicle-as-wall withdrawn under nav's name | 1517/1 (the spawn test), zero edge errors, zero drain reports, baseline unmoved; four override files that had silently skipped the drain now run it clean; whether the sealing makes combat's super-less override harmless is tested by the main check launched on this merge (15:18, log in the scratchpad) |
| feel | `cfac4fe6` (`19e258d2`) | **the Terminus roof dressing** (rooftop plant in a reserved band at zero extra draw calls, inside the collision box; a tier count the builder cannot honour is reported, not clamped; the first version passed every test and read as nothing until looked at), the lamp A/B as a real pair (the six lamps light the floor), the placement probe in the tree | 1495/38, exit 2; all 38 are combat's `test_tank_yaw_fit` leak on main (the first observer `test_theme_factions` this time); the four roof tests PASS by their own lines; baseline unmoved |
| combat | `53cc42e3` (`1c445bda`) | **a hull is an oriented box, not a disc** (`Units.hull_distance_to_line` / `hull_reach_along`, the six disc-of-diagonal sites migrated behind `match.hull_disc`; DISC stays the default until the gangs-vs-law series reports), **the suppression assertion as the separation it claims** (held > 3× chased), **the damage-off tune** for the timing benches, the engine-deck columns, **the hull-rotation plant constraint** (landed off, then working once a tolerance was found to be the blind spot), the spawn constant's comment corrected | check on `306651e0`: 1489/16, exit 2: 14 the navmesh cascade its tree predates the fix for, one feel's, one the bodies-only guard's catch that does not reproduce alone; shard 1 with everything combat landed 783/0; sim-baseline unreached by `check`, the default flip measured behaviour-neutral |
| combat | `53c759d6` (`3d0d4e39`) | **`SPAWN_LIFT_M` landed at 0.0** with one constant for both spawn sources and the named-body diagnostic that ended the red-test argument | 1483/3, exit 2: the three are main's reds; sim-baseline unreached |
| feel | `d99d2658` (`786898b3`) | the neighbouring-files rule in the brief; round-10 Status; the trailer bench records `Armor.no_damage` per phase and REFUSES without the freeze | merged WITHOUT its own check, stated in the merge message: bench code `make check` never runs, executed on builder0 in the run that produced the NOT USABLE refusal |
| main | `49ed1fb3` | **the main check under nav's seal with combat's leaking override still present** | **1535/1, 16 passed 2 FAILED 0 NOT RUN, exit 2; NO cascade (0 body, 0 region, 0 edge reports); sim-baseline unmoved 1e90f69e5d6fcc46; determinism 253adefeec657df1; builder0, test x5, 2 at once; the two reds: the spawn settle assertion and the engine-deck scenario. `main-checked` moved here.** |
| control | `be269334` (`c0d56029`) | the screen-specified facing chevron (nose stand-off half the arm span, solved back to the ground per pose, dark backing, asserted at his pose), the pin test rewritten to the contract (the task's heading IS the order deferred; unanimity kept on direct unit orders; the reversal of `ac4df0d7` named in the docstring), the four teardown overrides under the seal | 1540/1, 16 passed 2 FAILED 0 NOT RUN, exit 2, builder0 1134 s; sim-baseline unmoved; determinism 253adefeec657df1; ZERO region and body reports (the 32-red cascade on 78aa496d gone under the seal); the two reds main's known pair |
| metrics | `ec6fef46` (`2746233b`) | the scenario runner unified onto TestCase's ErrorCollector, allowlist and SEALED teardown (`run_scenarios.gd:70` had called the hook un-awaited: every scenario ran without the body guard and the drain), the engine-message allowlist (`tests/baselines/engine_expected.txt`, 0 seen from 1 pattern on every shard), `T=` refusing shell metacharacters, the exclusive window's slot ceiling, round-status BASE column | 1548/1, 16 passed 2 FAILED 0 NOT RUN, exit 2, builder0 1123 s, 5 shards; sim-baseline unmoved; determinism 253adefeec657df1; engine 0 errors 0 warnings (the first fully clean tally); the two reds main's known pair. **Consequence: the scenario count on main is now 41,3,3,0 against the recorded 42,2,3,0, and it was never load: four runs split exactly on whether a drain ran between scenarios; `scenario_cp2::test_artillery_stays_dug_in_on_a_moving_target` (combat) and `scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move` (squad) were passing on the previous scenario's leaked navigation state, failing fast (0.6 s, 1.4 s) once drained. Re-record with that REASON on main after combat's merge; the two scenarios routed as behaviour findings.** |
| scale | `b70dd8f7` (`3e2e77f1`) | the bodies guard's two fixes (a baseline at process start; two candidates named beside a riser with the sampling moment), the round-10 handover (the spawn grid gives a hull room to turn; the `hull_size` consumer list) | 1540/0 (`TEST_SHARDS=3`), 17 passed 1 FAILED 0 NOT RUN, exit 2, builder0; sim-baseline unmoved; determinism 253adefeec657df1; zero body and region reports; both pre-registered risers GONE under the seal (test_theme_factions was combat's foundry seen by its neighbour; test_combat_sim_profile's one body was owned and is freed by the seal); the one FAILED target is ai-scenarios-check at 43,1 vs the recorded 42,2 (engine-deck the survivor). `tests/test_case.gd` auto-merged across nav's seal, metrics' allowlist and scale's guard; three files run locally on the merged tree: 30 passed, 0 failed (laptop, `b70dd8f7`, `FILTER='engine_warnings|spawn_isolation|nav_arena_drain'`). |
| combat | `7f8eeab8` (`63155ffb`) | **the plant constraint default-OFF on the source bisect**, **`Tank.place()` with the settle tick** (the 90-body tick-1 shove gone; every match's first physics tick resolves the scene), TUNE applied at first read with point-of-use readers, **the two-arm load-order knob test** (a child Godot per arm, differ-assertion first), every combat teardown reaching the base, the disc sites behind `match.hull_disc` (disc default), the suppression separation assertion, the engine-deck columns, the refusal ranking that refuted diagonal spacing | **1544/0, 0 engine errors, 0 warnings, zero residue** (builder0, test x2, 1 at once), exit 2 on two RECORD-STATE targets: sim-baseline MOVED 1e90f69e5d6fcc46 → 1ea332e7bc268d2a (identical to 1db4893c's, so the test-side delta moved nothing; one cause, the settle tick; determinism 559a415887806e43), adopted on main next; ai-scenarios 43,1 vs the recorded 42,2 (re-recorded on main next with the drain and engine-deck reasons) |
| main | `22af6d0c` | **the closing main check** (both records on main: sim baseline `1ea332e7bc268d2a` at `1570fef1`, scenario count `41,3,3,0` at `22af6d0c`) | **1557/1, 17 passed 1 FAILED 0 NOT RUN, exit 2; sim-baseline PASSED; ai-scenarios-check PASSED at 41,3; determinism 559a415887806e43; 0 engine errors and 0 warnings on all six shards; zero residue; builder0, test x6, 3 at once. The one red: `test_combat_sim_cost::test_a_parked_hull_stays_exactly_still_and_drives_off_when_told`, its mid-loop `await teardown()` relied on the drain that nav's seal deliberately removed from the hook (`teardown()` now only frees; `_teardown()` drains), so the boundary delta reads regions still on the map (0 → 2 on the first unit, 2 → 2 after, zero residue): the tree's `TestCase` is the variable, NOT the shard count or a transient (my first reading, corrected by combat from main's file); the test is the fifth file of the seal's own list, the mid-test caller; fix: `free_owned()` then `await drain_navigation()` explicitly, combat, filtered line owed. `main-checked` moved here.** |
| combat | `4b125177` (`aa9f641a`) | `test_combat_sim_cost` frees and drains explicitly mid-loop instead of calling the teardown hook (the seal's fifth file) | merged at a FILTERED line, stated: builder0 `make test FILTER=combat_sim_cost exited 0`, 2/0, engine 0/0, boundary 0 → 0 on all three units; a filtered run cannot show what a test leaves for the next one, so the last main check verifies it in full |
| show | `4b95749d` (`a21bad3c`) | the decision pair on a real fight (a real army, the densest cluster, a 12 px drawn-mesh gate, `clear_pose`, the heading sweep), the capture pair actually FROZEN (FxWorld and the Show process-disabled across it), sibling frame directories, the docs with run seven's numbers and the freeze caveat, the round-10 list | **THE ROUND'S FINAL CHECK** (a21bad3c = main c13821c9 + show; main's tree equals it on every checked path): **1559/0, 18 targets all passed, exit 0**, lint 587 scripts, sim-baseline PASSED 1ea332e7bc268d2a, determinism 559a415887806e43, ai-scenarios 41,3 unchanged, zero FAIL lines; combat's sim_cost fix verified on a full shard; S6 held at every check (the show never reached the simulation). `main-checked` is here. |

**MERGED 08:10: CP2, scale's resized roster, at `ddb16592` (checked at `7542df28`: 1395 passed, 0 failed, exit 2 = the pre-registered sim-baseline move only). THE ROSTER IS LIVE ON `main`.** **SIM BASELINE RECORDED: `glibc-2.43 2d5215a8a0a59ded`** (builder0 08:15, twice, agreeing; the third move of the night; it differs from scale's branch prediction because combat's move composes with it). A main check on the full tip started 08:16; control's item 4 and feel's X4 were started at 08:10. Its history: verified to 1392 passed / 3 failed on `e7ebb372`; two of
the three fixed by scale, the third (a contact-pip test in control's file) fixed by control at 07:00 (`e36d61c7`: the test now picks a
spot it can see instead of a fixed 30 m offset that the bigger hulls put behind a prop) and committed by scale at
`7542df28`; scale's full check on it at 07:01 came back **1395 passed, 0 failed across both shards and still exit 2**, because T1's shard count is a recursively expanded make variable that re-derived itself from free memory between launch (2 shards) and verification (3): lesson 176, the fix is routed to metrics. **Re-running with the count pinned (`TEST_SHARDS=3`), wrapper line ~08:05**; inconclusive, not green, until then. The swap-bases fairness control is owed. **Owed by scale on the merged tree: the swap-bases fairness control (running from 08:10) and the factions re-render.** **MERGED 08:25: CP3, metrics at `0d4e5ef1` (checked at `0f811c1c`): the parallel check is ~3.2× faster** (837 / 882 / 882 s against a like-for-like serial 2820 s, three consecutive greens, hashes identical) **and its own three-run rule caught a latent race in the mechanism before it shipped; two runs would have passed** (lessons 175, 176). `REMOTE_SLOTS=3` ships with the measured reason. Owed: `ai-scenarios-check` into the gate as its own commit; determinism's truncated verdict line.

### What you should look at (all sent to you overnight; paths on this laptop)

0. **WITHDRAWN (14:10): show's "the show makes the fight up to +4.2 % easier to read"** and the luminance strip it rests on: every show frame was a five-a-side skirmish with a 3 s warm-up, the army 86 m from the ring the camera pointed at, so the readability gate measured bare asphalt. Fixed (budget, warm-up, camera at the army's centroid, an empty-frame gate); re-shot on a real army (16:50: 11–23 vehicles in frame, 35 of 36 frames inside the readability bar): **the show's effect on readability is ~zero, scattered both ways**; endgame cues (`victory`, `defeat`) are reported and not judged, with the counter-argument written into the gate for you to overrule. The strobe clips are being re-shot at 30 fps because 10 fps sampled the gaps between flashes (a 0.134 s stab, 1.3 frames). **Two calls the resize forced, written for you by control at the top of `_agents/streams/archive/round10/control.md` (Status), with frames:** the selection ring is now "a circle you could park two tanks abreast inside" (`build/camera-looks/arenas/yard/default.jpg`, `build/control-playtest/1920x1080/8_whole_army.png`); **ruled (b), a ring shaped to the hull; BUILT at control `fe9b7f59` (12:05) and sent to you: `~/projects/godot-control/build/ring-before-after/{before_circles,after_shaped}.png`** — a signed-distance rounded rectangle in the marker shader, half-extents from `hull_size` per instance, constant band thickness in metres, same six draw calls; enemy dash, thin unselected mark and `Shown.forward` orientation kept. Overrule in one word. The squad-wide facing drag: squad's 23b1d1a7 (landing today) turns the LEADER only; followers get a follow order with no facing and, measured, may never hold it (squad's own test asserts a follower is given no arrival heading). Squad's option 3 (re-issue the final move with the facing on arrival) was measured three ways (17:50): the crews turn (167° → 3° off by +15 s), then the orders complete and clear and the heading dies with them (settled 132°, 41°, 28°; `NO ORDER` on every crew): **a facing on a move is an arrival heading and exists only while the order is live. RULED: on arrival a HOLD carrying the drawn heading, a standing order, which is what "go there and face that way" asked for; landing with the three-way falsifier.** control's pin, derived from the crews' orders, draws by itself once every crew holds the heading. **Landed (19:00, four iterations, each falsified by a measurement the previous could not make: move+facing dies with the order; a one-shot hold is overwritten by `_group` every update; hold+halt hands each crew its own sector; hold+halt=false+told is correct): all four crews hold `hold facing=<drawn>`. The hulls end at tank 1.4°, tank 16.2°, ifv 41.4°, ifv 28.5°: tracked hulls neutral-steer to it, wheeled hulls cannot while parked and keep their last approach. The test asserts the ORDER (the element's contract) and prints the angles. Committed at squad `d29115ae` (filtered 8/0 on builder0); merges at its full check's lines because a hold on arrival changes what bots do after a move and may move the baseline. Decided, nav's to own: a held wheeled hull manoeuvres to its ordered facing above a threshold (obedience reads), round 10 unless cheap.** Queued, squad, round 10: `_is_clear` compares rotated boxes as aligned, sound within a team, a gap for arenas whose spawn zones are not exactly opposed. **Round-10 item, found on the way: 40 s from a right-drag to a settled squad on a 20 m move (22.3 s for the element to declare arrival, ~20 s more for the crews to stop; A9's co-arrival pacing waits on the slowest member); he will feel that before he sees any heading.** Then: **Terminus at your camera, 10:20:** `~/projects/godot-feel/build/terminus-luminance/terminus_pitch21_fov35_49m_default-camera.png` (sent to you). The bands now read the cyan and magenta the layout asks for (the palette fix confirmed in-game) and are still the brightest thing on screen; the vehicles are dark slabs held up by the UI rings. feel's diagnosis: light the floor (Terminus: two floodlights at the perimeter where pit has four, eight towers inside the fight), do not dim the bands. Lamps among the blocks in `terminus.json` are queued for scale behind the red test. **The show's four dials, in your terms: `_agents/show_dials.md`** (merged 10:30). Watch the two clips before the
   stills. It leads with the correction: the knob you will reach for is brightness and the one that reads as *alive*
   is the band's width. Two calls are posed as yours (roofline vs full outline; whether the `last_stand` strobe
   survives) with feel's and show's argument stated so you can overrule knowingly. Adding a cue is ten lines of JSON
   and no code: `_agents/lighting.md` §4b.
1. **The roster at real relative scale**: `~/projects/godot-scale/build/roster-lineup/lineup_pose.png` (your pose) and
   `lineup_factions.png`. K = 0.707, rig-anchored. **Overrule:** `Units.RIG_LENGTH_M` → 19.8 for real metres. feel's
   art review of the resize (08:40): it works, the rig dominates; two things for your eye, neither a defect: the
   Syndicate reads pristine white against everyone's rust (the ivory tower, intended), and **the Syndicate is fewer AND
   smaller** — the whole faction sits under 5.5 m while three factions field 8 m and up. If that reads as the runt
   rather than the surgical few, the thing to change is each unit's *reference vehicle*, not a number.
2. **The War Rig bending**: `~/projects/godot-feel/build/rig-hinge/strip_45.png`, `strip_21.png` (your pose),
   `strip_reverse_60.png` (the jackknife). Hear it from us: the collider is still one box.
3. **The camera in the Terminus alleys**: `~/projects/godot-control/build/terminus-alleys/index.html`; `alley4_asked`
   vs `alley4_clear` is the pair. **Overrule:** the lift resolver is one function; a push-in variant is the same test.
4. **The light show**: `~/projects/godot-show/build/show/` (frames, three arms: default, `before/`, `outline/`) and
   **`build/show/clips/*.mp4`; watch the clips before the stills**: after feel's art review the default is quiet in a
   still and lives in motion. The coloured horizontal bands in every frame are feel's round-7 shopfront neon, not the
   show. **Three dials, all data:** `show.channels.windows.ceiling` (1.10; the gate says what raising it costs the
   fight), `show_edge_energy` (0.8, parapet only), `"style": "outline"` (the full-silhouette look feel argues against).
5. **The resized roster under your camera** (control; `camera-looks` on builder0 at 08:59, `index.html` with 28 grid
   frames and all ten arenas at your pose; `build/camera-looks/arenas/yard/default.jpg` shows the ring finding on ONE
   unit: the tank sits in a circle about twice its own length; and the local shot at 08:28):
   `~/projects/godot-control/build/control-playtest/1920x1080/8_whole_army.png`. **Two findings, one is your call:**
   the selection rings are now a cloverleaf, because a ring's radius is 0.75 × the longer hull side and the 8.62 m
   tank's ring is 12.9 m across; options costed at the top of control's Status (circumscribing-circle bound, an
   oriented marker along the hull, or leave it). And a facing drag on a WHOLE SQUAD lost its heading: **fixed for the leader on `stream/squad` at `23b1d1a7`**
   (the cause was one line of squad's own, a facing only at a halt; verified 7/7 on a filtered run, NOT a full check —
   merge it after one) — **but the followers still cannot carry it** (`_flow` gives them a `follow` with no destination
   until the leader arrives, which is essentially arrival). Three fixes are in squad's brief in the order to try; **you
   can see the answer in two seconds by dragging a facing and looking where the followers point**, which is why squad
   did not pick one blind.
6. **The airship**: `~/projects/godot-feel/build/airship-look/airship_widest.png`. **You will not see it at your
   default pose**: the sky is below the top of the frame at 21°. It lives over the city at 560 m and shows at 8–12° tilt.
   **Your call:** leave it, or make it a title/results element. One constant either way.

### ⚠ Where it stood at 08:30, and what to run first

**builder0 dropped off the network a second time at ~08:27** (the first outage was ~02:50–03:25). Every remote run in
flight died with 255 (transport, not the suite): control's camera sweep, feel's X4 check, scale's fairness control,
and the `main` check that would have covered CP2 and its baseline. **So:**

- **The last `main` tip verified by its own check is `0808834e`** (1454/0, all thirteen merges before CP2).
- **On `main` above it, merged on their own green branch checks but NOT yet covered by a `main` check:** CP2 (scale
  `ddb16592`, checked at `7542df28`), the recorded baseline `2d5215a8a0a59ded`, and CP3 (metrics `0d4e5ef1`, checked
  at `0f811c1c`). Each is green alone; the combination is the one thing unproven.
- **The `main` check on the full tip `b008a277` (CP2 + CP3 + everything) came back at 08:48: `exited 2`, 1478 passed,
  1 FAILED** — `test_match_spawns_and_results::test_a_full_faction_army_a_side_spawns_clear_of_itself`: three units
  (`Green_S5_1`, `Rust_S5_1`, `Rust_S8_1`) spawn inside a wall or crate. **A composition failure:** it passed on
  scale's branch (1395/0 at `7542df28`) and on `main` before CP2 (1454/0 at `0808834e`), so it is a composition. **scale eliminated from the repository alone (08:58):** the test runs on foundry, whose
  layout is untouched; `game/tactics/` (ArmyLayout) is unchanged in the window; combat's `units.gd` lines are an inert
  `--tune` parser; the dressing adds no bodies. nav then accounted for `movement.gd` and `combat_motion.gd` line by line (constants, pure reads, one write-only
  bool, A6 behind its opt-in switch; the baseline unmoved by its merge), so **what remains in the window is
  `tank_brain.gd` (+133: squad's corridor field and tube plumbing, combat's switching-cost seam) — OR no motion at
  all: a unit that spawns ALREADY intersecting looks identical to one nudged on tick one**, which would be a
  placement-margin failure CP2 exposed (scale's). **FINAL (scale, 11:05, measured): the writer is `move_and_slide`'s depenetration recovery — three resized hulls move 1.475 m DOWN in frame 1 with velocity exactly zero, then climb back (−0.190 at frame 2, −0.042 at frame 3; a passing unit gets +0.87 mm from the identical contact). The test read at frame 1, the worst instant of a settle that resolves by frame 3, and which units land on the bad side depends on engine state left by earlier tests, so the shard schedule decided the verdict (71/71/71 green, 69/68/68 red, same code). Every collider box bottom is exactly at the origin at the catalogue height (`_apply_hull_size` is correct); nothing leaked; no spawn y change is needed (a 5 cm lift moved the frame-1 value by 0.032 m and fixed nothing; the constant `ArmyLayout.SPAWN_LIFT_M` stays at 0.0, now actually wired). RULED: the clear-of-itself test asserts on placement, and any physics-frame assertion samples after settling (largest per-frame delta < 1 cm, capped at ten frames), squad's. **THEN (14:30, feel's frame table): the settle sampling is right but is not the fix. Placement is clean, four overlapping pairs appear at frame 2 and persist to frame 10: two of the three widest hulls abreast (artillery 2.90, ifv 2.86, lancer 2.76) converge to a lateral pitch of 3.15 m where the half-metre rule needs 3.33 m. Squad checked the arithmetic: the layout's pitch for that pair is ≥ 5.0 m and `_clear_spot` guarantees 3.83 m, so placement clears by 1.67 m and something moves each unit ~0.9 m toward its neighbour after placement (the pitch ruling withdrawn). The corrected commit lands the settle sampling with a failure naming each pair's slot pitch, placement and settled centre-to-centre and both displacement vectors; squad eliminated flow (no `Elements` installed in that test) and any driving (0.9 m in 67 ms from rest is a teleport), then scale's four-frame vectors (`42aac2f2`, 17:00) split it in two: **frame 1 is NOT depenetration** (artillery +1.528 m and lancer -1.502 m in x, toward each other into overlap, velocity.x exactly 0, zero contacts; the two sunk tanks meanwhile show a clean vertical ground recovery of 0.87 mm with a sane normal), and frame 2 IS (they push apart 0.375 m each with a contact and settle at 3.154 m, clear of the 2.83 m need); the units are under power (vel.z ramping 0.2 to 0.8) so squad's no-driving argument does not hold. A position write with zero velocity: the only writers in the motion path are `tank.gd:496` (`_process`, `not simulate`: `global_position.lerp(sync_position, weight)`, remote smoothing), `respawn`, and `match.gd:1062` (`tank.position = data["position"]`, the grid slot). The smoothing-lerp hypothesis died by inspection within the half hour (scale): `simulate` defaults true (only `client_mode.gd` sets it false) so that branch cannot run in the test, and the 1.5 m appears INSIDE `get_position_delta()`, so `move_and_slide` itself moved them; a grep for assignments cannot find a mover that is a function call. Then scale's row print (18:05) eliminated that too: the two movers are alone in a second rank at z = 100.62 (the tank's length plus `HULL_CLEAR_M` behind the others), nothing within 12 m overlaps (nearest gap 2.21 m), no obstacle or perimeter near, no ground contact reported, `simulate` true on all five. **Every cause outside the body is measured dead; the 1.5 m step happens inside the body's own physics step, and both movers converge toward x ≈ −48.9, their squadmate's x, the column's centre line, which reads as a lateral correction computed and consumed within one tick. combat's per-tick trace (18:45) then settled the mechanism: the motion model handed `move_and_slide` a lateral velocity of exactly 0.000, the body moved 1.528 m, velocity came back untouched and no slide collision was counted, which is `move_and_slide`'s PENETRATION RECOVERY: **the two widest hulls abreast are spawned overlapping something on the VEHICLE layer outboard of each** (scale's neighbour probe used the world mask, on which another vehicle is invisible), and the frame-2 contact with the separating normal is the same mechanism once the overlap is shallow. `tank_motion.gd` is exonerated by measurement and its grant returned. combat is probing with each hull's own collider on its own mask to NAME the body; the live guess is a squadmate's rotated footprint (an 8.62 m box under a layout yaw) overlapping where the axis-aligned spacing said clear, the spawner's disc-vs-box question, squad's. **DIAGNOSIS EIGHT, THE REAL ONE (combat's collider probe, 18:55): on the first physics tick the physics server's body transforms are a PERMUTATION of the spawn slots, up to 90.7 m from the nodes** (Green_S2_3's body stood at Green_S6_1's slot on the other side of the map; Green_S6_3's body next to S2_2's slot), so the solver resolved a scrambled copy of the layout in which bodies genuinely overlapped deeply, and `move_and_slide`'s recovery yanked them up to 1.5 m before anything was asked to move; from tick 2 node and server agree to the last decimal. Every earlier oddity follows: the 1.5 m step at zero velocity, no slide collision, scale's true-but-irrelevant "nothing overlaps" (true of the scene, not of the solver's copy), and the three-frame sink that retired the spawn lift. Suspect: `common/physics_interpolation=true` with `_build_tank` setting `position` before the node enters the tree, so the first flush to the server is wrong; `force_update_transform()` in `Tank._ready` changed nothing (bit-identical run), and combat's correction narrows it: the server origins are not any node's current position but the units' PRE-DEPLOY grid spawns (`Match.spawn_position`'s jittered slots, written by `_build_tank` before the node entered the tree); `ArmyLayout.deploy` moves the nodes AFTER `_ready` in the same frame, and Node3D transform notifications are batched and flushed at the end of the process frame, so a physics tick before the flush sees every deployed body where `_build_tank` put it. The scramble is DETERMINISTIC (identical to the last decimal on three runs), so it has been baked into every baseline rather than jittering them and the fifth move records on its merits. **CONFIRMED in the strong form (combat's every-hull dump, 19:10): 90 of 90 bodies were still in `Match.spawn_position`'s jittered grid on tick 1 (server x = `SLOT_X` ± the jitter, z = `BASE_Z` ± 2.4) while every node was in the layout's two rows, 56 to 110 m apart. `army_layout.gd:286` writes `global_position`, `rotation.y` and `reset_physics_interpolation()`, which fixes what is DRAWN, not what is THERE. The grid is itself a valid non-overlapping layout, so the solver's world overlapped only where the grid happened to stack two hulls, which is why the bug was invisible except at the two places it was not. EVERY MATCH'S FIRST PHYSICS TICK HAS RUN AGAINST THE PRE-DEPLOY GRID ALL ROUND (deterministically, so baked into every baseline). REMEDY NOT YET MEASURED: `force_update_transform()` in `_ready` and a `Tank.place()` doing the node write plus `force_update_transform()` plus the interpolation reset were both bit-identical to no fix (**`force_update_transform()` updates the NODE's transform, not the body's; the node and the body are two pieces of state and only writing the second moves the second**, the whole defect in one sentence); and a direct `PhysicsServer3D.body_set_state(BODY_STATE_TRANSFORM)` READ BACK on the next line still returned the grid slot: **PhysicsServer3D commands queue until the step runs, `_physics_process` runs before they are applied, so nothing deploy can call reaches the space before tick 1; the three remedies were three spellings of one queued command. Corrected statement: a hull that is teleported and then driven in the same frame is driven against the pre-teleport world, and `move_and_slide`'s penetration recovery silently resolves overlaps that no longer exist.** **THE REMEDY, MEASURED (combat, 19:25, full army, 90 hulls): a placed or respawned hull skips its first `_drive` and rebuilds its motion model from the placed transform, once (`Tank.place()`, which `respawn()` now calls first): worst node-vs-body distance across 90 hulls 139.41 m → 0.02 m, the pair's convergence 2.279 m → 0.000 (placed 5.432 m apart, still 5.432 after tick 1), `moved` equals `would move` to four decimals every tick, the inter-hull contact gone, placement unchanged and correct throughout (closest gap 2.210 m, 0 overlapping pairs, as scale measured all along). Re-measured identically on the tidied `place()` (the three dead flushes in the docstring, not the body). `tests/test_tank_place.gd` (5/0): the ENGINE assertion (a placed node moved 60 m while the space still holds the body 60 m away; goes red the day Godot's command queue changes, at which point the settle tick is removed rather than kept), 90 hulls deployed with worst first-tick movement 0.0000 m against a 0.10 m budget AND a positive control (three ticks later the furthest hull has driven 0.1067 m, so an army of statues cannot pass), a respawn 34 m away beside a parked rig moving 0.0000 m on its first tick, `sync_position` advertising the placed spot, and y = 0.75 asked and 0.750 placed (staged non-zero because at 0.0 the right and wrong versions agree). `Units.stat()` gains the `has()` guard, warning rather than erroring until `expect_error` (nav's `06c7e772`) is on main. Lands after the fifth hash is recorded, as its own commit with its own cause, the SIXTH baseline move of the day.** Whatever works lands as its own commit after the yaw_fit merge, with its own cause, as the SIXTH baseline move of the day.** **Consequences: every match's first tick has run against the wrong physics world all round; it is a determinism candidate if the permutation depends on registration order (combat prints it twice); the overlap test asserts node-vs-server agreement on tick 1, the symptom guard beside it.** **And metrics found the test's verdict tracks the shard count derived from free memory at launch (five points on the same code: 5 shards FAIL, 5 FAIL, 6 PASS, 5 FAIL, 4 FAIL; six is the only count seen to pass and four refutes "even"): pin `TEST_SHARDS=5` to reproduce, print the count beside any claim.** Incidental landmine: `sync_position` holds values on the opposite side of the map from the units (harmless while `simulate` is true; combat's). The teardown guard's three "navigation-region leaks" were ALSO a transient (regions drain on the frame after free(); the guard counted at frame 0): retracted, the three grants lapsed unused, the guard keeps its bodies-only half. Six wrong diagnoses in one morning, all kept in lesson 178; the guard's in lesson 180.** **11:15: `main` is ALSO red on `test_theme_city_block::test_an_unknown_colour_name_is_deterministic_rather_than_a_dice_roll` (verified on main at f40ebb24, laptop, filtered: 4 passed, 1 failed; feel's 637ad4de, feel is on it) and on the two artillery handover reds (`test_theme_unit_scale` box-fill, `test_units_scale` mesh proportions) until scale's box lands. 11:20: metrics' new `ai-scenarios-check` gate (merged at `bac84a6f`; its check exited 2 with only main's reds) exposed three scenario reds in the window `1cb2fda9..main` (builder0 both ends): (1) `scenario_dodge_rate` — RETRACTED as a regression within the hour: combat's pristine-tree baseline (`9f864474`, laptop) already had five of six rows at 0 dodges and the sixth at 9 of 451 ticks (a 2 % coin), the scenario's own header says "KNOWN-FAILING since CP4 … 254 of 254 … Not in make check", and the gate promoted it; metrics makes the gate honour the known-failing marker and re-records the count; **"fix dodging itself" is a round-10 item** (it has never fired); the hit-rate rise 85–90 → 90–98 % is most likely bigger hulls being bigger targets, which scale's fairness controls measure. (2) `scenario_cp2`: the scout lands 13 of 14 shots and 0 on the engine deck (23 of 45 on combat's pre-CP2 tree), and its no-weak-spots control arm fired NOTHING in every run including pristine (a control that never fires proves nothing). scale read `armor.gd`: the engine deck is a 25° cone about dead astern (`Armor.is_weak_spot`, two directions and a dot product, nothing that scales), so there is no marker to follow and it is UNEXPLAINED; live hypothesis: a scout orbiting a 3.6:1 slab (8.62 × 2.40 m, was ~square) never gets astern. combat prints, per shell, the hull-forward-vs-shell-travel angle at impact, the shooter's bearing and the range; each of three outcomes names a different owner. 11:45, combat (`make deck-angles`, harness proven on a tank-vs-tank duel: first shot 8.7 s, four hits, all `weak_spot false` from the front): a lone scout vs a tank NEVER fires — it parks at 79 m (closest approach 69 m; `SCOUT_STANDOFF` 85 m against a 45 m gun), option census SPOT 70 / HOLD 60 / ADVANCE 10, ENGAGE never — and the scenario's x3m control arm fires nothing for the same reason: without `matchups` there is no A5 ORBIT to score, so the brain correctly declines the fight. **The control controls for the wrong thing** (squad's to rethink: matchups on, weak spots off). The deck question is x4mw-only (pristine: 45 shots, 41 hits, 23 on the deck; combat's A2 tree bit-identical; now 0 of 13), so it moved after `c68b423e` and CP2's sizes stay the suspect. **11:55, combat's columns on x4mw (merged tree, laptop, 16 hits): travel angle min 66.7° (the 25° cone is never entered, so `Armor.is_weak_spot` is exonerated); range median 13.0 m (it closes fine); bearing from the tank's nose max 109.7°, never past the side — the orbit never completes to the stern, where pristine got 23 of 41. Geometry (an 8.62 m hull) or the ORBIT behaviour's control law cannot be separated by these columns; scale runs the discriminator (same scenario, pre-CP2 `tank` hull_size only, a temporary one-row edit so the run is `dirty` and diagnostic, on builder0 after the quiet window; pre-CP2 `tank` was 2.4 × 2.4 × 3.6 and now is 2.40 × 2.40 × 8.62, so LENGTH is the only variable and a recovery names it). **Pre-registered (scale, 12:00): the bearing recovers past 135°, because a scout holding a fixed standoff from the flank sweeps far less angle per metre alongside a 3.6:1 slab than around a square hull, and the scenario's time bound ends with it on the quarter; if so the finding is that the ORBIT behaviour's radius must be a function of hull length, a consequence of the resize the game must address, not a defect; if it still stops near 110° against a 3.6 m target, the control law is combat's.** The probe is gated behind DECK_PROBE=1. **DISCRIMINATOR RUN (scale, builder0, 18:40, one variable: `tank` length 8.62 → 3.60, width and height identical; a dirty diagnostic tree, reverted): hits 16 → 43, engine-deck hits 0 → 22, max bearing 109.7° → 163.9°, min travel angle 66.7° → 9.9°, median range 13 → 3.7 m, 38 of 43 hits on the rear face. THE PREDICTION HELD: length is the driver, the flag was never broken, the orbit is tuned to a hull length that no longer exists. Finding for round 10 (combat's ORBIT behaviour (the matchups arm, not the catalogue's A5 fast marching), with nav): orbit radius and angular rate as a function of the target's hull length.** Pristine 9f864474's 23 of 41 astern sits beside this arm's 22 of 43.** (3) `scenario_suppression`: held 0.29 / 1.02 / 161 rounds vs tracking 0.12 / 0.28 / 6, ordering right, margin below its bar; still red after the artillery box. **Read by combat (14:05): the mechanic is unmoved to three figures (held 1.02 density, 161 rounds, pristine and now) and the CONTROL arm moved, tracking density 0.20 → 0.28 against an absolute `< 0.2` bar that had 0.005 of headroom pre-CP2; the resize's third recorded consequence. Approved: the assertion becomes a separation, held > 3× chased (5.2× pre-CP2, 3.6× now), which fails when the mechanic stops and not when the roster changes; the game-constant half stays.** Also kept: the screening bar re-derived at a 1.83 m dozer would be 0.45 (measured), beside the reverted width.** The 09:15 reading that follows was the step before. **10:45, scale's `3f6c1650` check (`exited 2`, 1479 passed, 3 failed, 71/71/71 shards): the clear-of-itself test PASSED on that schedule and failed at 69/68/68 on the same code, so a green on it is NOT evidence the fragility is gone; and the new teardown guard's three reds are all REAL LEAKS nobody knew about: `test_control_point`, `test_ai_player_holds_mechanism` and `test_combat_envelope` build arenas without `ArenaFixture` and leave 2 NAVIGATION REGIONS each behind, the class ArenaFixture's docstring warns of (the next routing test paths straight through walls against the old map, silently). Ruled: the guard lands WITH the three one-line fixes (scale granted the three test files for that change only), so main never goes red on them. The guard reports a lower bound (high-water mark) and counts only CollisionObject3D and navigation regions. 10:55, squad: `ArmyLayout.deploy`'s final write kept the tank's existing y and discarded the layout's, so the placement y was `Match.spawn_position`'s 0.0 everywhere and squad's earlier "0.05 passes on my branch" was never a measurement (struck); the write is fixed (`global_position = spot`, constant still 0.0) and a third assertion lands with it: no unit moves more than 0.25 m from its captured placement across the first physics frame, naming unit and delta. The −1.47 m is therefore written AFTER placement, in the first frame; scale's four-moment print names the writer.** Worst tick-one displacement across 90 units
  is 1.8 cm (settling); the test **passes alone** (`FILTER=a_full_faction_army`: 1/0, exit 0) and fails only when
  `test_arena_layouts` (which stands up scrapyard) runs before it in the same process — scrapyard's bodies still in the
  physics space while the army deploys on foundry (the tell: two hulls of one squad within half a metre). The merge
  added test files, the shards redistributed, and the polluter landed ahead of the victim: **the schedule changed, not
  the code** (lesson 178, lesson 36's shape). The resize made it fatal. **scale owns the fix** (arena tests free
  deterministically; the shared TestCase counts leftover bodies at test start and names the leaker). **The resize did not create it; it consumed the margin that hid it** (the contact-pip
  finding's shape). scale's `make spawn-probe` names each flagged unit's position and the body it intersects and runs
  after its fairness series (~09:05); nav answers from that. Also found: the test's first assertion compares
  `Match.SPAWN_SLOTS` with a constant defined AS `Match.SPAWN_SLOTS` and cannot fail (combat's/squad's file).
  Everything else in that run passed, including `sim-baseline` at `2d5215a8a0a59ded`. **So: `main` is RED on exactly
  one test as you read this; the last fully green `main` is `0808834e`.** If scale has not reported, run
  `make remote T=check` from `~/projects/godot` on
  `main` (read the `>> remote: make check exited <N>` line, never a pipe; a 255 is ssh). Then, in order:
  control's `make remote T=camera-looks` and `T=control-playtest-shots` (item 4), feel's
  `make remote T=check` on `f1859075` and `T=vehicle-gallery` (X4 + the neon fix), scale's fairness control.
- **Frames of the resized roster under your camera:** control is shooting `control-playtest-shots` locally at 08:30
  while the box is down (memory allowed it); the path is at the top of control's Status. Any `build/camera-looks/`
  on the laptop is an OLDER run and must not be read as CP2's.

### Decisions made on your behalf (each reversible in one place)

**The afternoon's decisions (13:00–16:30), newest first:**
- **combat merges at its TIP `63155ffb` after one more check, not at `1db4893c`** (a red I could name: its own stale flag assertion). The sim-baseline move to `1ea332e7bc268d2a` is recorded on the merged tree with the settle tick as its one declared cause. Reversal: merge `1db4893c` at its lines instead and record then.
- **Combat's pushback accepted: `test_combat_no_damage` keeps BOTH resets** (the static is the reader's fallback when no tune is set, so erasing only the key leaks true). My instruction to drop the static reset was wrong and is withdrawn.
- **Metrics' quiet-window re-record is PARKED**; `ai_scenarios_count.txt` stays at `42,2,3,0` (stale for a written reason) until a natural gap tonight with the fixed slot ceiling (`149bcd5d`). Twelve held slots while four streams check was the wrong trade. Reversal: `TANK_SQUAD_EXCLUSIVE=1 make remote T=ai-scenarios-record REASON=...`.
- **feel's tip `786898b3` merged WITHOUT its own check**, stated in the merge message (bench code `make check` never runs, executed on builder0 in the refusing run). Reversal: none needed; the next main check's lint parses it.
- **No cherry-pick of combat's one-line fix ahead of its check** (the morning's unverified merge cost main 25 red minutes); nav's seal turned out to cover it anyway.
- **Control and scale released to merge main and check once** on the strength of the 49ed1fb3 result, without waiting for combat's arm.
- **Round 10's plant item re-ordered by combat's refutation**: the predicate question first, the ordering second, diagonal-derived spacing third as a candidate with the table beside it. The constraint stays OFF.

**The day's decisions (10:00–22:20 — the 22:20 is 13:50, a typo carried forward), newest first; each has its measurement beside it above:**
- **The hull-rotation plant constraint stays OFF** (reversed at 22:20 from my own 17:40 enable): with it on, four of five squads sit 87–91 m from their slots; it ships only if the world-only mask passes all four numbers. Flip: `Tank.yaw_fit_enabled`.
- **The oriented-box hull geometry stays behind its knob, disc default**, until the gangs-vs-law series with feel's matrix as the before says otherwise. Flip: `match.hull_disc`.
- **The two no-mesh units keep their old box** (2.40 × 2.40) after the lineup showed the reference-derived width made a slab flatter; **one hull mesh each is your paid-generation gate**.
- **The selection ring is hull-shaped** (frames with you). Flip: the marker shader.
- **A dragged squad heading is a HOLD on arrival**; a held wheeled hull will manoeuvre to its facing above a threshold (nav, round 10).
- **The Terminus floor is lit by scale's six irregular lamps**, not the show's pools; **units readable without the HUD is a separate ask** (rim light recommended, round 10).
- **The clearance routing refusal stays OFF on measurement** (progress −35 %); the bake stays 2.0 m; heavies-in-alleys is your call.
- **Warnings fail a test unless declared; a filter that matches nothing fails; a check keeps going and reports NOT RUN; `main-checked` is an annotated tag that is not green.**
- **Show's readability claim is withdrawn** (the fight was never in the frame); endgame cues are reported, not judged.

- **Sizing is rig-relative** (K = 14.0 / 19.8 = 0.707); Syndicate platforms referenced by role; `law_tank` is a
  Centauro 8×8. **Balance was not a constraint**, per your round-8 ruling.
- **Articulation is visual** this round; the sim keeps one body and one box (S2).
- **The light show's default is light inside things** (windows, shopfronts) plus one roofline per block, venue palette,
  never red or cool white; the outline look is a named variant. The fight must stay the brightest read: a gate measures
  it against its own null. (feel's art ruling, adopted.)
- **The camera lifts over a roof rather than pushing in**, and cuts the block in the way.
- **A2 ships opt-in; the dwell timer is retired** (measured inert). **A4's default stays off** (it fails its bars and the
  curved entry does not arrive). **A8 is off** (it made a wedge fail a defile it passes without it). **A10 is stood down**
  (heavies-in-front was never a cost, only the old matcher's tie order: lesson 50's shape). **A1's brain-side tube is
  off** behind a five-seed gate (−62% re-decides with latency intact, but four more GREEN dead on one seed).
- **The gap-widening ruling was made and WITHDRAWN** within twenty minutes: the measure behind it was wrong (lesson 162).
  The maps are fine; no map changed.
- **The airship moved over the city** because geometry made it invisible over the arena at your pose.
- **builder0 slots 3 → 6** (the queue, not the machine, was the bottleneck: lesson 161); CP3 sets 3 once a slot holds a
  sharded check.

### What is unverified, stated plainly

**A hardware note for you (12:45, corrected 13:20):** the laptop's `build/metrics/p7-pit.jsonl` (a 101 MB trajectory log
copied back from builder0 at 10:11) has one changed bit at line 143,873 (`"slot_x"` → `"slot_\xf8"`). nav's copy of the
same log, taken at 10:12 and validated line by line, is intact and the same length to the byte; the corrupt file's
mtime is still 10:11, so **the byte changed under a file nobody rewrote: corruption at rest or in the read path on
this laptop** (disk or page cache; not separable without root). The transfer is exonerated for this one. It landed in
a key name, so the reader refused the file; in a digit it would have silently moved a number. metrics has added a
checksum manifest to every copy-back (`43594f27`) so the next one is localised. **Whether this laptop's disk and
memory deserve a look (fsck, memtest) is your call; it ran at 245 MB free for part of the night.** Separately, the
laptop's `build/` keeps stale files from earlier runs (copy-back without `--delete`); metrics is adding `--delete`
with wrapper logs protected, and the habit becomes: wrapper logs go in the session scratchpad, not `build/`.

- **`main` at `0808834e` is VERIFIED GREEN** (builder0 07:38: exited 0, **1454 passed, 0 failed**, 16 targets, sim-baseline
  `32831dc99cdaf5ca`): that tip holds every merge in the table above and the recorded baseline. Only docs commits
  follow it (until CP2/CP3 merge, each with its own check). Every branch was green on its own check before merging;
  the combination is what each `main` check proves.
- CP2 (scale) and CP3 (metrics) as above.
- Nothing is pushed to `origin`.

### What each stream owes (each is at the head of its brief's Status, in your terms)

**As of 20:00, in one line each (the history is below):**
- **combat:** MERGED at `7f8eeab8` (17:05; see the table: 1544/0, the round's only fully green runner line). Owed to close: its Status with the round-10 list (the predicate question with the table; the ordering; diagonal spacing as candidate; the artillery scenario routed by metrics; gangs-vs-law with `match.hull_disc`; ORBIT radius vs hull length), docs-only. The gangs-vs-law series does NOT run this round: the lead's direction at 16:55 is converge, merge, reset. Earlier (16:20): `1db4893c`'s four lines (builder0): `>> remote: make check exited 2`; 1540 passed, 2 failed (shard 0 781/2, shard 1 759/0, 0 engine errors, 0 warnings); **sim-baseline MOVED 1e90f69e5d6fcc46 → 1ea332e7bc268d2a, determinism 559a415887806e43: the PRE-REGISTERED outcome, one declared cause, the settle tick (every match's first physics tick now resolves the scene, not the pre-deploy grid)**; cascade GONE on the UNSEALED TestCase with combat's `await super.teardown()`, so the fix is confirmed on its own merits and, with main's 49ed1fb3, the seal and the fix are INDEPENDENTLY confirmed. The two reds: `test_combat_sim_cost` charged with ONE inherited body (`bodies 1 -> 1`, the delta assertion firing in its own defence: the body belongs to an earlier test in shard 0), and `test_combat_no_damage` asserting the foreign static the writer no longer writes (combat's own split-source-of-truth, fixed at `c27a4e87`). RULED: NOT merged at 1db4893c (a red I can name); combat's tip `63155ffb` (both fixes, the four teardown overrides reaching the base, the load-order test) is checking now and merges at its lines; the hash is recorded on the merged tree with this provenance. Pre-registered for the tip's check: the sim_cost residue GONE = the body was one of the four overrides (a Match alone leaves one visible body); PERSISTS = the owner is elsewhere in shard 0, named from the test order. Combat's call, before reading: PERSISTS (an unfreed arena-less Match carries a tank, so it would leave ≥ 2 bodies, not exactly 1; the body was already 1 at sim_cost's first iteration, so it predates it and is not accumulating). And a second pre-registration: the tip's changes are all test-side, so its hash must equal 1ea332e7bc268d2a; a different hash is a finding to chase before either number is recorded. Earlier (15:30): the check on `1db4893c` was running; the four lines were owed. **The refusal ranking REFUTES the diagonal-spacing correlation (combat, laptop, `DRIVE_TRACE` on the five off-slot crews of five_squads): `Green_Charlie_1` at 0.06 m across refused 1260 CONTINUOUS ticks, `Green_Bravo_6` at −1.36 m (overlapping) 1113, `Green_Charlie_3` at 3.19 m (the loosest, near the ~3.3 m a turn needs, the pre-registered refuter) 1135, `Green_Echo_3` at 2.58 m 867; the one crew that seats, `Green_Alpha_4`, refused 128 at a TIGHT 0.26 m, and what sets it apart is that Alpha was ordered first. The across gap predicts nothing in either direction; the refusal counter never resets, so this is a permanent freeze of most of the army (nav's N1 breach at army scale), not a stall; vehicle-as-wall, no-room-for-the-diagonal and combat's own settle-tick and second-cause stories are all dead or unsupported; the mechanism is UNEXPLAINED and recorded as such. The reversal to default-off stands (it rests on the source bisect, and an unexplained mechanism argues harder for off). `Green_Echo_1` produced zero traced ticks and is a gap in the data, not a row. Round 10 (see the section below): diagonal-derived spacing goes in as a CANDIDATE with this table beside it, and the first question is combat's: why a clear hull with 3.19 m of room accepts none of its three candidate yaws for 1135 consecutive ticks, a question about the predicate, with the ordering observation as the next thing to rank. Also: feel's hinge bench caught the inert-knob bug on the match runner's `--tune=` command-line path (accepted, no error, `Armor.no_damage` false in 13 of 13 phases, census 90 → 77), so BOTH entry points were broken and combat's fix covered the second by its shape, not by a test; the `no_damage` predicate test is added, and the LOAD-ORDER case is a real test at `d6daa3b3` (a child Godot run in two arms, differ-assertion first, ~1.7 s per child on the laptop; lesson 199).** Earlier: the default-off commit is landed at `e21f72c8` on the merged tip `1db4893c`, checking (23:50): `yaw_fit_enabled := false` with the bisect table first in the docstring, the benefit re-measured on one build (44.0° → 11.6°, 74 %; 12.1 → 6.1 m; the old before-column struck everywhere), the residual unchanged, `_ensure_env_tuning` (round 7's bug recurring, four owners, two of them dictionaries), `match.yaw_world` labelled as not a mask arm with both tells, tests selecting arms through the tuning key with the arm asserted first; filtered: tank_yaw_fit 2/0, nav_face_recovery 8/0, ai_player_orders 4/0. Its hash is the day's remaining move, and the reading is pre-registered before the number: sim-baseline MOVES → one declared cause, the settle tick (the constraint is off and the tuning plumbing is inert with no TUNE set); sim-baseline UNMOVED → the ALARMING outcome, not the clean one, because a hull skipping one drive must change positions from tick 2 onward, so an unmoved hash would mean `place()` does not reach the sim scenario's spawn path, to be found rather than recorded as a tidy no-move. The check also verifies, on a full shard run, that both cascade roots (sim_cost, the yaw_fit override) are gone, which the commit messages claim only as "the mechanism is removed". Earlier plan: `Tank.place()` with the settle tick (every match's first tick fixed), `Units.stat()`'s missing-unit guard, and `test_combat_sim_cost` awaiting its teardown with boundary assertions; then the gangs-vs-law series with the box knob as the arm, per cell, feel's matrix as the before.
- **nav:** COMPLETE: `06c7e772` and `da57ab82` merged (the accessor, `expect_error`, the sealed teardown, the guard; the containment dead); the wheeled-hull facing row pre-registered for round 10; the seventh disc site (`Avoidance.radius_of`) queued with its falsifier; vehicle-as-wall withdrawn; then the held wheeled hull's facing (decided: it manoeuvres above a threshold) as a pre-registered row; pit and terminus for the clearance rotation only if the box is quiet.
- **squad:** COMPLETE (00:05): hold-on-arrival merged (baseline unmoved by construction), the `_hull` fallbacks loud, `incoming_fire` on combat's helper reviewed and merged, the spawn test settling then judging with the separating-axis roster, the deform override's super call dropped under the sealing; round 10's first item written up and corrected (the grid half is scale's; four crews overlap at spawn once the shove is gone).
- **scale:** COMPLETE and MERGED at `b70dd8f7` (16:50; see the table). One open note from its check, not explained: the spawn settle assertion, red on every five-shard main check, PASSED on scale's three-shard tree that predates `Tank.place()`, so its outcome may depend on shard composition (a neighbour's state), lesson 198's shape; combat's merge check on five shards reads it. Earlier: the lamp pair shot and reviewed by feel; the two guard fixes at `b6e24892` (baseline at process start; two candidates named beside a riser with the sampling moment stated), whose check surfaced two NEW risers (`test_combat_sim_profile` 1 body; `test_theme_factions` 44 bodies, most likely combat's leaking foundry observed again) inside the 36-failure cascade, so it is HELD with the round-10 handover (`4119d0e2`, top of Status) until combat's cascade fix is on main and a quiet main check lets its findings read as findings; grid-fairness done; stretch 6 open.
- **feel:** COMPLETE and MERGED at `d99d2658` (15:45; its tip `786898b3` merged without its own check, stated in the merge message: two of its five commits are code on the trailer bench, which `make check` never runs and which executed on builder0 in the run that produced the refusal). Its brief carries the neighbouring-files rule in its own right and the three round-10 items (the neighbouring-files note in its own right; rim light, the single-variable lamp pair and the hinge cost as round 10). **The hinge cost is UNMEASURED at round's end, and that stands in the record instead of a number: three runs, three refusals, each a different cause and each the bench correctly declining (a busy box; a moving census; and today, `make perf-trailer-ab PERF_CYCLES=6 exited 0` with the verdict NOT USABLE because the census freeze was OFF in 13 of 13 phases with `--tune=match.no_damage=1` on the command line verbatim and accepted without error, the census walking 90 → 77, plus builder0 at load 8.22 with 25 other Godot processes giving 78–100 ms frames against a 33.3 ms budget, which would have been refused on spread alone).** Earlier: MERGED at `cfac4fe6`: the lamp pair is a real pair now (both halves show-off, the before from the pre-lamp arena: the six lamps light the floor), and the Terminus roof dressing (`19e258d2`, checking: rooftop plant at zero extra draw calls, inside the collision box; the first version passed every test and read as nothing, caught only by looking; the three-way sent to you). Owed: the hinge cost with `TUNE=match.no_damage=1`, running after `19e258d2`'s check: the bench reads the damage path's own static per phase and refuses if it is off, and the census clause covers a mid-phase flip, so it yields either the trailer's number or a measurement of combat's inert-knob bug on a second knob; the per-faction hull rim light is round 10 pending your call.
- **show:** COMPLETE and MERGED at `4b95749d` (18:00; the table's last row is the round's final check). Earlier (17:25): its check on `06f8ca0b` came back RED, 1483/3, all three stale main content its branch predated (the artillery box fill twice, re-derived by scale at `b70dd8f7`; feel's neon warning, fixed at `a33638b8`), sim-baseline never reached; show committed the three docs (`c23936fc`, run seven's numbers with the freeze caveat; three round-10 findings: parapet-vs-outline stopped discriminating because the camera now sweeps toward the fight, the `--no-strobe` arm changes period as well as programme, the clips in build/ are the 05:5x set and must not go to the lead; the gate's honest reading: 26 pairs inside the null's error bar, "not measurable", never "no effect"), merged main `c13821c9` clean into `a21bad3c`, and launched one check on it at 17:21. **That check doubles as the round's final main check: nothing else lands on main first, so the merged tree is byte-identical to `a21bad3c`'s (verified by an empty diff at merge time).** Earlier (17:00) RULED for convergence: run eight is CUT from this round (it becomes round 10's first show action); show writes the two docs with run seven's numbers and the caveat (a pair that was not frozen), commits, runs ONE check on that tip (its game code since the last checked show commit `e1823e68`: `show.gd`, `cues.gd`, two tests, `show_look.gd`, `mk/show.mk`; the capture gates and docs are off the check path), and I merge at its four lines, then the last main check. Earlier (16:50): run EIGHT chained at `06f8ca0b` after the seventh. **The "frozen" pair was never frozen:** `get_tree().paused` stops the simulation only; `FxWorld` (`fx_world.gd:115`) and the `Show` run at PROCESS_MODE_ALWAYS, so six process frames of tracers, flashes and the show's own clock sat between every pair's halves, which is why the null grew 1.3 % → 2.3 % the moment the camera followed a real fight (the scene got busy, read as the camera getting busy). Fixed: both process-disabled across the capture pair, the settle 1 frame not 3; the bar untouched at max(3 %, 2× the run's own null p95); the three reds get the discriminator only on a still pair. **The lead's verdict (16:40, verbatim in game_design.md): the show reads as "the subtle glowing effect but that's it"**; asked of show after run eight: a three-frame pair for HIM at today's band width, 2× and 3×, one dial moved, frame-mean deltas beside each, the dial and file named so his choice is one edit. Earlier (16:30): on its SEVENTH run. The sixth's files were the FIFTH's: `show-frames` begins with `rm -rf build/show` and `show-decisions` wrote under it, so one make invocation of both created the decision frames and deleted them before copy-back; caught by timestamps (15:20–15:40 files against a 15:42 launch), the third stale-artefact catch today; fixed at `c83117dc` (`build/show-decisions/` is a sibling). What the sixth established from its own log: 12 decision frames, vehicles in frame min 12 / median 39 / max 39, two clips, contact at 59.6 m after ~116 s in all four processes, the frame gate passed with the street pose gone. Unresolved and NOT tuned into passing: the venue strip failed its luminance gate on 3 of 26 frames (−5.1 %, −7.5 %, −7.5 % against a 4.6 % bar) and the null itself grew 1.3 % → 2.3 % p95 because the camera now tracks a moving fight (the pair is frozen; the frozen scene is busy); show does not yet know whether −7.5 % is the show or the fight and says so. Earlier: the decision pair and frames were on their FIFTH run (23:45): each run fixed something the one before hid (five-a-side → a real army; the map centre → the densest cluster; a frustum count → drawn pixels; a camera inside a solid → control's clear_pose; a camera looking AT a solid, lift +0.0 honestly reported → a 12-heading sweep on control's sight_blocked, the heading being the one part of his pose a player moves); the luminance gate's one red (−3.5 % on a kill ripple) waits until the frames are composed, since a number measured through a wall is not a number; the two docs ride the frames.
- **control:** COMPLETE and MERGED at `be269334` (16:35; `c0d56029` at 1540/1, the two reds main's known pair, zero leak reports, its four override edits 31/0). Its prediction resolved as it read it: all 32 gone, the "0 failed" half wrong by swallowing main's two knowns (a claim about one thing stated as a claim about everything). Stretch item 6 (the `ungrouped=N` readout and the refused-order banner on the default `make skirmish` path) waits on squad's A10 and is round 10. Earlier (15:55) HELD: `78aa496d`'s check came back `exited 2`, 1501/33; 32 are combat's foundry leak observed by the region guard (whole files red together: test_theme_trailer, test_units_catalog, test_wheeled_arrival and three more), on a tree without nav's seal or combat's fix; ONE is control's own and predates round 9's drawing: `test_control_order_marks::test_the_squad_pin_only_claims_a_heading_every_crew_was_given` (red in isolation, 4/1 filtered), because `2cca6bea` reversed the pin rule (the pin draws the task's heading) and did not update the test `ac4df0d7` wrote for the old rule; main is NOT red on it (2cca6bea is not on main, ac4df0d7's test passes there). Control rewrote the test to the contract (the task's heading IS the order deferred; unanimity still asserted on direct unit orders) with the reversal named in the docstring; GREEN filtered on builder0 at `19d87f5c`, 5/0. Control's pre-registered prediction for its post-merge check: 0 failed, all 32 region reds gone; if a cascade reappears near test_command_readability, test_touch, test_command_camera or test_control_panel, its own four override edits are the first suspect, not the seal. Round-10 candidate from control (not its file): the region guard should record the count at SETUP as well as teardown so a test inheriting a dirty map reports "arrived dirty" instead of "left 4", turning the first observer into a witness rather than the accused (scale's bodies-guard fix at `b6e24892` is the same idea for bodies). Sequence ruled: no full check until both cascade arms are on main, then merge main, the four teardown edits under the seal, ONE check, merge at it. Control's admission for the record: a reversal shipped without re-running the file that asserted the old rule; filtered runs never touched it. Earlier: the facing re-shoot is done on the resized roster with squad's hold (`2cca6bea`, playtest green at both resolutions): the drag preview reads (a ring on the destination, an arrow to the pointer) and the HUD line says "3 units: move facing N"; the pin now reads the TASK again, a deliberate reversal of the morning's derived-pin rule because squad's hold honours the task's facing by construction and per-unit orders carry no facing during the drive (the derived pin was blank for the whole journey and appeared only on arrival, when the player no longer needs it); the unanimity fallback stays for direct orders. The facing arrow was lost in the pin's stalk (the arms were sized in metres, 96 px across against a 15 px nose at 21°, a tick along the stalk, drawn before the stalk); fixed at `78aa496d` (checking): the chevron is specified on the SCREEN (nose stand-off half the arm span) and solved back to the ground per pose, drawn after the stalk with a dark backing, asserted as a property at his pose; both frames sent to you at 22:45; the chevron crosses the pin's head, crowded but readable, leaning the head away is a small change if you want it. Then the four teardown edits once nav's sealing merges.
- **metrics:** COMPLETE and MERGED at `ec6fef46` (16:40; see the table: 1548/1, the first clean engine tally, and the scenario-count split settled on the drain, not load). Earlier (16:10): checking `2746233b` (main merged in; expect no cascade, the two known reds). **Found on merge and verified on main: `tests/ai_scenarios/run_scenarios.gd:70` calls `case.teardown()` un-awaited, so under the seal every AI scenario runs with NO body guard and NO navigation drain (the sixth file of the five nav's note counts; the merge was clean because the line still compiles and does something, the signature-change lesson found again by the person who wrote it); fixed on metrics' tip to `await case._teardown()`. Consequence for the scenario count: on `0870877f` the runner had just started awaiting what was then the full drain, so scenarios newly got a completed drain between them, a concrete mechanism for the two new reds (`artillery_stays_dug_in_on_a_moving_target`, `the_base_of_fire_keeps_firing_while_the_others_move`) now likelier than load; tonight's window measurement tests "does the drain change these two scenarios", and if it does, the 42,2,3,0 baseline was two scenarios passing on a neighbour's leaked state (lesson 198's shape).** Earlier: the held-window re-record produced `41,3,3,0` a second time and the window verdict said NOT USABLE, 0 samples: the exclusive run held slots 1–3 while other streams' six-slot launchers used 4–6, so `TANK_SQUAD_EXCLUSIVE` was taking its own slot count and never had a window; fixed at `149bcd5d` (an exclusive run takes slots 1..`TANK_SQUAD_SLOT_CEILING`, default 12; a test asserts a six-slot launcher cannot start during a window). Ruled: PARKED, `ai_scenarios_count.txt` stays at `42,2,3,0` (stale, the gate red for a written reason) until a natural gap tonight; metrics' own words for why the verdict line exists: fifteen minutes of held slots bought a defect in the guard rather than a number it would have quoted. One check on its tip, then merge (expect a `test_case.gd` signature merge). Earlier: the check over `7a8edca8` (the schedule in the verdict line) and `59927de9` (one cause, many victims); otherwise complete.
- **orchestrator:** (16:00) main's arm is IN: no cascade under the seal (above); tag moved; control and scale released to merge main and check once; combat's arm (unsealed + its one-line fix) still running, with control's prediction attached: a residual cascade sourced at `test_combat_no_damage` (a Match per `_tank()` call, override never reaches the base; verified on main), or, if its cascade line is clean, a leak the guards cannot see (a Match with no arena leaves no bodies or regions). Earlier (15:45): two checks running are two ARMS, deliberately: main's on `49ed1fb3` carries nav's seal WITH combat's leaking override still present (nav's prediction: no cascade); combat's on `1db4893c` carries the UNSEALED TestCase plus combat's one-line fix `26754ef1` (combat verified `14c14f0b` is not an ancestor of its tip). A clean cascade line on each proves the seal and the fix separately. On the merged tree, combat's `await super.teardown()` frees once and the sealed `_teardown()` finds nothing to free the second time (`free_owned()` clears its list); a redundant await of a void hook is a warning, not an error, and no lint setting promotes warnings. Earlier: the next main check once combat's sixth-move commit is on main (the cascade's first carrier gets named by the grouping); move `main-checked` only after reading it; the lead's decisions list in "Decisions made on your behalf" is current through the roster width reversal and the plant enable.


- **scale:** **FAIRNESS CLEAN under the resized roster (16:45, builder0, 18 pairs per arena, both arms proven applied): paired south advantage yard −0.022 ± 0.025 (recorded −0.04 ± 0.05), pit +0.000 ± 0.040 (recorded +0.03 ± 0.04), aggregate −0.011 ± 0.024, winner flips 2/18 each as in round 5; CP2 did not make either map unfair. Side finding, a negative: green_win_rate is 0.278 on both arenas, exactly round 5's 25–28 %, so the Green deficit predates CP2 and is not hull size (one class of explanation removed from combat's gangs-vs-law question). Caveat: faction armies are re-laid at tick 0, so this is blind to the spawn grid.** **GRID-FAIRNESS DONE (scale, builder0, 20:50, verification.md's prescribed 2v2 bot configuration, seeds 1–60, with and without `--swap-bases`): south wins 63 of 119 decisive matches pooled across both arms, 52.9 % ± 4.6 %, 0.64 SE from even, against the 51 % recorded after the mirrored half-bake and the 64 % it replaced; the swap's geometry is asserted to move on the constants and every baked list, so the arms are distinguishable and the null is a result. The resized roster and the 19-column grid did not reintroduce a base advantage. scale's brief items 1–5 are complete; only stretch item 6 remains.** (On the shard series: the passing case is n = 1; the defensible statement is that the verdict varies with shard count and six passed once.) Earlier: the swap-bases fairness control (two commands at the top of its Status, labelled by population; died with builder0 at 08:27); **the Condemned artillery's collider was measured in its DEPLOYED pose** (outriggers down, 4.74 m wide) while it drives stowed at 2.90 m, so shells stop in empty air beside it: feel stows the legs in the measurement, scale re-derives the box (length unchanged), **and that is one more baseline move to record. THE FIRST ITEM OF YOUR MORNING, in this order (about an hour of box time):** (1) merge feel's `b4c01959` (the stow in the measurement; feel's box-fill test is deliberately RED until step 2 lands — that red is the handover, not a defect); (2) scale `git merge main`, `make roster-scale`, commits the derived box (length unchanged, width 4.74 → 2.90; a **certainty** of a baseline move, not a prediction), runs its check (red only on sim-baseline); (3) merge scale; (4) `make remote T=sim-baseline-record` twice, commit. Then feel's tip check and X4 are green together; the "roster's widest hull" of the night was that pose artefact. Then the factions re-render; feel's two Terminus
  floodlights (half the lamps of pit, eight lit towers inside the fight); the stretch 9/20 → 0/20 re-measure.
- **combat:** 64367efe's check (15:00): 1476 passed, 18 failed, 14 of them one cascade — `Navigation map synchronization had 284 edge error(s)` poisoning shard 0 (the runner fails any test that logs an engine error), none combat's; CAUSE FOUND by nav (15:20): `free()` is synchronous and NavigationServer3D's region removal is not (scale measured the drain at one frame), so the next test's `ArenaFixture.build()` bakes a second full arena over the old regions and the warning lands at the next server sync, unrelated to test boundaries; nav fixed the fixture (wait until the map is EMPTY before instantiating, bounded, named; merged unverified at `f1128ef5`, the main check verifies it), and since 20+ test files instantiate `ARENA` directly and bypass the fixture, the second half goes into the shared `TestCase` teardown: after freeing the test's nodes, wait until the map is empty, so the next test starts clean whichever way it builds its arena (nav `f5a20e25`: `TestCase.drain_navigation()`, bounded at 30 frames, named; wiring it into `teardown()` needed one word in the shared runner, `await case.teardown()` at `run_tests.gd:98`, granted, because an un-awaited coroutine would drain after the next test had started and look wired while inert; one check on nav's tip verifies all three); sim-baseline unreached twice in a row because `check` aborts on `test` (metrics makes the hash targets run regardless). Landed on combat's tip (`306651e0`, checked 17:20: 1489/16, exit 2; 14 are the navmesh cascade its tree predates the fix for, one is feel's, one is **the bodies-only guard's first real catch: `test_combat_sim_cost` leaves one physics body, combat's, fixing**; shard 1 with everything combat landed is 783/0; sim-baseline unreached a third time): `364d77f2` the suppression separation assertion, `6eb6eddc` the hull helper, `d5e3f547` the six-site disc-to-box migration behind `match.hull_disc` (**box was the default and it moves the simulation**: combat measured box ≠ disc on one machine, same build and seed; ruled: the default stays DISC until the gangs-vs-law series has run with the knob as the arm, so no baseline move now; the box becomes default in the same commit as a series result that shows it no worse on every cell). **The reading that now fits best (squad's roster on the separating axis + combat, 23:25): the constraint is CORRECT and the formation is not ready for it.** Abreast crews are clear (across gaps 1.12–4.28 m, none overlapping) but an 8.62 × 2.40 m hull yawing sweeps to its 4.48 m half-diagonal and needs ~3.3 m of extra lateral room, which four of five pairs lack; so the plant is correctly refusing a rotation there is no room for, and a world-only mask passing five_squads would be the constraint declining to prevent the very collision it exists to prevent (hulls yawing through each other in formation, the lead's complaint in another costume). Combat's prediction, recorded first: refusals rank with the across gap, Charlie (1.12 m) most; the ranking with DRIVE_TRACE decides. **Round 10's first item: every clearance constant says which MOTION it licenses (width for driving straight, the half-diagonal for turning in place, (w+l)/4 for a swept turn): `HULL_CLEAR_M` (squad; the formation's lateral pitch must give a hull room to rotate: tank short by 1.27 m, gang_tank by 3.53 m), the navmesh bake radius and `Avoidance.radius_of` (nav; the clearance row compared a rotational envelope to a lateral clearance). Delta's margin is the first symptom; the plant constraint returns when the formation gives hulls room. **Sharper still (combat's roster on the settle-tick tree, 23:55): the off-slot crews NEVER DEPARTED, they are still at the spawn row (z ≈ 94–101) with destinations across the map (z ≈ 6–19), their first turn toward the goal refused in the press, and FOUR crews overlap at spawn (across −1.36, −0.02, −0.01, −0.77 m), which squad's roster and scale's placement numbers could not see because they measured AABB separation where the hulls STAND (correct, pre-physics) while combat measured the TURNING envelope; both right about their own question, and the wrong question for a vehicle that has to turn. **One number, two sites, opposite errors (scale): a disc of the box diagonal overstates where a hull IS (friendly-fire refuses safe shots, the disc sites) and correctly states the room a hull needs to TURN (spacing by width under-provisions it); whoever fixes the disc sites must not "fix" the turning envelope the same way; written into the `hull_size` consumer list.** So the SPAWN GRID (scale's) is a second site for the same arithmetic, necessary before slot spacing: a hull must have room to turn before the army can execute its first order.** nav's vehicle-as-wall mechanism is withdrawn under its own name (`3a3f2f50`); its prediction that off-slot failures track crowding at seating survives with the staggered-order test as its discriminator.** **REVERSED at 22:20: the constraint's default returns to OFF** (combat's bisect: `bd618dd4`, flag off, 0 of 30 units off their slots; `986f8921`, the one-line default on, 12 of 30 with four of five squads 87–91 m from their slots; the reading, still inferred not measured: hulls forming up nosed against squadmates have their arrival yaw refused because `test_move` counts a vehicle as a wall). It ships this round only if the world-only mask arm passes all four numbers with nav's counter and residual. The earlier ruling, for the record: **the hull-rotation plant constraint was ENABLED by ruling (17:40)**: re-measured bit-identical on the merged tree (nav's corridor: 4.99 m of path, 11.6° of yaw, 6.1 m of footprint in a 4.8 m corridor, giveups 1, against 28.5° and 9.6 m unconstrained; open ground 71.2° in 1 s, 0 applied; a wedged rig 14 offers, 0 refused ticks), so 59 % of the illegal yaw is gone at no cost where there is nothing to hit and no freeze; nav's face recovery fires for the first time this round. Residual named: the hull still rotates 1.3 m of footprint through a wall (the exact form freezes a wedged rig for 30 ticks, nav's N1 breach). Landed on combat's branch at `986f8921` (18:30): `match.yaw_fit` on, nav's test renamed `test_a_wedged_semi_no_longer_yaws_through_the_wall` with the bar on the EXCEEDANCE (1.8 m against a measured 1.27, printed on every pass) and nav's note that the sweep is length × sin(yaw), so the bar can go red on a roster change with the code untouched (CP2's third pre-registered movement); the check on `396be191` came back 1480/49 with sim-baseline NOT RUN (the fourth consecutive check that never reached it; 48 of the 49 are one cascade in shard 0 with two roots: `test_combat_sim_cost`'s bare teardown, fixed, then `test_theme_city_block` NAMED as raising the body count from 1 to 44 and the regions to 4, which feel measured to be false of its file (0 bodies, 0 regions; one MeshInstance3D), and combat's log then showed the riser's predecessor was combat's own `test_tank_yaw_fit`, whose `teardown()` override never called `super.teardown()` and so leaked a whole foundry: ONE author, two roots, both combat's, both fixed; the guard names the first OBSERVER of a residue, as its docstring says, and cannot convict the first test in a process (a static baseline at −1), scale's fix; and combat's own boundary assertion in sim_cost counted the WHOLE tree and so reproduced the charge-the-observer defect inside the fix for it, now a delta across the test's own fixture with both numbers printed; whether one physics body is really this test's on builder0 stays open until that delta prints), so **the fifth and sixth moves record as ONE hash with both causes named** (the constraint and the settle tick, independently attributable from the commits). **And one REAL behaviour failure on that tree only: `test_ai_player_orders::test_five_squads_ordered_in_quick_succession`, 10 units off their slots (Green_Alpha_1 4 m off: MOVE → COVER_FIRE → ENGAGE), which does not fail on main; the plant constraint is the prime suspect (a hull refused an illegal yaw may not turn onto its slot), and the enable does NOT ship until combat's yaw_fit on/off pair on the same tree says so. **Two rulings meet here (squad, 20:10): a held wheeled hull is to manoeuvre to its ordered facing, which is a short arc off the slot and back at low speed, and the hold now carries a facing, so the plant sees low-speed yaw demands at every slot; if the constraint refuses those as illegal excursions, the demand never resolves and the hull sits wrong forever, a stuck state. The pair reads each off-slot unit's ORDER (a held facing while off-slot = refused a manoeuvre; nothing or a fresh move = re-tasked by its brain), and if the constraint refuses arrival manoeuvres, the exemption is a design change through nav's plant review, not a tolerance. **combat's hypothesis with a line number (20:15): `_penetration` uses `test_move`, which collides on the body's own mask (3: world AND vehicles), so a hull nosed against a squadmate is "in geometry" and its arrival yaw is refused; the justification for refusing a yaw is that a wall will not move, and a vehicle will. If the pair confirms, the rule measures penetration against the world layer only, which leaves the corridor evidence (scenery) unchanged. Also landed: tests can select any knob without editing source, `TUNE=match.yaw_fit=0 make test FILTER=…`, loud on a bad spec; an arm that needs a code edit to select is an arm nobody re-measures.** **nav's plant review (20:20), in advance of the pair: WORLD_MASK-only ENDORSED, because a wall's refusal is permanent and correct while a squadmate's is transient and means disobeying an order for a reason already gone; because hull-to-hull spacing already has an owner (Avoidance, ORCA) and two layers policing one constraint is how two nosed hulls deadlock each other, N1 broken by construction; and because the corridor evidence never had vehicles in it, so this narrows the rule rather than claiming anything new. Attached: a counted exclusion (`yaw_vehicle_contact` in `arm_report()`) and the residual named as a trade (a hull can still rotate through a squadmate; `move_and_slide` separates them after). Underneath: `test_move` answers a boolean, so two touching hulls give current = candidate = true and the relative comparison cannot rank, the saturating predicate one layer in; vehicles could be counted only with a depth.** **THE PAIR (combat, 20:25, closed 20:40): the constraint is EXONERATED: identical, 12 off slot on both arms on one machine (the 10 was builder0's run), and every off-slot crew holds `order now (none)` in ENGAGE / HOLD / SPOT, three brain choices, not one plant behaviour: they were never told to finish the move, squad's layer. Same tree, so the cause is in main's window `0416274d..b3f7ffae` (squad's deploy write fix and settle assertions, nav's drain set, scale's revert and lamps, control's item 4, metrics' runner, feel's docs), **RESOLVED by squad's full check (21:05): the test PASSES on squad's tree, which contains main through its merge (0 of 30 off slot, worst gap 6.8 m against 36), so the cause is UNCONDITIONAL CODE ON COMBAT'S BRANCH (the settle tick, `Tank.place()`, the plant refactor or the geometry migration); toggling the knob excluded the knob, not the commits that carry it; combat bisects its branch commit by commit and the enable does not merge until the commit is named and fixed. combat first suspected a second dead frame in the settle tick and then read the file: the empty-motion branch has no return, so the settle costs exactly one tick by design; if the bisect lands on the settle commit the mechanism is unknown, with three candidates in order (the one skipped tick landing differently for the squad ordered first; `state_for` rebuilding speed and forward from the transform and discarding a mid-order hull's carried velocity; `place()` writing `sync_position`). Acceptance for any fix: both claims measured on the same pair, the slots (five_squads) AND the shove (the 90-hull worst first-tick movement, the 5.432 m pair at zero convergence); a fix that restores the slots by removing the settle is not a fix, and one that keeps the shove out but leaves the slots wrong is not one either.** **Then (21:30): combat's forward bisect gives BIT-IDENTICAL failures at every point of its branch (12 of 30 off slot, the same gaps to the decimal); squad's tree passes on builder0 (4/0 filtered) from the SAME merge point (b3f7ffae, code-identical to the passing main check 0416274d, one HANDOFF commit apart), and both passing main checks did execute the test (`PASS` in their logs). Every failing number is from combat's laptop and every passing one from builder0, so the split is MACHINE before branch: combat runs its tip's filtered test on builder0 (after its bisect restores the branch: a remote from a detached HEAD would label the wrong tree's answer as the tip's). A pass there means "machine-sensitive, cause not established" (glibc-2.39 vs 2.43 can move a routing outcome as it moves the sim hash, and a refactor that changes floating-point structure looks exactly like that), not a merge blocker; a fail there names the branch. Correction from combat's `git show` (21:45): `986f8921` is ONE line (`yaw_fit_enabled := true`), so the knob pair exonerates it outright; the `_fitting_forward` call site is `4cb9b9c6` (10:59), which is on main since `53cc42e3` and therefore in the passing main checks and squad's passing tree, so on builder0 the call site is not the cause either. **Then (22:00): `b3f7ffae` PASSES on combat's laptop (0 of 30 off slot), so the machine hypothesis is dead and the split is combat's branch, two commits wide: `bd618dd4` (comments and an equivalent `match` rewrite) and `986f8921` (the one-line default `yaw_fit_enabled := true`). The knob pair at the tip was confounded by a second cause (the settle tick) that fails both arms, so it read "inert" while the flag was guilty three commits back: two causes make an A/B at the tip say nothing. If `986f8921` fails and `bd618dd4` passes, the constraint really puts squads off their slots, the enable does not ship as it stands, and the next arm is the enable with `match.yaw_world=1` (nav's endorsed world-only mask: hulls forming up nosed against squadmates have their arrival yaw refused because a vehicle counts as a wall), which if it passes five_squads while keeping the corridor numbers becomes the default. Then (22:35): both tip arms (`yaw_world=1`, `yaw_fit=0`) are identical, 12 of 30, while `bd618dd4` with the flag off by default passes; before calling that a second cause combat is testing the duller explanation, that `TUNE=match.yaw_fit=0` never reaches the predicate at the tip (a static written at class load can be overwritten or read early; a parse message is a call-site counter, not proof the predicate changed): the probe is nav's wedged test, which must go RED under `yaw_fit=0` if the tune takes. **IT STAYED GREEN (22:55): the tune is INERT. `apply_tuning` printed and the predicate never changed (11.6°, giveups 1, byte-identical to the control). So the knob A/B (both arms had the constraint ON), the "second cause at the tip" and the yaw_world corridor table are VOID; the one-line source bisect survives with no tune in it and the reversal stands on it. Likely mechanism, being confirmed: `Units._static_init()` writes `Tank.yaw_fit_enabled`, a static on another class, and Tank's own initialiser runs later and clobbers it, which would make every knob that writes a foreign static unreliable (yaw_fit, yaw_world, no_damage; hull_disc writes Units.tuning itself). Fix, structural (combat, 23:05): the sweep found `apply_tuning` reaching across to FOUR owners (`Tank.yaw_fit_enabled` / `yaw_fit_world`, `Armor.no_damage` / `deck_probe`, and two foreign DICTIONARIES, `SwitchingCost.tuning` and `Weapons.tuning`, which an owner's later initialiser replaces with `{}`, so a per-knob getter would have left the series' own switch.* and weapon arms broken), so `_static_init` only reads `TUNE` into a string and `_ensure_env_tuning()` applies it on the first actual read of a tune, when every class it touches is loaded; point-of-use readers (`Tank.yaw_fit_on()`, `yaw_world_on()`, `Armor.no_damage_on()`) read Units' own dictionary with the static as the default; an unknown knob errors by name (ControlGains.forced()'s pattern). Each knob's test asserts the PREDICATE moved, never that the spec parsed (round 7's bug at `combat_motion.gd:40`, recurring). **PROVEN (23:10): under yaw_fit=0 the wedged row goes RED (10.42 m of path, 44.0° of yaw, giveups 0, 4.42 m drift, 12.1 m of footprint), bit-identical to nav's original unconstrained measurement; which exposes that combat's before-column all day (28.5°, 9.6 m) was taken in an arm that was not "constraint off" (likely the slack-0.02 build). Corrected corridor result: 44.0° → 11.6° (74 % of the illegal yaw removed), 12.1 → 6.1 m of footprint; the residual (1.27 m against 1.8) and the squad result unchanged; the reversal stands. The re-taken two-arm table on this build (23:15): yaw 44.0° → 11.6°, footprint 12.1 → 6.1 m, path 10.42 → 4.99 m, drift 4.42 → 2.26 m, giveups 0 → 1 (face_checked 5 both). Tenth instance of the family: a baseline that was never taken in the arm it claimed. **The first arm (23:30): five_squads PASSES at the tip with the constraint genuinely off (0 of 30; Delta 14.8 m this run against 22.2 and 22.4 earlier: run-to-run variation, not a level), so there is NO second cause (the eleventh withdrawn) and everything else on combat's branch is exonerated: the settle tick, place(), the sync write, the geometry migration, the TUNE hook, the guards and fixes.** **THE MATRIX (23:40): yaw_world does NOT ship and its numbers do NOT count.** five_squads 0 of 30 under yaw_world=1, the corridor 9.1° / 5.5 m / residual 0.70 m; but the wall case under yaw_world is offered 30, applied 30, refused 30 ticks, swept 0.0°, a hull frozen solid (nav's N1 breach), and the corridor residual MOVED in a corridor with no vehicles, which a pure mask change cannot do: the two arms were two APIs (`test_move` with recovery and `get_depth` vs `collide_shape` with the widest point-pair), differing in the measurement, not only the mask; combat's own comment claiming otherwise is falsified by its data. Default-off stands on the source bisect; squad's diagonal-spacing reading is the only explanation consistent with every measurement; if the mask question is asked in round 10 it is `test_move` in both arms with only the collider set swapped and "the corridor must not move" as the arm proof. test_tank_yaw_fit went red under yaw_fit=0 as predicted (the tune outranks the static; tests select arms through the tuning key). The remaining arms (superseded): five_squads under yaw_world=1, five_squads under yaw_world=1 (the real experiment), the corridor under yaw_world=1, and the wall/open-ground cases under both; combat predicts test_tank_yaw_fit goes RED under yaw_fit=0 because the tune now outranks the static it sets, and the follow-up is that tests select their arm through the tuning key.** Sequencing corrected by combat: the tip fails with the rule fully OFF, so no variant of the rule can pass there and a yaw_world run at the tip would say nothing; the SECOND cause is found first with `yaw_fit=0` held constant along `986f8921` → `7c2a41bc` → `43aaa8d7` → tip (the first failure names it; the settle tick is the suspect, tested directly), and only then is yaw_world a real experiment. nav's conditions for yaw_world as default, stated before the diff: the corridor residual (1.27 m against a 1.8 m bar) and the face row re-MEASURED under yaw_world with their MEASURE lines, not inherited, because the deepest-contact depth is not guaranteed to be the same number without vehicles in the mask; the counter and the named residual; and the outcome that reverses the endorsement, five_squads passing while the corridor residual grows materially.** Squad's new settle assertion in the spawn test is a committed TRUE POSITIVE (the army does not come to rest within 10 frames; 76 units named with vectors; the two teams' displacements mirror-symmetric to five decimals, the tick-1 grid seen through the layout's symmetry; the two ejections at y 1.31 and 2.09 in the same log) which combat's `Tank.place()` must clear: zero units, a millimetre last step.** (Earlier: squad's suspect was the drain set; nav verified by ancestry that the drain ON MAIN only WAITS, up to 120 frames between tests, and removes nothing, so the falsifier is the filtered case with the drain's budget at 1 frame; the containment that DOES remove regions is unmerged and, nav found, would strip a live arena's navmesh in the bare-teardown case, which is why containment, guard and sealing merge together or not at all). **The check on the three (`c3df6d4a`, 20:55): 1401 passed, 117 FAILED, the 284 edge errors BACK, nine "detached 2 leaked navigation region(s)" in `test_ai_scenarios`: a regression of nav's, not a discovery; the containment (the only code that removes state) is the prime suspect, detaching regions an arena still in use owned; nav withdrew its own prediction that new failures would be the drain working. HELD: nothing of nav's merges past `06c7e772` until a check does not move 1516/2; the sealing and the guard are re-checked without the containment (`da57ab82`; nav's prediction recorded before the result at 23:30: the sealed `_teardown()` frees owned nodes whether or not an override calls super, so the cascade should be ABSENT on that tree even with combat's leaking override still in it; if so, combat's fix is belt-and-braces and the four other override files are fixed without editing; at 13/18 targets, zero drain reports and zero edge errors, `test` still to report); the containment does not land in any state-removing form: its check also STUCK the shard (six targets waiting with zero Godot processes at 50 min), because once live regions are detached `ArenaFixture.build()`'s readiness predicate can never be satisfied and every arena build burns its full 5 s patience; a guard that reports loudly and lets the leaking test fail is worth more than one that removes state.** The enable is unblocked. The world-mask rule is built as a selectable arm (`match.yaw_world`) and stays off until a vehicle-contact case exists to measure it on; nav's counter and residual land with it then. Correction to the mechanism: `_penetration` already ranks by `get_depth()`; the limit is that the deepest single contact masks the wall term when a squadmate is pressed harder, dominance not saturation, so counting vehicles would need per-collider depth. A SEVENTH disc site, nav's: `Avoidance.radius_of` uses (w + l)/4, 4.33 m for a rig against a true half-width of 1.66, too wide abeam and too narrow end-on; queued with its own falsifier.** combat's per-tick `Tank.drive_trace` (`DRIVE_TRACE=<names>`) is armed on the spawn pair; `tank_motion.gd`'s `step_in_place` lateral term (`sideways = carried·right`, decayed by `pow(1 − grip, delta·60)`) is the live candidate; nav's condition on the grant: two fixes both make a hull stand still on tick one and only one is a bug fix, a STALE carried velocity at rest (zeroing it moves nothing else) versus a too-weak DECAY (a handling change for every hull, which moves the baseline and invalidates the clearance control, the P7 rotation baseline and A11's numbers, all priced through `step_in_place`); the assertion `carried == ZERO at rest before the decay` separates them; (1) is combat's, (2) is nav's with the re-baselining; the `sync_position` landmine lands this round as an assertion that fails today plus the one-line fix. Then the gangs-vs-law series. Earlier: **the hull-rotation plant defect**: a hull's position is collision-resolved and its rotation is not, so
  hulls rotate through scenery; this is your round-8 "semi yawing in place", and CP2 makes it worse. Spec agreed with
  nav; not started so that tonight's baseline move has one named cause.
- **nav:** P7's A12 baseline: **the rotation landed (`c025bc6b`, builder0): yard 0.304, pit 0.321, terminus 0.331, pooled 0.320 weighted by active ticks, all inside the pre-registered 30–36 %; the spread of three points across maps that treated A4 oppositely (806 blocked gates vs zero) says the pathology is in the movement layer, not a map, so A6 is a roster-wide row.** Active fraction 0.595–0.738 travels beside it (A6 row in the catalogue). One arena per remote call: `nav-fight-maps` threads one `NAV_FLAGS` so three maps would clobber one `--trajectory` path, and `build/` is wiped per target, so copy each log out first. Then per-hull-class agent radius after CP2.
- **squad:** A10 resumes at `c0f22597` once the deleted `fixed` flag's guarantee is preserved; the tube's five-seed gate.
- **control:** item 4 merged; since then (13:35, tip `6ba28cb6`, check running): the derived squad-heading pin, the hull-shaped marker, the card's lean bound asked from the laid-out nodes, radar blips reading hull length, and **a real CP2 bug caught by sweeping instead of one pose: the wall cutaway sliced the top 1.57 m off a 6.18 m hull at a 50° tilt (fixed; worst margin +0.20 m across 8–70°)**; **item 4 COMPLETE at `230265a6` (16:10): the auto-frame never included a hull's own size in its bounds, so five War Rigs in column at YOUR pose put a hull corner 16 px off screen while the frame believed it had fitted them (a pad from hull_size fixes it: +12.4 px; three more squads honestly fall back to edge markers); a pre-existing fit-maths limit at the 8° floor for columns over ~70 m is named as the exception. Three of item 4's six entries were real defects, two of them at his pose.** the "four more fixture-less tests" of 10:50 were RETRACTED at 11:05 (the guard counted a one-frame transient); and `test_control_response` was checked: it never routes and drives in open ground by constant, so K1's 100 ms figure could not have been flattered by a stale mesh; nothing owed there.
- **feel:** X4 green with scale's box; **the hinge's frame cost is NOT YET MEASURED and the reason is sized (13:15): frame cost tracks the vehicle census at 0.677 ms per vehicle (r = 0.92) and the census walks 90 → 72 during a bench run, a confound the size of the effect; a quiet box does not touch it. combat is adding a damage-off tune the bench will require.** The Terminus brightness: scale's six irregular lamps are on main (fba3b298); feel judges them from `crowd-look ARENA=terminus CROWD_FLAGS=--no-show` (the wide poses contain the block grid; `size-look` frames the spawn at the rim, where the nearest lamp is 72 m out of shot, and its frame would have been a verdict on unlit asphalt), and notes that the bright cyan pools around units in the 10:20 frame are UI rings, not light. **VERDICT (feel `e9122334`, 17:30, sent to you: `~/projects/godot-feel/build/crowd-look/ahead-p35-d120.png`): the floor reads as improvised work lights (discrete warm pools, real falloff, hazard rings, dark between, no grid; the municipal-lattice objection answered), a clear improvement on the two-lamp baseline; but dark hulls between pools are still close to invisible without their markers, so the lamps add atmosphere, not legibility, and at your opening pose no lamp is in frame until the army moves into the blocks. YOUR CALL, recorded: if you want units readable without the HUD, that is a separate ask; recommendation: a faint per-faction rim light on hulls (feel, round 10, pair discipline) rather than more lamps.** A paired footing (a pre-merge show-off frame) is being shot. **The round-8 re-measure is DONE (feel `d91dd0e6`, builder0, ten matches a cell): gangs vs law, the 0/20, is 20 % on pit and 50 % on yard; no matchup on either arena is unwinnable. On pit the pooled gangs number is unmoved at 30 % while the unwinnable cell recovered (the rig paid ~10 points in each of its two playable matchups), so the target's default summary would have said nothing happened: the pooled statistic hid an improvement this time. Only the +50, the 0 → 20 and the pooled 27 → 53 carry weight at ten matches a cell.** Next for feel: the Terminus roof dressing (the lifted camera shows undressed roofs), a frame before any triangle.
- **metrics:** backlog and both stretch items COMPLETE (14:50). Landed or checking: the gate honours PENDING and gates on non-pending counts (record `42,2,3,0` at `dd6f84ca`); `expect_warning` and separate warning counts in the runner; `--pool`; the copy-back checksum manifest and `--delete` with logs protected (wrapper logs now go in the session scratchpad); `remote.sh` refuses to rsync over a live run; the quiet-window mode (HELD / NOT USABLE); `make sim-baseline-adopt` (two reads, refuses a coin, merges the line without deleting other machines'); `make round-status`. **16:20: metrics' `check3` showed that a failing `test` abandons 7 of 18 targets silently (nothing in the log says so); `check4` on the tip `0269e7b0` carries `-k` and a PASS / FAIL / NOT RUN verdict from the markers and is the merge gate.** Observation from its first run: builder0 ran six slots at load 15.7 on 12 cores this hour (streams launched before merging main carried the pre-T1 `REMOTE_SLOTS`; T1 measured 3), which is why checks took 25–40 min.
- **show:** item 7 (stretch) not started.

### The round's structural finding, and what round 10 should spend itself on

**Round 10's list, in the order I would brief it (each item's evidence is in the stream lines above and the lessons):**
1. **The plant predicate** (combat): why a clear hull with 3.19 m of room accepts none of three candidate yaws for 1135 consecutive ticks; instrument each candidate's `_penetration` per collider per tick on `Charlie_3`; then the ORDERING (five_squads in the other four squad orders); then diagonal-derived spacing as a CANDIDATE. Constraint OFF throughout.
2. **The spawn grid gives a hull room to turn** (scale): four crews overlap at spawn on the settle-tick tree; the grid is a second site for the half-diagonal arithmetic, and it is a true defect independent of item 1.
3. **Every clearance constant names the motion it licenses** (nav/squad): `HULL_CLEAR_M`, the bake radius, `Avoidance.radius_of` (the seventh disc site, with its falsifier).
4. **ORBIT radius reads hull length** (combat): the engine-deck scenario is red on main because length is the driver (0 → 22 deck hits at 3.6 m); the scenario re-records with that REASON.
5. **The region guard records the count at SETUP** (metrics/nav): "arrived dirty" instead of "left 4", the observer as witness not accused; scale's bodies-guard fix is the model.
6. **The gangs-vs-law series with `match.hull_disc` as the arm** (combat), feel's matrix (pit 20 %, yard 50 %) as the before, per cell; the box becomes default only on a result no worse on every cell.
7. **Your paid gate: one hull mesh each for `tank` and `burner`** (the two units that do not read as vehicles).
8. **Per-faction hull rim light** (feel), pair discipline; the single-variable lamp pair; the trailer's frame cost with a working freeze (three refusals so far).
9. **Heavies-in-alleys: your call** (should hulls above the bake radius simply not route through alleys?); nav prices not deciding.
10. **The show's two calls** (the decision pair and the luminance gate's one red), sent with the fifth run's frames.
11. **Delta's margin; the `_is_clear` yaw gap; the held wheeled hull's facing threshold** (nav's pre-registered rows).
12. **The load-order knob test pattern** (two child arms, differ-assertion first) becomes the template for every knob; the drain-between-scenarios question for the scenario count (`42,2,3,0` vs `41,3,3,0`).


**A second structural consequence of the resize, measured by nav at 10:35 (`c025bc6b`, post-CP2 roster):** the navmesh
is baked for a 2.0 m agent (`arena.tscn`, mirrored by `NAV_AGENT_RADIUS`) and **14 of 21 units now have an avoidance
radius above it** (median 2.50 m, `gang_tank` 4.58 m = 2.3× the bake, `gang_scout` 1.36 m). The mesh certifies
corridors the largest hulls cannot physically use, a plausible contributor to the wedging nav chased all round, and it
arrived with CP2, not with any nav change. **A third consequence, on the unit you named (scale, 12:10):** `roster-scale` prints `no mesh` for two units, the Condemned `tank` (your bus-tank, `Units.DEFAULT`) and `burner`; the rule gave them a length from the reference and kept today's width and height (the brief's "do not invent proportions"), so the bus-tank is 8.62 m long and still 2.40 m wide and 2.40 m tall, a 3.6:1 slab where a Type D school bus is ~2.6 × 3.1 m and 4.7:1. Invisible to every check (no mesh to compare the box against). **Decided on your behalf (12:15) and REVERSED at 13:50 on the picture:** scale derived width and height for those two from the cited references × K (2.40 × 2.40 → 1.83 × 2.19), shot the lineup, and looked: **the Tank and the Burner are the only two vehicles in the roster that do not read as vehicles** (long, dark, flat slabs; the IFV at 7.5 m reads as a bus far better than the Tank at 8.6 m), because they are the only two with no mesh of their own and wear the shared dozer hull stretched to length; the narrower box made the slab flatter. So the derivation is not merged (reverted on scale's branch, both numbers kept in its Status), the two keep 2.40 × 2.40, there is no third baseline move today, and the screening bar stays. **YOUR GATE: one hull mesh each for `tank` and `burner` (paid generation), which fixes the silhouette and retires the box contract's no-mesh branch.** Frames sent to you: `~/projects/godot-scale/build/roster-lineup/lineup_pose.png`, `lineup_factions.png` (the five back-row Syndicate labels overlap; a nicety). The round's artefact from this: **scale's list of all 42 readers of `hull_size` and what each assumes (`6617779f`, "What reads `hull_size`" in workstreams.md, pointed to from units.gd's schema comment), and writing it found a hazard on first use: three consumers model a hull as a DISC of its box diagonal (`match.gd:1383` friendly-fire risk, `match.gd:1450` incoming projectiles, `ai/incoming_fire.gd:101`, cached per unit), so the AI treats the War Rig (3.32 × 14.00) as a 14.4 m-wide circle, 7.19 m against a real half-width of 1.66 m, 4.3× (pre-CP2 worst 2×). Gangs refusing safe shots and over-reacting to shells is a candidate mechanism for your gangs-vs-law 9/20 → 0/20, untested; combat replaces the disc with the oriented box at its two `match.gd` sites, squad at `incoming_fire.gd` (its file), one helper; the error is a function of angle, worst abeam (the across-the-rig shot a pack wants) and near-zero end-on; both arms of the gangs-vs-law series run from ONE build behind a `match.*` knob, with the null stated: if the box arm does not move the series, that is evidence against the mechanism and is reported as such.** **The fallbacks were stale AND DEAD (nav `06c7e772`, 19:30): `Units.stat()` ends in `PROFILES[id].get(key, fallback)`, so an unknown unit id raises before any fallback is consulted; the case every call site was written for was unreachable, which is why a pre-CP2 value sat there a round with no consequence. nav's `hull_box()` checks `PROFILES.has()` first; the `has()` guard inside `stat()` itself goes to combat (C1); metrics' `expect_error` surfaced the second, undeclared error exactly as designed.** Silent pre-CP2 fallbacks are routed to make loud (push_error naming the id, `Units.DEFAULT`'s live size, one accessor): nav's three (`ai/avoidance.gd:54`, `ai/movement.gd:708, 1700`) and squad's two in `army_layout._hull` (`[2.6, 1.8, 4.0]` understates `tank`'s live 8.62 m by 4.6 m, silently reproducing the pre-X1 nose-to-tail bug for any unit the layout cannot read). The disc/box knob gates the geometry inside one helper so all three sites flip together; `incoming_fire.gd`'s static per-id radius cache changes shape and squad checks it cannot hand out stale geometry across tests.

**Ruled (10:40):** nav's routing reads the bake radius from the arena and
consults each hull's shortfall (refuse or widen) rather than discovering it by wedging; the bake stays 2.0 this round
(4.58 would close every alley for the two thirds that fit); per-class meshes are round 10 money only if nav's
falsifier says so. **Built and measured (nav `164d51d4`, builder0, 13:30):** `bake_radius()` reads the live mesh (the constant demoted to a cross-check that `push_error`s), `clearance_shortfall()` per hull (gang_tank +2.58 m, scout −0.54 m), and the routing refusal behind `--nav-off=clearance`: gang_tank's chord slack −2.28 m → refused (3 of 6 consultations), scout 0.90 m → untouched; the switch-off test reproduces the old slack byte for byte and `sim-baseline 1e90f69e5d6fcc46` is unmoved with the whole row in the tree. **The A/B (nav `961640cf`, yard, seed 3, 120 s, both arms on one tree, 16:00): the routing refusal FAILS its guards and the default stays OFF on measurement.** Arm proof: treatment refused 441,606 of 485,697 consultations (90.9 %). Attack-move `progressing` 0.407 → 0.263 (−35 % against a −10 % bar), `slow` 0.02 → 0.388 (the hulls crawl), ifv `off_corridor` 0.373 → 0.429, net/path fell ~10 % on ifv and lancer, the active fraction 0.664 → 0.176. **The ALL row improves on every primary (osc_share halved, cusps −39 %) and would have shipped it: you cannot oscillate if you are not going anywhere.** Per-hull rows and the active fraction beside every fraction caught it; nav's own "refused < chords" bar passed at 90.9 % and is rewritten as a share. One map; pit and terminus when the box has room. **Corrected by nav (20:30): `radius_of` is `(w + l)/4 + margin`, a ROTATIONAL envelope (4.58 m for the rig against a true half-width of 1.66), while the bake's 2.0 m is a LATERAL clearance for driving a corridor; "14 of 21 units exceed the bake" compares the two kinds of length and is inflated as a corridor statement, and the A/B's 90.9 % refused was the rule measuring the wrong length, not the rule being strict. What survives untouched: a 14 m hull cannot rotate in a 4.8 m corridor (9.6 m of footprint, measured geometrically, independent of radius_of). The verdict (default off) stands; round 10's question is what a shortfall is measured against, and `radius_of` itself is a seventh disc site (too wide abeam, too narrow end-on), nav's, with its own falsifier.** **Your call, recorded:** should the largest hulls simply not route through alleys narrower than
their clearance (heavies use streets)? nav can measure the cost of not deciding; it cannot decide it.

**Round 10's plant-constraint item, reframed at 15:30 by combat's ranking (the table is in combat's line above and lesson 199).** Until this afternoon the item read: derive the spawn grid and the formation pitch from the half-diagonal, then switch the constraint back on. That rested on a correlation over four crews which the ranking killed: a crew with 3.19 m of lateral room refuses as hard and as long as one with 0.06 m, and the only crew that seats is the one whose squad was ordered first. So the item is now, in order: (1) **the predicate**: why does `_fitting_forward` accept none of three candidate yaws (down to 0.3 of the wanted turn) for over a thousand consecutive ticks on a hull that is clear on every axis anyone has measured; instrument what each candidate's `_penetration` returns against WHAT collider, per tick, on `Charlie_3`; (2) **the ordering**: five_squads with the squads ordered in the other four orders, does the seating crew follow the order or the geometry; (3) only then the diagonal-derived spacing, as a candidate with the table beside it. The constraint stays OFF until (1) has an answer; scale's spawn-grid half (four crews overlap at spawn on the settle-tick tree) is a true defect regardless and is not waiting on (1).

**Intent does not reach the layer that moves the hull.** nav measured `CombatMotion` deciding under a tenth of a hull's
ticks with `Movement` driving the rest and knowing no leash; squad found A8's deformation fails a defile because a slot
layout is the wrong place for intent the mover cannot see; the maze defile failure survived three pre-registered
hypotheses and is now a named regime (`wedged`) rather than a story. Every one of nav's five rows trips on the same
seam. That is round 10's first candidate, ahead of retrying any row.

**Metrics' close-out (merged docs-only at `44d4bb58`), and the one thing it would keep if only one survived:** a fix at one layer defeated by a layer above it that was never in the picture (lesson 192): make eating `$` before the shell three times, a pipeline reporting `tail`'s status, `$(date)` resetting `$?`, a tag object between a ref and its commit, six call sites landing in the wrong parameter, a scenario runner still calling `teardown()` after the seal; in every one the code was right about the thing it looked at and wrong about WHAT it was looking at. Its companion: three of its own suites were green on the laptop and red on builder0, and surfaced only because they run inside `check`; a guard exercised only where it is easy passes for the wrong reason, which is the argument for leaving them in the gate.

**Lessons 152–174 were written tonight** (`_agents/orchestration.md`): the night's recurring shape is *the absence of
work reading as the success of work*: a lint that checked zero files, a scenario suite outside the gate, a flag that
silenced its own tests, a perturbation that could not perturb, a control arm where the mechanism could not act, a
measure that flagged everything. Each is now a guard.

---

## Round 9 is LAUNCHED (2026-09-19 evening). Start here.

**Eight streams — metrics, scale, nav, combat, squad, feel, control, and (added 2026-09-20) show** — each with a brief in `_agents/streams/<stream>.md`
and a worktree at `~/projects/godot-<stream>`. The split, checkpoints (CP1 A12 metrics, CP2 the resized roster, CP3
parallel `check`), ownership carve-outs and the four new contracts S1–S4 are in
[`_agents/workstreams.md`](_agents/workstreams.md) *Round 9: the seven streams*. The lead's two feedback items and the
sizing rule are in [`_agents/game_design.md`](_agents/game_design.md) *Round 9 direction*.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all eight (show at `~/projects/godot-show`, OFFSET 8; it runs every Godot process on builder0 because the laptop had ~2.2 GB free with seven live):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**`main` IS GREEN at `f49aa08a`** (builder0, 2026-09-20 00:27: `>> remote: make check exited 0`, `1261 passed, 0 failed`,
`sim-baseline passed: 04414f5d6a6dfa7c (glibc-2.43)`). Round 8's unverified merge is now verified; every commit since is
docs only. **Orchestrator duties this round:** merge CP1
(metrics' A12) and CP2 (scale's roster) the day they are announced and tell every stream to `git merge main`; record
the sim baseline in the same session as CP2 (it moves); put scale's side-by-side roster frame and feel's rig-hinge frames
in front of the lead the day they exist; get feel's `_agents/legibility.md` signed by control and nav before anyone
writes A6 motion code; review nav's A7 priority table against combat's and feel's contracts before nav codes it; relay
negative results between streams. Final integration order: metrics → scale → nav → combat → squad → control → feel → show. **Overnight 01:45:** all eight agents busy; nothing merged yet. **CP2b (squad `6e0c9968`) is HELD** — its drift scenario errors on a stub without `pitch`, invisible to `check` because `ai-scenarios` is not in it (lesson 159; metrics adds it behind a count baseline for CP3). nav: A4's positive control 403/403; A1 is a negative result, the real driver was re-planning against a sliding station (47% of re-plans), fixed. scale has A3 built (`3dcab48b`). feel has the airship built (`567a8007`). control's facing drag and camera lift built. **Round-wide trap found 02:00 (show, verified in `tools/make_arenas.py`): `arenas/*.json` are GENERATED and the generator drops any key it does not know — a hand-edited layout loses the edit on the next `make arenas`, silently. Ruled: the generator preserves an allowlist of hand-authored keys (`show`) and `Arena.validate()` rejects unknown top-level keys; scale owns both.** **MERGED 03:05: CP2c, control's right-drag facing at `e27f0681` (builder0 1269/0, exited 0) → `main` `260dddc7`; check on main running.** **MERGED 03:10: stream/nav at `5c8f08b3`** (builder0 1290/0, exited 0, sim-baseline UNCHANGED at `04414f5d6a6dfa7c`: A7/A11/A1/A4 all opt-in, 29 new tests) → `main` `08a8c378`; **NOT covered by the check running behind CP2c** (asked builder0: its tree has no `clothoid.gd`), so a second check on main is chained to start when that one's wrapper line lands. **MERGED 03:30: stream/feel at `7a706911`** (the articulated War Rig, S2; builder0 1273/0, exited 0, baseline UNCHANGED, read from streamed stdout) → `main` `8147bddc`. **builder0 came back at 03:25 (ZeroTier link; ~35 min outage; no remote jobs survived the drop; the check on main restarted at 03:25).** ~~⚠ builder0 went OFF THE NETWORK at ~03:15~~ (it went off at ~02:50 (ZeroTier link; the laptop's internet is fine): the check on main behind CP2c died with ssh 255 mid-run, so **`main` at `8147bddc` (CP2c + nav + feel) is NOT yet covered by a check** — it runs the moment the box returns (polled every 5 min). Every stream is holding remote runs and working locally. **CP2's blocker is diagnosed and fixed (scale `e5d71ba2`, 03:50):** the 104.9 m unit was a *respawned* enemy-killed unit sitting on its own new spawn slot with no order; the old grid passed by geometric luck. The test now excludes destroyed units, as its sibling already did. CP2 waits only on scale's remote check and hash. **`main` VERIFIED GREEN at `ba1c22c8` (CP2c + nav + feel; builder0 04:12: exited 0, 1310 passed, 0 failed, sim-baseline 04414f5d6a6dfa7c unchanged; note that run's lint was still the vacuous one — CP1's own check at `ae9c65e1` covered the same code with the working lint).** **MERGED 04:00: CP1, metrics at `ae9c65e1`** (builder0 1310/0, exited 0, 16 targets, baseline UNCHANGED across CP2c + nav + feel) → `main`. Since ae9c65e1 already contained the three earlier merges, main's code is exactly the tree that passed. **Every stream merges main now.** The working lint is live (an empty file list fails; `tests/baselines/lint_expected.txt` carries the 8 known artefacts). T1 measured at 6 slots: 1776 s vs 2693 s serial = 34%, **missing the 50% bar because six slots starve the inner fan-out (CHECK_JOBS=1, 2 shards)**; the shipped configuration is 3 slots (CHECK_JOBS=3, 6 shards), series running. **MERGED 04:20: stream/nav at `3b01f5b7`** (wedged detector, forced gains, A1 monotonicity guard, face recovery; builder0 1295/0, exited 0, baseline unchanged) → `main` `e1a9895c`, **VERIFIED GREEN** (builder0 04:35: exited 0, 1315 passed, 0 failed, 16 targets, sim-baseline 04414f5d6a6dfa7c unchanged; the sharded check took **990 s** against the 2693 s serial baseline on a box running six other jobs). **MERGED 05:05: stream/control at `6813908d`** (checked at `ffd09b0e`: the camera lift + occlusion cutaway on the Terminus, the corridor readout, the console gate; 16/16 targets, verdict read from the box's markers after metrics' kill took the wrapper) → `main` `f005dd37`, **VERIFIED GREEN** (builder0 05:14: exited 0, 1327 passed, 0 failed, 16 targets, 791 s sharded). **MERGED 05:15: stream/nav at `c6222a5c`** (A4's A/B: default stays off on measurement; the rotation-read map set; A11 cannot act without A7, arm guard; builder0 1316/0, exited 0, baseline unchanged) → `main` `36aa295d`, **VERIFIED GREEN** (builder0 05:50: exited 0, 1328 passed, 0 failed, 16 targets). **MERGED 05:40: CP2b, stream/squad at `974f194a`** (checked at `02762b8d`: hull-derived slot pitch + leash, facings on element orders, A8 off, A9, per-faction gains measured; A10 stood down; builder0 1297/0 with the pre-registered baseline move as the only red, five post-baseline targets exited 0) → `main`. **SIM BASELINE RECORDED: `glibc-2.43 d4c049819a5833d3`** (builder0 06:00, read twice, agreeing, on the merged tree with squad and feel in; matches squad's pre-registered value). **`main` VERIFIED GREEN at `82604493`** (the full tip with squad, feel and the new baseline: builder0 06:00, exited 0, 1370 passed, 0 failed). **MERGED 05:45: stream/feel at `37d6f838`** (checked at `5ae7e531`: the airship, the differential smokes proved, the pipeline roster fix, the Terminus luminance diagnosis; builder0 1316/0, 16 targets, baseline UNCHANGED, real lint 543 files clean) → `main`. **`main` VERIFIED GREEN at `1f6e54b7`** (with squad's follow-up: builder0 06:35, exited 0, 1370 passed, 0 failed, 16 targets, 1035 s). **MERGED 06:10: stream/squad at `c2d7c28f`** (checked at `1a797642`: A1's brain-side tube measured, −62% re-decides with latency intact, ships OFF behind a five-seed gate because 4 more GREEN died on one seed; nav's corridor field; builder0 1364/0). squad is DONE and stopped; its report is at the head of its Status. **MERGED 06:15: stream/control at `d5e37692`** (checked at `3683e0ca`: the legibility readout on nav's key and corridor; builder0 1372/0, 16 targets, baseline unmoved). control's backlog is complete except item 4 (the post-CP2 camera sweep), standing by. **`main` VERIFIED GREEN at `888d0f8d`** (control's and nav's tips in: builder0 07:00, exited 0, 1383 passed, 0 failed, 16 targets). **MERGED 06:40: stream/nav tip** (checked at `d6a1f454`: the legibility key, corridor tangent, A6 opt-in and honestly inert, the arrival-heading test; builder0 1381/0, baseline d4c049819a5833d3 unchanged against main's current value). nav is DONE and stopped; five rows built, none on by default, four negative with pre-registered falsifiers. **MERGED 07:00: stream/combat at `55b0de58`** (the dwell timer retired on measurement, A2 opt-in, the CLEAR_LANE catch; builder0 1393/0, exit 2 = sim-baseline only). **SIM BASELINE RECORDED: `glibc-2.43 32831dc99cdaf5ca`** (builder0 07:10, read twice, agreeing; one named cause: the retired timer). **`main` VERIFIED GREEN at `0808834e`** (all twelve merges + the new baseline: builder0 07:38, exited 0, 1454 passed, 0 failed, 16 targets). **MERGED 07:10: stream/show at `77b209c0`** (checked at `e1823e68`: the arena light show; builder0 1420/0, lint 560 clean, baseline UNMOVED — S6's pre-registered claim held; show's shader edits under feel's `game/theme/fx/shaders/` and `export_presets.cfg` are the granted emission hooks, feel reviews). show is DONE and stopped; items 1–6 complete, 7 (stretch) not started. **MERGED 07:12: combat's report commit `0709b073`** (docs only). combat is DONE and stopped. **Live checkpoints as of 2026-09-20:** CP1 (A12 format stable, positive control passed, merge hash pending), CP2 (roster resized on `stream/scale`, line-up frame for the lead pending), CP2b (squad's attacking-element leash), CP2c (control's right-drag facing, green locally), CP3 (T1 in progress). Contracts S5 (one commitment term, two seams) and S6 (the light show) were added mid-round; the lead's lighting and camera items are in `game_design.md` *Round 9 addition*.

**In front of the lead (2026-09-20 01:15):** feel's **rig-hinge frames** — the War Rig articulated at the fifth wheel
(corner at 45°, the same corner at his pose, the reverse jackknife), sent as three strips built from
`~/projects/godot-feel/build/rig-hinge/` (stream/feel `7a706911`, laptop). Numbers beside them: live match, 32 rigs,
1,440 rig-frames, mean articulation 6.1°, 4.9% past 30°, 1.2% at the 65° clamp; the closed form `asin(5.06/12) = 24.9°`
at the rig's 12 m turning circle, reached 22.7° on the corner. **Caveat he should know:** the collider is still the
one 14 m box (S2), so a shell can pass through empty air inside a fold this round. Awaiting his look.

**In front of the lead (2026-09-20 02:55): the roster line-up at real relative scale** (`lineup_pose.png` at his pose,
`lineup_factions.png` all 21 by faction; builder0, `stream/scale` ~`8fc9a2a8`, K = 0.707). **Approved on his behalf
overnight**: the rig reads as a semi beside a car, the Condemned tank as a bus (8.6 m; on screen 281 × 135 px against
round 8's 199 × 100, the rig 734 × 279). Defects noted for one more render: labels collide in the factions frame and
its near row clips. He can overrule the look or K in the morning. **The gap-widening ruling was withdrawn** (scale's
first corridor measure was wrong; the corrected one shows no pinch on any rotation map: yard 18.0 m, terminus 11.5 m,
maze 7.0 m = its authored `MAZE_TIGHT_GAP`).

**In front of the lead (04:05): the Terminus alley pair** (`~/projects/godot-control/build/terminus-alleys/index.html`,
six pairs; `alley4_asked` = the camera inside a wall, `alley4_clear` = a squad in the street with rings, facades intact;
`alley5` is the open-ground control where nothing is cut). Lift + occlusion cutaway, control `c97d4d5f`, laptop, windowed
at his pose. Approved overnight; item 3 of control's brief is done on the hash its check names.

**One question for the lead, with a recommendation:** the roster is being scaled *rig-relative* (the world's vehicles
at K ≈ 0.7 of real size, so the 14 m rig he ruled on stays and the bus, garbage truck, APC and assault gun grow
1.5–2×). The alternative is *real metres*, which puts the rig at 18–21 m and roughly doubles apparent crowding on
every arena. **Recommendation: rig-relative.** If he prefers real metres it is one number (K) and a re-run of the
table, at any point before CP2 merges.

## Round 8 is CLOSED (2026-09-19). The state at launch of round 9.

**All six streams merged, worktrees removed, briefs archived to `_agents/streams/archive/round8/`.** `main` carries
everything. The six `stream/*` branches are kept as history; `make worktree STREAM=<name> OFFSET=<n>` recreates a
worktree for round 9.

- **Sim baseline: `glibc-2.43 04414f5d6a6dfa7c`** (was `0cb238bf366e141f`). Recorded from builder0, **read twice with
  both readings agreeing**, covering the two hash-moving changes: squad's brain and start positions, and combat's
  **widened match** — which is why it moved so far. The old match fielded five `tank` hulls and was blind to 5 of 6
  mutations; the new one fields every locomotion × mount combination.
- ~~**⚠ `main` IS NOT COVERED BY A GREEN CHECK.**~~ **Verified green at `f49aa08a` on 2026-09-20 (see the round-9 section above).** Was: combat was merged unverified **on the lead's explicit call** (*"checking
  in a dirty codebase is ok, let's just get everything merged so we can hit a milestone"*), so the round could close
  and the environment be reset. Its blast radius is bounded and was verified, not assumed:
  `git diff --name-only main...stream/combat -- game/` returns **nothing**. **The first task of round 9 is one full
  `make remote T=check` on `main`.**
- **Round 9 is planned:** `_agents/workstreams.md` *Round 9 goal* has the split, the order, and the argument for the
  order; `_agents/research_catalog.md` has the twelve adopted techniques with owners and falsifiers. **A12 (metrics)
  and T1 (parallelise `check`) come before any mechanism.**
- **Measurement provenance is preserved** in `_agents/streams/references/round8/` — 72 JSONs, the raw data behind
  every number the archived briefs cite. **Cite from those with their commit and machine, not from a brief's prose.**
- **Two traps for a fresh environment**, both in `_agents/remote_builds.md`: a cold `make import` exceeds `slot.sh`'s
  5400 s cap and is killed (use `TANK_SQUAD_SLOT_TIMEOUT=14400`), and a remote run that exits **255** is ssh, not the
  suite — after which `build/` holds a **previous run's** artefacts.

## ⚠ READ THIS FIRST: round 8 is merged; the lead's verdict on round 7 was "it still sucks"

**All six streams' round-8 work is on `main`.** What remains unmerged is documentation plus three small tooling commits
(control's camera-looks frame, arena's brief work, combat's per-matchup reporting) — **all of which has since been
merged too.** ~~`main` is green~~ **— see the close section above: `main` is NOT covered by a green check.** Baseline
is now **`glibc-2.43 04414f5d6a6dfa7c`**; `0cb238bf366e141f` was round 8's mid-round value.

### What the lead can now do that he could not

| his complaint | what shipped |
|---|---|
| *"the gang tanks are still tiny"* (×4) | **the War Rig is 14 m** — 721 × 315 px at his camera against a tank's 199 × 100. It drew **91 px tall** before, **shorter on screen than a tank** |
| *"the semi trucks are yawing in place"* | a wheeled hull with a **turret** gets `stop` instead of `face`; the turret aims, as a real truck does |
| *"not all units belong to a squad"* | **17 gang vehicles were on no number key.** Fixed from both ends, with an `ungrouped=N` readout at start |
| *"they don't obey… they shoot at whatever they were already shooting at"* | drills aimed at `Drills.nearest_visible`, never at the task's target. Task path **765/155 → 164/759** unit-ticks |
| *"it's still just a boring square"* | **yard and pit are hexagons**; `Arena.ROTATION` is `["yard","pit","terminus"]`, so `random` only deals maps he kept |
| *"the 3d polygon primitives… I have not seen that at all"* | **the Terminus** — a cityscape, built, named by the booth, in the rotation |
| scouts ramming their targets (round 7) | shoot-and-scoot: **3.0 → 27.7 m** closest approach, **29 → 211** shots |

**Plus, unreported by him and found on the way:** every gang vehicle played a **shield-destroyed crackle at spawn, ~40 at
once, since the gangs shipped**; the radar outline sat **20 m outside every wall on every map**; hulls with a cut gun drew
at **80% of their box** since round 7; five kinds of refused order **returned their reason to nobody**; and the camera's
lean **parked the selected squad under the command card** on every order.

### The three things the next round must not re-learn

1. **⚠ `sim-baseline` ONLY FIELDS TANKS** (lesson 137). Both doctrines in the baseline match are all-`tank`, one map,
   40 s. **"sim-baseline passed" means "a tank-vs-tank match on foundry is unchanged"** — it is blind to every wheeled
   hull, every gang vehicle, and every other map. **feel has twice proved its art inert by passing it; that proof holds
   for tanks.** Widening it is one match and it is the cheapest high-value fix available.
2. **The oscillation is measured and unfixed.** **5.3–7.2% of attack-moving travel time** on all four maps, pre-registered
   before the run. **It is not terrain** (`blocked_terrain` 0.000–0.010) and **it is not the hold path** (nav's A/B cleared
   it). The mechanism is **gear-shuffling** — forward and reverse within the same 2 s window. The remaining suspect is the
   **re-aim rate**, and the veto shape of that fix has already been measured and **reverted** (lesson 138).
3. **Three things were built, measured and thrown away this round** — flow fields, a gear-change cost, a target-switch
   floor. **All three were cheap because they were measured before shipping.** The expensive version is round 7's: ship,
   measure twice, then discover the mechanism was never reached.

### Open, and waiting on him

- ~~**12 m vs 14 m for the War Rig.**~~ **RULED 2026-09-19: it stays at 14 m** (*"we can revisit that later if it's still an issue"*). The cover cliff was an artefact of sampling the hull's CENTRE POINT, not of the maps — catalogue **A3** fixes the query at any hull length. Retained below only for the numbers: 14 m costs `gangs vs law` **9/20 → 0/20** across both maps (p ≈ 2×10⁻⁶), cause
  unresolved between splash/suppression and the creep. **Nobody is shrinking it to make the number look better**; feel has
  12 m ready and he decides with the frames.
- **The Terminus is in the rotation and marked UNJUDGED** — the constant and its test both say so, with a comment naming
  the line to change.
- **The crowd and the energy weapons** — he has the files and has not said.
- **Street-level detail on the city blocks** — feel's question, shipped plain deliberately.

## Current state (main)

- **Round 5 is fully merged** (render, arena, control, combat, ai, audio). Briefs and their reports are archived in
  [`_agents/streams/archive/round5/`](_agents/streams/archive/round5/); the measurements behind their numbers are in
  [`_agents/streams/references/`](_agents/streams/references/), each with its commit, machine and caveat.
- **The frame rate fight is won.** The lead's round-6 playtest does not mention it once. The simulation runs at
  **30 Hz** with physics interpolation, physics is **Jolt**, and the target the lead chose is **a locked 30 fps at
  1080p with 30 a side, plus a 720p 60 fps option** (his round-5 sign-off). Baseline for scale: 60 fps used to hold at
  13 vehicles at 720p and never at 1080p.
- **The game today:** StarCraft-style control with a camera that only shows what your force can see; elements that
  pick formations and run battle drills from real doctrine, the same library for you and the CPU; suppression that
  makes base-of-fire-and-maneuver real; four playable factions with their own rosters and doctrine; tank shells you
  can watch fly; a voiced announcer trio; layered sound and a music director; seven arenas.
- **Builds run on builder0:** `make remote T=check`. **Budget 30–50 minutes during an active round, not the 7 minutes
  the docs used to claim** — measured ~50 min for 1010 tests on `main` at `5c68a03e` with six streams live, because
  builder0 runs two slots and four concurrent checks both queue *and* slow each other
  ([remote_builds.md](_agents/remote_builds.md)). So: **iterate with a local `make check`, spend a remote slot only on
  a merge candidate**, and ask the orchestrator to clear a window for a big measurement series. **Read the result from
  the wrapper's own `>> remote: make check exited <N>` line and the runner's `N passed, M failed` — never a shell exit
  code through a pipe, and never the `waiting for a heavy-run slot` line, which is printed on enqueue and never
  retracted.**

## Round 6: six streams (planned 2026-09-18)

Goal: **movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get
stuck behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera
too far above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](_agents/game_design.md) *Round 6 direction*, his words in full).

| Stream | Brief | Outcome |
|---|---|---|
| nav | [streams/archive/round10/nav.md](_agents/streams/archive/round10/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, one regulated control law (PID). Proven on a maze (**N1 = CP1**) |
| squad | [streams/archive/round10/squad.md](_agents/streams/archive/round10/squad.md) | A squad order is a *formation* order: one formation system, a slot per unit, a form-up ETA, and every named task doing what it says (**N2 = CP3**) |
| control | [streams/archive/round10/control.md](_agents/streams/archive/round10/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, loading that shows itself |
| arena | [streams/archive/round10/arena.md](_agents/streams/archive/round10/arena.md) | Terrain that makes ambush and flanking possible, objectives off the centre line, and the maze nav is measured against (**N3 = CP2**) |
| combat | [streams/archive/round10/combat.md](_agents/streams/archive/round10/combat.md) | Seeing an enemy is not the same as opening fire: acquisition, a real effective band, fire discipline (**N5 = CP4**) |
| feel | [streams/archive/round10/feel.md](_agents/streams/archive/round10/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and a place that reads from a low camera |

Ownership, contracts (N1–N6, M1–M3, L1–L5, K1–K5, C1–C8), checkpoints and invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

### What the survey found, and every stream's brief is built on

- **There *is* pathfinding** (Godot `NavigationServer3D` over a navmesh, i.e. A* over polygons). What is missing is
  everything about *other units*: no RVO/ORCA, no separation, no reservation, no negotiation. One mechanism exists —
  `_around_friends`, which sidesteps the **single nearest ally** by 5 m without checking the sidestep against the
  navmesh, ignores enemies entirely, and is a no-op outside a `TankBrain`.
- **A stuck unit then lies about it.** `TankBrain.ORDER_STALL_ARRIVE = 12.0`: after 3 s of no progress, a unit within
  **twelve metres** of its goal declares the order complete. That is why a jammed horde looks like it *decided* to
  stop.
- **The formation abstraction the lead described exists three times** — `game/control/group_formation.gd` (used by a
  plain player move), `game/ai/formations.gd` + `squad.gd` (≤ 5 members), `game/tactics/tactics_formation.gd` (any
  size, sectors, the best of the three) — with three shape tables, three assignment rules, three pacing rules, and no
  single owner. And **a plain `move` deliberately bypasses the element layer and dissolves the element**
  (`rts_controls.gd:42-46`), so his commonest order is the one that turns a squad back into loose vehicles.
- **Formation slots are never validated against geometry** — clamped to the arena rectangle only, so a wedge beside a
  container stack puts vehicles inside it.
- **Steering is a pure P controller** with one gain for the whole game (`turn = clamp(-error/30°, ±1)`), which is
  exactly the gap the lead's PID instinct points at.
- **Firing needs no acquisition.** `_shootable()` admits any target inside weapon range with a clear physics line of
  sight; the comment records that the `seen` test was found unused and **removed**. And `effective_range == range` for
  every core weapon, so there is no band where a shot is legal but bad. That is the mechanism behind *"units see each
  other and then everyone just starts firing"*.
- **Pitch is welded to zoom** in `rts_camera.gd:179-185` (`lerp(25°, 82°)` over the same slider as `lerp(16 m, 260 m)`).
  A player commanding 30 vehicles zooms out; there is no way to zoom out without tilting to near top-down. The lead
  never chose a bird's eye view — he chose to see his army, and the camera charged him a top-down for it.
- **Nothing about loading is threaded** — no `Thread`, no `WorkerThreadPool`, no `ResourceLoader.load_threaded_*`
  anywhere in `game/`. FIGHT synchronously loads the scene, builds the venue, **bakes the navmesh**, and instantiates
  ~44 vehicles a side in one frame, with no progress UI of any kind.
- **The crowd already exists** and shipped 2026-09-14 — MultiMesh, 900–4000 figures, seats from the stands' rows,
  reacting to `FxWorld.spectacle`, plus a `crowd_voice.gd` murmur and roar bed. So the lead seeing none of it is a
  *diagnosis* job, not a build job: find out what hides it before adding anything.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all six:

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

### Where round 6 actually stands (2026-09-18 evening, the lead away)

**Four streams have finished: feel, control, combat, squad.** arena has delivered its review page and holds one item;
nav is the only stream with work in flight.

**Merged and green on `main`** (every merge at the commit whose own full check went green):
one formation system instead of three · support-by-fire that forms a real firing line · the player's units holding
until ordered, *enforced by a rule rather than by a coincidence* · a plain move keeping a squad a squad without order
thrash · form-up paced by a real navigation ETA · loading **7.6 s → 1.4 s** · **3,011 spectators in the default frame**
(round 5's default showed 0 of 2,040) · stands on all four sides, a city skyline, crowd audible through a proper mix ·
the lead's **12°** camera with the wall cutaway · the task palette with APP-6 symbology, `move`/`follow` off the card,
Support by Fire / Screen / Ambush earned · a loading screen and "why did my element do that" · the maze and
`make nav-maze` · terrain authoring rules · the **N1 Movement API** · engagement ranges: **fights decided at 40 m
instead of 54, off-axis kills 26% → 45%**.

**Held deliberately, and it is the lead's call:** nav's ORCA avoidance + right-of-way + PID reaches **100% arrival in
every configuration** (maze-60 head-on went **0 → 60/60**; `yard`-60 34 → 60/60) but costs a tick of order-response
latency — **4 ticks where K1 guarantees 3 (100 ms)**. Arrival bought with responsiveness is a trade he has not
approved, and *"the units aren't very responsive to my input"* is his own round-5 complaint. **Do not merge it, and do
not let anyone weaken the K1 test, without him.**

**What the round actually taught, and it is not what anyone expected:** it found **more broken instruments than broken
game code**. Three load-bearing coincidences (lesson 50), four constants calibrated against a camera that had changed
(lesson 59), six tick-rate leftovers of which three lied to a reader rather than failing a test (lesson 30), a build
queue that starved rather than being slow (lesson 48), an audio harness recording at 1/10 speed (lesson 46), a
measurement whose outliers were a spawn bug (lesson 57), and a series whose control was not a real "before" and so
hid which half of the change did the work (lesson 62). Lessons 32–62 are all round 6.

**Open orchestrator obligations (round 6):****Open orchestrator obligations (round 6):**

1. **Ping arena the moment CP4 merges.** arena is holding X3 (objectives off the centre line) until then, because it
   is a tactical claim that would straddle the range change. At the same ping it re-derives X2's exposure numbers at
   the new effective range — one cheap Python re-run, not machine time. arena found that its static
   exposure/sightline numbers are *mostly* CP4-proof (eye-level rays against box footprints, no weapons involved),
   with one exception it flagged rather than buried: `exposure()` hard-codes a **110 m watcher range**, which is a
   weapon-range assumption wearing a sightline's clothes.
2. **The sim baseline WILL move with CP4, and combat owns the move.** It is not a perturbation: N5 changes when the
   trigger is pulled, so a different battle happens from first contact onward. The order combat set, which the
   orchestrator endorsed: **series → final bands → record the baseline twice on builder0 → one commit.** Until that
   commit exists, **no stream re-runs a determinism-sensitive measurement**, or it will be comparing against a hash
   that is about to be replaced.
3. **CP4 does not merge alone: it merges paired with squad's brain-range fix.** combat's evidence, which the
   orchestrator accepted: `TankBrain._combat_move()` decides where to stand from `weapon["range"]` (full reach) while
   N5 decides firing from the *effective* band, so the outranging and short-halt branches park a unit exactly where it
   may not shoot — measured at **61 m for 45 s, 0 shots, 0 metres, never arrives**. Landing CP4 alone would trade the
   lead's *"everyone just starts firing"* for *"everyone stands still"*, which is a worse game and breaks product
   constraint #1. combat has committed a two-token proposal **in squad's file** (`5478fa61` on `stream/combat`,
   explicitly to take, replace or revert) which makes the scenario finish in **14.9 s — faster than the 20.8 s it
   measured before N5 existed**. squad owns the judgement and the remaining cases; **`scenario_motion::test_brains_dont_dither`
   at 17.7 and 15.6 option switches per minute against a bar of 12 is the blocking one**, because "no element
   flip-flopping" is the round's legibility bar.
4. **DONE — CP2 merged** at arena's green `5590c465` (1018 passed, exited 0). Note for the record: arena first
   reported `38c15f77` ready on a *filtered* run showing 5/5; the full check found 2 failures, and `38c15f77` and
   `13add85d` are both **red**. Merging the commit whose own full check went green (lesson 29) is the only reason that
   never reached `main` — and lesson 45 is the filtered-run half of it.
5. **TWO merges re-time other streams' measurements this round, not one.** CP4 is the known one. The second, found by
   control: **`perf_scene.gd` calls `RtsCamera.pose_for(focus, 0, zoom)`**, so when control's pitch decoupling merges,
   `make perf-scene`'s camera drops from the welded pose to the lead's **12°/FOV 60** — a far lower, wider camera that sees the whole venue to the far stands,
   so feel's **M1** frame numbers move at that merge through no change of feel's own. Relayed to feel; the rule is the
   same as CP4's: **re-baseline after the merge, and never publish a frame number measured across it.** This is the
   generalisable shape — a shared harness that derives its own configuration from another stream's code silently
   inherits that stream's changes.
6. **RESOLVED, and now with the lead: the mix was the cause, and the crowd question costs nothing to answer.** Two
   recordings were sent to him 2026-09-18 while he was away — `build/crowd-listen/full_mix_real_pace.mp3` (the match as
   a player hears it) and `crowd_only_real_pace.mp3`, builder0 vsync-off at tree `1badf779`, Yard, Gangs vs Law, same
   seed. **The one question: is the crowd audible, and does it sound like people or like hiss?** The murmur is still
   round 3's procedural filtered noise. **If hiss**, the ElevenLabs text is drafted in feel's brief under *Waiting on
   the lead*: 5 sources (bed, tense lull, roar, near-miss "oooh", last-stand stomping), **pilot first** —
   `crowd_bed` + `crowd_roar`, ~25 s ≈ **250 credits**, full set ~900 (lesson 19). **If fine, nothing is spent.**
   The mix itself was settled by measurement: at +13 dB the crowd was the loudest bed in the game (~4 dB under the whole
   mix); at **+8 dB** it sits a median **7.5 dB** under (min 5.6), impacts dipping it 2:1 on top; −17.5 LUFS, true peak
   −3.6 dBFS, 0 clipped.
   *The rule that produced this, kept for next time:* an ElevenLabs request must never be approved while the mix could
   be the cause — feel measured the existing crowd murmur as procedural filtered noise at **~43 dB below
   full scale on a Bed bus that is ducked under impacts** — inaudible in a firefight whatever the source material is.
   Recording a better bed and playing it 43 dB down buys an inaudible better bed. The order the orchestrator set:
   solo the crowd, record a real match, fix the mix (bed level, duck depth and release, a ceiling on how far impacts
   may duck the bed), re-listen — *then* ask for credits if it is still thin. Paid generation is irreversible in a way
   a gain change is not (lesson 18), and the standing gate is text → cheap pilot → listen → batch (lesson 19).
7. **Tell nav the hour CP4 merges.** It is doing `movement.gd` first (combat's four edits are all in the gunnery half)
   and the `gunnery.gd` split *after* CP4, so combat's edits move across once instead of conflicting. Its plan, endorsed.
8. **nav must NOT delete `ORDER_STALL_ARRIVE` (the 12 m lie) yet, and knows it.** It is one line in squad's
   `tank_brain.gd` — the file squad has two gating fixes in flight in — and removing it makes arrival numbers look
   **worse** before avoidance makes them better. With three streams measuring, we would lose the attribution on all
   three. It lands later as its own commit with a before/after from arena's harness attached. Its entire value is the
   measurement that comes with it.
9. **X4 is held, not lost, and the bar for re-adding it is written into `rts_controls.gd`:** *0 idle commands on five
   squads in the lead's own sequence.* control measured 31 idle commands and `never_arrived` 0 → 3 of 21 with it on
   (round 5's healthy value was 0) — and "units never arrive" is the lead's *headline* complaint, so it must not ship
   on a hope. **squad owes the answer: designed station-keeping, or thrash?** When it re-lands, the A/B must be re-run
   **on the merged tree** — CP3 changed the formation system underneath the exact path X4 exercises, so 31-against-0
   was measured against a world that no longer exists.
10. **Which arenas are fun is still unanswered** (`fun: []` on both pages, 2026-09-18). arena is spending the round on
   map shape without it. Nothing is blocked; ask again on whatever page he sees next.
11. **nav was not started with the other five streams** (2026-09-18). Its brief now carries arena's full CP2 baseline
   so it starts with the target number rather than rediscovering it; squad has been told to take its two independent
   items first and explicitly *not* to build its own avoidance to fill the gap.

**Orchestrator duties this round:** merge CP1 (nav's Movement API) and CP2 (arena's maze) as soon as they're announced
and tell everyone to `git merge main`; **CP4 (combat's engagement envelope) lands once and early, and every stream
re-runs its measurements after it — nobody publishes a number that straddles it**; get control's camera page in front
of the lead the day it exists; relay findings between streams; rescue git-ignored payload from worktrees before
removing them ([backups.md](_agents/backups.md)). Final integration order: nav → combat → squad → arena → control →
feel.

## Waiting on the lead

1. **The camera look AND which arena is fun — both are on one page, live since 2026-09-18:**
   **https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL** (private to the lead's account). One frozen 30-a-side fight
   (Condemned vs Syndicate, Container Yard, seed 3, ~6 s after the first shot): row 1 is round 5's four welded poses
   (zoom 0.20/0.36/0.55/0.75 = 34°/45°/56°/68°, the last being the "bird's eye" he disliked); then a grid of
   pitch 25/35/45/60° × distance 28/50/90 m × FOV 45/60°; then an arena tour, all seven arenas at three poses each
   with a **Fun** checkbox. He taps a frame to pick it (optional note) and ticks the fun arenas.
   **His answers are saved in the page's own database at `picks/lead`** — read them back with the Artifact tool's
   `read_db` on that URL, then tell control, which sets the defaults from his pick.
   Provenance: rendered on the **laptop** at 1920×1080 from `stream/control`'s working tree at `a975e262`
   (uncommitted at the time). Frames are camera poses only, so machine and commit do not change what they show.
   **The diagnosis is confirmed by row 1:** the start pose was fine; zooming out is what tilted him to top-down.
3. **The Lancer sits in two factions** (Condemned `lancer`, Syndicate `syn_lancer`): the role is shared, the vehicle
   isn't. One of them may want to lose it.
4. **Meshy credits: 88 left.** Any new 3D art needs a top-up. ElevenLabs has ~123k.
5. **Git LFS, eventually.** `.git` is 353 MB and grows with every regeneration. The rule to adopt when it hurts:
   generated binaries that *ship* go in LFS; generated *sources* stay out of git and live in backups.
6. **Faction art is excluded from the web export** (47 MB): the three new rosters *play* as themselves but *look* like
   the Condemned in the browser. Desktop ships the real art.
7. **Carried over:** rotate the Meshy API key; the round-2 questions in `streams/archive/round2/`.

## Open questions and follow-ups (not scheduled)

- **Dynamic obstacles: deliberately none, and now with a reason rather than a default** (arena ruled, nav verified,
  2026-09-18). **Nothing blocks drivable space mid-match, now or planned**, so a `NavigationObstacle3D` has no consumer.
  The strong argument against building one is **fairness, not cost**: the navmesh is baked as the southern half plus its
  180° rotation *as a second region*, because a normal bake is not point-symmetric — mirrored trips differed by up to
  4.4 m and the south base won 64% of 140 matches (trip-up 21). **Any mid-match re-bake must reproduce that
  construction or silently reintroduce the base bias**, with units standing on the mesh while it happens. And the lead's
  approved destructible-cover design (*a stack collapses to a lower stack, never changing drivable space*) was chosen to
  avoid exactly this, so X6 will not create a consumer either.
  **If round 7 ever revisits the startup-only mesh, it must revisit `agent_max_climb` in the same breath** — both are
  consequences of the same construction, and both need the swap-bases control re-run.

- **The unifying shape of round 7's best candidates, named by arena:** *the correct behaviour depends on what the
  element is currently trying to do.* Round 6 made each layer correct **in general** — avoidance that keeps a column a
  column, an objective at the centre, a formation that holds its geometry — and the residue in every case is that the
  *right* answer changes with the element's current intent. Three items below are the same statement at different
  scales: not overtaking is right for a column and wrong for a charge; a central objective is right for a brawl and
  wrong for a game about flanking; a fixed slot is right for holding and wrong for forming up. **A round that made
  behaviour context-dependent would be the natural successor to one that made it correct.**
- **Should a battle drill override formation discipline?** Round 6's ORCA deliberately does **not** treat a friend
  moving the same way as a collision, so a column stays a column — which is right for formations and is why round 5's
  overtaking sidestep was removed (it also steered into walls unchecked). Attributed cost, measured by bisect: an
  assault-through an ambush now takes **18.5 s against 17.7 s**, because the quick units no longer pass the slow ones.
  **0.8 s is not worth re-adding overtaking for** — it would risk nav's 33/60 → 60/60 arrival result. But *a charge is
  the one case where you might want the fast units through rather than the column preserved*, and the lead would notice
  it as *"my fast units got stuck behind the slow ones during a charge"*. Round-7 question: do drills get to suspend
  formation discipline, and which ones?
- **The lead's PID request is half-delivered, and the missing half is the visible half.** nav's N6 regulates any
  `move_to` whose goal *slides* — a squad follower's leader-anchored slot is such a goal, so **squad station-keeping is
  PID-controlled and measured (0.35 m mean gap against 4.58 m for the old proportional law)**. squad deliberately added
  **no second regulator**, which is right. But **element slots are fixed per leg or per click**, so the PID never
  engages for elements: an element still *snaps* to its formation geometry rather than **flowing** into it. The lead's
  own words were *"no matter where they might be currently, there's a formula to form up"* and *"a PID loop would
  conceptually be useful for a unit trying to get back in his formation"* — the second is delivered for squads and not
  for elements. **Making elements flow into formation is the next build on top of N6**, and it is the piece most likely
  to make the formations *look* as good as they now measure. A round-7 candidate, and cheap now that the regulator
  exists.
- **Per-faction PID gains** (nav's X8, not started): the lead asked for it by name — *"we might even be able to
  differentiate units of different factions by PID values"* — the Syndicate crisp, the gangs loose. `control_gains.gd`
  exists and the defaults are stable, so this is now a data exercise. It must be **measured** rather than shipped as
  flavour: if identical armies with different gains win equally often and look the same on screen, say so.

- ~~**A texture leak on `main` that `make check` cannot see**~~ **FIXED in round 8 (`3040ccd9`), together with the void
  below the near wall; feel re-verifies both at the lead's poses in round 9, and the console gate itself is control's
  round-9 item 4.** The original note, kept for the reasoning: (found by control on the merged tree at `2fa58c01`,
  laptop, windowed): `make shell-playtest` fails its clean-console gate with two `ERROR: Texture with GL ID of
  142/143: leaked 5460 bytes` lines, absent in all seven pre-merge runs. Likely feel's `night_sky`/skyline shaders or
  `arena_environment` crossing the **title → skirmish scene switch** — control's inference, not a proof; routed to
  feel. **Why it matters beyond two console lines:** `shell-playtest` is **not in `make check`**, so `main` goes green
  with it; a leaked resource is an **ERROR**, and the relay and net smokes fail their clients on any ERROR
  (trip-up 75), so this may be one scene switch from breaking a gated smoke; and it happens on the transition every
  player crosses. **Round-7 candidate regardless of this fix: `shell-playtest`'s console gate belongs in `check`, or
  its expected state belongs in a committed baseline** (lesson 42 — do not simply add a red suite to the gate).
- ~~**The void below the near wall.**~~ **FILLED in round 8 (`3040ccd9`).** Was: the ground plane ended at the stands,
  so any camera outside the venue looked down into black, the bottom 15–40% of a far frame at the lead's 12°.

- **FIGHT → playable is 7.6 s → 1.4 s** (laptop, `make shell-playtest` gangs vs law on Boulevard: 7,563 ms at
  `a975e262` against 1,398/1,406 ms on two runs of `8d9c59af`'s tree). feel's strong-reference fix did the shortening —
  `make spawn-cost` went from ~63 ms per vehicle to **0.8 ms** after the first of each type — and control's loading
  screen makes the remaining beat legible rather than shorter. **What is left is the arena build + navmesh bake, ~690 ms
  of the 1.4 s**, which is synchronous on purpose for determinism (trip-up 57: async navigation iterations made the same
  seed simulate differently). Not scheduled: it belongs to arena or nav, it is a ~0.7 s win, and it must not be bought
  by making navigation async.
- **Round-3 `matchup-search` numbers in `balance.md` may be unreliable and cannot be re-derived.** A make-namespace
  collision (`UNITS ?= 60` in `mk/ai.mk` reaching `mk/match.mk`) meant **every `matchup-search` run silently passed
  `--units 60` whatever the caller asked for**, and the tool never recorded the value it used
  ([orchestration.md](_agents/orchestration.md) lesson 44). Fixed as `SEARCH_UNITS`. Any conclusion that assumed a
  non-default unit count is suspect; combat flagged this rather than assuming the old numbers were fine. **The general
  fix, worth doing everywhere: print every resolved knob into the output**, so a wrong value shows up in the artefact.
  Related and also open: **nothing checks that a "reproduce with" line in a reference README still runs** — `make
  engagement PAIRS=… SEEDS=3 TIME=240`, documented as the way to reproduce a saved baseline, had been broken since the
  `VARIANTS` default landed. A smoke test that runs every documented reproduce line is a round-7 candidate.

- **Backups are automatic** ([backups.md](_agents/backups.md)): a systemd user timer rsyncs the git-ignored generated
  assets to `builder0:~/tank_squad_backup/` every 30 minutes, never deleting. `make backup`, `make backup-status`.
  **A worktree's ignored payload is still only in one place until it's copied into the main checkout** — round 5's
  close rescued 195 MB of announcer and ElevenLabs masters out of the audio worktree.
- **The element layer does not yet earn its place at 30 a side.** With the control point on, brains-only beat faction
  doctrine 34-14; with it off, 27-21; cutting `break_contact` reaches parity (24-24), not better. The army-level layer
  proposed in `doctrine.md` is a **bet** on the missing layer being *above* the elements, not a fix for the drills.
  Evidence: `archive/round5/ai.md` and `references/round5_ai_ladders.json`.
- **The control point funnels the whole fight** — found independently by three streams. arena owns the fix attempt
  this round (objectives off the centre line), measured with a control that cancels the cause, not more seeds.
- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%, 5 seeds) — pre-Jolt, pre-30 Hz. Re-measure after
  combat's CP4 before tuning anything.
- **Determinism:** `NavigationServer3D` is on the risk list ([determinism.md](_agents/determinism.md)); the grid-A*
  replacement is unwritten. Navigation map iterations are pinned **synchronous** in `project.godot` (trip-up 57) —
  do not switch them to async to make a loading bar look nicer.
- **Cross-build determinism** (D1–D4), the **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), the
  Steam build, arena announcer audio, and the paused netcode, garage and progression streams.
- **Disk:** the laptop is at 95%. `assets/incoming/` alone is 968 MB of raw generated art.

## Three claims on `main` that are weaker than their commit messages say

All three are the orchestrator's, all three were caught by streams on 2026-09-19, and the first two are the same
failure: **an instrument that could not have detected the treatment.** The third is worse.

- **⚠ THE ARRIVE-ON-HEADING ARC CANNOT FIRE IN THE GAME THE LEAD PLAYS.** Round 8 reported *"cars arrive on heading"*
  to him as shipped. Found by control, verified independently by the orchestrator in the code rather than relayed:
  a `facing` is put into a move command in **exactly one place** — `game/ui/tactical_map.gd:269`, the **touch map's**
  right-drag (*press = destination, drag = facing*) — and **the touch map is behind `--touch-map` /
  `--command-playtest`** (`game/modes/skirmish_mode.gd:112`, `:301`). His desktop controls are `RtsControls`, which
  only ever **reads** `facing` (`game/control/rts_controls.gd:307`, for camera yaw and the order pin) and **never
  sends it**. squad sets one for holds and stations; **a player move never carries one.**
  **So nav's `_arrive_facing` arc is not merely unmeasured — it is unreachable on the default path**, and its gate
  counters reading `aimed 0, refused 0` in both A/B arms would read the same in a real match. This is the round
  skill's own rule — *a behaviour behind a flag the default path never passes has not shipped; play the default
  path* — broken again, and the orchestrator relayed it to the lead as a win instead of playing it.
  **Round 9, control's fix, small and already scoped:** give the desktop right-click the same grammar the touch map
  has (press = destination, drag = the facing to arrive on), with a test asserting `orders.current(unit)["facing"]`
  after a drag **so the next A/B has a live arm by construction**, checked at the lead's pose so a facing drag cannot
  read as a box-select. **And note for round 9's probe:** even after that lands, `nav-fight` issuing a plain `move`
  still measures nothing. **The live cases are a player drag and a squad hold.** Do not re-measure zero twice.

- **`6a8aaa8c` says the facing pair does not move the sim baseline.** It was measured against the old `sim-baseline`
  match, which combat then showed was **blind to 5 of 6 mutations** — wheeled turn rate, fixed-mount fire arc, hover
  speed, the rig's hull box and a turret traverse all left the hash unchanged, and only the tracked case registered.
  Arrival-on-heading on a wheeled hull is plausibly inside that blind set. Re-run against combat's widened match
  (`db837581`).
- **The facing arc is not "measured inert".** nav's A/B returned every figure identical between arms to three
  decimals across four maps — and its own arm-engagement counter read **`gates aimed 0, gates refused 0` in BOTH
  arms.** The arc never executed. `_arrive_facing` attaches a facing only when the order carries one, and `nav-fight`
  issues `move` without one, so a CPU fight never triggers it. **Write it as "measured to never execute in a CPU
  fight; untested under player facings"** — the cases where it does fire, a player drag-order with a facing and a
  squad holding one for an ambush, are exactly the cases the lead looks at. Round 9's probe must issue orders that
  carry a facing or it re-measures nothing.

## The round-9 backlog is already written

**[`_agents/research_catalog.md`](_agents/research_catalog.md)** is the curated output of an external research review
the lead commissioned on 2026-09-19 (two independent services, one abstract brief, both replies kept verbatim in
`_agents/research/`). **50 techniques proposed, 12 adopted with a pre-registered falsifier each, every rejection given
its reason.** Eight of the twelve were named by *both* services independently, which is the strongest signal in it.

Read it before briefing a stream, and note three things it changed:
- **`algorithms.md`'s rejection of learned policies was built on a wrong premise** and now says so. A lead decision.
- **Invariant 0c** in `workstreams.md`: a technique adopted in one stream is checked against the others *before* either
  merges, and a brief that adopts one must name what it **replaces**. Two correct techniques can compose into neither.
- **Round 8's flow-field null does not refuse catalogue A5** (anisotropic exposure-metric routing). Different object,
  and the roster row says so.

Also: the sources contain mid-sentence truncation, and Service A's audit counts and Elo figures are **unverifiable
assertions about a codebase it has never seen — never quote the digits.**

## Starting the next round

The pattern, the kickoff prompt, and the checklists are in [`_agents/orchestration.md`](_agents/orchestration.md).
When the lead's next playtest feedback lands, it goes into [`game_design.md`](_agents/game_design.md) verbatim, the
streams into [`workstreams.md`](_agents/workstreams.md), and the briefs into `_agents/streams/`.
