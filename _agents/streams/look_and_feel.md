# Stream: Look & Feel (cyberpunk gladiator arena)

> Read [../workstreams.md](../workstreams.md). You own `game/theme/**` (the slot registry, all
> art scenes, team colors, UI palette), `game/ui/widgets/**` (new: reusable HUD components),
> `game/ui/hud.tscn`, `game/combat/impact.gd`, and new `assets/audio`, `assets/fonts`.

## The brief

The lead, 2026-09-13: *"a futuristic Cyberpunk Gladiator arena. Think Mad Max meets Death Race meets Blade Runner."*

The lead, 2026-09-14: *"On the look_and_feel I want to basically copy the cyberpunk theme from
~/projects/led-drone-microcontrollers/mavlink-hud where I've documented some of the key re-usable concepts."*

**So the HUD/UI language is decided: replicate the mavlink-hud cyberpunk HUD.** The 3D world
(arena, vehicles, lighting) should feel like it belongs behind that HUD: a night arena, neon over
rust and scrap, and the same palette.

## The reference (read these first)

| What | Where |
|---|---|
| **Message banner spec** (chamfered panel, glowing corner brackets, beam→open→glitch→snap choreography, typewriter text, info/warning/error themes, lifecycle) | [references/hud_message_banner.md](references/hud_message_banner.md) |
| **Breathing conductors spec** (circuit-trace lines wiring widgets together; baked glow + per-frame alpha modulation) | [references/hud_breathing_conductors.md](references/hud_breathing_conductors.md) |
| Original Android implementation | `~/projects/led-drone-microcontrollers/mavlink-hud/android-app/app/src/main/java/com/mavlink/hud/ui/CyberHudView.java` (HUD), `MapLibreCyberMap.java` (**cyber-styled map: the model for our radar**), `RssiView.java` |
| Drawables (bracket borders, frames) | `…/android-app/app/src/main/res/drawable/bg_bracket_border.xml`, `bg_bracket_filled.xml`, `cyberpunk_border.xml` |
| Palette | `…/android-app/app/src/main/res/values/colors.xml` |

Read the original code for anything the specs don't cover (tapes, map styling, fonts). The
specs are authoritative where they're explicit; their gotcha sections record mistakes already paid for.

### Palette (from mavlink-hud `colors.xml` + the specs)

| Role | Color |
|---|---|
| Background | `#050510` (HUD background in spec: `#000510`); card/panel `#121225`; info fill `#202030` @ 86% |
| Primary neon cyan | `#00F3FF` (most used); border cyan `#00FFFF`; glow `#00E5FF` |
| Accents | neon purple `#D900FF`, neon pink `#FF0099`, neon green `#39FF14` |
| Warning | fill `#FFFF00` @ 20%, border `#FFFF00` |
| Error | fill `#D50000` @ 20%, border `#FF1744` |
| Text | `#E0E0E0` (info), `#FFFFFF` (warning/error); monospace |
| Conductors | core `#004D40`→`#008D9F` @ 59%, glow `#00E5FF` breathing to 71% |

## What to build (first milestone)

1. **Reusable HUD widgets in `game/ui/widgets/`:**
   - `CyberFrame`: chamfered translucent panel + glowing corner brackets (spec §3), for any panel.
   - `CyberBanner`: the full message banner with choreography, typewriter, history, themes (spec §4–§7). Top = warnings/errors, bottom = info.
   - `Conductors`: breathing circuit traces wiring the HUD widgets together (spec 2), with glow baked once and modulated per frame.
2. **Wire them into the game** through the contracts (workstreams.md):
   - `Hud.post_message(text, severity)` → banners. Gameplay posts orders, "commander down", unit lost, victory.
   - A radar frame styling hook for the gameplay stream's radar (they own its data and interaction; you own how it looks).
   - Shield + hull display (gameplay G6 adds rechargeable shields): nameplate/HUD bars and a shield-hit / shield-down / recharge visual on vehicles.
   - Restyle `hud.tscn`, the tactical map's palette (`GameTheme.ui`), and fonts (monospace).
3. **A `cyberpunk` theme** (`game/theme/cyberpunk/`) filling every visual slot: a night arena environment (dark sky, fog, floodlights/neon), emissive trims on vehicles and walls, team colors that read against it (keep the two teams unmistakable, e.g. cyan vs magenta/pink). Make it the default once it's good.

## Godot notes for porting the specs

- Canvas drawing → a `Control` with `_draw()`: `draw_colored_polygon` (chamfer fill), `draw_polyline` with antialiasing (brackets, traces), `draw_circle` (dots).
- Glow: follow the specs' architecture: **bake once, modulate per frame.** Render blurred strokes into a texture once (SubViewport + a blur shader, or pre-blurred images) and draw with modulated alpha. Never blur in the frame loop. A cheap fallback: several wider, lower-alpha strokes under the crisp one.
- Animations: `Tween` with the spec's easing functions (decelerate, easeInOut, the exact bounce curve).
- Typewriter: `Label.visible_characters` + the `█` cursor. **Godot's default font lacks block glyphs** (orientation trip-up #20): ship a monospace font that has U+2588, or draw the cursor as a rectangle.
- Scale geometry by `screen_height / 1080`; keep stroke widths and glow radii fixed, per the spec.

## Constraints

- **Compatibility renderer (WebGL 2 / phones):** no SDFGI, SSR, SSAO, or volumetric fog. Emissive materials, glow, depth fog, unshaded neon, and particles are the palette; verify in `make web-smoke` screenshots.
- Performance: 60 fps on a mid-range phone; keep the web `.pck` reasonable.
- **Art never changes the simulation:** `make sim-baseline` must keep passing.
- Readability first: team colors, commander markers, and fog of war must stay unmistakable.

## Verification

`make screenshot`, a skirmish screenshot (`--skirmish --screenshot=... --screenshot-delay=8`),
`make web-smoke` (look at `build/screenshots/web.png`), `make check`. Put before/after screenshots
in merge notes. Compare against the reference app's look where possible.

## Status

- 2026-09-13: brief written; `default` theme extracted into slots (placeholder boxes).
- 2026-09-14: reference HUD chosen (mavlink-hud); specs copied into `references/`. Nothing started.
