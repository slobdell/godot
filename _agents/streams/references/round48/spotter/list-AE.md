# Spotter class lists: A, E (classes v4 (2026-10-31; v3 + F, A-E unchanged))
main df9aacc1a, builder3, 576 fights (13121-13216 x 6 maps, 240 s, native); 576 fights, seeds 13121-13216 (96), maps crossing gorge locks parade sumps terminus. The 10 longest moments of each class (and each cause), by flagged crew-seconds. Every row is one second (the probe's own fields; blocker_* is the named blocker's own row at that tick).

## A. hurt crews retreat by abandoning the squad (engage): 0.14 moments / fight, 0.5 crew-s / fight

82 moments; by map: crossing 15, gorge 6, locks 21, parade 17, sumps 16, terminus 7

- **Rust_Eyes_3** (scout, team 1) parade seed 13184, 110-129 s, 18 flagged s
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=parade SPOT_CREW=Rust_Eyes_3 SPOT_FROM=108 SPOT_TO=120`

| s | speed | hp | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 112 | 7.67 | 1 | RETREAT | driving | 3.4 |  |  | 65.5 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 113 | 0 | 1 | RETREAT | arrived | 2.1 |  |  | 69.2 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 114 | -4.9 | 1 | RETREAT | driving | 86.6 |  | 130.7 | 70.9 | 0 | 45 | 0 | RETREAT - back to its squad |
| 115 | 4.51 | 1 | RETREAT | driving | 89.8 |  | 90.9 | 71.9 | 0 | 45 | 0 | RETREAT - back to its squad |
| 116 | 4.53 | 1 | RETREAT | driving | 9.2 |  | 178 | 67.5 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 117 | -5.13 | 1 | RETREAT | driving | 5.8 |  | 177.1 | 69 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 118 | 0 | 1 | RETREAT | arrived | 2.9 |  | 179.4 | 70.4 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 119 | 0 | 1 | RETREAT | arrived | 2.9 |  | 179.4 | 70.1 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 120 | 0 | 1 | RETREAT | arrived | 2.9 |  | 179.4 | 68.5 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 121 | 0 | 1 | RETREAT | arrived | 2.9 | 6.3 | 179.4 | 65.6 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 122 | 0 | 1 | RETREAT | arrived | 2.9 | 2.9 | 179.4 | 65.1 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 123 | 0 | 1 | RETREAT | arrived | 2.9 | 0 | 179.4 | 65.1 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 124 | 0 | 1 | RETREAT | arrived | 2.9 | 0 | 179.4 | 66.8 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| 125 | 0 | 1 | RETREAT | arrived | 2.9 | 0 | 179.4 | 66.6 | 0 | 45 | 0 | RETREAT - breaking line of sight |
| ... 4 more seconds | | | | | | | | | | | | |

- **Rust_Hunters2_1** (law_ifv, team 1) sumps seed 13138, 16-36 s, 17 flagged s
  `make spotter-clip SPOT_SEED=13138 SPOT_ARENA=sumps SPOT_CREW=Rust_Hunters2_1 SPOT_FROM=14 SPOT_TO=26`

| s | speed | hp | choice | phase | to_go | gain_5 | route_off | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | -2.93 | 18 | RETREAT | driving | 17.7 |  | 179.5 | 81.5 | 37.7 | 60 | 4 | RETREAT - base of fire, support by fire |
| 21 | -4.85 | 18 | RETREAT | driving | 18.1 |  | 180 | 81.5 | 42 | 60 | 0 | RETREAT - base of fire, support by fire |
| 22 | -4.95 | 18 | RETREAT | driving | 19.8 |  | 172.5 | 81.5 | 46.8 | 60 | 4 | RETREAT - base of fire, support by fire |
| 23 | -5 | 18 | RETREAT | driving | 19.3 |  | 179.9 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 24 | -5 | 18 | RETREAT | driving | 18.8 |  | 179.9 | 0 |  | 60 | 4 | RETREAT - base of fire, support by fire |
| 25 | -5 | 18 | RETREAT | driving | 16.5 |  | 178.6 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 26 | -5 | 18 | RETREAT | driving | 22.2 |  | 179.4 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 27 | -5 | 18 | RETREAT | driving | 21.7 |  | 180 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 28 | -4.96 | 18 | RETREAT | driving | 60 |  | 172.1 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 29 | -5 | 18 | RETREAT | driving | 55.2 |  | 160.8 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 30 | -4.99 | 18 | RETREAT | driving | 50.3 |  | 176.3 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 31 | -5 | 18 | RETREAT | driving | 45.3 |  | 179.9 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 32 | -5 | 18 | RETREAT | driving | 40.3 |  | 180 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| 33 | -5 | 22 | RETREAT | driving | 35.3 | 24.7 | 180 | 0 |  | 60 | 0 | RETREAT - base of fire, support by fire |
| ... 3 more seconds | | | | | | | | | | | | |

- **Rust_Guns_2** (gang_tank, team 1) locks seed 13151, 48-63 s, 14 flagged s
  `make spotter-clip SPOT_SEED=13151 SPOT_ARENA=locks SPOT_CREW=Rust_Guns_2 SPOT_FROM=46 SPOT_TO=58`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 50 | -0.87 | 45 | attack_move | RETREAT | driving | 20.5 |  | 142.8 | 71.9 | 0 | 50 | 0 | RETREAT - bounding, far ambush, back to its squad |
| 51 | -2.7 | 45 | attack_move | RETREAT | driving | 19.2 |  | 143.5 | 69.8 | 0 | 50 | 0 | RETREAT - bounding, far ambush, back to its squad |
| 52 | 0 | 45 | attack_move | RETREAT | arrived | 17.7 |  | 142.6 | 67.4 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 53 | 1.07 | 45 | attack_move | RETREAT | driving | 17 | 0.4 | 133.1 | 68.6 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 54 | 0 | 45 | attack_move | RETREAT | arrived | 17.3 | 1.1 | 134.1 | 71.2 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 55 | 0 | 45 | attack_move | RETREAT | arrived | 17.3 | 3.2 | 134.1 | 73.7 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 56 | 0 | 45 | attack_move | RETREAT | arrived | 8.7 |  | 37 | 76.5 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 57 | 0 | 45 | attack_move | RETREAT | arrived | 8.7 |  | 37 | 78.6 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 58 | -2 | 45 | attack_move | RETREAT | driving | 9.3 |  | 37.4 | 80 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 59 | 0 | 45 | attack_move | RETREAT | arrived | 9.1 |  | 40.8 | 81.9 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 60 | 0.7 | 45 | attack_move | RETREAT | driving | 9.1 |  | 40.9 | 74.4 | 0 | 50 | 0 | RETREAT - bounding, far ambush, breaking line of sight |
| 61 | 5.2 | 45 | attack_move | RETREAT | driving | 6.7 | 1.9 | 59.1 | 77.3 | 0 | 50 | 0 | RETREAT - bounding, far ambush, back to its squad |
| 62 | -2.47 | 45 | attack_move | RETREAT | driving | 66.8 |  | 152.6 | 77.9 | 0 | 50 | 0 | RETREAT - assault through, back to its squad |
| 63 | 0.37 | 45 | attack_move | RETREAT | driving | 65.1 |  | 134.6 | 76.1 | 0 | 50 | 0 | RETREAT - assault through, back to its squad |

- **Rust_Hunters_3** (law_ifv, team 1) locks seed 13213, 61-78 s, 14 flagged s
  `make spotter-clip SPOT_SEED=13213 SPOT_ARENA=locks SPOT_CREW=Rust_Hunters_3 SPOT_FROM=59 SPOT_TO=71`

| s | speed | hp | choice | phase | to_go | route_off | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|
| 65 | -4.99 | 3 | RETREAT | driving | 8 | 176.5 | 0 | 60 | 0 | RETREAT |
| 66 | -4.9 | 3 | RETREAT | driving | 5.5 | 174.2 | 0 | 60 | 0 | RETREAT |
| 67 | -4.99 | 3 | RETREAT | driving | 8.1 | 177.1 | 0 | 60 | 0 | RETREAT |
| 68 | -5 | 3 | RETREAT | driving | 18.7 | 178.7 | 0 | 60 | 0 | RETREAT |
| 69 | -5 | 3 | RETREAT | driving | 14.8 | 179.7 | 0 | 60 | 0 | RETREAT |
| 70 | -3.32 | 3 | RETREAT | driving | 144.8 | 136.7 | 0 | 60 | 0 | RETREAT |
| 71 | -4.99 | 3 | RETREAT | driving | 140.1 | 177.2 | 0 | 60 | 0 | RETREAT |
| 72 | -5 | 3 | RETREAT | driving | 135.1 | 174.5 | 0 | 60 | 0 | RETREAT |
| 73 | -2.67 | 3 | RETREAT | driving | 15.1 | 147.8 | 0 | 60 | 0 | RETREAT |
| 74 | -2.4 | 3 | RETREAT | driving | 133.1 | 141.6 | 0 | 60 | 0 | RETREAT |
| 75 | -1.05 | 3 | RETREAT | driving | 18 | 80.1 | 0 | 60 | 0 | RETREAT |
| 76 | -2.64 | 3 | RETREAT | driving | 128.7 | 127.9 | 0 | 60 | 0 | RETREAT |
| 77 | -4.99 | 3 | RETREAT | driving | 124.5 | 175.4 | 0 | 60 | 0 | RETREAT |
| 78 | -1.1 | 3 | RETREAT | driving | 20.2 | 90.5 | 0 | 60 | 0 | RETREAT |

- **Green_Eyes_6** (syn_scout, team 0) sumps seed 13172, 157-172 s, 14 flagged s
  `make spotter-clip SPOT_SEED=13172 SPOT_ARENA=sumps SPOT_CREW=Green_Eyes_6 SPOT_FROM=155 SPOT_TO=167`

| s | speed | hp | order | choice | phase | to_go | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 159 | -9.68 | 15 | attack_move | RETREAT | driving | 22.8 | 169 | 59.4 | 0 |  | 55 | 4 | RETREAT - assault through, breaking line of sight |
| 160 | -4.25 | 15 | attack_move | RETREAT | driving | 15 | 161.1 | 64.4 | 0 |  | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 161 | 1.38 | 15 | attack_move | RETREAT | driving | 25 | 45.5 | 72.2 | 0 |  | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 162 | 2.62 | 15 | attack_move | RETREAT | driving | 10.1 | 61.3 | 71.9 | 1.8 | 15 | 55 | 4 | RETREAT - assault through, back to its squad |
| 163 | 15 | 15 | attack_move | RETREAT | driving | 15.5 | 148.8 | 65.4 | 1.8 | 10.8 | 55 | 6 | RETREAT - assault through, back to its squad |
| 164 | 5.77 | 15 | attack_move | RETREAT | driving | 27 | 169.4 | 55.3 | 1.8 | 14.3 | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 165 | -8.1 | 15 | attack_move | RETREAT | driving | 25.6 | 172.5 | 56.4 | 0 |  | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 166 | -9.89 | 15 | attack_move | RETREAT | driving | 16.6 | 150.4 | 63.6 | 0 |  | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 167 | -9.15 | 15 | attack_move | RETREAT | driving | 15.7 | 165.7 | 70.3 | 1.8 | 23.9 | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 168 | -3.76 | 15 | attack_move | RETREAT | driving | 18 | 178 | 75.6 | 19.8 | 27.4 | 55 | 4 | RETREAT - assault through, back to its squad |
| 169 | 0 | 15 | attack_move | RETREAT | arrived | 18.8 | 170 | 74.9 | 19.8 | 26.9 | 55 | 3 | RETREAT - assault through, breaking line of sight |
| 170 | 0 | 15 | attack_move | RETREAT | arrived | 18.8 | 170 | 74.9 | 19.8 | 26.9 | 55 | 6 | RETREAT - assault through, breaking line of sight |
| 171 | 0 | 15 | attack_move | RETREAT | arrived | 18.8 | 170 | 74.9 | 0 |  | 55 | 1 | RETREAT - assault through, breaking line of sight |
| 172 | 0 | 15 | attack_move | RETREAT | arrived | 18.8 | 170 | 74.9 | 0 |  | 55 | 0 | RETREAT - assault through, breaking line of sight |

- **Green_Spears_1** (gang_scout, team 0) parade seed 13129, 69-86 s, 13 flagged s
  `make spotter-clip SPOT_SEED=13129 SPOT_ARENA=parade SPOT_CREW=Green_Spears_1 SPOT_FROM=67 SPOT_TO=79`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 74 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 75 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 76 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 77 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 78 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 79 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 80 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 81 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 82 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 83 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 84 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 85 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |
| 86 | 0 | 9 | attack_move | RETREAT | arrived | 66.8 | 0 | 171.2 | 0 | 30 | 0 | RETREAT - breaking away |

- **Rust_Burners_5** (burner, team 1) locks seed 13121, 83-97 s, 11 flagged s
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=locks SPOT_CREW=Rust_Burners_5 SPOT_FROM=81 SPOT_TO=93`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 87 | -4.81 | 8 | attack_move | RETREAT | driving | 62.2 |  | 6.9 | 3.8 | 31.7 | 20 | 0 |  | RETREAT - assault through |
| 88 | -4.57 | 8 | attack_move | RETREAT | driving | 67.3 | -22 | 20.2 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 89 | -4.78 | 8 | attack_move | RETREAT | driving | 71.8 | -22.9 | 5.5 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 90 | -4.2 | 8 | attack_move | RETREAT | driving | 76.9 | -24.1 | 8.2 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 91 | -4.69 | 8 | attack_move | RETREAT | driving | 81.1 | -23.1 | 21.6 | 0 |  | 20 | 0 | TerrainRims | RETREAT - assault through |
| 92 | -4.9 | 8 | attack_move | RETREAT | driving | 86.6 | -24.4 | 15.7 | 0 |  | 20 | 0 | TerrainRims | RETREAT - assault through |
| 93 | -4.84 | 8 | attack_move | RETREAT | driving | 90.4 | -23.1 | 2.1 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 94 | -4.7 | 8 | attack_move | RETREAT | driving | 95.4 | -23.6 | 7.8 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 95 | -4.9 | 8 | attack_move | RETREAT | driving | 100.3 | -23.4 | 1.9 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 96 | -4.97 | 8 | attack_move | RETREAT | driving | 105.2 | -24.1 | 2.4 | 0 |  | 20 | 0 |  | RETREAT - assault through |
| 97 | -4.98 | 8 | attack_move | RETREAT | driving | 109.3 | -22.8 | 12.2 | 0 |  | 20 | 0 | TerrainRails | RETREAT - assault through |

