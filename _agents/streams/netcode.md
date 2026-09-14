# Stream: Netcode (production multiplayer without paying for compute)

> Read [../workstreams.md](../workstreams.md) first. You own `game/network/`,
> `game/modes/server_mode.gd`, `client_mode.gd`, `tools/serve_web.py`, `tests/net/`, `mk/net.mk`.

## The lead's idea (2026-09-13)

> "Making it so that our eventual deployed web servers just serve as match makers and message
> brokers, where we assign one of the players in the game to be the game host (this way, all of
> the computation happens on a remote phone or another player's remote device, not on our own
> server). I assume we can bypass cheating for the most part by making the API just take events
> in the world, and I'm thinking we can introduce arbitrary latency to the host's machine by adding
> comparable latency to any actions that matches the other player(s)."

## Analysis

**The cost goal is sound.** Having players host the game (a "listen server") is a proven model,
and our server would only do matchmaking plus relaying small messages. Squad commands and
~30 Hz snapshots of 10 tanks are a few kilobytes per second.

**But three parts need care:**

1. **Host cheating isn't solved by "the API takes events".** Whoever *simulates* decides
   what happened. A modified host can deal extra damage, ignore reloads, or read hidden enemy
   positions, and its events will look perfectly legitimate. Adding delay to the host's inputs
   evens out *reaction time*, but it does nothing for *integrity*.
2. **Phones are fragile hosts.** Mobile OSes suspend backgrounded apps and throttle background
   browser tabs; batteries and thermals throttle CPUs. A host leaving or stalling ends the match
   for everyone unless we build host migration.
3. **Connectivity:** browsers can't accept incoming connections. Peer-to-peer needs WebRTC with
   STUN, plus a TURN relay for many mobile networks. The simplest robust option is to relay
   everything through our WebSocket broker; bandwidth is cheap at our message sizes.

