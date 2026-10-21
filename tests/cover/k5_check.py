#!/usr/bin/env python3
"""K5 (cover, round 37): check a prepared plan of `tools/make_arenas.py` (COVER_K5) without touching arenas/.

    python3 tests/cover/k5_check.py PLAN OUT_DIR      (PLAN: none | a | b)

Copies arenas/ to OUT_DIR, regenerates there with COVER_K5=PLAN, and checks against arenas/:
- none: every file byte-identical (the prepared code is inert);
- a / b: only the plan's maps (and their dry twins) change, only in `props`, and only barricades come in (a swap takes
  out exactly the named wreck / container and its mirror); every added run, grown by add_runs_proposal.CLEAR_M, touches
  nothing that collides and no terrain (a swap's barricade sits where the clutter stood); every lane that passed R4
  before (tools/terrain_measure) still passes.
Prints one line per changed map; exit 1 on any failure.
"""
import ast, json, os, shutil, subprocess, sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import add_runs_proposal as runs  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def tables():
    """COVER_K5_SWAPS / _RUNS / _A_RUNS read from the generator's source (importing it would run it)."""
    out = {}
    for node in ast.parse((ROOT / "tools" / "make_arenas.py").read_text()).body:
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) \
                and node.targets[0].id in ("COVER_K5_SWAPS", "COVER_K5_RUNS", "COVER_K5_A_RUNS"):
            out[node.targets[0].id] = ast.literal_eval(node.value)
    return out


def key(p):
    return (p["type"], round(p["position"][0], 2), round(p["position"][1], 2))


def main():
    plan, out = sys.argv[1], Path(sys.argv[2])
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(ROOT / "arenas", out)
    env = dict(os.environ)
    env.pop("COVER_K5", None)
    if plan != "none":
        env["COVER_K5"] = plan
    subprocess.run([sys.executable, str(ROOT / "tools" / "make_arenas.py"), str(out)], cwd=ROOT, env=env, check=True,
                   stdout=subprocess.DEVNULL)
    t = tables()
    swaps = t["COVER_K5_SWAPS"] if plan == "a" else {}
    with_runs = set(t["COVER_K5_RUNS"]) if plan == "b" else (set(t["COVER_K5_A_RUNS"]) if plan == "a" else set())
    expected = set(swaps) | with_runs
    failures = []
    changed = []
    for path in sorted((ROOT / "arenas").glob("*.json")):
        before, after = path.read_bytes(), (out / path.name).read_bytes()
        if before == after:
            continue
        name = path.stem
        base = name[:-len("_dry")] if name.endswith("_dry") else name
        changed.append(name)
        if base not in expected:
            failures.append(f"{name}: changed but not in plan {plan}")
            continue
        a, b = json.loads(before), json.loads(after)
        if {k: v for k, v in a.items() if k != "props"} != {k: v for k, v in b.items() if k != "props"}:
            failures.append(f"{name}: something besides props changed")
        gone = Counter(map(key, a["props"])) - Counter(map(key, b["props"]))
        came = Counter(map(key, b["props"])) - Counter(map(key, a["props"]))
        want_gone = Counter()
        for kind, x, z in swaps.get(base, []):
            want_gone[(kind, float(x), float(z))] += 1
            want_gone[(kind, float(-x), float(-z))] += 1
        if gone != want_gone:
            failures.append(f"{name}: removed {dict(gone)}, expected {dict(want_gone)}")
        if any(k[0] != "barricade" for k in came):
            failures.append(f"{name}: added something other than barricades: {dict(came)}")
        n_runs = len(t["COVER_K5_RUNS"].get(base, [])) if base in with_runs else 0
        if sum(came.values()) != 2 * len(swaps.get(base, [])) + 4 * n_runs:
            failures.append(f"{name}: {sum(came.values())} barricades in, expected "
                            f"{2 * len(swaps.get(base, [])) + 4 * n_runs}")
        for x, z in (t["COVER_K5_RUNS"].get(base, []) if base in with_runs else []):
            for centre in ((x, z), (-x, -z)):
                if not runs.fits(a, centre, float(a.get("half_size", 120.0))):
                    failures.append(f"{name}: the run at {centre} does not clear {runs.CLEAR_M} m")
        lost = runs.lanes_ok(a) - runs.lanes_ok(b)
        if lost:
            failures.append(f"{name}: lanes no longer pass R4: {sorted(lost)}")
        print(f"k5 {plan}: {name}: -{sum(gone.values())} clutter, +{sum(came.values())} barricades")
    if plan != "none":
        for base in sorted(expected - {c[:-len('_dry')] if c.endswith('_dry') else c for c in changed}):
            failures.append(f"{base}: in plan {plan} but unchanged")
    for f in failures:
        print("FAIL " + f)
    print(f"k5 {plan}: {len(changed)} files changed, {len(failures)} failures")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
