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

**The reference is the slot the leader ASSIGNED that tick** (`Element.slots`), never a shape reconstructed from a
formation name — see FORMAT.md. squad's A8 files a formation through a corridor with a morph that is deliberately
not affine, and against a nominal shape an element that had *correctly* filed would read as a large residual: a
false positive on the one manoeuvre A8 exists to produce. Against the commanded slot, every deformation the leader
ordered is free and only departure from the element's own intent is measured.

Reported only for elements of **four or more members**: a 2-D affine fit has 6 parameters and 3 points determine it
exactly, so a 3-unit element's residual is identically zero and would read as a perfect formation. Smaller elements
are counted under `refused_too_small`, never reported as 0.000.

The fit is an **orthogonal projection**, not a 3×3 solve, so an element filed into single file — whose slots are
collinear and whose affine coefficients are therefore ambiguous — is still measured rather than refused. The
report carries the reference `rank` (3 a real shape, 2 a file, 1 every slot in one place) so a reader knows why a
residual is small.

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

## A6's falsifier: off-corridor fraction

Not a fifth metric either — the statistic `_agents/legibility.md` §7 names, computed here because §7 says it is
**measured with A12 and nothing else**: one quantity, one implementation, every stream reading the same number.

> *Time fraction with velocity opposing the corridor tangent, under attack-move, over active ticks: 30–36% → under 10%.*

Velocity comes from consecutive samples; the **corridor tangent is logged** (`corridor_x`/`corridor_z`), because
it cannot be derived. It is the tangent of the **leg nav is currently driving**, never the bearing to the goal —
a hull rounding a corner drives along its leg while the goal bearing points through a wall, which is exactly the
case A6 exists for.

**What the report prints, and why every part of it is there:**

    off_corridor=0.312 (active 0.845, 12440 ticks; inactive 1980, slow 310, ordered_arc 122)

- **`off_corridor`** — the fraction itself, over *active* ticks only. **`null` when the producer's build has no
  corridor key**, and then no verdict may be published from that log.
- **`active`** — the active fraction, and it is **half the result, not a footnote**: a law that improves its own
  number by switching itself off more often is not a pass. §7 requires it beside the fraction; the renderer
  cannot print one without the other. **P7's baseline shows why it is worth the space:** across yard / pit /
  terminus the fraction barely moves (0.304 / 0.321 / 0.331) while the **active fraction moves far more**
  (0.631 / 0.595 / 0.738). So the pathology is roster-wide but A6's *opportunity* to act on it is
  map-dependent — a distinction invisible in the fraction alone (nav, 2026-09-20).
- **`inactive`** — nav published the key and said *no leg right now*. A named case (§5), not an absence.

#### The control arm A6 has to beat, read off nav's P7 logs (metrics, 2026-09-20)

Whole roster, both armies, builder0. **Two of the three logs are usable** — see the corruption note below.

| map | commit | off_corridor | active | eff_mean | eff_p10 | osc_share | net/path | cusp/min | sparc |
|---|---|---|---|---|---|---|---|---|---|
| yard | `c025bc6b` | 0.304 | 0.631 | 0.681 | 0.220 | 0.044 | 0.815 | 43.10 | **−2.013** |
| terminus | `5369bd13` | 0.331 | 0.738 | 0.660 | 0.210 | 0.052 | 0.799 | 69.14 | **−2.013** |
| pit | `c025bc6b` | — | — | — | — | — | — | — | — |

**The two commits differ by one Status file and nothing else** (`git diff --stat 5369bd13 c025bc6b`:
`_agents/streams/nav.md`, 28 lines), so the rows are comparable. That is the mixed-commit banner working as
intended: it flagged the mixture, printed the command that settles it, and the command settled it — the
reader verified rather than assumed.

