#!/usr/bin/env python3
"""Round 25 pace: the first BRIDGE_TRACK line two traces disagree on, and which fields differ (tests/pace/... pace-div)."""
import json
import sys


def rows(path):
    out = []
    for line in open(path, errors="replace"):
        if line.startswith("BRIDGE_TRACK "):
            out.append(json.loads(line[len("BRIDGE_TRACK "):]))
        elif line.startswith("BRIDGE_PROBE "):
            out.append({"PROBE": line[len("BRIDGE_PROBE "):].strip()[:300]})
    return out


def main(a_path, b_path):
    a, b = rows(a_path), rows(b_path)
    print(f"a: {len(a)} lines, b: {len(b)} lines")
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            keys = sorted(k for k in set(x) | set(y) if x.get(k) != y.get(k))
            print(f"first difference at line {i}: t={x.get('t')} unit={x.get('n')}")
            for k in keys:
                print(f"  {k}: a={json.dumps(x.get(k))[:200]}\n  {' ' * len(k)}  b={json.dumps(y.get(k))[:200]}")
            if i > 0:
                print(f"previous line (equal): t={a[i - 1].get('t')} unit={a[i - 1].get('n')}")
            return 0
    print("identical" if len(a) == len(b) else "equal prefix, different lengths")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
