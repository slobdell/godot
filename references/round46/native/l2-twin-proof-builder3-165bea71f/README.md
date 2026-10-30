# Engage L2's decide twin: EQUAL on his replays (builder3 light, 2026-10-30)

engage 9446e1903 (lane cases decided in GDScript: `not (LANE_CLEAR and lane_case(s))` routes them off the native path) v
pair/native-l2 165bea71f (that guard removed; decide_native.cpp twins the lane rule). His two recordings, full length, all crews;
every non-`sel` row compared (the match row's `path` dropped).

| Recording | seconds | rows base / pair | differing | divergence from his match (both arms) |
|---|---|---|---|---|
| Gorge 2026-10-29T09-35-51 | 107 | 426 / 426 | 0 | 11/20 within 3 m, first over Green_Hunters_1 @50 s |
| Terminus 2026-10-29T22-57-47 | 151 | 2071 / 2071 | 0 | 1/20 within 3 m, first over Green_Guns_1 @22 s |

The divergence from his match is L2's behaviour (LANE_CLEAR ON); on main both replay 20/20 to ~their ends. Unit sample:
test_native_decide 7536 decisions / 0 mismatches, 78 CLEAR_LANE choices only the lane rule makes; a broken C++ edge gives 29.
