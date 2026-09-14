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

### 2026-09-12: Why flanking works (armor facing)
- **One line:** Tanks have thick front armor and thin sides and back; a hit in the side does twice the damage of a hit in the front, and the rear three times.
- **Why it matters:** It turns "who shoots faster" into "who gets a better angle", which is the start of tactics.
- **Show it:** `make run BOTS=1`. Let the bot drive at you and count shots to kill it head-on (6). Then get beside it (3), or behind (2). Read `game/combat/armor.gd`: the whole rule is about 10 lines.

### 2026-09-12: A test that passes for the wrong reason
- **One line:** A "no friendly fire" test passed, but only because shells were missing *every* tank, friend or enemy.
- **Why it matters:** Green tests aren't proof. Break the code on purpose and check the test goes red.
- **Show it:** In `tank.tscn`, shrink the Collision box height back to 1.0 and run `make test FILTER=combat`. Watch which tests fail, and which *keep passing* when they shouldn't.

### 2026-09-12: Commanders vs pilots
- **One line:** Claude plays through standing orders ("drive there, shoot whatever you see") because it thinks in seconds, not milliseconds.
- **Why it matters:** It's the whole squad-game idea in miniature: you don't steer, you decide what your units should do and when. Claude lost 4–2 to a dumb bot mostly because it couldn't say "and retreat if you get hurt."
- **Show it:** `make server BOTS=1`, open the browser client, and ask Claude to join with `make agent-client`. Play against it, and afterwards ask each other what order you wished you could have given.

### 2026-09-13: Is the game fair? Don't guess, measure
- **One line:** The map is a perfect mirror, yet the south team won 64% of 140 robot-vs-robot games. Swapping who starts where proved it was the *spot*, not the team.
- **Why it matters:** It's the scientific method on a game: a control experiment (swap the bases) separates "this strategy is better" from "this map is broken". Every future "is strategy A better?" question depends on it.
- **Show it:** `make matches N=40 JOBS=6 GREEN=2 RUST=2` (about a minute). Then ask: if Green wins 28 of 40, is that luck? Flip a coin 40 times together and see how far from 20 it wanders. Then read the table in `squad_ai_design.md` "Fairness".

### 2026-09-13: Running away can be the worst move
- **One line:** Retreating by turning around shows the enemy your weakest armor, so backing up slowly while facing them can be safer.
- **Why it matters:** Rules create tactics nobody designed on purpose. The designer's job is to notice them, which is what playtests are for.
- **Show it:** `make run`, let the bot damage you, then try both escapes: turn and drive (fast), or hold S to reverse (slow). Which one survives more often?

### 2026-09-13: "Weights in a tree": how a tank decides
- **One line:** Ten times a second each tank gives every possible action a score, like "attack Rust_2: 0.62, take cover: 0.31, retreat: 0.0", and does the highest one. The player's directives change the weights.
- **Why it matters:** It's how most game AI worked long before LLMs: simple math that is predictable, tunable, and explainable. "Why did it retreat?" has an exact answer.
- **Show it:** `make watch-match` and read the nameplates. Then open `doctrines/anvil_hammer.json`, change the Hammer squad's `"flanking"` to 0.0, and watch again. Do they still swing wide?

### 2026-09-13: Formations are just arithmetic relative to the leader
- **One line:** A wedge is "leader here; wingman 12 m back-left; the other 12 m back-right", recomputed every moment as the leader moves and turns. Pick a new leader and the whole shape re-centers on it.
- **Why it matters:** Big behaviors from tiny data: a formation is a list of offsets, and a drill is a few weight changes. The player gets lots of power from one drag, because the math does the rest.
- **Show it:** `make skirmish`. Select Alpha (1), press X (wedge) then V (line), and watch them re-form. Click a wingman twice to make it commander and watch the shape re-center. Open `game/ai/formations.gd`: each formation is one line.

### 2026-09-14: Why can't every phone just run the game? (determinism)
- **One line:** If everyone simulates from the same commands, they must get *exactly* the same answer, down to the last bit. A computer's `sin()` isn't the same on every device, so we rebuilt the tank math with whole numbers (1.0 m = 65536) and got identical results in a desktop app and a browser.
- **Why it matters:** It decides the whole multiplayer design: identical math means no server has to run the game and cheaters are caught by comparing fingerprints (hashes).
- **Show it:** `make det-spike` prints the same 16-character hash twice (native and browser) and `FLOAT_PROBE trig: DIFFERENT`. Open `game/network/detcore/fixed.gd`: sine is computed with shifts and adds (CORDIC), no `sin()`.

### 2026-09-14: A phone in a tunnel (reconnects without losing anything)
- **One line:** Every message gets a number. When the connection comes back, each side says "the last one I got was #812" and the other resends what's missing, so a 10-second dead zone doesn't break the match.
- **Why it matters:** Mobile players lose signal all the time. The game has to treat that as normal, not as "you left".
- **Show it:** `make relay-drop-smoke` cuts a player's connection for 10 s and prints "resumed after 10.1 s away (same peer id)". Then `make relay-rejoin-smoke`: gone longer than the grace period, the player comes back and gets their tank back where they left it.
