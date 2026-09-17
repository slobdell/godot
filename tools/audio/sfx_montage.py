#!/usr/bin/env python3
"""A scripted ten-second firefight mixed offline from the game's own sound files, for listening A/B.

    python3 tools/audio/sfx_montage.py --out build/audio/montage          # synth.mp3 and layered.mp3

The same script of shots, hits and bursts is mixed twice: once from the synthesised takes (what the game played
before round 5) and once with the layered takes wherever sfx_layers.gd has them. Volumes follow SfxSystem.MIX and
GunfireLoops.VOLUME_DB, distance is a gain and a lowpass the way AudioStreamPlayer3D applies them, and the sum goes
through the World bus's trim and a limiter, so the comparison is the game's mix rather than raw files.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import sfx_layer  # noqa: E402

RATE = sfx_layer.RATE
SFX_SYSTEM = ROOT / "game" / "theme" / "audio" / "sfx_system.gd"
LAYERS = ROOT / "game" / "theme" / "audio" / "sfx_layers.gd"
GUNFIRE_VOLUME_DB = -9.0
WORLD_TRIM_DB = -6.0

## Two scripts: the Condemned's guns (the original A/B), and the Syndicate's, which the lead heard as a cartoon
## because every weapon borrowed another faction's sound. "before" plays what each Syndicate weapon used to make.
SYNDICATE = [
    (0.00, "railgun_shot", 30, 0, 0), (0.55, "energy_hit", 55, 0, 0),
    (1.60, "pulse_shot", 25, 0, 0), (1.95, "pulse_shot", 25, 1, 0), (2.30, "energy_hit", 45, 1, 0),
    (3.20, "plasma_loop", 20, 0, 1.6),
    (3.60, "energy_hit", 40, 2, 0), (4.10, "energy_hit", 40, 0, 0),
    (5.20, "energy_beam", 22, 0, 0), (5.70, "energy_hit", 50, 1, 0),
    (6.60, "missile_launch", 35, 0, 0), (8.20, "explosion_small", 60, 0, 0),
    (9.00, "railgun_shot", 80, 1, 0), (9.60, "energy_beam", 28, 1, 0),
    (10.4, "plasma_loop", 70, 0, 1.2),
]
## What the lead actually heard playing the Syndicate: every weapon took its fire model's family sound, so both
## beams were the ray-gun zap, the repeater was the machine gun, and the missiles were a mortar tube.
WAS = {"railgun_shot": "laser_pulse", "energy_beam": "laser_pulse", "plasma_loop": "mg_loop",
       "pulse_shot": "autocannon_shot", "missile_launch": "mortar_launch", "energy_hit": "bullet_hit_metal"}

## (time s, sound, distance m, take index or None for random, hold s for loops)
SCRIPT = [
    (0.00, "tank_boom", 30, 0, 0),
    (0.55, "shell_hit_armor", 60, 0, 0),
    (1.40, "autocannon_shot", 25, 0, 0), (1.62, "autocannon_shot", 25, 1, 0), (1.84, "autocannon_shot", 25, 2, 0),
    (1.70, "bullet_hit_metal", 45, 0, 0), (1.93, "bullet_hit_metal", 45, 1, 0), (2.15, "ricochet", 45, 0, 0),
    (2.60, "mg_loop", 20, 0, 1.8),
    (3.10, "bullet_hit_metal", 50, 2, 0), (3.50, "bullet_hit_metal", 50, 3, 0),
    (4.60, "tank_boom", 90, 1, 0),
    (5.30, "dirt_impact", 40, 0, 0),
    (6.20, "tank_boom", 18, 2, 0),
    (6.72, "shell_hit_armor", 40, 1, 0),
    (6.95, "explosion_big", 40, 0, 0),
    (7.60, "autocannon_shot", 70, 1, 0), (7.82, "autocannon_shot", 70, 0, 0), (8.04, "autocannon_shot", 70, 2, 0),
    (8.40, "mg_loop", 110, 0, 1.2),
]
LENGTH_S = 11.0


def mix_table() -> dict:
    text = SFX_SYSTEM.read_text()
    block = text[text.index("const MIX := {"):]
    block = block[: block.index("}")]
    return {m.group(1): float(m.group(2)) for m in re.finditer(r'"([a-z_]+)": \[(-?[\d.]+), ', block)}


def distance_filter_table() -> dict:
    text = SFX_SYSTEM.read_text()
    block = text[text.index("const DISTANCE_FILTER := {"):]
    block = block[: block.index("}")]
    return {m.group(1): (float(m.group(2)), float(m.group(3)))
            for m in re.finditer(r'"([a-z_]+)": \[([\d.]+), (-?[\d.]+)\]', block)}


def layered_table() -> dict:
    if not LAYERS.exists():
        return {}
    return {m.group(1): [ROOT / p for p in re.findall(r'"res://([^"]+)"', m.group(2))]
            for m in re.finditer(r'"([a-z_]+)": \[([^\]]*)\]', LAYERS.read_text())}


def alias_table() -> dict:
    """SfxSystem.ALIAS: what a sound falls back to while it has no takes of its own."""
    text = SFX_SYSTEM.read_text()
    block = text[text.index("const ALIAS := {"):]
    block = block[: block.index("}")]
    return dict(re.findall(r'"([a-z_]+)": "([a-z_]+)"', block))


def synth_files(sound: str) -> list[Path]:
    audio = ROOT / "assets" / "audio"
    return [audio / ("%s.wav" % sound)] + sorted(audio.glob("%s_[0-9].wav" % sound))


def place(bed: np.ndarray, x: np.ndarray, start_s: float) -> None:
    start = int(start_s * RATE)
    end = min(len(bed), start + len(x))
    if end > start:
        bed[start:end] += x[: end - start]


def at_distance(x: np.ndarray, sound: str, distance: float, filters: dict) -> np.ndarray:
    # AudioStreamPlayer3D inverse distance with SfxSystem's unit_size 55: gain = unit_size / max(unit_size, d) roughly.
    gain = 55.0 / max(55.0, distance)
    if sound in filters:
        cutoff, db = filters[sound]
        amount = min(1.0, distance / 600.0) * 1.8  # the engine interpolates the filter with distance; our fights are close
        amount = min(1.0, amount)
        from scipy.signal import butter, sosfilt
        dull = sosfilt(butter(2, max(cutoff, 20000 - (20000 - cutoff) * amount), "lowpass", fs=RATE, output="sos"), x)
        x = x + (dull - x) * min(1.0, amount * abs(db) / 12.0)
    return x * gain


def render(use_layered: bool, script: list | None = None, substitute: dict | None = None) -> np.ndarray:
    mix, filters, layers = mix_table(), distance_filter_table(), layered_table() if use_layered else {}
    script = script if script is not None else SCRIPT
    bed = np.zeros(int(max(t for t, *_ in script) + 4.0) * RATE)
    cache: dict = {}
    for when, sound, distance, take, hold in script:
        sound = (substitute or {}).get(sound, sound)
        pool = layers.get(sound) or synth_files(sound)
        if not any(p.exists() for p in pool):  # not generated yet: what it stands in for (SfxSystem.ALIAS)
            stand_in = alias_table().get(sound, sound)
            pool = layers.get(stand_in) or synth_files(stand_in)
        path = pool[take % len(pool)]
        if path not in cache:
            cache[path] = sfx_layer.decode(path)
        x = cache[path]
        if hold:
            repeats = int(np.ceil(hold * RATE / len(x)))
            x = np.tile(x, repeats)[: int(hold * RATE)]
            x = sfx_layer.fade_tail(x, 0.03)
            volume = GUNFIRE_VOLUME_DB
        else:
            volume = mix.get(sound, 0.0)
        place(bed, at_distance(x, sound, distance, filters) * 10 ** (volume / 20), when)
    return sfx_layer.limit(bed * 10 ** (WORLD_TRIM_DB / 20))


def write_mp3(x: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "pipe:0",
                    "-c:a", "libmp3lame", "-b:a", "160k", str(path)], input=pcm, check=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "audio" / "montage")
    parser.add_argument("--syndicate", action="store_true", help="the Syndicate's weapons, before and after")
    args = parser.parse_args(argv)
    renders = [("syndicate_before", render(True, SYNDICATE, WAS)), ("syndicate_after", render(True, SYNDICATE))] \
        if args.syndicate else [("synth", render(False)), ("layered", render(True))]
    for name, x in renders:
        write_mp3(x, args.out / ("%s.mp3" % name))
        print("%s.mp3: loudest 400 ms %.1f dB, peak %.1f dBFS" % (name, sfx_layer.loudness_db(x),
                                                              20 * np.log10(max(np.abs(x).max(), 1e-9))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
