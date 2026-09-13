# Godot for Programmers

Godot concepts mapped to things an experienced programmer already knows, plus
the facts this repo relies on. Examples point at real files here.

## Concept map

| Godot | Think of it as | In this repo |
|---|---|---|
| **Node** | An object in a tree with lifecycle callbacks. Everything in a running game is a node. | `Tank`, `PlayerController`, `FollowCamera` |
| **Scene** (`.tscn`) | A saved subtree of nodes: a composable prefab or class. Scenes instance other scenes. | `tank.tscn` is instanced inside `main.tscn` |
| **Script** (`.gd`) | Attaches behavior to *one* node. `extends CharacterBody3D` means "this node *is* a CharacterBody3D, plus my code". | `tank.gd` |
| `class_name Foo` | Registers a global type name, usable in type hints and `Foo.new()` | `class_name TankCommand` |
| **Resource** (`.tres`, meshes, materials) | Serializable, shareable, reference-counted data objects | The `BoxMesh`/`StandardMaterial3D` sub-resources inside `tank.tscn` |
| `RefCounted` | A plain object freed when unreferenced (nodes are *not* ref-counted, so you `free()`/`queue_free()` them) | `TankCommand`, `TankMotion` |
| **Signal** | The observer pattern, built in. `signal died`, `died.emit()`, `tank.died.connect(fn)` | `Tank.fired` / `Tank.died` → `Match`; `Shell.hit` → `Match` |
| Collision layers / masks | A body *is on* layers and *scans* masks (bitfields). Ray queries take a mask | world = layer 1, tanks = layer 2; shells scan 1+2; line of sight scans 1 |
| Ray query | `get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, exclude))` → `{}` or `{position, collider, …}`. Use during physics processing | `Shell`, `Perception` |
| `Label3D` | Text in 3D space; `billboard` faces the camera | tank nameplates |
| `Logger` | (4.5+) Subclass and `OS.add_logger()` to receive every engine error | `tests/run_tests.gd` fails tests on errors |
| **Autoload** | A singleton node that lives above the current scene | None yet. M2 kept networking in `main.gd` because it only needs one scene; a menu/lobby scene would justify an autoload |
| **Groups** | Tags on nodes: `add_to_group("tanks")`, `get_tree().get_nodes_in_group("tanks")` | None yet |
| `@export var` | A field that shows up in the editor Inspector and is saved into the scene | `max_forward_speed` in `tank.gd` |
| `@onready var x = $Child` | Assigned right before `_ready()`, once children exist. `$Child` is shorthand for `get_node("Child")` | `turret` in `tank.gd` |
| `_ready()` | Constructor-ish: runs once when the node and its children enter the tree | `main.gd` wires modes here |
| `_process(delta)` | Per *rendered frame*, variable rate. Use for visuals. | `FollowCamera` |
| `_physics_process(delta)` | Per *physics tick*, fixed 60 Hz by default. Use for simulation. | `Tank`, controllers |
| **SceneTree** | The main loop, which owns the root and the frame/physics signals | `tests/run_tests.gd` *is* a SceneTree script |
| `res://` / `user://` | Project-relative read-only path / per-user writable data dir | `res://game/main.tscn` |
| Feature tags | Build-time flags: `OS.has_feature("web")`, `"server"`, `"debug"` | `main.gd` (web), export preset (`server`) |
| **Project Settings** | `project.godot`: global config, input map, main scene | renderer, input actions |
| `MultiplayerPeer` | The transport (sockets). Assign one to `multiplayer.multiplayer_peer` and the high-level API works over it | `WebSocketMultiplayerPeer` in `main.gd` |
| Peer id | Every connection gets an int; **1 is always the server** | `Tank_<peer_id>` names |
| `@rpc(...)` | Marks a method as remotely callable: `method.rpc_id(peer, args…)`. Options pick who may call it (`"authority"`/`"any_peer"`) and delivery (`"reliable"`/`"unreliable_ordered"`) | `NetworkInput.submit_command` |
| Multiplayer authority | Which peer "owns" a node (default: server). `is_multiplayer_authority()` | all tanks: server |
| `MultiplayerSpawner` | Replicates node creation/removal from the authority to everyone | `Main/TankSpawner` |
| `MultiplayerSynchronizer` | Replicates chosen properties on an interval (a `SceneReplicationConfig`) | `Tank/StateSync` |

## Physics bodies: which one?

| Body | Moves by | Use when |
|---|---|---|
| `StaticBody3D` | never (or scripted) | ground, walls, crates |
| `CharacterBody3D` | **your code** sets `velocity`, then `move_and_slide()` handles collisions | player/AI units with game-y, predictable movement: **our tanks** |
| `RigidBody3D` | the physics engine (forces, impulses) | debris, bouncing shells (maybe M3) |
| `VehicleBody3D` | simulated wheels/suspension | realistic driving (not a goal; hard to network and to AI-drive) |

## Coordinates (memorize this)

- **Y is up. Forward is −Z.** `-global_basis.z` is "the way this node faces".
- **Positive `rotation.y` rotates counter-clockwise seen from above, which turns LEFT.** To face a target on the right (+X) you need yaw −90°.
- Units are meters by convention. Our tank is about 2.4 × 3.6 m.

## GDScript tips for people coming from Python/TypeScript

- Indentation-based like Python; **tabs** by convention in Godot projects.
- Use static typing: `var speed := 0.0` infers `float`; `func f(x: int) -> void:`. You get faster code, editor autocomplete, and errors at parse time.
- `Variant` is the dynamic "any" type. Untyped `var` is Variant.
- `await some_signal` suspends a function (a coroutine). `await get_tree().physics_frame` waits one tick, which the tests use.
- `move_toward`, `rotate_toward`, `lerp`, `clampf`, `angle_difference` are global math helpers.
- No `null`-safety operator; check `if node == null` / `is_instance_valid(node)`.

## Scene files are text, which matters for AI agents

`.tscn` is a readable INI-like format (see `game/tank/tank.tscn`): `[ext_resource]`
(other files), `[sub_resource]` (embedded meshes/materials), then `[node]`
entries with `parent=` paths. That means Claude can author scenes directly and
diffs are reviewable. Guidelines:
- **Small, structural scenes by hand are fine** (all scenes in this repo were written by hand, then loaded and tested).
- **Visual layout work** (placing 40 props, tuning a UI) is faster in the editor. Let the editor save, and commit its output.
- The editor may add `uid="uid://…"` to headers and resources when it re-saves. That's expected; commit it.
- Don't hand-edit `.godot/` (cache) or invent `uid://` values.

## The editor tour (what to click first)

1. `make editor` → FileSystem dock (bottom-left) → double-click `game/main.tscn`.
2. Scene dock (top-left) shows the node tree. Click `Tank` → Inspector (right) shows `@export` values; change `max_forward_speed`, then press F5 to play.
3. Click the scroll icon next to a node to open its script.
4. Project → Project Settings → Input Map shows the actions `PlayerController` reads.
5. Remote tab in the Scene dock while the game is running: inspect the *live* tree, which is great for debugging.
