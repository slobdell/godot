#!/usr/bin/env python3
"""Round 16 (brains A1): behaviour parity for performance work.

Runs one headless `--match` per (map, seed), keeps each MATCH_RESULT minus the wall-clock fields (real_seconds,
speedup), and writes them as sorted JSON lines plus one digest. A brains change that claims "no decision changed"
must print the same digest before and after: `make ai-parity` on both commits, or `make ai-parity PARITY_REF=<file>`
to compare against a saved run and name the first run that differs.

The workload is brain-heavy on purpose (CPU armies of two factions at the lead's army sizes, elimination, a time
limit): the state hash in MATCH_RESULT covers every tank's position, heading, turret, health and suppression at the
end, so one changed decision anywhere in the minute shows up.
"""
import argparse
import hashlib
import platform
import socket
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

WALL_CLOCK_FIELDS = ("real_seconds", "speedup")


def seeds_of(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            lo, hi = part.split("-")
            out.extend(range(int(lo), int(hi) + 1))
        elif part:
            out.append(int(part))
    return out


def run_one(godot, sim_hz, arena, seed, args):
    cmd = [godot, "--headless", "--fixed-fps", str(sim_hz), "--path", ".", "--", "--match", "--elimination",
           f"--arena={arena}", f"--seed={seed}", f"--time-limit={args.time}", f"--budget={args.budget}",
           f"--green-faction={args.green}", f"--rust-faction={args.rust}"] + args.extra.split()
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    line = next((l for l in proc.stdout.splitlines() if l.startswith("MATCH_RESULT ")), None)
    if line is None:
        return {"arena": arena, "seed": seed, "error": f"no MATCH_RESULT (exit {proc.returncode})",
                "tail": proc.stdout[-800:] + proc.stderr[-800:]}
    result = json.loads(line[len("MATCH_RESULT "):])
    for field in WALL_CLOCK_FIELDS:
        result.pop(field, None)
    return {"arena": arena, "seed": seed, "result": result}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--sim-hz", default=30)
    ap.add_argument("--maps", default="yard,terminus")
    ap.add_argument("--seeds", default="1-8")
    ap.add_argument("--time", default=60)
    ap.add_argument("--budget", default=2600)
    ap.add_argument("--green", default="law")
    ap.add_argument("--rust", default="condemned")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ref", default="")
    ap.add_argument("--extra", default="", help="more match flags, e.g. --brains-off=all (the switched-off arm)")
    args = ap.parse_args()
    runs = [(m, s) for m in args.maps.split(",") for s in seeds_of(args.seeds)]
    print(f">> ai-parity: maps={args.maps} seeds={args.seeds} time={args.time} budget={args.budget} "
          f"{args.green} v {args.rust} {args.extra}, {len(runs)} matches", flush=True)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(lambda r: run_one(args.godot, args.sim_hz, r[0], r[1], args), runs))
    lines = [json.dumps(row, sort_keys=True) for row in rows]
    with open(args.out, "w") as f:
        f.write("\n".join(lines) + "\n")
    errors = [row for row in rows if "error" in row]
    for row in rows:
        r = row.get("result", {})
        print(f"AI_PARITY {row['arena']} seed {row['seed']}: "
              + (row["error"] if "error" in row else
                 f"hash {r.get('state_hash')} score {r.get('score')} winner {r.get('winner', '')}"))
    digest = hashlib.md5("\n".join(lines).encode()).hexdigest()
    # Round 17: a digest is a PER-MACHINE reference (MATCH_RESULT's state hash depends on glibc, trip-up 63): round 16's
    # cf50ef2b and builder0's 0095f2cf are the same tree on two machines. Name the machine on the line.
    libc = "-".join(platform.libc_ver())
    print(f"AI_PARITY_DIGEST {digest} ({len(rows)} matches) on {socket.gethostname()} ({libc}) -> {args.out}")
    if errors:
        for row in errors:
            print(row.get("tail", ""), file=sys.stderr)
        print(f"ai-parity: {len(errors)} match(es) produced no result")
        return 1
    if args.ref:
        ref = {}
        with open(args.ref) as f:
            for raw in f:
                if raw.strip():
                    r = json.loads(raw)
                    ref[(r["arena"], r["seed"])] = r
        differ = [row for row in rows if ref.get((row["arena"], row["seed"])) != row]
        if differ:
            for row in differ:
                print(f"ai-parity: DIFFERS {row['arena']} seed {row['seed']}")
            print(f"ai-parity: {len(differ)} of {len(rows)} matches differ from {args.ref} -- a decision changed")
            return 1
        print(f"ai-parity: all {len(rows)} matches identical to {args.ref}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
