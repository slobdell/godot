# Stream: combat (suppression, faction rosters, scale)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: suppression, army size and factions; *Factions*), [../workstreams.md](../workstreams.md)
> (**L2 and L3 are yours and are CP2**), [../balance.md](../balance.md) and [../determinism.md](../determinism.md).
> You own `game/units/`, `game/combat/` except `impact.gd`, `game/match/`, `game/tank/`, `game/arena/` + `arenas/`,
> `tools/{match_series,matchup_matrix,make_arenas,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`. Round 3: [archive/round3/combat.md](archive/round3/combat.md).

## The lead's direction (2026-09-16)

> *"This game should have real concepts of suppressive fire and effective fire (i.e. vehicles make decisions to avoid
> walking into a wall of bullets that will kill them, and opposing forces could concentrate their fire power to create
> those suppressive fire effects or cut off an avenue) … tanks would probably want to provide protective cover for
> weaker units … I basically want a lot of units but I don't want to stress the performance of the game … a baseline of
> 30 units per side … different factions should have different unit sizes based on the effectiveness of each unit (i.e.
> the gang is diluted with cheaper units, so it should be a bigger swarm, the condemned have more expensive and smaller
> unit counts from there, then the law has more expensive and smaller unit counts from there, and the syndicate would
> have the fewest number of units)."*
>
> And on balance: *"it's also probably not worth trying to balance anything out substantively yet"*, because doctrine
> will change every number. Measure, keep it sane, don't chase perfection.

## Where things stand (round 3)

Tank shells (320 damage, 5 s reload, 75 m/s), 25 mm bursts, machine-gun streams, weak spots, armor by face, wheels with
turning circles and multi-point turns, artillery deploy, friendly fire, arenas as data with hazards, K2 weapon events
and `incoming_projectiles`, K3 locomotion and `TankMotion.predict`, the matchup matrix (8 of 12 counters hold), the
control point on by default. 15 faction vehicles exist as **art only** (`game/theme/factions/`, K4 slots).

## Backlog (in order)

**X1. L2 suppression and L3 roster schema (CP2).** Skeleton first, with the sim baseline updated once, on purpose:
- **Suppression:** `Tank.suppression` (0–1, decays), raised by near-misses and by rounds passing close; above a
  threshold a unit is `pinned` (accuracy penalty, and the brains will avoid it). `Match.threat_field(team)` (a cheap
  grid of incoming-fire density) and `Match.is_beaten_zone(from, to)`. K2 events gain `suppression_applied`.
- **Rosters:** `Units.PROFILES` entries carry `faction`; `Units.roster(faction)`; `--green-faction=`/`--rust-faction=`
  on the match runner; `Army` builds a faction army to a budget. The Condemned keep today's stats.
Tests for every field. **Announce CP2 as soon as it's green.**

**X2. Suppression that changes decisions.** Tune it so a machine gun's value is volume, not damage: a stream across a
lane should make crossing it a bad idea, concentrated fire should pin, and pinning should be worth doing. Work with ai
(they consume `threat_field`) and doctrine (support-by-fire drills). Measure: time to cross a suppressed lane, hit rate
while pinned, and whether "pin then flank" beats "everyone shoots" in a seeded series.

**X3. Heavies protect the fragile.** Give the mechanics that make interposing worthwhile: hull size and line of fire
already block shots; consider armor facing rules for taking hits meant for a neighbor. Don't invent a "guard" buff:
make position do the work, and measure that a tank in front of a Lancer actually saves it.

**X4. Faction rosters (L3).** Three new rosters on the existing art (`game/theme/factions/`), each with its own costs,
stats and feel:
- **Road gangs:** cheapest, fastest, most numerous; light armor; short range; the swarm.
- **The Condemned:** today's roster, the mid-point (~30 units a side at the baseline budget).
- **The Law:** fewer, tougher, disciplined; suppression tools (their special is the sonic emitter).
- **The Syndicate:** fewest, most expensive, best per unit; energy weapons; the Lancer is their special.
The lead's baseline is ~30 a side for the mid faction, and the counts fall out of cost and effectiveness, not fixed
numbers. Fill `good_vs`/`weak_vs` only where the mechanics really deliver it (game_design.md's ruling; the
`scout > lancer` claim is still owed a mechanic or removal).

