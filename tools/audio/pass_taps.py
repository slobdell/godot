#!/usr/bin/env python3
"""Round 17 G1: what the mix's dynamics take from a real fight, from audio-pass's bus taps (--audio-taps).

    python3 tools/audio/pass_taps.py build/audio/pass.wav

Each tap pair (a bus before and after its effects; game/audio/audio_recorder.gd) becomes the gain that stage applied,
10 ms at a time, wherever the bus was loud enough to matter. The World bus's pair is its limiter (with its make-up
gain: AudioEffectLimiter lifts everything by ceiling - threshold) and the booth's duck; Bed's and Gunfire's are the
impacts' ducks. Reported: how hot the World bus runs into its limiter (peaks over full scale), the gain at the
loudest moments (where the shots are), and how often each stage takes more than 1 / 3 / 6 dB. Writes
<pass>.taps.json and prints a table.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import weapon_sheet  # noqa: E402

## game/audio/audio_recorder.gd TAP_HEADROOM_DB: every tap was recorded this much down.
TAP_HEADROOM_DB = 12.0
WINDOW_S = 0.01
## A window quieter than this on the way in is not a moment the stage matters.
FLOOR_DB = -45.0
PAIRS = [("world", "World: limiter (+make-up) and booth duck"), ("bed", "Bed: the impacts' duck"),
         ("guns", "Gunfire: the impacts' duck"), ("master", "Master: its limiter (out = the recording itself)")]


def windows_db(x: np.ndarray, rate: int, kind: str = "rms") -> np.ndarray:
    x = weapon_sheet.mono(x)
    n = int(WINDOW_S * rate)
    frames = len(x) // n
    blocks = x[: frames * n].reshape(frames, n)
    value = np.sqrt((blocks ** 2).mean(axis=1)) if kind == "rms" else np.abs(blocks).max(axis=1)
    return 20 * np.log10(np.maximum(value, 1e-9)) + TAP_HEADROOM_DB


def align_lag(tap: np.ndarray, recording: np.ndarray, rate: int, max_s: float = 8.0) -> int:
    """Samples to drop from the recording's start so it lines up with the tap (10 ms envelopes, cross-correlated)."""
    hop = int(WINDOW_S * rate)
    env = lambda x: np.sqrt(np.maximum((weapon_sheet.mono(x)[: (len(x) // hop) * hop].reshape(-1, hop) ** 2).mean(axis=1), 0))
    a, b = env(tap), env(recording)
    span = min(len(a), 3000)
    best, best_lag = -np.inf, 0
    for lag in range(0, int(max_s / WINDOW_S)):
        if lag + span > len(b):
            break
        score = float(np.dot(a[:span], b[lag: lag + span]))
        if score > best:
            best, best_lag = score, lag
    return best_lag * hop


def analyse(base: Path) -> dict:
    report = {}
    for name, label in PAIRS:
        tin, tout = base.with_suffix(".%s_in.wav" % name), base.with_suffix(".%s_out.wav" % name)
        if name == "master":
            tout = base  # Master's output is the recording (recorded after its limiter, at full scale: no tap headroom)
        if not (tin.exists() and tout.exists()):
            continue
        xi, rate = weapon_sheet.read(tin)
        xo, _ = weapon_sheet.read(tout)
        if name == "master":
            # The taps start TAP_AFTER_S into the run, the recording at its start: align them by their envelopes.
            xo = xo[align_lag(xi, xo, rate):]
        n = min(len(xi), len(xo))
        li = windows_db(xi[:n], rate)
        lo = windows_db(xo[:n], rate) - (TAP_HEADROOM_DB if name == "master" else 0.0)
        pi = windows_db(xi[:n], rate, "peak")
        active = li > FLOOR_DB
        gain = (lo - li)[active]
        if gain.size == 0:
            report[name] = {"label": label, "active_s": 0.0}
            continue
        loudest = li[active] >= np.percentile(li[active], 99)
        typical = float(np.median(gain))
        report[name] = {
            "label": label,
            "active_s": round(float(active.sum() * WINDOW_S), 1),
            "peak_in_dbfs": round(float(pi.max()), 1),
            "peak_in_p99_dbfs": round(float(np.percentile(pi[active], 99)), 1),
            "windows_over_full_scale_pct": round(100.0 * float((pi[active] > 0.0).mean()), 2),
            "gain_median_db": round(typical, 1),
            "gain_at_loudest_1pct_db": round(float(np.median(gain[loudest])), 1),
            "gain_min_db": round(float(gain.min()), 1),
            # below the stage's own typical gain (the limiter's make-up is not a reduction)
            "time_reduced_over_1db_pct": round(100.0 * float((gain < typical - 1.0).mean()), 1),
            "time_reduced_over_3db_pct": round(100.0 * float((gain < typical - 3.0).mean()), 1),
            "time_reduced_over_6db_pct": round(100.0 * float((gain < typical - 6.0).mean()), 1),
        }
    return report


def world_trim_db() -> float:
    import re
    text = (HERE.parents[1] / "game" / "theme" / "audio" / "sfx_system.gd").read_text()
    found = re.search(r"const WORLD_TRIM_DB := (-?[\d.]+)", text)
    return float(found.group(1)) if found else 0.0


def booth_and_music(base: Path) -> dict:
    """While the booth speaks: how far its voice sits above the battle reaching the master (World's output after its
    trim), and where the music sits. 400 ms windows; a window is speech when the booth is within 20 dB of its loudest."""
    paths = {k: base.with_suffix(".%s.wav" % k) for k in ("booth", "music", "world_out")}
    if not all(p.exists() for p in paths.values()):
        return {}
    data = {k: weapon_sheet.read(p)[0] for k, p in paths.items()}
    rate = 44100
    n = min(len(v) for v in data.values())
    hop = int(0.4 * rate)
    frames = n // hop

    def levels(x):
        x = weapon_sheet.mono(x)[: frames * hop].reshape(frames, hop)
        return 20 * np.log10(np.maximum(np.sqrt((x ** 2).mean(axis=1)), 1e-9)) + TAP_HEADROOM_DB

    booth, music, world = levels(data["booth"]), levels(data["music"]), levels(data["world_out"]) + world_trim_db()
    speaking = booth > booth.max() - 20.0
    if not speaking.any():
        return {"speech_s": 0.0}
    over = booth[speaking] - world[speaking]
    return {"speech_s": round(float(speaking.sum() * 0.4), 1),
            "booth_over_battle_median_db": round(float(np.median(over)), 1),
            "booth_over_battle_p10_db": round(float(np.percentile(over, 10)), 1),
            "music_under_battle_median_db": round(float(np.median(music - world)), 1),
            "battle_level_median_dbfs": round(float(np.median(world)), 1),
            "music_level_median_dbfs": round(float(np.median(music)), 1)}


def main(argv: list[str]) -> int:
    base = Path(argv[0])
    report = analyse(base)
    report["booth_and_music"] = booth_and_music(base)
    base.with_suffix(".taps.json").write_text(json.dumps(report, indent=1) + "\n")
    print("| stage | active s | peak in dBFS | p99 peak in | windows > 0 dBFS | gain median dB | gain at loudest 1 % | min | > 1 dB under | > 3 dB | > 6 dB |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for name, r in report.items():
        if name == "booth_and_music" or "gain_median_db" not in r:
            continue
        print("| %s | %.0f | %.1f | %.1f | %.2f %% | %+.1f | %+.1f | %+.1f | %.1f %% | %.1f %% | %.1f %% |" % (
            r["label"], r["active_s"], r["peak_in_dbfs"], r["peak_in_p99_dbfs"], r["windows_over_full_scale_pct"],
            r["gain_median_db"], r["gain_at_loudest_1pct_db"], r["gain_min_db"], r["time_reduced_over_1db_pct"],
            r["time_reduced_over_3db_pct"], r["time_reduced_over_6db_pct"]))
    print("booth and music while the booth speaks: %s" % json.dumps(report["booth_and_music"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
