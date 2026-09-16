# Stream: ai (execution, cost at scale, the tactics harness)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: doctrine, suppression, army size, offline tactics discovery), [../workstreams.md](../workstreams.md)
> (you consume doctrine's L1 and combat's L2/L3), [../unit_ai.md](../unit_ai.md) (your architecture and ladder).
> You own `game/ai/` except `doctrine.gd`, `game/agent/`, `tools/agent.py`, `tools/ai_ladder.py`, `mk/ai.mk`,
> `tests/ai_scenarios/`, and `_agents/{tank_brain,squad_ai_design,unit_ai}.md`.
> Round 3: [archive/round3/ai.md](archive/round3/ai.md).

## The lead's direction (2026-09-16)

> *"I also still need to emphasize that the intelligence of all units is crucial here, and another framework we haven't
> explored yet is to create a local, offline simulation of our game that we could plug into an AI brain (i.e. AI agents
> play against each other somehow in the game, or have more explicit control of individual unit decisions, and possibly
> even in slow motion as necessary) not for the purpose of live gameplay, but for the purpose of discovering novel
> tactics and decision making, and somehow formalizing those discoveries into deterministic heuristics. For example, it
> would seem totally reasonable for The Gang to have a tactic of encircling their opponent like a pack of hyenas … or
> just circling when facing off with the enemy in order to distribute damage across the squad."*
>
> Decided with the lead: **doctrine from the literature comes first** (the doctrine stream), the harness **measures**
> it, and the LLM-plays-the-game layer is a later discovery experiment whose findings are distilled into deterministic
> rules before they ship. Nothing runs a model during live play.

## Where things stand (round 3)

Brains strafe, dodge shells (`IncomingFire`), hunt weak spots, use cover, and obey orders within 1 tick; champion `x4`;
`CpuCommander` v6 is the default. **CPU cost is the wall: ~7–9 ms per tick at 50 brains** (round 2's measurement,
round 3 kept it about the same), and the lead wants ~30 a side (60+ units in a match, more for gangs).

## Backlog (in order)

**X1. Execute doctrine well (doctrine's L1).** Brains keep doing the micro; the element leader decides formation,
technique and drill. Make the seam clean: a brain in a formation slot holds its slot and facing while fighting, a brain
told to bound moves fast and stops on the leader's call, a brain in support-by-fire keeps firing while the other element
moves. Scenarios first. Build against L1's contract with a stub until CP1 lands.

**X2. The cost of 30 a side.** Profile and cut, in this order: one shared per-team knowledge pass instead of per-unit
scans, thinking less often when nothing is close (extend think LOD), cheaper target scoring (typed arrays, precomputed
matchup tables), and order execution at a lower rate for units that aren't firing. **Target: ≤ 4 ms per tick at 60
units**, measured on builder0 with `make ai-perf`, without losing the ladder's champion behavior.

**X3. Suppression-aware behavior (combat's L2).** Read `threat_field` and `is_beaten_zone`: don't cross a wall of
bullets, prefer covered approaches, break contact when pinned, and **apply** suppression on purpose (a machine gun
firing at a crossing to stop it, even without kills). Scenarios measure that units stop walking into beaten zones and
that suppressing enables a flank.

**X4. The tactics harness.** `make tactics-ladder`: seeded, headless matches that pit doctrine variants and brain
variants against each other across matchups, arenas and factions, with an ELO table and a report of which drill wins
where (`_agents/unit_ai.md`). This is how doctrine gets validated and tuned, and how a change proves itself before it
becomes default.

**X5. Faction behavior (with doctrine's X6 and combat's L3).** Make the factions' automated tactics read differently in
play: gang packs encircling and circling, the Law bounding behind suppression, the Syndicate kiting at range. You own
how a unit executes; doctrine owns which tactic is chosen.

**X6. Groundwork for offline discovery.** Enough to run the experiment later, no live-play dependency: a match runner
mode where an external process (the existing agent bridge) sees a compact state and issues element tasks at a slow
cadence, optional slow motion, and a log of `(state, decision, outcome)` per match. Write the distillation plan in
`_agents/unit_ai.md`: how a logged policy becomes a decision tree or scoring weights, and how it gets validated by X4
before shipping. **Do not** wire an LLM into gameplay.

- **Stretch:** run the discovery experiment once with a local script or the agent bridge and report what it found;
  a difficulty knob tied to reaction time and suppression sensitivity.

## How to verify

`make remote T=check`; your scenarios; `make ai-perf` numbers before and after X2; the tactics ladder's table; watched
matches whose screenshots you look at, with a spectator's description of what changed. The sim baseline changes on
purpose (record it on builder0).

## Don't touch

Doctrine data, elements and drills (doctrine), weapons, suppression and rosters (combat), the camera and HUD (control),
audio (audio).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
