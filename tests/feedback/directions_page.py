#!/usr/bin/env python3
"""Round 37 (feedback, F1): the lead's directions page, from `make feedback-shots` output.

    make remote T=feedback-shots         # build/feedback-shots/laptop/: stills + clips from a real skirmish
    make feedback-page                   # build/feedback-page/index.html + media/
    (Claude publishes it as a private Artifact with capabilities {"db": {}, "user": {}}; the lead taps a pick per slot)
    (read back: ArtifactData list of collection "picks" -> picks/<slot> = {letters: [..], words, at})

One section per slot (hit, pinned, repair, cone): what it looks like today (nothing), then each direction as a clip at
his camera, a close still, and a one-line tradeoff; a pick toggle per direction (combinations allowed), a words box,
and Save. Standard library + Pillow (stills re-encoded as JPEG to keep the page light).
"""

import argparse
import html
import json
import shutil
from pathlib import Path

from PIL import Image

SLOTS = [
    {"id": "hit", "title": "A shot that lands on the flank or the rear",
     "notice": "Today a round into a tank's side or back looks exactly like one into its front, so flanking feels like "
               "nothing happened. Each still shows three enemy tanks hit at the same instant: the front (left), the flank "
               "(middle) and the rear (right). A hit in the engine deck keeps its gold flare whichever look you pick.",
     "options": {
         "a": ("A flare by the face struck", "The hit itself changes: a pale glance off the front armour, an orange burst on "
               "the flank, a big red burst with a ring from behind. Reads in the heat of a fight; adds a little to a busy screen."),
         "b": ("A hit marker over the unit", "A small wedge beside the health bar points in from the side that was hit, with "
               "FLANK or REAR over it for a second. The clearest from far out; it is a HUD mark, not something in the world."),
         "c": ("The struck side lit on a ring", "A quarter of a ring under the tank flashes on the side the round struck: shows "
               "WHERE the armour was hit, which teaches facing. Flatter from your low camera angle."),
     }},
    {"id": "pinned", "title": "A crew pinned by heavy fire",
     "notice": "Suppression already makes a crew shoot wide and see less; soon it will also slow it down (never stop it). "
               "Each still shows four enemy crews: untouched, lightly, heavily and fully pinned.",
     "options": {
         "a": ("Heads-down chevrons", "One to three yellow chevrons over the health bar, pulsing, more as the fire gets "
               "heavier. Small and readable at any zoom; another mark over the bar."),
         "b": ("A pin ring at the hull", "A dashed yellow ring at the vehicle's wheels that tightens with four pins pointing "
               "in. In the world, not the HUD; harder to read on a crowded street."),
         "c": ("The bar outlined, PINNED", "The health bar gets a yellow frame and the word PINNED under it. Unmistakable; the "
               "most text on screen."),
     }},
    {"id": "repair", "title": "The Resupply Tanker mending",
     "notice": "The gangs' Tanker repairs friends within 18 m at 5 hit points a second once they have not been hit for 3 s. "
               "Each still shows a Tanker with two hurt friends inside its reach and one hurt friend outside it (not mended).",
     "options": {
         "a": ("A mending beam", "A green beam arcs from the Tanker to each vehicle it is repairing, pulses flowing along it. "
               "Says who mends whom at a glance."),
         "b": ("Its reach as a ring", "While it is mending, the Tanker's 18 m reach shows as a dashed green ring, and each "
               "vehicle being mended glows green underneath with a plus. Shows where to park; the ring is big."),
         "c": ("The health bar filling", "The mended vehicle's health bar gets a bright moving edge and +5/s beside it. "
               "Says how fast; does not show which Tanker."),
     }},
    {"id": "cone", "title": "The Sonic Emitter blowing",
     "notice": "The Law's Emitter does almost no damage; it pins everything in a 40 degree cone out to 32 m. Each still "
               "shows an Emitter blowing at two enemy tanks; they get pinned for real, so the pinned look shows on them too.",
     "options": {
         "a": ("Sound ripples on the ground", "Violet arcs run outward across the ground inside the cone. Reads as sound; "
               "the cone's exact edge is softer."),
         "b": ("The cone's footprint", "The whole cone drawn on the ground, faint fill, bright edges and end. Shows exactly "
               "what it reaches; more of a diagram than an effect."),
         "c": ("A shimmer in the air", "A see-through cone in the air with pressure rings running out from the horns. The "
               "most 'thing in the world'; from straight above it is thinner."),
     }},
]
RECOMMENDED = {"hit": "a", "pinned": "a", "repair": "a", "cone": "b"}
## Lead gate 1: ElevenLabs is spent only on text he approves. At most 4 new sounds this round (C37.6); the Emitter already
## has its horn loop (sonic_loop), so three are asked for.
SOUNDS = [
    ("flank_hit", "A flank hit", "A tank shell slamming into the thin side armour of a heavy vehicle: a sharp metallic crack, "
     "a deep tearing clang as the plate buckles, fragments rattling inside the hull, a short ring of metal. Single impact, "
     "no explosion, no music."),
    ("rear_hit", "A rear hit", "A shell punching into the rear engine compartment of an armoured truck: a brutal hollow "
     "crunch of metal, a burst of hissing steam, a whoomp of fuel catching, the engine coughing and grinding. Single impact, "
     "no music."),
    ("repair_loop", "The Tanker mending (a loop)", "Field repair on an armoured truck, seamless loop: an impact wrench "
     "ratcheting in short bursts, a welding torch hiss and crackle, a hydraulic pump whine, spanners clinking on steel. "
     "No voices, no music."),
]
## The caller already has rear and engine-deck lines (caller.hit.07-09, caller.kill.38-39); a flank hit has none. Voiced
## lines are paid too, so their text goes to him first.
LINES = [
    ("caller.hit.flank.01", "Caught broadside! That is what happens when you show them your doors!"),
    ("caller.hit.flank.02", "They went the long way round, and it paid off big!"),
    ("caller.hit.flank.03", "Right in the side panel! Nobody was watching that flank!"),
]


