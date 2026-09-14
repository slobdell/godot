# Stream: Look & Feel (cyberpunk gladiator arena)

> Read [../workstreams.md](../workstreams.md). You own `game/theme/**` (the slot registry, all
> art scenes, team colors, UI palette), `game/ui/hud.tscn`, `game/combat/impact.gd`, and new
> `assets/audio`, `assets/fonts`.

## The brief (the lead, 2026-09-13)

> "a futuristic Cyberpunk Gladiator arena. Think Mad Max meets Death Race meets Blade Runner."

Reads as: a spectacle arena at night; neon signage and floodlights over rust, scrap, and chrome;
armored, improvised combat vehicles; rain, haze, and sodium/neon color contrast; broadcast-style
HUD with an announcer; the crowd and the show matter as much as the fight.

## How the seams work

- Gameplay scenes contain **VisualSlot** nodes (`tank.hull`, `tank.turret`, `weapon.cannon`, `weapon.flamethrower`, `prop.crate`, `prop.wall`, `arena.environment`, `arena.dressing`). `GameTheme.slots` maps each to a scene. **Build a new theme as `game/theme/cyberpunk/` with the same slot ids**, then make it active (e.g. a `--theme=cyberpunk` flag / default).
- Slot scenes may implement `set_team_color(color)`, `setup(weapon_profile)`, `set_firing(bool)`. See `game/theme/default/` for working examples and [assets.md § Slot contracts](assets.md#slot-contracts) for sizes and orientation.
- The tactical map's colors come from `GameTheme.ui`; the HUD layout is `game/ui/hud.tscn`.
- Candidates to turn into slots when you get there: impacts/explosions (`fx.impact`, today `game/combat/impact.gd`), muzzle flashes, nameplates, destroyed-tank wrecks. Coordinate the slot names with gameplay.

## Constraints

- **Compatibility renderer (WebGL 2 / phones):** no SDFGI, SSR, SSAO, or volumetric fog. Emissive materials, glow, fog (depth), unshaded neon, particles (GPU and CPU) are the palette; verify each in `make web-smoke` screenshots.
- **Performance and size budgets:** target 60 fps on a mid-range phone; keep the web `.pck` reasonable (it downloads on every visit).
- **Art never changes the simulation:** the determinism hash in workstreams.md must not change. Collision shapes live in gameplay scenes, not yours.
- Readability first: team colors and the commander markers must stay unmistakable at tactical-map zoom.

## Verification

`make screenshot`, a skirmish screenshot (`--skirmish --screenshot=... --screenshot-delay=8`),
`make web-smoke` (look at `build/screenshots/web.png`), `make check` (determinism unchanged).
Publish before/after screenshots in your merge notes.

## Status

- 2026-09-13: brief written; `default` theme extracted into slots (placeholder boxes). Nothing started.
