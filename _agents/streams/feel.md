# Stream: feel (round 9 — the War Rig bends in the middle, and motion that reads as obedience)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 9 direction* §1 — your item; *The Syndicate airship*), [../workstreams.md](../workstreams.md) (*Round 9:
> the seven streams* — you own **S2** and author **S4**; the CP1/CP2 rules; the round-6 table still gives you **M1**,
> **M3**, **K4**, **K5**, **L5**, **C6**), [../research_catalog.md](../research_catalog.md) row **A6**,
> [../art_direction.md](../art_direction.md), [../slot_contracts.md](../slot_contracts.md), and your own round-8 report
> in [archive/round8/feel.md](archive/round8/feel.md) *Status* (the trailer costing, the fit fix, the gun cut, the sky
> and void fixes — all yours, all still true).
>
> **You own** `game/theme/**` (materials, shaders, effects, props, the crowd and its voice), `game/audio/`,
> `game/announcer/`, `assets/{announcer,audio,music}/` and the art paths, `tools/{assets,announcer,audio}/`,
> `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md`,
> and the new `_agents/legibility.md`.

## The lead's direction (2026-09-19, evening, verbatim)

> *"1. The semi trucks for the road gangs are still one long box itself of a truck / trailer combination."*

> *"2. We resized the semi trucks for the gang and this makes the game much cooler and awesome."*

He called both minor. The first is yours; the second is the **scale** stream's (every vehicle at real relative size,
checkpoint **CP2**) and reaches you only as a fit check after it lands. It is round 8's item 4 asked a second time —
then: *"the gang semi trucks don't actually behave like a semi truck with a truck and a trailer — both components just
move together … I don't know how easy this is to do or if we should shelve it for later."* You costed it at close:
**a visual-only hinge is about a day, negligible runtime, the sim untouched, the rigid 14 m box is the compromise.**
That costing is the adopted shape (contract **S2**).

And the airship, approved for round 9: *"a Bladerunner-like Airship that hovered over the arena, sometimes visible in
the field of view, that also had a big TV screen … Syndicate-feel"* — *"yes please record that."* Stretch, last.

## Where things stand (surveyed 2026-09-19 on `main` at `f49aa08a`)

**The rig today.** `gang_tank` is one `Tank` (`game/tank/tank.gd`), one collision box `[3.32, 5.24, 14.0]` from
`Units.PROFILES` (`game/units/units.gd:378`), one hull mesh `game/theme/factions/gangs/generated/unit_gangs_tank_hull.glb`
— natural size **0.85 × 1.35 × 3.60 m** (`make assets-inspect IN=…`), forward −Z, bounds z −1.80 … +1.80. The hull is
fitted uniformly by length in `DozerPart._fit_to_hull` (`game/theme/cyberpunk/dozer_part.gd:73`): fit = 14.0 / 3.6 ≈
**3.89**, so one model-space metre is 3.89 world metres. The naval gun is already cut out of that mesh at runtime by
`FactionArt.GUN_CUTS["gangs/tank"]` (`game/theme/factions/faction_art.gd:128`): a box in model space, a pivot, and
`rest_yaw_deg: 180` because the gun was modelled pointing backwards; `DozerPart._cut_gun` (`dozer_part.gd:101`) splits
every `MeshInstance3D` with `FactionArt.split_mesh` (`faction_art.gd:151`, triangle-centroid test, cached per mesh and
box) and parents the inside piece to a `GunPivot` that `_process` (`dozer_part.gd:133`) yaws to the tank's turret each
frame. **The trailer is the same mechanism with a different box and a different law for the pivot's yaw.** The gun cut
box sits at z −0.3 … +1.9 in model space, i.e. on the trailer's back — after your cut the gun pivot must be a child of
the *trailer* pivot, not the hull, or the gun stays on the tractor's heading while the trailer swings under it.

**The drawn transform is not the sim transform.** `project.godot` has `physics/common/physics_interpolation=true`
(line 74); the sim ticks at 30 Hz and a frame draws an interpolated pose. `Tank` resets interpolation at spawn
(`tank.gd:182`) and respawn (`tank.gd:603`), and switches it off in one configuration (`tank.gd:174` — read why before
relying on it). A hinge integrated per frame must read the tank's **drawn** pose (`get_global_transform_interpolated()`)
and integrate with the frame's delta, never the physics tick — and it must reset itself whenever the tank resets its
interpolation, or the first frame after a respawn draws a trailer streak from the wreck.

