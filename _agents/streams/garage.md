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

_(the worker keeps this current)_
