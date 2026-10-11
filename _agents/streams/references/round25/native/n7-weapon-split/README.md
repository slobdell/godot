# N7: where the weapon block's time goes (builder0, headless, before choosing the seam)

`make native-tp-headless` (Sumps, 25 a side with leaders, window 8-20 s, seeds 92721 31337 5988, n = 3), on a LOCAL
throwaway branch `local/native-laps-weapon` (2a79ef2f + one more lap commit, = 40060c44 + measurement-only sub-laps in
gunnery.gd; never merged). Tick scripts 34.7 ms.

`parts-laps.txt`: brain/weapon 3.97 ms = weapon.scan 1.86 (the engine's sight ray: native_scan earned ~0) + w.indirect
0.42 (artillery) + lanes (FireLanes.for_shot / _clear_to_fire) 0.26 + w.lanes.engage (Engagement.engage) 0.26 +
w.aim.lead (Ballistics lead + Difficulty offset) 0.21 + weapon.aim (fixed-mount steer, aim_error, range) 0.16 +
w.aim.cover 0.10 + w.notarget 0.09; ~0.6 unlapped (apply()'s wrapper). What a native_weapon seam can replace: ~1.4 ms
of section (4 % of the tick); at the 15-45 % ports have realized, ~0.2-0.6 ms saved: under the 2 % bar alone.

`drive-profile.txt` (`--native-drive-profile`, same runs): ~95 us a drive; GDScript callbacks inside the native
drive: Pathing.query re-plans 16-18 us, the k-turn planner (planned_reverse) 10-12.5, negotiate 1.2-1.4.
