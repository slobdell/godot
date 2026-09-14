> Copied 2026-09-14 from the lead's notes (/tmp/widget1.md), which document the cyberpunk HUD in
> ~/projects/led-drone-microcontrollers/mavlink-hud (Android: CyberHudView.java). Reference for the look & feel stream.

# Sci-Fi HUD Message Banner — Replication Specification

A complete, language-agnostic specification for the info / warning / error banner widget used in a cyberpunk-styled flight HUD. Everything needed to reproduce the widget pixel-for-pixel and frame-for-frame is described here: geometry, colors, transparency, glow, the "beam → expand" entrance choreography, the glitch/snap accents, the typewriter text engine, and the message lifecycle state machine.

&nbsp;

The implementation assumes only:

&nbsp;

1. A 2D canvas API (paths, strokes, fills, per-draw alpha, blur/shadow).  
2. A frame-driven animation facility (interpolated scalar values over time).  
3. A monospace font.

&nbsp;

---

## 1\. Anatomy and placement

There are **two instances** of the same widget, differing only in anchor position, color theme, and entrance timing:

&nbsp;

| Instance | Purpose | Anchor | Themes |
| :---- | :---- | :---- | :---- |
| **Warning banner** | errors \+ warnings | top-center of screen | Red (error) or Yellow (warning), switchable per message |
| **Status banner** | info / notices | bottom-center of screen | Fixed cyan-on-dark ("info") theme |

&nbsp;

Each banner is composed of **three stacked layers**, drawn in this order (bottom to top):

&nbsp;

1. **Fill** — a chamfered (octagonal) translucent panel.  
2. **Border** — four glowing **corner brackets** (NOT a complete outline — the middles of each edge are intentionally open). This is a large part of the sci-fi look.  
3. **Text overlay** — a scrolling monospace text block (current message on top, history below), positioned to match the banner's *base* rectangle. Rendered by the UI toolkit's text stack, not the canvas, and faded in/out independently of the panel animation.

&nbsp;

The panel (fill \+ border) is drawn every frame on a fullscreen canvas that sits *under* the text overlay in z-order.

&nbsp;

---

## 2\. Reference coordinate system

All "pixel" constants below are calibrated for a **1080-pixel-tall screen**. Define:

&nbsp;

scale   \= screenHeightPx / 1080.0        \# resolution scale for canvas geometry

&nbsp;

density \= platform display density        \# e.g. dp→px factor; use 1.0 if N/A

&nbsp;

- Canvas geometry (chamfers, bracket arms) multiplies by `scale`.  
- Layout margins multiply by `density` (they were authored as dp). On a single-target implementation you may treat both as one scale factor.  
- Stroke widths and glow radii are **fixed pixel values** (they do not scale) — 4 px strokes and 10 px glow at any resolution. This was deliberate: on large screens the panels grow but the line weight stays razor-thin.

### Base rectangle (both banners)

baseW \= screenW \* 0.60        \# 60% of screen width

&nbsp;

baseH \= screenH \* 0.09        \# 9% of screen height

&nbsp;

margin \= 16 \* density         \# gap from screen edge

&nbsp;

**Warning banner (top):** fixed center point

&nbsp;

cx \= screenW / 2

&nbsp;

cy \= margin \+ baseH / 2

&nbsp;

**Status banner (bottom):** fixed center point

&nbsp;

cx \= screenW / 2

&nbsp;

midY \= (screenH \- margin) \- baseH / 2

&nbsp;

During animation the box **scales about this fixed center point** — width and height each shrink/grow symmetrically around (cx, cy). This is essential: the "beam" appears as a line at the banner's vertical center, then opens up and down equally.

&nbsp;

w \= baseW \* animWidth          \# animWidth, animHeight, animAlpha ∈ \[0..1+\]

&nbsp;

h \= baseH \* animHeight

&nbsp;

left \= cx \- w/2;  right \= cx \+ w/2

&nbsp;

top  \= cy \- h/2;  bottom \= cy \+ h/2

&nbsp;

---

## 3\. Chamfered panel geometry

