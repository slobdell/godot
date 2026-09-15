# Unit AI: how every vehicle fights smart (round 2)

> **Owner: ai stream.** Written 2026-09-15 (A0 in [streams/archive/round2/ai.md](streams/archive/round2/ai.md)). Builds on
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

## As built (2026-09-15): where the code differs from the plan below

The sections below are the design as planned in A0; this is the map from plan to code and the deliberate
deviations.

| Plan | Code | Deviation and why |
|---|---|---|
| Considerations × curves | `game/ai/utility_curves.gd`; COVER_FIRE and TAKE_COVER use them | Older options keep their hand-tuned products (rewriting them would move every measurement for no gain) |
| `why` explanations | `TankBrain.why` appended to `tank.intent` ("COVER_FIRE Rust_2 - squad focus, peek") | Phase and squad-role tags, not consideration dumps: readable on a nameplate |
| Tactical points around cover | `CoverMap` (rings at 3.5 m and 7.5 m, every 3 m) + `TacticalQuery.find_cover/find_cover_fire/find_overwatch` | No dynamic rings around me (static points were enough in scenarios); hiding means the whole hull (center ± 1.6 m) is hidden; friends spacing 5 m; ≤ 16 candidates, ≤ 8 deep, ≤ 6 threats (hull check only for the main one) |
| Peek within the front arc | 30°, 45°, 60° off the bearing, 3–10.5 m, +1.5 m past the first clear spot | ≤ 45° can't get around a wall's end with a tank that can't strafe |
| Exposure influence layer | `threatens_me` per contact (in its weapon's reach with a clear line) | Only the count is used (TAKE_COVER, RETREAT); no damage-rate weighting yet |
| FireLanes | `game/ai/fire_lanes.gd`; OrderController `_clear_to_fire`; brain CLEAR_LANE | Corridor = 2 m (a side-on hull's half length) + 2σ spread, swept by the friend's motion for shells; defers to rules' `Match.friendlies_in_line_of_fire` when present |
| Matchups | `game/ai/matchups.gd` (`effective_dps`, `hit_chance`, `tracking`, `prior`, `duel_advantage`), tested on catalog-v2-shaped data | Not yet wired into target choice or movement: needs catalog v2 on `main` (checkpoint 1); two scenarios pending. Target value will be effective dps ÷ toughness × prior; duel advantage scales ENGAGE appetite; fixed mounts orbit when a turret's tracking factor drops |
| SquadTactics | `game/ai/squad_tactics.gd` + bounding overwatch in `TankBrain._with_overwatch` and `Squad._update_bound` | Escorts for fragile units are a target-priority bonus on enemies within 45 m of them, not a movement assignment |
| AI ladder | `game/ai/brain_variants.gd`, `tools/ai_ladder.py`, `make ai-ladder` | Variants are feature switches read from `--green-brain/--rust-brain` by the brain itself (no match-runner edits) |
| Perf ≤ 1 ms at 50 units | ~7–9 ms (see Results) | Not met; think LOD (18 ticks with no enemy within 130 m) and per-tick shared tables built; the rest is listed under Results |

## Round 3: alive and responsive (2026-09-15, [streams/ai.md](streams/ai.md) X1–X6)

The lead after round 2: *"Tanks will just sit there stationary and shoot each other - there's no intent at evasive
action, no intent of trying to shoot a weak spot, no intent of trying to circle your opponent … the units just don't
feel controllable right now, they seem to get stuck in some particular state and then not respond to my clicks."*

### Orders always win (X1)

| Piece | Code | What it does |
|---|---|---|
| K1 adapter | `game/ai/order_feed.gd` | Reads control's `Orders` duck-typed (`Match.orders`, or the object `Orders.attach` stored on the match); normalizes `current(unit)` to `{verb, goal, target, issued_tick, speed}`: the per-unit world `goal` (control's `to` + formation slot), `goal_position(unit)` for a follow's live station, `pace_factor(unit)` as speed, `station(unit)` as the idle post. `TankBrain.EXECUTES_ORDERS` tells control's stand-in executor to leave brains alone |
| Response guarantee | `TankBrain._poll_order` | Polled every think tick and whenever `order_changed` names the unit; a new order interrupts the unstick routine and commitment and is executed the same tick (measured worst 1 tick) |
| What vs how | `TankBrain.ORDER_OPTIONS`, `_obey` | The verb filters the options: move → MOVE; hold → HOLD; follow → FOLLOW; attack → only fights on its target, PURSUE when out of sight; attack-move → MOVE at 0.55 unless a visible enemy in weapon range + 10 m gets fought (+0.5), RETREAT only when about to die |
| Completion | `_update_order_progress` | Brains call `Orders.complete`: move on arrival (3.5 m, or 12 m after 3 s without progress), attack-move the same once nothing is engaged, attack/follow when the other unit is gone, stop once below 0.5 m/s |
| Regroup | idle posts | Every finished order leaves a post; an idle unit fights within 30 m of it (the situation's objective + leash) and drives back beyond that. No scouting, contesting, or resupply trips on its own |
| No stuck states | `_timed_out`, `cooldowns` | An option kept past its timeout (fights: since the last shot) or driving 3 s without progress (`OrderController.stalled_ticks`) goes on a 5 s cooldown (×0.25). Ladder: with vs without, 26–22 over two doctrines |

Scenarios: `tests/ai_scenarios/scenario_orders.gd` (`StubOrders` stands in for control's `Orders` until CP1); pure
decide tests: `tests/test_ai_orders.gd`.

### Fighting on the move (X2) and evasion and weak spots (X3)

**Literature.** Context steering (Andrew Fray, *Game AI Pro 2*, 2015: interest and danger maps over a ring of
directions, the choice with the best interest among the least danger), steering behaviors (Reynolds, GDC 1999:
evade, pursue with prediction), and armor doctrine (short halts; angling the hull so the front takes the hits).

**`CombatMotion`** (`game/ai/combat_motion.gd`, pure): 16 directions × {forward, reverse}, each judged where it ends
after ~1.2 s of driving. Interest terms: the weapon's range band, tangential motion, keeping the chosen side (a jink
flips it), working toward the target's side and rear, front armor toward every gun that can shoot (the target
counting double), continuity. Costs: seconds of hull turn (a pivot is standing still), reversing. Dangers
(subtracted): obstacles on the path (CoverMap), arena edges, ramming the target, crowding a friend, and an incoming
round that would hit (`would_be_hit`: current velocity, hull turn, acceleration, stepped closest approach).

| Style | Who (`TankBrain.motion_style`) | How it fights |
|---|---|---|
| `strafe` | turret units, front armor < 6 (IFV, Lancer, Burner) | Circles inside the band, jinks sides every 1.5–4 s per unit; jinks shuffle forward/back instead of pivoting |
| `angle` | front armor ≥ 6 (the tank) | A **weave**: the hull stays within 50° of the target and rocks forward and back along it; a **short halt** brakes so the gun is loaded as the hull stops, fires, then moves again while reloading |
| `run` | fixed guns (the scout) | Attack runs aimed past the target's flank, break away inside 9 m, turn back in beyond 30 m on the other flank |

A **busy target** (its gun on someone else) flips the priorities: flank weight up, own armor weight down, no side-on
mask, so the unit not being shot at swings wide for the side (`why`: "going for its side"). `IncomingFire`
(`game/ai/incoming_fire.gd`) reads `Match.incoming_projectiles` (K2) when combat ships it and the Shells container
until then; a new round on its way triggers a think at once.

Brain variants: **x2** = a6 + `combat_motion`; **x3** = x2 + `dodge`. The champion stays a6 until a ladder says
otherwise (results below).

### Measurements so far (round-2 weapons, builder0)

| Measure | a6 (round 2) | x2 / x3 |
|---|---|---|
| Tank duel: time moving | 1% | 79–84% |
| Tank duel: hits on the front | 100% | 36% (circling side-on) → 100% (weave) |
| Tank mirror (5 v 5) hits by face | front 66%, side 31%, rear 3% | first cut front 36–39%, side 47–49%, rear 15%; weave front 56%, side 35%, rear 8% |
| Two tanks on one: time seeing its side or rear | | 0 s (weave only) → 5.0 s of 20 (busy-target flanking) |
| Scout ordered onto a tank (x2) | | 4 attack runs in 25 s, all 22 hits into its side or rear |
| IFV vs a cannon at 30–45 m: shells that miss | 0% | 6–15% (noise over 33 shells) |
| Ladder vs a6, individuals mirror | | x2 0–24 (first cut) → 3–13 (short halt) → x3 4–12 (weave) → **14–10** (turn cost, busy-target flanking) → **15–9** (after the CPU pass) |
| Ladder vs a6, combined_arms | | x2 12–12 → x3 **17–7** → **21–3** |
| CPU, 50 brains, builder0, back to back | 3.9–4.6 ms per tick | x3 5.0–6.1 ms → **4.7 ms** |

Reading: moving tanks lost mirrors because they showed their sides (the armor multiplier is 0.5 front, 1.0 side,
1.5 rear) and fired on the move with a turret the hull drags off target; the weave and the short halt recovered
most of it, and charging for hull turns (a pivot is standing still) plus flanking only targets busy with someone
else made x3 the champion (`BrainVariants.CHAMPION`, 2026-09-15). CPU pass: CombatMotion's hops skip the navmesh
(`direct` move orders), plans are reused for 15 ticks unless a round, a jink, the target, or the run phase changes,
"can that gun shoot me" uses a 2 m line-of-sight memo, and ally lists and sorted intel names are shared per tick. **Dodging is physically marginal with round-2 shells:** 70 m/s at 25–45 m arrives in ~0.5 s, in which a
14 m/s² hull moves ~2 m off the shooter's lead, less than half a hull; the dodge threshold scenario is pending until
combat's slower, visible tank shells land.

### A CPU that maneuvers (X5)

`CpuCommander` policies v3–v6 (`game/ai/cpu_commander.gd`, `--green-commander=<policy>` / `--rust-commander=<policy>`)
plan the whole army every second by squad role (`squad_class`: fast = mostly scouts, support = mostly artillery or
Lancers, line = the rest), in shapes a player can see: **muster** at a rally point ahead of base (line in a wedge,
scouts in a V, support in a column), **advance** with the main line in a wedge and the others beside it, scouts
screening ahead, support trailing; on contact **engage**: the strongest line squad assaults the enemy's center, other
line squads swing to a flank point 45 m off the axis in a wedge and assault from there, scouts charge in a V; worn
squads **rest** (break contact below 35% hull + shield, back at 70%); clearly outmatched far off, the army
**withdraws**. The scout V reads in a real fight: 13.2 s of a 45 s swarm attack at speed, spread up to 72 m
(`scenario_commander.gd`). Commands go out as SquadCommands (C7) so doctrines and the skirmish CPU use them unchanged.

The variants, each one change measured against the last (ladder on **same-army mirrors**: `tests/ai_scenarios/armies/`
holds the CPU archetypes as fixed armies, because `cpu:` armies are seeded per side and a `cpu:` ladder compared armies,
not commanders; 12 matches per pairing, brain x3 everywhere):

| Policy | Change | vs plain x3: armor | balanced | swarm | anvil_hammer | total |
|---|---|---|---|---|---|---|
| v2 (round 2) | squad-by-squad assault | | | | 3–13 | |
| v3 | role-based army plan above | 3–9 | 9–3 | 9–3 | 7–5 | 28–20 |
| v4 | flank only with a 1.15× edge, wide advance, scouts charge only artillery/Lancers | 5–7 | 11–1 | 12–0 | 2–10 | 30–18 |
| v5 | v3, but a squad flanks only with ≥ 40% of the main squad's strength | 5–7 | 8–4 | 9–3 | 7–5 | 29–19 |
| **v6** (default) | v5's flanking + v4's wide advance and scout rule (16 matches per pairing) | 6–10 | 13–3 | 16–0 | 10–6 | **45–19** |

Head to head v4 beat v3 30–18 and v5 32–16; v6 and v4 split 31–33, and v6 beats plain brains where v4 doesn't (anvil_hammer 10–6 vs 3–13). Reading: v5's flanking wins with tank-heavy armies (armor, anvil_hammer);
v4's scouts, left holding their screening spot ahead of the line, shred light armies with machine guns from there
(swarm 12–0, 272 kills); charging the enemy line with scouts is worth it only against artillery and Lancers. Two traps
found on the way: every policy but "v3" fell back to v2's planner (a dispatch bug; the first v4 and v5 numbers were v2's),
and `cpu:` mirrors aren't mirrors.

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
| Three brains in a squad vs three targets: share of damage on the most-damaged target | 66% (each shoots its nearest) | 100% (squad focus) |
| Bounding overwatch next to a wall: the watcher's time hidden from a known gun during the first leg | 0% (stays where it halted) | 51% (tactical overwatch spot; the bound waits for the overwatch to set) |
| Scout circles a slow turret; IFV prioritizes scouts | pending: needs rules' catalog v2 (checkpoint 1) | |