- **Green_Guns_5** (tank, team 0) locks seed 13160, 106-119 s, 10 flagged s
  `make spotter-clip SPOT_SEED=13160 SPOT_ARENA=locks SPOT_CREW=Green_Guns_5 SPOT_FROM=104 SPOT_TO=116`

| s | speed | hp | choice | phase | to_go | route_off | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|
| 110 | -3.95 | 92 | RETREAT | driving | 10 | 178.6 | 0 | 70 | 0 | RETREAT |
| 111 | -4 | 92 | RETREAT | driving | 8.5 | 179.8 | 0 | 70 | 0 | RETREAT |
| 112 | -3.78 | 92 | RETREAT | driving | 53.7 | 164.9 | 0 | 70 | 0 | RETREAT |
| 113 | -4 | 92 | RETREAT | driving | 49.7 | 177.7 | 0 | 70 | 0 | RETREAT |
| 114 | -3.54 | 92 | RETREAT | driving | 12.2 | 158.6 | 0 | 70 | 0 | RETREAT |
| 115 | -3.37 | 92 | RETREAT | driving | 47.2 | 154.8 | 0 | 70 | 0 | RETREAT |
| 116 | -3.99 | 92 | RETREAT | driving | 43.3 | 173.6 | 0 | 70 | 0 | RETREAT |
| 117 | -2.96 | 92 | RETREAT | driving | 16.1 | 140.1 | 0 | 70 | 0 | RETREAT |
| 118 | -2 | 92 | RETREAT | driving | 41.9 | 128.5 | 0 | 70 | 0 | RETREAT |
| 119 | -3.98 | 92 | RETREAT | driving | 38.6 | 178.4 | 0 | 70 | 0 | RETREAT |

- **Rust_Guns_3** (gang_tank, team 1) parade seed 13177, 104-117 s, 10 flagged s
  `make spotter-clip SPOT_SEED=13177 SPOT_ARENA=parade SPOT_CREW=Rust_Guns_3 SPOT_FROM=102 SPOT_TO=114`

| s | speed | hp | choice | phase | to_go | gain_5 | route_off | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 108 | -3.96 | 30 | RETREAT | driving | 68.7 | 13.9 | 178 | 0 | 50 | 0 | RETREAT |
| 109 | -3.97 | 35 | RETREAT | driving | 64.7 | 19.1 | 178.6 | 0 | 50 | 0 | RETREAT |
| 110 | -3.98 | 40 | RETREAT | driving | 60.7 | 19.4 | 179 | 0 | 50 | 0 | RETREAT |
| 111 | -3.98 | 45 | RETREAT | driving | 56.8 | 19.5 | 179.3 | 0 | 50 | 0 | RETREAT |
| 112 | -3.99 | 50 | RETREAT | driving | 52.8 | 19.8 | 179.5 | 0 | 50 | 0 | RETREAT |
| 113 | -3.99 | 55 | RETREAT | driving | 48.8 | 19.9 | 179.7 | 0 | 50 | 0 | RETREAT |
| 114 | -3.99 | 60 | RETREAT | driving | 44.8 | 19.9 | 179.8 | 0 | 50 | 0 | RETREAT |
| 115 | -4 | 65 | RETREAT | driving | 40.8 | 19.9 | 179.8 | 0 | 50 | 0 | RETREAT |
| 116 | -4 | 71 | RETREAT | driving | 36.8 | 20 | 179.9 | 0 | 50 | 0 | RETREAT |
| 117 | -4 | 77 | RETREAT | driving | 32.8 | 20 | 179.9 | 0 | 50 | 0 | RETREAT |

- **Rust_Hunters_4** (law_ifv, team 1) parade seed 13213, 79-92 s, 10 flagged s
  `make spotter-clip SPOT_SEED=13213 SPOT_ARENA=parade SPOT_CREW=Rust_Hunters_4 SPOT_FROM=77 SPOT_TO=89`

| s | speed | hp | choice | phase | to_go | route_off | hit_dmg | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|
| 83 | -5 | 80 | RETREAT | driving | 19.5 | 178.5 | 0 | 60 | 0 | RETREAT |
| 84 | -5 | 80 | RETREAT | driving | 18.5 | 179.2 | 0 | 60 | 0 | RETREAT |
| 85 | -5 | 80 | RETREAT | driving | 19.5 | 179.6 | 0 | 60 | 0 | RETREAT |
| 86 | -0.8 | 80 | RETREAT | driving | 19.9 | 123.9 | 0 | 60 | 0 | RETREAT |
| 87 | -5 | 80 | RETREAT | driving | 17.5 | 179 | 0 | 60 | 0 | RETREAT |
| 88 | -5 | 80 | RETREAT | driving | 19.5 | 179.6 | 0 | 60 | 0 | RETREAT |
| 89 | -5 | 80 | RETREAT | driving | 18.5 | 179.8 | 0 | 60 | 0 | RETREAT |
| 90 | -5 | 80 | RETREAT | driving | 19.5 | 179.5 | 0 | 60 | 0 | RETREAT |
| 91 | -5 | 80 | RETREAT | driving | 18.5 | 179.7 | 0 | 60 | 0 | RETREAT |
| 92 | -5 | 80 | RETREAT | driving | 19.5 | 179.4 | 0 | 60 | 0 | RETREAT |


