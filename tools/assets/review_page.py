#!/usr/bin/env python3
"""The lead's concept review page: pick-one-per-slot cards with Approve/Reject, saved as the lead taps.

The human gate before any Meshy 3D request (_agents/streams/references/concept_review.md has the whole process):

    make art-review-page TITLE="Concept review #2"      # build/review_page/index.html + images/ from review.json
    (Claude publishes it as a private Artifact with capabilities {"db": {}} and sends the lead the link)
    (after the lead taps: Claude saves the page's "decisions" collection with read_db out_dir=…)
    make art-apply-decisions DIR=<out_dir> URL=<artifact url>   # records every decision in assets/review/review.json

The page shows every WAITING item of assets/review/review.json (ALL=1: every item not superseded), grouped by the
item's "group" in manifest order, one card per option: the concept image (tap to enlarge), its notes (the tradeoff),
slot, 3D cost, the prompt, a "your words" box, and Approve / Reject. Each tap writes decisions/<item id> =
{decision, words, at} to the Artifact's database; opening the page again shows the saved state. Without the Artifact
runtime (a plain browser) it still renders, read-only, and asks for picks in chat.
Optional manifest key "group_notes": {group: one line shown under the group heading}.

Standard library only.
"""

import argparse
import html
import json
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review  # noqa: E402

OUT = review.ROOT / "build" / "review_page"


def select(manifest: dict, include_decided: bool = False) -> list:
    wanted = ("waiting", "approved", "rejected") if include_decided else ("waiting",)
    return [item for item in manifest["items"] if item["status"] in wanted]


def groups_in_order(items: list) -> list:
    order = []
    for item in items:
        if item["group"] not in order:
            order.append(item["group"])
    return order


def build(manifest: dict, out_dir: Path, title: str, include_decided: bool = False, ledger: Path = review.LEDGER) -> Path:
    items = select(manifest, include_decided)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "images").mkdir(exist_ok=True)
    notes = manifest.get("group_notes", {})
    sections = []
    for group in groups_in_order(items):
        members = [i for i in items if i["group"] == group]
        cards = []
        for item in members:
            source = review.ROOT / item["image"]
            if source.exists():
                shutil.copyfile(source, out_dir / "images" / source.name)
            img = "images/" + source.name
            mood = int(item.get("est_3d_credits", 0)) == 0
            cost = "mood picture · never sent to 3D" if mood else f"3D ≈ {item['est_3d_credits']} credits"
            short = item["title"].split(": ", 1)[-1]
            cards.append(f"""
      <article class="card" data-id="{html.escape(item['id'])}" data-state="waiting">
        <button class="shot" type="button" data-full="{img}" aria-label="Enlarge {html.escape(short)}">
          <img src="{img}" alt="{html.escape(item['title'])}" loading="lazy" width="1024" height="1024">
        </button>
        <div class="card-body">
          <div class="card-head"><code class="id">{html.escape(item['id'])}</code><span class="pill">waiting</span></div>
          <h3>{html.escape(short)}</h3>
          <p class="note">{html.escape(item.get('notes', ''))}</p>
          <dl class="facts">
            <div><dt>slot</dt><dd>{html.escape(item['target'])}</dd></div>
            <div><dt>cost</dt><dd>{cost}</dd></div>
          </dl>
          <details><summary>Prompt</summary><p class="prompt">{html.escape(item['prompt'])}</p></details>
          <label class="words-label" for="words-{html.escape(item['id'])}">Your words (optional)</label>
          <textarea id="words-{html.escape(item['id'])}" rows="2" placeholder="What you like, or what to change"></textarea>
          <div class="actions">
            <button type="button" class="act approve" data-decision="approved">{'Looks right' if mood else 'Approve for 3D'}</button>
            <button type="button" class="act reject" data-decision="rejected">{'Not this' if mood else 'Reject'}</button>
          </div>
          <p class="saved" aria-live="polite"></p>
        </div>
      </article>""")
        blurb = f"<p>{html.escape(notes[group])}</p>" if group in notes else "<p></p>"
        sections.append(f"""
    <section class="group">
      <header class="group-head">
        <h2>{html.escape(group)}</h2>
        {blurb}
        <span class="count">{len(members)} option{'s' if len(members) != 1 else ''}</span>
      </header>
      <div class="options">{''.join(cards)}
      </div>
    </section>""")
    models = [i for i in items if int(i.get("est_3d_credits", 0)) > 0]
    picks = len({i["group"] for i in models})
    spent = sum(int(i.get("concept_credits", 0)) for i in items)
    page = f"""<title>Tank Squad {html.escape(title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600;700&family=IBM+Plex+Sans:ital,wght@0,400;0,500;0,600;1,400&family=Share+Tech+Mono&display=swap">
__CSS__

<div class="stripe" aria-hidden="true"></div>
<div class="wrap">
  <header class="masthead">
    <div>
      <p class="eyebrow">Art stream · lead gate before any 3D</p>
      <h1>{html.escape(title)}</h1>
      <p class="lede">{len(items)} photoreal concepts for Meshy. <b>Nothing here has been built in 3D yet.</b> Approve at
        most one option per group and only those get built; a few words on what you like or want changed go straight
        into the brief.</p>
    </div>
    <div class="tally" aria-label="Decisions so far">
      <div class="w"><b id="n-waiting">{len(items)}</b><span>waiting</span></div>
      <div class="a"><b id="n-approved">0</b><span>approved</span></div>
      <div class="r"><b id="n-rejected">0</b><span>rejected</span></div>
    </div>
  </header>
  <div class="how">
    <span><strong>Tap a picture</strong> to see it full size.</span>
    <span><strong>≈15 credits</strong> per model (image-to-3D, textured): {len(models)} if every option went ahead, {picks} if one per group.</span>
    <span><strong>{spent}</strong> credits spent on these concepts ({review.ledger_total(ledger)} in the ledger so far).</span>
    <span class="status-line" id="status">Connecting to save your choices…</span>
  </div>
  {''.join(sections)}
  <footer>Built {time.strftime('%Y-%m-%d')} from <code>assets/review/review.json</code> by <code>tools/assets/review_page.py</code>.
    Prompts follow <code>_agents/art_direction.md</code>. Decisions are recorded with your words.</footer>
</div>

__SCRIPT__
"""
    page = page.replace("__CSS__", CSS).replace("__SCRIPT__", SCRIPT)
    index = out_dir / "index.html"
    index.write_text(page)
    return index


