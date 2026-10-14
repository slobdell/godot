# Stream: sizing (every judged bar sized by its probe's measured noise: the smallest n that decides, variance-aware pass lines, early stopping; nothing in play)

> Read `_agents/orchestration.md` (the worker contract; lessons 292, 295–305), `_agents/verification.md` (*Timing in
> tests*, *Attributing a behaviour's cost*, *Positive controls*), `_agents/workstreams.md` **Round 30** (C30.1–C30.10,
> especially **C30.3** and **C30.10**) and its *Bars* blocks for rounds 27–29 (the judged tables are quoted there with
> their verdicts), `_agents/roadmap.md` *AT ROUND 29's CLOSE* (item 1 is this stream), and the three round-29 reports in
> `streams/archive/round29/`. **You own ONLY:** `tools/judge/**` (new), `tests/test_judge*.gd` (new),
> `_agents/judging.md` (new), `_agents/streams/references/round30/sizing/**` (new). You read, never edit, the judged
> tables in `streams/references/round27..29/`. **No builder0 series, ever** (C30.3): your material is what the rounds
> already measured. **Model:** this stream runs on **Fable 5.1** — his ask (2026-10-14).

## The lead's direction

His ask (2026-10-14): *"I have my weekly quota restored with now 0% Fable usage. Are there perhaps some deliberate hard
tasks we should give to some fable agents"* … *"hard or lingering problems that we can throw at Fable to mitigate any
bottlenecks in our project."* The bottleneck is builder0 (12 cores, 14 GB; loaded checks 53–60 min v 41 quiet; judged
series queue for hours); he deferred a second machine: *"I want to get more build machines, but I'll defer on that as
long as we can"* (2026-10-13). Traffic's round-29 measurement: on a shared box the lever is FEWER RUNS, not better
sharding. Every series this project runs is sized by feel (n = 18 an arm, three seeds × six ticks) and every guard is a
round number (+5 crews; ≤ +20 %).

What he will notice: nothing in play. What the project notices: the next bar a stream writes says "n = 12, se 1.9, the
guard is base + 2 se = +4" and cites your row, instead of n = 18 by habit; and a series that is decided after a third of
its runs stops there.

## Where things stand (main `0d35f215`)

The motivating cases (each has its table in `references/` or its block in `workstreams.md`):
- **M1's 75 s guard (round 29):** the bar said ≤ base + 5 at n = 288 crews a task; the CLICKED pair, where M1 never
  acts, moved the same class +10, and round 28's re-run on the same seeds swung ±17. The guard was below the noise.
  `references/round29/manoeuvre/m1_judged.txt`, round 28's `m1_last_attempt_drawn.txt`, `m0_hull_rest_base.txt`.
- **Traffic T3 (round 29):** all-in +23 % failed a +20 % line at n = 18; T1b (round 28) had one wedged run carry a whole
  table (lesson 302); round 28's T1 judged base-v-base rows exist (`references/round28/traffic/judged-j*`,
  `t1b-c*base*`): an A/A pair already measured. `references/round29/traffic/*.jsonl` + `verdict_*.txt`.
