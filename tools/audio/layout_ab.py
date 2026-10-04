#!/usr/bin/env python3
"""Round 17: does res://default_bus_layout.tres change anything native? `make layout-ab` records his match with the
declared layout and with --no-bus-layout (the buses built at runtime, as before), interleaved; this compares, per arm
and run: the whole mix (integrated LUFS, true peak), the booth's level, the World bus's gain across its effects (the
limiter and the booth's sidechain) while the booth speaks and while it doesn't, the music's level, the crowd's level.
Real-time runs are not sample-identical, so the verdict is the difference BETWEEN arms against the spread WITHIN an arm.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import pass_taps  # noqa: E402
import weapon_sheet  # noqa: E402


def level_db(path: Path) -> float:
    x, rate = weapon_sheet.read(path)
    x = weapon_sheet.mono(x)
    return float(20 * np.log10(max(np.sqrt(np.mean(x * x)), 1e-9)) + pass_taps.TAP_HEADROOM_DB)


def measure(wav: Path) -> dict:
    x, rate = weapon_sheet.read(wav)
    row = {"lufs": round(weapon_sheet.integrated_lufs(x, rate), 2), "tp": round(weapon_sheet.true_peak_db(x, rate), 2)}
    for tap in ("booth", "music", "crowd"):
        p = wav.with_suffix(".%s.wav" % tap)
        row[tap + "_db"] = round(level_db(p), 2) if p.exists() else None
    taps = pass_taps.analyse(wav)
    row["world_gain_median_db"] = taps.get("world", {}).get("gain_median_db")
    bm = pass_taps.booth_and_music(wav)
    row["booth_over_battle_db"] = bm.get("booth_over_battle_median_db")
    return row


def spoken(log: Path) -> list[str]:
    import re
    return re.findall(r"HUD_MESSAGE \[info\] (?:CALLER|VETERAN|PA): (.*)", log.read_text(errors="replace")) if log.exists() else []


def main(argv: list[str]) -> int:
    folder = Path(argv[0])
    rows = {}
    # Like for like: every run must hear the same commentary (--announcer-seed pins it; asserted here).
    heard = {w.stem: spoken(w.with_suffix(".log")) for w in sorted(folder.glob("*_[0-9].wav"))}
    common = min((len(h) for h in heard.values()), default=0)
    first = next(iter(heard.values()), [])
    same_lines = bool(common) and all(h[:common] == first[:common] for h in heard.values())
    print("same commentary in every run: %s (%d lines compared)" % (same_lines, common))
    for wav in sorted(folder.glob("*_[0-9].wav")):
        rows[wav.stem] = measure(wav)
    keys = ["lufs", "tp", "booth_db", "music_db", "crowd_db", "world_gain_median_db", "booth_over_battle_db"]
    report = {"runs": rows, "verdict": {}, "same_lines": same_lines}
    print("| run | " + " | ".join(keys) + " |")
    print("|---|" + "---|" * len(keys))
    for name, r in rows.items():
        print("| %s | %s |" % (name, " | ".join("%s" % r[k] for k in keys)))
    for k in keys:
        arms = {arm: [r[k] for n, r in rows.items() if n.startswith(arm) and r[k] is not None] for arm in ("runtime", "declared")}
        if not all(arms.values()):
            continue
        between = abs(np.mean(arms["declared"]) - np.mean(arms["runtime"]))
        within = max(np.ptp(v) if len(v) > 1 else 0.0 for v in arms.values())
        report["verdict"][k] = {"between_db": round(float(between), 2), "within_db": round(float(within), 2),
                                "equal": bool(between <= max(within, 0.5))}
    print("verdict (difference between arms vs spread within an arm, dB):")
    for k, v in report["verdict"].items():
        print("  %-22s between %5.2f  within %5.2f  %s" % (k, v["between_db"], v["within_db"], "EQUAL" if v["equal"] else "DIFFERS"))
    (folder / "layout_ab.json").write_text(json.dumps(report, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
