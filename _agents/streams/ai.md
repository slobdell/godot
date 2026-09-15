# Stream: ai (units that feel alive; a CPU that maneuvers)

> Read [../orchestration.md](../orchestration.md), [../game_design.md](../game_design.md) (*Round 3 direction*, pillar
> 7, *Unit AI*), [../workstreams.md](../workstreams.md) (you consume K1, K2, K3), [../unit_ai.md](../unit_ai.md) (your
> round-2 architecture and ladder), and [../determinism.md](../determinism.md). You own `game/ai/` except
> `doctrine.gd`, `game/agent/`, `tools/agent.py`, `tools/ai_ladder.py`, `mk/ai.mk`, `tests/ai_scenarios/`, and
> `_agents/{tank_brain,squad_ai_design,unit_ai}.md`.

## The lead's direction (2026-09-15)

> *"right now the interaction against opponents sucks. It barely feels alive. Tanks will just sit there stationary and
> shoot each other - there's no intent at evasive action, no intent of trying to shoot a weak spot, no intent of trying
> to circle your opponent (i.e. move tangentially from your opponent while shooting at him). There's no action from
> the computer player to use different formations or flanking maneuvers. There's no intent to pop in and out of cover
> … the units just don't feel controllable right now, they seem to get stuck in some particular state and then not
> respond to my clicks; units within the same squad ended up getting separated and didn't rejoin … a V formation of
> scouts from the gang coming at you would be scary."* Inspiration: *"Twisted Metal 3."*

## Where things stand (round 2)

- Utility brains (`TankBrain`), a 2D cover map and tactical queries (A2), peek-and-shoot (`COVER_FIRE`, A3), fire
  lanes and friendly-fire discipline (A4), matchup groundwork and the `a5` variant (A5: target choice by time-to-kill,
  scouts `ORBIT` slow turrets; not the default), squad tactics (A6), the ladder with champion `a6` (A7).
- **Unfinished from round 2** (close-out in [archive/round2/ai.md](archive/round2/ai.md)): the ladder `a5` vs `a6` on
  `combined_arms` and the scout matchup matrix per variant were stopped mid-run.
- CPU ~7–9 ms per tick at 50 brains (target ≤ 4 ms for phones later). A `CpuCommander` exists but loses to plain brains.
- Despite the architecture, the lead sees stationary duels: behaviors exist but rarely win the utility contest, or the
  movement they request is too timid to read.

## Backlog (in order)

**X1. Orders always win (K1).** When CP1 lands, brains execute `Orders.current(unit)` as their goal: a new order
preempts any option within 3 ticks (test: every option state), attack-move fights on the way, follow keeps station,
hold stays put but still turns and shoots. Formation slots from control's group moves become the movement target.
Kill "stuck" states: every commitment has a timeout and yields to orders. Regroup: a unit far from its group's slot
with no personal order returns. Scenarios first.

