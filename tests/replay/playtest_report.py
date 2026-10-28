#!/usr/bin/env python3
"""Round 43 (native N5), round 44 (N1: one screen): one report for his playtest recording, so a fresh agent reads his match
before guessing at it.

    python3 tests/replay/playtest_report.py <recording.jsonl[.gz]> [--replay <replay-match output>] [--out <full.txt>] [--html <out.html>]
    make playtest-report RECORDING=<file> [HTML=build/playtest-report/report.html]   (runs the replay first, shim on)

It PRINTS a summary that fits one screen (he pastes it; at most SUMMARY_MAX lines): the match, one line per click (the order
rows of one tick are one click: its squads, verb, how far apart their spots are, who arrived, the worst arrival), how many hits
and deaths happened off screen, the replay's verdict, and the path of the full report.

It WRITES the full report to --out (default build/playtest-report/<recording>.txt) and a page beside it (--html overrides):
  (a) the match: arena, seed, factions, squad cap, native, his switches; then tools/recording_arrivals.py per order
  (b) the camera at each hit and death: the last `cam` row at or before the event (tests/camera/camera_recording.py's
      compass words, his screen's terms) and whether the victim was on screen; a recording from before round 43 has none
  (c) the replay: `make replay-match`'s divergence table for the first 30 s (every crew), when --replay is given
"""
import argparse
import contextlib
import gzip
import html
import importlib.util
import io
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SUMMARY_MAX = 40  # lines printed; the rest is in the full file
CLICK_LINES = 24  # clicks listed in the summary before "... N more"
# The on-screen estimate: the cam row has no lens, so RtsCamera's default FOV_DEG on a 16:9 screen, a hull's middle 1.5 m up,
# and the shown pitch lifted by RtsCamera.tilt_at's far-range floor (MIN_PITCH_DEG 8 -> FAR_TILT_MAX_DEG 40 over 70-160 m).
FOV_DEG, ASPECT, HULL_Y = 35.0, 16.0 / 9.0, 1.5


def _load(name, path):
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.modules[name] = module
    return module


