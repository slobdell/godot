#!/usr/bin/env python3
"""`make metrics LOGS=...` — A12's four metrics over one or more trajectory logs.

Every falsifier in `_agents/research_catalog.md` that names cusp density, displacement efficiency, spectral arc
length or formation residual is read from here and from no other tool (contract S3).

Usage:
    make metrics LOGS="build/metrics/*.jsonl"
    make metrics LOGS=... METRICS_JSON=build/metrics/report.json
"""

from __future__ import annotations

import argparse
import glob
import json
import sys

import metrics
from trajlog import TrajectoryLogError, read_log


def _fmt(value, digits=3, width=9):
    if value is None:
        return "-".rjust(width)
    return ("%.*f" % (digits, value)).rjust(width)


def _facing(cells):
    """`null` when the column is absent, a number when it is there. Never a bare 0.0 for missing data: a log
    written before `facing_arc` existed printed `arc_live=0.0s` in both arms of an A/B, which reads as a
    measurement of behaviour (nav, 2026-09-20)."""
    bits = []
    for label, key in (("ordered_facing", "facing_ordered_seconds"), ("arc_live", "facing_arc_seconds")):
        value = cells[key]
        if value is None:
            bits.append("%s=null" % label)        # no data: absent, or present and every value null
        else:
            bits.append("%s=%.1fs" % (label, value))   # a real measurement, INCLUDING a real 0.0
    return (" " + " ".join(bits)) if bits else ""


def _corridor(cells):
    """A6's falsifier, with its active fraction welded to it. `null` when the producer's build has no corridor
    key: the fraction cannot be computed and no verdict may be published from that log."""
    if cells["off_corridor_fraction"] is None:
        return " off_corridor=null"
    return (" off_corridor=%.3f (active %.3f, %d ticks; inactive %d, slow %d, ordered_arc %d)"
            % (cells["off_corridor_fraction"], cells["corridor_active_fraction"],
               cells["corridor_active_ticks"], cells["corridor_inactive_ticks"],
               cells["corridor_below_speed_ticks"], cells["corridor_ordered_arc_ticks"]))


