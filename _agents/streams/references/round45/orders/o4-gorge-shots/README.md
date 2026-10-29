# O4 (round 45, orders): his Gorge click top-down, guard OFF v ON

`make orders-probe-shots ORDERS_PROBE_MAPS=gorge ORDERS_PROBE_SHOT_SQUADS=4 ORDERS_PROBE_SHOT_ROUTES=click
ORDERS_PROBE_SHOT_ARMS="base:--group-guard=off,--probe-click=-43.2/53.2,--probe-budget=3000,--probe-army=res://tests/control/orders_probe_his_4.json
g2:--probe-click=-43.2/53.2,--probe-budget=3000,--probe-army=res://tests/control/orders_probe_his_4.json"` on the laptop (code 4f7525afa +
the probe's longer wait for the controls), his round-43 four-squad army at Gorge's spawn, one click at his (-43.2, 53.2), the frame
five seconds after arrival (desktop 1280x720). His base is at the bottom; the three near drops are the red boxes.

- `gorge-4-click-base-arrival_plus5-desktop.png` (guard OFF, today): four destinations four ways; the blue one ACROSS the middle drop
  toward the enemy, the red one at the west wall, the squads scattered; the probe's all-in 36.1 s.
- `gorge-4-click-g2-arrival_plus5-desktop.png` (guard ON): the four places on his side of the drops in one body behind his click
  (the white marker at the neck's mouth), nobody across; all-in 3.1 s.
The exact places of HIS three-squad click are in tests/test_control_his_gorge_click.gd and the replay read (orders.md Status, O4).
