# Spotter batch 1: his 30 'looks dumb', by cause

_Written 2026-10-31 by the spotter worker. His labels: 30 of 30 'looks dumb', no notes (his words: "all cases it exposed looked like dumb behavior"). Batch 1 = stream/spotter tree 1209a934f + spotter, builder3, 12 CPU-v-CPU showmatch fights (terminus crossing locks sumps gorge parade x seeds 13215 13216, 240 s, native), ranked by tools/spotter/rank.py; clips on the judging page https://claude.ai/artifact/DXKpD67u2r49HQrk93ozJD. Every clip reproduced its moment (crew 0.02-0.07 m from the table at the peak tick)._

**Reproduce any row:** its `make spotter-clip ...` line renders the clip again (offscreen, builder3; checked: the crew stands where the table said). To WATCH the fight live, `make showmatch SEED=<seed> ARENA=<map>` runs the same `--skirmish --demo-match --clean --seed --arena` match in a window (it adds only presentation flags: announcer, music; unverified as bit-identical in a window, so the clip line is the exact reproduction); the crew and seconds are in the row. Seconds and ticks are the match's own (30 ticks a second).

The classes are by CAUSE as the per-second table shows it (brain choice, mover phase, who blocks it, goal distance, damage), so each can become one stream item. A clip can show two causes; it is filed under the one that explains most of its seconds.

| Class | Clips | Owner (suggested) |
|---|---|---|
| A. Hurt crews retreat by abandoning the squad | 4 | engage (TankBrain RETREAT: where a hurt crew goes and how) |
| B. Squadmates jam each other: give-way loops | 9 | manoeuvre (Movement yield / give-way, holdway, the nopush ease) |
| C. Stuck on terrain / no path, and it never gives up | 5 | manoeuvre + route (Movement blocked 'terrain' / 'no_path', the no-progress watchdog that is OFF since R47.42) |
| D. Followers and slow movers drive away from where they are going | 7 | orders + route (FOLLOW's goal; the support-by-fire move's route and pace) |
| E. Shot from beyond its range, no answer | 5 | engage (engagement choice under outranging fire: close, take cover, or leave) |

## A. Hurt crews retreat by abandoning the squad (4)

**Owner:** engage (TankBrain RETREAT: where a hurt crew goes and how).

A crew at 2-10 % hp takes RETREAT and drives (often in REVERSE, 4-5 m/s for 8-19 s) 50-125 m away from its squad, with no enemy in sight, then sits alone. Its order is still the squad's attack_move. A player reads: it ran away and left its squad, and backing up for 19 s looks broken. Ask: retreat toward the squad / a covered spot near it, turn and drive rather than reverse past a few metres, stop once out of fire.

