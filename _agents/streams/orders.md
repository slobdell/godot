# Stream: orders (attack from a side you draw; showmatch recordings worth sharing)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (reading (5), the
> press–drag–release gesture) and *Round 27 direction*, `_agents/workstreams.md` *Round 27* (C27.3, C27.6), and round 26's
> orders report (`streams/archive/round26/orders.md`, *Round 27 candidates*). You own `game/control/**`, the order hints
> in `game/ui/**` (help/hint text about order input only; list them in Status), `tests/test_control*.gd`, the control
> playtests and their make targets in `mk/command.mk`, the showmatch/cinematic tooling you built in round 26, and this
> round (grant) `game/camera/**`'s cinematic framing.

## The lead's direction

Round 26: *"I was trying to get tanks oriented in a screen at a particular angle … This is probably the case for all our
specialized cases (attack, ambush, screen, etc)."* Round 26 gave screen, support by fire, ambush, attack-move and move a
drawn facing; **attack** was left out (decided for him overnight 2026-10-11: a round 27 candidate). Round 26 also: he
asked for `make demo` *"so I can easily record the game to share with people"* — that is `make showmatch`, and he
watched it to give round 27's feedback, so its recordings matter.

What he will notice: press on an enemy and drag, and the squad swings round to come at it from the side he drew; a
showmatch recording that never ends looking at the floor.

## Where things stand (main `04845af7`)

- Armed orders take a facing (press at the spot, drag toward the facing, release); a click keeps the automatic facing.
- Attack (press on an enemy) takes no direction.
- The cinematic camera's last shot can tilt so the bottom third is the purple floor under the arena (seed 43496 docks,
  `HUD=1` movie's end frame).
- Hull facing at rest against a drawn facing has a tail of 100–167° hulls on every task (round 26 probe, small n).

## Backlog (in order)

**O1 — attack with a drawn direction (C27.3).** Press on an enemy, drag, release: the drag's direction (from the release
point toward the enemy, i.e. the side to come from — pick the reading that feels right in play and write the one-line
reason) goes on the attack task as `task["approach"] = [x, z]`; a plain click on an enemy is today's attack. Show the
drag the way the other armed orders do. Until brains' CP0 merges, test against a stub reading `task["approach"]` in your
paths; after CP0, `git merge main` and prove it end to end through the player's input path (lesson 291: probe the path
the player's input takes — `recall_group` → `order_selection`, never `assign_task` directly).

**O2 — the cinematic camera's last shot stays on the arena.** Clamp the framing so the end shot never looks under the
arena floor; screenshots at desktop and phone aspect of the end frame over several seeds/maps (look at them).

**O3 — hull facing at rest, judged properly.** Per hull class at n ≥ 30, same-seed A/B: how far each hull ends from a
drawn facing per task. Report only; anything to fix is a request (the face-at-rest path is in frozen `order_controller.gd`;
the scout's post facing is brains' S6 rule).

**O4 — stretch:** the help text for the new gesture; a short `make showmatch` clip of a flank attack for him.

## How to verify

`make remote T=check`, `make remote LIGHT=1 T=facing-probe` / `T=facing-shots`; scripted input through the real path;
screenshots at desktop and phone aspect. Every Godot run on builder0 (C27.6).

## Don't touch

`game/ai/**`, `game/tactics/**` (brains', scout's, native's); `order_controller.gd` (native's freeze); `native/**`.

## Waiting on the lead

Nothing.

## Status

_Updated 2026-10-11 night (worker, `godot-orders`)._

**Plan (in order):** O1 the gesture with a stub (the task drops `approach` until brains' CP0 teaches ElementTask the
key) → O2 the end shot (a measuring hook first, then the fix) → O3 the hull probe (built while builder0 runs the
others) → O1 end to end after CP0 (`git merge main` when told) → O4 the flank clip.

### Done

- **O1, the gesture** (`cd113207`): press on an enemy (the right button, or the left with attack-move armed), drag out
  to the side the squad should come from, release. The task gets `approach` = the unit direction from the release
  toward the enemy. **Reading chosen:** the release point is the side to come FROM (the hand puts the squad where it
  wants it, as a move does; the arrow then runs from there INTO the enemy, which is the way the squad hits). A click is
  today's attack, now decided on the release (one rule: every press that can become a drag waits for its release);
  byte-identical command and task (tested). Shift keeps attack-move armed (tasks never queue). A selection that is not
  a squad attacks head-on with a notice ("a drawn approach needs a whole squad"); loose units beside squads attack as
  today (a unit order has no approach). The drag rings the enemy in the attack colour and draws an arrow from the
  pointer into it; the HUD line says "attack Tank 3 from the W". Escape / a right press mid-drag cancel it. Above the
  horizon: the last ground crossed (round 26's rule). **Until CP0 the task carries no `approach`** (ElementTask's
  validator refuses unknown keys): `_copy_approach` checks `ElementTask.KEYS.has("approach")`, so after CP0 it flows
  with no change here. Tests `test_control_attack_approach` (15). Builder0: lint 905 parse; control filter 72/0.