- **Brains B5c (round 29):** the off arm's yard cells "never in 7/12" against on 12/12 — a count line; B1/B2 side counts
  18/18 v 0/18 (`references/round28/brains_b1_judged_*.jsonl`, round 29's blocks); the arrive series 100/100 v 89/100.
- **Manoeuvre M4 (round 29):** pinned crew-s 2902 → 1040 "se 460" — the one bar line that quoted an se.
- **The jsonl formats:** one row per run with the case/seed/tick and every metric; `tools/compare_arms.py`,
  `tools/crossing_table.py`, `tools/hull_rest_table.py`, `tools/flank_probe_table.py`, `tools/facing_probe_table.py`
  read them (read these first: they are how a bar's numbers are produced today).
- builder0's cost of a run: a traffic-series case of 18 runs ≈ 20–40 min loaded; a hull-rest task of 288 crews ≈ 1 h;
  the judged M1 run (6 tasks × 2 arms) took ~2 h of the box.

## Backlog (in order)

**S1 — the inventory (a table, one row per judged line, rounds 27–29).** For every bar line that was judged: stream,
item, metric, its form (median / count / rate / paired difference), n (runs, crews), the pass line, the measured value
in each arm, the verdict, and — wherever the data allows — the NOISE: a paired se from the rows, the A/A swing where a
base-v-base pair exists (M1's clicked pair, T1b's base rows, B5c's off-arm cells), the between-seed v between-tick
variance. Write it as `references/round30/sizing/inventory.md` (+ the csv it is generated from, by a script in
`tools/judge/`). Mark every line where the pass line was INSIDE the noise.

**S2 — the per-probe n table (CP-N; deliver this first, within your first session, before S4–S5 are polished).** For
each probe this round's bars use (traffic-series's four cases; the hull-rest probe's tasks; the yard / Sumps / Terminus
cells; the arrive series; bridge-pooled; the ApproachStage / flank probe; manoeuvre-fights' kills/deaths/hit rate; the
Terminus census's arrivals and contact-ticks; pinned crew-seconds): the metric's noise (paired se per run, from S1's
rows), the effect its bar names (e.g. −25 % between-squad fast; ≤ +20 % all-in; ≤ +5 crews), and the smallest n (runs,
and how to spend them over seeds × ticks) that decides that effect at a stated power (say 80 %) and false-pass rate
(say 5 %), paired design. Where the data cannot say (no A/A), say so and say what two base runs would cost to find out.
Output: `_agents/judging.md` *The table* — one row per probe × metric, with n_today, n_needed, and the se the bar
should quote. **Tell the orchestrator the moment it is written (CP-N); the three game streams' bars cite it (C30.3).**

**S3 — variance-aware pass lines.** A written rule for each FORM of line this project uses: a guard ("not worse than base
by more than X") becomes base + k·se (paired) with k stated and the reason; a count line ("crews ≥ base − 2", "12/12",
"18/18 v 0/18") gets its binomial reading (what 12/12 v 7/12 means at n = 12; when 17/18 is a pass); a median line gets
its paired bootstrap interval; "within 2 se" gets its definition (which se, paired on what). Worked examples re-sizing
M1's 75 s guard, T3's all-in line and B5c's yard count, with the verdict each WOULD have had. Into `judging.md`.

**S4 — sequential (early-stop) judging.** A design for stopping a paired series early when the result is decided: a
group-sequential or SPRT-style boundary over the seed × tick grid in the order the runners already use, with its
false-pass and false-fail rates SIMULATED on rounds 27–29's rows (resample them; no new runs). State what fraction of
the round-29 judged runs would have stopped early and whether any verdict changes. Then the recommendation for the
runners: what `tools/compare_arms.py` (or a new `tools/judge/sequential.py` the runners call per row) prints after each
run — CONTINUE / PASS / FAIL with the boundary — and the one rule for when a stream may stop. The runners' code is
traffic's / brains' / manoeuvre's: you write the script and the rule; the orchestrator hands the call to the owners.

**S5 — the method doc and the tool.** `_agents/judging.md`: how to write a bar (the probe's noise → n → the lines →
pre-register → judge; the A/A pair a new probe owes before its first bar; the early-stop rule); `tools/judge/`:
`size.py` (given a probe's rows or its table row and an effect, print n and the guard), `inventory.py` (S1), `aa.py`
(read an A/A pair's noise from two base jsonl files), `sequential.py` (S4); each with tests that run in `make check`
(`tests/test_judge*.gd` calling the scripts on fixture rows, or a python test target in `mk/` — ask the orchestrator which
the check should carry; a pure-python target behind `make judge-test` wired into CHECK_TARGETS is the recommendation).
Numbers in the doc carry their source table and commit.

**Stretch:** the cost side: a table of what each round-29 judged series cost builder0 (runs × minutes) against what S2
says it needed; the saving in box-hours for a round like 29.

## How to verify

`make remote T=check` green with your tests in (C30.10); every number in `judging.md` reproducible by a `tools/judge/`
command on a file in `references/`; the orchestrator re-derives one row of CP-N by hand before relaying it. No Godot
runs. Light builder0 at most for `check`.

## Don't touch

Anything outside your four paths. The runners (`tools/compare_arms.py`, `*_table.py`, `mk/*.mk` series targets) are the
game streams': you propose diffs in your Status, the orchestrator relays.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current; CP-N announced the moment the table is written; the report at the top)_
