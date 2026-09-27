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