def still(src: Path, out: Path, width: int = 1400) -> str:
    image = Image.open(src).convert("RGB")
    if image.width > width:
        image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
    name = src.stem + ".jpg"
    image.save(out / name, quality=84, optimize=True)
    return "media/" + name


def build(shots: Path, out: Path) -> Path:
    media = out / "media"
    if out.exists():
        shutil.rmtree(out)
    media.mkdir(parents=True)
    source = (shots / "SOURCE.txt").read_text().strip() if (shots / "SOURCE.txt").exists() else ""
    sections = []
    for slot in SLOTS:
        sid = slot["id"]
        before = shots / f"{sid}_none_rts.png"
        cards = []
        for letter, (name, note) in slot["options"].items():
            clip = shots / f"{sid}_{letter}.mp4"
            rts = shots / f"{sid}_{letter}_rts.png"
            close = shots / f"{sid}_{letter}_close.png"
            rts_src = still(rts, media) if rts.exists() else ""
            close_src = still(close, media) if close.exists() else ""
            if clip.exists():
                shutil.copyfile(clip, media / clip.name)
                main = (f'<video class="shot" src="media/{clip.name}" poster="{rts_src}" autoplay muted loop playsinline '
                        f'aria-label="{html.escape(name)}, at your camera"></video>')
            else:
                main = f'<img class="shot" src="{rts_src}" alt="{html.escape(name)}, at your camera">'
            rec = '<span class="rec">Recommended</span>' if RECOMMENDED[sid] == letter else ""
            cards.append(f"""
      <article class="option" data-slot="{sid}" data-letter="{letter}">
        <figure>{main}<figcaption>Your camera: 49 m, 21&deg;</figcaption></figure>
        {f'<button type="button" class="zoom" data-src="{close_src}"><img src="{close_src}" alt="{html.escape(name)}, close in" loading="lazy"><span>Close in</span></button>' if close_src else ''}
        <div class="body">
          <h3><span class="letter">{letter.upper()}</span>{html.escape(name)} {rec}</h3>
          <p>{html.escape(note)}</p>
          <button type="button" class="pick" id="pick-{sid}-{letter}" aria-pressed="false">Pick {letter.upper()}</button>
        </div>
      </article>""")
        before_html = (f'<figure class="before"><img src="{still(before, media)}" alt="Today, nothing shows" loading="lazy">'
                       f'<figcaption>Today: nothing shows</figcaption></figure>') if before.exists() else ""
        sections.append(f"""
  <section class="slot" id="{sid}">
    <header>
      <p class="eyebrow">{sid}</p>
      <h2>{html.escape(slot['title'])}</h2>
      <p class="notice">{html.escape(slot['notice'])}</p>
    </header>
    {before_html}
    <div class="options">{''.join(cards)}
    </div>
    <div class="answer">
      <label for="words-{sid}">Anything to change? (optional)</label>
      <textarea id="words-{sid}" rows="2" placeholder="e.g. A, but smaller"></textarea>
      <div class="row"><button type="button" class="save" id="save-{sid}" data-slot="{sid}">Save my pick</button>
      <span class="status" id="status-{sid}" aria-live="polite"></span></div>
    </div>
  </section>""")
    rows = "".join(f"""
      <article class="sound" data-sound="{sid}">
        <h3>{html.escape(title)}</h3>
        <p class="prompt">{html.escape(text)}</p>
        <label for="sound-words-{sid}">Change the description (optional)</label>
        <textarea id="sound-words-{sid}" rows="2"></textarea>
        <div class="row"><button type="button" class="pick approve" id="approve-{sid}" data-sound="{sid}" aria-pressed="false">Make this sound</button>
        <span class="status" id="sound-status-{sid}" aria-live="polite"></span></div>
      </article>""" for sid, title, text in SOUNDS)
    rows += "".join(f"""
      <article class="sound" data-sound="{lid}">
        <h3>The announcer, on a flank hit</h3>
        <p class="prompt">&ldquo;{html.escape(text)}&rdquo;</p>
        <label for="sound-words-{lid}">Change the line (optional)</label>
        <textarea id="sound-words-{lid}" rows="2"></textarea>
        <div class="row"><button type="button" class="pick approve" id="approve-{lid}" data-sound="{lid}" aria-pressed="false">Record this line</button>
        <span class="status" id="sound-status-{lid}" aria-live="polite"></span></div>
      </article>""" for lid, text in LINES)
    sections.append(f"""
  <section class="slot" id="sounds">
    <header>
      <p class="eyebrow">sounds</p>
      <h2>New sounds and lines, written out before they are made</h2>
      <p class="notice">These are the descriptions the sound generator gets. These are the descriptions the sound generator gets, and the announcer's new lines for a flank hit (he already calls rear and engine hits). Nothing is generated until you approve it. The Emitter already has its horn loop, so it gets no new sound.</p>
    </header>
    <div class="options">{rows}
    </div>
  </section>""")
    page = TEMPLATE.replace("{{SECTIONS}}", "".join(sections)).replace("{{SOURCE}}", html.escape(source)) \
        .replace("{{RECOMMENDED}}", json.dumps(RECOMMENDED))
    (out / "index.html").write_text(page)
    return out / "index.html"


