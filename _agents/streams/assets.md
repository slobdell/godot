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

- (nothing yet)

## Status

- 2026-09-15: brief written for round 3. Nothing started.
