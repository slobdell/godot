# G2 v2b dev read 2 (orders, round 39; DEV seeds 3801-3803, n 3, not judged)

- builder0 light J4; his routes on 4ce8784d5, cells on b1b20fa3d (the same game code). Arms: `main:`; `g2v2b:` R38.47's arm +
  `--group-route-corner=line`; `lead:` g2v2b + `--group-lead=drive`.
- g2v2b = g2v2 byte for byte on every cell (his routes off 3,302, never-in 3; cells off 1,462, never-in 0): centring the
  rank past the corner changed nothing, and the avenue's 682 m stays.
- `lead` on route legs is worse on his routes (off 3,498, never-in 6: his 5 east 0 -> 3). G1 v5 stays on plain clicks.
- The avenue cause (laptop trace, 4ce8784d5): his route line starts at the army's own position (`_remember_route_click`
  keeps the body first), and the room was the rearmost leg start plus a step, so squad 4's last place stood back at the army's
  start, (1.8, 92.0). Fix (v2c, next commit): on a leg under the switch no rank stands behind the rearmost start. Laptop,
  the same cell: squad 4 at (0.8, 57.6), on the route, every squad in.
