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

**In progress** (2026-09-20). Worktree `godot-metrics`, branch `stream/metrics`, started at `9f864474` (= `main`).

### The plan (worker contract step 2), smallest foundation first

| # | Step | Deliverable |
|---|---|---|
| 1a | The log format and its reader | `tools/metrics/FORMAT.md`, `tools/metrics/trajlog.py`, round-trip + refusal tests |
| 1b | The reference emitter | `tools/metrics/trajectory_log.gd` (mine) + a hook in nav's `fight_probe.gd` and combat's `match_runner_mode.gd` |
| 2 | The four metrics, known-answer tested | `tools/metrics/metrics.py`, `tools/metrics/test_metrics.py`, `make metrics-pytest` |
| 3 | The positive control | re-run of round 8's configuration at `aa984edd` on builder0, written to `_agents/streams/references/round9/metrics/` |
| 4 | `make metrics` + `_agents/metrics.md`, then **announce CP1** | `mk/metrics.mk`, `_agents/metrics.md` |
| 5 | T1: parallelise `check` (measure → map → schedule → timeouts → falsifier → retire), then **announce CP3** | `check-timed`, `check-parallel` in `mk/core.mk` |
| 6–7 | Stretch: a progress heartbeat for `check`; the offline-objective note | |

### Decisions taken where the brief left a choice

1. **Two readings of displacement efficiency, both shipped.** The *general* metric is every unit, every contiguous
   4 s window, ungated — a distribution. The *`oscillating` special case* re-implements round 8's gating exactly
   (only ticks under orders with flat distance-to-goal > 8 m; trail reset when the goal jumps > 3 m; numerator =
   full windows with path >= 8 m and ratio < 0.25; **denominator = all under-way ticks**, including those whose
   window is not yet full). *Why:* the round-8 share cannot be reproduced without that denominator, and the
   continuous metric is worthless if it is silently gated the same way. Both are printed side by side.
2. **Cusp sign from position + logged heading, never from `gear`.** Signed speed `s = sign(v · h) * |v|` with a
   0.5 m/s floor (`GEAR_SPEED`, so it is comparable with round 8's gear-flip counter). *Why:* it sees a reversal
   the controller never labelled, which is the whole point of a trajectory-space metric.
3. **SPARC on `|speed|`, not on signed speed.** *Why:* the DC term normalises the spectrum, and a shuffling hull's
   signed mean passes through zero, which would make the metric explode on exactly the case we care about.
   Reversals are cusp density's job; each metric has one job.
4. **SPARC is a fixed 128-sample window, zero-padded to a fixed 1024-point FFT, with a fixed cutoff of 20 rad/s** —
   not the reference's adaptive cutoff. *Why:* the brief requires a number that is identical across machines; an
   adaptive cutoff makes the answer depend on a threshold crossing. Pure-Python radix-2 FFT, **no numpy**, so the
   tool has no dependency `make check` does not already have.
5. **Affine residual is reported only for elements with >= 4 members.** *Why:* a 2-D affine fit has 6 parameters and
   3 points determine it exactly, so a 3-unit element's residual is identically zero and would read as "perfect".
6. **`.jsonl` plain, `.jsonl.gz` accepted by the reader.** The emitter writes plain (Godot's compression is not
   gzip); a big log is gzipped after the run.

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

#### T1 (item 5): what is measured, decided and built

- **(a) the BEFORE.** `make check-timed` runs the same targets in the same order one at a time, recording
  per-target wall-clock and peak RSS plus the machine, its cores, MemAvailable, load and how many other Godot
  processes were already up. `CHECK_TARGETS` is now ONE variable used by both `check` and `check-timed`, so a
  target cannot be measured and not run. Running on builder0 now.
- **(b) the dependency map**, read out of the recipes and written into `mk/core.mk` beside the code it justifies.
  Four constraints and no more: `import` (the only `.godot` writer, a shared prerequisite so `-j` builds it once);
  `SMOKE_NET_PORT` {net-smoke, combat-smoke}; `SMOKE_BROKER_PORT` {relay-smoke, lobby-smoke};
  `user://garage_scratch/my_army.json` {garage-smoke, army-loop-smoke}. Deliberately *not* constraints, with the
  reason: the sim hash (separate processes on a fixed tick hash identically — and CP3 proves it rather than
  assuming it) and `build/` logs (every target writes its own named file).
- **(c) the schedule.** `check` hands the list to one sub-make with `-j$(CHECK_JOBS) -Otarget`; the three
  exclusion groups are order-only prerequisites between `_cp-*` wrappers, so the chains live in `check`'s own
  block and `make combat-smoke` does not silently start running net-smoke for every caller forever. `CHECK_JOBS`
  and `LINT_JOBS` are **derived** from `tools/slot.sh --jobs <mb-per-job>`, which reads MemAvailable and nproc and
  keeps a quarter back — never hard-coded (lesson 148), and living in slot.sh because "how much can this machine
  take" is one fact with one owner.
- **`lint` now fans out, and this is the biggest single win.** Two things measured first, because the lint lock
  reads like a ban on any concurrency here and is not: (1) `--check-only` **never writes `.godot`** — snapshotted
  all 911 cache files, five passes, zero change; the exclusive writer is `import`, and re-reading the incident,
  the second `make lint` ran `import` FIRST, which is what corrupted the first lint's reads. (2) Serial and `-P6`
  give **byte-identical findings** — 24 files, 35 s → 11 s, and then repeated with a deliberately broken file so
  the comparison was not an empty one (lesson 147). At 1.82 s of Godot start-up × 531 files, serial lint was ~16
  minutes on the laptop. The lock stays: a second `make lint` still runs `import` underneath the first.

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

**Timeouts raised: none so far.** Any raise will be a row here with target, before, after and the measurement.

**Branch to delete at round close:** `tmp/metrics-r8-control` (every commit on it says NOT FOR MERGE).
