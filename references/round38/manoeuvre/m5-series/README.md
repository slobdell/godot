# M5 v2 judged series (seatstep: a seated crew's give-way avoids the asker's lead-out spots), round 38

- ON `lab/manoeuvre-r38-m5on` 269d593c5 (seatstep ON) vs BASE `lab/manoeuvre-r38-m5` 226e4c190 (OFF). builder0, native, J=6,
  2026-10-22 13:18 - 23:49 (shared with orders' G1 series, R38.8). ON check: builder2, 3,063 passed / 0 failed.
- Jam census: locks / sumps / terminus x seeds 6940-6979 = 120 paired fights. Hull-rest: 6901-6932 x 4 factions x 6 tasks =
  768 runs an arm, arms ON / BASE / BASE-on-GDScript (`M1_GD=1`, the (e) floor arm).
- Judge: `python3 tests/manoeuvre/m5_judge.py <dir> --v2` -> `judge.txt`. Bar: `_agents/streams/manoeuvre.md`, "Bar M5 v2".

**VERDICT: FAIL** on the deciding line: seat metres 76,032 -> 72,255 (-3,777, -5.0 %) < the 1.645 se bar 4,881. Every map points
the same way (locks -4.0 %, sumps -4.9 %, terminus -6.2 %). Lead-out give-ways fall 1,291 -> 747 (-544, 1.645 se 112): the rule
does what it says, but the crews still end about as far from their seats. All safety guards pass: deaths per team, (a1) kill share
(0.521 -> 0.527, bar +-0.018), (a2) total deaths (+6, bar 102), wait, timeouts, contacts, jam deaths, (f) arrived.

(e) never settled: faced_attack_move +4 > +3.3 FAILS on its number. faced_ambush (+1) and faced_support_by_fire (+3) are marked
FAIL only because the floor arm is short (126/128 and 125/128 pairs): the GDScript arm's gangs runs hit the 300 s per-run
timeout under load (7 of 192, the same few on every pass; driver STOPPED after 3 passes and the judge was run by hand on what
was there). The floor itself is D_floor = 0 on every task: GDScript and native hull-rest are bit-identical per seed (twins), so
"base v base, two paths" measures no noise. A future noise floor needs a seed-shift or a perturbation, not the other path.

Raw rows (1.1 GB) stay in `~/overnight-manoeuvre/r38/m5/` on the laptop.
