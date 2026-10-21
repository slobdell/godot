# S4: orders' LOOP squads (a crew driving 10 m or more AWAY from its own order goal): traces, split by driver, design note

**His words (game_design.md):** "the feel of the game needs to have the user perceive that the units are smart and under their
control"; "the general priority is to mitigate vehicle contention with one another".

**Run:** builder0 light lane, at orders' commit `55c973cd4` (the count's own commit) plus probe-only commits on `lab/s4-trace`
(`3aa5a5042` TRACE_FLAGS, `e9abeafdd` hold rows, `51a8b41b2` / `b3ac4b34c` / `c5fedd42c` the away-by-driver probe v1-v3: measurement
only). GDScript path (`--brains-off=native`), because the native execute step skips the census. **away_m reproduces orders' native
numbers to the decimal** (32.4, 67.8, ...), so the paths agree. The 16 runs cover 16 of orders' 19 LOOP squads; the 3 left out share
a run with a covered squad. Reader: `tests/manoeuvre/s4_away.py` → `s4_away_55c973cd4_builder0.txt`. Traces: `trace_*.txt.gz`.

## (1) The two named cases: neither is the drive's turn rule

- **Locks 3 click s3624, Bravo_1 (ifv), traffic's STREET HOLD (T1).** It stands 4 m from its seat (−3.6, 18.4), nose south.
  The hold verdict gives it the spot (−5.1, −16.8), 35 m away across the lock (Traffic.holding f 665–1110). It drives there at
  ~9 m/s, waits, is released after ~15 s, and drives back. Of its 32.4 m away, the hold drove 31.5 m.
- **Terminus 5 route s3623, Bravo_4 (scout), a GIVE-WAY.** Its seat (−7.5, 68.5) is ~13 m behind it. A planned k-turn reverse leg
  backs it into Green_Alpha_2 (f 860–900). Alpha_2 asks, and Bravo_4 gives way (phase yielding, f 905–1010): ~22 m south at up to
  9.6 m/s. The route law then turns it round on its wheels and drives back (another ~14 m away first). Of its 67.8 m: yield 39.5,
  route after the yield 14.1, a fresh route 10.6.

## (2) Every looping squad, metres driven away from the goal by driver (the worst crew of each squad)

| driver | metres | |
|---|---|---|
| give-way (phase yielding) | **196** | traffic's give-way block |
| route law after a give-way, hold, k-turn or escape (≤ 5 s before) | 96 | mostly the way back after a give-way (77) |
| route law, FRESH (forward 94, reverse 6) | **100** | the turn-around S4 was filed for: mine |
| k-turn legs | 39 | mine (the reverse leg is what met Alpha_2 above) |
| street hold | 32 | traffic's T1 (one case) |
| H1 escape | 9 | mine |

Largest driver per worst crew: **give-way 11 of 16**, fresh route 3, hold 1, escape 1.

## (3) The give-ways (traffic's T10): the yielder's distance to its own seat, and whether the asker had a way round

172 give-ways begun by any crew of the 16 looping squads (whole runs). `seat_m` = the yielder's distance to its own seat at the
ask (its move_to goal, else the slot its face keeps to). `lane` = T7's pass lane (`_pass_lane`) for the asker, read at that
moment: the asker's hull swept on either side of the yielder.

| yielder's distance to its seat | give-ways | sent to a spot >= 10 m from its seat | T7 lane for the asker |
|---|---|---|---|
| <= 5 m | 90 | 22 | 17 |
| 5–10 m | 34 | 22 | 5 |
| 10–20 m | 35 | 30 | 7 |
| > 20 m | 13 | 13 | 1 |

- **(a) 124 of 172 (72 %) yielders were within 10 m of their seat when asked; 44 of those were sent >= 10 m from it.** Of all 172,
  84 yielders stood on `stop` and 15 on `face` (parked crews that had arrived); 73 were still on a move_to.
- **(b) The asker had a T7 lane in 22 of the 124 (18 %), and in 8 of the 44.** So in most cases the asker could NOT have passed
  on another side by T7's sweep. The street is one hull wide there, and a parked crew in it has to move for anyone to get by.
- Spots chosen: `spot(10,0)` 35, in place (`hold`) 31, `spot(5,-9)` 14, then the near ones; `spot(16,0)` 7, `spot(24,0)` 3,
  `back(6/10)` 12. The far spots lead the way out AHEAD of the asker along its line, so the yielder ends up further from its seat.
- **What he'd see:** a crew already parked on its seat, asked to move, drives 10–24 m up the street ahead of whoever asked, then
  turns round on its wheels and drives back (the 77 m of "route after a give-way").
- **Options for traffic (theirs to choose):** score the spots by the distance to the yielder's own seat, not only nearest-first,
  when it is within ~10 m of it; let a seated crew step aside and come straight back (reverse) rather than leading the asker out;
  where T7's lane exists (18 %), refuse and offer the lane even when not under fire.

## (4) My share: a fresh turn-around away from a goal behind the hull

