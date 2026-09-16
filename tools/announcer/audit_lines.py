#!/usr/bin/env python3
"""Text audit for the announcer line library (like mavlink-hud's audit_tts.py, for a tagged banter library).

    python3 tools/announcer/audit_lines.py            # assets/announcer/lines.json + beats.json
    python3 tools/announcer/audit_lines.py --strict   # warnings fail too

Errors (exit 1): broken structure, unknown speakers/acts/slots, missing tags, duplicate ids or texts, symbols and
digits a voice would read badly, "a {unit}" articles, needs-flags nothing sets, questions nobody answers, beats with
no lines. Warnings: overlong lines for the speaker, near-duplicates, phrases from the rejected tone
(_agents/streams/archive/round3/announcer.md), and borrowed catchphrases.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LINES = ROOT / "assets" / "announcer" / "lines.json"
BEATS = ROOT / "assets" / "announcer" / "beats.json"

ACTS = {
    "caller": {"hype", "call", "button", "interrupt", "setup_question", "stat", "reaction"},
    "color": {"analysis", "roast", "answer_agree", "answer_disagree", "callback", "prediction", "lore", "button"},
    "pa": {"welcome", "notice", "sponsor_read", "result", "answer_disagree", "filler"},
}
# Slot name -> vocabulary it speaks ("count" kinds are number words the director fills).
SLOTS = {"team": "team", "other_team": "team", "team_s": "team_s", "other_team_s": "team_s",
         "unit": "unit", "killer_unit": "unit", "victim_unit": "unit", "target_unit": "unit", "shooter_unit": "unit",
         "units": "units", "other_units": "units", "arena": "arena",
         "count": "number", "other_count": "number", "streak": "number", "kills": "number"}
# Slots whose spoken value can start with a vowel sound ("IFV", "artillery"): never after "a".
VOWEL_RISK = {"unit", "units"}
MAX_CHARS = {"caller": 110, "color": 130, "pa": 200}
ALLOWED = re.compile(r"^[A-Za-z .,!?'{}_:;-]+$")
DIRECTOR_FLAGS = re.compile(r"^said_[a-z_]+_\{team\}$|^said_friendly_\{team\}$")
# The lead rejected these as "far too overt" (2026-09-15); keep them out of new lines.
REJECTED_TONE = ["terms and conditions", "void where", "retired", "organ", "team-building", "hydration is a privilege",
                 "learning opportunity", "because you won't make it", "pre-order"]
# Famous announcers' signature calls and strong language: the characters are original, and the rating stays mild.
BORROWED = ["let's get it on", "it's time", "down goes", "let's get ready", "oh my god", "boom goes", "damn", "hell",
            "shit", "bastard", "christ"]


def _norm(text: str) -> str:
    return re.sub(r"[^a-z ]", "", text.lower()).strip()


def audit(lines_data: dict, beats_data: dict) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    kinds = set(beats_data.get("moments", {}))
    vocabulary = lines_data.get("vocabulary", {})
    lines = lines_data.get("lines", [])
    if not lines:
        return ["the library has no lines"], []
    ids, texts, openings = {}, {}, {}
    sets, topics_asked, topics_answered = set(), set(), set()
    by_kind_act: dict[tuple, int] = {}
    for line in lines:
        where = line.get("id", "<no id>")
        for field in ("id", "speaker", "act", "tags", "text"):
            if field not in line:
                errors.append("%s: missing %s" % (where, field))
        if any(field not in line for field in ("id", "speaker", "act", "tags", "text")):
            continue
        if line["id"] in ids:
            errors.append("%s: duplicate id" % where)
        ids[line["id"]] = line
        speaker, act, text, tags = line["speaker"], line["act"], line["text"], line["tags"]
        if speaker not in ACTS:
            errors.append("%s: unknown speaker %r" % (where, speaker))
            continue
        if act not in ACTS[speaker]:
            errors.append("%s: %s has no act %r" % (where, speaker, act))
        line_kinds = [t for t in tags if t in kinds or t == "any"]
        if not line_kinds:
            errors.append("%s: tags %s name no moment kind (%s) or any" % (where, tags, ", ".join(sorted(kinds))))
        for kind in line_kinds:
            by_kind_act[(kind, speaker, act)] = by_kind_act.get((kind, speaker, act), 0) + 1
        if "intensity" in line and line["intensity"] not in (1, 2, 3):
            errors.append("%s: intensity must be 1, 2, or 3" % where)
        plain = re.sub(r"\{[a-z_]+\}", "", text)
        if not ALLOWED.match(plain):
            bad = sorted(set(c for c in plain if not ALLOWED.match(c)))
            errors.append("%s: characters a voice reads badly %s in %r" % (where, bad, text))
        for slot in re.findall(r"\{([^}]*)\}", text):
            if slot not in SLOTS:
                errors.append("%s: unknown slot {%s}" % (where, slot))
            elif SLOTS[slot] not in ("number",) and SLOTS[slot] not in vocabulary:
                errors.append("%s: slot {%s} has no vocabulary %r" % (where, slot, SLOTS[slot]))
            if slot in SLOTS and SLOTS[slot] in VOWEL_RISK and re.search(r"\b[Aa] \{%s\}" % slot, text):
                errors.append("%s: 'a {%s}' reads 'a IFV'; use 'the' or 'that'" % (where, slot))
        key = _norm(text)
        if key in texts:
            errors.append("%s: same text as %s" % (where, texts[key]))
        texts[key] = where
        opening = (speaker, " ".join(key.split()[:5]))
        if len(key.split()) >= 7 and opening in openings:
            warnings.append("%s: starts like %s" % (where, openings[opening]))
        openings.setdefault(opening, where)
        if len(text) > MAX_CHARS[speaker]:
            warnings.append("%s: %d characters is long for the %s (%d)" % (where, len(text), speaker, MAX_CHARS[speaker]))
        lowered = text.lower()
        for phrase in REJECTED_TONE:
            if phrase in lowered:
                warnings.append("%s: %r is from the rejected tone" % (where, phrase))
        for phrase in BORROWED:
            if re.search(r"\b%s\b" % re.escape(phrase), lowered):
                warnings.append("%s: %r is a borrowed catchphrase or strong language" % (where, phrase))
        sets.update(line.get("sets", []))
        if act == "setup_question":
            if not line.get("topic"):
                errors.append("%s: a setup_question needs a topic" % where)
            topics_asked.add(line.get("topic"))
        if act.startswith("answer") and line.get("topic"):
            topics_answered.add(line["topic"])
    for line in lines:
        for flag in line.get("needs", []):
            if flag not in sets and not DIRECTOR_FLAGS.match(flag):
                errors.append("%s: needs %r, which no line sets" % (line.get("id"), flag))
    for topic in sorted(t for t in topics_asked if t not in topics_answered):
        errors.append("topic %r is asked but never answered" % topic)
    for kind, config in beats_data.get("moments", {}).items():
        for beat in config.get("beats", []):
            for step in beat.get("steps", []):
                acts = step["act"] if isinstance(step["act"], list) else [step["act"]]
                if step.get("optional") or step.get("chance") is not None:
                    continue
                if not any(by_kind_act.get((kind, step["speaker"], act)) or by_kind_act.get(("any", step["speaker"], act))
                           for act in acts):
                    errors.append("beat %r of %s: no %s line for %s" % (beat.get("name"), kind, step["speaker"], "/".join(acts)))
    return errors, warnings


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lines", type=Path, default=LINES)
    parser.add_argument("--beats", type=Path, default=BEATS)
    parser.add_argument("--strict", action="store_true", help="warnings fail the audit too")
    args = parser.parse_args(argv)
    lines_data = json.loads(args.lines.read_text())
    errors, warnings = audit(lines_data, json.loads(args.beats.read_text()))
    counts = {}
    for line in lines_data.get("lines", []):
        counts[line.get("speaker")] = counts.get(line.get("speaker"), 0) + 1
    words = sum(len(line.get("text", "").split()) for line in lines_data.get("lines", []))
    print("audited %d lines (%s), %d words: %d errors, %d warnings" % (
        len(lines_data.get("lines", [])), ", ".join("%s %d" % kv for kv in sorted(counts.items())), words,
        len(errors), len(warnings)))
    for error in errors:
        print("ERROR   " + error)
    for warning in warnings:
        print("warning " + warning)
    return 1 if errors or (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
