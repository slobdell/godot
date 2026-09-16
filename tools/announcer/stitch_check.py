#!/usr/bin/env python3
"""Hears the slot fillers the way a player will: stitched into a line, not alone.

    python3 tools/announcer/stitch_check.py                  # every filler, in a line that uses it
    python3 tools/announcer/stitch_check.py --dry-run        # what it would assemble, no API calls

Speech-to-text cannot judge a lone 0.3 s word — in the pilot it missed "Rust", "Green", "eight" and "one" as
isolated clips and then transcribed every one of them correctly in context. So `generate.py` reports those as
unverifiable and this is what actually checks them: for each filler, assemble a real line around it, transcribe the
assembly, and require the filler's own word to come back.

That is also the only check that can catch a bad *slice* — a clip that clips its consonant or swallows a syllable
sounds fine alone and wrong in a sentence.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import audit_lines  # noqa: E402
import mixdown  # noqa: E402
import recording_plan  # noqa: E402
import voice_client  # noqa: E402

ROOT = HERE.parents[1]
CLIPS = ROOT / "assets" / "announcer" / "clips"
LINES = ROOT / "assets" / "announcer" / "lines.json"
## A filler's word must come back in the transcript of the line it was stitched into.
## How the recogniser spells words it cannot be expected to get right: a team name it hears as a surname, an
## invented unit name, and an acronym. These say nothing about whether the delivery is good - they only stop the
## check reporting a clip as missing when it plainly played. The two marked "ear" have never been listened to by a
## human; they are the first things to play when someone can.
SOFT_MATCHES = {
    "rust": ["rust", "russ", "rusty"],
    "green": ["green"],
    "lancer": ["lancer", "blazer", "lance"],   # ear
    "ifv": ["ifv", "iv"],                      # ear
}
## A stand-in of the right kind for every slot in the line we are not currently checking.
DEFAULTS = {"team": "green", "team_s": "green", "unit": "tank", "units": "tank", "arena": "foundry", "number": 3.0}
## How close the whole assembled line has to be to its text. Below 1.0 because the recogniser drops final
## punctuation, writes numbers as digits, and hears "Rust" as "Russ" at a stitch boundary.
LINE_MIN_RATIO = 0.7


def words(text: str) -> list[str]:
    """Words *and* numerals: speech-to-text writes "ten" back as "10", and dropping digits made this check report a
    perfectly good clip as missing (2026-09-16)."""
    return re.findall(r"[a-z']+|\d+", text.lower())


def variants(word: str) -> set[str]:
    """One word as every spelling both sides might use: letters and digits only (so apostrophes never matter), with
    and without a trailing s. The recogniser writes the same possessive as "Rust's", "Russ" and "Russ'" in three
    different lines, and none of those should look like a missing clip."""
    bare = re.sub(r"[^a-z0-9]", "", str(word or "").lower())
    forms = {bare}
    if bare.endswith("s"):
        forms.add(bare[:-1])
    return forms


def accepted_forms(word: str) -> set[str]:
    """Every spelling that counts as hearing this word: its own variants, its soft homophones, and the numeral for
    a number word."""
    forms = set()
    for base in variants(word):
        forms |= variants(base)
        for soft in SOFT_MATCHES.get(base, []):
            forms |= variants(soft)
        if base in recording_plan.NUMBER_WORDS:
            forms.add(str(recording_plan.NUMBER_WORDS.index(base)))
    return forms


def spoken_value_present(expect: str, heard: list[str]) -> bool:
    """Whether the filler's spoken value came through. It is not always one word: an arena speaks as "the Foundry"
    and a possessive as "Rust's", so every word of it has to be looked for separately - matching the whole phrase
    as a single token reported eighteen perfectly good clips as missing (2026-09-16)."""
    wanted = words(str(expect or ""))
    if not wanted:
        return True
    # "the" and other bare articles carry no evidence; the distinctive words are what prove the clip played.
    distinctive = [w for w in wanted if not variants(w) & {"the", "a", "an"}] or wanted
    spoken = set()
    for word in heard:
        spoken |= variants(word)
    return all(bool(accepted_forms(word) & spoken) for word in distinctive)


def sample_cues(lines_data: dict, manifest: dict) -> list[dict]:
    """One cue per filler clip: a real line that uses that slot, with that filler's value in it."""
    by_id = {line["id"]: line for line in lines_data["lines"]}
    vocab = lines_data["vocabulary"]
    wanted: dict[str, dict] = {}
    for clip_id in manifest.get("clips", {}):
        if not clip_id.startswith("fill."):
            continue
        _, speaker, kind, value, _intonation = clip_id.split(".", 4) if clip_id.count(".") >= 4 \
            else (None, None, None, None, None)
        if speaker is None:
            continue
        wanted[clip_id] = {"speaker": speaker, "kind": kind, "value": value}

    cues = []
    for clip_id, want in sorted(wanted.items()):
        for line_id, line in sorted(by_id.items()):
            if line["speaker"] != want["speaker"] or line_id not in manifest.get("lines", {}):
                continue
            # Fill every slot with a value of its own kind (audit_lines.SLOTS is the same map the library uses),
            # and put the filler we are checking into whichever slot it belongs to.
            slots = {}
            for slot in re.findall(r"\{([^}]*)\}", line["text"]):
                base = slot[:-2] if slot.endswith("_s") else slot
                kind = audit_lines.SLOTS.get(slot)
                if kind is None:
                    slots = {}
                    break
                if kind == want["kind"]:
                    slots[base] = float(want["value"]) if kind == "number" else want["value"]
                else:
                    slots[base] = DEFAULTS[kind]
            if not slots:
                continue
            cue = {"t": 0.0, "end": 1.0, "line_id": line_id, "slots": slots, "cut": False}
            try:
                parts = mixdown.cue_clips(cue, manifest)
            except KeyError:
                continue
            if clip_id not in parts:
                continue
            if want["kind"] == "number":
                spoken = recording_plan.NUMBER_WORDS[int(float(want["value"]))]
            else:
                spoken = vocab.get(want["kind"], {}).get(want["value"], want["value"])
            spoken_text = line["text"]
            for slot in re.findall(r"\{([^}]*)\}", line["text"]):
                base = slot[:-2] if slot.endswith("_s") else slot
                kind = audit_lines.SLOTS.get(slot)
                value = slots.get(base)
                if kind == "number":
                    said = recording_plan.NUMBER_WORDS[int(float(value))]
                else:
                    said = vocab.get(kind, {}).get(str(value), str(value))
                spoken_text = spoken_text.replace("{%s}" % slot, said)
            cues.append({"clip": clip_id, "cue": cue, "parts": parts, "expect": spoken,
                         "text": line["text"], "spoken_text": spoken_text})
            break
    return cues


