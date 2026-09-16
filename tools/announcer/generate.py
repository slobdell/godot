#!/usr/bin/env python3
"""The announcer audio pipeline: line library -> voice masters -> sliced, normalized, checked Ogg clips + manifest.

    python3 tools/announcer/generate.py --dry-run                 # what would be sent, and what it would cost
    python3 tools/announcer/generate.py --mock --out build/announcer/mock   # the whole pipeline, no credits
    python3 tools/announcer/generate.py --lead-approved           # real ElevenLabs requests (lead gate 2)

Modeled on the lead's mavlink-hud speech-to-text-elevenlabs pipeline (rules -> MP3 masters, skip existing, print
credits, ffmpeg -> OGG), plus what stitched commentary needs: whole sentences with character timestamps sliced at
word boundaries (tools/announcer/recording_plan.py), request stitching for answers, silence trimming and loudness
normalization so any clip can follow any other, a speech-to-text check of every clip, mono Ogg Vorbis at a speech
bitrate, a manifest with tags and durations, and a ledger of what was spent.

Masters are git-ignored and never regenerated when their text, voice, and model haven't changed.
"""

from __future__ import annotations

import argparse
import datetime
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import recording_plan  # noqa: E402
import voice_client  # noqa: E402

LINES = ROOT / "assets" / "announcer" / "lines.json"
MASTERS = ROOT / "assets" / "announcer" / "masters"
CLIPS = ROOT / "assets" / "announcer" / "clips"
LEDGER = ROOT / "assets" / "announcer" / "ledger.md"
SPEECH_BITRATE = "40k"
LOUDNESS = "loudnorm=I=-16:TP=-1.5:LRA=11"
TRIM = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse,"
        "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.04,areverse")
STT_MIN_RATIO = 0.8
# Speech runs ~15 characters a second: used only to estimate speech-to-text minutes in a dry run.
CHARACTERS_PER_SECOND = 15.0


def clip_file(clip: str) -> str:
    return clip.replace("#", "-") + ".ogg"


def request_key(request: dict, voice_name: str, model_id: str) -> str:
    material = json.dumps([voice_name, model_id, request["text"], request.get("previous_text"), request.get("next_text")])
    return hashlib.sha1(material.encode()).hexdigest()


def slice_times(alignment: dict, start: int, end: int) -> tuple[float, float]:
    """Seconds to cut a character span [start, end) at word boundaries, padded into the silence around it."""
    starts = alignment["character_start_times_seconds"]
    ends = alignment["character_end_times_seconds"]
    t0, t1 = float(starts[start]), float(ends[end - 1])
    before = float(starts[start - 1]) if start > 0 else 0.0
    after = float(ends[end]) if end < len(ends) else t1 + 0.16
    pad_left = min(0.05, max(0.0, (t0 - before) / 2))
    pad_right = min(0.08, max(0.0, (after - t1) / 2))
    return max(0.0, t0 - pad_left), t1 + pad_right


def normalized_master(master: Path) -> Path:
    """The whole sentence loudness-normalized once (mono WAV beside the master). Slices cut from it share one gain;
    normalizing each short slice on its own made one-word fillers ~10 dB louder than the sentences around them."""
    wav = master.with_suffix(".norm.wav")
    if not wav.exists() or wav.stat().st_mtime < master.stat().st_mtime:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(master), "-af", "%s,aresample=44100" % LOUDNESS,
                        "-ac", "1", str(wav)], check=True)
    return wav


def cut_clip(master: Path, start_s: float, end_s: float, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % start_s, "-to", "%.3f" % end_s,
                    "-i", str(normalized_master(master)), "-af", TRIM, "-ac", "1", "-c:a", "libvorbis",
                    "-b:a", SPEECH_BITRATE, str(out)], check=True)


def heard_ok(expected: str, heard: str, counts_words: bool) -> bool:
    words = re.findall(r"[a-z']+", expected.lower())
    got = re.findall(r"[a-z']+", heard.lower())
    if counts_words:  # the mock hears one burst per space-separated word ("ninety-four" is one)
        return len([w for w in expected.split() if re.search(r"[A-Za-z]", w)]) == len(got)
    return difflib.SequenceMatcher(a=words, b=got).ratio() >= STT_MIN_RATIO


