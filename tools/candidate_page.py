#!/usr/bin/env python3
"""Round 18 (maps, M7): the lead's page for the candidate maps -- one card per map: frames at his pose, the top-down
plot, the M2 numbers in plain words against the maps he has played, the command to play it, and KEEP / CUT / notes
saved to the page's `db` (collection `verdicts`, one doc per map; `meta/read` says when Claude last read them, C15.2).

Usage: python3 tools/candidate_page.py --room build/arenas/room.json --frames build/container-frames \
           --plots build/arenas --out build/candidate-page [--commit <sha>]
Writes <out>/index.html and copies the images beside it (publish with the Artifact tool, `files`).
"""
from __future__ import annotations

import argparse
import html
import json
import os
import shutil
import sys

## What he has played, for comparison (laptop, `tools/arena_room.py` at round 18's first commits; the Status table).
REFERENCE = {"line_kept": "7–8%", "line_open_cut": "88%", "centre_kept": "18–33%", "centre_cut": "40–64%"}

## Frame captions, per map and spot (the spot keys are `CF_SPOTS_<map>` in mk/arena.mk).
SPOT_WORDS = {"opening": "Where the match starts you", "skirmish": "A match under way, from your camera",
              "parade": {"floor": "The open floor", "west_bay": "A bay of walls", "west_neck": "The neck on the way round"},
              "gorge": {"west_neck": "A causeway down into the valley", "valley": "The valley", "road_round": "The road round"},
              "archipelago": {"centre_island": "The centre island", "forward_island": "A forward island",
                              "the_open": "Open ground between islands"},
              "cut": {"trench": "The trench", "the_band": "The open band", "blocks": "The blocks"},
              "yard_open": {"the_band": "The band down the middle", "west_stacks": "The alleys beside it"},
              "docks": {"the_apron": "The open apron", "east_bridge": "Your bridge over the basin",
                        "warehouses": "Your warehouses"}}


def caption(name, key):
    return SPOT_WORDS.get(name, {}).get(key) or SPOT_WORDS.get(key) or key.replace("_", " ").capitalize()


## What he will be able to DO on each map, in his terms (the orchestrator, 16:5x PDT: describe the play, not the build).
DO = {
    "parade": "March a whole squad line abreast across 112 m of open floor, and get shot down the length of that line "
              "by a squad waiting in the bay of container walls on either side. Or post your own squad in a bay, "
              "facing out at right angles to their advance, and do it to them. The slow way is round the back of a "
              "bay, past a neck.",
    "gorge": "Fight for two narrow causeways down into a wide valley, or take the long road round the ends of the drops "
             "and come out on the valley's flank. Once in the valley there is room to spread out.",
    "archipelago": "Hop from island to island of cover across open ground. Screen the open gaps while the rest of the "
                   "squad crosses; the forward islands are what you fight over.",
    "cut": "Use the long open band for big formations, or cross it under cover in the concrete trench across its "
           "middle. The blocks at either end are close-quarters ground.",
    "yard_open": "This is your Container Yard with the middle opened up: its two middle walls of containers are gone, "
                 "leaving a band 100 m wide where a squad can move line abreast, with the yard's alleys still on both "
                 "sides to ambush from. It sits beside the original, which does not change. If you keep it, say in "
                 "your notes whether it should replace the original or join it.",
    "docks": "Each side has warehouses on its left and a basin with one bridge on its right. Rush the bridge, cross the "
             "open apron, or grind through the warehouses to the prize in theirs.",
}


## Long hulls scraping containers, per minute of fight (median over 4 seeds; `container-contacts CC_TURNED_ONLY=1`,
## builder0, tree synced 18:07:48 PDT 2026-10-04 = parade v3; the dealt yard in the same run: 794). yard_open was not
## in that run.
SCRAPES = {"parade": 215, "docks": 184, "archipelago": 102, "gorge": 72, "cut": 26}
YARD_SCRAPES = 794


## Formations seated by the game itself (picker's "fits here" badge on the order path a player's move uses; a squad of
## two War Rigs and two IFV-class hulls; parade v3 at 9475c06d, builder0, read 2026-10-04 evening).
FORMATIONS = {"parade": "Measured with the game's own seating: in the middle, every formation fits, Line included; and in "
                        "the bay on either side, a line of four stands between its two walls facing out over the floor. "
                        "That is the ambush you described, at right angles to a line crossing."}


