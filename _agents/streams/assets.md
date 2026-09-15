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

Read back with `read_db` (collection `decisions`) per page, then `make art-apply-decisions DIR=… URL=…`.

## Status

_Updated 2026-09-15 (worker)._ Baseline `make remote T=check` green on builder0 before any change.

**Plan** (order changed from the brief on purpose: the faction concepts went first because the lead's review is the
long pole; everything ungated runs while it waits)
1. X3 faction concepts → **waiting on the lead** (three review pages above)
2. X1 stackable containers → in progress
3. X2 giant ad screens
4. X5 artillery outriggers as parts
5. X6 size and draw budget (measured before/after X1–X2, and again at the end)
6. X4 approved faction vehicles in 3D → after the lead's taps
7. Stretch: neon billboards and scrap barricades; a wreck husk concept (gated)

**Done**
- **X3 concepts** (commits 1a29652 and next): 33 options (3 factions × 5 roles; 3 tank-class options, 2 for each other
  role) on one page per faction. New `tools/assets/concept_batch.py` (`make art-concept-batch SPEC=…`): concepts as a
  committed spec (faction lead sentence + subject + faction look + no-text tail), generated in parallel, registered
  once, `supersedes` for regenerated failures; `review_page.py --groups/--intro` builds a page per faction;
  `generate.py` gained `--concept-task` (re-download a paid task without a new request) and download retries.
  - Pilot first (one tank per faction, 27 credits) to check the style: gang turrets came out small (prompts now say
    "oversized") and the Syndicate read a little like a concept car (its look now asks for "heavy and armored like a
    real military machine").
  - Looked at every image before publishing; regenerated 5: three Law concepts had lettering baked in ("POLICE", "RIOT
    ROCKET TRUCK": the Law's look now forbids words and insignia), the Law water cannon read as a tank gun, and gang
    tank C was a near-copy of B.
  - **Spend: 342 credits** (38 concept images), balance **346**. Every request is in `assets/meshy_ledger.md`.

**Decisions**
- No people in faction concepts (image-to-3D turns riders into blobs); crews come later as cheap figures.
- Cool neon (cyan, magenta, blue strobes) in faction prompts becomes the team accent through the unit shader; red and
  amber lights keep their color. So the Law's blue strobes will glow in team color and its red ones stay red.
- The Syndicate's special and the gangs' special each show two different jobs (the roster sketches say "or"); the
  lead's pick decides the role.

**Questions for the lead**
1. **Meshy balance:** 346 credits left. One 3D model per role is 15 × 15 = 225 credits, which leaves ~120 for retries
   and the stretch concepts. A top-up may be needed before round 4's assets.
