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
    if "facing_arc" not in row["columns"]:
        write("        NOTE: no `facing_arc` column. A LIVE arrival arc is off-corridor by construction and is the\n"
              "        unit obeying, not a pathology -- and `facing_ordered` is not a substitute: an order carries\n"
              "        its facing for the whole journey. Without `facing_arc`, no off-corridor verdict may be\n"
              "        published from this log (FORMAT.md).\n")
    if not row["cause_columns"]:
        write("        NOTE: this log has no cause columns, so every cusp is reported as unclassified "
              "(FORMAT.md: order_reverse / phase / creeping).\n")
    if len(row["teams"]) > 1:
        write("        NOTE: this log holds BOTH armies. Only the ordered side has goals, so `osc_share` and\n"
              "        `net/path` are already over ordered ticks alone, but `units` counts everyone: read\n"
              "        `ordered` beside it, or pass --team.\n")
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
                  (" ordered_facing=%.1fs arc_live=%.1fs"
                   % (cells["facing_ordered_seconds"], cells["facing_arc_seconds"]))
                  if cells["facing_ordered_seconds"] or cells["facing_arc_seconds"] else ""))
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
            if not isinstance(events, dict):
                print("metrics: REFUSED %s: expected an object {unit: [tick, ...]}" % args.switches,
                      file=sys.stderr)
                return 1
            row["turns"] = metrics.turn_report(log, events)
        rows.append(row)
        print_report(row, sys.stdout)
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as handle:
            json.dump(rows, handle, indent=2, sort_keys=True)
        print("metrics: wrote %s (%d log%s)" % (args.json_out, len(rows), "" if len(rows) == 1 else "s"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
