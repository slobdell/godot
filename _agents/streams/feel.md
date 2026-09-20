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
### THE REPORT — read this first; everything below it is the working record

**FRAMES FOR THE LEAD, all on this laptop:**

| what | path | pose |
|---|---|---|
| **The roster at real relative scale** | `build/roster-lineup/lineup_pose.png` | **his** (21°, FOV 35, 49 m) |
| the same, four faction rows | `build/roster-lineup/lineup_factions.png` | — |
| **The War Rig bending** | `build/rig-hinge/strip_45.png` (reads best), `strip_21.png` (his pose), `strip_reverse_60.png` (jackknife) | 45° / **his** / 60° |
| **The Syndicate airship** | `build/airship-look/airship_widest.png` | 8° tilt — **he cannot see it at 21°**, see §2 |
| **The Terminus out-reading its own fight** | `build/terminus-luminance/terminus_pitch21_fov35_49m_default-camera.png` | **his** — the evidence for the 22/30 finding |

**My look at the resize (the one subjective check I owe on CP2): it works.** `lineup_pose.png` runs Rat Rod **2.9 m**
→ War Rig **14.0 m** and the rig **dominates** — visibly five times the rat rod and clearly larger than the
Condemned Tank at 8.6 m. That is the thing he asked for. Two observations, neither a defect:

- **The Syndicate reads as a different game, and that is the art direction working.** The Railgun Platform is
  pristine white against everyone else's rust and soot — `art_direction.md` calls the Syndicate the ivory tower
  with almost no rust, so this is intended; at roster scale it is simply very legible.
- **The Syndicate is fewer AND smaller** (Skimmer 4.0, Spotter 4.0, Limousine Gunship 4.6, Missile Ring 4.9,
  Railgun Platform 5.4 — the whole faction sits under 5.5 m while three other factions field 8 m+). Their doctrine
  is "fields almost nothing but guns and the eyes to aim them", which argues for fewer-but-bigger. **A look
  question for the lead, not a defect** — the numbers are derived from real reference vehicles, so if it reads
  wrong the reference is what changes.


**Round 9, feel. Green at `5ae7e531`** (builder0: `>> remote: make check exited 0`, `check passed: 16 targets`,
**1,316 passed / 0 failed**, `sim-baseline passed: 04414f5d6a6dfa7c` — unchanged —, `lint: all 543 scripts parse,
8 known artefacts baselined`). Merged to main. *(Squad's later merge moved the baseline to `d4c049819a5833d3`;
mine was verified against the value that was current when it ran.)*

#### 1. "The semi trucks are still one long box" — done, and you have the frames

**The War Rig is a tractor and a trailer now, hinged at the fifth wheel.** It corners like a semi: the cab swings
out ahead while the tanker cuts the corner inside it. It **jackknifes when it reverses**, because that is what a
trailer does.

- **In a live match** (32 rigs, 1,440 samples): mean bend **6.1°**, 4.9% of the time past 30°, 1.2% at the limit.
  So it folds occasionally and **lives near straight** — the occasional truck backing out of a corner, not a fleet
  of broken vehicles.
- **On its own tightest turn** (12 m, its real turning circle): settles at **22.7°** against the textbook's
  `asin(L/R) = 24.9°`. The law is right, not just plausible.
- **Frames:** `build/rig-hinge/` — the corner at 45° (where the bend reads), the same corner at **your pose**, and
  the jackknife from above.

**⚠ One thing to know before you see it happen: the collision box is still the single 14 m box.** A shell can pass
through empty air inside a fold this round. That was the agreed trade for not touching the simulation — and the
simulation is **proved** untouched, not assumed: the hash is identical, and that was predicted in writing before
the work started.

#### 2. The Syndicate airship — built, and there is a decision for you

It exists: envelope, fins, gondola, engine pods, a screen a side sharing the arena's ad channel, so **it replays
your kills overhead**. Syndicate-clean, no rust. No collision. Absent on low-end.

**But the measurement says you will not see it at your pose, and the reason is geometry, not tuning.** The top of
your screen sits **3.5° below the horizon** at pitch 21° — *the sky is never on screen where you play*. Over 768
samples at every tilt you can reach, the first version was visible **0.0%** of the time.

**So I moved it out over the city** (560 m, in front of the skyline, inside the draw distance). Now: **visible 12.5%
of the time at 8–12° of tilt, ~105 px on screen, still never at your default 21°.** The frame is
`build/airship-look/airship_widest.png` — top-left, against the lit city, half out of frame.

**Your call, and it is one line either way:** *(a)* leave it over the city, where you see it when you tilt down —
which is Blade Runner's airship, over a city; or *(b)* accept it cannot hover over the arena in play, and use it on
the title, results and replay screens where the camera can look up.

#### 3. "They still don't do what I command" — the cause is now written down and agreed

Three streams signed `_agents/legibility.md`. The claim: that complaint is **not disobedience, it is
illegibility** — a unit circling correctly still spends a third of its time moving away from where you sent it.
**Nothing has shipped yet**; the page is the contract that stops it being built wrong. The key finding was that the
obvious version of the fix would have done nothing measurable, and nav said so plainly: it would have *"shipped a
heading law, measured no change, and spent a round arguing about the tolerance."*

#### 4. Found on the way, not asked for

- **The Terminus is brighter than the fight.** On the city map, the buildings out-read the vehicles in **22 of 30
  frames at your pose** — with the lighting show switched off entirely, so it is the map, not the show. Cause found:
  it is the only arena with buildings *inside* the fighting area (eight 40 m towers, two of them 40 m from the
  centre) and it has **half the floodlights of `pit`** at the same size. The fix is more light among the buildings.
- **The asset pipeline had its own stale copy of every vehicle's size**, already disagreeing with the real one.
  Harmless today; it would have made every model generated after the resize come out the wrong size, silently.
- **Two of our own safety checks had been described as broken for two rounds** after they were fixed. Proved
  working four different ways.

#### 5. Owed

