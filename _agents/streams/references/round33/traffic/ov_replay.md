# Round 33 overnight (traffic, T4's replay line): a same-process rematch does not replay, ghost OFF too

Tree: stream/traffic-overnight `07f588f0` (game code = main `e46f1720` + parkedroom, DEFAULT_OFF). Laptop, GDScript
path (no native library), `--fixed-fps 60`. Probe: `tests/traffic/rematch_probe.gd -- --seed=<s> --arms=off,off,off
--diff=on --diff-y=off [--traffic-on=ghost]`: brains' body stage (the Locks, body OFF) three times in ONE process;
`--diff` compares every tank's flat position, real_velocity and estimated_velocity per match tick against run 0 and
prints the first difference. Raw: `ov_replay_seeds.txt`.

**This corrects `x4_rematch_statics.md` (R33.17) and roadmap `42040bc9`:** "ghost OFF, a rematch replays exactly" held
on seed 1 only (n 1). Over six seeds it does not.

| seed | ghost OFF alone_s, runs 0 / 1 / 2 | ghost ON alone_s, runs 0 / 1 / 2 |
|---|---|---|
| 1 | 35.0 / 35.0 / 35.0 | 37.0 / **28.5** / 37.0 |
| 2 | 12.0 / 12.0 / 12.0 | 14.5 / **15.0** / 14.5 |
| 3 | 39.0 / **37.0** / 39.0 | 40.0 / **37.5** / 40.0 |
| 4 | 34.5 / 34.5 / 34.5 | 51.0 / 51.0 / 51.0 |
| 5 | 56.5 / **19.5** / **19.5** | 14.5 / **57.0** / 14.5 |
| 6 | 15.5 / 15.5 / 15.5 | 16.0 / 16.0 / 16.0 |

A rematch branched on 2 of 6 seeds with the ghost OFF, and on 4 of 6 with it ON (n 6 each, one machine, one tree).

## Where it enters (seed 1)

- **Both arms:** the rematch's first tick already differs in hull HEIGHT (Green_Hunters2_1 y 0.000871 in run 0 v
  0.00087 in run 1). That is the physics server settling the hull on the floor differently in a second match.
- **Ghost OFF, seed 1:** the flat state (x/z, real and estimated velocity) never differs, so the AI replays.
- **Ghost ON, seed 1:** everything flat is identical through tick 48. At tick 49 Green_Sirens_3's x/z differs by
  ~7e-5 m and the run branches. The AI's inputs were identical up to that tick, so the slide itself (a contact the
  height difference changes) is what moved; the ghost then feeds the physical displacement to ORCA.
- **Not the shared physics space:** `--clear=world` (a new World3D, so a fresh physics space and navigation map,
  before each rematch) reads the same as no clear (seed 1, ghost ON: 37.0 → 28.5; ghost OFF 35.0 → 35.0). Clearing
  every traffic static and Movement's registry doesn't change it either (R33.17).
- **Odd:** the third match usually reads like the first (4 of the 5 branched cases go A, B, A). Not explained.

## What it means for T4's replay line

A same-process rematch is not replay-exact on the shipped tree (ghost OFF) either. The ghost makes a branch more
likely (4 of 6 v 2 of 6, n 6), because it reads displacement and not the commanded velocity, but it does not cause it.
A fresh process replays exactly in both arms (every run 0 here, and sim-baseline's hashes). So the replay line for T4
is that the ghost adds no new kind of non-replay: a fresh process is replay-exact ghost ON, and the same-process
rematch is a pre-existing property for the match/physics owner. The fix belongs to that owner (a match in a fresh
process, or whatever resets the server's carry), not to traffic.
