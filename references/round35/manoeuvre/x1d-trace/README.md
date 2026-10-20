# X1(d): the choke wedge. Trace and design note (round 35 extension, manoeuvre)

**Question (brains' X4a, relayed by the orchestrator):** law-716 Green_Guns_7 pushes at throttle 0.83 for 50 s with
estimated_velocity 9.98 against a real 0.32 m/s. Does unstick read `estimated_velocity` here, so `_stuck_time` never builds?

## Runs

- **The case, reproduced exactly.** builder0, native, lab/x1d-e1 = brains' E1 series tree 83b3b90b4 + this stream's STALL_TRACE
  probe (248e7495c, measurement only). `manoeuvre-hull-rest FACING_ONLY=faced_attack_move M1_ARMS=new_drawn M1_SEEDS=716-716
  HULL_FACTIONS=law`, `M1_FLAGS=--turn-states --element-trace=all --turn-trace=Green_Guns_7`. Guns_7's MANOEUVRE_STATE rows are
  **byte-identical** to brains' series log (0 diff lines). `stall_trace_law716_e1.txt.gz` has the per-5-tick STALL_TRACE.
- **The same case on today's code** (stream 248e7495c, main ed121d24f's behaviour, native, `manoeuvre-hull-one`): Guns_7 gets
  through and arrives at f 1655. No wedge.
- **How often:** `tests/manoeuvre/rocking_census.py` over joint3's hull-rest logs (builder0, native, 901–932 drawn × 4 factions
  × 6 tasks, 768 runs an arm). It counts crews with |throttle| > 0.5 on a move_to, net movement < 0.5 m over 10 s, the stall clock
  seen running, and no escape (`rocking_joint3.txt`): **base 6 crews in 6 runs, joint ON 3 in 3** (one crew a run; six classes).

## What the trace shows

- **Unstick reads REAL velocity here, not estimated.** Guns_7 is a 7.3 m law_tank (≤ UNSTICK_BLIND_MAX_LEN_M 10), and under a
  routed move_to `_honest_blocker` always returns a hull: here friendly Hunters_2 / Hunters_6 of another element. So
  `reading = real_velocity`, and the stall clock does build: 0.17 → 0.33 → … → 0.87 s in each window.
  **The premise of the question does not hold for this case.**
- **What defeats it is the reset rule.** The clock goes to 0 on any tick where real speed ≥ STUCK_SPEED (0.8 m/s). The hull is
  wedged between two friendly hulls at full throttle, and about once a second the contact pops: real speed reads 8.5–9.9 m/s for
  ONE tick (f 1780, 1810, 1895, 1925…). Net movement over 10 s is ≤ 0.1 m. The clock reaches 0.73–0.99 s and is zeroed just short
  of STUCK_SECONDS (1.0), every second, for ~50 s. H1's escape never starts (esc 0 throughout) and H1b never counts a loop
  (loops 0).
- **W1c doesn't touch it:** the throttle is already ≥ 0.83, so the intent reading changes nothing. The joint's halving (6 → 3)
  comes from T9 / W1c freeing the asks around such crews, not from this rule.

## Design note (to the orchestrator)

- **(A) The lever:** the stall clock resets on NET motion, not on one fast tick. While the clock runs, keep where the hull stood
  when it started. Reset when the hull has moved more than STUCK_NET_M (proposed 0.5 m, under a hull's width) from there, or when
  the throttle test fails, as today. A one-tick pop (≤ 0.33 m a tick) no longer zeroes a hull that has gone nowhere.
  This is brains' "count by net motion" applied inside unstick.
- **(B) Scope:** routed move_to only, the honest path only (where the reading is already real_velocity). The blind path and
  every other order keep today's rule bit for bit.
- **(C) Behind a switch,** `--nav-off=stallnet`, default OFF until judged. **Native mirrors it** (drive_native's unstick holds
  the same clock; one Vector3 member, `_stuck_from`, added to exec_fields).
- **(D) Expected size: small.** About 0.4–0.8 % of hull-rest runs, one crew each, and 3 in 768 with the joint on (which ships
  now, R35.66). A hull-rest series can't judge a gain that rare. So the deciding line should be a deterministic lab stage (a
  hull driven into a one-hull-wide gap between two parked friends of another element, native and GDScript), with series guards
  for no harm.
- **Recommendation:** low priority. Round 36, after the joint ship's numbers on main and the scoreboard (X5) show whether rocking
  crews remain. Not worth a judged series this round.

## Bar draft (stallnet), filed before any code. Not to be built until the orchestrator queues it

- **Arms:** native, two trees (pair = stream + native's mirror; base = the same with STALL_NET_DEFAULT false).
- **Counter first:** `stall_net_holds` > 0 in the ON arm: ticks where today's rule would have reset and the net rule kept the
  clock.
- **Deciding (lab, both paths):** `test_manoeuvre_stall_net`. In the pinch stage, ON fires an escape within 3 s; base never does
  in 20 s (pinned premise).
- **Deciding (series):** rocking_census crews, new ≤ base (REPORTED if base < 5).
- **Guards:** fresh hull-rest 128 pairs a task and fights on locks/terminus/sumps × 24. The joint bar's (d), (e), (f), (i), (q), (r),
  (s) and give-ways, each within 1.645 se, plus unstick fires ≤ base + 1.645 se (no reverse storm). Movers are counted by net motion
  (brains' rule).