- **#1 Rust_Eyes2_1** (law_scout, rust), sumps seed 13215, 81-91 s (peak tick 2580): far from its squad (125.6 m, rarer than 99.99 %); driving away from its route (6 s, rarer than 99.97 %); no progress toward its goal (6 s, rarer than 99.89 %); taking fire from behind (3 s, rarer than 99.76 %)
  - choice [('RETREAT', 11)] | intent [('RETREAT - assault through, breaking away', 10), ('RETREAT - near ambush, breaking away', 1)]
  - order [('attack_move', 11)] move [('move_to', 11)] phase [('arrived', 6), ('driving', 5)]
  - blocked [('', 11)] touch [('', 11)] lane [('Rust_Eyes2_4', 11)]
  - clip `sumps-13215-Rust_Eyes2_1-81-91.mp4` (page asset /_blob/37e4d045a3f6086cc8a93d90f32f001e); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=sumps SPOT_CREW=Rust_Eyes2_1 SPOT_FROM=81 SPOT_TO=91`
- **#2 Rust_Guns_1** (law_tank, rust), gorge seed 13215, 56-66 s (peak tick 1830): no progress toward its goal (10 s, rarer than 99.98 %); reversing on a move order (19 s, rarer than 99.93 %); far from its squad (52.3 m, rarer than 99.69 %)
  - choice [('RETREAT', 8), ('MOVE', 3)] | intent [('RETREAT - assault through', 6), ('MOVE - spring ambush, ordered', 3)]
  - order [('attack_move', 8), ('move', 3)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13215-Rust_Guns_1-56-66.mp4` (page asset /_blob/ba343aa2859340940665599b5174e16c); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=gorge SPOT_CREW=Rust_Guns_1 SPOT_FROM=56 SPOT_TO=66`
- **#8 Green_Eyes_4** (law_scout, green), gorge seed 13216, 15-25 s (peak tick 600): driving away from its route (7 s, rarer than 99.99 %); turning on the spot (79.6 deg/s, rarer than 99.99 %); far from its squad (72.6 m, rarer than 99.56 %)
  - choice [('RETREAT', 11)] | intent [('RETREAT - assault through, breaking away', 10), ('RETREAT - near ambush, breaking line of sight', 1)]
  - order [('attack_move', 11)] move [('move_to', 11)] phase [('driving', 10), ('yielding', 1)]
  - blocked [('', 10), ('Green_Eyes II_4', 1)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13216-Green_Eyes_4-15-25.mp4` (page asset /_blob/aa2c0551fe6819cd86b6a9921f693ed3); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=gorge SPOT_CREW=Green_Eyes_4 SPOT_FROM=15 SPOT_TO=25`
- **#16 Rust_Guns_1** (law_tank, rust), parade seed 13215, 131-141 s (peak tick 4080): far from its squad (83.4 m, rarer than 99.98 %); reversing on a move order (11 s, rarer than 99.5 %)
  - choice [('RETREAT', 6), ('MOVE', 5)] | intent [('RETREAT', 5), ('MOVE - ordered', 5)]
  - order [('attack_move', 6), ('move', 5)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 11)] lane [('', 11)]
  - clip `parade-13215-Rust_Guns_1-131-141.mp4` (page asset /_blob/1591a83c336d46edcb702b5c66127505); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=parade SPOT_CREW=Rust_Guns_1 SPOT_FROM=131 SPOT_TO=141`

## B. Squadmates jam each other: give-way loops (9)

**Owner:** manoeuvre (Movement yield / give-way, holdway, the nopush ease).

