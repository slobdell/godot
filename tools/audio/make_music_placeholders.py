#!/usr/bin/env python3
"""Placeholder music beds and stingers, so the music director is testable before the lead writes the real tracks.

    python3 tools/audio/make_music_placeholders.py --out assets/music

Everything here is synthesised from scratch (no samples, no downloads, seeded), the way the sound effects are, and is
ours to ship. These are **placeholders**: correct tempo, correct loop points, correct loudness, and deliberately
plain, so nobody mistakes one for the finished thing. The real tracks come from Suno against assets/music/PROMPTS.md
and replace these file by file — the manifest row is what the director reads, so a swap is a file plus a row.

Mono and 48 kbps because they are placeholders and live in git; the real beds are stereo at 96-128 kbps.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import re
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

RATE = 44100
BITRATE = "48k"
## PROMPTS.md's loudness contract. Placeholders are normalised to it so a crossfade between a placeholder and a real
## track doesn't jump, and limited so nothing clips (normalising to -16 LUFS alone pushed three beds over 0 dBFS).
TARGET_LUFS = -16.0
PEAK_CEILING_DB = -1.5
## Vorbis decodes a little hotter than it was encoded, so the limiter aims below the ceiling and the measurement
## above is taken from the encoded file.
LIMITER_DB = -3.5

# state -> (bpm, beats_per_bar, bars, root Hz, character). `character` picks how the bed is voiced below.
BEDS = {
    "garage":     (95, 4, 4, 55.00, "brood"),
    "pre_match":  (100, 4, 4, 49.00, "tension"),
    "victory":    (120, 4, 4, 65.41, "triumph"),
    "defeat":     (70, 4, 2, 41.20, "hollow"),
}
## X5 (round 5): the match itself is one track in stems that build with the fight, not four beds that swap. Each
## stem: (file stem, `from` intensity or None, `states` or None, voice). Everything else about the track: FIGHT.
FIGHT = {"bpm": 120, "beats_per_bar": 4, "bars": 4, "root": 55.0,
         "states": ["lull", "skirmish", "battle", "last_stand"], "intensity": 0.6}
FIGHT_STEMS = [
    ("fight_pad", 0.0, None, "pad"),         # always: the floor under a lull
    ("fight_pulse", 0.2, None, "pulse"),     # first contact: a heartbeat kick
    ("fight_bass", 0.45, None, "bass"),      # a real fight: the driving bass
    ("fight_drums", 0.65, None, "drums"),    # a battle: snare and hats
    ("fight_alarm", None, ["last_stand"], "alarm"),  # only when it is happening to you
]
# Which MatchMood states each bed may play under (L5 names; `garage` and `pre_match` are outside a match).
STATES = {"garage": ["garage"], "pre_match": ["pre_match"], "victory": ["victory"], "defeat": ["defeat"]}
INTENSITY = {"garage": 0.1, "pre_match": 0.25, "victory": 0.7, "defeat": 0.2}
# id -> (seconds, character)
STINGERS = {
    "sting.first_blood": (2.0, "stab"),
    "sting.kill": (1.5, "hit"),
    "sting.comeback": (3.0, "swell"),
    "sting.last_unit": (3.0, "siren"),
    "sting.victory": (4.0, "fanfare"),
    "sting.defeat": (4.0, "collapse"),
}


def _saturate(x: float, drive: float = 2.0) -> float:
    return math.tanh(x * drive) / math.tanh(drive)


def _bed(bpm: int, beats_per_bar: int, bars: int, root: float, character: str, rng: random.Random) -> list[float]:
    """One seamless loop: a kick pulse train, a bass note per bar, and a pad. Deliberately plain."""
    beat_s = 60.0 / bpm
    total = int(RATE * beat_s * beats_per_bar * bars)
    out = [0.0] * total
    heavy = character in ("crush", "desperate", "drive", "triumph")
    fifth = root * 1.5
    for index in range(total):
        t = index / RATE
        beat = t / beat_s
        into_beat = beat % 1.0
        sample = 0.0
        # Kick: a pitch-dropping sine on every beat (every other beat for the slow, hollow beds).
        if character not in ("hollow", "brood") or int(beat) % 2 == 0:
            env = math.exp(-into_beat * beat_s * (22.0 if heavy else 14.0))
            pitch = 120.0 * math.exp(-into_beat * beat_s * 9.0) + 42.0
            sample += _saturate(math.sin(2 * math.pi * pitch * into_beat * beat_s) * env, 3.0) * 0.55
        # Bass: one note a bar, saturated so it carries on a laptop speaker.
        bar = int(beat / beats_per_bar)
        into_bar = (beat % beats_per_bar) * beat_s
        note = root if bar % 2 == 0 else (fifth if character != "hollow" else root * 0.94)
        bass_env = math.exp(-into_bar * (1.1 if heavy else 0.7))
        sample += _saturate(math.sin(2 * math.pi * note * t), 2.6 if heavy else 1.4) * 0.34 * bass_env
        # Pad: two detuned saws a fifth apart, slowly moving. The mids stay thin; the booth lives there.
        pad = 0.0
        for partial, weight in ((2.0, 0.5), (3.0, 0.22), (4.5, 0.12)):
            pad += math.sin(2 * math.pi * note * partial * t + math.sin(t * 0.7) * 0.6) * weight
        sample += pad * (0.16 if character in ("brood", "tension", "hollow") else 0.10)
        # A little noise texture so it isn't a pure tone.
        sample += (rng.random() - 0.5) * (0.05 if heavy else 0.02)
        out[index] = sample
    _seam(out, int(RATE * 0.02))
    return out


def _fight_stems() -> dict:
    """The fight track's stems as numpy arrays of one length, voiced so each layer is audible on its own."""
    import numpy as np
    bpm, bars, per_bar, root = FIGHT["bpm"], FIGHT["bars"], FIGHT["beats_per_bar"], FIGHT["root"]
    beat_s = 60.0 / bpm
    total = int(RATE * beat_s * per_bar * bars)
    t = np.arange(total) / RATE
    beat = t / beat_s
    into_beat = (beat % 1.0) * beat_s
    bar = (beat // per_bar).astype(int)
    notes = np.where(bar % 4 == 3, root * 1.2, np.where(bar % 2 == 1, root * 1.5, root))
    rng = np.random.default_rng(55)
    out = {}
    for name, _from, _states, voice in FIGHT_STEMS:
        if voice == "pad":
            x = sum(np.sin(2 * np.pi * notes * k * t + np.sin(t * 0.5) * 0.8) * w for k, w in ((2, 0.4), (3, 0.2), (4, 0.1)))
            x = x * 0.8
        elif voice == "pulse":
            env = np.exp(-into_beat * 16.0)
            x = np.tanh(np.sin(2 * np.pi * (110.0 * np.exp(-into_beat * 10.0) + 40.0) * into_beat) * env * 3.0) * 0.55
        elif voice == "bass":
            eighth = (beat * 2 + 0.5) % 1.0  # off the kick, so their peaks never stack
            env = np.exp(-eighth * beat_s * 0.5 * 9.0)
            x = np.tanh(np.sin(2 * np.pi * notes * t) * 2.5) * env * 0.8
        elif voice == "drums":
            backbeat = (np.floor(beat) % 2 == 1)
            snare = rng.standard_normal(total) * np.exp(-into_beat * 22.0) * backbeat * 0.7
            sixteenth = ((beat * 4) % 1.0) * beat_s / 4
            hats = np.diff(rng.standard_normal(total + 1)) * np.exp(-sixteenth * 90.0) * 0.18
            x = np.tanh((snare + hats) * 2.0) * 0.45  # noise spikes would set the whole track's level
        else:  # alarm: a slow two-note siren an octave up
            half = (beat // 2) % 2
            x = np.sin(2 * np.pi * np.where(half == 0, root * 8, root * 8 * 1.335) * t) * 0.35 * (0.6 + 0.4 * np.sin(2 * np.pi * t / beat_s))
        fade = int(RATE * 0.02)
        x = np.asarray(x, dtype=float)
        x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
        out[name] = x
    return out


def _write_np_wav(x, path: Path, scale: float) -> None:
    import numpy as np
    pcm = (np.clip(x * scale, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def build_fight(out_dir: Path, scratch: Path) -> dict:
    """Stems scaled together: the full arrangement (every stem, the alarm included) meets the loudness target and
    stays under the ceiling, so any subset of it does too."""
    import numpy as np
    stems = _fight_stems()
    mix = sum(stems.values())
    full = scratch / "fight_full.wav"
    scale = 0.89 / np.abs(mix).max()
    _write_np_wav(mix, full, scale)
    gain = TARGET_LUFS - measure(full)["lufs"]
    # No limiter can sit on a sum of stems, so the summed peak is kept under the ceiling by the gain itself (Vorbis
    # decodes a touch hot, hence the margin under the ceiling).
    gain = min(gain, PEAK_CEILING_DB - 0.7 - 20 * math.log10(0.89))
    entries = []
    for name, from_, states, _voice in FIGHT_STEMS:
        wav = scratch / (name + ".wav")
        _write_np_wav(stems[name], wav, scale)
        ogg = out_dir / (name + ".ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-af", "volume=%.2fdB" % gain,
                        "-ac", "1", "-c:a", "libvorbis", "-b:a", BITRATE, str(ogg)], check=True)
        entry = {"file": ogg.name}
        if from_ is not None:
            entry["from"] = from_
        if states is not None:
            entry["states"] = states
        entries.append(entry)
    length = len(mix) / RATE
    return {"stems": entries, "bpm": FIGHT["bpm"], "beats_per_bar": FIGHT["beats_per_bar"],
            "loop_start_s": 0.0, "loop_end_s": round(length - 0.02, 3), "intensity": FIGHT["intensity"],
            "states": FIGHT["states"], "rights": "placeholder, generated by this repo (CC0)", "placeholder": True}


def _stinger(seconds: float, character: str, rng: random.Random) -> list[float]:
    total = int(RATE * seconds)
    out = [0.0] * total
    for index in range(total):
        t = index / RATE
        frac = t / seconds
        sample = 0.0
        if character in ("stab", "hit"):
            env = math.exp(-t * (7.0 if character == "stab" else 14.0))
            sample = _saturate(math.sin(2 * math.pi * (180.0 * math.exp(-t * 6.0) + 48.0) * t), 3.5) * env
            sample += (rng.random() - 0.5) * env * 0.5
        elif character == "swell":
            env = min(1.0, frac * 2.2) * math.exp(-max(0.0, frac - 0.55) * 7.0)
            sample = math.sin(2 * math.pi * (140.0 + 320.0 * frac) * t) * env * 0.7
            sample += math.sin(2 * math.pi * 523.25 * t) * max(0.0, frac - 0.6) * 1.6 * env
        elif character == "siren":
            env = math.exp(-max(0.0, frac - 0.3) * 3.0)
            sweep = 700.0 - 480.0 * frac
            sample = math.sin(2 * math.pi * sweep * t) * env * 0.5
            sample += _saturate(math.sin(2 * math.pi * 87.31 * t), 2.5) * env * 0.5
        elif character == "fanfare":
            env = min(1.0, frac * 6.0) * math.exp(-max(0.0, frac - 0.35) * 2.4)
            for partial, weight in ((1.0, 0.5), (1.5, 0.3), (2.0, 0.22)):
                sample += _saturate(math.sin(2 * math.pi * 261.63 * partial * t), 2.0) * weight * env
            sample += (rng.random() - 0.5) * env * 0.25
        else:  # collapse
            env = math.exp(-frac * 2.6)
            sample = _saturate(math.sin(2 * math.pi * (110.0 - 70.0 * frac) * t), 3.0) * env * 0.8
            sample += (rng.random() - 0.5) * env * 0.3
        out[index] = sample
    _fade_out(out, int(RATE * 0.05))
    return out


def _seam(samples: list[float], fade: int) -> None:
    """Crossfades the loop's tail over its head so the seam is inaudible."""
    for index in range(fade):
        weight = index / fade
        head = samples[index]
        tail = samples[len(samples) - fade + index]
        samples[index] = head * weight + tail * (1.0 - weight)


def _fade_out(samples: list[float], fade: int) -> None:
    for index in range(fade):
        samples[len(samples) - fade + index] *= 1.0 - index / fade


def _write_wav(samples: list[float], path: Path) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.89 / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)


def measure(path: Path) -> dict:
    """Integrated loudness and true peak, from ffmpeg's EBU R128 meter."""
    result = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                            capture_output=True, text=True)
    text = result.stderr
    summary = text[text.rfind("Integrated loudness"):] if "Integrated loudness" in text else text
    lufs = re.search(r"I:\s*(-?\d+\.?\d*)\s*LUFS", summary)
    peak = re.search(r"Peak:\s*(-?\d+\.?\d*)\s*dBFS", summary)
    return {"lufs": float(lufs.group(1)) if lufs else 0.0, "peak_db": float(peak.group(1)) if peak else 0.0}


def encode(wav: Path, out: Path, gain_db: float) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    limit = 10 ** (LIMITER_DB / 20.0)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav),
                    "-af", "volume=%.2fdB,alimiter=limit=%.4f:attack=5:release=60:level=disabled" % (gain_db, limit),
                    "-ac", "1", "-c:a", "libvorbis", "-b:a", BITRATE, str(out)], check=True)


