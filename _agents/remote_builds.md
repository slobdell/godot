# Remote builds on builder0

> Added 2026-09-15. The lead: *"our machine is horrifically slow at building. Therefore we need to be able to offload
> our builds to a remote build machine … in reality we just need to be able to offload builds to builder0 (i.e. I
> can ssh to slobdell@builder0). Getting our builds fast unblocks the rest of our development cycles."*
> `~/projects/plane_maker` has a distributed build system; it's deliberately not copied (overkill for one builder).

## Use it

```bash
make remote T=check                    # make check on builder0; logs and screenshots copied back to build/
make remote T="test FILTER=combat"     # any make target with its variables
make remote T=skirmish-shots           # rendering targets use builder0's logged-in desktop (DISPLAY :0)
tools/remote.sh ai-ladder VARIANTS=a6,a5   # the script directly
```

**Workers: use `make remote T=…` for every heavy target** (check, test, smokes, match series, ladders, exports,
screenshots). Run light things locally (editing, `make lint`, a single quick test if builder0 is unreachable).
Interactive targets that open a window for the lead (`make skirmish`, `make editor`) stay local.

## How it works (`tools/remote.sh`)

| Step | Detail |
|---|---|
| Sync | `rsync -az --delete` of the checkout to `builder0:~/tank_squad/<folder name>` (`godot`, `godot-control`, …): each worktree gets its own remote folder, so parallel agents never share files. `local.mk` (ports) and `override.cfg` (Godot user dir) travel with it, so parallel remote runs don't collide either. Not synced: `.git/`, `.tools`, `.godot/`, `build/`, `node_modules/`, `assets/incoming/` (builder0 keeps its own import cache and dependencies). |
| Toolchain | `builder0:~/tank_squad/.tools` holds the pinned Godot + export templates (installed by our own `make bootstrap`) and Node v22.14.0, shared by every remote folder via a `.tools` symlink. No sudo, nothing system-wide. First use bootstraps automatically (~45 s on builder0's network). |
| Run | `make <args>` in the remote folder with Node on `PATH`, `TANK_SQUAD_SLOTS=3` (builder0's own heavy-run slots, so parallel agents queue there instead of overloading it), and `DISPLAY=:0` + the mutter Xwayland auth file when the desktop session is logged in. |
| Results | `build/` is copied back (logs, screenshots, reports, review pages; not `web/`, `server/`, `.pck`, `.wasm`). The script exits with make's status. |

Knobs (environment or `local.mk`): `REMOTE_HOST` (default `slobdell@builder0`), `REMOTE_ROOT` (default
`tank_squad`), `REMOTE_SLOTS` (default 3).

## builder0 (checked 2026-09-15)

12 cores (i5-1345U), 14 GB RAM, ~23 GB free disk, Intel Iris Xe, Ubuntu 26.04 (glibc 2.43), git, rsync, Python 3, ffmpeg, Google
Chrome 150. Passwordless ssh from the laptop as `slobdell`. No sudo.

## Measurements

| Run | Laptop | builder0 |
|---|---|---|
| `make check` (full, 2026-09-15) | 14–22 min (queued behind other agents' runs) | **6 min 40 s** (first run, including the first import) |

## The sim baseline differs per machine

builder0 (glibc 2.43) and the laptop (glibc 2.39) produce different `make sim-baseline` hashes from the same binary
(system math library differences; [determinism.md](determinism.md)). The baseline file holds one line per glibc
version; builder0's is canonical. When gameplay changes on purpose: `make remote T=sim-baseline-record`, then
`cp build/sim_state_hash.txt tests/baselines/` and commit.

## Troubleshooting

- **"cannot reach builder0":** check `ssh -o BatchMode=yes slobdell@builder0 true`. Fall back to local `make`.
- **Rendering targets fail with a display error:** nobody is logged into builder0's desktop (no
  `/run/user/1000/.mutter-Xwaylandauth.*`). Run that target locally, or ask the lead to log in.
- **Stale import cache weirdness:** `ssh slobdell@builder0 rm -rf ~/tank_squad/<folder>/.godot` and rerun.
- **Disk:** each remote folder holds its own `.godot` cache and `build/`; clean old ones with
  `ssh slobdell@builder0 rm -rf ~/tank_squad/godot-<old stream>` when a round closes.
- Secrets: remote runs don't forward API keys. Paid-generation targets (Meshy, ElevenLabs) run locally, where the
  lead's environment has the keys.
