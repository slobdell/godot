# Agent Orientation: Tank Squad

**Read this first. It takes 3 minutes and will save you 30.**

---

## How we manage context (read this if you're starting a new task)

We work on **one high-level task at a time** to limit context rot and token cost.
When a task is complete, the running agent updates `HANDOFF.md` at the project
root before the context window is cleared. A fresh agent with no memory should
regain full situational awareness from `HANDOFF.md` in under 5 minutes.

**If you were started as a WORKSTREAM agent** (gameplay, look & feel, assets, netcode, garage), read
[workstreams.md](workstreams.md) and your brief in `streams/` right after this file: they define what you own
and the contracts you must not break.

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

A Godot 4.7 (GDScript) tank game that exports to **WebAssembly for browsers**
and to a **headless Linux server binary** from one codebase, with real-time
server-authoritative multiplayer over WebSockets (M2), team combat with
server bots (M3), an HTTP bridge that lets Claude command a tank (M3.5), and
M4 infrastructure: navmesh pathing, reflexes, and a faster-than-real-time match runner. The destination is
a squad-strategy game where players author *doctrine* for 5 tanks, eventually
via an on-device LLM on Android, rather than driving tanks by hand
([vision.md](vision.md)).

## Mental model in one picture

```
 decides                      acts                       shows
┌──────────────────┐   TankCommand   ┌────────────┐   ┌────────────────┐
│ PlayerController │ ─────────────▶  │    Tank    │ ─▶│ camera / render│
│ ScriptedController│  (per physics  │ (sim only) │   └────────────────┘
│ NetworkInput (M2) │    tick)       └────────────┘
│ UtilityController (M4)│
└──────────────────┘
```

A `Tank` never reads input. Something upstream fills in a `TankCommand`. Every
future feature (networking, squad AI, LLM doctrine) is a new thing on the left
side of that arrow, not a change to the tank. See [architecture.md](architecture.md).

## Layout

```
Makefile                 every workflow: `make help`
project.godot            engine config: renderer, input map, main scene
export_presets.cfg       "Web" and "Linux Server" export presets
game/
  main.tscn / main.gd    entry point: parses flags, picks a GameMode, owns camera/HUD/local controller
  modes/                 one file per way to run: offline, skirmish, match_runner, server, client (+ LaunchFlags)
  theme/                 GameTheme (slot → scene, team colors, UI palette), VisualSlot, default/ placeholder art
  match/                 Match: THE RULES (teams, spawners, shells, damage, respawn, score, bots)
  tank/                  Tank (CharacterBody3D + StateSync; emits fired/died), TankCommand (the seam), TankMotion
  combat/                Weapons (data: cannon, flamethrower), Shell, Armor, Ballistics, Impact
  ai/                    Squad + Formations (commander, drills, slots); TankBrain (utility AI) + Directives + Doctrine;
                         OrderController (orders + reflexes → command),
                         BotController (legacy baseline), Steering, Perception, Pathing
  agent/                 AgentBridge: localhost HTTP → OrderController (Claude plays)
  ui/                    TacticalMap (squad command overlay), Hud (hud.tscn = layout, hud.gd = text)
  controllers/           PlayerController (keyboard+mouse), ScriptedController (demo/tests)
  network/               NetworkInput (client→server commands + validation), Replication (what syncs)
  camera/                FollowCamera
  arena/                 collision layout + navigation (mirrored, fair navmesh); art comes from theme slots
tests/                   headless runner + TestCase base + test_*.gd; net/bot_client_check.gd
doctrines/               team plans as JSON (squads, weapons, directives) for the match runner
mk/                      Makefile targets split by area (core, play, net, match, web); root Makefile includes them
tests/baselines/         recorded simulation hash (make sim-baseline)
_agents/streams/         per-workstream briefs (gameplay, look_and_feel, assets, netcode, garage)
tools/                   serve_web.py, web_smoke/, agent.py (Claude's CLI for the bridge), match_series.py (experiments)
_agents/                 you are here
.tools/  (gitignored)    pinned Godot + export templates, from `make bootstrap`
build/   (gitignored)    exports and screenshots
```

