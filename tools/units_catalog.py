"""Read `game/units/units.gd` as data: the ONE Python reader for the unit catalog (contract C1).

Before round 9 `tools/arena_report.py` carried its own three-line regex for `hull_size` and `tools/roster_scale.py`
would have been the second copy. Both now call this module, which is a thin facade over
`tools/gdscript_source.py` -- the shared parser, with the shared refusal behaviour.
"""

from __future__ import annotations

import pathlib

import gdscript_source
from gdscript_source import GdError as CatalogError  # the name the callers already use

UNITS_GD = gdscript_source.GAME / "units" / "units.gd"


def load(path: pathlib.Path | None = None) -> dict:
    """`{unit id: profile dict}` exactly as `Units.PROFILES` holds it."""
    path = path or UNITS_GD
    profiles = gdscript_source.const(path, "PROFILES")
    if not isinstance(profiles, dict) or not profiles:
        raise CatalogError("units.gd's PROFILES parsed to nothing")
    for unit_id, profile in profiles.items():
        if not isinstance(profile, dict) or "hull_size" not in profile:
            raise CatalogError("%s has no hull_size: the parse is wrong, not the catalog" % unit_id)
    return profiles


def const_float(name: str, path: pathlib.Path | None = None) -> float:
    """A scalar `const` from units.gd (e.g. RIG_LENGTH_M), read not copied."""
    return gdscript_source.const_float(path or UNITS_GD, name)


def hull_lengths(path: pathlib.Path | None = None) -> dict:
    """`{unit id: hull length in metres}` from `hull_size [w, h, l]`."""
    return {unit_id: float(p["hull_size"][2]) for unit_id, p in load(path).items()}