## How the computer played each map (series 2: CPU v CPU, brains alone on both sides, 8 seeds x swapped bases,
## builder0, tree 0901ab64, 2026-10-04 20:30 PDT; medians over 16 matches). crossed = vehicles that got 20 m past the
## middle line toward the other base; open = time inside the map's declared open ground.
CPU_PLAY = {"parade": (0.31, 0.41), "gorge": (0.36, 0.13), "archipelago": (0.37, 0.07), "cut": (0.39, 0.25),
            "docks": (0.35, 0.12), "yard_open": (0.35, 0.12)}
OPEN_WORDS = {"parade": "the open floor", "gorge": "the valley", "archipelago": "the open ground between islands",
              "cut": "the open band", "docks": "the apron", "yard_open": "the band down the middle"}


## Brains' lane-deadlock witness (its commit f4daada0 = the D4+D5 fix on f6c6a282, laptop, 2026-10-04 evening): a squad
## of four Law tanks sent 150 m forward from the green spawn on an attack-move (a TASK, so it can be squeezed into file),
## seeds 1-4, 180 s. (arrived of 4, median seconds). The Sumps, a dealt map, for scale: 4/4 in 39.8 s with the fix,
## 0 of 8 before it. Shown only with --with-witness: the fix is not on main until brains' CP1 merges.
WITNESS = {"parade": (4, 14.1), "yard_open": (4, 13.8), "archipelago": (4, 15.3), "docks": (4, 21.1),
           "gorge": (4, 35.0), "cut": (3, 46.1)}


def pct(v):
    return "%d%%" % round(100 * v)


SHOW_WITNESS = False


def words(m):
    r = m["room"]
    a = m["ambush"]
    chokes = m["chokepoints"]
    necks = sorted({(round(c["width_m"]), c["way_round"]) for c in chokes if c["width_m"] < 20})
    best_axis = max(a, key=lambda k: a[k]["hulls"])
    axis_words = {"base_to_base": "base to base", "diagonal_ne": "on a diagonal", "diagonal_nw": "on a diagonal",
                  "side_to_side": "side to side"}
    lines = [
        ("Room", "A line of four at its own spacing can drive through %s of the field (the corridor maps you play: %s; "
                 "Foundry, which you cut: %s). The widest line the field takes: %d vehicles abreast."
         % (pct(r["line_share"]), REFERENCE["line_kept"], REFERENCE["line_open_cut"], r["abreast_at_spacing"])),
        ("Open, with ambush ground", "From the middle you can see %s of the field. The last maps this open (40–64%%) "
                   "you cut, and they had nowhere to hide; the maps you kept see %s. What is new here: a line of four "
                   "crossing the middle %s can be shot down its length from cover it could not see when it set off, "
                   "with room there for %d hidden vehicles (%d in the best spot%s)."
         % (pct(m.get("centre_sees_share", 0)), REFERENCE["centre_kept"], axis_words[best_axis],
            a[best_axis]["hulls"], a[best_axis]["best"],
            "" if best_axis == "base_to_base" else "; crossing base to base: %d" % a["base_to_base"]["hulls"])),
        *([("Formations", FORMATIONS[m["name"]])] if m["name"] in FORMATIONS else []),
        *([("The computer, playing it", "In computer-against-computer matches about %s of the vehicles pushed past "
                    "the middle, and they spent %s of their time on %s. Neither base won more by being on its side."
                    % (pct(CPU_PLAY[m["name"]][0]), pct(CPU_PLAY[m["name"]][1]), OPEN_WORDS[m["name"]]))]
          if m["name"] in CPU_PLAY else []),
        *([("A squad on the move", "Four tanks sent 150 m forward on an attack-move %s. On the Sumps they take "
                    "about 40 s, and before tonight's fix to how squads hold formation in a tight lane they never got "
                    "there at all. (4 test runs on the laptop.)"
                    % ("got there in about %d s" % round(WITNESS[m["name"]][1]) if WITNESS[m["name"]][0] == 4 else
                       "got there in about %d s in 3 of 4 runs; in the fourth the squad stopped short at one spot "
                       "beside a block wall, which is a driving fault being worked on, not a narrow place in the map"
                       % round(WITNESS[m["name"]][1])))]
          if SHOW_WITNESS and m["name"] in WITNESS else []),
        ("Scraping", ("Long vehicles scrape containers about %d times a minute here; on the Container Yard you play, %d."
                      % (SCRAPES[m["name"]], YARD_SCRAPES)) if m["name"] in SCRAPES else
                     "Not measured yet on this one (the Container Yard you play: %d scrapes a minute)." % YARD_SCRAPES),
        ("Chokepoints", ("%d narrow places on the main routes, the tightest %d m of drivable width; %s."
                         % (len(chokes), min(round(c["width_m"]) for c in chokes),
                            "every one has a way round" if all(c["way_round"] for c in chokes) else
                            "%d of them have a way round" % sum(1 for c in chokes if c["way_round"])) if chokes else
                         "None on the main routes: the ways across are open.")
         + (" Necks under 20 m: %s." % ", ".join("%d m" % w for w, _ in necks) if necks else "")),
    ]
    return lines


