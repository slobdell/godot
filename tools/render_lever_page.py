#!/usr/bin/env python3
"""The lead's render-levers page (render, round 16, R8): what each picture-changing lever buys, at his window.

Reads `make lever-shots` output (build/look-parity/lever_<name>/sumps-1854x1011/{live,his}_t0150_fx.png against
lever_none, plus each lever's diff report) and writes a page and its frames as JPEGs. Every lever is OFF in the game;
the page asks, per lever, whether it goes on. Taps go to the `db` capability at `decisions/<lever>` as
{decision, words, at} (the fleet and water pages' schema), so the orchestrator reads them at the round's close.
Publishing is the Artifact tool's job; this only writes the files.

Usage: render_lever_page.py --shots build/look-parity --out build/lever-page --commit <sha> --gpu-all 16.0
"""
import argparse
import html
import json
import pathlib

from PIL import Image

# name, title, what he would see, GPU ms saved (laptop UHD 620, his window 1854x1011, frozen staged frame,
# within-run A/B, `make render-split`), the evidence line.
LEVERS = [
    ("scale_075", "Render the 3D at 75 % resolution",
     "The arena is drawn at three quarters of your window's lines and scaled up; the HUD and text stay sharp. "
     "Edges and distant detail get softer.", 3.48),
    ("scale_085", "Render the 3D at 85 % resolution",
     "The same at 85 %: softer, less so. Pick this or 75 %, not both.", 1.48),
    ("no_env_fog", "No arena fog",
     "The depth and height haze that sits over the floor and fades the far stands goes. The night reads clearer "
     "and flatter.", 1.05),
    ("lights_2", "Two explosion lights instead of four",
     "Fireballs and muzzle flashes light the floor and nearby hulls two at a time instead of four. In a big "
     "exchange some blasts stop lighting their surroundings.", 0.62),
    ("no_haze", "No heat shimmer over wrecks",
     "The air above burning wrecks stops bending. The fires and smoke stay.", 0.46),
    ("crowd_medium", "A thinner crowd",
     "The stands seat about 3,600 figures instead of every one of the ~7,700 seats.", 0.31),
    ("unlit_stands", "Flat-lit stands",
     "The grandstand steel loses its moonlight shading and reads flatter. The crowd is unchanged.", 0.23),
]
POSES = [("live", "your camera"), ("his", "centre, your pitch and zoom"), ("venue", "low, toward the north stands")]


def jpeg(src: pathlib.Path, dst: pathlib.Path) -> bool:
    if not src.exists():
        return False
    Image.open(src).convert("RGB").save(dst, quality=84)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default="build/look-parity")
    ap.add_argument("--out", default="build/lever-page")
    ap.add_argument("--commit", required=True)
    ap.add_argument("--gpu-all", type=float, required=True)
    ap.add_argument("--arena", default="sumps")
    args = ap.parse_args()
    shots, out = pathlib.Path(args.shots), pathlib.Path(args.out)
    (out / "frames").mkdir(parents=True, exist_ok=True)
    sub = "%s-1854x1011" % args.arena
    cards = []
    for pose, _ in POSES:
        jpeg(shots / "lever_none" / sub / ("%s_t0150_fx.png" % pose), out / "frames" / ("none_%s.jpg" % pose))
    for name, title, what, saved in LEVERS:
        changed = "–"
        report = shots / ("lever_diff_%s" % name) / "report.json"
        if report.exists():
            pairs = {p["name"]: p for p in json.loads(report.read_text())["pairs"]}
            row = pairs.get("%s/live_t0150_fx.png" % sub)
            if row and "share" in row:
                changed = "%.0f %%" % (row["share"] * 100.0)
        frames = []
        for pose, label in POSES:
            ok = jpeg(shots / ("lever_%s" % name) / sub / ("%s_t0150_fx.png" % pose), out / "frames" / ("%s_%s.jpg" % (name, pose)))
            if ok:
                frames.append((pose, label))
        cards.append({"name": name, "title": title, "what": what, "saved": saved, "changed": changed, "frames": frames})
    (out / "index.html").write_text(page(cards, args.commit, args.gpu_all))
    print("lever page: %s (%d levers)" % (out / "index.html", len(cards)))


