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
| 9 | **Playability (local only)** | `make squad-orders-test`, `make response-test` | a display, a quiet machine | The player can actually command the game: five squads ordered in turn all arrive and hold (never arrived 0, arrived-then-left 0, idle element commands 0), and an order reaches a moving vehicle in ~150 ms at 30 a side. **Neither is in `make check`** -- they need a display and take minutes, and builder0's remote desktop draws ~1 fps, so they must be run on the laptop | **before a round is called done**, and after anything touching orders, selection, brains, elements or the tick rate |
| 8b | Replays | `make replay` | node | A command log replays with every hash verified and a 1-command tamper is caught; a recorded relay match plays back identically | replays, detcore, RelayPeer |

**Measurements (not pass/fail):** `make net-measure TANKS=10 CLIENTS=2 LATENCY=150 JITTER=50` (bytes/s,
snapshot gaps, input delay per player), `make broker-load ROOMS=50` (broker CPU/memory). Results live in
`_agents/streams/archive/round1/netcode.md`.

**Bundles:** `make check` = rows 0, 1, 2, 6, 6b, 6c, 6d, 6e, 6f (unit tests), 6g, 6h incl. army-loop-smoke (headless, ~5 min on a loaded machine). `make check-all` = `check` + rows 3, 4, 5, 7, 7b, 7c and fails on any `ERROR` from the exported server shutting down with bots. **Then read the screenshots.**

**Skirmish screenshots:** `make skirmish-shots` runs a scripted skirmish and saves desktop and phone-aspect (1200×540 = a 2400×1080 phone at 2× UI scale) screenshots to `build/screenshots/`. Look at both after any UI, camera, or fog change.

**Control playtest (round 3):** `make control-playtest` drives a skirmish through real mouse and key events (box select, attack-move across the arena, a queued route, a group swap, a pushed unit rejoining) and fails unless every order's tracks respond within 3 ticks (`build/control-playtest/headless/orders.jsonl`); `make remote T=control-playtest-shots` saves the same session at 1920×1080 and 1280×720. Run after any change to selection, orders, groups, the panel, or the executor, and look at the frames.

**Command playtest:** `make command-playtest` taps each squad's chip, orders it off screen through the radar, and checks the camera (tracking starts, the squad is on screen within 4 s, the view never exceeds the tracking speed, zoom stays in the model view); `make command-playtest-shots` does the same in a 1200×540 window and saves frames plus a UI tour to `build/command-playtest/`. Run after any change to the tactical map, radar, or camera, and look at the frames.

**Look & feel checks** (need a display; look at every PNG): `make fx-bench` (effect costs per trick; compare against the tier budgets in streams/references/fx_tricks.md), `make vehicle-gallery` (slot methods driven with fake values), **`make facing-audit`** (every faction unit side-on with the engine's forward marked: run it after any new or re-imported vehicle art — round 7 found the gang IFV and the Syndicate lancer driving backwards, and the lead had only noticed one of them; "nobody has complained" is not evidence the art is right), `make hud-gallery` and `make title-shot` (desktop + phone aspect), and the real game with `--skirmish --hud-demo --screenshot=…` (the tactical camera is the hard case for arena art). Headless tests cover the pooling/budget logic (`tests/test_fx_systems.gd`), banner lifecycle (`test_hud_widgets.gd`), and vehicle slot contracts (`test_theme_vehicles.gd`).

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

## Timing in tests: measure in `make check`, judge elsewhere (policy, 2026-09-19)

**`make check` does not gate on how long something takes.** It is the thing six to nine agents run at once on builder0
(an i5-1345U: 2 hyperthreaded P-cores + 8 E-cores, 12 threads) and on the shared laptop, so a wall-clock assertion there
is a claim about *other streams' activity*, and when it fails it looks like a code defect. Found by control, ruled by
the orchestrator:

- **The evidence.** `test_control_scale`'s frame budget (absolute 2.0 ms, 11% headroom over the idle laptop's 1.80) went
  red in #19 on builder0 at **2.33 ms, where idle builder0 is ~0.65 ms** (`9c889025`), and on the laptop at load 4–8
  (2.2–3.1 ms). One bare click-to-order sample read **24 ms for ~4 ms of work** (laptop, load 7.8).
