#!/usr/bin/env python3
"""Round 17 G4: the audition page's audio and data, built from the repo (published as an Artifact by the worker).

    python3 tools/audio/audition_page.py [--clips build/audio/audition] [--out build/audio/local/page]

For every family on the page: today's sound and each designed direction, DRY (the shipped takes as the game plays them:
three takes in a row; the 25 mm as two real four-round bursts at its 0.12 s rhythm; a loop held for 4 s) and, when
`make audition-clips` has run, IN THE FIGHT (the same 15 s of his match through the game's mix). Nothing is
level-matched: each file's loudness (BS.1770 momentary max / integrated), true peak and stereo width is measured and
written beside it. Writes <out>/audio/*.mp3 and <out>/data.json; the page (audition.html) reads data.json.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import weapon_sheet  # noqa: E402

RATE = 44100
BURST_DB = -6.0
## family -> (title, the player's words for it, sound, how to preview, option ids, fight clip per option)
FAMILIES = [
    {"id": "tank", "sound": "tank_boom", "title": "The tank's main gun", "ref": "an Abrams' 120 mm",
     "preview": "takes", "options": ["0", "a", "b", "c"]},
    {"id": "25mm", "sound": "autocannon_shot", "title": "The IFV's 25 mm", "ref": "a Bradley's Bushmaster, an Apache's chain gun",
     "preview": "burst", "options": ["0", "a", "b", "c"]},
    {"id": "mg", "sound": "mg_loop", "title": "The scouts' machine gun", "ref": "a heavy machine gun, every round with weight",
     "preview": "loop", "options": ["0", "a", "b"]},
    {"id": "kill", "sound": "explosion_big", "title": "A vehicle destroyed", "ref": "the biggest event in the game",
     "preview": "takes", "options": ["0", "a", "b"]},
    {"id": "railgun", "sound": "railgun_shot", "title": "The Syndicate's railgun", "ref": "as heavy as a tank's main gun",
     "preview": "takes", "options": ["0", "a"]},
    {"id": "twinmg", "sound": "twin_mg_loop", "title": "Twin machine guns", "ref": "two heavy guns at once", "preview": "loop",
     "options": ["0", "a"]},
    {"id": "mortar", "sound": "mortar_launch", "title": "A mortar firing", "ref": "a tube thump you feel", "preview": "takes",
     "options": ["0", "a"]},
    {"id": "missiles", "sound": "missile_launch", "title": "Guided missiles away", "ref": "an ignition crack and a motor",
     "preview": "takes", "options": ["0", "a"]},
    {"id": "pulse", "sound": "pulse_shot", "title": "The pulse cannon", "ref": "an energy weapon with weight", "preview": "takes",
     "options": ["0", "a"]},
    {"id": "flame", "sound": "flame_loop", "title": "The flamethrower", "ref": "a roar with width", "preview": "loop",
     "options": ["0", "a"]},
    # Second tries: sounds he marked redo (verdicts, 14:21-14:22 PDT). The first try stays beside two new directions.
    {"id": "skid", "sound": "track_skid", "title": "A tank braking hard", "ref": "60 tonnes stopping", "preview": "takes",
     "options": ["a", "b", "c"], "second": True},
    {"id": "squeal", "sound": "track_squeal", "title": "A tank turning hard", "ref": "tracks fighting the ground", "preview": "takes",
     "options": ["a", "b", "c"], "second": True},
    {"id": "incoming", "sound": "shell_incoming", "title": "A round coming down", "ref": "the second before it lands", "preview": "takes",
     "options": ["a", "b", "c"], "second": True},
    {"id": "shield", "sound": "shield_up", "title": "A shield charging back up", "ref": "protection back, heard across the field",
     "preview": "takes", "options": ["a", "b", "c"], "second": True},
]
## Sounds new in round 17 with one design each: heard, kept or sent back.
SINGLES = [
    ("Where a round lands", [("impact_concrete_heavy", "A shell into concrete"), ("impact_steel_heavy", "A shell into a container"),
                             ("impact_water_heavy", "A shell into water"), ("dirt_impact", "A shell into the ground (today's)"),
                             ("impact_armor_medium", "A 25 mm round on a vehicle"), ("impact_concrete_medium", "A 25 mm round into concrete"),
                             ("impact_steel_medium", "A 25 mm round into steel"), ("impact_dirt_medium", "A 25 mm round into the ground"),
                             ("impact_concrete_light", "A machine-gun round into concrete"), ("impact_dirt_light", "A machine-gun round into the ground"),
                             ("impact_water_light", "A round into water")]),
    ("Things that were silent", [("tyre_skid", "A wheeled vehicle braking hard"), ("wreck_fire_loop", "A burning wreck")]),
]
## The shipped music level's arm (game/audio/music_director.gd), marked as the default on the page.
MUSIC_DEFAULT = "music_half"
MUSIC = [("music_now", "As the new mix leaves it", "+0 dB"), ("music_half", "About half the gap back (the default now)", "+4 dB"),
         ("music_old", "About the old relation", "+8 dB")]
BOOTH = [("duck_launch", "As it was", "−28 dB at 6:1"), ("duck_mid", "Between (the default now)", "−24 dB at 4:1"),
         ("duck_new", "Lightest", "−20 dB at 2.5:1")]


def directions() -> tuple[dict, dict]:
    text = (ROOT / "game" / "theme" / "audio" / "sfx_directions.gd").read_text()
    takes, labels = {}, {}
    body = text[text.index("const TAKES"): text.index("const LABELS")]
    for sound, inner in re.findall(r'"([a-z0-9_]+)": \{(.*)\},', body):
        takes[sound] = {d: [ROOT / p.replace("res://", "") for p in re.findall(r'"(res://[^"]+)"', paths)]
                        for d, paths in re.findall(r'"([a-z0-9]+)": \[([^\]]*)\]', inner)}
    body = text[text.index("const LABELS"):]
    for sound, inner in re.findall(r'"([a-z0-9_]+)": \{(.*)\},', body):
        labels[sound] = dict(re.findall(r'"([a-z0-9]+)": "([^"]*)"', inner))
    return takes, labels


def chosen() -> dict:
    return weapon_sheet.chosen_directions()


def stereo(x: np.ndarray) -> np.ndarray:
    return x if x.shape[1] == 2 else np.repeat(x, 2, axis=1)


def preview(paths: list[Path], kind: str) -> np.ndarray:
    xs = [stereo(weapon_sheet.read(p)[0]) for p in paths]
    gap = np.zeros((int(0.5 * RATE), 2))
    if kind == "burst":
        out = []
        for burst in range(2):
            b = np.zeros((int(1.4 * RATE), 2))
            for i in range(4):
                x = xs[(burst * 4 + i) % len(xs)]
                s = int(i * 0.12 * RATE)
                n = min(len(x), len(b) - s)
                b[s:s + n] += x[:n]
            out += [b, gap]
        # Four overlapping rounds sum past full scale; the game plays the 25 mm at -4 dB (SfxSystem.MIX). The same
        # BURST_DB for every option, said on the page, so nothing clips and the comparison stays fair.
        return np.concatenate(out) * 10 ** (BURST_DB / 20)
    if kind == "loop":
        x = xs[0]
        return np.tile(x, (int(np.ceil(4.0 * RATE / len(x))), 1))[: int(4.0 * RATE)]
    parts = []
    for x in xs[:3]:
        parts += [x, gap]
    return np.concatenate(parts)


def write_mp3(x: np.ndarray, path: Path) -> dict:
    wav = path.with_suffix(".wav")
    with wave.open(str(wav), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "192k", str(path)], check=True)
    wav.unlink()
    # Width after the first 150 ms: a centred crack dominates a whole-clip number and hides the tail, and the tail is
    # where a living-room system opens up or doesn't (the orchestrator's review of page v1).
    return {"loud": round(weapon_sheet.momentary_max_lufs(x, RATE), 1), "tp": round(weapon_sheet.true_peak_db(x, RATE), 1),
            "width": round(weapon_sheet.width(x[int(0.15 * RATE):]), 2), "seconds": round(len(x) / RATE, 1)}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clips", default=str(ROOT / "build" / "audio" / "audition"))
    parser.add_argument("--booth-seeds", default=str(ROOT / "build" / "audio" / "booth_match" / "booth_match.json"),
                        help="booth-match's report: shown beside the booth figures as their seed-to-seed spread")
    parser.add_argument("--out", default=str(ROOT / "build" / "audio" / "local" / "page"))
    args = parser.parse_args(argv)
    out = Path(args.out)
    audio = out / "audio"
    audio.mkdir(parents=True, exist_ok=True)
    clips = Path(args.clips)
    clip_info = json.loads((clips / "clips.json").read_text()) if (clips / "clips.json").exists() else {"clips": {}}
    takes, labels = directions()
    shipped = weapon_sheet.shipped_takes()
    picks = chosen()
    data = {"families": [], "singles": [], "booth": [], "match": "the Sumps, Law (24) v Condemned (27), seed 92721",
            "whole": {}, "clip_window": clip_info.get("window_s"), "duck_window": clip_info.get("duck_window_s")}

    def fight(name: str) -> dict | None:
        row = clip_info["clips"].get(name)
        if not row:
            return None
        shutil.copy(clips / row["file"], audio / ("fight_" + row["file"].replace("clip_", "")))
        return {"file": "audio/fight_" + row["file"].replace("clip_", ""), "loud": row["integrated_lufs"], "tp": row["true_peak_db"]}

    for family in FAMILIES:
        sound = family["sound"]
        entry = {k: family[k] for k in ("id", "title", "ref")}
        entry["second"] = family.get("second", False)
        entry["default"] = picks.get(sound, family["options"][0])
        entry["options"] = []
        for option in family["options"]:
            paths = shipped[sound] if option == "0" else takes[sound][option]
            row = write_mp3(preview(paths, family["preview"]), audio / ("%s_%s.mp3" % (family["id"], option)))
            first_try = entry["second"] and option == "a"
            entry["options"].append({"id": option, "label": "Today's sound" if option == "0" else
                                     ("First try (you sent it back)" if first_try else "Direction " + option.upper()),
                                     "about": "As the game plays it now, before round 17" if option == "0" else labels[sound][option],
                                     "dry": dict(row, file="audio/%s_%s.mp3" % (family["id"], option)),
                                     # The default of every family plays in the all-defaults run (recorded as tank_a).
                                     "fight": fight("%s_%s" % (family["id"], option)) or
                                     (fight("tank_a") if option == entry["default"] and family["id"] in ("tank", "25mm", "mg", "kill") else None)})
        # Dry matching: every option turned DOWN to the family's quietest (never up), so a louder file is not a
        # better-sounding one by level alone. The page applies it as playback volume; the numbers stay as measured.
        quietest = min(o["dry"]["loud"] for o in entry["options"])
        for o in entry["options"]:
            o["dry"]["match_db"] = round(quietest - o["dry"]["loud"], 1)
        data["families"].append(entry)
    for heading, sounds in SINGLES:
        group = {"heading": heading, "sounds": []}
        for sound, label in sounds:
            paths = takes[sound]["a"] if sound in takes else shipped.get(sound, [])
            if not paths:
                continue
            row = write_mp3(preview(paths, "loop" if sound.endswith("_loop") else "takes"), audio / ("%s.mp3" % sound))
            group["sounds"].append({"id": sound, "label": label, "dry": dict(row, file="audio/%s.mp3" % sound)})
        data["singles"].append(group)
    import pass_taps
    for name, label, setting in BOOTH:
        about = setting
        taps = clips / ("fight_%s.wav" % name)
        if taps.with_suffix(".booth.wav").exists():
            m = pass_taps.booth_and_music(taps)
            about = "%s. While the caller speaks, his voice sits %.1f dB above the battle (median), %.1f dB at the busiest tenth" % (
                setting, m["booth_over_battle_median_db"], m["booth_over_battle_p10_db"])
        data["booth"].append({"id": name, "label": label, "setting": about, "fight": fight(name)})
    # The booth figures move with the commentary (which lines, when): the same fight under three announcer seeds
    # spreads them by ~3 dB. Shown beside the page's figures so a 1-2 dB gap between settings is read as noise.
    seeds = Path(args.booth_seeds)
    if seeds.exists():
        report = json.loads(seeds.read_text())
        rows = [{"seed": r["seed"], "median": r["shipped"][0], "p10": r["shipped"][1]} for r in report["seeds"]]
        # The spread of the rows shown (the shipped build), not booth-match's reference arm.
        data["booth_seeds"] = {"rows": rows, "window_s": report["window_s"],
                               "spread": {k: round(max(r[k] for r in rows) - min(r[k] for r in rows), 1) for k in ("median", "p10")}}
    data["music"] = []
    for name, label, setting in MUSIC:
        about = "music " + setting
        taps = clips / ("fight_%s.wav" % name)
        if taps.with_suffix(".music.wav").exists():
            m = pass_taps.booth_and_music(taps)
            master = pass_taps.analyse(taps).get("master", {})
            # The Music tap sits before the bus volume this arm changes: add it back for the relation the ear hears.
            lift = float(setting.replace("dB", "").strip())
            about = "music %s: it sits %.1f dB under the battle while the caller speaks (before round 17: about 7 dB). The master limiter does not engage (its input peaks %.1f dBFS, ceiling −1)" % (
                setting, -(m["music_under_battle_median_db"] + lift), master.get("peak_in_dbfs", 0.0))
        data["music"].append({"id": name, "label": label, "setting": about, "fight": fight(name)})
    data["music_default"] = MUSIC_DEFAULT
    data["whole"] = {"before": fight("today"), "now": fight("tank_a")}
    (out / "data.json").write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    page = (HERE / "audition_page.html").read_text().replace("/*DATA*/{}", json.dumps(data, ensure_ascii=False))
    (out / "gun_audition.html").write_text(page)
    print("audition page data: %s (%d mp3)" % (out / "data.json", len(list(audio.glob("*.mp3")))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
