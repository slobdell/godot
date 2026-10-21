# The round scoreboard

The same fixed workload run against each main, so the columns compare: what a player would notice. Oldest main on the left. Each number is read from that main's own run by today's readers (`tools/scoreboard/`), so the method is the same in every column; "n/a" means that main's game never printed it (older than the thing measured).

**The workload** (`mk/scoreboard.mk`, native, pinned at 30 Hz): 40 showmatch fights (Terminus, Locks, Sumps, Gorge, Parade x 8 seeds, 180 s, CPU v CPU); 48 move orders drawn with a facing (attack-move and move, every faction x 6 seeds, Foundry, a quiet enemy); 36 group orders (Locks, Crossing, Terminus x 3 and 5 squads x one click and a route x 3 seeds). Seeds 2601+ on every main.

| | **round 34 close**<br>`c29a8c7b6` | **round 35 launch**<br>`a0ae0aafd` | **today's main (2026-10-20)**<br>`1c82d6d1e` | **CP36.1: the joint W1c+T9, 4 maps adopted**<br>`e45bb6632` | **T8 ships: a held crew that is hit leaves the hold**<br>`3d46b2884` | **round 37 launch: the guard lines' base**<br>`9d325e291` | better | ± noise |
|---|---|---|---|---|---|---|---|---|
| **Fights** | | | | | | | | |
| Tanks lost per fight, any cause | 40.4 | 40.4 | 41.9 | 40.9 | 40.4 | not run | lower | ± 9.82 |
| ... shot in the open (the fight itself) | 32.2 | 32.2 | 33.9 | 33.1 | 33.0 | not run |  | ± 8.52 |
| ... stuck: wedged against terrain or a wreck when killed | 6.1 | 6.1 | 6.22 | 6.03 | 5.92 | not run | lower | ± 2.33 |
| ... jammed in our own traffic when killed | 2.08 | 2.08 | 1.77 | 1.8 | 1.55 | not run | lower | ± 0.96 |
| ... jammed AND under fire (the killing-zone case) | 1.75 | 1.75 | 1.3 | 1.48 | 1.2 | not run | lower | ± 0.76 |
| ... killed while held at a street mouth (waiting its turn) | 1.77 | 1.77 | 1.82 | 1.65 | 0.42 | not run | lower | ± 0.4 |
| Kills per fight | 40.0 | 40.0 | 41.4 | 40.5 | 40.0 | not run |  | ± 9.72 |
| Hit rate | 74 % | 74 % | 75 % | 76 % | 76 % | not run |  | ± 6.6 % |
| Fights read (of fights run) | 40 of 40 | 40 of 40 | 40 of 40 | 40 of 40 | 40 of 40 | not run |  |  |
| **Moving out** | | | | | | | | |
| Orders where the squad never settled in 75 s | 13 of 48 | 13 of 48 | 10 of 48 | 9 of 48 | 9 of 48 | not run | lower | ± 7.31 |
| Crews left 25+ m behind their squad, per order | 0 | 0 | 0.06 | 0.12 | 0.12 | not run | lower | ± 0.17 |
| Crews still driving toward the spot at the end, per order | 0.1 | 0.1 | 0.12 | 0.1 | 0.1 | not run | lower | ± 0.22 |
| Crews rocking in place at the end (stuck), per order | 0.04 | 0.04 | 0.04 | 0.08 | 0.08 | not run | lower | ± 0.16 |
| **Group orders** | | | | | | | | |
| Seconds until every squad is in (median) | 18.9 s | 18.9 s | 18.9 s | 18.9 s | 18.9 s | not run | lower | ± 7.9 s |
| Orders where some squad never got in (90 s) | 5 of 36 | 5 of 36 | 0 of 36 | 0 of 36 | 0 of 36 | not run | lower | no spread |
| Squads that drove across to the far bank (should be 0) | 0 | 0 | 0 | 0 | 0 | not run | lower | no spread |
| Twitch after placing, median (metres a crew shuffles) | 12.9 m | 12.9 m | 12.6 m | 10.8 m | 10.8 m | not run | lower | ± 3.59 m |
| **Guard lines** (his measure: both should be rare) | | | | | | | | |
| A blob frontal assault WINS (should be rare) | not run | not run | not run | not run | not run | 48 % | lower | ± 11 % |
| ... the blob's kill ratio (its kills / its losses) | not run | not run | not run | not run | not run | 0.88 | lower | ± 0.07 |
| ... blob fights decided on points at the 600 s cap | not run | not run | not run | not run | not run | 0 % |  | ± 0 % |
| A pure turtle WINS (should be rare too) | not run | not run | not run | not run | not run | 39 % | lower | ± 15 % |
| ... the turtle's kill ratio (its kills / its losses) | not run | not run | not run | not run | not run | 0.8 | lower | ± 0.17 |
| ... turtle fights decided on points at the 600 s cap | not run | not run | not run | not run | not run | 0 % |  | ± 0 % |
| Guard fights read (blob / turtle, of run) | not run | not run | not run | not run | not run | 160 of 160 / 160 of 160 |  |  |

