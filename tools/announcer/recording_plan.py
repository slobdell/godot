"""What to record for the announcer's line library: requests to the voice service, and the clips cut from them.

Every line is recorded as a whole sentence (natural delivery). A line with slots ("{team} takes out the
{victim_unit}!") is recorded once with sample values and sliced at word boundaries into carrier segments
("#0" = "takes out the", ...); at runtime the director's slot values are played from filler clips between them.
Fillers are recorded inside short carrier sentences for each intonation a slot appears in (mid-sentence, final,
rising) and sliced out, so "Rust" at the end of a sentence sounds like the end of a sentence
(game_design.md "Recording tricks for natural stitching").

A request: {id, speaker, text, previous_text, next_text, slices: [{clip, start, end, text, kind}]}; start/end are
character offsets into text. The plan also maps each line to its parts for playback:
[{"clip": id} | {"slot": name, "vocab": kind, "intonation": mid|final|rising}].
"""

from __future__ import annotations

import re

SLOT = re.compile(r"\{([a-z_]+)\}")
# Slot name -> vocabulary kind (mirrors AnnouncerLibrary.slot_kind in game/announcer/announcer_library.gd).
SLOT_VOCAB = {"team": "team", "other_team": "team", "team_s": "team_s", "other_team_s": "team_s",
              "unit": "unit", "killer_unit": "unit", "victim_unit": "unit", "target_unit": "unit", "shooter_unit": "unit",
              "units": "units", "other_units": "units", "arena": "arena",
              "count": "number", "other_count": "number", "streak": "number", "kills": "number"}
NUMBER_WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
# The number values a match can produce: units alive (0-10), streaks, merged kills.
NUMBER_VALUES = [str(n) for n in range(0, 11)]
# Carrier sentences for fillers; {x} is sliced out. Chosen so the word sits where its intonation says.
CARRIERS = {
    "mid": "And {x} keeps coming.",
    "final": "That one goes to {x}.",
    "rising": "Is that {x}?",
}
CARRIERS_BY_VOCAB = {
    "number": {"mid": "And {x} more are coming.", "final": "That makes {x}.", "rising": "Is it {x}?"},
    "team_s": {"mid": "And {x} crew keeps coming.", "final": "That one was {x}.", "rising": "Was that {x}?"},
    "units": {"mid": "And the {x} keep coming.", "final": "Look at all those {x}.", "rising": "Are those {x}?"},
    "arena": {"mid": "Live from {x} tonight.", "final": "Welcome to {x}.", "rising": "Are we in {x}?"},
}


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


def spoken_line(line: dict, vocabulary: dict, rotation: int) -> tuple[str, list[dict]]:
    """The text to record for a line (sample slot values filled in) and each slot's span in it."""
    out, spans, cursor = "", [], 0
    for number, match in enumerate(SLOT.finditer(line["text"])):
        out += line["text"][cursor:match.start()]
        name = match.group(1)
        kind = SLOT_VOCAB[name]
        values = vocabulary_values(vocabulary, kind)
        keys = sorted(values)
        value = "2" if kind == "number" else keys[(rotation + number) % len(keys)]
        spoken = values[value]
        if match.start() == 0 or line["text"][:match.start()].rstrip().endswith((".", "!", "?")):
            spoken = spoken[0].upper() + spoken[1:]
        spans.append({"slot": name, "vocab": kind, "start": len(out), "end": len(out) + len(spoken),
                      "intonation": intonation_after(line["text"], match.end())})
        out += spoken
        cursor = match.end()
    return out + line["text"][cursor:], spans


def _trimmed(text: str, start: int, end: int) -> tuple[int, int]:
    # Punctuation right after a slot is spoken with the slot word ("scout!"), so a segment never starts with it.
    while start < end and text[start] in " ,.!?;:":
        start += 1
    while end > start and text[end - 1] == " ":
        end -= 1
    return start, end


def plan(lines_data: dict, speakers: list[str] | None = None, only: set | None = None) -> dict:
    """{requests: [...], lines: {line_id: {speaker, parts}}, fillers: {clip: {...}}}

    `speakers` and `only` (line ids) narrow what is recorded; the whole library still provides context (the question
    an answer is stitched to, the sample values), so a line's request is the same however it was selected."""
    vocabulary = lines_data.get("vocabulary", {})
    requests, line_parts, needed_fillers = [], {}, {}
    topic_questions = {}
    for line in lines_data["lines"]:
        if line["act"] == "setup_question" and line.get("topic"):
            topic_questions.setdefault(line["topic"], line["text"])
    for index, line in enumerate(lines_data["lines"]):
        if speakers and line["speaker"] not in speakers or only and line["id"] not in only:
            continue
        text, spans = spoken_line(line, vocabulary, index)
        slices, parts, cursor = [], [], 0
        for number, span in enumerate(spans + [None]):
            stop = span["start"] if span else len(text)
            start, end = _trimmed(text, cursor, stop)
            if re.search(r"[A-Za-z]", text[start:end]):
                clip = line["id"] if not spans else "%s#%d" % (line["id"], len(slices))
                slices.append({"clip": clip, "start": start, "end": end, "text": text[start:end],
                               "kind": "line" if not spans else "segment"})
                parts.append({"clip": clip})
            if span:
                parts.append({"slot": span["slot"], "vocab": span["vocab"], "intonation": span["intonation"]})
                needed_fillers[(line["speaker"], span["vocab"], span["intonation"])] = True
                cursor = span["end"]
        request = {"id": line["id"], "speaker": line["speaker"], "text": text, "slices": slices}
        # Request stitching: an answer sounds like an answer when the model knows the question.
        if line["act"].startswith("answer") and line.get("topic") in topic_questions:
            request["previous_text"] = topic_questions[line["topic"]]
        requests.append(request)
        line_parts[line["id"]] = {"speaker": line["speaker"], "parts": parts}
    fillers = {}
    for speaker, kind, intonation in sorted(needed_fillers):
        carrier = CARRIERS_BY_VOCAB.get(kind, CARRIERS)[intonation]
        for value, spoken in sorted(vocabulary_values(vocabulary, kind).items()):
            text = carrier.replace("{x}", spoken)
            if carrier.startswith("{x}"):
                text = text[0].upper() + text[1:]
            start = carrier.index("{x}")
            clip = filler_clip(speaker, kind, value, intonation)
            requests.append({"id": clip, "speaker": speaker, "text": text,
                             "slices": [{"clip": clip, "start": start, "end": start + len(spoken), "text": spoken, "kind": "filler"}]})
            fillers[clip] = {"speaker": speaker, "vocab": kind, "value": value, "intonation": intonation, "text": spoken}
    return {"requests": requests, "lines": line_parts, "fillers": fillers}


def filler_clip(speaker: str, kind: str, value: str, intonation: str) -> str:
    return "fill.%s.%s.%s.%s" % (speaker, kind, value, intonation)


def summarize(the_plan: dict) -> dict:
    """Per speaker: requests, clips, characters sent."""
    summary = {}
    for request in the_plan["requests"]:
        row = summary.setdefault(request["speaker"], {"requests": 0, "clips": 0, "characters": 0})
        row["requests"] += 1
        row["clips"] += len(request["slices"])
        row["characters"] += len(request["text"])
    return summary
