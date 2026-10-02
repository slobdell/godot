# Stream: garage, round 15 (the second tour's list)

> Read the archived round-14 brief `archive/round14/garage.md` and its **Status** (what shipped, G7's list — this brief
> is that list — the merge notes naming the carve-outs taken), and `references/round14/garage/garage_tour_after.jpg`.
> **You own** `game/garage/**`, `game/modes/garage_mode.gd`, `mk/garage.mk`, `tests/garage/**`. **Carve-outs this
> round (additive, listed in merge notes, the orchestrator reviews):** (a) `game/ui/loading_screen.gd` (the army
> card's hint line); (b) `game/ui/widgets/hud_skin.gd` and the status box it draws (the status line at 20:9); (c) a
> first-visit tip is the garage's own if it is shown in the garage, and a carve-out into `game/modes/skirmish_mode.gd`
> (one additive hook) if it is shown at the fight's planning pause.

## The lead's direction (2026-10-01)

> *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for the night."*

Standing: the garage is where his son builds an army (vision.md); no pay-to-win; fixed units. Overnight: decide,
record the reason, keep going.

## Where things stand (round 14's G7, in a player's words; verify on main)

1. *"I didn't do anything and lost."* A first fight with no orders is lost on the control point (7–0 in 25 s, every
   tour). The results say why; nothing BEFORE the fight says the centre scores (the PA mentions it in passing).
2. *"Is the scout as big as the bus?"* The turntable frames every unit to its panel, so a 3 m buggy and a 14 m rig
   look the same size.
3. *"I can't read the loader's small print on my phone."* The army card's hint line is ~9 px at 810 tall.
4. *"The top-left box on my phone says '(seed' on one line and '81549)' on the next."* The status line wraps at
   20:9 (the score line under it no longer does).
5. *"My tanks and IFVs look the same in the fight."* — fleet's this round, not yours.

## Backlog (in order)

**H1. The centre scores, said before the fight.** A first-visit tip where the player will read it: in the garage
before FIGHT ("The centre scores — hold it or lose on time") and/or at the planning pause (the HUD's message column
already says "give orders first"). One line, once per fresh profile, dismissable; the tour's fresh-profile run asserts
it is shown once and not twice. Decide where and say why.

**H2. The sense of size.** Either a length on the unit card ("8.6 m long") beside the stats, or a fixed scale per army
on the turntable (the longest unit sets the frame; the others draw to scale with a floor grid for reference). Build the
card length first (an hour), then measure whether the fixed scale reads at phone aspect (the 3 m buggy must still be
seen: ≥ 60 px long at 1800×810) — ship the fixed scale only if it does. Test: the card length equals `hull_size` length
to one decimal; the turntable's drawn length ratio buggy:rig equals the catalogue's within 10 % when the fixed scale is
on.

**H3. The loader's hint readable on a phone.** Carve-out (a): the hint line ≥ 14 px at 810 tall (scale with the card),
or dropped on phone if the card already says what the hint says. Frames at both aspects.

**H4. The status box at 20:9.** Carve-out (b): the status line ("Skirmish vs cpu (seed N)") fits on one line at 20:9
the way the score line was made to (`_fit_scoreboard_line`), or drops the seed to a second, deliberate line. Frames.

**H5. The tour again.** `make remote T=garage-tour` at both aspects after H1–H4, every frame looked at, the sheet under
`references/round15/garage/`, and the NEXT list in the same register — the lead's son is the reader.

**H6 (stretch).** The results screen's "they held the centre longer" line links to the tip's words (same phrase), so
the loss teaches the thing the tip said.

## How to verify

`make remote T=check` (garage smokes in it); `garage-tour` `TOUR_DONE failed=0` at both aspects, frames looked at;
sim baseline `6313a38d7ecd99bb` pre-registered UNMOVED (UI only).

## Don't touch

`game/audio/**`, `assets/music/**`; `game/tactics/**`, `game/ai/**`; `game/theme/**` (fleet's); `game/match/**`;
`game/control/**` beyond the two carve-outs.

## Waiting on the lead

Nothing. The sheet is for his morning.

## Status

_Updated 2026-10-02 by the garage worker. Numbers are builder0 unless marked; each names its commit._

### Plan (the brief's order; decisions in one line each)
H1 → H2 → H3 → H4 → H6 (built with H1: same words) → H5 (the tour, last, because it photographs the rest).

### Baseline
`85703220` (the branch as launched): builder0 `make check` exited 0, **1821 passed / 0 failed**.

### Done
- **H1 the centre scores, said before the fight** (`3d01b8d7`). **Decision: at the first fight, not in the garage.**
  The player this is for taps FIGHT first, before the tip bar's three garage tips have advanced, so a 4th bar tip would
  never reach him; and the centre means nothing until the arena is on screen. `CentreTip` (game/garage) is a yellow
  card under the planning banner: *"The centre scores — hold it or lose on time."* It stays the whole planning pause
  and 12 s of play after it, a tap dismisses it. Once per fresh profile (`GarageSettings.take_centre_tip`, saved in
  garage.cfg; X on the garage's tip bar hides it too). **No skirmish_mode carve-out was needed:** GarageMode's own
  handover (`_start_skirmish`, where the match tips were already posted) adds it. Tests `test_garage_centre_tip`; the
  tour asserts it on the fresh first fight and NOT during the REMATCH.
- **H2 the sense of size** (`3d01b8d7`). The card length shipped: every catalogue card's kit line ends "· 9.7 m
  long", the inspector has its own "9.7 m long" line (`ArmyCatalog.length_text` = `hull_size[2]` to one decimal;
  test `test_garage_sense_of_size`). **The fixed scale was measured and NOT shipped:** with the longest garage unit
  (the Tank, 9.70 m) setting the frame, the shortest (the Scout, 3.04 m) draws **65 px at 1920×1080 but 49 px at
  1800×810** on the garage's own turntable (483 × 192 px there) — under the brief's 60 px bar (laptop, headless,
  `3d01b8d7`; pixel geometry, machine-independent). The drawn ratio matched the catalogue within 10 % at both. It
  stays behind `GarageTurntable.scale_unit` (opt-in, unused) with `drawn_length_px()` for re-measuring if the panel
  grows.
- **H3 the loader's hint on a phone** (`3d01b8d7`, carve-out a). The army card grows with the touch boost like the
  HUD (`LoadingScreen.garage_card_metrics`: scale = height/1080 × boost, capped to the screen width) and the hint is
  never under 14 px: 18 px at 1800×810 on a phone (was 12), 14 px at 810 on desktop, 16 at 1080. The card grows when
  two hint lines would not fit. Test in `test_garage_loader`.
- **H4 the status box at 20:9** (`3d01b8d7`, carve-out b). `HudSkin.fit_status`: each status line is kept to one
  line by stepping the font down (to 80 % at most, like the score line's fit); a line still too wide puts "(seed N)" on
  a line of its own instead of wherever the wrap falls. Test in `test_garage_hud_clean` (four screens, two texts).
- **H6 the loss teaches the tip** (`3d01b8d7`). A time-out lost on the point shows the tip's own words as the results'
  lesson (`ResultsScreen.point_lesson`, in THEIR ARMY's lesson slot, where a counter lesson about units that never
  fought used to be); the reason line still says "they held the centre longer (7 to 0)". Test in
  `test_garage_time_limit`; the tour checks it when the loss is on the point.

- **H5 the tour again** (`3d01b8d7`): `make remote T=garage-tour` **TOUR_DONE failed=0 at 1920×1080 and at 1800×810
  (`--ui-touch`)**, 27 steps each, no ERROR in either log. New steps: 18 *the first fight says the centre scores*,
  22 *the loss on the point repeats the tip* (both runs lost 5–0 / 7–0 on the point, as every tour), 24 *the centre
  tip is not shown twice* (the REMATCH). Every frame looked at; the sheet is
  `references/round15/garage/garage_tour_round15.jpg` (loader, garage, first fight, results, back in the garage; both
  aspects), logs beside it. Read off the frames: the status reads "Skirmish vs cpu (seed 28458)" on one line at 20:9;
  the tip sits under the PA caption, clear of the message column and the command card; the cards read "3.0 m long" /
  "7.5 m long" / "9.7 m long"; the loader's hint is legible at phone size; THEIR ARMY's lesson is the tip's words.

### Verification (every number builder0)
- Baseline `85703220`: `make check` exited 0, 19 targets, 1821 passed / 0 failed.
- `3d01b8d7` (H1–H4, H6): `make check` exited 0, **1832 passed / 0 failed** (+11 new tests); `garage-tour`
  TOUR_DONE failed=0 at both aspects.
- **Sim baseline `6313a38d7ecd99bb` UNMOVED**, pre-registered with the path: everything here is UI (a CanvasLayer card,
  labels, the loader's drawing, the HUD's status font); nothing reads or writes the match. `sim-baseline` passed inside
  the check above.

### NEXT list (from the round-15 tour frames at `3d01b8d7`, in a player's words)
1. *"Where IS the centre?"* The tip says the centre scores, but nothing on the field points at it while the tip is up;
   the marker is a small crate mid-field that reads as scenery. Candidate: pulse a ring on the control point (and its
   radar dot) while the tip is shown.
2. *"Two people talked at once."* The tip comes up while the PA's opening line is on screen just above it, so the first
   seconds have two things to read. Candidate: show the tip after the PA's first caption ends (the planning pause is
   long enough), or put the PA's first line about the centre and the tip together.
3. *"Is the scout as big as the bus?"* — now answered in numbers on the card, still not in the picture: the fixed
   scale needs a taller turntable on a phone (192 px tall now; the Scout at 49 px, the bar 60 → ~240 px tall).
   Candidate: a taller turntable at 20:9 (the inspector has room under PAINT), then turn `scale_unit` on.
4. *"It still says TIP 1/3 after I played a whole match."* Back in the garage after FIGHT → results → REMATCH → ARMY
   the tip bar is still on its first tip (the tour never tapped a unit IN a squad, which is what tip 1 waits for).
   Candidate: FIGHT completes the bar (a player who has fought does not need "choose an opponent, then tap FIGHT").
5. *"I lost and got nothing."* A first loss pays +0 ("Match too short to pay"): the tour's 25 s matches; probably right
   for a real match, worth a look at what a first real loss pays (economy, balance.md; not a garage change alone).

### Questions for the lead
- None blocking. Choices made and reversible: the tip at the fight (not the garage), 12 s of play after the pause,
  X on the garage's tip bar also hides it; the fixed scale off on the measurement.

### Requests to other streams / the orchestrator
- None.

### Merge notes (shared-file edits, all additive; the orchestrator reviews)
- `game/ui/loading_screen.gd` (carve-out a): `HINT_MIN_PX`, `garage_card_metrics`, `_draw_garage_card` draws from it
  (the hint's alpha 0.65 → 0.8).
- `game/ui/widgets/hud_skin.gd` (carve-out b): `_fit_status_lines`, `fit_status`, `STATUS_FLOOR`; `_fit_status_frame`
  calls it before placing the score line.
- `game/modes/skirmish_mode.gd`: **not touched** (carve-out c not needed: the tip is added by GarageMode's handover).
- Everything else is the garage's own paths.

### What to playtest (exact commands)
- Fresh profile first (the tip is once ever): delete `user://garage.cfg` (or play from a new browser profile), then
  `make title` → GARAGE: the cards say how long each unit is; FIGHT: the yellow card under the planning banner says
  the centre scores; give no orders and let it time out: the results' lesson repeats it. FIGHT again: no card.
- At 20:9: `make title` with `--resolution 1800x810 --ui-touch` (or a phone): the loader's small print and the
  top-left box ("Skirmish vs cpu (seed N)" on one line).

### Done report
Every backlog item is complete (H1–H5) and the stretch H6 is built; H2's fixed scale was measured and declined on
its own bar. **Green, merge here: `3d01b8d7`** for the code; the commit after it is this Status and the sheet (docs).
