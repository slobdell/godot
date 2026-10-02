#!/usr/bin/env python3
"""Round 15 (squad P1): the lead's decision page for the gangs' encircle / bait verdicts.

Reads the series summary `make squad-doctrine-series` writes (build/squad-doctrine.json), a notes json (the
recommendation and the per-arm one-liners, written by the stream after reading the series) and a folder of frames
(<arm>.jpg, his pose), and writes one self-contained HTML page. Published as a private Artifact with
capabilities {"db": {}, "user": {}}: one tap stores {arm, words, at} in the doc `decisions/choice`; Claude reads it
back with ArtifactData. Nothing changes in doctrines/ until he has chosen (C12.6).

Usage: decision_page.py --series build/squad-doctrine.json --notes notes.json --frames DIR --out page.html
"""
import argparse
import base64
import html
import json
import os
import sys

ARMS = [("shipped", "As shipped", "encircle off, bait on"),
        ("encircle", "Encircle on", "encircle on, bait on"),
        ("nobait", "Bait off", "encircle off, bait off"),
        ("both", "Both flipped", "encircle on, bait off")]
ROW_CHANGE = {"shipped": "Nothing changes: doctrine_gangs.json stays as it is.",
              "encircle": "\"encircle\" is added to drills.enabled in doctrine_gangs.json.",
              "nobait": "\"bait\" is removed from drills.enabled in doctrine_gangs.json.",
              "both": "\"encircle\" is added to drills.enabled and \"bait\" is removed, in doctrine_gangs.json."}
OPPONENTS = [("guns", "Two dug-in guns"), ("chasers", "Two IFVs that chase"), ("standard", "A standard element")]


def pooled(cells, opponent, arm):
    """Mean over maps (yard, Terminus) of one arm against one opponent, plus summed W/L/T and discordant seeds."""
    rows = [c["arms"][arm] for c in cells if c["opponent"] == opponent and c["arena"] != "lane" and arm in c["arms"]]
    if not rows:
        return None
    n = sum(r["n"] for r in rows)
    out = {"n": n,
           "pack": sum(r["pack"] * r["n"] for r in rows) / n, "enemy": sum(r["enemy"] * r["n"] for r in rows) / n,
           "won": sum(r["won"] for r in rows), "lost": sum(r["lost"] for r in rows), "time": sum(r["time"] for r in rows)}
    vs = [r["vs_shipped"] for r in rows if r.get("vs_shipped")]
    if vs:
        out["lower"] = sum(v["enemy_lower"] for v in vs)
        out["higher"] = sum(v["enemy_higher"] for v in vs)
    return out


def sign_p(b, c):
    import math
    n = b + c
    if n == 0:
        return 1.0
    return min(1.0, 2.0 * sum(math.comb(n, i) for i in range(min(b, c) + 1)) / 2 ** n)


def frame_uri(folder, arm):
    for ext, mime in (("jpg", "image/jpeg"), ("png", "image/png")):
        path = os.path.join(folder, "%s.%s" % (arm, ext))
        if os.path.exists(path):
            with open(path, "rb") as handle:
                return "data:%s;base64,%s" % (mime, base64.b64encode(handle.read()).decode())
    return None


def card(arm, label, flags, cells, notes, frames):
    rows = []
    for opponent, opp_label in OPPONENTS:
        p = pooled(cells, opponent, arm)
        if p is None:
            continue
        if "lower" in p:
            vs = "%d / %d <span class=\"p\">p %.2f</span>" % (p["lower"], p["higher"], sign_p(p["lower"], p["higher"]))
        else:
            vs = "<span class=\"muted\">the control</span>"
        rows.append("<tr><th scope=\"row\">%s</th><td>%.0f%%</td><td>%.0f%%</td><td>%d–%d–%d</td><td>%s</td></tr>"
                    % (opp_label, 100 * p["pack"], 100 * p["enemy"], p["won"], p["lost"], p["time"], vs))
    uri = frame_uri(frames, arm)
    figure = ("<figure><img src=\"%s\" alt=\"%s: the pack against the chasers at 16 s, from the player's camera\" "
              "loading=\"lazy\"><figcaption>%s</figcaption></figure>"
              % (uri, html.escape(label), html.escape(notes.get("frame_caption", {}).get(arm, "")))) if uri else ""
    rec = " recommended" if notes.get("recommend") == arm else ""
    return """
<article class="card%s" data-arm="%s" id="arm-%s">
  <header><h2>%s</h2><span class="flags">%s</span>%s</header>
  <p class="verdict">%s</p>
  <div class="table-wrap"><table>
    <thead><tr><th scope="col">Against</th><th scope="col">Pack left</th><th scope="col">Enemy left</th>
    <th scope="col">Won–lost–time</th><th scope="col">Seeds enemy lower / higher than shipped</th></tr></thead>
    <tbody>%s</tbody></table></div>
  %s
  <p class="change"><strong>Choosing this:</strong> %s</p>
  <button type="button" class="choose" id="choose-%s" data-arm="%s" aria-pressed="false">Choose %s</button>
</article>""" % (rec, arm, arm, html.escape(label), html.escape(flags),
                 "<span class=\"badge\">Recommended</span>" if rec else "",
                 html.escape(notes.get("arms", {}).get(arm, "")), "".join(rows), figure, html.escape(ROW_CHANGE[arm]),
                 arm, arm, html.escape(label.lower()))