def rows_of(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def header_of(rows):
    return next((r for r in rows if r.get("t") == "match"), {})


def rate_of(rows):
    return float(header_of(rows).get("tick_rate", 30))


def seed_words(header):
    """The match seed; when the header's is -1 (a random seed), his --seed switch as typed beside it."""
    seed = header.get("seed", "?")
    typed = header.get("flags", {}).get("seed")
    if typed is not None and str(typed) != str(seed):
        return "%s (his --seed=%s)" % (seed, typed)
    return str(seed)


# ---- the camera: was a point on his screen? ---------------------------------------------------------------------------

def tilt_at(pitch, dist):
    t = min(max((dist - 70.0) / (160.0 - 70.0), 0.0), 1.0)
    return max(pitch, 8.0 + (40.0 - 8.0) * t)


def on_screen(cam, x, z):
    """Whether ground point (x, z) at hull height is inside the frame of the camera a `cam` row describes (RtsCamera.pose_at:
    the boom (0, sin tilt, cos tilt) * dist turned by yaw about up, looking at the ground point)."""
    yaw, tilt = math.radians(cam["yaw"]), math.radians(min(max(tilt_at(cam["pitch"], cam["dist"]), 1.0), 89.0))
    tx, tz = cam["target"]
    d = cam["dist"]
    ox, oy, oz = tx + d * math.cos(tilt) * math.sin(yaw), d * math.sin(tilt), tz + d * math.cos(tilt) * math.cos(yaw)
    fx, fy, fz = tx - ox, -oy, tz - oz
    n = math.sqrt(fx * fx + fy * fy + fz * fz)
    fx, fy, fz = fx / n, fy / n, fz / n
    rx, rz = -fz, fx  # forward x up, flattened
    n = math.hypot(rx, rz)
    rx, rz = rx / n, rz / n
    ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy  # right x forward
    vx, vy, vz = x - ox, HULL_Y - oy, z - oz
    depth = vx * fx + vy * fy + vz * fz
    if depth < 0.1:
        return False
    half = math.tan(math.radians(FOV_DEG) / 2.0)
    side = (vx * rx + vz * rz) / depth
    up = (vx * ux + vy * uy + vz * uz) / depth
    return abs(side) <= half * ASPECT and abs(up) <= half


def camera_events(rows):
    """Every hit and death with the cam row at or before it and whether its victim was on screen (None: no camera or no
    census position yet)."""
    cams = [r for r in rows if r.get("t") == "cam"]
    census = [r for r in rows if r.get("t") == "census"]
    out = []
    ci = si = 0
    for e in (r for r in rows if r.get("t") in ("hit", "dead")):
        while ci < len(cams) and cams[ci]["tick"] <= e["tick"]:
            ci += 1
        while si < len(census) and census[si]["tick"] <= e["tick"]:
            si += 1
        cam = cams[ci - 1] if ci else None
        victim = e.get("target") if e["t"] == "hit" else e.get("unit")
        pos = None
        if si:
            pos = next((u["pos"] for u in census[si - 1]["units"] if u.get("n") == victim), None)
        seen = on_screen(cam, pos[0], pos[1]) if cam and pos else None
        out.append((e, cam, victim, seen))
    return out


# ---- the clicks: the order rows of one tick and verb ------------------------------------------------------------------

def squad_of(unit):
    return re.sub(r"_\d+$", "", re.sub(r"^(Green|Rust)_", "", unit))


def clicks_of(rows):
    """[(tick, verb, [order rows])]: one per click (orders to several squads write a row per squad on the same tick)."""
    out = []
    for r in (r for r in rows if r.get("t") == "order"):
        if out and out[-1][0] == r["tick"] and out[-1][1] == r.get("verb"):
            out[-1][2].append(r)
        else:
            out.append((r["tick"], r.get("verb"), [r]))
    return out


def click_line(tick, verb, orders, arrivals_by_row, rate):
    squads = " ".join("%s:%d" % (squad_of(o["units"][0]), len(o["units"])) for o in orders if o.get("units"))
    words = ["%6.1f s" % (tick / rate), "%-11s" % verb, squads or "-"]
    first = orders[0]
    if first.get("click"):
        words.append("click (%.0f, %.0f)" % tuple(first["click"][:2]))
    spots = [o["to"] for o in orders if o.get("to")]
    if len(spots) > 1:
        apart = max(math.hypot(a[0] - b[0], a[1] - b[1]) for a in spots for b in spots)
        words.append("%d spots %.0f m apart" % (len(spots), apart))
    elif spots:
        words.append("to (%.0f, %.0f)" % tuple(spots[0][:2]))
    elif first.get("target"):
        words.append("-> %s" % str(first["target"]).replace("Rust_", "").replace("Green_", ""))
    if first.get("queue"):
        words.append("queued")
    units = [u for o in orders for u in arrivals_by_row.get(id(o), [])]
    if units:
        arrived = sum(1 for u in units if u["arrived"] is not None)
        worst = max(units, key=lambda u: u["best"])
        words.append("arrived %d/%d" % (arrived, len(units)))
        words.append("worst %s %.0f m%s" % (worst["name"], worst["best"], "" if worst["arrived"] is not None else " never"))
        away = max(units, key=lambda u: u["away"])
        if away["away"] >= 30:
            words.append("AWAY %s %.0f m" % (away["name"], away["away"]))
    return "  " + "  ".join(words)


# ---- the summary (printed) --------------------------------------------------------------------------------------------

def summary(rows, path, replay_lines, full_path, html_path=""):
    header = header_of(rows)
    rate = rate_of(rows)
    end = rows[-1].get("tick", 0) if rows else 0
    units = header.get("units", [])
    factions = header.get("factions") or {}
    out = ["PLAYTEST %s" % os.path.basename(path)]
    out.append("match: %s, seed %s, %.0f s, %s v %s (%d v %d units)%s" % (
        header.get("arena", "?"), seed_words(header), end / rate, factions.get("green", "Green"), factions.get("rust", "Rust"),
        sum(1 for u in units if u.get("team") == 0), sum(1 for u in units if u.get("team") == 1),
        ", squad cap %s, %s, native %s" % (header["squad_cap"], header.get("preset"), "on" if header.get("native") else "off")
        if "squad_cap" in header else " (before round 43: no cap/factions/native recorded)"))
    deaths = [r for r in rows if r.get("t") == "dead"]
    hits = [r for r in rows if r.get("t") == "hit"]
    out.append("fight: %d hits, %d deaths (his %d, CPU %d)" % (len(hits), len(deaths),
               sum(1 for d in deaths if d.get("team") == 0), sum(1 for d in deaths if d.get("team") == 1)))
    arrivals = _load("recording_arrivals", os.path.join(ROOT, "tools", "recording_arrivals.py"))
    by_row = {id(o): units for o, units, _ in arrivals.per_order(rows)}
    clicks = clicks_of(rows)
    out.append("his clicks (%d; time, verb, squad:crews, spots, arrived in the window to the next order, worst best-distance):" % len(clicks))
    tail = []
    events = camera_events(rows)
    if not any(r.get("t") == "cam" for r in rows):
        tail.append("camera: no cam rows (a recording from before round 43)")
    else:
        judged = [(e, seen) for e, _, _, seen in events if seen is not None]
        off = [e for e, seen in judged if not seen]
        his = sum(1 for e in off if (e.get("target") or e.get("unit") or "").startswith("Green_"))
        tail.append("camera: %d of %d hits/deaths off screen (%d on his units, %d deaths); estimate: fov %.0f, 16:9" % (
            len(off), len(judged), his, sum(1 for e in off if e["t"] == "dead"), FOV_DEG))
    tail.append("replay: " + replay_verdict(replay_lines))
    tail.append("full report: %s%s" % (full_path, " (page %s)" % html_path if html_path else ""))
    room = min(CLICK_LINES, SUMMARY_MAX - len(out) - len(tail))  # never past one screen, whatever the match
    if len(clicks) > room:
        room -= 1
    for tick, verb, orders in clicks[:room]:
        out.append(click_line(tick, verb, orders, by_row, rate))
    if len(clicks) > room:
        out.append("  ... %d more clicks in the full report" % (len(clicks) - room))
    out += tail
    return out


def replay_verdict(lines):
    if lines is None:
        return "not run (make playtest-report runs it)"
    verdict = [l for l in lines if l.startswith("DIVERGENCE")]
    if not verdict:
        failed = [l for l in lines if l.startswith("replay:")]
        return (failed[-1] if failed else "no DIVERGENCE line") + " (see the full report)"
    keys = dict(kv.split("=", 1) for kv in verdict[-1].split()[1:] if "=" in kv)
    if keys.get("verdict") == "PASS":
        return "PASS, his match: %s of %s crews within %s for %s s" % (keys.get("within"), keys.get("crews"), keys.get("bar"),
                                                                       keys.get("seconds"))
    # Why it parted, when the replay knows: its own mismatch lines (tests/replay_orders.gd) and a seed it could not repeat.
    why = []
    if any(l.startswith("REPLAY_NATIVE_MISMATCH") for l in lines):
        why.append("native differs (make native)")
    roster = sum(1 for l in lines if l.startswith("REPLAY_ROSTER_MISMATCH"))
    if roster:
        why.append("%d roster mismatches" % roster)
    if any(l.startswith("REPLAY_REEXEC") and " --seed=-1 " in l + " " for l in lines):
        why.append("seed not recorded")
    return "FAIL, %s of %s crews within %s for %s s; first over %s%s" % (
        keys.get("within"), keys.get("crews"), keys.get("bar"), keys.get("seconds"), keys.get("first_over"),
        " (%s)" % ", ".join(why) if why else "")


# ---- the full report (written) ----------------------------------------------------------------------------------------

def section_match(rows, path):
    header = header_of(rows)
    end = rows[-1].get("tick", 0) if rows else 0
    rate = rate_of(rows)
    units = header.get("units", [])
    sides = {0: sum(1 for u in units if u.get("team") == 0), 1: sum(1 for u in units if u.get("team") == 1)}
    out = ["(a) THE MATCH", "  %s" % path,
           "  arena %s, seed %s, %.0f s, Green %d units v Rust %d" % (header.get("arena", "?"), seed_words(header),
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
    arrivals = _load("recording_arrivals", os.path.join(ROOT, "tools", "recording_arrivals.py"))
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        arrivals.report(path)
    out += ["  " + line for line in buf.getvalue().splitlines() if not line.startswith("===")]
    return out


def section_camera(rows):
    rate = rate_of(rows)
    out = ["(b) THE CAMERA AT EACH HIT AND DEATH (his screen's compass: the way the view looks; OFF = the victim off screen,"
           " estimated with fov %.0f on 16:9)" % FOV_DEG]
    if not any(r.get("t") == "cam" for r in rows):
        out.append("  no cam rows: a recording from before round 43 (camera K5.1 records the camera from then on)")
        return out
    camera = _load("camera_recording", os.path.join(ROOT, "tests", "camera", "camera_recording.py"))
    for e, c, _, seen in camera_events(rows):
        if e["t"] == "hit":
            what = "hit   %s%s %s%s" % (e["shooter"] + " -> " if e.get("shooter") else "", e.get("target", "?"), e.get("face", ""),
                                        " KILL" if e.get("killed") else "")
        else:
            what = "death %s (by %s)" % (e.get("unit", "?"), e.get("killer", "?"))
        if c is None:
            out.append("  %6.1f s  %-58s  (no camera yet)" % (e["tick"] / rate, what[:58]))
            continue
        out.append("  %6.1f s  %-58s  look %-2s %6.1f  at (%6.1f, %6.1f)  %s (cam row %.1f s)%s" % (
            e["tick"] / rate, what[:58], camera.compass(c["yaw"]), c["yaw"], c["target"][0], c["target"][1], c.get("mode", ""),
            c["tick"] / rate, "" if seen is None else ("  on" if seen else "  OFF")))
    return out


def section_replay(replay_lines, replay_path):
    out = ["(c) THE REPLAY (make replay-match, first 30 s, every crew; native library and trig shim through make)"]
    if replay_lines is None:
        out.append("  not run (pass --replay <replay-match output>, or use `make playtest-report`)"
                   if not replay_path else "  could not read %s" % replay_path)
        return out
    keep = [l for l in replay_lines if l.startswith(("REPLAY_", "NATIVE_EXEC", "crew ", "DIVERGENCE", "replay:"))
            or (l[:1].isalpha() and "  " in l and any(ch.isdigit() for ch in l[-6:]))]
    out += ["  " + l for l in keep] if keep else ["  (no replay output in %s)" % replay_path]
    verdict = [l for l in replay_lines if l.startswith("DIVERGENCE")]
    out.append("  -> " + ("the replay IS his match for these 30 s" if verdict and "verdict=PASS" in verdict[-1]
                          else "the replay leaves his match: read the first_over crew before trusting it"))
    return out


def page(text):
    return ("<!doctype html><meta charset=utf-8><title>Playtest report</title>"
            "<style>body{font:13px/1.4 ui-monospace,monospace;margin:16px;background:#fff;color:#111}"
            "@media (prefers-color-scheme:dark){body{background:#111;color:#ddd}}pre{white-space:pre-wrap}</style>"
            "<h1 style='font:600 18px system-ui'>Playtest report</h1><pre>%s</pre>" % html.escape(text))


def default_out(recording):
    name = os.path.basename(recording)
    for ext in (".gz", ".jsonl"):
        if name.endswith(ext):
            name = name[:-len(ext)]
    return os.path.join(ROOT, "build", "playtest-report", name + ".txt")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("recording")
    ap.add_argument("--replay", default="")
    ap.add_argument("--out", default="", help="the full report (default build/playtest-report/<recording>.txt)")
    ap.add_argument("--html", default="", help="the full report as a page (default: --out with .html)")
    args = ap.parse_args(argv)
    rows = rows_of(args.recording)
    replay_lines = None
    if args.replay:
        try:
            with open(args.replay) as handle:
                replay_lines = handle.read().splitlines()
        except OSError:
            replay_lines = None
    full_path = args.out or default_out(args.recording)
    html_path = args.html or os.path.splitext(full_path)[0] + ".html"
    head = summary(rows, args.recording, replay_lines, full_path, html_path)
    full = head + ["", "=" * 100, ""] + section_match(rows, args.recording) + [""] + section_camera(rows) + [""] + \
        section_replay(replay_lines, args.replay)
    for target, body in ((full_path, "\n".join(full) + "\n"), (html_path, page("\n".join(full)))):
        os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
        with open(target, "w") as handle:
            handle.write(body)
    print("\n".join(head))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