def check(clips_dir: Path, lines_path: Path, dry_run: bool, log=print) -> int:
    manifest = json.loads((clips_dir / "manifest.json").read_text())
    lines_data = json.loads(lines_path.read_text())
    samples = sample_cues(lines_data, manifest)
    if not samples:
        log("no filler clips to check yet")
        return 0
    log("checking %d fillers, each stitched into a line that uses it" % len(samples))
    if dry_run:
        for s in samples:
            log("  %-34s in %s" % (s["clip"], s["text"]))
        return 0

    client = voice_client.RealClient()
    bad = []
    out_dir = ROOT / "build" / "announcer" / "stitch"
    out_dir.mkdir(parents=True, exist_ok=True)
    for sample in samples:
        total = sum(manifest["clips"][c]["duration_s"] + mixdown.PART_GAP_S for c in sample["parts"])
        sample["cue"]["end"] = total
        out = out_dir / (sample["clip"].replace(".", "_") + ".ogg")
        mixdown.render(mixdown.schedule({"cues": [sample["cue"]]}, manifest), clips_dir, out, total + 0.2)
        transcript = client.transcribe(out)
        heard = words(transcript)
        expect = str(sample["expect"] or "").lower()
        # Two things at once: the filler's own word came through, and the whole assembled line reads correctly
        # (which is what covers the `segment` fragments stitched around it).
        missing = not spoken_value_present(expect, heard)
        whole = difflib.SequenceMatcher(a=words(sample["spoken_text"]), b=heard).ratio()
        if missing or whole < LINE_MIN_RATIO:
            bad.append((sample["clip"], sample["expect"], transcript))
            log("  STITCH %-32s %s | expected %r, heard %r" % (
                sample["clip"], "filler missing" if missing else "line %.2f similar" % whole,
                sample["spoken_text"], transcript))
    log("stitch check: %d of %d fillers not heard in context" % (len(bad), len(samples)))
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--clips", type=Path, default=CLIPS)
    parser.add_argument("--lines", type=Path, default=LINES)
    parser.add_argument("--dry-run", action="store_true", help="list what would be assembled; no API calls")
    args = parser.parse_args(argv)
    if not (args.clips / "manifest.json").exists():
        print("no clips yet at %s" % args.clips)
        return 0
    return check(args.clips, args.lines, args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