def card(m, layout, frames, plot):
    name = m["name"]
    title = html.escape(layout.get("title", name))
    figs = "".join(
        '<figure><img src="%s" alt="%s at %s" loading="lazy"><figcaption>%s</figcaption></figure>'
        % (html.escape(f), title, html.escape(caption(name, k).lower()), html.escape(caption(name, k)))
        for k, f in frames)
    facts = "".join("<div class=fact><dt>%s</dt><dd>%s</dd></div>" % (html.escape(k), html.escape(v)) for k, v in words(m))
    cmd = "make skirmish ARENA=%s" % name
    return f'''<article class=map id="{name}" data-map="{name}">
<header class=map-head><h2>{title}</h2><span class=tag>{name}</span></header>
<p class=do>{html.escape(DO.get(name, layout.get("note", "")))}</p>
<div class=frames>{figs}</div>
<div class=body>
<figure class=plot><img src="{html.escape(plot)}" alt="{title} from above" loading="lazy"><figcaption>From above, north (the CPU's side) at the top. Green: a line of four fits. Circles: chokepoints. Triangles: hidden ground that shoots down a crossing line. Stars: the objectives.</figcaption></figure>
<dl class=facts>{facts}</dl>
</div>
<div class=play><code id="cmd-{name}">{cmd}</code><button type=button class=copy data-cmd="{cmd}">Copy</button></div>
<form class=verdict data-map="{name}">
<fieldset><legend>After you play it</legend>
<div class=choices role=radiogroup aria-label="Your call on {title}">
<label><input type=radio name="v-{name}" id="keep-{name}" value="KEEP"><span>Keep</span></label>
<label><input type=radio name="v-{name}" id="cut-{name}" value="CUT"><span>Cut</span></label>
<label><input type=radio name="v-{name}" id="again-{name}" value="AGAIN"><span>Play it again first</span></label>
</div>
<label class=notes-label for="notes-{name}">What you noticed</label>
<textarea id="notes-{name}" rows=3 placeholder="Optional: what worked, what didn't, what to change"></textarea>
<div class=save-row><button type=submit class=save>Save</button><span class=status aria-live=polite></span></div>
</fieldset>
</form>
</article>'''


