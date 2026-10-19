# Round 33 traffic X1: the far ask loop's census (REPORTED)

**Workload:** `make traffic-far-census FAR_RANGE=500-523 FAR_AT=terminus,locks,random FAR_JOBS=7`, builder0, tree `dc6723ed`
(main `ae3dad71` + the probe only, measurement), showmatch fights (`--skirmish --demo-match`, both CPU sides run elements,
as his opponent does), 180 s each. 72 run, 69 read (random 502 / 509 and terminus 509 timed out at 900 s on a box at load
~30). The probe: `tests/traffic/far_census.gd` (manoeuvre's H1B_FAR rows, read only, plus the blocker's state the tick each
row is written). Raw rows: `x1_far_rows.txt`; the table: `x1_far_census_table.txt` (`tests/traffic/far_table.py`).
Validation: fights 403–409 on the same probe gave round 32's six rows exactly (Green_Guns_4 on Green_Eyes II_3 x4, 54 m;
Rust_Battery2_1 on Rust_Battery_5, 19 m; Green_Battery_1 on _2, under way).

| | far loops | a match | matches with any | episodes (asker on blocker) |
|---|---|---|---|---|
| all 69 fights | 37 | 0.54 | 9 (13 %) | 13 |
| Terminus (24) | 16 | 0.67 | 3 | 4 |
| the Locks (26) | 20 | 0.77 | 5 | 6 |
| random (19: sumps, pit, archipelago, ...) | 1 | 0.05 | 1 | 1 |

| blocker kind | blocker | loops | a match | episodes |
|---|---|---|---|---|
| same_element | parked | 17 | 0.25 | 4 |
| **other_element** | **parked** | **9** | **0.13** | **3** (0.04 a match) |
| same_element | moving | 5 | 0.07 | 2 |
| unseated | parked | 4 | 0.06 | 2 |
| unseated | moving | 2 | 0.03 | 1 |

**Parked blockers (all kinds, 30 loops, ~10 episodes, 0.14 episodes a match):** where they stood: a hold post 16 loops (4
episodes); set up on a fire post 10 (3); elsewhere 4 (2). The ask's answer: **refused, "just gave way to this asker" 20**;
refused, set up and firing (T1c-b2, his yes) 10.

**The mechanism (traced, fights s403 crossing, `traffic-far-one`):** the parked crew (a scout on its hold post inside a
one-hull neck between a building and a container, `x1_crossing403_neck.png`) is asked once; `_begin_yield`'s fixed spot set
has nothing that fits (side spots off the mesh, the straight runs ahead into the building corner: dry run nofit 7,
offmesh 6, line 2, wheels 2), so it gives way IN PLACE for 6 s (the `yieldhold` fallback, which moves nothing), and from
then on `ask()` refuses that asker for good (`asker == _last_yielded_to`). The asker asks, backs 2–3 m and drives in again
every ~5 s until its order changes.

**Frequency for the orchestrator:** the brief's case (a parked crew of ANOTHER element) is **rare: 3 episodes in 69
fights (~1 in 23 matches of 180 s)**, well under ~1 a match. The same mechanism behind ANY parked crew (any element, or
none) is ~1 in 7 matches, 20 of its 30 loops the "just gave way in place" refusal.

**Side finding (brains):** a CPU squad of more than 5 hulls is refused an element (`Elements.form`, C19.1) at the start
(`skirmish_mode.gd:415`) and again every think tick once the team's elements are all gone (`element_commander.gd:180`):
those crews run unseated, and the log carries up to ~470 ERROR lines a fight (locks 506).
