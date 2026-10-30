# Bar A6 v5 (round 46, manoeuvre M3): the street hold decided on where the SQUAD is going — FAILED as filed on guard 2b alone

Frozen tree **258ce00f0** (stream/manoeuvre: the squad way = the transit route's nearest segment, or on a drill move the crew's own
path to the squad's destination; the cache as static scratch); check builder0 `>> remote: make check exited 0`, 3475 passed / 0
failed, sim-baseline unmoved. Arms BASE (today) v ARM-W `--traffic-on=holdway`, native ON (the street hold is Traffic's GDScript, read
by both drives: native's confirmation). Seeds 12049-12072 (hold probe, 75 s; odd side-street, even head-on) and 12073-12096 (Bar E1's
probe). Series builder0 light 04:33-04:38 PDT 2026-10-30. Filed in streams/manoeuvre.md, recorded on main 3098180d3; no amendment.

| Line | Read | Verdict |
|---|---|---|
| Floor: side seeds with a verdict in BASE (>= 8 of 12) | 12 of 12 | MET |
| Deciding: side jam_s ARM < BASE by >= 2 se AND pooled | 397 -> 34; -30.25 s a run, se 5.50 (z -5.50) | PASS |
| 1 off_arrive_s (side 12) <= +2 se | -1.50 (z -0.34) | PASS |
| 2a verdicts (head-on 12) within +/- 2 se | 12 -> 12 | PASS |
| **2b held_on_s (head-on 12) ARM <= BASE + 2 se (one-sided)** | **498 -> 868; +30.83 crew-s a run, se 12.33 (z +2.50)** | **FAIL** |
| 3 contacts_mouth (24) <= +1.645 se | 720 -> 580 (z -1.14) | PASS |
| 4 contacts_far (24) <= + max(1.645 se, 2) (A6 v4's miss) | 47 -> 10; -1.54 a run (z -1.50) | PASS |
| 5 last_a_s (24) <= +1.645 se | +0.54 s a run (z +0.29) | PASS |
| 6 Bar E1's lines (12073-12096) | every line identical (stuck 65.6 = 65.6, first hit 3.34 = 3.34, deaths 37 = 37) | PASS |
| 7 check / 8 SCRIPT ERROR | exited 0 / 0 | PASS |

**Reading:** on head-on meetings the waiting squad's crews are held longer in total (crew-seconds), yet the passer's far crews
brush them far less (47 -> 10) and the waiting squad's last crew arrives no later (last_a +0.5 s, within noise): the hold now
keeps crews back that today's nose read released early into the passer's path.
