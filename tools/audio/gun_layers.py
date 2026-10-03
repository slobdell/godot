#!/usr/bin/env python3
"""Round 17 G3: the gun families built in layers, as stereo takes, one folder of DIRECTIONS per sound.

    python3 tools/audio/gun_layers.py                  # every direction in assets/audio/gun_designs.json
    python3 tools/audio/gun_layers.py --only tank_boom # one sound

A shot is layers, each with its own job, summed and mastered:
  * the CRACK - the pressure front: broadband, a rise in a millisecond. What small speakers carry and what "kinetic"
    means. Generated (a close muzzle blast) and/or SYNTHESISED here as an N-wave (the shape of a real blast's
    pressure: a jump up, a ramp through zero, a jump back) with a few ms of bright noise;
  * the BODY - the 60-200 Hz punch in the chest (the generated report);
  * the SUB - 30-60 Hz, felt on a subwoofer and inaudible on a laptop, synthesised as a falling sine so its level is
    known (it must not eat a laptop's headroom: the sheet checks it);
  * the MECHANISM - breech, chain drive, links and brass (generated, quiet, a beat after the shot);
  * the TAIL - the report rolling off the arena and the terrain, in STEREO (generated). Godot's AudioStreamPlayer3D
    keeps a stereo file's width and pans it by balance (measured round 17: L/R correlation 0 at 0°, 45° and 90°), so
    a stereo take plays positionally like any other.

Sources are ElevenLabs masters named by tools/audio/sfx_generate.py from assets/audio/elevenlabs/guns_r17.json (or
sources.json). Take n of a direction uses take n of each source in turn (rotated per layer), so no two takes share
every layer. Writes assets/audio/layered/<sound>~<direction>_<n>.wav (16-bit stereo) and
game/theme/audio/sfx_directions.gd. SfxSystem.DIRECTION names the one the game plays; `--sfx-direction=` overrides it.
"""

from __future__ import annotations

import argparse
import json
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import sfx_generate  # noqa: E402
import weapon_sheet  # noqa: E402

RATE = 44100
DESIGNS = ROOT / "assets" / "audio" / "gun_designs.json"
RECIPES = [ROOT / "assets" / "audio" / "elevenlabs" / "guns_r17.json", sfx_generate.SOURCES]
LAYERED = ROOT / "assets" / "audio" / "layered"
MANIFEST = ROOT / "game" / "theme" / "audio" / "sfx_directions.gd"
CEILING_DB = -1.0


# ---- Sources -------------------------------------------------------------------------------------------------------

def recipes() -> dict:
    found = {}
    for path in RECIPES:
        if path.exists():
            for source in sfx_generate.load_sources(path)["sources"]:
                found[source["id"]] = source
    return found


def decode_stereo(path: Path) -> np.ndarray:
    import subprocess
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "2", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64).reshape(-1, 2)


def source_takes(source: dict) -> list[Path]:
    return [p for p in (sfx_generate.master_path(sfx_generate.MASTERS, source, t) for t in range(1, int(source["takes"]) + 1))
            if p.exists()]


def onsets(x: np.ndarray, min_gap_s: float = 0.07, below_db: float = 14.0) -> list[int]:
    """Where each report in a generated burst starts: peaks of the 3 ms envelope within `below_db` of the loudest,
    at least `min_gap_s` apart, walked back to where each one rises out of the one before."""
    env = weapon_sheet._envelope(weapon_sheet.mono(x), RATE, 0.003)
    floor = env.max() * 10 ** (-below_db / 20)
    gap = int(min_gap_s * RATE)
    found: list[int] = []
    i = 0
    while i < len(env):
        if env[i] >= floor:
            window = env[i: i + gap]
            peak = i + int(np.argmax(window))
            start = peak
            while start > 0 and env[start - 1] < env[start] and env[start - 1] > env[peak] * 0.1:
                start -= 1
            found.append(start)
            i = peak + gap
        else:
            i += 1
    return found


def trim_onset(x: np.ndarray, threshold_db: float = -30.0, pre_s: float = 0.002) -> np.ndarray:
    start = weapon_sheet.onset(x, RATE, threshold_db)
    return x[max(0, start - int(pre_s * RATE)):]


# ---- Synthesised layers --------------------------------------------------------------------------------------------

