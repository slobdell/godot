# Stream: brains (the sitting duck; the commander at ten squads; the tick at 50 a side)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 22 direction* (his words and
> the reading of his recording), `_agents/doctrine.md` (*Round 19 (brains)* the hold posture, *Round 21 (brains)*),
> `_agents/workstreams.md` *Round 22* (C22.2, C22.4, C22.6), and your round-21 final report
> (`streams/archive/round21/brains.md` Status: the hold fall-back's series and why it lost; stretch (b)'s pricing
> note; the known issues). You own `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`,
> `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you declare. Orders' probes are read-only instruments.

## The lead's direction (2026-10-07)

> *"in my last play I had one of those laser vehicles from the condemned. It was shooting at a Syndicate vehicle at
> range, and the SYndicate vehicle just sat there and took it until it died. THat clearly looks like dumb CPU player"*

Standing: *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as smart"*
(2026-10-04); a direct order of his still wins (lesson 264, C22.6). And: *"yeah double it sounds good"*: ten squads of
five a side, 50 vehicles (army's CP1; `Formations.MAX_MEMBERS` stays 5).

## Where things stand (read at `5beb038f`; the orchestrator's reading of his recording, verify it)

- **His recording `build/recordings/2026-10-07T12-58-28.jsonl`** (foundry, seed 73429, his Condemned: 3 tanks, 2 IFVs,
  2 Lancers (laser), 2 scouts, artillery v the Syndicate: 2 Limousine Gunships, a Railgun Platform, a Skimmer, a
  Missile Ring; main `5beb038f`, CPU leaders ON). `Rust_Hunters_2` (Limousine Gunship, pulse cannon) stood at
  (−6.7, 51.7) under `hold` from its element (`src element`, phase `arrived`) from tick 1096 until it died at 1771
  (22.5 s), never moving; 36 hits of 9–29 damage (laser chip) took shield 200 / hp 240 to 0. `Rust_Eyes_1` (Skimmer)
  died the same way (hold at (−33.7, 35.8), ticks 976–1113). The hit records carry no shooter; the Lancers' positions
  are in the census every 30 ticks: measure the range and whether the Lancer was in the gunship's sight.
- **The mechanism to verify:** the hold posture (round 19's B2) keeps the element on its post; `ElementSituation`
  already computes `taking_fire` per crew and for the element, and `threat_from` reads it, but no drill or plan step
  answers *fire I cannot return* (the shooter beyond my effective range, or unseen). Round 21's hold fall-back (a losing
  TRADE after 6 thinks in contact) was a different trigger and measured against (−0.6 to −1.1 alive); do not revive
  it unchanged. `Drills.CONTACT_DRILLS` has `break_contact` (outgunned) and `react_to_contact` (close with a visible
  enemy); the crew's own `TankBrain` may also hold a position it was given.
- Ten squads a side: `ElementCommander`, `ArmyLayout`, `Posture`, the ambush search and the tick cost were built and
  measured at ≤ 5 elements a side (round 19: +5.1 ms a tick on his laptop at 25 v 25). Stretch (b) from round 21: 56 of
  192 uncached `closest_point` calls a tick in slot grounding (transit stations move every update so the memo misses).
- Round 21's observation for him (`roadmap.md` *Round 22 candidates* 2): four Syndicate out-range ten Rat Rods for no
  damage; a lone spotter kites five Rat Rods at 20–30 m. His balance call; you measure, you do not change `Units.cost`.

## Backlog (in order)

**B1. The sitting duck (DECLARED, alone; C22.6).** A crew (either side) being hit by fire it cannot return — the
shooter beyond the crew's effective range, or not in its sight, for more than a short grace (say 2 s of hits) — does
not stay on its post. Design the answer as a drill or a plan step with three outcomes, chosen by the situation:
(a) CLOSE to its own effective range when the shooter is seen and the element is not outgunned; (b) get OUT of the line
of fire (a covered spot within a bound, `CoveredRoute`/cover points) when cover is near; (c) FALL BACK out of the
shooter's range when neither. Under HIS explicit `hold` the crew holds (his order wins) but the element reports it in
the HUD readout ("under fire from beyond range: holding on your order"); under the ELEMENT's hold (the leader's
posture) the element acts. Scenario first, from his recording: a Limousine Gunship (pulse cannon) in a hold at
(−6.7, 51.7) on foundry, a Condemned Lancer at the Lancer's census position firing; assert the gunship moves within
3 s of the first hit, ends either within its range of the Lancer or out of the Lancer's range or behind cover, and
loses less than the recording's 440 shield+hp; both arms (his crew under his `hold`: holds and the readout says so).
Then the paired series (hold stage, parade and foundry, 8 then 24 seeds; alive, loss, score margin), and the arrive
series if any movement plan changed. Ship on mechanism + measures the same way as M3/P2; if a measure goes against,
say which outcome (a/b/c) did it and bound it.

**B2. The commander at ten squads a side.** `ArmyLayout`, `Posture`, the ambush search, element formation and the
form-up at 10 elements: a CPU-v-CPU match at 50 v 50 (the garage's opponent at 2000 for each faction after army's CP1)
runs to a result with no error lines, elements ≤ 10, no element over 5, the layout inside the arena; a scenario on
parade and foundry; what the commander does differently with ten (nothing by design, or say what).

**B3. The tick at 50 a side (C22.4; DECLARED if not equal-answer).** `make sim-profile` and `ai-ab-match` on builder0 at
25 v 25 and 50 v 50 with leaders on: µs a tick per table, the slot-grounding memo cut (round 21's stretch b) priced by
A/B, any other equal-answer cut; the ratio 50/25 is the number perf and the orchestrator need the same day. Hand the
orchestrator the table; the laptop's number is perf's / the orchestrator's (C22.4).

**B4. The range gap, measured for him.** yard_open and parade, 4 Syndicate (one full squad) v 10 Rat Rods and 1
spotter v 5 Rat Rods, 8 seeds each, both doctrines' default behaviour, before and after B1 (does B1 change it? the Rat
Rods are the ones under fire they cannot return): a table with his words beside it; no price moves.

**B5. Doctrine.** `doctrine.md` *Round 22 (brains)*: B1's rule in one sentence and the three outcomes; B3's numbers.

**Stretch (a).** P2's known limit: a target that turns while unseen is followed straight on (a turn memory or a wider
cone), only if cheap and measured on the pursuit series. **Stretch (b).** The yard's containers make a chasing crew
back round once (routing).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism as pre-registered.
- B1's scenario and series; `make squad-arrive-series` both arms for any movement change (lesson 261).
- Play it: `make garage` → the Condemned → a suggested army with Lancers → FIGHT v the Syndicate: a Syndicate vehicle
  under your laser at range moves (closes, hides or backs off) instead of dying in place. Then as the Syndicate v the
  Condemned: your own gunship under his hold order holds and the readout says why. Record and read your own recording.
- Screenshots at desktop and phone aspect of B1 mid-reaction; look at them.
- Every number: commit, machine, workload, sample size (C16.3).

## Don't touch

`game/control/**`, `game/ui/**` (orders' and perf's; the probes are read-only for you) · `game/garage/**`,
`game/units/**` (army; `Units.cost` is his) · `game/theme/**` (perf) · `game/match/**`, `game/modes/**` (nobody; a
signal or constant is a request) · `arenas/**`, `game/arena/**` · `mk/core.mk`, `tests/baselines/**` except declared lines.

## Waiting on the lead

- Nothing blocks you. The range gap (B4) is measured for his decision, not changed.

## Status

_Updated 2026-10-07 ~15:00 PDT (round 22, brains worker). In progress; detail per item below._

### Plan (in order; B1 and any non-equal-answer B3 cut each one commit, merged alone)

1. **B1** the sitting duck: scenario from his recording first (`tests/tactics/duck_stage.gd`), the rule
   (`UnansweredFire`), the recording stage's series, the paired hold-stage series, shots. **Built, `f0e83a7f`.**
2. **B3** moved up beside B1 (the orchestrator, 14:00: his Sumps match at 4-10 fps): a fork of this worker profiles
   from a scratch clone (his Sumps seed 5988 first; per element v per vehicle; the slot-grounding memo cut by A/B).
3. **B2** ten squads a side: `make army-series` (instrument `6e1ad82f`).
4. **B4** the range gap: `make gap-series` (instrument `6e1ad82f`), before/after B1.
5. **B5** doctrine.md; then stretch (a), (b).

### Baseline

`32748a0c` (the launch): builder0, `>> remote: make check exited 0`, 2211 passed 0 failed, thirteen lines unmoved;
21 passed + 2 NOT JUDGED (perf-judge and the brains' CPU budget: builder0 busy, three other streams' checks).

### B1 — a crew under fire it cannot return leaves its post (DECLARED, C22.6; `f0e83a7f`)

**His recording read (verified):** `Rust_Hunters_2` was on an **ambush** task (recorded tick 841, `from` (-2.25, 51.8),
kill zone (-25.5, 34.7)); once hit it SPRANG (`spring_ambush`: "the positions do not change when it is sprung", and
nothing times an ambush out), so it held. The Lancers (`Green_Charlie_1` 85-89 m, `Green_Bravo_3` 85-104 m) were
beyond its pulse cannon (70 m, effective 55) and inside its sight (95 m): it knew where the fire came from and had no
rule for it. A plain CPU `hold` does not reproduce it (its react-to-contact drill moves it); the ambush does.

**The rule** (`game/tactics/unanswered_fire.gd`, a plan step after the drills in `ElementPlan.build`; memory in
`Element.ducks`): a crew on its post (a hold, or within 8 m of its order's point) hit for 2 s with no SEEN enemy inside
its own effective range leaves the post by the first of: **(a) close** (the probable shooter is seen, the element's
strength >= what it knows of, the drive to its own band <= 45 m: attack it); **(b) cover** (a spot within 25 m that
hides the whole hull from the shooter, aimed 3 m deeper); **(c) fall back** (straight away until 10 m outside the
shooter's reach, 12-45 m). Cover that still gets it hit after 5 s escalates to a fall-back (twice at most). It returns
to its post after 12 s without a hit once nothing it knows of reaches the post. **Under HIS posture tasks (hold,
ambush, support by fire, screen) his crew holds** and the element's readout says *"under fire from beyond range:
holding on your order"*; under his move (arrived: the element's halt) or the computer's posture, it acts. Switch
`UnansweredFire.ENABLED` (`--duck=off`).

**Decision:** his four posture verbs, not only `hold`, count as his order: each is him choosing where the crew fights
from (C22.6: "under his explicit order a crew does what he said"); one constant (`PLAYER_POSTS`) if he wants it narrower.

**His recording's stage** (`make duck-stage-series`, builder0, `f0e83a7f`, seeds 1-4 per cell, 30 s):

| side | Lancers | duck | n | moved | react s | outcome | alive | lost (of 440) | Lancers lost |
|---|---|---|---|---|---|---|---|---|---|
| CPU | 1 | on | 4 | 4 | 2.6 | close 4 | 4 | 137 | 320 (dead) |
| CPU | 1 | off | 4 | 0 | - | - | 0 | 440 | 0 |
| CPU | 2 | on | 4 | 4 | 3.4 | cover 4 | 4 | 191 | 0 |
| CPU | 2 | off | 4 | 0 | - | - | 0 | 440 | 0 |
| CPU | 3 | on | 4 | 0 | - | cover 4 (decided, dead first) | 0 | 440 | 0 |
| CPU | 3 | off | 4 | 0 | - | - | 0 | 440 | 0 |
| his | 1-3 | on / off | 4 each | 0 | - | held (readout says so) | 0 | 440 | 0 |

Off = his recording exactly (never moves, dies at 27.7 s with seed 1). **The bound:** three Lancers take 440 in ~3 s,
inside the 2 s grace plus the drive; outcome (b) is decided but too late. A shorter grace would make one stray hit move
a crew; left as is.

**The paired series** (`make duck-series`, two stages: `law` = round 19's, nobody out-ranged, must be unchanged;
`lancers` = his recording's matchup): running on builder0 (8 seeds), then 24.

### Questions for the lead (in his terms; none blocking)

- (B4, when measured) the range gap: his decision, not changed.

### Requests to other streams

- None yet.

### Known issues

- B1 against three or more long-range guns at once: the crew dies inside the grace (measured above).
- A crew in cover returns to its post 12 s after the last hit once its team has lost sight of the shooter, and is shot
  again: a peek every ~15 s, each costing ~2 s of fire (shield regenerates in between). Measured in the 2-Lancer stage.