**The trailer must not reach the simulation, and there is a proof ready.** Art fills `VisualSlot`s under the tank
(orientation trip-up 34); colliders come from `hull_size`; combat showed by construction in round 7 that art cannot
reach the hash. `make sim-baseline` on your branch against the current `main` hash (`glibc-2.43 04414f5d6a6dfa7c`,
builder0 only — the laptop's glibc 2.39 line does not exist and the target silently skips, Invariant 2) is the
assertion. **Pre-registered: it does not move.** If it does, that is information about something else on the tree —
say so, do not "fix" it.

**Things HANDOFF still lists as open that you already closed in round 8** — verify, do not rebuild: the texture leak
on the title → skirmish switch (the Environment `Sky`'s radiance mips; fixed by the unshaded `NightSky` dome,
`3040ccd9`) and **the void below the near wall** (the cutaway's near plane clips every real surface, so the dome now
draws the city's ground where each ray meets y = 0, plus a `CityGround` plane out to the skyline, same commit). One
frame at each of the lead's poses (12° and the 35° telephoto) confirms both stayed fixed through round 8's merges; if
either regressed, that is X5.

**A6 is a contract before it is code** (workstreams **S4**). Your round-8 handover already states the law: a
*turreted* hull fighting off-axis keeps its nose within ~25° of the ordered corridor's tangent and lets the turret
fight; a *hull-fixed* hull stays in forward-oblique bounds so every leg visibly advances. The motion code is nav's
(`movement.gd`, `combat_motion.gd`) and combat's; the readout is control's. **Nobody writes A6 motion code until feel,
control and nav have all signed `_agents/legibility.md`.** control's desktop right-drag facing lands first regardless.

**Two smoke targets of yours accuse innocent code once a round.** `announcer-record-smoke` (`mk/announcer.mk:119`) and
`music-smoke` (`mk/audio.mk:35`) ask *"does this subsystem perturb the simulation?"* — a differential question — and
answer it by comparing one run against the shared baseline file (orchestration lesson 65). Note `music-smoke`'s own
comment (`mk/audio.mk:32-34`) already says the comparison should be against a control run — read the recipe and check
whether the `expected=` control run is actually what is compared, or whether the baseline file still wins; the recipe
runs a control match at line 38 and compares at line 53, so the remaining defect may be narrower than the lesson says.
Establish it before changing it.

**The airship's screen is already built.** `AdBroadcast.channel(node, name)` (`game/theme/arena_kit/ads/ad_broadcast.gd:59`)
gives every screen on a channel one shared material — *ten screens cost one layout* — and `LiveFeed` (`live_feed.gd`)
replays kills from frames already on the GPU. An airship hull is an ellipsoid, fins, a gondola and a plane: primitives,
no Meshy (88 credits, and Meshy's failure mode is "cartoon", the wrong failure for the Syndicate).

## Backlog (in order)

**X1 — the trailer cut.** A `TRAILER_CUTS`-style entry beside `GUN_CUTS` for `gangs/tank`: a box in model space
covering everything aft of the fifth wheel, and the hinge pivot at the fifth wheel on the tractor's chassis line.
**Measure the fifth wheel from the mesh**, do not guess: `make assets-view IN=…unit_gangs_tank_hull.glb SPLIT=1` and
`make facing-audit UNITS=gang_tank` side-on, then place the box so the cab and the tractor's drive axles stay on the
hull and the tank body and its bogie go to the trailer. Test first: a headless test that the cut produces two
non-empty pieces whose merged bounds equal the uncut bounds (nothing lost, nothing doubled), that the gun pivot is now
under the trailer pivot, and that a unit with no trailer cut is untouched. Then frames: `make facing-audit` and
`make vehicle-gallery` before and after — **the approved model must not move by a pixel at rest**, since a hinge at
zero angle is the original mesh. Look at them.

**X2 — the hinge.** Per frame, from the tractor's drawn pose: with v the drawn speed along the tractor's forward, θ the
angle between the tractor's heading and the trailer's, and L the trailer's wheelbase (hinge to the bogie's centre,
measured from the mesh in X1 and scaled by the fit), `dθ_trailer/dt = (v / L) · sin(θ_tractor − θ_trailer)`; in
reverse v is negative and the trailer diverges, which is correct and is what jackknifing is. Clamp |θ| to a jackknife
limit (~65–70°; the cab must never intersect the tank body — check against the mesh, not a number), reset to θ = 0
on spawn and respawn (`Tank` calls `reset_physics_interpolation()` there — hook the same moments), and integrate with
the frame delta. Tests: a scripted figure-eight on a `ScriptedController` asserting the trailer lags the tractor,
never exceeds the limit, and settles to zero on a straight; a unit test of the law on a pure turn (steady-state angle
for a constant-radius circle is `asin(L / R)` — assert it). **Frames are the deliverable**: `build/rig-hinge/` — a
strip of a rig cornering at the lead's pose (21°, 49 m, FOV 35, the `size-look` camera, `mk/fx.mk:85`) and one at his
12°, plus a 3–4 s clip if `perf-scene`'s capture path makes it cheap. Send the path to the orchestrator; he takes it to
the lead. **Then `make remote T=sim-baseline` on the branch: green on the current main hash, pre-registered.**
Frame cost: the rig is still one draw per part; `make perf-scene` before/after with the gang army must not move
(M1: a locked 30 fps at 1080p with 30 a side).

**X3 — `_agents/legibility.md`, the A6 contract page.** One page: the law above stated precisely (angles, which
corridor tangent — the current order's path leg, not the straight line to the goal); which units it binds (turreted
vs hull-fixed, by `mount`); **who executes it** — nav's velocity layer, named as a *priority* in A7's priority table
(nav is writing that table now; read nav's brief Status and agree the row with them rather than proposing a second
mechanism); **what the player is shown** — control's readout; the joint falsifier (time with velocity opposing the
corridor tangent **30–36% → under 10%, with no fall in exchange ratio**), and what A6 **replaces** (Invariant 0c —
"nothing" is the answer the orchestrator interrogates). Send it to the orchestrator for control and nav to sign; record
each signature on the page with a date. Until all three have signed, the page is the whole deliverable.

**X4 — after CP2 (the resized roster merges): the fit is right at every size.** Merge `main`, then land
`test_the_semis_fill_their_boxes` generalised to every unit with art (your `26e1f26a` on branch `feel-rig-check` is the
seed — it survives in the shared repo): drawn box vs `hull_size` within tolerance, mutation-checked against a
deliberately wrong box. **scale derives the numbers; you check the art is not distorted** — `_fit_to_hull` is uniform
by length so nothing should stretch, but a model whose proportions disagree with its new box is a finding for scale,
not something to stretch away. Look at `make vehicle-gallery`, `make size-look` with a mixed army, and one real match
at his pose. Hand scale any unit whose box the mesh cannot fill.

**X5 — the lead's poses, checked.** The void under the near wall and the sky leak: one frame each at 12° and 35°
(`make camera-looks` is control's tool and makes the same frames; use its output rather than a second harness) and
`make shell-playtest`'s console for leak lines. If both hold, one line in Status; if not, fix what regressed.

**X6 — the two smoke targets made honest** (lesson 65). Establish first *whether* each still compares against the
baseline file or against its own control run (read the recipe; run it on a tree whose baseline you have deliberately
staled). Whichever still asks the absolute question becomes differential: the same match twice in one invocation,
with and without the subsystem, the two hashes compared to each other, and the message names the subsystem only when
the two differ. Keep the existing checks (a valid recording, the beds changed).

**X7 — stretch: the Syndicate airship.** Primitives only (an ellipsoid envelope, fins, a gondola, a screen plane
on an `AdBroadcast` channel — the ad channel's average colour already lights the ground, so the arena is washed in
whatever it shows), Syndicate livery per `art_direction.md` (pristine, no rust), **no collision body of any kind**,
drift driven from the fixed tick's count (`Match.tick`) so a replay shows it where it was, and never the wall clock.
"Sometimes visible in the field of view" is verified **at his pose with frames** — control's `camera-looks` per-edge
frames — not with a screenshot taken to show it. Tiered like the crowd (off on LOW if it costs a draw the web build
cannot spare). Pre-register the sim hash unchanged; if it moves, it is the same class of surprise as arena's
`_build_perimeter()` (workstreams Invariant 2) and worth reporting.

## How to verify

- `make remote T=check` on every merge candidate; iterate locally with `make check` and a `FILTER=` — never claim
  readiness from a filtered run (lesson 45). Read the wrapper's `>> remote: make check exited <N>` and the runner's
  `N passed, M failed`.
- `make remote T=sim-baseline` on the branch after X2 and X7: green on main's hash. That is the S2 guarantee.
- Frames you look at: `make facing-audit UNITS=gang_tank TURRET=70`, `make vehicle-gallery`, `make size-look`,
  `build/rig-hinge/` (yours, new), `make camera-looks` (control's). Desktop and phone aspect where a HUD is in frame.
- `make perf-scene` before/after with a gangs army for X2 and X7 (M1 budget); `make shell-playtest` console for leaks.
- `make announcer-check` and `make audio-check` after X6, once on a tree with a deliberately staled baseline to prove
  the new comparison cannot be fooled by it (prove a guard can go red, Invariant 0).
- Every number carries its commit and its machine (builder0 ≈ 2.75× the laptop).

## Don't touch

- The simulation: `game/tank/`, `game/ai/`, `game/units/`, `game/match/`, `game/combat/`. The trailer is art; if the
  hinge needs a value the sim does not expose, ask through the orchestrator — do not add a field to `Tank`.
- The roster's numbers (`hull_size`, `muzzle_height`, the spawn grid): **scale**'s this round. You report a mesh that
  cannot fill its box; you do not edit the box.
- control's paths (`game/control/`, `game/ui/`, `game/camera/`), including `camera-looks` — use its output.
- **One grant into your paths, made at launch:** scale adds an additive `lineup` view to your
  `game/theme/fx/bench/size_look.gd` (the 21-unit side-by-side frame for the lead), calling `box_at_length` rather than
  copying it. You review that diff at merge and own the file again afterwards; do not refactor `size_look.gd`
  underneath it mid-round.
- nav's motion code. A6 is a page until three signatures are on it.
- No Meshy (88 credits); ElevenLabs only under the standing text-approval gate, and nothing in this backlog needs it.

## Waiting on the lead

- Nothing at start. The X2 cornering frames go to him through the orchestrator; the airship's look (X7) goes on a
  frame before it ships, since "Syndicate-feel" is his to judge.

## Status

### Plan (feel, 2026-09-20)

**Order changed at the top, with a reason: X3 first, then X1 → X2 → X6 → X5 → X4 (after CP2) → X7.** X3 is a page,
it costs no build, and *two other streams are blocked on it* — nav cannot write A7 code and control cannot write the
readout until it is signed. Everything else in the backlog is mine alone. So the blocking doc goes first and the
rest of the round runs behind it.

- **X3 — `_agents/legibility.md`: DONE and sent (`4ec341d2`), awaiting nav's and control's signatures.** See below.
- **X1 — the trailer cut.** Measured, not started.
- **X2 — the hinge.** Not started.
- **X6 — the two smoke targets.** Not started.
- **X5 — the lead'''s poses.** Not started.
- **X4 — the every-unit box-fill test.** Blocked on CP2 by design.
- **X7 — the airship.** Stretch, last.

### X3 — the A6 contract (S4): written, feel signed, nav reviewed

`_agents/legibility.md` at **`4ec341d2`**. nav asked for one decision and got it.

**feel confirms nav'''s level 3** (above formation, below the weapon band). A6 does not outrank the standoff band:
its own falsifier bars trading exchange ratio for a tidy line; for the 3 hull-fixed units a law above the band would
point the gun mount down the corridor and stop them shooting; and for turreted hulls the conflict is nearly empty,
since level 2 constrains the *radial* component and leaves the tangential free.

**The one change asked of A7'''s table — and the reason the page is worth more than a one-line brief: the falsifier is
measured on VELOCITY, not on heading.** A6-a (the nose clause) cannot move P7 on its own, because a turreted hull'''s
nose is already free of its gun and its velocity is chosen at levels 1, 2 and 5. So A6 also claims what level 3'''s
null space currently gives away — *the sign of the arc*: when both shoulders serve the band equally, take the one
that advances along the corridor. Level 3'''s remaining null space is speed alone. Circling is untouched; the
*shoulder* is claimed. One cell in nav'''s table, and the difference between A6 mattering and A6 being cosmetic.

Also settled in the page: the corridor is N1'''s `path_points` current leg with exactly one publisher; composition
with the arc/armour task written per style (`strafe` 10 units, `angle` 8, `standoff` 3, `run` exempt as an A/B
control); an inactive law must not read as a broken one (lesson 149), so active ticks are flagged with a reason and
the falsifier is computed over them with the active fraction reported beside it; Invariant 0c answered as
*"replaces nothing"* and then argued rather than asserted.

### The rig, measured (X1'''s input; `9f864474`, laptop, `make assets-profile`)

`unit_gangs_tank_hull.glb` is a long-nose tractor with a plow and a **tanker** trailer, natural 0.85 × 1.35 × 3.60 m,
forward −Z, fit to the 14.0 m box = **3.889**. In model space:

| feature | model z | world z (× 3.889) |
|---|---|---|
| plow tip (front) | −1.80 | −7.00 |
| steer axle | −1.13 | −4.39 |
| cab rear wall | −0.19 | −0.74 |
| **gap: zero triangles in the body band (y 0.40–1.12)** | −0.19 … −0.01 | 0.70 m of air |
| tanker front cap | −0.01 | −0.04 |
| drive tandem axles | +0.19, +0.39 | +0.74, +1.52 |
| trailer bogie | +1.55 | +6.03 |
| tanker rear | +1.80 | +7.00 |

New tool in the same commit: **`make assets-profile IN=… [AXIS= SLICES= BOX= CLIP=1 RENDER=1]`** — a slice table
(triangles, height, width per slice) plus a **ruled orthographic side view whose pixels are metres**. A perspective
turnaround cannot be read as a number, and the cut box has to be read off the mesh.
