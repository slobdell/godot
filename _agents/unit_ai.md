# Unit AI: how every vehicle fights smart (round 2)

> **Owner: ai stream.** Written 2026-09-15 (A0 in [streams/ai.md](streams/ai.md)). Builds on
> [tank_brain.md](tank_brain.md) (the utility brain as it stood after round 1) and
> [squad_ai_design.md](squad_ai_design.md) (why utility AI, where skill comes from). The design rules come
> from [game_design.md](game_design.md) "Unit AI". Results and the ELO table are at the bottom.

The lead's ask: *"all of the vehicles on the board should behave smartly, i.e. taking advantage of cover,
going in and out of cover to shoot … avoid shooting their own friendlies … really sophisticated."*

## Summary: what we build and why

| Layer | Literature | What we adopt | What we skip, and why |
|---|---|---|---|
| Decision making | Utility AI with considerations and response curves (Dave Mark, IAUS) | Keep `TankBrain`'s pure `decide()`. New and reworked options are written as **considerations × response curves** (`UtilityCurves`), with the IAUS compensation factor and a per-option weight | A data-driven consideration editor: our weights are code constants tuned by the ladder, and a GUI would slow iteration |
| Where to stand | Killzone position picking, CryEngine TPS, Unreal EQS | **Tactical queries** (`TacticalQuery`): *generate* candidates (static points around cover features plus rings around me and my squad slot), *filter* cheaply (arena, obstacles, leash), then *score* with weighted criteria. Expensive tests (line of sight) run last, only on survivors | Asynchronous raycast queues and time slicing: our LOS test is pure 2D math against at most ~20 boxes, cheap enough to run inline |
| Threat awareness | Influence maps (Tozour; Mark's modular influence maps) | **Point-sampled threat**: for a candidate point, sum each known enemy's weapon reach, damage rate, and line of sight. It is a lazily evaluated influence map | A full grid over the arena, until a measurement shows point queries are too slow or a squad/commander query needs area reasoning (then a coarse 8 m grid for the CPU commander) |
| Seeing and shooting | Killzone "lines of fire", Halo/Crysis friendly avoidance | `CoverMap`: pure 2D line of sight over cover features; `FireLanes`: friendlies within a hull width of the line of fire, or inside splash plus scatter | Physics raycasts in decisions: they need a scene, can't be unit tested on hand-built situations, and cost more |
| Peeking | Hide/peek pairs (Killzone cover, Gears of War) | A `COVER_FIRE` option: hide spot + peek spot from one tactical query; peek when the gun is (nearly) loaded, fire, back into cover to reload or recharge | Hull-down on terrain: the arena is flat, walls are 3 m. Revisit with rules' low cover (`height`) and the roadmap's terrain |
| Target choice | StarCraft/Warcraft acquisition priorities ("things that can shoot back first"), exchange-ratio reasoning | `Matchups.effectiveness()`: expected damage per second from mechanics (armor facing, shield multiplier, turret tracking vs angular speed, fixed arcs) × the catalog's `good_vs`/`weak_vs` prior | Hard-coded counter tables: the rules stream wants counters to emerge from mechanics, so the AI reads the mechanics too |
| Squad coordination | F.E.A.R. (Orkin): per-agent planners plus squad behaviors that hand out goals; US Army bounding overwatch (FM 3-20.15) | `SquadTactics`, a squad blackboard every 30 ticks: focus target, suppress-and-flank roles, cover for a retreating teammate, escorts for fragile units, overwatch positions for bounds. Brains read it as considerations, never as commands | A GOAP planner: our action set is small and flat, plans would be hard to measure and explain. F.E.A.R.'s squad behaviors were simple coordinators, which is the part we take |
| Cost | Staggered updates, AI LOD, caching (TPS, EQS) | Think staggering (exists), tactical queries only when a position is needed, per-team memoized LOS keyed by quantized positions (deterministic), a CPU budget test at 50 units | Multi-threading: the web export has no threads |

## 1. Decision making: considerations and response curves

**Literature.** Dave Mark's *Behavioral Mathematics for Game AI* (2009) and the GDC talks with Kevin Dill
("Improving AI Decision Modeling Through Utility Theory", 2010; "Architecture Tricks", 2013, the *Infinite Axis
Utility System*). Each behavior (option × target) is scored as the **product of considerations**. A consideration
normalizes one input (distance, health, ammo) to 0..1 and passes it through a **response curve** (linear, quadratic,
logistic, inverse). The product is corrected for how many considerations it has (more factors would otherwise
always score lower): `make_up = (1 − score) × (1 − 1/n)`, `score += make_up × score`. A behavior's **weight**
(priority) scales the result, so "survive" outranks "reposition" by design. A product means any consideration at 0
vetoes the behavior, a readable property ("no LOS lane → no COVER_FIRE").

**What we have.** `TankBrain.decide()` already multiplies ad-hoc factors per option, with commitment
(×1.15, 45 ticks), an emergency margin, and stable ties. It works and it's measured; rewriting every option at once
would move the sim baseline and every result for no player-visible gain.

**What we adopt.**
- `UtilityCurves` (pure, static): `linear`, `quadratic`, `logistic`, `smoothstep`, `inverse`, `band` (a plateau
  between two values with soft edges, for "preferred range"), and `compensate(product, n)`.
- New options, and existing options when we touch them, use these. Each option keeps a one-line comment
  naming its considerations.
- **Explainability:** `ranked` keeps the top options; a new `why` string records the dominant considerations of the
  winner (e.g. `COVER_FIRE Rust_2 [lane ok, reload 0.9, cover 0.8]`). The nameplate and the agent bridge show it.
- Commitment stays. Options that are *sub-phased* (COVER_FIRE's hide ↔ peek) keep the option committed and switch
  phase inside `_act`, so phase changes don't reset commitment.

## 2. Tactical position evaluation

**Literature.** *Killzone's AI: Dynamic Procedural Combat Tactics* (Straatman, van der Sterren, Beij, GDC 2005):
bots pick positions by scoring nearby waypoints with weighted functions (cover from threats, LOS to target,
distance), using precomputed cover/line-of-fire data. CryEngine's **Tactical Point System** (Matthew Jack, *Game
AI Pro*, 2013): a query is **generation** (points around cover objects, hide spots, grids) → **conditions**
(boolean filters, cheapest first) → **weights** (scoring), with expensive raycasts deferred and evaluation stopped
once the best can't be beaten. Unreal's **Environment Query System** is the same shape: generators, contexts,
filter/score tests.

**What we adopt: `TacticalQuery`** (pure over a `CoverMap` and a Situation):
1. **Generate.** Static points built once per arena from cover features: every obstacle's footprint grown by a
   clearance (3.5 m), sampled every ~3 m, plus diagonal corner points. Dynamic points: a ring around me (10 m, 20 m)
   and around my squad slot when I have one. Deduplicated; ~350 static points on today's arena.
2. **Filter (cheap first).** Inside the drivable arena; not inside a grown obstacle; within `search_radius` of me;
   inside my leash/objective or near my slot (player intent); not within 6 m of a friendly (splash spacing).
3. **Score (weighted, 0..1 per criterion, expensive last).**
   - *cover*: fraction of known threats (visible first, then fresh memories, up to 6 nearest) whose line of sight to
     the point is blocked (CoverMap);
   - *lane*: line of sight from the point (or its peek spot) to the target;
   - *range*: `band` around my weapon's preferred range to the target;
   - *exposure*: point-sampled threat: sum over threats that see the point of their damage rate in range;
   - *travel*: distance from me (straight line; the path is checked only for the winner);
   - *intent*: distance from my squad slot or objective;
   - *spacing*: distance to the nearest friendly.
   Each query type (`cover`, `cover_fire`, `firing_lane`, `flank`, `overwatch`) is a weight vector over these.
4. **Peek spots.** For a hide point, the peek point is the nearest generated point within 3–9 m whose LOS to the
   target is clear, and whose direction from the hide point is within 60° of the target direction (so driving forward
   to peek keeps the front armor toward the enemy and reversing back to hide keeps it there too; tanks can't strafe).

**Cost control.** Queries run only when an option needs a position, at most every `QUERY_EVERY_TICKS` (30) per
tank unless the situation changed (a new threat, the target moved > 8 m, a new order). LOS results are memoized in a
per-team table keyed by *quantized positions* (1 m), so the result depends only on inputs: evaluation order can't
change a decision, which keeps `make determinism` green. The table is dropped every 60 ticks.

## 3. Influence maps: threat, control, exposure

**Literature.** Paul Tozour, "Influence Mapping" (*Game Programming Gems 2*, 2001); Dave Mark, "Modular Tactical
Influence Maps" (*Game AI Pro 2*, 2015): layers (threat, proximity, control) propagated with falloff, combined per
query ("working maps"). Killzone 2's bots used them for strategic reasoning.

**What we adopt.** The *exposure* criterion above is a point-sampled threat layer (enemy damage rate × in range × has
line of sight), and *control* for the CPU commander is "who can bring more guns to bear here". We compute them on
demand for a few dozen points rather than a grid, because brains only ever ask about a handful of candidates.
**Trigger for a grid:** if the CPU commander or path-safety scoring needs area queries (e.g. "safest route to the
flank"), add a coarse 8 m grid (30 × 30 cells) per team refreshed every 30 ticks.

## 4. Line of fire and friendly fire

**Literature.** Killzone checked lines of fire for friendlies when picking positions; Halo 2/3 and Crysis soldiers
won't shoot through allies and step aside to clear a lane. Friendly fire is on in round 2 (rules), so a shot through
a teammate hurts it; today a friendly just eats the shell.

**What we adopt: `FireLanes`** (pure):
- *Direct fire* (cannon, autocannon, laser, machine gun): a friendly blocks when it lies between shooter and aim
  point (projection in (1 m, distance + 2 m)) and within `hull half-width + spread margin` of the line, where the
  margin grows with distance × the weapon's spread (2σ). Adapter: `Match.friendlies_in_line_of_fire()` (C4) once
  rules ship it; our own implementation until then.
- *Splash* (mortar): a friendly within `splash_radius + 2σ scatter` of the aim point.
- **OrderController holds fire** while a lane is blocked (the last gate before `cmd.fire`), and counts it
  (`held_for_friendly`). It prefers another shootable enemy with a clear lane before holding.
- **The brain moves to clear it:** a blocked lane for more than ~1 s makes `CLEAR_LANE` score: a `firing_lane`
  tactical query (a nearby point with LOS to the target, no friendly in the lane, same range band).
- **Risk, not only veto** (for later tuning): lane-blocked target value × 0 in `ENGAGE`'s target choice, so brains
  prefer enemies they can shoot cleanly.

## 5. Cover discipline: peek and shoot

**Literature.** Cover-based shooters (Gears of War, Killzone) run a hide/peek loop per agent: stay hidden while
reloading, expose only to fire. For vehicles, *hull-down* (CoH 2, real armor doctrine) shows only the turret.

**What we adopt: `COVER_FIRE target`**, sub-phases computed from state each tick in `_act`/OrderController:
- **HIDE** at the hide point, reversed in if possible so the front faces the threat. The turret pre-aims at where the
  target will appear (watch point), so peeking costs no traverse time.
- **PEEK** when the gun will be ready by the time the tank reaches the peek point (`reload_left ≤ travel time`), the
  shield isn't broken, and the target is still where the lane is.
- **FIRE** from the peek point (halted, so moving spread doesn't apply).
- **BACK** into the hide point after the shot while reloading, or immediately when the shield breaks or two guns turn
  on me.
- Scores high for cautious directives, slow-reload weapons (cannon, mortar-proof), and when a good hide/peek pair
  exists within reach; it loses to ENGAGE for fast-firing weapons (machine gun, autocannon) that gain little.
- **Hull-down / front armor:** peek directions stay within 60° of the target so the front takes the hits; when rules
  add low cover (`height < muzzle_height`), a low-cover point counts as permanent peek with front-only exposure.

## 6. Matchup-aware fighting

**Literature.** StarCraft/Warcraft auto-acquire: prefer units that can attack you, then by priority value. Exchange
ratio: engage fights where my damage rate on them beats theirs on me.

**What we adopt: `Matchups`** (pure):
- `effective_dps(attacker, defender, geometry)`: weapon damage / reload × armor-facing multiplier (from positions) ×
  shield multiplier while the shield is up × **tracking** (turret turn rate vs the defender's angular speed around
  the attacker; fixed mounts: only inside `fire_arc_deg`) × range fit × penetration vs armor once rules add it.
- Target value = my effective dps on it ÷ its remaining toughness, plus a bonus when it threatens a fragile ally; duel
  appetite = my dps on it ÷ its dps on me (≥ 1 good, < 0.6 avoid unless ordered).
- The catalog's `good_vs`/`weak_vs` (C1) is a prior multiplier (×1.25 / ×0.75), because mechanics estimated from a
  snapshot miss things (a scout will close the distance).
- Role behaviors: **fixed-mount scouts** aim with the hull and orbit slow turrets (circle at a radius where the
  turret's angular speed can't keep up: `ω_orbit = v / r > turret_turn_rate`); **IFVs** screen and prioritize
  scouts; **tanks** keep the front toward the most dangerous threat; **Lancers and artillery** keep distance and
  stay behind friendly guns.

## 7. Squad tactics

**Literature.** Jeff Orkin, *Three States and a Plan: The AI of F.E.A.R.* (GDC 2006): each soldier plans with GOAP;
a **squad coordinator** runs squad behaviors (get to cover, advance cover, orderly advance, search) by giving members
goals; flanking and suppression *emerge* when one member is sent to a flank position while the others hold and fire.
US Army bounding overwatch (FM 3-20.15 tank platoon, FM 3-21.8): one element moves while the other covers from
positions with fields of fire, then they swap.

**What we adopt: `SquadTactics`** (pure, per squad every 30 ticks, results in `Squad.blackboard`):
- **Focus fire:** the enemy with the best `sum over members of (effective dps × lane clear) / its toughness`; members
  get a target-value bonus for it (not a lock: a brain still shoots what it can).
- **Suppress-and-flank:** with ≥ 3 members vs a dug-in enemy, the member best placed for its side becomes the
  flanker (a `flank` query), the rest suppress (COVER_FIRE or ENGAGE on it).
- **Cover the retreat:** a member that retreats or recharges gets a covering member: the nearest healthy one
  targets whoever is shooting the retreater.
- **Escort fragile units:** artillery/Lancers get their nearest gun escort's position as a spacing/intent term.
- **Bounding overwatch:** the overwatch element's slots become `overwatch` query results near the formation slot
  (cover + LOS toward the bound's destination), instead of "stay where you are".
- All of it is *within* the player's order (G3): it tilts considerations, it never overrides KEEP_SLOT.
- Re-measure T1 ("coordination beats individuals") with and without the control point after this lands.

## 8. Performance budget (phones)

- **Budget:** at 50 units, AI (brains + orders + tactics) ≤ **1.0 ms per physics tick** on the dev machine
  (≈ 4–5 ms on a mid-range phone in wasm, under half of the 16.7 ms frame). Measured by `make ai-perf`
  (a scenario that prints `MEASURE ai_usec_per_tick`).
- **Techniques:** staggered thinking (6 ticks, existing); tactical queries only when needed and at most every 30
  ticks per tank; candidates capped (48 after filtering) and threats capped (6 nearest); LOS memoized per team with
  quantized keys; squad tactics every 30 ticks; no allocations in OrderController's per-tick path beyond what exists.
- **LOD later:** units far from any enemy think every 12 ticks.

## 9. Testing and measurement

- **Golden decisions** (`tests/test_brain_decide.gd`, `tests/test_ai_*.gd`): hand-built Situations, one behavior per
  test, named as a player would say it.
- **Behavior scenarios** (`tests/test_ai_scenarios.gd` in `make check`; longer ones in `tests/ai_scenarios/`,
  `make ai-scenarios`): seeded mini-battles on the real arena with assertions on what happened (moved to cover
  within N s, peeked and fired and returned, held fire while a friendly crossed).
- **AI ladder** (`make ai-ladder`): brain versions or parameter sets play each other (seeded, swap bases, swap team
  identity), an ELO table below, a new champion must beat the old one. Brain variants are selected with
  `--green-brain=<id>` / `--rust-brain=<id>` so old behavior stays runnable.
- **Determinism:** all of the above read `Match.tick`, iterate sorted by name, and are pure given a Situation.

## Build order (the brief's backlog)

A1 scenario harness → A2 `CoverMap` + `TacticalQuery` → A3 `COVER_FIRE` → A4 `FireLanes` + hold fire + `CLEAR_LANE`
→ A5 `Matchups` (after rules' catalog v2) → A6 `SquadTactics` → A7 ladder. Each starts as a failing scenario.

## References

- Dave Mark, *Behavioral Mathematics for Game AI*, 2009; Mark & Dill, "Improving AI Decision Modeling Through
  Utility Theory", GDC 2010; Mark, "Architecture Tricks: Managing Behaviors in Time, Space, and Depth" (IAUS), GDC 2013.
- Remco Straatman, William van der Sterren, Arjen Beij, "Killzone's AI: Dynamic Procedural Combat Tactics", GDC 2005.
- Matthew Jack, "Tactical Position Selection: An Architecture and Query Language", *Game AI Pro*, 2013 (CryEngine TPS).
- Epic Games, Environment Query System documentation (Unreal Engine 4/5).
- Paul Tozour, "Influence Mapping", *Game Programming Gems 2*, 2001; Dave Mark, "Modular Tactical Influence Maps",
  *Game AI Pro 2*, 2015.
- Jeff Orkin, "Three States and a Plan: The A.I. of F.E.A.R.", GDC 2006.
- Damián Isla, "Handling Complexity in the Halo 2 AI", GDC 2005.
- US Army FM 3-20.15 *Tank Platoon* (movement techniques: traveling, traveling overwatch, bounding overwatch).

## Results

### Behavior scenarios (`make ai-scenarios`, seeded, 2026-09-15)

| Scenario | Before (round 1 brain) | Now |
|---|---|---|
| A hurt tank (120/300 hull, shield down) under two guns, cover 8 m away | never hidden: backed 100 m toward base across open ground | out of both guns' sight after 3.3 s, stays hidden 2.4 s+ (RETREAT breaks line of sight first) |
| A healthy cannon tank near a wall vs a gun 45 m away, 20 s | hidden 0%, 10 shots from the open | hidden 68%, 9 shots, back into cover after firing 7 times (COVER_FIRE) |
| A friend shuttles across the line of fire | 1 of 7 shots fired through the friend | 0 of 7 |
| A friend parked in the line of fire | never fires (every shot would hit the friend) | sidesteps 5.4 m, first shot at 2.9 s, 4 shots, none through the friend (CLEAR_LANE) |
| Artillery shells an enemy with a friend 5 m from it | (not measured before) | 0 rounds (4 when the friend is 50 m off) |
| Scout circles a slow turret; IFV prioritizes scouts | pending: needs rules' catalog v2 (checkpoint 1) | |

### The 2D cover map vs physics

`CoverMap.clear_line` agreed with physics raycasts on 139 of 139 random sight lines on the real arena
(`test_ai_cover_map`). Microbenchmarks on the dev machine: a physics ray ≈ 3 µs from GDScript; a computed
CoverMap line ≈ 10 µs; a memoized one ≈ 0.7 µs.

### CPU cost (`make ai-perf`: 50 brains, 25 v 25, 30 s, most of it fighting)

| Step | usec per physics tick |
|---|---|
| Round 1 brain as found | ~15 300 |
| Sight rays only for halt_on_contact reflexes; per-tick shared tank tables (behavior identical) | ~9 800 |
| + A2/A3 tactical queries (unoptimized) | ~14 700 |
| + contact cap (nearest 8), cover queries only for worn tanks, 6-tick target scans, cheap facing | ~6 800–9 000 |

The shared machine swings ±30% with other worktrees' load. Where the rest goes (per tick): building
situations ~3 ms (contact dictionaries), decide ~1.4 ms, weapon target checks ~1.8 ms, pathing ~0.8 ms,
tactical queries ~1.1 ms. **The 1 ms target is not met.** Next steps, in order of expected gain: think LOD
(units with no contact within 120 m think every 18 ticks), orders at 30 Hz for units not firing, a
per-team shared contact table built once per intel refresh (brains add only their per-tank fields), and
typed arrays in place of dictionaries in `decide()`.
