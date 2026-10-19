# Round 33 traffic (after R33.17): does a traffic static carry one match into the next? No; the ghost carries the physics server's state

Asked by brains via the orchestrator: the body stage's order swing isn't frame phase (brains, laptop, bbb4d2db). Laptop,
2026-10-17 ~18:00 PDT, tree pair/ghost-on-r33 (game code bbb4d2db, ghost ON by default), GDScript path (the laptop has no
native library built, so native is out of these runs), `--fixed-fps 60`, tests/traffic/rematch_probe.gd: brains' body stage
seed 1, body OFF, twice in ONE process, n 1 per row (each row is deterministic: identical across processes).

## (1) Every static in traffic's files, and what resets it
- traffic.gd verdict / hold / crossing caches (`_cross_answers`, `_cross_kept`, `_shares`, `_looked`, `_verdicts`,
  `_waits`, `_live`, `_streets`): `_forget()`, which `refresh()` calls whenever the tanks root changes (every new match).
- traffic.gd table (`_root`, `_frame`, `_map`, `_where`, `_teams`, `_movers`): rebuilt by `refresh()` on a new root.
- Survive a match and are harmless: the counters (`verdicts` ... `cross_reach_free`: stats, `reset_counters()`);
  `last_share` (written, never read in game); `_last_point` (scratch, written before it's read); `log_waits`,
  `street_override`, `ground_override`, `destinations` (tests only: no game writer); `_off` / `_parsed` (the switches).
- avoidance.gd: the table (`_table_root` / `_table_frame` / columns / `_grid` / `_index`) rebuilt per root and frame;
  `_radius_by_unit`, `_halves_by_unit`, `_unit_rows` keyed by unit TYPE (from its size: the same in every match);
  `solved` / `deflected` / `oriented_pairs` counters.
- steering.gd: no statics. movement.gd's give-way block: counters and logs only (`parked_rooms`, `room_log`,
  `yield_*` counters).
- Not traffic's, read by it: `Movement._registry` (keyed by instance id; match 1's entries are never looked up again; a
  leak, not carried behaviour).

## (2) The second match, cleared v not
| ghost | clear before match 2 | match 1 alone_s / arrived | match 2 alone_s / arrived |
|---|---|---|---|
| ON | none | 37.0 / 17.2 | 28.5 / 14.8 |
| ON | every traffic static (rematch_probe `clear_traffic`) | 37.0 / 17.2 | 28.5 / 14.8 |
| ON | traffic + Movement._registry | 37.0 / 17.2 | 28.5 / 14.8 |
| ON | brains' 12 named caches (body_twice_probe, incl. Traffic._forget) | 37.0 / 17.2 | 28.5 / 14.8 |
| ON | traffic, `--brains-off=native` | 37.0 / 17.2 | 28.5 / 14.8 |
| OFF (`--traffic-off=ghost`) | none | 35.0 / 16.1 | 35.0 / 16.1 |
| OFF | every traffic static | 35.0 / 16.1 | 35.0 / 16.1 |

Reading: no traffic static carries a match. With the ghost OFF a rematch replays exactly. With the ghost ON it does not,
and no GDScript static that anyone has named stops it. The ghost's input is `Tank.real_velocity` =
`CharacterBody3D.get_real_velocity()` (tank.gd:734-748), i.e. the physics server's contact result. Whatever the server
keeps from match 1 (freed bodies, broadphase order) reaches ORCA's neighbour table, and the closed loop grows it. That is
a property of the ghost (it feeds physics noise into avoidance), not stale traffic state, so there's no reset to build
here. For T4 in round 34: an order-free guard needs the stage in a fresh process per arm (brains' f8cf6476 hardening
does that). Whether the physics server's history should be cleared between matches (a rematch is a new process today?)
is the tank/match owners' call.
