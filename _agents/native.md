# Native code: the vehicle brain's hot loop in C++ (round 23, stream native)

> Added 2026-10-08. The lead (2026-10-07): the army he builds is too small, *"double it"*; 25 a side already goes into
> slow motion on his laptop once everyone is in contact, and the cost is the per-vehicle tick (round 22's verdict:
> ~0.6–0.8 ms a vehicle, four fifths the brain, a flat profile, equal-answer cuts ≤ 2 %). He asked whether native meant
> Rust; the recommendation taken: **C++ through godot-cpp** (`game_design.md` *Round 23 direction: the launch*).
> This file: how it is built, the flags and why, the hazards, how the proof is run. The stream's brief and numbers:
> `streams/archive/round24/native.md` (round 24) and `streams/archive/round23/native.md` (round 23).

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
# TRAP (round 24, brains): plain `make test` / `make remote T=test` does NOT rebuild the library; on a folder whose
# .so predates the C++ (builder0's main lane held one from 10-08) the native tests error. Run `make native` first.
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

7. **A C++ static holds plain data only: no godot `Ref`, no godot builtin** (round 31, the planner's two segfaults on
   builder0). A static `RID` / `String` / `Dictionary` is constructed when the library is LOADED, before the extension's
   init sets the bindings its constructor calls: Godot dies inside `--import` (signal 11, a libc-only backtrace) before any
   test (d373af4e). A static `Ref<T>` is released after the ObjectDB is gone: the process dies at EXIT, after a green run
   (ad1d1f3d). Hold ids (`RID::get_id()`), numbers and std containers in statics; hold godot objects per instance (or in
   the uninitialize hook's care, as `exec_states` is). `make native-live-guard` (in `check`) starts and quits Godot through
   the library once and fails on a crash line or a non-zero exit.

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
- **How a laptop session is run (standing practice from 2026-10-09, after `4ba8fd0b`'s void session):** never
  straight after a build or any heavy job on the laptop (`native-tick-profile` sleeps NATIVE_TP_COOLDOWN = 180 s
  first), the arms ALTERNATED arena by arena and seed by seed with the order reversed every pair (ABBA, built into the
  target), and the ruling read from the PAIRED column only (`tests/native/tick_profile_paired.py BUILD BASE ARM`):
  the base drifts 0.75–0.81 game speed between sessions. A session where a segment the port cannot touch (priority 0:
  tanks, match) moves with the arm is void: file it as such and rerun. The first native_el session did exactly that
  (the arm run first, seconds after a parallel native build: its first run +45 % in every segment).
- **Round 25 note (the orchestrator, not changed after reading a result):** the laptop workload should include a
  water map (his last playtest was the Locks); `native_el` is re-priced then (its water rules are free on foundry and
  parade, which carry no terrain).
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

## Round 24, phase 2 (N4, bar C24.7: 25 a side, game speed >= 0.97 in the opening clash on his laptop)

**Where the in-contact tick goes** is now one command: `make native-tp-headless` (builder0 has no display: headless
Sumps, NATIVE_TPH_SIZE a side with leaders, the 8-20 s window, every SimProfile section sorted by
`tests/native/tick_profile_parts.py`). It chooses ports; the laptop's windowed table (`native-tick-profile`, paired by
`tests/native/tick_profile_paired.py`) rules them. Absolute ms move between builder0 runs (one run read every section
~45 % lower than another): compare SHARES. Measurement-only sub-laps added: `act.*` (prelude, by option,
combat_move, set_orders), `m.native_drive`, `t.order_progress`. Laps in files we do not own (game/tactics) are kept on
a LOCAL throwaway branch and never merged.

| step | seam (switch) | what | proof | ruling |
|---|---|---|---|---|
| `Movement._around_fire` | inside the native drive (`native_fire`) | the beaten-zone check with ThreatField's `peak_along`/`mean_along` read in C++ (read-only: no grant needed); SuppressionFeed's indirect answer kept | `test_native_fire`: 4137 asked (sidesteps, kept legs, no way round, indirect), 0 mismatches | alone −1.16 % (se 0.82): under the bar |
| **the N4 group** | `native_situation` + `native_tq` + `native_fire` together (`--brains-off=native_n4`) | pre-registered as ONE bundle by the orchestrator | the three proofs; hashes equal on/in-run A/B (builder0 `c8ca14dc`: his Sumps `f07b7b3e16d6b37f`, 25 a side `1d9babf1c4db6f81`) | **ON**: laptop windowed `58056d54`, n = 6 paired, tick scripts −4.11 % (se 0.47); game speed in the window 0.835 v 0.810 |
| SlotGround's grounding (grant C24.8) | top of `on_anchor_side`, `pulled_dry`, `standable_for` (`native_el`) | the water rules (wet, over_water, leg_wet, dry_leg_end) over the arena's terrain rectangles; `standable_for`'s pushes, fit test and rings over NavNative, with a C++ memo per map iteration (a pure function: invisible) | `test_native_el`: 7 tests, 0 mismatches (water rules on every water arena + a dry one; Locks and Sumps fights; standable_for on four built arenas, every hull envelope); element digest on = off over sumps parade yard terminus locks crossing (`078ad429…`, 96 runs) | **OFF**: laptop windowed `4ba8fd0b`, arms alternated seed by seed (ABBA), n = 6 paired: tick scripts −0.37 % (se 0.67); elements −0.15 ms (se 0.05) of 5.3. His laptop workload (foundry, parade) has NO water, so the water rules cost nothing there; headless on the Sumps (pits): elements 4.21 → 3.27 ms. Worth re-pricing on a water map if one becomes his workload |

**`SlotGround.standable_from` stays GDScript on purpose.** Its side memo is keyed by a 5 m CELL of the origin, so an
answer depends on which origin in that cell asked first: porting it means mirroring that memo entry for entry. Its
`standable_for` calls go native; NativeEl keeps `_ground_map` / `_ground_iteration` as the GDScript does, because the
side memo clears on them.

**Not taken in round 24: `ElementPlan.build`** (for round 25). 1.04 ms of the in-contact tick (builder0 headless, 25 a
side): `_plan_movement` 0.47, `_plan_drill` 0.35, `Drills.select` 0.06, `TacticsFormation.pitch` 0.04, UnansweredFire
0.03, `table.select` 0.03. The 0.8 ms is spread over ~40 functions of a 1713-line file (formations, `_group`,
`_advance`, bounding, the drills) and its output is Dictionaries the GDScript reads; a bit-exact port is a
multi-day item for at most ~1 ms. Take it only if the think-rate change (brains' L1) leaves the bar short.

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

## Round 25: the two workloads, and what they ruled

**The two workloads** (`make native-tick-profile NATIVE_TP_WORKLOAD=bar|water`): `bar` is C24.7's (foundry + parade,
window 8-20 s), the bar's definition, unchanged without him. `water` is his last two playtests' kind of map: the Locks
and the Crossing, window **12-24 s** (`NATIVE_TP_WATER_WINDOW`), because on the Crossing the armies first hit each other
at 12-14 s across the river (on the Locks at 8-10 s, like foundry): `tests/native/fight_onset.py` over builder0
recordings, `references/round25/native/water-onset-fccc520c/`. A session reads ONE workload: the target moves the last
session's `build/tp-*.log` to `build/tp-prev/` first. `tick_profile_paired.py` also prints elements and priority 0
(tank + match) paired in ms (the void rule), hulls alive at the window's ends, and a line per arena;
`tick_profile_budget.py` prints the gap to 0.97 by component (below).

**Windowed fights diverge between arms** (hulls alive at the window's end differ by up to 2 per pair: a skirmish is not
seeded like a headless match). A port that changes nothing in the sim can therefore read a few % on segments it cannot
touch; check the per-section split (every brain section moving together = the fight, not the port) and say so.

**The table** (`references/round25/perf/laptop/`, flightdeck, his preset, 25 a side, `49e2bdcd` = main `fccc520c` +
tooling, n = 6 paired ABBA, a watcher logging foreign Godot processes; one voided pair re-run):

| workload | arm | tick scripts | game speed | ruling |
|---|---|---|---|---|
| water | shipped | 38.2 ms | 0.763 (locks 0.80, crossing 0.72) | — |
| water | all native off | 56.7 | 0.537 | native is worth +48 % (se 3.2) of the tick on water |
| water | `native_el` | 37.5 | 0.772 | **OFF** by the letter: tick −1.64 % (se 1.65); elements −2.06 ms (se 0.33) of 8.75, controllers +1.20 (se 0.30) spread over every section (fight variance). builder0 headless ABBA, hashes equal: elements' share 20 → 16 % (Locks), 29 → 22.5 % (Crossing). **Then ON**: the orchestrator ordered a FRESH pre-registered n = 12 (not pooled, lesson 280): `b1884509`, seeds 4242 777 13 2024 8191 60601: tick **−4.85 % (se 0.47)**, speed 0.770 v 0.737; elements −2.16 ms (se 0.14); prio0 +0.008 (se 0.019); controllers per hull alive +1.21 % (se 0.76, not ruling). `references/round25/perf/laptop/tp-water-el12-b1884509/` |
| bar | shipped | 35.2 | 0.769 | — |
| bar | `native_scan` | 35.0 | 0.773 | **OFF**: −0.39 % (se 1.08) |

**The gap to 0.97** (`tick_profile_budget.py`; the clock runs at most 3 ticks a frame, so saturated game speed =
100 / (R + 3 S) with S a tick's sim and R the frame's work outside it; the model reads 0.768 where 0.769 was measured):
0.97 needs R + 3 S <= 103 ms. Bar: now 130, **9.0 ms a tick short (25.6 % of the scripts)**, or 27 ms a frame from R
alone (R 22.8). Water: 9.5 ms a tick (24.8 %), R 14.8. What equal-answer porting has left (ElementPlan.build ≤ ~1 ms,
act ~1, the k-turn planner < 0.5, scan ~0, el ~0 on the bar) is ~2-3 ms a tick: porting alone does not reach 0.97 at
25 a side on his laptop.

**20 a side, measured** (`48f2d843`, native_el ON, bar workload, s25 v s20 ABBA in one session, n = 6 paired,
`references/round25/perf/laptop/tp-bar-s20-48f2d843/`; arms may carry a size: `NATIVE_TP_ARMS="s25@25= s20@20="`):
game speed **0.896** v 0.792 (+0.105, se 0.015), scripts −16 %. Not 0.97. The saturated model only holds AT the cap: at
20 a side the clock averages 2.43 ticks a frame and the model reads 0.934, because slow frames still hit the cap and
lose time. Below the cap, trust the measured speed, not `tick_profile_budget.py`'s model line.

## N6 (C25.6): the army cap follows the render preset

`Units.max_squads()` = `LAPTOP_SQUADS` (4) when `RenderLevers.preset() == "laptop"`, else `MAX_SQUADS` (5, the
compile-time ceiling); `Units.max_units()` = that x 5. Read ONCE at skirmish setup (`SkirmishMode.squad_cap_for`:
`--squad-cap=N` pins it, else the machine's), logged as `ARMY_CAP` and, after both armies spawn, `ARMY_CAP_FIELDED`.
Under the ceiling both sides go through `SkirmishMode.capped`: a garage-shaped army (<= 5 squads of <= 5) keeps its
first squads; a bigger (faction) army loses vehicles from its largest squad first, then folds like the player's. The
buyers stop at the cap (`Army.cpu_army`, `GarageOpponent.build`: the same purchase order, so the role mix holds), the
garage's catalog offers the cap, a saved 5-squad army opens with its first four and a status-line note
(`ArmyDraft.CAP_NOTE`), and `SquadConsolidation.for_player`'s default is the cap. Credits are unchanged. No network
path loads armies: the cap is that of the machine that builds the match. Desktop and headless are unchanged (proof:
`make check`'s thirteen lines and determinism). Tests: `tests/test_native_army_cap.gd`.
**The trap:** a laptop measurement at 25 a side through `--skirmish` is trimmed to 20 unless it pins `--squad-cap=5`
(`_agents/verification.md`); read `ARMY_CAP_FIELDED` in every log. The laptop goes back to 25 when
`make native-tick-profile` at 25 (which pins it) reads >= 0.97; the orchestrator flips it.

## N7 (round 25 evening): what a port must look like to pay -- measured

**The measurement.** `native_weapon`, two slices built and proven equal (tag `n7-weapon-slices` at `148104c0`; reverted
from the branch so gunnery.gd carries no C25.2 burden for nothing): (1) the aim solution (Ballistics.lead_point,
Difficulty.aim_offset, distance, Ballistics.aim_error: 600 poses, 0 mismatches) and (2) Engagement.Lay.engage (gates 2
and 3, acquire_seconds, crossing_rate, the lay and the counters written back: 1200 poses, 0 mismatches); native-proof
with it on (+ leaders) on = off = ab = `b646df113768ddb8`. Each is ONE call per crew per tick with ~10-16 arguments
read off nodes and dictionaries, replacing ~3-6 us of GDScript. **Priced** (builder0, `ai-ab-match
AB_SWITCH=native_weapon`, leaders, x 3): controller band **−0.4 / +0.4 / −0.2 %**: nothing. The marshalling costs what
the GDScript did. (Sizing first, `references/round25/native/n7-weapon-split/`: the replaceable part of brain/weapon was
~1.4 of 3.97 ms headless; the scan's 1.86 is the engine's sight ray.)

**The rule since:** a port pays only when (a) it is BATCHED -- one call over all crews, reading the native record
(avoidance, the record) -- or (b) it removes a crossing INTO GDScript from native code (a callback inside the native
drive), or (c) the work replaced per call is large next to what is marshalled (`decide`: ~100 us a call, −4.3 % on the
laptop). A per-crew port of a few-microsecond function is ~0 however exact it is. Size before building: the work per
call (section ms / calls) against the arguments the seam must read.

**What is left, ranked by that test** (laptop bar ms where the laptop split has them, else builder0 headless; a
saving is an estimate until priced):

| # | candidate | shape | section | est. saving a tick | needs |
|---|---|---|---|---|---|
| 1 | the k-turn planner's check and plan (`Movement._planned_reverse`, the native drive's callback) | (b) removes a crossing | **measured: ~0.13 ms a tick of GDScript** (83 % of calls stop at the cheap check; `references/round25/native/n7-kturn-split/`) | **<= 0.1 ms: not built** | native-owned |
| 2 | tactics' polls batched over every crew (`t.poll`: element 1.13, order 0.95, squad 0.44, station 0.25) | (a) batched | 2.72 ms | 0.8-1.4 ms | a grant (game/tactics, brains'); churns every round |
| 3 | `situation` past the core (s.tactics, s.squad, s.cover_spots, s.incoming, s.cover_fire) | (c) large per call, or (a) | 2.45 ms | 0.5-0.9 ms | partly tactics' |
| 4 | `t.rate_progress` batched | (a) | 1.37 ms | 0.4-0.7 ms | a grant |
| 5 | `act`'s prelude batched (after brains' F4) | (a); measure the batched share first | 2.48 ms (prelude 0.5) | 0.3-0.8 ms | tank_brain.gd seam |
| 6 | `feed.normalize` batched | (a) | 0.65 ms | 0.2-0.3 ms | a grant |
| 7 | the re-plan query callback (Pathing.query inside the drive) | (b), but mostly the engine's navmesh | 16-18 us a drive | <= 0.2 ms | native-owned |
| -- | weapon (aim, engage, lanes) per crew | per-crew, small | -- | **~0 (measured)** | -- |