def read_decisions(folder: Path) -> dict:
    """{item id: {decision, words, at}} from read_db's out_dir (<dir>/decisions/<id>.json, or the files directly)."""
    if (folder / "decisions").is_dir():
        folder = folder / "decisions"
    found = {}
    for file in sorted(folder.glob("*.json")):
        body = json.loads(file.read_text())
        body = body.get("data", body) if isinstance(body.get("data"), dict) else body
        found[file.stem] = body
    return found


def apply(manifest: dict, decisions: dict, url: str) -> list:
    """Records each tapped decision on its review item. Returns [(id, status, words)] for the ones that changed."""
    changed = []
    for item_id, body in decisions.items():
        decision = body.get("decision", "")
        if decision not in ("approved", "rejected"):
            continue
        try:
            item = review.find(manifest, item_id)
        except review.ReviewError:
            print(f"review page: no review item {item_id!r}; skipped", file=sys.stderr)
            continue
        when = str(body.get("at", ""))[:16].replace("T", " ")
        said = str(body.get("words", "")).strip()
        where = f"the review page {url}" if url else "the review page"
        verb = "Approve" if decision == "approved" else "Reject"
        words = (f"“{said}” ({verb} on {where}, {when} UTC)" if said
                 else f"{'Approved' if decision == 'approved' else 'Rejected'} on {where} (tapped {verb}, no comment), {when} UTC")
        if item["status"] == decision and item.get("lead_words") == words:
            continue
        if item.get("model_task") and decision == "rejected":
            print(f"review page: {item_id} already went to 3D (task {item['model_task']}); recording the rejection anyway",
                  file=sys.stderr)
        review.decide(manifest, item_id, decision, words)
        changed.append((item_id, decision, words))
    return changed


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", default=str(review.REVIEW))
    sub = parser.add_subparsers(dest="command", required=True)
    p_build = sub.add_parser("build", help="write the review page")
    p_build.add_argument("--title", default="Concept review")
    p_build.add_argument("--all", action="store_true", help="also show decided items (not superseded)")
    p_build.add_argument("--out", default=str(OUT))
    p_apply = sub.add_parser("apply", help="record the decisions the lead tapped (read_db out_dir)")
    p_apply.add_argument("--decisions", required=True, help="the folder read_db saved the decisions collection into")
    p_apply.add_argument("--url", default="", help="the review page's Artifact URL (quoted in the recorded words)")
    args = parser.parse_args(argv)
    path = Path(args.manifest)
    manifest = review.load(path)
    if args.command == "build":
        index = build(manifest, Path(args.out), args.title, args.all)
        shown = len(select(manifest, args.all))
        print(f"review page: {index} ({shown} concepts)")
        if shown == 0:
            print("review page: nothing is waiting for review (make art-concept first, or ALL=1)", file=sys.stderr)
            return 1
        return 0
    changed = apply(manifest, read_decisions(Path(args.decisions)), args.url)
    review.save(manifest, path)
    for item_id, decision, words in changed:
        print(f"{decision:<9} {item_id:<18} {words}")
    print(f"review page: {len(changed)} decision(s) recorded in {path}")
    return 0


