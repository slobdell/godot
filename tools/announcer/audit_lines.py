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
         # The booth names a side by its faction, never by its colour (the lead, 2026-09-16). `_attr` is the
         # attributive form for after an article: "the Law tank", not "the the Law tank".
         "faction": "faction", "other_faction": "faction",
         "faction_s": "faction_s", "other_faction_s": "faction_s",
         "faction_attr": "faction_attr", "other_faction_attr": "faction_attr",
         "unit": "unit", "killer_unit": "unit", "victim_unit": "unit", "target_unit": "unit", "shooter_unit": "unit",
         "units": "units", "other_units": "units", "arena": "arena",
         "count": "number", "other_count": "number", "streak": "number", "kills": "number",
         "count_over": "count_over", "other_count_over": "count_over",
         "formation": "formation", "technique": "technique", "drill": "drill"}
# Slots whose spoken value can start with a vowel sound ("IFV", "artillery"): never after "a".
VOWEL_RISK = {"unit", "units"}
# The Veteran carries the technical analysis now, and a thought that trails off needs room to trail (the lead's
# own example ran 178 characters). The caller stays short because hype is short.
MAX_CHARS = {"caller": 110, "color": 185, "pa": 220}
# Used only to tell "the last {faction} vehicle" (wrong) from "a row for {faction}" and "the damage {faction} is
# soaking up" (both right): a preposition or a following verb means the slot is not inside the noun phrase.
PREPOSITIONS = {"for", "of", "to", "from", "with", "by", "on", "in", "at", "against", "over", "behind", "under"}
# A faction is a crew of people and takes a plural verb, the way sports commentary treats every team name: "the
# Wreckers crack it wide open", "the Law are all over them". It is the only rule that works for all four names —
# "the Condemned takes it" is simply wrong, and "the Wreckers takes it" doubly so.
SINGULAR_VERBS = {"is", "has", "takes", "wins", "gets", "keeps", "goes", "does", "brings", "rolls", "fields",
                  "looks", "needs", "loses", "leads", "holds", "cracks", "shreds", "opens", "comes", "puts",
                  "finishes", "answers", "wants", "was", "hits", "makes", "drives", "runs", "turns", "knows",
                  "pays", "sends", "starts", "stops", "catches", "lands", "strikes", "wipes",
                  # Round 10, from the transcripts: "The Wreckers draws first blood" had been recorded for three
                  # rounds because these words were not on the list.
                  "draws", "steals", "smells", "connects", "picks", "shells", "shuts", "closes", "stands", "opens",
                  "pulls", "seals", "breaks", "throws", "fires", "calls", "clears", "scores"}
VERBS = {"is", "are", "was", "were", "has", "have", "had", "takes", "wins", "gets", "keeps", "goes", "does",
         "will", "can", "brings", "rolls", "fields", "looks", "needs", "loses", "leads", "holds"}
# X3 (round 5): the booth names a side by its faction, never by its colour. Capitalised, a colour is a team name
# ("Green and Rust, live"); "the rust around the bolts" is the substance and stays legal. The team slots speak
# colours by construction, so they are banned outright (and their vocabulary is gone, so nothing could fill one).
COLOUR_NAMES = re.compile(r"\b(?:green|rust|red|blue|orange)\s+(?:team|side|squads?|crews?)\b|\b(Green|Rust|Red|Blue)\b", re.I)
COLOUR_SLOTS = {"team", "other_team", "team_s", "other_team_s"}
# A literal faction name as a *side* must be tagged with that faction, because tags are requirements: untagged, a
# line about the Wreckers can play in a match between the Law and the Syndicate. The Syndicate owns the arena and
# the Law is the state, so those two only count as a side when their crews or machines are the subject.
SIDE_NOUNS = r"(?:crews?|machines?|vehicles?|tanks?|officers?|units?|drivers?|hover machines?)"
FACTION_AS_SIDE = {
    "condemned": re.compile(r"\bCondemned\b"),
    "gangs": re.compile(r"\bWreckers?\b|\broad gangs?\b|\bgang crews?\b|\bGangs\b"),
    "law": re.compile(r"\bthe Law\s+%s\b|\bLaw\s+%s\b" % (SIDE_NOUNS, SIDE_NOUNS)),
    "syndicate": re.compile(r"\bSyndicate\s+%s\b" % SIDE_NOUNS),
}
ALLOWED = re.compile(r"^[A-Za-z .,!?'{}_:;-]+$")
DIRECTOR_FLAGS = re.compile(r"^said_[a-z_]+_\{team\}$|^said_friendly_\{team\}$")
# The lead rejected these as "far too overt" (2026-09-15); keep them out of new lines.
REJECTED_TONE = ["terms and conditions", "void where", "retired", "organ", "team-building", "hydration is a privilege",
                 "learning opportunity", "because you won't make it", "pre-order"]
# Famous announcers' signature calls and strong language: the characters are original, and the rating stays mild.
BORROWED = ["let's get it on", "it's time", "down goes", "let's get ready", "oh my god", "boom goes", "damn", "hell",
            "shit", "bastard", "christ"]


# C10 (round 10): the PA's register. Her new lines (`added` set) name their one wrong detail as data,
# {"span": "...", "category": "..."}, and these gates hold it to the research's shape: one short span, mid-sentence with
# ordinary words after it (clause-final is where a punchline sits), a flat carrier, and no two lines in a pool with the
# same kind of wrong detail. The categories are listed in lines.json (`oddity_categories`).
AFFECT_WORDS = {"sadly", "unfortunately", "tragically", "hilarious", "hilariously", "amazing", "amazingly", "wow",
                "incredible", "incredibly", "terrible", "terribly", "horrible", "horribly", "awful", "shocking",
                "shockingly", "lol", "ironically", "funny", "joke", "grim", "grimly", "darkly"}
