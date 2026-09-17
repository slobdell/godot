# Stream: ai (cost at scale, the gates that block behaviour, the tactics ladder)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *Unit AI*, *What earns a place in doctrine*), [../workstreams.md](../workstreams.md),
> [../unit_ai.md](../unit_ai.md) and [../doctrine.md](../doctrine.md), and your round-4 report
> [archive/round4/ai.md](archive/round4/ai.md). **Doctrine had no stream this round, so you inherit it:** you own
> `game/ai/`, `game/tactics/`, `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`,
> `tests/ai_scenarios/`, and `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md`.

## The lead's direction (2026-09-17)

Frame rate is the blocker this round, and the brains are part of it: *"right now for this many vehicles the framerate
drops substantially."* The simulation's share is yours. The lead also still wants what he asked for in round 4: units
that look intelligent, and eventually *"an offline simulation … to discover novel tactics and formalize those
discoveries into deterministic heuristics."*

## Where things stand (round 4, measured)

| Item | State |
|---|---|
| Brains execute doctrine (L1), suppression-aware movement and deliberate suppression (L2) | done and measured |
| **CPU cost** | **5.4–6.2 ms per tick at 60 units, against a 4 ms target** |
| **SUPPRESS unreachable in a duel** | a gate, not a weight: the "killing this is slow going" test reads `Matchups.kill_rate`, and the champion runs with `matchups: false` |
| **A pinned enemy doesn't pull a unit out of cover** | the 1.5× flank bonus exists but COVER_FIRE wins the choice 1435 ticks of 1440 |
| Tactics ladder (X4), faction behaviour (X5), offline discovery groundwork (X6) | **not started** |
| Champion | `x4t9` (thinks every 9 ticks in a fight) |

## Backlog (in order)

**X1. 4 ms at 60 units.** The named levers, in priority order from your own report: `_cover_fire_spot` runs a tactical
query for every brain with a target in reach, including ones that will never choose COVER_FIRE; a shared per-team
contact table instead of per-unit scans; typed arrays and precomputed matchup tables in `decide()`; order execution at
a lower rate for units that aren't firing. **Measure behaviour, not just the clock** (round 4's lesson: two cost cuts
silently removed most of a behaviour). `make ai-perf UNITS=60` before and after, plus the scenarios.

