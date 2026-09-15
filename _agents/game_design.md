# Game design: what Tank Squad is (round 2 onward)

> **Source of truth for the game's rules and player experience.** Written 2026-09-15 from the lead's
> decisions after round 1. It **supersedes** earlier plans where they conflict: MechWarrior-style loadouts
> (weapons per hardpoint, components, heat sinks) and "players author doctrine instead of commanding" are
> out as the core loop. Numbers live in [balance.md](balance.md); the look in [art_direction.md](art_direction.md);
> where it's going commercially in [vision.md](vision.md). Every stream brief builds toward this file. Decisions
> marked **(lead)** are the lead's; **(proposed)** are defaults the streams may tune, recording why.

## The game in one paragraph

A **die-hard real-time squad tactics game** in a Death Race gladiator arena. Before each round you **spend a
budget on fixed unit types**: over-the-top converted war machines like the armored prison-bus dozer. You split
them into **up to 5 squads** and command **one squad at a time** with taps: pick a squad, tap where it goes.
Every vehicle is **smart on its own**. It uses cover, peeks out to shoot, picks targets its weapon is good
against, and avoids shooting its friends, because **friendly fire is real**. You win by combining units that
cover each other's weaknesses, like StarCraft's rock-paper-scissors, and by commanding squads better than your
opponent. Winning earns **credits** that unlock more unit types and bigger budgets.

## Pillars (use these to settle design arguments)

1. **For die-hard players.** Depth over dopamine. No pay-to-win, no premium currency, no shortcuts for sale,
   no ads, no energy timers **(lead)**. Progress comes only from playing well. The web version is free; the Android
   app is a paid app **(lead, intent)**.
2. **Over-the-top eccentric vehicles.** The lead: *"What made Mad Max and Death Race so good was the over-the-top
   eccentric vehicles. This makes it go from a nerdy army game to a fun game"* (in the spirit of the Metal Gear
   Solid era). Every unit is a character with a silhouette you remember ([art_direction.md](art_direction.md)).
3. **Simple units, deep combinations.** Units are **static** during a match: no upgrades, no weapon swaps
   **(lead)**. Depth comes from matchups, positioning, and squad coordination, not from menus.
4. **Smart autonomous units.** Even before any LLM, every vehicle behaves like a competent crew. The player
   decides *where* and *what*; units handle *how* **(lead)**.
5. **Mobile first.** Everything works with single taps, drags, and pinches on a phone. No right-click, no
   hover, no keyboard required **(lead)**.
6. **Readable at a glance.** You can always tell whose unit it is, what type it is, and where your squads are
   going, even in the dark neon arena.

## Units: fixed types that counter each other

