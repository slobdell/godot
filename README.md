# Tank Squad

A Godot 4 tank game that runs in the browser (WebAssembly) with a headless
multiplayer server built from the same project. It's headed toward a
squad-strategy game where you command five tanks by describing your strategy in
plain language. See [`_agents/vision.md`](_agents/vision.md).

## Quick start (Linux)

```bash
make bootstrap     # one time: pinned Godot 4.7.2 + export templates into ./.tools
make run           # play: WASD/arrows drive, mouse aims the turret
make editor        # open the Godot editor on this project
make help          # everything else
```

Play it in a browser:

```bash
make serve-web     # then open http://localhost:8060  (or /?demo to watch it drive itself)
```

## Where to read next

- New to Godot? [`_agents/godot_for_programmers.md`](_agents/godot_for_programmers.md)
- How the code is organized and why: [`_agents/architecture.md`](_agents/architecture.md)
- How online game servers work, and our plan: [`_agents/server_management.md`](_agents/server_management.md)
- What's done and what's next: [`_agents/roadmap.md`](_agents/roadmap.md)
- Working with Claude on this repo: [`CLAUDE.md`](CLAUDE.md) → [`HANDOFF.md`](HANDOFF.md)