**± noise** is two standard errors of a difference between two columns: a line moved only when two mains differ by more than it. Sized from the seed-to-seed spread of `3d46b2884`, `3d46b2884-b2700` (one main, 2 seed blocks; each seed's fights / move orders / group orders read on their own), se of one column = sd / sqrt(seeds a column has), a difference x sqrt(2). Medians and counts are approximate this way; a line near its noise needs a second block on both mains. "no spread" = the line read the same in every seed of the noise block (often 0), so nothing sizes it.

**The guard lines** (CP37.1, `tests/ai_scenarios/guard_line.gd`, `tools/scoreboard/guard.sh`): the showmatch fight run to its end (90 zone points or the last crew; a fight still going at 600 s goes to the side ahead on points), one side ordered and the other today's CPU. BLOB: every squad sent at once with his right-click (a plain move, no drills) at the zone in the enemy's half. TURTLE: every squad holds a post on its own zone and never advances. Terminus, Locks, Sumps, Gorge, Parade x seeds 2601-2608 and 2701-2708 x each side as the guard (both factions both ways): 160 fights a line. Their ± is the same method as the noise column, from that read's own 16 seeds.

**Where each column ran:**

- `c29a8c7b6` (round 34 close): builder2, workload and probes from `dc0298abe`, remote exit 0, SCRIPT ERROR lines fights 0 / moves 0 / orders 0. >> scoreboard-run on builder2 | commit c29a8c7b6 | native on | parts 'fights moves orders' | load 1.00 1.52 3.55
- `a0ae0aafd` (round 35 launch): builder2, workload and probes from `dc0298abe`, remote exit 0, SCRIPT ERROR lines fights 0 / moves 0 / orders 0. >> scoreboard-run on builder2 | commit a0ae0aafd | native on | parts 'fights moves orders' | load 5.62 8.64 7.93
- `1c82d6d1e` (today's main (2026-10-20)): builder2, workload and probes from `2024f8cc1`, remote exit 0, SCRIPT ERROR lines fights 0 / moves 0 / orders 0. >> scoreboard-run on builder2 | commit 1c82d6d1e | native on | parts 'fights moves orders' | load 5.96 8.91 9.22
- `e45bb6632` (CP36.1: the joint W1c+T9, 4 maps adopted): builder2, workload and probes from `090580147`, remote exit 0, SCRIPT ERROR lines fights 0 / moves 0 / orders 0. >> scoreboard-run on builder2 | commit e45bb6632 | native on | parts 'fights moves orders' | load 11.48 3.69 1.31
- `3d46b2884` (T8 ships: a held crew that is hit leaves the hold): builder2, workload and probes from `b87ea18ac`, remote exit 0, SCRIPT ERROR lines fights 0 / moves 0 / orders 0. >> scoreboard-run on builder2 | commit 3d46b2884 | native on | parts 'fights moves orders' | load 6.26 3.65 7.85
- `9d325e291` (round 37 launch: the guard lines' base): not run yet.

**How each line is read** (`tools/scoreboard/score.py`): fight deaths by T5's causes (tests/traffic/jam_ab.py; "under fire" = the last hit landed during the jam, or 2+ hits in the 10 s before); never settled = no `settled_after_s` inside the 75 s judge; left behind = more than 25 m off its slot in its element's last trace row (tests/tactics/e1_bar.py); still driving / rocking = brains' mover kinds (a crew moving at the judge that closed 3+ m on its goal or wandered, v one that moved under 1 m net in its last 10 s); group orders = tests/control/orders_probe_table.py (all-in = the last squad's arrival; twitch = the most a crew moved after its place; on a main older than the deploy step, from the squad's arrival).

