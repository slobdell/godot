#!/usr/bin/env python3
"""Turns ElevenLabs masters into the takes the game ships: generated body + synthesised transient, mastered.

    python3 tools/audio/sfx_layer.py                   # every source whose masters exist
    python3 tools/audio/sfx_layer.py --only tank_boom  # one sound (a source id or an SfxSystem sound)

For each take of each source in assets/audio/elevenlabs/sources.json:
1. decode the master to mono float, trim the silence before its onset (generated effects rarely start on time,
   and a shot that sounds 40 ms after its muzzle flash reads as lag);
2. high-pass the sub-sonic rumble that eats headroom and no speaker plays;
3. **speaker translation:** the generated booms put ~97% of their energy under 200 Hz, which a laptop or a phone
   simply does not reproduce, so the low band is saturated in parallel into 150-1500 Hz harmonics the ear reads as
   the same weight (the missing-fundamental effect);
4. lay the first few milliseconds of the existing synthesised take on top: its crack is designed and tight, and it
   keeps the family resemblance with the sounds the lead already knows;
5. match loudness to the synthesised take the mix was tuned against, plus a per-source `gain_db` for the cinematic
   exaggeration the lead asked for, so SfxSystem.MIX still means what it meant;
6. peak-limit to -1 dBFS, fade the tail, and write 16-bit mono WAV (QOA-imported one-shots are the cheapest thing to
   start in a battle; loops import as PCM so their loop points are right).

Writes assets/audio/layered/<sound>_<n>.wav and game/theme/audio/sfx_layers.gd, the manifest SfxSystem loads
(a script constant, so exports need no include_filter entry and nothing is probed on disk at runtime).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import sfx_generate  # noqa: E402

AUDIO = ROOT / "assets" / "audio"
LAYERED = AUDIO / "layered"
MANIFEST = ROOT / "game" / "theme" / "audio" / "sfx_layers.gd"
RATE = 44100
CEILING_DB = -1.0
## A master whose own peak is under this is a failed generation, not a quiet sound: levelling it up ships amplified
## MP3 noise. The batch had two (bullet_on_steel take 3 at -25 dBFS, mg_single take 3 at -32 with half the file
## "active", i.e. noise). They are refused, and `make sfx-generate` re-rolls a take whose master is deleted.
MIN_MASTER_PEAK_DB = -20.0

## Per-source defaults; a source's "layer" object overrides any of them.
DEFAULTS = {
    "transient_ms": 90.0,      # how much of the synthesised take lays on top (0 = none)
    "transient_db": -4.0,      # its level against the body
    "harmonics_db": -9.0,      # the saturated low band's level (None = off)
    "highpass_hz": 32.0,
    "max_s": None,             # trim the body to this length (None = keep it all)
    "fade_s": 0.25,            # the tail's fade out
    "gain_db": 0.0,            # louder than the synthesised take it replaces
    "tail_lift_db": 0.0,       # raise the decay by up to this much: the rolling tail the lead asked for
    "sub_db": None,            # a synthesised low body under the take, at this level (None = none)
    "sub_hz": 55.0,            # where that body sits
    "seam_s": 0.03,            # a loop's crossfade at its seam (a crowd bed's texture wants seconds, not ms)
    "level_s": None,           # ride a bed's gain steady over this window (None = leave its swells)
}


def decode(path: Path, rate: int = RATE) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def envelope(x: np.ndarray, window_s: float = 0.005, rate: int = RATE) -> np.ndarray:
    return np.sqrt(np.maximum(moving_mean(x * x, max(1, int(window_s * rate)), same=True), 0.0))


def moving_mean(x: np.ndarray, n: int, same: bool = False) -> np.ndarray:
    """A running mean by cumulative sum: O(N), where np.convolve with a 400 ms window was minutes per take."""
    padded = np.concatenate([[0.0], np.cumsum(x)])
    valid = (padded[n:] - padded[:-n]) / n
    if not same:
        return valid
    head = (n - 1) // 2
    return np.concatenate([np.full(head, valid[0]), valid, np.full(len(x) - len(valid) - head, valid[-1])])


## Loops (round 6): where a loop's sound starts and ends, relative to its peak, and the longest dip allowed inside it.
LOOP_ONSET_DB = -24.0
MAX_LOOP_DIP_S = 0.25
MIN_LOOP_S = 1.2


def longest_active(x: np.ndarray, below_db: float = 12.0, rate: int = RATE) -> np.ndarray:
    """The longest stretch of `x` with no dip longer than MAX_LOOP_DIP_S (10 ms frames against the median level)."""
    hop = rate // 100
    frames = len(x) // hop
    level = 20 * np.log10(np.sqrt((x[: frames * hop].reshape(frames, hop) ** 2).mean(axis=1)) + 1e-9)
    quiet = level < np.median(level) - below_db
    allowed = int(MAX_LOOP_DIP_S * 100)
    best = (0, 0)
    start = 0
    run = 0
    for i, q in enumerate(quiet):
        run = run + 1 if q else 0
        if run > allowed:
            start = i + 1
            continue
        if not q and i + 1 - start > best[1] - best[0]:
            best = (start, i + 1)
    return x[best[0] * hop: best[1] * hop]


def longest_dip(x: np.ndarray, below_db: float = 12.0, rate: int = RATE) -> float:
    """The longest stretch (s) whose 10 ms level sits more than `below_db` under the take's median level."""
    hop = rate // 100
    frames = len(x) // hop
    if frames == 0:
        return 0.0
    level = 20 * np.log10(np.sqrt((x[: frames * hop].reshape(frames, hop) ** 2).mean(axis=1)) + 1e-9)
    quiet = level < np.median(level) - below_db
    best = run = 0
    for q in quiet:
        run = run + 1 if q else 0
        best = max(best, run)
    return best * hop / rate


