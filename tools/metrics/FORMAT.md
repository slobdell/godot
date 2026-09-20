# The Tank Squad trajectory log (format v1)

**Contract S3** (`_agents/workstreams.md`). One format, defined here, emitted by every producer. *If your harness
cannot produce it, ask metrics — do not invent a second one.*

Round 8's probes kept a per-unit position trail in memory and threw it away; every published number was a per-run
aggregate. That is why "reproduce it from the same replays" was not possible: **there were no replays.** This file
is the replay.

## The file

**JSON Lines**, UTF-8, LF. Extension `.jsonl`; the reader also accepts `.jsonl.gz` (gzip it after the run — Godot's
own compression is not gzip, so the emitter always writes plain).

- **Line 1 is the header.** Exactly one, and it must be first.
- **Every other line is one sample: one unit, one tick.** Samples are written in tick order; within a tick, in the
  producer's iteration order. The reader groups by unit and sorts by tick, so a producer need not interleave.
- Blank lines are skipped. **Nothing else is tolerated**: a malformed line, an unknown `kind`, a missing required
  field or a field of the wrong type **refuses the whole file, loudly, naming the line number**
  (`_agents/workstreams.md` Invariant 0 — *no fallback*: a log we cannot read must never become a log that reads as
  "nothing happened").

## The header

```json
{"kind":"header","format":"tank-squad-trajectory","version":1,
 "commit":"aa984edd","machine":"builder0","tick_rate":30,
 "arena":"yard","seed":3,"producer":"nav-fight",
 "command":"godot --headless ... --arena=yard --seed=3","knobs":{"time_limit":120.0,"busy":0.0,"budget":6500}}
```

| field | type | meaning |
|---|---|---|
| `kind` | `"header"` | |
| `format` | `"tank-squad-trajectory"` | refuses anything else |
| `version` | int | `1`. A reader refuses a version it does not know |
| `commit` | str | the tree the run was made from (`git rev-parse --short HEAD`), `"unknown"` only if git is absent |
| `machine` | str | hostname. **Every number carries its commit and its machine** (CLAUDE.md rule 4) |
| `tick_rate` | int | simulation Hz. Windows are defined in seconds and resolved against this |
| `arena` | str or null | layout name |
| `seed` | int or null | |
| `producer` | str | `"nav-fight"`, `"match-runner"`, `"synthetic"`, … |
| `command` | str | the command line, for the reproduce row in the README |
| `knobs` | object | **every resolved knob, with the value it resolved to** (lesson 44: print what each knob resolved to, not what was passed) |

Unknown extra header keys are kept and passed through. They are documentation, not data.

## A sample line

```json
{"tick":412,"unit":"Green_alpha_2","unit_id":"scout","team":0,
 "x":-13.25,"z":41.5,"heading_rad":7.3512,"speed_mps":-1.84,"gear":-1,
 "goal_x":10.0,"goal_z":60.0,"order_verb":"attack_move","element":3,"slot_x":8.5,"slot_z":57.25}
```

### Required in every sample

| field | type | notes |
|---|---|---|
| `tick` | int | the simulation tick. Monotonic per unit; **gaps are allowed and are meaningful** — a window never spans a gap |
| `unit` | str | node name, unique within the run |
| `unit_id` | str | the unit *type* (`scout`, `war_rig`, …). Metrics are reported per type |
| `team` | int | |
| `x`, `z` | float | world position. **x/z only — a ramp is not travel** (`fight_probe.gd` `_flat`) |
| `heading_rad` | float | **UNWRAPPED**: continuous, accumulated, never re-wrapped to ±π. Round 8's 20.7° "overshoot" was a wrap bug (`archive/round8/nav.md` item 8). A consumer that wants an angle wraps it itself |
| `speed_mps` | float | **signed**: negative in reverse |
| `gear` | int | −1, 0 or 1. **Diagnostic only.** No metric reads it — cusp density is defined from position and heading precisely so that it sees a reversal the controller never labelled |
| `goal_x`, `goal_z` | float **or null** | the goal of the order the unit currently holds. Both null together when it holds no order |
| `order_verb` | str **or null** | `move`, `attack_move`, `hold`, … Null when it holds no order |
| `element` | int **or null** | element id, or null when it belongs to none |
| `slot_x`, `slot_z` | float **or null** | **the slot its leader ASSIGNED this tick, deformation included** (`Element.slots`) — *not* a shape reconstructed from a formation name. See below. Both null together when it has none |

