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

### If you are picking audio up, read this section and the two after it
They are the whole job: **never skip the whole-match pass** (below, with the engine gotcha), **how to hear and measure
each part** (the command for every layer), and **the spare music** (what exists and what it might suit). Everything
else here is the record of round 5. `assets/music/PROMPTS.md` is the lead's own brief for generating more music, and
`assets/audio/elevenlabs/sources.json` is every sound-effect recipe with the prompt that made it.

**Where the backlog stands:** X1 and X2 are built end to end and **waiting on the lead** for the batch (the pilot page
is below). X3 is done. X4 is done except the parts that have nothing to key on yet. X5 is done. X6's tooling is done;
the pass itself waits for the batch, so the lead hears the real mix. Stretch: solo mode done. Per-faction flavour and
the PA reading ad copy are written up under *Next steps*.

### Plan (in order)
1. **X1 guns:** pilot generation tool, layering/mastering tool, SfxSystem wiring, A/B page → **lead gate** → batch.
2. **X3 colour names:** audit rule first (fails on today's library), fix the text, re-record only changed lines.
3. **X2 impacts and death:** recipes are written and ride the same batch as X1 (one gate, not two); the mix side
   (impacts duck the fight) needs no new sound.
4. **X5 music stems** (no dependency), **X4 the world underneath** (voice caps and culling measured against M1),
   **X6 the full pass**, then the stretch items.

### ElevenLabs spend this round (balance 125,297 at the start)

| Run | Credits | Balance after |
|---|---|---|
| X1 pilot: cannon, 25 mm, MG stream, shell on armour (10 takes) | 230 | 124,733 |
| X3: colour names out of four lines (30 clips) | 1,899 | 122,834 |
| Arena CP2: the four new map names (72 clips) | 8,758 | 114,076 |
| X1+X2 batch: every other gun and impact (35 takes) | 518 | 113,558 |
| PA lines between matches (12 clips) | 1,523 | 112,035 |
| Re-rolls of four failed sound generations | 61 | 111,974 |
| **Total** | **12,989** | **111,974** |

The balance reads unsettled for minutes after a run; `assets/{audio/elevenlabs,announcer}/ledger.md` note where it
moved later.

### Waiting on the lead
**Answered 2026-09-17:** "Run the batch", "All of them work" (the ad copy), "Record them" (the PA lines), and screens
"live during, ads between". All three runs are done (below).

0. **The whole-match listen**, now with his music: <https://claude.ai/artifact/1tgMvTnnNHpvxczSi9KDpm>. A real match on
   the Boulevard recorded off the game (battle excerpt, opening, the full 90 s) plus the before/after firefight, and
   three questions: do the guns sound dangerous; does the announcer sit above the battle (the spectrogram says his
   line sits inside it, so that's flagged); does the music follow the fight and stay under it. Tuning is levels only.
1. ~~**The gun pilot** (lead gate 1)~~: <https://claude.ai/artifact/E1hxqREgGsPMB74oUPkC4N>. A scripted ten-second firefight,
   before and after, and each pilot sound raw and as it ships. Reply: run the batch / run it with changes / not yet.
2. **Ad copy for the screens and the PA between matches** (draft, text only):
   `assets/announcer/drafts/ad_copy.md`. Twelve screen ads in the existing brand world (AquaCorp, Syndicate Life,
   Meridian, Harbor General, Vireo, Northgrid, ...) and twelve PA lines, each ordinary advertising with one detail
   slightly off. Asked: which read as jokes, and whether screens carry ads or live match content. Recording the PA
   lines is about 1,500 credits.

### Done so far
- **X1 pilot (5281440, f696544).** `make sfx-generate` (dry run by default; `APPROVED=1 PILOT=1`) turns
  `assets/audio/elevenlabs/sources.json` into git-ignored MP3 masters, and `make sfx-layer` turns those into the takes
  that ship (`assets/audio/layered/`, manifest `game/theme/audio/sfx_layers.gd`). `SfxSystem` plays layered takes where
  they exist; `--sfx-synth` gives the old set back for A/B. Pilot: tank cannon, 25 mm round, MG stream, shell on armour,
  10 takes, **230 credits** (about 10 credits per generated second; the balance updates minutes late, so the ledger
  now waits for it). The batch (X1's other guns plus all of X2's impacts, 35 takes) is **about 520 credits** and waits
  on the lead.
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
- **X3 colour names (db15512).** Only one spoken line named colours (`caller.intro.07`, "Green and Rust, live"), but
  nothing stopped the next one. The line audit now fails a capitalised colour or a colour team, any `{team}` slot (its
  Green/Rust vocabulary is deleted too, so nothing could fill one), a literal faction named **as a side** without its
  faction tag (tags are requirements, so an untagged Wreckers line could play in a Law-Syndicate match; the Syndicate
  and the Law as institutions stay legal), and "{faction} are ... its". The new rules found three more lines:
  `caller.kill.48` and `caller.ff.07` ("are down to its"), and `pa.sponsor.14` (tonight's Condemned crews, in any
  match). Four lines rewritten, **30 clips re-recorded, speech-to-text flagged none, 1,899 credits**. Balance 122,834.
- **X5 music stems (0bc1db3).** A manifest track can be stems: `{file, from}` (comes in at that intensity) or
  `{file, states}`. They play sample-locked in one `AudioStreamSynchronized`, layers change on bar lines with a 1.2 s
  fade, and a layer holds through a 0.08 dip so a pause between kills doesn't strip the arrangement. One placeholder
  `fight` track (pad, pulse, bass, drums, and a siren that only plays in a last stand) replaces the four in-match beds,
  so lull → skirmish → battle never crossfades or reloads. In a real headless match: pad only at 0 s, the pulse at first
  contact (10.2 s), the full band in the battle (18.7 s). `make music-import IN=<Suno stems folder> STATE=fight
  LAYERS="Synth=0 Drums=0.35 ..."` imports stems with one shared gain; `music-check` checks they line up, the full
  arrangement's loudness and peak, and that the always-on layers aren't silence. `PROMPTS.md` tells the lead how.
- **X4 the world underneath (f696544, 7b9d467, and the voice-priority commit).**
  - `make audio-bench`: `perf-scene` runs `--mute`, so **its numbers include no audio at all**. The bench times each
    audio system headless under a battle busier than a real one (60 vehicles, 16 machine gunners, a shot every frame,
    a busy booth, the music following the mood). It caught a real cost: **an Ogg one-shot cost 0.29 ms per frame
    against 0.045 for a WAV** (a Vorbis decoder built per shot), so layered takes ship as WAV/QOA.
  - Engines (`EngineSystem` moved to `game/theme/audio/` with render's agreement): **speed and load**, so a tank pulling
    away roars before it is fast, plus a running-gear voice per engine (tracks under diesel hulls, tyres under the
    rest) pitched with speed and silent at rest. Nearest vehicles by insertion rather than a lambda sort: 0.17 ms at
    60 vehicles for twice the work (was 0.2–0.3). Engines now sit on the World bus, so the booth ducks them.
  - `CrowdVoice`: the murmur and roar left render's `CrowdSystem` (the visuals didn't change). The murmur sits on a
    floor set by `MatchMood` intensity, so a long firefight stays loud between kills, and the result gets a roar.
    Mutation-checked.
  - Voice priority in `SfxSystem`: a sound is weighed by how loud it will be at the camera. Past 600 m or under -46 dB
    it never starts. With the pool full it takes the quietest voice (start level less 14 dB per second of play), and
    only if it's at least as loud, so a distant ping can't cut a nearby cannon's tail.
  - Bench at 60 vehicles, mean per frame on the loaded laptop: booth and mood 0.05–0.07 ms, music 0.03–0.04, engines
    0.17, gunfire 0.09–0.14, one-shots 0.045. **Booth, music and crowd (the M1 line) are ~0.1 ms of their 0.3.**
  - Not done in X4, and why: *the arena PA between rounds* and *ad screens audible near them* wait on the lead's ad copy
    (round 4's open gate), and the screens' positions come from arena's layout v2. *Different ground* has nothing to
    key on yet: every arena floor is one surface.
- **X2 without new sounds (f8fb167): a shell landing is the loudest thing, then falls away.** Heavy impacts play on
  an `Impacts` bus; engines, gun loops, the crowd and small hits play on a `Bed` bus that a compressor keyed from
  `Impacts` pulls down (1 ms attack, 420 ms release). Both feed `World`. The recorded impact sounds themselves are in
  the gated batch.
- **Arena's four maps in the booth (bcff889, arena CP2's request).** `yard`, `boulevard`, `pit` and `boneyard` speak as
  the Container Yard, the Boulevard, the Pit and the Boneyard. Only the 18 `{arena}` lines were recorded for them: 72
  clips, speech-to-text flagged none, 122,834 → 116,573 (the balance may still settle a little lower).
- **X6, the first whole-match recordings (with the pilot guns; the full pass waits for the batch).**
  `make remote T="audio-pass PASS_SECONDS=90"`, CPU against CPU at about 30 a side, the gangs against the Law, booth
  voiced, music on. The first recording found the mix clipping: **true peak +0.1 dBFS, 485 clipped samples**, all
  during the booth's lines, which sat 15–20 dB over the battle with the music summing underneath into an unlimited
  Master. Master now has a hard limiter at -1 dB (`SfxSystem.MASTER_CEILING_DB`, an `AudioEffectHardLimiter` made once by
  whichever system builds a bus first) and the booth sits 4 dB lower (`AnnouncerVoice.TRIM_DB = -4`, applied under
  `--announcer-volume`). Second recording: **-20.6 LUFS,
  true peak -4.7 dBFS, 0 clipped samples**, loudness range 22.4 → 16.9 LU. In the spectrogram the booth's lines now sit
  level with the heavy hits, the pre-contact lull is a quiet bed, and the fight builds from about 35 s. What the log
  says was heard: "The Foundry! Wide open, nowhere to hide", the PA's control-point welcome, and the Veteran on "the
  Wreckers" by name; the music changed 3 times. What I can't tell from numbers is whether it *sounds* good: that is
  the lead's (build/audio/pass.mp3 on builder0 runs).
- **The batch, the PA lines, and what the guard caught (a59f331, 5e3e6de).** Every gun and impact is now layered (44
  takes). `sfx_layer` refuses a master whose own peak is under -20 dBFS: that's a failed generation, not a quiet sound.
  Pointed at everything, including what had shipped, it caught `autocannon_round` take 2 from the pilot the lead had
  approved, `bullet_on_steel` take 3, and `mg_single` take 3 three times running (so `mg_round`, which no weapon plays,
  keeps two takes). It also caught the flamethrower's new loop importing compressed, the loop bug again; `make
  sfx-layer` now fixes a new loop's import after Godot creates it. The twelve approved PA lines are recorded, with an
  intro beat (welcome, then a word from the screens) and an outro beat (result, then a sign-off). Speech-to-text heard
  `pa.signoff.02` as "[outro jingle]": the spectrogram is plain speech, and two fresh transcriptions match the text
  exactly.
- **Frame-rate and tick-rate assumptions, ahead of the 30 Hz tick (35ba8dd, 0cbcafc).** Engines read the interpolated
  transform, and their speed and load smoothing is in seconds (a test fails with the old per-frame lerp at 30 vs
  120 fps). The booth's match clock divided ticks by a constant 60, which would have run the booth, mood and music at
  half speed; it reads `Engine.physics_ticks_per_second` now. Everything else in audio's paths was already in seconds.
- **Music at 30 a side (d16fe38, and the pass logs).** First contact takes the intensity from 0.4 to 0.9 in under a
  second, which was a cut from pad to full band. On a bar line the director now moves one layer, so a battle
  arrives over three bars (6 s at 120 bpm). `MUSIC_LAYERS` logs `pos=`/`bar=` because `t=` is the game clock, not the
  music's (a headless match read t=14.5 with the music at 2.0 s).
- **The lead's music is in (190dea27 and the drop of the placeholder stems).** He generated 23 Suno tracks
  (`assets/incoming/music/`, git-ignored, backed up). Sorted with `tools/audio/survey_tracks.py` (tempo, tone, and the
  steadiest window in each), **9 are used**: garage and victory from the two cleanest *Wasteland Blues* takes,
  pre_match from *Anvil of Doom* (his 60 BPM intro), lull from *Subterranean Anvil*, last_stand from *Anvil Protocol*,
  defeat from *Mechanical Dread*; the fight is three stem sets at different tempos so the rotation reads as variety —
  *Hydraulic Wasteland* (112), *Ritual of Iron* (120), *Rust & Hydraulic Pressure* (129), each split with demucs on
  builder0 (their vocals stems are 13–18 dB down: bleed, as expected from instrumental tracks). **14 spares** remain
  for per-faction or per-arena music: Machine Combat, Warzone Brass, Factory Silence, Ragnarok's Engine, Mechanical
  Predator ×2, Apocalyptic Machine Hymn, Mechanical Momentum, Predatory Hunt, Neon Outrun, Post-Apocalyptic Convoy,
  Rusted Steel Sky, Wasteland Blues, Neon Wasteland Blues. Nothing he sent was unusable.
  **Two fixes the real tracks forced:** the importer searches whole-bar loop points for the quietest seam instead of
  taking the first (the first garage import seamed at 0.46, six times the limit), and it searches on the **encoded**
  file, because normalising, limiting and Vorbis move the waveform enough that a seam measured before them read 0.098
  where `music-check` measured 0.347. Everything now seams under 0.02.
  **Measured in a real match with his music:** -19.8 LUFS, true peak -3.7 dBFS, 0 clipped, the lull track handing over
  to the fight track at contact and the layers building; a second match drew a different fight track.
  **The one gap, for him:** his set has no slow, hollow defeat track (he made three kinds: garage calm, the 60 BPM
  intro, and combat). Defeat uses *Mechanical Dread*, which grinds rather than mourns. The *Acid Rain Wasteland*
  prompt in PROMPTS.md fills it in minutes if he wants one.
- **The lead heard the whole match (2026-09-17): "the new sound effects sound awesome"**, and the music "is not matching
  the vibe I wanted". He supplied his own proven Suno prompts. `assets/music/PROMPTS.md` is rewritten around them
  (verbatim, checked line by line), one per bed, with exact steps (01b9fae4). Decisions: the fight (skirmish into
  battle) is **his three GOOD battle tracks as stem sets** that rotate per match, split locally with **demucs on
  builder0** (`make music-stems`; PyTorch has no room on the laptop; tested on the repo's own mix, and the drums and
  bass stems follow the real parts), because two Suno generations never share an arrangement to layer. `lull`
  (Lockdown Protocol, "good but slow") and `last_stand` (Cyber Metal / Dark Techno) stay whole tracks, where a change
  of song is the point. `music-import` gained `FROM`/`TO` (Suno's intros and outros don't loop) and `STATES`, and a
  real track retires the placeholder states it covers: a placeholder stem set outranks any single bed and would
  otherwise keep playing over his lull. The whole workflow ran end to end on a scratch copy, and `music-check`
  correctly refused a split whose "other" stem was silent.
- **The fight music stopped after 8 seconds in every match, since X5 (bc1ce8f), and the mix was balanced against that
  silence (the music trim commit).** `AudioStreamSynchronized` reports no playback position (every `MUSIC_LAYERS`
  line in the passes read `pos=0.000`), so the director could neither seek the stems back to their loop start nor
  find a bar line. A music-only pass (`PASS_FLAGS=--audio-solo=music`) proved it: sound for 8 s, digital silence
  from 10 s. Each stem is now a looping copy of its resource, and a stem track's position comes from the director's
  own clock wrapped to the loop; the same pass afterwards had music for the whole 40 s. With the music actually
  playing, a full match measured -15.2 LUFS and was mostly music, so the soundtrack sits 9 dB under the battle
  (`MusicDirector.TRIM_DB`): -20.6 LUFS, true peak -2.9 dBFS, building from about -25 dB before contact to -15 in the
  battle. Lesson for the next owner: **solo each layer in a real match before judging the mix** — a layer that has
  silently stopped makes every other level look right.
- **Locked 30 fps (the lead's new target).** `make audio-bench` reports each system's worst frame and frames over 1 ms.
  Nothing in audio spikes periodically; the slow frames move between runs and hit several systems at once (machine
  scheduling), and the one repeatable one is the bench reloading its fixture.
- **Bug from control (2b28709): the booth called every side the Condemned outside the match runner.** The event
  adapter gave both teams one default faction. Each side's faction is now read from the vehicles the match fielded.
  Test, mutation-checked. The same class of fix as `--arena=random` (50bde77, the booth names the arena that was
  built): read what the match built, never what a flag said.
- **Stretch: `--audio-solo=guns|impacts|engines|crowd|booth|music|ui` (e953586)** plays one layer of the mix, for tuning.
- **X6 tooling (8ae6404).** `AudioRecorder` (`--audio-record=PATH`) records the Master bus, and `make audio-pass`
  records a 30-a-side CPU match with the booth voiced and the music on, then reports loudness, range, true peak,
  clipping, loudness every 5 s, booth lines and music changes, plus an MP3 and a spectrogram. The full pass waits for
  the batch sounds, so it's the mix the lead will actually hear.

### What to playtest (exact commands)
- **The game with everything on:** `make skirmish` (announcer voiced, music on). What's new: the four pilot guns
  (cannon, 25 mm, MG stream, shell on armour) layered with ElevenLabs; loops that loop their whole length; engines that
  roar pulling away, with tracks or tyres under them; a crowd that stays loud through a long firefight and roars at the
  result; the fight music building in layers instead of swapping tracks; big hits ducking everything underneath; the
  booth naming the map.
- **A/B the old sound effects:** `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish
  --announcer=voice --music=on --sfx-synth`.
- **One layer at a time:** the same command with `--audio-solo=guns` (or `impacts`, `engines`, `crowd`, `booth`,
  `music`, `ui`).
- **Watch it:** `make cinematic`.
- **Numbers:** `make audio-bench` (per-frame cost), `make music-check`, `make sfx-generate` (dry run, the batch's cost).

### Never skip the whole-match pass
**Everything else was green both times the whole-match recording found a shipped bug.** The booth's lines clipping at
+0.1 dBFS, and the fight music stopping after 8 seconds in every match (so the whole mix had been balanced against
silence), both passed every unit test, level check, contract check and smoke. No per-clip check could see either.
Before calling any audio change done: `make remote T="audio-pass PASS_SECONDS=90"`, and at least once per round each
layer alone (`PASS_FLAGS=--audio-solo=music`, `=guns`, …), then look at the PNG and listen to the MP3.

**Engine gotcha, `AudioStreamSynchronized`:** it reports no playback position (`get_playback_position()` is always
0.0), so you can't seek it or read bars from it. Loop each sub-stream by itself (`loop`/`loop_offset` on a copy of
the resource) and keep your own clock for position, as `MusicDirector.position_s()` does for stems.

### How to hear and measure each part (for whoever owns audio next)
Every command runs from the repo root. `GODOT=.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64`.

| To hear or measure | Run |
|---|---|
| The whole game, everything on | `make skirmish` (or `make cinematic` to watch CPU against CPU) |
| **Only the guns firing** | `$GODOT --path . -- --skirmish --announcer=voice --music=on --audio-solo=guns` |
| Only impacts and explosions | the same with `--audio-solo=impacts` |
| Only engines and running gear | `--audio-solo=engines` |
| Only the crowd | `--audio-solo=crowd` |
| Only the booth | `--audio-solo=booth` |
| Only the music | `--audio-solo=music` |
| Only UI blips and acknowledgements | `--audio-solo=ui` |
| The old synthesised sound effects, for A/B | add `--sfx-synth` (combines with `--audio-solo`) |
| A whole match's mix, measured | `make remote T="audio-pass PASS_SECONDS=150"` → `build/audio/pass.{mp3,png,json}`: integrated loudness, true peak, clipped samples, loudness every 5 s, booth lines, music changes. Look at the PNG (the booth's lines are the dense striped blocks) and keep true peak under -1 dBFS with 0 clipped samples. It's gangs against the Law at about 30 a side, booth voiced, music on. It needs builder0's display because the sound effects only exist with one |
| What audio costs a frame | `make audio-bench` (headless): booth and mood, music, engines, gunfire, one-shots, mean and p95. `make perf-scene` is muted and shows no audio |
| The music contract | `make music-check`; the layers changing in a real match: `make music-smoke` (`MUSIC_LAYERS` lines) |
| The gun and impact recipes, and what the batch costs | `make sfx-generate` (dry run); remix for free after editing `layer` settings in `assets/audio/elevenlabs/sources.json`: `make sfx-layer` |
| A scripted firefight mixed both ways, as files | `python3 tools/audio/sfx_montage.py` → `build/audio/montage/{synth,layered}.mp3` |

**If the match's pacing changes** (ai reported doctrine losing at 30 a side with a control point, so the fight may
change shape this round): the music director's layer thresholds are the stems' `from` values in
`assets/music/manifest.json`, and `MatchMood`'s heat and hysteresis decide when the states move. Run `audio-pass` and
read `MUSIC_LAYERS` against the booth's lines before retuning either.

### The lead's spare music (14 of his 23 tracks, in `assets/incoming/music/`, git-ignored and backed up)
Sorted by `tools/audio/survey_tracks.py`; "seam" is what a loop over the steadiest window would cost, so the low ones
import cleanly today. Nothing here is second-rate — his set simply has more combat material than eight beds need.

| Track | BPM | Character | What it might suit |
|---|---|---|---|
| Neon Wasteland Blues | 71 | the darkest of the blues takes, 86% low end | a second garage bed, or a quiet results screen |
| Wasteland Blues | 82 | the brightest blues take | the garage, if he tires of the one in |
| Machine Combat | 106 | brightest of the combat group, seam 0.00 | a fourth fight set; the cleanest import of the spares |
| Post-Apocalyptic Convoy | 110 | mid, sparse, seam 0.01 | a `lull` alternative with more motion than Subterranean Anvil |
| Mechanical Predator, Mechanical Predator (1) | 110, 126 | two takes of one prompt | per-faction fight music (the Syndicate reads as the colder one) |
| Apocalyptic Machine Hymn, Factory Silence, Ragnarok's Engine | 112 | the same tempo as the Hydraulic fight set | per-arena fight music: the same grid, so they can share bar lines |
| Warzone Brass | 112 | brightest centroid of the set (3229) | a brass-led fight set, if the booth needs more room it isn't taking |
| Mechanical Momentum | 120 | seam 0.01, steady | a fourth fight set at Ritual of Iron's tempo |
| Neon Outrun | 126 | least low end (45%), most synthwave | the title screen or the garage, where there is no battle to sit under |
| Predatory Hunt | 126 | driving, seam 0.18 | a `last_stand` alternative |
| Rusted Steel Sky | 178 (89 doubled) | fastest, thin low end | a `last_stand` alternative with more panic |

### Verified
- `make remote T=check` exited 0 against 181f6ca: 872 Godot tests, sim hash `d4bd86eee0f96c54` unchanged,
  announcer-variance, announcer-record-smoke, music-smoke (1 layer change in its 40 s match) and audio-check all passed.
  **Final: `make remote T=check` exited 0 against 7cadd8d7** (everything in this report, the lead's music included):
  946 tests, sim hash `32f665bc60306e8f` matching main's baseline, announcer-variance, announcer-record-smoke,
  music-smoke and audio-check all passed. Later commits touch only this brief.
- Two things the check found on the way, both mine and both fixed: `CrowdSystem` built its `CrowdVoice` in a field
  initializer, which leaked on relay-smoke's headless clients (a77d9e3, reproduced with a probe, regression test); and
  builder0 has no numpy or scipy (`make audio-deps`, 181f6ca).

### Known issues
- Music-smoke's 40-second match only reaches one layer change on builder0 (two on the laptop): the match is short, and
  the smoke asserts the soundtrack changes, not how much.
- `make audio-bench` prints "resources still in use at exit" from its own teardown; the numbers are unaffected.
- `make_music_placeholders.py` seeds beds with Python's salted `hash()`, so regenerating rewrites the unchanged beds
  and stingers. The committed ones were restored by hand; the fight stems use a fixed seed.
- The balance lags the API by minutes: ledger rows show what was read when the run ended, with a note where it moved.

### Next steps
1. **Two questions are with the lead** (the page above): whether his music sits at the right level under the battle
   (`MusicDirector.TRIM_DB`, currently -9 dB) and whether the booth sits above it (`AnnouncerVoice.TRIM_DB`, -4 dB).
   Both are one constant and a re-measured `audio-pass`; no credits.
2. **He has no slow, hollow defeat track.** Defeat uses *Mechanical Dread*, which grinds rather than mourns. The
   *Acid Rain Wasteland* prompt in `assets/music/PROMPTS.md` fills it; import with `make music-import STATE=defeat`.
3. **`Hud.post_caption(speaker, text)`** is control's new caption line. The booth still posts
   `post_message("CALLER: …")`, which control routes for now; switch `announcer_booth.gd` once it is on main.
4. **Spares to spend** if per-faction or per-arena music is wanted: the table above. The director already rotates
   between equally fitting tracks, so adding a fourth fight set is an import, not code.
5. **Round 4 leftovers still open:** the arena PA reading between rounds needs the ad screens placed (the copy is
   approved and recorded); per-faction *voice treatment* for the booth is unexplored.

### Requests to other streams
- **control:** when `Hud.post_caption(speaker, text)` reaches main, the booth switches to it from
  `post_message("CALLER: ...")` (not done yet: it isn't on main).
- **render:** `make audio-bench` exists for the unmuted perf-scene variant. `perf-scene` numbers so far include no audio.
- **render:** keep `assets/audio/{mg_loop,flame_loop,engine_*,crowd_murmur}.wav` importing as PCM
  (`compress/mode=0`); `SfxSystem.loop_frames(stream)` is the safe way to set a loop end if you touch that code.
- **orchestrator:** back up `assets/audio/elevenlabs/masters/` (paid sources, git-ignored).

### Merge notes (shared files)
- `game/main.gd`: one line `AudioRecorder.attach(self)` after the booth and music attach, and one header line for
  `--audio-record`.
- `game/theme/fx/crowd_system.gd` (render's; agreed): the murmur and roar players and their ~12 lines removed, one
  `add_child(voice)` of a `CrowdVoice` added. `game/theme/fx/engine_system.gd` moved to `game/theme/audio/` (same
  class name), and its test moved to `tests/audio/test_audio_engines.gd`.
- Commit db15512 (X3) also carries X5's four deleted in-match beds (staged before it); X5's own commit has the rest.