def synth_crack(ms: float = 2.5, bright_hz: float = 2500.0, noise_ms: float = 8.0, seed: int = 0) -> np.ndarray:
    """A blast's pressure front: an N-wave `ms` long (jump to +1, ramp to -1, jump back to 0) plus `noise_ms` of
    decaying noise above `bright_hz`, slightly different in each ear so it has a place rather than sitting inside
    the head."""
    from scipy.signal import butter, sosfilt
    rng = np.random.default_rng(seed)
    n = int(ms / 1000.0 * RATE)
    wave_ = np.concatenate([np.linspace(1.0, -1.0, max(n, 2)), np.zeros(int(0.06 * RATE))])
    t = np.arange(len(wave_)) / RATE
    out = np.zeros((len(wave_), 2))
    for ch in range(2):
        noise = sosfilt(butter(2, bright_hz, "highpass", fs=RATE, output="sos"), rng.standard_normal(len(wave_)))
        noise *= np.exp(-t / (noise_ms / 1000.0)) * 0.6
        out[:, ch] = wave_ + noise
    return out / np.abs(out).max()


def synth_sub(hz: float = 40.0, decay_s: float = 0.6, sweep: float = 1.6, seed: int = 0) -> np.ndarray:
    """A falling sine from `hz * sweep` to `hz`, decaying over `decay_s`: the weight a subwoofer adds, at a level we
    know. A 4 ms fade-in keeps it from clicking."""
    length = int(decay_s * 5 * RATE)
    t = np.arange(length) / RATE
    freq = hz * (1.0 + (sweep - 1.0) * np.exp(-t / 0.08))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    x = np.sin(phase) * np.exp(-t / decay_s) * np.minimum(1.0, t / 0.004)
    return np.repeat(x[:, None], 2, axis=1)


# ---- Composition ---------------------------------------------------------------------------------------------------

def _filters(x: np.ndarray, layer: dict) -> np.ndarray:
    from scipy.signal import butter, sosfilt
    if layer.get("highpass_hz"):
        x = sosfilt(butter(2, float(layer["highpass_hz"]), "highpass", fs=RATE, output="sos"), x, axis=0)
    if layer.get("lowpass_hz"):
        x = sosfilt(butter(2, float(layer["lowpass_hz"]), "lowpass", fs=RATE, output="sos"), x, axis=0)
    return x


def layer_signal(layer: dict, take: int, index: int, sources: dict) -> np.ndarray | None:
    """One layer of take `take` (1-based); `index` rotates which source take each layer uses."""
    if "synth" in layer:
        kind = layer["synth"]
        if kind == "crack":
            x = synth_crack(float(layer.get("ms", 2.5)), float(layer.get("bright_hz", 2500.0)),
                            float(layer.get("noise_ms", 8.0)), seed=take * 7 + index)
        elif kind == "sub":
            x = synth_sub(float(layer.get("hz", 40.0)), float(layer.get("decay_s", 0.6)), float(layer.get("sweep", 1.6)))
        else:
            raise ValueError("unknown synth layer %s" % kind)
        peak_normalised = True
    else:
        source = sources[layer["from"]]
        takes = source_takes(source)
        if layer.get("use"):
            takes = [takes[i - 1] for i in layer["use"] if i - 1 < len(takes)]  # the takes picked by ear and sheet
        if not takes:
            return None
        x = decode_stereo(takes[(take - 1 + index) % len(takes)])
        if layer.get("pair") and len(takes) > 1:
            # ElevenLabs returns effectively mono audio (width 0.00-0.02 measured, round 17, even for "wide" tails), so
            # width is made here: two different takes of the same event, one per ear, are as decorrelated as two
            # microphones far apart.
            other = decode_stereo(takes[(take + index) % len(takes)])
            if layer.get("trim_onset", True):
                x, other = trim_onset(x), trim_onset(other)
            n = min(len(x), len(other))
            x = np.stack([x[:n].mean(axis=1), other[:n].mean(axis=1)], axis=1)
        elif layer.get("slice") is not None:
            # One report cut out of a generated burst: the n-th onset (rotating with the take), `max_s` long.
            starts = onsets(x)
            if not starts:
                return None
            x = x[starts[(int(layer["slice"]) + take - 1) % len(starts)]:]
        elif layer.get("trim_onset", True):
            x = trim_onset(x)
        x = x / max(np.abs(x).max(), 1e-9)
        peak_normalised = True
    if layer.get("start_s") or layer.get("max_s"):
        start = int(float(layer.get("start_s", 0.0)) * RATE)
        end = start + int(float(layer["max_s"]) * RATE) if layer.get("max_s") else len(x)
        x = x[start:end]
    x = _filters(x, layer)
    if layer.get("fade_in_ms"):
        n = min(len(x), int(float(layer["fade_in_ms"]) / 1000.0 * RATE))
        x[:n] *= np.linspace(0.0, 1.0, n)[:, None]
    if layer.get("fade_s"):
        n = min(len(x), int(float(layer["fade_s"]) * RATE))
        x[len(x) - n:] *= np.linspace(1.0, 0.0, n)[:, None]
    if layer.get("mono"):
        x = np.repeat(x.mean(axis=1)[:, None], 2, axis=1)
    if layer.get("width") is not None:
        mid, side = (x[:, 0] + x[:, 1]) / 2, (x[:, 0] - x[:, 1]) / 2
        side *= float(layer["width"])
        x = np.stack([mid + side, mid - side], axis=1)
    x = x * 10 ** (float(layer.get("gain_db", 0.0)) / 20)
    delay = int(float(layer.get("delay_ms", 0.0)) / 1000.0 * RATE)
    if delay:
        x = np.concatenate([np.zeros((delay, 2)), x])
    assert peak_normalised
    return x