`null` is a value, not an absence: the **key must be present**. A sample missing `goal_x` is refused; a sample with
`"goal_x": null` is a unit under no orders.

#### `slot_x` / `slot_z` is the leader's INTENT, and that is what makes the residual fair

The affine formation residual is measured against whatever you log here, so what you log decides what the metric
means. **Log the slot the leader assigned on this tick** — `Element.slots[unit]`, or `place()`'s `offset` if you
prefer the element frame (the fit absorbs any rigid change of frame, so the two give the same number). **Do not
reconstruct a nominal shape from the formation name.**

squad's A8 narrows a formation to fit a corridor with a *file morph* that is deliberately **not affine**: a wedge
has pairs of slots at the same depth, and no 2×2 can separate two points that differ only across the heading while
squeezing that axis toward zero — at the limit they land on top of each other, which is why a literal affine
reading of "a wedge becomes a column" would stand hulls inside each other in the narrowest corridors. If the
reference were the nominal wedge, an element that had **correctly** filed through a defile — every unit exactly on
the slot its leader gave it — would read as a large residual: a false positive on the one manoeuvre A8 exists to
produce. Against the commanded slot, every deformation the leader ordered is free, affine or not, and the residual
measures only departure from the element's own intent.

Two consequences, both reported rather than hidden:

- **An element in single file has collinear slots.** The affine *coefficients* are then ambiguous but the residual
  is not, so the fit is an orthogonal projection and such elements are still measured — a unit standing out of the
  file is seen. `make metrics` prints the reference `rank` (3 a real shape, 2 a file, 1 every slot in one place),
  because a small residual at rank 2 means something different from a small residual at rank 3.
- **Elements of three or fewer are refused, never reported as 0.000.** Three points determine a 2-D affine map
  exactly, so their residual is identically zero. They appear under `too_small`. (Attrition produces them, so a
  falsifier needs its own answer there — squad's is geometric: zero crossings and zero rank inversions, which
  hold from two members upward.)

### Optional in every sample — each one all-or-nothing

These say *why* a unit did what it did, so a metric can separate an ordered manoeuvre from a pathology.

**Each column is all-or-nothing across a log** — present in every sample or in none. A log where some samples carry
one and some do not is refused: that is the shape in which a partial column silently becomes a wrong denominator.
The **set** of columns is the producer's choice, so a harness that can answer three of them is not forced to fake a
fourth. (Per-column rather than per-set since 2026-09-20, when `facing_ordered` was added after logs already
existed with the other three.)

| field | type | notes |
|---|---|---|
| `order_reverse` | bool or null | the order asks for reverse (a yield spot behind it, a retreat) |
| `phase` | str or null | `Movement.state(tank).phase` — `yielding`, `blocked`, `none`, … |
| `creeping` | bool or null | the plant is in its wheeled creep (K-turn legs) |
| `facing_ordered` | bool or null | the unit's ORDER carries an arrival facing (order-level, true for the whole journey) |
| `facing_arc` | bool or null | **the arrival ARC is live on this tick** (see below) |
| `corridor_x`, `corridor_z` | float or null, **paired** | the unit tangent of the path leg nav is **currently driving** (`Movement.state(unit)["corridor"]`) — see below |

Without the first three, every cusp is reported as `unclassified`, and `make metrics` says so rather than
reporting a zero.

