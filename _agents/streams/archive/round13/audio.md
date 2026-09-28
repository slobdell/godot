# Stream: audio, round 13 (the garage, smoke-tested like a player, then given music)

> **ARCHIVED — round 13 closed 2026-09-27.** This brief is kept as written, including its pre-registrations and the
> ones the stream proved wrong. What shipped is in `HANDOFF.md` *ROUND 13*; the lead's words are in `game_design.md`
> *Round 13 direction*; the evidence is in `streams/references/round13/`; the next round's candidates are in
> `roadmap.md` *Round 14 candidates*.


> Read [`game_design.md`](../../game_design.md) *Round 13 direction* (his answer 6, verbatim), the archived round-12 brief
> `../round12/audio.md` and its Status (the director's per-state draw, the manifest, the `garage` state that
> nothing plays), and `assets/music/PROMPTS.md`. **You own** round 12's audio paths (`game/audio/`, `assets/music/`,
> `tools/audio/`, `mk/audio.mk`, `tests/audio/`, the announcer paths) **plus a carve-out this round:** `game/garage/**`,
> `game/modes/garage_mode.gd` and the garage targets in `mk/garage.mk` — for the smoke test and the music hook ONLY. The
> garage stream is paused; a garage feature or fix bigger than an hour is written up as a round-14 item, not built.

## The lead's direction (2026-09-27)

> *"6. Yes let's add garage music, but I've never even smoke tested the garage."*

And answer 5: *"29 MB of music is fine"* (the web pack question is closed; add what the garage needs).

## Where things stand (verify)

- `MusicDirector.STATES` includes `garage`; the manifest has a `garage`/`victory` pool of 4 (round 12); **nothing in
  `game/` asks the director for the `garage` state** (round 12's finding: the same shape as `pre_match` before it was
  fixed). `game/modes/garage_mode.gd` is the mode; `make garage`, `garage-smoke` (headless: open, FIGHT, the skirmish
  starts with the saved army, no errors), `garage-shots`, `garage-e2e`, `garage-web-smoke` exist and are in `check`'s
  garage smoke — **headless**. He has never played it: the title → GARAGE → build → FIGHT path with a display, at his
  aspect, is the gap.

## Backlog (in order)

