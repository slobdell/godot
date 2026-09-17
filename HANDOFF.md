# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-16. **Round 4 is merged, verified and closed. Round 5 isn't planned yet: it starts from the
lead's playtest.**_

## Current state (main)

- **Verified:** `make remote T=check` green on builder0 (843 tests, every smoke, the announcer's Python tests, the
  variance gate, music smoke). Sim baseline `glibc-2.43 7b1bb7c20063e5a0` (builder0 canonical;
  `make remote T=sim-baseline-record`).
- **The game today:** StarCraft-style control with a camera that only shows what your force can see; elements that pick
  formations and run battle drills from real doctrine, the same library for you and the CPU; suppression that makes
  base-of-fire-and-maneuver real; four playable factions with their own rosters and doctrine (44 gang vehicles to 17
  Syndicate at the same budget); tank shells you can watch fly; a voiced announcer trio calling the match by faction;
  layered sound and a music director.
- **Builds run on builder0:** `make remote T=check`, about 7 minutes ([remote_builds.md](_agents/remote_builds.md)).
  One remote run per worktree at a time.

## Round 5: six streams (planned 2026-09-17)

Goal: **make it playable.** The lead played round 4 and stopped at the frame rate, a camera that frames the enemy, a
title screen that won't click, one flat map, vehicles that read as blue lights, and two masses trading fire
([game_design.md](_agents/game_design.md) *Round 5 direction*). Faction art ships; the garage stays paused.

| Stream | Brief | Outcome |
|---|---|---|
| render | [streams/render.md](_agents/streams/render.md) | 60 fps at 30 a side: the shader-uniform wall, far fewer lights for a more grounded look, detail levels, vehicles that read as vehicles, faction art shipped (**M1 = CP1**) |
| arena | [streams/arena.md](_agents/streams/arena.md) | Maps as a discipline: layout schema v2 with the arena kit, four arenas with real tactical shape, fairness-validated and measured (**M2 = CP2**) |
| control | [streams/control.md](_agents/streams/control.md) | Play it and fix what stops you: camera frames your force, the title screen works, a clean console, subtitles on their own line, the three dials |
| combat | [streams/combat.md](_agents/streams/combat.md) | Ranges and cover that force maneuver instead of two masses; the gangs' 23%; the duplicated Lancer |
| ai | [streams/ai.md](_agents/streams/ai.md) | 4 ms at 60 units, the gates blocking SUPPRESS and cover-pulling, the tactics ladder, faction behaviour (inherits doctrine) |
| audio | [streams/audio.md](_agents/streams/audio.md) | Guns that sound dangerous (ElevenLabs), impacts, colour names out of the booth, music stems |

Ownership, contracts (M1–M3, L1–L5, K1–K5, C1–C8), checkpoints and gates: [`_agents/workstreams.md`](_agents/workstreams.md).

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all six:

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**Orchestrator duties:** merge CP1 (render's frame budget) and CP2 (arena's layout schema) as soon as they're
announced and tell everyone to `git merge main`; relay anything waiting on the lead the same day; rescue git-ignored
payload from worktrees before removing them ([backups.md](_agents/backups.md)); final integration order arena → combat
→ ai → render → control → audio.

## Round 4: closed 2026-09-16

## Round 4: closed 2026-09-16

All five streams (control, doctrine, combat, ai, audio) are merged and green: **843 tests**, every smoke, sim baseline
`glibc-2.43 d4bd86eee0f96c54`. Briefs and their reports: `_agents/streams/archive/round4/`. Round 5 isn't planned yet.

**Play it:** `make skirmish` (faction menu, then the vision-framed camera and task commands: E screens, R base of
fire), `make skirmish-factions FACTION=gangs ENEMY_FACTION=syndicate` (44 vs 17 vehicles), `make cinematic` (a camera
that finds the fighting on its own), `make doctrine-page`, `make announcer-demo`, `make tactics-parity`,
`make faction-matrix`.

**Three dials control left for the lead** (none blocking, all in archive/round4/control.md): how close the default
frame should sit, one alert line or three, and whether the faction menu should open by default.

## Waiting on the lead

1. **Playtest round 4** and say what's fun and what isn't: that's round 5's direction.
2. **Git LFS, eventually.** Not urgent for safety any more (see backups below), but `.git` is 353 MB and grows with
   every regeneration. The rule to adopt when it starts to hurt: generated binaries that *ship* (voice clips, faction
   models) go in LFS; generated *sources* stay out of git and live in backups. GitHub's free tier is 1 GB storage and
   1 GB/month bandwidth; a data pack is about $5/month per 50 GB (confirm on the billing page).
