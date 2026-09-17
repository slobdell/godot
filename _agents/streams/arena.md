# Stream: arena (maps worth fighting over)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *The arena*, *The arena kit*), [../workstreams.md](../workstreams.md) (**M2 is yours and is
> CP2**), [../doctrine.md](../doctrine.md) (what formations and drills need from terrain) and
> [../verification.md](../verification.md) (the swap-bases fairness control). You own `game/arena/`, `arenas/`,
> `tools/make_arenas.py`, a new `mk/arena.mk`, and a new `_agents/arenas.md` (your design doc).

## The lead's direction (2026-09-17)

> *"the maps are just too simple. We probably need a dedicated agent to formulate maps. I'm also not seeing the assets
> I asked for earlier like the big dystopian TV screen in the match or the shipping containers as re-usable components
> in the arena. As far as I know there's only one map right now and it's boring and doesn't provide any meaningful way
> to do tactics."*

## Where things stand

- Three layouts exist as data (`arenas/foundry.json` — round 1's arena, `scrapyard.json`, `furnace.json` with fire
  pits), but the default is flat and sparse: a handful of crates and walls on a 240 m square.
- **The arena kit is built and almost unused:** `prop.container_20` / `container_40` (ISO sizes, stackable, one
  MultiMesh per kind, faction stencils), `prop.ad_screen` (a 7 × 14 m LED wall with channels and ad copy),
  barricades, gates, floodlight towers, neon signs, `prop.wreck`. Placing them costs nothing at generation time.
- Armies are now ~30 a side (44 for the gangs), so spawn zones and frontages sized for 10 vehicles no longer fit.
- Doctrine measures formations and drills against terrain: a wedge beats a column *because* of frontage and cover, and
  bounding overwatch needs somewhere to bound *to*. Flat ground makes all of it pointless.

## Backlog (in order)

**X1. Layout schema v2 (M2; CP2).** Extend `arenas/<name>.json` to carry the kit: `props` with `type`, position,
rotation and `stack` for containers; ad screens; barricades; signs; wrecks. Add per-arena **spawn zones sized for 30+ a
side**, and annotations the AI can read (lanes, cover clusters, open ground). Keep it point-symmetric and validated,
keep `--arena=<name>`, and keep the loader honest: unknown prop types fail loudly. Tell combat when it lands (they
build collision and navigation from it) and render (they dress it). **Announce CP2 as soon as it's green.**

**X2. What makes a map tactical.** Write `_agents/arenas.md` first: the vocabulary you'll build with (lanes,
chokepoints, cover clusters, sightline breaks, hard cover vs soft, flanking routes, high-traffic centre vs safe
flanks), what each does to the game we actually have (fire arcs, suppression, spotting ranges, turning circles), and
how you'll test that a map delivers it. Cite doctrine's measurements where they apply.

**X3. Four arenas with different characters,** built from the kit: for example a **container yard** (dense lanes,
short sightlines, ambushes), a **boulevard** (long fire lanes broken by screens and barricades, artillery matters), a
**pit** (a low centre overlooked from the edges, a control-point brawl), and a **scrapyard** (irregular cover, no
symmetry of shape but symmetric of value). Each ships with a one-line description of the fight it wants to produce.

**X4. Prove they work.** For each arena: the swap-bases fairness control (neither side wins by starting position), a
seeded match series, and measurements that the map does what X2 says — average engagement range, how much of a crossing
is exposed, how often flanking routes get used, how long a unit can stay hidden. Numbers in `_agents/arenas.md`.

**X5. Dressing and spectacle.** Place the ad screens where the camera sees them, containers stacked into real cover,
signs and floodlights on the stands, wrecks as permanent cover where it helps. Coordinate with render's frame budget
(M1): props are cheap per kind but not free per instance.

**X6. Arena selection.** `--arena=` everywhere, a random-but-fair default, and a short note in the Status on which
arena suits which faction matchup (the gangs' swarm wants lanes; the Syndicate's range wants the boulevard).

- **Stretch:** simple destructible cover (a container stack that collapses); a layout generator that proposes
  candidates for a human to approve, once X2 says what "good" means.

## How to verify

`make remote T=check`, the fairness control per arena, seeded series, and `make remote T=skirmish-shots --arena=<name>`
screenshots of each map **looked at**. A spectator's description of how a fight in each one differs.

## Don't touch

Vehicle art, props' materials and the frame budget (render), weapons and rules (combat), brains (ai), UI and camera
(control).

## Status

### Report (2026-09-17, end of the worker's run)

`make remote T=check` green on the report commit: **868 passed, 0 failed**, sim baseline `d4bd86eee0f96c54` unchanged.

**Done** (all on `stream/arena`; design and every measurement in [../arenas.md](../arenas.md)):
- **X1 (M2, CP2, merged by the orchestrator):** layout schema v2: `props` (containers stacking 1-3, ad screens,
  barricades, wrecks, floodlights, signs; `ArenaKit.PROPS`), `spawn_zones`, `lanes`, `regions`; loud validation,
  point symmetry for everything that collides, spawns 6 m clear of cover; props normalized into `obstacles`, so no
  consumer had to change. `tests/test_arena_kit.gd` (8 tests, mutation-checked).
