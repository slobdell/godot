# Stream: airship (he played whole matches on the built-up maps and never saw it)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *The Syndicate airship* (why it
> exists: *"sometimes visible in the field of view"*), *Round 11 direction* (*The camera and the airship: push up, not
> away*), *Round 14 direction, first item* (steer clear of his view) and *Round 15: the airship's "what gives way",
> decided on the page* (his pick C), `_agents/workstreams.md` *Round 21* (C21.3), and the archived briefs
> `streams/archive/round14/airship.md` and `streams/archive/round15/airship.md` with their Status (the instruments
> `airship-view`, `airship-report`, `airship-look`, `airship-shot`; the arms; the noise declaration; B2's finding that
> no altitude lever reached the in-frame bar; B3's finding that pointing the camera near the hull makes it LEAVE the
> shot). Evidence: `streams/references/round14/airship/`, `references/round15/airship/`. **You own**
> `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
> `game/theme/fx/bench/airship_shot.gd`, `game/theme/fx/bench/rig_vanish.gd`, `tools/airship_view_pool.py`, the airship
> targets in `mk/fx.mk`, the `_build_airship` carve-out in `game/theme/cyberpunk/arena_dressing.gd`. **Read-only:**
> `game/camera/**` (one additive accessor allowed, listed in merge notes; a fix on the camera's side is a REQUEST),
> `arenas/**`, `game/arena/**` (the map layouts; `Arena.ROTATION` is the live list you read).

## The lead's direction

2026-09-19, why it exists: *"a Bladerunner-like Airship that hovered over the arena, sometimes visible in the field of
view, that also had a big TV screen"*. 2026-09-23: *"we push the camera up above the airship (that way there's more
likelihood of seeing the cool airship for an in-game effect)"*. 2026-09-27: *"frequently when we're playing the
airship flies right in front of the camera and disrupting the game… make the airship smarter and try to avoid blocking
the player's field of view"*. 2026-09-28, shown the climb's cost (seen half as often): *"ah ok that's a great idea,
turn that on by default"*. 2026-10-03, his tap: **C** (climb against where the camera rests; the camera stops lifting
over the hull). **Nothing new from him in words this round:** the finding is the orchestrator's from his afternoon play
on 2026-10-06 (he played the garage's fights on foundry and never saw it), measured below. Standing: opaque, visible,
in the venue, 1.5×, never faded or cut away; the fight is never hidden behind it.

## Where things stand (read at `0a9ce446`, main, the orchestrator's laptop)

- **`make airship-report`** (headless, his pose, `SEEN_YAWS` averaged, `LEG_S` default), share of the flight in his
  frame: **terminus 0 %, cut 0 %, locks 1 %, crossing 1 %, docks 3 %**, sumps 10 %, pit 16 %, the open maps
  (parade, yard, gorge, archipelago) 24–31 %. Inside something drawn: 0 % everywhere (round 11's rule holds).
- **Why (hypothesis, labelled; verify first):** on the built-up maps the pilot climbs over tall kit (`_clear_spot`, the
  solid rule) and the view-climb (`view_climb`, `view_rest`, `view_low`) keeps the belly above
  `SyndicateAdAirship.visible_ceiling_at(distance)`; the frame's top edge is 3.5° BELOW the horizon at his pitch, so
  anything above the ceiling at its range is out of frame. On the open maps there is less to climb over and the
  carrot's orbit brings the hull low into frame between the squads' views. Round 15's B2 found no altitude lever
  reached the brief's in-frame bar on the four maps it tested; the built-up rotation maps were never in the list.
- **The instrument's default list is stale (lesson 265):** `airship_report.gd` `MAPS` is the round-11 nine; the
  rotation is twelve (`Arena.ROTATION`: yard, pit, terminus, crossing, sumps, locks, parade, gorge, archipelago, cut,
  docks, yard_open). Six rotation maps were never measured until 2026-10-06.
- The airship is built on every map; his laptop preset does not remove it (FX tier HIGH on desktop). It costs no
  credits and nothing in the sim (dressing; the baselines never see it).
- `make airship-view` is not tick-repeatable; quote pooled series only (round 15's known issue). `VIEW_DISPLAY=1` on
  builder0 is ~1 fps. `make airship-look` needs a display (builder0's is unlocked and on).

## Backlog (in order)

**V0. The instrument reads the live rotation.** `airship_report.gd` defaults to `Arena.ROTATION` (plus `MAPS=` to
override); a test fails when a rotation map is missing from the report; the report prints a per-map line and a
pooled line. Run it on main's flight on builder0 as the BEFORE table (commit, machine, LEG_S, seeds) in Status.

**V1. Name the mechanism per map.** For each built-up map (terminus, cut, locks, crossing, docks, sumps) attribute the
missing share by REMOVING one thing at a time (lesson: a cost is attributed by removal, not by ratio): the view-climb
(`AIRSHIP_OFF=viewclimb`), the rest-climb (`viewrest`), the solid-clearance climb over kit, the carrot's altitude/orbit
radius. A table: map × lever removed → in-frame %, hides-the-fight % (`airship-view`, pooled seeds). The lever that
returns the share without raising hides-the-fight is the design; if none does, say so with the numbers.

**V2. Seen on every map (the behaviour).** Build the lever(s) V1 names so that on every rotation map the hull is in
his frame for a real share of the flight without hiding the fight more than main does (C21.3). Candidate designs to
decide among with V1's table, not before: (a) a lower cruise over kit where the sight lines allow it (clear the kit
by a margin, not by the ceiling); (b) the climb sinks back faster and lower once the camera has moved on
(`view_sink`, measured OFF in round 15 on four maps; re-measure on the built-up six); (c) "appearances": the pilot
plans a pass that crosses the top third of his frame on purpose every N seconds, far side of the fight, then climbs
out, so he SEES it and it never stands between him and his vehicles; (d) a bigger orbit over the quiet half of the
map at an altitude under the ceiling at that range. The recommended bar (the orchestrator, stated for him in the
launch; his answer may move it): in frame about as often as on the open maps today (20–30 % of the flight), never
over the ground he looks at. Every switch defaults OFF until its acceptance passes; then ON in one commit with the
before/after tables.

**V3. Looked at.** `make airship-look` and `airship-shot` frames on terminus, cut, locks, docks at his pose: the hull
in frame, over the city, not over the fight; desktop and phone aspect; the three worst frames per map from
`airship-view VIEW_DISPLAY=1` if it runs; put them under `streams/references/round21/airship/` and say what you see.

**V4. Docs.** The airship section of `game_design.md` is his words (do not edit); write yours in the file headers and in
`_agents/show_dials.md` or `lighting.md` if a dial moved; a one-line entry in `roadmap.md` is the orchestrator's.

**Stretch (a).** The deck panel is seen at ~89° (`deck_grazing_deg`): a dark slab in play. If V2's lower cruise brings
it under 80°, say so; if a tilt of the deck panel toward his pose is cheap and looks right in the frames, do it.
**Stretch (b).** A hardware-preset switch for the laptop (`FX tier`) that keeps the airship but drops its screen's
feed to a static poster, if the frames show the feed costs him anything (measure first with `make perf-play`).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED (the airship is dressing; say so
  in each commit).
- `make airship-report` on the live rotation, before and after (builder0, same LEG_S); `make airship-view` pooled
  seeds on at least the six built-up maps for hides-the-fight; `make airship-look` frames looked at.
- Play it: `make skirmish ARENA=terminus` and `ARENA=cut` for a few minutes at his pose; does the airship come into
  the top of the frame now and then, and does it ever stand between you and your squad? Record what you saw.
- Every number: commit, machine, workload, seeds (C16.3). Builder0 is ~2.75× faster than the laptop.

## Don't touch

`game/camera/**` (read-only; a request) · `game/control/**`, `game/ui/**` (orders') · `game/tactics/**`, `game/ai/**`
(brains') · `arenas/**`, `game/arena/**` (nobody; you READ `Arena.ROTATION`) · the rest of `game/theme/**` outside your
files · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- **How often he wants to see it** (asked in the launch, in his terms, recommended: as on the open maps today, a glimpse
  every minute or two, never over the fight). Build the recommendation; his answer moves the bar, not the method.

## Status

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