## E. shot from beyond its range, no answer (engage): 5.58 moments / fight, 23.3 crew-s / fight

### E / no answer: 4.41 moments / fight, 19.0 crew-s / fight

2541 moments; by map: crossing 606, gorge 330, locks 487, parade 388, sumps 412, terminus 318

- **Rust_Eyes_3** (syn_scout, team 1) crossing seed 13126, 25-65 s, 33 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13126 SPOT_ARENA=crossing SPOT_CREW=Rust_Eyes_3 SPOT_FROM=23 SPOT_TO=35`

| s | speed | hp | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | 0 | 150 | TAKE_COVER | arrived | 1.1 |  |  | 45.1 | 127.5 | 99.9 | 55 | 0 | TAKE_COVER |
| 33 | 0 | 150 | TAKE_COVER | arrived | 1.1 |  |  | 43.7 | 127.5 | 99.9 | 55 | 0 | TAKE_COVER |
| 34 | 0 | 150 | TAKE_COVER | arrived | 1.1 |  |  | 43.5 | 76.8 | 99.9 | 55 | 0 | TAKE_COVER |
| 35 | 0 | 150 | TAKE_COVER | arrived | 1.1 |  |  | 43.4 | 37.8 | 99.1 | 55 | 0 | TAKE_COVER |
| 36 | 5.23 | 150 | SPOT | driving | 122.8 |  | 18.9 | 44.2 | 0 |  | 55 | 0 | SPOT - outranged: closing |
| 37 | 0 | 150 | SPOT | driving | 123.8 |  | 95.4 | 45.1 | 30.3 | 99.3 | 55 | 0 | SPOT - outranged: closing |
| 38 | 0 | 150 | TAKE_COVER | arrived | 1.4 |  |  | 45 | 71.9 | 99.3 | 55 | 0 | TAKE_COVER |
| 39 | 0 | 150 | TAKE_COVER | arrived | 1.4 |  |  | 45 | 71.9 | 99.3 | 55 | 0 | TAKE_COVER |
| 40 | 0 | 150 | ENGAGE | driving | 118.5 |  | 79.2 | 45 | 84.8 | 99.1 | 55 | 0 | ENGAGE Green_Battery_2 - water between: firing across, outranged: closing |
| 41 | 0 | 150 | TAKE_COVER | arrived | 1.4 |  |  | 45 | 43.2 | 98.9 | 55 | 0 | TAKE_COVER |
| 42 | 0 | 150 | TAKE_COVER | arrived | 1.4 |  |  | 45 | 43.2 | 98.9 | 55 | 0 | TAKE_COVER |
| 43 | 0 | 150 | TAKE_COVER | arrived | 1.5 |  |  | 45.2 | 89.1 | 99.1 | 55 | 0 | TAKE_COVER |
| 44 | 0 | 143 | TAKE_COVER | arrived | 1.5 |  |  | 45.2 | 79.9 | 99.1 | 55 | 0 | TAKE_COVER |
| 45 | 0 | 143 | TAKE_COVER | arrived | 1.5 |  |  | 45.2 | 79.9 | 99.1 | 55 | 0 | TAKE_COVER |
| ... 19 more seconds | | | | | | | | | | | | | |

- **Rust_Guns_3** (tank, team 1) crossing seed 13184, 53-86 s, 27 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=crossing SPOT_CREW=Rust_Guns_3 SPOT_FROM=51 SPOT_TO=63`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 60 | 0 | 300 | hold | HOLD | driving |  |  |  |  | 2.5 |  | 152.1 | 5.9 | 18 | 137.6 | 70 | 0 |  | HOLD - spring ambush, outranged: out of its sight |
| 61 | 0 | 300 | hold | HOLD | arrived |  |  |  |  |  |  |  | 5.5 | 18 | 137.6 | 70 | 0 |  | HOLD - spring ambush |
| 62 | 0 | 299 | hold | HOLD | arrived |  |  |  |  |  |  |  | 5.6 | 110.9 | 58.4 | 70 | 0 |  | HOLD - spring ambush |
| 63 | -1.53 | 272 | hold | HOLD | driving |  |  |  |  | 3 |  | 177.8 | 5.8 | 137.9 | 132.9 | 70 | 0 |  | HOLD - spring ambush, holding |
| 64 | -1 | 272 | hold | HOLD | driving |  |  |  |  | 3.1 |  | 177 | 5.7 | 137.9 | 132.4 | 70 | 0 |  | HOLD - spring ambush, holding |
| 65 | 0 | 187 | hold | HOLD | arrived |  |  |  |  |  |  |  | 5.6 | 112 | 132.1 | 70 | 0 |  | HOLD - spring ambush |
| 66 | 0 | 187 | hold | HOLD | arrived |  |  |  |  |  |  |  | 5.7 | 85 | 56.5 | 70 | 1 |  | HOLD - spring ambush |
| 67 | 0 | 163 | hold | HOLD | driving |  |  |  |  | 3.1 |  |  | 5.8 | 109 | 134.7 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: out of its sight |
| 68 | 1.09 | 163 | hold | HOLD | driving |  |  |  |  | 3 |  | 142.1 | 6.1 | 24 | 135.8 | 70 | 0 | Block_3 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 69 | -1.44 | 163 | hold | HOLD | driving |  |  |  |  | 3.7 |  | 143.6 | 5.3 | 24 | 134 | 70 | 0 |  | HOLD - spring ambush, holding |
| 70 | -2.08 | 163 | hold | HOLD | driving |  |  |  |  | 4.2 |  | 172.9 | 5.9 | 0 |  | 70 | 0 |  | HOLD - spring ambush, holding |
| 71 | 0 | 140 | hold | HOLD | arrived |  |  |  |  |  |  |  | 5.2 | 29.7 | 132.1 | 70 | 0 |  | HOLD - spring ambush |
| 72 | -1.04 | 140 | hold | HOLD | driving |  |  |  |  | 3.9 |  | 136.8 | 6 | 29.7 | 133.5 | 70 | 0 |  | HOLD - spring ambush, holding |
| 73 | -1.38 | 120 | hold | HOLD | yielding | Rust_Lances_3 | driving | move_to | hold | 2.9 |  | 110.9 | 6 | 49.7 | 137.9 | 70 | 0 |  | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| ... 13 more seconds | | | | | | | | | | | | | | | | | | | |

