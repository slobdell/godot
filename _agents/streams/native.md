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

### Report (round 37 worker, 2026-10-21 ~13:00 PDT)

**In player terms:** today a naive all-in rush (every squad right-clicked onto the enemy's zone) wins about **half** its fights
against the CPU's tactics, and sitting tight on your own zone wins about **two in five**. Those are the two lines every rule this
round is judged on; both should fall.

**CP37.1 the guard lines: DONE, merged on main (d9545d381 merges bc9c1301d; 84c11a60d takes 2bb41ef93).**
- BASE (builder2, guard.sh cfb8120ba = main 9d325e291's game tree; 5 maps x seeds 2601-2608 + 2701-2708 x both sides as the
  guard; 160 fights a line, 320 read, 0 attempts lost to preemption): BLOB **wins 48 % (± 11 %)**, kill ratio **0.88
  (± 0.07)**, median 112 s; TURTLE **wins 39 % (± 15 %)**, kill ratio **0.80 (± 0.17)**, median 194 s; 0 % capped, 0 draws.
  ± = 2 se of a difference between two mains from the 16 seeds (unpaired). A/A: blocks 2601+ / 2701+ blob 49 / 46 %, kr 0.88 /
  0.88; turtle 41 / 38 %, 0.81 / 0.80. Faction pair dominates a seed (as blob: Syndicate 73 %, Condemned 56, Gangs 30, Law 22).
- Today's main plays the same fights: bc9c1301d's tree (cover K2 code OFF), seed 2601, 20 of 20 GUARD_RESULT lines
  byte-identical (builder2).
- Bars pair the SAME fights: `GUARD_ARGS=--rules-on=sight GUARD_TAG=sight tools/scoreboard/guard.sh C`, then
  `python3 tools/scoreboard/guard.py --pair references/scoreboard/guards/9d325e291.fights.jsonl ../godot-native-guard-raw/C-sight`
  (flips, exact McNemar, paired win and kill-ratio differences with per-seed se). GUARD_RESULT carries `cover_struck` and the
  arm's `args`. Rules and cover have the recipe.
- Design: the guard side is marked as the human-commanded side (`player_team`, so its ElementCommander stands down) and tasked
  through `Element.assign`: no game code (design note below; R37.1 / R37.3).

**N2 the twins:**
- Cover K2/K3: `CoverNative.low_screen / low_features_near / cover_roll` (3d598cdaa + .uid 11f129b35): builder0 light quick
  exited 0, 15000 answers 0 mismatches; cover's hull-down and seat tests pass on the native path. Seams in cover's files (merge
  note below).
- Manoeuvre M5a seatstep: `pair/native-m5` **156d563d9 GREEN** (builder2 `make native check exited 0`, 2984/0, 25 + 2 NOT
  JUDGED, sim-baseline 13/13 unmoved); twin stages 0 mismatches, ON avoids the lead-out (12 of 18 beam, 6 of 9 ahead).
  Manoeuvre merges it.
- Unstick in R2's short halt (manoeuvre's b496101bd): `pair/native-unstick` ca6978178 (+ .uid): quick exited 0, OFF 18 compared
  0 mismatches (9/9 fire), ON 18 compared 0 mismatches (0 fire). Manoeuvre merged it (4378658cb).