### T1: does coordination beat individuals? (Anvil & Hammer vs Individuals, elimination, 300 s, 16 per row)

| Brain | Normal bases | Swapped | + control point | + control, swapped | Coordinated overall |
|---|---|---|---|---|---|
| `main` as of round 2 start (round 1 brain) | 1 : 15 | | | | (idle guns Green 78%, Rust 89%) |
| A0–A4 (before squad tactics) | 2 : 14 | 3 : 13 | 9 : 7 | 13 : 3 | 5/32 without the control point (16%), 22/32 with it (69%) |
| a6 (squad tactics, champion) | 4 : 12 | 1 : 15 | 4 : 12 | 8 : 8 | 5/32 without (16%), **12/32 with it (38%)** |

Reading: without the control point nothing changed. With it, squad tactics cut the coordinated doctrine's edge
from 69% to 38%. The "Individuals" doctrine is one 5-tank squad, so squad tactics (focus fire, a flanker)
coordinate it too, while Anvil & Hammer's 3 + 2 split gets less from them. **Design question for the lead:**
smarter autonomous squads shrink the payoff of a player's coordination. That's intended ("units handle how"),
but the player's edge must come from *where and when* (splitting, flanking routes, timing, the control
point), not from making units fight well. Watch this in playtests; the counters in catalog v2 (checkpoint 1)
should add payoff to composition choices.

