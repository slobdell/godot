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

- 2026-09-15: brief written for round 3.
- 2026-09-15 (ai agent, unattended): baseline green at 72cc9f3. CP1 and CP2 were announced ready in control's and combat's
  briefs but not merged to `main` during this run, so ai built against K1/K2/K3 through adapters, then **previewed both
  checkpoints in a throwaway merge** (nothing merged into this branch) and fixed what broke. Details and tables:
  [../unit_ai.md](../unit_ai.md) "Round 3". Last `make remote T=check` green on this branch's last commit.

### Plan and state

1. **X1 orders always win** — **done**; checked against control's real `Orders` in the preview.
2. **X2 movement while fighting** — **done** (CombatMotion: strafe, weave, attack runs; wheels steering for K3).
3. **X3 evasion and weak spots** — **done except the dodge bar**: busy-target flanking, front armor toward every gun,
   dodging (`IncomingFire`, K2 when present), reload windows and baiting (opt-in x4). The "dodge ≥ 35% of tank shells"
   scenario stays pending: physically marginal at combat's shell speeds (request below).
4. **X4 make it visible** — **done**: `make ai-shots` (trails, intents, explain lines), wide flanks, fast breakaways.
5. **X5 CPU commander** — **done**: v6 is `CpuCommander.DEFAULT_POLICY`; skirmish default is control's switch (request).
6. **X6 ladder and matrix** — round 2's runs **done**; the re-run with combat's weapons **done provisionally in the
   preview**; **waiting on the real CP2 merge** for the official one.
7. **Stretch** — difficulty knob **done**; explanation overlay **done**.

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
- **What a spectator sees** (frames looked at; all 16 `make remote T=ai-shots` frames retaken after main's remote.sh fix
  7dc7bdc, all distinct, same picture): moving units trace 20–50 m arcs where round-2 brains sit still; tanks
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
- Sim baseline changed on purpose five times; now `470f6950f0845991` (glibc-2.43).

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
- Champions by the ladder rule: brain **x3**, commander **v6**. x3 stays the default even though parked brains edge it with
  combat's weapons in the preview (question 1).
- Same-army mirror armies for commander ladders (`tests/ai_scenarios/armies/`): `cpu:` armies are seeded per side.

**Questions for the lead:**
1. **Alive vs. optimal under round-3 weapons** (pillar 7): in the preview, parked round-2 brains beat moving ones 69–51.
   I kept the moving brain as the default (pillar 7; the gap is modest and should shrink with combat's turret
   stabilization or a softer moving-fire spread). If the CPU feels weak in playtests, `--green-brain=a6 --rust-brain=a6`.

**Requests to other streams:**
- **control:** turn the CPU commander on by default in skirmish (`skirmish_mode.gd` creates it only with `--commander`;
  v6 meets X5's bar). Optional: player words for `TankBrain.ORDER_ONLY_OPTIONS` (MOVE, FOLLOW, PURSUE: "Moving",
  "Following", "Closing in"); cull off-screen icons in `tactical_map.gd` before drawing (the 16384 px guard is a backstop).
- **combat:** (1) **turret stabilization** (a hull turning at 80°/s drags a 50°/s turret off its target; moving tanks lose
  the first shot to parked ones); (2) a **softer moving-fire spread** for turrets (2.5× at full speed); (3) for dodging to
  read, **tank shells taking ≥ 0.7 s over 30–50 m** (a 14 m/s² hull moves ~2 m off the lead in 0.5 s, under half a hull).

**Known issues:**
- Heavy tanks can't dodge tank shells (physics); they take them on the front armor.
- The dodge bar (≥ 35% of tank shells for a light unit) is pending: IFVs reach 6–15%.
- With combat's weapons single matches swing; 16-match ladders are noisy: on 12 more combined_arms matches (seeds 1–6,
  both colors) x3 won 6, a6 5, one draw, and x3's tanks lived 37% longer on the same number of shots, so the preview's
  combined_arms deficit (14–30) is weak evidence. Re-measure with more seeds after the merge.

**What to playtest (after the merges):**
- `make skirmish` (with control's desktop controls): order units mid-fight (they respond at once), push one away (it
  regroups), watch tanks weave and IFVs circle, scouts make runs. Add `--commander` for the maneuvering CPU,
  `--ai-explain` for the lines, `--rust-difficulty=easy` for a gentler CPU.
- `make remote T=ai-shots` (frames in `build/ai-shots/`: duel, scout runs, brawl, CPU charge).
- `make remote T=ai-scenarios`, `make remote T="ai-perf BRAIN=x3"`, `make remote T="ai-ladder VARIANTS=a6,x3 LADDER_DOCTRINE=combined_arms"`,
  commander: `VARIANTS=x3,x3+v6 LADDER_DOCTRINE=res://tests/ai_scenarios/armies/balanced.json`.

**Next steps:**
1. After CP1+CP2 merge: `git merge main`, rerun `make remote T=check`, the scenarios, the brain ladder (a6, x3, x3m, x4)
   and the commander ladder; re-tune x3 for combat's final weapons (especially combined_arms); re-test the dodge bar.
2. If combat stabilizes turrets or softens moving spread, re-run the x3 vs a6 ladder first: that's the expected fix.
3. Unit-vs-unit matchup matrix with the final champion (combat's `make matchups`).

**Merge notes (shared files):**
- `game/ai/order_controller.gd` conflicts with stream/combat's one-line lead-speed edit in `_apply_weapon`: take ai's
  version (the same per-weapon fix plus the difficulty aim wander). Combat's edits to `game/ai/fire_lanes.gd` and
  `tests/ai_scenarios/scenario_cover.gd` are applied here byte-identically.
- `tools/remote.sh` (7dc7bdc) and `game/ui/command_icons.gd` (8dbe23e, the army-loop-smoke triangulation flake) are
  main's, merged here 2026-09-15; control's and combat's copies of those files differ: take main's.
- Sim baseline: take the one recorded after the final merge (`make remote T=sim-baseline-record`).
