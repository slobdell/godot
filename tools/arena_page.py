#!/usr/bin/env python3
"""The arena review page for the lead (arena X5, round 6): every shipping arena, as a picture and as what it
measures, and for each one the only question that needs an answer: **keep it, fix it, or cut it?**

    make arena-shots ARENAS=...        # the pictures (needs a display: make remote T=arena-shots)
    make arena-report                  # build/arenas/report.json, the measurements
    make arena-page                    # build/arena-page/index.html

It exists because "which arena is fun" has been open since round 5 and the lead has still never played them
(_agents/arenas.md, his round-5 sign-off: "Not played yet"). He cannot answer from a list of names, and he should
not have to read a JSON blob to find out that one map's centre sees 64% of the field. So: one card per arena, the
picture first, the numbers in plain language under it, and the maps this stream thinks are the problem called out
rather than buried in a ranking.

Round 6 lesson 12 is the reason this is a single self-contained file with the images inlined: round 3's three
review pages sat unseen for a day because nobody could open them. This one is one file that can be sent anywhere.
"""

import argparse
import base64
import html
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
## Arenas the lead can actually be given. Fixtures (the maze) are not offered: they are not maps.
SHOT = "build/screenshots/arena-%s-%s.png"
PLAN = "build/arenas/%s.png"
## Width the screenshots are served at. The originals are 1920x1080 PNGs of 4-5 MB each; eight of those is 35 MB
## and no use to anyone on a phone.
IMAGE_WIDTH = 1280
IMAGE_QUALITY = 82


def shrink(path, width=IMAGE_WIDTH):
    """A data: URI of the screenshot, downscaled to `width`, so the page is one file that can be sent anywhere."""
    try:
        from PIL import Image
    except ImportError:
        return None
    if not path.exists():
        return None
    image = Image.open(path).convert("RGB")
    if image.width > width:
        image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, "JPEG", quality=IMAGE_QUALITY, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buffer.getvalue()).decode()


def read(report, name):
    for entry in report:
        if entry["name"] == name:
            return entry
    return None


def plain_english(entry):
    """What the numbers mean, in the terms the lead used. He said the game reads as 'one big open brawl' and that he
    wants to set up ambushes and flank -- so every line here answers one of those, or it does not belong."""
    a = entry["ambush"]
    routes = {r["route"]: r for r in a["approach_routes"]}
    direct = routes.get("direct", {})
    covered = routes.get("covered", {})
    centre = a["centre_sees_share"]
    best = a["overwatch"][0] if a["overwatch"] else {}
    lines = []
    if centre >= 0.5:
        lines.append(("bad", "Standing in the middle you can see <b>%d%%</b> of the battlefield. "
                             "Very little can be set up out of sight." % round(centre * 100)))
    elif centre >= 0.3:
        lines.append(("mixed", "The middle sees <b>%d%%</b> of the battlefield — some of the map is hidden from it."
                      % round(centre * 100)))
    else:
        lines.append(("good", "The middle only sees <b>%d%%</b> of the battlefield. There is plenty of room to move "
                              "unseen." % round(centre * 100)))
    detour = a.get("flank_detour")
    if detour is not None and direct and covered:
        cost = "costs almost nothing" if detour <= 1.15 else (
            "costs a %d%% longer drive" % round((detour - 1) * 100))
        lines.append(("good" if detour <= 1.15 else "mixed",
                      "Taking the covered way round instead of straight across %s." % cost))
    gain = direct.get("posting_gain")
    if gain is not None:
        if gain >= 0.09:
            lines.append(("good", "Posting a squad to watch a lane really pays here — it roughly doubles how much "
                                  "of the crossing the defender covers."))
        elif gain <= 0.03:
            lines.append(("mixed", "Posting a squad to watch a lane buys very little: the cover is so broken that "
                                   "the extra reach does not see anything."))
        else:
            lines.append(("mixed", "Posting a squad to watch a lane is worth something, but not decisive."))
    if best:
        hidden = best.get("hidden_approach")
        if hidden is not None and hidden <= 0.15:
            lines.append(("bad", "The best firing position on the map can only be sneaked up on from <b>%d%%</b> of "
                                 "directions — whoever takes it is very hard to shift." % round(hidden * 100)))
        elif hidden is not None and hidden >= 0.35:
            lines.append(("good", "The best firing position can be sneaked up on from <b>%d%%</b> of directions, so "
                                  "holding it is a choice, not a lock." % round(hidden * 100)))
    lines.append(("plain", "Longest clear line of sight: <b>%d m</b>. Cover pieces: <b>%d</b>."
                  % (round(entry["longest_sightline_m"]), entry["features"])))
    return lines


