# T9: a give-way recorded FINISHED while the asker is still pinned nose-on (manoeuvre's X4b trace 1). Read + design note

**Source:** manoeuvre's trace `references/round36/manoeuvre/x4b/trace_condemned-6325-Green_Battery_2.txt.gz` (stream/manoeuvre
`5bf752b4f`; main `a318a2cd3`, builder0, native, condemned-6325, byte-identical to the series row). Read on the laptop, no new fights.

## What happened

Green_Battery_2 (artillery, hull 8.20 m long) is nose-on to Green_Guns_2 (tank, hull 9.70 m long, unseated, order stop), at
(-5.7, 101.2) v (1.0, 95.2): **centre distance 8.99 m**. Guns_2 gives way from ~f 1020 (cmd 0.70, real 0.0–0.2: no room behind,
room_back 0.0). By f 1050 it has crept 0.1 m, to (1.1, 95.2): **centre distance 9.07 m**. Its give-way runs to the 6 s clock
(~f 1200) and ends. T9's `_yield_unfinished` reads the asker as **passed**, because `_flat_distance > YIELD_CLEAR` (9.0 m centre to
centre), so `_last_yielded_to = Battery_2` is recorded. Every later ask of Battery_2 is refused (H1B_FAR f 1471: gap_m 9.0,
`blocker_last_yielded_to` Battery_2, `blocker_unfinished_count` 0).

**The cause:** YIELD_CLEAR is a centre-to-centre distance, and **two long hulls touching nose-on are about as far apart as it
is**: 9.70 / 2 + 8.20 / 2 = **8.95 m**. Any creep reads as "passed". The same 9 m test is in `_tick_yield`'s `passed`, where it
only allows the end (the give-way still ran its clock here). In `_yield_unfinished` it decides whether the give-way is recorded,
and here it recorded a give-way that freed nobody. T9's own geometry would have said unfinished: the guard returned before it.

## Design (no code before the orchestrator's go; native mirrors `_yield_unfinished`)

In `_yield_unfinished` only (T9's reading, not `_tick_yield`): passed-by-distance becomes a **gap**, not a centre distance. The asker
is clear when `distance − (my half-length + its half-length) > YIELD_CLEAR_GAP` (2.0 m), or when it is past along `_yield_dir` or
not under way, as today. Half-lengths, not disc radii, because the failure is nose-on, where the disc reach (6.4 m here)
under-reads the contact by 2.5 m. Effect: a pinned long-hull pair is unfinished (T9's 2 retries, then the cap records as today), so
the third case of X4b's (A) behaves like the other two. It **frees few on its own** (7 of 10 parked blockers have < 1 m room
behind). It only makes T9 do what it was built to do; manoeuvre's H1b side-point re-drive is the fix that frees them.

**Test first:** `test_traffic_yieldfit2` gets a nose-on long-hull pair (tank 9.70 m + artillery 8.20 m, centres 9.05 m) with the
giver unable to move: unfinished with the fix, recorded today.
**Bar:** a guard read on T9's lines (jam_ab `--any-arms`: jam-under-fire, jam:yielding, give-ways started ± band; yields_unfinished
reported), plus manoeuvre's left_behind (A) count, on fresh seeds. It's small, so it could ride with manoeuvre's H1b pair if the
orchestrator prefers one series.