TEMPLATE = r"""<title>Tank Squad Feedback Looks</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Saira+Condensed:wght@600;800&family=Atkinson+Hyperlegible:wght@400;700&family=Share+Tech+Mono&display=swap">
<style>
/* Layout: one long scroll, a section per slot; each slot's three looks side by side on desktop, stacked on a phone.
   A single dark look on purpose: it is the game's night arena, and the clips read best against it. */
:root {
  --bg: #0d1016; --panel: #151a23; --line: #263042; --fg: #e8ecf3; --dim: #93a0b6;
  --signal: #ffb21f; --picked: #57f08c; --rec: #7fb2ff;
  --display: "Saira Condensed", "Arial Narrow", sans-serif;
  --body: "Atkinson Hyperlegible", system-ui, sans-serif;
  --mono: "Share Tech Mono", ui-monospace, monospace;
  color-scheme: dark;
}
body { background: var(--bg); color: var(--fg); font: 16px/1.5 var(--body); }
.wrap { max-width: 1240px; margin: 0 auto; padding-block: 28px 64px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; gap: 56px; }
h1, h2, h3 { font-family: var(--display); text-wrap: balance; margin: 0; letter-spacing: 0.01em; }
h1 { font-size: clamp(2rem, 5vw, 3.2rem); font-weight: 800; text-transform: uppercase; }
h2 { font-size: clamp(1.5rem, 3.4vw, 2.2rem); font-weight: 800; }
h3 { font-size: 1.25rem; font-weight: 600; display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.intro { display: grid; gap: 12px; max-width: 70ch; }
.intro p { margin: 0; color: var(--dim); }
.eyebrow { font-family: var(--mono); text-transform: uppercase; letter-spacing: 0.14em; color: var(--signal); margin: 0; font-size: 0.85rem; }
.source { font-family: var(--mono); font-size: 0.78rem; color: var(--dim); }
.slot { display: grid; gap: 20px; border-top: 1px solid var(--line); padding-top: 28px; }
.slot header { display: grid; gap: 8px; max-width: 75ch; }
.notice { margin: 0; color: var(--dim); }
.before { margin: 0; max-width: 420px; }
.before img { border-radius: 4px; opacity: 0.85; }
figcaption { font-family: var(--mono); font-size: 0.75rem; color: var(--dim); padding-top: 4px; letter-spacing: 0.04em; }
.options { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 18px; }
.option { background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 12px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.option.on { border-color: var(--picked); box-shadow: 0 0 0 1px var(--picked) inset; }
.option figure { margin: 0; }
.shot { width: 100%; aspect-ratio: 1854 / 1011; object-fit: cover; border-radius: 4px; background: #000; display: block; max-width: 100%; }
.zoom { all: unset; cursor: zoom-in; display: flex; gap: 10px; align-items: center; font-family: var(--mono); font-size: 0.78rem; color: var(--dim); }
.zoom img { width: 120px; aspect-ratio: 1854 / 1011; object-fit: cover; border-radius: 3px; }
.zoom:focus-visible, button:focus-visible, textarea:focus-visible { outline: 2px solid var(--signal); outline-offset: 2px; }
.body { display: grid; gap: 8px; }
.body p { margin: 0; color: var(--dim); font-size: 0.95rem; }
.letter { font-family: var(--mono); background: var(--signal); color: #111; border-radius: 3px; padding: 0 7px; font-size: 1rem; }
.rec { font-family: var(--mono); font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--rec); border: 1px solid var(--rec); border-radius: 3px; padding: 1px 6px; }
button.pick, button.save { font: 700 1rem var(--body); border-radius: 4px; padding: 10px 14px; cursor: pointer; border: 1px solid var(--line); background: #1d2430; color: var(--fg); }
button.pick[aria-pressed="true"] { background: var(--picked); color: #062311; border-color: var(--picked); }
button.save { background: var(--signal); color: #1a1000; border-color: var(--signal); }
button:disabled { opacity: 0.5; cursor: default; }
.answer { display: grid; gap: 8px; max-width: 640px; }
.answer label { font-size: 0.9rem; color: var(--dim); }
textarea { font: inherit; background: var(--panel); color: var(--fg); border: 1px solid var(--line); border-radius: 4px; padding: 8px; resize: vertical; }
.row { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
.sound { background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 14px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.sound .prompt { margin: 0; font-family: var(--mono); font-size: 0.9rem; color: var(--fg); }
.sound label { font-size: 0.85rem; color: var(--dim); }
.status { font-family: var(--mono); font-size: 0.85rem; color: var(--picked); }
.lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); display: grid; place-items: center; z-index: 20; cursor: zoom-out;
  padding: max(16px, env(safe-area-inset-top, 0px)) max(16px, env(safe-area-inset-right, 0px)) max(16px, env(safe-area-inset-bottom, 0px)) max(16px, env(safe-area-inset-left, 0px)); }
.lightbox img { max-height: 100%; max-width: 100%; }
@media (prefers-reduced-motion: reduce) { video.shot { animation: none; } }
</style>
<main class="wrap">
  <div class="intro">
    <p class="eyebrow">Round 37 &middot; pick a look</p>
    <h1>What the rules are doing</h1>
    <p>Four things the game does today that you cannot see. Each has three looks, filmed in a real match on the Terminus with your laptop's settings and your camera. Pick one look per section, or two if you want both, add words if you like, and press Save. The recommended one is marked.</p>
    <p>At the bottom: three new sounds (a flank hit, a rear hit, the Tanker mending) and three announcer lines for a flank hit, written out for you to approve before any are made.</p>
    <p class="source">{{SOURCE}}</p>
  </div>
{{SECTIONS}}
</main>
<div class="lightbox" id="lightbox" hidden><img alt="Close-up" id="lightbox-img"></div>
<script>
const RECOMMENDED = {{RECOMMENDED}};
const picked = {};
document.querySelectorAll(".option").forEach(card => {
  const slot = card.dataset.slot, letter = card.dataset.letter;
  picked[slot] = picked[slot] || new Set();
  card.querySelector(".pick").addEventListener("click", ev => {
    const set = picked[slot];
    set.has(letter) ? set.delete(letter) : set.add(letter);
    render(slot);
  });
});
function render(slot) {
  document.querySelectorAll(`.option[data-slot="${slot}"]`).forEach(card => {
    const on = picked[slot].has(card.dataset.letter);
    card.classList.toggle("on", on);
    card.querySelector(".pick").setAttribute("aria-pressed", String(on));
  });
}
document.querySelectorAll(".zoom").forEach(b => b.addEventListener("click", () => {
  document.getElementById("lightbox-img").src = b.dataset.src;
  document.getElementById("lightbox").hidden = false;
}));
document.getElementById("lightbox").addEventListener("click", ev => { ev.currentTarget.hidden = true; });
document.addEventListener("keydown", ev => { if (ev.key === "Escape") document.getElementById("lightbox").hidden = true; });

let db = null;
function say(slot, text) { document.getElementById("status-" + slot).textContent = text; }
document.querySelectorAll(".save").forEach(button => button.addEventListener("click", async () => {
  const slot = button.dataset.slot;
  const letters = [...picked[slot]].sort();
  if (!letters.length) { say(slot, "Pick at least one look first."); return; }
  if (!db) { say(slot, "Saving is not available here: tell Claude your pick (" + slot + ": " + letters.join("+") + ")."); return; }
  button.disabled = true;
  try {
    await db.doc("picks/" + slot).set({letters, words: document.getElementById("words-" + slot).value.trim(), at: new Date().toISOString()});
    say(slot, "Saved: " + letters.map(l => l.toUpperCase()).join(" + "));
  } catch (e) {
    say(slot, "Not saved (" + (e && e.code || "error") + "). Try again, or tell Claude your pick.");
  } finally { button.disabled = false; }
}));
document.querySelectorAll(".approve").forEach(button => button.addEventListener("click", async () => {
  const id = button.dataset.sound;
  const on = button.getAttribute("aria-pressed") !== "true";
  const status = document.getElementById("sound-status-" + id);
  if (!db) { status.textContent = "Saving is not available here: tell Claude (" + id + ")."; return; }
  button.disabled = true;
  try {
    await db.doc("sounds/" + id).set({approved: on, words: document.getElementById("sound-words-" + id).value.trim(), at: new Date().toISOString()});
  } catch (e) {
    status.textContent = "Not saved (" + (e && e.code || "error") + ").";
  } finally { button.disabled = false; }
}));
(async () => {
  try { db = window.claude ? await window.claude.use("db") : null; } catch (e) { db = null; }
  if (!db) return;
  for (const slot of Object.keys(RECOMMENDED)) {
    db.doc("picks/" + slot).onSnapshot(snap => {
      if (!snap.exists) return;
      const data = snap.data();
      picked[slot] = new Set(data.letters || []);
      document.getElementById("words-" + slot).value = data.words || "";
      render(slot);
      say(slot, "Saved: " + (data.letters || []).map(l => l.toUpperCase()).join(" + "));
    }, () => {});
  }
  document.querySelectorAll(".approve").forEach(button => {
    const id = button.dataset.sound;
    db.doc("sounds/" + id).onSnapshot(snap => {
      if (!snap.exists) return;
      const data = snap.data();
      button.setAttribute("aria-pressed", String(!!data.approved));
      button.textContent = data.approved ? "Approved: will be made" : (id.startsWith("caller") ? "Record this line" : "Make this sound");
      document.getElementById("sound-words-" + id).value = data.words || "";
      document.getElementById("sound-status-" + id).textContent = data.approved ? "Saved" : "Not approved";
    }, () => {});
  });
})();
</script>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--shots", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    page = build(args.shots, args.out)
    files = sorted(p.relative_to(args.out).as_posix() for p in (args.out / "media").iterdir())
    print(f"feedback-page: {page} ({len(files)} media files)")


if __name__ == "__main__":
    main()
