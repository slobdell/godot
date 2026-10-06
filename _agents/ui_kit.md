# The UI kit: how every screen in Tank Squad looks

> **Round 19 (garage, G2; contract C19.5).** The lead: *"In the UI in the garage we also want chamfered borders and
> stuff, and I think we have enough content now where we have a theme to build off of."* This page is that theme,
> written down so the garage, the results screen, the scoreboard (board) and every later screen are built from the
> same parts. Pictures: `make ui-kit-shots` (needs a display; `make remote T=ui-kit-shots`) writes one frame per
> element and the whole sheet to `build/screenshots/ui-kit/`. **Look at the frame before you use an element, and add
> a frame when you add an element.**

## The rule in one line

**Dark translucent panels, 45° chamfered corners, a thin neon border, Share Tech Mono, and colour that means
something.** It is the HUD's language (ported from mavlink-hud in round 1: `streams/archive/round1/look_and_feel.md`)
applied to whole screens. Nothing is rounded; nothing is flat grey; nothing glows that isn't telling you something.

## Where it lives (all in `game/ui/widgets/`)

| File | What | Owner |
|---|---|---|
| `cyber_style.gd` (`CyberStyle`) | the palette, the font, `ui_scale` (screen height / 1080 × the 1.5 touch boost) | garage (kit) |
| `cyber_frame.gd` (`CyberFrame`) | the HUD's big panel: a chamfered fill with four glowing corner brackets; animatable | garage (kit) |
| `cyber_ui_theme.gd` (`CyberUiTheme`) | the window-wide Godot `Theme` HudSkin applies in a match (buttons, panels, labels) | garage (kit) |
| `cyber_banner.gd`, `conductors.gd` | the message banners and the breathing traces between panels | garage (kit) |
| **`cyber_kit.gd` (`CyberKit`)** | **round 19: the named sizes, faction colours, and the factories below** | garage (kit) |
| **`cyber_card.gd` (`CyberCard`)** | a tappable chamfered card that lights its brackets when selected | garage (kit) |
| **`cyber_meter.gd` (`CyberMeter`)** | a filled chamfered meter with ticks: credits left, a score | garage (kit) |
| **`cyber_crest.gd` (`CyberCrest`)** | a faction's crest slot (letters now; a texture when a faction gets art) | garage (kit) |
| `kit/ui_kit_gallery.gd` | the gallery behind `make ui-kit-shots` (`--kit-element=NAME` for one element) | garage (kit) |

**Additive only (C19.5).** A change to an existing kit file adds a parameter with today's default or a new function;
the HUD's and the title's output stay identical frame for frame (`make hud-digest` before and after; a title frame
diffed). A new element is a new file or a new static function, with a gallery section.

## Scale

