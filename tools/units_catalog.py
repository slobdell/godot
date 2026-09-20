"""Read `game/units/units.gd` as data: the ONE Python reader for the unit catalog (contract C1).

Invariant 0 in `_agents/workstreams.md`: *a value with a single owner is READ, not mirrored.* Before round 9
`tools/arena_report.py` carried its own three-line regex for `hull_size`; `tools/roster_scale.py` would have been the
second. Both now call this module, so there is one parser to mutation-check instead of one per tool.

**It raises rather than falling back.** A reader that returns a hard-coded list when the parse breaks restores the
exact bug it was written to prevent, silently (Invariant 0, first clause). Every failure here is a `CatalogError`.

The parser is deliberately dumb: GDScript's dictionary/array literals are JSON-ish, so it strips comments, walks
balanced braces, and evaluates the literals it finds. It understands what `units.gd` actually contains — strings,
floats, ints, `true`/`false`, arrays, dictionaries — and refuses anything else (an expression, a constant reference)
rather than guessing.
"""

from __future__ import annotations

import pathlib
import re

UNITS_GD = pathlib.Path(__file__).resolve().parent.parent / "game" / "units" / "units.gd"


class CatalogError(RuntimeError):
    """The catalog could not be read. Never swallowed, never defaulted."""


# ---- lexing ---------------------------------------------------------------------------------------------------

def _strip_comments(source: str) -> str:
    """Blank out `#` comments, leaving string literals alone (a `#` inside a blurb is not a comment)."""
    out = []
    in_string = False
    quote = ""
    i = 0
    while i < len(source):
        c = source[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < len(source):
                out.append(source[i + 1])
                i += 2
                continue
            if c == quote:
                in_string = False
            i += 1
            continue
        if c in "\"'":
            in_string, quote = True, c
            out.append(c)
            i += 1
            continue
        if c == "#":
            while i < len(source) and source[i] != "\n":
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _match_brace(text: str, start: int) -> int:
    """Index just past the `{`/`[` opened at `start`, skipping string literals."""
    opens = {"{": "}", "[": "]"}
    close = opens[text[start]]
    depth = 0
    i = start
    in_string = False
    quote = ""
    while i < len(text):
        c = text[i]
        if in_string:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                in_string = False
            i += 1
            continue
        if c in "\"'":
            in_string, quote = True, c
        elif c in opens:
            depth += 1
        elif c in "}]":
            depth -= 1
            if depth == 0:
                if c != close:
                    raise CatalogError("mismatched brackets near offset %d in units.gd" % start)
                return i + 1
        i += 1
    raise CatalogError("unterminated %s at offset %d in units.gd" % (text[start], start))


def _split_top_level(body: str) -> list[str]:
    """`a, b, c` -> [a, b, c], ignoring commas inside nested literals and strings."""
    parts: list[str] = []
    depth = 0
    in_string = False
    quote = ""
    current = []
    i = 0
    while i < len(body):
        c = body[i]
        if in_string:
            current.append(c)
            if c == "\\" and i + 1 < len(body):
                current.append(body[i + 1])
                i += 2
                continue
            if c == quote:
                in_string = False
            i += 1
            continue
        if c in "\"'":
            in_string, quote = True, c
        elif c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(current))
            current = []
            i += 1
            continue
        current.append(c)
        i += 1
    parts.append("".join(current))
    return [p.strip() for p in parts if p.strip()]


_STRING = re.compile(r'^"((?:[^"\\]|\\.)*)"$|^\'((?:[^\'\\]|\\.)*)\'$', re.S)
_NUMBER = re.compile(r"^[-+]?(\d+\.\d*|\.\d+|\d+)(e[-+]?\d+)?$", re.I)


def _value(text: str):
    """One GDScript literal as a Python value. Raises on anything that is not a literal."""
    text = text.strip()
    if not text:
        raise CatalogError("empty value in units.gd")
    if text[0] == "{":
        if _match_brace(text, 0) != len(text):
            raise CatalogError("trailing text after a dictionary in units.gd: %r" % text[:60])
        return _dict_entries(text[1:-1])
    if text[0] == "[":
        if _match_brace(text, 0) != len(text):
            raise CatalogError("trailing text after an array in units.gd: %r" % text[:60])
        return [_value(p) for p in _split_top_level(text[1:-1])]
    m = _STRING.match(text)
    if m:
        raw = m.group(1) if m.group(1) is not None else m.group(2)
        return raw.encode("utf-8").decode("unicode_escape")
    if text in ("true", "false"):
        return text == "true"
    if text == "null":
        return None
    if _NUMBER.match(text):
        return float(text) if ("." in text or "e" in text.lower()) else int(text)
    raise CatalogError("units.gd holds a value this reader does not understand: %r. It is not a literal, so the "
                       "catalog can no longer be read as data -- fix the reader, do not guess." % text[:80])


def _dict_entries(body: str) -> dict:
    out = {}
    for part in _split_top_level(body):
        head, sep, tail = _split_key(part)
        if not sep:
            raise CatalogError("dictionary entry without a `:` in units.gd: %r" % part[:60])
        out[_value(head)] = _value(tail)
    return out


def _split_key(part: str):
    """Split `"key": value` at the first top-level `:` (a `:` inside a blurb or a nested literal is not it)."""
    depth = 0
    in_string = False
    quote = ""
    i = 0
    while i < len(part):
        c = part[i]
        if in_string:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                in_string = False
            i += 1
            continue
        if c in "\"'":
            in_string, quote = True, c
        elif c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
        elif c == ":" and depth == 0:
            return part[:i], ":", part[i + 1:]
        i += 1
    return part, "", ""


# ---- the catalog ----------------------------------------------------------------------------------------------

def _const_literal(source: str, name: str) -> str:
    m = re.search(r"^const\s+%s\s*:?=\s*" % re.escape(name), source, re.M)
    if not m:
        raise CatalogError("units.gd has no `const %s` any more. This reader is stale -- fix it rather than "
                           "falling back to a copy of the values." % name)
    start = m.end()
    while start < len(source) and source[start] in " \t":
        start += 1
    if source[start] not in "{[":
        raise CatalogError("`const %s` is no longer a literal in units.gd" % name)
    return source[start:_match_brace(source, start)]


def load(path: pathlib.Path | None = None) -> dict:
    """`{unit id: profile dict}` exactly as `Units.PROFILES` holds it."""
    text = (path or UNITS_GD).read_text()
    profiles = _value(_const_literal(_strip_comments(text), "PROFILES"))
    if not isinstance(profiles, dict) or not profiles:
        raise CatalogError("units.gd's PROFILES parsed to nothing")
    for unit_id, profile in profiles.items():
        if not isinstance(profile, dict) or "hull_size" not in profile:
            raise CatalogError("%s has no hull_size: the parse is wrong, not the catalog" % unit_id)
    return profiles


def const_float(name: str, path: pathlib.Path | None = None) -> float:
    """A scalar `const` from units.gd (e.g. RIG_LENGTH_M), read not copied."""
    text = _strip_comments((path or UNITS_GD).read_text())
    m = re.search(r"^const\s+%s\s*:?=\s*([^\n#]+)$" % re.escape(name), text, re.M)
    if not m:
        raise CatalogError("units.gd has no `const %s`" % name)
    return float(_value(m.group(1).strip()))


def hull_lengths(path: pathlib.Path | None = None) -> dict:
    """`{unit id: hull length in metres}` from `hull_size [w, h, l]`."""
    return {unit_id: float(p["hull_size"][2]) for unit_id, p in load(path).items()}
