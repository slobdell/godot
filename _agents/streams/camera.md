# Stream: camera (a new selection pans at once; his squad stays near the middle of the screen)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 345, 352), `_agents/workstreams.md` **Round 47** (C47.1-C47.11;
> C47.10 is your laptop budget), your last brief `streams/archive/round46/camera.md` (FINAL REPORT: the planner, Bar C1, C1 v2),
> R46.20 / R46.23 / R46.37 in `workstreams.md`, and `game_design.md` *His playtest after round 46's ships* (item 4) and *His fifth note*.
> **You own:** `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`, `tests/test_camera*.gd`, `tests/camera/**`,
> `mk/camera.mk`; read-only feed lines in `game/modes/skirmish_mode.gd` (as C42.3). **Model:** Opus. **Machine:** builder3; the laptop
> only for the lock-held budget read. **Seeds:** 12801-12848 (Bar K), 12849-12896 (reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-30, verbatim)

Crossing (~15:42): "Also on the camera work, when I change squads, the camera does pan to the target squad but there seems be a delay
between selecting a squad and the camera starting to move toward the other selected squad (I sent half my army west and half my army
east)"

Parade (~16:08): "ok also in my last game, the camera didn't seem to be tracking the squads I was using very well, the camera position
was far away with the squad I was controlling off in the distance at the edge of the peripheral, and the camera position didn't seem
to correct"

His standing rule (round 46): ONE planner of camera position at all times, no special cases. He asked for the planner ON (R46.37).

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0; planner ON, `--camera-planner=off` = round 45's camera)

- **The delay:** at each selection the `cam` row goes to mode `aim-hold` and stays put: Crossing sel Spears tick 838 -> cam (-73, 60)
  unchanged at 840 and 863, first moves at 870 (~1 s); sel Guns tick 663 -> `aim-hold` at 690.
- **Not tracking (Parade, `references/round46/playtest/2026-10-30T16-03-40-parade.jsonl`, 130 cam rows):** median gap look-point to his selection's centre
  **18 m**; **38 % of rows > 30 m**; median camera distance 69 m (up to 100). Worst: sel Bravo ~tick 2941, look (30, 78) v Bravo (51, -73)
  **152 m off**; 2 s later 147, 5 s 107, 8 s 111 m (mode alternating `planner` / `aim-hold`). Delta then 77-92 m off while he panned by
  hand (`manual`). Sumps milder (ticks 3036-3121, 71-78 m off for 3 s; 3541-3601, 21-24 m off at 99 m distance).
- Suspects: `aim-hold` freezing the look on every selection; a slow pan over long distances; the cost preferring a far framing over his
  squad; `manual` pan never handing back. C1 v2 (the rear ambush without losing the building win) is the round-46 leftover.

## Backlog (in order)

1. **K1 planner ON v `--camera-planner=off` on Parade, Crossing and Sumps (Status first, then message the orchestrator):** the same
   gap measures (median, % > 30 m, time to < 20 m after a selection) for both. If round 45's camera tracks better, say which term of the
   planner causes it, by removal.
2. **K2 a selection pans at once, ON:** no `aim-hold` delay on a selection change (the planner's own rule, not a special case); the
   pan to a far squad completes in a time he won't call slow (state the number; ~0.5-0.8 s for 150 m is a starting guess).
3. **K3 his selection stays framed:** the planner's cost keeps his selection's centre within a bound of the look point at a
   distance that shows it (a hard term, not a weight that loses to the fight); `manual` hands back to the planner when he selects.
4. **K4 Bar K**, filed BEFORE any number on 12801-12848 (scripted selection changes in full fights): deciding = % of time his selection
   is > 30 m off, seconds to frame a new selection; guards = Bar C1's lines (hits/deaths on screen, occlusion by buildings, the
   rear-ambush turn), the laptop's per-frame cost (C47.10). Ships ON; name the green hash.
