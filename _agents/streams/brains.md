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

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
