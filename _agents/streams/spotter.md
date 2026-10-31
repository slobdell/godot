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

_(updated 2026-10-31 ~00:10 PDT by the spotter worker; every number names its commit, machine, workload and n)_

### Plan (smallest foundation first)
S1 probe (it is what S0 runs) -> S2 ranker -> S0 the night shift -> S3 clips -> S4 judging page (his gate) -> S5 label reader ->
S6 (after a few hundred labels) -> stretch. S1 came before S0 because the night shift's frame needs a real batch to prove itself on.

### Done so far
- **S1 the feature table** (1f3d4b517): `tests/spotter/feature_probe.gd` listens to a showmatch fight (`--skirmish --demo-match`,
  native, the shipped default) and writes one row per live crew per second: position, heading, speed, hp, order / move / weapon
  order, phase, blocked_by, wall contact (cause, collider), route metres to its goal (NoProgressCensus's navigation query) and
  its gain over 2 / 5 s, nose v route, visible enemies and the nearest one's distance, shots, ticks since fire, lane blocker,
  squad centroid distance, incoming damage and how far off the nose / how far away it came from. Read-only. `tools/spotter/
  features.py` derives eleven signals with words and run lengths (no progress, wall, friend-blocked, reversing, wrong way,
  holding fire in range, rear fire, outranged, still under fire, far from squad, spinning) and a floor under which each reads 0.
  Trial: 1209a934f+, builder3 light lane, terminus + crossing seed 13121, 90 s: 6511 crew-seconds, no engine errors; the hull
  forward (-Z) agrees with the displacement on 98.9 % of 1225 moving samples.
- **S2 the ranker** (`tools/spotter/rank.py`): per unit class, an empirical tail (-log10 of the share at or above the value: a
  non-parametric robust z), a crew-second scores its two largest, hot seconds merge into moments, top N with 8 a fight / 1 a
  crew, each with readable reasons + a reproduction line -> moments.json / moments.md. Trial (same 2 fights): 231 moments; the top
  ones were crews boxed by squadmates and reversing (terminus Rust_Hunters_1 55-63 s; crossing Rust_Burners2_4 41-47 s).
- **S0 the night shift** (046082c52 + fixes): `tools/spotter/night.sh` on builder3, cron every 5 min (`crontab -l` there, marked
  `# spotter-night`). Runs only after the box has been idle 10 min: nobody holds `~/tank_squad/.full-check.lock` and no process of
  anyone else runs in a `~/tank_squad/<folder>` (checks, queued checks, quick-remotes, series, light runs, renders all do).
  Batches run `nice -n 19 ionice -c3` in their own process group, never take a slot (TANK_SQUAD_SLOT=night past the Makefile
  gate) or the lock; a watcher re-asks every 10 s and kills the group the moment the box is busy (yield <= ~15 s). Each finished
  fight is a checkpoint (killed fights leave .part and re-run). Game = a NAMED commit: `refs/heads/green` in
  builder3's bare `~/spotter-night/repo.git` (cloned from GitHub once; `make spotter-night-push SHA=` sends only that commit's
  missing objects), checked out clean in `~/tank_squad/spotter-night` with the spotter kit laid over it (dev tooling only).
  Output `~/spotter-night/<date>/<commit>/` + one-page `SUMMARY.md`; disk cap 20 GB (oldest days first; builder3 had 152 GB free).
  `tests/spotter/test_night.sh` 15/0 (idle runs, yield in 6 s at a 1 s poll and the batch's whole group killed, busy never
  starts, idle wait, lock = busy, STOP). Installed 2026-10-30 23:50; green = **09780edb9** (main, builder3 3569/0). At 00:02 it
  was correctly waiting (manoeuvre's full check held the lock). **Proof run: pending the first idle window tonight.**
- **S3 clips** (0641c90a9): `tests/spotter/clip_probe.gd` + `tools/spotter/clips.py`. **The display question, answered:** builder3
  has no Xvfb and no root, so the distro's xvfb package was fetched with `apt download` and extracted to `~/tools/xvfb` (no root,
  no missing libs). Godot on it draws with Mesa llvmpipe (NVIDIA's GL needs its own X server): the same gl_compatibility renderer
  his game uses, rasterized on the CPU; the GPU encodes (h264_nvenc). His desktop :1 is never touched. The fight replays from its
  seed with rendering off, then every tick is rendered from a near-top-down camera following the crew (a 50-degree view let a
  building hide the crew), a yellow marker over it, a caption with its reasons. **Each clip checks the crew's position at the
  moment's peak tick against the table:** 3/3 reproduced, drift 0.02-0.05 m (1209a934f+, builder3 light lane, ~41-98 s a clip).
- **S4 page** drafted (`references/spotter/judge/index.html`): clips from the page's db, three taps + a note per clip, labels in db.
- **S5** `tools/spotter/labels.py` (precision overall / top 10-30, signals dumb v fine, the dumb ones as findings with repro lines).

- **S4 the judging page is UP (his gate): https://claude.ai/artifact/DXKpD67u2r49HQrk93ozJD** (URL sent to the orchestrator
  00:45). Batch 1: stream/spotter tree (1209a934f + spotter), builder3 light lane, 12 fights (6 maps x seeds 13215-13216, 240 s),
  52,487 crew-seconds, 1,557 moments, top 30 as clips: **30/30 reproduced their moment** (crew 0.02-0.07 m from the table at the
  peak tick). db: `clips/<arena-seed-crew-from-to>` (write admin; checked: a Contributor's write is refused, a Viewer reads) and
  `labels/<same id>` {verdict dumb|fine|unsure, note, by, at} written by his taps. Videos are the page's assets. Local copy of
  the batch: `~/spotter-work/batch1/` (laptop). What the 30 are, by brain choice: RETREAT 5, MOVE 12, HOLD 6, FOLLOW 3, ENGAGE 2,
  SPOT 2. A RETREAT driving away from its route is by design; his taps will say whether it LOOKS dumb (S5 then down-weights).
- **Stretch: his recordings** (`tools/spotter/recording.py`, 5020d4dd8): the census rows of a recording ARE his match, so ranking
  them needs no replay. Over his four round-46 playtests, his side (team 0), 9,879 crew-seconds: #1 Sumps Green_Alpha_5 101-113 s
  (blocked by a friendly 13 s, no progress 9 s), #2 Sumps Green_Charlie_5 33-57 s (no progress 25 s), **#3 Locks Green_Hunters_4
  33-56 s (far from its squad 42.5 m, no progress 24 s) = his own Locks complaint (the IFV that drove away from his attack target
  on the ~230 m detour), found with no hint.** Straight-line goal distance only (the census has no route), no shooter on hits.
- **Stretch: the parameter search, a proposal** (`references/spotter/param_search_proposal.md`): which constants (Movement STUCK /
  UNSTICK / REPATH / FOLLOW / WAIT, TankBrain LANE_SEARCH, FOLLOW_DISTANCE), the prerequisite (a behaviour-knob registry on the
  existing `--tune=` path: owners' edits), objective (dumb-signal seconds paired by seed v the default arm), guards, output (a
  frozen table as a proposal to the owner). After S5's labels, not before.
- **Night shift green = 8d37b9796** (pushed 00:20 at the orchestrator's word; the orchestrator pushes each green main from now on).

### In flight
- Full check of **5020d4dd8** on builder3 (queued on the full-check lock since 00:04; several checks ahead of it).
- The night shift's first idle window (the box has been busy with checks all evening; it starts 10 min after they stop).

### How to stop / remove the night shift
`make spotter-night-stop` (or on builder3 `~/spotter-night/bin/night.sh stop`), `make spotter-night-start` to resume,
`make spotter-night-uninstall` removes the cron line (data stays in `~/spotter-night`; `rm -rf` it to free the disk).
`make spotter-night-status` says what it is doing and what holds the box.

### Requests / merge notes
- `mk/spotter.mk` is new; `include mk/*.mk` picks it up. **Makefile: ONE additive line** above `_SLOT_GOALS` (granted R47.46):
  `LIGHT_GOALS += spotter-night-% spotter-test spotter-rank`.
- The orchestrator runs `make spotter-night-push SHA=<green>` after each green main check (agreed 00:20).
- Not mine, left untracked: `tests/test_authority_press_on.gd.uid`, `tests/test_gunnery_pot_shot.gd.uid` (main's tests' .uid).

### Questions for the lead
- (none yet; S4's taps are his gate)
