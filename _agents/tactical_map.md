# Tactical Map: Few Inputs, Deep Control

> **Status: v1 implemented (2026-09-13); v2 (2026-09-15, stream/gameplay): RTS 3D camera, radar, fog of
> war, touch-first controls. See "v2" at the end.** Play it: `make skirmish` (desktop) or `make serve-web` → `http://localhost:8060/?skirmish` (browser, no server). Builds on
> [tank_brain.md](tank_brain.md) (autonomous brains + directives) and answers its
> "Squad command UI" open question.

## The lead's brief

> "I want the tactical map. The challenge here is really a UX standpoint, where I want
> to essentially give the player a lot of hidden control and power without an
> overwhelming set of inputs. There's also a simple concept where a tank is elected as
> a commander, and from there it would be easy to control the squad to take an action
> relative to the command (i.e. … Army-standard tank formations and battle drills); if
> we elected a tank the commander then things like V formations could be formed up
> relative to the commander."

## UX principle: three kinds of input, everything else is implied

| Input | Gesture (mouse / keys; touch later) | Answers |
|---|---|---|
| **Who** | Click a tank (selects its squad) or press `1` / `2` / `3`. Click a tank in the already-selected squad to **make it commander** | Which squad, and who leads it |
| **Where / which way** | **Right-drag** on the map: press = destination, drag direction = facing on arrival (a short drag faces the direction of travel). A ghost of the formation follows the cursor | The spot and the orientation |
| **How** | One **drill** chip (`Q` Move · `W` Bound · `E` Hold · `R` Assault · `T` Break contact) and one **formation** chip (`Z` Column · `X` Wedge · `C` Vee · `V` Line · `B` Echelon · `N` Coil) | The battle drill and the shape |

A complete order is at most **one click + one drag + one chip**. The "hidden power" is
everything that gesture expands into, none of which the player touches:

```
Right-drag with "Bound" + "Wedge" selected
  → SquadCommand {squad, verb: bound, to, facing, formation: wedge}   (structured data, validated)
    → Squad: elects/keeps a commander, splits the squad into two elements, runs the bound cycle
      → per-tank DIRECTIVE MODIFIERS + formation SLOT targets
        → autonomous TankBrains still score options (a hurt tank still retreats, a tank
          in contact still fights) inside the drill's weights
          → orders → TankCommand
```

The same `SquadCommand` data can come from the map, a CPU commander, the agent
bridge (Claude commanding squads), or later an LLM or a network client.

## The commander

- Every squad has one **commander**. Formations are laid out **relative to the commander's position and heading**, so moving the commander moves the formation.
- **Election:** the player clicks a tank in the selected squad. By default, the first tank in the squad's roster leads.
- **Succession:** when the commander is destroyed, the next surviving tank in the roster takes command immediately, and an event appears ("Alpha: commander down, Green_Alpha_2 takes command"). The formation re-forms around the new leader. **Decapitation becomes a tactic**: a disrupted squad loses cohesion for a moment.
- The commander paces the squad: it slows down while followers are far out of their slots.

## Formations (after US Army tank platoon doctrine)

Roughly following the formations taught for tank platoons (ATP 3-20.15), adapted
to 2–5 tanks per squad. Offsets are in the commander's frame (right, back), in
units of `spacing` (default 12 m):

| Formation | Shape | Use it for | Trade-off |
|---|---|---|---|
| **Column** | single file behind the leader | moving fast through a lane between obstacles | only the leader can shoot forward; flanks exposed |
| **Wedge** (Λ) | leader at the point, others staggered back left and right | movement to contact; the default | good all-round firepower and control |
| **Vee** (V) | leader at the base, the others forward on both flanks | pushing into a known threat with firepower forward | leader protected; the flanks take contact first |
| **Line** | abreast of the leader | maximum firepower forward; assaults | weak flanks, hard to control, no depth |
| **Echelon** (right or left) | a diagonal behind the leader to one side | protecting one flank (e.g. along a wall) | the other flank is blind |
| **Coil** | a ring facing outward around the destination | halting; all-round security | no movement |

## Drills (after battle drills and movement techniques)

