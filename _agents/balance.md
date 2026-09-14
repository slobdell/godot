# Balance: measurements, tuning values, and the army design

> **Round 2 note (2026-09-15):** the chassis + loadout recommendation below was superseded by the lead's fixed unit types ([game_design.md](game_design.md)). Measurements stay as history; the rules stream adds the unit-vs-unit matchup matrix, and the army stream adds the economy section.

> Started 2026-09-15 by the gameplay stream's overnight run. Everything here was measured with
> `tools/match_series.py` (headless, seeded, `--elimination`, 300 s limit). Small samples (10–24 per
> row) are marked; treat anything within ±15 points of 50% as "not significantly different".
> Rules of thumb: always run swapped bases (`--swap-bases`) and swap which team plays which side
> (team identity). Use `--tune=unit_or_weapon.stat=value` to try a number without editing code.

## Where the tuning values live

| What | File | Key values (2026-09-15) |
|---|---|---|
| Unit stats (hull, shield, speed, sight, heat, size, hardpoints, component slots, cost) | `game/units/units.gd` `PROFILES` | tank 300+150, 9 m/s, 75 m sight, 200 pts; scout 140+80, 14 m/s, 110 m, 110 pts; artillery 200+80, 6.5 m/s, 60 m, 220 pts |
| Components | `game/units/units.gd` `COMPONENTS` | heat sink +40 cap +6/s (30); ammo rack +50% ammo (25); shield booster +60 (40); armor plating +80 hull −1 m/s (35) |
| Weapons (damage, range, reload, spread, ammo, heat, armor table, shield multiplier, cost) | `game/combat/weapons.gd` `PROFILES` | cannon 34, 70 m, 2.5 s, 45 shells, shield ×0.8; laser 9/0.5 s, 55 m, 12 heat, shield ×1.25, +20 pts; machine gun 4/0.2 s, 45 m, shield ×0.6; mortar 70 in 8 m, 35–160 m, 4.5 s, 24 rounds; flamethrower 20/s, 20 m, shield ×1.5 |
| Armor facing, directional shields | `game/combat/armor.gd` | hull front 0.5 / side 1 / rear 1.5 (per weapon table); shield front 0.7 / side 1 / rear 1.4 |
| Base service, arena, sensing | `game/match/match.gd` | resupply 1 shell/s and repair 6 HP/s within 30 m of your base; intel every 6 ticks, 12 s memory |
| Brain weights | `game/ai/tank_brain.gd` | ORDER_WEIGHT 0.95, SCOUT_STANDOFF 85 m, SCOUT_HUNT 1.6 (floor 0.8), ARTILLERY_SAFE_DISTANCE 80 m, RECHARGED 0.6 |
| Budget | `Units.DEFAULT_BUDGET` | 1000 |

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

## Economy (army stream; measured 2026-09-15)

> Owned by the army stream. Numbers live in `game/progression/progression.gd` (`BUDGET_TIERS`,
> `UNIT_UNLOCK_CREDITS`, `AWARD`) and each unit's catalog `unlock_tier`. Re-measure with `make economy-sim`
> after changing any of them (or when rules adds units or changes costs).

**Principles** (game_design.md "Progression", vision.md): credits come only from playing; nothing is ever sold.
Unlocks add options, not power: both armies always fight at the same budget tier, and units are sidegrades.
No grind walls: an average player unlocks everything in an evening or two, a weak player isn't locked out, and a
strong player gets there a little faster.

**What a match pays** (`Progression.credits_for`):

| Outcome | Base | Per enemy unit destroyed | Tier bonus | Minimum length |
|---|---|---|---|---|
| Win | 100 | +6 | +25% of base per tier | 60 s simulated (shorter pays 0) |
| Draw | 30 | +6 | same | same |
| Loss | 10 | +6 | same | same |

Why a loss pays so little on its own: the first numbers (loss 15, 20 s minimum) made a thrown match worth
**45 credits/minute** against **39** for a real 3-minute win with 3 kills. A regression test
(`test_throwing_matches_is_never_faster_than_trying`) now holds the order. A loss still pays for the damage done,
so a close fight earns something. Each match pays once (`last_award` holds its key).

**What unlocks cost:** budget tiers are bought in order; units can be bought any time, so the player chooses between
a new unit type and a bigger army.

| Tier | Name | Budget (both sides) | Unlock | ≈ units per side |
|---|---|---|---|---|
| 0 | Scrapyard | 800 | starter | 5 |
| 1 | Pit | 1,200 | 400 | 8 |
| 2 | Arena | 1,700 | 900 | 11 |
| 3 | Colosseum | 2,400 | 1,600 | 16 |
| 4 | Grand Circus | 3,200 | 2,500 | 21 (25 max) |

Units: `unlock_tier` 0 = starter (scout, IFV, tank); 1 = 300 credits (artillery); 2 = 600 (Lancer); 3 = 1,000;
4 = 1,500 (future units). Total to unlock everything today: 6,300 credits.

**Simulated players** (`make economy-sim`, 400 players per row; model and assumptions in
`tests/garage/economy_sim.gd`: a win destroys ~90% of the enemy, a loss ~35%; matches last 2.5 + 0.9 × tier
minutes; players fight at their top tier and buy the cheapest unlock first). Matches (hours) to reach each milestone:

| Win rate | first unlock | every unit | tier 1 | tier 2 | tier 3 | top tier | everything |
|---|---|---|---|---|---|---|---|
| 35% | 6 (0.3 h) | 21 (1.0 h) | 13 (0.5 h) | 33 (1.7 h) | 50 (2.9 h) | 70 (4.6 h) | 70 (4.6 h) |
| 50% | 5 (0.2 h) | 17 (0.8 h) | 10 (0.4 h) | 26 (1.3 h) | 39 (2.3 h) | 55 (3.7 h) | 55 (3.7 h) |
| 65% | 4 (0.2 h) | 14 (0.7 h) | 8 (0.4 h) | 22 (1.1 h) | 33 (1.9 h) | 47 (3.1 h) | 47 (3.1 h) |

Typical pay: tier 0 win 130 / loss 22; tier 2 win 210 / loss 39; tier 4 win 314 / loss 62.

**Reading:** the first unlock comes within ~5 matches (a quick first reward), every unit type within ~1 hour
(counters are the game, so they shouldn't wait), and the biggest armies after 3–5 hours. A 65% player finishes
~1.5 hours before a 35% player: skill is rewarded without walling anyone out. **Open for the lead:** this is
deliberately short for a paid die-hard game where unlocks are options, not power. As units are added at tiers 3–4
the path lengthens by ~1,000–1,500 credits each (≈ 5–7 matches). If the lead wants a longer arc, raise tier prices
first (the army gets bigger, not stronger), and re-run the sim.
