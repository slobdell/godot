# A12's positive control: reproducing round 8's oscillation finding

> **This section was written and committed BEFORE the run's numbers existed.** Its bar is the one in
> `_agents/streams/archive/round9/metrics.md` backlog item 3, which the orchestrator pre-registered on 2026-09-19.
> The results table below is filled in afterwards and says plainly whether the bar was met.

## What is being controlled, and why it is a re-run and not a replay

The catalogue says A12 must reproduce the round-8 finding *"from the same replays"*. **The replays do not exist.**
Round 8's probes kept a per-unit position trail in memory and threw it away; every saved JSON in
`references/round8/` is a per-run aggregate. So the honest control is a re-run of the recorded configuration at the
recorded commit on the recorded machine, with the new emitter added and nothing else changed — and this file is its
provenance.

It also cannot be run on `main`: **`game/` has moved 1,261 lines across 28 files since `aa984edd`** (and the sim
baseline hash moved with it), so a difference measured there would confound *"the metric is wrong"* with *"the game
changed"*.

## The configuration, from the archived brief and not from memory

`_agents/streams/archive/round8/nav.md` — *"The headline, re-measured on main. Tree `aa984edd` (main `f5526594`
merged, no nav changes on top), builder0, attack_move, Condemned vs Condemned, seed 3, 120 s. Arm read live:
commit=true, standoff."*

| knob | value | where it comes from |
|---|---|---|
| tree | `aa984edd` + the emitter only | the archived brief |
| machine | builder0 | the archived brief (the laptop is ~2.75× slower and is not comparable) |
| target | `nav-fight-maps` | the archived brief, *"Stall repro, `nav-fight-maps`, attack_move, arena's counters"* |
| maps | yard, boneyard, pit, boulevard | the headline table |
| `FIGHT_BUSY_LEVELS` | `0` (scripted, no player re-orders) | the archived brief, *"the 4 maps, busy 0, seed 3, 120 s"* |
| `STALL_VERB` | `attack_move` | the archived brief |
| `FIGHT_SEED` | 3 | the archived brief |
| `NAV_TIME` | 120 | the archived brief |
| `FIGHT_BUDGET` | 6500 | `mk/nav.mk`'s default at that tree |
| factions | Condemned vs Condemned | `mk/nav.mk`'s default (no `--*-faction` flag) |

**The only change to the tree** is metrics' emitter: `tools/metrics/trajectory_log.gd` copied verbatim from
`stream/metrics` `01bb2f23`, plus the same six-line `--trajectory=` hook in `tests/nav/fight_probe.gd`. Nothing that
the simulation reads is touched, and the run's own `NAV_FIGHT` line is produced by the unmodified counters — so the
probe's own number and the tool's number come out of **one run**, which removes commit, machine, seed and load as
confounds between them.

### Reproduce it

```sh
git worktree add --detach build/godot-metrics-r8 aa984edd
# copy tools/metrics/trajectory_log.gd in and add the six-line hook to tests/nav/fight_probe.gd, then:
cd build/godot-metrics-r8 && tools/remote.sh nav-fight-maps \
  TANK_SQUAD_SLOT_TIMEOUT=14400 "FIGHT_MAPS=yard boneyard pit boulevard" FIGHT_BUSY_LEVELS=0 \
  STALL_VERB=attack_move FIGHT_SEED=3 NAV_TIME=120 FIGHT_BUDGET=6500 \
  'NAV_FLAGS=--trajectory=$(CURDIR)/build/nav-maps/$$map.jsonl'
```

Then, from `stream/metrics`:

```sh
make metrics LOGS="<logs>" --order-verb=attack_move --team=0   # via: python3 tools/metrics/run_metrics.py
```

## The pre-registered bar (brief item 3, written 2026-09-19)

1. **The threshold reproduces.** Displacement efficiency's `oscillating` special case lands in **5.3–7.2%** on the
   four maps, **within ±0.5 points per map**, with the same per-map ordering **yard > boneyard > pit > boulevard**.
2. **The continuous metric says something the threshold could not.** Report the distribution of window efficiencies
   per unit type, and whether **the scout is the shuffler** (round 8: scout 0.68 `net_over_path`, rig 0.95 —
   catalogue A8).
3. **If it does not reproduce, the first suspect is the arm** (`NAV_FIGHT_ARM`, lesson 147: prove the arm), the
   second is the commit, the third is the metric — in that order.

## Files

Run on **builder0**, tree `1422acd9` (= `aa984edd` + metrics' emitter and the one-token `NAV_FLAGS` pass-through,
throwaway branch `tmp/metrics-r8-control`), 2026-09-20.

| file | what |
|---|---|
| `<map>.jsonl.gz` | **the replay.** The full per-tick trajectory log, ~5 MB gzipped (~77 MB raw), 118k samples, 34 GREEN + 44 RUST units, 120 s. Kept because round 8's whole problem was that no replay existed; the next round can re-measure this fight without re-running it |
| `<map>-metrics.json` | `make metrics`'s full report, machine-readable |
| `<map>-metrics.txt` | the same, as printed |
| `<map>-probe.json` | the run's own `NAV_FIGHT` line — **the unmodified round-8 counters from the same run**, which is what makes the comparison below free of commit, machine, seed and load as confounds |

