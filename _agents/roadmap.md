# Roadmap

Each milestone leaves a playable, tested game. Tick the boxes as they land and
keep "Acceptance" honest: it's what `verification.md` checks are run against.

## ✅ M0: Scaffold (2026-09-12)
- [x] `make bootstrap` installs pinned Godot 4.7.2 + trimmed templates into `.tools/`
- [x] Git repo, `.gitignore`, `_agents/` docs, `HANDOFF.md`, `CLAUDE.md`
- [x] Headless test runner (`make test`), desktop screenshot (`make screenshot`)
- [x] Web export + local server + headless-Chrome smoke test (`make web-smoke`)
- [x] Linux dedicated-server export that boots (`make export-server`)

## ✅ M1: One tank, direct control (2026-09-12)
- [x] Hull drives/turns (WASD/arrows); turret tracks the mouse on the ground plane
- [x] `TankCommand` seam; `PlayerController` + `ScriptedController`
- [x] Arena with grid ground, crates, sky, shadows; follow camera
- [x] Tests: motion math, command sanitizing, real-physics drive/turn/turret

## ✅ M2: Networked direct control, stage S0 (2026-09-12)
- [x] `--server[=port]` hosts a `WebSocketMultiplayerPeer` (exported server binary defaults to it); `--connect[=url]` / `?connect` joins
- [x] Server spawns a tank per peer via `MultiplayerSpawner` + spawn function; despawns on disconnect
- [x] Clients send `TankCommand` by RPC; server-side `NetworkInput` checks the sender, rejects non-finite values, clamps, rate-limits, and stops stale input
- [x] State replicated by `MultiplayerSynchronizer` at 30 Hz; clients smooth toward it; other players' tanks painted rust
- [x] `server_relay` off (clients can't message each other); headless processes capped to 60 fps
- [x] `make server`, `make client`, `make net-smoke` (headless server + 2 bot clients over real sockets), `make web-net-smoke` (browser client + bot)
- [x] Tests: 6 server-validation unit tests; net-smoke proves spawn, replication of others, and server-simulated movement
- **Known gaps, deliberately deferred:**
  - Clients *smooth* toward the latest snapshot (exponential), which isn't true buffered snapshot interpolation. Fine on LAN; revisit if remote play looks jittery.
  - No client-side prediction: your own tank responds ~1–2 snapshots late. Acceptable for tanks; direct control is not the end game.
  - No join authentication (anyone who can reach the port can join), no teams, no reconnect.
  - Browsers on an `https://` page require `wss://`, which is solved at M6 by the reverse proxy.

## M3: Combat (built to be read by AI later)
**Pre-read:** [squad_ai_design.md](squad_ai_design.md), "Consequences for the roadmap".
- [ ] Fire → server spawns a shell (projectile, not hitscan), collision, damage, death, respawn. Firing is a *reliable* event, not the unreliable per-tick command stream
- [ ] **Armor facing** (front/side/rear multipliers) so positioning matters
- [ ] **Line-of-sight query** and taller cover obstacles, the first "sense" primitives AI will reuse
- [ ] Two teams with colors; minimal HUD: health, reload
- **Acceptance:** two networked players can destroy each other; flanking visibly beats frontal fire; a client can't deal damage by lying

## M4: One smart tank + the match runner
- [ ] **Headless match runner** (`make match …`): runs a match to completion faster than real time, prints a JSON result. Pulled forward from M5 because every AI experiment needs it
- [ ] Navmesh (`NavigationRegion3D`), perception (LOS + detection radius), blackboard
- [ ] `UtilityController`: actions `advance_to`, `engage`, `take_cover`, `retreat_to`, `hold`; directive weights; commitment bonus
- [ ] In-game score overlay (top 3 actions per tank)
- **Acceptance:** experiment **E1** passes ([squad_ai_design.md](squad_ai_design.md))

## M5: Squads, doctrine as data, and "does skill exist?"
- [ ] 5 tanks per side; squad blackboard; phases (conditions that swap directive sets)
- [ ] Doctrine JSON schema: loadout (points budget), per-tank directives + phases; server-side validation
- [ ] Equipment trade-offs (armor / speed / gun types)
- [ ] Experiments **E2** (knob sensitivity) and **E3** (skill existence) run and logged
- **Acceptance:** E3 passes, i.e. authored doctrines beat random and no doctrine dominates

## M6: Deploy (stage S1)
- [ ] VPS + Caddy (HTTPS + `wss://` reverse proxy) + systemd unit for the server; `make deploy`
- **Acceptance:** the project lead and their son play at a public URL

## M7: Live commanding + LLM doctrine compiler (prototype)
- [ ] Command-point system (experiment **E4**)
- [ ] Natural language → doctrine JSON, constrained to the schema; eval set of example orders
- [ ] Provider interface: cloud model first, on-device later
- **Acceptance:** E4 passes; ≥ N eval prompts compile to valid doctrine that behaves as described

## M8: Android + Gemini Nano
**Pre-read:** [vision.md](vision.md) "Platform facts to re-verify". Extend [bootstrap.md](bootstrap.md) with the Android toolchain.
- [ ] Android export (Makefile: `bootstrap-android`, `export-android`)
- [ ] Godot Android plugin bridging to on-device Gemini Nano; capability detection + fallback
- **Acceptance:** on a supported phone, typed orders compile to doctrine on-device

## M9: Players persist (stage S3)
- [ ] Accounts, saved doctrines, match history, matchmaking or asynchronous ladder; evaluate Nakama first

## Open ordering decisions
- ~~M2 before M4?~~ Decided 2026-09-12: yes; M2 done.
- **Async vs live matches** ([vision.md](vision.md) Q1) decides how much of S2+ we ever build. E3/E4 results should inform it.
