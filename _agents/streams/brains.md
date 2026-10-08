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

_Updated 2026-10-07 ~17:00 PDT (round 22, brains worker). In progress; detail per item below._

### Plan (in order; B1 and any non-equal-answer B3 cut each one commit, merged alone)

1. **B1** the sitting duck: scenario from his recording first (`tests/tactics/duck_stage.gd`), the rule
   (`UnansweredFire`), the recording stage's series, the paired hold-stage series, shots. **Built; final arm
   `5d910d80`; its check and 24-seed series running.**
2. **B3** moved up (the orchestrator, 14:00 and 16:00: his Sumps match at 4-10 fps is the per-vehicle tick): a fork of
   this worker profiles and cuts from scratch clones (Movement / Pathing); the stride priced as a game-wide setting
   for the orchestrator's question to him (C17.4: his choice). See *B3* below.
3. **B2** ten squads a side: `make army-series` (CPU v CPU), the layout at ten (`layout_probe`, a test). The
   orchestrator ruled no ArmyLayout change (orders' request). **Layout done `dea90944`; the series running.**
4. **B4** the range gap: `make gap-series`. **Measured at `7061fe8d`; the final-arm re-run queued.**
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

**Its check:** `f0e83a7f` green (builder0, `>> remote: make check exited 0`, 23 targets ALL JUDGED, 2220 passed 0
failed, thirteen lines unmoved). **The final arm `5d910d80` is green** (builder0, `>> remote: make check exited 0`,
23 targets ALL JUDGED, 2221 passed 0 failed, thirteen lines unmoved, determinism `762a0576f944f5b7`; the match runner
forms no elements, so the declared change moves no baseline line). **Merged alone to main as `e3fd375e`** (the orchestrator, with the foundry cost stated).

**The paired series** (`make duck-series`, round 19's hold stage, 8 paired seeds, on - off, builder0; two stages: `law`
= round 19's Law tanks, nobody out-ranged; `lancers` = his recording's matchup: his Lancers, a tank and an IFV v four
Syndicate holders without the railgun):

| commit (arm) | stage / map | crews that left a post (close/cover/fall back) | CPU alive | alive margin CPU - his | his loss | CPU points margin |
|---|---|---|---|---|---|---|
| `f0e83a7f` | law / parade, foundry | 0 / 0 | 0.00 | 0.00 | 0 | 0.00 (identical runs) |
| `f0e83a7f` (close = attack) | lancers / foundry | 13/0/0 | +0.75 (se 0.16) | +1.50 (se 0.27) | +240 (se 52) | **-15.6 (se 2.8)** |
| `f0e83a7f` | lancers / parade | 13/3/0 | +0.12 (se 0.30) | +0.25 (se 0.56) | +88 (se 102) | -0.6 (se 1.0) |
| `f9c49c0e` (close = attack-move) | lancers / foundry | 12/0/0 | +0.75 (se 0.16) | +1.38 (se 0.26) | +222 (se 49) | **-10.5 (se 3.6)** |
| `f9c49c0e` | lancers / parade | 14/3/0 | +0.25 (se 0.25) | +0.38 (se 0.32) | +83 (se 51) | +0.9 (se 1.0) |
| `f21ad013` leash 20 m | lancers / foundry | 3/17/11 | +0.75 (se 0.16) | +1.38 (se 0.26) | +201 (se 58) | **-4.4 (se 1.7)** |
| `f21ad013` leash 20 m | lancers / parade | 5/12/13 | +0.62 (se 0.18) | +0.38 (se 0.32) | -77 (se 101) | +1.4 (se 1.1) |
| `f21ad013` leash 30 m | lancers / foundry | 4/15/7 | +0.75 | +1.38 | +211 | -4.4 (se 1.7) |

**Which outcome cost points, and the bound:** outcome (a), CLOSE. An attack on the shooter chased his Lancer off the
depot (-15.6 points a match on foundry); an attack-move to its own band cut that to -10.5; leashing the close to 20 m
(farther, the crew takes cover or falls back) to -4.4 (se 1.7) with the same +0.75 vehicles kept. What is left is (b)
and (c) taking crews off the zone for a while. The final arm (`5d910d80`: leash 20, grace 1.5 s, the shooter
remembered in cover) is in the 24-seed series now.

**The final arm's changes, and why:** the leash made his recording's gunship take COVER instead of closing (its band is
35 m away), a short drive that starts slowly: it moved 3.3 s after the first hit with a 2 s grace, so the grace is 1.5 s
(the Lancer's third pulse): 2.8-2.9 s (laptop, seeds 1-4, 1 and 2 Lancers, all alive, one Lancer: hull untouched; two:
110-135 lost). And a crew in cover went back to its post when its team lost sight of the shooter, a peek every ~15 s
into the same laser: it now stays while the shooter, where it was last seen, reaches its post (30 s at most).

**The final arm's 24-seed series** (`make duck-series DUCK_SEEDS=1..24`, builder0, `5d910d80`, paired, on - off):

| stage / map | crews off post (close/cover/fall back) | CPU alive | alive margin CPU - his | his loss | CPU points margin |
|---|---|---|---|---|---|
| law / parade | 3/0/2 | +0.17 (se 0.13) | +0.17 (se 0.13) | +10 (se 21) | 0.00 (se 0.12) |
| law / foundry | 0/0/2 | -0.04 (se 0.04) | -0.04 (se 0.04) | -1 (se 1) | -0.33 (se 0.43) |
| lancers / parade | 16/27/52 | **+0.62 (se 0.10)** | +0.54 (se 0.17) | -24 (se 42) | +0.21 (se 0.41) |
| lancers / foundry | 15/53/32 | **+1.00 (se 0.10)** | +1.38 (se 0.19) | +146 (se 36) | **-5.83 (se 1.90)** |

His recording's stage at `5d910d80` (4 seeds a cell): one Lancer: cover 4/4, moved 2.8 s after the first hit, alive,
nothing lasting lost; two: cover 4/4, alive, 44 lost; three: dies (440); his gunship under his order: holds, 24/24.
**Verdict:** for B1 everywhere except foundry's points, where the cost is REAL (-5.8, 3 se): with the close leashed it
is outcome (b) and (c), cover and fall-back taking crews off the depot. **The bound tried, `POST_LEASH_M` 15 m** (a
crew on a holding task's post leaves it by at most 15 m, else it holds; `c1002756`, builder0, 8 paired seeds), against
`5d910d80` on the same seeds 1-8: foundry points +1.9 (se 1.7), CPU alive -0.12 (se 0.23), his loss -61 (se 42);
parade identical but for points -0.25 (se 0.25). **Within the noise everywhere: shipped OFF** (`POST_LEASH_M = INF`;
`--duck-post-leash=` stays as the arm). **Recommendation: merge `5d910d80` as it is**, with the foundry cost stated:
the computer's holders keep a vehicle more and hurt his attack more (+146 HP, se 36), and score ~6 points less a
match there while they hide from fire they cannot return.

**Frames** (`make remote T=duck-shots`, builder0, `7061fe8d`, looked at; JPEGs in `references/round22/brains/`): at
8 s with the rule on, one Lancer: the gunship's trail runs west off its post toward the Lancer, `ENGAGE
Green_Charlie_1` (that arm closed; the final arm takes cover there); off: it sits on its post by the crate, `HOLD -
spring ambush`; two Lancers, phone aspect: tucked behind the crate.

### B2 — the commander at ten squads a side

- **The layout at ten** (`tests/tactics/layout_probe.gd`, `LayoutCheck`; laptop, `dea90944`): ten full squads of five
  a side (each faction's roster cycled), every rotation map + foundry x four factions x both teams = 104 deployments:
  **0 hull overlaps**; two rows of five, ~7-10 m apart box to box. In 21 of 104 two squads' FOOTPRINT boxes touch
  (mostly the gangs' 14 m War Rigs on terminus, crossing, docks, sumps): a measure, no two vehicles touch.
  `test_tactics_army_layout10` guards the worst corner (gangs on terminus, crossing, docks, foundry).
- **Orders' request** (rows that interleave his first Ctrl+A order): **ruled by the orchestrator: no ArmyLayout
  change** (two rows of five laid into ranks of three cross by construction whatever the gap; orders' untangle deals
  the first order; the thirteen lines stay put).
- **The commander** (`make army-series`: CPU v CPU, the garage opponent at 2000 CR and a FULL ten-of-five army, gangs v
  gangs / gangs v law / condemned v syndicate, parade + foundry): first run at `7061fe8d` died on its own recipe
  (pipefail on an empty error grep); fixed `463b87fd`: **builder0, 24 runs (opponent + full x parade, foundry x seeds
  1-2 x gangs:gangs, gangs:law, condemned:syndicate, 240 s), 0 error lines, 0 missing, 0 broken: every FULL army 10 v 10
  elements, none over 5, 0 vehicle-seconds outside the arena (deploy or after); 21 of 24 to a result (3 draws at 240 s,
  gangs v gangs and condemned v syndicate)**. The whole-match ms a tick it prints is wall time with the probe's
  sampling, builder0 loaded: full 50 v 50 19-74 ms, opponent 7-26 (B3's table is the measure). Rows in
  `references/round22/brains/army-series-463b87fd.jsonl`. The laptop smoke (`7061fe8d`, gangs v syndicate FULL,
  foundry, 15 s): 50 v 50, 10 elements a side, none over 5, nothing outside, no error lines. At 2000 CR the garage
  opponent buys only 18 Law / 11 Syndicate / ~30 gangs vehicles (its archetypes mix dearer vehicles), so ten squads
  is the gangs' army and the FULL case.
- **What the commander does differently with ten:** nothing by design (`ElementCommander` plans per element; the
  posture, the ambush search and the layout scale by element count); the cost is B3's.

### B3 — the tick at 50 a side (C22.4; the fork's numbers, scratch clones)

| workload (builder0, whole match, n = 1, load 4-13: +-30 %) | leaders off | CPU leaders only | both sides |
|---|---|---|---|
| his Sumps seed 5988, 41 vehicles (`deec4d9` = `32748a0c`) | 15.6 ms a tick | 16.7 | 19.6 |
| 25 v 25 | 16.6 | - | 21.9 |
| 50 v 50 | 41.7 | - | 62.7 |

Ratio 50/25: **2.5** leaders off, **2.9** leaders on both sides. 50 v 50 parts (builder0, Sumps, n = 1): controllers
49 ms a tick (16.5 at 25 v 25), elements 8.6 (3.6), match's own sections 4.1 (intel ~9 ms per refresh), tank 4.4. The
script profile is FLAT after `Pathing.closest_point` (14 %, ~104 calls a tick at 41 vehicles): decide 4.6 %,
build_situation 3.8, Tank._drive 3.1, the cover map 3.3, gunnery 1.5 ... (laptop, 53 sampled fight frames).
**Equal-answer cut 1 (the fork, `open_ground`):** a certificate that a point on level open navmesh grounds to itself
skips `closest_point` at slot grounding and movement's chord, k-turn, avoid and gate sites (each compares the distance
against a 0.3-1.5 m slack; the certificate bounds it at 0.15 m): nav.closest 76.8 -> 39.5 calls a tick, 1.95 -> 1.05
ms (laptop, his Sumps, 75 s, --brains-parts); builder0 `make sim-baseline` with it ON: 13 lines unmoved, in-run A/B
hashes equal. **Price on builder0 (his Sumps, CPU leaders): -0.3 % of the tick** (0.0 % in the fight, -9 % in the
form-up; the laptop's -4 % did not reproduce): that was the wrong arm. **With leaders on BOTH sides (his path: his
elements form when he tasks a squad): -1.8 % (his armies) and -2.1 % (50 v 50), fight -2.1 / -2.3 %**, state hashes
equal (builder0, in-run A/B, Sumps seed 5988). **Back as its own merge candidate `883a5e78`** (the orchestrator, on
the both-sides rows); its check queued after the stride pricing and B1's bound arm. Still 2 %, not the 4x. **The cap's real lever is the brains' rate** (equal-answer cuts buy 10-25 %, not the ~4x 50 a side
needs): `brain_stride 2` priced as a GAME-WIDE setting (both sides, every machine; the orchestrator's constraint),
for the orchestrator's question to him; OFF until he says (C17.4).

**The stride, priced game-wide** (both sides, every vehicle; measurement rows `b3s2` = the champion x18m + `brain_stride
2`, `b3fs2` = + `far_exec_stride 2`, `b3fi1` = + `far_idle_hz 1`; scratch `e204baa` = `32748a0c` + the rows; builder0;
OFF in the code, his choice, C17.4):

| in-run A/B (one match, arms alternate in 300-tick blocks; Sumps seed 5988; leaders both sides) | whole tick's scripts, fight | whole run | controller band |
|---|---|---|---|
| `b3s2`, 50 a side, Sumps | **-19.0 %** | -17.1 % | -25.4 % |
| `b3s2`, 50 a side, foundry | -2.9 % | -5.2 % | -13.0 % |
| `b3s2`, 25 a side, Sumps | -18.2 % | -14.0 % | -24.2 % |
| `b3s2`, 25 a side, foundry | -13.3 % | -15.2 % | -22.8 % |
| `b3fs2` (far stride), 50 / 25, Sumps | +10.4 % / +12.2 % (costs MORE) | | |

Whole matches (`make stride-table`, n = 1 each, different fights: +-30 %): 50 a side x18m -> b3s2: Sumps 34.9 -> 26.8 ms a
tick, foundry 52.7 -> 38.8; 25 a side: Sumps 17.0 -> 21.5, foundry 26.9 -> 23.3. **Why not half:** a brain with a new
order or element call runs at once whatever its stride (TankBrain.wants_to_run), and in a fight that is most ticks.
**Behaviour** (all `b3s2` against x18m): the beaten-zone scenario 0 ticks in the zone both; pursuit (4 seeds a map) the
target killed 4/4 both, kill 6.9 / 8.6 s against 8.3 / 7.8; the arrive series 50/50 both. Nothing seen, nothing
gained beyond ~15-25 %. **The answer for the cap: neither the equal-answer cuts (~2 %) nor the stride (~15-25 %) make 50 a
side fit his laptop's tick** (50 v 50 with leaders 62.7 ms a tick on builder0, x 2.75 for the laptop; with both cuts
~48 ms builder0, ~130 ms laptop). The cap is the frame's/perf's number with these as its inputs.
Evidence: `references/round22/brains/b3/` (the fork's report, the 50 v 50 parts table, the stride A/B lines and table,
the stride patch).

### B4 — the range gap, measured for him (no price moves)

`make gap-series` (both sides under their own doctrine's default behaviour, the computer's squad leader each; builder0,
`7061fe8d`, 8 seeds a cell, 90 s):

| case | map | Syndicate won | Rat Rods won | Rat Rods alive | Rat Rods lost (HP) | Syndicate alive | Syndicate lost (HP) | Rat Rods' first blood |
|---|---|---|---|---|---|---|---|---|
| 10 Rat Rods v 4 Syndicate (tank, gunship, spotter, skimmer) | yard_open | 8 | 0 | 0 of 10 | 1000 | 4.0 of 4 | 148 | 3.8 s |
| same | parade | 8 | 0 | 0 of 10 | 1000 | 3.9 of 4 | 159 | 4.0 s |
| 5 Rat Rods v 1 spotter platform | yard_open | 5 | 3 | 0.9 of 5 | 462 | 0.6 of 1 | 175 | 4.8 s |
| same | parade | 7 | 1 | 0.5 of 5 | 474 | 0.9 of 1 | 124 | 4.4 s |

B1 changes none of it (on and off identical, every run): the Rat Rods are attacking, never on a post, so the rule never
fires; the Syndicate's crews are never out-ranged. His words beside it: *"four Syndicate out-range ten Rat Rods for no
damage"* (round 21) -> today a little damage (148-159 HP of ~1240), every one of the 16 lost. The final-arm re-run is
queued. **His call (C12.6), nothing changed.**

### Questions for the lead (in his terms; none blocking)

- **The range gap (B4):** a full Syndicate squad of four beat ten Rat Rods in all 16 fights (all ten dead, the
  Syndicate losing about an eighth of its armour), and one spotter platform beat five Rat Rods in 12 of 16. The four
  cost 1320 points against the ten Rat Rods' 700 (the spotter 340 against five Rat Rods' 350). Recommended: leave it,
  since the Syndicate pays nearly twice as much for that squad; or ask for a price change and say which side moves.
- **Fifty a side (via the orchestrator):** every vehicle thinking 15 times a second instead of 30, on both sides, or a
  smaller cap; the orchestrator is asking him with our numbers.

### Requests to other streams

- None yet.

### Known issues

- B1 against three or more long-range guns at once: the crew dies inside the grace (measured above: 440 in ~3 s).
- B1 on foundry's depot: the computer keeps more vehicles but holds the zone a little less (-4.4 points a match, se
  1.7, final measure pending): cover and fall-back take crews off the zone for a while.
- A local `make remote T=check` wrapper was killed (SIGTERM, 16:13 PDT, rc 143) while its builder0 side ran on (the
  memory guard, most likely; nothing of ours sent it). Checks now run from a dedicated clone
  (`scratchpad/godot-brains-chk`), so the worktree is free while they run.