def build(series, notes, frames):
    cells = series["cells"]
    cards = "".join(card(a, l, f, cells, notes, frames) for a, l, f in ARMS)
    return TEMPLATE.replace("{{LEDE}}", html.escape(notes.get("lede", ""))) \
        .replace("{{RECOMMENDATION}}", html.escape(notes.get("recommendation", ""))) \
        .replace("{{METHOD}}", html.escape(notes.get("method", ""))) \
        .replace("{{CARDS}}", cards)


TEMPLATE = """<title>Gang Pack Verdicts</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@600;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400;600&display=swap">
<style>
/* Layout: one column of four arm cards, a decision bar that follows the reader; summary first, detail below. */
:root {
  --bg: #f3f4f1; --surface: #ffffff; --ink: #1d2320; --muted: #5d6762; --line: #d5dbd6;
  --accent: #c2410c; --accent-ink: #ffffff; --good: #2f6f4f; --rec: #fff1e6;
  --display: "Chakra Petch", "Arial Narrow", sans-serif; --body: "IBM Plex Sans", system-ui, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #141816; --surface: #1d2320; --ink: #e8ece9; --muted: #9aa5a0; --line: #333c37;
  --accent: #f08a4b; --accent-ink: #1a0f08; --good: #7fcfa3; --rec: #2b1f17; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #141816; --surface: #1d2320; --ink: #e8ece9; --muted: #9aa5a0; --line: #333c37;
  --accent: #f08a4b; --accent-ink: #1a0f08; --good: #7fcfa3; --rec: #2b1f17; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font: 15px/1.55 var(--body); }
main { max-width: 900px; margin: 0 auto; padding-inline: 16px; padding-block: 24px 96px; display: grid; gap: 20px; }
h1 { font: 700 2rem/1.1 var(--display); letter-spacing: .01em; margin: 0; text-wrap: balance; }
h2 { font: 700 1.3rem/1.2 var(--display); margin: 0; }
.eyebrow { font: 600 .75rem var(--mono); letter-spacing: .12em; text-transform: uppercase; color: var(--muted); margin: 0; }
.lede { max-width: 65ch; margin: 0; }
.rec-box { background: var(--rec); border-left: 4px solid var(--accent); padding: 12px 16px; max-width: 70ch; }
.rec-box p { margin: 0; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 16px; display: grid; gap: 12px; min-width: 0; }
.card.recommended { border-color: var(--accent); }
.card.chosen { outline: 3px solid var(--good); }
.card header { display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px 12px; }
.flags { font: .8rem var(--mono); color: var(--muted); }
.badge { font: 600 .7rem var(--mono); letter-spacing: .08em; text-transform: uppercase; background: var(--accent); color: var(--accent-ink); padding: 2px 8px; border-radius: 3px; }
.verdict { margin: 0; max-width: 65ch; }
.table-wrap { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; font-size: .88rem; }
th, td { text-align: left; padding: 6px 10px 6px 0; border-bottom: 1px solid var(--line); vertical-align: top; }
thead th { font: 600 .72rem var(--mono); text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }
td { font-family: var(--mono); }
.p, .muted { color: var(--muted); font-size: .8rem; }
figure { margin: 0; display: grid; gap: 4px; }
figure img { width: 100%; border-radius: 4px; border: 1px solid var(--line); }
figcaption { font-size: .82rem; color: var(--muted); }
.change { margin: 0; font-size: .9rem; }
button.choose { justify-self: start; font: 600 .95rem var(--body); padding: 10px 18px; border-radius: 4px; border: 2px solid var(--accent); background: transparent; color: var(--ink); cursor: pointer; }
button.choose:hover { background: var(--rec); }
button.choose[aria-pressed="true"] { background: var(--good); border-color: var(--good); color: var(--surface); }
button:focus-visible, textarea:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
.words { display: grid; gap: 6px; }
.words label { font-weight: 600; }
textarea { font: inherit; padding: 8px; min-height: 4.5em; border: 1px solid var(--line); border-radius: 4px; background: var(--surface); color: var(--ink); }
.bar { position: sticky; bottom: env(safe-area-inset-bottom, 0px); background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 10px 14px; display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: center; }
#status { font: .85rem var(--mono); color: var(--muted); }
#status.live { color: var(--good); }
#status.err { color: var(--accent); }
.method { font-size: .82rem; color: var(--muted); max-width: 75ch; margin: 0; }
@media (prefers-reduced-motion: no-preference) { button.choose { transition: background .15s; } }
</style>
<main>
  <p class="eyebrow">Tank Squad · round 15 · the gangs' doctrine table</p>
  <h1>Encircle on? Bait off?</h1>
  <p class="lede">{{LEDE}}</p>
  <div class="rec-box"><p><strong>Recommendation.</strong> {{RECOMMENDATION}}</p></div>
  {{CARDS}}
  <div class="words">
    <label for="words">Anything to add (saved with your choice)</label>
    <textarea id="words" placeholder="Optional"></textarea>
  </div>
  <p class="method">{{METHOD}}</p>
  <div class="bar" role="status"><span id="chosen">No choice yet.</span><span id="status">Connecting…</span></div>
</main>
<script>
(() => {
  const statusEl = document.getElementById("status");
  const chosenEl = document.getElementById("chosen");
  const words = document.getElementById("words");
  const buttons = Array.from(document.querySelectorAll("button.choose"));
  let db = null;

  function paint(arm, at) {
    for (const b of buttons) {
      const on = b.dataset.arm === arm;
      b.setAttribute("aria-pressed", on ? "true" : "false");
      b.closest(".card").classList.toggle("chosen", on);
    }
    const b = buttons.find(x => x.dataset.arm === arm);
    chosenEl.textContent = b ? "Chosen: " + b.closest(".card").querySelector("h2").textContent +
      (at ? " (saved " + new Date(at).toLocaleString() + ")" : "") : "No choice yet.";
  }

  async function choose(arm) {
    if (!db) {
      statusEl.className = "err";
      statusEl.textContent = "Saving isn't available in this view. Reply in chat with your choice.";
      return;
    }
    const current = buttons.find(b => b.getAttribute("aria-pressed") === "true");
    const clearing = current && current.dataset.arm === arm;
    paint(clearing ? "" : arm);
    statusEl.className = "";
    statusEl.textContent = "Saving…";
    try {
      const ref = db.doc("decisions/choice");
      if (clearing) await ref.delete();
      else await ref.set({ arm, words: words.value.trim(), at: new Date().toISOString() });
      statusEl.className = "live";
      statusEl.textContent = clearing ? "Cleared" : "Saved";
    } catch (e) {
      paint(current ? current.dataset.arm : "");
      statusEl.className = "err";
      statusEl.textContent = "Not saved (" + ((e && e.code) || "error") + "). Try again, or reply in chat.";
    }
  }

  document.addEventListener("click", ev => {
    const b = ev.target.closest("button.choose");
    if (b) choose(b.dataset.arm);
  });
  words.addEventListener("change", async () => {
    const current = buttons.find(b => b.getAttribute("aria-pressed") === "true");
    if (!db || !current) return;
    try {
      await db.doc("decisions/choice").update({ words: words.value.trim(), at: new Date().toISOString() });
      statusEl.textContent = "Words saved";
    } catch (e) { /* saved with the next tap */ }
  });

  const claude = window.claude;
  if (!claude || typeof claude.use !== "function") {
    statusEl.textContent = "Read-only copy: reply in chat with your choice.";
    return;
  }
  claude.use("db").then(ns => {
    if (!ns) { statusEl.textContent = "Saving isn't available here: reply in chat with your choice."; return; }
    db = ns;
    db.doc("decisions/choice").onSnapshot(snap => {
      const d = snap && snap.exists ? snap.data() : null;
      paint(d ? d.arm : "", d ? d.at : null);
      if (d && typeof d.words === "string" && document.activeElement !== words) words.value = d.words;
      statusEl.className = "live";
      statusEl.textContent = "Your choice saves when you tap";
    }, err => {
      statusEl.className = "err";
      statusEl.textContent = "Lost the connection (" + err.code + "). Reload to keep saving.";
    });
  });
})();
</script>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--series", required=True)
    parser.add_argument("--notes", required=True)
    parser.add_argument("--frames", default="")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    with open(args.series) as handle:
        series = json.load(handle)
    with open(args.notes) as handle:
        notes = json.load(handle)
    page = build(series, notes, args.frames)
    with open(args.out, "w") as handle:
        handle.write(page)
    print("decision_page: %s (%d KB)" % (args.out, len(page) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