Even all of it (~2.3-4.2 ms) does not close the 9 ms gap at 25 a side; the laptop fields 20 (C25.6) until something does.

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

## P3 (round 26, perf): the whole-brain batched pass -- the design, written before any number (lesson 278)

**What it is.** Today each crew's `OrderController._physics_process` runs, in scene order, `think` (the poll prologue,
the think gate, and on its think tick `build_situation` -> `decide` -> `_act`) then `compute_command` (reflexes, the
move -- `Movement.drive`, native since round 24 with callbacks --, `unstick`, the weapon). Each of those is GDScript
calling, per crew, into C++ for its native parts. The batched pass inverts it: **one C++ call per physics tick, made by
the first controller to run, walks every crew of both teams over the native record and produces every crew's
`TankCommand`**; each controller then only copies its row into `tank.command` (as `NativeRecord.command_into` already
can).

**What moves into the pass (per crew, every tick or on its think tick):**

| stage | today | in the pass |
|---|---|---|
| the gate | `think`'s prologue: home, squad serial, `_poll_order`, `_poll_element`, station, the incoming wake-up, the re-rate (`_think_rate`), `_update_order_progress`, `_due_to_think` | over the record; order/element/squad state PUSHED into it on change (Orders, Elements, Match emit; the pass never reads their Dictionaries) |
| situation | core native (`native_situation`), the rest GDScript (squad context, `_tactics`, cover spots, cover fire, incoming) | all of it as C++ structs (no Dictionaries); TacticalQuery and CoverMap already native |
| decide | native (`decide_native.cpp`), but its inputs and candidates are Dictionaries | the same scoring over structs |
| act | GDScript, ~130 us a call, many callbacks (movement, tactics' queries, order helpers) | C++, producing the move/weapon orders as structs |
| execute | drive native per crew (callbacks into `_planned_reverse`, `_negotiate`, `_blocker`, `_keep_station`, ...), weapon/unstick/reflexes GDScript | drive + its callbacks + weapon (aim, engage, lanes) + unstick + reflexes in C++ |

**What stays GDScript:** tactics/elements (`ElementPlan`, `ElementCommander`, the element feed's producers), the CPU
commander, Orders and the player's controls, the match's rules (`Match`, shells, damage), every signal and every
consumer outside the brain (HUD, the explain overlay, the census, the AgentBridge). They exchange with the pass
through the record: they PUSH (an order given, an element's call/slot/station, a squad's serial) and they READ (each
crew's choice, intent label, watch point, move/weapon order) after it has run.

**The record's shape:** today's `TankRecords` (pose, command, hull, route) plus per crew: the brain's own state
(choice, since, cooldowns, `_left`, the think schedule and debt, `_kept_thinks`, the order and its key, home, post,
element context, stalled/lane/fire counters, the cover caches), the mover's state (the drive's Dictionaries become a
struct), the gunnery's lay; per team the contacts table (exists) and the prototypes. Shared memos (`AiTickCache`'s
`faced_by`, `CoverMap`'s coarse memo) move with it.

**Two ways a future behaviour change lands, and the trade:**

1. **Both languages (today's C26.2 rule, extended to the whole brain).** GDScript stays the reference and the
   live-function proofs hold the C++ to it bit for bit. Every AI change (traffic's convention, manoeuvre's turn,
   brains' every fix) is written twice and proven equal: today a port of one function costs perf about a day per
   behaviour change; over the whole brain every brains/traffic/manoeuvre commit carries it. Iteration speed of the AI:
   roughly halved for as long as the AI is reshaped every round.
2. **The C++ as the ONLY implementation for the ported functions** (GDScript retired there). One implementation, no
   proof burden, the speed kept. But AI work becomes C++ work: a rebuild per change (seconds), no hot reload, no web
   build of the AI (the web build has no native library: it would need the GDScript kept anyway, C18.7), and the
   agents' behaviour iteration -- the thing this project changes every round -- moves to the slower language. And his
   son's checkout needs a C++ toolchain to play at all.

**Decision rule for the estimate (fixed before the prototype is measured):** the pass's saving =
(the GDScript time it replaces, measured section by section in the window) x (1 - r), where r is the measured ratio
C++ time / GDScript time for the SAME work done batched over the record with no Dictionary built and no per-crew call
(the prototype's number); engine calls inside those sections (sight rays, navmesh queries, physics) are subtracted
first and count as unchanged. The laptop number is the builder0 share applied to the laptop's measured split (P1).
The days: from the line counts of what is ported (the drive took ~2 days for ~1300 lines with its proof), scaled.

### P3: the prototype (measured; the rule above was written first)

**What was built** (throwaway `local/perf-p3-proto` tip `b32c6a45`, never merged; the patch is
`streams/references/round26/perf/p3-prototype/p3-prototype-b32c6a45.patch`): the hottest slice of think that already reads
only record data, `TankBrain._think_rate`'s contact loop (every crew, every intel refresh and every think: is any
known enemy within LOD_RADIUS, is one in reach), as ONE C++ call a tick over the record (`TankNative.rate_classes`:
every row x its team's contacts table, the answer a {name: class} Dictionary each crew reads). `--p3-rate=2` asks both
and counts; `=1` uses the C++; `=3` also gathers contacts only when intel refreshes (it changes only then).

**Equal answer:** 0 mismatches in 23 000 asks (`=2`, three seeds); the `=0` and `=1` arms end with the same hulls
alive per seed.

**Price** (builder0 light lane, load ~16-28 from five streams, b57838ed + prototype, foundry 25 a side + leaders,
8-20 s, seeds 92721 31337 5988, n = 3 per arm; ms a tick):

| what | ms a tick |
|---|---|
| the GDScript loop it replaces (`=0`) | **0.66** (0.61-0.71) |
| the C++ doing the same work for every crew | **0.03-0.04** (r = 0.05: twenty times faster) |
| the call + its Dictionary + the per-crew lookups | 0.05 + 0.05 |
| **gathering the record** (`NativeRecord.fill`: every hull's members read by the C++) | **0.40-0.44** |
| gathering the contacts tables, every tick / only on intel refresh (`=3`) | 0.19-0.21 / **0.10** |
| total batched (`=1`) | 0.83 (0.71 with the split laps' run) |

**The finding that centres the estimate:** the work itself is ~5 % of its GDScript, but **one shared gather costs
~0.5 ms a tick** (record 0.4 + contacts 0.1 on refresh), so one slice alone does not pay (0.66 -> 0.6-0.7).
A batched pass pays only when MANY sections read ONE gather a tick; then the 0.5 ms is paid once and every section
runs at ~r of its GDScript. That is the whole-brain pass's case, and it is exactly what per-section porting (N7) never
had.

### P3: the estimate (the rule above, applied; confidence medium-low; CORRECTED 01:10 on the orchestrator's check)

**What the pass would replace** (P1's builder0 split, `b57838ed`, foundry/parade 25 a side, shares of the tick's
scripts): the controllers are 74-75 %; ~7 % of it is engine work that stays (the scan's sight ray ~4.5, rays and navmesh
queries ~2.7), which leaves ~67 %. **Of that, ~18 % is ALREADY C++** (the native drive's own part ~7 of its 10, the
drive's GDScript callbacks being ~30 % of a drive by `--native-drive-profile`; decide 5.3; situation's core ~5; avoid,
cover, nav, dodge inside other sections ~1), so **~49 % is GDScript the pass would rewrite**. The already-native 18 %
saves only its marshalling (Dictionaries built for GDScript consumers, member reads through Variants): **m = 0.3-0.5**
of it. Elements (15-16 %), tank (5-6), match (3.5-4) stay.

**r** (C++ time / GDScript time for the same work over structs): the prototype's tight loop measured 0.05; logic-heavy
sections (decide-like scoring, act's arms, the state machines) will not get that far: **central 0.15, range 0.08-0.3**.
**Fixed costs a tick:** the record and contacts gather (measured 0.5 ms = 1.1 % of the loaded tick) + the state the
GDScript PUSHES into the record (orders, element calls, squad serials: not measured, sized at 1-2x the gather) +
handing commands, intents and choices back: **2-4 %**.

**Saving = 0.49 x (1 - r) + 0.18 x m - fixed = 46 % of the tick's scripts (36 % at r 0.3, m 0.3, fixed 4 %; 52 % at
r 0.08, m 0.5, fixed 2 %).**

| his laptop (his preset, the opening clash) | today (measured) | the whole pass (est., central / low) | the execute half alone (est., central / low) |
|---|---|---|---|
| 20 a side (379e0567, n = 6: scripts 28.6, wall 37.8 ms a game tick, 0.97 needs 34.4) | **0.881** | wall 24.6 / 27.5 ms -> **full speed** (1.36 / 1.21 uncapped) | 33.2 / 34.2 -> **~1.00 / 0.975: just full speed** |
| 25 a side (49e2bdcd, n = 6: scripts 35.2, 0.769, wall 43.3) | **0.769** | 27.1 / 30.6 -> **full speed** (1.23 / 1.09) | **0.88 / 0.86** |

The execute half (drive callbacks, weapon, unstick, wall contact: ~17 % GDScript + the drive's native 7 % after the
engine work) saves ~16 % (12.5-16) on its own; the think half the rest.

**The work:** ~9 000 lines of GDScript (tank_brain.gd 3 480, movement.gd's GDScript callbacks ~2 000, combat_motion
1 100, order_controller 580, gunnery 380, ai_tick_cache 390, think_quiet, incoming_fire, squad_tactics and the feeds'
readers ~1 100). At round 24's rate with live-function proofs (the drive's ~1 300 lines in ~2 days, decide's ~480 in
~1): **14-18 days of porting, 3-5 for the record and the push, 3-5 for exactness and the laptop's ruling: ~5 weeks
(4-7) of one stream**; the execute half ~2 weeks of it.

**What is frozen meanwhile:** while a function is being ported, its behaviour changes either wait or are written twice
(C26.2 today, for the whole brain). Execute half: manoeuvre (drive, k-turn), traffic (give-way, avoid), gunnery.
Think half: brains' tank_brain.gd (situation, decide, act) and the feeds' readers.

**Afterwards, the two ways (above):** both languages (every AI change ported and proven: ~1.5-2x the work of a change,
for as long as the AI keeps changing every round) or the C++ as the only brain (one implementation; the browser build
keeps a frozen GDScript brain, his son's checkout needs a C++ compiler to play at full speed).

## Stage 1 (decided by the lead 2026-10-11, "Driving+shooting half": NEXT round, after CP1-CP3; `game_design.md` *Round 26: his C++ decision*) — the launch design

**Scope: the execute step, per crew, every tick:** `OrderController.compute_command` and everything under it —
`_sense`, `_apply_reflexes`, `_apply_move` -> `Movement.drive` (already native) **with its GDScript callbacks ported**
(the re-plan block of `_next_waypoint` ~45 us a drive, `_planned_reverse` and the k-turn planner, `_negotiate` /
`_blocker` / the give-way, `_keep_station`, `_approach_gate`, `_repair`, `_inflate_corners`, `_chord_slack`, traffic's
`Traffic.shape` as settled in CP1b, manoeuvre's `_manoeuvre` gate from CP2/CP3), `Movement.unstick`, `Gunnery.apply`
(the scan loop around the engine's sight ray, `_aim_solution`, `Engagement.Lay.engage`, the fire lanes, `_cover`,
`_clear_to_fire`, suppress and indirect), and the wall-contact observer. **Not in it:** think (situation, decide, act,
the polls: stage 2), elements, the CPU commander, Match, the engine's ray and navmesh queries (called from C++ as now).

**Shape (equal answer kept, so it is NOT one call over all crews):** the controllers interleave `think_i` then
`execute_i` in scene order, and crew i's execute writes state crew j's think and execute read the same tick (the mover's
phase, `yield_to`, the avoidance table built at the first avoid). Batching every execute after every think would reorder
those reads (a DECLARED change). So: **ONE native call per crew per tick** (`TankNative.execute(row, ...)`, the seam at
the top of `compute_command`), each replacing ~200-300 us of GDScript (N7 rule (c): large per call; **round 27: that figure was never measured** -- the estimate below is built from shares, not from it; the measured per-crew number is in `streams/native.md` Status), all of them reading
**ONE record gathered once a tick** (P3's prototype: the gather is ~0.5 ms; it then also feeds avoidance, which today
gathers its own table). The per-crew state that the GDScript keeps in members today (Movement's ~140 fields, the
gunnery lay, reflex state) moves INTO the record as C++ structs, with GDScript accessors for the readers outside the
execute step (`Movement.state()`, `route_arms()` and the census counters, the HUD's and explain overlay's reads,
`straight_and_clear`, `in_kturn`, `is_under_way`).

**Seams (grants the round needs):** the top of `OrderController.compute_command` (brains' file); `Movement` and
`Gunnery` member storage behind accessors (movement.gd: brains', traffic's and manoeuvre's blocks; gunnery.gd: brains');
`Traffic` (traffic's, after CP1b settles); the native drive's callbacks become direct C++ calls.

**The freeze it needs (C26.2 for the whole execute step):** while stage 1 runs, a behaviour change to `movement.gd`'s
drive and its callbacks, `gunnery.gd`, `order_controller.gd`'s execute path, `steering.gd`, `avoidance.gd`,
`traffic.gd`, `wall_contact.gd`, `clothoid.gd` either waits or comes to perf as a diff to port (both languages, the
live-function proof). Think-side files (tank_brain.gd's situation/decide/act, tactics) are NOT frozen.

**Proof:** `test_native_drive` widened to the whole execute step (every crew executed both ways from one snapshot of
all movers and lays: command, every member, every static); `native-proof` (one hash on, off, A/B) with and without
leaders; the thirteen lines and determinism unmoved; `make check` and `make check NATIVE=off`.

**The shape re-priced (the orchestrator's check, 2026-10-11, lesson 284).** The P3 number came from a batched call;
stage 1 is per crew. The prototype slice was re-measured in stage 1's shape (`local/perf-p3-proto` tip `e66dd526`:
`TankNative.rate_class_one(name, reach, ...)`, one call per crew over the record gathered once a tick; builder0 light
lane, load high, foundry 25 a side + leaders, 8-20 s, seeds 92721 31337 5988, n = 3 per arm; equal answer 0/22 000;
`streams/references/round26/perf/p3-prototype/stage1-shape-m*`): the GDScript loop 0.61-0.84 ms a tick (~27 us a crew);
per crew 9.7 us a call (28 calls a tick: 0.27 ms), of which the C++ work 1.7 us (r = 0.06) and **the crossing ~8 us a
call** (four arguments: a name and three floats; nothing read off nodes or Dictionaries); the shared gather 0.65 ms
(record 0.55, contacts on intel refresh 0.10). So reading the record instead of marshalled arguments removes N7's
problem: a per-crew call costs ~8 us, which against ~200-300 us of execute work per crew (unmeasured, see above) is ~3-4 %.

**Stage 1's estimate, with that overhead:** 17 % GDScript x (1 - r) + 7 % already-native x m - gather 1.05 % - crossings
(46 a tick x 8 us = 0.6 %) - the think->execute hand-off (~0.5 %) = **15 % of the tick's scripts (11 % at r 0.3, m 0.3,
1 % more overhead)**. On his laptop, re-based on P1's session (`d84f7503`, n = 6: 20 a side 0.918, wall 36.4 ms a game
tick, scripts 27.8): **20 a side 1.00-1.03** (full speed); on round 25's base (`379e0567`: 0.881, scripts 28.6, wall
37.8): **0.96-0.995**. **25 a side 0.88-0.92** (`d84f7503`: 0.803, wall 41.5, scripts 33.5). The lead's "20 a side
~0.975-1.0" holds within the session-to-session spread of the base.

**A DECLARED batched execute instead (all thinks, then one call executing every crew):** it removes only the crossings,
~0.6 % of the tick (on the laptop ~0.17 ms a game tick at 20 a side, +0.005 game speed), and changes what crews read of
each other mid-tick: a crew's think would read a neighbour's mover state (its phase, give-way, `yield_to`) one tick
(33 ms) older, and the avoidance table would be built after every crew's new orders instead of interleaved. No player
would see 33 ms, but every pass line and the thirteen hashes would move for a +0.005 gain: **not worth a declared
change; stage 1 stays per crew, equal answer.**

**Price and bar:** stage 1 is estimated at 11-15 % of the tick's scripts (above); ruled on his laptop (`native-tick-profile`, bar workload, 20 and 25 a side pinned, ABBA, n >= 6, the
paired column), ON only outside 2 se. The measured number re-bases stage 2's estimate before he is asked again.

**Measured for E1 (round 26, `631e678f`, builder0 light lane, Sumps fight, 20 crews):** `MoverRecord`
(`native/src/mover_record.*`, OFF) gathers every fixed-type member of each crew's Movement, Gunnery and Engagement.Lay
(97 fields) natively, equal to the GDScript's read (58 200 values, 0 mismatches, `tests/native/test_native_mover_record.gd`)
— and costs **464 us a gather (~23 us a crew, ~0.24 us a field read through the engine)**. So the execute state cannot be
re-gathered every tick: stage 1 makes the C++ its OWNER (the GDScript reads it through accessors), and only the pose and
contacts are gathered per tick.

**Order of work (~2 weeks, one stream):** (1) the record v2 (mover + lay state as structs, accessors, the shared
gather replacing avoidance's own) with its field-by-field test, OFF; (2) the drive's callbacks one by one, each proven
(the cheapest first: `_chord_slack`, `_inflate_corners`, `_keep_station`, `_approach_gate`; then `_negotiate`/`_blocker`;
then `_planned_reverse` and the k-turn planner; then the re-plan block); (3) gunnery (scan, aim, engage, lanes, cover,
fire); (4) reflexes, unstick, wall contact; (5) the per-crew `execute` seam ON in an A/B; (6) the laptop's ruling.

## Round 26 P5: drawing is not the laptop's limit at 20 a side (measured; why stage 1 is the next step)

A LIGHTER look (laptop's five levers + 65 % scale, no glow, half the transient effects, the smallest crowd) was built
and priced on his laptop (`354052f5`, his preset, bar workload, 20 a side pinned, ABBA n = 6 per arm,
`streams/references/round26/perf/laptop/tp-p51-*` and `tp-p52-*`): LIGHTER v LIGHT game speed +0.013 (se 0.010); each
new lever removed from LIGHTER moves the frame's work outside the simulation by -0.4 to +1.0 ms (none outside 2 se) and
game speed by <= 0.008. At 20 a side a game tick is 36.4 ms of wall time, 27.8 of it the simulation's scripts (P1,
`d84f7503`): the CPU's simulation, not the picture, is what keeps the laptop under full speed. Not shipped; the
evidence that the C++ (stage 1) is where the laptop's speed is.

## Stage 1 as built (round 27, stream native; numbers and rulings in `streams/native.md` Status)

**The pieces (all in `native/src/`, all OFF by default until E6 rules):**

| piece | file | what |
|---|---|---|
| the table | `exec_fields.h` | every script member of Movement, Gunnery, Engagement.Lay (X-macro, 145 fields); `test_native_exec_state` fails when a script's members and the table disagree and prints the line to add |
| the owned state | `exec_state.{h,cpp}`, `exec_holder.h` | the typed struct, `pull` (members -> struct; `pull_gun`, `pull_mover_field` for parts), `push` (struct -> members: all, or the dirty fields; dirty = the bits changed); each Movement holds its `NativeExecState` in `native_state` (freed with it) |
| the view | `exec_view.h` | `ObjectView` (the live members through get/set) and `StructView` (the owned struct); every port is written once against `V` |
| the drive | `drive_native.cpp` | `Drive<V>`; E2's callback ports under `native_cb`; E4's `unstick` |
| the gun | `gun_native.cpp` | Gunnery.apply incl. ARC's `_apply_indirect`; Tank's reload/ammo reads |
| the execute | `execute_native.cpp` | compute_command's common path (living hull, no reflexes, not giving way; move_to, stop, a tracked hull's plain face) as ONE call per crew; anything else handed back before a write |

**The doors (the mirror's one rule):** the C++ owns the state during a crew's execute and pushes back the fields it
changed; any GDScript that WRITES the state outside the native execute marks `Movement.native_stale` with its bit
(`STALE_ALL`: reset, idle, ask, a hand-back, the seam's off branch; `STALE_ORDER`: new_order; `STALE_GUN`: OrderController's
gun forwarders; `STALE_STALL`: its stalled_ticks forwarder), and the next native execute pulls that part first. A new door
(a GDScript writer of these members outside the execute step) must mark its bit; `--native-exec-verify` (native-proof's
`exec_verify` arm) pulls afresh before every execute and counts any field that differs: that is how a missed door shows.
**Tests are doors too:** a test that sets a mover up by writing its members (a k-turn leg, a yield) must go through a
method that marks stale, or mark `native_stale |= Movement.STALE_ALL` itself. Stage 1's ON commit found one
(`test_nav_kturn_brake`: members written, then `_kturn_start_leg`, which now marks).

**Switches:** `native_exec` (the seam), `native_owned` (on the owned state; else the live members), `native_cb` (E2's
callback ports; OFF by its price, round 27 B), `native_gun` (the gun alone, outside the execute seam). Stage 1 ON = the
first three together (`--brains-on=native_exec,native_cb,native_owned`).

**The proofs:** `test_native_exec_state` (table, pull, scramble + push, changed-only push), `test_native_drive` (both
views; unstick's branches), `test_native_gun` (three arms, every order type), `test_native_execute` (compute_command
three ways, hand-backs write nothing); `make native-proof NATIVE_PROOF_ARMS="on off ab exec exec_owned exec_verify stage1
stage1_ab"` (one hash; `AB_FLAGS="--green-elements --rust-elements"` for leaders); `--native-exec-profile` for where an
execute's microseconds go.

**Two traps found building it:** a namespace-scope object holding a godot type (a `String` in a counters struct) is
constructed when the library loads, before godot-cpp can make one: Godot's `--import` crashed (signal 11, an empty
backtrace). And a registry of states keyed by id freed its Variants after the engine at exit ("corrupted size vs.
prev_size"): state must live as long as its owner, not the process.

## Round 26: what the C++ followed (C26.2)

| change | port | proof | cost |
|---|---|---|---|
| manoeuvre M1 (`613f665b`): `order = _manoeuvre(order)` at the top of `drive()` | `c892870c`: the GATE in `Drive::manoeuvre` (drive_native.cpp: the early-outs, goal, gap, `_behind_tick`, `_behind_goal`/`NEW_GOAL_JUMP`, the reversed copy); the DECISION (new goal, or a gap) calls `_manoeuvre` back; inert while movement.gd has no `BEHIND_GAP_TICKS` | `test_native_drive` + manoeuvre's tests and its six behind cases native-on, 15/0; `native-proof` `d0e122bac5b346dc` x3 (local merge, builder0) | callback 0.04-0.08 ms a tick (Sumps 25) |
| manoeuvre M3 (`f46fae96`): the creep line after `cmd.throttle`/`cmd.turn` in `drive()` | PORTED, then NOT MERGED: `9749c766` + `1024845a` (inline arithmetic, inert without `CREEP_LIFT_PACE`), kept on branch `local/perf-m3-port`, reverted on stream/perf (`197e684c`, `14fb9f63`). Manoeuvre time-boxed M3 out (bridge drill 9/18 with the hold branch; lift-only drove hulls into Terminus walls). **Round 27:** if the planned-turn version lands, re-apply the side branch to its final hunk (lift-only = drop the `else` branch) and re-prove | `test_native_drive` 2160 drives, 130 creep-lifted, 0 mismatches; `native-proof` `bf7a2029f5944398` x3 (local merge `822749f8`, builder0) | none (no callback) |
| traffic CP1b (`Traffic.shape` in `_avoid`) | HELD: its first draft cost ~3.6 ms a tick in GDScript; traffic redesigns (cost line <= 0.5 ms), then a C++ port reading the record, never a callback (C26.10) | -- | -- |

**C26.2 for M1:** an edit to `_manoeuvre`'s first block (the lines above the decision) needs the C++ to follow; an edit
inside the decision branch (`Manoeuvre.choose`, the plan, the kept goal) needs nothing.

## N5.M (round 33): `_manoeuvre`'s decision in C++ — the design, written before the code

**What.** Round 26 put `_manoeuvre`'s per-tick GATE in C++ (`Drive::manoeuvre`); the DECISION (a new goal, or the same
spot after a gap in the drive ticks) is still `cb(k._manoeuvre, order)`. N5.M ports the decision: the rest of
`Movement._manoeuvre` (reaimed, arrive, the facing test, `_kept_goal` / `_kept_from`, the counters) and what it calls,
`Manoeuvre.choose` / `behind` / `simulate` / `_others` / `_hull_hit` / `_note`, `Movement._kturn_frame`, `_outline_offs`
(new `NavNative::outline_offs`, `outline_off` per point: the same arithmetic) and `TankMotion.state_of` (built natively;
the unit's `state_for` stats memoized per unit like `settle_of`). Manoeuvre (owner) confirmed 2026-10-17 that CP-F does
not touch these; the orchestrator released the port (R33.4: parkedroom leaves `_manoeuvre` alone).

**Equal, line by line.** Every member write through the view (`_behind_tick`, `_behind_since`, `_behind_goal`,
`_behind_plan`, `_kept_goal`, `_kept_from`: exec rows already exist), Movement's statics `behind_asked` /
`behind_reverses` through `sadd`, Manoeuvre's `plans` / `refused` tables in place on the Manoeuvre script (`_note`). The
simulation reuses the proven pieces: `motion_step` (N6.1), `drive_toward` (backward for `reverse_toward`) and `wheels`
(gear ±1), `NavNative::outline_ok`, `pathing_ready()`, the memoized `hull_box` / settle radius / `bake_radius`.
**Declared, not equal:** `NativeBridge.took("motion")` / `took("nav")` (the bridge's measurement table) is not counted
by the native decision. It is never game state.

**Falls back to the callback (the decision whole, as today) when** `manoeuvre_ready` is false (a constant or the
Manoeuvre script missing: an older tree), or any switch the GDScript arm would read differently is off:
`native_nav` (the GDScript's outline then asks the engine, not N2a's index) or `kturn_cap` (another outline rule) is off,
or the new switch `BrainSwitches.native_manoeuvre` (default ON; `--brains-off=native_manoeuvre` puts the callback back
for an A/B). `native_motion` and `native_move` are OFF by default (crossing cost, not equality): the GDScript arm steps
and checks outlines in GDScript, and the C++ decision calls `motion_step` and `NavNative::outline_ok` directly, each
proven the same bits (N6.1, N2b), as the native tank drive does; `NativeMotion.configure()` is asked at
`NativeDrive.configure` so the motion constants are there.

**Proof.** The drive twins compare the whole drive from one snapshot; `MoverState.capture` gains Manoeuvre's `plans` /
`refused` (statics of another script) so the decision's counters are compared too. Floors: the k-turn fight (every hull
sent 8-16 m behind it) and the drive fight count decisions made natively (`drive_owned_counts`: `manoeuvre_native`,
`manoeuvre_called_back`), with both answers (`reverse`, `route`) and a refusal reached. Then manoeuvre's own behind
tests native-on in the plain check, `native-proof` (determinism and the thirteen maps unmoved: nothing changes by
construction) and `make check NATIVE=off`.

**Price.** Measured in `test_native_manoeuvre` (builder0 light lane under load ~18, lab `536f773c`, n 1 run of 900
at-rest decision ticks): a decision tick's whole drive 1762 usec native with the decision CALLED BACK (rounds 26-32),
719 usec with N5.M, 1728 usec all GDScript. About 1 ms saved per new goal (a spike, not a per-tick cost: decisions are
once per goal).

**Proof as built (lab `536f773c`, builder0 light):** `test_native_manoeuvre` (new; five hulls on yard_open sent astern
at rest and rolling, the decision twinned on its tick, live and owned): 920 decisions native, 0 called back, 0
mismatches; plans route 613 / reverse 307; refusals facing_nose 225, static 84, route_faster 66, friendly 6, enemy 2
(a parked Rust hull). `no_arrival` is reached from `1a1182bb`: a sweep of Manoeuvre.simulate found 4 War Rig and 6 Lancer
goals, of 1604 astern, that reverse clear but do not arrive inside SIM_HORIZON_S. The stage asks the War Rig's four:
940 decisions, 0 mismatches both views, `refused:no_arrival` 4 (floor 1). The live guard counts the decision as
`taken["manoeuvre"]` from the drive's own count (`607fca1a`); in the tick profile's 20-a-side foundry match it took 227,
none called back. Merged as main `199d1587` (R33.15). The drive twins: 165 / 179 decisions native, 0 called back, 0
mismatches (route only: the Sumps refuses its reverses). The k-turn fight compares none (an order lands before the fight's
own drive decides it), so it asks no floor.
