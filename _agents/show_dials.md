# The arena light show: the four dials

> **For the lead, 2026-09-20.** One page. What you can turn, what each one does to the picture, and which frame or
> clip to look at while you decide. The engineering is in [lighting.md](lighting.md); none of it is needed here.
>
> **Everything on this page is data — a number in a text file.** Nothing needs a rebuild, a re-export or a
> programmer. The files are `arenas/terminus.json` (what this arena's lights do) and
> `game/theme/show/cues.json` (what they do when the fight changes). `make show-report ARENA=terminus` prints every
> value currently in force.

**Watch the clips before the stills.** `build/show/clips/` — five six-second clips. What the show *does* is
breathe, and a still cannot show breathing; the stills understate it, and that is not a figure of speech, it is the
reason a reviewer asked last night whether the thing was switched on at all.

---

## Dial 1 — **How alive the buildings look.** This is the one that matters.

**And the knob you will reach for is the wrong one.** The instinct is *"turn the brightness up"*. That brightens the
city, which competes with the fight for your eye, and we now measure that and refuse it. What reads as *alive* is
**contrast** — the gap between a building's dimmest and brightest moment — **not its brightest.**

| | now | was | what it looks like |
|---|---|---|---|
| **Window swing** | **32%** | 65% | how much the lit windows rise and fall as the building breathes |
| Shopfront swing | 31% | 55% | the same, at street level |

It was narrowed last night to pass a readability check, and I want you to know that rather than find it.
**Widening it back is one line**, and the way to do it is to lower the floor *and* raise the ceiling together —
`"floor": 0.70, "ceiling": 1.20` instead of `0.80 / 1.10` — so the city gets **more alive without getting
brighter**.

**Look at:** `clips/terminus_lull.mp4` (this is the idle — most of a match looks like this), then
`terminus_wide_cue_battle.png` against `before/terminus_wide_cue_battle.png`, which is the same instant with the
show switched off.

---

## Dial 2 — **How slowly it breathes.**

Each thing in the venue breathes on its own clock, and they are deliberately out of step so the place never pulses
as one and never visibly repeats.

| | now |
|---|---|
| Perimeter rim | one breath every **24 s** |
| Windows | **22 s** |
| Roof lines | **20 s** |
| Tower beams | **18 s** |
| Shopfronts | **15 s** |
| Signs | **13 s** |
| Floodlight pools | **11 s** |

**Slower than ~25 s reads as nothing happening. Faster than ~10 s reads as an alarm going off.** Inside that band
it is taste, and you can move any single line without touching the others — **but they must stay out of step.**
Making two of them the same, or one exactly double another, makes the whole venue visibly sync up every few
minutes, which looks like a fault. The file refuses a set that would do that and tells you which pair is the
problem, so you can change numbers freely and it will stop you.

**Look at:** `clips/terminus_lull.mp4`.

---

## Dial 3 — **How hard the venue reacts to the fight.**

The idle is the breathing. The **cues** are the show: the venue changes when the match does.

| when | what the venue does now | how fast it gets there |
|---|---|---|
| **FIGHT** (the loading screen drops) | house lights down on the buildings, rim and towers up | 0.7 s |
| **Skirmish** (first contact) | leans in slightly — nothing you'd look away from the fight to see | 2.5 s |
| **Battle** | a chase running round the rim, a wave over the buildings | 1.2 s |
| **Last stand** | a strobe — **the only strobe in the venue** | 0.6 s |
| **Victory** | a sweep round the rim **in the winner's colour** — the one team-coloured thing here | 0.8 s |
| **Defeat** | the house goes cold. Nothing switches off; it just stops being interested | 2.0 s |
| **A kill** | a ripple travelling outward across the nearest buildings from where it happened | instant |

Two numbers per cue: **how fast it moves** (the chase/strobe period) and **how fast it arrives** (the attack). A cue
can run much faster than the idle is allowed to — that is the point of a cue — with a floor at 0.8 s.

**Look at:** `clips/terminus_battle.mp4`, `clips/terminus_last_stand.mp4`, `clips/terminus_victory.mp4`,
`clips/terminus_kill.mp4`. **This is the dial the stills are worst at showing** — a still of a chase is a still of
some lights, and a still of a strobe caught between flashes just looks dim.

---

## Dial 4 — **How much of the venue is lit at once.**

Not a brightness — a *fraction*. The four floodlight towers, the rim's edges and the signs each sit at their own
point in the cycle, so the question is how many are bright at any moment:

- **All of them, rising and falling together-ish** — the idle. Calm.
- **A travelling pulse, one bright at a time** — a chase. Reads as an event.
- **A short stab** — a strobe. Reserved for `last_stand`.

It is one word per channel — `breathe`, `sweep`, `chase`, `strobe` — plus **how far out of step** the instances
are, which is a single number from 0 (all together) to 1 (fully scattered). Everything in the venue is currently at
1, which is why no two buildings are ever at the same brightness.

**Look at:** `terminus_wide_cue_fight.png` (rim and towers up together) against `clips/terminus_battle.mp4` (the
chase travelling).

---

## Two things that are not dials, and are your call

**The lit edges.** You asked for *"the lit edges breathe and glow"*. There are two ways to read that and both are
built:

- **What ships now — the roofline only.** A lit run along the top of each building.
- **The other one — every corner lit**, in `build/show/outline/`. Closer to your words.

feel argues for the roofline on art-direction grounds: the corners *are* the building's outline, so lighting them
draws a wireframe around everything, and the direction says in as many words *"neon lives behind or inside things,
not outlines on everything"*. I agree with feel. **You may not, and it is one word in the layout file.** Compare
`terminus_wide_cue_battle.png` with `outline/terminus_wide_cue_battle_outline.png`.

**The strobe on `last_stand`.** It is the only one in the venue and it is deliberately rare. Keep or cut:
`clips/terminus_last_stand.mp4`.

---

## What it costs

**No extra draw calls and no extra lights.** The show does not add anything to the scene — it rides surfaces the
venue was already drawing, and changes fifteen numbers a frame. That part is structural, not a measurement: the
code is forbidden from creating geometry or a light, and a test enforces it.

**The frame cost is small enough that we cannot currently measure it.** Last night, before the roster resize, it
came out at **0.22 ms of GPU — about 1.5% of a frame.** Since the bigger vehicles landed, two attempts this morning
gave **+1.5 ms and −0.65 ms**: they straddle zero, which means the thing is smaller than the measuring error rather
than that it got cheaper. The build machine is running eight streams' test suites at once and is too busy to see
something this small.

**So: no worse than before, and probably the same 1.5%** — being re-measured on a quiet machine, and the real figure
will replace this paragraph rather than sit beside it.

**And a check you did not ask for but should know exists:** every frame we shoot is measured for whether the venue
out-competes the fight for your eye, against the same frame with the show switched off. **If the lights win, the
build fails.** That is why dial 1 got narrowed — and it is also how you will find out immediately if widening it
goes too far.