- **Green_Guns_5** (gang_tank, team 0) crossing seed 13121, 72-102 s, 24 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13121 SPOT_ARENA=crossing SPOT_CREW=Green_Guns_5 SPOT_FROM=70 SPOT_TO=82`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 79 | -2.4 | 348 | hold | HOLD | driving |  | 118.9 |  | 162.8 | 45.9 | 40 | 60.2 | 50 | 0 |  | HOLD - holding, outranged: closing |
| 80 | 3.03 | 348 |  | ENGAGE | driving |  | 7.7 |  | 6.5 | 44.9 | 40 | 60.3 | 50 | 0 |  | ENGAGE Rust_Burners2_1 - squad focus, in its slot, going for its side, weaving, front armor on it, outranged: closing |
| 81 | 4.2 | 332 |  | ENGAGE | blocked | no_path | 2.6 |  | 0.9 | 45.5 | 40 | 56.5 | 50 | 0 |  | ENGAGE Rust_Burners_5 - water between: firing across, outranged: closing |
| 82 | 1.7 | 316 |  | ENGAGE | blocked | no_path | 0.7 |  |  | 46.1 | 32 | 53.9 | 50 | 1 |  | ENGAGE Rust_Burners_5 - water between: firing across, outranged: closing |
| 83 | -2.8 | 316 |  | ENGAGE | blocked | no_path | 0.6 |  |  | 44.9 | 32 | 54 | 50 | 0 |  | ENGAGE Rust_Burners_5 - water between: firing across, outranged: closing |
| 84 | 0 | 300 |  | ENGAGE | blocked | no_path | 0.1 |  |  | 44.1 | 32 | 54.4 | 50 | 0 |  | ENGAGE Rust_Burners_5 - water between: firing across, outranged: closing |
| 85 | -2.1 | 284 | move | MOVE | driving |  | 16.7 |  | 128.5 | 43.5 | 32 | 54.7 | 50 | 0 |  | MOVE - ordered |
| 86 | -2 | 284 | move | MOVE | driving |  | 15.9 |  | 84.9 | 42.2 | 32 | 56.6 | 50 | 0 | Container40_8 | MOVE - ordered |
| 87 | 2.47 | 259 | move | MOVE | driving |  | 16.4 |  | 76.1 | 42.4 | 41 | 56.4 | 50 | 1 |  | MOVE - ordered |
| 88 | -2 | 234 | move | MOVE | blocked | no_path | 16.6 |  | 81.8 | 42.9 | 50 | 55.6 | 50 | 0 | Container40_8 | MOVE - ordered |
| 89 | -1.5 | 234 | move | MOVE | blocked | no_path | 17.1 |  | 75.6 | 42.2 | 50 | 55.3 | 50 | 0 |  | MOVE - ordered |
| 90 | -1.47 | 209 | move | MOVE | driving |  | 7.7 |  | 126.8 | 41.7 | 50 | 55 | 50 | 0 |  | MOVE - ordered |
| 91 | -0.67 | 184 | move | MOVE | driving |  | 7.3 |  | 102.8 | 41.8 | 50 | 55.3 | 50 | 1 |  | MOVE - ordered |
| 92 | -2.4 | 184 | move | MOVE | driving |  | 7.2 |  | 67.9 | 41.4 | 50 | 55.8 | 50 | 0 |  | MOVE - ordered |
| ... 10 more seconds | | | | | | | | | | | | | | | | |

- **Green_Hunters_1** (syn_ifv, team 0) locks seed 13189, 67-96 s, 23 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13189 SPOT_ARENA=locks SPOT_CREW=Green_Hunters_1 SPOT_FROM=65 SPOT_TO=77`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 74 | 0 | 228 | hold | HOLD | arrived |  |  |  | 10.8 | 56 | 117.9 | 70 | 3 | HOLD |
| 75 | 0 | 228 | hold | HOLD | arrived |  |  |  | 9.7 | 56 | 117.9 | 70 | 0 | HOLD |
| 76 | 0 | 217 | hold | HOLD | driving | 2.4 |  | 78.1 | 9.6 | 47.2 | 112.3 | 70 | 3 | HOLD - outranged: out of its sight |
| 77 | 0.2 | 187 | hold | HOLD | driving | 3.8 |  | 164.5 | 7.7 | 77.2 | 113.9 | 70 | 0 | HOLD - holding |
| 78 | 0 | 172 | hold | HOLD | arrived |  |  |  | 8.4 | 73.3 | 112.5 | 70 | 3 | HOLD |
| 79 | 0 | 128 | hold | HOLD | driving | 2.4 |  | 86.3 | 7.5 | 89 | 118.1 | 70 | 0 | HOLD - outranged: out of its sight |
| 80 | 0 | 123 | hold | HOLD | arrived |  |  |  | 6.1 | 64 | 118.1 | 70 | 3 | HOLD |
| 81 | 0 | 123 | hold | HOLD | arrived |  |  |  | 3.4 | 57 | 118.1 | 70 | 0 | HOLD |
| 82 | 0.4 | 92 | hold | HOLD | driving | 2.4 |  | 119.2 | 3.4 | 36 | 112.6 | 70 | 3 | HOLD - outranged: out of its sight |
| 83 | 5.64 | 92 | hold | HOLD | driving | 7.3 |  | 171.9 | 4.1 | 31 | 117 | 70 | 0 | HOLD - holding |
| 84 | -1.25 | 62 | hold | HOLD | driving | 7.4 |  | 173 | 5.3 | 61 | 117.2 | 70 | 3 | HOLD - holding |
| 85 | -1.63 | 31 | hold | HOLD | driving | 6.3 |  | 87.8 | 7.4 | 61 | 122 | 70 | 0 | HOLD - holding, outranged: out of its sight |
| 86 | -2.4 | 26 | hold | HOLD | driving | 6.2 |  | 70.7 | 10.4 | 66 | 121.7 | 70 | 3 | HOLD - holding |
| 87 | 0 | 26 | hold | HOLD | driving | 6.2 | -3.8 | 53 | 9.7 | 36 | 121.6 | 70 | 0 | HOLD - holding |
| ... 9 more seconds | | | | | | | | | | | | | | |

- **Green_Burners_2** (burner, team 0) sumps seed 13159, 41-70 s, 23 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13159 SPOT_ARENA=sumps SPOT_CREW=Green_Burners_2 SPOT_FROM=39 SPOT_TO=51`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 48 | -2.5 | 220 | move | MOVE | blocked | terrain | 8.4 |  | 5.5 | 12.4 | 6.9 | 40.5 | 20 | 0 |  | MOVE - ordered |
| 49 | 4.8 | 220 | move | MOVE | blocked | terrain | 8 | 3.5 | 25.8 | 14.1 | 6.9 | 40.9 | 20 | 0 |  | MOVE - ordered |
| 50 | -3.5 | 220 | move | MOVE | driving |  | 6.7 | 2.5 | 16.6 | 14.8 | 0 |  | 20 | 0 |  | MOVE - ordered |
| 51 | 2.93 | 220 | move | MOVE | driving |  | 8 | -1.3 | 2.7 | 16.1 | 28.7 | 30.3 | 20 | 0 |  | MOVE - ordered |
| 52 | 0.35 | 220 |  | CLEAR_LANE | driving |  | 12.1 |  | 180 | 17.7 | 55.4 | 34.2 | 20 | 0 |  | CLEAR_LANE Rust_Eyes_5 - guarding artillery, Green_Hunters_1 in the line of fire |
| 53 | -3 | 220 |  | CLEAR_LANE | driving |  | 9.7 |  | 122.2 | 17 | 70.3 | 32.5 | 20 | 0 |  | CLEAR_LANE Rust_Eyes_4 - Green_Hunters_1 in the line of fire |
| 54 | -3 | 220 |  | CLEAR_LANE | driving |  | 9.9 |  | 81.6 | 15.7 | 63.4 | 32.2 | 20 | 0 |  | CLEAR_LANE Rust_Eyes_4 - Green_Hunters_1 in the line of fire |
| 55 | -2.5 | 220 |  | CLEAR_LANE | driving |  | 3.2 |  | 46 | 14.8 | 44.6 | 32.3 | 20 | 0 | Block_29 | CLEAR_LANE Rust_Eyes_4 - Green_Hunters_1 in the line of fire |
| 56 | 1.6 | 219 |  | CLEAR_LANE | arrived |  | 3.6 |  | 29.5 | 14.3 | 30.7 | 32.5 | 20 | 0 |  | CLEAR_LANE Rust_Eyes_4 - Green_Hunters_1 in the line of fire |
| 57 | 6.88 | 210 |  | ENGAGE | driving |  | 11.7 |  | 30.9 | 16.5 | 24.9 | 30.1 | 20 | 6 |  | ENGAGE Rust_Eyes_4 - in its slot, weaving, front armor on it, outranged: closing |
| 58 | -3.5 | 209 | move | MOVE | driving |  | 56.7 |  | 178.6 | 17.6 | 11 | 29.6 | 20 | 0 |  | MOVE - ordered |
| 59 | -3.5 | 207 | move | MOVE | driving |  | 53.3 |  | 145.7 | 16.3 | 12 | 29.8 | 20 | 0 |  | MOVE - ordered |
| 60 | -3.5 | 195 | move | MOVE | driving |  | 51.8 |  | 89.6 | 17.2 | 15 | 31.9 | 20 | 0 |  | MOVE - ordered |
| 61 | -0.7 | 183 | move | MOVE | driving |  | 53.1 |  | 41.3 | 19.6 | 26 | 32.7 | 20 | 0 |  | MOVE - ordered |
| ... 9 more seconds | | | | | | | | | | | | | | | | |

- **Green_Burners_5** (burner, team 0) sumps seed 13214, 21-50 s, 23 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13214 SPOT_ARENA=sumps SPOT_CREW=Green_Burners_5 SPOT_FROM=19 SPOT_TO=31`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 28 | -3 | 220 | attack_move | ENGAGE | driving |  |  |  |  | 49.8 |  | 1.5 | 12.3 | 43.9 | 30.8 | 20 | 3 |  | ENGAGE Rust_Spears_2 - assault through, water between: firing across, outranged: closing |
| 29 | 5.5 | 220 | attack_move | ENGAGE | driving |  |  |  |  | 48.5 |  | 8.9 | 13.4 | 70.4 | 29.2 | 20 | 0 |  | ENGAGE Rust_Spears_2 - assault through, in its slot, boxed in by fire, going for its side, weaving, front armor on it, outranged: closing |
| 30 | 3.3 | 220 | attack_move | ENGAGE | arrived |  |  |  |  |  |  |  | 15.9 | 78.8 | 25 | 20 | 7 | TerrainRims | ENGAGE Rust_Spears_2 - assault through, water between: firing across |
| 31 | 0 | 212 | attack_move | ENGAGE | arrived |  |  |  |  |  |  |  | 15.9 | 64.6 | 24.9 | 20 | 0 |  | ENGAGE Rust_Hunters2_3 - assault through, water between: firing across |
| 32 | 0 | 203 | attack_move | ENGAGE | arrived |  |  |  |  |  |  |  | 15.1 | 47.2 | 24.9 | 20 | 0 |  | ENGAGE Rust_Hunters2_3 - assault through, water between: firing across |
| 33 | 0 | 194 | attack_move | ENGAGE | arrived |  |  |  |  |  |  |  | 14 | 30.2 | 24.9 | 20 | 0 |  | ENGAGE Rust_Hunters2_3 - assault through, water between: firing across |
| 34 | 0.23 | 184 | move | MOVE | driving |  |  |  |  | 17.7 |  | 41.5 | 13.1 | 29 | 24.7 | 20 | 0 |  | MOVE - bounding, far ambush, ordered |
| 35 | 0.3 | 175 | move | MOVE | driving |  |  |  |  | 19 |  | 27.7 | 11 | 28 | 25.5 | 20 | 0 |  | MOVE - bounding, far ambush, ordered |
| 36 | 0.83 | 166 | move | MOVE | blocked | terrain |  |  |  | 18.4 |  | 24.4 | 10.8 | 28 | 25.2 | 20 | 0 |  | MOVE - bounding, far ambush, ordered |
| 37 | 2.11 | 156 | move | MOVE | yielding | Green_Burners_4 | driving | move_to | move | 19.3 |  | 15.2 | 8.6 | 29 | 25.5 | 20 | 0 |  | MOVE - bounding, far ambush, ordered |
| 38 | 7.47 | 147 | move | MOVE | driving |  |  |  |  | 37.8 |  | 5.4 | 9.7 | 29 | 24.8 | 20 | 0 |  | MOVE - bounding, far ambush, ordered |
| 39 | 4.06 | 145 | move | MOVE | driving |  |  |  |  | 32.5 |  | 34.2 | 11.4 | 21 | 25.4 | 20 | 0 |  | MOVE - bounding, far ambush, ordered, outranged: closing |
| 40 | 3.39 | 145 | move | MOVE | driving |  |  |  |  | 32.3 |  | 48.9 | 10 | 12 | 25.2 | 20 | 0 |  | MOVE - bounding, far ambush, ordered, outranged: closing |
| 41 | -2.51 | 145 | attack_move | MOVE | driving |  |  |  |  | 16.6 |  | 46.8 | 8.4 | 3 | 25.5 | 20 | 0 |  | MOVE - bounding, far ambush, attack-move, outranged: closing |
| ... 9 more seconds | | | | | | | | | | | | | | | | | | | |

