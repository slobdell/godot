#!/usr/bin/env python3
"""Round 36 (N5, native): the census gap lint. Round 35 lost reads to a counter added to a rule but not to the series'
printed line (R35.35: `face_settles` was in Manoeuvre, not in `ManoeuvreCensus.counters()`, so the series' rows could not
show the bar's (o2)). This finds that before a series runs.

usage: census_lint.py [REPO]        (default: this repo)

A COUNTER is a public `static var <name> := 0` (or `: int = 0`) in one of COUNTER_SOURCES that some game script increments
(`<name> += `). It is ON A SERIES LINE when a series script prints it: a census, probe or stage script under tests/
(`*census*.gd`, `*probe*.gd`, `*stage*.gd`) reads it directly (`Movement.stall_net_holds`), or calls a static report that
reaches it (`Movement.route_arms()` -> `ManoeuvreCensus.report()` -> `counters()` ...: every static func the report's body
calls, followed through the classes below).

Fails (exit 1) when:
  - a counter is on no series line and not in ALLOWED (a new counter nobody prints: add it to the report its series prints,
    or to ALLOWED with the reason and owner); or
  - a counter IS on a series line but still in ALLOWED (the allowance is stale: remove it); or
  - a counter in ALLOWED is NAMED IN A BAR: `name` in backticks in _agents/workstreams.md or a live brief
    (_agents/streams/*.md, not archive/): a bar that reads a counter its series never prints cannot be read.
Prints every counter's place, then `census lint: N counters, M on a series line, K allowed, F failures`."""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# class -> its script (reports are followed through these; counters are read from COUNTER_SOURCES)
CLASSES = {"Movement": "game/ai/movement.gd", "Manoeuvre": "game/ai/manoeuvre.gd", "ManoeuvreCensus": "game/ai/manoeuvre_census.gd",
           "Traffic": "game/ai/traffic.gd", "PlannerSeam": "game/ai/planner/planner_seam.gd"}
COUNTER_SOURCES = ("Movement", "Manoeuvre", "Traffic", "ManoeuvreCensus")
SERIES_FILES = ("census", "probe", "stage")
# Counters no series prints today, each with its reason and owner. A bar may not name one (see above).
ALLOWED = {
    "Manoeuvre.turn_in_ticks": "manoeuvre: the scout orbit's turn-in, read by test_manoeuvre_orbit only (no series)",
    "Manoeuvre.turn_in_stalls": "manoeuvre: as turn_in_ticks",
    "Manoeuvre.turn_in_leashed": "manoeuvre: as turn_in_ticks",
    "Manoeuvre.turn_in_holds": "manoeuvre: as turn_in_ticks",
    "Manoeuvre.turn_in_stops": "manoeuvre: as turn_in_ticks",
}


def body(text, fn):
    m = re.search(r"^static func %s\(.*$" % re.escape(fn), text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    end = re.search(r"^\S", rest, re.M)
    return rest[:end.start()] if end else rest


def lint(repo):
    texts = {}
    for cls, rel in CLASSES.items():
        path = os.path.join(repo, rel)
        texts[cls] = open(path).read() if os.path.exists(path) else ""
    names = "|".join(CLASSES)
    reached, todo, roots = set(), [], set()
    for path in glob.glob(os.path.join(repo, "tests", "**", "*.gd"), recursive=True):
        if not any(k in os.path.basename(path) for k in SERIES_FILES):
            continue
        src = open(path).read()
        reached.update(re.findall(r"\b(%s)\.([a-z_]\w*)\b(?!\s*\()" % names, src))
        for cls, fn in re.findall(r"\b(%s)\.([a-z_]\w*)\s*\(" % names, src):
            if re.search(r"^static func %s\(.*->\s*Dictionary" % re.escape(fn), texts[cls], re.M):
                todo.append((cls, fn))
                roots.add("%s.%s()" % (cls, fn))
    followed = set()
    while todo:
        cls, fn = todo.pop()
        if (cls, fn) in followed:
            continue
        followed.add((cls, fn))
        b = body(texts.get(cls, ""), fn)
        for other, name in re.findall(r"\b(?:(%s)\.)?([a-z_]\w*)\b" % names, b):
            reached.add((other or cls, name))
        for other, name in re.findall(r"\b(?:(%s)\.)?([a-z_]\w*)\s*\(" % names, b):
            todo.append((other or cls, name))
    incremented = set()
    for p in glob.glob(os.path.join(repo, "game", "**", "*.gd"), recursive=True):
        incremented.update(re.findall(r"\b([a-z][a-z_0-9]*)\s*\+=", open(p).read()))
    counters = []
    for cls in COUNTER_SOURCES:
        for name in re.findall(r"^static var ([a-z][a-z_0-9]*)\s*(?::=\s*0\b|:\s*int\s*=\s*0\b)", texts[cls], re.M):
            if name in incremented:
                counters.append(("%s.%s" % (cls, name), (cls, name) in reached))
    docs = [os.path.join(repo, "_agents", "workstreams.md")] + sorted(glob.glob(os.path.join(repo, "_agents", "streams", "*.md")))
    named = set()
    for path in docs:
        if os.path.exists(path):
            named.update(re.findall(r"`(?:[A-Z]\w+\.)?([a-z][a-z_0-9]*)`", open(path).read()))
    failures = []
    for key, on_line in counters:
        short = key.split(".", 1)[1]
        if on_line and key in ALLOWED:
            failures.append("%s is on a series line now: remove its ALLOWED entry" % key)
        elif not on_line and key not in ALLOWED:
            failures.append("%s is on no series line (none of %s reaches it): print it in its series' report, or ALLOW it "
                            "with the reason and owner" % (key, ", ".join(sorted(roots)) or "no report"))
        elif not on_line and short in named:
            failures.append("%s is named in a bar (`%s` in _agents/) but no series prints it (%s)" % (key, short, ALLOWED[key]))
    for key in sorted(set(ALLOWED) - {k for k, _ in counters}):
        failures.append("%s is ALLOWED but is no longer a counter: remove the entry" % key)
    return counters, roots, failures


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(HERE)
    counters, roots, failures = lint(repo)
    for key, on_line in counters:
        print("  %-44s %s" % (key, "on a series line" if on_line else "ALLOWED: " + ALLOWED.get(key, "NO")))
    for f in failures:
        print("census lint FAIL: " + f)
    print("census lint: %d counters, %d on a series line, %d allowed, %d failures (reports followed from %s)" % (
        len(counters), sum(1 for _, on in counters if on), sum(1 for k, on in counters if not on and k in ALLOWED),
        len(failures), ", ".join(sorted(roots))))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
