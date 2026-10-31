# Stream: spotter (find the moments where our units look dumb, so he doesn't have to play to find them)

> Read `_agents/orchestration.md` (the worker contract; lessons 350, 352, 353), `_agents/workstreams.md` **Round 47** (C47.1-C47.11 and
> R47.40, your stream's ruling), `game_design.md` *On machine learning* (top of the file), the 2026-09-19 re-decision (grep "What stays
> shut"), and *His ML question* (end of the file: his words and the plan you are carrying out). **This is a new, green-field stream:
> development tooling only, nothing ships in the game.** **You own:** `tools/spotter/**`, `tests/spotter/**`, `mk/spotter.mk` (new; one
> include line in the Makefile, listed in merge notes), `references/spotter/**`, `_agents/streams/references/round47/spotter/**`.
> **Read-only:** every census, trace and recording other streams write (`tests/manoeuvre/*census*`, `tests/route/route_census*`,
> `game/ai/noprogress_census.gd`, `tests/replay/**`, recordings under `references/`). A new per-tick row in the GAME (a census line you
> need) is a request to the orchestrator, never your edit. **Model:** Opus. **Machines:** builder3 (CPU fights in its light lane; its GPU
> RTX 5060 Ti 16 GB for clips and training; ONE full check + ONE series at a time, the full-check lock queues). **Seeds:** 13121-13216.
> Dev 7001-7012.

## The lead's direction (2026-10-30 ~22:40-22:50, verbatim)

"also while we're waiting on other agents, and now that we have builder3 up with a GPU, is it time to start considering training models
for CPU opponents? Or perhaps using machine learning to detect things in our game for better development? (i.e. I think you mentioned
detecting dumb looking computer behavior)"

"well aren't our existing workstreams already going to take a long while before completion? It's alreayd late into the evneing, I doubt
this round will finish before bed time. THis seems like a green field, brand new effort that generally doesn't conflict with other
workstreams. How about just starting an agent now?"

Memory: units must look smart and under his control; smart AI on both sides; a human is the only check for anything subjective.

## Where things stand

- **What "dumb" has meant in his playtests (game_design.md, rounds 37-47):** a crew nose-in to a building while its squad drives on
  (Locks Burners2_4); IFVs sitting "driving" with no progress at a bridge (Crossing Hunters); a hurt crew driving away from his attack
  target (Locks Hunters_4, RETREAT); tanks in range not firing (Crossing Guns_3); squads splitting far apart for one click; the camera
  far from his squad; outranged crews advancing into fire they can't answer (his Crossing gangs v syndicate, 6 shots v 358).
- **Detectors that already exist** (hand-written, each finds ONE class): the no-progress census (`--noprogress-census`, manoeuvre
  Bar M), route-census (driven v planned, reversed metres, held seconds, by class), the stall / aside / start traces, engage's
  attack-shot probe (held_line_s), the camera's gap census. Use their outputs; don't rewrite them.
- **Recordings:** his round-46 playtests in `references/round46/playtest/` (replays are his match only to ~11 s, R47.16: past that a
  replay is a STAGED read). CPU-v-CPU fights are deterministic per seed and replayable exactly.

## His follow-up (2026-10-30 ~23:40, verbatim)

"Basically we have this builder3 that will end up being idle during night hours or when you're not working, or when we're running low
on quota. I'd like to put these machine resources to work"

**So the deliverable is a NIGHT SHIFT, not only a session's work:** jobs that run on builder3 by themselves (no Claude session, no
quota) whenever the box is idle, and leave results a person or a fresh agent can read in the morning.

## Backlog (in order)

0. **S0 the night shift's frame, first:** a runner on builder3 (`tools/spotter/night.sh` + a systemd USER timer or cron, installed by
   a make target and removable by one) that, when no full check holds the lock and no judged series is running
   (`tools/builder_checks.sh`, `.full-check.lock`), runs batches niced (`nice -n 19`, `ionice -c3`), checkpoints after each batch, and
   STOPS the moment a check or series queues (it yields; it never holds the full-check lock). It pulls main's latest green commit
   (a named tree, never a dirty one), writes to `~/spotter-night/<date>/` with a one-page `SUMMARY.md`, and keeps disk under a cap
   (state it). Each night job is one of S1-S3 (fights + features + ranking + clips) and, once labels exist, S6 (training). Prove it
   on one evening's run before relying on it; say how to stop it.

