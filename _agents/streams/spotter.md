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

**Report (2026-10-31 ~12:40 PDT, the spotter worker).** S1-S4 done; S5 waits for the first green main after a class fix merges;
S6 waits on "fine" labels (none yet). Full check: see *Green* below.

### Plan (order kept from the backlog; one-line reasons)
1. S1 batch 2's numbers (done). 2. S2 the class rule + the before at df9aacc1a (done; the rule had to come first because S3 and S4
read it). 3. S3 the owners' lists (done). 4. S4 the night shift follows main (done). 5. S5 his next page after the first class fix
(waiting). 6. S6 learn.py v the hand ranker (blocked on fine labels). 7. Stretch: census requests (written below).

### Done (every number: commit, machine, workload, n)
- **S1 batch 2** (page db exported 2026-10-31 ~12:30 PDT into `references/round48/spotter/batch2-db.json`; `labels.py` now splits
  his taps from `by: "assumed"`, gives precision by rank band and the controls' base rate; test_labels.py). Batch 2 = main 2fc962aa6,
  builder3, 24 fights. **His own taps: 34/34 dumb** (rank 31-50: 15/15, 51-75: 17/17, 76-100: 2/2); 31 assumed (C48.4); 5 flagged + 10
  controls untapped -> **base rate unknown** (he has not tapped a control). Classes from batch 2 in `references/round48/spotter/
  batch2-classes.md`: the rule puts 47 of 70 flagged clips in a class (E 18, B 11, F 7, C 7, D 3, A 1), 23 none; controls 0/10 classed.
- **S2 the class rule** `tools/spotter/classes.py` **classes v4** (= v3, A-E, + F placed last; **frozen this round**, R48.4: a change
  re-reads df9aacc1a in the same commit). Fixed thresholds, written at the top of the file. Order A, E, stuck-by-cause, C, B, D, F:
  A RETREAT >= 40 m from squad 3 s or reversing 5 s; E >= 5 of 8 s hit from beyond 1.05 x own range and not closing 10 m; STUCK
  (move, > 15 m to go, < 1 m in 5 s, 6 s) goes to its cause (RETREAT A, crew blocker B, terrain / prop C, else D); C blocked by
  terrain / no_path or on a prop 8 s; B blocked / yielding to a named crew 8 s, or a HOLD crew yielding 3 s; D nose > 100 deg off
  route 5 s, or a follower reversing / spinning > 40 deg/s 3 s; F direct fire, fire-at-will, enemy in sight within 0.9 x range, no
  shot >= 3 s, 8 s. B / E / F carry a cause split. Checked on batch 1 (1209a934f fights): 19 of his 30 hand-classed clips land in
  their class (A 4/4, B 7/9, C 4/5, E 3/5, D 1/7: batch 1's follow rows carry no goal). Tests: test_classes.py (each threshold
  caught, its near miss not; lesson 350).
- **The BEFORE (C48.2): main df9aacc1a, builder3, 576 fights = seeds 13121-13216 x 6 maps, 240 s showmatch, native.** Moments /
  flagged crew-s a fight: **A 0.14 / 0.5; E 5.58 / 23.3** (no answer 4.41, answering 1.17); **C 3.40 / 32.8; B 17.00 / 69.7** (held
  crew gives way 11.63, parked blocker 0.81, moving squadmates 4.55); **D 5.14 / 11.6; F 1.64 / 7.0** (support by fire 0.79, holding
  0.43, moving 0.27, ambush 0.16). By map: `references/round48/spotter/classes-df9aacc1a.md`. Baseline with per-fight counts (for
  the paired read): `tools/spotter/baselines/classes-df9aacc1a.json`. Relayed by the orchestrator. Engage's own read on the same
  fights is A 0.16 / E 0.70: A agrees; E is a different (broader) rule: any 5-of-8 s outranged exposure without a 10 m close,
  including crews in transit on a MOVE.
- **S3 lists** (`references/round48/spotter/`, df9aacc1a, 10 longest per class and per cause, each with `make spotter-clip` and its
  per-second rows): `list-B.md` (rows carry the named blocker's own phase / move / order at that tick: manoeuvre's ask), `list-C.md`,
  `list-AE.md`, `list-D.md`, `list-F.md`; built by `tools/spotter/class_lists.py` (`main` / `clips` modes).
- **Findings sent:** NEW class F (holds fire, enemy in sight and in range; R48.6: engage). His judged B clips are 9/11 "moving
  squadmates" while the main rate is mostly short "held crew gives way" (changed manoeuvre's next item). Candidates G (wanders off
  alone: wrong way + far from squad) and H (shot from behind, doesn't turn: 7 clips) for his next page.
- **S4 the night shift** (kit 9c446d11b installed on builder3): after each batch it runs the class rule over EVERY fight of the
  commit (any date folder) and writes `<date>/<commit>/classes/` + a SUMMARY.md section, **paired v df9aacc1a** on the fights both
  ran (after - before a fight, with se). A commit's finished seeds count across days (the same commit is never re-run on a new day);
  once 13121-13216 is done it runs **13553-13744**. Proven: test_night.sh 18/0 (cross-day skip, extra range); on builder3 the class
  step + summary over today's df9aacc1a folder (self-paired 0.00 on every class). `make spotter-night-pull` brings classes.* home.
  Not yet seen: an unattended batch with the new kit (the box was busy with checks at install).

### Waiting / blocked
- **S5 (gate: first green main after a class fix merges):** then `make spotter-night-push SHA=<it>`, read its paired class rates,
  and build his ~15-clip page: unflagged controls (~7) + 3-4 each of candidates G and H, blind, `judge_docs.py` (orchestrator's ask).
- **S6 (blocked: labels):** 95 dumb (64 his + 31 assumed), **0 fine**. learn.py needs ~100 / 100; fine labels can only come from
  his taps on controls / lower ranks. Each ~15-clip page adds at most ~7 negatives.

### Questions for the lead
- None blocking. His 15 clips on batch 2's page (the controls) are still the only read of the base rate.

### Requests to other streams (through the orchestrator)
- Stretch (census, game-side, not mine): per hit, the SHOOTER's crew name in the probe / his recordings' census (hit_dmg carries no
  source; `src` is always ""), and the turret's bearing v its target's bearing per crew-second (would sharpen F: a turret that never
  laid on the enemy v one that laid and didn't fire).

### Merge notes
- Spotter paths only: `tools/spotter/**`, `tests/spotter/**`, `mk/spotter.mk`, `_agents/streams/references/round48/spotter/**`,
  this brief. No Makefile edit.