**A model that fits this game better: deterministic lockstep.** Every player's device runs the
simulation from the same stream of commands; each command executes at tick T+N for everyone
(the lead's "add comparable latency for everyone", formalized). The server only relays commands.
Players periodically exchange **state hashes**: if a cheater changes an outcome, their hash
diverges and the match flags them. Nobody has a host advantage; host leaving isn't fatal;
replays, spectators, and asynchronous matches come almost for free; bandwidth is tiny. RTS games
use this because their input is *commands*, and our input is squad commands, where a 100–200 ms
execution delay is invisible. (Remaining weakness: every client holds full state, so a
"map hack" can reveal fog of war.)

**The catch, which we measured on 2026-09-13:** lockstep needs *bit-identical* simulation on
every device. We ran the same seeded 40-second match three ways:

| Build | State hash after 2401 ticks |
|---|---|
| Native Linux x86-64, `--fixed-fps` (×2) | `e69acc63a64f319a` (identical) |
| Native Linux x86-64, real-time (×2) | `e69acc63a64f319a` (identical) |
| **WebAssembly in Chrome, same machine** | **`a0431b7a67fc25b7`: diverged** (different shots and damage) |

So our current simulation (Godot physics + NavigationServer, floating point) is deterministic on
one build, but **not across platforms**, even the same CPU through a different compiler. Phones
(ARM) will differ too. Lockstep would require a **custom deterministic simulation core**
(fixed-point math, our own 2D collision and line-of-sight, grid pathfinding, fixed iteration
order). Our architecture already isolates the simulation (Tank/Match/brains) from presentation,
and brains already think on ticks, so this is a contained rewrite, but a real one.

## Recommended plan

| Phase | What | Why |
|---|---|---|
| **N0: Broker** | A small service: lobbies/matchmaking + WebSocket relay (rooms); join tokens | Needed by every option; proves the cost model |
| **N1: Player-hosted, relayed** | One client runs `ServerMode` logic, talking through the relay; others are clients. Use for casual/friends matches | Ships multiplayer with zero game compute; cheating accepted for casual play |
| **N2: Deterministic-core spike** | Prototype fixed-point tank movement + shells + LOS for one arena; run the same command log on native, wasm, and an Android phone; compare hashes | Decides whether lockstep is achievable |
| **N3: Lockstep (if N2 passes)** | Commands scheduled at T+N via the broker; hash exchange every second; desync → flag the match | Cheat-resistant, cheapest, enables replays/async |

Open questions for the lead: is casual-first (N1) acceptable while N2 is explored? Ranked play
would wait for N3 (or run on authoritative servers for a small ranked pool).

## Verification you own

Dedicated server: `make net-smoke`, `make combat-smoke`, `make web-net-smoke`.
Broker and relay (built 2026-09-14): `make broker-test`, `make broker-smoke`, `make relay-smoke` and
`make lobby-smoke` (both in `make check`); `make relay-drop-smoke`, `relay-latency-smoke`,
`relay-rejoin-smoke`, `web-relay-smoke`, `web-host-smoke` (in `make check-all`).
Determinism and replays: `make det-spike` (native vs wasm hashes), `make replay`.
Measurements (not pass/fail): `make net-measure`, `make broker-load`. Rows 6e–8b in
[../verification.md](../verification.md) say what each proves.

## Status

- 2026-09-13: brief written; cross-platform determinism measured (diverges). Nothing started.
- 2026-09-14: overnight backlog added with an assumed decision (N0 → N1 casual relay while N2 spikes).

### Overnight run 2026-09-14 (netcode agent): morning report

**Plan (in order):** N0 broker → N1 relay peer (headless relay-smoke, then browser) → bandwidth/latency
measurements → N2 deterministic spike (native vs wasm) → N3 designs + a 10 s socket-drop test →
stretch (replay recorder, hosting costs, anti-cheat notes).

**Summary:** every backlog item and all three stretch items are done. Players can host matches
through a relay broker (browser or native, a touch lobby, reconnects, rejoin, replays); bandwidth
and latency are measured; the deterministic-core spike is **bit-identical native vs WebAssembly at
1.5% of a tick budget, so lockstep is feasible**; the N3 designs are written. `make check` is green
(115 tests) and **`make check-all` passed** (all relay stress smokes, browser boot/client/relay/host,
desktop screenshot, server export); screenshots reviewed: `web.png`, `web-net.png`, `web-relay.png`,
`web-host.png` (room badge), `host-badge.png`, `replay.png`, `lobby-desktop.png`, `lobby-phone.png`.

**Done**

1. **N0 broker** (`server/broker/`, Node 22 + `ws` 8.21.3 pinned). `make broker-bootstrap`,
   `make broker`, `make broker-test` (31 unit tests), `make broker-smoke` (real process: host + 2
   players, 600 frames up, 600 down, one socket cut and resumed with zero reliable-frame loss, host
   leaves → players told, `/stats` agrees). Protocol and decisions below under *N0 broker*.
2. **N1 player-hosted through the relay.** `game/network/relay_peer.gd` (`RelayPeer`, a
   `MultiplayerPeerExtension`): the existing spawner/synchronizer/RPC code runs unchanged with a
   player as host. `--host [--relay=URL]` (HostMode: ServerMode's rules plus the host's own tank;
   `--no-player` for a relayed dedicated host), `--join=CODE` (ClientMode). Browser: `?host`,
   `?join=CODE`, relay defaults to `/relay` on the page's origin (`tools/serve_web.py` proxies it).
   Checks, all green:
   - `make relay-smoke` (in `make check`): broker + headless host (own tank + 2 bots) + 2 headless
     clients by room code: each sees 5 tanks, moves 37 m, sees damage replicate.
   - `make relay-drop-smoke` (in `check-all`): one client's socket cut for **10 s**; it resumes the
     same seat after 10.1 s and keeps driving; the other client is unaffected.
   - `make web-relay-smoke` (check-all): a browser player joins a native host (screenshot
     `build/screenshots/web-relay.png`).
   - `make web-host-smoke` (check-all): **a browser hosts** (wasm simulation) and a headless client
     joins, drives 37 m, sees combat. The SwiftShader tab hosted at only 2 fps / 15 ticks per s
     (software rendering; `TANK_SQUAD_HOST_STATS`), which exposed the stale-input bug below.
   - GDScript unit tests: 10 in `tests/test_relay_peer.gd`, 4 new `test_network_input` cases
     (slow-host staleness, send-on-change policy); later `tests/test_det_core.gd` (7) and
     `tests/test_lobby.gd` (3).
3. **Bandwidth + latency measured** (`make net-measure TANKS= CLIENTS= LATENCY= JITTER=`; table
   under *Measurements* below). 10 tanks cost **14.6 KB/s down** per player, 20 tanks **27.3 KB/s**
   (~1.37 KB/s per tank, linear); the host uploads that times the player count (60 KB/s for 4
   players). Shield + heat as always-sent floats would add **+32%** (measured with stand-in
   properties, not committed). Player upload was 3.0 KB/s (a command every 60 Hz tick); **now
   1.5 KB/s** (send on change + keepalive). With 150 ms + 50 ms jitter on every peer
   (`make relay-latency-smoke`), play stays sane: time from spawn to replicated motion goes from
   ~300 ms to ~680 ms, snapshot gaps p95 50 → 67 ms (max 101 ms), combat replicates, no errors.
4. **N2 verdict: lockstep is feasible.** `game/network/detcore/` (Q16.16 ints, integer CORDIC
   trig, grid line of sight, arena walls, shells, turret brain; no floats). `make det-spike`: the
   same seeded command log (20 tanks, 3600 ticks = 2 min, 92 shots, 56 hits, 2 kills) gives
   **identical hashes at all 12 checkpoints natively and as WebAssembly in Chrome**
   (`ea02d9652cc08086`). Cost per tick: **284 µs native, 485 µs wasm = 1.5% of a 30 Hz budget**;
   even a 5× slower phone has >90% headroom. 7 unit tests incl. a recorded baseline hash.
   **Control experiment** (`FloatProbe`, printed by `make det-spike`): chaotic float recurrences
   using only + − × ÷ √ hash **identically** native vs wasm; adding sin/cos/atan2/exp gives
   **different** hashes. So today's cross-build divergence most likely comes from library trig
   (inside Godot's math, physics and navigation), not from floats as such. Integers remain the
   safe choice: a float core without libm could work on x86 and wasm, but ARM compilers may fuse
   multiply-adds (FMA) and nothing here has been measured on ARM. Not yet
   run on ARM (needs a phone; see Questions). Caveat: this proves the *approach*; the real game's
   brains, intel, squads and pathing would all need porting to integers (designs, section 1).
5. **N3 designs** in [references/netcode_designs.md](references/netcode_designs.md): lockstep
   protocol (T+D scheduling, adaptive delay, hash exchange, desync handling with majority resync
   or server replay adjudication, autopilot for dropped seats, snapshot catch-up), host loss for N1
   (end the match; migration not worth it), mobile backgrounding (10 s drop measured; gaps listed),
   anti-cheat notes for N1, broker hosting cost estimates.

**Decisions (with reasons)**

- Broker language: **Node + `ws`**. Node is already a project dependency (web smoke), `ws` is the
  most used WebSocket server, one dependency (212 KB), and it runs on every cheap host. Go would be
  leaner per connection but adds a toolchain for no gain at our message rates.
- **Star topology enforced by the broker**: players can only address the host (Godot's
  `server_relay = false`, enforced where a modified client can't skip it).
- **Reconnect without losing reliable packets**: every frame carries a per-direction sequence
  number; reliable frames are retained until acked; a resume retransmits what the other side
  hasn't seen. Unreliable frames (snapshots) are never buffered. Without this, one dropped socket
  loses a spawn/despawn RPC and Godot's replicated scene tree silently diverges.
- **A dropped socket is invisible to Godot**: `RelayPeer` stays `CONNECTED` and reconnects on its
  own (every 1 s, within the broker's 30 s grace). Unreliable packets sent while away are dropped.
  Clients also detect silent dead links (no traffic for 8 s → reconnect).
- **Player peer ids are proposed by the client** (like Godot's own peers) and kept by the broker
  unless taken, so `get_unique_id()` is valid before the join completes.
- **Stale-input rule changed** (`network_input.gd`): "the owner went quiet" is now measured from
  the host's last network read, not the physics tick's wall clock. Before, a host rendering slowly
  (2 fps tab; a hitching phone) judged every fresh command stale and players' tanks never moved.

**Stretch and extra items (done)**

6. **Replays** (`make replay`): (a) lockstep-style: the deterministic core's command log + checkpoint
   hashes saved and replayed with every hash verified; changing one command's turn by 1 is caught
   (diverged at tick 600). (b) For today's game: `--join=CODE --record=PATH` saves every packet the
   host sends that player; `--replay=PATH [--replay-speed=2]` rebuilds the match from that seat
   through Godot's own replication (headless playback matched the live run: 4 tanks, 36.8 m,
   damage). `make replay-watch REPLAY=path` opens one in a window (screenshot reviewed).
7. **Broker capacity** (`make broker-load`): 100 players replaying measured traffic use 22% of one
   core, 200 use 38%, ~14–20 KB per connection. Hosting costs and the anti-cheat notes are in
   [references/netcode_designs.md](references/netcode_designs.md) §4–5.
8. **Touch-first lobby** (`--lobby`, browser `?lobby`): HOST A MATCH, or tap a room code on an
   on-screen keypad (no virtual keyboard on phones) and JOIN; a wrong code comes back with "No room
   XXXXX". The host gets a big room-code badge with COPY INVITE LINK (`?join=CODE`). A test checks
   every target is ≥ 48 px and on screen at 5 desktop/phone sizes; `make lobby-smoke` (in `make
   check`) taps through it. Screenshots: `build/screenshots/lobby-desktop.png`, `lobby-phone.png`.
9. **Rejoin after the grace period** (the app was killed): the client rejoins automatically with a
   player key (per-tab `sessionStorage` in browsers) and the host restores its tank's team,
   place and health for 5 min (`make relay-rejoin-smoke`, check-all).
10. **Upload halved**: players send commands on change + 100 ms keepalive (3.0 → 1.5 KB/s).

**Decisions (continued)**

- **Browser player key per tab (`sessionStorage`), not per browser (`localStorage`):** several tabs
  in one browser must be different players (that's how `make play` is tested), and a phone that
  kills and restores a tab keeps its session storage.
- **Host loss in N1 ends the match** (with a HOST LEFT banner); host migration isn't worth it
  because lockstep removes the host (designs §2).
- **The lobby switches modes in place** instead of reloading the page with `?host`/`?join`: it works
  the same natively and in browsers, and a failed join can come straight back to the lobby.
- **Measurement runs are uncommitted experiments** when they touch shared lists (the +2 floats test
  on `TANK_PROPERTIES` was reverted, per the no-restructure rule).

**Questions for the lead**

1. *Assumed:* casual player-hosted matches through a relay first (N0 → N1) while N2 decides on
   lockstep. **N2 says lockstep is feasible** (bit-identical native vs wasm, 1.5% of a tick budget).
   Next decision: when to start porting the simulation to an integer core (recommended: after
   gameplay's directive sets 1–2 settle; designs §1 "What lockstep costs").
2. Can you run `make det-spike` on an **Android phone** (Chrome, same page: `?det-spike`)? ARM is the
   one platform not measured, and the one most likely to differ. The page prints
   `DET_SPIKE_RESULT` with the hash in the HUD status line; it must read `ea02d9652cc08086`.
3. Should the web build open the **lobby by default** when there are no URL flags? Today `?lobby`
   is opt-in so gameplay's offline default is untouched.

**Requests to other streams**

- **Gameplay:** (1) please add `sync_shield`/`sync_heat` as **ints quantized 0–100 with
  `REPLICATION_MODE_ON_CHANGE`** rather than always-sent floats: each always-sent float costs +0.23
  KB/s per tank per player (measured). (2) `tests/test_navigation.gd::test_path_goes_around_a_wall`
  is flaky on the loaded machine (failed 2 of ~8 `make check` runs tonight, "got 2 points"; it
  passed every run on its own). It looks like trip-up #22 (navmesh not ready right after baking).
  (3) When fog of war (G1) lands, netcode will filter hidden enemies out of each player's snapshots
  (`MultiplayerSynchronizer.set_visibility_for`); please expose the per-team visibility query.
- **Look & feel:** `game/network/ui/lobby_panel.gd` and `room_badge.gd` are plain Buttons/Labels,
  so please reskin them freely (keep the ≥ 48 px rule; `tests/test_lobby.gd` checks it).

**Known issues**

- On the wasm host smoke, SwiftShader renders at 2 fps, so the host simulates at ~15 ticks/s.
  That's the test machine's software rendering, not a phone measurement.
- No real phone has run any of this yet (host, player, backgrounding, det-spike).
- `make check` needs `npm ci` for the broker once (like web-smoke). Offline machines can't run it.

**What to playtest**

- `make play-relay`, then open **http://localhost:8100/?lobby** (this worktree's WEB_PORT; 8060
  after merge to main). Tap HOST A MATCH; in a second tab (or a phone on the LAN with
  `WEB_HOST=0.0.0.0`) open `?lobby`, tap the code, JOIN. Add `?host&demo&bots=2` for company.
- Watch a recording: `make replay` (records one), then `make replay-watch`.
- Headless proofs: `make relay-smoke relay-drop-smoke relay-latency-smoke relay-rejoin-smoke`,
  `make det-spike`, `make net-measure TANKS=20`, `make broker-load ROOMS=50`.

**Shared-file edits (merge notes):** `game/modes/game_mode.gd` (`--det-spike` → DetSpikeMode,
`--lobby` → LobbyMode, `--host` → HostMode, `--join`/`--replay` → ClientMode; all additive
checks), `game/main.gd` (flag docs only), `Makefile` (LIGHT_GOALS += broker, broker-bootstrap,
broker-test, broker-smoke, play-relay, replay-watch), `mk/core.mk` (`check` += broker-test
relay-smoke lobby-smoke; `check-all` += relay-drop-smoke relay-latency-smoke relay-rejoin-smoke
web-relay-smoke web-host-smoke). Netcode-owned but behavior-changing: `network_input.gd`
(staleness measured from the last network read; clients send on change), `server_mode.gd`
(join/leave handlers are methods now).

**Next steps (netcode)**

1. Real-phone runs: Android Chrome as player, as host, backgrounded, and `?det-spike`.
2. Interest management once fog lands (hidden enemies not sent: bandwidth + no map hack).
3. Replication diet after gameplay's G6/G7 land: drop `sync_position.y`, ON_CHANGE reload,
   quantized angles (estimate: −30–40% bytes).
4. `visibilitychange` → "player paused" instead of "lagging"; keep-open banner for hosts.
5. If the lead greenlights lockstep: broker protocol v2 (`lockstep` rooms), then port movement +
   shells first behind cross-build hash checks.

## Notes from other streams (2026-09-14)

- Gameplay will add replicated state: `sync_shield` (G6), `sync_ammo`, `sync_heat` (G7). Budget bandwidth for it, and for more units per side (budgeted armies).
- The product is **mobile first**: design for phones on flaky cellular links (reconnects, app backgrounding), which weighs against a phone acting as the match host.

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. **Assumed decision (the lead hasn't answered the open question):** take the recommended plan, casual player-hosted matches through a relay first (N0 → N1) while the deterministic spike (N2) is explored. Record the assumption under Questions for the lead. Nothing gets deployed and no accounts are created; everything runs locally. **Don't restructure `replication.gd`'s `TANK_PROPERTIES` list tonight**: gameplay appends `sync_ammo`/`sync_heat`/`sync_shield` to it in parallel.

1. **N0 broker** (`server/broker/` or similar, your call of language; dependencies pinned and installed by a `make broker-bootstrap`, run by `make broker`): lobbies with join codes, room relay of binary messages, host assignment, heartbeats, reconnect tokens, message size/rate caps, in-memory state. Unit tests + `make broker-smoke`.
2. **N1 player-hosted through the relay:** a Godot `MultiplayerPeerExtension` (or equivalent) that tunnels the existing high-level multiplayer through the broker, so `MultiplayerSpawner`/`Synchronizer`/RPC code works unchanged with one player hosting. `make relay-smoke`: a headless host + 2 headless clients through a local broker, combat happens (like combat-smoke). Then the browser client through the relay (`make web-relay-smoke`).
3. **Bandwidth + latency measurements:** bytes/second per client for today's snapshots with 10 and 20 tanks, the projected cost with shield/ammo/heat, and a latency-injection test (e.g. 150 ms + jitter) showing play stays sane. Record in this brief.
4. **N2 deterministic-core spike:** integer/fixed-point tank movement + shells + grid line-of-sight in GDScript (GDScript ints are 64-bit). Run the same command log native vs WebAssembly (the SwiftShader smoke browser is fine for *determinism*, which is CPU math) and compare hashes (`make det-spike`). Also measure the cost: can wasm GDScript tick 20 units at 30 Hz with headroom? Write a verdict: lockstep feasible, or not.
5. **N3 designs:** the lockstep protocol (command scheduling at T+N, hash exchange, desync handling, reconnect/catch-up) if N2 passes, host migration or "host left" handling for N1, and how mobile backgrounding is survived (measured with a test that drops a client's socket for 10 s and rejoins).
- **Stretch:** a command-log replay recorder/player (`make replay`); hosting cost estimates for the broker on common platforms (docs only, no accounts); an anti-cheat notes section for N1 (what a host can and can't fake).

## N0 broker (built 2026-09-14)

`server/broker/`: `src/protocol.mjs` (wire format), `src/broker.mjs` (rooms, relay, limits, resume),
`src/main.mjs` (CLI; every limit is a `--kebab-case` flag), `src/test_peer.mjs` (test client),
`smoke.mjs`. In-memory only; one process holds every room. HTTP `GET /healthz`, `GET /stats`
(counts only, never room codes). WebSocket on any path (`/relay` behind a proxy works).

**Control messages** (JSON text frames, `version: 1` on host/join):

| Direction | op | Fields | Meaning |
|---|---|---|---|
| → | `host` | `max_peers?` | open a room; you are peer 1 |
| ← | `hosted` | `room, peer_id, token, max_peers, heartbeat_ms, grace_ms` | 5-char code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| → | `join` | `room, peer_id?, player?` | proposed id is kept if free (Godot clients pick their id up front); `player` = opaque key `[A-Za-z0-9_-]{1,64}`, forwarded only to the host (rejoin) |
| ← | `joined` | `room, peer_id, token, host_id` | |
| → | `resume` | `token, last_seq` | new socket for an existing seat; `last_seq` = last frame seq you received |
| ← | `resumed` | `room, peer_id, last_seq, peers?, players?` | `last_seq` = your last frame the broker got; retransmit reliable frames after it |
| → / ← | `ack` | `seq` | trims the other side's retransmit buffer (broker acks every 250 ms) |
| → | `leave`, `kick {peer_id}` (host), `set_open {open}` (host), `ping {t}` | | |
| ← (host) | `peer_joined {player}`, `peer_away`, `peer_back`, `peer_left {reason}` | `peer_id` | reasons: left, kicked, timeout, rate_limited, overflow |
| ← (players) | `host_away`, `host_back`, `host_left {reason}` | | the room closes when the host leaves or its grace ends |
| ← | `error` | `code, message` | then a 4xxx close for fatal ones (`protocol.mjs` `CLOSE`) |

**Binary frames:** 9-byte header `int32 peer | uint8 flags | uint32 seq` + Godot's packet. `peer` is
the target going up (0 all, N one, −N all but N) and the sender coming down. `flags` = transfer mode
(bits 0-1) + channel (bits 2-7).

**Limits (defaults):** 64 KiB frames, 4 KiB control, 16 peers/room, 1000 rooms, 10 s to
host/join, ping every 5 s (two missed → away), 30 s grace, 4 MiB unacked reliable bytes per peer,
rates host 6000 msg/s + 2 MiB/s and player 600 msg/s + 256 KiB/s (2 s burst; exceeding closes the
seat with no grace), 5 wrong join codes per connection.

## Measurements (2026-09-14, localhost, relay, Godot 4.7.2)

`make net-measure`: a relayed dedicated host (`--no-player`) with bots, headless `--demo` players,
30 s windows. "Down/up" are per player through the broker, including the 9-byte relay header.

| Tanks | Players | Link | Down | Up | Snapshots/s in | Position update gap mean / p95 / max | Spawn → first motion |
|---|---|---|---|---|---|---|---|
| 10 | 1 | local | 14.6 KB/s | 3.0 KB/s | 36 | 37 / 50 / 67 ms | 300 ms |
| 10 | 2 | local | 15.0 KB/s | 3.0 KB/s | 35 | 35 / 50 / 51 ms | 290 ms |
| 10 | 4 | local | 14.7 KB/s | 3.0 KB/s | 33 | 35 / 50 / 51 ms | 291–323 ms |
| 20 | 1 | local | 27.3 KB/s | 3.0 KB/s | 43 | 39 / 50 / 52 ms | 313 ms |
| 10 | 2 | 150 ms + 50 ms jitter, every peer | 15.0 KB/s | 3.0 KB/s | 35 | 40 / 67 / 101 ms | 667–669 ms |
| 10 | 1 | +2 always-sent floats (shield/heat stand-ins) | 19.2 KB/s | 3.0 KB/s | 36 | 36 / 50 / 51 ms | 307 ms |
| 20 | 1 | +2 always-sent floats | 37.0 KB/s | 3.0 KB/s | 51 | 37 / 50 / 67 ms | 282 ms |
| 10 | 1 | after the send-on-change input policy | 15.2 KB/s | **1.5 KB/s** | 37 | 35 / 50 / 51 ms | 290 ms |

Host upload = players × down (10 tanks, 4 players: 60 KB/s measured by `TANK_SQUAD_HOST_STATS`).
Hosting on a phone's cellular uplink: 4 players × 15 KB/s = 480 kbit/s, fine on 4G; 8 players at
20 tanks ≈ 1.8 Mbit/s is where weak uplinks will hurt.

**Bandwidth recommendations for gameplay's new state:** send `sync_shield`/`sync_heat` as ints
quantized to 0–100 with `REPLICATION_MODE_ON_CHANGE` (only costs bytes while they change), not
always-sent floats (+0.23 KB/s per tank per player each). `sync_ammo` as an ON_CHANGE int is
negligible. Later wins (netcode, after tonight's no-restructure rule): drop `sync_position.y`
(always 0), make `sync_reload` ON_CHANGE, and filter hidden enemies per peer once fog of war lands
(fewer bytes and no map hack).
