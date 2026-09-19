#!/usr/bin/env python3
"""Render X6 (round 5): wrap each faction's generated Meshy parts in the cyberpunk look (dozer_part.gd: team rim,
paint, heat, shield, underglow) so gameplay can fill `unit.<id>.hull/turret/weapon` with them.

Writes game/theme/factions/<faction>/parts/<role>_<part>.tscn for every generated part that exists
(game/theme/factions/<faction>/generated/unit_<faction>_<role>_<part>.tscn). GameTheme registers the slots at runtime
only where these files exist, so a build that excludes the faction art (the web export) falls back to the Condemned.
Re-run after build_factions.sh adds or removes a part."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
FACTIONS = ["gangs", "law", "syndicate"]
ROLES = ["scout", "ifv", "tank", "artillery", "special"]
PARTS = {"hull": "hull", "turret": "turret", "weapon": "cannon"}
## Models generated facing +Z instead of the engine's -Z (trip-up 2): the wrapper turns them round (dozer_part.gd
## `model_yaw_deg`). Round 7, the lead three times: "the gang's IFV drives backwards". Found and checked with
## `make facing-audit`, which shows every unit side-on with its forward marked.
MODEL_YAW_DEG = {("gangs", "ifv", "hull"): 180.0}

TEMPLATE = """[gd_scene format=3]

[ext_resource type="Script" path="res://game/theme/cyberpunk/dozer_part.gd" id="1_part"]
[ext_resource type="PackedScene" path="res://game/theme/factions/{faction}/generated/unit_{faction}_{role}_{part}.tscn" id="2_model"]

[node name="{name}" type="Node3D"]
script = ExtResource("1_part")
model_scene = ExtResource("2_model")
part = "{wrapper_part}"
{extra}"""


def main() -> None:
    written = 0
    for faction in FACTIONS:
        out_dir = ROOT / "game/theme/factions" / faction / "parts"
        out_dir.mkdir(parents=True, exist_ok=True)
        for role in ROLES:
            for part, wrapper_part in PARTS.items():
                model = ROOT / f"game/theme/factions/{faction}/generated/unit_{faction}_{role}_{part}.tscn"
                target = out_dir / f"{role}_{part}.tscn"
                if not model.exists():
                    if target.exists():
                        target.unlink()
                    continue
                name = "".join(word.capitalize() for word in f"{faction}_{role}_{part}".split("_"))
                yaw = MODEL_YAW_DEG.get((faction, role, part), 0.0)
                extra = "model_yaw_deg = %s\n" % repr(float(yaw)) if yaw else ""
                target.write_text(TEMPLATE.format(faction=faction, role=role, part=part, name=name, wrapper_part=wrapper_part,
                                                  extra=extra))
                written += 1
    print(f"faction parts: {written} wrapper scenes")


if __name__ == "__main__":
    main()
