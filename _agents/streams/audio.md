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

_Updated 2026-09-17 by the audio worker._

### Plan (in order)
1. **X1 guns:** pilot generation tool, layering/mastering tool, SfxSystem wiring, A/B page → **lead gate** → batch.
2. **X3 colour names:** audit rule first (fails on today's library), fix the text, re-record only changed lines.
3. **X2 impacts and death:** recipes are written and ride the same batch as X1 (one gate, not two).
4. **X5 music stems** (no dependency), **X4 the world underneath** (voice caps and culling measured against M1),
   **X6 the full pass**, then the stretch items.

### Waiting on the lead
1. **The gun pilot** (lead gate 1): <https://claude.ai/artifact/E1hxqREgGsPMB74oUPkC4N>. A scripted ten-second firefight,
   before and after, and each pilot sound raw and as it ships. Reply: run the batch / run it with changes / not yet.

### Done so far
- **X1 pilot (5281440).** `make sfx-generate` (dry run by default; `APPROVED=1 PILOT=1`) turns
  `assets/audio/elevenlabs/sources.json` into git-ignored MP3 masters, and `make sfx-layer` turns those into the takes
  that ship (`assets/audio/layered/`, manifest `game/theme/audio/sfx_layers.gd`). `SfxSystem` plays layered takes where
  they exist; `--sfx-synth` gives the old set back for A/B. Pilot: tank cannon, 25 mm round, MG stream, shell on armour,
  10 takes, **230 credits** (about 10 credits per generated second; the balance updates minutes late, so the ledger
  now waits for it).
- **What "listening" meant here, honestly:** I can't hear. I read spectra, envelopes and levels, and the lead's ears
  are the check that counts (the gate). What the numbers showed and what I changed because of them: the generated
  cannons put **97% of their energy under 200 Hz**, which laptop and phone speakers don't play, so the layer step
  saturates that band into 150–1500 Hz harmonics. Matching loudness unweighted made the new cannon quieter on a small
  speaker than the old one, so loudness is measured above 120 Hz. The raw boom fell 30 dB in 0.4 s, so the tail is
  lifted by up to 14 dB. Raw 25 mm takes differed by 30 dB and are levelled. The MG recording is a real ~13 rounds a
  second, not a click track.
- **A loop bug that was probably half the "lame" (5281440).** Every looped sound set `loop_end = data.size() / 2`,
  which counts frames only for PCM, but the WAVs imported QOA-compressed: the machine gun, flamethrower, engines and
  crowd each repeated **their first fifth** (0.2 s of a 1 s MG loop). Loops now import as PCM. The engine and crowd code
  is render's and needed no change. There's a test, and it was mutation-checked (it fails with `compress/mode=2`).

### Requests to other streams
- **render:** keep `assets/audio/{mg_loop,flame_loop,engine_*,crowd_murmur}.wav` importing as PCM
  (`compress/mode=0`); `SfxSystem.loop_frames(stream)` is the safe way to set a loop end if you touch that code.
- **orchestrator:** back up `assets/audio/elevenlabs/masters/` (paid sources, git-ignored).

### Merge notes (shared files)
- None yet.
