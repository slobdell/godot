#!/usr/bin/env python3
"""S6 round 10, item 4: the lead's verdict page -- the Terminus with the show OFF (the "1990s game" he named) beside
the same frozen frame with the show ON, for every effect, plus the band-width strip and the clips.

Nothing goes to him without the before, so every picture here is a PAIR shot in one process at one frozen instant
(show_look.gd toggles Show.driving on a paused scene): the two halves differ in the light show and in nothing else.

    python3 tools/show_page.py [build]   ->  build/show-page/index.html (self-contained folder: copy it anywhere)
"""
import glob
import html
import json
import os
import shutil
import sys

build = sys.argv[1] if len(sys.argv) > 1 else "build"
out = os.path.join(build, "show-page")
shutil.rmtree(out, ignore_errors=True)
os.makedirs(os.path.join(out, "img"))

# What each frame is, in the lead's words rather than ours. Keyed by the label show_look.gd writes.
CAPTIONS = {
    "t8_1": ("Idle: the Vegas twinkle", "Every window on its own clock, flaring and fading at random (the patch's "
             "<code>pixels</code> channel). The art's own lit windows keep breathing underneath."),
    "cue_skirmish": ("Skirmish: a sweep across the facades", "A lit band 25 m wide travelling along every wall."),
    "cue_battle": ("Battle: a chase up every tower", "A pulse climbing each building, every block on its own beat."),
    "cue_last_stand": ("Last stand: the strobe on ONE facade", "Only the wall facing the losing side's base strobes "
                       "(a still catches it at one moment of the flash; the clip shows it)."),
    "cue_victory": ("Victory: a sweep in the winner's colour", "The one team-coloured thing in the venue."),
    "cue_fight": ("FIGHT: house lights down", "The moment the loading screen drops: windows dark, rim and towers up."),
    "cue_capture": ("Capture: the block fills floor by floor", "An objective changing hands lights the nearest "
                    "building from the street up, one storey every 0.18 s (caught mid-climb)."),
    "cue_kill_0_55s": ("A kill: the ripple crossing the windows", "The wavefront travelling outward from the kill "
                       "across the facades nearest it."),
}
ORDER = ["t8_1", "cue_skirmish", "cue_battle", "cue_capture", "cue_kill_0_55s", "cue_last_stand", "cue_victory",
         "cue_fight"]


def rows_in(folder):
    rows = []
    for log in sorted(glob.glob(os.path.join(folder, "*.log"))):
        for line in open(log, errors="ignore"):
            if line.startswith("SHOW_LOOK {"):
                rows.append(json.loads(line.split(" ", 1)[1]))
    return rows


def copy(src, name):
    if not os.path.exists(src):
        return None
    shutil.copy(src, os.path.join(out, "img", name))
    return "img/" + name


def delta(r):
    b = r["luma_ring_before"] / max(r["luma_band_before"], 1e-6)
    d = r["luma_ring"] / max(r["luma_band"], 1e-6)
    return (d - b) / b * 100.0


def pair_html(title, note, before, after, r):
    stats = ("fight-vs-venue ratio %+.1f%% with the show on (negative = the venue competes more); "
             "vehicles in frame %d; pitch %.0f&deg;%s; file <code>%s</code>"
             % (delta(r), r.get("vehicles_in_frame", 0), r.get("pitch_deg", 21),
                " (lifted to clear a roof)" if r.get("lifted_deg", 0) > 0.5 else "", html.escape(r["file"])))
    return f"""
<section>
  <h2>{title}</h2>
  <p class="note">{note}</p>
  <div class="pair">
    <figure><img src="{before}" loading="lazy"><figcaption>show OFF &mdash; the before</figcaption></figure>
    <figure><img src="{after}" loading="lazy"><figcaption>show ON</figcaption></figure>
  </div>
  <p class="stats">{stats}</p>
</section>"""


parts = []
show_dir = os.path.join(build, "show")
rows = [r for r in rows_in(show_dir) if r.get("pose") == "wide" and r.get("luma_band_before")]
by_label = {r["label"]: r for r in rows}
hero = by_label.get("cue_battle") or (rows[0] if rows else None)
for label in ORDER + sorted(set(by_label) - set(ORDER)):
    r = by_label.get(label)
    if r is None:
        continue
    title, note = CAPTIONS.get(label, (label.replace("_", " "), ""))
    before = copy(os.path.join(show_dir, "before", r["file"]), "before_" + r["file"])
    after = copy(os.path.join(show_dir, r["file"]), r["file"])
    if before and after:
        parts.append(pair_html(title, note, before, after, r))

