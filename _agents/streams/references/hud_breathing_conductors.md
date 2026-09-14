> Copied 2026-09-14 from the lead's notes (/tmp/widget2.md). Companion to hud_message_banner.md.
> Reference for the look & feel stream. (Its §7 targets Go/WebGL; in this repo the equivalent is Godot
> Compatibility renderer: bake glow once into textures/SubViewports, modulate alpha per frame.)

# Sci-Fi HUD "Breathing Conductors" — Replication Specification

Companion document to `widget.md` (the message banner spec). Same HUD, same design language. This document specifies the **breathing circuit-trace lines** ("conductors") that visually wire the HUD widgets together, and — critically — the **pre-rendered glow architecture** that makes the whole effect nearly free per frame. The original burns roughly one bitmap blit and one thin polyline stroke per conductor per frame; all blurring happens once, at layout time.

&nbsp;

Target context for the implementer: **Go → WebAssembly with WebGL.** The spec is written platform-agnostically (§1–§6 are pure math/geometry/pipeline), and §7 maps the architecture onto WebGL specifically. The original was an immediate-mode 2D canvas; in WebGL the pattern translates to *baked glow textures \+ per-frame uniform modulation* and gets cheaper still.

&nbsp;

---

## 1\. The effect, described

Thin teal circuit traces run across the dark HUD background, connecting the instruments (speed/altitude tapes) to the surrounding info panels — like PCB traces or power lines feeding each widget. Each trace:

&nbsp;

- is a crisp \~1 px polyline with small filled circular "solder pad" dots at its endpoints;  
- carries a soft, wide neon glow halo along its entire length (line \+ dots);  
- **breathes**: the glow slowly swells and fades on a sine wave with a period of **10–25 seconds**, while the core line's color simultaneously shifts between a dark "off" teal and a brighter "on" cyan;  
- breathes **independently of every other trace** — each line has its own frequency and phase, chosen so no two lines ever pulse in sync and the ensemble never visibly loops.

&nbsp;

The result reads as idle machinery: current trickling through the ship's wiring. It is deliberately slow and dim — ambient life, not a blinking indicator. At any instant some traces are nearly dark and others softly lit.

&nbsp;

There are 13 conductors in the original, in four groups (3 \+ 4 \+ 4 \+ 2), one group per destination widget.

&nbsp;

---

## 2\. Color and stroke specification

Reference scale (same convention as the banner spec): `scale = screenHeightPx / 1080`, `density` \= dp→px factor (1.0 if N/A).

&nbsp;

| Element | Value |
| :---- | :---- |
| Core line stroke | `1 * density` px wide, anti-aliased, butt caps |
| Core "off" color | `#004D40` (dark teal) |
| Core "on" color | `#008D9F` (medium cyan) |
| Core alpha | fixed **150/255 (≈59%)** at all times |
| Endpoint dots (core) | filled circles, radius `4–6 * scale` px (see §4), same breathing color/alpha as their line |
| Glow color | `#00E5FF` (bright cyan), baked at full opacity |
| Glow stroke width | `8 * scale` px (before blur) |
| Glow blur radius | `12 * scale` px, Gaussian |
| Glow alpha (per frame) | `fraction * 180/255` — breathes between 0 and ≈71% |

&nbsp;

Note the split: the **glow** does the big visible breathing (0 → 71% opacity), while the **core line** never disappears — it only shifts hue slightly and stays at 59% alpha. This keeps the circuit legible at all times; only the "energy" pulses.

&nbsp;

---

## 3\. The breathing math

Per conductor `i`, per frame:

&nbsp;

t        \= wall-clock time in MILLISECONDS (any monotonic ms clock)

&nbsp;

fraction \= (sin(t \* FREQ\[i\] \+ PHASE\[i\]) \+ 1\) / 2          \# 0..1

&nbsp;

glowAlpha  \= fraction \* (180/255)                          \# modulates baked glow

&nbsp;

