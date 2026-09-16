"""What to record for the announcer's line library: one whole sentence per thing the booth can actually say.

A line with no slots is recorded once. A line with slots ("{team} takes out the {victim_unit}!") is recorded once
**for every combination of values it can take** — "Green takes out the IFV!", "Rust takes out the scout!", and so
on. Nothing is sliced and nothing is stitched at runtime: a cue plays exactly one clip.

That replaces the carrier-and-filler scheme of rounds 3-4. It was cut at word boundaries and levelled carefully and
it still sounded pasted, because a sentence's intonation spans the whole sentence: a word lifted out of one
recording carries the wrong pitch, stress and length into another. The lead heard it immediately
(_agents/streams/audio.md, *Why stitching failed*). No amount of tuning the cuts fixes prosody.

The cost is combinations, so the library's writing rules keep them small: one variable thing per sentence, no exact
numbers, and teams (2 values) and arenas (3) are cheap enough to record whole. [constant MAX_COMBINATIONS] is the
backstop — a line over it is a writing bug, and `plan()` reports it rather than quietly ordering 676 recordings.

A request: {id, speaker, text, previous_text?, slices: [{clip, start, end, text, kind: "line"}]}. The single slice
spans the whole text; `generate.py` still cuts it, which is what trims silence and levels the clip.
The plan maps each line to its variants: {line_id: {speaker, variants: {key: clip_id}}}, where `key` is
[func variant_key] over the slot values.
"""

from __future__ import annotations

import itertools
import re

SLOT = re.compile(r"\{([a-z_]+)\}")
# Slot name -> vocabulary kind (mirrors AnnouncerLibrary.slot_kind in game/announcer/announcer_library.gd).
SLOT_VOCAB = {"team": "team", "other_team": "team", "team_s": "team_s", "other_team_s": "team_s",
              "faction": "faction", "other_faction": "faction",
              "faction_s": "faction_s", "other_faction_s": "faction_s",
              "faction_attr": "faction_attr", "other_faction_attr": "faction_attr",
              "unit": "unit", "killer_unit": "unit", "victim_unit": "unit", "target_unit": "unit", "shooter_unit": "unit",
              "units": "units", "other_units": "units", "arena": "arena",
              "count": "number", "other_count": "number", "streak": "number", "kills": "number",
              "count_over": "count_over", "other_count_over": "count_over",
              "formation": "formation", "technique": "technique", "drill": "drill"}
NUMBER_WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
# The number values a match can produce. Numbers are the most expensive slot there is (eleven values), and at
# thirty units a side an exact count is wrong as often as it is right: the library's rule is to say "half their
# force" rather than a number. This stays small so a stray {count} cannot quietly cost a fortune.
NUMBER_VALUES = [str(n) for n in range(0, 6)]
## A line needing more recordings than this is a writing bug, not a budget decision: it names more than one
## variable thing. plan() collects them under "too_many" instead of ordering them.
MAX_COMBINATIONS = 24


def vocabulary_values(vocabulary: dict, kind: str) -> dict:
    """value -> spoken text for a vocabulary kind."""
    if kind == "number":
        return {value: NUMBER_WORDS[int(value)] for value in NUMBER_VALUES}
    return dict(vocabulary.get(kind, {}))


def intonation_after(text: str, end: int) -> str:
    """How a slot ending at `end` is voiced: rising before '?', final before '.' or '!', else mid."""
    rest = text[end:].lstrip()
    if rest.startswith("?"):
        return "rising"
    if rest[:1] in (".", "!") or rest == "":
        return "final"
    return "mid"


def base_slot(slot: str) -> str:
    """The value a text slot reads: {team_s} ("Green's") and {team} ("Green") are the same underlying team.
    Mirrors AnnouncerLibrary.base_slot in game/announcer/announcer_library.gd."""
    for suffix in ("_attr", "_s"):
        if slot.endswith(suffix) and slot[:-len(suffix)] in ("team", "other_team", "faction", "other_faction"):
            return slot[:-len(suffix)]
    return slot


def normalize_value(value) -> str:
    """One slot value as it appears in a clip id. Numbers are written as integers on both sides of the wire, so
    GDScript's 3.0 and Python's "3" agree."""
    text = str(value)
    try:
        return str(int(float(text)))
    except (TypeError, ValueError):
        return text


def variant_key(slots: dict, bases: list[str]) -> str:
    """The part of a clip id that says which realization this is: the slot values, in sorted base-slot order.
    Must match AnnouncerLibrary.variant_key exactly, or the game asks for clips that were never recorded."""
    return ".".join(normalize_value(slots.get(base, "")) for base in bases)


