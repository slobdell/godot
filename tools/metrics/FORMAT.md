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
| `slot_x`, `slot_z` | float **or null** | its assigned slot in its element's formation. Both null together when it has none |

`null` is a value, not an absence: the **key must be present**. A sample missing `goal_x` is refused; a sample with
`"goal_x": null` is a unit under no orders.

### Optional in every sample — all-or-nothing

These let signed cusp density split *ordered* from *unexplained*. A log where **some** samples carry one and some do
not is refused: that is the shape in which a partial column silently becomes a wrong denominator.

| field | type | notes |
|---|---|---|
| `order_reverse` | bool or null | the order asks for reverse (a yield spot behind it, a retreat) |
| `phase` | str or null | `Movement.state(tank).phase` — `yielding`, `blocked`, `none`, … |
| `creeping` | bool or null | the plant is in its wheeled creep (K-turn legs) |

Without them every cusp is reported as `unclassified`, and `make metrics` says so rather than reporting a zero.

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