- **Rust_Wrenches_4** (gang_support, team 1) crossing seed 13188, 88-115 s, 21 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13188 SPOT_ARENA=crossing SPOT_CREW=Rust_Wrenches_4 SPOT_FROM=86 SPOT_TO=98`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 95 | -3.44 | 143 | move | MOVE | driving |  | 13.6 |  | 105.5 | 11.6 | 44 | 103.7 | 14 | 0 | MOVE - ordered |
| 96 | 2.57 | 147 | move | MOVE | driving |  | 13.4 |  | 79.4 | 11.2 | 0 |  | 14 | 0 | MOVE - ordered |
| 97 | 7.7 | 125 | move | MOVE | driving |  | 12.5 |  | 82.3 | 11.3 | 26 | 95.9 | 14 | 0 | MOVE - ordered |
| 98 | 5.95 | 127 | move | MOVE | driving |  | 11 |  | 72.5 | 9.9 | 26 | 101.8 | 14 | 0 | MOVE - ordered |
| 99 | 6.6 | 79 | move | MOVE | driving |  | 10.1 |  | 11.4 | 7.6 | 77 | 119.3 | 14 | 0 | MOVE - ordered |
| 100 | 4.03 | 81 |  | RETREAT | driving |  | 11.8 |  | 114.7 | 7.8 | 51 | 125.3 | 14 | 0 | RETREAT - back to its squad |
| 101 | -3.5 | 84 |  | RETREAT | driving |  | 11.7 |  | 94.8 | 7.8 | 51 | 124.5 | 14 | 0 | RETREAT - back to its squad |
| 102 | -3.5 | 88 |  | RETREAT | blocked | terrain | 12.6 |  | 53.9 | 8.4 | 0 |  | 14 | 0 | RETREAT - back to its squad |
| 103 | 0.17 | 74 |  | RETREAT | blocked | terrain | 14.8 |  | 25.7 | 9.9 | 18 | 108.8 | 14 | 0 | RETREAT - back to its squad |
| 104 | 0.87 | 77 | move | MOVE | driving |  | 13.1 |  | 76.7 | 10.1 | 18 | 108.5 | 14 | 0 | MOVE - ordered |
| 105 | 5.08 | 57 | move | MOVE | driving |  | 12.4 |  | 81.9 | 9.4 | 40 | 121 | 14 | 0 | MOVE - ordered |
| 106 | 4.83 | 60 | move | MOVE | driving |  | 13.4 |  | 108.7 | 6.2 | 22 | 123.6 | 14 | 0 | MOVE - ordered |
| 107 | -3.5 | 62 | move | MOVE | blocked | terrain | 13.6 |  | 90.6 | 6.2 | 22 | 123.3 | 14 | 0 | MOVE - ordered |
| 108 | -3 | 61 | move | MOVE | blocked | terrain | 14.7 |  | 52.8 | 6.8 | 0 |  | 14 | 0 | MOVE - ordered |
| ... 7 more seconds | | | | | | | | | | | | | | | |

- **Rust_Wrenches_2** (gang_support, team 1) sumps seed 13188, 181-207 s, 20 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13188 SPOT_ARENA=sumps SPOT_CREW=Rust_Wrenches_2 SPOT_FROM=179 SPOT_TO=191`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 188 | -0.43 | 171 | move | MOVE | driving |  | 13 |  | 176.8 | 6.7 | 54 | 108.2 | 14 | 0 | MOVE - ordered |
| 189 | 0.79 | 174 | move | MOVE | driving |  | 15.4 |  | 160.9 | 8.5 | 54 | 106.7 | 14 | 0 | MOVE - ordered |
| 190 | -0.31 | 143 | move | MOVE | driving |  | 16.7 |  | 153 | 11.6 | 31 | 105.2 | 14 | 0 | MOVE - ordered |
| 191 | 7.13 | 143 | move | MOVE | blocked | terrain | 20 |  | 145.7 | 12 | 31 | 104.5 | 14 | 0 | MOVE - ordered |
| 192 | 8.45 | 143 | move | MOVE | blocked | terrain | 24.6 |  | 107.9 | 7.9 | 31 | 107.5 | 14 | 0 | MOVE - ordered |
| 193 | -1.88 | 117 | move | MOVE | driving |  | 15.2 |  | 145.1 | 7.1 | 30 | 113 | 14 | 0 | MOVE - ordered |
| 194 | -2.81 | 119 | move | MOVE | driving |  | 12.8 |  | 154.5 | 7.3 | 30 | 110.5 | 14 | 0 | MOVE - ordered |
| 195 | -3.73 | 122 | move | MOVE | driving |  | 9.6 |  | 169.5 | 8.7 | 30 | 108.3 | 14 | 0 | MOVE - ordered |
| 196 | 4.28 | 81 | move | MOVE | driving |  | 9.8 |  | 175.8 | 11 | 41 | 105.6 | 14 | 0 | MOVE - ordered |
| 197 | 4.63 | 81 | move | MOVE | driving |  | 15.5 |  | 179.9 | 16 | 41 | 105.4 | 14 | 0 | MOVE - ordered |
| 198 | -3.96 | 81 | move | MOVE | blocked | terrain | 15 | 0.2 | 179.9 | 20.5 | 41 | 105.3 | 14 | 0 | MOVE - ordered |
| 199 | -4.56 | 84 | move | MOVE | blocked | terrain | 10.7 | 2.1 | 178.5 | 21.3 | 0 |  | 14 | 0 | MOVE - ordered |
| 200 | -3.97 | 89 | move | MOVE | driving |  | 6.2 | 3.5 | 172.2 | 20.2 | 0 |  | 14 | 0 | MOVE - ordered |
| 201 | 0 | 94 |  | HOLD | arrived |  |  |  |  | 20 | 0 |  | 14 | 0 | HOLD - covering its sector |
| ... 6 more seconds | | | | | | | | | | | | | | | |

- **Rust_Sirens_2** (law_suppressor, team 1) terminus seed 13123, 23-48 s, 19 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13123 SPOT_ARENA=terminus SPOT_CREW=Rust_Sirens_2 SPOT_FROM=21 SPOT_TO=33`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | 0.39 | 260 | move | MOVE | blocked | terrain |  |  |  | 33.9 |  | 121.1 | 13.3 | 38.5 | 50.9 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 31 | 0.29 | 260 | move | MOVE | blocked | terrain |  |  |  | 34.6 |  | 111.3 | 13.1 | 66 | 51.3 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 32 | -0.88 | 260 | move | MOVE | blocked | terrain |  |  |  | 35 | -14 | 101.1 | 12.8 | 27.5 | 51.4 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 33 | 5 | 260 | move | MOVE | driving |  |  |  |  | 21.2 |  | 156.4 | 11.5 | 27.5 | 52.2 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 34 | 2.82 | 260 | move | MOVE | driving |  |  |  |  | 23.9 |  | 173.4 | 9.4 | 0 |  | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 35 | -3 | 260 | move | MOVE | blocked | no_path |  |  |  | 22.1 |  | 154.8 | 9.4 | 0 |  | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 36 | -2.76 | 260 | move | MOVE | blocked | no_path |  |  |  | 19.9 |  | 126.3 | 10.5 | 0 |  | 32 | 1 | MOVE - assaulting, support by fire, ordered |
| 37 | -3 | 260 | move | MOVE | blocked | no_path |  |  |  | 18.3 |  | 95 | 12.2 | 43.4 | 42.2 | 32 | 4 | MOVE - assaulting, support by fire, ordered |
| 38 | 5.46 | 260 | move | MOVE | blocked | no_path |  |  |  | 18.5 | 2.7 | 97.4 | 9.3 | 48.4 | 43.9 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 39 | -1.14 | 260 | move | MOVE | blocked | no_path |  |  |  | 18.9 | 5 | 105.7 | 4.9 | 48.4 | 45.8 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| 40 | 4.63 | 260 | move | MOVE | driving |  |  |  |  | 17.7 |  | 59.4 | 2.8 | 43.4 | 45.7 | 32 | 6 | MOVE - assaulting, support by fire, ordered |
| 41 | -1.8 | 260 | move | MOVE | yielding | Rust_Sirens_1 | driving | move_to | move | 17.8 |  | 46.5 | 2.5 | 38.5 | 45.6 | 32 | 10 | MOVE - assaulting, support by fire, ordered |
| 42 | -1.81 | 260 | move | MOVE | yielding | Rust_Sirens_1 | driving | move_to | move | 19.5 |  | 35.8 | 0.8 | 38.5 | 44 | 32 | 10 | MOVE - assaulting, support by fire, ordered |
| 43 | -1.23 | 154 | move | MOVE | yielding | Rust_Sirens_1 | arrived | stop | hold | 20.7 |  | 29.1 | 4.1 | 139.1 | 113.9 | 32 | 0 | MOVE - assaulting, support by fire, ordered |
| ... 5 more seconds | | | | | | | | | | | | | | | | | | |

- **Rust_Hunters_1** (ifv, team 1) crossing seed 13184, 110-135 s, 18 flagged s, cause: no answer
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=crossing SPOT_CREW=Rust_Hunters_1 SPOT_FROM=108 SPOT_TO=120`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 117 | -3 | 220 | attack | PURSUE | driving |  | 154.8 |  | 125.1 | 61.6 | 121.7 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 118 | 0.43 | 220 | attack | PURSUE | driving |  | 155.4 |  | 129.3 | 20.7 | 121.3 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 119 | 0.57 | 220 | attack | PURSUE | driving |  | 154.1 |  | 112.3 | 0 |  | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 120 | 1.11 | 220 | attack | PURSUE | blocked | terrain | 166.2 |  | 75.1 | 0 |  | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 121 | -3.21 | 220 | attack | PURSUE | blocked | terrain | 155.4 |  | 63.5 | 28.4 | 122.6 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 122 | -3 | 220 | attack | PURSUE | blocked | terrain | 157.6 | -2.8 | 37.6 | 28.4 | 120.6 | 60 | 0 | TerrainRims | PURSUE Green_Guns_3 - ordered, closing in |
| 123 | 3.87 | 220 | attack | PURSUE | blocked | terrain | 158 | -2.6 | 24.2 | 28.4 | 120.5 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 124 | 0.55 | 190 | attack | PURSUE | driving |  | 153.2 | 0.9 | 6.6 | 90.5 | 111.9 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 125 | -3 | 190 | attack | PURSUE | driving |  | 155.6 | 10.7 | 17.5 | 90.5 | 111.9 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 127 | -3 | 171 | attack | PURSUE | blocked | terrain | 156.2 | 1.4 | 1.4 | 19 | 122.2 | 60 | 0 |  | PURSUE Green_Guns_3 - ordered, closing in |
| 128 | 6.87 | 171 | attack | PURSUE | driving |  | 127.3 |  | 0 | 19 | 122.8 | 60 | 0 |  | PURSUE Green_Hunters_4 - ordered, closing in |
| 129 | 8.62 | 171 | attack | PURSUE | driving |  | 119.3 |  | 0 | 19 | 124.8 | 60 | 0 |  | PURSUE Green_Hunters_4 - ordered, closing in |
| 130 | 9.94 | 171 | attack | PURSUE | driving |  | 110.1 |  | 0 | 0 |  | 60 | 0 |  | PURSUE Green_Hunters_4 - ordered, closing in |
| 131 | 11 | 171 | attack | PURSUE | driving |  | 99.5 |  | 0 | 0 |  | 60 | 0 |  | PURSUE Green_Hunters_4 - ordered, closing in |
| ... 4 more seconds | | | | | | | | | | | | | | | |