10 fresh route episodes of >= 5 m in the looping squads' crews (v2's `S4_EP`). Each goal lay **130–180 deg off the nose**, 0.2–29 m
away. Each hull drove **5.4–11.1 m away** (the reading is a few ticks short) before turning back: 4 ifvs, 5 scouts and 1 tank. 4
were already moving (3–13 m/s) when the goal fell behind them; 6 were near rest. In player terms: told to a point a few metres
behind it, the vehicle drives off the other way for 5–11 m, turns round and comes back. A smaller version of what he described,
and it's mine.

**Proposal (S4, behind its own switch, OFF until judged): "back in".** A hull on a move_to (not `reverse`, not paced in an element
drive) whose goal is the route's last point and is within REVERSE_IN_M (15 m) and more than REVERSE_IN_DEG (120 deg) off its nose
drives the order in reverse (the `reverse` drive law it already has, wheels and tracks), if the hull's outline is clear along the
straight reverse to the goal (the k-turn's swept outline, the same check native already mirrors). It never runs during a give-way,
hold, escape, k-turn leg or S2a's side step. A moving hull's reverse throttle brakes it first. Reaching the goal ends it, and so
does the goal moving beyond REVERSE_IN_M or out of the cone. The face at rest then turns it to its facing, as today.

**Lab stage (deterministic, the deciding line), filed with Bar S4 before any number:** one hull (ifv, scout, tank) at rest, nose
north. Its goal is D in {7, 10, 14} m behind it, at {0, 30, 60} deg off its tail, on open ground and in a lane two hulls wide
(walls each side). Read per cell: **away_m** (orders' measure: the most metres beyond the starting distance), the loop's length
(path driven / straight distance), time to seat, wall contact ticks.

## (5) Bar S4 (filed before any number)

- **Deciding (lab):** ON away_m <= 1.0 m in every cell where the rule fires, and ON path <= 1.3 x straight + 1 m there. Base
  printed beside. A cell where the reverse sweep is blocked must decline (ON = base to the bit).
- **Lab guards:** ON arrives in every cell; ON time to seat <= base + 2 s per cell; ON wall contact ticks 0.
- **Native:** the default arm = GDScript (drive twin), as for S1 / S2a.
- **Series (after S1's and S2a's, fresh seeds, both arms):**
  - Orders' probe (12 street cells x 6 fresh seeds): the LOOP squads' fresh-route metres not up (the reader above); all squads'
    away_m and twitch_m not up (paired, 1.645 se).
  - **Friendly contact ticks not up (the lead's priority).**
  - Arrivals not down.
  - S1's movement guards (hull-rest movers by net motion, never settled, squads arrived; fights' deaths / kills / hit rate,
    far loops, unstick fires).
  - REPORTED: the episodes by unit kind.
- Ships ON only on a green full check with the series passing.

## (6) Addendum (v4 probe, `lab/s4-trace` M1-decision rows, same runs byte-identical): "back in" already exists, and it is M1

Building the stage found that round 26's **M1** (`Manoeuvre.choose`, `Movement._manoeuvre`) already is the proposal: once per
goal, a goal within 25 m and > 100 deg off the nose (or inside the forward circle) is simulated both ways and driven in reverse when
that is clear and quicker. So the question for my share is why M1 did not reverse in the 10 fresh episodes. M1's choice when each
episode began:

| why the forward loop ran | n | unit, goal, metres away |
|---|---|---|
| `facing_nose`: the order's facing is > 60 deg off the hull's nose, so M1 drives nose first and the hull arrives facing it | 3 | scouts: 19.4 m / 7.7, 15.5 / 6.6, 8.6 / 5.4 |
| `friendly`: another hull stands in the reverse's swept corridor | 3 | scout 7.7 m / 6.5 (at 7.5 m/s), ifv 8.0 / 8.9, tank 8.6 / 11.1 (at 5.8 m/s) |
| `route_faster`: a scout overran its goal at 13.2 m/s; the forward loop is quicker than braking and backing | 1 | 15.9 / 5.5 |
| reverse chosen; the reverse law pulled forward first (goal inside the reverse circle, 50 deg off the tail) | 1 | scout 6.5 / 7.4 |
| goal beyond M1's MAX_M (25 m) | 1 | ifv 29.4 / 9.2 |
| an element-paced station overshoot (0.2 m off the goal at 4.9 m/s) | 1 | ifv / 6.1 |

**Verdict: no new rule for S4's drive share. Bar S4 is not run.** Each piece is small (5–11 m), and most are by design:
- **facing_nose:** a vehicle told to face the way it came has to turn round somewhere; the forward loop does it on the way in.
- **friendly:** the reverse is refused because a friend stands in its path, which is the contention he asked to avoid.
- **The rest:** single cases.

The visible part is the 10–35 m sends from give-ways and holds (traffic's T10). One question is his to answer, in player terms
(below). The rest is not worth a rule on 10 episodes in 16 runs.

**Question for the lead (player terms):** *"You send a vehicle to a spot a few metres behind it and tell it to face the other way.
Should it swing round forward in a small loop (about 5–8 m out, and it arrives already facing the right way), or back straight
in and then turn on the spot?"* Recommendation: keep the loop. It is quicker, and a car turning round reads as natural. The case
that looks dumb is the 20–35 m one, which is traffic's.