def limit_stereo(x: np.ndarray, ceiling_db: float = CEILING_DB, release_s: float = 0.12, look_ms: float = 1.5) -> np.ndarray:
    """A linked look-ahead limiter on the 4x-oversampled peak: the gain reaches its floor before the peak arrives, so
    the crack's first millisecond is turned down whole, never clipped flat."""
    from scipy.ndimage import maximum_filter1d
    from scipy.signal import lfilter, resample_poly
    ceiling = 10 ** (ceiling_db / 20)
    over = np.abs(resample_poly(x, 4, 1, axis=0)).max(axis=1)
    peak = over.reshape(-1, 4).max(axis=1)[: len(x)]
    if len(peak) < len(x):
        peak = np.concatenate([peak, np.zeros(len(x) - len(peak))])
    needed = np.minimum(1.0, ceiling / np.maximum(peak, 1e-12))
    look = max(1, int(look_ms / 1000.0 * RATE))
    held = -maximum_filter1d(-needed, size=2 * look + 1)
    a = np.exp(-1.0 / (release_s * RATE))
    smoothed = lfilter([1 - a], [1, -a], held, zi=[held[0] * a])[0]
    gain = np.minimum(held, smoothed)
    return x * gain[:, None]


def slaps(dry: np.ndarray, reflections: list, seed: int = 0) -> np.ndarray:
    """The shot coming back off the arena: each reflection [delay ms, gain dB, pan -1..1] is the dry shot delayed,
    dulled (walls and distance eat the top) and placed left or right, a few ms apart in each ear so it has width."""
    from scipy.signal import butter, sosfilt
    rng = np.random.default_rng(seed)
    mono_dry = sosfilt(butter(2, 3500.0, "lowpass", fs=RATE, output="sos"), dry.mean(axis=1))
    longest = max(int(float(r[0]) / 1000.0 * RATE) for r in reflections) + len(mono_dry) + 64
    out = np.zeros((longest, 2))
    for delay_ms, gain_db, pan in reflections:
        jitter = rng.uniform(-0.04, 0.04)
        pan = float(np.clip(pan + jitter, -1.0, 1.0))
        g = 10 ** (float(gain_db) / 20)
        left, right = g * np.cos((pan + 1) * np.pi / 4), g * np.sin((pan + 1) * np.pi / 4)
        start = int(float(delay_ms) / 1000.0 * RATE)
        spread = int(abs(pan) * 0.0006 * RATE)  # the far ear hears it a little later
        out[start + (spread if pan > 0 else 0): start + (spread if pan > 0 else 0) + len(mono_dry), 0] += left * mono_dry
        out[start + (spread if pan < 0 else 0): start + (spread if pan < 0 else 0) + len(mono_dry), 1] += right * mono_dry
    return out


