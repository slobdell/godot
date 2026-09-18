# Round 5 (ai): the raw cost and behaviour runs

> Kept because they are **interleaved** runs — A, B, A, B on one machine within minutes — and cannot be compared
> against anything measured later unless the raw numbers survive. Method and what they mean:
> [../../unit_ai.md](../../unit_ai.md) ("How this stream measures things"). Machine: the lead's laptop (the one whose
> frame rate is in question), shared with five other agents, so absolute values are pessimistic and only the ratios
> within a block are evidence.

## Think rate, after the 30 Hz move (`make ai-perf UNITS=60`, thread CPU per living unit per second of match)

Interleaved, two passes, commit `ddf6f8dd`:

| Thinks per second | Variant | Run 1 | Run 2 |
|---|---|---|---|
| 7.5 (what integer division gave the champion at 30 Hz) | `x6t75` | 7 756 µs | 7 884 µs |
| **6.67 (restored: the rate it was measured at for two rounds)** | `x5p` | 7 402 | 7 451 |
| 5 | `x6t5` | 6 782 | 6 799 |
| 3.75 | `x6t4` | 6 943 | 7 001 |

Restoring 6.67/s is **-5%** against the accidental rate; 5/s would be **-13%**. (An earlier block at commit `fe6d3e2e`,
before the cadence fix, read 9 819 / 8 275 / 6 972 µs for 7.5 / 5 / 3.75 — same ordering, higher absolute values, a
different day's machine load. Never compare across those blocks.)

## The exact cuts of X1, at 60 Hz (before the tick change), same scenario, same battle

| State | Thread CPU per tick | Per living unit |
|---|---|---|
| Start of round 5 (`x4t9`) | 7 748 µs | 188 µs |
| + typed per-tick columns, feed sources once a tick, no cover-fire search for fast guns, no lambda per option | ~7 400 | ~180 |
| + CoverMap typed features and bucketed tactical points | 7 260 | 177 |
| `x5b2` (whole controller every other tick), whole scenario suite | | 147 (-21%) |

Jolt changed nothing measurable here: 185.7 µs per unit before, 184.1 after, back-to-back on one machine.

## Dodging: attempts, not shells that missed (`scenario_dodge_rate`, 8 seeds)

| Build | Unit | Ticks with a round inbound | Of them dodging | Shells that missed |
|---|---|---|---|---|
| 30 Hz, champion `x5p` | tank | 502 | **0** | 6% |
| 30 Hz, champion `x5p` | IFV | 514 | 8 | 9% |
| 60 Hz snapshot `25ea2898`, `x5p` | tank | 893 | **0** | 17% |
| 60 Hz snapshot `25ea2898`, `x5p` | IFV | 953 | 0 | 12% |

Inside `CombatMotion`, every candidate direction scored "would still be hit" (254 of 254 candidate evaluations at
30 Hz, 248 of 248 at 60). A shell crosses 50 m in ~0.7 s; a hull turning at 100°/s needs ~0.8 s to swing perpendicular.
45-shell samples resolve about 2 percentage points per shell: the differences between rates are noise, the zeroes are
not.

## The player's orders (`test_ai_player_orders`, `test_tactics_reissue`), after the fixes

| Measure | Result |
|---|---|
| Unit ordered across two firing guns | arrives in 16.8 s, all 519 ticks on MOVE |
| Five squads ordered a second apart | every unit on its own slot, worst 4.9 m; drift afterwards 0 m |
| Element orders on a squad the player commands | 0 (was 33 in one doctrine-army run, killing the squad 40 m short) |
| Element re-issues of an intention already being carried out | 0.0 a second |
