# Prompt library and style guide for AI-generated models

> Assets stream, 2026-09-14. Proven against Meshy on 2026-09-14 (the lead's key): the production flow below produced
> the `prison_dozer` unit. Record new runs in the **Results log** at the bottom.

## The look: see [../../art_direction.md](../../art_direction.md) (source of truth)

The north star is the **Death Race prison dozer** (2026-09-14): a real vehicle brutally converted into an arena war
machine, photoreal and gritty, with neon behind grilles. **Concept images must be photoreal.** The first concept, which
had "stylized, low-poly game asset, plain light grey panels" in its prompt, came out looking like a cartoon and was rejected.
Game budgets (triangles, textures) are enforced by the 3D step and the normalizer, **never by the image prompt.**

## Production flow (proven 2026-09-14)

1. **Concept** (text-to-image, `nano-banana-pro`): start from the art direction prompt, swap the base vehicle and weapon.
   Generate several directions, and pick one with the lead.
2. **Turnaround** (image-to-image with the chosen concept as reference, `--multi-view`) so the 3D step sees every side.
3. **3D: image-to-3D Smart Topology (`meshy-t2`) from the chosen 3/4 concept**, textured with PBR. It won the side-by-side
   against multi-image `meshy-7` Ultra from the turnaround: T2 kept the neon bars, hazard stripes, red lights and emission map
   and delivers the model as ~280 separate islands (so turret and gun split cleanly); meshy-7 came back as a fused mesh with a
   flat dark texture and no emission map. Keep the turnaround for reference and for later meshy-7 experiments.
4. **Split + fit** with `--split=tank` (islands labelled hull/turret/cannon by geometry), `--scale-from`/`--deck-from`
   (turret on a tall hull's roof), `--attach-to=tank.turret` (the gun stays where it was generated, stretched only
   along its axis to the gameplay muzzle point), `--emission-energy` (generated emission maps come in dim).
   Recipe: `tools/assets/build_prison_dozer.sh`. Review with `make assets-unit THEME=<theme>` (close-up, day/night),
   `make assets-preview`, `make assets-web-gallery`.

```bash
tools/assets/generate.py --provider meshy --slot unit.tank --concept-only --prompt "<art direction prompt>" --name meshy/<unit>
tools/assets/generate.py --provider meshy --slot unit.tank --concept-only --reference assets/incoming/meshy/<unit>.concept.png \
    --multi-view --prompt "The same vehicle, identical design, turnaround views" --name meshy/<unit>_turn
tools/assets/generate.py --provider meshy --slot unit.tank --image-task <chosen concept task id> \
    --smart-topology --polycount 15000 --name meshy/<unit>
# (alternative, compared and not chosen for the dozer:)
tools/assets/generate.py --provider meshy --slot unit.tank --multi-image --image-task <turnaround task id> \
    --ai-model meshy-7 --ultra --polycount 30000 --name meshy/<unit>_m7
```

## Rules that make generated models pipeline-friendly

| Rule | Why | How |
|---|---|---|
| One object, no ground, plain dark background | the normalizer fits the whole bounding box to the slot | "isolated on a plain dark grey studio background, no ground, no people" (plus `remove_background`) |
| Whole vehicle in frame, three-quarter front view | the 3D step needs the full silhouette; the front must be unambiguous | "full vehicle in frame, three-quarter front view from slightly above" |
| A distinct turret/weapon on top | hull / turret / cannon are separate slots (split after 3D) | "squat heavily armored turret carrying a long thick-barreled cannon" |
| Neon as light bars and strips | becomes the emission map, then team accent lights | "magenta and cyan light bars behind the grilles and red warning lights" |
| No text or logos | generators garble text | "no text, no logos" |

Always append: **`Full vehicle in frame, three-quarter front view from slightly above, isolated on a plain dark grey studio background, no ground, no people, no text, no logos. Photorealistic, gritty, high detail, cinematic lighting, grounded real-world materials.`**

## Older per-part prompts (superseded; kept for props and parts only)

> These predate the art direction and ask for "stylized, low poly". For vehicles, use the production flow above
> (the whole unit, photoreal, split afterwards). Rewrite any of these toward the art direction before use.

## Vehicles (unit classes from `game/units/units.gd`; gameplay grows the catalog)

**Hero tank hull** (`tank.hull`, 2.4 × 3.6 × ≤1.6 m, forward −Z)
> Armored scrap-metal battle tank hull seen from above-front, wide low chassis with two heavy tank treads, welded steel plates and rivets, sloped front armor, exhaust pipes at the rear, large flat painted armor panels in plain light grey, thin glowing cyan neon strips along the side skirts, no turret, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Hero tank turret** (`tank.turret`, ~1.4 × 1.7 × 0.55 m)
> Squat angular tank turret made of welded scrap armor plates, flat bottom, hatch and periscope on top, plain light grey painted panels, one thin glowing cyan neon strip around the base, no gun barrel, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Cannon** (`weapon.cannon`, 2.5 m long, forward −Z)
> Long heavy tank cannon barrel with a boxy muzzle brake and heat-sink rings, dark gunmetal, a short glowing amber heat vent near the base, straight horizontal barrel, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Scout** (fast, light; hull budget applies)
> Fast light armored dune buggy on four big off-road wheels, roll cage, spoiler made of scrap sheet metal, exposed engine, plain light grey painted body panels, glowing pink neon underglow strips, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Artillery** (long-range; hull + a long `weapon.*` barrel)
> Heavy tracked self-propelled artillery vehicle made of welded rusty plates, long raised mortar barrel mounted on the back, stabilizer legs folded, hazard stripes, plain light grey painted armor panels, glowing purple neon strips, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Laser emitter** (`weapon.laser`, planned G7)
> Futuristic tank laser emitter, a long boxy barrel with three glowing cyan lens rings and cooling fins, dark gunmetal, straight horizontal barrel, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte
Then `--heat=*fin*` or a `heat` material so `set_heat(ratio)` makes the fins glow.

## Props (collision footprints fixed by gameplay; `stretch` fit)

**Crate / cover block** (`prop.crate`, 4.5 × 3 × 4.5 m, a cube, so prompt for boxy proportions)
> Stack of two rusty armored cargo crates welded together, square footprint, reinforced corners, hazard stripes, one amber warning light on top, thin glowing cyan neon strip along the edges, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Wall segment** (`prop.wall`, 18 × 3 × 1.5 m: generate a 3–4.5 m segment and tile with `--repeat=5x1x1`)
> Heavy concrete blast barrier segment, straight, chipped edges and exposed rebar, rusty steel cap along the top, a horizontal glowing pink neon light bar, graffiti-free, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte

**Arena dressing** (candidates; look & feel decides)
- *Wrecked car:* "burnt-out wrecked sedan with crushed roof and no wheels, rust and soot, one flickering cyan neon tube hanging off, low poly game asset, …"
- *Floodlight tower:* "tall steel floodlight tower with a cluster of four big lamps on top, cables, ladder, amber hazard light, low poly game asset, …"
- *Spectator cage:* "chain-link cage section on steel posts with barbed wire on top and pink neon strip along the base, low poly game asset, …"
- *Tire barricade:* "stacked tire barricade wall, three rows, chained together, low poly game asset, …"

## Image-to-3D (usually better control)

1. Sketch or collage a side-front 3/4 view on a flat grey background (or generate a concept image), with the silhouette readable at thumbnail size.
2. `make assets-generate PROVIDER=meshy SLOT=tank.hull IMAGE=<url or data URI> PROMPT="<texture prompt from above>"`.
3. The prompt becomes Meshy's `texture_prompt`; the image drives the shape.

## After generation (every model)

```bash
make assets-inspect IN=assets/incoming/<name>.glb SLOT=tank.hull           # what came back: size, tris, materials
make assets-normalize IN=assets/incoming/<name>.glb SLOT=tank.hull THEME=<theme> \
     ARGS="--forward=+z --tint=<paint material> --emission-map=assets/incoming/<name>.emission.png \
           --source='meshy task <id>' --license='Meshy Pro: customer owns output' --credit='generated with Meshy'"
make assets-gallery THEME=<theme>                                           # look at it next to the default tank
```

Check in the gallery: does the cannon's red muzzle marker sit at the barrel tip? Does the team tint land on
the paint and not the treads? Does anything glow?

## Results log

| date | step / model | input | output | credits | verdict |
|---|---|---|---|---:|---|
| 2026-09-14 | text-to-image nano-banana-pro | "stylized, low-poly-friendly, plain light grey panels" tank prompt | toy-like cartoon tank (`tank_v1`) | 9 | **rejected by the lead** ("looks like a cartoon"): never put game-budget words in concept prompts |
| 2026-09-14 | image-to-3D meshy-t2 | `tank_v1` concept | faithful 11.9k-tri model, 212 islands | 15 | faithful, but faithful to a rejected concept |
| 2026-09-14 | text-to-image nano-banana-pro ×3 | photoreal prompts: A Mad Max scrap, **B Death Race prison dozer**, C Blade Runner raider | three strong concepts | 27 | **B picked** as the art-direction north star |
| 2026-09-14 | image-to-image nano-banana-pro, multi-view | concept B | consistent front/back/side turnaround (needs edge-sliver trimming) | 9 | good |
| 2026-09-14 | image-to-3D **meshy-t2**, PBR | concept B (3/4 view) | 14.6k tris, 282 islands, base/normal/roughness/metallic/**emission** 2k | 15 | **chosen**: neon, stripes, lights kept; clean split |
| 2026-09-14 | multi-image-to-3D meshy-7 Ultra, PBR | concept B + 3 turnaround views | 30k tris fused, no emission map | ~35 | not chosen: flat dark texture, neon lost |
