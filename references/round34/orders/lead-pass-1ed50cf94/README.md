# The lead's probe pass: several squads to one point, and routes (round 34, after O1–O4 and brains' fixes)

Tree `1ed50cf94` = main `62d90dc97` (green, builder0 2866/0) + the O5 probe. **Table:** builder0, native, headless,
`--fixed-fps 30`, seed 34, n 1 a cell (deterministic). **Shots:** the laptop (flightdeck, GDScript path, windowed), the
same 24 cells. Top-down, at the moment every squad has arrived (`arrival`, or `window_end` at 90 s) and 5 s later
(`arrival_plus5`), desktop 1280x720 and phone 1560x720. The HUD is hidden. Posts: white = where he clicked (the last
waypoint of a route); red, yellow, green, blue, violet = squads 1–5's own spots. Arms: `main` (the game as it is) and
`deploy_on` (`--deploy-step=on`, brains' B8b prototype, off on main).

## What he'll see (in his terms)

- **No squad crosses the river any more.** No crew reaches the far bank in any of the 24 cells (Locks, Crossing,
  Terminus; one click or a route; 3 or 5 squads). His scouts-over-the-bridge case is closed on both river maps.
- **Five squads to one point: all five go now.** The back two used to stay home (72 m behind the click, at their own
  start). Now every squad drives toward the click. The back rank stands 52–64 m behind it, still the widest spread, and
  all five are in at 14 s on the Locks and Terminus and 28.5 s on the Crossing.
- **Three squads to one point:** the middle squad stands on the click, the two outer ones 28–37 m either side. All in
  at 18–24 s.
- **Routes (shift-clicked waypoints):** squads now pass the middle waypoints without stopping and finish at the last
  one. Two cells still leave one squad short at 90 s: the Locks 3-squad route (squad 1 stops 29 m short of its spot)
  and the Locks 5-squad route (squad 5 22.7 m short; squad 3 drives 257 m and only gets in at 88.7 s).
- **After arriving, crews still shuffle:** the worst crew moves 19–38 m after its squad arrives with 3 squads, and up
  to 87 m with 5 on the Crossing (brains' B6).
- **The deploy step (`deploy_on`)** is mixed. The Crossing 3-squad click is in 6 s sooner with less shuffle (18.6 v
  24.4 s, 27.8 v 37.8 m). It finishes the two Locks routes that main leaves short (21.7 s and 49.3 s). The Crossing
  5-squad route is slower (41.7 v 31.0 s), and the Terminus clicks shuffle more or arrive later.

## The table

`table-builder0.txt` (rows: `rows/rows-builder0.jsonl`; the laptop's windowed runs: `rows/laptop-windowed-runs.txt`,
GDScript, so their numbers differ in detail). Columns: the anchor's offset from the click (worst / median), squads
that reached a deck / the far bank, all in (s; `-` = not within 90 s), the closest any squad stood to another squad's
hull at arrival, the worst shuffle after arrival, the worst drive over planned drive, and the least a squad is sent
toward the click (negative = away; none is negative now).
