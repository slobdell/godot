# Balance: measurements, tuning values, and the army design

> **Round 2 note (2026-09-15):** the chassis + loadout recommendation below was superseded by the lead's fixed unit types ([game_design.md](game_design.md)). Measurements stay as history; the rules stream adds the unit-vs-unit matchup matrix, and the army stream adds the economy section.

> Started 2026-09-15 by the gameplay stream's overnight run. Everything here was measured with
> `tools/match_series.py` (headless, seeded, `--elimination`, 300 s limit). Small samples (10–24 per
> row) are marked; treat anything within ±15 points of 50% as "not significantly different".
> Rules of thumb: always run swapped bases (`--swap-bases`) and swap which team plays which side
> (team identity). Use `--tune=unit_or_weapon.stat=value` to try a number without editing code.

## Where the tuning values live

| What | File | Key values (round 2, rules stream) |
|---|---|---|
| Unit types (cost, tier, hull, shield, speed, turn rates, sight, weapon, mount, fire arc, muzzle height, armor thickness) | `game/units/units.gd` `PROFILES` | scout 110 pts, 140+80, 14 m/s, fixed MG ±8°, armor 2/1/1; tank 200, 300+150, 9 m/s, turret 50°/s, armor 8/4/2; IFV 150, 220+100, 11 m/s, turret 180°/s, armor 5/3/2; artillery 220, 200+80, 6.5 m/s, armor 3/2/1.5; Lancer 200, 200+120, 8.5 m/s, turret 80°/s, heat 100 (−12/s), armor 4/3/2 |
| Weapons (damage, range, reload, spread, ammo, heat, penetration, splash, shield multiplier) | `game/combat/weapons.gd` `PROFILES` | cannon 34, 70 m, 2.5 s, pen 10; autocannon 9, 60 m, 0.35 s, pen 4; laser 9/0.5 s, 80 m, 12 heat, pen 12, shield ×1.25; machine gun 4/0.2 s, 45 m, pen 3; mortar 70 in 8 m, 35–160 m, 4.5 s, pen 10; flamethrower 20/s, 20 m, pen 12 |
| Penetration vs armor, directional shields | `game/combat/armor.gd` | hull multiplier = clamp(0.5·log2(1.6·pen/armor), 0.05, 1.5) on the face hit (arcs hit "side"); shield front 0.7 / side 1 / rear 1.4 |
| Base service, arena, sensing, friendly fire, spawns | `game/match/match.gd` | resupply 1 shell/s and repair 6 HP/s within 30 m of your base; intel every 6 ticks, 12 s memory; blind artillery scatter ×3; friendly fire always on; 9 × 3 spawn grid |
| Arena layouts | `arenas/*.json` (`Arena`) | `foundry` (round 1's map), `scrapyard` (dense cover, three lanes) |
| Brain weights | `game/ai/tank_brain.gd` (ai stream) | ORDER_WEIGHT 0.95, SCOUT_STANDOFF 85 m, SCOUT_HUNT 1.6 (floor 0.8), ARTILLERY_SAFE_DISTANCE 80 m, RECHARGED 0.6 |
| Budget | `Units.DEFAULT_BUDGET` | 1000 |

Try a number without editing code: `--tune=tank.turret_turn_rate_deg=70,ifv.armor.front=4,autocannon.penetration=5`
(match runner, `tools/match_series.py --extra=`, `make matchups TUNE=`).

## Round 2: the unit-vs-unit matchup matrix (rules R7)

`make matchups` (tools/matchup_matrix.py) plays cost-equal single-type armies for every pair of unit types, on
both bases, each type as both colors. Intended counters (game_design.md): scout > artillery, scout > Lancer,
IFV > scout, tank > IFV, Lancer > tank, artillery > slow clumps. Bar: a counter wins ≥ 65% cost-equal and every
unit wins some matchup.

### Fairness controls after rules R1–R6 (2026-09-14)

2v2 legacy bots (`--green 2 --rust 2`, first to 5 kills or 300 s), 24 seeds per row:

| Arena | Normal bases (Green south) | Swapped (Green north) | South base | Green team |
|---|---|---|---|---|
| foundry | Green 14 : 7 Rust (3 draws) | Green 8 : 14 Rust (2) | 28 : 15 | 22 : 21 |
| scrapyard | Green 16 : 7 Rust (1) | Green 14 : 8 Rust (2) | 24 : 21 | 30 : 15 |

Friendly fire dominates these bot matches: ~2 friendly kills per team per match (the legacy BotController
doesn't check its line of fire), so matches rarely reach 5 enemy kills. Each layout is fair on one axis and
lopsided on the other, which reads as noise, not geometry (the navmesh symmetry tests pass for both); the brain-
driven control below decides.

Brain-driven control (Individuals mirror, 5 tanks a side, elimination, 240 s), 30 seeds per row:

| Arena | Normal bases | Swapped | South base | Green team | Friendly kills / match |
|---|---|---|---|---|---|
| foundry | Green 16 : 14 Rust | Green 18 : 12 Rust | 28 : 32 (47%) ✅ | 34 : 26 | 0.25 |
| scrapyard | Green 16 : 14 Rust | Green 14 : 16 Rust | 32 : 28 (53%) ✅ | 30 : 30 ✅ | 0.4 |

Both layouts are fair. Dense cover (scrapyard) doubles friendly damage (~1,200 vs ~650 points per match): more
shots through teammates at corners, which the AI stream's line-of-fire checks should cut.

### Matrix #1 (commit 6fb62db, current brains, before any R7 tuning)

| row beats column | scout | tank | ifv | artillery | lancer |
|---|---|---|---|---|---|
| scout | — | 0% | 0% | **83%** | 0% |
| tank | **100%** | — | **100%** | **100%** | **67%** |
| ifv | **100%** | 0% | — | **100%** | **67%** |
| artillery | 17% | 0% | 0% | — | 0% |
| lancer | **100%** | 33% | 33% | **100%** | — |

Holds: IFV > scout, tank > IFV, scout > artillery. Fails: tank > scout (should lose), Lancer > scout and Lancer
< tank (inverted), artillery dominated, tank dominant.
Mechanisms (watched in the brain's option stats): **scouts don't fight** anything but artillery. The brain gives
scouts SPOT (hold 85 m standoff) and scales their ENGAGE by SCOUT_FIGHT, so five scouts orbit a tank at 85 m
until it runs them down, and Lancers (80 m beam) pick them off at their standoff distance. That's brain behavior
(ai stream: matchup targeting, fixed-mount strafing runs), not a stat; the scout rows can't be judged until it
lands. Artillery alone has only its own 60 m sight, so it can barely fire (35 m minimum range).

### R7 tuning experiments (12 matches per pair, 600 points, `--tune`)

| # | Change | Result |
|---|---|---|
| A+B | laser 85 m, preferred 72–82, Lancer sight 85; artillery sight 90 | Lancer vs tank 33% → 58%, but Lancer vs IFV 33% → 58% (wrong way); artillery still 0% |
| C | A + laser 12 dmg / 16 heat, Lancer turret 55°/s | **tank > IFV 100%, IFV > Lancer 75%, Lancer > tank 67%** ✅ applied |
| D | artillery sight 90, both sides escorted by 1 scout (a spotter, outside the budget) | artillery 0–17% ❌ |
| E | D + mortar 110 dmg, splash 10, reload 4 s, artillery 180 pts | artillery 92–100% ❌ (flipped) |
| F | mortar 85, splash 9, artillery sight 90 (escort for tank/IFV/Lancer rows; none vs scouts) | spotted artillery 46–79% ✅, but beats scouts 58% ❌ (sees them coming) |
| G | mortar 85, splash 9 (sight 60) | spotted 0–58%; beats scouts 75% ❌ (splash wrecks clumped scouts) |
| H | G + minimum range 50 m | scouts > artillery 88% ✅; spotted artillery 0–29% ❌ (rushers get under it) |
| I | mortar 90, splash 9, minimum range 42 m | **scouts > artillery 92%; spotted artillery beats IFVs 58%**, loses to tanks 33% and Lancers 17% ✅ applied |

<!-- MATCHUP MATRIX BEGIN -->
_Matrix #2, measured 2026-09-14 with `tools/matchup_matrix.py` on the R7-tuned catalog (committed right after 2b6d33c)._

Cost-equal armies at ~600 points per side (scout 5x = 550, tank 3x = 600, ifv 4x = 600, artillery 3x = 660, lancer 3x = 600); 3 seeds x both bases x both colors = 12 matches per pair, 180 s limit. Cell = the ROW unit's win share against the COLUMN unit (draws count half; a timeout goes to the side with more army value left).

| row beats column | scout | tank | ifv | artillery | lancer |
|---|---|---|---|---|---|
| scout | — | 0% | 0% | **92%** | 0% |
| tank | **100%** | — | **100%** | **83%** | 33% |
| ifv | **100%** | 0% | — | **100%** | **75%** |
| artillery | 8% | 17% | 0% | — | 0% |
| lancer | **100%** | **67%** | 25% | **100%** | — |

| pair | row wins : column wins : draws | avg length | friendly damage / match |
|---|---|---|---|
| scout vs tank | 0 : 12 : 0 | 131 s | 400 |
| scout vs ifv | 0 : 12 : 0 | 50 s | 473 |
| scout vs artillery | 10 : 0 : 2 | 101 s | 133 |
| scout vs lancer | 0 : 12 : 0 | 63 s | 80 |
| tank vs ifv | 12 : 0 : 0 | 95 s | 600 |
| tank vs artillery | 10 : 2 : 0 | 97 s | 248 |
| tank vs lancer | 4 : 8 : 0 | 103 s | 362 |
| ifv vs artillery | 12 : 0 : 0 | 72 s | 182 |
| ifv vs lancer | 9 : 3 : 0 | 64 s | 163 |
| artillery vs lancer | 0 : 12 : 0 | 36 s | 258 |
<!-- MATCHUP MATRIX END -->

Spotted artillery (both sides escorted by one scout, outside the budget and the verdict), same tuned catalog:
artillery vs tank 33%, vs IFV **58%**, vs Lancer 17%. Artillery is a support unit: alone it is blind (60 m sight,
42 m minimum range), so the pure matrix row understates it.

**Where R7 stands:** five designed counters hold at ≥ 65% (IFV > scout, tank > IFV, Lancer > tank, IFV > Lancer,
scout > artillery) and every unit wins a matchup (artillery only with a spotter). Not yet: scouts beat nothing but
artillery (the design wants scout > Lancer and trouble for tanks). That's the scout brain's spotting standoff
(SCOUT_STANDOFF 85 m, SCOUT_FIGHT): re-run `make matchups` when the ai stream's matchup targeting and fixed-mount
strafing land, before touching scout stats. Samples are 12 per pair (±14 points).

## Round 2 rules defaults (rules R8, 2026-09-14): recommendations for the lead

Measured on the R7-tuned catalog with friendly fire on, 8 seeds per row, elimination, 300 s limit.

**1. Make the control point the default rule.** (Recommended; **the lead agreed 2026-09-14**.) "Coordination beats individuals" (T1): Anvil &
Hammer (3 + 2 tanks, split) vs Individuals (5 tanks):

| Rules | Normal bases, AH as Green / as Rust | Swapped bases, AH as Green / as Rust | Coordinated wins |
|---|---|---|---|
| Elimination only | 0 : 8 / 0 : 8 | 0 : 8 / 0 : 8 | **0 of 32** |
| + `--control` | 4 : 4 / 6 : 2 | 0 : 8 / 5 : 3 | **15 of 32 (47%)** |

Under recharging shields the concentrated brawl wins every time; a reason to hold ground restores the split
doctrine to parity, as in round 1 (10 : 10). Command/skirmish owns the flag (`--control`).

**2. Drop finite ammo on direct-fire guns; keep the mortar's 24 rounds.** (Applied; **the lead: "ok for now"**.)
Armor vs Balanced CPU armies (1000 points), both bases, both colors:

| Ammo | Armor wins | RESUPPLY share of brain time | Avg length |
|---|---|---|---|
| Finite (cannon 45, autocannon 300, MG 600, mortar 24) | 26 of 32 | 1–6% | 122 s |
| Unlimited everywhere (`--tune=…ammo=-1`) | 25 of 32 | 0–4% | 112 s |

No outcome changed, and resupply trips were mostly base repair. In squad matches without respawns a load lasts
the fight, so ammo added HUD readouts and "out of ammo" messages, not decisions. The mortar keeps its load (a
battery that shells all match long is the one place a limit matters), and base repair stays (it drives the
RESUPPLY option most of the time). Reversible: put `"ammo"` back on a weapon.

**Also seen:** the Armor archetype beats Balanced 26 : 6. Balanced spends half its army on artillery and scouts,
which SPOT and BOMBARD instead of fighting (38% + 19% of their time). For the army stream's CPU presets and
the ai stream's scouts.

## Stretch: the Burner and arena hazards (rules, 2026-09-14)

**Burner** (`burner`, unlock tier 2, flamethrower, CPU archetype `brawl`). `tools/matchup_matrix.py --focus burner` rows (12 per pair):

| Burner values | vs scout | vs tank | vs IFV | vs artillery | vs Lancer |
|---|---|---|---|---|---|
| 160 pts, 12 m/s, front armor 7, hull 260, 20 dps | 100% | 100% | 100% | 100% | 100% ❌ |
| **220 pts, 10 m/s, front armor 4, hull 220, 20 dps (applied)** | 100% | 0% | **67%** | **83%** | 0% |
| same + 14 dps | 100% | 0% | 33% | 83% | 0% |

The scout column is the scout brain again (it never fights). Burner = anti-light/anti-artillery brawler that
tanks and Lancers stop.

**Hazards:** `arenas/furnace.json` = foundry + six fire pits (30 dps, shields ×1.5, armor ignored, either team).
Not measured in series yet: the brains don't know about hazards (`Arena.hazards()` exists for the ai stream), and
the pits are invisible until art makes `prop.fire_pit`, so furnace isn't a default.

## Results so far

### G5 turrets (5 cannons each, Anvil & Hammer vs Individuals, 40 matches)
Idle guns 83–87% → 61–68%; first shot 7.3 → 6.2 s.

### G7 lasers vs cannons (Individuals doctrines, counterbalanced)
| Rules | Laser wins |
|---|---|
| No shields (G7 as first built) | 14/60 (23%) |
| Shields, laser shield multiplier 1.5 | 29/40 (72%) |
| Shields, multiplier **1.25** (current) | 14/24 (58%) ✅ within 35–65% |

### G6 shields and the coordination result (T1)
Anvil & Hammer (coordinated) vs Individuals, 20–24 matches per row:

| Rules | Coordinated wins |
|---|---|
| After G5 | 60% |
| After G7 (ammo 30) | 46% |
| G6 shields, first cut | 8% |
| + ammo 45 / faster resupply / repair 6 | 10% (RESUPPLY time 26% → 5–10%) |
| + RECHARGE instead of retreating home | 10% |
| + directional shields | 0–10% |
| `--tune=tank.max_shield=0` (hull 300) | 31% |
| `--tune=tank.max_shield=0,tank.max_health=400` | 31% |
| Individuals mirror (fairness control) | 45–55% ✅ |

Reading: recharging shields reward concentrated, sustained aggression, and the split/holding doctrine
lost its edge. This is the top question for the lead (streams/archive/round1/gameplay.md Status).

### Directive set 2: army archetypes (E3 at army level)
Five seeded CPU archetypes at 1000 points (`Army.ARCHETYPES`), every pairing 16 matches (4 each: normal and
swapped bases, each side as Green and as Rust). Round robin #1 (commit d917809):

| Pairing | Result |
|---|---|
| armor vs balanced | 6 : 10 |
| armor vs recon_strike | 16 : 0 |
| armor vs siege | 6 : 10 |
| armor vs swarm | 16 : 0 |
| balanced vs recon_strike | 14 : 2 |
| balanced vs siege | 2 : 14 |
| balanced vs swarm | 14 : 2 |
| recon_strike vs siege | 1 : 15 |
| recon_strike vs swarm | 13 : 3 |
| siege vs swarm | 13 : 3 |

Overall: **siege 81%**, armor 69%, balanced 62%, recon_strike 25%, swarm 12%. ❌ Siege dominates; scout-heavy
armies aren't viable. Mechanisms: two mortars out-shell anything that has to walk into range, and scouts only
spotted (they add nothing to tanks, whose 75 m sight already covers a 70 m gun).

Changes for round robin #2: a counter triangle (scouts hunt artillery, SCOUT_HUNT), artillery 180 → 220
points, and direct fire now needs the target seen by the team (a fog hole; also a prerequisite for making
spotting matter to guns). Round robin #2 (commit 10f33e3, mortar still 90):

| Pairing | #1 | #2 |
|---|---|---|
| armor vs balanced | 6 : 10 | 7 : 9 |
| armor vs recon_strike | 16 : 0 | 16 : 0 |
| armor vs siege | 6 : 10 | 4 : 12 |
| armor vs swarm | 16 : 0 | 16 : 0 |
| balanced vs recon_strike | 14 : 2 | 15 : 1 |
| balanced vs siege | 2 : 14 | 4 : 12 |
| balanced vs swarm | 14 : 2 | 16 : 0 |
| recon_strike vs siege | 1 : 15 | 3 : 13 |
| recon_strike vs swarm | 13 : 3 | 14 : 2 |
| siege vs swarm | 13 : 3 | 16 : 0 |

Overall #2: siege 83%, balanced 69%, armor 67%, recon_strike 28%, swarm 3%. The scout counter didn't move
anything (the scout armies lose to tank armies, which have no artillery to hunt). Then **mortar 90 → 70**
(probe, 16 each): siege vs armor **10 : 6**, siege vs balanced **10 : 6** (from 12 : 4). Applied (049f5d5).

Near-sighted tanks probe (`--tune=tank.sight_radius=60`, below the cannon's 70 m, so spotters extend a tank's
reach): recon_strike vs armor **0 : 16**, balanced vs armor 9 : 7 (vs 9 : 7 without). No help for scouts.

Where E3 stands: siege, balanced, and armor are within reach of each other; scout-heavy armies are not
viable (recon_strike ~28%, swarm ~3%). Scouts earn their points only next to artillery. Open design
question for the lead in the Status.

### Stretch: control point (`--control`)
| Series | Result |
|---|---|
| Anvil & Hammer vs Individuals, with `--control` (normal + swapped, 20) | **10 : 10** (without control: ~2 : 18) |
| Individuals mirror, with `--control` (16) | 5 : 11 (small sample; watch for a Rust bias) |

Loser kills rose to 0.9–1.9 (from ~0.6–1.0). A reason to hold ground restores what shields took from the
holding doctrine. Recommendation to the lead: make the control point the default skirmish mode.

### Stretch: the flamethrower (T3 revisited)
T3 in tank_brain.md (flamers 0–6%) predates the 2026-09-13 rebalance. Re-measured (flame_rush vs Individuals,
normal + swapped bases, both team identities):

| Build / tune | Flamer wins |
|---|---|
| Pre-overnight commit `ee20791` (as Green, 10) | 9/10: flamers have dominated since the rebalance |
| Current, 45 dps (36) | **36/36** |
| shield multiplier 1.0 / 0.7 (20 each) | 20/20, 18/20 |
| 32 dps + shield 1.25 (20) | 18/20 |
| 4 flamers vs 5 cannons (20) | 20/20 |
| **20 dps** (20) | **10/20** ✅ applied |

Mechanism: cannons fire at full rate with ~90% accuracy, but through front shields and front armor a shell
does ~13 effective damage (≈5 dps per tank); a charge crosses the 50 m between gun range and flame range in
~5.5 s. At 20 dps a flamer still out-damages a cannon ~4× once it arrives, so it keeps its niche (close
fights, cover, anti-shield ×1.5) without winning every open-field rush.

### Stretch: CPU commander
v1 (hold in even fights): Individuals + commander vs Individuals **2 : 30** (both team identities, both
bases). Holding still under recharging shields loses. v2 (assault unless clearly weaker): **11 : 9** (20).
Parity, not yet an advantage, so it stays opt-in (`--commander`). Ideas: bound/flank with two squads, focus
one target per squad, pull back to recharge as a squad.

## Recommendation: chassis + loadout (MechWarrior-lite), not fixed classes

**Built this way on 2026-09-15.** A few chassis with distinct jobs, each with 1 weapon hardpoint and
1–2 component slots, drawing from short lists with costs:

- **Chassis carry the role** (speed, sight, size, survivability): scout (eyes), tank (workhorse),
  artillery (indirect fire). A role you can read from the silhouette is what makes combined arms
  legible to a player on a phone.
- **Weapons carry the tactics** (range band, ammo vs heat, anti-shield vs anti-hull): cannon, laser,
  machine gun, mortar, flamethrower. Hardpoints restrict nonsense (no mortar scouts).
- **Components carry the tuning** (a laser tank needs a heat sink, a cannon tank an ammo rack): cheap,
  few, additive stat modifiers, so balance stays a table of numbers.

Why not full MechWarrior (many hardpoints, free-form)? Balance work explodes combinatorially, and the
brain would need per-build tactics. Why not fixed classes? The garage would have nothing to decide.
The middle path keeps both the garage interesting and the balance surface small: 3 chassis × a few
weapons × 4 components. Next chassis candidates: a heavy tank with 2 hardpoints; an engineer that
repairs in the field (a counter to base-only repair).

## How to run the experiments

```bash
# lasers vs cannons, counterbalanced
python3 tools/match_series.py --godot .tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --runs 10 --jobs 2 \
  --score-limit 0 --time-limit 300 --extra="--elimination --green-doctrine=res://doctrines/individuals_laser.json --rust-doctrine=res://doctrines/individuals.json"
# ... then --swap-bases, then the two doctrines swapped
# a number without editing code
--extra="... --tune=laser.shield_multiplier=1.25,tank.max_shield=100"
# budgeted CPU armies
--extra="--elimination --green-doctrine=cpu:siege --rust-doctrine=cpu:swarm --budget=1000"
```
`match_series.py` prints wins, pace (first shot/kill), loser kills, idle guns, and what the brains spent
their time doing (`stats.options`).
