#!/usr/bin/env python3
"""Image-to-3D for every concept the lead approved that has no model yet (assets X4), several at once.

    tools/assets/model_batch.py --list                      # what would be built, and the credits (no spend)
    tools/assets/model_batch.py --groups "Road gangs"       # ≈15 credits per model, logged in assets/meshy_ledger.md

Each model is one `generate.py --review-item <id> --smart-topology` process, so the lead gate and the one-model-per-
concept rule stay in generate.py (it refuses unapproved items and duplicates). The image sent is the background-
removed concept from assets/incoming/meshy/ when it's still there, else the committed review image (Meshy concept tasks
expire after ~3 days). Output: assets/incoming/meshy/<id>_t2.glb + maps, ready for a build recipe.
"""

import argparse
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review  # noqa: E402

HERE = Path(__file__).resolve().parent
POLYCOUNT = 15000


def pending(manifest: dict, group_prefix: str = "") -> list:
    return [i for i in manifest["items"] if i["status"] == "approved" and not i.get("model_task")
            and int(i.get("est_3d_credits", 15)) > 0 and i["group"].startswith(group_prefix)]  # mood pictures never go to 3D


def command(item: dict, root: Path = review.ROOT) -> list:
    raw = root / item.get("source_png", "")
    image = raw if item.get("source_png") and raw.exists() else root / item["image"]
    slot = "prop.crate" if item["target"].startswith("prop.") else "unit.tank"
    return [sys.executable, str(HERE / "generate.py"), "--provider", "meshy", "--slot", slot, "--review-item", item["id"],
            "--image", str(image), "--smart-topology", "--polycount", str(POLYCOUNT), "--name", f"meshy/{item['id']}_t2"]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--groups", default="", help="only groups whose name starts with this")
    parser.add_argument("--jobs", type=int, default=5)
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args(argv)
    todo = pending(review.load(), args.groups)
    credits = sum(int(i.get("est_3d_credits", 15)) for i in todo)
    for item in todo:
        print(f"{item['id']:<22} {item['group']:<26} {item['target']}")
    print(f"model batch: {len(todo)} model(s), ≈{credits} credits")
    if args.list or not todo:
        return 0

    def run(item: dict) -> int:
        result = subprocess.run(command(item), capture_output=True, text=True)
        for line in (result.stdout + result.stderr).splitlines():
            if "IN_PROGRESS" not in line and "PENDING" not in line:
                print(f"[{item['id']}] {line}", flush=True)
        return result.returncode

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        codes = list(pool.map(run, todo))
    failed = [i["id"] for i, code in zip(todo, codes) if code != 0]
    print(f"model batch: built {len(todo) - len(failed)}; failed: {', '.join(failed) or 'none'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
