#!/usr/bin/env python3
"""The sim baseline, one line per dealt map (ship, round 18, S1/S2).

    sim_baseline.py layouts                         print the dealt maps (and the candidates), read from the game
    sim_baseline.py check  <file> <out_dir>         run the baseline match on every dealt map, compare to <file>
    sim_baseline.py read   <out_dir>                (on the build box) read every dealt map TWICE; refuse a disagreement
    sim_baseline.py adopt  <file> <reads.json>      merge every line that moved; print one commit message
    sim_baseline.py candidates <out_dir>            every candidate map plays a short headless match (check-all)

The file holds one line per (machine libc, map):

    # glibc-2.43 foundry: recorded on builder0 at ea61d450, twice, agreeing (2026-10-02)
    glibc-2.43 foundry 05df1d55ba49cde1

**Why per map.** Until round 18 the baseline ran one match on `foundry` (`Arena.DEFAULT_LAYOUT`), a map with no
containers that nobody is dealt. Round 17 turned every container on every dealt map and the baseline, correctly, did
not move; so a change to a map or to a brain that only shows on the maps he plays could pass it unseen. The maps come
from the game (`tests/support/dealt_layouts.gd`: `DEFAULT_LAYOUT` plus every name in `ROTATION`), so a map dealt
tomorrow with no line here is a FAILURE that names the adopt command -- never a skip. Candidates (C18.2: playable by
name, never dealt) carry no line, and the check says so on every run.

**The match** is the one everyone knows (`SIM_HASH_READ`: the sim_baseline doctrines, seed 3, 40 s, elimination),
with `--arena=<map>`; foundry's line stays the number it always was. The matches run concurrently: separate
processes on a fixed tick hash identically under any load (determinism.md), so seven maps cost about one.

**Arm assertions** (lesson 247: the arm is read from the running system, not the flag passed): an unknown `--arena`
falls back to foundry with an "arena: ... using foundry" error, which this treats as a failure of that map; and no two
maps may share a hash, since two different maps cannot fight the same fight.

The commands are injectable so every branch can be driven by a stub (lesson 250):
    SIM_BASELINE_LAYOUTS_CMD   prints a `DEALT_LAYOUTS {json}` line
    SIM_BASELINE_MATCH_CMD     a shell command with `{layout}` in it; prints a `MATCH_RESULT {json}` line
    SIM_BASELINE_KEY           the machine key (default glibc-<getconf GNU_LIBC_VERSION>)
    SIM_BASELINE_JOBS          concurrent matches (default: all of them)
"""

from __future__ import annotations

import datetime
import json
import os
import re
import socket
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HASH = re.compile(r"^[0-9a-f]{16}$")
KEY = re.compile(r"^[A-Za-z0-9._+-]+$")
NAME = re.compile(r"^[a-z0-9_]+$")
ADOPT = "make sim-baseline-adopt"
# Arena._ready's own fallback message for a name it cannot load (game/arena/arena.gd): the arm assertion.
FALLBACK = re.compile(r"arena: .*; using ")


# ---- the file ------------------------------------------------------------------------------------------------

def parse(text: str) -> tuple[dict[tuple[str, str], tuple[str, str]], list[str]]:
    """(key, layout) -> (hash, provenance comment); plus the lines it could not read (never silently dropped)."""
    entries: dict[tuple[str, str], tuple[str, str]] = {}
    bad: list[str] = []
    pending = ""
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            pending = stripped
            continue
        parts = stripped.split()
        if len(parts) == 3 and KEY.match(parts[0]) and NAME.match(parts[1]) and HASH.match(parts[2]):
            entries[(parts[0], parts[1])] = (parts[2], pending)
        else:
            bad.append(stripped)
        pending = ""
    return entries, bad


def render(entries: dict[tuple[str, str], tuple[str, str]], order: list[str]) -> str:
    """Grouped by machine; within one, the dealt order (default first, then the rotation), then anything else."""
    rank = {name: i for i, name in enumerate(order)}
    out = []
    for key, layout in sorted(entries, key=lambda kl: (kl[0], rank.get(kl[1], len(rank)), kl[1])):
        value, comment = entries[(key, layout)]
        if comment:
            out.append(comment)
        out.append(f"{key} {layout} {value}")
    return "\n".join(out) + "\n"


def read_file(path: str) -> tuple[dict, list[str]]:
    p = Path(path)
    return parse(p.read_text()) if p.exists() else ({}, [])


# ---- the game ------------------------------------------------------------------------------------------------

def machine_key() -> str:
    if os.environ.get("SIM_BASELINE_KEY"):
        return os.environ["SIM_BASELINE_KEY"]
    version = subprocess.run(["getconf", "GNU_LIBC_VERSION"], capture_output=True, text=True).stdout.split()
    return "glibc-" + (version[1] if len(version) > 1 else "unknown")