Each unit type is a fixed package: chassis, one weapon, armor, speed, sight, cost. **No loadouts.**
Round 1's weapons don't disappear; they move onto unit types (the lead: *"the laser is awesome, but we'll
just move that to a different unit type"*).

### Starting roster (proposed; the lead named the scout, tank, and IFV)

| Unit | Real-world idea | Weapon and mount | Strong against | Weak against |
|---|---|---|---|---|
| **Scout** | armored rally truck / dune buggy | **fixed forward machine gun, no turret**: it only hits what it points at **(lead)** | artillery, lasers (fast, gets close, hard to track) | IFVs (fast turret, autocannon shreds light armor) |
| **Tank** | the prison-bus dozer (in the game now) | heavy cannon on a **slow turret** **(lead)** | IFVs, anything heavy that sits still | scouts (the turret can't track them), massed IFVs flanking |
| **IFV** (Bradley / Stryker) | armored bus or garbage truck | **30 mm autocannon**: fast fire, low penetration, **fast turret** **(lead)** | scouts and light units | tanks (can't get through front armor) |
| **Artillery** | crane carrier with a mortar battery | indirect arcing fire, minimum range, needs a teammate's sight | slow clumps, units holding still | scouts, anything that closes the distance |
| **Lancer** (laser) | converted power-utility truck | long hitscan beam, **heat-limited**, strips shields | tanks at range, shielded targets | scouts, IFV rushes |

The flamethrower becomes a candidate future unit (a close-range "Burner"). Future units are added one at a
time, each with a clear job and a clear counter.

**Rules that make matchups real** (proposed, rules stream): turret turn rate vs target angular speed decides
tracking; penetration vs armor facing decides whether a hit hurts; fixed-mount weapons only fire inside a narrow
forward arc; scouts' speed beats slow turrets; artillery's minimum range punishes being rushed. Matchups must
emerge from these mechanics rather than a damage multiplier table, and be **measured** with the match runner
(a unit-vs-unit matrix in balance.md).

**Keep from round 1:** Halo-style recharging shields over hull health (the lead chose them), finite ammo with
base resupply (rules stream may simplify if it doesn't add decisions), heat only where a unit's weapon uses
it (the Lancer). **Drop:** components, heat sinks, ammo racks, per-hardpoint weapons.

## Army, squads, budget

- **Before the round:** a budget, **buy any mix of units, and divide them into up to 5 squads** **(lead)**.
  Squads hold up to 5 units (formations place 5) **(proposed)**. Army size is limited by budget.
- **Squads are the unit of command.** The player commands one squad at a time and **switches squads with one tap**
  (a squad bar) **(lead)**.
- **Cosmetic paint** stays optional and free (never sold). Team identity comes from accent lights.

## Progression: credits earn more options

- **Winning earns credits** **(lead)**. Credits unlock **new unit types** and **higher budget tiers** (bigger armies).
- **Fairness guard (proposed; important for die-hard players):** matches are fought at a **shared budget tier**.
  Both sides get the same budget, so a veteran's bigger bank never buys a bigger army against a newcomer. Unlocks
  add *options*, not raw power: units are sidegrades by design (counters, not upgrades). Losing still earns a
  little. Competitive/ranked play (later) uses fixed budgets and the full roster.
- **No money in the loop**, ever (pillar 1).
- Progress is saved locally first (`user://`); an account system comes with online play (netcode, later).

## Commanding (mobile first)

- **Tap a squad** (its chip in the squad bar, or any of its units on the map) → **tap the ground or the radar**
  → it goes there **(lead)**. No right-click. Advanced (optional): hold-and-drag to set facing.
- **Formations get icons** that show the shape, drawn from the real formation geometry, so a non-military
  player sees what "wedge" or "echelon right" means **(lead)**. Drills (move, bound, hold, assault, break
  contact) get icons and one-line plain-language descriptions too.
- **The camera follows the action** **(lead)**: after an order to somewhere off screen, the camera smoothly tracks
  the squad (or frames squad + destination) instead of making the player zoom out and back in. Manual pan
  always overrides; a tap on the squad bar re-centers.
- Commands stay **SquadCommand data** ([tactical_map.md](tactical_map.md)), so the CPU, Claude, and a future LLM
  commander use the same verbs as the player.

## Unit AI: really good, before any LLM

The lead wants this *"really sophisticated"*. The player's orders set intent; each vehicle's brain does the rest:
- **Cover:** find positions that block line of sight to known threats, reach them, **peek out to shoot and duck
  back** (fire from cover, reload in cover), and prefer hull-down angles that show front armor.
- **Target selection by matchup:** engage what my weapon is good against; avoid duels I lose; call for help.
- **Friendly fire awareness:** never take a shot whose line of fire (or splash) crosses a friendly, or weigh the
  risk explicitly; move to clear a firing lane.
- **Squad tactics:** bounding overwatch, suppress-and-flank, focus fire, covering a retreating teammate,
  protecting fragile units (artillery, Lancers).
- **Deterministic, measurable:** pure decision functions, seeded; behavior regression scenarios ("peeks from
  cover", "holds fire when a friendly crosses") plus AI-vs-AI tournaments with ELO so a new brain must beat the old one.
- Grounding in game-AI literature: utility AI (what we have), tactical position evaluation (Killzone,
  CryEngine's Tactical Point System, Unreal's EQS), influence maps, and GOAP-style squad coordination (F.E.A.R.).
  Details belong in the AI stream's design doc.

## The arena

- A **gladiator arena** in a converted industrial site, with **stands full of cheering crowds** that react to the
  fight (big kills, close calls) **(lead)**.
- **Textured ground** and **better lighting**: readable at night without losing the neon mood **(lead)**.
- **Map layouts (proposed): authored, symmetric arenas as data, not a full procedural generator yet.**
  Competitive fairness needs point symmetry and curated cover, which generators struggle to guarantee. A small set of hand-made
  layouts (cover, lanes, chokepoints) plus optional seeded variation of dressing is the right first step; revisit a
  generator once we know what makes a good layout. The lead was unsure whether a generator is worth it; this is the recommendation.
- Unit art and arena art come from the Meshy pipeline, **with the lead approving concept images before any
  image-to-3D request** **(lead)**.

## Match rules (current defaults)

- Squad-vs-squad elimination; no respawns.
- **Friendly fire on** **(lead)**.
- The center **control point** as a second win condition: round 1 measured that it restores "coordination
  beats individuals" under shields (balance.md). **Recommended default; pending the lead.**
- Fog of war from per-unit sight; scouting matters.

## Later layers (kept, not now)

- Online play: the relay broker and player-hosted matches exist (archive/round1/netcode.md); lockstep for ranked is
  feasible (integer core spike). Resumes after the core loop is fun.
- **The AI Commander:** an optional LLM opponent that issues the same SquadCommands. Bring-your-own Gemini key
  first, then on-device Gemini Nano on Android (the plan and its rules are in vision.md).
- **Factions** (idea, not decided): see roadmap.md's idea backlog.
- Replays and spectating (recording works over the relay today).