def page(cards, commit, gpu_all):
    items = []
    for c in cards:
        figs = "".join(
            '<figure class="pair"><div class="frames">'
            '<img src="frames/none_%s.jpg" alt="Now, %s" loading="lazy">'
            '<img src="frames/%s_%s.jpg" alt="With the lever, %s" loading="lazy" class="after">'
            '</div><figcaption><button type="button" class="flip" aria-pressed="false">Show with the lever</button>'
            '<span>%s</span></figcaption></figure>' % (pose, label, c["name"], pose, label, html.escape(label))
            for pose, label in c["frames"])
        items.append('''
<section class="lever" data-lever="{name}" data-saved="{saved}">
  <header>
    <h2>{title}</h2>
    <p class="price"><b>−{saved:.2f} ms</b> GPU <span class="dim">· {changed} of the frame changes</span></p>
  </header>
  <p class="what">{what}</p>
  {figs}
  <p class="flag">To play it: <code>make skirmish SKIRMISH_FLAGS=--render-levers={name}</code></p>
  <div class="choose" role="group" aria-label="{title}">
    <button type="button" data-decision="on">Turn it on</button>
    <button type="button" data-decision="off">Keep the picture</button>
    <button type="button" data-decision="try">I'll play it first</button>
  </div>
  <label class="words">Your words (optional)<textarea id="words-{name}" rows="2"></textarea></label>
  <p class="state" aria-live="polite"></p>
</section>'''.format(name=c["name"], title=html.escape(c["title"]), what=html.escape(c["what"]), saved=c["saved"],
                     changed=c["changed"], figs=figs))
    return TEMPLATE.replace("{{ITEMS}}", "".join(items)).replace("{{COMMIT}}", html.escape(commit)) \
        .replace("{{GPU}}", "%.1f" % gpu_all)


