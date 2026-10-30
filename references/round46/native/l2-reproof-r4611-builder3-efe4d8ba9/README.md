# L2 twin re-proved on engage's frozen efe4d8ba9; R46.11's acceptance (builder3 light, 2026-10-30)

**Twin (C46.4):** efe4d8ba9 (native decides every case) v efe4d8ba9 + engage's routing guard put back (lane cases in GDScript).
`test FILTER=test_native_decide|fire_lanes_crowd|engage_lane_line` on efe4d8ba9: 13 passed / 0 failed; test_native_decide 7536
decisions / 0 mismatches, 78 CLEAR_LANE choices only the lane rule makes. His replays, full length, all crews, every non-`sel` row:

| Recording | rows frozen / guard | differing |
|---|---|---|
| Gorge 2026-10-29T09-35-51 (107 s) | 426 / 426 | 0 |
| Terminus 2026-10-29T22-57-47 (151 s) | 2071 / 2071 | 0 |

**R46.11:** pair/native-r4611 = efe4d8ba9 + stream/native 882c62d7c. replay-match reads the recordings' missing `rules` stamp
and adds `--lane-clear=off` (REPLAY_RULES line): Gorge 20/20 within 3 m to 107 s (PASS; 11/20 from 50 s without it); Terminus
17/20 at 151 s, first over Green_Guns_3 @151 (main's own reading; 1/20 from 22 s without it). `divergence.txt` has every line.
