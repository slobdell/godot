# Stream: cover (hull-down behind real low cover)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, CP37.1,
> C37.3, C37.4) and `_agents/game_design.md` *OPEN QUESTIONS for him before round 37* (his answers to 3, 6, 9, 11). **You own:**
> `game/ai/cover_map.gd`, `game/ai/tactical_query.gd`, the partial-cover damage seam (one function in `game/combat/armor.gd` called
> from `Match.projectile_impact`; merge note to rules, who own the rest of combat), `arenas/*.json` (low cover only, C37.3),
> `tests/cover/**`, `tests/test_cover*.gd`, `mk/cover.mk`. C++ twins are native's (`cover_native`; you declare, native writes).
> **Model:** Opus. **Machine:** builder2 for series (shared queue: say in Status when you start/finish); light runs on either.

## The lead's direction (2026-10-21, verbatim in game_design.md)

He rejected a dig-in berm: **"the sandbag rings or dirt would just come out of nowhere."** His answer: **"the actual idea of using
real cover would add an important element of the game. If I'm understanding correctly here, idle units that are close to a piece of
cover might drive a very short distance to take advantage of the cover. While we might not have much waist-high cover on our maps
currently, it's certainly something we could add or try out."** On obstacles: **"let's defer on this one. The maps are already kind
of busy."** Wrecks stay passable (contention is his first movement priority).

What he will notice: a tank parked tight behind a low wall or rubble pile takes most frontal shots on the cover; from the side or
behind it is fully exposed; artillery from above ignores it; ordering a squad to the far side of a rubble line v the open street
beside it visibly changes the fight.

## Where things stand

- Cover today is all-or-nothing line of sight: `TacticalQuery.hull_hidden` (centre + HULL_MARGIN either side), `CoverMap.clear_line`,
  `find_cover`, `peek_from`. No partial cover in damage. `Armor.MULTIPLIER` front 0.5 / side 1.0 / rear 1.5 (+ engine-deck weak spot).
- Maps: `arenas/*.json` (13 dealt in sim-baseline). How much waist-high cover exists is UNKNOWN.

## Backlog (in order)

1. **K1 the count.** Per dealt map: the low cover a hull can sit behind with the turret showing (height band, length), where fights
   happen on it (fight census heat if available), and a screenshot page. Report to the orchestrator: which maps already have enough,
   which need RE-SHAPING of existing clutter (no net additions). Any map change is a before/after page for him first (C37.3).
2. **K2 the damage seam.** Switch `--cover-hulldown` (OFF): a shell arriving in the target's front arc whose line passes through low
   cover within a few metres of the hull strikes the cover (no damage) with a probability from the exposed fraction; side/rear arcs
   unaffected; ARC (artillery) unaffected. Lab test both paths (a tank behind a low wall: frontal hits fall by the stated fraction,
   flank hits unchanged). Declare the twin.
3. **K3 the seat API (C37.4).** `TacticalQuery.low_cover_seat(near, threat_dir, max_shift_m := 4.0) -> Variant`, deterministic,
   reachable (navmesh), with a unit test; tell orders when it is on main.
4. **K4 the bar (after CP37.1):** shape C37.2 (deciding the blob line; guards the turtle line, kills, match length, perf).
5. **K5 the map re-shape** he approves, per map, each with sim-baseline attribution (the orchestrator adopts).
6. **Stretch:** the CPU choosing low-cover seats when it defends (a brains-path grant; ask).

## How to verify

Lab tests both paths; `make quick-remote`; screenshots of every map you touch, looked at; series on builder2 on CP37.1's lines; every
number with commit, machine, workload, n. Smoke: `make skirmish ARENA=<a map with low cover>`, park a squad behind it, attack it
head-on, then from the flank.

## Don't touch

