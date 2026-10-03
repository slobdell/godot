#!/usr/bin/env python3
"""Round 17 (brains T1): a decision lever's BEHAVIOUR columns beside the champion's.

One headless `--match` per (arm, seed): both sides on the arm's brain variant (`--green-brain=<arm> --rust-brain=<arm>`),
the lead's Sumps workload (Law v Condemned at his army sizes) by default, `--brains-census` for the brains' own
think-LOD counts. Per arm it reports the pace of the fight from MATCH_RESULT (first shot, first kill, kills, shots,
hits, damage) and the first second any brain was at the fight rate (first contact in reach), each as a median and a
mean over the seeds, with the per-seed values kept in the JSON. The seeds are named before the first run (lesson 224):
PRICE_SEEDS in mk/ai.mk. The champion's arm is run twice when --control is given: the two must be byte-identical
(the run is deterministic, so a difference there means the comparison itself is unsound).
"""
import argparse
import hashlib
import json
import re
import statistics
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

LOD_RE = re.compile(r"^BRAINS_LOD unit-ticks (\{.*?\}); thinks (\{.*?\}); first fight-rate tick (-?\d+)", re.M)


def seeds_of(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            lo, hi = part.split("-")
            out.extend(range(int(lo), int(hi) + 1))
        elif part:
            out.append(int(part))
    return out


def run_one(args, arm, seed):
    cmd = [args.godot, "--headless", "--fixed-fps", str(args.sim_hz), "--path", ".", "--", "--match", "--elimination",
           "--control", f"--arena={args.arena}", f"--seed={seed}", f"--time-limit={args.time}", f"--budget={args.budget}",
           f"--green-faction={args.green}", f"--rust-faction={args.rust}", f"--green-brain={arm}", f"--rust-brain={arm}",
           "--brains-census"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
    line = next((l for l in proc.stdout.splitlines() if l.startswith("MATCH_RESULT ")), None)
    if line is None:
        return {"arm": arm, "seed": seed, "error": f"no MATCH_RESULT (exit {proc.returncode})",
                "tail": proc.stdout[-800:] + proc.stderr[-800:]}
    result = json.loads(line[len("MATCH_RESULT "):])
    for field in ("real_seconds", "speedup"):
        result.pop(field, None)
    lod = LOD_RE.search(proc.stdout)
    census = {}
    if lod:
        census = {"ticks": json.loads(lod.group(1)), "thinks": json.loads(lod.group(2)),
                  "first_fight_s": round(int(lod.group(3)) / float(args.sim_hz), 2) if int(lod.group(3)) >= 0 else -1.0}
    return {"arm": arm, "seed": seed, "result": result, "census": census}


def pair_sum(value):
    return sum(value) if isinstance(value, list) else value


def summarise(rows, sim_hz):
    fields = {
        "first_fight_s": lambda r: r["census"].get("first_fight_s", -1.0),
        "first_shot_s": lambda r: r["result"]["stats"]["first_shot_seconds"] if "stats" in r["result"] else r["result"].get("first_shot_seconds", -1.0),
        "first_kill_s": lambda r: r["result"]["stats"]["first_kill_seconds"] if "stats" in r["result"] else r["result"].get("first_kill_seconds", -1.0),
        "kills": lambda r: pair_sum(r["result"]["stats"]["kills"]) if "stats" in r["result"] else pair_sum(r["result"].get("kills", 0)),
        "shots": lambda r: pair_sum(r["result"]["stats"]["shots"]) if "stats" in r["result"] else pair_sum(r["result"].get("shots", 0)),
        "hits": lambda r: pair_sum(r["result"]["stats"]["hits"]) if "stats" in r["result"] else pair_sum(r["result"].get("hits", 0)),
    }
    out = {}
    for name, get in fields.items():
        values = []
        for r in rows:
            try:
                values.append(float(get(r)))
            except (KeyError, TypeError):
                pass
        present = [v for v in values if v >= 0]
        out[name] = {"median": round(statistics.median(present), 2) if present else None,
                     "mean": round(statistics.mean(present), 2) if present else None,
                     "n": len(present), "missing": len(values) - len(present), "values": values}
    thinks, ticks = {}, {}
    for r in rows:
        for k, v in r["census"].get("thinks", {}).items():
            thinks[k] = thinks.get(k, 0) + v
        for k, v in r["census"].get("ticks", {}).items():
            ticks[k] = ticks.get(k, 0) + v
    out["thinks"] = thinks
    out["unit_ticks"] = ticks
    out["thinks_total"] = sum(thinks.values())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--sim-hz", default=30, type=int)
    ap.add_argument("--arms", default="x5p,l17i1")
    ap.add_argument("--seeds", default="1701-1716")
    ap.add_argument("--arena", default="sumps")
    ap.add_argument("--time", default=120)
    ap.add_argument("--budget", default=4600)
    ap.add_argument("--green", default="law")
    ap.add_argument("--rust", default="condemned")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--control", action="store_true", help="run the first arm twice; the two must be identical")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    arms = args.arms.split(",")
    seeds = seeds_of(args.seeds)
    runs = [(a, s) for a in arms for s in seeds]
    if args.control:
        runs += [(arms[0] + "#control", s) for s in seeds]
    print(f">> ai-lever-behaviour: arms={args.arms} seeds={args.seeds} arena={args.arena} time={args.time} "
          f"budget={args.budget} {args.green} v {args.rust}, {len(runs)} matches", flush=True)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(lambda r: run_one(args, r[0].split("#")[0], r[1]) | {"label": r[0]}, runs))
    errors = [r for r in rows if "error" in r]
    for r in errors:
        print(f"ai-lever-behaviour: {r['label']} seed {r['seed']}: {r['error']}\n{r.get('tail', '')}", file=sys.stderr)
    good = [r for r in rows if "error" not in r]
    report = {"arms": {}, "seeds": seeds, "arena": args.arena, "time": args.time, "budget": args.budget}
    for label in dict.fromkeys(r["label"] for r in rows):
        mine = [r for r in good if r["label"] == label]
        digest = hashlib.md5("\n".join(json.dumps(r["result"], sort_keys=True) for r in sorted(mine, key=lambda r: r["seed"])).encode()).hexdigest()
        report["arms"][label] = summarise(mine, args.sim_hz) | {"digest": digest, "matches": len(mine)}
    with open(args.out, "w") as f:
        json.dump({"report": report, "runs": rows}, f, indent=1, sort_keys=True)
    for label, s in report["arms"].items():
        def m(k):
            return f"{s[k]['median']}/{s[k]['mean']}" + (f" ({s[k]['missing']} none)" if s[k]["missing"] else "")
        print(f"AI_LEVER_BEHAVIOUR {label}: first fight-rate s {m('first_fight_s')}; first shot s {m('first_shot_s')}; "
              f"first kill s {m('first_kill_s')}; kills {m('kills')}; shots {m('shots')}; hits {m('hits')}; "
              f"thinks {s['thinks_total']}; digest {s['digest']} ({s['matches']} matches; median/mean)")
    if args.control:
        a, b = report["arms"][arms[0]]["digest"], report["arms"][arms[0] + "#control"]["digest"]
        print(f"AI_LEVER_CONTROL {arms[0]} twice: {'IDENTICAL' if a == b else 'DIFFERENT'} ({a} / {b})")
        if a != b:
            return 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
