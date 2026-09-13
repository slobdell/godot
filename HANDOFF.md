# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** It has the
> mental model, the context-handoff workflow, and the trip-ups (now 25 of them).
> Then come back here.

_Last updated: 2026-09-13. M4 infrastructure committed. **Paused for the project lead's smoke test before any AI work.**_

## Current state

**M0–M3.5 and the M4 infrastructure are done, verified, and committed.**
`make check-all` passes from a clean build: 48 tests, net-smoke, combat-smoke,
match-smoke (~68× real time), desktop and browser screenshots (inspected), and
a clean exported-server shutdown with bots.

What you can do right now:
- `make run` (or `make run BOTS=3`): play offline vs bots. WASD/arrows drive, mouse aims, click/space fires.
- `make play BOTS=1` → `http://localhost:8060/?connect`: browser multiplayer with bots (one command, one URL).
- `make server` + browser + ask Claude to run `make agent-client`: **play against Claude** ([agent_bridge.md](_agents/agent_bridge.md)).
- `make matches N=40 JOBS=6 GREEN=2 RUST=2`: robot series with win rates.

## What happened in this session (M4 infrastructure)

1. **Navmesh pathing**: bots and orders route around walls (the playtest #1 deadlock is now a passing test).
2. **Reflexes** (conditional standing orders: `retreat_below_hp`, `halt_on_contact`) with an event log, the smallest version of doctrine phases; `reverse` moves.
3. **Match runner** (`--match`, `make match/matches/match-smoke`) with shot/hit/armor-face/kill stats.
4. **Fairness bug found by the match runner and fixed:** the south base won 64% of 140 matches because the navmesh bake was asymmetric. The navmesh is now half-baked + mirrored, and it's 51% over 120 matches. Full method in [squad_ai_design.md § Fairness](_agents/squad_ai_design.md#fairness-measure-it-dont-assume-it), guarded by a symmetry test.
5. **Playtest #2** (Claude lost 4–1): the retreat reflex exposed the rear armor, so retreats now back away by default. Details in [agent_bridge.md](_agents/agent_bridge.md).

## Next task: WAIT for the lead's smoke test, then M4 AI

Don't start these until the lead has played and given feedback:
1. Perception memory (last-known positions, detection radius): bots stop being omniscient.
2. `UtilityController` (actions × directive weights, commitment bonus) + a score overlay → experiment **E1**.
3. Playtest #3 to validate reverse retreats.

If the lead's feedback changes combat feel (speed, reload, damage, camera), do that first and re-run the fairness control afterwards.

## Open decisions for the project lead

1. **Smoke test:** does combat feel right (speed, reload, damage, camera distance)? Anything confusing?
2. **Play against Claude** once, while it's fresh (runbook in agent_bridge.md).
3. Still open: your son's Godot version and OS; the working title.
