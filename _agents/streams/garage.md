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

_Updated 2026-09-28 by the garage worker. Numbers are builder0 unless marked; each names its commit._

### Plan (as worked, the brief's order)
G1 → G2 → G3 → G4 → G5 → G6 (every one done), then G7 (the tour again, frames looked at, the next list).

### Baseline
`b5c11813` (the branch as launched): builder0 `make check` exited 0, 18 targets, **1790 passed / 0 failed**.

### Done

- **G1 room to build** (`4547ffc4`). Decision: **the starter leaves room** (the brief's recommendation; a first tap
  that works beats a tip). `GarageScreen.starter_army` builds Anvil & Hammer at *budget − cheapest unlocked unit* and
  prices it against the full budget. Scrapyard (800): **Tank, Tank | IFV, Scout = 660, 140 left** (was Tank, Tank |
  IFV, IFV = 700, 100 left). Same four units; one IFV became a Scout, so the army that FIGHTs untouched is 40 points
  lighter. Why not "a unit fewer" (550, 250 left, any unit fits): that fields 550 against the CPU's 800 for a player
  who hits FIGHT first; a Scout fitting is the first tap that works without weakening the first fight. The + ADD
  refusal still says REMOVE when an add does not fit. Test: `test_garage_first_visit` (every budget tier).
- **G2 the turntable shows the vehicle he fights with** (`aaa4bde5`). Carve-out (c) taken as **call it, not mirror
  it**: the preview is now a real `Tank` from tank.tscn (`simulate = false`, processing disabled, nameplate hidden),
  so `apply_unit` → `_apply_hull_size`, the turret mount, `DozerPart._fit_to_hull` and the gun cuts run exactly as in
  the match. A mirror was not possible anyway: the art's fit (`_fit_to_hull`) only runs under a `Tank` ancestor.
  `tank.gd` untouched. The camera frames the unit's bounding sphere in the narrower view angle; the floor disc grows.
  Tests (`test_garage_turntable`): every garage unit drawn within 5 % of its `hull_size` length (measured as
  `test_theme_unit_scale` measures a match vehicle); the shortest and longest unit have all 8 box corners in view
  at three spins.
- **G3 a stalemate is a draw** (`83c2aa1d`). Rule chosen: **judged**. On `time_limit` under elimination the side that
  **destroyed more points** (catalogue cost of the other side's losses, `Match._points_lost`) wins; **equal —
  including nothing — is a DRAW**. The control point (skirmish default ON) still decides first when its score
  differs. Why judged rather than only "no losses → draw": the old tie-break (more tanks alive, then health) also
  made a *real* win on time read as a draw (1 v 2, Green kills one, loses none → 1 v 1 at full health → draw) and
  favours the bigger army of cheap units (the gang swarm). Points, not unit count, for the same reason. Results
  screen: "Time ran out — draw"; a draw pays the existing `AWARD.draw` (30, nothing new). The skirmish's finish
  banner said DEFEAT on any non-win: it now says DRAW on a draw. Tests (`test_garage_time_limit`): a real 5 s
  time-out with no contact, 1 tank v 2 → draw; a kill with no losses → that side wins; a tank each → draw; a scout
  lost against a tank lost → the scout's side wins.
- **G4 the HUD is clean** (`83c2aa1d`). The camera readout is **off unless `--camera-readout=on`**
  (`CameraReadout.wanted`); **`make skirmish` passes it** (his launch; `CAMERA_READOUT=off` drops it), so his tool is
  where he left it and a player (title, garage, web) never sees it. When on it sits between the HUD's two message
  columns (`CameraReadout.placement`) and its font shrinks to that gap (≥ 9 px). The score box: the line steps its
  font down to stay on one line (hud_skin, additive). Tests (`test_garage_hud_clean`): off/on by flag; clear of the
  status block and both columns at 1920×1080, 1800×810 and 2400×1080.
- **G5 the loader shows the army** (`e4b4db3e`, well under the hour). `GarageMode.loader_card(flags)`: "YOUR ARMY  MY
  ARMY / 2 Tanks · 1 IFV · 1 Scout · 660 / 800" and one hint line, drawn where the command-card tip was, on a garage
  load only (REMATCH, a challenge, an immediate autofight keep the tip). Test `test_garage_loader`.
- **G6 `catalog_stub.gd` deleted** (`e4b4db3e`) with what only it reached: `ArmyCatalog.is_stub`, `from_game`'s stub
  branch (now a `push_error` if `Units` were ever not v2), `ArmyFormat.game_reads_v2` and the v1 stand-in path of
  `to_game_doctrine` (now a copy), `GarageMode.fight`'s v1 copy. **What depended on it: nothing live** (verified:
  every use was gated on `Units.PROFILES` being v1; no test, tool or make target named it).
