#!/usr/bin/env python3
"""The lead's water page (arena, round 12, A2): "water reads black and should read wet", judged at his pose.

Reads `make water-pairs` output (frames `<map>-<spot>-<look>.png`, the dry twin `<map>_dry-<spot>.png`, and
`stats.jsonl`) and writes a page plus its frames as JPEGs:

  - a first question: has he driven the Locks yet;
  - every water map, every spot: the dry twin, round 10's water and the water now, side by side, one tap each;
  - the build as pairs for one spot per map (WaterLook's steps, one dial each, the caption naming it);
  - the pits beside the new water: round 10 and now, with the changed-pixel count (0 means untouched);
  - the Locks question, with the exposure number beside it;
  - the numbers: the share of water pixels darker than 0.03 luma, before and after.

The page declares the `db` capability and writes each tap to `decisions/<id>` as {decision, words, at} (the fleet
page's schema), so the orchestrator reads it at the round's close. Publishing is the Artifact tool's job; this only
writes the files.

Usage: water_page.py --pairs build/water-pairs --out build/water-page --commit <sha> [--perf "<line>"]
"""
import argparse
import html
import json
import pathlib
import re
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent

MAPS = [
    ("crossing", "The Crossing", "Dealt. A river with two bridges."),
    ("locks", "The Locks", "Dealt. A canal wall to wall, the lock in the middle, a swing bridge each side."),
    ("terminus_canal", "The Terminus canal", "A fixture, not dealt: a canal drawn on the Terminus. Its before is the Terminus itself."),
]
PITS = [("sumps", "The Sumps"), ("pit", "The Pit")]
HERO = {"crossing": "bridge", "locks": "lock", "terminus_canal": "avenue_bridge"}
# The Locks' centre sees this share of the field (arenas.md, round 11: "the centre sees 0.45").
LOCKS_EXPOSURE = 0.45


def steps():
    """WaterLook.STEPS as [(name, caption)], read from the GDScript so the page cannot disagree with the pairs."""
    text = (ROOT / "game/theme/arena_kit/terrain/water_look.gd").read_text()
    block = text[text.index("const STEPS"):]
    return re.findall(r'\["(\w+)", "([^"]+)"', block)