def dry_run(the_plan: dict, speakers: dict, masters: Path, model_id: str) -> str:
    rate = voice_client.CREDITS_PER_CHARACTER.get(model_id, 1.0)
    out = ["DRY RUN: nothing is sent. Model %s at %.1f credits per character." % (model_id, rate), ""]
    out.append("%-8s %-12s %9s %7s %11s %13s" % ("speaker", "voice", "requests", "clips", "characters", "est. credits"))
    totals = [0, 0, 0, 0.0]
    pending_chars = 0
    recorded = 0
    for speaker, row in sorted(recording_plan.summarize(the_plan).items()):
        voice = speakers.get(speaker, {}).get("voice", "")
        credits = row["characters"] * rate
        out.append("%-8s %-12s %9d %7d %11d %13.0f%s" % (speaker, voice or "(not made)", row["requests"], row["clips"],
                                                       row["characters"], credits, "" if voice else "  skipped until the voice exists"))
        for total, value in zip(range(4), (row["requests"], row["clips"], row["characters"], credits)):
            totals[total] += value
    for request in the_plan["requests"]:
        voice = speakers.get(request["speaker"], {}).get("voice", "")
        meta = masters / request["speaker"] / (request["id"] + ".json")
        if voice and meta.exists() and json.loads(meta.read_text()).get("key") == request_key(request, voice, model_id):
            recorded += 1
        elif voice:
            pending_chars += len(request["text"])
    out.append("%-8s %-12s %9d %7d %11d %13.0f" % ("total", "", totals[0], totals[1], totals[2], totals[3]))
    out.append("")
    out.append("Already recorded (skipped on a real run): %d requests. Still to send for made voices: %d characters, ~%.0f credits."
               % (recorded, pending_chars, pending_chars * rate))
    minutes = totals[2] / CHARACTERS_PER_SECOND / 60
    out.append("Speech-to-text check: %d clips, about %.0f minutes of audio (billed by duration)." % (totals[1], minutes))
    out.append("Fillers: %d slot clips (team names, units, numbers, arenas) across the intonations the lines use." % len(the_plan["fillers"]))
    return "\n".join(out)


def generate(the_plan: dict, speakers: dict, client, masters: Path, out: Path, model_id: str, log=print) -> dict:
    """Records what's missing, cuts every clip, checks it, and writes out/manifest.json. Returns a report."""
    resolved = client.voice_ids()
    counts_words = getattr(client, "counts_words", isinstance(client, voice_client.MockClient))
    report = {"requests_sent": 0, "characters": 0, "skipped_existing": 0, "clips": 0, "stt_failed": [], "missing_voices": [],
              "alignment_errors": []}
    clips = {}
    manifest_path = out / "manifest.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    previous = {part: previous.get(part, {}) for part in ("clips", "lines", "fillers")}
    credits_before = client.remaining_credits()
    for request in the_plan["requests"]:
        voice_name = speakers.get(request["speaker"], {}).get("voice", "")
        if not voice_name or voice_name not in resolved:
            if request["speaker"] not in report["missing_voices"]:
                report["missing_voices"].append(request["speaker"])
                log("skip %s lines: voice %r is not in the account yet" % (request["speaker"], voice_name))
            continue
        master = masters / request["speaker"] / (request["id"] + ".mp3")
        meta_path = master.with_suffix(".json")
        key = request_key(request, voice_name, model_id)
        meta = json.loads(meta_path.read_text()) if meta_path.exists() and master.exists() else {}
        if meta.get("key") == key:
            report["skipped_existing"] += 1
        else:
            audio, alignment = client.speak(resolved[voice_name], request["text"], request.get("previous_text"), request.get("next_text"))
            master.parent.mkdir(parents=True, exist_ok=True)
            master.write_bytes(audio)
            meta = {"key": key, "text": request["text"], "voice": voice_name, "model": model_id,
                    "previous_text": request.get("previous_text"), "alignment": alignment}
            meta_path.write_text(json.dumps(meta))
            report["requests_sent"] += 1
            report["characters"] += len(request["text"])
            log("recorded %s (%d characters)" % (request["id"], len(request["text"])))
        alignment = meta["alignment"]
        if len(alignment["characters"]) != len(request["text"]):
            report["alignment_errors"].append(request["id"])
            log("ALIGNMENT %s: %d timed characters for %d in the text; not sliced" % (
                request["id"], len(alignment["characters"]), len(request["text"])))
            continue
        for piece in request["slices"]:
            start_s, end_s = slice_times(alignment, piece["start"], piece["end"])
            path = out / request["speaker"] / clip_file(piece["clip"])
            earlier = previous["clips"].get(piece["clip"], {})
            if path.exists() and path.stat().st_mtime >= master.stat().st_mtime and earlier.get("text") == piece["text"] \
                    and earlier.get("request_key") == key:
                clips[piece["clip"]] = earlier  # cut and checked on an earlier run from this same master
                report["clips"] += 1
                if not earlier["stt_ok"]:
                    report["stt_failed"].append(piece["clip"])
                continue
            cut_clip(master, start_s, end_s, path)
            heard = client.transcribe(path)
            ok = heard_ok(piece["text"], heard, counts_words)
            if not ok:
                report["stt_failed"].append(piece["clip"])
                log("SPEECH-TO-TEXT %s: expected %r, heard %r" % (piece["clip"], piece["text"], heard))
            clips[piece["clip"]] = {"file": "%s/%s" % (request["speaker"], clip_file(piece["clip"])), "speaker": request["speaker"],
                                    "voice": voice_name, "text": piece["text"], "kind": piece["kind"], "request": request["id"],
                                    "duration_s": round(voice_client.probe_duration(path), 3), "stt_text": heard, "stt_ok": ok,
                                    "request_key": key}
            report["clips"] += 1
    # A partial run (--only, --speakers) adds to the manifest instead of replacing it.
    manifest = {"schema": 1, "generated": datetime.date.today().isoformat(), "model": model_id,
                "client": type(client).__name__, "clips": dict(previous["clips"], **clips),
                "lines": dict(previous["lines"], **the_plan["lines"]), "fillers": dict(previous["fillers"], **the_plan["fillers"])}
    out.mkdir(parents=True, exist_ok=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True))
    report["credits_before"] = credits_before
    report["credits_after"] = client.remaining_credits()
    return report


