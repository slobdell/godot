# R46.6 the sel row: replays unchanged (builder3 light, 2026-10-30)

His two recordings replayed full length, all crews (`make replay-match ... CREWS=all`), with the sel row (stream/native
274177400's recorder) and without (a734c2296's recorder); every other row compared after dropping `sel` rows and the
match row's `path` (a timestamp).

| Recording | seconds | rows arm / base | differing | sel rows (arm) | divergence (both arms) |
|---|---|---|---|---|---|
| Gorge 2026-10-29T09-35-51 | 107 | 490 / 490 | 0 | 13 | 20/20 within 3 m, PASS |
| Terminus 2026-10-29T22-57-47 | 151 | 2141 / 2141 | 0 | 18 | 17/20 within 3 m at 151 s, first over Green_Guns_3@151 (same in base: not this change) |

`run.sh` is the driver; `divergence.txt` the four DIVERGENCE lines.
