# Pre-registration: what "stuck" means, written before measuring

**Round 8, arena.** The lead, after playing round 7:

> *"units are still just getting stuck behind basic barriers where they seem to just move back and forth
> indefinitely trying to get unstuck."*

**nav's `nav-fight` reports blocked-by-terrain at ZERO. He watches it happen.** The instrument and the game
disagree, and the game is right. My job is to make the game's version measurable, so that when nav builds flow
fields there is something for them to improve.

**This file is written and committed BEFORE any measurement is taken**, because a probe built after looking will
show whatever I expected. nav pre-registered "robotic" the same way.

---

## The hypothesis I am testing first, and why

**"Moving back and forth indefinitely" is oscillation, not blockage.** A unit that is *moving* is not `blocked` —
so a blocked-by-terrain counter reads zero while the player watches a vehicle shuffle in place forever. If that is
the difference, **the metric is the bug**, and flow fields may not even be the fix.

This is the cheapest hypothesis to kill and the one that would most change what nav builds. **It is a hypothesis,
not a conclusion, and the probe is built to be able to refute it.**

## Definitions, fixed now

All measured only while a unit **holds a move order** (there is nothing wrong with a parked unit standing still).
Window `W = 4.0 s`, which is long enough to contain a full back-and-forth and short enough that a unit rounding a
corner does not look like one.

| name | definition | in words |
|---|---|---|
| `blocked` | speed < **0.5 m/s** for ≥ **3.0 s** | not moving. **This is roughly what `nav-fight` counts, and it reads zero.** |
| `oscillating` | over `W`: path length ≥ **8 m** *and* net displacement < **25%** of path length | **moving a lot, going nowhere** — the lead's words |
| `no_progress` | over `W`: distance to goal improved by < **2 m** | not getting closer, whatever it is doing |
| `stuck` | `blocked` **or** `oscillating` | the union, reported with its parts separated |

**Why a ratio and not a distance:** a unit crossing the map slowly still has net ≈ path. A unit shuffling has
net ≈ 0 with path large. The ratio separates them and is scale-free, so it does not need retuning per unit type.

**What would refute the hypothesis:** if `oscillating` is also ~0 in his configuration, then he is seeing
something neither counter captures, and I go back to watching rather than counting. **A probe that reports zero on
all three is a result, not a failure**, and I will say so.

## The other two hypotheses, not yet tested

1. **Configuration.** He plays `make skirmish`: `--skirmish --enemy=cpu --arena=random`, his own orders, a
   windowed game. `nav-fight` runs `--arena=yard` fixed with CPU armies at budget 6500. **`--arena=random` picks
   from yard, boulevard, pit and boneyard** — so three of the four maps he might be on are ones `nav-fight` never
   tests, and two of them are maps he asked us to stop investing in.
2. **Prop sizes.** "Basic barriers" may be props at sizes the tested map does not contain.

## Rules for myself

- **The thresholds above do not move after a measurement.** If they are wrong, that is a finding to report, and
  any change is made and stated explicitly, with the before and after both published.
- **The probe asserts its own conditions** (`verification.md`): the arena is the one named, the units are the count
  requested, and they are actually under orders — a "no oscillation" result from units that were never ordered
  anywhere would be worthless and perfectly plausible.
- **Report per arena, never pooled.** `--arena=random` is the whole point of hypothesis 1; a pooled number would
  hide exactly the thing it is meant to expose.


---

# Results (2026-09-19, `d2d1bc04`+, laptop, 30 units, 60 s, hold-fire, one way)

**Reported against the definitions above, which were committed before the probe existed and have not moved.**

| | `blocked`/crawl | `oscillating` | **`no_progress`** | arrived |
|---|---|---|---|---|
| **barriers** (the fixture) | 0.112 | 0.015 — 11 units | **0.192 — 26 of 30 units** | 23/30 |
| **yard** (a shipping map) | 0.028 | 0.001 — 2 units | 0.050 — 8 units | 30/30 |

## The hypothesis was right in direction and wrong in size

**Oscillation is real and discriminates** — 15× between the barrier fixture and yard, 11 units against 2 — **but at
1.5% of under-way time it is not "indefinitely".** I pre-registered that a near-zero would be reported as a result
rather than a failure, and this is the honest version of that: *the thing I named is happening, and it is not the
main thing.*

## The measure that matters is the third one, and the gap between them is the finding

`no_progress` reads **0.192 on the barrier fixture, affecting 26 of 30 units** — against `crawl` at 0.112 and
`oscillating` at 0.015. **Those do not add up to it.** Roughly 6.5 points of under-way time is units making no
progress while being *neither* slow enough to count as blocked *nor* travelling far enough to count as shuffling:
a unit creeping back and forth at 1–2 m/s, which is what being pinned at a barrier end actually looks like.

**So the instrument and the game disagree because they are asking different questions.** `nav-fight` asks *is this
unit blocked*, and the honest answer is usually no. The player asks *is this unit getting where I sent it*, and the
answer is no for a fifth of the time on ground built to stall. **A unit can fail the second test while passing the
first, and that is the whole gap.**

## What this does and does not license

- **It does not say flow fields are the wrong fix.** It says the fix must be measured against progress, not
  against blockage, or it will show no improvement whatever it does.
- **It is not his configuration yet.** This is hold-fire, no enemy, ordered to a far point. He plays `make
  skirmish` with an enemy, his own orders, and **`--arena=random`** across four maps. Hypothesis 1 is still
  untested and remains the likeliest source of any remaining difference.

---

# Hypothesis 1, tested (2026-09-19, `9c22f5e4`, laptop, 30 units, 60 s, hold-fire, one way, seed 1)