**G1. The garage as a player sees it.** From the title, on the default path, with a display (builder0's, `make remote`):
GARAGE → build an army (tap/drag, the budget, a preset, an army code) → FIGHT → the match → results → REMATCH/ARMY.
Frames at desktop 1920×1080 and the 20:9 phone aspect (`garage-shots` is the start; extend it to the whole loop).
**Look at every frame** and list what is wrong in Status, in his words' register (what a player would say), with the
frame beside each: broken layout, a button that does nothing, text that overflows, a stale unit (the catalogue stub
`catalog_stub.gd` hardcodes pre-CP2 boxes — does the garage show the right vehicles at all?). Fix what is an hour's work
inside the carve-out; the rest is the round-14 garage list.

**G2. Garage music.** The garage mode asks the director for `garage` on enter and hands back on leaving (to `pre_match`
via the title, or straight to the match: which state the FIGHT hand-off lands in must be stated and tested); the pool
rotates like every other state (least recently heard first; the test from round 12's M1 extended to `garage`).
`music-smoke` and `audio-launch-smoke` extended to cover entering the garage. `make music-check` on anything imported;
`assets/music/PROMPTS.md` updated. If the four-track pool shares with `victory`, decide whether the garage wants its own
mood (his tracks: `Factory Silence`, `Neon Outrun` are candidates by title) and say why.

**G3 (stretch).** The two placements made by title (`defeat_hunt`, `defeat_ragnarok`): listen if you can; otherwise
leave the note for him.

## How to verify

`make remote T=check` (the garage smokes are in it); `make remote T=garage-shots` and your loop frames; `music-smoke`
and `announcer-record-smoke` matching their no-audio controls; the sim baseline `6313a38d7ecd99bb` pre-registered
UNMOVED (the garage is outside the match).

## Don't touch

`game/tactics/**`, `game/ai/**`, `game/theme/**`, `game/control/**`, `game/match/**`.

## Waiting on the lead

Nothing. The frames and the round-14 garage list go into Status for him.

## Status

_Updated 2026-09-27 by the audio worker. Numbers: builder0 unless marked; the check hashes are named where they ran._

### Plan (as worked)
1. G1 first, because G2's hook sits on the path it tests: a scripted player's tour from the title (`make garage-tour`).
2. Fix what the tour finds that is an hour inside the carve-out; list the rest for round 14.
3. G2: the director holds `garage` while the builder is up; FIGHT hands back to the mood; the pools split.
4. G3 (stretch): the two defeat placements are a listening job; nobody on the agent side can listen (below).

### G1: the garage as a player sees it: DONE

**How:** `make remote T=garage-tour` (new, `tests/garage/garage_tour.gd`). From the title, by real input events (taps
at a control's centre, a drag by mouse motion): GARAGE → REMOVE a unit → + ADD a Scout → drag an IFV card onto squad 2
→ PRESETS → a preset → SHARE (read the code) → IMPORT it → COMPARE / UNLOCKS / CHALLENGES → FIGHT → the match →
results → REMATCH → results → ARMY → the builder again. 1920×1080 and 1800×810 (20:9, `--ui-touch`), a first visit
(`--tour-fresh`: no tips seen, no credits, no armies). Prints `TOUR_STEP` per step and `TOUR_DONE failed=N`. Frames:
`build/screenshots/garage-tour/{desktop,phone}/` (git-ignored); **committed:** `references/round13/audio/garage_tour_{desktop,phone}.jpg`
(contact sheets of tour 4 at `1dae1959`, every frame labelled by step) and the two tour logs beside them. Tour 1's
pre-fix frames were overwritten by later runs; its log lines are quoted in the table.

**What a player would say, frame by frame** (tour 1, `8f96a43c` + the title line, before any fix):

| # | what a player would say | frame | status |
|---|---|---|---|
| 1 | *"There's no garage on the title."* The menu was SKIRMISH / SPECTATE / MULTIPLAYER / FX LAB / TEST DRIVE; the only way in was `make garage`. | sheet `01_title` (after: GARAGE is the 2nd row) | **fixed** (a GARAGE row) |
| 2 | *"I hit FIGHT and it asked me to pick a faction, with nobody on the field."* A windowed FIGHT ran the skirmish's faction menu (`GARAGE_FIGHT … green=0 rust=0`); picking there restarted a plain skirmish WITHOUT the army. Every garage check was headless, where that menu never opens. | tour 1's log: `GARAGE_FIGHT … green=0 rust=0`, `TOUR_STEP 15 fight_6s FAIL … faction menu instead: true`; after: sheet `17_fight_6s` | **fixed** (`--no-pick-faction` in the hand-over); tour 3: `green=4 rust=4`, the match loop runs |
| 3 | *"My first + ADD didn't work."* The starter army spends 700 of 800 and the cheapest unit is 110: the first tap is always refused, in red. | tour 1's log: `+ ADD: 4 -> 4 units (Not enough budget: a Scout costs 110, 100 left.)`; the tour now REMOVEs first (`06_removed_unit`, `07_added_unit`) | **improved**: the toast now says *"Tap a unit and REMOVE it to make room."* (test `test_garage_first_visit`). The starter itself is a round-14 call |
| 4 | *"The tank in the garage isn't the tank I fought with."* The turntable shows a short turreted tank; the match fields the Condemned's long dozer-bus. Same slot (`unit.tank.hull` → the dozer), so most likely the match's fit to the 8.62 m hull box (`tank.gd::_apply_hull_size` / `_fit_to_hull`) is not applied on the turntable. | sheet `05_garage_open` (turntable) vs `17_fight_6s` (the same Tank in the match) | round 14 (theme-side, not an hour) |
| 5 | *"Nobody fired and it says DEFEAT."* A 25 s time-out with nothing lost on either side scores a loss (Match's time-limit winner; the tour's short match is the extreme case, but a real stalemate would read the same). | sheet `20_results`, `22_rematch_results` | round 14 (`game/match`, not ours) |
| 6 | *"There's debug text over the HUD."* The camera readout (`CAMERA pitch 21° …`, round 6's tool for the lead, `--camera-readout=off`) overlaps the score box and FX/QUALITY buttons at 20:9, and the score box wraps as "Green 4 units vs / 6 units Rust". | phone sheet `17_fight_6s`, `18_match_mid` | round 14 (control's HUD) |
| 7 | *"The garage opens dark with a random tip in the way."* **Checked, and no:** that frame is the loading screen's 0.35 s fade-out (`LOAD_TIMING total_ms=5439` printed just before it; `first_frame` 1.7 s on builder0's display); the next frame is fully lit. What IS true: a garage load shows the match loader's command-card tip ("STOP [S]") for ~5 s. The tour now frames the loader (`garage_loading`) and waits for it to go before `garage_open`. | sheet `04_garage_loading` (the loader), `05_garage_open` (lit) | noted; harmless |

**What works as a player expects** (tour 3, both aspects, `TOUR_DONE failed=0`, no `ERROR`): the catalogue is the
live roster, not the stub (COMPARE lists the Burner, which `catalog_stub.gd` does not have; Scout 110, IFV 150, Tank
200, Lancer / Artillery / Burner locked); REMOVE, + ADD and a card drag onto a squad all change the army; PRESETS opens
and applies; SHARE shows a code and IMPORT reads it back; COMPARE, UNLOCKS and CHALLENGES open and close; FIGHT starts
the player's 4 against the CPU (4 or 6, within the 800 budget); results name both armies and a counter lesson; REMATCH
replays the same seed; ARMY returns to the builder with the army that fought (DELETE now offered, it was saved). The
phone layout fits at 1800×810 with nothing clipped.

**The round-14 garage list** (from the table, in the order a player hits them): the starter army should leave room to
add a unit (or open with a tip that says REMOVE first); the turntable should show the vehicle at its match proportions;
a stalemate time-out should not read DEFEAT; the camera readout should not sit over the HUD on a phone (or be off for
players); the garage load's loader could show the army instead of a command-card tip. `catalog_stub.gd` is dead code
while the catalog is v2 (the stub path runs only for a v1 `Units.PROFILES`), so its pre-CP2 boxes are unreachable, the
same shape as the stale fallbacks in `workstreams.md`: delete it when the garage unpauses.

### G2: garage music: DONE

- `MusicDirector.hold(state)` / `release()`: a held director ignores the mood; release returns it to the mood's state.
  `attach()` asks `GarageMode.music_state()` before it starts, so the first bed IS the garage's (no bar of the opening).
- **Which state FIGHT lands in: `pre_match`**, the opening, because nobody has fired; crossfaded on the garage bed's
  next bar line (`MusicDirector.release` → `music_state_for("lull", false)`). Tested
  (`test_the_garage_holds_its_own_bed_until_fight_hands_back_to_the_opening`) and seen in the tour's log:
  `MUSIC_TRACK state=garage track=garage` → `GARAGE_FIGHT` → `state=pre_match track=pre_match` → fight → defeat.
- REMATCH, a challenge and an immediate `--garage-autofight` play no garage bed (`music_state()` is "" there): the tour
  shows REMATCH opening straight on `pre_match`, and ARMY coming back to `state=garage`.
- **The pool split.** Garage: `garage` (Wasteland Blues (2)) + `blues_neon` (Neon Wasteland Blues). Victory: `victory`
  (Wasteland Blues (1)) + `blues_wasteland` (Wasteland Blues). **Why:** FIGHT does not reload the scene, so ONE director
  follows the player from the garage into the match, and a draw is cached per set of tracks: with one shared pool of four
  the win replayed the blues take he had just heard in the garage. The blues stay the garage's because they are his own
  prompt for it (*"good for mech equipping and stuff"*); Factory Silence and Neon Outrun (the candidates by title) stay
  where they are, and PROMPTS.md says how to try one (a second manifest row: intensity ranks per track, so adding
  `"garage"` to their own rows would either never play or take over the lull). Each pool rotates least-recently-heard
  first (`test_the_garage_bed_heard_last_time_waits_its_turn`).
- `--garage-autofight=S` (new: fight after S seconds) lets a headless run hear the garage before FIGHT.
- `music-smoke` now also runs a headless garage (`--garage-autofight=3 --music=on`) and requires the first cue to be
  `garage` and the first after `GARAGE_FIGHT` to be `pre_match`, with no `ERROR`. `audio-launch-smoke` (display) runs the
  title → GARAGE tour with no audio flags and requires the booth's voice, `garage` before FIGHT and `pre_match` after.
- Nothing imported, so no `music-check` input changed (the manifest's `states` only).

### G3 (stretch): not done, for the lead's ear

`defeat_hunt` (Predatory Hunt) and `defeat_ragnarok` (Ragnarok's Engine) are placed by title and by one measure each
(PROMPTS.md). Nobody on the agent side can listen. Tour 2's two losses drew both (`defeat_ragnarok`, then `defeat_hunt`), so a
listening route is `make garage` → FIGHT → lose; or `make remote T="audio-pass PASS_SECONDS=90"` for the whole mix. A wrong placement
is one `states` line in the manifest.

### Verification

- Baseline before any change: `8f96a43c`, builder0, `make check` 1773 passed / 0 failed (`>> remote: make check exited 0`).
- `test FILTER=music_director|garage_music`: 29 passed, 0 failed (builder0).
- `make remote T=garage-tour`: `TOUR_DONE failed=0` at both aspects (tour 3 at `8627c453`+tour edits; tour 4 at
  `1dae1959`), exit 0.
- `make check` at `8627c453`: 17/18, tests 1778/0; RED on `ai-scenarios-check` (`scenario_perf`: AI cost 22 ms/tick,
  builder0 running two checks at once; the load-sensitive timing scenario, no AI code in the diff). At `1dae1959`:
  `ai-scenarios-check` passed, tests 1779/0, RED on `audio-check` only: the new garage leg of music-smoke counted the
  engine's exit-time `6 resources still in use at exit` (the army loop's quit mid-scene; the cues were right:
  garage → pre_match → victory). That one shutdown line is now excluded from the leg's ERROR scan; any other ERROR fails.
- **`make check` at `c4d11015`: GREEN.** builder0, `18 targets, all passed`, tests 1779 passed / 0 failed,
  `>> remote: make check exited 0`. music-smoke: hash `4329da226006f01e` matches the same match without the music; its
  garage leg `garage:garage -> pre_match:pre_match_outrun -> victory:victory`.
- **`make remote T=audio-launch-smoke` at `c4d11015`: passed** (display; not in check). A flagless title → GARAGE:
  booth `voice`; before FIGHT `garage`; after it `pre_match → victory → (REMATCH) pre_match → victory → (ARMY) garage`.
  The wins drew `blues_wasteland` and `victory`: never the take just heard in the garage (the pool split doing its job).
  Note the same short time-out scored a VICTORY here and a DEFEAT in the tour: row 5 of the G1 table is a coin, not a rule.

### Done
G1 and G2 complete; G3 left for his ear (above). **Green, merge here: `c4d11015`** (anything after it is this Status only).
- **Sim baseline `6313a38d7ecd99bb`: pre-registered UNMOVED** (the garage and the music are outside the simulation;
  `music-smoke` compares the hash with and without the music).

### Questions for the lead
- None blocking. For his ear: the garage's two blues, and whether the victory screen misses the other two (the pools
  were one; they are two now, for the reason above).

### Merge notes (shared-file edits)
- `game/ui/widgets/title/title_screen.gd` (control's, look & feel's title): ONE additive line, the GARAGE menu row.
- `game/garage/garage_screen.gd`, `game/garage/garage_mode.gd`, `mk/garage.mk`: the carve-out (garage is paused).
- `tests/garage/`: the tour and one first-visit test.

### What to playtest (exact commands)
- `make title` → GARAGE: the garage's blues; build; FIGHT: the blues hand over to the opening on a bar line; the
  match has YOUR army (no faction menu). After the result, REMATCH (no blues) and ARMY (the blues again).

