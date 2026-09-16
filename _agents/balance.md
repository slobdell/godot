# Balance: measurements, tuning values, and the army design

> **Round 3 (2026-09-15, combat stream):** weapons, weak spots, driving, deploy, and the matchup search are in
> *Round 3: weapons rebuilt and matrix #5* below; the round-2 sections stay as history.

> **Round 2 note (2026-09-15):** the chassis + loadout recommendation below was superseded by the lead's fixed unit types ([game_design.md](game_design.md)). Measurements stay as history; the rules stream adds the unit-vs-unit matchup matrix, and the army stream adds the economy section.

> Started 2026-09-15 by the gameplay stream's overnight run. Everything here was measured with
> `tools/match_series.py` (headless, seeded, `--elimination`, 300 s limit). Small samples (10–24 per
> row) are marked; treat anything within ±15 points of 50% as "not significantly different".
> Rules of thumb: always run swapped bases (`--swap-bases`) and swap which team plays which side
> (team identity). Use `--tune=unit_or_weapon.stat=value` to try a number without editing code.

## Where the tuning values live

| What | File | Key values (round 2, rules stream; **round 3 changes: see *Round 3* below**) |
|---|---|---|
| Unit types (cost, tier, hull, shield, speed, turn rates, sight, weapon, mount, fire arc, muzzle height, armor thickness) | `game/units/units.gd` `PROFILES` | scout 110 pts, 140+80, 14 m/s, fixed MG ±8°, armor 2/1/1; tank 200, 300+150, 9 m/s, turret 50°/s, armor 8/4/2; IFV 150, 220+100, 11 m/s, turret 180°/s, armor 5/3/2; artillery 220, 200+80, 6.5 m/s, armor 3/2/1.5; Lancer 200, 200+120, 8.5 m/s, turret 80°/s, heat 100 (−12/s), armor 4/3/2 |
| Weapons (damage, range, reload, spread, ammo, heat, penetration, splash, shield multiplier) | `game/combat/weapons.gd` `PROFILES` | cannon 34, 70 m, 2.5 s, pen 10; autocannon 9, 60 m, 0.35 s, pen 4; laser 9/0.5 s, 80 m, 12 heat, pen 12, shield ×1.25; machine gun 4/0.2 s, 45 m, pen 3; mortar 70 in 8 m, 35–160 m, 4.5 s, pen 10; flamethrower 20/s, 20 m, pen 12 |
| Penetration vs armor, directional shields | `game/combat/armor.gd` | hull multiplier = clamp(0.5·log2(1.6·pen/armor), 0.05, 1.5) on the face hit (arcs hit "side"); shield front 0.7 / side 1 / rear 1.4 |
| Base service, arena, sensing, friendly fire, spawns | `game/match/match.gd` | resupply 1 shell/s and repair 6 HP/s within 30 m of your base; intel every 6 ticks, 12 s memory; blind artillery scatter ×3; friendly fire always on; 9 × 3 spawn grid |
| Arena layouts | `arenas/*.json` (`Arena`) | `foundry` (round 1's map), `scrapyard` (dense cover, three lanes) |
| Brain weights | `game/ai/tank_brain.gd` (ai stream) | ORDER_WEIGHT 0.95, SCOUT_STANDOFF 85 m, SCOUT_HUNT 1.6 (floor 0.8), ARTILLERY_SAFE_DISTANCE 80 m, RECHARGED 0.6 |
| Budget | `Units.DEFAULT_BUDGET` | 1000 (garage/progression); **round 4: `Units.BASELINE_BUDGET` 5200** for full-scale faction battles |
| Suppression (round 4, L2) | `game/combat/threat_field.gd`, `Weapons "suppression"`, `Match.SUPPRESSION_*`, `Tank.PINNED_SUPPRESSION` | see *Round 4: suppression and effective fire* |

Try a number without editing code: `--tune=tank.turret_turn_rate_deg=70,ifv.armor.front=4,autocannon.penetration=5`
(match runner, `tools/match_series.py --extra=`, `make matchups TUNE=`).

## Round 4: suppression and effective fire (combat X1, contract L2)

**What it is.** Every round that resolves stamps the ground it swept into a coarse decaying grid, one per team
(`ThreatField`, `game/combat/threat_field.gd`): 6 m cells, a 1 s half-life, a *segment* for direct fire (muzzle to
wherever the round stopped), a *disc* for arcs and flame cones. Units standing in that fire get suppressed, which
costs them accuracy and turret tracking. Everything the brains and the drills need is two queries:
`Match.threat_field(team)` and `Match.is_beaten_zone(team, from, to)`.

| Number | Where | Value and why |
|---|---|---|
| Suppression per round | `Weapons.PROFILES[*]["suppression"]` | MG 0.10 (×10/s = **1.0/s**), 25 mm 0.35 (×2.2/s = 0.78/s), cannon 1.2 (×0.2/s = 0.24/s), laser 0.15 (0.3/s), mortar 3.0 over a 9 m splash, flame 1.5 **per second**. The machine gun is the best suppressor per second and can still barely scratch a tank's front: volume, not damage |
| Half-life | `ThreatField.HALF_LIFE_SECONDS` | 1.0 s. A steady source settles at rate ÷ 0.693, so one machine gun holds a lane at ~1.4 |
| Full suppression | `Match.SUPPRESSION_FULL_DENSITY` | 3.0, i.e. about two machine guns or a mortar burst on the same spot |
| Beaten zone | `Match.BEATEN_ZONE_DENSITY` | 1.0, so **one** crew streaming down a lane is enough to make crossing it a bad idea (the lead's "cut off an avenue") |
| Pinned | `Tank.PINNED_SUPPRESSION` | 0.6. The accuracy cost scales in smoothly below it: the threshold is a label for decisions, not a cliff |
| Build / fade | `Tank.SUPPRESSION_RISE_PER_SECOND` 0.6, `..._RECOVER_...` 0.3 | ~1.7 s of heavy fire to go heads-down, ~3.3 s of quiet to come back |
| Accuracy | `Match.SUPPRESSION_SPREAD_FACTOR` | 2.0: a fully suppressed tank's 0.8° becomes 2.4°. It still shoots, it just stops hitting anything far away (`Match.shot_spread`, which also carries the older `MOVING_SPREAD_FACTOR`) |
| Turret tracking | `Tank.SUPPRESSION_TRACKING_PENALTY` | 0.5: heads down means the gunner loses the target, which is why suppression **plus a flank** works |
| Deploying | `Tank._deploy_step` | A pinned crew can't get a battery's outriggers down |

**Deliberate simplifications**
- **Only the enemy's rounds suppress you.** A team is never scared off its own base of fire, so support-by-fire
  doesn't need shift-fire discipline to be usable. Friendly-fire *damage* is unchanged (it is still real).
- **Suppression arrives when the round resolves**, not while it flies: a shell in the air has not frightened anyone
  yet, and a shell that hits a wall at 20 m marks 20 m of lane, not its full 70 m range.
- **Decisions stay with the brains.** The rules only make fire *ineffective*; breaking contact, going to cover and
  refusing to cross a lane belong to ai and doctrine, which read the field.
- Cost: the field decays 2 × 1600 float cells every 3 ticks (~0.05 ms/tick). If that shows up at 30 a side, the fix
  is a global decay scale instead of a full pass (see X5's numbers).

**The sim baseline moved on purpose** with L2: suppression changes shot spread, so every seeded match diverges, and
`Match.state_hash` now includes each unit's suppression. It moved a second time with X2's two corrections (a round
that hits a unit marks that unit's cell, and a hit's suppression scales with the hull fraction it removes):
`glibc-2.43 763efdb242eeb5bf`.

### X2: does suppression actually bite? (measured 2026-09-16, builder0)

Reproduce with `make remote T="test FILTER=combat_suppression_bite"` (every row is a `MEASURE` line) and
`make remote T="suppression-series N=16 GREEN_ARCH=swarm RUST_ARCH=armor"` (suppression on, then every weapon's
`suppression` tuned to 0 as the control).

| Question | Measurement | Verdict |
|---|---|---|
| Does a stream shut a lane? | 1 scout streaming across a lane: density 1.17, `is_beaten_zone` **true**, a crossing IFV loses 4.2 HP and peaks at 0.38 suppression. 3 scouts: route exposure 0.12 → 0.37, 18.9 HP, peaks at **0.70 (pinned)** | Yes, and it scales with crews |
| Does concentrating fire pin? | one machine gun on a tank settles at **0.42**, two at **0.82** (pin at 0.60) | Yes, exactly as designed: one crew rattles, two pin |
| Is pinning worth doing? | a tank at 60 m hits **13/13** calm and **5/13** pinned; a 90° turret swing takes **105 ticks** calm and **208** pinned | Yes: pin, then flank |
| Is a machine gun's value volume? | suppression per second: MG **1.00**, 25 mm 0.78, mortar 0.67, laser 0.30, cannon 0.24 — while the MG still does ×0.05 damage through a tank's front | Yes |
| **Does it change match outcomes today?** | swarm vs armor, 16 seeds, 1000 pts: **Rust 16-0 with suppression and 16-0 without**. Mean suppression per living unit **0.03**, pinned **0.7%** of unit-samples. The only difference is pace: matches run 77.7 s instead of 69.6 s (+12%), because degraded accuracy drags fights out | **No — and that is the finding** |

**Why not:** the scouts that carry the machine guns spend **84% of their time on SPOT** and almost none firing, and no
brain or drill ever puts fire on a lane to deny it. The mechanics are ready and measurable; the payoff is a
*decision*, which belongs to ai (suppress on purpose, avoid beaten zones) and doctrine (support-by-fire). Requests are
in the combat brief's Status. Until then, leaving the numbers alone is the right call: tuning suppression up to force
an effect through unused mechanics would only distort the matchup matrix.

**Two notes for whoever reads these numbers**
- A hitscan stream aimed at a fixed point is a curtain only a couple of sigma of spread thick (~3 m at 40 m), so one
  crew costs a crossing vehicle a burst, not its life. Thickness comes from *more crews on nearby lanes*, which is why
  three cost 4.5× the damage of one.
- The `suppression=0` control still reports ~0.01 mean suppression, because a hit also rattles a crew in proportion to
  the hull fraction it removes (`Match.SUPPRESSION_PER_HULL_FRACTION`), independent of the weapon's suppression
  weight. That is deliberate: being hit hard is suppressive whatever hit you.
- New match stats for this: `suppression_samples`, `suppression_total` and `pinned_samples` per team (sampled over
  living units every `SUPPRESSION_SAMPLE_TICKS`), printed by `tools/match_series.py`.

### X3: heavies shielding the fragile (measured 2026-09-16, builder0)

**No guard buff exists, and none is needed.** A shell or beam stops at the first hull it meets, and armor facing
then decides what that costs, so interposing is already the strongest defensive play in the game. Reproduce with
`make remote T="test FILTER=combat_screening"`.

| Setup (enemy dozer firing 4 cannon shells at a Lancer from 58 m) | Lancer loses | Screen loses |
|---|---|---|
| Lancer alone | **320 (destroyed)** | — |
| A friendly dozer on the line, 8 m in front | **0 (survives)** | 405 of its 450 |
| That dozer 10 m off the line | **320 (destroyed)** | 0 |
| A battery lobbing instead of a dozer firing | **320 (destroyed)** | 67 splash |

Why the trade is worth making, with numbers rather than a rule: the same cannon shell is ×0.50 against a dozer's
8 mm front and ×1.21 against a Lancer's 3 mm, and the dozer has 450 hull + shield against the Lancer's 320. That is
**2.8 shells to kill the screen against 0.8 to kill what it screens** — a heavy in the right place is worth roughly
three and a half times its own body in absorbed fire.

**What a screen cannot do**, so the drills don't over-trust it: it does not stop arcs (a mortar lands behind it), it
does not stop flames (the cone touches everything in it), it only covers its own width (10 m off the line is worth
nothing), and **a wreck does not screen** — `Tank._set_alive(false)` disables the collision shape, so shells fly
through it. Turning that last one around is the stream's stretch item (*wrecks as cover*).

**New query (C4):** `Match.screen_for(unit, from_point) -> Tank` returns the friendly hull blocking the line from
`from_point` to `unit` at rounds' flight height, or null. It reports the geometry the physics already uses and grants
nothing; ai and doctrine use it to know whether a fragile unit is covered, or whether a heavy is doing its job.

## Round 4: army size and factions (combat X1, contract L3)

Every catalog entry carries a `faction` (`Units.FACTIONS`: condemned, gangs, law, syndicate; missing means
`condemned`, so every round-3 army and doctrine still loads). `Units.roster(faction)`,
`Units.roster_average_cost(faction)` and `Army.typical_size(faction, budget)` are the L3 queries;
`--green-faction=` / `--rust-faction=` on the match runner build a faction army.

| Number | Value and why |
|---|---|
| `Units.BASELINE_BUDGET` | 5200: the Condemned average 183 points a vehicle, so a full-scale battle is **28 a side** — the lead's "baseline of 30 units per side". `DEFAULT_BUDGET` stays 1000 and the garage keeps its own `Progression.BUDGET_TIERS` while that stream is paused |
| `Army.MAX_ARMY_UNITS` | 45 vehicles a side, which is what the spawn grid holds |
| `Match.SPAWN_SLOTS` | 27 → **52** (13 columns 11 m apart out to ±66 m, 4 rows 8 m apart from `BASE_Z`). The front row is still at `BASE_Z`, so spawn distance and pace are unchanged; `tools/make_arenas.py` regenerates every layout's spawn list |
| Spawn jitter | now clamped along z too (`SPAWN_JITTER_MAX_Z` 1.2 m), or a jittered hull in row 2 overlapped one in row 1 |

### X4: the three new rosters (2026-09-16)

15 vehicles and 11 weapons, all data. **Nothing here is a faction-wide bonus**: a faction is a set of costs and
stats out of one shared mechanics vocabulary, and its army size falls out of the costs
(`Units.roster_average_cost` → `Army.typical_size`). Measured at `BASELINE_BUDGET` (5200):

| Faction | Avg cost | Vehicles a side | Identity, in mechanics |
|---|---|---|---|
| **Road gangs** | 131 | **39** | **No shields anywhere.** Cheapest and fastest, thin armor, short reach. The `twin_mg` is the best suppressor per second in the game (1.26/s); the War Rig is the biggest hull in the game (3.0 × 5.6 m) and turns in 12 m; the Resupply Tanker mends hulls within 18 m, which is how a shieldless faction gets hit points back |
| **The Condemned** | 183 | **28** | Unchanged from round 3: the mid-point, the lead's "baseline of 30 a side" |
| **The Law** | 215 | **24** | Sight (a 125 m scout) and suppression. The Sonic Emitter is 18 damage/s and **4.0 suppression/s**; gas rockets are 55 damage and **5.0 suppression** over a 14 m burst. Their guns are reliable rather than fierce; the Retired APC has a 9 mm front and cannot chase anything |
| **The Syndicate** | 340 | **15** | Energy and hover. Biggest shields, no ammunition, everything heat-limited: the railgun is 420 damage and 16 penetration at 110 m, twice, then it waits. Guided missiles have 0.8 m of scatter at any range **when a teammate is looking**, and the usual ×3 blind penalty wastes the salvo when nobody is |

**Two new mechanics** (the only code the rosters needed):
- **`hover`** (`TankMotion.step_in_place`): swings to face at `hull_turn_rate_deg` at any speed, like tracks, because
  nothing needs traction to do it — but nothing grips the ground either, so momentum carries like wheels. Measured: a
  Skimmer at full speed through a hard turn travels **22° off its own nose**, where a dozer travels exactly where it
  points and a wheeled Rat Rod needs a multi-point shuffle (28° in half a second against the Skimmer's 80°).
- **Field repair** (`Units "repair_radius_m"` / `"repair_hp_per_second"`, `Match.repair_rate_for`): a gun truck beside
  a Resupply Tanker mends 60 → 110 hp over 10 s; one 50 m away mends nothing. Repairs need
  `REPAIR_QUIET_SECONDS` (3 s) since the last hit — it used to piggyback on the shield recharge delay, which is 0
  for a faction with no shields, so a gang truck mended itself while being shot.

**Design calls worth knowing**
- **Every rear stays at or below 2.0 mm.** "Everything hurts from behind" is a rule of the game, not a unit's choice
  (`test_combat_mechanics`), so the Syndicate's "no strong face" is front and side armor, never a thick back.
- **The Condemned scout's `good_vs` lost "lancer"**, which round 3 measured at 0%. game_design.md rules those claims
  must be real in the mechanics. Suppression (L2) is the mechanic that could earn it back — a machine gun is the best
  suppressor in the game, and a suppressed Lancer tracks at half speed and scatters ×3 — but only once ai suppresses
  on purpose (X2). Put it back when the matrix shows it.
- **The Lancer role now appears in two factions**, as `lancer` (Condemned) and `syn_lancer` (Syndicate). That is what
  *Factions* asks for: the role is shared, the vehicle is not. Flagged for the lead.
- **Plain `cpu` armies stay Condemned.** A faction is only chosen through `--green-faction=` / `--rust-faction=`, so
  every round-3 skirmish, garage and match-runner opponent is unchanged.
- **The garage offers the default faction only** (`ArmyCatalog.from_game`). Its screens, presets and unlock tiers are
  written for one roster and that stream is paused: a compatibility fix, not a design.
- **Faction art is not wired up.** `game/theme/factions/` is 47 MB and excluded from the exports, so the new vehicles
  play as themselves and *look* like the Condemned through the C6 fallback. Shipping the models would take the web
  pack from 0.8 MB to ~48 MB — a cross-stream call. See the combat brief's *Questions for the lead*.

### X5: what the simulation costs at scale (measured 2026-09-16, builder0)

`make remote T="scale-bench TIME=40"` runs a headless match at N vehicles a side and reads `speedup` (simulated
seconds per real second) out of `MATCH_RESULT`, so **ms/tick = 1000 / (60 × speedup)**. Run without brains for the
simulation's own cost and with them for the whole picture; the difference is ai's. 60 fps is a **16.7 ms** budget for
everything including rendering.

| A side (units) | Sim only, before | Sim only, **after** | With brains, before | With brains, **after** |
|---|---|---|---|---|
| 25 (50) | 4.39 ms | **3.03** | 12.82 ms | **10.42** |
| 40 (80) | 7.94 | **5.05** | 23.81 | **18.52** |
| 60 (120) | 15.15 | **7.58** | 41.67 | **33.33** |
| 100 (200) | 33.33 | **13.89** | 83.33 | **55.56** |

**Two fixes, 30–58% off the simulation:**
1. `Match._sorted_tanks()` re-sorted every tank by name, through a GDScript lambda comparator, on **every call** —
   a dozen call sites, several of them every tick. It is now built at most once per tick (keyed on the tick and the
   child count; `remove_player` invalidates it by hand, because a freed tank doesn't change the child count until
   the frame ends). This was the single most expensive thing in the simulation at scale.
2. The "idle guns" readout (`gun_ready_samples` / `gun_idle_samples`) paid a line-of-sight raycast for every
   viewer-enemy pair in weapon range on **every** intel pass — the same order of work as team vision itself, for a
   statistic. Sampled every 10th pass now (`GUN_READY_EVERY_INTELS`); the ratio it reports is unchanged.

The sim baseline did not move, which is the proof that neither changed the simulation.

**Where that leaves the lead's 30 a side (60 units):** about **3.9 ms of simulation** and **~13 ms with brains**,
headless on builder0. The simulation fits comfortably; the frame does not, once rendering is added. The remaining
cost is brain time, which is ai's stream (their target is ≤ 4 ms per tick at 60 units). Caveats worth keeping: this
is builder0, which runs up to three agents' heavy jobs at once, and it is headless, so it excludes rendering
entirely. The laptop's integrated GPU is the real judge.

**A rendering ceiling found while screenshotting a 31-vs-35 battle** (`make faction-shots`): Godot logs
`Too many instances using shader instance variables … Maximum items supported by this hardware is: 4096`. Each
vehicle's visual slots consume shader instance uniforms, and a full-scale battle exhausts the pool. It is an art /
theme problem, not a simulation one, and no stream owns `game/theme/**` this round — flagged in the combat brief.

**Arena and spawns:** the spawn grid holds 52 a side (13 columns 11 m apart out to ±66 m, 4 rows 8 m apart from
`BASE_Z`), and the existing 240 × 240 m arenas are not crowded at 35 a side — the screenshots show both armies
converged on the control point with most of the map empty. No arena needed to grow.

### X6: faction versus faction (measured 2026-09-16, builder0)

`make remote T="faction-matrix SEEDS=5 TIME=150"` (`tools/faction_matrix.py`): every pair at 5200 points,
elimination, control point on, each pairing **counterbalanced** — the same seeds played from both colours, which
cancels the side advantage and team identity in one pass. 60 matches, ~25 min.

| Pairing | Win% (first) | Vehicles fielded | Lost | Length | Mean suppression on the loser |
|---|---|---|---|---|---|
| condemned vs syndicate | 70% | 32.6 | 17.9 | 91 s | 0.018 |
| condemned vs law | 60% | 32.6 | 18.0 | 101 s | 0.057 |
| law vs syndicate | 60% | 24.8 | 16.6 | 90 s | 0.026 |
| gangs vs syndicate | 40% | 43.0 | 37.4 | 91 s | 0.019 |
| gangs vs condemned | 20% | 43.0 | 40.8 | 93 s | 0.033 |
| gangs vs law | 10% | 43.0 | 40.7 | 102 s | 0.065 |

Averaged: **Condemned 70%, Law 63%, Syndicate 47%, road gangs 23%.** Match length is **90–102 s** at 24–43 vehicles
a side, which is the right order for a full-scale battle (round 3's 5-a-side fights ran 22–60 s).

**The gangs cannot win, and two attempts to fix it moved nothing.** Both attempts were kept, because both were real
defects rather than tuning:
1. **They had no answer to armor at all.** Their two most numerous vehicles did **2 dps** through any armor — the
   ×0.05 penetration floor — so 43 vehicles were decorative. The Rat Rod now carries game_design.md's
   **explosive spear** (penetration 14, 95 damage, 30 m, 3 s): ×0.74 through a dozer's front. Result: 30% → 40%
   against the Syndicate, no change against the others.
2. **Their assault vehicles were being given a spotter's directive.** `Army.SQUADS` is keyed by *role*, so the
   gangs' spear buggies inherited the Condemned scout's "spotters first" directive and held standoff. `SQUADS` now
   takes faction-qualified keys (`"gangs/scout"` → Spears, assault, aggression 0.95). It worked — their SPOT share
   fell from 84% to 34% and ENGAGE/CONTEST rose — and they still lost 0-6 to the Law.

**Why I stopped there.** Both mechanics the gangs are *designed* around are on other branches: suppression that
changes decisions (ai's SUPPRESS option) and pack tactics (doctrine's drills). The matrix confirms it — mean
suppression on the loser is 0.02–0.08, i.e. essentially none. 43 fragile short-ranged vehicles lose to 24 armored
long-ranged ones when volume buys nothing. Inflating gang stats now would have to be taken back out the moment those
land, which is the lead's own guidance (*"it's also probably not worth trying to balance anything out substantively
yet"*). **Re-run `make faction-matrix` on `main` once combat, doctrine and ai are all merged**; that is the number
that means something.

The Condemned at 70% are the other outlier, but they are the reference roster and the gangs' collapse distorts the
average. Judge that one after the same re-run.

**Open:** `Doctrine.MAX_SQUADS` is 5 (a player-UI number), but 28 vehicles need six squads or more, so faction armies
are validated through `Army.parse_scaled`, which runs `Doctrine.parse` over slices of five squads. Requested of the
doctrine stream: raise `MAX_SQUADS` (or make it a UI-only cap) and this wrapper goes away.

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
_Matrix #6, measured 2026-09-15 on builder0 after CP1 (control's Orders merged) and wheels' multi-point turns (brain a6).
Same catalog as matrix #5._

Cost-equal armies at ~600 points per side (scout 5x = 550, tank 3x = 600, ifv 4x = 600, artillery 3x = 660, lancer 3x = 600, burner 3x = 660); 3 seeds x both bases x both colors = 12 matches per pair, 180 s limit. Cell = the ROW unit's win share against the COLUMN unit (draws count half; a timeout goes to the side with more army value left).

| row beats column | scout | tank | ifv | artillery | lancer | burner |
|---|---|---|---|---|---|---|
| scout | — | 0% | 0% | **100%** | 0% | 0% |
| tank | **100%** | — | **100%** | **100%** | **92%** | **100%** |
| ifv | **100%** | 0% | — | **100%** | 25% | 25% |
| artillery | 0% | 0% | 0% | — | 0% | 0% |
| lancer | **100%** | 8% | **75%** | **100%** | — | **100%** |
| burner | **100%** | 0% | **75%** | **100%** | 0% | — |

| pair | row wins : column wins : draws | avg length | friendly damage / match |
|---|---|---|---|
| scout vs tank | 0 : 12 : 0 | 169 s | 0 |
| scout vs ifv | 0 : 12 : 0 | 57 s | 0 |
| scout vs artillery | 12 : 0 : 0 | 51 s | 0 |
| scout vs lancer | 0 : 12 : 0 | 50 s | 0 |
| scout vs burner | 0 : 12 : 0 | 167 s | 0 |
| tank vs ifv | 12 : 0 : 0 | 35 s | 2 |
| tank vs artillery | 12 : 0 : 0 | 23 s | 0 |
| tank vs lancer | 11 : 1 : 0 | 54 s | 0 |
| tank vs burner | 12 : 0 : 0 | 21 s | 0 |
| ifv vs artillery | 12 : 0 : 0 | 23 s | 9 |
| ifv vs lancer | 3 : 9 : 0 | 59 s | 9 |
| ifv vs burner | 3 : 9 : 0 | 41 s | 1 |
| artillery vs lancer | 0 : 12 : 0 | 32 s | 0 |
| artillery vs burner | 0 : 12 : 0 | 37 s | 0 |
| lancer vs burner | 12 : 0 : 0 | 35 s | 0 |
<!-- MATCHUP MATRIX END -->

_Round 2's matrix #2 (before round 3's weapons) is preserved in git history (`git show 391f22b:_agents/balance.md`)._


Spotted artillery (both sides escorted by one scout, outside the budget and the verdict), same tuned catalog:
artillery vs tank 33%, vs IFV **58%**, vs Lancer 17%. Artillery is a support unit: alone it is blind (60 m sight,
42 m minimum range), so the pure matrix row understates it.

**Where R7 stands:** five designed counters hold at ≥ 65% (IFV > scout, tank > IFV, Lancer > tank, IFV > Lancer,
scout > artillery) and every unit wins a matchup (artillery only with a spotter). Not yet: scouts beat nothing but
artillery (the design wants scout > Lancer and trouble for tanks). That's the scout brain's spotting standoff
(SCOUT_STANDOFF 85 m, SCOUT_FIGHT): re-run `make matchups` when the ai stream's matchup targeting and fixed-mount
strafing land, before touching scout stats. Samples are 12 per pair (±14 points).


## Round 3: weapons rebuilt and matrix #5 (combat X2-X6, 2026-09-15)

**What changed** (numbers in `game/combat/weapons.gd` and `game/units/units.gd`, each with its reason in a comment):

| Area | Round 2 | Round 3 |
|---|---|---|
| Tank cannon | 34 dmg / 2.5 s, 70 m/s | 320 dmg / 5 s, 75 m/s: 2 shells kill a tank from the side or rear, 4 from the front |
| IFV 25 mm | 9 dmg / 0.35 s, pen 4 | 4-round bursts of 15 dmg every 1.8 s at 180 m/s, pen 5 |
| Scout MG | 4 dmg / 0.2 s | a 10 rounds/s hitscan stream of 3.5 dmg, spread 2° |
| Laser | 12 dmg, 16 heat, 85 m | 22 dmg, 18 heat, 90 m (preferred 76-86); Lancer sight 90 |
| Flamethrower | 20 dps | 55 dps |
| Mortar | 90 | 140 (swept to 320: see below) |
| Armor | IFV 5/3/2, Lancer 4/3/2, Burner 4/3/2 | IFV front 7, Lancer 3/2/1.5, Burner front 6 (a plow) |
| Tank sight | 75 m | 62 m (a welded-slit dozer: it needs spotters for its 70 m gun) |
| Weak spots | none | engine deck: ≤ 25° off dead astern, armored like half the rear |
| Driving | every hull pivots | the tank on tracks (accel 10); wheels elsewhere with turning circles (scout 5 m .. artillery 9 m) and drift |
| Artillery | fires on the move | deploys 2.5 s (a fire command digs it in), packs 2 s |

**Pace:** fights that took 50-130 s in matrix #2 now take 22-60 s (scouts, who spot instead of fighting, still stall to
the time limit against tanks and Burners). A 1-v-1 tank duel ends in three volleys (~17 s); see the combat brief's
Status for tick-by-tick timelines (`make duel`).

**How it was tuned:** `make matchup-search VARIANTS=tools/matchup_variants/<round>.json` plays tune variants on
builder0 and scores each against the designed counters (every unit's `good_vs`, plus inverted `weak_vs`: 12 pairs).
Rounds 1-6 (`tools/matchup_variants/x6_round*.json`) and two artillery sweeps, 8-16 matches per pair:

| Finding | Evidence |
|---|---|
| **The IFV / Lancer / tank triangle is zero-sum on laser strength.** A laser strong or long enough to beat tanks kites and burns down IFV rushes; one weak enough for IFVs loses to tanks. | laser 26 dmg, pen 20, 100 m: Lancer > tank 75%, IFV > Lancer 0%. laser 22, 85 m: IFV > Lancer 56%, Lancer > tank 0% |
| Levers that move one edge only: **IFV front armor** (IFV > Lancer 50% -> 75% with Lancer > tank unchanged) and **tank sight** (Lancers see it first). | round 5 V vs O; round 3 M-O |
| Counter-intuitive: more tank shield (lasers strip shields ×1.25) *lowered* Lancer > tank (50% -> 6%), and a slower tank lowered it too (19%). The brains' matchup appetite reacts to the numbers; results swing ±15% between neighbours. | rounds 5-6 |
| **Artillery's mortar has a cliff at the scout's 220 effective HP:** at 200+ a burst kills bunched scouts, flipping scout > artillery from 79% to 0-33%, and scouts then win nothing. Spotted batteries (a scout escort each side) win at most 17% against tanks even at 320. | `x6_mortar_vs_scouts.json`, `x6_artillery.json` |
| Deploying broke artillery with today's brains until a fire command itself digs the battery in: ai's BOMBARD keeps adjusting range while backing off and never stood still. | `make duel GREEN_UNITS=artillery,artillery,artillery,scout …` |

**Matrix #6 (after CP1, same catalog):** wheels now turn "in place" as multi-point turns (control's executor faces
arrived units that way, and one-direction creep sent them circling off their stations). Lancer brains face threats by
turning in place, so a wheeled Lancer now rocks on the spot instead of circling: Lancer > tank 33% -> **8%**, IFV >
Lancer 75% -> **25%** (A/B on the Lancer pairs with the old creep, same commit). 7 of 12 counters hold. Kept on
purpose: circling was an accident of the assist, and the fix is behavior (ai: drive wheeled units with
`TankMotion.predict` instead of "face"), not stats.

**Where matrix #5 stood:** 8 of 12 designed counters hold at ≥ 65%: tank > IFV 100%, IFV > scout 100%, IFV > Lancer
75%, scout > artillery 79%, Burner > IFV 67%, Burner > artillery 100%, tank > Burner 100%, Lancer > Burner 100%.
Not yet: **Lancer > tank 50%** (a coin flip), **scout > tank and scout > Lancer 0%** (scouts hold their spotting
standoff: the lead's "spotters first"; they beat nothing but artillery), **artillery > tank 0%** (blind alone, weak
spotted). Every unit but artillery wins a matchup. The tank is still the strongest unit per point (it loses only
the Lancer coin flip); the next lever is behavior, not stats: ai's dodging (`incoming_projectiles`), flanking for
weak spots, and circle-strafing should punish a 5 s reload far more than any number here.

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
