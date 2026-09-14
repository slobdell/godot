# Netcode designs (N3): lockstep, host loss, mobile backgrounding

> Written 2026-09-14 by the netcode stream overnight, after N2 measured a fixed-point core
> **bit-identical on native and WebAssembly** (streams/netcode.md, *N2 verdict*). Nothing here is
> built yet except what's marked **(built)**. Read streams/netcode.md first.

## 1. Lockstep protocol

### Shape

Every device runs the same deterministic simulation (a DetSim-style integer core) from the same
ordered stream of player inputs. The broker only relays. Nobody is authoritative, so there's no
host advantage and no host to lose.

| Term | Value | Why |
|---|---|---|
| Sim rate | 30 ticks/s | Squad commands don't need 60; N2 measured 20 tanks at 1.5% of a 30 Hz budget in wasm |
| Input delay `D` | 4 ticks (133 ms) by default, adaptive 2..10 | Covers RTT/2 + jitter for most links; squad orders tolerate 200 ms |
| Input bundle | every 2 ticks (15 Hz) per peer | Halves messages; latency cost 33 ms |
| Hash exchange | every 30 ticks (1 s) | Cheap (8 bytes), and localizes a desync to a 1 s window |
| Snapshot | every 300 ticks (10 s), kept locally | Reconnect catch-up and desync forensics |

### Messages (broker protocol v2: a `lockstep` room where any peer may broadcast)

The N0 broker's star topology only lets players address the host. A lockstep room sets
`{"op": "host", "mode": "lockstep"}` and lets every seat send to 0 (everyone). Frames keep the 9-byte
header and the resume/retransmit machinery, so a dropped socket loses nothing.

| Message | Fields | Sent |
|---|---|---|
| `INPUT` | `first_tick, last_tick, commands[]` (each `{tick, squad, verb, to, facing, formation}` = SquadCommand) | every 2 ticks, **even when empty** (it doubles as "I'm alive and at tick T") |
| `HASH` | `tick, hash64` | every 30 ticks |
| `PING`/`PONG` | `t` | 1 Hz, for adaptive delay |
| `SNAPSHOT_REQ` / `SNAPSHOT` | `tick` / `tick, bytes` | reconnect |

### Rules

1. A command issued locally during tick `t` is scheduled for `t + D` and put in the next `INPUT`.
2. Tick `T` executes only when every *active* seat's inputs covering `T` have arrived. Commands for
   the same tick apply in seat order (seat index assigned by the broker at join), then in send order.
3. If inputs are missing, the simulation **waits** (the view keeps interpolating and animating
   cosmetics). The game clock is the slowest active peer: honest, and nobody gets ahead.
4. `D` adapts: every 5 s, `D = clamp(ceil((rtt_p95 / 2 + 50 ms) / tick), 2, 10)` using the worst
   peer; the change is itself scheduled as a command at `t + D_old` so everyone switches on the same tick.
5. **Hash check:** after executing `T` with `T % 30 == 0`, send `HASH(T)`. A mismatch is a desync.

### Desync handling

