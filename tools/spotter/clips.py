#!/usr/bin/env python3
"""Spotter S3: render the top moments of a batch as short clips, on builder3, OFFSCREEN.

    python3 tools/spotter/clips.py build/spotter/fights [--top 30] [--godot PATH]      (cwd = the project)
        -> <fights>/clips/<n>-<arena>-<seed>-<crew>.mp4 and clips.json (each with its reproduction line and drift check)

The display: its own Xvfb (the distro's xvfb package extracted without root to ~/tools/xvfb; XVFB= overrides), never his desktop
:1 (R47.23). NVIDIA's GL needs its own X server, so on Xvfb Godot draws with Mesa llvmpipe: the SAME gl_compatibility renderer his
game uses, rasterized on the CPU (32 threads). The GPU encodes (h264_nvenc; libx264 when NVENC is busy or absent).
Each clip is one Godot run of tests/spotter/clip_probe.gd: the fight from its seed, fast-forwarded with rendering off, then every
tick rendered from the clip's start to its end. A clip whose crew stands more than DRIFT_M from the table's position at the peak
tick did not reproduce its moment: it is marked `reproduced: false` (a bug to report, never shown as evidence).
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rank as R  # noqa: E402

DRIFT_M = 1.0
SIZE = "960x540"


def find_godot():
    found = sorted(glob.glob(".tools/godot-*/Godot_v*_linux.x86_64"))
    return found[0] if found else "godot"


def start_xvfb(xvfb):
    for display in range(91, 120):
        if os.path.exists(f"/tmp/.X11-unix/X{display}") or os.path.exists(f"/tmp/.X{display}-lock"):
            continue
        proc = subprocess.Popen([xvfb, f":{display}", "-screen", "0", f"{SIZE}x24", "-nolisten", "tcp"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            if os.path.exists(f"/tmp/.X11-unix/X{display}"):
                return proc, f":{display}"
            time.sleep(0.1)
        proc.kill()
    sys.exit("clips: no Xvfb display could start")


BLIND = False  # --blind: the caption names the crew only (a batch with hidden controls; batch 2's reasons were burned in)


def caption(m):
    if BLIND:
        return f"{m['crew']} ({m.get('unit', '')})  {m['arena']}"
    words = "; ".join(f"{r['words']} {r['value']:g} {r['unit']}" for r in m["reasons"][:2])
    return f"{m['crew']} ({m['unit']})  {m['arena']} seed {m['seed']}  t={m['start_s']}-{m['end_s']} s  |  {words}"


def encode(frames_dir, out):
    for codec in (["-c:v", "h264_nvenc", "-cq", "28"], ["-c:v", "libx264", "-crf", "26", "-preset", "veryfast"]):
        cmd = ["ffmpeg", "-loglevel", "error", "-y", "-framerate", "30", "-i", os.path.join(frames_dir, "f%05d.jpg"),
               *codec, "-pix_fmt", "yuv420p", "-movflags", "+faststart", out]
        if subprocess.run(cmd).returncode == 0:
            return codec[1]
    return ""


def render(m, godot, display, work, clip_dir, index, timeout):
    c = m["clip"]
    name = clip_name(m)
    mp4 = os.path.join(clip_dir, name + ".mp4")
    done = os.path.join(clip_dir, name + ".json")
    if os.path.exists(mp4) and os.path.exists(done):  # rendered by an earlier batch: the same fight, crew and seconds
        old = json.load(open(done))
        old.update({"index": index, "moment": m, "repro": R.repro(m)})
        return old
    frames = os.path.join(work, name)
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    args = [godot, "--path", ".", "--resolution", SIZE, "--fixed-fps", "30", "--script", "res://tests/spotter/clip_probe.gd", "--",
            "--skirmish", "--demo-match", "--clean", f"--seed={c['seed']}", f"--arena={c['arena']}", "--mute",
            f"--clip-crew={c['crew']}", f"--clip-from={c['from_s']}", f"--clip-to={c['to_s']}", f"--clip-dir={frames}",
            f"--clip-check-tick={m['peak_tick']}", f"--clip-check={m['at'][0]},{m['at'][1]}", f"--clip-title={caption(m)}"]
    env = dict(os.environ, DISPLAY=display)
    started = time.time()
    try:
        out = subprocess.run(args, env=env, capture_output=True, text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired:
        out = ""
    result = {"done": None, "check": None}
    for line in out.splitlines():
        if line.startswith("CLIP_DONE "):
            result["done"] = json.loads(line[10:])
        elif line.startswith("CLIP_CHECK "):
            result["check"] = json.loads(line[11:])
    codec = encode(frames, mp4) if result["done"] and result["done"]["frames"] > 0 else ""
    shutil.rmtree(frames, ignore_errors=True)
    drift = result["check"]["drift_m"] if result["check"] else None
    clip = {
        "index": index, "file": os.path.basename(mp4) if codec else "", "codec": codec,
        "frames": result["done"]["frames"] if result["done"] else 0, "seconds_to_render": round(time.time() - started, 1),
        "drift_m": drift, "reproduced": drift is not None and drift <= DRIFT_M,
        "repro": R.repro(m), "moment": m,
    }
    if codec:
        with open(done, "w") as handle:
            json.dump(clip, handle)
    return clip


def clip_name(m):
    """A clip's file name is its moment (fight, crew, seconds), so a later batch's re-ranking reuses it."""
    c = m["clip"]
    return f"{c['arena']}-{c['seed']}-{c['crew'].replace(' ', '_')}-{c['from_s']}-{c['to_s']}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fight_dir")
    ap.add_argument("--top", type=int, default=30)
    ap.add_argument("--godot", default="")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--only", type=int, default=0, help="render just this rank (1-based)")
    ap.add_argument("--blind", action="store_true", help="caption the crew only (no reasons in the frames)")
    ap.add_argument("--ranks", default="", help="render ranks A-B (1-based) instead of the top N, plus moments.json's controls")
    ap.add_argument("--one", nargs=5, metavar=("SEED", "ARENA", "CREW", "FROM_S", "TO_S"),
                    help="one clip from its reproduction line (no moments.json, no drift check)")
    args = ap.parse_args()
    global BLIND
    BLIND = args.blind
    if args.one:
        seed, arena, crew, from_s, to_s = args.one
        one = {"seed": int(seed), "arena": arena, "crew": crew, "unit": "", "start_s": int(from_s), "end_s": int(to_s),
               "peak_tick": -1, "at": [0.0, 0.0], "reasons": [],
               "clip": {"seed": int(seed), "arena": arena, "crew": crew, "from_s": int(from_s), "to_s": int(to_s)}}
        data = {"stamp": "one clip", "top": [one]}
        args.only = 1
    else:
        data = json.load(open(os.path.join(args.fight_dir, "moments.json")))
    moments = data["top"][: args.top]
    first = 1
    if args.ranks:
        a, b = (int(x) for x in args.ranks.split("-"))
        moments, first = data["top"][a - 1:b] + data.get("controls", []), a
    if args.only:
        moments = [data["top"][args.only - 1]]
    clip_dir = os.path.join(args.fight_dir, "clips")
    work = os.path.join(args.fight_dir, ".frames")
    os.makedirs(clip_dir, exist_ok=True)
    xvfb_path = os.environ.get("XVFB") or os.path.expanduser("~/tools/xvfb/root/usr/bin/Xvfb")
    xvfb, display = start_xvfb(xvfb_path)
    clips = []
    try:
        for i, m in enumerate(moments, args.only or first):
            clip = render(m, args.godot or find_godot(), display, work, clip_dir, i, args.timeout)
            clips.append(clip)
            print(f"clip {i:2d}: {clip['file'] or 'FAILED'} drift {clip['drift_m']} m, {clip['frames']} frames, "
                  f"{clip['seconds_to_render']} s ({clip['codec']})", flush=True)
    finally:
        xvfb.terminate()
        shutil.rmtree(work, ignore_errors=True)
    path = os.path.join(args.fight_dir, "clips.json")
    old = json.load(open(path)) if os.path.exists(path) and args.only else {"clips": []}
    merged = {c["index"]: c for c in old.get("clips", [])}
    merged.update({c["index"]: c for c in clips})
    with open(path, "w") as handle:
        json.dump({"stamp": data["stamp"], "clips": [merged[k] for k in sorted(merged)]}, handle, indent=1)
    bad = [c for c in clips if not c["reproduced"]]
    print(f"clips: {len(clips) - len(bad)} of {len(clips)} reproduced their moment -> {clip_dir}")


if __name__ == "__main__":
    main()