PAGE = '''<title>Candidate Maps</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;700&family=IBM+Plex+Sans:wght@400;500&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: one column of map cards, each a frame strip over plot + plain-word numbers, the verdict at its foot. */
:root{
  --bg:#f3f4f2;--panel:#ffffff;--ink:#1b2027;--muted:#5b6370;--line:#d9dcd8;--accent:#c4621b;--accent-ink:#ffffff;--ok:#2f7d4f;--cut:#a23838;
  --display:"Chakra Petch",ui-sans-serif,system-ui,sans-serif;--body:"IBM Plex Sans",ui-sans-serif,system-ui,sans-serif;--mono:"IBM Plex Mono",ui-monospace,monospace;
}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#14171c;--panel:#1c2027;--ink:#e7e9ec;--muted:#9aa2ad;--line:#2d333c;--accent:#e98a3f;--accent-ink:#14171c;--ok:#5fbf86;--cut:#e07a7a;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#14171c;--panel:#1c2027;--ink:#e7e9ec;--muted:#9aa2ad;--line:#2d333c;--accent:#e98a3f;--accent-ink:#14171c;--ok:#5fbf86;--cut:#e07a7a;color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:15px/1.55 var(--body);padding-inline:16px;padding-block:24px 48px}
main{max-width:1120px;margin:0 auto;display:grid;gap:40px}
.intro h1{font:700 2rem/1.15 var(--display);letter-spacing:.01em;margin:0 0 8px;text-wrap:balance}
.intro p{margin:0 0 8px;max-width:68ch;color:var(--muted)}
.intro .read{font:13px var(--mono);color:var(--muted)}
.map{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:20px;display:grid;gap:16px;min-width:0}
.map-head{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap}
.map-head h2{font:700 1.5rem/1.2 var(--display);margin:0}
.tag{font:12px var(--mono);color:var(--muted);letter-spacing:.06em;text-transform:uppercase}
.do{margin:0;max-width:72ch;font-size:1.05rem}
.frames{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px}
figure{margin:0;min-width:0}
figure img{display:block;width:100%;border-radius:3px;border:1px solid var(--line)}
figcaption{font-size:12.5px;color:var(--muted);margin-top:4px}
.body{display:grid;grid-template-columns:minmax(0,5fr) minmax(0,6fr);gap:20px;align-items:start}
@media (max-width:760px){.body{grid-template-columns:1fr}}
.facts{margin:0;display:grid;gap:12px}
.fact dt{font:500 12px var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--accent)}
.fact dd{margin:2px 0 0}
.play{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.play code{font:14px var(--mono);background:var(--bg);border:1px solid var(--line);border-radius:3px;padding:6px 10px;overflow-x:auto;max-width:100%}
button{font:500 14px var(--body);border-radius:3px;border:1px solid var(--line);background:var(--panel);color:var(--ink);padding:6px 14px;cursor:pointer}
button:focus-visible,input:focus-visible+span,textarea:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.save{background:var(--accent);color:var(--accent-ink);border-color:var(--accent)}
.save:disabled{opacity:.5;cursor:default}
fieldset{border:1px solid var(--line);border-radius:4px;margin:0;padding:12px 14px;display:grid;gap:10px}
legend{font:500 12px var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--muted);padding:0 6px}
.choices{display:flex;gap:8px;flex-wrap:wrap}
.choices label{cursor:pointer}
.choices input{position:absolute;opacity:0;pointer-events:none}
.choices span{display:inline-block;border:1px solid var(--line);border-radius:3px;padding:6px 14px;font-weight:500}
.choices input[value=KEEP]:checked+span{background:var(--ok);border-color:var(--ok);color:var(--panel)}
.choices input[value=CUT]:checked+span{background:var(--cut);border-color:var(--cut);color:var(--panel)}
.choices input[value=AGAIN]:checked+span{background:var(--ink);border-color:var(--ink);color:var(--panel)}
.notes-label{font-size:13px;color:var(--muted)}
textarea{font:14px var(--body);background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:3px;padding:8px;width:100%;box-sizing:border-box;resize:vertical}
.save-row{display:flex;gap:12px;align-items:center;flex-wrap:wrap}
.status{font-size:13px;color:var(--muted)}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
<main>
<section class=intro>
<h1>Candidate maps</h1>
<p>New maps built for room to manoeuvre: open ground for big formations, a few chokepoints, and cover a line abreast can be ambushed from. None of them is dealt by the random pick; play each one by name with the command on its card, then make your call. Your call is saved on this page, and Claude reads it.</p>
<p>The numbers on each card are measured from the map itself before anyone played it, and compared with maps you already know.</p>
<p class=read id=read-line>Version 3, built at __COMMIT__.</p>
</section>
__CARDS__
</main>
<script>
(function(){
  document.querySelectorAll('.copy').forEach(function(b){
    b.addEventListener('click',function(){
      var t=b.getAttribute('data-cmd');
      var done=function(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy'},1500)};
      try{navigator.clipboard.writeText(t).then(done,function(){sel(b)})}catch(e){sel(b)}
    });
  });
  function sel(b){var c=b.previousElementSibling;var r=document.createRange();r.selectNodeContents(c);var s=getSelection();s.removeAllRanges();s.addRange(r);b.textContent='Selected: copy it'}
  var forms=[].slice.call(document.querySelectorAll('form.verdict'));
  forms.forEach(function(f){f.addEventListener('submit',function(e){e.preventDefault()})});
  function setStatus(f,t){f.querySelector('.status').textContent=t}
  forms.forEach(function(f){setStatus(f,'Connecting to the page store…')});
  if(!window.claude||!window.claude.use){forms.forEach(function(f){setStatus(f,'Saving works when this page is opened on claude.ai.');f.querySelector('.save').disabled=true});return}
  Promise.all([claude.use('db'),claude.use('user')]).then(function(r){
    var db=r[0],user=r[1];
    if(!db){forms.forEach(function(f){setStatus(f,'Sign in on claude.ai to save your call.');f.querySelector('.save').disabled=true});return}
    db.doc('meta/read').get().then(function(d){
      var el=document.getElementById('read-line');
      var v=d&&(d.data?d.data():d);
      if(v&&v.read_at){el.textContent=el.textContent+' Claude last read your answers: '+v.read_at+'.'}
      else{el.textContent=el.textContent+' Claude has not read any answers yet.'}
    }).catch(function(){});
    forms.forEach(function(f){
      var map=f.getAttribute('data-map');
      var ref=db.doc('verdicts/'+map);
      ref.get().then(function(d){
        var v=d&&(d.data?d.data():d);
        if(v&&v.verdict){var i=f.querySelector('input[value='+v.verdict+']');if(i)i.checked=true}
        if(v&&v.notes)f.querySelector('textarea').value=v.notes;
        var words={KEEP:'Keep',CUT:'Cut',AGAIN:'Play it again first'};
        setStatus(f,v&&v.at?('Saved: '+(words[v.verdict]||v.verdict)+', '+new Date(v.at).toLocaleString()+'. Change it any time.'):'Not decided yet.');
      }).catch(function(){setStatus(f,'Not decided yet.')});
      f.addEventListener('submit',function(){
        var c=f.querySelector('input[type=radio]:checked');
        if(!c){setStatus(f,'Pick Keep, Cut or Play it again first, then save.');return}
        var btn=f.querySelector('.save');btn.disabled=true;setStatus(f,'Saving…');
        var who=user&&user.id?user.id():Promise.resolve('');
        Promise.resolve(who).then(function(id){
          return ref.set({map:map,verdict:c.value,notes:f.querySelector('textarea').value.slice(0,4000),at:new Date().toISOString(),by:id||''});
        }).then(function(){setStatus(f,'Saved: '+c.parentNode.textContent.trim()+', '+new Date().toLocaleString()+'. Change it any time.')},function(err){setStatus(f,'Not saved: '+((err&&err.message)||'the store refused it')+'. Try again.')})
          .then(function(){btn.disabled=false});
      });
    });
  });
})();
</script>
'''


