# Workstreams: Working in Parallel

> Parallel agents, each on an independent problem, in git worktrees. Round 1 ran 2026-09-14 (gameplay, look &
> feel, assets, netcode, garage; archived in `streams/archive/round1/`). **Round 2 was planned 2026-09-15.**
> Read [game_design.md](game_design.md), this file, then your brief in `streams/`.

## Round 2 streams

| Stream | Brief | Outcome |
|---|---|---|
| **rules** | [streams/rules.md](streams/rules.md) | Fixed unit roster v2 replaces loadouts; counters from mechanics; friendly fire; ≤ 5 squads; arena layouts as data; matchup matrix |
| **ai** | [streams/ai.md](streams/ai.md) | Sophisticated unit and squad AI: cover and peeking, matchup targeting, friendly-fire-aware firing, squad tactics, AI ELO ladder |
| **command** | [streams/command.md](streams/command.md) | Tap-only commanding, squad bar, formation/drill icons, camera that follows orders, readability at play distance |
| **art** | [streams/art.md](streams/art.md) | Meshy roster and arena art behind lead review gates; textured ground; lighting; stands with crowds; vehicle readability |
| **army** | [streams/army.md](streams/army.md) | Army builder on catalog v2, credits and unlocks, budget tiers, the full match loop |

**Paused: netcode** (relay, lobby, replays, and the lockstep spike all work; see
[streams/archive/round1/netcode.md](streams/archive/round1/netcode.md)). No stream owns its paths this round; a stream that breaks a
netcode smoke test fixes it minimally and says so in its merge notes.

**Why this split** (2026-09-15): round 1's gameplay stream carried rules, AI, UI, and camera at once. The lead's
round-2 asks are deep in each (a "really sophisticated" AI, a new unit model, a mobile command UX), so each
gets its own agent. Art and assets merge because generation is gated on the lead's reviews: one agent
alternates gated generation with ungated lighting, ground, and crowd work. The garage becomes **army**, since
loadouts are gone and progression is new.

**Dependency order:** rules' **R1 (catalog v2 + army JSON v2)** is the foundation for ai (roles and weapon mounts),
army (what can be bought), and art (which units need models). **Checkpoint 1:** when R1 lands on `stream/rules`,
the orchestrator merges it to `main` and the other streams `git merge main`. Until then they build against
the contracts below (stubs in their own paths).

## Product constraints every stream designs for (the lead)

1. **Mobile first:** every action by single tap, drag, pinch, or on-screen button; no right-click, hover, or
   keyboard required. Tap targets ≥ ~48 px at 1080p. Test with `InputEventScreenTouch`/`ScreenDrag`.
2. **The vibe:** over-the-top converted vehicles in a night gladiator arena. Mad Max × Death Race × Blade Runner,
   photoreal and grimy, neon behind grilles, never cartoon. Source of truth: [art_direction.md](art_direction.md).
3. **Die-hard, no pay-to-win:** nothing that sells power or shortcuts; progression is earned ([vision.md](vision.md)).
4. **Web and phones:** Compatibility renderer, 60 fps on a mid-range phone, one simulation that runs headless.

## Lead gates (the only items that block on the lead)

1. **Meshy concept review (art):** before any image-to-3D request, the art stream prepares the concept images as a
   review sheet (`make art-review` → `build/review/index.html` + the PNGs), lists them under **Waiting on the
   lead** in its Status, and moves on to ungated work. Only approved images (recorded in the brief with the lead's
   words) go to 3D. Record credits spent per request.
2. **Design changes to game_design.md pillars** (any stream): propose with evidence; the lead decides.
3. Anything that spends money, creates accounts, or is destructive outside your worktree.

## Autonomous mandate: how a stream agent works without the lead

The lead's kickoff is short on purpose (the `/goal` prompt in `HANDOFF.md`); everything else is in the docs. It means:

1. **Orient:** read `CLAUDE.md` → `HANDOFF.md` → `_agents/orientation.md` → [game_design.md](game_design.md) → this file → your brief. Run `make check` to confirm a green start.
2. **Plan:** turn your brief's directives into an ordered list in its **Status** section (smallest foundation first). Brief directives are the lead's intent. Where they leave a choice open, make the call a good game designer/engineer would, and record it with a one-line reason.
3. **Loop per directive:** build → automated test (a regression test that fails without the change) → `make check` → **smoke test like a player** (launch it, take screenshots at desktop *and* phone aspect, and look at them; drive it through the agent bridge or scripted input; for gameplay, run `tools/match_series.py`) → fix what felt wrong → commit to your branch with a message saying what and why.
4. **Keep going** to the next directive without waiting. Update your brief's Status after each one (done, measured result, decisions, known issues).
5. **Stop and ask the lead only** at a **lead gate** (below), for a contract change that another stream must accept, for spending money or creating accounts, for anything destructive outside your worktree, or when a directive is impossible or self-contradictory as written. Otherwise, decide, document, and continue.
6. **Done** = every directive in the current set meets its acceptance notes, `make check` + `make web-smoke` pass, screenshots were reviewed, the brief's Status is current, and the branch is ready to merge (rebased on `main`). Then write a short merge note: what changed, what to playtest, decisions made, and open questions for the lead.