def variant_clip(line_id: str, key: str) -> str:
    return line_id if not key else "%s@%s" % (line_id, key)


def line_bases(text: str) -> list[str]:
    """The distinct underlying slots a line reads, sorted, so every side computes the same key."""
    return sorted({base_slot(name) for name in SLOT.findall(text)})


def realizations(line: dict, vocabulary: dict) -> list[dict]:
    """Every whole sentence this line can become: [{key, text, slots}], one per combination of its slot values."""
    text = line["text"]
    bases = line_bases(text)
    if not bases:
        return [{"key": "", "text": text, "slots": {}}]
    # Each base slot draws from the vocabulary of whichever text slot reads it (they always agree by construction).
    choices = []
    for base in bases:
        name = next(n for n in SLOT.findall(text) if base_slot(n) == base)
        choices.append(sorted(vocabulary_values(vocabulary, SLOT_VOCAB[name])))
    out = []
    for combination in itertools.product(*choices):
        slots = dict(zip(bases, combination))
        if not plausible(slots):
            continue
        out.append({"key": variant_key(slots, bases), "text": fill(text, slots, vocabulary), "slots": slots})
    return out


def plausible(slots: dict) -> bool:
    """Whether a combination can actually happen in a match. A line naming both teams always means opposite ones,
    so "Green ... Green" is a recording nobody will ever play - half the combinations of every such line."""
    for side in ("team", "faction"):
        other = "other_" + side
        # The lead, 2026-09-16: matches are strictly between different factions, so "the Law ... the Law" is a
        # recording nobody will ever play - and for factions that is three quarters of the combinations.
        if side in slots and other in slots and slots[side] == slots[other]:
            return False
    return True


def fill(text: str, slots: dict, vocabulary: dict) -> str:
    """The line with its slots spoken, capitalized where a slot starts a sentence (as AnnouncerLibrary.fill does)."""
    out, cursor = "", 0
    for match in SLOT.finditer(text):
        out += text[cursor:match.start()]
        name = match.group(1)
        spoken = vocabulary_values(vocabulary, SLOT_VOCAB[name]).get(slots[base_slot(name)], "")
        if match.start() == 0 or text[:match.start()].rstrip().endswith((".", "!", "?")):
            spoken = spoken[:1].upper() + spoken[1:]
        out += spoken
        cursor = match.end()
    return out + text[cursor:]


def plan(lines_data: dict, speakers: list[str] | None = None, only: set | None = None) -> dict:
    """{requests: [...], lines: {line_id: {speaker, variants: {key: clip}}}, too_many: [...]}

    One request per whole sentence. `speakers` and `only` (line ids) narrow what is recorded; the whole library
    still provides context (the question an answer is recorded against), so a line's request is the same however
    it was selected. Lines over MAX_COMBINATIONS are reported in `too_many` and not ordered."""
    vocabulary = lines_data.get("vocabulary", {})
    requests, line_variants, too_many = [], {}, []
    topic_questions = {}
    for line in lines_data["lines"]:
        if line["act"] == "setup_question" and line.get("topic"):
            topic_questions.setdefault(line["topic"], line["text"])
    for line in lines_data["lines"]:
        if speakers and line["speaker"] not in speakers or only and line["id"] not in only:
            continue
        spoken = realizations(line, vocabulary)
        if len(spoken) > MAX_COMBINATIONS:
            too_many.append({"id": line["id"], "combinations": len(spoken), "text": line["text"],
                             "slots": line_bases(line["text"])})
            continue
        variants = {}
        for realization in spoken:
            clip = variant_clip(line["id"], realization["key"])
            request = {"id": clip, "speaker": line["speaker"], "text": realization["text"],
                       "slices": [{"clip": clip, "start": 0, "end": len(realization["text"]),
                                   "text": realization["text"], "kind": "line"}]}
            # Request stitching: an answer sounds like an answer when the model knows the question.
            if line["act"].startswith("answer") and line.get("topic") in topic_questions:
                request["previous_text"] = topic_questions[line["topic"]]
            requests.append(request)
            variants[realization["key"]] = clip
        line_variants[line["id"]] = {"speaker": line["speaker"], "variants": variants,
                                     "bases": line_bases(line["text"])}
    return {"requests": requests, "lines": line_variants, "too_many": too_many}


def summarize(the_plan: dict) -> dict:
    """Per speaker: requests, clips, characters sent."""
    summary = {}
    for request in the_plan["requests"]:
        row = summary.setdefault(request["speaker"], {"requests": 0, "clips": 0, "characters": 0})
        row["requests"] += 1
        row["clips"] += len(request["slices"])
        row["characters"] += len(request["text"])
    return summary
