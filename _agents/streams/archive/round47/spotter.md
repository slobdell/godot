> **ARCHIVED (round 47 closed 2026-10-31).** Final state of this brief; results in `workstreams.md` *Round 47* (R47.1-R47.52, Bars).

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

## FINAL REPORT (2026-10-31 ~04:50 PDT, the spotter worker; session ending, the night shift keeps running)

**Merged:** main has stream/spotter 93477ba80 (= **a414cdba1 GREEN**: builder3, `make check exited 0`, 3608 passed / 0 failed, 29 targets
ALL JUDGED; earlier 9858da23f GREEN, same numbers). Spotter paths only + one Makefile line (`LIGHT_GOALS += spotter-night-% spotter-test
spotter-rank`, R47.46).

### What exists (all dev tooling; nothing ships in the game)
| Piece | Where | What it does |
|---|---|---|
| S1 feature probe | `tests/spotter/feature_probe.gd`, `tools/spotter/features.py` | one row per live crew per second of a CPU-v-CPU showmatch fight (read-only); 11 signals in words with run lengths and floors |
| S2 ranker | `tools/spotter/rank.py` | per-unit-class empirical tail (non-parametric robust z), moments, 8 a fight / 1 a crew, readable reasons, reproduction lines, `--controls N` |
| S3 clips | `tests/spotter/clip_probe.gd`, `tools/spotter/clips.py` | offscreen on builder3 (Xvfb extracted without root to `~/tools/xvfb`; Mesa llvmpipe = his gl_compatibility renderer; never his desktop :1), NVENC encode, follow camera + marker, **drift check at the peak tick** (a clip that does not reproduce is marked, never shown), `--ranks`, `--blind`, `--one` |
| S4 pages | `references/spotter/judge/` (batch 1), `judge2/` (batch 2); `tools/spotter/judge_docs.py` | tap-to-judge (looks dumb / fine / can't tell + note); db `clips` (write admin) + `labels` (his taps); videos as page assets |
| S5 | `tools/spotter/labels.py`, `_agents/streams/references/round47/spotter/batch1-classes.md` | precision, signals dumb v fine, findings with repro lines; the classes write-up |
| S6 | `tools/spotter/learn.py` (+ test) | stdlib logistic regression v the hand score, K-fold by seed (AUC, precision at 10 / 30 %); waits for labels |
| S0 night shift | `tools/spotter/night.sh` on builder3 + `mk/spotter.mk` | below |
| Stretch | `tools/spotter/recording.py`; `references/spotter/param_search_proposal.md` | ranks HIS recordings from their own census (his Locks Hunters_4 detour came out #3 of his side unprompted); the offline parameter-search proposal |
Make targets: `spotter-fights`, `spotter-rank`, `spotter-batch`, `spotter-clips`, `spotter-clip`, `spotter-test` (Python + test_night.sh), `spotter-night-*`.

### The night shift (S0): how to check it, stop it, where the morning page lands
- **Runs by itself:** builder3 cron every 5 min (`crontab -l`, line marked `# spotter-night`). It starts only after the box has been idle
  10 min (nobody holds `~/tank_squad/.full-check.lock`, no process of anyone else's in a `~/tank_squad/<folder>`), runs nice 19 / ionice
  idle, never takes a slot or the lock, and **yields within ~15 s** when anything else starts (kills its own process group; a finished
  fight is a checkpoint). Each batch: 6 maps x 2 seeds of 13121-13216 (240 s fights), rank, top 30 clips. Game = the green ref the
  orchestrator pushes after each green main (`make spotter-night-push SHA=`; now 2adbd3ac8), checked out clean with the kit laid over it.
- **Check:** `make spotter-night-status` (what it's doing, what holds the box, last log lines, disk).
  **Stop:** `make spotter-night-stop` (`-start` resumes); **remove:** `make spotter-night-uninstall` (data stays; cap 20 GB, oldest days go
  first; builder3 had 149 GB free).
- **Morning page:** builder3 `~/spotter-night/<date>/SUMMARY.md` (top 20 moments, clips count, yields, the night's log); details in
  `~/spotter-night/<date>/<commit>/fights/` (moments.md, clips/). `make spotter-night-pull` copies SUMMARY + moments to the laptop
  (`~/spotter-work/night/<date>/`).
- **Verified:** test_night.sh 15/0 on the laptop AND on builder3 (idle runs, yield in 6 s at a 1 s poll with the batch group killed, busy
  never starts, idle wait, lock = busy, STOP); cron's bare environment has every tool; cron has ticked since 23:55 with an empty error
  log, recording each busy reason. The batch body itself (tree checkout of a named commit + kit, fights, rank, clips, SUMMARY) ran twice
  through `night.sh batch-now` (same code minus the idle gate). **Not yet seen: an unattended batch** — the box was never idle 10 min
  tonight (checks back to back). First thing to look at next session: `make spotter-night-status` / its night.log `batch:` lines.

### Results
- **Batch 1** (1209a934f + spotter, builder3, 12 fights = 6 maps x 13215-13216, 52,487 crew-seconds, 1,557 moments): top 30 as clips,
  30/30 reproduced (0.02-0.07 m). **His verdict: 30 of 30 "looks dumb"** (no notes; "all cases it exposed looked like dumb behavior").
  **Five cause classes** (`batch1-classes.md`; routed R47.48): A hurt crews RETREAT by abandoning the squad, often reversing 8-19 s (4,
  engage); B squadmates jam each other in give-way loops, HOLD crews leave posts to give way (9, manoeuvre r48); C stuck on terrain /
  no_path and never giving up, one sat a whole match (5, manoeuvre + route r48); D drives away from its goal (7, orders; the FOLLOW
  rows were a probe artifact, amended: the real fault is the follower reversing / spinning when its leader pivots); E shot from beyond
  its range with no answer (5, engage E10).
- **Batch 2** (main 2fc962aa6, builder3, 24 fights = 6 maps x 13121-13124, 113,636 crew-seconds, 4,002 moments): **ranks 31-100 + 10
  hidden random controls**, shuffled, reasons hidden until he taps, captions blacked out; 80/80 reproduced (<= 0.07 m).
  Page: https://claude.ai/artifact/JWq9fmZ11eVbx68HoUofA9 (batch 1: https://claude.ai/artifact/DXKpD67u2r49HQrk93ozJD).
- **From batch 2's taps, compute** (export the page's `clips` + `labels` with ArtifactData, then `tools/spotter/labels.py`):
  precision by rank band (31-50, 51-75, 76-100: where it drops), the controls' "dumb" rate (the base rate: if ordinary seconds also
  look dumb, the ranker is not what finds them), precision per signal (drop or down-weight signals he calls fine), and classes for any
  new cause (same format as batch1-classes.md).
- **Probe bugs found by reading judged batches, fixed:** enemy-in-sight was always -1 (read a reflex-only list; now its own LOS ray:
  batch 2 sees an enemy in 39 % of crew-seconds, hold-fire 9,403 crew-seconds); a follow's goal was frozen (now the mover's live goal);
  clip frame 0 showed the showmatch camera.

### S6: the label floor
30 positives and no negatives train nothing. **~100 "fine" and ~100 "dumb"** is the floor for the 18-feature model's held-out AUC to mean
anything; 300+ to trust it per class. Getting "fine" labels needs lower ranks and controls (batch 2 is the first). A GPU buys nothing
at this size; a frame model only if the feature model plateaus.

### Round 48 (for the next orchestrator)
1. Read batch 2's taps (above); keep the ranker's floor where precision stays high; file new classes.
2. Next judging batches: blind (`SPOT_BLIND=1`), with controls, from the night shift's folders (its clips are top-30 per day; use
   `night.sh batch-now` + `SPOT_RANKS` for deeper bands); upload with judge_docs.py.
3. Once ~100/100 labels: `learn.py` v the hand ranker; ship the better one as the night's ranker if it wins on held-out seeds.
4. Re-run a batch AFTER engage / manoeuvre / orders ship fixes for classes A-E: the same seeds, the class's signal rate before v after
   (the spotter as a regression check).
5. The parameter search (`param_search_proposal.md`) after labels, and only with the owners' behaviour-knob registry.
6. Probe gaps worth adding: the shooter on hits in HIS recordings (a census request to the orchestrator), turret v target bearing.

### Questions for the lead
- None blocking. Batch 2's page is his next gate (no hurry).

### Merge notes / leftovers
- `mk/spotter.mk` new (globbed); one Makefile line (above). Not mine, left untracked: `tests/test_authority_press_on.gd.uid`,
  `tests/test_gunnery_pot_shot.gd.uid`.
- Laptop copies: `~/spotter-work/batch1/`, `~/spotter-work/batch2/` (fights, moments, clips). Upload staging `.spotter-upload*/` in
  this worktree is git-excluded and can be deleted.
- remote_builds trip-up (filed by the orchestrator): a TERM to a queued `remote.sh` wrapper left the remote lock waiter alive; stopped
  by a cwd-verified pgid kill.
