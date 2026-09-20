"""Reader and writer for the Tank Squad trajectory log (format v1).

The format is specified in FORMAT.md, which is the contract (S3); this file is its only reference
implementation. Nothing here falls back: a log we cannot read must never become a log that reads as
"nothing happened" (`_agents/workstreams.md` Invariant 0). Every refusal names the line number.

Pure Python 3, no third-party dependency: `make check` must not grow one for a measurement tool.
"""

from __future__ import annotations

import gzip
import io
import json
import math
import os
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional

FORMAT_NAME = "tank-squad-trajectory"
VERSION = 1

# (name, allow_null). Present in EVERY sample line; see FORMAT.md.
REQUIRED_INT = [("tick", False), ("team", False), ("gear", False), ("element", True)]
REQUIRED_STR = [("unit", False), ("unit_id", False), ("order_verb", True)]
REQUIRED_FLOAT = [
    ("x", False),
    ("z", False),
    ("heading_rad", False),
    ("speed_mps", False),
    ("goal_x", True),
    ("goal_z", True),
    ("slot_x", True),
    ("slot_z", True),
]
# All-or-nothing: present in every sample of a log, or in none of them.
OPTIONAL_BOOL = ["order_reverse", "creeping"]
OPTIONAL_STR = ["phase"]

REQUIRED_FIELDS = (
    [n for n, _ in REQUIRED_INT] + [n for n, _ in REQUIRED_STR] + [n for n, _ in REQUIRED_FLOAT]
)
OPTIONAL_FIELDS = OPTIONAL_BOOL + OPTIONAL_STR

REQUIRED_HEADER = ["format", "version", "commit", "machine", "tick_rate", "producer"]


class TrajectoryLogError(Exception):
    """A log that cannot be trusted. Never caught and turned into an empty result."""


@dataclass
class Header:
    commit: str
    machine: str
    tick_rate: int
    producer: str
    arena: Optional[str] = None
    seed: Optional[int] = None
    command: str = ""
    knobs: Dict[str, Any] = field(default_factory=dict)
    extra: Dict[str, Any] = field(default_factory=dict)

    def provenance(self) -> str:
        """The one line every number this log produces must carry."""
        bits = ["commit=%s" % self.commit, "machine=%s" % self.machine, "producer=%s" % self.producer]
        if self.arena is not None:
            bits.append("arena=%s" % self.arena)
        if self.seed is not None:
            bits.append("seed=%s" % self.seed)
        bits.append("tick_rate=%d" % self.tick_rate)
        return " ".join(bits)


@dataclass
class Sample:
    tick: int
    unit: str
    unit_id: str
    team: int
    x: float
    z: float
    heading_rad: float
    speed_mps: float
    gear: int
    goal_x: Optional[float]
    goal_z: Optional[float]
    order_verb: Optional[str]
    element: Optional[int]
    slot_x: Optional[float]
    slot_z: Optional[float]
    order_reverse: Optional[bool] = None
    phase: Optional[str] = None
    creeping: Optional[bool] = None

    @property
    def ordered(self) -> bool:
        return self.goal_x is not None and self.goal_z is not None

    def goal_distance(self) -> Optional[float]:
        """Flat (x/z) distance to the goal, or None when under no orders."""
        if not self.ordered:
            return None
        return math.hypot(self.x - self.goal_x, self.z - self.goal_z)


@dataclass
class TrajectoryLog:
    header: Header
    units: Dict[str, List[Sample]]
    path: str = ""
    # Which optional columns this log carries, all-or-nothing.
    has_cause: bool = False

    @property
    def unit_ids(self) -> Dict[str, str]:
        return {name: samples[0].unit_id for name, samples in self.units.items() if samples}

    def sample_count(self) -> int:
        return sum(len(s) for s in self.units.values())

    def tick_span(self) -> int:
        ticks = [s.tick for samples in self.units.values() for s in samples]
        return (max(ticks) - min(ticks) + 1) if ticks else 0


def _die(path: str, line_no: int, message: str) -> None:
    where = "%s:%d" % (path or "<log>", line_no)
    raise TrajectoryLogError("%s: %s" % (where, message))