Phase `yielding` or `blocked` by a NAMED squadmate for 5-18 s: the crew reverses or swings off its route to make room, often for a crew of its own squad that is itself waiting, sometimes while taking fire (#7 dies at 4 hp while blocked by Hunters_1 / Guns_2; #6 yields 9 s under fire). HOLD orders yield too (#6, #7, #29, #30): a crew told to hold drives off its post to give way. A player reads: they get in each other's way and can't sort it out.

- **#6 Green_Spears_1** (gang_scout, green), crossing seed 13215, 16-26 s (peak tick 690): blocked by a friendly (13 s, rarer than 99.99 %); sitting still under fire, not shooting back (3 s, rarer than 99.85 %); hit from beyond its own range (3 s, rarer than 99.13 %)
  - choice [('HOLD', 11)] | intent [('HOLD', 10), ('HOLD - covering its sector', 1)]
  - order [('hold', 11)] move [('face', 11)] phase [('yielding', 9), ('arrived', 2)]
  - blocked [('Green_Spears II_1', 9), ('', 2)] touch [('', 11)] lane [('', 11)]
  - clip `crossing-13215-Green_Spears_1-16-26.mp4` (page asset /_blob/e965d575bca96e4d9e7efaf96406f98e); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=crossing SPOT_CREW=Green_Spears_1 SPOT_FROM=16 SPOT_TO=26`
- **#7 Green_Guns_4** (gang_tank, green), gorge seed 13215, 14-24 s (peak tick 660): blocked by a friendly (10 s, rarer than 99.97 %); no progress toward its goal (10 s, rarer than 99.89 %)
  - choice [('HOLD', 11)] | intent [('HOLD - holding', 11)]
  - order [('hold', 11)] move [('move_to', 11)] phase [('blocked', 9), ('driving', 2)]
  - blocked [('Green_Hunters_1', 4), ('Green_Guns_2', 3), ('', 2)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13215-Green_Guns_4-14-24.mp4` (page asset /_blob/b150ee9d93b5f2df9067122ada743093); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_4 SPOT_FROM=14 SPOT_TO=24`
- **#11 Green_Wrenches_2** (gang_support, green), crossing seed 13215, 84-94 s (peak tick 2700): blocked by a friendly (18 s, rarer than 99.95 %); reversing on a move order (9 s, rarer than 99.95 %); no progress toward its goal (9 s, rarer than 99.86 %)
  - choice [('MOVE', 11)] | intent [('MOVE - ordered', 11)]
  - order [('move', 11)] move [('move_to', 11)] phase [('yielding', 8), ('driving', 3)]
  - blocked [('Green_Wrenches_3', 5), ('Green_Spears II_7', 3), ('', 3)] touch [('', 11)] lane [('', 11)]
  - clip `crossing-13215-Green_Wrenches_2-84-94.mp4` (page asset /_blob/afd8dd702389a9f18237a4aeeecda30b); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=crossing SPOT_CREW=Green_Wrenches_2 SPOT_FROM=84 SPOT_TO=94`
- **#9 Green_Spears_4** (gang_scout, green), gorge seed 13215, 8-15 s (peak tick 390): pressed against a wall or prop (2 s, rarer than 99.99 %); hit from beyond its own range (4 s, rarer than 99.94 %); blocked by a friendly (3 s, rarer than 96.69 %)
  - choice [('SPOT', 6), ('ENGAGE', 1), ('MOVE', 1)] | intent [('SPOT', 6), ('ENGAGE Rust_Guns_1 - water between: firing across', 1)]
  - order [('', 7), ('move', 1)] move [('face', 4), ('move_to', 4)] phase [('yielding', 4), ('arrived', 2), ('driving', 2)]
  - blocked [('', 4), ('Green_Wrenches_2', 3), ('Green_Spears_3', 1)] touch [('', 6), ('TerrainRims', 2)] lane [('', 8)]
  - clip `gorge-13215-Green_Spears_4-8-15.mp4` (page asset /_blob/ee0afcdfa306b9f4b31e9b0157c76d1f); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=gorge SPOT_CREW=Green_Spears_4 SPOT_FROM=8 SPOT_TO=15`
- **#27 Rust_Battery_1** (syn_artillery, rust), sumps seed 13216, 140-150 s (peak tick 4380): no progress toward its goal (13 s, rarer than 99.96 %); turning on the spot (80 deg/s, rarer than 99.84 %); driving away from its route (2 s, rarer than 99.71 %); blocked by a friendly (5 s, rarer than 99.14 %)
  - choice [('MOVE', 11)] | intent [('MOVE - ordered', 11)]
  - order [('move', 11)] move [('move_to', 11)] phase [('yielding', 6), ('driving', 5)]
  - blocked [('', 5), ('Rust_Hunters_1', 3), ('Rust_Hunters_2', 3)] touch [('', 11)] lane [('', 11)]
  - clip `sumps-13216-Rust_Battery_1-140-150.mp4` (page asset /_blob/324200371f34bcde0976586581275373); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=sumps SPOT_CREW=Rust_Battery_1 SPOT_FROM=140 SPOT_TO=150`
- **#29 Green_Spears II_2** (gang_scout, green), gorge seed 13215, 9-19 s (peak tick 450): driving away from its route (6 s, rarer than 99.97 %); blocked by a friendly (9 s, rarer than 99.84 %)
  - choice [('HOLD', 7), ('MOVE', 4)] | intent [('HOLD - holding', 4), ('MOVE - ordered', 4)]
  - order [('hold', 7), ('move', 4)] move [('move_to', 8), ('face', 3)] phase [('yielding', 8), ('driving', 3)]
  - blocked [('Green_Wrenches_3', 5), ('', 3), ('Green_Spears_1', 2)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13215-Green_Spears_II_2-9-19.mp4` (page asset /_blob/43bee0b3457d3b02d072cfe1ea30c102); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=gorge SPOT_CREW=Green_Spears II_2 SPOT_FROM=9 SPOT_TO=19`
- **#30 Green_Spears II_6** (gang_scout, green), locks seed 13215, 18-28 s (peak tick 780): driving away from its route (5 s, rarer than 99.91 %); blocked by a friendly (8 s, rarer than 99.75 %)
  - choice [('HOLD', 11)] | intent [('HOLD - holding', 10), ('HOLD', 1)]
  - order [('hold', 11)] move [('move_to', 10), ('face', 1)] phase [('yielding', 8), ('driving', 2), ('arrived', 1)]
  - blocked [('Green_Spears II_3', 6), ('', 3), ('Green_Guns_5', 2)] touch [('', 11)] lane [('', 11)]
  - clip `locks-13215-Green_Spears_II_6-18-28.mp4` (page asset /_blob/cbdd045615ea81f8d0bbc2a29e155a60); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=locks SPOT_CREW=Green_Spears II_6 SPOT_FROM=18 SPOT_TO=28`
- **#21 Green_Hunters_4** (gang_ifv, green), crossing seed 13215, 108-118 s (peak tick 3420): reversing on a move order (9 s, rarer than 99.98 %); blocked by a friendly (9 s, rarer than 99.64 %); no progress toward its goal (6 s, rarer than 99.59 %)
  - choice [('MOVE', 9)] | intent [('MOVE - ordered', 9)]
  - order [('move', 9)] move [('move_to', 9)] phase [('blocked', 9)]
  - blocked [('terrain', 6), ('Green_Spears II_3', 3)] touch [('', 9)] lane [('Green_Hunters_9', 9)]
  - clip `crossing-13215-Green_Hunters_4-108-118.mp4` (page asset /_blob/0442a0ec9e59a573a91f996f07e66d90); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters_4 SPOT_FROM=108 SPOT_TO=118`
- **#15 Rust_Hunters_4** (syn_ifv, rust), crossing seed 13216, 58-68 s (peak tick 1980): reversing on a move order (8 s, rarer than 99.97 %); blocked by a friendly (5 s, rarer than 99.85 %); hit from beyond its own range (3 s, rarer than 95.73 %)
  - choice [('MOVE', 8), ('ENGAGE', 2), ('HOLD', 1)] | intent [('MOVE - ordered', 8), ('ENGAGE Green_Sirens_3 - squad focus, water between: firing across', 2)]
  - order [('move', 8), ('', 2), ('hold', 1)] move [('move_to', 8), ('face', 3)] phase [('blocked', 5), ('arrived', 3), ('driving', 3)]
  - blocked [('', 6), ('terrain', 4), ('Rust_Hunters_3', 1)] touch [('', 11)] lane [('', 11)]
  - clip `crossing-13216-Rust_Hunters_4-58-68.mp4` (page asset /_blob/5559aa1692b86dadd500f64928e10335); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=crossing SPOT_CREW=Rust_Hunters_4 SPOT_FROM=58 SPOT_TO=68`

## C. Stuck on terrain / no path, and it never gives up (5)

**Owner:** manoeuvre + route (Movement blocked 'terrain' / 'no_path', the no-progress watchdog that is OFF since R47.42).

Phase `blocked`, blocked_by `terrain` or `no_path`, 0 m/s or reversing into a prop for 8-37 s; #18 sat the WHOLE match (224 s, to_go 0) on a spring-ambush MOVE whose spot has no path; #26 reversed 37 s into Barricade_45; artillery (#3, #14) stuck 20-97 m short of its firing spot while under fire. A player reads: stuck and not even trying.

- **#3 Rust_Battery_1** (law_artillery, rust), sumps seed 13215, 182-192 s (peak tick 5670): no progress toward its goal (24 s, rarer than 99.99 %); blocked by a friendly (28 s, rarer than 99.57 %)
  - choice [('MOVE', 10), ('HOLD', 1)] | intent [('MOVE - assaulting, support by fire, ordered', 10), ('HOLD - base of fire, support by fire, holding', 1)]
  - order [('move', 10), ('hold', 1)] move [('move_to', 11)] phase [('blocked', 9), ('driving', 2)]
  - blocked [('terrain', 9), ('', 2)] touch [('', 11)] lane [('', 11)]
  - clip `sumps-13215-Rust_Battery_1-182-192.mp4` (page asset /_blob/67238cc3cda239925cad41b1e7d718a3); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=sumps SPOT_CREW=Rust_Battery_1 SPOT_FROM=182 SPOT_TO=192`
- **#14 Green_Battery_1** (law_artillery, green), terminus seed 13216, 199-209 s (peak tick 6210): taking fire from behind (11 s, rarer than 99.99 %); no progress toward its goal (8 s, rarer than 99.43 %); driving away from its route (2 s, rarer than 99.36 %); blocked by a friendly (5 s, rarer than 96.65 %)
  - choice [('MOVE', 9)] | intent [('MOVE - assaulting, support by fire, ordered', 9)]
  - order [('move', 9)] move [('move_to', 9)] phase [('blocked', 5), ('driving', 4)]
  - blocked [('', 4), ('terrain', 4), ('no_path', 1)] touch [('', 9)] lane [('', 9)]
  - clip `terminus-13216-Green_Battery_1-199-209.mp4` (page asset /_blob/3853bc8eaba3bdf90927b63b284cc058); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=terminus SPOT_CREW=Green_Battery_1 SPOT_FROM=199 SPOT_TO=209`
- **#18 Rust_Guns_1** (law_tank, rust), crossing seed 13215, 232-242 s (peak tick 7200): blocked by a friendly (224 s, rarer than 99.98 %)
  - choice [('MOVE', 9)] | intent [('MOVE - spring ambush, ordered', 9)]
  - order [('move', 9)] move [('move_to', 9)] phase [('blocked', 9)]
  - blocked [('no_path', 9)] touch [('', 9)] lane [('', 9)]
  - clip `crossing-13215-Rust_Guns_1-232-242.mp4` (page asset /_blob/79d0283f767b0a967264a66cc3e6ed56); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=crossing SPOT_CREW=Rust_Guns_1 SPOT_FROM=232 SPOT_TO=242`
- **#26 Green_Guns_1** (gang_tank, green), sumps seed 13215, 100-110 s (peak tick 3210): reversing on a move order (37 s, rarer than 99.97 %); no progress toward its goal (4 s, rarer than 98.7 %); blocked by a friendly (3 s, rarer than 95.9 %)
  - choice [('HOLD', 8), ('ENGAGE', 3)] | intent [('HOLD - holding', 8), ('ENGAGE Rust_Eyes2_4 - assault through, in its slot, boxed in by fire, weaving, front armor on it', 2)]
  - order [('hold', 8), ('attack_move', 2), ('attack', 1)] move [('move_to', 11)] phase [('driving', 6), ('blocked', 5)]
  - blocked [('', 6), ('terrain', 5)] touch [('Barricade_45', 9), ('', 2)] lane [('', 6), ('Green_Hunters_4', 4), ('Green_Guns_2', 1)]
  - clip `sumps-13215-Green_Guns_1-100-110.mp4` (page asset /_blob/1d9d0d05d41c8c93c0de354a8fd5a1ea); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=sumps SPOT_CREW=Green_Guns_1 SPOT_FROM=100 SPOT_TO=110`
- **#24 Green_Hunters_7** (gang_ifv, green), locks seed 13215, 15-25 s (peak tick 660): turning on the spot (56.3 deg/s, rarer than 99.98 %); far from its squad (75 m, rarer than 99.8 %); driving away from its route (5 s, rarer than 99.7 %); no progress toward its goal (5 s, rarer than 99.25 %)
  - choice [('MOVE', 11)] | intent [('MOVE - ambush, ordered', 5), ('MOVE - ordered', 4)]
  - order [('move', 11)] move [('move_to', 11)] phase [('driving', 5), ('blocked', 3), ('yielding', 3)]
  - blocked [('', 5), ('terrain', 3), ('Green_Hunters_2', 3)] touch [('', 10), ('Container20_22', 1)] lane [('', 11)]
  - clip `locks-13215-Green_Hunters_7-15-25.mp4` (page asset /_blob/a7cdc80408cd4c47f178a48cc048ff33); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=locks SPOT_CREW=Green_Hunters_7 SPOT_FROM=15 SPOT_TO=25`

## D. Followers and slow movers drive away from where they are going (7)

**Owner:** orders + route (FOLLOW's goal; the support-by-fire move's route and pace).

The goal gets FARTHER while the crew drives at speed: FOLLOW crews (#17, #23, #25) whose to_go grows 17 -> 76 m / 64 -> 100 m as they follow a leader the other way; law_suppressors on 'assaulting, support by fire' (#13, #22, #28) crawl at 1.7-4 m/s, circle (#28: to_go fixed at 118 m for 10 s while moving), or drive on 4 m/s while being shot to 58 hp from beyond their 32 m range; #4 shuttles forward / back under fire 72 m from its squad. A player reads: where is it going?

- **#17 Rust_Guns_2** (syn_tank, rust), locks seed 13216, 36-46 s (peak tick 1230): driving away from its route (9 s, rarer than 99.95 %); no progress toward its goal (14 s, rarer than 99.95 %); turning on the spot (87.1 deg/s, rarer than 99.56 %)
  - choice [('FOLLOW', 11)] | intent [('FOLLOW Rust_Guns_1 - following Rust_Guns_1', 11)]
  - order [('follow', 11)] move [('move_to', 11)] phase [('driving', 9), ('yielding', 2)]
  - blocked [('', 9), ('Rust_Guns_1', 2)] touch [('', 11)] lane [('', 11)]
  - clip `locks-13216-Rust_Guns_2-36-46.mp4` (page asset /_blob/081aceb40963ecde9124e4ecc87afbdd); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=locks SPOT_CREW=Rust_Guns_2 SPOT_FROM=36 SPOT_TO=46`
- **#23 Green_Guns_5** (gang_tank, green), terminus seed 13215, 62-72 s (peak tick 2040): no progress toward its goal (12 s, rarer than 99.97 %); driving away from its route (5 s, rarer than 99.73 %)
  - choice [('FOLLOW', 10), ('MOVE', 1)] | intent [('FOLLOW Green_Guns_1 - following Green_Guns_1', 10), ('MOVE - ordered', 1)]
  - order [('follow', 10), ('move', 1)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 10), ('Block_6', 1)] lane [('', 11)]
  - clip `terminus-13215-Green_Guns_5-62-72.mp4` (page asset /_blob/fe430a1bd334f83311cc03f38a6a7088); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=terminus SPOT_CREW=Green_Guns_5 SPOT_FROM=62 SPOT_TO=72`
- **#25 Green_Wrenches_4** (gang_support, green), parade seed 13215, 13-23 s (peak tick 600): far from its squad (57.4 m, rarer than 99.95 %); driving away from its route (5 s, rarer than 99.77 %); hit from beyond its own range (3 s, rarer than 91.19 %)
  - choice [('FOLLOW', 8), ('MOVE', 3)] | intent [('FOLLOW Green_Wrenches_1 - following Green_Wrenches_1', 8), ('MOVE - assaulting, support by fire, ordered', 3)]
  - order [('follow', 8), ('move', 3)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 11)] lane [('', 11)]
  - clip `parade-13215-Green_Wrenches_4-13-23.mp4` (page asset /_blob/b27a635f29e816f33f4abbcd9823b200); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=parade SPOT_CREW=Green_Wrenches_4 SPOT_FROM=13 SPOT_TO=23`
- **#13 Green_Sirens_2** (law_suppressor, green), crossing seed 13216, 52-62 s (peak tick 1710): far from its squad (105.6 m, rarer than 99.96 %); turning on the spot (43 deg/s, rarer than 99.96 %); hit from beyond its own range (4 s, rarer than 98.93 %)
  - choice [('MOVE', 11)] | intent [('MOVE - assaulting, support by fire, ordered', 11)]
  - order [('move', 11)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 10), ('TerrainRims', 1)] lane [('', 11)]
  - clip `crossing-13216-Green_Sirens_2-52-62.mp4` (page asset /_blob/3de62fc7635e2d1741ee5fef60bef913); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=crossing SPOT_CREW=Green_Sirens_2 SPOT_FROM=52 SPOT_TO=62`
- **#22 Green_Sirens_1** (law_suppressor, green), crossing seed 13216, 69-79 s (peak tick 2310): hit from beyond its own range (11 s, rarer than 99.96 %); turning on the spot (24.1 deg/s, rarer than 99.34 %); far from its squad (45 m, rarer than 97.13 %)
  - choice [('MOVE', 9)] | intent [('MOVE - assaulting, support by fire, ordered', 9)]
  - order [('move', 9)] move [('move_to', 9)] phase [('driving', 9)]
  - blocked [('', 9)] touch [('', 9)] lane [('', 9)]
  - clip `crossing-13216-Green_Sirens_1-69-79.mp4` (page asset /_blob/5f8b11b0c329d64b01932a6ad0b84ede); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=crossing SPOT_CREW=Green_Sirens_1 SPOT_FROM=69 SPOT_TO=79`
- **#28 Green_Sirens_2** (law_suppressor, green), gorge seed 13216, 22-32 s (peak tick 900): driving away from its route (10 s, rarer than 99.96 %); no progress toward its goal (8 s, rarer than 99.96 %); far from its squad (50.8 m, rarer than 98.34 %)
  - choice [('MOVE', 11)] | intent [('MOVE - assaulting, support by fire, ordered', 11)]
  - order [('move', 11)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13216-Green_Sirens_2-22-32.mp4` (page asset /_blob/3546056839bb98c3667d04259c59e4df); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=gorge SPOT_CREW=Green_Sirens_2 SPOT_FROM=22 SPOT_TO=32`
- **#4 Green_Guns_2** (gang_tank, green), sumps seed 13215, 28-38 s (peak tick 1020): taking fire from behind (11 s, rarer than 99.97 %); far from its squad (72.6 m, rarer than 99.78 %); driving away from its route (5 s, rarer than 99.73 %); blocked by a friendly (3 s, rarer than 95.9 %)
  - choice [('MOVE', 8), ('ENGAGE', 3)] | intent [('MOVE - ordered', 8), ('ENGAGE Rust_Guns_2 - squad focus, no line of fire: going round', 1)]
  - order [('move', 8), ('attack_move', 2), ('attack', 1)] move [('move_to', 9), ('stop', 2)] phase [('driving', 9), ('arrived', 2)]
  - blocked [('', 11)] touch [('', 10), ('Wreck_27', 1)] lane [('', 10), ('Green_Spears_2', 1)]
  - clip `sumps-13215-Green_Guns_2-28-38.mp4` (page asset /_blob/376c3dc8db1626f7afd3f2f422a3a613); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=sumps SPOT_CREW=Green_Guns_2 SPOT_FROM=28 SPOT_TO=38`

## E. Shot from beyond its range, no answer (5)

**Owner:** engage (engagement choice under outranging fire: close, take cover, or leave).

hit_dmg from a shooter farther than the crew's own weapon range for 3-11 s; the crew holds, reverses, or keeps 'going round' with no line of fire. #20 a law tank on ENGAGE 'no line of fire: going round' loses 274 hp (330 -> 56) in 10 s; #5 a scout takes 775 damage (180 -> 5) reversing; #19 a scout on HOLD sits 5 s under fire and never shoots. This is his Crossing outranging complaint (gangs v syndicate) in CPU-v-CPU fights. NOTE: batch 1's probe never saw 'enemy in sight and in range, not firing' (a probe bug, fixed after batch 1), so the hold-fire class is UNDER-counted here.

- **#5 Green_Eyes_2** (law_scout, green), locks seed 13216, 23-33 s (peak tick 870): hit from beyond its own range (10 s, rarer than 99.99 %); reversing on a move order (5 s, rarer than 99.91 %); sitting still under fire, not shooting back (2 s, rarer than 99.79 %)
  - choice [('MOVE', 3), ('SPOT', 3), ('RETREAT', 2)] | intent [('MOVE - ordered', 3), ('SPOT', 3)]
  - order [('', 5), ('move', 3), ('hold', 1)] move [('move_to', 8), ('face', 1)] phase [('driving', 8), ('arrived', 1)]
  - blocked [('', 9)] touch [('', 9)] lane [('', 9)]
  - clip `locks-13216-Green_Eyes_2-23-33.mp4` (page asset /_blob/8626487a5040de3fe10fd73d36d79755); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=locks SPOT_CREW=Green_Eyes_2 SPOT_FROM=23 SPOT_TO=33`
- **#10 Green_Hunters_8** (gang_ifv, green), crossing seed 13215, 74-84 s (peak tick 2460): hit from beyond its own range (8 s, rarer than 99.95 %); taking fire from behind (6 s, rarer than 99.93 %); reversing on a move order (3 s, rarer than 96.84 %)
  - choice [('MOVE', 8), ('HOLD', 3)] | intent [('MOVE - ordered', 8), ('HOLD', 3)]
  - order [('move', 8), ('hold', 2), ('', 1)] move [('move_to', 8), ('face', 3)] phase [('driving', 8), ('arrived', 2), ('yielding', 1)]
  - blocked [('', 10), ('Green_Wrenches_4', 1)] touch [('', 10), ('TerrainRims', 1)] lane [('', 11)]
  - clip `crossing-13215-Green_Hunters_8-74-84.mp4` (page asset /_blob/f8992450ac4de3cf780dbac8e759e6f2); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters_8 SPOT_FROM=74 SPOT_TO=84`
- **#19 Rust_Eyes_1** (syn_scout, rust), crossing seed 13216, 125-133 s (peak tick 3930): sitting still under fire, not shooting back (5 s, rarer than 99.96 %); hit from beyond its own range (5 s, rarer than 99.88 %); turning on the spot (24.3 deg/s, rarer than 92.6 %)
  - choice [('HOLD', 9)] | intent [('HOLD', 7), ('HOLD - covering its sector', 2)]
  - order [('hold', 9)] move [('face', 9)] phase [('arrived', 9)]
  - blocked [('', 9)] touch [('', 9)] lane [('', 9)]
  - clip `crossing-13216-Rust_Eyes_1-125-133.mp4` (page asset /_blob/708dd875e74cebaffab13ca8e1d9cfb3); `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=crossing SPOT_CREW=Rust_Eyes_1 SPOT_FROM=125 SPOT_TO=133`
- **#12 Rust_Eyes2_1** (law_scout, rust), gorge seed 13215, 71-81 s (peak tick 2340): taking fire from behind (7 s, rarer than 99.99 %); driving away from its route (3 s, rarer than 99.63 %); far from its squad (63.4 m, rarer than 99.31 %)
  - choice [('ENGAGE', 6), ('FLANK', 4), ('SUPPRESS', 1)] | intent [('FLANK Green_Spears II_2 - assault through, swinging wide', 3), ('SUPPRESS Green_Guns_2 - assault through, squad focus, suppressing Green_Guns_2', 1)]
  - order [('attack_move', 8), ('attack', 3)] move [('move_to', 11)] phase [('driving', 11)]
  - blocked [('', 11)] touch [('', 11)] lane [('', 11)]
  - clip `gorge-13215-Rust_Eyes2_1-71-81.mp4` (page asset /_blob/8be342f9b2a390ce5257fe368b4bd5d1); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=gorge SPOT_CREW=Rust_Eyes2_1 SPOT_FROM=71 SPOT_TO=81`
- **#20 Rust_Guns_2** (law_tank, rust), terminus seed 13215, 61-71 s (peak tick 2010): taking fire from behind (9 s, rarer than 99.98 %); driving away from its route (3 s, rarer than 99.83 %); far from its squad (47.7 m, rarer than 99.33 %)
  - choice [('ENGAGE', 10), ('TAKE_COVER', 1)] | intent [('ENGAGE Green_Spears_3 - assault through, guarding artillery, no line of fire: going round', 2), ('ENGAGE Green_Spears_2 - assault through, squad focus, no line of fire: going round', 2)]
  - order [('attack_move', 8), ('attack', 3)] move [('move_to', 10), ('stop', 1)] phase [('driving', 10), ('arrived', 1)]
  - blocked [('', 11)] touch [('', 10), ('Barricade_25', 1)] lane [('', 11)]
  - clip `terminus-13215-Rust_Guns_2-61-71.mp4` (page asset /_blob/03311c232be6eca60b8abd4c61754834); `make spotter-clip SPOT_SEED=13215 SPOT_ARENA=terminus SPOT_CREW=Rust_Guns_2 SPOT_FROM=61 SPOT_TO=71`
