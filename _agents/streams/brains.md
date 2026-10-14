# Stream: brains (the yard's last crew in every time AND a car that arrives facing the way it came; gang trucks' screen slots filled; your bridge 108/108)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–305, **305 is yours**), `_agents/game_design.md`
> *Round 28 direction*, *Round 29: his artillery call*, `_agents/doctrine.md`, `_agents/workstreams.md` **Round 30**
> (C30.1–C30.10, especially **C30.5**, **C30.8**, **C30.9**), and round 29's brains report
> (`streams/archive/round29/brains.md`: *FINAL REPORT*, **B5c**, B3, B4, *support by fire*). **You own:** `game/ai/**`
> EXCEPT traffic's, manoeuvre's, native's and the planner's carve-outs (C30 list; `order_controller.gd` is manoeuvre's face
> path + native's seams; `game/ai/planner/**` is the planner's), `game/tactics/**`, `tests/ai_scenarios/**` (others add
> their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
> `tests/test_nav*.gd`, `tests/test_form_up.gd`, `tests/test_wheeled_arrival.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`,
> `doctrines/doctrine_*.json`. **Granted to others in your files:** traffic's gate lines (C29.3, standing); manoeuvre's three
> lines in `TankBrain._order_move`. **The C++ (C30.2):** `decide`, `build_situation`'s core, the TacticalQuery functions and
> `_approach_gate` run in C++ (native's mirror of B5c is on `lab/native-b5c`): a change there goes to native as a diff
> first. **Model:** this stream runs on the usual model (Opus).

## The lead's direction

**Round 28, his calls (2026-10-12):** artillery with a drawn side: **SHELL FROM HIS SIDE** (shipped, round 29); a drawn
flank onto a stronger squad: **SWING ROUND ANYWAY** (shipped, round 29). Round 24, his bridge: every squad across, both
sides. **Round 30 (2026-10-14):** no new words from him on brains; the carry-overs are the orchestrator's.

What he will notice: at the yard crossing the last crew of his squad is in every time (round 29's gate won that, 7/12
never-in → 12/12) AND a car ordered to face the way it came still turns round and parks facing it. Four gang trucks on a
screen all take their slots. His bridge drill passes every cell.

## Where things stand (main `0d35f215`, GREEN: builder0 2584/0, 26 ALL JUDGED)

- **B5c the arrival gate — PARKED after passing its bar, by the rule set before its proof.** `lab/brains-r29-gate` =
  `a8df3dc3`; flip `brains-b5c-flip` = `ed843d63`; native's mirror `lab/native-b5c` (equal: 6000 drives + 189 forced
  stalls, 0 mismatches; `b01a8959` mirrors the fix, unrun). The judged attempt `053beffb` passed EVERY line (yard crossing
  last crew in: never 7/12 → 21.95 s 12/12; Sumps all-within-8 m 38.8 → 36.0 s; arrive series 89 → 100/100; bridge-pooled
  18/18; counters on/off). **Then the pair check went red on round 8's `test_wheeled_arrival` (face the way it came, 180°):**
  the gate lies 17.5 m PAST the goal, the car reaches it still pointing out (dot −0.88), v2's latch marks it done and it
  arrives 60° off. The narrow fix (a gate reached facing away is not latched; `_gate_turning_for` holds the stalled
  give-up while turning) passes that test but MOVED the judged cells (yard 23 t3 22.1 → 39.9 s; `reached_facing_away`
  fires 129–220 times a yard cell): **the yard crossing reaches its gates facing away often, so the latch is what wins
  yard.** Worst run (Terminus seed 3): B_4, 9 m from its slot, pulled 17.5 m back to a gate and jammed on terrain ~8 s
  (manoeuvre's M5 this round, C30.5). Lesson 305.
- **B4 (gang trucks' screen slots) rides on B5c:** `make screen-slots` (TacticsLab seed 61, four 14 m gang_tank, screen
  east): A_2 blocked no_path/terrain from 20 s, 18.5 m off; a spacing pass (`lab/brains-r29-linespread`, pitch 6.0 →
  15.8 m) does NOT free it; B5c's rule does (A_2 in at 18.3 s). Six metres between 2.9 m-wide hulls is physical.
- **B3 his bridge — two cells, one fixed, one needs route-aware seating.** `lab/brains-r29-bridge` = `474cf510`: rust t5
  seed 1 fixed by the mouth guard (gives way while the crew holds up a squadmate, `--mouth-held=off`): 4/4 in 39.3 s.
  **Rust t16 seed 2:** when the drill ends at 12.5 s an attack-move seats by straight line (drills on: no transit, no route
  seating), the seating is fixed when the flow joins, both crews route east round via the bridge and their seats CROSS;
  S_2 yields at the rim. Needs route-aware seating for an attack-move across a crossing.
- **Support by fire, wheeled turret hulls (REPRODUCED, not fixed):** `make hull-rest-probe FACING_ONLY=faced_support_by_fire`
  (`053beffb`, 24 runs an arm): wheels/turret drawn median 80.5° v clicked 57.1° (p 0.019). But in every law run, BOTH
  arms, the squad is NOT ARRIVED when the probe reads it ("settled" ≈ 19 s, crews still): it measures hulls stopped on the
  way. Needs a per-crew trace of a drawn SBF before any fix.
- **`test_tactics_scenarios.gd` is 425 s**, the floor of any shard plan at 5–6 shards (traffic's round-29 measurement).
- B1 (artillery from his side), B2 (the flank), B5 (queued attack) are on main and he plays them.

## Backlog (in order)

**B5c-v4 — the gate that keeps yard AND the 180° arrival (DECLARED; CP-G; a pair with native from `lab/native-b5c`).**
Design from the round-29 record, pick by tracing yard 23 t3 and the 180° test side by side: (i) latch a gate reached
facing away only after ONE circuit (the car has shown it cannot align in place), else keep the latch as v2; or (ii) lay
a 180° gate to the SIDE of the goal (a turning-circle offset), never beyond it, so the car reaches it near the heading;
plus the round-29 refinement: **no gate when the hull is already within the approach length and the route via the gate
is much longer** (B_4's 17.5 m pull-back). Test first, on the default path, BEFORE any series: `test_wheeled_arrival` (all
cases), `test_nav_arrival_heading`, `test_nav_gate_hold` (on `lab/brains-r29-gate`), a new 180° heading test, `test_native_gate` with native's mirror.
**Bar (send before numbers; last attempt named; cite sizing's rows if CP-N has landed, C30.3):** round 29's B5c bar
(yard crossing last-crew median on ≤ off − 5 s and crews ≥ off every run, n = 12; Sumps all-within-8 m median ≤ off, no run
> 5 s later, guns_on_arc ≥ off − 0.05, n = 12; arrive series 8 m ≥ control − 1, median ±2 %; counters on/off; bridge-pooled
18/18) **plus, from the start:** the 90° AND 180° heading tests on the default path; Terminus seeds 2–4 crews arrived ≥ off
and B_4's pull-back gone (a hull within the approach length gets no gate: counter); `make screen-slots` seed 61 A_2 in
(B4). Partial: none. Shipping = the default flip + native's mirror as a pair; native shows yard and Sumps on the ON path
equal to the judged on-arm run for run (round 29's merge condition stands).

**B7 — split `test_tactics_scenarios.gd` (C30.9; early, one commit, no series).** Two files balanced by
`tests/shard_times.txt` (traffic's `make test-times`), no behaviour change, the same tests byte for byte; `test wall` and
the shards' seconds before and after in the commit message (builder0, same load noted). Do it right after B5c-v4's tests
are written, so every check this round is shorter.

**B3b — route-aware seating for an attack-move across a crossing (DECLARED): his bridge 108/108.** From
`lab/brains-r29-bridge`: keep the mouth guard (rust t5 s1); for rust t16 s2, seat an attack-move whose element must cross
a bridge/mouth by the ROUTE (the seat order follows the crossing order, as transit seating does), so seats do not cross.
Bar: his bridge drill 108/108 (`make bridge-series`, the full 108-cell grid, both sides); bridge-pooled 18/18; arrive series 100/100
unchanged; Sumps/yard cells unchanged within 2 se; ≤ 0.5 ms; the mouth-guard counter fires. Native: say whether any
line is in ported code (`native-verify-scenarios`).

**B6 — support by fire, wheeled turret line: trace first.** A per-crew trace of a drawn SBF (the screen test has none):
which crews are read before arrival, where each stops and why, the line's bearing per crew at true arrival. Fix the
PROBE first (read only after `all_in8_s`), re-run both arms, and only then decide whether there is a fix (DECLARED, own
bar) or a measurement artefact (write it up and close it).

**Stretch:** the ambush/screen facing for a line of mixed classes (if B6's trace shows a class problem). Nothing else.

## How to verify

`make remote T=check` (builder0 only, C30.7); `make bridge-series`, `bridge-pooled`, `squad-arrive-series`, `screen-slots`,
`hull-rest-probe`, the yard / Sumps / Terminus cells as round 29's B5c record names them (their targets are on `lab/brains-r29-gate`), `native-verify-scenarios`;
`test_wheeled_arrival`, `test_nav_arrival_heading`, `test_nav_gate_hold` on the default path BEFORE any series. A clip of the 180° arrival and of the
yard crossing for him. Every number carries its commit, machine, workload and n; the worst run's trace before the median.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; manoeuvre's drive body, unstick, k-turn block, `manoeuvre*.gd`,
`wall_contact.gd`, `order_controller.gd`'s face path; native's `native/**`; `game/control/**`, `game/tank/**`; the
planner's `game/ai/planner/**`; sizing's `tools/judge/**`.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: every number names commit, machine, workload and n; bars go to the orchestrator before
numbers; the report at the top)_

### Plan (2026-10-14; start = stream `bd05077d`, covered by the launch check, main `0d35f215` green)
1. **B5c-v4** on `lab/brains-r30-gate` (a C30.2 pair: the stream tip stays mergeable without native's mirror). Base =
   round 29's gate restored (`0c7a6e72`), `--gate-trace` (measurement only), the v4 rule + `tests/test_nav_gate_v4.gd`;
   traced side by side first (yard 23 t3, the 180° test); the bar to the orchestrator before any series; the settled diff
   to native.
2. **B7** on the stream right after v4's tests: time each scenario test alone (`make scenario-times`), split into two
   files by those times, one commit, `test wall` before/after.
3. **B3b** route-aware attack-move seating across a crossing (from `lab/brains-r29-bridge`).
4. **B6** the SBF per-crew trace; fix the probe first.
5. Stretch: mixed-class line facing, only if B6 shows a class problem.

### B5c-v4 — traced side by side, the design picked (builder0, GDScript drive `--brains-off=native`)
Round 29's state (`a8df3dc3` restored at lab `0c7a6e72`) reproduces: yard_open cross seed 23 t3 last crew A_5 **39.9 s**
(round 29: 39.9). `--gate-trace` per crew:
- **The 180° test** (`test_wheeled_arrival`, IFV, open ground): reaches its gate 17.5 m beyond the goal facing out (dot
  −1.00), comes round it (reads `blocked no_path` while circling at speed), reaches it again facing out once, then at
  dot 0.01, latches, arrives facing back (> 0.85): ~8 s of turning.
- **Yard A_5** (herringbone seat facing west, gate 20 m east of it): it drove in from the north-west PAST its seat and
  reached the gate facing east (dot −0.94): **the same geometry as the 180° test.** Coming round it ran south into the
  containers (`blocked terrain` at (16, −68) 6 s+), was given up, re-aimed after a re-seat, reached it facing away again
  at 29.8 s, ran north into the containers (19, −40), and latched only at 38.5 s.
- So "one circuit" (option i) as "the second facing-away reach" would fail the 180° test (it reaches facing out twice
  before it lines up), and a gate to the side (option ii) is a new geometry with no trace behind it. **Picked:** come
  round a gate reached facing away only where a turning circle of navmesh fits BESIDE the gate (either side, 12 points
  at one turning radius from a centre one radius off the axis), and only until stuck (`blocked` on terrain or a hull;
  `no_path` is the circling) or `GATE_TURN_SECONDS` 12 (≈ 1.5× the open-ground turn); else latch and drive onto the goal
  (round 29's yard win). Plus **near**: a NEW goal already within the approach length, whose drive via the gate is more
  than 2× the straight line, gets no gate (B_4), decided once per goal so a car coming round its own gate is never caught.
- **Tests first** (lab `19eca15a`, builder0, `make gate-test`, GDScript drive): `test_nav_gate_v4` (180° comes
  round with `gates_turned` > 0 and no latch away; 90°; the turn room; the bounds: `no_path` keeps turning, terrain
  latches `turn_blocked`, 12 s latches `turn_capped`; B_4's near case 9 m off; the planner's scout case: law_scout 9 m
  short, facing back, drove 102 m on main, now near fires and < 30 m) + `test_wheeled_arrival` (all) +
  `test_nav_arrival_heading` + `test_nav_gate_hold`: **24 passed, 0 failed**. On the DEFAULT path they need native's
  mirror (the pair).
- **The near rule is judged on the NOMINAL approach** (before the roomy shortening): the roomy rule halves some gates
  (8.8 m on the default layout), and B_4's and the scout's gates were nominal.
- **Tuning** (round 29's seeds; lab `19eca15a`): yard 23 × 6 ticks last crew median 21.1 s on v never off (all in 6/6 v
  2/6); Sumps 2 × 6: 24.3 v 24.4 s, arc equal; Terminus 2–4 t11: 10/10 ×3 v 9/10 twice (near fired, seed 3 = B_4's).
- **Bar** sent 11:1x PDT and ACCEPTED by godot-67 before numbers (filed in workstreams *Bars (round 30)*), with its
  additions: worst on-arm run of (1) and (2) traced first; each come-round's ending counted per arm (latched / stuck /
  cap; mostly-cap is a finding); cost ≤ 0.5 ms at Sumps 25 a side or NOT READABLE; thirteen explained if they move;
  Terminus seed 3 reported only. CP-N landed during the run: the bar stands as filed, reported with the table's se.

### B5c-v4 — JUDGED (lab `19eca15a`, builder0, GDScript drive both arms, `make gate-series`, fresh seeds)
| line | n | on | off | reading (CP-N) |
|---|---|---|---|---|
| (1) yard crossing, runs with every crew in | 12 | **12/12** | 1/12 | Fisher decides at n = 9: the deciding line. PASS |
| (1) yard, crews on ≥ off every run | 12 | 12 of 12 runs | – | PASS |
| (1) yard, last-crew median | 12 | 19.0 s | never (11 runs) | ≤ off − 5 s; A/A ±9 s, se ≈ 3 s: reported, not deciding |
| (2) Sumps all within 8 m, median | 12 | 24.5 s | 37.5 s | PASS; no run > 5 s later (0 of 12) |
| (2) Sumps guns_on_arc mean | 12 | 0.941 | 0.941 | PASS (≥ off − 0.05) |
| (3) Terminus seeds 3, 5, 6, 7 t11 (reported) | 4 | 10/10 every run | 10/10 every run | near fired every run; seed 3 (B_4) last 50.1 v 56.8 s |
| (5) counters | 28 a arm | > 0 every on run | 0 every off run | PASS |
| (4) arrive series, within the element's 8 m (5 maps × 5 squads × seeds 29–32) | 100 | **99** | 91 | McNemar 8 v 0 discordant (decided); PASS (≥ off − 1) |
| (4) arrive series, every crew on its slot | 100 | 89 | 77 | reported |
| (4) arrive, paired median within 8 m (91 cells in both) | 91 | 24.5 s | 29.6 s | −17 % (paired diff −8.4 s, se 1.6); PASS (no slower than +2 %) |
| (6) bridge-pooled, rule on (GDScript) | 18 | **18/18** | – | PASS |
| (7) screen-slots seed 61 (gang_tank ×4, screen east) | 1 | A_2 in 22.8 s | A_2 never (18.5 m off) | PASS; A_4 ends 5.4 m off in BOTH arms (not "in"): B4 not wholly fixed |

Arrive counters: 98 of 100 on-arm runs fired an event counter; the other two show the rule acting or not needed (yard
law_ifv×2+suppressor+tank seed 32: refused only `cramped` 224 plan ticks, v3's room rule; pit law_scout+ifv+tank×2 seed
29: only `on_approach`). Totals over the 100: turned 25, latched_away 1, near 148.
