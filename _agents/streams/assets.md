# Stream: assets (arena kit, faction vehicles, outriggers)

> Read [../orchestration.md](../orchestration.md), [../art_direction.md](../art_direction.md),
> [../game_design.md](../game_design.md) (*Factions*, the wear spectrum, *The arena kit*, *Artillery deploys before
> firing*), [../workstreams.md](../workstreams.md) (K4 is yours; lead gate 1), [references/concept_review.md](references/concept_review.md)
> (the review page), [references/asset_prompts.md](references/asset_prompts.md), and `assets/README.md`. You own models,
> props, dressing, and galleries in `game/theme/**` not owned by feel (`roster/`, `arena_kit/`, `prison_dozer/`,
> `gallery/`, new `factions/`, cyberpunk vehicle and prop parts), `assets/**` except `assets/audio/` and
> `assets/announcer/`, `tools/assets/`, `mk/assets.mk`, `art_direction.md`, and the asset references.

## The lead's direction (2026-09-15)

> *"we've already talked about, mostly around more re-usable assets in the map (big TV screen, 20 or 40 foot
> stackable containers), then we want to go ahead and generate assets for our fleet of vehicles we'll want to create
> for our new factions."* Earlier: *"I assume the asset size is going to balloon with more and more sprites in our map.
> I'm thinking 2 highly re-usable things: 20 foot milvan containers (or 40 foot) that I assume we could re-stack on the
> map. And I'm also thinking some Syndicate / Blade Runner vibes by putting towering TV screens on the map … where we
> could put rolling ads in the arena … these ads would all be super dystopian."* On factions: *"we'll make them wildly
> different characteristics"*; *"The Law should look more professional than the condemned, clearly but all their
> vehicles should still be pretty worn down (showing the signs of a defective state). The Syndicate of course will have
> an ivory tower vibe"*; and *"something like 'The Dreadnaught' out of Death Race - a suped up fuel truck where the back
> has been converted to a giant war machine."* Spending: *"I don't really care about the Meshy spending cap, just don't
> be wasteful."* Decided with the lead: **concepts for all three new factions** this round.

## Where things stand (round 2)

- Themes `roster` (caged dune buggy scout, garbage-truck IFV, crane-carrier artillery, flatbed Lancer) and `arena_kit`
  (a Meshy container prop, blast barrier, container grandstands with an instanced crowd, gate, floodlight towers),
  textured asphalt floor, the tap-to-approve review page (`make art-review-page`), the Meshy ledger.
- Web `.pck` 20.3 MB; the roster gallery draws ~331k primitives for 10 vehicles plus the arena (phones want far less).
- The artillery's outrigger legs are baked into its hull, deployed.
- Round-2 record: [archive/round2/art.md](archive/round2/art.md).

## Backlog (ungated items first; gated items as reviews come back)

**X1. Stackable shipping containers** (game_design.md *The arena kit*): 20 ft (6.06 × 2.44 × 2.59 m) and 40 ft (12.19 m)
meshes, a few hundred triangles each, sharing one corrugated-steel texture set (hand-built or CC0: record licenses;
Meshy only if it clearly wins). Per-instance variation in the shader (paint, rust, doors, faction stencils), stacking,
one MultiMesh per kind. A layout type `container_20`/`container_40` with `stack` for combat's arena data (Status
request: combat owns layouts and collision). Gallery shots of a container yard.

**X2. Giant ad screens.** A tall screen prop (frame, supports, emissive panel) with a shader that plays still ads and
flipbooks: slow pan and zoom, scanlines, flicker, glitch transitions, and a font overlay for text and live match
content; a per-ad average color that tints a fake light splat on the ground. Ship with placeholder ads; **ad art and
copy are the lead's call** (announcer's humor direction applies: believable, slightly off). A slot and a layout type.

**X3. Faction concepts (lead gate).** For the road gangs, the Law, and the Syndicate: 2–3 concept options per role
(scout, IFV, tank-class, artillery, special), following the wear spectrum and each faction's roster sketch in
game_design.md (the gangs' tank-class is the fuel-truck war rig; the Law's tank is an 8×8 assault gun; the Syndicate's
is a curvy hover tank). Our own designs and names; no text in generated images. One review page per faction, listed
under *Waiting on the lead*. Iterate prompts at the concept stage; don't send duplicates to 3D.

**X4. Approved faction vehicles in 3D.** Image-to-3D for approved concepts only, through the pipeline, into
`game/theme/factions/<faction>/` as K4 slots, one texture set per unit, triangle budgets from slot_contracts.md, and
`make vehicle-gallery FACTION=<id>` screenshots next to the concepts.

