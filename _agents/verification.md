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
| 6h | Army flow | `make garage-smoke` and `make army-loop-smoke` (screenshots: `make garage-shots`, `make army-loop-shots` → **Read `build/screenshots/garage-*.png`, `army-results-*.png`**; browser: `make garage-web-smoke` → `web-garage*.png`, `web-army-loop.png`) | nothing (shots: a display) | `--garage` opens the army builder, FIGHT saves the army and the skirmish starts with it (`GARAGE_FIGHT … budget=N green=N rust=N`); the loop shows results, REMATCH replays the same seeded opponent, ARMY returns to the builder; CPU armies fit the tier budget; a challenge mission starts; no `ERROR` | anything touching the army builder, progression, skirmish startup, doctrines, `GameMode.choose`, main.gd restarts |
| 6i | Combat feel and balance (round 3) | `make duel GREEN_UNITS=tank RUST_UNITS=scout,scout` (a text timeline: shots, hits with face and weak spots, poses, intents), `make matchups [FOCUS= ESCORT=]`, `make matchup-search VARIANTS=tools/matchup_variants/<file>.json`, `make pace [CONTROL=1]` (run all on builder0: `make remote T=…`) | nothing | Weapons, weak spots, driving, and deploy play out as designed; counters hold (≥ 65% cost-equal); first shot, first kill, and match length. Results and history: balance.md *Round 3* | anything touching weapons, units, armor, driving, or match rules |
| 7 | Browser multiplayer | `make web-net-smoke` → **Read `build/screenshots/web-net.png`** | Chrome + node | A browser client connects (`TANK_SQUAD_SPAWNED`) to a server with one bot; ~8 s later the screenshot should show the *remote* bot tank near "YOU", team colors, nameplates, and usually shells/damage | anything touching client rendering, spawning, combat visuals, the web export |

| 6e | Relay (player-hosted) | `make relay-smoke` | node | Broker + a headless player **host** (own tank + 2 bots) + 2 headless clients joined by room code: each sees 5 tanks, moves, sees damage replicate; no ERROR anywhere | anything touching networking, modes, RelayPeer, the broker |
| 6f | Broker | `make broker-test` (+ `make broker-smoke`) | node | 31 unit tests: lobbies, star relay, limits, resume with retransmit; the smoke drives the real process | anything in `server/broker/` |
| 6g | Lobby | `make lobby-smoke` | node | `--lobby` tapped through: a wrong code returns with a message; HOST opens a room with its badge | lobby, HostMode, ClientMode |
| 7b | Relay under stress | `make relay-drop-smoke`, `relay-latency-smoke`, `relay-rejoin-smoke` | node | 10 s socket cut resumes the same seat; 150 ms + jitter stays playable; a seat lost past the grace period rejoins and gets its tank back | reconnect, NetworkInput, HostMode |
| 7c | Browser relay | `make web-relay-smoke` → **Read `web-relay.png`**; `make web-host-smoke` → **Read `web-host.png`** | Chrome + node | A browser joins a native host; a browser **hosts** (wasm simulation) and a native client plays in it | anything touching the web export or relay |
| 8 | Cross-build determinism (N2) | `make det-spike` | Chrome + node | The integer core gives identical hashes native vs wasm; prints cost per tick and the float probe | `game/network/detcore/` |
| 8b | Replays | `make replay` | node | A command log replays with every hash verified and a 1-command tamper is caught; a recorded relay match plays back identically | replays, detcore, RelayPeer |

**Measurements (not pass/fail):** `make net-measure TANKS=10 CLIENTS=2 LATENCY=150 JITTER=50` (bytes/s,
snapshot gaps, input delay per player), `make broker-load ROOMS=50` (broker CPU/memory). Results live in
`_agents/streams/archive/round1/netcode.md`.

**Bundles:** `make check` = rows 0, 1, 2, 6, 6b, 6c, 6d, 6e, 6f (unit tests), 6g, 6h incl. army-loop-smoke (headless, ~5 min on a loaded machine). `make check-all` = `check` + rows 3, 4, 5, 7, 7b, 7c and fails on any `ERROR` from the exported server shutting down with bots. **Then read the screenshots.**

**Skirmish screenshots:** `make skirmish-shots` runs a scripted skirmish and saves desktop and phone-aspect (1200×540 = a 2400×1080 phone at 2× UI scale) screenshots to `build/screenshots/`. Look at both after any UI, camera, or fog change.