ODDITY_WORDS = (1, 6)
ODDITY_TAIL = 4


def audit_oddity(line: dict, categories: dict) -> list[str]:
    where, text, oddity = line["id"], line["text"], line.get("oddity")
    if not isinstance(oddity, dict) or not oddity.get("span"):
        return ["%s: a new PA line names no oddity {span, category}: which words are the one wrong detail?" % where]
    errors = []
    span, category = oddity["span"], oddity.get("category", "")
    if category not in categories:
        errors.append("%s: unknown oddity category %r (lines.json oddity_categories)" % (where, category))
    if text.count(span) != 1:
        errors.append("%s: the oddity %r is not in the text exactly once" % (where, span))
        return errors
    words = len(span.split())
    if not ODDITY_WORDS[0] <= words <= ODDITY_WORDS[1]:
        errors.append("%s: the oddity is %d words; the wrong detail is 1-6 words" % (where, words))
    after = text[text.index(span) + len(span):]
    if after.lstrip()[:1] in (".", "!", "?", "") or len(re.findall(r"[A-Za-z']+", after)) < ODDITY_TAIL:
        errors.append("%s: the oddity sits at the end, the punchline position; bury it with %d or more ordinary words "
                      "after it" % (where, ODDITY_TAIL))
    if "!" in text:
        errors.append("%s: an exclamation breaks the PA's flat register" % where)
    affect = sorted(set(re.findall(r"[a-z]+", text.lower())) & AFFECT_WORDS)
    if affect:
        errors.append("%s: affect word %s in the PA's flat register" % (where, ", ".join(affect)))
    return errors


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
    categories = lines_data.get("oddity_categories", {})
    oddity_seen: dict[tuple, str] = {}
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
        # A faction name carries its own article ("the Law"), so an article in front of it doubles up:
        # "The last {other_faction} vehicle" reads "The last the Condemned vehicle". The attributive form
        # ({faction_attr} = "Law") belongs there instead. It is only wrong when the faction sits *inside* the noun
        # phrase: "a row for {faction}" and "the damage {other_faction} is soaking up" are both correct, because a
        # preposition or a verb ends the phrase before the slot.
        for match in re.finditer(r"\b(the|a|an)\s+((?:\w+\s+){0,2})\{((?:other_)?faction)\}(\s+\w+)?", text, re.I):
            between, after = match.group(2).lower().split(), (match.group(4) or "").strip().lower()
            if any(word in PREPOSITIONS for word in between) or after in VERBS or not after:
                continue
            errors.append("%s: %r puts an article before a faction name, which already has one; "
                          "use {%s_attr}" % (where, match.group(0).strip(), match.group(3)))
        for match in re.finditer(r"\{(?:other_)?faction\}\s+(\w+)", text):
            if match.group(1).lower() in SINGULAR_VERBS:
                errors.append("%s: a faction takes a plural verb (%r): \"the Condemned take it\", not \"takes\""
                              % (where, match.group(0)))
        for match in COLOUR_NAMES.finditer(re.sub(r"\{[a-z_]+\}", "", text)):
            if match.group(1) and match.group(1).islower():
                continue  # "rust" the substance, "red" the colour of something
            errors.append("%s: %r names a side by colour; the booth names sides by faction (X3)" % (where, match.group(0)))
        for slot in re.findall(r"\{([a-z_]+)\}", text):
            if slot in COLOUR_SLOTS:
                errors.append("%s: {%s} speaks a colour; use {%s} (sides are named by faction)"
                              % (where, slot, slot.replace("team", "faction")))
        for faction, pattern in FACTION_AS_SIDE.items():
            if pattern.search(text) and not {"faction_" + faction, "other_faction_" + faction} & set(tags):
                errors.append("%s: names %s as a side without a faction_%s or other_faction_%s tag, so it can play "
                              "in a match they are not in" % (where, faction, faction, faction))
        # A faction is plural all the way through its own clause: "the Condemned hit their own", never "its own".
        # `its` is fine when something else owns it ("this crowd is on its feet", "the artillery finds its mark"), so
        # only an `its` before the next full stop, with no other subject in between, counts.
        # Not {faction_s}: a possessive hands the sentence to whatever it owns ("the Wreckers' scout lands one on
        # its own" is right), so only a faction as the subject counts.
        for match in re.finditer(r"\{(?:other_)?faction\}([^.!?]*?)\bits\b", text):
            between = match.group(1).lower()
            if re.search(r"\b(crowd|artillery|building|arena|floor|scout|tank|lancer|burner|machine|vehicle|gun|"
                         r"turret|shell|beam|and|but|while)\b", between):
                continue
            errors.append("%s: a faction is plural all the way through the sentence (%r -> \"their\")"
                          % (where, match.group(0).strip()))
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
        if speaker == "pa" and line.get("added"):
            errors.extend(audit_oddity(line, categories))
        if speaker == "pa" and isinstance(line.get("oddity"), dict):
            for kind in line_kinds:
                key = (kind, line["oddity"].get("category"))
                if key in oddity_seen:
                    errors.append("%s: the same kind of wrong detail (%s) as %s in the %s pool"
                                  % (where, key[1], oddity_seen[key], kind))
                oddity_seen.setdefault(key, where)
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
