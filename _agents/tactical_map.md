# Tactical Map: Few Inputs, Deep Control

> **Status: v1 implemented (2026-09-13).** Play it: `make skirmish` (desktop) or `make serve-web` → `http://localhost:8060/?skirmish` (browser, no server). Builds on
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
