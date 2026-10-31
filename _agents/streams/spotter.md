# Stream: spotter (find the moments units look dumb, and measure each fix by them)

> Read `_agents/orchestration.md` (the worker contract; lessons 350, 352, 353), `_agents/workstreams.md` **Round 48** (C48.2-C48.4 are
> yours; R48.3) and **Round 47** (R47.40, R47.48), your last brief `streams/archive/round47/spotter.md` (FINAL REPORT and *Round 48*),
> `streams/references/round47/spotter/batch1-classes.md`, `game_design.md` *His ML question*, *His spotter labels*, *His answer on spotter
> batch 2*. **Development tooling only, nothing ships in the game.** **You own:** `tools/spotter/**`, `tests/spotter/**`, `mk/spotter.mk`,
> `references/spotter/**`, `_agents/streams/references/round48/spotter/**`, the night shift's folders on builder3 (`~/spotter-night/`).
> **Read-only:** every census, trace and recording other streams write; a new per-tick row in the GAME is a request to the orchestrator.
> **Model:** Opus. **Machine:** builder3 (CPU fights in its light lane, yield to the full-check lock; the GPU for clips and training).
> **Seeds:** 13553-13744 (new batches); the night shift keeps 13121-13216 as the fixed before / after set. Dev 7001-7012.

## The lead's direction (verbatim)

2026-10-30: "is it time to start considering training models for CPU opponents? Or perhaps using machine learning to detect things in our
game for better development? (i.e. I think you mentioned detecting dumb looking computer behavior)"

2026-10-31 (morning): "I see there are 80 "looks dumb" cases for me to review. For 100% cases that I've checked, it does in fact look dumb.
THis is too much for me to review. Can we just assume that all of these results are in fact cases of units looking dumb?"

Also (2026-10-30): builder3 should be put to work when it is idle (nights, quota-low hours).

## Where things stand

- **Batch 2** (https://claude.ai/artifact/JWq9fmZ11eVbx68HoUofA9; main 2fc962aa6, builder3, ranks 31-100 + 10 hidden controls): he
  tapped 34, all flagged (ranks 31-78), all "dumb". The orchestrator labelled 31 more flagged clips "dumb" with `by: "assumed"`,
  `assumed: true` (C48.4). 15 stay for him: the 10 controls + 5 flagged (crossing-13124-Rust_Guns_5-31-41, locks-13122-Rust_Spears_1-13-23,
  locks-13121-Rust_Hunters_3-54-64, gorge-13124-Green_Hunters_2-45-55, gorge-13122-Rust_Spears_5-78-87). Over batches 1-2: 64/64 of his own
  taps on flagged clips are "dumb"; the controls' rate is unknown until he taps them.
- **The night shift** ran every seed 13121-13216 at main df9aacc1a by 08:40 2026-10-31 and has been idle since (the same commit and seeds
  repeat exactly). `make spotter-night-status` / `-push SHA=` / `-stop` / `-pull`.
- Ranker `tools/spotter/rank.py` (per-class non-parametric tail), `learn.py` waiting on labels, `labels.py` for precision by band.

## Backlog (in order)

1. **S1 batch 2's numbers:** export `clips` + `labels` (ArtifactData; the orchestrator can dump them for you), `labels.py`: precision by
   band on his own taps only, and with assumed labels separated. File any new classes from batch 2 (A-E or new) in
   `_agents/streams/references/round48/spotter/batch2-classes.md`. When he taps the controls, the base rate (C48.4).
2. **S2 the class rates at main df9aacc1a (C48.2):** per class A-E, moments a fight and signal crew-seconds a fight on the night set (13121-
   13216, 6 maps), with the classifier that assigns a moment to a class written down (so the before / after reads the same rule). Publish
   in Status and message the orchestrator: this is the "before" every owner's fix is read against.
3. **S3 class lists for the owners (C48.3):** for manoeuvre (B, C), engage (A, E), orders (D): the clip lines and per-second rows at main,
   batch 1 and batch 2 together. Send through the orchestrator the first hour.
4. **S4 the night shift follows main:** after each green main the orchestrator runs `make spotter-night-push SHA=`; your summary per night
   gives the class rates at that commit v df9aacc1a. Also make it keep builder3 busy on new seeds (13553-13744) when the fixed set is done.
5. **S5 his next judging page, ~15 clips** (C48.4): unflagged controls + a few flagged, blind, from a commit after the first class fix
   ships. Upload with `judge_docs.py`. A page only when there is a question his taps answer (the base rate; a new class).
6. **S6** `learn.py` v the hand ranker on held-out seeds once labels allow (~100 / 100 dumb / fine); ship the better one as the night's ranker.
7. **Stretch:** the shooter on hits in his recordings; turret v target bearing (census requests through the orchestrator).

## How to verify

`make spotter-*` targets on builder3; every clip reproduces its moment (`make spotter-clip ...`, drift <= 0.1 m); `make remote T=check` for a
hash you will NAME. Every rate with its commit, machine, seeds, maps, n fights.

## Don't touch

Everything in `game/**`, `native/**`, `arenas/**`, `tests/baselines/**`, other streams' censuses (read-only).

## Waiting on the lead

His 15 clips on batch 2's page (the controls) — no hurry.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
