# Verification: How to Prove a Change Works Without Seeing the Screen

An agent can't watch the game, so "it compiles" is not "it works". Before
calling a task done, run every row that applies to what you touched, and **look
at the screenshots** (Claude can read PNGs). Report failures as failures.

## The ladder

| # | Check | Command | Needs | Proves | Run when |
|---|---|---|---|---|---|
| 0 | Lint | `make lint` | nothing | Every script parses (shows the real compile error instead of cascading "Nonexistent function 'new'") | always, first |
| 1 | Unit tests | `make test` | nothing | Pure logic (`TankMotion`, `TankCommand`, armor/lead/steering, **TankBrain.decide golden cases**, directives, doctrines) | always |
| 2 | Integration tests | `make test` (same runner) | nothing | Real scenes + real physics frames: commands actually move tanks | always |
| 3 | Desktop render | `make screenshot` → **Read `build/screenshots/demo.png`** | a display | The scene renders: lighting, meshes, camera framing, turret direction | any visual/scene change |
| 4 | Web boot | `make web-smoke` → **Read `build/screenshots/web.png`** | Chrome + node | The WebAssembly build loads in a real browser, logs `TANK_SQUAD_READY`, no console errors, renders | any change, before a task is "done" |
| 5 | Server boot | `make export-server && build/server/tank_squad_server.x86_64 --headless --quit-after 120` | nothing | The stripped release server binary starts in SERVER role (prints `TANK_SQUAD_LISTENING` and `TANK_SQUAD_READY role=SERVER`) | anything touching startup, exports, server |
| 6 | Network | `make net-smoke` | nothing | A headless server + **2 headless bot clients** over real WebSockets: each gets a tank, sees both tanks, and its tank moves by ≥ 3 m *as replicated from the server*. Server log must contain no `ERROR` | anything touching main.gd, tanks, controllers, networking |
| 6b | Combat over network | `make combat-smoke` | nothing | A headless server with a bot + a stationary bot client: the client's replicated health must drop (the server bot aimed, fired, and hit; damage replicated). Also prints any kills from the server log | anything touching combat, shells, bots, Match |
| 6d | Determinism (T0) | `make determinism` | nothing | The same seed + doctrines twice gives byte-identical results: no wall clock or unordered iteration in decisions | anything touching brains, Match, intel, orders |
| 6c | Match runner | `make match-smoke` | nothing | A seeded 2v2 bot match finishes via its limit, prints `MATCH_RESULT`, has shots, runs > 2× real time, logs no errors | anything touching Match, bots, orders, navigation, main.gd roles |
| 7 | Browser multiplayer | `make web-net-smoke` → **Read `build/screenshots/web-net.png`** | Chrome + node | A browser client connects (`TANK_SQUAD_SPAWNED`) to a server with one bot; ~8 s later the screenshot should show the *remote* bot tank near "YOU", team colors, nameplates, and usually shells/damage | anything touching client rendering, spawning, combat visuals, the web export |

**Bundles:** `make check` = rows 0, 1, 2, 6, 6b, 6c, 6d (all headless, ~2 min). `make check-all` = `check` + rows 3, 4, 5, 7 and fails on any `ERROR` from the exported server shutting down with bots. **Then read the screenshots.**

**Look & feel checks** (need a display; look at every PNG): `make fx-bench` (effect costs per trick; compare against the tier budgets in streams/references/fx_tricks.md), `make vehicle-gallery` (slot methods driven with fake values), `make hud-gallery` and `make title-shot` (desktop + phone aspect), and the real game with `--skirmish --hud-demo --screenshot=…` (the tactical camera is the hard case for arena art). Headless tests cover the pooling/budget logic (`tests/test_fx_systems.gd`), banner lifecycle (`test_hud_widgets.gd`), and vehicle slot contracts (`test_theme_vehicles.gd`).

**Experiments** (`make matches …`) are not pass/fail checks, but any change to the map, spawning, navigation, or combat rules should re-run the fairness control: `python3 tools/match_series.py --godot <godot> --runs 60 --green 2 --rust 2` and again with `--extra=--swap-bases`. Win rates should stay near 50/50 ([squad_ai_design.md](squad_ai_design.md) "Fairness").