Every size below is **at 1080p**. A screen picks ONE scale and passes it to every element it builds: `CyberKit.s(control)`
(screen height / 1080, no touch boost) × `CyberStyle.touch_boost()` on a screen a finger uses (the garage and the
results screen do; the HUD does the same through `CyberStyle.ui_scale`). Elements that draw themselves take it as a
parameter (`CyberCard.set_scale_1080(s)`, `CyberMeter.ui_scale`); never multiply a size by the scale twice (the
first gallery did, and the phone sheet ran off the screen). **Stroke widths and glow radii do not scale**
(CyberFrame's 4 px stroke, 10 px glow): a hairline at 4K is still a hairline.

## Palette (`CyberStyle`; frame `palette.png`)

| Name | Hex | Means |
|---|---|---|
| `CYAN` | `#00F3FF` | yours, the selection, the default border. Friendly team colour in a match |
| `PINK` | `#FF0099` | the enemy. Enemy team colour |
| `PURPLE` | `#D900FF` | structure (the radar outline, conductors' far end) |
| `GREEN` | `#39FF14` | go: the PRIMARY action (FIGHT), money you still have |
| `YELLOW` | `#FFFF00` | a price, a warning |
| `ERROR_BORDER` / `ERROR_FILL` | `#FF1744` / `#D50000` | wrong: over budget, refused, destructive |
| `TEXT` | `#E0E0E0` | words. Dim words are TEXT at 60 % alpha |
| `CARD` | `#121225` | the panel fill (at 0.82–0.92 alpha over the arena; `CyberKit.PANEL_FILL` is 0.88) |
| `HUD_BACKGROUND` | `#000510` | a screen's backdrop when there is no arena behind it |

**Faction colours** (`CyberKit.FACTION_COLORS`, round 19): Condemned amber `#FFB000`, Road Gangs orange `#FF5A1F`,
the Law blue `#4D8DFF`, the Syndicate ivory `#E8E0FF`. They mark a faction (its crest, its card, its name) and
**never** a team: in a match the teams are cyan and magenta whatever the factions.

**Rules.** Colour means something (art_direction: red is a signal, not trim). One accent per element. Cool white is
not in the palette (the Syndicate's ivory is warm on purpose).

## Type (`CyberStyle.font()` = Share Tech Mono + a JetBrains Mono fallback for █ ▲ ─; frame `type.png`)

| Constant | Size | For |
|---|---|---|
| `CyberKit.TITLE` | 44 | a screen's title (GARAGE, VICTORY) |
| `CyberKit.HEADING` | 28 | a section heading, the FIGHT button |
| `CyberKit.BODY` | 22 | names, buttons, the meter |
| `CyberKit.SMALL` | 18 | prices, chips, secondary lines |
| `CyberKit.MICRO` | 15 | labels under things (a role, a swatch name) |

The HUD's banners keep their own 25.2. Text over anything busy gets a 3 px black outline (the buttons and the meter
do it for you). Upper case for actions and headings, sentence case for anything a player reads as a sentence.

## Spacing and tap targets

`GAP_S` 8 (inside an element) · `GAP_M` 16 (between elements, a box's padding) · `GAP_L` 24 (between groups) ·
`CUT` 10 (a box's corner cut; panels 16, CyberFrame 20) · **`TAP` 48: nothing a finger taps is shorter**
(`test_army_screen.gd` pins it at 1080p).

## Elements

Each has a frame in `build/screenshots/ui-kit/<name>.png`.

- **`CyberKit.box(fill, border, width, cut, pad)`** — the one StyleBox: a `StyleBoxFlat` with `corner_detail = 1`, so
  each rounded corner becomes one 45° cut. Every chamfered thing on a screen is one of these.
  `CyberKit.panel_box(scale)` is a group's background. (`CyberUiTheme._box` is the same idea at 7 px for the HUD.)
- **`CyberFrame`** (`frame.png`) — the HUD's big panel: chamfer 20, glowing corner brackets, themes INFO / WARNING /
  ERROR. Use it for a screen's major regions when you want the brackets; it draws, it doesn't lay out children.
- **Buttons: `CyberKit.button(text, scale, accent, size)` / `style_button(...)`** (`button.png`) — five states:
  normal (dim accent border), hover (bright border, lighter fill), pressed / toggled (accent fill at 24 %, 2 px
  border, accent text), disabled (faded, no accent). The accent says what the button does: CYAN for the ordinary,
  **GREEN for the one primary action on a screen** (FIGHT), ERROR_BORDER for destructive. Always ≥ `TAP` tall.
- **`CyberCard`** (`card.png`) — a tappable chamfered card; put its content in `card.content` (a VBox that ignores
  the mouse, so the whole card is one target). `selected` lights the four corner brackets in `accent` (CyberFrame's
  language at card size); `disabled` dims it. Faction cards use the faction colour as the accent.
- **`CyberKit.chip(text, scale, color)`** (`chip.png`) — a small chamfered button for one owned thing (a vehicle in
  a squad). Tinted with its colour; one tap target tall.
- **`CyberKit.tag(text, scale, color)`** (`tag.png`) — a price or a count in a small chamfered box: "40 CR", "5 / 5".
  YELLOW for prices.
- **`CyberMeter`** (`meter.png`) — a filled chamfered meter with a tick every `step`: the label on the left, the
  readout on the right ("620 CR LEFT" with `shows_left`, else "620 / 1000 CR"); past the total it fills in the error
  colour and reads "OVER BY 40 CR". `low_fraction` (off by default) turns the fill `CyberKit.AMBER` (`#FFB300`) when
  under that fraction is left and above zero ("nearly spent"; the garage sets 0.1). The garage's credits; board's
  score bug uses it for points.
- **`CyberCrest`** (`crest.png`) — a faction's crest slot: a chamfered badge in the faction colour with its letters
  (CN, RG, LW, SY), `dim` when not picked, `texture` to replace the letters when the faction gets an emblem.
- **`CyberKit.heading(number, text, scale, accent)`** (`heading.png`) — a numbered section heading, "1  FACTION":
  the number in the accent. A screen that asks questions in order numbers them.

## Building a screen with it (the garage is the first full consumer)

1. A full-rect backdrop (`CyberStyle.HUD_BACKGROUND`, or a translucent shade over the arena), then a
   `MarginContainer` at `GAP_L × 2` and containers. **Lay out with containers, not positions**: the phone aspect
   (20:9, `--ui-touch`) is first-class and containers survive it.
2. Groups are `PanelContainer`s with `CyberKit.panel_box(scale)`; the screen's big regions may sit in a `CyberFrame`.
3. Text through `CyberStyle.label(text, size × scale, color)`.
4. Exactly one GREEN button.
5. Photograph it at both aspects and look (`make garage-shots`, `make garage-tour`).