def print_report(row, handle):
    head = row["by_unit_id"]
    write = handle.write
    write("METRICS %s\n" % row["provenance"])
    write("        log=%s samples=%d units=%d window=%.1fs (%d ticks)  sparc_window=%d samples, nfft=%d, "
          "cutoff=%.0f rad/s\n" % (row["path"], row["samples"], row["units"], row["window_s"], row["window_ticks"],
                                   row["sparc_window_samples"], row["sparc_nfft"], row["sparc_cutoff_rad_s"]))
    if row["oscillating_order_verb"]:
        write("        `osc_share` counts only ticks under order_verb=%s (fight_probe.gd's --stall-verb).\n"
              % row["oscillating_order_verb"])
    # Keyed on whether any arc value was actually KNOWN, not on the column name: the column can be present and
    # every value null, which is the case nav's pre-publication logs are in.
    if row["all"]["facing_arc_seconds"] is None:
        write("        NOTE: no `facing_arc` DATA (the column is absent, or present and null throughout). A LIVE\n"
              "        arrival arc is off-corridor by construction and is the\n"
              "        unit obeying, not a pathology -- and `facing_ordered` is not a substitute: an order carries\n"
              "        its facing for the whole journey. Without `facing_arc`, no off-corridor verdict may be\n"
              "        published from this log (FORMAT.md).\n")
    if not row["cause_columns"]:
        write("        NOTE: this log has no cause columns, so every cusp is reported as unclassified "
              "(FORMAT.md: order_reverse / phase / creeping).\n")
    if len(row["teams"]) > 1:
        write("        NOTE: this log holds BOTH armies, and the two kinds of statistic behave DIFFERENTLY.\n"
              "        GATED on orders and so unaffected: osc_share, osc_units, net/path, under_way.\n"
              "        UNGATED and therefore DILUTED by the unordered side: eff_mean, eff_p10, cusp/min, sparc.\n"
              "        Pass --team to compare the ungated ones. (nav read eff_mean 0.717 unfiltered against\n"
              "        0.833 for the ordered side alone, from the same log -- while net/path was identical.)\n")
    write("  %-16s %5s %7s %9s %9s %9s %9s %9s %9s %7s %9s\n" % (
        "unit_id", "units", "ordered", "eff_mean", "eff_p10", "osc_share", "osc_units", "net/path", "cusp/min",
        "cusps", "sparc"))
    for unit_id in list(head) + ["ALL"]:
        cells = head[unit_id] if unit_id != "ALL" else row["all"]
        write("  %-16s %5d %7d %s %s %s %9d %s %s %7d %s\n" % (
            unit_id, cells["units"], cells["units_ordered"],
            _fmt(cells["efficiency_mean"]), _fmt(cells["efficiency_p10"]),
            _fmt(cells["oscillating_share"]), cells["oscillating_units"], _fmt(cells["net_over_path"]),
            _fmt(cells["cusps_per_agent_minute"], 2), cells["cusps"], _fmt(cells["sparc_mean"])))
    for unit_id in list(head) + ["ALL"]:
        cells = head[unit_id] if unit_id != "ALL" else row["all"]
        write("      %-14s under_way=%.1fs agent_min=%.2f eff_windows=%d sparc_windows=%d "
              "cusps[ordered=%d creep=%d unexplained=%d unclassified=%d] "
              "refused[zero_path=%d parked=%d short=%d]%s\n" % (
                  unit_id, cells["under_way_seconds"], cells["agent_minutes"], cells["efficiency_windows"],
                  cells["sparc_windows"], cells["cusps_ordered"], cells["cusps_creep"], cells["cusps_unexplained"],
                  cells["cusps_unclassified"], cells["efficiency_refused_zero_path"],
                  cells["sparc_refused_parked"], cells["sparc_refused_short"],
                  # Beside the fractions, never inside them.
                  _facing(cells) + _corridor(cells)))
    turns = row.get("turns")
    if turns:
        write("  hull TURN between consecutive events (degrees; the HULL's own rotation, not a bearing to any\n"
              "  target -- nothing in a trajectory log knows what a unit was shooting at):\n")
        write("  %-16s %8s %10s %9s %9s %9s %9s %9s\n" % (
            "unit_id", "events", "intervals", "mean", "p10", "p50", "p90", "<15 deg"))
        for unit_id, cells in turns["by_unit_id"].items():
            write("  %-16s %8d %10d %s %s %s %s %s\n" % (
                unit_id, cells["events"], cells["intervals"], _fmt(cells["turn_deg_mean"], 1),
                _fmt(cells["turn_deg_p10"], 1), _fmt(cells["turn_deg_p50"], 1), _fmt(cells["turn_deg_p90"], 1),
                _fmt(cells["share_under_15_deg"], 3)))
        if turns["unknown_units"]:
            write("  NOTE: %d event unit(s) are not in this log (%s...) -- wrong arm's events?\n" % (
                len(turns["unknown_units"]), ", ".join(turns["unknown_units"][:3])))
    if row["by_element"]:
        write("  %-10s %12s %8s %8s %10s %6s\n" % (
            "element", "residual_rms", "ticks", "members", "too_small", "rank"))
        for element, cells in row["by_element"].items():
            write("  %-10s %s %8d %8d %10d %6d\n" % (
                element, _fmt(cells["residual_rms_mean"], 3, 12), cells["ticks"], cells["members"],
                cells["refused_too_small"], cells["reference_rank"]))
    else:
        write("  no element/slot columns in this log: the affine formation residual has nothing to fit.\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("logs", nargs="+", help="trajectory logs (.jsonl or .jsonl.gz); globs are expanded")
    parser.add_argument("--json", dest="json_out", default="", help="also write the whole report here, as JSON")
    parser.add_argument("--pool", action="store_true",
                        help="also print ONE pooled row over all the logs, weighted by ticks -- nav's rotation "
                             "figure across several maps in one command. The per-file lines are kept.")
    parser.add_argument("--switches", default="",
                        help="a JSON file {unit name: [tick, ...]} of decision events; also reports the hull TURN "
                             "between consecutive events per unit type (combat's A2 bearing read)")
    parser.add_argument("--order-verb", default=None,
                        help="count the `oscillating` special case only under this order verb -- fight_probe.gd's "
                             "--stall-verb. Round 8's headline is attack_move")
    parser.add_argument("--team", type=int, default=None,
                        help="report only this team's units (0 = GREEN, 1 = RUST); default: every unit in the log")
    args = parser.parse_args(argv)

    paths = []
    for pattern in args.logs:
        found = sorted(glob.glob(pattern)) or ([pattern] if "*" not in pattern else [])
        if not found:
            print("metrics: %s matched no log" % pattern, file=sys.stderr)
            return 2
        paths.extend(found)

    rows = []
    for path in paths:
        try:
            log = read_log(path)
        except TrajectoryLogError as error:
            # Invariant 0: a log we cannot read never becomes a report that says nothing happened.
            print("metrics: REFUSED %s" % error, file=sys.stderr)
            return 1
        span = metrics.window_samples(log.header.tick_rate)
        longest = max((len(s) for s in log.units.values()), default=0)
        if longest < span:
            print("metrics: REFUSED %s: the longest unit has %d samples, under one %d-tick window. A metric over "
                  "less than one window is not a smaller number, it is no number." % (path, longest, span),
                  file=sys.stderr)
            return 1
        if args.team is not None:
            log.units = {n: s for n, s in log.units.items() if s and s[0].team == args.team}
            if not log.units:
                print("metrics: REFUSED %s: --team=%d matched no unit in this log" % (path, args.team),
                      file=sys.stderr)
                return 1
        row = metrics.report(log, args.order_verb)
        if args.switches:
            with open(args.switches, encoding="utf-8") as handle:
                events = json.load(handle)
            # Two shapes accepted: the bare map, and a wrapper that keeps the ticks beside whatever the producer
            # recorded about each event. combat writes the second so a pair cannot be assembled from two runs --
            # a good enough reason that it should not need a second file format to be read.
            if isinstance(events, dict) and isinstance(events.get("switches"), dict):
                events = events["switches"]
            if not isinstance(events, dict) or not all(isinstance(v, list) for v in events.values()):
                print("metrics: REFUSED %s: expected {unit: [tick, ...]}, or {\"switches\": {unit: [tick, ...]}}"
                      % args.switches, file=sys.stderr)
                return 1
            row["turns"] = metrics.turn_report(log, events)
        rows.append(row)
        print_report(row, sys.stdout)
    if args.pool:
        if len(rows) < 2:
            print("metrics: REFUSED --pool over %d log(s): pooling one file is the file." % len(rows),
                  file=sys.stderr)
            return 1
        pooled = metrics.pool(rows)
        p = pooled["pooled"]
        print("")
        print("POOLED over %d logs (%s): %s" % (
            pooled["files"], ", ".join(str(a) for a in pooled["arenas"]),
            "commit %s, %s" % (pooled["commits"][0], pooled["machines"][0])))
        if pooled["mixed_commits"] or pooled["mixed_machines"]:
            print("  ⚠ REFUSE TO QUOTE THIS: pooled across %s%s%s. Numbers from different trees or different"
                  % ("commits " + ",".join(pooled["commits"]) if pooled["mixed_commits"] else "",
                     " and " if pooled["mixed_commits"] and pooled["mixed_machines"] else "",
                     "machines " + ",".join(pooled["machines"]) if pooled["mixed_machines"] else ""))
            print("    machines are not one measurement (CLAUDE.md rule 4; the laptop is ~2.75x slower).")
            # Tell the reader how to CHECK rather than leaving them to assume. The first time this banner fired
            # on real data, the answer was "docs only, the pool stands" -- which is exactly the outcome that
            # makes a warning get ignored next time unless verifying it is one command.
            commits = pooled["commits"]
            for i in range(len(commits) - 1):
                print("    verify it is inert:  git diff --stat %s %s" % (commits[i], commits[i + 1]))
            if len(commits) > 1:
                print("    if that touches game/ or tests/, re-run the odd log at the other commit and re-pool;")
                print("    \"nothing relevant changed\" is the assumption this project keeps paying for.")
        print("  weighted by TICKS, not by averaging the per-file fractions -- a mean would weight a 30 s log")
        print("  the same as a 120 s one. Per-file rows above; a map that disagrees with the pool is visible there.")
        print("  oscillating_share %s over %s s under way | cusps %d (%s/agent-min)" % (
            _fmt(p["oscillating_share"], 4, 6).strip(), p["under_way_seconds"], p["cusps"],
            _fmt(p["cusps_per_agent_minute"], 2, 5).strip()))
        print("  off_corridor %s (active %s over %d ticks)" % (
            "null" if p["off_corridor_fraction"] is None else "%.4f" % p["off_corridor_fraction"],
            "null" if p["corridor_active_fraction"] is None else "%.4f" % p["corridor_active_fraction"],
            p["corridor_active_ticks"]))
        rows.append({"pooled": pooled})

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as handle:
            json.dump(rows, handle, indent=2, sort_keys=True)
        print("metrics: wrote %s (%d log%s)" % (args.json_out, len(rows), "" if len(rows) == 1 else "s"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