- **O4 help (part)** (`cd113207`): the armed hint ("ATTACK-MOVE: click the ground (drag to face) or an enemy (drag to
  flank)"), the command card's line, and a first-time hint "RIGHT-DRAG: off an enemy: flank it" retired by the first
  flank drag.

- **CP0 merged** (`3a08977e` = main `1c8da4d8` into this branch); `approach` now always rides the attack task, the
  pre-CP0 guard removed and the tests assert it outright (`f0ce6f7f`; builder0 `test FILTER=control` 412 passed / 0
  failed).
- **O1 end to end, through his input path** (`make flank-probe`, `1d3b1bcb`, builder0, foundry, gangs v the quiet
  enemy, no damage, seeds 3/5/8/11/13/21 x left/right = 12 runs per arm). Squad 1 by its key (`recall_group`), the REAL
  right-drag off the nearest enemy (brought 55 m ahead, in sight, and told to hold) out to a side 90 deg off the line;
  the `clicked` arm clicks the same enemy (today's attack), judged against the same side. Every second: the squad
  centroid's bearing from the target against the side drawn.

  | arm | approach on the task | reached the side (within 35 deg) | median s to reach | best side err median | end err median/worst (90 s) | end distance median |
  |---|---|---|---|---|---|---|
  | drawn | 12/12 | **9/12** | 17 s | **1.0 deg** | 51.4/61.5 deg | 18.8 m |
  | clicked | 0/12 | 5/12 (passing through) | 24 s | 89.0 deg | 89.9/158.2 deg | 19.6 m |

  **Read:** a drawn side swings the squad round to it while it closes (90 -> under 20 deg by 13-25 s, 9 of 12). After
  ~40-60 s in contact the centroid drifts off the side: the target cannot die (no damage) and the crews mill round it,
  which a player will not see as often (the target dies). Two seeds (3, 13) never close in EITHER arm (the squad holds
  ~50-75 m; drawn stays 40-54 deg off, brains' 45 deg notches at max reach): for brains, below. The first two forms of
  the probe measured nothing (the target sat 180 m away unseen; then it drove back to its slot and was pursued with the
  side ignored, brains' rule for a mover): fixed, recorded so the numbers are read right.
- **O2 done** (`962ad749`, `afe2bf6e`). A/B on the same seeds (builder0, whole showmatches in real time, a frame
  sampled every second; seeds 43496 docks, 3666 yard_open, 101 pit, 202 docks, 7 cut, 77 cut):
  - before (`--cinematic-keep-angle`, round 26's director): 7 of 650 sampled seconds showed under the arena (each with
    17-50 % of the bottom third cut away; seeds 43496 and 7).
  - after: **0 of 1303** (1920x1080 and 1200x540), and every end frame (36) at 0. A first form of the fix flapped the
    angle (seed 202: 139 jumps in 201 s, the rig's yaw-follow fighting the director): the director now owns the angle,
    at most 4 deliberate cuts in a match. Frames looked at: on the arena at both sizes; the crowd at the top as always.
- **Frames** (`make flank-shots`, 1854x1011 and 1200x540): the ring on the enemy and the arrow from the drawn side into
  it read at both sizes.

- **Camera scope (the orchestrator's question):** the player's skirmish camera is unchanged. `CinematicCamera` is built only
  at `skirmish_mode.gd:613` under `--cinematic` (showmatch, cinematic); its `start()` turning the rig's yaw-follow off
  is its only change to the rig. Pinned by `test_control_cinematic::test_the_players_camera_keeps_yaw_follow` (`a5d3a31b`).
- **Main f4c5f7c9 merged** (`9c6f3381`, scout's CP-S).

### Checks (builder0, `make remote T=check`)

- `1d3b1bcb` (CP0 merged, O1 + O2 + probes): exited 0, **2497 passed / 0 failed, 24 targets ALL JUDGED**, determinism
  foundry 2875411ff4ec6be7.
- **`9c6f3381` (main f4c5f7c9 merged): exited 0, 2505 passed / 0 failed, 24 targets ALL JUDGED**, determinism foundry
  2875411ff4ec6be7. **Merge here for O1 + O2** (named to the orchestrator).

### In progress

- **O3:** `make hull-rest-probe` (drawn v clicked on the same seeds, every faction, per hull class) +
  `tools/hull_rest_table.py`: running on builder0.
- **O4 clip:** `make flank-clip` (Movie Maker, 1080p) queued after it.

### Questions for the lead

- None yet.

### Requests to other streams

- brains (done in CP0): `"approach"` in `ElementTask.KEYS`.
- brains (new): on foundry seeds 3 and 13 an attack task on a holding enemy 55 m away never closes (both arms: the squad
  sits 50-75 m off for 90 s; drawn it circles at reach 40-54 deg off the side and stops). Repro: `make remote
  T=flank-probe FLANK_SEEDS="3 13"`, traces in `build/flank/*/*/screen.json` (`trace` = [s, side err, m, target speed]).

### Known issues

- The first-time hint column clips its longer lines at 1200x540 ("screen / support by fire (dra"): round 26's string,
  seen in the flank frames.
- Seed 7's phone end frame: a dark city block fills the right fifth (an arena building near the camera, not under the
  floor).

### Files touched in `game/ui/**`

- `game/ui/control_hints.gd` (one hint, "flank").
