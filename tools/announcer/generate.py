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
import tempfile
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
## A sliced clip is levelled to the mean of the sentence it came from, so a word that happened to fall on an
## unstressed beat doesn't dip when it is stitched between two others. Measured in the pilot (2026-09-16): whole
## sentences land within 0.2 LU of each other, but the one-word fillers spread 5.6 LU and "Rust", "eight" and
## "Green" came out 5-7 dB under the lines they stitch into - which is also why speech-to-text missed exactly those.
## Bounded, because the cure for a quiet word is not an arbitrarily loud one: normalizing each slice on its own
## (round 3) made fillers ~10 dB hotter than the sentences.
LEVEL_MATCH_MAX_DB = 6.0
## Speech-to-text cannot reliably hear a single word on its own: in the pilot it missed "Rust", "Green", "eight"
## and "one" as isolated clips, then transcribed every one of them correctly once they were stitched into a line
## ("Green is down to eight", exactly). A clip this short with one word in it is therefore reported as
## *unverifiable* rather than failed - otherwise ~90 false alarms in the full run would bury the real ones. What
## proves these clips are good is the stitch check (`make announcer-stitch-check`), which hears them in context.
STT_UNVERIFIABLE_S = 0.7
# Speech runs ~15 characters a second: used only to estimate speech-to-text minutes in a dry run.
CHARACTERS_PER_SECOND = 15.0


## Godot must not import these folders: the booth loads clips from disk at runtime, importing 2,396 files is slow
## and once crashed the import step outright, and they are excluded from every export anyway. The generator writes
## the marker itself so that wiping the folder to re-cut cannot silently lose it (it did, 2026-09-16, and 2,396
## .import files ended up committed).
## **The masters need it just as much (round 10).** They are git-ignored, so nobody thought about them - but
## `tools/remote.sh` rsyncs them to builder0 all the same (it excludes assets/incoming/, not these), and there
## `make import` met 616 fresh MP3s and died: `make[2]: *** [mk/core.mk:45: import] Segmentation fault`, on
## color.faction.09.mp3. Nothing loads a master at runtime; they are the cutter's input.
GDIGNORE_NOTE = """# Godot deliberately ignores this folder; see README.md. The booth loads these clips from disk
# at runtime (AnnouncerVoice), they are excluded from both export presets, and importing them all is slow.
"""


def drop_caches(masters: Path) -> int:
    """Removes the normalized-WAV and level caches beside the masters. They exist only to make re-cutting fast and
    regenerate from the MP3 in seconds, but they are roughly six times the size of what they cache: after one full
    run they were 950 MB of a 1.1 GB masters folder, on a laptop sitting at 98% disk. Kept during a run, dropped
    at the end."""
    freed = 0
    for pattern in ("*.norm.wav", "*.level.txt"):
        for stale in masters.rglob(pattern):
            freed += stale.stat().st_size
            stale.unlink()
    return freed


def keep_out_of_godot(folder: Path) -> None:
    marker = folder / ".gdignore"
    if not marker.exists():
        folder.mkdir(parents=True, exist_ok=True)
        marker.write_text(GDIGNORE_NOTE)
    for stale in folder.rglob("*.import"):
        stale.unlink()


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


def mean_volume_db(path: Path, extra_filter: str = "") -> float:
    """The RMS level ffmpeg reports for a file, after `extra_filter`. RMS rather than EBU R128 integrated loudness
    because that gates out anything under about 400 ms, and every filler here is shorter than that (the pilot's
    0.29 s "Rust" measured as -70 LUFS: not silence, just unmeasurable that way)."""
    chain = ",".join(part for part in (extra_filter, "volumedetect") if part)
    result = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", chain, "-f", "null", "-"],
                            capture_output=True, text=True)
    found = re.search(r"mean_volume:\s*(-?\d+\.?\d*) dB", result.stderr)
    return float(found.group(1)) if found else 0.0


def master_level_db(master: Path) -> float:
    """The sentence's own speech level, trimmed the same way its slices are, cached beside the master."""
    cache = master.with_suffix(".level.txt")
    norm = normalized_master(master)
    if not cache.exists() or cache.stat().st_mtime < norm.stat().st_mtime:
        cache.write_text("%.3f" % mean_volume_db(norm, TRIM))
    return float(cache.read_text())


