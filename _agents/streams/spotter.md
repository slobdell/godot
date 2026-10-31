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

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
