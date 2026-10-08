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

Each is a sub-switch under `native` (`native_dodge`, `native_avoid`, `native_cover`) so `ai-ab-match AB_SWITCH=<name>`
prices one step alone. Every price so far is single digits of the controller band (the brief's expectation); the
ceiling of per-piece ports is the marshalling and the fact that the big lines are Dictionary-shaped state machines.

## The plan from here (written before a line of it is coded; the orchestrator's rule)

**What the band is made of** (`make native-sizing`: 50 v 50 with leaders, builder0 pinned, n = 3; the numbers in
`streams/native.md` Status and, at the close, here). Read it as three buckets: the EXECUTE step (every tick: move,
avoid, weapon, unstick), THINK (every 3–9 ticks: situation, decide, act), and inside each the ENGINE calls that stay
engine calls in any port (`NavigationServer3D.map_get_closest_point`, path queries, physics rays).

**N2a — the navmesh's closest point, natively indexed (the biggest single line; equal-answer by construction).**
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

**N2b — movement's geometry** (after CP1 is on main): `_chord_compute` (`nav.chord`, ~130 µs a call, half of it
closest-point calls it would make natively through N2a's index), `_arc_hit` / `_outline_ok` (the k-turn probes),
`_around_fire`. Each a seam replacing tens of µs; equal hash the proof.

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
