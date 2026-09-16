# Fonts

| File | What | License | Source |
|---|---|---|---|
| `ShareTechMono-Regular.ttf` | The HUD's monospace face (unmodified) | SIL OFL 1.1, Reserved Font Name "Share" (`ShareTechMono-OFL.txt`) | github.com/google/fonts `ofl/sharetechmono` |
| `Oswald-Latin.ttf` | The arena ad screens' display face (assets X2: `game/theme/arena_kit/ads/ad_broadcast.gd`, weights through `FontVariation`) | SIL OFL 1.1 (`Oswald-OFL.txt`) | github.com/google/fonts `ofl/oswald/Oswald[wght].ttf` (2026-09-15), subset to Basic Latin, Latin-1 and common punctuation with fontTools, weight axis kept (a Modified Version; Oswald has no Reserved Font Name): 172 KB → 49 KB |
| `JetBrainsMono-Blocks.ttf` | Fallback for glyphs Share Tech Mono lacks: box drawing, block elements (the typewriter cursor `█` U+2588), geometric shapes, arrows | SIL OFL 1.1 (`JetBrainsMono-OFL.txt`) | github.com/google/fonts `ofl/jetbrainsmono`, instanced at wght=400 and subset to U+2190–21FF, U+2500–25FF with fontTools (a Modified Version; JetBrains Mono has no Reserved Font Name) |

`game/ui/widgets/cyber_style.gd` loads the pair as one `FontVariation`-style font with the fallback
chained, so any HUD label can print `█ ▲ ■ ─` safely (orientation trip-up #20).
