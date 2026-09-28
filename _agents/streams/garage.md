# Stream: garage, round 14 (the list a player's first visit produced)

> Read [`game_design.md`](../game_design.md) *Round 13 direction* (answer 6) and the archived round-13 audio brief
> `archive/round13/audio.md` **Status** (the G1 table: seven things a player would say, with a frame each; the round-14
> list; what already works), the sheets in `references/round13/audio/garage_tour_{desktop,phone}.jpg` and the tour logs
> beside them. **You own** `game/garage/**`, `game/modes/garage_mode.gd`, `mk/garage.mk`, `tests/garage/**`, and the
> garage's page in `_agents/` if you write one. **Carve-outs this round (additive, listed in merge notes, the
> orchestrator reviews at merge; no control, match or fleet stream runs):** (a) the time-limit winner rule in
> `game/match/match.gd` (`start_limits`, the `time_limit` reason) and the results screen's reading of it; (b)
> `game/ui/camera_readout.gd` (its default and its placement at 20:9); (c) the garage turntable's use of the hull-size
> fit — READ `Tank._apply_hull_size` (`game/tank/tank.gd:277`), call it or mirror it from the garage's own preview
> code; do not edit `tank.gd` unless one additive accessor is unavoidable.

## The lead's direction

Round 13, answer 6: *"Yes let's add garage music, but I've never even smoke tested the garage."* The smoke test was
done (audio, round 13, `make garage-tour`); this round builds what it found. Standing: no pay-to-win, fixed units,
the garage is where his son builds an army (vision.md).

## Where things stand (verify on main)

- `make garage-tour` (round 13): a tap-by-tap loop from the title at 1920×1080 and 20:9, `TOUR_DONE failed=0`, a frame
  per step under `build/screenshots/garage-tour/`. The garage bed plays; FIGHT hands over to `pre_match`.
- The round-14 list, from the G1 table, in the order a player hits it:
  1. **"My first + ADD didn't work."** The starter army spends 700 of 800 and the cheapest unit is 110; the first tap is
     always refused (round 13 improved the toast: "Tap a unit and REMOVE it to make room").
  2. **"The garage opens dark with a random tip in the way"** — not dark (the loader's 0.35 s fade), but the match
     loader's command-card tip ("STOP [S]") shows for ~5 s on a garage load.
  3. **"The tank in the garage isn't the tank I fought with."** The turntable shows a short turreted tank; the match
     fields the Condemned's 8.62 m dozer-bus (same slot; the hull-box fit is not applied on the turntable).
  4. **"Nobody fired and it says DEFEAT."** A time-out with nothing lost on either side scores a loss (the tour's 25 s
     match is the extreme; a real stalemate reads the same, and audio saw it read VICTORY by chance too).
  5. **"There's debug text over the HUD."** `camera_readout.gd` (round 6's tool for the lead, `--camera-readout=off`)
     overlaps the score box and the FX/QUALITY buttons at 20:9; the score box wraps.
  6. `catalog_stub.gd` is dead code (the v1 path only); its pre-CP2 boxes are unreachable. Delete it.

## Backlog (in order)

**G1. Room to build.** Decide and build ONE: the starter army leaves ≥ 110 free (a unit fewer), or the first visit
opens with the tip that says REMOVE first (round 13's toast, promoted). Recommended: the starter leaves room — a first
tap that works beats a tip. `test_garage_first_visit` covers it; the tour's `05_added_unit` frame proves it.

**G2. The turntable shows the vehicle he fights with.** The preview applies the same hull-size fit the match applies
(carve-out c). Test: the turntable's tank mesh AABB length equals the catalogue's `hull_size` length within 5 %;
frame beside the match's `16_fight_6s` at the same unit.

**G3. A stalemate is a draw, or is judged.** Carve-out (a): on `time_limit` with no kills either side, the result is
DRAW (recommended) — or, if the lead's control-point rules give a score, that score. Results screen says "Time ran
out — draw" and pays what a draw pays (nothing new: no credits for a draw is fine, say so). Test with a 5 s time limit
and no contact. Make sure a REAL win on time (more kills) still reads VICTORY.

**G4. The HUD is clean for a player.** Carve-out (b): the camera readout defaults OFF for a player (ON under
`--camera-readout=on`, and in the lead's dev launch if `make skirmish` passes it — check how he launches; keep his
tool one flag away) and, when on, sits where it does not overlap at 20:9; the score box does not wrap at 20:9. Frames
at both aspects.

**G5. The loader shows the army, not a command tip**, on a garage load (the tip is a match thing). Small; do it if it
is under an hour, else list it.

**G6. Delete `catalog_stub.gd`** and whatever only it reached; the garage check stays green; say in the commit what
depended on it (nothing, per audio — verify).

**G7 (stretch).** Play the loop yourself with a display (`make remote T=garage-tour`, look at every frame again) and
write the NEXT list in the same register, with frames.

## How to verify

`make remote T=check` (the garage smokes are in it) green on every named commit; `make remote T=garage-tour` at both
aspects, `TOUR_DONE failed=0`, and LOOK at the frames; commit a before/after sheet under
`_agents/streams/references/round14/garage/`. Sim baseline `6313a38d7ecd99bb` pre-registered UNMOVED (G3 changes the
verdict at the time limit, which the baseline match — a 40 s elimination — never reaches; say so and check it).

## Don't touch

`game/audio/**`, `assets/music/**` (audio's, paused); `game/tactics/**`, `game/ai/**`; `game/theme/**` beyond reading
`tank.gd`; `game/control/**` beyond `camera_readout.gd`; `game/match/**` beyond the time-limit rule.

## Waiting on the lead

Nothing blocks. G3's rule (draw vs judged) is a recommendation; record the choice and the reason.

## Status

_(the worker keeps this current)_
