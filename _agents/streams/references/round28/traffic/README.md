# Round 28 traffic: T1's series (builder0, GDScript path `--brains-off=native`, `make traffic-series`)

| file | commit | arm | seeds x start ticks | headline | caveat |
|---|---|---|---|---|---|
| t0-c6e32d03-gd-seeds123.jsonl | c6e32d03 (= main 94b5fc0d + docs) | T0 base, both + solo | {1,2,3} x {1,3,6,8,11,16} | fast 294/716/277/113 (TC/TH/YC/YH) | tuning seeds; no between-squad split (added later) |
| tuning-v2d-672eb785-seeds123.jsonl | 672eb785 | v2d = v3, both only | {1,2,3} | fast 198/374/160/113 | tuning seeds: v3 was tuned on these |
| judged-jbase-672eb785-seeds456.jsonl | 672eb785 | base (`--traffic-off=turns,streetright,streetturns`), both + solo | {4,5,6} | fast 183/871/309/122 | the judged base |
| judged-jv3-672eb785-seeds456.jsonl | 672eb785 | v3, both only | {4,5,6} | fast 199/419/205/118: FAILED (2 of 4 down >= 25 %) | the judged arm |
| judged-jrbase-672eb785-seeds456.jsonl | 672eb785 | base, `--side=rust` (CPU side), Terminus only | {4,5,6} | fast 183/868 | |
| judged-jrv3-672eb785-seeds456.jsonl | 672eb785 | v3, `--side=rust`, Terminus only | {4,5,6} | fast 171/431 | |

Each line is one run's TRAFFIC_PROBE report (tests/traffic/traffic_stage.gd); pool with `tests/traffic/traffic_table.py`
(the both-only arms need the base's solo lines appended for the ratio column).
| t1b-cbase-474558f8-seeds101112.jsonl | 474558f8 | T1b base (`--traffic-off=streetturns`), both + solo | {10,11,12} | fast 246/872/232/97 | T1b's judged base |
| t1b-ct1b-474558f8-seeds101112.jsonl | 474558f8 | T1b (street head-on rule alone), both | {10,11,12} | TH fast 872 -> 440 but crews 173 -> 170, all-in +26 %, fstuck 629 -> 839: FAILED | run (12,16) wedged at the street mouth: 4 crews never in, 305 crew-s stuck |
| t1b-crbase / t1b-crt1b-474558f8-seeds101112.jsonl | 474558f8 | the same, `--side=rust`, Terminus head-on | {10,11,12} | fast 763 -> 392, crews 170 -> 173 | reported only |

The {7,8,9} T1b run (fc31d0c4) is VOID and not kept: the rule never ran (0 verdicts; the _avoid gate).