3. **Meshy credits: 88 left** (round 3 spent 600). Any new art needs a top-up. ElevenLabs has 125,297 left.
4. **Faction art is excluded from the exports** (47 MB): the three new rosters *play* as themselves but *look* like the
   Condemned. Wiring it up takes the web pack from 0.8 MB to ~48 MB.
5. **The Lancer sits in two factions** (Condemned `lancer`, Syndicate `syn_lancer`): the role is shared, the vehicle
   isn't. One of them may want to lose it.
6. **Control's three dials** (frame distance, alert lines, faction menu on by default) and **doctrine's page**: worth
   growing into a "why did my element do that" view, or throwaway?
7. **Carried over:** rotate the Meshy API key; the round-2 questions in `streams/archive/round2/`.

## Open questions and follow-ups (not scheduled)

- **Backups are automatic now** ([backups.md](_agents/backups.md)): a systemd user timer rsyncs the git-ignored
  generated assets (Meshy downloads, announcer masters, Suno tracks later) to `builder0:~/tank_squad_backup/` every 30
  minutes, never deleting. `make backup`, `make backup-status`. The cache drive holds a dated snapshot for Google Drive.
  **A worktree's ignored payload is still only in one place until it's copied into the main checkout.**

- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%, averaged over 5 seeds). Combat fixed two real
  defects behind it and neither moved the number, then stopped rather than inflate stats the moment drills and
  suppression landed. Re-run `make faction-matrix SEEDS=5 TIME=150` on today's `main` before tuning anything.
- **ai's own follow-ups:** the 4 ms-at-60-units target isn't met (5.4–6.2 ms); SUPPRESS can't be reached in a duel
  because of a gate, not a weight; a pinned enemy doesn't actually pull a unit out of cover. All with evidence in
  archive/round4/ai.md.
- **Doctrine's request:** an optional `facing` in `UnitCommand` (control's file), to remove the halt-formation hack.
- **Unfinished by design:** ElevenLabs sound effects layered under the synthesised transients (credits available),
  music stems that build with intensity, and the offline tactics-discovery harness (ai's X4–X6).

- **The renderer runs out of per-instance shader uniforms at ~30 a side** (found independently by combat and control,
  2026-09-16). A full-scale battle logs hundreds of `Too many instances using shader instance variables … Maximum items
  supported by this hardware is: 4096`, then `instance_buffer_pos.has(p_instance)` failures. Raising
  `rendering/limits/global_shader_variables/buffer_size` won't help: 4096 is the hardware cap. The fix is fewer
  per-instance uniforms in the vehicle materials — bake per-unit colour into vertex colours, or share a material per
  team instead of per instance. Users: `game/theme/cyberpunk/{unit_skin,weapon_cannon,dozer_part}.gd` and
  `game/theme/fx/shaders/{unit_body,vehicle_glow,shield}.gdshader`. **Nobody owned `game/theme/**` in round 4**, so this
  is unassigned and blocks the "30 a side" goal from looking right. `make control-scale-shots` counts and attributes
  the errors rather than swallowing them.

- **Factions as gameplay.** The art exists (15 vehicles in `game/theme/factions/`, gallery-only, excluded from the web
  export). Playable factions need catalog entries, per-faction mechanics, and balance. The lead's picks settled the
  specials (game_design.md *Factions*); the Lancer now sits in both the Condemned and Syndicate rosters, which is a
  design question.
- **A scout's counter** (ai asked, ruled in game_design.md): scouts are spotters first; `good_vs` claims must be real
  in the mechanics. Combat still owes the `scout > lancer` claim a mechanic or its removal.
- **Unit-count bench:** frame time, draw calls, triangles, and simulation time at 25/50/100/200 vehicles.
- **Cross-build determinism** ([determinism.md](_agents/determinism.md) D1–D4), including glibc differences.
- **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), the Steam build, arena announcer audio, the
  paused netcode and army/progression streams.
- **Disk:** the laptop is at 95% (about 6 GB free). `assets/incoming/` alone is 968 MB of raw generated art.

## Starting the next round

The pattern, the kickoff prompt, and the checklists are in [`_agents/orchestration.md`](_agents/orchestration.md).
Round 4's streams get written into [`_agents/workstreams.md`](_agents/workstreams.md) and `_agents/streams/` when the
lead's playtest feedback lands.
