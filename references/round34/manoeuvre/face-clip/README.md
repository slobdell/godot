# The War Rig face-behind clip (round 34 stretch): before v after CP-F attempt 4

`make manoeuvre-face-clip FACE_CLIP_ON= FACE_CLIP_OFF=--nav-off=turnhull` on the laptop (flightdeck, a display), tree
lab/cpf4 e76f6dab6 (TURN_HULL_DEFAULT true, so the BEFORE arm is `--nav-off=turnhull` and the AFTER arm the tree's
default; the target's comment says so). Gangs, faced_right, 180°, seed 5, Foundry, quiet enemy, both arms GDScript,
filmed at 2x. `face_clip_e76f6dab6.mp4` (crf 30 re-encode of the 26 MB render, which is in
`~/overnight-manoeuvre/r34_face_clip_e76f6dab6_laptop.mp4`), `frames.png` four moments, `*-screen.jsonl` each arm's SCREEN row.

What he will see: ten wheeled turret crews (5 gang tanks, 5 IFVs) told to face behind them. BEFORE: every hull stops
where its wheels happened to end, 134–174° off the drawn arrow (one IFV 62°, one 16.5°), `faced_ok` false, the task
ignored at the judge. AFTER: the hulls come round and rest 0.9–7.2° off the arrow, all ten still, `faced_ok` true,
settled after 34.5 s (the camera's own clock; the stage calls 21 s for the before arm because nobody turns).
The laptop renders the mechanism only (trip-up 85); attempt 4's numbers come from builder2's series, not this clip.
