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

F1's picks (the orchestrator relays).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
