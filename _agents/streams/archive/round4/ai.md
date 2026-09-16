# Stream: ai (execution, cost at scale, the tactics harness)

> **Archived 2026-09-16:** round 4 is merged into `main`. This brief and its Status are the record of what the stream did;
> the current round is in [../../../workstreams.md](../../../workstreams.md).

> Read [../orchestration.md](../../../orchestration.md) (the worker contract), [../game_design.md](../../../game_design.md)
> (*Round 4 direction*: doctrine, suppression, army size, offline tactics discovery), [../workstreams.md](../../../workstreams.md)
> (you consume doctrine's L1 and combat's L2/L3), [../unit_ai.md](../../../unit_ai.md) (your architecture and ladder).
> You own `game/ai/` except `doctrine.gd`, `game/agent/`, `tools/agent.py`, `tools/ai_ladder.py`, `mk/ai.mk`,
> `tests/ai_scenarios/`, and `_agents/{tank_brain,squad_ai_design,unit_ai}.md`.
> Round 3: [archive/round3/ai.md](../round3/ai.md).

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

_Round 4, ai stream. Updated 2026-09-16. Branch `stream/ai`; `main` merged at 7fd1f1e (CP1 + CP2)._

### Where things are

| # | Item | State |
|---|---|---|
| X1 | Execute doctrine (L1) | **done** — `224fd8c`, re-aimed at the real `Elements` in `7fd1f1e` |
| X2 | The cost of 30 a side | **partly done** — `d2ff1c0`, `48cbff3`. New champion **x4t9**; the 4 ms target at 60 units is **not met**. See below |
| X3 | Suppression-aware (L2) | **done** — `c3a9df3` |
| X4 | The tactics harness | **not started** — the one other streams are waiting on |
| X5 | Faction behavior | **not started** |
| X6 | Offline discovery groundwork | **not started** |

### X1 — brains execute their element's doctrine

`ElementFeed` is the mirror of `OrderFeed` for L1: it normalizes `element.state()` into the few things a brain
executes — my slot, my sector of fire, and whether I am the half that moves or the half that shoots — and degrades to
"behave as before" when doctrine publishes less. Built against a stub before CP1; when CP1 landed the shapes were
different (slots are bare positions, sectors are DEGREES off the element heading, and there is no per-unit role) and
only the adapter changed. A scenario runs doctrine's real `Elements` end to end so the next shape change fails there.

| Measured on builder0 (`tests/ai_scenarios/scenario_elements.gd`) | Result |
|---|---|
| Fights from its slot: worst drift, same 3 v 2 attack | **13.7 m in an element vs 34.9 m without one**, 12 vs 11 shots |
| Covers its sector: a halted pair, ticks engaged and on whom | 960 each; the flank tank on the enemy **10 m farther away**, because that one was in its sector |
| Bounds and halts on the call | rushed at **8.0 m/s of a 9.0 m/s top speed** (overwatch half 0.0), stopped **1 tick** after the halt, no new order needed |
| Base of fire while the assault crosses its front | shots in both halves of 24 s, **0** through a friendly |
| Against doctrine's real `Elements` | 4 of 4 members got a world slot and a sector of fire |

### X3 — reading a wall of bullets, and making one

Suppression existed after CP2 but changed nothing: combat measured mean suppression 0.03 and units pinned 0.7% of the
time because nothing suppressed on purpose, and doctrine measured bounding overwatch still *costing* survival because
covering fire that can't suppress is a stopped vehicle. Now: a `suppress` weapon order that fires at ground, a
SUPPRESS brain option that chooses to, movement scored against the field in the move executor (so orders, bounds and
drills are all covered), and pinned crews read as worse *shooters* — worth flanking, not avoiding.

| Measured on builder0, each against `x4ns` (the champion with L2 taken away) on the same seed | Result |
|---|---|
| Across a swept lane | **10 ticks in the beaten zone vs 33**, peak suppression 0.33 vs 0.36, still arrives |
| Two machine guns pinning a tank while a third goes round it | suppression **1.00 vs 0.40**; the target landed **2 of 5 shells vs 5 of 5**; the flanker dealt **1311 vs 279** |

