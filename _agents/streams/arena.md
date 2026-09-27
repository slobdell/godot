# Stream: arena (water reads wet)

> Read [`arenas.md`](../arenas.md) — *Water reads black* first, then the rest; [`game_design.md`](../game_design.md)
> *Round 11: the lead's verdicts* (items 4 and 5) and *Round 12 direction*; [`art_direction.md`](../art_direction.md);
> [`workstreams.md`](../workstreams.md) (round 12: ownership, C12.3, the standing rules) and the round-10 contract R9
> (terrain maps) there. The archived briefs `archive/round11/arena.md` and `archive/round10/terrain.md` are the history
> of these maps and this shader; do not work from their backlogs. **You own** `arenas/`, `game/arena/`,
> **`game/theme/arena_kit/terrain/**`** (the water and pit art and shaders — theme paths, yours this round because no
> feel stream runs), `tools/make_arenas.py`, `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`,
> `tests/arena/`, `tests/test_arena*.gd`, `_agents/arenas.md`; **carve-out:** additive read accessors for the lamp
> pools and the venue's emissive layout in `game/theme/cyberpunk/arena_dressing.gd` / the arena environment, listed in
> merge notes.

## The lead's direction

2026-09-24, on the arena page, on the Crossing's river and the Locks' canal: **water reads black and should read wet**
— he agreed with the diagnosis and chose *next round* over that night. Written up in `arenas.md` *Water reads black*
by the round-11 arena stream, from its own frames. His earlier words on these maps (2026-09-20): bridges, pits and
water were the terrain he asked for three times before they were dealt.

2026-09-26: *"ok that all looks good … Can you set up our workspaces to orchestrated workloads for all these items?"*

## Where things stand (from `arenas.md`, round 11; re-verify)

- **Maps with water:** `crossing` (dealt, a river with two bridges), `locks` (dealt with its recordings in round 11:
  a canal, a lock, a swing bridge), `terminus_canal` (a fixture). `sumps` and `pit` carry PITS, which are not water and
  should stay dark — and today the two kinds of hole are told apart mostly by kerb colour.
- **Why it is black** (`game/theme/arena_kit/terrain/water.gdshader`, round 10): `mix(water_deep, sky, fresnel ×
  reflection)` plus one lamp streak. At his 21° camera the reflected ray points ~21° up where the modelled sky is
  almost black (the neon band is horizon-only), Schlick gives fresnel ≈ 0.16, so the surface is ~84 % `water_deep` =
  (0.004, 0.012, 0.018). That was deliberate: feel's round-10 review said the brighter first look "reads as a
  starfield/nebula", so it went to oily black.
- **Frames at his pose:** `_agents/streams/references/arena/water-reads-black-2026-09-24/` (crossing-bridge, locks-lock,
  locks-swing_bridge, locks-overview; builder0, `231c838d`).
- **The round-11 stream's read of what it needs** (a read, not a spec — his eye decides): reflect what is actually
  around the water at HIS angles (the stands' crowd lights, the purple wall rims, the blocks' windows sit exactly where a
  21° reflected ray lands) — cheaply, an environment band built from the venue's real layout instead of the horizon-only
  band; lift the body colour toward a dark teal; specular that MOVES (the lamp pools glinting on a slow swell — the cue
  that says wet, and it must not become the starfield again); a lap line at the rim, which also separates water from
  pits at a glance.
- **Tools:** `make remote T=terrain-shots` (each water map at his pose beside its dry twin + overview),
  `make terrain-page`, `make arena-page`, `make terrain-drive`, `make water-probe`, `make terrain-pytest`,
  `make arena-report`. The perf budget is M1 (`make perf-scene` on builder0; zero added real lights, draw calls counted).
- **The Locks' open canal** (his verdict item 5): he did not answer whether the open canal is the kill zone he wants or
  needs cover on the quays; the orchestrator ruled LEAVE IT OPEN and asked that it be re-put **after he has driven it**,
  with the exposure number beside the question (the centre sees 45 % of the field).

