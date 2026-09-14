# Stream: Look & Feel (cyberpunk gladiator arena)

> Read [../workstreams.md](../workstreams.md). You own `game/theme/**` (the slot registry, all
> art scenes, team colors, UI palette), `game/ui/widgets/**` (new: reusable HUD components),
> `game/ui/hud.tscn`, `game/combat/impact.gd`, and new `assets/audio`, `assets/fonts`.

## The brief

The lead, 2026-09-13: *"a futuristic Cyberpunk Gladiator arena. Think Mad Max meets Death Race meets Blade Runner."*

The lead, 2026-09-14: *"On the look_and_feel I want to basically copy the cyberpunk theme from
~/projects/led-drone-microcontrollers/mavlink-hud where I've documented some of the key re-usable concepts."*

The lead, 2026-09-14: *"A lot of the vibes from this game [are] Mad Max + Death Race + Blade Runner
with a dark atmosphere and neon glowing lights. I think the lighting effects are what could make
this game really fun. Shooting a projectile ideally creates ambient light along its path of travel.
We'll want obstacles that reflect the cyberpunk arena, with glowing lights themselves."*

**So the HUD/UI language is decided: replicate the mavlink-hud cyberpunk HUD.** The 3D world
(arena, vehicles, lighting) should feel like it belongs behind that HUD: a **dark** night arena,
neon over rust and scrap, and the same palette. **Lighting is the headline feature:** the arena is
mostly dark, so weapon fire, neon, and explosions are what reveal it.

**Autonomy:** the lead will start you with *"You are the look_and_feel agent. Execute, iterate, and
smoke test toward completion without my input."* Follow *Autonomous mandate* in workstreams.md.
Judge your work from screenshots (desktop and phone aspect, native and `make web-smoke`) and keep
iterating until it looks like a game you'd want to play.

## The reference (read these first)

| What | Where |
|---|---|
| **Message banner spec** (chamfered panel, glowing corner brackets, beam→open→glitch→snap choreography, typewriter text, info/warning/error themes, lifecycle) | [references/hud_message_banner.md](references/hud_message_banner.md) |
| **Breathing conductors spec** (circuit-trace lines wiring widgets together; baked glow + per-frame alpha modulation) | [references/hud_breathing_conductors.md](references/hud_breathing_conductors.md) |
| Original Android implementation | `~/projects/led-drone-microcontrollers/mavlink-hud/android-app/app/src/main/java/com/mavlink/hud/ui/CyberHudView.java` (HUD), `MapLibreCyberMap.java` (**cyber-styled map: the model for our radar**), `RssiView.java` |
| Drawables (bracket borders, frames) | `…/android-app/app/src/main/res/drawable/bg_bracket_border.xml`, `bg_bracket_filled.xml`, `cyberpunk_border.xml` |
| Palette | `…/android-app/app/src/main/res/values/colors.xml` |
| **FX tricks catalog** (efficient lighting and effects on Compatibility/WebGL 2/phones, verified limits, and the FX lab protocol) | [references/fx_tricks.md](references/fx_tricks.md) |

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

0. **L0: the FX lab. Figure out the tricks before building the look on them.** The lead:
   *"we need to figure out the 'tricks' to still render cool effects but do so in an efficient manner."*
   Start from [references/fx_tricks.md](references/fx_tricks.md):
   - Build `make fx-bench` (a worst-case firefight scene on a fixed camera path, per-trick toggles, `FX_BENCH` frame-time/draw-call output) plus an on-screen perf overlay.
   - Prototype the core tricks as reusable pieces in `game/theme/fx/`: a **LightPool**, **pooled MultiMesh tracers with ground light splats**, a **laser beam** shader, **flipbook explosions** (replacing the per-hit allocation in `Impact`), **emissive neon** with shader flicker, and a **chunked ground**.
   - Turn every **[verify]** in the catalog into a measured result in its Results table (support, ms cost, screenshot, verdict), and write the resulting **frame budget per quality tier** into this brief.
   - Ask the lead for one phone run (`make serve-web WEB_HOST=0.0.0.0`, open `/?fx-bench` on the phone) when the lab is ready. Don't block on it; keep going with the desktop and real-browser numbers.
   - `fx-bench` may use a standalone scene that reuses gameplay's tank/shell signals without editing gameplay code. Any hooks you need (e.g. the `fx.shell` slot) go through the lead/contracts.

