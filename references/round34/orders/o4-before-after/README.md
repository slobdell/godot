# O4 before/after through the O5 probe (planner, 2026-10-19; builder0, native, main arm, 3-waypoint shifted routes, n 1 a cell, deterministic)

- before: lab/planner-o4-before `df3a5abb0` = main `2c7c1d0dc` (a1199d198) + the current probe
- after: stream/planner `e4fb423a3` = main with O4 `471cdcd5e`, M2 `75a1d8c51` and brains' Locks station fix + the probe
- The one-click Locks rows: before `../rows-95155fc8e-builder0.jsonl`; after (655fe383d, builder0, the same game code
  as e4fb423a3): Locks 5 click far-bank 1 -> 0, all in 21.5 -> 13.8 s, worst shuffle 78.5 -> 33.2 m (brains' station
  fix); Locks 3 click far-bank 0 -> 1 (squad 1 over the middle bridge at 38 s: a second leak; brains has c3cdbd6c4).
