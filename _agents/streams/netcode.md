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

`make net-smoke`, `make combat-smoke`, `make web-net-smoke`; add a relay smoke test (two headless
clients through the broker) and a cross-platform hash test (native vs wasm; `tools/web_smoke/smoke.mjs`
can capture `MATCH_RESULT` from the browser; see the measurement command in HANDOFF history).

## Status

- 2026-09-13: brief written; cross-platform determinism measured (diverges). Nothing started.
- 2026-09-14: overnight backlog added with an assumed decision (N0 → N1 casual relay while N2 spikes).

### Overnight run 2026-09-14 (netcode agent): morning report

**Plan (in order):** N0 broker → N1 relay peer (headless relay-smoke, then browser) → bandwidth/latency
measurements → N2 deterministic spike (native vs wasm) → N3 designs + a 10 s socket-drop test →
stretch (replay recorder, hosting costs, anti-cheat notes).

**Done**

1. **N0 broker** (`server/broker/`, Node 22 + `ws` 8.21.3 pinned). `make broker-bootstrap`,
   `make broker`, `make broker-test` (30 unit tests), `make broker-smoke` (real process: host + 2
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
   - 10 GDScript unit tests (`tests/test_relay_peer.gd`) + 1 new `test_network_input` case.

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

**Questions for the lead**

1. *Assumed:* casual player-hosted matches through a relay first (N0 → N1) while N2 decides on
   lockstep. Confirm or redirect.

**Requests to other streams:** none yet.

**Known issues:** none yet.

**What to playtest:** `make play-relay`, open http://localhost:8100/?host in one tab (this
worktree's WEB_PORT; 8060 on main), read the room code off the HUD, open
`http://localhost:8100/?join=CODE` in another tab. Add `&demo&bots=2` to the host URL for company.
Headless: `make relay-smoke`, `make relay-drop-smoke`.

**Shared-file edits (merge notes):** `game/modes/game_mode.gd` (`--host` → HostMode, `--join` →
ClientMode), `game/main.gd` (flag docs only), `Makefile` (LIGHT_GOALS: broker, broker-bootstrap,
broker-test, broker-smoke, play-relay), `mk/core.mk` (`check` += broker-test relay-smoke;
`check-all` += relay-drop-smoke web-relay-smoke web-host-smoke). `make check` now needs
`npm ci` for the broker once (like web-smoke does).

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
| → | `join` | `room, peer_id?` | proposed id is kept if free (Godot clients pick their id up front) |
| ← | `joined` | `room, peer_id, token, host_id` | |
| → | `resume` | `token, last_seq` | new socket for an existing seat; `last_seq` = last frame seq you received |
| ← | `resumed` | `room, peer_id, last_seq, peers?` | `last_seq` = your last frame the broker got; retransmit reliable frames after it |
| → / ← | `ack` | `seq` | trims the other side's retransmit buffer (broker acks every 250 ms) |
| → | `leave`, `kick {peer_id}` (host), `set_open {open}` (host), `ping {t}` | | |
| ← (host) | `peer_joined`, `peer_away`, `peer_back`, `peer_left {reason}` | `peer_id` | reasons: left, kicked, timeout, rate_limited, overflow |
| ← (players) | `host_away`, `host_back`, `host_left {reason}` | | the room closes when the host leaves or its grace ends |
| ← | `error` | `code, message` | then a 4xxx close for fatal ones (`protocol.mjs` `CLOSE`) |

**Binary frames:** 9-byte header `int32 peer | uint8 flags | uint32 seq` + Godot's packet. `peer` is
the target going up (0 all, N one, −N all but N) and the sender coming down. `flags` = transfer mode
(bits 0-1) + channel (bits 2-7).

**Limits (defaults):** 64 KiB frames, 4 KiB control, 16 peers/room, 1000 rooms, 10 s to
host/join, ping every 5 s (two missed → away), 30 s grace, 4 MiB unacked reliable bytes per peer,
rates host 6000 msg/s + 2 MiB/s and player 600 msg/s + 256 KiB/s (2 s burst; exceeding closes the
seat with no grace), 5 wrong join codes per connection.
