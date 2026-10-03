#!/usr/bin/env python3
"""Round 17 G1: the weapon sheet. Every weapon and impact sound we ship, per take, measured the same way, so that
"the guns have no power" can be split into what the SOURCE is missing (no crack, no width, no tail), what the MIX
takes away (level, limiter, ducking, distance) and what the FORMAT cannot carry (mono, no sub layer).

    python3 tools/audio/weapon_sheet.py                         # the source sheet -> build/audio/weapon_sheet.{json,md}
    python3 tools/audio/weapon_sheet.py --arrivals build/audio/arrivals   # + what reaches the master (the probe's WAVs)

Per take: channels, duration, attack (10 -> 90 % of the envelope's peak), crest (sample peak over the loudest 400 ms
RMS), true peak (4x oversampled), momentary-max and integrated loudness (ITU-R BS.1770 K-weighting, gated), the
energy share in six bands (< 40, 40-80, 80-200, 200-2k, 2k-6k, > 6k Hz), the crack (the > 2 kHz level over the
first 15 ms against the loudest 50 ms of the whole sound), the tail (peak to 40 dB down) and the stereo width
(side over mid energy; 0 = mono).

The arrivals are recorded in the game (game/audio/weapon_probe.gd, `make weapon-sheet` on builder0): each sound
played through SfxSystem's real voices and buses at the overhead camera's distances, the Master bus recorded. The
same measurements of those recordings, against the source, are what the chain costs.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LAYERS = ROOT / "game" / "theme" / "audio" / "sfx_layers.gd"
SFX_SYSTEM = ROOT / "game" / "theme" / "audio" / "sfx_system.gd"
OUT = ROOT / "build" / "audio"

## The sheet: every sound a weapon makes when it fires, then everything a round makes when it lands.
FIRE_SOUNDS = ["tank_boom", "cannon_shot", "autocannon_shot", "mg_round", "mg_loop", "twin_mg_loop", "mortar_launch",
               "railgun_shot", "energy_beam", "laser_pulse", "pulse_shot", "plasma_loop", "missile_launch", "sonic_loop",
               "flame_loop"]
IMPACT_SOUNDS = ["explosion_big", "explosion_small", "shell_hit_armor", "dirt_impact", "bullet_hit_metal", "ricochet",
                 "weak_spot_hit", "shield_hit", "shield_down", "energy_hit", "shell_whine"]
SHEET_SOUNDS = FIRE_SOUNDS + IMPACT_SOUNDS
BANDS = [("<40", 0.0, 40.0), ("40-80", 40.0, 80.0), ("80-200", 80.0, 200.0), ("200-2k", 200.0, 2000.0),
         ("2k-6k", 2000.0, 6000.0), (">6k", 6000.0, 1e9)]


# ---- Reading -------------------------------------------------------------------------------------------------------

def read(path: Path) -> tuple[np.ndarray, int]:
    """(frames x channels float64 in -1..1, rate). WAVs are read directly; anything else through ffmpeg."""
    if path.suffix.lower() == ".wav":
        with wave.open(str(path)) as handle:
            rate = handle.getframerate()
            channels = handle.getnchannels()
            width = handle.getsampwidth()
            raw = handle.readframes(handle.getnframes())
        if width == 2:
            x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
        elif width == 4:
            x = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
        else:
            raise ValueError("%s: %d-byte samples" % (path, width))
        return x.reshape(-1, channels), rate
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=channels,sample_rate", "-of", "csv=p=0", str(path)],
                           capture_output=True, text=True, check=True).stdout.strip().split(",")
    rate, channels = int(probe[0]), int(probe[1])
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, channels), rate


def shipped_takes() -> dict[str, list[Path]]:
    """sound -> the files it plays: its layered takes (SfxLayers) when it has them, else the synthesised ones."""
    takes: dict[str, list[Path]] = {}
    for sound, paths in re.findall(r'"([a-z0-9_]+)": \[([^\]]*)\]', LAYERS.read_text()):
        takes[sound] = [ROOT / p.replace("res://", "") for p in re.findall(r'"(res://[^"]+)"', paths)]
    text = SFX_SYSTEM.read_text()
    sounds = dict(re.findall(r'"([a-z0-9_]+)": "res://(assets/audio/[a-z0-9_]+\.wav)"', text[: text.index("const TAKES")]))
    counts = dict((k, int(v)) for k, v in re.findall(r'"([a-z0-9_]+)": (\d+)', text[text.index("const TAKES"): text.index("const WORLD_VOICES")]))
    for sound, path in sounds.items():
        if sound in takes:
            continue
        base = ROOT / path
        pool = [base] + [base.with_name("%s_%d.wav" % (sound, n)) for n in range(2, counts.get(sound, 1) + 1)]
        takes[sound] = [p for p in pool if p.exists()]
    return takes


# ---- Loudness (ITU-R BS.1770-4) --------------------------------------------------------------------------------------

def k_weight(x: np.ndarray, rate: int) -> np.ndarray:
    """The K filter (a +4 dB shelf above ~1.7 kHz, then a high-pass at ~38 Hz), designed for any rate the way
    pyloudnorm does it, which reproduces the standard's 48 kHz coefficients."""
    from scipy.signal import lfilter
    gain_db, q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    k = np.tan(np.pi * fc / rate)
    vh = 10 ** (gain_db / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    y = lfilter(b, a, x, axis=0)
    q, fc = 0.5003270373238773, 38.13547087602444
    k = np.tan(np.pi * fc / rate)
    a0 = 1 + k / q + k * k
    return lfilter([1.0, -2.0, 1.0], [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0], y, axis=0)


def _block_powers(x: np.ndarray, rate: int, block_s: float, step_s: float) -> np.ndarray:
    y = k_weight(x, rate)
    n = int(block_s * rate)
    if len(y) < n:
        y = np.concatenate([y, np.zeros((n - len(y), y.shape[1]))])
    step = max(1, int(step_s * rate))
    power = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y * y]), axis=0)
    starts = np.arange(0, len(y) - n + 1, step)
    return ((power[starts + n] - power[starts]) / n).sum(axis=1)  # channels weighted 1 (L, R, C)


