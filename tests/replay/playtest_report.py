#!/usr/bin/env python3
"""Round 43 (native N5): one report for his playtest recording, so a fresh agent reads his match before guessing at it.

    python3 tests/replay/playtest_report.py <recording.jsonl[.gz]> [--replay <replay-match output>] [--html <out.html>]
    make playtest-report RECORDING=<file> [HTML=build/playtest-report/report.html]   (runs the replay first, shim on)

Sections, plain text first:
  (a) the match: arena, seed, factions, squad cap, native, his switches; then tools/recording_arrivals.py per order
  (b) the camera at each hit and death: the last `cam` row at or before the event (tests/camera/camera_recording.py's
      compass words, his screen's terms); a recording from before round 43 has none, and says so
  (c) the replay: `make replay-match`'s divergence table for the first 30 s (every crew), when --replay is given
"""
import argparse
import contextlib
import gzip
import html
import importlib.util
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def rows_of(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def section_match(rows, path):
    header = next((r for r in rows if r.get("t") == "match"), {})
    end = rows[-1].get("tick", 0) if rows else 0
    rate = float(header.get("tick_rate", 30))
    units = header.get("units", [])
    sides = {0: sum(1 for u in units if u.get("team") == 0), 1: sum(1 for u in units if u.get("team") == 1)}
    out = ["(a) THE MATCH", "  %s" % path,
           "  arena %s, seed %s, %.0f s, Green %d units v Rust %d" % (header.get("arena", "?"), header.get("seed", "?"),
                                                                  end / rate, sides[0], sides[1])]
    if "squad_cap" in header:
        flags = header.get("flags", {})
        switches = " ".join("--%s=%s" % (k, v) if v != "" else "--" + k for k, v in sorted(flags.items()))
        out.append("  factions %s, squad cap %s, preset %s, native %s" % (header.get("factions"), header["squad_cap"],
                                                                        header.get("preset"), header.get("native")))
        out.append("  switches: %s" % (switches or "(none)"))
    else:
        out.append("  (a recording from before round 43: no squad cap, factions, native or switches recorded)")
    deaths = [r for r in rows if r.get("t") == "dead"]
    hits = [r for r in rows if r.get("t") == "hit"]
    orders = [r for r in rows if r.get("t") == "order"]
    out.append("  %d orders, %d hits, %d deaths (Green %d, Rust %d)" % (len(orders), len(hits), len(deaths),
               sum(1 for d in deaths if d.get("team") == 0), sum(1 for d in deaths if d.get("team") == 1)))
    out.append("")
    out.append("  arrivals per order (tools/recording_arrivals.py):")
    arrivals = _load("recording_arrivals", os.path.join(ROOT, "tools", "recording_arrivals.py")) if "recording_arrivals" not in sys.modules else sys.modules["recording_arrivals"]
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        arrivals.report(path)
    out += ["  " + line for line in buf.getvalue().splitlines() if not line.startswith("===")]
    return out


def section_camera(rows):
    rate = float(next((r for r in rows if r.get("t") == "match"), {}).get("tick_rate", 30))
    cams = [r for r in rows if r.get("t") == "cam"]
    out = ["(b) THE CAMERA AT EACH HIT AND DEATH (his screen's compass: the way the view looks)"]
    if not cams:
        out.append("  no cam rows: a recording from before round 43 (camera K5.1 records the camera from then on)")
        return out
    camera = _load("camera_recording", os.path.join(ROOT, "tests", "camera", "camera_recording.py"))
    events = [r for r in rows if r.get("t") in ("hit", "dead")]
    for e in events:
        before = [c for c in cams if c["tick"] <= e["tick"]]
        if e["t"] == "hit":
            what = "hit   %s -> %s %s%s" % (e.get("shooter", "?"), e.get("target", "?"), e.get("face", ""),
                                          " KILL" if e.get("killed") else "")
        else:
            what = "death %s (by %s)" % (e.get("unit", "?"), e.get("killer", "?"))
        if not before:
            out.append("  %6.1f s  %-58s  (no camera yet)" % (e["tick"] / rate, what[:58]))
            continue
        c = before[-1]
        out.append("  %6.1f s  %-58s  look %-2s %6.1f  at (%6.1f, %6.1f)  %s (cam row %.1f s)" % (
            e["tick"] / rate, what[:58], camera.compass(c["yaw"]), c["yaw"], c["target"][0], c["target"][1], c.get("mode", ""),
            c["tick"] / rate))
    return out


def section_replay(replay_path):
    out = ["(c) THE REPLAY (make replay-match, first 30 s, every crew; native library and trig shim through make)"]
    if not replay_path:
        out.append("  not run (pass --replay <replay-match output>, or use `make playtest-report`)")
        return out
    try:
        with open(replay_path) as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        out.append("  could not read %s: %s" % (replay_path, error))
        return out
    keep = [l for l in lines if l.startswith(("REPLAY_", "NATIVE_EXEC", "crew ", "DIVERGENCE")) or (l[:1].isalpha() and "  " in l
            and any(ch.isdigit() for ch in l[-6:]))]
    out += ["  " + l for l in keep] if keep else ["  (no replay output in %s)" % replay_path]
    verdict = [l for l in lines if l.startswith("DIVERGENCE")]
    out.append("  -> " + ("the replay IS his match for these 30 s" if verdict and "verdict=PASS" in verdict[-1]
                          else "the replay leaves his match: read the first_over crew before trusting it"))
    return out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("recording")
    ap.add_argument("--replay", default="")
    ap.add_argument("--html", default="")
    args = ap.parse_args(argv)
    rows = rows_of(args.recording)
    report = section_match(rows, args.recording) + [""] + section_camera(rows) + [""] + section_replay(args.replay)
    text = "\n".join(report)
    print(text)
    if args.html:
        os.makedirs(os.path.dirname(os.path.abspath(args.html)), exist_ok=True)
        with open(args.html, "w") as handle:
            handle.write("<!doctype html><meta charset=utf-8><title>Playtest report</title>"
                         "<style>body{font:13px/1.4 ui-monospace,monospace;margin:16px;background:#fff;color:#111}"
                         "@media (prefers-color-scheme:dark){body{background:#111;color:#ddd}}pre{white-space:pre-wrap}</style>"
                         "<h1 style='font:600 18px system-ui'>Playtest report</h1><pre>%s</pre>" % html.escape(text))
        print("\nHTML: %s" % args.html)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
