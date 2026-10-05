# picker, round 18: frames rescued from its worktree's build/ at the stream's close (2026-10-05)

- `banner-before-*_2_hold.jpg` / `banner-after-*_2_hold.jpg`: the DEFEAT word during the end-of-match slow motion, before
  and after it moved to 66 % of the screen height (merge `1a9564d2`), at 1854x1011 (his window) and 1200x540 (a phone's
  aspect). builder0, `end-trace` with shots, Sumps seed 1. Looked at by picker and by the orchestrator.
- `parade_v3_spot_bay_*.jpg` / `parade_v3_spot_centre_*.jpg`: the Formation panel with its "fits here" line on the
  Parade Ground v3 (maps' `9475c06d` layout file on picker `40cd31b8`): a squad of four in the west bay facing east and
  in the centre; every card read "fits here" at both spots. `make remote T="picker-shots PICKER_ARENA=parade
  PICKER_SPOTS=bay:-80,0,90+centre:0,0,0"` reproduces them on main.