def _lufs(power: np.ndarray) -> np.ndarray:
    return -0.691 + 10 * np.log10(np.maximum(power, 1e-20))


def integrated_lufs(x: np.ndarray, rate: int) -> float:
    blocks = _block_powers(x, rate, 0.4, 0.1)
    gated = blocks[_lufs(blocks) > -70.0]
    if gated.size == 0:
        return -70.0
    relative = _lufs(np.array([gated.mean()]))[0] - 10.0
    gated = gated[_lufs(gated) > relative]
    return float(_lufs(np.array([gated.mean()]))[0])


def momentary_max_lufs(x: np.ndarray, rate: int) -> float:
    return float(_lufs(_block_powers(x, rate, 0.4, 0.01)).max())


def short_term_max_lufs(x: np.ndarray, rate: int) -> float:
    return float(_lufs(_block_powers(x, rate, 3.0, 0.1)).max())


def true_peak_db(x: np.ndarray, rate: int) -> float:
    from scipy.signal import resample_poly
    over = resample_poly(x, 4, 1, axis=0)
    return float(20 * np.log10(max(np.abs(over).max(), 1e-12)))


# ---- Shape ---------------------------------------------------------------------------------------------------------

def mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def _envelope(x: np.ndarray, rate: int, window_s: float) -> np.ndarray:
    n = max(1, int(window_s * rate))
    power = np.convolve(x * x, np.ones(n) / n, mode="same") if n < 64 else _running_mean(x * x, n)
    return np.sqrt(np.maximum(power, 0.0))


def _running_mean(x: np.ndarray, n: int) -> np.ndarray:
    padded = np.concatenate([[0.0], np.cumsum(x)])
    valid = (padded[n:] - padded[:-n]) / n
    head = (n - 1) // 2
    return np.concatenate([np.full(head, valid[0]), valid, np.full(len(x) - len(valid) - head, valid[-1])])


def band_shares(x: np.ndarray, rate: int) -> dict[str, float]:
    x = mono(x)
    spectrum = np.abs(np.fft.rfft(x)) ** 2
    freqs = np.fft.rfftfreq(len(x), 1.0 / rate)
    total = max(spectrum.sum(), 1e-20)
    return {name: float(spectrum[(freqs >= lo) & (freqs < hi)].sum() / total) for name, lo, hi in BANDS}


def attack_ms(x: np.ndarray, rate: int) -> float:
    """Time from 10 % to 90 % of the 1 ms envelope's peak: a gun's pressure front is a millisecond or two."""
    env = _envelope(mono(x), rate, 0.001)
    peak = env.max()
    if peak <= 0:
        return 0.0
    top = int(np.argmax(env >= 0.9 * peak))
    below = np.nonzero(env[:top + 1] < 0.1 * peak)[0]
    start = int(below[-1]) if below.size else 0
    return 1000.0 * (top - start) / rate


def crest_db(x: np.ndarray, rate: int) -> float:
    """Sample peak over the RMS of the loudest 400 ms: how far the strike stands above the body."""
    x = mono(x)
    n = min(len(x), int(0.4 * rate))
    power = _running_mean(x * x, n).max() if n > 0 else 0.0
    return float(20 * np.log10(max(np.abs(x).max(), 1e-12)) - 10 * np.log10(max(power, 1e-20)))