- **X2:** `_agents/arenas.md`: the vocabulary grounded in the mechanics as measured, rules of thumb, the test method.
- **X3:** four arenas built from the kit, each with its one-line fight: **yard** (the Container Yard), **boulevard**,
  **pit**, **boneyard**. `make arenas` regenerates them; `make arena-report` measures and plots them.
- **X4:** `make arena-series` (swap-bases pairs through `tests/arena/arena_probe.gd`). 18 seed pairs per arena: no base
  advantage distinguishable from zero on any of them (largest −0.05 ± 0.03 surviving share). Maps change hidden time
  (36% → 58%), the long tail of hit ranges (p90 74 → 64 m), flank use (pit 18%) and match shape (the boulevard is
  decided by elimination 26/36, the yard by control 24/36). **They don't change median hit range (39-43 m everywhere)**,
  which is combat's and ai's to move.
- **X5:** screens on every arena facing their own half's base, stacked containers as the main cover, floodlights,
  signs, wrecks; render fitted the slots and measured the busiest map (boulevard) inside M1 (8.7-10.7 ms GPU).
  `make remote T=arena-shots` screenshots looked at: fog of war bends around the cover, screens read.
- **X6:** `--arena=<name>` everywhere; `--arena=random` picks from `Arena.ROTATION` (the four proven arenas), seeded;
  `make skirmish` plays a random arena by default. Faction note below.
- **Stretch:** `make arena-candidates` (generated layouts for a human to approve, never shipped automatically);
  destructible cover written up as a cross-stream proposal (arenas.md).

**Which arena suits which matchup** (weak evidence: gangs vs syndicate, 6 seeds, colours not counterbalanced): the
syndicate won everywhere; the gangs did least badly on the **boulevard** (open avenues let the swarm close to 30 m at
once) and worst in the **yard** (lanes feed them in piecemeal). That's the opposite of the brief's guess, so re-test
once combat's gangs work lands. Expected from the static numbers, not yet measured: long guns and artillery want the
boulevard, burners and scouts the yard, tanks the pit.