| Drill | What the squad does | Contact behavior |
|---|---|---|
| **Move** (traveling) | all tanks move together in formation toward the destination | return fire while moving; formation is kept unless a tank is hurt |
| **Bound** (bounding overwatch) | two elements leapfrog: one halts and covers (overwatch) while the other moves up ~25 m, then they swap | the overwatch element engages anything in sight; the bounding element keeps moving |
| **Hold** | halt in formation at the destination, facing the drag direction | engage from position; leashed to slots |
| **Assault** | drive at the destination; formation loosens into individual fights | aggression up; brains hunt |
| **Break contact** | withdraw toward the destination (default: own base), backing away with the front armor toward the threat | fire while withdrawing |

## Fog of war on the map

The map shows your tanks exactly, but enemies only as your team's **intel**:
visible contacts solid, remembered ones fading with age. The shared vision that
makes scouting matter to the brains is also what the player sees.

## Architecture

| Piece | File | Notes |
|---|---|---|
| Formation geometry (pure) | `game/ai/formations.gd` | slot offsets, heading rotation, world slots; unit tested |
| Squad runtime + commands | `game/ai/squad.gd` | roster, commander, succession, drill state (bound cycle), `SquadCommand` validation |
| Brain integration | `game/ai/tank_brain.gd` | new option `KEEP_SLOT`; drill → directive modifiers; the commander's pacing |
| Map UI | `game/ui/tactical_map.gd` | overlay `Control` drawn over a top-down camera; emits SquadCommands |
| Skirmish mode | `--skirmish` / `?skirmish` / `make skirmish` | single player commands Green squads vs a CPU doctrine; works in the browser with no server |

## Verification plan

- Unit: formation shapes and rotation; election and succession; command validation; the bound cycle.
- Integration (real physics): a wedge ordered 60 m forward arrives with tanks near their slots; hold halts and faces; break contact withdraws in reverse.
- UI logic without rendering: synthetic mouse and key events into `TacticalMap` produce the expected SquadCommands.
- Visual: screenshots of the skirmish map (selection, ghost formation, fog-of-war contacts).

## v1 as built (2026-09-13)

- **Skirmish mode** (`--skirmish`, `?skirmish`, `make skirmish ENEMY=individuals|anvil_hammer|flame_rush`): you command Green's squads from `doctrines/player_default.json` (Alpha: 3 cannons in a wedge; Bravo: 2 in a line, both holding) against a CPU doctrine. First to 10 kills; VICTORY/DEFEAT banner.
- **Map drawing:** friendly tanks as circles with hull ticks; the commander marked by a gold diamond; the selected squad ringed, with each tank's brain intent under it; destination line, ghost slots, arrival-facing arrow; a live gold ghost formation while right-dragging; enemies only from team intel (solid = in sight, hollow and fading = remembered). 3D enemy tanks outside your team's sight are hidden, and 3D nameplates are hidden on the map.
- **Panels:** the drill and formation bar (clickable, lit when active, keyboard shortcuts on the labels); a squad readout (`*` = commander, health per tank); a hint line; an event log (orders, bounds, "commander down, X takes command").
- **Tab** switches to a 3D view behind the selected squad's commander and back.

### Verified

- 10 squad tests: formation geometry, validation, election/succession, move-in-wedge arrival, hold facing, break contact in reverse, bounding overwatch leapfrogging 54 m.
- 5 map tests driving `_gui_input` / `_unhandled_key_input` with synthetic events: screen↔world mapping, squad keys, formation keys (incl. echelon flip), a right-drag producing destination + facing + pending drill, click-twice election, E = hold here.
- Screenshots of a scripted skirmish (bound + echelon orders, a live drag preview, commander succession in the log) and of the browser build at `?skirmish`.

### Known gaps / next

- **Multiplayer squad command:** today skirmish is single-player; a networked client would send SquadCommands to the server (same data, validated there).
- **Claude as the opposing commander:** give the agent bridge a `/squad` endpoint; the enemy becomes a thinking commander instead of a static doctrine.
- **Touch/phone:** tap = select, long-press-drag = where, bottom chips = how (the input model already maps 1:1).
- Formation slots don't yet avoid obstacles (a wedge along a wall clamps to the arena edge; slots inside crates rely on navmesh closest-point).
- Pending drill is global, not per squad.