def shrink(src, dst, box=(1280, 720)):
    """Copy an image at most `box` pixels (his laptop loads the page; 1080p frames made it 8.7 MB)."""
    try:
        from PIL import Image
    except ImportError:
        shutil.copy(src, dst)
        return
    im = Image.open(src)
    im.thumbnail(box)
    if dst.endswith(".jpg"):
        im.convert("RGB").save(dst, quality=80)
    else:
        im.save(dst, optimize=True)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--room", required=True)
    p.add_argument("--frames", required=True)
    p.add_argument("--plots", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--commit", default="?")
    p.add_argument("--shots", help="build/screenshots: arena-<map>-skirmish.png from make arena-shots leads each card")
    p.add_argument("--with-witness", action="store_true", help="add brains' squad-on-the-move line (once its fix is on main)")
    p.add_argument("--maps", default="parade,gorge,archipelago,cut,docks,yard_open")
    args = p.parse_args(argv)
    global SHOW_WITNESS
    SHOW_WITNESS = args.with_witness
    rows = {r["name"]: r for r in json.load(open(args.room))}
    os.makedirs(args.out, exist_ok=True)
    cards = []
    for name in args.maps.split(","):
        layout = json.load(open(os.path.join("arenas", name + ".json")))
        # Only the frames the map's LATEST run wrote (its manifest): a copy-back mirrors builder0's build/, so a frame
        # from an earlier version of the map (the Parade Ground's ladder) survives beside the new ones by name.
        meta = json.load(open(os.path.join(args.frames, "%s_after.json" % name)))
        frames = []
        shot = os.path.join(args.shots, "arena-%s-skirmish.png" % name) if args.shots else ""
        for entry in meta.get("frames", []):
            if entry["key"] == "your_base":
                continue  # tried (round 18): at 4 s the armies are not on the field and the camera sits behind the stands
            if entry["key"] == "opening" and shot and os.path.exists(shot):
                continue  # the match's opening camera shows floor and a ring; the skirmish shot below shows the fight
            shrink(os.path.join(args.frames, entry["file"]), os.path.join(args.out, entry["file"]))
            frames.append((entry["key"], entry["file"]))
        if shot and os.path.exists(shot):
            out = "%s_skirmish.jpg" % name
            shrink(shot, os.path.join(args.out, out))
            frames.insert(0, ("skirmish", out))
        plot = "room-%s.png" % name
        shrink(os.path.join(args.plots, plot), os.path.join(args.out, plot), (700, 700))
        cards.append(card(rows[name], layout, frames, plot))
        print("CANDIDATE_PAGE %s frames=%d" % (name, len(frames)))
    page = PAGE.replace("__CARDS__", "\n".join(cards)).replace("__COMMIT__", html.escape(args.commit))
    with open(os.path.join(args.out, "index.html"), "w") as f:
        f.write(page)
    print("CANDIDATE_PAGE_DONE %s" % os.path.join(args.out, "index.html"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
