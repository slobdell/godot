# Spotter batch 2 by class

batch 2 (main 2fc962aa6, builder3, 24 fights 6 maps x 13121-13124); his taps 34/34 dumb + 31 assumed (C48.4). Each clip run through `tools/spotter/classes.py` (classes v4 (2026-10-31; v3 + F, A-E unchanged)) on its own fight; its class is the class with the most flagged crew-seconds of that crew inside the clip's window. `none` = the rule flags no second of the clip (a candidate new class, or a moment only the ranker's rarity sees).

## What batch 2 adds (the spotter worker, 2026-10-31)

- **New class F: holds fire with an enemy in sight and in range** (engage). Batch 1's probe could not see it (enemy-in-sight
  was always -1, fixed for batch 2). In batch 2, 21 of the 70 flagged clips carry the hold-fire signal (5-66 s); the rule's F
  takes 7 clips as their main class. At main df9aacc1a: **1.64 moments / fight**. Its largest cause is a **support-by-fire / base-of-fire
  crew that doesn't shoot** (0.79 / fight), ahead of plain HOLD (0.43), moving (0.27) and spring ambush (0.16, which holds fire
  on purpose; read it apart). Added to the rule as v4 and placed LAST in the order, so A-E read exactly as v3 (checked: identical rates).
- **B in his judged clips is mostly "moving squadmates"** (9 of 11). At main, by contrast, B's moments are mostly "held crew gives way"
  (11.63 of 17.00 a fight), and those are short: 3 s qualifies a HOLD crew. **For manoeuvre:** his "dumb" B is two movers jammed for
  8+ s. A fix aimed only at held crews may move the rate a lot but change little of what he saw.