### E / answering: 1.17 moments / fight, 4.3 crew-s / fight

671 moments; by map: crossing 159, gorge 95, locks 130, parade 74, sumps 124, terminus 89

- **Rust_Guns_4** (tank, team 1) crossing seed 13184, 192-227 s, 25 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=crossing SPOT_CREW=Rust_Guns_4 SPOT_FROM=190 SPOT_TO=202`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 199 | -2 | 300 | hold | HOLD | driving |  | 4.6 | 0.4 | 37 | 7.1 | 66.1 | 133.8 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 200 | 0 | 290 | hold | HOLD | driving |  | 5.2 | 0 | 0 | 7.5 | 80.8 | 133.2 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 201 | -1.31 | 290 | hold | HOLD | driving |  | 5.1 | 0.5 | 13.9 | 8 | 80.8 | 133.3 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 203 | 3.3 | 290 | hold | HOLD | driving |  | 4.4 | 0.6 | 46.2 | 9.4 | 0 |  | 70 | 0 |  | HOLD - spring ambush, holding |
| 205 | 4.67 | 268 | hold | HOLD | driving |  | 2.5 |  | 109.7 | 8.1 | 43.7 | 137.6 | 70 | 0 |  | HOLD - spring ambush, outranged: breaking line of sight |
| 206 | 2.61 | 268 | hold | HOLD | driving |  | 3.1 |  | 177.3 | 9.1 | 43.7 | 139.9 | 70 | 0 | Block_3 | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 207 | 3.12 | 238 | hold | HOLD | driving |  | 3.2 |  | 151.3 | 10.5 | 73.7 | 139.9 | 70 | 0 | Block_3 | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 208 | -2.39 | 238 | hold | HOLD | blocked | terrain | 2.9 |  | 163 | 12.1 | 30 | 129.3 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 209 | 0 | 238 | hold | HOLD | arrived |  |  |  |  | 13 | 30 | 128.6 | 70 | 0 |  | HOLD - spring ambush |
| 210 | 0 | 238 | hold | HOLD | arrived |  |  |  |  | 13.3 | 0 |  | 70 | 0 |  | HOLD - spring ambush |
| 211 | 1.67 | 207 | hold | HOLD | driving |  | 3.2 |  | 151.8 | 12.6 | 54.3 | 135.4 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 212 | 0 | 188 | hold | HOLD | arrived |  | 4.7 |  | 136.8 | 14.5 | 73.3 | 133.8 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: breaking line of sight |
| 213 | 0 | 188 | hold | HOLD | driving |  | 5.8 |  | 121.8 | 16.3 | 73.3 | 132.6 | 70 | 0 |  | HOLD - spring ambush, holding, outranged: out of its sight |
| 215 | 0.24 | 188 | hold | HOLD | driving |  | 5.9 |  | 66.5 | 18.9 | 0 |  | 70 | 0 |  | HOLD - spring ambush, holding |
| ... 11 more seconds | | | | | | | | | | | | | | | | |

- **Rust_Lances_3** (lancer, team 1) crossing seed 13184, 61-86 s, 19 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=crossing SPOT_CREW=Rust_Lances_3 SPOT_FROM=59 SPOT_TO=71`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 68 | 0 | 200 | hold | HOLD | yielding | Rust_Lances_1 | yielding | stop | hold | 25.1 | -7.1 | 171.9 | 7.4 | 39.7 | 132.2 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 69 | 0 | 200 | hold | HOLD | yielding | Rust_Lances_1 | yielding | stop | hold | 25.1 | -6.3 | 171.9 | 7 | 39.7 | 132.2 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 70 | 3.13 | 200 | hold | HOLD | driving |  |  |  |  | 26.4 | -4.5 | 167.6 | 7.4 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 71 | 1.9 | 200 | hold | HOLD | driving |  |  |  |  | 27.4 | -3.2 | 141.9 | 7.3 | 43.1 | 129.4 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 72 | 6.03 | 200 | hold | HOLD | driving |  |  |  |  | 28.3 | -3.2 | 136.4 | 4.8 | 43.1 | 132.7 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 73 | 5.1 | 186 | hold | HOLD | driving |  |  |  |  | 6.7 |  | 116.2 | 3.7 | 88.2 | 136.5 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 74 | 5.64 | 186 | hold | HOLD | driving |  |  |  |  | 7 |  | 118.5 | 3.3 | 45.1 | 136.5 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 75 | 4.61 | 186 | hold | HOLD | driving |  |  |  |  | 7.2 |  | 123.7 | 3.4 | 45.1 | 136.3 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 76 | 5.97 | 186 | hold | HOLD | blocked | Rust_Guns_3 | yielding | move_to | hold | 6.8 |  | 132.7 | 3.3 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 77 | 5.1 | 186 | hold | HOLD | driving |  |  |  |  | 6.6 |  | 162 | 3.5 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding |
| 78 | -2.63 | 186 | hold | HOLD | driving |  |  |  |  | 6.6 | 0.1 | 166.8 | 5.2 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding |
| 79 | -2.34 | 186 | hold | HOLD | blocked | Rust_Hunters_1 | driving | move_to | attack | 6.1 | 0.8 | 162.5 | 6.7 | 24.9 | 134.1 | 90 | 0 | HOLD - base of fire, support by fire, holding |
| 80 | 0 | 186 | hold | HOLD | arrived |  |  |  |  |  |  |  | 6.4 | 24.9 | 133.6 | 90 | 0 | HOLD - base of fire, support by fire |
| 81 | 2.67 | 186 | hold | HOLD | driving |  |  |  |  | 5.6 |  | 161.8 | 6.5 | 76.7 | 133.6 | 90 | 0 | HOLD - base of fire, support by fire, outranged: breaking line of sight |
| ... 5 more seconds | | | | | | | | | | | | | | | | | | |

