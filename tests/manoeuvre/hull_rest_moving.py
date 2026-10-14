#!/usr/bin/env python3
"""Round 29 (manoeuvre M0/M1): what the crews still moving at the hull-rest judge were doing.

Reads <dir>/<arm>/<faction>/<task>-<seed>/screen.json (per-crew `still` at the judging moment) and the run's run.log,
which carries `MANOEUVRE_STATE` lines when the arm ran with `M1_FLAGS=--turn-states` (ManoeuvreCensus: each crew once a
second). For every crew not still at the judge, its last state line before the judge (`SCREEN {`) names what it was doing:
  face_legs    a face at rest, driving a planned leg (Manoeuvre.plan_face)
  face_creep   a face at rest, no plan (none fitted, refused, or retrying): the creep's shuffle
  pinned       a move whose hull is not getting anywhere (real speed < 0.3 m/s under |throttle| > 0.3; round 30 M4b:
               Tank.real_velocity from the state line's `real`, the plant's `moved` in older logs)
  dressing     a move within 8 m of its goal
  driving      a move further out
  other        any other order
Prints MOVING_KIND per task x arm (MOVING_KIND_WT: wheeled turreted hulls only), then each moving crew of the arms' worst runs (lesson 302). Report only.
"""
import json
import pathlib
import re
import sys

STATE = re.compile(r"MANOEUVRE_STATE f (\d+) (.+?) (\S+) order (\S*) from (\S*) v ([-\d.]+) moved ([-\d.]+) "
                   r"cmd ([-\d.]+)/([-\d.]+) face (\d+)/([-\d.]+) blocked (\S+) retry (-?\d+) touch (\S+) "
                   r"stuck ([-\d.]+) pivot (\S+) esc ([-\d.]+) goal ([-\d.]+)(?: real ([-\d.]+))?")
KINDS = ("face_legs", "face_creep", "pinned", "dressing", "driving", "other", "no_state")


def kind_of(m) -> str:
    if m is None:
        return "no_state"
    order = m.group(4)
    if order == "face":
        return "face_legs" if int(m.group(10)) > 0 or float(m.group(11)) > 0.0 else "face_creep"
    if order == "move_to":
        # Round 30 (M4b): pinned by the motion the hull really made (`real`, Tank.real_velocity) when the log has it;
        # older logs carry only the plant's reading (`moved`, estimated_velocity: 12 m/s on a pinned truck).
        made = float(m.group(19)) if m.group(19) is not None else float(m.group(7))
        if made < 0.3 and abs(float(m.group(8))) > 0.3:
            return "pinned"
        return "dressing" if float(m.group(18)) <= 8.0 else "driving"
    return "other"


def main(root: str) -> int:
    table = {}  # task -> arm -> kind -> n
    focus = {}  # the same, wheeled turreted hulls only (the hulls M1 turns)
    worst = {}  # arm -> (moving, path, [(unit, kind, line)])
    saw_states = False
    for path in sorted(pathlib.Path(root).glob("*/*/*/screen.json")):
        arm = path.parts[-4]
        last = {}
        log = path.parent / "run.log"
        if log.exists():
            for line in log.read_text(errors="replace").splitlines():
                if line.startswith("SCREEN {"):
                    break  # the judge: the probe stops every crew after it
                m = STATE.search(line)
                if m:
                    last[m.group(2)] = m
        saw_states = saw_states or bool(last)
        for row in json.loads(path.read_text()):
            if "squads" not in row:
                continue
            task = row["scenario"]
            crews = []
            for squad in row["squads"]:
                for crew in squad.get("each", []):
                    if crew.get("still", True):
                        continue
                    m = last.get(crew.get("unit", ""))
                    k = kind_of(m)
                    table.setdefault(task, {}).setdefault(arm, {}).setdefault(k, 0)
                    table[task][arm][k] += 1
                    if crew.get("class") == "wheels/turret":
                        focus.setdefault(task, {}).setdefault(arm, {}).setdefault(k, 0)
                        focus[task][arm][k] += 1
                    crews.append((crew.get("unit", "?"), crew.get("id", "?"), crew.get("hull_error_deg"), k,
                                  m.group(0) if m else ""))
            if crews and len(crews) > worst.get(arm, (0,))[0]:
                worst[arm] = (len(crews), str(path.parent), crews)
    if not table:
        print(f"MOVING_KIND nothing moving (or no rows) under {root}")
        return 0
    if not saw_states:
        print("MOVING_KIND (no MANOEUVRE_STATE lines: run the arms with M1_FLAGS=--turn-states for the kinds)")
    print("MOVING_KIND task | arm | " + " | ".join(KINDS) + " | total")
    for task in sorted(table):
        for arm in sorted(table[task]):
            counts = [table[task][arm].get(k, 0) for k in KINDS]
            print(f"MOVING_KIND {task} | {arm} | " + " | ".join(str(c) for c in counts) + f" | {sum(counts)}")
    print("MOVING_KIND_WT (wheels/turret only) task | arm | " + " | ".join(KINDS) + " | total")
    for task in sorted(focus):
        for arm in sorted(focus[task]):
            counts = [focus[task][arm].get(k, 0) for k in KINDS]
            print(f"MOVING_KIND_WT {task} | {arm} | " + " | ".join(str(c) for c in counts) + f" | {sum(counts)}")
    for arm in sorted(worst):
        n, where, crews = worst[arm]
        print(f"MOVING_WORST {arm}: {n} moving in {where}")
        for unit, uid, err, k, line in crews:
            print(f"MOVING_WORST   {unit} ({uid}) {err} deg {k}: {line[16:200]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/manoeuvre/hull-rest"))
