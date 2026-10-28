# G1 v10 switch-off output proof (R44.23): the G1 v9 probe, 805eae5e1 (switch off) v the O0 record 716e6304e

builder0 light lane, 2026-10-28 15:54-15:56 PDT (laptop clock), from a scratch worktree at exactly 805eae5e1 (the frozen tree the
orchestrator merges OFF): `tools/remote.sh --light orders-probe ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_ROUTES=click "ORDERS_PROBE_ARMS=main:"
"ORDERS_PROBE_SEEDS=7001 7002 7003 7004"`, the o0 recipe (locks / crossing / terminus x 7001-7004, five squads, his click, 60 squad rows).
Native OFF (the light lane carries no C++ library; the layout under test is GDScript). `--group-column=always` not given: the default, OFF.

Compared row for row (sorted by map, seed, squad, element; every key) against
`../o0-probe-identical-builder0-716e6304e/rows-716e6304e.jsonl`, which equalled main 711f3e94f's rows.

Result: **60 / 60 rows byte-identical** (result.txt). The v10 column code (e2d1b499f and the commits before it, all under
`SelectionSquads.COLUMN_ALWAYS`) changes no place, no arrival and no contact with the switch off.
