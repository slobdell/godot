#!/usr/bin/env python3
"""Placeholder running-gear loops for the engine voices (X4): tracks clattering and tyres rolling.

    python3 tools/audio/make_world_loops.py        # writes assets/audio/{tread_loop,tire_loop}.wav

Synthesised and seeded like make_sfx.gd's sounds, CC0, one second long and seamless, so EngineSystem can pitch them
with speed (a faster vehicle clanks faster). ElevenLabs recordings replace them through sources.json like any other
sound; these exist so the layer is audible and testable before that.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sfx_layer  # noqa: E402

RATE = 22050
OUT = HERE.parents[1] / "assets" / "audio"


def band(x, low, high):
    return sosfilt(butter(2, [low, high], "bandpass", fs=RATE, output="sos"), x)


def seamless(x, fade_s=0.03):
    n = int(fade_s * RATE)
    t = np.linspace(0, np.pi / 2, n)
    head = x[:n] * np.sin(t) + x[-n:] * np.cos(t)
    return np.concatenate([head, x[n:-n]])


def tread_loop(rng):
    """Track links slapping the drive sprocket (12 a second at 1.0x), a grinding bed, a little squeal."""
    total = RATE + int(0.03 * RATE)
    t = np.arange(total) / RATE
    x = band(rng.standard_normal(total), 90, 900) * 0.25  # the grind
    for k in range(13):
        start = max(0, int((k / 12.0 + rng.uniform(-0.008, 0.008)) * RATE))
        length = int(0.05 * RATE)
        if start + length > total:
            continue
        env = np.exp(-np.arange(length) / RATE * 70.0) * rng.uniform(0.6, 1.0)
        clank = band(rng.standard_normal(length), 400, 3200) + np.sin(2 * np.pi * rng.uniform(700, 1100) * np.arange(length) / RATE)
        x[start:start + length] += clank * env * 0.9
    x += np.sin(2 * np.pi * 2300 * t + np.sin(2 * np.pi * 3 * t) * 4) * 0.03  # squeal
    return seamless(x)


def tire_loop(rng):
    """Big tyres on grit: a rolling roar with gravel crackle."""
    total = RATE + int(0.03 * RATE)
    x = band(rng.standard_normal(total), 120, 1400) * 0.6
    crackle = (rng.random(total) > 0.992) * rng.standard_normal(total)
    x += band(crackle, 1500, 6000) * 1.5
    return seamless(x)


def main() -> int:
    rng = np.random.default_rng(1987)
    for name, synth in (("tread_loop", tread_loop), ("tire_loop", tire_loop)):
        x = synth(rng)
        x = x / np.abs(x).max() * 0.85
        path = OUT / ("%s.wav" % name)
        sfx_layer.write_wav(path, x, RATE)
        print("wrote %s (%.2f s)" % (path.relative_to(HERE.parents[1]), len(x) / RATE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