- **Rust_Lances_3** (lancer, team 1) crossing seed 13184, 86-108 s, 16 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13184 SPOT_ARENA=crossing SPOT_CREW=Rust_Lances_3 SPOT_FROM=84 SPOT_TO=96`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 93 | -0.53 | 186 | hold | HOLD | driving | 8 | 0 | 155.2 | 7.8 | 44.5 | 130.7 | 90 | 0 | Container40_5 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 94 | 0.53 | 186 | hold | HOLD | driving | 7.8 | 0.2 | 152.2 | 8.1 | 40.5 | 119.9 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 95 | -0.14 | 186 | hold | HOLD | driving | 8.1 | -0.1 | 145.6 | 7.3 | 40.5 | 120.4 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 96 | 1.73 | 186 | hold | HOLD | driving | 8.7 | -0.8 | 143.8 | 6.9 | 40.5 | 120.9 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 97 | 1.79 | 162 | hold | HOLD | arrived | 11.7 | -3.7 | 136.8 | 8.3 | 39.6 | 133.9 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 98 | -1.46 | 162 | hold | HOLD | arrived | 11.6 | -3.7 | 123.1 | 8.8 | 39.6 | 133.6 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 99 | 4 | 162 | hold | HOLD | driving | 12.1 | -4.4 | 120.7 | 9.3 | 39.6 | 134.4 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 100 | 5.58 | 162 | hold | HOLD | driving | 13.8 | -5.7 | 119 | 9.4 | 0 |  | 90 | 0 | Block_3 | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 101 | 1.15 | 112 | hold | HOLD | arrived | 6.1 |  | 116.2 | 8.9 | 50 | 133.4 | 90 | 0 | Block_3 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 102 | 5.07 | 112 | hold | HOLD | driving | 7 |  | 125.6 | 9 | 50 | 135.2 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 103 | 0 | 80 | hold | HOLD | arrived | 8.4 |  | 135.2 | 9.4 | 82 | 147.8 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 104 | 0.8 | 80 | hold | HOLD | driving | 8.4 |  | 135.3 | 10.5 | 32 | 147.9 | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 105 | 6.49 | 80 | hold | HOLD | driving | 11.1 |  | 139.6 | 8.9 | 32 | 151.4 | 90 | 0 | Block_3 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 106 | 7.71 | 80 | hold | HOLD | driving | 15.8 | -9.7 | 157.8 | 9.7 | 0 |  | 90 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| ... 2 more seconds | | | | | | | | | | | | | | | |

- **Rust_Guns_2** (syn_tank, team 1) parade seed 13216, 43-65 s, 16 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13216 SPOT_ARENA=parade SPOT_CREW=Rust_Guns_2 SPOT_FROM=41 SPOT_TO=53`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 50 | -4.2 | 320 | hold | HOLD | driving | 2.9 |  | 54.5 | 5.4 | 70.5 | 131.6 | 110 | 0 | HOLD - spring ambush, outranged: out of its sight |
| 51 | 0 | 320 | hold | HOLD | driving | 5.3 |  | 38.1 | 6.6 | 70.5 | 134.5 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 52 | 0 | 320 | hold | HOLD | driving | 5.3 |  | 94.1 | 6.6 | 72.3 | 134.5 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 53 | 2.99 | 320 | hold | HOLD | driving | 5.7 |  | 144.7 | 6.8 | 34.1 | 130.2 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 54 | 0.22 | 320 | hold | HOLD | driving | 9.6 |  | 163.7 | 8.7 | 34.1 | 133.2 | 110 | 0 | HOLD - spring ambush, holding |
| 55 | -4.66 | 320 | hold | HOLD | driving | 7.8 | -4.9 | 82.8 | 7.7 | 0 |  | 110 | 1 | HOLD - spring ambush, holding |
| 56 | 0 | 320 | hold | HOLD | driving | 7.9 | -2.6 | 86.9 | 7.4 | 16.9 | 137.4 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 57 | 3.03 | 320 | hold | HOLD | driving | 7.9 | -2.6 | 84.7 | 7.6 | 16.9 | 137.2 | 110 | 0 | HOLD - spring ambush, holding |
| 58 | 4.02 | 320 | hold | HOLD | driving | 7.8 | -2.1 | 86.2 | 8 | 16.9 | 136.4 | 110 | 0 | HOLD - spring ambush, holding |
| 59 | -4.46 | 320 | hold | HOLD | driving | 7.2 | 2.4 | 150 | 7.6 | 0 |  | 110 | 0 | HOLD - spring ambush, holding |
| 60 | -2.87 | 320 | hold | HOLD | driving | 3.2 | 4.6 | 175.5 | 5.5 | 0 |  | 110 | 0 | HOLD - spring ambush, holding |
| 61 | 4 | 320 | hold | HOLD | driving | 3.3 | 4.6 | 152.9 | 5.6 | 51 | 124.1 | 110 | 1 | HOLD - spring ambush, outranged: out of its sight |
| 62 | 6.6 | 320 | hold | HOLD | driving | 9.7 | -1.8 | 160.9 | 8.8 | 84.7 | 138 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 63 | 6.78 | 320 | hold | HOLD | driving | 16 | -8.2 | 163.3 | 11.9 | 84.7 | 144.6 | 110 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| ... 2 more seconds | | | | | | | | | | | | | | |

- **Rust_Lances_1** (lancer, team 1) crossing seed 13131, 199-221 s, 14 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13131 SPOT_ARENA=crossing SPOT_CREW=Rust_Lances_1 SPOT_FROM=197 SPOT_TO=209`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 206 | -2.28 | 200 | hold | HOLD | driving | 6 | 0.9 | 57.7 | 29.2 | 124.9 | 90 | 0 | HOLD - base of fire, support by fire, holding |
| 207 | -2.4 | 200 | hold | HOLD | driving | 6.3 | 2.1 | 59.5 | 69.3 | 130.2 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 208 | 0 | 200 | hold | HOLD | arrived | 7.2 | -0.8 | 46.2 | 69.3 | 128.6 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 209 | 0 | 200 | hold | HOLD | arrived | 7.2 | -1.2 | 46.2 | 40 | 128.6 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 210 | 0 | 200 | hold | HOLD | arrived | 7.2 | -1.4 | 46.2 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 212 | 0.53 | 200 | hold | HOLD | driving | 4.8 | 1.5 | 50.1 | 68.8 | 126 | 90 | 0 | HOLD - base of fire, support by fire, outranged: out of its sight |
| 213 | -2.4 | 200 | hold | HOLD | driving | 5.9 | 1.3 | 28.7 | 94.7 | 130.5 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 214 | -2.4 | 200 | hold | HOLD | driving | 7.9 | -0.7 | 27.1 | 94.7 | 129.3 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 215 | -2.4 | 200 | hold | HOLD | driving | 10 | -2.7 | 37.2 | 25.9 | 127.4 | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 216 | -2 | 200 | hold | HOLD | driving | 11.3 | -6 | 24.6 | 0 |  | 90 | 0 | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 218 | 1.96 | 200 | hold | HOLD | driving | 4.1 | 1.8 | 11.1 | 46.4 | 124.8 | 90 | 0 | HOLD - base of fire, support by fire, outranged: breaking line of sight |
| 219 | 0 | 200 | hold | HOLD | arrived | 2.2 | 5.8 | 13.3 | 46.4 | 125.5 | 90 | 0 | HOLD - base of fire, support by fire, outranged: breaking line of sight |
| 220 | 2.8 | 200 | move | MOVE | driving | 16 |  | 157 | 46.4 | 125.4 | 90 | 0 | MOVE - assaulting, support by fire, ordered |
| 221 | 2.4 | 200 | move | MOVE | driving | 16.4 |  | 150.8 | 0 |  | 90 | 0 | MOVE - assaulting, support by fire, ordered |

- **Rust_Wrenches_1** (gang_support, team 1) crossing seed 13164, 56-75 s, 13 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13164 SPOT_ARENA=crossing SPOT_CREW=Rust_Wrenches_1 SPOT_FROM=54 SPOT_TO=66`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 63 | 6.93 | 187 | hold | HOLD | yielding | Rust_Wrenches_2 | yielding | move_to | move | 14.4 |  | 147.3 | 15.9 | 42 | 35.8 | 14 | 0 | TerrainRims | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 64 | 3.29 | 190 | hold | HOLD | driving |  |  |  |  | 13.5 | -1.7 | 130.1 | 15.1 | 0 |  | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: out of its sight |
| 65 | 5.86 | 195 | hold | HOLD | driving |  |  |  |  | 14.9 | -2.2 | 129.6 | 15.2 | 0 |  | 14 | 0 |  | HOLD - base of fire, support by fire, holding |
| 66 | 5.5 | 154 | hold | HOLD | driving |  |  |  |  | 17.1 | -4.6 | 118.4 | 15.4 | 43 | 42.1 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 67 | -1.07 | 112 | hold | HOLD | driving |  |  |  |  | 18.4 | -5.9 | 94.7 | 15.7 | 88 | 41.8 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 68 | -1.53 | 114 | hold | HOLD | driving |  |  |  |  | 18.4 | -4 | 74.2 | 13.9 | 88 | 41.3 | 14 | 0 | TerrainRims | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 69 | 6.95 | 80 | hold | HOLD | driving |  |  |  |  | 17.3 | -3.8 | 54.9 | 11.2 | 82 | 42.1 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 70 | 8.21 | 67 | hold | HOLD | driving |  |  |  |  | 9.8 | 5 | 33.6 | 3.4 | 75 | 45.9 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 71 | 0 | 70 | hold | HOLD | arrived |  |  |  |  | 7.1 | 10 | 38 | 5.4 | 52 | 47.3 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 72 | 0 | 72 | hold | HOLD | arrived |  |  |  |  | 7.1 | 11.3 | 38 | 6.2 | 15 | 47.3 | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 73 | 0 | 78 | hold | HOLD | arrived |  |  |  |  | 7.1 | 11.3 | 38 | 8.6 | 0 |  | 14 | 0 |  | HOLD - base of fire, support by fire, holding, outranged: breaking line of sight |
| 74 | 0 | 83 | hold | HOLD | arrived |  |  |  |  |  |  |  | 13 | 0 |  | 14 | 0 |  | HOLD - base of fire, support by fire |
| 75 | 0 | 88 | hold | HOLD | arrived |  |  |  |  |  |  |  | 13.9 | 0 |  | 14 | 0 |  | HOLD - base of fire, support by fire |