def trim_onset(x: np.ndarray, threshold_db: float = -36.0, pre_s: float = 0.004, rate: int = RATE) -> np.ndarray:
    """Drops what comes before the sound starts (relative to its own peak), keeping a few ms of pre-roll."""
    env = envelope(x, rate=rate)
    if env.max() <= 0:
        return x
    start = int(np.argmax(env > env.max() * 10 ** (threshold_db / 20)))
    return x[max(0, start - int(pre_s * rate)):]


def highpass(x: np.ndarray, cutoff_hz: float, rate: int = RATE) -> np.ndarray:
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(2, cutoff_hz, "highpass", fs=rate, output="sos"), x)


def bandpass(x: np.ndarray, low: float, high: float, rate: int = RATE) -> np.ndarray:
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(2, [low, high], "bandpass", fs=rate, output="sos"), x)


def harmonics(x: np.ndarray, rate: int = RATE) -> np.ndarray:
    """The low band driven into tanh and band-limited to where small speakers work: weight you can hear on a laptop."""
    low = bandpass(x, 30.0, 220.0, rate)
    peak = np.abs(low).max()
    if peak <= 0:
        return np.zeros_like(x)
    driven = np.tanh(low / peak * 6.0)
    return bandpass(driven, 150.0, 1500.0, rate)


def sub_body(x: np.ndarray, hz: float, rate: int = RATE) -> np.ndarray:
    """A low body under a sound that has none: a decaying sine at `hz`, shaped by the take's own envelope and
    pitched down a little as it decays, the way a real impact's body does. Generated energy weapons come back as
    all crack and hiss (2-4% of their energy below 200 Hz); this is what makes one land in the chest."""
    env = envelope(x, 0.02)
    if env.max() <= 0:
        return np.zeros_like(x)
    env = env / env.max()
    t = np.arange(len(x)) / rate
    decay = np.exp(-t * 2.2)
    sweep = hz * (1.0 + 0.35 * np.exp(-t * 9.0))  # a touch higher at the strike, settling: weight, not a sweep
    phase = 2 * np.pi * np.cumsum(sweep) / rate
    return np.tanh(np.sin(phase) * 1.6) * env * decay


def loudness_db(x: np.ndarray, rate: int = RATE) -> float:
    """The loudest 400 ms (RMS, dBFS) of what a laptop or phone speaker actually plays (above ~120 Hz): how loud a
    one-shot *feels* at its moment, measured the same way on both sides of a comparison, which is all it is for.
    Unweighted, a generated cannon (86% of its energy under 150 Hz) "matched" the synthesised one and then played
    several dB quieter on every speaker the lead owns."""
    n = min(len(x), int(0.4 * rate))
    if n == 0:
        return -120.0
    x = highpass(x, 120.0, rate)
    power = moving_mean(x * x, n)
    return 10.0 * np.log10(max(power.max(), 1e-12))


