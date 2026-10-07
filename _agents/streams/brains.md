# Stream: brains (his attack is obeyed under every order; an attack on a vehicle that runs is a pursuit)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 20, afternoon* and *Round 20,
> evening* (his words and the orchestrator's reading of his recording), `_agents/doctrine.md` (*Form up on the move*,
> *Round 20 (brains)*), `_agents/workstreams.md` *Round 21* (C21.1, C21.2, C21.4), and your own round-20 final report
> (`streams/archive/round20/brains.md` Status: M1's converge design and its yard case, M1b's `Drills.obeys_attack`, M3's
> series method, the two stretch items). You own `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`,
> `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`,
> `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you declare. Orders' probe files
> (`game/control/two_squads_playtest.gd`, `tests/test_control_two_squads.gd`) are READ-ONLY instruments for you (C21.4).

## The lead's direction

Standing: *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as smart"*
(2026-10-04). After round 20's CP1 (2026-10-06 afternoon, 25 Rat Rods ordered to attack one vehicle): *"they all just
spread out and drove away"*. After the close (2026-10-06 ~18:40, foundry, seed 29989, 25 Rat Rods v the Syndicate):

> *"I just played again with 25 scouts, once again just trying to attack a target in formation. A lot of vehicles
> didn't actually drive toward the target they just circled around. I don't know if that was them trying to get in
> formation or what, but even when there was only one vehicle remaining it was still just driving in circles instead
> of actually moving to the target I designated"*

**His recording is the evidence:** `build/recordings/2026-10-06T18-38-40.jsonl` (main `6c03daad`; the `task` lines
carry each drill's `why`, the census every 30 ticks shows the `hold` members and positions; lesson 264: read it before
theorising). Not on builder0 unless you copy it there.

## Where things stand (read at `366bef66`; the orchestrator's reading, to be verified by you)

- **The bait drill fires under his attack-MOVE.** Tick 474: a `move` task with drills on, five squads; tick 654: four
  `hold` + one forward in every squad but Alpha, which went in alone and died. `Drills.obeys_attack` (M1b) covers only
  `{"verb": "attack", "target": …}` from `state.player`; an attack-move is a `move` task that `ElementTask.runs_drills`,
  so `ELECTIVE_DRILLS` (bait, encircle) still fire. His direction is clear: the gangs' elective drills are the
  computer's choice, never a thing that happens under his order.
- **His named-target click worked** (tick 795, `attack Rust_Hunters_1`, "vee, as ordered"): every squad closed.
- **The circling, and a hypothesis labelled as one (lesson 219).** His last attack (tick 1827) named `Rust_Eyes_3`, a
  Syndicate spotter RETREATING from (−33, 6) to (15, −112) over 17 s. Bravo_1 drove east past the target's old position
  and back west (an orbit ~40 m across); Delta_1, the last vehicle, "arrived" 70 m short and sat, then crept.
  `ElementPlan._task_point` for an `attack` returns the target's position only while the target is in
  `situation.contacts`; otherwise the NEAREST contact, or `null`, and a null destination sets `plan["arrived"] = true`
  and halts. A retreating spotter that leaves the squad's sight therefore stops the squad where it stands ("arrived"
  70 m short); when it is seen again the destination jumps and the vee's stations are re-laid around the new point,
  and a lone Rat Rod at 18 m/s overshoots its station and circles back (M1's yard IFV case at scale). Bravo_4 was
  also `blocked/terrain` once at x = −96 after orders' row sent it to the wall (orders' O1, not yours).
- The thirteen baseline lines are CPU-v-CPU; your P1/P2 change HIS squads' behaviour, so they should be UNMOVED, but
  `Drills.select` and the attack plan run for both sides: pre-register, then adopt and name any line that moves (C21.2).
- Orders' row for several squads is capped this round (orders O1, CP1): your five-squad scenarios should assign tasks
  the way orders does after CP1, or say they assign directly (as M1b's scenario did) and so cannot see the detour.

## Backlog (in order)

**P0. CPU squad leaders ON by default (his answer, 2026-10-06 evening: *"yes let's just go ahead and add the cpu
leaders feature"*; C21.5).** `ELEMENT_CPU_DEFAULT := true` in `game/modes/skirmish_mode.gd` (your one carve-out:
that constant and its comment), a test that a flagless launch runs the CPU's elements and `--no-element-cpu` does
not. Pre-register which baseline lines and series launch with explicit flags (unmoved) and which inherit the default;
adopt and name what moves; merge ALONE, first, so his next game has it. Then M3's hidden line and round 19's posture
run on his path: say so in Status with the laptop price you have on record (3–5 ms a tick, round 19).

**P1. No elective drill under ANY player order (DECLARED, alone).** Widen M1b: a task from `state.player` (move,
attack-move, attack with or without a target, screen, hold) runs no `ELECTIVE_DRILLS`, and one already running stops;
reactions to contact (near ambush, break contact, react to contact) are unchanged; the computer's packs keep every
drill. Test first: `test_tactics_attack_obeyed` gains the attack-move arm (yard, five squads of five gang scouts, one
Law tank 70 m off; before: bait in some squads; after: none, every squad closes). Scenario then the recording's
case if you can replay it (`foundry`, seed 29989). Pre-register UNMOVED; adopt and name any line that moves.

**P2. An attack on a named target that moves is a PURSUIT (DECLARED, alone).** Design, decide and record the reasons:
(a) the destination is the target's live position while seen, its last-known position plus its last velocity × the
time since otherwise (a short memory, say 10 s, then the last-known point itself); never `null` while the target is
alive, so the squad never "arrives" short; (b) stations are laid relative to the target's velocity (lead it), the
whole squad at road speed, no `arrived` until inside the slowest crew's effective range (the spear's 30 m); (c) a
single survivor (or a squad of one) drives straight at the target: no station, no re-lay. Scenario first:
`tests/tactics/` pursuit probe, five Rat Rods attack a spotter retreating at 8 m/s (and one at 18 m/s, which they
cannot catch: they must still close, not orbit); assert monotone-ish closing distance (no crew farther from the
target at t+5 s than at t for any t after the first leg) and no heading reversal greater than 120° for any vehicle
while the target is alive. Then the arrive series (lesson 261) and a paired series on a fight with a retreating
target (CPU-v-CPU, the Syndicate's spotters do retreat): his loss, alive, time to kill, 8 seeds then 24 if inside
noise (M3's method). Ship on mechanism + all measures pointing the same way, as M3 did.

**P3. Doctrine + numbers.** `doctrine.md` *Round 21 (brains)*: P1's rule in one sentence, P2's pursuit with its
numbers; `navigation.md` only if routing changed.

**Stretch (a). The holding element falls back one bound when it is losing the trade** (round 19's −1.4 ± 1.2 vehicles
in the 8-v-4 stage). A new behaviour: scenario + paired series, DECLARED, alone.

**Stretch (b). The CPU squad leaders' next price cut by in-run A/B** (`make ai-ab-match`), not the profiler, which
overstated round 19's grounding cut (0.86 ms → 0.0 %). Equal-answer cuts only; the number in his frame on his laptop
is the orchestrator's quiet-window run, ask for it.

**Stretch (c). M1's yard case** (a wedge 100 m forward from the spawn row, an IFV backs round once, away 1.4 → 3.2 m):
the brain's aim point on a station kept outside a wheeled hull's turning circle. Only if cheap and measured on the
converge probe.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and the runner's
  `N passed, M failed`, never a pipe's exit code). 23 targets ALL JUDGED; thirteen lines + determinism as pre-registered.
- `make squad-arrive-series` both arms for P2 (lesson 261); `make converge-probe` for stretch (c).
- Play it: `make garage` → Road Gangs → CLEAR → tap the Rat Rod 25 times → FIGHT; select all, V (attack-move) across
  the floor: no squad holds back while one scout goes forward. Then attack one Syndicate spotter (right-click a
  vehicle): every scout drives at it; when it runs, they chase; the last one alive drives straight at it. Record and
  read your own recording (`build/recordings/latest.txt`).
- Screenshots at desktop and phone aspect of a pursuit mid-chase; look at them.
- Every number: commit, machine, workload, sample size (C16.3). Builder0 is ~2.75× faster than the laptop.

## Don't touch

`game/control/**`, `game/ui/**` (orders'; the probe is read-only for you, C21.4) · `game/theme/**` (airship's and
nobody's) · `game/garage/**`, `game/progression/**`, `game/units/**`, `game/match/**` (nobody; a signal is a request)
· `arenas/**`, `game/arena/**` · `mk/core.mk`, `tests/baselines/**` except declared lines · balance values (C12.6) ·
`game/modes/**` except the one constant C21.5 grants.

## Waiting on the lead

- Nothing. CPU squad leaders on by default is ANSWERED (yes, 2026-10-06 evening): P0.

## Status

_Updated 2026-10-06 evening (round 21, brains worker)._

### Plan (in order; each declared change its own commit, merged alone)

1. **P0** CPU squad leaders ON by default: the constant, `test_tactics_cpu_leaders_default` (his launch lines, the
   garage's fight flags, the control arm, and a real in-process skirmish that installs `ElementCommander_1` flagless
   and none with `--no-element-cpu`). Merge ALONE, first.
2. **P1** no elective drill under any player order: widen `Drills.obeys_attack` to every task of his; the attack-move
   arm in `test_tactics_attack_obeyed` first (fails today: squads 1 and 5 bait, laptop, seed 3).
3. **P2** pursuit: the probe first (`tests/tactics/`), then `ElementPlan`'s attack destination (live / last-known +
   velocity × age / last-known), stations led by the target's velocity, no `arrived` outside 30 m, a squad of one
   drives straight at it. Arrive series + a paired series.
4. **P3** doctrine.md *Round 21 (brains)*.
5. Stretch (a) the hold falls back one bound when losing; (b) the in-run A/B price cut; (c) M1's yard case.

### Start

`make remote T=check` on `0c243e8a` (the launch tree, untouched): builder0, **`>> remote: make check exited 2`**, 2165
passed 1 failed; `relay-smoke` FAILED (a client saw 4/5 tanks) and `test_control_order_marks::test_the_squad_pin_draws
_the_tasks_heading_and_needs_every_crew_without_one` (orders' file) failed; sim-baseline 13 maps unmoved. builder0 was
at load 13-18 with three streams' checks at once (37 other godot). Both reds are on the launch tree, not mine: seen
1 of 1 there, recorded here, watched in every later check (lesson 258c).

### P0 — CPU squad leaders ON by default (C21.5) — **GREEN `30c95bc5`, merge ALONE, first**

**Green:** `30c95bc5`, builder0, `>> remote: make check exited 0`, 23 targets all passed ALL JUDGED, 2169 passed 0
failed, thirteen lines unmoved (as pre-registered), determinism `762a0576f944f5b7` (unchanged). Its first check
(`58376350`) failed 22 tests in one shard: the in-process skirmish boot left the tree in the skirmish's planning PAUSE,
and every later test in that process drove a frozen world; the test now unpauses and restores the frame cap (P0
amended; local single-process run of it with the 22 victims: 32/0). **His path now:** the computer's posture, its
ambush and the hidden line run in every `make skirmish` and garage fight; the price on record is round 19's 3–5 ms a
tick on his laptop (not re-measured this round: the orchestrator's quiet-window run is the number in his frame).

**Pre-registered (before the check):** the thirteen sim-baseline lines and `determinism` launch `--match`
(`SIM_MATCH_ARGS`, `DET_MATCH_ARGS`: the match runner), which never reads `ELEMENT_CPU_DEFAULT`
(`SkirmishMode.cpu_runs_elements` is called only from `SkirmishMode.start`): **UNMOVED**. The series that launch
`--skirmish` with an explicit `--element-cpu`/`--no-element-cpu` (`ai-element-perfplay`) are unmoved. What inherits the
default: every flagless `--skirmish` run — his `make skirmish`, `make garage`'s FIGHT, orders' control-playtest /
two-squads / picker playtests, `perf-play`, `hud-cost`, the board and audio passes: their CPU side now runs squad
leaders (more AI time per tick; the CPU's movement differs). None of those is a baseline line; any that fails in the
check is named below.

### P1 — no elective drill under ANY order of his (DECLARED, `229c8a0e`)

`Drills.obeys_player(state)` replaces `obeys_attack`: a squad of his (`state.player`; on his team only he gives tasks)
runs no bait or encircle under any task (move, attack-move, attack with or without a target, screen, hold), and one
already running stops. Reactions to contact unchanged; the computer keeps every drill. **Before → after**
(`test_tactics_attack_obeyed`, the attack-move arm: yard, seed 3, five squads of five gang scouts, one Law tank 70 m
off, laptop): Squad_1 and Squad_5 baited → no squad ran bait or encircle, every squad closed 38-55 m in 15 s, the tank
destroyed; the computer's attack-move still baits in all five. Pure test of every task shape in `test_tactics_drills`.
**Pre-registered UNMOVED:** the thirteen lines and determinism (the match runner has no player team).

### P2 — an attack on a named target that moves is a PURSUIT (DECLARED; building)

**The scenario first** (`tests/test_tactics_pursuit.gd`; the open yard, seed 3, five Rat Rods, HIS attack, vee, on a
Syndicate spotter 70 m ahead that drives away and bears off right at 8 m/s, and one at 18 m/s they cannot catch):
before P2 every crew's hull turned 180° and the range opened +77 to +83 m in 5 s (the squad halted "arrived", ran far
ambush round a spot the target had left, then drove BACK to a stale leg anchor at its spawn). A trace of each layer
found five causes, each fixed and each in the commit:
1. **Null destination = "arrived".** `ElementPlan._task_point` gave the named target's position only while it was in
   the element's contacts. Now: its live position while seen; out of sight the element's own **track** of it
   (`Element.pursuit`, from team intel, kept after intel forgets it at 12 s) carried forward by its last velocity for
   up to `PURSUIT_MEMORY_S` = 10 s, then held there. **Decided against the brief's "then the last-known point itself":**
   turning back to an older point is itself a heading reversal, the thing being fixed.
2. **Contact drills against a running target.** A pursuit (`ElementPlan.pursues`: a named target moving ≥ 2 m/s or out
   of sight; sticky for the task) makes react-to-contact and far ambush give way (`Drills.PURSUIT_YIELDS`); and the
   target **coming back into sight is not an ambush** (it reappears "sudden" because the element forgot it; near
   ambush + assault through charged past its spot). A sudden enemy who is not the target is still an ambush (tested).
3. **The shape and the legs.** A pursuing squad of 2+ lays its formation (his vee) on where the target WILL be (led by
   its velocity × min(time to close, 3 s)), seats fixed once laid, every crew at road speed (no co-arrival pacing), on
   an attack-move that names it; no legs, no element-wide band, never `arrived`. A squad of one: `attack`, straight at it.
4. **Order thrash at the band.** Each crew decides by its own reach (range × 1.15, +15 m hysteresis once attacking):
   in reach `attack` (the executor keeps closing while the target runs), else its station.
5. **The brain's combat micro.** Under an attack (or an attack-move naming it) on a target opening the range ≥ 2 m/s
   beyond the gun's preferred band, `TankBrain` ENGAGE drives at where it is going (`TankBrain.chases`) instead of
   circling the target's spot in the band (the run/strafe micro is what orbited).
After: 8 m/s worst closing −7.0 m, worst hull turn 50°; 18 m/s −8.7 m, 95° (both under 120°, laptop). **Stage:** the
open yard; on the container yard a crew meeting a 12 m container backs round it (routing, not an orbit) and the
reversal measure then counts it. **Measures:** the HULL heading while driving and farther than 35 m (inside, turning
round a target it is shooting at is the fight), not the travel direction (a crew backing a metre flips it 180°).
**Control arm:** `--pursuit=off` on any match run or probe (`TacticsFlags`, `settle_probe`, `pursuit_probe`).

**The out-of-sight case** (the orchestrator's question; `9226a007`): five Law tanks (12 m/s, 78 m sight) see a spotter
60 m off that drives away at 18 m/s; team intel forgets it for 10 s. The squad never reports arrived while it lives
and ends 7.9 m from it (seed 3, laptop). Before P2 this was the null destination = "arrived" (his 70 m-short sit). One
164° turn when a crew sees it again to its side (it turned twice unseen and the track carried it straight on): a
wrong guess corrected once, reported, not asserted.

**Series** (`make pursuit-series`, `tests/tactics/pursuit_probe.gd`: his two squads of five Rat Rods attack a Syndicate
spotter + scout under the CPU's squad leader; **laptop**, `9f392432`, **24 paired seeds per map**, on − off):

| map | time to kill | his loss (HP) | alive margin CPU − his | his hull reversals (runs' total, on / off) |
|---|---|---|---|---|
| yard_open | −2.47 s (sd 3.29, se 0.67) | −103 (sd 180, se 37); lower in 16, higher in 8 | −0.46 (se 0.45) | 3 / 94 |
| foundry | −2.67 s (sd 4.15, se 0.85) | −83 (sd 131, se 27); lower in 18, higher in 6 | −0.25 (se 0.34) | 16 / 93 |

Target killed 24/24 in every cell (median 7.35 vs 9.65 s, 7.9 vs 9.8 s). Seeds 1–8 alone were −1.5 / −1.7 s and
−76 / −70 HP at 1.3–1.6 se; 24 put time and loss at 2.8–3.7 se, all one way. **Verdict: ship it** — the mechanism
(no orbit: reversals ~25× fewer) and every measure agree. **Also tried:** his recording rebuilt (`--case=recording`,
foundry, census tick 1824, seed 3): pursuit on keeps his nearest crew within 72 m of the target at worst vs 113 m
off, but the lab's Syndicate holds and fights instead of retreating (no score/posture history), so all seven of his
die in both arms: the chase shows, his game's retreat does not. **Not built:** a full Syndicate squad of four simply
out-ranges ten Rat Rods (all ten dead in 13 s for no damage, yard_open, seed 3, laptop): balance (C12.6), recorded
for the orchestrator, not mine.

**Arrive series (lesson 261)** (`make squad-arrive-series ARRIVE_ARM_FLAG=pursuit`, laptop, `9f392432`, five squads ×
yard, terminus, pit, sumps, cut × seeds 1–4): **100 of 100 arrive in both arms, the two tables identical cell for cell**
(as predicted: his attack-move names no target, so no pursuit can start).

**Pre-registered (before its check):** the thirteen lines and determinism UNMOVED expected: the match runner runs no
elements, so ElementPlan/Drills/Element paths cannot run there; the one P2 path outside elements is
`TankBrain.chases` (a brain under an `attack`/named `attack_move` order on a contact opening the range beyond its
band); if any line moves, that is its cause, and the line is adopted and named. Local, laptop, the P2 tree:
`make test FILTER="test_tactics|test_ai_|test_nav"` 429 passed 0 failed.