- **Rust_Eyes_1** (syn_scout, team 1) gorge seed 13203, 81-100 s, 13 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13203 SPOT_ARENA=gorge SPOT_CREW=Rust_Eyes_1 SPOT_FROM=79 SPOT_TO=91`

| s | speed | hp | order | choice | phase | blocked | blocker_phase | blocker_move | blocker_order | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | touch_what | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 88 | 7.09 | 64 | hold | HOLD | driving |  |  |  |  | 5 |  | 173.1 | 7.4 | 45.5 | 142.9 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 89 | 10.2 | 64 | hold | HOLD | driving |  |  |  |  | 15.1 |  | 166.1 | 3.3 | 84.6 | 145 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 90 | 6.39 | 64 | hold | HOLD | yielding | Rust_Eyes_2 | driving | move_to | hold | 23.1 |  | 135.9 | 3.2 | 39.1 | 144.4 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 91 | -4.14 | 64 | hold | HOLD | yielding | Rust_Eyes_2 | blocked | move_to | hold | 22.6 |  | 134.7 | 2 | 39.1 | 144.6 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 92 | -2.45 | 64 | hold | HOLD | yielding | Rust_Eyes_2 | blocked | move_to | hold | 20.5 |  | 131 | 3.8 | 0 |  | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 93 | 0 | 64 | hold | HOLD | yielding | Rust_Eyes_2 | driving | move_to | hold | 20.3 | -15.2 | 130.1 | 4.3 | 36.7 | 148.4 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 94 | 2.33 | 64 | hold | HOLD | driving |  |  |  |  | 20.4 | -5.4 | 127.8 | 4.6 | 56.8 | 148.3 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 95 | 3.84 | 64 | hold | HOLD | blocked | no_path |  |  |  | 24 | -0.9 | 125.7 | 1.8 | 92.8 | 145 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 96 | 5.95 | 64 | hold | HOLD | blocked | no_path |  |  |  | 25.1 | -2.5 | 117.3 | 2.4 | 56.1 | 141.8 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 97 | 0 | 64 | hold | HOLD | blocked | no_path |  |  |  | 25.6 | -5.1 | 171.2 | 6.9 | 36 | 140.9 | 55 | 0 |  | HOLD - holding, outranged: out of its sight |
| 98 | 0 | 64 | hold | HOLD | blocked | no_path |  |  |  | 25.7 | -5.4 | 117.1 | 11.1 | 0 |  | 55 | 0 | Perimeter | HOLD - holding, outranged: out of its sight |
| 99 | -2.77 | 64 | hold | HOLD | driving |  |  |  |  | 25.5 | -5.1 | 129.9 | 11.3 | 0 |  | 55 | 0 |  | HOLD - holding |
| 100 | -9.71 | 64 | hold | HOLD | driving |  |  |  |  | 18 | 6 | 179.3 | 3.9 | 0 |  | 55 | 0 |  | HOLD - holding |

- **Green_Guns_1** (gang_tank, team 0) locks seed 13129, 101-119 s, 12 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13129 SPOT_ARENA=locks SPOT_CREW=Green_Guns_1 SPOT_FROM=99 SPOT_TO=111`

| s | speed | hp | order | choice | phase | blocked | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 108 | -2.8 | 356 | hold | HOLD | driving |  | 2.1 |  |  | 18.9 | 32 | 64.9 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 109 | -2.8 | 340 | hold | HOLD | driving |  | 4.3 |  | 30.7 | 18.2 | 32 | 67.4 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 110 | 1.07 | 324 | hold | HOLD | driving |  | 5.8 | -2.7 | 30.4 | 19.1 | 32 | 68.8 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 111 | 0.07 | 300 | hold | HOLD | driving |  | 4.1 | 1.1 | 55.8 | 21.1 | 56 | 67.2 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 112 | -2.8 | 275 | hold | HOLD | driving |  | 5.6 | -3.5 | 45.3 | 19.1 | 65 | 68.5 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 113 | -0.13 | 275 | hold | HOLD | driving |  | 7.2 | -5.1 | 42.4 | 16.5 | 49 | 69.5 | 50 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 114 | 6.89 | 250 | hold | HOLD | driving |  | 5.7 | -1.4 | 86.4 | 15.1 | 50 | 68.8 | 50 | 0 | HOLD - spring ambush, covering its sector, outranged: out of its sight |
| 115 | 9 | 250 | hold | HOLD | driving |  | 11.6 | -5.8 | 172.2 | 13.2 | 25 | 71.9 | 50 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 116 | 11.03 | 250 | hold | HOLD | driving |  | 21.3 | -17.2 | 161.5 | 12 | 25 | 80.7 | 50 | 0 | HOLD - spring ambush, holding, outranged: out of its sight |
| 117 | 3.9 | 250 | hold | HOLD | driving |  | 28.8 | -23.3 | 172.9 | 11.8 | 0 |  | 50 | 0 | HOLD - spring ambush, holding |
| 118 | -3.6 | 250 | hold | HOLD | driving |  | 28.7 | -21.5 | 174.2 | 11.8 | 0 |  | 50 | 0 | HOLD - spring ambush, holding |
| 119 | -3.9 | 250 | hold | HOLD | blocked | terrain | 24.8 | -19.1 | 175.6 | 12.3 | 0 |  | 50 | 0 | HOLD - spring ambush, holding |

- **Green_Hunters_6** (law_ifv, team 0) locks seed 13144, 107-125 s, 12 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13144 SPOT_ARENA=locks SPOT_CREW=Green_Hunters_6 SPOT_FROM=105 SPOT_TO=117`

| s | speed | hp | order | choice | phase | to_go | gain_5 | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 114 | 3.67 | 280 | hold | HOLD | driving | 16.2 |  | 154.8 | 14 | 54 | 90.8 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 115 | 0 | 280 | hold | HOLD | arrived | 16.6 |  | 155.5 | 14.4 | 26.5 | 90.4 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 116 | -3.47 | 280 | hold | HOLD | driving | 15.8 | -13.9 | 172.2 | 13.6 | 0 |  | 60 | 0 | HOLD - holding |
| 117 | -5 | 280 | hold | HOLD | driving | 11 | -6.5 | 179.6 | 8.6 | 0 |  | 60 | 0 | HOLD - holding |
| 118 | -3.95 | 280 | hold | HOLD | driving | 6.2 | 6 | 180 | 4.6 | 0 |  | 60 | 0 | HOLD - holding |
| 119 | -2.1 | 280 | hold | HOLD | driving | 3.3 | 12.9 | 180 | 3.2 | 27.5 | 81.5 | 60 | 0 | HOLD - holding |
| 120 | 5.61 | 280 | hold | HOLD | driving | 4.7 | 11.9 | 160.5 | 2.3 | 93.5 | 83.1 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 121 | 9.35 | 244 | hold | HOLD | driving | 13.4 | 2.5 | 165.3 | 6.6 | 156 | 87.6 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 122 | 3.67 | 229 | hold | HOLD | driving | 18.4 | -7.5 | 165.7 | 11.9 | 128.5 | 89.6 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 123 | 0 | 152 | hold | HOLD | arrived | 19.5 | -13.3 | 166.3 | 13.1 | 62.5 | 89.9 | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 124 | 0 | 97 | hold | HOLD | arrived | 19.5 | -16.2 | 166.3 | 13.1 | 0 |  | 60 | 0 | HOLD - holding, outranged: breaking line of sight |
| 125 | -3.85 | 15 | hold | HOLD | driving | 16.9 | -12.2 | 178 | 11.3 | 0 |  | 60 | 0 | HOLD - holding |

- **Green_Guns_4** (tank, team 0) sumps seed 13146, 64-82 s, 12 flagged s, cause: answering
  `make spotter-clip SPOT_SEED=13146 SPOT_ARENA=sumps SPOT_CREW=Green_Guns_4 SPOT_FROM=62 SPOT_TO=74`

| s | speed | hp | order | choice | phase | to_go | route_off | squad_d | hit_dmg | fire_far | range | shots | intent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 71 | 0 | 300 | hold | HOLD | arrived |  |  | 12 | 19.3 | 78.2 | 70 | 0 | HOLD - covering its sector |
| 72 | 0 | 300 | hold | HOLD | arrived |  |  | 12 | 19.3 | 78.2 | 70 | 0 | HOLD - covering its sector |
| 73 | 0 | 300 | hold | HOLD | driving | 2.6 | 57.6 | 12 | 19.3 | 78.2 | 70 | 0 | HOLD - covering its sector, outranged: out of its sight |
| 74 | 0 | 300 | hold | HOLD | driving | 2.6 | 21.2 | 12 | 19.3 | 78.2 | 70 | 0 | HOLD - covering its sector, outranged: out of its sight |
| 75 | 0 | 300 | hold | HOLD | arrived |  |  | 12.2 | 19.3 | 78.4 | 70 | 0 | HOLD - covering its sector |
| 76 | 2.33 | 300 | hold | HOLD | driving | 2.2 | 45 | 12.3 | 27.5 | 78.6 | 70 | 0 | HOLD - covering its sector, outranged: out of its sight |
| 77 | 2.8 | 300 |  | HOLD | driving | 27.2 | 163 | 14 | 66 | 83.5 | 70 | 0 | HOLD - covering its sector, outranged: closing |
| 78 | 0.33 | 300 |  | HOLD | driving | 27.4 | 83.6 | 14.4 | 66 | 83.7 | 70 | 0 | HOLD - covering its sector, outranged: closing |
| 79 | 8.51 | 300 |  | HOLD | driving | 22.4 | 14.7 | 16.3 | 38.5 | 79.8 | 70 | 0 | HOLD - covering its sector, outranged: closing |
| 80 | 7.82 | 300 |  | ADVANCE | driving | 12.7 | 25.8 | 15.1 | 19.3 | 67.2 | 70 | 0 | ADVANCE - outranged: closing |
| 81 | 0 | 278 | move | MOVE | driving | 12.7 | 163.5 | 15 | 48.3 | 64.3 | 70 | 0 | MOVE - ordered |
| 82 | -2.17 | 214 | attack_move | COVER_FIRE | driving | 5.9 | 26.5 | 14.5 | 112.3 | 64.5 | 70 | 0 | COVER_FIRE Rust_Lances_1 - squad focus, shield low, in cover |