**X2. Movement while fighting.** Circle-strafing: move tangentially around the target at the weapon's best range
while firing (turrets track; fixed-mount scouts make attack runs and orbit outside a slow turret's tracking speed);
keep moving unless holding. Using K3 `TankMotion.predict`, plan maneuvers that the vehicle can actually drive (wheels
have turning circles once combat lands them; A8 from round 2). Scenarios: "two tanks duel: both keep moving and at
least one flanks within N s", "a scout run on a tank's rear".

**X3. Evasion and weak spots.** Dodge: read `Match.incoming_projectiles`, jink or brake when a slow tank shell will
hit. Seek weak spots: prefer positions that expose the target's side or rear (K2 faces) and keep your front toward
threats. Pop in and out of cover with the new long tank reload: hide while reloading, peek to fire. Scenarios measure
dodge rate against tank shells and weak-spot hit share.

**X4. Make it visible.** Behaviors must *read* to a player at play distance: exaggerate commitment (a flank is a wide,
obvious arc; a retreat breaks away at speed), avoid dithering (hysteresis), and pick up the pace. Record short
`make remote T=skirmish-shots` sequences or a scripted watch-match and describe what a spectator sees.

**X5. A CPU opponent that maneuvers.** Promote a commander that uses the new behaviors: flanking groups, a visible
formation charge (a scout V), focus fire, pulling hurt units back, baiting with fast units. It must beat plain brains
on the ladder before becoming the skirmish default. Formations here are the CPU's; the player's are automatic (control).

**X6. The ladder and matrix re-run.** Finish round 2's `a5`/`a6` runs, then re-run champion selection with combat's new
weapons and driving (after CP2 and combat X2/X4 land: coordinate via Status). Report CPU cost per unit per tick; keep
≤ round 2's.

- **Stretch:** explanation overlays for the lead's playtests (why a unit is doing what it does), and a difficulty knob
  for the CPU (reaction delay, accuracy).

## How to verify

`make remote T=check`; your scenarios (`make remote T=ai-scenarios`) including the response-guarantee and the new
movement scenarios; the ladder on builder0; screenshots or recorded watch-match frames **looked at**, with a
description of what the fight looks like. The sim baseline changes on purpose, with the reason.

## Don't touch

Weapons, movement physics, and `Match` (combat; request changes), selection, groups, and the Orders implementation
(control; you execute orders), effects (feel), models (assets).

## Status

- 2026-09-15: brief written for round 3. Nothing started.
- 2026-09-15 (ai agent): baseline `make remote T=check` green at 72cc9f3. CP1 and CP2 not announced yet, so X1–X3
  build against K1/K2/K3 through adapters in `game/ai/` (see Decisions).

### Plan (ordered, smallest foundation first)

1. **X1 orders always win** — **done** (built against K1 through `OrderFeed` + `StubOrders`; re-verify against control's
   real `Orders` at CP1).
2. **X2 movement while fighting** — **done for tracks** (`CombatMotion` styles strafe / angle-weave / attack runs, short
   halt); wheels: the pure layer respects turning circles, the driving (`Steering` for wheels) waits for K3 at CP2.
3. **X3 evasion and weak spots** — **mostly done**: busy-target flanking, front armor toward every gun, dodge model
   (`IncomingFire`, adapter until K2). The dodge-rate bar is a pending scenario until combat's slower tank shells land.
4. **X4 make it visible** — **done for today's weapons**: `make ai-shots` (trails + intents, looked at), wide flank arcs,
   light hulls break away at speed, dithering measured (4.7 option switches per unit per minute); re-tune after CP2.
5. **X5 CPU commander** — **done**: policy v6 beats plain brains 45–19 over four same-army mirrors and is
   `CpuCommander.DEFAULT_POLICY`; making it the skirmish default is control's one-line change (request below).
6. **X6 ladder and matrix** — round 2's runs done; re-run after CP2 + combat X2/X4; CPU cost to bring back down.
7. Stretch: CPU difficulty knob — **done** (`--<team>-difficulty=easy|normal|hard`); explanation overlay — open.

### Report (kept current)

**Done (measured):**
- **X6 part 1** (round 2's unfinished runs, round-2 weapons, builder0): ladder `a6,a5` on `combined_arms`: **a6 11–5 a5**
  (ELO 1070 / 930). Scout matrix (12 matches per pairing) with a6 / a5 as the default brain: scouts beat artillery 10–2 /
  6–6 and lose everything else (vs tank, IFV, Lancer 0–12; Burner 2–10) either way: a5's orbiting doesn't rescue them.
- **X1 orders always win**: worst response **1 tick** over 13–14 move orders issued mid-brawl (interrupting ENGAGE,
  SPOT, HOLD, RETREAT, RECHARGE, TAKE_COVER); mutation check (orders only on think ticks) → 6 ticks, the test fails.
  Attack-move kills a scout beside its route, then arrives (24 s, 3 m off). Attack keeps fire on the ordered target
  (475 ticks vs 0 on a nearer enemy). Hold drifts 0.0 m and still shoots behind it. Follow stays within 18 m of a moving
  IFV 100% of the time. An idle unit pushed 57 m off its post is back in 7.0 s. Stuck-state timeouts cost nothing on
  the ladder (with vs without: 26–22 over two doctrines).
- **X2/X3, new champion x3** (fights on the move, weaves, flanks busy targets, dodges), round-2 weapons: beat a6
  **14–10** on `individuals` and **17–7** on `combined_arms` (94 kills vs 31). Tank duel: moving 79–84% of the time
  (a6 1%) with 100% of hits on fronts; two tanks on one get its side for 3.9–5 s of 20; a scout ordered onto a tank
  makes 4 wide attack runs in 25 s with all 22 hits in its side or rear.
- **What a spectator sees** (`make remote T=ai-shots`, frames looked at): moving units leave 20–50 m sweeping arcs while
  round-2 brains sit as dots; tanks rock forward and back nose-on and lurch to a stop to fire; the scout loops 50 m past
  the tank and comes back on the other flank; a hurt IFV peels off to recharge; nameplates read "ENGAGE Rust_A_1 - going
  for its side, weaving, front armor on it".
- The road there (ladder vs a6, tank mirror): circling side-on 0–24 → short halt 3–13 → weave 4–12 → turn cost and
  busy-target flanking 14–10. Mirror hits by face: a6 front 66%; first cut front 36%, side 49%, rear 15%; weave front 56%.
- Dodging: IFV vs a cannon at 30–45 m, shells that miss: a6 0%, x2/x3 6–15%. Physically marginal with 70 m/s shells
  (see Requests); the ≥ 35% bar is a pending scenario.
- **CPU (X6 part):** 50 brains, back to back on builder0: a6 3.9–4.6 ms per tick; x3 first cut 5.0–6.1 ms, now
  **4.7 ms** (direct moves skip the navmesh for CombatMotion's checked hops, motion re-plans every 15 ticks unless
  something changed, a 2 m line-of-sight memo for "can that gun shoot me", shared per-tick ally and intel-name tables,
  the multi-threat armor loop only for heavy hulls). `make ai-perf BRAIN=a6` profiles any variant and prints the parts
  (situation 1.6 ms, decide 0.56, act 0.53 of which motion 0.30, move 0.33, weapon 0.84). The ladder after these:
  x3 15–9 (individuals), 21–3 (combined_arms).
- **K1 aligned with control's branch** (read, not merged): brains read control's per-unit `goal`, `goal_position` for
  follow, `pace_factor`, and `station` for idle posts; stop completes once stopped, attack-move once arrived with
  nothing engaged; order identity ignores live values. `TankBrain.EXECUTES_ORDERS` makes control's stand-in
  OrderExecutor leave brains alone. AiScenario.orders() uses control's `Orders` once it exists.
- **X5 CPU commander** (details and the variant table in unit_ai.md "A CPU that maneuvers"): army plans by squad role
  (muster, advance in a wedge with scouts screening in a V, the main line assaults while other line squads with ≥ 40% of
  its strength swing 45 m out to a flank, scouts charge artillery and Lancers in a V, worn squads rest, withdraw when
  outmatched). Same-army mirrors (x3 brains both sides), v6 vs plain: armor 6–10, balanced 13–3, swarm 16–0,
  anvil_hammer 10–6 = **45–19**; v2 (round 2) lost to plain brains 3–13. The scout V at speed: 16.4 s of a 45 s swarm
  attack, spread up to 72 m. Frames: `make remote T="ai-shots STAGE=cpu_charge"` (IFVs swing 40 m arcs round the
  defenders, scouts charge the battery).
- **X4:** a flanker still in front of its target swings 20 m wider ("swinging wide"); light hulls break away forward at
  full speed instead of backing off at 4–5 m/s ("breaking away"); x3 after both: 16–8 (individuals), 21–3
  (combined_arms) vs a6. Dithering: 4.7 option switches per unit per minute (a6 2.7).
- **Wheels ready for CP2:** `Steering.drive_toward_wheels` (pure pursuit, full lock far off the nose, three-point turns
  only for points inside the turning circle) used for `locomotion: wheels`; against a car double of combat's K3 wheels: a
  point 60 m behind in 8.9 s, 9 m behind in 5.4 s (loop), inside the turning circle in 3.5 s (2 s reversing).
- Sim baseline: `397d0a3e14891d2d` (X1 timeouts), `9d936357e51d78dd` (x3 champion), `fe0a7942ac259713` (the CPU pass
  and K1 alignment), `08c31b3dccbcb72e` (X4 flank and breakaway), each on purpose. CPU at 50 brains: x3 4.5 ms, a6 3.7.

- **Checkpoint preview** (a throwaway clone with `stream/control` and `stream/combat` merged onto this branch; nothing
  merged here): with control's real `Orders` and combat's weapons and wheels, 550 of 551 tests passed after four fixes
  now on this branch: **local avoidance** (a friend parked in the way is passed 5 m beside it: a wheeled IFV looped its
  unstick routine against a parked tank for 8 s), **live follow stations and group pace** (a follow's goal was read once,
  so the follower parked at the leader's first station), **wheels finish a move within 0.6 turning radii and move on to
  the next path waypoint within 0.8** (a car orbited tight path corners and its goal), and **stop completes after 20
  ticks at rest** (it finished before the unit had even started moving). Scenarios there: 23 of 27; left for after CP2:
  the cover duel (320-damage shells on a 5 s reload punish peeking into a loaded gun: next, peek in the enemy's reload
  window) and the pending dodge bar (x3 tanks dodge 22% of combat's shells vs a6 11%; IFVs 11% vs 6%).

- **X3 reload windows (variant x4, opt-in):** brains see when an enemy's slow gun fired (a muzzle flash), keep a cover-fire
  target in memory through its reload, peek only while it reloads (or isn't watching), bait a watching gun with a quick
  flick out of cover, and short-halt only when the target can't punish it. Wall duel vs a durable cannon, 30 s: x3 takes
  8 hits (round-2 weapons) / 6 (combat's), x4 takes 4 / 4. But on the ladder x4 isn't better than x3: 31–41 with
  round-2 weapons (individuals 12–12, combined_arms 8–16, balanced 11–13) and 36–36 with combat's (8–16, 16–8, 12–12),
  so x3 stays champion; re-test x4 after CP2.
- **Integration fix:** order execution led moving targets with `Shell.SPEED` (70 m/s) for every weapon; it now uses the
  weapon's `projectile_speed_mps` (K2: combat's 25 mm rounds fly at 180 m/s, so brains would have over-led).
- **Difficulty knob** (`game/ai/difficulty.gd`, stretch): easy thinks every 18 ticks and its aim wanders up to 2 m
  (deterministic pattern, no RNG); hard thinks every 4. Balanced mirror: normal beats easy 15–1 (easy hits 53% vs 74%),
  hard vs normal 8–8 (faster reactions alone don't win: a harder level needs better decisions, not speed).

**Decisions (with reasons):**
- Brains read K1 through `OrderFeed` (duck-typed: `Match.orders` when the field exists, else an attached object), so
  ai never names control's classes and works before and after CP1 unchanged.
- A unit's destination is the order's `slot` [x, z] if present, else `to` + `slot_offset` (world meters), else `to`.
- Brains call `Orders.complete(unit)`: move/attack-move on arrival (3.5 m, or 12 m after 3 s without progress, for
  crowded slots), attack/follow when the target is gone, stop at once. Hold never completes.
- Orders are absolute: move, hold, and follow never retreat or wander; attack fights only its target (in any style the
  brain likes) and chases it to its last sighting; attack-move fights what it meets (visible, within weapon range +
  10 m) and retreats only when about to die. Why: pillar 7 ("orders always win"), StarCraft semantics.
- **Regroup = a post:** every finished order leaves the unit a post (its slot); idle units fight within 30 m of it and
  drive back when they drift farther. No squad bookkeeping needed, and it works per unit for any group shape.
- **No stuck states:** any autonomous option kept past its timeout (fights: since the last shot) or driving 3 s
  without progress goes on a 5 s cooldown (×0.25). Orders never time out.

- **Fighting on the move = context steering** (`CombatMotion`): one pure scoring over 32 candidates with styles as
  weight tables, so combat's new numbers retune data, not code. Heavy hulls weave nose-on (front armor 0.5×) and short
  halt to fire; light turrets circle; fixed guns make runs. A pivot costs seconds of standing still, so jinks shuffle
  forward and back. Why: the ladder (each step above) and the lead's "circle your opponent".
- **Champion x3** by the ladder rule (out-rates a6 and beats it head to head on both doctrines); the skirmish and match
  runner use it by default. a6 stays runnable (`--green-brain=a6`).

**Questions for the lead:** none yet.

**Requests to other streams:**
- control (K1, after reading your branch): done on my side: brains read `goal`, `goal_position`, `pace_factor`,
  `station`, call `complete`, and declare `TankBrain.EXECUTES_ORDERS`, so `OrderExecutor` can go once both branches
  merge. I added a one-line guard in your `CommandIcons.draw_unit` (see Merge notes): `tactical_map.gd:633` draws icons
  for units projected tens of thousands of pixels off-screen; culling them before drawing would be the real fix.
- combat: the `Match.orders` field (K1) as planned.
- combat (X2 weapons, measured reasons): (1) **tank shell flight time ≥ ~0.7 s at 30–50 m** (≤ ~60 m/s) if dodging should
  read: with 70 m/s shells a 14 m/s² hull moves ~2 m off the shooter's lead before impact, less than half a hull, so
  even strafing IFVs dodge only 6–15%. (2) **Turret stabilization:** the turret turns relative to the hull, so a tank
  pivoting at 80°/s drags its 50°/s turret off target; world-space turret aim would let tanks shoot on the move (today
  they must short-halt). (3) Moving spread ×2.5 at full speed punishes moving fire; arcade feel wants it smaller for
  turrets (accuracy measured 82–86% either way at today's ranges, so it matters most for long shots).
- control (skirmish): turn the CPU commander on by default in skirmish (`skirmish_mode.gd` creates `CpuCommander` only
  with `--commander`); policy v6 beats plain brains 45–19, so X5's bar is met. Its SquadCommands need the CPU's doctrine
  squads (not K1), which skirmish already loads.
- control (shared test): `test_command_icons` requires player words for every `TankBrain.OPTIONS`; the order-only
  options live in `TankBrain.ORDER_ONLY_OPTIONS` (MOVE, FOLLOW, PURSUE) and read as "Move"/"Follow"/"Pursue" through the
  fallback; add words when convenient ("Moving", "Following", "Closing in").

**Known issues:**
- **CPU:** x3 4.7 ms per tick at 50 brains vs a6 3.9–4.6 ms on the same machine (round 2's 7–9 ms was the laptop).
  Next levers if phones need it: order execution's per-tick line of sight for named targets (0.84 ms), contact
  dictionaries (0.5 ms), cover queries for moving units (0.4 ms).

- Heavy tanks can't dodge (physics, above); they take hits on the front armor instead.

**Merge notes (shared files):**
- `game/ai/order_controller.gd` will conflict with stream/combat's one-line lead-speed edit in `_apply_weapon`: take
  ai's version (the same per-weapon `projectile_speed_mps` fix plus the difficulty aim wander). Combat's edits to
  `game/ai/fire_lanes.gd` and `tests/ai_scenarios/scenario_cover.gd` are applied here byte-identically.
- `tools/remote.sh` is **byte-identical to stream/control's** (it finds the running Xwayland's auth file; a stale one hung
  every rendering target on builder0), and `game/ui/command_icons.gd` is **byte-identical to stream/combat's** (icons
  beyond 16384 px are skipped: army-loop-smoke failed ~1 run in 3 on a (53141, 63901) px icon). All three streams hit
  both bugs; with identical copies the merges don't conflict on them (combat's remote.sh differs: take control's).
