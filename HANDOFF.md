# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** It has the
> mental model, the context-handoff workflow, and the trip-ups (now 28 of them).
> Then come back here.

_Last updated: 2026-09-13. Tank Brain v1 (the deterministic CPU middle layer) committed and measured._

## Current state

- `make check` passes (lint, 70 tests, net/combat/match smoke, **determinism**); web-net-smoke and the exported server (with bots) are clean.
- **One URL for browser play:** `make play BOTS=1` → `http://localhost:8060/?connect`. The lead's first attempt opened the game server's WebSocket port in a browser; `/ws` is now proxied (trip-up #26).
- **AI v1** ([tank_brain.md](_agents/tank_brain.md)): autonomous `TankBrain`s (utility scoring over directive weights), directives + doctrines as JSON (`doctrines/`), shared team vision with memory, weapons as data (cannon + flamethrower), `make watch-match`, `make lint`, `make determinism`.

## What the experiments say (details and method in tank_brain.md § Results)

| | Result |
|---|---|
| **Coordination vs the same tanks uncoordinated (T1)** | **62.5%** from both bases: the lead's thesis holds in simulation |
| Brains vs the old BotController (T2) | 35% → **70%** after fixing a target-lock bug found with the new idle-gun metric |
| Flamethrower doctrines (T3/T3b) | 6% and **0%**: the flamethrower is a dominated weapon and needs a real trade-off |
| Brain mirror match (T0b) | Rust 58% from both bases (p ≈ 0.07): possible ordering bias; counterbalance team identity |

## Next tasks (in order)

1. **Wait for the lead's decisions:** (a) the squad-command UI direction (3 options in tank_brain.md), (b) the flamethrower trade-off (speed/HP/smoke/map cover), (c) combat feel from their smoke test.
2. Investigate T0b (`--rust-first`, larger N) before any close experiment.
3. Switch `make run` / server bots from BotController to TankBrain (T2 justifies it).
4. Tuning candidates from the data: rear hits ~0% (flank standoff/approach), idle guns ~72% for everyone (turret speed/aim tolerance).

## Notes for whoever picks this up

- The lead may still have an old `make server` running on port 9080 (it blocks `make play` there). Ask before killing it.
- Never edit game scripts while a `match_series.py` run is in progress: every match process loads scripts at start, so mid-run edits contaminate results.
