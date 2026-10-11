"""His bridge drill's verdict (round 26, brains B1; the orchestrator's C26.6 ruling, 2026-10-11).

A run passes when every crew that SURVIVED is across and no crew spent RIM_STUCK_S or more pressed at the water. A crew
killed in the fight before it crossed is excused only if it was not stuck before it died: under RIM_STUCK_S of rim +
deck-jam time in the DEATH_WINDOW_S before its death (BridgeStage's `dead` entries). A crew that dies pinned in a queue
is still a crossing failure: a jam that gets crews shot is the bug he would see.

    python3 tools/tactics/bridge_verdict.py build/bridge-series.jsonl   -> BRIDGE_POOLED line, one EXCUSED line per crew
"""
import json
import sys

RIM_STUCK_S = 3.0


def verdict(row):
    """(passed, reasons, excused) for one BRIDGE_PROBE row. `excused` lists one readable line per excused dead crew."""
    if row.get("missing"):
        return False, ["missing"], []
    reasons = []
    excused = []
    crews = int(row["crews"])
    uncrossed_dead = 0
    for d in row.get("dead", []):
        if d.get("crossed"):
            continue
        if float(d.get("stuck_s", 0.0)) >= RIM_STUCK_S:
            reasons.append("%s died stuck (%.1f s held in the last 10 s, killer %s)" % (d["name"], float(d["stuck_s"]), d.get("killer") or "?"))
            continue
        uncrossed_dead += 1
        excused.append("%s killed by %s at %.1f s, not stuck (%.1f s held in the last 10 s); speeds %s" % (
            d["name"], d.get("killer") or "?", float(d.get("died_s", -1)), float(d.get("stuck_s", 0.0)), d.get("speeds", [])))
    if int(row["crossed"]) + uncrossed_dead < crews:
        reasons.append("crossed %d of %d (%d excused dead)" % (int(row["crossed"]), crews, uncrossed_dead))
    if int(row.get("rim_crews", 1)) != 0:
        reasons.append("rim_crews %d" % int(row["rim_crews"]))
    return not reasons, reasons, excused


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    bad = []
    for row in rows:
        passed, reasons, excused = verdict(row)
        tag = "%s tick %s seed %s" % (row.get("side"), row.get("start_tick"), row.get("seed"))
        for line in excused:
            print("BRIDGE_EXCUSED %s: %s" % (tag, line))
        if not passed:
            bad.append("%s: %s" % (tag, "; ".join(reasons)))
    print("BRIDGE_POOLED %d of %d runs pass%s" % (len(rows) - len(bad), len(rows), ("; failing: %s" % " | ".join(bad)) if bad else ""))
    return 1 if bad or not rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
