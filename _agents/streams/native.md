# Stream: native (the per-vehicle tick: a native toolchain, then the brain's hot loop ported where it pays)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 23 direction: the launch*
> (the language decision), `_agents/determinism.md` (ALL of it: the proof you must keep), `_agents/workstreams.md`
> *Round 23* (C23.1, C23.3), `_agents/remote_builds.md` (builder0: what it has, `taskset -c 0-3`, no sudo), round 22's
> brains report (`streams/archive/round22/brains.md` Status *B3* and `streams/references/round22/brains/b3/`: the tick
> table, the parts profile, the stride, the open_ground finding) and perf's (`streams/archive/round22/perf.md` P0–P2),
> and round 17's sizing (`streams/archive/round17/brains.md:350-363`). You own `native/**` (new: the C++ sources,
> SConstruct/CMake, the `.gdextension`), `game/ai/native/**` (new: the GDScript side of the seam), `mk/native.mk`
> (new), and the files you port: `game/ai/avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`,
> `brain_switches.gd` (additive), and in `game/ai/movement.gd` ONLY the pure-geometry seams (`_chord_compute`,
> `_arc_hit`, `_outline_ok`, the call into `Avoidance`; C23.1). `tests/test_native*.gd`, `tests/native/**` (new).
> `Makefile`, `mk/core.mk` (the `check` dependency on `native`), `project.godot`, `.gitignore`, `export_presets.cfg`:
> additive, listed in merge notes.

## The lead's direction (2026-10-07)

> *"the armies I can create with tanks are too small"* → *"yeah double it sounds good"* (round 22: ten squads, 50
> vehicles a side; built, capped at 25 until the tick is cut). On the language, asked whether native meant Rust: the
> orchestrator's recommendation stands unless he says otherwise: **C++ through godot-cpp** (the official binding; the
> engine's own types; the brain's hot loop is math over arrays). Standing: *"we should still have the option to keep
> scale at 1.0 on better gaming setups"*; the native game never bends for the browser (C18.7; the browser is low
> priority and keeps the GDScript path).

**For him:** big fights go into slow motion on his laptop; 25 a side already does once everyone is in contact; the
50-a-side army he asked for ships when a tick at 50 v 50 on the laptop fits a 30 Hz frame with room for the render.

## Where things stand (read at `68b97663`, main-checked; verify)

**The cost (builder0 unless said; the laptop ~2.75× slower):**

| workload (`deec4d9` = `32748a0c` + rows; n = 1 whole match, ±30 %) | leaders | tick ms | controllers | elements |
|---|---|---|---|---|
| his Sumps 24 v 17 (seed 5988) | none / both | 15.6 / 19.6 | 13.9 / 14.5 | – / 3.45 |
| 25 v 25 Sumps | none / both | 16.6 / 21.9 | 14.9 / 16.5 | – / 3.60 |
| 50 v 50 Sumps | none / both | 41.7 / **62.7** | 37.4 / **49.0** | – / 8.63 |

"controllers" = the SimProfile segment between priorities −15 and −9 (`game/match/sim_profile.gd:62-63`): every
`OrderController`/`TankBrain._physics_process` at −10, i.e. the brains' whole per-vehicle loop including their calls
into match.gd and the NavigationServer: ~0.49 ms a vehicle at 100 alive. Perf P1 (`f6e47603`, 3 seeds × 120 s): the
tick grows ~0.8 ms per vehicle a side; at 50 a side on the laptop the frame is ~2 s of tick per second of play
(game_speed 0.35–0.6, his Sumps match). Perf P2 (50 v 50 foundry, frozen, 100 alive): tick **105.7 ms** on builder0.
**Target (C23.3):** 50 v 50 with leaders on the laptop in contact ≤ 25 ms a tick (today ≈ 170), i.e. roughly −60 %
of the controller band; the bar that returns the cap to 50. Anything short of it still moves the cap up by the table.