Re-read any of them without re-running anything:

```sh
python3 tools/metrics/run_metrics.py _agents/streams/references/round9/metrics/yard.jsonl.gz \
    --team 0 --order-verb attack_move
```

**Run once from this README to prove it runs** (lesson 44): all four `.gz` files were re-read from these stored
paths and reproduced the table below.

## Result — the bar is MET

### 1. The threshold reproduces. Exactly.

| map | round 8 published | the probe, this run | **A12's tool, this run** | delta (tool − probe) | units r8 | units probe | units A12 |
|---|---|---|---|---|---|---|---|
| yard | 7.2% | 7.2% | **7.16%** | −0.04 pt | 28 | 28 | 27 |
| boneyard | 6.6% | 6.6% | **6.65%** | +0.05 pt | 27 | 27 | 27 |
| pit | 5.8% | 5.8% | **5.81%** | +0.01 pt | 25 | 25 | 25 |
| boulevard | 5.3% | 5.3% | **5.30%** | +0.00 pt | 28 | 28 | 28 |

- **Round 8's published shares came back bit-for-bit** on all four maps, with the same unit counts. The arm was
  proven live before any number was read — `NAV_FIGHT_ARM commit=true fixed_style=standoff avoidance=true
  station=true off=[]`, matching the archived brief's *"commit=true, standoff"* (lesson 147).
- **A12's tool lands within 0.05 percentage points of the counter on every map**, against a bar of ±0.5 — a factor
  of ten inside it — and the per-map ordering **yard > boneyard > pit > boulevard** is preserved.
- The under-way denominators agree to **1.1–1.2 s out of 1300–1520 s (0.08%)**, and the gap is one frame on every
  map: a single sampling frame's difference between a node reading `physics_frame` and the probe's own handler on
  the same signal.

**Where they differ, and which statistic to trust.** `oscillating_units` differs by one on yard (27 against 28).
That unit sits exactly on the window boundary: re-running the same log at window lengths 118–122 samples flips it
back and forth (118 → 28, 119 → 28, 120 → 27, 121 → 27, 122 → 27) while the share stays at 7.07–7.16% throughout.
**So the share is the robust statistic and the unit count is not** — a bar pre-registered on "how many units ever
oscillated" is a bar on a coin flip for the borderline unit, and this is written down so nobody registers one.

### 2. What the continuous metric says that the threshold could not

The threshold answers *"was it below 0.25?"*. The distribution answers *"how much of the time was it anywhere
near driving?"*, and the two are not the same picture (yard, GREEN, attack_move):

| unit_id | units | efficiency mean | efficiency p10 | oscillating share | cusps / agent-minute | SPARC |
|---|---|---|---|---|---|---|
| ifv | 7 | 0.624 | 0.250 | 12.1% | 35.8 | −2.23 |
| lancer | 6 | 0.619 | 0.216 | 9.4% | 34.8 | −2.10 |
| tank | 21 | 0.798 | 0.388 | 4.9% | 7.4 | −1.94 |
| **all** | 34 | 0.709 | 0.288 | 7.2% | 18.1 | −2.05 |

1. **The light WHEELED hulls are the shufflers, and the tanks are not.** `ifv` and `lancer` oscillate **2.5×** as
   often as `tank` and reverse **~5×** as often. This is round 8's A8 finding arrived at from the other side —
   *"the scout is the shuffler (0.68 `net_over_path`), not the rig (0.95)"* — on a Condemned roster that fields no
   scout. It is a **locomotion** effect, not a unit.
2. **The threshold understates it by a factor of four.** A tenth of every wheeled unit's windows sit at or below
   **0.22–0.25** efficiency, against the 7.2% of ticks the threshold flags. The lead is watching the p10, not the
   mean, and not the threshold.
3. **56% of all reversals are the wheeled creep, and we can now say so.** Split by cause: 665 creep, 234 ordered,
   293 unexplained of 1,192 cusps — and **`tank` produces zero creep cusps** (a tracked hull does not creep) while
   splitting evenly between ordered and unexplained. Round 8's gear-flip counter, reading the controller's labels
   rather than the motion, could only report about a third as unexplained.
4. **27,500 tank windows were refused, not scored.** Those are hulls holding station at a standoff and not moving
   at all; scoring them 1.0 (as "net == path == 0") or 0.0 would have moved the army-level mean by more than the
   pathology does. They are reported as `refused[zero_path=...]`.

### 3. Two corrections the control forced, both found by running it rather than reading it

- **The first run reproduced round 8 perfectly and wrote no trajectory log at all.** At `aa984edd`,
  `nav-fight-maps` had no `$(NAV_FLAGS)` pass-through — nav added it later — so `--trajectory=` never reached the
  probe. The one-token fix is on the throwaway branch, named in its commit as not for merge. *A run that exits 0
  and produces the expected numbers can still have done none of the thing you asked for.*
- **The emitter's header said `commit=unknown` on builder0**, which is the machine nearly every number this project
  quotes comes from: `tools/remote.sh` excludes `.git/` from the rsync and exports `TANK_SQUAD_COMMIT` instead, and
  says so in its own comment. Fixed before these files were stored, which is why the header above reads `1422acd9`.