- **A ratio fixes a busy machine, not a full one.** Timing the work interleaved with a fixed reference workload
  (`control_fixture.gd`: `reference_work`, `fastest_ms`) and budgeting their ratio cancels core type (P vs E) and
  throughput: the control frame held at 18.8–20.2 reference workloads across loads (laptop, `35c72304`), and +1 ms of work
  still fails it (30.2 against 26). **But with 7 CPU burners on the laptop's 8 threads the order path went from 3 ms to
  42 ms (~14×) as the fastest of 10 samples, while the reference only doubled**: a slice of engine work also waits on
  engine worker threads, and a single-threaded GDScript yardstick can't see those starve.

**The rule:**
1. **In `make check`, timing is a printed measurement (`MEASURE ...`), never an assertion.** Prefer a ratio to a
   reference over raw milliseconds even as a measurement: it compares across machines.
2. **Timing verdicts belong to a separate target run on purpose on an uncontended builder0**, with `sim-profile`
   (`mk/match.mk`) as the precedent.
3. **A timing check that must stay a gate asserts its own precondition and REFUSES** (*"not judged: reference workload
   2.1× nominal, machine too loaded"*), and the summary counts it as not judged, **never as a pass**. A silent skip is
   lesson 91.
4. **Liveness timeouts are not budgets.** A timeout catches a hang, and a hang doesn't care whether it's 120 s or 600 s:
   make them generous (`garage-smoke`/`army-loop-smoke`: 60/120 → 600 s at `d8f26176`; they ran 10 s and 18 s on the
   laptop, only ~6× headroom against a measured 14× starvation, and a timeout failure reads as a deadlock).
5. **A bound with 30× headroom is a smoke check, not a budget; label it as one.** `match-smoke`'s `speedup > 2`
   (58–84× on builder0) and `test_visibility`'s 200 ms refresh (3.2–5.9 ms on builder0) can't flake and can't catch a
   regression. Either give them a real budget in the timing target, or say in the message that they are sanity bounds.
6. **One sample is the most exposed shape.** Take the fastest of N, and use the test's own natural reference where it has
   one (a cache hit against the same test's cold load).

**A verdict over time in a live fixture is a race by construction.** control's "an order not carried out is called out
after 2 s" tests stubbed what each gun was on, but the fixture's own brains kept fighting, killed the target inside the
grace, and the order died with it: 1 run in 4 went red, confirmed by printing the target's health (0) in the failure
message. Freeze what the verdict depends on (a durable target, `_keep_alive` in `test_control_order_refused.gd`), or
build without the brains — and when a timed test flakes, print the world's state in its failure message before
theorising.

**When a grep for timing turns up a hit, say why it isn't one.** From the 2026-09-19 survey: tick counts
(`test_control_response`, `test_responsiveness`) are sim time; `test_combat`'s respawn waits on the same `SceneTree` timer
the game uses (`match.gd`), so both sides move together; a camera test that waits wall-clock for a rotation driven by the
same process delta is consistent. Those are not exposed.

**Status:** **control complies** — its four timing budgets (frame, order, click, health bars) print `TIMING NOT JUDGED
(make control-timing judges): …` in `make check`, tagged `[OVER BUDGET]` when they would have failed, and assert only under
`make control-timing` (`TANK_SQUAD_JUDGE_TIMING=1`, `mk/command.mk`); the pattern is `Fixture.judge_timing` in
`tests/support/control_fixture.gd`. Positive control: +1 ms in the panel's `summary()` fails `control-timing` and leaves
`make check` green with the tag. Other streams' timing assertions are still gates (the survey above). `test_theme_factions.gd:63` (cache hit < 5 ms,
one sample) is routed to feel.

||||||| baf04ead

## Attributing a behaviour's cost: switch it off (nav, round 7)

The only honest way to say what one mechanism contributes is to **remove it and measure again**, never a
per-mechanism ratio read off a combined run. nav keeps one switch per movement behaviour:
`--nav-off=grace,minpace,pushidle,carrot,yield,unstick,repath,chord,guard,backup,standoff` (and `r5sidestep` turns a
REMOVED round-5 behaviour back on), passed as `NAV_FLAGS=--nav-off=…` to `make nav-where` / `nav-fight`, or set
`Movement._off` in a test. The table of what each isolates is in [navigation.md](navigation.md) *Measuring*.
How it paid: a fix dropped head-on maze-60 from 60/60 to 27/60; one run per switch (guard off 57, chord off 48,
backup off 34) named the culprit in an hour instead of a day of reasoning.

Two traps, both hit: **a switch that silently does nothing** makes "no difference" meaningless — prove each switch
moves some number first; and **once a branch is merged, `main` is no longer the before-picture** — bisect on named
commits. And a regression can come from something **removed**, which no switch of added behaviour will find.

## Positive controls: assert the run is the run you think it is, from inside it

**Every measurement script asserts its own conditions before it reports a number, and exits non-zero if they are
not met.** Not around the run — *inside* it, where the setup actually is.

**The reason, and it is the whole argument:** the arena stream produced six wrong numbers in one day, and **three
assertions would have caught every one of them** —

1. **the map is the one named** (every faction-matrix number this project has quoted was a *foundry* number, and
   the tool said so nowhere);
2. **the objectives are where the layout says** (a CPU competing for the wrong ground looks completely functional);
3. **the armies are the size requested** (`NAV_UNITS=60` on a layout with 52 spawn points put **eight pairs of
   hulls in eight positions**; those hulls cannot move, and their failures were published as congestion).

A stream that can say *"three assertions would have caught every wrong number I produced today"* has an unusually
strong case for spending an hour on assertions rather than features.

**Why this is not the same as a careful measurement window.** Arena's `centre_sees_share` is measured over a fixed
extent so the number cannot be **gamed** by a layout declaring itself bigger. That is worth doing and it is not
enough: **it still does not assert that the thing you think you are measuring is present in the run.** A fixed
window survives a hostile layout; only an assertion inside the run survives someone changing the setup — including
a future agent who has never read any of this.

**The shape to copy** (`tests/arena/maze_probe.gd`, `_positive_control`): check what the run depends on, print one
`*_CONTROL ok: …` line naming the conditions when they hold, and on failure `push_error` each problem and
**exit 1 before writing any output**. A number from a run whose conditions were not met is worse than no number,
because **it looks exactly like a real one**.

**A control states the condition it checked and what it therefore refuses to report. It does not explain why the
condition matters.** The first version of arena's said *"…spawn slots wrapped, and those hulls cannot move, so
every arrival number below would be wrong"* — a **diagnosis the control cannot verify**, and one that had gone
stale a round earlier: coincident hulls have parted by name since round 6. It was true when written and false when
read, and **a stale diagnosis in a failure message is worse than one in a document, because it arrives at the
moment someone is deciding what to do** — that sentence nearly had nav's 60/60 arrival result held out of a merge
as void. The replacement says only what is permanently true:

> `8 pairs of units started on top of each other: spawn slots wrapped, so this run is not the experiment named
> (60 distinct start points). No number written.`

**And when a control fires on your own setup, fix the cause rather than downgrading the assertion to a warning.**
`NAV_UNITS=60` on a 52-slot layout genuinely was not the experiment it named; the probe now offsets the surplus
units so it is. A warning is the invisible-skip failure in another costume.

Idea from combat, after two of its designator runs measured a different game than it thought and no check caught
either.

### And the layer above it: a comparison must prove its arms differ (combat, round 7)

A positive control asks *did the treatment engage in this run*. It passes happily on **two arms that are secretly
the same arm** — and that is not a hypothetical, because arena hit the identical gap the same day in its
`--swap-bases` fairness tool: it had asserted *which arena*, while the thing that could silently fail was *whether
the swap applied*. **An assertion about the stage is not an assertion about the experiment.**

**This is what a broken comparison looks like.** It is `tools/compare_arms.py` with its arm-distinguishability
check removed — the mutation test for that guard:

```
faction             treatment      control     delta
gangs                   70% n=20         35% n=20       +0 pts
law                     35% n=20         35% n=20       +0 pts
syndicate               45% n=20         45% n=20       +0 pts
```

Clean, symmetric, well-powered, and completely empty: **the answer you were hoping for, reached by the treatment
never having happened.** Nobody reading that suspects anything, which is why the guard has to be mechanical.
`make compare-arms` refuses four things — the same file twice; a different commit, machine, or a dirty tree; a
different arena, budget, seeds, time limit or faction list; and identical arms.

Two rules fell out of building it:

- **A guard that fires on the good case teaches its user to ignore it.** The output path is *supposed* to differ
  between two arms, so requiring it to match would refuse every correct comparison.
- **Assert against what the RUN emitted, not what the caller passed.** A flag is what you asked for;
  `MATCH_RESULT`'s `controls` is what happened. `compare_arms` compares recorded `args`, so a flag that was
  accepted, recorded and then silently inert still looks fine to it. **Per comparison, against emitted state, is
  the version still unbuilt** — the honest edge of all three guards.

**And guards get mutation-checked like anything else — more, not less.** A guard sits on the hot path of every
future run, and this round shipped one that crashed every run it was added to protect and another whose refusal
`return 2` was discarded by a bare `main()` call, so it **exited 0 and reported success to make**. Watch the guard
fail before you trust it.

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

## Why two tests failed depending on what ran before them (2026-09-19)

**`tests/run_tests.gd` runs every test file in ONE process, sharing one `SceneTree` and every autoload.** The loop is:

```gdscript
var case: TestCase = script.new()
case.tree = self          # the SAME SceneTree for every case, all run long
await case.call(method_name)
case.teardown()           # isolation is whatever this happens to do
```

**So isolation is honour-system, per case, and everything in an autoload survives the whole run** — `Pathing`'s baked
navmesh, `Arena.active`, `Units.tuning`, `GameTheme.slots`, and any node a teardown forgot. **A test's result is therefore
a function of the order the suite happens to run in, and that order changes whenever anyone adds a file.**

**Two round-7 failures, both in files whose owners had not seen them, both exposed by an unrelated timing change:**

| failure | what it read that the previous test left |
|---|---|
| `test_navigation::test_path_goes_around_a_wall` — path goes straight through the wall | `_setup` waits for **`Pathing.is_ready`** — *any* navmesh — so after another test bakes a different arena it paths against **that** mesh. Lesson 87: a readiness check on a property, not an identity. `TacticsLab.navigation_is_this_arenas()` is the fix |
| `test_units_roster::test_the_catalog_is_where_stats_come_from` — muzzle y **0.26** against catalog **1.12** | the assertion read `turret.GLOBAL_position.y`, so it claimed **both** *the catalog sets the muzzle above the hull* (deterministic) **and** *the hull has settled one physics frame after spawn* (physics, and whatever state the previous test left). The scout was sitting **0.86 m low** |

**`Units.tuning` was the first suspect and was innocent** — it tunes shields, damage and armour, never a muzzle height,
and clears both dictionaries at the end of its body.

### Two rules from it

1. **One assertion, one claim** (combat). *"A conflated assertion cannot tell you which of its claims broke — the failure
   gets attributed to whatever changed most recently."* That is precisely how this arrived as a guess about a static in a
   third stream's file. **If a claim needs the physics world to have settled, say so and give it the frames.**
2. **Wait on identity, never on a symptom** (arena, lesson 87). *"Every previous fix of mine made the property more
   specific; only identity ends it."*

### The root cause is NOT fixed, and both fixes above only hide it

**Something earlier in a full run leaves the world in a state where a tank has not settled after one physics frame.**
combat flagged this rather than claiming closure: its fix makes the symptom invisible to that test. **If nav's navmesh
case has the same root — a test reading world state a previous test left — finding it is worth more than either fix.**

**Proposed for round 8, NOT now** (`run_tests.gd` is shared and six streams have checks in flight; breaking the runner
mid-round would stop everybody): **after each `teardown()`, the runner asserts the world is clean** — no leftover tanks in
the tree, `Arena.active` cleared, `Units.tuning` empty, no baked navmesh — and **FAILS naming the test that leaked**,
rather than letting the next test inherit it. **A guard, not a documented discipline: today proved that a warning written
by the stream that later hit it was not enough** (lesson 117).

## Filming a march for a human to judge (nav, round 8)

A capture meant to answer "does this group read as squads or as a herd?" has its own failure mode, and it is silent: the
frames come back, the target exits 0, and nothing in them shows the thing being judged. `nav-flow-look` on terminus at
the lead's own camera (pitch 21, 122 m) put the camera at street level among 40 m city blocks, which hid nearly every
vehicle, and the unit nameplates covered the rest. Before quoting a look as evidence:

- pitch 45-55 degrees on a map with tall cover (the lead's 21 degrees is for watching ONE hull turn, not a formation);
- nameplates off, or the shot is labels;
- frame the camera on the army's middle and keep it there as the army moves;
- look at a frame from the middle of the march, not only the first and last.
