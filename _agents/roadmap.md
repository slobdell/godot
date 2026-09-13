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
- Not done (deliberately): firing, which is M3

## M2: Networked direct control (real-time stack, stage S0)
**Pre-read:** [server_management.md](server_management.md) §1–2, 5.
- [ ] `--server` flag / feature tag starts a `WebSocketMultiplayerPeer` server on a port; `--connect=ws://host:port` (or `?connect=` on web) joins
- [ ] Server spawns a tank per peer (`MultiplayerSpawner`); clients send `TankCommand` each tick; server applies via `NetworkInputController` (sanitized, rate-limited)
- [ ] State replicated with `MultiplayerSynchronizer`; clients interpolate
- [ ] `make server` target; disconnect removes the tank
- [ ] Tests: a headless **bot client** connects to a headless server, drives, and sees its tank move (no browser needed)
- **Acceptance:** `make server` + two `make serve-web` tabs → two tanks, each controlled by its own tab, smooth on localhost

## M3: Combat
- [ ] Fire → server spawns shell (projectile, not hitscan), collision, damage, death, respawn
- [ ] Armor facing (front/side/rear) so positioning matters; this is the seed of the equipment trade-offs
- [ ] Minimal HUD: health, reload
- **Acceptance:** two networked players can destroy each other; a client can't deal damage by lying

## M4: A squad that plays itself (single-player first)
**Pre-read:** [vision.md](vision.md) design space.
- [ ] 5 tanks per side; navmesh (`NavigationRegion3D`); perception (line of sight, detection radius)
- [ ] `SkillController` + first 3 skills: `hold_sector`, `guard_perimeter`, `bait`; squad blackboard
- [ ] Click-to-assign skills in a debug UI
- **Acceptance:** two AI squads with hand-assigned skills fight a full match with no human input, headless

## M5: Doctrine as data
- [ ] Doctrine JSON schema: loadout (with a points budget), role, skills + params, triggers
- [ ] Equipment trade-offs implemented (armor/speed/gun types)
- [ ] Server-side validation; form-based doctrine editor
- [ ] `make match A=doctrines/x.json B=doctrines/y.json`: headless, faster than real time, prints the result, which enables batch balance testing
- **Acceptance:** doctrine files alone determine a match; invalid doctrine is rejected with a clear reason

## M6: Deploy (stage S1)
- [ ] VPS + Caddy (HTTPS + `wss://` reverse proxy) + systemd unit for the server; `make deploy`
- **Acceptance:** the project lead and their son play at a public URL

## M7: LLM doctrine compiler (prototype)
- [ ] Natural language → doctrine JSON, constrained to the schema; an eval set of example orders with expected doctrines
- [ ] Provider interface: cloud model first (fast iteration), on-device later
- **Acceptance:** ≥ N of the eval prompts compile to valid doctrine that behaves as described

## M8: Android + Gemini Nano
**Pre-read:** [vision.md](vision.md) "Platform facts to re-verify". Extend [bootstrap.md](bootstrap.md) with the Android toolchain.
- [ ] Android export (Makefile: `bootstrap-android`, `export-android`)
- [ ] Godot Android plugin bridging to on-device Gemini Nano; capability detection + fallback
- **Acceptance:** on a supported phone, spoken/typed orders compile to doctrine on-device

## M9: Players persist (stage S3)
- [ ] Accounts, saved doctrines, match history, matchmaking; evaluate Nakama first

## Open ordering decisions
- **M2 before M4?** Current plan: yes. Retrofitting server authority onto finished AI is painful, and the lead explicitly wants to understand hosting. Counter-argument: M4 is the heart of the vision and doesn't need networking. Revisit after M3.
- **Async vs live matches** ([vision.md](vision.md) Q1) decides how much of S2+ we ever build.
