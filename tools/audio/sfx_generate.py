#!/usr/bin/env python3
"""Sound-effect source material from ElevenLabs: prompts in, MP3 masters out, every paid request in the ledger.

    python3 tools/audio/sfx_generate.py --dry-run                     # what would be sent and roughly what it costs
    python3 tools/audio/sfx_generate.py --mock --masters build/sfx/m  # the whole path, no credits
    python3 tools/audio/sfx_generate.py --approved [--only tank_boom] # real requests (lead gate 1, approved round 5)

The recipe for every source lives in assets/audio/elevenlabs/sources.json: which SfxSystem sound it layers under, the
prompt, how long, how many takes. A take is one request; its master is named after a hash of everything that shaped
it (prompt, duration, influence, loop, model, take number), so an unchanged recipe is never paid for twice and an
edited prompt is a fresh generation rather than a silent reuse of the old one.

Masters are git-ignored inputs (like the announcer's): tools/audio/sfx_layer.py turns them into the shipped takes,
and re-mixing costs nothing as long as they survive (backups.md).
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import os
import struct
import subprocess
import sys
import time
import wave
import io
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCES = ROOT / "assets" / "audio" / "elevenlabs" / "sources.json"
MASTERS = ROOT / "assets" / "audio" / "elevenlabs" / "masters"
LEDGER = ROOT / "assets" / "audio" / "elevenlabs" / "ledger.md"

MODEL_ID = "eleven_text_to_sound_v2"
OUTPUT_FORMAT = "mp3_44100_128"
KEY_ENVS = ("ELEVENLABS_API_KEY", "ELEVENLABS_KEY_ID")
KEY_PREFIX = "sk_"
## Only a planning number for dry runs: ElevenLabs bills sound effects by generated duration (the pilot measured
## ~10 credits per second: 230 for 23 s). The ledger records the
## real spend from the account's balance before and after, and that is the number to trust.
ESTIMATED_CREDITS_PER_SECOND = 10.0
REQUEST_TIMEOUT_S = 180.0
RETRY_DELAYS_S = (2.0, 6.0, 15.0, 40.0)
RETRY_ON = ("timeout", "timed out", "connection", "temporarily", "too many requests", "429",
            "500", "502", "503", "504", "internal server error", "bad gateway", "service unavailable")


def load_sources(path: Path = SOURCES) -> dict:
    data = json.loads(path.read_text())
    problems = validate(data)
    if problems:
        raise ValueError("sources.json: " + "; ".join(problems))
    return data


def validate(data: dict) -> list[str]:
    """What is wrong with a recipe file, as sentences (empty when it is fine)."""
    problems = []
    seen = set()
    for source in data.get("sources", []):
        sid = source.get("id", "?")
        if sid in seen:
            problems.append("%s appears twice" % sid)
        seen.add(sid)
        for field in ("id", "sound", "prompt", "duration_s", "takes"):
            if field not in source:
                problems.append("%s has no %s" % (sid, field))
        duration = float(source.get("duration_s", 0))
        if not 0.5 <= duration <= 30.0:
            problems.append("%s: duration_s %.2f is outside the API's 0.5-30 s" % (sid, duration))
        influence = float(source.get("prompt_influence", 0.3))
        if not 0.0 <= influence <= 1.0:
            problems.append("%s: prompt_influence must be 0-1" % sid)
        if int(source.get("takes", 0)) < 1:
            problems.append("%s: takes must be at least 1" % sid)
    return problems


def take_key(source: dict, take: int, model_id: str = MODEL_ID) -> str:
    shaped_by = json.dumps([source["prompt"], float(source["duration_s"]), float(source.get("prompt_influence", 0.3)),
                            bool(source.get("loop", False)), model_id, take], sort_keys=True)
    return hashlib.sha1(shaped_by.encode()).hexdigest()[:10]


def master_path(masters: Path, source: dict, take: int, model_id: str = MODEL_ID) -> Path:
    return masters / ("%s_%d.%s.mp3" % (source["id"], take, take_key(source, take, model_id)))


def requests(data: dict, only: set | None = None, pilot: bool = False) -> list[dict]:
    """Every take the recipe asks for, in order. `pilot` keeps only sources marked for the pilot."""
    wanted = []
    for source in data["sources"]:
        if only and source["id"] not in only and source["sound"] not in only:
            continue
        if pilot and not source.get("pilot", False):
            continue
        for take in range(1, int(source["takes"]) + 1):
            wanted.append({"source": source, "take": take})
    return wanted


def plan(data: dict, masters: Path, only: set | None = None, pilot: bool = False, model_id: str = MODEL_ID) -> dict:
    todo, done = [], []
    for request in requests(data, only, pilot):
        path = master_path(masters, request["source"], request["take"], model_id)
        (done if path.exists() else todo).append(dict(request, path=path))
    seconds = sum(float(r["source"]["duration_s"]) for r in todo)
    return {"todo": todo, "done": done, "seconds": seconds,
            "estimated_credits": int(round(seconds * ESTIMATED_CREDITS_PER_SECOND))}


def environment_key() -> str:
    for name in KEY_ENVS:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return ""


def worth_retrying(error: Exception) -> bool:
    status = getattr(error, "status_code", None)
    if status is not None:
        return int(status) == 429 or 500 <= int(status) < 600
    text = ("%s %s" % (type(error).__name__, error)).lower()
    return any(needle in text for needle in RETRY_ON)


class RealClient:
    name = "ElevenLabs"

    def __init__(self, api_key: str | None = None, model_id: str = MODEL_ID):
        key = api_key or environment_key()
        if not key:
            raise RuntimeError("neither %s is set; the key lives in the environment, never in a file" % " nor ".join(KEY_ENVS))
        if not key.startswith(KEY_PREFIX):
            raise RuntimeError("that is an ElevenLabs key id, not an API key (API keys start with %s)" % KEY_PREFIX)
        from elevenlabs.client import ElevenLabs  # only real runs need the SDK

        self._client = ElevenLabs(api_key=key, timeout=REQUEST_TIMEOUT_S)
        self.model_id = model_id

    def remaining_credits(self):
        subscription = self._client.user.get().subscription
        return subscription.character_limit - subscription.character_count

    def generate(self, prompt: str, duration_s: float, influence: float, loop: bool) -> bytes:
        kwargs = dict(text=prompt, duration_seconds=duration_s, prompt_influence=influence,
                      model_id=self.model_id, output_format=OUTPUT_FORMAT)
        if loop:
            kwargs["loop"] = True
        return b"".join(self._client.text_to_sound_effects.convert(**kwargs))


class MockClient:
    """Makes a noise burst of the requested length, so the layering path runs on real audio for nothing."""
    name = "MockClient"

    def __init__(self, credits: int = 100000):
        self.credits = credits
        self.calls: list[dict] = []

    def remaining_credits(self):
        return self.credits

    def generate(self, prompt: str, duration_s: float, influence: float, loop: bool) -> bytes:
        self.calls.append({"prompt": prompt, "duration_s": duration_s, "loop": loop})
        self.credits -= int(round(duration_s * ESTIMATED_CREDITS_PER_SECOND))
        rate = 22050
        frames = bytearray()
        seed = int(hashlib.sha1(prompt.encode()).hexdigest()[:8], 16)
        count = int(duration_s * rate)
        lead = int(0.03 * rate)  # generated effects rarely start on sample zero
        for i in range(count):
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            noise = (seed / 0x3FFFFFFF) - 1.0
            envelope = 0.0 if i < lead else (1.0 if loop else math.exp(-4.0 * (i - lead) / count))
            frames += struct.pack("<h", int(12000 * envelope * noise))
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes(bytes(frames))
        return subprocess.run(["ffmpeg", "-v", "error", "-f", "wav", "-i", "pipe:0", "-c:a", "libmp3lame", "-b:a", "96k",
                               "-ar", "44100", "-f", "mp3", "pipe:1"], input=buffer.getvalue(),
                              capture_output=True, check=True).stdout


def generate(the_plan: dict, client, log=print, delays=None, settle_polls: int = 0, settle_s: float = 30.0) -> dict:
    """Runs every missing take. A failure on one take is logged and skipped, never fatal to the rest."""
    before = client.remaining_credits()
    made, failed = [], []
    for request in the_plan["todo"]:
        source, take, path = request["source"], request["take"], request["path"]
        path.parent.mkdir(parents=True, exist_ok=True)
        describe = "%s take %d" % (source["id"], take)
        audio = None
        for attempt, delay in enumerate(tuple(RETRY_DELAYS_S if delays is None else delays) + (None,)):
            try:
                audio = client.generate(source["prompt"], float(source["duration_s"]),
                                        float(source.get("prompt_influence", 0.3)), bool(source.get("loop", False)))
                break
            except Exception as error:  # noqa: BLE001 - one bad take must not cost the run
                if delay is None or not worth_retrying(error):
                    log("FAILED %s: %s" % (describe, error))
                    failed.append(describe)
                    break
                log("RETRY %s after %s: waiting %.0f s" % (describe, type(error).__name__, delay))
                time.sleep(delay)
        if audio:
            path.write_bytes(audio)
            made.append(path)
            log("made %s (%.1f s) -> %s" % (describe, float(source["duration_s"]), path.name))
    after = client.remaining_credits()
    # The account balance lags the requests (the pilot read unchanged straight after, and 230 lower minutes later),
    # so a real run waits for it to settle before the ledger records the spend.
    for _ in range(settle_polls if made else 0):
        if after != before:
            break
        time.sleep(settle_s)
        after = client.remaining_credits()
    return {"requests": len(made), "failed": failed, "seconds": sum(float(r["source"]["duration_s"]) for r in the_plan["todo"]),
            "estimated_credits": the_plan["estimated_credits"], "before": before, "after": after}


def append_ledger(ledger: Path, report: dict, client_name: str, model_id: str, note: str = "") -> None:
    ledger.parent.mkdir(parents=True, exist_ok=True)
    if not ledger.exists():
        ledger.write_text("# Sound-effect ledger (ElevenLabs)\n\nEvery paid sound-effect run, appended by "
                          "tools/audio/sfx_generate.py. Lead gate 1 (round 5): approved; pilot first, then the batch.\n\n"
                          "| Date | Client | Model | Requests | Seconds | Est. credits | Credits before → after | Spent | Note |\n"
                          "|---|---|---|---|---|---|---|---|---|\n")
    spent = ""
    if isinstance(report["before"], int) and isinstance(report["after"], int):
        spent = str(report["before"] - report["after"])
    with ledger.open("a") as handle:
        handle.write("| %s | %s | %s | %d | %.1f | %d | %s → %s | %s | %s |\n" % (
            datetime.date.today().isoformat(), client_name, model_id, report["requests"], report["seconds"],
            report["estimated_credits"], report["before"], report["after"], spent, note))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--mock", action="store_true")
    mode.add_argument("--approved", action="store_true", help="real ElevenLabs requests (costs credits)")
    parser.add_argument("--sources", type=Path, default=SOURCES)
    parser.add_argument("--masters", type=Path, default=MASTERS)
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    parser.add_argument("--only", default="", help="comma-separated source ids or SfxSystem sounds")
    parser.add_argument("--pilot", action="store_true", help="only sources marked \"pilot\": true")
    parser.add_argument("--note", default="")
    args = parser.parse_args(argv)
    data = load_sources(args.sources)
    only = {s for s in args.only.split(",") if s} or None
    the_plan = plan(data, args.masters, only, args.pilot)
    print("%d takes to generate (%.1f s of audio, ~%d credits at %.0f/s), %d already made" % (
        len(the_plan["todo"]), the_plan["seconds"], the_plan["estimated_credits"], ESTIMATED_CREDITS_PER_SECOND,
        len(the_plan["done"])))
    if args.dry_run:
        for request in the_plan["todo"]:
            print("  %-24s take %d  %4.1f s  %s" % (request["source"]["id"], request["take"],
                                                    float(request["source"]["duration_s"]), request["source"]["prompt"][:70]))
        return 0
    client = MockClient() if args.mock else RealClient()
    report = generate(the_plan, client, settle_polls=0 if args.mock else 10)
    ledger = args.masters / "ledger.md" if args.mock else args.ledger
    append_ledger(ledger, report, client.name, MODEL_ID, args.note or ("mock run: no credits" if args.mock else ""))
    print("spent: %s → %s credits; %d made, %d failed" % (report["before"], report["after"], report["requests"],
                                                        len(report["failed"])))
    return 1 if report["failed"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
