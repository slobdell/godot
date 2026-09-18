# Combat's measurement records (round 5, 2026-09-17)

The raw results behind numbers quoted in [balance.md](../../../balance.md) and
[sim_tick_rate.md](../../../sim_tick_rate.md). They are here so a later agent can **compare a new result against the
old world, or re-derive a published number, without paying for the machine time again** — three hours of builder0 and
about an hour of the lead's laptop. Each file says what produced it, on what machine, and against which build.

| File | What it holds | Reproduce with |
|---|---|---|
| `team-fairness-2026-09-17.json` | Per-seed winners for all five fairness configurations over seeds 1–16, plus the base-position re-measure over seeds 17–64. The evidence that **the army draw, not team identity or base, decides a mirror**: swapping armies flips the winner in 15 of 16 seeds | `make team-fairness N=16` (five configs, ~20 min on builder0) |
| `engagement-baseline-2026-09-17.json` | Per-match engagement blocks for 15 counterbalanced faction battles: contact, engaged and kill distances, held line, net advance, kills by face and off axis, cover use. **Stale by construction** — taken before the `ready_to_fire` fix and before armies held until ordered — and kept precisely so the re-taken baseline has something to be compared against | `make engagement PAIRS=… SEEDS=3 TIME=240` (round 6: the knob is `VARIANT_FILE=`, not `VARIANTS=` — see mk/match.mk) |
| `tick-rate-ab-2026-09-17.json` | Two 30 Hz vs 60 Hz A/B pairs (one machine, one build, one seed per pair) with per-band breakdowns, plus a builder0 profile. The evidence for **a quarter to a third off the simulation's cost per simulated second** | `make sim-profile TIME=60` on a copy with `SimClock.TICK_RATE` flipped |
| `perf-30hz-laptop-2026-09-17.json` | `perf-scene` phases at 720p and 1080p on the lead's laptop at 30 Hz: vehicles against frame time, p95, GPU, tick cost, ticks per frame. The evidence for **a locked 30 fps at 1080p holding ~29 vehicles on a quiet machine** | `make perf-scene PERF_RES=1920x1080` (opens a window ~2 min) |

**Reading them.** Compare like with like: `perf-scene` and `sim-profile` both run a *live battle*, so two runs
diverge and equal vehicle counts are not equal fights. Only compare runs made as a pair on one machine with one
build, which is why the A/B file is organised in pairs. And on an overloaded machine game time runs slower than wall
time (see sim_tick_rate.md), so never derive a per-second rate from a stopwatch against a windowed run.