- Written answers (no twin needed): rules R1-R3 (C++ reads sight live, never computes spread, drives the throttle tank.gd hands
  it), K2 (no native hit path skips cover's seam), O2 (no C++ writes `move_order`), M1 sidestand (the far fire is GDScript-only).
- Rules' empirical run (R37.4) DONE on rules' pair 75c3e74e0 (builder0 light): `make native test FILTER=test_rules_` native ON
  20/0 and NATIVE=off 20/0, both exited 0, every test PASS in both arms (the tests set each switch ON and OFF themselves; they
  print no numbers, so the equality is per assertion). Rules told; its arms may start.

**N3 the scoreboard:** the page has a *Guard lines* section (references/scoreboard/guards/<commit>.json); the round-37 launch
column 9d325e291 is read (builder2, verdict ok 40/48/36): v 3d46b2884 every line inside its noise (stuck deaths 5.92 -> 5.17 a
fight v ± 2.33). OWED: a row (fights + guard lines) for every main the round ships, as the orchestrator names them.

**N4 the net-test diagnostics: DONE** (820633935): relay_host_up / broker-load / lobby-smoke fail loudly with the broker's log
when BROKER_LISTENING never comes (mutation: `broker-load NODE=false` -> "broker never printed BROKER_LISTENING ... (process
exited)", exit 1; a real broker-load exit 0, laptop); combat-smoke keeps the server-ERROR grep and the reap after a client FAIL.

**N5 promote scenario_scout_suppress::test_target_behind: DONE** (e1053de12): it PASSES (builder2, n=3, shots=101). **The
orchestrator adopts `tests/baselines/ai_scenarios_count.txt` 53,0,5,0 -> 54,0,4,0** (the gate counts passed + not judged).

**N6 the judging re-render: DONE** (05e3982e0): round 36's 20 lines in `tools/judge/lines_r36.py`; `_agents/judging.md`
*Round 37 re-render*; table unchanged (round 36's rows are on round36/* branches); 0 of 9 se lines inside the noise.

**perf-judge on builder2 (R37.20):** it can never judge as built: builder2's nominal is the old c4d's (now e2-highcpu-32, Intel
Broadwell; the reference reads 2.28-2.50 ms v 0.898 at 62-96 % idle) and scenario_perf's pass line is absolute (FAIL_USEC
20,000; the brains read 21-34k there). Ruled: one perf-judge on builder0 for main (the orchestrator's); (b) DONE 14c10d1d4:
perf_judge.sh says "NOT JUDGED: builder2 is not a judging machine" at once (laptop test_perf_judge 7/0, check-perf-judge 10/0);
(c) a relative line (µs per reference ms) is round 38's.

**Checks:** cfb8120ba builder2 `exited 2`, 2973/0, sim-baseline unmoved, the one red N5's planned count move. Stream tip
6c9bc7239 (main a10846307 + N2 cover twins + N4 + N5 + N6 + N3 row): full check QUEUED on builder2 behind main's.

**Decisions (mine):** the blob re-targets only when its zone changes (a player clicks once); the turtle's posts are the CPU's own
hold layout without its intruder attack; a fight runs to its own end (cap 600 s never reached); the CPU v CPU control (`none`)
was not run (not asked; it would cost builder2's shared series slot): the both-ways pairing already separates role from faction.

**Questions for the lead:** none.

**Requests to other streams:** cover: the three dispatch lines in `cover_map.gd` / `armor.gd` (merge note). Rules: declare the
pair commit for the empirical twin run.

**Known issues:** the faction balance is lopsided (Syndicate wins 73 % as a blob and 67 % as a turtle; Law v Syndicate 0 %); not
this stream's, but a rule's effect can hide inside a pairing, so read bars paired. Low cover is struck 0 times in 4 Terminus
fights with hulldown ON (cover's K1: low cover is where the fighting isn't; K5's re-shape is the lever).

**What to playtest:** nothing new to feel (tooling and twins). To watch a guard fight:
`godot --path . --script res://tests/ai_scenarios/guard_line.gd -- --skirmish --demo-match --seed=2601 --arena=locks --guard=blob --guard-side=green`
(drop `--headless` to watch the cinematic camera).

**Merge notes (shared / other owners' files):** `game/ai/cover_map.gd` (low_screen and low_features_near dispatch to CoverNative
under BrainSwitches.native_cover; the GDScript kept as `low_screen_gd` / `low_features_near_gd`) and `game/combat/armor.gd`
(low_cover_strike takes its roll from `map._native.cover_roll` on the native path): cover's files, three dispatch lines, 3d598cdaa.
`mk/net.mk` (N4). `tests/scenario_scout_suppress.gd` PENDING list (N5). Side worktrees to remove at the close: ../godot-native-m5,
../godot-native-unstick, ../godot-native-cp371, ../godot-native-guard, ../godot-native-score; builder0/builder2 folders
`~/tank_squad/godot-native*`.

### History (chronological notes)

**CP37.1 BASE (2026-10-21 11:31 PDT, builder2, guard.sh cfb8120ba = main 9d325e291's game tree, n 160 a line, 0 attempts lost
to preemption).** 5 maps x seeds 2601-2608 + 2701-2708 x both sides as the guard. BLOB (his right-click, every squad at once at the
enemy's zone): **wins 48 % (± 11 %)**, kill ratio **0.88 (± 0.07)**, 0 % capped, median 112 s. TURTLE (posts on its own zone,
never advances): **wins 39 % (± 15 %)**, kill ratio **0.80 (± 0.17)**, 0 % capped, median 194 s. ± = 2 se of a difference
between two mains from 16 seeds (unpaired); blocks 2601+ / 2701+: blob 49 / 46 %, kr 0.88 / 0.88; turtle 41 / 38 %, 0.81 /
0.80. Faction pair dominates a seed (Syndicate 73 % as blob, Gangs 30, Law 22): bars pair the SAME 320 fights,
`guard.py --pair references/scoreboard/guards/9d325e291.fights.jsonl ARM`. In player terms: today a naive all-in rush wins
about half its fights against the CPU's tactics, and sitting tight wins about two in five.
**Today's main plays the same fights:** guard.sh on bc9c1301d (main 2cc959224's tree, cover's K2 OFF code in), seed 2601, 20 of 20
GUARD_RESULT lines byte-identical to the base's (builder2). **Arm tooling (cover K4 / rules ask):** GUARD_RESULT carries
`cover_struck` and `args`; `GUARD_ARGS=--cover-on=hulldown GUARD_TAG=hulldown tools/scoreboard/guard.sh C` runs an arm on the same
fights (builder0 light smoke: 4/4 fights, args recorded, cover_struck 0 in 4 Terminus fights). Cover and rules told.
**Hand-over: CP37.1 is GREEN, merge here: `bc9c1301d`** (pair/native-cp371 = five CP37.1 commits on main 2cc959224): builder2
`make native check exited 0`, 2988/0, 25 + 2 NOT JUDGED (load), sim-baseline 13/13 unmoved. Follow-ups on the same branch + 8a34906b9
(the base rows, --pair) + 2bb41ef93 (cover_struck / GUARD_ARGS), byte-identical to stream/native's files.

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
M1 sidestand needs no mirror (the far fire is GDScript-only). **GREEN: 156d563d9** builder2 `make native check exited 0`,
2984/0, 25 + 2 NOT JUDGED, sim-baseline 13/13 unmoved; manoeuvre told (it merges the pair into its M5 trees).

**Unstick short-halt twin (manoeuvre's b496101bd, for rules' R2):** `pair/native-unstick` ca6978178 (side worktree
../godot-native-unstick) = b496101bd + drive_native's unstick early return when `tank.short_halt_seconds > 0` (after holding(),
before seam_live(), as the GDScript) + tests/test_native_unstick_halt.gd: builder0 light quick exited 0, OFF 18 compared 0
mismatches (GDScript fires 9/9), ON 18 compared 0 mismatches (0 fires). Manoeuvre merged it into stream/manoeuvre (4378658cb); its .uid (uid://b6ujvp2xqaynp, manoeuvre's) committed on the pair.

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