#### `facing_ordered`, and the rule that comes with it

Control shipped desktop right-drag facing, so a move order can now carry an arrival heading, and **an arrival arc
at the end of a dragged move is off-corridor by construction — that is the unit OBEYING.** Ruled by the
orchestrator with control, 2026-09-20:

> **Ticks under an ordered facing count as *ordered*, never as off-corridor, and are reported BESIDE the fraction,
> never inside it.**

So:

- Signed cusp density puts a reversal inside such an arc in `cusps_ordered`. It must never reach `unexplained` —
  that is the bucket A6's falsifier reads, and charging it for obedience would fail the contract for doing the
  right thing.
- Every report carries `facing_ordered_seconds` next to the counts, as a separate tally and not a subtraction, so
  a reader can see how much of a run was under an ordered facing and judge a fraction themselves.
- **Any future off-corridor or opposing-tangent statistic obeys the same rule**, and `make metrics` refuses to let
  a log without this column masquerade as one that has it: it prints a NOTE saying no off-corridor verdict may be
  published from that log.

#### `corridor_x` / `corridor_z`, and the three states that must not collapse

A6's falsifier (`_agents/legibility.md` §7) is *"time fraction with velocity opposing the corridor tangent, under
attack-move, over active ticks"* — **measured with A12 and nothing else**, because the quantity is trajectory-space
and A12 exists so every stream reads it from one implementation. Velocity is derivable from consecutive samples;
the tangent is not, so it is logged.

**It is the leg, not the bearing to the goal.** §2: the corridor is *"the path nav is currently driving, not the
straight line to the goal"*. A hull rounding a corner has a tangent along its leg while the goal bearing points
through a wall — which is exactly the case A6 exists for, so a statistic built on `goal_x`/`goal_z` would be wrong
precisely where it matters.

**Three states, and the metric keeps them apart:**

| state | in the log | what the metric does |
|---|---|---|
| **no data** | the columns are **absent** | `off_corridor=null`. **No verdict may be published.** |
| **inactive** | present, **null** | nav says there is no leg right now — a *named* case (§5). Counted in `inactive`, excluded from the fraction's denominator |
| **active** | present, a unit vector | scored |

**Producers: read the key with `has()`, never `get("corridor", null)`.** The default-argument form cannot tell
*"nav answered null"* from *"this build has no such key"*, so a consumer falls through to its fallback on exactly
the ticks where nav said there is no leg (control hit this within minutes of adopting the key). The reference
emitter omits the columns entirely when the key is absent, which is what makes the first row above visible.

**The active fraction travels with the fraction, always.** §7 requires it and the report prints them together:
*a falsifier that improves because the law switched itself off more often is not a pass.*

**Ordered arrival arcs are excluded and counted separately** (`ordered_arc`), on `facing_arc` and never on
`facing_ordered` — an order carries its facing from the moment it is issued, so excluding on that would excuse the
whole drive to the gate and hide the pathology being measured.

Producer: nav's `fight_probe.gd` emitter (nav has been asked for it). Until it lands, logs simply omit the column
and the NOTE appears.

## Size

30 Hz × 60 units × 120 s ≈ 216,000 lines ≈ 45 MB. Gzip takes it to ~4 MB.
Emit only what the run is about (the emitter's `--trajectory-team=` limits it), and gzip before committing a log
to `_agents/streams/references/`.

## Reading it

`tools/metrics/trajlog.py`:

```python
from trajlog import read_log
log = read_log("build/metrics/yard.jsonl")   # raises TrajectoryLogError on anything malformed
log.header.tick_rate                          # int
log.units                                     # {unit_name: [Sample, ...]}, each sorted by tick
```

Everything in `tools/metrics/` is **pure Python 3 with no third-party dependency** — no numpy, no scipy. The FFT is
ours (`metrics.py`, radix-2), so the number is identical on the laptop and on builder0.