## Unattended runs (overnight): extra rules when the lead is away

Streams run with the lead mostly away (round 1 ran overnight). **Assume nobody answers questions for hours.** On top of the mandate above:

1. **Never wait for an answer.** Everything the mandate says to "ask the lead" becomes: write it
   under **Questions for the lead** in your brief's Status, take the most *reversible* reasonable
   option (or skip that item), and keep working on the next one.
2. **Need something from another stream?** Don't edit their paths. Build a small adapter or stub
   inside your own paths, write the request under **Requests to other streams** in your Status, and
   continue. The integrator reconciles in the morning.
3. **Merge `main` into your branch only when the orchestrator announces a checkpoint** (e.g. rules' catalog v2); otherwise `main` doesn't move under you. Commit
   to `stream/<name>` after every green step. You may `git push -u origin stream/<name>` as a backup.
   Never push `main`, never force-push, never touch another worktree.
4. **The machine is shared and small** (8 cores, 7.6 GB RAM, ~8 GB free disk on 2026-09-15):
   - Heavy runs queue through `tools/slot.sh` automatically via `make` (orientation trip-up #37). Wrap any Godot/Chrome/match-series run you start outside make.
   - At most **one** long-running background process of yours at a time (a server, an agent client). Stop it by PID when done; never `pkill -f` a pattern (trip-up #19). Never kill processes you didn't start.
   - Disk: check `df -h .` before downloading. Keep each stream's downloads under **500 MB**. No local ML models or large Docker images. Delete stale `build/` outputs you created.
5. **No new money, accounts, or secrets.** The only paid service in use is Meshy (the lead's key, `MESHY_API_KEY`), and only through the art stream's lead gate. Never commit keys.
6. **Time-box.** If one item fights you for ~90 minutes without progress, write down what you learned and what you'd try next, then move on.
7. **The backlog is deliberately longer than one night.** Finishing an item isn't a reason to stop; take the next one, then the stretch items. Stop only when the backlog is done or you're truly blocked on everything left.
8. **Shared files** (`project.godot`, `game/main.gd`, `main.tscn`, `game/modes/game_mode.gd`, root `Makefile`, `mk/core.mk`): additive, minimal edits only, listed in your merge notes. Prefer adding UI and nodes from code in your own paths over editing shared scenes.
9. **Leave a morning report.** Keep your brief's **Status** current as you go (a crash mustn't lose it). It needs: done (with measurements), decisions + reasons, questions for the lead, requests to other streams, known issues, what to playtest (exact `make` commands), and the next steps.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same*
repository, each on its own branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=rules OFFSET=1       # → ../godot-rules on branch stream/rules
make worktree STREAM=ai OFFSET=2
make worktree STREAM=command OFFSET=3
make worktree STREAM=art OFFSET=4
make worktree STREAM=army OFFSET=5
make worktrees                            # status of all of them
```

What `tools/worktree.sh` isolates (verified 2026-09-14: two worktrees ran `net-smoke` + `combat-smoke`
at the same moment, both passed, on ports 9261 and 9271):

| Shared resource | Collision risk | Isolation |
|---|---|---|
| Files and branch | agents overwrite each other | separate folder + `stream/<name>` branch |
| Network ports (servers, smoke tests, agent bridge) | two `make check`s fight over 9181/8061/8765 | `local.mk`: every port + `10 × OFFSET` |
| CPU (match series) | 5 agents × parallel matches thrash | `local.mk`: `JOBS := 2` |
| Godot `user://` (saves, logs) | garage saves / logs collide | `override.cfg`: `tank_squad_<stream>` user dir |
| `.godot/` import cache | a stale cache for another branch | per worktree (not shared) |
| `.tools/` Godot toolchain (300 MB) | none (read-only use) | shared by symlink |

## Running the agents

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude`, then the `/goal` prompt from `HANDOFF.md` (the same text for every stream; the agent reads its stream from its folder).
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** (a Claude session in the main checkout, or the lead) reviews and integrates:
   ```bash
   make worktrees                                   # who's dirty, who's ahead of main
   git log --oneline main..stream/rules          # what a stream did
   git diff main...stream/rules --stat           # what it touched: stay inside owned paths?
   (cd ../godot-rules && git merge main && make check)   # rebased branch must be green
   git merge --no-ff stream/rules                    # in the main checkout
   make check && git push
   ```
4. **After every merge, tell the other streams to `git merge main`** so conflicts surface early and small. (Prefer merge over rebase once a branch is pushed.)
5. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree; the orchestrator's checkout owns `main`.
- `git stash`, hooks, and `git config` are **shared** across worktrees: a stash made in one shows up in all. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).

## Who owns what (round 2)

Owning a path means you may change it freely. Anything else, change only through the
stream that owns it, or through a contract change (below).

| Path | Owner |
|---|---|
| `game/units/` (catalog v2, army validation), `game/ai/doctrine.gd` (the army/doctrine JSON parser) | rules |
| `game/combat/` except `impact.gd` (weapons, armor, ballistics, shells, arc rounds) | rules |
| `game/match/` (rules, spawning, damage, friendly fire, intel, visibility field, announcer, control point) | rules |
| `game/tank/` (the vehicle simulation; rename to units is rules' call), `game/arena/` + `arenas/` (new: layout data) | rules |
| `doctrines/`, `tools/match_series.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | rules |
| `game/ai/` except `doctrine.gd` (brains, orders, squads, formations geometry, directives, perception, pathing, CPU commander, new tactical-position code), `game/agent/`, `tools/agent.py` | ai |
| `_agents/tank_brain.md`, `_agents/squad_ai_design.md`, `_agents/unit_ai.md` (new) | ai |
| `game/ui/` except `widgets/**` and `hud.tscn` (tactical map, radar, `hud.gd` text, new squad bar and icons), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `_agents/tactical_map.md` | command |
| `game/theme/**` (themes, fx, audio, galleries), `game/ui/widgets/**`, `game/ui/hud.tscn`, `game/combat/impact.gd`, `assets/**`, `tools/assets/`, `mk/assets.mk`, `mk/fx.mk`, `_agents/art_direction.md`, `_agents/streams/references/{fx_tricks,asset_*}.md` | art |
| `game/garage/` (the army builder; keep the path), `game/progression/` (new), `game/modes/garage_mode.gd`, new flow/results modes and screens, `mk/garage.mk` | army |
| `game/network/`, `server/`, `game/modes/{server,client,host,lobby,det_spike}_mode.gd`, `tools/serve_web.py`, `tests/net/`, `mk/net.mk` | **paused** (netcode): minimal compatibility fixes only |
| `_agents/slot_contracts.md` | rules + art together (contract) |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `HANDOFF.md` | orchestrator (streams propose edits in their Status) |
| **Shared:** `project.godot`, `export_presets.cfg`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `CLAUDE.md` | nobody alone: keep edits minimal and mention them in your merge notes |

Tests live beside their owner's code in `tests/`; name them for the area (`test_units_*.gd`, `test_ai_*.gd`,
`test_command_*.gd`, `test_art_*.gd`/`test_fx_*.gd`, `test_army_*.gd`) so ownership is obvious.

## Contracts between streams (round 2)

Changing one requires updating this section, and the owning stream announcing it in its Status.

| Contract | Owner, where | Consumers |
|---|---|---|
| **C1 Unit catalog v2** (replaces v1 loadouts). `Units.PROFILES[id]` = `display_name`, `role` (`scout`/`tank`/`ifv`/`artillery`/`lancer`, extensible), `blurb`, `cost`, `unlock_tier` (0 = starter), `hull_size` [w, h, l], `max_health`, `max_shield`, `shield_recharge_delay`, `shield_recharge_rate`, `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`, `sight_radius`, `weapon` (a `Weapons.PROFILES` id), `mount` (`turret` or `fixed`), `turret_turn_rate_deg` (turret mounts), `fire_arc_deg` (fixed mounts), `muzzle_height`, optional `heat_capacity`/`heat_dissipation`, `good_vs`/`weak_vs` (role lists: design intent for AI hints and the army UI; mechanics decide real outcomes). Weapons gain `penetration` and `splash_radius`. No components, no hardpoints. Optional `faction` (default `condemned`; added 2026-09-15 for future factions, rules adds it after checkpoint 1). | rules: `game/units/units.gd`, `game/combat/weapons.gd` | ai, army, art, command (unit cards, icons) |
| **C2 Army JSON v2** (doctrine files, garage saves): `{"name", "squads": [{"name", "formation"?, "directive"?, "units": [{"unit": id, "paint"?: "#rrggbb", "directive"?}]}]}`; ≤ 5 squads, ≤ 5 units per squad; cost ≤ the match budget. Rules migrates `doctrines/` and rejects v1 loadout keys with a clear error. | rules: `game/ai/doctrine.gd`, `game/units/` | army (produces), skirmish/match runner (load), ai (squads) |
| **C3 Match result for progression:** `Match.finished(result)` includes `winner`, `reason`, per-team `units_lost`/`units_left`, kills by unit type, `duration_seconds`, `budget`. | rules: `game/match/match.gd` | army (credits), command (results display) |
| **C4 Combat queries for AI:** (all new) `Match.friendlies_in_line_of_fire(shooter: Tank, aim_point: Vector3) -> Array` (direct fire, and splash for arcs), `Arena.cover_features() -> Array` of `{position, size, rotation, height, type}`, `Tank` exposes `mount`, `fire_arc_deg`, `turret_turn_rate`, `muzzle_height`. | rules | ai |
| **C5 Arena layouts:** `arenas/<name>.json` = `{name, half_size, obstacles: [{type, position [x, z], rotation_deg, size?}], spawns: {green: [...], rust: [...]}, control_point?}`, validated point-symmetric; `--arena=<name>`. Obstacle `type` maps to visual slot `prop.<type>`; `arena.dressing` gets `setup(layout)` so stands and crowds fit the arena. | rules (data, collision, nav) | art (props, dressing), ai (cover), command (radar outline) |
| **C6 Visual slots**, including per-unit ids `unit.<id>.hull/turret/weapon` (fall back to `tank.*`/`weapon.*`), `set_team_color` = team accent, `set_paint` = cosmetic, `set_shield`, `set_heat`, `set_firing`, `setup` | rules + art: [slot_contracts.md](slot_contracts.md), `game/theme/game_theme.gd` | art fills; rules places |
| **C7 Command API:** `SquadCommand` `{squad, verb, to, facing, formation, commander}` (unchanged); `Formations.offsets(formation, count)` (exists) for icons (ai keeps it stable); `TacticalMap.command_issued` (exists) plus a new selection signal `squad_selected(squad_key)`; camera: `RtsCamera.follow(target)` / `focus_on(point)` (exist) plus a new `frame(points: Array)` | command (UI and camera), ai (squad and formations) | ai, army (squad names), agent bridge |
| **C8 Progression profile:** `user://profile.json` = `{schema, credits, unlocked_units [ids], budget_tier, wins, losses}`; `Progression.BUDGET_TIERS` = `[{tier, budget, unlock_credits}]`; `Progression.award(result) -> credits` | army: `game/progression/` | command (results screen shows credits), skirmish (budget) |
| **HUD messages:** `Hud.post_message(text, severity)` → cyber banners | command posts; art renders | everyone |
| **Visibility / radar data:** `VisibilityField`, `Match.is_visible_to`, `Match.intel`, `Radar.blips()`, `GameTheme.ui["radar_frame"]`, slot `fx.fog_of_war` (defined in round 1) | rules (field), command (radar) | art (skin) |
| **Launch flags and console markers** (`TANK_SQUAD_*`, `MATCH_RESULT`, `GARAGE_FIGHT`, …) | each mode's owner; list in `game/main.gd` header | smoke tests, match_series.py |

## Invariants every stream must keep

1. `make check` passes before merging (lint, tests, network + relay + lobby smoke, combat, match, determinism, sim baseline, garage smoke). Netcode is paused, not abandoned: keep its smokes green.
2. **Art never changes the simulation.** `make sim-baseline` (part of `make check`) replays a seeded match and compares its `state_hash` to `tests/baselines/sim_state_hash.txt` (`e5cf33921713b657` on 2026-09-15). Only **rules** and **ai** change it, on purpose, updating the file in the same commit and saying why; command, art, and army must leave it unchanged.
3. The web build still boots (`make web-smoke`) and the dedicated server still exports (`make export-server`). Visual slots must load on a headless server.
4. Fairness: any change to the arena, spawns, or navigation re-runs the swap-bases control (verification.md).
5. Docs move with code: update your stream brief's **Status** section and any stale `_agents/` doc in the same merge.
6. **Design follows [game_design.md](game_design.md).** If your work shows a design rule is wrong, record the evidence and propose the change in your Status; do not silently diverge.
7. **Keep new simulation code portable** (rules and ai): follow the guidelines in [determinism.md](determinism.md) (pure classes, simple geometry we own, one seam per engine query, vector math instead of trig) and add any new engine dependency to its inventory. Today's simulation is deterministic within one build only; lockstep for ranked play needs it identical across builds, so every engine-math feature is future porting work.
