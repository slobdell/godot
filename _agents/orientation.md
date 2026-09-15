# Agent Orientation: Tank Squad

**Read this first. It takes 3 minutes and will save you 30.**

---

## How we manage context (read this if you're starting a new task)

We work on **one high-level task at a time** to limit context rot and token cost.
When a task is complete, the running agent updates `HANDOFF.md` at the project
root before the context window is cleared. A fresh agent with no memory should
regain full situational awareness from `HANDOFF.md` in under 5 minutes.

**If you were started as a WORKSTREAM agent** (round 3: control, combat, ai, feel, assets, announcer), read
[orchestration.md](orchestration.md) (the worker contract), [game_design.md](game_design.md), [workstreams.md](workstreams.md), and your brief in `streams/` right after this file. **If you're the orchestrator** (the main checkout, talking with the lead), read [orchestration.md](orchestration.md) in full:
they define what the game is, what you own, and the contracts you must not break.

**If you were just handed the repo:**
1. Read `HANDOFF.md` (project root): the current state and the task you're here to do.
2. Read this file for the mental model and trip-ups.
3. Read whatever domain doc `HANDOFF.md` points to.
4. Run `make doctor` and `make test` to confirm baseline health. If `.tools/` is missing, run `make bootstrap` first.
5. Do the task, one change at a time, verifying as you go ([verification.md](verification.md)).

**When your task is complete, before signing off:**
1. Update `HANDOFF.md`: what changed, the current state, and the NEXT task. **`HANDOFF.md` MUST reference this file near the top and tell the reader to read it.**
2. Update any `_agents/` doc your change made stale, especially `roadmap.md` checkboxes.
3. If something confused you and then clicked, add it to `teaching_notes.md`.

---

## What this is in two sentences

A Godot 4.7 (GDScript) **real-time squad tactics game**: players buy fixed unit types (over-the-top converted
war machines like the Meshy-generated prison-bus dozer), split them into up to 5 squads, and command them with
taps while autonomous utility-AI brains fight in a neon gladiator arena ([game_design.md](game_design.md)). One
codebase exports to **WebAssembly** (free web version), a **headless server**, and later **Android** (paid app),
with server-authoritative and player-hosted relay multiplayer already working ([vision.md](vision.md)).

## Mental model in one picture

```
 decides                          acts                        shows
┌───────────────────────────┐  TankCommand  ┌────────────┐   ┌──────────────────────┐
│ TacticalMap → SquadCommand│ ────────────▶ │    Tank    │ ─▶│ VisualSlots (themes) │
│ Squad → TankBrain (utility│  (per physics │ (sim only; │   │ camera, HUD, FX      │
│   AI) → OrderController   │     tick)     │  Match has │   └──────────────────────┘
│ PlayerController, Network │               │  the rules)│
│ Input, AgentBridge        │               └────────────┘
└───────────────────────────┘
```

A `Tank` never reads input. Something upstream fills in a `TankCommand`; `Match` owns the rules; art only fills
visual slots, so it can never change the simulation. See [architecture.md](architecture.md).

## Layout