TEMPLATE = r'''<title>Render Levers</title>
<style>
/* Layout: one column of lever cards under a sticky budget bar; each card is the before/after at his pose. */
:root {
  --bg: #f3f4f6; --panel: #ffffff; --ink: #15171c; --dim: #5d6370; --line: #d9dce3;
  --accent: #0f7b8a; --on: #1f7a3a; --off: #6b4f9e; --try: #8a5a12;
  --display: "Oswald", "Arial Narrow", sans-serif; --body: "IBM Plex Sans", system-ui, sans-serif;
  --mono: "Share Tech Mono", ui-monospace, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0d0f14; --panel: #161a22; --ink: #e8eaf0; --dim: #9aa1b0; --line: #2a303c;
  --accent: #39c6d6; --on: #5ccf7c; --off: #b39ae6; --try: #e0a94a; color-scheme: dark } }
:root[data-theme="dark"] { --bg: #0d0f14; --panel: #161a22; --ink: #e8eaf0; --dim: #9aa1b0; --line: #2a303c;
  --accent: #39c6d6; --on: #5ccf7c; --off: #b39ae6; --try: #e0a94a; color-scheme: dark }
body { background: var(--bg); color: var(--ink); font: 15px/1.5 var(--body); padding: 0 16px 48px; }
main { max-width: 980px; margin: 0 auto; display: grid; gap: 20px; }
h1, h2 { font-family: var(--display); font-weight: 500; text-wrap: balance; letter-spacing: .01em; margin: 0; }
h1 { font-size: 1.9rem; margin-top: 24px; }
.intro { max-width: 68ch; color: var(--ink); }
.intro p { margin: .4em 0; }
.dim { color: var(--dim); }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 2; background: var(--bg);
  border-bottom: 1px solid var(--line); padding-block: 10px; display: flex; flex-wrap: wrap; gap: 6px 18px;
  align-items: baseline; font-variant-numeric: tabular-nums; }
.bar b { font-family: var(--mono); font-size: 1.15rem; }
.meter { flex: 1 1 220px; height: 8px; background: var(--line); border-radius: 4px; overflow: hidden; align-self: center; }
.meter i { display: block; height: 100%; width: 0; background: var(--accent); transition: width .3s; }
.lever { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 16px; display: grid; gap: 10px; min-width: 0; }
.lever header { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 4px 16px; align-items: baseline; }
.price { margin: 0; font-variant-numeric: tabular-nums; }
.price b { font-family: var(--mono); font-size: 1.1rem; color: var(--accent); }
.what { margin: 0; max-width: 70ch; }
.pair { margin: 0; display: grid; gap: 6px; }
.frames { position: relative; }
.frames img { display: block; width: 100%; height: auto; border-radius: 4px; }
.frames img.after { position: absolute; inset: 0; opacity: 0; transition: opacity .15s; }
.pair.showing .frames img.after { opacity: 1; }
figcaption { display: flex; gap: 10px; align-items: center; color: var(--dim); font-size: .9rem; flex-wrap: wrap; }
.flip { font: inherit; border: 1px solid var(--line); background: var(--bg); color: var(--ink); border-radius: 4px; padding: 4px 10px; cursor: pointer; }
.flip[aria-pressed="true"] { border-color: var(--accent); color: var(--accent); }
.flag { margin: 0; font-size: .9rem; color: var(--dim); }
code { font-family: var(--mono); color: var(--ink); overflow-wrap: anywhere; }
.choose { display: flex; flex-wrap: wrap; gap: 8px; }
.choose button { font: 600 .95rem var(--body); padding: 8px 14px; border-radius: 6px; border: 1px solid var(--line);
  background: var(--bg); color: var(--ink); cursor: pointer; }
.choose button[data-decision="on"][aria-pressed="true"] { border-color: var(--on); color: var(--on); }
.choose button[data-decision="off"][aria-pressed="true"] { border-color: var(--off); color: var(--off); }
.choose button[data-decision="try"][aria-pressed="true"] { border-color: var(--try); color: var(--try); }
button:focus-visible, textarea:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.words { display: grid; gap: 4px; font-size: .9rem; color: var(--dim); }
textarea { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 6px; padding: 6px 8px; resize: vertical; }
.state { margin: 0; font-size: .9rem; color: var(--dim); min-height: 1.2em; }
.foot { color: var(--dim); font-size: .85rem; max-width: 70ch; }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;600&family=Oswald:wght@500&family=Share+Tech+Mono&display=swap">
<main>
  <h1>What can the picture give up for a smooth game?</h1>
  <div class="intro">
    <p>The graphics card takes <b>{{GPU}} ms</b> to draw one frame at your laptop's window (1854 × 1011). The goal is
    10 ms, so the game has room for everything else inside a steady 30 frames a second. The work so far took off what
    nobody could see; every lever below changes what you see, so none of them is on.</p>
    <p class="dim">Each frame pair is the same frozen moment of a Sumps skirmish with the same staged explosions.
    Press <i>Show with the lever</i> to flip between now and with it. Glow is not on this page: you asked to keep it.</p>
  </div>
  <div class="bar" aria-live="polite">
    <span>Turned on: <b id="total">0.00 ms</b> of the 6 ms needed</span>
    <span class="meter" aria-hidden="true"><i id="meter"></i></span>
    <span class="dim" id="sync">Your choices are saved for the next round.</span>
  </div>
  {{ITEMS}}
  <p class="foot">Measured on the laptop (Intel UHD 620) at your window, each lever against "everything on" in the same
  run, at commit {{COMMIT}}. Savings don't add exactly; the two resolution levers overlap, so pick one.</p>
</main>
<script>
(function () {
  const levers = Array.from(document.querySelectorAll(".lever"));
  const choices = {};
  function render() {
    let total = 0;
    for (const card of levers) {
      const name = card.dataset.lever, mine = choices[name] || {};
      for (const b of card.querySelectorAll(".choose button")) b.setAttribute("aria-pressed", String(b.dataset.decision === mine.decision));
      const words = card.querySelector("textarea");
      if (mine.words !== undefined && document.activeElement !== words) words.value = mine.words;
      card.querySelector(".state").textContent = mine.decision ? ({on: "Saved: turn it on.", off: "Saved: keep the picture.", try: "Saved: you'll play it first."})[mine.decision] : "";
      if (mine.decision === "on") total += parseFloat(card.dataset.saved);
    }
    document.getElementById("total").textContent = total.toFixed(2) + " ms";
    document.getElementById("meter").style.width = Math.min(100, total / 6 * 100) + "%";
  }
  for (const fig of document.querySelectorAll(".pair")) {
    const btn = fig.querySelector(".flip");
    btn.addEventListener("click", () => {
      const on = fig.classList.toggle("showing");
      btn.setAttribute("aria-pressed", String(on));
      btn.textContent = on ? "Show it now" : "Show with the lever";
    });
  }
  let db = null;
  async function save(name, patch) {
    choices[name] = Object.assign({}, choices[name], patch, {at: new Date().toISOString()});
    render();
    if (!db) { document.getElementById("sync").textContent = "Not saved: this view can't store choices."; return; }
    try { await db.doc("decisions/" + name).set(choices[name]); document.getElementById("sync").textContent = "Saved."; }
    catch (e) { document.getElementById("sync").textContent = "Not saved (" + (e && e.code || "error") + "). Try again in a moment."; }
  }
  for (const card of levers) {
    const name = card.dataset.lever;
    for (const b of card.querySelectorAll(".choose button")) b.addEventListener("click", () => save(name, {decision: b.dataset.decision, words: card.querySelector("textarea").value.trim()}));
    card.querySelector("textarea").addEventListener("change", (e) => { if ((choices[name] || {}).decision) save(name, {words: e.target.value.trim()}); });
  }
  render();
  if (window.claude && window.claude.use) {
    window.claude.use("db").then((store) => {
      db = store;
      if (!db) { document.getElementById("sync").textContent = "Choices can't be saved in this view."; return; }
      db.collection("decisions").onSnapshot((snap) => {
        for (const d of snap.docs) choices[d.id] = d.data();
        render();
      });
    });
  }
})();
</script>
'''

if __name__ == "__main__":
    main()
