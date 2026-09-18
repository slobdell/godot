# Stream: feel (the arena is a place, and it is full of people)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *The arena*), [../workstreams.md](../workstreams.md) (you own **M1**, **M3**, **K4**, **K5**,
> **L5**, **C6**), [../art_direction.md](../art_direction.md), [../slot_contracts.md](../slot_contracts.md), and
> round 5's reports in [archive/round5/](archive/round5/) — `render.md` and `audio.md` are both yours now, and their
> saved baselines are in [references/](references/) (`fx_tricks.md`, `perf/`).
>
> **You own** `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**),
> `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and the art paths, `tools/{assets,announcer,
> audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters,
> `_agents/{art_direction,slot_contracts}.md`.
>
> **Round 5's render and audio streams fold into you.** The frame-rate fight is won — the lead did not mention it once
> this round — so the remaining presentation job is whether the arena feels like a place worth fighting in.

## The lead's direction (2026-09-18, verbatim)

> *"On the look and feel side, I notice that the background / ambient crowd in the stands is non-existent."*

> *"the lower camera angles look good because we actually get to see the vehicles"* (control owns the camera; you own
> what it finds when it gets down there)

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**Start here, because it changes the whole brief: the crowd already exists, and it shipped four days ago.**

- `game/theme/fx/crowd_system.gd` — one MultiMesh of billboard quads, one draw call, `PER_TIER = {LOW 900, MEDIUM
  1800, HIGH 4000}`, seats generated from the stands' rows (0.85 m spacing, 0.85 occupancy), reacting to
  `FxWorld.spectacle` (kills roar, hits ripple), with 6% of fans in team neon. Shader
  `game/theme/fx/shaders/crowd.gdshader`, atlas `game/theme/cyberpunk/crowd/crowd_atlas.png`.
- `game/theme/cyberpunk/arena_dressing.gd` — grandstand modules (`kit_stands`, ~23 m each, roof 15.7 m) tiled along
  the **north and south** walls, 5 seat rows per module, gates east and west, floodlight towers at ±112, ad screens,
  neon signs, container barricades. `HALF = 121`.
- `game/theme/audio/crowd_voice.gd` (round 5) — looping `crowd_murmur` plus `crowd_cheer` roars on the bed bus,
  `MURMUR_DB -30 → -14`, `ROAR_DB -9`, floor driven by `MatchMood` intensity. The WAVs exist.
- It landed 2026-09-14 (`74ab6fff`, *"the gladiator venue with a cheering crowd"*).

So **the code path is not the missing piece, and "build a crowd" is the wrong first move.** Something is stopping the
lead from seeing or hearing any of it, and finding out what is X1. The standing hypotheses, in order of suspicion:
the stands sit outside ±121 m and the camera's default vision framing never includes them; the fog (`density 0.0012`
plus height fog, flat near-black background, no skybox) eats them at that distance; the crowd tier is LOW on his
machine; the murmur is 30 dB down under gunfire; or trip-up 74 bit again (a QOA-compressed loop repeating its first
fifth). **Do not guess — instrument it, then look.**

The environment is `game/theme/cyberpunk/arena_environment.tscn`: no skybox texture, flat near-black background
(`#030307`), ambient from sky colour, ACES tonemap, glow, depth fog `0.0012`, height fog, one `Moon` directional light
(energy 1.7, shadow max 110 m).

## Backlog (in order)

**X1 — find out why the lead sees no crowd, before changing anything.** Take screenshots at the camera poses a player
actually gets (including the low angles control is moving toward), with the crowd soloed and the fog off, and *look at
them*. Report what you find as a diagnosis with an image: "the stands are behind 40 m of fog at the default frame" is
a finding; "added more crowd" is not. Same for the audio: record a real match with the `crowd` solo layer and listen
(lesson: round 5's music played once and went silent while every unit test passed — it was only caught by recording a
real match).

**X2 — make the crowd read from the player's camera.** Whatever X1 finds: the stands and their people must be visible
and alive from the angles the lead plays at. Likely work — bringing the stands closer or raking them higher, fog and
tone-mapping that doesn't swallow them, a crowd density that survives the LOW tier, brighter/larger figures at
distance, movement that reads at 50–200 m (a shimmer of motion beats individually animated people). Hold the budget:
**a locked 30 fps at 1080p with 30 a side** (M1), and the crowd is one draw call today — keep it that way.

**X3 — make the crowd react, audibly.** The murmur bed under everything, swelling with `MatchMood`, a real roar on a
kill or a last stand, and a drop into tension during a lull. It exists; make it audible under gunfire without fighting
the announcer. ElevenLabs credits are available for better crowd beds under the standing gate: **approve the text,
pilot cheaply, listen, then batch** (lesson 19 — the announcer shipped a version that passed every automated check and
was obviously wrong to the first human who heard it).

**X4 — the arena as a place.** With the camera coming down to 25–50°, the eye now lands on the horizon, not the floor:
the stands, the gates, the towers, the screens, the sky. Check what that reveals — the flat near-black background may
need a real skyline or a skybox now, props may need silhouettes that read from low down, and the ad screens (live
match content during the fight, ads between — the lead's ruling) should be legible from a playing angle. Work with
control: their `make camera-looks` page is the same screenshots you need.

**X5 — the loading screen's voice.** control builds the loading mechanism and its progress; you give it something
worth looking at — faction art, the matchup, the arena, and an announcer sting or crowd bed under it. Coordinate; do
not build the screen yourself.

**X6 — keep the frame.** You inherit M1. Anything added this round is measured with `make perf-scene` / `make
audio-bench`, and the numbers carry their commit and machine. `make perf-scene` runs with `--mute`, so its frame
numbers contain no audio at all (trip-up 76).

**X7 (stretch) — the Syndicate's weapons still sound cartoonish** (the lead, round 5, specific to the energy/laser
family and not the pipeline — he called the same batch "awesome" on the Condemned). "Laser" is the most cliché prompt
in sound design and reaches straight for the 1950s ray-gun: prompt for the physical event instead — a capacitor bank
discharging, an arc flash, a transformer failing — and avoid pitch sweeps entirely.

**X8 (stretch) — impacts and payoff cues.** Once combat's shorter engagement ranges land, flanking pays off in rear
and side hits: a weak-spot hit should *sound and look* like a reward. combat provides the event; you make it land.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make perf-scene`, `make fx-bench`, `make audio-bench`, `make vehicle-gallery`, `make announcer-demo`,
  `make web-smoke` (the web build must still boot and stay lean).
- **Look at the screenshots and listen to the recordings.** For anything subjective a human is the only check that
  counts (lesson 19) — put cheap samples in front of the lead through the orchestrator before any expensive run.
- You **must not** move the sim baseline (invariant 2). Art and sound never change the simulation.
- Remote screenshots can silently repeat one frame on builder0 (trip-up 65): if captures look identical, check the log
  for `Invalid MIT-MAGIC-COOKIE`.

## Don't touch

`game/ai/**` (nav's and squad's), `game/control/` `game/ui/` `game/camera/` (control's — including the loading screen
itself), `game/units/` `game/combat/` `game/match/` (combat's), `arenas/` `game/arena/` (arena's — you dress what they
place, you do not place).

## Waiting on the lead

1. **Crowd bed audio text**, if X3 needs new ElevenLabs material: approve the text, then a cheap pilot before any
   batch. Route it through the orchestrator the day it is ready.
2. **No new Meshy models** (88 credits left). Placing and re-dressing existing art is free and expected.

## Status

_The worker keeps this current._