**X5. Artillery outriggers as parts.** Separate the crane carrier's four arms (or replace them with hand-built
telescoping beams using its textures) and animate from `set_deployed(ratio)` (combat's X5). Gallery captures stowed,
half, and deployed.

**X6. Size and draw budget.** Reuse texture sets, generate lower-detail versions at distance, and report the web
`.pck` size and gallery primitives before and after. Target: no growth in `.pck` from X1–X2; faction vehicles live in
their own theme folder (excluded from the web export until factions are playable).

- **Stretch:** neon billboards and scrap barricades for the stands; a wreck husk concept (gated) for combat's wreck
  event.

## How to verify

`make remote T=check` (sim baseline unchanged), `make remote T=vehicle-gallery`, arena-kit gallery shots, the
review pages, `.pck` size and primitive counts; look at every screenshot next to its concept.

## Don't touch

Layouts, collision, and navigation (combat), effects and sound (feel), brains (ai), UI (control).

## Waiting on the lead

**Faction concept review (X3), published 2026-09-15.** Tap Approve on at most one option per group (add words if you
like); only approved concepts go to 3D (≈15 credits each, 15 if one per role). Prompts and tradeoffs are on the cards;
the spec is `assets/review/batches/round3_factions.json`.

| Faction | Page | Groups (options) |
|---|---|---|
| Road gangs | https://claude.ai/artifact/7j75ZXkvHiqHoZ4ACTBKqr | tank `gangs_tank_a` semi tanker, `_b` rigid tanker, `_c2` mining haul truck · scout `_a` dune buggy, `_b` rat rod · IFV `_a` 1950s pickup, `_b` muscle-car ute · artillery `_a` logging-truck catapult, `_b` tow-wrecker catapult · special `_a` war-drum truck, `_b` resupply tanker |
| The Law | https://claude.ai/artifact/TytWFgfoKRpRtbFSu2QazG | tank `law_tank_a` 8×8 assault gun, `_b` airport crash tender, `_c2` heavy transporter · scout `_a` sedan, `_b` pickup · IFV `_a2` 6×6 MRAP, `_b` retired APC · artillery `_a` gas rocket pod truck, `_b2` command van launcher · special `_a2` water cannon, `_b` sonic emitter |
| The Syndicate | https://claude.ai/artifact/BBfezgVH9zmLmbCcYKtEL8 | tank `syndicate_tank_a` yacht hull, `_b` pebble monocoque, `_c` supercar · scout `_a` teardrop, `_b` manta wing · IFV `_a` pearl gunship, `_b` black-glass limousine · artillery `_a` petal launch cells, `_b` ring with missile wings · special `_a` shield projector, `_b` Lancer laser |

**Wreck husk review (stretch), published 2026-09-15:** https://claude.ai/artifact/NXAg84GYQ8uUb7QsdghXvF: `wreck_a`
burned-out armored truck shell, `wreck_b` crushed scrap-heap hulk (one model for every unit, scaled to its hull; spec
`assets/review/batches/round3_wrecks.json`).

Read back with `read_db` (collection `decisions`) per page, then `make art-apply-decisions DIR=… URL=…`.

## Status

_Updated 2026-09-15 (worker). **Report: every backlog item is done or waiting on the lead's taps (X3 → X4 models; the
wreck concepts).** Baseline `make remote T=check` was green before any change; every commit passed it, and the last
(e60d9dd) did too: 437 tests, every smoke, sim baseline unchanged (assets never touch the simulation). `make web-smoke`
passes locally (builder0's Chrome has no WebGL2, so it can't run there: proposed trip-up 6)._

**Plan and outcome** (order changed from the brief on purpose: the faction concepts went first because the lead's
review is the long pole; everything ungated ran while it waits)
1. X3 faction concepts → **done, waiting on the lead** (three review pages above)
2. X1 stackable containers → **done**
3. X2 giant ad screens → **done** (placeholder ads and copy until the lead picks)
4. X5 artillery outriggers as parts → **done**
5. X6 size and draw budget → **done**, with ~0.8 MB of growth rather than none (numbers below)
6. X4 approved faction vehicles in 3D → **groundwork done** (K4 slots, faction gallery); models wait on the lead's taps
7. Stretch → neon signs and scrap barricades **done**; wreck husk concepts **waiting on the lead**