5. **K5 his acceptance read:** the three recordings' gap measures on the shipped tree, before/after.
6. **K6 C1 v2** (the rear ambush) if K1-K5 are done.

## Don't touch

`game/control/**` (orders; selection is theirs, you read it), `game/ui/**` but `camera_readout.gd`, movement / engage / route code,
`native/**`, `arenas/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-30 ~19:40, top = newest).** **Bar K READ: FAIL 29 of 33 (every deciding line passes; G2, G3, G4b, G8 fail).**
Candidate e4a614eab GREEN builder3 (`make check exited 0`, 3525 passed / 0 failed, 28 ALL JUDGED; the checked tree was b1f08cc2d =
e4a614eab + docs, with the two `.uid` files on disk, committed after in 2c60ccd93). Series 19:03-19:27 builder3, 72 deciding + 48
guard runs an arm, 0 lost; verdict `references/round47/camera/bark-verdict-builder3-e4a614eab.txt`. Laptop (R47.24 G10): planner
0.329 ms a frame, p99 0.80; whole rig BASE 0.852 v ARM 0.839 ms (UHD 620, laptop preset, NATIVE=off, lock-held, split 12801/12802,
60 s each). **The fix stays ON on the branch as the default; whether it reaches main is the orchestrator's (lesson 339 / C47.2).**

| Line | BASE (main) | ARM (fix) | |
|---|---|---|---|
| D1 selection > 30 m from the look, % of play | 11.9 | **6.9** (ratio 0.58) | PASS |
| D2 a far pick framed (< 20 m), mean / p90 s | 4.92 / 10.0 | **0.73 / 0.95** | PASS |
| D3 far picks never framed | 244 | **21** | PASS |
| G1 hidden by a building while driving, s | 1085.9 | 845.7 | PASS |
| **G2 none of his selection on screen, s** | 61.1 | 143.2 | **FAIL** |
| **G3 hits on his units off screen, %** | 5.3 | 12.6 | **FAIL** |
| G4a/c jerks; a pan not a cut (peak heights/s) | 2.56; 1.31 | 2.66; 4.02 | PASS |
| **G4b snaps from a source but the pan** | 0 | 7 ('planner', in 72 runs) | **FAIL** |
| G5 clicks on the aimed unit / slip p95 / held | 83.4 % / 29.5 px / 37.3 % | 77.9 % / 34.8 px / 27.8 % | PASS |
| G6 action share / G7 inside a solid | 46.5 % / 0.11 s | 48.1 % / 0.15 s | PASS |
| **G8 rear ambush first shot -> on screen (never = 20)** | 7.08 s (14 episodes, 4 never) | 8.56 s (11, 4 never) | **FAIL** |
| G8 all lanes; retreat | 6.73; 6.33 s | 5.91; 6.04 s | PASS |

**SHIPPED ON (R47.29, his "Ship it ON"): 2c60ccd93 merged into main.**

**K5 his acceptance read (the shipped code e4a614eab, builder3, `make camera-replay CAMK_HAND=model|rest|busy`; main's camera =
`--camera-select-pan=off`; R47.8's caveat: the replays leave his matches, both arms replay the same match):**

| Recording | his own rows (1 Hz) | > 30 m off, main -> FIX: hand model / rest / busy | far pick framed, median s (max), FIX: model / rest / busy | never, main -> FIX (model) |
|---|---|---|---|---|
| Parade | 42.0 % | 26.4 -> **6.2** / 41.9 -> **10.0** / 20.8 -> **6.6** | 0.33 (0.63) / 0.30 (0.63) / 0.35 (0.63) | 7 -> 1 |
| Crossing | 12.6 % | 13.4 -> **4.5** / 29.5 -> **9.7** / 13.9 -> **4.5** | 0.35 (0.73) / 0.30 (0.73) / 0.35 (0.73) | 3 -> 2 |
| Sumps | 16.7 % | 13.9 -> **4.3** / 14.9 -> **4.6** / 13.5 -> **4.1** | 0.37 (0.83) / 0.40 (1.27) / 0.37 (0.83) | 6 -> 0 |
| Locks | 23.5 % | 26.8 -> **4.7** / 27.1 -> **5.0** / 20.2 -> **4.7** | 0.47 (0.53) / 0.47 (0.53) / 0.45 (0.53) | 4 -> 0 |

The finding holds under every hand: main's camera is worst with a resting hand (it holds for his aim), the fix is the same under
all three. Logs: `~/camera-r47/k5-{model,rest,busy}.log` (laptop).

**In his terms.** ON: when he picks a squad by its key, the camera sets off for it at once and is on it in under a second (main:
5 s on average, and a quarter of far picks never reached). The cost is the squad he LEAVES: G2 and G3 come entirely from the split
workload, the one built to flip between squads 140 m apart (ATTACK: none on screen 8.9 -> 7.1 s, hits off screen ~1.3 -> 1.6 %).
On main the view never really left the old squad, so its fight stayed in view and the new one sat at the top edge ("on screen");
ON, the old squad's fight is off screen once he has moved to the new one (that is what he asked for), and for ~0.15 s of each far
pick neither squad is in view mid-pan. G8 is the same turn: the rear-lane latencies are the same in both arms with the same 4
"never"; ARM had 3 fewer episodes, so the four 20 s nevers weigh more in the mean. G4b: 7 one-frame snaps tagged 'planner' in 72
runs (BASE 0), the pan's tail as it hands over. **Clicks (the orchestrator's watch item):** 83.4 -> 77.9 % on the aimed unit; 60
clicks of ARM's were aimed while a pan ran (BASE 6), slip p95 on those 464 px; so yes: if he clicks while the view is still
sweeping to the squad he just picked, he misclicks more; a click after the view has arrived lands as on main (slip p95 34.8 v
29.5 px overall).

**Recommendation (lesson 339):** ship ON. What he asked for (pans at once, his squad stays framed) passes by 4-7x; the failed guards
are the price of the camera following the squad he picks (G2/G3), a counting artefact (G8), and 7 snaps. `--camera-select-pan=off`
is main's camera. Ship hash for the orchestrator: **2c60ccd93** (= e4a614eab's code, the green check's tree + the two .uid files)
or e4a614eab itself.

### Plan (ordered; smallest foundation first)
1. K1 tools: `tests/camera/replay_camera.gd` (his match replayed WITH his `sel` rows and a hand model), `tests/camera/k1_gap.py`
   (the look-to-selection gap), `make camera-replay` (arms per recording). Then K1's table, ON v OFF, his three recordings (+ Locks).
2. K2+K3 as ONE rule (they have one cause): `RtsCamera._pan_urgent`. Tests first: `tests/test_camera_select_pan.gd`.
3. K4 Bar K: CameraLook `sel_far_s` / `sel_frames`, CameraPlaytest `--camera-scenario=split`, `tests/camera/bar_k.py`; dev read
   (7001-7004) to make each deciding line fire on BASE (lesson 350), then file, then the series on 12801-12848.
4. K5 his three recordings before/after with the K1 tools. 5. K6 C1 v2 only if time is left.

### K1: the cause (read from his Parade recording, main e306ce27f, laptop; my measure, `k1_gap.py` on his `cam` rows)
His recordings, 1 Hz `cam` rows v his `sel` rows' centre at the last census row (gap = look point to selection centre):

| Recording | n rows | median gap | > 30 m | median distance | far selections (> 20 m when picked) | framed (< 20 m) after | never |
|---|---|---|---|---|---|---|---|
| Parade | 131 | 21.8 m | 42.0 % | 68.9 m | 18 | median 1.0 s, max 2.0 | **11** |
| Crossing | 127 | 8.5 m | 12.6 % | 97.5 m | 5 | median 3.0 s, max 5.2 | 0 |
| Sumps | 132 | 8.2 m | 16.7 % | 78.2 m | 13 | median 1.0 s, max 6.0 | 1 |
| Locks | 81 | 11.1 m | 23.5 % | 87.7 m | 6 | median 0.4 s | 4 |

**Why (Parade tick 2900-3181, rows read one by one):** he selects Bravo 152 m north of the look point; the view is pitched 21 deg
at ~50 m, so a squad 150 m straight ahead sits at the TOP EDGE of his screen, which round 46's rule counts as "on screen". The
urgent pan only ran while a crew was OFF screen, so it never started: the look crept 4 m in the first second (the glide's
normal pace x the hand-moving pace 0.25 = ~4.7 m/s at 50 m) and stopped whenever his hand rested (`aim-hold`). Mode alternated
`planner`/`aim-hold` for 10 s, 141-152 m off, until he gave up and panned by hand. The Crossing delay is the same rule: a squad
partly on screen = no urgent pan, and his hand on the mouse holds or slows the rest. The planner's wanted point was on Bravo
(its fit centres the selection); the glide never got there.

**K1 ON v OFF (his matches replayed with his selections; builder3; `make camera-replay`, tests/camera/replay_camera.gd).**
Arms: **R46** = `--camera-planner=on --camera-select-pan=off` (main's camera, e306ce27f's rule), **R45** = `--camera-planner=off`
(round 45's camera), **FIX** = the K2(+K3) default. Trees: Crossing and Locks ran ecd0bfcb5 (K2 at 4 heights/s, before K3's
bound); Parade and Sumps ran ebfc3b162 (K2 + K3). Samples every 5 ticks, n = 380 (Crossing), 362 (Locks), 697 (Parade), 691
(Sumps) per arm. **Hand model (his real hand is not in the recording):** the mouse moves 0.6 s then rests 0.4 s, every second, all
match (resting under HOVER_HOLD_S, so the aim hold applies as it did for him); each selection and each order is a click (it spends
the aim); no hand pans, wheel or rotation (his `manual` rows are not replayed). **Not his exact match (R47.8):** `REPLAY_SPAWN
placed 0` (native's N0), so the units leave his match within seconds; the camera writes no sim state, so all three arms replay the
SAME diverged match: a like-for-like A/B, not his screen. Parade's armies are his own files (tests/camera/armies); Sumps' CPU side
is rebuilt from the roster (directives assumed). "Never" includes selections replaced or killed before framing (same in each arm).

| Recording | > 30 m off: R46 / R45 / FIX | median gap m | far selections framed, median s (max) R46 / R45 / FIX | never R46 / R45 / FIX |
|---|---|---|---|---|
| Parade | 26.4 / 42.0 / **4.6 %** | 18.3 / 24.6 / **8.1** | 1.33 (12.3) / 3.77 (4.9) / **0.33 (0.63)** | 7 / 9 / **1** |
| Sumps | 13.9 / 22.0 / **3.2 %** | 8.0 / 9.7 / **4.1** | 1.27 (6.9) / 1.13 (4.5) / **0.30 (0.63)** | 6 / 6 / **0** |
| Crossing | 13.4 / 33.2 / **5.5 %** | 9.9 / 11.1 / **7.7** | 1.07 (6.8) / 4.07 (13.1) / **0.33 (0.73)** | 3 / 3 / 2 |
| Locks | 26.8 / 13.3 / **4.7 %** | 7.6 / 6.1 / **6.5** | 0.73 (0.97) / 0.83 (1.43) / **0.47 (0.53)** | 4 / 5 / **0** |

**Answer to K1:** round 45's camera does NOT track better overall (worse on Parade, Sumps and Crossing; better on Locks: it
sits closer, 66 v 83 m). Neither old camera pans to a far selection quickly: both slow for his hand and hold for his aim. The
term that causes round 46's misses is the urgent pan's trigger ("a crew off screen"; a squad far ahead is ON screen at the top
edge), plus, at 100 m, the planner's lean/wide frame putting his squad 35 m off the look (Crossing tick 690: K3's bound).


### Bar K FILED (2026-10-30 ~18:30, stream/camera, before any number on 12801-12848; candidate e4a614eab, its full check on builder3 running at filing)

**Bar K, a new selection pans at once and his squad stays framed (camera K2/K3; C47.1, C47.2, C47.10).** Switch
`--camera-select-pan` (ON at e4a614eab; `=off` = main's camera, round 46's planner exactly: byte-identical BASE path). The rule
(`RtsCamera._pan_urgent`): the pick's own pan starts at once if the planner's point is > 20 m from the shown look point (no aim
hold, no hand pace), moves the LOOK POINT only (the turn and zoom keep his hand's pace and hold), a spring from rest capped at
4 view-heights/s, and ends when that gap is <= 12 m and the pan has slowed to what his hand allows, or after 1.5 s; a later start
(a second within FRESH_S, or a frame that has drifted 30 m with no hand on the camera since the pick) waits until he is not aiming.
K3's 20 m bound is PARKED OFF (dev knob `--camera-sel-bound`). Constants as in the code; no dev knob in the series.
**Arms:** BASE `--camera-select-pan=off` v ARM default, ONE commit (e4a614eab, frozen: no edits in the worktree while it runs),
builder3, headless 1920x1080 @60, `make camera-trace` (CameraPlaytest), 150 s. Series: `~/camera-r47/bark.sh`.
**Workloads:** SPLIT (`--camera-scenario=split`: his Crossing case, half his groups out 70 m left, half right, then the hand picks
ANOTHER group by its key every 1-3 s, aims and clicks; his hand stays on the mouse, drifting 0.6 s of each second; his eye waits
up to 1.5 s for the view to reach the squad and stop panning before he aims) on 12801-12812 Terminus, 12813-12824 Locks,
12825-12836 Crossing, 12837-12848 Gorge (48 an arm); ATTACK (round 41's autoplay; the same eye wait) on 12801-12812 Terminus and
12825-12836 Crossing (24); AMBUSH (lanes by seed % 3) and RETREAT on Terminus 12801-12824 (24 each). The eye wait is a WORKLOAD
choice made after dev reads (a player does not click while the view sweeps); clicks aimed while a pan ran are REPORTED.
**Deciding (his two notes, SPLIT + ATTACK pooled; CameraLook):** D1 seconds his selection's middle is > 30 m from the look point,
% of play: ARM <= BASE and ARM <= 10 % (the ratio reported; a 0.6 x ratio was drafted and dropped after the dev read showed
0.74 x at n = 8, said here so nobody reads it as a fresh line). D2 a new selection > 20 m off when picked -> within 20 m (never =
10 s): ARM mean <= 1.0 s AND <= BASE; ARM p90 <= 1.5 s. D3 such selections never framed: ARM <= BASE.
**Guards (what it could break; Bar C1's lines):** G1 driving with half+ of his selection hidden by a building: ARM <= 1.1 x BASE
+ 5 s. G2 none of his selection on screen: ARM <= BASE. G3 hits on his units off screen: ARM <= BASE + 1 point. G4a no automatic
source but 'select' over BASE's worst + 0.5 jerks/min; G4b snaps from any automatic source but 'select' = 0 (the pan's own
reported); **G4c a pan, not a cut** (the orchestrator's ask): the view's own fastest move <= 4.5 view-heights/s, and seconds
over 4.5 <= BASE + 1. G5a clicks on the aimed unit >= 70 %; G5b slip p95 <= 40 px; G5c held <= BASE + 2 points. G6 action share
>= BASE - 5. G7 inside a solid <= BASE + 1 s/run. G8 the rear-ambush turn: AMBUSH rear lane and all lanes, first shot -> on screen
mean (never = 20) <= BASE + 1 s, blind % of fire <= BASE + 2; RETREAT the same + facing the wall <= BASE + 5. G9 every run ok and
staged, no SCRIPT ERROR. **G10 the laptop (C47.10):** UHD 620, laptop preset, under the lock, the rig's ms per frame mean <= 0.5 and
the planner step p99 <= 1.5 ms (Bar C1's G8; the rule adds one vector length a frame).
**Judge:** `python3 tests/camera/bar_k.py ~/camera-r47/bark --budget-ms <mean> <p99>`. **Also reported (not lines):** his four
recordings before/after under THREE hand models (K5: `make camera-replay CAMK_HAND=model|rest|busy`).
**If it fails** (C47.2): in player terms, what he would see ON v OFF, to the orchestrator the same hour.

### Dev reads before Bar K (7001-7004 Terminus, 90 s, split + attack + ambush, builder3; never a bar; `tests/camera/bar_k.py`)
Each read failed a guard and changed the rule or the workload BEFORE any 128xx number (BASE = `--camera-select-pan=off`):
| Tree | What failed | Change |
|---|---|---|
| ebfc3b162 | clicks on the aimed unit 82 -> 60 %, slip p95 33 -> 173 px, hits off screen 1.2 -> 12 % | the pan ended within 3 m of a point that moves with every yaw step: it never ended. -> starts/ends on a gap, max 1.5 s |
| 0927ea3e0 | 'planner' jerks 1.7 -> 7.3/min | the pan ended at full speed. -> ends once slowed |
| 4f12af25e (+ `--camera-sel-bound=0`) | bound ON: rear ambush 1.4 -> 6.3 s, hits off screen 2.7 %; bound OFF: both = BASE | **K3's bound parked OFF** (dev knob): it clipped the planner's wide frame of the contacts |
| db75ab282 | planner jerks 5/min, snaps 157 | the urgent pan lifted the hand's pace from the yaw: turns at 45 deg/s under his hand. -> the pan moves the look point only |
| 8db2073c1 | slip p95 182 | the gap was to the selection's MEAN; a spread army's mean is far from a right look: re-fired every 1.5 s. -> gap to the planner's point |
| fcc37974a | (workload) the autoplay's BASE was 3.3 % far v 26-42 % in his replays: its hand sat idle after a key | split's hand stays on the mouse (the K1 model); his eye waits up to 1.5 s for the view before aiming (both arms) |
| b9e28935b | 20 of 29; 13 clicks aimed while a pan ran, slip p95 152 | the eye waits for the pan to end (both workloads, both arms); only the pick's own pan ignores his aim, a later start waits for him (63429985c) |

### K2/K3: one rule (`RtsCamera._pan_urgent`, `select_pan`, ON)
The planner's own rule is now the gap between where the view looks and where the planner wants it: a new selection (or a
re-pick: `take_vision`) pans at once until the look is within 3 m (PAN_ARRIVE_M) of the planner's point; a look that falls 20 m
(PAN_START_M) behind with no hand on the camera since the selection is caught up the same way (K3: "didn't correct"); while it
pans neither the aim hold nor the hand's pace applies. The pan is a critically damped spring (omega 7.5, from rest, no step in
speed) capped at **4 view-heights/s** (260 m/s was tried first: ~8-13 heights/s at his 50 m, a jump cut; at 4 a frame moves 1/15
of the screen at 60 fps, 1/7.5 at his laptop's ~30: it reads as a fast pan). Replays: a far selection within 20 m in median
0.3 s, max 0.73. His own pan stays his until he selects (no swing back). **K3's bound:** the planner's point is held within 20 m
of his selection's middle (`RtsCamera.bound_to`) -- **PARKED OFF** after the dev read (it hid the contacts); K3 ships as the drift
correction alone: a selection whose frame falls 30 m behind, with no hand on the camera since he picked it, is caught up once he
is not aiming. Tests: tests/test_camera_select_pan.gd
(green at 92a0da143, builder3 `make quick` 258/0; K3's test added after).

