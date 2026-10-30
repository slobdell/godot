# Bar G2 THE GROUP GUARD: the series (round 45, orders) — FAIL as filed (R45.31)

**Tree:** frozen 03d1ddbc5 (stream/orders; worktree `godot-orders-g2`), its full check builder0 20:31-21:17 GREEN ALL JUDGED 3452/0.
**Machine:** builder3 (devia@builder3, Ryzen 9 9950X, 32 threads, judged, no Spot), 8 jobs, 23:16-00:26 on 2026-10-29/30, after
builder2's Spot preemption lost try 1 before any row (a machine change before any number). **Arms:** `base:--group-guard=off`
(today's lay) v `g2:` (the tree's default, the guard ON). **Seeds:** part A 11201-11224 (n 24 a cell, 1728 runs + the recorded
cell 48), part B 11225-11236 (384 + his Terminus click 48), part C 11237-11248 (48 fights). **Judge:** `tests/control/orders_g2_judge.py`
as frozen (`verdict-frozen-judge.txt`) and with R45.25's report-only columns (`verdict-r45.25-columns.txt`, this branch's judge over
the same rows). The rows: `~/orders-r45/bar3/` on the laptop (geometry 13 MB, streets 2.6 MB).

## Verdict: FAIL (A guards False, B False, C True); `--group-guard` stays OFF on main

**Every deciding line PASSED on fresh seeds:** D1 nobody across a gap (0 places in 1728 arm runs, base 0), D2 nobody sent back,
D3 every moved place within the body's reach, D4 the fallback never taken on Gorge, D5 every held squad within reach + a rank step,
**D5b his exact Gorge click with his three squads at their recorded starts: nobody held, D1-D4 and D6, 24 of 24 runs**, D6 on his own
click nobody behind its start. Contacts (part A) 32293 -> 23190 PASS. Part C fights PASS (his kills / losses / the CPU's within se).

**What failed, in his terms:**
1. **Part B, the streets (G1 v9's own lines; not an R45.25-exempt kind):** on the Crossing / Terminus / Locks street clicks with 3 and 5
   squads the fitted file lays its rear ranks on the straight approach line, not the road, so on a bending street they leave it:
   places outside the street corridor 7 -> 33 (line <= 1.8), metres driven outside it after being in it 430 -> 1934 (<= 215), friend
   contacts 11251 -> 17804 (<= 12381), 14 probe-guard cells, Terminus all-in 11.7 -> 47.4 s. He would see squads parking on the next
   street over and bumping each other to get there: R44.23's cause 2 again.
2. **Part A guards:** all-in on five reach-80 cells and his round-43 Locks click (base's lay leaves squads at their feet or close by;
   the file forms 56-100 m away and the last squad arrives after the departure queue: e.g. Locks -62/50 27 s v 6 s, base moved 2 of 4
   there, so not R45.25's exempt kind); never-in one squad in 1-7 of 24 runs on four cells (the squeezed file's rear squad jostling
   at the back, its halt coil over the rank ahead's); the held guard on locks along-80.

**Round-46 note (D3's print):** cell lines read "farthest moved max 124 v reach 58 + 6" while D3 PASSED: the line pairs the MAX of
one column with the MEDIAN of another across runs; per run the farthest moved place equals that run's own reach exactly (124 v 124,
150 v 150, 92 v 92; checked over gorge his-80, terminus his-80 / along-80 / his-20). D3 does NOT exclude restored places.

**The orchestrator's recommendation for him (R45.31):** a VETO-only guard first (keep today's lay unless it puts a squad across a gap
or behind its start: exactly his Gorge case, no change on streets), the street-aware file after.