1. **S1 the feature table:** from N fresh CPU-v-CPU fights (both sides, several maps, the shipped default game, 13121+), a per-crew-
   second table of what a player would see: speed, progress toward the goal, reversing, wall / friendly contact, heading v route,
   facing v incoming fire, enemy in own range and not firing, distance from squad, held by an order. Reuse the census code paths;
   where a feature has no source, ask the orchestrator.
2. **S2 the ranker, no training yet:** score each crew-second by how unusual it is (robust z-scores per unit class, an isolation forest
   or similar, CPU is fine), merge adjacent seconds into MOMENTS (a crew, a start, a length), and rank the top ~50 per batch. State
   what each top moment's strongest features were (readable reasons).
3. **S3 clips:** render each top moment as a short clip (3-6 s) from the game's own camera framing the crew, on builder3 (its Xorg :1
   is his logged-in desktop: windows there only in short bursts, R47.23; prefer an offscreen / virtual display if the GPU can drive it:
   find out and say). A clip must be reproducible from (seed, map, tick, crew).
4. **S4 the judging page (his gate):** a tap-to-judge Artifact with the `db` capability: each clip with its reasons and three taps,
   "looks dumb" / "fine" / "can't tell", plus a free note. Message the orchestrator the URL. Never stockpile; a batch of ~30 is enough.
5. **S5 read his labels:** precision of the ranker (how many of its top moments he called dumb), and a summary of the dumb ones by class
   for the other streams (the orchestrator relays them as findings, with the clip and its reproduction line).
6. **S6 a learned ranker (only after a few hundred labels):** a small classifier on builder3's GPU over the features (or clip frames),
   compared with S2 on held-out labels. Report whether it beats the hand ranker; it never ships in the game.
