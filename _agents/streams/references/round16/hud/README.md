# Round 16, hud: the two unit-bar defect fixes (the orchestrator's call), at his pose

`make remote T=hud-bar-shots` (builder0, 1854×1011, Law on the Sumps v the Road Gangs, seed 92721, the skirmish's own
camera on group 1; the Gangs' 14 m rig and a scout set down in front, hurt to 60 %, one selected friendly hurt to
45 %; tactical pause). Each image: BEFORE on the left, AFTER on the right, 3× nearest-neighbour.

- `bar-height-before-after.png` (`unit_bars.gd`, commit "bar height"): rows = the rig, the scout, the hurt selected
  friendly. Before, every bar sat 2.0 + 1.2 m up whatever the hull — on the rig's cab (the salmon block), well above the
  scout. After, 1.2 m over each hull's own top. The third row also shows the duplicate bar (two bars on one unit).
