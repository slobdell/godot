# S3: W1b (WHEEL_HALT) deleted — native's half of the pair (R35.78, C36.3)

Manoeuvre's half: `lab/manoeuvre-s3` (GDScript): `Manoeuvre.WHEEL_HALT_DEFAULT`, `wheel_halt_asks`, `wheel_halts`,
`wheel_halt_on()`, `wheel_halt()` deleted; the call in `Movement.drive` deleted; `wheelhalt` out of `Movement.OFF_NAMES`;
`tests/test_manoeuvre_wheel_halt.gd` deleted; the census/wedge/fight readers no longer print the counters. W1b was default
OFF, so play is unchanged (sim-baseline must read unmoved on the pair).

Native's half (its paths; without it the pair does not parse: three tests/native files name the deleted statics):

1. `tests/native/mover_state.gd` lines ~60–61 and ~85–89: drop the two `static:Manoeuvre.wheel_halt_asks` /
   `static:Manoeuvre.wheel_halts` keys (save and restore).
2. `tests/native/traffic_hold_case.gd` ~30–46: drop the `halt` / `halt_before` block, its print and the `>= 100 asks`
   assertion (the stage's other lines stand).
3. `tests/native/drive_twin_case.gd` ~503–505: drop the `WHEEL_HALT_DEFAULT` print.
4. `game/ai/native/native_drive.gd` 118: drop the `WHEEL_HALT_DEFAULT` config key.
5. `native/src/drive_native.{h,cpp}`, `tank_native.cpp`: drop `wheel_halt_ready`, `WHEEL_HALT`, the two counter keys and
   the block at drive_native.cpp ~3567–3578 (it was inert: `wheel_halt_ready` is false once the constant is gone).

Check: `make native check` on the pair; sim-baseline 13 maps unmoved is the inertness line.