- `garage-tour` (`75fb0e25`) now checks round 14: the first + ADD before any REMOVE, the loader's army card, no camera
  readout in the fight, a quiet time-out reads DRAW.

### Verification
- `tools/remote.sh test 'FILTER=garage|army_screen|army_draft|army_progression|rts_camera|army_challenges|theme_unit_scale'`
  at the tree committed as `75fb0e25`: **97 passed, 0 failed** (builder0), including the 12 new tests.
- `make check` and `make remote T=garage-tour` at `75fb0e25`: _running_.
- **Sim baseline `6313a38d7ecd99bb` pre-registered UNMOVED**, with the path: G3 changes only `Match.result`'s winner
  for `reason == "time_limit"`, which the baseline match (a 40 s elimination) never reaches, and the winner is not in
  the state hash; everything else is garage/UI.

### Questions for the lead
- None blocking. G3's rule (points destroyed, then draw) is a recommendation, recorded above; the one-line alternative
  is "no losses either side → draw, else the old standing rule".

### Requests to other streams / the orchestrator
- G3 changes what `time_limit` elimination results report as the winner. Any ladder or series that ends matches on
  time (`tools/match_series.py`, `ai_ladder.py`, `faction_matrix.py` …) will see time-outs judged on points destroyed
  instead of tanks alive + health. Elimination wins are unchanged. Squad and nav: if a series you compare across this
  merge has many time-outs, re-run its baseline side.

### Merge notes (shared-file edits, all additive; the orchestrator reviews)
- `game/match/match.gd` (carve-out a): `result()`'s time-limit branch and `_points_lost`.
- `game/ui/camera_readout.gd` (carve-out b): `wanted`, `placement`, the draw position.
- `game/modes/skirmish_mode.gd` (not a listed carve-out, two small edits in the spirit of a and b): the finish
  banner reads DRAW on a draw; the readout's condition calls `CameraReadout.wanted` (the default lived here).
- `game/ui/widgets/hud_skin.gd` (not listed): `_fit_scoreboard_line`, the score line kept on one line (the brief's
  "the score box does not wrap at 20:9").
- `game/ui/loading_screen.gd` (not listed; G5 is the brief's item): `garage_card` and its drawing.
- `mk/play.mk`: `make skirmish` passes `--camera-readout=$(or $(CAMERA_READOUT),on)`.
- `_agents/workstreams.md`: the *What reads hull_size* table (the stub row struck, the turntable's row added).
- Two docs commits of the orchestrator's (`d6ab3ac5`, `a3aee344`, the airship A0 notes) appeared on this branch
  under mine while I worked; they are docs only and already on main's side.

### What to playtest (exact commands)
- `make title` → GARAGE: the loader names your army; tap + ADD on the Scout first (it works); tap the Tank in Alpha
  and look at the turntable (the long dozer-bus you fight with); FIGHT; let the clock run out with nobody fighting:
  the banner and the results say DRAW. At 20:9: `--resolution 1800x810 --ui-touch`: no camera text over the HUD.
- `make skirmish`: the camera readout is still there for you (P copies the pose); `CAMERA_READOUT=off` hides it.

### Next steps
- G7 (stretch): the tour again, every frame looked at, the next list (below once written).
