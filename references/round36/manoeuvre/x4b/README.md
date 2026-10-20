# S2 / X4b: the crews left behind, after the joint (CP36.1). Read, traces, design note

**Run:** builder0, native, main `a318a2cd3` (the joint W1c + T9 ON; adoption `e45bb6632` changed only baselines), one arm
(main's defaults). hull-rest drawn, `faced_attack_move` + `faced_move`, FRESH seeds 6301–6332 x gangs/law/syndicate/condemned =
256 runs, `--turn-states --element-trace=all`. 4/4 `make remote` exited 0, 256/256 runs. Reader: `tests/manoeuvre/left_behind.py`
(Bar E1's (c) definition via `tests/tactics/e1_bar.py`; each crew named by NET motion over its last 10 s, brains' X4a rule) →
`left_behind_a318a2cd3_builder0.txt`; `tests/manoeuvre/h1b_far_last.py` → `h1b_far_last_rows.txt`.

## The read

| | n |
|---|---|
| crews > 25 m off their slot at the element's last row | **29** in 256 runs (attack-move 21, move 8) |
| of those, still (net < 1 m in 10 s, a move held, goal > 5 m) | **17** (14 at ~0 throttle, 3 pressing) |
| closing / wander | 6 / 6 |

Round 35's Bar E1 new arm read 17 left, 9 wedged in 128 runs (different seeds, and "wedged" by real speed there): per 128 runs
that is 17 / 9 then against 14.5 / 8.5 now. **The joint did not free the left-behind crews in the aggregate.** (Not a paired A/B:
this is main's census on fresh seeds.)

## The worst three, traced (byte-identical MANOEUVRE_STATE rows to the series; `trace_*.txt.gz`: STALL_TRACE every 5 ticks + H1B_FAR)

1. **condemned-6325 Green_Battery_2** (artillery, 58.7 m behind). Nose-on to Green_Guns_2 (unseated, order `stop`, arrived).
   H1 fires every ~7 s: it asks, stands ~2 s, backs ~2 m, re-drives into Guns_2. Guns_2 gave way ONCE (f ~1020–1140, throttle
   0.70, real 0.0–0.2: it had nowhere to go), the give-way was recorded as FINISHED (T9's unfinished count 0), and
   `Movement.ask` refuses every later ask from Battery_2 (`asker == _last_yielded_to`). H1b's far branch (goal 56 m) counts
   and does nothing.
2. **law-6310 Green_Guns_8** (law_tank, 50.8 m). Head-on to Green_Guns_6 (another element, itself driving west to its slot,
   itself in an H1 loop). Guns_6 gave way to Guns_8 unfinished twice (T9's retries), reached the cap, recorded → every later ask
   refused. Both hulls loop to the judge.
3. **condemned-6318 Green_Burners_6** (burner, 49.0 m). Nose-on to Green_Guns_4 (unseated, `stop`, arrived, room behind 0 m;
   Burners_6's room behind 0 m). Guns_4 gave way unfinished 3 times (T9 cap), recorded → refused for the rest of the run.

## Mechanisms, each with its count (the 17 still crews)

- **(A) Refused forever after a give-way that never cleared the asker: 10.** H1B_FAR's last row: the blocker's
  `_last_yielded_to` IS the asker (the once-only rule in `ask`). By T9's state on the traced three: 2 reached T9's retry cap
  (YIELD_RETRIES 2 in 30 s, then recorded as today), 1 was recorded as finished though the asker was still pinned. Blockers: 8
  unseated/arrived (parked, order stop or face), 2 another element's crew. In 7 of 10 the blocker has < 1 m room behind: a give-way
  has nowhere to go.
- **(B) The blocker is busy yielding to someone else: 1** (law-6303 Guns_6 on Guns_5, which yields to Guns_6's squadmate).
- **(C) No H1B_FAR row (no hull-pinned far loop): 6.** 3 at ~0 throttle without an escape (law-6310 Guns_7, gangs-6309 Hunters_5,
  law-6332 Eyes_1 at its last row 29 s), 2 pressing (gangs-6303 Guns II_3 thr 0.96 with NO escape and the clock at 0: the
  stallnet candidate; condemned-6317 Battery_9 thr 0.90), 1 artillery beside a moving squadmate. Not traced yet.

## Design note (to the orchestrator; no bar until the go)

What the player sees: a crew pinned nose-on to a parked friend backs a couple of metres and drives back into it every ~7 s
for a minute or more while its squad goes on. The parked friend tried once (or T9's twice), had no room, and now refuses.
Nobody goes round.

- **(1) Mine (the asker's side, H1b's far branch, `unstick`):** after H1B_ASKS refused asks on the SAME friend that has not moved
  (> 0.5 m) and the goal is far (H1b's far case, today a counter only), stop re-driving the same line: the escape's re-drive aims
  at a SIDE point clear of the friend (the outline sweep H1 already has, `_hull_within` / the yield spot search reused from the
  asker's side), so the hull goes round when there is room; when neither side has room, it stands (no loop) and the element's
  straggler release (E1) carries the squad on. Native mirrors the step. Expected effect: the 10 (A) crews either get round or
  stop rocking.
- **(2) Traffic's (the asked side, `ask` / T9):** let a parked crew give way again to an asker that is STILL pinned on it after an
  H1 escape (via "pinned") once its own room has changed; today's cap exists to stop shuffling forever, and in 7 of 10 the parked
  crew has < 1 m to give, so this alone frees few.
- **Recommendation: (1), on my side, behind a switch, judged by a deterministic lab stage (a hull H1-looping on a parked friend in a
  street with room on one side: ON goes round within N s; one-hull street: ON stands instead of looping) plus the series guards
  as Bar S1's.** (C)'s pressing crew (gangs-6303) is traced next to see whether S1 already covers it.
