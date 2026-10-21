# Stream: native (the guard lines, the C++ twins, the scoreboard)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/native.md`, `_agents/workstreams.md`
> **Round 37** (C37.1, CP37.1, C37.2, C37.3) and `game_design.md` *OPEN QUESTIONS for him before round 37* (answer 11, the guard).
> Your round-36 brief is `streams/archive/round36/native.md`. **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`,
> `references/scoreboard/**`, `tools/judge/**`, `tests/ai_scenarios/**` (for the guard lines and the scout_suppress promotion), the
> net-test scripts (N4), the test-hygiene grant (C36.5).
> **Model:** Opus. **Machine:** builder2 (shared series queue with rules and cover: say in Status when you start/finish).

## The lead's direction

The measure for every rule change this round (his answer 11): **a blob frontal assault should lose, AND a pure turtle must not
always win.** Native is C++ for core components long-term (memory: stage 1 ON 2026-10-12).

What he will notice: nothing alone; every rule he plays at the round's close was judged on these lines, and the native build stays
identical to the script.

## Where things stand

- The scoreboard (`tools/scoreboard/`, `references/scoreboard/README.md`): a row per main, a noise column from 2 seed blocks.
- Doctrines/archetypes exist (`game/units/army.gd`: an army IS a doctrine; `cpu:<archetype>`), and `tests/ai_scenarios/` runs scripted
  matchups; round 3/8's balance sweeps used them.
- `scenario_scout_suppress::test_target_behind` passes identically while marked PENDING (n=3, shots=101, every check since at least
  2026-10-20, switches either way; manoeuvre's logs): promote it.
- Net-test diagnostics (round 36's sweep): relay_host_up / broker-load / lobby-smoke wait 5 s for BROKER_LISTENING then fall through
  silently (a dead broker surfaces 30 s later as "host never opened a room"); combat-smoke under `-eu -o pipefail` exits on a client
  FAIL before the reap and the server-ERROR grep.
- Round 36 skipped the judging-table re-render (close step 5b).

## Backlog (in order)

1. **CP37.1 the guard lines.** Design note to the orchestrator first: how the BLOB side is ordered (every squad straight at the other
   side's held zones, at once) and the TURTLE side (every squad holds its own zones, never advances) WITHOUT new game code (doctrine,
   army JSON, or the match runner's orders); the TACTICS side is today's CPU at its normal doctrine; both factions, both ways. Then
   read today's main on builder2: win rate and kill ratio per line, n sized from two seed blocks' noise. This is the BASE every rules
   and cover bar quotes. Hand over a green hash; the orchestrator merges it alone.
2. **N2 the twins** for every rules/cover/manoeuvre pair (R1 sight, R2 spread, R3 pin-slow, K2 hull-down, M1): 0 mismatches before
   their series, in the same pair.
3. **N3 the scoreboard row** for every main the round ships, with both guard lines added as columns.
4. **N4 the net-test diagnostics** (above): fail loudly and keep the diagnostics.
5. **N5 promote** `scenario_scout_suppress::test_target_behind` (update `tests/baselines/ai_scenarios_count.txt` through the
   orchestrator).
6. **N6 the judging-table re-render** (orchestration.md close step 5b) with round 36's judged pairs.

## How to verify

Twins 0 mismatches; `make native check` per named hash; the guard lines' noise stated before any rule is judged on them; every number
with commit, machine, workload, n.

## Don't touch

Game GDScript outside your grants (rules', cover's, feedback's, orders', manoeuvre's paths), `tests/baselines/**` (ask). Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**CP37.1 BASE (2026-10-21 11:31 PDT, builder2, guard.sh cfb8120ba = main 9d325e291's game tree, n 160 a line, 0 attempts lost
to preemption).** 5 maps x seeds 2601-2608 + 2701-2708 x both sides as the guard. BLOB (his right-click, every squad at once at the
enemy's zone): **wins 48 % (± 11 %)**, kill ratio **0.88 (± 0.07)**, 0 % capped, median 112 s. TURTLE (posts on its own zone,
never advances): **wins 39 % (± 15 %)**, kill ratio **0.80 (± 0.17)**, 0 % capped, median 194 s. ± = 2 se of a difference
between two mains from 16 seeds (unpaired); blocks 2601+ / 2701+: blob 49 / 46 %, kr 0.88 / 0.88; turtle 41 / 38 %, 0.81 /
0.80. Faction pair dominates a seed (Syndicate 73 % as blob, Gangs 30, Law 22): bars pair the SAME 320 fights,
`guard.py --pair references/scoreboard/guards/9d325e291.fights.jsonl ARM`. In player terms: today a naive all-in rush wins
about half its fights against the CPU's tactics, and sitting tight wins about two in five.

**Round 37, 2026-10-21 (worker).** Plan: CP37.1 (design note, probe, base read on builder2) -> N2 twins as pairs arrive -> N5
promote (small) -> N4 net-test diagnostics -> N6 judging re-render -> N3 a row per shipped main.

**N3:** the scoreboard page renders a *Guard lines* section from `references/scoreboard/guards/<commit>.json` (blob / turtle
win, kill ratio, capped share, ± from that read's own seeds); known answers in test_guard.py. **N6 DONE** (05e3982e0,
see judging.md *Round 37 re-render*): round 36's 20 lines in `tools/judge/lines_r36.py`, table unchanged (no round-36 rows on
main), 0 of 9 se lines inside the noise, 6 verdict margins under 1.645 se.

**Checks:** `cfb8120ba` (CP37.1 + N4 + N5 + N6 + N3, game tree = main 9d325e291) builder2 `make native check exited 2`: runner
2973/0, sim-baseline 13/13 unmoved, perf-judge NOT JUDGED (busy box, 2.5-3.9x); the ONE red is ai-scenarios-check, N5's
planned move (passed+not judged 53 -> 54, pending 5 -> 4: test_target_behind PASS n=3 shots=101; **the orchestrator adopts
54,0,4,0** with N5). The hand-over is cut CP37.1-ONLY as `pair/native-cp371` bc9c1301d (main 2cc959224 + the five CP37.1
commits cherry-picked, files byte-identical to stream/native's), full check queued on builder2, then pair/native-m5's.

**M5a mirror (manoeuvre, R37.10):** `pair/native-m5` 156d563d9 (side worktree ../godot-native-m5) = lab/manoeuvre-r37-m5
b94025dbe + begin_yield's seatstep mirror per manoeuvre's spec. builder0 light `make native quick` exited 0, 21/0: every old
test_native_yield stage PASS (switch OFF); new twin stages 0 mismatches: ON beam 6 m 18 drives (seated 18, moved 15, lead-out
avoided 12), ON ahead 8 m move_to and face_slot 9 each (9/9/6), ON 14 m never fires, OFF never fires; test_traffic_seatstep 3/3.
M1 sidestand needs no mirror (the far fire is GDScript-only). Full check queued on builder2 after CP37.1's (manoeuvre asked).

**Twin questions answered in writing (orchestrator):** R37.2 rules (no twin: C++ reads sight live, never computes spread,
drives the throttle tank.gd hands it); K2 (no native hit path skips cover's seam: shell_native only flies and emits `hit`,
beams are GDScript, combat_native runs downstream; splash and flames skip the seam on both paths, cover's call); O2 (no native
path issues an idle crew's move: decide_native returns the choice, every act call site goes through `_order_move`, no C++ writes
`move_order`). **N2 cover twins** (3d598cdaa): CoverNative.low_screen / low_features_near / cover_roll + seams
in cover_map.gd and armor.gd (merge note to cover: three dispatch lines, GDScript kept as `*_gd` reference), test
`tests/test_native_cover_low.gd`: builder0 light `make native quick` on 3d598cdaa exited 0: 15000 answers, 0 mismatches (1053 screened, 1830 near, of 3000 queries); test_cover_hulldown and test_cover_seat pass on the native path; test_native_cover 0 mismatches; combat-smoke PASS.

**Done so far (unchecked unless named):** N4 net diagnostics 820633935 (broker waits fail loudly, mutation-tested on the
laptop: `broker-load NODE=false` -> "broker never printed BROKER_LISTENING ... (process exited)" exit 1; a real broker-load exit
0); N5 promotion e1053de12 (`tests/baselines/ai_scenarios_count.txt` must move 53,0,5,0 -> 54,0,4,0: **the orchestrator
adopts**); R37.2 twin audit answered in writing (no C++ twin needed for R1/R2/R3: C++ reads sight live, never computes spread,
and drives the throttle tank.gd hands it).

**builder2 queue (shared with rules, cover):** native's guard base read RUNNING since 2026-10-21 09:55 PDT (`guard.sh
cfb8120ba`: its game tree = main 9d325e291's, only tests/tools differ; 16 seeds x 20 fights). A first chunk on 73a7d5f46 is VOID
(the probe's `finished` lambda captured `result` by value, so every fight read as capped at 600 s; kept aside as
`../godot-native-guard-raw/void-73a7d5f46-capbug`). Full check of cfb8120ba queued on builder2 behind `--wait-below 1`.
**First valid chunk (seed 2601, builder2, cfb8120ba, n 20):** fights end by elimination or 90 points in 51-198 s, 0 capped. The
seed is Law (26 vehicles) v Syndicate (16) and the Syndicate side won 9 of 10 whatever its role: one seed's faction pair
dominates, so the line is read over 16 seeds and broken down by pairing (guard v tactics of the same faction, both ways).

### CP37.1 design note (sent to the orchestrator; no new game code)

- **Where:** `tests/ai_scenarios/guard_line.gd`, a SceneTree probe around the scoreboard's own fight: `--skirmish --demo-match
  --clean --seed=N --arena=A` (both sides today's CPU at its normal doctrine, elements + ElementCommander, zones on). Flags
  `--guard=blob|turtle|none --guard-side=green|rust`, cap `--seconds=600` (a fight ends at 90 zone points or elimination;
  a capped fight is judged as the game judges a time-out, `Match.result("time_limit")`). Prints `GUARD_RESULT {json}`.
- **How one side is ordered without game code:** the probe marks the ordered side as the side a human commands
  (`player_team` meta, the game's own switch: `ElementCommander._physics_process` stands down for it, its elements take
  preempting player tasks), then gives its elements ElementTasks through `Element.assign`, the call the tactical map makes.
  So the blob/turtle side IS a player's army ordered naively; the tactics side is untouched.
- **BLOB (R37.1 (a) / R37.3):** every element (recon and support included) is sent at once with his RIGHT-click task
  `{"verb":"move","to":zone,"drills":false}` (element_plan.gd:359 -> `_plan_form_up`: a formed-up transit, no bounding, no
  overwatch, no contact drill; his A-click, drills on, may bound under "contact likely" and is kept only as `--blob-drills=on`,
  not run) at the zone in the enemy's half; when it holds that, at the zone it does not hold; holding both, at
  the enemy spawn. Re-tasked only when that target changes (a player clicks once); unseated crews re-seated per squad.
- **TURTLE:** every element holds a post across the zone in its OWN half (`hold`, facing the enemy spawn, 22 m apart, no
  drills: the CPU's own hold layout minus its intruder attack), given once, never advances. Crews shoot what they see.
  Every map in the workload has one zone a half (mirrored pairs), so "own" and "theirs" are unambiguous.
- **Workload:** the scoreboard's 5 maps (terminus locks sumps gorge parade) x 8 seeds x BOTH sides (the same seed's
  faction pair with each faction as the guard: both factions both ways) = 80 fights a line a seed block; two blocks (2601+,
  2701+) = 160 a line. Lines: blob, turtle (+ `none`, the CPU v CPU control, if the box time allows).
- **Driver (builder2 preempted every ~2 min from ~09:00 PDT 2026-10-21):** `tools/scoreboard/guard.sh COMMIT`: one seed a
  remote call (20 fights), its own scratch worktree `../godot-native-guard`, raw logs in `../godot-native-guard-raw/<commit>/`,
  a chunk counted only on `exited 0 (build/ copied back)` + a verified copy-back, resumable, a 255 restarts builder2 and
  retries; driver.txt counts the attempts lost to preemption.
- **Read per line:** the guard's win rate (draws counted apart), its kill ratio (kills / losses, totals), match length, per
  faction; noise from the two seed blocks (per-seed-unit sd -> 2 se of a difference, the scoreboard's ± column method).

