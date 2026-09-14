# Art direction: the north star

> **Source of truth for the game's style and setting.** Decided by the lead on 2026-09-14. Every stream that
> makes or places art (look & feel, assets, garage, HUD, marketing) designs toward this. It sits *on top of*
> the established cyberpunk theme (neon palette, the mavlink-hud HUD language in `streams/look_and_feel.md`);
> it doesn't replace it.

![North star: the Death Race prison dozer](art/north_star_prison_dozer.jpg)

The lead, on seeing this concept: *"the death race prison dozer absolutely captures the vibe of the entire game!"*

## The vibe in one paragraph

**Death Race is the spine, Mad Max is the build method, Blade Runner is the light.** Every war machine is a
**repurposed civilian or industrial vehicle** (a prison transport, a mining bulldozer, a school bus, a garbage
truck, a tow rig), converted by whoever runs the arena into a gladiator weapon: riveted slab armor bolted over
the original body, grilles over the windows, chains, short brutal spikes, a dozer blade or ram, tracks
grafted under a road chassis. The materials are **real and filthy**: blackened gunmetal, grime, rust, oil,
worn yellow-black hazard stripes. It's lit like a **Blade Runner night**: harsh magenta and cyan neon light
bars glowing behind grilles and along seams, red warning lights, amber beacons. **Photoreal and grounded, never
cartoon or toy-like.**

## Rules for every piece of art

| Do | Don't |
|---|---|
| Base each vehicle on a recognizable real vehicle that's been brutally converted (you should be able to tell what it used to be) | Invent clean sci-fi hovertanks or generic "cool tanks" |
| Riveted slab armor, steel grilles over openings, welded chains, short spikes, dozer blades and rams, sheet-metal track skirts | Smooth, sleek, or pristine surfaces |
| Blackened gunmetal and dark steel as the base; rust, grime, oil, soot as the wear | Bright or saturated base paint; plain flat colors |
| Worn **yellow-black hazard stripes** as the recurring graphic motif | Logos, readable text, clean decals |
| **Neon lives behind or inside things**: light bars behind grilles, strips in armor seams, magenta + cyan, plus red warning and amber beacon lights | Neon as outlines on everything, or a cartoon glow |
| Heavy, low, wide, top-heavy silhouettes that read from an RTS camera; a distinct turret or weapon on top | Thin, spindly, or detail-only silhouettes that vanish at 40 m |
| Photoreal, gritty, cinematic concept art as the reference target | "Stylized", "toon", "low-poly-looking" style (the first Meshy concept was rejected for looking like a cartoon) |

**Paint and team identity** (the lead's standing direction): players **paint the whole vehicle** (cosmetic, over
the grime), and **friend or foe is shown by accent lights** (the neon light bars and warning lights), not by hull
color. The materials and wear stay the same whatever the paint.

**The arena follows the same logic:** a repurposed industrial site (a prison yard, quarry, scrapyard, or rail
depot) turned into a night-time gladiator venue: floodlights, chain-link, concrete barriers with hazard stripes,
shipping containers, neon signage behind grilles, wet reflective ground.

## The prompt that produced it (reuse its structure)

Meshy text-to-image, `nano-banana-pro`, task `01a09fec-d5c3-700a-bce1-3cdf54384292`:

> Photorealistic concept art of an arena death-race battle tank, Death Race meets Mad Max. A heavy tracked war
> machine converted from an armored prison transport and a mining bulldozer: thick riveted slab armor, narrow
> slit viewports behind steel grilles, welded chains, short brutal spikes, sheet-metal skirts over the tracks,
> blackened gunmetal with worn yellow-black hazard stripes, grime and rust. Squat heavily armored turret carrying
> a long thick-barreled cannon. Harsh neon accents in the Blade Runner style: magenta and cyan light bars behind
> the grilles and red warning lights. Full vehicle in frame, three-quarter front view from slightly above,
> isolated on a plain dark grey studio background, no ground, no people, no text, no logos. Photorealistic,
> gritty, high detail, cinematic lighting, grounded real-world materials.

For a new unit, keep everything and swap the **base vehicle** and the **weapon**. For example, scout: *a converted armored
ambulance / rally truck*; artillery: *a converted garbage truck / crane carrier with a mortar battery*. Prompt
library and pipeline: `streams/references/asset_prompts.md`.

## Where this is referenced

`HANDOFF.md`, `vision.md` (the look), `workstreams.md` (product constraint 2), `streams/look_and_feel.md`,
`streams/assets.md`, `streams/garage.md`, `streams/references/asset_prompts.md`. Update those links if this file moves.
