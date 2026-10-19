# Round 33 overnight (traffic item 3): the fire-post loop, random-705, diagnosed (report only, nothing built)

Reproduced exactly: X3's tree `d90fbdb7` (game code `aff64e2b`), `--traffic-on=parkedroom` (the X3 ON arm), builder2
light lane, native library built, `make native traffic-far-one FAR_ONE_ARENA=random FAR_ONE_SEED=705` (= parade, gangs v
condemned), --fixed-fps 30, n 1. The same 20 far loops as the series' builder0 log: Rust_Battery_1 → Rust_Battery2_3 ×
11, Rust_Battery2_5 → Rust_Battery2_3 × 9, the first at tick 3775. The trace adds the brain's weapon order, target, task and
`on_fire_post()` to far_census's FAR_TRACE (probe only). Raw: `ov_firepost_r705_trace.txt.gz` (FAR_ROW + FAR_TRACE).

## Who refuses whom, and why

1. **The blocker digs in short of its place, with nothing to shoot.** Rust_Battery2_3 (artillery) drives toward its
   element slot. At 111.5 s its move reads ARRIVED with 5.1 m still to go (slot 5.9 m away), and its option turns MOVE →
   ADVANCE with no order verb. Standing still, `tank.gd _deploy_step` digs it in (any deploying hull still for
   DEPLOY_SETTLE_TICKS = 0.25 s). Deploy 0.12 → 1.0 by 114 s. Weapon `fire_at_will`, **target "" the whole time**. It
   doesn't move again for the last 66 s of the fight.
2. **T1c-b2 then refuses every passer.** `Movement.on_fire_post()` (movement.gd:1659) = deployed + any fire order but
   hold_fire + move arrived. That is TRUE for a truck that is dug in and idle, not only for one that is firing. Every ask is
   refused (setup_refusals), and the askers loop (H1b far loops, gap 8.5 m).
3. **The askers dig in too, every time they stall.** Both askers are batteries on a `move` (25.8 m and 42 m to go). Each
   time one is blocked for 0.25 s it starts to deploy (Rust_Battery2_5 0.15 → 1.0 while "blocked"), and each retry first
   has to pack up again (pack_seconds), so it stalls again. Rust_Battery_1 also gave way to Rust_Battery2_5 twice in the
   jam.

## Owner proposal

- **traffic (movement.gd's give-way block, T1c-b2's predicate):** refuse a passer only for a battery that is set up
  AND has a fire mission (a target / engaged_target, or a shot in the last few seconds). A dug-in truck with no target
  is asked like a parked crew and packs up to make room. This keeps T1c-b2's purpose (a firing battery never repacks
  for a squadmate) and removes the case here. Bar-able on traffic's census (fire-post loops) and brains' "T1c-b2
  (repack while firing) 0" line.
- **brains (the battery item, `--battery-seat=deployatplace`):** "deploy only within 8 m of the assigned place" stops
  the ASKERS digging in while blocked mid-move (they were 25.8 m and 42 m from their goals). It does NOT stop the
  BLOCKER here: it dug in 5.9 m from its slot, inside 8 m. So the battery item alone leaves this loop.
- **tank/brains (not traffic):** whether any deploying hull should auto-dig-in after 0.25 s still without a fire mission
  at all (tank.gd _deploy_step), and why the move read arrived 5.1 m short (an arrival tolerance; brains' arrivedgate
  switch touches arrival). Both are brains' battery-item territory.

Recommendation: the traffic predicate narrowing plus brains' deployatplace, judged together on fresh fights. Or, if
brains prefers, a brains-side "no dig-in without a fire mission", which would make the traffic change unnecessary.
Brains to say which.

## Brains' answer (2026-10-18): the narrowing is traffic's

- The blocker is 5.9 m from its slot, so it IS at its place by brains' (c) 8 m rule. Digging in there is right: an
  idle set-up truck is ready the moment a target shows, and "no dig-in without a fire mission" would cost every battery
  its 2–2.5 s deploy at first contact (the fire-order → first-shot line in brains' bar).
- The defect is the refusal: `on_fire_post()` reads readiness as firing. T1c-b2 is traffic's, so traffic narrows it,
  and brains' census line "T1c-b2 (repack while firing) 0" keeps it honest.
- The askers' dig-in on every stall (25.8 m and 42 m from their goals) is what brains' (c) stops (`--battery-deploy=off`
  is its off arm, on lab/brains-r33-battery `e8530098`; that series runs on builder2, fresh 47–52).
- Interaction: brains' (a) keeps a SET-UP battery's seat where it stands. Once a truck's legs rise for a passer
  (deploy_ratio < 1), (a) seats it as a mover again, which is fine.

**Owner proposal (traffic + brains agree): traffic** narrows T1c-b2: a battery counts as firing only when it is set up
AND has a fire mission (a target, engaged, or a shot in the last few seconds). It is judged after (or on a tree with)
brains' battery item, so the askers' dig-in is already gone and the remaining loops are the blocker's alone.