def cut_clip(master: Path, start_s: float, end_s: float, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    norm = normalized_master(master)
    with tempfile.TemporaryDirectory() as scratch:
        piece = Path(scratch) / "piece.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % start_s, "-to", "%.3f" % end_s,
                        "-i", str(norm), "-af", TRIM, "-ac", "1", str(piece)], check=True)
        # A whole-sentence clip is its own master, so this is a no-op for it; only slices move.
        gain = max(-LEVEL_MATCH_MAX_DB, min(LEVEL_MATCH_MAX_DB, master_level_db(master) - mean_volume_db(piece)))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(piece),
                        "-af", "volume=%.2fdB,alimiter=limit=0.84:attack=2:release=40:level=disabled" % gain,
                        "-ac", "1", "-c:a", "libvorbis", "-b:a", SPEECH_BITRATE, str(out)], check=True)


def transcribe_safely(client, path: Path, expected: str, counts_words: bool) -> tuple[str, bool, str]:
    """(heard, ok, unreadable). `unreadable` is a reason string when the recogniser refused the clip outright.

    A 28-minute paid generation run must not die because a *check* raised: the audio it was checking is already
    recorded and on disk. Seen 2026-09-16 at 277 of 581 clips, on `audio_too_short` for a very short slice."""
    try:
        heard = client.transcribe(path)
    except Exception as error:  # the SDK raises its own ApiError type; any refusal is handled the same way
        if voice_client.worth_retrying(error):
            try:
                heard = voice_client.with_retries(lambda: client.transcribe(path), "transcribe %s" % path.name)
                return heard, heard_ok(expected, heard, counts_words), ""
            except Exception as retried:
                error = retried
        body = getattr(error, "body", None)
        detail = body.get("detail", {}) if isinstance(body, dict) else {}
        reason = detail.get("status") or detail.get("message") or type(error).__name__
        return "", True, "speech-to-text refused it (%s)" % reason
    return heard, heard_ok(expected, heard, counts_words), ""


def context_dependent(kind: str, expected: str, seconds: float) -> bool:
    """True when speech-to-text cannot fairly judge this clip on its own.

    Since round 4 every clip is a whole sentence, so this is nearly always False and the check is trustworthy
    again — that is a real benefit of dropping the stitching, not just a side effect. It stays for the one case
    left: a line so short it is a single word, which the recogniser still guesses at."""
    words = [w for w in expected.split() if re.search(r"[A-Za-z]", w)]
    return len(words) <= 1 and seconds < STT_UNVERIFIABLE_S


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
    if the_plan.get("too_many"):
        out.append("NOT ordered, too many combinations (a line naming more than one variable thing): %s"
                   % ", ".join("%s (%d)" % (r["id"], r["combinations"]) for r in the_plan["too_many"]))
    return "\n".join(out)


