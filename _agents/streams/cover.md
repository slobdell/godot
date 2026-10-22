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

**K5 full check RED at 3923ba026 (builder0, 4781 s, `make check exited 2`): test 3015 passed / 10 failed; sim-baseline
MOVED exactly the five K5 maps (switch OFF, so the maps did it): terminus 64e5266ef0faa245, sumps f7fc6b91340c2231, locks
a929186d10a30461, parade 69079de179015f0d, gorge 7a911a7558729ff1; 8 unmoved; determinism 8c3c1232b711a760.** The 10 failures
are other streams' staged scenarios whose stage points sit on the runs (both chose the busy streets): native traffic hold x4
(terminus west street x=-70, runs (-80,70)/(-62,80)); native yield sumps x2 (spot:hold 0); manoeuvre h1b_side bank (locks
north bank ~(33,11), the mirror run (26,16)); brains cpu_opening / cpu_hold / cpu_hold_guns (parade depot bay, run (-44,-8)).
None are my paths. Asked the orchestrator (2026-10-22): (1) owners re-pin their stages on the K5 maps [recommended], (2) I
re-site the runs clear of the stages (costs hit share), (3) hold K5. builder2 series HELD until the answer (re-siting changes
what Bar K judges).

**HAND-OVER (2026-10-22): merge 43d16acc4** (code == 05300509a: main da3193cf5 merged + K5 maps with parade re-sited at
c02b01d83 + K2 switch OFF). builder0 `make check exited 2` ONLY on sim-baseline's expected adoption: test 3055 passed 0 failed,
24 passed / 1 FAILED (sim-baseline) / 2 NOT JUDGED (perf-judge refused 3x at 2.35/1.69/2.49x, box busy; scenario_perf
unpinned), scenarios 53/0, 4 pending, determinism 8c3c1232b711a760. sim-baseline MOVED (switch OFF: the maps did it; the
orchestrator adopts on merge): terminus 64e5266ef0faa245, sumps f7fc6b91340c2231, locks a929186d10a30461, parade
d4cd790f2b1a157a, gorge 7a911a7558729ff1; the other 8 unmoved. Perf-judge still owed on a quiet box (K2 OFF adds one
dictionary lookup per front-arc hit).

**BAR K VERDICT (K4, 2026-10-22): FAIL on the deciding line; every guard holds. K2 stays OFF.** Paired, ON v OFF, one tree
per fight: builder2, terminus/locks/sumps/gorge at 3923ba026 + parade's 64 fights per arm re-run at c02b01d83 (re-sited run,
R37.35; seeds 2601-08 + 2701-08, both sides, blob + turtle, all 64 parade fights replaced in BOTH arms), 320 fights an arm,
GUARD_JOBS 20, every log with its GUARD_RESULT (one preemption at 05:11, seed 2702 lost and re-run by the driver).
- Deciding: blob wins 45 % -> 44 % (diff -1.3 pts, paired se 0.9 = 1.4 se, needs > 2); flips 2 to a loss, 0 to a win,
  McNemar p 0.25 (needs < 0.05). Kill ratio 0.85 -> 0.84 (-0.016, se 0.006).
- Guards: turtle 36 % -> 37 % (+0.6, se 1.1; not up); kr 0.75 -> 0.75. Kills/fight and length per faction within 3 %
  (gangs 10.08 -> 10.38 kills, 144 s both; law 13.0, 142 s; syndicate 30.3, 134 -> 133 s; condemned 17.7, 152 s).
  Positive control: cover_struck ON terminus 101, locks 241, sumps 15, gorge 79, parade 69 (OFF 0 everywhere).
  OFF-v-OFF replay (seed 2601, 20 fights): 0 flips, identical. Perf-judge and sim-baseline: the hand-over check below.
- **Map effect (the maps alone, OFF@K5 v 9d325e291's fights, same seeds):** blob 48 -> 45 % (-2.5, se 3.4; flips 19/15,
  p 0.30), kr 0.88 -> 0.85; turtle 39 -> 36 % (-3.1, se 2.2; flips 14/9, p 0.20), kr 0.80 -> 0.75 (-0.057, se 0.023, 2.5 se
  DOWN: his attackers trade a little worse on the barrier maps). Nothing rises; sumps/gorge/locks left as sited (ruling).