def append_ledger(ledger: Path, report: dict, client_name: str, model_id: str, note: str = "") -> None:
    if report["requests_sent"] == 0:
        return
    if not ledger.exists():
        ledger.write_text("# Announcer voice ledger (ElevenLabs)\n\nEvery paid generation run, appended by "
                          "tools/announcer/generate.py. Lead gate: text approved before any real run.\n\n"
                          "| Date | Client | Model | Requests | Characters | Est. credits | Credits before → after | Note |\n"
                          "|---|---|---|---|---|---|---|---|\n")
    rate = voice_client.CREDITS_PER_CHARACTER.get(model_id, 1.0)
    with ledger.open("a") as handle:
        handle.write("| %s | %s | %s | %d | %d | %.0f | %s → %s | %s |\n" % (
            datetime.date.today().isoformat(), client_name, model_id, report["requests_sent"], report["characters"],
            report["characters"] * rate, report["credits_before"], report["credits_after"], note))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="print what would be sent and the estimated credits")
    mode.add_argument("--mock", action="store_true", help="run everything against the mock client (no credits)")
    mode.add_argument("--lead-approved", action="store_true", help="real ElevenLabs requests: only after the lead approves the text")
    parser.add_argument("--lines", type=Path, default=LINES)
    parser.add_argument("--out", type=Path, help="clips and manifest (default: assets/announcer/clips, or build/announcer/mock with --mock)")
    parser.add_argument("--masters", type=Path, help="masters (default: assets/announcer/masters, or <out>/masters with --mock)")
    parser.add_argument("--speakers", default="", help="comma-separated speakers to include")
    parser.add_argument("--only", default="", help="comma-separated line ids (their fillers come along)")
    parser.add_argument("--model", default=voice_client.MODEL_ID)
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    args = parser.parse_args(argv)
    lines_data = json.loads(args.lines.read_text())
    the_plan = recording_plan.plan(lines_data, [s for s in args.speakers.split(",") if s] or None,
                                   set(args.only.split(",")) if args.only else None)
    speakers = lines_data.get("speakers", {})
    if args.dry_run:
        print(dry_run(the_plan, speakers, args.masters or MASTERS, args.model))
        return 0
    if args.mock:
        out = args.out or ROOT / "build" / "announcer" / "mock"
        # Voices not made yet (the Veteran) get a stand-in so mock runs exercise every speaker.
        speakers = {name: dict(s, voice=s.get("voice") or "mock-%s" % name) for name, s in speakers.items()}
        client = voice_client.MockClient(voices={s["voice"]: "mock-" + s["voice"] for s in speakers.values()})
        report = generate(the_plan, speakers, client, args.masters or out / "masters", out, args.model)
        append_ledger(out / "ledger.md", report, "MockClient", args.model, "mock run: no credits")
    else:
        client = voice_client.RealClient(model_id=args.model)
        out = args.out or CLIPS
        report = generate(the_plan, speakers, client, args.masters or MASTERS, out, args.model)
        append_ledger(args.ledger, report, "ElevenLabs", args.model)
    print("sent %d requests (%d characters), reused %d masters, cut %d clips; speech-to-text flagged %d; alignment errors %d; "
          "voices missing: %s; credits %s → %s" % (
              report["requests_sent"], report["characters"], report["skipped_existing"], report["clips"], len(report["stt_failed"]),
              len(report["alignment_errors"]), ", ".join(report["missing_voices"]) or "none", report["credits_before"], report["credits_after"]))
    for clip in report["stt_failed"]:
        print("  check by ear: %s" % clip)
    return 1 if report["stt_failed"] or report["alignment_errors"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
