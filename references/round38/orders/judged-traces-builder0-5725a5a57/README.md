# Traces of the two failing judged cells (orders, round 38)

- Machine: builder0 light lane, J2. Tree: 5725a5a57, which carries ab31e9bc2's game code.
- Workload: `make native orders-probe` with `--probe-trace=2`, which logs squad 2's crews every second.
- n: 1 seed each. Each subfolder holds the raw logs for both arms.

## g1-s4710: Bar G1 v4, crossing 3 click, never-in

- **Where Bravo was sent.** The column sends squad 2 (Bravo) to the head of the street, at anchor (-75.4, 45.4).
- **Where Alpha parks.** Squad 1 (Alpha) gets the nearer place, anchor (-43.1, 86.2). It arrives at 3.3 s and parks in the
  street on Bravo's way; its crews end 32 m off their seats.
- **How Bravo stalls.** Bravo's crews queue behind it from t=8 to t=14.
  - Two of them get through.
  - Bravo_1 wedges at (-60.2, 81.5) and is still on its MOVE order at t=90. Its goal (-65.8, 45.1) is 36 m away.
  - At the end, an Alpha crew is 8.8 m off it (end_foreign_m 8.8 on both squads).
- **Main never hits this.** In main each squad drives its own lane.
- **The cause.** A nearer squad parks across a farther squad's way, and parked crews never give way. That is the same gap
  as the bridge mouth (the round-39 seat/give-way item).
- **G1's share.** The column hands the far places to squads that start behind the near ones. Ordering the column so the
  squad whose crews lead takes the far place, or holding the near squad until the far one is past, is orders' own fix.

## g3-s5201: Bar G3 v5, crossing 3 route, twitch

- **What G3 moved.** G3 moved squad 2's final halt off squad 3's, from (-73.8, 33.4), which was 3.6 m off squad 3's
  (-71.2, 30.9), to (-60.5, 42.3).
- **What happened after arrival.** The crews arrived, and at about t=24 the deploy re-seated them.
  - Bravo_1's seat moved from (-51.4, 38.3) to (-61.7, 51.9), and it drove for another 20+ s.
  - Squad 2's twitch: 23.0 m, against main's 0.0.
- **The other seeds.** s5204, 5208, 5209 and 5212 show the same squad-2 twitch, 16-21 m.
- **The cause.** The moved place passes standable/clear but does not hold the squad's seats, so the deploy re-seats after
  arrival.
- **Next try.** Accept a cleared place only where the deploy would seat every crew without re-seating (the ground-cap
  check), or step it back along the squad's own leg.
