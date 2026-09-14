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

## Notes from other streams (2026-09-14)

- Gameplay will add replicated state: `sync_shield` (G6), `sync_ammo`, `sync_heat` (G7). Budget bandwidth for it, and for more units per side (budgeted armies).
- The product is **mobile first**: design for phones on flaky cellular links (reconnects, app backgrounding), which weighs against a phone acting as the match host.
