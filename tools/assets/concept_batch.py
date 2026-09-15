#!/usr/bin/env python3
"""A batch of concept images from one committed spec: generated in parallel, then registered for the lead's review.

    tools/assets/concept_batch.py assets/review/batches/round3_factions.json --list          # prompts, no spend
    tools/assets/concept_batch.py assets/review/batches/round3_factions.json --only gangs     # ≈9 credits per concept
    make art-review-page TITLE="Road gangs" GROUPS="Road gangs"                               # one page per faction

The spec is the record of what was asked for (assets stream, round 3; process in
_agents/streams/references/concept_review.md). Each faction has a lead sentence with a {role} placeholder, a look
paragraph (the wear spectrum in _agents/game_design.md), role names, optional role notes (shown under each group on
the review page), and concepts {id, role, title, subject, notes, tail?,
supersedes?, why?} (a regenerated concept marks the failed one superseded, so the lead never sees it). A prompt is
    lead(role) + subject + look + tail
so every option of a faction shares its materials and every prompt ends with the no-text studio tail.

Idempotent: a concept already in the review manifest is skipped; one whose image is already downloaded is registered
without being generated again. Each generation is one `generate.py --concept-only` process (Meshy allows 10
concurrent tasks); registration is sequential because the manifest isn't safe for parallel writers.
"""

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review  # noqa: E402

HERE = Path(__file__).resolve().parent
INCOMING = review.ROOT / "assets" / "incoming"
MODE_3D = "image-to-3D meshy-t2 smart topology, PBR"


class BatchError(Exception):
    pass


def expand(spec: dict) -> list:
    """Every concept of the spec with its prompt, group, target slot, and title, in spec order."""
    concepts, seen = [], set()
    for faction_id, faction in spec["factions"].items():
        letters = {}
        for concept in faction["concepts"]:
            if concept["id"] in seen:
                raise BatchError(f"concept id {concept['id']!r} appears twice")
            seen.add(concept["id"])
            role = concept["role"]
            if role not in faction["roles"]:
                raise BatchError(f"{concept['id']}: faction {faction_id} has no role {role!r}")
            letter = chr(ord("A") + letters.get(role, 0))
            letters[role] = letters.get(role, 0) + 1
            parts = [faction["lead"].format(role=faction["roles"][role]), concept["subject"], faction.get("look", ""),
                     concept.get("tail", faction.get("tail", spec["tail"]))]
            concepts.append({
                "id": concept["id"], "faction": faction_id, "role": role,
                "group": f"{faction['label']} · {_role_label(role)}",
                "target": faction.get("target", "unit.{faction}.{role}").format(faction=faction_id, role=role),
                "title": f"{_role_label(role)} {letter}: {concept['title']}",
                "notes": concept.get("notes", ""),
                "est_3d": int(concept.get("est_3d", spec.get("est_3d", 15))),
                "keep_background": bool(concept.get("keep_background", False)),
                "prompt": " ".join(p.strip() for p in parts if p.strip()),
                "supersedes": concept.get("supersedes", ""), "why": concept.get("why", ""),
            })
    return concepts


def group_notes(spec: dict) -> dict:
    notes = {}
    for faction in spec["factions"].values():
        for role, note in faction.get("role_notes", {}).items():
            notes[f"{faction['label']} · {_role_label(role)}"] = note
    return notes


def _role_label(role: str) -> str:
    return {"ifv": "IFV"}.get(role, role.capitalize())


def meshy_generate(incoming: Path):
    """The real generator: one generate.py --concept-only process per concept (its output is prefixed by id)."""
    def run(concept: dict) -> int:
        cmd = [sys.executable, str(HERE / "generate.py"), "--provider", "meshy", "--slot", "unit.tank", "--concept-only",
               "--prompt", concept["prompt"], "--name", f"meshy/{concept['id']}", "--out-dir", str(incoming)]
        if concept["keep_background"]:
            cmd.append("--keep-background")
        result = subprocess.run(cmd, capture_output=True, text=True)
        for line in (result.stdout + result.stderr).splitlines():
            print(f"[{concept['id']}] {line}", flush=True)
        return result.returncode
    return run


def run(spec: dict, manifest_path: Path, incoming: Path = INCOMING, generate=None, jobs: int = 8, only=None) -> list:
    """Generates what's missing and registers it. Returns the ids registered by this run."""
    generate = generate or meshy_generate(incoming)
    concepts = [c for c in expand(spec) if not only or c["faction"] in only or c["id"] in only]
    manifest = review.load(manifest_path)
    known = {item["id"] for item in manifest["items"]}
    pending = [c for c in concepts if c["id"] not in known]
    sidecar = lambda c: incoming / "meshy" / f"{c['id']}.concept.json"  # noqa: E731
    to_generate = [c for c in pending if not sidecar(c).exists()]
    if to_generate:
        print(f"concept batch: generating {len(to_generate)} concept(s), {jobs} at a time", flush=True)
        with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
            codes = dict(zip([c["id"] for c in to_generate], pool.map(generate, to_generate)))
        for concept_id, code in codes.items():
            if code != 0:
                print(f"concept batch: {concept_id} failed (exit {code}); not registered", file=sys.stderr)
    registered = []
    manifest = review.load(manifest_path)
    notes = group_notes(spec)
    if notes:
        manifest.setdefault("group_notes", {}).update(notes)
    for concept in pending:
        if not sidecar(concept).exists():
            continue
        review.add(manifest, concept["id"], sidecar(concept), concept["group"], concept["target"], concept["title"],
                   concept["est_3d"], MODE_3D, concept["notes"], manifest_path.parent / "images")
        registered.append(concept["id"])
    for concept in concepts:
        old = next((i for i in manifest["items"] if i["id"] == concept["supersedes"]), None)
        if old is not None and old["status"] == "waiting" and concept["id"] in {i["id"] for i in manifest["items"]}:
            review.decide(manifest, old["id"], "superseded",
                          f"Regenerated as {concept['id']} before review ({concept['why'] or 'failed the pre-review look'}).")
    review.save(manifest, manifest_path)
    return registered


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("spec")
    parser.add_argument("--manifest", default=str(review.REVIEW))
    parser.add_argument("--only", action="append", default=[], help="a faction id or concept id (repeatable)")
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--list", action="store_true", help="print ids, groups and prompts; generate nothing")
    args = parser.parse_args(argv)
    spec = json.loads(Path(args.spec).read_text())
    try:
        if args.list:
            for c in expand(spec):
                if not args.only or c["faction"] in args.only or c["id"] in args.only:
                    print(f"{c['id']}  [{c['group']}]  {c['title']}\n    {c['prompt']}\n")
            return 0
        done = run(spec, Path(args.manifest), only=set(args.only), jobs=args.jobs)
    except (BatchError, review.ReviewError) as error:
        print(f"concept batch: {error}", file=sys.stderr)
        return 2
    print(f"concept batch: registered {len(done)}: {', '.join(done)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