## Backlog (in order)

**A1. The wet look, as pairs.** Work in `water.gdshader` and its material inputs. Build it in the order the diagnosis
suggests and shoot a pair after EACH step (one variable per pair, the dial and the file in the caption — show's rule 12):
(a) the body colour off black; (b) an environment band from the venue's real emissive layout (wall neon height and
colours, the stands) at the elevations a 21° reflected ray reaches — read the layout through an accessor, never a copied
table (Invariant 0); (c) moving specular from the lamp pools on a slow swell — bounded so it never reads as a starfield
(state the amplitude and the pool count); (d) the lap line at the rim. Then the composite. Measured cost: `perf-scene`
before/after on the Crossing, draw calls and frame time; a planar reflection is the expensive version and is tried
only if (b) fails his eye, with its cost stated first.

**A2. His page, with `db`.** `make art-review-page`-style or `terrain-page`: each water map, before/after at his pose,
the dry twin beside it, a Fun/Approve tap per frame, plus **the Locks question** with the exposure number and a first
question "have you driven the Locks yet?". Declare the `db` capability (round 11's arena page forgot it and every
answer had to be re-asked by hand). Send the URL to the orchestrator; it reads the `db` at close.

**A3. Pits stay pits.** The Sumps and the dug Pit must still read as shafts (black, red glow) beside the new water; a
pair per map. If the lap line or the teal leaks into the pit material through a shared shader, split them.

**A4 (stretch).** Whatever his taps on A2 ask for; and the terrain report's water rows (`terrain-measure`) re-checked
so the numbers beside his frames are current.

## How to verify

- `make remote T=check` green on every named commit. **Pre-registered UNMOVED:** the sim baseline
  `01ab39b592cc9837` (the water is visual; the navmesh and every layout are untouched — if you touch `arenas/*.json`
  or the generator, say why and re-run the swap-bases control per `verification.md`).
- `make remote T=terrain-shots`, look at every frame; `perf-scene` numbers with commit and machine.
- C12.3: no collider, no `ArenaKit.PROPS` size, no obstacle body changes.

## Don't touch

`game/camera/**` (camera's), `game/theme/arena_kit/airship/**`, `game/theme/factions/**` (fleet's), the rest of
`game/theme/**` beyond the carve-out, `game/tactics/**`, `game/ai/**`, `game/audio/**`.

## Waiting on the lead

His taps on A2 (and the Locks question once he has driven it). Nothing blocks A1 or A3.

## Status

_(the worker keeps this current)_

### REPORT (2026-09-27, round 12 arena): water reads wet, on his page, pits untouched