CSS = r"""<style>
:root {
  --ground: #0e0f14; --panel: #171922; --panel-2: #1e212c; --line: #2a2d38;
  --text: #e4e2da; --dim: #8e909c; --hazard: #f2b01e; --cyan: #19d3da; --magenta: #ff3d8b;
  --display: "Chakra Petch", "Arial Narrow", system-ui, sans-serif;
  --body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: "Share Tech Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
  color-scheme: dark;
}
* { box-sizing: border-box; }
html, body { background: var(--ground); color: var(--text); }
body { margin: 0; font: 15px/1.55 var(--body); padding-inline: 16px; padding-block: 0 72px; }
.wrap { max-width: 1240px; margin: 0 auto; }
.stripe { height: 10px; margin-inline: -16px; background: repeating-linear-gradient(-45deg, var(--hazard) 0 14px, #121217 14px 28px); opacity: .9; }
.masthead { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 24px 40px; align-items: end; padding-block: 28px 20px; border-bottom: 1px solid var(--line); }
.eyebrow { font: 600 12px/1 var(--display); letter-spacing: .16em; text-transform: uppercase; color: var(--hazard); margin: 0 0 10px; }
h1 { font: 700 clamp(28px, 5vw, 44px)/1.05 var(--display); margin: 0 0 12px; text-wrap: balance; letter-spacing: .01em; }
.lede { margin: 0; max-width: 64ch; color: var(--dim); }
.lede b { color: var(--text); font-weight: 500; }
.tally { display: grid; grid-template-columns: repeat(3, auto); gap: 4px 28px; font-variant-numeric: tabular-nums; }
.tally div { display: flex; flex-direction: column; }
.tally b { font: 600 30px/1 var(--mono); }
.tally span { font-size: 12px; color: var(--dim); letter-spacing: .06em; text-transform: uppercase; margin-top: 6px; }
.tally .w b { color: var(--hazard); } .tally .a b { color: var(--cyan); } .tally .r b { color: var(--magenta); }
.how { display: flex; flex-wrap: wrap; gap: 8px 28px; padding-block: 14px; color: var(--dim); font-size: 14px; border-bottom: 1px solid var(--line); }
.how strong { color: var(--text); font-weight: 500; }
.status-line { font: 13px var(--mono); color: var(--dim); }
.status-line.live { color: var(--cyan); }
.group { padding-block: 36px 8px; }
.group-head { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 4px 18px; align-items: baseline; margin-bottom: 16px; }
.group-head h2 { font: 600 22px/1.1 var(--display); margin: 0; text-transform: uppercase; letter-spacing: .06em; }
.group-head p { margin: 0; color: var(--dim); max-width: 70ch; }
.count { font: 13px var(--mono); color: var(--dim); }
.options { display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr)); }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 4px; display: flex; flex-direction: column; overflow: hidden; transition: border-color .2s; }
.card[data-state="approved"] { border-color: var(--cyan); box-shadow: 0 0 0 1px var(--cyan) inset; }
.card[data-state="rejected"] { border-color: #4a2334; }
.card[data-state="rejected"] .shot img { filter: saturate(.35) brightness(.7); }
.shot { all: unset; display: block; cursor: zoom-in; background: #2e2e32; }
.shot img { display: block; width: 100%; height: auto; aspect-ratio: 1; object-fit: cover; max-width: 100%; }
.shot:focus-visible { outline: 2px solid var(--hazard); outline-offset: -2px; }
.card-body { padding: 14px 16px 16px; display: flex; flex-direction: column; gap: 8px; flex: 1; }
.card-head { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.id { font: 14px var(--mono); color: var(--hazard); }
.pill { font: 600 11px/1 var(--display); letter-spacing: .1em; text-transform: uppercase; padding: 5px 8px 4px; border-radius: 2px; background: var(--panel-2); color: var(--dim); border: 1px solid var(--line); }
.card[data-state="waiting"] .pill { color: var(--hazard); border-color: #5a4614; }
.card[data-state="approved"] .pill { background: var(--cyan); color: #051416; border-color: var(--cyan); }
.card[data-state="rejected"] .pill { background: var(--magenta); color: #1a0510; border-color: var(--magenta); }
h3 { font: 600 17px/1.25 var(--display); margin: 0; text-wrap: balance; }
.note { margin: 0; color: #c3c2bb; font-size: 14px; }
.facts { margin: 0; display: grid; gap: 2px; font-size: 13px; }
.facts div { display: grid; grid-template-columns: 40px minmax(0, 1fr); gap: 8px; }
.facts dt { color: var(--dim); font: 12px var(--mono); padding-top: 1px; }
.facts dd { margin: 0; font: 13px var(--mono); color: var(--text); overflow-wrap: anywhere; }
details { font-size: 13px; }
summary { cursor: pointer; color: var(--dim); font: 12px var(--mono); letter-spacing: .04em; }
summary:focus-visible { outline: 2px solid var(--hazard); }
.prompt { color: #b9b8b1; margin: 8px 0 0; }
.words-label { font: 12px var(--mono); color: var(--dim); margin-top: auto; padding-top: 6px; }
textarea { width: 100%; resize: vertical; background: var(--ground); color: var(--text); border: 1px solid var(--line); border-radius: 3px; padding: 8px 10px; font: 14px/1.4 var(--body); }
textarea:focus-visible { outline: 2px solid var(--hazard); outline-offset: 1px; border-color: transparent; }
.actions { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.act { font: 600 14px/1 var(--display); letter-spacing: .04em; text-transform: uppercase; padding: 13px 10px 12px; min-height: 44px; border-radius: 3px; cursor: pointer; background: transparent; color: var(--text); border: 1px solid var(--line); }
.act.approve:hover, .card[data-state="approved"] .act.approve { border-color: var(--cyan); color: var(--cyan); }
.act.reject:hover, .card[data-state="rejected"] .act.reject { border-color: var(--magenta); color: var(--magenta); }
.act:focus-visible { outline: 2px solid var(--hazard); outline-offset: 2px; }
.act:disabled { opacity: .45; cursor: not-allowed; }
.saved { margin: 0; min-height: 1.2em; font: 12px var(--mono); color: var(--dim); }
.saved.err { color: var(--magenta); }
.lightbox { position: fixed; inset: 0; background: rgba(6,7,10,.94); display: grid; place-items: center; padding: 16px; z-index: 10; cursor: zoom-out; }
.lightbox img { max-width: 100%; max-height: 100%; object-fit: contain; }
footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--line); color: var(--dim); font-size: 13px; }
@media (max-width: 720px) {
  .masthead { grid-template-columns: 1fr; }
  .group-head { grid-template-columns: 1fr auto; }
  .group-head p { grid-column: 1 / -1; grid-row: 2; }
}
@media (prefers-reduced-motion: reduce) { .card { transition: none; } }
</style>"""

