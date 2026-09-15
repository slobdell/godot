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
