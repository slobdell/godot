# builder2, the GCP burst builder (`balsa-worker-gcp`)

A second remote build machine for Tank Squad, powered on only when we want more throughput. builder0 stays the default
for everything. This one is a Google Cloud VM that we start, use, and stop again. It is the plane_maker project's
machine, `~/projects/plane_maker/gcp/` and `_agents/gcp_integration_plan.md`, reused. Set up for Tank Squad on
2026-10-17 (round 33).

## The machine

| | GCP burst builder | builder0 |
|---|---|---|
| Name / address | `builder2` (the lead's /etc/hosts), GCP VM `balsa-worker-gcp`, ZeroTier `10.115.229.9` | `builder0`, ZeroTier `10.115.229.237` |
| Where | GCP project `leddrones`, zone `us-west1-a` | the lead's house |
| Type | `c4d-standard-32`: 16 Zen 5 cores / **32 threads**, **121 GB** RAM | 12 threads, 14 GB RAM |
| Disk | 100 GB hyperdisk-balanced (45 GB used by plane_maker) | |
| OS / glibc | Ubuntu 26.04 LTS, glibc **2.43** (2ubuntu2) | Ubuntu 26.04 LTS, glibc **2.43** (2ubuntu2.4) |
| Toolchain | g++ 15.2.0, cmake 4.2.3, Python 3.14.4 (same as builder0) | same |
| Provisioning | **SPOT**: Google can stop it at any moment | always on |
| Display | none (headless only) | logged-in desktop (`DISPLAY :0`) |

**Same glibc, so the sim-baseline hashes should match.** The recorded match hashes carry the machine's glibc label
(`glibc-2.43`). A machine on a different glibc reads every map as moved. The first check confirms or refutes this
(see *First check*, below).

## Cost (from plane_maker's doc, us-west1; confirm in the console)

- **Running, Spot:** about **$0.52/hour**. On demand about $1.51/hour.
- **Stopped:** compute is free, but the 100 GB boot disk keeps billing (about $10/month), whether it runs or not.
- **Deleted** (`gcloud compute instances delete … --delete-disks=all`) costs $0, and it can be recreated with
  `~/projects/plane_maker/gcp/gcp_provision.sh` (about 10 minutes, then Tank Squad's first-use bootstrap below).
- The billing account is the lead's. **Never leave it running overnight unasked.** Stop it when the burst is done.

## Use it

```bash
make gcp-start                      # power on (billing starts), wait for ssh over ZeroTier (~30 s)
make gcp-status                     # RUNNING/TERMINATED, SPOT, and whether ssh answers
make gcp-remote T=check             # = make remote T=check, on the GCP box instead of builder0
make gcp-remote T="test FILTER=combat"
make gcp-stop                       # power off; REFUSES while any make runs there (FORCE=1 overrides)
```

`gcp-remote` is `REMOTE_HOST=slobdell@builder2 make remote …`: the same `tools/remote.sh`, with the same rsync,
guard, slots, copy-back and `>> remote: make … exited <N>` line. Everything in `_agents/remote_builds.md` applies:
launch long runs with `systemd-run --user` and read the wrapper's exited line. Each worktree gets its own folder,
`~/tank_squad/<worktree>`, on that box too.

**First use on a fresh box bootstraps itself.** `remote.sh` installs pinned Godot 4.7.2, its export templates
(1.3 GB) and Node into `~/tank_squad/.tools` the first time, about 1–2 minutes on Google's network. The native library
is built by the first `check` or `quick`, as on a fresh builder0 folder.

## Rules for the orchestrator

1. **Its numbers are its own machine's.** Every number from it carries `builder2` as its
   machine, never "builder0". Timing (perf-judge, per-tick prices) is NOT comparable with builder0's. A judged series
   runs both arms on ONE machine.
2. **Spot can vanish mid-run.** A preempted run ends `exited 255`, exactly like a network drop. It is no result,
   so re-run it. Prefer it for checks and series that are cheap to repeat. If preemptions start costing real work,
   switch it to on-demand (`gcloud compute instances set-scheduling … --provisioning-model=STANDARD`, while stopped),
   at about 3× the price.
3. **Rendering targets** (screenshots, windowed renders) stay on builder0 or the laptop. This box has no desktop.
4. **Stop it when the burst ends** (`make gcp-stop`). Before stopping, make sure no stream has a run there:
   `gcp-stop` refuses while any `make` runs, and `tools/remote.sh --status` under `REMOTE_HOST` shows whose.
5. **Turning it on is the lead's standing yes** ("we'll turn this builder on periodically whenever we want higher
   build throughput", 2026-10-17). Start it when the queue on builder0 is deep, and say so in HANDOFF.

## First check (2026-10-17, main `d99394f1`)

`build/gcp-first-check-d99394f1.log`. It was a cold box: the shared tools downloaded once (Godot and templates, about 2
min) and the folder imported cold.

- **The suite took 932 s (15.5 min), against 58–71 min (3461–4239 s) for builder0's main checks the same day under
  load.** It ran 12 targets at once, with 16 test shards and lint -P16. The AI's cost per tick was 5.5 ms here against
  about 10.9 ms on builder0, so each core is roughly 2× faster.
- **sim-baseline: 13 maps unmoved**, the same hashes as builder0's. The glibc match holds.
- **2738 passed, 1 failed:** `test_native_controller::test_the_controller_tick_is_the_live_gdscript`, 7 mismatches in
  600 scenarios. It passes on builder0 on the same code. native_controller is OFF by default, but a twin that depends on
  the CPU (AMD EPYC 9B45, AVX-512, v builder0's Intel i5-1345U) is handed to native as a determinism question.
  **Answered (native, `c7646f41`, merged as main `ac06a393`):** timer granularity, not the sim. The twin compares
  `profile_usec > 0`, and on Zen 5 the GDScript held path sometimes finishes inside one microsecond. The test now spins
  until the clock advances, and reads 0 mismatches on builder2 and on builder0.
- **web-smoke FAILED: no Chrome.** Installed since (google-chrome-stable 155.0.8059.84; builder0 has 150.0.7871.46).
- **perf-judge and scenario_perf NOT JUDGED: no nominal.** The image had no `/etc/hostname`, so the machine read as
  "unknown". It now holds `builder2`. The nominal is recorded idle with
  `make gcp-remote T=ai-perf-nominal` and goes into `tests/ai_scenarios/perf_nominal.json`. perf-judge's 1.5× refusal
  line is relative to each machine's own nominal, so builder2 judges against builder2.
- **A second worktree's cold import segfaulted once** (planner, re-run). See *Seeding a new worktree folder*.


**Not CPU-bound under one check (the lead watched htop, 2026-10-17).** One `make check` there runs up to 12 targets at
once, with 16 test shards and lint -P16, and the box still sits at load about 16 of 32. The tests are paced by the WALL
CLOCK (`make test` runs without `--fixed-fps`; `roadmap.md` has the candidate), so a test that waits 30 simulated seconds
waits 30 real ones, however many cores are free. **So builder2's throughput comes from running SEVERAL streams' jobs at
once, not from one check finishing much faster.** `REMOTE_SLOTS` (default 3 heavy) is the knob to raise once memory is
measured (121 GB is room for many).

**Seeding a new worktree folder (2026-10-17).** A worktree's first run on builder2 pays a cold `make import` (517
steps), and one cold import segfaulted (planner's folder, JetBrainsMono-Blocks.ttf, n 1). Copy the warm folder's import
cache instead: `ssh builder2 'cd ~/tank_squad && mkdir -p <wt> && cp -a godot/.godot <wt>/'` (105 MB). Godot then
re-imports only the files that differ, checked by content hash. rsync protects `.godot/`, so the next sync keeps it.
**Do NOT copy `native/bin` or `native/build`.** CMake's cache holds absolute paths, and a copied `.so` can look newer
than a branch's different C++ sources (rsync keeps the laptop's mtimes), so a stale library would be used. Let each
folder build its own native library.