Rules' paths (the rest of combat, tank, match), orders' seat laying (you provide the query; they call it), `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

The map page (K1/K5) when you have it: the orchestrator relays.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-21 (cover worker, Opus).** Branch `stream/cover`. Launch base 9d325e291 (main GREEN per HANDOFF; no baseline re-run).

**GREEN, merge here: e6f720619** (K1 tooling + pages, K2 OFF, K3): builder2 `make check exited 0`, 25 passed + 2 NOT JUDGED
(perf-judge refused 3x at ratio ~2.5x, the box busy; scenario_perf loaded 4.21x), tests 2988 passed 0 failed, native ON, sim-baseline
13/13 unmoved (the switch OFF is inert), scenarios 52/0, 4 pending, 1 unexpectedly passing (`scout_suppress::test_target_behind`,
known, native's to promote). Perf-judge is owed on a quiet box (OFF adds one dictionary lookup per front-arc hit).

### Plan (in order) and where each stands
1. **K1 the count** -- DONE: census + fight heat + page (below); reported to the orchestrator.
2. **K2 the damage seam** -- code + lab test DONE at 5b4e79362 (laptop, `make test FILTER=cover_hulldown`, 8/8 PASS); quick-remote GREEN (builder0, 183/0); full check GREEN at e6f720619 (above).
3. **K3 the seat API** -- DONE at 5b4e79362 (laptop, `FILTER=cover_seat`, 7/7 PASS); orders told once it is on main.
4. **K4 the bar** -- after CP37.1; see the sequencing note below (K4 before K5 measures ~nothing).
5. **K5 the map re-shape** -- WAITING ON HIS GATE: draft page filed (below).
6. Stretch: the CPU choosing low-cover seats when it defends (needs a brains-path grant).

### K1: the static census (no Godot; `make cover-census`, arenas at 9d325e291)
The ONLY low cover in the game is the jersey `barricade` (0.9 m; `ArenaKit.PROPS`). Everything else is >= eye height (1.3 m) and
already all-or-nothing line-of-sight cover: wreck 2.0 m, containers 2.59 m, walls/crates 3 m.

| map | low pieces | metres | facing the enemy's half | within 15 m of a lane |
|---|---|---|---|---|
| foundry, sumps, locks, gorge | 0 | 0 | - | - |
| terminus | 2 | 12 | 0 | 2 |
| parade, archipelago, cut, docks | 2 | 12 | 2 | 0 |
| yard, crossing, pit, yard_open | 4 | 24 | 4 | 0-4 |

(boulevard has 28 but is not dealt.) Yard's four sit at z = +-78, beside the bases, not where fights happen. **Every dealt map
needs re-shaping for the rule to matter** (heat numbers will say where).

### K1: where the fighting is (builder2, 5b4e79362 = launch game code, `make cover-heat`: 4 fights a map, 180 s, factions paired in turn)
Of every hit on a hull, the share that landed on a hull within 4 m of low cover: foundry 0 % (2699 hits), yard 0.9 % (2820),
pit 0.4 % (2424), terminus 0.6 % (2535), crossing 2.8 % (2973), sumps 0 % (3165), locks 0 % (2400), parade 0 % (2755), gorge
0 % (2008), archipelago 0.1 % (2560), cut 0 % (2315), docks 0.1 % (2855), yard_open 1.6 % (3450). **No dealt map has its low
cover where fights happen.**
Pages (self-contained, from above, low cover bright, hits in red): `_agents/streams/references/round37/cover/low-cover-page.html`;
the K5 draft `reshape-draft-page.html` (raw numbers `heat.json`). Tools: `make cover-census`, `make cover-heat`,
`tests/cover/cover_page.py`, `tests/cover/reshape_proposal.py`.

**K5 draft (his gate, NOT applied):** turn lone clutter in the fighting into jersey barriers on the same spot, facing the enemy
(a swap needs >= 50 sampled hits within 12 m of it and its mirror; containers that are part of a street wall are never touched).
Under "re-shape, don't add" that finds: pit 1 pair, terminus 1, crossing 2, sumps 2, gorge 1, archipelago 2, docks 2; **foundry,
yard, locks, parade, cut, yard_open: nothing** (their hottest streets have no lone clutter). Each swap trades hard cover (a
container or wreck hides a crew completely) for low cover. **Option (b) draft (the orchestrator's ask, NOT applied):** `addruns-draft-page.html`, from `tests/cover/add_runs_proposal.py`.
Short 12 m runs (two barriers) ADDED across the hottest streets of the four maps with the most concentrated fighting (top four
cell pairs >= 20 % of hull hits: crossing 0.28, sumps 0.27, locks 0.20, gorge 0.20), each with its mirror, 5 m clear all
round, out of the spawn ends, 2 runs a map: 8 barriers a map. Each run has 6-16 % of its map's sampled hull hits within 12 m
(crossing 172 / 182 of 2973; sumps 373 / 288 of 3165; locks 341 / 309 of 2400; gorge 303 / 316 of 2008). Crossing's
hottest spot (the west bridge) has no room, so its runs sit on the bank facing the bridges.
**Taller rubble (his Q1 alternative):** `rubble_note.md`. Two limits: rounds fly at 1.05-1.14 m, so anything over ~1.0 m blocks
the sheltering crew's own shots unless rules moves low cover off the shells' hit layer; eye height 1.3 m caps low cover at
~1.25 m, which lifts a 4 m tank only from 0.22 to 0.31 hidden. Not worth it unless Bar K shows hull-down working for the cars.
**Apply note:** the dealt maps are written by `tools/make_arenas.py`
(not cover's path): an approved re-shape must land there too, or the next `make arenas` undoes it (request to the orchestrator).

### K2: decisions (the rule as built)
- `Armor.low_cover_strike` (one function + its `cover_roll` hash; merge note to rules) called from `Match._shell_hit` and
  `Match._fire_beam`: a PROJECTILE or BEAM round in the hull's FRONT arc (Armor.ARC_DEG) whose shooter is beyond a low feature
  lying between the hull's face and 3 m past it (`CoverMap.HULLDOWN_REACH_M`) strikes the cover (no damage, an impact event on
  the cover, `stats.cover_struck` +1) with probability = `CoverMap.low_screen`'s fraction. Side/rear, ARC (artillery from
  above) and CONE (flames) never. Switch: `--cover-on=hulldown` (CoverMap.DEFAULT_OFF; `CoverMap.set_off` for tests).
- **The fraction is honest geometry:** the share of the hull's presented front width the cover's shadow spans, times
  min(1, cover height / hull height). Decided because he rejects "cheating" visuals: a jersey barrier visibly hides most of a
  low car and little of a bus. Consequence, per unit behind a 0.9 m barricade: Rat Rod 0.73, law_scout 0.68, syn_ifv 0.67,
  scout 0.60, syn_tank 0.49, gang_ifv 0.43; tanks/IFVs/artillery 0.22-0.34; gang_tank 0.17, law_suppressor 0.15.
  **So today's barricade protects scouts and the Syndicate's low hulls; the big trucks barely.** (A question for him below.)
- The roll is a hash of the projectile id (no RNG draw): OFF is byte-identical, the twin is trivial.
- Lab (5b4e79362, laptop): IFV autocannon v a Rat Rod tight behind yard's barricade, 20 s a leg: frontal hits OFF 41, ON 13
  (+29 on the cover; kept 0.31 v expected 0.27); flank OFF 45, ON 44 (+0). Scout machine gun (beam), 8 s: frontal OFF 43, ON 11
  (+30; 0.27); flank 68 v 71 (+0).

### K3: the seat API (C37.4)
`TacticalQuery.low_cover_seat(map, near, threat_dir, max_shift_m := 4.0, hull := SEAT_DEFAULT_HULL, node := null) -> Variant`.
**One deviation from C37.4's signature: `map: CoverMap` first** (every TacticalQuery function takes it; orders has it via
`CoverMap.of(node)`), plus the crew's `hull` (hull_size as a Vector3; the seat depends on its length) and `node` (any arena
node: with it the seat must be on the navmesh and reachable from `near`). The seat: nose 1 m short of a low feature's near
side, the cover between the crew and `threat_dir`, hiding >= 15 % of its front (the same `low_screen` the damage rule reads),
within `max_shift_m`; best = most hidden, then shortest shift, then lowest feature index (deterministic). The caller lays the
facing (= threat_dir). null = keep your own seat.

### Bar K (filed 2026-10-21 before any number; recorded on main as R37.7)
Arms ON (`--cover-on=hulldown`) v OFF, same seeds, same tree (pair named), on CP37.1's two lines, both factions both ways, n as
CP37.1 sizes it. Positive control: ON's `stats.cover_struck` > 0 on every map. Deciding: the blob line moves toward the blob losing
by more than CP37.1's 2-seed-block noise. Guards: the turtle line not toward the turtle winning beyond that noise; kills a fight
and match length per faction within +-10 % of OFF; perf-judge PASS. A series before K5's re-shape is the null reading. **Scope (R37.11):** the rule acts on direct shells and beams only, on
both the GDScript and native paths (native flies the round; the seam sits in `Match._shell_hit` / `_fire_beam`, before
combat_native's damage maths). Artillery/mortar splash and cone/flame damage never pass through it, so low cover never stops them. A
hull-down crew is fully exposed to those by design.
**R37.7 (orchestrator):** granted `tools/make_arenas.py` and the arenas it regenerates, for low cover only, with a merge note.

### Questions for the lead
1. **(player terms)** A tank parked tight behind a waist-high jersey barrier: should it be hard to hit from the front even when
   it is a tall truck that visibly towers over the barrier? Recommendation: **no, keep it honest**: low cars mostly hidden, big
   trucks barely, and give the big ones real protection by re-shaping some clutter into **taller rubble (about chest height,
   still low enough to see and shoot over)** where fights happen. (Taller rubble is a new prop look: art, then his page.)

2. **(player terms)** The fighting on every map happens away from the few waist-high barriers there are. Re-shaping only what
   is already there gives at most one or two new barrier spots on seven maps and none on the other six. Would you rather (a) keep
   to re-shaping (small effect, maps unchanged in feel), or (b) allow a FEW barrier runs added in each map's hottest streets (the
   maps get a little busier)? Recommendation: **(a) first** on the seven maps, measured; (b) only if the blob line says hull-down
   needs more ground. The draft page shows every map before/after.

### What to playtest (when merged)
- Lab: `make test FILTER=cover_` (hull-down both paths, the seat). Positive control in a real fight: any match with
  `--cover-on=hulldown` prints `stats.cover_struck` in MATCH_RESULT (absent when OFF).
- Player view (once K5 puts barriers where fights are): `make skirmish ARENA=pit` with `--cover-on=hulldown`; park a squad tight
  behind the re-shaped barrier, attack head-on (sparks on the barrier, fewer hits), then from the flank (no change).

### Next steps / blocked
- **K5:** waiting on his two answers (the orchestrator is asking). On (a): apply the draft's swaps in `tools/make_arenas.py`
  (granted R37.7) + regenerate, before/after frames at his pose, sim-baseline attribution with the switch OFF (maps move: the
  orchestrator adopts).
- **K4:** waiting on CP37.1 on main; then the null reading on today's maps, then the judged series on the re-shaped maps.
- **Stretch (CPU defends from low-cover seats):** needs a grant in the brains paths (`cpu_commander.gd` / tank_brain); requested.

### Native twins (N2, on stream/native 3d598cdaa; not merged here)
CoverNative.low_screen, low_features_near and cover_roll in C++, bit for bit. `test_native_cover_low.gd` gave 15000 answers, 0
mismatches; test_cover_hulldown and test_cover_seat pass on the native path (builder0 light `make native quick` exited 0).
low_cover_seat needs no twin. **Merge note (native's edits in cover's files):** cover_map.gd's `low_screen` / `low_features_near`
dispatch to native under BrainSwitches.native_cover, with the GDScript kept as `low_screen_gd` / `low_features_near_gd`;
armor.gd's `low_cover_strike` takes its roll from `map._native.cover_roll` on the native path. **K4's pair merges stream/native
at its CP37.1 hand-over** (the orchestrator: no cherry-pick before then). Any later edit of mine to low_screen goes to both
versions, with native told.

### Requests to other streams
- **native:** ~~twins~~ DONE (N2, above).
- **orders (O6):** the API above is on `stream/cover` 5b4e79362; I'll say when it is on main.
- **orchestrator:** a brains-path grant for the stretch (the CPU's defending crews take `low_cover_seat` once when they halt), only after K4 passes.
- **rules (merge note):** two calls in `match.gd` (`_shell_hit`, `_fire_beam`), each guarded by `Armor.low_cover_strike`
  returning null when OFF; `stats["cover_struck"]` is created only when ON.

