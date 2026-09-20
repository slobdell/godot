# A12's positive control: reproducing round 8's oscillation finding

> **This section was written and committed BEFORE the run's numbers existed.** Its bar is the one in
> `_agents/streams/metrics.md` backlog item 3, which the orchestrator pre-registered on 2026-09-19.
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

_(filled in after the run)_

## Result

_(filled in after the run — and if the bar is missed, it says so here first.)_
