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

_Report, 2026-09-15, by the feel worker. Branch `stream/feel`; every item below is committed and each backlog commit
passed `make remote T=check` on builder0. **Final: `make remote T=check` green on `5852c0a` (466 tests, every smoke,
sim baseline unchanged), the merge of `main` through 13685ce.**_

### Done

| Item | Commit | What it is | Verified |
|---|---|---|---|
| **X1** effects from K2 events | `0e57e2a` (+ `64ac80e`) | `WeaponFx` (one family per `fire_model`) fed by `MatchFxLink`: live K2 signals when the match has them, else a stub from `Tank.fired` + `Impact` (a hit is attributed to the recent shot whose line passes within 3.5 m). Matched to combat's real K2 on its branch: events' own `speed_mps`/`range`, flamethrower puffs (`stream` events of a CONE weapon) ignored, deaths via each unit's `died` | 11 tests (`test_fx_weapon_events`), mutation-checked |
| **X2** the tank shell | `4daca5d` | Muzzle: white-hot star, tongue of fire, smoke ring flung off the barrel, dust ring and puffs off the ground, recoil rock (`VehicleJolt`: the art only), light burst, `tank_boom` (2.8 s tail with stand echoes). Flight: fat glowing slug, long floor light, wins a pooled light. Hit: shockwave, sparks, torn-steel debris, smoke, distance-scaled shake, hit rock. Kill: cooks off (second blast, 34 m ring, debris, smoke column, scorch). Miss: dirt geyser + small scorch; `shell_whine` for a 1–7 m near miss; shells that fly out of range fizzle into the dirt | 10 tests; `make fx-shots` close-ups and RTS views looked at |
| **X3** 25 mm bursts, MG streams | `d1d9623` | Every burst round counted (flash, gas puff, short fat tracer, `autocannon_shot` thump, HE pop). Streams: node-less virtual tracers in the tracer MultiMesh (muzzle → where each round stopped), a muzzle light flickering while the trigger is held, sparks rate-limited per target, ricochet streaks + zing. Sound: `mg_loop` held per gunner (4 nearest), not a click per round. New cyberpunk `fx.tracer` slot for round 2's hitscan MG | 8 tests |
| **X4** hits that read | `64ac80e` | Weak spots (K2 `weak_spot`): gold four-point flare + ring, gold sparks, fire jets from a tank's hull, `weak_spot_hit` crunch + two-note chime. Shield holds → splash in the victim's glow + a ripple across the shell from the struck point (`ShieldEffect.hit_at`). Every death explodes and cooks off whatever killed it (duplicate reports dropped). Wrecks burn from several points, smoke column, cook-offs | 6 tests + fires test; showcase `tank_weak_spot`, `ifv_on_shield` |
| **X5** order and selection feedback | `a5fab5e` | `OrderFeedback`: one ground marker per command (move ring, attack brackets on the target and following it, gold attack-move chevrons, follow diamond, hold frame, stop X), a marker per queued waypoint, a dotted trail with a running light under selected units with queues, a pulse under newly selected units; `ui_ack_move`, `ui_ack_attack`, `ui_select`. Local team only. Reads K1 and the selection by duck typing | 7 tests; showcase `orders` (K1 stand-in) looked at from the RTS camera |
| **X6** vehicles in motion | `b6bef7c` | `MotionFx` (from node movement, never the sim; nearest 6/12/20 by tier): dust behind treads and tires by speed (own pool), drift marks when wheeled units slide (own MultiMesh, 16 s fade; K3 `locomotion` when present), a lurch on hard braking/launch. Engine sound by speed already existed (round 2) | 6 tests; showcase `motion` |
| **X7** budget and listening | `f0c1c48` | FX lab `Round3Firefight`: 25 v 25 with round 3's weapons through `WeaponFx`, moving, orders. builder0 (Iris Xe): **high 6.9 ms / 273 draws, low 4.4 ms / 140 draws; weapon FX +0.6 ms, motion ~0.06 ms** (full table in `references/fx_tricks.md`). `make sfx-listen` | bench run and screenshots looked at |
| **Stretch** kill-cam, heat haze | `10dd979` | `KillCam`: an elimination that ends on a kill → time 0.2×, sound 0.55× for 1.4 real s, camera centers on the final kill, eases back; never networked; `--no-kill-cam`. `HeatHaze`: ≤ 8 screen-bending quads over the nearest fires, tier high only, cost within noise | 4 tests |

Also verified: `make remote T=skirmish-shots` (the real game, stub path: shell rings, sparks, a burning wreck with smoke
read at desktop and phone aspect) and `make remote T=web-smoke` (boots, tier low, no console errors). Sim baseline
untouched (feel never changes it).

### Decisions (one line each)
- Effects are **data families keyed by K2 `fire_model`**, so combat's retuned weapons pick the right look from the event.
- The burst MultiMesh's **instance basis carries motion** (velocity, drag, gravity, rise): moving smoke, dust, and
  delayed cook-offs cost one write each, no script per frame. New kinds: shockwave, smoke, scorch, sparks, debris, flare.
