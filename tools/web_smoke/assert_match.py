#!/usr/bin/env python3
"""Judge a browser match the way a player would notice it (ship W3, round 17). Usage:

    assert_match.py <report.json> [--expect tools/web_pack/web_expect.json]

Reads observe.mjs's report (console, failed requests, the audio dBFS timeline) and fails on what lesson 239's class
would do to a player: the game reaches for something an export left out. Each rule names the thing the player loses:

  boot      TANK_SQUAD_READY, no uncaught exception, no console error, no request answered 4xx/5xx or failed
  music     the soundtrack found its tracks (`MUSIC on: N beds`, N > 0; never `MUSIC no tracks`)
  sound     something was HEARD: the WebAudio output rose above -60 dBFS at least once after the match started
            (an excluded sound folder fails silently in the log, never in the ears)
  voice     the booth is in the state this build declares (web_expect.json `voice`): "subtitles" = the clip-less
            state is announced and nothing claims a voice; "fetch" = the voice joined and spoke at least one line
            (`VOICE_LINE local|late`), and no line was lost to a failed fetch
  match     the match ran: the armies were placed (`SKIRMISH_ARMY` twice)
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--expect", default=os.path.join(ROOT, "tools/web_pack/web_expect.json"))
    ap.add_argument("--voice", help="override the expected voice state (subtitles|fetch)")
    a = ap.parse_args()
    report = json.load(open(a.report))
    expect = json.load(open(a.expect))
    voice_mode = a.voice or expect["voice"]
    lines = [c["text"] for c in report.get("console", []) if c.get("type") != "observer"]
    text = "\n".join(lines)
    fails, notes = [], []

    def need(ok, rule, why):
        (notes if ok else fails).append(f"{'ok  ' if ok else 'FAIL'} {rule}: {why}")

    ready = report.get("marks", {}).get("ready")
    need(ready is not None, "boot", f"TANK_SQUAD_READY at {ready}s" if ready else "the game never logged TANK_SQUAD_READY")
    errors = [c["text"] for c in report.get("console", []) if c.get("type") == "error"] + report.get("errors", [])
    need(not errors, "boot", "no console error / uncaught exception" if not errors else "; ".join(e[:160] for e in errors[:4]))
    # net::ERR_ABORTED is the page cancelling its own request (the loader's duplicate fetch), not a missing file.
    bad = [r for r in report.get("responses", []) if r.get("status", 200) >= 400] + \
        [r for r in report.get("failed_requests", []) if "ERR_ABORTED" not in str(r.get("why"))]
    need(not bad, "boot", "every request answered" if not bad else "; ".join(f"{r.get('url')} {r.get('status', r.get('why'))}" for r in bad[:4]))

    m = re.search(r"MUSIC on: (\d+) beds", text)
    need(bool(m) and int(m.group(1)) > 0 and "MUSIC no tracks" not in text, "music",
         f"{m.group(1)} beds" if m else "no `MUSIC on:` line (the soundtrack never started)")

    armies = len(re.findall(r"^SKIRMISH_ARMY ", text, re.M))
    need(armies >= 2, "match", f"{armies} armies placed")

    # The audio thread's record (an AudioWorklet that sees every block) is the witness; the analyser samples taken on a
    # starved main thread are only a fallback for a browser where the worklet failed to load.
    at = report.get("audio_thread") or {}
    if expect.get("sound", "require") == "measure":
        def need_sound(ok, rule, why):
            notes.append(f"{'ok  ' if ok else 'MEASURE'} {rule} (measured, not required: web_expect.json): {why}")
    else:
        need_sound = need
    if at.get("records") and expect.get("sound", "require") == "require":
        # Required since guns' bus-layout fix (main f93f3cb4): heard, early, and EFFECTS, not only the music. In Sample
        # mode every sound the engine plays is a buffer source; a bed is long (>= 15 s), an effect short (< 6 s).
        peak = at.get("peak_db") if at.get("peak_db") is not None else -200
        ready = (report.get("marks") or {}).get("ready") or 0
        first = at.get("first_loud_t")
        within = float(expect.get("first_sound_within_s", 30))
        need(peak > -60, "sound", f"heard: peak {peak} dBFS, {at['loud_block_fraction'] * 100:.0f}% of {at['audio_seconds']} s of audio blocks loud (page {at['median_fps']} fps)"
             if peak > -60 else f"the page made NO sound in {at['audio_seconds']} s (peak {peak} dBFS)")
        need(first is not None and first - ready <= within, "sound",
             f"first sound {first - ready:.1f} s after READY (bound {within:.0f} s)" if first is not None else "no first sound")
        starts = (report.get("audio") or {}).get("starts", [])
        if report.get("playback", "sample") == "sample" or starts:
            effects = [x for x in starts if x.get("seconds") is not None and x["seconds"] < 6]
            need(bool(effects), "sound", f"{len(effects)} effects started (short buffers), {len(starts) - len(effects)} longer"
                 if effects else f"no sound EFFECT was started ({len(starts)} sources, all long: music only)")
    elif at.get("records"):
        peak = at.get("peak_db") if at.get("peak_db") is not None else -200
        need_sound(peak > -60, "sound", f"heard: peak {peak} dBFS, {at['loud_block_fraction'] * 100:.1f}% of {at['audio_seconds']} s "
             f"of audio blocks above -60 dBFS, first at {at['first_loud_t']} s (page {at['median_fps']} fps)"
             if peak > -60 else f"the page made NO sound in {at['audio_seconds']} s of audio (peak {peak} dBFS; page {at['median_fps']} fps)")
    else:
        samples = (report.get("audio") or {}).get("samples", [])
        loud = [s for s in samples if s["db"] > -60]
        peak = max((s["db"] for s in samples), default=-200)
        need_sound(bool(loud), "sound", f"{len(loud)}/{len(samples)} analyser samples above -60 dBFS, peak {peak:.1f} (no worklet: {at.get('error')})"
             if loud else f"the page made NO sound in {len(samples)} analyser samples (peak {peak:.1f} dBFS; no worklet: {at.get('error')})")

    if voice_mode == "subtitles":
        need("ANNOUNCER no recorded clips" in text and "ANNOUNCER voice" not in text, "voice",
             "subtitles only, as this build declares" if "ANNOUNCER no recorded clips" in text
             else "the booth did not announce its clip-less state")
    else:
        joined = "ANNOUNCER voice joined" in text
        spoken = len(re.findall(r"^VOICE_LINE (local|late) ", text, re.M))
        failed = len(re.findall(r"^VOICE_LINE missed .*fetch failed|^VOICE_FETCH clip FAILED", text, re.M))
        late = [float(x) for x in re.findall(r"^VOICE_LINE late ([0-9.]+) s", text, re.M)]
        arrived_late = len(re.findall(r"^VOICE_LINE missed .*\(arrived late\)", text, re.M))
        need(joined, "voice", "the voice joined" if joined else "the voice never joined (manifest not fetched?)")
        # The gate is the PATH: a line was cued, its clip was fetched and arrived. Whether it arrived inside LATE_S is
        # frame rate (builder0's SwiftShader runs the match at ~2 fps): spoken lines are reported, not required.
        need(spoken + arrived_late > 0, "voice", f"{spoken + arrived_late} cued clips arrived: {spoken} spoken "
             f"({len(late)} late, worst {max(late, default=0):.2f}s), {arrived_late} too late to speak")
        notes.append(f"{'ok  ' if spoken else 'MEASURE'} voice spoken: {spoken} lines (reported; at very low frame rates clips arrive after LATE_S)")
        need(failed == 0, "voice", "no clip fetch failed" if not failed else f"{failed} clip fetches failed")

    for pack in expect.get("packs", []):
        m = re.search(rf"^WEB_PACK loaded {re.escape(pack)} \((.*)\)$", text, re.M)
        need(bool(m), "packs", f"{pack}: {m.group(1)}" if m else f"{pack}: never loaded (the three factions' art would be stand-ins)")

    for line in notes + fails:
        print("  " + line)
    if fails:
        print(f"WEB MATCH SMOKE FAILED ({len(fails)}): a browser player loses what the FAIL lines name")
        return 1
    print("WEB MATCH SMOKE PASSED: boots, plays, sounds, and the booth is what this build declares")
    return 0


if __name__ == "__main__":
    sys.exit(main())