**Idle guns** (a loaded gun with an enemy in its own sight and range, not firing): 78/89% on `main`, 95% with
the new brains. An 8+8 mirror probe: r1 brains 88–90% idle, 3298 shots, 79% accuracy, 16% side hits; a6 brains
95% idle, 3163 shots (−4%), **85% accuracy, 25% side hits**: a6 lands more hits. The extra idle time is by
design (holding fire for a friend in the lane, waiting in cover to reload), not a lost-shots bug. (One real
contributor was fixed with A6: the 6-tick target scan kept "nothing to shoot" for 5 ticks after a miss.)

### AI ladder (`make ai-ladder`)

Brain variants (`game/ai/brain_variants.gd`): **r1** = round 1's behaviors on today's sensing; **a4** = + cover
fire, retreat to cover, fire discipline; **a6** = + squad tactics. Every pairing plays a mirror army (default
`individuals`: five cannons in one squad), each seed four ways (both colors × both bases). ELO: K = 16, all
start at 1000, the match list replayed 20 times and the last 10 averaged. A challenger becomes champion only by
out-rating the champion AND beating it head to head. The champion is `BrainVariants.CHAMPION` (the default
brain everywhere).

<!-- ladder-table -->
**Run 1 (2026-09-15, `main`'s rules: no friendly fire; individuals mirror; 16 matches per pairing):**

| Variant | ELO | W–L |
|---|---|---|
| r1 | 1090 | 22–10 |
| a6 | 1007 | 16–16 |
| a4 | 903 | 10–22 |

Head to head: r1 beat a4 **13–3** and a6 9–7; a6 beat a4 9–7.

Reading: the new behaviors look smart in scenarios but lost the straight fight. Two suspects: (1) holding fire
for friends is a pure handicap while shells that hit friends do no damage (rules turn friendly fire on in round
2, which flips this); (2) a hide/peek cycle of ~4 s gives the enemy's shield (4 s recharge delay) time to come
back. Squad tactics recovered part of the gap (a6 over a4).

**Run 2 (same rules, with think LOD; 12 matches per pairing):** probes `a6n` = a6 without holding fire for
friends, `a6np` = a6n + COVER_FIRE backing off against broken shields and winning trades.

| Variant | ELO | W–L |
|---|---|---|
| **a6** | 1189 | 28–8 |
| r1 | 997 | 20–16 |
| a6n | 974 | 16–20 |
| a6np | 839 | 8–28 |

Head to head: a6 beat r1 7–5, a6n 9–3, a6np 12–0; r1 beat a6n 7–5 and a6np 8–4.

Reading: both suspects were wrong. Holding fire for friends *helps* even without friendly fire (a6 over a6n
9–3: shells stopped by a friend were wasted reloads), and "press instead of ducking" was clearly worse (0–12).
Across both runs r1 vs a6 is 14–14: in a straight mirror brawl the new behaviors are about even with round 1's
charge-and-shoot, while being the behavior the lead asked for (cover, peeking, no friendly fire), and they
win the coordinated fights (squad tactics). **Champion: a6** (it beat champion a4 in run 1 and r1 in run 2).
The press probe was deleted. Re-run after checkpoint 1: friendly fire on and the v2 roster change the answer.

**Run 3 (CPU probe, 16 matches):** `a6t9` = a6 thinking every 9 ticks in contact instead of 6. AI cost 11.2 →
8.6 ms per tick at 50 brains (same machine load, back to back: −24%). Head to head a6 9–7: within noise, but the
challenger didn't win, so **the champion stays a6**. `a6t9` stays in `BrainVariants` as the first lever if phones
need the CPU (re-test it there with more matches).

### CpuCommander (stretch): does a CPU commander beat plain brains?

Individuals mirror (one 5-tank squad each), one side commanded, 8 matches × {Green, Rust} × {normal, swapped}:

| Commander | Commanded side wins |
|---|---|
| v1 (round 1) | 8/32 (25%) |
| v2 (assault toward fresh contacts, no break-contact within 45 m, fewer re-issued orders) | 9/32 (28%) |

Reading: on a single squad of competent brains, squad orders only constrain them (KEEP_SLOT 6–15% of the
commanded tanks' time; RETREAT and hunting are limited under orders). v2's rules are sounder but not
measurably better. It stays opt-in (`--commander` / `--green-commander`). A commander's value should come from
several squads (one fixes, one flanks), which needs catalog-v2 armies (≤ 5 per squad): measure again then.

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
