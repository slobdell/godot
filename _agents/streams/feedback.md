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

F1's picks (the orchestrator relays). **The directions page: https://claude.ai/artifact/FDSA2k9cBPFfncfo2rCSHn**
(private; published 2026-10-21 from build/feedback-page, shots builder0 `make feedback-shots FB_PRESET=laptop` on the
a459ed338 tree + capture fixes, Terminus, 1854x1011). Picks land in its db: `picks/<hit|pinned|repair|cone>` =
{letters, words, at}; sound and line approvals in `sounds/<flank_hit|rear_hit|repair_loop|caller.hit.flank.0N>` =
{approved, words, at}. My recommendations: hit a, pinned a, repair a, cone b. Lead gate 1: nothing generated with
ElevenLabs until a `sounds/*` approval. Until his pick no look draws without the flag.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-21, F1 page up, picks pending.**
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