def _number(path: str, line_no: int, row: Dict[str, Any], key: str, allow_null: bool) -> Optional[float]:
    if key not in row:
        _die(path, line_no, "missing required field %r (FORMAT.md: the key must be present, null is a value)" % key)
    value = row[key]
    if value is None:
        if allow_null:
            return None
        _die(path, line_no, "field %r is null, which this field does not allow" % key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _die(path, line_no, "field %r is %r, expected a number" % (key, value))
    value = float(value)
    if not math.isfinite(value):
        _die(path, line_no, "field %r is %r; a metric computed from it would be silently meaningless" % (key, value))
    return value


def _integer(path: str, line_no: int, row: Dict[str, Any], key: str, allow_null: bool) -> Optional[int]:
    if key not in row:
        _die(path, line_no, "missing required field %r (FORMAT.md: the key must be present, null is a value)" % key)
    value = row[key]
    if value is None:
        if allow_null:
            return None
        _die(path, line_no, "field %r is null, which this field does not allow" % key)
    if isinstance(value, bool) or not isinstance(value, int):
        _die(path, line_no, "field %r is %r, expected an integer" % (key, value))
    return value


def _text(path: str, line_no: int, row: Dict[str, Any], key: str, allow_null: bool) -> Optional[str]:
    if key not in row:
        _die(path, line_no, "missing required field %r (FORMAT.md: the key must be present, null is a value)" % key)
    value = row[key]
    if value is None:
        if allow_null:
            return None
        _die(path, line_no, "field %r is null, which this field does not allow" % key)
    if not isinstance(value, str):
        _die(path, line_no, "field %r is %r, expected a string" % (key, value))
    return value


def parse_header(row: Dict[str, Any], path: str = "", line_no: int = 1) -> Header:
    if row.get("kind") != "header":
        _die(path, line_no, "the first line must be the header (kind=%r)" % row.get("kind"))
    for key in REQUIRED_HEADER:
        if key not in row:
            _die(path, line_no, "header is missing required field %r" % key)
    if row["format"] != FORMAT_NAME:
        _die(path, line_no, "format is %r, expected %r" % (row["format"], FORMAT_NAME))
    if row["version"] != VERSION:
        _die(path, line_no, "format version %r; this reader knows version %d only" % (row["version"], VERSION))
    tick_rate = row["tick_rate"]
    if isinstance(tick_rate, bool) or not isinstance(tick_rate, int) or tick_rate <= 0:
        _die(path, line_no, "tick_rate is %r, expected a positive integer" % (tick_rate,))
    known = set(REQUIRED_HEADER) | {"kind", "arena", "seed", "command", "knobs"}
    return Header(
        commit=str(row["commit"]),
        machine=str(row["machine"]),
        tick_rate=int(tick_rate),
        producer=str(row["producer"]),
        arena=row.get("arena"),
        seed=row.get("seed"),
        command=str(row.get("command", "")),
        knobs=dict(row.get("knobs") or {}),
        extra={k: v for k, v in row.items() if k not in known},
    )


def parse_sample(row: Dict[str, Any], path: str, line_no: int, expect_cause: Optional[bool]) -> Sample:
    kind = row.get("kind", "sample")
    if kind != "sample":
        _die(path, line_no, "unknown kind %r (a log carries one header and samples, nothing else)" % kind)
    values: Dict[str, Any] = {}
    for key, allow_null in REQUIRED_INT:
        values[key] = _integer(path, line_no, row, key, allow_null)
    for key, allow_null in REQUIRED_STR:
        values[key] = _text(path, line_no, row, key, allow_null)
    for key, allow_null in REQUIRED_FLOAT:
        values[key] = _number(path, line_no, row, key, allow_null)
    if values["gear"] not in (-1, 0, 1):
        _die(path, line_no, "gear is %r, expected -1, 0 or 1" % (values["gear"],))
    # Paired fields: both null or both set. A half-set goal is a goal we would measure against garbage.
    for a, b in (("goal_x", "goal_z"), ("slot_x", "slot_z")):
        if (values[a] is None) != (values[b] is None):
            _die(path, line_no, "%s and %s must be null together (got %r and %r)" % (a, b, values[a], values[b]))
    if (values["goal_x"] is None) != (values["order_verb"] is None):
        _die(
            path,
            line_no,
            "goal_x/goal_z and order_verb must be null together: a goal with no verb, or a verb with no goal, "
            "is an order we cannot attribute (got verb=%r)" % (values["order_verb"],),
        )
    has_cause = any(key in row for key in OPTIONAL_FIELDS)
    if expect_cause is not None and has_cause != expect_cause:
        _die(
            path,
            line_no,
            "the optional cause columns %s are all-or-nothing across a log: this line %s them while earlier lines "
            "%s (a partial column becomes a wrong denominator, silently)"
            % (OPTIONAL_FIELDS, "carries" if has_cause else "omits", "did not" if has_cause else "did"),
        )
    if has_cause:
        for key in OPTIONAL_FIELDS:
            if key not in row:
                _die(path, line_no, "the cause columns are all-or-nothing: %r is missing" % key)
        for key in OPTIONAL_BOOL:
            if row[key] is not None and not isinstance(row[key], bool):
                _die(path, line_no, "field %r is %r, expected a boolean or null" % (key, row[key]))
            values[key] = row[key]
        for key in OPTIONAL_STR:
            values[key] = _text(path, line_no, row, key, True)
    return Sample(**values)


def _open(path: str) -> io.TextIOBase:
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8")
    return open(path, "r", encoding="utf-8")


def read_lines(lines: Iterable[str], path: str = "") -> TrajectoryLog:
    header: Optional[Header] = None
    expect_cause: Optional[bool] = None
    units: Dict[str, List[Sample]] = {}
    for line_no, raw in enumerate(lines, start=1):
        line = raw.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            _die(path, line_no, "not JSON (%s)" % exc.msg)
            raise  # unreachable; keeps type checkers honest
        if not isinstance(row, dict):
            _die(path, line_no, "expected a JSON object, got %s" % type(row).__name__)
        if header is None:
            header = parse_header(row, path, line_no)
            continue
        sample = parse_sample(row, path, line_no, expect_cause)
        if expect_cause is None:
            expect_cause = any(key in row for key in OPTIONAL_FIELDS)
        units.setdefault(sample.unit, []).append(sample)
    if header is None:
        raise TrajectoryLogError("%s: empty log (not even a header)" % (path or "<log>"))
    for name, samples in units.items():
        samples.sort(key=lambda s: s.tick)
        ids = {s.unit_id for s in samples}
        if len(ids) > 1:
            raise TrajectoryLogError(
                "%s: unit %r changes unit_id within one log (%s); a unit name is unique per run"
                % (path or "<log>", name, sorted(ids))
            )
        ticks = [s.tick for s in samples]
        if len(set(ticks)) != len(ticks):
            raise TrajectoryLogError("%s: unit %r has two samples on one tick" % (path or "<log>", name))
    return TrajectoryLog(header=header, units=units, path=path, has_cause=bool(expect_cause))


def read_log(path: str) -> TrajectoryLog:
    with _open(path) as handle:
        return read_lines(handle, path)


def read_logs(paths: Iterable[str]) -> List[TrajectoryLog]:
    return [read_log(p) for p in paths]


# ---- Writing (the synthetic fixtures and any Python-side producer) -----------------------------


def header_line(
    commit: str,
    machine: str,
    tick_rate: int,
    producer: str,
    arena: Optional[str] = None,
    seed: Optional[int] = None,
    command: str = "",
    knobs: Optional[Dict[str, Any]] = None,
) -> str:
    return json.dumps(
        {
            "kind": "header",
            "format": FORMAT_NAME,
            "version": VERSION,
            "commit": commit,
            "machine": machine,
            "tick_rate": tick_rate,
            "arena": arena,
            "seed": seed,
            "producer": producer,
            "command": command,
            "knobs": knobs or {},
        },
        sort_keys=True,
    )


def sample_line(sample: Sample, with_cause: bool = False) -> str:
    row: Dict[str, Any] = {key: getattr(sample, key) for key in REQUIRED_FIELDS}
    if with_cause:
        for key in OPTIONAL_FIELDS:
            row[key] = getattr(sample, key)
    return json.dumps(row, sort_keys=True)


def write_log(path: str, header: Header, samples: Iterable[Sample], with_cause: bool = False) -> None:
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "wt", encoding="utf-8") as handle:  # type: ignore[operator]
        handle.write(
            header_line(
                header.commit,
                header.machine,
                header.tick_rate,
                header.producer,
                header.arena,
                header.seed,
                header.command,
                header.knobs,
            )
            + "\n"
        )
        for sample in samples:
            handle.write(sample_line(sample, with_cause) + "\n")
