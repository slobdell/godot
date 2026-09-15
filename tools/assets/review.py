#!/usr/bin/env python3
"""The lead's concept review gate and the Meshy spend ledger (_agents/workstreams.md "Lead gates").

Every new generated model starts as a cheap concept image. Concepts wait in a review manifest until the lead
approves one in their own words; only approved concepts may go to image-to-3D (tools/assets/generate.py
enforces it), and each concept goes to 3D at most once.

    make art-concept NAME=scout_a GROUP="X4 roster" TARGET=unit.scout TITLE="…" PROMPT="…"   (≈9 credits)
    make art-review                                   # build/review/index.html + images, for the lead
    make art-review-status                            # the table in the terminal
    make art-decide ID=scout_a DECISION=approved WORDS="the lead's words"
    make art-review-page / art-apply-decisions      # the tap-to-approve page (tools/assets/review_page.py)

The whole process: _agents/streams/references/concept_review.md

Files:
    assets/review/review.json     the manifest (committed): items, prompts, task ids, decisions
    assets/review/images/<id>.jpg the concept as the lead saw it (committed; 1024 px)
    assets/meshy_ledger.md        every Meshy request with its credits (committed; appended by generate.py)

Standard library, plus Pillow for thumbnails when installed (otherwise the PNG is copied as is).
"""

import argparse
import html
import json
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "assets" / "review" / "review.json"
LEDGER = ROOT / "assets" / "meshy_ledger.md"
STATUSES = ("waiting", "approved", "rejected", "superseded")
THUMB_PX = 1024

# Meshy API prices (docs.meshy.ai/en/api/pricing, asset_services.md), for estimates before a task reports its own.
PRICES = {
    "text-to-image": 9, "image-to-image": 9,
    "image-to-3d smart-topology": 15, "image-to-3d": 30, "multi-image-to-3d": 30,
    "text-to-3d preview": 20, "text-to-3d refine": 10, "retexture": 10, "remesh": 5,
}

LEDGER_HEADER = """# Meshy spend ledger

> Every Meshy API request the art stream makes, appended by `tools/assets/generate.py` (credits as the task
> reported them in `consumed_credits`; failed tasks cost 0). Round 1's 110 credits are summarized in
> `_agents/streams/references/asset_prompts.md`. The lead (2026-09-15): no cap, *"just don't be wasteful."*

| date (UTC) | request | task id | credits | for | result | balance after |
|---|---|---|---:|---|---|---:|
"""


class ReviewError(Exception):
    pass


# ---- manifest -------------------------------------------------------------------------------------------------

def load(path: Path = REVIEW) -> dict:
    if not path.exists():
        return {"schema": 1, "items": []}
    return json.loads(path.read_text())


def save(manifest: dict, path: Path = REVIEW) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    gdignore = path.parent / ".gdignore"
    if not gdignore.exists():  # Godot must not import (and export) review images
        gdignore.write_text("")
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


