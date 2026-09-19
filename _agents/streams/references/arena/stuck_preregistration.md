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