**Green, merge here: `35ab155c`** (builder0, `>> remote: make check exited 0`, 18 targets, **1773 passed, 0 failed**,
sim-baseline `6313a38d7ecd99bb` **UNMOVED** (nav's CP2 baseline; the water is visual), determinism `550d53790035ddb4`).
It carries both of the orchestrator's checkpoints. The commits after it touch only docs, `tools/water_page.py`
and `mk/arena.mk`'s `terrain-measure` list; the tip's own check is recorded below when it lands.

**His page:** https://claude.ai/artifact/1PsZA4HnRWGCSgajuyamKN (version 2, `db` declared; taps land in
`decisions/<id>` as `{decision, words, at}`, the fleet page's schema). It asks first "have you driven the Locks
yet?", then gives an overall tap; every water spot as dry twin | round 10 | now with a tap; each map's build as
one-dial steps (keep/drop); the pits; the Locks question with its exposure; and the numbers. **Read its `db` at
close** (lesson 220).

**Done:**
- **A1, the wet look, as pairs** (`WaterLook.STEPS`, one decision per step, each caption naming its dial):
  r10 → a_body (teal body) → a_flood (lit by the floor's light map) → b_venue (the venue as built: blocks,
  containers, wall bars, stands, crowd) → c_lamps (real lamp heads as columns of light, plus the pools glinting on
  the crests; round 10's fake streak off) → c_swell (the slow swell that moves them) → d_lap (the lap line).
  Near-black share of water pixels, round 10 → now, same frame, same instant (`35ab155c`, builder0): Crossing bridge
  0.49 → 0.44, far bridge 0.72 → 0.37, neck 0.57 → 0.50; Locks lock 0.18 → 0.07, swing bridge 0.39 → 0.20, far quay
  0.98 → 0.55, canal 0.70 → 0.39; Terminus canal west bridge 0.66 → 0.38, avenue bridge 0.58 → 0.49. Cost: about
  **1 ms GPU** at 1080p on an Iris Xe where the river fills a fifth of the frame, ~0.2 ms on the Locks' strip, **0
  added draw calls, 0 lights** (the table below). The planar reflection was never needed.
- **A2:** the page above, with `db`, sent to the orchestrator.
- **A3, pits stay pits:** pits have their own shader (`pit.gdshader`; the trace is shared through
  `terrain_trace.gdshaderinc`, the look is not). Pit pixels that change between round 10 and the shipped water: Sumps
  catwalk 8 of 274,452, causeway 0 of 89,996, lip 4 of 52,728; Pit corner 16 of 167,812, far yard 48 of 34,372 (vehicles
  at the rim). Test: `test_the_pits_are_their_own_shader_with_none_of_the_waters_dials`.
- **A4 (stretch), numbers re-checked:** `terrain-measure` (now including the Locks): the Locks' centre sees **0.451**
  of the field (dry twin 0.511), so the page's 45 % is current; the Crossing 0.28 mean / 0.35 max, the Sumps 0.32 /
  0.42. No geometry changed, so no report number moved. The rest of A4 waits on his taps.

**Tests** (`tests/test_arena_water.gd`, 7): the pairs move one decision at a time; they end at the shader's defaults
(what ships); round 10 is reproducible from the dials; the pits' shader has none of the water's dials; the water
reflects every wall, bar, stands profile, lamp and the flood map of the venue as built; every reflected lamp is one
the venue built; the Locks' canal reflects the obstacles beside it.

**Tools:** `make remote T=water-pairs` (every step, five maps, frozen, WATER_STATS), `make remote T=water-gpu`
(the cost held still, `WATER_GPU_LOOKS=` per step), `python3 tools/water_page.py` (the page).

**Decisions (one line each):**
- An analytic trace of the real venue, not a planar reflection: zero draw calls, and it reads the layout (Invariant 0).
- Lamps as anisotropic columns: a physically sharp glint almost never lands at his 21° pose.
- The smear is laid out in the view's frame: round noise drew the neon as scribbles.
- Pits split into their own shader rather than gated by a flag: a flag is one typo from a leak.
- The Locks' `quay_road` spot moved to `canal:-55:0`: its camera sat inside a block.

**Questions for the lead (on the page):** does the water read wet now (overall, and per spot)? Keep or drop each
step? Have you driven the Locks, and is the open canal the kill zone you want or does it need cover on the quays
(it ships open)?

**Requests to other streams:** none open.

**Known issues:** the cost is measured on builder0's integrated GPU only, not on a phone. If phones need it, the next
cut is fewer lamps (only those whose column can reach water in view) and a cheaper bank distance. `perf-scene` on a
shared builder0 cannot resolve a sub-millisecond change (its average swung 92 → 13 ms across cycles).

**What to playtest:** `make skirmish ARENA=crossing` and `make skirmish ARENA=locks` at his usual camera; look at the
river and the canal while the fight moves (the swell and the lamp columns move; the pairs are frozen stills).

**Next steps:** read his taps from the page's `db` and act on them (A4); if he says "too much", the dials are in
`WaterLook` and each has a pair; the Locks cover question on his answer.

**Merge notes (shared files):** `game/theme/cyberpunk/arena_dressing.gd` (the carve-out, additive): `GROUP`
(`add_to_group` in `_ready`), `RIM_BAR`/`FOOT_BAR`/`CROWD_ROWS` consts, which replace identical literals in the bar
and seat-row placement (same values), the recording of edges/bars/lamps/stands size where they are built, and
`reflection_venue()`. `tools/water_page.py` is new (tools/ is shared; it is arena's page generator, like
`terrain_page.py`). Also note the `arena-before` worktree (`../godot-arena-arena-before`, branch
`stream/arena-before`, nothing committed, now clean): please remove it at close.

### The log (in order)

**Started 2026-09-26 21:20.** Baseline green: `46bac1a3`, builder0, `>> remote: make check exited 0`, 1726 passed,
0 failed, sim-baseline `01ab39b592cc9837`.

**Plan (in order):**
1. Split the shared trace into `terrain_trace.gdshaderinc`; `water.gdshader` and `pit.gdshader` each include it (A3
   by construction: the wet look's uniforms do not exist in anything a pit compiles). *Reason:* a flag in a shared
   shader is one typo from a leak; two shaders cannot leak.
2. `ArenaDressing.reflection_venue()` (additive accessor, the carve-out): the wall's inner face edges with their
   stands spans, the light bars, `StandsProfile.points()`, the crowd's band, every tower's lamp head (recorded where
   `_build_tower` places it) plus each layout floodlight's (KitYard's mast), and the floor's flood map.
   `TerrainVisual` finds it by group after the arena finishes building, and reads the obstacles near the water from
   the layout (a block's neon band read off its DRAWN mesh).
3. `WaterLook.STEPS`: r10 → a_body → a_flood → b_venue → c_lamps → c_swell → d_lap, one decision per step, tests
   holding step 0 to round 10 and the last step to the shader's defaults. `make water-pairs` shoots every step at his
   pose frozen at one instant and prints WATER_STATS (water luma, black share, changed pixels).
4. Tune by eye on the pairs, measure cost (`perf-scene` Crossing before/after), then A2 (page with `db`), A3 frames.

**Decisions:**
- *Reflection is an analytic trace, not a planar reflection.* The venue is a polygon wall, a stands profile and ≤16
  boxes; tracing them costs loops over uniforms and zero draw calls. A planar reflection is a second render of the
  scene. Tried only if this fails his eye.
- *Lamp glints are physical* (the reflected ray against each real lamp head), plus a broad sheen lobe, because at his
  21° pose the sharp glint rarely lands on the channels (the lamps are high and far): round 10's fake streak came
  from a direction no lamp stood in.
- *The `quay_road` spot on the Locks moved to `canal:-55:0`:* its camera sat inside the block at (-30, 42) and every
  frame there was a wall (both in round 11's terrain-shots and here).

**Progress (what the frames taught, in order; every frame at his pose, builder0):**
- First Locks pairs (22:23): b_venue puts the blocks' windows in the canal, but they read as pasted squares, so I
  softened, dimmed and smeared them in elevation. The lap line was invisible, so it got wider and brighter.
  body_flood 0.45 → 0.3 (the sodium pools turned the teal olive).
- The composite came out DARKER than round 10 (Crossing bridge mean water luma 0.166 → 0.073). A physically sharp
  mirror at 21° over the middle of a 140 m arena reflects open sky; the real lamps' glints almost never line up
  with his pose; and removing round 10's fake streak took its glare away. Fixes: each lamp became an anisotropic
  COLUMN (azimuth σ 0.05 rad, elevation σ 0.3 rad), the harbour-lights look; the floodlight pools glint on the long
  swell's crests (smooth noise at ~10–16 m, so never a sparkle); the flood-lit body goes by the light's luminance,
  so it stays teal; body (0.025, 0.09, 0.1).
- With that, the near-black share of water pixels at the Locks swing bridge went 0.39 → 0.20 and at the Crossing
  bridge 0.49 → 0.44 (round 10 → now, same frame, same instant; `d23125c7`-era pairs).
- The Terminus canal and the Locks showed the reflected neon as thin looping SCRIBBLES (round noise makes closed
  contours). The smear is now laid out in the view's frame, long across and short along it, so a neon line breaks
  into horizontal dashes; smear 0.12 → 0.09 (`504473f2`).
- Pit frames differed between steps: the Sumps has no water, so `set_water_look` never froze its pits and their
  ember moved; and a whole-frame count also catches the crowd and the show. Pits now freeze and mask too, and
  WATER_STATS reports `changed_inside_px` (`9fc09308`).

**Green:** `d23125c7` (my water + checkpoint 1), builder0, `>> remote: make check exited 0`, 18 targets, 1746 passed,
0 failed, sim-baseline `01ab39b592cc9837` UNMOVED, determinism `b83a374ce2fcde37`.

**Cost** (`make water-gpu`: builder0, Iris Xe, 1920×1080, his pose, one frame held still, the water toggled in 40
blocks, cost = median of paired drawn−hidden differences, IQR in brackets; `perf-scene` was useless here, its average
swung 92 → 13 ms across cycles with five streams on builder0):

| arm | Crossing bridge (water ≈ 19 % of the frame) | Locks lock (a narrow strip) |
|---|---|---|
| round 10 (`46bac1a3` worktree, two rounds) | −0.89 [−1.47, 0.24]; +0.35 [−1.09, 0.45] | +0.10; +0.09 |
| first wet look (`479a67b3`) | **+2.99 [2.87, 4.24]** | +0.80 |
| no per-pixel trig (`180309d7`) | +3.78 [2.58, 5.08] (trig was not it) | +0.92 |
| per step, `71689123` | r10 −0.03, a_flood 0.44, **b_venue 2.45**, c_lamps 2.53, d_lap 2.79 | — |
| boxes culled by bounding circle, stands solved as one line (`35ab155c`) | b_venue 0.07–0.34, c 0.5–1.3, **d_lap 1.04 [0.91, 2.4] twice** | d_lap +0.22 |

So the wet water costs **about 1 ms of GPU at 1080p on an integrated GPU at the most water-heavy pose**, about
0.2 ms on the Locks' strip, with **zero added draw calls and zero lights** (still one draw for all the water,
`TerrainVisual.draw_calls()`). The venue trace was the cost: it marched every stands profile point per pixel. What
is left is the lamps and the swell (≈ 0.5 ms) and the lap line (≈ 0.4 ms). The next cut, if phones need it: fewer
lamps (only those whose column can reach the water in view), and a cheaper bank distance. Not done: no phone
measurement exists (none of this has been profiled on Android).

**INCIDENT (2026-09-26 ~23:28, mine): a remote run from a non-git folder rsynced the laptop's `/` over
`builder0:~/tank_squad/`.** For a "before" `perf-scene` I ran `tools/remote.sh` from a `git archive` copy of
`46bac1a3` in my scratchpad. `git rev-parse --show-toplevel` failed there, `repo_root` and `name` came back empty,
and the sync became `rsync -az --delete / builder0:~/tank_squad/`. I killed it within minutes. Damage: source files
deleted in the other remote folders (build/, .godot/ and the shared .tools/ were protected by the filters), so any
remote run in flight then is void (the orchestrator's check from 23:14, squad's squad-shape-series from 23:27), and
each stream's next `make remote` re-syncs its tree. The laptop's root directories were also copied into
`~/tank_squad/`, `home/` included (2.2 GB of `/home/slobdell`). The orchestrator (godot-83) found it independently, deleted
the copied files on builder0, and is landing a guard in `tools/remote.sh` on `main` (lesson 221). My check started at
~23:29 is VOID and will be re-run after merging that checkpoint. My scratch copy and its launcher are deleted. From
now on: `make remote T=...` from the worktree only, and any "before" run from a real `git worktree`.

**Requests to other streams:** none open (the remote.sh guard and the builder0 cleanup are the orchestrator's,
both in hand).
