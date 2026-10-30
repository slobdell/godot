#!/usr/bin/env python3
"""R46.11: the rule switches a replay of his recording must turn off, read from the recording's own build stamp.

    python3 tests/replay/rules.py HIS.jsonl ["REPLAY_FLAGS"]  ->  prints the flags to add (space-separated, maybe none), and one
                                                               REPLAY_RULES line on stderr

A rule that ships ON changes every later replay of a match played without it (engage's L2 `--lane-clear`: his Terminus replay
left his match at 22 s, Gorge at 50 s). The `match` row's `rules` key (MatchRecorder.rules(), round 46) says which rules the build
that played it had ON. Each rule in RULES is turned off when that build had it off, or when the recording has no `rules` key or
no entry for it (it was played on a build older than the stamp, so before the rule shipped ON). A rule the recording's own `flags`
set, or one named in REPLAY_FLAGS (an A/B of the replay), is left alone.
"""
import gzip
import json
import sys

# rule key in `rules` -> (the launch switch, the value that turns it off)
RULES = {"lane_clear": ("lane-clear", "off")}


def decide(path, replay_flags=""):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        header = json.loads(handle.readline())
    stamped = header.get("rules")
    played_flags = header.get("flags", {}) or {}
    add, why = [], []
    for rule, (switch, off) in RULES.items():
        if ("--%s" % switch) in replay_flags:
            why.append("%s: as REPLAY_FLAGS says" % switch)
        elif switch in played_flags:
            why.append("%s: his match set --%s=%s (the replay applies it)" % (switch, switch, played_flags[switch]))
        elif stamped is None or rule not in stamped:
            add.append("--%s=%s" % (switch, off))
            why.append("%s: recorded before the build stamp had it: --%s=%s" % (switch, switch, off))
        elif not stamped[rule]:
            add.append("--%s=%s" % (switch, off))
            why.append("%s: his build ran it OFF: --%s=%s" % (switch, switch, off))
        else:
            why.append("%s: his build ran it ON" % switch)
    return add, "; ".join(why)


if __name__ == "__main__":
    flags, why = decide(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
    print("REPLAY_RULES %s: %s" % (" ".join(flags) or "none", why), file=sys.stderr)
    print(" ".join(flags))
