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

_(the worker keeps this current; newest first within each section)_

### B1 acceptance pre-registration (written 2026-10-02 ~01:30, before any run of seeds 25–32; not edited after)
- **Arms, one batch:** `climb` (main's flight) against the B1 fix — `climbrestlow` unless design series 2
  (`climbrestlead*`, pit + yard, seeds 11–18) beats it on pooled hides with seen-without-hiding no lower; the choice is
  recorded here before the acceptance batch starts.
- **Seeds 25–32, maps Terminus, yard, pit, Locks, 240 s, builder0, `make airship-view VIEW_TRACE=1`.**
- **(1) the cluster gone or halved:** intrusions STARTING at 38–50 s, pooled over all 32 runs per arm: fix ≤ 0.5 × climb.
- **(2) the rest unchanged:** pooled hides-the-fight per map not up by more than 0.5 points; longest intrusion per map
  not up by more than 1 s (declared noise: the same seeds read 1.2 % and 3.3 % on the pit in two batches).
- **(3) seen-share not down:** seen-without-hiding (in frame and not hiding, round 14's c′) pooled per map ≥ 0.9 × climb
  on every map where climb's is ≥ 1 %; maps under that report and are not scored.
- **Ships ON** (`view_rest` and the levers it carries flipped to true; C15.1 — `view_climb` itself untouched) only if
  (1)–(3) all hold; otherwise OFF with the numbers, one switch away.

### B1: the 39–49 s cluster — NAMED; the fix built behind `viewrest`, being measured
- **Instrument:** `make airship-view VIEW_TRACE=1` writes one row per sim tick per run; `python3
  tools/airship_view_pool.py --trace <dir>` lists every intrusion with what led up to it (and, B2, a ledger of what
  each climb bought and cost against the same hull at cruise).
- **Data:** builder0, `d8935f54`, climb ON (main's default), seeds 11–18, Terminus/yard/pit/Locks, 240 s each:
  hides-the-fight pit 3.32 %, yard 2.52 %, Terminus 0.55 %, Locks 0.86 % (pooled); 60 intrusions; 16 of them at
  38–50 s (plus 20 more spread over 114–240 s: the cluster is the FIRST occurrence of one mechanism, not a separate one).
- **Buckets (all 60):** camera LIFTED at onset + hull climbing **54**; lifted + hull at cruise 5; camera at rest 1.
  The camera's jump to the next group was within 3 s of onset in only 5.
- **The mechanism, in order:** (1) the cluster is the first lap's near arc — on every open-map seed the hull first
  comes within 35 m of the camera at 31–49 s, and the first hide follows within 2 s; (2) at cruise that pass hides
  nothing from where the camera RESTS, so the climb's look-ahead never asked (`warning_s` 0 in most rows), but the
  hull's footprint grown by `RtsCamera.HULL_LEAD_M` holds the camera, so round 11's lift fires — up AND back until
  "the hull lies between him and the fight" (its own comment), which is the intrusion; (3) the climb then aimed over
  the LIFTED lens and rose through its sight lines, with targets of 33–60 m against 31 m over the resting lens;
  (4) and even a climb that arrived in time set the lift off: the belly sat 1.5 m over the lens, inside the lift's
  2 m reach under the belly (`RtsCamera.SOLID_CLEAR_M`). Test `test_a_hull_climbed_over_the_lens_no_longer_sets_off_the_lift`
  pins (4) both ways.
- **The fix (`--airship-on=viewrest`, OFF until measured), on the airship's side:** plan against the camera's pose
  WITHOUT the hull lift (`RtsCamera.rest_transform`, the one additive accessor), count the lift's zone as one more
  thing to climb over (planned by the same ghost), and keep the belly over the lens by the lift's reach + 1.5 m.
- **Design series running:** builder0, `e4550e3c`, pit + yard, seeds 11–18, arms climb / climbrest / climbrestsink /
  climbrestlow. Acceptance on 25–32 (all four maps) after.

**Baseline:** `85703220` (branch start) builder0 `>> remote: make check exited 0`, 1821 passed / 0 failed, 18 passed +
1 NOT JUDGED (`scenario_perf`, loaded ref=1.80x — the known row), sim-baseline `6313a38d7ecd99bb` unmoved.

### Plan (in order, 2026-10-02 ~00:30)
1. **B1** — a per-tick trace in `make airship-view` (`VIEW_TRACE=1`) and a reader (`tools/airship_view_pool.py
   --trace`); the cluster read on the round-14 acceptance seeds 11–18 (where it was seen), climb ON, four maps; buckets
   by mechanism; then the fix the bucket names behind a switch. **Seeds named before any variant:** design 1–4, 7,
   11–18; acceptance **25–32** (never run before acceptance).
2. **B2** — seen-share levers re-measured with the climb ON as the base (lower target; sooner return to cruise;
   camera-side orbit bias), each behind a switch; pre-registered bars from the brief; acceptance on 25–32 too.
3. **B3** — `airship-shot CLIP=1` pit + Terminus; the four-worst sheet under `references/round15/airship/`.
4. **B4 (stretch)** — the lift-vs-climb ordering: measured both ways on the design seeds; a REQUEST if it is the camera's.

Reasons: the trace first because round 14's logs kept no per-intrusion times (the claim "39–49 s" came from per-run
logs that were not filed), so the cluster cannot be read back from the references.
