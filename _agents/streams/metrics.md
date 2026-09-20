# Stream: metrics (A12 trajectory-space metrics = CP1, then T1 parallelise `make check` = CP3)

> Read `HANDOFF.md`, [orientation.md](../orientation.md), [orchestration.md](../orchestration.md) (*The worker
> contract*), [workstreams.md](../workstreams.md) (*Round 9: the seven streams* — contract **S3**, checkpoints **CP1**
> and **CP3** — and the *Round 9 goal* section's **A12** row and **T1** paragraph), and
> [research_catalog.md](../research_catalog.md) row **A12** (and Part 1 §1's last bullet: nothing offline runs until
> A12 exists). You own `tools/metrics/` (new), `mk/metrics.mk` (new), `_agents/metrics.md` (new), and — **for T1
> only** — the `check` recipe in `mk/core.mk`, `tools/slot.sh`, and any smoke timeout you must raise, each listed in
> your merge notes with its before/after. This is a **tooling** stream: you write no game behaviour. Every other
> stream's falsifier this round is read from your tool and no other, which is why you land first.

## The lead's direction (2026-09-19)

He did not name A12; he named the thing it exists to fix and the thing T1 exists to fix.

On the round-8 measurement (his complaint was the *shape* of the motion, we measured *time spent*):

> *"I can also see that the semi trucks are yawing in place (should be impossible, they're not a tracker vehicle).
> ANother obvious problem right now in [make skirmish] is that units get stuck behind basic barriers… moving back and
> forth indefinitely trying to get unstuck."*

On the check (2026-09-19, asking why builder0 sits idle during a check): recorded in `workstreams.md` *Round 9 goal* —
**"The lead asked for this directly (2026-09-19) and it is worth more than any single algorithm on this list."**

The research brief's own admission, which is A12's charter (`research_catalog.md` A12): *"we repeatedly measured
[time-allocation] while the human complaint was about [trajectory]"*. A unit that oscillates for 0.5 s costs 6% of
travel time and ruins the next fifteen seconds of watching.

## Where things stand

**The measurement that must be reproduced.** Round 8's headline (nav, archived brief
`_agents/streams/archive/round8/nav.md` *The headline, re-measured on main*): tree **`aa984edd`** (main `f5526594`
merged), **builder0**, `make nav-fight-maps`, attack_move, Condemned vs Condemned, seed 3, 120 s, arm read live
(commit=true, standoff):

| map | oscillating | units that ever oscillated |
|---|---|---|
| yard | 7.2% | 28 |
| boneyard | 6.6% | 27 |
| pit | 5.8% | 25 |
| boulevard | 5.3% | 28 |

**How that number is defined today** — `tests/nav/fight_probe.gd:462-535`, arena's three pre-registered stall
counters pasted verbatim from `_agents/streams/references/arena/stall_counters_for_fight_probe.gd.txt` (frozen in
`references/arena/stuck_preregistration.md`): a **4 s window** (`WINDOW_S`, line 470); a window counts as
*oscillating* when path length ≥ **8 m** (`OSCILLATE_PATH_M`) and net displacement / path < **0.25**
(`OSCILLATE_RATIO`); *no_progress* when distance-to-goal improved < 2 m; *crawl* when speed < 0.5 m/s; the window
resets when the goal jumps > 3 m. `oscillating_share` = oscillating ticks / ticks under orders and not arrived.
`_travel_report()` (line 304) sums the same windows per unit type into `net_over_path` and `oscillating_share`.
**A12's windowed displacement efficiency is this quantity generalised** (a continuous ratio per window instead of a
threshold, on every unit whether ordered or not) — which is why the round-8 finding is your positive control: if the
new metric cannot see it, the metric is wrong.

**What is logged today, and what is not.** `nav-fight` (`mk/nav.mk:41-44`) prints **one `NAV_FIGHT <json>` line per
run** — aggregates only (`travelled`, `gear_detail`, `inplace_detail`, the order buckets). The probe keeps a per-unit
position trail (`trail`, line 484) and a gear sign (`gear_sign`, line 213) **in memory and discards them**. There is
**no per-tick trajectory log anywhere in the repo**, and the round-8 JSONs in `_agents/streams/references/round8/nav/`
and `round8/arena/` are per-run summaries (`summary.json` rows: `arrived`, `t50_s`, `oscillating_share`, … — verify
with `python3 -c "import json; print(list(json.load(open(...))))"`). **So "from the same replays" in the catalogue
cannot be taken literally: the replays do not exist.** The honest positive control is a re-run of the recorded
configuration at the recorded commit on the recorded machine (backlog item 3). The `references/round8/` directory has
no README; the archived brief's table above is the provenance, and your re-run establishes a new one.

**The gear-flip counter** (`fight_probe.gd:209-247`): a flip is a sign change of the drive gear above `GEAR_SPEED`,
attributed to `reverse_order` / `yielding` / `phase:<x>` from the controller's state at the flip. Round 8 measured
**9–19 reversals per agent-minute** in a 2 s window, a third ordered, a third the creep K-turn, a third unexplained
(`research_catalog.md` P2). Signed cusp density is the trajectory-side version of this: a cusp is a sign change in
the *velocity along the path*, read from positions, not from the controller — so it sees flips the controller never
labelled.