def layouts() -> dict:
    """{"dealt": [default, *rotation], "candidates": [...]} from the game; raises with what it printed."""
    cmd = os.environ.get("SIM_BASELINE_LAYOUTS_CMD", "")
    if not cmd:
        raise RuntimeError("SIM_BASELINE_LAYOUTS_CMD is not set (the Makefile sets it)")
    run = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    for line in run.stdout.splitlines():
        if line.startswith("DEALT_LAYOUTS "):
            data = json.loads(line[len("DEALT_LAYOUTS "):])
            dealt: list[str] = []
            for name in [data.get("default", "")] + list(data.get("rotation", [])):
                if name and name not in dealt:
                    dealt.append(name)
            if not dealt or not data.get("rotation"):
                raise RuntimeError(f"the game reported no rotation: {line}")
            return {"dealt": dealt, "candidates": [c for c in data.get("candidates", []) if c not in dealt]}
    raise RuntimeError(f"no DEALT_LAYOUTS line (exit {run.returncode}):\n{run.stdout[-800:]}{run.stderr[-800:]}")


def one_match(layout: str, log_dir: Path, tag: str) -> dict:
    """{"layout", "hash" or "", "error" or ""}; the run's stderr is kept in <log_dir>/<layout><tag>.err."""
    cmd = os.environ.get("SIM_BASELINE_MATCH_CMD", "")
    if "{layout}" not in cmd:
        return {"layout": layout, "hash": "", "error": "SIM_BASELINE_MATCH_CMD has no {layout}"}
    run = subprocess.run(cmd.replace("{layout}", layout), shell=True, capture_output=True, text=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    (log_dir / f"{layout}{tag}.err").write_text(run.stderr)
    fallback = FALLBACK.search(run.stderr)
    if fallback:
        return {"layout": layout, "hash": "", "error": f"the game did not load it ({fallback.group(0)}...)"}
    for line in run.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            try:
                value = str(json.loads(line[len("MATCH_RESULT "):]).get("state_hash", ""))
            except json.JSONDecodeError as err:
                return {"layout": layout, "hash": "", "error": f"unreadable MATCH_RESULT ({err})"}
            if HASH.match(value):
                return {"layout": layout, "hash": value, "error": ""}
            return {"layout": layout, "hash": "", "error": f"MATCH_RESULT state_hash {value!r} is not a hash"}
    return {"layout": layout, "hash": "", "error": f"no MATCH_RESULT (exit {run.returncode})"}


def run_all(names: list[str], log_dir: Path, tags: list[str]) -> dict[str, list[dict]]:
    """Every (layout, tag) at once; layout -> one result per tag, in tag order."""
    jobs = [(name, tag) for name in names for tag in tags]
    workers = int(os.environ.get("SIM_BASELINE_JOBS") or 0) or len(jobs)
    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        results = list(pool.map(lambda job: one_match(job[0], log_dir, job[1]), jobs))
    out: dict[str, list[dict]] = {name: [] for name in names}
    for (name, _tag), result in zip(jobs, results):
        out[name].append(result)
    return out


def shared_hashes(hashes: dict[str, str]) -> list[str]:
    seen: dict[str, list[str]] = {}
    for name, value in hashes.items():
        if value:
            seen.setdefault(value, []).append(name)
    return [f"{', '.join(names)} share {value}" for value, names in seen.items() if len(names) > 1]


# ---- check ---------------------------------------------------------------------------------------------------

def cmd_check(path: str, out_dir: str) -> int:
    out = Path(out_dir)
    key = machine_key()
    try:
        maps = layouts()
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"sim-baseline FAILED: could not read the dealt maps from the game: {err}")
        return 1
    entries, bad = read_file(path)
    mine = {layout: value for (k, layout), (value, _c) in entries.items() if k == key}
    runs = run_all(maps["dealt"], out / "logs", [""])
    actual = {name: runs[name][0]["hash"] for name in maps["dealt"]}

    out.mkdir(parents=True, exist_ok=True)
    rows = [f"{key} {name} {actual[name] or '-'} {mine.get(name, 'none')}" for name in maps["dealt"]]
    (out / "lines.txt").write_text("\n".join(rows) + "\n")

    failures: list[str] = []
    for line in bad:
        failures.append(f"unreadable line in {path}: {line!r} (want '<glibc> <map> <16 hex>')")
    print(f"sim-baseline: {len(maps['dealt'])} dealt maps on {key} ({socket.gethostname()}): {' '.join(maps['dealt'])}")
    for name in maps["dealt"]:
        result = runs[name][0]
        expected = mine.get(name)
        if result["error"]:
            failures.append(f"{name}: {result['error']} (stderr: {out / 'logs' / (name + '.err')})")
            print(f"  {name:<10} ERROR    {result['error']}")
        elif not mine:
            print(f"  {name:<10} {result['hash']}  (no lines for {key})")
        elif expected is None:
            failures.append(f"{name}: a DEALT map with no line for {key} (got {result['hash']}). "
                            f"Record it on purpose: {ADOPT}")
            print(f"  {name:<10} {result['hash']}  NO LINE")
        elif expected == result["hash"]:
            print(f"  {name:<10} {result['hash']}  unmoved")
        else:
            failures.append(f"{name} MOVED: expected {expected}, got {result['hash']}")
            print(f"  {name:<10} {result['hash']}  MOVED (was {expected})")
    for shared in shared_hashes(actual):
        failures.append(f"two maps fought the same fight ({shared}): one of them did not load as itself")
    for name in maps["candidates"]:
        print(f"  {name:<10} candidate: never dealt, no baseline line (C18.2)")
    for name in sorted(set(mine) - set(maps["dealt"])):
        print(f"  {name:<10} has a line but is not dealt: not checked ({ADOPT} drops it)")

    if not failures and not mine:
        print(f"sim-baseline SKIPPED: no baseline lines for {key}. The canonical ones are builder0's "
              "(make remote T=check); see _agents/determinism.md")
        return 0
    if not failures:
        print(f"sim-baseline passed: {len(maps['dealt'])} maps unmoved ({key})")
        return 0
    print(f"sim-baseline FAILED on {key}:")
    for failure in failures:
        print(f"  - {failure}")
    if any("MOVED" in f or "no line" in f for f in failures):
        print(f"  If gameplay changed ON PURPOSE: {ADOPT} (reads every dealt map twice on builder0, refuses a "
              "disagreement, merges the lines, prints the commit message). Otherwise the map named above is where "
              "to look: make container-hashes CH_LAYOUTS=<map> reads one map's hash.")
    return 1


