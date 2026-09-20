# A12: trajectory-space metrics

> **The rule.** *A falsifier that names cusp density, displacement efficiency, spectral arc length or formation
> residual is read from `make metrics` and no other tool.* (Contract **S3**, `workstreams.md`.)
>
> Owner: metrics. Tool: `tools/metrics/`. Format: [`tools/metrics/FORMAT.md`](../tools/metrics/FORMAT.md).
> Tests: `make metrics-pytest` (known answers, all derived on paper). Fixtures: `make metrics-fixtures`.

## Why this exists

Round 8's admission, in the research brief's own words: *"we repeatedly measured [time-allocation] while the human
complaint was about [trajectory]"*. The lead watched semis yawing in place and units *"moving back and forth
indefinitely trying to get unstuck"*; we reported that 6% of travel time was spent oscillating. A unit that jerks
for half a second costs almost nothing in a time budget and ruins the next fifteen seconds of watching.

And squad's churn lever (lesson 150) is the same failure from the other end: `commit_bonus` 1.35 halved the churn
metric, passed a 48-match ladder, and cost a squad its fire concentration and a scout its engine-deck targeting.
**The metric improved while the behaviour degraded.** So the acceptance bar for these four is not "they are
principled"; it is that they reproduce a pathology we already found (see *The positive control*).

## What you need first: a trajectory log

There was **no per-tick trajectory log anywhere in the repo** before round 9 — the probes kept a position trail in
memory and discarded it, and every saved JSON is a per-run aggregate. `FORMAT.md` defines the log; two producers
emit it today, each behind a flag that is off by default:

| producer | how |
|---|---|
| `nav-fight` (`tests/nav/fight_probe.gd`) | `make nav-fight NAV_FLAGS=--trajectory=$PWD/build/metrics/run.jsonl` |
| the match runner (`game/modes/match_runner_mode.gd`) | `--trajectory=<abs path>` on any `--match` run |

Both call `TrajectoryLog.install()` (`tools/metrics/trajectory_log.gd`) and nothing else: **the writer is metrics'
and the hook is two lines.** If your harness cannot produce the format, ask metrics — *do not invent a second one*.

A 120 s run of 60 units is ~216,000 lines and ~45 MB; gzip takes it to ~4 MB and the reader accepts `.jsonl.gz`.

## The four metrics

Run them with `make metrics LOGS="build/metrics/*.jsonl"` (add `METRICS_JSON=path` for machine-readable output).
Everything is pure Python with **no third-party dependency, including the FFT**, so the number is identical on the
laptop and on builder0.

### 1. Windowed displacement efficiency — *is it getting anywhere?*

Net displacement ÷ path length over a sliding **4 s window** (`WINDOW_S`, 120 ticks at 30 Hz), x/z only.
1.0 is a straight line; 0.0 is back where it started; a semicircle is its chord over its arc (2/π ≈ 0.637).

**It is reported twice, and the difference matters.**

- **`efficiency_mean` / `efficiency_p10`** — the continuous metric: every unit, every contiguous window, **ungated**.
  This is the new thing. A window never spans a tick gap: absence is not a straight line.
- **`oscillating_share`** — round 8's threshold, re-implemented from positions with `fight_probe.gd`'s gating kept
  **verbatim**: only ticks under orders and more than 8 m from the goal count; the window resets when the goal jumps
  more than 3 m; a window counts as oscillating when path ≥ 8 m *and* efficiency < 0.25; and **the denominator is
  every under-way tick**, including the 119 before the first window closes. Change any one of those three and the
  share moves for a reason that is not behaviour.

**What it can see that the threshold cannot:** the `shuffle` fixture. A unit doing 8 m out, 2 m back, forever, scores
**efficiency 0.600 and `oscillating_share` 0.000** — visibly shuffling, and completely invisible to round 8's
counter. That fixture is the argument for A12 in one file.

**What it cannot see:** a unit driving a perfect straight line at a wildly varying speed (efficiency 1.000). That is
metric 3's job.

