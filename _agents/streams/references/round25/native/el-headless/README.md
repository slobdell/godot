# native_el, the headless second reading on the water maps (round 25, N5b)

`b65c19b3` (the Locks) and `49e2bdcd` (the Crossing): both `fccc520c` + N5a tooling and docs, no game code; builder0 light lane, `make native-tp-headless PROF_ARENA=<map>
NATIVE_TP_WINDOW=12,24`, 25 a side with leaders, arms `on` (shipped) and `el` (`--brains-on=native_el`), one seed per
remote run, arms ABBA by seed (92721 on,el; 31337 el,on; 5988 on,el). builder0's load swung the whole tick 26 <-> 46 ms
between runs, so read the elements segment's SHARE of the tick (and the pair where the tank segment is flat). Every
pair's state hash is equal (the port is equal-answer on both maps).

| map | seed | elements on | elements el | share on -> el |
|---|---|---|---|---|
| locks | 92721 | 9.17 | 4.52 | 19.8 -> 16.6 % |
| locks | 31337 | 5.38 | 6.98 | 19.9 -> 15.4 % |
| locks | 5988 | 5.74 | 4.33 | 21.7 -> 17.3 % (tank flat: the clean pair, -1.41 ms) |
| crossing | 92721 | 8.23 | 7.28 | 29.1 -> 22.2 % |
| crossing | 31337 | 11.16 | 8.55 | 30.3 -> 23.5 % |
| crossing | 5988 | 8.48 | 6.47 | 28.5 -> 22.4 % |

The ruling is the laptop's (windowed, in contact): `references/round25/perf/laptop/`.
