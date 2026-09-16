# Stream: ai (units that feel alive; a CPU that maneuvers)

> **Archived 2026-09-15:** round 3 is merged into `main`. This brief and its Status are the record of what the stream did;
> the current round is in [../../../workstreams.md](../../../workstreams.md).

> Read [../orchestration.md](../../../orchestration.md), [../game_design.md](../../../game_design.md) (*Round 3 direction*, pillar
> 7, *Unit AI*), [../workstreams.md](../../../workstreams.md) (you consume K1, K2, K3), [../unit_ai.md](../../../unit_ai.md) (your
> round-2 architecture and ladder), and [../determinism.md](../../../determinism.md). You own `game/ai/` except
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
- **Unfinished from round 2** (close-out in [archive/round2/ai.md](../round2/ai.md)): the ladder `a5` vs `a6` on
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

- 2026-09-15: brief written for round 3.
- 2026-09-15 (ai agent, unattended): baseline green at 72cc9f3. CP1 and CP2 were announced ready in control's and combat's
  briefs but not merged to `main` during this run, so ai built against K1/K2/K3 through adapters, then **previewed both
  checkpoints in a throwaway merge** and fixed what broke; both checkpoints have since been merged here for real, and
  all six of combat's requests to ai are done. Details and tables: [../unit_ai.md](../../../unit_ai.md) "Round 3".
  **X1–X6 and both stretch items are complete**, nothing is blocked, and one design question is open for rules and
  combat (what a scout's counter is). `make remote T=check` green on the last commit (558 tests, scenarios 33 passed +
  1 pending, sim baseline `d7967d8b36d4417b` for glibc-2.43, recorded on purpose).

### Plan and state

1. **X1 orders always win** — **done and verified at CP1** (main 07e07bf merged 2026-09-15): `make remote T=check` 509
   passed, scenarios 27 passed + 1 pending, now running against control's real `Orders` (AiScenario.orders() prefers it;
   StubOrders is only a fallback). Response worst 1 tick over 14 orders; control's executor stands down for brains
   (`TankBrain.EXECUTES_ORDERS`).
2. **X2 movement while fighting** — **done** (CombatMotion: strafe, weave, attack runs; wheels steering for K3).
3. **X3 evasion and weak spots** — **done except the dodge bar**: busy-target flanking, front armor toward every gun,
   dodging (`IncomingFire`, K2 when present), reload windows and baiting (opt-in x4). The "dodge ≥ 35% of tank shells"
   scenario stays pending: physically marginal at combat's shell speeds (request below).
4. **X4 make it visible** — **done**: `make ai-shots` (trails, intents, explain lines), wide flanks, fast breakaways.
5. **X5 CPU commander** — **done**: v6 is `CpuCommander.DEFAULT_POLICY`; skirmish default is control's switch (request).
6. **X6 ladder and matrix** — **done** after CP1 and CP2 merged: the official brain ladder (a6, x3, x3m, x4 on four
   armies, 16 matches per pairing), the commander ladder (x3 vs x3+v6 on four mirrors) and combat's matchup matrix all
   re-run on builder0 against round-3 weapons, then a second four-army run at 6 seeds to decide the champion. Results
   under "Report"; the champion changed by the ladder rule from x3 to **x4**.
7. **Stretch** — difficulty knob **done**; explanation overlay **done**.
8. **After CP2, combat's requests** (combat.md "Requests to other streams"): (a) dodging **done** (x3), (b) weak spots
   **done** (feature `weak_spots`), (c) wheels **done** (Steering's turning circles, CombatMotion's reachable headings),
   (d) artillery BOMBARD **done** (stays dug in on a moving target), (e) `matchups.gd` bursts and engine deck **done**,
   (f) lone units through the center crate's shadow **done** (side lane).

### Report