1. **Reusable HUD widgets in `game/ui/widgets/`:**
   - `CyberFrame`: chamfered translucent panel + glowing corner brackets (spec §3), for any panel.
   - `CyberBanner`: the full message banner with choreography, typewriter, history, themes (spec §4–§7). Top = warnings/errors, bottom = info.
   - `Conductors`: breathing circuit traces wiring the HUD widgets together (spec 2), with glow baked once and modulated per frame.
2. **Wire them into the game** through the contracts (workstreams.md):
   - `Hud.post_message(text, severity)` → banners. Gameplay posts orders, "commander down", unit lost, victory.
   - A radar frame styling hook for the gameplay stream's radar (they own its data and interaction; you own how it looks).
   - Shield + hull display (gameplay G6 adds rechargeable shields): nameplate/HUD bars and a shield-hit / shield-down / recharge visual on vehicles.
   - Restyle `hud.tscn`, the tactical map's palette (`GameTheme.ui`), and fonts (monospace).
3. **A `cyberpunk` theme** (`game/theme/cyberpunk/`) filling every visual slot: a night arena environment (dark sky, fog, floodlights/neon), emissive trims on vehicles, team colors that read against it (keep the two teams unmistakable, e.g. cyan vs magenta/pink). Make it the default once it's good.
   - **Obstacles are arena props with their own lights:** crates become scrap barricades, containers, and wrecked cars with neon strips, hazard lights, and signage; walls become blast barriers with light bars and holographic ads. They must keep their collision footprints (slot contracts in streams/assets.md).