**Playtesting with the agent bridge** is the last rung: not automated, but it finds design problems no assertion will ([agent_bridge.md](agent_bridge.md)).

Coming with M4: **match runner** results (JSON) for AI experiments.

## Writing tests

- Put a file `tests/test_<topic>.gd` that `extends TestCase`; every `test_*` method runs on a fresh instance.
- Assertions: `assert_true`, `assert_eq`, `assert_near`. They record and continue, so one run shows all failures. **Write the message as the physical meaning** ("turret swings to face a target on the right"), not the mechanics ("rotation.y == -1.57").
- Scene tests: `add_to_tree(SCENE.instantiate())` (freed automatically), then `await wait_physics_frames(n)`.
- **Brain behavior gets golden tests on hand-built Situations** (`tests/test_brain_decide.gd`): name the behavior a player expects ("a flanker goes for the side of an enemy busy with a teammate"). If a heuristic change breaks one, decide whether the *behavior* or the *test* was wrong, and write down why. (Example: investigating a remembered enemy was losing to marching blindly at the enemy base; the scoring changed, not the test.)
- **Watch it, too:** `make watch-match` shows every brain's intent on its nameplate.
- **Assert on the lowest/highest value seen, not the value at the end, when the thing can recover.** `test_bot_engages_a_visible_enemy` once "failed" because the bot killed the target and it respawned at full health before the check. The bot worked; the test was wrong. It was diagnosed by printing state on failure, not by re-running (see trip-ups).
- **Confirm a new combat/physics test can fail.** The first armor tests "passed" friendly-fire and wall-blocking checks only because *every* shell was flying over the tanks' collision boxes.
- Prefer extracting math into a pure class (like `TankMotion`) over testing through nodes.
- A test that can't fail is worse than none. When adding one, briefly break the code to confirm it goes red.

## How the checks work (so you can extend them)

- `tests/run_tests.gd` is a `SceneTree` script run with `--headless --script`. It discovers tests, awaits each (so tests can wait on physics frames), and calls `quit(1)` on failure, so `make test` fails CI-style. `make test FILTER=combat` runs tests whose `file::method` contains the text.
- **Any engine or script error during a test fails that test.** The runner registers a `Logger` (`OS.add_logger`, Godot 4.5+) that collects errors. Without it, a script error aborted a test function silently and the test printed PASS.
- `--screenshot=<abs path>` is handled in `game/main.gd`: wait 3 s, `await RenderingServer.frame_post_draw`, save the viewport image, quit. It requires a real renderer, so not `--headless`.
- `tools/web_smoke/smoke.mjs` (puppeteer-core + system Chrome with SwiftShader WebGL): serves `build/web`, opens `/?demo`, waits for the `TANK_SQUAD_READY` console line, screenshots, and fails on page exceptions or `console.error`.
- Markers printed by `main.gd`: `TANK_SQUAD_READY` (wired), `TANK_SQUAD_LISTENING` (server), `TANK_SQUAD_CONNECTED` / `TANK_SQUAD_SPAWNED` (client). `smoke.mjs` takes the marker to wait for as its 4th argument. **If you rename one, grep the Makefile and `tools/`.**
- `tests/net/bot_client_check.gd` is a `SceneTree` script that waits for the server's TCP port, instantiates the *real* `main.tscn` (which reads the same `--connect`/`--demo` flags), and watches `Tanks/Tank_<my peer id>.sync_position`. It isn't named `test_*`, so `make test` doesn't pick it up. **The `NET_SMOKE_EXPECT` override exists to prove the check can fail:** `make net-smoke NET_SMOKE_EXPECT=3` must exit non-zero.

## Known limits

- The desktop screenshot uses the local Intel GPU (OpenGL 3.3+); the web one uses SwiftShader. Colors and shadows can differ slightly. Neither is a performance measurement.
- `web-net-smoke`'s screenshot timing depends on the bot's drive time; if the bot isn't in frame, the check still passes (it only asserts boot + spawn). Look at the picture.
- Nothing measures latency or jitter yet; everything runs on localhost.
- No input-injection tests yet (keyboard/mouse → `PlayerController`). `ScriptedController` covers the command path; the input map mapping itself is untested.