coreColor  \= lerpRGB(\#004D40, \#008D9F, fraction)           \# per-channel linear

&nbsp;

coreAlpha  \= 150/255                                       \# constant

&nbsp;

`FREQ` is in **radians per millisecond**; period `T = 2π / FREQ` ms. The exact values used (keep them — they were tuned so nothing syncs):

&nbsp;

| Group | Frequencies (rad/ms) | Periods (s) | Phases (rad) |
| :---- | :---- | :---- | :---- |
| Status (3 lines) | 0.00045, 0.0005, 0.00042 | 14.0, 12.6, 15.0 | 0.5, 2.1, 4.8 |
| Flight info (4) | 0.0004, 0.00025, 0.0005, 0.0006 | 15.7, 25.1, 12.6, 10.5 | 1.2, 3.5, 5.9, 0.8 |
| Map (4) | 0.00053, 0.00047, 0.0004, 0.00055 | 11.9, 13.4, 15.7, 11.4 | 4.2, 0.3, 2.7, 5.1 |
| Log (2) | 0.00049, 0.00056 | 12.8, 11.2 | 3.9, 1.5 |

&nbsp;

Design rules if you invent your own sets:

&nbsp;

- Periods in the **10–25 s** range. Faster reads as alarm-blinking; slower reads as static.  
- All frequencies pairwise **incommensurate** (no small integer ratios) so the ensemble never repeats within a session.  
- Phases scattered across \[0, 2π) so lines that are geometrically parallel (the groups of 3–4 run side by side, 24·scale px apart) are visibly desynchronized — this is what makes the wiring look alive rather than like a single blinking group.

&nbsp;

---

## 4\. Conductor geometry (routing)

All conductors are polylines made of **horizontal/vertical runs joined by exact 45° bends** — never arbitrary angles, never curves. Circuit-board aesthetics. Each group is a bundle of parallel lines spaced `24 * scale` px apart, running from the edge of one widget to the edge of another.

&nbsp;

Endpoint dots: a filled circle radius `6 * scale` at the source end and `4 * scale` at the destination end (the small status group uses `4 * scale` at both). Dots sit exactly on the line's terminal vertex.

&nbsp;

The four routes in the original (positions relative to a 1920×1080 layout; adapt to your own widget layout, the *style* is what matters):

&nbsp;

1. **Status group (3 lines):** from the left edge of the airspeed tape, horizontally left toward a top-left widget, then a 45° bend upward, then vertically up into the widget's bottom edge. The 45° segment is computed so each of the 3 staggered lines bends at a shifted point (`x3 = xBend + yBend − y1`), producing nested concentric elbows — the classic PCB "bus corner".  
2. **Flight-info group (4 lines):** straight horizontal runs from the right edge of the altitude tape to the left edge of the right-side info panel.  
3. **Map group (4 lines):** straight horizontal runs from the left edge of the airspeed tape to the right edge of the bottom-left map widget.  
4. **Log group (2 lines):** straight horizontal runs from the altitude tape to a bottom-right panel.

### Dynamic termination (optional but slick)

One destination widget animates its height. Its conductors are **clipped** at the widget's live bottom edge each frame (`clipRect` from that edge down), and a glowing endpoint dot is drawn *at the clip line* — so as the widget grows or shrinks, the traces appear to plug into its moving edge, dot riding the edge. The dot's glow uses a small pre-rendered glow sprite (§5), alpha-modulated by the same breathing fraction.

&nbsp;

---

## 5\. The efficiency trick: pre-rendered glow layers

Gaussian blur is the expensive part, and naively re-blurring 13 glowing paths per frame is a frame-budget killer. The solution — the heart of this spec:

&nbsp;

**Bake each conductor's glow into its own tightly-cropped RGBA image once, at layout time. Per frame, draw that image with a scalar opacity.**

### 5.1 Bake step (run once at startup and on every resize)

For each conductor `i`:

&nbsp;

1\. Build the full path (line polyline \+ endpoint dot circles).

&nbsp;

2\. Compute the path's bounding box.

&nbsp;

3\. Inflate it by  padding \= blurRadius \+ strokeWidth \+ 2

&nbsp;

                \= 12·scale \+ 8·scale \+ 2  px on every side.

&nbsp;

4\. Allocate an RGBA image exactly that inflated size (transparent).

&nbsp;

5\. Into it, stroke the polyline AND fill/stroke the dots with:

&nbsp;

     color \#00E5FF, stroke width 8·scale, Gaussian blur radius 12·scale,

&nbsp;

     full opacity.

&nbsp;

6\. Store: (image\_i, originX\_i, originY\_i)   \# origin \= inflated bounds top-left

&nbsp;

Also bake one small shared **glow-dot sprite**: a circle of radius `4·scale` blurred by `12·scale`, in a square image of side `2·(4·scale + 12·scale + 4)`. This is reused for any dynamically-positioned endpoint (§4's moving dot).

&nbsp;

Key properties:

&nbsp;

- One image per conductor (not one per group) because each line breathes on its own clock — per-line opacity requires per-line images (or an atlas with per-quad alpha; see §7).  
- The tight cropping matters: a mostly-horizontal conductor's glow image is \~screen-wide but only \~50 px tall. Total texture memory for all 13 stays small.  
- The bake includes the dots, so line and pads glow as one continuous halo.

### 5.2 Per-frame draw (the entire runtime cost)

For each conductor, in this order (glow under core):

&nbsp;

fraction \= breathing fraction (§3)

&nbsp;

1\. Blit glow image at (originX, originY) with opacity \= fraction \* 180/255

&nbsp;

2\. Stroke the core polyline: 1px, lerped color, alpha 150

&nbsp;

3\. Fill the endpoint dots: same color/alpha

&nbsp;

(+ optional clip \+ edge-dot for the animating widget, §4)

&nbsp;

No blur, no path tessellation, no allocation, no image regeneration per frame. The original profiled this whole layer at well under a millisecond.

### 5.3 Invalidation

Rebake **only** when geometry changes: viewport resize, or a layout change that moves widgets. The breathing itself never requires rebaking — that is the entire point: **animation lives exclusively in the modulation scalar, never in the baked pixels.**

&nbsp;

---

## 6\. Draw order and compositing

Within the HUD frame:

&nbsp;

1. Opaque dark background (`#000510` \+ vignette/pattern).  
2. **Conductors** (glow blit, then core lines) — under everything else.  
3. Widget panels, banners, instruments, text on top.

&nbsp;

Compositing is plain source-over alpha blending throughout. The glow images are premultiplied-friendly (single hue on transparent); if your pipeline uses premultiplied alpha, bake accordingly and modulate with `color = (a, a, a, a) × fraction·(180/255)` style tinting.

&nbsp;

---

## 7\. Mapping to WebGL (the implementer's actual target)

The bake/modulate architecture translates one-to-one, and WebGL makes the runtime even cheaper:

&nbsp;

**Bake:**

&nbsp;

- At init/resize, render each conductor's glow into a texture. Two easy routes: a. Draw the path into an offscreen 2D canvas with `ctx.filter = 'blur(12px·scale)'` (or `shadowBlur`), then `texImage2D` from that canvas. Simplest; blur quality matches the original (it was a normal Gaussian). b. Pure-GL: render the crisp 8·scale-wide stroke to an FBO, then run a separable two-pass Gaussian (σ ≈ blurRadius/2 ≈ 6·scale, kernel radius \~2σ) into a second FBO-backed texture.  
- Pack all 13 glow crops (plus the dot sprite) into **one texture atlas** and store per-conductor UV rects. One texture bind for the whole layer.

&nbsp;

**Per frame:**

&nbsp;

- One draw call for all glows: a quad per conductor (13 quads), each with a per-vertex/per-instance `alpha = fraction·(180/255)` attribute, sampling the atlas; fragment shader `outColor = texture(...) * alpha`.  
- Core lines: `gl.LINES`/thin quads with per-instance breathing color uniform or attribute (lerp the RGB on CPU per conductor per frame — 13 lerps — or pass `fraction` and lerp in the vertex shader between two color uniforms). Native `gl.LINES` at width 1 is fine here since the core is 1 px by design; use thin quads if you need guaranteed AA.  
- Dots: small triangle-fan circles or a round-point sprite, same color.  
- The animated clip edge (§4) becomes a scissor rect or a `v_y > edgeY` discard in the fragment shader, plus one dot-sprite quad positioned at the edge.

&nbsp;

**Time:** feed `performance.now()` (milliseconds) straight into the §3 formulas — the frequency constants are already in rad/ms. In Go/WASM, sample the time once per frame on the Go side and compute the 13 fractions there; they're trivially cheap. Avoid syscall/js chatter per conductor.

&nbsp;

---

## 8\. Gotchas (paid for in iteration; don't rediscover them)

- **Never re-blur per frame.** If you find yourself calling a blur inside the render loop, you've left the architecture. All breathing is opacity/color modulation of static assets.  
- **Bake at full opacity, modulate at draw.** Baking a dimmed glow and then modulating again double-attenuates and the breathe range collapses.  
- **Inflate the bake bounds** by `blur + strokeWidth + 2` or the halo clips hard at the image edge — visible as a rectangular seam when the glow is bright.  
- **Rebake on resize** (and only then). Stale bakes after a viewport change leave misplaced glow ghosts, since blit positions are stored absolute.  
- Use **milliseconds** with the given frequencies. Feeding seconds makes the lines strobe \~1000× too fast; feeding a frame counter ties the breathing to frame rate.  
- Keep the core line's alpha **constant**. Early versions breathed the core too; the circuit "disconnected" visually every cycle and looked broken rather than idle.  
- Glow alpha ceiling is 180/255, not 255 — full-blast glow reads as an alert and competes with the banner widgets' 255-alpha borders. The hierarchy (banners \> instruments \> ambient wiring) depends on this headroom.  
- Per-line frequency/phase, not per-group. Synchronized parallel lines look like a loading indicator; desynchronized ones look like current.  
- The conductor layer draws **beneath** all widgets, so glow halos slide under panel fills — traces appear to run *into* the widgets, not over them.

&nbsp;

---

## 9\. Quick reference card

Core line:  1px @ alpha 150, color lerp \#004D40 → \#008D9F by fraction

&nbsp;

Glow bake:  stroke 8·scale, Gaussian blur 12·scale, \#00E5FF, full opacity,

&nbsp;

            per-conductor cropped texture, bounds inflated blur+stroke+2

&nbsp;

Glow draw:  blit with opacity \= fraction · 180/255

&nbsp;

Breathing:  fraction \= (sin(t\_ms · freq \+ phase)+1)/2 ; periods 10–25 s,

&nbsp;

            unique freq+phase per line (see §3 tables)

&nbsp;

Dots:       filled circles r=6·scale (source) / 4·scale (dest), core color;

&nbsp;

            shared blurred dot sprite for glow

&nbsp;

Routing:    H/V runs \+ exact 45° bends; parallel bundles spaced 24·scale

&nbsp;

Rebake:     on resize only; NEVER inside the frame loop

&nbsp;

Z-order:    background → conductors → widgets/banners/text

&nbsp;

scale:      screenHeight / 1080

&nbsp;
