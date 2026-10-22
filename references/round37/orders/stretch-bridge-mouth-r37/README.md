# Stretch 1 re-checked on round 37's tree: a plain click at the Crossing's west bridge mouth
Laptop GDScript, commit 9de8a7d4f (main c76469184 merged), `tests/orders_probe.gd --arena=crossing --seed=3790
--probe-route=click --probe-click=-92,Z`, Z = 34 / 37 / 40 (3 / 6 / 9 m short of the deck's south end at z 31,
outside DECK_CLEAR_CLICK_M), 3 and 5 squads: 6 runs, 24 squads.
- crossed 0, goals across 0 (no crew's own destination on the far bank, sampled every 0.5 s).
- deck True in 3 squads (a crew stood on the dry deck, not past it).
Round 36's answer stands: the deploy's halt lay (`_dry_halt_anchor`) steps a plain click's halt back off the deck and far
bank. No code. (The probe has armies for 3 and 5 squads only; 1 and 2 report "no RtsControls".)