def build(out_dir: Path) -> dict:
    manifest = {"schema": 1,
                "note": "Placeholders from tools/audio/make_music_placeholders.py. Replace file by file with the "
                        "lead's Suno tracks (assets/music/PROMPTS.md); the director reads only this manifest.",
                "target_lufs": TARGET_LUFS, "tracks": {}, "stingers": {}}
    with tempfile.TemporaryDirectory() as scratch:
        for name, (bpm, beats_per_bar, bars, root, character) in BEDS.items():
            rng = random.Random(hash(name) & 0xffff)
            samples = _bed(bpm, beats_per_bar, bars, root, character, rng)
            wav = Path(scratch) / (name + ".wav")
            _write_wav(samples, wav)
            gain = TARGET_LUFS - measure(wav)["lufs"]
            ogg = out_dir / ("bed_%s.ogg" % name)
            encode(wav, ogg, gain)
            measured = measure(ogg)
            length = len(samples) / RATE
            manifest["tracks"][name] = {
                "file": ogg.name, "bpm": bpm, "beats_per_bar": beats_per_bar,
                # The whole file is one loop, so the loop is the whole file minus the crossfaded seam.
                "loop_start_s": 0.0, "loop_end_s": round(length - 0.02, 3),
                "intensity": INTENSITY[name], "states": STATES[name],
                "lufs": round(measured["lufs"], 1), "peak_db": round(measured["peak_db"], 1),
                "rights": "placeholder, generated by this repo (CC0)", "placeholder": True,
            }
        manifest["tracks"]["fight"] = build_fight(out_dir, Path(scratch))
        for id_, (seconds, character) in STINGERS.items():
            rng = random.Random(hash(id_) & 0xffff)
            wav = Path(scratch) / (id_.replace(".", "_") + ".wav")
            _write_wav(_stinger(seconds, character, rng), wav)
            gain = TARGET_LUFS - measure(wav)["lufs"]
            ogg = out_dir / (id_.replace(".", "_") + ".ogg")
            encode(wav, ogg, gain)
            measured = measure(ogg)
            manifest["stingers"][id_] = {"file": ogg.name, "seconds": seconds, "lufs": round(measured["lufs"], 1),
                                         "peak_db": round(measured["peak_db"], 1),
                                         "rights": "placeholder, generated by this repo (CC0)", "placeholder": True}
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path("assets/music"))
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = build(args.out)
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    total = sum(p.stat().st_size for p in args.out.glob("*.ogg"))
    print("wrote %d beds and %d stingers to %s (%.0f KB)"
          % (len(manifest["tracks"]), len(manifest["stingers"]), args.out, total / 1024))
    for name, track in manifest["tracks"].items():
        if "stems" in track:
            print("  %-11s %3d bpm  loop %.2f s  %d stems" % (name, track["bpm"], track["loop_end_s"], len(track["stems"])))
            continue
        print("  %-11s %3d bpm  loop %.2f s  %5.1f LUFS  peak %5.1f dB" % (name, track["bpm"], track["loop_end_s"],
                                                                          track["lufs"], track["peak_db"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
