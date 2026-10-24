# G2 v2c dev read 3 (orders, round 39; DEV seeds 3801-3803, n 3, not judged)

- builder0 light J4, tree 584d23588 (game code 6ac4b67d2). Arms: `main:`; `g2v2c:` R38.47's arm + `--group-route-corner=line`;
  his routes also `lead:` (g2v2c + `--group-lead=drive`). The cells' lead arm did not run.

| | main | v2 (dev 1) | v2c |
|---|---|---|---|
| his routes off (sum) / never-in | 5,022 / 9 | 3,302 / 3 | 2,523 / 3 |
| his 5 east off / never | 2,965 / 3 | 876 / 0 | 207 / 0 |
| his 5 west off / never | 1,127 / 6 | 849 / 0 | 884 / 0 |
| his 5 avenue off | 142 | 682 | 536 |
| his 3 east never | 0 | 3 | 3 |
| route cells off / never | 2,404 / 1 | 1,462 / 0 | 1,432 / 0 |
| terminus 5 route worst twitch | 18.7 | 34.1 | 34.1 |

- lead on legs (his routes): off 2,012, never-in 6 (his 5 west 0 -> 3): worse on the guard that matters; not pursued.
- Open: his 3 east (squad 2 never in: a whole-squad swap on the last leg, deterministic, g2 v1's too); his 5 avenue (still
  3.8x main: the gates abreast across the corner, `--group-gate=main`); terminus 5 route twitch.