4. **Lighting that makes combat spectacular:**
   - **Projectiles light their path:** a glowing tracer that casts light on the ground and obstacles as it flies, plus a muzzle flash and a hit/explosion flash. This needs the `fx.shell` slot (gameplay G7 moves the shell mesh into it; if it hasn't landed, ask via the lead rather than editing `game/combat/shell.*`).
   - **Lasers** (gameplay G7): bright beams that light the area along their length; the flamethrower should light its surroundings too.
   - **Heat and shields read visually:** barrels/vents glow hotter via `set_heat(ratio)`; a shield shimmer on hit, a visible shield-down state, and a recharge effect via `set_shield(ratio)` (gameplay G6).
   - Vehicles carry their own small light (headlights/underglow in team color) so you can find your squad in the dark.

## Godot notes for porting the specs

- Canvas drawing → a `Control` with `_draw()`: `draw_colored_polygon` (chamfer fill), `draw_polyline` with antialiasing (brackets, traces), `draw_circle` (dots).
- Glow: follow the specs' architecture: **bake once, modulate per frame.** Render blurred strokes into a texture once (SubViewport + a blur shader, or pre-blurred images) and draw with modulated alpha. Never blur in the frame loop. A cheap fallback: several wider, lower-alpha strokes under the crisp one.
- Animations: `Tween` with the spec's easing functions (decelerate, easeInOut, the exact bounce curve).
- Typewriter: `Label.visible_characters` + the `█` cursor. **Godot's default font lacks block glyphs** (orientation trip-up #20): ship a monospace font that has U+2588, or draw the cursor as a rectangle.
- Scale geometry by `screen_height / 1080`; keep stroke widths and glow radii fixed, per the spec.

### Lighting on the Compatibility renderer (read before designing FX)
- Verified in Godot 4.7.2: **8 real lights per object, 32 renderable lights** by default, and today's ground is **one** mesh, so dozens of projectiles each carrying an `OmniLight3D` won't work. The full catalog of workarounds (light pool, ground light splats, MultiMesh tracers, flipbooks, shader animation, chunked ground, fake wet reflections, quality tiers) is in [references/fx_tricks.md](references/fx_tricks.md). L0 proves which ones pay off.
- **The SwiftShader-based `make web-smoke` is not a performance measurement.** Use native, a real GPU browser, and the lead's phone.
- All of this lives in visual slots and `game/theme/fx/`, so the headless server and `make sim-baseline` never see it.

## Constraints

- **Compatibility renderer (WebGL 2 / phones):** no SDFGI, SSR, SSAO, or volumetric fog. Emissive materials, glow, depth fog, unshaded neon, and particles are the palette; verify in `make web-smoke` screenshots.
- Performance: 60 fps on a mid-range phone; keep the web `.pck` reasonable.
- **Art never changes the simulation:** `make sim-baseline` must keep passing.
- Readability first: team colors, commander markers, and fog of war must stay unmistakable. Dark doesn't mean murky: units and the ground they drive on must stay legible.
- **Mobile first** (workstreams.md): HUD widgets sized for touch and legible on a phone screen; banners and frames must not cover the play area needed for taps and swipes.

## Verification

`make screenshot`, a skirmish screenshot (`--skirmish --screenshot=... --screenshot-delay=8`),
`make web-smoke` (look at `build/screenshots/web.png`), `make check`. Put before/after screenshots
in merge notes. Compare against the reference app's look where possible.

## Status

- 2026-09-13: brief written; `default` theme extracted into slots (placeholder boxes).
- 2026-09-14: reference HUD chosen (mavlink-hud); specs copied into `references/`. Lighting direction (projectile light, glowing obstacles, lasers, heat/shield visuals) and mobile-first constraint added. FX tricks catalog + L0 FX lab added (the lead: efficiency tricks first).

### Overnight run 2026-09-14: morning report (kept current as items land)

**Plan (backlog order):** L0 FX lab → L1 HUD widgets → L2 cyberpunk arena → L3 vehicles → L4 HUD
restyle → L5 heat/shield/laser hooks → L6 quality tiers → stretch (camera-shake curve, SFX, title screen).

#### Done
- **L0 FX lab.** `make fx-bench` (browser `?fx-bench`) runs an 18-config worst-case firefight and
  prints `FX_BENCH` JSON lines + `build/fx-bench.json` + a screenshot per config; `PerfOverlay`
  shows fps/ms/draws/lights on screen. Systems in `game/theme/fx/`: `FxWorld` (lazy, never on
  headless), `LightPool` (priority + distance), `TracerSystem` (MultiMesh tracers + ground splats),
  `BurstSystem` (one ring-buffer MultiMesh for flipbook fireballs, muzzle stars, ground glows; atlas
  generated procedurally by `make fx-textures`), `ChunkedGround`, `StaticBatcher` (merge props by
  material), `FxQuality` tiers, shader pre-warm, shaders (tracer, splat, burst, neon, wet ground,
  beam cone, hologram). `Impact` now forwards to the pooled bursts (no per-hit mesh/material).
  **Measured** (UHD 620, 720p; full table in references/fx_tricks.md → Results): worst case
  tier high 15.1 ms / 384 draws, medium 8.0 ms / 190, low 5.5 ms / 190. Moon shadows +4.9 ms and
  2× draws; render scale 0.7 −4.3 ms; 16 pooled lights +0.9 ms; glow +1.1 ms; splats ≈ 0; a single
  ground plane +1.6 ms vs tiles; merging props −180 draws and −1.6 ms CPU; the naive per-shell
  light/mesh approach hitches to 33 ms. Probe: instance uniforms work, `Decal` and `ReflectionProbe`
  don't help in Compatibility, GPUParticles3D works natively. Browser/phone numbers pending.

- **L1 HUD widgets** (`game/ui/widgets/`): `CyberFrame` (chamfer fill + glowing corner brackets,
  animatable about its center), `CyberBanner` (beam → open → glitch → snap choreography, typewriter
  with █ cursor at 30 fps, blink, history newest-first with caps, dedup, 5 s auto-dismiss; a manual
  timeline so it animates during the tactical pause and tests step it exactly), `CyberMessages`
  (top = warnings/errors, bottom = info; **wired into `hud.tscn`, listening to `Hud.message_posted`**,
  so `hud.post_message(text, Hud.WARNING)` just works), `Conductors` (breathing traces; glow baked
  once into two tiny textures, per-frame alpha only; `add_bus` builds nested 45° elbows),
  `CyberStyle` (palette, easing curves, 1080p scale × a 1.5 touch boost on phones, font). Font:
  Share Tech Mono + a 14 KB JetBrains Mono subset as fallback for █ ▲ ─ (`assets/fonts/`, OFL, README).
  `make hud-gallery` → `build/screenshots/hud-gallery.png` / `-phone.png`. 10 tests in
  `tests/test_hud_widgets.gd` (mutation-checked: breaking the dismiss timer or the font fallback fails them).

- **L2 cyberpunk arena** (`--theme=cyberpunk`): night environment (near-black background, cool
  moonlight, thin exponential + height fog, HDR glow, environment reflections off so glossy floor
  doesn't turn black), chunked wet-asphalt floor with faint violet lane grid, blast-barrier perimeter
  with violet light bars and a rim-top light line, four floodlight towers with fake volumetric beams
  and painted light pools, **wet-floor reflection streaks** (`StreakSystem`: one MultiMesh oriented
  toward the camera in the shader, fading when looking straight down), neon props with the same
  footprints: `prop.crate` = rusted container stack with amber hazard edges, a glowing top panel
  and a failing red beacon; `prop.wall` = concrete barrier with a violet top light bar, chevrons, and
  a hologram ad. **Props use violet/amber/red, never the team cyan/magenta.** Iterated from the
  tactical camera (orthographic, 200 m up, ~3 px/m): thin strips vanish there, so every prop has a
  wide emissive top. Screenshots: `build/screenshots/l2_skirmish_before.png` → `l2_skirmish.png`,
  `l2_follow.png`; the default look for comparison: `l2_skirmish_default.png`.

#### Frame budget per quality tier (from L0; details in references/fx_tricks.md)
| Tier | Default for | Worst-case frame | Draw calls | Pooled lights | Glow | Render scale | MSAA | Shadows |
|---|---|---|---|---|---|---|---|---|
| low | web, mobile | ≤ 12 ms | ≤ 250 | 4 | on | 0.75 | off | off |
| medium | — | ≤ 12 ms | ≤ 250 | 8 | on | 1.0 | off | off |
| high | desktop | ≤ 16 ms | ≤ 450 | 16 | on | 1.0 | 2× | moon |

#### Decisions (with reasons)
- **Theme switch by flag:** `--theme=cyberpunk` / `?theme=cyberpunk` read in `GameTheme._static_init`, so no shared file changes were needed to select a theme.
- **FX systems live under the scene root, created on first use** (`FxWorld.get_instance()`), and return null on headless peers: servers, tests, and `sim-baseline` never build effects.
- **The muzzle-flash event is "a tracer appeared"**: the `fx.shell` slot has no firing hook, and this needs no contract change.
- **Tracers take the team's neon** (`GameTheme.team_glow`, new): cyan vs magenta shots keep the two teams readable in the dark. The shell's team is read from the Shell node (read-only duck typing).
- **Readability rules for arena art** (learned from the tactical camera): emissive features ≥ 0.5 m wide or they vanish at ~3 px/m; fog must stay thin (the tactical camera is 200 m away: density 0.006 hid 70% of the scene); glossy dark floors reflect a black sky as black blotches, so keep roughness ≥ 0.45 and environment reflections off.
- **HUD text grows 1.5× on touch devices** (`CyberStyle.touch_boost`, preview with `--ui-touch`): the spec's 25 px at 1080p is ~1.5 mm tall on a phone. Banners keep ≥ 2.2 lines of height so the boosted text fits.
- **Banner timestamps use the wall clock (`HH:MM:SS`) like the reference**; `clock` is swappable (match time would be a one-line change).
- **The FX lab uses visual-only tanks and shells** (slot visuals, not the simulation), so it never touches gameplay code and is deterministic without physics.

#### Shared-file edits (for the merge notes)
- `game/modes/game_mode.gd`: 2 lines, `--fx-bench` routes to `FxBenchMode` (in `game/theme/fx/bench/`).

#### Questions for the lead
1. **Phone run** when convenient: `make export-web && make serve-web WEB_HOST=0.0.0.0`, open `http://<LAN IP>:8080/?fx-bench` on the phone (this worktree serves on 8080), and read the overlay's summary at the end (or add `&fx-quality=low`).

#### Requests to other streams
- (none yet)

#### Known issues
- The FX lab prints two "Texture … leaked" engine errors at exit (after switching MSAA/render scale at runtime). Bench only; the game itself exits clean.
- Bench frame times are GPU-bound on a shared laptop iGPU with four other agents running; use deltas, not absolutes.

#### What to playtest
- `make fx-bench` (≈2 min, opens a window), then look at `build/screenshots/fx/`.
- `make run` with the cyberpunk look: `godot --path . -- --theme=cyberpunk` (tanks still placeholder until L3).

#### Next steps
- L3 vehicles (in progress), then switch the default theme.

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. Each item: `make check` (sim-baseline unchanged!) + screenshots you look at (desktop and 2400×1080 phone aspect; `make web-smoke` for "boots in the browser") + a commit + a Status update with before/after screenshot paths.

1. **L0 FX lab:** `mk/fx.mk` → `make fx-bench` + perf overlay; LightPool; MultiMesh tracers + ground light splats via the `fx.shell` slot (landed on main); chunked ground; glow check; a pooled, shared-material impact (`impact.gd` is yours); shader pre-warm. Fill the Results table in `references/fx_tricks.md` and set per-tier frame budgets. Note: this machine has no discrete GPU. Record native numbers, and mark browser/phone numbers "pending the lead's phone run".
2. **L1 HUD widgets:** `CyberFrame`, `CyberBanner` (wired to `Hud.post_message`, top = warnings/errors, bottom = info), `Conductors`. Ship a monospace font with the block glyph (an OFL font such as Share Tech Mono or JetBrains Mono; put its license next to it in `assets/fonts/`). A demo/gallery scene plus tests for the banner lifecycle.
3. **L2 cyberpunk arena** (`game/theme/cyberpunk/`): night environment + fog + glow; chunked dark wet-look ground with light streaks; perimeter walls with neon light bars; floodlight beams; neon versions of `prop.crate`/`prop.wall` (same footprints). Switch the default theme once it beats `default` in screenshots.
4. **L3 vehicles:** hull/turret/weapon scenes with emissive trims, team colors cyan vs magenta (update `team_colors` and `GameTheme.ui`), team-colored underglow, glowing tracer shells, flipbook-style explosions (generate the flipbook frames procedurally in Godot if you have no source art).
5. **L4 HUD restyle:** `hud.tscn` and the tactical map palette in the cyberpunk style, touch-sized and legible at phone size.
6. **L5 future hooks, built against the documented contracts** (gameplay lands the mechanics in parallel): `set_heat(ratio)` barrel glow, `set_shield(ratio)` shield shimmer/down/recharge, a `weapon.laser` scene and `fx.laser_beam` (`setup(from, to)`), all shown in a gallery scene that drives the methods with fake values, so they work the moment gameplay calls them.
7. **L6 quality tiers:** an `FxQuality` low/med/high setting wired into the light pool, splats, glow, and render scale; default by platform (web/mobile = low).
- **Stretch:** camera shake (request it from gameplay, which owns the camera; you provide the effect curve); sound design with CC0 or procedurally generated SFX in `assets/audio/` (shots, laser hum, shield hit, explosions, UI blips), with licenses recorded; an animated main-menu/title screen in the HUD style.
