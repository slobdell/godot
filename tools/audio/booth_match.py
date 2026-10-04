#!/usr/bin/env python3
"""Round 17: does the shipped booth duck reproduce the page's clip of it? (`make booth-match`)

    python3 tools/audio/booth_match.py <reference.wav> <folder of shipped_N.wav>

The reference is the page's recording of the setting the build ships (its taps beside it); the shipped runs are the
default build on the same match. Booth over the battle (median and busiest tenth) over the page's window (clips.json
`duck_window_s`, else the whole recording) for each; PASS when the reference falls inside the shipped runs' spread
widened by a tolerance (TOLERANCE_DB), which absorbs that two runs of one seed are not sample-identical.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import weapon_sheet  # noqa: E402

TOLERANCE_DB = 1.5
WORLD_TRIM_DB = -2.0  # SfxSystem.WORLD_TRIM_DB: the World taps sit before the bus volume


def booth_over_battle(base: Path, window: tuple[float, float] | None) -> tuple[float, float]:
    rd = lambda tap: weapon_sheet.read(Path(str(base.with_suffix("")) + ".%s.wav" % tap))[0]
    booth, world = rd("booth"), rd("world_out")
    rate = 44100
    hop = int(0.4 * rate)
    if window:
        # the taps start ~3 s after the recording; the page's window is in recording time
        a, b = int((window[0] - 3.0) * rate), int((window[1] - 3.0) * rate)
        booth, world = booth[max(a, 0):b], world[max(a, 0):b]
    n = min(len(booth), len(world)) // hop
    level = lambda x: 20 * np.log10(np.maximum(np.sqrt((weapon_sheet.mono(x)[: n * hop].reshape(n, hop) ** 2).mean(axis=1)), 1e-9)) + 12.0
    bl, wl = level(booth), level(world) + WORLD_TRIM_DB
    speaking = bl > bl.max() - 20.0
    over = bl[speaking] - wl[speaking]
    return float(np.median(over)), float(np.percentile(over, 10))


## The page's booth clips were cut at this window of his match (clips.json duck_window_s): used for live references too.
PAGE_WINDOW = (29.9, 49.9)


def main(argv: list[str]) -> int:
    folder = Path(argv[1])
    shipped = [booth_over_battle(p, PAGE_WINDOW) for p in sorted(folder.glob("shipped_*.wav")) if "." not in p.stem]
    if argv[0] == "--live":
        return live(folder)
    # A stored clip as the reference (its session's lines and draw: indicative only; --live is the acceptance).
    ref = Path(argv[0])
    clips = ref.parent / "clips.json"
    window = tuple(json.loads(clips.read_text()).get("duck_window_s") or ()) if clips.exists() else ()
    window = window if len(window) == 2 else None
    r_med, r_p10 = booth_over_battle(ref, window)
    meds, p10s = [s[0] for s in shipped], [s[1] for s in shipped]
    ok_med = min(meds) - TOLERANCE_DB <= r_med <= max(meds) + TOLERANCE_DB
    ok_p10 = min(p10s) - TOLERANCE_DB <= r_p10 <= max(p10s) + TOLERANCE_DB
    report = {"window_s": window, "reference": {"median": round(r_med, 1), "p10": round(r_p10, 1)},
              "shipped": [{"median": round(m, 1), "p10": round(p, 1)} for m, p in shipped], "tolerance_db": TOLERANCE_DB,
              "pass": bool(ok_med and ok_p10)}
    (folder / "booth_match.json").write_text(json.dumps(report, indent=1) + "\n")
    print("booth-match %s: reference %.1f / %.1f dB; shipped %s (median / busiest tenth, window %s)" % (
        "PASSED" if report["pass"] else "FAILED", r_med, r_p10, ", ".join("%.1f / %.1f" % s for s in shipped), window))
    return 0 if report["pass"] else 1


def lines(log: Path) -> list[str]:
    import re
    return re.findall(r"HUD_MESSAGE \[info\] (?:CALLER|VETERAN|PA): (.*)", log.read_text(errors="replace"))


def live(folder: Path) -> int:
    """Per booth seed: the page's tree (ref_<seed>) and the shipped build (shipped_<seed>) with the same lines. PASS when
    the shipped minus reference difference, averaged over seeds, is within TOLERANCE_DB for the median and the busiest
    tenth, and every seed's two arms spoke the same lines."""
    rows, same_lines = [], True
    for ref in sorted(folder.glob("ref_*.wav")):
        if "." in ref.stem:
            continue
        seed = ref.stem.split("_", 1)[1]
        ship = folder / ("shipped_%s.wav" % seed)
        r, s = booth_over_battle(ref, PAGE_WINDOW), booth_over_battle(ship, PAGE_WINDOW)
        lr, ls = lines(ref.with_suffix(".log")), lines(ship.with_suffix(".log"))
        common = min(len(lr), len(ls), 12)
        match = lr[:common] == ls[:common] and common > 0
        same_lines = same_lines and match
        rows.append({"seed": seed, "ref": [round(r[0], 1), round(r[1], 1)], "shipped": [round(s[0], 1), round(s[1], 1)],
                     "diff": [round(s[0] - r[0], 1), round(s[1] - r[1], 1)], "same_lines": match, "lines_compared": common})
    d_med = float(np.mean([x["diff"][0] for x in rows])) if rows else float("nan")
    d_p10 = float(np.mean([x["diff"][1] for x in rows])) if rows else float("nan")
    spread = {"ref_median": round(float(np.ptp([x["ref"][0] for x in rows])), 1) if rows else None,
              "ref_p10": round(float(np.ptp([x["ref"][1] for x in rows])), 1) if rows else None}
    ok = bool(rows) and same_lines and abs(d_med) <= TOLERANCE_DB and abs(d_p10) <= TOLERANCE_DB
    report = {"window_s": PAGE_WINDOW, "seeds": rows, "mean_diff": [round(d_med, 1), round(d_p10, 1)],
              "spread_across_seeds": spread, "tolerance_db": TOLERANCE_DB, "pass": ok}
    (folder / "booth_match.json").write_text(json.dumps(report, indent=1) + "\n")
    for x in rows:
        print("  seed %s: page %.1f / %.1f, shipped %.1f / %.1f, diff %+.1f / %+.1f, same lines %s (%d)" % (
            x["seed"], *x["ref"], *x["shipped"], *x["diff"], x["same_lines"], x["lines_compared"]))
    print("booth-match %s: mean diff %+.1f / %+.1f dB (median / busiest tenth); spread across seeds %s" % (
        "PASSED" if ok else "FAILED", d_med, d_p10, spread))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