def tail_s(x: np.ndarray, rate: int, down_db: float = 40.0) -> float:
    """From the envelope's peak to the last moment it is within `down_db` of it."""
    env = _envelope(mono(x), rate, 0.01)
    peak_at = int(np.argmax(env))
    above = np.nonzero(env >= env[peak_at] * 10 ** (-down_db / 20))[0]
    return float((above[-1] - peak_at) / rate) if above.size else 0.0


def onset(x: np.ndarray, rate: int, threshold_db: float = -30.0) -> int:
    env = _envelope(mono(x), rate, 0.001)
    return int(np.argmax(env >= env.max() * 10 ** (threshold_db / 20)))


def crack_db(x: np.ndarray, rate: int) -> float:
    """The > 2 kHz level over the first 15 ms of the sound, against the loudest 50 ms of the whole of it (dB).
    A real gun's report is a broadband pressure front; a sound with no crack reads -30 or lower."""
    from scipy.signal import butter, sosfilt
    x = mono(x)
    start = onset(x, rate)
    high = sosfilt(butter(4, 2000.0, "highpass", fs=rate, output="sos"), x)
    front = high[start: start + int(0.015 * rate)]
    n = min(len(x), int(0.05 * rate))
    loudest = _running_mean(x * x, n).max() if n > 0 else 0.0
    return float(10 * np.log10(max(np.mean(front * front) if front.size else 0.0, 1e-20)) - 10 * np.log10(max(loudest, 1e-20)))


def width(x: np.ndarray) -> float:
    """Side energy over mid energy: 0 for mono, ~1 for two unrelated channels."""
    if x.ndim == 1 or x.shape[1] < 2:
        return 0.0
    mid = (x[:, 0] + x[:, 1]) / 2
    side = (x[:, 0] - x[:, 1]) / 2
    return float(np.sum(side * side) / max(np.sum(mid * mid), 1e-20))


def measure(x: np.ndarray, rate: int) -> dict:
    if x.ndim == 1:
        x = x[:, None]
    bands = band_shares(x, rate)
    return {
        "channels": int(x.shape[1]),
        "seconds": round(len(x) / rate, 3),
        "attack_ms": round(attack_ms(x, rate), 2),
        "crest_db": round(crest_db(x, rate), 1),
        "true_peak_db": round(true_peak_db(x, rate), 1),
        "momentary_max_lufs": round(momentary_max_lufs(x, rate), 1),
        "integrated_lufs": round(integrated_lufs(x, rate), 1),
        "bands": {k: round(v, 4) for k, v in bands.items()},
        "crack_db": round(crack_db(x, rate), 1),
        "tail_s": round(tail_s(x, rate, 40.0), 2),
        "width": round(width(x), 3),
    }


# ---- The sheet -----------------------------------------------------------------------------------------------------

def source_sheet(sounds: list[str] = SHEET_SOUNDS) -> dict:
    takes = shipped_takes()
    sheet = {}
    for sound in sounds:
        rows = []
        for path in takes.get(sound, []):
            x, rate = read(path)
            row = measure(x, rate)
            row["file"] = str(path.relative_to(ROOT))
            rows.append(row)
        sheet[sound] = rows
    return sheet


def summary(rows: list[dict]) -> dict:
    """The mean of a sound's takes (bands averaged as shares)."""
    if not rows:
        return {}
    keys = ["seconds", "attack_ms", "crest_db", "true_peak_db", "momentary_max_lufs", "integrated_lufs", "crack_db",
            "tail_s", "width"]
    out = {k: round(float(np.mean([r[k] for r in rows])), 2) for k in keys}
    out["channels"] = max(r["channels"] for r in rows)
    out["bands"] = {name: round(float(np.mean([r["bands"][name] for r in rows])), 4) for name, _, _ in BANDS}
    out["takes"] = len(rows)
    return out


