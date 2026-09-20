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

- **X3 — `_agents/legibility.md`: DONE. SIGNED by feel, nav and control (2026-09-20). A6 motion code is unblocked.**
- **X1 — the trailer cut: DONE** (`4a8c1843`), 10 tests, every number measured off the mesh.
- **X2 — the hinge: code and tests DONE** (`4a8c1843`); **the lead's frames are owed** (`make rig-hinge`).
- **X8 — the pipeline's private copy of the roster (scale's finding, Invariant 0): DONE**, mutation-checked.
- **X6 — the two smoke targets: ESTABLISHED, and the premise is wrong.** Both are ALREADY differential; see below.
- **X5 — the lead's poses.** Next, and the brief's camera is wrong: see *The 12° correction*.
- **X4 — the every-unit box-fill test.** Blocked on CP2 by design.
- **X7 — the airship: BUILT** (`567a8007`); its orbit numbers are provisional until `make airship-look` says
  whether the lead can ever actually see it.

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

### ⏸ PAUSED 03:20 (orchestrator: the lead's session limit). WHERE I AM, AND THE EXACT NEXT STEP

**Nothing is mid-flight and nothing is uncommitted.** The local batch was still queued behind another stream's
`make check` when I stopped it, so no work was lost: I killed the `slot.sh` wrapper (not the `make` inside it),
verified no `slot<N>.owner` and no wait-ticket of mine remains in `/tmp/tank_squad_slots/`, and the working tree is
clean. Branch tip: see the last commit below.

**`7a706911` is MERGED TO MAIN** — X1, X2's code, X3 and X8 are shipped. **The tip is ELEVEN commits past it and
is covered by no check**: the file-existence guard, `--no-trailer`, the airship and `airship-look`, the `spectacle`
weight table, the airship's tier fix, the `ArenaDressing` test fix, and Status commits.

**THE EXACT NEXT STEP, in order, when RESUME arrives:**

1. **Only after the orchestrator says builder0 is up**, and after checking builder0 for an orphaned `slot.sh` of
   mine from the run that died at 03:15: `REMOTE_SLOTS=6 make remote T=check` on the tip. That is the one thing
   standing between eleven commits and a merge.
2. **Recover the stranded artefacts** — a plain
   `rsync -az builder0:~/tank_squad/godot-feel/build/ build/` brings back `7a706911`'s run output. **No re-run is
   needed**; only the copy failed. Until then **no number may be cited from local `build/`**, except
   `build/rig-hinge/`, which was made locally and which I verified the failed rsync never touched.
3. **The local batch, re-queued as one sequential slot** (all four are laptop-only; none can go to builder0
   usefully while the queue there is the bottleneck):
   `make perf-scene PERF_NAME=perf-gangs-off PERF_FLAGS="--player-faction=gangs --enemy-faction=gangs --no-trailer"`,
   then the same with `PERF_NAME=perf-gangs-on` and no `--no-trailer` (**M1: the hinge's frame cost, A/B in one
   tree**), then `make airship-look`, then `make shell-playtest` (**X5's leak lines**).
4. **`make airship-look`: check the frames DIFFER before reading anything into them.** A stale X cookie makes Godot
   fall back to Wayland, which stops redrawing a hidden window, so every capture after the first silently repeats
   the first (`remote_builds.md`, and the comment at `tools/remote.sh:62`). For a sweep whose entire output is
   frames that are *supposed* to differ, that failure is indistinguishable from a result.
5. **X6's two experiments** — the script is written and ready at
   `<scratchpad>/x6.sh`: stale the baseline for this machine's glibc and confirm `sim-baseline` goes red while both
   smokes stay green (they do not consult the file), then skew the instrumented run's seed and confirm `music-smoke`
   goes red (the comparison is live). Then delete the dead `key="control"` in both recipes and correct **lesson 65**,
   which is the orchestrator's file.
6. **X4** stays blocked on CP2 by design.

**The open question I expect to answer with (3) and (4), and which is a design question for the lead rather than a
bug:** at his pose the top of the frame sits at `pitch - FOV/2` = 21 - 17.5 = **3.5° BELOW the horizon**, so nothing
in the sky can be drawn there at any altitude or distance. If the sweep confirms it, *"sometimes visible in the
field of view"* is **false at his camera and true only at the bottom of his tilt range** (he can reach 8°), and the
airship's `ORBIT_RADIUS` / `ORBIT_ALTITUDE` are provisional until he rules.

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
