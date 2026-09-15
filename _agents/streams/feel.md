# Stream: feel (impact: weapon effects, hits, sound, feedback)

> Read [../orchestration.md](../orchestration.md), [../game_design.md](../game_design.md) (*Round 3 direction*,
> *Weapons feel*), [../workstreams.md](../workstreams.md) (you consume K1 and K2), [../art_direction.md](../art_direction.md),
> and [references/fx_tricks.md](references/fx_tricks.md) (pooling, tier budgets, the FX lab). You own
> `game/theme/fx/**`, `game/theme/audio/`, `assets/audio/`, `game/combat/impact.gd`, the weapon, shell, beam, and
> tracer effect scenes and scripts in `game/theme/cyberpunk/` (`fx_*`, `tracer_shell.gd`, `laser_beam.gd`),
> `game/ui/widgets/**`, `game/ui/hud.tscn`, `mk/fx.mk`, and `fx_tricks.md`.

## The lead's direction (2026-09-15)

> *"it's still currently boring and no fun to play … It barely feels alive … the tanks right now just shoot these
> boring blasts at somewhat high frequency. Tanks should shoot at very low frequency and be able to land devastating
> hit … machine guns in and of themselves with their wall of bullets"*, and the inspiration: *"Twisted Metal 3."* The
> lighting has been the lead's headline visual feature since round 1: projectiles light the arena as they fly.
> Decided: **arcade-tactical**.

## Where things stand (round 2)

- Pooled FX with quality tiers, the FX lab and `make fx-bench`, tracer shells, laser beams, muzzle flashes and hit
  sparks, fake light splats, burning kill sites (`fire_sites.gd`), synthesized engine and crowd sound, cyber HUD widgets.
- The lead has not heard the synthesized sounds (art's question 2 in [archive/round2/art.md](archive/round2/art.md)).
- Today's shots all look similar: small, frequent blasts with little weight.

## Backlog (in order)

**X1. Effects driven by K2 events.** Subscribe to `Match.weapon_fired` and `Match.projectile_impact` (build against a
stub emitter in your paths until CP2 lands). One effect family per `fire_model`, pooled, within tier budgets.

**X2. The tank shell.** A deep muzzle blast (flash, smoke ring, dust kicked up, the tank rocking back), a glowing shell
you can follow in flight that lights the ground under it, and an impact that sells devastation: shockwave, sparks,
debris, a scorch mark, a short camera shake scaled by distance, and a heavier version for a kill. A miss throws dirt
and fades. Sound: a boom with a tail, a whine for a near miss.

**X3. The 25 mm burst and the machine-gun stream.** Tracer bursts with rhythm (you can count the rounds), small
impact sparks and ricochets off armor; the scout's stream as a visible wall of tracers with light flicker. Distinct
sounds (thump-thump-thump vs brrrt), cheap enough for many at once.

**X4. Hits that read.** Armor hits spark; **weak-spot hits** (K2 `weak_spot`) get a distinct, satisfying effect and
sound; shield hits show the shield; kills get a stronger explosion and a burning wreck (extend `fire_sites.gd`).
Damage numbers or hit markers only if they fit the vibe (propose).

**X5. Order and selection feedback** (with control's K1): ground markers for move, attack, and attack-move clicks, a
waypoint trail for queued orders, a pulse on the selected units, and short acknowledgement sounds. Control owns *when*
they show; you own how they look and sound.

**X6. Vehicles in motion.** Dust or sparks from treads and tires, drift marks for wheeled units (K3 `lateral_grip`),
engine sound by speed, a lurch on hard braking. Cheap on the low tier.

**X7. Budget and listen.** `make remote T=fx-bench` holds the tier budgets with 50 vehicles fighting; a short list of
sounds for the lead to listen to (exact commands) in Status.

- **Stretch:** a slow-motion kill-cam moment for the last unit of a match; screen-space heat haze near fires within
  budget.

## How to verify

`make remote T=check` (the sim baseline must not change), `make remote T=fx-bench`, `make remote T=skirmish-shots`
and close-up captures of each weapon's fire, flight, and impact, **looked at** and compared with the vibe; the web
build still boots.

## Don't touch

Weapons and damage (combat: you only read K2), brains (ai), selection and orders (control), models and props
(assets).

## Status

- 2026-09-15: brief written for round 3. Nothing started.
