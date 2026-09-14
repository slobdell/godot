> **Archived round-1 brief (2026-09-14 overnight run), kept as history.** Current plan: [../../../workstreams.md](../../../workstreams.md) and [../../../game_design.md](../../../game_design.md).

# Stream: Look & Feel (cyberpunk gladiator arena)

> Read [../workstreams.md](../../../workstreams.md). You own `game/theme/**` (the slot registry, all
> art scenes, team colors, UI palette), `game/ui/widgets/**` (new: reusable HUD components),
> `game/ui/hud.tscn`, `game/combat/impact.gd`, and new `assets/audio`, `assets/fonts`.

## The brief

> **Art direction source of truth: [../art_direction.md](../../../art_direction.md)** (2026-09-14). The lead picked the
> "Death Race prison dozer" concept as capturing *"the vibe of the entire game"*: repurposed real vehicles brutally
> converted (riveted slab armor, grilles, chains, spikes, yellow-black hazard stripes, blackened gunmetal and grime)
> with magenta/cyan neon behind grilles and red/amber warning lights. Photoreal, never cartoon. The arena follows
> the same logic (a repurposed industrial site turned night-time gladiator venue). It layers on top of the
> cyberpunk HUD and palette below.

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
| **Message banner spec** (chamfered panel, glowing corner brackets, beam→open→glitch→snap choreography, typewriter text, info/warning/error themes, lifecycle) | [references/hud_message_banner.md](../../references/hud_message_banner.md) |
| **Breathing conductors spec** (circuit-trace lines wiring widgets together; baked glow + per-frame alpha modulation) | [references/hud_breathing_conductors.md](../../references/hud_breathing_conductors.md) |
| Original Android implementation | `~/projects/led-drone-microcontrollers/mavlink-hud/android-app/app/src/main/java/com/mavlink/hud/ui/CyberHudView.java` (HUD), `MapLibreCyberMap.java` (**cyber-styled map: the model for our radar**), `RssiView.java` |
| Drawables (bracket borders, frames) | `…/android-app/app/src/main/res/drawable/bg_bracket_border.xml`, `bg_bracket_filled.xml`, `cyberpunk_border.xml` |
| Palette | `…/android-app/app/src/main/res/values/colors.xml` |
| **FX tricks catalog** (efficient lighting and effects on Compatibility/WebGL 2/phones, verified limits, and the FX lab protocol) | [references/fx_tricks.md](../../references/fx_tricks.md) |

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
   Start from [references/fx_tricks.md](../../references/fx_tricks.md):
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
- Verified in Godot 4.7.2: **8 real lights per object, 32 renderable lights** by default, and today's ground is **one** mesh, so dozens of projectiles each carrying an `OmniLight3D` won't work. The full catalog of workarounds (light pool, ground light splats, MultiMesh tracers, flipbooks, shader animation, chunked ground, fake wet reflections, quality tiers) is in [references/fx_tricks.md](../../references/fx_tricks.md). L0 proves which ones pay off.
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
- 2026-09-14: reference HUD chosen (mavlink-hud); specs copied into `references/`. Lighting direction, mobile-first constraint, FX tricks catalog + L0 FX lab added.
- **2026-09-14 overnight run: backlog L0–L6 and all three stretch items done**, plus a verification sweep and an integration rehearsal with gameplay. Morning report below.
- **2026-09-15 integration:** the cyberpunk `tank.hull` / `tank.turret` / `weapon.cannon` slots are now the assets stream's Meshy prison dozer, wrapped by `game/theme/cyberpunk/dozer_part.gd`. The wrapper adds the team accent strips, the underglow, and the shield shell sized from the model's bounds, and paint tints the body. The procedural parts remain for the gallery and as fallback art. Open issue: at the default tactical zoom, the model is hidden under markers and glow.

### Morning report (overnight run 2026-09-14)

**In one paragraph:** the game now looks like the brief. **Cyberpunk is the default theme**: a dark
night arena lit by neon and weapon fire, with procedural scrap tanks carrying team accent lights and
underglow, tracers that light the floor along their path, flipbook explosions, lasers, shields, and a
styled fog of war. The whole UI is in the mavlink-hud language (banners, frames, conductors, themed
buttons, a title screen), and procedural sound comes with it. It was all built on an FX lab that
measured which tricks are cheap on the Compatibility renderer, and it stays inside per-tier frame
budgets (phone tier 5.9 ms worst case on this laptop iGPU). `make check` and `make check-all` pass,
sim-baseline is unchanged (`e69acc63a64f319a`), and web-smoke passes. A rehearsal merge with
`stream/gameplay` is clean and passes all 177 tests.

