# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-20 07:00. **Round 9's overnight run: twelve branches merged and verified; CP2 and CP3 pending. Read the morning summary first.**_

## ☀ THE MORNING AFTER ROUND 9's NIGHT — read this first (2026-09-20, written 07:00, updated at each tick)

**You went to bed at ~00:45 with eight streams briefed. By 07:00 twelve branches were merged to `main`, every merge at
a hash whose own builder0 check went green, the sim baseline was recorded as it moved, and `main` was verified green
after each wave. Nothing is pushed to `origin` — you push.** The night's rules were yours: any decision over no
decision, and finished, validated work. Every decision below is reversible in one place, and each says how.

### What is on `main` (in merge order; builder0 verdicts read from the wrapper's own line)

| stream | merged at | what | verdict |
|---|---|---|---|
| control | `e27f0681` (CP2c) | **desktop right-drag orders the heading to arrive on** (press = destination, drag past 18 px = facing): the arc that could never fire on your controls now can | 1269/0 |
| nav | `5c8f08b3` | **A7 priority projection, A11 dynamic-window arcs, A1 event-triggered replanning, A4 clothoids: all built, measured, and OPT-IN**; the arrival gate counts offered = aimed + refused | 1290/0, baseline unmoved |
| feel | `7a706911` | **the War Rig is a tractor and a trailer hinged at the fifth wheel** (S2: the collider is still one 14 m box, so a shell can pass through a fold; the accepted cost this round) | 1273/0, baseline unmoved |
| metrics | `ae9c65e1` (CP1) | **A12 trajectory metrics** (reproduced round 8's oscillation numbers to 0.05 pt), **the lint that actually checks** (the remote gate had parse-checked ZERO files all round: lesson 157), the sharded parallel check (a full gate now takes 13–18 min instead of 45) | 1310/0 |
| nav | `3b01f5b7`, `c6222a5c`, `d6a1f454` | the `wedged` regime detector, the gains override, **the A4 A/B (fails its bars; default stays off on measurement)**, the legibility key and corridor tangent, A6's two clauses (opt-in, honestly inert until the corridor arrives) | 1295/0, 1316/0, 1381/0 |
| control | `ffd09b0e`, `3683e0ca` | **the camera stays outside the Terminus blocks** (lift 21° → 32° over a roof; 703 of 4328 poses inside a building → 0) **and the block in the way is cut** (alley walled 518 → 0); the corridor readout | 16/16 targets, 1372/0 |
| squad | `02762b8d`, `1a797642` | **slot pitch and leash from the members' hulls**, facings on element orders, **A8 measured and switched off**, **A9 co-arrival + explicit bounding overwatch**, per-faction PID gains measured; A10 stood down; A1's brain-side tube measured and OFF | 1297/0 + five targets; 1364/0; **baseline moved → `d4c049819a5833d3`** (recorded twice) |
| feel | `5ae7e531` | **the Syndicate airship** (primitives, no Meshy), the differential smokes proved, the pipeline roster fix | 1316/0, baseline unmoved |
| combat | `55b0de58` | **the dwell timer retired on measurement** (inert for two rounds), **A2 opt-in** (weaker than the flat bonus on churn, costs nothing where 1.35 did), the CLEAR_LANE catch | 1393/0; **baseline moved → `32831dc99cdaf5ca`** (recorded twice at 07:10, agreeing) |
| show | `e1823e68` | **the arena as a light show**: fixtures, channels, patches, cues; Terminus and yard patched; ~1.5% of frame time, zero added lights | 1420/0, baseline unmoved |

**NOT merged at 07:00: CP2, scale's resized roster.** Built and verified to 1392 passed / 3 failed on `e7ebb372`; two of
the three since fixed, the third (a contact-pip test in control's file) fixed by control at 07:00 (`e36d61c7`: the test now picks a
spot it can see instead of a fixed 30 m offset that the bigger hulls put behind a prop) and committed by scale at
`7542df28`; scale's full check on it at 07:01 came back **1395 passed, 0 failed across both shards and still exit 2**, because T1's shard count is a recursively expanded make variable that re-derived itself from free memory between launch (2 shards) and verification (3): lesson 176, the fix is routed to metrics. **Re-running with the count pinned (`TEST_SHARDS=3`), wrapper line ~08:05**; inconclusive, not green, until then. The swap-bases fairness control is owed. **If it did not land by the time you read this, it is the first merge of
your morning, and control's item 4 and feel's X4 (the post-resize camera and art sweeps) follow it.** **CP3 (metrics' three-slot series and the `REMOTE_SLOTS=3` default):** the check is 63–66% faster than serial (2820 s → ~930 s) with bit-identical hashes, **but its own three-run flake criterion caught a latent race** (the exclusion groups that keep two smokes off one port were inert: lesson 175); fixed at `fe7599f5`, the three runs restarted at 07:10 and land ~08:00. Not merged until they do.

### What you should look at (all sent to you overnight; paths on this laptop)

1. **The roster at real relative scale**: `~/projects/godot-scale/build/roster-lineup/lineup_pose.png` (your pose) and
   `lineup_factions.png`. K = 0.707, rig-anchored. **Overrule:** `Units.RIG_LENGTH_M` → 19.8 for real metres.
2. **The War Rig bending**: `~/projects/godot-feel/build/rig-hinge/strip_45.png`, `strip_21.png` (your pose),
   `strip_reverse_60.png` (the jackknife). Hear it from us: the collider is still one box.
3. **The camera in the Terminus alleys**: `~/projects/godot-control/build/terminus-alleys/index.html`; `alley4_asked`
   vs `alley4_clear` is the pair. **Overrule:** the lift resolver is one function; a push-in variant is the same test.
4. **The light show**: `~/projects/godot-show/build/show/` (frames, three arms: default, `before/`, `outline/`) and
   **`build/show/clips/*.mp4`; watch the clips before the stills**: after feel's art review the default is quiet in a
   still and lives in motion. The coloured horizontal bands in every frame are feel's round-7 shopfront neon, not the
   show. **Three dials, all data:** `show.channels.windows.ceiling` (1.10; the gate says what raising it costs the
   fight), `show_edge_energy` (0.8, parapet only), `"style": "outline"` (the full-silhouette look feel argues against).
5. **The airship**: `~/projects/godot-feel/build/airship-look/airship_widest.png`. **You will not see it at your
   default pose**: the sky is below the top of the frame at 21°. It lives over the city at 560 m and shows at 8–12° tilt.
   **Your call:** leave it, or make it a title/results element. One constant either way.

### Decisions made on your behalf (each reversible in one place)

- **Sizing is rig-relative** (K = 14.0 / 19.8 = 0.707); Syndicate platforms referenced by role; `law_tank` is a
  Centauro 8×8. **Balance was not a constraint**, per your round-8 ruling.
- **Articulation is visual** this round; the sim keeps one body and one box (S2).
- **The light show's default is light inside things** (windows, shopfronts) plus one roofline per block, venue palette,
  never red or cool white; the outline look is a named variant. The fight must stay the brightest read: a gate measures
  it against its own null. (feel's art ruling, adopted.)
- **The camera lifts over a roof rather than pushing in**, and cuts the block in the way.
- **A2 ships opt-in; the dwell timer is retired** (measured inert). **A4's default stays off** (it fails its bars and the
  curved entry does not arrive). **A8 is off** (it made a wedge fail a defile it passes without it). **A10 is stood down**
  (heavies-in-front was never a cost, only the old matcher's tie order: lesson 50's shape). **A1's brain-side tube is
  off** behind a five-seed gate (−62% re-decides with latency intact, but four more GREEN dead on one seed).
- **The gap-widening ruling was made and WITHDRAWN** within twenty minutes: the measure behind it was wrong (lesson 162).
  The maps are fine; no map changed.
- **The airship moved over the city** because geometry made it invisible over the arena at your pose.
- **builder0 slots 3 → 6** (the queue, not the machine, was the bottleneck: lesson 161); CP3 sets 3 once a slot holds a
  sharded check.

### What is unverified, stated plainly

- Whatever merged after the last green `main` check at the time you read this (see *Live checkpoints* below for the
  latest verdict line). Every branch was green on its own check before merging; the combination is what each `main`
  check proves.
- CP2 (scale) and CP3 (metrics) as above.
- Nothing is pushed to `origin`.

### What each stream owes (each is at the head of its brief's Status, in your terms)

- **scale:** a green check and the swap-bases fairness control for CP2; the factions re-render; feel's two Terminus
  floodlights (half the lamps of pit, eight lit towers inside the fight); the stretch 9/20 → 0/20 re-measure.
- **combat:** **the hull-rotation plant defect**: a hull's position is collision-resolved and its rotation is not, so
  hulls rotate through scenery; this is your round-8 "semi yawing in place", and CP2 makes it worse. Spec agreed with
  nav; not started so that tonight's baseline move has one named cause.
- **nav:** P7's A12 baseline (exact invocation written); per-hull-class agent radius after CP2.
- **squad:** A10 resumes at `c0f22597` once the deleted `fixed` flag's guarantee is preserved; the tube's five-seed gate.
- **control:** item 4 (the post-CP2 camera sweep) the moment CP2 is on `main`; the contact-pip fix for scale.
- **feel:** X4 after CP2; the hinge's frame cost when the box is quiet; the Terminus brightness (diagnosed, scale's fix).
- **metrics:** CP3's table; `ai-scenarios` into `check` behind its count baseline; the corridor columns' consumer.
- **show:** item 7 (stretch) not started.

### The round's structural finding, and what round 10 should spend itself on

**Intent does not reach the layer that moves the hull.** nav measured `CombatMotion` deciding under a tenth of a hull's
ticks with `Movement` driving the rest and knowing no leash; squad found A8's deformation fails a defile because a slot
layout is the wrong place for intent the mover cannot see; the maze defile failure survived three pre-registered
hypotheses and is now a named regime (`wedged`) rather than a story. Every one of nav's five rows trips on the same
seam. That is round 10's first candidate, ahead of retrying any row.

**Lessons 152–174 were written tonight** (`_agents/orchestration.md`): the night's recurring shape is *the absence of
work reading as the success of work*: a lint that checked zero files, a scenario suite outside the gate, a flag that
silenced its own tests, a perturbation that could not perturb, a control arm where the mechanism could not act, a
measure that flagged everything. Each is now a guard.

---

## Round 9 is LAUNCHED (2026-09-19 evening). Start here.

**Eight streams — metrics, scale, nav, combat, squad, feel, control, and (added 2026-09-20) show** — each with a brief in `_agents/streams/<stream>.md`
and a worktree at `~/projects/godot-<stream>`. The split, checkpoints (CP1 A12 metrics, CP2 the resized roster, CP3
parallel `check`), ownership carve-outs and the four new contracts S1–S4 are in
[`_agents/workstreams.md`](_agents/workstreams.md) *Round 9: the seven streams*. The lead's two feedback items and the
sizing rule are in [`_agents/game_design.md`](_agents/game_design.md) *Round 9 direction*.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all eight (show at `~/projects/godot-show`, OFFSET 8; it runs every Godot process on builder0 because the laptop had ~2.2 GB free with seven live):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**`main` IS GREEN at `f49aa08a`** (builder0, 2026-09-20 00:27: `>> remote: make check exited 0`, `1261 passed, 0 failed`,
`sim-baseline passed: 04414f5d6a6dfa7c (glibc-2.43)`). Round 8's unverified merge is now verified; every commit since is
docs only. **Orchestrator duties this round:** merge CP1
(metrics' A12) and CP2 (scale's roster) the day they are announced and tell every stream to `git merge main`; record
the sim baseline in the same session as CP2 (it moves); put scale's side-by-side roster frame and feel's rig-hinge frames
in front of the lead the day they exist; get feel's `_agents/legibility.md` signed by control and nav before anyone
writes A6 motion code; review nav's A7 priority table against combat's and feel's contracts before nav codes it; relay
negative results between streams. Final integration order: metrics → scale → nav → combat → squad → control → feel → show. **Overnight 01:45:** all eight agents busy; nothing merged yet. **CP2b (squad `6e0c9968`) is HELD** — its drift scenario errors on a stub without `pitch`, invisible to `check` because `ai-scenarios` is not in it (lesson 159; metrics adds it behind a count baseline for CP3). nav: A4's positive control 403/403; A1 is a negative result, the real driver was re-planning against a sliding station (47% of re-plans), fixed. scale has A3 built (`3dcab48b`). feel has the airship built (`567a8007`). control's facing drag and camera lift built. **Round-wide trap found 02:00 (show, verified in `tools/make_arenas.py`): `arenas/*.json` are GENERATED and the generator drops any key it does not know — a hand-edited layout loses the edit on the next `make arenas`, silently. Ruled: the generator preserves an allowlist of hand-authored keys (`show`) and `Arena.validate()` rejects unknown top-level keys; scale owns both.** **MERGED 03:05: CP2c, control's right-drag facing at `e27f0681` (builder0 1269/0, exited 0) → `main` `260dddc7`; check on main running.** **MERGED 03:10: stream/nav at `5c8f08b3`** (builder0 1290/0, exited 0, sim-baseline UNCHANGED at `04414f5d6a6dfa7c`: A7/A11/A1/A4 all opt-in, 29 new tests) → `main` `08a8c378`; **NOT covered by the check running behind CP2c** (asked builder0: its tree has no `clothoid.gd`), so a second check on main is chained to start when that one's wrapper line lands. **MERGED 03:30: stream/feel at `7a706911`** (the articulated War Rig, S2; builder0 1273/0, exited 0, baseline UNCHANGED, read from streamed stdout) → `main` `8147bddc`. **builder0 came back at 03:25 (ZeroTier link; ~35 min outage; no remote jobs survived the drop; the check on main restarted at 03:25).** ~~⚠ builder0 went OFF THE NETWORK at ~03:15~~ (it went off at ~02:50 (ZeroTier link; the laptop's internet is fine): the check on main behind CP2c died with ssh 255 mid-run, so **`main` at `8147bddc` (CP2c + nav + feel) is NOT yet covered by a check** — it runs the moment the box returns (polled every 5 min). Every stream is holding remote runs and working locally. **CP2's blocker is diagnosed and fixed (scale `e5d71ba2`, 03:50):** the 104.9 m unit was a *respawned* enemy-killed unit sitting on its own new spawn slot with no order; the old grid passed by geometric luck. The test now excludes destroyed units, as its sibling already did. CP2 waits only on scale's remote check and hash. **`main` VERIFIED GREEN at `ba1c22c8` (CP2c + nav + feel; builder0 04:12: exited 0, 1310 passed, 0 failed, sim-baseline 04414f5d6a6dfa7c unchanged; note that run's lint was still the vacuous one — CP1's own check at `ae9c65e1` covered the same code with the working lint).** **MERGED 04:00: CP1, metrics at `ae9c65e1`** (builder0 1310/0, exited 0, 16 targets, baseline UNCHANGED across CP2c + nav + feel) → `main`. Since ae9c65e1 already contained the three earlier merges, main's code is exactly the tree that passed. **Every stream merges main now.** The working lint is live (an empty file list fails; `tests/baselines/lint_expected.txt` carries the 8 known artefacts). T1 measured at 6 slots: 1776 s vs 2693 s serial = 34%, **missing the 50% bar because six slots starve the inner fan-out (CHECK_JOBS=1, 2 shards)**; the shipped configuration is 3 slots (CHECK_JOBS=3, 6 shards), series running. **MERGED 04:20: stream/nav at `3b01f5b7`** (wedged detector, forced gains, A1 monotonicity guard, face recovery; builder0 1295/0, exited 0, baseline unchanged) → `main` `e1a9895c`, **VERIFIED GREEN** (builder0 04:35: exited 0, 1315 passed, 0 failed, 16 targets, sim-baseline 04414f5d6a6dfa7c unchanged; the sharded check took **990 s** against the 2693 s serial baseline on a box running six other jobs). **MERGED 05:05: stream/control at `6813908d`** (checked at `ffd09b0e`: the camera lift + occlusion cutaway on the Terminus, the corridor readout, the console gate; 16/16 targets, verdict read from the box's markers after metrics' kill took the wrapper) → `main` `f005dd37`, **VERIFIED GREEN** (builder0 05:14: exited 0, 1327 passed, 0 failed, 16 targets, 791 s sharded). **MERGED 05:15: stream/nav at `c6222a5c`** (A4's A/B: default stays off on measurement; the rotation-read map set; A11 cannot act without A7, arm guard; builder0 1316/0, exited 0, baseline unchanged) → `main` `36aa295d`, **VERIFIED GREEN** (builder0 05:50: exited 0, 1328 passed, 0 failed, 16 targets). **MERGED 05:40: CP2b, stream/squad at `974f194a`** (checked at `02762b8d`: hull-derived slot pitch + leash, facings on element orders, A8 off, A9, per-faction gains measured; A10 stood down; builder0 1297/0 with the pre-registered baseline move as the only red, five post-baseline targets exited 0) → `main`. **SIM BASELINE RECORDED: `glibc-2.43 d4c049819a5833d3`** (builder0 06:00, read twice, agreeing, on the merged tree with squad and feel in; matches squad's pre-registered value). **`main` VERIFIED GREEN at `82604493`** (the full tip with squad, feel and the new baseline: builder0 06:00, exited 0, 1370 passed, 0 failed). **MERGED 05:45: stream/feel at `37d6f838`** (checked at `5ae7e531`: the airship, the differential smokes proved, the pipeline roster fix, the Terminus luminance diagnosis; builder0 1316/0, 16 targets, baseline UNCHANGED, real lint 543 files clean) → `main`. **`main` VERIFIED GREEN at `1f6e54b7`** (with squad's follow-up: builder0 06:35, exited 0, 1370 passed, 0 failed, 16 targets, 1035 s). **MERGED 06:10: stream/squad at `c2d7c28f`** (checked at `1a797642`: A1's brain-side tube measured, −62% re-decides with latency intact, ships OFF behind a five-seed gate because 4 more GREEN died on one seed; nav's corridor field; builder0 1364/0). squad is DONE and stopped; its report is at the head of its Status. **MERGED 06:15: stream/control at `d5e37692`** (checked at `3683e0ca`: the legibility readout on nav's key and corridor; builder0 1372/0, 16 targets, baseline unmoved). control's backlog is complete except item 4 (the post-CP2 camera sweep), standing by. **`main` VERIFIED GREEN at `888d0f8d`** (control's and nav's tips in: builder0 07:00, exited 0, 1383 passed, 0 failed, 16 targets). **MERGED 06:40: stream/nav tip** (checked at `d6a1f454`: the legibility key, corridor tangent, A6 opt-in and honestly inert, the arrival-heading test; builder0 1381/0, baseline d4c049819a5833d3 unchanged against main's current value). nav is DONE and stopped; five rows built, none on by default, four negative with pre-registered falsifiers. **MERGED 07:00: stream/combat at `55b0de58`** (the dwell timer retired on measurement, A2 opt-in, the CLEAR_LANE catch; builder0 1393/0, exit 2 = sim-baseline only). **SIM BASELINE RECORDED: `glibc-2.43 32831dc99cdaf5ca`** (builder0 07:10, read twice, agreeing; one named cause: the retired timer). **MERGED 07:10: stream/show at `77b209c0`** (checked at `e1823e68`: the arena light show; builder0 1420/0, lint 560 clean, baseline UNMOVED — S6's pre-registered claim held; show's shader edits under feel's `game/theme/fx/shaders/` and `export_presets.cfg` are the granted emission hooks, feel reviews). show is DONE and stopped; items 1–6 complete, 7 (stretch) not started. **MERGED 07:12: combat's report commit `0709b073`** (docs only). combat is DONE and stopped. **Live checkpoints as of 2026-09-20:** CP1 (A12 format stable, positive control passed, merge hash pending), CP2 (roster resized on `stream/scale`, line-up frame for the lead pending), CP2b (squad's attacking-element leash), CP2c (control's right-drag facing, green locally), CP3 (T1 in progress). Contracts S5 (one commitment term, two seams) and S6 (the light show) were added mid-round; the lead's lighting and camera items are in `game_design.md` *Round 9 addition*.

**In front of the lead (2026-09-20 01:15):** feel's **rig-hinge frames** — the War Rig articulated at the fifth wheel
(corner at 45°, the same corner at his pose, the reverse jackknife), sent as three strips built from
`~/projects/godot-feel/build/rig-hinge/` (stream/feel `7a706911`, laptop). Numbers beside them: live match, 32 rigs,
1,440 rig-frames, mean articulation 6.1°, 4.9% past 30°, 1.2% at the 65° clamp; the closed form `asin(5.06/12) = 24.9°`
at the rig's 12 m turning circle, reached 22.7° on the corner. **Caveat he should know:** the collider is still the
one 14 m box (S2), so a shell can pass through empty air inside a fold this round. Awaiting his look.

**In front of the lead (2026-09-20 02:55): the roster line-up at real relative scale** (`lineup_pose.png` at his pose,
`lineup_factions.png` all 21 by faction; builder0, `stream/scale` ~`8fc9a2a8`, K = 0.707). **Approved on his behalf
overnight**: the rig reads as a semi beside a car, the Condemned tank as a bus (8.6 m; on screen 281 × 135 px against
round 8's 199 × 100, the rig 734 × 279). Defects noted for one more render: labels collide in the factions frame and
its near row clips. He can overrule the look or K in the morning. **The gap-widening ruling was withdrawn** (scale's
first corridor measure was wrong; the corrected one shows no pinch on any rotation map: yard 18.0 m, terminus 11.5 m,
maze 7.0 m = its authored `MAZE_TIGHT_GAP`).

**In front of the lead (04:05): the Terminus alley pair** (`~/projects/godot-control/build/terminus-alleys/index.html`,
six pairs; `alley4_asked` = the camera inside a wall, `alley4_clear` = a squad in the street with rings, facades intact;
`alley5` is the open-ground control where nothing is cut). Lift + occlusion cutaway, control `c97d4d5f`, laptop, windowed
at his pose. Approved overnight; item 3 of control's brief is done on the hash its check names.

**One question for the lead, with a recommendation:** the roster is being scaled *rig-relative* (the world's vehicles
at K ≈ 0.7 of real size, so the 14 m rig he ruled on stays and the bus, garbage truck, APC and assault gun grow
1.5–2×). The alternative is *real metres*, which puts the rig at 18–21 m and roughly doubles apparent crowding on
every arena. **Recommendation: rig-relative.** If he prefers real metres it is one number (K) and a re-run of the
table, at any point before CP2 merges.

## Round 8 is CLOSED (2026-09-19). The state at launch of round 9.

**All six streams merged, worktrees removed, briefs archived to `_agents/streams/archive/round8/`.** `main` carries
everything. The six `stream/*` branches are kept as history; `make worktree STREAM=<name> OFFSET=<n>` recreates a
worktree for round 9.

- **Sim baseline: `glibc-2.43 04414f5d6a6dfa7c`** (was `0cb238bf366e141f`). Recorded from builder0, **read twice with
  both readings agreeing**, covering the two hash-moving changes: squad's brain and start positions, and combat's
  **widened match** — which is why it moved so far. The old match fielded five `tank` hulls and was blind to 5 of 6
  mutations; the new one fields every locomotion × mount combination.
- ~~**⚠ `main` IS NOT COVERED BY A GREEN CHECK.**~~ **Verified green at `f49aa08a` on 2026-09-20 (see the round-9 section above).** Was: combat was merged unverified **on the lead's explicit call** (*"checking
  in a dirty codebase is ok, let's just get everything merged so we can hit a milestone"*), so the round could close
  and the environment be reset. Its blast radius is bounded and was verified, not assumed:
  `git diff --name-only main...stream/combat -- game/` returns **nothing**. **The first task of round 9 is one full
  `make remote T=check` on `main`.**
- **Round 9 is planned:** `_agents/workstreams.md` *Round 9 goal* has the split, the order, and the argument for the
  order; `_agents/research_catalog.md` has the twelve adopted techniques with owners and falsifiers. **A12 (metrics)
  and T1 (parallelise `check`) come before any mechanism.**
- **Measurement provenance is preserved** in `_agents/streams/references/round8/` — 72 JSONs, the raw data behind
  every number the archived briefs cite. **Cite from those with their commit and machine, not from a brief's prose.**
- **Two traps for a fresh environment**, both in `_agents/remote_builds.md`: a cold `make import` exceeds `slot.sh`'s
  5400 s cap and is killed (use `TANK_SQUAD_SLOT_TIMEOUT=14400`), and a remote run that exits **255** is ssh, not the
  suite — after which `build/` holds a **previous run's** artefacts.

## ⚠ READ THIS FIRST: round 8 is merged; the lead's verdict on round 7 was "it still sucks"

**All six streams' round-8 work is on `main`.** What remains unmerged is documentation plus three small tooling commits
(control's camera-looks frame, arena's brief work, combat's per-matchup reporting) — **all of which has since been
merged too.** ~~`main` is green~~ **— see the close section above: `main` is NOT covered by a green check.** Baseline
is now **`glibc-2.43 04414f5d6a6dfa7c`**; `0cb238bf366e141f` was round 8's mid-round value.

### What the lead can now do that he could not

| his complaint | what shipped |
|---|---|
| *"the gang tanks are still tiny"* (×4) | **the War Rig is 14 m** — 721 × 315 px at his camera against a tank's 199 × 100. It drew **91 px tall** before, **shorter on screen than a tank** |
| *"the semi trucks are yawing in place"* | a wheeled hull with a **turret** gets `stop` instead of `face`; the turret aims, as a real truck does |
| *"not all units belong to a squad"* | **17 gang vehicles were on no number key.** Fixed from both ends, with an `ungrouped=N` readout at start |
| *"they don't obey… they shoot at whatever they were already shooting at"* | drills aimed at `Drills.nearest_visible`, never at the task's target. Task path **765/155 → 164/759** unit-ticks |
| *"it's still just a boring square"* | **yard and pit are hexagons**; `Arena.ROTATION` is `["yard","pit","terminus"]`, so `random` only deals maps he kept |
| *"the 3d polygon primitives… I have not seen that at all"* | **the Terminus** — a cityscape, built, named by the booth, in the rotation |
| scouts ramming their targets (round 7) | shoot-and-scoot: **3.0 → 27.7 m** closest approach, **29 → 211** shots |

**Plus, unreported by him and found on the way:** every gang vehicle played a **shield-destroyed crackle at spawn, ~40 at
once, since the gangs shipped**; the radar outline sat **20 m outside every wall on every map**; hulls with a cut gun drew
at **80% of their box** since round 7; five kinds of refused order **returned their reason to nobody**; and the camera's
lean **parked the selected squad under the command card** on every order.

### The three things the next round must not re-learn

1. **⚠ `sim-baseline` ONLY FIELDS TANKS** (lesson 137). Both doctrines in the baseline match are all-`tank`, one map,
   40 s. **"sim-baseline passed" means "a tank-vs-tank match on foundry is unchanged"** — it is blind to every wheeled
   hull, every gang vehicle, and every other map. **feel has twice proved its art inert by passing it; that proof holds
   for tanks.** Widening it is one match and it is the cheapest high-value fix available.
2. **The oscillation is measured and unfixed.** **5.3–7.2% of attack-moving travel time** on all four maps, pre-registered
   before the run. **It is not terrain** (`blocked_terrain` 0.000–0.010) and **it is not the hold path** (nav's A/B cleared
   it). The mechanism is **gear-shuffling** — forward and reverse within the same 2 s window. The remaining suspect is the
   **re-aim rate**, and the veto shape of that fix has already been measured and **reverted** (lesson 138).
3. **Three things were built, measured and thrown away this round** — flow fields, a gear-change cost, a target-switch
   floor. **All three were cheap because they were measured before shipping.** The expensive version is round 7's: ship,
   measure twice, then discover the mechanism was never reached.

### Open, and waiting on him

- ~~**12 m vs 14 m for the War Rig.**~~ **RULED 2026-09-19: it stays at 14 m** (*"we can revisit that later if it's still an issue"*). The cover cliff was an artefact of sampling the hull's CENTRE POINT, not of the maps — catalogue **A3** fixes the query at any hull length. Retained below only for the numbers: 14 m costs `gangs vs law` **9/20 → 0/20** across both maps (p ≈ 2×10⁻⁶), cause
  unresolved between splash/suppression and the creep. **Nobody is shrinking it to make the number look better**; feel has
  12 m ready and he decides with the frames.
- **The Terminus is in the rotation and marked UNJUDGED** — the constant and its test both say so, with a comment naming
  the line to change.
- **The crowd and the energy weapons** — he has the files and has not said.
- **Street-level detail on the city blocks** — feel's question, shipped plain deliberately.

## Current state (main)

- **Round 5 is fully merged** (render, arena, control, combat, ai, audio). Briefs and their reports are archived in
  [`_agents/streams/archive/round5/`](_agents/streams/archive/round5/); the measurements behind their numbers are in
  [`_agents/streams/references/`](_agents/streams/references/), each with its commit, machine and caveat.
- **The frame rate fight is won.** The lead's round-6 playtest does not mention it once. The simulation runs at
  **30 Hz** with physics interpolation, physics is **Jolt**, and the target the lead chose is **a locked 30 fps at
  1080p with 30 a side, plus a 720p 60 fps option** (his round-5 sign-off). Baseline for scale: 60 fps used to hold at
  13 vehicles at 720p and never at 1080p.
- **The game today:** StarCraft-style control with a camera that only shows what your force can see; elements that
  pick formations and run battle drills from real doctrine, the same library for you and the CPU; suppression that
  makes base-of-fire-and-maneuver real; four playable factions with their own rosters and doctrine; tank shells you
  can watch fly; a voiced announcer trio; layered sound and a music director; seven arenas.
- **Builds run on builder0:** `make remote T=check`. **Budget 30–50 minutes during an active round, not the 7 minutes
  the docs used to claim** — measured ~50 min for 1010 tests on `main` at `5c68a03e` with six streams live, because
  builder0 runs two slots and four concurrent checks both queue *and* slow each other
  ([remote_builds.md](_agents/remote_builds.md)). So: **iterate with a local `make check`, spend a remote slot only on
  a merge candidate**, and ask the orchestrator to clear a window for a big measurement series. **Read the result from
  the wrapper's own `>> remote: make check exited <N>` line and the runner's `N passed, M failed` — never a shell exit
  code through a pipe, and never the `waiting for a heavy-run slot` line, which is printed on enqueue and never
  retracted.**

## Round 6: six streams (planned 2026-09-18)

Goal: **movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get
stuck behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera
too far above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](_agents/game_design.md) *Round 6 direction*, his words in full).

| Stream | Brief | Outcome |
|---|---|---|
| nav | [streams/nav.md](_agents/streams/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, one regulated control law (PID). Proven on a maze (**N1 = CP1**) |
| squad | [streams/squad.md](_agents/streams/squad.md) | A squad order is a *formation* order: one formation system, a slot per unit, a form-up ETA, and every named task doing what it says (**N2 = CP3**) |
| control | [streams/control.md](_agents/streams/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, loading that shows itself |
| arena | [streams/arena.md](_agents/streams/arena.md) | Terrain that makes ambush and flanking possible, objectives off the centre line, and the maze nav is measured against (**N3 = CP2**) |
| combat | [streams/combat.md](_agents/streams/combat.md) | Seeing an enemy is not the same as opening fire: acquisition, a real effective band, fire discipline (**N5 = CP4**) |
| feel | [streams/feel.md](_agents/streams/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and a place that reads from a low camera |

Ownership, contracts (N1–N6, M1–M3, L1–L5, K1–K5, C1–C8), checkpoints and invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

### What the survey found, and every stream's brief is built on

- **There *is* pathfinding** (Godot `NavigationServer3D` over a navmesh, i.e. A* over polygons). What is missing is
  everything about *other units*: no RVO/ORCA, no separation, no reservation, no negotiation. One mechanism exists —
  `_around_friends`, which sidesteps the **single nearest ally** by 5 m without checking the sidestep against the
  navmesh, ignores enemies entirely, and is a no-op outside a `TankBrain`.
- **A stuck unit then lies about it.** `TankBrain.ORDER_STALL_ARRIVE = 12.0`: after 3 s of no progress, a unit within
  **twelve metres** of its goal declares the order complete. That is why a jammed horde looks like it *decided* to
  stop.
- **The formation abstraction the lead described exists three times** — `game/control/group_formation.gd` (used by a
  plain player move), `game/ai/formations.gd` + `squad.gd` (≤ 5 members), `game/tactics/tactics_formation.gd` (any
  size, sectors, the best of the three) — with three shape tables, three assignment rules, three pacing rules, and no
  single owner. And **a plain `move` deliberately bypasses the element layer and dissolves the element**
  (`rts_controls.gd:42-46`), so his commonest order is the one that turns a squad back into loose vehicles.
- **Formation slots are never validated against geometry** — clamped to the arena rectangle only, so a wedge beside a
  container stack puts vehicles inside it.
- **Steering is a pure P controller** with one gain for the whole game (`turn = clamp(-error/30°, ±1)`), which is
  exactly the gap the lead's PID instinct points at.
- **Firing needs no acquisition.** `_shootable()` admits any target inside weapon range with a clear physics line of
  sight; the comment records that the `seen` test was found unused and **removed**. And `effective_range == range` for
  every core weapon, so there is no band where a shot is legal but bad. That is the mechanism behind *"units see each
  other and then everyone just starts firing"*.
- **Pitch is welded to zoom** in `rts_camera.gd:179-185` (`lerp(25°, 82°)` over the same slider as `lerp(16 m, 260 m)`).
  A player commanding 30 vehicles zooms out; there is no way to zoom out without tilting to near top-down. The lead
  never chose a bird's eye view — he chose to see his army, and the camera charged him a top-down for it.
- **Nothing about loading is threaded** — no `Thread`, no `WorkerThreadPool`, no `ResourceLoader.load_threaded_*`
  anywhere in `game/`. FIGHT synchronously loads the scene, builds the venue, **bakes the navmesh**, and instantiates
  ~44 vehicles a side in one frame, with no progress UI of any kind.
- **The crowd already exists** and shipped 2026-09-14 — MultiMesh, 900–4000 figures, seats from the stands' rows,
  reacting to `FxWorld.spectacle`, plus a `crowd_voice.gd` murmur and roar bed. So the lead seeing none of it is a
  *diagnosis* job, not a build job: find out what hides it before adding anything.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all six:

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

### Where round 6 actually stands (2026-09-18 evening, the lead away)

**Four streams have finished: feel, control, combat, squad.** arena has delivered its review page and holds one item;
nav is the only stream with work in flight.

**Merged and green on `main`** (every merge at the commit whose own full check went green):
one formation system instead of three · support-by-fire that forms a real firing line · the player's units holding
until ordered, *enforced by a rule rather than by a coincidence* · a plain move keeping a squad a squad without order
thrash · form-up paced by a real navigation ETA · loading **7.6 s → 1.4 s** · **3,011 spectators in the default frame**
(round 5's default showed 0 of 2,040) · stands on all four sides, a city skyline, crowd audible through a proper mix ·
the lead's **12°** camera with the wall cutaway · the task palette with APP-6 symbology, `move`/`follow` off the card,
Support by Fire / Screen / Ambush earned · a loading screen and "why did my element do that" · the maze and
`make nav-maze` · terrain authoring rules · the **N1 Movement API** · engagement ranges: **fights decided at 40 m
instead of 54, off-axis kills 26% → 45%**.

**Held deliberately, and it is the lead's call:** nav's ORCA avoidance + right-of-way + PID reaches **100% arrival in
every configuration** (maze-60 head-on went **0 → 60/60**; `yard`-60 34 → 60/60) but costs a tick of order-response
latency — **4 ticks where K1 guarantees 3 (100 ms)**. Arrival bought with responsiveness is a trade he has not
approved, and *"the units aren't very responsive to my input"* is his own round-5 complaint. **Do not merge it, and do
not let anyone weaken the K1 test, without him.**

**What the round actually taught, and it is not what anyone expected:** it found **more broken instruments than broken
game code**. Three load-bearing coincidences (lesson 50), four constants calibrated against a camera that had changed
(lesson 59), six tick-rate leftovers of which three lied to a reader rather than failing a test (lesson 30), a build
queue that starved rather than being slow (lesson 48), an audio harness recording at 1/10 speed (lesson 46), a
measurement whose outliers were a spawn bug (lesson 57), and a series whose control was not a real "before" and so
hid which half of the change did the work (lesson 62). Lessons 32–62 are all round 6.

**Open orchestrator obligations (round 6):****Open orchestrator obligations (round 6):**

1. **Ping arena the moment CP4 merges.** arena is holding X3 (objectives off the centre line) until then, because it
   is a tactical claim that would straddle the range change. At the same ping it re-derives X2's exposure numbers at
   the new effective range — one cheap Python re-run, not machine time. arena found that its static
   exposure/sightline numbers are *mostly* CP4-proof (eye-level rays against box footprints, no weapons involved),
   with one exception it flagged rather than buried: `exposure()` hard-codes a **110 m watcher range**, which is a
   weapon-range assumption wearing a sightline's clothes.
2. **The sim baseline WILL move with CP4, and combat owns the move.** It is not a perturbation: N5 changes when the
   trigger is pulled, so a different battle happens from first contact onward. The order combat set, which the
   orchestrator endorsed: **series → final bands → record the baseline twice on builder0 → one commit.** Until that
   commit exists, **no stream re-runs a determinism-sensitive measurement**, or it will be comparing against a hash
   that is about to be replaced.
3. **CP4 does not merge alone: it merges paired with squad's brain-range fix.** combat's evidence, which the
   orchestrator accepted: `TankBrain._combat_move()` decides where to stand from `weapon["range"]` (full reach) while
   N5 decides firing from the *effective* band, so the outranging and short-halt branches park a unit exactly where it
   may not shoot — measured at **61 m for 45 s, 0 shots, 0 metres, never arrives**. Landing CP4 alone would trade the
   lead's *"everyone just starts firing"* for *"everyone stands still"*, which is a worse game and breaks product
   constraint #1. combat has committed a two-token proposal **in squad's file** (`5478fa61` on `stream/combat`,
   explicitly to take, replace or revert) which makes the scenario finish in **14.9 s — faster than the 20.8 s it
   measured before N5 existed**. squad owns the judgement and the remaining cases; **`scenario_motion::test_brains_dont_dither`
   at 17.7 and 15.6 option switches per minute against a bar of 12 is the blocking one**, because "no element
   flip-flopping" is the round's legibility bar.
4. **DONE — CP2 merged** at arena's green `5590c465` (1018 passed, exited 0). Note for the record: arena first
   reported `38c15f77` ready on a *filtered* run showing 5/5; the full check found 2 failures, and `38c15f77` and
   `13add85d` are both **red**. Merging the commit whose own full check went green (lesson 29) is the only reason that
   never reached `main` — and lesson 45 is the filtered-run half of it.
5. **TWO merges re-time other streams' measurements this round, not one.** CP4 is the known one. The second, found by
   control: **`perf_scene.gd` calls `RtsCamera.pose_for(focus, 0, zoom)`**, so when control's pitch decoupling merges,
   `make perf-scene`'s camera drops from the welded pose to the lead's **12°/FOV 60** — a far lower, wider camera that sees the whole venue to the far stands,
   so feel's **M1** frame numbers move at that merge through no change of feel's own. Relayed to feel; the rule is the
   same as CP4's: **re-baseline after the merge, and never publish a frame number measured across it.** This is the
   generalisable shape — a shared harness that derives its own configuration from another stream's code silently
   inherits that stream's changes.
6. **RESOLVED, and now with the lead: the mix was the cause, and the crowd question costs nothing to answer.** Two
   recordings were sent to him 2026-09-18 while he was away — `build/crowd-listen/full_mix_real_pace.mp3` (the match as
   a player hears it) and `crowd_only_real_pace.mp3`, builder0 vsync-off at tree `1badf779`, Yard, Gangs vs Law, same
   seed. **The one question: is the crowd audible, and does it sound like people or like hiss?** The murmur is still
   round 3's procedural filtered noise. **If hiss**, the ElevenLabs text is drafted in feel's brief under *Waiting on
   the lead*: 5 sources (bed, tense lull, roar, near-miss "oooh", last-stand stomping), **pilot first** —
   `crowd_bed` + `crowd_roar`, ~25 s ≈ **250 credits**, full set ~900 (lesson 19). **If fine, nothing is spent.**
   The mix itself was settled by measurement: at +13 dB the crowd was the loudest bed in the game (~4 dB under the whole
   mix); at **+8 dB** it sits a median **7.5 dB** under (min 5.6), impacts dipping it 2:1 on top; −17.5 LUFS, true peak
   −3.6 dBFS, 0 clipped.
   *The rule that produced this, kept for next time:* an ElevenLabs request must never be approved while the mix could
   be the cause — feel measured the existing crowd murmur as procedural filtered noise at **~43 dB below
   full scale on a Bed bus that is ducked under impacts** — inaudible in a firefight whatever the source material is.
   Recording a better bed and playing it 43 dB down buys an inaudible better bed. The order the orchestrator set:
   solo the crowd, record a real match, fix the mix (bed level, duck depth and release, a ceiling on how far impacts
   may duck the bed), re-listen — *then* ask for credits if it is still thin. Paid generation is irreversible in a way
   a gain change is not (lesson 18), and the standing gate is text → cheap pilot → listen → batch (lesson 19).
7. **Tell nav the hour CP4 merges.** It is doing `movement.gd` first (combat's four edits are all in the gunnery half)
   and the `gunnery.gd` split *after* CP4, so combat's edits move across once instead of conflicting. Its plan, endorsed.
8. **nav must NOT delete `ORDER_STALL_ARRIVE` (the 12 m lie) yet, and knows it.** It is one line in squad's
   `tank_brain.gd` — the file squad has two gating fixes in flight in — and removing it makes arrival numbers look
   **worse** before avoidance makes them better. With three streams measuring, we would lose the attribution on all
   three. It lands later as its own commit with a before/after from arena's harness attached. Its entire value is the
   measurement that comes with it.
9. **X4 is held, not lost, and the bar for re-adding it is written into `rts_controls.gd`:** *0 idle commands on five
   squads in the lead's own sequence.* control measured 31 idle commands and `never_arrived` 0 → 3 of 21 with it on
   (round 5's healthy value was 0) — and "units never arrive" is the lead's *headline* complaint, so it must not ship
   on a hope. **squad owes the answer: designed station-keeping, or thrash?** When it re-lands, the A/B must be re-run
   **on the merged tree** — CP3 changed the formation system underneath the exact path X4 exercises, so 31-against-0
   was measured against a world that no longer exists.
10. **Which arenas are fun is still unanswered** (`fun: []` on both pages, 2026-09-18). arena is spending the round on
   map shape without it. Nothing is blocked; ask again on whatever page he sees next.
11. **nav was not started with the other five streams** (2026-09-18). Its brief now carries arena's full CP2 baseline
   so it starts with the target number rather than rediscovering it; squad has been told to take its two independent
   items first and explicitly *not* to build its own avoidance to fill the gap.

**Orchestrator duties this round:** merge CP1 (nav's Movement API) and CP2 (arena's maze) as soon as they're announced
and tell everyone to `git merge main`; **CP4 (combat's engagement envelope) lands once and early, and every stream
re-runs its measurements after it — nobody publishes a number that straddles it**; get control's camera page in front
of the lead the day it exists; relay findings between streams; rescue git-ignored payload from worktrees before
removing them ([backups.md](_agents/backups.md)). Final integration order: nav → combat → squad → arena → control →
feel.

## Waiting on the lead

1. **The camera look AND which arena is fun — both are on one page, live since 2026-09-18:**
   **https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL** (private to the lead's account). One frozen 30-a-side fight
   (Condemned vs Syndicate, Container Yard, seed 3, ~6 s after the first shot): row 1 is round 5's four welded poses
   (zoom 0.20/0.36/0.55/0.75 = 34°/45°/56°/68°, the last being the "bird's eye" he disliked); then a grid of
   pitch 25/35/45/60° × distance 28/50/90 m × FOV 45/60°; then an arena tour, all seven arenas at three poses each
   with a **Fun** checkbox. He taps a frame to pick it (optional note) and ticks the fun arenas.
   **His answers are saved in the page's own database at `picks/lead`** — read them back with the Artifact tool's
   `read_db` on that URL, then tell control, which sets the defaults from his pick.
   Provenance: rendered on the **laptop** at 1920×1080 from `stream/control`'s working tree at `a975e262`
   (uncommitted at the time). Frames are camera poses only, so machine and commit do not change what they show.
   **The diagnosis is confirmed by row 1:** the start pose was fine; zooming out is what tilted him to top-down.
3. **The Lancer sits in two factions** (Condemned `lancer`, Syndicate `syn_lancer`): the role is shared, the vehicle
   isn't. One of them may want to lose it.
4. **Meshy credits: 88 left.** Any new 3D art needs a top-up. ElevenLabs has ~123k.
5. **Git LFS, eventually.** `.git` is 353 MB and grows with every regeneration. The rule to adopt when it hurts:
   generated binaries that *ship* go in LFS; generated *sources* stay out of git and live in backups.
6. **Faction art is excluded from the web export** (47 MB): the three new rosters *play* as themselves but *look* like
   the Condemned in the browser. Desktop ships the real art.
7. **Carried over:** rotate the Meshy API key; the round-2 questions in `streams/archive/round2/`.

## Open questions and follow-ups (not scheduled)

- **Dynamic obstacles: deliberately none, and now with a reason rather than a default** (arena ruled, nav verified,
  2026-09-18). **Nothing blocks drivable space mid-match, now or planned**, so a `NavigationObstacle3D` has no consumer.
  The strong argument against building one is **fairness, not cost**: the navmesh is baked as the southern half plus its
  180° rotation *as a second region*, because a normal bake is not point-symmetric — mirrored trips differed by up to
  4.4 m and the south base won 64% of 140 matches (trip-up 21). **Any mid-match re-bake must reproduce that
  construction or silently reintroduce the base bias**, with units standing on the mesh while it happens. And the lead's
  approved destructible-cover design (*a stack collapses to a lower stack, never changing drivable space*) was chosen to
  avoid exactly this, so X6 will not create a consumer either.
  **If round 7 ever revisits the startup-only mesh, it must revisit `agent_max_climb` in the same breath** — both are
  consequences of the same construction, and both need the swap-bases control re-run.

- **The unifying shape of round 7's best candidates, named by arena:** *the correct behaviour depends on what the
  element is currently trying to do.* Round 6 made each layer correct **in general** — avoidance that keeps a column a
  column, an objective at the centre, a formation that holds its geometry — and the residue in every case is that the
  *right* answer changes with the element's current intent. Three items below are the same statement at different
  scales: not overtaking is right for a column and wrong for a charge; a central objective is right for a brawl and
  wrong for a game about flanking; a fixed slot is right for holding and wrong for forming up. **A round that made
  behaviour context-dependent would be the natural successor to one that made it correct.**
- **Should a battle drill override formation discipline?** Round 6's ORCA deliberately does **not** treat a friend
  moving the same way as a collision, so a column stays a column — which is right for formations and is why round 5's
  overtaking sidestep was removed (it also steered into walls unchecked). Attributed cost, measured by bisect: an
  assault-through an ambush now takes **18.5 s against 17.7 s**, because the quick units no longer pass the slow ones.
  **0.8 s is not worth re-adding overtaking for** — it would risk nav's 33/60 → 60/60 arrival result. But *a charge is
  the one case where you might want the fast units through rather than the column preserved*, and the lead would notice
  it as *"my fast units got stuck behind the slow ones during a charge"*. Round-7 question: do drills get to suspend
  formation discipline, and which ones?
- **The lead's PID request is half-delivered, and the missing half is the visible half.** nav's N6 regulates any
  `move_to` whose goal *slides* — a squad follower's leader-anchored slot is such a goal, so **squad station-keeping is
  PID-controlled and measured (0.35 m mean gap against 4.58 m for the old proportional law)**. squad deliberately added
  **no second regulator**, which is right. But **element slots are fixed per leg or per click**, so the PID never
  engages for elements: an element still *snaps* to its formation geometry rather than **flowing** into it. The lead's
  own words were *"no matter where they might be currently, there's a formula to form up"* and *"a PID loop would
  conceptually be useful for a unit trying to get back in his formation"* — the second is delivered for squads and not
  for elements. **Making elements flow into formation is the next build on top of N6**, and it is the piece most likely
  to make the formations *look* as good as they now measure. A round-7 candidate, and cheap now that the regulator
  exists.
- **Per-faction PID gains** (nav's X8, not started): the lead asked for it by name — *"we might even be able to
  differentiate units of different factions by PID values"* — the Syndicate crisp, the gangs loose. `control_gains.gd`
  exists and the defaults are stable, so this is now a data exercise. It must be **measured** rather than shipped as
  flavour: if identical armies with different gains win equally often and look the same on screen, say so.

- ~~**A texture leak on `main` that `make check` cannot see**~~ **FIXED in round 8 (`3040ccd9`), together with the void
  below the near wall; feel re-verifies both at the lead's poses in round 9, and the console gate itself is control's
  round-9 item 4.** The original note, kept for the reasoning: (found by control on the merged tree at `2fa58c01`,
  laptop, windowed): `make shell-playtest` fails its clean-console gate with two `ERROR: Texture with GL ID of
  142/143: leaked 5460 bytes` lines, absent in all seven pre-merge runs. Likely feel's `night_sky`/skyline shaders or
  `arena_environment` crossing the **title → skirmish scene switch** — control's inference, not a proof; routed to
  feel. **Why it matters beyond two console lines:** `shell-playtest` is **not in `make check`**, so `main` goes green
  with it; a leaked resource is an **ERROR**, and the relay and net smokes fail their clients on any ERROR
  (trip-up 75), so this may be one scene switch from breaking a gated smoke; and it happens on the transition every
  player crosses. **Round-7 candidate regardless of this fix: `shell-playtest`'s console gate belongs in `check`, or
  its expected state belongs in a committed baseline** (lesson 42 — do not simply add a red suite to the gate).
- ~~**The void below the near wall.**~~ **FILLED in round 8 (`3040ccd9`).** Was: the ground plane ended at the stands,
  so any camera outside the venue looked down into black, the bottom 15–40% of a far frame at the lead's 12°.

- **FIGHT → playable is 7.6 s → 1.4 s** (laptop, `make shell-playtest` gangs vs law on Boulevard: 7,563 ms at
  `a975e262` against 1,398/1,406 ms on two runs of `8d9c59af`'s tree). feel's strong-reference fix did the shortening —
  `make spawn-cost` went from ~63 ms per vehicle to **0.8 ms** after the first of each type — and control's loading
  screen makes the remaining beat legible rather than shorter. **What is left is the arena build + navmesh bake, ~690 ms
  of the 1.4 s**, which is synchronous on purpose for determinism (trip-up 57: async navigation iterations made the same
  seed simulate differently). Not scheduled: it belongs to arena or nav, it is a ~0.7 s win, and it must not be bought
  by making navigation async.
- **Round-3 `matchup-search` numbers in `balance.md` may be unreliable and cannot be re-derived.** A make-namespace
  collision (`UNITS ?= 60` in `mk/ai.mk` reaching `mk/match.mk`) meant **every `matchup-search` run silently passed
  `--units 60` whatever the caller asked for**, and the tool never recorded the value it used
  ([orchestration.md](_agents/orchestration.md) lesson 44). Fixed as `SEARCH_UNITS`. Any conclusion that assumed a
  non-default unit count is suspect; combat flagged this rather than assuming the old numbers were fine. **The general
  fix, worth doing everywhere: print every resolved knob into the output**, so a wrong value shows up in the artefact.
  Related and also open: **nothing checks that a "reproduce with" line in a reference README still runs** — `make
  engagement PAIRS=… SEEDS=3 TIME=240`, documented as the way to reproduce a saved baseline, had been broken since the
  `VARIANTS` default landed. A smoke test that runs every documented reproduce line is a round-7 candidate.

- **Backups are automatic** ([backups.md](_agents/backups.md)): a systemd user timer rsyncs the git-ignored generated
  assets to `builder0:~/tank_squad_backup/` every 30 minutes, never deleting. `make backup`, `make backup-status`.
  **A worktree's ignored payload is still only in one place until it's copied into the main checkout** — round 5's
  close rescued 195 MB of announcer and ElevenLabs masters out of the audio worktree.
- **The element layer does not yet earn its place at 30 a side.** With the control point on, brains-only beat faction
  doctrine 34-14; with it off, 27-21; cutting `break_contact` reaches parity (24-24), not better. The army-level layer
  proposed in `doctrine.md` is a **bet** on the missing layer being *above* the elements, not a fix for the drills.
  Evidence: `archive/round5/ai.md` and `references/round5_ai_ladders.json`.
- **The control point funnels the whole fight** — found independently by three streams. arena owns the fix attempt
  this round (objectives off the centre line), measured with a control that cancels the cause, not more seeds.
- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%, 5 seeds) — pre-Jolt, pre-30 Hz. Re-measure after
  combat's CP4 before tuning anything.
- **Determinism:** `NavigationServer3D` is on the risk list ([determinism.md](_agents/determinism.md)); the grid-A*
  replacement is unwritten. Navigation map iterations are pinned **synchronous** in `project.godot` (trip-up 57) —
  do not switch them to async to make a loading bar look nicer.
- **Cross-build determinism** (D1–D4), the **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), the
  Steam build, arena announcer audio, and the paused netcode, garage and progression streams.
- **Disk:** the laptop is at 95%. `assets/incoming/` alone is 968 MB of raw generated art.

## Three claims on `main` that are weaker than their commit messages say

All three are the orchestrator's, all three were caught by streams on 2026-09-19, and the first two are the same
failure: **an instrument that could not have detected the treatment.** The third is worse.

- **⚠ THE ARRIVE-ON-HEADING ARC CANNOT FIRE IN THE GAME THE LEAD PLAYS.** Round 8 reported *"cars arrive on heading"*
  to him as shipped. Found by control, verified independently by the orchestrator in the code rather than relayed:
  a `facing` is put into a move command in **exactly one place** — `game/ui/tactical_map.gd:269`, the **touch map's**
  right-drag (*press = destination, drag = facing*) — and **the touch map is behind `--touch-map` /
  `--command-playtest`** (`game/modes/skirmish_mode.gd:112`, `:301`). His desktop controls are `RtsControls`, which
  only ever **reads** `facing` (`game/control/rts_controls.gd:307`, for camera yaw and the order pin) and **never
  sends it**. squad sets one for holds and stations; **a player move never carries one.**
  **So nav's `_arrive_facing` arc is not merely unmeasured — it is unreachable on the default path**, and its gate
  counters reading `aimed 0, refused 0` in both A/B arms would read the same in a real match. This is the round
  skill's own rule — *a behaviour behind a flag the default path never passes has not shipped; play the default
  path* — broken again, and the orchestrator relayed it to the lead as a win instead of playing it.
  **Round 9, control's fix, small and already scoped:** give the desktop right-click the same grammar the touch map
  has (press = destination, drag = the facing to arrive on), with a test asserting `orders.current(unit)["facing"]`
  after a drag **so the next A/B has a live arm by construction**, checked at the lead's pose so a facing drag cannot
  read as a box-select. **And note for round 9's probe:** even after that lands, `nav-fight` issuing a plain `move`
  still measures nothing. **The live cases are a player drag and a squad hold.** Do not re-measure zero twice.

- **`6a8aaa8c` says the facing pair does not move the sim baseline.** It was measured against the old `sim-baseline`
  match, which combat then showed was **blind to 5 of 6 mutations** — wheeled turn rate, fixed-mount fire arc, hover
  speed, the rig's hull box and a turret traverse all left the hash unchanged, and only the tracked case registered.
  Arrival-on-heading on a wheeled hull is plausibly inside that blind set. Re-run against combat's widened match
  (`db837581`).
- **The facing arc is not "measured inert".** nav's A/B returned every figure identical between arms to three
  decimals across four maps — and its own arm-engagement counter read **`gates aimed 0, gates refused 0` in BOTH
  arms.** The arc never executed. `_arrive_facing` attaches a facing only when the order carries one, and `nav-fight`
  issues `move` without one, so a CPU fight never triggers it. **Write it as "measured to never execute in a CPU
  fight; untested under player facings"** — the cases where it does fire, a player drag-order with a facing and a
  squad holding one for an ambush, are exactly the cases the lead looks at. Round 9's probe must issue orders that
  carry a facing or it re-measures nothing.

## The round-9 backlog is already written

**[`_agents/research_catalog.md`](_agents/research_catalog.md)** is the curated output of an external research review
the lead commissioned on 2026-09-19 (two independent services, one abstract brief, both replies kept verbatim in
`_agents/research/`). **50 techniques proposed, 12 adopted with a pre-registered falsifier each, every rejection given
its reason.** Eight of the twelve were named by *both* services independently, which is the strongest signal in it.

Read it before briefing a stream, and note three things it changed:
- **`algorithms.md`'s rejection of learned policies was built on a wrong premise** and now says so. A lead decision.
- **Invariant 0c** in `workstreams.md`: a technique adopted in one stream is checked against the others *before* either
  merges, and a brief that adopts one must name what it **replaces**. Two correct techniques can compose into neither.
- **Round 8's flow-field null does not refuse catalogue A5** (anisotropic exposure-metric routing). Different object,
  and the roster row says so.

Also: the sources contain mid-sentence truncation, and Service A's audit counts and Elo figures are **unverifiable
assertions about a codebase it has never seen — never quote the digits.**

## Starting the next round

The pattern, the kickoff prompt, and the checklists are in [`_agents/orchestration.md`](_agents/orchestration.md).
When the lead's next playtest feedback lands, it goes into [`game_design.md`](_agents/game_design.md) verbatim, the
streams into [`workstreams.md`](_agents/workstreams.md), and the briefs into `_agents/streams/`.
