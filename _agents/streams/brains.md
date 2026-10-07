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

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