def compose(design: dict, take: int, sources: dict) -> np.ndarray:
    parts = []
    dry_parts = []
    for index, layer in enumerate(design["layers"]):
        x = layer_signal(layer, take, index, sources)
        if x is not None:
            parts.append(x)
            if layer.get("dry", "synth" in layer and layer["synth"] == "crack" or layer.get("body", False)):
                dry_parts.append(x)
    if design.get("slaps") and dry_parts:
        dry = np.zeros((max(len(p) for p in dry_parts), 2))
        for p in dry_parts:
            dry[:len(p)] += p
        parts.append(slaps(dry, design["slaps"], seed=take))
    length = int(float(design.get("length_s", 0)) * RATE) or max(len(p) for p in parts)
    mix = np.zeros((length, 2))
    for p in parts:
        n = min(length, len(p))
        mix[:n] += p[:n]
    # The whole take: true peak to the ceiling (gain up or down), so every direction is mastered alike and the
    # sheet and the mix compare like with like. A short fade so a long tail never ends on a step.
    peak = np.abs(mix).max()
    mix *= 10 ** (CEILING_DB / 20) / max(peak, 1e-9) * 10 ** (float(design.get("drive_db", 0.0)) / 20)
    if design.get("target_lufs") is not None:
        # Every take of a rapid sound at one loudness (a burst's rounds must not jump 11 dB between takes, as sliced
        # rounds did), the limiter taking whatever peak that leaves over the ceiling.
        for _ in range(3):  # the limiter takes some back from a high-crest take: scale, limit, measure again
            mix = limit_stereo(mix * 10 ** ((float(design["target_lufs"]) - weapon_sheet.momentary_max_lufs(mix, RATE)) / 20))
    mix = limit_stereo(mix)
    fade = min(length, int(float(design.get("fade_s", 0.3)) * RATE))
    mix[length - fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    return mix


def compose_loop(design: dict, take: int, sources: dict) -> np.ndarray:
    """A held gun as a seamless stereo loop. The first layer is the bed (a generated burst, its steadiest stretch);
    on every round found in it go an N-wave crack and a short chest thump (`per_round`), so each round has the weight
    and the snap the generated burst lacks; further layers (the mechanism) run underneath; the arena's slaps are
    folded around the loop so they continue across the seam; the seam is crossfaded."""
    import sfx_layer
    length = int(float(design["loop_s"]) * RATE)
    bed_layer = design["layers"][0]
    source = sources[bed_layer["from"]]
    takes = source_takes(source)
    if bed_layer.get("use"):
        takes = [takes[i - 1] for i in bed_layer["use"] if i - 1 < len(takes)]
    def steady_of(path: Path) -> np.ndarray:
        raw = decode_stereo(path).mean(axis=1)
        steady = sfx_layer.longest_active(raw)[int(0.15 * RATE):]
        if len(steady) < length:
            steady = np.tile(steady, int(np.ceil(length / max(len(steady), 1))) + 1)
        return _filters(steady[:length + int(0.05 * RATE)], bed_layer)

    left = steady_of(takes[(take - 1) % len(takes)])
    # A bed that is a place rather than a gun (a fire) takes a second take for the other ear: true width.
    right = steady_of(takes[take % len(takes)]) if bed_layer.get("pair") and len(takes) > 1 else left
    mix = np.stack([left, right], axis=1)
    mix = mix / max(np.abs(mix).max(), 1e-9) * 10 ** (float(bed_layer.get("gain_db", 0.0)) / 20)
    rounds = design.get("per_round", {})
    if rounds:
        starts = [s for s in onsets(mix, min_gap_s=float(rounds.get("min_gap_s", 0.06)), below_db=float(rounds.get("below_db", 12.0)))
                  if s < length]
        crack = synth_crack(float(rounds.get("crack_ms", 1.0)), float(rounds.get("bright_hz", 2500.0)),
                            float(rounds.get("noise_ms", 5.0)), seed=take)
        thump = synth_sub(float(rounds.get("thump_hz", 70.0)), float(rounds.get("thump_decay_s", 0.05)), 1.8)
        for i, start in enumerate(starts):
            level = 10 ** ((float(rounds.get("crack_db", -6.0)) + np.random.default_rng(take * 100 + i).uniform(-1.5, 1.5)) / 20)
            for part, gain in ((crack, level), (thump, 10 ** (float(rounds.get("thump_db", -10.0)) / 20))):
                n = min(len(part), len(mix) - start)
                mix[start:start + n] += part[:n] * gain
        design.setdefault("_rounds", []).append(len(starts))
    for index, layer in enumerate(design["layers"][1:], start=1):
        x = layer_signal(layer, take, index, sources)
        if x is None:
            continue
        x = np.tile(x, (int(np.ceil(len(mix) / max(len(x), 1))) + 1, 1))[: len(mix)]
        mix += x
    if design.get("slaps"):
        echoes = slaps(mix, design["slaps"], seed=take)
        overflow = echoes[len(mix):]
        echoes = echoes[: len(mix)].copy()
        echoes[: len(overflow)] += overflow[: len(mix)]  # the echoes of the loop's end land on its start
        mix = mix + echoes
    mix = mix[:length + int(0.03 * RATE)]
    mix = np.stack([sfx_layer.loop_seam(mix[:, c]) for c in range(2)], axis=1)
    mix *= 10 ** (CEILING_DB / 20) / max(np.abs(mix).max(), 1e-9)
    if design.get("target_lufs") is not None:
        for _ in range(3):
            mix = limit_stereo(mix * 10 ** ((float(design["target_lufs"]) - weapon_sheet.momentary_max_lufs(mix, RATE)) / 20))
    return limit_stereo(mix)


def write_stereo(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def take_path(sound: str, direction: str, take: int) -> Path:
    return LAYERED / ("%s~%s_%d.wav" % (sound, direction, take))


def write_manifest(designs: dict, built: dict) -> None:
    lines = ["class_name SfxDirections",
             "## GENERATED by tools/audio/gun_layers.py from assets/audio/gun_designs.json: do not edit. Round 17 (G3):",
             "## each sound's DIRECTIONS - the same sound designed more than one way, in layers, as stereo takes - for",
             "## the lead's ear on the audition page. SfxSystem.DIRECTION picks the one the game plays.", "",
             "const TAKES := {"]
    for sound in sorted(built):
        inner = ", ".join('"%s": [%s]' % (d, ", ".join('"res://%s"' % p.relative_to(ROOT) for p in paths))
                          for d, paths in sorted(built[sound].items()))
        lines.append('\t"%s": {%s},' % (sound, inner))
    lines += ["}", "", "## sound -> direction -> what it is, in a line (the page shows it).", "const LABELS := {"]
    for sound in sorted(built):
        inner = ", ".join('"%s": "%s"' % (d, designs[sound]["directions"][d]["label"].replace('"', "'"))
                          for d in sorted(built[sound]))
        lines.append('\t"%s": {%s},' % (sound, inner))
    lines.append("}")
    MANIFEST.write_text("\n".join(lines) + "\n")


def existing(designs: dict) -> dict:
    built: dict = {}
    for sound, entry in designs.items():
        for direction, design in entry["directions"].items():
            paths = [take_path(sound, direction, n) for n in range(1, int(design["takes"]) + 1)]
            if all(p.exists() for p in paths):
                built.setdefault(sound, {})[direction] = paths
    return built


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--only", default="", help="comma-separated sounds or sound~direction")
    parser.add_argument("--report", default=str(ROOT / "build" / "audio" / "gun_layers.json"))
    args = parser.parse_args(argv)
    designs = json.loads(DESIGNS.read_text())
    designs.pop("about", None)
    sources = recipes()
    only = {s for s in args.only.split(",") if s}
    report = {}
    for sound, entry in designs.items():
        for direction, design in entry["directions"].items():
            if only and sound not in only and "%s~%s" % (sound, direction) not in only:
                continue
            missing = [layer["from"] for layer in design["layers"] if "from" in layer and not source_takes(sources[layer["from"]])]
            if missing:
                print("skip %s~%s: no masters for %s" % (sound, direction, ", ".join(sorted(set(missing)))))
                continue
            for take in range(1, int(design["takes"]) + 1):
                x = compose_loop(design, take, sources) if design.get("loop") else compose(design, take, sources)
                path = take_path(sound, direction, take)
                write_stereo(path, x)
                row = weapon_sheet.measure(x, RATE)
                report.setdefault("%s~%s" % (sound, direction), []).append(row)
                print("%s~%s take %d: %.2f s, attack %.1f ms, crest %.1f dB, M max %.1f LUFS, crack %.1f dB, "
                      "<80 Hz %.0f%%, > 2 kHz %.0f%%, tail %.1f s, width %.2f" % (
                          sound, direction, take, row["seconds"], row["attack_ms"], row["crest_db"],
                          row["momentary_max_lufs"], row["crack_db"], 100 * (row["bands"]["<40"] + row["bands"]["40-80"]),
                          100 * (row["bands"]["2k-6k"] + row["bands"][">6k"]), row["tail_s"], row["width"]))
    write_manifest(designs, existing(designs))
    # Loops import as 16-bit PCM or their loop points land a fifth of the way in (orientation trip-up 74); the
    # .import exists only after the first import, so `make sfx-layer`'s second import (or this run's) applies it.
    import sfx_layer
    for changed in sfx_layer.keep_loops_uncompressed(LAYERED):
        print("loop import set to PCM:", changed.name)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