### 2. Signed cusp density — *how often does it reverse?*

Sign changes of the **along-body velocity**, per agent-minute, with a 0.5 m/s floor (`GEAR_SPEED`, so it is
comparable with round 8's gear-flip counter). A K-turn is exactly 2 cusps; a straight line is 0.

**Read from position and the logged heading, never from `gear`.** That is the whole point of a trajectory-space
version: round 8's gear-flip counter could only see flips the controller *labelled*, and a third of them came back
`unexplained`. This sees the motion whatever the controller thought it was doing.

Where the log carries the optional cause columns (`order_reverse`, `phase`, `creeping`, `facing_ordered` — each
all-or-nothing, FORMAT.md), cusps are split `ordered` / `creep` / `unexplained`. Without them every cusp is
reported as `unclassified` and the tool says so, rather than printing a zero.

**An ordered arrival facing is an order.** Control shipped desktop right-drag facing, so a move order can carry an
arrival heading, and the arc at the end of such a move is off-corridor *by construction* — the unit obeying.
Ruled 2026-09-20 with control: **ticks under an ordered facing count as `ordered`, never as off-corridor, and are
reported beside the fraction, never inside it.** A reversal inside that arc lands in `cusps_ordered` and never in
`cusps_unexplained`, because `unexplained` is the bucket A6's falsifier reads — and a metric that charges a
contract for the obedience we just shipped is the wrong metric. Every report carries `facing_ordered_seconds` as a
separate tally, and `make metrics` prints a NOTE on any log without the column saying that **no off-corridor
verdict may be published from it**. The same rule binds any future off-corridor or opposing-tangent statistic.

### 3. Spectral arc length (SPARC) — *how jerky is the speed?*

Balasubramanian et al. (2012/2015): the arc length of the DC-normalised magnitude spectrum of the speed profile,
plotted against normalised frequency. Closer to zero is smoother; more negative is jerkier.

Fixed everything, because a number that moves with the run length or with a threshold crossing cannot be compared
between two runs: **256-sample window, 256-point transform, no zero padding, periodic Hann taper, cutoff 20 rad/s**.
The profile is `|speed|`, not signed speed — the DC term normalises the spectrum and a shuffling hull's signed mean
passes through zero, which would make the metric explode on exactly the case we care about. Reversals are metric 2's
job; each metric has one job.

**Two deliberate departures from the reference, and why:**

1. *No zero padding, and a taper.* Our windows are arbitrary slices of an ongoing drive, not the rest-to-rest
   movements the paper is written for. The first version of this tool padded ×8 with no taper and scored a unit
   driving at a **dead constant speed** as jerkier than a square wave, because the step against the pad swamped the
   spectrum: it was measuring the window edge. The taper removes the edge, and `N = W` keeps every bin exact, which
   is also what makes the known answers hand-computable (the periodic Hann's own transform is three bins, so a
   constant profile's spectrum is exactly `(1, 0.5, 0, 0, …)` and SPARC is exactly **−1.9231**).
2. *A fixed cutoff, not the paper's adaptive one.* An adaptive cutoff makes the answer depend on where a spectrum
   happens to cross an amplitude threshold — a number that differs between two runs for no behavioural reason.

**⚠ What it cannot see, asserted as a test so nobody reads a ranking into it that is not there:**

- **Frequency.** SPARC is the total variation of the normalised spectrum, so sliding one peak along the axis does
  not change the length of the curve: a single clean wobble scores **identically** slow or fast. It ranks spectral
  *complexity* and *depth* — how many things the speed is doing at once, and how strongly. Real jerk is broadband,
  which is why it works; but *"the wobble got faster"* must be read from cusp density, not from this.
- **Anything above 20 rad/s (3.18 Hz).** By design: a 14 m truck does not change speed six times a second, and
  per-tick physics jitter that fast is not what the lead is watching.
- **Where the unit went.** SPARC is blind to position entirely.

### 4. Affine formation residual — *has a unit left its slot?*

Zhao (2018). Per element per tick, fit the least-squares affine map from the nominal slot geometry onto the actual
positions and report the residual RMS in metres.

**Exactly zero for any translation, rotation, scale or shear of the nominal shape.** An element that has wheeled,
spread out, or been squeezed through a corridor is still *in formation*; it goes positive only when a unit has left
its slot in a way the shared deformation does not explain — which is the thing a player actually sees.

Reported only for elements of **four or more members**: a 2-D affine fit has 6 parameters and 3 points determine it
exactly, so a 3-unit element's residual is identically zero and would read as a perfect formation. Smaller elements
are counted under `refused_too_small`, never reported as 0.000.

Known answer: on the unit square, displacing one vertex by *d* leaves every vertex out by *d*/4, so the RMS is *d*/4
— the brief's 3 m is **0.750 m**.

## The positive control

A12's acceptance is not that the four metrics are principled. It is that **the `oscillating` special case reproduces
round 8's finding** — 5.3–7.2% on yard / boneyard / pit / boulevard, in that order — from a re-run of the recorded
configuration at the recorded commit on the recorded machine. *A metric that cannot see a pathology we already
measured is the wrong metric.* The run, its pre-registered bar and its result are in
`_agents/streams/references/round9/metrics/README.md`.

("From the same replays", in the catalogue, cannot be taken literally: the replays did not exist. The honest control
is a re-run, and its provenance is written down as one.)

## Which of these is fit to be an optimiser objective (C7's prerequisite)

Catalogue **C7** (offline quality-diversity tuning) needs a scalar to maximise per niche, and the ruling on offline
compute makes it live. A12 exists because the numbers we had were measuring the wrong thing, so the question of
*which* of these four may be pointed at an optimiser is part of A12, not a later detail. **An optimiser pointed at a
bad objective does not fail — it succeeds at the wrong thing, faster than we can notice.**

- **Fit to optimise: windowed displacement efficiency.** It is bounded [0, 1], scale-free, has a defined optimum that
  is also the behaviour we want (drive where you were sent), and cannot be gamed by standing still — a parked unit
  produces no window at all rather than a perfect score. Maximise the **p10**, not the mean: the complaint is about
  the worst fifteen seconds of watching, and a mean lets a fleet of clean drivers pay for one unit shuffling in a
  corner.
- **Diagnostic only: signed cusp density.** Its optimum is a lie. Zero cusps is achieved by a vehicle that never
  reverses — including one that should have, and one that is stuck against a wall driving forward into it forever.
  It reads as a *constraint* ("no more than N per agent-minute"), never as an objective.
- **Diagnostic only: spectral arc length.** Its optimum is constant speed, which is achieved by never accelerating,
  braking or manoeuvring. An optimiser handed SPARC would discover that the smoothest army is one that ignores its
  orders. Use it as a constraint or as a tie-breaker between candidates that already pass the others.
- **Diagnostic only, and a trap: affine formation residual.** Zero is achieved by disbanding the element, by
  collapsing every slot onto one point, or by a formation so loose that any deformation explains it. It is a
  *detector*, and it is meaningful only against a fixed nominal geometry that the optimiser is not allowed to move.

**Recommendation for C7, when it comes:** one objective (p10 displacement efficiency) with the other three as
pre-registered constraint bands, and the behaviour scenarios (squad's fire concentration, the scout's engine decks)
kept as the outer gate — because lesson 150 is that the metric and the behaviour came apart, and no scalar we have
closes that gap on its own.

## How to read a `make metrics` run

Every row carries its commit, its machine, its window, its sample count and its unit count, and every refusal is
printed rather than folded into a zero:

- `efficiency_refused_zero_path` — windows where the unit did not move at all (0/0, not 1.0).
- `sparc_refused_parked` — windows whose speed profile sums to nothing.
- `sparc_refused_short` — windows that would have spanned a tick gap.
- `refused_too_small` — element-ticks with fewer than four members.

A log shorter than one window is **refused outright**: a metric over less than one window is not a smaller number,
it is no number.