**It broke once on merged main, and both causes were mine** (`b98630f`). Combat's suppression rework made the field
denser and burstier (peak 1.27 where it was 1.15), which exposed them:
- a unit dropped its detour the instant `is_beaten_zone` dipped between two bursts, and that counted as "no way
  round", so it then pushed straight through for four seconds. A beaten zone pulses by construction (≈1 s half-life,
  guns fire in bursts), so avoidance is now *entered* on the hard threshold and *kept* while the route still carries
  40% of it on average (`threat_along`); only spending too long ends the attempt.
- `FIRE_CHECK_TICKS = 6`, chosen during X2 to save ~370 µs, quietly cost most of the behaviour. It is not only a cost
  knob — it sets how many chances a unit gets to notice a wall while there is still room to go round. Measured
  (ticks in the beaten zone against a control's 33, with `make ai-perf UNITS=60` alongside): **every tick 21 / 4740 µs,
  every 3 ticks 10 / 4231 µs, every 6 ticks 28**. Three is both the best behaviour and cheaper than one.
- Fixing it exposed a third: a tank running for cover runs *through* the beaten zone on purpose, and avoidance was
  steering it sideways, so it stopped hiding at all (`ai_hurt_to_cover` first hidden −1, where it had been 195 ticks).
  A move that IS the escape now carries `to_safety` and is driven as given. Back to 201 ticks, hidden for 154.

Three things had to be true before avoidance worked at all, each measured: look ~34 m ahead (the next navmesh waypoint is a
few metres — by then you are in it); the way round is a step **sideways**, not a shallower line to the same place; and
the step must be committed to, or the unit wobbles along the edge of the fire (19 m off the line and it never
arrived). A cooldown then had to be added so a wall across the whole frontage doesn't stop a unit forever — orders
win in the end.

### X2 — the cost of 30 a side: honest numbers, target not met

`make ai-perf UNITS=n` (default 60, the round-4 target; `UNITS=50` repeats the round-2/3 numbers), `DETAIL=1` for the
finer laps. All on builder0, two interleaved runs each; the machine swings ±30% with other worktrees' load.

| When | x4 (champion) | x4t9 (thinks every 9 ticks in a fight) |
|---|---|---|
| Round 3, at 50 units | ~4700 | |
| After X2's cuts, at 50 units | **3670** | |
| After X2's cuts, at 60 units | 4529 / 4516 | 3994 / 4070 |
| After CP2 + X3, at 60 units | 5501 / 5389 | 5058 / 4501 |
| After caching the L2 source and staggering the route check | 5327 | 4293 |
| Final, champion = x4t9, two runs | | **6179 / 5403** (and 4488 at 50 units) |

The last row is higher than the one above it and that is not a regression being hidden: adopting x4t9, holding the
suppression aim point and finishing orders every tick all changed *what happens* in the scenario, so it is a
different battle (160k line-of-sight queries against 150k). Two back-to-back runs of identical code came out 6179 and
5403, a 14% spread, which is the shared machine. **Treat ~5.4–6.2 ms at 60 units as where this stands.**

What was cut, in the brief's order:What was cut, in the brief's order: a shared per-team contact pass (`AiTickCache.contact_prototypes`, built once per
intel refresh instead of 30 times over); a **graded** think LOD (6 ticks while either gun can reach, 12 while an enemy
is within 130 m but nothing is in reach, 18 otherwise, re-rated every intel refresh so coming into range is never
noticed late); no re-picking a target or re-testing its sight line while the gun is reloading; local avoidance over
the tick's shared ally table with a squared-distance reject; and the remaining path distance no longer walked twice
per tick.

**Measured and rejected:** answering "can I see it" with the memoized 2D cover map instead of a physics ray made
picking a target *slower* at 60 units (650 µs vs 573) — with a memo that big a hit costs about what the ray saves.

**Honest reading: the target is not met, and the gap grew rather than closed.** Every micro-cut bought about 3%; the
one structural lever is how often a brain thinks, and that is now spent. CP2's suppression and X3's reading of it
added roughly 900 µs on top of a 4.5 ms starting point. At equal behaviour the work is real — 50 units cost 3670 µs
where round 3 paid ~4700 — but the round-4 target of 4 ms at 60 units was not reached.

Where the time goes at 60 units (µs/tick, `DETAIL=1`, before the last two cuts): `move` 1180 (`move.avoid` 767),
`situation` 1347 (`s.cover` 532, `s.contacts` 382), `weapon` 837 (`weapon.scan` 510), `decide` 516, `act` 353.
The next levers, in the order I would take them:
1. **`s.cover`** is the largest single part and the least gated: `_cover_fire_spot` runs a tactical query for every
   brain with a target in reach, including ones committed to ENGAGE that will never pick COVER_FIRE. Gate it the way
   the design already says (COVER_FIRE is for slow guns and cautious crews) and it should mostly disappear.
2. **`weapon.scan`**: the reload gate helped cannons; fast-firing guns still ray-test their pick every tick.
3. **`decide`**: typed arrays and a precomputed matchup table, the one item of the brief's list not attempted.
4. **Measure a faction army too.** The scenario is 60 identical cannon tanks in one brawl — the worst case, and
   harsher than the mixed roster the lead actually wants. Combat's `make remote T="scale-bench TIME=40"` now measures
   the simulation the same way; the two should be read together. Report both, hold the headline to the all-tank case.

**Champion changed: `x4t9`** (the same brain thinking every 9 ticks in a fight instead of 6). It won all four armies
post-CP2 — individuals 13-11, armor 13-11, balanced 13-11, swarm 14-10, pooled **53-43** over 96 matches. The same
comparison *before* suppression landed was 48-48 with a clear loss on the all-armor army (9-15, 85% accuracy against
88%), which is why it was measured twice rather than adopted the first time it looked cheaper.

Two things fell out of adopting it, both improvements in their own right: orders now **finish every tick** instead of
on a think tick (a target dying could sit unreported for 150 ms; control's 3-tick test caught it), and SUPPRESS
**holds its aim point** rather than tracking — combat measured that a round stamps the cells it flew through, so fire
held on a place piles into one cell while fire that chases a unit spreads thin. Measured: **138 rounds and 0.81
density held, against 17 rounds and 0.00 tracking** (a gun told to track also stops firing whenever the target is out
of reach or sight; one told to hose a place does not).

### Decisions taken where the brief left a choice

- **X1 rides on K1 orders as the transport** (L1 says elements issue per-unit orders through `Orders`), so the only
  new seam is the element's read-only state. One command path into the brain, nothing to unwind.
- **The X3 control is a brain variant (`x4ns`), not a changed world**, so every suppression measurement compares two
  brains in the same fight rather than two different fights.
- **Suppression is read live for contacts we can see** and left at 0 for remembered ones: a crew keeping its head down
  is visible behavior. (Requested as an intel field from combat; not blocking.)

### Questions for the lead

(none)

### Requests to other streams

1. **doctrine** — `Element.state()` publishes no per-unit role and no `heading`. `ElementFeed` derives the role from
   the movement technique or drill plus the verb of the K1 order the leader issued, and reads `heading` off the
   element object, which both work but are guesses about intent. Publishing `roles: {unit: "bound"|"overwatch"|
   "base_of_fire"|"maneuver"}` and `heading` in `state()` would make a bounding unit's "move fast, halt on the call"
   exact instead of inferred. Not blocking: `tests/test_ai_elements.gd` pins both paths.
2. **combat** — `Match.intel` entries don't carry `suppression`, so ai reads it off the live Tank in its own shared
   per-team pass. An intel field next to `health`/`shield` would be cleaner. Also: `is_beaten_zone(team, from, to)`
   with `from == to` reads as nothing (peak along a zero-length segment); "am I standing in it" needs
   `threat_field(team).at(point)`. Both reported with numbers.
3. **orchestrator** — `tests/run_tests.gd` (shared) appears to skip a test file that doesn't compile rather than
   failing: `tests/test_ai_elements.gd` used 2-argument `assert_eq` throughout, never parsed, and a full `make check`
   reported 749 passed without it. Fixed the same hole in `tests/ai_scenarios/run_scenarios.gd` (ai's own).

### Known issues

- **X2's 4 ms target is not met**: ~5.4–6.2 ms at 60 units (above), with the next levers listed in order.
- **X4, X5 and X6 are not started.** X4 (the tactics harness) is the one other streams are waiting on: doctrine wants
  to know which drill wins where, and combat wants faction-vs-faction near 50%. `make ai-ladder` already plays brain
  variants against each other across armies and prints ELO plus head-to-head, and `tools/ai_ladder.py` takes any
  doctrine file, so X4 is mostly a matter of sweeping *doctrine* variants and arenas alongside brain variants and
  reporting per-drill rather than per-variant — the machinery is there, the sweep and the report are not.
- **SUPPRESS can't be reached in a duel.** Seen in `build/ai-shots/scout_runs_16s.png`: a machine-gun scout against a
  durable tank reads `ENGAGE Rust_Tank_1 - breaking away` and keeps making attack runs at a hull its rounds barely
  mark — the exact case the brief describes ("a machine gun firing at a crossing to stop it, even without kills").
  The reason is a gate, not a weight: SUPPRESS's "killing this is slow going" test reads `Matchups.kill_rate`, and the
  champion runs with `matchups: false`, so that clause is always false and only an already-pinned target or a squad
  focus/flank target can trigger it. That is why SUPPRESS shows 11% of the time on the five-unit `individuals` army
  (squad tactics name a focus) and never in a 1 v 1. The fix is a matchup-free proxy for "my rounds don't hurt this"
  — the weapon's penetration against the target's armour, which `Armor`/`Units` already expose. Left undone
  deliberately: it changes what the champion does, so it wants a ladder run behind it rather than a late edit.
- **A pinned enemy doesn't actually pull a unit out of cover.** The 1.5x flank bonus on a pinned target exists, but
  the printed option counts in `scenario_suppression` show COVER_FIRE winning the choice anyway (1435 ticks of 1440).
  Suppress-and-flank therefore pays off as "the teammate works on it unmolested" rather than "the teammate goes
  round it". Whether the bonus should out-score peeking from cover is a tuning question the ladder should settle.
- **Two test runners silently pass files that don't compile** (see requests, 3). Fixed in ai's own scenario runner.
- The `x4mw` variant (matchup targets and engine decks) is still opt-in and still blocked on the same question from
  round 3: what a scout's counter is.

### What to playtest

- `make skirmish` — watch a machine-gun unit: it should put fire on a tank it can't hurt while something else goes
  round, and the nameplate reads "Keeping their heads down".
- `make ai-shots` / `make remote T=ai-shots` — the driving trails. `scout_runs_16s.png` shows a clean attack-run S-curve
  ("ENGAGE … - breaking away"), so round 3's fixed-gun behaviour survives the new think cadence; it is also the
  evidence for the SUPPRESS gate above.
- `make remote T="ai-scenarios FILTER=scenario_elements"` and `FILTER=scenario_suppression` for the measurements above.

### Merge notes

- **`make remote T=check` exits 0 on the last commit** (821 passed, sim baseline matched), on top of merged main.
- The sim baseline moved once more, on purpose, for the avoidance fix: **`glibc-2.43 d4bd86eee0f96c54`**, recorded
  twice on builder0.
- A narrow relaxation in audio's K5 validator twins (`game/announcer/announcer_events.gd`, `tools/announcer/events.py`):
  `MAY_BE_DEAD = ("shooter", "killer")`, because a shell outlives the crew that fired it and `announcer-record-smoke`
  was rejecting a legitimate kill. Diagnosed and reported to audio before touching it; they made the same change on
  `stream/audio`, so whichever merges first wins and the other is a no-op. Tests on the Python side now say a kill by
  a dead shooter is accepted while a unit dying twice and a wreck being spotted are still rejected.
- One additive line in control's `game/ui/command_icons.gd`: `"SUPPRESS": "Keeping their heads down"`. Its own comment
  says unknown options render capitalized so ai can add them freely, but `test_command_icons` requires an entry.
- The **sim baseline moved twice on purpose** and is now `glibc-2.43 10e95d54f5dd3efe` (recorded twice on builder0,
  identical both times): first from X2's graded think LOD and the reload gating, then from X3's decisions.
- `mk/ai.mk`: `ai-perf` gained `UNITS` and `DETAIL`.