**The profile is flat and its top line is already native.** `make ai-script-profile` (laptop, `deec4d9`, his Sumps):
`Pathing.closest_point` 14 % self (`game/ai/pathing.gd:105`: a memoised wrapper on
`NavigationServer3D.map_get_closest_point`, 104–286 calls a tick by site: chord 105, slot 75, kturn 66, avoid 21,
gate 17); `build_situation` 24 % total; `Movement.drive` 33 % total (`_chord_compute` 9, `_next_waypoint` 8, `_avoid`
7.8); `decide` 8.7. Parts (`b3-parts-50v50.txt`, instrumented, read shares not ms): execute ≈ think; `move` 61 %,
`situation` 40 % (14.7 thinks a tick), `weapon` 31 %, nav.closest 20 %, weapon.scan 18, move.avoid 16, nav.chord 15,
move.path 14, decide 10, avoid.solve 8. **Equal-answer cuts bought ≤ 2 %**, the stride 15–25 % (OFF, his call), and
open_ground was NOT equal (lesson 272: a sim hash is not the proof; the full suite is part of it).

**What the loop is made of** (`game/ai/`; one `TankBrain extends OrderController` node per tank, priority −10,
`order_controller.gd:190`; `think` at `tank_brain.gd:531-642` on a think tick (fight every 3 ticks, near 6, idle 9);
`compute_command` every tick `:281-307` → `movement.drive`, `unstick`, `gunnery.apply`):

| piece | lines | shape | portable? |
|---|---|---|---|
| `avoidance.gd` `refresh` :112 / `neighbours` :208 / `solve` :263 (ORCA) | 416 | pure 2D math over `PackedFloat32Array` columns and a grid; only `refresh` reads nodes | **yes, first** |
| `steering.gd` | 111 | pure Vector3 math, 7 trig sites | yes |
| `cover_map.gd` `clear_line*`, `blocked`, `segment_hits` | 419 | pure 2D boxes/segments, quantised Vector4i memo keys | yes |
| `movement.gd` `_chord_compute` :2584, `_arc_hit` :3113, `_outline_ok` :3170, k-turn | 4,007 total | geometry, but with nav queries inside | the geometry yes; the state machine (≈140 methods on `ctl.tank.*`) no |
| `incoming_fire.gd` `closest_approach` :162 | 167 | pure | yes, small |
| `combat_motion.gd` `choose*` :172/:193/:493 | 1,097 | pure, over a Dictionary request | needs typed structs; marshalling |
| `tank_brain.gd` `decide` :1067-1541 | 475 | static, pure, over nested Dictionaries; tie-breaks by Dictionary order | needs typed structs; later |
| `build_situation` :1774-1910 | 140 | reads nodes, `AiTickCache`, match intel, `CoverMap`, `TacticalQuery` | entangled: last, if ever |
| `gunnery.gd` | 372 | `Perception.has_line_of_sight` = physics `intersect_ray` | the ray is engine; the scan loop portable |

Round 17's estimate (`round17/brains.md:350-363`): ~1.1 ms of ~9 ms of brains a tick was pure-and-plain math then;
*"the big lines are Dictionary-shaped."* **So the honest expectation is that porting the pure pieces one by one buys
10–30 %, and reaching −60 % needs the loop's DATA reshaped** (typed per-tank structs or packed arrays the native side
owns across ticks, with GDScript calling once per tank or once per team per tick, not once per function). Price each
step; let the numbers choose the next; say early if the ceiling is the marshalling.

**Nothing native exists.** No `.gdextension`, no godot-cpp, no SConstruct/CMake, no `native/`. `.tools/` holds the
official `Godot_v4.7.2-stable_linux.x86_64` (single-precision `real_t`: `Vector3` is float32, GDScript `float` is
double) and the venv; templates `linux_{debug,release}.x86_64` and `web_nothreads_*` only (no `web_dlink_*`, so the
web build cannot load an extension: the GDScript path stays, C18.7). `export_presets.cfg`: Web, Linux Server, Linux
Desktop, Web Factions; no Android preset today. Toolchains: the laptop gcc/g++ 13, cmake, ccache; **builder0 gcc/g++
15.2, cmake, python3, no sudo, no scons** (SCons is a pip package: install it into the venv, `make bootstrap` learns
it). `make check` runs on builder0 by rsync (`tools/remote.sh`); the `.so` is a build artefact, never committed.