#### What to playtest (exact commands)
- `make title`: the title screen (tap SKIRMISH to relaunch into it).
- `make skirmish`: tactical view (banners in the side columns, themed buttons, FX button top-left: tap to cycle LOW/MEDIUM/HIGH).
- `make run`: drive a tank in the 3D follow view (spec banners top/bottom, camera shake on kills).
- `make vehicle-gallery`: tanks, lasers, shields (hit/break/recharge), flamethrowers, heat, paint.
- `make fx-bench`: the FX lab (about 3 min, opens a window) → `build/fx-bench.json`, `build/screenshots/fx/`.
- `make hud-gallery`: banners, frames, conductors. Browser: `make serve-web`, then `?title`, `?skirmish`, `?fx-bench`.
- Flags for any mode: `--theme=default` (old boxes), `--fx-quality=low|medium|high`, `--perf`, `--hud-demo`, `--mute`, `--no-shake`, `--ui-touch` (phone-sized HUD on desktop).

#### Done
- **L0 FX lab.** `make fx-bench` / `?fx-bench`: a deterministic 10v10 worst-case firefight on the real arena (tracers, lasers, shields, explosions), one pass per trick config, `FX_BENCH` JSON lines, hitch logging, a screenshot per config, an on-screen `PerfOverlay`; on the web it reports after the first pass and keeps looping for phone tests. Systems (`game/theme/fx/`): `FxWorld` (lazy; never on headless peers), `LightPool` (priority + distance), `TracerSystem` (MultiMesh tracers + ground light splats), `BurstSystem` (ring-buffer MultiMesh: flipbook fireballs with a procedurally generated atlas, muzzle stars, ground glows), `BeamSystem`, `StreakSystem`, `UnderglowSystem`, `ChunkedGround`, `StaticBatcher`, `ColorMeshBuilder`, `CameraShake`, `FxQuality`/`FxAutoQuality`, shader pre-warm, a support probe. `Impact` forwards to the pooled bursts (no per-hit mesh/material). **Results table + verdicts for every [verify] item: `references/fx_tricks.md` → Results.** Headline numbers (UHD 620, 720p): the naive per-shell light/mesh approach hitches to 33 ms; splats cost ≈ 0; 16 pooled lights +0.9 ms; glow +1.1 ms; render scale 0.7 −4.3 ms; a single ground plane +1.6 ms vs tiles; merging props −180 draws / −1.6 ms CPU; moon shadows with 4 PSSM splits +3.3 ms / +65 draws vs orthogonal. `Decal` and `ReflectionProbe` don't help in Compatibility; instance uniforms work.
- **L1 HUD widgets** (`game/ui/widgets/`): `CyberFrame`, `CyberBanner` (beam → open → glitch → snap, typewriter with █ cursor, history, dedup, 5 s dismiss; a manual timeline so it runs during the tactical pause), `CyberMessages` (wired to `Hud.message_posted`: `hud.post_message(text, Hud.WARNING)` just works), `Conductors` (breathing traces, glow baked once into two tiny textures), `CyberStyle`. Font: Share Tech Mono + a 14 KB JetBrains Mono block-glyph subset (`assets/fonts/`, OFL). `make hud-gallery`.
- **L2 cyberpunk arena:** night environment (thin fog + height fog, HDR glow, cool moonlight), chunked wet-asphalt floor with a violet lane grid, blast-barrier perimeter with light bars, floodlight towers with fake volumetric beams, wet-floor reflection streaks, neon props on the same footprints (amber-lit container stacks with failing beacons, violet-lit blast walls with holograms). Props never use team colors. Iterated from the orthographic tactical camera, where thin neon vanished and fog hid the map.
- **L3 vehicles:** procedural Death Race tanks (one mesh and two draws per part; all tanks share two materials), team accent lights (trims, stripes, crest, coils) + underglow, a flamethrower with a turbulent flame, pooled light and roar. **Friend or foe = accent lights; paint is full-body** (`set_paint`, per the lead's garage answer). Team neon: cyan `#00F3FF` vs magenta `#FF0099`.
- **L4 HUD restyle:** `CyberUiTheme` for every Control (including gameplay's tactical map, without code changes there), a framed status block, a framed center banner. **Banners never cover the arena:** with the tactical map up they sit in mid-height side columns (info left, warnings right, wrapping), clear of the map's top buttons, orders log, radar and command bar; without it the spec strips return. Touch boost 1.5× on phones.
- **L5 hooks, built to gameplay's actual G1/G6/G7 contracts** (read from `stream/gameplay`): shields (hit shimmer, break crackle, recharge sweep), `weapon.laser` (heating coils, pulse flash), `fx.laser_beam` (batched beams that light the floor and borrow pooled lights), `set_heat` on every weapon, `fx.fog_of_war` (dark digital haze, cyan vision boundary), `radar_frame` StyleBox. `make vehicle-gallery` drives them all with fake values.
- **L6 quality tiers:** `FxQuality` drives lights, splats, effect capacity, glow, shadows, 3D render scale and MSAA, live-switchable; the tier comes from the flag, then the player's saved choice (HUD FX button), then the platform default (web/mobile LOW). `FxAutoQuality` steps down on web/mobile when frames drop.
- **Stretch:** camera shake (through `Camera3D.h_offset/v_offset`, so the camera code is untouched); **sound design**: ten effects synthesized from scratch (`make sfx`, CC0, 264 KB, checked numerically for phone-speaker audibility) through a pooled `SfxSystem`; **animated title screen** (`make title`, `?title`).
- **Verification:** `make check` green on every commit (129 tests on the last one), `make check-all` passed, web boot verified for the default game, `?fx-bench`, `?title`, and browser multiplayer. Tests: `tests/test_fx_systems.gd`, `test_hud_widgets.gd`, `test_theme_vehicles.gd` (mutation-checked where it mattered).
- **Integration rehearsal** (a throwaway detached worktree in my scratchpad; nothing pushed; `main` untouched): merging `stream/gameplay` is clean and all 177 tests pass. It caught three problems, all fixed here: gameplay's new `fx.fog_of_war` slot was missing from the cyberpunk theme (themes now fall back to `DEFAULT_SLOTS`; a cyberpunk fog fills it), banner/FX-button collisions with gameplay's new tactical map layout, and a theme regression I introduced along the way (now tested). Screenshots of the merged game: `build/screenshots/int_skirmish.png`, `int_skirmish_phone.png`, `int_skirmish_radar.png`, `int_match.png`.

#### Frame budget per quality tier (measured in the FX lab; details in references/fx_tricks.md)
| Tier | Default for | Worst-case frame | Draw calls | Pooled lights | Glow | Render scale | MSAA | Shadows | Measured (UHD 620, 720p) |
|---|---|---|---|---|---|---|---|---|---|
| low | web, mobile | ≤ 12 ms | ≤ 250 | 4 | on | 0.75 | off | off | 5.9 ms / 240 |
| medium | — | ≤ 12 ms | ≤ 250 | 8 | on | 1.0 | off | off | 8.6 ms / 240 |
| high | desktop | ≤ 16 ms | ≤ 450 | 16 | on | 1.0 | 2× | moon (orthogonal) | 14.1 ms / 401 |

#### Merge notes (for the morning integration)
- **Shared-file edits:** `export_presets.cfg`: `exclude_filter` gains `build/*` in both presets. **The web `.pck` was shipping every PNG screenshot under `build/` (Godot imports them): 13.4 MB → 0.6 MB**, web-smoke and the server export re-verified. `game/modes/game_mode.gd`: 4 lines at the top of `choose()` (`--fx-bench` → `FxBenchMode`, `--title` → `TitleMode`); `hud.tscn` (mine) gains `HudSkin` + `CyberMessages` nodes; `_agents/orientation.md` (common tasks, layout, trip-ups 38–43), `verification.md`, `workstreams.md` (contract row).
- **Conflicts `git merge-tree` predicts** (re-checked at the final commit): assets merges clean. **gameplay, garage:** `orientation.md` only (every stream appends trip-ups numbered 38+ and common-task rows: keep all, renumber). **netcode:** that plus `game_mode.gd` (keep netcode's new routes and put my two `if` lines first).
- After merging gameplay, `game_theme.gd` holds gameplay's `DEFAULT_SLOTS` (with `weapon.laser`, `fx.laser_beam`, `fx.fog_of_war`) plus this branch's themes; git did it automatically in the rehearsal.
- **Post-merge doc fixes** (left out of this branch because the neighboring lines change on gameplay/netcode and would conflict): `workstreams.md` HUD-messages contract row: `hud.gd` is no longer a stub; `message_posted` feeds the `CyberMessages` banners in `hud.tscn`. `orientation.md` trip-up 20: HUD widgets draw █ ▲ ─ through `CyberStyle.font()` (Share Tech Mono + a JetBrains Mono fallback); keep ASCII only in labels on the default font.
- New default look: other streams' screenshot-based checks will now see the cyberpunk theme; `--theme=default` restores the boxes for comparison.

#### Decisions (with reasons)
- **Cyberpunk became the default theme** once screenshots beat `default` from both the follow and tactical cameras, and web-smoke compiled every shader on WebGL 2.
- **Themes are selected by flag** (`--theme`, read in `GameTheme._static_init`) and **fall back to `DEFAULT_SLOTS`** for undefined slots, so slots other streams add always work.
- **FX systems live under the scene root, created on first use, never on headless peers**: servers, tests, and sim-baseline never build effects. Visual RNGs are private (the simulation's RNG is untouched).
- **The muzzle-flash event is "a tracer appeared"** (the `fx.shell` slot has no firing hook; no contract change needed). **Tracers take the team neon** (`GameTheme.team_glow`).
- **Friend or foe = accent lights; paint = full body** (the lead via garage). Props use violet/amber/red so they never read as a team.
- **Arena art readability rules** (from the tactical camera, ~3 px/m): emissive features ≥ 0.5 m wide, thin fog, roughness ≥ 0.5, low specular, no environment reflections under a black sky.
- **Banners adapt to the view instead of the spec's fixed strips**: the spec's bottom strip covered the player's squads in skirmish.
- **HUD text is 1.5× on touch devices**: the spec's 25 px at 1080p is about 1.5 mm tall on a phone.
- **No per-event allocation in combat:** every effect joins a pool or MultiMesh; lasers from gameplay's per-pulse slot register with `BeamSystem` instead of drawing themselves.
- **Sounds are synthesized, not downloaded:** no licenses to track, deterministic, tiny, and tuned for phone speakers.
- **Lasers are team-neutral violet-white** until gameplay passes a team (the `fx.laser_beam` contract has none).

#### Questions for the lead
1. **Phone run, when convenient:** `make serve-web WEB_HOST=0.0.0.0` (it exports first), open `http://<LAN IP>:8080/?fx-bench` on the phone (this worktree serves on 8080; main uses 8060). It runs every config once (~3 min), then the overlay shows the summary; a screenshot of it is all I need (`?fx-bench=all,tier_low,tier_medium` is a 30 s version). Also worth a look on the phone: `?title` and `?skirmish` (HUD size, banner columns, FX button).
2. **Make the title screen the entry point?** `run/main_scene` is `main.tscn` (straight into offline play). Switching is a one-line shared change I left alone, because modes, the web page, and smoke tests assume today's entry.
3. **Sound:** I can't listen. The effects are designed and measured, but please give them a listen (`make vehicle-gallery` or `make skirmish`); `--mute` silences them.

#### Requests to other streams
- **Gameplay (contract change, please accept):** split paint from team: `invoke("set_team_color", [GameTheme.team_color(team)])` at spawn and `invoke("set_paint", [color])` for the garage's paint. An adapter handles today's `Tank.set_paint` meanwhile.
- **Gameplay (radar):** read `GameTheme.ui.get("radar_field", …)` for the visibility tint and `GameTheme.ui.get("radar_outline", …)` for the arena outline (both defined); `radar_frame` is already used.
- **Gameplay:** `fx.laser_beam` has no team: call `beam.invoke("set_team_color", [GameTheme.team_color(team)])` after `setup` if lasers should be team-colored (implemented).
- **Gameplay:** `test_navigation::test_path_goes_around_a_wall` is a load race (see Known issues); wait until the map contains this arena's regions before querying.
- **Gameplay:** the HUD's `Status`/`Scoreboard` don't update while paused (hud.gd `_process`), so the top-left block stays hidden during PLANNING; `process_mode = ALWAYS` on the HUD fixes it.
- **Gameplay:** a destroyed tank just disappears (`visible = false`). A wreck hook (e.g. `tank.hull` `set_destroyed()`) would let the art leave a burning hulk.
- **Assets:** add optional `set_paint(Color)` to the `tank.hull`/`tank.turret`/`weapon.*` slot contracts, and keep a separate emissive accent mask in generated models so team color never recolors the body. Style reference for generated art: `make vehicle-gallery`.

#### Known issues
- `test_navigation::test_path_goes_around_a_wall` (gameplay's test) is **a load race, reproduced without any look & feel code involved**: run alone under 6 busy CPU loops it failed 1 of 3 times (a straight 2-point path). It failed 3 of ~12 full `make check` runs tonight while four agents shared the machine, and passed at normal load.
- The FX lab prints two "Texture … leaked" engine errors at exit (after switching MSAA/render scale at runtime); the game itself exits clean.
- FX-lab frame times are GPU-bound on a shared laptop iGPU; compare deltas, not absolutes. WebGL reports no GPU timing.
- The explosion flipbook is generated procedurally: fine at gameplay distance, soft up close.

#### Next steps
- The phone numbers → adjust tier budgets (and the auto step-down threshold) if the phone misses them.
- After the merge: wrecks (with a gameplay hook), team-colored lasers, the radar palette, and art for gameplay's future units (scouts, artillery) in the same `ColorMeshBuilder` style.
- Swap procedural art for the assets stream's generated models as they land (slot contracts unchanged; keep accent masks separate).

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
