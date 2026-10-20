# W1c: brains' E1 long attack-move wedges, traced (round 35, manoeuvre; the orchestrator's relay)

builder0, native (NATIVE_EXEC in the logs), stream 58395b79c = main 0f4d528d7 (the scout turn-in shipped) + manoeuvre's OFF
switches; `make native manoeuvre-hull-trace` (one hull-rest cell under tests/manoeuvre/wedge_trace.gd, the crew every 0.5 s).
Timelines: `law605_timeline.txt`, `law607_timeline.txt` (`tests/manoeuvre/wedge_tick_timeline.py`); raw rows `*.jsonl.gz`.
(The `fires` column is Movement.unstick_fires, a STATIC game-wide counter, not the crew's own.)

- **law-605 Green_Eyes_4** (scout): still wedges on 0f4d528d7, so the turn-in neither removed it nor moved it. From t ≈ 10 s to the
  judge (80 s) it sits at (-8.1, 99.6), 34 m off its move goal, `blocked` by Green_Eyes II_5 and touching it; route driver,
  ORCA pace 0.05 → throttle 0.05. **Green_Eyes II_5** is parked (another squad, `stop`, arrived). It gave way once (t 8.5–13), but the
  yield drove it only 2.4 m, to (-4.7, 100.9), still touching Eyes_4 and still across its route. After that nothing asked again.
- **law-607 Green_Guns_6**: the same shape. From t ≈ 24 s, 23 m off its goal, in a pack of 8–9 friends, `blocked` by Green_Hunters_2,
  touching Guns_5, ORCA pace 0.09 → throttle 0.09.

**Mechanism:** unstick's stall rule needs |throttle| > 0.5 (driving hard, not moving). ORCA throttles a routed hull to ~0 against a
friend it is touching, so the command is tiny while the drive's intent is full: the stall clock never runs, H1's escape (ask, reverse,
stand) never starts, and the parked crew is never asked again. **W1c proposal (to the orchestrator, not built):** for a routed move
in contact with or blocked by a FRIENDLY hull, the stall rule reads the drive's intent (|throttle| / pace); every other case keeps
today's gate; the escape is H1's. Traffic's half: a give-way that ends with the yielder still touching the asker isn't done (yieldfit).
