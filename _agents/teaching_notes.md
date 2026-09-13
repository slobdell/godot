# Teaching Notes

A running log for the project lead, who is learning Godot one step ahead of
their son. Each entry is a concept that was confusing, surprising, or satisfying
the first time, written so it can be re-explained to a beginner. **Append;
don't rewrite history.** Agents: add an entry when a session hits one of these
moments.

Format: **Concept**, then the one-line version, why it matters, and a way to
*show* it (something to click or change and watch).

---

### 2026-09-12: Scenes are Lego, scripts are behavior
- **One line:** A scene is a reusable bundle of nodes; a script gives one node behavior. The tank is a scene; the arena is a scene; `main.tscn` just snaps them together.
- **Why it matters:** This is *the* Godot idea. Beginners often put everything in one giant scene and script.
- **Show it:** Open `main.tscn` in the editor, select the `Tank` node, press Ctrl+D to duplicate it, and drag the copy a few meters away. Press F5: there are two tanks, but only one moves. Ask why; that leads into the next note.

### 2026-09-12: Separate "deciding" from "doing"
- **One line:** The tank doesn't read the keyboard. A controller decides and hands the tank a `TankCommand`; the tank does.
- **Why it matters:** The same tank can then be driven by a person, a demo script, the network, or an AI, without rewriting the tank. Every later feature depends on it.
- **Show it:** `make run` (you drive) vs `make demo` (a script drives). Same tank scene, one different node.

### 2026-09-12: `_process` vs `_physics_process`
- **One line:** `_process` runs every drawn frame (fast, uneven); `_physics_process` runs at a steady 60 per second. Movement and game rules go in physics.
- **Show it:** Add `print(delta)` in both and watch the numbers.

### 2026-09-12: Forward is −Z and "left" is positive rotation
- **One line:** In Godot 3D, Y is up, a node faces −Z, and increasing `rotation.y` turns it left.
- **Why it matters:** It's the #1 source of "my tank drives backwards / turns the wrong way" bugs.
- **Show it:** In the editor, select the tank, drag the Rotation Y value in the Inspector, and watch which way it turns.

### 2026-09-12: Tests for a game?
- **One line:** You can test games like any code: pure math directly, and scenes by running real physics for a second and checking where things ended up (`tests/test_tank_drive.gd`).
- **Why it matters:** When Claude writes game code, tests and screenshots are how it (and you) know it works without playing it every time.

### 2026-09-12: The server is the referee
- **One line:** In online games, players' computers only *ask* ("I'm pressing forward"); the server decides what actually happens and tells everyone.
- **Why it matters:** Otherwise anyone could edit their game to say "I have infinite health". It also explains lag: you see what the server said a moment ago.
- **Show it:** `make server`, open two browser tabs at `localhost:8060/?connect`. Drive in one tab and watch the tank move in the other. Then stop the server (Ctrl+C) and both tabs freeze: the server was running the game all along.

### 2026-09-12: Two ways to talk over the network
- **One line:** An **RPC** is "call this function on that computer" (our input). A **synchronizer** is "keep this variable the same everywhere" (tank positions).
- **Why it matters:** Choosing between "send an event" and "sync a value" is the core networking design decision.
- **Show it:** In `tank.tscn`, select `StateSync` and open the Replication panel at the bottom of the editor: three synced properties. Then read `submit_command` in `network_input.gd`, which is just a function with `@rpc` on it.

### 2026-09-12: Same tanks, different players, where's the skill?
- **One line:** Chess pieces are identical too. Skill is making better decisions: what to bring, how units work together, reading the opponent, and timing.
- **Why it matters:** It's the central design question of the squad game (see `squad_ai_design.md`), and a great conversation to have about any game he likes: "what do good players do that bad players don't?"
- **Show it:** Play a round of Gladiabots or any auto-battler together and ask, after each loss, what decision lost it.