**Done**
- **X3 concepts** (1a29652, 5e1d64f): 33 options (3 factions × 5 roles; 3 tank-class options, 2 for each other role) on
  one page per faction. New `tools/assets/concept_batch.py` (`make art-concept-batch SPEC=…`): concepts as a committed
  spec (faction lead sentence + subject + faction look + no-text tail), generated in parallel, registered once,
  `supersedes` for regenerated failures; `review_page.py --groups/--intro` builds a page per faction; `generate.py`
  gained `--concept-task` (re-download a paid task without a new request) and download retries.
  - Pilot first (one tank per faction, 27 credits) to check the style: gang turrets came out small (prompts now say
    "oversized") and the Syndicate read a little like a concept car (its look now asks for "heavy and armored like a
    real military machine").
  - Looked at every image before publishing; regenerated 5: three Law concepts had lettering baked in ("POLICE", "RIOT
    ROCKET TRUCK": the Law's look now forbids words and insignia), the Law water cannon read as a tank gun, and gang
    tank C was a near-copy of B.
  - **Spend: 342 credits** (38 concept images), then 18 for the two wreck concepts: **360 this round, balance 328**.
    Every request is in `assets/meshy_ledger.md`.
- **X1 containers** (43faff4): `prop.container_20` / `prop.container_40` at ISO sizes, ~314 triangles each, built in code
  (`ContainerMesh`); one shared texture set (`make assets-containers`: CC0 ambientCG rust + chipped-paint erosion
  order, a stencil atlas); `container.gdshader` picks paint, rust (gathers along rails and bottoms), stencil and door
  opening per instance; `ContainerYard` draws every container of a kind as one MultiMesh; stacks via `setup(obstacle)`
  `stack` or the Arena's height scale; faction yards (`faction`: condemned, law, syndicate, gangs). 7 tests.
  Screenshots: `make arena-kit-gallery` → `build/screenshots/arena-kit-{close,yard,doors,screens,overview}.png`.
- **X2 ad screens** (7cf0287): `prop.ad_screen` (7 × 14 m LED wall, legs, plinth, beacon); `AdBroadcast` channels render
  the ad into a small 2D feed shared by every screen on the channel (art with a slow push-in, flipbooks, copy set in
  Oswald, a ticker), `ad_screen.gdshader` (scanlines, LED grid, flicker, glitch between ads and on big kills), a ground
  light pool in the ad's average color; the cyberpunk venue raises 4 screens over the short walls on 2 channels
  (visible behind the title screen). The live card counts confirmed kills and odds from `Match.tank_destroyed`. Six
  placeholder ads (`make assets-ads`). 8 tests.
- **X5 outriggers** (8e883d6): `OutriggerRig` cuts the crane carrier's four legs out of its generated hull by region
  boxes (shared per mesh, no pipeline rebuild) and `unit.artillery.hull` `set_deployed(ratio)` slides them in and lifts
  the jacks (0 = stowed, 0.5 = beams out, 1 = braced, the default). 3 tests; `make artillery-deploy-shot`.
- **X6 size and draw budget** (3df61be + neon atlas): web `.pck` measured on builder0 with `make remote T=assets-report`:
  **21.3 MB** (round 2: 20.3 MB). The arena kit's share, from `pck_report.py --group`: containers **236 KB**, screens,
  ads and neon signs **~530 KB** (after halving the neon atlas, 644 → ~530), Oswald **33 KB**: about **0.8 MB**, not
  zero. Cuts made to get there: analytic corrugation instead of a normal map, container maps at 256 px, ad stills at
  256 × 512, flipbook frames at 128 × 256, Oswald subset to Latin (172 → 49 KB source), Basis Universal on everything
  new. Faction vehicles will live in `game/theme/factions/` (to be excluded from the web export until factions are
  playable). Draws (`make arena-kit-measure`, yard view, tier high): kit hidden 81 draws / 49k primitives; 36 containers
  +4 draws / +15.7k primitives (two MultiMeshes, with shadows); 6 screens +24 draws / +0.5k primitives. The venue adds 4
  screens, one sign MultiMesh and 4 container stacks (inside the existing container draws) to every match.
- **Stretch** (3df61be, 06fb861): neon tube signs crown the grandstands (AquaCorp, Organ Futures, Syndicate Life, Live
  from the Pit; one MultiMesh, warm and violet neon only, never team colors); gang-tagged container stacks barricade
  both gates (reusing X1, no new textures); two wreck husk concepts are on their own review page.
- **X4 groundwork** (3df61be, ungated): K4 slot contracts `unit.<faction>.<role>.<part>` in `AssetContracts` (fitted
  to the Condemned unit in the same role), faction themes under `game/theme/factions/<faction>/generated` found by the
  checker, `FactionArt` (which model fills each role), `make vehicle-gallery FACTION=<id>` (a labeled empty spot for
  roles not built yet). 3 tests. `tools/assets/model_batch.py` sends every approved, not-yet-built concept to
  image-to-3D in parallel (`--list` shows the credits first); generate.py still enforces the gate.

**Decisions**
- No people in faction concepts (image-to-3D turns riders into blobs); crews come later as cheap figures.
- Cool neon (cyan, magenta, blue strobes) in faction prompts becomes the team accent through the unit shader; red and
  amber lights keep their color. So the Law's blue strobes will glow in team color and its red ones stay red.
- The Syndicate's special and the gangs' special each show two different jobs (the roster sketches say "or"); the
  lead's pick decides the role.
- Containers are code-built meshes plus CC0 textures, not Meshy: simple hard-surface shapes, exact ISO sizes, and a 40 ft
  mesh of its own for free. Corrugation is analytic in the shader (crisp up close, no shimmer at distance, no texels).
- Door tags live in UV2, not vertex colors: the Compatibility renderer multiplies vertex COLOR by MultiMesh instance
  colors, which are zero when a MultiMesh doesn't use them (doors silently never opened). Proposed trip-up below.
- Screens share one 2D feed per channel instead of a video or a feed per screen; text is engine-set, never baked. Two
  channels so neighboring screens don't mirror each other. Low tier redraws the feed at half rate.
- Outriggers are cut at load time from the existing model rather than re-split in the pipeline: no Meshy re-run, the
  legs keep the hull's texture set, and the cut is cached per mesh.
- Rendering targets run locally: builder0 had no logged-in desktop (no Xwayland auth), so `make remote T=<shots>` fails
  with "X11 Display is not available". The windowed runs are short and take no input.

**Questions for the lead**
1. **Meshy balance:** 328 credits left. One 3D model per role is 15 × 15 = 225 credits (+15 for a wreck), which leaves
   ~90 for retries. A top-up may be needed before round 4's assets.
2. **Ad art and copy** are placeholders (`tools/assets/build_ads.py`, `game/theme/arena_kit/ads/ads.json`): Syndicate Life
   "Coverage that outlives you", AquaCorp "Clean water. Every day you qualify.", Office of the Warden "Safer streets
   start with a report", Organ Futures "Invest in tonight's champions", The Freedom Program "Win your freedom tonight",
   and a live card. Keep, rewrite, or send real ad concepts through a review page?
3. **Container stencil brands** (AquaCorp, Organ Futures, a WRECKERS gang tag, PRISON TRANSPORT, EVIDENCE, IMPOUND LOT 7,
   DETENTION STORAGE) are ours and fictional; say if any should change.

**Proposed trip-ups** (for orientation.md; orchestrator's file)
1. **A MultiMesh without `use_colors` zeroes vertex `COLOR` in the Compatibility renderer** (it multiplies by the
   instance color). Container doors tagged by vertex color never opened; tags moved to UV2.
2. **Headless runs don't keep MultiMesh instance data:** `get_instance_transform()` returns zeros under the dummy
   renderer. Keep a CPU copy for tests (ContainerYard entries, NeonSigns placements metadata).
3. **Nodes created in `var x := Node.new()` initializers leak if the owner is freed before `_ready`** (tests that
   instantiate a scene and free it). Create them in `_ready`, or free orphans on `NOTIFICATION_PREDELETE`
   (`cyber_vehicle.gd`).
4. **A fresh worktree has no `assets/incoming/meshy/`:** three paid concept downloads failed on the missing folder.
   `generate.py` now creates it and can re-download a finished task (`--concept-task`).
5. **builder0 may have no logged-in desktop:** `make remote T=<screenshot target>` fails with "X11 Display is not
   available"; run short rendering targets locally.
6. **builder0's Chrome has no WebGL2:** `make remote T=web-smoke` fails with "WebGL2 - Check web browser configuration"
   before Godot starts. Run web smokes locally (SwiftShader works there).

**Requests to other streams**
- **combat (layouts, C5):** obstacle types `container_20` [6.06, 2.59, 2.44] and `container_40` [12.19, 2.59, 2.44] with
  an optional `stack` (collision height = 2.59 × stack; one high is hull-down cover, two high blocks sight), and
  `ad_screen` with a plinth footprint [7.4, 1.4, 1.4]. Please call `visual.invoke("setup", [obstacle])` on obstacle
  visuals (as `_build_hazards` does) so layouts can set `stack`, `faction`, `paint`, `stencil`, `rust`, `doors`,
  `channel`; without it a height-scaled visual still stacks. Rows are in slot_contracts.md.
- **combat (X5 deploy):** call `invoke("set_deployed", [ratio])` on the artillery's hull slot as it deploys and packs up.
- **control / announcer (later):** `AdBroadcast.channel(node, "arena").post_live({headline, fine_print})` puts anything on
  the screens' live card (score, odds, the announcer's hype line).

**Known issues**
- The arena kit adds ~0.8 MB to the web `.pck` (target was no growth); the biggest pieces are the placeholder ads and the
  container texture set. Real ads chosen by the lead should keep to 256 × 512 stills.
- The screens' live card finds the Match by searching the scene a few times after it appears; a direct hook from
  control or the announcer (`post_live`) would be cleaner (request above).
- Outrigger leg boxes are tuned to this crane carrier's mesh (`artillery_part.gd` LEG_BOXES); a new artillery model needs
  its own boxes.
- Barricade containers outside the gates aren't hidden by the FX lab's venue toggle (they draw with the containers).
- Gameplay can't place containers or screens as cover until combat adds the obstacle types (request above).

**What to playtest**
- `make title` or `make skirmish`: the four screens over the short walls (ads cycle every ~8 s with a glitch; the live
  card shows kills and odds once units die), neon signs on the stands, gang container barricades beside the gates.
- `make arena-kit-gallery` then open `build/screenshots/arena-kit-*.png`: container yard (stacks, open doors, each
  faction's stencils), screens on two channels, the 200 m overview. Windowed and interactive:
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . res://game/theme/gallery/arena_kit_gallery.tscn`
- `make artillery-deploy-shot`: three crane carriers stowed / half / braced.
- `make vehicle-gallery FACTION=condemned` (all five roles) and `FACTION=gangs|law|syndicate` (empty until models land).
- The review pages in *Waiting on the lead*.

**Next steps**
1. When the lead taps: `read_db` each page → `make art-apply-decisions`, copy the decisions here, then
   `tools/assets/model_batch.py --list` and run it (≈15 credits per model).
2. For each model: `make assets-view IN=assets/incoming/meshy/<id>_t2.glb SPLIT=1`, write a recipe
   (`tools/assets/build_factions.sh`, like build_roster.sh) normalizing into `THEME=factions/<faction>` slots
   `unit.<faction>.<role>.*`, then `make vehicle-gallery FACTION=<id>` next to the concepts, and add
   `game/theme/factions/*/generated/*` to the web/server `exclude_filter` (shared file) until factions are playable.
3. An approved wreck: normalize into a `prop.wreck` scene for feel's wreck effects.
4. After combat adds the obstacle types, an arena layout built from containers (combat owns `arenas/`) and a
   swap-bases fairness run.

**Merge notes**
- **Shared-file edits:** `Makefile` (`LIGHT_GOALS` += `art-concept-batch`); `mk/fx.mk` (`vehicle-gallery` passes
  `FACTION=` as `--gallery-faction` and names the screenshot per faction); `game/theme/game_theme.gd` (additive slot rows
  `prop.container_20`, `prop.container_40`, `prop.ad_screen` in DEFAULT_SLOTS).
- **Owned paths:** `game/theme/{arena_kit,cyberpunk,gallery,factions}/`, `assets/{pipeline,review,fonts,CREDITS.md,
  meshy_ledger.md}`, `tools/assets/`, `mk/assets.mk`, `tests/test_assets_*.gd`, `_agents/art_direction.md`,
  `_agents/slot_contracts.md` (new rows).
- **Contracts:** K4 slot ids live in `AssetContracts` and `FactionArt`; new slot rows (containers, ad screen,
  `set_deployed`) in slot_contracts.md. No gameplay code changed; the sim baseline is untouched.
- `dozer_part.gd` gained a `_prepare_model()` hook and `cyber_vehicle.gd` frees an orphan mesh node on predelete (both
  assets-owned, used by every generated unit).
- Rescue before removing the worktree: `assets/incoming/meshy/` holds 40 concept PNGs and the artillery source
  (`rsync -a --ignore-existing assets/incoming/ ~/projects/godot/assets/incoming/`), plus `assets/incoming/ambientcg/`.
