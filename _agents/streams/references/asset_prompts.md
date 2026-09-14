# Prompt library and style guide for AI-generated models

> Assets stream, 2026-09-14. Use with `make assets-generate` once a key exists
> ([asset_services.md](asset_services.md): Meshy first). Untested against a real generator (no key
> overnight): treat these as a starting point and record what works in the **Results log** below.

## The look in one paragraph

A cyberpunk gladiator arena: *Mad Max × Death Race × Blade Runner*. Vehicles are **scrap-built war machines**:
welded plates, exposed bolts, cages, spikes kept short, and one clear silhouette per class. Surfaces are **dark and
weathered** (gunmetal, rust, oil stains, chipped paint), so the **neon reads**: thin strips of cyan `#00F3FF`, pink
`#FF0099`, or purple `#D900FF`, plus amber hazard lights. The camera is an RTS camera 20–60 m away on a phone
screen, so **big shapes beat small detail**. A detail smaller than about 15 cm on a tank won't be seen.

## Rules that make generated models pipeline-friendly

| Rule | Why | How in the prompt / options |
|---|---|---|
| One object, no ground plane, no base, no scene | the normalizer fits the whole bounding box to the slot | "single isolated object, no ground, no pedestal, no background" |
| Front view is unambiguous | bounds can't tell forward from backward (`--forward` is manual) | describe the front: "cannon pointing forward", "sloped front armor" |
| Separate parts by name when possible | hull / turret / cannon are separate slots | Meshy `model_type: smart-topology` separates parts; otherwise generate hull, turret, cannon as three prompts |
| Neutral team paint area | `set_team_color` tints materials named `paint*`/`Main` | "large flat painted armor panels in plain light grey"; after import, name that material `paint` |
| Emissive strips as separate, saturated color | the pipeline can mark them emissive (`--emissive=glob:energy`) or use Meshy's emission map | "thin glowing cyan neon strips along the edges"; meshy-6 + `enable_pbr` returns an emission map |
| Low poly on purpose | budgets: hull 8k, turret 4k, cannon 2k, props 2–3k | `target_polycount` is set from the slot budget automatically; add "low poly, game asset" |
| No text or logos | generators garble text; signage is procedural (neon_kit billboard) | "no text, no letters, no logos" |
| Matte, not glossy PBR | Compatibility renderer, no SSR; gloss reads as noise at distance | "matte weathered metal, stylized" |

Always append: **`, low poly game asset, single isolated object, no ground, no background, no text, stylized, matte`**.

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

## Results log (fill in once keys exist)

| date | provider / model | slot | prompt id | tris out | worked? | notes |
|---|---|---|---|---:|---|---|
| | | | | | | |
