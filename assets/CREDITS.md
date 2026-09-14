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
| Procedural cyberpunk kit (A4) | candidates | generated in this repo by `assets/pipeline/procedural_kit.gd` | project-owned | — |

## Rules

- Only add models whose license page you have read. **CC-BY** models (e.g. other creators' tanks on
  Poly Pizza) need visible attribution in the game credits; avoid them unless that's set up.
- AI-generated models: record the provider, plan, and date in the manifest `license` field. Meshy's
  **free** plan outputs are CC BY 4.0 (credit Meshy); paid plans assign ownership to us
  (`_agents/streams/references/asset_services.md`).
- Raw downloads live in `assets/incoming/` (git-ignored). Re-fetch commands are in `mk/assets.mk`
  (`make assets-kitbash`).
