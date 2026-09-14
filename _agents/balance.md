# Balance: measurements, tuning values, and the army design

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
| Weapons (damage, range, reload, spread, ammo, heat, armor table, shield multiplier, cost) | `game/combat/weapons.gd` `PROFILES` | cannon 34, 70 m, 2.5 s, 45 shells, shield ×0.8; laser 9/0.5 s, 55 m, 12 heat, shield ×1.25, +20 pts; machine gun 4/0.2 s, 45 m, shield ×0.6; mortar 90 in 8 m, 35–160 m, 4.5 s, 24 rounds; flamethrower 45/s, 20 m, shield ×1.5 |
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
lost its edge. This is the top question for the lead (streams/gameplay.md Status).

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
spotting matter to guns). Round robin #2 results: appended below when it finishes.

### Stretch: control point (`--control`)
| Series | Result |
|---|---|
| Anvil & Hammer vs Individuals, with `--control` (normal + swapped, 20) | **10 : 10** (without control: ~2 : 18) |
| Individuals mirror, with `--control` (16) | 5 : 11 (small sample; watch for a Rust bias) |

Loser kills rose to 0.9–1.9 (from ~0.6–1.0). A reason to hold ground restores what shields took from the
holding doctrine. Recommendation to the lead: make the control point the default skirmish mode.

### Stretch: CPU commander
v1 (hold in even fights): Individuals + commander vs Individuals **2 : 30** (both team identities, both
bases). Holding still under recharging shields loses. v2 (assault unless clearly weaker) is opt-in
(`--commander`) and not yet measured.

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
