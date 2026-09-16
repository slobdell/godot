# Asset credits and licenses

Every third-party model that ends up in the game (normalized into `game/theme/*/generated/`) is listed
here with the license **as stated on its source page**, checked on the date shown. The per-model
record (source URL, license, credit, pipeline options) is also kept in each theme's
`generated/manifest.json`, and `make assets-check` fails if a manifest entry lacks a source or license.

CC0 needs no attribution, but we credit creators anyway.

| Model(s) | Used for | Source | License (quoted from the page) | Checked |
|---|---|---|---|---|
| Quaternius **Animated Tank Pack**: tank `58c387b2-636f-49dc-a900-13b0852717d6.glb` | `kitbash`: `tank.hull`, `tank.turret`, `weapon.cannon` | https://poly.pizza/bundle/Animated-Tank-Pack-0tfvbeAJkU (also https://quaternius.com/packs/animatedtanks.html) | Poly Pizza: "Licence: Public Domain (CC0)". Quaternius: "License: CC0 … free to use in both personal and commercial projects." | 2026-09-14 |
| Quaternius **Toon Shooter Game Kit**: Container Small, Barrier Large, Street Light (+ others downloaded for evaluation) | `kitbash`: `prop.crate`, `prop.wall`, candidates | https://poly.pizza/bundle/Toon-Shooter-Game-Kit-qraiSXoAru (also https://quaternius.com/packs/toonshootergamekit.html) | "Public Domain (CC0)" / "License: CC0" | 2026-09-14 |
| Quaternius **Cyberpunk Game Kit**: Cyberpunk Signs, Light Square, Streetlight (evaluated) | `kitbash` candidates | https://poly.pizza/bundle/Cyberpunk-Game-Kit-Hkfxa8K8zF (also https://quaternius.com/packs/cyberpunkgamekit.html) | "License: CC0 … In FBX, OBJ, glTF and Blend formats, free to use in personal and commercial projects." | 2026-09-14 |
| Kenney **Space Station Kit**, **Retro Urban Kit** (evaluated, not shipped yet) | — | https://kenney.nl/assets/space-station-kit, https://kenney.nl/assets/retro-urban-kit | "License: (Creative Commons Zero, CC0) … You can use this content for personal, educational, and commercial purposes." (License.txt in the zip) | 2026-09-14 |
| **Prison dozer** (art-direction north star): Meshy text-to-image `nano-banana-pro` concept `01a09fec-d5c3-700a-bce1-3cdf54384292` → image-to-3D `meshy-t2` task `01a09ff4-4b17-76af-8ed1-4d7f2e8d7c9d` | `prison_dozer`: `tank.hull`, `tank.turret`, `weapon.cannon` | generated with the lead's Meshy Pro account, 2026-09-14 | Meshy terms §3.2: on paid plans the customer owns the generated output (free-plan outputs would be CC BY 4.0) | 2026-09-14 |
| **Round-2 roster** (review #1, approved by the lead 2026-09-14): scout `scout_b`, IFV `ifv_b`, artillery `artillery_a`, Lancer `lancer_b`; Meshy `nano-banana-pro` concepts → image-to-3D `meshy-t2` (task ids in `game/theme/roster/generated/manifest.json` and `assets/meshy_ledger.md`) | `roster`: `unit.<id>.hull/turret/weapon` | generated with the lead's Meshy Pro account | Meshy terms §3.2: on paid plans the customer owns the generated output | 2026-09-14 |
| **Arena kit** (review #1, approved by the lead 2026-09-14): `container_a`, `barrier_a`, `scrap_a`, `stands_a`, `gate_a`, `tower_a`; Meshy `nano-banana-pro` concepts → image-to-3D `meshy-t2` | `arena_kit`: `prop.crate`, `prop.wall`, `kit.scrap_heap`, `kit.stands`, `kit.gate`, `kit.floodlight_tower` | generated with the lead's Meshy Pro account | Meshy terms §3.2: on paid plans the customer owns the generated output | 2026-09-14 |
| Crowd figure atlas, crowd murmur/cheer sounds | cyberpunk crowd (`tools/assets/build_crowd.py`, `make_sfx.gd`) | procedural, in this repo | project-owned, CC0 | 2026-09-14 |
| ambientCG **Asphalt027C** (cracked asphalt), **Concrete047B** (drain grate cut from it) | cyberpunk arena floor (`game/theme/cyberpunk/ground/`, `tools/assets/build_ground.py`) | https://ambientcg.com/a/Asphalt027C, https://ambientcg.com/a/Concrete047B | "All ambientCG assets are provided under the Creative Commons CC0 1.0 Universal License." (https://docs.ambientcg.com/license/) | 2026-09-14 |
| ambientCG **Rust009** (rust), **PaintedMetal006** (its chip pattern becomes the erosion order); procedural corrugation normals and stencils (Share Tech Mono, OFL) | shipping containers (`game/theme/arena_kit/containers/`, `tools/assets/build_containers.py`) | https://ambientcg.com/a/Rust009, https://ambientcg.com/a/PaintedMetal006 | CC0 1.0 (https://docs.ambientcg.com/license/); stencils project-owned | 2026-09-15 |
| Placeholder ad art (procedural) and copy; Oswald (display font) | giant ad screens (`game/theme/arena_kit/ads/`, `tools/assets/build_ads.py`) | generated in this repo; Oswald from github.com/google/fonts `ofl/oswald` (subset) | project-owned; Oswald SIL OFL 1.1 (`assets/fonts/Oswald-OFL.txt`) | 2026-09-15 |
| Procedural cyberpunk kit (A4) | candidates | generated in this repo by `assets/pipeline/procedural_kit.gd` | project-owned | — |

## Rules

- Only add models whose license page you have read. **CC-BY** models (e.g. other creators' tanks on
  Poly Pizza) need visible attribution in the game credits; avoid them unless that's set up.
- AI-generated models: record the provider, plan, and date in the manifest `license` field. Meshy's
  **free** plan outputs are CC BY 4.0 (credit Meshy); paid plans assign ownership to us
  (`_agents/streams/references/asset_services.md`).
- Raw downloads live in `assets/incoming/` (git-ignored). Re-fetch commands are in `mk/assets.mk`
  (`make assets-kitbash`).