**The proof you must keep** (`_agents/determinism.md`): same build + machine + seed = same match; the thirteen
`glibc-2.43` lines in `tests/baselines/sim_state_hash.txt` (builder0's are canonical; the laptop, glibc 2.39, is
skipped); `Match.state_hash()` (`match.gd:1279-1288`: tick, per tank name/position/rotation/turret/health/alive/
suppression) and determinism `762a0576f944f5b7`. `make ai-ab-match` (`mk/ai.mk:131-142`; Law v Condemned, Sumps,
4600, 180 s, seed 92721; `AB_FLAGS="--green-elements --rust-elements"` for leaders; `--brains-ab-run=<switch>` flips a
`BrainSwitches` flag every 30 ticks and charges the controller band per arm, `BRAINS_AB` line) **fails unless the
two hashes are equal**: your port is a `BrainSwitches` flag (`brain_switches.gd:41` `NAMES`; `--brains-off=native`),
and ai-ab-match is its price AND half its proof; the other half is the full check (lesson 272) and `make
element-digest` / `make ai-parity` (`mk/ai.mk:93`, a digest over seeds 1–8 on yard and terminus). Bit-exactness
hazards, each a rule for your C++: (1) two float widths: reproduce each GDScript double↔float32 rounding point
(`real_t` where GDScript has Vector math, `double` where it has `float`); (2) `-ffp-contract=off`, no
`-march=native`, no `-ffast-math`, no reassociation (gcc fuses FMA by default in GNU mode); (3) trig through the same
glibc libm in double (`sin`, not `sinf`): sites tank_brain 5, movement 17, steering 7, clothoid 6, avoidance 4,
combat_motion 4; (4) iteration order and memo semantics identical (neighbours by distance then name, invariant 7;
Dictionary insertion order in `decide`'s tie-breaks); (5) `PackedFloat32Array` columns store float32: store float,
compute where GDScript computes. For divergence hunting: `--hash-every=N --hash-until=T --hash-detail-from=T0`
(determinism.md:66–70). **If a piece cannot be made bit-exact, it is a DECLARED change** (C22.2 carried: one commit,
alone, lines adopted and named, the paired series showing equal outcomes), second choice, said out loud.

## Backlog (in order)

**N0. The toolchain, priced by a no-op** (the foundation; nothing else starts until it is green on builder0 AND the
laptop). `native/`: godot-cpp pinned to the 4.7 branch matching 4.7.2 (vendored as a submodule or a pinned tarball
under `native/godot-cpp/`, your call, recorded; the `extension_api.json` dumped from OUR binary with
`--dump-extension-api` so the binding matches), one `TankNative` class (or a per-piece set) registered by
`native/tank_squad.gdextension` for `linux.x86_64` debug/release only (web: absent; the `.gdextension` lists no web
entry, the game runs without it). Flags per the hazards above; `-O2`. `mk/native.mk`: `make native` (builds with
SCons from the venv, or CMake; ccache; ~minutes), `make native-clean`; `make bootstrap` installs scons; `make check`
depends on `native` where a C++ compiler exists and runs the suite with the `.so` present; `NATIVE=off` runs it
without (the suite must pass BOTH ways: the web build is the second). `game/ai/native/native_bridge.gd`: one place
that says `Native.available` (ClassDB has the class) and routes; `BrainSwitches` gets `native` (default ON when
available). The no-op: one pure function (`IncomingFire.closest_approach`, or `Steering.drive_toward`) ported, the
GDScript call replaced by the native one behind the switch; `ai-ab-match` hashes equal, check green with and without
the `.so`, thirteen unmoved, determinism unmoved; the BRAINS_AB price of the call (expected ≈ 0: this is the call
overhead baseline you will subtract from every later number). Also prove builder0's `.so` and the laptop's agree on
the hash of one match (same glibc rule as today: they may NOT across glibc versions; the laptop is skipped in the
baseline today, so the proof is: laptop GDScript hash == laptop native hash; builder0 GDScript == builder0 native).
Write `_agents/native.md`: how to build, the flags and why, the hazards, how the proof is run; one paragraph in
`orientation.md`'s map. Tell the orchestrator when N0 is green (merge candidate; everyone's `make check` changes).

