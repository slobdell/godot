# G2 v2 dev read 1 (orders, round 39; DEV seeds, not judged)

- Machine: builder0 light lane, J4. Tree: da9591207 (G2 v2 = single file past the corner).
- Workload: `make native orders-probe`, n 3 (dev seeds 3801-3803). `his/`: terminus, his routes east `70/50+70/-30+25/-30`,
  west `-70/50+-70/-30+-25/-30`, avenue `0/30+0/-30+-50/-30` x 3 / 5 squads. `cells/`: locks / crossing / terminus x 3 / 5 x route.
- Arms: `main:`; `g2:` R38.47's arm (`--group-lay=column,--group-legs=on,--group-route-line=on,--group-leg-width=along,
  --group-gate=main`); `g2v2:` g2 + `--group-route-corner=line`.

| | main | g2 | g2v2 |
|---|---|---|---|
| his routes, metres off his drawn path (sum) | 5,022 | 5,107 | 3,302 |
| his routes, never-in squads (sum over seeds) | 9 | 6 | 3 |
| his 5 east: off / never | 2,965 / 3 | 1,982 / 3 | 876 / 0 |
| his 5 west: off / never | 1,127 / 6 | 2,063 / 0 | 849 / 0 |
| his 5 avenue: off | 142 | 167 | **682** |
| his 3 east: never | 0 | 3 | 3 (g2's too) |
| route cells: off (sum) / never | 2,404 / 1 | 1,915 / 0 | 1,462 / 0 |
| terminus 5 route: worst twitch | 18.7 | 19.6 | **34.1** |

- Avenue cost: single file up the x = 0 street stacks five herringbones back past squad 4's previous leg end, so squad 4
  stops at (1.8, 92.0), 122.7 m off his route. Next (v2b, the next commit): past the corner a rank stands centred on the
  route, as wide as that street allows, not single file.
- His 3 east: squad 2 never in in g2 and g2v2 (s3801-3803, the same deterministic run): its place (61.3, -23.4) and
  squad 3's (27.5, -29.6) are main's, swapped. That's the whole-squad swap on a leg (`untangle_whole`), shared with g2 v1.