**The check you are parallelising.** `mk/core.mk:85`:
`check: lint test net-smoke combat-smoke broker-test relay-smoke lobby-smoke match-smoke determinism sim-baseline
garage-smoke army-loop-smoke announcer-check audio-check match-pytest`, run serially by make, the whole goal wrapped
once in a heavy-run slot by the root `Makefile:84-99` (`tools/slot.sh $(MAKE) $(MAKECMDGOALS)`), shell
`-eu -o pipefail` (`Makefile:18`). On builder0 `tools/remote.sh` runs it with `REMOTE_SLOTS` (default 3, line 22).
Measured at round 8's close (`workstreams.md` T1): **one single-threaded Godot at ~7% CPU on a 12-thread machine**
for 30–50 minutes (`remote_builds.md:59-64`: 6 min 40 s alone on 2026-09-15; ~50 min with six live streams at
`5c68a03e`, orchestrator's run). The slot count is **derived** in `tools/slot.sh:58-70` — `MemAvailable` at 2.5 GB
a slot, clamped [2, 4] (lesson 148 in `orchestration.md`) — and the same lesson records what raising concurrency
invalidates: **ratios computed inside one run survive; `t50_s`/`t90_s`, crossing times and per-tick costs do not.**
Copy that split when you retire numbers after CP3.

**Wall-clock timeouts you will meet** (`grep -n timeout mk/*.mk`): the garage smokes are already at 600 s
(`mk/garage.mk:13,68,82`, raised from 60/120 for exactly this reason); `net.mk` client `--timeout=35..90`;
`command.mk:10` 120 s (control-playtest), `:100` 360 s (shell-playtest); `nav.mk:65` 900 s; `audio.mk:124` 360 s;
`match.mk` has none on the match runner itself. `mk/core.mk:55-57` records why a timeout on a *wrapper* is worse than
none: it reaps the parent and leaves Godot children running. **Inner fan-out already exists** — `matches`,
`faction-matrix`, `engagement` run `--jobs $(JOBS)` (`JOBS ?= 4`, `Makefile:66`; worktrees get `JOBS := 2`), and
`slot.sh:25-26` warns that one slot can already hold ~4.4 GB of Godot from an `xargs -P 6`. Memory is the constraint
(~735 MB a Godot run, 11.9 GB available on builder0, ~2.4 GB on the laptop with six sessions up).

**Determinism is safe, timing is not** (`workstreams.md` T1). Separate processes on a fixed tick hash identically
under any load; `determinism` and `sim-baseline` compare hashes, and both must be bit-identical between the serial
and parallel `check` — that is part of CP3's falsifier, not an assumption.

## Backlog (in order)

Smallest foundation first; a failing test before each build; commit every green step; Status current.

1. **The trajectory log format, and a reference emitter.** Define `tools/metrics/FORMAT.md` and a JSON-lines schema:
   one line per unit per tick with `tick`, `unit` (node name), `unit_id` (type), `team`, `x`, `z`, `heading_rad`
   (unwrapped — round 8's 20.7° "overshoot" was a wrap bug, `archive/round8/nav.md` item 8), `speed_mps` (signed:
   negative in reverse), `gear` (−1/0/1), `goal_x`, `goal_z` (or null when not under orders), `order_verb`,
   `element` and `slot` (or null). A header line carries `commit`, `machine`, `tick_rate`, `arena`, `seed`, the
   command line and every resolved knob (lesson 44: print what each knob resolved to). Emit it from
   `tests/nav/fight_probe.gd` behind `--trajectory=PATH` (**four lines in nav's file — ask the orchestrator to grant
   the edit, and keep it to the emitter; nav owns the probe**) and from the match runner
   (`game/modes/match_runner_mode.gd`, combat's — same request; if either owner prefers to add the hook themselves,
   hand them the schema and continue on synthetic data). Contract S3: **every producer emits this format; nobody
   invents a second one.** Test: a 10-tick fixture round-trips through the reader; a line missing a required field
   is refused loudly (Invariant 0's *no fallback* clause).
2. **The four metrics, each with a known-answer test** (`tools/metrics/test_metrics.py`, plain `unittest`, discovered
   by `make metrics-pytest`; **check with `-v` that every test is collected** — arena shipped four bare functions
   `unittest discover` never ran, `workstreams.md` Invariant 0):
   - **Windowed displacement efficiency**: net displacement / path length on a 4 s sliding window (`WINDOW_S` kept, so
     the round-8 threshold is a special case: efficiency < 0.25 with path ≥ 8 m *is* `oscillating`). Known answers:
     a straight line at constant speed → 1.000 in every window; a pure 8 m-out-2 m-back shuffle → the hand-computed
     value; a semicircle → its chord/arc.
   - **Signed cusp density**: sign changes of the along-path velocity per agent-minute, from positions (not from
     `gear`), with a speed floor so a stationary unit's jitter is not a cusp; split *ordered* (a reverse order or a
     `face` creep in the log's `order_verb`/phase) from *unexplained*. Known answers: a K-turn → exactly 2 cusps; the
     shuffle above → one per leg; a straight line → 0.
   - **Spectral arc length** of the speed profile (Balasubramanian 2012/2015): the arc length of the normalised
     Fourier magnitude spectrum of `speed_mps` over a window, more negative = jerkier. Known answers: a constant speed
     → the analytic value; a sine-modulated speed at one frequency → a value you derive by hand and pin; and a
     **fixed-length FFT with a fixed window** so the number is deterministic across machines.
   - **Affine formation residual** (Zhao 2018): per element per tick, fit the affine map from the nominal slot
     geometry to the actual positions (least squares, closed form) and report the residual RMS — zero for a rigid
     translation/rotation/shear of the nominal shape, positive when a unit has left its slot. Known answers: a
     translated wedge → 0; a sheared wedge → 0; one unit displaced 3 m → the hand value.
   Print every metric with its window, sample count and the number of units, and refuse (do not silently zero) a log
   shorter than one window.
3. **The positive control: reproduce round 8's finding.** Re-run the archived configuration **on builder0 at
   `aa984edd`** (`git worktree add` a detached checkout of that commit inside your worktree's `build/`, or ask the
   orchestrator for a slot window; **one `make remote` per worktree at a time**, and the recorded tree needs your
   emitter, so cherry-pick the emitter commit onto a throwaway branch from `aa984edd` and say so):
   `make remote T="nav-fight-maps FIGHT_MAPS='yard boneyard pit boulevard' FIGHT_BUSY_LEVELS=0 NAV_FLAGS=--trajectory=…"`,
   then `make metrics` over the four logs. **Pre-registered bar, written here before the run:** displacement
   efficiency's `oscillating` special case reproduces **5.3–7.2%** on the four maps within ±0.5 points per map with the
   same per-map ordering (yard > boneyard > pit > boulevard), **and** the continuous metric says something the
   threshold could not: report the distribution of window efficiencies per unit type, and whether the scout is the
   shuffler (round 8: scout 0.68 `net_over_path`, rig 0.95, `research_catalog.md` A8 row). If the numbers do not
   reproduce, the first suspect is the arm (`NAV_FIGHT_ARM` line — lesson 147, prove the arm), the second is the
   commit, the third is the metric. Write the result into `_agents/streams/references/round9/metrics/` with a README
   row per file (what, commit, machine, headline, caveat — lesson 31, from the note not from memory), including the
   trajectory logs themselves if under ~20 MB each (else the per-map summaries plus the exact reproduce line, and
   **run the reproduce line once from the README to prove it runs**, lesson 44).
4. **`make metrics` and `_agents/metrics.md`.** `make metrics LOGS=…` prints the four metrics per unit type and per
   element, `--json` for tools, and `make metrics-pytest` is in your own `metrics-check`. `_agents/metrics.md` is one
   page: each metric's definition, window, units, the known-answer cases, what it can and cannot see, and the rule
   *"a falsifier that names cusp density, displacement efficiency, spectral arc length or formation residual is read
   from `make metrics` and no other tool."* **Then announce CP1 to the orchestrator** (SendMessage to the session in
   `~/projects/godot`; and write it in Status): *"CP1 ready — this commit is green, merge here: `<sha>`"*, naming the
   hash the full `make remote T=check` ran on. **Tell the orchestrator the day the format (item 1) is stable**, before
   the metrics are finished, so nav, squad and combat can start emitting; they build now and publish verdicts after
   CP1 merges.
5. **T1: parallelise `make check`.**
   a. **Measure first.** Run the serial `check` on builder0 with per-target wall-clock (wrap each target in
      `/usr/bin/time -f` or a `date +%s` pair inside a new `check-timed` that runs the same list) — commit, machine,
      concurrent load (`make worktrees` on the laptop; `ps` on builder0) all recorded. This is the *before*; without
      it the falsifier cannot be read. Also record peak RSS per target (`/usr/bin/time -v`), which sets the budget.
   b. **Dependency map.** Which targets share a port, a file in `build/`, `user://`, or a Godot import — `net-smoke`,
      `relay-smoke`, `lobby-smoke`, `combat-smoke` bind `SMOKE_*` ports (`local.mk` isolates *worktrees*, not targets
      inside one); `garage-smoke` writes a scratch save; `announcer-record-smoke` and `music-smoke` compute the sim
      hash (`workstreams.md` Invariant 2's note). Write it down before scheduling anything.
   c. **Schedule.** Run independent targets concurrently under a **derived** budget: total = `MemAvailable` /
      peak-RSS-per-run, capped by the port groups; derive it the way `slot.sh:58-70` derives slots — **never
      hard-code it** (lesson 148). Simplest workable shape: `check` becomes `$(MAKE) -j$(CHECK_JOBS) check-parallel`
      with explicit order-only prerequisites for the port-sharing groups, `-Otarget` so output is not interleaved, and
      each target's log kept whole in `build/check/<target>.log`. A failure must still print the runner's
      `N passed, M failed` and the wrapper's `>> remote: make check exited <N>` unchanged — the orchestrator reads
      those two lines and nothing else (lesson 28).
   d. **Timeouts.** Any `timeout N` that now fires under load is raised, and **each raise is a row in your merge
      notes: target, before, after, the measured time that justified it.** A timeout that kills a wrapper and leaves
      Godot running (`mk/core.mk:55-57`) is replaced by one on the Godot process itself.
   e. **Falsifier (pre-registered in `workstreams.md` T1):** full-`check` wall-clock on builder0 drops **≥ 50%**
      against (a), **zero new flakes over three consecutive runs** on the same commit, and `sim-baseline`'s and
      `determinism`'s hashes **bit-identical** to the serial run's. A faster check that flakes once is worse than a
      slow one — if a target flakes, find the cause (lesson 4: flaky under load is not a diagnosis) before touching
      the schedule.
   f. **Retire what the change invalidates**, the way nav did in `verification.md` after lesson 148: list which
      published wall-clock figures (timings inside smokes, `remote_builds.md`'s check durations) are no longer
      comparable, and update `remote_builds.md` with the new budget. **Announce CP3** with the green hash and the
      three-run table.
6. **Stretch — a progress heartbeat for `check`** (lesson 48): every minute, which targets are running, which are
   done, and elapsed time, on stderr, so a 40-minute wait is never indistinguishable from a hang.
7. **Stretch — offline objective plumbing.** Catalogue C7 needs a scalar per niche; write the one-paragraph note in
   `_agents/metrics.md` on which of the four metrics is fit to be an optimiser objective and which are diagnostics
   only (an optimiser pointed at a bad objective succeeds at the wrong thing — `game_design.md` *Ruling: offline
   compute*). No optimiser this round.

## How to verify

- `make lint`, `make metrics-pytest` (**read the collected count**), `make metrics LOGS=<fixture>` on the synthetic
  fixtures with the hand-computed answers in the README beside them.
- Item 3's re-run on builder0 with the pre-registered bar above; the arm proven from the `NAV_FIGHT_ARM` line.
- `make remote T=check` before every readiness claim — **never a filtered run** (lesson 45), **never through a pipe**:
  run it unpiped to a log, then read `>> remote: make check exited <N>` and the runner's `N passed, M failed`
  (lesson 28). One `make remote` per worktree at a time (trip-up 66); killing the local wrapper does not stop
  builder0 (lesson 15, trip-up 68). Budget 30–50 minutes while seven streams are live; a cold `make import` on a
  fresh remote folder needs `TANK_SQUAD_SLOT_TIMEOUT=14400` (HANDOFF's two traps).
- For T1: the three-run table (commit, machine, wall-clock each, hashes each, flakes each) *is* the verification.
  Read every result line (lesson 10).
- **Every number carries its commit, its machine, its workload and its sample size.** The laptop is ~2.75× slower
  than builder0 and its glibc (2.39) has no baseline line, so `sim-baseline` silently skips locally.

## Don't touch

- Game behaviour of any kind: `game/ai/`, `game/tactics/`, `game/combat/`, `game/units/`, `game/tank/`,
  `game/theme/`, `game/control/`, `arenas/`. Your emitters are hooks in nav's probe and combat's runner, each a
  requested grant of a few lines; if an owner wants the hook themselves, give them the schema.
- The catalogue's mechanisms: you measure them; you do not build or tune them.
- `tests/baselines/sim_state_hash.txt` — the orchestrator records it (Invariant 2). Your CP3 proves it unchanged.
- Other streams' `mk/*.mk` beyond a raised timeout listed in merge notes. Shared files (`Makefile`, `mk/core.mk`,
  `tools/slot.sh`) get minimal edits, each named in merge notes.

## Waiting on the lead

Nothing. No paid generation, no design pillar. (If T1 needs a bigger builder0 slot budget than the derived one, that
is the orchestrator's call, not his.)

## Status

> # ROUND 9 CLOSED. CP1 and CP3 met and merged; backlog, both stretch items and every orchestrator-queued
> # item complete. Last merge `ec6fef46` (my `2746233b`). Working tree clean, nothing on builder0.
>
> **CP1 (A12) `ae9c65e1`** — the four trajectory metrics, contract S3, positive control reproduced round 8's
> oscillation finding to within 0.05 points against a ±0.5 bar, and found that the shuffler is the WHEELED
> hull, not the light one. **CP3 (T1) `0d4e5ef1`** — `check` parallel and sharded, 2820 s → 837/882/882 s
> (−70%/−69%/−69%), three consecutive greens, hashes identical; `REMOTE_SLOTS` LOWERED to 3 on measurement.
>
> **The last check: `2746233b`, builder0** — `>> remote: make check exited 2`, `1548 passed, 1 failed`,
> 5 shards over 219 files, 1123 s, `sim-baseline 1e90f69e5d6fcc46 (baseline unmoved) | determinism
> 253adefeec657df1`, `16 passed, 2 FAILED, 0 NOT RUN [test x5, lint -P6, 2 at once, builder0]`, markers
> agreeing, no cascade, **`engine: 0 errors, 0 warnings`**. The two reds are main's known pair.
>
> ### The one finding to carry into round 10
> **Two AI scenarios were passing on a neighbour's leaked navigation state.** Four runs split exactly on
> whether the drain completed between scenarios, not on the box:
>
> | tree | drain completed? | count | `artillery_stays_dug_in` + `base_of_fire_keeps_firing` |
> |---|---|---|---|
> | `4dba0b53` | **no** | `43,1,3,0` | PASS |
> | `0870877f` ×2, `2746233b` | yes | `41,3,3,0` | FAIL |
>
> They fail in 0.6 s and 1.4 s, so not load. Routed: artillery → combat, base-of-fire → squad's round-10
> brief. **`tests/baselines/ai_scenarios_count.txt` is still `42,2,3,0` and is the orchestrator's to
> re-record from main once combat's tip lands** — two records an hour apart would each be true of a
> different tree.
>
> ### What a fresh agent should know about this tooling
> - `make round-status` — every worktree vs main, the box, the baselines, and whether each branch's base is
>   covered by `main-checked`. `make remote-status` for one folder.
> - `make remote` refuses to rsync over a live run of its own, verifies the copy-back by sha256, and mirrors
>   (`--delete`, `*.log` protected). `--quiet` holds every slot and ends in `QUIET WINDOW: HELD | NOT USABLE`.
> - `check` keeps going and reports PASS / FAIL / **NOT RUN** per target with the schedule it ran under.
> - `lint` carries two liveness probes and fails if the checker reports nothing.
> - `make sim-baseline-adopt` reads twice, refuses a disagreement, merges rather than overwriting.
> - **Every gate refuses to record a baseline without a REASON**, and every shell tool has a `tools/test_*.sh`
>   suite in `check` (231 tests) — `make shell-tools-test`.
>
> ### The two patterns worth more than any of it
> **1. An absence that has something plausible to say.** `lint` over zero files, `check-hashes` on absent
> data, a blank `QUIET WINDOW` reading HELD, `0 passed, 0 failed` exiting 0, a commit subject standing in
> for a check verdict, a count of occurrences labelled "tests". The blank absence gets noticed; the
> plausible one does not.
>
> **2. A fix at one layer defeated by a layer above it that was never in the picture.** make expanding `$`
> before shell quoting (three times), a pipeline reporting `tail`'s status, `$(date)` resetting `$?`, a tag
> object interposing between a ref and its commit, six call sites landing in the wrong parameter, and a
> scenario runner still calling `teardown()` after the seal. **In every one the code was correct about the
> thing it was looking at and wrong about what it was looking at.** The rule that follows: *after a
> signature change, read every caller, not every conflict.* I wrote that down and then broke it an hour
> later in a file I had just edited.
>
> **And the one that cost the most: three of my own test suites were green here and red on the box**
> — `TANK_SQUAD_SLOT` set inside `check`, fixed sleeps on a loaded box, no `.git` on builder0. Every one
> surfaced only because the suites run inside `check` rather than by hand. A guard exercised only where it
> is easy passes for the wrong reason.


> ### ✅ CP1 MERGED (`ae9c65e1`). CP3's falsifier MET at `0f811c1c` — ready to merge.
> **Green commit: `0f811c1c`** (`>> remote: make check exited 0`, three consecutive runs). Commits above it are
> **documentation only** (`git diff 0f811c1c..HEAD` touches `_agents/` and nothing else).
>
> | run | wall-clock | vs serial 2820 s | jobs × shards | tests | sim-baseline |
> |---|---|---|---|---|---|
> | serial (a) | 2820 s | — | 1 × 1 | 1310 / 0 | `04414f5d6a6dfa7c` |
> | parallel 1 | **837 s** | **−70.3%** | 2 × 5 | 1310 / 0 | `04414f5d6a6dfa7c` |
> | parallel 2 | **882 s** | **−68.7%** | 3 × 6 | 1310 / 0 | `04414f5d6a6dfa7c` |
> | parallel 3 | **882 s** | **−68.7%** | 3 × 6 | 1310 / 0 | `04414f5d6a6dfa7c` |
>
> Full evidence, both denominators, the ordering proofs and the two bugs the series caught:
> `references/round9/metrics/t1-cp3.md`.
>
> **Owed, in order:** ~~(1) `ai-scenarios-check` into `CHECK_TARGETS`~~ (`fbf2af95`); ~~(2) `determinism`'s
> truncated verdict line~~ (`c6cafa42`, `make check-hashes`); (3) nav's A6 control-arm logs, to be read once
> they emit `corridor`.

> ### ⚠ 2026-09-20 10:32 — MY BRANCH IS NOT GREEN, AND NEITHER IS `main`. THE FAILURES ARE NOT MINE.
> Check on `fbf2af95`, builder0, 1011 s: **exit 2, 1481 passed / 4 failed, plus `ai-scenarios-check`.**
> `git diff --stat main...HEAD -- game/ tests/` is **empty** — this branch differs from `main` only in
> `tools/metrics/`, `mk/core.mk`, `Makefile`, `tools/remote*.sh` and `_agents/`. Every failure below is
> `main`'s; `fbf2af95` only made three of them visible. Reported to the orchestrator 10:50.
>
> **`ai-scenarios-check` 45,0,2,0 → 42,3,2,0 on its first run inside `check` — lesson 159, paid off:**
>
> | scenario | measured |
> |---|---|
> | `dodge_rate::who_dodges_and_how_often_they_try` | **dodging has stopped.** ifv and tank × 3 seeds: 431–514 ticks with a round inbound, **0 dodging, 0%, every hull, every seed** |
> | `cp2::a_scout_works_onto_a_tanks_engine_deck` | the scout fights fine (13 hits / 14 shots) and **0 of 13 land on the deck**. Its `x3m` control arm fired **nothing at all** (0 shots) |
> | `suppression::holding_the_aim_point…` | held 0.29 / density 1.02 / 161 rounds vs tracking 0.12 / 0.28 / 6 — ordering right, margin below its bar |
>
> Window `1cb2fda9..main` holds combat's `55b0de58` (dwell timer retired, A2), feel's `d8a107b5` (collider
> measured stowed) and `1dc2302f` (the 5 cm spawn lift). **Guess, labelled as one:** rows 2–3 are
> geometry-shaped and HANDOFF says the boxes are mid-handover, so scale's re-derivation may clear them; row 1
> is not geometry-shaped and I would not expect it to.
>
> Also red, all `main`'s: `test_theme_unit_scale`, `test_units_scale` (the box handover, documented),
> `test_match_spawns_and_results` (the y=0 spawn contact, ruled but not landed), and
> `test_theme_city_block::test_an_unknown_colour_name_is_deterministic_rather_than_a_dice_roll` — **that
> last one I cannot find written down anywhere and it may be new.**

> ### The lint gap: my structural hypothesis was WRONG, and the probe said so
> I argued the root cause was that a per-file `--check-only` cannot see an error that only appears when the
> project compiles together, and recommended a whole-project pass. **The probe on builder0 (`b839495c`)
> refutes it.** Verbatim, four arms:
>
> | arm | result |
> |---|---|
> | 0 positive control (blatant syntax error at the same `res://` path) | `Parse Error: Unterminated string.` — the experiment is valid |
> | A self-contained 12-line ternary, nothing from the project | `Cannot infer the type of "my_map" …` |
> | B real `movement.gd` at `bffdea0f`, class cache present | `Cannot infer the type of "my_map" …` |
> | C same, class cache moved aside | `SimClock not declared` + knock-on constants (different errors, not fewer) |
>
> So the checker sees this class fine, with or without the cache: **the green run never checked
> `movement.gd`.** That is the silent-pass hole, closed at `2e73a05e` (no output at all / killed by a signal
> / blind for the whole run). **No whole-project pass was built** — it would be a second forty-second gate
> justified by a guess I now know was wrong.
>
> The probe paid for itself twice: arm 0 proved `res://build/…` resolves, which is the uncertainty that made
> me defer the stronger self-test. `lint` now carries **two** liveness probes — the eight baselined
> artefacts (catches a wholly blind run) and a synthetic type-inference error whose finding is REQUIRED
> (catches a checker that can reproduce yesterday's findings but not see a new one).
>
> ### `check` keeps going, and check4 measured what that is worth
> `>> check: 16 passed, 2 FAILED, 0 NOT RUN` on `0269e7b0`, against **check3's 10 of 18** under the old
> behaviour — one failing shard used to abandon seven other targets with nothing in the log saying so.
> Summary cross-checked against the markers: 18 started, 16 done, 2 failed, 0 never started. They agree.
>
> ### `make test FILTER="a|b"` exited 127, and quoting alone would have been worse
> The filter is a substring, so a quoted `a|b` matches nothing — and the runner printed `0 passed, 0 failed`
> and **exited 0**. **A filter that matches no tests is now a failure**; `|` means alternation; `'` and `$`
> are refused by name. `$` was found by the test, not by me: I quoted against the shell and **make had
> already expanded it** (`FILTER=$HOME` arrived as `OME`).
>
> **The general form, four instances today:** a fix aimed at one layer defeated by a layer above it that was
> never in the picture — make's expansion beating shell quoting, a pipeline reporting `tail`'s status,
> `$(date)` resetting `$?`. And separately, three times: *a test asserted something about its environment it
> had never checked* (`TANK_SQUAD_SLOT` set inside `check`, fixed sleeps on a loaded box, no `.git` on the
> build box). Every one surfaced only because the suites are IN `check`.

> ### Orchestrator's post-backlog tooling block: three items, all in, one check outstanding.
> | commit | what | the finding it produced |
> |---|---|---|
> | `8c5bb14a` | `make sim-baseline-adopt` | **the hand `cp` DELETES other machines' baselines** — `build/sim_state_hash.txt` holds one line, and the symptom where it was deleted is `sim-baseline SKIPPED`, a skip not a failure. Also folded three copies of the hash read into one `SIM_HASH_READ`. |
> | `dcf4d242` | `--delete` copy-back, `*.log` protected | `--delete` would unlink a wrapper log **while its redirect is open** |
> | `26c6b1e5` `1e5972e4` | `make round-status` | **six slots held on builder0 at load 15.70** where `REMOTE_SLOTS=3`; and see below |
>
> **`round-status` found a real thing and got a second thing wrong on the same run, and the second is mine.**
> I flagged `godot-feel` and `godot-nav` as "work but no slot" and passed it to the orchestrator as something
> to look at. **They were QUEUED.** A queued run has already `cd`-ed into its folder — the exact reason the
> live-run guard covers the queue — so processes-without-a-slot is the *healthy* state while a stream waits.
> A tool that turns a normal state into a finding is worse than one that says nothing, because someone acts
> on it. Fixed: a queued run holds a `slot.sh` ticket, so the three states are distinguishable, and only
> "no slot AND no ticket" is flagged, worded as the uncertainty it is rather than as an accusation.
>
> The six-slot observation stands and the part worth keeping is that **the shard count is derived from free
> memory at launch**, so a run that starts into a crowded box stays slow for its whole duration, not only
> while it is crowded.
>
> 142 shell tests over six suites; `metrics-pytest` 138.

> ### Backlog and both stretch items COMPLETE. Last check `dd6f84ca`: exit 2, and the red was mine.
> builder0, `1499 passed, 3 failed`, 1000 s, 4 shards over 214 files, `sim-baseline 1e90f69e5d6fcc46`
> (unmoved), `determinism 253adefeec657df1`. **Both new features proved themselves in it:**
> `ai-scenarios-check: 42 passed, 2 failed, 3 pending, 0 unexpectedly passing (non-pending counts 42,2
> unchanged)` — green, the coin out of the gate, the two live regressions still visible to scale; and
> `engine: 0 errors, 2 warnings`, with `test_theme_city_block` reading `0 engine errors, 2 engine warnings`
> and naming both — the exact case `expect_warning` exists for.
>
> **The red was `shell-tools-test`, and it is this round's lesson pointing at me.** Six of twelve slot tests
> and one quiet-window test passed on an idle laptop and failed on the box: `slot.sh` short-circuits when
> `TANK_SQUAD_SLOT` is set, and `check` runs inside a slot, so every slot assertion exercised nothing; and my
> fixed sleeps were a property of an idle machine. Fixed at `bf2686ac` (unset the slot vars, poll instead of
> sleep). **A guard exercised only where it is easy passes for the wrong reason** — and I only found out
> because I put the suite in `check` rather than running it by hand.
>
> Not mine, `git diff main...HEAD -- game/` empty: `test_match_spawns_and_results` (the y=0 spawn contact)
> and `test_assets_pipeline::test_committed_generated_themes_meet_their_contracts`, which I have not seen
> documented anywhere.

> ### Earlier: waiting on the box (held quiet for feel and show).
> `bac84a6f`'s check, for the record: builder0, `>> remote: make check exited 2`, **1481 passed / 4 failed**,
> 993 s, 5 shards over 212 files — the same seven failures as `fbf2af95`, reproduced exactly. **`make
> check-hashes` printed on real data for the first time**, which closes CP3's one inferred criterion:
> `>> check: hashes on builder0 | sim-baseline 2d5215a8a0a59ded (baseline unmoved) | determinism
> 253adefeec657df1` — `determinism`'s state_hash had never reached a log at all.
>
> | commit | what | verified |
> |---|---|---|
> | `e3a91460` | `make remote` refuses to rsync over a live run of its own | **on builder0**, against a live 27-process check |
> | `cc58b4ad` | the ai-scenarios gate, on the non-pending counts | 20 fixture tests; **baseline not yet re-recorded**, so the gate stays red |
> | `305878b3` | engine warnings told apart from errors; `expect_warning` | **not parsed** — GDScript, no local Godot runs |
> | `0826d823` | `--quiet`: a timing run holds the box and judges its own window | 76 shell tests; remote script rendered and parse-checked |
>
> **Three defects found by tests for features that had not shipped yet**, two of them pre-existing and
> shared:
> 1. **`slot.sh` could not release its slot when killed.** bash defers a trap until the foreground command
>    finishes, so `kill` on a slot holder did nothing until the work finished by itself. This is the whole
>    of remote_builds.md's stale-`.owner` entry, which had been written up as an operator mistake; the
>    entry is rewritten. Work now runs in the background under an interruptible `wait`.
> 2. **Killing a slot holder left its work running** — the slot came back while the Godot under it did not.
>    Now killed as a tree, walked by parent, never by pattern.
> 3. **My own `QUIET WINDOW` verdict printed HELD for a file with zero samples.** `grep -cv X || echo 0`
>    fires its fallback exactly when the count is zero, so the variable became `0\n0`, the integer test
>    errored, and the guard was skipped. The round's recurring defect, inside the code written to prevent
>    it, defaulting to the reassuring answer.
>
> **A6's control arm is read — the last owed item — and the pooled figure stands.** From nav's scratchpad
> copies (**not** from `build/`, see below): yard 0.304/0.631, pit 0.321/0.595, terminus 0.331/0.738,
> **pooled 0.3203 (active 0.6622) over 96,054 active ticks — reproduces the earlier figure exactly.**
>
> | map | commit | off_corridor | active | eff_mean | cusp/min | sparc |
> |---|---|---|---|---|---|---|
> | yard | `c025bc6b` | 0.304 | 0.631 | 0.681 | 43.10 | **−2.013** |
> | terminus | `5369bd13` | 0.331 | 0.738 | 0.660 | 69.14 | **−2.013** |
>
> **`cusp/min` swings 60% between the two maps with no treatment applied; `sparc` is identical to three
> decimals.** A claim meant to survive the rotation should be pre-registered against SPARC and the
> off-corridor pair — cusp density is mostly measuring the arena. The two commits differ by one Status file
> and no code, which the mixed-commit banner flagged and its own printed command settled.
>
> **One flipped bit, and I got its cause wrong the first time.** `build/metrics/p7-pit.jsonl` on this laptop
> has `0x78` `x` → `0xf8` at line 143,873 of 273,578; nav's copy is clean and the same length to the byte. I
> reported the file as unusable and the pooled figure as unreproducible; **both were wrong** — nav kept
> copies out of `build/`. And the mechanism is not the stale-artefact story it looked like: the `build/`
> copy's **mtime never changed**, so no rsync rewrote it. The byte changed under a file nobody touched, on
> this laptop. The transfer is exonerated for this one; the stale-`build/` problem nav found is real and
> **separate**, and this file is not an instance of it.
>
> Both are now guarded anyway: the copy-back mirrors the run (`--delete`, with `*.log` protected so a live
> redirect is never unlinked) and verifies a sha256 manifest the box writes. That localises the next flip;
> it does not prevent one. **The loud failure was the lucky case** — in a digit instead of a key name it
> would have read as a valid coordinate, and no per-line checksum exists to catch that.

> **Corrected by combat, and it was my error to make:** I reported `scenario_dodge_rate` to the orchestrator
> as a regression without opening the file, whose own header says KNOWN-FAILING since CP4 and "Not in make
> check". The gate had inherited a ~2% coin as its expectation. A baseline records whatever was true the
> instant it was taken, **including luck**.

> ### `e3a91460` — `make remote` refuses to rsync over a live run of its own (trip-up 66, enforced)
> Requested by the orchestrator after it voided nav's check on `96bbf38e` and scale's 62-minute fairness run
> in one morning. **Verified against the live box:** `tools/remote.sh --status` listed my own running
> 27-process check out of `/proc` with start times, and `tools/remote.sh metrics-pytest` refused it (exit 9,
> *"nothing was synced and nothing was run"*) — the old script would have destroyed that run.
> **/proc decides; the marker is printed, never believed** — a second `.owner` file would have been the
> stale-`.owner` bug again, locking a stream out of the box until a human deleted a file. Only the launch
> window (rsync started, no process yet) trusts a file, bounded by `REMOTE_CLAIM_TTL=300` under a `flock`.
> Fails open, loudly. `REMOTE_FORCE=1` prints the run it destroys. 36 known-answer tests, ~1 s, no Godot,
> now `CHECK_TARGETS` #18. Its own check is chained behind the `bac84a6f` one.

### Done

**CP1 (A12) is complete and its acceptance is met. T1 is measured and built; its falsifier run is in flight.**

| # | item | state |
|---|---|---|
| 1a | the log format + reader | **done** — `tools/metrics/FORMAT.md`, `trajlog.py` |
| 1b | the reference emitter + both hooks | **done** — `trajectory_log.gd`, nav's probe (+6 lines), combat's runner (+7) |
| 2 | the four metrics, known-answer tested | **done** — `metrics.py`, 91 tests, every answer derived on paper |
| 3 | the positive control | **done and PASSED** — see below |
| 4 | `make metrics` + `_agents/metrics.md` + announce CP1 | **done**; announced to the orchestrator and every stream |
| 5 | T1 parallelise `check` | (a) measuring now, (b)–(d) built, (e) falsifier run next |
| 6 | stretch: progress heartbeat | not started |
| 7 | stretch: offline objective note | **done** — in `_agents/metrics.md` |

#### The positive control (item 3) — the bar is met by a factor of ten

Re-ran round 8's recorded configuration at the recorded commit on the recorded machine: builder0, tree `1422acd9`
(= `aa984edd` + the emitter and a one-token `NAV_FLAGS` pass-through, throwaway branch `tmp/metrics-r8-control`,
**not for merge**, the orchestrator will delete it at round close), `nav-fight-maps`, attack_move, Condemned vs
Condemned, seed 3, 120 s, busy 0, budget 6500. Arm proven live before any number was read: `NAV_FIGHT_ARM
commit=true fixed_style=standoff avoidance=true station=true off=[]`, matching the archived brief.

| map | round 8 published | the probe, this run | A12's tool, this run | delta |
|---|---|---|---|---|
| yard | 7.2% | 7.2% | **7.16%** | −0.04 pt |
| boneyard | 6.6% | 6.6% | **6.65%** | +0.05 pt |
| pit | 5.8% | 5.8% | **5.81%** | +0.01 pt |
| boulevard | 5.3% | 5.3% | **5.30%** | +0.00 pt |

Bar was ±0.5 points per map with the ordering preserved. The probe's counter and my tool come from the **same
run**, so commit, machine, seed and load are not confounds between them; under-way denominators agree to 0.08%
(one frame). Replays (4 × 5 MB gzipped), reports and each run's `NAV_FIGHT` line are in
`_agents/streams/references/round9/metrics/`, with the reproduce line run from the stored paths to prove it runs.

**What the continuous metric says that the threshold could not** (yard, GREEN, attack_move):

| unit_id | units | eff mean | eff p10 | oscillating | cusps/agent-min | SPARC |
|---|---|---|---|---|---|---|
| ifv | 7 | 0.624 | 0.250 | 12.1% | 35.8 | −2.23 |
| lancer | 6 | 0.619 | 0.216 | 9.4% | 34.8 | −2.10 |
| tank | 21 | 0.798 | 0.388 | 4.9% | 7.4 | −1.94 |

1. **The shuffler is the WHEELED hull, not the light one.** This roster fields no scout, yet reproduces round 8's
   A8 shape exactly — so it is a locomotion effect. squad has re-aimed A8/A9's measurement design on it and nav
   has taken it for A11's lattice.
2. **56% of all reversals are the wheeled creep, and they are now named** (665 creep / 234 ordered / 293
   unexplained of 1,192). `tank` produces **zero** creep cusps. Round 8's gear-flip counter read the controller's
   labels and had to call a third unexplained; cusp density reads the motion.
3. **The threshold understates it ~4×**: a tenth of every wheeled unit's windows sit at or below 0.25 efficiency.
4. **27,500 tank windows refused, not scored** (station-holding hulls that never moved).

**Which statistic is robust, recorded so nobody pre-registers on the wrong one:** the oscillating SHARE is (0.05
points across two independent implementations). `oscillating_units` is NOT — one unit on yard flips between 27 and
28 with a ±1-sample change in window length while the share holds.

#### T1 (item 5): the measurement reframed the work

**`test` is 2388 s of a 2584 s check — 92% of it.** Full serial profile, builder0, `c21d0256`, 12 cores,
12.4 GB available, load 0.42, 5 other Godot processes (`build/check/timings.tsv`, copied into references):

| target | s | peak RSS |
|---|---|---|
| **test** | **2388** | 427 MB |
| announcer-check | 80 | 252 MB |
| audio-check | 30 | **919 MB** (the ceiling) |
| army-loop-smoke | 24 | 272 MB |
| combat-smoke | 19 | 250 MB |
| determinism / relay-smoke | 11 each | 257 / 249 MB |
| garage-smoke | 7 | 266 MB |
| net-smoke / sim-baseline | 4 each | 250 / 273 MB |
| broker-smoke / lobby / match-smoke / match-pytest | 0–2 each | 17–86 MB |
| **TOTAL** | **2584** | |

**Round 8's framing was aimed at the wrong thing.** *"The targets in check are largely independent, run them
concurrently"* saves under 3 minutes out of 43. **The suite is the check.** So `tests/run_tests.gd` gained
`--shard=I/N` (round-robin over the sorted discovery order; unsharded is byte-identical including its final line;
shards print `SHARD i/n: …` and never the bare line, so a sharded run still has exactly one `N passed, M failed` —
the total, summed by the recipe, which refuses if fewer than N shards reported).

**Budgets from the measurement, not from round 8's "~735 MB a Godot run"** (more than twice too pessimistic):
CHECK_JOBS 2200 → 1000 MB a target; LINT_JOBS 250 MB (a `--check-only` peaks at 200–205 MB, not 735 — it parses
and exits without building a world); TEST_SHARDS 500 MB. All three via `tools/slot.sh --jobs`, which now divides
the **memory** budget by the live slot count — after T1 a check is 6–8 processes, so raising slots and the inner
fan-out together is how a 95%-idle box goes straight to OOM. Cores are deliberately *not* divided: this work is
latency-bound, which is the finding.

**`REMOTE_SLOTS` 6 → 3, deliberately fewer**, with the measured table in `remote.sh`. Throughput is the same at
any slot count; **latency per check scales with it**, and latency is what eight streams wait on. Six slots would
also land the check *on* the ≥50% bar rather than clearing it.

**Two bugs found by measuring, both shipped fixed:**
- **`lint` checked ZERO files on builder0, for everyone, and said "all scripts parse".** `git ls-files` cannot
  answer there (`remote.sh` excludes `.git/`; in a worktree the `.git` *pointer file* travels and its gitdir does
  not), and a failing command substitution in a `for` word list does not trip `set -e`. **Every green that rested
  only on `make remote T=check` was not parse-checked.** Now: a `find` fallback (verified to return the identical
  531 files), an empty list is a loud failure, and the success line carries the count.
- **`make lint` on `main` is red**, for 5 files / 8 lines, *all* `--check-only` isolation artefacts — verified to
  survive a completed `make import` and a serial re-check, so not the cache symptom the lock guards. Two
  mechanisms: a scene cannot resolve the script currently under check (`tank.tscn` names `tank.gd` and
  `visual_slot.gd`), and a `class_name` static reads as missing when the global is unregistered (`Units.roster`,
  the exact case `mk/core.mk` records costing an evening). Fixed with `tests/baselines/lint_expected.txt` — a
  finding not in it fails; one that stops occurring is reported so the list can be tightened; every line carries
  its reason. **Green on builder0 in 94 s.**

**Measured and deliberately deferred:** `make test` passes no `--fixed-fps`, so the suite advances physics at
wall-clock 30 Hz and mostly *waits*. Ten seconds of simulated time: **15.4 s without, 6.9 s with** — ~5× on the
simulated portion, on top of sharding. Not in CP3: sharding cannot change a test's *result* and this can, and two
speed-ups in one commit make a regression in either invisible. Its own checkpoint, written up in
`references/round9/metrics/t1-fixed-fps-followup.md` with the control (1261/0 unsharded at `c21d0256`).

**Also built, deliberately not yet in `CHECK_TARGETS`:** `ai-scenarios-check` (lesson 159), gated on a *change* in
the passed/failed/pending counts rather than on outcome, so the laptop-speed perf case does not redden the gate
while a new script error does. It joins `check` in its own commit *after* CP3's runs — adding a target between the
before and after would confound the falsifier.

### Decisions taken since the plan

7. **The emitter samples on `physics_frame`, not in `_physics_process`.** Every probe in the repo samples there,
   and `_physics_process` reads each hull *after* it moved this frame — a one-tick offset against the very
   counters the log exists to be comparable with.
8. **The emitter reads `TANK_SQUAD_COMMIT` before asking git.** `remote.sh` excludes `.git/` and exports it
   instead; without this the header said `commit=unknown` on builder0, the machine nearly every number we quote
   comes from.
9. **The optional columns are all-or-nothing PER COLUMN, not per set** — so `facing_arc` could be added without
   refusing the logs already written without it.
10. **`facing_arc`, not `facing_ordered`, is what classifies a cusp as ordered.** An order carries its facing from
    the moment it is issued, so treating that as obedience would excuse every real reversal on the drive to the
    gate — the opposite of control's concern and the harder error to catch. `facing_arc` is emitted as **null**
    until nav publishes it from `Movement.state()`, never `false`.
11. **The affine residual is fitted by orthogonal projection, not a 3×3 solve.** squad's A8 files an element into
    single file, whose slots are collinear: the old solve refused those elements outright, blinding the metric on
    A8's headline manoeuvre. The reference rank (3 shape / 2 file / 1 one spot) is reported beside every residual.
12. **`slot_x`/`slot_z` is the slot the LEADER ASSIGNED that tick**, never a reconstructed nominal shape — written
    into FORMAT.md as a requirement on producers, because against a nominal shape an element that had *correctly*
    filed through a defile would read as a large residual.

### Questions for the lead

Nothing.

### Requests to other streams

- **nav:** publish `facing_arc` (is the arrival arc live this tick) from `Movement.state(tank)` —
  `_approach_gate` computes it per tick and keeps it nowhere, and `game/ai/movement.gd` is nav's file. My emitter
  already reads the key and emits null until it appears; `make metrics` refuses an off-corridor verdict from a log
  whose arcs are null. **Nothing else is needed: the `facing` key nav confirmed is already read.**
- **squad:** the `decision_probe` hook is theirs to add once CP1 is on `main` (a preload of a missing path is a
  parse error, so it cannot land before the merge). Recorded in their Status as waiting on me.

### Known issues

- **⚠ I killed two other streams' `make remote T=check` wrappers (2026-09-20 04:39)** — control's and squad's.
  (I first reported three; combat checked their own and it was alive. Corrected with the orchestrator.) Stopping one orphaned
  run of my own, I used a kill loop whose `ps | grep` pattern matched **machine-wide instead of within this
  worktree**; control's and squad's local wrappers died with it. Their builder0 runs survived (killing a
  wrapper does not stop the box) but their `>> remote: ... exited <N>` line and `build/` copy-back did not. Told
  all three within minutes with recovery commands, and the orchestrator relayed it. **Every kill from here filters
  on `/proc/<pid>/cwd` against `$PWD` first and prints what it is about to kill** — which is what I had been doing
  correctly earlier the same night and skipped while hurrying to free the box. Proposed as a lesson jointly with
  control, who made the mirror-image mistake (a name-matched process tree read as their own worktree's).
  Related trap, hit **three** times while cleaning up, which is the part worth remembering: a name match tells
  you nothing about ownership **in either direction**. `pgrep -f <pattern>` matches your own command line
  containing the pattern, so *"is my script still running?"* answers yes either way; and `pgrep -f tank_squad`
  on builder0 matches command lines rather than working directories, which had me one step from telling combat
  their run was dead when 13 of its processes were alive. **Enumerate by `/proc/<pid>/cwd`, never by name** —
  the read-only version of this mistake is as costly as the destructive one, because it yields a confident wrong
  conclusion rather than an error.

- **`oscillating_units` is a fragile statistic** (above). The share is not; quote the share.
- **No producer emits element slots by default.** `nav-fight` installs Elements and nothing forms them; the match
  runner needs `--green-elements --rust-elements`. The affine residual therefore reads "no element/slot columns in
  this log" rather than 0.000 on a default run. Told to squad and combat.
- **My own trip-up 66:** I relaunched `make remote` while the first was still syncing, and two `rsync --delete`
  into one directory deleted each other's temp files. Both stopped by PID, one restarted. *A `pgrep | head -5`
  that shows other streams' runs is not evidence that yours is dead.*

### Merge notes (shared files)

| file | change | why |
|---|---|---|
| `Makefile` | `LIGHT_GOALS` gains `metrics metrics-pytest metrics-fixtures metrics-check`; `.PHONY` gains `check-timed` | the metrics tools are pure Python and run in 0.5 s; queueing them behind a 40-minute check is the waste that list exists to prevent |
| `mk/core.mk` | `CHECK_TARGETS` variable; `check` calls one sub-make with `-j -Otarget`; new `check-parallel`, `_cp-*` wrappers and three order-only chains; new `check-timed`; `lint` fans out with `xargs -P $(LINT_JOBS)` | T1. `check` expands to the same target list it always did (verified by printing the variable against the old line) |
| `tools/slot.sh` | a `--jobs <mb-per-job> [max]` subcommand ahead of the normal path | derive concurrency from the machine, one owner for the fact. Behaviour without the flag is byte-identical |
| `tests/nav/fight_probe.gd` | +6 lines (preload + one `TRAJECTORY.install`) | S3 emitter, pre-granted at launch; nav reviews at merge |
| `game/modes/match_runner_mode.gd` | +7 lines (preload + one `TRAJECTORY.install`) | S3 emitter, pre-granted at launch; combat has reviewed and asked to keep it |

**Timeouts: none raised, and the margins are why** (serial measurement against the limit already in the recipe):

| target | measured | its limit | margin |
|---|---|---|---|
| combat-smoke | 19 s | client `--timeout=60` | **3.2×** (the tightest in `check`) |
| relay-smoke | 11 s | client `--timeout=60` | 5.5× |
| net-smoke | 4 s | client `--timeout=35..90` | 9×+ |
| army-loop-smoke | 24 s | `timeout 600` | 25× |
| garage-smoke | 7 s | `timeout 600` | 86× |

Any raise will be a row here with target, before, after and the measurement that justified it. **Also checked:**
`mk/core.mk:55-57` warns that a `timeout` on a *wrapper* reaps the parent and leaves Godot children running — every
`timeout N` in `mk/*.mk` wraps the Godot process (or the exported server binary) **directly**, so there is nothing
of that shape to replace. Audited, not assumed.

**Branch to delete at round close:** `tmp/metrics-r8-control` (every commit on it says NOT FOR MERGE).
