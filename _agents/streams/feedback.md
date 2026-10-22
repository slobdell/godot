# Stream: feedback (the player sees what the rules are doing)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 37** (C37.1, C37.6), `_agents/game_design.md`
> *Round 36: his direction against the slug-fest* and *OPEN QUESTIONS for him before round 37* (answers 8, 9a, 10). **You own:**
> `game/theme/**`, `game/ui/**` (except orders' order hints), `game/audio/**`, `game/announcer/**`, new assets under `assets/` for
> your items, `tests/test_feedback*.gd`, `tests/feedback/**`, `mk/feedback.mk`. Presentation only: sim-baseline must not move.
> **Model:** Opus. **Machine:** builder0 for checks; the laptop for looking (the laptop is his test bed: Intel UHD 620).

## The lead's direction (verbatim in game_design.md)

On the support trucks (2026-10-20): the non-lethal vehicles "just seem to be wastes of units"; "For both the medic truck and the
siren truck, we need to add some sort of clear visualization". On unit swaps (2026-10-21): **"for the two units I identified earlier,
we just need visual feedback for the player"** (the gangs' Resupply Tanker, the Law's Sonic Emitter). On flanks (9a): yes, make
flank and rear hits obvious. On suppression (8): a pinned unit shows it ("slow, never stop, and show it").

What he will notice: the Tanker's repair is visible (what it is mending, how fast); the Emitter's cone and the crews it has
heads-down are visible; a rear or engine-deck hit flashes and sounds different and the announcer calls it; a pinned crew looks pinned.

## Where things stand

- **Resupply Tanker** (`units.gd` ~622): `repair_radius_m` 18, `repair_hp_per_second` 5; repair ticks in `Match` (~905–920,
  `repair_rate_for`, after `REPAIR_QUIET_SECONDS` 3). Nothing shows it today.
- **Sonic Emitter** (`weapons.gd` `sonic_emitter`): CONE 40 deg, range 32 m, 18 dps, **4.0 suppression a second**. Nothing shows the cone.
- **Hits:** `Match.projectile_impact` flags `weak_spot`; `Armor.facing` gives FRONT/SIDE/REAR. Hits all look alike today.
- **Suppression:** `Tank.suppression` 0..1; rules' R3 adds `Tank.pin_slow()` (C37.2).
- Memory rules for assets: 2–3 directions per slot on a tap-to-approve page before anything final; he limits the COUNT, not the
  spend; announcer satire subtle, the caller authentic UFC hype.

## Backlog (in order)

1. **F1 the directions page** (C37.6): 2–3 directions each for the flank/rear hit, the pinned look, the Tanker's repair, the
   Emitter's cone, as stills or short clips from the real game on his laptop preset. The orchestrator publishes/relays it and records
   his picks in game_design.md; build nothing final before the pick.
2. **F2 the support trucks** to his pick (both factions, both his preset and the full look).
3. **F3 flank/rear hits**: flash, sound (≤ 4 new sounds in total this round, ElevenLabs, best quality), announcer line (the
   `weak_spot` / rear call; subtle, believable).
4. **F4 the pinned look**, reading suppression now and `pin_slow()` once R3 is on main.
5. **Stretch:** the radar marks a pinned enemy; the unit panel names "pinned" / "repairing".

## How to verify

Tests for the readers; screenshots and clips you have LOOKED at, on his laptop preset and the full look; perf on the laptop preset
(no new cost past the HUD budget: `make control-timing`); `make skirmish ARENA=terminus` with the gangs, then the Law. For anything
subjective he is the only check: the page.

## Don't touch

Simulation code (rules', cover's, orders', manoeuvre's paths), `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing. **His picks landed 2026-10-21 ~19:55 PDT** (page db, game_design.md "his picks on feedback's directions page"): hit
**C**, pinned **A**, repair **A**, cone **C**, all six audio items approved; the orchestrator confirmed. Built (F2-F4 below).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-21/22, F2-F4 built to his picks.**
- **His picks are the game's** (5c8845969), ON by default (`FeedbackLook.DEFAULTS`); `--feedback-look=hit:off,marks:on`
  turns any off/on. hit C: the struck face's quarter of a ring under the tank, toward the shot (FACE_COLORS: side yellow,
  rear red, front pale at 0.45). pinned A: one to three chevrons over the bar (`UnitBars.chevrons_for`, reads
  `pinned_of`, which reads `pin_slow()` when R3 is on). repair A: the green beam, Tanker -> patient. cone C: the shimmer.
  `marks` (radar ring, card words) stays OFF: not on his page. **Deleted:** every losing look (flares, hit markers, pin
  rings, reach rings, mending glow, bar text, ripples, footprint; the ground shader is one kind now) and the directions page
  builder; `make feedback-shots` now shoots each pick on/off.
- **F3 sounds and lines** (e12aa27cc), his six approved items. ElevenLabs (ledgered): `eleven_text_to_sound_v2` 5 takes /
  14 s / 140 credits (121443 -> 121303) for flank_hit x2, rear_hit x2, repair_loop x1 (sources.json; `make sfx-layer`
  -> assets/audio/layered); `eleven_multilingual_v2` 3 requests / 175 characters for caller.hit.flank.01-03 (STT 3/3 ok;
  the balance read 121303 both sides, the ledger row carries the 175). Played: flank_hit / rear_hit over a gun round's
  side / rear hit (once per target per 0.4 s; never a stream or artillery), repair_loop while a beam shows (`RepairHum`,
  2 voices, nearest patients). **Found and fixed on the way:** the live booth never knew which face a round struck
  (MatchEventAdapter inferred damage from hull loss), so the existing rear and weak-spot calls only ever played in the
  recorded fixtures; it now reads the K2 impact (`_struck_face`, artillery = no face), and AnnouncerMemory tags `flank`.
- **Audio files:** what ships is committed (assets/audio/layered/{flank_hit_1,flank_hit_2,rear_hit_1,rear_hit_2,
  repair_loop_1}.wav + .import; assets/announcer/clips/caller/caller.hit.flank.0{1,2,3}.ogg). The paid MASTERS are
  git-ignored (backups.md) and live only in this worktree; copy them into the main checkout at merge:
  assets/audio/elevenlabs/masters/{flank_hit_1.53ee27c251,flank_hit_2.c69e8cd824,rear_hit_1.ba6a4361f1,
  rear_hit_2.9500a7bf63,repair_loop_1.776af65f15}.mp3 and assets/announcer/masters/caller/caller.hit.flank.0{1,2,3}.
  {mp3,json,level.txt,norm.wav}.
- **Looked at in a real fight** (`make remote T=feedback-fight`, laptop preset, his pose): the first capture of his picks
  showed the ring segment blooming into a white disc under a firing line (31 hits in 3 s on a War Rig); fixed in aae7355a2
  (one per target per 0.3 s unless the face changes, 12 m cap, clamped light).
- **Desktop preset (F2, FX HIGH / LOOK FULL, builder0, seed 5):** the glow (threshold 0.9) still turned the
  segments into a white pool under a firing line: they were additive and ~3 stack per face (0.9 s life, one every
  0.3 s). The shader now blends instead (blend_mix, light as opacity), so overlaps settle at the face's colour. Seen in
  hit-only recaptures on desktop and laptop: solid yellow side / red rear wedges, no white. Pinned chevrons and the cone
  shimmer read the same on desktop as on the laptop. Clips: build/feedback-fight/{desktop,laptop}-seed5/, the additive
  one kept in desktop-seed5-additive/.
- **Green hash to merge: 4c8946fd1** (make check exited 0 on builder0: 25 passed, 2 NOT JUDGED (perf-judge refused 3x,
  box busy at 2.55/2.34/2.48x; ai-scenarios 1 refused), 3030 passed / 0 failed, sim-baseline unmoved on 13 maps).
  Merged as main ac8cb7d92 (R37.36). Clips of his picks: build/feedback-fight/picks/ (README.txt), rebuilt on
  4c8946fd1 for both presets after a remote copy-back --delete wiped the local-only folder; mk/feedback.mk now exports
  REMOTE_COPYBACK_PROTECT=feedback-fight/picks/ so it survives. The desktop hit clip is the same 30-hit firing line that
  bloomed white before blending: now yellow side / red rear wedges.
- **Check fixes (de57b3231, green on builder0: 25 passed, 2 NOT JUDGED (box busy), 3030 passed / 0 failed, sim-baseline
  unmoved on 13 maps):** e35c6abcf failed announcer-transcripts-check (with the booth hearing hit faces, scouts_vs_tanks
  seed 2 now calls "Caught broadside!": regenerated) and test_sfx_pipeline (SfxSystem.ALIAS now names a stand-in for
  flank_hit, rear_hit and repair_loop).

**2026-10-21, F1 page up, picks pending.**
- **Real-fight clips of the recommended looks** (orchestrator's ask, kept in the tree, not published):
  `make remote T=feedback-fight` (FB_FIGHT_SEED=, FB_FIGHT_CLIPS=, FB_FLAGS=--feedback-fight-slots=repair) runs a
  spectated CPU fight, gangs v Law, laptop preset, his pose, and films each slot's moment as it happens (hit: a crew
  flanked 2+ times in 2 s; pinned: the most suppressed crew; repair: a Tanker mending; cone: an Emitter blowing).
  The picked set: build/feedback-fight/recommended/ (README.txt says which seed each is from). Looked at: the flank
  flares, the chevrons, the green beam and the violet footprint all read at his pose. quick-remote builder0 164/0.
  Capture lessons: a skirmish without --cinematic sits in its planning pause; the spectator's CinematicCamera cuts
  away mid-clip unless its process is paused; runs overwrite each other unless each seed has its own folder.
- **Finding for the lead (repair):** in seeds 3 and 5 all three gang Tankers died within ~25 s of contact and no
  mending ever ran (FEEDBACK_FIGHT_STATE: the one hurt friend in reach was still under fire; repair needs 3 s quiet).
  Seeds 7 and 11 showed it. In a real fight his Tankers rarely get to mend: worth a rules question, not a look one.
- **Nothing new shows by default** (d22d6867c, orchestrator's ask): with no `--feedback-look` every slot is OFF, and
  the stretch (radar ring, PINNED / REPAIRING on the card) sits behind `marks:a`. `FeedbackLook.RECOMMENDED` keeps my
  recommendation; once he picks, DEFAULTS becomes his pick. To try them all: `--feedback-look=hit:a,pinned:a,repair:a,cone:b,marks:a`.
  Merged main 406d00623 (cca1a994b); quick-remote builder0 129 passed, 0 failed.
- **7e2ff0a4f is green: builder0 `make remote T=check` exited 0, 3025 passed, 0 failed, "27 targets, all passed, ALL
  JUDGED", perf-judge PASS, scenarios 53/0/4 pending/0 unexpected, every sim-baseline unmoved.**
- **305f71a37 check: builder0 `make remote T=check` exited 0, 2985 passed, 0 failed, scenarios 52/0, every
  sim-baseline unmoved** (3811 s). Two NOT JUDGED on a busy box (perf-judge ratios 1.9-2.4x; one ai-scenario), being
  re-run alone on the merge below.
- Stretch done (305f71a37): the radar rings a pinned enemy in sight (yellow); the unit card says PINNED /
  REPAIRING +5/s.
- Merged main dcf7c3968 (CP37.1, rules R1-R3 OFF) as 6eed1f86a: `FeedbackReader.slowed()` already calls
  `Tank.pin_slow()`, so the pinned look reads R3 as soon as `RuleSwitches.pin_slow_on`; no code change needed.
- Re-judged alone on builder0 (merge 6eed1f86a / a8690b304): perf-judge PASS 1.01x; control-timing 5/0 + 8/0 (the
  4/1 in a first run was contention); ai-scenarios-check gate held 53,0 but NOT JUDGED again because
  `scenario_scout_suppress::test_target_behind` UNEXPECTEDLY PASSES (pending 5 -> 4). That scenario is not mine
  (feedback is presentation only, sim-baseline unmoved); likely main's rules/cover work. Flagged to the orchestrator.
- **Cost (perf-scene, builder0, llvmpipe software GL, CPU v CPU 30-a-side spectated so every unit is shown, FxWorld
  `fx_steps_ms.feedback`, the "all" phase, n = 10 and 8-10 phases per run):** a8690b304 read every unit every frame:
  every look off 0.15-0.27 ms, every look of every slot on 0.33-0.57 ms. 5ce6f87fc reads at 10 Hz (REREAD_S): off
  0.08-0.16 ms, all on 0.09-0.20 ms (whole FX 0.9-1.6 ms). Both runs hit perf-scene's 600 s timeout under llvmpipe
  (exit 2, no PERF_SCENE_DONE; 0 engine errors), so only the CPU-side step times mean anything here; frame times don't.
- No picks in the page db yet (`picks`, `sounds` empty at last read). F2-F4 final and any ElevenLabs request wait
  on the orchestrator's confirmation.

**2026-10-21 report (F1 in progress).**
- Built (a459ed338 + follow-ups): `FeedbackReader` (pure reads), `FeedbackLook` (`--feedback-look=hit:b,pinned:a+c,...`,
  three looks per slot, default = my recommendation), `FeedbackFx` (world half, pooled), UnitBars' screen half,
  `make feedback-shots` (stages each slot on its own open patch of a real skirmish, armies held still and silent, stills
  at his pose + close in + 2 s clips) and `make feedback-page`. quick-remote builder0 at the a459ed338 tree: 203 passed,
  0 failed. Sim untouched (reads only).
- Capture lessons: a live battle drove through the first capture (armies are now held by zeroing their commands at
  physics priority -5); vehicles must not be freed mid-match (SelectionMarkers/MotionFx assert), so each slot gets its
  own site; staged crews on a scoring ring take it (sites avoid objectives); the RTS rig keeps tracking the army unless
  `stop_tracking()`; shields hide hull-hit flares (targets are gang vehicles, no shields).
- Incident: I killed rules' laptop `make lint` (pid 3152953) by mistake; told rules and the orchestrator.

**2026-10-21, started.** Launch check: main 9d325e291 inherits round 36's green (HANDOFF); not re-run.

**Plan (smallest foundation first):**
1. `FeedbackReader` (pure, `game/theme/fx/feedback_reader.gd`): reads, never writes, the four facts per frame: a hit's
   face (front / side / rear / engine deck), a crew's pinned level (`Tank.suppression`; `pin_slow()` once R3 lands),
   who a Tanker is mending and how fast (the same conditions as `Match.repair_rate_for`), whether an Emitter's cone is
   blowing (its `weapon_fired` puffs). Tests first: `tests/test_feedback_reader.gd`.
2. `FeedbackLook` (`--feedback-look=hit:b,pinned:a,...`): which direction each slot draws; the default is my
   recommendation until his pick, then the losers are deleted.
3. `FeedbackFx` under FxWorld (world marks: one MultiMesh + one shader, pooled like OrderFeedback) + overlays in
   `UnitBars` (screen-space, crisp from his RTS camera). Fog respected: nothing drawn on a unit he can't see.
4. `feedback_showcase` (`make feedback-shots`, builder0 display): each slot x direction staged with a real Match,
   stills at his pose (21 deg, FOV 35, 49 m) and a close-up, on `--render-preset=laptop`, plus short clips.
5. The page (`tests/feedback/directions_page.py` -> build/feedback-page/): tap-to-pick per slot, db capability.

**Found while surveying (so nobody re-reads it):** weak-spot (engine deck) hits already flash gold and play
`weak_spot_hit` (WeaponFx `_weak_spot`); side and rear hits outside the 25 deg deck arc look exactly like front hits.
The announcer already tags `rear` / `weak_spot` on BIG hits and kills (`announcer_memory._on_damage`, lines
caller.hit.07-09, caller.kill.38-39); no `side`/flank tag exists. The Emitter already has its `sonic_loop` sound but
draws nothing (its fire_model is `stream`, kind CONE; Match emits a `weapon_fired` puff every 3 ticks while it blows).