- **E in his clips is all "no answer"** (18 of 18). Batch 2 is at 2fc962aa6, before E10 shipped.
- **Still unclassed: 23 flagged clips.** Their signals: far from its squad (10), driving away from its route (10), hold fire under
  8 s (9), **taking fire from behind (7)**, blocked by a friendly under 8 s (6). Two candidates, not added to the rule (v4 stays
  frozen this round, R48.4): **G, wanders off alone** (wrong way + far from squad, short of D's thresholds) and **H, shot from
  behind and doesn't turn** (rear fire, 7). Both need his eye on a few clips before they become classes.
- The 10 controls carry no class under the rule (0 of 10). His taps on them are still the only measure of the base rate.

| class | flagged clips | controls |
|---|---|---|
| A hurt crews retreat by abandoning the squad | 1 | 0 |
| E shot from beyond its range, no answer | 18 | 0 |
| C stuck on terrain / no path, never gives up | 7 | 0 |
| B squadmates jam each other: give-way loops | 11 | 0 |
| D drives away from where it is going | 3 | 0 |
| F holds fire with an enemy in sight and in range | 7 | 0 |
| none no class | 23 | 10 |

## A. hurt crews retreat by abandoning the squad (1)

- rank 38 **Green_Hunters_1** gorge seed 13122; rule seconds {'A': 8}; ranker: reversing on a move order (17 s); no progress toward its goal (5 s); hit from beyond its own range (4 s); far from its squad (61.3 m)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Green_Hunters_1 SPOT_FROM=69 SPOT_TO=79`

## E. shot from beyond its range, no answer (18)

- rank 31 **Green_Guns_3** gorge seed 13122, cause: no answer; rule seconds {'E': 7}; ranker: hit from beyond its own range (9 s); sitting still under fire, not shooting back (6 s); driving away from its route (2 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_3 SPOT_FROM=100 SPOT_TO=110`
- rank 33 **Rust_Hunters2_1** locks seed 13124, cause: no answer; rule seconds {'E': 7}; ranker: hit from beyond its own range (9 s); taking fire from behind (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters2_1 SPOT_FROM=57 SPOT_TO=67`
- rank 36 **Rust_Spears_5** gorge seed 13122, cause: no answer; rule seconds {'E': 4}; ranker: sitting still under fire, not shooting back (4 s); hit from beyond its own range (6 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Rust_Spears_5 SPOT_FROM=78 SPOT_TO=87`
- rank 39 **Green_Sirens_3** locks seed 13122, cause: no answer; rule seconds {'E': 2}; ranker: hit from beyond its own range (9 s); sitting still under fire, not shooting back (4 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=locks SPOT_CREW=Green_Sirens_3 SPOT_FROM=16 SPOT_TO=26`
- rank 42 **Rust_Wrenches_5** sumps seed 13122, cause: no answer; rule seconds {'E': 6}; ranker: sitting still under fire, not shooting back (8 s); hit from beyond its own range (9 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=sumps SPOT_CREW=Rust_Wrenches_5 SPOT_FROM=38 SPOT_TO=48`
- rank 48 **Rust_Wrenches_1** terminus seed 13124, cause: no answer; rule seconds {'E': 4}; ranker: taking fire from behind (9 s); enemy in sight and in range, not firing (2 s); sitting still under fire, not shooting back (2 s); blocked by a friendly (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Rust_Wrenches_1 SPOT_FROM=107 SPOT_TO=117`
- rank 54 **Rust_Wrenches_2** parade seed 13124, cause: no answer; rule seconds {'E': 9}; ranker: hit from beyond its own range (15 s); taking fire from behind (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=parade SPOT_CREW=Rust_Wrenches_2 SPOT_FROM=78 SPOT_TO=88`
- rank 59 **Rust_Guns_3** terminus seed 13124, cause: no answer; rule seconds {'E': 7}; ranker: taking fire from behind (12 s); hit from beyond its own range (8 s); enemy in sight and in range, not firing (8 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Rust_Guns_3 SPOT_FROM=62 SPOT_TO=72`
- rank 62 **Rust_Burners2_3** gorge seed 13121, cause: no answer; rule seconds {'E': 4}; ranker: taking fire from behind (4 s); sitting still under fire, not shooting back (2 s); hit from beyond its own range (6 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=gorge SPOT_CREW=Rust_Burners2_3 SPOT_FROM=58 SPOT_TO=67`
- rank 65 **Green_Guns_1** gorge seed 13121, cause: no answer; rule seconds {'E': 9}; ranker: hit from beyond its own range (11 s); reversing on a move order (12 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_1 SPOT_FROM=46 SPOT_TO=56`
- rank 69 **Green_Guns_1** gorge seed 13122, cause: no answer; rule seconds {'E': 3}; ranker: sitting still under fire, not shooting back (5 s); taking fire from behind (5 s); hit from beyond its own range (5 s); enemy in sight and in range, not firing (3 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_1 SPOT_FROM=37 SPOT_TO=45`
- rank 71 **Rust_Sirens_3** parade seed 13123, cause: no answer; rule seconds {'E': 6}; ranker: hit from beyond its own range (10 s); taking fire from behind (2 s); far from its squad (26.4 m)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=parade SPOT_CREW=Rust_Sirens_3 SPOT_FROM=32 SPOT_TO=42`
- rank 72 **Green_Eyes_2** crossing seed 13122, cause: no answer; rule seconds {'E': 4}; ranker: hit from beyond its own range (6 s); taking fire from behind (3 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=crossing SPOT_CREW=Green_Eyes_2 SPOT_FROM=50 SPOT_TO=59`
- rank 73 **Rust_Burners_1** locks seed 13121, cause: no answer; rule seconds {'E': 4}; ranker: taking fire from behind (4 s); hit from beyond its own range (6 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Burners_1 SPOT_FROM=19 SPOT_TO=28`
- rank 77 **Rust_Spears_1** locks seed 13122, cause: no answer; rule seconds {'E': 4}; ranker: hit from beyond its own range (6 s); taking fire from behind (2 s); reversing on a move order (4 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=locks SPOT_CREW=Rust_Spears_1 SPOT_FROM=13 SPOT_TO=23`
- rank 86 **Rust_Wrenches_5** terminus seed 13124, cause: no answer; rule seconds {'E': 6}; ranker: taking fire from behind (7 s); hit from beyond its own range (10 s); far from its squad (34 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Rust_Wrenches_5 SPOT_FROM=27 SPOT_TO=37`
- rank 90 **Green_Guns_2** gorge seed 13122, cause: no answer; rule seconds {'E': 6}; ranker: hit from beyond its own range (8 s); sitting still under fire, not shooting back (5 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_2 SPOT_FROM=101 SPOT_TO=111`
- rank 93 **Green_Spears_2** locks seed 13121, cause: no answer; rule seconds {'E': 5}; ranker: taking fire from behind (4 s); hit from beyond its own range (4 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Green_Spears_2 SPOT_FROM=57 SPOT_TO=64`

## C. stuck on terrain / no path, never gives up (7)

- rank 35 **Rust_Hunters_2** locks seed 13121; rule seconds {'C': 5, 'B': 2}; ranker: no progress toward its goal (12 s); blocked by a friendly (14 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters_2 SPOT_FROM=54 SPOT_TO=64`
- rank 40 **Rust_Battery_2** locks seed 13122; rule seconds {'C': 2, 'D': 2}; ranker: no progress toward its goal (9 s); reversing on a move order (8 s); blocked by a friendly (6 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=locks SPOT_CREW=Rust_Battery_2 SPOT_FROM=190 SPOT_TO=200`
- rank 43 **Green_Hunters_4** crossing seed 13122; rule seconds {'C': 9}; ranker: blocked by a friendly (203 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters_4 SPOT_FROM=232 SPOT_TO=242`
- rank 46 **Rust_Wrenches_4** terminus seed 13124; rule seconds {'C': 7}; ranker: blocked by a friendly (14 s); no progress toward its goal (10 s); driving away from its route (3 s); far from its squad (34.6 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Rust_Wrenches_4 SPOT_FROM=26 SPOT_TO=36`
- rank 50 **Green_Hunters_2** crossing seed 13123; rule seconds {'C': 11}; ranker: blocked by a friendly (51 s); taking fire from behind (4 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters_2 SPOT_FROM=58 SPOT_TO=68`
- rank 61 **Green_Wrenches_3** locks seed 13121; rule seconds {'C': 2}; ranker: reversing on a move order (10 s); blocked by a friendly (9 s); no progress toward its goal (6 s); far from its squad (30.9 m)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Green_Wrenches_3 SPOT_FROM=33 SPOT_TO=43`
- rank 75 **Rust_Guns_2** sumps seed 13124; rule seconds {'C': 4}; ranker: reversing on a move order (14 s); blocked by a friendly (11 s); no progress toward its goal (8 s); far from its squad (44.6 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=sumps SPOT_CREW=Rust_Guns_2 SPOT_FROM=67 SPOT_TO=77`

## B. squadmates jam each other: give-way loops (11)

- rank 37 **Green_Lances_3** crossing seed 13123, cause: moving squadmates; rule seconds {'F': 1, 'B': 6}; ranker: blocked by a friendly (13 s); enemy in sight and in range, not firing (9 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=crossing SPOT_CREW=Green_Lances_3 SPOT_FROM=40 SPOT_TO=50`
- rank 41 **Green_Hunters_9** sumps seed 13121, cause: held crew gives way; rule seconds {'B': 3}; ranker: blocked by a friendly (30 s); reversing on a move order (3 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=sumps SPOT_CREW=Green_Hunters_9 SPOT_FROM=48 SPOT_TO=58`
- rank 44 **Green_Eyes II_1** crossing seed 13124, cause: moving squadmates; rule seconds {'B': 9}; ranker: no progress toward its goal (14 s); blocked by a friendly (17 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=crossing SPOT_CREW=Green_Eyes II_1 SPOT_FROM=118 SPOT_TO=128`
- rank 47 **Rust_Guns2_3** sumps seed 13124, cause: moving squadmates; rule seconds {'B': 7, 'D': 2}; ranker: no progress toward its goal (18 s); blocked by a friendly (14 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=sumps SPOT_CREW=Rust_Guns2_3 SPOT_FROM=104 SPOT_TO=114`
- rank 55 **Rust_Burners_3** gorge seed 13121, cause: moving squadmates; rule seconds {'B': 5, 'D': 1, 'C': 1}; ranker: no progress toward its goal (11 s); blocked by a friendly (8 s); driving away from its route (3 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=gorge SPOT_CREW=Rust_Burners_3 SPOT_FROM=151 SPOT_TO=161`
- rank 64 **Rust_Hunters_3** locks seed 13121, cause: moving squadmates; rule seconds {'B': 7, 'D': 1}; ranker: no progress toward its goal (13 s); blocked by a friendly (12 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters_3 SPOT_FROM=54 SPOT_TO=64`
- rank 66 **Rust_Hunters_3** gorge seed 13121, cause: moving squadmates; rule seconds {'D': 3, 'B': 4}; ranker: no progress toward its goal (12 s); reversing on a move order (10 s); blocked by a friendly (5 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=gorge SPOT_CREW=Rust_Hunters_3 SPOT_FROM=111 SPOT_TO=121`
- rank 82 **Rust_Hunters_5** locks seed 13123, cause: moving squadmates; rule seconds {'C': 1, 'B': 5, 'D': 1}; ranker: no progress toward its goal (12 s); reversing on a move order (3 s); far from its squad (50.2 m); turning on the spot (36 deg/s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters_5 SPOT_FROM=22 SPOT_TO=32`
- rank 83 **Rust_Hunters_2** crossing seed 13121, cause: moving squadmates; rule seconds {'B': 1}; ranker: pressed against a wall or prop (2 s); no progress toward its goal (6 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=crossing SPOT_CREW=Rust_Hunters_2 SPOT_FROM=53 SPOT_TO=62`
- rank 91 **Rust_Lances_2** locks seed 13121, cause: moving squadmates; rule seconds {'B': 4, 'D': 1}; ranker: no progress toward its goal (10 s); blocked by a friendly (12 s); reversing on a move order (4 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Lances_2 SPOT_FROM=152 SPOT_TO=162`
- rank 92 **Rust_Sirens_2** locks seed 13123, cause: moving squadmates; rule seconds {'B': 3, 'C': 1}; ranker: driving away from its route (10 s); blocked by a friendly (11 s); no progress toward its goal (8 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=locks SPOT_CREW=Rust_Sirens_2 SPOT_FROM=32 SPOT_TO=42`

## D. drives away from where it is going (3)

- rank 32 **Rust_Guns_3** crossing seed 13123; rule seconds {'D': 7, 'C': 3}; ranker: no progress toward its goal (20 s); reversing on a move order (11 s); driving away from its route (3 s); blocked by a friendly (4 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=crossing SPOT_CREW=Rust_Guns_3 SPOT_FROM=30 SPOT_TO=40`
- rank 60 **Green_Eyes II_6** parade seed 13124; rule seconds {'D': 1}; ranker: driving away from its route (5 s); enemy in sight and in range, not firing (23 s); far from its squad (50.6 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=parade SPOT_CREW=Green_Eyes II_6 SPOT_FROM=27 SPOT_TO=37`
- rank 81 **Green_Eyes II_2** parade seed 13124; rule seconds {'D': 2}; ranker: driving away from its route (6 s); enemy in sight and in range, not firing (13 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=parade SPOT_CREW=Green_Eyes II_2 SPOT_FROM=17 SPOT_TO=27`

## F. holds fire with an enemy in sight and in range (7)

- rank 34 **Green_Hunters_5** terminus seed 13122, cause: support by fire; rule seconds {'D': 1, 'F': 7}; ranker: enemy in sight and in range, not firing (14 s); driving away from its route (4 s); no progress toward its goal (7 s); turning on the spot (94.9 deg/s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=terminus SPOT_CREW=Green_Hunters_5 SPOT_FROM=31 SPOT_TO=41`
- rank 51 **Rust_Guns2_3** gorge seed 13124, cause: support by fire; rule seconds {'F': 6, 'E': 5}; ranker: taking fire from behind (8 s); hit from beyond its own range (6 s); enemy in sight and in range, not firing (41 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=gorge SPOT_CREW=Rust_Guns2_3 SPOT_FROM=76 SPOT_TO=86`
- rank 56 **Rust_Guns_2** parade seed 13121, cause: ambush (holds fire on purpose); rule seconds {'F': 9}; ranker: enemy in sight and in range, not firing (19 s); turning on the spot (79.9 deg/s); no progress toward its goal (3 s); blocked by a friendly (3 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=parade SPOT_CREW=Rust_Guns_2 SPOT_FROM=21 SPOT_TO=31`
- rank 80 **Rust_Guns_3** locks seed 13124, cause: holding; rule seconds {'F': 2}; ranker: enemy in sight and in range, not firing (66 s); reversing on a move order (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=locks SPOT_CREW=Rust_Guns_3 SPOT_FROM=209 SPOT_TO=219`
- rank 95 **Green_Hunters_5** sumps seed 13122, cause: support by fire; rule seconds {'F': 2, 'B': 1}; ranker: enemy in sight and in range, not firing (10 s); turning on the spot (89.8 deg/s); driving away from its route (2 s); no progress toward its goal (4 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=sumps SPOT_CREW=Green_Hunters_5 SPOT_FROM=32 SPOT_TO=42`
- rank 97 **Rust_Guns_5** crossing seed 13124, cause: holding; rule seconds {'F': 10}; ranker: far from its squad (69.6 m); taking fire from behind (5 s); hit from beyond its own range (3 s); reversing on a move order (7 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=crossing SPOT_CREW=Rust_Guns_5 SPOT_FROM=31 SPOT_TO=41`
- rank 99 **Rust_Guns_3** parade seed 13121, cause: support by fire; rule seconds {'F': 3}; ranker: taking fire from behind (3 s); enemy in sight and in range, not firing (10 s); turning on the spot (67.3 deg/s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=parade SPOT_CREW=Rust_Guns_3 SPOT_FROM=49 SPOT_TO=59`

## none. no class (the rule sees none of it) (23)

- rank 45 **Rust_Hunters2_4** parade seed 13124; rule seconds {}; ranker: taking fire from behind (12 s); sitting still under fire, not shooting back (2 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=parade SPOT_CREW=Rust_Hunters2_4 SPOT_FROM=72 SPOT_TO=82`
- rank 49 **Green_Eyes II_8** terminus seed 13124; rule seconds {}; ranker: turning on the spot (88.8 deg/s); enemy in sight and in range, not firing (11 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Green_Eyes II_8 SPOT_FROM=41 SPOT_TO=51`
- rank 52 **Green_Hunters_2** gorge seed 13124; rule seconds {}; ranker: sitting still under fire, not shooting back (3 s); enemy in sight and in range, not firing (18 s); blocked by a friendly (3 s); far from its squad (31.6 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=gorge SPOT_CREW=Green_Hunters_2 SPOT_FROM=45 SPOT_TO=55`
- rank 53 **Rust_Spears_4** locks seed 13122; rule seconds {}; ranker: no progress toward its goal (5 s); taking fire from behind (4 s); hit from beyond its own range (4 s); reversing on a move order (3 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=locks SPOT_CREW=Rust_Spears_4 SPOT_FROM=41 SPOT_TO=51`
- rank 57 **Rust_Guns_2** gorge seed 13124; rule seconds {}; ranker: driving away from its route (9 s); far from its squad (59.2 m)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=gorge SPOT_CREW=Rust_Guns_2 SPOT_FROM=17 SPOT_TO=27`
- rank 58 **Rust_Lances_1** locks seed 13121; rule seconds {}; ranker: turning on the spot (27.4 deg/s); far from its squad (36.7 m); driving away from its route (2 s); enemy in sight and in range, not firing (2 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Lances_1 SPOT_FROM=76 SPOT_TO=86`
- rank 63 **Rust_Hunters_5** gorge seed 13122; rule seconds {}; ranker: reversing on a move order (12 s); far from its squad (48.4 m)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=gorge SPOT_CREW=Rust_Hunters_5 SPOT_FROM=12 SPOT_TO=22`
- rank 67 **Green_Eyes II_1** terminus seed 13124; rule seconds {}; ranker: taking fire from behind (3 s); enemy in sight and in range, not firing (24 s); driving away from its route (3 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=terminus SPOT_CREW=Green_Eyes II_1 SPOT_FROM=65 SPOT_TO=75`
- rank 68 **Green_Lances_4** terminus seed 13123; rule seconds {}; ranker: driving away from its route (2 s); far from its squad (36.8 m); turning on the spot (80.4 deg/s); enemy in sight and in range, not firing (4 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=terminus SPOT_CREW=Green_Lances_4 SPOT_FROM=27 SPOT_TO=37`
- rank 70 **Green_Eyes II_4** gorge seed 13124; rule seconds {}; ranker: enemy in sight and in range, not firing (34 s); driving away from its route (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=gorge SPOT_CREW=Green_Eyes II_4 SPOT_FROM=54 SPOT_TO=64`
- rank 74 **Rust_Hunters_4** terminus seed 13123; rule seconds {}; ranker: driving away from its route (6 s); no progress toward its goal (3 s); blocked by a friendly (5 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=terminus SPOT_CREW=Rust_Hunters_4 SPOT_FROM=17 SPOT_TO=26`
- rank 76 **Rust_Hunters_4** locks seed 13124; rule seconds {}; ranker: taking fire from behind (8 s); no progress toward its goal (5 s); enemy in sight and in range, not firing (5 s); blocked by a friendly (3 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters_4 SPOT_FROM=24 SPOT_TO=34`
- rank 78 **Rust_Burners2_1** sumps seed 13121; rule seconds {}; ranker: taking fire from behind (6 s); hit from beyond its own range (3 s); enemy in sight and in range, not firing (1 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=sumps SPOT_CREW=Rust_Burners2_1 SPOT_FROM=69 SPOT_TO=78`
- rank 79 **Green_Hunters II_5** crossing seed 13124; rule seconds {}; ranker: far from its squad (88.3 m); blocked by a friendly (5 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters II_5 SPOT_FROM=44 SPOT_TO=54`
- rank 84 **Green_Lances_4** sumps seed 13123; rule seconds {}; ranker: taking fire from behind (7 s); sitting still under fire, not shooting back (2 s); turning on the spot (25.6 deg/s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=sumps SPOT_CREW=Green_Lances_4 SPOT_FROM=99 SPOT_TO=109`
- rank 85 **Rust_Eyes_2** terminus seed 13123; rule seconds {}; ranker: driving away from its route (6 s); far from its squad (49.1 m)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=terminus SPOT_CREW=Rust_Eyes_2 SPOT_FROM=121 SPOT_TO=131`
- rank 87 **Rust_Spears_3** locks seed 13122; rule seconds {}; ranker: hit from beyond its own range (6 s); taking fire from behind (2 s); driving away from its route (2 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=locks SPOT_CREW=Rust_Spears_3 SPOT_FROM=27 SPOT_TO=36`
- rank 88 **Green_Eyes II_7** crossing seed 13124; rule seconds {}; ranker: far from its squad (102.1 m); turning on the spot (35.9 deg/s); reversing on a move order (3 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=crossing SPOT_CREW=Green_Eyes II_7 SPOT_FROM=192 SPOT_TO=202`
- rank 89 **Green_Guns_2** crossing seed 13122; rule seconds {}; ranker: far from its squad (72.2 m); enemy in sight and in range, not firing (4 s)
  `make spotter-clip SPOT_SEED=13122 SPOT_ARENA=crossing SPOT_CREW=Green_Guns_2 SPOT_FROM=19 SPOT_TO=29`
- rank 94 **Rust_Burners_1** sumps seed 13121; rule seconds {}; ranker: driving away from its route (8 s); blocked by a friendly (6 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=sumps SPOT_CREW=Rust_Burners_1 SPOT_FROM=18 SPOT_TO=28`
- rank 96 **Rust_Eyes_3** terminus seed 13123; rule seconds {}; ranker: blocked by a friendly (6 s); no progress toward its goal (4 s); reversing on a move order (3 s)
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=terminus SPOT_CREW=Rust_Eyes_3 SPOT_FROM=27 SPOT_TO=37`
- rank 98 **Green_Hunters_2** crossing seed 13124; rule seconds {}; ranker: far from its squad (86.3 m); driving away from its route (4 s)
  `make spotter-clip SPOT_SEED=13124 SPOT_ARENA=crossing SPOT_CREW=Green_Hunters_2 SPOT_FROM=90 SPOT_TO=100`
- rank 100 **Green_Guns_5** gorge seed 13121; rule seconds {}; ranker: reversing on a move order (21 s)
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=gorge SPOT_CREW=Green_Guns_5 SPOT_FROM=20 SPOT_TO=30`