### 3.1 Fill (translucent octagon)

An axis-aligned rectangle with all four corners cut at 45°:

&nbsp;

chamfer \= 20 \* scale

&nbsp;

chamfer \= min(chamfer, min(w, h) / 2.5)      \# clamp for small/collapsed boxes

&nbsp;

path:

&nbsp;

  (left+chamfer, top) → (right-chamfer, top) → (right, top+chamfer)

&nbsp;

  → (right, bottom-chamfer) → (right-chamfer, bottom)

&nbsp;

  → (left+chamfer, bottom) → (left, bottom-chamfer) → (left, top+chamfer)

&nbsp;

  → close

&nbsp;

fill with theme background color (see §5), anti-aliased

&nbsp;

The `/2.5` clamp matters visually: while the banner is collapsed to its "beam" state (height ≈ 5% of baseH, i.e. \~5 px), the chamfer clamps to `h/2.5` ≈ 2 px, so the beam reads as a thin lens/hexagon sliver rather than a broken shape.

### 3.2 Border (corner brackets, not a full outline)

Four disconnected open paths, one per corner. Each bracket runs: *straight arm along one edge → 45° chamfer diagonal → straight arm along the adjacent edge*. Stroked, never filled.

&nbsp;

chamfer  \= 20 \* scale, clamped to min(w,h)/2.5   (same clamp as fill)

&nbsp;

armLength \= 30 \* scale

&nbsp;

\# Clamp arms so opposing brackets never touch (leave a gap mid-edge):

&nbsp;

armLength \= min(armLength, h/2 \- chamfer, w/2 \- chamfer), floor at 0

&nbsp;

Top-left bracket:

&nbsp;

  (left+chamfer+arm, top) → (left+chamfer, top) → (left, top+chamfer)

&nbsp;

  → (left, top+chamfer+arm)

&nbsp;

Bottom-left:

&nbsp;

  (left, bottom-chamfer-arm) → (left, bottom-chamfer) → (left+chamfer, bottom)

&nbsp;

  → (left+chamfer+arm, bottom)

&nbsp;

Bottom-right:

&nbsp;

  (right-chamfer-arm, bottom) → (right-chamfer, bottom) → (right, bottom-chamfer)

&nbsp;

  → (right, bottom-chamfer-arm)

&nbsp;

Top-right:

&nbsp;

  (right, top+chamfer+arm) → (right, top+chamfer) → (right-chamfer, top)

&nbsp;

  → (right-chamfer-arm, top)

&nbsp;

stroke: 4 px wide, butt caps, anti-aliased, theme border color

&nbsp;

Emergent look on the banner's proportions (e.g. 1152×97 px at 1920×1080): the vertical arms clamp to `h/2 − chamfer` ≈ 28 px so the left and right short edges are *almost fully outlined* (tiny gap at mid-edge), while the long top and bottom edges are mostly open with brackets only near the corners. Do not "fix" this — it is the intended aesthetic.

### 3.3 Glow

The border stroke carries a soft neon glow:

&nbsp;

shadow/blur layer: radius 10 px, offset (0, 0), color \= the border color

&nbsp;

                   (including its current alpha)

&nbsp;

Equivalent in any stack: draw the bracket path twice — first with a 10 px Gaussian blur in the border color, then the crisp 4 px stroke on top. The fill has **no** glow.

&nbsp;

---

## 4\. Text block

Overlaid on the banner's **base** rectangle (60% × 9% of screen, same margins — it does not shrink with the panel animation; it is simply hidden until the panel finishes opening).

&nbsp;

- **Font:** monospace, regular weight.  
- **Size:** `25.2 * density * scale` px (i.e. "25.2 dp at 1080p reference").  
- **Color:** pure white `#FFFFFF` for the warning banner; light grey `#E0E0E0` for the status banner.  
- **Structure:** a vertical scroll container holding two text views:  
  1. `currentText` — the message currently being typed (top).  
  2. `historyText` — previous messages, newest first, one per line (below).  
