# N7: the k-turn planner's size (builder0, headless, throwaway laps on `local/native-laps-kturn`, never merged)

`make native-tp-headless NATIVE_TPH_FLAGS=--native-drive-profile` (Sumps, 25 a side + leaders, 8-20 s, seeds 92721
31337 5988; d1596ed7 + laps in Movement._planned_reverse). `kturn-split.txt`: per tick, 4.5-4.9 calls stop at the cheap
check (too close / under KTURN_MIN_ERROR_DEG: 0.02 ms), 0.6-0.8 sweep the arc and find it clear (0.07-0.10 ms),
0.2-0.3 sweep and hit (0.016 ms): the planner's GDScript is ~0.13 ms a tick in all. The drive profile's
"planned_reverse 6-10 us a drive" is the timer round the callback averaged over drives, and overstated what porting
can remove. A native pre-check would remove ~83 % of the crossings (~5 a tick, a few us each); porting the whole
planner (arc sweeps over the navmesh, easing, legs) at most ~0.1 ms. Not worth building.
