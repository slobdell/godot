"""`make roster-scale` (scale, round 9, contract S1): the roster at real relative scale, as a table.

One row per unit: the real vehicle it is drawn as, that vehicle's cited length, the world factor K, the length the
rule gives it, today's collision box, and the box the APPROVED MESH fills at that length. The last column is the
one to read -- MISMATCH is the gap between what `units.gd` claims the hull is and what the art actually draws.

The two halves:
  * `game/units/units.gd` is read by `tools/units_catalog.py` -- the same reader `tools/arena_report.py` uses, so
    there is one parser to mutation-check instead of one per tool (Invariant 0).
  * the mesh boxes come from a headless Godot pass (`tests/scale/roster_boxes.gd`) that calls feel's
    `SizeLook.box_at_length()`. That formula is CALLED, never reimplemented here: a second copy in Python is
    exactly the mirror that Invariant 0's table is full of.

Nothing here writes to units.gd. The table is what the reference choices are argued from -- the judgment in this
stream is which real vehicle each unit is, and this prints that judgment where it can be disagreed with.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import units_catalog


def scale_k(profiles: dict, rig_length_m: float, rig_unit: str) -> float:
    """The world factor, DERIVED from the rig's reference exactly as `Units._derive_scale_k` derives it."""
    rig = profiles.get(rig_unit)
    if rig is None:
        raise units_catalog.CatalogError("units.gd has no unit '%s' to anchor the scale on" % rig_unit)
    reference = rig.get("scale_reference")
    if not reference or "length_m" not in reference:
        raise units_catalog.CatalogError(
            "%s has no scale_reference.length_m, so K cannot be derived and no target length in this table would "
            "mean anything. Restore it -- this tool does NOT fall back to a remembered value (Invariant 0)." % rig_unit)
    length = float(reference["length_m"])
    if length <= 0.0:
        raise units_catalog.CatalogError("%s's reference length is %s" % (rig_unit, length))
    return rig_length_m / length


def rows(profiles: dict, boxes: dict, k: float) -> list:
    out = []
    for unit_id, profile in profiles.items():
        reference = profile.get("scale_reference") or {}
        box = [float(v) for v in profile["hull_size"]]
        target = round(float(reference["length_m"]) * k, 2) if reference else box[2]
        measured = boxes.get(unit_id, {})
        out.append({
            "unit": unit_id,
            "faction": profile.get("faction", "condemned"),
            "role": profile.get("role", ""),
            "vehicle": reference.get("vehicle", "-- no reference --"),
            "reference_m": float(reference["length_m"]) if reference else None,
            "target_m": target,
            "box": box,
            "has_mesh": bool(measured.get("has_mesh")),
            "mesh_box": measured.get("box_at_target"),
            "mesh_box_today": measured.get("box_at_today"),
            "muzzle_height": float(profile.get("muzzle_height", 0.0)),
        })
    out.sort(key=lambda r: (["condemned", "gangs", "law", "syndicate"].index(r["faction"]), r["unit"]))
    return out


def worst_mismatch(box: list, other) -> float:
    """The largest per-axis disagreement, as a fraction. `None` (no mesh to compare with) is not a disagreement."""
    if not other:
        return 0.0
    return max(abs(float(a) - float(b)) / max(float(b), 1e-6) for a, b in zip(box, other))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--boxes", default="build/roster-boxes.json",
                    help="the headless Godot pass's output (tests/scale/roster_boxes.gd)")
    ap.add_argument("--json", help="also write the table here")
    ap.add_argument("--tolerance", type=float, default=0.01, help="MISMATCH threshold as a fraction (default 1%%)")
    args = ap.parse_args()

    profiles = units_catalog.load()
    rig_unit = "gang_tank"
    rig_length_m = units_catalog.const_float("RIG_LENGTH_M")
    k = scale_k(profiles, rig_length_m, rig_unit)

    measured = {}
    path = pathlib.Path(args.boxes)
    if path.exists():
        measured = json.loads(path.read_text()).get("units", {})
    else:
        print("!! no %s: run `make roster-scale` (it renders the boxes first). Mesh columns are blank." % path)

    table = rows(profiles, measured, k)
    print("ROSTER SCALE -- one factor for the whole world, anchored by the War Rig")
    print("  anchor   %s at %.2f m (the lead's ruling)" % (rig_unit, rig_length_m))
    print("  reference %s, %.2f m" % (profiles[rig_unit]["scale_reference"]["vehicle"],
                                      profiles[rig_unit]["scale_reference"]["length_m"]))
    print("  K = %.2f / %.2f = %.6f  (the world is drawn at %.1f%% of real size)"
          % (rig_length_m, profiles[rig_unit]["scale_reference"]["length_m"], k, k * 100.0))
    print()
    header = ("%-16s %-10s %-52s %7s %7s %7s %-18s %-18s %s"
              % ("unit", "faction", "reference vehicle", "real m", "x K", "today", "box today", "mesh box @ target", "MISMATCH"))
    print(header)
    print("-" * len(header))
    mismatched = []
    for row in table:
        mesh = row["mesh_box"]
        if not row["has_mesh"]:
            mesh_text = "no mesh"
        else:
            mesh_text = "[%s]" % ", ".join("%.2f" % float(v) for v in mesh)
        gap = worst_mismatch(row["box"], mesh if row["has_mesh"] else None)
        flag = ""
        if row["has_mesh"] and abs(row["target_m"] - float(row["box"][2])) > 0.005:
            flag = "length %+.2f m" % (row["target_m"] - float(row["box"][2]))
        elif row["has_mesh"] and gap > args.tolerance:
            flag = "box %.0f%% off the mesh" % (gap * 100.0)
        if flag:
            mismatched.append(row["unit"])
        print("%-16s %-10s %-52s %7s %7.2f %7.2f %-18s %-18s %s" % (
            row["unit"], row["faction"], row["vehicle"][:52],
            ("%.2f" % row["reference_m"]) if row["reference_m"] else "-",
            row["target_m"], float(row["box"][2]),
            "[%s]" % ", ".join("%.2f" % v for v in row["box"]), mesh_text, flag))
    print()
    print("ROSTER_SCALE %s" % json.dumps({
        "k": round(k, 6), "rig": rig_unit, "rig_length_m": rig_length_m,
        "units": len(table), "with_reference": sum(1 for r in table if r["reference_m"]),
        "with_mesh": sum(1 for r in table if r["has_mesh"]),
        "needing_change": len(mismatched),
        "shortest_hull_m": min(r["target_m"] for r in table),
        "longest_hull_m": max(r["target_m"] for r in table),
    }))
    if args.json:
        pathlib.Path(args.json).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.json).write_text(json.dumps({"k": k, "rows": table}, indent=2))
        print(">> roster-scale: %s" % args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())