def jpeg(src, dst, width=1280):
    image = Image.open(src).convert("RGB")
    image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
    image.save(dst, quality=84, optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pairs", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--perf", default="")
    args = parser.parse_args()
    pairs = pathlib.Path(args.pairs)
    out = pathlib.Path(args.out)
    (out / "frames").mkdir(parents=True, exist_ok=True)
    stats = {}
    for line in (pairs / "stats.jsonl").read_text().splitlines():
        row = json.loads(line)
        stats[(row["arena"], row["spot"], row["look"])] = row
    look_steps = steps()
    first, last = look_steps[0][0], look_steps[-1][0]

    def frame(name):
        src = pairs / f"{name}.png"
        if not src.exists():
            return None
        dst = out / "frames" / f"{name}.jpg"
        jpeg(src, dst)
        return f"frames/{name}.jpg"

    def spots_of(arena):
        return sorted({spot for (a, spot, look) in stats if a == arena}, key=lambda s: (s != HERO.get(arena), s))

    sections = []
    rows = []
    for arena, title, note in MAPS:
        cards = []
        for spot in spots_of(arena):
            before = stats.get((arena, spot, first))
            after = stats.get((arena, spot, last))
            if not before or before["water_px"] < 20000:
                continue  # a spot where the water is not really in frame is not a judgement of the water
            dry_name = "terminus" if arena == "terminus_canal" else f"{arena}_dry"
            imgs = [("Dry twin", frame(f"{dry_name}-{spot}")), ("Round 10", frame(f"{arena}-{spot}-{first}")),
                    ("Now", frame(f"{arena}-{spot}-{last}"))]
            ident = f"water_{arena}_{spot}"
            cards.append(card(ident, f"{title}, {spot.replace('_', ' ')}", imgs,
                              [("wet", "Reads wet"), ("black", "Still reads black"), ("much", "Too much")],
                              f"near-black water pixels {pct(before['black_share'])} → {pct(after['black_share'])}"))
            rows.append((title, spot, before, after))
        sequence = ""
        hero = HERO.get(arena)
        if hero and (arena, hero, first) in stats:
            tiles = []
            for i, (name, caption) in enumerate(look_steps):
                src = frame(f"{arena}-{hero}-{name}")
                if src is None:
                    continue
                ident = f"step_{arena}_{name}"
                buttons = "" if i == 0 else choice_buttons(ident, [("keep", "Keep"), ("drop", "Drop")])
                tiles.append(f"""<figure class="step"><img src="{src}" alt="{html.escape(caption)}" loading="lazy">
<figcaption><b>{i}. {html.escape(name)}</b> {html.escape(caption)}</figcaption>{buttons}</figure>""")
            sequence = f"""<details class="steps"><summary>How it was built, one dial per step ({html.escape(hero.replace('_', ' '))})</summary>
<p class="hint">Each frame changes ONE thing from the one before it, frozen at the same instant of the swell. Keep or drop any step.</p>
<div class="strip">{''.join(tiles)}</div></details>"""
        sections.append(f"""<section id="{arena}"><h2>{html.escape(title)}</h2><p class="note">{html.escape(note)}</p>
{''.join(cards)}{sequence}</section>""")

    pit_cards = []
    for arena, title in PITS:
        for spot in spots_of(arena):
            after = stats.get((arena, spot, last))
            if not after:
                continue
            imgs = [("Round 10", frame(f"{arena}-{spot}-{first}")), ("Now", frame(f"{arena}-{spot}-{last}"))]
            changed = after["changed_px"]
            pit_cards.append(card(f"pit_{arena}_{spot}", f"{title}, {spot.replace('_', ' ')}", imgs,
                                  [("pit", "Still reads as a pit"), ("changed", "Something changed")],
                                  "identical to round 10" if changed == 0 else f"{changed} pixels differ from round 10",
                                  pair=True))
            break  # one frame per pit map: they are identical by construction, the number says so

    table = "".join(
        f"<tr><td>{html.escape(t)}</td><td>{html.escape(s.replace('_', ' '))}</td><td>{pct(b['black_share'])}</td>"
        f"<td>{pct(a['black_share'])}</td><td>{b['mean_luma']:.3f}</td><td>{a['mean_luma']:.3f}</td></tr>"
        for t, s, b, a in rows)
    perf = f"<p class=\"hint\">{html.escape(args.perf)}</p>" if args.perf else ""
    page = TEMPLATE.format(
        commit=html.escape(args.commit), sections="".join(sections), pits="".join(pit_cards), table=table, perf=perf,
        exposure=f"{LOCKS_EXPOSURE:.0%}",
        driven=choice_buttons("q_locks_driven", [("yes", "Yes, I've driven it"), ("no", "Not yet")]),
        locks=choice_buttons("q_locks_canal", [("open", "Leave it open (the kill zone)"), ("cover", "Add cover on the quays"),
                                               ("later", "Ask me after I've driven it")]),
        locks_words=words_box("q_locks_canal"), driven_words=words_box("q_locks_driven"),
        overall=choice_buttons("water_overall", [("wet", "The water reads wet now"), ("black", "Still reads black"),
                                                ("much", "Wet, but too much")]),
        overall_words=words_box("water_overall"))
    (out / "index.html").write_text(page)
    print(f"water-page: {out / 'index.html'} ({len(list((out / 'frames').glob('*.jpg')))} frames)")


def pct(x):
    return f"{x:.0%}"


def choice_buttons(ident, options):
    return f"""<div class="choices" data-id="{ident}">""" + "".join(
        f"""<button type="button" data-choice="{value}">{html.escape(label)}</button>""" for value, label in options) + \
        """<span class="saved" aria-live="polite"></span></div>"""


def words_box(ident):
    return f"""<label class="words"><span>Your words (optional)</span><textarea id="w_{ident}" data-words="{ident}" rows="2"></textarea></label>"""


def card(ident, title, imgs, options, stat, pair=False):
    figures = "".join(
        f"""<figure><a href="{src}" target="_blank" rel="noopener"><img src="{src}" alt="{html.escape(title)}: {html.escape(label)}" loading="lazy"></a><figcaption>{html.escape(label)} · tap for full size</figcaption></figure>"""
        for label, src in imgs if src)
    return f"""<article class="card"><header><h3>{html.escape(title)}</h3><span class="stat">{html.escape(stat)}</span></header>
<div class="frames {'two' if pair else 'three'}">{figures}</div>{choice_buttons(ident, options)}{words_box(ident)}</article>"""