SCRIPT = r"""<script>
(() => {
  const cards = [...document.querySelectorAll(".card")];
  const statusEl = document.getElementById("status");
  let db = null;

  function paint(card, decision, words, at) {
    const state = decision || "waiting";
    card.dataset.state = state;
    card.querySelector(".pill").textContent = state;
    const area = card.querySelector("textarea");
    if (typeof words === "string" && document.activeElement !== area) area.value = words;
    if (at) card.querySelector(".saved").textContent = "Saved " + new Date(at).toLocaleString();
    tally();
  }

  function tally() {
    const count = s => cards.filter(c => c.dataset.state === s).length;
    document.getElementById("n-waiting").textContent = count("waiting");
    document.getElementById("n-approved").textContent = count("approved");
    document.getElementById("n-rejected").textContent = count("rejected");
  }

  async function decide(card, decision) {
    const note = card.querySelector(".saved");
    if (!db) {
      note.classList.add("err");
      note.textContent = "Saving isn't available in this view. Reply in chat with the id instead.";
      return;
    }
    const words = card.querySelector("textarea").value.trim();
    const previous = card.dataset.state;
    const next = previous === decision ? "waiting" : decision;  // tapping the active choice again clears it
    paint(card, next === "waiting" ? "" : next);
    note.classList.remove("err");
    note.textContent = "Saving…";
    try {
      const ref = db.doc("decisions/" + card.dataset.id);
      if (next === "waiting") await ref.delete();
      else await ref.set({ decision: next, words, at: new Date().toISOString() });
      note.textContent = next === "waiting" ? "Cleared" : "Saved";
    } catch (e) {
      paint(card, previous === "waiting" ? "" : previous);
      note.classList.add("err");
      note.textContent = "Not saved (" + (e && e.code || "error") + "). Try again, or reply in chat.";
    }
  }

  document.addEventListener("click", ev => {
    const act = ev.target.closest(".act");
    if (act) return decide(act.closest(".card"), act.dataset.decision);
    const shot = ev.target.closest(".shot");
    if (shot) {
      const box = document.createElement("div");
      box.className = "lightbox";
      box.setAttribute("role", "dialog");
      box.setAttribute("aria-label", "Full size concept");
      const img = document.createElement("img");
      img.src = shot.dataset.full;
      img.alt = shot.querySelector("img").alt;
      box.append(img);
      const close = () => { box.remove(); shot.focus(); document.removeEventListener("keydown", onKey); };
      const onKey = e => { if (e.key === "Escape") close(); };
      box.addEventListener("click", close);
      document.addEventListener("keydown", onKey);
      document.body.append(box);
    }
  });

  document.addEventListener("change", async ev => {
    const area = ev.target.closest("textarea");
    if (!area || !db) return;
    const card = area.closest(".card");
    if (card.dataset.state === "waiting") return;  // words travel with a decision
    try {
      await db.doc("decisions/" + card.dataset.id).update({ words: area.value.trim(), at: new Date().toISOString() });
      card.querySelector(".saved").textContent = "Words saved";
    } catch (e) { /* the next decision tap saves them */ }
  });

  const claude = window.claude;
  if (!claude || typeof claude.use !== "function") {
    statusEl.textContent = "Read-only copy: reply in chat with your picks.";
    return;
  }
  claude.use("db").then(ns => {
    if (!ns) { statusEl.textContent = "Saving isn't available here: reply in chat with your picks."; return; }
    db = ns;
    db.collection("decisions").onSnapshot(snap => {
      const byId = new Map(snap.docs.map(d => [d.id, d.data()]));
      for (const card of cards) {
        const d = byId.get(card.dataset.id);
        paint(card, d ? d.decision : "", d ? d.words : undefined, d ? d.at : null);
      }
      statusEl.textContent = "Choices save as you tap";
      statusEl.classList.add("live");
    }, err => {
      statusEl.textContent = "Lost the connection (" + err.code + "). Reload to keep saving.";
      statusEl.classList.remove("live");
    });
  });
})();
</script>"""


if __name__ == "__main__":
    sys.exit(main())