**Done (measured; builder0; round-2 weapons unless marked "preview"):**
- **Round 2's leftovers:** a6 beat a5 11–5 on `combined_arms`; scouts lose every matchup but artillery with a6 or a5.
- **X1 orders:** worst response **1 tick** over 13–14 orders issued mid-brawl, interrupting ENGAGE, SPOT, HOLD, RETREAT,
  RECHARGE, TAKE_COVER, COVER_FIRE (mutation check: think-tick polling → 6 ticks, test fails). Attack-move kills a scout
  on its route, then arrives; attack keeps fire on its target (475 ticks vs 0 on a nearer enemy); hold drifts 0.0 m and
  still shoots; follow stays within 18 m 100%; a unit pushed 57 m off its post regroups in 7 s. Stuck-state timeouts cost
  nothing (26–22 with vs without). Preview: control's group-move, rejoin, stop/hold/follow tests pass with brains
  executing orders.
- **X2/X3 champion x3** (moving, weaving, busy-target flanking, dodging): beat a6 16–8 (individuals) and 21–3
  (combined_arms). Tank duel: moving ~80% of the time (a6 1%), 100% of hits on fronts; two tanks on one see its side or
  rear 4–7 s of 20; a scout ordered onto a tank makes 3–4 wide attack runs with every hit in its side or rear. Road to
  it: circling side-on 0–24 → short halt 3–13 → weave 4–12 → turn cost + busy-target flanking 14–10.
- **What a spectator sees** (frames looked at; all 16 `make remote T=ai-shots` frames retaken again after the champion
  change, all distinct: a scout loops around a tank and breaks away beside it, two IFVs converge on a gun by the control
  point "going for its side, weaving, front armor on it", hurt units peel off with tracers crossing behind them): moving units trace 20–50 m arcs where round-2 brains sit still; tanks
  rock nose-on and lurch to a stop to fire; the scout loops 50 m past a tank and returns on the other flank; a hurt unit
  peels off to cover; the CPU's IFVs swing 40 m arcs round defenders while its scouts charge the battery in a V; explain
  lines show each move goal and target.
- **X5 commander v6** vs plain x3 on same-army mirrors: **45–19** (armor 6–10, balanced 13–3, swarm 16–0, anvil_hammer
  10–6); preview **38–26**. Round 2's v2 lost to plain brains 3–13. The scout V at speed: 16.4 s of a 45 s attack.
- **CPU:** 50 brains, back to back: x3 4.5–4.7 ms per tick, a6 3.7–4.6 (round 2 reported 7–9 on the laptop). Preview 3.9.
- **Difficulty:** normal beats easy 15–1 (easy hits 53% vs 74%); hard vs normal 8–8.
- **Reload windows (x4):** wall duel vs a durable cannon, hits taken 8 → 4 (preview 6 → 4); ladder vs x3 31–41 / 36–36.
- **Preview integration fixes** (now on this branch): local avoidance of parked friends, live follow stations and group
  pace, wheels arrival and waypoint reach, stop settle time, per-weapon lead speed (`projectile_speed_mps`).
- **Provisional X6 (preview, combat's weapons):** x3 vs a6 51–69 pooled (individuals 18–14, balanced 19–25,
  combined_arms 14–30); no probe closed it (no dodging, matchup targets, shoot-and-scoot, halting only 3 s+ reloads).
  Dodging tank shells: x3 tanks 22% vs a6 11%, IFVs 11% vs 6%.
- **Official X6 after CP1+CP2** (builder0, 16 matches per pairing, both colors, four armies). Brains, wins across the
  four armies: **x4 102**, x3m 97, x3 96, a6 89; x4 beat x3 **36–28** head to head (13–3 individuals, 9–7
  combined_arms, 8–8 balanced, 6–10 armor). The preview's "parked brains win" result did not survive the real merge:
  a6 leads only on combined_arms. **Commander v6** vs plain x3: **58–37–1** (balanced 18–6, swarm 20–4, armor 9–14–1,
  anvil_hammer 11–13), so v6 stays the default.
