# Stream: scale (the roster at real relative scale — CP2 — then everything that was sized for a 4 m hull, then A3)

> Read `CLAUDE.md`, `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*),
> [game_design.md](../game_design.md) (*Round 9 direction* — the lead's words and the sizing rule — and *Ruling: the
> War Rig stays at 14 m*, *Factions*), [workstreams.md](../workstreams.md) (*Round 9: the seven streams*: contract
> **S1**, checkpoint **CP2**, the ownership carve-out), [research_catalog.md](../research_catalog.md) (rows **A3**,
> pathologies **P5** and **P6**, Part 1 §4), and [arenas.md](../arenas.md).
>
> **You own** all of arena's paths this round (`arenas/`, `game/arena/`, `tools/make_arenas.py`, `tools/arena_report.py`
> and its siblings, `mk/arena.mk`, `_agents/arenas.md`), plus **a carve-out from combat's C1**: the `hull_size` and
> `muzzle_height` **values** of every `Units.PROFILES` entry and the new optional `scale_reference` key in
> `game/units/units.gd`, and the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in
> `game/match/match.gd` (`SPAWN_JITTER_MAX_X/Z` and `SPAWN_SLOTS` are derived from them — if they must move, they move
> in the same commit with the derivation written beside them). New: `tools/roster_scale.py`, `mk/scale.mk`. combat
> reviews the `units.gd` / `match.gd` diff at merge and owns the files again afterwards.

## The lead's direction (2026-09-19, evening)

> *"We resized the semi trucks for the gang and this makes the game much cooler and awesome. We need to do
> proportional, real-world relative sizing for all of our vehicles. As an example, the bus-tanks and garbage trucks for
> the condemned definitely need resizing, so by extension I'm sure so do the rest."*

And the two rulings this rests on, both his:

> *"Yes the war rig stays at 14m, we can revisit that later if it's still an issue."* (2026-09-19)
>
> *"the intent for the semi trucks is that they're huge — we'll worry about evening up factions later."* (round 8)

**What he confirmed by playing:** the round-8 semi resize worked not because of the number but because a semi finally
*looked like a semi next to a car*. He wants that for every vehicle. He called this "minor"; it is the item he will
judge the round by, and it touches five owners' paths — which is why it has its own stream.

## The sizing rule (decided by the orchestrator; do not re-derive it, apply it)

From [game_design.md](../game_design.md) *Round 9 direction*:

1. **One factor `K` for the whole world, anchored by the War Rig at its ruled 14.0 m.** A real tractor + tanker
   trailer is ~18–21 m; fix the rig's `scale_reference.length_m` from a cited source and publish
   `Units.SCALE_K = 14.0 / that` **once**. Expect K ≈ 0.67–0.78.
2. **Every other unit's length = its real-world reference length × K.** The only judgment per unit is *which* real
   vehicle it is; [game_design.md](../game_design.md) *Factions* names most of them (prison-bus dozer, armored troop
   bus, garbage truck, crane carrier, power-utility truck, plow-nosed fire truck, rat rod, 1950s pickup, tow wrecker,
   rigid fuel tanker, up-armored pursuit sedan, 6×6 MRAP, 8×8 assault gun, rocket truck, riot truck, supercar,
   limousine, teardrop drone, missile wing). Each unit's `blurb` in `units.gd` says what it is. Cite a real length for
   each (manufacturer figure or a well-known type: a Blue Bird school bus, a Stryker MGS, a Cougar 6×6, a Peterbilt 379
   + 42 ft tanker…). Where the design names no real vehicle (the Syndicate hover platforms), choose the nearest real
   analogue by role, say so in the table, and keep it consistent within the faction.
3. **Width and height come from the approved mesh at that length** — `SizeLook.box_at_length(unit, length)`
   (`game/theme/fx/bench/size_look.gd:53`), the tool round 8 used for the rig. **`hull_size` IS the collider**
   (`units.gd:372`): a tidy round number that disagrees with the mesh means shells hitting empty air. Do not round.
4. **Balance is not a constraint.** Measure the consequences; never tune a size to fix a win rate.
5. **The lead sees the roster before it ships** — one side-by-side frame (backlog item 2). A look, not a number.

**Why rig-relative and not real metres** is recorded in game_design.md. The one open question — would he rather have
real metres (K = 1, rig 18–21 m)? — **is the orchestrator's to carry on the decisions page. Do not block on it.** If
he answers "real metres", it is one constant and a re-run of your table, which is the point of building it as a table.

## Where things stand

- **The roster today** (`game/units/units.gd` at `f49aa08a`): 21 units. Every hull except the War Rig
  (`[3.32, 5.24, 14.0]`, line 378) and the Resupply Tanker (`[3.39, 3.59, 7.0]`, line 442) is **2.8–5.0 m long** — the
  armored troop bus (`ifv`, 3.8 m), the 8×8 Assault Gun (4.6 m), the 6×6 Retired APC (4.2 m), the Rat Rod (2.8 m) all
  within two metres of each other. A real school bus is ~12 m; a Stryker ~7 m; a rat rod ~4.5 m.
- **Art already fits itself to length.** `DozerPart._fit_to_hull` (`game/theme/cyberpunk/dozer_part.gd:73`) scales
  every part of a unit uniformly by `hull_size[2] / FactionArt.hull_length(unit)`. **Changing `hull_size` is the whole
  visual change**; nothing in `game/theme/` needs editing for the resize. Round 8 proved it on the rig: 5.6 → 14.0 m,
  drawn 721 × 315 px at the lead's camera against a tank's 199 × 100 (builder0, `14bdb039`).
- **feel's round-8 roster-wide hitbox finding** ([archive/round8/feel.md](archive/round8/feel.md) line 199): **all 19
  art units' boxes disagree with their drawn meshes by more than 5% on some axis** (the rig was +1.7 w / +2.3 h before
  its fix; `law_suppressor` drawn 1.0 m taller than its box). Regenerating every box with `box_at_length` fixes this
  **by construction**, and the every-unit box-fill test feel owed lands with it (`test_the_semis_fill_their_boxes`,
  `feel-rig-check` branch `26e1f26a`, mutation-checked — take it, generalise it, or write your own).
- **Units with no art of their own:** `SizeLook.natural_size` returns zero when a unit has no `model_scene`
  (`size_look.gd:62`) and `box_at_length` then hands back today's `hull_size` unchanged. Find out which of the 21 that
  is (the Condemned's cyberpunk parts under `game/theme/cyberpunk/units/` vs the three faction folders under
  `game/theme/factions/*/parts/`). **Those units get a length from the rule and keep their width/height ratio from
  today's box, and the table says "no mesh" beside them.** Do not invent proportions.
- **Muzzle heights are a roster-wide invariant.** Rounds fly flat at muzzle height; `test_every_muzzle_clears_under_every_hull_top`
  (`tests/test_units_catalog.gd:46`) asserts every `muzzle_height ≤ min(hull_size[1]) − MUZZLE_CLEARANCE (0.1)`.
  Today the shortest hull is 1.4 m (`units.gd:293` says heights are held ≥ 1.4 m for this reason). If K shrinks the
  Rat Rod or the Skimmer below that, **every muzzle in the roster may have to come down** — and `muzzle_height` is
  yours this round for that reason. Re-derive each from the mesh at the new scale where it was measured from the mesh;
  keep the test green without weakening it.
- **The spawn grid was sized for a 2.6 × 4 m hull** (`game/match/match.gd:70–86`): 13 columns 11 m apart, 4 rows
  8 m apart, jitter ±3.5 / ±1.2 m, 52 slots, fourth row at z = 114 against `DRIVABLE_LIMIT` 116. Round 8 found
  *"length was the axis the spawn grid appeared to cap"* for the rig. Arena layouts carry **baked** spawn lists
  regenerated by `tools/make_arenas.py` (**the copy WON once** — Invariant 0's table in workstreams.md: baked spawn
  lists beat the constants). `Arena.spawn_spot` is consulted first (`match.gd:484`); the constants are the fallback.
  Change both in one commit or you have changed nothing on a real map.
- **Assembly and formation spacing already read `hull_size`** (`game/tactics/army_layout.gd:159, 295`): `deep_floor =
  longest + HULL_CLEAR_M`. That is squad's code; it will re-measure after CP2. Note anything you see it get wrong in
  *Requests to other streams*, do not edit it.
- **The navmesh is baked with ONE agent radius, 2.0 m** (`Arena._bake`, `game/arena/arena.gd:141`; consumed as
  `Movement.NAV_AGENT_RADIUS` in `game/ai/movement.gd:43`), for a footprint range that is about to grow from 5× to
  more. That is **P6** in the catalogue. The navmesh is baked as the southern half plus its 180° mirror
  ([arenas.md](../arenas.md) *Why the navmesh is baked as one half plus a mirror*) — **any bake change re-runs the
  swap-bases control** (trip-up 21: the south base once won 64%).
- **Cover is a step function at 12.19 m** (arena, round 8, `b5e52899`; [archive/round8/arena.md](archive/round8/arena.md)
  line 314): share of the field within 45 m of a prop long enough for the hull —

  | hull | 6 m | 7 m | **12.19 m** | **12.5 m** | 14 m |
  |---|---|---|---|---|---|
  | yard | 0.99 | 0.99 | 0.99 | **0.00** | 0.00 |
  | pit | 0.85 | 0.48 | 0.46 | **0.00** | 0.00 |
  | terminus | 0.98 | 0.95 | 0.91 | 0.91 | 0.91 |

  The cliff is `container_40`'s own length, **an artefact of registering cover by sampling the hull's centre point**
  ([research_catalog.md](../research_catalog.md) Part 1 §4). `make arena-report` prints a `WATCH` line for it
  (`tools/arena_report.py:186–195`: *"NOTHING on this map can hide the longest hull"*). **After the resize several
  more hulls cross 12.19 m on yard and pit** — the bus, the garbage truck, the tanker are candidates — so A3 stops
  being a rig-only fix and becomes the roster's. Static geometry; measured at `f49aa08a`'s tree by arena on the
  laptop (pure Python, machine-independent).
- **`gangs vs law` went 9/20 → 0/20 with the 14 m rig** (combat, round 8, [archive/round8/combat.md](archive/round8/combat.md)
  line 323): 20 counterbalanced matches across yard and pit, p ≈ 2×10⁻⁶, builder0. Shuffling evidenced against, splash
  evidenced against, "bigger target" surviving by elimination only. Combat's hypothesis: law is the suppression
  faction and a 14 m hull is a far easier thing to keep suppressed. **Unexplained, and not yours to fix** — yours to
  re-measure on the whole resized roster (stretch item 6), because the resize is the first experiment that changes
  every faction's size at once.
- **The sim baseline WILL move** with CP2 (collision boxes are the simulation). **You do not record it** (Invariant 2,
  workstreams.md): your green report says *"the sim baseline moves and is deliberately NOT recorded here"* and the
  orchestrator records it on `main` in the same session as the merge. On the laptop `sim-baseline` silently skips
  (glibc 2.39 has no line), so a green local check proves nothing about the hash — say so in Status rather than
  "sim-baseline passed".

## Backlog (in order)

Tests first for every item. Each green step is a commit; each report names the commit and the machine.

### 1. The reference table, derived and asserted (S1)

- Add the optional key `scale_reference: {"vehicle": String, "length_m": float, "source": String}` to the C1 schema
  comment in `units.gd` and to every unit. Add `Units.SCALE_K`, computed from `gang_tank`'s reference at 14.0
  (`SCALE_K = 14.0 / PROFILES["gang_tank"]["scale_reference"]["length_m"]`), **derived, not typed**.
- **Tests, written before the numbers change:**
  - every unit with a `scale_reference` has `hull_size[2] == snappedf(length_m × SCALE_K, 0.01)` (tolerance 0.01);
  - every unit with a mesh has `hull_size` equal to `SizeLook.box_at_length(unit, hull_size[2])` within a stated
    tolerance (this is feel's owed box-fill test made roster-wide; it must fail today on the 19 units feel listed —
    **mutation-check it: run it on the current numbers first and record the 19 failures as the "before"**);
  - the muzzle test stays as it is and stays green;
  - a test that the K derivation is used everywhere (rename the rig's reference and the table refuses; Invariant 0's
    "mutation-check the reader both directions").
- `make roster-scale` (`mk/scale.mk` → `tools/roster_scale.py`, reading `units.gd` **the way `arena_report` reads it,
  not a copy**): one row per unit — faction, id, reference vehicle, cited length, K, target length, today's box, the
  mesh's box at the target length (from a headless Godot pass that calls `box_at_length`), and a MISMATCH column.
  Print K and the rig's reference at the top of every run. Units with no mesh print "no mesh" in the box column.
- **Deliverable for the orchestrator before any value changes:** the table, in Status, so the reference choices can be
  read at a glance. Then apply.

### 2. Apply it, and render the frame the lead judges

- Write the new `hull_size` (and `muzzle_height` where the mesh moved it) for all 21 units. `_fit_to_hull` does the
  rest. Run the catalog tests; run `make lint test`.
- **The side-by-side frame:** extend `SizeLook` (or add a mode to it — it is feel's file; ask via Status, or build
  the lineup in your own `tools/`/`mk/scale.mk` target that drives `--size-look-lengths`' machinery) so **all 21
  vehicles stand in one line-up at one camera** — the lead's pose (`SizeLook.PITCH_DEG` 21°, 49 m, FOV 35 is what
  round 8 used; also give him a wider pose that fits 21 hulls), grouped by faction, the War Rig and the Condemned
  `tank` at both ends as references, each labelled. Render on builder0 at 1920×1080 (`make remote T=…`; needs a
  display, see `size-look`'s note in `mk/fx.mk:85` and trip-up 65 about stale frames). **Look at it yourself first**
  (verification.md: look at the screenshots you produce). Then **send the path to the orchestrator** — it goes on the
  lead's review page. **Do not announce CP2 until the frame has been sent.** The numbers need no approval; the look
  does.
- Also re-render `make facing-audit` for the whole roster: a unit that grows 2× can reveal a turret pivot or gun cut
  placed for the old roof (`_fit_to_hull` raises them by `fit`, but check).

### 3. The spawn grid, from the roster's largest hull

- **Test first, and derive the expectation from the data (lesson 3):** for every shipped arena and every faction at
  `Units.BASELINE_BUDGET` (and the gangs' swarm at `Army.MAX_ARMY_UNITS`), every spawned hull — jittered to
  `SPAWN_JITTER_MAX_*` — stands clear of every neighbour by the clearance the comment at `match.gd:70` promises and
  inside `Arena.contains()`. Write it against the roster's largest hull, not against 4 m. Run it on today's
  constants with the new roster: it should fail, and the failure is your "before".
- Fix `SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING` (and the jitter bounds they derive, in the same commit with the
  derivation written down), **regenerate the baked spawn lists** with `tools/make_arenas.py` for every layout, and
  keep the front row at `BASE_Z` so spawn distance and pace are unchanged (or say by how much they changed and why).
  The fourth row must stay inside the arena for every shape (M4: the hexagon's inradius is 121 m; `DRIVABLE_LIMIT`
  116 is the inscribed bound).
- **Re-run the swap-bases fairness control** ([verification.md](../verification.md); `make team-fairness`, `make
  arena-series`), on builder0, and report win rates with N.

### 4. Clearance for the new roster (P6), then announce CP2

- Measure first: `make nav-maze` (30 units, head-on) and `make nav-fight` on yard on the resized roster, against the
  same runs on `main` before your change, same seeds, builder0. Report arrivals, stuck events and `blocked_*`
  buckets side by side. If the widest hulls now scrape or stall in the maze's gaps, that is the P6 finding made
  concrete — **report it with numbers before touching the bake.**
- If the bake must change (agent radius, or the maze's gap widths as a fixture), do it as its own commit, re-run the
  swap-bases control (the half-plus-mirror construction, [arenas.md](../arenas.md)), and update
  `Movement.NAV_AGENT_RADIUS`'s **comment** via a request to nav — the constant is nav's; a mirror that drifts is
  exactly what Invariant 0 forbids, so propose that nav read it from `Arena` instead.
- **Announce CP2** to the orchestrator (SendMessage *and* Status): the green commit hash on builder0 (`>> remote:
  make check exited 0` and the runner's `N passed, 0 failed`, unpiped), the statement *"the sim baseline moves and is
  deliberately NOT recorded here"*, the frame's path, the fairness numbers, and the list of every other stream's
  number that is now stale (spawn, cover, clearance, formation spacing, anything in pixels at his camera).

### 5. A3: hull-chord cover over directional summed-area tables

Catalogue row **A3** ([research_catalog.md](../research_catalog.md)), owner arena → you; combat owns the consumer.
**Replaces** centre-point cover registration (Invariant 0c: say so in the commit).

- **Positive control first, before any code:** reproduce the 12.19 m step on yard with `make arena-report` on the
  resized roster and record it — the treatment has engaged only if the step is gone afterwards (lesson 147's rule:
  prove the arm is distinguishable).
- Build, in `game/arena/`: for K = 8 canonical headings, a directional summed-area table of prop occlusion over the
  arena grid, and a query **`Arena.cover_fraction(from: Vector3, heading: float, hull_length: float, watcher: Vector3)
  -> float`** (name it in Status if you change the signature) returning the fraction of the hull chord occluded from
  the watcher — two lookups and a subtraction, independent of hull length, integer prefix sums (deterministic).
  Tables are built at arena setup from the same obstacle list the collision comes from (read, never copied).
- **Falsifier (pre-registered in the catalogue):** exposed hull fraction for units reporting `AT_COVER` drops below
  5% at every hull length 2.8–14.0 m, and yard's cover score for a 14 m hull rises from 0.00 to within 0.1 of its
  12 m value.
- **`tools/arena_report.py`'s `hull_cover` and its WATCH line change in the same commit** as the tables, or the
  report becomes a confident false alarm (the lead's ruling in game_design.md *Ruling: the War Rig stays at 14 m*).
  Keep the old point-sample number printed **beside** the new fraction for one round so the two can be compared
  (lesson 49: report the split alongside, never instead of).
- Hand combat the seam: a message naming the function, its units, and a one-line example, and where today's
  centre-point registration lives so combat can replace its call. Do not edit `game/combat/` or `game/ai/`.

### 6. Stretch: the 9/20 → 0/20 re-measured on the resized roster

Reproduce combat's round-8 series (per-matchup, counterbalanced, both maps, same seeds and time — their conditions
are in [archive/round8/combat.md](archive/round8/combat.md) and `streams/references/round8/combat/`) on the resized
roster. Report per matchup, with N and p. **Report, do not tune.** If it moved, say which sizes changed on both
sides; if it did not, say that the resize is not the variable.

## How to verify

- `make remote T=check` before every readiness claim, **read the wrapper's own `>> remote: make check exited <N>`
  line and the runner's `N passed, M failed`**, never a pipe's exit code (lesson 28). Iterate locally with
  `make lint test`; a filtered run never establishes readiness (lesson 45).
- `make roster-scale` (yours) prints K, the references, and every box against its mesh.
- The frames: `make remote T=…` for the line-up and `facing-audit`; open every PNG you produce and look at it.
- Fairness after any spawn or bake change: `make team-fairness`, `make arena-series` with `--swap-bases`, builder0,
  N stated.
- `make arena-report` before and after A3, with the WATCH line quoted.
- Every number: commit, machine (laptop is ~2.75× slower than builder0), workload, sample size.

## Don't touch

- `game/units/units.gd` beyond the carved-out keys (`hull_size`, `muzzle_height`, `scale_reference`, `SCALE_K`, and
  the schema comment): no costs, speeds, armor, weapons, turn rates. **No balance tuning of any kind.**
- `game/match/` beyond the three spawn constants and what they derive; `game/combat/`, `game/tank/`, `game/ai/`,
  `game/tactics/`, `game/control/`, `game/ui/`, `game/camera/`, `game/theme/` (feel's — the fit is automatic; if
  `SizeLook` needs a mode, ask feel via Status and build in your own paths meanwhile).
- No Meshy, no ElevenLabs, no new art. The Syndicate airship is feel's this round, not yours.
- `tests/baselines/sim_state_hash.txt` — the orchestrator records it.
- Never `pkill -f`; one `make remote` per worktree at a time (trip-ups 19, 66, 68).

## Waiting on the lead

- **The side-by-side look** (item 2): he taps the frame on the review page. Build everything else while he is away;
  CP2 announces once the frame has been *sent*, not once it has been *approved* — he removed balance and size as
  constraints, and the numbers are derived.
- **Rig-relative K vs real metres:** the orchestrator carries it. Not a block.

## Requests to other streams (fill in as they arise)

- **combat:** reviews the `units.gd` / `match.gd` diff at merge; owns A3's consumer.
- **squad:** formation and assembly spacing re-measured after CP2 (`army_layout.gd` reads `hull_size`).
- **nav:** `Movement.NAV_AGENT_RADIUS` mirrors the bake — propose it read `Arena`'s value.
- **feel:** a 21-unit line-up mode in `SizeLook`, if you cannot build it in your own paths.
- **control:** the camera, HUD, selection boxes and radar at his pose against the new sizes.
- **metrics: LANDED — the merge trap is now impossible, not documented.** `tools/remote.sh` re-execs from a private
  copy and unlinks it immediately (`pinned=$(mktemp …)`, `TANK_SQUAD_PINNED_SELF=… exec bash "$pinned"`), with the
  reasoning in its own comment: *"the kernel keeps the text alive for this process through its open fd, and nobody —
  not even git — can reach it by name to change it."* That is better than the copy-to-/tmp I proposed, because
  unlinking closes the window where the copy itself could be edited. **The ⚠ below is retired**: a `git merge` can no
  longer rewrite a wrapper mid-flight, so the hand-check it demanded is no longer the thing standing between us and a
  lost run. *(Original request kept below for the record of what it cost to learn.)*
- ~~**metrics (or whoever owns `tools/remote.sh`): make the merge trap impossible instead of documented.**~~ I lost a
  render to it (a wrapper part-way through `tools/remote.sh`/`slot.sh` when `git merge main` rewrote them under it),
  and the brief now carries a ⚠ telling every future agent to check by hand. While merging today I noticed metrics
  running `bash /tmp/remote.sh.AIzYCv check` — **a copy of the wrapper in `/tmp`**, which is exactly the defence, and
  it is *not* in the tree, so metrics invented it per-invocation in their own session. Proposal: `make remote` copies
  the wrapper (and `slot.sh`) to a temp path and execs that, so a merge can never rewrite a script mid-flight. That
  turns a hand-checked rule into a property, and retires the ⚠ and half of trip-ups 66/68. **One of us should land it
  rather than both keep working around it.**

## Status

_Updated 2026-09-20 (post-merge), worktree `godot-scale`, branch `stream/scale`._

### The fairness controls after CP2 — the split beside the aggregate

**CP2 is green at `7542df28` (1395 passed, 0 failed) and merged to `main` at `86463527`.** These are the controls
run on the merged tree, and they are **two different experiments**. Reporting them pooled would be the round-8
pooling mistake again, so each is labelled by the population it actually exercises:

> ### ⚠ BOTH FAIRNESS CONTROLS ARE OWED — builder0 went off the network mid-run
>
> **Nothing of mine is red; there is simply no number yet.** The `arena-series` run started on builder0 at 08:21 and
> the box dropped off at ~08:27. From my own log, which is the only thing that counts (lesson 28):
>
> ```
> ssh: connect to host builder0 port 22: No route to host
> >> remote: FAILED to copy build/ back (rsync exit 255); local build/ is STALE, not this run's
> >> remote: make arena-series ARENAS=... SEEDS=18 OUT=fairness-cp2 exited 255 (build/ copied back: FAILED)
> ```
>
> `ssh builder0 uptime` still answers `No route to host` at 08:28. **`exited 255` is transport, not a result** — the
> matches were mid-flight, no summary was written, and the copy-back failed, so anything in `build/` is a previous
> run's. I checked: `build/fairness-cp2.json` does not exist and there is no `grid-fairness` or `faction-matrix` file
> in `build/` to be mistaken for one. **Do not quote a fairness number from this tree until one of these runs
> finishes.**
>
> **Run these two when `ssh builder0 uptime` answers.** Both are long; **neither is a laptop job** (the laptop is
> ~2.75× slower and has the memory guard, and these are 180 and 120 matches):
>
> ```
> make remote T="arena-series ARENAS=yard,boulevard,pit,boneyard,foundry SEEDS=18 OUT=fairness-cp2"
> make remote T="test FILTER=spawn_grid grid-fairness"
> ```
>
> One `make remote` per worktree at a time, so they go in that order, and **read each result from the wrapper's own
> `>> remote: make <target> exited <N>` line**, never a pipe.
>
> **⚠ AND CHECK FOR AN ORPHAN FIRST — the dropped run left its whole self running on builder0.** The box came back at
> 08:31 and ten minutes after my wrapper had died at 255 the remote side was still going: `make arena-series`, its
> `slot.sh`, `arena_series.py --jobs 2` and **two headless matches**, all with a cwd in `~/tank_squad/godot-scale`,
> holding a heavy-run slot. Found by cwd, terminated by explicit PID (parents and children), then verified no survivor
> — **never `pkill -f`**, which matches your own shell (trip-up 19, hit twice this round).
>
> **The part trip-up 68 does not say, and it is the expensive part: an orphan blocks its own worktree's queue.** The
> next `make remote` rsyncs with `--delete`, so launching the second command would have rewritten the tree underneath
> a running `arena_series.py` — the same hazard as the merge trap, arriving from the other direction. So an orphan is
> not merely a wasted slot you can ignore while you get on with the next thing; **it must be cleared before anything
> else runs in that worktree.**
>
> I killed it rather than letting it finish, which was the close call: it was ten minutes into the right run on the
> right clean tree, so finishing it and fetching the JSON by hand was tempting. It was at `--jobs 2` (slot.sh had
> divided the memory budget while three other worktrees held slots) with ~35 minutes left, a relaunch on the quiet box
> costs ten minutes of lost work, and it was blocking `grid-fairness` regardless. **On the relaunch I let slot.sh pick
> the job count rather than forcing `JOBS=8` to hit the 09:00 read** — that division is what makes the wrapper unable
> to OOM the box, and overriding a safety guard to meet a reporting deadline is the wrong trade. The second command runs the swap-applied positive
> control (`test FILTER=spawn_grid`) in the same invocation as the series it guards, deliberately: a win rate from
> two arms means nothing until that test is green.

| control | what it plays | what it can see | result |
|---|---|---|---|
| `make arena-series` (5 arenas × 18 seeds × 2) | **faction armies** | the arena and its navmesh | **OWED** — died at 255 (transport) |
| `make grid-fairness` (2v2 bots, 60 seeds × 2) | **the spawn grid** | the grid I changed in item 3 | **OWED** — never got a slot |

### main's one red test: all three candidates eliminated from the repository alone

**`test_match_spawns_and_results::test_a_full_faction_army_a_side_spawns_clear_of_itself`** fails on main's tip
(`b008a277`, 1478 passed / 1 failed) with `[Green_S5_1, Rust_S5_1, Rust_S8_1]` "inside a wall or crate". Green on my
branch (`7542df28`, 1395/0) and green on pre-CP2 main (`0808834e`, 1454/0), so it is a composition. **Assigned to me,
and the diagnosis needed no machine time.**

**It is not a new test meeting CP2 for the first time** — that was the cheaper explanation and it is wrong. The test
arrived in `d916dc29`, which **is** an ancestor of both `7542df28` and `0808834e`, so it ran and passed against the
resized roster *and* against pre-CP2 main. Only the combination is red.

**My HEAD already holds main's version of every file that could matter**, which is what makes elimination possible:
`git diff HEAD main -- arenas/ game/arena/ game/match/match.gd game/tactics/ game/units/units.gd` is **empty**. So the
red reproduces here, and the cause lies wholly inside `7542df28..HEAD`. Over that window:

| candidate | verdict | the evidence |
|---|---|---|
| show's arena JSON keys | **ruled out** | only `terminus.json` and `yard.json` changed; **the test runs on foundry** (`Arena.DEFAULT_LAYOUT`, no `layout_name` set and no `--arena` in a test run) and `arenas/foundry.json` is **untouched** |
| squad's X1 pitch in `ArmyLayout` | **ruled out** | **`game/tactics/` does not appear in the diff at all** — the code placing all 45 units did not change |
| combat's `units.gd` | **ruled out** | the +9 lines are a `--tune` parser branch for `switch.<knob>`; inert unless a run passes `--tune switch.*`, and the test passes none |
| theme/dressing (checked for completeness) | **ruled out** | `arena_dressing.gd`, `kit_yard.gd`, `city_block.gd` all changed and the arena scene has a `Dressing` node, but their diffs contain no `StaticBody`/`CollisionShape`/`BoxShape`/`collision`. The whole merge diff also has **no** `collision_layer`/`collision_mask`/`WORLD_MASK` change, so the probe is not hitting a body that changed layer |

**And what remained after all four eliminations — nav's three AI files — was also wrong.** I sent it as the live
suspect and it is not. The answer is not a code change at all, in anyone's stream.

**SOLVED, and read off the output rather than inferred. Units are placed at exactly `y = 0.0`, resting on the ground
at ZERO penetration.** That is a degenerate contact, and which way it resolves depends on the physics engine's
internal state, which depends on how many bodies the process created and destroyed earlier. After an arena test has
built and dropped a 38-body arena, the solver ejects three units **~1.5 m DOWNWARD through `Arena/Ground`**:

```
SPAWN_ISO_BLOCKED Green_S5_1 unit=tank      placed (-52.235, 0.0,  97.07) -> now (-52.235, -1.475,  98.589) moved 2.118 m :: Arena/Ground
SPAWN_ISO_BLOCKED Rust_S5_1  unit=tank      placed ( 52.235, 0.0, -97.07) -> now ( 51.603, -1.475, -97.074) moved 1.605 m :: Arena/Ground
SPAWN_ISO_BLOCKED Rust_S8_1  unit=artillery placed (-38.755, 0.0, -97.07) -> now (-38.755, -1.733, -97.077) moved 1.733 m :: Arena/Ground
```

**The same three units as main, every time.** And note the gap between what the test says and what is true: it reports
*"no unit spawns inside a wall or crate"* and the body they intersect is **the ground** — they are under the floor.
**A failure message that named the body it hit would have saved the morning.** That is the cheapest lesson here and it
is not specific to this test.

**This is round 8's sim-hash lesson with spawn positions instead of a hash: identical geometry, different body
creation order, different Jolt answer.** The victim alone and the victim after the polluter see an identical world —
`active=foundry`, `obstacles=19`, `bodies=111`, `units=90` — and place all 90 units at **identical coordinates**. Only
the engine's internal state differs.

**The eight measurements, because the wrong turns are worth as much as the answer:**

| run | result | what it killed or established |
|---|---|---|
| `test FILTER=a_full_faction_army` | 1 passed, 0 failed | **passes alone** |
| `test FILTER=match_spawns` | 4 passed, 1 failed | fails with `test_arena_layouts` first |
| `test FILTER=army` | passes | bisects the polluter to that one file |
| `make spawn-probe` | blocked=0 of 90, worst motion **0.018 m** | standalone is clean; tick-one motion is settling, so **nav is exonerated** |
| `spawn-probe --pollute=scrapyard` | blocked=**16**, named scrapyard walls at z=±70 | a stale arena *can* produce the symptom |
| `spawn-probe --pollute-free=scrapyard` | bodies **38 → 0 immediately**; blocked=0 | **`free()` is deterministic — my stale-bodies hypothesis is refuted** |
| TestCase teardown leak guard | never fires | **nothing leaks** bodies or navigation regions |
| in-harness reproduction (`test_spawn_isolation.gd`) | the same three units, repeatably | the difference is the harness path, not the pollution |

**I was wrong twice on the way and both refutations are kept beside the answer.** I proposed **RNG stream divergence**
(there is no new random draw anywhere in `game/` in the window — the orchestrator confirmed zero hits independently)
and **stale physics bodies** (`free()` is immediate). A third self-inflicted error is worth recording too: my own
Python overlap check reported *"obstacle overlap: NONE"* while having parsed **0 obstacles with a size**, because
foundry's obstacles carry only `type` and `position` and sizes are resolved in GDScript. **A vacuous check of my own,
in the middle of a round whose whole lesson is vacuous checks.**

**SCALE'S HALF IS CLEAN, and now says so deterministically.** At CP2 hull sizes a full 45-unit army a side is *placed*
with **0 overlapping pairs and a closest-pair gap of 1.040 m**, measured **before any physics step** so it cannot move
with test order:

```
SPAWN_ISO_PLACEMENT closest pair gap 1.040 m; 0 overlapping pairs at placement
```

**The resize did not outgrow the assembly.** That is committed as a real assertion rather than left as an inference
from someone else's red.

**What this stream deliberately does NOT assert (Invariant 0b).** The fix is either to place units a few centimetres
above the ground so the contact is not degenerate (`ArmyLayout.deploy` writes `y = 0.0`; `Match.spawn_position`
returns `y = 0.0`) or to settle more than one frame before measuring. Both are outside these paths, so the test prints
a `SPAWN_ISO_WATCH` line. **Recommended to squad: the y-offset** — it removes the degeneracy at the source and makes
every future spawn measurement order-independent, where settling longer only hides it behind a larger frame count.
The owner should also move the test's own two assertions to placement: **both** of them are taken after a physics
frame, including the hull-overlap one, which is why both moved with test order.

**A vacuous guard in that test, found on the way and not the bug.** Its first line is
`assert_true(Match.SPAWN_SLOTS >= Doctrine.MAX_UNITS)`, and `Doctrine.MAX_UNITS := Match.SPAWN_SLOTS` — **it compares
my constant with itself and cannot fail.** It reads as protecting the grid and protects nothing: the same family as the
baked-spawn guard that compared the constants with themselves. Not my file; reported, not edited.

### The round's recurring shape: things that succeeded in a way indistinguishable from working

Not "something broke". **Every expensive thing this round was something that reported success while doing nothing**,
and the instances are now numerous enough to be a pattern rather than a run of bad luck. Four, across two streams:

| what looked fine | what it actually did |
|---|---|
| `_quieten()` in the line-up render | `hud is CanvasItem` was quietly **false** (`Hud extends CanvasLayer`), so nothing was hidden — two unusable renders |
| the baked-spawn-list guard | `Arena.load_layout` returns `{"layout": …}`, so it compared the constants **with themselves** |
| a stale `slot.sh` `.owner` after a cleanup | the slot goes on blocking **every** worktree's queue while the cleanup looks finished |
| `AssetContracts.ROLE_UNITS` | a round-3 stand-in that was **only** wrong once hulls differed — green on both branches, red on the merge |

feel adds the vacuous lint (`--check-only` reporting "all scripts parse" over **zero files**), the seeded random colour
that looked like a design choice, and A6's heading law that would have passed its own review while moving nothing.

**The operational rule this earns: a check that cannot fail is worse than a missing check, because a missing check is
visible.** Hence the discipline this stream now applies without being asked — mutation-check every reader in both
directions, and prove the arm is distinguishable before believing the result. The swap-bases guard added today is that
rule applied to the fairness apparatus itself: `arena_series.py` verified the flag was *reported*, which cannot see
`spawn_position` ceasing to consult it, and that failure yields two identical arms and a perfectly plausible
"no base advantage" from a treatment that never happened.

### A derived roster is interrogable; a typed one is inert

**The better argument for S1's "derived, not typed", and it was found by accident.** feel reported the artillery's mesh
height as `1.38` and `1.38 × 2.0500 = 2.829` disagreed with the committed `2.82`, so I asked whether the height had
moved. It was settled **without either of us running anything**, by inverting the function that produced the number:
`box_at_length` computes `snappedf(natural.y × k, 0.01)`, so

```
snapped == 2.82  <=>  natural.y × 2.0500 ∈ [2.815, 2.825)  <=>  natural.y ∈ [1.373171, 1.378049)
```

`1.38` was a `%.2f` print, the geometry does not move, and the committed 2.82 will reproduce. **A hand-typed 2.82
could not have answered that question at all** — the only route would have been to occupy builder0.

So the rule has a second payoff nobody designed: **a derived value carries information about the mesh it came from, and
can be interrogated after the fact.** That is a stronger argument than drift, because drift is a risk you are asked to
take on faith while interrogability is a capability that can be demonstrated on demand.

**And the same exchange shows the failure mode of stating a bound you did not derive.** feel's five sample rows were
each correct, but the interval summarising them — `[1.3750, 1.3784]` — was eyeballed from the rows rather than inverted
from the function, so it excluded valid values at one end and admitted an invalid one at the other (`1.3784 × 2.05`
snaps to **2.83**). **Four decimals is a claim about method.** Stated as "somewhere around 1.375–1.378" it would have
been honest; stated to four decimals it looked derived, and the right response was to invert it rather than take it.

### The spawn settle curve — the reference for anyone who ever sees a vehicle pop at spawn

**Units are placed at exactly `y = 0.0` with their collider bottom exactly at the origin, and the ground's top is
exactly `y = 0`.** That contact has zero penetration, and `move_and_slide`'s depenetration recovery resolves it either
way. Measured on a full 45-unit army a side, foundry, `seed_spawns(9, 6.0)`:

| frame | Green_S5_1 (tank) | its `get_position_delta()` | a passing unit of the same class |
|---|---|---|---|
| 1 | **−1.475051** | `(0.0, −1.475051, 1.519325)` | `(0.0, +0.00087, 0.0)` — up 0.87 mm |
| 2 | −0.190296 | `(0.0, +1.284755, 0.0)` | +0.000113 |
| 3 | **−0.041655** | `(−0.000031, +0.148641, 0.000031)` | +0.000015 |

`velocity` is **exactly zero** throughout and `motion_mode` is `MOTION_MODE_FLOATING`, so nothing fell and nothing was
assigned: the delta carries the whole drop, which means **`move_and_slide` recovered the body**. Most units get the
benign form — pushed *up* by under a millimetre. A few get it downward, and **they climb back out: −1.475 → −0.190 →
−0.042 by frame 3.**

**So a spawn pop is a settle, not a bug, and it is transient.** If the lead ever sees a vehicle dip at spawn, this is
it, and the numbers above are the reference. **What is NOT acceptable is measuring it at frame 1** — which is what
main's red spawn test did, and what made the result depend on test order (the engine's internal state decides which
way a zero-penetration contact resolves, and that state depends on how many bodies the process made and destroyed
earlier).

**Ruled (orchestrator): no spawn `y` change — the constant stays `0.0` and wired.** A y-offset only changes which way
the contact resolves; combat's 5 cm control moved the frame-1 value by **0.032 m** and fixed nothing. The fix is
test-side: **assert placement, which is deterministic, and sample any physics assertion after settling.**

**And my collider is exonerated by direct measurement**, so the round-9 `_apply_hull_size` rewrite has no defect here:

```
SPAWN_ISO_AABB Green_S0_1 tank      origin_y=0.0000 local_y=1.2000 box_h=2.4000 -> bottom=+0.0000 top=+2.4000
SPAWN_ISO_AABB Green_S0_4 artillery origin_y=0.0000 local_y=1.4100 box_h=2.8200 -> bottom=+0.0000 top=+2.8200
SPAWN_ISO_GROUND Arena/Ground box (320,1,320) centred y=-0.5000 -> top=+0.0000 bottom=-1.0000
```

Every bottom exactly at the origin, every `local_y` exactly `h/2`, every `box_h` the catalogue height. **The "implied
2.9 m and 3.5 m hulls" were an artefact of reading the sink depth as a half-height** — there is no second height.

### The teardown guard: narrowed to bodies, after it was wrong about regions

The first version counted **navigation regions** as well and failed three tests in control's, squad's and combat's
files. **It was wrong, and the measurement that shows it took one run:**

```
SPAWN_ISO_REGIONS before=2 with_arena=2 then after free: [2, 0, 0, 0]   (frames 0,1,2,3)
```

`free()` takes an arena's **bodies** to 0 in the same call, but the server drops its **regions on the next frame**, and
`teardown()` is synchronous so it can only sample frame 0 — where a correctly-freed arena still shows its regions.
**A guard that fails inside a settling window is the same defect as the test it was written to explain.** The three
tests were innocent (`AiScenario.dispose()` already frees properly), the grants on their files lapsed unused, and the
guard's own advice — *"build arenas through ArenaFixture"* — was withdrawn as wrong: the fixture solves the *consumer*
side, waiting for your own regions before measuring, and does nothing about regions outstanding at teardown.

**What landed is the claim I can defend: bodies only.** A `CollisionObject3D` at teardown has no transient window. It
reports a **lower bound** on leakers (high-water mark: once the count rises, a later test leaking below it is not
blamed), and it fails **the test that leaked**, not the next one to run — which is the whole point, since this class of
bug always appears as the victim's failure.

**The lesson I would keep above either fix:** I built an instrument, it produced three confident reds in other people's
files, and it was measuring a transient. **Checking it before acting on it cost one run; not checking it would have
sent three streams to fix nothing** — and my own overlap script had already printed a vacuous "overlap: NONE" the same
morning. In a round whose recurring failure is checks that cannot fail, the checks I write are not exempt.

### Two units are outside the contract that catches bad boxes — and one is the lead's own example

`roster-scale` prints **`no mesh`** for exactly two of the twenty-one:

```
tank    condemned  Type D school bus, 40 ft (Blue Bird All American)  12.19  8.62  [2.40, 2.40, 8.62]  no mesh
burner  condemned  Pumper fire engine, 32 ft (Pierce Enforcer)         9.75  6.89  [2.40, 2.40, 6.89]  no mesh
```

`SizeLook.natural_size` returns zero without a `model_scene`, so `box_at_length` hands today's width and height back
unchanged. **That is the brief's rule, followed on purpose** — *"those units get a length from the rule and keep their
width/height ratio from today's box… Do not invent proportions."* Nothing here is a defect.

**But the consequence lands on the unit the lead pointed at.** He named the *bus-tanks*. `tank` is `Units.DEFAULT`, it
wears the shared hull art, and it is one of the two the rule could not derive — so it is **8.62 m long and still
2.40 m wide and 2.40 m tall**, inherited from the old boxy `2.4 × 2.4 × 3.6`. A Type D school bus is ~2.6 m wide and
**~3.1 m tall**: the reference says *bus*, the box says *long low slab*, at **3.6:1 instead of a bus's 4.7:1** and
0.7 m short in height.

**Not reopened here, deliberately.** I looked at `lineup_pose.png` and judged that it reads as a bus rather than a
dozer, and he has that frame on the review page; a look he is about to rule on is not mine to relitigate. If he wants
true bus proportions it is either **art for those two units** (feel's, a later round) or a **hand-chosen width/height
from the cited reference** — and the second is exactly what "do not invent proportions" forbids me, so it needs his
word.

**The part that generalises: this class is invisible to every check we have.** feel's drawn-vs-box test compares a box
to a mesh, and these two have no mesh, so **they pass by absence** — the same shape as the vacuous lint over zero files
and my own overlap script over zero obstacles. Two of twenty-one units sit outside the contract that would catch a bad
box, and nothing said so until the table's own `no mesh` column was read. **That column is the only thing standing
between "derived" and "assumed" for these two, which is why it is printed on every run.**

### Queued, in order, behind the current work (recorded so none of it is rediscovered)

1. **The guard + the three fixture-less arena tests** — landing as its own commit, **no baseline move**.
2. **The artillery box + whatever the collider/writer hunt finds** — one commit, one baseline record, both causes named.
3. **Fairness on yard and pit** (the two arenas in `Arena.ROTATION`, both with rows in arenas.md's recorded table).
4. **Terminus lamps among the blocks** (feel's ask, forwarded to the lead). Terminus has **two** floodlights at r=128
   against pit's **four plus eight 40 m towers inside the fight**, so at his pose the neon bands — now correctly cyan
   and magenta — are still the brightest thing on screen and the vehicles read as dark slabs. **Light the floor; do not
   dim the bands.** Ruled with show: the floor's baseline lighting is **mine** in `terminus.json` (the show *modulates*
   what is already lit; its `pools` channel is not the floor's baseline), so the lamps must be judged **with the show
   off as well as on**, at 21° / FOV 35 / 49 m, and **the vehicles must read without the UI rings.** A frame at that
   pose is the acceptance test.
   **Two constraints found while reading, before any work:** (a) **the lamps go in `tools/make_arenas.py`, not in
   `terminus.json`.** `props` is generated, and only `show` is in `PRESERVED_KEYS` — a lamp hand-added to the JSON is
   silently deleted by the next `make arenas`, which is exactly the Invariant 0 trap this stream spent round 9 removing.
   (b) The current two floodlights are **one** `floodlight(-128, 0)` plus its 180° mirror, i.e. both on the hexagon's
   east/west vertices at r=128, **outside the fight entirely** — so this is not "add more of the same", it is the first
   light inside the block grid. The grid's geometry gives the candidates: a 40 m plaza at the origin, a 20 m avenue up
   the middle between the `x = ±30, z = ±62` blocks, 20 m streets at `x ≈ 60..80` between the `z = 0` blocks, and a
   22 m ring road across each half at `z ≈ 20..42`. Intersections at `(0, 30)` and `(±70, 30)` already carry
   containers, so a lamp there must not fight the clearance check that already refused `z = 84` for a container.
5. **P6 / the navmesh bake radius, pre-registered so the trigger is not invented after the fact.** nav measured that
   **14 of 21 units' avoidance radius `((w+l)/4 + margin)` exceeds `arena.tscn`'s 2.0 m bake** — median **2.50 m**,
   `gang_tank` **4.58 m**, `gang_scout` 1.36 m. Ruled: **the bake stays 2.0 this round** and nav's routing consults each
   hull's shortfall. `arena.tscn`'s bake is mine, so **if the yard/pit fairness runs show the largest hulls wedging in
   alleys, 2.0 is the number that changes — as a baseline move, and not before nav's falsifier reports.** Note for
   whoever reads that result: the **median** unit is already under-served, not just the tail, so wedging would not be a
   rare event.

**An observation from show for the record, not an alarm:** the same 6500 budget buys **68 vehicles at 191k primitives
before CP2 and 64–68 at 145k after** (terminus, `PERF_NAME=show-layer`). **The resize went through simpler meshes, not
more geometry** — the hulls grew in metres while the primitive count fell by a quarter.

### Decided: the Condemned artillery's box binds the DRIVING pose (one number owed)

feel's X4 box-fill sweep found **18 of 19 units pass and one fails for a real reason**:

```
UNIT_BOX_FILL 19 units, worst artillery axis 0 at 38.9%
artillery axis 0: drawn 2.90 m against a 4.74 m box (39% out)
```

**`artillery` is the only unit with an `OutriggerRig`**, whose legs are posed by `set_deployed(ratio)` — 0 stowed for
driving, 1 jacks down — and per `slot_contracts.md` the model's **authored pose is deployed**. So
`SizeLook.box_at_length` measured the union AABB **with the legs down** (4.74 m wide) while `Tank` drives it **stowed
at 2.90 m**. Since **`hull_size` IS the collider**, that artillery drives with a collider **63% wider than the
vehicle you can see**, and shells stop in empty air beside it.

**Ruled (mine — it is my number): the box binds the driving pose.** A collider must match the silhouette that is
being shot at, and this one is stowed every moment it is shot at on the move. The precedent decides it the same way:
the War Rig's jackknife already puts thin geometry outside the box part of the time and the project accepted that. The
alternative pays a real cost during the behaviour that matters to buy correctness for the behaviour that does not.

**A second reason visible only from this stream: the 4.74 m had already propagated.** This brief records "adjacent
columns leave 7.5 − 2×1.5 − 4.74 = −0.24 m for the Condemned artillery's width" as the reason the grid does not hold
the widest hull. At 2.90 m that reads **+1.60 m** and the negative disappears. **The roster's widest hull was an
artefact of a pose**, and it had already reached a second stream's reasoning.

**The number is deliberately NOT typed in yet.** Every width and height here is `box_at_length`'s own output (S1:
*derived, not typed*); hand-entering 2.90 from a message is the exact mirror that drifts the first time the mesh
moves. Sequence: **feel** makes the measurement take the driving pose (stow the legs, or drop `LEG_BOXES` from the
union — their files), then **I** re-run `make roster-scale` and commit the derived box. The length 8.20 m does not
move; only the width and whatever height the legs inflated.

**⚠ That edit moves the sim baseline a SECOND time.** A collider change is a simulation change, and CP2's baseline was
recorded on `main` at the merge. It will need another `sim-baseline-record` from the orchestrator; the commit will say
so rather than let it surface as a mystery red in someone else's check. Both of us are blocked on builder0 being back.

**Why two, and why the obvious one is the wrong one.** A faction army *never stands on the spawn grid*:
`Match.load_doctrine` ends in `ArmyLayout.deploy()`, which re-lays every unit by its own hull size at tick 0,
synchronously, before any physics step. So `arena-series` — the control the brief names, and the one with a recorded
baseline to sit beside — measures whether the **arena** is still fair under the resized roster, and is structurally
blind to the grid. What lives on the grid is what `Match.spawn_tank` puts there and leaves: network players and
legacy bots. So **item 3's answer is the bot series**, which is also verification.md's own prescription
(`--runs 60 --green 2 --rust 2`, with and without `--swap-bases`) and the E0 configuration that recorded **51%**
after the mirrored half-bake retired the 64% south bias (trip-up 21). It is now `make grid-fairness` in `mk/scale.mk`
so it is a command rather than a recollection.

**The baseline `arena-series` is compared against** (arenas.md, 18 pairs, builder0): yard **−0.04 ± 0.05**,
boulevard **+0.01 ± 0.02**, pit **+0.03 ± 0.04**, boneyard **−0.05 ± 0.03**, foundry **−0.00 ± 0.02** — paired south
advantage in surviving share. Same five arenas and `SEEDS=18`, so this is like-for-like rather than a fresh number
with nothing beside it. **The win rate is the wrong instrument here** and is kept only for reference: each team's
army is seeded separately and army strength decides most matches, so a swap flipped the winner in only 5 of 72 runs
in round 5, in both directions. The paired surviving-share margin is the measure.

**A guard the project did not have, and the fairness apparatus rests on it.** Every fairness number ever published
here depends on `--swap-bases` actually moving the teams, and **nothing asserted that it does.**
`tools/arena_series.py:41` checks that the match *reported* `swap_bases`, which is the right guard for "did the flag
reach the run" and blind to the failure that matters more: **if `Match.spawn_position` stopped consulting the flag,
the probe would still report `swap_bases=true` while both arms spawned in identical places** — two identical arms, a
perfectly plausible "no base advantage", and the answer we hope for reached by the treatment never happening. That is
verification.md's broken-comparison table exactly. `test_swapping_the_bases_actually_moves_where_a_team_spawns`
(`tests/test_spawn_grid.gd`) now asserts the **geometry** moves, on **both** paths — the constants *and* every
layout's baked list, because `spawn_position` consults `Arena.spawn_spot` first and a flag honoured by only one of
them is a half-applied treatment — and that swapped Green takes the slot normal Rust stood on. `match_series.py` has
no swap guard of its own, so this test *is* the positive control for the bot series.

### Decided overnight (the lead was asleep; the orchestrator ruled where a ruling was needed)

1. **CP2 lands as it is.** Every hull length is derived from a cited reference vehicle times one factor; nothing was
   tuned to make a number look better. The look was approved on his behalf from `lineup_pose.png`.
2. **K = 14.00 / 19.80 = 0.707071**, anchored on the War Rig at the 14.0 m he ruled, its reference a standard US
   tractor + 42 ft DOT-406 petroleum tanker. If he prefers real metres it is **one constant** — `Units.RIG_LENGTH_M`
   — plus `make roster-scale` and a rewrite of 21 values from the table.
3. **The Syndicate's hover platforms are referenced BY ROLE** (no road ancestry), consistently, stated on every row.
   **`law_tank` is a Centauro B1 8×8 (7.85 m), not a Stryker MGS (6.95 m)** — at 6.95 the Law's *tank* would be
   shorter than its own 6×6 MRAP.
4. **Three files outside this stream were edited**, each granted explicitly and each reviewed by its owner:
   `game/tank/tank.gd` (two silent mirrors that the resize could not land over), and one test each in control's and
   feel's files (size-dependent literals re-timed with the measurement beside them).
5. **A map-widening change (CP2d) was ruled and then withdrawn**, because the measurement behind it was mine and it
   was wrong. See *The maps' corridors vs the roster* below. **The maps are fine.**
6. **Still open for him, nothing blocked on it:** whether the Condemned `artillery` should carry its outriggers in
   its collider at 4.74 m wide (feel's call, round 10, and they have said so for the record), and whether a
   per-hull-class navmesh radius is wanted (nav's, catalogue C2).

### The five-squads failure: diagnosed to the line, and fixed

`test_ai_player_orders::test_five_squads_ordered_in_quick_succession` failed on `4375a9ad` with one unit **104.9 m**
from its slot while the other four squads sat at 3–5 m. **The spawn grid caused it; a respawn is the mechanism; the
test's own missing rule is the defect.** Each step measured, none argued:

1. **Not flaky, not test order.** It fails `--filter=ai_player_orders` **alone**, with Charlie at **104.9 m in
   both** the remote full-suite run and the local filtered one — identical to 0.1 m, while every other squad's
   number moves by ~1 m between the two machines (ordinary glibc drift, trip-up 63). *A value that does not drift
   when everything around it does is not a measurement of a drive.*
2. **The offender moved sideways, not short.** `Green_Charlie_1` went x −18 → **+45**, z 95 → **90**; its five
   squadmates all drove from z = 95 to z ≈ 11–21 as ordered. Invisible until printed, because the test reports the
   per-squad worst gap and the three units *nearest* their slots.
3. **(45, 90) is its OWN spawn slot.** It is the 13th green unit spawned, so slot 12: `SLOT_X[12] = 45.0`, row 0,
   `BASE_Z = 90.0`. Under the old grid that slot is (66, 90).
4. **Reverting ONLY the spawn grid fixes it** — constants *and* the ten baked lists, resized roster left in place:
   4/4 pass, worst gap 7.9 m.
5. **It died and came back.** `Rust_A_1 destroyed Green_Charlie_1`, and at measurement time it is `alive=true`,
   `health 300.0/300.0`, `slot_index=12`, at (45.0, 90.0). **A respawned unit has no order**, so it sits on its
   spawn point.

**Why the old grid passed: luck of geometry.** `elimination` is unset in this test, so the enemy respawns too —
three times in one run. The grid decides where it comes back, the new grid put it somewhere it could reach the
player's line, and it killed a unit. Nothing about a 19-column grid is wrong; **the test was asserting that all 30
units hold their posts while a live enemy respawned beside them for 40 s, and it held by coincidence.**

**The fix is the sibling's rule, not a bigger tolerance.** `test_a_doctrine_army_re_arranges_when_each_squad_is_ordered`
already excludes destroyed units and says why in its own comment: *"skirmish plays to elimination: a destroyed unit
doesn't come back without its orders."* The failing test now connects `Match.tank_destroyed` and excludes them too,
reports the count, **and asserts at most three were destroyed** — so the exclusion can never hide a massacre and
turn a wipe-out into a green run.

### Merging `main` (CP1) — two traps, one of which I walked into

**`git merge main` at `402606ce`.** CP1 (metrics' A12 + the working lint), plus control's facing, nav's
A7/A11/A1/A4 and feel's articulated rig. The roster survived: tank 8.62 m, all 21 carrying a `scale_reference`.

**⚠ MERGE ONLY WHEN NO REMOTE RUN OF YOURS IS IN FLIGHT.** `main` rewrites `tools/remote.sh` and `tools/slot.sh`,
and a wrapper part-way through executing them can read a rewritten script. **I merged with a `roster-lineup`
queued on builder0, so that render is VOID and was killed and re-queued.** Nothing of mine was executing on the
box (it was still waiting for a slot), so there was no orphan to clean up — but that was luck, not care.

**And it is `git merge main`, never `git merge origin/main`:** nothing is pushed tonight, so `origin/main` is
behind and merging it brings nothing, with a clean exit that looks like success.

**THE ONE CONFLICT, and the house rule pointed the wrong way.** `tests/test_fx_light_rounds.gd` collided. The rule
is *the owner's version wins in its paths* — but feel had deliberately **kept the old assertion** and left a
comment saying the replacement was scale's to make inside the CP2 commit, so the two branches would not both edit
the line. **Taking theirs would have shipped a red test**: a window calibrated on a 3.80 m IFV against a hull that
is now 7.54 m. Resolved by combining — feel's note explaining the deferral, my derived window.
**The conflict rule assumes both sides were trying to change the file; it does not cover an owner who has
explicitly deferred.**

### The CP2 check, and four consequences it found in other streams' tests

**Candidate `7542df28`.** The first full check on the merged tree (`e7ebb372`) returned `exited 2`,
`1392 passed, 3 failed`. **All three were real CP2 consequences in other streams' files, none was a flake, and
all three are fixed:**

| test | what CP2 did to it | fix |
|---|---|---|
| `test_ai_player_orders::test_five_squads_ordered_in_quick_succession` | the grid moved where a *respawning enemy* came back, it killed a unit, and a respawned unit has no order | excludes destroyed units, as its sibling already did |
| `test_units_roster::test_v1_armies_are_rejected_with_reasons` | `SPAWN_SLOTS` 52 → 57 makes a full army 12 squads, so a 13th trips `MAX_SQUADS` before the spawn cap | the extra vehicle goes into a squad with room |
| `test_assets_pipeline::test_committed_generated_themes_meet_their_contracts` | feel made the contract read `Units.PROFILES`; the boxes then grew 1.7–2.4× and the committed art "filled 48%" | shape check + faction slots contracted against their **own** unit |
| `test_command_squad_bar::test_contact_pip_when_an_enemy_is_in_sight` | the enemy's 8.62 m hull overlaps a crate, physics shoves it **1.48 m under the floor**, the eye-height ray goes underground | control's: the test picks a spot it can actually see |

**The asset one is the find, and it was not the one anyone was looking for.** feel granted the shape check and
asked me to *check rather than assume* that all 14 art units would then pass. Measured: **against its own box, 0
fail; against the Condemned box, 11 of 14 fail.** `AssetContracts.ROLE_UNITS` mapped every faction's art slot to
the Condemned unit in the same role — a round-3 stand-in whose own comment said *"until factions get catalog
entries of their own"*, which they have had since round 4. **A stand-in is only wrong when the thing it stands in
for differs**, and nothing differed while every hull was 2.8–5.0 m long.

**And it is the round's cleanest composition failure: feel's branch was green because it had the old roster, mine
was green because it had the old contract table. Inertness does not compose, and neither of us could have found
it alone.**

**The contact pip had a detail worth more than the fix:** at the old 3.60 m hull the enemy already overlapped that
crate by **5 cm**. CP2 did not move it from clear to blocked — it moved it from an overlap the solver tolerated to
one the solver resolved by shoving the body through the floor. **A smaller resize, or a different arena, would
have done it eventually.**

**⚠ The re-check found a bug in T1's sharding, not in CP2.** `SHARD 0/2: 645 passed, 0 failed` and
`SHARD 1/2: 750 passed, 0 failed` — **1395 tests, 0 failed** — and then
`test FAILED: 2 of 3 shards reported a summary line`. `mk/core.mk:155` has
`TEST_SHARDS ?= $(shell ...)`: **`?=` is recursively expanded, so the shell re-runs on every reference** — twice to
launch, once to verify — and `slot.sh --jobs` reads free memory, which moves. The run launched 2 and compared
against 3. **Nothing died; the guard fired on itself.** Routed to metrics (their file, one character: `:=`).
Re-running pinned with `TEST_SHARDS=3`. **Until a wrapper line says `exited 0`, this stream's position is that the
run is INCONCLUSIVE, not green** — naming the mechanism is not the same as having the line.

### Where it stands

**Backlog 1, 2, 3, 4 and 5 are complete. CP2 is green, announced, and MERGED. Stretch item 6 is not started.**

**The green line, on `7542df28`, builder0, `TEST_SHARDS=3` pinned:**

```
>> remote: make check TEST_SHARDS=3 exited 2 (build/ copied back)
1395 passed, 0 failed
```

Shards `0/3` 561, `1/3` 440, `2/3` 394 — 69 + 68 + 68 files, 1351 s total. **The sharding labels are right now,
so T1's guard is no longer firing on itself** (the `?=` bug is still metrics' to land; until it does, every sharded
check needs `TEST_SHARDS` pinned explicitly or it launches 2 shards and verifies against 3).

**`exited 2` is one target, and it is the pre-registered one.** `determinism passed`; the whole log greps clean for
`FAILED`/`Error`/`***` except:

```
sim-baseline FAILED: expected d4c049819a5833d3 for glibc-2.43, got bdf1686a0ce5a750
```

**The sim baseline moves and is deliberately NOT recorded here** (Invariant 2). CP2 rewrites all 21 colliders and
the spawn grid, and colliders and spawn positions *are* the simulation, so a moved hash is the consequence, not a
regression. The orchestrator recorded it on `main` with the merge — and flagged that the recorded value will differ
from `bdf1686a0ce5a750` because combat's timer retirement is in that tree too, which is why a stream must not
record it from its own branch.

The branch tip at announcement was `ddb16592`, Status-only: `git diff --stat 7542df28 ddb16592` is one file,
`_agents/streams/scale.md`, +38 lines. Same code tree, so the hash stood.

**The merge's one composition test, and it passed on real data.** `main` brought a new top-level key into
`arenas/yard.json` and `arenas/terminus.json`: **`show`** (98 and 58 lines of another stream's lighting). Both of my
arena contracts had to accept it or CP2 and that work would have been mutually destructive — `Arena.validate()`
rejects unknown top-level keys, so the layouts would have refused to load, and `tools/make_arenas.py` rewrites these
files, so a regeneration would have silently deleted the lighting. Checked rather than assumed, on the merged tree:

```
ARENA_KEPT yard: show (authored beside the generator, not by it)
ARENA_KEPT terminus: show (authored beside the generator, not by it)
```

and `git diff --stat -- arenas/` after a full `python3 tools/make_arenas.py arenas` is **empty** — the generator
reproduces all ten layouts byte-for-byte, lighting intact. This is the *good* outcome of the hazard that produced
this round's asset-contract failure: `show` was in `LAYOUT_KEYS` and in `PRESERVED_KEYS` **before** there was
anything to preserve, so the two streams composed instead of colliding. **The contract was written for a key that did
not exist yet, and that is the only reason this cost nothing.**

**Merged to `main` by the orchestrator** at `86463527` ("Merge stream/scale at ddb16592 (CP2, checked at
7542df28)"), then `git merge main` back into this branch to run the post-merge controls on the tree that actually
ships. No remote run of mine was in flight at either merge (checked, not assumed — see the trap below).

### The plan, in the order it was worked

1. the reference table, derived and asserted (S1) — **done**, `b7055602`
2. apply it, and render the frame the lead judges — **done**; numbers in `b7055602`, frames rendered at `0e809a09`
   and **sent** (the CP2 gate), three cosmetic defects named below rather than hidden
3. the spawn grid, from the roster's largest hull — **done**, `eecc940b` and its predecessors
4. clearance for the new roster (P6), then **CP2 announced** — **done**, green on `7542df28`, merged at `86463527`
5. **A3** hull-chord cover over directional summed-area tables — **done**, built to combat's spec
6. stretch: the 9/20 → 0/20 re-measured — **not started**; the post-merge fairness control comes first (below)

**Post-merge, in flight or owed:** the swap-bases fairness control on the merged tree (the orchestrator's 08:0x
request — running), then the factions re-render, then item 6.

### 1. The reference table (S1) — done

**K is fixed: `Units.SCALE_K` = 14.00 / 19.80 = 0.707071.** The anchor is `gang_tank` at the 14.0 m the lead ruled;
its reference is a standard US tractor + 42 ft DOT-406 petroleum tanker semi-trailer at **19.80 m** (65 ft, the
standard legal configuration), so the world is drawn at **70.7% of real size** — inside the 0.67–0.78 the
orchestrator expected. `SCALE_K` is *derived*, never typed: `Units._derive_scale_k()` reads the rig's
`scale_reference` and returns `NAN` loudly if it is ever removed, so every derived length fails rather than
defaulting to something plausible.

`make roster-scale` prints the whole table (reference vehicle, cited source, K, target length, box today, the
mesh's box, MISMATCH). Hull length in metres, today → new:

| faction | unit | today | new | reference vehicle |
|---|---|---|---|---|
| condemned | scout | 3.00 | **3.04** | Dakar-class rally-raid buggy (Prodrive Hunter T1+), 4.30 m |
| condemned | tank | 3.60 | **8.62** | Type D school bus, 40 ft (Blue Bird All American), 12.19 m — *the lead's own example* |
| condemned | ifv | 3.80 | **7.54** | Type C school / prisoner-transport bus, 35 ft, 10.67 m |
| condemned | artillery | 4.00 | **8.20** | four-axle all-terrain crane carrier (Liebherr LTM 1070-4.2), 11.60 m — *width re-derived 4.74 → 2.90 in the driving pose* |
| condemned | lancer | 3.80 | **6.46** | utility line truck, 30 ft (International 4300 + Altec boom), 9.14 m |
| condemned | burner | 3.80 | **6.89** | pumper fire engine, 32 ft (Pierce Enforcer), 9.75 m |
| gangs | gang_scout | 2.80 | **2.93** | 1932 Ford Model B hot rod, 4.14 m |
| gangs | gang_ifv | 3.60 | **3.44** | 1955 Chevrolet 3100 half-ton pickup, 4.87 m |
| gangs | gang_tank | 14.00 | **14.00** | tractor + 42 ft DOT-406 tanker semi-trailer, 19.80 m — **the anchor** |
| gangs | gang_artillery | 4.20 | **6.89** | heavy-duty tow wrecker on a 6x4 chassis, 9.75 m |
| gangs | gang_support | 7.00 | **6.58** | rigid 3,000 gal fuel bowser (Freightliner M2 106), 9.30 m |
| law | law_scout | 3.40 | **3.80** | Ford Crown Victoria Police Interceptor, 5.38 m |
| law | law_ifv | 4.20 | **5.01** | Force Protection Cougar 6x6 MRAP, 7.08 m |
| law | law_tank | 4.60 | **5.55** | Centauro B1 8x8 assault gun (hull, gun excluded), 7.85 m |
| law | law_artillery | 4.40 | **4.95** | M142 HIMARS on an FMTV 6x6 chassis, 7.00 m |
| law | law_suppressor | 4.40 | **6.86** | riot-control water cannon (Wasserwerfer 10000, MAN 6x6), 9.70 m |
| syndicate | syn_scout | 3.20 | **4.04** | *by role*: wheeled recon vehicle, Fennek LGS, 5.71 m |
| syndicate | syn_ifv | 4.60 | **4.63** | *by role*: infantry fighting vehicle, CV90 hull, 6.55 m |
| syndicate | syn_tank | 5.00 | **5.44** | *by role*: main battle tank hull, Leopard 2A7, gun excluded, 7.70 m |
| syndicate | syn_artillery | 4.40 | **4.93** | *by role*: rocket artillery, M270 MLRS, 6.97 m |
| syndicate | syn_lancer | 4.40 | **4.04** | *by role*: sensor/designator vehicle, Fennek with the BAA mast, 5.71 m |

**The two judgment calls, both put to the orchestrator and both approved (2026-09-20):**
- **The Syndicate hover platforms have no road ancestry** — game_design.md names them by shape (teardrop, supercar,
  limousine), not by a vehicle they were converted from — so each is referenced to the real vehicle that fills the
  **same role**, consistently across the faction, and every row says so in its own `scale_reference.vehicle`.
- **`law_tank` is the Centauro B1 8x8 (7.85 m), not the Stryker MGS (6.95 m).** game_design.md says "Stryker-style",
  but at 6.95 m the Law's *tank* would be **shorter than its own Cougar 6x6 MRAP** (7.08 m). The blurb is "an 8x8
  with a real gun", which is what a Centauro is.

**The spread the lead asked for now exists.** Before: two vehicles over 5 m and nineteen between 2.8 and 5.0. After:
**2.93 m to 14.0 m with the middle filled in** — a school bus is 8.6 m next to a 2.9 m hot rod and a 14 m semi.

### 2. The numbers applied — done, and two mirrors had to go first

Widths and heights are now **the approved mesh's own proportions at the derived length** (`SizeLook.box_at_length`),
so `hull_size` is what is drawn. That discharges feel's round-8 roster-wide finding **by construction**.

**Recorded "before" (`9f864474`, laptop), so the treatment is known to be distinguishable (lesson 147):** running
the new tests against HEAD's numbers with the references in place failed **20 of 21** on length (only `gang_tank`,
the anchor, passed) and **17 of 19** on the box (only `gang_tank` and `gang_support`, which round 8 had already
fixed), by up to **106%** on an axis — `syn_artillery` was 2.60 m wide against its mesh's 3.64 m.

⚠ **I EDITED `game/tank/tank.gd`, which is not this stream's file** (granted retroactively by the orchestrator;
combat has seen the detail and does not object; combat reviews it at CP2). Two mirrors, both the silent kind, and
the resize could not land over either:

- **`Tank._apply_hull_size` returned early whenever a unit's box equalled `Units.PROFILES[DEFAULT].hull_size`.**
  `DEFAULT` *is* `"tank"`, so that branch fired for the Condemned tank and for nothing else: its collider came from
  `tank.tscn`'s authored `BoxShape3D` (2.4 x **1.6** x 3.6) while the catalog has said 2.4 x **2.4** x 3.6 since
  round 2. **The scene silently WON for the one unit `sim-baseline` fields** (lesson 137), and no edit to
  `hull_size` would have moved it — the lead's bus-tanks would simply not have resized.
- **The shared hull art was fitted against that same catalog entry rather than against the mesh it draws**
  (2.18 x 2.30 x 3.85 m). The moment the Condemned tank stopped being 3.6 m long, every unit without its own art
  would have been drawn at the wrong size, in silence. Measured on the reverted code: a 6.89 m box drew **2.88 m**.

**Consequence to expect, named so nobody re-derives it: the Condemned tank's collider grows 0.8 m in height.** That
is a correctness fix, not a tune, and it is a real combat change (a taller target). combat has already flagged that
`scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` reads that hull's hit distribution with six hits of
margin, and **expects it to move** — so that when it does, nobody attributes it to A2 or A7.

Both mirrors now have a regression test, each mutation-checked by surgically restoring the old behaviour and
watching it go red: `test_the_default_units_collider_comes_from_the_catalog_not_from_the_scene` and
`test_a_unit_wearing_the_shared_hull_art_is_drawn_at_its_own_box` (`tests/test_units_scale.gd`).

**Muzzles came down roster-wide.** The shortest hull is now the Rat Rod's own mesh at **1.24 m** instead of a
hand-held 1.40 m floor, so the ceiling (`MUZZLE_CLEARANCE` under the shortest hull) fell **1.30 → 1.14 m** and the
**18 muzzles above it came down to it**. Rounds fly flat at muzzle height, so this is a real ballistic change and
it is pre-registered, not incidental.

**THE SIM BASELINE MOVES and is deliberately NOT recorded here** (Invariant 2). On the laptop `sim-baseline`
silently skips — glibc 2.39 has no line — so a green local check proves nothing about the hash.

### 2b. The frame the lead judges — RENDERED AND SENT

`make roster-lineup` (builder0, 1920x1080, commit `0e809a09`). Three frames in `build/roster-lineup/`:

| frame | what it answers |
|---|---|
| **`lineup_pose.png`** | **HIS pose** (21°, 49 m, FOV 35 — the same one round 8 shot the rig at) over the size spread. The one to look at. |
| `lineup_factions.png` | four rows, one per faction, each sorted by length: is each faction's roster sensible? |
| `lineup_row.png` | all 21 in one row, the Condemned tank and the War Rig as the bookends the round is anchored on |

**What `lineup_pose.png` shows, left to right:** Rat Rod **2.9 m**, Pursuit Cruiser 3.8, Gun Truck 3.4, Railgun
Platform 5.4, Condemned Tank **8.6**, War Rig **14.0**. A semi looks like a semi next to a car, and the bus-tank he
named reads as a bus rather than a dozer.

**On screen at his camera, against round 8's numbers:** the rig **734 × 279 px**, the Condemned tank **281 × 135**.
Round 8 measured that tank at **199 × 100** — so it grew by half again while the rig kept its dominance. (Round 8's
rig was 721 × 315 at a slightly different framing; the rig's own box did not change.)

**Two cosmetic defects, named rather than hidden:** `lineup_pose.png` clips the Rat Rod slightly at the left edge,
and `lineup_factions.png` clips the Condemned row at both edges — the near row is the widest at 55.7 m and the fit
was computed on the focus plane rather than the near row's, so perspective pushes it past the frame. Labels still
overlap in the two dense back rows. One more render fixes all three; not queued, because the frames are usable and
CP2 is gated on the frame being *sent*.

**It took three renders, and the first two were the interesting part.** Both were unusable: the HUD covered a third
of the image and order beams washed out the labels. The cause was not the layout — `_quieten()` read `Main.hud` and
tested `hud is CanvasItem`, and **`Hud extends CanvasLayer`, which is not a CanvasItem**, so the test was quietly
false and nothing was hidden. It now finds every CanvasLayer by class and hides both marker drawers (feel's
`FxWorld.order_feedback` and control's `SelectionMarkers`), and prints
`SIZE_LOOK_QUIET 1 canvas layers, 2 marker layers` so a future silent no is visible. **A capability test that
silently means "no" is the same shape as every mirror this stream found this round.**

### 3. The spawn grid — done, and it needed less than the brief expected

**Test first, and the first thing the tests established is what the grid actually has to hold.** `ArmyLayout.deploy()`
re-lays every unit by its own hull size at the end of `Match.load_doctrine`, **synchronously, before any physics
step**, so a doctrine army never stands on this grid. What stays here is what `Match.spawn_tank` puts here and
leaves: network players and legacy bots, driving `Units.DEFAULT`. That was combat's round-8 finding, carried as a
comment; it is now a guard —
`test_a_doctrine_army_is_never_left_standing_on_the_grid` spawns a real gangs and a real Condemned army at
`Units.BASELINE_BUDGET` and asserts no two hulls overlap at tick 0.

**What changed:** `Units.DEFAULT` went 3.6 → 8.62 m, longer than the old 8 m rows, and combat's existing
`test_the_spawn_grid_holds_the_unit_a_bare_spawn_drives` went red on it. There is nowhere deeper to go (the back
row was already at z = 114 against `DRIVABLE_LIMIT` 116), so the grid became **shallower and wider**:

| | before | after |
|---|---|---|
| `SLOT_X` | 13 columns, 11 m pitch, ±66 m | **19 columns, 7.5 m pitch, ±67.5 m** |
| `SPAWN_ROWS` × `SPAWN_ROW_SPACING` | 4 × 8.0 m (z = 90, 98, 106, 114) | **3 × 12.0 m (z = 90, 102, 114)** |
| `SPAWN_SLOTS` | 52 | **57** (`Army.MAX_ARMY_UNITS` is 45) |
| jitter x / z | ±3.5 / ±1.2 m | **±1.5 / ±0.6 m** |

**The front row stays at `BASE_Z` = 90 and the back row stays at z = 114, so spawn distance, depth and pace are
unchanged.** The jitter fell out of the pitch: column pitch and row spacing, each minus the bare-spawn hull
(2.40 × 8.62 m) and minus squad's `ArmyLayout.HULL_CLEAR_M` (2.0), halved. A doctrine army's scatter is unaffected
(`ArmyLayout` lays it out itself).

**Why ±67.5 and not wider:** `make arenas` **refused ±72 m**. The Terminus has an ad screen at (76, 100) and a
column at 72 stood 1.3 m from its footprint against a required 4.3. The authoring check earned its place.

**For the record and deliberately NOT asserted** (Invariant 0b — a check must not encode a decision nobody has
made): at the round-9 roster the grid does **not** hold the biggest hull. Adjacent columns leave
7.5 − 2×1.5 − 4.74 = **−0.24 m** for the Condemned artillery's width; adjacent rows leave 12.0 − 2×0.6 − 14.0 =
**−3.2 m** for the War Rig's length. Both are harmless *because* of `deploy()`, and both become findings the day
`deploy()` stops running first — which is exactly what the new guard watches.

**Three mirrors killed on the way**, all of them in this stream's paths and all three mutation-checked:

1. **`tools/make_arenas.py` carried its own copy of `SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING`** behind a comment
   saying *"must mirror"*. It is the worst row in Invariant 0's table because **the copy WON** — `Arena.spawn_spot`
   is consulted before the constants, so the baked lists beat them. It now READS them
   (`tools/gdscript_source.py`), and `test_every_layouts_baked_spawn_list_is_the_grid_the_constants_describe`
   checks every shipped map against the constants. **That guard was green by absence when first written**
   (`Arena.load_layout` returns `{"layout": …}`, not the layout, so it was comparing the constants with
   themselves); it was caught by mutation-checking it, and it fires now.
2. **`make_arenas.check_spawn_clearance(layout, clearance=6.0)`** mirrored `Arena.SPAWN_CLEARANCE`, which is
   `Match.SPAWN_JITTER_MAX_X + 2.5`. The margin is now a named constant (`Arena.SPAWN_CLEARANCE_MARGIN`) and the
   tool reads **both halves** from where they are defined.
3. **`arena_report.py` sliced `layout["spawns"]["rust"][:13]`** in two places — 13 being `Match.SLOT_X.size()` at
   the time, a mirror hidden in a slice with nothing naming it. At 19 columns the slice quietly took two thirds of
   the front row, and the only symptom was the route optimiser's monotonicity test wobbling by 0.001. It reads the
   front row off the points now (`arena_report.front_row`).

**All ten layouts regenerated** (`make arenas`); `make arena-test` 75/75, `tools/test_arena*.py` 19/19,
`--filter=match` 72/72, all on the laptop.

### 4. Clearance for the new roster (P6) — measured

`make nav-maze NAV_UNITS=30 ARENA=maze NAV_TIME=180 SEED=1 NAV_BOTH=1`, builder0, same seed both arms, 30 units
head-on through the maze's defile. The probe spawns `Units.DEFAULT` — the Condemned `tank` — so this is the unit
that went **3.60 → 8.62 m**.

| | BEFORE (`9f864474`) | AFTER (`97b383eb`) | × |
|---|---|---|---|
| arrived | 30 / 30 | 30 / 30 | 1.00 |
| off_navmesh | 0 | 0 | — |
| t50 | 78.03 s | 120.17 s | 1.54 |
| t90 | 95.73 s | 159.40 s | 1.67 |
| **t100** | **104.10 s** | **165.87 s** | **1.59** |
| **stuck_events** | **341** | **678** | **1.99** |
| crawl | 319.2 unit-s (0.133) | 675.3 unit-s (0.185) | 2.12 |
| no_progress | 859.9 unit-s (0.359) | 1682.4 unit-s (0.462) | 1.96 |
| **oscillating** | **10.5 unit-s (0.004), 14 units** | **132.3 unit-s (0.036), 27 units** | **12.60** |
| distance travelled | 11785.3 m | 11636.9 m | 0.99 |
| progress made | 5837.2 m | 5650.1 m | 0.97 |

**Nobody fails to arrive, and nobody is pushed off the navmesh.** What changes is how long it takes and how much
of it is spent stopped: **the same ground covered** (distance ×0.99, progress ×0.97) in **59% more time**, with
**twice the stuck events** and **twelve times the oscillating seconds**, spread over 27 of 30 units instead of 14.

**⚠ THE CONFOUND, named rather than buried: the two arms differ by more than hull length.** The "before" arm is
`main`'s tree, which the brief asked for — so it also carries the **old spawn grid** (4 rows of 13 vs 3 rows of
19) and the old baked spawn lists. `maze_probe` spawns through that grid and orders each unit to the 180° mirror
of **its own spawn point**, so the two arms start in different places and drive to different goals. The result is
real and it is large, but **it is not attributable to hull length alone from these two runs.** A third arm with
only `units.gd` and `tank.gd` reverted — the new grid, the old roster — isolates it, costs one builder0 slot, and
is queued behind the CP2 check.

**No conclusion about the mechanism from me** (nav's request, and their three pre-registered hypotheses for the
defile are all dead). What I will say is what the numbers say: the pathology is **time and stopping**, not
reachability.

### 5. A3: hull-chord cover over directional summed-area tables — done

**REPLACES centre-point cover registration** (Invariant 0c: a brief that adopts a catalogue row must name what it
replaces). `Arena.cover_fraction(viewer, point, heading, length)` returns the fraction of a hull's own centreline
chord occluded from a watcher — combat's signature, taken as they specced it, heading as a flat `Vector3` because
every caller already holds a forward vector. Two array lookups and a subtraction, the same work at 2.93 m and at
14.0 m, integer arithmetic throughout (`game/arena/cover_tables.gd`).

**Positive control first, before any code** (lesson 147). `make arena-report` on the resized roster reproduces
round 8's step exactly — share of the field within 45 m of a prop long enough for the hull (laptop, pure Python):

| hull | 2.93 | 5.0 | 6.0 | 7.0 | 8.62 | 12.0 | **12.19** | **12.5** | 14.0 |
|---|---|---|---|---|---|---|---|---|---|
| yard | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 | **0.99** | **0.00** | 0.00 |
| pit | 0.85 | 0.85 | 0.85 | 0.48 | 0.46 | 0.46 | **0.46** | **0.00** | 0.00 |
| terminus | 0.98 | 0.98 | 0.98 | 0.95 | 0.91 | 0.91 | **0.91** | 0.91 | 0.91 |

**And the resize is what makes A3 stop being a rig-only fix:** pit's score already halves at **7.0 m**
(0.85 → 0.48), and five units are now over 7 m where one was.

**The falsifier is met.** Mean occluded chord fraction over the contested field, watcher on the far side, under the
new query (laptop, this commit):

| hull | 2.93 | 6.0 | 8.62 | 12.0 | 12.19 | 12.5 | 14.0 | spread |
|---|---|---|---|---|---|---|---|---|
| yard | 0.320 | 0.292 | 0.291 | 0.288 | 0.288 | 0.288 | **0.287** | 0.033 |
| pit | 0.31 | 0.38 | 0.34 | 0.36 | 0.36 | 0.36 | **0.36** | — |
| terminus | 0.76 | 0.76 | 0.77 | 0.77 | 0.77 | 0.77 | **0.77** | — |

**Flat.** Where the old rule put yard at 0.99 and then 0.00, the new one puts a 14 m hull within **0.03** of a 12 m
one. `make arena-cover` prints it; `tests/test_arena_cover_tables.gd` asserts it on every shipped map (8 tests) and
**carries the old rule in the same file as the positive control**, so the thing being replaced stays checkable.

**What it costs, reported as two terms because they behave oppositely** (`CoverTables.worst_case_error`): an
**angular** term, `1 − cos(22.5°) ≈ 7.6%` of hull length, constant as a *fraction*; and a **grid** term of one 2 m
cell, constant in *metres*. So the query is **least precise on the shortest hull, not the longest** — the opposite
of the intuition, and combat has said this inverts where they were going to set `hull_hidden`'s threshold.

**One defect found by writing that error report.** The first chord discretisation was
`floor(length / 2 / cell) * 2 + 1`, which collapses every hull shorter than twice the cell to a **single cell** —
i.e. the centre-point query, under a new name, for the Rat Rod and the whole light end of the roster. It is
`max(1, round(length / cell))` now. **A row that replaces a point sample can reintroduce it by arithmetic**, and
only stating the error term out loud caught it.

**`make arena-report`'s WATCH line changed in the same commit as the tables**, as the lead's ruling requires. It no
longer says *"NOTHING on this map can hide the longest hull"* — true under the old definition, **false** under the
new one, and a WATCH line that is confidently wrong is worse than silence. It now names the definition that
produced the number, says it is superseded, and points at `make arena-cover`. The point sample is still **printed
beside** the chord figure for one round (lesson 49) and `hull_cover.definition` says so in the JSON. arena's own
guard against a dead WATCH line keyed on the exact phrase, so it was rewritten to key on the reach reaching the
reader rather than on a form of words.

**⚠ HALF OF A3'S PRE-REGISTERED FALSIFIER IS NOT ACHIEVABLE AS WRITTEN, and it is recorded here rather than
discovered when someone quotes A3 as met** (combat spotted it from the error numbers; the reading is theirs):

- **The half that passed cleanly** is the pathology A3 was adopted for: the 12.19 m step is gone, yard's 14 m
  figure is within 0.03 of its 12 m one against a pre-registered 0.1, and the spread across 2.93–14.0 m is 0.033.
- **The half that cannot pass** is *"exposed hull fraction … below 5% at **every** hull length 2.8–14.0 m"*. At
  2.93 m the worst-case error is **0.759**, because the grid term is a constant 2 m against a hull that is one to
  two cells long: the query cannot distinguish 5% exposure from 50% there. **No threshold fixes that — it is the
  resolution, not the calibration.**
- **The honest statement for the round, which is combat's wording:** *A3 fixes cover for hulls long enough to be
  resolved by the grid, and leaves short hulls where they already were.* It does not make the short end worse — at
  2.93 m it degrades gracefully to roughly the point sample we already had. **The catalogue over-promised the
  range; it did not over-promise the mechanism.**
- **Open, with numbers:** the grid term is exactly the cell size. At 1.0 m cells the Rat Rod's grid error falls
  0.683 → 0.341, at 0.5 m → 0.171. That is 4× and 16× the table memory and build time. Affordability is being
  measured (`tests/scale/cover_bench.gd`); if 1.0 m is cheap it is worth having, because the units that hide for a
  living are the light ones and that is the length the query is currently blindest at. If it is not, the range
  limit goes into `hull_hidden`'s threshold and into `_agents/balance.md` as a known bound rather than a bug.

**Not answered yet, deliberately:** combat's optional second entry point `hull_footprint_clearance(point, heading,
length)`. A prefix sum of occlusion along a heading is not a distance transform, so it is not obviously free from
these tables. I will say yes or no with a reason rather than half-build it; combat keeps the point sample and
renames it honestly in the meantime.

### The maps' corridors vs the roster — and ⚠ a wrong measurement I circulated and retracted

**THE ANSWER: the maps are fine.** Perpendicular free span across the base-to-base route, against the roster's
widest hull (the Condemned `artillery`, 4.74 m with its outriggers deployed). `make arena-report`, laptop, static
geometry, machine-independent:

| map | tightest | slack | hulls passing with 1 m spare |
|---|---|---|---|
| foundry / furnace | 62.50 m | +57.76 | 21/21 |
| boulevard | 59.00 m | +54.26 | 21/21 |
| boneyard | 27.00 m | +22.26 | 21/21 |
| pit | 19.00 m | +14.26 | 21/21 |
| yard | 18.00 m | +13.26 | 21/21 |
| scrapyard | 17.50 m | +12.76 | 21/21 |
| terminus | 11.50 m | +6.76 | 21/21 |
| maze | 7.00 m | +2.26 | 21/21 |
| **barriers** | **5.50 m** | **+0.76** | **20/21** |

**The measure validates itself against the authored geometry:** it reports the maze's tightest point as exactly
**7.00 m**, and `tools/make_arenas.py` authors `MAZE_TIGHT_GAP = 7.0`. `barriers` is the only WATCH, it is 0.76 m
of slack for the single widest hull, and it is not in `Arena.ROTATION`.

**So squad's maze result is entirely the navmesh question, not a map question.** 7.0 m of physical gap minus
`NAV_AGENT_RADIUS` 2.0 m each side leaves 5.0 m of navigable corridor for a 4.74 m hull — 13 cm a side. nav's,
with squad's reproduction.

#### ⚠ The first version of this measurement was wrong, and I circulated it

**It reported that 8 of 10 maps had a tightest point NARROWER than the widest hull.** It went to the orchestrator,
squad and nav, and it produced a ruling to widen the kit's gaps (CP2d) before I caught it. Withdrawn; the ruling is
withdrawn too (lesson 162).

**What was wrong:** the function returned **twice the distance to the nearest obstacle**. That is the corridor
width only when something blocks **both** sides. Where a route passes close to a *single* prop with open ground
beyond, it means nothing. On yard, at the exact point I reported as 4.72 m:

```
nearest tall props to (4, 66):   2.71 m wreck at (9, 68);  the next is 11.78 m away
free span across the route:      20.0 m one way, 3.0 m the other  ->  about 23 m
```

**I reported 4.72 m where there are 23**, and the corrected measure puts yard at 18.00 m.

**The lesson, which is worth more than the number was:**
- **A measure that flags EVERY map is usually measuring the wrong thing.** It was plausible on all ten, and
  plausibility on all ten is the tell.
- **I circulated ten numbers without sanity-checking one against the world.** One `print` of the nearest props at
  one reported pinch would have ended it. And **there was a free positive control available all along** — the maze's
  authored `MAZE_TIGHT_GAP = 7.0` — which the wrong version missed by 2.6 m and the right one hits exactly.
- **I wrote the WATCH line's prose as if the quantity were established** (*"only 19 of 21 hulls pass there"*), which
  made a wrong number legible and quotable. **It is the same failure shape this stream spent the round finding in
  other people's code — the thing under test quietly not being the thing described — and `arena_report` has now had
  two of mine in one night: the `[:13]` slice I fixed, and this one I introduced.**

`corridor_widths()`'s docstring carries the wrong version's history, so the next person to touch it knows what it
looked like when it lied.

### Decisions (with reasons)

- **The two units with no `unit.<id>.hull` art** — `tank` and `burner`, wearing the shared dozer — **take a length
  from the rule and keep the width and height the catalog already had.** Nothing has measured a proportion for
  them and inventing one is opinion, not sizing. `Tank` stretches the shared art to the box on every axis, so what
  is drawn still matches `hull_size`. `test_only_the_two_known_units_have_no_art_of_their_own` pins the list in
  both directions.
- **Appendages are inside the box, because the rule says the box is what is drawn.** Three units grew far more on
  a cross-axis than in length, and they are the art's own proportions, not a choice: `law_suppressor` is now
  **6.18 m tall** (the horn tower really is about as tall as that truck is long in the approved concept), the
  Condemned `artillery` is **4.74 m wide** (deployed outriggers) and `syn_artillery` **4.07 m wide** (missile
  wings). They are flagged here and they are what the lead will see in the line-up. Trimming them would be sizing
  by opinion, which the rule forbids; if anyone wants appendages excluded from the collider that is an extension of
  `FactionArt.GUN_CUTS` and it is feel's, next round.
- **Muzzles: `min(today's, ceiling)`, not scaled.** No muzzle in the catalog was ever measured from a mesh (they
  are 1.05 / 1.12 / 1.20 / 1.27, i.e. a shared barrel height), so there is nothing to re-derive per unit; the only
  real constraint is the roster-wide ceiling, and every muzzle above it came down to it.
- **`tools/gdscript_source.py` is the one Python reader for GDScript constants**, with `units_catalog.py` a thin
  facade over it. Three tools were about to grow three regexes.

### Questions for the lead

- **None blocking.** The one open question — rig-relative K vs real metres — is the orchestrator's to carry. It is
  now genuinely one number: `Units.RIG_LENGTH_M` 14.0 → 19.80 in `units.gd`, then `make roster-scale` and rewrite
  the 21 `hull_size` values from the table. Everything else re-derives.
- **The look** (backlog item 2) is his, and CP2 waits for the frame to be *sent*, not approved.

### Owed after the CP2 hash (not started)

**feel's floodlight request, diagnosed with counts, and it is in this stream's paths** (`arenas/terminus.json` via
`tools/make_arenas.py`). **Its own commit AFTER CP2**, because it changes a rotation map.

- **The Terminus is the only arena with `block` props** — eight 40 m towers *inside* the fight, at r = 40 and
  r = 69 — and it carries **half pit's floodlights at the same arena size**, both sets out at **r = 128 on the
  centre line**. So the venue got brighter and the floor did not.
- That asymmetry is **the whole of show's 22-of-30 "band brighter than ring" result.**
- **The fix is two more floodlights AT THE STREET INTERSECTIONS among the blocks, where the fight is** — not more
  at the perimeter, which is what made the ring bright in the first place.
- **feel deliberately did not compensate in its own materials**: one owner of arena brightness, and it is the
  layout. That is the right call and it is why this lands here rather than there.
- **Measure with show's frame gate (ring vs band, with a no-show arm) before and after.** If the light bodies turn
  out to be geometry rather than pure lighting, it needs the swap-bases fairness control too; if they are not, it
  needs none.

### Requests to other streams

- **combat** — reviews the `units.gd` / `match.gd` / `tank.gd` diff at merge (already briefed, no objection).
  Expect `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` to move: that hull's collider is 0.8 m taller.
- **combat, A3 consumer spec received (2026-09-20)** and it is what item 5 will be built to:
  `cover_fraction(viewer: Vector3, point: Vector3, heading: Vector3, length: float) -> float` — heading as a flat
  `Vector3`, not radians; the worst-case quantisation error at K = 8 headings reported **as a fraction of hull
  length**; determinism asserted in a test (integer prefix sums, no float reduction order); `0.0` rather than
  garbage, and no error spam, when the hull straddles a table edge or leaves the arena. Second, cheaper-if-free
  entry point: `hull_footprint_clearance(point, heading, length) -> float`. Combat also reports that
  `EngagementStats.near_cover` **has never measured cover** — it measures proximity to an obstacle footprint — and
  owns renaming it; the viewer question is theirs, the hull-aware primitive is mine.
- **feel** — `assets/pipeline/asset_contracts.gd` `UNITS` carries its own copy of `hull_size` and `muzzle_height`
  for five units and **already disagreed** with the catalog before this round (it has `tank` h = 1.6). It is the art
  pipeline's normalization contract, so it is inert for gameplay, but **any new art generated after CP2 would be
  normalized to the old 3.6–4.0 m sizes**, and no test ties it to `Units.PROFILES`, so nothing will say so. Routed
  via the orchestrator.
- **squad** — formation and assembly spacing re-measure after CP2. `army_layout.gd` reads `hull_size` and the
  roster's widest hull is now **4.74 m** and longest **14.0 m**; `deep_floor = longest + HULL_CLEAR_M` will grow.
- **nav** — `Movement.NAV_AGENT_RADIUS` still mirrors the bake at 2.0 m for a footprint range that has grown.
  Proposal unchanged: read it from `Arena`. Numbers come with item 4.
- **control** — the camera, HUD, selection boxes and radar at his pose against the new sizes, after CP2.

### Known issues

- **`make check` has not yet gone green on builder0 for this branch.** A full `make remote T=check` on `b7055602`
  (the roster resize, before the spawn-grid commit) was still running when this Status was written. **No readiness
  claim is made until the wrapper's own `>> remote: make check exited <N>` line and the runner's
  `N passed, 0 failed` say so, unpiped** (lesson 28).
- The line-up frame is built (`make roster-lineup`, three frames) but **not rendered**: it needs a display, so it
  needs builder0, and this worktree already has a `make remote` in flight (trip-up 66).

### What to playtest (exact commands)

```
make roster-scale                         # the table: reference vehicle, K, target length, box, mesh box
make remote T=roster-lineup               # the three line-up frames -> build/roster-lineup/lineup_*.png
make remote T=facing-audit                # every unit side-on at the new scale -> build/facing/<unit>.png
make skirmish --player-faction=condemned  # the bus-tanks, at his camera
```

### Merge notes (shared-file edits)

- **`game/tank/tank.gd`** — `_apply_hull_size` only (the early return removed; the shared-art fit now reads the
  mesh) plus the new `Tank.shared_hull_size()`. Not this stream's file; granted, and combat reviews it.
- **`game/units/units.gd`** — the carved-out keys only: `hull_size` and `muzzle_height` values, the new
  `scale_reference` key on all 21 profiles, `RIG_UNIT` / `RIG_LENGTH_M` / `SCALE_K` / `_derive_scale_k` /
  `target_length_m`, and the schema comment. **No costs, speeds, armor, weapons or turn rates were touched.**
- **`game/match/match.gd`** — the three spawn constants and the two jitter bounds they derive, in one commit, with
  the derivation written beside them. Nothing else.
- **`game/arena/arena.gd`** — `SPAWN_CLEARANCE_MARGIN` extracted so `make_arenas.py` can read it. This stream's file.
- **`game/theme/fx/bench/size_look.gd`** — additive `--size-look-lineup` mode (granted at launch; feel reviews).
- **`arenas/*.json`** — all ten regenerated by `make arenas`; only the `spawns` lists changed.