| item | state |
|---|---|
| The hinge's frame cost (M1) | **Not measured, and the quiet box did not fix it.** Two six-cycle runs on an *empty* builder0 both came back NOT USABLE. The cause is now sized: frame cost regresses on vehicle census at **0.677 ms per vehicle (r 0.921, r² 0.85)**, and the battle thins monotonically through the run (90 → 72), so census alone is worth +0.68…+3.38 ms per cycle against a total cost spread of 6.39 ms and a mean of +0.01 ms. **The confound is the size of the signal, and in one cycle larger than it** — and it is a drift, not noise, so more cycles will not average it away. Needs combat's census-freeze tune (damage off, no deaths, no respawns, default off); the bench will then *require* it and refuse to report when it is off. Do not quote a trailer number until then. |
| The Terminus lighting | Diagnosed and handed to the stream that owns the map file |
| Roof dressing on the Terminus | Your new camera shows roofs far more often; they are undressed. A frame first, then surface treatment |
| The artillery contract check (X4) | **Fixed and green at `9cc69e0b`.** The slot check compared the *authored* pose (legs down, 2.31 m wide) against a box derived from the *driving* pose and blamed the mesh. It now reads the driving silhouette through the shipping theme's part. Refit by length: 1.41 × 2.05 = **2.89** against scale's committed **2.90** — the same box from a third direction. The lookup has its own two tests because it is the link that fails *silently*: a wrong lookup returns `Vector3.ZERO` and the caller quietly falls back to the authored bounds, which is exactly what my first version did. |
| Every-unit hitbox check (X4) | **Written and it found something on its first run** — see below. **Unverified**: builder0 went off the network mid-check. |

**S1 record — the Condemned artillery's box, 2.90 m wide, agreed by three independent routes.** S1 requires the
numbers to be *derived and checked, not mirrored* (Invariant 0), and a single derivation that agrees with itself is
exactly what that rule is aimed at. The box was measured in the pose the unit is shot at in (stowed, outriggers in)
rather than the pose the concept was approved in (deployed, 4.74 m wide), and three routes that share no code path
landed on the same number:

1. **Drawn-vs-box test** (`test_theme_unit_scale`, feel): the drawn mesh fits inside the catalogue box on every
   axis — **2.90**.
2. **`DRIVING_BOUNDS` print** (`test_assets_outriggers`, feel): authored `2.31 × 1.38 × 4.00` → driving
   `1.41 × 1.38 × 4.00`; refit by length to the slot's 8.20 m is `1.41 × 2.05 =` **2.89**.
3. **Inversion of the committed value** (scale, `roster-scale`): the committed `4.74` inverted through the same
   refit gives the stowed width back — scale's derivation, arrived at from the catalogue side, not the mesh side.

The 2.89/2.90 gap is `snappedf(x, 0.01)`'s rounding and nothing else, which is checkable rather than asserted:
`snappedf` is invertible, so the committed value brackets the underlying width to `[1.373171, 1.378049)` — scale's
figure, which I verified independently after quoting an eyeballed `[1.3750, 1.3784]` that was not derived. Route 2
is the one that can fail silently (a bad slot lookup returns `Vector3.ZERO` and the caller falls back to the
authored bounds without raising), so it carries its own two tests and its failure was demonstrated, not assumed.


### Plan (feel, 2026-09-20)

**Order changed at the top, with a reason: X3 first, then X1 → X2 → X6 → X5 → X4 (after CP2) → X7.** X3 is a page,
it costs no build, and *two other streams are blocked on it* — nav cannot write A7 code and control cannot write the
readout until it is signed. Everything else in the backlog is mine alone. So the blocking doc goes first and the
rest of the round runs behind it.

- **X3 — `_agents/legibility.md`: DONE. SIGNED by feel, nav and control (2026-09-20). A6 motion code is unblocked.**
- **X1 — the trailer cut: DONE** (`4a8c1843`), 10 tests, every number measured off the mesh.
- **X2 — the hinge: code and tests DONE** (`4a8c1843`); **the lead's frames are owed** (`make rig-hinge`).
- **X8 — the pipeline's private copy of the roster (scale's finding, Invariant 0): DONE**, mutation-checked.
- **X6 — the two smoke targets: ESTABLISHED, and the premise is wrong.** Both are ALREADY differential; see below.
- **X5 — the lead's poses: VERIFIED CLEAN.** Both round-8 fixes held through every merge since. See below.
- **X4 — the every-unit box-fill test.** Blocked on CP2 by design.
- **X7 — the airship: BUILT, MEASURED, and MOVED because the measurement said he could never see it.** See below.

### ✅ GREEN, and the S2 guarantee delivered: `7a706911` (builder0) — with one honest caveat about the artefacts