## Common tasks

| I want to… | Do |
|---|---|
| **Command squads (the real game)** | `make skirmish` (or browser `?skirmish`): click = who, right-drag = where/facing, Q-T drills, Z-N formations, Tab 3D view |
| **Build an army, then fight with it** | `make garage` (browser `?garage`): tap/drag units into squads, pick weapons, FIGHT → skirmish. Saved armies: `user://doctrines/` |
| Play it | `make run` (WASD/arrows drive, mouse aims, click/space fires; 1 bot; `BOTS=3` for more) |
| Verify everything headless | `make check` (then `make check-all` for render + browser + export) |
| Run bot matches / experiments | `make match GREEN=2 RUST=2`, `make matches N=40 JOBS=6 GREEN=2 RUST=2`; doctrine series: `tools/match_series.py --extra="--green-doctrine=res://doctrines/X.json --rust-doctrine=…"` |
| Watch two doctrines fight | `make watch-match GREEN_DOCTRINE=anvil_hammer RUST_DOCTRINE=flame_rush` (nameplates show each brain's intent) |
| Find a GDScript compile error fast | `make lint` |
| Let Claude play | `make server BOTS=1` + `make agent-client`, then `tools/agent.py …` ([agent_bridge.md](agent_bridge.md)) |
| Open the editor | `make editor` |
| Check nothing broke | `make test`, then the relevant rows of [verification.md](verification.md) |
| See it in a browser | `make serve-web` → http://localhost:8060 (add `?demo`) |
| Prove the web build boots | `make web-smoke` → `build/screenshots/web.png` |
| Play multiplayer locally | `make play BOTS=1`, then open several tabs at http://localhost:8060/?connect (or `make client`) |
| Play with someone on the LAN | `make play WEB_HOST=0.0.0.0`; they open `http://<your-ip>:8060/?connect` |
| Prove networking works | `make net-smoke` (headless) and `make web-net-smoke` (browser) |
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
20. **Godot's default font lacks block glyphs** (■ █ render as empty boxes). Keep HUD text ASCII.
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
34. **Gameplay scenes must not contain meshes.** Art goes through `VisualSlot` + `GameTheme` (streams/assets.md has the slot contracts). A mesh added straight into `tank.tscn` or `arena.tscn` will collide with the look & feel stream's work.
35. **The browser build and the native build do not simulate identically** (measured: same seed, different state hash after 40 s). Determinism holds per build only; don't design cross-platform lockstep on the current physics (streams/netcode.md).
36. **`git stash` removes uncommitted code the running experiment/test depends on.** Don't stash to "test the committed version" mid-change; use a worktree.
37. **Heavy runs queue for a machine-wide slot.** Parallel worktree agents share one 7.6 GB machine, so the root Makefile routes every non-interactive goal through `tools/slot.sh` (2 slots). `>> waiting for a heavy-run slot` is normal, not a hang. Wrap heavy commands you run outside make yourself (`tools/slot.sh python3 tools/match_series.py …`). Runs over 90 minutes are killed.
38. **In a doctrine, a squad's `formation` alone means "form up and HOLD here."** `Squad.apply_command` turns a bare formation into `verb: hold`, so a CPU doctrine with formations never leaves its base (every garage CPU army lost 0-6 and drew 0-shot matches against each other until this was found). Player squads want it; CPU squads must omit `formation` and steer with objectives. Measure a new doctrine with a short match series before trusting it.
39. **Tests must not write the player's real `user://` files.** Godot tests run with the same user dir as the game, so a test that opens the garage with default settings consumed the lead's first-run tips. Point stores and settings at test paths (or in-memory), and give automated runs a flag for it (`--garage-settings=none`).
