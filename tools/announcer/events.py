#!/usr/bin/env python3
"""K5 match-event validator (tests/announcer/fixtures/README.md is the contract).

    python3 tools/announcer/events.py tests/announcer/fixtures/*.jsonl

Exits non-zero and prints every problem when a timeline breaks the contract. The GDScript twin
(game/announcer/announcer_events.gd) must accept and reject the same timelines.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

TEAMS = ("green", "rust")
UNIT_TYPES = ("scout", "tank", "ifv", "artillery", "lancer", "burner")
TICKS_PER_SECOND = 60

# type -> {field: kind}. Kinds: int, num, str, bool, team, unit, ratio, id, team_map_ratio, team_map_int, special.
REQUIRED: dict[str, dict[str, str]] = {
    "match_start": {"arena": "str", "budget": "int", "teams": "special"},
    "first_contact": {"team": "team", "unit_id": "id", "unit": "unit", "target_id": "id", "target_unit": "unit"},
    "damage": {"shooter": "id", "shooter_unit": "unit", "victim": "id", "victim_unit": "unit",
               "hull": "ratio", "shield": "ratio", "critical": "bool"},
    "unit_destroyed": {"victim": "id", "victim_unit": "unit", "victim_team": "team", "killer": "str",
                       "killer_unit": "str", "killer_team": "str", "friendly": "bool"},
    "friendly_fire": {"shooter": "id", "shooter_unit": "unit", "victim": "id", "victim_unit": "unit",
                      "team": "team", "hull": "ratio", "killed": "bool"},
    "close_call": {"unit_id": "id", "unit": "unit", "team": "team", "hull_left": "ratio"},
    "control_changed": {"owner": "owner"},
    "squad_wiped": {"team": "team", "squad": "str"},
    "momentum": {"army_health": "team_map_ratio"},
    "match_end": {"winner": "winner", "reason": "reason", "duration_seconds": "num",
                  "units_left": "team_map_int", "kills_by_unit": "special"},
    # L1, from doctrine (2026-09-16): why an element is lining up the way it is. `reason` is the doctrine table's
    # own words — a subtitle and the demo page's "why", never spoken, since every spoken word must be recorded.
    "element_formation": {"team": "team", "element": "str", "size": "int", "reason": "str",
                          "formation": "str", "technique": "str", "changed": "special"},
    "element_drill": {"team": "team", "element": "str", "size": "int", "reason": "str",
                      "drill": "str", "formation": "str", "distance": "num", "target": "str"},
}
EVENT_TYPES = tuple(REQUIRED)

# Fields that may name a unit that is already gone. A shell outlives the crew that fired it — Shell keeps the
# shooter's *name* and Match looks it up when the round lands, handling the null — so a vehicle really can be
# killed by something that died first. Everything else stays strict, so a unit dying twice, or being targeted
# after death, is still caught. (Diagnosed by the ai stream, 2026-09-16: rare until brains started firing to
# suppress, which puts far more rounds in the air when a shooter dies.)
MAY_BE_DEAD = ("shooter", "killer")


# Fields that may legitimately name a unit that is already destroyed: a shell outlives the vehicle that fired it, so
# a crew can be killed by someone who died first. That has always been possible and became common in round 4, when
# brains started firing to suppress and machine guns began hosing ground continuously.
MAY_BE_DEAD = ("shooter", "killer")


def _kind_error(value, kind: str) -> str:
    """Returns "" when value is of kind, else a short description of what was expected."""
    is_num = isinstance(value, (int, float)) and not isinstance(value, bool)
    if kind == "int":
        return "" if isinstance(value, int) and not isinstance(value, bool) else "an integer"
    if kind == "num":
        return "" if is_num and value >= 0 else "a non-negative number"
    if kind in ("str", "id"):
        if not isinstance(value, str):
            return "a string"
        return "a non-empty id" if kind == "id" and value == "" else ""
    if kind == "bool":
        return "" if isinstance(value, bool) else "true or false"
    if kind == "team":
        return "" if value in TEAMS else "green or rust"
    if kind == "owner":
        return "" if value in TEAMS + ("neutral",) else "green, rust, or neutral"
    if kind == "winner":
        return "" if value in TEAMS + ("draw",) else "green, rust, or draw"
    if kind == "reason":
        return "" if value in ("elimination", "control", "time") else "elimination, control, or time"
    if kind == "unit":
        return "" if value in UNIT_TYPES else "a unit type (%s)" % ", ".join(UNIT_TYPES)
    if kind == "ratio":
        return "" if is_num and 0.0 <= value <= 1.0 else "a ratio 0..1"
    if kind in ("team_map_ratio", "team_map_int"):
        if not isinstance(value, dict) or sorted(value) != sorted(TEAMS):
            return "an object with exactly green and rust"
        inner = "ratio" if kind == "team_map_ratio" else "int"
        return "" if all(_kind_error(value[t], inner) == "" for t in TEAMS) else "green and rust as %s" % inner
    return ""


def validate_event(event, index: int = 0) -> list[str]:
    """Problems with one event on its own (shape and field kinds)."""
    where = "event %d" % index
    if not isinstance(event, dict):
        return ["%s: not a JSON object" % where]
    problems = []
    for field, kind in (("tick", "int"), ("t", "num"), ("type", "str")):
        if field not in event:
            problems.append("%s: missing %s" % (where, field))
        elif _kind_error(event[field], kind):
            problems.append("%s: %s must be %s" % (where, field, _kind_error(event[field], kind)))
    if problems:
        return problems
    if event["tick"] < 0:
        problems.append("%s: tick must be >= 0" % where)
    kind_of = event["type"]
    if kind_of not in REQUIRED:
        return problems + ["%s: unknown type %r" % (where, kind_of)]
    where = "event %d (%s)" % (index, kind_of)
    for field, kind in REQUIRED[kind_of].items():
        if field not in event:
            problems.append("%s: missing %s" % (where, field))
        elif kind != "special" and _kind_error(event[field], kind):
            problems.append("%s: %s must be %s" % (where, field, _kind_error(event[field], kind)))
    if problems:
        return problems
    if kind_of == "match_start":
        problems += _check_teams(event["teams"], where)
    elif kind_of == "match_end":
        problems += _check_kills(event["kills_by_unit"], where)
    elif kind_of == "unit_destroyed":
        hazard = event["killer"] == ""
        if hazard and (event["killer_unit"] or event["killer_team"]):
            problems.append("%s: a hazard kill has empty killer, killer_unit, and killer_team" % where)
        if not hazard and (_kind_error(event["killer_unit"], "unit") or _kind_error(event["killer_team"], "team")):
            problems.append("%s: killer_unit and killer_team must name a unit type and team" % where)
        if not hazard and event["friendly"] != (event["killer_team"] == event["victim_team"]):
            problems.append("%s: friendly must be true exactly when killer_team == victim_team" % where)
    return problems


def _check_teams(teams, where: str) -> list[str]:
    if not isinstance(teams, list) or len(teams) != 2:
        return ["%s: teams must be a list of two teams" % where]
    problems = []
    seen_teams = []
    for team in teams:
        if not isinstance(team, dict) or _kind_error(team.get("team"), "team") or not isinstance(team.get("faction"), str) \
                or not isinstance(team.get("units"), list) or not team["units"]:
            problems.append("%s: each team needs team, faction, and a non-empty units list" % where)
            continue
        seen_teams.append(team["team"])
        for unit in team["units"]:
            if not isinstance(unit, dict) or _kind_error(unit.get("id"), "id") or _kind_error(unit.get("unit"), "unit"):
                problems.append("%s: each unit needs an id and a unit type" % where)
    if not problems and sorted(seen_teams) != sorted(TEAMS):
        problems.append("%s: teams must be green and rust" % where)
    return problems


def _check_kills(kills, where: str) -> list[str]:
    if not isinstance(kills, dict) or sorted(kills) != sorted(TEAMS):
        return ["%s: kills_by_unit must have green and rust" % where]
    for team in TEAMS:
        if not isinstance(kills[team], dict) or any(_kind_error(k, "unit") or _kind_error(v, "int") for k, v in kills[team].items()):
            return ["%s: kills_by_unit.%s maps unit types to integers" % (where, team)]
    return []


def validate_timeline(events: list) -> list[str]:
    """Problems with a whole match: every event, plus ordering and references."""
    problems = []
    for index, event in enumerate(events):
        problems += validate_event(event, index)
    if problems:
        return problems
    if not events:
        return ["timeline is empty"]
    if events[0]["type"] != "match_start":
        problems.append("the first event must be match_start")
    if events[-1]["type"] != "match_end":
        problems.append("the last event must be match_end")
    counts = {}
    for event in events:
        counts[event["type"]] = counts.get(event["type"], 0) + 1
    for once in ("match_start", "match_end"):
        if counts.get(once, 0) != 1:
            problems.append("exactly one %s (found %d)" % (once, counts.get(once, 0)))
    if counts.get("first_contact", 0) > 1:
        problems.append("first_contact happens at most once")
    if problems:
        return problems
    team_of = {}
    type_of = {}
    for team in events[0]["teams"]:
        for unit in team["units"]:
            if unit["id"] in team_of:
                problems.append("match_start: unit id %s listed twice" % unit["id"])
            team_of[unit["id"]] = team["team"]
            type_of[unit["id"]] = unit["unit"]
    dead = set()
    last_tick, last_t = 0, 0.0
    for index, event in enumerate(events):
        where = "event %d (%s)" % (index, event["type"])
        if event["tick"] < last_tick or event["t"] < last_t:
            problems.append("%s: tick and t must not decrease" % where)
        last_tick, last_t = event["tick"], event["t"]
        for id_field, type_field in (("unit_id", "unit"), ("shooter", "shooter_unit"), ("victim", "victim_unit"),
                                     ("killer", "killer_unit"), ("target_id", "target_unit")):
            unit_id = event.get(id_field)
            if event["type"] == "match_start" or not unit_id:
                continue
            if unit_id not in team_of:
                problems.append("%s: %s %s is not in match_start" % (where, id_field, unit_id))
            elif type_field in event and event[type_field] != type_of[unit_id]:
                problems.append("%s: %s is a %s, not a %s" % (where, unit_id, type_of[unit_id], event[type_field]))
            elif unit_id in dead and id_field not in MAY_BE_DEAD:
                problems.append("%s: %s %s was already destroyed" % (where, id_field, unit_id))
        if event["type"] == "unit_destroyed":
            if event["victim"] in team_of and team_of[event["victim"]] != event["victim_team"]:
                problems.append("%s: %s is on %s" % (where, event["victim"], team_of[event["victim"]]))
            dead.add(event["victim"])
    return problems


def load_timeline(path: Path) -> list:
    """Parses a .jsonl file; a line that isn't JSON raises ValueError naming the line."""
    events = []
    for number, line in enumerate(Path(path).read_text().splitlines(), start=1):
        if not line.strip():
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise ValueError("%s:%d: not JSON (%s)" % (path, number, error)) from error
    return events


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: events.py FIXTURE.jsonl ...")
        return 2
    failed = 0
    for name in argv:
        try:
            problems = validate_timeline(load_timeline(Path(name)))
        except (OSError, ValueError) as error:
            problems = [str(error)]
        if problems:
            failed += 1
            print("INVALID %s" % name)
            for problem in problems[:20]:
                print("  " + problem)
        else:
            print("valid   %s" % name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
