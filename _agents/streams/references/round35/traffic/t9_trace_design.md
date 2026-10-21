# T9 (R35.12): why a crew that gave way once refuses every later ask, and the design (no code before the joint bar)

**Trace.** `lab/t9-trace-w1c` `e2bea96f2` = manoeuvre's W1c trace tree `ec991cf7f` + a measurement-only print of every ask
(`T9_ASK`), every give-way start (`T9_YIELD`) and end (`T9_END`). builder0 light lane, GDScript (`--brains-off=native`), W1c ON
(`--nav-off=stallintent`), hull-rest law `faced_attack_move` seed 605, n 1. Log: `build/light/.../law-faced_attack_move-605/run.log`.

| frame | event |
|---|---|
| 256 | Green_Eyes_4 (on a move, pinned) asks Green_Eyes II_5 (another squad's scout, **arrived, stop**). II_5 gives way: `spot(-3,6)`, a 6.7 m run. |
| 334 | Eyes_4 asks again (W1c's `pinned` ask); II_5 is mid give-way (`yield_to` set): refused, as designed. |
| 435 | II_5's give-way **ends on the 6 s clock** (`left_s` 0, `held_s` 3.5 at its spot, 1.4 m from the point): Eyes_4 never got past (5.1 m centre to centre, still under way, pinned by other friends). `_end_yield` records `_last_yielded_to = Green_Eyes_4`. |
| 676, 941, 1395 | Eyes_4 asks II_5 again: **refused every time by `asker == _last_yielded_to`** (II_5 arrived/stop, `last` = Green_Eyes_4). |
| 2003 | The same with II_7 (gave way to Eyes_4 at 1306, its give-way ended on the clock at 1485, refuses at 2003). |

**The mechanism.** `ask()` opens with `if yield_to != "" or asker == _last_yielded_to: return false`, and `_last_yielded_to` is
written at the end of EVERY give-way and only ever overwritten by a give-way to someone else. The rule was built for two MOVERS
taking turns (`_negotiate`: "it gave way to me last time: my turn"). For a PARKED crew it is a once-only rule: after one give-way
it never makes room for that asker again, however that give-way ended. (Manoeuvre's native read saw a 2.4 m give-way; this
GDScript read a 6.7 m one: the spot differs by path, the lock does not.) It is the same lock parkedroom v2–v4 removed for parked
crews (round 33–34, parked with parkedroom for other reasons).

## T9's design (judged jointly with manoeuvre's W1c)

`--traffic-on=yieldfit2` (DEFAULT_OFF until judged; the name `yieldfit` is taken by the nav switch):

1. **A give-way that did not do its job does not count as done.** In `_end_yield`, the give-way is UNFINISHED when it ends
   without the asker having passed (the `passed` reading right_of_way already makes: asker gone, beyond YIELD_CLEAR, past my
   line, or stopped) AND I am still in the asker's way: box gap to the asker ≤ `YIELD_CONTACT_M` (1.0 m) OR my centre within
   r(me) + r(asker) + YIELD_LINE_MARGIN of the asker's travel line ahead of it. Then `_last_yielded_to` is NOT written (counted
   `yields_unfinished`), so the next ask is honoured and searches spots from where I now stand.
2. **A cap against a shuffle:** at most `YIELD_RETRIES` 2 unfinished give-ways to the same asker in `YIELD_RETRY_WINDOW_S` 30 s;
   the third ends as today (recorded), so two crews cannot trade places forever.
3. **Unchanged:** a FINISHED give-way still records `_last_yielded_to` (two movers still take turns); the battery rule; T7's
   under-fire gate (a crew under fire with the asker having a lane still refuses first).

Native: `_end_yield` and `ask()`'s first line run natively (`drive_native.cpp` ~1863, ~2480): mirror needed (two reads and a
counter). W1c is manoeuvre's half: the pinned asker asks again; T9 makes the asked crew answer.

**Bar (draft, for the joint W1c + T9 series):** the stuck-asker cells (hull-rest law/gangs × faced_attack_move and the other
tasks, fresh seeds) plus fights: G = crews ending > X m off goal / wedged-with-a-live-move seconds (manoeuvre's W1c line);
guards: yields started a fight (≤ base + k·se: no shuffle storm), friendly contacts, far loops, stuck/open/jam deaths, kills.
Reported: `yields_unfinished`, retries capped.
