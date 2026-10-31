#!/usr/bin/env python3
"""Spotter S4: the judging page's `clips` documents for one batch, ready for the session's ArtifactData batch write.

    python3 tools/spotter/judge_docs.py <fights dir> <urls.txt> <out dir> --batch NAME --commit HASH
        urls.txt: one "<clip file stem> <asset id>" a line, from the Artifact asset upload of <fights dir>/clips/*.mp4
        -> <out dir>/<doc id>.json (one per clip) and <out dir>/writes.json (the batch's `writes`, file_path entries)

Each document carries what the page shows (crew, map, seconds, reasons, the reproduction line, the video) and what S5 / S6 read
(signals, surprise_max, signals_max, length_s, choice, score, drift_m).
"""
import argparse
import json
import os


def docs(clips, urls, batch, commit):
    out = []
    for c in clips:
        if not c.get("file") or not c.get("reproduced"):
            continue  # a clip that did not reproduce its moment is a bug, never shown as evidence
        key, m = c["file"][:-4], c["moment"]
        out.append((key, {
            "order": c["index"], "batch": batch, "commit": commit, "machine": "builder3",
            "crew": m["crew"], "unit": m["unit"], "team": m["team"], "arena": m["arena"], "seed": m["seed"],
            "seconds": f"{m['clip']['from_s']}-{m['clip']['to_s']} s", "score": m["score"], "length_s": m["length_s"],
            "choice": m.get("context", {}).get("choice", ""),
            "reasons": [f"{r['words']} ({r['value']:g} {r['unit']})" for r in m["reasons"]],
            "signals": [r["signal"] for r in m["reasons"]],
            "surprise_max": m.get("surprise_max", {}), "signals_max": m.get("signals_max", {}),
            "repro": c["repro"], "drift_m": c["drift_m"], "video_url": "/_blob/" + urls[key], "video_id": urls[key]}))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("fight_dir")
    ap.add_argument("urls")
    ap.add_argument("out_dir")
    ap.add_argument("--batch", required=True)
    ap.add_argument("--commit", required=True)
    args = ap.parse_args()
    urls = dict(line.split() for line in open(args.urls) if line.strip())
    clips = json.load(open(os.path.join(args.fight_dir, "clips.json")))["clips"]
    os.makedirs(args.out_dir, exist_ok=True)
    writes = []
    for key, body in docs(clips, urls, args.batch, args.commit):
        path = os.path.join(os.path.abspath(args.out_dir), key + ".json")
        json.dump(body, open(path, "w"))
        writes.append({"op": "set", "collection": "clips", "doc_id": key, "file_path": path})
    json.dump(writes, open(os.path.join(args.out_dir, "writes.json"), "w"))
    print(f"judge_docs: {len(writes)} clip documents -> {args.out_dir}/writes.json")


if __name__ == "__main__":
    main()
