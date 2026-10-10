# Laptop session, native N5a/N5b/N5d (round 25, 2026-10-10 07:21-08:10 PDT)

flightdeck (UHD 620), his preset (`laptop`), `make native-tick-profile`, 25 a side, at `49e2bdcd` (= main `fccc520c` +
native's tooling and docs: the game code is main's), the library built on flightdeck just before (`make native`), a
180 s cooldown before each workload, arms alternated ABBA by arena x seed. A watcher logged every Godot process outside
this worktree and the load every 5 s (`watch-*.log`): nothing foreign in the water workload; one brains process at
07:51:48 overlapped the end of the bar's first run (foundry 92721 `on`), so that PAIR is voided (`tp-bar-*/void/`) and
was re-run at the end in reversed order (scan, on; `watch-rerun.log`: nothing foreign). Logs trimmed to their
NATIVE_TICK_PROFILE / PERF_PLAY lines; tables `tp-*/paired.txt` (`tests/native/tick_profile_paired.py`,
`tick_profile_budget.py`).

## Water workload (N5a's baseline + N5b): locks + crossing x 92721 31337 5988, window 12-24 s, n = 6 paired

| arm | flags | tick scripts | game speed in the window | paired v on |
|---|---|---|---|---|
| on (shipped) | | 38.21 ms | **0.763** (locks 0.803, crossing 0.723) | — |
| el | `--brains-on=native_el` | 37.53 | 0.772 | tick **−1.64 % (se 1.65)**: under the bar -> OFF by the letter; elements **−2.06 ms (se 0.33)** of 8.75; controllers +1.20 ms (se 0.30), spread +4-5 % over every brain section, match, tank and the engine's rays (none touched by the port: fight variance, the windowed fights diverge, el had >= hulls alive in every pair) |
| off | `--brains-off=native` | 56.65 | 0.537 | tick **+48.4 % (se 3.2)**: native is worth a third of the tick on water |

Gap to 0.97 (saturated model, cap 3 ticks a frame: R + 3 S <= 103.1 ms): **9.5 ms a tick (24.8 % of the scripts)**;
R (outside the sim) 14.8 ms a frame. Elements are 8.75 ms on water v 5.60 on the bar's maps (+3.2 ms).

## Bar workload (N5d): foundry + parade x 92721 31337 5988, window 8-20 s, n = 6 paired (one pair re-run)

| arm | flags | tick scripts | game speed | paired v on |
|---|---|---|---|---|
| on (shipped) | | 35.19 ms | **0.769** | — |
| scan | `--brains-on=native_scan` | 35.02 | 0.773 | tick **−0.39 % (se 1.08)** -> OFF (round 24's in-contact reading +2.05 %; both under the bar) |

Gap to 0.97: **9.0 ms a tick (25.6 % of the scripts)**, or 27 ms a frame from outside the sim alone (R 22.8 ms).
The base reads 0.769 here v 0.827 in round 24's `4ba8fd0b` session (tick scripts 35.2 v 32.4 ms): between-session
drift is known (0.75-0.81, lesson 282), and main moved after that session (brains' final merges); only the paired
columns rule.

Per arm, frame level (means): see the `frame / ticks / speed / process_ms / R` lines in `paired.txt` and the
orchestrator's message.
