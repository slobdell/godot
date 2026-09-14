# HUD fonts (look & feel stream)

| File | What | License | Source |
|---|---|---|---|
| `ShareTechMono-Regular.ttf` | The HUD's monospace face (unmodified) | SIL OFL 1.1, Reserved Font Name "Share" (`ShareTechMono-OFL.txt`) | github.com/google/fonts `ofl/sharetechmono` |
| `JetBrainsMono-Blocks.ttf` | Fallback for glyphs Share Tech Mono lacks: box drawing, block elements (the typewriter cursor `█` U+2588), geometric shapes, arrows | SIL OFL 1.1 (`JetBrainsMono-OFL.txt`) | github.com/google/fonts `ofl/jetbrainsmono`, instanced at wght=400 and subset to U+2190–21FF, U+2500–25FF with fontTools (a Modified Version; JetBrains Mono has no Reserved Font Name) |

`game/ui/widgets/cyber_style.gd` loads the pair as one `FontVariation`-style font with the fallback
chained, so any HUD label can print `█ ▲ ■ ─` safely (orientation trip-up #20).