def generate(the_plan: dict, speakers: dict, client, masters: Path, out: Path, model_id: str, log=print,
             max_characters: int | None = None) -> dict:
    """Records what's missing, cuts every clip, checks it, and writes out/manifest.json. Returns a report.

    `max_characters` is the run's budget: a recording that would take the characters sent past it is not requested
    (counted in `over_budget`), so a paid batch cannot overshoot the stop line it was sized against."""
    resolved = client.voice_ids()
    counts_words = getattr(client, "counts_words", isinstance(client, voice_client.MockClient))
    report = {"requests_sent": 0, "characters": 0, "skipped_existing": 0, "clips": 0, "stt_failed": [], "stt_unverifiable": [], "failed_requests": [], "missing_voices": [],
              "alignment_errors": [], "over_budget": 0}
    clips = {}
    keep_out_of_godot(masters)
    manifest_path = out / "manifest.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    keep_out_of_godot(out)
    freed = drop_caches(masters)
    if freed:
        log("cleared %.0f MB of re-cutting caches beside the masters" % (freed / 1e6))
    previous = {part: previous.get(part, {}) for part in ("clips", "lines")}
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
        elif max_characters is not None and report["characters"] + len(request["text"]) > max_characters:
            report["over_budget"] += 1
            continue
        else:
            try:
                audio, alignment = voice_client.with_retries(
                    lambda: client.speak(resolved[voice_name], request["text"], request.get("previous_text"),
                                         request.get("next_text")),
                    request["id"], log)
            except Exception as error:
                # Every recording already made is on disk and this run is idempotent, so the useful thing to do
                # with one that will not come is note it and keep going. Re-running picks it up for free.
                report["failed_requests"].append({"id": request["id"], "error": "%s: %s" % (type(error).__name__, error)})
                log("FAILED %s: %s (the rest of the run continues; re-run to pick it up)" % (request["id"], error))
                continue
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
                    # Classify it the same way a fresh cut would be, or a clip cut before this rule existed keeps
                    # failing the run forever.
                    bucket = "stt_unverifiable" if context_dependent(
                        piece["kind"], piece["text"], float(earlier.get("duration_s", 0.0))) else "stt_failed"
                    report[bucket].append(piece["clip"])
                continue
            cut_clip(master, start_s, end_s, path)
            seconds = voice_client.probe_duration(path)
            heard, ok, unreadable = transcribe_safely(client, path, piece["text"], counts_words)
            if unreadable:
                # The recogniser refused the clip itself (it rejects very short audio outright). The audio is
                # already paid for and written; losing its check is not a reason to abandon the run, and the
                # stitch check hears it in context anyway.
                report["stt_unverifiable"].append(piece["clip"])
                log("SPEECH-TO-TEXT %s: %s; covered by the stitch check" % (piece["clip"], unreadable))
                clips[piece["clip"]] = {"file": "%s/%s" % (request["speaker"], clip_file(piece["clip"])),
                                        "speaker": request["speaker"], "voice": voice_name, "text": piece["text"],
                                        "kind": piece["kind"], "request": request["id"],
                                        "duration_s": round(seconds, 3), "stt_text": "", "stt_ok": True,
                                        "request_key": key}
                report["clips"] += 1
                continue
            if not ok and context_dependent(piece["kind"], piece["text"], seconds):
                report["stt_unverifiable"].append(piece["clip"])
                log("SPEECH-TO-TEXT %s: %r heard as %r; not judgeable alone, covered by the stitch check"
                    % (piece["clip"], piece["text"], heard))
            elif not ok:
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
                "lines": dict(previous["lines"], **the_plan["lines"])}
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
    parser.add_argument("--only", default="", help="comma-separated line ids (every recording of each comes along)")
    parser.add_argument("--model", default=voice_client.MODEL_ID)
    parser.add_argument("--ledger", type=Path, default=LEDGER)
    parser.add_argument("--note", default="", help="the ledger row's note: which batch this is")
    parser.add_argument("--max-characters", type=int, help="send nothing that takes this run past this many characters")
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
        report = generate(the_plan, speakers, client, args.masters or MASTERS, out, args.model,
                          max_characters=args.max_characters)
        append_ledger(args.ledger, report, "ElevenLabs", args.model, args.note)
    print("sent %d requests (%d characters), reused %d masters, cut %d clips; speech-to-text flagged %d; alignment errors %d; "
          "voices missing: %s; credits %s → %s" % (
              report["requests_sent"], report["characters"], report["skipped_existing"], report["clips"], len(report["stt_failed"]),
              len(report["alignment_errors"]), ", ".join(report["missing_voices"]) or "none", report["credits_before"], report["credits_after"]))
    if report.get("over_budget"):
        print("  %d recordings NOT requested: they would have passed --max-characters %d" % (
            report["over_budget"], args.max_characters))
    if report.get("failed_requests"):
        print("  %d recordings did not come back even after retrying; re-run to pick them up:"
              % len(report["failed_requests"]))
        for failure in report["failed_requests"][:10]:
            print("    %s — %s" % (failure["id"], failure["error"][:90]))
    if report.get("stt_unverifiable"):
        print("  %d fragments and one-word clips speech-to-text cannot judge alone; `make announcer-stitch-check` "
              "hears them in context" % len(report["stt_unverifiable"]))
    for clip in report["stt_failed"]:
        print("  check by ear: %s" % clip)
    return 1 if report["stt_failed"] or report["alignment_errors"] or report.get("failed_requests") else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
