# Agent Bridge: Claude Plays a Tank

> **Status: implemented (2026-09-12)**, with one playtest so far (report below).
> It started from the project lead's idea: *"make it so that you yourself have
> programmatic control of the input for one of the players… smoke test by
> playing against each other."*

## Why this is more than a test harness

It serves three purposes at once:

1. **Smoke testing with a thinking opponent.** Scripted bots find crashes; an agent that *tries to win* finds design problems. The first session found four (see the play report).
2. **A working prototype of the LLM commander.** The vision has an LLM giving strategy to tanks ([vision.md](vision.md)). Claude-through-the-bridge *is* that loop, just with a big cloud model on a slow cadence instead of Gemini Nano.
3. **The action layer that squad AI needs.** Orders like `move_to` and `target` are layer 2 ("Actions") of [squad_ai_design.md](squad_ai_design.md). The same `OrderController` runs the server's bots.

## The key constraint: Claude is slow, so Claude gives orders, not inputs

A human pilot adjusts inputs 60 times a second. Claude takes roughly 5–30 seconds
per decision (read state → think → act). So Claude **cannot** push `TankCommand`s.
Instead:

```
Claude (Bash tool)                   Godot process with --agent-port (client or offline)
  tools/agent.py state  ───HTTP────▶ AgentBridge ──▶ observe() ──▶ JSON
  tools/agent.py move 10 -20 ──────▶ AgentBridge ──▶ OrderController.set_orders() (validated)
                                     OrderController, every physics tick:
                                       move order + weapon order ─▶ TankCommand ─▶ NetworkInput ─▶ server
```

Orders are **standing**: they keep executing between Claude's turns. Claude is
a **commander with a limited command rate**, the same trade-off as experiment
E4's command budget.

## Code map

| File | Role |
|---|---|
| `game/ai/order_controller.gd` | `OrderController`: standing orders → `TankCommand` (steering, unstick, lead aiming, fire discipline). Validates orders |
| `game/ai/bot_controller.gd` | `BotController extends OrderController`: a 2 Hz policy (advance to nearest enemy, stop within 45 m when visible, fire at will). Server bots |
| `game/agent/agent_bridge.gd` | `AgentBridge`: a minimal HTTP/1.1 server on 127.0.0.1, served from `_physics_process` (observations do raycasts) |
| `tools/agent.py` | CLI with compact text output |
| `game/main.gd` `_make_controller()` | `--agent-port=N` swaps the local controller for OrderController + AgentBridge |

## Fairness and safety rules

- On a server, the agent is **an ordinary network client**. It sees only what a client receives (with fog of war in future, what its team can see), and its commands pass the same server validation as a human's.
- The bridge binds to **127.0.0.1 only** and exists only with `--agent-port`. It isn't available in the browser build (browsers can't open TCP servers).
- **A web page can also reach 127.0.0.1.** The bridge rejects any request with an `Origin` header (browsers send it on cross-site POSTs) and any `Host` other than `127.0.0.1:PORT` / `localhost:PORT` (DNS rebinding). Both are unit-tested.

## Interface

| Method | Path | Result |
|---|---|---|
| GET | `/state` | `me` (pos, heading, turret, health, alive, reload), other `tanks` (…plus distance, bearing, relative_bearing, `visible`, `exposed_face` = which armor a shot from here hits, `aiming_at_me`), `score`, current `orders`, `engaged` target |
| GET | `/map` | bounds, bases, shell speed and range, armor multipliers, obstacles as **world-space footprints** (`x: [min,max]`, `z: [min,max]`, height) |
| POST | `/orders` | `{"move": {...}, "weapon": {...}}`, either may be omitted; 400 with a reason if invalid (nothing changes) |
| POST | `/screenshot` | windowed clients only; saves `build/screenshots/agent_<ms>.png` |

Move orders: `{"type":"move_to","x":10,"z":-20}` · `{"type":"stop"}` · `{"type":"drive","throttle":1,"turn":0.3,"seconds":2}`
Weapon orders: `{"type":"fire_at_will"}` · `{"type":"target","name":"Bot_1"}` · `{"type":"aim","x":0,"z":0}` · `{"type":"hold_fire"}`

Coordinates: world meters, **x grows east, z grows south**. Compass headings: 0 = north (−Z), 90 = east (+X).

## Runbook

**Claude vs server bots (no human):**
```bash
make server BOTS=1          # background
make agent-client           # background; bridge on 127.0.0.1:8765
python3 tools/agent.py map  # once
python3 tools/agent.py fire-at-will && python3 tools/agent.py move -40 -30
python3 tools/agent.py watch 8   # wait while reporting events; repeat decide → order → watch
```
Or `make agent-offline BOTS=2` for a single-process match.

**The lead vs Claude:** `make server`, `make serve-web` → the lead opens
`http://localhost:8060/?connect` (they're Green or Rust, whichever is smaller);
Claude runs `make agent-client` and plays. Add `BOTS=1` for a 2v2 with bots.
To *watch* Claude's view, use `make agent-client-windowed` (and `agent.py screenshot`).

**Stopping background processes:** save PIDs (`… & echo $! > build/x.pid`) and
`kill $(cat build/x.pid)`. **Never `pkill -f <pattern>` from a shell whose own
command line contains that pattern:** it kills itself (this happened; exit code 144).

## Play report #1 (2026-09-12): Claude vs one BotController, 1v1, ~2 minutes

Final score: Bot 4, Claude 2. Findings, most important first:

1. **Standing orders without conditions don't suit a slow commander.** Claude was destroyed twice *between* decisions (7–10 s think gaps), once while sitting still on a finished `move_to`. The flip side: a standing `move_to + fire_at_will` left from an earlier turn won a fight while Claude wasn't looking. **Evidence for phases/directives:** the commander needs "retreat when HP < 40%" and "hold until an enemy is visible" as *orders*, not decisions it must be awake for. → [squad_ai_design.md](squad_ai_design.md) layer 4.
2. **1v1 has little positional skill.** A tank that charges you always shows its front armor (half damage), while you show your side if you move across it. Flanking needs a second unit to hold the enemy's attention. **Evidence that squads are where positional skill lives** (vision), and a warning that 1v1 balance tells us little.
3. **First shot wins an even duel, and pre-aim decides the first shot.** A chasing tank's turret already points at you when you round a corner. Added `aiming_at_me` to observations. Ambush positioning (pre-aiming the corner the enemy must come around) should be a real tactic; it needs perception memory so bots don't simply know where you are.
4. **Bots deadlock on walls.** Straight-line steering plus "reverse and turn" doesn't get around a 12 m wall; the bot pinned itself against the wall trying to reach Claude behind it. **M4's navmesh is necessary**, not polish.
5. **The bot is omniscient** (knows hidden positions). Fine for a baseline; unfair for ambush play. Perception memory / fog of war belong in M4–M5.
6. Bridge fixes made during play: obstacle footprints instead of center + size + rotation (rotated walls were ambiguous); `aiming_at_me`.