7. **Stretch (night shift):** an offline PARAMETER SEARCH on idle nights (the ruling allows frozen tables from offline search): a
   proposal only this round (which behaviour constants, which fights judge them, which owner's file it would touch), for next round's
   orchestrator. Then: the same ranking over his own recordings (first ~11 s exact, then staged), and a `make spotter` that runs S1-S3 overnight.

## How to verify

Each step's output is a file a human can read (tables, clip lists with reproduction lines). A clip that does not reproduce its moment
is a bug. Every number with its commit, machine, n. `make remote T=check` before naming a hash to merge (your files only: usually a
quick check is enough; name what you ran).

## Don't touch

Any game code (`game/**`, `native/**`, `arenas/**`), other streams' tests and make files, `tests/baselines/**`. No paid generation. Python
packages (scikit-learn, torch) in a venv OUTSIDE the repo on builder3 (`~/tools/spotter-venv`), pinned in `tools/spotter/requirements.txt`.

## Waiting on the lead

S4's labels.

## Status

_(updated 2026-10-31 ~03:10 PDT by the spotter worker; every number names its commit, machine, workload and n)_

### Report (top)
- **Merged to main** by the orchestrator: stream/spotter 213f5d070 (check GREEN at **9858da23f**: builder3, `make check exited 0`,
  3608 passed / 0 failed, 29 targets ALL JUDGED). Later commits on the branch are spotter paths only (Python, the probe, the pages,
  docs). The newest probe change (LOS + follow goal, tests/spotter/feature_probe.gd) has run in batch 2's 24 fights with no engine
  errors but no full check; the last full check on this branch is 9858da23f.
- **His gate S4: batch 1 judged, 30 of 30 "looks dumb"** (no notes; his words via the orchestrator: "all cases it exposed looked
  like dumb behavior"). Precision of the top 30 = 1.00 (n = 30, no negatives).
- **S5 done for batch 1:** `_agents/streams/references/round47/spotter/batch1-classes.md` (5 cause classes, every crew with
  seconds, peak tick, per-second context, clip, reproduction line). Routed by the orchestrator (R47.48): A RETREAT abandoning the
  squad and E outranged / no answer -> engage (E10); D -> orders; B give-way loops and C stuck on terrain / no_path -> round 48's
  manoeuvre. Class D's FOLLOW rows were a probe artifact (orders reproduced it; amended in the doc).
- **Batch 2 (in flight):** main **2fc962aa6**, builder3 (`night.sh batch-now`, nice 19), 24 fresh fights (6 maps x seeds
  13121-13124, 240 s), 113,636 crew-seconds, 4,002 moments; the page shows **ranks 31-100 + 10 hidden random controls** (ordinary
  windows the ranker did not flag), shuffled, reasons hidden until he taps: https://claude.ai/artifact/JWq9fmZ11eVbx68HoUofA9
  (clips uploading when rendered). It answers where precision drops and the base rate.
- **S6 waits for negatives:** 30 positives train nothing. Floor: ~100 "fine" and ~100 "dumb" for an 18-feature model's held-out
  AUC to mean anything; 300+ to trust it per class. `tools/spotter/learn.py` is ready (stdlib logistic regression, K-fold by seed,
  v the hand score); a GPU buys nothing at this size (frame models only if it plateaus).
- **S0 night shift:** installed on builder3, cron every 5 min, green ref pushed by the orchestrator after each green main (now
  2fc962aa6). It has NOT yet run a batch unattended: the box was never idle 10 min tonight (back-to-back checks). Its pieces are
  proven separately: the yield / lock / STOP frame (test_night.sh 15/0), the tree checkout of a named commit with the kit laid over
  it, batches, ranking, clips, SUMMARY.md (batch-now, the same code path minus the idle gate and the yield).

### Probe bugs found and fixed (each found by reading a judged batch)
1. `near_enemy` read `OrderController.visible_enemy_names`, filled only for halt_on_contact reflexes: -1 in every batch 1 row, so
   "enemy in sight and in range, not firing" never fired (engage's hold-fire class was invisible). Now the probe's own pure LOS ray
   (Perception.has_line_of_sight, sight radius). Batch 2: enemy in sight in 44,687 of 113,636 crew-seconds; hold-fire 9,403.
2. A follow's `brain.order.goal` is never updated (the drive follows the live station): "goal getting farther" was false for
   follows. Now the mover's live goal; older follow rows carry no goal (features.py).
3. Clip frame 0 showed the showmatch's own camera for one frame: 4 unsaved warm-up ticks.

### Done (the pieces)
- **S1** `tests/spotter/feature_probe.gd` (one row per crew-second, read-only) + `tools/spotter/features.py` (11 signals with words,
  run lengths, floors). **S2** `tools/spotter/rank.py` (per-class empirical tail, moments, caps, reasons, reproduction lines,
  `--controls N`). **S3** `tests/spotter/clip_probe.gd` + `tools/spotter/clips.py`: offscreen Xvfb extracted without root to
  builder3 `~/tools/xvfb` (his desktop :1 never used), Mesa llvmpipe = his gl_compatibility renderer, NVENC encode, near-top-down
  follow camera, marker + caption, **drift check** at the peak tick: batch 1 30/30 within 0.02-0.07 m; 10 s cap; `--ranks A-B`.
  **S4** pages `references/spotter/judge/index.html` (batch 1) and `judge2/` (batch 2), db `clips` (write admin; checked) +
  `labels`, videos as page assets; `tools/spotter/judge_docs.py` builds the clip docs. **S5** `tools/spotter/labels.py` + the
  classes doc. **S6** `tools/spotter/learn.py` (+ test). **S0** `tools/spotter/night.sh` + `mk/spotter.mk` targets.
- **Stretch:** `tools/spotter/recording.py` ranks HIS recordings from their own census (his Locks Hunters_4 detour came out #3 of
  his side unprompted); `references/spotter/param_search_proposal.md` (proposal only: constants, the knob-registry prerequisite,
  objective, guards; after labels).

### How to stop / remove the night shift
`make spotter-night-stop` / `-start` / `-status` / `-uninstall` (data stays in builder3 `~/spotter-night`; cap 20 GB).

### Questions for the lead
- None blocking. Batch 2's page is his next gate (no hurry).

### Requests / merge notes
- `mk/spotter.mk` is new (globbed). Makefile: one additive line `LIGHT_GOALS += spotter-night-% spotter-test spotter-rank` (R47.46).
- Not mine, left untracked: `tests/test_authority_press_on.gd.uid`, `tests/test_gunnery_pot_shot.gd.uid`.

### Next steps
1. Upload batch 2's clips + docs (judge_docs --shuffle), message the URL. 2. When he judges: labels.py (precision by rank band,
control base rate), classes for any new causes. 3. Once ~100 fine + 100 dumb exist: learn.py v hand. 4. Watch for the night
shift's first unattended run (SUMMARY.md in builder3 `~/spotter-night/<date>/`).