def limit(x: np.ndarray, ceiling_db: float = CEILING_DB, release_s: float = 0.08, rate: int = RATE) -> np.ndarray:
    """A look-ahead peak limiter: gain never lets a sample past the ceiling, recovers smoothly afterwards."""
    from scipy.ndimage import maximum_filter1d
    from scipy.signal import lfilter
    ceiling = 10 ** (ceiling_db / 20)
    look = int(0.002 * rate)
    needed = np.minimum(1.0, ceiling / np.maximum(np.abs(x), 1e-12))
    held = -maximum_filter1d(-needed, size=2 * look + 1)  # the minimum gain in the look-ahead window
    a = np.exp(-1.0 / (release_s * rate))
    # Attack instantly (take the lower of the held gain and the smoothed one), release slowly.
    smoothed = lfilter([1 - a], [1, -a], held, zi=[held[0] * a])[0]
    gain = np.minimum(held, smoothed)
    return np.clip(x * gain, -ceiling, ceiling)


def lift_tail(x: np.ndarray, lift_db: float, rate: int = RATE) -> np.ndarray:
    """Compresses the decay after the peak by half, up to `lift_db`: the body stays where it is and the rolling tail
    comes up to meet it. A generated boom falls 30 dB in a third of a second; a cinematic one rumbles on."""
    if lift_db <= 0 or len(x) < rate // 10:
        return x
    env = np.sqrt(np.maximum(moving_mean(x * x, int(0.05 * rate), same=True), 1e-12))
    peak_at = int(np.argmax(env))
    below_db = 20 * np.log10(env / env[peak_at])
    gain_db = np.clip(-below_db * 0.5, 0.0, lift_db)
    ramp = np.clip((np.arange(len(x)) - peak_at - int(0.06 * rate)) / (0.25 * rate), 0.0, 1.0)
    gain_db = moving_mean(gain_db * ramp, int(0.03 * rate), same=True)
    return x * 10 ** (gain_db / 20)


