# Stream: native (the quiet reads; his match replayed faithfully (CP43.0); twins for what ships; the judged lines)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.2, C43.4, CP43.0), your
> round-42 brief `streams/archive/round42/native.md` (Status: N4 never run, lines_r42, the guard tool's paired means). **You own:**
> `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `_agents/judging.md`; NEW this round `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tests/replay/**`; GRANT (C43.2) keys on the `match` / `order` rows of `game/match/match_recorder.gd`.
> **Model:** Opus. **Machine:** builder0 (quiet window first); builder2 for rows.

## The lead's direction

Nothing he sees directly: "core components in C++ long-term" (memory). This round his playtest could not be re-run: "I don't know if
this is a regression" can only be answered by a replay of his match that reproduces it.

## Where things stand (main at launch: see HANDOFF)

- **builder0 is idle at launch** (20:32 PDT: load 0.00) and the other three streams spend their first half hour reading. N4 (the
  quiet-box read) has never had a window in round 42.
- **The replay probe** `tests/replay_orders.gd` (the orchestrator's, now yours) re-issues his recorded orders into a headless skirmish
  (`--fixed-fps 30`, same seed / arena / factions / cap) and writes a new recording. On his `references/round42/playtest/` recording
  it diverges inside 2 s: his Guns squad jams at the start (War Rig 3 yields 20 s to his Hunters), the replay's drives off. Candidates,
  none tested: his laptop ran 26-31 fps (frame-rate-dependent movement or a physics/frame tick mismatch); an order landing on a
  different tick or frame phase than recorded; the interactive input path (selection, a drag, group-click layout from the screen's
  rays) issuing something different from the recorded row; state the recording doesn't hold (the army's spawn deal, RNG draws by
  anything frame-driven: camera, audio, LOD, the announcer).
- `tools/recording_arrivals.py` reads a recording's arrivals (the orchestrator's; yours now).
- Two control-timing OVER BUDGET lines noted by camera on a loaded box: a right click on 30 units 2699.8 v 104 workloads; control per
  frame 28.25 v 26.0. Re-read quiet before anyone acts on them.

## Backlog (in order)

1. **N1 the quiet reads (now, while builder0 is idle; time-box 60 min, then yield to the others).** `make remote-quiet`: perf-judge on
   main b12b17ac7 (the round's reference), N4 lint-fast before/after wall time, the two control-timing lines re-read. Report each with
   commit, machine, load. If someone's check starts, stop and record what you got.
2. **N2 CP43.0 the replay reproduces his match.** First measure the divergence (per crew per census tick: replay v his match). Then find
   the cause by removing candidates one at a time (run the replay at his frame rate: e.g. `--fixed-fps 28` or the recorded frame times;
   issue orders on the recorded tick and phase; drive the real input path). Fix in your paths; add to the recording (C43.2: additive keys
   only) whatever it must hold for the next playtest to replay. Bar (filed before the numbers): every crew of his first two orders
   within 3 m of his census for the first 20 s, on this recording and on round 41's (`references/round42/engage/`). If an interactive
   match cannot be replayed bit-faithfully, write why and what would make it so. Name the green hash: the orchestrator merges it alone
   and tells engage and manoeuvre the same minute.
3. **N3 twins as asked:** manoeuvre's S2 / S3 rules, engage's A3 if it lands in a mirrored seam (C43.4). Pair branches as before.
4. **N4 lines_r43** as bars are filed (from workstreams.md *Bars (round 43)* and the streams' tables; nothing re-measured).
5. **Stretch:** a `make replay RECORDING=<file>` target (headless, prints the divergence table) so every future playtest can be re-run.

## How to verify

`make quick-remote`; `make remote T=check` for a hash you name; native-proof on builder0 for any twin. The replay: its divergence table
on both recordings, before and after.

## Don't touch

`game/ai/movement.gd`, `traffic.gd` (manoeuvre), `game/tactics/**` (engage), `game/camera/**` (camera), `game/match/**` but your
C43.2 keys, `tests/baselines/**`. If the divergence's cause is in someone else's code, write it up and message the orchestrator. Don't
push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