```
Makefile                 every workflow: `make help`
project.godot            engine config: renderer, input map, main scene
export_presets.cfg       "Web" and "Linux Server" export presets
game/
  main.tscn / main.gd    entry point: parses flags, picks a GameMode, owns camera/HUD/local controller
  modes/                 one file per way to run: offline, skirmish, match_runner, garage, title, fx_bench, server, client, host, lobby, det_spike (+ LaunchFlags)
  theme/                 GameTheme (slot → scene, team colors, UI palette), VisualSlot; cyberpunk/ (default look),
                         default/ (placeholder boxes), fx/ (pooled effects, FX lab), audio/ (SFX), gallery/
  match/                 Match: THE RULES (teams, spawners, shells, damage, respawn, score, bots)
  tank/                  Tank (CharacterBody3D + StateSync; emits fired/died), TankCommand (the seam), TankMotion
  combat/                Weapons (data: cannon, flamethrower), Shell, Armor, Ballistics, Impact
  ai/                    Squad + Formations (commander, drills, slots); TankBrain (utility AI) + Directives + Doctrine;
                         OrderController (orders + reflexes → command),
                         BotController (legacy baseline), Steering, Perception, Pathing
  agent/                 AgentBridge: localhost HTTP → OrderController (Claude plays)
  ui/                    TacticalMap (squad command overlay), Hud (hud.tscn = layout, hud.gd = text),
                         widgets/ (CyberFrame, CyberBanner, Conductors, HudSkin, title screen)
  controllers/           PlayerController (keyboard+mouse), ScriptedController (demo/tests)
  network/               NetworkInput (client→server commands + validation), Replication (what syncs),
                         RelayPeer (multiplayer through the broker), ReplayPeer, ui/ (lobby, room badge),
                         detcore/ (integer deterministic-simulation spike: Fixed, DetSim, CommandReplay)
  units/                 Units (the unit catalog) and Army (budgets, seeded CPU armies); round 2: fixed unit types
  garage/                the army builder (fixed unit types, ≤ 5 squads, presets, army codes v2, challenges), results screen, ArmyLoop (rematch)
  progression/           Progression (credits, unlocks, budget tiers: user://profile.json), MatchReport (match result for credits)
  camera/                FollowCamera, RtsCamera (the skirmish camera: pan/zoom/rotate/follow, touch gestures)
  arena/                 collision layout + navigation (mirrored, fair navmesh); art comes from theme slots
tests/                   headless runner + TestCase base + test_*.gd; net/ (bot_client_check.gd, lobby_check.gd, det_spike_compare.py)
doctrines/               armies as JSON (squads, units, directives) for skirmish and the match runner
mk/                      Makefile targets split by area (core, play, net, match, web); root Makefile includes them
tests/baselines/         recorded simulation hash (make sim-baseline)
_agents/streams/         per-workstream briefs (round 3: control, combat, ai, feel, assets, announcer); archive/round1/ and archive/round2/
assets/                  asset pipeline (assets/pipeline/, runtime wrapper), CREDITS, fonts, audio; raw downloads in assets/incoming/ (git-ignored)
server/broker/           match broker (Node + ws): lobbies, relay, resume; `make broker`, `make broker-test`
tools/                   serve_web.py (/ws + /relay proxies), web_smoke/, agent.py (Claude's CLI for the bridge), match_series.py (experiments)
_agents/                 you are here
.tools/  (gitignored)    pinned Godot + export templates, from `make bootstrap`
build/   (gitignored)    exports and screenshots
```

## Common tasks