**The wrapper's own line: `>> remote: make check exited 0`.** But it continues `(build/ copied back: FAILED)` and
remote.sh then exits 4 on its own policy — *"nothing local proves what the run did"*. **That is the copy-back guard,
not a suite failure**, and the distinction is the one `remote_builds.md` exists to make: rsync died with **exit 255**,
which is ssh, and **builder0 went off the network at ~03:15** (confirmed independently: `No route to host`, 100%
packet loss, and the orchestrator's own check died the same way).

So, precisely: **the numbers below were read from the run's streamed stdout while it was still connected, not from
copied artefacts.** The artefacts are on builder0 and did not come back. **Local `build/` is therefore NOT this
run's and no number may be cited from it** — with one verified exception: `build/rig-hinge/` was produced *locally*
at 01:09–01:10, and nothing in `build/` was written after 03:00 (checked with `find -newermt`), so the lead's frames
are untouched by the failed copy.

**`sim-baseline passed: 04414f5d6a6dfa7c (glibc-2.43)` — exactly main's hash, unchanged**, with **1,273 passed,
0 failed** (main's suite is 1,252; the trailer's 12 and the airship's 5 are the difference). **This is contract S2
delivered: the articulated trailer does not reach the simulation** — and it was *pre-registered as inert before it
was built*, so it is a confirmed prediction rather than a discovered fact. That distinction is the whole reason art
gets asserted rather than assumed here: round 8's `_build_perimeter()` moved the baseline with geometrically
identical walls in a different body creation order (Invariant 2).

**lint local: 531 files, 8 known baselined lines** (metrics' sweep on `main`: 5 files, 8 lines, all `--check-only`
isolation artefacts). **The local lint earned its keep on its first run**: of ten lines it reported, two were mine —
`tests/test_theme_airship.gd` referenced `ArenaDressing` as a class name, and `arena_dressing.gd` has **no**
`class_name`; the game reaches it through its scene. Fixed at `1d3029d8`. Remote lint parse-checks **zero** files
(lesson 157), so that test would have failed at run time in the full suite instead, half an hour and one queue away.

**⚠ The tip has moved past the green hash.** `7a706911` is what builder0 ran; everything after it — the file-existence
guard, `--no-trailer`, the airship, the `spectacle` weight table, the tier fix and the test fix — is **unverified**
and needs a second check. Merge `7a706911`, or wait for the second check; do not merge the tip on this one's word.

### X4 — ran once and found one unit: the artillery's collider is its DEPLOYED pose (`f1859075`)

```
UNIT_BOX_FILL 19 units, worst artillery axis 0 at 38.9%
artillery axis 0: drawn 2.90 m against a 4.74 m box (39% out)
```

**18 of 19 pass**, so scale's resize is right everywhere else and this is not a resize mistake — it is a
measurement that could not have known better.

**The mechanism.** `artillery` is the only unit with an `OutriggerRig` (`artillery_part.gd`): four legs cut loose
from the hull and posed by `set_deployed(ratio)`, **0 = stowed for driving, 1 = jacks down**. Per
`slot_contracts.md` the model's **authored pose is deployed**, so `SizeLook.box_at_length` measured the union AABB
**with the legs down** (4.74 m wide) while `Tank` drives it **stowed** (2.90 m).

**Why it is not cosmetic: `hull_size` IS the collider.** While that artillery drives — most of the time, and all of
the time it is shot at on the move — **its collider is 63% wider than the vehicle you can see.** Shells stop in
empty air beside it.

**Recommendation (scale's number, scale's call): bind the box to the DRIVING pose.** A deployed leg overhanging the
collider is the same accepted cost as the War Rig's jackknife, and far less wrong than 1.84 m of permanent
invisible armour on a moving vehicle.

**The honest half, about my own test:** a unit with two silhouettes cannot match one box in both poses, so **no box
makes this test pass in both states.** It checks the driving pose deliberately. If scale rules the other way, **my
test changes, not their number** — and the exception gets the measurement attached rather than a widened tolerance.

**Confirmed in passing:** `syn_artillery`'s 4.07 m width, which scale flagged as arguable, **passes** the
drawn-vs-box check — its missile wings really are that wide. A look question for the lead, not a defect.

### The Terminus has been wearing the wrong colours for a round (show found it; fixed `637ad4de`)

`CityBlock.neon_color()` honoured only strings beginning with `#`, so every colour **name** a layout used fell
through to a random pick from the **signage** palette. `arenas/terminus.json` asks for `"cyan"` on four blocks and
`"magenta"` on four — **all eight were ignored.**

**And `NeonSigns.COLORS` is `[amber, warm white, RED, violet]`**, so the bug was putting **red and a near-white** on
eight buildings on the lead's city map: the exact two colours I ruled out for show's parapet three hours earlier,
on the grounds that red is a *signal* in this game (beacons, alarms) and cool white is not in the palette. **I laid
down a rule about architectural colour while my own file was breaking it eight times.**

**The half worth remembering is not "honour names", it is the fallback.** A *seeded* random pick in answer to a
name someone typed on purpose **looks exactly like a deliberate choice**, which is how this survived a whole round
of people looking at that map. An unresolvable name is now loud and deterministic; a block that asks for nothing
still gets seeded variety, which was always the intent. The tests read what `terminus.json` actually asks for
rather than remembering it, and assert the result is **not** a signage-palette pick. The hard rejection belongs in
`Arena.validate()` beside the other unknown-key checks — arena's file, scale's this round, flagged to them.

**Frame provenance, for whoever assembles the lead's summary:** every Terminus frame shot before `637ad4de` — all
of show's — has the old accidental palette. **Mine are unaffected:** `build/rig-hinge/` is `foundry`,
`build/airship-look/` is `foundry`, and `build/shell-playtest/` is `pit`. None of the three needs that caveat.
**Not yet verified**: no local Godot runs tonight, so the fix rides the next builder0 check.

### The X8/CP2 composition, and my ruling on it (2026-09-20, scale's find)

**My `AssetContracts` change and scale's resize are each correct alone and RED together** — 14 slot-contract
failures on the merged tree (`test_assets_pipeline::test_committed_generated_themes_meet_their_contracts`,
builder0 `e7ebb372`). I made the pipeline read `Units.PROFILES` on every call, which scale asked for and which was
right; scale then made `hull_size` 1.7–2.4× bigger. The slot size is derived from `hull_size`, the committed art
was normalised to the OLD sizes, so *"too small for the slot"* fires on every unit whose hull grew. **My branch was
green because it had the old roster; scale's was green because it had the old contract table.**

**scale's lesson, and it is better than either of our fixes: INERTNESS DOES NOT COMPOSE.** Neither of us could have
found this alone, and it is the cleanest instance of Invariant 2's own warning the round has produced.

**My ruling: the shape check, not the size check — and NOT simply retiring the rule.**

- scale is right that the absolute check measures nothing now: `_fit_to_hull` scales every part by
  `hull_size[2] / FactionArt.hull_length()`, so a model at 48% of its slot draws at **100%** of it.
- **But retiring it leaves newly generated art ungated, which is the one thing the pipeline is for.** scale's
  `test_every_box_is_its_meshs_proportions_at_that_length` covers every unit **in the catalog**; a fresh `.glb` is
  not in the catalog yet, and `assets-check` is the gate it passes on the way there.
- **So the rule changes question rather than disappearing: not "is this the right size" but "is this the right
  SHAPE".** The fit is uniform by length, so a mesh whose aspect disagrees with its box over- or under-fills in
  width and height — and `hull_size` **is** the collider, so that is a shell through empty air. It is my own
  round-8 roster-wide finding, asserted at the gate from the other side.

**Granted to scale to land inside CP2** (my file; I review at merge), with the code written out and a
`SHAPE_TOLERANCE` of 6% justified by `box_at_length`'s own 0.01 m rounding — **and the instruction that a unit which
still fails is a real finding, not something to widen the tolerance for.** A tolerance chosen to make the red go
away is not a tolerance.

### What is actually verified on the merged tree (run, not inferred — 2026-09-20, laptop, filtered)

**I claimed three files passed that had never executed**, so these were re-run **with `;` rather than `&&`, so each
file reports its own line**:

| file | result |
|---|---|
| `test_theme_trailer` | **12 passed, 0 failed** |
| `test_theme_airship` | **5 passed, 0 failed** |
| `test_assets_outriggers` | **6 passed, 0 failed** |
| `test_theme_city_block` | **5 passed, 0 failed** (after `a33638b8`) |
| `test_theme_unit_scale` | **1 failed** — the artillery handover red, expected |
| `test_units_scale` (scale's) | **1 failed** — same artillery cause, `2.9 m` |

**The lesson, in its general form:** an `&&` chain reports the first failure and **silence** for everything after
it, and silence reads exactly like success at the bottom of a log. **A batch claim has to name each file's own
passed/failed line.** I read one summary line, took it for four files, and told another stream three of them had
passed — one of which was genuinely broken and merged on that claim. It is the round's recurring shape
(*something that looked finished and was not*) arriving in my own reporting rather than in someone's code.

### READY TO RUN the moment the orchestrator calls the quiet window (three runs, in this order)

**Why they wait: two of the three are TIMING or BEHAVIOUR measurements, and builder0 was at load 20.89 with 67
Godot processes and six resident checks when I checked.** A screenshot is slowed by contention; a frame-time
number is *destroyed* by it, and the load is exactly the signal you are trying to see past.

```bash
# 1. M1: the hinge's frame cost. Self-judging: per-cycle bracketed costs, warm-up cycle discarded, and a verdict
#    in metrics' vocabulary -- NOT USABLE -- <what> above <bound> in N of M samples (peak X).
#    DONE, twice, on an empty box, and it refuses its own number both times: the census confound (0.677 ms per
#    vehicle) is the size of the signal. Do not re-run this until combat's census-freeze tune exists -- a third
#    quiet run will spend a slot to print the same refusal. The tune is `--tune=match.no_damage=1` (combat,
#    guarded at `Tank.take_hit`, default off, REFUSED LOUDLY if mistyped). When it reaches main, add it to this
#    target's PERF_FLAGS and make the bench require it -- refuse to report when it is absent, rather than report
#    with a caveat, because the caveat is the part that gets dropped when the number is quoted.
REMOTE_SLOTS=6 make remote T="perf-trailer-ab PERF_CYCLES=6"

# 2. The merge candidate, taken in the same window rather than adding a check to a busy box.
REMOTE_SLOTS=6 make remote T=check

# 3. The round-8 re-measure, on the RESIZED roster. Same arms as the original or it is not a re-measure.
REMOTE_SLOTS=6 make remote T="faction-matrix ARENA=pit  SEEDS=5 TIME=150 BUDGET=5200 JOBS=8"
REMOTE_SLOTS=6 make remote T="faction-matrix ARENA=yard SEEDS=5 TIME=150 BUDGET=5200 JOBS=8"
```

**The arms for (3) are not invented — they are read out of the original run's own JSON**
(`_agents/streams/references/combat/faction-matrix-pit-rig14m-2026-09-19.json`, whose `args` block records
`budget 5200, seeds 5, jobs 8, time_limit 150, factions gangs,condemned,law,syndicate, no_faction_directives
false`, taken on **builder0 at `c042bb81`, dirty false**). `--seeds 5` is **5 × 2 bases × 2 colours = the twenty
counterbalanced matches** the 9/20 and 0/20 were counted from. **A re-measure whose arms differ from the original
is not a re-measure**, and this is the round where two streams already found that inertness and green-ness do not
compose.

**What the question actually is now, and it is not the round-8 question.** The 0/20 was the 14 m rig against a
**toy roster** — everything else was 2.8–5.0 m. After CP2 the whole roster grew, so the rig is no longer an
outlier in kind, only in degree. **Read matchups, not factions** (combat's own round-8 lesson: pooling hid this
completely on `pit`, where the gangs' rate was 30% in both arms while one matchup had become unwinnable).

### ⏹ WAITING (10:40) on two calls that are not mine. Everything else is done.

**Nothing of mine is running on either machine; tree clean; zero behind `main`.**

| waiting on | who | what happens then |
|---|---|---|
| **scale's `b3c36498` reaching `main`** (its check started 10:37) | orchestrator merges at the wrapper line | **Three reds clear at once**: my `test_theme_unit_scale` box-fill, scale's `test_units_scale` proportions, both the same artillery cause. I re-run both files — **run, not inferred**. The baseline moves once, `2d5215a8a0a59ded → 1e90f69e5d6fcc46`, recorded twice. |
| **the quiet window** (builder0 was load 20.89, six checks) | orchestrator calls it; I go first | The three runs in the block above: the hinge cost, the check on `a33638b8`, the 20/20 re-measure. |

**Owed to scale, accepted:** an eye on the Terminus floodlight frame before the lead sees it (they put **eight**
lamps inside the block grid at `dc28822f`, authored in `make_arenas.py` since `props` is generated). I judge it
**at his pose with the show OFF**, because the floor's baseline is mine and the 22-of-30 luminance question is a
property of the map rather than of the light show. **What I am watching for is not "too dim" but eight pools
reading as a regular lattice** — a salvaged city that lights its streets in a neat grid reads municipal rather
than improvised. If it does, the note back is **fewer-and-brighter with one or two dark corners**, not dimmer.

**Still owed and nobody is blocked on it:** the Terminus roof dressing (a frame before a triangle), and the
`ErrorCollector` warning/error conflation, which is metrics' now — until it lands, **no production path a test
exercises may `push_warning`**, and that sentence is going into `verification.md`.
ownership is `readlink /proc/<pid>/cwd`, and a slot's real holder is `fuser` on its `.lock`, never the `.owner`.
### X7 — the sweep said 0.0% everywhere, and that changed the design (builder0, `e82ecd1a`)

**Before — radius 118 m, altitude 74 m: `visible_pct 0.0` over 768 samples, at EVERY reachable tilt.** Not rare.
Never. The tool now prints why, which is one line of geometry: the frame's top edge sits at `FOV/2 - pitch` degrees
above the horizon.

| tilt | frame top | airship elevation | altitude that would have fitted |
|---|---|---|---|
| **21° (his)** | **−3.5°** — horizon off the top | 15.0–65.3° | **impossible at any altitude** |
| 8° | +9.5° | 17.7–68.9° | below 42 m |
| 12° | +5.5° | 16.9–67.8° | below 30 m |
| 17° | +0.5° | 15.9–66.5° | below 16 m |

**At his pose the sky is not on screen at all.** And at his lowest reachable tilt an airship over the arena would
have had to fly below 42 m — on a map whose city blocks are 40 m tall. That is not hovering, it is landing.

**After — radius 560 m, altitude 56 m (`CitySkyline.RADIUS` is 640 m, `RtsCamera` draws to 1200 m):**

| tilt | seen | widest on screen |
|---|---|---|
| 8° | **12.5%** | **105 px** |
| 12° | **12.5%** | **108 px** |
| 17° and above | 0.0% | — |
| **21° (his default)** | **0.0%** | — |

**Looked at, not just counted:** `build/airship-look/airship_widest.png` has it top-left, silhouetted against the
lit city, its ad screen showing the arena channel, half out of frame — which is the lead's phrase almost exactly.
The three frames were checked to have **three different md5s** before anything was read into them, because a stale
X cookie makes Godot fall back to Wayland and silently repeat the first capture (`remote_builds.md`), and for a
sweep whose whole output is frames that should differ, that failure is indistinguishable from a result.

**WHAT HE HAS TO RULE ON, and I am not pretending otherwise: he will not see it at his default 21°.** It is in
frame only when he tilts down to 8–12°, and it is over the **city**, not over the arena. That trades his literal
words for his own reference — Blade Runner's airship is over a city. **Both numbers are constants; overruling this
is one line.** The alternative, if he wants it over the arena, is that it becomes a presentation element (title,
results, replay) where the camera can look up.

### X5 — the void and the sky leak: both still fixed (`make shell-playtest`, builder0, merged tree)

**Zero leak lines and zero errors** through the whole shell — title → SKIRMISH → faction menu → planning → two
minutes of battle, driven by real clicks (`grep -icE 'leak|orphan'` = **0**, `grep -cE '^ERROR|SCRIPT ERROR'` = **0**
in `build/shell-playtest/run.log`). So the round-8 texture leak on the title → skirmish switch (the Environment
`Sky`'s radiance mips, fixed by the unshaded `NightSky` dome) has survived every merge since.

**And the void below the near wall is gone in the frames**, at the pose the readout itself confirms is his:
`CAMERA pitch 21° distance 72 m FOV 35° auto-frame ON`. The cutaway is active — the near stands are cut and their
crowd is drawn from behind — and the ground beneath them is continuous: structure and a lit strip, not a hole onto
the skybox. Checked at deployment (`3_battle_03s.png`) and mid-fight (`3_battle_75s.png`) on `pit`.

**The honest limit of this check:** `shell-playtest` shoots where the game puts the camera, which is inside the
arena looking across. The harshest near-wall case is control's per-edge `camera-looks`, which parks the camera
against each perimeter edge in turn; I did not run it, because it is a per-arena grid and the laptop is shared with
seven streams. The brief asked for *"one frame each at [his pose] and `make shell-playtest`'s console for leak
lines"*, and that is what this is.

### ⚠ OWED, and it is a venue defect of mine, not the light show's: the Terminus fails the luminance rule

**With NO light show at all — the branch-point look — the Terminus's block band is brighter than the fight ring in
22 of 30 frames at the lead's 21° pose over dark asphalt** (show's three-arm strip, 2026-09-20). The parapet default
then makes the ratio slightly *better* (−2.6% to +7.4%, mostly positive), **so the show is not the cause.** The rule
I gave show — *the fight is the brightest read* — is violated by the map itself, and it is a playability rule, not
a taste one: `art_direction.md` has always required the arena be *"lit well enough to read the fight"* on a phone.

**The levers are all mine:** the floodlight pools (`arena_dressing.gd` `_glow_multimesh`, `FLOODLIGHTS`), the floor's
albedo (`arena_ground*.gdshader`, and the Terminus is asphalt-dark), and the facades' base brightness
(`city_block.gdshader`, the storey `glow` and shopfront `glow` at channel identity).

**AND NOW SHOT, at his pose:** `build/terminus-luminance/terminus_pitch21_fov35_49m_default-camera.png`. The
brightest things in the frame are the **bands on the buildings** — a near-white cyan run along the left block and a
magenta one on the right — with the window grids behind them. **The vehicles are dark slabs**, legible mainly
because the selection rings around them are UI rather than lighting. Take the rings away and the fight is the
hardest thing in the frame to find. That is the 22-of-30 number as a picture.

**Incidentally confirmed by the same frame: the neon fix works in the real game.** Those bands read **cyan and
magenta** — the colours `terminus.json` asks for — where before `637ad4de` they were a random draw from the
signage palette (amber, warm white, red, violet). First visual confirmation, unplanned, from a frame shot for a
different question.

**And it sharpens my note to show:** the bands are correct in colour now and **still** the brightest thing on
screen, so it is the **placement** — a lit run at shopfront height on surface 1, facing the arena — that
out-competes the fight, not the palette. Dimming them is not the fix; lighting the floor is.

**DIAGNOSED 2026-09-20, and the mechanism is specific rather than "the map is dark".** Counted across every layout:

| arena | half | floodlights | blocks |
|---|---|---|---|
| pit | 140 | **4** | 0 |
| **terminus** | 140 | **2** | **8** |
| yard | 140 | 2 | 0 |
| boneyard, boulevard | 120 | 4 | 0 |
| foundry, furnace, scrapyard, maze, barriers | 120 | 0–0 | 0 |

**The Terminus is the only arena with `block` props, and it has HALF the floodlights of `pit` at the same size.**
Worse, the blocks are **inside the fighting area, not backdrop**: two sit at r = 40 m from the centre and four more
at r = 69, on a 140 m half-size — eight 40 m towers with lit window grids standing among the fight. Its two
floodlights are both at **r = 128**, out on the centre line at the far edges.

**So the venue got brighter and the floor did not.** The map adds a large lit facade area right where the player is
looking and lights the ground only from the perimeter. That is the whole of the 22-of-30 result.

**The fix belongs in the layout, and `arenas/` is scale's this round — so it is a request, not my edit.**
Recommendation: floodlights **among** the blocks (the street intersections between them), not more lamps on the
centre line at r = 128. **I deliberately did NOT reach for the lever in my own files** — making the dressing
compensate for a venue's own emissive would be a second hidden controller of arena brightness, which is exactly the
"two writers to one perceived quantity" hazard I warned show about on the ground wash. One owner: the layout.

Worth saying plainly for the lead: **this is a defect in the map he liked**, found only because show reported a
`--no-show` control arm beside its own numbers. A measurement that only reported the treated arm would have blamed
the light show.

### Owed at round close, not started: roof dressing on the Terminus (show's question, feel's geometry)

**Why it is a question now:** control's `RtsCamera.clear_pose()` lifts the camera over a roof rather than shortening
the boom (703 of 4328 poses were inside a building before, 0 after), so **roofs are on screen far more often on the
Terminus than when the blocks were built** — and a block's top cap is the least-dressed surface in the game. With
show's chamfers dark, the parapet run is a *roofline*; it is not roof *dressing*.

**My answer, recorded so it is not re-derived: yes it wants something, and a FRAME BEFORE A TRIANGLE.** Building on
the strength of "roofs are visible more often now" is round 7's failure exactly — ship, measure twice, discover the
mechanism was never reached. First one frame from `clear_pose()`'s lifted camera looking down on a Terminus roof,
then a decision. Then, in order:

1. **Surface treatment, zero draw calls, and it is the doc-correct answer rather than merely the cheap one.** The cap
   is already surface 0 and already tagged (`COLOR.r >= 0.75`), so tar-seam patching, water staining, grime pooling
   and a vent grid are all **texture in the existing shader**. `art_direction.md` calls the city salvaged and
   lived-in, which is a *surface* property at least as much as a silhouette one: a roof reading as tar and rust and
   standing water is more in-world than a roof with three boxes on it.
2. **Only if it still wants geometry: a MultiMesh scattered by the block seed** — vent housing, water tank, aerial
   mast — **one draw per prop type across every block and every tier**, the trick `ContainerYard` already uses.
   Never per-block meshes.

**A cost nobody had priced:** `CityBlock.build()` caps **every tier**, not just the top (`city_block.gd:109-112`), so
a tiered block is three or four horizontal surfaces. Whatever the treatment is, it is paid for several times a block
— which argues harder for (1) going first.

### Decided overnight (the lead asleep; orchestrator's standing instruction, 2026-09-20)

1. **The corner in `make rig-hinge` is shot at the rig's own minimum turn radius (12 m), not a wide one.** A wide
   corner is physically correct and visually nothing — `asin(L/R)` at 26 m is 11° and the frame showed a bend he
   would have had to be *told* was there. Most reversible option available: one catalog-read constant, overridable
   with `--rig-hinge-radius=`.
2. **The jackknife strip is shot from 60°, not his 21°**, and is labelled a diagnostic. At his pitch a hard fold
   puts the trailer broadside between camera and cab and the frame becomes a tanker with no truck in it. The
   *judgement* frames stay at his pose.
3. **`--no-trailer` exists as an A/B switch** so the hinge's frame cost is measured in one tree rather than across
   two checkouts on two days (round 5 lost hours to exactly that). Shape copied from nav's `--nav-off=`.
4. **The airship's two navigation lights are steady, not strobing**, and `show` has been told: the Syndicate is the
   faction that does not flicker, and a strobing airship would undo the one piece of art direction the lead named
   ("pristine, no rust"). A programme that wants the airship puts the cue on its screens.
5. **`CyberMaterials.neon()` gained an optional `fixture` tag** rather than granting `show` a carve-out for one line
   in my file. Sharing stays the default, so the perimeter is still one material and one draw call.

### X7 — the airship, and the question it has to answer before it is finished (`567a8007`)

Built from primitives (ellipsoid envelope, tail cone, four fins, gondola, engine pods, two navigation lights, a
screen a side), Syndicate ivory, **no collision body of any kind** (asserted by a test over five collision classes),
drift from `Match.tick` and never the wall clock (asserted: one lap returns it to the same place, and every sampled
tick is on the orbit at its altitude with the nose on the tangent), **absent on LOW** like the crowd. The screens
join the existing `arena` `AdBroadcast` channel and share its material, so the eleventh screen in the arena costs
one quad and no second 2D feed — and the airship replays the player's last kill because `LiveFeed` already does.

**What is NOT yet established, and the reason the orbit's two constants are provisional: whether the lead can ever
see it.** *"Sometimes visible in the field of view"* is precisely the class of claim that turns out false — round 8
shipped a camera fix for the HUD hiding his own selection and a facing feature that could not fire on his control
scheme at all. So `make airship-look` sweeps **every camera yaw a player can rotate to** against **the whole orbit**
at his pose, projects the airship's bounds and reports the fraction of that grid where any of it is on screen.
Too low and he never sees it; 100% and it is wallpaper. **The frames come after the number**, and `ORBIT_RADIUS`
and `ORBIT_ALTITUDE` get set by what they say. Queued.

### ⚠ The 12° correction (control, 2026-09-20) — it invalidates a line in this brief

This brief, `legibility.md`'s first draft and my X5 item all said *"the lead's 12° and 35° poses"*. **That is wrong
twice.** 12° is the camera he played and **rejected** — *"I was totally wrong about the camera, the game is
unplayable now with low field of view"* — and "35°" in that phrase is an **FOV**, not a second pitch. **His pose is
one pose: pitch 21°, FOV 35°, 49 m, auto-frame on.** Fixed in `legibility.md` §6 and in `make rig-hinge`, whose
second frame is 45° and is labelled in the source as a detail view, never as his. **X5 is shot at 21°/FOV 35/49 m,
plus a low pose to hunt the void — the low pose is a diagnostic, not a judgement.**

### X1 + X2 — the rig bends at the fifth wheel (`4a8c1843`, 10 tests, laptop)

**The cut is not a plane, and that is the finding.** The tanker's front cap overhangs the tractor's drive tandem, so
no single box separates them: a plane at the fifth wheel takes the drive wheels with the trailer, and a plane aft of
them leaves 1.8 world metres of barrel rigid on the tractor. The cut is a **union of boxes** — everything aft of the
tandem's rear wheels, plus the barrel *above* those wheels — so `FactionArt.split_mesh` grew a `split_mesh_boxes`
beside it and the old single-box call is a wrapper. `GUN_CUTS` is untouched.

**The jackknife limit is measured, not chosen.** A test voxelises everything forward of the tanker's cap (cab,
stacks, hood, plow, fuel tank), swings the trailer a degree at a time and reports the last clean angle: **90°** —
because the trailer's overhang ahead of the pivot is only 0.25 model m, so it very nearly pivots in place. **The
limit is therefore not geometry-bound**, and 65° is a physical choice (the brief's 65–70°) with 25° of proved
clearance. What the test deliberately does *not* guard: the cut faces at the fifth wheel are coincident, because the
rig is one mesh and the chassis rails run through the cut, so a few centimetres of rail overlap at any angle —
invisible under the barrel and between the wheels, the same accepted cost as the collider (S2).

**The hinge** reads the **drawn** pose and the **frame's** delta (the sim is 30 Hz with interpolation on), snaps to
zero on a teleport so a respawn cannot draw a streak from the wreck, and derives its wheelbase in world metres from
the model's world scale — **so it survives CP2 without an edit**. The gun rides the trailer: its pivot is reparented
under the trailer's and the turret's lay is taken back out, so gunnery is unaffected.

### X2 — the hinge measured in a real match and on a known corner (`72a06181`, laptop, Intel UHD 620)

**In a live skirmish** (`--player=cpu:gang_ram --player-faction=gangs --budget=6500`, `foundry`, seed 3; **32 rigs,
1,440 rig-frames**, sampled per rig per frame, not as a maximum over the field):

| | |
|---|---|
| mean articulation | **6.1°** |
| peak | 65.0° (one rig, at the clamp) |
| rig-frames past 30° | **4.9%** |
| rig-frames at the 65° clamp | **1.2%** |

That is the answer to metrics' warning (*"56% of all reversals in a fight are the wheeled creep, so the trailer will
jackknife often"*). **It does jackknife, and metrics was right to warn**: one rig in 32 reaches the clamp within six
seconds and 4.9% of rig-frames are past 30°. But the fleet **lives near straight** — a mean of 6° — so it reads as
the occasional truck folding out of a reverse, not as a fleet of broken vehicles. **The first version of this
measurement reported only the maximum over all 32 rigs, which one vehicle pins and which cannot tell "the fleet is
folded in half" from "one rig is reversing out of a corner".** Fixed before it was reported.

**On a known corner** — **the rig's own minimum turn radius, 12 m** (read from `min_turn_radius_m`, so it follows the
roster through CP2), 9 m/s, trailer wheelbase 5.06 world m. Degrees of articulation by degrees through the turn:
`0 → −7.7 → −14.7 → −19.1 → −21.5 → −22.7`. The closed form for steady-state off-tracking is
`asin(L / R) = asin(5.06 / 12) =` **24.9°**, and it settles at **22.7°** — the deficit is the approach transient.
**The law is right end to end, not just in the unit test.**

*(The first corner was shot at 26 m, which is physically correct and visually nothing: `asin(L/R)` there is 11° and
the frame showed a bend the lead would have had to be TOLD was there. 12 m is not a staged number — it is the worst
bend the game will ever draw under power.)*

**Reversing** (the creep case, from the corner's end pose with the kink still in it, so the divergence has something
to grow from — reversing from a dead-straight hinge is an unstable equilibrium and a frame shot that way would have
been a lie): `−47.3°` at 4 m, **clamped at −65° by 9 m** and held. It diverges, which is what jackknifing is.

**Owed on X2:** `build/rig-hinge/` frames for the lead, `make remote T=sim-baseline` on the branch
(pre-registered: the hash does not move), and `make perf-scene` before/after with a gangs army (M1).

### X8 — the asset pipeline had its own copy of the roster (scale's finding; Invariant 0)

`assets/pipeline/asset_contracts.gd` `UNITS` carried its own `hull_size` and `muzzle_height` for five units, with no
test tying it to `Units.PROFILES`, and **it had already drifted**: the tank 1.6 m tall there against 2.4 m in the
catalog, the IFV 1.6 against 3.0, artillery 1.6 against 2.8, the Lancer 1.6 against 2.2 — only the scout agreed.
Inert for gameplay, and **exactly the thing that would have normalised every model generated after CP2 to the old
toy sizes, silently.** `UNITS` is now an id list; the numbers come from the catalog on every call, and
`STANDARD_HULL` (the turret-scale reference) with them. **The mutation check is free and real: every one of those
heights was 1.6 in the old table, so the old table fails the new test as written.**

### S6 (show) — where the lighting hook belongs in my materials, recorded before the agent starts

The orchestrator granted `show` additive carve-outs in `CityBlock`'s emission, `arena_dressing.gd`'s perimeter rim,
`NeonSigns`, the floodlight pools and `CyberMaterials.neon()`. Asked for an opinion on a per-instance custom-data
slot versus a material uniform: **both, and they are not interchangeable.**

- **Per-instance custom data on the MultiMesh** for anything that differs *between instances* — individual windows
  breathing, block edges pulsing out of phase. It is how the crowd is already driven, it costs no draw call and no
  light, and a uniform cannot express it at all. A `show` that reaches for a uniform here ends up adding a second
  MultiMesh to get the variation back, which breaks its own zero-draw-call rule.
- **A material uniform** for anything *global* — the rim's colour and level, a pool's intensity, the arena wash. One
  write a frame.
- **The rule:** differs between instances → custom data; one number for the whole fixture → uniform; never add a
  MultiMesh or a light to get variation a custom-data channel could have carried.

**And the constraint `show` must know before it designs:** `AdBroadcast`'s ad channel **already** drives the ground
wash from each ad's average colour, so an arena-wide light cue is a *second writer to the same perceived quantity*.
Those need one owner or they will fight, and the fight will read as flicker neither stream can reproduce. Also: the
instance-uniform ceiling is real and `make perf-scene` already counts *"Too many instances using shader instance
variables"* as a first-class number — read that counter, not only the frame time.

### Two traps that cost me time today, both worth a lesson

**1. A non-simulating `Tank` is a REPLICA, and setting its transform does nothing.** With `simulate=false` the tank
eases its own position and yaw toward `sync_position` / `sync_yaw` every rendered frame (`tank.gd:456-465`). Set the
transform alone and it is undone inside the frame — so my hinge, which integrates the *drawn* motion, integrated a
drift toward the origin and reported **0.0° at every milestone of a corner that visibly happened**. The law had unit
tests and every one of them passed; what was broken was everything between the law and the tank. `facing_audit.gd`
already hit this with `sync_turret_yaw` and says so in a comment — **which I read, and did not generalise.** There is
now an end-to-end test that drives a rig round a real corner in a real node tree, because that is the only kind of
test that could have caught it.

**2. Killing a `make` leaves `tools/slot.sh` holding a machine-wide slot, and the stale `.owner` file makes a dead
holder look alive in every other agent's log.** I started a second `make lint` while my first was still running (the
in-checkout flock correctly refused it), then killed the wrong process in the chain: the `make` died, its `slot.sh`
wrapper lived, and it held one of the laptop's two slots — with nothing running inside it — until I noticed. Every
other stream's queue was behind it. **Kill the `slot.sh` wrapper, not the `make` inside it**, then check
`/tmp/tank_squad_slots/` and remove a stale `slot<N>.owner` by hand: the lock releases with the process but the
owner file does not, so the banner every waiter prints keeps naming a job that ended. Reported to the orchestrator
for `_agents/remote_builds.md`, which is not mine. *(And the better habit, which builder0's idle 12 cores make
obvious: `make remote T=...` rather than queueing locally behind six other agents.)*

### X6 — established first, and the premise is wrong: both targets are ALREADY differential

The brief and orchestration **lesson 65** say `announcer-record-smoke` and `music-smoke` answer a differential
question against the shared baseline file. **Read the recipes: they do not, and have not since round 6.** Both run a
**control match in the same invocation** (`expected=$(... no --music=on / no --announcer-record ...)`) and compare
`actual` against `expected`; the baseline file is never opened. `mk/audio.mk:31-34` and `mk/announcer.mk:115-118`
carry the round-6 comment explaining the fix. The only residue is a dead `key="control"` assignment in both recipes.

**So X6 was not a build job — and both experiments are now RUN, on the laptop, 2026-09-20.** Reading the recipe said
they were already differential; a guard nobody has seen fail is not known to work (Invariant 0), so both halves were
proved:

| experiment | prediction | result |
|---|---|---|
| **1a** stale `glibc-2.39 deadbeef…` line added for this machine → `make sim-baseline` | **red** (the file is live here) | `sim-baseline FAILED: expected deadbeefdeadbeef for glibc-2.39, got 5dbb0689ddffc1c0`, **exit 2** ✓ |
| **1b** same stale file → `make music-smoke` | **green** (never opens it) | `music-smoke passed: … hash 41e00136e74693d2 (matches the same match without the music)`, **exit 0** ✓ |
| **1c** same stale file → `make announcer-record-smoke` | **green** (same) | `announcer-record-smoke passed: hash 41e00136e74693d2 (matches the same match without the booth)`, **exit 0** ✓ |
| **2** instrumented run's seed skewed to 4 so the hashes must differ → `make music-smoke` | **red**, naming the subsystem | `music-smoke FAILED: the soundtrack changed the simulation (7c9c59aaefc5c30e, without it 41e00136e74693d2)`, **exit 2** ✓ |

**Four predictions, four confirmations.** Both targets are differential, neither consults the baseline file, and the
comparison is live rather than merely silent. Both files were restored by the script and `git status` confirms it.

**Landed:** the dead `key="control"` is gone from both recipes, and both now carry the experiment beside them, so the
next agent reads the proof rather than the two-round-old claim. **Owed to the orchestrator: lesson 65 is wrong and is
their file.** *(The round's real lesson: a lesson describing a defect fixed two rounds ago sends a stream to rebuild
it — this brief budgeted X6 as a build item and it was a reading item plus four matches.)*

**One incidental finding:** the brief says `sim-baseline` "silently skips" on the laptop. It skips only because there
is **no line for `glibc-2.39`**; add one and it runs and compares normally (it produced `5dbb0689ddffc1c0` here). The
laptop can self-check against itself, it simply has no recorded value — worth knowing before anyone concludes the
target cannot run off builder0.

### X3 — the A6 contract (S4): written, feel signed, nav reviewed

`_agents/legibility.md` at **`4ec341d2`**. nav asked for one decision and got it.

**feel confirms nav's level 3** (above formation, below the weapon band). A6 does not outrank the standoff band:
its own falsifier bars trading exchange ratio for a tidy line; for the 3 hull-fixed units a law above the band would
point the gun mount down the corridor and stop them shooting; and for turreted hulls the conflict is nearly empty,
since level 2 constrains the *radial* component and leaves the tangential free.

**The one change asked of A7's table — and the reason the page is worth more than a one-line brief: the falsifier is
measured on VELOCITY, not on heading.** A6-a (the nose clause) cannot move P7 on its own, because a turreted hull's
nose is already free of its gun and its velocity is chosen at levels 1, 2 and 5. So A6 also claims what level 3's
null space currently gives away — *the sign of the arc*: when both shoulders serve the band equally, take the one
that advances along the corridor. Level 3's remaining null space is speed alone. Circling is untouched; the
*shoulder* is claimed. One cell in nav's table, and the difference between A6 mattering and A6 being cosmetic.

Also settled in the page: the corridor is N1's `path_points` current leg with exactly one publisher; composition
with the arc/armour task written per style (`strafe` 10 units, `angle` 8, `standoff` 3, `run` exempt as an A/B
control); an inactive law must not read as a broken one (lesson 149), so active ticks are flagged with a reason and
the falsifier is computed over them with the active fraction reported beside it; Invariant 0c answered as
*"replaces nothing"* and then argued rather than asserted.

### The rig, measured (X1's input; `9f864474`, laptop, `make assets-profile`)

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
