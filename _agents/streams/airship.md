# Stream: airship, round 15 (the view-climb is ON; now the intrusions it does not fix, and what it costs him)

> Read [`game_design.md`](../game_design.md) *Round 14 direction, first item* and *Round 14: the view-climb decided*
> (his words), the archived round-14 brief `archive/round14/airship.md` and its **Status** (A1's instrument, A2's two
> terms, A3's acceptance table, the noise declaration, the 39–49 s cluster), the headers of
> `game/theme/arena_kit/airship/{airship_flight,airship_sight,airship_view,airship_pilot}.gd`, and
> `references/round14/airship/view/` (per-seed JSONs, the design logs, `a3_pit_seed17_off_t753_hull_in_front.png`).
> **You own** `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
> `game/theme/fx/bench/airship_shot.gd`, `game/theme/fx/bench/rig_vanish.gd`, `tools/airship_view_pool.py`, the airship
> targets in `mk/fx.mk`, the `_build_airship` carve-out in `game/theme/cyberpunk/arena_dressing.gd`. **Read-only:**
> `game/camera/**` (one additive accessor allowed, listed; the round-11 camera LIFT over the hull is part of what he
> sees — if the fix for an intrusion is on the camera's side, it is a REQUEST in Status, not an edit).

## The lead's direction

2026-09-27: *"make the airship smarter and try to avoid blocking the player's field of view"*. 2026-09-28, shown the
view-climb's numbers and its cost (seen half as often): *"ah ok that's a great idea, turn that on by default"*.
2026-10-01: *"playin right now feels good"* — an overnight round, no new complaint. Standing: opaque, visible, in the
venue, 1.5×, never faded or cut away; flies from the fixed tick.

## Where things stand (verify on main)

- `AirshipFlight.view_climb := true` (his toggle; `AIRSHIP_OFF=viewclimb` restores round 13). The steering term
  (`viewsteer`) OFF: measured no help live. `climb_squads` ON (climbs for each squad's likely view too).
- `make airship-view` (headless, the live camera driven the way he plays, pooled over seeds; NOT tick-repeatable, so
  only pooled series are quoted): with the climb, hides-the-fight pit 2.3 %, yard 2.5 %, Terminus 1.2 %, Locks 1.2 %;
  longest intrusions 4.5–6.2 s; **in his frame about half as often as before** (pit 14 → 4.4 %).
- **The 39–49 s cluster:** on every map an intrusion lands around 39–49 s into the match, climb or not. Unchased.
- Most intrusions are the camera travelling to the hull (a squad selected under it; the round-11 lift then moves the
  camera up and over).

## Backlog (in order)

**B1. The 39–49 s cluster, named.** From the per-seed JSONs and a run with per-tick positions: what is the airship
doing at 39–49 s (its first lap's far side? the first fight's centre moving? the loader's first camera jump?), where is
the camera, and why the climb does not prevent it (planned too late? the camera arrived under it?). Buckets, with the
frame of the worst one at his pose. Then the fix the bucket names, behind a switch, measured on fresh seeds (name them
before the build: 25–32) with `airship-view` both arms; the cluster gone or halved, the rest unchanged, seen-share not
down.

**B2. Seen as often as before, still out of the way.** The climb halved how often he sees the ship. Measure what buys
it back without putting it in the way: a lower climb target (built in round 14, OFF, "measured no help" — re-measure
with the climb ON as the base), a return to cruise sooner after the view clears, or an orbit biased to the camera's
side where the belly is over the lens anyway. Pre-register: in-frame share back to ≥ 70 % of round 13's, hides-the-fight
not up by more than 0.5 points on any map, longest intrusion not up. Ship what holds.

**B3. The clip he will watch.** `airship-shot CLIP=1` on the pit and the Terminus, the live camera, climb ON: looked at;
a sheet of the four worst moments under `references/round15/airship/`. If something reads wrong to a viewer (a
climb that reads as fleeing, a wallow lost), say so with the frame.

**B4 (stretch).** The camera's side: when the camera jumps to a squad under the hull, the round-11 lift moves the
camera; with the climb on, which should give way first? Measure the two orders on the same seeds; the answer is a
REQUEST to a camera stream if it is the camera's.

## How to verify

`make remote T=check`; `airship-view` both arms with commit, machine, seeds; `test_theme_ad_airship.gd` (the determinism
property, screens-in-frame) green; sim baseline `6313a38d7ecd99bb` pre-registered UNMOVED (dressing). Look at the clip.

## Don't touch

`game/camera/**` beyond one listed accessor; `game/arena/**`; `game/ai/**`; `game/garage/**`; `game/tactics/**`. No
transparency, no fade, no cutaway of the hull.

## Waiting on the lead

Nothing; the sheets and the clip are for his morning.

## Status

_(the worker keeps this current)_