- Freeze both hashes, both last snapshots, and the full input log (it's ~3 KB/min).
- **Casual:** majority wins. The minority peer requests a `SNAPSHOT` from a majority peer at the
  last agreed tick, verifies it hashes to the agreed value, replays inputs since, and continues. The
  match is tagged `desynced_once` for telemetry. (With two players there is no majority: both
  resync to the snapshot at the last agreed hash and the match continues untagged for ranking.)
- **Ranked:** the match is voided on the spot and the input log + snapshots go to a server that
  **replays the log** (cheap: a 5-minute match is 9000 ticks ≈ 3 s of CPU). The replay's hash
  says who diverged. Server compute is only spent on disputes, which keeps the cost goal.
- A desync with no cheater is a bug in the core; the log reproduces it exactly (`make replay`).

### Dropped peers and reconnect

- The broker is the neutral witness of connectivity. When a seat's grace period starts
  (`peer_away`), peers keep waiting on its inputs for up to **3 s** (short outages are invisible).
- After 3 s the seat goes **autopilot**: its squads follow their last orders plus doctrine
  (deterministic, like CPU squads). For every peer to agree on *when*, the broker announces
  `seat_autopilot {seat, from_tick}` where `from_tick` = 1 + the last tick covered by that seat's
  relayed `INPUT`s. Everyone uses it; nobody guesses.
- On resume (socket back within grace): the seat asks for a `SNAPSHOT` at the latest tick that is
  a multiple of 300, verifies its hash against the room's `HASH` messages, then fast-forwards
  through the logged inputs. Measured cost: 485 µs/tick in desktop wasm, so 60 s behind
  (1800 ticks) is ~0.9 s of catch-up. Assume ~5× slower on a mid-range phone: ~4.5 s. Then
  `seat_back {seat, from_tick}` ends autopilot at an agreed tick.
- Grace over: the seat stays on autopilot for the rest of the match (its squads keep fighting),
  and the player can rejoin by room code + player key into the same seat.

### Bandwidth and cost

Per peer, up: 15 `INPUT` bundles/s × ~20 bytes (mostly empty) + 1 `HASH`/s ≈ **0.3–0.6 KB/s**,
versus 14.6 KB/s down per player for today's snapshot replication (10 tanks, measured). Broker
egress falls ~25×.

### What lockstep costs the game (the real price)

All state-changing logic must move to integer math with a fixed iteration order:
movement/collision, shells, flamethrower cone, armor facing, line of sight, **intel**, **squads and
formations**, **TankBrain utility scoring**, and **pathing** (grid A* instead of NavigationServer).
Godot physics and NavigationServer stay out of the simulation (visuals can still use them). The
brains are gameplay-owned, float-heavy, and still changing weekly. Recommendation: don't port
while gameplay is iterating on rules. Keep N1 for casual play, and port when directive sets 1-2
settle, one system at a time behind `make det-spike`-style cross-build checks.

**Weakness that remains:** every device holds the full state, so a hacked client can reveal the
fog of war (map hack). Lockstep can't prevent that; ranked play would lean on replay review.

## 2. Host loss in N1 (player-hosted through the relay)

**(built)** A dropped host socket is survivable: the host's `RelayPeer` resumes within the
broker's 30 s grace. Players see "The host's connection dropped: waiting for them…" and the
action freezes (no snapshots, and their commands go stale after 500 ms). When the host resumes,
retransmission fills in reliable events and play continues.

**(built)** The host leaving or its grace running out closes the room. Players get `host_left`,
`server_disconnected` fires, tanks are cleared, and the HUD says "Match ended: <reason>".

**Host migration, considered and not recommended:**

| Option | How | Cost | Verdict |
|---|---|---|---|
| End the match | as built, plus a "rematch" button that re-hosts from the lobby | none | **ship this for N1** |
| Snapshot migration | host sends a compact match snapshot every 2 s to the broker; on loss the broker promotes the best-connected player, who rebuilds the scene from it and becomes peer 1 | High: Godot's replication assumes peer 1 never changes (node paths `Tank_<id>`, spawner state, RPC authority); up to 2 s rollback; every system needs snapshot/restore | no: lockstep removes the host instead |
| Backup host simulating in parallel | a second player also runs the sim from the same inputs | Only works with deterministic simulation, which *is* lockstep | fold into N3 |

**Recommended rule for N1:** prefer a desktop or a plugged-in phone as host, and have the
lobby say so. Show hosts a "keep this app open" banner when the page loses visibility
(`document.visibilitychange`).

## 3. Surviving mobile backgrounding

| Situation | What happens today (built) | Measured / reasoning |
|---|---|---|
| Socket drops for < 30 s (tunnel, Wi-Fi to cellular) | `RelayPeer` reconnects every 1 s and resumes its seat; reliable frames retransmit both ways; unreliable frames sent meanwhile are dropped | `make relay-drop-smoke`: 10 s cut, resumed after 10.1 s, same peer id, tank kept and moving, no errors, other player unaffected |
| Link silently dead (no FIN) | client notices after 8 s without traffic and reconnects; broker notices after two missed pings (≤ 10 s) | constants in `relay_peer.gd`, `broker.mjs` |
| Browser tab in background (player) | the page stops rendering and Godot stops polling; the browser still answers WebSocket pings, so the seat stays; the host's `NetworkInput` stops the tank after 500 ms without commands; on return, queued snapshots apply at once | reasoning; not yet measured on a real phone |
| App suspended > 30 s | seat released; the player can rejoin with the code but gets a **new** tank | gap: needs a player key → seat mapping in HostMode (next step) |
| Host backgrounded | the match freezes for everyone | inherent to N1; lockstep removes it |

**Next steps:** (1) a player key saved in `localStorage` and sent on join, so HostMode gives a
returning player their old tank; (2) `visibilitychange` → send `{"op":"away_intent"}` so the host
shows "paused" instead of "lagging"; (3) measure on a real Android phone (Chrome background tab and
app switch), which needs the lead's device.

## 4. Anti-cheat notes for N1 (player-hosted)

**The host can fake anything.** It runs the only simulation, so it decides damage, reloads,
positions, spawns, and who died, and its snapshots look legitimate. It also sees every tank
(fog of war doesn't exist for the host). N1 is for friends and casual rooms, not ranked.

**Players (clients) can fake very little:**

| Attack | Possible? | Why / mitigation |
|---|---|---|
| Speed hack, teleport, infinite ammo, faster reload, extra damage | **No** | the host simulates; a client only sends `throttle, turn, aim_point, fire` |
| Drive someone else's tank | **No** | `NetworkInput.accept` checks the sender owns the tank (tested) |
| NaN/huge values, input flooding | **No** | non-finite commands rejected, values clamped, 120 commands/s cap (tested); the broker also rate-limits every socket and closes floods with no grace |
| Message other players directly, spoof the host | **No** | the broker enforces the star topology and stamps sender ids itself (players can't forge `peer`) |
| Aimbot (perfect `aim_point`, instant fire) | **Yes** | inherent to sending aim; mitigate by turret turn-rate limits (already in the sim) and, later, server-side stats review |
| Map hack (see enemies through fog) | **Yes, today** | every tank replicates to every peer. Fix when gameplay's G1 fog lands: `MultiplayerSynchronizer.public_visibility = false` + `set_visibility_for(peer, visible)` driven by the team's visibility field, so hidden tanks aren't sent at all (also saves bandwidth) |
| Guessing room codes | **Hard** | 32^5 ≈ 33 M codes, 5 wrong guesses per connection, rooms exist only while hosted |
| Replaying someone's resume token | **Only with the token** | 144-bit random, sent only over the player's own socket; use `wss://` in production so it can't be sniffed |

**What the lead's "add comparable latency to the host" buys:** fairness in reaction time (the host
otherwise sees and acts 1 RTT sooner). It's cheap to add later: HostMode delays applying its own
local commands by the median player RTT (RelayPeer already measures pings). It does nothing for
integrity; only lockstep with hash checks (section 1) does.

## 5. Hosting cost estimates for the broker (docs only, no accounts)

**Measured traffic** (2026-09-14, `make net-measure`, today's snapshot replication through the relay):

| Match | Down per player | Up per player | Broker egress per player-hour |
|---|---|---|---|
| 10 tanks | 14.6 KB/s | 3.0 KB/s | (14.6 + 3.0) KB/s × 3600 ≈ **63 MB** |
| 20 tanks | 27.3 KB/s | 3.0 KB/s | ≈ **109 MB** |
| Lockstep (design, section 1) | ~0.5 KB/s | ~0.5 KB/s | ≈ **3.6 MB** |

(The broker relays both directions, so its egress is what it sends to players plus what it sends
to hosts.)

**What a broker needs (measured, `make broker-load`, 2026-09-14):** fake rooms replaying the
measured 10-tank traffic (host → each player 33 frames/s × 440 B; each player → host 30 frames/s × 50 B)
against one broker process on this 8-core desktop (shared with four other agents, so noisy):

| Rooms × players | Frames/s offered | Broker CPU (of one core) | Broker RSS | Memory per connection |
|---|---|---|---|---|
| 25 × 4 = 100 players | 6,300 | 22% | 60 → 68 MB | ~20 KB |
| 50 × 4 = 200 players | 12,500 | 38% | 66 → 81 MB | ~14 KB |

So roughly **20% of a desktop core per 100 players**, and memory is a non-issue. A cheap shared
vCPU (often half a desktop core or less) should carry **~200–300 concurrent players** in snapshot
relay mode; lockstep traffic (~25× fewer bytes and frames) would carry thousands. CPU, not memory
or bandwidth caps, is what scales a broker; add processes (rooms are independent) behind a join-code
→ process router when one fills.

**Rough monthly cost** for 1,000 player-hours per month at 10-tank matches (63 GB egress). List
prices as remembered at the 2025–26 knowledge cutoff; **verify before choosing**:

| Platform | Compute | Egress | Estimate |
|---|---|---|---|
| Fly.io (shared-cpu-1x, 256 MB) | ~$2/mo | ~$0.02/GB (NA/EU) | **~$3–4/mo** |
| Hetzner Cloud (CX22) | ~€4/mo | 20 TB included (EU) | **~€4/mo** |
| DigitalOcean droplet ($4–6) | $4–6/mo | 500 GB–1 TB included | **~$4–6/mo** |
| AWS Lightsail ($5) | $5/mo | 1 TB included | **~$5/mo** |
| AWS EC2 / Google Cloud VM | ~$4–8/mo | ~$0.08–0.12/GB | **~$10–14/mo** |
| Cloudflare Workers + Durable Objects (WebSocket hibernation) | usage-based | no egress fees | likely a few $/mo at this scale; needs a port of `broker.mjs` to the DO API |

At 100,000 player-hours per month (6.3 TB): bundled-transfer VPS hosts stay tens of dollars,
metered egress clouds reach roughly $500–750, and lockstep cuts either by ~20×. **Conclusion:**
relay bandwidth is affordable for casual N1 on a bundled-transfer host; lockstep is the scaling
lever, not the broker's CPU.
