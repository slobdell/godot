# Native code: the vehicle brain's hot loop in C++ (round 23, stream native)

> Added 2026-10-08. The lead (2026-10-07): the army he builds is too small, *"double it"*; 25 a side already goes into
> slow motion on his laptop once everyone is in contact, and the cost is the per-vehicle tick (round 22's verdict:
> ~0.6–0.8 ms a vehicle, four fifths the brain, a flat profile, equal-answer cuts ≤ 2 %). He asked whether native meant
> Rust; the recommendation taken: **C++ through godot-cpp** (`game_design.md` *Round 23 direction: the launch*).
> This file: how it is built, the flags and why, the hazards, how the proof is run. The stream's brief and numbers:
> `streams/native.md` (then `streams/archive/round23/native.md`).

## What exists

| piece | where | what |
|---|---|---|
| the sources | `native/src/` | `TankNative` (a `RefCounted`; `register_types.cpp` is the entry `tank_squad_native_init`) |
| the build | `native/CMakeLists.txt`, `native/build.sh`, `mk/native.mk` | `make native` → `native/bin/libtank_native.linux.x86_64.so` + `native/bin/tank_squad.gdextension` |
| the binding | `.tools/godot-cpp-10.0.0-stable/` (source, pinned tag + sha256) and `build-<key>/` (that machine's build) | godot-cpp 10.0.0-stable, CMake, against the API dumped from our 4.7.2 binary |
| the seam | `game/ai/native/native_bridge.gd` | `NativeBridge.available` (ClassDB has `TankNative`), `NativeBridge.impl` (the instance the seams call) |
| the switch | `game/ai/brain_switches.gd` `native` (the master) + one sub-switch per port (`native_dodge`, `native_avoid`) | ON while available; `--brains-off=native`, the in-run A/B (`--brains-ab-run=native`, or one port: `=native_avoid`) |
| the ports | `incoming_fire.gd` `closest_approach` (N0, the no-op); `combat_motion.gd` `would_be_hit` (N0b); `avoidance.gd` `solve` with `refresh`/`load_rows` loading the native table (N1) | `if BrainSwitches.native and BrainSwitches.native_<port>: return NativeBridge.impl.<fn>(...)` above the GDScript, which stays as the reference |
| the tests | `tests/test_native*.gd`, `tests/native/native_info.gd`, `tests/native/native_bench.gd` | bit-for-bit equality over seeded inputs per port; the `NATIVE` line that says which way a run went; the price of one call |

**The game runs without it.** No `.gdextension` → nothing loads → `NativeBridge.available` is false → every seam runs
its GDScript. That is the web build (no web entry; C18.7), `make check NATIVE=off`, and any machine without cmake and a
C++ compiler. The suite passes both ways and prints which (`NATIVE ...` in `test_native`'s output).

## How to build

```bash
make native                 # godot-cpp once per machine (minutes; ccache after), then native/src (seconds); switches ON
make native NATIVE=off      # switches OFF: removes native/bin/tank_squad.gdextension
make native-info            # NATIVE <build_info()> | switch on/off
make check                  # runs native-for-check first: builds and switches on (or OFF: NATIVE=off / no toolchain)
make check NATIVE=off       # the suite without the library (the web build's case); both must be green
make native-clean           # this worktree's build and library; the machine's godot-cpp stays (make distclean removes .tools)
NATIVE_CPUS=4-11 NATIVE_JOBS=8 make native   # builder0: pin the compiles to the E-cores, leave the P-cores to perf-judge
```

`native/build.sh` does it in order: (1) the godot-cpp tarball into `.tools/` (sha256 checked); (2) `extension_api.json`
dumped from `$(GODOT)` (`--dump-extension-api`; re-dumped when the binary is newer); (3) the binding built ONCE PER
MACHINE AND FLAG SET under `.tools/godot-cpp-<ver>/build-<sha of flags+godot tag>/` under a `flock` (two worktrees may
ask at once; `.tools` is one directory per machine, a symlink in every worktree, and builder0's `~/tank_squad/.tools` is
shared by every remote folder); (4) this worktree's extension into `native/build/` (a `.gdignore` inside, so Godot's
scan never walks the objects) and `native/bin/`; (5) the `.gdextension` copied from `native/tank_squad.gdextension.in`.

**Why these places.** `.tools` and `build/` are the two directories `tools/remote.sh` neither uploads nor deletes on
builder0; `native/bin` and `native/build` ARE uploaded (small) and would be `--delete`d, so a **host stamp**
(`native/bin/.built-on`, `native/build/.stamp`: host, tree, flags, godot-cpp) makes a machine rebuild anything that
arrived from another one — builder0 never tests a laptop-built library, and the copy-back never brings builder0's to
the laptop (it only mirrors `build/`). A vendored submodule under `native/` was the alternative and loses on both
counts (34 MB up every run, its build products deleted every run).

**Why a generated `.gdextension`.** Godot prints `ERROR: GDExtension dynamic library not found` for a listed library
that is missing, and `tools/engine_log_gate.py` fails any check target on an `ERROR:` line. So a run without the
`.so` must see no `.gdextension` at all: it exists only beside a library `make native` built, and `make import` (every
target's first step; `check` runs `native-for-check` just before it) is what registers or forgets it with Godot
(`.godot/extension_list.cfg`). The editor sees it the same way (`make native`, then `make editor`).

**Why CMake.** cmake and ccache are on both machines, scons on neither (a pip package; builder0 has no venv to put it
in); godot-cpp 10 ships first-class CMake (`GODOTCPP_CUSTOM_API_FILE`, `GODOTCPP_TARGET`, `GODOTCPP_PRECISION`). Our
`CMakeLists.txt` links the binding as an IMPORTED static library and repeats its PUBLIC usage requirements by hand
(`GDEXTENSION DEBUG_ENABLED THREADS_ENABLED LINUX_ENABLED UNIX_ENABLED`, `-static-libgcc -static-libstdc++`, the two
include dirs): an imported target carries none, and the headers must see the ABI the library was built with.

**Why `template_debug`, one `.so` for both feature tags.** The editor binary (every test, his skirmish) loads the
`linux.debug.x86_64` entry; a release export loads `linux.release.x86_64`. Both point at the one file: the numeric
flags are identical, only godot-cpp's internal `DEBUG_ENABLED` checks differ, and every number is proven under the
editor binary. A `template_release` flavour is a line in `mk/native.mk` the day an export needs it.

## The flags and why (`NATIVE_FP_FLAGS` in `mk/native.mk`: `-O2 -ffp-contract=off -fno-fast-math`)

The proof is bit-exactness against GDScript running inside the engine binary, so the C++ must round where the engine
rounds and nowhere else:

- **`-ffp-contract=off`:** gcc fuses `a*b+c` into an FMA by default in GNU mode when the target has one; an FMA rounds
  once where the engine rounds twice. (Without `-march` the x86-64 baseline has no FMA instruction anyway; the flag
  makes it a rule rather than a coincidence.)
- **No `-march=native`, no `-ffast-math`, no `-Ofast`, no reassociation:** each changes results in the last bits; the
  engine's official binary is built for baseline x86-64 with none of them.
- **`-O2`, not `-O3`:** -O3's vectorisation reorders reductions only under fast-math, so it would be safe, but -O2 is
  what the numbers are taken at and nobody needs to re-prove the port for a flag.
- **The same flags for the binding and for us** (the key of the binding's build directory), and `-std=c++17` without
  GNU extensions, `-fno-exceptions`, `-fvisibility=hidden` as godot-cpp uses.
- **Single precision** (`GODOTCPP_PRECISION=single`): the official 4.7.2 binary is single-precision, so `real_t` is
  float32 in both; `static_assert(sizeof(real_t) == 4)` in `tank_native.cpp`.

## A fresh checkout, the build's cost, and what ships

- **`make bootstrap` does not build the library; `make check` and `make native` do.** The game runs without it
  (every seam falls back to its GDScript), so a fresh checkout plays at once and gets the native speed after one
  `make native`. Measured: godot-cpp cold on builder0's eight E-cores 228 s (1089 TUs); on the laptop 1703 s under a
  load of 11 (the baseline measurement and two agents' work beside it) — expect ~8–10 min on a quiet laptop
  (its threads are ~2× an E-core's time; `-j8`), then seconds for `native/src`, and ccache makes every rebuild of the
  binding after a flag change a minute. `make doctor` says ON/OFF and where it was built.
- **No prebuilt `.so` in the repository.** It is a machine's artefact: the glibc it was linked against decides
  where it loads. Measured: builder0's library (Ubuntu 26.04, glibc 2.43) imports `sqrtf`/`atan2f`/`acosf`/`asinf`
  at `GLIBC_2.43` (glibc 2.43's new versions, pulled in by godot-cpp's own library) and so **does not load on the
  laptop (24.04, glibc 2.39)**; the laptop's library needs `GLIBC_2.38` at most and loads on anything newer.
  libstdc++ and libgcc are static (godot-cpp's default), so the C++ runtime is not a factor.
- **So a release's `.so` is built on the oldest glibc the release targets** — his laptop (or a 24.04 container),
  never builder0 — and ships inside the export (the Linux Desktop preset packs `native/bin/*.so` with the
  `.gdextension` automatically; the Web presets exclude `native/*`). An export made on builder0 is for builder0:
  on his laptop its library fails to load with an `ERROR: GDExtension dynamic library not found`-style line and the
  game plays on GDScript. When Android comes, its `.so` is a cross-compile from the same sources (an arm64
  `linux`-style target in `mk/native.mk`), and the equality proof runs there too (the trig hazard: Android's libm).
- **His son's fresh checkout:** `make bootstrap`, `make native` (one coffee the first time), `make skirmish`. Without
  cmake and a C++ compiler the same checkout plays, slower at scale, and `make doctor` says why.

## The hazards (each a rule for every port)

1. **Two float widths.** GDScript `float` is double; `Vector3` members are float32; a `Vector3 * float` narrows the
   scalar to float32 first; `Vector3(a, b, c)` from floats narrows each; `v.length()`, `.dot()`,
   `.length_squared()` compute in float32 and widen on return. Write each port line by line against the GDScript with
   the width GDScript has at that point (see `closest_approach` in `tank_native.cpp`: the comment is the GDScript). A
   float32 op computed in double and narrowed is the float32 op (double rounding is innocuous at 53 ≥ 2·24 + 2 bits
   for + − × ÷ √), so either spelling is exact; the trap is a double kept where GDScript narrowed, or the reverse.
2. **Trig and libm:** GDScript's `sin`/`cos`/`atan2`/`sqrt` on a `float` are the engine's `Math::sin(double)` → glibc's
   `sin`; call the same double functions (never `sinf`), and know that glibc versions differ in the last bits
   (`determinism.md`: builder0's lines are canonical, the laptop skips the baseline).
3. **Iteration order and memo semantics:** a port of a loop keeps the GDScript's order (neighbours by distance then
   name; Dictionary insertion order in `decide`'s tie-breaks), and a memo keyed the same way answers the same.
4. **Packed columns are float32:** `PackedFloat32Array` stores float; read float, compute where GDScript computed.
5. **The bridge is dynamic, and a call costs more than a small function.** `NativeBridge.impl` is an `Object`; the
   class name cannot appear in GDScript (it would not parse on a machine without the library), so `impl.fn(...)` is
   a Variant call: a method lookup, every argument converted, a Variant back. **N0 measured it:** the ten-line
   `closest_approach` ported alone came back 3.7 % SLOWER on the controller band (one call per dodge step, ~2000 a
   tick). The seam rule that follows: **one call must replace tens of microseconds of GDScript** (ORCA's `solve`,
   a whole loop like `would_be_hit`, later the execute step per tank), never a function the call itself outweighs.
   `make native-bench` prints the floor per call on a machine.
6. **If a piece cannot be made bit-exact, it is a DECLARED change** (C22.2, C23.1): one commit, alone, lines adopted and
   named, the paired series showing equal outcomes; second choice, said in advance.

## The proof (every port, every commit)

| what | command | passes when |
|---|---|---|
| the unit half | `make test FILTER=native` | `test_native`: every ported seam equals its GDScript BIT FOR BIT over seeded inputs; the `NATIVE` line says which way the run went |
| the match hash, one machine | `make native-proof` (`AB_FLAGS="--green-elements --rust-elements"` for leaders) | the Sumps match (Law v Condemned, seed 92721, 180 s) prints ONE state hash native on, `--brains-off=native`, and the 30-tick A/B |
| the price | `make ai-ab-match AB_SWITCH=native` (every port) or `=native_avoid` (one port) (× 3, `taskset -c 0-3` on builder0) | `BRAINS_AB <switch>:` the controller band ON v OFF; hashes equal |
| the full suite, both ways | `make remote T=check` and `make remote T="check NATIVE=off"` | green; the thirteen lines and determinism UNMOVED (pre-registered) |
| the behaviour digests | `make ai-parity`, `make element-digest` | unchanged |
| the two machines | `make native-proof` on the laptop AND on builder0 | each machine equal to ITSELF (the glibc rule: the two machines' hashes differ by libm, native or not) |

For a divergence: `--hash-every=N --hash-until=T --hash-detail-from=T0` (determinism.md) on the on/off pair names the
first tick and field; `tests/scale/witness_first_field.py` reads two dumps.

## What is ported (round 23)

| step | commit | one call replaces | proof |
|---|---|---|---|
| N0 `IncomingFire.closest_approach` | `8503f23e` | 10 lines (0.28 µs): the no-op, +3.7 % SLOWER: the call floor | 4000 samples |
| N0b `CombatMotion.would_be_hit` | `792945cf` | the dodge loop: every round × every 0.1 s step | 3000 samples |
| N1 `Avoidance.solve` (+ `refresh`/`load_rows` feed the table) | `4fe82371` | neighbours + ORCA + three linear programs, ~90 µs | 1500 solves, crowds, overlaps, oriented |
| N1b `CoverMap.clear_line` / `_coarse` / `path_blocked` | `26168cca` | the grid walk + slab tests + memo, 10–25 µs | 19 200 answers, the memo's count |
| N2b `Movement._chord_compute` (its sampling loop), `_outline_ok`, `_arc_hit` (C23.1 hunks) | `ea93d133` | the chord's 1–2 probes as one call; the ten outline probes as one; the whole k-turn sweep (up to 57 steps × 10 probes) as one | 400 poses × 3 functions equal to the LIVE movement.gd functions (native off) on every check; **OFF by default** (~1 % of the band) |
| N2a `Pathing.closest_point` → `NavNative` (C23.1a) | `589db189` | the engine's O(polygons) scan: 25 µs → 1.9 µs a call (laptop), 429 calls a tick at 50 v 50 | 5 611 points on the Sumps + 13 maps × 961, equal to `map_get_closest_point` bit for bit |

Each is a sub-switch under `native` (`native_dodge`, `native_avoid`, `native_cover`) so `ai-ab-match AB_SWITCH=<name>`
prices one step alone. Every price so far is single digits of the controller band (the brief's expectation); the
ceiling of per-piece ports is the marshalling and the fact that the big lines are Dictionary-shaped state machines.

## The rules for a seam (round 24: two workloads, one for each half of the brain)

- **Execute ports** (the drive, the route, avoidance): the headless in-run A/B (`make native-price`, builder0
  `taskset -c 0-3`, his Sumps / 25 v 25 / 50 v 50 with leaders, n = 3, hashes equal): ON when the 50 v 50 mean is
  ≥ 2 % of the controller band outside 2 se (round 23's rule).
- **Think ports** (situation, decide, act, the matchups, the scan): **the laptop's windowed in-contact number**
  (`make native-tick-profile` on the laptop: his preset, 25 a side, foundry + parade × three seeds, TickProfile over
  8–20 s of match time = the opening contact, n = 6 per arm): ON when the arm saves ≥ 2 % of the tick's scripts
  outside 2 se, hashes equal (the headless A/B is the second reading). Why: the headless A/B is a whole-match mean in
  which contact is a fraction; in contact the brains are think-heavy (think 16.1 ms a tick v execute 8.8 at 25 a side,
  `26009842`, laptop), so a think port's worth shows only there. The orchestrator's ruling, 2026-10-09.
- **The table that set the rule** (`26009842`, flightdeck, n = 6 per arm, load ~2; `references/round24/native/
  tick-profile-26009842/`): tick scripts in the window, native as shipped **34.9 ms** (controllers 25.8 = 74 %,
  elements 5.3, priority 0 3.8; the engine's physics step 0.6 between ticks; frame 125.9 ms at 2.96 ticks: the
  catch-up cap); `--brains-off=native_drive` 36.6 (the drive −4.6 % in contact); `--brains-off=native` 42.7 (all
  native −18 %); `--brains-on=native_situation,native_matchups` 35.6 (`brain/situation` −0.45 ms, se 0.08, = 1.3 % of
  the tick: under the bar; `decide` unmoved); `--brains-on=native_scan` 36.9 (worse: +2.05, se 0.56). So situation,
  matchups and scan stay OFF by this rule too.

## What is ported (round 24)

| step | seam (switch) | one call replaces | proof (every check) |
|---|---|---|---|
| N3a the record + contacts | none yet (`native_record`, OFF: nothing reads it) | — | `test_native_record`: every field == its live value |
| Avoidance's table, gathered natively | `Avoidance.refresh` (the `native` master) | the per-tick GDScript table build (578 µs a tick at 50 v 50) | `test_native_avoid_gather`: every column, grid, index, still flag |
| N3b `weapon.scan` | `Gunnery._nearest_shootable` (`native_scan`) | the loop over the other team, range + seen gates, the sight ray | `test_native_scan`: 300 poses, live and through the seam |
| N3b `move.path` | `Movement._next_waypoint`'s tail (`native_path`; reached only with `native_drive` off) | the route follower after the re-plan block | `test_native_route`: 463 poses, live and through the seam |
| **N3c `Movement.drive`** | top of `drive` (`native_drive`) | the whole drive; callbacks into the live GDScript for: `Pathing.query`/`_inflate_corners` (re-plans), `_around_fire` on its check ticks, the k-turn PLANNER, `_keep_station`, `_repair`, `_blocker`, `_negotiate` | `test_native_drive`: every mover driven both ways from one snapshot of all movers (command + every member + every static + the station PID): a 12-hull fight (2160 drives) and a k-turn scenario (1440 drives, 22 plans, 671 leg ticks) |

| N3d `situation` core | `build_situation`'s first block (`native_situation`, **OFF**: in contact −1.97 % paired, se 0.8 %, laptop `211b5375`, under the 2 % bar written before the table; headless 50 v 50 +2.0 %) | allies, contact selection, contact entries | `test_native_situation`: 2353 situations built both ways |
| N3d `decide` (**ON**: in contact −4.3 % of the tick's scripts, se 1.4 %, laptop `2b761799` n = 6; headless 50 v 50 +2.3 %, se 0.25, builder0 `bcd4d699` n = 3, hashes equal) | top of `TankBrain.decide` (`native_decide`; the default arm: flat commitment, no switch probe) | every option's score, `_obey`, cooldowns, the flip-back, commitment, the choice and `_top`; candidates built as the same Dictionaries in the same order, so ties break the same way (EQUAL, not declared) | `test_native_decide`: 6990 decisions (real situations + mutated copies reaching every order verb, drill verb, cooldown, flip, variant, empty gun, control point, blocked lane), 21 options chosen, 0 mismatches |
| N3d `matchups_for` | top of `TankBrain.matchups_for` (`native_matchups`) | 70 % of `decide` (85 of 121 µs, builder0): Matchups' time-to-kill math and `Armor.facing` per contact | `test_native_matchups`: 2393 real situations + orbit cases (10 868 orbit entries); `decide` asked both ways too; the C++'s constants held to matchups.gd's and armor.gd's |

`decide_native.cpp` reads each contact once into a C++ row and the unit table directly (`_is_prey`, `rounds_barely_mark`,
`SuppressionFeed.suppresses`, `ElementFeed.is_firing_base` ported: they were per-contact calls into GDScript); what is
left of its ~50 µs (live ~96, builder0) is building the candidate Dictionaries the GDScript consumers read.

**Correction (round 24, the same night):** the shipped brain (`BrainVariants.CHAMPION` = `x18m`) has `"matchups": false`,
so `decide` never calls `matchups_for` in play; the "70 % of decide" above came from a probe that timed
`matchups_for` directly. The port is right and proven, and serves the variants that use it (a5, x3m, x4mw); for the
shipped brain it saves nothing (its windowed in-contact arm: `decide` +0.03 ms, se 0.07). `decide`'s ~120 µs is its own
scoring. `matchups_native.cpp` ports functions of `game/ai/matchups.gd` and `game/combat/armor.gd` (brains' and combat's): the
proof asks the LIVE functions, so an edit there that the C++ does not follow fails the check (the N2b pattern) — the
owner then either edits both or turns `native_matchups` off and asks native.

The native drive runs only in the default configuration (`NativeDrive.usable`: no `--nav-off=` switch, no
`reverse_log`/`kturn_log`, `chord_memo` on); constants come from the live scripts at first use (`configure`), so an
edit to a constant is followed. `--native-drive-profile` prints the drive's per-callback µs. The match hash is
unchanged with every port on (`native-proof` at `d0bc1517`, builder0: `e155255c75dd2e2a` his Sumps, `f07b7b3e16d6b37f`
with leaders).

## The plan from here (written before a line of it is coded; the orchestrator's rule)

**What the band is made of** (`make native-sizing`: 50 v 50 with leaders, builder0 pinned, n = 3; the numbers in
`streams/archive/round23/native.md` Status and here). Read it as three buckets: the EXECUTE step (every tick: move,
avoid, weapon, unstick), THINK (every 3–9 ticks: situation, decide, act), and inside each the ENGINE calls that stay
engine calls in any port (`NavigationServer3D.map_get_closest_point`, path queries, physics rays).

**N2a — the navmesh's closest point, natively indexed (the biggest single line; equal-answer by construction). BUILT
(`589db189`): the laptop's `native-proof` band −15.2 % with every port on (−5.2 % before it), hashes unmoved.**
`nav.closest` is 300–900 `map_get_closest_point` calls a tick at 50 v 50 and ~35 µs each on builder0 because the
engine's query (4.7.2 `NavMeshQueries3D::map_iteration_get_closest_point_info`) is a LINEAR SCAN of every polygon of
every region with no broadphase. The port: at arena load, read each region's `navigation_mesh` polygons and
`global_transform` (the half and its π-mirror), transform the vertices exactly as `NavRegionBuilder3D` does (float
`Transform3D::xform`), keep the engine's region-then-polygon order, index polygon AABBs in a grid; a query expands rings
until the ring bound exceeds the best distance, then evaluates the candidate SUPERSET in the original order with the
engine's own per-polygon code (copied line for line: `real_t`, the strict `<`, the per-region `is_zero_approx` break)
so the first strict minimum is the same polygon and the same point. Proof: thousands of points (a lattice over the
arena plus random, on every dealt map) equal to `map_get_closest_point` bit for bit, then the hash proofs. Expected:
each call from ~35 µs to a few µs: −15 to −30 % of the band at 50 v 50, more than every brain port together. The seam
is `Pathing.closest_point` (`game/ai/pathing.gd`, brains'): a one-function grant through the orchestrator, or
`NativeBridge` wraps it from movement's call sites (mine after CP1).

**N2b — movement's geometry: BUILT, PROVEN EQUAL, OFF (~1 % gain)** (`ea93d133`, the proof `f1342298`, OFF
`d8e292b4`): `_chord_compute`'s sampling loop, `_outline_ok` and `_arc_hit` each one native call over N2a's index
(`nav_native.cpp`), behind `native_move`; the seams route only in the forms they port (`chord_memo` hoisted;
`kturn_cap`; the lazy start pose when it is this pose's), so the other switches' A/Bs stay exact. The proof
(`tests/test_native_movement_geometry.gd`) asks the LIVE `Movement` each pose through the seam and with `native` off,
so a brains edit to that geometry that the C++ does not follow fails the check (it sets `native_move` itself, so it
runs while the switch is off). **Price** (`native_move` alone, builder0 `taskset -c 0-3`, n = 3, `f62dd96d`, leaders,
hashes equal): his Sumps −0.57 / −0.70 / −1.26 % (mean 0.85, se 0.21), 25 v 25 −0.81 / −0.82 / −1.31 % (0.98, se 0.17),
50 v 50 −3.86 / −0.72 / −1.62 % (2.07, se 0.93). The orchestrator's bar (judged at 50 v 50: mean ≥ 2 % and outside 2 se)
is met only by run 1 on a box ~33 % heavier (band 28.7 v 21.5 ms); the two clean runs average 1.2 %. **Ruled OFF**:
lesson 276 asks that a seam clearly pay. Turn it on (one line, `brain_switches.gd`) if a quieter series or the
laptop's price shows ≥ 2 %. Why so little: N2a already made the closest-point calls these loops make cheap; what
is left is a handful of vector ops per probe. `_around_fire` was not ported: the whole function is 0.8 ms a tick at
50 v 50 (~2 % of the brains' work) and its cost is `Match.threat_along` (`game/match/match.gd`, not native's).
`_avoid`'s own geometry was left: its cost is the avoidance call (N1).

**N3 — the execute step as one native call per tank per tick (where −60 % would live).** `Movement.drive` is 4 000
lines of state machine over `ctl.tank.*` and Dictionaries; `decide` ties by Dictionary order; `build_situation` reads
nodes, `AiTickCache`, match intel. A port that keeps the GDScript as the reference needs the DATA reshaped first: a
per-tank native record (position, heading, speed, hull, the last command, the neighbour set, the cover-map handle, the
route), a per-team contacts table filled once a tick, and `TankCommand` built natively. **Honest sizing:** the execute
step's non-engine share (the sizing table's number) is the ceiling of N3; its engine share (nav queries, rays) moves
only by N2a-style re-implementation. It is a multi-round job (the state machine's ~140 `ctl.tank.*` touch points),
and bit-exactness through a Dictionary-ordered state machine is unlikely end to end: expect a DECLARED change (C22.2),
the lead's to accept, with the paired series as the proof. The alternative levers are not native's: the stride (brains'
B3: −15 to −25 %, OFF by his call), a think-rate / LOD design (think less often or less widely for crews far from the
player's fight), or the cap at 25.

## N3a — the data the C++ owns, and the execute step's map (round 24; written before N3b is coded)

### The data (BUILT: `native/src/tank_record.{h,cpp}`, `game/ai/native/native_record.gd`, `tests/test_native_record.gd`)

- **The per-tank record** (`TankNative.record_gather`, ONE call a tick): one row per living hull under `tanks_root`,
  in Avoidance's table order, **gathered by the C++ itself** (it walks the children and reads each member: 0.03 µs a
  member read from C++, `make native-bench` at `c8da555e`; the first version packed the columns in GDScript and cost
  +3.5 / +5.4 / +2.5 % of the band at 50 v 50, builder0 pinned, `46fd0596`). GDScript supplies only its statics, once
  per id (each unit's hull numbers, each weapon's range). float32 columns (stride 15): position, forward (`-basis.z`), estimated velocity, the last
  command's aim point, the turret's forward. float64 (stride 9): `speed()`, the last command's throttle and turn,
  `max_forward_speed`, `hull_turn_rate`, `Avoidance.radius_of`, the hull's halves, `wheel_radius()`. int32 (stride 4):
  team, health, the last command's fire, `_path_index`. The routes concatenated (`PackedVector3Array` + offsets). The
  neighbour set is asked when needed (`record_neighbours(row)`: Avoidance.neighbours' answer over N1's table AT THAT
  MOMENT; the fill never calls `Avoidance.refresh`, whose `_still` column reads other movers' `is_under_way()` and so
  depends on WHEN in the controller phase it is built). The routes and `_path_index` are the snapshot at the fill
  (N3c's mover rows own the live route). The cover map's handle (the
  arena's `CoverNative` instance id). Widths as hazard 1: nothing is converted on the way in.
- **The contacts table** (`TankNative.contacts_gather`, one call per team, the intel Dictionary handed over by
  reference): `match.intel[team]` in name order (sorted natively by String's `<`, as `Array.sort`; never through
  `AiTickCache`'s memo, whose timing a fill must not move), the raw fields plus
  `weapon_range`. The derived per-team fields (`gun_ready_in`, the faded suppression) are N3d's.
- **TankCommand built natively:** `command_into(row, cmd)` writes a row's command (throttle/turn double, aim
  float32, fire) into the controller's `TankCommand` with four property sets inside one call.
- **The proof:** every field read back equals the LIVE value it came from (`==` and the same Variant type), the
  neighbour set equals `Avoidance.neighbours`, 200 commands written natively equal the GDScript's, the contacts equal
  the intel (`tests/test_native_record.gd`). `NativeRecord.layout_ok()` holds the GDScript strides to the library's.
- **The switch:** `native_record` (OFF; nothing reads the record yet). ON, `Avoidance.refresh` fills both once a tick
  (profile part `native.fill`), so `ai-ab-match AB_SWITCH=native_record` prices the marshalling.

### The execute step's call graph, and equal or DECLARED per function

Read at `bfc00f53` (= round 23's close; brains' bridge fix (CP1) may move `_next_waypoint`/`Pathing`, and N3b
re-reads the map on main's frozen code). The shares column is `make native-sizing` with `--brains-parts`, 50 v 50
with leaders, builder0 `taskset -c 0-3` (see *The shares* below for the run). **Every row is EQUAL-answer by plan; no
row of the execute step needs a DECLARED change.** The reasons, once: the execute step draws no random numbers,
iterates no Dictionary to break a tie (its one Dictionary loop is `queue_census`, measurement), and every engine query
in it (navmesh closest point and path, physics rays) is either N2a's exact index or the same engine function called
from C++ (godot-cpp's `NavigationServer3D` / `PhysicsDirectSpaceState3D`: the same code, the same bits). The DECLARED
risk of N3 lives in think (`decide`'s Dictionary-ordered ties, N3d), not here.

```
OrderController.compute_command                 (order_controller.gd: brains', NOT frozen; stays GDScript, calls the seam)
├─ movement.bind; _sense; _apply_reflexes                       c.reflexes   (rays only under halt_on_contact)
├─ _apply_move
│  ├─ movement.right_of_way          (yield: Steering + another mover's state, read by name)
│  ├─ movement.idle / face / drive-order branches (OrderController's; tiny)
│  └─ movement.drive  ───────────────────────────────────────────── N3c: ONE native call per tank
│     ├─ within_leash, _repair_for, _track_goal                    (pure state)
│     ├─ _approach_gate → _curved_gate (Clothoid), Pathing.closest_point (N2a)          path.gate
│     ├─ _next_waypoint → Pathing.query [nav.path, rare: replans], _inflate_corners,
│     │                   _along_route, _chord_on_mesh [nav.chord], _corner_beyond      move.path
│     ├─ _around_fire → SuppressionFeed.beaten/along → Match.threat_along               move.fire
│     ├─ _remaining_path_distance                                                       move.remaining
│     ├─ _avoid → Avoidance.refresh + solve (N1), Pathing.closest_point (N2a)           move.avoid
│     ├─ give-way pacing (B1)                                       (pure state)
│     ├─ _guard_steer → _chord_on_mesh                                                  move.guard
│     ├─ Steering.drive_toward(_wheels) / reverse_*, _circle_gate, _planned_reverse
│     │    (k-turn: _arc_hit/_outline_ok = N2b, _plan_fill, _rollout, _look_stop)        steer.drive
│     ├─ _nose_stop, _note_wedge, _keep_station (Pid + ControlGains)                    steer.station
│     └─ _track_progress, _update_phase (_blocker, _repair → Pathing.query),
│        _negotiate (_hull_ahead, another mover's ask()/_begin_yield)                   move.steer
├─ movement.unstick → _pressing_escape (WallContact.swing_of), _hull_within, _ask_behind
├─ gunnery.apply → _scanned_shootable/_nearest_shootable (AiTickCache.enemy_columns,
│                  _shootable: Perception's ray) [weapon.scan], aim/lead [weapon.aim], lanes  weapon
└─ movement.note_decision (contact.decided Dictionary; driver_ticks counters)
TankBrain.think's every-tick prologue: _poll_order / _poll_element / OrderFeed.station        t.poll (think's file; N3d)
```

| function (part) | equal how | what crosses the seam |
|---|---|---|
| `Steering.*` (inside `steer.drive`) | equal: four pure functions; doubles where GDScript has `float`, `signed_angle_to`/`normalized` in float32, `sin`/`cos` the double libm calls (hazard 2) | nothing: a leaf inside drive (alone it is a 1 µs function: lesson 276 says never its own seam) |
| `_planned_reverse`, `_circle_gate`, `_plan_fill`, `_rollout`, `_look_stop`, `_ease_for` (`steer.drive`) | equal: N2b already proved the geometry (`_arc_hit`, `_outline_ok`) bit for bit; the rest is arithmetic over the k-turn state (`_kturn_left_m`, `_kturn_legs`, …) | the k-turn state lives in the native mover; `BrainLevers.kturn_check_ticks` read per call (brains' lever: a value in, not a callback) |
| `_next_waypoint` + `_along_route`, `_corner_beyond`, `_inflate_corners`, `_off_path` (`move.path`) | equal: segment search and carrot walk are float math over `_path` (float32 points); the chord is N2a/N2b's | **`Pathing.query` stays GDScript** (brains' `pathing.gd`): on a replan (event or cadence, a few % of ticks) the native call returns "replan" and the seam calls `Pathing.query` and hands the route back, then resumes. The `a1_*` counters and `a1_by_cause` (a Dictionary, measurement) are bumped from a returned code by the GDScript side, so every test that reads them sees the same numbers |
| `_approach_gate`, `_curved_gate`, `_arrive_gate` (`path.gate`) | equal: Clothoid is three pure functions; the closest point is N2a | `gate_refusals` (Dictionary counter) bumped from a returned code |
| `_around_fire` (`move.fire`) | equal by CALLBACK: its cost is `Match.threat_along` (match.gd, not native's); round 23 dropped porting it (~2 %) | runs on a fire-check tick only (every 2nd): the native drive calls back the GDScript `_around_fire` on those ticks, or the seam runs it before the native call and passes the waypoint in |
| `_avoid` (`move.avoid`) | equal: N1's solve is already native; the rest is arithmetic + one N2a closest point | `BrainLevers.orca_neighbours` read per call |
| `_guard_steer` (`move.guard`) | equal: two chords (N2b) and a corner walk | nothing |
| `_keep_station`, `Pid.step_with_rate` (`steer.station`) | equal: the PID is arithmetic in doubles; `ControlGains.for_loop` read once per faction change | the PID's integrator state in the native mover |
| `_track_progress`, `_update_phase`, `_blocker`, `_nose_stop`, `_note_wedge` (`move.steer`) | equal: arithmetic over the record (`_blocker` walks every hull: the record's rows in scene order, the GDScript's order) | `phase`, `blocked_by` are Strings others read: synced back (below) |
| `_negotiate`, `ask`, `_begin_yield`, `right_of_way` (`move.steer`) | equal IF the native movers are called in the same tank order as today (controllers run in scene order; the seam is in each controller's own tick, so it is) — one mover's `ask()` mutates another's state mid-tick, exactly as the GDScript does | the other mover's state is in the same native table (mover rows), so the mutation is native→native |
| `unstick`, `_pressing_escape`, `_hull_within`, `_ask_behind` | equal: arithmetic + neighbours (the record's set) + `WallContact.swing_of` (pure) | nothing new |
| `note_decision` | equal by construction: stays GDScript (it builds `contact.decided`, a Dictionary WallContact reads) from the synced fields | — |
| `gunnery`: `_nearest_shootable`/`_shootable` (`weapon.scan`), aim/lead (`weapon.aim`) | equal: the scan is a loop over `AiTickCache.enemy_columns` (the record's rows of the other team, scene order) with Perception's ray, which godot-cpp casts through the same `PhysicsDirectSpaceState3D::intersect_ray` | the weapon order (a Dictionary) read into fields when it changes, not every tick |

**The mover state, and what must come back each tick.** With native ON the native mover rows own the drive's state;
the GDScript `Movement` keeps its fields as the reference path (`--brains-off=native`). Fields read OUTSIDE
movement.gd (counted at `bfc00f53`: `phase` 7, `blocked_by` 5, `is_under_way` 5, `yield_to` 3, `stalled_ticks` 2,
`_path`/`_path_index` 3, `_remaining`, `pace_now`, `_deflected`, `_repair_to`/`_repair_for`, `in_kturn`/`_kturn_*`
(tests), `straight_and_clear`, `corridor`, `reading()`, `legibility()`) are written back after each native call: ~20
values, one packed return (~2–4 µs) against the ~250 µs of GDScript the call replaces (`move` ≈ 16.9 ms for 68 calls a
tick at 50 v 50, round 23's sizing). The test that proves N3c compares the command AND every synced field against
the live GDScript on the same poses (N2b's pattern), so a field a later edit adds and the port forgets fails there.

**What stays engine-bound whatever N3 does:** `nav.path` (replans; few a tick), the physics rays in `weapon.scan`
(godot-cpp calls the same server), `Match.threat_along` (match.gd). They are the floor under N3's gain.

### The shares (the map's numbers)

`make native-sizing NATIVE_SIZE_RUNS=2` at `bfc00f53` (every round-23 port ON, `native_move` OFF), builder0 light lane,
`taskset -c 0-3`, under this worktree's own check (load 5–11), 50 v 50 Sumps with leaders, 120 s, n = 2; logs
`streams/references/round24/native/sizing-bfc00f53/`. Band uninflated: tick 39.9 ms, controllers **30.1 ms**, elements
6.0 (round 23's `3c61ecbe`, before N2a: 51.4 / 39.8 / 7.6).

| part (instrumented; read shares and µs a call) | µs a tick | calls a tick | µs a call | share of the brains' work |
|---|---|---|---|---|
| **execute** | 15 668 | | | **50.6 %** (engine: `nav.path` 527 = 3.4 % of execute; `nav.closest` is N2a's, not counted) |
| `move` (all of `_apply_move` + `unstick`) | 9 351 | 67.3 | **138.9** | 30.2 % |
| of it `move.path` / `move.avoid` / `nav.chord` / `steer.drive` / `move.guard` / `steer.station` | 1 928 / 1 890 / 1 100 / 936 / 742 / 552 | 46.9 | 41 / 40 / 19 / 20 / 16 / 12 | 6.2 / 6.1 / 3.6 / 3.0 / 2.4 / 1.8 % |
| `weapon` (`gunnery.apply`) | 4 817 | 67.3 | **71.5** | 15.6 % (`weapon.scan` 1 970 = 6.4 %, `weapon.lanes` 680) |
| `t.poll` (think's per-tick prologue) | 2 431 | 67.3 | 36.1 | 7.9 % |
| `c.wall_contact` | 716 | 100 | 7.2 | 2.3 % |
| **think** | 15 278 | 14.9 | | **49.4 %** (`situation` 6 230 = 20.1 %, `decide` 2 370 = 7.7 %, `act` 1 295) |

**What it says for N3.** N2a moved the engine out of execute (27.5 % → 3.4 %), so execute is now almost all GDScript:
**N3c's ceiling is ~49 % of the brains' work** (execute minus its engine share), reached only if the whole `move` +
`weapon` step goes native. No single leaf is above 6.5 % (`weapon.scan`, `move.path`, `move.avoid`): the N3b leaves
each price in low single digits (N2b's lesson), and the gain is in N3c joining them into one call per tank, where the
~139 + 72 µs of GDScript per tank per tick is replaced by C++ plus ~5 µs of marshalling (the record's fill, the
synced fields). think is the other half: N3d (`situation`, 20 %) is the next biggest single line.

**CP1 (`b6bd539a`) read against the map:** brains' bridge fix touched `tank_brain.gd` only in `_combat_move` (a
combat hop is clipped short of water through `SlotGround.dry_leg_end`, or becomes a `face` halt) — THINK's side: it
shapes the `direct` order the execute step receives, and the execute step drives that order unchanged. No row of the
execute map moves; the clip is N3d's (think) when `_combat_move` is ported, and stays a GDScript call into
`SlotGround` (brains' `game/tactics/`) there. `movement.gd`, `gunnery.gd` and the rest of the freeze set are
untouched by CP1.

**`t.poll` is not a port target (decided at N3a).** It is think's every-tick prologue in `tank_brain.gd`
(`_poll_order` → `OrderFeed.current`/`key`, `_poll_element` → `ElementFeed.context`/`changed`, `OrderFeed.station`):
Dictionary reads and builds across brains' feeds, 36 µs a call. A native call would have to receive those
Dictionaries (the marshalling IS the work), so it cannot pay (lesson 276). Its lever is brains': read the element
context only on its signal (`_element_dirty`) rather than on every think tick, the way `_poll_order` already gates.
Recorded as a request, not built.

### N3c's design (decided before coding; the rule written before the number, lesson 278)

**The GDScript `Movement` stays the owner of the mover's state; the native drive works on it.** Every other path that
touches a mover (`reset`, `new_order`, `idle`, another mover's `ask()`, `right_of_way`, `unstick`, `note_decision`,
the tests, `legibility()`, the element feeds) keeps working unchanged, and a branch the C++ has not ported yet is
a CALLBACK into the live GDScript method with the state already where that method reads it. So N3c can land
piecewise and is always equal: what is native is proven equal, what is not is the GDScript itself.

Two ways to move the state, chosen by `make native-bench`'s new rows (builder0, pinned):
(a) the C++ reads and writes the mover's members as it goes (`Object::get/set` by cached `StringName`); (b) GDScript
packs the ~60 members drive touches into a packed array before the call and unpacks after (callbacks pack again).
**Measured (`c8da555e`, builder0 pinned): a member read from C++ 0.030 µs, read + write 0.054 µs; GDScript's own
`get(name)` 0.106, a packed write 0.025.** So (a), by the rule below. **Rule:** (a) if a member access from C++ costs ≤ 0.15 µs (drive touches ~100 member reads/writes a tick: ≤ 15 µs
against the ~139 µs of GDScript the call replaces); else (b) if packing + unpacking 60 members costs less than (a);
else N3c is priced per piece first (a seam that cannot keep 2/3 of its GDScript's cost is not built).

**Callbacks, not ports, for the rare branches** (each a few % of ticks or less): `Pathing.query` on a re-plan,
`_around_fire` on a fire-check tick (its cost is `Match.threat_along`), `_negotiate`/`ask` (only when stalled or held
back), `_repair`, the k-turn PLANNER when it plans (the check itself is native), every diagnosis/log function
(`*_diagnose`, `_note_look`, `_note_circle`: measurement, behind their flags; with a log flag on, the whole drive
runs GDScript).

## Android (round 24, stretch b): the cross-compile works; the device proof is what is left

`make native-android` (builder0, `36d7cb47`+): NDK r27c (sha256 pinned in `mk/native.mk`, fetched once into `.tools/`,
~660 MB), godot-cpp 10.0.0-stable for arm64-v8a with the proof's flags (143 s cold on builder0's E-cores,
`taskset -c 4-11`, -j8), then `native/src` → `native/bin-android/libtank_native.android.arm64.so` (12 MB, ELF 64-bit
ARM aarch64; android-24; the C++ runtime static, `ANDROID_STL=c++_static`). The desktop library and its
`.gdextension` are untouched.

**The trig hazard there:** the library imports bionic's libm (`sin`, `cos`, `pow`, `log` for the doubles the GDScript's
scalar math uses; `sinf`, `atan2f`, `acosf`, `asinf`, `atanf` for godot-cpp's float32 vector math). The Android engine
binary calls the same bionic functions for the same math, so native = GDScript ON THE DEVICE by the desktop's argument;
a device's hashes will differ from builder0's (glibc) and the laptop's, as those two differ from each other.

**What is left:** (1) the `.gdextension`'s `android.debug.arm64` / `android.release.arm64` entries (the file is
generated by `make native`; an Android entry should be added only when an Android export ships it); (2) the export
preset including `native/bin-android/*.so`; (3) the proof ON a device: `make test FILTER=native` and `native-proof`
run there (or in an arm64 emulator), each equal to itself. No device was available this round.