TEMPLATE = """<title>Canal Water Review</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;700&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono:wght@400&display=swap">
<style>
:root {{ color-scheme: dark; --bg:#0b1113; --panel:#131c1f; --line:#223036; --fg:#e3ecea; --dim:#8ea3a3;
  --teal:#3fd0c4; --amber:#f2b33d; --red:#ff6a4a; --chosen:#123a37; }}
body {{ background:var(--bg); color:var(--fg); font:15px/1.55 "IBM Plex Sans", system-ui, sans-serif; margin:0; }}
main {{ max-width:1400px; margin:0 auto; padding-inline:16px; padding-block:28px 64px; display:grid; gap:28px; }}
h1, h2, h3 {{ font-family:"Barlow Condensed", "Arial Narrow", sans-serif; font-weight:700; letter-spacing:.01em; text-wrap:balance; margin:0; }}
h1 {{ font-size:40px; }} h2 {{ font-size:30px; color:var(--teal); }} h3 {{ font-size:21px; font-weight:500; }}
.lede {{ max-width:68ch; color:var(--dim); margin:6px 0 0; }} .lede q {{ color:var(--fg); }}
.meta {{ font:12px/1.4 "IBM Plex Mono", monospace; color:var(--dim); }}
section {{ display:grid; gap:14px; }} .note {{ color:var(--dim); margin:0; max-width:68ch; }}
.card {{ background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:12px; display:grid; gap:10px; }}
.card header {{ display:flex; flex-wrap:wrap; justify-content:space-between; align-items:baseline; gap:6px 16px; }}
.stat {{ font:13px "IBM Plex Mono", monospace; color:var(--amber); font-variant-numeric:tabular-nums; }}
.frames {{ display:grid; gap:8px; }} .frames.three {{ grid-template-columns:minmax(0, .62fr) minmax(0, 1fr) minmax(0, 1fr); align-items:end; }}
.frames.two {{ grid-template-columns:repeat(2, minmax(0, 1fr)); }}
figure {{ margin:0; display:grid; gap:4px; }} figure img {{ width:100%; height:auto; border-radius:3px; display:block; }}
figcaption {{ font-size:13px; color:var(--dim); }} figcaption b {{ color:var(--fg); font-weight:600; }}
.choices {{ display:flex; flex-wrap:wrap; gap:8px; align-items:center; }}
button {{ font:600 14px "IBM Plex Sans", sans-serif; color:var(--fg); background:transparent; border:1px solid var(--line);
  border-radius:4px; padding:8px 14px; cursor:pointer; min-height:40px; }}
button:hover {{ border-color:var(--teal); }} button:focus-visible, textarea:focus-visible {{ outline:2px solid var(--teal); outline-offset:2px; }}
button[aria-pressed="true"] {{ background:var(--chosen); border-color:var(--teal); color:#fff; }}
button:disabled {{ opacity:.45; cursor:default; }}
.saved {{ font-size:12px; color:var(--dim); }}
.words {{ display:grid; gap:4px; font-size:12px; color:var(--dim); }}
textarea {{ font:14px "IBM Plex Sans", sans-serif; color:var(--fg); background:var(--bg); border:1px solid var(--line); border-radius:4px; padding:8px; resize:vertical; }}
.question {{ border-color:var(--amber); }} .question h3 {{ color:var(--amber); }}
.big {{ font:700 44px/1 "Barlow Condensed", sans-serif; color:var(--amber); font-variant-numeric:tabular-nums; }}
details.steps {{ background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:10px 12px; }}
details.steps summary {{ cursor:pointer; font-weight:600; }}
.hint {{ color:var(--dim); font-size:13px; margin:8px 0; }}
.strip {{ display:grid; grid-auto-flow:column; grid-auto-columns:minmax(280px, 1fr); gap:10px; overflow-x:auto; padding-bottom:6px; }}
.step {{ align-content:start; }}
.tablewrap {{ overflow-x:auto; }} table {{ border-collapse:collapse; font-variant-numeric:tabular-nums; min-width:560px; }}
th, td {{ text-align:left; padding:6px 14px 6px 0; border-bottom:1px solid var(--line); }} th {{ color:var(--dim); font-weight:600; font-size:13px; }}
.offline {{ color:var(--amber); font-size:13px; }}
@media (max-width:760px) {{ .frames.three, .frames.two {{ grid-template-columns:1fr; }} h1 {{ font-size:32px; }} }}
@media (prefers-reduced-motion: reduce) {{ * {{ scroll-behavior:auto; }} }}
</style>
<main>
<header>
  <h1>Canal Water Review</h1>
  <p class="lede">You said the Crossing's river and the Locks' canal <q>read black and should read wet</q>. Every frame is at your
  pose (21°, FOV 35, 49 m back). The water now reflects what is really around it: the city blocks, the wall's neon, the
  stands, and the lamps as columns of light on a slow swell. Your taps are saved as you make them.</p>
  <p class="meta">frames: builder0, {commit} · pairs frozen at one instant of the swell</p>
  <p class="offline" id="offline" hidden>Taps can't be saved in this view. Open the page on claude.ai while signed in.</p>
</header>

<article class="card question"><h3>First: have you driven the Locks yet?</h3>{driven}{driven_words}</article>

<article class="card question"><h3>Overall: does the water read wet now?</h3>{overall}{overall_words}</article>

{sections}

<section id="pits"><h2>Pits stay pits</h2>
<p class="note">Pits now have their own shader, so nothing from the water's new look can reach them. Each frame is round 10
beside now, at the same instant.</p>{pits}</section>

<section id="locks-question"><h2>The Locks' open canal</h2>
<article class="card question"><h3>Is the open canal the kill zone you want, or does it need cover on the quays?</h3>
<p><span class="big">{exposure}</span> of the field is visible from the centre of the Locks. The canal is open across its
water by design: the short way over is watched, the flanks are not. It ships open until you say otherwise.</p>
{locks}{locks_words}</article></section>

<section id="numbers"><h2>The numbers</h2>
<p class="note">The share of water pixels darker than 0.03 luma (what "reads black" means as a number), and their mean
luma, at each spot, round 10 against now. Same frame, same instant.</p>
<div class="tablewrap"><table><thead><tr><th>Map</th><th>Spot</th><th>Near-black, round 10</th><th>Near-black, now</th>
<th>Mean luma, round 10</th><th>Mean luma, now</th></tr></thead><tbody>{table}</tbody></table></div>{perf}
</section>
</main>
<script>
(async () => {{
  const groups = [...document.querySelectorAll(".choices")];
  const state = {{}};
  const render = () => {{
    for (const g of groups) {{
      const doc = state[g.dataset.id];
      for (const b of g.querySelectorAll("button")) b.setAttribute("aria-pressed", String(!!doc && doc.decision === b.dataset.choice));
      g.querySelector(".saved").textContent = doc ? "saved" : "";
    }}
    for (const t of document.querySelectorAll("textarea[data-words]")) {{
      const doc = state[t.dataset.words];
      if (doc && typeof doc.words === "string" && document.activeElement !== t) t.value = doc.words;
    }}
  }};
  let db = null;
  try {{ db = await window.claude?.use?.("db"); }} catch (e) {{ db = null; }}
  if (!db) {{
    document.getElementById("offline").hidden = false;
    for (const b of document.querySelectorAll("button[data-choice]")) b.disabled = true;
    return;
  }}
  db.collection("decisions").onSnapshot(snap => {{
    for (const d of snap.docs) state[d.id] = d.data();
    render();
  }});
  const save = async (id, patch) => {{
    const words = document.querySelector(`textarea[data-words="${{id}}"]`)?.value ?? "";
    const next = {{ ...(state[id] || {{}}), words, ...patch, at: new Date().toISOString() }};
    state[id] = next;
    render();
    try {{ await db.doc("decisions/" + id).set(next); }}
    catch (e) {{
      const g = document.querySelector(`.choices[data-id="${{id}}"] .saved`);
      if (g) g.textContent = e && e.code === "invalid_argument" ? "you can view but not answer on this page" : "not saved, try again";
    }}
  }};
  for (const g of groups) g.addEventListener("click", e => {{
    const b = e.target.closest("button[data-choice]");
    if (b) save(g.dataset.id, {{ decision: b.dataset.choice }});
  }});
  for (const t of document.querySelectorAll("textarea[data-words]")) t.addEventListener("change", () => {{
    const id = t.dataset.words;
    if (state[id]?.decision) save(id, {{}});
  }});
}})();
</script>
"""

if __name__ == "__main__":
    main()
