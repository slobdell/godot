# O5: his tick-1512 click on native's exact replay, before / after G1 v10 (laptop, 2026-10-28 ~10:20 PDT, laptop clock)

Scratch tree = orders 7b9e7d1a4 merged with stream/native 9f4eb4f59 (N2: `--click=TICK:X,Z` replays the four recorded rows as ONE
group click). `make replay-match RECORDING=.../2026-10-28T08-21-31-locks.jsonl REPLAY_SECONDS=56 CREWS=all REPLAY_FLAGS="[--group-column=always] --click=1512:-35,97"`.
The replay ran the GDScript drive (REPLAY_NATIVE_MISMATCH: the laptop had no library in the scratch tree), so the crews' positions
at tick 1512 are within a metre or two of his, and the divergence verdict (a drive read) is void; the LAYOUT is what this read is for.

- `tick1512-orders-before.jsonl` (main's layout): Guns_4 (-51.5, 15.3), Hunters (-45.9, 69.5), Spears (6.8, 56.5), Wrenches
  (-23.7, 117.2) = his recording ((-50.5, 15.2), (-45.9, 69.5), (7.9, 57.7), (-25.5, 117.2)) to within 2 m: the click is (-35, 97).
- `tick1512-orders-after.jsonl` (`--group-column=always`): Hunters (-35.4, 95.1) ON his click; Guns_4 (-7.7, 77.6), Spears (13.7,
  91.5), Wrenches (43.9, 92.4) hold where they stand, in file behind it. Every row carries `click` [-35, 97] and `group` 4 (O1).