## A verdict and a STATED CONSEQUENCE per arena, not a ranking. The lead answers a concrete choice far better than
## an open one -- he has twice taken the floor of a range we offered rather than pick from it -- so each card says
## what this stream thinks is wrong and asks keep / fix / cut. Disagreeing with a diagnosis is easier than inventing
## one, and "cut it" is a real answer we would act on.
VERDICTS = {
    "boulevard": ("Its middle sees 64% of the battlefield and the best firing position on it can only be approached "
                  "unseen from 12% of directions: it dominates the map and cannot be flanked back. Every fight here "
                  "funnels to the centre. This is the one we would change first.", "bad"),
    # One card, because they are the same map with different hazards. Two near-identical cards would cost a
    # judgement and tell him nothing; saying they are twins is itself the useful fact.
    "foundry": ("Round 1's arena, and still the default for every headless test. One spot beside the centre crate "
                "can see the whole crossing, so whoever holds the middle has already won the ground. "
                "<b>The Furnace is this same map with burning pits added</b> — a verdict on one is probably a "
                "verdict on both, unless you want to split them.", "bad"),
    "boneyard": ("Wrecks and tipped containers at odd angles. Middling on every measure, and no two fights in it "
                 "look the same.", "mixed"),
    "pit": ("A walled ring around the middle with four gates. The gates are the map: hold one and you own an "
            "approach.", "mixed"),
    "scrapyard": ("Round 2's dense layout. Long walls cut it into lanes and fights happen at the corners.", "mixed"),
    "yard": ("Container walls base to base. The least exposed crossing in the game and the only map where going "
             "round costs almost nothing — but so broken up that posting a squad to watch a lane buys little.", "good"),
}

CSS = """
:root { color-scheme: dark; --bg:#11131a; --card:#1a1d27; --line:#2b3040; --ink:#e8eaf2; --dim:#9aa1b8;
        --good:#4ec9a0; --mixed:#d8b45a; --bad:#e2685f; }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.55 system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }
.wrap { max-width:1100px; margin:0 auto; padding:24px 16px 64px; }
h1 { font-size:1.6rem; margin:0 0 6px; letter-spacing:-.01em; }
.sub { color:var(--dim); margin:0 0 28px; }
.ask { background:var(--card); border:1px solid var(--line); border-left:3px solid var(--good);
       border-radius:10px; padding:16px 18px; margin:0 0 32px; }
.ask b { color:var(--good); }
.warn { background:rgba(226,104,95,.08); border:1px solid rgba(226,104,95,.35); border-radius:10px;
        padding:14px 18px; margin:0 0 16px; }
.warn b { color:var(--bad); }
.card { background:var(--card); border:1px solid var(--line); border-radius:12px; overflow:hidden; margin:0 0 28px; }
.card > img { width:100%; display:block; background:#000; }
.plan { padding:16px 18px 0; }
.plan img { width:100%; max-width:560px; display:block; margin:0 auto; border-radius:8px; background:#fff; }
.plan p { color:var(--dim); font-size:.88rem; max-width:560px; margin:8px auto 0; }
.body { padding:16px 18px 18px; }
.name { font-size:1.25rem; font-weight:650; margin:0 0 2px; }
.tag { display:inline-block; font-size:.72rem; letter-spacing:.08em; text-transform:uppercase;
       padding:2px 8px; border-radius:999px; vertical-align:3px; margin-left:8px; }
.tag.good { background:rgba(78,201,160,.15); color:var(--good); }
.tag.mixed { background:rgba(216,180,90,.15); color:var(--mixed); }
.tag.bad { background:rgba(226,104,95,.15); color:var(--bad); }
.verdict { color:var(--dim); margin:6px 0 14px; }
ul { list-style:none; padding:0; margin:0; }
li { padding:5px 0 5px 20px; position:relative; }
li::before { content:"●"; position:absolute; left:0; font-size:.7em; top:.65em; }
li.good::before { color:var(--good); } li.mixed::before { color:var(--mixed); }
li.bad::before { color:var(--bad); } li.plain::before { color:var(--dim); }
li.plain { color:var(--dim); }
.q { margin:14px 0 0; padding-top:12px; border-top:1px solid var(--line); font-weight:600; }
footer { color:var(--dim); font-size:.9rem; border-top:1px solid var(--line); padding-top:18px; margin-top:8px; }
code { background:#0d0f15; padding:1px 5px; border-radius:4px; font-size:.9em; }
@media (max-width:600px){ .wrap{padding-block:16px 48px; padding-inline:16px;} h1{font-size:1.35rem;} }
@media (prefers-reduced-motion:reduce){ *{animation:none!important;transition:none!important;} }
"""