- **Weak spots after CP2** (combat's request b, feature `weak_spots`): a matchup-aware scout orbits to a tank's stern
  and bursts in while the cannon reloads: **57 of 71 hits on the engine deck** (19 of 46 before), and the tank loses 173
  instead of 84 in 25 s.
- **Champion is now x4** (x3 + reload windows), by two independent four-army ladder runs (144–96 matches per army, both
  colors): **x4 beat x3 92–68** over 160 head-to-head matches (17–7, 14–10, 12–12, 13–11 in the second run). The
  deck-seeking **x4mw** (x4 + matchups + weak spots) beat x4 **93–67** over the same runs and led three of four tables,
  but is only even with x3 (**48–48**), is last on the all-armor army (29–43), and sends scouts onto a tank's engine deck
  at 3 m — which rules' catalog test forbids (`test_units_roster::test_a_scout_keeps_an_enemy_tank_in_sight_but_out_of_its_range`).
  So x4mw stays opt-in (`--green-brain=x4mw`) until rules and combat settle what a scout's counter is (request below).
  Pooled wins over all four armies, 288 matches each: x4mw 148, x4 146, x3m 144, x3 138.
- **Lone units (request f):** two lone tanks from mirror spawns with no objective passed **9 m apart, never seen** (the
  line between mirror positions always runs through the center crate; mirror-image lanes still passed at 48 m unseen).
  With both teams' lanes on the same side of the map they meet head-on: **first sighting at 61 m after 7.3 s**, 4 shots
  each.
- **A boxed-in unit used to freeze** (found by looking at `build/ai-shots/scout_runs_16s.png`, where the scout sat
  against its target for 6 s): every candidate direction was inside a grown obstacle, so `CombatMotion` returned nothing
  and the brain fell back to "face" — firing from a standstill, round 2's complaint. It now nudges out along the best
  direction inside the arena: the same scout makes 3 full attack runs over 25 s instead of parking at 10 m.
- Sim baseline changed on purpose; recorded again after this round's behavior changes.

**Decisions (with reasons):**
- K1 through `OrderFeed`, duck-typed (`Match.orders` or the attached object): ai never names control's classes. A unit's
  destination is control's per-unit `goal`; a follow's station and a group's pace are read live every think.
- Brains call `Orders.complete`: move on arrival (3.5 m; wheels 0.6 turning radii; 12 m after 3 s without progress),
  attack-move once there with nothing engaged, attack/follow when the other unit is gone, stop after 20 ticks at rest.
  `TankBrain.EXECUTES_ORDERS` retires control's stand-in executor.
- Orders are absolute (move/hold/follow never wander or retreat; attack fights only its target; attack-move fights what
  it meets and retreats only when about to die): pillar 7 and StarCraft semantics. Regroup = a post left by every
  finished order (30 m leash). No stuck states: timeouts and stalls put options on cooldown.
- Fighting on the move is one pure context-steering layer with styles as weight tables, so new weapon numbers retune data.
- Champions by the ladder rule: brain **x4**, commander **v6** (the preview's "parked brains win" result did not survive
  the real merge). A variant is adopted only when it beats the champion head to head over the whole four-army field,
  which is why x4mw — better than x4, even with x3 — stays opt-in.
- Same-army mirror armies for commander ladders (`tests/ai_scenarios/armies/`): `cpu:` armies are seeded per side.

**Questions for the lead:** none open. (Round 3's question — whether parked round-2 brains beat moving ones under
combat's weapons, which the checkpoint preview suggested 69–51 — was answered by the official X6 run after the real
merge: moving brains lead on three of four armies, a6 only on `combined_arms`. Pillar 7 and the ladder now agree, so no
trade-off to rule on. If the CPU ever feels weak in a playtest, `--green-brain=a6 --rust-brain=a6` still swaps it.)

**Requests to other streams:**
- **control:** CP1 is in: `OrderExecutor` now does nothing for brain units (`TankBrain.EXECUTES_ORDERS`), so it can be
  deleted when convenient. Turn the CPU commander on by default in skirmish (`skirmish_mode.gd` creates it only with `--commander`;
  v6 meets X5's bar). Optional: player words for `TankBrain.ORDER_ONLY_OPTIONS` (MOVE, FOLLOW, PURSUE: "Moving",
  "Following", "Closing in"); cull off-screen icons in `tactical_map.gd` before drawing (the 16384 px guard is a backstop).
- **rules + combat:** **what is a scout's counter?** Rules' catalog says scouts are `good_vs` artillery and lancers and
  `test_units_roster` requires a scout to keep a tank spotted from beyond 70 m; combat's request (b) says a scout's
  stream through a tank's engine deck does ×1.13 instead of ×0.05, which only pays at 3–10 m astern. Both can't hold. My
  measurement: the deck-hunting brain (x4mw) takes a tank to 134 of 300 hull in 25 s, but is the weakest variant on the
  all-armor army. Whichever you pick, I'll make it the champion's behavior.
- **combat:** (0) **a scout's machine gun cannot get through a Lancer's shield**, so the catalog's counter (scout
  `good_vs` lancer) never pays: 3.5 damage × 0.6 shield multiplier × facing = 15 (front) to 29 (rear) shield dps, and
  the shield holds 120 and recharges 45/s after 4 s. Breaking it needs ~8 s of unbroken hits; an attack run gives 1–2 s.
  Measured: a scout on a stopped Lancer fired 37 rounds in 20 s for **0 net damage** (scenario `ai_cp2_scout_vs_lancer`),
  and in your matrix #6 scout vs lancer is 0:12 in 21 s. Knobs: the MG's `shield_multiplier`, the recharge delay
  against light hits, or accept scouts as spotters and change the catalog's `good_vs`. Same for scout vs tank if the
  engine deck isn't enough (the deck itself works: 57 of 71 hits land there now).
  (1) **turret stabilization** (a hull turning at 80°/s drags a 50°/s turret off its target; moving tanks lose
  the first shot to parked ones); (2) a **softer moving-fire spread** for turrets (2.5× at full speed); (3) for dodging to
  read, **tank shells taking ≥ 0.7 s over 30–50 m** (a 14 m/s² hull moves ~2 m off the lead in 0.5 s, under half a hull).

