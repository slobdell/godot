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

> ⚠ **T1 (metrics, round 9, 2026-09-20) RETIRES every `make check` wall-clock figure taken before it**, on both
> machines. Not because the machine changed — because *the check* did. It now runs its targets concurrently and
> splits the test suite across processes, and the figures below were taken when it was one Godot process at a
> time. **Ratios computed inside one run survive; wall-clock totals, per-target durations and "budget N minutes"
> do not** (lesson 148's split, applied to itself).
>
> ⚠ **And every pre-T1 figure was also measuring a check whose `lint` step did nothing.** `git ls-files` cannot
> answer on builder0 (`.git/` is not rsynced), so `lint` iterated zero files, printed *"all scripts parse"* and
> exited 0. So the old numbers are for *less work than the check does now*, which is worth knowing before
> comparing them with anything.

### The serial profile, measured once so it never has to be guessed again

builder0, `c21d0256`, 12 cores, 12.4 GB available, load 0.42, 5 other Godot processes. Per target, serially:

| target | s | peak RSS | | target | s | peak RSS |
|---|---|---|---|---|---|---|
| **test** | **2388** | 427 MB | | garage-smoke | 7 | 266 MB |
| announcer-check | 80 | 252 MB | | net-smoke | 4 | 250 MB |
| audio-check | 30 | **919 MB** | | sim-baseline | 4 | 273 MB |
| army-loop-smoke | 24 | 272 MB | | broker-test | 2 | 84 MB |
| combat-smoke | 19 | 250 MB | | lobby-smoke | 2 | 259 MB |
| determinism | 11 | 257 MB | | match-smoke | 2 | 257 MB |
| relay-smoke | 11 | 249 MB | | match-pytest | 0 | 17 MB |
| | | | | **TOTAL** | **2584** | |

**`test` is 92% of the check.** Reproduce the table with `make check-timed` (it records the machine, its cores,
MemAvailable, the load average and how many other Godot processes were already running — because builder0 with one
check on it and builder0 with five are different machines for this purpose).

**Peak RSS is the largest single PROCESS, not a target's total** — `net-smoke` and `relay-smoke` each hold three
Godot processes at once. Round 8's "~735 MB a Godot run" is more than twice too pessimistic for these targets, and
the budgets in `mk/core.mk` are derived from this table rather than from that figure.

### Historic, retired by T1 — kept only to show what the check used to cost

| Run | Laptop | builder0 |
|---|---|---|
| `make check` (full, 2026-09-15) | 14–22 min (queued behind other agents' runs) | **6 min 40 s** (first run, including the first import) |
| `make check` (full, 2026-09-18, **six live streams**) | — | **~50 min** for 1010 tests, orchestrator's run on `main` at `5c68a03e` |

**The 6 min 40 s figure is a quiet-machine number, and a round with six streams is not a quiet machine.** With
several `make remote T=check` runs live, some execute and some wait, and the ones executing are also slower for
sharing the box — so any single figure needs its concurrent load beside it, which is why `check` now prints its own
load, MemAvailable and Godot-process count in its first line.

Two consequences, both learned the hard way on 2026-09-18:

1. **Iterate with a local `make check`; spend a remote slot only on a merge candidate** — a commit you are about to
   hand the orchestrator. Six streams each checking every green step is what makes the queue.
2. **`>> waiting for a heavy-run slot (N in use)` is printed when you enqueue, and is not retracted.** Being granted a
   slot is a *later* line in the same log. A stream read that first line, watched the log go quiet, and reported to
   the orchestrator that it had been starved of a slot for 50 minutes — while it had in fact been running for 48 of
   them. This is [orchestration.md](orchestration.md) lesson 28 in a new place: **read the line that reports the
   state you are asking about, and re-read your own log before reporting a stall.** Check what is actually running
   with `ssh slobdell@builder0 "ps -eo pid,etime,args | grep '[s]lot.sh'"` and match each pid to a worktree with
   `readlink /proc/<pid>/cwd`.
3. **A big measurement series deserves a cleared window**, not a share of two slots. Ask the orchestrator; it can tell
   the other streams to stay off builder0 for the duration.

**Two `make remote` runs from one worktree clobber each other, and the copy-back is the sneakier half.** Trip-up 66
covers the remote side: each run rsyncs `--delete` into the same `~/tank_squad/<folder>`, so a second run swaps files
under the first and the one already executing tests a tree that no longer exists (the orchestrator did this with
*three* at once on 2026-09-18 and had to stop all of them). The half that is easy to miss: **even with different
`REMOTE_ROOT`s, both runs copy back into the one local `build/`** — feel hit this and found a *newer* render silently
replaced by the other folder's *older* frames. It was caught only by checking the file's timestamp. So: **one remote
run per worktree at a time**, and before you analyse or relay anything out of `build/`, check its timestamp
(`ls -la --time-style=+%H:%M build/...`).

## builder0 runs vsync'd windows at a crawl: ~1/10 real time

**Measured 2026-09-18** (feel), same muted 30-second `audio-pass`, only vsync changed:

| | match seconds recorded in 30 s wall |
|---|---|
| vsync on (Godot's default) | **3.1 s** |
| `--disable-vsync` | **25.6 s** |

A vsync'd window on builder0's idle desktop presents at a crawl, so **anything that runs the game in a window there
and measures against the wall clock is recording slow motion.** `perf-scene` and `crowd-look` were never affected
because they already disable vsync. `audio-pass` now defaults to `--disable-vsync` (`PASS_GODOT_FLAGS`); `FrameTarget`
still paces the game.

**What this invalidates, and what it does not.** Round 5's audio numbers were taken this way and its own report noted
"game time runs ~10x slower than wall time" while leaving the cause open. Its **loudness, peak and clipping figures
stand** — they describe exactly what was recorded. What does **not** stand is anything about *how dense the battle was*
or how **ducking and layers behave over time**, including its "layer changes look rare" note: a compressor sidechain or
a duck envelope behaves completely differently when impacts arrive every 3 s instead of every 0.3 s, and slow motion is
the most flattering possible case for whatever is being ducked *under*.

**The general rule: if a harness opens a window on builder0, disable vsync or measure on the laptop.** For any
time-domain question (ducking, envelopes, rate limits, anything with a release or a cooldown), prefer the laptop — it
runs real time and it is the machine the lead plays on.

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
- **Back-to-back checks in one worktree folder can collide on a smoke port.** Round 5's close: a run came back
  `1010 passed, 0 failed` **and** `exited 2`, because `net-smoke` hit
  `server: cannot listen on port 9221: Already in use` -- the previous run's server in the same remote folder was
  still exiting. `make remote T=net-smoke` passed on its own immediately after, and the full check passed on the
  re-run. Note what caught it: the pass/fail counts alone said green, and only the wrapper's exit line disagreed.
  Leave a few seconds between runs in the same folder, and re-run before treating a port collision as a defect.
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

## ⚠ A foreground `make remote` is killed by the harness, not by another agent (found 2026-09-19)

**Symptom:** the wrapper ends with `make: *** [mk/core.mk:111: remote] Terminated` — or `Terminated sleep 5` inside
`tools/slot.sh`'s wait loop — **while the run was still queued on builder0 and no target had executed.** The remote side
is often still alive and queued, orphaned from its dead local wrapper.

**Cause: the agent harness SIGTERMs long-running foreground shell commands.** Its timeout **defaults to 2 minutes and
caps at 10**, and `make remote T=check` takes **30–50 minutes** during an active round, most of it waiting for a slot. So
a foreground check **cannot survive to completion by construction**, whatever timeout you pass.

**This is not another agent killing your run.** control suspected a pattern-matching cleanup, reasonably — trip-up 79 is
real and a broad `pkill -f "remote.sh"` once killed an orchestrator's own shell. But the orchestrator checked every live
wrapper by cwd at the time and found **six concurrent runs from five worktrees, all healthy**, including its own
**backgrounded** `check` alive at 43 minutes. **The backgrounded one survived; the foreground ones died.**

**The rule: never run `make remote` in the foreground. Always background it**, so the harness stops holding a timeout
over it, and read the result from the output file when it completes.

**How the streams lost time to this:** a wrapper killed at ~10 minutes has usually not started any target, so it produces
**no output at all** — not a failure, not a partial run, nothing. It reads as *"the queue is slow"*, which is also true,
and that coincidence hid it. **Several rounds of "still waiting for a slot, nothing came back" were this.** Check whether
a missing result is a killed wrapper before concluding builder0 is merely busy: `ps -o pid,etime,args -p <pid>` on the
wrapper, and `readlink /proc/<pid>/cwd` to confirm whose it is.

**If you find an orphaned remote run** (local wrapper dead, builder0 side alive), kill the remote side by cwd before
relaunching, or two runs will `rsync --delete` into the same builder0 folder — lesson 52.

## ⚠ The harness's own task-completion notification reports the wrong process (found 2026-09-19)

A backgrounded `make remote T=check ... | tail -30` on `main` finished and the harness announced
**`completed (exit code 0)`**. The wrapper's own line in the log said **`>> remote: make check exited 2`**, and
`sim-baseline` had failed. **The notification was reporting `tail`'s exit status, not `make`'s.**

**So the rule *never read a build result through a pipe* has a second face: the completion notification is downstream of
your pipeline too.** It is more dangerous than a piped `echo $?`, because it arrives from the *tooling* rather than from a
log, which is exactly the kind of source one trusts without checking. **Believing it here would have meant announcing
`main` green on the strength of a system notification.**

**Two consequences:**
- **Read the wrapper's `>> remote: make <target> exited <N>` line. Always. It is not advice about pipes** — it is the only
  channel in this system that reports the thing you actually asked about. Everything else reports the last process in a
  chain (combat's observation, having checked its own waiters and found them correct **by habit rather than by reasoning**).
- **Don't pipe at all when backgrounding.** Redirect to a file (`> log 2>&1`) and grep it afterwards, so the wrapper's
  status is also the shell's status and the two cannot disagree.

## ⚠ Killing a remote run locally does NOT stop it on builder0 (found 2026-09-19)

**`tools/remote.sh` dying — whether you kill it, or the harness SIGTERMs it at its 10-minute cap — leaves the `make` it
started still running on builder0.** The orphan **keeps holding a heavy-run slot**, and the next `rsync --delete` from the
same worktree **overwrites the tree underneath it**, so it continues testing a tree that no longer exists.

**This is a footgun for every stream, not a mistake anyone made.** combat lost a gate run to the second-order version: it
went to clean up orphans it had created this way, and killed its own live gate among them.

**Until the wrapper traps its own exit and stops the remote job — round-8 work, because `remote.sh` is the one tool all
six streams depend on and it should not be rewritten mid-round — the discipline is:**

1. **Identify by `readlink /proc/<pid>/cwd`, never by pattern.** `pkill -f "remote.sh"` has killed an orchestrator's own
   shell (trip-up 79), and a stale `until ! pgrep -f "remote.sh sim-baseline-record"` waiter from a **deleted** worktree
   was still matching that pattern **1 day 21 hours** later.
2. **Kill the remote side FIRST, then the local wrapper.** The other order re-creates the orphan you are removing.
3. **"I cannot account for this process" is a reason to LEAVE IT ALONE, not a reason to include it** (combat's rule,
   after assuming anything older than its launch was stale and killing its own live chain — exit 143).
4. **Kill only a PID you can tie to a specific launch by its start time.** Age alone is not evidence: checks legitimately
   run 30–50 minutes.

## ⚠ A cwd-filtered `pkill` can match its own shell (control, 2026-09-19)

control killed a superseded queued run with `pgrep -f "remote.sh|make remote"` filtered by cwd — **and the pattern matched
the kill command's own shell**, whose command line contains `make remote` and whose cwd is the worktree. **It killed
itself before reaching the ssh step, leaving the builder0 half orphaned in the queue.**

This is trip-up 79 one layer deeper: **filtering by cwd is necessary and not sufficient, because your own shell is also in
that cwd.**

- **Exclude `$$` and its parent from any cwd-filtered kill**, then **verify on builder0 afterwards** rather than assuming
  the local kill reached the remote side (it never does — see the orphaned-run section above).
- **An orphaned `slot.sh` ignores SIGTERM while sleeping in its wait loop and needs `kill -9`.**
- **`slot.sh`'s `kill -0` ticket check made the dead ticket harmless** — a queue that prunes tickets by liveness survives
  exactly this, which is why it was rewritten that way.

## ⚠ A worktree has no git-ignored asset masters, so a generation dry-run over-counts wildly (feel, 2026-09-19)

**The announcer's recorded masters are git-ignored, so they exist only in the main checkout.** feel's first
`announcer-generate` dry run from its worktree reported **"0 already recorded, 144 requests, ~17,018 credits"** — it
could not see any existing clip, so it planned to **re-buy every line for all seven existing arenas.**

**The real job was 18 clips, 2,125 characters, ~2,125 credits.** An **8× overspend**, and it would have looked like a
normal run.

- **Before any paid generation from a worktree, copy the masters in from the main checkout (read-only) and re-run the
  dry run.** The plan should collapse to the new items only.
- **Always dry-run paid generation and read the request count**, not just the credit estimate — *"144 requests"* was the
  tell, not the number after it.
- **This is the asset-pipeline form of lesson 132** (`origin/main` stale) and lesson 127 (*attributable is not current*):
  **a worktree is not the repository, and anything git-ignored is invisible from it.** What differs here is that the
  consequence is money rather than a wrong number.

## A transport failure is not a test failure, and it leaves `build/` lying (2026-09-19)

**`>> remote: make ... exited 255` is ssh, not the suite.** combat hit this mid-run: `Timeout, server builder0 not
responding`, then `No route to host`. The runner had printed **`590 passed, 0 failed`** before the machine left.
**No test failed. The machine did.** Also seen: **`exited 3, "cannot reach"`** when the host is down at launch
(arena) — likewise not a check result.

**And the dangerous part, which the wrapper says out loud and is easy to skim past:**

    >> remote: FAILED to copy build/ back (rsync exit 255); local build/ is STALE, not this run's

**After a 255, `build/` holds a PREVIOUS run's artefacts.** A stream that reads a number out of `build/` after a
transport failure gets a real, plausible number **from the wrong tree**. That is the worst shape of wrong available:
not missing, not obviously broken — plausible.

**Never assemble a check from two attempts.** combat's framing, kept verbatim because it is the cleanest statement of
the rule anyone has made here: *"590 from one attempt and the rest from another is not a check, it is two fragments
that never saw the same tree."*

**And this is why `sim-baseline-record` is read TWICE.** combat's reason is better than "confirm it repeats": with a
machine that has been flapping, **one reading cannot distinguish "this is the new hash" from "this run was
disturbed". Two agreeing readings can — and a disagreement is information about builder0 rather than about the
match.**

## A cold `make import` exceeds the slot timeout (2026-09-19)

**`slot.sh` kills any command at `TANK_SQUAD_SLOT_TIMEOUT`, default 5400 s — and a cold import on the laptop takes
longer than that.** Deleting `.godot` forces a re-import of ~968 MB of assets; on the 8-core laptop with ~2.4 GB
available it was killed at 90 minutes with `Error 124`, and `lint` then failed with `exited 2` **while reporting zero
script failures** — because its prerequisite had been killed, not because anything was wrong with the code.

**This matters most to anyone resetting the environment**, which is exactly when a cold import happens:

    TANK_SQUAD_SLOT_TIMEOUT=14400 make import

**And do not reach for `rm -rf .godot` as a remedy.** The symptom that provoked it — `Parse Error: referenced
non-existent resource` for tracked, present files, cascading into false `Nonexistent function` errors — is **two
lints sharing one import cache**, now prevented by the `flock` on `make lint`. Clearing `.godot/imported` is the
widest scope that is ever warranted; the full delete costs 90+ minutes and fixes nothing the lock does not.

## ⚠ Killing a `make` leaves `tools/slot.sh` holding a slot, and its stale `.owner` file makes a dead holder look alive (feel, 2026-09-20)

feel started a second `make lint` while the first was running, killed the wrong process in the chain, and one of the
laptop's two slots sat **held with nothing inside it** while every other stream queued behind it — the banner in every
waiter's log kept naming a job that had ended. The lock dies with the process; the owner file does not.

- **Kill the `slot.sh` wrapper, not the `make` inside it.** Find it with `ps -eo pid,args | grep '[s]lot.sh'` and
  `readlink /proc/<pid>/cwd` to confirm it is yours (trip-up 79).
- Then look in `/tmp/tank_squad_slots/`: a `slot<N>.owner` naming a PID that no longer exists is stale — remove it by
  hand. Waiters read that file for their banner, so a stale one lies to everyone.
- The habit that would have avoided it: builder0 sat at load 0.64 on 12 cores the whole time. Heavy runs go there.

## ⚠ An orphaned remote run yields NO verdict, and it blocks its own directory (squad, 2026-09-20 03:28)

`>> remote: make check exited <N>` is printed by the **local** wrapper. If the wrapper dies (a `&` inside a command
that then exits, a killed shell, a dropped ssh), the remote `make` keeps running on builder0, holds a slot, scrolls a
thousand PASS lines — and there is no line at the end, so by the rules the result does not exist. And you cannot
re-launch into `~/tank_squad/godot-<stream>` while the orphan is reading it (trip-up 66). **Launch pattern that
survives (squad's third launch of one check, after losing two):** `setsid nohup make remote T=check > log 2>&1 &`
— its own process group, a log with a completion marker (`echo CHECK_EXIT=$? >> log` after the make) — so neither a
parent shell exiting nor a signal aimed at somebody's process group can take the wrapper. Then read the wrapper line
from the log. **Before any re-run:** `ssh builder0 "ps -eo pid,etimes,args | grep '[s]lot.sh'"`, `readlink
/proc/<pid>/cwd` to find only yours, kill by explicit PID walking `pgrep -P` (never by pattern, trip-up 19), confirm
no survivors, then launch.

## ⚠ A process-pattern kill is machine-wide: seven checkouts run the same commands (metrics, 2026-09-20 04:39)

metrics meant to stop one orphaned run of its own and ran a kill loop over `ps | grep -E '[r]emote.sh check$'`.
Seven processes matched; two were its own. It killed the local wrappers of control's and squad's remote checks (combat's was reported dead and was not — a
read-only name match misled the report the same way) — the runs kept executing on builder0 (lesson 15) but their `>> remote: make check exited <N>` lines and
copy-backs were gone. **Every kill filters by `readlink /proc/<pid>/cwd` against the worktree first and prints what it
is about to kill** (trip-up 79, now from the other side). Recovery when it happens to you: wait for your folder to leave
`/tmp/tank_squad_slots/*.owner` on the box, read the verdict from `~/tank_squad/godot-<stream>/build/check/*.log` there,
rsync `build/` back by hand, and report the hash as "verdict read from the box's log, no wrapper line".

**A pattern-based process search is unsafe read-only as well as destructive.** `pgrep -f "Godot_v4.7.2"` matched the
shell running the search (its own command line contains the string, and its cwd passes a cwd filter), so it reported
a "lingering" process that was itself — a phantom that looks exactly like the leak you were hunting. Use self-excluding
patterns (`grep '[G]odot'`), or `pgrep -x` on the binary, and confirm by cwd (squad, 2026-09-20, third time in one night).

**`ps` ancestry is not ownership either: all nine sessions hang off one parent (PPID 2113).** feel filtered by
`ppid == 2113` as "mine" and the list held show's, squad's, scale's, control's and the orchestrator's runs. The
ownership test is `readlink /proc/<pid>/cwd`; who really holds a slot is `fuser /tmp/tank_squad_slots/slot<N>.lock`,
because an `.owner` file can be stale (feel, 2026-09-20 05:45).

**The wrappers now pin themselves (metrics `92c77b90`):** `remote.sh` and `slot.sh` re-exec from a private copy and unlink
it, so a `git merge` cannot rewrite a running wrapper (demonstrated: an unpinned script executed the replacement's lines
3–5 mid-run; the pinned one did not). **This does NOT retire "do not merge while a run is in flight"**, which stands on
three other grounds: sub-makes re-read `mk/*.mk` (every `_cp-*` wrapper of the parallel check spawns one), a second
`make remote` rsyncs into a directory a suite is reading (trip-up 66), and Godot loads `.gd`/`.tscn` lazily. Merge
between runs.

**An orphan blocks its own worktree's queue, not just a slot.** scale's dropped `arena-series` was still executing on
builder0 ten minutes after its wrapper died (the make, slot.sh, arena_series.py and two headless matches); the next
`make remote` from that worktree would have rsynced `--delete` under it. Kill the whole tree by cwd-verified PID
before relaunching (scale, 2026-09-20 08:45).