**N1. Avoidance (ORCA) native.** `Avoidance.refresh` stays GDScript (it reads nodes) but fills the native side's
columns once a tick (one call per team per tick, packed arrays by reference); `neighbours` + `solve` + `_program1/2/3`
in C++; the per-tank call returns the velocity. Equal hash in `ai-ab-match` (both with and without leaders) and the
check; price = the controller-band delta in BRAINS_AB at his Sumps, 25 v 25, 50 v 50 (3 runs each, `taskset -c 0-3`
on builder0, commit + machine + n in Status). Expected single digits of the band; the point is the seam pattern.

**N2. Movement's geometry.** `_chord_compute`, the k-turn arc/outline tests, `_around_fire` / `_avoid` geometry, the
`Pathing.closest_point` memo (the call overhead on 100–286 engine calls a tick; a native memo keyed per nav iteration
can batch the `map_get_closest_point` calls through godot-cpp's `NavigationServer3D` singleton without re-entering
GDScript). **Merge main first** (brains' CP1 lands in `movement.gd`'s `_keep_station` / `speed_factor` hunks; yours
are the pure-geometry functions; C23.1). Price as N1.

**N3. The data reshaped (where −60 % lives, if N1–N2 show the marshalling ceiling).** A native per-tank record the
C++ owns across ticks (position, heading, speed, hull, the last command, the neighbour set, the cover-map handle), a
per-team "contacts" table filled once a tick from `AiTickCache`, and `CombatMotion.choose*` + the execute step
(`_apply_move` → `movement.drive` → steering → command) as ONE native call per tank per tick returning a `TankCommand`
struct; `decide` and `build_situation` stay GDScript until the execute side is proven (think runs 3–9× less often
than execute). This is a redesign of `movement.gd`'s state machine into C++: do it as a port that keeps the GDScript
file as the reference implementation (the switch runs either), equal hash the proof at every step, each step its own
commit and price. Say at each step what the band reads at 50 v 50 on builder0 and where it is on the way to the
target; the orchestrator runs the laptop numbers.