def fade_tail(x: np.ndarray, fade_s: float, rate: int = RATE) -> np.ndarray:
    n = min(len(x), int(fade_s * rate))
    if n > 1:
        x = x.copy()
        x[-n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
    return x


def ride_level(x: np.ndarray, window_s: float, max_db: float = 9.0, rate: int = RATE) -> np.ndarray:
    """A slow gain rider: the level over `window_s` is held at the take's median, by at most `max_db` either way.
    Anything faster than the window (a shout, a clap) keeps its shape; the drift a bed was asked not to have goes."""
    level = np.sqrt(np.maximum(moving_mean(x * x, max(1, int(window_s * rate)), same=True), 1e-12))
    gain = np.clip(np.median(level) / level, 10 ** (-max_db / 20), 10 ** (max_db / 20))
    return x * gain


def loop_seam(x: np.ndarray, crossfade_s: float = 0.03, rate: int = RATE) -> np.ndarray:
    """Folds the last few ms over the first so the loop point never clicks (equal-power)."""
    n = min(len(x) // 4, int(crossfade_s * rate))
    if n < 2:
        return x
    t = np.linspace(0, np.pi / 2, n)
    head = x[:n] * np.sin(t) + x[-n:] * np.cos(t)
    return np.concatenate([head, x[n:-n]])


def seam_jump(x: np.ndarray) -> float:
    """How big the step is from the last sample back to the first, against the signal's typical step."""
    steps = np.abs(np.diff(x))
    typical = np.percentile(steps, 99) if len(steps) else 1.0
    return float(abs(x[0] - x[-1]) / max(typical, 1e-9))


def synth_take(sound: str, take: int) -> Path | None:
    """The synthesised file this take layers onto (takes cycle through what exists)."""
    candidates = [AUDIO / ("%s.wav" % sound)] + sorted(AUDIO.glob("%s_[0-9].wav" % sound))
    candidates = [c for c in candidates if c.exists()]
    return candidates[(take - 1) % len(candidates)] if candidates else None


def build_take(master: Path, source: dict, take: int) -> tuple[np.ndarray, dict]:
    settings = dict(DEFAULTS, **source.get("layer", {}))
    loop = bool(source.get("loop", False))
    body = decode(master)
    raw_peak_db = 20 * np.log10(max(np.abs(body).max(), 1e-9))
    if raw_peak_db < MIN_MASTER_PEAK_DB:
        raise ValueError("%s peaks at %.1f dBFS: a failed generation (delete it and make sfx-generate re-rolls it)"
                         % (master.name, raw_peak_db))
    if loop:
        # Round 6: a loop starts on its sound (a generated take's quiet lead-in was a silence on every repeat), and a
        # loop with a hole in it is a gun that stutters: refused, like a near-silent master (delete it to re-roll).
        body = trim_onset(body, threshold_db=LOOP_ONSET_DB)
        body = trim_onset(body[::-1], threshold_db=LOOP_ONSET_DB)[::-1]
        if longest_dip(body) > MAX_LOOP_DIP_S:
            # Generated "unbroken" bursts often pause: keep the longest stretch without a hole, if it is long enough
            # to loop without the repeat showing.
            body = longest_active(body)
            if len(body) / RATE < MIN_LOOP_S:
                raise ValueError("%s: no stretch of %.1f s without a hole to loop (delete it and make sfx-generate "
                                 "re-rolls it)" % (master.name, MIN_LOOP_S))
    else:
        body = trim_onset(body)
    if settings["max_s"]:
        body = body[: int(float(settings["max_s"]) * RATE)]
    body = highpass(body, float(settings["highpass_hz"]))
    if settings["level_s"]:
        body = ride_level(body, float(settings["level_s"]))
    mixed = body.copy()
    if settings["harmonics_db"] is not None:
        mixed += harmonics(body) * np.abs(body).max() * 10 ** (float(settings["harmonics_db"]) / 20)
    if settings["sub_db"] is not None:
        mixed += sub_body(body, float(settings["sub_hz"])) * np.abs(mixed).max() * 10 ** (float(settings["sub_db"]) / 20)
    synth_path = synth_take(source["sound"], take)
    reference = decode(synth_path) if synth_path else None
    if reference is not None and not loop and float(settings["transient_ms"]) > 0:
        n = min(len(reference), int(float(settings["transient_ms"]) / 1000 * RATE))
        transient = reference[:n] * np.cos(np.linspace(0, np.pi / 2, n)) ** 2
        # The transient sits at the body's peak level, then the offset: a designed crack on a generated weight.
        scale = np.abs(mixed).max() / max(np.abs(transient).max(), 1e-9) * 10 ** (float(settings["transient_db"]) / 20)
        mixed[:n] += transient * scale
    if not loop:
        mixed = lift_tail(mixed, float(settings["tail_lift_db"]))
        mixed = fade_tail(mixed, float(settings["fade_s"]))
    if loop:
        # Folded before levelling: a crossfade after the limiter summed two limited stretches back over the ceiling.
        mixed = loop_seam(mixed, float(settings["seam_s"]))
    target = (loudness_db(reference) if reference is not None else -14.0) + float(settings["gain_db"])
    # The limiter takes loudness away from the peaky ones, so gain up and limit again until the take lands (a few
    # passes; each one converges most of the remaining gap, and 6 dB of extra drive is the most it may add).
    unlimited = mixed * 10 ** ((target - loudness_db(mixed)) / 20)
    drive = 0.0
    for _ in range(4):
        mixed = limit(unlimited * 10 ** (drive / 20))
        short = target - loudness_db(mixed)
        if short < 0.3 or drive >= 6.0:
            break
        drive = min(6.0, drive + short)
    report = {"sound": source["sound"], "take": take, "master": master.name, "seconds": round(len(mixed) / RATE, 3),
              "loudness_db": round(loudness_db(mixed), 1), "target_db": round(target, 1),
              "peak_db": round(20 * np.log10(max(np.abs(mixed).max(), 1e-9)), 2),
              "synth": synth_path.name if synth_path else None}
    if loop:
        report["seam_jump"] = round(seam_jump(mixed), 2)
    return mixed, report


def write_wav(path: Path, x: np.ndarray, rate: int = RATE) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(pcm.tobytes())


def write_take(x: np.ndarray, sound: str, take: int, loop: bool, out: Path) -> Path:
    """Every take is a 16-bit mono WAV. One-shots import as QOA (cheap to start), loops as PCM (see
    keep_loops_uncompressed). Ogg Vorbis was tried first and measured: starting an Ogg one-shot cost ~0.2 ms more
    script time per shot than a WAV (make audio-bench), because each play builds a Vorbis decoder, and a battle
    starts several a frame."""
    out.mkdir(parents=True, exist_ok=True)
    path = out / ("%s_%d.wav" % (sound, take))
    write_wav(path, x)
    stale = out / ("%s_%d.ogg" % (sound, take))
    for old in (stale, stale.with_name(stale.name + ".import")):
        if old.exists():
            old.unlink()
    return path


def loop_sounds(data: dict) -> set:
    """The SfxSystem sounds the recipe builds as loops (the crowd's bed is one without "loop" in its name)."""
    return {source["sound"] for source in data.get("sources", []) if source.get("loop", False)}


def keep_loops_uncompressed(folder: Path, sounds: set = frozenset()) -> list[Path]:
    """Loops must import as plain 16-bit PCM. The engine, crowd, flame and gunfire code set `loop_end` to
    `data.size() / 2`, which counts frames only for PCM: on a QOA-compressed import (Godot's default, compress/mode=2)
    it lands a fifth of the way in, and every loop in the game was repeating its first 0.2 s (found round 5).
    Returns the .import files it changed; Godot reimports them on the next `make import`."""
    changed = []
    for wav in sorted(folder.glob("*.wav")):
        if "loop" not in wav.name and wav.stem.rsplit("_", 1)[0] not in sounds:
            continue
        settings = wav.with_name(wav.name + ".import")
        if not settings.exists():
            continue
        text = settings.read_text()
        if "compress/mode=0" not in text:
            import re
            settings.write_text(re.sub(r"compress/mode=\d+", "compress/mode=0", text))
            changed.append(settings)
    return changed


def write_manifest(pools: dict, path: Path = MANIFEST) -> None:
    lines = ["class_name SfxLayers",
             "## GENERATED by tools/audio/sfx_layer.py: do not edit. The shipped takes per SfxSystem sound, built from",
             "## ElevenLabs source material layered with the synthesised transients (assets/audio/elevenlabs/sources.json).",
             "## A sound listed here plays these takes instead of its synthesised ones.", "",
             "const TAKES := {"]
    for sound in sorted(pools):
        files = ", ".join('"res://%s"' % p for p in pools[sound])
        lines.append('\t"%s": [%s],' % (sound, files))
    lines.append("}")
    path.write_text("\n".join(lines) + "\n")


def existing_pools(out: Path) -> dict:
    pools: dict = {}
    for path in sorted(out.glob("*_[0-9]*.*")):
        if path.suffix not in (".ogg", ".wav"):
            continue
        sound = path.stem.rsplit("_", 1)[0]
        pools.setdefault(sound, []).append("assets/audio/layered/" + path.name)
    for sound in pools:
        pools[sound].sort(key=lambda p: int(Path(p).stem.rsplit("_", 1)[1]))
    return pools


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sources", type=Path, default=sfx_generate.SOURCES)
    parser.add_argument("--masters", type=Path, default=sfx_generate.MASTERS)
    parser.add_argument("--out", type=Path, default=LAYERED)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--only", default="")
    parser.add_argument("--report", type=Path, default=None, help="write the per-take numbers as JSON")
    args = parser.parse_args(argv)
    data = sfx_generate.load_sources(args.sources)
    only = {s for s in args.only.split(",") if s} or None
    reports = []
    refusals = 0
    for request in sfx_generate.requests(data, only):
        source, take = request["source"], request["take"]
        master = sfx_generate.master_path(args.masters, source, take)
        if not master.exists():
            continue
        try:
            mixed, report = build_take(master, source, take)
        except ValueError as refused:
            print("REFUSED " + str(refused))
            refusals += 1
            # A take built earlier from this master must not keep shipping.
            for stale in args.out.glob("%s_%d.*" % (source["sound"], take)):
                stale.unlink()
            continue
        written = write_take(mixed, source["sound"], take, bool(source.get("loop", False)), args.out)
        report["file"] = written.name
        report["bytes"] = written.stat().st_size
        reports.append(report)
        print("%-18s take %d  %5.2f s  %6.1f dB (target %6.1f)  peak %5.1f dBFS  %s%s" % (
            report["sound"], take, report["seconds"], report["loudness_db"], report["target_db"], report["peak_db"],
            written.name, ("  seam %.2f" % report["seam_jump"]) if "seam_jump" in report else ""))
    write_manifest(existing_pools(args.out), args.manifest)
    for settings in keep_loops_uncompressed(args.out, loop_sounds(data)):
        print("loop import set to PCM: %s (run make import)" % settings.name)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(reports, indent=1))
    print("%d takes layered; manifest %s" % (len(reports), args.manifest.relative_to(ROOT) if args.manifest.is_relative_to(ROOT) else args.manifest))
    return 1 if refusals else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
