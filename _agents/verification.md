# Verification: How to Prove a Change Works Without Seeing the Screen

An agent can't watch the game, so "it compiles" is not "it works". Before
calling a task done, run every row that applies to what you touched, and **look
at the screenshots** (Claude can read PNGs). Report failures as failures.

## The ladder

| # | Check | Command | Needs | Proves | Run when |
|---|---|---|---|---|---|
| 1 | Unit tests | `make test` | nothing | Pure logic (`TankMotion`, `TankCommand`) | always |
| 2 | Integration tests | `make test` (same runner) | nothing | Real scenes + real physics frames: commands actually move tanks | always |
| 3 | Desktop render | `make screenshot` → **Read `build/screenshots/demo.png`** | a display | The scene renders: lighting, meshes, camera framing, turret direction | any visual/scene change |
| 4 | Web boot | `make web-smoke` → **Read `build/screenshots/web.png`** | Chrome + node | The WebAssembly build loads in a real browser, logs `TANK_SQUAD_READY`, no console errors, renders | any change, before a task is "done" |
| 5 | Server boot | `make export-server && build/server/tank_squad_server.x86_64 --headless --quit-after 120` | nothing | The stripped release server binary starts and runs `main.gd` (prints `TANK_SQUAD_READY`) | anything touching startup, exports, server |

Coming with M2: **bot-client network test** (a headless client connects to a
headless server and asserts replicated state). With M5: **match runner** reports.

## Writing tests

- Put a file `tests/test_<topic>.gd` that `extends TestCase`; every `test_*` method runs on a fresh instance.
- Assertions: `assert_true`, `assert_eq`, `assert_near`. They record and continue, so one run shows all failures. **Write the message as the physical meaning** ("turret swings to face a target on the right"), not the mechanics ("rotation.y == -1.57").
- Scene tests: `add_to_tree(SCENE.instantiate())` (freed automatically), then `await wait_physics_frames(n)`.
- Prefer extracting math into a pure class (like `TankMotion`) over testing through nodes.
- A test that can't fail is worse than none. When adding one, briefly break the code to confirm it goes red.

## How the checks work (so you can extend them)

- `tests/run_tests.gd` is a `SceneTree` script run with `--headless --script`. It discovers tests, awaits each (so tests can wait on physics frames), and calls `quit(1)` on failure, so `make test` fails CI-style.
- `--screenshot=<abs path>` is handled in `game/main.gd`: wait 3 s, `await RenderingServer.frame_post_draw`, save the viewport image, quit. It requires a real renderer, so not `--headless`.
- `tools/web_smoke/smoke.mjs` (puppeteer-core + system Chrome with SwiftShader WebGL): serves `build/web`, opens `/?demo`, waits for the `TANK_SQUAD_READY` console line, screenshots, and fails on page exceptions or `console.error`.
- `TANK_SQUAD_READY` is printed by `main.gd` after wiring. **If you rename it, update `smoke.mjs`.**

## Known limits

- The desktop screenshot uses the local Intel GPU (OpenGL 3.3+); the web one uses SwiftShader. Colors and shadows can differ slightly. Neither is a performance measurement.
- No input-injection tests yet (keyboard/mouse → `PlayerController`). `ScriptedController` covers the command path; the input map mapping itself is untested.
