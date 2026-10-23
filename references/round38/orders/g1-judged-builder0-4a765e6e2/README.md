# Bar G1 (O7 v2, `--group-lay=column`) judged: FAILS as filed (amended bar)

Tree 4a765e6e2 (game code = 130cf487f), builder0 native, light lane at J 4 beside manoeuvre's series (R38.8), fresh seeds
3881-3892 (n 12 a cell), 384 street runs + 48 his-click runs. `verdict.txt` = `orders_judge.py g1` (street + his rows,
yard_open as the no-change cell). Full check of the tree: builder2 (see the brief's Status).

- Deciding, all PASS: places outside the corridor (click cells) 84 -> 18 (line 21); metres driven outside it after being
  in it (click cells) 6,223 -> 1,393 (line 3,111); squads with crews re-dealt 58 -> 0. Contacts 14,004 -> 10,622.
- Guards FAIL: crossing 3 route twitch 5.8 -> 10.5 m; terminus_his 3 click twitch 2.3 -> 11.4 m (deterministic, n 1: the
  halt flips herringbone -> coil after the deploy; settle's `--deploy-latch=on` removes it); yard_open 177 / 192 rows
  identical: 5-squad clicks s3889 / s3891 laid a column because today's rear rank stood beside the yard's containers (off
  the clear width read at its rank), and route s3886 re-laid the first click (the 2 s re-lay) and changed timings.
- Every other guard in all 14 cells passes (all-in, never-in, end foreign, crossed).