**Control playtest (round 3):** `make control-playtest` drives a skirmish through real mouse and key events (box select, attack-move across the arena, a queued route, a group swap, a pushed unit rejoining) and fails unless every order's tracks respond within 3 ticks (`build/control-playtest/headless/orders.jsonl`); `make remote T=control-playtest-shots` saves the same session at 1920×1080 and 1280×720. Run after any change to selection, orders, groups, the panel, or the executor, and look at the frames.

**Command playtest:** `make command-playtest` taps each squad's chip, orders it off screen through the radar, and checks the camera (tracking starts, the squad is on screen within 4 s, the view never exceeds the tracking speed, zoom stays in the model view); `make command-playtest-shots` does the same in a 1200×540 window and saves frames plus a UI tour to `build/command-playtest/`. Run after any change to the tactical map, radar, or camera, and look at the frames.

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

## Known flakes

- **net-smoke: `ERROR: Condition "ready_state != STATE_OPEN" is true. Returning: FAILED` in the server log.** Seen on
  builder0 in round 5 (ai stream, 2026-09-17): one of two full `make remote T=check` runs on the same branch failed on
  it, and the next passed. What it is: the WebSocket server logging an error while it shuts down, which fails
  `net-smoke` through its `grep -E 'ERROR' build/net-smoke-server.log`. What it isn't: a networking regression —
  both bot clients printed `NET_CHECK PASS` (tanks 2/2, travel ≥ 3 m, first motion 353 ms). It predates round 5's
  gameplay changes. Most likely a teardown race (the clients disconnect while the server exits); closing the clients
  before killing the server is the probable fix. If it fails with those two PASS lines present, re-run before
  suspecting your change.

- **`ERROR: N RID allocations of type 'RendererDummy::TextureStorage::DummyTexture' / `TextServerAdvanced::ShapedTextDataAdvanced`
  / `FontAdvanced` were leaked at exit`, at the end of a headless run.** Engine shutdown noise from the *dummy*
  renderer and the text server, printed after the run has already passed, and **headless only**: checked by control
  (round 5, 2026-09-17) by playing a real windowed skirmish and quitting cleanly — **zero** `ERROR`, `SCRIPT ERROR` or
  `WARNING` lines, no leak report. A player never sees these. They do not fail a check on their own (the `WARNING: N
  RIDs of type "CanvasItem" were leaked` line beside them is the same thing). If you are hunting a real leak, reproduce
  it in a windowed run first.

- **A test that teleports a vehicle must call `reset_physics_interpolation()`** (or `Fixture.place`). Since combat's
  30 Hz tick turned physics interpolation on, a body assigned a new `global_position` is still *drawn* at its old one
  until the interpolation is reset, so anything reading what the player sees (`Shown`: the camera, selection rings, hull
  bars, unit picking) aims at where it was. Round 5 (control, 2026-09-17): `test_clicking_an_edge_marker_takes_you_to_that_element`
  failed once on builder0 with the camera 40.5 m from the element against a 40 m tolerance — the reported focus
  `(-84.07, -78.89)` is **79% of the way along the teleport**, which is interpolation, not load. Reproduced on demand by
  setting `Engine.physics_ticks_per_second = 4` and reading on the next process frame:
  `test_a_teleported_vehicle_is_drawn_where_it_was_put`. This was the **third** tick-rate trap of the round, after K1's
  `RESPONSE_TICKS` and ai's think cadence: anything measured in ticks, frames or interpolation quietly changes meaning
  when the tick rate does.

## Known limits

- **`make determinism` and `make sim-baseline` prove same-build determinism only.** Native vs WebAssembly runs of the same seed diverge today; nothing checks cross-build agreement for the real simulation yet (follow-up D1 in [determinism.md](determinism.md)).
- The desktop screenshot uses the local Intel GPU (OpenGL 3.3+); the web one uses SwiftShader. Colors and shadows can differ slightly. Neither is a performance measurement.
- `web-net-smoke`'s screenshot timing depends on the bot's drive time; if the bot isn't in frame, the check still passes (it only asserts boot + spawn). Look at the picture.
- Latency and jitter are *injected* (`--relay-latency`, `--relay-jitter`) on localhost; no real cellular link or phone has been measured yet.
- No input-injection tests yet (keyboard/mouse → `PlayerController`). `ScriptedController` covers the command path; the input map mapping itself is untested.
