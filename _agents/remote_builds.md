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

**Read the result from the wrapper's own line, never from a shell exit code.** The last thing `tools/remote.sh`
prints is `>> remote: make <target> exited <N> (build/ copied back)`, and that `N` is the build's verdict. **Do not
pipe the command** (`make remote T=check | tail -20`): a pipeline reports the exit status of the *last* command in it,
so a failed build comes back as 0 and reads as green — that happened on 2026-09-17 and left `main` red for an hour.
Run it unpiped (or in the background) and then grep the saved output for that line and for the runner's
`N passed, M failed` summary. A harness line such as `[exited with code 0]` describes the wrapper, not the build.

**`build/` after a remote run is only this run's if the copy-back succeeded.** The wrapper rsyncs builder0's `build/`
over the local one at the end; until 2026-09-17 it threw that rsync's errors away and printed `(build/ copied back)`
whatever happened, so a full local disk left **screenshots, perf JSONs, recordings and reports from an earlier run**
sitting there looking current (audio nearly drew a conclusion from a three-hour-old recording of a different match,
and noticed only because its log named the wrong factions). A failed copy-back now says
`FAILED to copy build/ back ... local build/ is STALE`, prints the rsync error and `df`, and **fails the command
(exit 4)** even when the build itself passed, because nothing local proves what the run did. The cheap habit either
way: **check the timestamps** (`ls -la --time-style=+%H:%M build/...`) before believing a file you are about to
analyse or put in front of the lead.

**Workers: use `make remote T=…` for every heavy target** (check, test, smokes, match series, ladders, exports,
screenshots). Run light things locally (editing, `make lint`, a single quick test if builder0 is unreachable).
Interactive targets that open a window for the lead (`make skirmish`, `make editor`) stay local.

## How it works (`tools/remote.sh`)

| Step | Detail |
|---|---|
| Sync | `rsync -az --delete` of the checkout to `builder0:~/tank_squad/<folder name>` (`godot`, `godot-control`, …): each worktree gets its own remote folder, so parallel agents never share files. `local.mk` (ports) and `override.cfg` (Godot user dir) travel with it, so parallel remote runs don't collide either. Not synced: `.git/`, `.tools`, `.godot/`, `build/`, `node_modules/`, `assets/incoming/` (builder0 keeps its own import cache and dependencies). |
| Toolchain | `builder0:~/tank_squad/.tools` holds the pinned Godot + export templates (installed by our own `make bootstrap`) and Node v22.14.0, shared by every remote folder via a `.tools` symlink. No sudo, nothing system-wide. First use bootstraps automatically (~45 s on builder0's network). |
| Run | `make <args>` in the remote folder with Node on `PATH`, `TANK_SQUAD_SLOTS=3` (builder0's own heavy-run slots, so parallel agents queue there instead of overloading it), and `DISPLAY=:0` + the mutter Xwayland auth file when the desktop session is logged in. |
| Results | `build/` is copied back (logs, screenshots, reports, review pages; not `web/`, `server/`, `.pck`, `.wasm`). The script exits with make's status, or 4 when the copy-back failed and the build passed. |

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

## Paid generation does not take a slot

Targets that wait on a hosted API (ElevenLabs, Meshy) are network-bound and can run for an hour. They belong
in the root Makefile's `LIGHT_GOALS`, or they hold one of this laptop's two heavy-run slots doing nothing but
waiting, and everyone else queues behind them for a lint (audio's full announcer run, 2026-09-16).
`assets-generate`, the `art-*` targets and `announcer-generate` are all light for that reason. They also stay
local: remote runs don't forward API keys.

## Troubleshooting

- **"cannot reach builder0":** check `ssh -o BatchMode=yes slobdell@builder0 true`. Fall back to local `make`.
- **The link drops intermittently; retry before concluding anything.** On 2026-09-17 builder0 became unreachable twice
  (about half an hour around 13:30, and again at 15:40), each time with the machine itself fine — `uptime` showed 72
  days and load under 1 on either side of both outages. A run that dies with *"Timeout, server builder0 not
  responding"* or *"No route to host"* has told you nothing about your code: probe again a few seconds later, and
  re-run. Don't start a local full `make check` as a fallback unless the outage lasts: it takes 14–22 minutes, shares
  the laptop with every other agent, and makes timing-sensitive tests *less* trustworthy, not more.
- **Rendering targets fail with a display error:** nobody is logged into builder0's desktop (no
  `/run/user/1000/.mutter-Xwaylandauth.*`). Run that target locally, or ask the lead to log in.
- **Killing `make remote` locally does not stop the build on builder0.** `remote.sh` drives make over ssh, so the remote
  make (and whatever it queued in `slot.sh`) keeps running, and your next `make remote` rsyncs `--delete` underneath it.
  Stop the remote one first: `ssh slobdell@builder0` and kill only the processes whose
  `readlink /proc/<pid>/cwd` points at *your* folder (`~/tank_squad/godot-<stream>`).
- **Two runs from the same worktree at once clobber each other:** the remote folder is per worktree, not per run, so a
  second `make remote` rsyncs over a running one (seen 2026-09-15: a parallel test run broke a check with an rsync
  error). Run one remote command per worktree at a time, or copy the worktree.
- **Stale import cache weirdness:** `ssh slobdell@builder0 rm -rf ~/tank_squad/<folder>/.godot` and rerun.
- **Disk:** each remote folder holds its own `.godot` cache and `build/`; clean old ones with
  `ssh slobdell@builder0 rm -rf ~/tank_squad/godot-<old stream>` when a round closes.
- **One remote run per worktree at a time.** Every `make remote` rsyncs (with `--delete`) into the same
  `~/tank_squad/<folder>`, so a second run started while a `check` is going swaps the files under it (feel, 2026-09-15:
  a screenshot run synced uncommitted code mid-check and the check failed on a class it hadn't imported).
- **Stale screenshots:** if every capture after the first looks the same, Godot fell back to Wayland (a stale Xwayland
  cookie); `tools/remote.sh` now reads the running Xwayland's `-auth` file (feel, 2026-09-15).
- Secrets: remote runs don't forward API keys. Paid-generation targets (Meshy, ElevenLabs) run locally, where the
  lead's environment has the keys.