- **Long-lived things get their own pools** (scorches, dust, drift marks) so a firefight never recycles them. Tier
  budgets: effects 128/192/320, decals 12/24/48, spray pieces 6/10/14, haze off/off/on.
- **Recoil, hit rocks, and lurches move only the vehicle's VisualSlot nodes** (tested: body and turret untouched).
- **Weak-spot color is gold**, never a team color (cyan/magenta). **No floating damage numbers**: the gold flare and chime
  are the hit marker (question below).
- **Machine guns are held loops for the 4 nearest gunners**; small-round sparks 0.07 s per target, clanks 0.09 s,
  ricochet sounds 0.15 s globally.
- **Order markers read K1 by duck typing** and ignore other teams, so they work before and after CP1 and never show
  the CPU's orders.
- **Kill-cam is presentation after the result**: it never runs on a networked match and counts wall time (it slows
  `Engine.time_scale` itself).
- All new sounds are synthesized by `make sfx` (CC0), each reseeding from its name; old files stayed byte-identical;
  energy above 200 Hz measured per file (`assets/audio/README.md`).

### Questions for the lead
1. **Listen:** `make sfx-listen` plays the new sounds in order (or `make sfx-listen LISTEN="tank_boom mg_loop
   weak_spot_hit"`). Is the tank boom heavy enough? Is the weak-spot chime too "gamey" for the arena, or the reward you
   want? Does the machine-gun loop read as brrrt?
2. **Hit markers:** no floating damage numbers; weak spots get a gold flare and chime instead. OK, or do you want numbers?
3. **Kill-cam:** slow motion on the final kill of an elimination. Keep it? Also on big moments mid-match in single
   player (it would change pace)?

### Requests to other streams
- **control (after CP1):** feel now draws the order acknowledgements, waypoint trails, and selection pulses in 3D with
  sounds (`game/theme/fx/order_feedback.gd`). Please drop `RtsControls._draw_acks` (2D rings) so markers don't draw
  twice; keep or drop the 2D waypoint dashes as you prefer (feel's trail is on the ground). Don't add ack sounds.
- **combat:** (1) optional: a `projectile_impact` with no target when a shell reaches its range, so misses land where
  the rules say (feel fizzles them into the dirt meanwhile); (2) the wreck-husk stretch (keep a dead unit visible):
  feel's burning wreck sites already sit where kills happen and would dress a husk.
- **orchestrator:** `tools/remote.sh` fix (stale Xwayland cookie → stale remote screenshots): **landed on `main` as
  7dc7bdc** (2026-09-15; identical hunk here, so the merge is clean); remote screenshots taken before it may be stale. Merge order: after control and combat, then check
  that `MatchFxLink.live` is true in a skirmish (effects switch to real K2 on their own).

### Known issues
- Tier high on the laptop's UHD 620 is estimated at ~16 ms for the 50-vehicle bench (Iris Xe × 2.3), the edge of its
  budget; the 50 vehicles' 886k primitives are the main cost, not effects.
- Round 2's MG fires 5 rounds/s, so streams look sparse until combat's ~11/s lands. Weak spots in the showcase are
  forced on (round 2 has none).
- Order markers were checked against a K1 stand-in, not control's real `Orders` (not on this branch yet); control's 2D
  ack rings will double them until removed.
- The kill-cam was verified by tests, not seen at a real match end; ArmyLoop's results screen appears a moment later
  (its timer slows too).
- On networked clients the link stays detached (no `Tank.fired` there): legacy effects only. Netcode is paused.

### What to playtest
- `make skirmish`: tank shells (watch a miss whine past and throw dirt), IFV bursts, scout streams, kills burning,
  order markers after CP1 (right-click move/attack, A-click, shift-queue with units selected).
- `make fx-shots` → `build/screenshots/fx-shots/*.png` (close-ups and RTS views of every weapon, weak spot, shield,
  wreck, orders, motion); `make fx-shots SHOWCASE=tank_kill,scout_stream` for a subset.
- `make fx-bench FX_CONFIGS=r3_all,r3_tier_low` on the laptop to measure the UHD 620; `make sfx-listen`.

### Next steps
- After CP1/CP2 merge: rerun `make fx-shots` and a skirmish with combat's weapons (live K2, weak spots, bursts at real
  rates); retune stream density and hit sizes against the real fire rates; delete the stub path once K2 is on `main`.
- Wire order markers to control's `Orders` in a real skirmish and screenshot them.

### Merge notes (shared files)
- `tools/remote.sh`: the Xwayland auth line (reads the running Xwayland's `-auth`, falls back to the newest file).
- `game/theme/game_theme.gd`: additive `fx.tracer` entry in `CYBERPUNK_SLOTS`.
- `_agents/remote_builds.md` (troubleshooting notes), `_agents/orientation.md` (trip-ups 65–66).
- Everything else is in feel's paths: `game/theme/fx/**`, `game/theme/audio/`, `assets/audio/`, `game/combat/impact.gd`,
  `game/theme/cyberpunk/{tracer_shell,tracer_round}.gd` + `fx_tracer.tscn`, `mk/fx.mk`, `references/fx_tricks.md`,
  tests `test_fx_*.gd`.