# ---- read (on the build box) ---------------------------------------------------------------------------------

def cmd_read(out_dir: str) -> int:
    out = Path(out_dir)
    reads_path = out / "sim_baseline_adopt.json"
    reads_path.unlink(missing_ok=True)
    key = machine_key()
    try:
        maps = layouts()
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"sim-baseline-adopt FAILED: could not read the dealt maps from the game: {err}")
        return 1
    print(f">> sim-baseline-adopt: reading {len(maps['dealt'])} maps twice on {socket.gethostname()} ({key})...")
    runs = run_all(maps["dealt"], out / "logs", [".1", ".2"])
    refused: list[str] = []
    for name in maps["dealt"]:
        first, second = runs[name]
        if first["error"] or second["error"]:
            refused.append(f"{name}: {first['error'] or second['error']}")
        elif first["hash"] != second["hash"]:
            refused.append(f"{name}: the two reads DISAGREE (first {first['hash']}, second {second['hash']})")
        print(f"  {name:<10} {first['hash'] or '-'} {second['hash'] or '-'}")
    for shared in shared_hashes({name: runs[name][0]["hash"] for name in maps["dealt"]}):
        refused.append(f"two maps fought the same fight ({shared}): one of them did not load as itself")
    if refused:
        print("sim-baseline-adopt REFUSED: nothing was adopted.")
        for line in refused:
            print(f"  - {line}")
        if any("DISAGREE" in r for r in refused):
            print("  A hash that does not reproduce on its own machine is not a baseline. Something in the simulation")
            print("  is not deterministic on that map; adopting either number would bless it and every later check")
            print("  would compare against a coin. Find the non-determinism first.")
        return 1
    record = {
        "key": key,
        "hashes": {name: runs[name][0]["hash"] for name in maps["dealt"]},
        "order": maps["dealt"],
        "commit": os.environ.get("TANK_SQUAD_COMMIT") or _git_head(),
        "machine": socket.gethostname(),
        "date": datetime.date.today().isoformat(),
    }
    out.mkdir(parents=True, exist_ok=True)
    reads_path.write_text(json.dumps(record, indent=1) + "\n")
    print(f">> sim-baseline-adopt: {len(maps['dealt'])} maps read twice, agreeing")
    return 0


def _git_head() -> str:
    run = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    return run.stdout.strip() or "unknown"


# ---- adopt (here) --------------------------------------------------------------------------------------------

