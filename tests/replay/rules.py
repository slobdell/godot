#!/usr/bin/env python3
"""R46.11: the rule switches a replay of his recording must turn off, read from the recording's own build stamp.

    python3 tests/replay/rules.py HIS.jsonl ["REPLAY_FLAGS"]  ->  prints the flags to add (space-separated, maybe none), and one
                                                               REPLAY_RULES line on stderr

A rule that ships ON changes every later replay of a match played without it (engage's L2 `--lane-clear`: his Terminus replay
left his match at 22 s, Gorge at 50 s). The `match` row's `rules` key (MatchRecorder.rules(), round 46) says which rules the build
that played it had ON. Each rule in RULES is turned off when that build had it off, or when the recording has no `rules` key or
no entry for it (it was played on a build older than the stamp, so before the rule shipped ON). A rule the recording's own `flags`
set, or one named in REPLAY_FLAGS (an A/B of the replay), is left alone.

Round 47 (N0): every replay-relevant rule that shipped ON in round 46, not lane_clear alone. His round-46 recordings carry only
`lane_clear` in their stamp, so a rule with no entry is decided by WHEN the recording was made (its `path` name) against when the
rule reached main: made after, his build ran it ON (no flag); made before, or undatable, it is turned off. The weave's dry_hop
(R46.21, with L1c) has no off switch and cannot be turned off here; the camera planner is presentation (no sim effect).
"""
import gzip
import json
import os
import re
import sys

# rule key in `rules` -> (the launch switch, the value that turns it off, when it reached main ON: the recorder's name stamp)
RULES = {
    "lane_clear": ("lane-clear", "off", "2026-10-30T06-04-20"),   # engage L1c, merge 0471b8e14
    "group_veto": ("group-veto", "off", "2026-10-30T06-42-57"),   # orders V1, merge 8e79c2168
    "shortfwd": ("traffic-off", "shortfwd", "2026-10-30T08-12-12"),  # manoeuvre, merge af9f7bb2b
    "holdway": ("traffic-off", "holdway", "2026-10-30T08-40-38"),  # manoeuvre, merge 097f61ccc (native game; OFF on web)
    # R47.22 (round 47, orders): the money is the army's cap; a match played before it had the laptop's count trim.
    "army_money": ("army-cap", "count", "2026-10-30T21-30-05"),  # orders 1c2fc5838, merged by the orchestrator
    # Round 47 (mapkit's note: his round-46 Crossing parted at 2-3 s): every other sim rule that shipped ON this round.
    "press_on": ("press-on", "off", "2026-10-30T19-45-51"),       # engage E7, merge b96e12e43 (R47.32)
    "battery_screen": ("battery-screen", "off", "2026-10-30T20-09-23"),  # orders O6, merge 09780edb9
    "buried": ("traffic-off", "buried", "2026-10-30T20-54-12"),   # manoeuvre, merge 06ba81b45 (R47.33)
    "holdyield": ("traffic-off", "holdyield", "2026-10-31T00-13-18"),  # manoeuvre, merge c41ae23bb (R47.42)
    "group_merged": ("group-merged", "off", "2026-10-31T00-41-40"),  # orders O1 v3, merge de3176388 (R47.41)
    "pot_shot": ("pot-shot", "off", "2026-10-31T03-14-17"),       # engage E3, merge 8d51777cc (R47.37)
}
STAMP = re.compile(r"(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})")


def recorded_at(header):
    found = STAMP.search(os.path.basename(str(header.get("path", ""))))
    return found.group(1) if found else ""


def _named(flags_text, switch, off):
    """Whether a flag string names this rule's switch (for traffic-off: the rule's own name in its list)."""
    for word in flags_text.split():
        if word.startswith("--%s=" % switch) or word == "--" + switch:
            if switch != "traffic-off" or off in word.split("=", 1)[-1].split(","):
                return True
        if switch == "traffic-off" and word.startswith("--traffic-on=") and off in word.split("=", 1)[1].split(","):
            return True
    return False


def decide(path, replay_flags=""):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        header = json.loads(handle.readline())
    stamped = header.get("rules")
    played_flags = header.get("flags", {}) or {}
    played_text = " ".join("--%s=%s" % (k, v) if v != "" else "--" + k for k, v in played_flags.items())
    made = recorded_at(header)
    add, why = [], []
    for rule, (switch, off, shipped) in RULES.items():
        flag = "--%s=%s" % (switch, off)
        if _named(replay_flags, switch, off):
            why.append("%s: as REPLAY_FLAGS says" % rule)
        elif _named(played_text, switch, off):
            why.append("%s: his match set it (the replay applies his flags)" % rule)
        elif stamped is not None and rule in stamped:
            if stamped[rule]:
                why.append("%s: his build ran it ON" % rule)
            else:
                add.append(flag)
                why.append("%s: his build ran it OFF: %s" % (rule, flag))
        elif made != "" and made >= shipped:
            why.append("%s: recorded %s, after it reached main ON (%s)" % (rule, made, shipped))
        else:
            add.append(flag)
            why.append("%s: recorded before it reached main (or undated): %s" % (rule, flag))
    return add, "; ".join(why)


if __name__ == "__main__":
    flags, why = decide(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
    print("REPLAY_RULES %s: %s" % (" ".join(flags) or "none", why), file=sys.stderr)
    print(" ".join(flags))
