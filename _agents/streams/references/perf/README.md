# The labelled `perf-scene` baselines

Each file is a `make perf-scene` run kept on purpose, so a later run can be compared against the same scene rather
than against a number in a commit message. They are all `--skirmish --player=cpu --enemy=cpu --seed=3 --budget=6500
--cinematic` (34 a side at the start, dropping as vehicles die), tier **high**, on **the lead's laptop** — Mesa Intel
UHD 620 (WHL GT2), shared with the other agents' work, so CPU numbers are pessimistic and GPU numbers are the GPU's.
**Read the machine factor in `../fx_tricks.md` before quoting any of these against a builder0 number: the laptop is
~2.75× slower for identical headless work.**

Shape of a file: `{"phases": [...one entry per measured phase...], "summary": {...}}`. Reproduce any of them with
`PERF_RES=<res> PERF_NAME=<name> make perf-scene` plus the flags below, then compare `summary`.

| File | What it is | Taken at | Headline |
|---|---|---|---|
| `baseline-60hz-preinterp.json` | 720p, **60 Hz simulation, before physics interpolation** — the "old world" reference | `47e3efa1` | avg 46.61, p95 63.15, GPU 9.86 |
| `baseline-60hz-preinterp-1080.json` | the same run at the laptop's native 1080p | `47e3efa1` | avg 57.74, p95 66.48, GPU 13.88 |
| `hz30-720.json` | 720p **after the 30 Hz tick + interpolation**, uncapped | `9b07d107` | avg 29.27, p95 42.08, GPU 8.93; holds 60 fps at 14, locked 30 at 18 |
| `hz30-1080.json` | the same at 1080p, uncapped | `9b07d107` | avg 39.0, p95 48.26, GPU 14.85; holds 60 fps at 8, locked 30 at 12 |
| `hz30-locked30-1080.json` | `FrameTarget.LOCKED_30` (the default) at 1080p, 30 Hz era | `9b07d107` | avg 41.35, p95 47.41, GPU 14.17 — **above the 33 ms cap: it did not hold at these counts** |
| `hz30-perf60-720.json` | `FrameTarget.PERFORMANCE_60` (~720 lines), uncapped | `9b07d107` | avg 27.04, p95 34.05, GPU 8.91; locked 30 at 13 |
| `locked30-capped-60hz-1080.json` | **before 30 Hz**: capped at 30 at 1080p on the 60 Hz simulation | `15e048d8` | avg 106.05, p99 94–144 at 36–64 vehicles — the 60 Hz spiral; the line the 30 Hz work had to clear |

A caveat on reading **these seven**: they predate the summary carrying it, so the file itself does not say whether the
run was capped — the table above is the record. Runs taken from `f6a0dd40` onwards carry `"capped"` and
`"frame_target"` in their summary, so a new baseline says for itself.

**The trap in the capped runs:** `holds_60fps_at_vehicles` / `holds_30fps_at_vehicles` are 0 in
`hz30-locked30-1080.json` and `locked30-capped-60hz-1080.json`, and that does **not** mean the machine held nothing.
With `--perf-capped` the frame time is pinned at the cap (~33 ms), so the capacity test — "is the median frame under
1000/fps + 1 ms?" — can never pass for 60 and is right at the line for 30. **Capacity comes from uncapped runs; capped
runs answer a different question: does the locked rate hold, i.e. is `avg_ms` at the cap with a p95 that isn't much
worse?**

How the capacity numbers are computed, for reading them honestly (`game/theme/fx/bench/perf_scene.gd`,
`holds_fps_at`): the `all` phases are grouped by vehicle count, and the count is "held" while the **median** of its
frame times stays under `1000/fps + FPS_TOLERANCE_MS` (1.0 ms); it walks counts upward and stops at the first that
fails. **60 fps is judged on `avg_ms`, locked 30 on `p99_ms`** — a locked frame rate is about the worst frames, not
the average one, which is also why the same run can report 30 fps holding at more vehicles than 60 fps does.
