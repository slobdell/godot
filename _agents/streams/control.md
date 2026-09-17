# Stream: control (the shell has to work)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *Controlling units*), [../workstreams.md](../workstreams.md) (M3 you share with render; you own
> K1 and L4) and your round-4 report [archive/round4/control.md](archive/round4/control.md). You own `game/control/`,
> `game/ui/` (including `hud.tscn`, the widgets and the title screen), `game/camera/`, `game/controllers/`,
> `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`.

## The lead's direction (2026-09-17)

> *"Right now the game is also unplayable with the camera, it ends up focusing on the enemy instead of our own friendly
> units. The startup screen seems stuck, I can't actually click any of the first buttons, and when I do manage to start
> the game there's a bunch of red error messages in the console log."*

Round 4 built the vision-framed camera, element focus and tasks, and every test passed. The lead still couldn't play
it. **Your first job is the gap between "the tests pass" and "a person can use it."**

## Where things stand

- The camera frames the *commanded element*; with nothing commanded, or when an element dissolves, it evidently ends up
  on the wrong thing. Reproduce it the way the lead hit it: `make skirmish`, don't give an order, watch what it frames.
- The title screen is `game/ui/` and `game/modes/title_mode.gd`. A headless `--title` run prints `TITLE_START offline`
  straight away, which suggests something starts or swallows input without a click.
- Console noise at 30 a side is largely the renderer's per-instance uniform limit (render's X2), but **triage all of
  it**: your job is a clean console for a player, and to hand anything that isn't yours to the stream that owns it.
- Announcer subtitles go through `Hud.post_message` and crowd the four-line log (audio's evidence:
  three of four visible lines were the announcer on desktop, and a kill message was buried on phone).

## Backlog (in order)

**X1. Play it, then fix what stops you.** Before writing code: run `make skirmish`, play a full match, and write down
in Status exactly where it stops being usable (with screenshots). Then fix, in whatever order the playthrough dictates:
- **The camera frames your force.** With no element commanded, frame the player's units; never centre on the enemy
  unless the player asked. An element dissolving hands focus back to your army, not to whatever was on screen.
- **The title screen accepts clicks** and starts what the button says; nothing starts a match on its own.
- **A clean console:** triage every error in a normal session, fix yours, and file the rest with evidence to the owning
  stream (render for shader and material errors, combat for simulation, audio for the booth).
Then play it again and say whether it's playable now.

**X2. Subtitles get their own line.** The booth speaks on its own band (a caption line or panel), so gameplay messages
(kills, losses, orders, control point) keep the message log. Readable at the default zoom and at 1280×720.

**X3. The lead's three dials** (from round 4, none blocking): how close the default frame sits, one alert line or
three, and whether the faction menu opens by default. Pick sensible defaults, make each one a flag or setting, and say
in Status what you chose and why.

**X4. Readability at 30 a side (M3, with render).** Selection marks, nameplates, health bars and order markers must
stay legible when 60 vehicles are on screen and render has toned the vehicle glows down. Their accent and your
selection colour must not be confusable. Screenshots at 30 a side, before and after.

**X5. Orders that survive a big army.** With 30+ units and several elements: selection, group switching and task
issuing stay inside the latency budget you measured in round 4 (box-select 1.38 ms, 30 orders 1.87 ms), and the element
bar stays readable. Add the optional `facing` to `UnitCommand` that doctrine asked for (their halt-formation hack goes
away).

**X6. The first two minutes.** A new player opens the game and gets: a title screen that works, a match that starts,
controls they can discover (a short on-screen hint set that doesn't nag), and a camera that never loses their army.
Write what a first-time player sees, in order, in Status.

- **Stretch:** the cinematic camera as a spectate mode from the title screen; a replay of the last match.

## How to verify

`make remote T=check`; your control tests with real input events; **a played match**, with screenshots you looked at
and a written verdict on playability; a clean console log attached to Status (`build/skirmish-console.log` or similar).

## Don't touch

Vehicle art and effects (render), arena layouts (arena), weapons and rules (combat), brains (ai), the booth's content
(audio: you own where its subtitles appear, not what it says).

## Status

- 2026-09-17: brief written for round 5. Nothing started.