bands = []
bands_dir = os.path.join(build, "show-bands")
for r in sorted(rows_in(bands_dir), key=lambda r: (r["label"].split("_band")[0], r.get("band", 1))):
    img = copy(os.path.join(bands_dir, r["file"]), "band_" + r["file"])
    if img:
        bands.append((r, img))
band_html = ""
if bands:
    first = bands[0][0]
    off = copy(os.path.join(bands_dir, "before", first["file"]), "band_off_" + first["file"])
    cells = "".join(
        f'<figure><img src="{img}" loading="lazy"><figcaption>{r["label"].replace("_", " ")} &mdash; '
        f'{r.get("band", 1):g}&times; ({delta(r):+.1f}%)</figcaption></figure>' for r, img in bands)
    band_html = f"""
<section>
  <h2>How hard the lit windows breathe: 1&times;, 2&times;, 3&times;</h2>
  <p class="note">One dial moved and nothing else, same frozen moment: <code>floor</code>/<code>ceiling</code> of the
  <code>windows</code> and <code>shopfronts</code> channels in <code>arenas/terminus.json</code>, widened around the
  same average so the city gets more alive without getting brighter. Costs nothing: the same one number a frame.
  {'<br>Show off: <a href="' + off + '">the before</a>.' if off else ''}</p>
  <div class="strip">{cells}</div>
</section>"""

clips = []
for mp4 in sorted(glob.glob(os.path.join(build, "show-clips", "*.mp4"))):
    name = os.path.basename(mp4)
    shutil.copy(mp4, os.path.join(out, "img", name))
    clips.append(f'<figure><video src="img/{name}" controls loop muted playsinline></video>'
                 f'<figcaption>{html.escape(name[:-4].replace("_", " "))}</figcaption></figure>')
clip_html = ""
if clips:
    clip_html = f"""
<section>
  <h2>In motion (30 fps, so a strobe is sampled, not missed)</h2>
  <p class="note">A chase is motion; a still of one is a still of some lights. These are the verdict for the effects.</p>
  <div class="strip">{''.join(clips)}</div>
</section>"""

page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Terminus Light Show</title>
<style>
:root {{ --bg:#0d0f14; --fg:#e8e6ef; --dim:#9a97a8; --line:#262a35; --accent:#ff2fa0; }}
@media (prefers-color-scheme: light) {{ :root:not([data-theme="dark"]) {{ --bg:#f6f5f9; --fg:#1a1822; --dim:#5d5a6b; --line:#dcd9e4; }} }}
body {{ background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, sans-serif; margin:0; padding:24px 16px 64px; }}
main {{ max-width:1400px; margin:0 auto; }}
h1 {{ font-size:28px; margin:0 0 4px; }} h2 {{ font-size:19px; margin:36px 0 4px; }}
.lede {{ color:var(--dim); max-width:780px; }}
.note {{ color:var(--dim); margin:0 0 10px; max-width:900px; }}
.pair {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; }}
.strip {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(320px, 1fr)); gap:10px; }}
figure {{ margin:0; }} img, video {{ width:100%; display:block; border:1px solid var(--line); border-radius:4px; }}
figcaption {{ font-size:13px; color:var(--dim); padding:4px 2px; }}
.stats {{ font-size:12px; color:var(--dim); }} code {{ font-size:12px; }}
@media (max-width:700px) {{ .pair {{ grid-template-columns:1fr; }} }}
</style></head><body><main>
<h1>The Terminus light show</h1>
<p class="lede">You said the buildings look like a 1990s game and asked for basic primitives to drive individual
lights, with light-show effects built from them. Every window on every building is now addressable on its own. Each
pair below is <b>one frozen frame shot twice</b>, show off (what you played) then show on, at your pose (21&deg;,
FOV 35, 49&nbsp;m). Your eye is the judge; the percentage under each is the readability instrument, reported, not
obeyed.</p>
{clip_html}
{''.join(parts) if parts else '<p>No frames yet: run <code>make remote T=show-frames</code>.</p>'}
{band_html}
</main></body></html>
"""
open(os.path.join(out, "index.html"), "w").write(page)
print("show-page: %d pairs, %d band frames, %d clips -> %s/index.html" % (len(parts), len(bands), len(clips), out))
