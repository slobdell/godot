# Agent Orientation: Tank Squad

**Read this first. It takes 3 minutes and will save you 30.**

---

## How we manage context (read this if you're starting a new task)

We work on **one high-level task at a time** to limit context rot and token cost.
When a task is complete, the running agent updates `HANDOFF.md` at the project
root before the context window is cleared. A fresh agent with no memory should
regain full situational awareness from `HANDOFF.md` in under 5 minutes.

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
  main.tscn / main.gd    entry point: picks role OFFLINE/SERVER/CLIENT from flags; HUD; local controller
  match/                 Match: THE RULES (teams, spawners, shells, damage, respawn, score, bots)
  tank/                  Tank (CharacterBody3D + StateSync; emits fired/died), TankCommand (the seam), TankMotion
  combat/                Shell (projectile), Armor (facing → damage), Ballistics (lead), Impact (visual)
  ai/                    OrderController (orders + reflexes → command), BotController, Steering, Perception, Pathing
  agent/                 AgentBridge: localhost HTTP → OrderController (Claude plays)
  controllers/           PlayerController (keyboard+mouse), ScriptedController (demo/tests)
  network/               NetworkInput: client→server command relay + server-side validation
  camera/                FollowCamera
  arena/                 ground, walls, crates, sky; arena.gd bakes the (mirrored, fair) navmesh
tests/                   headless runner + TestCase base + test_*.gd; net/bot_client_check.gd
tools/                   serve_web.py, web_smoke/, agent.py (Claude's CLI for the bridge), match_series.py (experiments)
_agents/                 you are here
.tools/  (gitignored)    pinned Godot + export templates, from `make bootstrap`
build/   (gitignored)    exports and screenshots
```

## Common tasks

| I want to… | Do |
|---|---|
| Play it | `make run` (WASD/arrows drive, mouse aims, click/space fires; 1 bot; `BOTS=3` for more) |
| Verify everything headless | `make check` (then `make check-all` for render + browser + export) |
| Run bot matches / experiments | `make match GREEN=2 RUST=2`, `make matches N=40 JOBS=6 GREEN=2 RUST=2` |
| Let Claude play | `make server BOTS=1` + `make agent-client`, then `tools/agent.py …` ([agent_bridge.md](agent_bridge.md)) |
| Open the editor | `make editor` |
| Check nothing broke | `make test`, then the relevant rows of [verification.md](verification.md) |
| See it in a browser | `make serve-web` → http://localhost:8060 (add `?demo`) |
| Prove the web build boots | `make web-smoke` → `build/screenshots/web.png` |
| Play multiplayer locally | `make server`, then `make serve-web` and open several tabs at http://localhost:8060/?connect (or `make client`) |
| Play with someone on the LAN | `make server` + `make serve-web WEB_HOST=0.0.0.0`; they open `http://<your-ip>:8060/?connect` |
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
