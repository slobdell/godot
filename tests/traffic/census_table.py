#!/usr/bin/env python3
"""Round 26 (traffic T1/T3): pool `make traffic-census` (build/traffic-census.jsonl) by arena and army size.

Per case and pooled: crew-seconds under way, stuck crew-seconds and their split by what was in the way (friendly,
enemy, static), the FRIENDLY share of all stuck time (his clump hypothesis), friendly contacts (fast ones), k-turns with
a friend at the nose.
"""
import json
import sys
from collections import defaultdict


def main(path):
    rows = [json.loads(l) for l in open(path) if l.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    groups = defaultdict(list)
    for r in rows:
        groups["%s@%s" % (r["arena"], r["credits"])].append(r)
    groups["ALL"] = rows
    print("TRAFFIC_CENSUS_TABLE %s (%d runs, %d missing)" % (path, len(rows), len(missing)))
    print("%-16s %4s %9s %8s %8s %8s %8s %7s %7s %5s %6s %6s" % (
        "case", "runs", "underway", "stuck", "friend", "enemy", "static", "f_share", "contact", "fast", "kturn", "kt_fr"))
    out = {}
    for key in sorted(groups):
        g = groups[key]
        if not g:
            continue
        tot = {k: sum(r[k] for r in g) for k in ("under_way_s", "stuck_s", "stuck_friend_s", "stuck_enemy_s",
                                                 "stuck_static_s", "contacts_friend", "contacts_friend_fast",
                                                 "kturns", "kturns_friend")}
        share = tot["stuck_friend_s"] / tot["stuck_s"] if tot["stuck_s"] else 0.0
        out[key] = dict(tot, runs=len(g), friend_share=round(share, 3))
        print("%-16s %4d %9.0f %8.0f %8.0f %8.0f %8.0f %7.3f %7d %5d %6d %6d" % (
            key, len(g), tot["under_way_s"], tot["stuck_s"], tot["stuck_friend_s"], tot["stuck_enemy_s"],
            tot["stuck_static_s"], share, tot["contacts_friend"], tot["contacts_friend_fast"], tot["kturns"],
            tot["kturns_friend"]))
    print("set-up hulls (T1c): repacks (all / while giving way), give-ways begun set up, asks refused set up, artillery shots:")
    for key in sorted(groups):
        g = groups[key]
        if g:
            t1c = {k: sum(r.get(k, 0) for r in g) for k in ("repacks", "repacks_yield", "deployed_yields", "setup_refusals",
                                                             "art_shots")}
            out[key].update(t1c)
            print("  %-16s repacks %4d / %3d  deployed_yields %3d  setup_refusals %4d  art_shots %5d" % (
                key, t1c["repacks"], t1c["repacks_yield"], t1c["deployed_yields"], t1c["setup_refusals"], t1c["art_shots"]))
    print("TRAFFIC_CENSUS_SUMMARY " + json.dumps(out, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/traffic-census.jsonl")
