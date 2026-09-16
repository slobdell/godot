#!/usr/bin/env python3
"""Build the lead's read-only doctrine view: every doctrine table, its rules, its drill numbers, and a
picture of each formation.  `make doctrine-page` -> build/doctrine/index.html

Read-only on purpose (doctrine stream, stretch item): the tables themselves are the source of truth
(doctrines/doctrine_<name>.json), and the engine reads them through game/tactics/doctrine_table.gd.  The
shapes drawn here mirror game/tactics/tactics_formation.gd; if that file's geometry changes, change _offsets
below to match (the page is illustration, the game is the authority).
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOCTRINES = ROOT / "doctrines"
SPACING = 12.0
DIAGONAL_SIDE = 0.9
HERRINGBONE_SIDE = 0.55
HERRINGBONE_FACING = 90.0
# The drills a table runs when it doesn't say otherwise — mirrors DoctrineTable.DRILL_DEFAULTS["enabled"].
# Encircle and bait are deliberately NOT in here: they are gang behaviour, not doctrine.
DEFAULT_DRILLS = ["react_to_contact", "near_ambush", "far_ambush", "assault_through", "support_by_fire",
                  "break_contact", "herringbone"]
# Drill numbers a table inherits when it doesn't set them — mirrors DoctrineTable.DRILL_DEFAULTS. _check_mirror()
# below re-reads the GDScript and fails the build if these ever drift apart.
DEFAULT_NUMBERS = {"near_ambush_m": 38.0, "assault_through_m": 26.0, "flank_m": 42.0,
                   "break_contact_ratio": 0.5, "disengage_m": 40.0, "rally_back_m": 55.0}
TABLE_GD = ROOT / "game" / "tactics" / "doctrine_table.gd"
SWARM_SPREAD = 1.9
SWARM_STAGGER = 0.8
RING_RADIUS = 2.4

TECHNIQUE_WORDS = {
    "traveling": "traveling (contact not likely: everyone moves)",
    "traveling_overwatch": "traveling overwatch (contact possible: the trail element follows ready to fire)",
    "bounding_overwatch": "bounding overwatch (contact expected: one element moves, the other covers)",
}


def _offsets(formation: str, count: int, spacing: float = SPACING) -> list[tuple[float, float]]:
    """(right, back) meters per slot — mirrors TacticsFormation.offsets."""
    slots = []
    for i in range(count):
        side = -1.0 if i % 2 == 1 else 1.0
        rank = float((i + 1) // 2)
        if formation == "column":
            slots.append((0.0, i * spacing))
        elif formation == "wedge":
            slots.append((0.0, 0.0) if i == 0 else (side * rank * spacing * DIAGONAL_SIDE, rank * spacing))
        elif formation == "vee":
            slots.append((0.0, 0.0) if i == 0 else (side * rank * spacing * DIAGONAL_SIDE, -rank * spacing))
        elif formation == "line":
            slots.append((0.0, 0.0) if i == 0 else (side * rank * spacing, 0.0))
        elif formation == "echelon_right":
            slots.append((i * spacing * DIAGONAL_SIDE, i * spacing))
        elif formation == "echelon_left":
            slots.append((-i * spacing * DIAGONAL_SIDE, i * spacing))
        elif formation == "herringbone":
            slots.append((side * spacing * HERRINGBONE_SIDE, i * spacing * 0.8))
        elif formation == "coil":
            angle = math.tau * i / max(count, 1)
            radius = spacing * (0.7 if count <= 3 else 0.9) * math.sqrt(max(count, 1) / 4.0)
            slots.append((math.sin(angle) * radius, -math.cos(angle) * radius))
        elif formation == "swarm":
            rank_out = float((i + 1) // 2)
            stagger = ((i * 7) % 5) - 2.0
            slots.append((side * rank_out * spacing * SWARM_SPREAD, stagger * spacing * SWARM_STAGGER))
        elif formation == "ring":
            step = math.tau * i / max(count, 1)
            slots.append((math.sin(step) * spacing * RING_RADIUS, -math.cos(step) * spacing * RING_RADIUS))
        else:
            slots.append((0.0, 0.0))
    return slots


def _sectors(formation: str, count: int) -> list[float]:
    """Each slot's sector of fire in degrees from the direction of travel — mirrors TacticsFormation.sectors."""
    out: list[float] = []
    for i in range(count):
        side = -1.0 if i % 2 == 1 else 1.0
        rank = float((i + 1) // 2)
        if formation == "column":
            out.append(0.0 if i == 0 else (180.0 if i == count - 1 and count > 2 else (90.0 if i % 2 == 0 else -90.0)))
        elif formation in ("wedge", "vee"):
            out.append(0.0 if i == 0 else side * min(45.0 + 45.0 * (rank - 1.0), 135.0))
        elif formation == "line":
            out.append(0.0 if count <= 1 else (i / (count - 1) - 0.5) * 60.0)
        elif formation == "echelon_right":
            out.append(0.0 if i == 0 else min(45.0 + 45.0 * (i - 1), 135.0))
        elif formation == "echelon_left":
            out.append(0.0 if i == 0 else -min(45.0 + 45.0 * (i - 1), 135.0))
        elif formation == "herringbone":
            if i == 0:
                out.append(0.0)
            elif i == count - 1 and count > 2:
                out.append(180.0)
            else:
                out.append(HERRINGBONE_FACING if i % 2 == 0 else -HERRINGBONE_FACING)
        elif formation == "swarm":
            out.append(0.0 if count <= 1 else (i / (count - 1) - 0.5) * 120.0)
        elif formation in ("coil", "ring"):
            angle = math.degrees(math.tau * i / count)
            out.append(angle - 360.0 if angle > 180.0 else angle)
        else:
            out.append(0.0)
    return out


def _svg(formation: str, count: int = 5, size: int = 132) -> str:
    """Top-down picture of the shape: vehicles as boxes, sectors of fire as spokes, travel is up."""
    slots = _offsets(formation, count)
    sectors = _sectors(formation, count)
    xs = [s[0] for s in slots] or [0.0]
    ys = [s[1] for s in slots] or [0.0]
    mid_x = (max(xs) + min(xs)) / 2
    mid_y = (max(ys) + min(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys), 24.0) + 22.0
    scale = (size - 18) / span
    parts = [f'<svg viewBox="0 0 {size} {size}" width="{size}" height="{size}" role="img" aria-label="{formation}">',
             f'<rect width="{size}" height="{size}" fill="#0d1117" rx="8"/>',
             f'<path d="M {size/2} 12 l -5 9 l 10 0 z" fill="#3ba55d"/>']
    for (right, back), sector in zip(slots, sectors):
        cx = size / 2 + (right - mid_x) * scale
        cy = size / 2 + (back - mid_y) * scale
        angle = math.radians(sector)
        # The heading is "up" on the page; + sector is to the element's right.
        dx = math.sin(angle) * 17
        dy = -math.cos(angle) * 17
        parts.append(f'<line x1="{cx:.1f}" y1="{cy:.1f}" x2="{cx+dx:.1f}" y2="{cy+dy:.1f}" '
                     f'stroke="#f0883e" stroke-width="1.6" opacity="0.75"/>')
        parts.append(f'<rect x="{cx-4:.1f}" y="{cy-5:.1f}" width="8" height="10" rx="2" fill="#58a6ff"/>')
    parts.append("</svg>")
    return "".join(parts)


def _condition(when: dict) -> str:
    if not when:
        return "<em>anything else</em>"
    bits = []
    for key, values in when.items():
        bits.append(f"{key} is {' or '.join(values)}")
    return ", ".join(bits)


def _check_mirror() -> None:
    """This file copies a few constants out of the engine to draw shapes and name differences. Copies rot, so
    read the GDScript and refuse to build a page that would lie about what the game does."""
    source = TABLE_GD.read_text()
    for key, mirrored in DEFAULT_NUMBERS.items():
        found = re.search(rf'^\t"{key}":\s*([0-9.]+),', source, re.MULTILINE)
        if not found:
            raise SystemExit(f"doctrine_page: {key} is no longer in DRILL_DEFAULTS; update the mirror")
        if abs(float(found.group(1)) - mirrored) > 1e-6:
            raise SystemExit(f"doctrine_page: {key} is {found.group(1)} in doctrine_table.gd, "
                             f"{mirrored} here — update DEFAULT_NUMBERS")
    enabled = re.search(r'"enabled":\s*\[(.*?)\]', source, re.DOTALL)
    if enabled:
        listed = re.findall(r'"([a-z_]+)"', enabled.group(1))
        if sorted(listed) != sorted(DEFAULT_DRILLS):
            raise SystemExit(f"doctrine_page: default drills are {listed} in doctrine_table.gd, "
                             f"{DEFAULT_DRILLS} here — update DEFAULT_DRILLS")


def _differences(data: dict, standard: dict) -> list[str]:
    """The short answer to "what makes this faction different", in words."""
    notes: list[str] = []
    base_drills = standard.get("drills", {})
    drills = data.get("drills", {})
    base_enabled = set(base_drills.get("enabled", DEFAULT_DRILLS))
    enabled = set(drills.get("enabled", DEFAULT_DRILLS))
    for gained in sorted(enabled - base_enabled):
        notes.append(f"runs <b>{gained.replace('_', ' ')}</b>, which standard doctrine has no drill for")
    for lost in sorted(base_enabled - enabled):
        notes.append(f"has <b>no {lost.replace('_', ' ')}</b> drill at all")
    base_space = standard.get("spacing_m", {}).get("open")
    space = data.get("spacing_m", {}).get("open")
    if base_space and space and abs(space - base_space) > 0.5:
        wider = "wider" if space > base_space else "tighter"
        notes.append(f"spreads <b>{space:g} m</b> in the open against {base_space:g} — {wider} than standard")
    techniques = {rule["technique"] for rule in data.get("movement", [])}
    if techniques == {"traveling"}:
        notes.append("<b>never bounds and never overwatches</b>: every rule just moves")
    elif "bounding_overwatch" in techniques and len(techniques) > 1:
        bounding = sum(1 for rule in data.get("movement", []) if rule["technique"] == "bounding_overwatch")
        notes.append(f"<b>bounds under fire</b> in {bounding} of its {len(data.get('movement', []))} rules")
    shapes = {rule["formation"] for rule in data.get("movement", [])}
    exotic = shapes - {rule["formation"] for rule in standard.get("movement", [])}
    if exotic:
        notes.append("uses shapes standard doctrine does not: <b>" + ", ".join(sorted(exotic)) + "</b>")
    labels = (("near_ambush_m", "charges an ambush from"), ("break_contact_ratio", "breaks contact below"),
              ("flank_m", "swings"), ("react_ticks", "takes"))
    for key, label in labels:
        if key not in drills:
            continue
        base = base_drills.get(key, DEFAULT_NUMBERS.get(key))
        if base is None or abs(float(drills[key]) - float(base)) < 1e-6:
            continue
        if key == "break_contact_ratio" and float(drills[key]) == 0.0:
            continue  # already said as "no break contact drill at all"
        unit = " m" if key.endswith("_m") else (" ticks" if key.endswith("_ticks") else "")
        notes.append(f"{label} <b>{float(drills[key]):g}{unit}</b> where standard doctrine says "
                     f"{float(base):g}{unit}")
    return notes


def _table_html(data: dict, standard: dict | None = None) -> str:
    rows = []
    for rule in data.get("movement", []):
        rows.append(
            "<tr>"
            f"<td>{_condition(rule.get('when', {}))}</td>"
            f"<td class='shape'>{_svg(rule['formation'])}<div>{rule['formation'].replace('_', ' ')}</div></td>"
            f"<td>{TECHNIQUE_WORDS.get(rule['technique'], rule['technique'])}</td>"
            f"<td class='why'>{rule['why']}</td>"
            "</tr>")
    numbers = []
    for label, values in (("spacing (m)", data.get("spacing_m", {})), ("legs (m)", data.get("legs", {})),
                          ("drills", data.get("drills", {}))):
        if not values:
            continue
        pretty = ", ".join(f"{k} <b>{v}</b>" for k, v in values.items() if k != "enabled")
        if "enabled" in values:
            pretty += "<br>drills run: " + ", ".join(values["enabled"])
        numbers.append(f"<p class='numbers'><span>{label}</span> {pretty}</p>")
    differences = ""
    if standard is not None and data.get("name") != standard.get("name"):
        notes = _differences(data, standard)
        if notes:
            differences = ("<ul class='differs'>"
                           + "".join(f"<li>{note}</li>" for note in notes) + "</ul>")
    return (f"<section><h2>{data.get('display_name', data['name'])} "
            f"<span class='faction'>{data.get('faction', '')}</span></h2>"
            f"<p class='summary'>{data.get('summary', '')}</p>"
            + differences + "".join(numbers) +
            "<table><thead><tr><th>when</th><th>formation</th><th>movement technique</th><th>why</th></tr></thead>"
            f"<tbody>{''.join(rows)}</tbody></table></section>")


STYLE = """
:root { color-scheme: dark; }
body { background:#010409; color:#e6edf3; font:15px/1.55 -apple-system, "Segoe UI", Roboto, sans-serif; margin:0 auto; padding:28px 20px 60px; max-width:1100px; }
h1 { font-size:26px; margin:0 0 4px; } h2 { font-size:20px; margin:34px 0 4px; }
.lead { color:#8b949e; max-width:70ch; }
.faction { font-size:12px; color:#8b949e; border:1px solid #30363d; border-radius:999px; padding:2px 8px; vertical-align:middle; }
.summary { color:#c9d1d9; max-width:80ch; }
.numbers { color:#8b949e; font-size:13px; margin:2px 0; } .numbers span { color:#58a6ff; display:inline-block; min-width:86px; }
ul.differs { margin:10px 0 14px; padding-left:18px; color:#e6edf3; }
ul.differs li { margin:3px 0; } ul.differs b { color:#f0883e; font-weight:600; }
table { border-collapse:collapse; width:100%; margin-top:10px; }
th, td { border-top:1px solid #21262d; padding:8px 10px; text-align:left; vertical-align:top; }
th { color:#8b949e; font-weight:600; font-size:13px; }
td.shape { text-align:center; width:150px; color:#8b949e; font-size:12px; }
td.why { color:#c9d1d9; max-width:34ch; }
footer { color:#6e7681; font-size:13px; margin-top:40px; }
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(ROOT / "build" / "doctrine"))
    args = parser.parse_args()
    _check_mirror()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    tables = []
    for path in sorted(DOCTRINES.glob("doctrine_*.json")):
        tables.append(json.loads(path.read_text()))
    standard = next((t for t in tables if t.get("name") == "standard"), None)
    # Standard first: it is the baseline every other table is described against.
    tables.sort(key=lambda t: (t.get("name") != "standard", t.get("name", "")))
    body = "".join(_table_html(table, standard) for table in tables)
    html = (f"<!doctype html><html lang='en'><head><meta charset='utf-8'>"
            f"<meta name='viewport' content='width=device-width, initial-scale=1'>"
            f"<title>Tank Squad doctrine</title><style>{STYLE}</style></head><body>"
            "<h1>Doctrine</h1>"
            "<p class='lead'>What every element leader does without being told: the formation and movement "
            "technique it picks for a task, and the numbers its battle drills run on. Rules are read top to "
            "bottom and the first match wins. Travel is up the page; the orange spokes are each vehicle's "
            "sector of fire. Each faction lists <b>what it does that standard doctrine doesn't</b>. "
            "Read-only: the tables live in <code>doctrines/doctrine_*.json</code>, the reasoning in "
            "<code>_agents/doctrine.md</code>.</p>"
            f"{body}<footer>Generated by <code>make doctrine-page</code>.</footer></body></html>")
    (out / "index.html").write_text(html)
    print(f"DOCTRINE_PAGE {out / 'index.html'} ({len(tables)} tables)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