## The page commits to one dark look on purpose: it is a page of screenshots of a night-time arena game, and a light
## ground would fight every image on it. So no light/dark token swap -- but every colour is declared explicitly on
## :root and the body paints its own background, so the page holds whatever ground it is composited over.
def render(report, order, shots, plans, fragment=False):
    cards = []
    for name in order:
        entry = read(report, name)
        if entry is None:
            continue
        verdict, tone = VERDICTS.get(name, ("", "mixed"))
        image = shots.get(name)
        plan = plans.get(name)
        picture = '<img src="%s" alt="%s in play">' % (image, html.escape(name)) if image else ""
        if plan:
            picture += ('<div class="plan"><img src="%s" alt="%s from above">'
                        '<p>Its plan from above. Orange is cover you cannot see or shoot through; the red line is '
                        'the longest clear shot on the map; the dotted boxes top and bottom are where each side '
                        'starts. Black is open ground.</p></div>' % (plan, html.escape(name)))
        bullets = "".join('<li class="%s">%s</li>' % (tone_, text) for tone_, text in plain_english(entry))
        cards.append(
            '<div class="card">%s<div class="body"><div class="name">%s<span class="tag %s">%s</span></div>'
            '<p class="verdict">%s</p><ul>%s</ul><p class="q">Keep it &nbsp;·&nbsp; Fix it &nbsp;·&nbsp; Cut it &nbsp;·&nbsp; I\'d rather just play it first</p></div></div>'
            % (picture, html.escape(entry.get("title", name.title())), tone,
               {"good": "worth keeping", "mixed": "middling", "bad": "too open"}[tone],
               html.escape(verdict), bullets))
    head = "" if fragment else ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
                                '<meta name="viewport" content="width=device-width,initial-scale=1">')
    tail = "" if fragment else "</body></html>"
    return """%s<title>Tank Squad Arenas</title><style>%s</style>%s<div class="wrap">
<h1>The seven arenas</h1>
<p class="sub">Each one as the match runner sees it, and what it measures. Round 6, arena stream.</p>
<div class="warn"><b>Nobody has played these.</b> Everything below is what the <i>shape</i> of each map measures —
sightlines and routes, with no match run. You are the only one who can say how any of them actually plays, which is
exactly what makes your answer worth more than the numbers.</div>
<div class="ask"><b>For each map: keep it, fix it, cut it — or say you would rather play it first.</b> One answer
each. <br><br>
&ldquo;Cut&rdquo; is a real answer we would act on: cutting a map is far cheaper than fixing one.
&ldquo;Play it first&rdquo; is equally real — you have never driven any of these, and if the honest answer is
&ldquo;I\'ll tell you after a match&rdquo;, say that rather than guess.<br><br>
Each card states what we think is wrong with it, so you can disagree with something concrete instead of ranking
seven pictures cold.<br><br>
The ones marked <b style="color:var(--bad)">too open</b> are the measured version of &ldquo;the game is just this
big open brawl&rdquo;: their middles see most of the battlefield, so there is nowhere to set up an ambush and
nothing a flank can take. <b>Boulevard is the worst, and it is first.</b></div>
%s
<footer>Pictures: <code>make arena-shots</code>, the match runner's own camera, 30 a side.
Measurements: <code>make arena-report</code> — static geometry, no match played.
&ldquo;Seen&rdquo; assumes a defender covers 45 m, which is what an ordinary crew manages on its own judgement;
a squad you <i>order</i> to watch a lane reaches further, so &ldquo;covered&rdquo; is never a guarantee.
The Furnace shares the Foundry's card — same shape, different hazards. The Maze is not here: it is a nav test
fixture, not a map.
</footer></div>%s""" % (head, CSS, "" if fragment else "</head><body>", "".join(cards), tail)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default="build/arenas/report.json")
    parser.add_argument("--out", default="build/arena-page/index.html")
    # The player's camera, not the match runner's. The match-runner overview prints every unit's name, health and
    # current AI decision over the terrain -- a developer view that buries the very thing this page asks about.
    parser.add_argument("--view", default="skirmish", choices=["overview", "skirmish"])
    parser.add_argument("--fragment", action="store_true",
                        help="omit the document wrapper (the Artifact platform supplies its own head/body)")
    args = parser.parse_args()
    report = json.loads((ROOT / args.report).read_text())
    # Worst first: the lead's time goes on the maps this stream is asking about, not on the ones that measure fine.
    # Worst first, and furnace folded into foundry's card (they are the same shape). Six judgements, not seven.
    order = [n for n in ("boulevard", "foundry", "boneyard", "pit", "scrapyard", "yard") if read(report, n)]
    shots, plans, missing = {}, {}, []
    for name in order:
        data = shrink(ROOT / (SHOT % (name, args.view)))
        if data:
            shots[name] = data
        else:
            missing.append(name)
        plan = shrink(ROOT / (PLAN % name), 900)
        if plan:
            plans[name] = plan
    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render(report, order, shots, plans, fragment=args.fragment))
    size = out.stat().st_size
    if missing:
        print("ARENA_PAGE_MISSING_SHOTS %s (run: make remote T=arena-shots)" % ",".join(missing))
    print("ARENA_PAGE %s (%d arenas, %.1f MB)" % (out, len(order), size / 1e6))


if __name__ == "__main__":
    main()
