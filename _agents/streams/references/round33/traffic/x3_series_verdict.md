# Round 33 traffic X3: the parkedroom series, verdict FAIL (L1, L6); ships nothing

Tree: stream/traffic `d90fbdb7` (game code = `aff64e2b`; parkedroom default OFF), arm `--traffic-on=parkedroom`.
builder0, 2026-10-17 11:48–13:22 PDT, `make traffic-far-census FAR_RANGE=700-723 FAR_AT=terminus,locks,random FAR_JOBS=7`
(180 s showmatch fights, `--skirmish --demo-match --clean --fixed-fps 60`), n 72 paired fights (24 per arena),
none left out. Raw: `x3_series_far_ab.txt`, `x3_series_table_off.txt`, `x3_series_table_on.txt`.

| line | filed | OFF | ON | verdict |
|---|---|---|---|---|
| L1 gain | parked far loops: ON ≤ 50 % of OFF and drop − 1.645·se > 0 | 22 | 25 (se 20.3) | **FAIL** |
| L2 guard | all far loops: ON ≤ OFF + 1.645·se | 36 | 44 (+1.645·se = 71.8) | PASS |
| L3 guard (random 24) | kills / deaths / hit rate within ± 1.645·se | 1031 / 1041 / 0.704 | 1013 / 1026 / 0.694 | PASS |
| L6 return | room give-ways alive at 30 s and back within 3 m of the post ≥ 90 % | — | 212 of 2175 (10 %) | **FAIL** |
| R (reported) | give-ways a fight, median / worst | 158 / 330 | 176 / 285, room 42 / 111 | busiest ON: locks-706 |

L4 (traffic-series) and L5 (traffic-census repacks) were NOT run: the series was stopped after L1/L6 failed (no
partial ship; R33.10, builder0 freed for the other streams).

## What the reading says

- **The targeted mechanism is gone**: parked loops behind a crew on a HOLD post that "just gave way to this asker"
  (round 33 X1's mechanism: in-place yield, then refused for good): OFF 11 loops / 4 episodes, ON 0.
- **What is left is outside parkedroom by design**: ON's parked loops are 23 behind a crew SET UP ON A FIRE POST
  (T1c-b2's refusal, which the bar keeps: a set-up mortar truck never repacks for a passer), 20 of them in ONE fight
  (random-705: two Rust_Battery crews behind Rust_Battery2_3, 11 + 9 loops) — and 2 "already giving way". OFF had 11
  fire-post loops in 7 episodes. At n 72 the fire-post count is one fight's noise (paired se of the sum 20.3 against
  totals of 22 / 25), so L1 neither shows the gain nor a loss.
- **L6's failure is a real design defect, not only a metric**: "parked" in `ask()` is `not is_under_way()`, which is
  also true of a crew paused for a moment between orders. Those crews are asked, make room, and their element then sends
  them on: the 30 s read finds them a median 19.1 m from the "post" (0–30 s of the match: n 1070, 7 % back, median
  25.6 m; 30–90 s: n 1105, 13 % back, median 13.9 m; the room leg itself is a median 6.0 m; only 27 % ended nearer the
  post than the room spot). 3093 room give-ways in 72 fights (42 a fight median) is that over-firing; the neck stage
  (`test_traffic_neck`, crew truly at its post) returns within 3 m as designed. (The room log keeps the first 500 a run,
  so every read is in a fight's first ~90 s.)

## What a next try would have to change (not built)

1. Gate the room on a crew AT a post (its hold / fire post / element slot reached, and idle there for a filed time),
   not merely "not under way"; that is what L6 assumed and what X1's episodes were.
2. Judge L1 on the hold-post loops it targets, with fire-post (T1c-b2) loops reported apart, and at an n where one
   fight's 20 loops is not the whole signal (the per-fight parked count is ~0.3; n 72 cannot resolve a 50 % cut).
Both are bar changes, so they go to the orchestrator before any build.
