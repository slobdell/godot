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

_(nothing yet)_

### Questions for the lead

Nothing. (The brief's *Waiting on the lead* is empty and nothing has changed that.)

### Requests to other streams

_(none yet — the two emitter hooks are pre-granted in `workstreams.md`; nav and combat review them at merge.)_
