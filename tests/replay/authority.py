#!/usr/bin/env python3
"""R45.24: whether a replay of his recording needs `--player-authority=off` (the game before engage's E2).

    python3 tests/replay/authority.py HIS.jsonl [auto|on|off]   ->  prints `on` or `off`, and one REPLAY_AUTHORITY line on stderr

E2 (his order to a crew outranks its squad's drills) reached main at 2026-10-29 15:11 PDT (merge 8ef4f584d); a match recorded before
it ran without it, and replays with it diverge (engage: Gorge 4/20 from 40 s; with `--player-authority=off` 20/20 for 105 s). The
header carries no version, so `auto` reads the recording's own name stamp (`path`: build/recordings/<YYYY-MM-DDTHH-MM-SS>-<arena>,
his laptop's local time). LIMIT: a match played after the merge on a checkout that had not pulled main yet reads `on` wrongly:
REPLAY_AUTHORITY=off says so. `on` / `off` are taken as given.
"""
import gzip
import json
import re
import sys

E2_ON_MAIN = "2026-10-29T15-11-37"


def decide(path, mode="auto"):
    if mode in ("on", "off"):
        return mode, "as asked (REPLAY_AUTHORITY=%s)" % mode
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        header = json.loads(handle.readline())
    stamp = re.search(r"(\d{4}-\d\d-\d\dT\d\d-\d\d-\d\d)", str(header.get("path", "")) or path)
    if stamp is None:
        stamp = re.search(r"(\d{4}-\d\d-\d\dT\d\d-\d\d-\d\d)", path)
    if stamp is None:
        return "on", "no date stamp in the recording's name: today's game (REPLAY_AUTHORITY=off for an older match)"
    when = stamp.group(1)
    if when < E2_ON_MAIN:
        return "off", "recorded %s, before E2 reached main (%s): --player-authority=off" % (when, E2_ON_MAIN)
    return "on", "recorded %s, after E2 reached main (%s)" % (when, E2_ON_MAIN)


if __name__ == "__main__":
    answer, why = decide(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "auto")
    print("REPLAY_AUTHORITY %s: %s" % (answer, why), file=sys.stderr)
    print(answer)