- **Padding:** 24 dp left and right, 0 top.  
- **Overflow:** vertical scroll with a subtle **fade-out gradient edge** (15 dp long) at the container's top/bottom — content dissolves rather than clipping hard.  
- Each message is rendered as `HH:mm:ss: message text` (24-hour timestamp, colon-space separator).

### 4.1 Typewriter engine ("cyberpunk typewriter")

New messages type in character-by-character with a block cursor:

&nbsp;

- **Cursor glyph:** `█` (U+2588 FULL BLOCK), appended after the visible prefix.  
- **Duration:** random per message, uniform in **\[250 ms, 600 ms\]** for the *whole string* regardless of length (long strings type faster per char).  
- **Update loop:** \~30 fps (every 33 ms). Visible chars \= `floor(len * elapsed/duration)`, clamped. Only redraw when the count changes.  
- **On completion:** render full text, then blink the cursor: toggle visibility every **300 ms** (full text \+ `█` / full text alone).  
- **Interruption:** if a new message arrives mid-type, the in-flight message instantly completes (`forceFinish`), moves to history, and the new message starts typing in the (now empty) current slot.

### 4.2 History behavior

When a new message displaces the current one:

&nbsp;

1. Prepend the completed message (with its timestamp) to the history string, newline-separated, newest first.  
2. Skip the prepend if the history already starts with that exact string (cheap consecutive-duplicate guard).  
3. Truncate the history string to a cap (500 chars for warnings, 1000 for status).

&nbsp;

History **persists across banner appearances** — when the warning banner dismisses and later reopens, earlier messages reappear below the new one.

&nbsp;

---

## 5\. Color themes and transparency

All colors are given as `#AARRGGBB` where relevant. The theme is chosen per message (see §7) and applied to both fill and border before drawing.

### Status (info) banner — fixed theme

| Element | Value | Notes |
| :---- | :---- | :---- |
| Fill | `#202030` at alpha **220/255 (≈86%)** | dark blue-grey, nearly opaque |
| Border \+ glow | `#00FFFF` (pure cyan) at alpha **255** | 4 px stroke, 10 px glow |
| Text | `#E0E0E0` |  |

### Warning theme (severity \= warning)

| Element | Value | Notes |
| :---- | :---- | :---- |
| Fill | `#32FFFF00` | pure yellow at alpha 0x32 \= 50/255 (≈20%) — very translucent |
| Border \+ glow | `#FFFF00` at alpha 255 | pure yellow |
| Text | `#FFFFFF` |  |

### Error theme (severity \= error/critical)

| Element | Value | Notes |
| :---- | :---- | :---- |
| Fill | `#32D50000` | deep crimson at alpha 0x32 (≈20%) |
| Border \+ glow | `#FF1744` at alpha 255 | neon red |
| Text | `#FFFFFF` |  |

### Alpha composition during animation

The animation exposes a scalar `animAlpha ∈ [0..1]`. Per frame:

&nbsp;

effectiveFillAlpha   \= themeFillAlpha \* animAlpha      \# e.g. 220·a or 50·a

&nbsp;

effectiveBorderAlpha \= 255 \* animAlpha

&nbsp;

glow color           \= border color WITH effectiveBorderAlpha

&nbsp;

i.e. the border is fully opaque at rest; the fill is never fully opaque; both scale linearly with `animAlpha`. Recompose the ARGB colors each frame — don't multiply alphas cumulatively.

&nbsp;

---

## 6\. Animation choreography

All animation is expressed through exactly **three scalars** fed to the renderer each frame: `(animWidth, animHeight, animAlpha)`. Width/height are fractions of the base rectangle; the box stays centered on its fixed anchor (§2). Text visibility is a separate binary alpha (0 or 1\) switched at choreography boundaries.

&nbsp;

Interpolator definitions (Android semantics, reproduce exactly):

&nbsp;