def locked_update(path: Path, change) -> dict:
    """Load, change, and save the manifest under an exclusive lock (parallel 3D requests record their tasks)."""
    import fcntl
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path.with_suffix(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        manifest = load(path)
        change(manifest)
        save(manifest, path)
        return manifest


def find(manifest: dict, item_id: str) -> dict:
    for item in manifest["items"]:
        if item["id"] == item_id:
            return item
    raise ReviewError(f"no review item {item_id!r} (make art-review-status)")


def thumbnail(source: Path, dest: Path) -> Path:
    """A 1024 px JPEG of the concept (or a plain copy if Pillow is missing or can't read it). Returns the file."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image
        with Image.open(source) as image:
            image = image.convert("RGBA")
            image.thumbnail((THUMB_PX, THUMB_PX))
            # Concepts come back background-removed; flatten onto the studio grey they were prompted with.
            flat = Image.new("RGB", image.size, (46, 46, 50))
            flat.paste(image, mask=image.split()[3])
            flat.save(dest, "JPEG", quality=88)
        return dest
    except (ImportError, OSError):
        copy = dest.with_suffix(source.suffix)
        shutil.copyfile(source, copy)
        return copy


def add(manifest: dict, item_id: str, concept_json: Path, group: str, target: str, title: str,
        est_3d: int, mode_3d: str, notes: str = "", image_dir: Path = None, view: int = 0) -> dict:
    """Registers a finished concept (generate.py --concept-only wrote <name>.concept.json + .png) for review."""
    if any(item["id"] == item_id for item in manifest["items"]):
        raise ReviewError(f"review item {item_id!r} already exists; pick a new id for a new concept")
    sidecar = json.loads(concept_json.read_text())
    task = sidecar["task"]
    png = concept_json.with_name(concept_json.name.replace(".concept.json", ".concept%s.png" % (view or "")))
    if not png.exists():
        raise ReviewError(f"{png} is missing")
    image_dir = image_dir or REVIEW.parent / "images"
    image = thumbnail(png, image_dir / f"{item_id}.jpg")
    item = {
        "id": item_id, "group": group, "target": target, "title": title, "prompt": sidecar.get("prompt", ""),
        "concept_task": task["id"], "concept_type": task.get("type", ""), "concept_credits": task.get("consumed_credits", 0),
        "references": sidecar.get("references", []), "source_png": _rel(png), "image": _rel(image),
        "est_3d_credits": est_3d, "mode_3d": mode_3d, "notes": notes,
        "status": "waiting", "lead_words": "", "decided": "", "model_task": "", "added": _today(),
    }
    manifest["items"].append(item)
    return item


def decide(manifest: dict, item_id: str, decision: str, words: str) -> dict:
    if decision not in STATUSES:
        raise ReviewError(f"decision must be one of {', '.join(STATUSES)}")
    if decision == "approved" and not words.strip():
        raise ReviewError("an approval must quote the lead's words (WORDS=…)")
    item = find(manifest, item_id)
    item.update(status=decision, lead_words=words, decided=_today())
    return item


def gate_3d(manifest: dict, item_id: str, retry_reason: str = "") -> dict:
    """The item a 3D request may be built from, or an error saying why not (unapproved, or a duplicate)."""
    item = find(manifest, item_id)
    if item["status"] != "approved":
        raise ReviewError(f"review item {item_id!r} is {item['status']}: only concepts the lead approved go to 3D "
                          f"(make art-review, then make art-decide once the lead answers)")
    if item.get("model_task") and not retry_reason:
        raise ReviewError(f"review item {item_id!r} already went to 3D (task {item['model_task']}); a duplicate "
                          f"request wastes credits. If that task failed or must be redone, pass --retry-reason")
    return item


def record_model_task(manifest: dict, item_id: str, task_id: str) -> None:
    item = find(manifest, item_id)
    previous = item.get("model_task")
    if previous:
        item.setdefault("previous_model_tasks", []).append(previous)
    item["model_task"] = task_id


# ---- ledger ---------------------------------------------------------------------------------------------------

def ledger_append(request: str, task: dict, purpose: str, balance="", path: Path = LEDGER) -> None:
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(LEDGER_HEADER)
    credits = task.get("consumed_credits", task.get("credits_consumed", 0)) or 0
    row = "| %s | %s | `%s` | %s | %s | %s | %s |\n" % (
        time.strftime("%Y-%m-%d %H:%M", time.gmtime()), request, task.get("id", "?"), credits,
        purpose.replace("|", "/"), task.get("status", "?"), balance)
    with path.open("a") as ledger:
        ledger.write(row)


def ledger_total(path: Path = LEDGER) -> int:
    if not path.exists():
        return 0
    total = 0
    for line in path.read_text().splitlines():
        cells = [c.strip() for c in line.split("|")]
        if len(cells) > 5 and cells[3].startswith("`"):
            try:
                total += int(cells[4])
            except ValueError:
                pass
    return total


# ---- the sheet ------------------------------------------------------------------------------------------------

def build(manifest: dict, out_dir: Path, ledger: Path = LEDGER) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "images").mkdir(exist_ok=True)
    items = manifest["items"]
    waiting = [i for i in items if i["status"] == "waiting"]
    groups = []
    for item in items:
        if item["group"] not in groups:
            groups.append(item["group"])
    cards = []
    for group in groups:
        members = [i for i in items if i["group"] == group]
        members.sort(key=lambda i: STATUSES.index(i["status"]))
        cards.append(f'<h2>{html.escape(group)}</h2><div class="grid">')
        for item in members:
            src = ROOT / item["image"]
            if src.exists():
                shutil.copyfile(src, out_dir / "images" / src.name)
            words = f'<p class="words">“{html.escape(item["lead_words"])}” <span>{item["decided"]}</span></p>' \
                if item["lead_words"] else ""
            refs = f'<p class="meta">references: {html.escape(", ".join(item["references"]))}</p>' if item["references"] else ""
            notes = f'<p class="notes">{html.escape(item["notes"])}</p>' if item.get("notes") else ""
            cards.append(f"""
<article class="card {item['status']}">
  <a href="images/{src.name}"><img src="images/{src.name}" alt="{html.escape(item['title'])}" loading="lazy"></a>
  <div class="body">
    <div class="head"><code class="id">{html.escape(item['id'])}</code><span class="badge">{item['status']}</span></div>
    <h3>{html.escape(item['title'])}</h3>
    <p class="meta">slot <code>{html.escape(item['target'])}</code> · 3D ≈ <b>{item['est_3d_credits']}</b> credits
      ({html.escape(item['mode_3d'])}) · concept {item['concept_credits']} credits</p>
    {notes}{words}{refs}
    <details><summary>prompt</summary><p class="prompt">{html.escape(item['prompt'])}</p>
      <p class="meta">concept task <code>{item['concept_task']}</code></p></details>
  </div>
</article>""")
        cards.append("</div>")
    est = sum(i["est_3d_credits"] for i in waiting)
    page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tank Squad concept review</title>
<style>
:root {{ --bg:#0b0b12; --panel:#15151f; --text:#e6e6ea; --dim:#9a9aa8; --cyan:#00e5f0; --mag:#ff2da0; --amber:#ffc23a; --red:#ff5a5a; }}
* {{ box-sizing: border-box; }}
body {{ margin:0; padding:24px 16px 64px; background:var(--bg); color:var(--text); font:15px/1.45 system-ui, sans-serif; }}
main {{ max-width:1280px; margin:0 auto; }}
h1 {{ margin:0 0 4px; font-size:24px; }} h2 {{ margin:36px 0 12px; font-size:18px; color:var(--cyan); }}
.lede {{ color:var(--dim); max-width:72ch; }}
.how {{ background:var(--panel); border-left:3px solid var(--amber); padding:12px 16px; margin:16px 0; max-width:80ch; }}
.stats {{ display:flex; gap:24px; flex-wrap:wrap; margin:12px 0; }} .stats b {{ font-size:22px; display:block; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap:16px; }}
.card {{ background:var(--panel); border-radius:6px; overflow:hidden; border:1px solid #262633; }}
.card img {{ width:100%; aspect-ratio:1; object-fit:cover; display:block; background:#2e2e32; }}
.card .body {{ padding:12px 14px 14px; }}
.head {{ display:flex; justify-content:space-between; align-items:center; }}
.id {{ color:var(--cyan); font-size:14px; }} h3 {{ margin:6px 0; font-size:16px; }}
.badge {{ font-size:12px; text-transform:uppercase; letter-spacing:.06em; padding:2px 8px; border-radius:3px; background:#333; }}
.waiting .badge {{ background:var(--amber); color:#000; }} .approved .badge {{ background:var(--cyan); color:#000; }}
.rejected .badge {{ background:var(--red); color:#000; }} .superseded {{ opacity:.55; }}
.meta {{ color:var(--dim); font-size:13px; margin:4px 0; }} .notes {{ margin:6px 0; }}
.words {{ border-left:2px solid var(--mag); padding-left:8px; font-style:italic; }} .words span {{ color:var(--dim); font-style:normal; font-size:12px; }}
.prompt {{ font-size:13px; color:#c8c8d0; }} code {{ font-size:12px; }}
</style></head><body><main>
<h1>Tank Squad: concept review</h1>
<p class="lede">Concept images for new Meshy models. Nothing here has been turned into 3D: each concept waits for the
lead's approval first (<code>_agents/workstreams.md</code>, Lead gates). Built {time.strftime('%Y-%m-%d %H:%M')}.</p>
<div class="stats"><div><b>{len(waiting)}</b>waiting</div>
<div><b>{sum(1 for i in items if i['status'] == 'approved')}</b>approved</div>
<div><b>≈{est}</b>credits to build every waiting concept in 3D</div>
<div><b>{ledger_total(ledger)}</b>credits spent this round (ledger)</div></div>
<div class="how"><b>How to answer:</b> reply with ids and a few words, e.g. <i>“approve scout_b and ifv_a; reject lancer_a,
too clean; artillery: try a cement mixer”</i>. Approve at most one concept per unit or prop; I build only those,
and write your words into the brief.</div>
{''.join(cards)}
</main></body></html>
"""
    index = out_dir / "index.html"
    index.write_text(page)
    return index


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def _today() -> str:
    return time.strftime("%Y-%m-%d")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", default=str(REVIEW))
    parser.add_argument("--ledger", default=str(LEDGER))
    sub = parser.add_subparsers(dest="command", required=True)
    p_add = sub.add_parser("add", help="register a finished concept for review")
    p_add.add_argument("--id", required=True)
    p_add.add_argument("--concept", required=True, help="the <name>.concept.json generate.py wrote")
    p_add.add_argument("--view", type=int, default=0, help="which view of a multi-view concept to show")
    p_add.add_argument("--group", required=True)
    p_add.add_argument("--target", required=True, help="the slot(s) it fills, e.g. unit.scout")
    p_add.add_argument("--title", required=True)
    p_add.add_argument("--est-3d", type=int, default=PRICES["image-to-3d smart-topology"])
    p_add.add_argument("--mode-3d", default="image-to-3D meshy-t2 smart topology, PBR")
    p_add.add_argument("--notes", default="")
    p_decide = sub.add_parser("decide", help="record the lead's decision")
    p_decide.add_argument("id")
    p_decide.add_argument("decision", choices=STATUSES)
    p_decide.add_argument("--words", default="")
    p_build = sub.add_parser("build", help="write the HTML review sheet")
    p_build.add_argument("--out", default=str(ROOT / "build" / "review"))
    sub.add_parser("status", help="print the items")
    args = parser.parse_args(argv)
    manifest_path = Path(args.manifest)
    try:
        manifest = load(manifest_path)
        if args.command == "add":
            item = add(manifest, args.id, Path(args.concept), args.group, args.target, args.title, args.est_3d,
                       args.mode_3d, args.notes, manifest_path.parent / "images", args.view)
            save(manifest, manifest_path)
            print(f"added {item['id']} (waiting): {item['image']}")
        elif args.command == "decide":
            item = decide(manifest, args.id, args.decision, args.words)
            save(manifest, manifest_path)
            print(f"{item['id']}: {item['status']}")
        elif args.command == "build":
            index = build(manifest, Path(args.out), Path(args.ledger))
            print(f"review sheet: {index}")
        else:
            for item in manifest["items"]:
                print(f"{item['status']:<10} {item['id']:<18} {item['target']:<22} {item['title']}"
                      + (f"  → 3D {item['model_task']}" if item.get("model_task") else ""))
            print(f"ledger total: {ledger_total(Path(args.ledger))} credits")
    except (ReviewError, OSError, KeyError, json.JSONDecodeError) as error:
        print(f"review: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