**N4. The cap returns.** When the laptop table (the orchestrator's, `streams/references/round23/perf/laptop/`) shows
50 v 50 in contact at or under the bar: nothing of yours (army's A4 recipe flips `Units.MAX_SQUADS` to 10, the
orchestrator's at the close). You report the builder0 number per step; the laptop is the fact (lesson 271).

**Stretch.** The HUD's per-unit loops (round 19's held item 2, ~3 % of the frame; only once the toolchain exists,
only if perf's numbers in `legibility.md` still say so). `gunnery.gd`'s scan loop (the rays stay engine calls).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe), with the `.so` built there AND `NATIVE=off`. 23 targets ALL JUDGED; thirteen lines +
  determinism UNMOVED (pre-registered; an unplanned move is a finding: stop, attribute, message the orchestrator, C19.3).
- `make ai-ab-match` (with and without leaders) equal hashes + the BRAINS_AB price, 3 runs, `taskset -c 0-3`, commit,
  machine, n, spread. `make ai-parity`, `make element-digest` unchanged.
- The laptop's `.so` built and its hash equal to the laptop's GDScript hash on one match (the orchestrator can run
  the laptop command for you: ask, with the exact command).
- Every number: commit, machine, workload, sample size (C16.3). Never a ratio per behaviour as a cost: remove it and
  measure (lesson: attribute a cost only by removing it).

## Don't touch

`game/ai/tank_brain.gd`, `element*.gd`, `game/tactics/**`, `movement.gd`'s state machine, `_keep_station`,
`speed_factor` (brains) · `game/control/**`, `game/ui/**` (orders) · `game/match/**` except by request through the
orchestrator (equal-answer seams in match.gd's per-tick paths were brains' in round 22 under C22.7; if you need one,
ask) · `game/garage/**`, `game/units/**` · `tests/baselines/**` · `tools/remote.sh`, `tools/slot.sh` (a change is a
request: the check's rsync may need your `native/` build dir excluded; ask the orchestrator, who owns them).

## Waiting on the lead

- Nothing blocks you. He is asleep (2026-10-07 night); no gate tonight. The language is decided (C++); if he wakes
  and says Rust, the orchestrator tells you before N1.

## Status

_(the worker keeps this current; started 2026-10-07 23:38 PDT from `46764993`, the lead asleep)_

### Plan (in order)

1. **N0 the toolchain, priced by a no-op** (in progress): godot-cpp `10.0.0-stable` pinned by tag + sha256 under
   `.tools/` (per machine, shared by every worktree, never rsynced), built by CMake with the proof's flags; our
   extension `native/src` → `native/bin/libtank_native.linux.x86_64.so` + the generated `.gdextension`; `NativeBridge`,
   `BrainSwitches.native`, `IncomingFire.closest_approach` ported; `tests/test_native.gd`; `make check` both ways on
   builder0; `make native-proof` on both machines; `ai-ab-match AB_SWITCH=native` × 3 for the price; `_agents/native.md`.
2. **N1 Avoidance** (neighbours + solve native, refresh fills columns once a tick): written, tested after N0 closes.
2b. **N0b `would_be_hit` as ONE call** (combat_motion.gd, mine): turns the no-op's loss into a gain and is the
   batching rule made concrete; the `closest_approach` seam then becomes the inner step of that call.
3. **N2 Movement's geometry** (after CP1 is on main and merged here).
4. **N3 the data reshaped** (if N1–N2 show the marshalling ceiling).
5. Stretch: the HUD loops, gunnery's scan.

### Decisions (reversible; one line each)

- **CMake, not SCons.** cmake + ccache exist on both machines, scons does not (it would be a pip install into a venv
  builder0 does not have); godot-cpp 10 ships first-class CMake (`GODOTCPP_CUSTOM_API_FILE`, `GODOTCPP_TARGET`).
- **godot-cpp `10.0.0-stable` (2026-09-15), the current release.** godot-cpp is versioned on its own since 10.x and
  targets 4.3+ by `api_version` / a custom API file; its last engine-named tag is `godot-4.5-stable`. Its
  `gdextension_interface.json` is byte-identical to our binary's dump; the API is dumped from OUR 4.7.2 binary at
  build time (`--dump-extension-api`; it differs from the shipped `extension_api-4-7.json` only in its header).
- **Where it lives:** the source tarball and that machine's build of the binding under `.tools/godot-cpp-10.0.0-stable/`
  (download once, build once per machine and flag set; a `flock` for two worktrees at once), like the Godot binary —
  NOT a submodule under `native/`: a vendored tree is rsynced to builder0 on every run and its build products
  `--delete`d there. Per worktree only our few sources build (`native/build/`, seconds) into `native/bin/`.
- **A generated `.gdextension`, not a committed one.** Godot prints `ERROR: GDExtension dynamic library not found` for
  a listed library that is absent, and `tools/engine_log_gate.py` fails any target on an `ERROR:` line — so the
  no-`.so` runs (NATIVE=off, the web build) must see NO `.gdextension`. `make native` copies
  `native/tank_squad.gdextension.in` to `native/bin/tank_squad.gdextension` beside the `.so`; `make native-off`
  removes it; `make import` (which every target runs) registers or forgets it.
- **One `.so` for both the `debug` and `release` feature tags** (the editor binary runs the suite and his skirmish; a
  release export loads the same file): same flags, only godot-cpp's internal checks differ. A `template_release`
  flavour is a later line in `mk/native.mk` if an export ever needs it.
- **A host stamp, not trust.** `native/bin/.built-on` and `native/build/.stamp` (host, tree, flags, godot-cpp): a
  `.so` or build tree that arrived from another machine (rsync) is rebuilt there, so builder0 never tests a
  laptop-built library.
- **`make bootstrap` does not build it** (a cold godot-cpp is ~3.5 min on builder0's E-cores, ~10 on the laptop):
  `make check` / `make native` do, on first need; `make doctor` reports it.
- **The no-op is `IncomingFire.closest_approach`** (pure, one call site, `combat_motion.gd:1069` inside the dodge
  loop): the smallest function with every width hazard in it (float32 members, double scalars, a narrowing scale).

### Done

- **N0 built and loading on builder0** (`8503f23e`): godot-cpp 10.0.0-stable built in 228 s cold on builder0's eight
  E-cores (`taskset -c 4-11`, 1089 TUs; ccache warm after); our `.so` 3.0 MB; `NATIVE godot-cpp 10.0.0-stable | api
  4.7.2 | gcc 15.2.0 | -O2 -ffp-contract=off -fno-fast-math | built on builder0 | real_t 32 bits | switch on`.
  `test_native`: 4000 seeded samples of `closest_approach`, **0 mismatches** bit for bit (builder0). A deliberate cold
  import (`rm -rf .godot`, 511 steps) with the extension loaded: clean.
- **The first price of the no-op** (builder0, light lane, UNPINNED, under a check at load ~10, n = 1, `8503f23e`,
  his Sumps 24 v 17 seed 92721, no leaders): `ai-ab-match AB_SWITCH=native` hashes EQUAL (`b75e19aec9c19ce5` both
  runs); **the native arm is 3.7 % SLOWER on the controller band** (ON 20173 v OFF 19448 µs/tick, 1911/1890 ticks;
  whole tick 22536 v 21714). **Finding, the one N0 exists for:** a Variant call across the seam (`impl.fn(...)` on an
  `Object`: method lookup, five args converted, a Variant back) costs more than the ten-line GDScript body it
  replaces; at ~2000 `closest_approach` calls a tick (every `would_be_hit` step of every incoming round) that is
  ~0.35 µs a call, +0.7 ms a tick. So the seam granularity rule: **a port pays off only where one call replaces tens
  of microseconds of GDScript** (N1's `solve`: ~43 calls a tick at 50 v 50 for ~87 µs of GDScript each) **and
  sub-microsecond functions must be batched** (the whole `would_be_hit` loop as one call: N0b below). The per-call
  floor is measured by `make native-bench` (next). The pinned n = 3 series comes after the checks.
- **The floor per call** (`make native-bench`, builder0, `taskset -c 0-3` under a check's load, `4fe82371`, 300 000
  calls each): a dynamic native call 0.239 µs (`impl.fn(...)`; `call()` 0.241, a `Callable` 0.234; no args and a
  String back 0.204); the GDScript `closest_approach` body 0.284; the seam as the game calls it 0.478 (the static
  wrapper 0.075 + two cross-class static reads); so **a seam breaks even at ~0.5 µs of GDScript and pays from a few
  µs up**.
- **N0b `would_be_hit` as ONE call** (`792945cf`): 3000 seeded samples (1818 hits), 0 mismatches, builder0.
- **N1 ORCA native** (`4fe82371`): `refresh`/`load_rows` hand the native table the columns once a tick (one call, by
  reference); `solve` is one call per mover returning (vx, vz, the counters). 60 seeded tables × 25 queries = 1500
  solves (crowds, overlaps, same-spot pairs, oriented on/off, caps 6 and 3): **0 mismatches bit for bit**, the probe
  counters equal (builder0). The port is 330 lines of C++ against 180 of GDScript: every scalar double, every Vector2
  op float32, `_det` in double over float32 members, as the GDScript has them.
- **Per-port prices, first reading** (builder0 light lane, UNPINNED, under a check at load ~10, n = 1, `4fe82371`,
  his Sumps 24 v 17 seed 92721, no leaders; hashes EQUAL `b75e19aec9c19ce5` in every run, the same fight as N0's):
  `native_dodge` −2.6 % of the controller band (ON 14156 v OFF 14532 µs/tick), `native_avoid` −2.0 % (10531 v 10746),
  all three ports together −0.9 % (16743 v 16601: noise; the box's load moved the band 10–17 ms between runs, only
  the within-run pairs are comparable). **Single digits of the band at 24 v 17, as the brief expected**; the pinned
  n = 3 series at 25 v 25 and 50 v 50 (denser: more neighbours, more rounds in flight) follows when the checks are
  off the box.

- **N0–N1b GREEN, merge here: `799e5408`** (ON check `184dbd05`: builder0 exited 0, 2268/0, 23 ALL JUDGED, unmoved,
  determinism `762a0576f944f5b7`; OFF check the `3c61ecbe` tree: exited 0, 2268/0, 23 ALL JUDGED, unmoved, the same
  determinism; above them docs and logs only). `make native-proof` EQUAL on builder0 (`b75e19aec9c19ce5` on / off /
  A/B; the band −7.1 % light-lane n = 1) and on the laptop (`71ebff19d3f2dbc0` on / off / A/B; −5.2 %). Both
  machines: all four ports 0 mismatches in their unit proofs (gcc 15.2 / glibc 2.43 and gcc 13.3 / glibc 2.39).
- **N2a the navmesh's closest point** (`21e8ae43`, `c5762661`, `589db189`; seam granted C23.1a): `NavNative` indexes
  the map's polygons (regions in `map_get_regions` order, vertices `transform.xform`ed as the region builder does) in
  a grid and runs the engine's own per-polygon loop over a superset of candidates in the engine's order. Proof: 5611
  points on the Sumps (a 7 m lattice, random, vertices, mid-edges, above and below) and 961 points on each of the 13
  dealt maps + foundry: **0 mismatches bit for bit** against `map_get_closest_point` (laptop); 3.6 polygons visited
  a query against the engine's 570. Laptop: engine 25.5 µs a call, native 1.9 (the dynamic call included). Laptop
  `native-proof` at `589db189`: EQUAL (`71ebff19d3f2dbc0`, unchanged by N2a), **the band −15.2 %** with every port
  on (his Sumps, no leaders, n = 1). The pinned n = 3 series on builder0 (`make native-price`, his Sumps / 25 v 25 /
  50 v 50 with leaders, `native_nav` alone and every port) is running; its check too.

### The band sized for his decision (builder0, `taskset -c 0-3`, n = 3, `3c61ecbe`, every port ON)

`make native-sizing`: 50 v 50 Sumps with leaders both sides (perf's `size 50` armies, seed 92721, 120 s = 3600
ticks, the fight thins to 4 + 37 by the end, so these are whole-match means; in contact the band is higher). Logs:
`streams/references/round23/native/`.

| | ms a tick (uninflated, `--sim-profile`) | runs |
|---|---|---|
| whole tick | **51.4** | 44.7 / 40.4 / 69.2 (the third under a load spike: read the first two) |
| controllers (the band) | **39.8** | 34.5 / 31.2 / 53.7 |
| elements | 7.6 | 6.6 / 6.0 / 10.2 |

The shares (instrumented `--brains-parts`; shares and calls are the reading, the µs are inflated ~1.1×):

| bucket | µs a tick | share of the brains' work | of which engine calls that stay engine calls |
|---|---|---|---|
| **execute** (`compute_command` every tick: move, avoid, weapon, unstick) | 24 392 | **56.6 %** | 6 716 = 27.5 % of execute (`nav.closest` 6 247: **429 `map_get_closest_point` a tick at 14.5 µs**; `nav.path` 469) |
| **think** (situation, decide, act; every 3–9 ticks, 15.3 thinks a tick) | 18 675 | **43.4 %** | 589 = 3.2 % (`los.ray` 149 rays a tick) |

Inside execute: `move` 16 942 (68 calls: `nav.chord` 3 170, `move.path` 3 199, `steer.drive` 3 446 (the k-turn
planning), `move.avoid` 2 741 of which `avoid.solve` 854 (19 µs a call NOW, native; 93 before), `move.guard` 1 675,
`t.poll` 2 883), `weapon` 5 715 (`weapon.scan` 2 417). Inside think: `situation` 7 763 (507 µs a think: `s.contacts`
1 816, `s.select` 1 019, `s.cover_fire` 968, `s.cover_spots` 770, `s.allies` 739, `s.tactics` 780), `decide` 2 915
(191 µs a think), `act` 1 604.

**What it says for the three options (his call):** (1) **N3** (the execute step native with its data reshaped) has a
ceiling of execute's NON-engine share, ~41 % of the brains' work; think stays GDScript in that plan (another 42 %);
so N3 alone cannot reach −60 %: reaching it means the whole brain (execute AND think) in C++, a multi-round rewrite,
and bit-exactness through the Dictionary-ordered state machine is unlikely end to end (a DECLARED change, his to
accept). (2) The one line that is both big and clean is the engine's own `map_get_closest_point` (14.5 % of the
brains' work; a linear scan of every navmesh polygon): **N2a** re-implements it natively with a grid, equal-answer by
construction (the plan in `_agents/native.md`), worth −10 to −15 % of the band at 50 v 50, more in contact. (3) A
think-rate / LOD design (think less often or less widely for crews far from the player's fight) cuts think's 43 % by
policy, not by porting: brains' lever, his taste. The cap at 25 (the laptop's 39–40 ms a tick in contact) stays
until one of these lands.

### Questions for the lead

- None yet (C++ taken as recommended; nothing here needs an answer tonight).

### Requests to other streams

- **Orchestrator (`tools/remote.sh`, when convenient; not blocking):** add to the UPLOAD rsync
  `--filter='P native/bin/' --filter='P native/build/' --exclude='native/bin/' --exclude='native/build/'`
  so builder0 keeps its own built library between runs (today the laptop's small `native/bin` and `native/build`
  go up and are rebuilt there by the host stamp: correct, a few seconds, just wasteful). `.tools` already covers
  godot-cpp.

### Known issues

_(none yet)_

### Merge notes (shared files, additive)

- `mk/core.mk`: `check` runs `native-for-check` before `import` (3 lines); `doctor` prints a `native:` line.
- `.gitignore`: `native/build/`, `native/bin/`.
- `game/ai/brain_switches.gd`: `native` switch + NAMES entry + `set_named` arm (masked by availability).
- `game/ai/incoming_fire.gd`: the seam at the top of `closest_approach` (4 lines).
- `game/ai/combat_motion.gd`: the seam at the top of `would_be_hit` (5 lines).
- `game/ai/avoidance.gd`: the seam at the top of `solve`; `_load_native()` called at the end of `refresh` and
  `load_rows` (the native table fed once a tick).
- `game/ai/cover_map.gd`: `_native` (the twin, built in `_index`), seams in `clear_line`, `clear_line_coarse`,
  `path_blocked`.
- `game/ai/pathing.gd` (brains'; granted C23.1a): three lines above the engine call in `closest_point`.
- `export_presets.cfg`: `native/*` appended to the Web and Web Factions `exclude_filter`.
- `tools/remote.sh`: the orchestrator's `1c14fd5a` (native/bin, native/build protected and not uploaded), merged here.