## Iteration 2 (2026-09-13): the lead's first skirmish

> "the game is a little bit unplayable at the moment. First off, tanks should not re-spawn,
> this should be a squad vs squad match. Second, it should not be easy for our tanks to die…
> I haven't been able to successfully use the commander and formations feature (maybe because
> the tanks die too quickly)"

**Diagnosis with measurements** (5v5 CPU matches, first-kill and first-shot timing):

| Change | First shot | First kill | Why |
|---|---|---|---|
| Before (small map, 100 HP, 110 m guns, respawns) | **0 s** | 14 s | Bases were 84 m apart with a clear sightline: both teams fired from spawn. There was no maneuver phase at all, so formations had no time to matter |
| 400 HP, 70 m cannon, 75 m sensors | 1 s | 29 s | Tougher, but still immediate contact: both sides close 84 m in a second |
| **Arena doubled** (240 m, bases 180 m apart) + the above | **7–8 s** | **~32 s** | A real approach phase; a fight takes ~25 s to claim a tank |

**What changed:**
- **Squad vs squad elimination** in skirmish (`Match.elimination`): no respawns; the last team standing wins (VICTORY/DEFEAT). Time-limited elimination matches are decided by tanks alive, then total health. The runner has `--elimination`; the network server and `make run` keep respawns.
- **Tougher tanks and slower killing:** 400 HP (was 100), cannon reload 2.5 s (was 2.0), cannon range 70 m (was 110), sensor 75 m (was 90), and **shot spread** 0.8° σ that grows ×2.5 at full speed, so halting to shoot (Hold, overwatch) is rewarded. The spread RNG is seeded, so matches stay deterministic.
- **Arena doubled** to 240×240 m with 4.5 m crates, 18 m walls, and three extra mirrored cover pairs; all size constants now live in `Match` (`ARENA_HALF_SIZE`, `DRIVABLE_LIMIT`, `BASE_Z`).
- **Tactical pause:** skirmish starts in a PLANNING pause; **Space** pauses and resumes anytime. Orders work while paused; the map processes with `PROCESS_MODE_ALWAYS`.
- **Hurt tanks stop yo-yoing:** a tank below its retreat threshold no longer advances blindly (without repairs, it bounced between base and enemy forever and matches stalemated).
- **Input discoverability:** **left-drag on open ground** also orders (right-drag still works; a left press on a tank selects; a plain left click on the ground does nothing). A **toast** confirms every order ("Alpha: Bound in Wedge") or explains a rejection.

**Were clicks broken?** A new test drives the map through Godot's real input pipeline
(`Viewport.push_input`). It first "failed", but only because **headless Godot's root
viewport is 64×64**, so the pushed clicks landed off-map. In a real window the same click
reaches the map. With a 1280×720 test viewport, keys, clicks, commander election, drags,
and pausing all pass end to end. Conclusion: the lead's trouble was the pace and
discoverability, not dropped input.


## v2 (2026-09-15): 3D camera, radar, fog, touch

| Input | Mouse / keys | Touch |
|---|---|---|
| Who | click a tank (again: commander), 1–3, squad chips | tap a tank (again: commander), squad chips |
| Where | left- or right-drag on the ground (press = spot, drag = facing), radar drag | tap ground (go), hold 0.35 s then drag (go + face), radar drag |
| How | Q–T drills, Z–N formations, or the buttons | buttons (drills; Formation opens the formation row) |
| Camera | arrows / screen edge / middle-drag pan, wheel zoom, `,` `.` rotate, F follow, Tab overview, radar tap | drag pan, pinch zoom, twist rotate, radar tap, Follow / Overview buttons (tap the selected squad's chip to follow) |
| Time | Space | Pause / Resume button |

- The camera is `RtsCamera` (a controller for the main camera); the map works in perspective because every
  interaction is a ground raycast. Without a rig (tests) the old flat top-down view remains.
- Fog of war: `VisibilityField` (team vision grid) drawn in 3D by the `fx.fog_of_war` slot and on the radar;
  enemies are drawn only from intel. Nameplates never show brain intents in skirmish.
- The radar (`Radar`) is an input too: tap = look there, drag = order.
