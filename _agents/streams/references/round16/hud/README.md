# Round 16, hud: the two unit-bar defect fixes (the orchestrator's call), at his pose

`make remote T=hud-bar-shots` (builder0, 1854×1011, Law on the Sumps v the Road Gangs, seed 92721, the skirmish's own
camera on group 1; the Gangs' 14 m rig and a scout set down in front, hurt to 60 %, one selected friendly hurt to
45 %; tactical pause). Each image: BEFORE on the left, AFTER on the right, 3× nearest-neighbour.

- `bar-height-before-after.png` (`unit_bars.gd`, commit "bar height"): rows = the rig, the scout, the hurt selected
  friendly. Before, every bar sat 2.0 + 1.2 m up whatever the hull — on the rig's cab (the salmon block), well above the
  scout. After, 1.2 m over each hull's own top. The third row also shows the duplicate bar (two bars on one unit).
- `duplicate-bar-before-after.png` (`rts_controls.gd` + `unit_bars.gd`, commit "duplicate bar"; BEFORE = after the
  height fix): top, the hurt selected friendly — two bars (the controls' round-3 bar, cyan/purple, wide, and UnitBars'
  a few px below) become UnitBars' one. Bottom, the selected row: **the controls' bar was also drawn over every
  SELECTED unit, hurt or not** — those bright bars go too, and a full-health selected unit now shows UnitBars' quiet
  (35 %) bar like any other; the selection rings still mark the selection. `--no-unit-bars` keeps the old bar.
- `selected-bright-bar.png` (`unit_bars.gd`, commit "selected bar bright"; the orchestrator's decision after the
  duplicate drop): the selected row in three states, left to right — height fix only (the controls' bright full-width
  bars over the selection), duplicate dropped (the selection's full-health bars quiet), and now (UnitBars draws a
  SELECTED unit's bar solid at its own width and height). The camera differs slightly between runs.
