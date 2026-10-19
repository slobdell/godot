# parkedroom v2 + native hand-back: the pre-series trace (one end-to-end episode, ON)

Tree: `pair/parkedroom-on-v2n` `e7b202760` (game code = native's `5e5465af8` on traffic's `5259fb463`; parkedroom ON by
default). builder0, `make native traffic-far-one FAR_ONE_ARENA=terminus FAR_ONE_SEED=703
FAR_TRACE=Rust_Hunters2_2,Rust_Hunters2_1 FAR_FROM=15 FAR_TO=60`, --fixed-fps 30, n 1. NOT a judged number. The episode was
picked from a dev census on OLD fights 700-705 terminus (same tree, builder0); its FAR_ROOM row (f 620, back 2.3 m, order
unchanged) reproduces exactly in the trace.

Dev census (old fights, builder0, n 6, never judged): room give-ways per fight 9 / 9 / 12 / 38 / 2 / 4, ways back begun
4 / 5 / 5 / 26 / 1 / 1, native ask_handed_back 9 / 28 / 39 / 37 / 3 / 31. Before the hand-back (fresh native,
`5259fb463`): 1.5 room give-ways per fight.

Rust_Hunters2_2 (an IFV on a hold post at (-65.6, -27.8)):

| s | phase | spot | giving way to | from the post |
|---|---|---|---|---|
| 17.5 | arrived on its hold | | | 0.0 m |
| 21.0 | yielding (still >= 2 s: the room rule) | room(6,22) | Rust_Hunters2_1 | 0.8 m |
| 23.5 | yielding, the WAY BACK (v2's own) | room-back | Rust_Hunters2_1 | 2.3 m |
| 24.0 | arrived | room-back | | 1.3 m |
| 27.0 | yielding again | room(9,0) | Rust_Wrenches_1 | 0.9 m -> 8.6 m |
| 30.5 | driving back | | | 8.6 m |
| 32.5-60 | arrived, holding, order unchanged | | | 2.3 m |

Read: the gate (still >= 2 s), the hand-back (native gave the ask to Movement.ask), the way back after the asker passed,
and a second room with its own way back all ran on the native drive path. It ends inside 3 m of the post. Pre-series
gate: PASS.

## v3 (R33.36): the same episode, the pre-series trace

Tree `pair/parkedroom-on-v3` `6d0e00652` (v3 on native's hand-back line). builder0, the same command, n 1, NOT judged.
Hold goal (-61.8, -30.3); the crew was parked 4.5 m off it.

| s | phase | spot | from the parked spot | from the HOLD GOAL |
|---|---|---|---|---|
| 17.5-20 | arrived on its hold | | 0.0 m | 4.5 m |
| 21.0 | yielding (the room rule) to Rust_Hunters2_1 | room(6,22) | 0.8 m | 3.8 m |
| 23.5 | the way back ENDED (within HOLD_TOLERANCE - 0.5 m of the goal) | room-back | 2.3 m | 2.4 m |
| 23.5-47 | arrived, holding, order unchanged | | 2.3 m | 2.4 m |
| 47.0 | the brain sends it on (a move) | | | |

The first v3 build (`ee3f750ec`, no early end) took the same way back to 36.5 s, dithering 2-3 m off the goal while
still giving way. That's why `_room_home_inside` was added (`0f25b15b0`). Pre-series gate: PASS.