**X2. The gates that block behaviour** (with combat's X5). Make SUPPRESS reachable with a matchup-free proxy
(penetration against armour), and make a pinned enemy actually pull units out of cover. Both change what the champion
does, so both go through the ladder rather than a late edit.

**X3. The tactics ladder (round 4's X4, unfinished).** `make tactics-ladder`: seeded headless matches sweeping
**doctrine** variants and arenas alongside brain variants, reporting **per drill** rather than per variant, with ELO.
This is how a drill earns its place (game_design.md's rule) and how arena's new maps get judged for the fights they
produce. Arena's M2 layouts land this round: sweep them.

**X4. Faction behaviour that reads.** Gang packs, Law bounds behind suppression, Syndicate kiting — visibly different
at play distance, and measured in the ladder. The gangs' 23% win rate is combat's number, but if the cause is
behaviour, it's yours: a swarm that fights like a line company will lose.

**X5. Offline discovery groundwork** (round 4's X6, unfinished): a match-runner mode where an external process sees a
compact state and issues element tasks on a slow cadence, optional slow motion, and a `(state, decision, outcome)` log.
Write the distillation plan in `unit_ai.md`. **No model runs during live play.**

- **Stretch:** run the discovery experiment once and report what it found; a difficulty knob (reaction time,
  suppression sensitivity); explanation overlays for the lead's playtests.

## How to verify

`make remote T=check`; your scenarios; `make ai-perf` numbers before and after X1; the ladder's tables; a watched match
whose screenshots you look at, with a spectator's description. The sim baseline changes on purpose, recorded on builder0.

## Don't touch

Weapons, armour and rules (combat; request changes), arena layouts (arena), vehicle art and effects (render), UI and
camera (control), audio (audio).

## Status

_Round 5, ai stream. Updated 2026-09-17. Branch `stream/ai`. **`make remote T=check` green on 9231c6f: 900 passed, sim baseline `glibc-2.43 32f665bc60306e8f` matched** (later commits are docs only)._

### Plan (in order, smallest foundation first)

| # | Item | State |
|---|---|---|
| X1 | 4 ms at 60 units | **exact cuts done; the rest is structural.** The lead chose the 30 Hz simulation (combat, landing after this branch). `x5b2`/`x5pb2` (half-rate controllers) held: at 30 Hz they would think at 15 Hz |
| X2 | SUPPRESS reachable without matchups; a pinned enemy pulls units out of cover | **pinned half done: champion `x5p`** (53-43 over x4t9); the SUPPRESS proxy (`x5q`) lost with the swarm and waits for combat's `Lethality` |
| X3 | `make tactics-ladder` | **done** — doctrine wins small and loses large; `break_contact` cut; skirmish CPU stays on brains until a doctrine beats them at scale |
| X4 | Faction behaviour that reads, measured in the ladder | **measured, not solved**: faction doctrine loses to brains at scale; the gangs lose however they're run; the fix is an army-level plan (round-6 proposal in doctrine.md) |
| X5 | Offline discovery groundwork | **done** — `DiscoveryBridge` + `tools/discovery.py`, distillation plan in unit_ai.md; its first policy became the `pin_and_flank` commander variant (in the ladder) |

### X1 — the cost of 60 brains: what was measured

**Measuring first.** Wall time on builder0 swings ±25% between its P-cores and E-cores and with five other agents'
load, which hid every cut under 10%. `make ai-perf` now also prints the **thread CPU time** of the brains' band
(`tests/ai_scenarios/band_probe.gd` brackets the priority -10 band and reads `/proc/thread-self/schedstat`), and that
**per living unit per tick**, so variants that fight different battles still compare. On the idle laptop CPU time
and wall time agree within 1%.

| ai-perf, 60 cannon tanks, laptop, thread CPU per tick | usec | per living unit |
|---|---|---|
| Start of round 5 (x4t9) | 7748 | 188 |
| + exact cuts (typed per-tick columns, feed sources once per tick, no cover-fire search for fast guns, no lambda per option) | ~7400 | ~180 |
| + CoverMap typed features and bucketed tactical points (the yard has 2860 points every query used to scan) | 7260 | 177 |
| x5b2 (whole controller every other tick, staggered), whole scenario suite | | **147 (-21%)** |

Every exact cut kept the battle byte-identical (the LOS query counts and `make sim-baseline` are unchanged) and the
risky ones have equivalence tests against the plain versions (`test_ai_perf_equivalence`,
`test_ai_cover_map_equivalence`, both mutation-checked).

**Where the time goes**, measured by running one piece twice per tick and reading the extra CPU (a lower bound, since
the second call hits warm caches): thinking ~35% (situation 15%, decide 10%, the rest acting and the per-tick polls),
executing ~37% (moving 19%, the gun 14%). No piece dominates: 60 brains are ~180 µs each per tick of GDScript
spread over a few hundred operations. Round 4 already spent the think-rate lever, and holding only the steering at
30 Hz ("exec_stride") bought 6% and was removed.

**So 4 ms at 60 units on the laptop needs about half the work per tick,** and there are two ways to get it:
1. **combat's 30 Hz simulation proposal** (`_agents/sim_tick_rate.md`): halves every band, ai's included. A lead
   decision, now in front of him through the orchestrator.
2. **`x5b2`** (ai-only, opt-in): each brain runs its whole controller every other physics tick, staggered, and the
   tank keeps its last command in between; a new K1 order or element call still runs on the very next tick
   (`ai_order_response` worst 1 tick, unchanged). -21% per unit in the suite (thinking cadence is unchanged, so not
   -50%). It becomes champion only if the ladder says it costs no behaviour. It and (1) don't stack: if the lead takes
   (1), x5b2 goes.

**Found on the way:** `OrderController._shootable` computed "does my team see it" and never used the answer, so a gun
has always fired at anything in range with a clear line. The dead call is gone; whether it should hold fire on things
nobody spotted is a behaviour question for the ladder.

### X3 — the tactics ladder, and what it found

`make tactics-ladder` (unit_ai.md "Tactics ladder"). First full run: 120 matches, combined_arms mirror, foundry, yard,
boulevard, pit and boneyard, 2 seeds × 4 ways per pairing per arena, x4t9 brains throughout.

| Side | W-L | vs brains-only |
|---|---|---|
| faction's own doctrine | 49-31 | 26-14 |
| standard doctrine | 43-37 | 26-14 |
| brains only (what the skirmish CPU ran) | 28-52 | |

**The skirmish CPU had never run doctrine** (brains only unless `--element-cpu`), and the match runner never ran it at
all, so round 4's formations and drills were in no game the lead played.

**But doctrine wins small and loses large.** The mirror above is five-vehicle squads with no objective. In the game the
lead plays — faction armies at the 5200 budget, control point on — one snapshot (fc88c24), gangs vs law with every side
playing both factions, foundry / yard / boulevard:

| Ladder | brains only vs faction doctrine | brains vs faction doctrine without break_contact | faction doctrine without vs with break_contact |
|---|---|---|---|
| fac1b, control point on (144 matches) | **34-14** | **24-24** | **27-21** |
| fac2, control point off (48 matches) | 27-21 | | |

fac3 (same snapshot, control point on, 144 matches): faction doctrine without far_ambush, assault_through and bait
**drew brains 24-24** (gangs under it 24-24, the best any side did playing the gangs); the pin-and-flank commander lost
to brains 20-28 and to the trimmed table 20-28. Trimming drills buys parity, never superiority, whichever drills go.

So the control point makes doctrine worse (it funnels every element to one circle) but is not the whole story: doctrine
still loses without it. break_contact is a net loss at both scales and is now off in every shipped table
(875462f). Playing the gangs loses however they're commanded (brains 18-30, doctrine 10-38): that part of the 23% is
combat's. The skirmish CPU default **stays on brains** (the orchestrator's approval was withdrawn when this landed);
control has the switch ready (`ELEMENT_CPU_DEFAULT`). What's missing is a decision above the elements about which of
them take the objective and which shape the fight: a round-6 proposal in doctrine.md. Caveat: every ladder here used
x4t9 as the brains; the champion is now x5p, which only makes brains-only stronger.

Per drill (damage charged to what the units were doing), standard / faction: **support_by_fire 9.4 / 12.1 exchange**,
react_to_contact 1.08 / 1.12, near_ambush 1.16 / 1.18, assault_through 1.22 / 1.08, **break_contact 0.75 / 0.73 over
40% / 15% of drill time**, **far_ambush 0.26 / 0.16 with 16 / 44 deaths**. Exchange is evidence, not a verdict: **removing far_ambush changed
nothing** (55-65 overall, 20-20 head to head with standard) — it is chosen in fights already going badly. The only way
to know what a behaviour costs is to remove it and measure the army with and without. The discovery harness's
`pin_and_flank`, distilled into the commander, lost 43-77: the loop produces candidates, the ladder decides.

**Cost of doctrine at 30 a side** (laptop, Jolt, condemned 31 v 27, `make sim-profile`, interleaved, normalised by
the tank band): the elements band averages **1.5-1.8 ms/tick**, about **+15% of the whole tick** with brains running
under orders. It used to arrive as a **~9 ms spike every 6th tick** (every leader decided on the same tick); since
611b380 each element decides on its own tick in the cycle, so the **average is unchanged but the periodic hitch is
gone** — a stutter a player feels even when the mean frame time looks fine. Breakdown of an element update: situation
0.61 ms, plan 0.34, issuing orders 0.24 (per tick).

### X1 — x5b2's behaviour check

`tests/ai_scenarios/scenario_stride.gd`, x5b2 against x4t9 on the same seeds (laptop, Jolt): IFV dodges 14% of 35
tank shells vs 17% of 30, tank 17% vs 17%; crossing a swept lane 10 ticks in the beaten zone vs 10, both arrive.
Brain ladder (4 armies × 16): 31-33 head to head. More seeds (5-12) running before any proposal.

### Decisions taken where the brief left a choice

- **X1 measured by thread CPU time per living unit, interleaved** (band_probe.gd): wall time on a shared machine
  hid every cut under 10%, and variants fight different battles.
- **x5b2 held, not proposed:** -20% per unit for a 31-33 ladder and no measurable loss in dodging or the beaten
  zone, but the lead chose the 30 Hz simulation, where a half-rate controller would think at 15 Hz.
- **x5p adopted as champion** (53-43), **x5q not**: the SUPPRESS proxy cost the swarm army; combat's `Lethality`
  query is the better gate and is on its way.
- **Doctrine is not the skirmish CPU default** despite the first 52-28: in the real setup it loses (above).
- **break_contact cut, far_ambush kept**: removal measured, not exchange ratios.
- **The discovery harness is lockstep over stdin** rather than HTTP: a slow decider is never late and a seed replays.

### Questions for the lead

1. **An army-level plan above the elements** (doctrine.md, round-6 proposal): which elements take the objective, which
   shape the fight on the lanes, which stay in reserve. Doctrine wins at squad scale and loses at 30 a side, and this is
   the layer that's missing. Worth a round-6 stream?
2. With the control point on, everything funnels to one circle (arena: flank lanes 4-5% of unit-time). Should the
   control point stay on by default, or become one objective among several?

### Requests to other streams

1. **combat:** the match runner still runs brains only. `--green-elements` / `--rust-elements` (TacticsFlags) opt in;
   turning it on by default is your re-baseline to call, once a doctrine beats brains at scale.
2. **combat:** when `Lethality` merges, ai wires SUPPRESS's "slow kill" gate to it (x5q's replacement).
3. **control:** keep `ELEMENT_CPU_DEFAULT` false; the switch is right, the doctrine isn't ready.
4. **combat:** the gangs lose whether brains or doctrine command them (18-30 / 10-38 in the faction ladder).

### Known issues

- **4 ms at 60 units on the laptop is not met** at 60 Hz (~7.3 ms thread CPU in ai-perf). The 30 Hz simulation is
  the lead's answer; re-measure per second of match time after it lands.
- `drills.gd` turns near_ambush into assault_through without checking the table, so "-assault_through" in a ladder
  spec only removes half of it.
- The doctrine elements band costs ~1.5-1.8 ms/tick at 30 a side (now flat instead of a spike every 6th tick); the
  situation build (0.61 ms) is the next thing to cut if doctrine becomes the default.
- `OrderController._shootable` never used team spotting (found in X1, left as it always behaved).
- **net-smoke is flaky on builder0:** one of two full checks on this branch failed it with `ERROR: Condition "ready_state != STATE_OPEN" is true. Returning: FAILED` in the server log while both bot clients printed NET_CHECK PASS (a WebSocket teardown race, not ai code); the next check passed. Characterised here so nobody blames their own change for it.

### What to playtest

- `make skirmish` — the CPU now fights with x5p: a unit peeking at a tank that two machine guns have pinned comes out
  of cover and presses it.
- `make skirmish ARGS=--element-cpu` (or control's flag) — the CPU under doctrine, to see the difference yourself.
- `make tactics-ladder SIDES=brains=x5p,faction=x5p: FACTIONS=gangs,law` (on builder0) — the doctrine question.
- `python3 tools/discovery.py --godot .tools/godot-*/Godot_v4*.x86_64 --policy pin_and_flank --time-limit 90` —
  the offline discovery loop, logging to build/discovery/run.jsonl.

### Next steps

1. After 30 Hz: re-measure ai-perf per second of match time; re-run scenario_stride's checks; decide x5b2's fate.
2. Wire SUPPRESS to combat's `Lethality` and re-ladder (x5q's replacement).
3. The army-level plan (round-6 proposal), proven in the faction ladder at scale before any default flips.
4. `facing` from K1 when control's change reaches main (the herringbone shuffle in element_plan.gd).

### Merge notes

- **Sim baseline moves on purpose: `glibc-2.43 32f665bc60306e8f`** (champion x5p, recorded twice on builder0), in its
  own commit. No other commit on the branch moves it (the doctrine and element changes don't run in the baseline
  match). Merge before combat's 30 Hz change so the two moves stay separate.
- Shared files: none. `tests/test_tactics_reports.gd`'s frozen booth drill list lost `break_contact` (audio told).
- New make targets: `tactics-ladder` (mk/tactics.mk); `ai-ladder` gained `FIRST_SEED`; `ai-perf` prints thread CPU.
- New flags (all opt-in, headless tooling): `--green/rust-elements[=table-drill+commander]`, `--tactics-ledger`,
  `--green/rust-discovery[=seconds]`, `--discovery-log`, `--slow-motion`.

Queued from other streams (after X1, in the doctrine code ai inherits):
- **arena:** `ElementSituation._arena_features` calls 86–95% of the kit-built maps "dense" (it counts boxes; one container
  wall is several). Count touching boxes (1.5 m) as one piece of cover and ignore `cover: "low"` barricades; arena
  measured foundry unchanged at 16% (`make arena-report`).
- **control:** K1 `UnitCommand.facing` has landed; brains turning to `order["facing"]` on arrival and to
  `Orders.station(unit)["heading"]` when idle lets `element_plan.gd` drop the `HALT_*`/`_plan_halt` shuffle.

- **arena (for X3/X4):** flanks are 4–5% of unit-time on the dense kit maps against 14% on foundry (the CPU funnels
  to the control point), and median hit range is 39–43 m on every map. Lanes are annotated (`Arena.lanes_of`): the
  ladder should measure whether elements and brains actually take them.

Decision: X1 before X2 because X2 changes what the champion does, and every X2 ladder run is cheaper once the brains are.

