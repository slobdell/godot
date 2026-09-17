# Stream: audio (guns that sound dangerous)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *The arena announcer* including the humor direction, and *Matches are between different
> factions*), [../workstreams.md](../workstreams.md) (L5 is yours; lead gate 1 approves sound-effect generation) and
> your round-4 report [archive/round4/audio.md](archive/round4/audio.md). You own `game/announcer/`, `game/audio/`,
> `assets/{announcer,audio,music}/`, `tools/{announcer,audio}/`, `mk/{announcer,audio}.mk`, `tests/announcer/`.

## The lead's direction (2026-09-17)

> *"The sound effects for the guns and stuff are currently lame."*

Round 4 got the mix right (layered takes, a World bus with a limiter, distance filtering) but the *source material* is
still synthesised from noise and pulses in code. ElevenLabs sound-effect generation is approved and there are
**125,297 credits**. Cinematic exaggeration, not documentary realism.

## Where things stand

- **Announcer: done and shipped.** 589 lines, 2,372 whole-sentence recordings, variance gated in `check`, the booth
  live in matches, subtitles through the HUD (control is giving them their own line this round).
- **A bug the lead heard:** a caller line said *"Green and Rust, live, right now!"* — colour names, when
  game_design.md says sides are named by **faction** and matches are always cross-faction. Some lines still leak
  colours.
- **Music:** the director, states, beat-aligned crossfades and stingers all work on placeholder beds; the lead will
  write the real tracks in Suno from `assets/music/PROMPTS.md`.
- **Sound effects:** synthesised placeholders; the lead's verdict twice now is that they're the weakest part.

## Backlog (in order)

**X1. Guns, for real.** Generate sound effects with ElevenLabs and layer them under the existing transients: the tank
cannon (a crack you feel, a body, a long tail with stand echo), the 25 mm burst (a mechanical thump per round), the
machine-gun stream (a saw, not a click track), the laser, the mortar, the flamethrower. **Pilot a handful first,
listen, and put a sample in front of the lead before the batch** (round 4's lesson: for subjective quality a human is
the only check that counts). Variation pools so nothing repeats, distance filtering, and the existing mix and limiter.

**X2. Impacts and death.** Armour hits, shield hits, weak-spot hits, kills, cook-offs, wrecks burning: the moment a
shell lands should be the loudest thing in the mix, then fall away.

**X3. Colour names out of the booth.** Audit every line for colour references and faction correctness (the rule:
sides are named by faction, matches are always cross-faction). Fix the text, re-record only what must change, and add
the check to the line audit so it can't come back. Report the credits spent.

**X4. The world underneath.** Engines by load and speed, treads and tires on different ground, the crowd swelling with
the match mood, the arena PA between rounds, ad screens audible near them. Cheap at 60 vehicles: pool, cull by
distance, and cap voices; measure against render's frame budget (M1) since audio shares the CPU.

**X5. Music stems** (round 4's stretch, the lead's own next choice): split beds into layers that build with intensity
rather than swapping tracks, so the soundtrack follows the fight rather than stepping between states. `MusicDirector`
changes rather than gains a feature; keep the beat-aligned transitions.

**X6. Listen to it whole.** A recorded pass over a full 30-a-side match: guns, impacts, engines, crowd, booth and
music together, mixed so the announcer sits above the battle and nothing clips. Give the lead exact commands and a
short description of what he'll hear.

- **Stretch:** per-faction announcer flavour; ad copy read by the PA between rounds; a mute-everything-but-guns mode
  for tuning.

## How to verify

`make remote T=check` (the sim baseline never moves for audio), the announcer's Python tests and variance gate,
**listening** to each pilot and the full pass (say what you hear in Status), the credit ledger, and file sizes.

## Don't touch

When effects fire (render owns the visual side, combat owns the events), gameplay, arena layouts, UI layout (control
owns where subtitles appear).

## Status

- 2026-09-17: brief written for round 5. Nothing started.