| I want to… | Do |
|---|---|
| **Command your army (the real game)** | `make skirmish`: StarCraft-style controls (round 3): click or box-select, right-click to move/attack/follow, A attack-move, S stop, H hold, shift queues, ctrl+1–9 groups, G formation, Space pause ([tactical_map.md](tactical_map.md) "v4"). Round 2's tap grammar: `--touch-map` |
| **Build an army, then fight with it** | `make garage` (browser `?garage`): buy units, tap/drag them into squads, pick a tier and opponent, FIGHT → skirmish → results → REMATCH / ARMY. Saved armies: `user://doctrines/`; credits and unlocks: `user://profile.json`. Economy numbers: `make economy-sim` and balance.md "Economy" |
| Play it | `make run` (WASD/arrows drive, mouse aims, click/space fires; 1 bot; `BOTS=3` for more) |
| Verify everything headless | `make check` (then `make check-all` for render + browser + export) |
| Run bot matches / experiments | `make match GREEN=2 RUST=2`, `make matches N=40 JOBS=6 GREEN=2 RUST=2`; doctrine series: `tools/match_series.py --extra="--green-doctrine=res://doctrines/X.json --rust-doctrine=…"` |
| Watch two doctrines fight | `make watch-match GREEN_DOCTRINE=anvil_hammer RUST_DOCTRINE=flame_rush` (nameplates show each brain's intent) |
| Find a GDScript compile error fast | `make lint` |
| Let Claude play | `make server BOTS=1` + `make agent-client`, then `tools/agent.py …` ([agent_bridge.md](agent_bridge.md)) |
| Open the editor | `make editor` |
| Generate art (Meshy; concepts need the lead's review first) | `assets/README.md`, `make assets-generate`, `make assets-unit THEME=prison_dozer`; rules in art_direction.md |
| See the look (cyberpunk is the default theme; `--theme=default` for the boxes) | `make title` (menu), `make vehicle-gallery`, `make hud-gallery`; any mode takes `--perf` (overlay), `--fx-quality=low\|medium\|high`, `--hud-demo`, `--mute`, `--no-shake` |
| Measure an effect's cost | `make fx-bench` (FX lab: per-trick configs, `build/fx-bench.json`; browser `?fx-bench`); results and tier budgets in `_agents/streams/references/fx_tricks.md` |
| Check nothing broke | `make test`, then the relevant rows of [verification.md](verification.md) |
| Check the command UI and camera like a player | `make command-playtest` (headless camera check), `make command-playtest-shots` (frames in `build/command-playtest/`) |
| Check the desktop controls like a player | `make control-playtest` (headless: every order's response tick), `make remote T=control-playtest-shots` (frames in `build/control-playtest/`) |
| See it in a browser | `make serve-web` → http://localhost:8060 (add `?demo`) |
| Prove the web build boots | `make web-smoke` → `build/screenshots/web.png` |
| Play multiplayer locally | `make play BOTS=1`, then open several tabs at http://localhost:8060/?connect (or `make client`) |
| Play with someone on the LAN | `make play WEB_HOST=0.0.0.0`; they open `http://<your-ip>:8060/?connect` |
| Prove networking works | `make net-smoke` (headless) and `make web-net-smoke` (browser) |
| Play a player-hosted match (relay) | `make play-relay`, open `http://localhost:8060/?lobby`: HOST, or tap a room code and JOIN (`?host`, `?join=CODE` work directly) |
| Prove the relay works | `make relay-smoke` (in check), `relay-drop-smoke`, `relay-rejoin-smoke`, `web-host-smoke` (a browser hosts) |
| Measure bandwidth / latency | `make net-measure TANKS=20 CLIENTS=2 LATENCY=150 JITTER=50` |
| Watch a recorded match | `--join=CODE --record=PATH` while playing, then `make replay-watch REPLAY=PATH` |
| Add a tunable to a node | `@export var` in the script; it appears in the editor Inspector |
| Add an input | Add it to `[input]` in `project.godot` (or the editor's Input Map) |
| Add a test | New `tests/test_<thing>.gd` that `extends TestCase` with `test_*` methods |

## Trip-ups (each one cost real time; add yours)

1. **New `class_name` is invisible to headless runs until import.** Godot keeps a global class cache in `.godot/`. Every Makefile target that runs code depends on `make import` for this reason. If you run Godot by hand and see "Identifier not declared", run `make import`.
2. **Forward is −Z, and positive `rotation.y` turns LEFT** (counter-clockwise seen from above). A target on the right needs yaw −90°. `TankMotion.yaw_toward` and its tests encode this.
3. **Controllers must run before the tank each physics tick.** They set `process_physics_priority = -10` (lower runs first). Otherwise the tank acts on last tick's command, which means one frame of lag now and a desync source once networked.
4. **Release exports buffer `print()` and can lose it on exit.** The exported server printed *nothing* until `application/run/flush_stdout_on_print=true` was set in `project.godot`. Debug builds flush by default, so this only shows up in release. Keep it on: server logs must stream.
5. **Web export constraints are absolute:** Compatibility renderer only (WebGL 2), GDScript only (C# can't export to web), and we export **without threads** so any static host works without COOP/COEP headers.
6. **`--headless` uses a dummy renderer.** Tests and exports work headless; screenshots do not. `make screenshot` needs a display. `make web-smoke` does *not*, because Chrome renders with SwiftShader.
7. **The editor rewrites files.** Opening the project in the editor may re-save `.tscn`/`project.godot`: it adds `uid=` attributes, reorders keys, and **may strip comments from `project.godot`**. Commit those diffs; don't fight them. Put explanations that must survive in `_agents/` docs, not only in `project.godot` comments.
8. **`*.gd.uid` files are source.** Godot 4.4+ generates them beside scripts, and they must be committed. Only `.godot/` is cache.
9. **RPCs and synchronizers address nodes by path, which must match on every peer.** That's why tanks are named `Tank_<peer_id>`, built by one spawn function on every peer, and why `spawner.spawn_function` is assigned before connecting. A node that exists on only one side produces "node not found" errors on the other.
10. **`server_relay` defaults to ON.** With it on, any client can send RPCs to other clients *through* the server. `main.gd` turns it off before assigning the server peer (it can't change while a peer is active).
11. **A headless process has no vsync, so it spins a CPU core.** `main.gd` caps `Engine.max_fps` when `DisplayServer.get_name() == "headless"`. A future faster-than-real-time *match runner* must deliberately skip that cap.
12. **The offline peer is a server too.** `multiplayer.is_server()` is `true` with no network. Code that means "am I the dedicated server?" should check `role`, not `is_server()`.
13. **Scene sub-resources (materials) are shared by every instance.** Change one tank's material and all tanks change. `Tank.set_paint()` duplicates before editing.
14. **`cmd | grep &` in a Makefile hides the exit code unless `pipefail` is on.** The Makefile sets `-o pipefail`, and `net-smoke` relies on it to fail when a bot client fails. The flip side is that the shell also runs with `-e`, so an *informational* `grep` that finds nothing aborts the recipe. Append `|| true`.
15. **Collision shapes must cover everything that should be hittable.** Shells fly at barrel height (1.26 m). The hull box originally stopped at 1.05 m, so every shell flew over every tank, and two tests (friendly fire, wall blocks) passed for the wrong reason. The box is now 1.6 m tall.
16. **A script error inside a test function used to print PASS.** The error aborts the coroutine with no assertion failure recorded. The runner now captures engine errors with a `Logger` and fails the test.
17. **"Flaky" is not a diagnosis.** The bot test "failed after the kill test" and looked like cross-test leakage. It was a lethal bot plus a fast respawn restoring full health before the assertion. Print state on failure first.
18. **Put `MultiplayerSpawner`s before the containers they spawn into.** With Tanks listed first, the *release* server export logged "Attempt to disconnect a nonexistent connection … tree_exiting" for each bot at shutdown (debug builds and the editor were clean). Reordering fixed it; `make check-all` guards it.
19. **Never `pkill -f PATTERN` from a shell whose command line contains PATTERN.** It matches and kills itself (exit 144). Save PIDs instead.
20. **Godot's default font lacks block glyphs** (■ █ render as empty boxes). HUD widgets draw █ ▲ ─ through `CyberStyle.font()` (Share Tech Mono + a JetBrains Mono fallback); labels on the default font stay ASCII.
21. **A symmetric map does not give a symmetric navmesh.** The baker's output depends on traversal order; the south base won 64% of matches until the navmesh was built from one half plus its 180° mirror. Run the swap-bases control after any map change.
22. **The navigation map isn't ready right after baking, and "map iteration id > 0" doesn't mean ready.** The first sync can be of an empty map. `Pathing.is_ready()` also checks that a polygon owns a point. `OrderController` falls back to straight-line steering until then.
23. **NavigationMesh `agent_height` must be a multiple of `cell_height`**, and the map's cell size must match the mesh's (`navigation/3d/default_cell_size=0.5` in project.godot). The error-capturing test runner caught the first as an engine error.
24. **Faster than real time = `--fixed-fps 60` and no `Engine.max_fps` cap.** `main.gd` skips the headless cap only in `--match` mode.
25. **`aim` orders never fire.** Twice it cost Claude a life in playtests; use `fire_at_will`/`target` to shoot.
26. **Never point a browser at the game server's port (9080).** It only speaks WebSocket and logs `Missing or invalid header 'upgrade'` for plain HTTP (the lead hit this on first try). The page lives on 8060, and its `/ws` path is proxied to the game server (`tools/serve_web.py`), so `make play` + `http://localhost:8060/?connect` is the only URL anyone needs.
27. **`var x := dict["key"] <= 3` doesn't compile** ("Cannot infer the type"). Dictionary lookups are `Variant`, so `:=` can't infer the type. Write `var x: bool = …` or cast with `float(dict["key"])`. A compile error makes *every* dependent script fail with the misleading "Nonexistent function 'new' in base 'GDScript'". Run `make lint` to see the real message.
28. **Decisions must never read the wall clock.** Brains think on `Match.tick`; iterate tanks sorted by name. `make determinism` (same seed twice → identical result) is in `make check` and fails loudly if someone slips `Time.get_ticks_msec()` into a decision.
29. **A `Control` added under a `CanvasLayer` is 0×0 unless you set offsets too.** `set_anchors_preset(FULL_RECT)` alone left the tactical map sized 0×0: no panels and no mouse input. Use `set_anchors_and_offsets_preset()`.
30. **Doctrine JSON must be listed in `include_filter` in `export_presets.cfg`.** Non-resource files aren't exported by default, so skirmish would fail in the browser and server builds without it.
31. **Headless Godot's root viewport is 64×64.** Anything that turns screen coordinates into GUI hits (pushed mouse events, `gui_get_hovered_control`) silently misses in headless tests. Set `tree.root.size = Vector2i(1280, 720)` first.
32. **Windowed playtest scripts open on the lead's desktop,** where a stray click becomes an in-game order (it happened once: two phantom "bound" orders). Prefer headless tests; keep windowed runs short and say when one is coming.
33. **Balance numbers are spread across weapons.gd (damage, reload, range, spread), tank.gd (max_health), and match.gd (SENSOR_RANGE, arena size).** Re-measure pace (`first_shot_seconds`, `first_kill_seconds` in match stats) and re-run the fairness control after changing any of them. Earlier experiment results (T0–T3) predate the 2026-09-13 rebalance.
34. **Gameplay scenes must not contain meshes.** Art goes through `VisualSlot` + `GameTheme` (streams/archive/round1/assets.md has the slot contracts). A mesh added straight into `tank.tscn` or `arena.tscn` will collide with the look & feel stream's work.
35. **The browser build and the native build do not simulate identically** (measured: same seed, different state hash after 40 s). Determinism holds per build only; don't design cross-platform lockstep on the current physics (streams/archive/round1/netcode.md).
36. **`git stash` removes uncommitted code the running experiment/test depends on.** Don't stash to "test the committed version" mid-change; use a worktree.
37. **Heavy runs queue for a machine-wide slot.** Parallel worktree agents share one 7.6 GB machine, so the root Makefile routes every non-interactive goal through `tools/slot.sh` (2 slots). `>> waiting for a heavy-run slot` is normal, not a hang. Wrap heavy commands you run outside make yourself (`tools/slot.sh python3 tools/match_series.py …`). Runs over 90 minutes are killed.
38. **An unseeded `RandomNumberGenerator` is seeded randomly.** `Match._fire_rng` is only deterministic after `seed_spawns()`; a test that fires spread or scatter weapons without seeding is a dice roll (the artillery test flaked this way, 2026-09-15).
39. **Touch arrives twice.** Godot emulates the mouse from the first finger (`emulate_mouse_from_touch`); those mouse events have `device == InputEvent.DEVICE_ID_EMULATION`. The tactical map uses that to give fingers their own grammar (drag = pan) while real mouse drags still order. Two-finger gestures come only as `InputEventScreenTouch/Drag` (handled in `_input`).
40. **A full-rect `Control` with `MOUSE_FILTER_STOP` eats the wheel.** Events it receives never reach `_unhandled_input`, so the tactical map forwards wheel/middle-drag to `RtsCamera.handle_mouse()` explicitly.
41. **Theme inheritance stops at a `CanvasLayer`.** Setting `get_window().theme` did not restyle the tactical map (a Control under the HUD's CanvasLayer). Set `theme` on the top Control under each CanvasLayer (`HudSkin` does it for the map).
42. **A `Label` outside a container grows to fit new text**, even with autowrap on, so it overflows the width you set once. Re-pin `size.x` each frame (or put it in a container).
43. **Dark glossy floors under a black sky render black blotches** (smooth patches reflect the black background as ambient specular) and glare into pale blobs facing the moon. Keep roughness ≥ 0.5, low specular, and `reflected_light_source = disabled` in night scenes.
44. **A directional light's PSSM 4-split shadows redraw every shadow caster per split.** In the FX lab that was +65 draw calls and 3.3 ms; orthogonal mode with a 110 m max distance looked the same from our cameras.
45. **The Compatibility renderer doesn't batch 3D draws.** A prop built from 23 boxes is 23 draw calls (46 with shadows). Merge static art per material (`StaticBatcher`) or build vehicles as one vertex-colored mesh (`ColorMeshBuilder`); `Decal` and `ReflectionProbe` don't help there (probed).
46. **The tactical overview (Tab) is orthographic, 200 m up, ~3 px per meter** (skirmish starts in gameplay's perspective RTS camera, but the overview is the hard case). Art thinner than ~0.5 m vanishes, and exponential fog thick enough for the 3D view hides most of the map. Judge arena art from `--skirmish` screenshots, not only the follow camera.
47. **Everything Godot imports under the project ships in exports, including `build/screenshots/*.png`.** The web `.pck` was 13.4 MB, almost all screenshots; `exclude_filter` now has `build/*` (0.6 MB). Keep generated files out of exports or out of the project tree.
48. **Packed arrays are values in GDScript.** `for arr in [pos_x, pos_z]: arr.resize(n)` resizes *copies*; the fields stay empty. Edit each field directly (`game/network/detcore/det_sim.gd`).
49. **A GameMode (RefCounted) with no references is freed, and its signal callbacks silently stop firing.** LobbyMode switched `main.mode` to the next mode and lost its own "join failed" handler. Keep a strong reference (`main.set_meta`).
50. **Signal lambdas that capture a refcounted object connected to that same object leak it** (`multiplayer.x.connect(func(): multiplayer…)`, or `peer.sig.connect(f.bind(peer))`). Exit prints "N resources still in use". Connect methods and look the object up inside.
51. **"Stale input" must be judged from when the network was last read, not the physics tick's clock.** A browser host rendering at 2 fps read commands ~500 ms before simulating them and stopped every player's tank (`NetworkInput.command_for_tick`).
52. **Don't trust float math across builds, and especially not trig.** Same seed: `+ − × ÷ √` hashed identically native vs wasm, but `sin/cos/atan2/exp` did not (`make det-spike` FLOAT_PROBE). Lockstep code must use `Fixed` (integers). The simulation today is deterministic only within one build; the inventory, round-2 guidelines, and follow-up are in [determinism.md](determinism.md).
53. **In a doctrine, a squad's `formation` alone means "form up and HOLD here."** `Squad.apply_command` turns a bare formation into `verb: hold`, so a CPU doctrine with formations never leaves its base (every garage CPU army lost 0-6 and drew 0-shot matches against each other until this was found). Player squads want it; CPU squads must omit `formation` and steer with objectives. Measure a new doctrine with a short match series before trusting it.
54. **Tests must not write the player's real `user://` files.** Godot tests run with the same user dir as the game, so a test that opens the garage with default settings consumed the lead's first-run tips. Point stores and settings at test paths (or in-memory), and give automated runs a flag for it (`--garage-scratch`: in-memory settings and an emptied scratch save folder).
55. **`tools/` has a `.gdignore`, so `class_name` scripts there are invisible to Godot.** Godot code goes under `game/` or `assets/` (the asset pipeline lives in `assets/pipeline/`); `tools/` is for Python, shell, and Node.
56. **Anything Godot can see gets imported, and exported unless filtered.** `make import` writes `build/.gdignore`; the web/server presets exclude `build/*`, `tests/*`, `assets/pipeline/*`, and the candidate art themes (`kitbash`, `neon_kit`, `prison_dozer`: 12.5 MB → 0.8 MB web pack). A theme that becomes part of the game must come out of `exclude_filter` in `export_presets.cfg`.
57. **Keep navigation map/region iterations synchronous** (`project.godot` `navigation/world/*_use_async_iterations=false`). With Godot 4.7's async default the navmesh became ready 2–5 physics frames in, depending on machine load, and the same seed simulated differently (sim-baseline failed 4 of 6 runs under load).
58. **Release web templates refuse a scene path on the command line.** To export a different entry scene (e.g. the asset gallery), export a copy of the project with another `run/main_scene` (`tools/assets/web_gallery.sh`).
59. **Agent shells are non-interactive, and Ubuntu's `~/.bashrc` returns early for those.** An `export MESHY_API_KEY=…` at the end of it is invisible to `make assets-generate` run by an agent. Put keys before the interactive guard or in `~/.profile`.
60. **Two streams, one concept: check `main` before inventing a system.** Overnight the garage and gameplay each built a CPU army generator and both used `cpu:balanced` for different armies; integration kept gameplay's `Army` for opponents (garage `ArmyPresets` = player presets). Unknown `cpu:<archetype>` names are now errors instead of silently becoming Balanced.
61. **`get_tree().paused` survives `reload_current_scene()`.** The skirmish's planning pause pauses the tree, so a restart from the results screen came back frozen until `ArmyLoop.restart` unpaused first. To restart with different launch flags, set `Main.next_flags` before reloading (main.gd reads it once instead of the command line / URL); that works the same in the browser.
62. **The theme's panel colors are translucent** (`GameTheme.ui["garage_panel"]` alpha 0.86). An overlay drawn with them over busy UI makes its text collide with whatever is behind. Overlays need an opaque background (the army screen's `_overlay_style`) and a scrim.
63. **The sim baseline hash depends on the machine's glibc, not just the Godot binary.** builder0 (glibc 2.43) and the laptop (2.39) disagree while each is repeatable (libm trig). `tests/baselines/sim_state_hash.txt` keys hashes by glibc version; record with `make remote T=sim-baseline-record` ([determinism.md](determinism.md)).
64. **Heavy runs go to builder0:** `make remote T=check` (6 min 40 s there vs 14–22 min here). See [remote_builds.md](remote_builds.md). Long local background runs can be killed by the session's memory guard: detach with `setsid nohup … &` and poll a log with a unique end marker (Godot prints its own `[ DONE ]` lines).
65. **Remote screenshots can silently repeat one frame.** With a stale Xwayland cookie Godot falls back to Wayland on
    builder0, which stops redrawing a hidden window: every capture after the first is the same image, and a second
    `await RenderingServer.frame_post_draw` never returns. `tools/remote.sh` now reads the running Xwayland's `-auth`
    file. If captures look identical, check the log for `Invalid MIT-MAGIC-COOKIE` (feel, 2026-09-15).
66. **One `make remote` per worktree at a time.** Each run rsyncs `--delete` into the same builder0 folder, so a
    screenshot run started during a `check` swaps the files under it (the check then fails on code it never imported).