**X5. Scale.** With ai's cost work, make 30 a side (and more for the gangs) actually run: spawn zones and arena sizes
that fit ~60–90 vehicles, match lengths that stay fun, and the sim cost per tick measured at 25 / 40 / 60 / 100 a side
(report the numbers; ai owns the brain cost, you own the simulation's).

**X6. Re-measure, don't over-tune.** Re-run the matchup matrix and a faction-versus-faction series (each faction at the
same budget, both bases) after doctrine lands, and write what you see in balance.md. Fix only what's broken
(a unit that wins everything, a faction that can't win); leave fine balance for a later round.

- **Stretch:** wrecks as cover (the husk prop exists); arena layouts sized for bigger armies.

## How to verify

`make remote T=check` with the sim baseline updated on purpose and the reason recorded; unit tests per mechanic;
`make duel` timelines; seeded series on builder0; screenshots of a 30-a-side fight **looked at**.

## Don't touch

Elements, formations and drills (doctrine), brains (ai), the camera and HUD (control), audio (audio), Meshy art
(no stream this round; 88 credits left).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
- 2026-09-16: **plan** (worker contract step 2). Ordered, smallest foundation first:
  1. **X1a suppression** — `ThreatField` (a coarse decaying grid of where rounds fall), `Tank.suppression`/`pinned`,
     `Match.threat_field(team)` / `is_beaten_zone(...)`, K2 `suppression_applied`. Tests per field.
  2. **X1b roster schema** — `faction` on every profile, `Units.FACTIONS`/`roster()`, faction CPU armies,
     `--green-faction=`/`--rust-faction=`. Then **announce CP2**.
  3. **X2** tune suppression and measure (lane crossing, hit rate while pinned, pin-then-flank series).
  4. **X3** heavies shielding the fragile (position does the work, no guard buff).
  5. **X4** the three new rosters (gangs, law, syndicate) on the existing art.
  6. **X5** scale: spawn grid, arena sizes, sim cost at 25/40/60/100 a side.
  7. **X6** re-measure the matrix and faction-vs-faction; write balance.md.
  8. Stretch: wrecks as cover.

### X1 done (2026-09-16): L2 suppression + L3 roster schema — **CP2 is ready to merge**

**L2 suppression and effective fire.** Every round that resolves stamps the ground it swept into a coarse decaying
grid, one per team (`ThreatField`, `game/combat/threat_field.gd`: 6 m cells, 1 s half-life). Units in that fire get
suppressed, which costs accuracy and turret tracking, and above `Tank.PINNED_SUPPRESSION` (0.6) counts as pinned.
Numbers, reasons and the deliberate simplifications: [balance.md](../balance.md) *Round 4: suppression and effective
fire*. The API other streams build on:

| Call | Meaning |
|---|---|
| `Tank.suppression` (0..1), `Tank.is_pinned()`, `Tank.suppress(amount)` | the crew's state; `sync_suppression` is published for non-simulating peers |
| `Match.threat_field(team) -> ThreatField` | the fire **coming at** `team`. `at(point)`, `peak_along(from, to)`, `mean_along(from, to)`, `hot_cells()` |
| `Match.is_beaten_zone(team, from, to) -> bool` | would this move cross a wall of bullets? |
| `Match.threat_along(team, from, to) -> float` | the same as a score, for ranking routes |
| `Match.shot_spread(weapon, moving, suppression) -> float` | radians; the one place accuracy penalties live |
| `Weapons.suppression(weapon) -> float` | per round (per second for cones): MG 0.10, 25 mm 0.35, cannon 1.2, laser 0.15, mortar 3.0, flame 1.5/s |
| K2 events | `weapon_fired` and `projectile_impact` gained `suppression_applied` |

**Contract deviation, please relay:** the brief wrote `Match.is_beaten_zone(from, to)`, which has no way to say
*whose* incoming fire is meant. It ships as `is_beaten_zone(team, from, to)` (and `threat_field(team)` exactly as
specified). ai and doctrine: pass the asking unit's own team.

**L3 roster schema.** `Units.FACTIONS` / `DEFAULT_FACTION` / `FACTION_NAMES`, a `faction` key on every profile,
`Units.roster(faction)`, `Units.roster_average_cost(faction)`, `Army.archetypes_for(faction)`,
`Army.typical_size(faction, budget)`, `Army.load_army(name, seed, budget, faction)` and
`--green-faction=` / `--rust-faction=` on the match runner. Only the Condemned have units so far (X4 adds the other
three); the faction tests run over whatever factions have a roster and tighten by themselves.

**Scale plumbing that L3 needed** (part of X5, done early because a 28-vehicle army has nowhere to stand otherwise):
`Units.BASELINE_BUDGET` 5200 (= 28 Condemned a side, the lead's ~30), `Army.MAX_ARMY_UNITS` 45,
`Match.SPAWN_SLOTS` 27 → 52 (13 columns × 4 rows; the front row stays at `BASE_Z`, so pace is unchanged), z-clamped
spawn jitter, and regenerated `arenas/*.json` spawn lists.

**Verified:** `make remote T=check` green (681 tests, every smoke, determinism); new tests
`test_combat_suppression.gd` (13) and `test_combat_factions.gd` (12). **The sim baseline moved on purpose** to
`glibc-2.43 e9e5761beebbde59` (recorded twice on builder0, identical): suppression changes shot spread, and
`Match.state_hash` now includes each unit's suppression.

**Requests to other streams**
- **doctrine:** raise `Doctrine.MAX_SQUADS` (5) or make it a UI-only cap. 28 vehicles need six squads or more, so
  faction armies are validated through `Army.parse_scaled`, which runs `Doctrine.parse` over slices of five squads.
  That wrapper exists only to avoid editing your file, and should go away.
- **ai / doctrine:** `threat_field` / `is_beaten_zone` are live; the signature note above.
- **orchestrator:** `HANDOFF.md` ("Sim baseline `glibc-2.43 d7967d8b36d4417b`") and `_agents/workstreams.md`
  (invariant 2, same hash) both name the old baseline and need the new one at merge.

**Merge notes (shared files):** `game/modes/match_runner_mode.gd` (mine) gained the two faction flags; no edits to
`project.godot`, `export_presets.cfg`, `game/main.gd`, `Makefile` or `mk/core.mk`.

**Questions for the lead** (nothing is blocked on them)
1. **Faction art is 47 MB and excluded from the exports** (`export_presets.cfg` `game/theme/factions/*`). The new
   rosters will therefore *play* as their own factions but *look* like the Condemned (the C6 fallback). Shipping the
   models would grow the web pack from 0.8 MB to ~48 MB, which is a cross-stream call, not mine.
2. **The Lancer sits in two rosters.** Resolved the way *Factions* asks for ("same roles, wildly different
   trade-offs"): the Condemned keep today's Lancer, and the Syndicate gets its own lancer-role vehicle with its own
   numbers. Say if you wanted one of them to lose it instead.

### X2 done (2026-09-16): suppression measured, and it needs ai and doctrine to pay off

Every number and how to reproduce it: [balance.md](../balance.md) *X2: does suppression actually bite?*. The
mechanics do what the lead asked for, in isolation:

- one machine gun streaming across a lane makes it a beaten zone; three cost a crossing IFV **4.5× the damage** and
  **pin** it;
- one crew settles a tank at **0.42** suppression, two at **0.82** (pin at 0.60): concentrating fire works;
- a pinned tank hits **5/13** where a calm one hits **13/13**, and takes **208 ticks** instead of 105 to swing its
  turret 90° — which is exactly why "pin, then flank" is a plan;
- a machine gun lays down **1.0 suppression/s** against a cannon's 0.24, while still doing ×0.05 damage through a
  tank's front: volume, not damage.

**But it changes no match outcomes yet.** Swarm vs Armor over 16 seeds is 16-0 to Armor with suppression and 16-0
without; mean suppression per living unit is **0.03** and units are pinned **0.7%** of the time. The scouts that carry
the machine guns spend **84% of their time on SPOT**, and nothing in the game deliberately puts fire on a lane. The
only measurable difference is pace: fights run 12% longer.

I deliberately did **not** tune suppression up to force an effect: that would distort the matchup matrix to
compensate for unused mechanics. Two fixes for the two streams that own the decisions:

**Requests to other streams (X2)**
- **ai:** (1) make suppressing a deliberate option — a brain with a volume weapon and a loaded gun should be willing
  to put fire on a lane or on a pinned target rather than only on what it can kill; (2) score movement with
  `Match.is_beaten_zone(team, from, to)` / `threat_along(...)` so units stop driving through walls of bullets; (3) a
  pinned unit is a *worse shooter*, not a worse target — `Tank.is_pinned()` is the cue to flank it.
- **doctrine:** support-by-fire needs a base of fire that keeps shooting at ground it wants denied, not only at
  targets. That is what turns the mechanic on.
- **Both:** `Match.stats` now carries `suppression_samples` / `suppression_total` / `pinned_samples` per team and
  `tools/match_series.py` prints "suppression (mean per living unit, share pinned)", so you can see whether a change
  actually produced suppressive fire.

**New measurement targets (mine):** `make suppression-series`, `make suppression-control` (counterbalanced),
`make faction-match`, `make faction-series`.
