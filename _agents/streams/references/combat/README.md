# Combat's measurement records (round 5, 2026-09-17)

The raw results behind numbers quoted in [balance.md](../../../balance.md) and
[sim_tick_rate.md](../../../sim_tick_rate.md). They are here so a later agent can **compare a new result against the
old world, or re-derive a published number, without paying for the machine time again** — three hours of builder0 and
about an hour of the lead's laptop. Each file says what produced it, on what machine, and against which build.

| File | What it holds | Reproduce with |
|---|---|---|
| `team-fairness-2026-09-17.json` | Per-seed winners for all five fairness configurations over seeds 1–16, plus the base-position re-measure over seeds 17–64. The evidence that **the army draw, not team identity or base, decides a mirror**: swapping armies flips the winner in 15 of 16 seeds | `make team-fairness N=16` (five configs, ~20 min on builder0) |
| `engagement-baseline-2026-09-17.json` | Per-match engagement blocks for 15 counterbalanced faction battles: contact, engaged and kill distances, held line, net advance, kills by face and off axis, cover use. **Stale by construction** — taken before the `ready_to_fire` fix and before armies held until ordered — and kept precisely so the re-taken baseline has something to be compared against | `make engagement PAIRS=… SEEDS=3 TIME=240` (round 6: the knob is `VARIANT_FILE=`, not `VARIANTS=` — see mk/match.mk) |
| `n5-engagement-envelope-2026-09-18.json` | **The CP4 answer.** 75 matches, n=15 per arm, 3 counterbalanced faction pairings, SEEDS=3, builder0 at `fa4e7077`. Five arms: a **true round-5 control** (bands at reach *plus* `--no-acquisition --no-crossing`), the shipped bands, a discipline-off-only arm, 0.65 and 0.55 of reach. Headline: **kill distance 54 → 40 m (−26%), off-axis kills 26% → 45%**. The decomposition is the finding: the **gates** give −11 m and +17 points, the **bands** −3 m and +2. **Caveat that matters: the discipline-off arm is NOT a "before"** — it keeps sight, acquisition and the crossing penalty, because those are code and `--variants` only tunes data. Reading it as the old world understates N5 by a factor of three | `make engagement PAIRS=condemned:condemned,gangs:law,condemned:syndicate SEEDS=3 TIME=240 VARIANT_FILE=tools/matchup_variants/engagement_bands.json` (~25 min on builder0) |
| `faction-matrix-{boulevard,yard}[-plainroles]-2026-09-19.json` | **X4's ablation, four arms.** Every faction pair at 5200 points, counterbalanced, on an OPEN map (boulevard, 0.64) and a CLOSED one (yard, 0.20), each with faction directives ON and with them ablated to plain-role directives. builder0 at `f745f48a`, n=30 per faction per arm. **The result is that the experiment cannot answer the question, and the untreated factions prove it:** `gangs/scout` is the only faction-keyed entry, so the gangs are the only treated faction (+7 pts on both maps) — and **law, untreated, moved −10**. SE of a difference at n=30 is 12.9 points. Also the most current balance picture: every faction within 3 points of even except the Syndicate on the closed map (40%). Each file carries its own `run` conditions and the `positive control` line proving designators actually painted | `make remote T="faction-matrix-arms SEEDS=5 TIME=150 JOBS=8"` (~35 min on builder0; the deltas come from `make compare-arms`, which refuses two arms that are not comparable) |
| `tick-rate-ab-2026-09-17.json` | Two 30 Hz vs 60 Hz A/B pairs (one machine, one build, one seed per pair) with per-band breakdowns, plus a builder0 profile. The evidence for **a quarter to a third off the simulation's cost per simulated second** | `make sim-profile TIME=60` on a copy with `SimClock.TICK_RATE` flipped |
| `perf-30hz-laptop-2026-09-17.json` | `perf-scene` phases at 720p and 1080p on the lead's laptop at 30 Hz: vehicles against frame time, p95, GPU, tick cost, ticks per frame. The evidence for **a locked 30 fps at 1080p holding ~29 vehicles on a quiet machine** | `make perf-scene PERF_RES=1920x1080` (opens a window ~2 min) |

**A warning about `matchup-search` numbers anywhere in balance.md.** Until round 6 (`fd5ac1af`), `mk/match.mk`
used the bare name `UNITS`, which `mk/ai.mk` defaults to 60 — and make variables are one global namespace, so
**every `matchup-search` run ever made silently passed `--units 60` whatever the caller asked for, and the tool never
recorded the value it used.** Any round-3 conclusion in balance.md that assumed a non-default unit count is therefore
unreliable and **cannot be re-derived from the saved output**. The knob is now `SEARCH_UNITS`. The general rule this
earned: **print every resolved knob into the output** — an artefact that does not carry the conditions that produced
it cannot be audited later.

**Before you add a row here: a run taken on a dirty tree may be acted on and may NOT be quoted.** Every instrument
in `tools/` now prints `run: <machine> at <commit>` and records `{machine, commit, dirty}` in its json
(`tools/run_conditions.py`). `dirty = true` means the rsync carried uncommitted changes, so **the commit does not
identify what ran** and the row cannot deliver the reproducibility this directory exists to promise. Measure while
you work — that is normal — but re-run from a clean tree before a number becomes a fact in `balance.md`, in
`game_design.md`, or in front of the lead.

**Reading them.** Compare like with like: `perf-scene` and `sim-profile` both run a *live battle*, so two runs
diverge and equal vehicle counts are not equal fights. Only compare runs made as a pair on one machine with one
build, which is why the A/B file is organised in pairs. And on an overloaded machine game time runs slower than wall
time (see sim_tick_rate.md), so never derive a per-second rate from a stopwatch against a windowed run.