- Reading: the barriers are hit (ON stops 505 shots in 320 fights) but a hull-down front-arc rule at these sites barely moves
  who wins: too few hits land on a hull behind a run (2-15 % of a map's hull hits are within 12 m of one). The maps ship
  (his call, OFF has no effect on play beyond the geometry); K2 stays OFF. Stretch (CPU low-cover seats) is gated on K4
  passing: NOT started.

**R37.35 (2026-10-22), option (1): the maps stay; owners re-pin their stages (native: traffic x4, yield x2; manoeuvre: h1b bank).
Parade traced (READ grant on brains): NOT stage geometry.** With only arenas/parade.json back to pre-K5, all 3 brains parade tests
pass (builder0 full test 3019/7, the 7 being native's 6 + h1b); on K5's parade they fail. The CPU's opening lies in wait beside
the far depot for his column on the road from his base, and AmbushSite springs only where the attacker has no cover within 12 m
of the kill zone; the run (-44,-8)'s mirror (44,8) stood ~17 m off that road (its cover points ~9 m), refusals "no open ground"
14 -> 68, taken 1 -> 0. **Re-sited at c02b01d83:** parade = (-50,80), (-62,4) (2.5 % of hull hits, was 7.7 %);
`add_runs_proposal --clear-approaches` (no run within APPROACH_CLEAR_M 24 m of a base->depot road) + the arena wall's clearance;
`make cover-k5` checks it. builder0 c02b01d83: `make test FILTER=tactics_cpu exited 0` 7/0 (cpu_opening, cpu_hold, cpu_hold_guns
PASS); `make arena-test exited 0` (45/45, 148/0). Frames `k5-frames/parade_run_c*` (a low jersey line on open ground between
two container walls; before: empty). Other maps by the same rule: sumps (-30,-60) 5.6 m, gorge (-62,6) 7.2 m, locks (-46,-16)
17.7 m from a depot road; **map-alone effect** (guard.py --pair 9d325e291.fights.jsonl v OFF@3923ba026, builder2, 320 fights):
blob 48 -> 46 % (-1.9, se 3.2), kr 0.88 -> 0.87; turtle 39 -> 38 % (-1.3, se 2.9), kr 0.80 -> 0.75 (se 0.031); per map no rise
beyond 1 se (sumps blob +6.2, se 7.7; locks both down) -> left as they are (orchestrator's ruling). Bar K: OFF and ON at
3923ba026, parade's 64 fights per arm re-run at c02b01d83 (queued); OFF-v-OFF replay seed 2601: 20 fights, 0 flips, identical.

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

### Bar K, RE-FILED PAIRED (2026-10-21, per R37.14(b), before any arm number; supersedes the R37.7 text)
**Arms.** ON (`--cover-on=hulldown`) v OFF on ONE pair tree (named at the series; it merges stream/native at the CP37.1
hand-over), the SAME 320 fights as CP37.1's base: `make guard-run` on the 5 guard maps (terminus, locks, sumps, gorge, parade) x
seeds 2601-2608 + 2701-2708 x both sides as the guard x blob and turtle. Judged with `tools/scoreboard/guard.py --pair OFF ON`.
**OFF is run on the pair tree, not read from `references/scoreboard/guards/9d325e291.fights.jsonl`:** that base predates cover's
merge (821c7f494 is not in 9d325e291) and, after K5, the maps differ, so the paired base must be the same tree with the switch OFF.
Before ON: OFF v the 9d325e291 jsonl on today's maps must give 0 flips (the switch-OFF equality, CP37.1's OFF v OFF check);
any flip is attributed before an arm number.
**Positive control first:** ON's `cover_struck` > 0 in every guard map's fights (summed per map), or the arm did not engage and
nothing is judged. (Needs `cover_struck` in GUARD_RESULT: requested from native below.)
**Deciding (blob line, 160 paired fights):** the blob's win share DOWN, ON v OFF, by more than 2 se of the paired difference
(se = sd of the per-seed differences / sqrt(16 seeds)), AND the exact one-sided McNemar p < 0.05 on the flips (more blob wins
turned to losses than the reverse); second line: the blob's kill ratio not UP by more than 2 paired se.
**Guards:** (1) turtle line: the turtle's win share not UP by more than 2 paired se (McNemar reported the other way); (2) kills a
fight and match length per faction (as the guard, both lines) within +-10 % of OFF, paired; a faction outside is REPORTED with its
units; (3) perf-judge PASS on the pair tree; (4) sim-baseline unmoved with the switch OFF.
**Map overlap (the orchestrator's check):** the guard maps are terminus, locks, sumps, gorge, parade. Option (b)'s draft maps are
crossing, sumps, locks, gorge: 3 overlap; crossing is not a guard map; terminus and parade get nothing. Option (a)'s swaps fall
on terminus (1 pair), sumps (2), gorge (1): locks and parade get nothing. K1 near-cover share on the guard maps today: terminus
0.6 %, the other four 0 % -> **the pre-K5 series is a null reading by construction.** So whichever he picks, K5 places low cover
on ALL FIVE guard maps (and crossing as drafted for (b)), or the series reads a null on the maps that got none. The (b) script
fits two mirrored runs on every guard map (scratch run, heat 5b4e79362): terminus (-72,-26),(-68,26), 11-15 % of hull hits
within 12 m; parade (-44,-8),(-16,22), 8-9 %; locks/sumps/gorge as drafted. For (a), locks and parade have no lone clutter near
the fighting: they would need added runs, i.e. (b) on those two.
**Scope (R37.11):** the rule acts on direct shells and beams only, on
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
- **K5 APPLIED (his answer, game_design.md 2026-10-21: honest barriers, no taller rubble; runs on the 5 guard maps,
  lanes kept; crossing skipped).** `tools/make_arenas.py` `COVER_K5 = "b"`: two mirrored 12 m runs (two barricades) on
  each guard map, 8 barricades a map; arenas regenerated (terminus, locks, locks_dry, sumps, sumps_dry, gorge, parade).
  Sites (`add_runs_proposal.py --keep lanes`, heat 5b4e79362; share of sampled hull hits within 12 m of each run):
  gorge (-62,6) 15 %, (-28,-6) 10 %; locks (-26,-16) 14 %, (-46,-16) 13 %; parade (-44,-8) 7.7 %, (-50,80) 3.4 %;
  sumps (-36,72) 4.1 %, (-30,-60) 2.1 %; terminus (-80,70) 2.1 %, (-62,80) 1.8 %. **Terminus and sumps read weak:** a run
  in their busy streets narrows a lane (or the dry twin's west causeway), which the arena tests forbid.
  How the sites were kept honest (three rounds, each caught by the generator or the arena tests): the first draft's runs
  closed sumps' west causeway (R4, the generator) and narrowed terminus's ring road 22 -> 15.4 m and broke parade's
  base-to-base crossing line (arena-pytest); a strict shape guard (room/chokepoints unchanged too) pushed four maps' runs
  out of the fighting (0.1-6 %), so the applied guard keeps lane widths (dry twins included) and arena_room's base-to-base
  ambush read only. **Evidence:** `make cover-k5 PLAN=b` 7 files, 0 failures, arenas == plan b; builder0 `make arena-test
  exited 0` at 3923ba026 (pytest 45/45, Godot 148/0). Frames at his pose (builder0, `container-frames`, spots on the runs):
  `references/round37/cover/k5-frames/` -- every run reads as a low grey jersey line on open ground or a street, roads
  past it open; locks' first spots (26,16)/(46,16) render black BEFORE and after (the tool, not the runs), retaken from
  the other side (`locks_*_after2`).
  (granted R37.7) + regenerate, before/after frames at his pose, sim-baseline attribution with the switch OFF (maps move: the
  orchestrator adopts).
- **K4:** CP37.1 + native's guard tooling + N2 twins + rules' OFF code merged here from main a10846307 (02535d3aa). NEXT: the
  OFF gate (`GUARD_WORKTREE=../godot-cover-guard tools/scoreboard/guard.sh <tree>` on builder2, then `guard.py --pair
  references/scoreboard/guards/9d325e291.fights.jsonl <raw>`, 0 flips expected) once a10846307's builder2 check is green and
  builder2's series queue is free (orchestrator, R37.16). The arm still waits on his K5 answer; then the null reading on today's maps (OFF v 9d325e291 = 0 flips, then ON v OFF), then the judged series on the
  re-shaped maps per the paired Bar K above. **R37.18:** the separate OFF gate on today's maps is DROPPED (rules' base gate
  on a10846307 already replays 9d325e291's fights with my OFF code in); I re-gate OFF on the K5 maps. builder2 held till then.
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
- **native:** ~~twins~~ DONE (N2, above). ~~Two K4 asks~~ DONE (stream/native 420048f99; hand-over branch
  pair/native-cp371 2bb41ef93, the orchestrator merges): GUARD_RESULT carries `cover_struck` and `args`; an arm runs as
  `GUARD_ARGS=--cover-on=hulldown GUARD_TAG=hulldown tools/scoreboard/guard.sh <commit>` (raw logs in
  ../godot-native-guard-raw/<commit>-hulldown/), then `guard.py --pair <OFF> <that folder>`. guard.sh uses ONE scratch folder
  (../godot-native-guard): two arms at once from one tree collide; set GUARD_WORKTREE to a different path for the second.
  Native's evidence for the OFF gate: 20 of 20 re-run fights byte-identical between 9d325e291 and a tree with K2 OFF. Native's
  smoke (builder0 light, ON, terminus 2601 x blob/turtle x both sides, 4 fights): `cover_struck` = 0 in all 4 (the stat does
  reach result["stats"]): today's maps fail the positive control, as K1 predicts. The pre-K5 run is the null reading only.
- **orders (O6):** the API above is on `stream/cover` 5b4e79362; I'll say when it is on main.
- **orchestrator:** a brains-path grant for the stretch (the CPU's defending crews take `low_cover_seat` once when they halt), only after K4 passes.
- **rules (merge note):** two calls in `match.gd` (`_shell_hit`, `_fire_beam`), each guarded by `Armor.low_cover_strike`
  returning null when OFF; `stats["cover_struck"]` is created only when ON.

