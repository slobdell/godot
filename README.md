# Tank Squad

A Godot 4 tank game that runs in the browser (WebAssembly) with a headless
multiplayer server built from the same project. It's headed toward a
squad-strategy game where you command five tanks by describing your strategy in
plain language. See [`_agents/vision.md`](_agents/vision.md).

## Quick start (Linux)

```bash
make bootstrap     # one time: pinned Godot 4.7.2 + export templates into ./.tools
make run           # play vs a bot: WASD/arrows drive, mouse aims, click/space fires (BOTS=3 for more)
make check         # verify everything headless (tests + network + combat)
make editor        # open the Godot editor on this project
make help          # everything else
```

Play it in a browser:

```bash
make serve-web     # then open http://localhost:8060  (or /?demo to watch it drive itself)
```

Multiplayer (server-authoritative, over WebSockets):

```bash
make play BOTS=1   # game server + web page; open http://localhost:8060/?connect in 2+ tabs
make net-smoke     # or: prove it works with two headless bot clients
```
(Don't open port 9080 in a browser: that's the game server's WebSocket, and the page proxies to it.)

Let Claude play (it commands a tank through a localhost bridge):

```bash
make server BOTS=1     # terminal 1
make agent-client      # terminal 2; then ask Claude to play via tools/agent.py
```

## Where to read next

- New to Godot? [`_agents/godot_for_programmers.md`](_agents/godot_for_programmers.md)
- How the code is organized and why: [`_agents/architecture.md`](_agents/architecture.md)
- How tanks will think, and where player skill comes from: [`_agents/squad_ai_design.md`](_agents/squad_ai_design.md)
- How Claude plays, and what it learned: [`_agents/agent_bridge.md`](_agents/agent_bridge.md)

Robot-vs-robot matches, faster than real time (for balance and AI experiments):

```bash
make match GREEN=2 RUST=2               # one match, JSON result
make matches N=40 JOBS=6 GREEN=2 RUST=2 # a seeded series with win rates
```
- How online game servers work, and our plan: [`_agents/server_management.md`](_agents/server_management.md)
- What's done and what's next: [`_agents/roadmap.md`](_agents/roadmap.md)
- Working with Claude on this repo: [`CLAUDE.md`](CLAUDE.md) → [`HANDOFF.md`](HANDOFF.md)