def markdown(sheet: dict, title: str) -> str:
    lines = ["### " + title, "",
             "| sound | takes | ch | s | attack ms | crest dB | TP dBTP | M max LUFS | I LUFS | <40 | 40-80 | 80-200 | 200-2k | 2k-6k | >6k | crack dB | tail s | width |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for sound, rows in sheet.items():
        s = summary(rows)
        if not s:
            lines.append("| %s | 0 | | | | | | | | | | | | | | | | |" % sound)
            continue
        b = s["bands"]
        lines.append("| %s | %d | %d | %.2f | %.1f | %.1f | %.1f | %.1f | %.1f | %s | %.2f | %.1f | %.2f |" % (
            sound, s["takes"], s["channels"], s["seconds"], s["attack_ms"], s["crest_db"], s["true_peak_db"],
            s["momentary_max_lufs"], s["integrated_lufs"], " | ".join("%.0f%%" % (100 * b[n]) for n, _, _ in BANDS),
            s["crack_db"], s["tail_s"], s["width"]))
    return "\n".join(lines) + "\n"


## game/audio/weapon_probe.gd HEADROOM_DB: the unlimited arms are recorded this much lower, so nothing clips.
PROBE_HEADROOM_DB = 12.0
ARMS = ["full", "nolimit", "nofilter", "notrim"]


def arrival_sheet(folder: Path) -> dict:
    """The probe's recordings: <folder>/<sound>@<distance>m[~<arm>].wav, each the Master bus while one sound played.
    sound -> arm -> [rows by distance]; levels of the unlimited arms put back where they were played."""
    sheet: dict = {}
    for path in sorted(folder.glob("*@*m*.wav")):
        sound, rest = path.stem.rsplit("@", 1)
        distance, _, arm = rest.partition("~")
        arm = arm or "full"
        x, rate = read(path)
        if arm != "full":
            x = x * 10 ** (PROBE_HEADROOM_DB / 20)
        row = measure(x, rate)
        row["distance_m"] = float(distance.rstrip("m"))
        row["arm"] = arm
        row["file"] = str(path)
        sheet.setdefault(sound, {}).setdefault(arm, []).append(row)
    for arms in sheet.values():
        for rows in arms.values():
            rows.sort(key=lambda r: r["distance_m"])
    return sheet


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", default=str(OUT))
    parser.add_argument("--arrivals", help="the probe's folder of Master-bus recordings")
    parser.add_argument("--only", help="comma-separated sounds")
    args = parser.parse_args(argv)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    sounds = args.only.split(",") if args.only else SHEET_SOUNDS
    sheet = {"source": source_sheet(sounds)}
    text = markdown(sheet["source"], "Source (the shipped takes, as files)")
    if args.arrivals:
        sheet["arrivals"] = arrival_sheet(Path(args.arrivals))
        text += "\n" + arrivals_markdown(sheet["source"], sheet["arrivals"])
    (out / "weapon_sheet.json").write_text(json.dumps(sheet, indent=1) + "\n")
    (out / "weapon_sheet.md").write_text(text)
    print(text)
    print("weapon-sheet: %s" % (out / "weapon_sheet.md"))
    return 0


def arrivals_markdown(source: dict, arrivals: dict) -> str:
    """What reaches the master, against the file it played (the first take), and what each stage of the chain costs
    at the camera's focus (49 m) and across the arena (120 m): dB of momentary loudness and of the crack band."""
    lines = ["### Arrivals (the Master bus, one sound at a time, through the game's voices and buses; take 1)", "",
             "| sound | m | M max LUFS | TP dBTP | crest dB | crack dB | ch | width | Δ loudness | Δ crest | Δ crack |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for sound, arms in arrivals.items():
        first = (source.get(sound) or [{}])[0]
        for r in arms.get("full", []):
            lines.append("| %s | %.0f | %.1f | %.1f | %.1f | %.1f | %d | %.2f | %s | %s | %s |" % (
                sound, r["distance_m"], r["momentary_max_lufs"], r["true_peak_db"], r["crest_db"], r["crack_db"],
                r["channels"], r["width"],
                "%.1f" % (r["momentary_max_lufs"] - first["momentary_max_lufs"]) if first else "",
                "%.1f" % (r["crest_db"] - first["crest_db"]) if first else "",
                "%.1f" % (r["crack_db"] - first["crack_db"]) if first else ""))
    lines += ["", "### What each stage costs (dB; loudness / crest / > 2 kHz level). Level = MIX, distance, pan; "
              "trim = World -6 dB; filter = the distance filter; limit = World + Master limiters", "",
              "| sound | m | level | trim | filter | limit | total loudness | crest lost to limit | > 2 kHz lost to filter |",
              "|---|---|---|---|---|---|---|---|---|"]
    for sound, arms in arrivals.items():
        first = (source.get(sound) or [{}])[0]
        if not first:
            continue
        for distance in (49.0, 120.0):
            row = {arm: next((r for r in arms.get(arm, []) if r["distance_m"] == distance), None) for arm in ARMS}
            if None in row.values():
                continue
            loud = {arm: row[arm]["momentary_max_lufs"] for arm in ARMS}
            hi = {arm: high_level(row[arm]) for arm in ARMS}
            lines.append("| %s | %.0f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |" % (
                sound, distance, loud["notrim"] - first["momentary_max_lufs"], loud["nofilter"] - loud["notrim"],
                loud["nolimit"] - loud["nofilter"], loud["full"] - loud["nolimit"],
                loud["full"] - first["momentary_max_lufs"], row["full"]["crest_db"] - row["nolimit"]["crest_db"],
                hi["nolimit"] - hi["nofilter"]))
    return "\n".join(lines) + "\n"


def high_level(row: dict) -> float:
    """A row's > 2 kHz level in dB (loudness plus the band's share): what the distance filter takes."""
    share = row["bands"]["2k-6k"] + row["bands"][">6k"]
    return row["momentary_max_lufs"] + 10 * np.log10(max(share, 1e-9))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