- **decelerate:** `f(t) = 1 − (1 − t)²`  
- **easeInOut** (the default where none is stated): `f(t) = 0.5 − 0.5·cos(πt)`  
- **bounce:** with `b(t) = 8t²`:  
  &nbsp;  
  t' \= t \* 1.1226  
  &nbsp;  
  t' \< 0.3535 → b(t')  
  &nbsp;  
  t' \< 0.7408 → b(t' − 0.54719) \+ 0.7  
  &nbsp;  
  t' \< 0.9644 → b(t' − 0.8526) \+ 0.9  
  &nbsp;  
  else        → b(t' − 1.0435) \+ 0.95

### 6.1 Status banner entrance (fast, understated)

Initial state: `(0, 0.05, 0)`, text alpha 0\.

&nbsp;

| Step | Property | From → To | Duration | Interp |
| :---- | :---- | :---- | :---- | :---- |
| 1\. **Beam** | width | 0 → 1 (height held at 0.05, alpha jumps to 1\) | 200 ms | decelerate |
| 2\. **Open** | height | 0.05 → 1 (width 1, alpha 1\) | 150 ms | easeInOut |
| 3\. Text on | text alpha | 0 → 1 instantly at end | — | — |

&nbsp;

The "beam" is the signature move: a thin glowing horizontal sliver (5% of the banner height ≈ 5 px) grows from the center outward to full width, then the panel unfolds vertically like a shutter opening.

### 6.2 Status banner exit (slow, 4× the entrance)

| Step | Property | From → To | Duration | Interp |
| :---- | :---- | :---- | :---- | :---- |
| 1\. Text off | text alpha | 1 → 0 instantly | — | — |
| 2\. **Shut** | height | 1 → 0.05 | 800 ms | easeInOut |
| 3\. **Retract** | width AND alpha | 1 → 0 (both together, height 0.05) | 800 ms | easeInOut |

&nbsp;

The shrinking beam fades as it retracts — a clean dissolve.

### 6.3 Warning banner entrance (slower, more dramatic, with glitch)

Initial state: `(0, 0.05, 1)` — note alpha starts at 1, not 0 — text alpha 0\.

&nbsp;

| Step | Property | From → To | Duration | Interp |
| :---- | :---- | :---- | :---- | :---- |
| 1\. **Beam** | width | 0 → 1 (height 0.05) | 500 ms | decelerate |
| 2\. **Open** | height | 0.05 → 1 | 400 ms | easeInOut |
| 3\. **Glitch** | alpha strobe | keyframes 1.0 → 0.2 → 1.0 → 0.5 → 1.0 (w=h=1) | 400 ms | easeInOut over the whole sequence; linear between evenly spaced keyframes (at 0, ¼, ½, ¾, 1\) |
| 4\. **Snap** | width AND height together | 1.1 → 1.0 | 300 ms | bounce |
| 5\. Text on | text alpha | 0 → 1 instantly at end | — | — |

&nbsp;

The glitch strobes the *entire panel* (fill \+ border \+ glow) like a failing neon sign; the snap overshoots the box 10% too large and bounces it back to rest. Total entrance ≈ 1.6 s.

### 6.4 Warning banner exit

Same as the status exit (text off → shut 800 ms → retract 800 ms) with one difference: **alpha stays at 1 throughout** — the width collapse alone hides it. After retract completes, the panel is removed, the text views are cleared (the history *string* is retained, §4.2).

### 6.5 Re-triggering while visible

If a new message arrives while the banner is already open: **do not replay the entrance.** Snap the state to `(1, 1, 1)`, restyle to the new theme if the severity changed, and just run the typewriter. (This keeps a burst of messages readable instead of strobing.)

&nbsp;

---

## 7\. Message lifecycle state machine

Input: a stream of `(text, severity)` messages (originally MAVLink STATUSTEXT, severity 0–7, 0 \= most severe).

&nbsp;

**Routing:**

&nbsp;

| Severity | Destination | Theme |
| :---- | :---- | :---- |
| 0–3 (emergency…error) | warning banner (top) | Error / red |
| 4 (warning) | warning banner (top) | Warning / yellow |
| 5–7 (notice, info, debug) | status banner (bottom) | Info / cyan |

&nbsp;

**Per banner, on message arrival:**

&nbsp;

1. **Dedup:** if `text` equals the previous message on this banner verbatim, drop it silently.  
2. Cancel any pending auto-dismiss timer.  
3. Apply the theme (warning banner only — border, fill, text colors).  
4. Format as `HH:mm:ss: text`.  
5. If hidden → run the entrance choreography, then start the typewriter. If visible → snap to full (§6.5) and start the typewriter (previous message force-finishes into history first, §4.1/§4.2).  
6. Arm the auto-dismiss timer: **5000 ms** after the *most recent* message, run the exit choreography. Every new message resets the 5 s clock.

&nbsp;

The two banners are fully independent (separate timers, histories, dedup state).

&nbsp;

---

## 8\. Implementation notes and gotchas

These are the traps that cost iteration time; heed them:

&nbsp;

- **Scale about the fixed center, not the top-left.** Anchoring top-left makes the beam grow sideways and the open animation drop downward — it looks wrong immediately.  
- **Never animate height to exactly 0\.** The floor of `0.05` keeps the beam a visible glowing line; at 0 the panel flickers out instead of reading as a "power line" turning off.  
- **Clamp the chamfer** (`min(w,h)/2.5`) or the path self-intersects while collapsed and the fill glitches.  
- **Clamp bracket arms** (`h/2 − chamfer`, `w/2 − chamfer`) or opposing brackets overlap during the beam phase.  
- **Recompose colors per frame** from theme-alpha × animAlpha; don't mutate a shared paint's alpha cumulatively across frames.  
- The glow must use the border's *current* color including alpha, so the halo strobes with the glitch and changes hue with the theme.  
- On stacks where blur/shadow on paths requires a software layer or specific API level (e.g. Android hardware canvas pre-API 28), fall back to the two-pass blur-then-stroke technique in §3.3.  
- The typewriter UI update loop is capped at \~30 fps on purpose — per-char layout invalidation at 60 fps caused visible jank on the animating HUD.  
- The text overlay sits on the *base* rectangle and is gated by a hard 0/1 alpha at choreography boundaries. Do not scale or clip text with the panel; it smears and defeats the shutter illusion.  
- Stroke width (4 px) and glow radius (10 px) intentionally do **not** scale with resolution; only geometry does (`scale = H/1080`).  
- Anti-alias every path.

### Optional garnish (used in the original but separable)

The bottom status banner is visually "wired into" the rest of the HUD by three thin circuit-trace conductor lines (1 px, `#006064` teal at \~59% alpha, with 4 px terminal dots) running from a neighboring widget down into the banner's top edge, entering `40·scale` px outside the top-right chamfer. Purely decorative; include only if the surrounding HUD has similar traces.

&nbsp;

---

## 9\. Quick reference card

Panel:    60% W × 9% H, centered horizontally; 16 dp from top (warn) / bottom (status)

&nbsp;

Chamfer:  20·(H/1080) px @ 45°, clamp min(w,h)/2.5

&nbsp;

Brackets: arms 30·(H/1080) px, clamp to half-edge minus chamfer; stroke 4 px

&nbsp;

Glow:     10 px blur, border color, offset 0,0; fill has none

&nbsp;

Info:     fill \#202030 @86%, border \#00FFFF, text \#E0E0E0

&nbsp;

Warn:     fill \#FFFF00 @20%, border \#FFFF00, text \#FFFFFF

&nbsp;

Error:    fill \#D50000 @20%, border \#FF1744, text \#FFFFFF

&nbsp;

Enter:    beam(width 0→1) → open(height 0.05→1); warn adds glitch strobe \+ 1.1→1.0 bounce

&nbsp;

          status: 200+150 ms; warn: 500+400+400+300 ms

&nbsp;

Exit:     text off → shut(height→0.05, 800 ms) → retract(width→0, 800 ms; status also fades)

&nbsp;

Text:     monospace 25.2 dp@1080p, 24 dp side padding, HH:mm:ss prefix,

&nbsp;

          typewriter 250–600 ms \+ █ cursor blinking @300 ms, history below (newest first)

&nbsp;

Dismiss:  5 s after last message (timer resets per message); consecutive dupes dropped

&nbsp;