**Decisions:** v1 layouts unchanged and `Arena.DEFAULT_LAYOUT` stays foundry, so tests and the sim baseline never
moved (only the player's entry point is random). New arenas get new names; foundry, scrapyard and furnace are kept
(the announcer and tests use them). Low cover is 0.9 m (below every muzzle) because the eye ray is at 1.3 m and
muzzles at 1.05-1.27 m: there's no height that blocks fire but not sight. Fairness is a paired margin, not a win
rate, because army strength decides the winner.

**Questions for the lead** (none blocking):
1. Play `make skirmish` a few times (a random arena each time), or name one: `make skirmish ARENA=yard`
   (`boulevard`, `pit`, `boneyard`). Which fight is fun, and which is boring?
2. Should a player pick the arena (a menu), or is random the right default?
3. Generated layouts: worth growing (`make arena-candidates CHARACTER=yard`, open build/arena-candidates/index.html),
   or are hand-built arenas enough?
4. Destructible cover (container stacks that lose levels): worth scheduling? The proposal is in arenas.md.

**Known issues:** the title screen and `make skirmish-factions` don't pass `--arena=random` yet (control's, requested),
so they play foundry. The announcer has no names for the new arenas and would name "random" (audio's, requested; it
falls back to silence). Doctrine reads every kit map as "dense" (ai's call, evidence sent). Flanks are rarely used on
dense maps: the CPU funnels to the control point.

**What to playtest:** `make skirmish` (random arena), `make skirmish ARENA=pit`; pictures: `make remote
T=arena-shots`; numbers: `make arena-report` (plots in build/arenas/).

**Next steps:** re-run `make arena-series` with combat's `--swap-armies` counterbalance once it merges; re-test the
faction matchups with colours counterbalanced; an arena menu with control; a fifth, open arena as the long-range
contrast if the lead wants one (`make arena-candidates CHARACTER=open` is a start).

**Merge notes (shared files):** `mk/play.mk` `skirmish` adds `--arena=$(or $(ARENA),random)`. New files only elsewhere:
`game/arena/arena_kit.gd`, `tests/test_arena_kit.gd`, `tests/arena/arena_probe.gd`, `tools/{arena_report,arena_series,
arena_generator}.py`, `mk/arena.mk`, `arenas/{yard,boulevard,pit,boneyard}.json`, `_agents/arenas.md`.

### Log

- 2026-09-17: brief written for round 5.
- 2026-09-17 (worker started): plan, in order, smallest foundation first:
  1. **X1 schema v2 (CP2)**: `ArenaKit` (game/arena/arena_kit.gd) as the gameplay truth of each kit prop; `props`,
     `spawn_zones`, `lanes`, `regions` in the layout; the loader normalizes colliding props into `obstacles` so every
     current consumer (CoverMap, radar, ElementSituation, navmesh) sees them with no change on their side. Tests first
     (`tests/test_arena_kit.gd`). *Decision:* v1 layouts stay valid and unchanged, so the sim baseline doesn't move.
  2. **X2 `_agents/arenas.md`**: the vocabulary grounded in measured mechanics (eye 1.3 m, muzzles 1.05-1.27 m,
     doctrine's 45 m terrain count, 85 m support range), rules of thumb, and the measures.
  3. **X3 four arenas** (yard, boulevard, pit, boneyard) authored in `tools/make_arenas.py`, iterated against
     `tools/arena_report.py` (static views, routes, exposure, plots). *Decision:* new names; foundry/scrapyard/furnace
     keep their names and content (the announcer and tests reference them).
  4. **X4 proof**: swap-bases fairness and seeded series per arena, dynamic measures into arenas.md.
  5. **X5 dressing** with render's M1 budget, **X6 selection** (random-but-fair default; the sim baseline pinned to
     foundry so a new default doesn't move the hash).
- 2026-09-17: **X1 done, CP2 announced** (commit 56dd411; `make remote T=check` green, 850 passed, sim baseline
  unchanged). Mutation-checked: without the spawn-clearance rule the buried-spawn test fails. Merged CP1 from main.
- 2026-09-17: X2 drafted (`_agents/arenas.md`), X3 four draft arenas (yard, boulevard, pit, boneyard) with
  `make arena-report` (static views and routes, plots in build/arenas/), X4 tooling (`make arena-series`: swap-bases
  mirror matches through `tests/arena/arena_probe.gd`). First probe (yard, 40 s): median hit range 44 m, 57% of
  unit-time hidden.

- 2026-09-17: render shipped the kit slots (barricade, floodlight, sign, wreck fit) and two floor fixes; merged main.
  `make arena-shots` screenshots of yard, boulevard, pit, boneyard, foundry looked at: containers and screens read, the
  fog of war bends around cover in the skirmish view. Fixed from them: the boulevard's south screen showed green its
  back (screens now face their own half's base); the boneyard had no screen.
- 2026-09-17: **X6** `--arena=random` (seeded pick from `Arena.ROTATION`), `make skirmish` defaults to it.
  Decision: `Arena.DEFAULT_LAYOUT` stays foundry, so headless runs, tests and the sim baseline never change; only
  the player's entry point is random.
- 2026-09-17: finding for ai: doctrine's terrain count (every obstacle within 45 m, 5+ = dense) reads kit-built maps
  as dense on 86-95% of the field; `make arena-report` shows the share as counted today, sight-blocking only, and
  with touching boxes merged (boulevard 92% -> 46% dense). Sent to the orchestrator.

- 2026-09-17: **X4 first series** (5 arenas × seeds 1-6 × both bases, Condemned mirror at 5200; numbers in
  arenas.md). No arena shows a base advantage distinguishable from zero. The win rate can't show one: each team's
  army is seeded separately, army strength decided every match, and no winner flipped on a base swap. So the fairness
  measure is now the paired surviving-share margin. The maps change how fights look (hidden time 36% → 58%, p90 hit
  range 74 → 57 m, the pit sends 30% of unit-time around its ring) but not who wins, and median hit range is 38-43 m on
  every map, foundry included. Seeds 7-18 on the four new arenas are queued on builder0 to tighten the yard and
  boneyard.
- 2026-09-17: **stretch** `make arena-candidates` (generated layouts for a human to approve; see arenas.md).

### Requests to other streams
- **render (done 2026-09-17):** visual slots for the new kit types: `prop.barricade` (6 × 0.9 × 0.8 m jersey barrier run; a scaled
  `prop.wall` stands in), `prop.floodlight` (2.4 m footing of a floodlight tower; a scaled `prop.crate` stands in),
  `prop.sign` (decoration on a post, `setup(prop)` gets `sign`; shows nothing today). `prop.wreck` placed by a layout is
  a 3.2 × 2.0 × 6.4 m box. Every prop visual gets `setup(prop)` with its look keys.
- **audio:** display names for the new arenas in `assets/announcer/lines.json` → `arena` (the Container Yard, the
  Boulevard, the Pit, the Boneyard).
- **ai:** lanes and regions are readable (`Arena.lanes_of`, `Arena.regions_of`). Suggested: doctrine's terrain class
  counts touching boxes as one piece of cover and skips low cover (evidence: `make arena-report`).
- **control:** pass `--arena=random` when the title screen starts a skirmish and in `make skirmish-factions`, or offer
  an arena pick (`Arena.layout_names()`; layouts carry `title` and `note`).
- **audio:** the booth should name `Arena.active["name"]`, not the `--arena` flag (which can be `random`).

### Merge notes (shared files)
- `mk/play.mk` `skirmish`: adds `--arena=$(or $(ARENA),random)`. That's the only shared-file edit. The sim-baseline
  pin isn't needed: the default layout didn't change.