**Known issues:**
- Heavy tanks can't dodge tank shells (physics); they take them on the front armor.
- The dodge bar (≥ 35% of tank shells for a light unit) is pending: IFVs reach 6–15%.
- With combat's weapons single matches swing; a 16-match pairing is ±2 wins of noise, so champions are decided on the
  pooled four-army record, not one army (the official X6 run has a6 leading combined_arms while x4 leads three others).
- Scouts still can't hurt a Lancer (its shield outlasts their machine gun; combat request 0) and artillery wins nothing
  in combat's matrix: both are weapon numbers, not behavior.

**What to playtest:**
- `make skirmish` (with control's desktop controls): order units mid-fight (they respond at once), push one away (it
  regroups), watch tanks weave and IFVs circle, scouts make runs. Add `--commander` for the maneuvering CPU,
  `--ai-explain` for the lines, `--rust-difficulty=easy` for a gentler CPU.
- `make remote T=ai-shots` (frames in `build/ai-shots/`: duel, scout runs, brawl, CPU charge).
- `make remote T=ai-scenarios`, `make remote T="ai-perf BRAIN=x3"`, `make remote T="ai-ladder VARIANTS=a6,x3 LADDER_DOCTRINE=combined_arms"`,
  commander: `VARIANTS=x3,x3+v6 LADDER_DOCTRINE=res://tests/ai_scenarios/armies/balanced.json`.

**Next steps:**
1. If combat changes the machine gun's shield multiplier or the shield recharge (request 0), re-run
   `make remote T="ai-ladder VARIANTS=x3,x4mw LADDER_DOCTRINE=combined_arms"` and combat's `make matchups`: scouts are
   the units whose behavior is currently wasted.
2. If combat stabilizes turrets or softens moving spread, re-run x3 vs a6 as well: that was round 3's expected fix for
   moving brains.
3. Re-test the dodge bar (≥ 35% of tank shells for a light unit) once shells fly slower.

**Merge notes (shared files):**
- `game/ai/order_controller.gd` conflicts with stream/combat's one-line lead-speed edit in `_apply_weapon`: take ai's
  version (the same per-weapon fix plus the difficulty aim wander). Combat's edits to `game/ai/fire_lanes.gd` and
  `tests/ai_scenarios/scenario_cover.gd` are applied here byte-identically.
- `tools/remote.sh` (7dc7bdc) and `game/ui/command_icons.gd` (8dbe23e + 13685ce, the army-loop-smoke triangulation
  flake) are main's, merged here 2026-09-15; control's and combat's copies of those files differ: take main's.
- Sim baseline: take the one recorded after the final merge (`make remote T=sim-baseline-record`).