**`--arena=random` is `Arena.ROTATION` — yard, boulevard, pit, boneyard.** Three of the four had never been run
under these counters, and the pre-registration named them as the likeliest source of the difference. They are not.

| arena | `crawl` | `oscillating` | **`no_progress`** | osc. units | no-prog. units | arrived |
|---|---|---|---|---|---|---|
| yard | 0.028 | 0.001 | 0.050 | 2 | 8 | 30/30 |
| boulevard | 0.011 | 0.001 | 0.007 | 1 | 3 | 30/30 |
| pit | 0.017 | 0.002 | 0.028 | 1 | 5 | 30/30 |
| boneyard | 0.007 | 0.001 | 0.005 | 1 | 1 | 30/30 |
| *barriers (the fixture, for scale)* | *0.112* | *0.015* | *0.192* | *11* | *26* | *23/30* |

**Every map he plays is clean, and yard — already the most-tested map — is the WORST of the four.** The two maps
nobody had measured (boulevard, boneyard) are the best in the rotation. So the untested-maps worry was the wrong
worry: **hypothesis 1 is refuted in the form it was written.** Terrain alone, on the ground he actually plays, does
not stall a crossing.

## What that leaves, and why it is a sharper question than the one it replaces

The barrier fixture reaches 0.192 with **no enemy and hold-fire** — so ground *can* produce the lead's complaint,
and none of his four maps has that ground. What his configuration has and every run above lacks is **an enemy, his
own orders, and units interacting with each other**. The remaining difference is not *where* the units are; it is
*what else is happening around them*.

**This inverts what the fixture is for.** `barriers` was built to reproduce his stall and it reproduces *a* stall —
but on ground he never drives. It is now a sensitivity fixture (ground that is known to stall, for detecting whether
a movement change helps), not a reproduction of his complaint. **Saying otherwise would be the same error combat
caught in itself an hour ago: finding the authoritative copy of a value is not the same as checking the value still
matters.** I found ground that stalls; I had not checked it was ground he stands on.

## Next, and the honest limit of it

`nav-fight` is the instrument closest to his configuration (two CPU armies, GREEN ordered like a player) and it is
nav's file, so the measurement is run rather than edited: the same four maps, its own buckets. If `progressing`
stays low on a map where `blocked_*` reads zero, that is the round-7 gap reproduced in nav's own instrument, per
arena, on ground he plays — which nav can act on without adopting anything of mine.

**Still not tested, and now the whole of the remaining gap: his hands.** A human issuing orders mid-fight
re-tasks units in ways no scripted order sequence does.

---

# The fight, on the same four maps (`nav-fight`, unmodified, seed 3, 120 s, 34 v 44, laptop, `c0aa421f`)

**nav's instrument, nav's buckets, run not edited.** The point was to see whether its `blocked_*` buckets stay at
zero on ground the lead plays while units still fail to arrive. They do, and the time turns out to be somewhere
neither of us was pointing.

| arena | `blocked_terrain` | `progressing` | **`retasked`** | `halted_shooting` | ENGAGE-hop events |
|---|---|---|---|---|---|
| yard | 0.003 | 0.583 | **0.302** | 0.037 | 830 of 1034 |
| boulevard | 0.010 | 0.578 | **0.325** | 0.034 | 781 of 1078 |
| pit | 0.000 | 0.604 | **0.298** | 0.053 | 772 of 1035 |
| boneyard | 0.000 | 0.548 | **0.364** | 0.044 | 836 of 1173 |

## The verb is the variable, and it explains why every hold-fire run came out clean

`nav-fight` splits by order verb, and the split is not subtle:

| verb | `progressing` | `retasked` | re-tasks per unit-minute |
|---|---|---|---|
| **move** | **0.876 – 0.941** | 0.0 | 0.0 |
| **attack_move** | **0.408 – 0.474** | 0.42 – 0.494 | 43.9 – 47.9 |

**A unit under `move` gets where it is sent about 90% of the time. The same unit under `attack_move` manages
about 44%.** My crossing probe issues a plain move with hold-fire — which is exactly the `move` row — so its clean
results were never in tension with the lead's experience. **They were measuring the verb he does not use in a
fight.** That, and not the map, is what hypothesis 1 should have been about.

## Where the missing half goes: not blocked, re-tasked

`retasked` is nav's own definition — *"it is driving, but to somewhere else than its order (its brain chose OPTION;
> RETASK_M away)"*. So the unit is **moving, under a valid path, toward a destination the player did not choose**,
and `blocked_terrain` is honestly ~0.000 because nothing is in its way. About **three quarters of every re-task is
`ENGAGE hop`** — the same option re-aiming, with `direct` motion — at **44–48 events per unit-minute, a destination
change every ~1.3 s**, and `motion_jumps_per_unit_minute` 24–28 on top.

**This is a candidate for the lead's complaint that is not a navigation defect at all**: a unit re-aiming its
destination every 1.3 seconds while driving direct is a unit that visibly does not commit, and the instrument that
asks "is it blocked" will keep answering no, forever, correctly.

## What I have NOT shown, and will not imply

**I have not shown that a re-task looks like "back and forth".** I have shown where the time goes, not what the
trajectory looks like. A unit re-aimed every 1.3 s could equally be drifting in one direction. Establishing the
lead's actual words needs either the oscillation counter inside the fight probe (the block is extracted at
`c0aa421f` for nav) or a human watching one match. **Saying "this is his bug" on this evidence would be round 8's
third version of the same mistake** — a number that points the right way, reported past what it measures.

Nor does this clear flow fields or condemn them: it says a large share of the missing time is a **decision**
problem rather than a **path** problem, and a path improvement cannot recover time that is spent driving somewhere
else on purpose.
