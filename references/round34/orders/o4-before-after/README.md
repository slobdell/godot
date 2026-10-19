# O4 before/after through the O5 probe (planner, 2026-10-19; builder0, native, main arm, 3-waypoint shifted routes, n 1 a cell, deterministic)

- before: lab/planner-o4-before `df3a5abb0` = main `2c7c1d0dc` (a1199d198) + the current probe
- after: stream/planner `e4fb423a3` = main with O4 `471cdcd5e`, M2 `75a1d8c51` and brains' Locks station fix + the probe
- The Locks 5-squad and Locks 3-squad one-click rows: `../rows-95155fc8e-builder0.jsonl` (before) and the after run's
  click logs in this commit's history (`o4-655fe383d`, removed: its build folder mixed old logs); the numbers are in the
  message to the orchestrator and in planner.md's Status.
