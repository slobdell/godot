# O0 / O1 output-identical proof (CP44.0): the G1 v9 probe, 716e6304e v main 711f3e94f

builder0 light lane, 2026-10-28 ~09:40-10:05 PDT, both trees synced from the laptop (`tools/remote.sh --light orders-probe
ORDERS_PROBE_SQUADS=5 ORDERS_PROBE_ROUTES=click "ORDERS_PROBE_ARMS=main:" "ORDERS_PROBE_SEEDS=7001 7002 7003 7004"`), the
shape of manoeuvre's R43.34 proof: locks / crossing / terminus x 7001-7004, five squads, his click, 60 squad rows a tree.
Native: OFF in both trees (the light lane's folders carry no C++ library; the layout under test is GDScript, the drive is not in question).

Result: **60 / 60 rows byte-identical** (rows sorted by map, seed, squad; every key equal). The `group` key on the element's
task and the `click` / `group` keys on the recorder's order row change no place, no arrival and no contact.