**Pick the discriminator by what the map does NOT change.** `cusp/min` swings 60% between these two maps
(43 → 69) with no treatment applied at all, so a treatment effect smaller than that is unreadable against
it. `sparc` is **−2.013 on both**, to three decimals, across maps whose cusp densities differ by half. For
an A/B on one map either will do; for a claim that survives the rotation, **SPARC is the sensitive one and
cusp density is mostly measuring the arena**.

#### ⚠ `p7-pit.jsonl` is UNUSABLE: one flipped bit

One byte in 273,578 lines — `0x78` (`x`) → `0xf8`, turning `"slot_x"` into a broken key at line 143,873 of a
101 MB log written on builder0 and copied to the laptop. A single-bit flip, not a producer bug and not a
format problem.

**The loud failure is the lucky case.** That bit landed in a key name, so the reader refuses the file. Had it
landed in a digit it would have read as a perfectly valid coordinate and quietly moved a number. Nothing in
this toolchain would have caught it, and nothing yet does — a per-line checksum in the format would, and is
not there. Until the log is re-produced, **no A6 figure may quote pit**, and the earlier pooled rotation
figure (0.3203) is not reproducible from these files.

`trajlog` now refuses a bad byte with its file, its line, the byte, and its neighbourhood, and says *re-run
the producer, do not patch the file* — patching the one visible byte would leave any invisible ones and
bless the file. It used to escape as a bare `UnicodeDecodeError` naming a codec and an offset into a buffer.
- **`ordered_arc`** — excluded because an ordered arrival arc is off-corridor **by construction** and is the unit
  obeying. On `facing_arc`, **never** on `facing_ordered`: an order carries its facing from the moment it is
  issued, so excluding on that would excuse the whole drive to the gate.

### Pooling several maps into one figure (`--pool`)

    python3 tools/metrics/run_metrics.py "build/metrics/*.jsonl.gz" --team 0 --order-verb attack_move --pool

Prints the per-file rows as usual and then **one pooled row**, so a rotation figure across yard / pit / terminus
is one command rather than four and a calculator.

**Pooled by TICKS, never by averaging the per-file fractions** — and the mean is printed *beside* the real
figure so the weighting is visible rather than taken on trust. On P7 the two agree to a thousandth (0.3203 against
0.3187) **only because the three maps carry similar weight**; on files that do not, the mean is quietly wrong. A mean would weight a 30 s log the same as a
120 s one, which is how a rotation number ends up dominated by its shortest map. A 10 s log at 90% pooled with a
190 s log at 10% is **14%**, not 50%, and there is a test that says so.

Three things it refuses to do:
- **Launder a missing column.** A quantity that is `null` in *any* file is `null` in the pool — one log without
  the corridor column makes the pooled off-corridor fraction unpublishable, exactly as it does for that log alone.
- **Hide a disagreeing map.** The per-file rows stay above the pooled one, so a map that differs from the pool is
  visible rather than averaged away.
- **Pool across trees or machines silently.** Mixed commits or machines print a ⚠ REFUSE TO QUOTE THIS banner
  naming them (CLAUDE.md rule 4; the laptop is ~2.75× slower than builder0).

## Hull turn between events (`--switches`)

Not a fifth metric — a read the log already supports, added for combat's A2 question and available to anyone.

```sh
python3 tools/metrics/run_metrics.py run.jsonl --switches build/switch-events.json
```

`--switches` takes `{unit name: [tick, ...]}` and reports, per unit type, the distribution of **|Δ heading| in
degrees between consecutive events** — the hull's own rotation between two decisions. It exists because
`heading_rad` is logged **unwrapped**, so a 201° turn reads as 201° and not as −159°; round 8's 20.7° "overshoot",
which justified parking a whole technique, was that wrap bug.

**What it is not:** the change in bearing to a *target*. Nothing in a trajectory log knows what a unit was
shooting at. A unit that switched between two targets while driving straight reads ~0°, which is the honest
answer to *"did the hull have to turn"* and not to *"were the targets far apart"*. Units whose events are not in
the log are named rather than dropped — that usually means the events came from the other arm of an A/B.

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