def cmd_adopt(path: str, reads: str) -> int:
    try:
        record = json.loads(Path(reads).read_text())
        key, hashes, order = record["key"], record["hashes"], record["order"]
        commit, machine, when = record["commit"], record["machine"], record["date"]
    except (OSError, json.JSONDecodeError, KeyError) as err:
        print(f"sim-baseline-adopt FAILED: no readable {reads} came back from the box ({err}). Nothing was adopted.")
        return 1
    if not KEY.match(key) or not all(NAME.match(n) and HASH.match(h) for n, h in hashes.items()) or not hashes:
        print(f"sim-baseline-adopt FAILED: {reads} holds something that is not a baseline: {record!r}")
        return 1
    entries, bad = read_file(path)
    if bad:
        print(f"sim-baseline-adopt FAILED: {path} has lines it cannot read, fix them by hand first: {bad}")
        return 1
    machines = {k for (k, _l) in entries}
    before = {layout: value for (k, layout), (value, _c) in entries.items() if k == key}
    stamp = f"recorded on {machine} at {commit}, twice, agreeing ({when})"

    changes: list[str] = []
    for name in order:
        old = before.get(name)
        if old == hashes[name]:
            continue
        entries[(key, name)] = (hashes[name], f"# {key} {name}: {stamp}")
        changes.append(f"{name} {old or '(no line)'} -> {hashes[name]}")
    dropped = sorted(set(before) - set(order))
    for name in dropped:
        del entries[(key, name)]
        changes.append(f"{name} {before[name]} -> (dropped: no longer dealt)")

    if key not in machines:
        print(f"sim-baseline-adopt: {key} is a machine with no lines yet; adding {len(order)} (other machines' lines kept: "
              f"{', '.join(sorted(machines)) or 'none'})")
    if not changes:
        print(f"sim-baseline-adopt: nothing moved. All {len(order)} dealt maps on {key} match {path}; nothing written.")
        return 0
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(render(entries, order))
    tmp.replace(target)
    unmoved = [n for n in order if before.get(n) == hashes[n]]
    print(f"sim-baseline-adopt: {len(changes)} line(s) changed on {key}; unmoved: {', '.join(unmoved) or 'none'}")
    for change in changes:
        print(f"  {change}")
    moved_names = [c.split()[0] for c in changes]
    print("")
    print("Now commit it, and say WHY each map moved (Invariant 2 -- a moved baseline with no named cause is a")
    print("regression nobody noticed):")
    print("")
    print(f"    git add {path}")
    print(f"    git commit -m \"baselines: sim hashes on {key} moved on {', '.join(moved_names)} (<the change that moved them>)")
    print("")
    for change in changes:
        print(f"    {change}")
    print(f"    unmoved: {', '.join(unmoved) or 'none'}")
    print(f"    Each read twice at {commit} on {machine}, agreeing. <Why gameplay changed on purpose.>\"")
    return 0


# ---- candidates (S4): each loads and plays, no line ----------------------------------------------------------

def cmd_candidates(out_dir: str) -> int:
    """Every candidate map (C18.2: playable by name, never dealt) runs SIM_BASELINE_SMOKE_CMD (a short headless match).
    Fails on no result or a fallback to foundry; the engine lines each run printed are echoed so the check's
    engine-message gate (tools/engine_log_gate.py) judges them in this target's log."""
    try:
        maps = layouts()
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"candidates-smoke FAILED: could not read the maps from the game: {err}")
        return 1
    names = maps["candidates"]
    if not names:
        print("candidates-smoke: the game lists no candidate maps (Arena.CANDIDATES); nothing to run")
        return 0
    os.environ["SIM_BASELINE_MATCH_CMD"] = os.environ.get("SIM_BASELINE_SMOKE_CMD", "")
    runs = run_all(names, Path(out_dir) / "logs", [".smoke"])
    failures = []
    for name in names:
        result = runs[name][0]
        err_log = Path(out_dir) / "logs" / f"{name}.smoke.err"
        engine = [line for line in err_log.read_text().splitlines()
                  if re.match(r"^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING):", line)
                  or "parsing error" in line] if err_log.exists() else []
        for line in engine:
            print(line)
        if result["error"]:
            failures.append(f"{name}: {result['error']}")
        print(f"  {name:<14} {'ERROR ' + result['error'] if result['error'] else 'played'}"
              f"{f', {len(engine)} engine line(s) above' if engine else ''}")
    if failures:
        print(f"candidates-smoke FAILED: {'; '.join(failures)}")
        return 1
    print(f"candidates-smoke: {len(names)} candidate map(s) loaded and played: {' '.join(names)}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "layouts":
        try:
            maps = layouts()
        except (RuntimeError, json.JSONDecodeError) as err:
            print(f"layouts FAILED: {err}")
            return 1
        print(f"dealt: {' '.join(maps['dealt'])}")
        print(f"candidates: {' '.join(maps['candidates']) or '(none)'}")
        return 0
    if len(argv) == 4 and argv[1] == "check":
        return cmd_check(argv[2], argv[3])
    if len(argv) == 3 and argv[1] == "candidates":
        return cmd_candidates(argv[2])
    if len(argv) == 3 and argv[1] == "read":
        return cmd_read(argv[2])
    if len(argv) == 4 and argv[1] == "adopt":
        return cmd_adopt(argv[2], argv[3])
    print("\n".join(__doc__.strip().splitlines()[2:7]), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
